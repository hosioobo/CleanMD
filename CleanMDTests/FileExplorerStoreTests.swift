import XCTest
@testable import CleanMD

final class FileExplorerStoreTests: XCTestCase {
    func testCurrentFolderIsDerivedFromCurrentFile() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("note.md")
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        let store = FileExplorerStore(
            currentFileURL: file,
            dependencies: .init(
                contentsOfDirectory: { _ in [] },
                recentDocumentURLs: { [] },
                openURL: { _ in },
                pathSubtitle: { _ in "" },
                isReadableSupportedFile: { _ in true },
                isDirectory: { _ in false }
            )
        )

        XCTAssertEqual(store.currentFolderURL, folder.standardizedFileURL)
    }

    func testFolderItemsFilterReadableFilesAndSortDirectoriesFirst() throws {
        let folder = try makeTempDirectory()
        let docs = folder.appendingPathComponent("docs", isDirectory: true)
        let drafts = folder.appendingPathComponent("drafts", isDirectory: true)
        let alpha = folder.appendingPathComponent("alpha.md")
        let beta = folder.appendingPathComponent("beta.yaml")
        let gamma = folder.appendingPathComponent("gamma.txt")
        let hidden = folder.appendingPathComponent(".hidden.md")
        let pathFormatter = PathDisplayFormatter()

        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
        try "a".write(to: alpha, atomically: true, encoding: .utf8)
        try "b".write(to: beta, atomically: true, encoding: .utf8)
        try "c".write(to: gamma, atomically: true, encoding: .utf8)
        try "d".write(to: hidden, atomically: true, encoding: .utf8)

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
                recentDocumentURLs: { [] },
                openURL: { _ in },
                pathSubtitle: { pathFormatter.parentPath(for: $0) },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { url in
                    var isDirectory: ObjCBool = false
                    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                }
            )
        )

        XCTAssertEqual(store.folderItems.map(\.title), ["docs", "drafts", "alpha.md", "beta.yaml"])
        XCTAssertEqual(store.folderItems.map(\.isDirectory), [true, true, false, false])
        XCTAssertEqual(store.folderItems.first?.isCurrentFile, false)
        XCTAssertEqual(store.folderItems[2].isCurrentFile, true)
    }

    func testHistoryPreservesOrderFiltersUnsupportedAndDeduplicates() throws {
        let folderA = try makeTempDirectory()
        let folderB = try makeTempDirectory()
        let noteA = folderA.appendingPathComponent("config.yaml")
        let noteB = folderB.appendingPathComponent("config.yaml")
        let markdown = folderA.appendingPathComponent("guide.md")
        let unsupported = folderB.appendingPathComponent("readme.txt")
        let pathFormatter = PathDisplayFormatter()

        try "a".write(to: noteA, atomically: true, encoding: .utf8)
        try "b".write(to: noteB, atomically: true, encoding: .utf8)
        try "c".write(to: markdown, atomically: true, encoding: .utf8)
        try "d".write(to: unsupported, atomically: true, encoding: .utf8)

        let store = FileExplorerStore(
            currentFileURL: noteA,
            dependencies: .init(
                contentsOfDirectory: { _ in [] },
                recentDocumentURLs: { [noteA, unsupported, noteB, markdown, noteA] },
                openURL: { _ in },
                pathSubtitle: { pathFormatter.parentPath(for: $0) },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { _ in false }
            )
        )

        XCTAssertEqual(store.historyItems.map(\.title), ["config.yaml", "config.yaml", "guide.md"])
        XCTAssertEqual(store.historyItems.map(\.subtitle), [
            noteA.deletingLastPathComponent().path,
            noteB.deletingLastPathComponent().path,
            markdown.deletingLastPathComponent().path
        ])
        XCTAssertEqual(store.historyItems.map(\.url), [noteA.standardizedFileURL, noteB.standardizedFileURL, markdown.standardizedFileURL])
    }

    func testCurrentFileIsHighlightedInHistoryAndFolder() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("note.md")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        let pathFormatter = PathDisplayFormatter()

        let store = FileExplorerStore(
            currentFileURL: file,
            dependencies: .init(
                contentsOfDirectory: { url in
                    try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                },
                recentDocumentURLs: { [file] },
                openURL: { _ in },
                pathSubtitle: { pathFormatter.parentPath(for: $0) },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { _ in false }
            )
        )

        XCTAssertEqual(store.folderItems.first?.isCurrentFile, true)
        XCTAssertEqual(store.historyItems.first?.isCurrentFile, true)
    }

    func testActivateInvokesOpenAction() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("note.md")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        let pathFormatter = PathDisplayFormatter()

        var openedURL: URL?
        let store = FileExplorerStore(
            currentFileURL: file,
            dependencies: .init(
                contentsOfDirectory: { _ in [] },
                recentDocumentURLs: { [] },
                openURL: { openedURL = $0 },
                pathSubtitle: { pathFormatter.parentPath(for: $0) },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { _ in false }
            )
        )

        let item = FileExplorerItem(
            id: file.standardizedFileURL,
            url: file.standardizedFileURL,
            title: "note.md",
            subtitle: nil,
            isDirectory: false,
            isCurrentFile: false
        )

        store.activate(item)
        XCTAssertEqual(openedURL, file.standardizedFileURL)
    }

    func testActivateDoesNothingForCurrentFile() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("note.md")
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        var openedURL: URL?
        let store = FileExplorerStore(
            currentFileURL: file,
            dependencies: .init(
                contentsOfDirectory: { _ in [] },
                recentDocumentURLs: { [] },
                openURL: { openedURL = $0 },
                pathSubtitle: { _ in "" },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { _ in false }
            )
        )

        store.activate(
            FileExplorerItem(
                id: file.standardizedFileURL,
                url: file.standardizedFileURL,
                title: "note.md",
                subtitle: nil,
                isDirectory: false,
                isCurrentFile: true
            )
        )

        XCTAssertNil(openedURL)
    }

    func testActivatingDirectoryNavigatesIntoFolderInsteadOfOpeningDocument() throws {
        let folder = try makeTempDirectory()
        let nested = folder.appendingPathComponent("nested", isDirectory: true)
        let nestedFile = nested.appendingPathComponent("inside.yaml")
        let currentFile = folder.appendingPathComponent("note.md")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "value: true".write(to: nestedFile, atomically: true, encoding: .utf8)
        try "# note".write(to: currentFile, atomically: true, encoding: .utf8)

        var openedURL: URL?
        let store = FileExplorerStore(
            currentFileURL: currentFile,
            dependencies: .init(
                contentsOfDirectory: { url in
                    try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                },
                recentDocumentURLs: { [] },
                openURL: { openedURL = $0 },
                pathSubtitle: { _ in "" },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { url in
                    var isDirectory: ObjCBool = false
                    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                }
            )
        )

        let item = FileExplorerItem(
            id: nested.standardizedFileURL,
            url: nested.standardizedFileURL,
            title: "nested",
            subtitle: nil,
            isDirectory: true,
            isCurrentFile: false
        )

        store.activate(item)

        XCTAssertNil(openedURL)
        XCTAssertEqual(store.currentFolderURL, nested.standardizedFileURL)
        XCTAssertEqual(store.folderItems.map(\.title), ["inside.yaml"])
    }

    func testNavigateUpMovesBackToParentFolder() throws {
        let root = try makeTempDirectory()
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        let rootFile = root.appendingPathComponent("root.md")
        let nestedFile = nested.appendingPathComponent("inside.yaml")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "# root".write(to: rootFile, atomically: true, encoding: .utf8)
        try "value: true".write(to: nestedFile, atomically: true, encoding: .utf8)

        let store = FileExplorerStore(
            currentFileURL: rootFile,
            dependencies: .init(
                contentsOfDirectory: { url in
                    try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                },
                recentDocumentURLs: { [] },
                openURL: { _ in },
                pathSubtitle: { _ in "" },
                isReadableSupportedFile: { SupportedDocumentKind.isSupportedReadableFile(url: $0) },
                isDirectory: { url in
                    var isDirectory: ObjCBool = false
                    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                }
            )
        )

        store.activate(
            FileExplorerItem(
                id: nested.standardizedFileURL,
                url: nested.standardizedFileURL,
                title: "nested",
                subtitle: nil,
                isDirectory: true,
                isCurrentFile: false
            )
        )
        XCTAssertEqual(store.currentFolderURL, nested.standardizedFileURL)

        store.navigateUp()

        XCTAssertEqual(store.currentFolderURL, root.standardizedFileURL)
        XCTAssertEqual(store.folderItems.map(\.title), ["nested", "root.md"])
    }

    func testPathFormatterAbbreviatesHomeDirectoryInHistorySubtitles() {
        let formatter = PathDisplayFormatter(homeDirectory: URL(fileURLWithPath: "/Users/alice"))
        let fileURL = URL(fileURLWithPath: "/Users/alice/Projects/CleanMD/spec.md")

        XCTAssertEqual(formatter.parentPath(for: fileURL), "~/Projects/CleanMD")
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url.standardizedFileURL
    }
}
