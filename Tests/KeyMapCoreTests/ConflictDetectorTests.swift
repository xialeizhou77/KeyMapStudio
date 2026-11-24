import Foundation
import Testing
@testable import KeyMapCore

@Suite("ConflictDetector Tests")
struct ConflictDetectorTests {
    private let cmdN = KeyCombo(keyCode: 45, modifiers: [.command])
    private let cmdSpace = KeyCombo(keyCode: 49, modifiers: [.command])
    private let cmdShiftK = KeyCombo(keyCode: 40, modifiers: [.command, .shift])

    @Test("Detects critical conflict for two system shortcuts or two same-app menu shortcuts")
    func criticalConflicts() {
        let sys1 = ShortcutItem(
            id: "sys.1",
            title: "Spotlight",
            subtitle: "System",
            category: "System",
            source: .systemSymbolic,
            appName: "macOS",
            combo: cmdSpace,
            isEnabled: true
        )
        let sys2 = ShortcutItem(
            id: "sys.2",
            title: "Other System",
            subtitle: "System",
            category: "System",
            source: .systemSymbolic,
            appName: "macOS",
            combo: cmdSpace,
            isEnabled: true
        )

        let menu1 = ShortcutItem(
            id: "menu.1",
            title: "New Window",
            subtitle: "File → New Window",
            category: "File",
            source: .appMenu,
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            combo: cmdN,
            isEnabled: true
        )
        let menu2 = ShortcutItem(
            id: "menu.2",
            title: "New Document",
            subtitle: "File → New Document",
            category: "File",
            source: .appMenu,
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            combo: cmdN,
            isEnabled: true
        )

        let conflicts = ConflictDetector.detect(in: [sys1, sys2, menu1, menu2])
        #expect(conflicts.count == 2)
        #expect(conflicts.allSatisfy { $0.severity == .critical })
    }

    @Test("Detects warning conflict between global system shortcut and local app menu shortcut")
    func warningConflictSystemVsAppMenu() {
        let sys = ShortcutItem(
            id: "sys.64",
            title: "Spotlight",
            subtitle: "System",
            category: "System",
            source: .systemSymbolic,
            appName: "macOS",
            combo: cmdSpace,
            isEnabled: true
        )
        let appMenu = ShortcutItem(
            id: "menu.vscode.space",
            title: "Quick Open",
            subtitle: "File → Quick Open",
            category: "File",
            source: .appMenu,
            appBundleID: "com.microsoft.VSCode",
            appName: "VS Code",
            combo: cmdSpace,
            isEnabled: true
        )

        let conflicts = ConflictDetector.detect(in: [sys, appMenu])
        #expect(conflicts.count == 1)
        #expect(conflicts[0].severity == .warning)
        #expect(conflicts[0].items.count == 2)
    }

    @Test("Detects info conflict for same devTool with different when clauses and critical for same when")
    func devToolWhenClauseConflicts() {
        let dtEditor = ShortcutItem(
            id: "vscode.1",
            title: "editor.action.formatDocument",
            subtitle: "when: editorTextFocus",
            category: "VS Code",
            source: .devTool,
            appBundleID: "com.microsoft.VSCode",
            appName: "VS Code",
            combo: cmdShiftK,
            isEnabled: true,
            metadata: ["toolID": "vscode", "when": "editorTextFocus"]
        )
        let dtTerminal = ShortcutItem(
            id: "vscode.2",
            title: "workbench.action.terminal.clear",
            subtitle: "when: terminalFocus",
            category: "VS Code",
            source: .devTool,
            appBundleID: "com.microsoft.VSCode",
            appName: "VS Code",
            combo: cmdShiftK,
            isEnabled: true,
            metadata: ["toolID": "vscode", "when": "terminalFocus"]
        )

        let infoConflicts = ConflictDetector.detect(in: [dtEditor, dtTerminal])
        #expect(infoConflicts.count == 1)
        #expect(infoConflicts[0].severity == .info)

        // Same tool + same when -> critical
        let dtDuplicateSameWhen = ShortcutItem(
            id: "vscode.3",
            title: "editor.action.deleteLines",
            subtitle: "when: editorTextFocus",
            category: "VS Code",
            source: .devTool,
            appBundleID: "com.microsoft.VSCode",
            appName: "VS Code",
            combo: cmdShiftK,
            isEnabled: true,
            metadata: ["toolID": "vscode", "when": "editorTextFocus"]
        )

        let critConflicts = ConflictDetector.detect(in: [dtEditor, dtDuplicateSameWhen])
        #expect(critConflicts.count == 1)
        #expect(critConflicts[0].severity == .critical)
    }

    @Test("Produces ZERO conflict for two different apps' appMenu shortcuts sharing the same combo")
    func differentAppsMenuNoConflict() {
        let finderNew = ShortcutItem(
            id: "finder.new",
            title: "New Finder Window",
            subtitle: "File → New Finder Window",
            category: "File",
            source: .appMenu,
            appBundleID: "com.apple.finder",
            appName: "Finder",
            combo: cmdN,
            isEnabled: true
        )
        let safariNew = ShortcutItem(
            id: "safari.new",
            title: "New Window",
            subtitle: "File → New Window",
            category: "File",
            source: .appMenu,
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            combo: cmdN,
            isEnabled: true
        )

        // Also include disabled conflicting item (must be ignored)
        let disabledSys = ShortcutItem(
            id: "sys.disabled",
            title: "Disabled Global",
            subtitle: "System",
            category: "System",
            source: .systemSymbolic,
            appName: "macOS",
            combo: cmdN,
            isEnabled: false
        )

        let conflicts = ConflictDetector.detect(in: [finderNew, safariNew, disabledSys])
        #expect(conflicts.isEmpty)
    }

    @Test("Sorts conflicts by severity descending: critical -> warning -> info")
    func sortsBySeverityDescending() {
        let infoItems = [
            ShortcutItem(
                id: "dt.1", title: "c1", subtitle: "", category: "VS Code",
                source: .devTool, appBundleID: "com.microsoft.VSCode", appName: "VS Code",
                combo: KeyCombo(keyCode: 0, modifiers: [.command]),
                metadata: ["toolID": "vscode", "when": "a"]
            ),
            ShortcutItem(
                id: "dt.2", title: "c2", subtitle: "", category: "VS Code",
                source: .devTool, appBundleID: "com.microsoft.VSCode", appName: "VS Code",
                combo: KeyCombo(keyCode: 0, modifiers: [.command]),
                metadata: ["toolID": "vscode", "when": "b"]
            )
        ]
        let warningItems = [
            ShortcutItem(
                id: "sys.w", title: "w1", subtitle: "", category: "System",
                source: .systemSymbolic, appName: "macOS",
                combo: KeyCombo(keyCode: 11, modifiers: [.command])
            ),
            ShortcutItem(
                id: "app.w", title: "w2", subtitle: "", category: "File",
                source: .appMenu, appBundleID: "com.apple.Safari", appName: "Safari",
                combo: KeyCombo(keyCode: 11, modifiers: [.command])
            )
        ]
        let criticalItems = [
            ShortcutItem(
                id: "sys.c1", title: "c1", subtitle: "", category: "System",
                source: .systemSymbolic, appName: "macOS",
                combo: KeyCombo(keyCode: 8, modifiers: [.command])
            ),
            ShortcutItem(
                id: "sys.c2", title: "c2", subtitle: "", category: "System",
                source: .systemSymbolic, appName: "macOS",
                combo: KeyCombo(keyCode: 8, modifiers: [.command])
            )
        ]

        let conflicts = ConflictDetector.detect(in: infoItems + warningItems + criticalItems)
        #expect(conflicts.map(\.severity) == [.critical, .warning, .info])
    }

    @Test("Global NSGlobalDomain and global comboRemap trigger warning against appMenu, while app-scoped comboRemap does not conflict with another app")
    func globalVsScopedScopes() {
        let globalAppMenu = ShortcutItem(
            id: "global.menu",
            title: "Global Help",
            subtitle: "NSGlobalDomain",
            category: "全局菜单快捷键",
            source: .appMenu,
            appBundleID: "NSGlobalDomain",
            appName: "所有应用程序",
            combo: cmdN
        )
        let safariMenu = ShortcutItem(
            id: "safari.menu",
            title: "New Window",
            subtitle: "File → New Window",
            category: "File",
            source: .appMenu,
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            combo: cmdN
        )
        let globalVsLocal = ConflictDetector.detect(in: [globalAppMenu, safariMenu])
        #expect(globalVsLocal.count == 1)
        #expect(globalVsLocal[0].severity == .warning)

        let scopedCombo = ShortcutItem(
            id: "combo.finder",
            title: "Finder Only Remap",
            subtitle: "Finder",
            category: "组合改键",
            source: .comboRemap,
            appBundleID: "com.apple.finder",
            appName: "Finder",
            combo: cmdN,
            metadata: ["targetAppBundleID": "com.apple.finder"]
        )
        #expect(ConflictDetector.detect(in: [scopedCombo, safariMenu]).isEmpty)
    }
}
