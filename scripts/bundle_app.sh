#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALLER_PWD="$(pwd)"

BUILD_CONFIG="${1:-${KEYMAPSTUDIO_BUILD_CONFIG:-release}}"
ARCH="${2:-${KEYMAPSTUDIO_ARCH:-host}}"
VERSION="${KEYMAPSTUDIO_VERSION:-1.0.0}"
APP_NAME="KeyMapStudio"

case "$BUILD_CONFIG" in
    release|debug) ;;
    *)
        echo "Error: invalid build configuration '$BUILD_CONFIG' (expected 'release' or 'debug')" >&2
        exit 1
        ;;
esac

case "$ARCH" in
    arm64|x86_64|host) ;;
    *)
        echo "Error: invalid architecture '$ARCH' (expected 'arm64', 'x86_64', or 'host')" >&2
        exit 1
        ;;
esac

if [[ -n "${KEYMAPSTUDIO_OUT_APP:-}" ]]; then
    if [[ "$KEYMAPSTUDIO_OUT_APP" == /* ]]; then
        APP_DIR="$KEYMAPSTUDIO_OUT_APP"
    else
        APP_DIR="$CALLER_PWD/$KEYMAPSTUDIO_OUT_APP"
    fi
elif [[ "$ARCH" == "host" ]]; then
    APP_DIR="$PROJECT_ROOT/build/${APP_NAME}.app"
else
    APP_DIR="$PROJECT_ROOT/build/${ARCH}/${APP_NAME}.app"
fi

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$PROJECT_ROOT"

sdk_requires_swiftui_macros() {
    local sdk_path="$1"
    local swiftmodule_dir="$sdk_path/System/Library/Frameworks/SwiftUICore.framework/Versions/A/Modules/SwiftUICore.swiftmodule"
    local iface
    for iface in "$swiftmodule_dir"/*-apple-macos.swiftinterface; do
        [[ -f "$iface" ]] || continue
        if grep -q 'type: "StateMacro"' "$iface"; then
            return 0
        fi
    done
    return 1
}

select_compatible_sdk() {
    if [[ -n "${SDKROOT:-}" ]]; then
        return 0
    fi

    local dev_dir default_sdk sdk_dir candidate
    dev_dir="$(xcode-select -p 2>/dev/null || true)"
    # Only apply the CLT fallback when Xcode is not selected (never override SDKROOT on macos-15 / Xcode runners).
    if [[ "$dev_dir" != "/Library/Developer/CommandLineTools" ]]; then
        return 0
    fi

    if find "$dev_dir" -maxdepth 7 -name "*SwiftUIMacros*" 2>/dev/null | grep -q .; then
        return 0
    fi

    default_sdk="$(xcrun --show-sdk-path 2>/dev/null || true)"
    [[ -z "$default_sdk" ]] && return 0

    if sdk_requires_swiftui_macros "$default_sdk"; then
        sdk_dir="$(dirname "$default_sdk")"
        while IFS= read -r candidate; do
            [[ -z "$candidate" ]] && continue
            if ! sdk_requires_swiftui_macros "$candidate"; then
                export SDKROOT="$candidate"
                echo "Detected CLT missing SwiftUIMacros; using compatible SDK: $SDKROOT"
                return 0
            fi
        done < <(find "$sdk_dir" -maxdepth 1 -type d -name 'MacOSX[0-9]*.sdk' 2>/dev/null | sort -rV)
        echo "Warning: CLT lacks SwiftUIMacros and no fallback SDK without StateMacro was found under $sdk_dir" >&2
    fi
}

select_compatible_sdk

BUILD_ARGS=(-c "$BUILD_CONFIG")
if [[ "$ARCH" != "host" ]]; then
    BUILD_ARGS+=(--arch "$ARCH")
fi

echo "Building ${APP_NAME} (${BUILD_CONFIG}, arch=${ARCH}, version=${VERSION})..."
swift build "${BUILD_ARGS[@]}"

BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Error: compiled binary not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "Generating app icon..."
swift "$PROJECT_ROOT/scripts/generate_icon.swift" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>KeyMapStudio</string>
    <key>CFBundleExecutable</key>
    <string>KeyMapStudio</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.keymapstudio.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KeyMapStudio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>KeyMapStudio 需要使用 Apple Events 与辅助功能权限读取应用菜单快捷键并在修改后协助重启目标应用。</string>
</dict>
</plist>
PLIST

echo "Signing ${APP_DIR}..."
codesign --force --deep --sign - "$APP_DIR"

echo "Verifying binary architecture and signature..."
lipo -info "$MACOS_DIR/$APP_NAME"
codesign --verify --deep --strict "$APP_DIR"

echo "Bundled successfully: $APP_DIR"
