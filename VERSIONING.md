# Versioning and Release Process

CleanMD uses a simple release structure based on semantic versioning, a shared changelog, and GitHub tags/releases.

## Canonical Source of Truth

These files are the project-owned release records:

- `Info.plist` — app version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`)
- `CHANGELOG.md` — ongoing user-facing change history
- `RELEASE_NOTES_vX.Y.Z.md` — per-release notes for GitHub Releases
- `VERSIONING.md` — policy and release checklist

## Version Format

CleanMD follows `MAJOR.MINOR.PATCH`.

- `MAJOR`: breaking changes or a major product reset
- `MINOR`: new user-facing features or meaningful UX improvements
- `PATCH`: bug fixes, regressions, and small polish releases

## Pre-1.0 Rule

Until `1.0.0`, keep using `0.x.y`.

- New feature release: `0.7.0` → `0.8.0`
- Bug-fix release: `0.8.0` → `0.8.1`

For this project, significant feature work like the file explorer, YAML support, or major navigation changes should usually bump the **minor** version.

## App Version vs Build Number

- `CFBundleShortVersionString`: user-visible version such as `0.8.0`
- `CFBundleVersion`: internal build number such as `8`

Recommended rule:

- bump the visible version when preparing a release
- increment the build number every release build

## Changelog Rules

Keep `CHANGELOG.md` in this shape:

- `## Unreleased`
- latest released version below it, with the release date

Recommended subsections:

- `### Added`
- `### Improved`
- `### Fixed`
- `### Removed` (only when needed)

During normal development, add notes under `Unreleased`.
When preparing a release, move those notes into a versioned section such as `## v0.8.0 — 2026-03-19`.

## Git and Release Naming

- Git tag: `v0.8.0`
- Release notes file: `RELEASE_NOTES_v0.8.0.md`
- Packaged artifact: `CleanMD-v0.8.0-macOS.zip`

## Release Checklist

1. Choose the next release version and build number.
2. Run `./scripts/prepare-release.sh <version> <build>`.
3. Move `CHANGELOG.md` entries from `Unreleased` into a dated release section.
4. Review or complete `RELEASE_NOTES_v<version>.md`.
5. Run the full release flow:
   - `./scripts/release.sh <version> <build>`
6. Verify the GitHub Release page and uploaded zip asset.

## Helper Scripts

- `./scripts/prepare-release.sh 0.8.0 8`
  - updates `Info.plist`
  - refuses to reuse a version that already has a Git tag or changelog section
  - creates a release notes template if missing
- `./scripts/package-release.sh`
  - builds `CleanMD.app`
  - creates `CleanMD-v<current-version>-macOS.zip`
- `./scripts/release.sh 0.8.0 8`
  - validates release metadata
  - runs smoke tests and packages the zip
  - commits release metadata, tags the release, pushes Git refs, and creates the GitHub Release
  - supports `--dry-run` for a local preflight without push/release creation
- `./scripts/create-github-release.sh 0.8.0`
  - creates the GitHub Release from the local tag, release notes, and packaged zip

## CI

- GitHub Actions CI lives in `.github/workflows/ci.yml`
- CI runs `swift test`, smoke tests, and `./build.sh` on macOS for pushes to `main` and pull requests

## Where To Put These Rules

Use this policy:

- Put the **canonical versioning policy** in tracked project files like `VERSIONING.md`.
- Keep release history in `CHANGELOG.md` and `RELEASE_NOTES_vX.Y.Z.md`.
- Keep helper automation in tracked project scripts such as `scripts/prepare-release.sh` and `scripts/package-release.sh`.
- Keep agent/tool state out of Git: `.omx/`, `.claude/`, `.codex/`, and similar local folders should stay ignored.
- Do **not** use tool-specific folders as the source of truth for release policy.
