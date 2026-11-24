#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${2:-${KEYMAPSTUDIO_ARCH:-host}}"

if [[ -n "${KEYMAPSTUDIO_OUT_APP:-}" ]]; then
    if [[ "$KEYMAPSTUDIO_OUT_APP" == /* ]]; then
        APP_DIR="$KEYMAPSTUDIO_OUT_APP"
    else
        APP_DIR="$(pwd)/$KEYMAPSTUDIO_OUT_APP"
    fi
elif [[ "$ARCH" == "host" ]]; then
    APP_DIR="$PROJECT_ROOT/build/KeyMapStudio.app"
else
    APP_DIR="$PROJECT_ROOT/build/${ARCH}/KeyMapStudio.app"
fi

KEYMAPSTUDIO_OUT_APP="$APP_DIR" "$PROJECT_ROOT/scripts/bundle_app.sh" "$@"
open -n "$APP_DIR"
