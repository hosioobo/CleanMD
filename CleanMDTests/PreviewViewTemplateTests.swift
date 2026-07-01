import XCTest
@testable import CleanMD

final class PreviewViewTemplateTests: XCTestCase {
    func testPreviewRenderSchedulerDeduplicatesQueuedAndRenderedInputs() {
        var scheduler = PreviewRenderScheduler()
        let input = PreviewRenderInput(
            text: "# Title",
            previewMode: .markdown,
            documentBaseURLString: "file:///tmp/docs/"
        )

        XCTAssertTrue(scheduler.enqueue(input))
        XCTAssertFalse(scheduler.enqueue(input))
        XCTAssertEqual(scheduler.pendingInput, input)

        scheduler.markRendered(input)
        XCTAssertFalse(scheduler.enqueue(input))
        XCTAssertTrue(
            scheduler.enqueue(
                PreviewRenderInput(
                    text: "# Title\n\nchanged",
                    previewMode: .markdown,
                    documentBaseURLString: input.documentBaseURLString
                )
            )
        )
    }

    func testPreviewWorkerCoalescesIntermediateRenders() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("var workerRenderInFlight = false;"))
        XCTAssertTrue(html.contains("var pendingWorkerRender = null;"))
        XCTAssertTrue(html.contains("pendingWorkerRender = request;"))
        XCTAssertTrue(html.contains("flushPendingWorkerRender();"))
        XCTAssertFalse(html.contains("function renderMarkdown(text)"))
    }

    func testTemplateSeedsInitialPreviewColorsBeforeJavaScriptRuns() {
        let palette = ColorPalette(previewBg: "#191614", previewText: "#e9e0d3")
        let html = PreviewView.htmlTemplate(resourceURL: nil, initialPalette: palette)

        XCTAssertTrue(html.contains("<html style=\"background: #191614;\">"))
        XCTAssertTrue(html.contains("<body style=\"background: #191614; color: #e9e0d3;\">"))
        XCTAssertTrue(html.contains("document.documentElement.style.background = c.previewBg;"))
    }

    func testYamlCodePreviewUsesReadableDocumentFrame() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertTrue(html.contains("yaml-preview-mode"))
        XCTAssertTrue(html.contains("renderYamlReadableHtml"))
        XCTAssertTrue(html.contains("yaml-readable-document"))
        XCTAssertTrue(html.contains("yaml-section-card"))
        XCTAssertTrue(html.contains("yaml-field-key"))
        XCTAssertFalse(html.contains("Readable View"))
        XCTAssertFalse(html.contains("yaml-readable-badge"))
        XCTAssertFalse(html.contains("yaml-section-title::after"))
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
        XCTAssertFalse(html.contains("Preview renderer fallback:"))
        XCTAssertTrue(html.contains("escapeHtml(String(text || ''))"))
    }

    func testYamlReadableRendererDoesNotInventEmptyScalarText() {
        let html = PreviewView.htmlTemplate(resourceURL: nil)

        XCTAssertFalse(html.contains("yaml-scalar-muted"))
        XCTAssertFalse(html.contains(">empty</span>"))
        XCTAssertTrue(html.contains("if (!raw) {\n                return '';\n            }"))
        XCTAssertFalse(html.contains("raw === 'null' || raw === '~'"))
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
