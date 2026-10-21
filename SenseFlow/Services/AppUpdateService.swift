import Combine
import Sparkle
import SwiftUI

/// Owns the application updater; Sparkle handles scheduling, signing and installation.
@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()
    @Published private(set) var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Starts Sparkle after the app's startup configuration has been registered.
    func start() {
        // This product offers explicit checks only, including when upgrading older preferences.
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
        controller.startUpdater()
    }

    /// Presents Sparkle's standard update UI, including recoverable network errors.
    func checkForUpdates() { controller.checkForUpdates(nil) }
}

struct AppUpdateSettingsView: View {
    @ObservedObject private var service = AppUpdateService.shared

    var body: some View {
        SettingsSection(title: "软件更新") {
            Text("当前版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                .font(.pingFang(.caption)).foregroundStyle(.secondary)
            Button("检查更新", action: service.checkForUpdates)
                .disabled(!service.canCheckForUpdates)
        }
    }
}
