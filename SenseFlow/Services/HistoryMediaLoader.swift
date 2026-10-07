import Foundation
import CoreGraphics
import ImageIO

/// Loads original media and prepares derivatives away from UI and database executors.
enum HistoryMediaLoader {
    static func imageData(for item: ClipboardItem) async throws -> Data {
        if let data = item.imageData { return data }
        guard let path = item.blobPath else { throw DocumentStoreError.missing }
        return try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: URL(fileURLWithPath: path))
        }.value
    }

    static func imagePreview(for item: ClipboardItem, pixels: Int) async throws -> CGImage {
        let data = try await imageData(for: item)
        return try await Task.detached(priority: .userInitiated) {
            guard pixels > 0, let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: pixels,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw DocumentStoreError.missing }
            return image
        }.value
    }

    static func pngForDrag(for item: ClipboardItem) async throws -> Data {
        let data = try await imageData(for: item)
        return try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw DocumentStoreError.missing }
            if CGImageSourceGetType(source) as String? == "public.png" { return data }
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw DocumentStoreError.missing }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else { throw DocumentStoreError.unavailable }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw DocumentStoreError.unavailable }
            return output as Data
        }.value
    }
}
