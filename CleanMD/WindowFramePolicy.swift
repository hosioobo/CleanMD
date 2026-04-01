import CoreGraphics
import Foundation

enum WindowFramePolicy {
    static let defaultSize = CGSize(width: 1100, height: 720)
    static let cascadeOffset = CGSize(width: 28, height: 28)
    static let minimumSavedSize = CGSize(width: 300, height: 240)

    static func placementFrame(
        savedFrame: CGRect?,
        visibleFrame: CGRect?,
        existingWindowCount: Int
    ) -> CGRect {
        let baseFrame = isValidSavedFrame(savedFrame)
            ? savedFrame!
            : defaultFrame(in: visibleFrame)

        let steps = max(0, existingWindowCount)
        var frame = baseFrame.offsetBy(
            dx: CGFloat(steps) * cascadeOffset.width,
            dy: -CGFloat(steps) * cascadeOffset.height
        )

        if let visibleFrame {
            frame = clamped(frame, to: visibleFrame)
        }

        return frame
    }

    static func defaultFrame(in visibleFrame: CGRect?) -> CGRect {
        guard let visibleFrame else {
            return CGRect(origin: .zero, size: defaultSize)
        }

        return CGRect(
            x: visibleFrame.midX - (defaultSize.width / 2),
            y: visibleFrame.midY - (defaultSize.height / 2),
            width: defaultSize.width,
            height: defaultSize.height
        )
    }

    static func isValidSavedFrame(_ frame: CGRect?) -> Bool {
        guard let frame else { return false }
        return frame.width > minimumSavedSize.width && frame.height > minimumSavedSize.height
    }

    static func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        var clamped = frame
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - frame.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - frame.height)

        clamped.origin.x = min(max(frame.origin.x, visibleFrame.minX), maxX)
        clamped.origin.y = min(max(frame.origin.y, visibleFrame.minY), maxY)
        return clamped
    }
}
