import SwiftUI

// MARK: - Fused color control

private struct ColorValueControl: View {
    @Binding var hex: String
    @State private var isPopoverPresented = false
    @State private var isHovered = false
    @State private var isFieldFocused = false

    private var isActive: Bool { isPopoverPresented || isFieldFocused }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                isPopoverPresented.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: hex))
                    .frame(width: 26, height: 26)
                    .padding(1)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                QuickColorPopover(hex: $hex, isPresented: $isPopoverPresented)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1, height: 18)

            EmbeddedHexField(hex: $hex, isFocused: $isFieldFocused)
                .frame(height: 28)
        }
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isActive
                                ? Color.accentColor.opacity(0.8)
                                : Color.primary.opacity(isHovered ? 0.24 : 0.14),
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

private enum QuickColorSwatches {
    static let rows: [[String]] = [
        ["#ffffff", "#f7f8fa", "#eaecf0", "#d0d7de", "#8c959f", "#57606a", "#24292e", "#0d1117"],
        ["#e3f2fd", "#bbdefb", "#90caf9", "#64b5f6", "#42a5f5", "#1e88e5", "#1565c0", "#0d47a1"],
        ["#ede7f6", "#d1c4e9", "#b39ddb", "#9575cd", "#7e57c2", "#5e35b1", "#4527a0", "#311b92"],
        ["#e8f5e9", "#c8e6c9", "#a5d6a7", "#81c784", "#66bb6a", "#43a047", "#2e7d32", "#1b5e20"],
        ["#fff3e0", "#ffe0b2", "#ffcc80", "#ffb74d", "#ffa726", "#fb8c00", "#ef6c00", "#e65100"],
        ["#fce4ec", "#f8bbd0", "#f48fb1", "#f06292", "#ec407a", "#d81b60", "#ad1457", "#880e4f"]
    ]
}

private struct QuickColorPopover: View {
    @Binding var hex: String
    @Binding var isPresented: Bool

    private var liveColor: Binding<Color> {
        Binding(
            get: { Color(hex: hex) },
            set: { hex = $0.hexString.lowercased() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: hex))
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pick color")
                        .font(.system(size: 12, weight: .semibold))
                    Text(hex.uppercased())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                ForEach(Array(QuickColorSwatches.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { swatch in
                            Button {
                                hex = swatch
                                isPresented = false
                            } label: {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color(hex: swatch))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(
                                                hex == swatch ? Color.accentColor : Color.primary.opacity(0.16),
                                                lineWidth: hex == swatch ? 1.5 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("HEX")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("", selection: liveColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(0.9)
                }
                StandaloneHexField(hex: $hex, fieldHeight: 26, cornerRadius: 6)
            }
        }
        .padding(12)
        .frame(width: 236)
    }
}

private struct StandaloneHexField: View {
    @Binding var hex: String
    var fieldHeight: CGFloat = 22
    var cornerRadius: CGFloat = 4
    @State private var hexInput = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        TextField("", text: $hexInput)
            .font(.system(size: 10, design: .monospaced))
            .textFieldStyle(.plain)
            .padding(.horizontal, 6)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                hexFocused ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.16),
                                lineWidth: 1
                            )
                    )
            )
            .focused($hexFocused)
            .onSubmit { commitHex() }
            .onChange(of: hexFocused) { if !$0 { commitHex() } }
            .onAppear { hexInput = hex.uppercased() }
            .onChange(of: hex) { if !hexFocused { hexInput = $0.uppercased() } }
    }

    private func commitHex() {
        if let normalized = ColorHex.normalize(hexInput) {
            hex = normalized
        }
        hexInput = hex.uppercased()
    }
}

private struct EmbeddedHexField: View {
    @Binding var hex: String
    @Binding var isFocused: Bool
    @State private var hexInput = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        TextField("", text: $hexInput)
            .font(.system(size: 10, design: .monospaced))
            .textFieldStyle(.plain)
            .padding(.horizontal, 7)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .focused($fieldFocused)
            .onSubmit { commitHex() }
            .onChange(of: fieldFocused) {
                isFocused = $0
                if !$0 { commitHex() }
            }
            .onAppear { hexInput = hex.uppercased() }
            .onChange(of: hex) { if !fieldFocused { hexInput = $0.uppercased() } }
    }

    private func commitHex() {
        if let normalized = ColorHex.normalize(hexInput) {
            hex = normalized
        }
        hexInput = hex.uppercased()
    }
}

// MARK: - Color Settings Panel

struct ColorSettingsPanel: View {
    @Binding var isVisible: Bool
    let availableHeight: CGFloat
    @ObservedObject private var cs = ColorSettings.shared
    @AppStorage("isDarkMode") private var isDarkMode = false

    /// Active palette — follows app's dark/light toggle, not OS appearance.
    private var cp: ColorPalette { isDarkMode ? cs.darkPalette : cs.lightPalette }

    // Panel layout constants
    private let col1: CGFloat = 138
    private let col2: CGFloat = 108
    private let col3: CGFloat = 108
    private let modeGap: CGFloat = 10
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("appearanceTop")
                        colHeaders
                        Divider().opacity(0.4)
                        editorRows
                        previewRows
                    }
                }
                .onAppear { proxy.scrollTo("appearanceTop", anchor: .top) }
            }
            Divider().opacity(0.5)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
        .environment(\.colorScheme, isDarkMode ? .dark : .light)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Text("Appearance")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button { isVisible = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
    }

    private var colHeaders: some View {
        HStack(spacing: 0) {
            Text("Item")
                .frame(width: col1, alignment: .leading)
            Text("Light")
                .frame(width: col2)
            Color.clear.frame(width: modeGap)
            Text("Dark")
                .frame(width: col3)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Restore Defaults") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    cs.restoreDefaults()
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
    }

    // MARK: - Editor rows

    private var editorRows: some View {
        VStack(spacing: 0) {
            sectionLabel("EDITOR")
            row(l: $cs.lightPalette.editorBg, d: $cs.darkPalette.editorBg) {
                bgSwatchLabel(hex: cp.editorBg, name: "Background")
            }
            row(l: $cs.lightPalette.editorText, d: $cs.darkPalette.editorText) {
                aaLabel(hex: cp.editorText, name: "Text")
            }
        }
    }

    // MARK: - Preview rows

    private var previewRows: some View {
        VStack(spacing: 0) {
            sectionLabel("PREVIEW")

            row(l: $cs.lightPalette.previewBg, d: $cs.darkPalette.previewBg) {
                bgSwatchLabel(hex: cp.previewBg, name: "Background")
            }
            row(l: $cs.lightPalette.previewText, d: $cs.darkPalette.previewText) {
                aaLabel(hex: cp.previewText, name: "Body Text")
            }

            // Headings — rendered at appropriate scale so the row IS the preview
            row(l: $cs.lightPalette.h1, d: $cs.darkPalette.h1) {
                Text("Heading 1")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: cp.h1))
                    .lineLimit(1)
            }
            toggleRow(label: "H1 Divider", isOn: $cs.showH1Divider)
            row(l: $cs.lightPalette.h2, d: $cs.darkPalette.h2) {
                Text("Heading 2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: cp.h2))
                    .lineLimit(1)
            }
            toggleRow(label: "H2 Divider", isOn: $cs.showH2Divider)
            row(l: $cs.lightPalette.h3, d: $cs.darkPalette.h3) {
                Text("Heading 3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: cp.h3))
                    .lineLimit(1)
            }

            // Code block
            row(l: $cs.lightPalette.codeBlockBg, d: $cs.darkPalette.codeBlockBg) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: cp.codeBlockBg))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .frame(width: 30, height: 20)
                        .overlay(
                            Text("{ }")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(Color(hex: cp.previewText).opacity(0.5))
                        )
                    Text("Code Block").font(.system(size: 12))
                }
            }

            // Inline code
            row(l: $cs.lightPalette.inlineCodeBg, d: $cs.darkPalette.inlineCodeBg) {
                HStack(spacing: 5) {
                    codePill
                    Text("Background").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            row(l: $cs.lightPalette.inlineCodeFg, d: $cs.darkPalette.inlineCodeFg) {
                HStack(spacing: 5) {
                    codePill
                    Text("Text").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }

            // Blockquote
            row(l: $cs.lightPalette.quoteText, d: $cs.darkPalette.quoteText) {
                HStack(spacing: 0) {
                    quoteLine
                    Text("  Quote Text")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: cp.quoteText))
                }
            }
            row(l: $cs.lightPalette.quoteBorder, d: $cs.darkPalette.quoteBorder) {
                HStack(spacing: 0) {
                    quoteLine
                    Text("  Quote Border").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            // Link
            row(l: $cs.lightPalette.link, d: $cs.darkPalette.link) {
                Text("Link text")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: cp.link))
                    .underline()
            }
        }
    }

    // MARK: - Sub-components

    private var codePill: some View {
        Text("code")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color(hex: cp.inlineCodeFg))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(hex: cp.inlineCodeBg), in: RoundedRectangle(cornerRadius: 3))
    }

    private var quoteLine: some View {
        Rectangle()
            .fill(Color(hex: cp.quoteBorder))
            .frame(width: 3, height: 20)
            .cornerRadius(1.5)
    }

    // MARK: - Row builder

    private func row<L: View>(
        l lHex: Binding<String>,
        d dHex: Binding<String>,
        @ViewBuilder label: () -> L
    ) -> some View {
        return HStack(alignment: .center, spacing: 0) {
            label()
                .frame(width: col1, alignment: .leading)
                .clipped()
            HStack(spacing: 0) {
                ColorValueControl(hex: lHex)
            }
            .frame(width: col2, alignment: .leading)
            .clipped()
            Color.clear.frame(width: modeGap)
            HStack(spacing: 0) {
                ColorValueControl(hex: dHex)
            }
            .frame(width: col3, alignment: .leading)
            .clipped()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.system(size: 12))
                .frame(width: col1, alignment: .leading)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(width: col2 + modeGap + col3, alignment: .leading)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 5)
    }

    // MARK: - Label styles

    /// A small coloured swatch square + label name — for background colour rows.
    private func bgSwatchLabel(hex: String, name: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: hex))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
                .frame(width: 18, height: 18)
            Text(name).font(.system(size: 12))
        }
    }

    /// "Aa" rendered in the chosen colour + label name — for text colour rows.
    private func aaLabel(hex: String, name: String) -> some View {
        HStack(spacing: 7) {
            Text("Aa")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: hex))
            Text(name).font(.system(size: 12))
        }
    }
}
