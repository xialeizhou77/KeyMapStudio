import Foundation

public enum ConflictDetector {
    public static func detect(in items: [ShortcutItem]) -> [ConflictItem] {
        let activeItems = items.filter { $0.isEnabled && $0.combo != nil }
        let grouped = Dictionary(grouping: activeItems) { item in
            item.combo!.canonicalKey
        }

        var conflicts: [ConflictItem] = []

        for (canonicalKey, group) in grouped {
            guard group.count >= 2, let combo = group.first?.combo else {
                continue
            }

            if let conflict = evaluateGroup(canonicalKey: canonicalKey, combo: combo, items: group) {
                conflicts.append(conflict)
            }
        }

        return conflicts.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            return lhs.combo.displayString < rhs.combo.displayString
        }
    }

    // MARK: - Classification

    private static func evaluateGroup(
        canonicalKey: String,
        combo: KeyCombo,
        items: [ShortcutItem]
    ) -> ConflictItem? {
        let globalItems = items.filter(isGlobalScope)
        let nonGlobalItems = items.filter { !isGlobalScope($0) }

        let sameAppMenuGroups = Dictionary(
            grouping: items.filter { item in
                item.source == .appMenu &&
                !isGlobalScope(item) &&
                !(item.appBundleID ?? "").isEmpty
            },
            by: { $0.appBundleID! }
        ).filter { $0.value.count >= 2 }

        let devToolByToolID = Dictionary(
            grouping: items.filter { item in
                item.source == .devTool && !isGlobalScope(item)
            },
            by: { toolIdentifier(for: $0) }
        )

        var sameToolSameWhenGroups: [[ShortcutItem]] = []
        var sameToolDiffWhenGroups: [[ShortcutItem]] = []

        for (_, toolItems) in devToolByToolID where toolItems.count >= 2 {
            let byWhen = Dictionary(grouping: toolItems) { item in
                normalizedWhen(item.metadata["when"]) ?? "__NIL__"
            }
            let duplicateSameWhen = byWhen.values.filter { $0.count >= 2 }
            if !duplicateSameWhen.isEmpty {
                sameToolSameWhenGroups.append(contentsOf: duplicateSameWhen)
            }
            if byWhen.keys.count >= 2 {
                sameToolDiffWhenGroups.append(toolItems)
            }
        }

        let severity: ConflictSeverity
        let reason: String

        if globalItems.count >= 2 {
            severity = .critical
            let names = uniqueDisplayNames(for: globalItems)
            reason = "多个全局快捷键共用了 \(combo.displayString)（\(names)）"
        } else if !sameAppMenuGroups.isEmpty {
            severity = .critical
            let appNames = sameAppMenuGroups.values.compactMap { $0.first?.appName }.sorted().joined(separator: "、")
            reason = "同一应用（\(appNames)）内存在多个菜单项使用相同快捷键 \(combo.displayString)"
        } else if !sameToolSameWhenGroups.isEmpty {
            severity = .critical
            let toolNames = sameToolSameWhenGroups.compactMap { $0.first?.appName }.sorted().joined(separator: "、")
            reason = "同一开发工具（\(toolNames)）在相同上下文条件下存在重复快捷键 \(combo.displayString)"
        } else if globalItems.count >= 1 && !nonGlobalItems.isEmpty {
            severity = .warning
            let globalNames = uniqueDisplayNames(for: globalItems)
            reason = "全局快捷键（\(globalNames)）与局部应用/工具快捷键共用 \(combo.displayString)，触发时可能被全局拦截"
        } else if !sameToolDiffWhenGroups.isEmpty {
            severity = .info
            let toolNames = sameToolDiffWhenGroups.compactMap { $0.first?.appName }.sorted().joined(separator: "、")
            reason = "同一开发工具（\(toolNames)）在不同上下文条件（when）下共用了 \(combo.displayString)"
        } else {
            return nil
        }

        let involvedItems: [ShortcutItem]
        if !globalItems.isEmpty {
            involvedItems = items
        } else {
            var seenIDs = Set<String>()
            var collected: [ShortcutItem] = []

            let appendUnique: ([ShortcutItem]) -> Void = { list in
                for item in list where seenIDs.insert(item.id).inserted {
                    collected.append(item)
                }
            }

            for group in sameAppMenuGroups.values {
                appendUnique(group)
            }
            for group in sameToolSameWhenGroups {
                appendUnique(group)
            }
            for group in sameToolDiffWhenGroups {
                appendUnique(group)
            }

            involvedItems = collected
        }

        guard involvedItems.count >= 2 else { return nil }

        return ConflictItem(
            id: "conflict|\(canonicalKey)",
            combo: combo,
            severity: severity,
            reason: reason,
            items: involvedItems
        )
    }

    private static func isGlobalScope(_ item: ShortcutItem) -> Bool {
        if item.metadata["isGlobal"] == "true" {
            return true
        }
        if item.appBundleID == "NSGlobalDomain" {
            return true
        }
        switch item.source {
        case .systemSymbolic, .hidRemap:
            return true
        case .comboRemap:
            let target = (item.metadata["targetAppBundleID"] ?? item.appBundleID ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return target.isEmpty || target == "NSGlobalDomain"
        case .appMenu, .devTool:
            return false
        }
    }

    private static func toolIdentifier(for item: ShortcutItem) -> String {
        if let toolID = item.metadata["toolID"], !toolID.isEmpty {
            return toolID
        }
        if let bundleID = item.appBundleID, !bundleID.isEmpty {
            return bundleID
        }
        return item.appName
    }

    private static func normalizedWhen(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func uniqueDisplayNames(for items: [ShortcutItem]) -> String {
        var seen = Set<String>()
        var names: [String] = []
        for item in items {
            let label = item.appName.isEmpty ? item.title : item.appName
            if seen.insert(label).inserted {
                names.append(label)
            }
        }
        return names.joined(separator: "、")
    }
}
