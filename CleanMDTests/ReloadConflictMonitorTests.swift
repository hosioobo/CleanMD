import XCTest
@testable import CleanMD

final class ReloadConflictMonitorTests: XCTestCase {
    func testStartDetectsCleanExternalUpdate() throws {
        let file = try makeFile(contents: "external")
        let monitor = ReloadConflictMonitor()
        defer { monitor.stop() }

        monitor.start(fileURL: file, currentText: "baseline")

        XCTAssertEqual(monitor.state, .externalUpdateAvailable)
        XCTAssertEqual(monitor.pendingDiskText, "external")
    }

    func testMarkResolvedClearsExternalUpdateAfterReload() throws {
        let file = try makeFile(contents: "external")
        let monitor = ReloadConflictMonitor()
        defer { monitor.stop() }

        monitor.start(fileURL: file, currentText: "baseline")
        monitor.markResolved(currentText: "external")

        XCTAssertEqual(monitor.state, .idle)
        XCTAssertNil(monitor.pendingDiskText)
    }

    func testKeepCurrentMovesExternalUpdateToConflictCue() throws {
        let file = try makeFile(contents: "external")
        let monitor = ReloadConflictMonitor()
        defer { monitor.stop() }

        monitor.start(fileURL: file, currentText: "baseline")
        monitor.keepCurrentVersion()

        XCTAssertEqual(monitor.state, .conflict)
        XCTAssertEqual(monitor.pendingDiskText, "external")
    }

    func testKeepCurrentRemainsConflictAcrossLaterDiskWrites() throws {
        let file = try makeFile(contents: "external one")
        let monitor = ReloadConflictMonitor()
        defer { monitor.stop() }

        monitor.start(fileURL: file, currentText: "baseline")
        monitor.keepCurrentVersion()
        try "external two".write(to: file, atomically: true, encoding: .utf8)
        monitor.updateCurrentText("baseline")

        XCTAssertEqual(monitor.state, .conflict)
        XCTAssertEqual(monitor.pendingDiskText, "external two")
    }

    func testMarkSavedClearsConflictAfterSaveMine() throws {
        let file = try makeFile(contents: "external")
        let monitor = ReloadConflictMonitor()
        defer { monitor.stop() }

        monitor.start(fileURL: file, currentText: "baseline")
        monitor.keepCurrentVersion()
        monitor.markSaved(currentText: "mine")

        XCTAssertEqual(monitor.state, .idle)
        XCTAssertNil(monitor.pendingDiskText)
    }

    func testStartDetectsUnavailableFile() throws {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("missing.md")
        let monitor = ReloadConflictMonitor()
        defer { monitor.stop() }

        monitor.start(fileURL: file, currentText: "draft")

        XCTAssertEqual(monitor.state, .fileUnavailable)
        XCTAssertNil(monitor.pendingDiskText)
    }

    private func makeFile(contents: String) throws -> URL {
        let folder = try makeTempDirectory()
        let file = folder.appendingPathComponent("note.md")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.standardizedFileURL
    }
}
