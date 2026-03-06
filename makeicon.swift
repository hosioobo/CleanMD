#!/usr/bin/env swift
// makeicon.swift — generates AppIcon.iconset and AppIcon.icns
import AppKit

func drawIcon(pixelSize: Int) -> Data {
    let s = CGFloat(pixelSize)

    let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // Very slight warm-grey background (not pure white, not obviously grey)
        ctx.setFillColor(CGColor(red: 0.969, green: 0.973, blue: 0.980, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

        // *# in monospaced bold — pure black, no other colour
        let fontSize = s * 0.50
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        // Nudge * downward to optically align with # (asterisk sits high by default)
        let asteriskAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .baselineOffset: -fontSize * 0.08
        ]
        let hashAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let full = NSMutableAttributedString()
        full.append(NSAttributedString(string: "*", attributes: asteriskAttrs))
        full.append(NSAttributedString(string: "#", attributes: hashAttrs))

        let textSize = full.size()
        let x = (s - textSize.width)  / 2
        let y = (s - textSize.height) / 2

        full.draw(at: NSPoint(x: x, y: y))
        return true
    }

    // Render NSImage → bitmap
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: rep.size))
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

let iconSizes: [(pixelSize: Int, name: String)] = [
    (1024, "icon_512x512@2x"),
    (512,  "icon_512x512"),
    (512,  "icon_256x256@2x"),
    (256,  "icon_256x256"),
    (256,  "icon_128x128@2x"),
    (128,  "icon_128x128"),
    (64,   "icon_32x32@2x"),
    (32,   "icon_32x32"),
    (32,   "icon_16x16@2x"),
    (16,   "icon_16x16"),
]

let iconsetURL = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for (px, name) in iconSizes {
    let data = drawIcon(pixelSize: px)
    try! data.write(to: iconsetURL.appendingPathComponent("\(name).png"))
    print("  \(name).png  (\(px)×\(px))")
}
print("Done.")
