import SwiftUI
import AppKit
import KeyMapCore

struct ShortcutRecorderView: View {
    @Binding var combo: KeyCombo?
    let allowEmpty: Bool
    let placeholder: String
    let onRecordingChanged: ((Bool) -> Void)?
    let onCommit: ((KeyCombo?) -> Void)?

    @State private var isRecording: Bool = false
    @State private var liveModifiers: KeyModifiers = []

    init(
        combo: Binding<KeyCombo?>,
        allowEmpty: Bool = false,
        placeholder: String = "点击录制快捷键",
        onRecordingChanged: ((Bool) -> Void)? = nil,
        onCommit: ((KeyCombo?) -> Void)? = nil
    ) {
        self._combo = combo
        self.allowEmpty = allowEmpty
        self.placeholder = placeholder
        self.onRecordingChanged = onRecordingChanged
        self.onCommit = onCommit
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RecorderCaptureRepresentable(
                    isRecording: $isRecording,
                    liveModifiers: $liveModifiers,
                    allowEmpty: allowEmpty,
                    onCapture: { captured in
                        combo = captured
                        setRecording(false)
                        onCommit?(captured)
                    },
                    onClear: {
                        combo = nil
                        setRecording(false)
                        onCommit?(nil)
                    },
                    onCancel: {
                        setRecording(false)
                    },
                    onRecordingChanged: { active in
                        if isRecording != active {
                            isRecording = active
                        }
                        if !active {
                            liveModifiers = []
                        }
                        onRecordingChanged?(active)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                contentView
                    .allowsHitTesting(false)
            }
            .frame(minWidth: 112, minHeight: 30)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isRecording
                          ? Color.accentColor.opacity(0.10)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isRecording ? Color.accentColor : Color.secondary.opacity(0.28),
                        lineWidth: isRecording ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if allowEmpty, combo != nil, !isRecording {
                Button {
                    combo = nil
                    onCommit?(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除快捷键")
            }
        }
        .onDisappear {
            if isRecording {
                setRecording(false)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isRecording {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                if liveModifiers.intersection(.standardMask).isEmpty {
                    Text("请按下快捷键 (Esc 取消)…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(liveModifiers.displaySymbols) …")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
            }
        } else if let combo {
            KeyCapBadge(combo: combo, size: .regular)
        } else {
            Text(placeholder)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func setRecording(_ active: Bool) {
        if isRecording != active {
            isRecording = active
            if !active {
                liveModifiers = []
            }
            onRecordingChanged?(active)
        }
    }
}

private struct RecorderCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var liveModifiers: KeyModifiers
    let allowEmpty: Bool
    let onCapture: (KeyCombo) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void
    let onRecordingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> RecorderCaptureNSView {
        let view = RecorderCaptureNSView()
        syncCallbacks(to: view)
        return view
    }

    func updateNSView(_ nsView: RecorderCaptureNSView, context: Context) {
        syncCallbacks(to: nsView)
        nsView.allowEmpty = allowEmpty
        if nsView.isRecording != isRecording {
            nsView.isRecording = isRecording
            if isRecording {
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(nsView)
                }
            } else if nsView.window?.firstResponder === nsView {
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(nil)
                }
            }
        }
    }

    private func syncCallbacks(to view: RecorderCaptureNSView) {
        view.onCapture = onCapture
        view.onClear = onClear
        view.onCancel = onCancel
        view.onLiveModifiersChanged = { mods in
            DispatchQueue.main.async {
                self.liveModifiers = mods
            }
        }
        view.onRecordingChanged = { active in
            DispatchQueue.main.async {
                self.onRecordingChanged(active)
            }
        }
    }
}

private final class RecorderCaptureNSView: NSView {
    var isRecording: Bool = false
    var allowEmpty: Bool = false
    var onCapture: ((KeyCombo) -> Void)?
    var onClear: (() -> Void)?
    var onCancel: (() -> Void)?
    var onLiveModifiersChanged: ((KeyModifiers) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let next = !isRecording
        isRecording = next
        if next {
            window?.makeFirstResponder(self)
        } else if window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
        onRecordingChanged?(next)
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            onRecordingChanged?(false)
        }
        return super.resignFirstResponder()
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        let mods = KeyModifiers(nsEventFlags: event.modifierFlags).intersection(.standardMask)
        onLiveModifiersChanged?(mods)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        handleKeyEvent(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handleKeyEvent(event)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let mods = KeyModifiers(nsEventFlags: event.modifierFlags).intersection(.standardMask)
        let keyCode = event.keyCode

        // Escape without modifiers always cancels recording
        if keyCode == 53 && mods.isEmpty {
            isRecording = false
            onCancel?()
            if window?.firstResponder === self {
                window?.makeFirstResponder(nil)
            }
            return
        }

        // Bare Backspace clears when allowEmpty is enabled
        if keyCode == 51 && mods.isEmpty && allowEmpty {
            isRecording = false
            onClear?()
            if window?.firstResponder === self {
                window?.makeFirstResponder(nil)
            }
            return
        }

        // Ignore pure modifier key presses
        if isPureModifierKeyCode(keyCode) {
            return
        }

        // Require either a modifier or a non-typing special/function key
        guard !mods.isEmpty || isStandaloneBindableKeyCode(keyCode) else {
            NSSound.beep()
            return
        }

        let captured = KeyCombo(keyCode: keyCode, modifiers: mods)
        isRecording = false
        onCapture?(captured)
        if window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
    }

    private func isPureModifierKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63:
            return true
        default:
            return false
        }
    }

    private func isStandaloneBindableKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        // F1-F12, F13-F20, Navigation & special keys
        case 64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105, 106, 107,
             109, 111, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,
             123, 124, 125, 126:
            return true
        default:
            return false
        }
    }
}
