import Foundation

public enum ConflictSeverity: String, Codable, Comparable, CaseIterable, Sendable {
    case critical
    case warning
    case info

    public var rank: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }

    public var displayName: String {
        switch self {
        case .critical: return "高危"
        case .warning: return "警告"
        case .info: return "提示"
        }
    }

    public static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct ConflictItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var combo: KeyCombo
    public var severity: ConflictSeverity
    public var reason: String
    public var items: [ShortcutItem]

    public init(
        id: String,
        combo: KeyCombo,
        severity: ConflictSeverity,
        reason: String,
        items: [ShortcutItem]
    ) {
        self.id = id
        self.combo = combo
        self.severity = severity
        self.reason = reason
        self.items = items
    }
}
