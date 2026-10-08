import Foundation
import CoreGraphics
import AVFoundation

/// Bounded previews, separate from originals. In-flight requests with the same key are shared.
actor ClipboardThumbnailLoader {
    private var cache: [String: CGImage] = [:]
    private var pending: [String: Task<CGImage?, Never>] = [:]
    private var costs: [String: Int] = [:]
    private var recency: [String] = []
    private var retainedBytes = 0
    private let maxBytes: Int
    private let maxCount: Int
    private let repository: HistoryContentRepository
    init(repository: HistoryContentRepository, maxBytes: Int = 50 * 1024 * 1024, maxCount: Int = 100) {
        self.repository = repository
        self.maxBytes = max(0, maxBytes)
        self.maxCount = max(0, maxCount)
    }
    private func touch(_ key: String) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    func thumbnail(for item: ClipboardItem, pixels: Int) async -> CGImage? {
        let key = "\(item.uniqueId):\(pixels)"
        guard pixels > 0 else { return nil }
        if let image = cache[key] { touch(key); return image }
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
            return try? await HistoryMediaLoader.imagePreview(for: detail, pixels: pixels)
        }
        pending[key] = request
        let image = await request.value
        pending[key] = nil
        if let image {
            let cost = image.bytesPerRow * image.height
            guard maxCount > 0, cost <= maxBytes else { return image }
            while retainedBytes + cost > maxBytes || cache.count >= maxCount {
                guard let oldest = recency.first else { break }
                recency.removeFirst()
                cache[oldest] = nil
                retainedBytes -= costs.removeValue(forKey: oldest) ?? 0
            }
            cache[key] = image; costs[key] = cost
            retainedBytes += cost
            touch(key)
        }
        return image
    }
}
