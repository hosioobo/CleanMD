import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var scrollSync: ScrollSyncController
    var isDarkMode: Bool
    var palette: ColorPalette

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let paragraph = editorParagraphStyle()

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = editorFont
        textView.defaultParagraphStyle = paragraph
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.backgroundColor = NSColor(hex: palette.editorBg)
        textView.textColor = NSColor(hex: palette.editorText)
        textView.insertionPointColor = NSColor(hex: palette.editorText)
        textView.typingAttributes = [
            .font: editorFont,
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor(hex: palette.editorText)
        ]
        textView.delegate = context.coordinator

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Listen for scroll changes
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        scrollSync.onScrollEditorTo = { [weak scrollView] fraction in
            guard let scrollView else { return }
            let contentHeight = scrollView.documentView?.bounds.height ?? 0
            let visibleHeight = scrollView.contentView.bounds.height
            let maxScroll = max(0, contentHeight - visibleHeight)
            let targetY = fraction * maxScroll
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        return scrollView
    }

    private func editorParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.25
        style.paragraphSpacing = 3
        return style
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Appearance (dark/light system look)
        let target = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        if scrollView.appearance != target {
            scrollView.appearance = target
        }

        // Apply palette colors whenever the palette actually changes
        // (covers both user edits AND dark/light mode switches)
        if context.coordinator.lastPalette != palette {
            context.coordinator.lastPalette = palette
            let bg = NSColor(hex: palette.editorBg)
            let fg = NSColor(hex: palette.editorText)
            textView.backgroundColor = bg
            scrollView.backgroundColor = bg
            textView.textColor = fg
            textView.insertionPointColor = fg
            textView.typingAttributes[.foregroundColor] = fg
            // Re-colour all existing text so the change is immediately visible
            if let storage = textView.textStorage, storage.length > 0 {
                storage.addAttribute(.foregroundColor, value: fg,
                                     range: NSRange(location: 0, length: storage.length))
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var lastPalette: ColorPalette? = nil

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        @objc func scrollDidChange(_ notification: Notification) {
            guard let scrollView else { return }
            let contentHeight = scrollView.documentView?.bounds.height ?? 0
            let visibleHeight = scrollView.contentView.bounds.height
            let maxScroll = max(1, contentHeight - visibleHeight)
            let currentY = scrollView.contentView.bounds.origin.y
            let fraction = max(0, min(1, currentY / maxScroll))
            parent.scrollSync.editorScrolled(to: fraction)
        }
    }
}
