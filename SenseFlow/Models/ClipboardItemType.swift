//
//  ClipboardItemType.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Foundation

/// 剪贴板条目类型
enum ClipboardItemType: String, Codable {
    case text = "text"
    case image = "image"

    /// 获取类型对应的颜色（用于 UI 显示）
    var colorHex: String {
        switch self {
        case .text:
            return "#007AFF"  // 系统蓝
        case .image:
            return "#AF52DE"  // 系统紫
        }
    }

    /// 获取类型对应的图标名称
    var iconName: String {
        switch self {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        }
    }
}
