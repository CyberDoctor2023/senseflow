import Foundation
import CoreGraphics
import AVFoundation

/// Bounded previews, separate from originals. In-flight requests with the same key are shared.
actor ClipboardThumbnailLoader {
    private var cache: [String: CGImage] = [:]
    private struct Request {
        let id = UUID()
        let item: ClipboardItem
        let pixels: Int
        var waiters: [UUID: CheckedContinuation<CGImage?, Never>]
        var task: Task<Void, Never>?
    }
    private var pending: [String: Request] = [:]
    private var queue: [String] = []
    private var activeLoads = 0
    private let maxLoads = 2
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
        guard pixels > 0, !Task.isCancelled else { return nil }
        let key = "\(item.uniqueId):\(pixels)"
        if let image = cache[key] { touch(key); return image }
        let waiter = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(returning: nil); return }
                if pending[key] != nil {
                    pending[key]?.waiters[waiter] = continuation
                } else {
                    pending[key] = Request(item: item, pixels: pixels, waiters: [waiter: continuation])
                    queue.append(key)
                }
                startQueuedLoads()
            }
        } onCancel: {
            Task { await self.cancel(waiter: waiter, key: key) }
        }
    }

    private func cancel(waiter: UUID, key: String) {
        guard var request = pending[key], let continuation = request.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(returning: nil)
        if request.waiters.isEmpty {
            pending[key] = nil
            queue.removeAll { $0 == key }
            request.task?.cancel()
        } else { pending[key] = request }
    }

    private func startQueuedLoads() {
        while activeLoads < maxLoads, !queue.isEmpty {
            let key = queue.removeFirst()
            guard let request = pending[key] else { continue }
            activeLoads += 1
            let item = request.item, pixels = request.pixels, id = request.id
            let task = Task {
                let image = await load(item, pixels: pixels)
                finish(key: key, id: id, image: Task.isCancelled ? nil : image)
            }
            pending[key]?.task = task
        }
    }

    private func load(_ item: ClipboardItem, pixels: Int) async -> CGImage? {
        guard !Task.isCancelled,
              let detail = try? await repository.loadDetail(itemID: item.id, revision: item.uniqueId),
              !Task.isCancelled else { return nil }
        if detail.type == .video, let path = detail.blobPath {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: pixels, height: pixels)
            return try? await generator.image(at: .zero).image
        }
        return try? await HistoryMediaLoader.imagePreview(for: detail, pixels: pixels)
    }

    private func finish(key: String, id: UUID, image: CGImage?) {
        activeLoads -= 1
        if let request = pending[key], request.id == id {
            pending[key] = nil
            if let image { retain(image, key: key) }
            for continuation in request.waiters.values { continuation.resume(returning: image) }
        }
        startQueuedLoads()
    }

    private func retain(_ image: CGImage, key: String) {
        let cost = image.bytesPerRow * image.height
        guard maxCount > 0, cost <= maxBytes else { return }
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
}
