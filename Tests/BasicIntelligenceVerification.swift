import AppKit
import SwiftUI
import SQLite
@testable import SenseFlow

/// Exercises production capture ordering, reversible coverage, and document safety in isolated storage.
@main struct BasicIntelligenceVerification {
    struct Failure: Error { let message: String }
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
        print("PASS \(message)")
    }

    @MainActor private static var verificationWindow: NSWindow?

    @MainActor static func main() {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        Task { @MainActor in
            do {
                try await runVerification()
                if verificationWindow == nil { NSApplication.shared.terminate(nil) }
            } catch {
                print("VERIFICATION FAILED: \(error)")
                exit(1)
            }
        }
        NSApplication.shared.run()
    }

    @MainActor private static func runVerification() async throws {
        let outputDirectory = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
            ?? Bundle.main.bundleURL.deletingLastPathComponent()
        let directory = outputDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "senseflow-verification-\(UUID().uuidString)"
        guard let preferences = UserDefaults(suiteName: suite) else { throw Failure(message: "preferences") }
        defer { preferences.removePersistentDomain(forName: suite) }
        let url = directory.appendingPathComponent("history.sqlite")
        let store = DatabaseManager(databaseURL: url, preferences: preferences)
        let sql = try Connection(url.path)
        var captureDurations: [Double] = []
        func capture(_ text: String, app: String = "Editor", path: String? = "/Applications/Editor.app") async throws {
            let started = ProcessInfo.processInfo.systemUptime
            let success = await withCheckedContinuation { continuation in
                store.enqueueCapture(.init(type: .text, textContent: text, appName: app, appPath: path)) {
                    continuation.resume(returning: $0)
                }
            }
            captureDurations.append((ProcessInfo.processInfo.systemUptime - started) * 1000)
            try require(success, "capture committed")
        }
        func texts() async throws -> [String] {
            try await store.fetchRecentItemsAsync(limit: 200).compactMap(\.textContent)
        }
        func rowID(_ text: String) throws -> Int64 {
            guard let id = try sql.scalar("SELECT id FROM clipboard_history WHERE text_content = ?", text) as? Int64 else {
                throw Failure(message: "missing row")
            }
            return id
        }
        try await capture("默认关闭")
        try await capture("默认关闭时保留两个片段")
        try require(try await texts().count == 2, "default off retains fragments")
        preferences.set(true, forKey: UserDefaultsKeys.replaceCoveredFragments)
        try await capture("明天下午三点")
        try await capture("明天下午三点开会")
        try await capture("请大家明天下午三点开会，谢谢。")
        var visible = try await texts()
        try require(!visible.contains("明天下午三点") && !visible.contains("明天下午三点开会"), "exact coverage flattens a chain")
        try require(visible.contains("请大家明天下午三点开会，谢谢。"), "complete original stays unchanged")
        let originalID = try rowID("明天下午三点")
        let original = try store.loadHistoryDetail(itemID: originalID, revision: "明天下午三点".sha256())
        try require(original.textContent == "明天下午三点", "covered original remains loadable")
        let page = try await store.searchItemsAsync(query: "明天", limit: 1, offset: 0)
        let next = try await store.searchItemsAsync(query: "明天", limit: 1, offset: 1)
        try require(page.count == 1 && next.isEmpty, "search coverage precedes pagination")
        preferences.set(false, forKey: UserDefaultsKeys.replaceCoveredFragments)
        visible = try await texts()
        try require(visible.contains("明天下午三点") && visible.contains("明天下午三点开会"), "disable restores originals")
        preferences.set(true, forKey: UserDefaultsKeys.replaceCoveredFragments)
        store.deleteItem(id: try rowID("请大家明天下午三点开会，谢谢。"))
        visible = try await texts()
        try require(visible.contains("明天下午三点") && visible.contains("明天下午三点开会"), "delete complete reveals all chain fragments")
        try await capture("保留来源区别")
        try await capture("保留来源区别以及更多文字", app: "Other", path: "/Applications/Other.app")
        visible = try await texts()
        try require(visible.contains("保留来源区别"), "different applications remain separate")
        try await capture("近似文本不会折叠")
        try await capture("近似文本不能折叠，还有后续。")
        visible = try await texts()
        try require(visible.contains("近似文本不会折叠"), "similar text does not count as exact coverage")
        try await capture("草稿保护内容")
        let draftID = try rowID("草稿保护内容")
        let source = DocumentSnapshot(itemID: draftID, revision: "草稿保护内容".sha256(), text: "草稿保护内容",
                                      appName: "Editor", appPath: "/Applications/Editor.app", timestamp: 0)
        try store.checkpointDocumentDraft(.init(sessionID: UUID(), source: source, generation: 1, text: "正在编辑的草稿"))
        try await capture("草稿保护内容及其后续")
        visible = try await texts()
        try require(visible.contains("草稿保护内容"), "draft source stays visible")
        try require(try store.recoverDocumentDraft(sourceID: draftID)?.text == "正在编辑的草稿", "draft content survives coverage")
        try await capture("重新复制片段")
        try await capture("重新复制片段后面的完整内容")
        try await capture("重新复制片段")
        visible = try await texts()
        try require(visible.contains("重新复制片段"), "explicit recopy restores a fragment")
        try await capture("事务失败保护")
        try sql.run("CREATE TRIGGER fail_coverage BEFORE INSERT ON fragment_coverage BEGIN SELECT RAISE(ABORT, 'verification'); END")
        let success = await withCheckedContinuation { continuation in
            store.enqueueCapture(.init(type: .text, textContent: "事务失败保护的完整片段", appName: "Editor", appPath: "/Applications/Editor.app")) {
                continuation.resume(returning: $0)
            }
        }
        try require(!success, "coverage failure reported")
        try require((try sql.scalar("SELECT COUNT(*) FROM clipboard_history WHERE text_content = '事务失败保护的完整片段'") as? Int64) == 0,
                    "failed transaction rolls back new record")
        visible = try await texts()
        try require(visible.contains("事务失败保护"), "failed transaction preserves original")
        try sql.run("DROP TRIGGER fail_coverage")
        try await capture("已保存版本保护")
        let savedID = try rowID("已保存版本保护")
        let savedSource = DocumentSnapshot(itemID: savedID, revision: "已保存版本保护".sha256(), text: "已保存版本保护",
                                           appName: "Editor", appPath: "/Applications/Editor.app", timestamp: 0)
        let derivedID = try store.saveDocumentVersion(text: "独立编辑后的版本", source: savedSource, requestID: UUID())
        try await capture("已保存版本保护的完整文本")
        try await capture("独立编辑后的版本及其完整内容")
        visible = try await texts()
        try require(visible.contains("已保存版本保护") && visible.contains("独立编辑后的版本"), "saved version and its source stay visible")
        try require(derivedID != savedID, "derived version preserves identity")
        try await capture("超长正文边界")
        let longText = "超长正文边界" + String(repeating: "正文", count: 40000)
        try await capture(longText)
        visible = try await texts()
        try require(visible.contains("超长正文边界"), "oversized document skips bounded coverage work")
        try require(try store.loadHistoryDetail(itemID: rowID(longText), revision: longText.sha256()).textContent == longText,
                    "large original persists in full")
        try await capture("未知来源保护", app: "未知", path: nil)
        try await capture("未知来源保护的完整文本", app: "未知", path: nil)
        visible = try await texts()
        try require(visible.contains("未知来源保护"), "unknown source is excluded from coverage")
        let sortedDurations = captureDurations.sorted()
        print("MEASUREMENT capture n=\(sortedDurations.count) median_ms=\(sortedDurations[sortedDurations.count / 2]) max_ms=\(sortedDurations.last ?? 0)")
        if CommandLine.arguments.contains("--extended") {
            try await capture("时间边界片段")
            print("WAITING real 121 second expiration boundary")
            try await Task.sleep(for: .seconds(121))
            try await capture("时间边界片段以及完整后续")
            visible = try await texts()
            try require(visible.contains("时间边界片段"), "expired candidates stay visible after a real 121 second interval")
        }
        let reopened = DatabaseManager(databaseURL: url, preferences: preferences)
        let persisted = try await reopened.fetchRecentItemsAsync(limit: 200)
        try require(persisted.contains { $0.textContent == "重新复制片段" }, "visibility survives database reopen")
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("migration-backups").path)
        try require(backups.contains { $0.hasPrefix("before-fragment-coverage-") }, "pre-change backup exists")
        if CommandLine.arguments.contains("--ui") || CommandLine.arguments.count == 1 {
            NSApplication.shared.setActivationPolicy(.regular)
            let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 850, height: 620),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "SenseFlow 基础智能验证"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView().environment(SettingsModel()))
            verificationWindow = window
            window.makeKeyAndOrderFront(nil)
            print("UI_READY window=\(window.windowNumber)")
            Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { _ in
                print("UI_FINISHED")
                NSApplication.shared.terminate(nil)
            }
        }
        print("ALL CHECKS PASSED")
    }
}
