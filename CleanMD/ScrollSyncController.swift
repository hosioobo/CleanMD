import Foundation

final class ScrollSyncController: ObservableObject {
    @Published private(set) var isLinked: Bool = true

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
    private var lastKnownEditorFraction: CGFloat = 0
    private var lastKnownPreviewFraction: CGFloat = 0
    private var pendingFirstScrollCalibration = true

    func toggleLinking() {
        setLinked(!isLinked)
    }

    func setLinked(_ linked: Bool) {
        guard linked != isLinked else { return }
        isLinked = linked

        if linked {
            // Treat the first user-driven scroll after enabling sync as the
            // calibration event and clear any stale suppression state from a
            // previous linked session.
            pendingFirstScrollCalibration = true
            lastSyncSentToEditor = .distantPast
            lastSyncSentToPreview = .distantPast
        } else {
            pendingFirstScrollCalibration = false
        }
    }

    // Called by EditorView when the user scrolls the editor.
    func editorScrolled(to fraction: CGFloat) {
        let clampedFraction = clamped(fraction)
        lastKnownEditorFraction = clampedFraction
        guard isLinked else { return }
        guard Date().timeIntervalSince(lastSyncSentToEditor) > suppressInterval else { return }

        let shouldForceCalibration = pendingFirstScrollCalibration
        pendingFirstScrollCalibration = false
        syncPreview(to: clampedFraction, force: shouldForceCalibration)
    }

    // Called by PreviewView when the user scrolls the preview.
    func previewScrolled(to fraction: CGFloat) {
        let clampedFraction = clamped(fraction)
        lastKnownPreviewFraction = clampedFraction
        guard isLinked else { return }
        guard Date().timeIntervalSince(lastSyncSentToPreview) > suppressInterval else { return }

        let shouldForceCalibration = pendingFirstScrollCalibration
        pendingFirstScrollCalibration = false
        syncEditor(to: clampedFraction, force: shouldForceCalibration)
    }

    private func syncEditor(to fraction: CGFloat, force: Bool = false) {
        let clampedFraction = clamped(fraction)
        if !force, abs(lastKnownEditorFraction - clampedFraction) < .ulpOfOne { return }
        lastKnownEditorFraction = clampedFraction
        lastSyncSentToEditor = Date()
        onScrollEditorTo?(clampedFraction)
    }

    private func syncPreview(to fraction: CGFloat, force: Bool = false) {
        let clampedFraction = clamped(fraction)
        if !force, abs(lastKnownPreviewFraction - clampedFraction) < .ulpOfOne { return }
        lastKnownPreviewFraction = clampedFraction
        lastSyncSentToPreview = Date()
        onScrollPreviewTo?(clampedFraction)
    }

    private func clamped(_ fraction: CGFloat) -> CGFloat {
        max(0, min(1, fraction))
    }
}
