# CleanMD

The lightest, fastest, cleanest native macOS Markdown editor.

CleanMD is a native macOS Markdown editor focused on speed, simplicity, and a clean split-view writing experience. It pairs a plain text editor with a live preview, supports code highlighting and math rendering, and works fully offline with bundled rendering assets.

## Features

- Native macOS app built with SwiftUI and AppKit
- Split editor and live preview
- Syntax highlighting for fenced code blocks
- KaTeX-powered math rendering
- Optional synchronized scrolling between editor and preview
- Offline-first bundled renderer assets
- Opens and saves `.md` and `.markdown` files
- Drag and drop Markdown files into the app
- Customizable preview color palette and heading dividers

## Screenshots

Use the two bundled screenshot documents so light mode and dark mode each show a different part of the app without scrolling:

- `SCREENSHOT_LIGHT.md`
- `SCREENSHOT_DARK.md`

Recommended captures:

- light mode full split view using `SCREENSHOT_LIGHT.md`
- dark mode full split view using `SCREENSHOT_DARK.md`
- palette customization panel

### Light Mode

![CleanMD light mode](screenshots/light-mode.png)

### Dark Mode

![CleanMD dark mode](screenshots/dark-mode.png)

## Requirements

- macOS 13 or later
- Xcode command line tools for local builds

## Download

Regular users can download packaged builds from the GitHub Releases page:

- `Releases` on `hosioobo/CleanMD`

### Run the App

1. Download the latest release from GitHub Releases.
2. Unzip `CleanMD-v0.7.0-macOS.zip`.
3. Move `CleanMD.app` to your Applications folder if desired.
4. Open `CleanMD.app`.

Early releases are packaged and ad-hoc signed for convenience, but they are not notarized yet. macOS Gatekeeper may show a warning the first time you open the app.

## Build From Source

```bash
swift build -c release
./build.sh
```

`./build.sh` builds the app, packages `CleanMD.app` in the repository root, copies the bundled web assets, applies ad-hoc signing, and launches the app.

## Project Structure

- `CleanMD/`: Swift source files and bundled preview assets
- `build.sh`: local packaging script for `CleanMD.app`
- `Info.plist`: app metadata and document type registration
- `makeicon.swift`: script used to generate app icon assets

## Contributing

```bash
git clone git@github.com:hosioobo/CleanMD.git
cd CleanMD
swift build
./build.sh
```

Please keep the app lightweight and offline-friendly. If you change bundled third-party assets, update the notices in `THIRD_PARTY_NOTICES.md`.

## Release Notes

The first public release is planned as `v0.7.0` and will include:

- source code for contributors
- a zipped macOS app for download
- release notes describing macOS support and Gatekeeper behavior

## License

CleanMD is available under the MIT license. See `LICENSE`.
