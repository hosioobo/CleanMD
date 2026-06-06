import XCTest
@testable import CleanMD

final class DocumentReloadingTests: XCTestCase {
    func testReloadReadsLatestUTF8TextFromDisk() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("note.md")
        try "old".write(to: file, atomically: true, encoding: .utf8)
        try "# Updated\n\nFresh from disk.".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            try DocumentReloading.loadText(from: file),
            "# Updated\n\nFresh from disk."
        )
    }

    func testReloadWithoutFileURLReturnsNil() throws {
        XCTAssertNil(try DocumentReloading.loadText(from: nil))
    }

    func testReloadRejectsNonUTF8Data() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("broken.md")
        try Data([0xff, 0xfe, 0xfd]).write(to: file)

        XCTAssertThrowsError(try DocumentReloading.loadText(from: file))
    }

    func testSaveTextWritesUTF8TextToDisk() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("mine.md")

        try DocumentReloading.saveText("# Mine\n", to: file)

        XCTAssertEqual(
            try String(contentsOf: file, encoding: .utf8),
            "# Mine\n"
        )
    }

    func testReloadRequiresConfirmationWhenDiskTextDiffersFromEditorText() {
        XCTAssertTrue(
            DocumentReloading.requiresReplacementConfirmation(
                currentText: "local draft",
                reloadedText: "external update"
            )
        )
    }

    func testReloadDoesNotRequireConfirmationWhenTextIsUnchanged() {
        XCTAssertFalse(
            DocumentReloading.requiresReplacementConfirmation(
                currentText: "same text",
                reloadedText: "same text"
            )
        )
    }

    func testExternalStateIsIdleWhenDiskAndEditorMatch() {
        XCTAssertEqual(
            DocumentReloading.externalFileState(
                baselineText: "old",
                currentText: "new",
                diskText: "new"
            ),
            .idle
        )
    }

    func testExternalStateIsIdleWhenOnlyEditorChanged() {
        XCTAssertEqual(
            DocumentReloading.externalFileState(
                baselineText: "old",
                currentText: "local draft",
                diskText: "old"
            ),
            .idle
        )
    }

    func testExternalStateIsExternalUpdateWhenOnlyDiskChanged() {
        XCTAssertEqual(
            DocumentReloading.externalFileState(
                baselineText: "old",
                currentText: "old",
                diskText: "external"
            ),
            .externalUpdateAvailable
        )
    }

    func testExternalStateIsConflictWhenEditorAndDiskBothChanged() {
        XCTAssertEqual(
            DocumentReloading.externalFileState(
                baselineText: "old",
                currentText: "local draft",
                diskText: "external"
            ),
            .conflict
        )
    }

    func testExternalStateIsFileUnavailableWhenDiskTextIsMissing() {
        XCTAssertEqual(
            DocumentReloading.externalFileState(
                baselineText: "old",
                currentText: "local draft",
                diskText: nil
            ),
            .fileUnavailable
        )
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.standardizedFileURL
    }
}
