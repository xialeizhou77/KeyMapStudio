import SwiftUI
import KeyMapCore

enum KeyCapSize: Sendable {
    case compact
    case regular
    case large

    var fontSize: CGFloat {
        switch self {
        case .compact: return 10.5
        case .regular: return 12
        case .large: return 14.5
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 5
        case .regular: return 7
        case .large: return 9
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: return 2
        case .regular: return 3.5
        case .large: return 5
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .compact: return 18
        case .regular: return 24
        case .large: return 30
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 4
        case .regular: return 5.5
        case .large: return 7
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: return 2.5
        case .regular: return 3.5
        case .large: return 5
        }
    }
}

struct KeyCapBadge: View {
    let combo: KeyCombo?
    var size: KeyCapSize = .regular
    var highlighted: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let combo {
            HStack(spacing: size.spacing) {
                ForEach(modifierTokens(for: combo.modifiers), id: \.self) { token in
                    capView(label: token, isModifier: true)
                }
                capView(label: combo.keyDisplayName, isModifier: false)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(combo.displayString)
        } else {
            Text("未绑定")
                .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, size.horizontalPadding + 2)
                .padding(.vertical, size.verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                )
        }
    }

    private func modifierTokens(for modifiers: KeyModifiers) -> [String] {
        var tokens: [String] = []
        if modifiers.contains(.function) { tokens.append("fn") }
        if modifiers.contains(.control) { tokens.append("⌃") }
        if modifiers.contains(.option) { tokens.append("⌥") }
        if modifiers.contains(.shift) { tokens.append("⇧") }
        if modifiers.contains(.command) { tokens.append("⌘") }
        return tokens
    }

    private func capView(label: String, isModifier: Bool) -> some View {
        let baseFill: Color = highlighted
            ? Color.accentColor.opacity(colorScheme == .dark ? 0.34 : 0.16)
            : Color(nsColor: .controlBackgroundColor)
        let borderColor: Color = highlighted
            ? Color.accentColor.opacity(0.75)
            : Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.16)
        let bottomEdgeColor: Color = highlighted
            ? Color.accentColor.opacity(0.45)
            : Color.black.opacity(colorScheme == .dark ? 0.55 : 0.22)

        return Text(label)
            .font(.system(
                size: size.fontSize,
                weight: isModifier ? .medium : .semibold,
                design: .rounded
            ))
            .foregroundStyle(highlighted ? Color.accentColor : Color.primary)
            .frame(minWidth: size.minWidth)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(baseFill)
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.65),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: bottomEdgeColor, radius: 0, x: 0, y: 1.2)
    }
}
