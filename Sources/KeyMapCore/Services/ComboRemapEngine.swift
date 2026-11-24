import AppKit
import CoreGraphics
import Foundation

public final class ComboRemapEngine: @unchecked Sendable {
    private static let antiLoopMagicTag: Int64 = 0x4B4D5354 // 'KMST'
    private static let standardCGEventFlagsMask: CGEventFlags = [
        .maskShift,
        .maskControl,
        .maskAlternate,
        .maskCommand
    ]

    public let rulesFileURL: URL

    private let lock = NSLock()
    private var _rules: [ComboRemapRule] = []
    private var _isRunning: Bool = false
    private var _isPausedForRecording: Bool = false
    private var _frontmostBundleID: String?
    private var _activeRemappedKeys: [UInt16: KeyCombo] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var workspaceObserver: NSObjectProtocol?

    public var rules: [ComboRemapRule] {
        lock.withLock { _rules }
    }

    public var isRunning: Bool {
        lock.withLock { _isRunning }
    }

    public var isPausedForRecording: Bool {
        get { lock.withLock { _isPausedForRecording } }
        set { lock.withLock { _isPausedForRecording = newValue } }
    }

    public init(
        rulesFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KeyMapStudio/combo_rules.json")
    ) {
        self.rulesFileURL = rulesFileURL
        _ = loadRules()
    }

    deinit {
        stop()
    }

    @discardableResult
    public func loadRules() -> [ComboRemapRule] {
        let loaded: [ComboRemapRule]
        if FileManager.default.fileExists(atPath: rulesFileURL.path),
           let data = try? Data(contentsOf: rulesFileURL),
           let decoded = try? JSONDecoder().decode([ComboRemapRule].self, from: data) {
            loaded = decoded
        } else {
            loaded = []
        }

        lock.withLock {
            _rules = loaded
        }
        return loaded
    }

    public func saveRules(_ newRules: [ComboRemapRule]) throws {
        try FileManager.default.createDirectory(
            at: rulesFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(newRules)
        try data.write(to: rulesFileURL, options: .atomic)

        lock.withLock {
            _rules = newRules
        }
    }

    @discardableResult
    public func start() -> Bool {
        let alreadyRunning = lock.withLock { _isRunning }
        if alreadyRunning {
            return true
        }

        let initialFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            self?.lock.withLock {
                self?._frontmostBundleID = bundleID
            }
        }

        lock.withLock {
            _frontmostBundleID = initialFrontmost
            workspaceObserver = observer
            _activeRemappedKeys.removeAll()
        }

        let startupSemaphore = DispatchSemaphore(value: 0)
        var createdSuccessfully = false

        let thread = Thread { [weak self] in
            guard let self else {
                startupSemaphore.signal()
                return
            }

            let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let engine = Unmanaged<ComboRemapEngine>.fromOpaque(userInfo).takeUnretainedValue()
                return engine.handleTapEvent(proxy: proxy, type: type, event: event)
            }

            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                createdSuccessfully = false
                startupSemaphore.signal()
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let currentLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(currentLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            self.lock.withLock {
                self.eventTap = tap
                self.runLoopSource = source
                self.tapRunLoop = currentLoop
                self._isRunning = true
            }

            createdSuccessfully = true
            startupSemaphore.signal()
            CFRunLoopRun()
        }

        thread.name = "com.keymapstudio.ComboRemapEngine"
        thread.qualityOfService = .userInteractive
        thread.start()

        startupSemaphore.wait()

        if !createdSuccessfully {
            lock.withLock {
                if let obs = workspaceObserver {
                    NSWorkspace.shared.notificationCenter.removeObserver(obs)
                }
                workspaceObserver = nil
                _isRunning = false
            }
        }

        return createdSuccessfully
    }

    public func stop() {
        let resources: (tap: CFMachPort?, source: CFRunLoopSource?, loop: CFRunLoop?, observer: NSObjectProtocol?) = lock.withLock {
            let captured = (eventTap, runLoopSource, tapRunLoop, workspaceObserver)
            eventTap = nil
            runLoopSource = nil
            tapRunLoop = nil
            workspaceObserver = nil
            _isRunning = false
            _activeRemappedKeys.removeAll()
            return captured
        }

        if let observer = resources.observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let tap = resources.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let loop = resources.loop, let source = resources.source {
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        if let loop = resources.loop {
            CFRunLoopStop(loop)
        }
    }

    // MARK: - Event Handling

    private func handleTapEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        _ = proxy

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = lock.withLock({ eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.antiLoopMagicTag {
            return Unmanaged.passUnretained(event)
        }

        let snapshot: (paused: Bool, rules: [ComboRemapRule], frontmost: String?) = lock.withLock {
            (_isPausedForRecording, _rules, _frontmostBundleID)
        }

        if snapshot.paused {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp {
            let activeTarget: KeyCombo? = lock.withLock {
                _activeRemappedKeys.removeValue(forKey: keyCode)
            }
            if let target = activeTarget {
                applyTargetCombo(target, to: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let incomingModifiers = KeyModifiers(cgEventFlags: event.flags).intersection(.standardMask)
        let activeFrontmost = snapshot.frontmost

        var matchedAppRule: ComboRemapRule?
        var matchedGlobalRule: ComboRemapRule?

        for rule in snapshot.rules where rule.isEnabled {
            guard rule.source.keyCode == keyCode,
                  rule.source.modifiers.intersection(.standardMask) == incomingModifiers else {
                continue
            }

            if let targetBundleID = rule.targetAppBundleID, !targetBundleID.isEmpty {
                if targetBundleID == activeFrontmost {
                    matchedAppRule = rule
                    break
                }
            } else if matchedGlobalRule == nil {
                matchedGlobalRule = rule
            }
        }

        guard let matched = matchedAppRule ?? matchedGlobalRule else {
            return Unmanaged.passUnretained(event)
        }

        lock.withLock {
            _activeRemappedKeys[keyCode] = matched.target
        }

        applyTargetCombo(matched.target, to: event)
        return Unmanaged.passUnretained(event)
    }

    private func applyTargetCombo(_ target: KeyCombo, to event: CGEvent) {
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(target.keyCode))
        let nonModifierFlags = event.flags.subtracting(Self.standardCGEventFlagsMask)
        event.flags = nonModifierFlags.union(target.modifiers.cgEventFlags)
        event.setIntegerValueField(.eventSourceUserData, value: Self.antiLoopMagicTag)
    }
}
