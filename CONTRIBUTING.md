# Contributing to KeyMapStudio

Thank you for your interest in contributing to **KeyMapStudio**! Whether you are reporting a bug, suggesting a new developer tool adapter, fixing an edge case, or improving documentation, your help is deeply appreciated.

---

## Ways to Contribute

- **Report Bugs**: Use our [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md) with reproducible steps and your macOS / chip details.
- **Suggest Features**: Use our [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md) for new IDE/terminal adapters, keyboard layouts, or workflow enhancements.
- **Submit Pull Requests**: Fix issues, improve UI/UX, add Swift Testing coverage, or refine documentation.

---

## Project Architecture

KeyMapStudio is structured as a modular Swift Package targeting **macOS 14.0+ (Swift 6)**:

```text
KeyMapStudio/
├── Package.swift
├── Sources/
│   ├── KeyMapCore/                  # Headless library (100% unit-testable)
│   │   ├── Models/                  # KeyCode, KeyCombo, ShortcutItem, RemapRule, ConflictItem, SnapshotModels
│   │   ├── Services/
│   │   │   ├── AXMenuScanner.swift
│   │   │   ├── AppMenuShortcutStore.swift
│   │   │   ├── SymbolicHotkeyCatalog.swift & SymbolicHotkeyStore.swift
│   │   │   ├── HidRemapManager.swift
│   │   │   ├── ComboRemapEngine.swift
│   │   │   ├── ConflictDetector.swift
│   │   │   ├── SnapshotManager.swift
│   │   │   ├── PermissionManager.swift
│   │   │   └── DevTools/            # DevToolAdapter protocol + VSCodeFamily / ITerm2 / Raycast / Obsidian
│   │   └── Utilities/               # JSONCParser, ShellRunner
│   └── KeyMapStudio/                # Native SwiftUI + AppKit + Carbon app target
│       ├── KeyMapStudioApp.swift
│       ├── State/                   # AppState (@Observable), GlobalHotKeyManager
│       ├── Overlay/                 # QuickOverlayPanelController (NSPanel)
│       └── Views/                   # 8 studio modules + ShortcutRecorderView + KeyCapBadge
├── Tests/
│   └── KeyMapCoreTests/             # Swift Testing suites (isolated temp directories)
└── scripts/
    ├── run.sh                       # Build, bundle, and launch KeyMapStudio.app
    ├── bundle_app.sh                # Compile, generate AppIcon.icns, write Info.plist, ad-hoc sign
    └── package_release.sh           # Build arm64 + x86_64 DMGs, ZIPs & SHA256SUMS.txt
```

---

## Development Setup & Local Verification

### Prerequisites

- macOS 14.0 (Sonoma) or newer
- Swift 6.0+ toolchain (Xcode 16+ or Apple Command Line Tools)

### Running Tests

All unit tests live in `Tests/KeyMapCoreTests/` and use **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect` — never `XCTest`).

```bash
swift test
```

> **Note for standalone Command Line Tools (without Xcode.app)**: On newer macOS SDKs where CLT lacks `SwiftUIMacros` or needs the testing macro plugin path explicitly, run:
> ```bash
> SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
>   swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
> ```

**Important test safety rule**: Unit tests MUST always operate on isolated temporary directories (`FileManager.default.temporaryDirectory`) and MUST NEVER mutate real user preferences (`~/Library/Preferences`), invoke live `hidutil property --set`, or execute `activateSettings -u`.

### Building and Running the App

```bash
# Build release bundle and launch build/KeyMapStudio.app
./scripts/run.sh

# Or build a specific configuration & architecture
./scripts/bundle_app.sh debug host
./scripts/bundle_app.sh release arm64
./scripts/bundle_app.sh release x86_64

# Verify code signature
codesign --verify --deep --strict --verbose=2 build/KeyMapStudio.app
```

---

## Coding & Adapter Guidelines

1. **Zero compiler warnings**: Keep builds clean across both Xcode and CommandLineTools toolchains.
2. **Thread safety & Swift concurrency**: Keep `KeyMapCore` models `Sendable` and protect mutable engine/service state properly (`NSLock` or `@MainActor`).
3. **Shortcut Recorder safety**: Any new view embedding `ShortcutRecorderView` MUST wire `onRecordingChanged: { appState.isRecordingShortcut = $0 }` so `ComboRemapEngine` pauses automatically during key capture.
4. **Adding a New DevTool Adapter**:
   - Conform to `DevToolAdapter` in `Sources/KeyMapCore/Services/DevTools/`.
   - Register it in `DevToolRegistry.defaultAdapters()`.
   - Clearly set `supportsWrite` (`false` if external mutations could corrupt live app state).
   - Add thorough isolated tests in `Tests/KeyMapCoreTests/DevToolAdaptersTests.swift`.
5. **Preserve comments & non-ASCII UI conventions**: Keep existing documentation intact and match the existing Simplified Chinese UI terminology in `Sources/KeyMapStudio/Views/`.

---

## Pull Request Process

1. Fork the repository and create a feature branch from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. Use descriptive [Conventional Commits](https://www.conventionalcommits.org/) messages (e.g., `feat:`, `fix:`, `docs:`, `test:`, `chore:`).
3. Ensure `swift test` and `./scripts/bundle_app.sh` pass with zero errors or warnings.
4. Open a Pull Request explaining **what changed**, **why**, and **how it was verified** (include screenshots for UI changes).
