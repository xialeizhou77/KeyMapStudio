import Foundation

public struct KeyDefinition: Codable, Hashable, Sendable {
    public let virtualKeyCode: UInt16
    public let label: String
    public let symbol: String
    public let ascii: Int
    public let nsUserKeyChar: String
    public let vsCodeName: String
    public let hidUsage: UInt64

    public init(
        virtualKeyCode: UInt16,
        label: String,
        symbol: String,
        ascii: Int,
        nsUserKeyChar: String,
        vsCodeName: String,
        hidUsage: UInt64
    ) {
        self.virtualKeyCode = virtualKeyCode
        self.label = label
        self.symbol = symbol
        self.ascii = ascii
        self.nsUserKeyChar = nsUserKeyChar
        self.vsCodeName = vsCodeName
        self.hidUsage = hidUsage
    }
}

public enum KeyCodeCatalog {
    public static let allKeys: [KeyDefinition] = [
        // Letters A-Z (Carbon HIToolbox ANSI keycodes, HID Keyboard Usage Page 0x07)
        KeyDefinition(virtualKeyCode: 0x00, label: "A", symbol: "A", ascii: 97, nsUserKeyChar: "a", vsCodeName: "a", hidUsage: 0x700000004),
        KeyDefinition(virtualKeyCode: 0x0B, label: "B", symbol: "B", ascii: 98, nsUserKeyChar: "b", vsCodeName: "b", hidUsage: 0x700000005),
        KeyDefinition(virtualKeyCode: 0x08, label: "C", symbol: "C", ascii: 99, nsUserKeyChar: "c", vsCodeName: "c", hidUsage: 0x700000006),
        KeyDefinition(virtualKeyCode: 0x02, label: "D", symbol: "D", ascii: 100, nsUserKeyChar: "d", vsCodeName: "d", hidUsage: 0x700000007),
        KeyDefinition(virtualKeyCode: 0x0E, label: "E", symbol: "E", ascii: 101, nsUserKeyChar: "e", vsCodeName: "e", hidUsage: 0x700000008),
        KeyDefinition(virtualKeyCode: 0x03, label: "F", symbol: "F", ascii: 102, nsUserKeyChar: "f", vsCodeName: "f", hidUsage: 0x700000009),
        KeyDefinition(virtualKeyCode: 0x05, label: "G", symbol: "G", ascii: 103, nsUserKeyChar: "g", vsCodeName: "g", hidUsage: 0x70000000A),
        KeyDefinition(virtualKeyCode: 0x04, label: "H", symbol: "H", ascii: 104, nsUserKeyChar: "h", vsCodeName: "h", hidUsage: 0x70000000B),
        KeyDefinition(virtualKeyCode: 0x22, label: "I", symbol: "I", ascii: 105, nsUserKeyChar: "i", vsCodeName: "i", hidUsage: 0x70000000C),
        KeyDefinition(virtualKeyCode: 0x26, label: "J", symbol: "J", ascii: 106, nsUserKeyChar: "j", vsCodeName: "j", hidUsage: 0x70000000D),
        KeyDefinition(virtualKeyCode: 0x28, label: "K", symbol: "K", ascii: 107, nsUserKeyChar: "k", vsCodeName: "k", hidUsage: 0x70000000E),
        KeyDefinition(virtualKeyCode: 0x25, label: "L", symbol: "L", ascii: 108, nsUserKeyChar: "l", vsCodeName: "l", hidUsage: 0x70000000F),
        KeyDefinition(virtualKeyCode: 0x2E, label: "M", symbol: "M", ascii: 109, nsUserKeyChar: "m", vsCodeName: "m", hidUsage: 0x700000010),
        KeyDefinition(virtualKeyCode: 0x2D, label: "N", symbol: "N", ascii: 110, nsUserKeyChar: "n", vsCodeName: "n", hidUsage: 0x700000011),
        KeyDefinition(virtualKeyCode: 0x1F, label: "O", symbol: "O", ascii: 111, nsUserKeyChar: "o", vsCodeName: "o", hidUsage: 0x700000012),
        KeyDefinition(virtualKeyCode: 0x23, label: "P", symbol: "P", ascii: 112, nsUserKeyChar: "p", vsCodeName: "p", hidUsage: 0x700000013),
        KeyDefinition(virtualKeyCode: 0x0C, label: "Q", symbol: "Q", ascii: 113, nsUserKeyChar: "q", vsCodeName: "q", hidUsage: 0x700000014),
        KeyDefinition(virtualKeyCode: 0x0F, label: "R", symbol: "R", ascii: 114, nsUserKeyChar: "r", vsCodeName: "r", hidUsage: 0x700000015),
        KeyDefinition(virtualKeyCode: 0x01, label: "S", symbol: "S", ascii: 115, nsUserKeyChar: "s", vsCodeName: "s", hidUsage: 0x700000016),
        KeyDefinition(virtualKeyCode: 0x11, label: "T", symbol: "T", ascii: 116, nsUserKeyChar: "t", vsCodeName: "t", hidUsage: 0x700000017),
        KeyDefinition(virtualKeyCode: 0x20, label: "U", symbol: "U", ascii: 117, nsUserKeyChar: "u", vsCodeName: "u", hidUsage: 0x700000018),
        KeyDefinition(virtualKeyCode: 0x09, label: "V", symbol: "V", ascii: 118, nsUserKeyChar: "v", vsCodeName: "v", hidUsage: 0x700000019),
        KeyDefinition(virtualKeyCode: 0x0D, label: "W", symbol: "W", ascii: 119, nsUserKeyChar: "w", vsCodeName: "w", hidUsage: 0x70000001A),
        KeyDefinition(virtualKeyCode: 0x07, label: "X", symbol: "X", ascii: 120, nsUserKeyChar: "x", vsCodeName: "x", hidUsage: 0x70000001B),
        KeyDefinition(virtualKeyCode: 0x10, label: "Y", symbol: "Y", ascii: 121, nsUserKeyChar: "y", vsCodeName: "y", hidUsage: 0x70000001C),
        KeyDefinition(virtualKeyCode: 0x06, label: "Z", symbol: "Z", ascii: 122, nsUserKeyChar: "z", vsCodeName: "z", hidUsage: 0x70000001D),

        // Digits 1-0
        KeyDefinition(virtualKeyCode: 0x12, label: "1", symbol: "1", ascii: 49, nsUserKeyChar: "1", vsCodeName: "1", hidUsage: 0x70000001E),
        KeyDefinition(virtualKeyCode: 0x13, label: "2", symbol: "2", ascii: 50, nsUserKeyChar: "2", vsCodeName: "2", hidUsage: 0x70000001F),
        KeyDefinition(virtualKeyCode: 0x14, label: "3", symbol: "3", ascii: 51, nsUserKeyChar: "3", vsCodeName: "3", hidUsage: 0x700000020),
        KeyDefinition(virtualKeyCode: 0x15, label: "4", symbol: "4", ascii: 52, nsUserKeyChar: "4", vsCodeName: "4", hidUsage: 0x700000021),
        KeyDefinition(virtualKeyCode: 0x17, label: "5", symbol: "5", ascii: 53, nsUserKeyChar: "5", vsCodeName: "5", hidUsage: 0x700000022),
        KeyDefinition(virtualKeyCode: 0x16, label: "6", symbol: "6", ascii: 54, nsUserKeyChar: "6", vsCodeName: "6", hidUsage: 0x700000023),
        KeyDefinition(virtualKeyCode: 0x1A, label: "7", symbol: "7", ascii: 55, nsUserKeyChar: "7", vsCodeName: "7", hidUsage: 0x700000024),
        KeyDefinition(virtualKeyCode: 0x1C, label: "8", symbol: "8", ascii: 56, nsUserKeyChar: "8", vsCodeName: "8", hidUsage: 0x700000025),
        KeyDefinition(virtualKeyCode: 0x19, label: "9", symbol: "9", ascii: 57, nsUserKeyChar: "9", vsCodeName: "9", hidUsage: 0x700000026),
        KeyDefinition(virtualKeyCode: 0x1D, label: "0", symbol: "0", ascii: 48, nsUserKeyChar: "0", vsCodeName: "0", hidUsage: 0x700000027),

        // Punctuation (-=[]\;',./ and `)
        KeyDefinition(virtualKeyCode: 0x1B, label: "-", symbol: "-", ascii: 45, nsUserKeyChar: "-", vsCodeName: "-", hidUsage: 0x70000002D),
        KeyDefinition(virtualKeyCode: 0x18, label: "=", symbol: "=", ascii: 61, nsUserKeyChar: "=", vsCodeName: "=", hidUsage: 0x70000002E),
        KeyDefinition(virtualKeyCode: 0x21, label: "[", symbol: "[", ascii: 91, nsUserKeyChar: "[", vsCodeName: "[", hidUsage: 0x70000002F),
        KeyDefinition(virtualKeyCode: 0x1E, label: "]", symbol: "]", ascii: 93, nsUserKeyChar: "]", vsCodeName: "]", hidUsage: 0x700000030),
        KeyDefinition(virtualKeyCode: 0x2A, label: "\\", symbol: "\\", ascii: 92, nsUserKeyChar: "\\", vsCodeName: "\\", hidUsage: 0x700000031),
        KeyDefinition(virtualKeyCode: 0x29, label: ";", symbol: ";", ascii: 59, nsUserKeyChar: ";", vsCodeName: ";", hidUsage: 0x700000033),
        KeyDefinition(virtualKeyCode: 0x27, label: "'", symbol: "'", ascii: 39, nsUserKeyChar: "'", vsCodeName: "'", hidUsage: 0x700000034),
        KeyDefinition(virtualKeyCode: 0x32, label: "`", symbol: "`", ascii: 96, nsUserKeyChar: "`", vsCodeName: "`", hidUsage: 0x700000035),
        KeyDefinition(virtualKeyCode: 0x2B, label: ",", symbol: ",", ascii: 44, nsUserKeyChar: ",", vsCodeName: ",", hidUsage: 0x700000036),
        KeyDefinition(virtualKeyCode: 0x2F, label: ".", symbol: ".", ascii: 46, nsUserKeyChar: ".", vsCodeName: ".", hidUsage: 0x700000037),
        KeyDefinition(virtualKeyCode: 0x2C, label: "/", symbol: "/", ascii: 47, nsUserKeyChar: "/", vsCodeName: "/", hidUsage: 0x700000038),

        // Primary Editing & Control Keys
        KeyDefinition(virtualKeyCode: 0x31, label: "Space", symbol: "Space", ascii: 32, nsUserKeyChar: " ", vsCodeName: "space", hidUsage: 0x70000002C),
        KeyDefinition(virtualKeyCode: 0x24, label: "Return", symbol: "↩", ascii: 13, nsUserKeyChar: "\r", vsCodeName: "enter", hidUsage: 0x700000028),
        KeyDefinition(virtualKeyCode: 0x30, label: "Tab", symbol: "⇥", ascii: 9, nsUserKeyChar: "\t", vsCodeName: "tab", hidUsage: 0x70000002B),
        KeyDefinition(virtualKeyCode: 0x33, label: "Delete", symbol: "⌫", ascii: 8, nsUserKeyChar: "\u{0008}", vsCodeName: "backspace", hidUsage: 0x70000002A),
        KeyDefinition(virtualKeyCode: 0x75, label: "Forward Delete", symbol: "⌦", ascii: 127, nsUserKeyChar: "\u{F728}", vsCodeName: "delete", hidUsage: 0x70000004C),
        KeyDefinition(virtualKeyCode: 0x35, label: "Escape", symbol: "⎋", ascii: 27, nsUserKeyChar: "\u{001B}", vsCodeName: "escape", hidUsage: 0x700000029),

        // Navigation & Arrow Keys
        KeyDefinition(virtualKeyCode: 0x7E, label: "Up Arrow", symbol: "↑", ascii: 65535, nsUserKeyChar: "\u{F700}", vsCodeName: "up", hidUsage: 0x700000052),
        KeyDefinition(virtualKeyCode: 0x7D, label: "Down Arrow", symbol: "↓", ascii: 65535, nsUserKeyChar: "\u{F701}", vsCodeName: "down", hidUsage: 0x700000051),
        KeyDefinition(virtualKeyCode: 0x7B, label: "Left Arrow", symbol: "←", ascii: 65535, nsUserKeyChar: "\u{F702}", vsCodeName: "left", hidUsage: 0x700000050),
        KeyDefinition(virtualKeyCode: 0x7C, label: "Right Arrow", symbol: "→", ascii: 65535, nsUserKeyChar: "\u{F703}", vsCodeName: "right", hidUsage: 0x70000004F),
        KeyDefinition(virtualKeyCode: 0x73, label: "Home", symbol: "↖", ascii: 65535, nsUserKeyChar: "\u{F729}", vsCodeName: "home", hidUsage: 0x70000004A),
        KeyDefinition(virtualKeyCode: 0x77, label: "End", symbol: "↘", ascii: 65535, nsUserKeyChar: "\u{F72B}", vsCodeName: "end", hidUsage: 0x70000004D),
        KeyDefinition(virtualKeyCode: 0x74, label: "Page Up", symbol: "⇞", ascii: 65535, nsUserKeyChar: "\u{F72C}", vsCodeName: "pageup", hidUsage: 0x70000004B),
        KeyDefinition(virtualKeyCode: 0x79, label: "Page Down", symbol: "⇟", ascii: 65535, nsUserKeyChar: "\u{F72D}", vsCodeName: "pagedown", hidUsage: 0x70000004E),

        // Function Keys F1-F12
        KeyDefinition(virtualKeyCode: 0x7A, label: "F1", symbol: "F1", ascii: 65535, nsUserKeyChar: "\u{F704}", vsCodeName: "f1", hidUsage: 0x70000003A),
        KeyDefinition(virtualKeyCode: 0x78, label: "F2", symbol: "F2", ascii: 65535, nsUserKeyChar: "\u{F705}", vsCodeName: "f2", hidUsage: 0x70000003B),
        KeyDefinition(virtualKeyCode: 0x63, label: "F3", symbol: "F3", ascii: 65535, nsUserKeyChar: "\u{F706}", vsCodeName: "f3", hidUsage: 0x70000003C),
        KeyDefinition(virtualKeyCode: 0x76, label: "F4", symbol: "F4", ascii: 65535, nsUserKeyChar: "\u{F707}", vsCodeName: "f4", hidUsage: 0x70000003D),
        KeyDefinition(virtualKeyCode: 0x60, label: "F5", symbol: "F5", ascii: 65535, nsUserKeyChar: "\u{F708}", vsCodeName: "f5", hidUsage: 0x70000003E),
        KeyDefinition(virtualKeyCode: 0x61, label: "F6", symbol: "F6", ascii: 65535, nsUserKeyChar: "\u{F709}", vsCodeName: "f6", hidUsage: 0x70000003F),
        KeyDefinition(virtualKeyCode: 0x62, label: "F7", symbol: "F7", ascii: 65535, nsUserKeyChar: "\u{F70A}", vsCodeName: "f7", hidUsage: 0x700000040),
        KeyDefinition(virtualKeyCode: 0x64, label: "F8", symbol: "F8", ascii: 65535, nsUserKeyChar: "\u{F70B}", vsCodeName: "f8", hidUsage: 0x700000041),
        KeyDefinition(virtualKeyCode: 0x65, label: "F9", symbol: "F9", ascii: 65535, nsUserKeyChar: "\u{F70C}", vsCodeName: "f9", hidUsage: 0x700000042),
        KeyDefinition(virtualKeyCode: 0x6D, label: "F10", symbol: "F10", ascii: 65535, nsUserKeyChar: "\u{F70D}", vsCodeName: "f10", hidUsage: 0x700000043),
        KeyDefinition(virtualKeyCode: 0x67, label: "F11", symbol: "F11", ascii: 65535, nsUserKeyChar: "\u{F70E}", vsCodeName: "f11", hidUsage: 0x700000044),
        KeyDefinition(virtualKeyCode: 0x6F, label: "F12", symbol: "F12", ascii: 65535, nsUserKeyChar: "\u{F70F}", vsCodeName: "f12", hidUsage: 0x700000045),

        // Caps Lock & Left/Right Modifier Keys
        KeyDefinition(virtualKeyCode: 0x39, label: "Caps Lock", symbol: "⇪", ascii: 65535, nsUserKeyChar: "", vsCodeName: "capslock", hidUsage: 0x700000039),
        KeyDefinition(virtualKeyCode: 0x38, label: "Left Shift", symbol: "⇧", ascii: 65535, nsUserKeyChar: "", vsCodeName: "shift", hidUsage: 0x7000000E1),
        KeyDefinition(virtualKeyCode: 0x3C, label: "Right Shift", symbol: "R⇧", ascii: 65535, nsUserKeyChar: "", vsCodeName: "rightshift", hidUsage: 0x7000000E5),
        KeyDefinition(virtualKeyCode: 0x3B, label: "Left Control", symbol: "⌃", ascii: 65535, nsUserKeyChar: "", vsCodeName: "ctrl", hidUsage: 0x7000000E0),
        KeyDefinition(virtualKeyCode: 0x3E, label: "Right Control", symbol: "R⌃", ascii: 65535, nsUserKeyChar: "", vsCodeName: "rightctrl", hidUsage: 0x7000000E4),
        KeyDefinition(virtualKeyCode: 0x3A, label: "Left Option", symbol: "⌥", ascii: 65535, nsUserKeyChar: "", vsCodeName: "alt", hidUsage: 0x7000000E2),
        KeyDefinition(virtualKeyCode: 0x3D, label: "Right Option", symbol: "R⌥", ascii: 65535, nsUserKeyChar: "", vsCodeName: "rightalt", hidUsage: 0x7000000E6),
        KeyDefinition(virtualKeyCode: 0x37, label: "Left Command", symbol: "⌘", ascii: 65535, nsUserKeyChar: "", vsCodeName: "cmd", hidUsage: 0x7000000E3),
        KeyDefinition(virtualKeyCode: 0x36, label: "Right Command", symbol: "R⌘", ascii: 65535, nsUserKeyChar: "", vsCodeName: "rightcmd", hidUsage: 0x7000000E7),
    ]

    private static let byVirtualKey: [UInt16: KeyDefinition] = {
        Dictionary(allKeys.map { ($0.virtualKeyCode, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    private static let byHIDUsage: [UInt64: KeyDefinition] = {
        Dictionary(
            allKeys.filter { $0.hidUsage != 0 }.map { ($0.hidUsage, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    private static let byNSUserKeyChar: [String: KeyDefinition] = {
        var map: [String: KeyDefinition] = [:]
        for def in allKeys where !def.nsUserKeyChar.isEmpty {
            map[def.nsUserKeyChar] = def
        }
        // Common AppKit/HID equivalent char aliases
        if let delDef = byVirtualKey[0x33] {
            map["\u{007F}"] = delDef
        }
        if let retDef = byVirtualKey[0x24] {
            map["\n"] = retDef
            map["\u{0003}"] = retDef
        }
        if let tabDef = byVirtualKey[0x30] {
            map["\u{0019}"] = tabDef // BackTab (Shift+Tab)
        }
        return map
    }()

    private static let byVSCodeName: [String: KeyDefinition] = {
        var map: [String: KeyDefinition] = [:]
        for def in allKeys where !def.vsCodeName.isEmpty {
            map[def.vsCodeName.lowercased()] = def
        }
        // Common VS Code key aliases
        let aliases: [(String, UInt16)] = [
            ("esc", 0x35),
            ("return", 0x24),
            ("del", 0x75),
            ("spacebar", 0x31),
            ("uparrow", 0x7E),
            ("downarrow", 0x7D),
            ("leftarrow", 0x7B),
            ("rightarrow", 0x7C),
            ("pgup", 0x74),
            ("pgdn", 0x79),
            ("backquote", 0x32),
            ("grave", 0x32),
            ("tilde", 0x32),
            ("minus", 0x1B),
            ("equal", 0x18),
            ("equals", 0x18),
            ("plus", 0x18),
            ("+", 0x18),
            ("bracketleft", 0x21),
            ("bracketright", 0x1E),
            ("backslash", 0x2A),
            ("semicolon", 0x29),
            ("quote", 0x27),
            ("comma", 0x2B),
            ("period", 0x2F),
            ("slash", 0x2C),
        ]
        for (alias, vk) in aliases {
            if let def = byVirtualKey[vk] {
                map[alias] = def
            }
        }
        return map
    }()

    private static let shiftedCharToVirtualKey: [String: UInt16] = [
        "!": 0x12, "@": 0x13, "#": 0x14, "$": 0x15, "%": 0x17,
        "^": 0x16, "&": 0x1A, "*": 0x1C, "(": 0x19, ")": 0x1D,
        "_": 0x1B, "+": 0x18, "{": 0x21, "}": 0x1E, "|": 0x2A,
        ":": 0x29, "\"": 0x27, "~": 0x32, "<": 0x2B, ">": 0x2F,
        "?": 0x2C
    ]

    public static func definition(forVirtualKey code: UInt16) -> KeyDefinition? {
        byVirtualKey[code]
    }

    public static func definition(forNSUserKeyChar char: String) -> KeyDefinition? {
        if let direct = byNSUserKeyChar[char] {
            return direct
        }
        let lowered = char.lowercased()
        if lowered != char {
            return byNSUserKeyChar[lowered]
        }
        return nil
    }

    public static func definition(forVSCodeName name: String) -> KeyDefinition? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return byVSCodeName[trimmed]
    }

    public static func definition(forHIDUsage usage: UInt64) -> KeyDefinition? {
        byHIDUsage[usage]
    }

    public static func definition(forCharacter char: String) -> KeyDefinition? {
        if let direct = definition(forNSUserKeyChar: char) {
            return direct
        }
        let lowered = char.lowercased()
        if let def = byVSCodeName[lowered] {
            return def
        }
        if let vk = shiftedCharToVirtualKey[char], let def = byVirtualKey[vk] {
            return def
        }
        return allKeys.first {
            $0.label.caseInsensitiveCompare(char) == .orderedSame || $0.symbol == char
        }
    }
}
