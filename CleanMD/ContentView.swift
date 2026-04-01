import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var scrollSync: ScrollSyncController
    @StateObject private var fileExplorerStore: FileExplorerStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @SceneStorage("isSidebarCollapsed") private var isSidebarCollapsed: Bool = false
    @State private var isColorPanelVisible: Bool = false
    @SceneStorage("appearanceInspectorWidth") private var appearanceInspectorWidth: Double = 396
    @State private var isDragTargeted = false
    @State private var inspectorDragStartWidth: CGFloat?
    // Observing colorSettings causes ContentView to re-render when palette changes,
    // which propagates the new palette + version params to the NSViewRepresentables.
    @ObservedObject private var colorSettings = ColorSettings.shared

    init(document: Binding<MarkdownDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
        _scrollSync = StateObject(wrappedValue: ScrollSyncController())
        _fileExplorerStore = StateObject(
            wrappedValue: FileExplorerStore(currentFileURL: fileURL)
        )
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                workspace
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isColorPanelVisible {
                    trailingAppearanceInspector(
                        availableHeight: geo.size.height,
                        totalWidth: geo.size.width
                    )
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .background(WindowConfigurator(
            scrollSync: scrollSync,
            isColorPanelVisible: $isColorPanelVisible
        ))
        .onAppear {
            fileExplorerStore.updateCurrentFileURL(fileURL)
        }
        .onChange(of: fileURL) { newValue in
            fileExplorerStore.updateCurrentFileURL(newValue)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var fileURL: URL?
                    if let data = item as? Data {
                        fileURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        fileURL = url
                    }
                    guard let url = fileURL,
                          SupportedDocumentKind.isSupportedReadableFile(url: url) else { return }
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
    }

    private var workspace: some View {
        NoDividerHSplitView(
            left: FileExplorerView(
                store: fileExplorerStore,
                isCollapsed: $isSidebarCollapsed
            ),
            right: NoDividerHSplitView(
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
                    showH2Divider: colorSettings.showH2Divider,
                    fileURL: fileURL
                )
            ),
            layout: .init(
                autosaveKey: "CleanMDSidebarExpandedWidthV2",
                defaultLeftWidth: 220,
                minLeftWidth: 170,
                minRightWidth: 420,
                collapsedLeftWidth: 36,
                isCollapsed: $isSidebarCollapsed,
                preserveLeftWidthOnResize: true
            )
        )
    }

    private func trailingAppearanceInspector(availableHeight: CGFloat, totalWidth: CGFloat) -> some View {
        let inspectorWidth = clampedAppearanceInspectorWidth(totalWidth: totalWidth)

        return HStack(spacing: 0) {
            inspectorResizeHandle(totalWidth: totalWidth)

            ColorSettingsPanel(
                isVisible: $isColorPanelVisible,
                availableHeight: availableHeight
            )
            .frame(width: inspectorWidth)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func inspectorResizeHandle(totalWidth: CGFloat) -> some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1)
        }
        .frame(width: 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if inspectorDragStartWidth == nil {
                        inspectorDragStartWidth = clampedAppearanceInspectorWidth(totalWidth: totalWidth)
                    }

                    let baseWidth = inspectorDragStartWidth ?? clampedAppearanceInspectorWidth(totalWidth: totalWidth)
                    let nextWidth = clampedAppearanceInspectorWidth(
                        proposedWidth: baseWidth - value.translation.width,
                        totalWidth: totalWidth
                    )
                    appearanceInspectorWidth = Double(nextWidth)
                }
                .onEnded { _ in
                    inspectorDragStartWidth = nil
                }
        )
    }

    private func clampedAppearanceInspectorWidth(
        proposedWidth: CGFloat? = nil,
        totalWidth: CGFloat
    ) -> CGFloat {
        let minimum: CGFloat = 340
        let maximum = max(minimum, min(520, totalWidth * 0.42))
        let candidate: CGFloat = proposedWidth ?? CGFloat(appearanceInspectorWidth)
        return min(max(candidate, minimum), maximum)
    }
}

// MARK: - No-Divider HSplitView

/// NSSplitView subclass whose divider is invisible but still 1 pt wide for dragging.
private final class NoDividerSplitView: NSSplitView {
    override func drawDivider(in rect: NSRect) { /* invisible */ }
    override var dividerThickness: CGFloat { 1 }
}

private struct SplitViewLayout {
    var autosaveKey: String? = nil
    var defaultLeftWidth: CGFloat = 0
    var minLeftWidth: CGFloat = 200
    var minRightWidth: CGFloat = 200
    var collapsedLeftWidth: CGFloat? = nil
    var isCollapsed: Binding<Bool>? = nil
    var preserveLeftWidthOnResize: Bool = false

    static let balanced = SplitViewLayout(
        autosaveKey: nil,
        defaultLeftWidth: 0,
        minLeftWidth: 200,
        minRightWidth: 200,
        collapsedLeftWidth: nil,
        isCollapsed: nil,
        preserveLeftWidthOnResize: false
    )
}

private final class SplitViewCoordinator: NSObject, NSSplitViewDelegate {
    var layout: SplitViewLayout
    private weak var splitView: NoDividerSplitView?
    private weak var leftSubview: NSView?
    private weak var rightSubview: NSView?
    private var hasAppliedInitialLayout = false
    private var lastCollapsedState: Bool?
    private var isApplyingProgrammaticLayout = false

    init(layout: SplitViewLayout) {
        self.layout = layout
    }

    func install(splitView: NoDividerSplitView, leftSubview: NSView, rightSubview: NSView) {
        self.splitView = splitView
        self.leftSubview = leftSubview
        self.rightSubview = rightSubview
        splitView.delegate = self
        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView else { return }
            self.applyLayout(to: splitView, force: true)
        }
    }

    func applyLayout(to splitView: NoDividerSplitView, force: Bool) {
        guard splitView.subviews.count == 2 else { return }

        let isCollapsed = layout.isCollapsed?.wrappedValue ?? false
        let totalWidth = availableWidth(in: splitView)
        if !isCollapsed && totalWidth <= 0 {
            DispatchQueue.main.async { [weak self, weak splitView] in
                guard let self, let splitView else { return }
                self.applyLayout(to: splitView, force: true)
            }
            return
        }
        let collapsedChanged = lastCollapsedState != isCollapsed
        guard force || !hasAppliedInitialLayout || collapsedChanged else { return }

        hasAppliedInitialLayout = true
        lastCollapsedState = isCollapsed
        leftSubview?.isHidden = false

        let targetWidth: CGFloat
        if isCollapsed {
            targetWidth = layout.collapsedLeftWidth ?? 36
        } else {
            targetWidth = clampedExpandedLeftWidth(storedOrDefaultLeftWidth(), totalWidth: totalWidth)
        }

        isApplyingProgrammaticLayout = true
        splitView.setPosition(targetWidth, ofDividerAt: 0)
        splitView.adjustSubviews()
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingProgrammaticLayout = false
        }

        if !isCollapsed {
            persistLeftWidth(targetWidth)
        }
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard let splitView else { return }
        guard !isApplyingProgrammaticLayout else { return }
        guard !(layout.isCollapsed?.wrappedValue ?? false) else { return }

        let width = clampedExpandedLeftWidth(currentLeftWidth(in: splitView), totalWidth: availableWidth(in: splitView))
        guard width > 1 else { return }
        persistLeftWidth(width)
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        guard splitView.subviews.count == 2 else { return }

        let dividerThickness = splitView.dividerThickness
        let bounds = splitView.bounds
        let totalWidth = max(0, bounds.width - dividerThickness)
        let leftWidth: CGFloat

        if layout.isCollapsed?.wrappedValue ?? false {
            leftWidth = layout.collapsedLeftWidth ?? 36
        } else if layout.preserveLeftWidthOnResize {
            leftWidth = clampedExpandedLeftWidth(storedOrDefaultLeftWidth(), totalWidth: totalWidth)
        } else {
            let oldTotalWidth = max(1, oldSize.width - dividerThickness)
            let ratio = currentLeftWidth(in: splitView) / oldTotalWidth
            leftWidth = clampedExpandedLeftWidth(totalWidth * ratio, totalWidth: totalWidth)
        }

        let rightWidth = max(layout.minRightWidth, bounds.width - dividerThickness - leftWidth)
        splitView.subviews[0].frame = NSRect(x: 0, y: 0, width: leftWidth, height: bounds.height)
        splitView.subviews[1].frame = NSRect(x: leftWidth + dividerThickness, y: 0, width: rightWidth, height: bounds.height)
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMinCoordinate proposed: CGFloat,
        ofSubviewAt index: Int
    ) -> CGFloat {
        if layout.isCollapsed?.wrappedValue ?? false {
            return layout.collapsedLeftWidth ?? 36
        }
        return max(proposed, layout.minLeftWidth)
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMaxCoordinate proposed: CGFloat,
        ofSubviewAt index: Int
    ) -> CGFloat {
        if layout.isCollapsed?.wrappedValue ?? false {
            return layout.collapsedLeftWidth ?? 36
        }
        let maxLeftWidth = max(0, availableWidth(in: splitView) - layout.minRightWidth)
        return min(proposed, maxLeftWidth)
    }

    private func storedOrDefaultLeftWidth() -> CGFloat {
        guard let autosaveKey = layout.autosaveKey else {
            return layout.defaultLeftWidth
        }

        let storedWidth = UserDefaults.standard.double(forKey: autosaveKey)
        if storedWidth > 0 {
            return storedWidth
        }

        return layout.defaultLeftWidth
    }

    private func persistLeftWidth(_ width: CGFloat) {
        guard let autosaveKey = layout.autosaveKey, width > 0 else { return }
        UserDefaults.standard.set(width, forKey: autosaveKey)
    }

    private func availableWidth(in splitView: NSSplitView) -> CGFloat {
        max(0, splitView.bounds.width - splitView.dividerThickness)
    }

    private func currentLeftWidth(in splitView: NSSplitView) -> CGFloat {
        guard splitView.subviews.count >= 1 else { return 0 }
        return splitView.subviews[0].frame.width
    }

    private func clampedLeftWidth(_ proposed: CGFloat, totalWidth: CGFloat) -> CGFloat {
        clampedExpandedLeftWidth(proposed, totalWidth: totalWidth)
    }

    private func clampedExpandedLeftWidth(_ proposed: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let minimum = min(layout.minLeftWidth, max(0, totalWidth - layout.minRightWidth))
        let maximum = max(minimum, totalWidth - layout.minRightWidth)
        let fallback = layout.defaultLeftWidth > 0 ? layout.defaultLeftWidth : max(minimum, totalWidth * 0.5)
        let candidate = proposed > 0 ? proposed : fallback
        return min(max(candidate, minimum), maximum)
    }
}

private struct NoDividerHSplitView<L: View, R: View>: NSViewRepresentable {
    let left:  L
    let right: R
    var layout: SplitViewLayout = .balanced

    func makeCoordinator() -> SplitViewCoordinator {
        SplitViewCoordinator(layout: layout)
    }

    func makeNSView(context: Context) -> NoDividerSplitView {
        let sv = NoDividerSplitView()
        sv.isVertical   = true
        sv.dividerStyle = .thin

        let lh = NSHostingView(rootView: left)
        let rh = NSHostingView(rootView: right)
        lh.autoresizingMask = [.width, .height]
        rh.autoresizingMask = [.width, .height]
        sv.addSubview(lh)
        sv.addSubview(rh)
        context.coordinator.install(splitView: sv, leftSubview: lh, rightSubview: rh)
        return sv
    }

    func updateNSView(_ sv: NoDividerSplitView, context: Context) {
        guard sv.subviews.count == 2 else { return }
        context.coordinator.layout = layout
        (sv.subviews[0] as? NSHostingView<L>)?.rootView = left
        (sv.subviews[1] as? NSHostingView<R>)?.rootView = right
        context.coordinator.applyLayout(to: sv, force: false)
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
                isColorPanelVisible: isColorPanelVisible,
                onToggleAppearancePanel: { context.coordinator.toggleAppearancePanel() }
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
            isColorPanelVisible: isColorPanelVisible,
            onToggleAppearancePanel: { context.coordinator.toggleAppearancePanel() }
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scrollSync: scrollSync, isColorPanelVisible: isColorPanelVisible)
    }

    class Coordinator {
        let scrollSync: ScrollSyncController
        let isColorPanelVisible: Binding<Bool>
        weak var titlebarHosting: NSHostingView<TitleBarIcons>?
        weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private let frameKey = "CleanMDGlobalWindowFrame"

        init(scrollSync: ScrollSyncController, isColorPanelVisible: Binding<Bool>) {
            self.scrollSync = scrollSync
            self.isColorPanelVisible = isColorPanelVisible
        }

        func configureWindow(_ window: NSWindow) {
            if self.window !== window {
                removeObservers()
                self.window = window
                addObservers(for: window)
            }

            let savedFrame: CGRect? = UserDefaults.standard.string(forKey: frameKey).map(NSRectFromString)
            let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            let existingWindowCount = Self.visibleWindowCount(excluding: window)
            let targetFrame = WindowFramePolicy.placementFrame(
                savedFrame: savedFrame,
                visibleFrame: visibleFrame,
                existingWindowCount: existingWindowCount
            )

            window.setFrame(targetFrame, display: false, animate: false)
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

        func toggleAppearancePanel() {
            isColorPanelVisible.wrappedValue.toggle()
        }

        private static func visibleWindowCount(excluding window: NSWindow) -> Int {
            NSApp.windows.filter {
                $0 !== window &&
                $0.isVisible &&
                !$0.isMiniaturized &&
                $0.canBecomeMain
            }.count
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
    let onToggleAppearancePanel: () -> Void

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
                .onTapGesture { scrollSync.toggleLinking() }
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
                .onTapGesture { onToggleAppearancePanel() }
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
