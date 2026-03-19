#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version> <build> [--dry-run]"
  echo "Example: $0 0.8.1 9"
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
  exit 1
fi

VERSION="$1"
BUILD="$2"
DRY_RUN=0

if [ "${3:-}" = "--dry-run" ]; then
  DRY_RUN=1
elif [ "$#" -eq 3 ]; then
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must use MAJOR.MINOR.PATCH (example: 0.8.1)"
  exit 1
fi

if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "Error: build must be an integer (example: 9)"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

TAG="v$VERSION"
RELEASE_NOTES="RELEASE_NOTES_v$VERSION.md"
ZIP_PATH="CleanMD-v${VERSION}-macOS.zip"
COMMIT_MESSAGE="Release v$VERSION"
REPO="${GITHUB_REPOSITORY:-hosioobo/CleanMD}"

ALLOWED_DIRTY_PATHS=(
  "Info.plist"
  "CHANGELOG.md"
  "$RELEASE_NOTES"
  "README.md"
  "VERSIONING.md"
  "scripts/prepare-release.sh"
  "scripts/package-release.sh"
  "scripts/create-github-release.sh"
  "scripts/release.sh"
  ".github/workflows/ci.yml"
)

contains_allowed_path() {
  local candidate="$1"
  local allowed
  for allowed in "${ALLOWED_DIRTY_PATHS[@]}"; do
    if [ "$candidate" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

collect_uncommitted_paths() {
  git status --porcelain=v1 --untracked-files=all | while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "${line:3}"
  done
}

ensure_only_release_metadata_is_dirty() {
  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [[ "$path" == *" -> "* ]]; then
      echo "Error: rename/copy detected in working tree: $path"
      echo "Commit or clean unrelated changes before running the release script."
      exit 1
    fi
    if ! contains_allowed_path "$path"; then
      echo "Error: unrelated working tree change detected: $path"
      echo "Commit or clean unrelated changes before running the release script."
      exit 1
    fi
  done < <(collect_uncommitted_paths)
}

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "main" ]; then
  echo "Error: release script must run from main (current: $current_branch)"
  exit 1
fi

if [ "$DRY_RUN" = "0" ] && ! gh api user >/dev/null 2>&1; then
  echo "Error: GitHub CLI cannot access the GitHub API. Check 'gh auth login' or your token configuration."
  exit 1
fi

current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist)"

if [ "$current_version" != "$VERSION" ]; then
  echo "Error: Info.plist version is $current_version but release expects $VERSION"
  echo "Run ./scripts/prepare-release.sh $VERSION $BUILD and review the metadata first."
  exit 1
fi

if [ "$current_build" != "$BUILD" ]; then
  echo "Error: Info.plist build is $current_build but release expects $BUILD"
  echo "Run ./scripts/prepare-release.sh $VERSION $BUILD and review the metadata first."
  exit 1
fi

if [ ! -f "$RELEASE_NOTES" ]; then
  echo "Error: missing release notes file: $RELEASE_NOTES"
  exit 1
fi

if grep -Eq "^## v${VERSION//./\\.}([[:space:]]|$)" CHANGELOG.md; then
  :
else
  echo "Error: CHANGELOG.md does not contain a finalized section for $TAG"
  exit 1
fi

if rg -n "TODO" "$RELEASE_NOTES" >/dev/null 2>&1; then
  echo "Error: release notes still contain TODO placeholders: $RELEASE_NOTES"
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Error: local tag already exists: $TAG"
  exit 1
fi

if [ "$DRY_RUN" = "0" ] && gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Error: GitHub release already exists: $TAG"
  exit 1
fi

ensure_only_release_metadata_is_dirty

echo "▶ Running smoke tests..."
./scripts/run-smoke-tests.sh

echo "▶ Packaging release asset..."
OVERWRITE=1 ./scripts/package-release.sh

if [ "$DRY_RUN" = "1" ]; then
  echo "✓ Dry run succeeded."
  echo "Skipped remote GitHub checks and would commit release metadata, tag $TAG, push main and $TAG, and create the GitHub release."
  exit 0
fi

to_add=()
for path in "${ALLOWED_DIRTY_PATHS[@]}"; do
  if [ -e "$path" ]; then
    to_add+=("$path")
  fi
done

if [ "${#to_add[@]}" -gt 0 ]; then
  git add "${to_add[@]}"
fi

if ! git diff --cached --quiet; then
  echo "▶ Creating release commit..."
  git commit -m "$COMMIT_MESSAGE"
else
  echo "▶ No release metadata changes to commit; tagging current HEAD."
fi

echo "▶ Creating tag $TAG..."
git tag "$TAG"

echo "▶ Pushing main..."
git push origin main

echo "▶ Pushing tag $TAG..."
git push origin "$TAG"

echo "▶ Creating GitHub release..."
./scripts/create-github-release.sh "$VERSION"

echo "✓ Release flow complete: $TAG"
