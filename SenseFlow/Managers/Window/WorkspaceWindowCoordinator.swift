import AppKit

/// A native card surface opts into hit testing without exposing its SwiftUI implementation.
@MainActor protocol HistoryCardSurface: AnyObject {}

/// A tool surface keeps preview actions inside the shared workspace.
@MainActor protocol HistoryToolSurface: AnyObject {}

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
    func toolSurfaceFrame(in window: NSWindow) -> CGRect? {
        var result: CGRect?
        func visit(_ view: NSView) {
            guard !view.isHiddenOrHasHiddenAncestor else { return }
            if view is any HistoryToolSurface {
                let frame = window.convertToScreen(view.convert(view.bounds, to: nil))
                result = result.map { $0.union(frame) } ?? frame
            }
            view.subviews.forEach(visit)
        }
        if let root = window.contentView { visit(root) }
        return result
    }
    func containsTool(in window: NSWindow, at point: NSPoint) -> Bool {
        func contains(_ view: NSView) -> Bool {
            guard !view.isHiddenOrHasHiddenAncestor else { return false }
            if view is any HistoryToolSurface, view.visibleRect.contains(view.convert(point, from: nil)) { return true }
            return view.subviews.contains(where: contains)
        }
        return window.contentView.map(contains) ?? false
    }
    var hasKeyWindow: Bool { contains(NSApp.keyWindow) }

    /// Hands focus back to a visible workspace surface without activating the app.
    func restoreKeyWindow(excluding closingWindow: NSWindow) {
        guard NSApp.isActive,
              let destination = windows.allObjects.first(where: {
                  $0 !== closingWindow && $0.isVisible && $0.canBecomeKey
              }) else { return }
        destination.makeKey()
    }
}
