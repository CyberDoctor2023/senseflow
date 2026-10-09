import AppKit

/// Subscribes to indexed system capture files independently of clipboard changes.
@MainActor final class SystemCaptureService: NSObject, ObservableObject {
    static let shared = SystemCaptureService()
    static let importExistingKey = "system_capture_import_existing"
    @Published private(set) var status = "开启后按系统标记检索截图和录屏。"
    @Published private(set) var errorMessage: String?
    private let database: DatabaseManager
    private let query = NSMetadataQuery()
    private let importer = SystemCaptureFileImporter()
    private var seen: Set<String> = []
    private var candidates: [(url: URL, key: String)] = []
    private var candidateIndex = 0
    private var task: Task<Void, Never>?
    private var started = false
    private var generation = UUID()
    private var grantedDirectory: URL?

    init(database: DatabaseManager = .shared) {
        self.database = database
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(resultsChanged),
                                               name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(resultsChanged),
                                               name: .NSMetadataQueryDidUpdate, object: query)
    }

    /// Discovers existing and new system captures in configured save directories.
    func start() {
        guard !started else { return }
        let screenshots = UserDefaults.standard.bool(forKey: "filter_screenshot_enabled")
        let recordings = UserDefaults.standard.bool(forKey: "filter_recording_enabled")
        guard screenshots || recordings else { status = "截图与录屏收集已关闭。"; return }
        restoreDirectoryAccess()
        started = true
        generation = UUID()
        seen.removeAll()
        candidates.removeAll()
        candidateIndex = 0
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        let importsExisting = UserDefaults.standard.object(forKey: Self.importExistingKey) as? Bool ?? true
        query.predicate = Self.capturePredicate(screenshots: screenshots, recordings: recordings,
                                                since: importsExisting ? nil : Date())
        status = importsExisting ? "收集已有及新增的系统截图和录屏。" : "只收集开启后新保存的系统截图和录屏。"
        query.notificationBatchingInterval = 0.5
        if !query.start() { started = false; errorMessage = "无法开启捕获文件发现，请检查 Spotlight 索引。" }
    }

    /// Spotlight rejects a single-child OR, even though Foundation can construct it.
    static func capturePredicate(screenshots: Bool, recordings: Bool, since: Date?) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if screenshots { predicates.append(NSPredicate(format: "kMDItemIsScreenCapture == 1")) }
        if recordings { predicates.append(NSPredicate(format: "kMDItemIsScreenRecording == 1")) }
        guard let first = predicates.first else { return nil }
        let kinds = predicates.count == 1 ? first : NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        guard let since else { return kinds }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [kinds,
            NSPredicate(format: "kMDItemFSCreationDate >= %@", since as NSDate)])
    }

    /// Cancels pending imports before tutorials or shutdown; never mutates original files.
    func stop() {
        generation = UUID()
        task?.cancel(); task = nil
        query.stop(); started = false
        candidates.removeAll()
        candidateIndex = 0
        grantedDirectory?.stopAccessingSecurityScopedResource(); grantedDirectory = nil
    }

    /// Applies collection choices without requesting permissions during app launch.
    func refreshCollection() { stop(); start() }

    /// Explicitly copying an older capture imports its actual media, not a path string.
    func importCopiedFiles(_ urls: [URL]) async -> [URL] {
        var ordinary: [URL] = []
        var imported = false
        defer {
            if imported { NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil) }
        }
        let token = generation
        for url in urls {
            do {
                let request = try await importer.prepare(url, origin: .clipboard)
                guard !Task.isCancelled, generation == token else { return [] }
                let success = try await database.performStoreOperation { [database] in database.insertItem(request) }
                if success { imported = true }
                else { throw SystemCaptureError.saveFailed }
            } catch SystemCaptureError.missingEvidence { ordinary.append(url) }
            catch { if generation == token { errorMessage = "捕获文件未能收集：\(error.localizedDescription)" } }
        }
        return ordinary
    }

    private func restoreDirectoryAccess() {
        guard let data = UserDefaults.standard.data(forKey: "system_capture_directory_bookmark") else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
            _ = url.startAccessingSecurityScopedResource(); grantedDirectory = url
            if stale {
                UserDefaults.standard.set(try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil), forKey: "system_capture_directory_bookmark")
            }
        } catch { errorMessage = "无法恢复已有文件访问授权，受保护的文件可能无法读取。" }
    }

    @objc private func resultsChanged() {
        guard started else { return }
        collectCandidates()
        guard task == nil else { return }
        let token = generation
        task = Task { [weak self] in
            guard let self else { return }
            defer { if generation == token { task = nil } }
            while !Task.isCancelled, generation == token, let candidate = nextCandidate() {
                seen.insert(candidate.key)
                do {
                    let request = try await importer.prepare(candidate.url)
                    guard !Task.isCancelled, generation == token else { return }
                    let success = try await database.performStoreOperation { [database] in database.insertItem(request) }
                    guard success else { throw SystemCaptureError.saveFailed }
                    guard generation == token else { return }
                    errorMessage = nil
                    NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
                } catch is CancellationError { return }
                catch { if generation == token { errorMessage = "捕获文件未能收集：\(error.localizedDescription)" } }
            }
        }
    }

    private func nextCandidate() -> (url: URL, key: String)? {
        guard candidateIndex < candidates.count else {
            candidates.removeAll(keepingCapacity: true)
            candidateIndex = 0
            return nil
        }
        let candidate = candidates[candidateIndex]
        candidateIndex += 1
        return candidate
    }

    /// Snapshots each metadata update once instead of rescanning all results per import.
    private func collectCandidates() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(AppConstants.appSupportDirectoryName).path
        var queued = Set(candidates.dropFirst(candidateIndex).map(\.key))
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !(support.map { path.hasPrefix($0 + "/") } ?? false) else { continue }
            let modified = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)?.timeIntervalSince1970 ?? 0
            let key = "\(path):\(modified)"
            if !seen.contains(key), queued.insert(key).inserted {
                candidates.append((URL(fileURLWithPath: path), key))
            }
        }
    }
}
