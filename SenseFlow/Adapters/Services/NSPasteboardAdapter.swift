import AppKit

/// Writes history selections and acknowledges internal changes to prevent duplicate capture.
final class NSPasteboardAdapter: ClipboardWriter {
    private let monitor: ClipboardMonitor
    init(monitor: ClipboardMonitor) { self.monitor = monitor }

    func write(_ text: String) async {
        await MainActor.run {

            // 【步骤 2】获取系统剪贴板
            let pasteboard = NSPasteboard.general

            // 【步骤 3】清空旧内容
            pasteboard.clearContents()

            // 【步骤 4】写入新内容
            pasteboard.setString(text, forType: .string)
            monitor.acknowledgeInternalWrite()
        }
    }

    /// 写入内容（通用）
    ///
    /// 【实现细节】
    /// 根据 ClipboardContent 的类型，调用不同的 NSPasteboard API
    ///
    /// 【模式匹配】
    /// 使用 Swift 的 switch 语句匹配枚举
    /// 这是类型安全的，编译器会检查是否处理了所有情况
    func write(_ content: ClipboardContent) async {
        await MainActor.run {

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            // 【模式匹配】
            // 根据内容类型调用不同的 API
            switch content {
            case .text(let text):
                // 写入文本
                pasteboard.setString(text, forType: .string)

            case .image(let data):
                // 写入图片（TIFF 格式）
                if let image = NSImage(data: data) { pasteboard.writeObjects([image]) }

            case .file(let url):
                // 写入文件 URL
                pasteboard.writeObjects([url as NSURL])

            case .empty:
                // 空内容：不写入任何东西
                break
            }
            monitor.acknowledgeInternalWrite()
        }
    }
}
