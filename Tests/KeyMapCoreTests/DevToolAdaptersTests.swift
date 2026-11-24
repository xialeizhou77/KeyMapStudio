import Foundation
import Testing
@testable import KeyMapCore

@Suite("DevTool Adapters & JSONCParser Tests")
struct DevToolAdaptersTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyMapStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("JSONCParser handles //, /* */, URLs inside quotes, escaped quotes, and trailing commas")
    func jsoncParserEdgeCases() throws {
        let jsonc = """
        \u{FEFF}// Leading comment
        [
          /* Multi-line
             block comment */
          {
            "key": "cmd+shift+k", // trailing inline comment
            "command": "editor.action.openUrl",
            "when": "editorTextFocus",
            "args": {
              "url": "https://example.com/docs/*keep*/?a=1&b=2",
              "escaped": "value \\"//not-a-comment\\", [stay,]",
            },
          },
        ]
        """

        let entries = try JSONCParser.parseJSONArray(jsonc)
        #expect(entries.count == 1)
        #expect(entries[0]["key"] as? String == "cmd+shift+k")
        #expect(entries[0]["command"] as? String == "editor.action.openUrl")

        let args = try #require(entries[0]["args"] as? [String: Any])
        #expect(args["url"] as? String == "https://example.com/docs/*keep*/?a=1&b=2")
        #expect(args["escaped"] as? String == #"value "//not-a-comment", [stay,]"#)

        let objectJSONC = """
        {
          // object comment
          "homepage": "https://obsidian.md//help",
          "items": ["a", "b",], /* trailing comma in array and object */
        }
        """
        let obj = try JSONCParser.parseJSONObject(objectJSONC)
        #expect(obj["homepage"] as? String == "https://obsidian.md//help")
        #expect(obj["items"] as? [String] == ["a", "b"])
    }

    @Test("VSCodeFamilyAdapter reads JSONC, handles -command disable entries, upserts, and removes")
    func vsCodeFamilyAdapter() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let keybindingsURL = tempDir.appendingPathComponent("User/keybindings.json")
        let fakeAppURL = tempDir.appendingPathComponent("MissingApp.app")
        try FileManager.default.createDirectory(at: keybindingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let initialJSONC = """
        // Place your key bindings in this file to override the defaults
        [
          {
            "key": "cmd+shift+k",
            "command": "editor.action.deleteLines",
            "when": "editorTextFocus",
            "args": { "url": "https://example.com" }, // keep url
          },
          {
            "key": "cmd+/",
            "command": "-editor.action.commentLine",
          },
        ]
        """
        try initialJSONC.write(to: keybindingsURL, atomically: true, encoding: .utf8)

        let adapter = VSCodeFamilyAdapter(variant: .vscode, configURL: keybindingsURL, appURL: fakeAppURL)
        let info = adapter.detectStatus()
        #expect(info.hasConfigFile == true)
        #expect(info.isAppInstalled == false)
        #expect(info.shortcutCount == 2)

        let loaded = adapter.loadShortcuts()
        #expect(loaded.count == 2)

        let deleteLines = try #require(loaded.first { $0.metadata["command"] == "editor.action.deleteLines" })
        #expect(deleteLines.isEnabled == true)
        #expect(deleteLines.combo == KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        #expect(deleteLines.metadata["when"] == "editorTextFocus")
        #expect(deleteLines.metadata["toolID"] == "vscode")

        let disabledComment = try #require(loaded.first { $0.metadata["command"] == "-editor.action.commentLine" })
        #expect(disabledComment.isEnabled == false)
        #expect(disabledComment.title == "editor.action.commentLine")
        #expect(disabledComment.combo == KeyCombo(keyCode: 44, modifiers: [.command]))

        // Upsert existing binding + insert a brand new binding
        let updatedCombo = KeyCombo(keyCode: 37, modifiers: [.option, .command]) // ⌥⌘L
        try adapter.upsertShortcut(
            command: "editor.action.deleteLines",
            combo: updatedCombo,
            when: "editorTextFocus",
            originalCommand: "editor.action.deleteLines"
        )
        try adapter.upsertShortcut(
            command: "workbench.action.quickOpen",
            combo: KeyCombo(keyCode: 35, modifiers: [.command]),
            when: "editorFocus",
            originalCommand: nil
        )

        let afterUpsert = adapter.loadShortcuts()
        #expect(afterUpsert.count == 3)
        let movedDelete = try #require(afterUpsert.first { $0.metadata["command"] == "editor.action.deleteLines" })
        #expect(movedDelete.combo == updatedCombo)

        let quickOpen = try #require(afterUpsert.first { $0.metadata["command"] == "workbench.action.quickOpen" })
        #expect(quickOpen.combo == KeyCombo(keyCode: 35, modifiers: [.command]))
        #expect(quickOpen.metadata["when"] == "editorFocus")

        // Remove disabled comment entry
        try adapter.removeShortcut(itemID: disabledComment.id)
        let afterRemove = adapter.loadShortcuts()
        #expect(afterRemove.count == 2)
        #expect(afterRemove.first { $0.metadata["command"] == "-editor.action.commentLine" } == nil)

        // Export & import round-trip
        let exported = adapter.exportRecords()
        #expect(exported.count == 2)
        let importedURL = tempDir.appendingPathComponent("Cursor/keybindings.json")
        let cursorAdapter = VSCodeFamilyAdapter(variant: .cursor, configURL: importedURL, appURL: fakeAppURL)
        let remappedRecords = exported.map { rec in
            DevToolBindingRecord(id: rec.id, toolID: "cursor", key: rec.key, command: rec.command, when: rec.when, extra: rec.extra)
        }
        try cursorAdapter.importRecords(remappedRecords)
        #expect(cursorAdapter.loadShortcuts().count == 2)
    }

    @Test("ITerm2Adapter reads, upserts, and removes GlobalKeyMap and Profile Keyboard Map bindings")
    func iterm2Adapter() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plistURL = tempDir.appendingPathComponent("com.googlecode.iterm2.plist")
        let fakeAppURL = tempDir.appendingPathComponent("MissingITerm.app")

        let initialPlist: [String: Any] = [
            "GlobalKeyMap": [
                "0x6b-0x100000": [
                    "Action": 12,
                    "Text": "clear\\n"
                ]
            ],
            "New Bookmarks": [
                [
                    "Name": "Default",
                    "Keyboard Map": [
                        "0x20-0x80000": [
                            "Action": 10,
                            "Text": "b"
                        ]
                    ]
                ]
            ]
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: initialPlist, format: .binary, options: 0)
        try data.write(to: plistURL, options: .atomic)

        let adapter = ITerm2Adapter(plistURL: plistURL, appURL: fakeAppURL)
        let shortcuts = adapter.loadShortcuts()
        #expect(shortcuts.count == 2)

        let globalItem = try #require(shortcuts.first { $0.metadata["scope"] == "GlobalKeyMap" })
        #expect(globalItem.combo == KeyCombo(keyCode: 40, modifiers: [.command])) // ⌘K
        #expect(globalItem.metadata["text"] == "clear\\n")

        let profileItem = try #require(shortcuts.first { $0.metadata["scope"] == "Keyboard Map" })
        #expect(profileItem.combo == KeyCombo(keyCode: 49, modifiers: [.option])) // ⌥Space
        #expect(profileItem.title.contains("Send Escape Sequence"))

        // Upsert new binding into Keyboard Map and update GlobalKeyMap binding
        try adapter.upsertShortcut(
            command: "Send Text: ls -la",
            combo: KeyCombo(keyCode: 37, modifiers: [.control, .option]), // ⌃⌥L
            when: "Keyboard Map",
            originalCommand: nil
        )
        try adapter.upsertShortcut(
            command: globalItem.title,
            combo: KeyCombo(keyCode: 40, modifiers: [.option, .command]), // ⌥⌘K
            when: "GlobalKeyMap",
            originalCommand: globalItem.title
        )

        let afterUpsert = adapter.loadShortcuts()
        #expect(afterUpsert.count == 3)
        let movedGlobal = try #require(afterUpsert.first { $0.metadata["scope"] == "GlobalKeyMap" })
        #expect(movedGlobal.combo == KeyCombo(keyCode: 40, modifiers: [.option, .command]))
        #expect(afterUpsert.contains { $0.metadata["scope"] == "Keyboard Map" && $0.combo == KeyCombo(keyCode: 37, modifiers: [.control, .option]) })

        // Remove profileItem
        try adapter.removeShortcut(itemID: profileItem.id)
        let afterRemove = adapter.loadShortcuts()
        #expect(afterRemove.count == 2)
        #expect(afterRemove.first { $0.id == profileItem.id } == nil)
    }

    @Test("ObsidianAdapter discovers vault from obsidian.json and reads/upserts/removes hotkeys.json")
    func obsidianAdapter() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vaultDir = tempDir.appendingPathComponent("TestVault", isDirectory: true)
        let obsidianDotDir = vaultDir.appendingPathComponent(".obsidian", isDirectory: true)
        try FileManager.default.createDirectory(at: obsidianDotDir, withIntermediateDirectories: true)

        let hotkeysURL = obsidianDotDir.appendingPathComponent("hotkeys.json")
        let initialHotkeys: [String: Any] = [
            "command-palette:open": [
                ["modifiers": ["Mod", "Shift"], "key": "P"]
            ],
            "app:toggle-left-sidebar": [
                ["modifiers": ["Alt"], "key": "Space"]
            ]
        ]
        let hotkeysData = try JSONSerialization.data(withJSONObject: initialHotkeys, options: [.prettyPrinted])
        try hotkeysData.write(to: hotkeysURL, options: .atomic)

        let obsidianConfigURL = tempDir.appendingPathComponent("obsidian.json")
        let obsidianConfig: [String: Any] = [
            "vaults": [
                "vault123": [
                    "path": vaultDir.path,
                    "ts": 1_700_000_000,
                    "open": true
                ]
            ]
        ]
        let configData = try JSONSerialization.data(withJSONObject: obsidianConfig, options: [.prettyPrinted])
        try configData.write(to: obsidianConfigURL, options: .atomic)

        let adapter = ObsidianAdapter(
            obsidianConfigURL: obsidianConfigURL,
            appURL: tempDir.appendingPathComponent("MissingObsidian.app")
        )
        let info = adapter.detectStatus()
        #expect(info.hasConfigFile == true)
        #expect(info.shortcutCount == 2)

        let loaded = adapter.loadShortcuts()
        #expect(loaded.count == 2)

        let palette = try #require(loaded.first { $0.title == "command-palette:open" })
        #expect(palette.combo == KeyCombo(keyCode: 35, modifiers: [.command, .shift]))

        let sidebar = try #require(loaded.first { $0.title == "app:toggle-left-sidebar" })
        #expect(sidebar.combo == KeyCombo(keyCode: 49, modifiers: [.option]))

        // Upsert new command + update existing command
        try adapter.upsertShortcut(
            command: "command-palette:open",
            combo: KeyCombo(keyCode: 40, modifiers: [.command, .option]), // ⌥⌘K
            when: nil,
            originalCommand: "command-palette:open"
        )
        try adapter.upsertShortcut(
            command: "editor:toggle-fold",
            combo: KeyCombo(keyCode: 3, modifiers: [.control, .command]), // ⌃⌘F
            when: nil,
            originalCommand: nil
        )

        let afterUpsert = adapter.loadShortcuts()
        #expect(afterUpsert.count == 3)
        let updatedPalette = try #require(afterUpsert.first { $0.title == "command-palette:open" })
        #expect(updatedPalette.combo == KeyCombo(keyCode: 40, modifiers: [.command, .option]))

        // Remove sidebar hotkey
        try adapter.removeShortcut(itemID: sidebar.id)
        let afterRemove = adapter.loadShortcuts()
        #expect(afterRemove.count == 2)
        #expect(afterRemove.first { $0.title == "app:toggle-left-sidebar" } == nil)
    }

    @Test("RaycastAdapter reads raycastGlobalHotkey and commandHotkeys in read-only mode")
    func raycastAdapter() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plistURL = tempDir.appendingPathComponent("com.raycast.macos.plist")
        let rawPlist: [String: Any] = [
            "raycastGlobalHotkey": "Command-49",
            "commandHotkeys": [
                "clipboard-history": "Option-Shift-v"
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: rawPlist, format: .binary, options: 0)
        try data.write(to: plistURL, options: .atomic)

        let adapter = RaycastAdapter(
            plistURL: plistURL,
            appURL: tempDir.appendingPathComponent("MissingRaycast.app")
        )
        let info = adapter.detectStatus()
        #expect(info.supportsWrite == false)
        #expect(info.hasConfigFile == true)
        #expect(info.shortcutCount == 2)

        let loaded = adapter.loadShortcuts()
        let global = try #require(loaded.first { $0.metadata["command"] == "raycastGlobalHotkey" })
        #expect(global.combo == KeyCombo(keyCode: 49, modifiers: [.command]))
        #expect(global.metadata["isGlobal"] == "true")
        #expect(global.isEditable == false)

        let clipboard = try #require(loaded.first { $0.metadata["command"] == "clipboard-history" })
        #expect(clipboard.combo == KeyCombo(keyCode: 9, modifiers: [.option, .shift]))

        #expect(throws: DevToolError.self) {
            try adapter.upsertShortcut(
                command: "test",
                combo: KeyCombo(keyCode: 49, modifiers: [.command]),
                when: nil,
                originalCommand: nil
            )
        }
        #expect(throws: DevToolError.self) {
            try adapter.removeShortcut(itemID: global.id)
        }
    }

    @Test("DevToolRegistry aggregates status, shortcuts, export, and skips read-only tools on import")
    func devToolRegistryAggregation() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vscodeConfig = tempDir.appendingPathComponent("vscode/keybindings.json")
        let raycastPlist = tempDir.appendingPathComponent("com.raycast.macos.plist")
        let fakeApp = tempDir.appendingPathComponent("Missing.app")

        try FileManager.default.createDirectory(at: vscodeConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"[{"key":"cmd+k","command":"workbench.action.clear"}]"#.write(to: vscodeConfig, atomically: true, encoding: .utf8)

        let raycastData = try PropertyListSerialization.data(
            fromPropertyList: ["raycastGlobalHotkey": "Option-Space"],
            format: .binary,
            options: 0
        )
        try raycastData.write(to: raycastPlist, options: .atomic)

        let vscode = VSCodeFamilyAdapter(variant: .vscode, configURL: vscodeConfig, appURL: fakeApp)
        let raycast = RaycastAdapter(plistURL: raycastPlist, appURL: fakeApp)
        let registry = DevToolRegistry(adapters: [vscode, raycast])

        let infos = registry.detectAll()
        #expect(infos.count == 2)
        #expect(registry.adapter(forToolID: "vscode")?.toolID == "vscode")
        #expect(registry.adapter(forToolID: "raycast")?.supportsWrite == false)

        let allShortcuts = registry.loadAllShortcuts()
        #expect(allShortcuts.count == 2)

        let exported = registry.exportAllRecords()
        #expect(exported["vscode"]?.count == 1)
        #expect(exported["raycast"]?.count == 1)

        // Importing back including read-only raycast records must succeed without throwing
        try registry.importAllRecords(exported)
        #expect(vscode.loadShortcuts().count == 1)
    }
}
