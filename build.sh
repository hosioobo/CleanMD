#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CleanMD"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"
BUILD_DIR="$PROJECT_DIR/.build/release"
SWIFTPM_CACHE_ROOT="${TMPDIR%/}/cleanmd-swiftpm"
SWIFTPM_HOME="$SWIFTPM_CACHE_ROOT/home"
CLANG_CACHE="$SWIFTPM_CACHE_ROOT/clang-module-cache"
SWIFTPM_CACHE="$SWIFTPM_CACHE_ROOT/cache"

cd "$PROJECT_DIR"

# --- App icon (regenerate only if makeicon.swift is newer than the icns) ---
if [ ! -f "$PROJECT_DIR/AppIcon.icns" ] || \
   [ "$PROJECT_DIR/makeicon.swift" -nt "$PROJECT_DIR/AppIcon.icns" ]; then
    echo "▶ Generating app icon..."
    swift "$PROJECT_DIR/makeicon.swift"
    iconutil -c icns "$PROJECT_DIR/AppIcon.iconset" -o "$PROJECT_DIR/AppIcon.icns"
fi

echo "▶ Building $APP_NAME..."
mkdir -p "$SWIFTPM_HOME" "$CLANG_CACHE" "$SWIFTPM_CACHE"
HOME="$SWIFTPM_HOME" \
CFFIXED_USER_HOME="$SWIFTPM_HOME" \
XDG_CACHE_HOME="$SWIFTPM_HOME/.cache" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
SWIFTPM_CUSTOM_CACHE_PATH="$SWIFTPM_CACHE" \
swift build --disable-sandbox -c release 2>&1

echo ""
echo "▶ Packaging $APP_NAME.app..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources/fonts"

# Binary
cp "$BUILD_DIR/$APP_NAME" "$APP_PATH/Contents/MacOS/"

# JS/CSS resources — copy from source (always authoritative)
cp "$PROJECT_DIR/CleanMD/Resources/"*.js  "$APP_PATH/Contents/Resources/" 2>/dev/null || true
cp "$PROJECT_DIR/CleanMD/Resources/"*.css "$APP_PATH/Contents/Resources/" 2>/dev/null || true
cp "$PROJECT_DIR/CleanMD/Resources/fonts/"*.woff2 "$APP_PATH/Contents/Resources/fonts/" 2>/dev/null || true

# Info.plist + icon
cp "$PROJECT_DIR/Info.plist"   "$APP_PATH/Contents/"
cp "$PROJECT_DIR/AppIcon.icns" "$APP_PATH/Contents/Resources/"

echo "▶ Code signing (ad-hoc)..."
codesign --sign - --force --deep "$APP_PATH"

echo "▶ Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP_PATH" 2>/dev/null || true

echo ""
echo "✓ Built: $APP_PATH"

if [ "${NO_OPEN:-0}" = "1" ]; then
    echo "▶ Skipping launch (NO_OPEN=1)"
else
    echo "▶ Launching..."
    open "$APP_PATH"
fi
