import CoreGraphics
import Foundation

enum AppearanceInspectorLayout {
    static let defaultWidth: CGFloat = 396
    static let minimumWidth: CGFloat = 340

    static func maximumWidth(totalWidth: CGFloat) -> CGFloat {
        max(minimumWidth, min(520, totalWidth * 0.42))
    }

    static func clampedWidth(_ proposedWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth, minimumWidth), maximumWidth(totalWidth: totalWidth))
    }
}
