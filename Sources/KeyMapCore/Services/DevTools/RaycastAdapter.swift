import AppKit
import Foundation

public final class RaycastAdapter: DevToolAdapter, @unchecked Sendable {
    public let plistURL: URL
    public let appURL: URL
    private let usesCustomAppURL: Bool

    public var toolID: String { "raycast" }
    public var displayName: String { "Raycast" }
    public var bundleID: String { "com.raycast.macos" }
    public var supportsWrite: Bool { false }

    public static var defaultPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.raycast.macos.plist")
    }

    public static var defaultAppURL: URL {
        URL(fileURLWithPath: "/Applications/Raycast.app")
    }

    public init(
        plistURL: URL = RaycastAdapter.defaultPlistURL,
        appURL: URL = RaycastAdapter.defaultAppURL
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

        if let globalRaw = plist["raycastGlobalHotkey"] as? String,
           let combo = Self.parseRaycastHotkey(globalRaw) {
            items.append(
                ShortcutItem(
                    id: "raycast|globalHotkey",
                    title: "Raycast Global Hotkey",
                    subtitle: "全局唤起 Raycast (\(globalRaw))",
                    category: displayName,
                    source: .devTool,
                    appBundleID: bundleID,
                    appName: displayName,
                    combo: combo,
                    defaultCombo: nil,
                    isEnabled: true,
                    isModified: true,
                    isEditable: false,
                    metadata: [
                        "toolID": toolID,
                        "command": "raycastGlobalHotkey",
                        "isGlobal": "true",
                        "rawHotkey": globalRaw,
                        "configPath": plistURL.path
                    ]
                )
            )
        }

        // Scan any additional hotkey dictionaries or strings stored in Raycast preferences.
        for key in plist.keys.sorted() {
            if key == "raycastGlobalHotkey" { continue }

            if key == "commandHotkeys" || key == "hotkeys",
               let dict = plist[key] as? [String: Any] {
                for subKey in dict.keys.sorted() {
                    if let strVal = dict[subKey] as? String,
                       let combo = Self.parseRaycastHotkey(strVal) {
                        items.append(makeCommandItem(commandID: subKey, rawHotkey: strVal, combo: combo))
                    } else if let subDict = dict[subKey] as? [String: Any],
                              let combo = Self.parseHotkeyDictionary(subDict) {
                        items.append(makeCommandItem(commandID: subKey, rawHotkey: combo.displayString, combo: combo))
                    }
                }
            } else if key.lowercased().contains("hotkey"),
                      let strVal = plist[key] as? String,
                      let combo = Self.parseRaycastHotkey(strVal) {
                items.append(makeCommandItem(commandID: key, rawHotkey: strVal, combo: combo))
            }
        }

        return items
    }

    public func upsertShortcut(
        command: String,
        combo: KeyCombo,
        when: String?,
        originalCommand: String?
    ) throws {
        throw DevToolError.readOnlyTool(displayName)
    }

    public func removeShortcut(itemID: String) throws {
        throw DevToolError.readOnlyTool(displayName)
    }

    public func exportRecords() -> [DevToolBindingRecord] {
        loadShortcuts().map { item in
            DevToolBindingRecord(
                id: item.id,
                toolID: toolID,
                key: item.metadata["rawHotkey"] ?? item.combo?.displayString ?? "",
                command: item.metadata["command"] ?? item.title,
                when: item.metadata["isGlobal"] == "true" ? "global" : nil,
                extra: item.metadata
            )
        }
    }

    public func importRecords(_ records: [DevToolBindingRecord]) throws {
        throw DevToolError.readOnlyTool(displayName)
    }

    // MARK: - Parsing

    public static func parseRaycastHotkey(_ raw: String) -> KeyCombo? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: "-").map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        guard let keyToken = parts.last, !keyToken.isEmpty else { return nil }

        var modifiers: KeyModifiers = []
        for token in parts.dropLast() {
            switch token.lowercased() {
            case "command", "cmd", "meta", "super":
                modifiers.insert(.command)
            case "option", "opt", "alt":
                modifiers.insert(.option)
            case "control", "ctrl":
                modifiers.insert(.control)
            case "shift":
                modifiers.insert(.shift)
            case "function", "fn":
                modifiers.insert(.function)
            default:
                return nil
            }
        }

        if let numericCode = UInt16(keyToken),
           KeyCodeCatalog.definition(forVirtualKey: numericCode) != nil {
            return KeyCombo(keyCode: numericCode, modifiers: modifiers)
        }

        let lowerKey = keyToken.lowercased()
        switch lowerKey {
        case "space":
            return KeyCombo(keyCode: 49, modifiers: modifiers)
        case "return", "enter":
            return KeyCombo(keyCode: 36, modifiers: modifiers)
        case "tab":
            return KeyCombo(keyCode: 48, modifiers: modifiers)
        case "escape", "esc":
            return KeyCombo(keyCode: 53, modifiers: modifiers)
        case "delete", "backspace":
            return KeyCombo(keyCode: 51, modifiers: modifiers)
        case "forwarddelete":
            return KeyCombo(keyCode: 117, modifiers: modifiers)
        case "up", "uparrow":
            return KeyCombo(keyCode: 126, modifiers: modifiers)
        case "down", "downarrow":
            return KeyCombo(keyCode: 125, modifiers: modifiers)
        case "left", "leftarrow":
            return KeyCombo(keyCode: 123, modifiers: modifiers)
        case "right", "rightarrow":
            return KeyCombo(keyCode: 124, modifiers: modifiers)
        default:
            break
        }

        if let def = KeyCodeCatalog.definition(forVSCodeName: lowerKey) {
            return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
        }
        if let def = KeyCodeCatalog.definition(forCharacter: lowerKey) {
            return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
        }
        return nil
    }

    private static func parseHotkeyDictionary(_ dict: [String: Any]) -> KeyCombo? {
        if let raw = dict["hotkey"] as? String ?? dict["shortcut"] as? String {
            return parseRaycastHotkey(raw)
        }
        if let vk = dict["keyCode"] as? Int, vk >= 0, vk <= Int(UInt16.max) {
            let modRaw = (dict["modifiers"] as? NSNumber)?.uint64Value ?? 0
            let mods = KeyModifiers(rawValue: modRaw & KeyModifiers.standardMask.rawValue)
            return KeyCombo(keyCode: UInt16(vk), modifiers: mods)
        }
        return nil
    }

    private func makeCommandItem(commandID: String, rawHotkey: String, combo: KeyCombo) -> ShortcutItem {
        ShortcutItem(
            id: "raycast|\(commandID)",
            title: commandID,
            subtitle: "Raycast 全局命令快捷键 (\(rawHotkey))",
            category: displayName,
            source: .devTool,
            appBundleID: bundleID,
            appName: displayName,
            combo: combo,
            defaultCombo: nil,
            isEnabled: true,
            isModified: true,
            isEditable: false,
            metadata: [
                "toolID": toolID,
                "command": commandID,
                "isGlobal": "true",
                "rawHotkey": rawHotkey,
                "configPath": plistURL.path
            ]
        )
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
}
