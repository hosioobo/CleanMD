# Changelog

All notable project updates are tracked here.

## Unreleased

## v0.13.0 — 2026-07-01

### Added

- Preview settings now persist across opened files, including editor/preview panel mode, scroll sync, dark mode, and Appearance inspector state.

### Improved

- Markdown previews now avoid extra normalization work before debounce and coalesce in-flight worker renders while typing.
- Preview panes now apply the selected background color before content rendering starts, reducing visible blank-state flashes.
- Local Markdown previews can now load eligible nearby local image assets through the existing local preview resource policy.

### Fixed

- Preview startup now seeds the initial HTML background and text colors from the active palette instead of briefly falling back to white.

## v0.12.1 — 2026-06-06

### Improved

- Preview packaging now validates required JavaScript, CSS, and KaTeX font resources before producing app bundles.
- Local preview resource loading now rejects oversized or non-regular files before reading them into memory.

### Fixed

- Editor selection ranges are now clamped after programmatic text replacement to avoid stale selection crashes.
- Preview image loading now stays local by default and prevents local-preview URLs from escaping the document folder.
- Markdown image destinations with spaces, escaped parentheses, or nested parentheses now normalize without truncating paths.

## v0.12.0 — 2026-06-05

### Added

- External file change recovery UX with clean update prompts, conflict banners, and file-unavailable recovery actions.
- Titlebar controls for editor-only, preview-only, and side-by-side editor/preview layouts.
- Manual reload cue that stays hidden until an external disk update needs attention.

### Improved

- YAML previews now read like settings documents instead of raw syntax-colored source while preserving source-faithful empty values.
- Save Mine now uses the owning macOS document save path so AppKit document state stays aligned after conflict recovery.
- Keep Current remains a sticky conflict state across later disk writes until the user reloads or saves.
- The public website and release records were refreshed for the current product presentation.

### Fixed

- YAML readable preview text now preserves scalar fidelity and avoids overflow in long content.

## v0.11.0 — 2026-04-15

### Added

- New public screenshots for the default light and dark views plus the Paper and Cool light themes.

### Improved

- The website now uses a leaner structure focused on product definition, proof, and install guidance.
- The README now centers on current app captures instead of the older launch-proof media set.
- GitHub release creation now pulls release text from the matching `CHANGELOG.md` section.

### Removed

- Version-specific `RELEASE_NOTES_v*.md` files from the repository.

## v0.10.0 — 2026-04-01

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
