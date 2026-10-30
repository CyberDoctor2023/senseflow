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
        tour.historyScrolled(by: 40)
        tour.historyScrolled(by: -40)
        try await Task.sleep(for: .milliseconds(1700))
        try require(tour.step == .preview, "native history survives both delayed scrolling instructions")
        guard let article = session.historyModel.items.first(where: { ($0.textContent?.count ?? 0) > 500 }) else { throw Failure() }
        let documents = session.historyModel.actions.documents
        let frame = session.historyFrame
        documents.preview(article, anchor: NSRect(x: frame.midX - 120, y: frame.minY + 40, width: 240, height: 240), pinOnOpen: false)
        // Observe the lifecycle event rather than assuming first native layout
        // completes within a fixed sleep on a busy machine.
        for _ in 0..<100 {
            if documents.source?.itemID == article.id && tour.hasPreview { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(documents.source?.itemID == article.id && tour.hasPreview && tour.step == .filters,
                    "native preview feeds actual tutorial progress")
        guard let number = documents.previewWindowNumber,
              let window = NSApp.windows.first(where: { $0.windowNumber == number }),
              let editor = findEditor(window.contentView) else { throw Failure() }
        documents.beginEditing()
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        editor.insertText("\n教程编辑验证", replacementRange: editor.selectedRange())
        documents.save()
        try await Task.sleep(for: .milliseconds(800))
        try require(!documents.isDirty && documents.errorMessage == nil,
                    "tutorial native edit archives a new example without a real database")
        try require(session.historyModel.items.contains { $0.textContent?.hasSuffix("教程编辑验证") == true }
                    && session.historyModel.items.contains { $0.id == article.id }, "tutorial save refreshes examples and preserves original")
        let closed = await documents.prepareToClose()
        try await Task.sleep(for: .milliseconds(800))
        try require(closed && !tour.hasPreview, "native preview closure releases the category instruction")
        try require(session.isHistoryVisible && session.historyFrame == frame,
                    "closing tutorial preview keeps history visible at its original position")
        try require(NSApp.keyWindow?.isVisible == true && NSApp.keyWindow?.windowNumber != number,
                    "closing tutorial preview restores focus to the tutorial workspace")
        documents.preview(article, anchor: NSRect(x: frame.midX - 120, y: frame.minY + 40, width: 240, height: 240), pinOnOpen: false)
        for _ in 0..<100 {
            if documents.source != nil && tour.hasPreview { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(documents.source != nil && tour.hasPreview, "preview reopens before external dismissal")
        session.outsideApplicationActivated()
        try await Task.sleep(for: .milliseconds(800))
        session.outsideApplicationActivated()
        try require(documents.source == nil && !tour.hasPreview && tour.step == .filters
                    && session.isHistoryVisible && session.historyFrame == frame,
                    "outside activation closes only preview and repeated notifications retain tutorial history")
        await session.historyModel.selectType(.text)
        tour.categorySelected()
        try await Task.sleep(for: .milliseconds(1700))
        try require(tour.step == .finished && session.historyModel.items.allSatisfy { $0.type == .text },
                    "tutorial filtering uses the shared history model")
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
        print("PASS: native tutorial lifecycle, preview, edit/save and filtering; physical input and layout appearance need separate verification")
    }
    static func findEditor(_ view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let editor = view as? NSTextView { return editor }
        return view.subviews.lazy.compactMap { findEditor($0) }.first
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
