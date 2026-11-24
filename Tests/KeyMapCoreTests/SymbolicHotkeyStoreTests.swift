import Foundation
import Testing
@testable import KeyMapCore

@Suite("SymbolicHotkeyStore Tests")
struct SymbolicHotkeyStoreTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyMapStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Loads partial plist with disabled entry lacking value dict and merges catalog defaults")
    func loadPartialPlistMergesCatalog() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plistURL = tempDir.appendingPathComponent("com.apple.symbolichotkeys.plist")
        let customMods = Int(KeyModifiers([.control, .option]).rawValue)

        let rawPlist: [String: Any] = [
            "AppleSymbolicHotKeys": [
                // Disabled entry without "value" dict -> falls back to catalog default combo (⌘Space)
                "64": [
                    "enabled": false
                ],
                // Modified hotkey with explicit parameters (⌃⌥K)
                "65": [
                    "enabled": true,
                    "value": [
                        "type": "standard",
                        "parameters": [107, 40, customMods]
                    ]
                ],
                // Unknown extra entry with valid value dict
                "999": [
                    "enabled": true,
                    "value": [
                        "type": "standard",
                        "parameters": [97, 0, Int(KeyModifiers.command.rawValue)]
                    ]
                ],
                // Unknown extra entry without value dict (should be skipped in loadShortcuts)
                "998": [
                    "enabled": false
                ]
            ]
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: rawPlist, format: .binary, options: 0)
        try data.write(to: plistURL, options: .atomic)

        let store = SymbolicHotkeyStore(plistURL: plistURL, activateSettingsOnWrite: false)
        let shortcuts = store.loadShortcuts()

        // All catalog entries + the valid extra entry 999
        #expect(shortcuts.count == SymbolicHotkeyCatalog.entries.count + 1)

        let spotlight = try #require(shortcuts.first { $0.metadata["symbolicID"] == "64" })
        #expect(spotlight.isEnabled == false)
        #expect(spotlight.isModified == true)
        #expect(spotlight.combo == KeyCombo(keyCode: 49, modifiers: [.command]))
        #expect(spotlight.defaultCombo == KeyCombo(keyCode: 49, modifiers: [.command]))

        let finderSearch = try #require(shortcuts.first { $0.metadata["symbolicID"] == "65" })
        #expect(finderSearch.isEnabled == true)
        #expect(finderSearch.isModified == true)
        #expect(finderSearch.combo == KeyCombo(keyCode: 40, modifiers: [.control, .option]))
        #expect(finderSearch.defaultCombo == KeyCombo(keyCode: 49, modifiers: [.option, .command]))

        // Untouched entry from catalog keeps default and isModified == false
        let inputPrev = try #require(shortcuts.first { $0.metadata["symbolicID"] == "60" })
        #expect(inputPrev.isEnabled == true)
        #expect(inputPrev.isModified == false)
        #expect(inputPrev.combo == KeyCombo(keyCode: 49, modifiers: [.control]))

        let extra999 = try #require(shortcuts.first { $0.metadata["symbolicID"] == "999" })
        #expect(extra999.combo == KeyCombo(keyCode: 0, modifiers: [.command]))
        #expect(shortcuts.first { $0.metadata["symbolicID"] == "998" } == nil)
    }

    @Test("Updates hotkey, persists across reloads, toggles enablement, and resets to default")
    func updateReloadAndReset() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plistURL = tempDir.appendingPathComponent("com.apple.symbolichotkeys.plist")
        let store = SymbolicHotkeyStore(plistURL: plistURL, activateSettingsOnWrite: false)

        let newCombo = KeyCombo(keyCode: 40, modifiers: [.option, .command]) // ⌥⌘K
        try store.updateHotkey(id: "64", combo: newCombo, enabled: true)

        // Reload with a fresh store instance
        let reloadedStore = SymbolicHotkeyStore(plistURL: plistURL, activateSettingsOnWrite: false)
        let afterUpdate = reloadedStore.loadShortcuts()
        let updated64 = try #require(afterUpdate.first { $0.metadata["symbolicID"] == "64" })
        #expect(updated64.combo == newCombo)
        #expect(updated64.isEnabled == true)
        #expect(updated64.isModified == true)

        // Verify raw plist structure
        let data = try Data(contentsOf: plistURL)
        let rawRoot = try #require(
            try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let hotKeys = try #require(rawRoot["AppleSymbolicHotKeys"] as? [String: Any])
        let entry64 = try #require(hotKeys["64"] as? [String: Any])
        let value64 = try #require(entry64["value"] as? [String: Any])
        let params = try #require(value64["parameters"] as? [Int])
        #expect(params == [107, 40, Int(KeyModifiers([.option, .command]).rawValue)])

        // Toggle disabled
        try reloadedStore.setEnabled(id: "64", enabled: false)
        let disabled64 = try #require(reloadedStore.loadShortcuts().first { $0.metadata["symbolicID"] == "64" })
        #expect(disabled64.isEnabled == false)
        #expect(disabled64.combo == newCombo)

        // Reset to default
        try reloadedStore.resetToDefault(id: "64")
        let reset64 = try #require(reloadedStore.loadShortcuts().first { $0.metadata["symbolicID"] == "64" })
        #expect(reset64.isEnabled == true)
        #expect(reset64.isModified == false)
        #expect(reset64.combo == KeyCombo(keyCode: 49, modifiers: [.command]))
    }

    @Test("Export and restore symbolic hotkey states round-trip cleanly")
    func exportAndRestoreStates() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourcePlist = tempDir.appendingPathComponent("source.plist")
        let targetPlist = tempDir.appendingPathComponent("target.plist")

        let sourceStore = SymbolicHotkeyStore(plistURL: sourcePlist, activateSettingsOnWrite: false)
        let customCombo = KeyCombo(keyCode: 36, modifiers: [.control, .command]) // ⌃⌘↩
        try sourceStore.updateHotkey(id: "64", combo: customCombo, enabled: true)
        try sourceStore.setEnabled(id: "28", enabled: false)

        let states = sourceStore.exportStates()
        #expect(!states.isEmpty)

        let targetStore = SymbolicHotkeyStore(plistURL: targetPlist, activateSettingsOnWrite: false)
        try targetStore.restoreStates(states)

        let restored = targetStore.loadShortcuts()
        let restored64 = try #require(restored.first { $0.metadata["symbolicID"] == "64" })
        #expect(restored64.combo == customCombo)
        #expect(restored64.isEnabled == true)

        let restored28 = try #require(restored.first { $0.metadata["symbolicID"] == "28" })
        #expect(restored28.isEnabled == false)
    }
}
