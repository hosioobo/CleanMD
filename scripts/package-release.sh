#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/CleanMD.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
ZIP_PATH="$PROJECT_DIR/CleanMD-v${VERSION}-macOS.zip"

if [ -e "$ZIP_PATH" ] && [ "${OVERWRITE:-0}" != "1" ]; then
  echo "Error: $ZIP_PATH already exists."
  echo "Set OVERWRITE=1 to replace it."
  exit 1
fi

echo "▶ Building CleanMD.app for release..."
NO_OPEN=1 "$PROJECT_DIR/build.sh"

echo "▶ Packaging $(basename "$ZIP_PATH")..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "✓ Created $ZIP_PATH"
