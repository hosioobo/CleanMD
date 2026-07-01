import Foundation

struct PreviewRenderInput: Equatable {
    let text: String
    let previewMode: PreviewMode
    let documentBaseURLString: String?

    var debounceLength: Int {
        text.utf16.count
    }
}

struct PreviewRenderScheduler {
    private var queuedInput: PreviewRenderInput?
    private var lastRenderedInput: PreviewRenderInput?
    private(set) var pendingInput: PreviewRenderInput?

    mutating func enqueue(_ input: PreviewRenderInput) -> Bool {
        guard input != queuedInput, input != lastRenderedInput else { return false }
        queuedInput = input
        pendingInput = input
        return true
    }

    mutating func markRendered(_ input: PreviewRenderInput) {
        lastRenderedInput = input
        if queuedInput == input {
            queuedInput = nil
        }
        if pendingInput == input {
            pendingInput = nil
        }
    }
}
