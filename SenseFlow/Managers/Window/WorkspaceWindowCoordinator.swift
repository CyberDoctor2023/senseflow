import AppKit

/// A native card surface opts into hit testing without exposing its SwiftUI implementation.
@MainActor protocol HistoryCardSurface: AnyObject {}

/// Explicit window membership replaces hardcoded history A/B focus checks.
@MainActor final class WorkspaceWindowCoordinator {
    private let windows = NSHashTable<NSWindow>.weakObjects()
    func register(_ window: NSWindow) { windows.add(window) }
    func contains(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return windows.contains(window)
    }
    /// Distinguishes presses on history cards from presses on the surrounding background.
    func containsCard(in window: NSWindow, at point: NSPoint) -> Bool {
        func contains(_ view: NSView) -> Bool {
            if view is any HistoryCardSurface,
               !view.isHiddenOrHasHiddenAncestor,
               view.visibleRect.contains(view.convert(point, from: nil)) { return true }
            return view.subviews.contains(where: contains)
        }
        guard let root = window.contentView else { return false }
        return contains(root)
    }
    var hasKeyWindow: Bool { contains(NSApp.keyWindow) }
}
