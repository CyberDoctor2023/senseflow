import Foundation
import AppKit

/// Runs one text tool at a time; failures never replace clipboard content.
actor ExecutePromptTool {
    private let aiTransport: AITransport
    private let clipboardReader: ClipboardReader
    private let clipboardWriter: ClipboardWriter
    private let notificationService: NotificationServiceProtocol
    private var isRunning = false

    init(aiTransport: AITransport, clipboardReader: ClipboardReader,
         clipboardWriter: ClipboardWriter, notificationService: NotificationServiceProtocol) {
        self.aiTransport = aiTransport
        self.clipboardReader = clipboardReader
        self.clipboardWriter = clipboardWriter
        self.notificationService = notificationService
    }

    /// Explicit input enables mouse invocation. Hotkeys use the current clipboard.
    /// Automatic paste is allowed only while the original application remains in front.
    func execute(tool: PromptTool, input explicitInput: String? = nil, autoPaste: Bool = true) async throws -> String {
        guard !isRunning else {
            notificationService.showError(title: tool.name, body: ExecuteToolError.alreadyRunning.localizedDescription)
            throw ExecuteToolError.alreadyRunning
        }
        isRunning = true
        defer { isRunning = false }
        do {
            guard let input = explicitInput ?? clipboardReader.readText(),
                  !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ExecuteToolError.emptyClipboard
            }
            let targetPID = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
            notificationService.showInProgress(title: tool.name, body: "正在处理文字…")
            let response = try await aiTransport.send(AITransportRequest(
                toolName: tool.name, systemPrompt: tool.prompt, userInput: input))
            try Task.checkCancellation()
            guard !response.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AITransportError.invalidResponse
            }
            await clipboardWriter.write(response.content)
            if autoPaste, let targetPID, targetPID != ProcessInfo.processInfo.processIdentifier {
                await MainActor.run {
                    AutoPasteManager.shared.performAutoPaste(delay: 0.15, expectedTargetPID: targetPID)
                }
            }
            notificationService.showSuccess(title: tool.name, body: "已完成并写入剪贴板")
            return response.content
        } catch {
            notificationService.showError(title: tool.name, body: error.localizedDescription)
            throw error
        }
    }
}

enum ExecuteToolError: LocalizedError {
    case emptyClipboard
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .emptyClipboard: return "没有可处理的文字"
        case .alreadyRunning: return "已有工具正在处理，请稍候再试"
        }
    }
}
