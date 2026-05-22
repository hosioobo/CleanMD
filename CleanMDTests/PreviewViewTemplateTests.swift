import XCTest
@testable import CleanMD

final class PreviewViewTemplateTests: XCTestCase {
    func testYamlCodePreviewUsesDedicatedDocumentFrame() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("yaml-preview-mode"))
        XCTAssertTrue(html.contains("renderYamlPreviewHtml"))
        XCTAssertTrue(html.contains("yaml-document-header"))
        XCTAssertTrue(html.contains("YAML</div>"))
        XCTAssertTrue(html.contains("pre.yaml-preview .hljs-attr"))
    }
}
