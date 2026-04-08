#!/usr/bin/env swift

import AppKit

struct Theme {
    static let paper = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1)
    static let panel = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 0.98)
    static let panelBorder = NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.85, alpha: 1)
    static let ink = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.11, alpha: 1)
    static let inkSoft = NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.38, alpha: 1)
    static let emerald = NSColor(calibratedRed: 0.07, green: 0.48, blue: 0.36, alpha: 1)
    static let emeraldSoft = NSColor(calibratedRed: 0.83, green: 0.92, blue: 0.88, alpha: 1)
    static let gold = NSColor(calibratedRed: 0.84, green: 0.70, blue: 0.43, alpha: 1)
    static let line = NSColor(calibratedRed: 0.86, green: 0.84, blue: 0.79, alpha: 1)
    static let shadow = NSColor(calibratedWhite: 0.05, alpha: 0.14)
    static let spotlightA = NSColor(calibratedRed: 0.07, green: 0.48, blue: 0.36, alpha: 0.22)
    static let spotlightB = NSColor(calibratedRed: 0.84, green: 0.70, blue: 0.43, alpha: 0.18)
}

enum AssetError: Error {
    case missingArgument
    case missingImage(String)
    case encodingFailed(String)
}

struct CopyRow {
    let label: String
    let lightHex: String
    let darkHex: String
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let framesDirectory: URL = {
    let arguments = CommandLine.arguments
    if arguments.count > 1 {
        return URL(fileURLWithPath: arguments[1], isDirectory: true)
    }

    return repoRoot
        .appendingPathComponent(".build", isDirectory: true)
        .appendingPathComponent("launch-assets", isDirectory: true)
        .appendingPathComponent("frames", isDirectory: true)
}()

let screenshotsDirectory = repoRoot.appendingPathComponent("screenshots", isDirectory: true)
let docsAssetsDirectory = repoRoot.appendingPathComponent("docs/assets", isDirectory: true)
let docsScreenshotsDirectory = docsAssetsDirectory.appendingPathComponent("screenshots", isDirectory: true)
let launchAssetsDirectory = docsAssetsDirectory.appendingPathComponent("launch", isDirectory: true)
let demoAssetsDirectory = docsAssetsDirectory.appendingPathComponent("demo", isDirectory: true)
let brandIconURL = docsAssetsDirectory.appendingPathComponent("brand/app-icon.png")

let lightScreenshotURL = screenshotsDirectory.appendingPathComponent("light-mode.png")
let darkScreenshotURL = screenshotsDirectory.appendingPathComponent("dark-mode.png")
let appearanceScreenshotURL = screenshotsDirectory.appendingPathComponent("appearance-panel.png")
let docsAppearanceScreenshotURL = docsScreenshotsDirectory.appendingPathComponent("appearance-panel.png")
let releaseProofGridURL = launchAssetsDirectory.appendingPathComponent("release-proof-grid.png")
let redditProofGridURL = launchAssetsDirectory.appendingPathComponent("rmacapps-proof-grid.png")
let demoPosterURL = launchAssetsDirectory.appendingPathComponent("demo-poster.png")

let panelRows: [CopyRow] = [
    .init(label: "Editor background", lightHex: "#fbfbfc", darkHex: "#181b1f"),
    .init(label: "Preview background", lightHex: "#fffaf1", darkHex: "#14171b"),
    .init(label: "Inline code", lightHex: "#f3ecdf", darkHex: "#263038"),
    .init(label: "Heading 1", lightHex: "#117a5c", darkHex: "#8fd0bc"),
    .init(label: "Link", lightHex: "#0f69b4", darkHex: "#8cbef4"),
    .init(label: "Accent", lightHex: "#d6b26d", darkHex: "#e5c989")
]

let paragraphStyle: NSMutableParagraphStyle = {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    return style
}()

func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func loadImage(_ url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw AssetError.missingImage(url.path)
    }
    return image
}

func pngData(for image: NSImage) throws -> Data {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else {
        throw AssetError.encodingFailed("Unable to encode \(image)")
    }

    return data
}

func writePNG(_ image: NSImage, to url: URL) throws {
    try pngData(for: image).write(to: url)
}

func image(_ size: CGSize, draw body: () -> Void) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocusFlipped(true)
    NSGraphicsContext.current?.imageInterpolation = .high
    body()
    image.unlockFocus()
    return image
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(
        roundedRect: rect,
        xRadius: radius,
        yRadius: radius
    )
}

func drawFill(_ color: NSColor, rect: CGRect, radius: CGFloat = 0) {
    color.setFill()
    if radius > 0 {
        roundedRect(rect, radius: radius).fill()
    } else {
        rect.fill()
    }
}

func drawStroke(_ color: NSColor, rect: CGRect, radius: CGFloat, width: CGFloat = 1) {
    color.setStroke()
    let path = roundedRect(rect.insetBy(dx: width / 2, dy: width / 2), radius: max(0, radius - width / 2))
    path.lineWidth = width
    path.stroke()
}

func shadow(_ offset: CGSize = .init(width: 0, height: 14), blur: CGFloat = 32, color: NSColor = Theme.shadow) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowOffset = offset
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = color
    return shadow
}

func drawText(
    _ text: String,
    rect: CGRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    shadow: NSShadow? = nil
) {
    let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
    style.alignment = alignment
    var attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    if let shadow {
        attributes[.shadow] = shadow
    }
    text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
}

func pill(
    label: String,
    rect: CGRect,
    fill: NSColor,
    stroke: NSColor,
    text: NSColor,
    font: NSFont,
    radius: CGFloat = 999
) {
    drawFill(fill, rect: rect, radius: radius)
    drawStroke(stroke, rect: rect, radius: radius)
    drawText(label, rect: rect.insetBy(dx: 12, dy: 8), font: font, color: text, alignment: .center)
}

func drawTrafficLights(origin: CGPoint) {
    let colors = [
        NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.34, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.21, alpha: 1),
        NSColor(calibratedRed: 0.19, green: 0.80, blue: 0.35, alpha: 1)
    ]

    for (index, color) in colors.enumerated() {
        let circle = CGRect(x: origin.x + CGFloat(index * 18), y: origin.y, width: 12, height: 12)
        color.setFill()
        NSBezierPath(ovalIn: circle).fill()
    }
}

func drawGlow(_ rect: CGRect, color: NSColor) {
    guard let gradient = NSGradient(colorsAndLocations: (color, 0), (color.withAlphaComponent(0), 1)) else {
        return
    }
    gradient.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
}

func hexColor(_ hex: String) -> NSColor {
    let value = hex.replacingOccurrences(of: "#", with: "")
    guard value.count == 6, let raw = Int(value, radix: 16) else {
        return .systemGray
    }

    let red = CGFloat((raw >> 16) & 0xff) / 255
    let green = CGFloat((raw >> 8) & 0xff) / 255
    let blue = CGFloat(raw & 0xff) / 255
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
}

func aspectFillRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
    let imageRatio = imageSize.width / imageSize.height
    let boundsRatio = bounds.width / bounds.height

    if imageRatio > boundsRatio {
        let scaledWidth = bounds.height * imageRatio
        return CGRect(
            x: bounds.midX - scaledWidth / 2,
            y: bounds.minY,
            width: scaledWidth,
            height: bounds.height
        )
    }

    let scaledHeight = bounds.width / imageRatio
    return CGRect(
        x: bounds.minX,
        y: bounds.midY - scaledHeight / 2,
        width: bounds.width,
        height: scaledHeight
    )
}

func drawImage(_ image: NSImage, in rect: CGRect) {
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}

func drawCard(
    image: NSImage,
    rect: CGRect,
    eyebrow: String,
    title: String,
    body: String
) {
    shadow(.init(width: 0, height: 20), blur: 34).set()
    drawFill(.white.withAlphaComponent(0.82), rect: rect, radius: 26)
    NSGraphicsContext.current?.saveGraphicsState()
    let clip = roundedRect(rect, radius: 26)
    clip.addClip()
    drawFill(.white.withAlphaComponent(0.78), rect: rect)
    drawFill(.white, rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 340))
    let imageRect = CGRect(x: rect.minX + 20, y: rect.minY + 20, width: rect.width - 40, height: 296)
    NSGraphicsContext.current?.saveGraphicsState()
    roundedRect(imageRect, radius: 18).addClip()
    drawImage(image, in: aspectFillRect(imageSize: image.size, in: imageRect))
    NSGraphicsContext.current?.restoreGraphicsState()
    drawStroke(Theme.line, rect: imageRect, radius: 18)
    NSGraphicsContext.current?.restoreGraphicsState()

    drawText(
        eyebrow.uppercased(),
        rect: CGRect(x: rect.minX + 20, y: rect.minY + 338, width: rect.width - 40, height: 22),
        font: .monospacedSystemFont(ofSize: 11, weight: .bold),
        color: Theme.emerald
    )
    drawText(
        title,
        rect: CGRect(x: rect.minX + 20, y: rect.minY + 366, width: rect.width - 40, height: 54),
        font: .systemFont(ofSize: 24, weight: .semibold),
        color: Theme.ink
    )
    drawText(
        body,
        rect: CGRect(x: rect.minX + 20, y: rect.minY + 426, width: rect.width - 40, height: rect.height - 444),
        font: .systemFont(ofSize: 16, weight: .regular),
        color: Theme.inkSoft
    )
}

func buildAppearanceScreenshot(base: NSImage) -> NSImage {
    image(CGSize(width: 1100, height: 720)) {
        drawImage(base, in: CGRect(x: 0, y: 0, width: 1100, height: 720))

        let handleRect = CGRect(x: 762, y: 44, width: 10, height: 664)
        drawFill(NSColor(calibratedWhite: 0.92, alpha: 1), rect: handleRect)
        drawFill(NSColor(calibratedWhite: 0.80, alpha: 1), rect: CGRect(x: 766, y: 80, width: 2, height: 620))

        let panelRect = CGRect(x: 772, y: 40, width: 310, height: 668)
        shadow(.init(width: -8, height: 14), blur: 18, color: NSColor(calibratedWhite: 0.02, alpha: 0.18)).set()
        drawFill(Theme.panel, rect: panelRect, radius: 20)
        drawStroke(Theme.panelBorder, rect: panelRect, radius: 20)

        drawText(
            "Appearance Inspector",
            rect: CGRect(x: 794, y: 62, width: 210, height: 24),
            font: .systemFont(ofSize: 19, weight: .semibold),
            color: Theme.ink
        )
        drawText(
            "Paper preset tuned for local Markdown review",
            rect: CGRect(x: 794, y: 89, width: 250, height: 22),
            font: .systemFont(ofSize: 12, weight: .regular),
            color: Theme.inkSoft
        )

        drawFill(NSColor.white.withAlphaComponent(0.74), rect: CGRect(x: 1034, y: 58, width: 28, height: 28), radius: 14)
        drawStroke(Theme.panelBorder, rect: CGRect(x: 1034, y: 58, width: 28, height: 28), radius: 14)
        drawText("x", rect: CGRect(x: 1034, y: 62, width: 28, height: 20), font: .systemFont(ofSize: 12, weight: .bold), color: Theme.inkSoft, alignment: .center)

        drawText(
            "Preset",
            rect: CGRect(x: 794, y: 126, width: 90, height: 18),
            font: .monospacedSystemFont(ofSize: 11, weight: .bold),
            color: Theme.inkSoft
        )
        pill(label: "Default", rect: CGRect(x: 794, y: 146, width: 78, height: 34), fill: NSColor.white.withAlphaComponent(0.86), stroke: Theme.panelBorder, text: Theme.inkSoft, font: .systemFont(ofSize: 13, weight: .medium))
        pill(label: "Paper", rect: CGRect(x: 880, y: 146, width: 72, height: 34), fill: Theme.emeraldSoft, stroke: Theme.emerald, text: Theme.emerald, font: .systemFont(ofSize: 13, weight: .semibold))
        pill(label: "Cool", rect: CGRect(x: 960, y: 146, width: 62, height: 34), fill: NSColor.white.withAlphaComponent(0.86), stroke: Theme.panelBorder, text: Theme.inkSoft, font: .systemFont(ofSize: 13, weight: .medium))

        drawText(
            "Theme",
            rect: CGRect(x: 794, y: 196, width: 90, height: 18),
            font: .monospacedSystemFont(ofSize: 11, weight: .bold),
            color: Theme.inkSoft
        )
        pill(label: "Light", rect: CGRect(x: 794, y: 216, width: 70, height: 34), fill: Theme.gold.withAlphaComponent(0.22), stroke: Theme.gold, text: Theme.ink, font: .systemFont(ofSize: 13, weight: .semibold))
        pill(label: "Dark", rect: CGRect(x: 872, y: 216, width: 68, height: 34), fill: NSColor.white.withAlphaComponent(0.86), stroke: Theme.panelBorder, text: Theme.inkSoft, font: .systemFont(ofSize: 13, weight: .medium))
        pill(label: "Live", rect: CGRect(x: 952, y: 216, width: 56, height: 34), fill: Theme.emeraldSoft, stroke: Theme.emerald, text: Theme.emerald, font: .systemFont(ofSize: 13, weight: .bold))

        var y: CGFloat = 280
        for row in panelRows {
            drawText(
                row.label,
                rect: CGRect(x: 794, y: y, width: 152, height: 18),
                font: .systemFont(ofSize: 13, weight: .medium),
                color: Theme.ink
            )

            let leftRect = CGRect(x: 948, y: y - 5, width: 52, height: 28)
            let rightRect = CGRect(x: 1008, y: y - 5, width: 52, height: 28)
            drawFill(hexColor(row.lightHex), rect: leftRect, radius: 8)
            drawStroke(Theme.panelBorder, rect: leftRect, radius: 8)
            drawFill(hexColor(row.darkHex), rect: rightRect, radius: 8)
            drawStroke(Theme.panelBorder, rect: rightRect, radius: 8)

            drawText(
                row.lightHex.uppercased(),
                rect: CGRect(x: 946, y: y + 26, width: 58, height: 18),
                font: .monospacedSystemFont(ofSize: 10, weight: .regular),
                color: Theme.inkSoft,
                alignment: .center
            )
            drawText(
                row.darkHex.uppercased(),
                rect: CGRect(x: 1006, y: y + 26, width: 58, height: 18),
                font: .monospacedSystemFont(ofSize: 10, weight: .regular),
                color: Theme.inkSoft,
                alignment: .center
            )

            drawFill(Theme.line.withAlphaComponent(0.5), rect: CGRect(x: 794, y: y + 54, width: 266, height: 1))
            y += 76
        }

        pill(
            label: "Restore Defaults",
            rect: CGRect(x: 794, y: 622, width: 128, height: 34),
            fill: NSColor.white.withAlphaComponent(0.88),
            stroke: Theme.panelBorder,
            text: Theme.inkSoft,
            font: .systemFont(ofSize: 13, weight: .medium)
        )
        pill(
            label: "Preview tuned for READMEs",
            rect: CGRect(x: 934, y: 622, width: 128, height: 34),
            fill: Theme.gold.withAlphaComponent(0.18),
            stroke: Theme.gold.withAlphaComponent(0.72),
            text: Theme.ink,
            font: .systemFont(ofSize: 11, weight: .semibold),
            radius: 17
        )
    }
}

func buildReleaseProofGrid(light: NSImage, dark: NSImage, appearance: NSImage, icon: NSImage) -> NSImage {
    image(CGSize(width: 1600, height: 900)) {
        let fullRect = CGRect(x: 0, y: 0, width: 1600, height: 900)
        if let gradient = NSGradient(colors: [Theme.paper, NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.82, alpha: 1)]) {
            gradient.draw(in: fullRect, angle: 90)
        }
        drawGlow(CGRect(x: -80, y: -140, width: 460, height: 460), color: Theme.spotlightA)
        drawGlow(CGRect(x: 1180, y: 520, width: 420, height: 420), color: Theme.spotlightB)

        drawFill(NSColor.white.withAlphaComponent(0.72), rect: CGRect(x: 72, y: 58, width: 184, height: 48), radius: 24)
        drawStroke(Theme.line, rect: CGRect(x: 72, y: 58, width: 184, height: 48), radius: 24)
        drawImage(icon, in: CGRect(x: 86, y: 69, width: 26, height: 26))
        drawText("CLEANMD PROOF SET", rect: CGRect(x: 122, y: 72, width: 118, height: 18), font: .monospacedSystemFont(ofSize: 11, weight: .bold), color: Theme.inkSoft)

        drawText(
            "Three real UI proofs before a narrow launch.",
            rect: CGRect(x: 72, y: 134, width: 920, height: 70),
            font: .systemFont(ofSize: 44, weight: .bold),
            color: Theme.ink
        )
        drawText(
            "Website, README, release page, and `r/macapps` can now reuse the same screenshot set and a short proof demo without changing the approved launch message.",
            rect: CGRect(x: 72, y: 210, width: 980, height: 48),
            font: .systemFont(ofSize: 20, weight: .regular),
            color: Theme.inkSoft
        )

        drawCard(
            image: light,
            rect: CGRect(x: 72, y: 292, width: 468, height: 530),
            eyebrow: "Hero proof",
            title: "Native split-view Markdown editing",
            body: "Use the light-mode window where folder tree, source, and rendered preview all read in one glance."
        )
        drawCard(
            image: dark,
            rect: CGRect(x: 566, y: 292, width: 468, height: 530),
            eyebrow: "Technical proof",
            title: "Code, tables, and math stay legible",
            body: "Keep the dark-mode document for README, docs, and release-note workflows that need rendered verification."
        )
        drawCard(
            image: appearance,
            rect: CGRect(x: 1060, y: 292, width: 468, height: 530),
            eyebrow: "Native polish",
            title: "Appearance controls show product care",
            body: "The inspector shot gives launch surfaces a native-workspace detail that differentiates CleanMD from a plain editor canvas."
        )
    }
}

func buildRedditProofGrid(light: NSImage, dark: NSImage, appearance: NSImage, icon: NSImage) -> NSImage {
    image(CGSize(width: 1440, height: 1440)) {
        let fullRect = CGRect(x: 0, y: 0, width: 1440, height: 1440)
        if let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.89, alpha: 1),
            NSColor(calibratedRed: 0.92, green: 0.89, blue: 0.84, alpha: 1)
        ]) {
            gradient.draw(in: fullRect, angle: 90)
        }

        drawGlow(CGRect(x: -60, y: 20, width: 400, height: 400), color: Theme.spotlightA)
        drawGlow(CGRect(x: 1080, y: 920, width: 380, height: 380), color: Theme.spotlightB)

        drawFill(NSColor.white.withAlphaComponent(0.78), rect: CGRect(x: 64, y: 60, width: 168, height: 46), radius: 23)
        drawStroke(Theme.line, rect: CGRect(x: 64, y: 60, width: 168, height: 46), radius: 23)
        drawImage(icon, in: CGRect(x: 78, y: 70, width: 24, height: 24))
        drawText("R/MACAPPS KIT", rect: CGRect(x: 112, y: 74, width: 110, height: 16), font: .monospacedSystemFont(ofSize: 11, weight: .bold), color: Theme.inkSoft)

        drawText(
            "Show the app before asking for trust.",
            rect: CGRect(x: 64, y: 134, width: 980, height: 66),
            font: .systemFont(ofSize: 46, weight: .bold),
            color: Theme.ink
        )
        drawText(
            "This square proof sheet gives a founder post three visible reasons to click before the install caveat and GitHub release link.",
            rect: CGRect(x: 64, y: 208, width: 980, height: 52),
            font: .systemFont(ofSize: 20, weight: .regular),
            color: Theme.inkSoft
        )

        drawCard(
            image: light,
            rect: CGRect(x: 64, y: 320, width: 634, height: 470),
            eyebrow: "Local files",
            title: "Open a folder and work",
            body: "Lead with the screenshot that proves the repo-and-docs workflow immediately."
        )
        drawCard(
            image: dark,
            rect: CGRect(x: 742, y: 320, width: 634, height: 470),
            eyebrow: "Technical docs",
            title: "Verify tables, code, and math",
            body: "Use the darker frame when commenters ask whether CleanMD holds up for real technical Markdown."
        )
        drawCard(
            image: appearance,
            rect: CGRect(x: 64, y: 840, width: 1312, height: 500),
            eyebrow: "Native polish",
            title: "Use the inspector shot as the differentiator",
            body: "The appearance panel lands the “native Mac workspace” argument faster than a long feature list."
        )
    }
}

func drawCallout(_ rect: CGRect, title: String, body: String) {
    shadow(.init(width: 0, height: 12), blur: 22, color: NSColor(calibratedWhite: 0.02, alpha: 0.24)).set()
    drawFill(NSColor.white.withAlphaComponent(0.92), rect: rect, radius: 18)
    drawStroke(NSColor.white.withAlphaComponent(0.75), rect: rect, radius: 18)
    drawText(title, rect: CGRect(x: rect.minX + 18, y: rect.minY + 14, width: rect.width - 36, height: 28), font: .systemFont(ofSize: 19, weight: .semibold), color: Theme.ink)
    drawText(body, rect: CGRect(x: rect.minX + 18, y: rect.minY + 46, width: rect.width - 36, height: rect.height - 60), font: .systemFont(ofSize: 14, weight: .regular), color: Theme.inkSoft)
}

func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = 4
    color.setStroke()
    path.stroke()

    let angle = atan2(end.y - start.y, end.x - start.x)
    let arrowSize: CGFloat = 14
    let left = CGPoint(x: end.x - cos(angle - .pi / 6) * arrowSize, y: end.y - sin(angle - .pi / 6) * arrowSize)
    let right = CGPoint(x: end.x - cos(angle + .pi / 6) * arrowSize, y: end.y - sin(angle + .pi / 6) * arrowSize)
    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: left)
    head.move(to: end)
    head.line(to: right)
    head.lineWidth = 4
    head.stroke()
}

func drawAnnotationBox(_ rect: CGRect, color: NSColor) {
    drawFill(color.withAlphaComponent(0.12), rect: rect, radius: 12)
    drawStroke(color.withAlphaComponent(0.65), rect: rect, radius: 12, width: 2)
}

func buildAnnotatedScene(base: NSImage, step: String, title: String, body: String, annotations: () -> Void = {}) -> NSImage {
    image(CGSize(width: 1100, height: 720)) {
        drawImage(base, in: CGRect(x: 0, y: 0, width: 1100, height: 720))
        annotations()
        pill(label: step, rect: CGRect(x: 38, y: 34, width: 94, height: 34), fill: Theme.emeraldSoft, stroke: Theme.emerald, text: Theme.emerald, font: .systemFont(ofSize: 13, weight: .bold))
        drawCallout(CGRect(x: 38, y: 82, width: 400, height: 124), title: title, body: body)
    }
}

func buildDemoEndCard(icon: NSImage) -> NSImage {
    image(CGSize(width: 1100, height: 720)) {
        let fullRect = CGRect(x: 0, y: 0, width: 1100, height: 720)
        if let gradient = NSGradient(colors: [Theme.paper, NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.84, alpha: 1)]) {
            gradient.draw(in: fullRect, angle: 90)
        }
        drawGlow(CGRect(x: -60, y: -20, width: 360, height: 360), color: Theme.spotlightA)
        drawGlow(CGRect(x: 760, y: 360, width: 320, height: 320), color: Theme.spotlightB)

        drawImage(icon, in: CGRect(x: 92, y: 96, width: 72, height: 72))
        drawText("CleanMD", rect: CGRect(x: 182, y: 106, width: 220, height: 38), font: .systemFont(ofSize: 32, weight: .bold), color: Theme.ink)
        drawText("End the demo where launch traffic actually lands.", rect: CGRect(x: 92, y: 188, width: 820, height: 64), font: .systemFont(ofSize: 42, weight: .bold), color: Theme.ink)
        drawText("The website overview, tracked download route, and GitHub release page now have matching proof assets and install-trust copy.", rect: CGRect(x: 92, y: 264, width: 720, height: 56), font: .systemFont(ofSize: 21, weight: .regular), color: Theme.inkSoft)

        pill(label: "Website overview", rect: CGRect(x: 92, y: 364, width: 220, height: 48), fill: Theme.emerald, stroke: Theme.emerald, text: .white, font: .systemFont(ofSize: 17, weight: .semibold))
        pill(label: "GitHub Releases", rect: CGRect(x: 328, y: 364, width: 208, height: 48), fill: NSColor.white.withAlphaComponent(0.88), stroke: Theme.panelBorder, text: Theme.inkSoft, font: .systemFont(ofSize: 17, weight: .medium))
        pill(label: "Gatekeeper steps are spelled out", rect: CGRect(x: 92, y: 434, width: 286, height: 40), fill: Theme.gold.withAlphaComponent(0.18), stroke: Theme.gold.withAlphaComponent(0.72), text: Theme.ink, font: .systemFont(ofSize: 14, weight: .semibold), radius: 20)

        drawText("hosioobo.github.io/CleanMD", rect: CGRect(x: 92, y: 514, width: 300, height: 24), font: .monospacedSystemFont(ofSize: 15, weight: .medium), color: Theme.emerald)
        drawText("github.com/hosioobo/CleanMD/releases/latest", rect: CGRect(x: 92, y: 548, width: 520, height: 24), font: .monospacedSystemFont(ofSize: 15, weight: .medium), color: Theme.inkSoft)
    }
}

func saveScene(_ image: NSImage, name: String) throws {
    let url = framesDirectory.appendingPathComponent(name)
    try writePNG(image, to: url)
}

do {
    try ensureDirectory(docsScreenshotsDirectory)
    try ensureDirectory(launchAssetsDirectory)
    try ensureDirectory(demoAssetsDirectory)
    try ensureDirectory(framesDirectory)

    let light = try loadImage(lightScreenshotURL)
    let dark = try loadImage(darkScreenshotURL)
    let icon = try loadImage(brandIconURL)

    let appearance = buildAppearanceScreenshot(base: light)
    try writePNG(appearance, to: appearanceScreenshotURL)
    try writePNG(appearance, to: docsAppearanceScreenshotURL)

    let releaseGrid = buildReleaseProofGrid(light: light, dark: dark, appearance: appearance, icon: icon)
    try writePNG(releaseGrid, to: releaseProofGridURL)
    try writePNG(releaseGrid, to: demoPosterURL)

    let redditGrid = buildRedditProofGrid(light: light, dark: dark, appearance: appearance, icon: icon)
    try writePNG(redditGrid, to: redditProofGridURL)

    let scene1 = buildAnnotatedScene(
        base: light,
        step: "Step 1",
        title: "Open a local folder",
        body: "Lead with the repo-and-docs workflow. The sidebar, source, and rendered preview all stay visible."
    )
    let scene2 = buildAnnotatedScene(
        base: dark,
        step: "Step 2",
        title: "Jump between Markdown files",
        body: "Use a second screenshot to imply fast navigation across project docs without leaving the workspace."
    ) {
        drawAnnotationBox(CGRect(x: 26, y: 94, width: 214, height: 574), color: Theme.emerald)
    }
    let scene3 = buildAnnotatedScene(
        base: light,
        step: "Step 3",
        title: "Edit once, verify immediately",
        body: "Highlight the editor and rendered pane together so the preview-update promise reads in a single frame."
    ) {
        drawAnnotationBox(CGRect(x: 290, y: 110, width: 260, height: 500), color: Theme.gold)
        drawAnnotationBox(CGRect(x: 574, y: 110, width: 482, height: 500), color: Theme.emerald)
        drawArrow(from: CGPoint(x: 550, y: 340), to: CGPoint(x: 610, y: 340), color: Theme.emerald)
    }
    let scene4 = buildAnnotatedScene(
        base: dark,
        step: "Step 4",
        title: "Keep scroll sync on",
        body: "A short caption plus paired arrows is enough to communicate the review behavior without building a heavier recording rig."
    ) {
        drawArrow(from: CGPoint(x: 452, y: 220), to: CGPoint(x: 452, y: 520), color: Theme.gold)
        drawArrow(from: CGPoint(x: 810, y: 220), to: CGPoint(x: 810, y: 520), color: Theme.gold)
    }
    let scene5 = buildAnnotatedScene(
        base: appearance,
        step: "Step 5",
        title: "Open the appearance inspector",
        body: "This frame gives launch copy a native-workspace proof point instead of another generic editor screenshot."
    )
    let scene6 = buildDemoEndCard(icon: icon)

    try saveScene(scene1, name: "scene-1.png")
    try saveScene(scene2, name: "scene-2.png")
    try saveScene(scene3, name: "scene-3.png")
    try saveScene(scene4, name: "scene-4.png")
    try saveScene(scene5, name: "scene-5.png")
    try saveScene(scene6, name: "scene-6.png")

    let outputs = [
        appearanceScreenshotURL.path,
        docsAppearanceScreenshotURL.path,
        releaseProofGridURL.path,
        redditProofGridURL.path,
        demoPosterURL.path
    ]

    for path in outputs {
        print(path)
    }
} catch {
    fputs("build-launch-assets.swift failed: \(error)\n", stderr)
    exit(1)
}
