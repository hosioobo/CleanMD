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
}

// MARK: - ColorSettings (singleton)

final class ColorSettings: ObservableObject {
    static let shared = ColorSettings()

    @Published var lightPalette: ColorPalette = .init()        { didSet { schedulePersist() } }
    @Published var darkPalette:  ColorPalette = .darkDefault   { didSet { schedulePersist() } }
    @Published var showH1Divider: Bool = true                  { didSet { schedulePersist() } }
    @Published var showH2Divider: Bool = true                  { didSet { schedulePersist() } }

    func palette(isDark: Bool) -> ColorPalette { isDark ? darkPalette : lightPalette }

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
