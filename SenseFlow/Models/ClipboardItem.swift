//
//  ClipboardItem.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Foundation
import AppKit

/// 剪贴板条目数据模型
struct ClipboardItem: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// 唯一标识符
    let id: Int64

    /// 内容唯一 ID (SHA256 hash，用于去重)
    let uniqueId: String

    /// 条目类型
    let type: ClipboardItemType

    /// 文本内容（仅文本类型）
    let textContent: String?

    /// 图片数据（仅图片类型，小于 512KB）
    let imageData: Data?

    /// 大文件路径（图片超过 512KB 时）
    let blobPath: String?

    /// 创建时间戳
    let timestamp: Int64

    /// 来源应用名称
    let appName: String

    /// 来源应用路径（用于获取图标）
    let appPath: String?

    /// OCR 识别的文本（仅图片类型，v0.2 新增）
    let ocrText: String?

    // MARK: - Computed Properties

    /// 获取预览文本（用于 UI 显示）
    var previewText: String {
        switch type {
        case .text:
            // 【学习 Deck】使用 index-limited 采样避免扫描整个长文本
            guard let text = textContent, !text.isEmpty else {
                return ""
            }
            return Self.sampleText(text, maxLength: BusinessRules.TextPreview.cardPreview * 8)  // 8 行估算
        case .image:
            // v0.2: 如果有 OCR 文本，显示前 N 个字符
            if let ocr = ocrText, !ocr.isEmpty {
                return Self.sampleText(ocr, maxLength: BusinessRules.ClipboardItem.ocrPreviewLength)
            }
            return "[图片]"
        }
    }

    /// 获取相对时间描述
    var relativeTimeString: String {
        let now = Date()
        let itemDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let interval = now.timeIntervalSince(itemDate)

        if interval < BusinessRules.ClipboardItem.oneMinute {
            return "刚刚"
        } else if interval < BusinessRules.ClipboardItem.oneHour {
            let minutes = Int(interval / BusinessRules.ClipboardItem.oneMinute)
            return "\(minutes)分钟前"
        } else if interval < BusinessRules.ClipboardItem.oneDay {
            let hours = Int(interval / BusinessRules.ClipboardItem.oneHour)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / BusinessRules.ClipboardItem.oneDay)
            return "\(days)天前"
        }
    }

    /// 获取来源应用图标
    var appIcon: NSImage {
        return AppIconCache.shared.icon(forPath: appPath ?? "")
    }

    // MARK: - Initialization

    init(id: Int64, uniqueId: String, type: ClipboardItemType, textContent: String?, imageData: Data?, blobPath: String?, timestamp: Int64, appName: String, appPath: String?, ocrText: String? = nil) {
        self.id = id
        self.uniqueId = uniqueId
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
        self.blobPath = blobPath
        self.timestamp = timestamp
        self.appName = appName
        self.appPath = appPath
        self.ocrText = ocrText
    }

    // MARK: - Helper Methods

    /// 获取图片（从内存或文件系统）
    func getImage() -> NSImage? {
        if let imageData = imageData {
            return NSImage(data: imageData)
        } else if let blobPath = blobPath {
            // 从文件系统读取大图片
            let url = URL(fileURLWithPath: blobPath)
            if let data = try? Data(contentsOf: url) {
                return NSImage(data: data)
            }
        }
        return nil
    }

    /// 生成内容的 SHA256 hash（用于去重）
    static func generateUniqueId(from content: String) -> String {
        return content.sha256()
    }

    /// 生成图片数据的 SHA256 hash
    static func generateUniqueId(from imageData: Data) -> String {
        return imageData.sha256()
    }

    /// 文本采样（学习 Deck 的 index-limited 技术）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - maxLength: 最大长度
    /// - Returns: 采样后的文本
    private static func sampleText(_ text: String, maxLength: Int) -> String {
        guard maxLength > 0 else { return "" }

        // 使用 limitedBy 参数避免扫描整个字符串
        guard let cutIndex = text.index(text.startIndex, offsetBy: maxLength, limitedBy: text.endIndex),
              cutIndex != text.endIndex else {
            // 文本长度 <= maxLength，直接返回
            return text
        }

        // 截取到 maxLength 位置
        return String(text[..<cutIndex])
    }
}
