import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @Environment(\.newDocument) private var newDocument
    @StateObject private var scrollSync: ScrollSyncController
    @StateObject private var fileExplorerStore: FileExplorerStore
    @StateObject private var reloadConflictMonitor: ReloadConflictMonitor
    @State private var documentSaveCoordinator = DocumentSaveCoordinator()
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @SceneStorage("isSidebarCollapsed") private var isSidebarCollapsed: Bool = false
    @SceneStorage("editorPreviewPanelMode") private var editorPreviewPanelModeRaw: String = EditorPreviewPanelMode.both.rawValue
    @State private var isColorPanelVisible: Bool = false
    @SceneStorage("appearanceInspectorWidth") private var appearanceInspectorWidth: Double = Double(AppearanceInspectorLayout.defaultWidth)
    @State private var isDragTargeted = false
    @State private var inspectorDragStartWidth: CGFloat?
    @State private var inspectorResizeCursorActive = false
    @State private var lastPresentedExternalUpdateText: String?
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
        _reloadConflictMonitor = StateObject(wrappedValue: ReloadConflictMonitor())
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
            palette: activePalette,
            scrollSync: scrollSync,
            isColorPanelVisible: $isColorPanelVisible,
            editorPreviewPanelModeRaw: editorPreviewPanelModeBinding,
            showsReloadButton: reloadConflictMonitor.state == .externalUpdateAvailable,
            onReloadFromDisk: handleReloadCue
        ))
        .onAppear {
            fileExplorerStore.updateCurrentFileURL(fileURL)
            reloadConflictMonitor.start(fileURL: fileURL, currentText: document.text)
        }
        .onChange(of: fileURL) { newValue in
            fileExplorerStore.updateCurrentFileURL(newValue)
            reloadConflictMonitor.start(fileURL: newValue, currentText: document.text)
        }
        .onChange(of: document.text) { newValue in
            reloadConflictMonitor.updateCurrentText(newValue)
        }
        .onChange(of: reloadConflictMonitor.state) { newValue in
            if newValue == .externalUpdateAvailable {
                presentExternalUpdatePromptIfNeeded()
            }
        }
        .onChange(of: reloadConflictMonitor.pendingDiskText) { _ in
            presentExternalUpdatePromptIfNeeded()
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
                    .stroke(themeAccent, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
    }

    private var workspace: some View {
        NoDividerHSplitView(
            left: FileExplorerView(
                store: fileExplorerStore,
                palette: activePalette,
                isCollapsed: $isSidebarCollapsed
            ),
            right: documentWorkspace,
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

    private var activePalette: ColorPalette {
        colorSettings.palette(isDark: isDarkMode)
    }

    private var themeAccent: Color {
        Color(hex: activePalette.themeAccent)
    }

    private var documentWorkspace: some View {
        VStack(spacing: 0) {
            externalFileBanner
            editorPreviewWorkspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var externalFileBanner: some View {
        switch reloadConflictMonitor.state {
        case .conflict:
            conflictBanner
        case .fileUnavailable:
            fileUnavailableBanner
        case .idle, .externalUpdateAvailable:
            EmptyView()
        }
    }

    private var conflictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            Text("External changes conflict with this editor.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Button("Reload Disk", action: reloadDiskVersionWithConfirmation)
            Button("Keep Both", action: keepBothVersions)
            Button("Save Mine", action: saveMineToDisk)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
        }
    }

    private var fileUnavailableBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)

            Text("The file was moved, deleted, or cannot be read.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Button("Save As", action: saveCurrentDocumentAs)
            Button("Dismiss", action: reloadConflictMonitor.dismissFileUnavailable)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var editorPreviewWorkspace: some View {
        switch editorPreviewPanelMode {
        case .both:
            NoDividerHSplitView(
                left: editorPanel,
                right: previewPanel
            )
        case .editorOnly:
            editorPanel
        case .previewOnly:
            previewPanel
        }
    }

    private var editorPanel: some View {
        EditorView(
            text: $document.text,
            scrollSync: scrollSync,
            isDarkMode: isDarkMode,
            palette: activePalette
        )
    }

    private var previewPanel: some View {
        PreviewView(
            text: document.text,
            scrollSync: scrollSync,
            isDarkMode: isDarkMode,
            palette: activePalette,
            showH1Divider: colorSettings.showH1Divider,
            showH2Divider: colorSettings.showH2Divider,
            fileURL: fileURL
        )
    }

    private var editorPreviewPanelMode: EditorPreviewPanelMode {
        EditorPreviewPanelMode.normalized(editorPreviewPanelModeRaw)
    }

    private var editorPreviewPanelModeBinding: Binding<String> {
        Binding(
            get: { EditorPreviewPanelMode.normalized(editorPreviewPanelModeRaw).rawValue },
            set: { editorPreviewPanelModeRaw = EditorPreviewPanelMode.normalized($0).rawValue }
        )
    }

    private func handleReloadCue() {
        switch reloadConflictMonitor.state {
        case .externalUpdateAvailable:
            presentExternalUpdatePrompt(force: true)
        case .conflict:
            reloadDiskVersionWithConfirmation()
        case .idle, .fileUnavailable:
            NSSound.beep()
        }
    }

    private func reloadDiskVersionWithConfirmation() {
        do {
            guard let reloadedText = try latestDiskText() else {
                NSSound.beep()
                return
            }

            if document.text != reloadedText {
                guard confirmReloadReplacement() else { return }
            }

            applyDiskText(reloadedText)
        } catch {
            NSSound.beep()
        }
    }

    private func presentExternalUpdatePromptIfNeeded() {
        guard reloadConflictMonitor.state == .externalUpdateAvailable,
              let diskText = reloadConflictMonitor.pendingDiskText,
              lastPresentedExternalUpdateText != diskText else { return }

        DispatchQueue.main.async {
            presentExternalUpdatePrompt()
        }
    }

    private func presentExternalUpdatePrompt(force: Bool = false) {
        guard reloadConflictMonitor.state == .externalUpdateAvailable,
              let diskText = reloadConflictMonitor.pendingDiskText else { return }
        guard force || lastPresentedExternalUpdateText != diskText else { return }

        lastPresentedExternalUpdateText = diskText

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "External Changes Available"
        alert.informativeText = "The file changed on disk. Choose whether to reload the disk version or keep the current editor contents."
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Keep Current")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            applyDiskText(diskText)
        case .alertSecondButtonReturn:
            reloadConflictMonitor.keepCurrentVersion()
        default:
            break
        }
    }

    private func confirmReloadReplacement() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reload from Disk?"
        alert.informativeText = "This will replace the current editor contents with the latest version on disk. Any unsaved edits in this window will be discarded."
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func latestDiskText() throws -> String? {
        if let pendingDiskText = reloadConflictMonitor.pendingDiskText {
            return pendingDiskText
        }
        return try DocumentReloading.loadText(from: fileURL)
    }

    private func applyDiskText(_ text: String) {
        document.text = text
        lastPresentedExternalUpdateText = nil
        reloadConflictMonitor.markResolved(currentText: text)
        clearReloadedDocumentChangeCount()
    }

    private func saveMineToDisk() {
        guard let fileURL,
              let nsDocument = NSDocumentController.shared.document(for: fileURL) else {
            NSSound.beep()
            return
        }

        documentSaveCoordinator.save(nsDocument) { didSave in
            DispatchQueue.main.async {
                guard didSave else {
                    NSSound.beep()
                    return
                }

                lastPresentedExternalUpdateText = nil
                reloadConflictMonitor.markSaved(currentText: document.text)
            }
        }
    }

    private func keepBothVersions() {
        guard let diskText = reloadConflictMonitor.pendingDiskText else {
            NSSound.beep()
            return
        }

        newDocument(MarkdownDocument(text: diskText))
        reloadConflictMonitor.keepCurrentVersion()
    }

    private func saveCurrentDocumentAs() {
        guard let fileURL,
              let nsDocument = NSDocumentController.shared.document(for: fileURL) else {
            NSSound.beep()
            return
        }

        nsDocument.saveAs(nil)
    }

    private func clearReloadedDocumentChangeCount() {
        guard let fileURL else { return }
        DispatchQueue.main.async {
            NSDocumentController.shared.document(for: fileURL)?.updateChangeCount(.changeCleared)
        }
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
        .onHover { hovering in
            guard hovering != inspectorResizeCursorActive else { return }
            inspectorResizeCursorActive = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if inspectorResizeCursorActive {
                NSCursor.pop()
                inspectorResizeCursorActive = false
            }
        }
        .help("Resize Appearance Inspector")
        .accessibilityLabel("Resize Appearance Inspector")
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
        let candidate: CGFloat = proposedWidth ?? CGFloat(appearanceInspectorWidth)
        return AppearanceInspectorLayout.clampedWidth(candidate, totalWidth: totalWidth)
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
    let palette: ColorPalette
    let scrollSync: ScrollSyncController
    let isColorPanelVisible: Binding<Bool>
    let editorPreviewPanelModeRaw: Binding<String>
    let showsReloadButton: Bool
    let onReloadFromDisk: () -> Void

    func makeNSView(context: Context) -> WindowSetupView {
        let view = WindowSetupView()
        view.onWindowWillAttach = { window in
            context.coordinator.configureWindow(window)
        }

        view.onWindowDidAttach = { window in
            let icons = TitleBarIcons(
                palette: palette,
                scrollSync: context.coordinator.scrollSync,
                isColorPanelVisible: isColorPanelVisible,
                editorPreviewPanelModeRaw: editorPreviewPanelModeRaw,
                showsReloadButton: showsReloadButton,
                onReloadFromDisk: onReloadFromDisk,
                onToggleAppearancePanel: { context.coordinator.toggleAppearancePanel() }
            )
            let hosting = NSHostingView(rootView: icons)
            context.coordinator.titlebarHosting = hosting
            Self.updateFittingSize(for: hosting)

            let vc = NSTitlebarAccessoryViewController()
            vc.view = hosting
            vc.layoutAttribute = .trailing
            window.addTitlebarAccessoryViewController(vc)
        }
        return view
    }

    func updateNSView(_ nsView: WindowSetupView, context: Context) {
        guard let hosting = context.coordinator.titlebarHosting else { return }
        hosting.rootView = TitleBarIcons(
            palette: palette,
            scrollSync: scrollSync,
            isColorPanelVisible: isColorPanelVisible,
            editorPreviewPanelModeRaw: editorPreviewPanelModeRaw,
            showsReloadButton: showsReloadButton,
            onReloadFromDisk: onReloadFromDisk,
            onToggleAppearancePanel: { context.coordinator.toggleAppearancePanel() }
        )
        Self.updateFittingSize(for: hosting)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scrollSync: scrollSync, isColorPanelVisible: isColorPanelVisible)
    }

    private static func updateFittingSize(for hosting: NSHostingView<TitleBarIcons>) {
        var size = hosting.fittingSize
        if size.width < 10 { size = CGSize(width: 120, height: 28) } // safety fallback
        hosting.frame.size = size
    }

    class Coordinator {
        let scrollSync: ScrollSyncController
        let isColorPanelVisible: Binding<Bool>
        weak var titlebarHosting: NSHostingView<TitleBarIcons>?
        weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private var keyMonitor: Any?
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

            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self else { return event }
                    guard self.isColorPanelVisible.wrappedValue else { return event }
                    guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else { return event }
                    guard event.keyCode == 53 else { return event }
                    self.isColorPanelVisible.wrappedValue = false
                    return nil
                }
            }
        }

        private func removeObservers() {
            let nc = NotificationCenter.default
            for token in observers {
                nc.removeObserver(token)
            }
            observers.removeAll()
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
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
    let palette: ColorPalette
    @ObservedObject var scrollSync: ScrollSyncController
    @Binding var isColorPanelVisible: Bool
    @Binding var editorPreviewPanelModeRaw: String
    let showsReloadButton: Bool
    let onReloadFromDisk: () -> Void
    let onToggleAppearancePanel: () -> Void

    @State private var reloadHover  = false
    @State private var darkHover    = false
    @State private var syncHover    = false
    @State private var paletteHover = false

    private var themeAccent: Color {
        Color(hex: palette.themeAccent)
    }

    var body: some View {
        HStack(spacing: 14) {
            if showsReloadButton {
                // Reload from disk
                Button {
                    onReloadFromDisk()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11.5, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .opacity(reloadHover ? 0.45 : 1.0)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Reload External Changes from Disk")
                .accessibilityLabel("Reload External Changes from Disk")
                .onHover { reloadHover = $0 }
            }

            EditorPreviewPanelModeControl(selection: $editorPreviewPanelModeRaw, palette: palette)

            // Scroll sync icon
            Button {
                scrollSync.toggleLinking()
            } label: {
                ScrollSyncIcon(isLinked: scrollSync.isLinked)
                    .foregroundStyle(scrollSync.isLinked ? themeAccent : Color.secondary)
                    .opacity(syncHover ? 0.45 : 1.0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(scrollSync.isLinked ? "Disable Scroll Sync" : "Enable Scroll Sync")
            .accessibilityLabel(scrollSync.isLinked ? "Disable Scroll Sync" : "Enable Scroll Sync")
            .onHover { syncHover = $0 }

            // Dark / light toggle
            Button {
                isDarkMode.toggle()
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 11.5, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .opacity(darkHover ? 0.45 : 1.0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
            .accessibilityLabel(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
            .onHover { darkHover = $0 }

            // Color settings
            Button {
                onToggleAppearancePanel()
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 11.5, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isColorPanelVisible ? themeAccent : Color.secondary)
                    .opacity(paletteHover ? 0.45 : 1.0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isColorPanelVisible ? "Hide Appearance Inspector" : "Show Appearance Inspector")
            .accessibilityLabel(isColorPanelVisible ? "Hide Appearance Inspector" : "Show Appearance Inspector")
            .onHover { paletteHover = $0 }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .padding(.trailing, 8)
    }
}

private struct EditorPreviewPanelModeControl: View {
    @Binding var selection: String
    let palette: ColorPalette

    private var themeAccent: Color {
        Color(hex: palette.themeAccent)
    }

    var body: some View {
        HStack(spacing: 0) {
            segment(
                mode: .editorOnly,
                systemName: "sidebar.left",
                help: "Show Editor Only"
            )
            segment(
                mode: .both,
                systemName: "rectangle.split.2x1",
                help: "Show Editor and Preview"
            )
            segment(
                mode: .previewOnly,
                systemName: "sidebar.right",
                help: "Show Preview Only"
            )
        }
        .padding(1)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editor Preview Layout")
    }

    private func segment(
        mode: EditorPreviewPanelMode,
        systemName: String,
        help: String
    ) -> some View {
        let isSelected = EditorPreviewPanelMode.normalized(selection) == mode

        return Button {
            selection = mode.rawValue
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? themeAccent : Color.secondary)
                .frame(width: 24, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? themeAccent.opacity(0.16) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
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
