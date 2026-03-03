//
//  ClipboardMonitor.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Foundation
import Cocoa
import AppKit

/// 扩展 NSPasteboard.PasteboardType 支持更多图片格式
///
/// 【学习 Deck】
/// 定义自定义类型标识符
extension NSPasteboard.PasteboardType {
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
    static let heic = NSPasteboard.PasteboardType("public.heic")
}

/// 剪贴板监听服务（单例）
class ClipboardMonitor {

    // MARK: - Singleton

    static let shared = ClipboardMonitor()

    // MARK: - Logger

    private let logger = AppLogger.clipboard

    // MARK: - Properties

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var shouldIgnoreNextChange: Bool = false  // 忽略下一次剪贴板变化（用于写入剪贴板时避免循环）

    // MARK: - Initialization

    private init() {
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Public Methods

    /// 开始监听剪贴板
    func startMonitoring() {
        // 停止已有的 timer
        stopMonitoring()

        // 创建新的 timer
        timer = Timer.scheduledTimer(
            timeInterval: BusinessRules.ClipboardMonitor.pollingInterval,
            target: self,
            selector: #selector(checkPasteboard),
            userInfo: nil,
            repeats: true
        )

        // 确保 timer 在所有 run loop 模式下都能运行
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        logger.info("剪贴板监听已启动（轮询间隔: \(BusinessRules.ClipboardMonitor.pollingInterval)秒）")
    }

    /// 停止监听剪贴板
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        logger.info("剪贴板监听已停止")
    }

    /// 忽略下一次剪贴板变化（用于写入剪贴板时避免循环捕获）
    ///
    /// 【设计说明】
    /// 使用标志位而非时间暂停，精确忽略"我们自己触发的"剪贴板变化
    /// 优点：
    /// - ✅ 只忽略下一次变化（精确）
    /// - ✅ 不依赖时间窗口
    /// - ✅ 不会误伤用户的快速操作
    func ignoreNextChange() {
        shouldIgnoreNextChange = true
        logger.debug("标记：忽略下一次剪贴板变化")
    }

    /// 暂停监听（兼容旧接口，内部调用 ignoreNextChange）
    @available(*, deprecated, message: "使用 ignoreNextChange() 替代")
    func pauseMonitoring(duration: TimeInterval = BusinessRules.ClipboardMonitor.defaultPauseDuration) {
        ignoreNextChange()
    }

    // MARK: - Private Methods

    @objc private func checkPasteboard() {
        guard shouldProcessPasteboard() else { return }

        if pasteboardDidChange() {
            processPasteboardContent()
        }
    }

    /// 判断是否应该处理剪贴板
    private func shouldProcessPasteboard() -> Bool {
        // 检查是否需要忽略这次变化
        if shouldIgnoreNextChange {
            shouldIgnoreNextChange = false  // 重置标志
            logger.debug("忽略本次剪贴板变化（自触发）")
            return false
        }
        return true
    }

    /// 检查剪贴板是否发生变化
    private func pasteboardDidChange() -> Bool {
        let currentChangeCount = pasteboard.changeCount
        let hasChanged = currentChangeCount != lastChangeCount

        if hasChanged {
            lastChangeCount = currentChangeCount
        }

        return hasChanged
    }

    /// 支持的剪贴板类型（按优先级排序）
    ///
    /// 【学习 Deck 的方式】
    /// 定义支持的类型列表，按优先级检测
    /// 优先级：图片 > 文件 > 文本
    private static let supportedTypes: [NSPasteboard.PasteboardType] = [
        .png, .tiff, .jpeg, .heic,  // 图片类型
        .fileURL,                    // 文件类型
        .string                      // 文本类型
    ]

    /// 处理剪贴板内容
    ///
    /// 处理剪贴板内容
    /// 流程: 过滤 → 检测类型 → 分发处理
    private func processPasteboardContent() {
        // 步骤 1: 检查是否应该过滤
        if shouldFilterCurrentContent() {
            return
        }

        // 步骤 2: 获取剪贴板项
        guard let item = getPasteboardItem() else {
            return
        }

        // 步骤 3: 检测内容类型
        guard let detectedType = detectContentType(from: item) else {
            return
        }

        // 步骤 4: 处理内容
        processContent(item: item, type: detectedType)
    }

    /// 检查是否应该过滤当前内容
    private func shouldFilterCurrentContent() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        let filterResult = ClipboardFilterManager.shared.shouldFilter(
            pasteboardTypes: pasteboard.types,
            appBundleID: app?.bundleIdentifier,
            appName: app?.localizedName
        )

        if filterResult.shouldFilter {
            if let reason = filterResult.reason {
                logger.warning("过滤原因: \(reason)，跳过保存")
            }
            return true
        }

        return false
    }

    /// 获取剪贴板项
    private func getPasteboardItem() -> NSPasteboardItem? {
        guard let item = pasteboard.pasteboardItems?.first else {
            logger.warning("剪贴板为空")
            return nil
        }

        logger.debug("剪贴板类型: \(item.types.map { $0.rawValue })")
        return item
    }

    /// 检测内容类型
    private func detectContentType(from item: NSPasteboardItem) -> NSPasteboard.PasteboardType? {
        guard let detectedType = Self.supportedTypes.first(where: { item.types.contains($0) }) else {
            logger.warning("不支持的剪贴板类型")
            return nil
        }

        return detectedType
    }

    /// 处理内容（根据类型分发）
    private func processContent(item: NSPasteboardItem, type: NSPasteboard.PasteboardType) {
        let appInfo = getSourceApplicationInfo()

        switch type {
        case .png, .tiff, .jpeg, .heic:
            if let imageData = item.data(forType: type) {
                logger.debug("检测到图片: \(type.rawValue)")
                handleImageData(imageData, appInfo: appInfo)
            }

        case .fileURL:
            if let fileURLs = getFileURLs() {
                logger.debug("检测到文件: \(fileURLs.count) 个")
                handleFileURLs(fileURLs, appInfo: appInfo)
            }

        case .string:
            if let textContent = item.string(forType: .string) {
                logger.debug("检测到文本")
                handleTextContent(textContent, appInfo: appInfo)
            }

        default:
            logger.warning("未处理的类型: \(type.rawValue)")
        }
    }

    // MARK: - Data Extraction

    private func getImageData() -> Data? {
        // 按优先级检查图片类型
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType(BusinessRules.ClipboardMonitor.ImageTypes.jpeg),
            NSPasteboard.PasteboardType(BusinessRules.ClipboardMonitor.ImageTypes.heic)
        ]

        for type in imageTypes {
            if let data = pasteboard.data(forType: type) {
                return data
            }
        }

        return nil
    }

    private func getTextContent() -> String? {
        return pasteboard.string(forType: .string)
    }

    /// 获取文件 URL 列表
    ///
    /// 【实现说明】
    /// 学习 Maccy/Deck 的方式，支持多文件复制
    /// 使用 readObjects 读取 NSURL 对象（而非 string）
    private func getFileURLs() -> [URL]? {
        // 方法 1: 使用 readObjects 读取 URL 对象（推荐）
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            return urls
        }

        // 方法 2: 从 propertyList 读取（兼容某些应用）
        if let urlStrings = pasteboard.propertyList(forType: .fileURL) as? [String] {
            let urls = urlStrings.compactMap { URL(string: $0) }
            if !urls.isEmpty {
                return urls
            }
        }

        // 方法 3: 单个文件的情况
        if let urlString = pasteboard.propertyList(forType: .fileURL) as? String,
           let url = URL(string: urlString) {
            return [url]
        }

        return nil
    }

    private func getSourceApplicationInfo() -> (name: String, path: String?) {
        // 尝试获取来源应用名称和路径
        // 注意: macOS 出于隐私考虑，不总是提供来源应用信息
        if let app = NSWorkspace.shared.frontmostApplication {
            let name = app.localizedName ?? BusinessRules.ClipboardMonitor.unknownAppName
            let path = app.bundleURL?.path
            return (name, path)
        }
        return (BusinessRules.ClipboardMonitor.unknownAppName, nil)
    }

    // MARK: - Data Handling

    private func handleImageData(_ imageData: Data, appInfo: (name: String, path: String?)) {
        guard DatabaseManager.shared.insertItem(type: .image, imageData: imageData, appName: appInfo.name, appPath: appInfo.path) else {
            return
        }

        // 使用 isEnabled 检查避免昂贵的格式化操作
        if logger.isEnabled(.info) {
            let sizeKB = Double(imageData.count) / BusinessRules.DataConversion.bytesPerKilobyte
            logger.info("保存图片: \(String(format: "%.1f", sizeKB)) KB | 来源: \(appInfo.name)")
        }
        notifyClipboardUpdate()
    }

    private func handleTextContent(_ textContent: String, appInfo: (name: String, path: String?)) {
        let trimmedText = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            logger.warning("空白文本，跳过保存")
            return
        }

        guard DatabaseManager.shared.insertItem(type: .text, textContent: textContent, appName: appInfo.name, appPath: appInfo.path) else {
            return
        }

        // 使用 isEnabled 检查避免昂贵的字符串截取操作
        if logger.isEnabled(.info) {
            let preview = trimmedText.prefix(BusinessRules.TextPreview.logPreview)
            logger.info("保存文本: \(preview)... | 来源: \(appInfo.name)")
        }
        notifyClipboardUpdate()
    }

    /// 处理文件 URL 列表
    ///
    /// 【实现说明】
    /// 将文件路径列表转换为文本存储（与 Deck 的方式一致）
    /// 格式：每行一个文件路径
    private func handleFileURLs(_ urls: [URL], appInfo: (name: String, path: String?)) {
        // 将文件路径列表转换为文本（每行一个路径）
        let filePaths = urls.map { $0.path }.joined(separator: "\n")

        guard DatabaseManager.shared.insertItem(type: .text, textContent: filePaths, appName: appInfo.name, appPath: appInfo.path) else {
            return
        }

        // 使用 isEnabled 检查避免昂贵的字符串操作
        if logger.isEnabled(.info) {
            let fileCount = urls.count
            let preview = fileCount == 1 ? urls[0].lastPathComponent : "\(fileCount) 个文件"
            logger.info("保存文件: \(preview) | 来源: \(appInfo.name)")
        }
        notifyClipboardUpdate()
    }

    private func notifyClipboardUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.logger.debug("发送剪贴板更新通知")
            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
        }
    }
}
