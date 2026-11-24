import Foundation

public final class HidRemapManager: @unchecked Sendable {
    public static let launchAgentLabel = "com.keymapstudio.hidremap"
    private static let hidutilPath = "/usr/bin/hidutil"

    public let rulesFileURL: URL
    public let launchAgentURL: URL

    public init(
        rulesFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KeyMapStudio/hid_rules.json"),
        launchAgentURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.keymapstudio.hidremap.plist")
    ) {
        self.rulesFileURL = rulesFileURL
        self.launchAgentURL = launchAgentURL
    }

    public func loadRules() -> [HidRemapRule] {
        guard FileManager.default.fileExists(atPath: rulesFileURL.path),
              let data = try? Data(contentsOf: rulesFileURL),
              let rules = try? JSONDecoder().decode([HidRemapRule].self, from: data) else {
            return []
        }
        return rules
    }

    public func saveRules(_ rules: [HidRemapRule]) throws {
        try FileManager.default.createDirectory(
            at: rulesFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(rules)
        try data.write(to: rulesFileURL, options: .atomic)
    }

    public static func buildHidutilPayload(for rules: [HidRemapRule]) -> String {
        let mappings: [[String: UInt64]] = rules
            .filter(\.isEnabled)
            .map { rule in
                [
                    "HIDKeyboardModifierMappingSrc": rule.sourceUsage,
                    "HIDKeyboardModifierMappingDst": rule.targetUsage
                ]
            }

        let payload: [String: Any] = ["UserKeyMapping": mappings]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"UserKeyMapping":[]}"#
        }
        return json
    }

    public static func parseHidutilOutput(_ output: String) -> [(source: UInt64, target: UInt64)] {
        guard !output.isEmpty else { return [] }

        var results: [(source: UInt64, target: UInt64)] = []
        var seen = Set<String>()

        let blockPattern = #"\{[^{}]*\}"#
        let srcPattern = #"HIDKeyboardModifierMappingSrc"?\s*[=:]\s*"?(0x[0-9a-fA-F]+|\d+)"?"#
        let dstPattern = #"HIDKeyboardModifierMappingDst"?\s*[=:]\s*"?(0x[0-9a-fA-F]+|\d+)"?"#

        guard let blockRegex = try? NSRegularExpression(pattern: blockPattern, options: [.dotMatchesLineSeparators]),
              let srcRegex = try? NSRegularExpression(pattern: srcPattern, options: []),
              let dstRegex = try? NSRegularExpression(pattern: dstPattern, options: []) else {
            return []
        }

        let nsOutput = output as NSString
        let fullRange = NSRange(location: 0, length: nsOutput.length)

        for match in blockRegex.matches(in: output, options: [], range: fullRange) {
            let block = nsOutput.substring(with: match.range)
            guard let srcValue = extractFirstUInt64(in: block, using: srcRegex),
                  let dstValue = extractFirstUInt64(in: block, using: dstRegex) else {
                continue
            }

            let dedupKey = "\(srcValue)->\(dstValue)"
            if seen.insert(dedupKey).inserted {
                results.append((source: srcValue, target: dstValue))
            }
        }

        return results
    }

    public func applyRules(_ rules: [HidRemapRule]) throws {
        try saveRules(rules)
        let payload = Self.buildHidutilPayload(for: rules)
        let result = try ShellRunner.run(Self.hidutilPath, arguments: ["property", "--set", payload])
        if result.exitCode != 0 {
            throw NSError(
                domain: "HidRemapManager",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: result.stderr.isEmpty ? "hidutil 设置失败" : result.stderr]
            )
        }
    }

    public func resetAllMappings() throws {
        let result = try ShellRunner.run(
            Self.hidutilPath,
            arguments: ["property", "--set", #"{"UserKeyMapping":[]}"#]
        )
        if result.exitCode != 0 {
            throw NSError(
                domain: "HidRemapManager",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: result.stderr.isEmpty ? "hidutil 重置失败" : result.stderr]
            )
        }
    }

    public func readLiveSystemMappings() -> [(source: UInt64, target: UInt64)] {
        guard let result = try? ShellRunner.run(Self.hidutilPath, arguments: ["property", "--get", "UserKeyMapping"]),
              result.exitCode == 0 else {
            return []
        }
        return Self.parseHidutilOutput(result.stdout)
    }

    public func generateLaunchAgentPlist(for rules: [HidRemapRule]) -> Data? {
        let payload = Self.buildHidutilPayload(for: rules)
        let plist: [String: Any] = [
            "Label": Self.launchAgentLabel,
            "ProgramArguments": [
                Self.hidutilPath,
                "property",
                "--set",
                payload
            ],
            "RunAtLoad": true
        ]
        return try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    public func installLaunchAgent(for rules: [HidRemapRule]) throws {
        guard let data = generateLaunchAgentPlist(for: rules) else {
            throw NSError(
                domain: "HidRemapManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法生成 LaunchAgent plist 数据"]
            )
        }
        try FileManager.default.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    public func removeLaunchAgent() throws {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    public func isLaunchAgentInstalled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    // MARK: - Helpers

    private static func extractFirstUInt64(in text: String, using regex: NSRegularExpression) -> UInt64? {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2 else {
            return nil
        }
        let token = nsText.substring(with: match.range(at: 1))
        if token.lowercased().hasPrefix("0x") {
            return UInt64(token.dropFirst(2), radix: 16)
        }
        return UInt64(token, radix: 10)
    }
}
