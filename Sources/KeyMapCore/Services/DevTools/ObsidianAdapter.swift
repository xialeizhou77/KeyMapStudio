import AppKit
import Foundation

public final class ObsidianAdapter: DevToolAdapter, @unchecked Sendable {
    public let obsidianConfigURL: URL
    public let explicitHotkeysURLs: [URL]?
    public let appURL: URL
    private let usesCustomAppURL: Bool

    public var toolID: String { "obsidian" }
    public var displayName: String { "Obsidian" }
    public var bundleID: String { "md.obsidian" }
    public var supportsWrite: Bool { true }

    public static var defaultConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/obsidian/obsidian.json")
    }

    public static var defaultAppURL: URL {
        URL(fileURLWithPath: "/Applications/Obsidian.app")
    }

    public init(
        obsidianConfigURL: URL = ObsidianAdapter.defaultConfigURL,
        appURL: URL = ObsidianAdapter.defaultAppURL
    ) {
        self.obsidianConfigURL = obsidianConfigURL
        self.explicitHotkeysURLs = nil
        self.appURL = appURL
        self.usesCustomAppURL = (appURL != Self.defaultAppURL)
    }

    public init(
        hotkeysFileURLs: [URL],
        appURL: URL = ObsidianAdapter.defaultAppURL
    ) {
        self.obsidianConfigURL = Self.defaultConfigURL
        self.explicitHotkeysURLs = hotkeysFileURLs
        self.appURL = appURL
        self.usesCustomAppURL = (appURL != Self.defaultAppURL)
    }

    public func detectStatus() -> DevToolInfo {
        let targets = resolveVaultTargets()
        let existingHotkeyURL = targets.first(where: {
            FileManager.default.fileExists(atPath: $0.hotkeysURL.path)
        })?.hotkeysURL

        let hasConfig: Bool
        let displayConfigPath: String
        if let explicitHotkeysURLs {
            hasConfig = existingHotkeyURL != nil
            displayConfigPath = existingHotkeyURL?.path ?? explicitHotkeysURLs.first?.path ?? obsidianConfigURL.path
        } else {
            let mainConfigExists = FileManager.default.fileExists(atPath: obsidianConfigURL.path)
            hasConfig = existingHotkeyURL != nil || mainConfigExists
            displayConfigPath = existingHotkeyURL?.path ?? targets.first?.hotkeysURL.path ?? obsidianConfigURL.path
        }

        let shortcuts = hasConfig ? loadShortcuts() : []

        return DevToolInfo(
            id: toolID,
            name: displayName,
            bundleID: bundleID,
            configPath: displayConfigPath,
            isAppInstalled: checkAppInstalled(),
            hasConfigFile: hasConfig,
            shortcutCount: shortcuts.count,
            supportsWrite: supportsWrite
        )
    }

    public func loadShortcuts() -> [ShortcutItem] {
        let targets = resolveVaultTargets()
        var items: [ShortcutItem] = []

        for target in targets {
            guard let dict = loadHotkeysDictionary(at: target.hotkeysURL) else { continue }
            for command in dict.keys.sorted() {
                guard let bindings = dict[command] as? [[String: Any]] else { continue }
                for (index, binding) in bindings.enumerated() {
                    let modStrings = binding["modifiers"] as? [String] ?? []
                    let keyString = binding["key"] as? String ?? ""
                    let combo = Self.parseObsidianCombo(modifiers: modStrings, key: keyString)

                    let itemID = Self.makeItemID(
                        hotkeysURL: target.hotkeysURL,
                        command: command,
                        index: index
                    )

                    let subtitle = targets.count > 1
                        ? "Vault: \(target.vaultName) · \(command)"
                        : command

                    items.append(
                        ShortcutItem(
                            id: itemID,
                            title: command,
                            subtitle: subtitle,
                            category: displayName,
                            source: .devTool,
                            appBundleID: bundleID,
                            appName: displayName,
                            combo: combo,
                            defaultCombo: nil,
                            isEnabled: true,
                            isModified: true,
                            isEditable: true,
                            metadata: [
                                "toolID": toolID,
                                "command": command,
                                "vaultName": target.vaultName,
                                "configPath": target.hotkeysURL.path,
                                "bindingIndex": String(index)
                            ]
                        )
                    )
                }
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
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw DevToolError.invalidConfigFormat("Obsidian 命令 ID 不能为空")
        }

        let targets = resolveVaultTargets()
        guard !targets.isEmpty else {
            throw DevToolError.configNotFound(obsidianConfigURL.path)
        }

        let targetURL = selectTargetURL(
            from: targets,
            when: when,
            originalCommand: originalCommand
        )

        var dict = try loadOrCreateHotkeysDictionary(at: targetURL)
        if let originalCommand, originalCommand != trimmedCommand {
            dict.removeValue(forKey: originalCommand)
        }

        let encodedBinding: [String: Any] = [
            "modifiers": Self.encodeObsidianModifiers(combo.modifiers),
            "key": Self.encodeObsidianKey(combo.keyCode)
        ]
        dict[trimmedCommand] = [encodedBinding]

        try writeHotkeysDictionary(dict, to: targetURL)
    }

    public func removeShortcut(itemID: String) throws {
        let targets = resolveVaultTargets()

        if let parsed = Self.parseItemID(itemID) {
            let targetURL = URL(fileURLWithPath: parsed.path)
            var dict = try loadOrCreateHotkeysDictionary(at: targetURL)
            if var bindings = dict[parsed.command] as? [[String: Any]],
               parsed.index >= 0 && parsed.index < bindings.count {
                bindings.remove(at: parsed.index)
                if bindings.isEmpty {
                    dict.removeValue(forKey: parsed.command)
                } else {
                    dict[parsed.command] = bindings
                }
                try writeHotkeysDictionary(dict, to: targetURL)
                return
            }
        }

        for target in targets {
            guard FileManager.default.fileExists(atPath: target.hotkeysURL.path) else { continue }
            var dict = try loadOrCreateHotkeysDictionary(at: target.hotkeysURL)
            if dict.removeValue(forKey: itemID) != nil {
                try writeHotkeysDictionary(dict, to: target.hotkeysURL)
                return
            }
            for command in Array(dict.keys) {
                guard var bindings = dict[command] as? [[String: Any]] else { continue }
                for index in bindings.indices {
                    let candidateID = Self.makeItemID(
                        hotkeysURL: target.hotkeysURL,
                        command: command,
                        index: index
                    )
                    if candidateID == itemID {
                        bindings.remove(at: index)
                        if bindings.isEmpty {
                            dict.removeValue(forKey: command)
                        } else {
                            dict[command] = bindings
                        }
                        try writeHotkeysDictionary(dict, to: target.hotkeysURL)
                        return
                    }
                }
            }
        }

        throw DevToolError.itemNotFound(itemID)
    }

    public func exportRecords() -> [DevToolBindingRecord] {
        let targets = resolveVaultTargets()
        var records: [DevToolBindingRecord] = []

        for target in targets {
            guard let dict = loadHotkeysDictionary(at: target.hotkeysURL) else { continue }
            for command in dict.keys.sorted() {
                guard let bindings = dict[command] as? [[String: Any]] else { continue }
                for (index, binding) in bindings.enumerated() {
                    let modStrings = binding["modifiers"] as? [String] ?? []
                    let keyString = binding["key"] as? String ?? ""
                    let itemID = Self.makeItemID(
                        hotkeysURL: target.hotkeysURL,
                        command: command,
                        index: index
                    )
                    records.append(
                        DevToolBindingRecord(
                            id: itemID,
                            toolID: toolID,
                            key: keyString,
                            command: command,
                            when: target.vaultName,
                            extra: [
                                "modifiers": modStrings.joined(separator: ","),
                                "configPath": target.hotkeysURL.path,
                                "vaultName": target.vaultName
                            ]
                        )
                    )
                }
            }
        }

        return records
    }

    public func importRecords(_ records: [DevToolBindingRecord]) throws {
        let relevant = records.filter { $0.toolID.isEmpty || $0.toolID == toolID }
        let targets = resolveVaultTargets()
        guard let fallbackURL = targets.first?.hotkeysURL else {
            if relevant.isEmpty { return }
            throw DevToolError.configNotFound(obsidianConfigURL.path)
        }

        var groupedByURL: [URL: [String: [[String: Any]]]] = [:]
        for record in relevant {
            let targetURL: URL
            if let path = record.extra["configPath"],
               targets.contains(where: { $0.hotkeysURL.path == path }) {
                targetURL = URL(fileURLWithPath: path)
            } else if let vaultName = record.when ?? record.extra["vaultName"],
                      let matched = targets.first(where: { $0.vaultName == vaultName }) {
                targetURL = matched.hotkeysURL
            } else {
                targetURL = fallbackURL
            }

            let modifiers: [String]
            if let modsRaw = record.extra["modifiers"], !modsRaw.isEmpty {
                modifiers = modsRaw.split(separator: ",").map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
            } else {
                modifiers = []
            }

            let entry: [String: Any] = [
                "modifiers": modifiers,
                "key": record.key
            ]

            var vaultDict = groupedByURL[targetURL] ?? [:]
            var existing = vaultDict[record.command] ?? []
            existing.append(entry)
            vaultDict[record.command] = existing
            groupedByURL[targetURL] = vaultDict
        }

        for (url, dict) in groupedByURL {
            try writeHotkeysDictionary(dict, to: url)
        }
    }

    // MARK: - Parsing & Encoding

    public static func parseObsidianCombo(modifiers modTokens: [String], key: String) -> KeyCombo? {
        var modifiers: KeyModifiers = []
        for token in modTokens {
            switch token.trimmingCharacters(in: .whitespaces).lowercased() {
            case "mod", "meta", "cmd", "command":
                modifiers.insert(.command)
            case "alt", "opt", "option":
                modifiers.insert(.option)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "shift":
                modifiers.insert(.shift)
            default:
                break
            }
        }

        let keyTrimmed = key.trimmingCharacters(in: .newlines)
        guard !keyTrimmed.isEmpty else { return nil }

        if keyTrimmed == " " || keyTrimmed.lowercased() == "space" {
            return KeyCombo(keyCode: 49, modifiers: modifiers)
        }

        let lower = keyTrimmed.trimmingCharacters(in: .whitespaces).lowercased()
        switch lower {
        case "enter", "return":
            return KeyCombo(keyCode: 36, modifiers: modifiers)
        case "escape", "esc":
            return KeyCombo(keyCode: 53, modifiers: modifiers)
        case "tab":
            return KeyCombo(keyCode: 48, modifiers: modifiers)
        case "backspace":
            return KeyCombo(keyCode: 51, modifiers: modifiers)
        case "delete":
            return KeyCombo(keyCode: 117, modifiers: modifiers)
        case "arrowup", "up":
            return KeyCombo(keyCode: 126, modifiers: modifiers)
        case "arrowdown", "down":
            return KeyCombo(keyCode: 125, modifiers: modifiers)
        case "arrowleft", "left":
            return KeyCombo(keyCode: 123, modifiers: modifiers)
        case "arrowright", "right":
            return KeyCombo(keyCode: 124, modifiers: modifiers)
        case "home":
            return KeyCombo(keyCode: 115, modifiers: modifiers)
        case "end":
            return KeyCombo(keyCode: 119, modifiers: modifiers)
        case "pageup":
            return KeyCombo(keyCode: 116, modifiers: modifiers)
        case "pagedown":
            return KeyCombo(keyCode: 121, modifiers: modifiers)
        default:
            break
        }

        if let def = KeyCodeCatalog.definition(forVSCodeName: lower) {
            return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
        }
        if let def = KeyCodeCatalog.definition(forCharacter: lower) {
            return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
        }
        return nil
    }

    public static func encodeObsidianModifiers(_ modifiers: KeyModifiers) -> [String] {
        var tokens: [String] = []
        if modifiers.contains(.command) { tokens.append("Mod") }
        if modifiers.contains(.control) { tokens.append("Ctrl") }
        if modifiers.contains(.option) { tokens.append("Alt") }
        if modifiers.contains(.shift) { tokens.append("Shift") }
        return tokens
    }

    public static func encodeObsidianKey(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "Enter"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Backspace"
        case 53: return "Escape"
        case 115: return "Home"
        case 116: return "PageUp"
        case 117: return "Delete"
        case 119: return "End"
        case 121: return "PageDown"
        case 123: return "ArrowLeft"
        case 124: return "ArrowRight"
        case 125: return "ArrowDown"
        case 126: return "ArrowUp"
        default:
            break
        }

        if let def = KeyCodeCatalog.definition(forVirtualKey: keyCode) {
            if def.vsCodeName.hasPrefix("f"), def.vsCodeName.count <= 3 {
                return def.vsCodeName.uppercased()
            }
            if def.label.count == 1 {
                return def.label.uppercased()
            }
            if !def.nsUserKeyChar.isEmpty {
                return def.nsUserKeyChar.uppercased()
            }
            return def.vsCodeName
        }

        return String(keyCode)
    }

    // MARK: - Vault & File Helpers

    private struct VaultTarget {
        let vaultName: String
        let hotkeysURL: URL
    }

    private func resolveVaultTargets() -> [VaultTarget] {
        if let explicitHotkeysURLs {
            return explicitHotkeysURLs.map { url in
                let parent = url.deletingLastPathComponent()
                let vaultDir = parent.lastPathComponent == ".obsidian" ? parent.deletingLastPathComponent() : parent
                let vaultName = vaultDir.lastPathComponent.isEmpty ? "Vault" : vaultDir.lastPathComponent
                return VaultTarget(vaultName: vaultName, hotkeysURL: url)
            }
        }

        guard FileManager.default.fileExists(atPath: obsidianConfigURL.path),
              let data = try? Data(contentsOf: obsidianConfigURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vaults = json["vaults"] as? [String: [String: Any]] else {
            return []
        }

        var targets: [VaultTarget] = []
        for vaultID in vaults.keys.sorted() {
            guard let vaultInfo = vaults[vaultID],
                  let path = vaultInfo["path"] as? String,
                  !path.isEmpty else {
                continue
            }
            let vaultURL = URL(fileURLWithPath: path, isDirectory: true)
            let hotkeysURL = vaultURL
                .appendingPathComponent(".obsidian", isDirectory: true)
                .appendingPathComponent("hotkeys.json")
            let name = vaultURL.lastPathComponent.isEmpty ? vaultID : vaultURL.lastPathComponent
            targets.append(VaultTarget(vaultName: name, hotkeysURL: hotkeysURL))
        }
        return targets
    }

    private func selectTargetURL(
        from targets: [VaultTarget],
        when: String?,
        originalCommand: String?
    ) -> URL {
        if let when,
           let matchedByVault = targets.first(where: { $0.vaultName == when || $0.hotkeysURL.path == when }) {
            return matchedByVault.hotkeysURL
        }
        if let originalCommand {
            for target in targets {
                if let dict = loadHotkeysDictionary(at: target.hotkeysURL),
                   dict[originalCommand] != nil {
                    return target.hotkeysURL
                }
            }
        }
        return targets[0].hotkeysURL
    }

    private func loadHotkeysDictionary(at url: URL) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        if let text = String(data: data, encoding: .utf8),
           let dict = try? JSONCParser.parseJSONObject(text) {
            return dict
        }
        return nil
    }

    private func loadOrCreateHotkeysDictionary(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        if data.isEmpty {
            return [:]
        }
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        if let text = String(data: data, encoding: .utf8) {
            return try JSONCParser.parseJSONObject(text)
        }
        throw DevToolError.invalidConfigFormat("无法解析 Obsidian hotkeys.json")
    }

    private func writeHotkeysDictionary(_ dict: [String: Any], to url: URL) throws {
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var output = data
        if output.last != 0x0A {
            output.append(0x0A)
        }
        try output.write(to: url, options: .atomic)
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

    private static func makeItemID(hotkeysURL: URL, command: String, index: Int) -> String {
        "obsidian|\(hotkeysURL.path)|\(command)|\(index)"
    }

    private static func parseItemID(_ itemID: String) -> (path: String, command: String, index: Int)? {
        let parts = itemID.split(separator: "|").map(String.init)
        guard parts.count >= 4, parts[0] == "obsidian", let index = Int(parts.last!) else {
            return nil
        }
        let path = parts[1]
        let command = parts[2..<(parts.count - 1)].joined(separator: "|")
        return (path, command, index)
    }
}
