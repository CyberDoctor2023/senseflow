import AppKit

/// Tracks only session cleanliness. Captured content is never recorded or uploaded.
@MainActor final class SessionDiagnostics {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func beginSession() {
        let previousWasUnclean = defaults.object(forKey: "senseflow.sessionClean") != nil && !defaults.bool(forKey: "senseflow.sessionClean")
        defaults.set(false, forKey: "senseflow.sessionClean")
        guard previousWasUnclean else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let alert = NSAlert()
            alert.messageText = "上次 senseflow 未正常退出"
            alert.informativeText = "已保存的历史和草稿仍保留。你可以继续使用，或打开本机诊断报告查看原因。强制退出也会出现此提示。"
            alert.addButton(withTitle: "继续使用")
            alert.addButton(withTitle: "查看诊断报告")
            if alert.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports"))
            }
        }
    }
    func finishSession() { defaults.set(true, forKey: "senseflow.sessionClean") }
}
