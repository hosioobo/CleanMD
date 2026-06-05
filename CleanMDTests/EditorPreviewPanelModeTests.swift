import XCTest
@testable import CleanMD

final class EditorPreviewPanelModeTests: XCTestCase {
    func testVisibilityFlagsMatchPanelMode() {
        XCTAssertTrue(EditorPreviewPanelMode.both.showsEditor)
        XCTAssertTrue(EditorPreviewPanelMode.both.showsPreview)

        XCTAssertTrue(EditorPreviewPanelMode.editorOnly.showsEditor)
        XCTAssertFalse(EditorPreviewPanelMode.editorOnly.showsPreview)

        XCTAssertFalse(EditorPreviewPanelMode.previewOnly.showsEditor)
        XCTAssertTrue(EditorPreviewPanelMode.previewOnly.showsPreview)
    }

    func testStoredValueNormalizationFallsBackToBoth() {
        XCTAssertEqual(EditorPreviewPanelMode.normalized("editorOnly"), .editorOnly)
        XCTAssertEqual(EditorPreviewPanelMode.normalized("previewOnly"), .previewOnly)
        XCTAssertEqual(EditorPreviewPanelMode.normalized("unknown"), .both)
        XCTAssertEqual(EditorPreviewPanelMode.normalized(""), .both)
    }
}
