#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <version> <build>"
  echo "Example: $0 0.8.0 8"
  exit 1
fi

VERSION="$1"
BUILD="$2"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must use MAJOR.MINOR.PATCH (example: 0.8.0)"
  exit 1
fi

if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "Error: build must be an integer (example: 8)"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$PROJECT_DIR/Info.plist"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"
RELEASE_NOTES="$PROJECT_DIR/RELEASE_NOTES_v$VERSION.md"
TODAY="$(date +%F)"
RELEASE_TAG="v$VERSION"

CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

echo "▶ Preparing release metadata"
echo "  Version: $CURRENT_VERSION ($CURRENT_BUILD) -> $VERSION ($BUILD)"

has_existing_tag=false
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1 &&
   git -C "$PROJECT_DIR" rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  has_existing_tag=true
fi

has_existing_changelog_entry=false
if [ -f "$CHANGELOG" ] && grep -Eq "^## v${VERSION//./\\.}([[:space:]]|$)" "$CHANGELOG"; then
  has_existing_changelog_entry=true
fi

if [ "$has_existing_tag" = true ] || [ "$has_existing_changelog_entry" = true ]; then
  echo "Error: release $RELEASE_TAG already appears to exist."
  if [ "$has_existing_tag" = true ]; then
    echo "  - Git tag already exists: $RELEASE_TAG"
  fi
  if [ "$has_existing_changelog_entry" = true ]; then
    echo "  - CHANGELOG.md already contains a section for $RELEASE_TAG"
  fi
  echo "Choose a new version or remove the existing release metadata before retrying."
  exit 1
fi

if [ "$CURRENT_VERSION" != "$VERSION" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
  echo "  Updated CFBundleShortVersionString to $VERSION"
else
  echo "  CFBundleShortVersionString already set to $VERSION"
fi

if [ "$CURRENT_BUILD" != "$BUILD" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$INFO_PLIST"
  echo "  Updated CFBundleVersion to $BUILD"
else
  echo "  CFBundleVersion already set to $BUILD"
fi

if [ ! -f "$RELEASE_NOTES" ]; then
  cat > "$RELEASE_NOTES" <<EOF
# CleanMD v$VERSION

## Highlights

- TODO

## Included

- TODO

## Platform

- macOS 13 or later

## Notes

- TODO
EOF
  echo "  Created release notes template: $(basename "$RELEASE_NOTES")"
else
  echo "  Release notes already exist: $(basename "$RELEASE_NOTES")"
fi

echo ""
echo "Next steps:"
echo "  1. Update CHANGELOG.md: move 'Unreleased' items into '## v$VERSION — $TODAY'"
echo "  2. Review $(basename "$RELEASE_NOTES")"
echo "  3. Run ./scripts/run-smoke-tests.sh"
echo "  4. Run ./scripts/package-release.sh"
echo "  5. Commit and tag:"
echo "     git add Info.plist CHANGELOG.md $(basename "$RELEASE_NOTES")"
echo "     git commit -m \"Release v$VERSION\""
echo "     git tag $RELEASE_TAG"

if [ -f "$CHANGELOG" ]; then
  echo ""
  echo "Reminder: CHANGELOG.md still needs a manual review before release."
fi
