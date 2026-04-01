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

    // Warm preset tuned toward the popular Obsidian "Things" aesthetic:
    // native-feeling warm neutrals with understated tan/orange accents.
    static let paperLight = ColorPalette(
        editorBg:     "#f7f3eb",
        editorText:   "#41362e",
        previewBg:    "#fcf8f1",
        previewText:  "#433831",
        h1:           "#8b5e34",
        h2:           "#7d6a2d",
        h3:           "#6d7b3d",
        inlineCodeBg: "#efe6cd",
        inlineCodeFg: "#7a4e2f",
        codeBlockBg:  "#ede0cf",
        quoteText:    "#6f6257",
        quoteBorder:  "#d4c4b0",
        link:         "#a14a3b"
    )

    static let paperDark = ColorPalette(
        editorBg:     "#1f1b19",
        editorText:   "#e8dfd2",
        previewBg:    "#191614",
        previewText:  "#e9e0d3",
        h1:           "#e4b67c",
        h2:           "#cdbb72",
        h3:           "#9fb476",
        inlineCodeBg: "#3a3128",
        inlineCodeFg: "#ebb58e",
        codeBlockBg:  "#302722",
        quoteText:    "#c6b4a3",
        quoteBorder:  "#66574d",
        link:         "#d98674"
    )

    // Cool preset tuned toward the popular Obsidian "Blue Topaz" aesthetic:
    // crisp blue surfaces, brighter contrast, and stronger cyan/blue accents.
    static let coolLight = ColorPalette(
        editorBg:     "#eef5fb",
        editorText:   "#23384d",
        previewBg:    "#f5fbff",
        previewText:  "#223a50",
        h1:           "#2364aa",
        h2:           "#3b82c4",
        h3:           "#6a6edc",
        inlineCodeBg: "#dde6fb",
        inlineCodeFg: "#4f56c7",
        codeBlockBg:  "#deedf7",
        quoteText:    "#5b7085",
        quoteBorder:  "#acc7df",
        link:         "#0ea5c6"
    )

    static let coolDark = ColorPalette(
        editorBg:     "#0f1824",
        editorText:   "#d6e8f8",
        previewBg:    "#0c1520",
        previewText:  "#d9ebfb",
        h1:           "#7cc4ff",
        h2:           "#5fb2ff",
        h3:           "#8f9cff",
        inlineCodeBg: "#1d2b46",
        inlineCodeFg: "#b7b8ff",
        codeBlockBg:  "#132331",
        quoteText:    "#9db9d6",
        quoteBorder:  "#35516d",
        link:         "#54d2ff"
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
