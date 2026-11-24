import AppKit
import ApplicationServices
import Foundation

public final class AXMenuScanner: @unchecked Sendable {
    private static let maxMenuDepth = 5
    private static let maxChildrenPerMenu = 200
    private static let dynamicMenuTitles: Set<String> = [
        "open recent",
        "最近打开",
        "最近使用的项目",
        "bookmarks",
        "书签",
        "history",
        "历史记录"
    ]

    public init() {}

    public func listRunningApps() -> [RunningAppInfo] {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> RunningAppInfo? in
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  !bundleID.isEmpty else {
                return nil
            }
            return RunningAppInfo(
                pid: app.processIdentifier,
                bundleID: bundleID,
                name: app.localizedName ?? bundleID,
                isActive: app.isActive
            )
        }

        return apps.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func scanMenuShortcuts(
        for app: RunningAppInfo,
        overrides: [String: String] = [:]
    ) async -> [ShortcutItem] {
        await Task.detached(priority: .userInitiated) {
            guard AXIsProcessTrusted() else {
                return []
            }

            let appElement = AXUIElementCreateApplication(app.pid)
            AXUIElementSetMessagingTimeout(appElement, 1.5)

            var menuBarRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)
            guard status == .success,
                  let rawMenuBar = menuBarRef,
                  CFGetTypeID(rawMenuBar) == AXUIElementGetTypeID() else {
                return []
            }

            let menuBar = unsafeBitCast(rawMenuBar, to: AXUIElement.self)
            var results: [ShortcutItem] = []
            var seenIDs = Set<String>()

            let topItems = Self.children(of: menuBar)
            for barItem in topItems {
                guard let topTitle = Self.stringAttribute(kAXTitleAttribute, of: barItem)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !topTitle.isEmpty,
                      topTitle != "Apple",
                      !Self.isDynamicMenu(topTitle) else {
                    continue
                }

                for subMenu in Self.children(of: barItem) {
                    Self.traverseMenu(
                        element: subMenu,
                        app: app,
                        overrides: overrides,
                        pathComponents: [topTitle],
                        depth: 1,
                        results: &results,
                        seenIDs: &seenIDs
                    )
                }
            }

            return results
        }.value
    }

    // MARK: - AX Traversal

    private static func traverseMenu(
        element: AXUIElement,
        app: RunningAppInfo,
        overrides: [String: String],
        pathComponents: [String],
        depth: Int,
        results: inout [ShortcutItem],
        seenIDs: inout Set<String>
    ) {
        guard depth <= maxMenuDepth else { return }

        let children = Self.children(of: element)
        for child in children {
            let role = stringAttribute(kAXRoleAttribute, of: child)
            if role == "AXSeparator" || stringAttribute(kAXSubroleAttribute, of: child) == "AXMenuItemSeparator" {
                continue
            }

            if role == (kAXMenuRole as String) {
                traverseMenu(
                    element: child,
                    app: app,
                    overrides: overrides,
                    pathComponents: pathComponents,
                    depth: depth,
                    results: &results,
                    seenIDs: &seenIDs
                )
                continue
            }

            guard let rawTitle = stringAttribute(kAXTitleAttribute, of: child) else {
                continue
            }
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !isDynamicMenu(title) else {
                continue
            }

            let subChildren = Self.children(of: child)
            if !subChildren.isEmpty {
                if depth < maxMenuDepth {
                    for sub in subChildren {
                        traverseMenu(
                            element: sub,
                            app: app,
                            overrides: overrides,
                            pathComponents: pathComponents + [title],
                            depth: depth + 1,
                            results: &results,
                            seenIDs: &seenIDs
                        )
                    }
                }
                continue
            }

            let fullPath = pathComponents + [title]
            let menuPath = AppMenuShortcutStore.formatMenuPath(fullPath)
            let displayPath = fullPath.joined(separator: " → ")

            let cmdChar = stringAttribute(kAXMenuItemCmdCharAttribute, of: child)
            let rawVirtualKey = intAttribute(kAXMenuItemCmdVirtualKeyAttribute, of: child)
            let cmdVirtualKey = rawVirtualKey.flatMap { ($0 >= 0 && $0 < Int(UInt16.max)) ? $0 : nil }
            let cmdModifiers = intAttribute(kAXMenuItemCmdModifiersAttribute, of: child) ?? 0
            let axCombo = KeyCombo.fromAX(
                cmdChar: cmdChar,
                virtualKey: cmdVirtualKey,
                axModifiers: cmdModifiers
            )

            let rawOverride = overrides[menuPath] ?? overrides[title]
            let overrideCombo = rawOverride.flatMap { KeyCombo.parseNSUserKeyEquivalent($0) }

            guard let effectiveCombo = overrideCombo ?? axCombo else {
                continue
            }

            let baseID = "appMenu.\(app.bundleID).\(menuPath)"
            var uniqueID = baseID
            var duplicateIndex = 2
            while seenIDs.contains(uniqueID) {
                uniqueID = "\(baseID)#\(duplicateIndex)"
                duplicateIndex += 1
            }
            seenIDs.insert(uniqueID)

            let item = ShortcutItem(
                id: uniqueID,
                title: title,
                subtitle: displayPath,
                category: fullPath.first ?? "菜单",
                source: .appMenu,
                appBundleID: app.bundleID,
                appName: app.name,
                combo: effectiveCombo,
                defaultCombo: axCombo,
                isEnabled: true,
                isModified: overrideCombo != nil,
                isEditable: true,
                metadata: [
                    "menuTitle": title,
                    "menuPath": menuPath,
                    "displayPath": displayPath
                ]
            )
            results.append(item)
        }
    }

    private static func isDynamicMenu(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if dynamicMenuTitles.contains(normalized) {
            return true
        }
        return normalized.hasPrefix("open recent") || normalized.hasPrefix("最近打开")
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard status == .success, let array = value as? [AnyObject] else {
            return []
        }

        var result: [AXUIElement] = []
        result.reserveCapacity(min(array.count, maxChildrenPerMenu))
        for raw in array.prefix(maxChildrenPerMenu) {
            let cfObj: CFTypeRef = raw
            if CFGetTypeID(cfObj) == AXUIElementGetTypeID() {
                result.append(unsafeBitCast(cfObj, to: AXUIElement.self))
            }
        }
        return result
    }

    private static func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else { return nil }
        return value as? String
    }

    private static func intAttribute(_ attribute: String, of element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else { return nil }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }
}
