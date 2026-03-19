# Changelog

All notable project updates are tracked here.

## Unreleased

_No changes yet._

## v0.8.0 — 2026-03-19

### Added

- File explorer sidebar with **Files** and **History** tabs for faster navigation.
- Support for opening and previewing `.yml` and `.yaml` files with preserved formatting.
- Smoke test script and coverage for file explorer, recent history, supported file types, and table normalization.
- Refreshed light/dark screenshots and end-user install guidance for GitHub visitors.
- Release helper scripts for preparing version metadata, packaging versioned zip builds, and creating GitHub Releases.

### Improved

- Sidebar behavior and recent document history handling.
- Sidebar collapse state now stays separate per window.
- Preview rendering for Markdown tables and path display formatting.

### Fixed

- Split view crash in the editor layout.
- Scroll sync calibration between editor and preview.
- Preview links now block local file navigation and unsupported URL schemes.
- Release preparation now refuses duplicate versions and avoids no-op `Info.plist` rewrites.

## v0.7.0 — 2026-03-05

First public release of CleanMD.

- Native macOS Markdown editor with split editor and live preview
- Syntax highlighting for fenced code blocks
- KaTeX math rendering with bundled offline assets
- Optional synchronized scrolling between editor and preview
- Drag and drop support for Markdown files
- Customizable preview palette and heading dividers
- macOS 13 or later
