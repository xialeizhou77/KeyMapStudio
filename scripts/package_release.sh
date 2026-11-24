#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${KEYMAPSTUDIO_VERSION:-1.0.0}"
DIST_DIR="$PROJECT_ROOT/dist"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/KeyMapStudio-*.dmg "$DIST_DIR"/KeyMapStudio-*.zip "$DIST_DIR/SHA256SUMS.txt"

STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/keymapstudio-release.XXXXXX")"
trap 'rm -rf "$STAGE_ROOT"' EXIT

package_arch() {
    local arch="$1"
    local artifact_prefix="$2"
    local app_dir="$PROJECT_ROOT/build/${arch}/KeyMapStudio.app"
    local dmg_path="$DIST_DIR/${artifact_prefix}.dmg"
    local zip_path="$DIST_DIR/${artifact_prefix}.zip"
    local stage_dir="$STAGE_ROOT/${artifact_prefix}"

    echo "=== Packaging ${artifact_prefix} (${arch}, v${VERSION}) ==="
    KEYMAPSTUDIO_VERSION="$VERSION" KEYMAPSTUDIO_OUT_APP="$app_dir" \
        "$PROJECT_ROOT/scripts/bundle_app.sh" release "$arch"

    rm -rf "$stage_dir"
    mkdir -p "$stage_dir"
    ditto "$app_dir" "$stage_dir/KeyMapStudio.app"
    ln -s /Applications "$stage_dir/Applications"

    rm -f "$dmg_path" "$zip_path"
    hdiutil create -volname "KeyMapStudio" -srcfolder "$stage_dir" -ov -format UDZO "$dmg_path"
    ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"
}

package_arch arm64 "KeyMapStudio-AppleSilicon-arm64"
package_arch x86_64 "KeyMapStudio-Intel-x86_64"

(
    cd "$DIST_DIR"
    shasum -a 256 KeyMapStudio-*.dmg KeyMapStudio-*.zip > SHA256SUMS.txt
)

echo "=== Release artifacts in $DIST_DIR ==="
ls -lh "$DIST_DIR"
echo "=== SHA256SUMS.txt ==="
cat "$DIST_DIR/SHA256SUMS.txt"
