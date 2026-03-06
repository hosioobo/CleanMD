import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @StateObject private var scrollSync = ScrollSyncController()
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var isColorPanelVisible: Bool = false
    @State private var isDragTargeted = false
    // Observing colorSettings causes ContentView to re-render when palette changes,
    // which propagates the new palette + version params to the NSViewRepresentables.
    @ObservedObject private var colorSettings = ColorSettings.shared

    var body: some View {
        NoDividerHSplitView(
            left: EditorView(
                text: $document.text,
                scrollSync: scrollSync,
                isDarkMode: isDarkMode,
                palette: colorSettings.palette(isDark: isDarkMode)
            ),
            right: PreviewView(
                text: document.text,
                scrollSync: scrollSync,
                isDarkMode: isDarkMode,
                palette: colorSettings.palette(isDark: isDarkMode),
                showH1Divider: colorSettings.showH1Divider,
                showH2Divider: colorSettings.showH2Divider
            )
        )
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .background(WindowConfigurator(
            scrollSync: scrollSync,
            isColorPanelVisible: $isColorPanelVisible
        ))
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
            let validExtensions = ["md", "markdown"]
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var fileURL: URL?
                    if let data = item as? Data {
                        fileURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        fileURL = url
                    }
                    guard let url = fileURL,
                          validExtensions.contains(url.pathExtension.lowercased()) else { return }
                    DispatchQueue.main.async {
                        NSDocumentController.shared.openDocument(
                            withContentsOf: url, display: true) { _, _, _ in }
                    }
                }
            }
            return true
        }
        // Drag indicator
        .overlay {
            if isDragTargeted {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        // Color-settings panel
        .overlay(alignment: .topTrailing) {
            GeometryReader { geo in
                if isColorPanelVisible {
                    ZStack(alignment: .topTrailing) {
                        Color.black.opacity(0.50)
                            .ignoresSafeArea()
                            .onTapGesture { isColorPanelVisible = false }

                        ColorSettingsPanel(
                            isVisible: $isColorPanelVisible,
                            availableHeight: geo.size.height
                        )
                        .padding(.top, 10)
                        .padding(.trailing, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    }
                    .animation(.easeInOut(duration: 0.12), value: isColorPanelVisible)
                    .zIndex(100)
                }
            }
        }
    }
}

// MARK: - No-Divider HSplitView

/// NSSplitView subclass whose divider is invisible but still 1 pt wide for dragging.
private class NoDividerSplitView: NSSplitView, NSSplitViewDelegate {
    private let minPaneWidth: CGFloat = 200

    override func drawDivider(in rect: NSRect) { /* invisible */ }
    override var dividerThickness: CGFloat { 1 }

    override func awakeFromNib() {
        super.awakeFromNib()
        delegate = self
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposed: CGFloat,
                   ofSubviewAt index: Int) -> CGFloat {
        max(proposed, minPaneWidth)
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMaxCoordinate proposed: CGFloat,
                   ofSubviewAt index: Int) -> CGFloat {
        min(proposed, splitView.bounds.width - minPaneWidth)
    }
}

private struct NoDividerHSplitView<L: View, R: View>: NSViewRepresentable {
    let left:  L
    let right: R

    func makeNSView(context: Context) -> NoDividerSplitView {
        let sv = NoDividerSplitView()
        sv.isVertical   = true
        sv.dividerStyle = .thin
        sv.delegate     = sv

        let lh = NSHostingView(rootView: left)
        let rh = NSHostingView(rootView: right)
        lh.autoresizingMask = [.width, .height]
        rh.autoresizingMask = [.width, .height]
        sv.addSubview(lh)
        sv.addSubview(rh)
        return sv
    }

    func updateNSView(_ sv: NoDividerSplitView, context: Context) {
        guard sv.subviews.count == 2 else { return }
        (sv.subviews[0] as? NSHostingView<L>)?.rootView = left
        (sv.subviews[1] as? NSHostingView<R>)?.rootView = right
    }
}

// MARK: - Window configurator (frame memory + title-bar icons)

/// NSView subclass with pre-attach and post-attach hooks.
/// Frame restoration runs in viewWillMove(toWindow:) to avoid a visible window jump.
private final class WindowSetupView: NSView {
    var onWindowWillAttach: ((NSWindow) -> Void)?
    var onWindowDidAttach: ((NSWindow) -> Void)?
    private weak var configuredWindow: NSWindow?
    private weak var attachedWindow: NSWindow?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        guard let newWindow else { return }
        guard configuredWindow !== newWindow else { return }
        configuredWindow = newWindow
        onWindowWillAttach?(newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        guard attachedWindow !== window else { return }
        attachedWindow = window
        onWindowDidAttach?(window)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let scrollSync: ScrollSyncController
    let isColorPanelVisible: Binding<Bool>

    func makeNSView(context: Context) -> WindowSetupView {
        let view = WindowSetupView()
        view.onWindowWillAttach = { window in
            context.coordinator.configureWindow(window)
        }

        view.onWindowDidAttach = { window in
            let icons = TitleBarIcons(
                scrollSync: context.coordinator.scrollSync,
                isColorPanelVisible: isColorPanelVisible
            )
            let hosting = NSHostingView(rootView: icons)
            context.coordinator.titlebarHosting = hosting
            var size = hosting.fittingSize
            if size.width < 10 { size = CGSize(width: 120, height: 28) } // safety fallback
            hosting.frame.size = size

            let vc = NSTitlebarAccessoryViewController()
            vc.view = hosting
            vc.layoutAttribute = .trailing
            window.addTitlebarAccessoryViewController(vc)
        }
        return view
    }

    func updateNSView(_ nsView: WindowSetupView, context: Context) {
        context.coordinator.titlebarHosting?.rootView = TitleBarIcons(
            scrollSync: scrollSync,
            isColorPanelVisible: isColorPanelVisible
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scrollSync: scrollSync)
    }

    class Coordinator {
        let scrollSync: ScrollSyncController
        weak var titlebarHosting: NSHostingView<TitleBarIcons>?
        weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private let frameKey = "CleanMDGlobalWindowFrame"

        init(scrollSync: ScrollSyncController) {
            self.scrollSync = scrollSync
        }

        func configureWindow(_ window: NSWindow) {
            if self.window !== window {
                removeObservers()
                self.window = window
                addObservers(for: window)
            }

            if let raw = UserDefaults.standard.string(forKey: frameKey) {
                let saved = NSRectFromString(raw)
                if saved.width > 300, saved.height > 240 {
                    window.setFrame(saved, display: false, animate: false)
                    return
                }
            }

            window.setFrame(NSRect(x: 0, y: 0, width: 1100, height: 720), display: false, animate: false)
            window.center()
        }

        private func addObservers(for window: NSWindow) {
            let nc = NotificationCenter.default
            observers.append(
                nc.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                    self?.saveWindowFrame()
                }
            )
            observers.append(
                nc.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                    self?.saveWindowFrame()
                }
            )
        }

        private func removeObservers() {
            let nc = NotificationCenter.default
            for token in observers {
                nc.removeObserver(token)
            }
            observers.removeAll()
        }

        private func saveWindowFrame() {
            guard let window else { return }
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: frameKey)
        }

        deinit {
            removeObservers()
        }
    }
}

// MARK: - Title-bar icons

private struct TitleBarIcons: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @ObservedObject var scrollSync: ScrollSyncController
    @Binding var isColorPanelVisible: Bool

    @State private var darkHover    = false
    @State private var syncHover    = false
    @State private var paletteHover = false

    var body: some View {
        HStack(spacing: 14) {
            // Scroll sync icon
            ScrollSyncIcon(isLinked: scrollSync.isLinked)
                .foregroundStyle(.secondary)
                .opacity(syncHover ? 0.45 : 1.0)
                .contentShape(Rectangle())
                .onTapGesture { scrollSync.isLinked.toggle() }
                .onHover { syncHover = $0 }

            // Dark / light toggle
            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 11.5, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .opacity(darkHover ? 0.45 : 1.0)
                .contentShape(Rectangle())
                .onTapGesture { isDarkMode.toggle() }
                .onHover { darkHover = $0 }

            // Color settings
            Image(systemName: "paintpalette")
                .font(.system(size: 11.5, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isColorPanelVisible ? Color.accentColor : .secondary)
                .opacity(paletteHover ? 0.45 : 1.0)
                .contentShape(Rectangle())
                .onTapGesture { isColorPanelVisible.toggle() }
                .onHover { paletteHover = $0 }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .padding(.trailing, 8)
    }
}

// MARK: - Scroll-sync icon

private struct ScrollSyncIcon: View {
    let isLinked: Bool

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let stroke: CGFloat = 1.5
            let thumbW  = w * 0.30
            let thumbH  = h * 0.36
            let trackX1 = w * 0.28
            let trackX2 = w * 0.72
            let top     = h * 0.04
            let bottom  = h * 0.96

            for x in [trackX1, trackX2] {
                var p = Path()
                p.move(to: CGPoint(x: x, y: top))
                p.addLine(to: CGPoint(x: x, y: bottom))
                ctx.stroke(p, with: .foreground, lineWidth: stroke)
            }

            let mid: CGFloat = h * 0.50
            let hi:  CGFloat = h * 0.30
            let lo:  CGFloat = h * 0.68

            func thumb(cx: CGFloat, cy: CGFloat) -> CGRect {
                CGRect(x: cx - thumbW / 2, y: cy - thumbH / 2, width: thumbW, height: thumbH)
            }

            ctx.fill(Path(thumb(cx: trackX1, cy: isLinked ? mid : hi)), with: .foreground)
            ctx.fill(Path(thumb(cx: trackX2, cy: isLinked ? mid : lo)), with: .foreground)
        }
        .frame(width: 16, height: 16)
        .opacity(isLinked ? 1.0 : 0.4)
    }
}
