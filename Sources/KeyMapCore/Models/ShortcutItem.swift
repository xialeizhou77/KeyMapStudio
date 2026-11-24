import Foundation
import Darwin

public enum ShortcutSource: String, Codable, CaseIterable, Sendable {
    case systemSymbolic
    case appMenu
    case devTool
    case hidRemap
    case comboRemap

    public var displayName: String {
        switch self {
        case .systemSymbolic: return "系统快捷键"
        case .appMenu: return "应用菜单"
        case .devTool: return "开发工具"
        case .hidRemap: return "硬件改键"
        case .comboRemap: return "组合改键"
        }
    }
}

public struct ShortcutItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var category: String
    public var source: ShortcutSource
    public var appBundleID: String?
    public var appName: String
    public var combo: KeyCombo?
    public var defaultCombo: KeyCombo?
    public var isEnabled: Bool
    public var isModified: Bool
    public var isEditable: Bool
    public var metadata: [String: String]

    public init(
        id: String,
        title: String,
        subtitle: String,
        category: String,
        source: ShortcutSource,
        appBundleID: String? = nil,
        appName: String,
        combo: KeyCombo? = nil,
        defaultCombo: KeyCombo? = nil,
        isEnabled: Bool = true,
        isModified: Bool = false,
        isEditable: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.source = source
        self.appBundleID = appBundleID
        self.appName = appName
        self.combo = combo
        self.defaultCombo = defaultCombo
        self.isEnabled = isEnabled
        self.isModified = isModified
        self.isEditable = isEditable
        self.metadata = metadata
    }
}

public struct RunningAppInfo: Identifiable, Hashable, Sendable {
    public var id: String { bundleID }
    public var pid: pid_t
    public var bundleID: String
    public var name: String
    public var isActive: Bool

    public init(pid: pid_t, bundleID: String, name: String, isActive: Bool) {
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
        self.isActive = isActive
    }
}
