import Foundation
import Testing
@testable import KeyMapCore

@Suite("HidRemapManager Tests")
struct HidRemapManagerTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyMapStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("buildHidutilPayload generates compact JSON with enabled rules only")
    func buildHidutilPayload() throws {
        let rules = [
            HidRemapRule(
                name: "Caps Lock → Escape",
                sourceUsage: 0x700000039,
                targetUsage: 0x700000029,
                isEnabled: true
            ),
            HidRemapRule(
                name: "Disabled Rule",
                sourceUsage: 0x7000000E7,
                targetUsage: 0x70000004C,
                isEnabled: false
            )
        ]

        let payload = HidRemapManager.buildHidutilPayload(for: rules)
        let data = try #require(payload.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let mappings = try #require(json["UserKeyMapping"] as? [[String: UInt64]])

        #expect(mappings.count == 1)
        #expect(mappings[0]["HIDKeyboardModifierMappingSrc"] == 0x700000039)
        #expect(mappings[0]["HIDKeyboardModifierMappingDst"] == 0x700000029)

        let emptyPayload = HidRemapManager.buildHidutilPayload(for: [rules[1]])
        #expect(emptyPayload == #"{"UserKeyMapping":[]}"#)
    }

    @Test("parseHidutilOutput parses hex and decimal hidutil output blocks")
    func parseHidutilOutput() {
        let sampleOutput = """
        (
            {
                HIDKeyboardModifierMappingDst = 30064771113;
                HIDKeyboardModifierMappingSrc = 30064771129;
            },
            {
                HIDKeyboardModifierMappingDst = 0x70000004c;
                HIDKeyboardModifierMappingSrc = 0x7000000e7;
            }
        )
        """

        let parsed = HidRemapManager.parseHidutilOutput(sampleOutput)
        #expect(parsed.count == 2)
        #expect(parsed[0].source == 0x700000039)
        #expect(parsed[0].target == 0x700000029)
        #expect(parsed[1].source == 0x7000000E7)
        #expect(parsed[1].target == 0x70000004C)

        #expect(HidRemapManager.parseHidutilOutput("(null)").isEmpty)
        #expect(HidRemapManager.parseHidutilOutput("").isEmpty)
    }

    @Test("saveRules/loadRules and LaunchAgent plist generation/install/remove work in temp directory")
    func rulesPersistenceAndLaunchAgent() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let rulesURL = tempDir.appendingPathComponent("hid_rules.json")
        let agentURL = tempDir.appendingPathComponent("LaunchAgents/com.keymapstudio.hidremap.plist")
        let manager = HidRemapManager(rulesFileURL: rulesURL, launchAgentURL: agentURL)

        let rules = [
            HidRemapRule.builtInPresets[0],
            HidRemapRule(
                name: "Right ⌘ → Forward Delete",
                sourceUsage: 0x7000000E7,
                targetUsage: 0x70000004C,
                isEnabled: true
            )
        ]

        try manager.saveRules(rules)
        let loaded = manager.loadRules()
        #expect(loaded == rules)

        // Generate LaunchAgent plist and inspect contents
        let plistData = try #require(manager.generateLaunchAgentPlist(for: rules))
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        )
        #expect(plist["Label"] as? String == HidRemapManager.launchAgentLabel)
        #expect(plist["RunAtLoad"] as? Bool == true)

        let args = try #require(plist["ProgramArguments"] as? [String])
        #expect(args.count == 4)
        #expect(args[0] == "/usr/bin/hidutil")
        #expect(args[1] == "property")
        #expect(args[2] == "--set")
        #expect(args[3] == HidRemapManager.buildHidutilPayload(for: rules))

        // Install & remove LaunchAgent using temp URL
        #expect(manager.isLaunchAgentInstalled() == false)
        try manager.installLaunchAgent(for: rules)
        #expect(manager.isLaunchAgentInstalled() == true)
        try manager.removeLaunchAgent()
        #expect(manager.isLaunchAgentInstalled() == false)
    }

    @Test("ComboRemapEngine persists and reloads rules in temp directory without starting event tap")
    func comboRemapEnginePersistence() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let comboRulesURL = tempDir.appendingPathComponent("combo_rules.json")
        let engine = ComboRemapEngine(rulesFileURL: comboRulesURL)
        #expect(engine.isRunning == false)
        #expect(engine.rules.isEmpty)

        let rule = ComboRemapRule(
            name: "Ctrl+H → Backspace",
            source: KeyCombo(keyCode: 4, modifiers: [.control]),
            target: KeyCombo(keyCode: 51, modifiers: []),
            targetAppBundleID: "com.apple.Terminal",
            isEnabled: true
        )
        try engine.saveRules([rule])

        engine.isPausedForRecording = true
        #expect(engine.isPausedForRecording == true)

        let reloaded = ComboRemapEngine(rulesFileURL: comboRulesURL)
        #expect(reloaded.rules == [rule])
        #expect(reloaded.isRunning == false)
    }
}
