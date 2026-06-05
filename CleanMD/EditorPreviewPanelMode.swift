import Foundation

enum EditorPreviewPanelMode: String, CaseIterable, Identifiable {
    case both
    case editorOnly
    case previewOnly

    var id: String { rawValue }

    var showsEditor: Bool {
        self != .previewOnly
    }

    var showsPreview: Bool {
        self != .editorOnly
    }

    static func normalized(_ rawValue: String) -> EditorPreviewPanelMode {
        EditorPreviewPanelMode(rawValue: rawValue) ?? .both
    }
}
