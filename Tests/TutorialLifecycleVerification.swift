import AppKit
@testable import SenseFlow

/// Runs the real tutorial workspace lifecycle with isolated progress and no external writes.
@main struct TutorialLifecycleVerification {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        Task { @MainActor in
            do { try await verify(); exit(0) }
            catch { print("FAIL: \(error)"); exit(1) }
        }
        app.run()
    }
    @MainActor static func verify() async throws {
        setbuf(stdout, nil)
        let suite = "top.senseflow.verification.tutorial.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw Failure() }
        defer { defaults.removePersistentDomain(forName: suite) }
        let tour = ClipboardOnboardingCoordinator(defaults: defaults)
        let writer = IsolatedWriter()
        var pasteCalls = 0
        let session = ClipboardTutorialSession(tour: tour, writer: writer, onPaste: { pasteCalls += 1 })
        session.show()
        try await Task.sleep(for: .milliseconds(450))
        try require(session.isVisible, "launch instruction visible")
        session.hide()
        try require(!session.isVisible, "launch instruction hides")
        tour.launchRequested()
        session.show()
        try await Task.sleep(for: .milliseconds(700))
        try require(session.isHistoryVisible && !session.historyModel.items.isEmpty, "real tutorial window loads example history")
        try require(session.historyFrame.width > 0 && session.historyFrame.height > 0, "tutorial has a valid native frame")
        session.hide()
        try await Task.sleep(for: .milliseconds(700))
        try require(!session.isVisible && !session.isHistoryVisible, "native history dismissal settles")
        session.show()
        try await Task.sleep(for: .milliseconds(700))
        try require(session.isHistoryVisible, "dismissed tutorial can reopen")
        session.close()
        session.show()
        try require(!session.isVisible && !session.isHistoryVisible, "closed session cannot revive")
        let writes = await writer.count
        try require(writes == 0 && pasteCalls == 0, "lifecycle does not write clipboard or paste into another app")
        print("PASS: native tutorial lifecycle; gesture, long-press and layout appearance need separate verification")
    }
    static func require(_ value: Bool, _ message: String) throws {
        guard value else { print("FAIL: \(message)"); throw Failure() }
        print("PASS: \(message)")
    }
    struct Failure: Error {}
    actor IsolatedWriter: ClipboardWriter {
        private(set) var count = 0
        func write(_ text: String) async { count += 1 }
        func write(_ content: ClipboardContent) async { count += 1 }
    }
}
