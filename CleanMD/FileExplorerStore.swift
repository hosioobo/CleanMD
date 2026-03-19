import Foundation
import AppKit
import Combine

enum FileExplorerTab: Hashable {
    case folder
    case history
}

struct FileExplorerItem: Identifiable, Equatable {
    let id: URL
    let url: URL
    let title: String
    let subtitle: String?
    let isDirectory: Bool
    let isCurrentFile: Bool
}

final class FileExplorerStore: ObservableObject {
    struct Dependencies {
        var contentsOfDirectory: (URL) throws -> [URL]
        var recentDocumentURLs: () -> [URL]
        var openURL: (URL) -> Void
        var pathSubtitle: (URL) -> String
        var isReadableSupportedFile: (URL) -> Bool
        var isDirectory: (URL) -> Bool

        static func live() -> Self {
            let pathFormatter = PathDisplayFormatter()
            return Self(
                contentsOfDirectory: { url in
                    try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                },
                recentDocumentURLs: {
                    NSDocumentController.shared.recentDocumentURLs
                },
                openURL: { url in
                    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                },
                pathSubtitle: { url in
                    pathFormatter.parentPath(for: url)
                },
                isReadableSupportedFile: { url in
                    SupportedDocumentKind.isSupportedReadableFile(url: url)
                },
                isDirectory: { url in
                    FileExplorerStore.isDirectory(url)
                }
            )
        }
    }

    @Published var selectedTab: FileExplorerTab
    @Published private(set) var currentFileURL: URL?
    @Published private(set) var currentFolderURL: URL?
    @Published private(set) var folderItems: [FileExplorerItem] = []
    @Published private(set) var historyItems: [FileExplorerItem] = []

    private let dependencies: Dependencies

    init(
        currentFileURL: URL? = nil,
        selectedTab: FileExplorerTab = .folder,
        dependencies: Dependencies = .live()
    ) {
        self.selectedTab = selectedTab
        self.currentFileURL = currentFileURL?.standardizedFileURL
        self.currentFolderURL = currentFileURL?.standardizedFileURL.deletingLastPathComponent()
        self.dependencies = dependencies
        refresh()
    }

    func updateCurrentFileURL(_ url: URL?) {
        currentFileURL = url?.standardizedFileURL
        currentFolderURL = url?.standardizedFileURL.deletingLastPathComponent()
        refresh()
    }

    func refresh() {
        folderItems = makeFolderItems()
        historyItems = makeHistoryItems()
    }

    func activate(_ item: FileExplorerItem) {
        if item.isDirectory {
            currentFolderURL = Self.normalizedFileURL(item.url)
            refresh()
            return
        }
        if item.isCurrentFile {
            return
        }
        dependencies.openURL(item.url)
    }

    func selectTab(_ tab: FileExplorerTab) {
        selectedTab = tab
    }

    func navigateUp() {
        guard let currentFolderURL, canNavigateUp else { return }
        self.currentFolderURL = currentFolderURL.deletingLastPathComponent().standardizedFileURL
        refresh()
    }

    var visibleItems: [FileExplorerItem] {
        selectedTab == .folder ? folderItems : historyItems
    }

    var currentFolderName: String? {
        guard let currentFolderURL else { return nil }
        let name = currentFolderURL.lastPathComponent
        return name.isEmpty ? currentFolderURL.path : name
    }

    var currentFolderPath: String? {
        currentFolderURL?.path
    }

    var canNavigateUp: Bool {
        guard let currentFolderURL else { return false }
        return currentFolderURL.deletingLastPathComponent() != currentFolderURL
    }

    var emptyStateText: String {
        switch selectedTab {
        case .folder:
            return currentFolderURL == nil ? "Open a file to see its folder" : "No folders or readable files"
        case .history:
            return "No recent files"
        }
    }

    private func makeFolderItems() -> [FileExplorerItem] {
        guard let folderURL = currentFolderURL else { return [] }
        let files: [URL]
        do {
            files = try dependencies.contentsOfDirectory(folderURL)
        } catch {
            return []
        }

        let filtered = files
            .filter { dependencies.isDirectory($0) || dependencies.isReadableSupportedFile($0) }
            .sorted { lhs, rhs in
                let lhsIsDirectory = dependencies.isDirectory(lhs)
                let rhsIsDirectory = dependencies.isDirectory(rhs)
                if lhsIsDirectory != rhsIsDirectory {
                    return lhsIsDirectory
                }
                return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }

        let normalizedCurrent = currentFileURL.map(Self.normalizedFileURL)

        return filtered.map { url in
            let isDirectory = dependencies.isDirectory(url)
            return FileExplorerItem(
                id: url,
                url: url,
                title: url.lastPathComponent,
                subtitle: nil,
                isDirectory: isDirectory,
                isCurrentFile: !isDirectory && normalizedCurrent == Self.normalizedFileURL(url)
            )
        }
    }

    private func makeHistoryItems() -> [FileExplorerItem] {
        let urls = dependencies.recentDocumentURLs()
        var seen = Set<String>()
        let normalizedCurrent = currentFileURL.map(Self.normalizedFileURL)

        return urls.compactMap { url in
            guard dependencies.isReadableSupportedFile(url) else { return nil }

            let normalized = Self.normalizedFileURL(url)
            let key = normalized.path
            guard seen.insert(key).inserted else { return nil }

            return FileExplorerItem(
                id: normalized,
                url: normalized,
                title: normalized.lastPathComponent,
                subtitle: dependencies.pathSubtitle(normalized),
                isDirectory: false,
                isCurrentFile: normalizedCurrent == normalized
            )
        }
    }

    private static func normalizedFileURL(_ url: URL) -> URL {
        url.standardizedFileURL
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
