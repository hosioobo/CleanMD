import XCTest
@testable import CleanMD

final class PreviewURLPolicyTests: XCTestCase {
    func testResolvesRelativeLinkAgainstDocumentFolder() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")

        let resolved = PreviewURLPolicy.resolvedURLString(
            from: "./nested/other.md",
            kind: .link,
            documentBaseURL: PreviewURLPolicy.documentBaseURL(for: fileURL)
        )

        XCTAssertEqual(resolved, "file:///tmp/docs/nested/other.md")
    }

    func testResolvesRelativeImageAgainstDocumentFolder() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")

        let resolved = PreviewURLPolicy.resolvedURLString(
            from: "images/diagram.png",
            kind: .image,
            documentBaseURL: PreviewURLPolicy.documentBaseURL(for: fileURL)
        )

        XCTAssertEqual(resolved, "file:///tmp/docs/images/diagram.png")
    }

    func testRejectsUnsupportedSchemes() {
        XCTAssertNil(PreviewURLPolicy.resolvedURLString(from: "javascript:alert(1)", kind: .link, documentBaseURL: nil))
        XCTAssertNil(PreviewURLPolicy.resolvedURLString(from: "data:text/html,boom", kind: .image, documentBaseURL: nil))
    }

    func testLocalMarkdownNavigationOpensDocument() {
        let url = URL(fileURLWithPath: "/tmp/docs/note.md")

        XCTAssertEqual(
            PreviewURLPolicy.navigationAction(for: url, currentURL: nil),
            .openDocument(url.standardizedFileURL)
        )
    }

    func testLocalPreviewURLRoundTripsFilePathsWithSpaces() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/images/space name #1.png")
        let previewURL = PreviewURLPolicy.localPreviewURL(for: fileURL)

        XCTAssertEqual(
            PreviewURLPolicy.fileURL(fromLocalPreviewURL: previewURL),
            fileURL.standardizedFileURL
        )
    }

    func testLocalPreviewNavigationOpensSupportedDocument() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
        let previewURL = PreviewURLPolicy.localPreviewURL(for: fileURL)

        XCTAssertEqual(
            PreviewURLPolicy.navigationAction(for: previewURL, currentURL: nil),
            .openDocument(fileURL.standardizedFileURL)
        )
    }

    func testMimeTypeFallsBackToPNGSignatureWhenFileHasNoExtension() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/image-without-extension")
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])

        XCTAssertEqual(PreviewURLPolicy.mimeType(for: fileURL, data: data), "image/png")
    }
}
