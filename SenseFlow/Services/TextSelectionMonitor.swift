//
//  TextSelectionMonitor.swift
//  SenseFlow
//
//  Created on 2026-02-06 for v0.5.0
//  文本选择监听器 - 划词即复制功能
//

import Cocoa
import ApplicationServices

/// 文本选择监听器（单例）
class TextSelectionMonitor {

    // MARK: - Singleton

    static let shared = TextSelectionMonitor()

    // MARK: - Properties

    private var eventMonitor: Any?
    private var isMonitoring: Bool = false
    private let debounceDelay: TimeInterval = BusinessRules.Performance.textSelectionDebounce

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 开始监听文本选择
    func startMonitoring() {
        guard !isMonitoring else { return }

        // 监听全局鼠标释放事件
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleMouseUp()
        }

        isMonitoring = true
    }

    /// 停止监听文本选择
    func stopMonitoring() {
        guard isMonitoring else { return }

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        isMonitoring = false
    }

    // MARK: - Private Methods

    /// 处理鼠标释放事件
    private func handleMouseUp() {
        // 延迟 100ms 确保选择操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay) { [weak self] in
            self?.processTextSelection()
        }
    }

    /// 处理文本选择
    private func processTextSelection() {
        // 检查功能开关
        guard isFeatureEnabled() else { return }

        // 获取当前应用信息
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appBundleID = app.bundleIdentifier
        let appName = app.localizedName

        // 使用 ClipboardFilterManager 检查应用过滤
        let filterResult = ClipboardFilterManager.shared.shouldFilter(
            pasteboardTypes: nil,  // 文本选择阶段不检查数据类型
            appBundleID: appBundleID,
            appName: appName
        )

        if filterResult.shouldFilter { return }

        // 先尝试 Accessibility API
        let result = AccessibilityTextExtractor().extractSelectedText()

        // 如果 Accessibility 获取到文本，直接使用
        if let text = result.text, !text.isEmpty {
            // 检查最小文本长度
            let minLength = getMinimumTextLength()
            guard text.count >= minLength else { return }

            copyToClipboard(text)
            return
        }

        // Accessibility 未获取到文本，检查是否应该尝试强制取词
        guard shouldForceExtract(error: result.error) else { return }

        // 尝试强制取词
        let forcedResult = SimulatedCopyTextExtractor().extractSelectedText()
        guard let forcedText = forcedResult.text, !forcedText.isEmpty else { return }

        // 检查最小文本长度
        let minLength = getMinimumTextLength()
        guard forcedText.count >= minLength else { return }

        // 复制到剪贴板
        copyToClipboard(forcedText)
    }

    /// 判断是否应该强制取词
    private func shouldForceExtract(error: AXError) -> Bool {
        // 检查是否开启强制取词
        let forcedExtractionEnabled = UserDefaults.standard.bool(
            forKey: UserDefaultsKeys.textSelectionForcedExtractionEnabled
        )
        guard forcedExtractionEnabled else { return false }

        // 如果错误是 .success，说明 API 正常工作，只是用户没选中文本
        // 不应该强制取词
        if error == .success {
            return false
        }

        // 其他错误（.noValue, .attributeUnsupported, .failure）
        // 说明应用不支持 Accessibility API
        // 应该强制取词
        return true
    }

    /// 复制文本到剪贴板
    private func copyToClipboard(_ text: String) {
        // 暂停 ClipboardMonitor 避免循环捕获
        ClipboardMonitor.shared.ignoreNextChange()

        // 写入剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Settings

    /// 检查功能是否启用
    private func isFeatureEnabled() -> Bool {
        let key = UserDefaultsKeys.textSelectionAutoCopyEnabled

        // 如果键不存在，默认关闭
        if UserDefaults.standard.object(forKey: key) == nil {
            return false
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    /// 获取最小文本长度
    private func getMinimumTextLength() -> Int {
        let value = UserDefaults.standard.integer(forKey: UserDefaultsKeys.textSelectionMinLength)
        return value > 0 ? value : 3  // 默认 3 字符
    }
}
