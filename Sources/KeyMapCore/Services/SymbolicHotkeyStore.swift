import Foundation

public final class SymbolicHotkeyStore: @unchecked Sendable {
    public let plistURL: URL
    public let activateSettingsOnWrite: Bool

    private static let activateSettingsPath = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"

    public init(
        plistURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist"),
        activateSettingsOnWrite: Bool = true
    ) {
        self.plistURL = plistURL
        self.activateSettingsOnWrite = activateSettingsOnWrite
    }

    public func loadShortcuts() -> [ShortcutItem] {
        let root = readRootDictionary()
        let plistHotKeys = root["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]

        var items: [ShortcutItem] = []
        var seenIDs = Set<String>()

        for def in SymbolicHotkeyCatalog.entries {
            seenIDs.insert(def.id)
            let entry = plistHotKeys[def.id] as? [String: Any]
            let item = buildShortcutItem(id: def.id, definition: def, entry: entry)
            items.append(item)
        }

        let extraIDs = plistHotKeys.keys
            .filter { !seenIDs.contains($0) }
            .sorted { lhs, rhs in
                if let lNum = Int(lhs), let rNum = Int(rhs) {
                    return lNum < rNum
                }
                return lhs < rhs
            }

        for id in extraIDs {
            guard let entry = plistHotKeys[id] as? [String: Any],
                  entry["value"] != nil else {
                continue
            }
            let item = buildShortcutItem(id: id, definition: nil, entry: entry)
            if item.combo != nil {
                items.append(item)
            }
        }

        return items
    }

    public func updateHotkey(id: String, combo: KeyCombo, enabled: Bool) throws {
        var root = readRootDictionary()
        var hotKeys = root["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]

        let maskedModifiers = Int(combo.modifiers.intersection(.standardMask).rawValue)
        let entry: [String: Any] = [
            "enabled": enabled,
            "value": [
                "type": "standard",
                "parameters": [combo.asciiCode, Int(combo.keyCode), maskedModifiers]
            ]
        ]

        hotKeys[id] = entry
        root["AppleSymbolicHotKeys"] = hotKeys
        try writeRootDictionary(root)
    }

    public func setEnabled(id: String, enabled: Bool) throws {
        var root = readRootDictionary()
        var hotKeys = root["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]
        var entry = hotKeys[id] as? [String: Any] ?? [:]

        entry["enabled"] = enabled
        if entry["value"] == nil,
           let def = SymbolicHotkeyCatalog.definition(forID: id),
           def.defaultVirtualKeyCode != UInt16.max {
            entry["value"] = [
                "type": "standard",
                "parameters": [def.defaultASCII, Int(def.defaultVirtualKeyCode), Int(def.defaultModifiers)]
            ]
        }

        hotKeys[id] = entry
        root["AppleSymbolicHotKeys"] = hotKeys
        try writeRootDictionary(root)
    }

    public func resetToDefault(id: String) throws {
        var root = readRootDictionary()
        var hotKeys = root["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]

        if let def = SymbolicHotkeyCatalog.definition(forID: id) {
            if def.defaultVirtualKeyCode != UInt16.max {
                hotKeys[id] = [
                    "enabled": def.defaultEnabled,
                    "value": [
                        "type": "standard",
                        "parameters": [def.defaultASCII, Int(def.defaultVirtualKeyCode), Int(def.defaultModifiers)]
                    ]
                ]
            } else {
                hotKeys[id] = ["enabled": def.defaultEnabled]
            }
        } else {
            hotKeys.removeValue(forKey: id)
        }

        root["AppleSymbolicHotKeys"] = hotKeys
        try writeRootDictionary(root)
    }

    public func exportStates() -> [SymbolicHotkeyState] {
        let root = readRootDictionary()
        let plistHotKeys = root["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]

        var states: [SymbolicHotkeyState] = []
        var seenIDs = Set<String>()

        for def in SymbolicHotkeyCatalog.entries {
            seenIDs.insert(def.id)
            let entry = plistHotKeys[def.id] as? [String: Any]
            let enabled = (entry?["enabled"] as? Bool) ?? def.defaultEnabled
            if let parsed = parseParameters(from: entry) {
                states.append(
                    SymbolicHotkeyState(
                        id: def.id,
                        enabled: enabled,
                        ascii: parsed.ascii,
                        virtualKeyCode: parsed.virtualKeyCode,
                        modifiers: parsed.modifiers
                    )
                )
            } else {
                states.append(
                    SymbolicHotkeyState(
                        id: def.id,
                        enabled: enabled,
                        ascii: def.defaultASCII,
                        virtualKeyCode: def.defaultVirtualKeyCode,
                        modifiers: def.defaultModifiers
                    )
                )
            }
        }

        let extraIDs = plistHotKeys.keys.filter { !seenIDs.contains($0) }.sorted()
        for id in extraIDs {
            guard let entry = plistHotKeys[id] as? [String: Any] else { continue }
            let enabled = (entry["enabled"] as? Bool) ?? false
            if let parsed = parseParameters(from: entry) {
                states.append(
                    SymbolicHotkeyState(
                        id: id,
                        enabled: enabled,
                        ascii: parsed.ascii,
                        virtualKeyCode: parsed.virtualKeyCode,
                        modifiers: parsed.modifiers
                    )
                )
            } else {
                states.append(
                    SymbolicHotkeyState(
                        id: id,
                        enabled: enabled,
                        ascii: 65535,
                        virtualKeyCode: UInt16.max,
                        modifiers: 0
                    )
                )
            }
        }

        return states
    }

    public func restoreStates(_ states: [SymbolicHotkeyState]) throws {
        var root = readRootDictionary()
        var hotKeys = root["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]

        for state in states {
            if state.virtualKeyCode != UInt16.max {
                hotKeys[state.id] = [
                    "enabled": state.enabled,
                    "value": [
                        "type": "standard",
                        "parameters": [state.ascii, Int(state.virtualKeyCode), Int(state.modifiers)]
                    ]
                ]
            } else {
                hotKeys[state.id] = ["enabled": state.enabled]
            }
        }

        root["AppleSymbolicHotKeys"] = hotKeys
        try writeRootDictionary(root)
    }

    // MARK: - Helpers

    private func buildShortcutItem(
        id: String,
        definition: SymbolicHotkeyDefinition?,
        entry: [String: Any]?
    ) -> ShortcutItem {
        let defaultCombo = definition?.defaultCombo
        let enabled = (entry?["enabled"] as? Bool) ?? (definition?.defaultEnabled ?? false)

        let effectiveCombo: KeyCombo?
        if let entry, let parsed = parseParameters(from: entry) {
            if parsed.virtualKeyCode != UInt16.max {
                effectiveCombo = KeyCombo(
                    keyCode: parsed.virtualKeyCode,
                    modifiers: KeyModifiers(symbolicBitmask: parsed.modifiers)
                )
            } else {
                effectiveCombo = nil
            }
        } else {
            effectiveCombo = defaultCombo
        }

        let isModified: Bool
        if let definition {
            isModified = (enabled != definition.defaultEnabled) ||
                (effectiveCombo?.canonicalKey != defaultCombo?.canonicalKey)
        } else {
            isModified = true
        }

        return ShortcutItem(
            id: "symbolic.\(id)",
            title: definition?.title ?? "系统快捷键 #\(id)",
            subtitle: "系统热键 ID \(id)",
            category: definition?.category ?? "其他系统快捷键",
            source: .systemSymbolic,
            appBundleID: nil,
            appName: "macOS 系统",
            combo: effectiveCombo,
            defaultCombo: defaultCombo,
            isEnabled: enabled,
            isModified: isModified,
            isEditable: true,
            metadata: ["symbolicID": id]
        )
    }

    private func parseParameters(
        from entry: [String: Any]?
    ) -> (ascii: Int, virtualKeyCode: UInt16, modifiers: UInt64)? {
        guard let value = entry?["value"] as? [String: Any],
              let params = value["parameters"] as? [Any],
              params.count >= 3,
              let ascii = (params[0] as? NSNumber)?.intValue,
              let rawVK = (params[1] as? NSNumber)?.intValue,
              let rawMods = (params[2] as? NSNumber)?.uint64Value else {
            return nil
        }

        let virtualKey: UInt16 = (rawVK >= 0 && rawVK < Int(UInt16.max)) ? UInt16(rawVK) : UInt16.max
        return (ascii: ascii, virtualKeyCode: virtualKey, modifiers: rawMods)
    }

    private func readRootDictionary() -> [String: Any] {
        guard FileManager.default.fileExists(atPath: plistURL.path),
              let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return [:]
        }
        return plist
    }

    private func writeRootDictionary(_ root: [String: Any]) throws {
        let directory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
        try data.write(to: plistURL, options: .atomic)

        if activateSettingsOnWrite, FileManager.default.isExecutableFile(atPath: Self.activateSettingsPath) {
            _ = try? ShellRunner.run(Self.activateSettingsPath, arguments: ["-u"])
        }
    }
}
