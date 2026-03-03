//
//  AppIconCache.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa

/// 应用图标缓存服务（单例）
/// 参考: Maccy's ApplicationImageCache.swift
class AppIconCache {

    // MARK: - Singleton

    static let shared = AppIconCache()

    // MARK: - Properties

    private var cache: [String: NSImage] = [:]
    private let defaultIcon: NSImage

    // MARK: - Initialization

    private init() {
        // 降级图标（应用被删除或路径为空）
        if let icon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil) {
            defaultIcon = icon
        } else {
            // 终极降级
            defaultIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Finder.app")
        }
    }

    // MARK: - Public Methods

    /// 获取应用图标（带缓存）
    /// - Parameter path: 应用路径，为空或无效时返回默认图标
    /// - Returns: 应用图标
    func icon(forPath path: String) -> NSImage {
        // 处理空路径
        guard !path.isEmpty else {
            return defaultIcon
        }

        // 检查缓存
        if let cachedIcon = cache[path] {
            return cachedIcon
        }

        // 从文件系统加载
        let icon = loadIcon(forPath: path)

        // 缓存结果
        cache[path] = icon

        return icon
    }

    /// 清空缓存（用于内存警告）
    func clearCache() {
        cache.removeAll()
        print("🧹 已清空应用图标缓存")
    }

    // MARK: - Private Methods

    private func loadIcon(forPath path: String) -> NSImage {
        let fileManager = FileManager.default

        // 检查应用是否存在
        guard fileManager.fileExists(atPath: path) else {
            print("⚠️ 应用不存在: \(path)")
            return defaultIcon
        }

        // 使用 NSWorkspace 加载图标
        let icon = NSWorkspace.shared.icon(forFile: path)

        return icon
    }
}
