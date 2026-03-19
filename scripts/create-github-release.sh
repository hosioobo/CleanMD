#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${GITHUB_REPOSITORY:-hosioobo/CleanMD}"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")}"
TAG="v$VERSION"
RELEASE_NOTES="$PROJECT_DIR/RELEASE_NOTES_v$VERSION.md"
ASSET="$PROJECT_DIR/CleanMD-v${VERSION}-macOS.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must use MAJOR.MINOR.PATCH (example: 0.8.0)"
  exit 1
fi

if [ ! -f "$RELEASE_NOTES" ]; then
  echo "Error: missing release notes file: $RELEASE_NOTES"
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
  --notes-file "$RELEASE_NOTES"

echo "✓ GitHub release created: $TAG"
