import Foundation
import Testing
@testable import KeyMapCore

@Suite("KeyCode & KeyCombo Tests")
struct KeyComboTests {
    @Test("KeyCodeCatalog lookups cover letters, F1-F12, Space, Escape, and HID usages")
    func catalogLookups() {
        // Letters
        let aDef = KeyCodeCatalog.definition(forVirtualKey: 0x00)
        #expect(aDef?.label == "A")
        #expect(aDef?.vsCodeName == "a")
        #expect(aDef?.hidUsage == 0x700000004)
        #expect(KeyCodeCatalog.definition(forHIDUsage: 0x700000004)?.virtualKeyCode == 0x00)

        let kDef = KeyCodeCatalog.definition(forVSCodeName: "K")
        #expect(kDef?.virtualKeyCode == 40)
        #expect(kDef?.nsUserKeyChar == "k")
        #expect(KeyCodeCatalog.definition(forNSUserKeyChar: "k")?.virtualKeyCode == 40)
        #expect(KeyCodeCatalog.definition(forCharacter: "k")?.virtualKeyCode == 40)

        // F1-F12
        let expectedFKeys: [(name: String, vk: UInt16, userChar: String, hid: UInt64)] = [
            ("f1", 0x7A, "\u{F704}", 0x70000003A),
            ("f2", 0x78, "\u{F705}", 0x70000003B),
            ("f3", 0x63, "\u{F706}", 0x70000003C),
            ("f4", 0x76, "\u{F707}", 0x70000003D),
            ("f5", 0x60, "\u{F708}", 0x70000003E),
            ("f6", 0x61, "\u{F709}", 0x70000003F),
            ("f7", 0x62, "\u{F70A}", 0x700000040),
            ("f8", 0x64, "\u{F70B}", 0x700000041),
            ("f9", 0x65, "\u{F70C}", 0x700000042),
            ("f10", 0x6D, "\u{F70D}", 0x700000043),
            ("f11", 0x67, "\u{F70E}", 0x700000044),
            ("f12", 0x6F, "\u{F70F}", 0x700000045),
        ]

        for entry in expectedFKeys {
            let byName = KeyCodeCatalog.definition(forVSCodeName: entry.name)
            let byVK = KeyCodeCatalog.definition(forVirtualKey: entry.vk)
            let byUserChar = KeyCodeCatalog.definition(forNSUserKeyChar: entry.userChar)
            let byHID = KeyCodeCatalog.definition(forHIDUsage: entry.hid)
            #expect(byName?.virtualKeyCode == entry.vk)
            #expect(byVK?.vsCodeName == entry.name)
            #expect(byUserChar?.virtualKeyCode == entry.vk)
            #expect(byHID?.virtualKeyCode == entry.vk)
        }

        // Space & Escape
        let space = KeyCodeCatalog.definition(forVirtualKey: 0x31)
        #expect(space?.label == "Space")
        #expect(space?.ascii == 32)
        #expect(space?.nsUserKeyChar == " ")
        #expect(space?.vsCodeName == "space")
        #expect(space?.hidUsage == 0x70000002C)
        #expect(KeyCodeCatalog.definition(forHIDUsage: 0x70000002C)?.virtualKeyCode == 0x31)

        let esc = KeyCodeCatalog.definition(forVirtualKey: 0x35)
        #expect(esc?.label == "Escape")
        #expect(esc?.ascii == 27)
        #expect(esc?.nsUserKeyChar == "\u{001B}")
        #expect(esc?.vsCodeName == "escape")
        #expect(esc?.hidUsage == 0x700000029)
        #expect(KeyCodeCatalog.definition(forVSCodeName: "esc")?.virtualKeyCode == 0x35)
        #expect(KeyCodeCatalog.definition(forHIDUsage: 0x700000029)?.virtualKeyCode == 0x35)

        // Caps Lock & Modifier HID usages
        #expect(KeyCodeCatalog.definition(forHIDUsage: 0x700000039)?.virtualKeyCode == 0x39)
        #expect(KeyCodeCatalog.definition(forHIDUsage: 0x7000000E0)?.virtualKeyCode == 0x3B)
        #expect(KeyCodeCatalog.definition(forHIDUsage: 0x7000000E7)?.virtualKeyCode == 0x36)
    }

    @Test("KeyCombo displayString and canonicalKey formatting")
    func displayStringAndCanonicalKey() {
        let combo = KeyCombo(keyCode: 40, modifiers: [.option, .command])
        #expect(combo.displayString == "⌥⌘K")
        #expect(combo.canonicalKey == "mod:\(KeyModifiers([.option, .command]).rawValue):vk:40")

        // .function is excluded from canonicalKey (standardMask only)
        let withFn = KeyCombo(keyCode: 40, modifiers: [.option, .command, .function])
        #expect(withFn.canonicalKey == combo.canonicalKey)

        let allMods = KeyCombo(keyCode: 0x00, modifiers: [.command, .shift, .option, .control])
        #expect(allMods.displayString == "⌃⌥⇧⌘A")
    }

    @Test("NSUserKeyEquivalent round-trips including @~$^, F-keys, arrows, and Escape")
    func nsUserKeyEquivalentRoundTrips() {
        let cases: [(combo: KeyCombo, expectedRaw: String)] = [
            (KeyCombo(keyCode: 40, modifiers: [.control, .option, .shift, .command]), "^~$@k"),
            (KeyCombo(keyCode: 0x08, modifiers: [.command]), "@c"),
            (KeyCombo(keyCode: 0x01, modifiers: [.shift]), "$s"),
            (KeyCombo(keyCode: 0x07, modifiers: [.option]), "~x"),
            (KeyCombo(keyCode: 0x00, modifiers: [.control]), "^a"),
            (KeyCombo(keyCode: 0x7A, modifiers: [.command, .shift]), "$@\u{F704}"),
            (KeyCombo(keyCode: 0x6F, modifiers: [.option]), "~\u{F70F}"),
            (KeyCombo(keyCode: 0x7E, modifiers: [.control, .option]), "^~\u{F700}"),
            (KeyCombo(keyCode: 0x7C, modifiers: [.command]), "@\u{F703}"),
            (KeyCombo(keyCode: 0x35, modifiers: [.command]), "@\u{001B}"),
            (KeyCombo(keyCode: 0x31, modifiers: [.command]), "@ "),
            (KeyCombo(keyCode: 0x24, modifiers: [.command]), "@\r"),
            (KeyCombo(keyCode: 0x30, modifiers: [.control]), "^\t"),
            (KeyCombo(keyCode: 0x33, modifiers: [.command]), "@\u{0008}"),
            (KeyCombo(keyCode: 0x75, modifiers: [.command]), "@\u{F728}"),
        ]

        for testCase in cases {
            let encoded = testCase.combo.nsUserKeyEquivalent
            #expect(encoded == testCase.expectedRaw)
            let parsed = KeyCombo.parseNSUserKeyEquivalent(encoded)
            #expect(parsed == testCase.combo)
        }

        // Uppercase ASCII letter implies Shift in AppKit NSUserKeyEquivalents
        let upperParsed = KeyCombo.parseNSUserKeyEquivalent("@K")
        #expect(upperParsed == KeyCombo(keyCode: 40, modifiers: [.command, .shift]))

        // Empty string fails gracefully
        #expect(KeyCombo.parseNSUserKeyEquivalent("") == nil)
    }

    @Test("VS Code key string parsing and serialization round-trips")
    func vsCodeRoundTrips() {
        let cmdShiftK = KeyCombo.parseVSCode("cmd+shift+k")
        #expect(cmdShiftK == KeyCombo(keyCode: 40, modifiers: [.command, .shift]))
        #expect(cmdShiftK?.vsCodeString == "shift+cmd+k")
        #expect(KeyCombo.parseVSCode(cmdShiftK?.vsCodeString ?? "") == cmdShiftK)

        let ctrlAltSpace = KeyCombo.parseVSCode("ctrl+alt+space")
        #expect(ctrlAltSpace == KeyCombo(keyCode: 49, modifiers: [.control, .option]))
        #expect(ctrlAltSpace?.vsCodeString == "ctrl+alt+space")
        #expect(KeyCombo.parseVSCode(ctrlAltSpace?.vsCodeString ?? "") == ctrlAltSpace)

        // Aliases and edge cases
        #expect(KeyCombo.parseVSCode("option+esc") == KeyCombo(keyCode: 53, modifiers: [.option]))
        #expect(KeyCombo.parseVSCode("cmd+return") == KeyCombo(keyCode: 36, modifiers: [.command]))
        #expect(KeyCombo.parseVSCode("cmd++") == KeyCombo(keyCode: 0x18, modifiers: [.command]))

        // Multi-key chords are rejected cleanly
        #expect(KeyCombo.parseVSCode("ctrl+k ctrl+s") == nil)
        #expect(KeyCombo.parseVSCode("") == nil)
    }

    @Test("KeyCombo.fromAX decodes Apple AXMenuItemCmdModifiers bitmask accurately")
    func fromAXModifiersDecoding() {
        // 0 -> .command (Bit 3 unset means Command IS present)
        let cmdOnly = KeyCombo.fromAX(cmdChar: "n", virtualKey: nil, axModifiers: 0)
        #expect(cmdOnly == KeyCombo(keyCode: 45, modifiers: [.command]))

        // 8 -> no .command
        let noCmd = KeyCombo.fromAX(cmdChar: "n", virtualKey: nil, axModifiers: 8)
        #expect(noCmd == KeyCombo(keyCode: 45, modifiers: []))

        // 1 | 8 -> .shift only (no .command)
        let shiftOnly = KeyCombo.fromAX(cmdChar: "n", virtualKey: nil, axModifiers: 1 | 8)
        #expect(shiftOnly == KeyCombo(keyCode: 45, modifiers: [.shift]))

        // 2 -> .command + .option
        let cmdOpt = KeyCombo.fromAX(cmdChar: "k", virtualKey: nil, axModifiers: 2)
        #expect(cmdOpt == KeyCombo(keyCode: 40, modifiers: [.command, .option]))

        // 4 -> .command + .control
        let cmdCtrl = KeyCombo.fromAX(cmdChar: "k", virtualKey: nil, axModifiers: 4)
        #expect(cmdCtrl == KeyCombo(keyCode: 40, modifiers: [.command, .control]))

        // 1 | 2 | 4 -> .command + .shift + .option + .control
        let allFour = KeyCombo.fromAX(cmdChar: "a", virtualKey: nil, axModifiers: 1 | 2 | 4)
        #expect(allFour == KeyCombo(keyCode: 0, modifiers: [.command, .shift, .option, .control]))

        // VirtualKey fallback when cmdChar is nil (e.g. F5 with Command)
        let f5Cmd = KeyCombo.fromAX(cmdChar: nil, virtualKey: 0x60, axModifiers: 0)
        #expect(f5Cmd == KeyCombo(keyCode: 0x60, modifiers: [.command]))
    }

    @Test("KeyModifiers flags conversion round-trips cleanly across NSEvent, CGEvent, Carbon, and symbolic bitmasks")
    func modifierFlagsConversions() {
        let mods: KeyModifiers = [.control, .option, .shift, .command]
        #expect(mods.displaySymbols == "⌃⌥⇧⌘")
        #expect(mods.nsUserKeyPrefix == "^~$@")
        #expect(mods.vsCodeTokens == ["ctrl", "alt", "shift", "cmd"])

        #expect(KeyModifiers(nsEventFlags: mods.nsEventFlags) == mods)
        #expect(KeyModifiers(cgEventFlags: mods.cgEventFlags) == mods)
        #expect(KeyModifiers(symbolicBitmask: mods.rawValue | (1 << 8)) == mods)
        #expect(mods.carbonFlags != 0)
    }
}
