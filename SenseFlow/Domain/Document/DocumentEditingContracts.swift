import Foundation

/// Immutable history content. Recency changes never change the content revision.
struct DocumentSnapshot {
    let itemID: Int64
    let revision: String
    let text: String
    let appName: String
    let appPath: String?
    let timestamp: Int64
}

/// Durable checkpoint; the native editor remains the sole live buffer.
struct DocumentDraft {
    let sessionID: UUID
    let source: DocumentSnapshot
    let generation: Int
    let text: String
}

enum DocumentStoreError: LocalizedError {
    case unavailable, missing, changed, empty, stale
    var errorDescription: String? {
        switch self {
        case .unavailable: return "暂时无法读写历史记录，请重试。"
        case .missing: return "原记录已被删除。"
        case .changed: return "记录版本已改变，请重新打开。"
        case .empty: return "空内容可保留为草稿，不能保存为历史记录。"
        case .stale: return "草稿已有更新，旧操作已取消。"
        }
    }
}

/// One store owner handles history, derived versions and independent drafts.
protocol HistoryContentRepository {
    func loadDetail(itemID: Int64, revision: String) async throws -> ClipboardItem
    func saveDerived(text: String, source: DocumentSnapshot, requestID: UUID) async throws -> Int64
    func recover(sourceID: Int64) async throws -> DocumentDraft?
    func checkpoint(_ draft: DocumentDraft) async throws
    func discard(sessionID: UUID, generation: Int) async throws
}

/// UI-neutral native buffer boundary; composition cannot be committed as a version.
@MainActor protocol DocumentEditor: AnyObject {
    var isComposing: Bool { get }
    func textSnapshot() -> String
    func load(text: String)
    func setEditable(_ editable: Bool)
    func focus()
}
