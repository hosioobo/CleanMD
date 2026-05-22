import AppKit

enum EditorFindSupport {
    static func configure(textView: NSTextView) {
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
    }
}
