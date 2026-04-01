import SwiftUI
import AppKit

// MARK: - ColorPalette

struct ColorPalette: Codable, Equatable {
    static let lightDefault = ColorPalette()

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

    static let paperLight = ColorPalette(
        editorBg:     "#f6f0e2",
        editorText:   "#4d3b2a",
        previewBg:    "#fbf4e6",
        previewText:  "#4d3b2a",
        h1:           "#3f2f21",
        h2:           "#4d3b2a",
        h3:           "#5b4633",
        inlineCodeBg: "#eadfcb",
        inlineCodeFg: "#4d3b2a",
        codeBlockBg:  "#efe5d3",
        quoteText:    "#6a5644",
        quoteBorder:  "#c8b79a",
        link:         "#8b5e34"
    )

    static let paperDark = ColorPalette(
        editorBg:     "#2d241d",
        editorText:   "#e8dcc7",
        previewBg:    "#241d18",
        previewText:  "#e8dcc7",
        h1:           "#f3e8d3",
        h2:           "#eadfc9",
        h3:           "#d8c6aa",
        inlineCodeBg: "#3a3028",
        inlineCodeFg: "#f1e6d2",
        codeBlockBg:  "#332a23",
        quoteText:    "#c8b79d",
        quoteBorder:  "#6c5a49",
        link:         "#d8a36d"
    )

    static let coolLight = ColorPalette(
        editorBg:     "#f3f7fb",
        editorText:   "#1f3347",
        previewBg:    "#f7fbff",
        previewText:  "#20384c",
        h1:           "#173247",
        h2:           "#234761",
        h3:           "#2f5975",
        inlineCodeBg: "#dfeaf4",
        inlineCodeFg: "#20415a",
        codeBlockBg:  "#e6eff7",
        quoteText:    "#536b7d",
        quoteBorder:  "#b6cad9",
        link:         "#0d6efd"
    )

    static let coolDark = ColorPalette(
        editorBg:     "#131c26",
        editorText:   "#d9e7f3",
        previewBg:    "#0f1720",
        previewText:  "#dce9f4",
        h1:           "#f3f8fc",
        h2:           "#d7e7f5",
        h3:           "#b8d0e4",
        inlineCodeBg: "#22303d",
        inlineCodeFg: "#dceaf7",
        codeBlockBg:  "#1b2732",
        quoteText:    "#a7bfd2",
        quoteBorder:  "#395062",
        link:         "#7cc4ff"
    )
}

enum AppearanceThemePreset: String, CaseIterable, Identifiable {
    case `default`
    case paper
    case cool
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: return "Default"
        case .paper: return "Paper"
        case .cool: return "Cool"
        case .custom: return "Custom"
        }
    }

    var palettes: (light: ColorPalette, dark: ColorPalette)? {
        switch self {
        case .default:
            return (.lightDefault, .darkDefault)
        case .paper:
            return (.paperLight, .paperDark)
        case .cool:
            return (.coolLight, .coolDark)
        case .custom:
            return nil
        }
    }

    static let selectableCases: [AppearanceThemePreset] = [.default, .paper, .cool]
}

// MARK: - ColorSettings (singleton)

final class ColorSettings: ObservableObject {
    static let shared = ColorSettings()

    @Published var lightPalette: ColorPalette = .init()        { didSet { schedulePersist() } }
    @Published var darkPalette:  ColorPalette = .darkDefault   { didSet { schedulePersist() } }
    @Published var showH1Divider: Bool = true                  { didSet { schedulePersist() } }
    @Published var showH2Divider: Bool = true                  { didSet { schedulePersist() } }

    func palette(isDark: Bool) -> ColorPalette { isDark ? darkPalette : lightPalette }

    var currentPreset: AppearanceThemePreset {
        for preset in AppearanceThemePreset.selectableCases {
            guard let palettes = preset.palettes else { continue }
            if lightPalette == palettes.light && darkPalette == palettes.dark {
                return preset
            }
        }
        return .custom
    }

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private var pendingPersistWorkItem: DispatchWorkItem?
    private var terminationObserver: NSObjectProtocol?
    private let persistDelay: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        persistDelay: TimeInterval = 0.12,
        notificationCenter: NotificationCenter = .default,
        observeTermination: Bool = true
    ) {
        self.defaults = defaults
        self.persistDelay = persistDelay
        self.notificationCenter = notificationCenter

        func load<T: Decodable>(_ key: String) -> T? {
            guard let s = defaults.string(forKey: key),
                  let v = try? JSONDecoder().decode(T.self, from: Data(s.utf8)) else { return nil }
            return v
        }
        // v2 keys — new schema (h1/h2/h3 instead of heading)
        if let p: ColorPalette = load("cp_v2_light") { lightPalette = p }
        if let p: ColorPalette = load("cp_v2_dark")  { darkPalette  = p }
        if defaults.object(forKey: "cp_show_h1_divider") != nil {
            showH1Divider = defaults.bool(forKey: "cp_show_h1_divider")
        }
        if defaults.object(forKey: "cp_show_h2_divider") != nil {
            showH2Divider = defaults.bool(forKey: "cp_show_h2_divider")
        }

        if observeTermination {
            terminationObserver = notificationCenter.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.flushPendingPersist()
            }
        }
    }

    func restoreDefaults() {
        lightPalette = .lightDefault
        darkPalette = .darkDefault
        showH1Divider = true
        showH2Divider = true
    }

    func applyPreset(_ preset: AppearanceThemePreset) {
        guard let palettes = preset.palettes else { return }
        lightPalette = palettes.light
        darkPalette = palettes.dark
    }

    func flushPendingPersist() {
        pendingPersistWorkItem?.cancel()
        pendingPersistWorkItem = nil
        persist()
    }

    private func schedulePersist() {
        pendingPersistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persist()
        }
        pendingPersistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + persistDelay, execute: workItem)
    }

    private func persist() {
        func store<T: Encodable>(_ v: T, key: String) {
            guard let d = try? JSONEncoder().encode(v),
                  let s = String(data: d, encoding: .utf8) else { return }
            defaults.set(s, forKey: key)
        }
        store(lightPalette, key: "cp_v2_light")
        store(darkPalette,  key: "cp_v2_dark")
        defaults.set(showH1Divider, forKey: "cp_show_h1_divider")
        defaults.set(showH2Divider, forKey: "cp_show_h2_divider")
    }

    deinit {
        flushPendingPersist()
        if let terminationObserver {
            notificationCenter.removeObserver(terminationObserver)
        }
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
