import Foundation

struct SmokeTestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws -> Bool {
    if condition() { return true }
    throw SmokeTestFailure(message: message)
}

func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.standardizedFileURL
}

func isDirectory(_ url: URL) -> Bool {
    var value: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &value) && value.boolValue
}

func testSupportedDocumentKind() throws {
    try expect(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/a.md")) == .markdown, "md should map to markdown")
    try expect(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/a.MARKDOWN")) == .markdown, "MARKDOWN should be case-insensitive")
    try expect(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/a.yml")) == .yaml, "yml should map to yaml")
    try expect(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/a.YAML")) == .yaml, "YAML should be case-insensitive")
    try expect(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/a.txt")) == .unsupported, "txt should be unsupported")
    try expect(SupportedDocumentKind.yaml.previewMode == .code(language: "yaml"), "yaml preview mode should be code")
}

func testPathDisplayFormatter() throws {
    let formatter = PathDisplayFormatter(homeDirectory: URL(fileURLWithPath: "/Users/test"))
    try expect(
        formatter.parentPath(for: URL(fileURLWithPath: "/Users/test/projects/demo/config.yaml")) == "~/projects/demo",
        "home path should abbreviate to ~"
    )
    try expect(
        formatter.parentPath(for: URL(fileURLWithPath: "/tmp/work/config.yaml")) == "/tmp/work",
        "non-home path should stay absolute"
    )
}

func testMarkdownTableNormalizer() throws {
    let markdown = """
    | 항목 | Raw | OMX | 판정 |
    | --- | --- | --- | --- |
    | 스크린샷 증거 | 페이지 상태 스크린샷 3장만 있음: lanes/raw/notes/screenshots/curriculum-3-guest-initial.png, lanes/raw/notes/
    screenshots/curriculum-3-guest-post-sell.png, 화면상 UI 증거는 안 보임 | 전/후 스크린샷 2장과 실제 결과 PNG 3장 있음 | omx 우세 |
    """

    let normalized = MarkdownTableNormalizer.normalize(markdown)
    let lines = normalized.components(separatedBy: "\n")

    try expect(lines.count == 3, "broken table row should be merged back into a single markdown row")
    try expect(lines[2].contains("lanes/raw/notes/ screenshots/curriculum-3-guest-post-sell.png"), "continued table cell content should stay in the same row")
}

func testMarkdownTableNormalizerLeavesFencedCodeBlocksUntouched() throws {
    let markdown = """
    ```md
    | A | B |
    | --- | --- |
    | first line
    second line | tail |
    ```
    """

    try expect(
        MarkdownTableNormalizer.normalize(markdown) == markdown,
        "table normalizer should not rewrite fenced code blocks"
    )
}

func testMarkdownTableNormalizerLeavesIndentedCodeBlocksUntouched() throws {
    let markdown = """
        | A | B |
        | --- | --- |
        | first line
        second line | tail |
    """

    try expect(
        MarkdownTableNormalizer.normalize(markdown) == markdown,
        "table normalizer should not rewrite indented code blocks"
    )
}

func testMarkdownTableNormalizerLeavesRawHTMLBlocksUntouched() throws {
    let markdown = """
    <pre>
    | A | B |
    | --- | --- |
    | first line
    second line | tail |
    </pre>
    """

    try expect(
        MarkdownTableNormalizer.normalize(markdown) == markdown,
        "table normalizer should not rewrite raw HTML blocks"
    )
}

func testMarkdownLinkDestinationNormalizerWrapsLocalDestinationsWithSpaces() throws {
    let source = "![img](./Screenshot 2026-03-20 at 11.51.17 AM.png)"
    let expected = "![img](<./Screenshot 2026-03-20 at 11.51.17 AM.png>)"

    try expect(
        MarkdownLinkDestinationNormalizer.normalize(source) == expected,
        "markdown preview should normalize local destinations with spaces so the parser recognizes them"
    )
}

func testRecentDocumentHistoryMerge() throws {
    let first = URL(fileURLWithPath: "/tmp/alpha.md")
    let second = URL(fileURLWithPath: "/tmp/beta.yaml")
    let third = URL(fileURLWithPath: "/tmp/gamma.md")

    let merged = RecentDocumentHistory.merge(
        primary: [first, second],
        secondary: [first, third, second]
    )

    try expect(
        merged == [first.standardizedFileURL, second.standardizedFileURL, third.standardizedFileURL],
        "recent history merge should preserve primary order and deduplicate"
    )
}

func testFileExplorerStore() throws {
    let folder = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }

    let docs = folder.appendingPathComponent("docs", isDirectory: true)
    let nested = folder.appendingPathComponent("nested", isDirectory: true)
    let alpha = folder.appendingPathComponent("alpha.md")
    let beta = folder.appendingPathComponent("beta.yaml")
    let gamma = folder.appendingPathComponent("gamma.txt")

    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try "# alpha".write(to: alpha, atomically: true, encoding: .utf8)
    try "value: true".write(to: beta, atomically: true, encoding: .utf8)
    try "unsupported".write(to: gamma, atomically: true, encoding: .utf8)

    let formatter = PathDisplayFormatter(homeDirectory: folder.deletingLastPathComponent())
    var openedURL: URL?

    let store = FileExplorerStore(
        currentFileURL: alpha,
        dependencies: .init(
            contentsOfDirectory: { url in
                try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            },
            recentDocumentURLs: { [alpha, gamma, beta, alpha] },
            openURL: { openedURL = $0 },
            pathSubtitle: { formatter.parentPath(for: $0) },
            isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
            isDirectory: { isDirectory($0) }
        )
    )

    try expect(store.currentFolderURL == folder, "current folder should derive from current file")
    try expect(store.folderItems.map(\.title) == ["docs", "nested", "alpha.md", "beta.yaml"], "folder view should show directories first and supported files only")
    try expect(store.folderItems[2].isCurrentFile, "current file should be highlighted in folder list")
    try expect(store.historyItems.map(\.title) == ["alpha.md", "beta.yaml"], "history should filter unsupported files and deduplicate")

    store.activate(store.folderItems[0])
    try expect(openedURL == nil, "activating a directory should not open a document")
    try expect(store.currentFolderURL == docs, "activating a directory should navigate into it")

    store.navigateUp()
    try expect(store.currentFolderURL == folder, "navigateUp should return to parent folder")

    store.activate(
        FileExplorerItem(
            id: alpha.standardizedFileURL,
            url: alpha.standardizedFileURL,
            title: alpha.lastPathComponent,
            subtitle: nil,
            isDirectory: false,
            isCurrentFile: false
        )
    )
    try expect(openedURL == alpha.standardizedFileURL, "activating a non-current file should open it")

    var recordedURL: URL?
    let recordingStore = FileExplorerStore(
        currentFileURL: nil,
        dependencies: .init(
            contentsOfDirectory: { _ in [] },
            recentDocumentURLs: { [] },
            openURL: { _ in },
            recordRecentDocumentURL: { recordedURL = $0 },
            pathSubtitle: { formatter.parentPath(for: $0) },
            isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
            isDirectory: { isDirectory($0) }
        )
    )

    recordingStore.updateCurrentFileURL(alpha)
    try expect(recordedURL == alpha.standardizedFileURL, "updating current file should record a recent document")
}

func testPreviewURLPolicyResolvesRelativeLocalURLs() throws {
    let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
    let documentBaseURL = PreviewURLPolicy.documentBaseURL(for: fileURL)
    let expectedMarkdownURL = URL(fileURLWithPath: "/tmp/docs/nested/other.md").standardizedFileURL
    let expectedImageURL = URL(fileURLWithPath: "/tmp/docs/images/diagram.png").standardizedFileURL
    let expectedUnicodeImageURL = URL(fileURLWithPath: "/tmp/docs/이미지 폴더/테스트 이미지 #1.png").standardizedFileURL

    try expect(
        URL(string: PreviewURLPolicy.resolvedURLString(from: "./nested/other.md", kind: .link, documentBaseURL: documentBaseURL) ?? "")?.standardizedFileURL == expectedMarkdownURL,
        "relative markdown links should resolve against the current document folder"
    )

    try expect(
        URL(string: PreviewURLPolicy.resolvedURLString(from: "images/diagram.png", kind: .image, documentBaseURL: documentBaseURL) ?? "")?.standardizedFileURL == expectedImageURL,
        "relative image sources should resolve against the current document folder"
    )

    try expect(
        URL(string: PreviewURLPolicy.resolvedURLString(
            from: "./이미지 폴더/테스트 이미지 #1.png",
            kind: .image,
            documentBaseURL: documentBaseURL
        ) ?? "")?.standardizedFileURL == expectedUnicodeImageURL,
        "relative image sources with unicode and spaces should resolve and percent-encode correctly"
    )
}

func testPreviewURLPolicyOpensSupportedLocalFilesAsDocuments() throws {
    let noteURL = URL(fileURLWithPath: "/tmp/docs/note.md")
    try expect(
        PreviewURLPolicy.navigationAction(for: noteURL, currentURL: nil) == .openDocument(noteURL.standardizedFileURL),
        "supported local file links should open as documents"
    )
}

func testPreviewURLPolicyRoundTripsLocalPreviewURLsWithSpaces() throws {
    let fileURL = URL(fileURLWithPath: "/tmp/docs/images/space name #1.png")
    let previewURL = PreviewURLPolicy.localPreviewURL(for: fileURL)

    try expect(
        PreviewURLPolicy.fileURL(fromLocalPreviewURL: previewURL) == fileURL.standardizedFileURL,
        "custom preview local URLs should decode back to the original file URL"
    )
}

func testPreviewURLPolicyDetectsPNGDataWithoutExtension() throws {
    let fileURL = URL(fileURLWithPath: "/tmp/docs/image-without-extension")
    let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])

    try expect(
        PreviewURLPolicy.mimeType(for: fileURL, data: data) == "image/png",
        "extensionless PNG data should still be served with image/png MIME type"
    )
}

func testPreviewURLPolicyAllowsSameDocumentFragmentNavigation() throws {
    let currentURL = URL(string: "https://example.com/docs/page.html")!
    let targetURL = URL(string: "https://example.com/docs/page.html#section-2")!

    try expect(
        PreviewURLPolicy.navigationAction(for: targetURL, currentURL: currentURL) == .allowInPlace,
        "same-document fragment navigation should stay in place"
    )
}

func testWindowFramePolicyCascadesAdditionalWindows() throws {
    let savedFrame = CGRect(x: 100, y: 200, width: 1100, height: 720)
    let frame = WindowFramePolicy.placementFrame(
        savedFrame: savedFrame,
        visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
        existingWindowCount: 1
    )

    try expect(
        frame.equalTo(CGRect(x: 128, y: 172, width: 1100, height: 720)),
        "additional windows should open slightly lower-right than the saved frame"
    )
}

func testColorHexNormalization() throws {
    try expect(ColorHex.normalize("ABCDEF") == "#abcdef", "bare six-digit hex should normalize with leading hash")
    try expect(ColorHex.normalize("  #1A2b3C  ") == "#1a2b3c", "hex normalization should trim whitespace and lowercase")
    try expect(ColorHex.normalize("#12345") == nil, "invalid hex should be rejected")
}

func testColorSettingsFlushPendingPersist() throws {
    let suiteName = "ColorSettingsSmoke.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw SmokeTestFailure(message: "Failed to create isolated defaults suite")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = ColorSettings(
        defaults: defaults,
        persistDelay: 60,
        notificationCenter: .init(),
        observeTermination: false
    )
    settings.lightPalette.editorBg = "#123456"

    try expect(defaults.string(forKey: "cp_v2_light") == nil, "debounced color settings should not persist immediately")

    settings.flushPendingPersist()

    try expect(defaults.string(forKey: "cp_v2_light") != nil, "flushPendingPersist should write pending palette changes")
}

func testColorSettingsPresetApplyAndDetection() throws {
    let suiteName = "ColorSettingsSmoke.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw SmokeTestFailure(message: "Failed to create isolated defaults suite")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = ColorSettings(
        defaults: defaults,
        persistDelay: 60,
        notificationCenter: .init(),
        observeTermination: false
    )

    settings.applyPreset(.paper)
    try expect(settings.lightPalette == .paperLight, "paper preset should update the light palette")
    try expect(settings.darkPalette == .paperDark, "paper preset should update the dark palette")
    try expect(settings.currentPreset == .paper, "currentPreset should detect a matching preset")

    settings.lightPalette.editorBg = "#010203"
    try expect(settings.currentPreset == .custom, "manual palette edits should switch currentPreset to custom")
}

func testAppearanceInspectorLayoutClamp() throws {
    try expect(
        AppearanceInspectorLayout.clampedWidth(200, totalWidth: 1600) == 340,
        "appearance inspector width should clamp to the minimum"
    )
    try expect(
        AppearanceInspectorLayout.clampedWidth(900, totalWidth: 1200) == 504,
        "appearance inspector width should clamp to the calculated maximum"
    )
}

func testScrollSyncControllerStartsLinked() throws {
    let controller = ScrollSyncController()
    try expect(controller.isLinked, "scroll sync should start linked by default")
}

func testScrollSyncControllerSyncsPreviewByDefault() throws {
    let controller = ScrollSyncController()
    var syncedFractions: [CGFloat] = []
    controller.onScrollPreviewTo = { syncedFractions.append($0) }

    controller.editorScrolled(to: 0.42)

    try expect(syncedFractions.count == 1, "default linked controller should forward editor scroll to preview")
    try expect(abs(syncedFractions[0] - 0.42) < 0.0001, "forwarded preview fraction should match editor fraction")
}

func testWebsiteLandingPageIncludesDownloadTrustAndFeedback() throws {
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let indexHTML = try String(
        contentsOf: repoRoot
            .appendingPathComponent("docs/index.html"),
        encoding: .utf8
    )
    let brandIcon = repoRoot.appendingPathComponent("docs/assets/brand/app-icon.png")

    try expect(indexHTML.contains("id=\"primary-download\""), "landing page should expose a primary download CTA")
    try expect(indexHTML.contains("href=\"./download/?ref=hero\""), "landing page should route the hero CTA through the tracked download path")
    try expect(indexHTML.contains("id=\"install-trust\""), "landing page should include an install trust section")
    try expect(indexHTML.contains("not notarized yet"), "landing page should explain the current notarization status")
    try expect(indexHTML.contains("href=\"https://github.com/hosioobo/CleanMD/issues/new"), "landing page should expose a support or feedback path")
    try expect(indexHTML.contains("data-site-event=\"page_view\""), "landing page should include a page-view analytics marker")
    try expect(indexHTML.contains("id=\"hero-proof\""), "landing page should put a real product screenshot in the hero")
    try expect(indexHTML.contains("id=\"comparison-section\""), "landing page should include a comparison section before the final CTA")
    try expect(indexHTML.contains("data-track-click=\"hero_download_click\""), "hero download CTA should use the named GTM event")
    try expect(indexHTML.contains("app-icon.png"), "landing page should use the bundled app icon")
    try expect(FileManager.default.fileExists(atPath: brandIcon.path), "landing page should ship the app icon under docs/assets")
    try expect(!indexHTML.contains("Final CTA"), "landing page should not expose internal CTA labels to users")
}

func testWebsiteDownloadRouteLooksUpLatestReleaseAndTracksReferrer() throws {
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let downloadHTML = try String(
        contentsOf: repoRoot.appendingPathComponent("docs/download/index.html"),
        encoding: .utf8
    )
    let siteJS = try String(
        contentsOf: repoRoot.appendingPathComponent("docs/site.js"),
        encoding: .utf8
    )

    try expect(downloadHTML.contains("data-page-kind=\"download\""), "download page should identify itself for redirect logic")
    try expect(downloadHTML.contains("data-release-api=\"https://api.github.com/repos/hosioobo/CleanMD/releases/latest\""), "download page should look up the latest GitHub release at runtime")
    try expect(downloadHTML.contains("data-release-fallback=\"https://github.com/hosioobo/CleanMD/releases/latest\""), "download page should have a release-page fallback URL")
    try expect(siteJS.contains("browser_download_url"), "download logic should redirect to the release asset, not just the release page")
    try expect(siteJS.contains("api.countapi.xyz"), "site scripts should send lightweight analytics events")
    try expect(siteJS.contains("searchParams.get(\"ref\")"), "download logic should attribute traffic sources from the ref query parameter")
    try expect(siteJS.contains("hero_download_click"), "site scripts should preserve the named hero download event")
    try expect(siteJS.contains("screenshot_open"), "site scripts should track screenshot-open events")
    try expect(siteJS.contains("comparison_section_view"), "site scripts should track comparison-section views")
    try expect(siteJS.contains("release_outbound_click"), "site scripts should track outbound release clicks")
}

func testLaunchProofAssetsAreWiredAcrossSurfaces() throws {
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let indexHTML = try String(
        contentsOf: repoRoot.appendingPathComponent("docs/index.html"),
        encoding: .utf8
    )
    let readme = try String(
        contentsOf: repoRoot.appendingPathComponent("README.md"),
        encoding: .utf8
    )
    let releaseNotes = try String(
        contentsOf: repoRoot.appendingPathComponent("RELEASE_NOTES_v0.10.0.md"),
        encoding: .utf8
    )

    let requiredAssets = [
        "screenshots/appearance-panel.png",
        "docs/assets/screenshots/appearance-panel.png",
        "docs/assets/launch/release-proof-grid.png",
        "docs/assets/launch/rmacapps-proof-grid.png",
        "docs/assets/launch/demo-poster.png",
        "docs/assets/demo/cleanmd-proof-demo.mp4",
        "docs/assets/demo/cleanmd-proof-demo.gif",
        "docs/launch-assets.md"
    ]

    try expect(indexHTML.contains("id=\"proof-showcase\""), "landing page should expose the proof showcase section")
    try expect(indexHTML.contains("appearance-panel.png"), "landing page should include the appearance inspector proof asset")
    try expect(indexHTML.contains("cleanmd-proof-demo.mp4"), "landing page should expose the short demo asset")
    try expect(readme.contains("screenshots/appearance-panel.png"), "README should include the appearance inspector screenshot")
    try expect(readme.contains("docs/assets/demo/cleanmd-proof-demo.gif"), "README should include the proof demo preview")
    try expect(releaseNotes.contains("release-proof-grid.png"), "release notes should reference the release-page proof grid")

    for asset in requiredAssets {
        let url = repoRoot.appendingPathComponent(asset)
        try expect(FileManager.default.fileExists(atPath: url.path), "\(asset) should exist in the repository")
    }
}

@main
enum SmokeTestsMain {
    static func main() throws {
        let tests: [(String, () throws -> Void)] = [
            ("SupportedDocumentKind", testSupportedDocumentKind),
            ("PathDisplayFormatter", testPathDisplayFormatter),
            ("MarkdownTableNormalizer", testMarkdownTableNormalizer),
            ("MarkdownTableNormalizerLeavesFencedCodeBlocksUntouched", testMarkdownTableNormalizerLeavesFencedCodeBlocksUntouched),
            ("MarkdownTableNormalizerLeavesIndentedCodeBlocksUntouched", testMarkdownTableNormalizerLeavesIndentedCodeBlocksUntouched),
            ("MarkdownTableNormalizerLeavesRawHTMLBlocksUntouched", testMarkdownTableNormalizerLeavesRawHTMLBlocksUntouched),
            ("MarkdownLinkDestinationNormalizerWrapsLocalDestinationsWithSpaces", testMarkdownLinkDestinationNormalizerWrapsLocalDestinationsWithSpaces),
            ("RecentDocumentHistory", testRecentDocumentHistoryMerge),
            ("FileExplorerStore", testFileExplorerStore),
            ("PreviewURLPolicyResolvesRelativeLocalURLs", testPreviewURLPolicyResolvesRelativeLocalURLs),
            ("PreviewURLPolicyOpensSupportedLocalFilesAsDocuments", testPreviewURLPolicyOpensSupportedLocalFilesAsDocuments),
            ("PreviewURLPolicyRoundTripsLocalPreviewURLsWithSpaces", testPreviewURLPolicyRoundTripsLocalPreviewURLsWithSpaces),
            ("PreviewURLPolicyDetectsPNGDataWithoutExtension", testPreviewURLPolicyDetectsPNGDataWithoutExtension),
            ("PreviewURLPolicyAllowsSameDocumentFragmentNavigation", testPreviewURLPolicyAllowsSameDocumentFragmentNavigation),
            ("WindowFramePolicyCascadesAdditionalWindows", testWindowFramePolicyCascadesAdditionalWindows),
            ("ColorHexNormalization", testColorHexNormalization),
            ("ColorSettingsFlushPendingPersist", testColorSettingsFlushPendingPersist),
            ("ColorSettingsPresetApplyAndDetection", testColorSettingsPresetApplyAndDetection),
            ("AppearanceInspectorLayoutClamp", testAppearanceInspectorLayoutClamp),
            ("ScrollSyncControllerStartsLinked", testScrollSyncControllerStartsLinked),
            ("ScrollSyncControllerSyncsPreviewByDefault", testScrollSyncControllerSyncsPreviewByDefault),
            ("WebsiteLandingPageIncludesDownloadTrustAndFeedback", testWebsiteLandingPageIncludesDownloadTrustAndFeedback),
            ("WebsiteDownloadRouteLooksUpLatestReleaseAndTracksReferrer", testWebsiteDownloadRouteLooksUpLatestReleaseAndTracksReferrer),
            ("LaunchProofAssetsAreWiredAcrossSurfaces", testLaunchProofAssetsAreWiredAcrossSurfaces)
        ]

        for (name, test) in tests {
            do {
                try test()
                print("PASS \(name)")
            } catch {
                fputs("FAIL \(name): \(error)\n", stderr)
                Foundation.exit(1)
            }
        }

        print("All smoke tests passed.")
    }
}
