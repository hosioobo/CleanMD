import XCTest
@testable import CleanMD

final class RecentDocumentHistoryTests: XCTestCase {
    func testMergeKeepsPrimaryOrderAndDeduplicates() {
        let first = URL(fileURLWithPath: "/tmp/alpha.md")
        let duplicate = URL(fileURLWithPath: "/tmp/alpha.md")
        let second = URL(fileURLWithPath: "/tmp/beta.yaml")
        let third = URL(fileURLWithPath: "/tmp/gamma.md")

        let merged = RecentDocumentHistory.merge(
            primary: [first, second],
            secondary: [duplicate, third, second]
        )

        XCTAssertEqual(merged, [first.standardizedFileURL, second.standardizedFileURL, third.standardizedFileURL])
    }
}
