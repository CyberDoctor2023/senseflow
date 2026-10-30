import SwiftUI
import AppKit

/// Expands a visual shell around a stable layout slot without shifting its center.
enum CardVisualGeometry {
    static func frame(slot: CGRect, scale: CGFloat) -> CGRect {
        slot.insetBy(dx: -slot.width * (scale - 1) / 2,
                     dy: -slot.height * (scale - 1) / 2)
    }
}
