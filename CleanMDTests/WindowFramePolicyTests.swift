import XCTest
@testable import CleanMD

final class WindowFramePolicyTests: XCTestCase {
    func testPlacementUsesSavedFrameWithoutCascadeForFirstWindow() {
        let savedFrame = CGRect(x: 100, y: 200, width: 1100, height: 720)

        XCTAssertEqual(
            WindowFramePolicy.placementFrame(
                savedFrame: savedFrame,
                visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                existingWindowCount: 0
            ),
            savedFrame
        )
    }

    func testPlacementCascadesDownAndRightForAdditionalWindow() {
        let savedFrame = CGRect(x: 100, y: 200, width: 1100, height: 720)

        XCTAssertEqual(
            WindowFramePolicy.placementFrame(
                savedFrame: savedFrame,
                visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                existingWindowCount: 1
            ),
            CGRect(x: 128, y: 172, width: 1100, height: 720)
        )
    }

    func testPlacementClampsWithinVisibleFrame() {
        let savedFrame = CGRect(x: 500, y: 40, width: 1100, height: 720)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1400, height: 900)

        XCTAssertEqual(
            WindowFramePolicy.placementFrame(
                savedFrame: savedFrame,
                visibleFrame: visibleFrame,
                existingWindowCount: 2
            ),
            CGRect(x: 300, y: 0, width: 1100, height: 720)
        )
    }
}
