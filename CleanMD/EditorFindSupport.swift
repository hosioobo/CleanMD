import AppKit

enum EditorFindSupport {
    static func configure(textView: NSTextView) {
        textView.usesFindPanel = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
    }
}
