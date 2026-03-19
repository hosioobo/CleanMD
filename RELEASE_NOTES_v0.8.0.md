# CleanMD v0.8.0

## Highlights

- New file explorer sidebar with **Files** and **History** tabs
- YAML (`.yml`, `.yaml`) open and preview support
- Better Markdown table rendering and recent-file navigation
- Safer preview link handling for local and unsupported URLs
- Structured GitHub-only release workflow with helper scripts

## Included

- Native macOS split editor and live preview workflow
- Folder browsing and recent document history in the sidebar
- YAML code preview with preserved indentation
- Improved sidebar collapse behavior with per-window state
- Smoke tests for supported file types, path formatting, history merge, tables, and file explorer behavior
- Release helper scripts for preparing version metadata and packaging versioned zip builds

## Platform

- macOS 13 or later

## Notes

- Packaged builds are currently created locally and ad-hoc signed.
- The app is not notarized yet, so macOS Gatekeeper may show a warning on first launch.
