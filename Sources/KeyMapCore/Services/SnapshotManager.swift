import Foundation

public final class SnapshotManager: @unchecked Sendable {
    public let snapshotsDirectory: URL

    public static var defaultSnapshotsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KeyMapStudio/snapshots", isDirectory: true)
    }

    public init(snapshotsDirectory: URL = SnapshotManager.defaultSnapshotsDirectory) {
        self.snapshotsDirectory = snapshotsDirectory
    }

    public func listSnapshots() -> [KeyMapSnapshot] {
        guard FileManager.default.fileExists(atPath: snapshotsDirectory.path) else {
            return []
        }

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let decoder = Self.makeDecoder()
        var snapshots: [KeyMapSnapshot] = []

        for url in urls where url.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: url),
               let snapshot = try? decoder.decode(KeyMapSnapshot.self, from: data) {
                snapshots.append(snapshot)
            }
        }

        return snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    public func saveSnapshot(_ snapshot: KeyMapSnapshot) throws {
        try FileManager.default.createDirectory(
            at: snapshotsDirectory,
            withIntermediateDirectories: true
        )
        let targetURL = snapshotsDirectory.appendingPathComponent("\(snapshot.id.uuidString).json")
        let data = try Self.makeEncoder().encode(snapshot)
        try data.write(to: targetURL, options: .atomic)
    }

    public func deleteSnapshot(id: UUID) throws {
        let directURL = snapshotsDirectory.appendingPathComponent("\(id.uuidString).json")
        if FileManager.default.fileExists(atPath: directURL.path) {
            try FileManager.default.removeItem(at: directURL)
            return
        }

        guard FileManager.default.fileExists(atPath: snapshotsDirectory.path),
              let urls = try? FileManager.default.contentsOfDirectory(
                  at: snapshotsDirectory,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let decoder = Self.makeDecoder()
        for url in urls where url.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: url),
               let snapshot = try? decoder.decode(KeyMapSnapshot.self, from: data),
               snapshot.id == id {
                try FileManager.default.removeItem(at: url)
                return
            }
        }
    }

    public func exportJSON(_ snapshot: KeyMapSnapshot, to url: URL) throws {
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let data = try Self.makeEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func importJSON(from url: URL) throws -> KeyMapSnapshot {
        let data = try Data(contentsOf: url)
        return try Self.makeDecoder().decode(KeyMapSnapshot.self, from: data)
    }

    public func diff(from old: KeyMapSnapshot, to current: KeyMapSnapshot) -> SnapshotDiffSummary {
        var details: [String] = []

        // 1. Symbolic Hotkeys
        let oldSymbolic = Dictionary(uniqueKeysWithValues: old.symbolicHotkeys.map { ($0.id, $0) })
        let curSymbolic = Dictionary(uniqueKeysWithValues: current.symbolicHotkeys.map { ($0.id, $0) })
        let symbolicIDs = Set(oldSymbolic.keys).union(curSymbolic.keys).sorted()
        var symbolicChangedCount = 0
        for sid in symbolicIDs {
            if oldSymbolic[sid] != curSymbolic[sid] {
                symbolicChangedCount += 1
                details.append("系统快捷键 #\(sid) 已变更")
            }
        }

        // 2. App Menu Overrides
        let allDomains = Set(old.appMenuOverrides.keys).union(current.appMenuOverrides.keys).sorted()
        var appMenuChangedCount = 0
        for domain in allDomains {
            let oldMenus = old.appMenuOverrides[domain] ?? [:]
            let curMenus = current.appMenuOverrides[domain] ?? [:]
            let menuKeys = Set(oldMenus.keys).union(curMenus.keys).sorted()
            for menuKey in menuKeys {
                if oldMenus[menuKey] != curMenus[menuKey] {
                    appMenuChangedCount += 1
                    details.append("应用菜单 [\(domain)] 「\(menuKey)」已变更")
                }
            }
        }

        // 3. HID Remap Rules
        let oldHid = Dictionary(uniqueKeysWithValues: old.hidRules.map { ($0.id, $0) })
        let curHid = Dictionary(uniqueKeysWithValues: current.hidRules.map { ($0.id, $0) })
        let hidIDs = Set(oldHid.keys).union(curHid.keys)
        var hidRulesChangedCount = 0
        for id in hidIDs {
            if oldHid[id] != curHid[id] {
                hidRulesChangedCount += 1
                let name = curHid[id]?.name ?? oldHid[id]?.name ?? id.uuidString
                details.append("硬件单键规则「\(name)」已变更")
            }
        }

        // 4. Combo Remap Rules
        let oldCombo = Dictionary(uniqueKeysWithValues: old.comboRules.map { ($0.id, $0) })
        let curCombo = Dictionary(uniqueKeysWithValues: current.comboRules.map { ($0.id, $0) })
        let comboIDs = Set(oldCombo.keys).union(curCombo.keys)
        var comboRulesChangedCount = 0
        for id in comboIDs {
            if oldCombo[id] != curCombo[id] {
                comboRulesChangedCount += 1
                let name = curCombo[id]?.name ?? oldCombo[id]?.name ?? id.uuidString
                details.append("组合键规则「\(name)」已变更")
            }
        }

        // 5. Dev Tool Overrides
        let toolIDs = Set(old.devToolOverrides.keys).union(current.devToolOverrides.keys).sorted()
        var devToolChangedCount = 0
        for toolID in toolIDs {
            let oldRecords = Dictionary(
                (old.devToolOverrides[toolID] ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let curRecords = Dictionary(
                (current.devToolOverrides[toolID] ?? []).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let recordIDs = Set(oldRecords.keys).union(curRecords.keys).sorted()
            for recID in recordIDs {
                if oldRecords[recID] != curRecords[recID] {
                    devToolChangedCount += 1
                    let cmd = curRecords[recID]?.command ?? oldRecords[recID]?.command ?? recID
                    details.append("开发工具 [\(toolID)] 「\(cmd)」已变更")
                }
            }
        }

        return SnapshotDiffSummary(
            symbolicChangedCount: symbolicChangedCount,
            appMenuChangedCount: appMenuChangedCount,
            hidRulesChangedCount: hidRulesChangedCount,
            comboRulesChangedCount: comboRulesChangedCount,
            devToolChangedCount: devToolChangedCount,
            details: details
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
