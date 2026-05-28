import XCTest
@testable import CleanMD

final class PreviewViewTemplateTests: XCTestCase {
    func testYamlCodePreviewUsesReadableDocumentFrame() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("yaml-preview-mode"))
        XCTAssertTrue(html.contains("renderYamlReadableHtml"))
        XCTAssertTrue(html.contains("yaml-readable-document"))
        XCTAssertTrue(html.contains("yaml-section-card"))
        XCTAssertTrue(html.contains("yaml-field-key"))
        XCTAssertTrue(html.contains("Readable View"))
    }

    func testPreviewKeepsFallbackRenderersWhenWebKitBlocksBundledAssets() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("if (typeof hljs === 'undefined')"))
        XCTAssertTrue(html.contains("if (typeof marked === 'undefined')"))
        XCTAssertTrue(html.contains("if (typeof renderMathInElement === 'undefined')"))
    }

    func testYamlReadableRendererEscapesBackslashCheckAsValidJavaScript() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("source[i - 1] !== '\\\\'"))
        XCTAssertFalse(html.contains("source[i - 1] !== '\\'"))
    }

    func testYamlReadableRendererKeepsRegexAndNewlineEscapesAsJavaScriptSource() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("replace(/\\\\r\\\\n?/g, '\\\\n').split('\\\\n')"))
        XCTAssertTrue(html.contains("blockLines.join('\\\\n').replace(/\\\\n+$/g, '')"))
        XCTAssertTrue(html.contains("</code></pre>\\\\n"))
        XCTAssertTrue(html.contains("</section>\\\\n"))
    }

    func testMainThreadPreviewFallsBackToVisibleRawTextOnRendererFailure() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("try {"))
        XCTAssertTrue(html.contains("catch (err)"))
        XCTAssertTrue(html.contains("Preview renderer fallback:"))
        XCTAssertTrue(html.contains("escapeHtml(String(text || ''))"))
    }

    func testYamlReadableRendererPreventsHorizontalOverflow() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("html {\n            overflow-x: hidden;"))
        XCTAssertTrue(html.contains("max-width: 100%;\n            min-width: 0;"))
        XCTAssertTrue(html.contains(".yaml-list-body"))
        XCTAssertTrue(html.contains("overflow-wrap: anywhere;"))
        XCTAssertTrue(html.contains("@media (max-width: 760px)"))
    }
}
