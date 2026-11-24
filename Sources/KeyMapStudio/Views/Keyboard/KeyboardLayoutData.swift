import Foundation
import KeyMapCore

/// Physical keycap metadata for rendering a Mac ANSI 78-key layout.
struct KeyboardKeyCap: Identifiable, Hashable, Sendable {
    let id: String
    let virtualKeyCode: UInt16
    let primaryLabel: String
    let secondaryLabel: String?
    let widthUnits: Double
    let isModifier: Bool
    let modifierFlag: KeyModifiers
    let isBindable: Bool

    init(
        id: String,
        virtualKeyCode: UInt16,
        primaryLabel: String,
        secondaryLabel: String? = nil,
        widthUnits: Double = 1.0,
        isModifier: Bool = false,
        modifierFlag: KeyModifiers = [],
        isBindable: Bool = true
    ) {
        self.id = id
        self.virtualKeyCode = virtualKeyCode
        self.primaryLabel = primaryLabel
        self.secondaryLabel = secondaryLabel
        self.widthUnits = widthUnits
        self.isModifier = isModifier
        self.modifierFlag = modifierFlag
        self.isBindable = isBindable
    }
}

/// Either a single full-height keycap or a vertically stacked arrow pair (Up/Down).
enum KeyboardRowSlot: Identifiable, Hashable, Sendable {
    case single(KeyboardKeyCap)
    case stackedPair(top: KeyboardKeyCap, bottom: KeyboardKeyCap)

    var id: String {
        switch self {
        case .single(let key):
            return key.id
        case .stackedPair(let top, let bottom):
            return "\(top.id)_\(bottom.id)"
        }
    }

    var widthUnits: Double {
        switch self {
        case .single(let key):
            return key.widthUnits
        case .stackedPair(let top, _):
            return top.widthUnits
        }
    }

    var keys: [KeyboardKeyCap] {
        switch self {
        case .single(let key):
            return [key]
        case .stackedPair(let top, let bottom):
            return [top, bottom]
        }
    }
}

struct KeyboardRow: Identifiable, Hashable, Sendable {
    let id: Int
    let heightUnits: Double
    let slots: [KeyboardRowSlot]
}

/// Full Mac ANSI 78-key layout across 6 rows. Total width per row = 14.5 units.
enum KeyboardLayoutData {
    static let totalRowUnits: Double = 14.5

    static let rows: [KeyboardRow] = [
        // Row 0: Esc + F1-F12 + Power/Lock (14 keys, 14.5 units)
        KeyboardRow(
            id: 0,
            heightUnits: 0.74,
            slots: [
                .single(KeyboardKeyCap(id: "r0_esc", virtualKeyCode: 53, primaryLabel: "esc", widthUnits: 1.5)),
                .single(KeyboardKeyCap(id: "r0_f1", virtualKeyCode: 122, primaryLabel: "F1", secondaryLabel: "☀︎")),
                .single(KeyboardKeyCap(id: "r0_f2", virtualKeyCode: 120, primaryLabel: "F2", secondaryLabel: "☼")),
                .single(KeyboardKeyCap(id: "r0_f3", virtualKeyCode: 99, primaryLabel: "F3", secondaryLabel: "⊞")),
                .single(KeyboardKeyCap(id: "r0_f4", virtualKeyCode: 118, primaryLabel: "F4", secondaryLabel: "⌕")),
                .single(KeyboardKeyCap(id: "r0_f5", virtualKeyCode: 96, primaryLabel: "F5", secondaryLabel: "🎙")),
                .single(KeyboardKeyCap(id: "r0_f6", virtualKeyCode: 97, primaryLabel: "F6", secondaryLabel: "☾")),
                .single(KeyboardKeyCap(id: "r0_f7", virtualKeyCode: 98, primaryLabel: "F7", secondaryLabel: "⏮")),
                .single(KeyboardKeyCap(id: "r0_f8", virtualKeyCode: 100, primaryLabel: "F8", secondaryLabel: "⏯")),
                .single(KeyboardKeyCap(id: "r0_f9", virtualKeyCode: 101, primaryLabel: "F9", secondaryLabel: "⏭")),
                .single(KeyboardKeyCap(id: "r0_f10", virtualKeyCode: 109, primaryLabel: "F10", secondaryLabel: "🔇")),
                .single(KeyboardKeyCap(id: "r0_f11", virtualKeyCode: 103, primaryLabel: "F11", secondaryLabel: "🔉")),
                .single(KeyboardKeyCap(id: "r0_f12", virtualKeyCode: 111, primaryLabel: "F12", secondaryLabel: "🔊")),
                .single(KeyboardKeyCap(id: "r0_lock", virtualKeyCode: UInt16.max, primaryLabel: "⏻", isBindable: false)),
            ]
        ),
        // Row 1: `~ 1-0 - = Delete (14 keys, 14.5 units)
        KeyboardRow(
            id: 1,
            heightUnits: 1.0,
            slots: [
                .single(KeyboardKeyCap(id: "r1_grave", virtualKeyCode: 50, primaryLabel: "`", secondaryLabel: "~")),
                .single(KeyboardKeyCap(id: "r1_1", virtualKeyCode: 18, primaryLabel: "1", secondaryLabel: "!")),
                .single(KeyboardKeyCap(id: "r1_2", virtualKeyCode: 19, primaryLabel: "2", secondaryLabel: "@")),
                .single(KeyboardKeyCap(id: "r1_3", virtualKeyCode: 20, primaryLabel: "3", secondaryLabel: "#")),
                .single(KeyboardKeyCap(id: "r1_4", virtualKeyCode: 21, primaryLabel: "4", secondaryLabel: "$")),
                .single(KeyboardKeyCap(id: "r1_5", virtualKeyCode: 23, primaryLabel: "5", secondaryLabel: "%")),
                .single(KeyboardKeyCap(id: "r1_6", virtualKeyCode: 22, primaryLabel: "6", secondaryLabel: "^")),
                .single(KeyboardKeyCap(id: "r1_7", virtualKeyCode: 26, primaryLabel: "7", secondaryLabel: "&")),
                .single(KeyboardKeyCap(id: "r1_8", virtualKeyCode: 28, primaryLabel: "8", secondaryLabel: "*")),
                .single(KeyboardKeyCap(id: "r1_9", virtualKeyCode: 25, primaryLabel: "9", secondaryLabel: "(")),
                .single(KeyboardKeyCap(id: "r1_0", virtualKeyCode: 29, primaryLabel: "0", secondaryLabel: ")")),
                .single(KeyboardKeyCap(id: "r1_minus", virtualKeyCode: 27, primaryLabel: "-", secondaryLabel: "_")),
                .single(KeyboardKeyCap(id: "r1_equal", virtualKeyCode: 24, primaryLabel: "=", secondaryLabel: "+")),
                .single(KeyboardKeyCap(id: "r1_delete", virtualKeyCode: 51, primaryLabel: "⌫", secondaryLabel: "delete", widthUnits: 1.5)),
            ]
        ),
        // Row 2: Tab Q-P [ ] \ (14 keys, 14.5 units)
        KeyboardRow(
            id: 2,
            heightUnits: 1.0,
            slots: [
                .single(KeyboardKeyCap(id: "r2_tab", virtualKeyCode: 48, primaryLabel: "⇥", secondaryLabel: "tab", widthUnits: 1.5)),
                .single(KeyboardKeyCap(id: "r2_q", virtualKeyCode: 12, primaryLabel: "Q")),
                .single(KeyboardKeyCap(id: "r2_w", virtualKeyCode: 13, primaryLabel: "W")),
                .single(KeyboardKeyCap(id: "r2_e", virtualKeyCode: 14, primaryLabel: "E")),
                .single(KeyboardKeyCap(id: "r2_r", virtualKeyCode: 15, primaryLabel: "R")),
                .single(KeyboardKeyCap(id: "r2_t", virtualKeyCode: 17, primaryLabel: "T")),
                .single(KeyboardKeyCap(id: "r2_y", virtualKeyCode: 16, primaryLabel: "Y")),
                .single(KeyboardKeyCap(id: "r2_u", virtualKeyCode: 32, primaryLabel: "U")),
                .single(KeyboardKeyCap(id: "r2_i", virtualKeyCode: 34, primaryLabel: "I")),
                .single(KeyboardKeyCap(id: "r2_o", virtualKeyCode: 31, primaryLabel: "O")),
                .single(KeyboardKeyCap(id: "r2_p", virtualKeyCode: 35, primaryLabel: "P")),
                .single(KeyboardKeyCap(id: "r2_lbracket", virtualKeyCode: 33, primaryLabel: "[", secondaryLabel: "{")),
                .single(KeyboardKeyCap(id: "r2_rbracket", virtualKeyCode: 30, primaryLabel: "]", secondaryLabel: "}")),
                .single(KeyboardKeyCap(id: "r2_backslash", virtualKeyCode: 42, primaryLabel: "\\", secondaryLabel: "|")),
            ]
        ),
        // Row 3: Caps Lock A-L ; ' Return (13 keys, 14.5 units)
        KeyboardRow(
            id: 3,
            heightUnits: 1.0,
            slots: [
                .single(KeyboardKeyCap(id: "r3_caps", virtualKeyCode: 57, primaryLabel: "⇪", secondaryLabel: "caps lock", widthUnits: 1.75)),
                .single(KeyboardKeyCap(id: "r3_a", virtualKeyCode: 0, primaryLabel: "A")),
                .single(KeyboardKeyCap(id: "r3_s", virtualKeyCode: 1, primaryLabel: "S")),
                .single(KeyboardKeyCap(id: "r3_d", virtualKeyCode: 2, primaryLabel: "D")),
                .single(KeyboardKeyCap(id: "r3_f", virtualKeyCode: 3, primaryLabel: "F")),
                .single(KeyboardKeyCap(id: "r3_g", virtualKeyCode: 5, primaryLabel: "G")),
                .single(KeyboardKeyCap(id: "r3_h", virtualKeyCode: 4, primaryLabel: "H")),
                .single(KeyboardKeyCap(id: "r3_j", virtualKeyCode: 38, primaryLabel: "J")),
                .single(KeyboardKeyCap(id: "r3_k", virtualKeyCode: 40, primaryLabel: "K")),
                .single(KeyboardKeyCap(id: "r3_l", virtualKeyCode: 37, primaryLabel: "L")),
                .single(KeyboardKeyCap(id: "r3_semicolon", virtualKeyCode: 41, primaryLabel: ";", secondaryLabel: ":")),
                .single(KeyboardKeyCap(id: "r3_quote", virtualKeyCode: 39, primaryLabel: "'", secondaryLabel: "\"")),
                .single(KeyboardKeyCap(id: "r3_return", virtualKeyCode: 36, primaryLabel: "↩", secondaryLabel: "return", widthUnits: 1.75)),
            ]
        ),
        // Row 4: Shift Z-M , . / Shift (12 keys, 14.5 units)
        KeyboardRow(
            id: 4,
            heightUnits: 1.0,
            slots: [
                .single(KeyboardKeyCap(id: "r4_lshift", virtualKeyCode: 56, primaryLabel: "⇧", secondaryLabel: "shift", widthUnits: 2.25, isModifier: true, modifierFlag: .shift)),
                .single(KeyboardKeyCap(id: "r4_z", virtualKeyCode: 6, primaryLabel: "Z")),
                .single(KeyboardKeyCap(id: "r4_x", virtualKeyCode: 7, primaryLabel: "X")),
                .single(KeyboardKeyCap(id: "r4_c", virtualKeyCode: 8, primaryLabel: "C")),
                .single(KeyboardKeyCap(id: "r4_v", virtualKeyCode: 9, primaryLabel: "V")),
                .single(KeyboardKeyCap(id: "r4_b", virtualKeyCode: 11, primaryLabel: "B")),
                .single(KeyboardKeyCap(id: "r4_n", virtualKeyCode: 45, primaryLabel: "N")),
                .single(KeyboardKeyCap(id: "r4_m", virtualKeyCode: 46, primaryLabel: "M")),
                .single(KeyboardKeyCap(id: "r4_comma", virtualKeyCode: 43, primaryLabel: ",", secondaryLabel: "<")),
                .single(KeyboardKeyCap(id: "r4_period", virtualKeyCode: 47, primaryLabel: ".", secondaryLabel: ">")),
                .single(KeyboardKeyCap(id: "r4_slash", virtualKeyCode: 44, primaryLabel: "/", secondaryLabel: "?")),
                .single(KeyboardKeyCap(id: "r4_rshift", virtualKeyCode: 60, primaryLabel: "⇧", secondaryLabel: "shift", widthUnits: 2.25, isModifier: true, modifierFlag: .shift)),
            ]
        ),
        // Row 5: Fn Ctrl Opt Cmd Space Cmd Opt + Arrow cluster (11 keys, 14.5 units)
        KeyboardRow(
            id: 5,
            heightUnits: 1.0,
            slots: [
                .single(KeyboardKeyCap(id: "r5_fn", virtualKeyCode: 63, primaryLabel: "🌐", secondaryLabel: "fn", widthUnits: 1.0, isModifier: true, modifierFlag: .function)),
                .single(KeyboardKeyCap(id: "r5_ctrl", virtualKeyCode: 59, primaryLabel: "⌃", secondaryLabel: "control", widthUnits: 1.0, isModifier: true, modifierFlag: .control)),
                .single(KeyboardKeyCap(id: "r5_lopt", virtualKeyCode: 58, primaryLabel: "⌥", secondaryLabel: "option", widthUnits: 1.0, isModifier: true, modifierFlag: .option)),
                .single(KeyboardKeyCap(id: "r5_lcmd", virtualKeyCode: 55, primaryLabel: "⌘", secondaryLabel: "command", widthUnits: 1.125, isModifier: true, modifierFlag: .command)),
                .single(KeyboardKeyCap(id: "r5_space", virtualKeyCode: 49, primaryLabel: "space", widthUnits: 5.25)),
                .single(KeyboardKeyCap(id: "r5_rcmd", virtualKeyCode: 54, primaryLabel: "⌘", secondaryLabel: "command", widthUnits: 1.125, isModifier: true, modifierFlag: .command)),
                .single(KeyboardKeyCap(id: "r5_ropt", virtualKeyCode: 61, primaryLabel: "⌥", secondaryLabel: "option", widthUnits: 1.0, isModifier: true, modifierFlag: .option)),
                .single(KeyboardKeyCap(id: "r5_left", virtualKeyCode: 123, primaryLabel: "◀", widthUnits: 1.0)),
                .stackedPair(
                    top: KeyboardKeyCap(id: "r5_up", virtualKeyCode: 126, primaryLabel: "▲", widthUnits: 1.0),
                    bottom: KeyboardKeyCap(id: "r5_down", virtualKeyCode: 125, primaryLabel: "▼", widthUnits: 1.0)
                ),
                .single(KeyboardKeyCap(id: "r5_right", virtualKeyCode: 124, primaryLabel: "▶", widthUnits: 1.0)),
            ]
        ),
    ]

    static let allKeys: [KeyboardKeyCap] = rows.flatMap { row in
        row.slots.flatMap(\.keys)
    }

    static func keyCap(forVirtualKey code: UInt16) -> KeyboardKeyCap? {
        allKeys.first { $0.isBindable && $0.virtualKeyCode == code }
    }
}
