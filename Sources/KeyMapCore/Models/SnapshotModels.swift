import Foundation

public struct SymbolicHotkeyState: Codable, Hashable, Sendable {
    public var id: String
    public var enabled: Bool
    public var ascii: Int
    public var virtualKeyCode: UInt16
    public var modifiers: UInt64

    public init(
        id: String,
        enabled: Bool,
        ascii: Int,
        virtualKeyCode: UInt16,
        modifiers: UInt64
    ) {
        self.id = id
        self.enabled = enabled
        self.ascii = ascii
        self.virtualKeyCode = virtualKeyCode
        self.modifiers = modifiers
    }
}

public struct DevToolBindingRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var toolID: String
    public var key: String
    public var command: String
    public var when: String?
    public var extra: [String: String]

    public init(
        id: String,
        toolID: String,
        key: String,
        command: String,
        when: String? = nil,
        extra: [String: String] = [:]
    ) {
        self.id = id
        self.toolID = toolID
        self.key = key
        self.command = command
        self.when = when
        self.extra = extra
    }
}

public struct KeyMapSnapshot: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var schemaVersion: Int
    public var symbolicHotkeys: [SymbolicHotkeyState]
    public var appMenuOverrides: [String: [String: String]]
    public var hidRules: [HidRemapRule]
    public var comboRules: [ComboRemapRule]
    public var devToolOverrides: [String: [DevToolBindingRecord]]

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        schemaVersion: Int = 1,
        symbolicHotkeys: [SymbolicHotkeyState] = [],
        appMenuOverrides: [String: [String: String]] = [:],
        hidRules: [HidRemapRule] = [],
        comboRules: [ComboRemapRule] = [],
        devToolOverrides: [String: [DevToolBindingRecord]] = [:]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.symbolicHotkeys = symbolicHotkeys
        self.appMenuOverrides = appMenuOverrides
        self.hidRules = hidRules
        self.comboRules = comboRules
        self.devToolOverrides = devToolOverrides
    }
}

public struct SnapshotDiffSummary: Sendable {
    public let symbolicChangedCount: Int
    public let appMenuChangedCount: Int
    public let hidRulesChangedCount: Int
    public let comboRulesChangedCount: Int
    public let devToolChangedCount: Int
    public let details: [String]

    public var totalChangedCount: Int {
        symbolicChangedCount + appMenuChangedCount + hidRulesChangedCount + comboRulesChangedCount + devToolChangedCount
    }

    public init(
        symbolicChangedCount: Int = 0,
        appMenuChangedCount: Int = 0,
        hidRulesChangedCount: Int = 0,
        comboRulesChangedCount: Int = 0,
        devToolChangedCount: Int = 0,
        details: [String] = []
    ) {
        self.symbolicChangedCount = symbolicChangedCount
        self.appMenuChangedCount = appMenuChangedCount
        self.hidRulesChangedCount = hidRulesChangedCount
        self.comboRulesChangedCount = comboRulesChangedCount
        self.devToolChangedCount = devToolChangedCount
        self.details = details
    }
}
