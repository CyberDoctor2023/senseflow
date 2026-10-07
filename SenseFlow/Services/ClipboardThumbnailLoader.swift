import Foundation
import ImageIO
import CoreGraphics
import AVFoundation

/// Bounded previews, separate from originals. In-flight requests with the same key are shared.
actor ClipboardThumbnailLoader {
    private var cache: [String: CGImage] = [:]
    private var pending: [String: Task<CGImage?, Never>] = [:]
    private var costs: [String: Int] = [:]
    private let repository: HistoryContentRepository
    init(repository: HistoryContentRepository) { self.repository = repository }

    func thumbnail(for item: ClipboardItem, pixels: Int) async -> CGImage? {
        let key = "\(item.uniqueId):\(pixels)"
        if let image = cache[key] { return image }
        if let request = pending[key] { return await request.value }
        let repository = self.repository
        let request = Task<CGImage?, Never> {
            guard let detail = try? await repository.loadDetail(itemID: item.id, revision: item.uniqueId) else { return nil }
            if detail.type == .video, let path = detail.blobPath {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: pixels, height: pixels)
                return try? await generator.image(at: .zero).image
            }
            let data: Data?
            if let stored = detail.imageData { data = stored }
            else if let path = detail.blobPath { data = try? Data(contentsOf: URL(fileURLWithPath: path)) }
            else { data = nil }
            guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }
        pending[key] = request
        let image = await request.value
        pending[key] = nil
        if let image {
            let cost = image.bytesPerRow * image.height
            if costs.values.reduce(0, +) + cost > 50 * 1024 * 1024 || cache.count >= 100 {
                cache.removeAll(); costs.removeAll()
            }
            cache[key] = image; costs[key] = cost
        }
        return image
    }
}
