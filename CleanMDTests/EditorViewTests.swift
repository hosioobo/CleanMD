import AppKit
import XCTest
@testable import CleanMD

final class EditorViewTests: XCTestCase {
    func testClampsSelectionAfterProgrammaticTextReplacement() {
        let ranges = [
            NSValue(range: NSRange(location: 100, length: 12)),
            NSValue(range: NSRange(location: 2, length: 10))
        ]

        let clamped = EditorView.clampedSelectedRanges(ranges, textLength: 5)
            .map(\.rangeValue)

        XCTAssertEqual(clamped, [
            NSRange(location: 5, length: 0),
            NSRange(location: 2, length: 3)
        ])
    }

    func testClampsSelectionToStartForEmptyReplacementText() {
        let ranges = [NSValue(range: NSRange(location: 4, length: 2))]

        let clamped = EditorView.clampedSelectedRanges(ranges, textLength: 0)
            .map(\.rangeValue)

        XCTAssertEqual(clamped, [NSRange(location: 0, length: 0)])
    }
}
