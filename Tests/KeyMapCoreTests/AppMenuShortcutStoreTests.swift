import Foundation
import Testing
@testable import KeyMapCore

@Suite("AppMenuShortcutStore Tests")
struct AppMenuShortcutStoreTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyMapStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("formatMenuPath produces AppKit ESC-delimited hierarchical paths")
    func formatMenuPath() {
        #expect(AppMenuShortcutStore.formatMenuPath([]) == "")
        #expect(AppMenuShortcutStore.formatMenuPath(["Copy"]) == "Copy")
        #expect(
            AppMenuShortcutStore.formatMenuPath(["File", "Export As..."]) == "\u{001B}File\u{001B}Export As..."
        )
        #expect(
            AppMenuShortcutStore.formatMenuPath(["File", "Share", "Mail"]) == "\u{001B}File\u{001B}Share\u{001B}Mail"
        )
    }

    @Test("Isolated overrideDirectory supports setOverride, loadOverrides, loadAllOverrides, removeOverride, and restoreAllOverrides")
    func isolatedOverridesLifecycle() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = AppMenuShortcutStore(overrideDirectory: tempDir)

        let exportPath = AppMenuShortcutStore.formatMenuPath(["File", "Export As..."])
        let safariCombo = KeyCombo(keyCode: 14, modifiers: [.option, .command]) // ⌥⌘E
        let globalCombo = KeyCombo(keyCode: 40, modifiers: [.control, .command]) // ⌃⌘K
        let finderCombo = KeyCombo(keyCode: 45, modifiers: [.shift, .command]) // ⇧⌘N

        try store.setOverride(
            domain: "com.apple.Safari",
            appName: "Safari",
            menuTitleOrPath: exportPath,
            combo: safariCombo
        )
        try store.setOverride(
            domain: AppMenuShortcutStore.globalDomain,
            appName: nil,
            menuTitleOrPath: "Show Preferences",
            combo: globalCombo
        )
        try store.setOverride(
            domain: "com.apple.finder",
            appName: "Finder",
            menuTitleOrPath: "New Folder",
            combo: finderCombo
        )

        #expect(store.loadOverrides(forDomain: "com.apple.Safari") == [exportPath: "~@e"])
        #expect(store.loadOverrides(forDomain: AppMenuShortcutStore.globalDomain) == ["Show Preferences": "^@k"])
        #expect(Set(store.loadCustomizedAppBundleIDs()) == Set(["com.apple.Safari", "com.apple.finder"]))

        let allOverrides = store.loadAllOverrides()
        #expect(allOverrides[AppMenuShortcutStore.globalDomain] == ["Show Preferences": "^@k"])
        #expect(allOverrides["com.apple.Safari"] == [exportPath: "~@e"])
        #expect(allOverrides["com.apple.finder"] == ["New Folder": "$@n"])

        let items = store.loadOverrideShortcutItems()
        #expect(items.count == 3)
        let safariItem = try #require(items.first { $0.appBundleID == "com.apple.Safari" })
        #expect(safariItem.title == "Export As...")
        #expect(safariItem.subtitle == "File → Export As...")
        #expect(safariItem.combo == safariCombo)
        #expect(safariItem.metadata["menuPath"] == exportPath)

        // Remove Safari's only override -> unregisters Safari from custommenu.apps
        try store.removeOverride(domain: "com.apple.Safari", menuTitleOrPath: exportPath)
        #expect(store.loadOverrides(forDomain: "com.apple.Safari").isEmpty)
        #expect(store.loadCustomizedAppBundleIDs() == ["com.apple.finder"])

        // Restore snapshot overrides replaces all domains cleanly
        let snapshotOverrides: [String: [String: String]] = [
            AppMenuShortcutStore.globalDomain: ["Quit": "@q"],
            "com.apple.TextEdit": ["Wrap to Page": "~@w"]
        ]
        try store.restoreAllOverrides(snapshotOverrides)

        let afterRestore = store.loadAllOverrides()
        #expect(afterRestore[AppMenuShortcutStore.globalDomain] == ["Quit": "@q"])
        #expect(afterRestore["com.apple.TextEdit"] == ["Wrap to Page": "~@w"])
        #expect(afterRestore["com.apple.finder"] == nil)
        #expect(store.loadCustomizedAppBundleIDs() == ["com.apple.TextEdit"])
    }
}
