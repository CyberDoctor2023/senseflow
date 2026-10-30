import AppKit
import AVFoundation
import CryptoKit
import Darwin
import ImageIO

/// Reads system-written evidence; never infers capture origin from names or shortcuts.
enum SystemCaptureEvidence {
    static func fileKind(_ url: URL) -> SystemCaptureKind? {
        if flag("com.apple.metadata:kMDItemIsScreenRecording", at: url) { return .recording }
        if flag("com.apple.metadata:kMDItemIsScreenCapture", at: url) { return .screenshot }
        return nil
    }

    static func imageKind(_ data: Data) -> SystemCaptureKind? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              exif[kCGImagePropertyExifUserComment as String] as? String == "Screenshot" else { return nil }
        return .screenshot
    }

    /// Same capture copied as PNG and TIFF has one identity while originals remain unchanged.
    static func screenshotIdentity(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
              width > 0, height > 0, width <= 16384, height <= 16384,
              width * height <= 40_000_000,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let bytes = context.data else { throw SystemCaptureError.invalidImage }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var digest = SHA256()
        digest.update(data: Data("screenshot:\(width):\(height):".utf8))
        digest.update(data: Data(bytesNoCopy: bytes, count: width * height * 4, deallocator: .none))
        return "capture:" + digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func flag(_ name: String, at url: URL) -> Bool {
        let size = getxattr(url.path, name, nil, 0, 0, 0)
        guard size > 0, size <= 1024 else { return false }
        var data = Data(count: size)
        let count = data.withUnsafeMutableBytes { getxattr(url.path, name, $0.baseAddress, size, 0, 0) }
        guard count == size, let value = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let flag = value as? NSNumber else { return false }
        return flag.boolValue
    }
}

enum SystemCaptureError: LocalizedError {
    case invalidImage, incomplete, missingEvidence, saveFailed
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "这张截图无法读取，或尺寸超过安全处理范围。"
        case .incomplete: return "捕获文件尚未保存完成，请稍后重试。"
        case .missingEvidence: return "没有可确认的系统捕获来源。"
        case .saveFailed: return "未能保存捕获文件，请检查可用存储空间。"
        }
    }
}

/// Serial file preparation keeps full media IO outside the history database and UI queues.
actor SystemCaptureFileImporter {
    private let storageDirectory: URL?
    /// A caller-supplied directory isolates media verification from user history.
    init(storageDirectory: URL? = nil) { self.storageDirectory = storageDirectory }
    func prepare(_ url: URL, origin: HistoryOrigin = .file) async throws -> DatabaseManager.ClipboardItemInsertRequest {
        guard let kind = SystemCaptureEvidence.fileKind(url) else { throw SystemCaptureError.missingEvidence }
        let dates = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let capturedAt = origin == .file ? (dates.creationDate ?? dates.contentModificationDate).map { Int64($0.timeIntervalSince1970) } : nil
        var before = try signature(url)
        var stable = false
        var quietSamples = 0
        for _ in 0..<6 {
            try await Task.sleep(for: .milliseconds(500))
            let after = try signature(url)
            if before == after, after.size > 0 { quietSamples += 1 } else { quietSamples = 0 }
            before = after
            if quietSamples >= 2 { stable = true; break }
        }
        guard stable else { throw SystemCaptureError.incomplete }
        if kind == .screenshot {
            guard before.size <= 128 * 1024 * 1024 else { throw SystemCaptureError.invalidImage }
            let data = try Data(contentsOf: url)
            let identity = try SystemCaptureEvidence.screenshotIdentity(data)
            guard try signature(url) == before else { throw SystemCaptureError.incomplete }
            return .init(type: .image, imageData: data, appName: "截图", captureKind: .screenshot,
                         origin: origin, contentIdentity: identity, capturedAt: capturedAt)
        }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        guard duration.seconds.isFinite, duration.seconds > 0, try await asset.load(.isPlayable) else {
            throw SystemCaptureError.incomplete
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        let identity = "recording:" + digest.finalize().map { String(format: "%02x", $0) }.joined()
        let directory = try storageDirectory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appendingPathComponent(AppConstants.appSupportDirectoryName).appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(identity.replacingOccurrences(of: ":", with: "-") + ".mov")
        if !FileManager.default.fileExists(atPath: destination.path) {
            let temporary = directory.appendingPathComponent(".\(UUID().uuidString).partial")
            defer { try? FileManager.default.removeItem(at: temporary) }
            try FileManager.default.copyItem(at: url, to: temporary)
            guard try signature(url) == before else { throw SystemCaptureError.incomplete }
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
        guard try signature(url) == before else { throw SystemCaptureError.incomplete }
        return .init(type: .video, appName: "录屏", captureKind: .recording, origin: origin,
                     contentIdentity: identity, storedMediaPath: destination.path, capturedAt: capturedAt)
    }

    private struct Signature: Equatable { let size: Int; let modified: Date? }
    private func signature(_ url: URL) throws -> Signature {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw SystemCaptureError.incomplete }
        return Signature(size: values.fileSize ?? 0, modified: values.contentModificationDate)
    }
}
