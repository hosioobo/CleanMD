import Foundation

struct PathDisplayFormatter {
    private let homeDirectoryPath: String

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectoryPath = homeDirectory.standardizedFileURL.path
    }

    func parentPath(for fileURL: URL) -> String {
        let parentPath = fileURL.deletingLastPathComponent().standardizedFileURL.path
        return Self.displayPath(parentPath, homeDirectoryPath: homeDirectoryPath)
    }

    private static func displayPath(_ path: String, homeDirectoryPath: String) -> String {
        guard !path.isEmpty else { return path }

        if path == homeDirectoryPath {
            return "~"
        }

        let homePrefix: String
        if homeDirectoryPath == "/" {
            homePrefix = "/"
        } else {
            homePrefix = homeDirectoryPath + "/"
        }

        if path.hasPrefix(homePrefix) {
            let suffix = String(path.dropFirst(homeDirectoryPath.count))
            return "~" + suffix
        }

        return path
    }
}
