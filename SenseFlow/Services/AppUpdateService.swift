import Combine
import Sparkle
import SwiftUI

/// Owns the application updater; Sparkle handles scheduling, signing and installation.
@MainActor
final class AppUpdateService: NSObject, ObservableObject, @preconcurrency SPUStandardUserDriverDelegate {
    static let shared = AppUpdateService()
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var availableVersion: String?
    private var activationObserver: AnyCancellable?
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self
    )

    private override init() {
        super.init()
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$automaticallyChecksForUpdates)
        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.availableVersion != nil else { return }
                self.checkForUpdates()
            }
    }

    /// Starts Sparkle after the app's startup configuration has been registered.
    func start() {
        // Earlier builds forced checks off on every launch. Migrate once, then respect user choice.
        let migrationKey = "scheduledUpdateChecksMigrationV1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            controller.updater.automaticallyChecksForUpdates = true
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
        controller.updater.automaticallyDownloadsUpdates = false
        controller.startUpdater()
        if controller.updater.automaticallyChecksForUpdates {
            controller.updater.checkForUpdatesInBackground()
        }
    }

    /// Stores the user's scheduling preference through Sparkle's own settings.
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    /// Presents Sparkle's standard update UI, including recoverable network errors.
    func checkForUpdates() { controller.checkForUpdates(nil) }

    /// Background menu-bar apps retain a visible reminder until the user returns.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool { immediateFocus }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        availableVersion = update.displayVersionString
        if NSApp.isActive {
            DispatchQueue.main.async { [weak self] in self?.checkForUpdates() }
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() { availableVersion = nil }
}

struct AppUpdateSettingsView: View {
    @ObservedObject private var service = AppUpdateService.shared

    var body: some View {
        SettingsSection(title: "软件更新") {
            Text("当前版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                .font(.pingFang(.caption)).foregroundStyle(.secondary)
            Toggle("自动检查更新", isOn: Binding(
                get: { service.automaticallyChecksForUpdates },
                set: { service.setAutomaticallyChecksForUpdates($0) }
            ))
            Text("启动时及每天检查，有新版本时提醒。")
                .font(.pingFang(.caption)).foregroundStyle(.secondary)
            if let version = service.availableVersion {
                Text("发现新版本 \(version)")
            }
            Button("检查更新", action: service.checkForUpdates)
                .disabled(!service.canCheckForUpdates)
        }
    }
}
