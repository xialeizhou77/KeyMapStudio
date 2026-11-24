import AppKit
import KeyMapCore
import SwiftUI

struct InteractiveKeyboardView: View {
    let appState: AppState

    @State private var physicalModifiers: KeyModifiers = []
    @State private var lockedModifiers: KeyModifiers = []
    @State private var physicalFnPressed: Bool = false
    @State private var flagsMonitor: Any?
    @State private var selectedKey: KeyboardKeyCap?
    @State private var sourceFilter: ShortcutSource?

    init(appState: AppState) {
        self.appState = appState
    }

    private var activeModifiers: KeyModifiers {
        physicalModifiers.union(lockedModifiers).intersection(.standardMask)
    }

    private var conflictItemIDs: Set<String> {
        Set(appState.conflicts.flatMap { $0.items.map(\.id) })
    }

    var body: some View {
        VStack(spacing: 0) {
            headerToolbar
            Divider()

            VSplitView {
                keyboardCanvas
                    .frame(minHeight: 290)

                selectedKeyDetailPanel
                    .frame(minHeight: 190, idealHeight: 250)
            }
        }
        .onAppear {
            installFlagsMonitor()
        }
        .onDisappear {
            removeFlagsMonitor()
        }
    }

    // MARK: - Header & Controls

    private var headerToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("交互式键盘热图")
                        .font(.title3.weight(.semibold))
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Modifier Toggle Pills (mouse lock / inspect)
                HStack(spacing: 6) {
                    Text("修饰键:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    modifierPill(flag: .control, symbol: "⌃", label: "Ctrl")
                    modifierPill(flag: .option, symbol: "⌥", label: "Opt")
                    modifierPill(flag: .shift, symbol: "⇧", label: "Shift")
                    modifierPill(flag: .command, symbol: "⌘", label: "Cmd")

                    if !lockedModifiers.isEmpty {
                        Button("清除") {
                            lockedModifiers = []
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                // Source Filter
                Picker("来源", selection: $sourceFilter) {
                    Text("全部来源").tag(ShortcutSource?.none)
                    Text("系统").tag(ShortcutSource?.some(.systemSymbolic))
                    Text("应用菜单").tag(ShortcutSource?.some(.appMenu))
                    Text("开发工具").tag(ShortcutSource?.some(.devTool))
                    Text("重映射").tag(ShortcutSource?.some(.comboRemap))
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Legend Row
            HStack(spacing: 16) {
                legendBadge(color: .blue, label: "系统快捷键")
                legendBadge(color: .green, label: "应用菜单")
                legendBadge(color: .purple, label: "开发工具")
                legendBadge(color: .orange, label: "底层改键 / 重映射")
                HStack(spacing: 5) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("存在冲突")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                legendBadge(color: Color.secondary.opacity(0.25), label: "空闲按键", strokeOnly: true)

                Spacer()

                if !activeModifiers.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.caption)
                        Text("当前组合前缀: \(activeModifiers.displaySymbols)")
                            .font(.caption.monospaced())
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.tint)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var statusSubtitle: String {
        if activeModifiers.isEmpty {
            return "按住实体键盘 ⌃ / ⌥ / ⇧ / ⌘ 可实时预览绑定，或点击修饰键胶囊与任意按键查看详情"
        } else {
            return "实时预览修饰键 \(activeModifiers.displaySymbols) 下的按键绑定（松开物理修饰键或取消锁定恢复全局）"
        }
    }

    private func modifierPill(flag: KeyModifiers, symbol: String, label: String) -> some View {
        let isPhysical = physicalModifiers.contains(flag)
        let isLocked = lockedModifiers.contains(flag)
        let isActive = isPhysical || isLocked

        return Button {
            if lockedModifiers.contains(flag) {
                lockedModifiers.remove(flag)
            } else {
                lockedModifiers.insert(flag)
            }
        } label: {
            HStack(spacing: 3) {
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.caption2)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive ? Color.accentColor : Color.secondary.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .help(isLocked ? "点击解锁 \(label)" : "点击锁定 \(label) 修饰键")
    }

    private func legendBadge(color: Color, label: String, strokeOnly: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(strokeOnly ? Color.clear : color.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color, lineWidth: strokeOnly ? 1 : 0)
                )
                .frame(width: 11, height: 11)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Keyboard Chassis Canvas

    private var keyboardCanvas: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 24
            let chassisPadding: CGFloat = 14
            let keySpacing: CGFloat = 5
            let availableWidth = max(560, geo.size.width - horizontalPadding * 2 - chassisPadding * 2)
            let maxSlotCount = 14
            let totalSpacing = keySpacing * CGFloat(maxSlotCount - 1)
            let unitWidth = (availableWidth - totalSpacing) / CGFloat(KeyboardLayoutData.totalRowUnits)
            let baseKeyHeight = min(56, max(38, unitWidth * 0.92))

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: keySpacing) {
                    ForEach(KeyboardLayoutData.rows) { row in
                        let rowHeight = baseKeyHeight * CGFloat(row.heightUnits)
                        HStack(spacing: keySpacing) {
                            ForEach(row.slots) { slot in
                                switch slot {
                                case .single(let key):
                                    keyCapButton(
                                        key: key,
                                        width: slotWidth(units: key.widthUnits, unitWidth: unitWidth, keySpacing: keySpacing),
                                        height: rowHeight,
                                        compactArrow: false
                                    )
                                case .stackedPair(let top, let bottom):
                                    let colWidth = slotWidth(units: slot.widthUnits, unitWidth: unitWidth, keySpacing: keySpacing)
                                    let halfHeight = max(16, (rowHeight - 3) / 2)
                                    VStack(spacing: 3) {
                                        keyCapButton(key: top, width: colWidth, height: halfHeight, compactArrow: true)
                                        keyCapButton(key: bottom, width: colWidth, height: halfHeight, compactArrow: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(chassisPadding)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func slotWidth(units: Double, unitWidth: CGFloat, keySpacing: CGFloat) -> CGFloat {
        // Scale proportionally while ensuring row aligns cleanly
        let extra = units > 1.0 ? keySpacing * 0.25 * CGFloat(units - 1.0) : 0
        return max(26, unitWidth * CGFloat(units) + extra)
    }

    private func keyCapButton(
        key: KeyboardKeyCap,
        width: CGFloat,
        height: CGFloat,
        compactArrow: Bool
    ) -> some View {
        let bindings = matchingShortcuts(for: key)
        let dominantColor = dominantCategoryColor(for: bindings)
        let hasConflict = bindings.contains { conflictItemIDs.contains($0.id) }
        let isSelected = selectedKey?.id == key.id
        let isPhysicallyPressedModifier = key.isModifier && isModifierActive(key)
        let distinctSources = Array(Set(bindings.map(\.source))).sorted { $0.rawValue < $1.rawValue }

        return Button {
            guard key.isBindable else { return }
            selectedKey = key
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: compactArrow ? 0 : 2) {
                    if !compactArrow, let secondary = key.secondaryLabel, !key.isModifier {
                        Text(secondary)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(key.primaryLabel)
                        .font(.system(
                            size: compactArrow ? 10 : (key.primaryLabel.count > 2 ? 10.5 : 13),
                            weight: isSelected || isPhysicallyPressedModifier ? .bold : .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(keyLabelColor(hasBindings: !bindings.isEmpty, isPressed: isPhysicallyPressedModifier))
                        .lineLimit(1)

                    if !compactArrow, key.isModifier, let secondary = key.secondaryLabel {
                        Text(secondary)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !compactArrow && !bindings.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(distinctSources.prefix(3), id: \.self) { src in
                                Circle()
                                    .fill(color(for: src))
                                    .frame(width: 4.5, height: 4.5)
                            }
                            if bindings.count > 1 {
                                Text("\(bindings.count)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: compactArrow ? 5 : 7, style: .continuous)
                        .fill(keyFillColor(
                            dominantColor: dominantColor,
                            isSelected: isSelected,
                            isPressed: isPhysicallyPressedModifier,
                            isBindable: key.isBindable
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: compactArrow ? 5 : 7, style: .continuous)
                        .stroke(
                            isSelected
                                ? Color.accentColor
                                : (isPhysicallyPressedModifier
                                    ? Color.accentColor.opacity(0.85)
                                    : (dominantColor?.opacity(0.6) ?? Color.primary.opacity(0.14))),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)

                if hasConflict {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(.white, lineWidth: 1))
                        .offset(x: -3, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!key.isBindable)
        .help(keyTooltip(for: key, bindings: bindings))
    }

    private func isModifierActive(_ key: KeyboardKeyCap) -> Bool {
        if key.modifierFlag == .function {
            return physicalFnPressed
        }
        return !activeModifiers.intersection(key.modifierFlag).isEmpty
    }

    private func keyFillColor(
        dominantColor: Color?,
        isSelected: Bool,
        isPressed: Bool,
        isBindable: Bool
    ) -> Color {
        if !isBindable {
            return Color(nsColor: .controlBackgroundColor).opacity(0.45)
        }
        if isPressed {
            return Color.accentColor.opacity(0.28)
        }
        if isSelected {
            return (dominantColor ?? Color.accentColor).opacity(0.26)
        }
        if let dominantColor {
            return dominantColor.opacity(0.16)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private func keyLabelColor(hasBindings: Bool, isPressed: Bool) -> Color {
        if isPressed || hasBindings {
            return .primary
        }
        return .primary.opacity(0.82)
    }

    private func keyTooltip(for key: KeyboardKeyCap, bindings: [ShortcutItem]) -> String {
        guard key.isBindable else { return "Touch ID / 电源锁定键" }
        if bindings.isEmpty {
            return "\(key.primaryLabel) (VK \(key.virtualKeyCode)) — 当前无匹配绑定"
        }
        let preview = bindings.prefix(3).map { item in
            let comboStr = item.combo?.displayString ?? key.primaryLabel
            return "\(comboStr): \(item.title)"
        }.joined(separator: "\n")
        return "\(key.primaryLabel) (\(bindings.count) 项绑定)\n\(preview)"
    }

    // MARK: - Detail Panel for Selected Key

    private var selectedKeyDetailPanel: some View {
        Group {
            if let key = selectedKey {
                let bindings = matchingShortcuts(for: key)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(key.primaryLabel)
                            .font(.headline.monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("按键详情 · VirtualKey 0x\(String(key.virtualKeyCode, radix: 16, uppercase: true)) (\(key.virtualKeyCode))")
                                .font(.headline)
                            Text(activeModifiers.isEmpty
                                ? "显示此按键上的全部 \(bindings.count) 项快捷键绑定"
                                : "仅显示修饰键 \(activeModifiers.displaySymbols) 下的 \(bindings.count) 项绑定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let def = KeyCodeCatalog.definition(forVirtualKey: key.virtualKeyCode), def.hidUsage != 0 {
                            Text(String(format: "HID 0x%llX", def.hidUsage))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary.opacity(0.5), in: Capsule())
                        }
                    }

                    if bindings.isEmpty {
                        ContentUnavailableView(
                            "暂无绑定",
                            systemImage: "keyboard",
                            description: Text(activeModifiers.isEmpty
                                ? "按键 \(key.primaryLabel) 当前未被任何快捷键或重映射规则占用。"
                                : "组合 \(activeModifiers.displaySymbols)\(key.primaryLabel) 当前空闲可用。")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(bindings) { item in
                            bindingRow(item)
                        }
                        .listStyle(.inset)
                    }
                }
                .padding(14)
            } else {
                ContentUnavailableView(
                    "点击上方任意按键",
                    systemImage: "hand.tap",
                    description: Text("点击键盘键帽查看该键上的所有系统、应用菜单、开发工具及改键规则，并支持直接修改或跳转。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func bindingRow(_ item: ShortcutItem) -> some View {
        let isConflicting = conflictItemIDs.contains(item.id)
        let catColor = color(for: item.source)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(catColor)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.source.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(catColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(catColor)

                    Text(item.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isConflicting {
                        Label("冲突", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            KeyCapBadge(combo: item.combo, size: .compact, highlighted: isConflicting)

            if item.isEditable {
                ShortcutRecorderView(
                    combo: Binding(
                        get: { item.combo },
                        set: { _ in }
                    ),
                    allowEmpty: false,
                    placeholder: "重绑",
                    onRecordingChanged: { recording in
                        appState.isRecordingShortcut = recording
                    },
                    onCommit: { newCombo in
                        if let newCombo {
                            appState.updateShortcut(item, newCombo: newCombo)
                        }
                    }
                )
                .frame(width: 140)
            }

            Button {
                jumpToItem(item)
            } label: {
                Label("定位", systemImage: "arrow.up.forward.square")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("跳转到对应模块查看并编辑")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Matching & Navigation Helpers

    private func matchingShortcuts(for key: KeyboardKeyCap) -> [ShortcutItem] {
        guard key.isBindable else { return [] }

        let base = appState.allShortcuts.filter { item in
            guard item.isEnabled else { return false }
            if let sourceFilter {
                if sourceFilter == .comboRemap {
                    guard item.source == .comboRemap || item.source == .hidRemap else { return false }
                } else {
                    guard item.source == sourceFilter else { return false }
                }
            }

            if let combo = item.combo {
                guard combo.keyCode == key.virtualKeyCode else { return false }
                if activeModifiers.isEmpty {
                    return true
                }
                return combo.modifiers.intersection(.standardMask) == activeModifiers
            }

            // Fallback for HID items if combo was omitted
            if item.source == .hidRemap,
               let usageStr = item.metadata["sourceUsage"],
               let usage = UInt64(usageStr),
               let def = KeyCodeCatalog.definition(forHIDUsage: usage) {
                return activeModifiers.isEmpty && def.virtualKeyCode == key.virtualKeyCode
            }
            return false
        }

        return base
    }

    private func dominantCategoryColor(for items: [ShortcutItem]) -> Color? {
        guard !items.isEmpty else { return nil }
        let sources = Set(items.map(\.source))
        if sources.contains(.hidRemap) || sources.contains(.comboRemap) { return .orange }
        if sources.contains(.systemSymbolic) { return .blue }
        if sources.contains(.devTool) { return .purple }
        if sources.contains(.appMenu) { return .green }
        return nil
    }

    private func color(for source: ShortcutSource) -> Color {
        switch source {
        case .systemSymbolic: return .blue
        case .appMenu: return .green
        case .devTool: return .purple
        case .hidRemap, .comboRemap: return .orange
        }
    }

    private func jumpToItem(_ item: ShortcutItem) {
        appState.selectedShortcutID = item.id
        switch item.source {
        case .systemSymbolic:
            appState.selectedSection = .system
        case .appMenu:
            if let bundleID = item.appBundleID {
                appState.selectedAppBundleID = bundleID
            }
            appState.selectedSection = .apps
        case .devTool:
            appState.selectedSection = .devTools
        case .hidRemap, .comboRemap:
            appState.selectedSection = .remapper
        }
    }

    // MARK: - NSEvent Flags Monitor

    private func installFlagsMonitor() {
        removeFlagsMonitor()
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let mods = KeyModifiers(nsEventFlags: event.modifierFlags).intersection(.standardMask)
            let fnDown = event.modifierFlags.contains(.function)
            Task { @MainActor in
                physicalModifiers = mods
                physicalFnPressed = fnDown
            }
            return event
        }
    }

    private func removeFlagsMonitor() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }
}
