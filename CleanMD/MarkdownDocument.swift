import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdownFile: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

struct MarkdownDocument: FileDocument {
    var text: String

    init(text: String = "# New Document\n\nStart writing here...\n") {
        self.text = text
    }

    static var readableContentTypes: [UTType] {
        [.markdownFile, UTType(filenameExtension: "md") ?? .plainText]
    }

    init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
