import AppKit
import ApplicationServices
import Combine

/// Refreshes accessibility status while the privacy settings page is visible.
@MainActor final class PermissionStatusCoordinator: ObservableObject {
    enum Consumer { case settings }
    struct Snapshot { let accessibilityGranted: Bool }
    static let shared = PermissionStatusCoordinator()
    @Published private(set) var snapshot = Snapshot(accessibilityGranted: AXIsProcessTrusted())
    private var observer: NSObjectProtocol?
    private var subscribers = 0

    func start(consumer: Consumer) {
        subscribers += 1
        refreshNow()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            }
    }
    func stop(consumer: Consumer) {
        subscribers = max(0, subscribers - 1)
        guard subscribers == 0, let observer else { return }
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
    }
    func refreshNow() { snapshot = Snapshot(accessibilityGranted: AXIsProcessTrusted()) }
}
