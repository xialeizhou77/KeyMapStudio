# Changelog

All notable changes to **KeyMapStudio** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-24

### Added

- **macOS System Symbolic Hotkeys**: Built-in catalog of 53 macOS system shortcuts across Spotlight, Input Sources, Screenshots, Mission Control & Spaces, Dock, Keyboard & Focus, and Accessibility, with live plist read/write (`com.apple.symbolichotkeys.plist`) and immediate apply via `activateSettings -u`.
- **Application Menu Scanning & Overrides**: Accessibility (`AXUIElement`) scanner for running apps with hierarchical menu path resolution, `NSUserKeyEquivalents` override persistence, one-click reset, and target app restart support.
- **Global Quick Overlay HUD (`⌥⌘K`)**: Borderless floating `NSPanel` triggered via Carbon global hotkey (`RegisterEventHotKey`) that automatically captures the frontmost app's menu shortcuts with modifier filter pills and inline rebinding.
- **Interactive 78-Key Mac ANSI Virtual Keyboard**: 6-row proportional keyboard visualization with live `NSEvent.flagsChanged` physical modifier tracking, lockable modifier toggles, source-coded color highlights, and conflict indicators.
- **Low-Level Key Remapping**:
  - `hidutil` single-key hardware remapper with 4 built-in presets (Caps Lock → Escape, Caps Lock → Left Control, Escape → Caps Lock, Right ⌘ → Forward Delete), custom key rules, reset all, and LaunchAgent login persistence.
  - `CGEventTap` combo remapping engine with loop-prevention event tagging (`0x4B4D5354`), optional per-app `bundleID` scoping, automatic pause during shortcut recording, and menu bar quick stop.
- **Developer Tools Shortcut Aggregation**: Unified adapters for VS Code, Cursor, and Antigravity (JSONC-aware with `-command` disable support), iTerm2 (`GlobalKeyMap` and profile `Keyboard Map`), Obsidian (multi-vault discovery via `obsidian.json`), and Raycast (read-only global & command hotkeys).
- **Cross-Layer Conflict Center**: Canonical key-combo conflict detection categorizing collisions into Critical, Warning, and Info levels without false positives across separate applications' menu shortcuts.
- **Snapshot Backup & Migration**: Timestamped full configuration snapshots with 5-domain diffing, rollback restore, and JSON export/import.
- **Packaging & CI/CD**: Dual-architecture (`arm64` Apple Silicon & `x86_64` Intel) app bundling (`scripts/bundle_app.sh`), DMG/ZIP/SHA256 release packaging (`scripts/package_release.sh`), and GitHub Actions CI & Release workflows.
