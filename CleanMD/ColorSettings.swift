import SwiftUI
import AppKit

// MARK: - ColorPalette

struct ColorPalette: Codable, Equatable {
    var editorBg:     String = "#F7F8FA"
    var editorText:   String = "#24292e"
    var previewBg:    String = "#ffffff"
    var previewText:  String = "#24292e"
    var h1:           String = "#24292e"
    var h2:           String = "#24292e"
    var h3:           String = "#24292e"
    var inlineCodeBg: String = "#eaecf0"
    var inlineCodeFg: String = "#24292e"
    var codeBlockBg:  String = "#eaecf0"
    var quoteText:    String = "#57606a"
    var quoteBorder:  String = "#d0d7de"
    var link:         String = "#0969da"

    static let darkDefault = ColorPalette(
        editorBg:     "#1e1e1e",
        editorText:   "#e1e4e8",
        previewBg:    "#0d1117",
        previewText:  "#e1e4e8",
        h1:           "#e1e4e8",
        h2:           "#e1e4e8",
        h3:           "#e1e4e8",
        inlineCodeBg: "#30363d",
        inlineCodeFg: "#d8d9f2",
        codeBlockBg:  "#161b22",
        quoteText:    "#b8bcc7",
        quoteBorder:  "#3d444d",
        link:         "#79c0ff"
    )
}

// MARK: - ColorSettings (singleton)

final class ColorSettings: ObservableObject {
    static let shared = ColorSettings()

    @Published var lightPalette: ColorPalette = .init()        { didSet { persist(); version += 1 } }
    @Published var darkPalette:  ColorPalette = .darkDefault   { didSet { persist(); version += 1 } }
    @Published var showH1Divider: Bool = true                  { didSet { persist(); version += 1 } }
    @Published var showH2Divider: Bool = true                  { didSet { persist(); version += 1 } }
    /// Increments whenever either palette changes. Pass as a param to
    /// EditorView/PreviewView so their updateNSView fires on color changes.
    @Published var version: Int = 0

    func palette(isDark: Bool) -> ColorPalette { isDark ? darkPalette : lightPalette }

    private init() {
        func load<T: Decodable>(_ key: String) -> T? {
            guard let s = UserDefaults.standard.string(forKey: key),
                  let v = try? JSONDecoder().decode(T.self, from: Data(s.utf8)) else { return nil }
            return v
        }
        // v2 keys — new schema (h1/h2/h3 instead of heading)
        if let p: ColorPalette = load("cp_v2_light") { lightPalette = p }
        if let p: ColorPalette = load("cp_v2_dark")  { darkPalette  = p }
        if UserDefaults.standard.object(forKey: "cp_show_h1_divider") != nil {
            showH1Divider = UserDefaults.standard.bool(forKey: "cp_show_h1_divider")
        }
        if UserDefaults.standard.object(forKey: "cp_show_h2_divider") != nil {
            showH2Divider = UserDefaults.standard.bool(forKey: "cp_show_h2_divider")
        }
    }

    private func persist() {
        func store<T: Encodable>(_ v: T, key: String) {
            guard let d = try? JSONEncoder().encode(v),
                  let s = String(data: d, encoding: .utf8) else { return }
            UserDefaults.standard.set(s, forKey: key)
        }
        store(lightPalette, key: "cp_v2_light")
        store(darkPalette,  key: "cp_v2_dark")
        UserDefaults.standard.set(showH1Divider, forKey: "cp_show_h1_divider")
        UserDefaults.standard.set(showH2Divider, forKey: "cp_show_h2_divider")
    }
}

// MARK: - SwiftUI Color ↔ hex  (NSColor side lives in EditorView.swift)

extension Color {
    /// Create a SwiftUI Color from a "#rrggbb" hex string.
    init(hex: String) {
        self.init(NSColor(hex: hex))   // NSColor(hex:) is defined in EditorView.swift
    }
    /// Return "#rrggbb" for this color.
    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02x%02x%02x",
                      Int((c.redComponent   * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent  * 255).rounded()))
    }
}
