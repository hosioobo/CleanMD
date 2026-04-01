import Foundation
import UniformTypeIdentifiers

enum PreviewURLKind {
    case link
    case image
}

enum PreviewNavigationAction: Equatable {
    case allowInPlace
    case openExternally(URL)
    case openDocument(URL)
    case cancel
}

enum PreviewURLPolicy {
    static let localFileScheme = "cleanmd-local"

    static func allowedSchemes(for kind: PreviewURLKind) -> [String] {
        switch kind {
        case .link:
            return ["http", "https", "mailto", "file"]
        case .image:
            return ["http", "https", "file"]
        }
    }

    static func allowedSchemesJSON(for kind: PreviewURLKind) -> String {
        let schemes = allowedSchemes(for: kind)
        guard let data = try? JSONEncoder().encode(schemes),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func documentBaseURL(for fileURL: URL?) -> URL? {
        fileURL?.standardizedFileURL.deletingLastPathComponent()
    }

    static func documentBaseURLAbsoluteString(for fileURL: URL?) -> String? {
        documentBaseURL(for: fileURL)?.absoluteString
    }

    static func localPreviewURL(for fileURL: URL) -> URL {
        let normalized = fileURL.standardizedFileURL
        let sourceComponents = URLComponents(url: normalized, resolvingAgainstBaseURL: false)
        var components = URLComponents()
        components.scheme = localFileScheme
        components.percentEncodedPath = sourceComponents?.percentEncodedPath ?? normalized.path
        components.percentEncodedQuery = sourceComponents?.percentEncodedQuery
        components.percentEncodedFragment = sourceComponents?.percentEncodedFragment
        return components.url ?? normalized
    }

    static func fileURL(fromLocalPreviewURL url: URL) -> URL? {
        guard url.scheme?.lowercased() == localFileScheme else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "file"
        return components?.url?.standardizedFileURL
    }

    static func mimeType(for fileURL: URL, data: Data) -> String {
        if let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType {
            return mimeType
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "image/png"
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        if data.starts(with: Array("GIF87a".utf8)) || data.starts(with: Array("GIF89a".utf8)) {
            return "image/gif"
        }
        if data.count >= 12,
           data.starts(with: Array("RIFF".utf8)),
           data[8..<12].elementsEqual(Array("WEBP".utf8)) {
            return "image/webp"
        }

        return "application/octet-stream"
    }

    static func resolvedURLString(
        from rawValue: String?,
        kind: PreviewURLKind,
        documentBaseURL: URL?
    ) -> String? {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if kind == .link, trimmed.hasPrefix("#") { return trimmed }

        let resolvedURL: URL?
        if let parsed = URL(string: trimmed), parsed.scheme != nil {
            resolvedURL = parsed
        } else if let documentBaseURL, documentBaseURL.isFileURL {
            resolvedURL = resolvedLocalFileURL(from: trimmed, relativeTo: documentBaseURL)
        } else if let documentBaseURL {
            resolvedURL = URL(string: trimmed, relativeTo: documentBaseURL)?.absoluteURL
        } else {
            resolvedURL = nil
        }

        guard let resolvedURL,
              let scheme = resolvedURL.scheme?.lowercased(),
              allowedSchemes(for: kind).contains(scheme) else {
            return nil
        }

        return resolvedURL.absoluteString
    }

    private static func resolvedLocalFileURL(from rawPath: String, relativeTo baseURL: URL) -> URL {
        if rawPath.hasPrefix("/") {
            return URL(fileURLWithPath: rawPath).standardizedFileURL
        }

        return URL(fileURLWithPath: rawPath, relativeTo: baseURL).standardizedFileURL
    }

    static func navigationAction(for url: URL, currentURL: URL?) -> PreviewNavigationAction {
        if let fileURL = fileURL(fromLocalPreviewURL: url) {
            return navigationAction(for: fileURL, currentURL: currentURL)
        }

        if isSameDocumentFragmentNavigation(url, currentURL: currentURL) {
            return .allowInPlace
        }

        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        switch scheme {
        case "http", "https", "mailto":
            return .openExternally(url)
        case "file":
            let normalized = url.standardizedFileURL
            if SupportedDocumentKind.isSupportedReadableFile(url: normalized) {
                return .openDocument(normalized)
            }
            return .openExternally(url)
        default:
            return .cancel
        }
    }

    static func isSameDocumentFragmentNavigation(_ url: URL, currentURL: URL?) -> Bool {
        guard let currentURL,
              var targetComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              var currentComponents = URLComponents(url: currentURL, resolvingAgainstBaseURL: false),
              let fragment = targetComponents.fragment,
              !fragment.isEmpty else {
            return false
        }

        targetComponents.fragment = nil
        currentComponents.fragment = nil
        return targetComponents.url == currentComponents.url
    }
}
