import AppKit
import Foundation

public final class VSCodeFamilyAdapter: DevToolAdapter, @unchecked Sendable {
    public enum Variant: String, Sendable {
        case vscode
        case cursor
        case antigravity
    }

    public let variant: Variant
    public let configURL: URL
    public let appURL: URL
    private let usesCustomAppURL: Bool

    public var toolID: String { variant.rawValue }

    public var displayName: String {
        switch variant {
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        }
    }

    public var bundleID: String {
        switch variant {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .antigravity: return "com.google.antigravity"
        }
    }

    public var supportsWrite: Bool { true }

    public init(variant: Variant, configURL: URL? = nil, appURL: URL? = nil) {
        self.variant = variant
        self.configURL = configURL ?? Self.defaultConfigURL(for: variant)
        if let appURL {
            self.appURL = appURL
            self.usesCustomAppURL = true
        } else {
            self.appURL = Self.defaultAppURL(for: variant)
            self.usesCustomAppURL = false
        }
    }

    public static func defaultConfigURL(for variant: Variant) -> URL {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        let folderName: String
        switch variant {
        case .vscode: folderName = "Code"
        case .cursor: folderName = "Cursor"
        case .antigravity: folderName = "Antigravity"
        }
        return appSupport
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("User", isDirectory: true)
            .appendingPathComponent("keybindings.json")
    }

    public static func defaultAppURL(for variant: Variant) -> URL {
        let appName: String
        switch variant {
        case .vscode: appName = "Visual Studio Code.app"
        case .cursor: appName = "Cursor.app"
        case .antigravity: appName = "Antigravity.app"
        }
        return URL(fileURLWithPath: "/Applications/\(appName)")
    }

    public func detectStatus() -> DevToolInfo {
        let hasConfig = FileManager.default.fileExists(atPath: configURL.path)
        let shortcuts = hasConfig ? loadShortcuts() : []
        return DevToolInfo(
            id: toolID,
            name: displayName,
            bundleID: bundleID,
            configPath: configURL.path,
            isAppInstalled: checkAppInstalled(),
            hasConfigFile: hasConfig,
            shortcutCount: shortcuts.count,
            supportsWrite: supportsWrite
        )
    }

    public func loadShortcuts() -> [ShortcutItem] {
        let entries = loadRawEntries()
        var occurrenceCounts: [String: Int] = [:]
        var items: [ShortcutItem] = []

        for entry in entries {
            guard let keyRaw = entry["key"] as? String,
                  let commandRaw = entry["command"] as? String else {
                continue
            }
            let keyTrimmed = keyRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let command = commandRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { continue }

            let when = Self.normalizeWhen(entry["when"] as? String)
            let itemID = makeStableID(
                command: command,
                key: keyTrimmed,
                when: when,
                occurrenceCounts: &occurrenceCounts
            )

            let isDisabled = command.hasPrefix("-")
            let cleanCommand = isDisabled ? String(command.dropFirst()) : command
            let combo = parseVSCodeCombo(keyTrimmed)

            var subtitleParts: [String] = []
            if isDisabled {
                subtitleParts.append("已禁用默认绑定")
            }
            if let when {
                subtitleParts.append("when: \(when)")
            }
            if combo == nil && !keyTrimmed.isEmpty {
                subtitleParts.append("按键: \(keyTrimmed)")
            }
            let subtitle = subtitleParts.isEmpty ? displayName : subtitleParts.joined(separator: " · ")

            var metadata: [String: String] = [
                "toolID": toolID,
                "command": command,
                "configPath": configURL.path,
                "key": keyTrimmed
            ]
            if let when {
                metadata["when"] = when
            }

            items.append(
                ShortcutItem(
                    id: itemID,
                    title: cleanCommand,
                    subtitle: subtitle,
                    category: displayName,
                    source: .devTool,
                    appBundleID: bundleID,
                    appName: displayName,
                    combo: combo,
                    defaultCombo: nil,
                    isEnabled: !isDisabled,
                    isModified: true,
                    isEditable: true,
                    metadata: metadata
                )
            )
        }

        return items
    }

    public func upsertShortcut(
        command: String,
        combo: KeyCombo,
        when: String?,
        originalCommand: String?
    ) throws {
        var entries = try loadRawEntriesForWrite()
        let newKey = combo.vsCodeString
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw DevToolError.invalidConfigFormat("命令名称不能为空")
        }
        let normalizedWhen = Self.normalizeWhen(when)
        let lookupCommand = originalCommand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmedCommand

        var matchIndex: Int?
        if let exactIndex = entries.firstIndex(where: { entry in
            guard let cmd = (entry["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            let entryWhen = Self.normalizeWhen(entry["when"] as? String)
            return cmd == lookupCommand && entryWhen == normalizedWhen
        }) {
            matchIndex = exactIndex
        } else if originalCommand != nil,
                  let fallbackIndex = entries.firstIndex(where: { entry in
                      let cmd = (entry["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                      return cmd == lookupCommand
                  }) {
            matchIndex = fallbackIndex
        }

        if let idx = matchIndex {
            var updated = entries[idx]
            updated["key"] = newKey
            updated["command"] = trimmedCommand
            if let normalizedWhen {
                updated["when"] = normalizedWhen
            } else {
                updated.removeValue(forKey: "when")
            }
            entries[idx] = updated
        } else {
            var newEntry: [String: Any] = [
                "key": newKey,
                "command": trimmedCommand
            ]
            if let normalizedWhen {
                newEntry["when"] = normalizedWhen
            }
            entries.append(newEntry)
        }

        try writeEntries(entries)
    }

    public func removeShortcut(itemID: String) throws {
        var entries = try loadRawEntriesForWrite()
        var occurrenceCounts: [String: Int] = [:]
        var targetIndex: Int?

        for (index, entry) in entries.enumerated() {
            guard let keyRaw = entry["key"] as? String,
                  let commandRaw = entry["command"] as? String else {
                continue
            }
            let keyTrimmed = keyRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let command = commandRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { continue }
            let when = Self.normalizeWhen(entry["when"] as? String)
            let candidateID = makeStableID(
                command: command,
                key: keyTrimmed,
                when: when,
                occurrenceCounts: &occurrenceCounts
            )
            if candidateID == itemID {
                targetIndex = index
                break
            }
        }

        if targetIndex == nil {
            targetIndex = entries.firstIndex(where: { entry in
                let cmd = (entry["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return cmd == itemID
            })
        }

        guard let indexToRemove = targetIndex else {
            throw DevToolError.itemNotFound(itemID)
        }

        entries.remove(at: indexToRemove)
        try writeEntries(entries)
    }

    public func exportRecords() -> [DevToolBindingRecord] {
        let entries = loadRawEntries()
        var occurrenceCounts: [String: Int] = [:]
        var records: [DevToolBindingRecord] = []

        for entry in entries {
            guard let keyRaw = entry["key"] as? String,
                  let commandRaw = entry["command"] as? String else {
                continue
            }
            let key = keyRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let command = commandRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { continue }
            let when = Self.normalizeWhen(entry["when"] as? String)
            let recordID = makeStableID(
                command: command,
                key: key,
                when: when,
                occurrenceCounts: &occurrenceCounts
            )

            var extra: [String: String] = [:]
            if let args = entry["args"],
               JSONSerialization.isValidJSONObject(args),
               let argsData = try? JSONSerialization.data(withJSONObject: args, options: [.sortedKeys, .withoutEscapingSlashes]),
               let argsJSON = String(data: argsData, encoding: .utf8) {
                extra["argsJSON"] = argsJSON
            } else if let argsStr = entry["args"] as? String {
                extra["argsString"] = argsStr
            }

            records.append(
                DevToolBindingRecord(
                    id: recordID,
                    toolID: toolID,
                    key: key,
                    command: command,
                    when: when,
                    extra: extra
                )
            )
        }

        return records
    }

    public func importRecords(_ records: [DevToolBindingRecord]) throws {
        let relevant = records.filter { $0.toolID.isEmpty || $0.toolID == toolID }
        var entries: [[String: Any]] = []
        entries.reserveCapacity(relevant.count)

        for record in relevant {
            var dict: [String: Any] = [
                "key": record.key,
                "command": record.command
            ]
            if let when = Self.normalizeWhen(record.when) {
                dict["when"] = when
            }
            if let argsJSON = record.extra["argsJSON"],
               let argsData = argsJSON.data(using: .utf8),
               let argsObject = try? JSONSerialization.jsonObject(with: argsData) {
                dict["args"] = argsObject
            } else if let argsString = record.extra["argsString"] {
                dict["args"] = argsString
            }
            entries.append(dict)
        }

        try writeEntries(entries)
    }

    // MARK: - Private Helpers

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

    private func loadRawEntries() -> [[String: Any]] {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let content = try? String(contentsOf: configURL, encoding: .utf8) else {
            return []
        }
        return (try? JSONCParser.parseJSONArray(content)) ?? []
    }

    private func loadRawEntriesForWrite() throws -> [[String: Any]] {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return []
        }
        let content = try String(contentsOf: configURL, encoding: .utf8)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return []
        }
        return try JSONCParser.parseJSONArray(content)
    }

    private func writeEntries(_ entries: [[String: Any]]) throws {
        let parentDir = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: entries,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var output = data
        if output.last != 0x0A {
            output.append(0x0A)
        }
        try output.write(to: configURL, options: .atomic)
    }

    private func makeStableID(
        command: String,
        key: String,
        when: String?,
        occurrenceCounts: inout [String: Int]
    ) -> String {
        let base = "\(toolID)|\(command)|\(key)|\(when ?? "")"
        let occurrence = occurrenceCounts[base, default: 0]
        occurrenceCounts[base] = occurrence + 1
        return "\(base)|\(occurrence)"
    }

    private func parseVSCodeCombo(_ raw: String) -> KeyCombo? {
        if let direct = KeyCombo.parseVSCode(raw) {
            return direct
        }
        let normalized = raw
            .lowercased()
            .replacingOccurrences(of: "meta+", with: "cmd+")
            .replacingOccurrences(of: "super+", with: "cmd+")
        return KeyCombo.parseVSCode(normalized)
    }

    private static func normalizeWhen(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
