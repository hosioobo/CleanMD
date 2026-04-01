import XCTest
@testable import CleanMD

final class MarkdownTableNormalizerTests: XCTestCase {
    func testBrokenTableRowIsMergedBackIntoSingleMarkdownRow() {
        let markdown = """
        | 항목 | Raw | OMX | 판정 |
        | --- | --- | --- | --- |
        | 스크린샷 증거 | 페이지 상태 스크린샷 3장만 있음: lanes/raw/notes/screenshots/curriculum-3-guest-initial.png, lanes/raw/notes/
        screenshots/curriculum-3-guest-post-sell.png, 화면상 UI 증거는 안 보임 | 전/후 스크린샷 2장과 실제 결과 PNG 3장 있음 | omx 우세 |
        """

        let normalized = MarkdownTableNormalizer.normalize(markdown)
        let lines = normalized.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(
            lines[2],
            "| 스크린샷 증거 | 페이지 상태 스크린샷 3장만 있음: lanes/raw/notes/screenshots/curriculum-3-guest-initial.png, lanes/raw/notes/ screenshots/curriculum-3-guest-post-sell.png, 화면상 UI 증거는 안 보임 | 전/후 스크린샷 2장과 실제 결과 PNG 3장 있음 | omx 우세 |"
        )
    }

    func testWellFormedTableRemainsUnchanged() {
        let markdown = """
        | 항목 | 값 |
        | --- | --- |
        | 상태 | 정상 |
        """

        XCTAssertEqual(MarkdownTableNormalizer.normalize(markdown), markdown)
    }

    func testFencedCodeBlockContainingTableLikeTextRemainsUnchanged() {
        let markdown = """
        ```md
        | A | B |
        | --- | --- |
        | first line
        second line | tail |
        ```
        """

        XCTAssertEqual(MarkdownTableNormalizer.normalize(markdown), markdown)
    }

    func testIndentedCodeBlockContainingTableLikeTextRemainsUnchanged() {
        let markdown = """
            | A | B |
            | --- | --- |
            | first line
            second line | tail |
        """

        XCTAssertEqual(MarkdownTableNormalizer.normalize(markdown), markdown)
    }

    func testRawHTMLBlockContainingTableLikeTextRemainsUnchanged() {
        let markdown = """
        <pre>
        | A | B |
        | --- | --- |
        | first line
        second line | tail |
        </pre>
        """

        XCTAssertEqual(MarkdownTableNormalizer.normalize(markdown), markdown)
    }
}
