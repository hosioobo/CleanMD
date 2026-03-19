#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR%/}/cleanmd-smoke"
OUT="$TMP_ROOT/cleanmd-smoke-tests"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
FRAMEWORKS_PATH="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

mkdir -p "$TMP_ROOT" "$TMP_ROOT/home" "$TMP_ROOT/cache" "$TMP_ROOT/clang-module-cache"

HOME="$TMP_ROOT/home" \
CFFIXED_USER_HOME="$TMP_ROOT/home" \
XDG_CACHE_HOME="$TMP_ROOT/cache" \
CLANG_MODULE_CACHE_PATH="$TMP_ROOT/clang-module-cache" \
swiftc \
  -sdk "$SDK_PATH" \
  -F "$FRAMEWORKS_PATH" \
  "$PROJECT_DIR/CleanMD/SupportedDocumentKind.swift" \
  "$PROJECT_DIR/CleanMD/PathDisplayFormatter.swift" \
  "$PROJECT_DIR/CleanMD/MarkdownTableNormalizer.swift" \
  "$PROJECT_DIR/CleanMD/FileExplorerStore.swift" \
  "$PROJECT_DIR/scripts/SmokeTestsMain.swift" \
  -o "$OUT"

"$OUT"
