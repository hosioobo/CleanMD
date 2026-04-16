#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${GITHUB_REPOSITORY:-hosioobo/CleanMD}"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")}"
TAG="v$VERSION"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"
ASSET="$PROJECT_DIR/CleanMD-v${VERSION}-macOS.zip"
TEMP_NOTES="$(mktemp)"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must use MAJOR.MINOR.PATCH (example: 0.8.0)"
  exit 1
fi

if [ ! -f "$CHANGELOG" ]; then
  echo "Error: missing changelog file: $CHANGELOG"
  exit 1
fi

awk -v tag="$TAG" '
  $0 ~ "^## " tag "([[:space:]]|$)" {capture=1}
  capture && $0 ~ "^## " && $0 !~ "^## " tag "([[:space:]]|$)" {exit}
  capture {print}
' "$CHANGELOG" > "$TEMP_NOTES"

if [ ! -s "$TEMP_NOTES" ]; then
  echo "Error: CHANGELOG.md does not contain a section for $TAG"
  rm -f "$TEMP_NOTES"
  exit 1
fi

if [ ! -f "$ASSET" ]; then
  echo "Error: missing release asset: $ASSET"
  exit 1
fi

if ! git -C "$PROJECT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Error: missing local Git tag $TAG"
  echo "Create the tag first: git tag $TAG"
  exit 1
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Release $TAG already exists on GitHub."
  exit 1
fi

echo "▶ Creating GitHub release $TAG on $REPO..."
gh release create "$TAG" \
  "$ASSET" \
  --repo "$REPO" \
  --title "CleanMD $TAG" \
  --notes-file "$TEMP_NOTES"

rm -f "$TEMP_NOTES"

echo "✓ GitHub release created: $TAG"
