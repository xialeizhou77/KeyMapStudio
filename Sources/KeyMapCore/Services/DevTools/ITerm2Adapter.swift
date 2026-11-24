import AppKit
import Foundation

public final class ITerm2Adapter: DevToolAdapter, @unchecked Sendable {
    public let plistURL: URL
    public let appURL: URL
    private let usesCustomAppURL: Bool

    public var toolID: String { "iterm2" }
    public var displayName: String { "iTerm2" }
    public var bundleID: String { "com.googlecode.iterm2" }
    public var supportsWrite: Bool { true }

    public static var defaultPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.googlecode.iterm2.plist")
    }

    public static var defaultAppURL: URL {
        URL(fileURLWithPath: "/Applications/iTerm.app")
    }

    public init(
        plistURL: URL = ITerm2Adapter.defaultPlistURL,
        appURL: URL = ITerm2Adapter.defaultAppURL
    ) {
        self.plistURL = plistURL
        self.appURL = appURL
        self.usesCustomAppURL = (appURL != Self.defaultAppURL)
    }

    public convenience init(plistURL: URL) {
        self.init(plistURL: plistURL, appURL: Self.defaultAppURL)
    }

    public func detectStatus() -> DevToolInfo {
        let hasConfig = FileManager.default.fileExists(atPath: plistURL.path)
        let shortcuts = hasConfig ? loadShortcuts() : []
        return DevToolInfo(
            id: toolID,
            name: displayName,
            bundleID: bundleID,
            configPath: plistURL.path,
            isAppInstalled: checkAppInstalled(),
            hasConfigFile: hasConfig,
            shortcutCount: shortcuts.count,
            supportsWrite: supportsWrite
        )
    }

    public func loadShortcuts() -> [ShortcutItem] {
        guard let plist = loadPlistDictionary() else { return [] }
        var items: [ShortcutItem] = []

        if let globalMap = plist["GlobalKeyMap"] as? [String: Any] {
            items.append(contentsOf: parseKeyMap(globalMap, scope: "GlobalKeyMap"))
        }

        if let bookmarks = plist["New Bookmarks"] as? [[String: Any]],
           let firstBookmark = bookmarks.first,
           let keyboardMap = firstBookmark["Keyboard Map"] as? [String: Any] {
            items.append(contentsOf: parseKeyMap(keyboardMap, scope: "Keyboard Map"))
        }

        return items.sorted { lhs, rhs in
            if lhs.subtitle != rhs.subtitle { return lhs.subtitle < rhs.subtitle }
            return lhs.title < rhs.title
        }
    }

    public func upsertShortcut(
        command: String,
        combo: KeyCombo,
        when: String?,
        originalCommand: String?
    ) throws {
        var plist = try loadOrCreatePlistDictionary()
        let encodedKey = try Self.encodeITermKey(combo)
        let targetScope = resolveTargetScope(when: when, originalCommand: originalCommand, plist: plist)

        if targetScope == "Keyboard Map" {
            var bookmarks = (plist["New Bookmarks"] as? [[String: Any]]) ?? [[:]]
            if bookmarks.isEmpty {
                bookmarks.append([:])
            }
            var first = bookmarks[0]
            var keyMap = (first["Keyboard Map"] as? [String: Any]) ?? [:]
            let entry = buildUpdatedEntry(
                in: &keyMap,
                command: command,
                originalCommand: originalCommand,
                newKey: encodedKey
            )
            keyMap[encodedKey] = entry
            first["Keyboard Map"] = keyMap
            bookmarks[0] = first
            plist["New Bookmarks"] = bookmarks
        } else {
            var globalMap = (plist["GlobalKeyMap"] as? [String: Any]) ?? [:]
            let entry = buildUpdatedEntry(
                in: &globalMap,
                command: command,
                originalCommand: originalCommand,
                newKey: encodedKey
            )
            globalMap[encodedKey] = entry
            plist["GlobalKeyMap"] = globalMap
        }

        try writePlistDictionary(plist)
    }

    public func removeShortcut(itemID: String) throws {
        var plist = try loadOrCreatePlistDictionary()
        var removed = false

        let parsed = Self.parseItemID(itemID)
        let targetScope = parsed?.scope
        let targetKey = parsed?.key

        if targetScope == nil || targetScope == "GlobalKeyMap" {
            if var globalMap = plist["GlobalKeyMap"] as? [String: Any] {
                if let k = targetKey, globalMap.removeValue(forKey: k) != nil {
                    removed = true
                } else if removeMatchingEntry(in: &globalMap, scope: "GlobalKeyMap", identifier: itemID) {
                    removed = true
                }
                plist["GlobalKeyMap"] = globalMap
            }
        }

        if !removed && (targetScope == nil || targetScope == "Keyboard Map") {
            if var bookmarks = plist["New Bookmarks"] as? [[String: Any]], !bookmarks.isEmpty {
                var first = bookmarks[0]
                if var keyboardMap = first["Keyboard Map"] as? [String: Any] {
                    if let k = targetKey, keyboardMap.removeValue(forKey: k) != nil {
                        removed = true
                    } else if removeMatchingEntry(in: &keyboardMap, scope: "Keyboard Map", identifier: itemID) {
                        removed = true
                    }
                    first["Keyboard Map"] = keyboardMap
                    bookmarks[0] = first
                    plist["New Bookmarks"] = bookmarks
                }
            }
        }

        guard removed else {
            throw DevToolError.itemNotFound(itemID)
        }

        try writePlistDictionary(plist)
    }

    public func exportRecords() -> [DevToolBindingRecord] {
        guard let plist = loadPlistDictionary() else { return [] }
        var records: [DevToolBindingRecord] = []

        if let globalMap = plist["GlobalKeyMap"] as? [String: Any] {
            records.append(contentsOf: exportMap(globalMap, scope: "GlobalKeyMap"))
        }

        if let bookmarks = plist["New Bookmarks"] as? [[String: Any]],
           let first = bookmarks.first,
           let keyboardMap = first["Keyboard Map"] as? [String: Any] {
            records.append(contentsOf: exportMap(keyboardMap, scope: "Keyboard Map"))
        }

        return records.sorted { $0.id < $1.id }
    }

    public func importRecords(_ records: [DevToolBindingRecord]) throws {
        let relevant = records.filter { $0.toolID.isEmpty || $0.toolID == toolID }
        var plist = (try? loadOrCreatePlistDictionary()) ?? [:]

        var globalMap: [String: Any] = [:]
        var keyboardMap: [String: Any] = [:]

        for record in relevant {
            let scope = record.extra["scope"] ?? record.when ?? "GlobalKeyMap"
            var entry: [String: Any] = [:]
            if let actionStr = record.extra["action"], let actionInt = Int(actionStr) {
                entry["Action"] = actionInt
            } else {
                entry["Action"] = 12
            }
            entry["Text"] = record.extra["text"] ?? record.command

            if scope == "Keyboard Map" {
                keyboardMap[record.key] = entry
            } else {
                globalMap[record.key] = entry
            }
        }

        plist["GlobalKeyMap"] = globalMap
        var bookmarks = (plist["New Bookmarks"] as? [[String: Any]]) ?? [[:]]
        if bookmarks.isEmpty {
            bookmarks.append([:])
        }
        var first = bookmarks[0]
        first["Keyboard Map"] = keyboardMap
        bookmarks[0] = first
        plist["New Bookmarks"] = bookmarks

        try writePlistDictionary(plist)
    }

    // MARK: - Key Parsing & Encoding

    public static func parseITermKey(_ rawKey: String) -> KeyCombo? {
        let parts = rawKey.split(separator: "-").map(String.init)
        guard parts.count >= 2 else { return nil }

        guard let charCode = parseHexUInt32(parts[0]),
              let modFlags = parseHexUInt64(parts[1]) else {
            return nil
        }

        let modifiers = KeyModifiers(rawValue: modFlags & KeyModifiers.standardMask.rawValue)

        // Optional 3rd part in newer iTerm2 keymaps carries the virtual keyCode directly.
        if parts.count >= 3, let vk = parseHexUInt32(parts[2]), vk <= UInt16.max {
            let virtualKey = UInt16(vk)
            if KeyCodeCatalog.definition(forVirtualKey: virtualKey) != nil {
                return KeyCombo(keyCode: virtualKey, modifiers: modifiers)
            }
        }

        if let virtualKey = virtualKeyCode(forITermCharCode: charCode) {
            return KeyCombo(keyCode: virtualKey, modifiers: modifiers)
        }

        return nil
    }

    public static func encodeITermKey(_ combo: KeyCombo) throws -> String {
        let charCode = iTermCharCode(forVirtualKey: combo.keyCode)
        let modRaw = combo.modifiers.intersection(.standardMask).rawValue
        return String(format: "0x%x-0x%x", charCode, modRaw)
    }

    private static func parseHexUInt32(_ token: String) -> UInt32? {
        let cleaned = token.lowercased().hasPrefix("0x") ? String(token.dropFirst(2)) : token
        return UInt32(cleaned, radix: 16)
    }

    private static func parseHexUInt64(_ token: String) -> UInt64? {
        let cleaned = token.lowercased().hasPrefix("0x") ? String(token.dropFirst(2)) : token
        return UInt64(cleaned, radix: 16)
    }

    private static func virtualKeyCode(forITermCharCode code: UInt32) -> UInt16? {
        switch code {
        case 0x09, 0x19:
            return 48 // Tab / BackTab
        case 0x0A, 0x0D:
            return 36 // Return
        case 0x03:
            return 76 // Keypad Enter (or Return fallback)
        case 0x1B:
            return 53 // Escape
        case 0x20:
            return 49 // Space
        case 0x08, 0x7F:
            return 51 // Delete / Backspace
        case 0xF700:
            return 126 // Up
        case 0xF701:
            return 125 // Down
        case 0xF702:
            return 123 // Left
        case 0xF703:
            return 124 // Right
        case 0xF704: return 122 // F1
        case 0xF705: return 120 // F2
        case 0xF706: return 99  // F3
        case 0xF707: return 118 // F4
        case 0xF708: return 96  // F5
        case 0xF709: return 97  // F6
        case 0xF70A: return 98  // F7
        case 0xF70B: return 100 // F8
        case 0xF70C: return 101 // F9
        case 0xF70D: return 109 // F10
        case 0xF70E: return 103 // F11
        case 0xF70F: return 111 // F12
        case 0xF728: return 117 // Forward Delete
        case 0xF729: return 115 // Home
        case 0xF72B: return 119 // End
        case 0xF72C: return 116 // Page Up
        case 0xF72D: return 121 // Page Down
        default:
            break
        }

        guard let scalar = UnicodeScalar(code) else { return nil }
        let charString = String(scalar)
        if let def = KeyCodeCatalog.definition(forNSUserKeyChar: charString) {
            return def.virtualKeyCode
        }
        let lower = charString.lowercased()
        if let def = KeyCodeCatalog.definition(forCharacter: lower) {
            return def.virtualKeyCode
        }
        if let def = KeyCodeCatalog.definition(forNSUserKeyChar: lower) {
            return def.virtualKeyCode
        }
        return nil
    }

    private static func iTermCharCode(forVirtualKey virtualKey: UInt16) -> UInt32 {
        switch virtualKey {
        case 36: return 0x0D
        case 48: return 0x09
        case 49: return 0x20
        case 51: return 0x7F
        case 53: return 0x1B
        case 115: return 0xF729
        case 116: return 0xF72C
        case 117: return 0xF728
        case 119: return 0xF72B
        case 121: return 0xF72D
        case 123: return 0xF702
        case 124: return 0xF703
        case 125: return 0xF701
        case 126: return 0xF700
        case 122: return 0xF704
        case 120: return 0xF705
        case 99: return 0xF706
        case 118: return 0xF707
        case 96: return 0xF708
        case 97: return 0xF709
        case 98: return 0xF70A
        case 100: return 0xF70B
        case 101: return 0xF70C
        case 109: return 0xF70D
        case 103: return 0xF70E
        case 111: return 0xF70F
        default:
            break
        }

        if let def = KeyCodeCatalog.definition(forVirtualKey: virtualKey) {
            if let scalar = def.nsUserKeyChar.lowercased().unicodeScalars.first {
                return scalar.value
            }
            if def.ascii > 0 {
                return UInt32(def.ascii)
            }
        }

        return UInt32(virtualKey)
    }

    // MARK: - Helpers

    private func parseKeyMap(_ map: [String: Any], scope: String) -> [ShortcutItem] {
        var result: [ShortcutItem] = []

        for (rawKey, rawValue) in map {
            guard let dict = rawValue as? [String: Any] else { continue }
            let action = dict["Action"] as? Int ?? -1
            let text = dict["Text"] as? String ?? ""
            let description = Self.describeAction(action, text: text)
            let combo = Self.parseITermKey(rawKey)

            let itemID = Self.makeItemID(scope: scope, key: rawKey)
            let metadata: [String: String] = [
                "toolID": toolID,
                "command": description,
                "when": scope,
                "scope": scope,
                "itermKey": rawKey,
                "action": String(action),
                "text": text,
                "configPath": plistURL.path
            ]

            result.append(
                ShortcutItem(
                    id: itemID,
                    title: description,
                    subtitle: "\(scope) · \(rawKey)",
                    category: displayName,
                    source: .devTool,
                    appBundleID: bundleID,
                    appName: displayName,
                    combo: combo,
                    defaultCombo: nil,
                    isEnabled: true,
                    isModified: true,
                    isEditable: true,
                    metadata: metadata
                )
            )
        }

        return result
    }

    private func exportMap(_ map: [String: Any], scope: String) -> [DevToolBindingRecord] {
        var records: [DevToolBindingRecord] = []
        for (rawKey, rawValue) in map {
            guard let dict = rawValue as? [String: Any] else { continue }
            let action = dict["Action"] as? Int ?? 12
            let text = dict["Text"] as? String ?? ""
            let description = Self.describeAction(action, text: text)
            records.append(
                DevToolBindingRecord(
                    id: Self.makeItemID(scope: scope, key: rawKey),
                    toolID: toolID,
                    key: rawKey,
                    command: description,
                    when: scope,
                    extra: [
                        "action": String(action),
                        "text": text,
                        "scope": scope
                    ]
                )
            )
        }
        return records
    }

    private func resolveTargetScope(
        when: String?,
        originalCommand: String?,
        plist: [String: Any]
    ) -> String {
        if let when {
            let trimmed = when.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "Keyboard Map" || trimmed == "KeyboardMap" || trimmed.lowercased().contains("profile") {
                return "Keyboard Map"
            }
            if trimmed == "GlobalKeyMap" || trimmed.lowercased().contains("global") {
                return "GlobalKeyMap"
            }
        }

        if let originalCommand {
            if let globalMap = plist["GlobalKeyMap"] as? [String: Any],
               findMatchingKey(in: globalMap, identifier: originalCommand) != nil {
                return "GlobalKeyMap"
            }
            if let bookmarks = plist["New Bookmarks"] as? [[String: Any]],
               let first = bookmarks.first,
               let keyboardMap = first["Keyboard Map"] as? [String: Any],
               findMatchingKey(in: keyboardMap, identifier: originalCommand) != nil {
                return "Keyboard Map"
            }
        }

        return "GlobalKeyMap"
    }

    private func buildUpdatedEntry(
        in map: inout [String: Any],
        command: String,
        originalCommand: String?,
        newKey: String
    ) -> [String: Any] {
        let lookup = originalCommand ?? command
        if let existingKey = findMatchingKey(in: map, identifier: lookup),
           var existingEntry = map[existingKey] as? [String: Any] {
            if existingKey != newKey {
                map.removeValue(forKey: existingKey)
            }
            if originalCommand != nil && command != originalCommand {
                let parsed = Self.parseActionCommand(command)
                existingEntry["Action"] = parsed.action
                existingEntry["Text"] = parsed.text
            }
            return existingEntry
        }

        let parsed = Self.parseActionCommand(command)
        return [
            "Action": parsed.action,
            "Text": parsed.text
        ]
    }

    private func removeMatchingEntry(
        in map: inout [String: Any],
        scope: String,
        identifier: String
    ) -> Bool {
        if map.removeValue(forKey: identifier) != nil {
            return true
        }
        if let matchedKey = findMatchingKey(in: map, identifier: identifier) {
            map.removeValue(forKey: matchedKey)
            return true
        }
        for key in Array(map.keys) {
            if Self.makeItemID(scope: scope, key: key) == identifier {
                map.removeValue(forKey: key)
                return true
            }
        }
        return false
    }

    private func findMatchingKey(in map: [String: Any], identifier: String) -> String? {
        if map[identifier] != nil {
            return identifier
        }
        for (rawKey, rawValue) in map {
            guard let dict = rawValue as? [String: Any] else { continue }
            let action = dict["Action"] as? Int ?? -1
            let text = dict["Text"] as? String ?? ""
            let description = Self.describeAction(action, text: text)
            if description == identifier || text == identifier {
                return rawKey
            }
        }
        return nil
    }

    private static func makeItemID(scope: String, key: String) -> String {
        "iterm2|\(scope)|\(key)"
    }

    private static func parseItemID(_ itemID: String) -> (scope: String, key: String)? {
        let parts = itemID.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3, parts[0] == "iterm2" else { return nil }
        return (parts[1], parts[2])
    }

    private static func parseActionCommand(_ command: String) -> (action: Int, text: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("Send Hex Code:") {
            return (11, String(trimmed.dropFirst("Send Hex Code:".count)).trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("Send Escape Sequence:") {
            return (10, String(trimmed.dropFirst("Send Escape Sequence:".count)).trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("Send Text:") {
            return (12, String(trimmed.dropFirst("Send Text:".count)).trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("Action ") {
            let rest = String(trimmed.dropFirst("Action ".count))
            let pieces = rest.split(separator: ":", maxSplits: 1).map(String.init)
            if let code = Int(pieces[0].trimmingCharacters(in: .whitespaces)) {
                let text = pieces.count > 1 ? pieces[1].trimmingCharacters(in: .whitespaces) : ""
                return (code, text)
            }
        }
        return (12, trimmed)
    }

    public static func describeAction(_ action: Int, text: String) -> String {
        let baseName: String
        switch action {
        case 0: baseName = "Next Tab"
        case 1: baseName = "Next Window"
        case 2: baseName = "Previous Tab"
        case 3: baseName = "Previous Window"
        case 4: baseName = "Move Tab Right"
        case 5: baseName = "Move Tab Left"
        case 6: baseName = "Scroll Down Line"
        case 7: baseName = "Scroll Up Line"
        case 8: baseName = "Scroll Down Page"
        case 9: baseName = "Scroll Up Page"
        case 10: baseName = "Send Escape Sequence"
        case 11: baseName = "Send Hex Code"
        case 12: baseName = "Send Text"
        case 13: baseName = "Ignore"
        case 14: baseName = "Select Split Pane Left"
        case 15: baseName = "Select Split Pane Right"
        case 16: baseName = "Select Split Pane Above"
        case 17: baseName = "Select Split Pane Below"
        case 18: baseName = "Scroll to Top"
        case 19: baseName = "Scroll to Bottom"
        case 20: baseName = "Next Pane"
        case 21: baseName = "Previous Pane"
        case 25: baseName = "Send Snippet"
        case 27: baseName = "Invoke Script Function"
        case 28: baseName = "Split Horizontally"
        case 29: baseName = "Split Vertically"
        case 32: baseName = "Next Tab / Window"
        case 33: baseName = "Move Tab Left"
        case 34: baseName = "Move Tab Right"
        case 39: baseName = "Cycle Tabs"
        default: baseName = "Action \(action)"
        }

        let trimmedText = text.trimmingCharacters(in: .newlines)
        if trimmedText.isEmpty {
            return baseName
        }
        return "\(baseName): \(trimmedText)"
    }

    private func checkAppInstalled() -> Bool {
        if FileManager.default.fileExists(atPath: appURL.path) {
            return true
        }
        guard !usesCustomAppURL else { return false }
        let userApp = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .appendingPathComponent(appURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: userApp.path) {
            return true
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    private func loadPlistDictionary() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: plistURL.path),
              let data = try? Data(contentsOf: plistURL),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any] else {
            return nil
        }
        return dict
    }

    private func loadOrCreatePlistDictionary() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: plistURL)
        if data.isEmpty {
            return [:]
        }
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = obj as? [String: Any] else {
            throw DevToolError.invalidConfigFormat("iTerm2 plist 根节点必须是字典")
        }
        return dict
    }

    private func writePlistDictionary(_ dict: [String: Any]) throws {
        let parentDir = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
    }
}
