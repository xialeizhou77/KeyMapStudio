import SwiftUI
import AppKit
import KeyMapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let hotKeyManager = GlobalHotKeyManager()
    lazy var overlayController = QuickOverlayPanelController(appState: appState)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        appState.onOverlayHotKeyChanged = { [weak self] combo in
            guard let self else { return }
            let ok = self.hotKeyManager.register(combo: combo)
            if !ok {
                self.appState.showBanner("注册全局呼出快捷键 \(combo.displayString) 失败，可能已被其他应用占用", isError: true)
            }
        }

        appState.onToggleOverlay = { [weak self] in
            self?.overlayController.toggle()
        }

        hotKeyManager.onTrigger = { [weak self] in
            self?.overlayController.toggle()
        }

        _ = hotKeyManager.register(combo: appState.overlayHotKey)

        Task { @MainActor [weak self] in
            await self?.appState.refreshAll()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let existing = sender.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey && $0.title == "KeyMapStudio" }) {
                if existing.isMiniaturized { existing.deminiaturize(nil) }
                existing.makeKeyAndOrderFront(nil)
            } else {
                appState.onOpenMainWindow?()
            }
        }
        return true
    }
}

@main
struct KeyMapStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("KeyMapStudio", id: "main") {
            MainStudioView(appState: appDelegate.appState)
                .frame(minWidth: 1080, minHeight: 680)
                .onAppear {
                    appDelegate.appState.onOpenMainWindow = { [openWindow] in
                        Task { @MainActor in
                            if let existing = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey && $0.title == "KeyMapStudio" }) {
                                if existing.isMiniaturized { existing.deminiaturize(nil) }
                                NSApp.activate(ignoringOtherApps: true)
                                existing.makeKeyAndOrderFront(nil)
                            } else {
                                NSApp.activate(ignoringOtherApps: true)
                                openWindow(id: "main")
                            }
                        }
                    }
                }
        }
        .defaultSize(width: 1240, height: 780)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新全部快捷键") {
                    Task { await appDelegate.appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("打开/隐藏快捷浮窗") {
                    appDelegate.overlayController.toggle()
                }
            }
        }

        MenuBarExtra {
            Button("打开快捷浮窗 (\(appDelegate.appState.overlayHotKey.displayString))") {
                appDelegate.overlayController.toggle()
            }

            Button("打开主窗口") {
                activateMainWindow()
            }

            Divider()

            let totalConflicts = appDelegate.appState.conflicts.count
            let criticalConflicts = appDelegate.appState.conflicts.filter { $0.severity == .critical }.count
            Button(criticalConflicts > 0
                   ? "冲突中心：\(totalConflicts) 项（高危 \(criticalConflicts)）"
                   : "冲突中心：\(totalConflicts) 项") {
                appDelegate.appState.selectedSection = .conflicts
                activateMainWindow()
            }

            Divider()

            Button(appDelegate.appState.isComboRemapRunning
                   ? "停止组合键重映射引擎"
                   : "启动组合键重映射引擎") {
                appDelegate.appState.toggleComboRemapEngine(!appDelegate.appState.isComboRemapRunning)
            }

            if appDelegate.appState.isComboRemapRunning {
                Button("紧急停止所有组合键改键") {
                    appDelegate.appState.toggleComboRemapEngine(false)
                }
            }

            Button("刷新全部快捷键") {
                Task { await appDelegate.appState.refreshAll() }
            }

            Divider()

            Button("退出 KeyMapStudio") {
                NSApp.terminate(nil)
            }
        } label: {
            let criticalCount = appDelegate.appState.conflicts.filter { $0.severity == .critical }.count
            HStack(spacing: 4) {
                Image(systemName: "command.square.fill")
                if criticalCount > 0 {
                    Text("\(criticalCount)")
                }
            }
        }
    }

    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeKey && $0.title == "KeyMapStudio" }) {
            if existing.isMiniaturized { existing.deminiaturize(nil) }
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
