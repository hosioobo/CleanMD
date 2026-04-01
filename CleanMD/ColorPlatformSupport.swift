import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        let r = CGFloat((color >> 16) & 0xff) / 255.0
        let g = CGFloat((color >> 8)  & 0xff) / 255.0
        let b = CGFloat(color          & 0xff) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
