import Foundation
import Observation
import AppKit
import ImageIO

/// Explicit preview and paste intents share detail loading, never clipboard side effects.
@MainActor @Observable final class HistoryActionCoordinator {
    private(set) var errorMessage: String?
    private(set) var isDragging = false
    var quickLookURL: URL?
    private var previewTask: Task<Void, Never>?
    let documents: DocumentPreviewCoordinator
    private let repository: HistoryContentRepository
    private let writer: ClipboardWriter
    private let onPaste: () -> Void
    private let allowsExternalDrag: Bool
    private let onDragEnded: () -> Void
    private var pasteTask: Task<Void, Never>?
    private var pasteRequest = UUID()
    init(documents: DocumentPreviewCoordinator, repository: HistoryContentRepository, writer: ClipboardWriter, onPaste: @escaping () -> Void, onDragEnded: @escaping () -> Void = {}, allowsExternalDrag: Bool = true) {
        self.documents = documents; self.repository = repository; self.writer = writer; self.onPaste = onPaste
        self.onDragEnded = onDragEnded
        self.allowsExternalDrag = allowsExternalDrag
    }

    /// Opens recording files with the system Quick Look presentation.
    func previewRecording(_ item: ClipboardItem) {
        previewTask?.cancel()
        previewTask = Task {
            do {
                let detail = try await repository.loadDetail(itemID: item.id, revision: item.uniqueId)
                try Task.checkCancellation()
                guard detail.type == .video, let path = detail.blobPath,
                      FileManager.default.fileExists(atPath: path) else { throw DocumentStoreError.missing }
                quickLookURL = URL(fileURLWithPath: path)
                errorMessage = nil
            } catch is CancellationError {} catch { errorMessage = error.localizedDescription }
        }
    }

    /// Tracks only the native drag lifetime, independently of the history pin mode.
    func setDragging(_ active: Bool) {
        guard isDragging != active else { return }
        isDragging = active
        if !active { onDragEnded() }
    }
    func select(_ item: ClipboardItem) {
        pasteTask?.cancel()
        pasteRequest = UUID()
        let token = pasteRequest
        pasteTask = Task {
            do {
                let detail = try await repository.loadDetail(itemID: item.id, revision: item.uniqueId)
                guard !Task.isCancelled, token == pasteRequest else { return }
                switch detail.type {
                case .text:
                    guard let text = detail.textContent else { throw DocumentStoreError.missing }
                    await writer.write(text)
                case .image:
                    let data: Data
                    if let stored = detail.imageData { data = stored }
                    else if let path = detail.blobPath {
                        data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: URL(fileURLWithPath: path)) }.value
                    } else { throw DocumentStoreError.missing }
                    guard !Task.isCancelled, token == pasteRequest else { return }
                    await writer.write(.image(data))
                case .video:
                    guard let path = detail.blobPath, FileManager.default.fileExists(atPath: path) else { throw DocumentStoreError.missing }
                    await writer.write(.file(URL(fileURLWithPath: path)))
                }
                errorMessage = nil
                onPaste()
            } catch is CancellationError {} catch { errorMessage = error.localizedDescription }
        }
    }
    func cancelPendingPaste() { pasteRequest = UUID(); pasteTask?.cancel() }

    /// Loads full content into a drag-local pasteboard without writing the system clipboard.
    func makeDragPasteboardItem(_ item: ClipboardItem) async throws -> NSPasteboardItem {
        guard allowsExternalDrag else { throw DocumentStoreError.unavailable }
        do {
            let detail = try await repository.loadDetail(itemID: item.id, revision: item.uniqueId)
            try Task.checkCancellation()
            let pasteboardItem = NSPasteboardItem()
            switch detail.type {
            case .text:
                guard let text = detail.textContent else { throw DocumentStoreError.missing }
                pasteboardItem.setString(text, forType: .string)
            case .image:
                let png = try await Task.detached(priority: .userInitiated) {
                    let data: Data
                    if let stored = detail.imageData { data = stored }
                    else if let path = detail.blobPath { data = try Data(contentsOf: URL(fileURLWithPath: path)) }
                    else { throw DocumentStoreError.missing }
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw DocumentStoreError.missing }
                    if CGImageSourceGetType(source) as String? == "public.png" { return data }
                    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw DocumentStoreError.missing }
                    let output = NSMutableData()
                    guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else { throw DocumentStoreError.unavailable }
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { throw DocumentStoreError.unavailable }
                    return output as Data
                }.value
                try Task.checkCancellation()
                pasteboardItem.setData(png, forType: .png)
            case .video:
                guard let path = detail.blobPath, FileManager.default.fileExists(atPath: path) else { throw DocumentStoreError.missing }
                pasteboardItem.setString(URL(fileURLWithPath: path).absoluteString, forType: .fileURL)
            }
            errorMessage = nil
            return pasteboardItem
        } catch {
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
            throw error
        }
    }
}
