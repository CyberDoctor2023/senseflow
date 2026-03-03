//
//  ClipboardImageCache.swift
//  SenseFlow
//
//  Created by Claude
//  Image caching service to avoid repeated disk I/O
//  【学习 Deck】使用 NSCache 自动管理内存
//

import Cocoa
import Foundation

/// 剪贴板图片缓存服务（单例）
/// 使用 NSCache 自动管理内存，避免重复的磁盘 I/O
final class ClipboardImageCache {

    // MARK: - Singleton

    static let shared = ClipboardImageCache()

    // MARK: - Logger

    private let logger = AppLogger.general

    // MARK: - Properties

    /// NSCache 自动管理内存压力，LRU 驱逐策略
    private let cache = NSCache<NSNumber, NSImage>()

    /// 缓存统计
    private var hits: Int = 0
    private var misses: Int = 0

    // MARK: - Initialization

    private init() {
        // 限制缓存数量（避免内存过大）
        cache.countLimit = 100  // 最多缓存 100 张图片

        // 限制缓存大小（估算：平均 500KB/张 → 50MB）
        cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB

        logger.debug("图片缓存初始化完成（最多 100 张，50 MB）")
    }

    // MARK: - Public Methods

    /// 获取图片（带缓存）
    /// - Parameters:
    ///   - item: 剪贴板条目
    /// - Returns: 图片，如果不存在返回 nil
    func image(for item: ClipboardItem) -> NSImage? {
        let key = NSNumber(value: item.id)

        // 检查缓存
        if let cachedImage = cache.object(forKey: key) {
            hits += 1
            if logger.isEnabled(.debug) {
                logger.debug("图片缓存命中 (ID: \(item.id), 命中率: \(hitRate)%)")
            }
            return cachedImage
        }

        // 缓存未命中，从磁盘加载
        misses += 1
        if logger.isEnabled(.debug) {
            logger.debug("图片缓存未命中 (ID: \(item.id), 命中率: \(hitRate)%)")
        }

        guard let image = loadImage(from: item) else {
            return nil
        }

        // 缓存结果（使用图片数据大小作为 cost）
        let cost = estimateImageSize(image)
        cache.setObject(image, forKey: key, cost: cost)

        if logger.isEnabled(.debug) {
            logger.debug("图片已缓存 (ID: \(item.id), 大小: \(cost / 1024) KB)")
        }

        return image
    }

    /// 清空缓存（用于内存警告）
    func clearCache() {
        cache.removeAllObjects()
        hits = 0
        misses = 0
        logger.info("图片缓存已清空")
    }

    /// 移除单个条目的缓存
    /// - Parameter itemId: 条目 ID
    func removeCache(for itemId: Int64) {
        let key = NSNumber(value: itemId)
        cache.removeObject(forKey: key)
        logger.debug("移除图片缓存 (ID: \(itemId))")
    }

    /// 获取缓存统计信息
    var statistics: String {
        let total = hits + misses
        guard total > 0 else { return "缓存统计: 无数据" }
        return "缓存统计: 命中 \(hits)/\(total) (\(hitRate)%)"
    }

    // MARK: - Private Methods

    /// 从剪贴板条目加载图片
    private func loadImage(from item: ClipboardItem) -> NSImage? {
        // 优先从内存数据加载（小图片）
        if let imageData = item.imageData {
            return NSImage(data: imageData)
        }

        // 从文件系统加载（大图片）
        if let blobPath = item.blobPath {
            let url = URL(fileURLWithPath: blobPath)
            if let data = try? Data(contentsOf: url) {
                return NSImage(data: data)
            } else {
                logger.warning("无法加载图片文件: \(blobPath)")
            }
        }

        return nil
    }

    /// 估算图片内存大小
    /// - Parameter image: NSImage 对象
    /// - Returns: 估算的字节数
    private func estimateImageSize(_ image: NSImage) -> Int {
        // 估算公式：width × height × 4 (RGBA)
        let size = image.size
        let width = Int(size.width * image.recommendedLayerContentsScale(0))
        let height = Int(size.height * image.recommendedLayerContentsScale(0))
        return width * height * 4
    }

    /// 计算缓存命中率
    private var hitRate: Int {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return (hits * 100) / total
    }
}
