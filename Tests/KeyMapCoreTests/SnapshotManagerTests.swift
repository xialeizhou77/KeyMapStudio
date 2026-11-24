import Foundation
import Testing
@testable import KeyMapCore

@Suite("SnapshotManager Tests")
struct SnapshotManagerTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyMapStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("saveSnapshot, listSnapshots (newest first), exportJSON/importJSON, and deleteSnapshot")
    func snapshotPersistenceAndExportImport() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshotsDir = tempDir.appendingPathComponent("snapshots", isDirectory: true)
        let manager = SnapshotManager(snapshotsDirectory: snapshotsDir)

        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_700_003_600)

        let olderSnapshot = KeyMapSnapshot(
            name: "Baseline",
            createdAt: olderDate,
            symbolicHotkeys: [
                SymbolicHotkeyState(id: "64", enabled: true, ascii: 32, virtualKeyCode: 49, modifiers: KeyModifiers.command.rawValue)
            ],
            appMenuOverrides: ["com.apple.Safari": ["Reload": "@r"]],
            hidRules: [HidRemapRule.builtInPresets[0]],
            comboRules: [
                ComboRemapRule(
                    name: "CapsCtrl",
                    source: KeyCombo(keyCode: 4, modifiers: [.control]),
                    target: KeyCombo(keyCode: 51, modifiers: [])
                )
            ],
            devToolOverrides: [
                "vscode": [
                    DevToolBindingRecord(id: "rec.1", toolID: "vscode", key: "cmd+k", command: "editor.action.test")
                ]
            ]
        )

        let newerSnapshot = KeyMapSnapshot(
            name: "After Edit",
            createdAt: newerDate,
            symbolicHotkeys: [],
            appMenuOverrides: [:],
            hidRules: [],
            comboRules: [],
            devToolOverrides: [:]
        )

        try manager.saveSnapshot(olderSnapshot)
        try manager.saveSnapshot(newerSnapshot)

        let listed = manager.listSnapshots()
        #expect(listed.count == 2)
        #expect(listed[0].id == newerSnapshot.id)
        #expect(listed[1].id == olderSnapshot.id)

        // Export & Import JSON round-trip
        let exportURL = tempDir.appendingPathComponent("exports/baseline.json")
        try manager.exportJSON(olderSnapshot, to: exportURL)
        let imported = try manager.importJSON(from: exportURL)

        #expect(imported.id == olderSnapshot.id)
        #expect(imported.name == "Baseline")
        #expect(Int(imported.createdAt.timeIntervalSince1970) == Int(olderDate.timeIntervalSince1970))
        #expect(imported.symbolicHotkeys == olderSnapshot.symbolicHotkeys)
        #expect(imported.appMenuOverrides == olderSnapshot.appMenuOverrides)
        #expect(imported.hidRules == olderSnapshot.hidRules)
        #expect(imported.comboRules == olderSnapshot.comboRules)
        #expect(imported.devToolOverrides == olderSnapshot.devToolOverrides)

        // Delete snapshot
        try manager.deleteSnapshot(id: olderSnapshot.id)
        let remaining = manager.listSnapshots()
        #expect(remaining.count == 1)
        #expect(remaining[0].id == newerSnapshot.id)
    }

    @Test("diff(from:to:) accurately counts changes across all 5 domains")
    func diffSummary() {
        let manager = SnapshotManager(
            snapshotsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        let hidRule1 = HidRemapRule(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Caps→Esc",
            sourceUsage: 0x700000039,
            targetUsage: 0x700000029
        )
        let comboRule1 = ComboRemapRule(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Ctrl+H → Backspace",
            source: KeyCombo(keyCode: 4, modifiers: [.control]),
            target: KeyCombo(keyCode: 51, modifiers: [])
        )

        let oldSnap = KeyMapSnapshot(
            name: "Old",
            symbolicHotkeys: [
                SymbolicHotkeyState(id: "64", enabled: true, ascii: 32, virtualKeyCode: 49, modifiers: KeyModifiers.command.rawValue),
                SymbolicHotkeyState(id: "65", enabled: true, ascii: 32, virtualKeyCode: 49, modifiers: KeyModifiers([.option, .command]).rawValue)
            ],
            appMenuOverrides: [
                "com.apple.Safari": ["Reload": "@r", "Print": "@p"]
            ],
            hidRules: [hidRule1],
            comboRules: [comboRule1],
            devToolOverrides: [
                "vscode": [
                    DevToolBindingRecord(id: "1", toolID: "vscode", key: "cmd+k", command: "cmd.a")
                ]
            ]
        )

        // Identical snapshot has zero diff
        let identicalDiff = manager.diff(from: oldSnap, to: oldSnap)
        #expect(identicalDiff.totalChangedCount == 0)
        #expect(identicalDiff.details.isEmpty)

        var modifiedHidRule = hidRule1
        modifiedHidRule.isEnabled = false

        let newSnap = KeyMapSnapshot(
            name: "New",
            symbolicHotkeys: [
                SymbolicHotkeyState(id: "64", enabled: false, ascii: 32, virtualKeyCode: 49, modifiers: KeyModifiers.command.rawValue),
                SymbolicHotkeyState(id: "65", enabled: true, ascii: 32, virtualKeyCode: 49, modifiers: KeyModifiers([.option, .command]).rawValue)
            ],
            appMenuOverrides: [
                "com.apple.Safari": ["Reload": "~@r", "Print": "@p"],
                "NSGlobalDomain": ["Quit": "@q"]
            ],
            hidRules: [modifiedHidRule],
            comboRules: [],
            devToolOverrides: [
                "vscode": [
                    DevToolBindingRecord(id: "1", toolID: "vscode", key: "cmd+j", command: "cmd.a"),
                    DevToolBindingRecord(id: "2", toolID: "vscode", key: "cmd+l", command: "cmd.b")
                ]
            ]
        )

        let diff = manager.diff(from: oldSnap, to: newSnap)
        #expect(diff.symbolicChangedCount == 1)
        #expect(diff.appMenuChangedCount == 2)
        #expect(diff.hidRulesChangedCount == 1)
        #expect(diff.comboRulesChangedCount == 1)
        #expect(diff.devToolChangedCount == 2)
        #expect(diff.totalChangedCount == 7)
        #expect(diff.details.count == 7)
    }
}
