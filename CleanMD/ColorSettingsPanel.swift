import SwiftUI
import AppKit

// MARK: - Color Chip
// Square swatch (click → native color panel) and separate hex field.

private struct ColorChip: View {
    @Binding var hex: String
    var body: some View { NativeColorChip(hex: $hex) }
}

private struct NativeColorChip: NSViewRepresentable {
    @Binding var hex: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(frame: .zero)
        well.isBordered = true
        if #available(macOS 13.0, *) {
            well.colorWellStyle = .minimal
        }
        well.color = NSColor(hex: hex)
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    func updateNSView(_ well: NSColorWell, context: Context) {
        context.coordinator.parent = self
        let target = NSColor(hex: hex)
        if !well.color.isEqual(target) {
            well.color = target
        }
    }

    final class Coordinator: NSObject {
        var parent: NativeColorChip

        init(_ parent: NativeColorChip) {
            self.parent = parent
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            parent.hex = Color(sender.color).hexString.lowercased()
        }
    }
}

private struct HexField: View {
    @Binding var hex: String
    @State private var hexInput = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        TextField("", text: $hexInput)
            .font(.system(size: 10, design: .monospaced))
            .textFieldStyle(.plain)
            .padding(.horizontal, 6)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
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
        var s = hexInput.trimmingCharacters(in: .whitespaces)
        if !s.hasPrefix("#") { s = "#" + s }
        let body = String(s.dropFirst())
        if body.count == 6, body.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }) {
            hex = s.lowercased()
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
    private let col1: CGFloat = 168
    private let chipSize: CGFloat = 22
    private let hexWidth: CGFloat = 90
    private let col2: CGFloat = 112   // Light: chip + hex
    private let col3: CGFloat = 112   // Dark:  chip + hex
    private let modeGap: CGFloat = 14
    private var panelMaxHeight: CGFloat { min(760, max(220, availableHeight - 20)) }
    private var panelMinHeight: CGFloat { min(420, panelMaxHeight) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
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
            Divider().opacity(0.4)
            footer
        }
        .frame(maxHeight: panelMaxHeight)
        .frame(width: col1 + col2 + modeGap + col3 + 32)
        .frame(minHeight: panelMinHeight, maxHeight: panelMaxHeight)
        // Panel background = preview pane background → "preview of the preview"
        .background(Color(hex: cp.previewBg), in: RoundedRectangle(cornerRadius: 12))
        // Force SwiftUI colour scheme to match app's dark/light, not the OS setting
        .environment(\.colorScheme, isDarkMode ? .dark : .light)
        .shadow(color: .black.opacity(0.30), radius: 24, y: 8)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Text("Appearance")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button { isVisible = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var colHeaders: some View {
        HStack(spacing: 0) {
            Text("Item")
                .frame(width: col1, alignment: .leading)
            Text("Light Mode")
                .frame(width: col2)
            Color.clear.frame(width: modeGap)
            Text("Dark Mode")
                .frame(width: col3)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.06))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Restore Defaults") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    cs.lightPalette = .init()
                    cs.darkPalette  = .darkDefault
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
                ColorChip(hex: lHex)
                    .frame(width: chipSize, height: chipSize)
                HexField(hex: lHex)
                    .frame(width: hexWidth)
            }
            .frame(width: col2, alignment: .leading)
            .clipped()
            Color.clear.frame(width: modeGap)
            HStack(spacing: 0) {
                ColorChip(hex: dHex)
                    .frame(width: chipSize, height: chipSize)
                HexField(hex: dHex)
                    .frame(width: hexWidth)
            }
            .frame(width: col3, alignment: .leading)
            .clipped()
        }
        .padding(.vertical, 6)
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
        .padding(.vertical, 6)
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
