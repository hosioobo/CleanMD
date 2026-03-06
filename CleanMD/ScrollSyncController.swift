import Foundation

class ScrollSyncController: ObservableObject {
    @Published var isLinked: Bool = false

    var onScrollEditorTo: ((CGFloat) -> Void)?
    var onScrollPreviewTo: ((CGFloat) -> Void)?

    // Timestamps of the last *programmatic* scroll we issued to each pane.
    // When a pane reports a scroll event, we ignore it if it arrived within
    // `suppressInterval` seconds of us having programmatically scrolled that
    // pane — this cleanly breaks the async feedback loop without any boolean
    // flag racing.
    private var lastSyncSentToEditor: Date = .distantPast
    private var lastSyncSentToPreview: Date = .distantPast
    private let suppressInterval: TimeInterval = 0.25

    // Called by EditorView when the user scrolls the editor.
    func editorScrolled(to fraction: CGFloat) {
        guard isLinked else { return }
        guard Date().timeIntervalSince(lastSyncSentToEditor) > suppressInterval else { return }
        lastSyncSentToPreview = Date()
        onScrollPreviewTo?(fraction)
    }

    // Called by PreviewView when the user scrolls the preview.
    func previewScrolled(to fraction: CGFloat) {
        guard isLinked else { return }
        guard Date().timeIntervalSince(lastSyncSentToPreview) > suppressInterval else { return }
        lastSyncSentToEditor = Date()
        onScrollEditorTo?(fraction)
    }
}
