import XCTest
@testable import CleanMD

final class AppearanceInspectorLayoutTests: XCTestCase {
    func testClampsWidthToMinimum() {
        XCTAssertEqual(AppearanceInspectorLayout.clampedWidth(200, totalWidth: 1600), 340)
    }

    func testClampsWidthToMaximum() {
        XCTAssertEqual(AppearanceInspectorLayout.clampedWidth(900, totalWidth: 1200), 504)
    }
}
