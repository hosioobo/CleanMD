import Foundation

enum PreviewMode: Equatable {
    case markdown
    case code(language: String)
}

enum SupportedDocumentKind: Equatable {
    case markdown
    case yaml
    case unsupported
}

extension SupportedDocumentKind {
    private static let markdownExtensions: Set<String> = ["md", "markdown"]
    private static let yamlExtensions: Set<String> = ["yml", "yaml"]

    init(fileExtension: String?) {
        let normalized = fileExtension?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if Self.markdownExtensions.contains(normalized) {
            self = .markdown
        } else if Self.yamlExtensions.contains(normalized) {
            self = .yaml
        } else {
            self = .unsupported
        }
    }

    init(url: URL) {
        self.init(fileExtension: url.pathExtension)
    }

    var isSupportedReadableFile: Bool {
        self != .unsupported
    }

    var previewMode: PreviewMode? {
        switch self {
        case .markdown:
            return .markdown
        case .yaml:
            return .code(language: "yaml")
        case .unsupported:
            return nil
        }
    }

    static func isSupportedReadableFile(url: URL) -> Bool {
        SupportedDocumentKind(url: url).isSupportedReadableFile
    }
}
