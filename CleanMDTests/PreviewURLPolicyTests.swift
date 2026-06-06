import XCTest
@testable import CleanMD

final class PreviewURLPolicyTests: XCTestCase {
    func testResolvesRelativeLinkAgainstDocumentFolder() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
        let expectedURL = URL(fileURLWithPath: "/tmp/docs/nested/other.md").standardizedFileURL

        let resolved = PreviewURLPolicy.resolvedURLString(
            from: "./nested/other.md",
            kind: .link,
            documentBaseURL: PreviewURLPolicy.documentBaseURL(for: fileURL)
        )

        XCTAssertEqual(URL(string: resolved ?? "")?.standardizedFileURL, expectedURL)
    }

    func testResolvesRelativeImageAgainstDocumentFolder() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
        let expectedURL = URL(fileURLWithPath: "/tmp/docs/images/diagram.png").standardizedFileURL

        let resolved = PreviewURLPolicy.resolvedURLString(
            from: "images/diagram.png",
            kind: .image,
            documentBaseURL: PreviewURLPolicy.documentBaseURL(for: fileURL)
        )

        XCTAssertEqual(URL(string: resolved ?? "")?.standardizedFileURL, expectedURL)
    }

    func testRejectsRemoteImagesByDefault() {
        XCTAssertNil(
            PreviewURLPolicy.resolvedURLString(
                from: "https://example.com/tracker.png",
                kind: .image,
                documentBaseURL: nil
            )
        )

        XCTAssertEqual(
            PreviewURLPolicy.resolvedURLString(
                from: "https://example.com/page",
                kind: .link,
                documentBaseURL: nil
            ),
            "https://example.com/page"
        )
    }

    func testLocalPreviewResourceMustStayInsideDocumentFolder() {
        let documentURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
        let documentBaseURL = PreviewURLPolicy.documentBaseURL(for: documentURL)
        let insideURL = URL(fileURLWithPath: "/tmp/docs/images/diagram.png")
        let outsideURL = URL(fileURLWithPath: "/tmp/secret.png")
        let absoluteOutsideURL = URL(fileURLWithPath: "/etc/passwd")

        XCTAssertEqual(
            PreviewURLPolicy.localPreviewResourceURL(
                fromLocalPreviewURL: PreviewURLPolicy.localPreviewURL(for: insideURL),
                documentBaseURL: documentBaseURL
            ),
            insideURL.standardizedFileURL
        )
        XCTAssertNil(
            PreviewURLPolicy.localPreviewResourceURL(
                fromLocalPreviewURL: PreviewURLPolicy.localPreviewURL(for: outsideURL),
                documentBaseURL: documentBaseURL
            )
        )
        XCTAssertNil(
            PreviewURLPolicy.localPreviewResourceURL(
                fromLocalPreviewURL: PreviewURLPolicy.localPreviewURL(for: absoluteOutsideURL),
                documentBaseURL: documentBaseURL
            )
        )
    }

    func testResolvesRelativeImageAgainstDocumentFolderWithUnicodeAndSpaces() {
        let fileURL = URL(fileURLWithPath: "/tmp/docs/guide.md")
        let expectedURL = URL(fileURLWithPath: "/tmp/docs/이미지 폴더/테스트 이미지 #1.png").standardizedFileURL

        let resolved = PreviewURLPolicy.resolvedURLString(
            from: "./이미지 폴더/테스트 이미지 #1.png",
            kind: .image,
            documentBaseURL: PreviewURLPolicy.documentBaseURL(for: fileURL)
        )

        XCTAssertEqual(URL(string: resolved ?? "")?.standardizedFileURL, expectedURL)
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

    func testSameDocumentFragmentNavigationIsAllowedInPlace() {
        let currentURL = URL(string: "https://example.com/docs/page.html")!
        let targetURL = URL(string: "https://example.com/docs/page.html#section-2")!

        XCTAssertEqual(
            PreviewURLPolicy.navigationAction(for: targetURL, currentURL: currentURL),
            .allowInPlace
        )
    }
}
