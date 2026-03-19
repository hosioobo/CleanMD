import XCTest
@testable import CleanMD

final class SupportedDocumentKindTests: XCTestCase {
    func testMarkdownExtensionsAreSupportedCaseInsensitively() {
        XCTAssertEqual(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/note.md")), .markdown)
        XCTAssertEqual(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/note.MARKDOWN")), .markdown)
    }

    func testYamlExtensionsAreSupportedCaseInsensitively() {
        XCTAssertEqual(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/config.yml")), .yaml)
        XCTAssertEqual(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/config.YAML")), .yaml)
    }

    func testUnsupportedExtensionsAreRejected() {
        XCTAssertEqual(SupportedDocumentKind(url: URL(fileURLWithPath: "/tmp/readme.txt")), .unsupported)
        XCTAssertEqual(SupportedDocumentKind(fileExtension: nil), .unsupported)
    }

    func testPreviewModeMappingMatchesKind() {
        XCTAssertEqual(SupportedDocumentKind.markdown.previewMode, .markdown)
        XCTAssertEqual(SupportedDocumentKind.yaml.previewMode, .code(language: "yaml"))
        XCTAssertNil(SupportedDocumentKind.unsupported.previewMode)
    }

    func testReadableFileHelperMatchesSupportedKinds() {
        XCTAssertTrue(SupportedDocumentKind.isSupportedReadableFile(url: URL(fileURLWithPath: "/tmp/a.md")))
        XCTAssertTrue(SupportedDocumentKind.isSupportedReadableFile(url: URL(fileURLWithPath: "/tmp/a.yaml")))
        XCTAssertFalse(SupportedDocumentKind.isSupportedReadableFile(url: URL(fileURLWithPath: "/tmp/a.json")))
    }
}
