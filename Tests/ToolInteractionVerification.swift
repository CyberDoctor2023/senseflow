import Foundation
import AppKit
import Carbon
@testable import SenseFlow

@main struct ToolInteractionVerification {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let pasteboard = NSPasteboard(name: .init("senseflow-verification-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("internal history selection", forType: .string)
        monitor.acknowledgeInternalWrite()
        for _ in 0..<3 {
            try require(!monitor.pasteboardDidChange(), "internal selection must not reappear on a later poll")
        }
        pasteboard.clearContents()
        pasteboard.setString("external copy", forType: .string)
        try require(monitor.pasteboardDidChange(), "external copy after an internal write must be observed")
        try require(!monitor.pasteboardDidChange(), "external copy is consumed exactly once")

        let transport = ControlledTransport()
        let writer = CapturingWriter()
        let notifications = CapturingNotifications()
        let runner = ExecutePromptTool(aiTransport: transport, clipboardReader: Reader(),
                                       clipboardWriter: writer, notificationService: notifications)
        let tool = PromptTool(name: "isolated tool", prompt: "retain facts")
        let first = Task { try await runner.execute(tool: tool, input: "explicit source", autoPaste: false) }
        while !(await transport.started) { await Task.yield() }
        do {
            _ = try await runner.execute(tool: tool, input: "competing source", autoPaste: false)
            throw Failure("concurrent invocation should fail")
        } catch ExecuteToolError.alreadyRunning {}
        await transport.finish(content: "processed source")
        let result = try await first.value
        let writes = await writer.values
        try require(result == "processed source" && writes == [result], "only the accepted request writes its result")
        let input = await transport.input
        try require(input == "explicit source", "mouse invocation processes displayed input, not stale clipboard")

        await transport.setFailure()
        do {
            _ = try await runner.execute(tool: tool, input: "failure source", autoPaste: false)
            throw Failure("transport failure should propagate")
        } catch AITransportError.invalidResponse {}
        let afterFailure = await writer.values
        try require(afterFailure == writes, "failed transport preserves clipboard output")
        try require(notifications.errors.count == 2, "busy and failed requests both report an error")
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = SQLitePromptToolRepository(databaseManager: DatabaseManager(databaseURL: directory.appendingPathComponent("tools.sqlite")))
        let bindings = RejectingHotKeys()
        let coordinator = PromptToolCoordinator(repository: repository, executeToolUseCase: runner, hotKeyCoordinator: bindings)
        var original = PromptTool(name: "rollback", prompt: "retain", shortcutKeyCode: 18,
                                  shortcutModifiers: UInt32(cmdKey | controlKey))
        try await coordinator.createTool(original)
        var conflicting = original
        conflicting.shortcutKeyCode = 19
        do {
            try await coordinator.updateTool(conflicting)
            throw Failure("conflicting shortcut should not save")
        } catch RejectingHotKeys.Failure.conflict {}
        let restored = try await repository.find(by: original.toolID)
        try require(restored?.shortcutKeyCode == 18 && bindings.registered == 18,
                    "failed shortcut update restores persisted value and old binding")
        original.shortcutKeyCode = 0
        try await coordinator.updateTool(original)
        let savedA = try await repository.find(by: original.toolID)
        try require(savedA?.hasShortcut == true && savedA?.keyCombo?.modifiers.contains(.command) == true && bindings.registered == 0,
                    "Command-Control-A retains keycode zero through saving and registration")
        original.shortcutModifiers = 0
        try await coordinator.updateTool(original)
        try require(bindings.registered == nil, "clearing a shortcut unregisters it")
        print("PASS: clipboard revisions, explicit input, concurrent requests, failure feedback, binding rollback and A-key registration")
    }
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(message) }
    }
    struct Failure: Error { let message: String; init(_ message: String) { self.message = message } }
}

private struct Reader: ClipboardReader {
    func readText() -> String? { "stale clipboard" }
    func readContent() -> ClipboardContent { .text("stale clipboard") }
}
private actor CapturingWriter: ClipboardWriter {
    var values: [String] = []
    func write(_ text: String) async { values.append(text) }
    func write(_ content: ClipboardContent) async { if let text = content.asText { values.append(text) } }
}
private final class CapturingNotifications: NotificationServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storedErrors: [String] = []
    var errors: [String] { lock.withLock { storedErrors } }
    func showInProgress(title: String, body: String) {}
    func showSuccess(title: String, body: String) {}
    func showError(title: String, body: String) { lock.withLock { storedErrors.append(body) } }
}
private actor ControlledTransport: AITransport {
    var started = false
    var input: String?
    private var continuation: CheckedContinuation<AITransportResponse, Never>?
    private var fails = false
    func send(_ request: AITransportRequest) async throws -> AITransportResponse {
        if fails { throw AITransportError.invalidResponse }
        input = request.userInput
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            started = true
        }
    }
    func finish(content: String) {
        continuation?.resume(returning: .init(content: content, serviceType: "isolated", modelName: "controlled"))
        continuation = nil
    }
    func setFailure() { fails = true }
}

private final class RejectingHotKeys: PromptToolHotKeyHandling, @unchecked Sendable {
    enum Failure: Error { case conflict }
    var registered: UInt16?
    func registerToolHotKey(for tool: PromptTool, handler: @escaping @Sendable () -> Void) throws {
        if tool.shortcutKeyCode == 19 { throw Failure.conflict }
        registered = tool.hasShortcut ? tool.shortcutKeyCode : nil
    }
    func unregisterToolHotKey(for toolID: ToolID) { registered = nil }
    func unregisterAllToolHotKeys() { registered = nil }
}
