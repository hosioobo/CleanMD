# Changelog

All notable project updates are tracked here.

## Unreleased

### Added

- Appearance theme presets for **Default**, **Paper**, and **Cool**, each with paired light/dark palettes.

### Improved

- The docked appearance inspector now behaves more like a native panel with keyboard-friendly controls, resize affordances, and accessibility labels.
- Appearance editing avoids unnecessary persistence work during live color changes and flushes pending settings safely on termination.
- Preview rendering now shares one renderer/sanitization source between the main-thread fallback and worker path to reduce drift.

### Fixed

- Markdown table normalization now leaves fenced code blocks, indented code blocks, and raw HTML blocks untouched.
- Preview URL handling now covers same-document fragment navigation and more local-path edge cases, including unicode and special-character file names.

## v0.9.0 — 2026-04-01

### Added

- GitHub Actions CI workflow for package tests, smoke tests, and app bundle builds on macOS.
- Release automation scripts for preparing metadata, packaging builds, and publishing reviewed releases.

### Improved

- Appearance editing now uses a docked inspector with faster Figma-like color controls and inline HEX editing.
- New windows now cascade instead of opening directly on top of each other.
- Scroll sync now starts enabled by default for side-by-side editing.

### Fixed

- Preview now opens local markdown links and renders local images more reliably, including spaced file names.
- Markdown preview preserves fenced code blocks while still repairing broken table rows in real documents.
- Restore Defaults now resets heading divider toggles as well as palette colors.
- CI cache setup now matches the local SwiftPM cache strategy.

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
