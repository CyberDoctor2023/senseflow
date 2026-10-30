import Foundation

/// Writes a selected history item without recapturing it as a new record.
protocol ClipboardWriter: Sendable {
    func write(_ text: String) async
    func write(_ content: ClipboardContent) async
}
