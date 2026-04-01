import Foundation
import XCTest
@testable import CleanMD

final class ScrollSyncControllerTests: XCTestCase {
    func testStartsLinkedByDefault() {
        let controller = ScrollSyncController()

        XCTAssertTrue(controller.isLinked)
    }

    func testEditorScrollSyncsPreviewByDefault() {
        let controller = ScrollSyncController()
        var syncedFractions: [CGFloat] = []

        controller.onScrollPreviewTo = { syncedFractions.append($0) }

        controller.editorScrolled(to: 0.42)

        XCTAssertEqual(syncedFractions.count, 1)
        XCTAssertEqual(syncedFractions.first ?? -1, 0.42, accuracy: 0.0001)
    }
}
