import Foundation
import AppKit
import Carbon
import CoreGraphics

public struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt64

    public static let shift = KeyModifiers(rawValue: 1 << 17)
    public static let control = KeyModifiers(rawValue: 1 << 18)
    public static let option = KeyModifiers(rawValue: 1 << 19)
    public static let command = KeyModifiers(rawValue: 1 << 20)
    public static let function = KeyModifiers(rawValue: 1 << 23)

    public static let standardMask: KeyModifiers = [.shift, .control, .option, .command]
    private static let supportedMask: KeyModifiers = [.shift, .control, .option, .command, .function]

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public init(nsEventFlags: NSEvent.ModifierFlags) {
        var result: KeyModifiers = []
        if nsEventFlags.contains(.shift) { result.insert(.shift) }
        if nsEventFlags.contains(.control) { result.insert(.control) }
        if nsEventFlags.contains(.option) { result.insert(.option) }
        if nsEventFlags.contains(.command) { result.insert(.command) }
        if nsEventFlags.contains(.function) { result.insert(.function) }
        self = result
    }

    public init(cgEventFlags: CGEventFlags) {
        var result: KeyModifiers = []
        if cgEventFlags.contains(.maskShift) { result.insert(.shift) }
        if cgEventFlags.contains(.maskControl) { result.insert(.control) }
        if cgEventFlags.contains(.maskAlternate) { result.insert(.option) }
        if cgEventFlags.contains(.maskCommand) { result.insert(.command) }
        if cgEventFlags.contains(.maskSecondaryFn) { result.insert(.function) }
        self = result
    }

    public init(symbolicBitmask: UInt64) {
        self.rawValue = symbolicBitmask & Self.supportedMask.rawValue
    }

    /// Decodes Apple Accessibility `kAXMenuItemCmdModifiers` bitmask:
    /// bit 0 (1) = Shift, bit 1 (2) = Option, bit 2 (4) = Control, bit 3 (8) = NO Command.
    public init(axMenuModifiers: Int) {
        var result: KeyModifiers = []
        if (axMenuModifiers & (1 << 0)) != 0 { result.insert(.shift) }
        if (axMenuModifiers & (1 << 1)) != 0 { result.insert(.option) }
        if (axMenuModifiers & (1 << 2)) != 0 { result.insert(.control) }
        if (axMenuModifiers & (1 << 3)) == 0 { result.insert(.command) }
        self = result
    }

    public var cgEventFlags: CGEventFlags {
        var flags = CGEventFlags()
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    public var nsEventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.shift) { flags.insert(.shift) }
        if contains(.control) { flags.insert(.control) }
        if contains(.option) { flags.insert(.option) }
        if contains(.command) { flags.insert(.command) }
        if contains(.function) { flags.insert(.function) }
        return flags
    }

    public var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    /// Display symbols in canonical macOS order: ⌃⌥⇧⌘
    public var displaySymbols: String {
        var result = ""
        if contains(.control) { result.append("⌃") }
        if contains(.option) { result.append("⌥") }
        if contains(.shift) { result.append("⇧") }
        if contains(.command) { result.append("⌘") }
        return result
    }

    /// AppKit NSUserKeyEquivalents modifier prefix in order: ^~$@
    public var nsUserKeyPrefix: String {
        var result = ""
        if contains(.control) { result.append("^") }
        if contains(.option) { result.append("~") }
        if contains(.shift) { result.append("$") }
        if contains(.command) { result.append("@") }
        return result
    }

    /// VS Code modifier tokens in canonical order: ctrl, alt, shift, cmd
    public var vsCodeTokens: [String] {
        var tokens: [String] = []
        if contains(.control) { tokens.append("ctrl") }
        if contains(.option) { tokens.append("alt") }
        if contains(.shift) { tokens.append("shift") }
        if contains(.command) { tokens.append("cmd") }
        return tokens
    }
}

public struct KeyCombo: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var canonicalKey: String {
        "mod:\(modifiers.intersection(.standardMask).rawValue):vk:\(keyCode)"
    }

    public var keyDisplayName: String {
        KeyCodeCatalog.definition(forVirtualKey: keyCode)?.symbol ?? String(format: "VK(0x%02X)", keyCode)
    }

    public var displayString: String {
        modifiers.displaySymbols + keyDisplayName
    }

    public var asciiCode: Int {
        KeyCodeCatalog.definition(forVirtualKey: keyCode)?.ascii ?? 65535
    }

    public var nsUserKeyEquivalent: String {
        guard let keyChar = KeyCodeCatalog.definition(forVirtualKey: keyCode)?.nsUserKeyChar,
              !keyChar.isEmpty else {
            return ""
        }
        return modifiers.nsUserKeyPrefix + keyChar
    }

    public var vsCodeString: String {
        let keyToken = KeyCodeCatalog.definition(forVirtualKey: keyCode)?.vsCodeName ?? ""
        guard !keyToken.isEmpty else {
            return ""
        }
        return (modifiers.vsCodeTokens + [keyToken]).joined(separator: "+")
    }

    public static func parseNSUserKeyEquivalent(_ raw: String) -> KeyCombo? {
        guard !raw.isEmpty else { return nil }

        var modifiers: KeyModifiers = []
        var index = raw.startIndex

        // Consume modifier prefixes while more than 1 character remains so a trailing key is preserved.
        while raw.distance(from: index, to: raw.endIndex) > 1 {
            let ch = raw[index]
            switch ch {
            case "@": modifiers.insert(.command)
            case "~": modifiers.insert(.option)
            case "$": modifiers.insert(.shift)
            case "^": modifiers.insert(.control)
            default:
                break
            }
            if ch == "@" || ch == "~" || ch == "$" || ch == "^" {
                index = raw.index(after: index)
            } else {
                break
            }
        }

        let keyPart = String(raw[index...])
        guard keyPart.count == 1 else { return nil }

        if let scalar = keyPart.unicodeScalars.first,
           scalar.value >= 0x41 && scalar.value <= 0x5A {
            // AppKit treats uppercase ASCII letters in NSUserKeyEquivalents as implying Shift.
            modifiers.insert(.shift)
        }

        guard let def = KeyCodeCatalog.definition(forNSUserKeyChar: keyPart) else {
            return nil
        }
        return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
    }

    public static func parseVSCode(_ raw: String) -> KeyCombo? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Multi-key chords (e.g. "ctrl+k ctrl+s") are not single KeyCombos.
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return nil
        }

        let lowered = trimmed.lowercased()
        var tokens: [String]
        if lowered == "+" {
            tokens = ["+"]
        } else if lowered.hasSuffix("++") {
            let prefix = String(lowered.dropLast(2))
            tokens = prefix.split(separator: "+", omittingEmptySubsequences: true).map(String.init)
            tokens.append("+")
        } else {
            tokens = lowered.split(separator: "+", omittingEmptySubsequences: true).map(String.init)
        }

        guard !tokens.isEmpty else { return nil }

        var modifiers: KeyModifiers = []
        var keyToken: String?

        for (idx, token) in tokens.enumerated() {
            let isLast = (idx == tokens.count - 1)
            switch token {
            case "cmd", "command", "meta", "super", "win":
                if isLast { return nil }
                modifiers.insert(.command)
            case "alt", "opt", "option":
                if isLast { return nil }
                modifiers.insert(.option)
            case "ctrl", "control":
                if isLast { return nil }
                modifiers.insert(.control)
            case "shift":
                if isLast { return nil }
                modifiers.insert(.shift)
            case "fn":
                if isLast { return nil }
                modifiers.insert(.function)
            default:
                if !isLast {
                    return nil
                }
                keyToken = token
            }
        }

        guard let finalKey = keyToken,
              let def = KeyCodeCatalog.definition(forVSCodeName: finalKey) else {
            return nil
        }
        return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
    }

    public static func fromAX(cmdChar: String?, virtualKey: Int?, axModifiers: Int) -> KeyCombo? {
        let modifiers = KeyModifiers(axMenuModifiers: axModifiers)

        if let cmdChar, !cmdChar.isEmpty {
            if let def = KeyCodeCatalog.definition(forNSUserKeyChar: cmdChar) {
                return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
            }
            if let def = KeyCodeCatalog.definition(forCharacter: cmdChar) {
                return KeyCombo(keyCode: def.virtualKeyCode, modifiers: modifiers)
            }
        }

        if let virtualKey, virtualKey >= 0, virtualKey <= Int(UInt16.max) {
            let code = UInt16(virtualKey)
            if KeyCodeCatalog.definition(forVirtualKey: code) != nil || (cmdChar?.isEmpty ?? true) {
                return KeyCombo(keyCode: code, modifiers: modifiers)
            }
        }

        return nil
    }
}
