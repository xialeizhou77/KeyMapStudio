import Foundation

public struct HidRemapRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var sourceUsage: UInt64
    public var targetUsage: UInt64
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        sourceUsage: UInt64,
        targetUsage: UInt64,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.sourceUsage = sourceUsage
        self.targetUsage = targetUsage
        self.isEnabled = isEnabled
    }

    public static var builtInPresets: [HidRemapRule] {
        [
            HidRemapRule(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111101")!,
                name: "Caps Lock → Escape",
                sourceUsage: 0x700000039,
                targetUsage: 0x700000029,
                isEnabled: true
            ),
            HidRemapRule(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111102")!,
                name: "Caps Lock → Left Control",
                sourceUsage: 0x700000039,
                targetUsage: 0x7000000E0,
                isEnabled: true
            ),
            HidRemapRule(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111103")!,
                name: "Escape → Caps Lock",
                sourceUsage: 0x700000029,
                targetUsage: 0x700000039,
                isEnabled: true
            ),
            HidRemapRule(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111104")!,
                name: "Right ⌘ → Forward Delete",
                sourceUsage: 0x7000000E7,
                targetUsage: 0x70000004C,
                isEnabled: true
            ),
        ]
    }
}

public struct ComboRemapRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var source: KeyCombo
    public var target: KeyCombo
    public var targetAppBundleID: String?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        source: KeyCombo,
        target: KeyCombo,
        targetAppBundleID: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.target = target
        self.targetAppBundleID = targetAppBundleID
        self.isEnabled = isEnabled
    }
}
