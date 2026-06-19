import Foundation

enum ExternalFileState: Equatable {
    case idle
    case externalUpdateAvailable
    case conflict
    case fileUnavailable
}

enum DocumentReloading {
    static func loadText(from fileURL: URL?) throws -> String? {
        guard let fileURL else { return nil }

        let hasScopedAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: fileURL)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return text
    }

    static func saveText(_ text: String, to fileURL: URL?) throws {
        guard let fileURL else { throw CocoaError(.fileNoSuchFile) }

        let hasScopedAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func externalFileState(
        baselineText: String,
        currentText: String,
        diskText: String?
    ) -> ExternalFileState {
        guard let diskText else { return .fileUnavailable }

        if diskText == currentText {
            return .idle
        }

        if diskText == baselineText {
            return .idle
        }

        if currentText == baselineText {
            return .externalUpdateAvailable
        }

        return .conflict
    }

}
