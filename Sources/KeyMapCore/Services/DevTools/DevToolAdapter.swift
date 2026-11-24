import Foundation

public enum DevToolError: Error, LocalizedError, Sendable {
    case readOnlyTool(String)
    case configNotFound(String)
    case invalidConfigFormat(String)
    case itemNotFound(String)
    case unsupportedCombo(String)

    public var errorDescription: String? {
        switch self {
        case .readOnlyTool(let tool):
            return "\(tool) 为只读配置集成，不支持直接修改快捷键"
        case .configNotFound(let path):
            return "未找到配置文件：\(path)"
        case .invalidConfigFormat(let detail):
            return "配置文件格式无效：\(detail)"
        case .itemNotFound(let id):
            return "未找到目标快捷键条目：\(id)"
        case .unsupportedCombo(let detail):
            return "暂不支持保存该快捷键组合：\(detail)"
        }
    }
}

public struct DevToolInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleID: String
    public let configPath: String
    public let isAppInstalled: Bool
    public let hasConfigFile: Bool
    public let shortcutCount: Int
    public let supportsWrite: Bool

    public init(
        id: String,
        name: String,
        bundleID: String,
        configPath: String,
        isAppInstalled: Bool,
        hasConfigFile: Bool,
        shortcutCount: Int,
        supportsWrite: Bool
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.configPath = configPath
        self.isAppInstalled = isAppInstalled
        self.hasConfigFile = hasConfigFile
        self.shortcutCount = shortcutCount
        self.supportsWrite = supportsWrite
    }
}

public protocol DevToolAdapter: Sendable {
    var toolID: String { get }
    var displayName: String { get }
    var bundleID: String { get }
    var supportsWrite: Bool { get }

    func detectStatus() -> DevToolInfo
    func loadShortcuts() -> [ShortcutItem]
    func upsertShortcut(command: String, combo: KeyCombo, when: String?, originalCommand: String?) throws
    func removeShortcut(itemID: String) throws
    func exportRecords() -> [DevToolBindingRecord]
    func importRecords(_ records: [DevToolBindingRecord]) throws
}

public final class DevToolRegistry: @unchecked Sendable {
    public let adapters: [any DevToolAdapter]

    public init(adapters: [any DevToolAdapter] = DevToolRegistry.defaultAdapters()) {
        self.adapters = adapters
    }

    public static func defaultAdapters() -> [any DevToolAdapter] {
        [
            VSCodeFamilyAdapter(variant: .vscode),
            VSCodeFamilyAdapter(variant: .cursor),
            VSCodeFamilyAdapter(variant: .antigravity),
            ITerm2Adapter(),
            RaycastAdapter(),
            ObsidianAdapter()
        ]
    }

    public func detectAll() -> [DevToolInfo] {
        adapters.map { $0.detectStatus() }
    }

    public func loadAllShortcuts() -> [ShortcutItem] {
        adapters.flatMap { $0.loadShortcuts() }
    }

    public func adapter(forToolID toolID: String) -> (any DevToolAdapter)? {
        adapters.first { $0.toolID == toolID }
    }

    public func exportAllRecords() -> [String: [DevToolBindingRecord]] {
        var result: [String: [DevToolBindingRecord]] = [:]
        for adapter in adapters {
            let records = adapter.exportRecords()
            if !records.isEmpty {
                result[adapter.toolID] = records
            }
        }
        return result
    }

    public func importAllRecords(_ recordsByTool: [String: [DevToolBindingRecord]]) throws {
        for (toolID, records) in recordsByTool {
            guard let adapter = adapter(forToolID: toolID) else { continue }
            guard adapter.supportsWrite else { continue }
            try adapter.importRecords(records)
        }
    }
}
