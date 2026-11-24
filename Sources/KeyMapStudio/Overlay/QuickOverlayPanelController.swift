import AppKit
import SwiftUI
import KeyMapCore

@MainActor
final class QuickOverlayPanelController {
    private let appState: AppState
    private var panel: OverlayFloatingPanel?
    private var resignKeyObserver: NSObjectProtocol?
    private var escapeMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    deinit {
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // Capture frontmost application BEFORE showing our floating panel
        let capturedApp = captureFrontmostExternalApp()

        let panel = ensurePanel()
        positionPanelOnActiveScreen(panel)

        Task { @MainActor [weak self] in
            await self?.appState.scanFrontmostAppForOverlay(capturedApp)
        }

        installEscapeMonitor()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        removeEscapeMonitor()
        panel?.orderOut(nil)
    }

    private func captureFrontmostExternalApp() -> RunningAppInfo? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let bundleID = front.bundleIdentifier else {
            return nil
        }
        return RunningAppInfo(
            pid: front.processIdentifier,
            bundleID: bundleID,
            name: front.localizedName ?? bundleID,
            isActive: true
        )
    }

    private func ensurePanel() -> OverlayFloatingPanel {
        if let existing = panel {
            return existing
        }

        let created = OverlayFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 520),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        created.isFloatingPanel = true
        created.level = .floating
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        created.isOpaque = false
        created.backgroundColor = .clear
        created.hasShadow = true
        created.hidesOnDeactivate = false
        created.isMovableByWindowBackground = true
        created.onEscape = { [weak self] in
            self?.hide()
        }

        let rootView = QuickOverlayView(appState: appState) { [weak self] in
            self?.hide()
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        created.contentView = hostingView

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: created,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }

        self.panel = created
        return created
    }

    private func positionPanelOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visibleFrame = targetScreen?.visibleFrame else {
            panel.center()
            return
        }
        let panelSize = panel.frame.size
        let originX = visibleFrame.midX - panelSize.width / 2
        let originY = visibleFrame.midY - panelSize.height / 2 + 40
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if event.keyCode == 53 && KeyModifiers(nsEventFlags: event.modifierFlags).intersection(.standardMask).isEmpty {
                Task { @MainActor in
                    self.hide()
                }
                return nil
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }
}

private final class OverlayFloatingPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}
