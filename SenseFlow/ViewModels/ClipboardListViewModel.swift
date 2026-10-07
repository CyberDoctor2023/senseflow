import SwiftUI

/// Presentation-only categories; code remains losslessly stored as text.
enum ClipboardContentFilter: String, CaseIterable { case text, image, code, screenshot, recording }

/// Owns refresh/search generations. Older results can never replace a newer query.
@MainActor final class ClipboardListViewModel: ObservableObject {
    private var loadedItems: [ClipboardItem] = [] {
        didSet { rebuildVisibleItems() }
    }
    @Published private(set) var selectedType: ClipboardContentFilter? {
        didSet { rebuildVisibleItems() }
    }
    @Published private(set) var items: [ClipboardItem] = []

    /// Derives presentation once per page/filter update, never during card body evaluation.
    private func rebuildVisibleItems() {
        if let selectedType { items = loadedItems.filter { Self.matches($0, filter: selectedType) } }
        else { items = loadedItems }
    }
    private static func matches(_ item: ClipboardItem, filter: ClipboardContentFilter) -> Bool {
        switch filter {
        case .text: return item.type == .text
        case .image: return item.type == .image
        case .code: return item.type == .text && looksLikeCode(item.textContent ?? "")
        case .screenshot: return item.captureKind == .screenshot
        case .recording: return item.type == .video && item.captureKind == .recording
        }
    }
    private static func looksLikeCode(_ text: String) -> Bool {
        let sample = String(text.prefix(2048))
        if sample.contains("```") { return true }
        let lines = sample.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let declarations = ["import ", "func ", "def ", "class ", "struct ", "let ", "const ", "function ", "var ", "SELECT ", "#!/"]
        if lines.contains(where: { line in declarations.contains(where: line.hasPrefix) }) { return true }
        return lines.filter { $0.contains(";") || $0.contains("{") || $0.contains("}") }.count >= 2
    }
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    private var hasMore = false
    private let pageSize = 200
    @Published var searchQuery = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            invalidate()
            debounceTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                await self?.refresh()
            }
        }
    }
    @Published var isWindowPinned = false {
        didSet {
            guard isWindowPinned != oldValue else { return }
            generation += 1
            pageTask?.cancel(); pageTask = nil; isLoadingMore = false
            debounceTask?.cancel(); refreshTask?.cancel(); refreshTask = nil; activeQuery = nil
            isLoading = false
            if !isWindowPinned { Task { [weak self] in await self?.loadItems() } }
        }
    }
    let actions: HistoryActionCoordinator
    let thumbnails: ClipboardThumbnailLoader
    private let repository: ClipboardRepositoryProtocol
    private var debounceTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var pageTask: Task<Void, Never>?
    private var generation = 0
    private var activeQuery: String?

    init(repository: ClipboardRepositoryProtocol, actions: HistoryActionCoordinator, thumbnails: ClipboardThumbnailLoader) {
        self.repository = repository; self.actions = actions; self.thumbnails = thumbnails
    }
    private func invalidate() {
        generation += 1
        pageTask?.cancel(); pageTask = nil; isLoadingMore = false
        debounceTask?.cancel(); refreshTask?.cancel(); refreshTask = nil; activeQuery = nil
        actions.documents.historyChanged()
    }
    /// Toggles a content filter while preserving any draft excluded by the new filter.
    func selectType(_ type: ClipboardContentFilter) async {
        let next: ClipboardContentFilter? = selectedType == type ? nil : type
        if let next, let source = actions.documents.source,
           let item = loadedItems.first(where: { $0.id == source.itemID }), !Self.matches(item, filter: next) {
            guard await actions.documents.prepareToClose() else { return }
        }
        actions.documents.historyChanged()
        selectedType = next
        if items.isEmpty { await loadMoreIfNeeded(after: nil) }
    }
    /// Hiding a selected category returns to all history without mutating stored records.
    func clearHiddenFilter(_ visible: [ClipboardContentFilter]) async {
        if let selectedType, !visible.contains(selectedType) { await selectType(selectedType) }
    }
    /// Appends bounded summaries only when the last visible card is reached; pinned history never changes.
    func loadMoreIfNeeded(after itemID: Int64?) async {
        guard !isWindowPinned, !isLoading, !isLoadingMore, hasMore,
              itemID == items.last?.id else { return }
        let token = generation
        let query = searchQuery
        let visibleCount = items.count
        isLoadingMore = true
        pageTask = Task { [weak self] in
            guard let self else { return }
            do {
                repeat {
                    let offset = loadedItems.count
                    let page = query.isEmpty
                        ? try await repository.fetchRecent(limit: pageSize, offset: offset)
                        : try await repository.search(query: query, limit: pageSize, offset: offset)
                    guard !Task.isCancelled, token == generation, !isWindowPinned, query == searchQuery else { return }
                    loadedItems.append(contentsOf: page)
                    hasMore = page.count == pageSize
                    errorMessage = nil
                } while hasMore && items.count == visibleCount
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                errorMessage = "历史加载失败：\(error.localizedDescription)"
            }
            guard token == generation else { return }
            isLoadingMore = false
            pageTask = nil
        }
        await pageTask?.value
    }
    func loadItems() async { debounceTask?.cancel(); await refresh() }
    func performSearch(query: String) async { searchQuery = query; debounceTask?.cancel(); await refresh() }
    private func refresh() async {
        guard !isWindowPinned else { return }
        let query = searchQuery
        if activeQuery == query, let refreshTask { await refreshTask.value; return }
        generation += 1
        pageTask?.cancel(); pageTask = nil; isLoadingMore = false
        let token = generation
        activeQuery = query
        isLoading = true
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = query.isEmpty ? try await repository.fetchRecent(limit: pageSize, offset: 0) : try await repository.search(query: query, limit: pageSize, offset: 0)
                guard !Task.isCancelled, !isWindowPinned, token == generation, query == searchQuery else { return }
                loadedItems = result
                hasMore = result.count == pageSize
                errorMessage = nil
            } catch {
                guard !Task.isCancelled, token == generation else { return }
                errorMessage = "历史加载失败：\(error.localizedDescription)"
            }
            isLoading = false
            refreshTask = nil; activeQuery = nil
        }
        await refreshTask?.value
        if items.isEmpty { await loadMoreIfNeeded(after: nil) }
    }
}
