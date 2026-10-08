//
//  DatabaseManager.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Foundation
import SQLite

/// 数据库管理器（单例）
class DatabaseManager {

    // MARK: - Singleton

    static let shared = DatabaseManager()

    // MARK: - Properties

    internal var db: Connection?
    private let historyTable = Table("clipboard_history")

    // 表字段定义
    private let id = Expression<Int64>("id")
    private let uniqueId = Expression<String>("unique_id")
    private let type = Expression<String>("type")
    private let textContent = Expression<String?>("text_content")
    private let imageData = Expression<Data?>("image_data")
    private let blobPath = Expression<String?>("blob_path")
    private let timestamp = Expression<Int64>("timestamp")
    private let appName = Expression<String>("app_name")
    private let appPath = Expression<String?>("app_path")
    private let ocrText = Expression<String?>("ocr_text")  // v0.2: OCR 识别的文本
    private let captureKind = Expression<String?>("capture_kind")
    private let origin = Expression<String>("origin")

    // v0.2: Prompt Tools 表
    internal let promptToolsTable = Table("prompt_tools")
    internal let toolId = Expression<String>("id")  // UUID string
    internal let toolName = Expression<String>("name")
    internal let toolPrompt = Expression<String>("prompt")
    internal let toolShortcutKeyCode = Expression<Int>("shortcut_key_code")
    internal let toolShortcutModifiers = Expression<Int>("shortcut_modifiers")
    internal let toolIsDefault = Expression<Bool>("is_default")
    internal let toolCreatedAt = Expression<Double>("created_at")
    internal let toolUpdatedAt = Expression<Double>("updated_at")

    // v0.4: Remote Tools Fields
    internal let toolSource = Expression<String>("source")
    internal let toolRemoteId = Expression<String?>("remote_id")
    internal let toolRemoteAuthor = Expression<String?>("remote_author")
    internal let toolRemoteVotes = Expression<Int>("remote_votes")
    internal let toolRemoteUpdatedAt = Expression<Double?>("remote_updated_at")

    // v0.5: Langfuse Fields
    internal let toolLangfuseName = Expression<String?>("langfuse_name")
    internal let toolLangfuseVersion = Expression<Int?>("langfuse_version")
    internal let toolLangfuseLabels = Expression<String?>("langfuse_labels")  // JSON array
    internal let toolLastSyncedAt = Expression<Double?>("last_synced_at")

    // v0.6: Prompt Tool Capabilities (JSON array)
    internal let toolCapabilities = Expression<String?>("capabilities")

    // 配置
    private let largeFileSizeThreshold = 512 * 1024  // 512KB

    // MARK: - Initialization

    internal let storeQueue = DispatchQueue(label: "top.senseflow.history-store", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<Bool>()
    // Owned exclusively by storeQueue; pending originals stay in SQLite, not task closures.
    private var isRecognizingHistory = false
    private var recognitionCursor: Int64 = 0
    private let blobs: BlobFileManager
    private let databaseURL: URL?
    private var openedDatabaseURL: URL?
    internal var onStoreQueue: Bool { DispatchQueue.getSpecific(key: queueKey) == true }

    /// A custom URL isolates integration verification from user history.
    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL
        self.blobs = databaseURL.map { BlobFileManager(directory: $0.deletingLastPathComponent().appendingPathComponent("blobs")) } ?? .shared
        storeQueue.setSpecific(key: queueKey, value: true)
        storeQueue.sync { setupDatabase() }
    }

    /// Serializes a complete store operation, including transactions, off the UI thread.
    func performStoreOperation<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            storeQueue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    /// Capture ordering follows submissions to the single store owner.
    func enqueueCapture(_ request: ClipboardItemInsertRequest, completion: @escaping (Bool) -> Void) {
        storeQueue.async {
            let success = self.insertItem(request)
            DispatchQueue.main.async { completion(success) }
        }
    }

    // MARK: - Database Setup

    private func setupDatabase() {
        do {
            // 获取应用支持目录
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            // 创建应用目录
            let appDirectory = appSupportURL.appendingPathComponent(AppConstants.appSupportDirectoryName, isDirectory: true)
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

            // 创建数据库文件
            let dbPath = (databaseURL ?? appDirectory.appendingPathComponent("clipboard.sqlite")).path
            openedDatabaseURL = URL(fileURLWithPath: dbPath)
            db = try Connection(dbPath)

            print("📂 数据库路径: \(dbPath)")

            // 创建表
            try createTable()

            // 创建索引
            try createIndexes()

            // 数据库迁移（必须在表创建后执行）
            print("🔍 开始检查数据库迁移...")
            try migrateIfNeeded()
            try migrateCaptureMetadata()
            try createDocumentTables()

            print("✅ 数据库初始化成功: \(dbPath)")

        } catch {
            handleDatabaseError("数据库初始化失败", error: error)
        }
    }

    /// 统一的数据库错误处理
    func handleDatabaseError(_ context: String, error: Error) {
        print("❌ \(context): \(error.localizedDescription)")
        // 可以在这里添加更多错误处理逻辑，如错误上报、用户通知等
    }

    private func createTable() throws {
        try db?.run(historyTable.create(ifNotExists: true) { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(uniqueId, unique: true)
            table.column(type)
            table.column(textContent)
            table.column(imageData)
            table.column(blobPath)
            table.column(timestamp)
            table.column(appName)
            table.column(appPath)
            table.column(ocrText)  // v0.2: OCR 文本字段
        })

        // v0.2: Prompt Tools 表（包含所有字段到 v0.5）
        try db?.run(promptToolsTable.create(ifNotExists: true) { table in
            table.column(toolId, primaryKey: true)
            table.column(toolName)
            table.column(toolPrompt)
            table.column(toolShortcutKeyCode, defaultValue: 0)
            table.column(toolShortcutModifiers, defaultValue: 0)
            table.column(toolIsDefault, defaultValue: false)
            table.column(toolCreatedAt)
            table.column(toolUpdatedAt)

            // v0.4: Remote Tools Fields
            table.column(toolSource, defaultValue: "custom")
            table.column(toolRemoteId)
            table.column(toolRemoteAuthor)
            table.column(toolRemoteVotes, defaultValue: 0)
            table.column(toolRemoteUpdatedAt)

            // v0.5: Langfuse Fields
            table.column(toolLangfuseName)
            table.column(toolLangfuseVersion)
            table.column(toolLangfuseLabels)
            table.column(toolLastSyncedAt)

            // v0.6: Explicit capabilities tags
            table.column(toolCapabilities)
        })
    }

    private func createIndexes() throws {
        // 按时间戳倒序索引（用于快速查询最新记录）
        try db?.run(historyTable.createIndex(timestamp, ifNotExists: true))

        // 按 uniqueId 索引（用于去重查询）
        try db?.run(historyTable.createIndex(uniqueId, ifNotExists: true))
    }

    /// 数据库迁移（委托给 DatabaseMigrationManager）
    private func migrateIfNeeded() throws {
        guard let db = db else { return }

        let migrationManager = DatabaseMigrationManager(db: db)
        try migrationManager.migrateIfNeeded()
    }

    // MARK: - CRUD Operations

    private func migrateCaptureMetadata() throws {
        guard let db else { throw DocumentStoreError.unavailable }
        let columns = Set(try db.prepare("PRAGMA table_info(clipboard_history)").compactMap { $0[1] as? String })
        guard !columns.contains("capture_kind") || !columns.contains("origin") else { return }
        guard let location = openedDatabaseURL else { throw DocumentStoreError.unavailable }
        let backups = location.deletingLastPathComponent().appendingPathComponent("migration-backups")
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let backup = backups.appendingPathComponent("before-captures-\(UUID().uuidString).sqlite")
        try db.run("VACUUM INTO ?", backup.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        try db.transaction {
            if !columns.contains("capture_kind") { try db.run("ALTER TABLE clipboard_history ADD COLUMN capture_kind TEXT") }
            if !columns.contains("origin") { try db.run("ALTER TABLE clipboard_history ADD COLUMN origin TEXT NOT NULL DEFAULT 'clipboard'") }
        }
    }

    /// 剪贴板项目插入请求
    struct ClipboardItemInsertRequest {
        let type: ClipboardItemType
        let textContent: String?
        let imageData: Data?
        let appName: String
        let appPath: String?
        let captureKind: SystemCaptureKind?
        let origin: HistoryOrigin
        let contentIdentity: String?
        let storedMediaPath: String?
        let capturedAt: Int64?

        init(type: ClipboardItemType, textContent: String? = nil, imageData: Data? = nil, appName: String, appPath: String? = nil,
             captureKind: SystemCaptureKind? = nil, origin: HistoryOrigin = .clipboard,
             contentIdentity: String? = nil, storedMediaPath: String? = nil, capturedAt: Int64? = nil) {
            self.type = type
            self.textContent = textContent
            self.imageData = imageData
            self.appName = appName
            self.appPath = appPath
            self.captureKind = captureKind
            self.origin = origin
            self.contentIdentity = contentIdentity
            self.capturedAt = capturedAt
            self.storedMediaPath = storedMediaPath
        }
    }

    /// 插入新条目（自动去重，重复内容移到最前面）
    func insertItem(_ request: ClipboardItemInsertRequest) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.insertItem(request) } }
        guard let db = db else { return false }

        do {
            if request.type == .text, request.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { return false }
            if request.type == .video, request.storedMediaPath == nil || request.contentIdentity == nil { return false }
            let uniqueIdValue = try request.contentIdentity ?? validateAndGenerateUniqueId(
                type: request.type,
                textContent: request.textContent,
                imageData: request.imageData
            )

            var rowId: Int64 = 0
            var isNew = false
            try db.transaction {
                if let existing = try db.pluck(historyTable.filter(uniqueId == uniqueIdValue)) {
                    rowId = existing[id]
                    if request.origin != .file {
                        try db.run(historyTable.filter(id == rowId).update(timestamp <- Int64(Date().timeIntervalSince1970)))
                    }
                    if let kind = request.captureKind {
                        try db.run(historyTable.filter(id == rowId).update(captureKind <- kind.rawValue))
                    }
                } else {
                    isNew = true
                    rowId = try insertToDatabase(
                        db: db,
                        uniqueId: uniqueIdValue,
                        type: request.type,
                        textContent: request.textContent,
                        imageData: request.imageData,
                        appName: request.appName,
                        appPath: request.appPath,
                        captureKind: request.captureKind,
                        origin: request.origin,
                        storedMediaPath: request.storedMediaPath,
                        capturedAt: request.capturedAt
                    )
                }
            }
            print("✅ 插入成功: \(request.type.rawValue)")

            if isNew { scheduleOCRIfNeeded(type: request.type, rowId: rowId) }

            return true

        } catch {
            handleDatabaseError("插入失败", error: error)
            return false
        }
    }

    private func validateAndGenerateUniqueId(type: ClipboardItemType, textContent: String?, imageData: Data?) throws -> String {
        let uniqueId = generateUniqueId(type: type, textContent: textContent, imageData: imageData)
        guard !uniqueId.isEmpty else {
            throw NSError(domain: "DatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法生成唯一 ID"])
        }
        return uniqueId
    }

    /// 插入数据到数据库
    private func insertToDatabase(db: Connection, uniqueId: String, type: ClipboardItemType, textContent: String?, imageData: Data?, appName: String, appPath: String?, captureKind: SystemCaptureKind? = nil, origin: HistoryOrigin = .clipboard, storedMediaPath: String? = nil, capturedAt: Int64? = nil) throws -> Int64 {
        let (finalImageData, blobPathValue) = try processImageData(imageData, uniqueId: uniqueId)
        let timestampValue = capturedAt ?? Int64(Date().timeIntervalSince1970)

        return try db.run(historyTable.insert(
            self.uniqueId <- uniqueId,
            self.type <- type.rawValue,
            self.textContent <- textContent,
            self.imageData <- finalImageData,
            self.blobPath <- storedMediaPath ?? blobPathValue,
            self.timestamp <- timestampValue,
            self.appName <- appName,
            self.appPath <- appPath,
            self.ocrText <- nil,
            self.captureKind <- captureKind?.rawValue,
            self.origin <- origin.rawValue
        ))
    }

    /// Starts one consumer for newly inserted images; queued work retains no image bytes.
    private func scheduleOCRIfNeeded(type: ClipboardItemType, rowId: Int64) {
        guard type == .image, !isRecognizingHistory else { return }
        recognitionCursor = rowId - 1
        isRecognizingHistory = true
        Task.detached(priority: .utility) { await self.recognizePendingHistory() }
    }

    private func recognizePendingHistory() async {
        while true {
            let item: ClipboardItem?
            do {
                item = try await performStoreOperation {
                    guard let db = self.db else {
                        self.isRecognizingHistory = false
                        return nil
                    }
                    let query = self.historyTable
                        .filter(self.type == ClipboardItemType.image.rawValue && self.id > self.recognitionCursor)
                        .order(self.id.asc).limit(1)
                    guard let row = try db.pluck(query) else {
                        self.isRecognizingHistory = false
                        return nil
                    }
                    self.recognitionCursor = row[self.id]
                    return try self.loadHistoryDetail(itemID: row[self.id], revision: row[self.uniqueId])
                }
            } catch {
                _ = try? await performStoreOperation {
                    self.isRecognizingHistory = false
                    self.handleDatabaseError("读取OCR原件失败", error: error)
                }
                return
            }
            guard let item else { return }
            do {
                let data = try await HistoryMediaLoader.imageData(for: item)
                guard let text = await OCRService.shared.recognizeText(from: data) else { continue }
                _ = try await performStoreOperation {
                    guard let db = self.db else { return }
                    let current = self.historyTable.filter(self.id == item.id && self.uniqueId == item.uniqueId)
                    try db.run(current.update(self.ocrText <- text))
                }
            } catch {
                // A deleted original or failed recognition never mutates history or stops the queue.
                continue
            }
        }
    }

    private func generateUniqueId(type: ClipboardItemType, textContent: String?, imageData: Data?) -> String {
        if type == .text {
            return textContent?.sha256() ?? ""
        } else {
            return imageData?.sha256() ?? ""
        }
    }

    private func processImageData(_ imageData: Data?, uniqueId: String) throws -> (Data?, String?) {
        guard let data = imageData else {
            return (nil, nil)
        }

        if blobs.shouldStoreLargeFileExternally(data) {
            let blobPath = try blobs.saveLargeFile(data: data, uniqueId: uniqueId)
            return (nil, blobPath)
        } else {
            return (data, nil)
        }
    }

    /// 检查条目是否存在
    func itemExists(uniqueId: String) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.itemExists(uniqueId: uniqueId) } }
        guard let db = db else { return false }

        do {
            let query = historyTable.filter(self.uniqueId == uniqueId)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            return false
        }
    }

    /// 获取最新的 N 条记录
    func fetchRecentItems(limit: Int = 200) -> [ClipboardItem] {
        if !onStoreQueue { return storeQueue.sync { self.fetchRecentItems(limit: limit) } }
        guard let db = db else { return [] }

        do {
            let query = historyTable
                .order(timestamp.desc)
                .limit(limit)

            var items: [ClipboardItem] = []
            for row in try db.prepare(query) {
                let item = ClipboardItem(
                    id: row[id],
                    uniqueId: row[uniqueId],
                    type: ClipboardItemType(rawValue: row[type]) ?? .text,
                    textContent: row[textContent],
                    imageData: row[imageData],
                    blobPath: row[blobPath],
                    timestamp: row[timestamp],
                    appName: row[appName],
                    appPath: row[appPath],
                    ocrText: row[ocrText], captureKind: row[captureKind].flatMap(SystemCaptureKind.init(rawValue:)),
                    origin: HistoryOrigin(rawValue: row[origin]) ?? .clipboard
                )
                items.append(item)
            }

            return items

        } catch {
            handleDatabaseError("查询失败", error: error)
            return []
        }
    }

    // MARK: - Async Query Methods

    /// 异步查询最近的剪贴板历史（async/await 版本）
    /// - Parameter limit: 最大返回数量
    /// - Returns: 剪贴板项数组
    func fetchRecentItemsAsync(limit: Int = 200, offset: Int = 0) async throws -> [ClipboardItem] {
        try await performStoreOperation { try self.fetchSummaries(query: "", limit: limit, offset: offset) }
    }

    /// Fetches only bounded text excerpts; full contents are loaded for explicit actions.
    func searchItemsAsync(query: String, limit: Int = 200, offset: Int = 0) async throws -> [ClipboardItem] {
        try await performStoreOperation { try self.fetchSummaries(query: query, limit: limit, offset: offset) }
    }

    /// 删除单条记录
    /// - Parameter itemId: 要删除的记录 ID
    func deleteItem(id itemId: Int64) {
        if !onStoreQueue { return storeQueue.sync { self.deleteItem(id: itemId) } }
        guard let db = db else { return }

        do {
            let query = historyTable.filter(id == itemId)
            if let row = try db.pluck(query) {
                if let path = row[blobPath] {
                    blobs.deleteBlobFile(at: path)
                }
            }

            try db.run(query.delete())
            print("✅ 已删除记录 ID: \(itemId)")

            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)

        } catch {
            handleDatabaseError("删除记录失败", error: error)
        }
    }

    /// 删除所有记录
    func clearAllItems() {
        if !onStoreQueue { return storeQueue.sync { self.clearAllItems() } }
        guard let db = db else { return }

        do {
            try db.transaction {
                try db.run(historyTable.delete())
                try db.run("DELETE FROM document_drafts")
                try db.run("DELETE FROM document_versions")
            }
            try blobs.cleanupAllBlobFiles()

            print("✅ 已清空所有记录")

            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)

        } catch {
            handleDatabaseError("清空失败", error: error)
        }
    }


    // MARK: - Document storage (only invoked on storeQueue)

    private func createDocumentTables() throws {
        guard let db else { throw DocumentStoreError.unavailable }
        let schemaExists = (try db.scalar("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='document_drafts'") as? Int64 ?? 0) > 0
        if !schemaExists, databaseURL == nil {
            // Resolve the canonical app directory rather than relying on Connection.description.
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let backups = support.appendingPathComponent(AppConstants.appSupportDirectoryName).appendingPathComponent("migration-backups")
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let backup = backups.appendingPathComponent("before-document-drafts-\(UUID().uuidString).sqlite")
            try db.run("VACUUM INTO ?", backup.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try SQLiteDocumentStore(db: db).createTables()
    }

    /// Lists bounded excerpts without loading image BLOBs or full document strings.
    private func fetchSummaries(query: String, limit: Int, offset: Int) throws -> [ClipboardItem] {
        guard let db else { throw DocumentStoreError.unavailable }
        let excerpt = Expression<String?>(literal: "substr(text_content, 1, 1025)")
        var selection = historyTable.select(id, uniqueId, type, excerpt, blobPath, timestamp, appName, appPath, captureKind, origin)
        if !query.isEmpty {
            let pattern = "%\(query)%"
            selection = selection.filter(textContent.like(pattern) || appName.like(pattern) || ocrText.like(pattern))
        }
        return try db.prepare(selection.order(timestamp.desc, id.desc).limit(limit, offset: offset)).map { row in
            ClipboardItem(id: row[id], uniqueId: row[uniqueId], type: ClipboardItemType(rawValue: row[type]) ?? .text,
                          textContent: row[excerpt], imageData: nil, blobPath: row[blobPath], timestamp: row[timestamp],
                          appName: row[appName], appPath: row[appPath], isSummary: true,
                          captureKind: row[captureKind].flatMap(SystemCaptureKind.init(rawValue:)), origin: HistoryOrigin(rawValue: row[origin]) ?? .clipboard)
        }
    }

    /// Full payload is fetched only for preview, copy or paste.
    func loadHistoryDetail(itemID: Int64, revision: String) throws -> ClipboardItem {
        if !onStoreQueue { return try storeQueue.sync { try self.loadHistoryDetail(itemID: itemID, revision: revision) } }
        guard let db else { throw DocumentStoreError.unavailable }
        guard let row = try db.pluck(historyTable.filter(id == itemID)) else { throw DocumentStoreError.missing }
        guard row[uniqueId] == revision else { throw DocumentStoreError.changed }
        return ClipboardItem(id: row[id], uniqueId: row[uniqueId], type: ClipboardItemType(rawValue: row[type]) ?? .text,
                             textContent: row[textContent], imageData: row[imageData], blobPath: row[blobPath],
                             timestamp: row[timestamp], appName: row[appName], appPath: row[appPath], ocrText: row[ocrText],
                             captureKind: row[captureKind].flatMap(SystemCaptureKind.init(rawValue:)), origin: HistoryOrigin(rawValue: row[origin]) ?? .clipboard)
    }

    /// Saves an immutable derived record and its request identity in one transaction.
    func saveDocumentVersion(text: String, source: DocumentSnapshot, requestID: UUID) throws -> Int64 {
        if !onStoreQueue { return try storeQueue.sync { try self.saveDocumentVersion(text: text, source: source, requestID: requestID) } }
        guard let db else { throw DocumentStoreError.unavailable }
        let result = try SQLiteDocumentStore(db: db).saveVersion(text: text, source: source, requestID: requestID) { hash in
            try self.insertToDatabase(db: db, uniqueId: hash, type: .text, textContent: text,
                                      imageData: nil, appName: source.appName, appPath: source.appPath)
        }
        DispatchQueue.main.async { NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil) }
        return result
    }
    func checkpointDocumentDraft(_ draft: DocumentDraft) throws {
        if !onStoreQueue { return try storeQueue.sync { try self.checkpointDocumentDraft(draft) } }
        guard let db else { throw DocumentStoreError.unavailable }
        try SQLiteDocumentStore(db: db).checkpoint(draft)
    }
    func recoverDocumentDraft(sourceID: Int64) throws -> DocumentDraft? {
        if !onStoreQueue { return try storeQueue.sync { try self.recoverDocumentDraft(sourceID: sourceID) } }
        guard let db else { throw DocumentStoreError.unavailable }
        return try SQLiteDocumentStore(db: db).recover(sourceID: sourceID)
    }
    func discardDocumentDraft(sessionID: UUID, generation: Int) throws {
        if !onStoreQueue { return try storeQueue.sync { try self.discardDocumentDraft(sessionID: sessionID, generation: generation) } }
        guard let db else { throw DocumentStoreError.unavailable }
        try SQLiteDocumentStore(db: db).discard(sessionID: sessionID, generation: generation)
    }

}

// MARK: - Notification Names

extension Notification.Name {
    static let promptToolsDidUpdate = Notification.Name("promptToolsDidUpdate")
}
