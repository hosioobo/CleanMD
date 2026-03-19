import Foundation
import AppKit

final class RecentDocumentHistory {
    static let shared = RecentDocumentHistory()

    private let defaults: UserDefaults
    private let storageKey = "CleanMDRecentDocumentHistory"
    private let maxEntries = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(_ url: URL) {
        let normalized = url.standardizedFileURL
        var paths = defaults.stringArray(forKey: storageKey) ?? []
        paths.removeAll { $0 == normalized.path }
        paths.insert(normalized.path, at: 0)
        if paths.count > maxEntries {
            paths = Array(paths.prefix(maxEntries))
        }
        defaults.set(paths, forKey: storageKey)
        NSDocumentController.shared.noteNewRecentDocumentURL(normalized)
    }

    func urls() -> [URL] {
        (defaults.stringArray(forKey: storageKey) ?? []).map(URL.init(fileURLWithPath:))
    }

    func mergedWithSystemRecentDocuments() -> [URL] {
        Self.merge(primary: urls(), secondary: NSDocumentController.shared.recentDocumentURLs)
    }

    static func merge(primary: [URL], secondary: [URL]) -> [URL] {
        var seen = Set<String>()
        var merged: [URL] = []

        for url in primary + secondary {
            let normalized = url.standardizedFileURL
            guard seen.insert(normalized.path).inserted else { continue }
            merged.append(normalized)
        }

        return merged
    }
}
