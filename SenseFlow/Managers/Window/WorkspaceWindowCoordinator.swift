import AppKit

/// Explicit window membership replaces hardcoded history A/B focus checks.
@MainActor final class WorkspaceWindowCoordinator {
    private let windows = NSHashTable<NSWindow>.weakObjects()
    func register(_ window: NSWindow) { windows.add(window) }
    func contains(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return windows.contains(window)
    }
    var hasKeyWindow: Bool { contains(NSApp.keyWindow) }
}
