import XCTest
@testable import CleanMD

final class MarkdownLinkDestinationNormalizerTests: XCTestCase {
    func testWrapsRelativeImageDestinationContainingSpaces() {
        let source = "![img](./Screenshot 2026-03-20 at 11.51.17 AM.png)"

        XCTAssertEqual(
            MarkdownLinkDestinationNormalizer.normalize(source),
            "![img](<./Screenshot 2026-03-20 at 11.51.17 AM.png>)"
        )
    }

    func testWrapsRelativeImageDestinationContainingSpacesAndParentheses() {
        let source = "![img](./Screenshot (1).png)"

        XCTAssertEqual(
            MarkdownLinkDestinationNormalizer.normalize(source),
            "![img](<./Screenshot (1).png>)"
        )
    }

    func testEscapedParenthesesDoNotCloseDestinationEarly() {
        let source = "[draft](./file\\(draft\\) copy.md)"

        XCTAssertEqual(
            MarkdownLinkDestinationNormalizer.normalize(source),
            "[draft](<./file\\(draft\\) copy.md>)"
        )
    }

    func testLeavesFencedCodeBlockUntouched() {
        let source = """
        ```md
        ![img](./Screenshot 2026-03-20 at 11.51.17 AM.png)
        ```
        """

        XCTAssertEqual(MarkdownLinkDestinationNormalizer.normalize(source), source)
    }
}
