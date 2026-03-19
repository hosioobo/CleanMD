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
}

@main
enum SmokeTestsMain {
    static func main() throws {
        let tests: [(String, () throws -> Void)] = [
            ("SupportedDocumentKind", testSupportedDocumentKind),
            ("PathDisplayFormatter", testPathDisplayFormatter),
            ("MarkdownTableNormalizer", testMarkdownTableNormalizer),
            ("FileExplorerStore", testFileExplorerStore)
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
