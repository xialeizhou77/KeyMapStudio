import AppKit
import Foundation

public final class AppMenuShortcutStore: @unchecked Sendable {
    public static let globalDomain = "NSGlobalDomain"

    private static let universalAccessDomain = "com.apple.universalaccess"
    private static let customMenuAppsKey = "com.apple.custommenu.apps"
    private static let userKeyEquivalentsKey = "NSUserKeyEquivalents"
    private static let defaultsPath = "/usr/bin/defaults"

    public let overrideDirectory: URL?

    public init(overrideDirectory: URL? = nil) {
        self.overrideDirectory = overrideDirectory
    }

    public static func formatMenuPath(_ components: [String]) -> String {
        guard !components.isEmpty else { return "" }
        if components.count == 1 {
            return components[0]
        }
        return "\u{001B}" + components.joined(separator: "\u{001B}")
    }

    public func loadCustomizedAppBundleIDs() -> [String] {
        let rawList: [String]
        if let overrideDirectory {
            let plist = readPlist(at: overrideDirectory.appendingPathComponent("\(Self.universalAccessDomain).plist"))
            rawList = plist[Self.customMenuAppsKey] as? [String] ?? []
        } else {
            let plist = readDefaultsDomain(Self.universalAccessDomain)
            rawList = plist[Self.customMenuAppsKey] as? [String] ?? []
        }

        var seen = Set<String>()
        var result: [String] = []
        for entry in rawList where entry != Self.globalDomain && !entry.isEmpty {
            if seen.insert(entry).inserted {
                result.append(entry)
            }
        }
        return result
    }

    public func loadOverrides(forDomain domain: String) -> [String: String] {
        let dict: [String: Any]
        if let overrideDirectory {
            dict = readPlist(at: plistURL(forDomain: domain, in: overrideDirectory))
        } else {
            dict = readDefaultsDomain(domain)
        }
        return dict[Self.userKeyEquivalentsKey] as? [String: String] ?? [:]
    }

    public func loadAllOverrides() -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]

        let globalOverrides = loadOverrides(forDomain: Self.globalDomain)
        if !globalOverrides.isEmpty {
            result[Self.globalDomain] = globalOverrides
        }

        for bundleID in loadCustomizedAppBundleIDs() {
            let overrides = loadOverrides(forDomain: bundleID)
            if !overrides.isEmpty {
                result[bundleID] = overrides
            }
        }

        return result
    }

    public func loadOverrideShortcutItems() -> [ShortcutItem] {
        let all = loadAllOverrides()
        var items: [ShortcutItem] = []

        for domain in all.keys.sorted() {
            guard let domainOverrides = all[domain] else { continue }
            let isGlobal = (domain == Self.globalDomain)
            let resolvedAppName = isGlobal ? "所有应用程序 (全局)" : resolveAppName(forBundleID: domain)

            for menuKey in domainOverrides.keys.sorted() {
                guard let rawEquiv = domainOverrides[menuKey] else { continue }
                let combo = KeyCombo.parseNSUserKeyEquivalent(rawEquiv)
                let (menuTitle, displayPath) = Self.parseMenuKeyDisplay(menuKey)

                items.append(
                    ShortcutItem(
                        id: "appOverride.\(domain).\(menuKey)",
                        title: menuTitle,
                        subtitle: displayPath,
                        category: isGlobal ? "全局菜单快捷键" : "应用自定义菜单",
                        source: .appMenu,
                        appBundleID: domain,
                        appName: resolvedAppName,
                        combo: combo,
                        defaultCombo: nil,
                        isEnabled: true,
                        isModified: true,
                        isEditable: true,
                        metadata: [
                            "menuTitle": menuTitle,
                            "menuPath": menuKey,
                            "displayPath": displayPath,
                            "domain": domain
                        ]
                    )
                )
            }
        }

        return items
    }

    public func setOverride(
        domain: String,
        appName: String?,
        menuTitleOrPath: String,
        combo: KeyCombo
    ) throws {
        _ = appName
        var equivalents = loadOverrides(forDomain: domain)
        equivalents[menuTitleOrPath] = combo.nsUserKeyEquivalent
        try writeEquivalents(equivalents, forDomain: domain)
        try registerDomainInUniversalAccess(domain)
    }

    public func removeOverride(domain: String, menuTitleOrPath: String) throws {
        var equivalents = loadOverrides(forDomain: domain)
        equivalents.removeValue(forKey: menuTitleOrPath)
        try writeEquivalents(equivalents, forDomain: domain)

        if equivalents.isEmpty, domain != Self.globalDomain {
            try unregisterDomainFromUniversalAccess(domain)
        }
    }

    public func restoreAllOverrides(_ overrides: [String: [String: String]]) throws {
        let existingDomains = Set([Self.globalDomain] + loadCustomizedAppBundleIDs())
        let targetDomains = Set(overrides.keys)

        for domain in existingDomains.union(targetDomains) {
            if let map = overrides[domain], !map.isEmpty {
                try writeEquivalents(map, forDomain: domain)
            } else {
                try writeEquivalents([:], forDomain: domain)
            }
        }

        var customApps: [String] = []
        if let globalMap = overrides[Self.globalDomain], !globalMap.isEmpty {
            customApps.append(Self.globalDomain)
        }
        for domain in overrides.keys.sorted() where domain != Self.globalDomain {
            if let map = overrides[domain], !map.isEmpty {
                customApps.append(domain)
            }
        }
        try writeCustomMenuAppsList(customApps)
    }

    // MARK: - Helpers

    private static func parseMenuKeyDisplay(_ menuKey: String) -> (title: String, displayPath: String) {
        if menuKey.hasPrefix("\u{001B}") {
            let parts = menuKey.dropFirst().split(separator: "\u{001B}").map(String.init)
            let title = parts.last ?? menuKey
            let displayPath = parts.joined(separator: " → ")
            return (title, displayPath)
        }
        return (menuKey, menuKey)
    }

    private func resolveAppName(forBundleID bundleID: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = running.localizedName,
           !name.isEmpty {
            return name
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !displayName.isEmpty {
                return displayName
            }
            if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
               !bundleName.isEmpty {
                return bundleName
            }
        }
        return bundleID
    }

    private func plistURL(forDomain domain: String, in directory: URL) -> URL {
        let safeDomain = domain.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safeDomain).plist")
    }

    private func readPlist(at url: URL) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return [:]
        }
        return plist
    }

    private func writePlist(_ dict: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private func readDefaultsDomain(_ domain: String) -> [String: Any] {
        guard let result = try? ShellRunner.run(Self.defaultsPath, arguments: ["export", domain, "-"]),
              result.exitCode == 0,
              let data = result.stdout.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return [:]
        }
        return plist
    }

    private func writeEquivalents(_ equivalents: [String: String], forDomain domain: String) throws {
        if let overrideDirectory {
            let url = plistURL(forDomain: domain, in: overrideDirectory)
            var dict = readPlist(at: url)
            if equivalents.isEmpty {
                dict.removeValue(forKey: Self.userKeyEquivalentsKey)
            } else {
                dict[Self.userKeyEquivalentsKey] = equivalents
            }
            try writePlist(dict, to: url)
            return
        }

        if equivalents.isEmpty {
            guard !loadOverrides(forDomain: domain).isEmpty else {
                return
            }
            let result = try ShellRunner.run(Self.defaultsPath, arguments: ["delete", domain, Self.userKeyEquivalentsKey])
            if result.exitCode != 0 &&
                !result.stderr.contains("not found") &&
                !result.stderr.contains("does not exist") &&
                !result.stderr.contains("There is no") {
                throw NSError(
                    domain: "AppMenuShortcutStore",
                    code: Int(result.exitCode),
                    userInfo: [NSLocalizedDescriptionKey: result.stderr.isEmpty ? "无法删除默认快捷键覆盖" : result.stderr]
                )
            }
        } else {
            let xmlData = try PropertyListSerialization.data(fromPropertyList: equivalents, format: .xml, options: 0)
            guard let xmlString = String(data: xmlData, encoding: .utf8) else {
                throw NSError(
                    domain: "AppMenuShortcutStore",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法编码 NSUserKeyEquivalents plist"]
                )
            }
            let result = try ShellRunner.run(
                Self.defaultsPath,
                arguments: ["write", domain, Self.userKeyEquivalentsKey, xmlString]
            )
            if result.exitCode != 0 {
                throw NSError(
                    domain: "AppMenuShortcutStore",
                    code: Int(result.exitCode),
                    userInfo: [NSLocalizedDescriptionKey: result.stderr.isEmpty ? "写入 defaults 失败" : result.stderr]
                )
            }
        }
    }

    private func registerDomainInUniversalAccess(_ domain: String) throws {
        var current = readRawCustomMenuApps()
        if !current.contains(domain) {
            current.append(domain)
            try writeCustomMenuAppsList(current)
        }
    }

    private func unregisterDomainFromUniversalAccess(_ domain: String) throws {
        let current = readRawCustomMenuApps()
        let updated = current.filter { $0 != domain }
        if updated.count != current.count {
            try writeCustomMenuAppsList(updated)
        }
    }

    private func readRawCustomMenuApps() -> [String] {
        if let overrideDirectory {
            let plist = readPlist(at: overrideDirectory.appendingPathComponent("\(Self.universalAccessDomain).plist"))
            return plist[Self.customMenuAppsKey] as? [String] ?? []
        } else {
            let plist = readDefaultsDomain(Self.universalAccessDomain)
            return plist[Self.customMenuAppsKey] as? [String] ?? []
        }
    }

    private func writeCustomMenuAppsList(_ list: [String]) throws {
        if let overrideDirectory {
            let url = overrideDirectory.appendingPathComponent("\(Self.universalAccessDomain).plist")
            var plist = readPlist(at: url)
            plist[Self.customMenuAppsKey] = list
            try writePlist(plist, to: url)
            return
        }

        let xmlData = try PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0)
        guard let xmlString = String(data: xmlData, encoding: .utf8) else {
            throw NSError(
                domain: "AppMenuShortcutStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法编码 custommenu.apps 列表"]
            )
        }
        let result = try ShellRunner.run(
            Self.defaultsPath,
            arguments: ["write", Self.universalAccessDomain, Self.customMenuAppsKey, xmlString]
        )
        if result.exitCode != 0 {
            throw NSError(
                domain: "AppMenuShortcutStore",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: result.stderr.isEmpty ? "更新 com.apple.universalaccess 失败" : result.stderr]
            )
        }
    }
}
