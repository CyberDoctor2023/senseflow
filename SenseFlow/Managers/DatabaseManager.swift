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
    private let databaseURL: URL?
    private var openedDatabaseURL: URL?
    internal var onStoreQueue: Bool { DispatchQueue.getSpecific(key: queueKey) == true }

    /// A custom URL isolates integration verification from user history.
    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL
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
    private func handleDatabaseError(_ context: String, error: Error) {
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

            if isNew { scheduleOCRIfNeeded(type: request.type, rowId: rowId, imageData: request.imageData) }

            return true

        } catch {
            handleDatabaseError("插入失败", error: error)
            return false
        }
    }

    /// 插入新条目（便捷方法，保持向后兼容）
    @available(*, deprecated, message: "Use insertItem(_:ClipboardItemInsertRequest) instead")
    func insertItem(type: ClipboardItemType, textContent: String? = nil, imageData: Data? = nil, appName: String, appPath: String?) -> Bool {
        let request = ClipboardItemInsertRequest(
            type: type,
            textContent: textContent,
            imageData: imageData,
            appName: appName,
            appPath: appPath
        )
        return insertItem(request)
    }

    /// 验证并生成唯一 ID
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

    /// 如果是图片类型，安排 OCR 识别
    private func scheduleOCRIfNeeded(type: ClipboardItemType, rowId: Int64, imageData: Data?) {
        guard type == .image else { return }

        if let data = imageData {
            print("📸 开始 OCR（小图片，\(data.count) bytes）")
            performOCR(for: rowId, imageData: data)
        } else {
            scheduleOCRForLargeImage(rowId: rowId)
        }
    }

    /// 为大图片安排 OCR（从文件读取）
    private func scheduleOCRForLargeImage(rowId: Int64) {
        guard let db = db else { return }

        do {
            let query = historyTable.filter(id == rowId)
            guard let row = try db.pluck(query), let path = row[blobPath] else {
                print("⚠️ 图片没有数据，无法执行 OCR")
                return
            }

            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                print("⚠️ 无法读取大图片文件: \(path)")
                return
            }

            print("📸 开始 OCR（大图片，\(data.count) bytes）")
            performOCR(for: rowId, imageData: data)
        } catch {
            handleDatabaseError("读取大图片失败", error: error)
        }
    }

    /// 后台执行 OCR 识别（不阻塞主线程）
    /// - Parameters:
    ///   - rowId: 数据库行 ID
    ///   - imageData: 图片数据
    private func performOCR(for rowId: Int64, imageData: Data) {
        Task.detached(priority: .utility) {
            let startTime = Date()
            if let ocrResult = await OCRService.shared.recognizeText(from: imageData) {
                let elapsed = Date().timeIntervalSince(startTime)
                print("✅ OCR 完成 (\(String(format: "%.2f", elapsed))s)")

                // 更新数据库
                await self.updateOCRText(for: rowId, ocrText: ocrResult)
            } else {
                print("⚠️ OCR 未识别到文字")
            }
        }
    }

    /// 更新 OCR 文本
    /// - Parameters:
    ///   - rowId: 数据库行 ID
    ///   - ocrText: OCR 识别的文本
    private func updateOCRText(for rowId: Int64, ocrText: String) async {
        _ = try? await performStoreOperation {
            guard let db = self.db else { return }
            let item = self.historyTable.filter(self.id == rowId)
            try db.run(item.update(self.ocrText <- ocrText))
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

        if BlobFileManager.shared.shouldStoreLargeFileExternally(data) {
            let blobPath = try BlobFileManager.shared.saveLargeFile(data: data, uniqueId: uniqueId)
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

    /// 搜索剪贴板历史（支持文本内容、应用名称、OCR 文本搜索）
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - limit: 最大返回数量
    /// - Returns: 匹配的剪贴板项数组
    func searchItems(query: String, limit: Int = 200) -> [ClipboardItem] {
        if !onStoreQueue { return storeQueue.sync { self.searchItems(query: query, limit: limit) } }
        guard let db = db else { return [] }

        // 空查询返回全部
        guard !query.isEmpty else {
            return fetchRecentItems(limit: limit)
        }

        do {
            let searchPattern = "%\(query)%"
            // v0.2: 支持搜索 OCR 文本
            let searchQuery = historyTable
                .filter(textContent.like(searchPattern) || appName.like(searchPattern) || ocrText.like(searchPattern))
                .order(timestamp.desc)
                .limit(limit)

            var items: [ClipboardItem] = []
            for row in try db.prepare(searchQuery) {
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

            print("🔍 搜索 '\(query)' 找到 \(items.count) 条记录")
            return items

        } catch {
            handleDatabaseError("搜索失败", error: error)
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
                    BlobFileManager.shared.deleteBlobFile(at: path)
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
            try BlobFileManager.shared.cleanupAllBlobFiles()

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
        try db.run("CREATE TABLE IF NOT EXISTS document_drafts (session_id TEXT PRIMARY KEY, source_id INTEGER NOT NULL UNIQUE, base_revision TEXT NOT NULL, generation INTEGER NOT NULL, text TEXT NOT NULL, source_name TEXT NOT NULL, source_path TEXT, source_timestamp INTEGER NOT NULL)")
        try db.run("CREATE TABLE IF NOT EXISTS document_versions (request_id TEXT PRIMARY KEY, source_id INTEGER, item_id INTEGER NOT NULL)")
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

    /// Idempotent save with stable deduplication and source linkage in one transaction.
    func saveDocumentVersion(text: String, source: DocumentSnapshot, requestID: UUID) throws -> Int64 {
        if !onStoreQueue { return try storeQueue.sync { try self.saveDocumentVersion(text: text, source: source, requestID: requestID) } }
        guard let db else { throw DocumentStoreError.unavailable }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DocumentStoreError.empty }
        var result: Int64 = 0
        try db.transaction {
            let versions = Table("document_versions")
            let request = Expression<String>("request_id")
            let savedID = Expression<Int64>("item_id")
            if let prior = try db.pluck(versions.filter(request == requestID.uuidString)) {
                result = prior[savedID]
                return
            }
            let hash = text.sha256()
            if let existing = try db.pluck(historyTable.filter(uniqueId == hash)) {
                result = existing[id]
                try db.run(historyTable.filter(id == result).update(timestamp <- Int64(Date().timeIntervalSince1970)))
            } else {
                result = try insertToDatabase(db: db, uniqueId: hash, type: .text, textContent: text,
                                              imageData: nil, appName: source.appName, appPath: source.appPath)
            }
            try db.run(versions.insert(request <- requestID.uuidString,
                                      Expression<Int64>("source_id") <- source.itemID, savedID <- result))
        }
        DispatchQueue.main.async { NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil) }
        return result
    }

    /// Rejects old checkpoints; committed generation cannot move backwards.
    func checkpointDocumentDraft(_ draft: DocumentDraft) throws {
        if !onStoreQueue { return try storeQueue.sync { try self.checkpointDocumentDraft(draft) } }
        guard let db else { throw DocumentStoreError.unavailable }
        try db.transaction {
            let drafts = Table("document_drafts")
            let sid = Expression<String>("session_id")
            let generation = Expression<Int>("generation")
            if let existing = try db.pluck(drafts.filter(sid == draft.sessionID.uuidString)), existing[generation] > draft.generation {
                throw DocumentStoreError.stale
            }
            try db.run("INSERT INTO document_drafts (session_id,source_id,base_revision,generation,text,source_name,source_path,source_timestamp) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(session_id) DO UPDATE SET generation=excluded.generation,text=excluded.text,base_revision=excluded.base_revision",
                       draft.sessionID.uuidString, draft.source.itemID, draft.source.revision, draft.generation,
                       draft.text, draft.source.appName, draft.source.appPath, draft.source.timestamp)
        }
    }

    func recoverDocumentDraft(sourceID: Int64) throws -> DocumentDraft? {
        if !onStoreQueue { return try storeQueue.sync { try self.recoverDocumentDraft(sourceID: sourceID) } }
        guard let db else { throw DocumentStoreError.unavailable }
        let drafts = Table("document_drafts")
        guard let row = try db.pluck(drafts.filter(Expression<Int64>("source_id") == sourceID)),
              let sessionID = UUID(uuidString: row[Expression<String>("session_id")]) else { return nil }
        let source = DocumentSnapshot(itemID: sourceID, revision: row[Expression<String>("base_revision")], text: "",
                                      appName: row[Expression<String>("source_name")], appPath: row[Expression<String?>("source_path")],
                                      timestamp: row[Expression<Int64>("source_timestamp")])
        return DocumentDraft(sessionID: sessionID, source: source, generation: row[Expression<Int>("generation")], text: row[Expression<String>("text")])
    }

    func discardDocumentDraft(sessionID: UUID, generation: Int) throws {
        if !onStoreQueue { return try storeQueue.sync { try self.discardDocumentDraft(sessionID: sessionID, generation: generation) } }
        guard let db else { throw DocumentStoreError.unavailable }
        let drafts = Table("document_drafts")
        let selection = drafts.filter(Expression<String>("session_id") == sessionID.uuidString)
        if let row = try db.pluck(selection), row[Expression<Int>("generation")] > generation { throw DocumentStoreError.stale }
        try db.run(selection.delete())
    }

    // MARK: - Prompt Tools CRUD Operations

    /// 获取所有 Prompt Tools
    func fetchAllPromptTools() -> [PromptTool] {
        if !onStoreQueue { return storeQueue.sync { self.fetchAllPromptTools() } }
        guard let db = db else { return [] }

        do {
            var tools: [PromptTool] = []
            for row in try db.prepare(promptToolsTable.order(toolCreatedAt.asc)) {
                // 使用扩展中的 parsePromptTool 方法来正确解析所有字段
                let tool = parsePromptToolFromRow(row)
                tools.append(tool)
            }
            return tools
        } catch {
            handleDatabaseError("获取 Prompt Tools 失败", error: error)
            return []
        }
    }

    /// 从数据库行解析 PromptTool（包含所有字段）
    internal func parsePromptToolFromRow(_ row: Row) -> PromptTool {
        let id = UUID(uuidString: try! row.get(toolId)) ?? UUID()
        let name = try! row.get(toolName)
        let prompt = try! row.get(toolPrompt)
        let shortcutKeyCode = UInt16(try! row.get(toolShortcutKeyCode))
        let shortcutModifiers = UInt32(try! row.get(toolShortcutModifiers))
        let isDefault = try! row.get(toolIsDefault)
        let createdAt = Date(timeIntervalSince1970: try! row.get(toolCreatedAt))
        let updatedAt = Date(timeIntervalSince1970: try! row.get(toolUpdatedAt))

        // v0.4 字段（可能不存在）
        let sourceString = (try? row.get(toolSource)) ?? "custom"
        let source = ToolSource(rawValue: sourceString) ?? .custom
        let remoteId = try? row.get(toolRemoteId)
        let remoteAuthor = try? row.get(toolRemoteAuthor)
        let remoteVotes = (try? row.get(toolRemoteVotes)) ?? 0
        let remoteUpdatedAtTimestamp = try? row.get(toolRemoteUpdatedAt)
        let remoteUpdatedAt = remoteUpdatedAtTimestamp.map { Date(timeIntervalSince1970: $0) }

        // v0.5 Langfuse 字段（可能不存在）
        let langfuseName = try? row.get(toolLangfuseName)
        let langfuseVersion = try? row.get(toolLangfuseVersion)
        let langfuseLabelsJson = try? row.get(toolLangfuseLabels)
        let langfuseLabels = parseLangfuseLabelsJson(langfuseLabelsJson)
        let lastSyncedAtTimestamp = try? row.get(toolLastSyncedAt)
        let lastSyncedAt = lastSyncedAtTimestamp.map { Date(timeIntervalSince1970: $0) }
        let capabilitiesJSON = try? row.get(toolCapabilities)
        let parsedCapabilities = parseCapabilitiesJson(capabilitiesJSON)
        let effectiveCapabilities = parsedCapabilities.isEmpty
            ? PromptToolCapability.infer(fromName: name, prompt: prompt)
            : parsedCapabilities

        return PromptTool(
            id: id,
            name: name,
            prompt: prompt,
            capabilities: effectiveCapabilities,
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: source,
            remoteId: remoteId,
            remoteAuthor: remoteAuthor,
            remoteVotes: remoteVotes,
            remoteUpdatedAt: remoteUpdatedAt,
            langfuseName: langfuseName,
            langfuseVersion: langfuseVersion,
            langfuseLabels: langfuseLabels,
            lastSyncedAt: lastSyncedAt
        )
    }

    /// 解析 Langfuse labels JSON 字符串
    private func parseLangfuseLabelsJson(_ json: String?) -> [String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let labels = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return labels
    }

    /// 解析 capabilities JSON 字符串
    private func parseCapabilitiesJson(_ json: String?) -> [PromptToolCapability] {
        guard let json,
              let data = json.data(using: .utf8),
              let capabilities = try? JSONDecoder().decode([PromptToolCapability].self, from: data) else {
            return []
        }
        return Array(Set(capabilities)).sorted(by: { $0.rawValue < $1.rawValue })
    }

    /// 将 Langfuse labels 编码为 JSON 字符串
    private func encodeLangfuseLabels(_ labels: [String]) -> String? {
        guard !labels.isEmpty,
              let data = try? JSONEncoder().encode(labels),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// 将 capabilities 编码为 JSON 字符串
    private func encodeCapabilities(_ capabilities: [PromptToolCapability]) -> String? {
        let normalized = Array(Set(capabilities)).sorted(by: { $0.rawValue < $1.rawValue })
        guard !normalized.isEmpty,
              let data = try? JSONEncoder().encode(normalized),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// 插入新的 Prompt Tool
    @discardableResult
    func insertPromptTool(_ tool: PromptTool) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.insertPromptTool(tool) } }
        guard let db = db else { return false }

        do {
            // 准备 Langfuse labels JSON
            let labelsJson = encodeLangfuseLabels(tool.langfuseLabels)
            let capabilitiesJson = encodeCapabilities(tool.capabilities)

            try db.run(promptToolsTable.insert(
                toolId <- tool.id.uuidString,
                toolName <- tool.name,
                toolPrompt <- tool.prompt,
                toolShortcutKeyCode <- Int(tool.shortcutKeyCode),
                toolShortcutModifiers <- Int(tool.shortcutModifiers),
                toolIsDefault <- tool.isDefault,
                toolCreatedAt <- tool.createdAt.timeIntervalSince1970,
                toolUpdatedAt <- tool.updatedAt.timeIntervalSince1970,
                toolSource <- tool.source.rawValue,
                toolRemoteId <- tool.remoteId,
                toolRemoteAuthor <- tool.remoteAuthor,
                toolRemoteVotes <- tool.remoteVotes,
                toolRemoteUpdatedAt <- tool.remoteUpdatedAt?.timeIntervalSince1970,
                toolLangfuseName <- tool.langfuseName,
                toolLangfuseVersion <- tool.langfuseVersion,
                toolLangfuseLabels <- labelsJson,
                toolLastSyncedAt <- tool.lastSyncedAt?.timeIntervalSince1970,
                toolCapabilities <- capabilitiesJson
            ))
            print("✅ Prompt Tool 插入成功: \(tool.name)")
            NotificationCenter.default.post(name: .promptToolsDidUpdate, object: nil)
            return true
        } catch {
            handleDatabaseError("Prompt Tool 插入失败", error: error)
            return false
        }
    }

    /// 更新 Prompt Tool
    @discardableResult
    func updatePromptTool(_ tool: PromptTool) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.updatePromptTool(tool) } }
        guard let db = db else { return false }

        do {
            // 准备 Langfuse labels JSON
            let labelsJson = encodeLangfuseLabels(tool.langfuseLabels)
            let capabilitiesJson = encodeCapabilities(tool.capabilities)

            let query = promptToolsTable.filter(toolId == tool.id.uuidString)
            try db.run(query.update(
                toolName <- tool.name,
                toolPrompt <- tool.prompt,
                toolShortcutKeyCode <- Int(tool.shortcutKeyCode),
                toolShortcutModifiers <- Int(tool.shortcutModifiers),
                toolUpdatedAt <- Date().timeIntervalSince1970,
                toolSource <- tool.source.rawValue,
                toolRemoteId <- tool.remoteId,
                toolRemoteAuthor <- tool.remoteAuthor,
                toolRemoteVotes <- tool.remoteVotes,
                toolRemoteUpdatedAt <- tool.remoteUpdatedAt?.timeIntervalSince1970,
                toolLangfuseName <- tool.langfuseName,
                toolLangfuseVersion <- tool.langfuseVersion,
                toolLangfuseLabels <- labelsJson,
                toolLastSyncedAt <- tool.lastSyncedAt?.timeIntervalSince1970,
                toolCapabilities <- capabilitiesJson
            ))
            print("✅ Prompt Tool 更新成功: \(tool.name)")
            NotificationCenter.default.post(name: .promptToolsDidUpdate, object: nil)
            return true
        } catch {
            handleDatabaseError("Prompt Tool 更新失败", error: error)
            return false
        }
    }

    /// 删除 Prompt Tool
    @discardableResult
    func deletePromptTool(id: UUID) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.deletePromptTool(id: id) } }
        guard let db = db else { return false }

        do {
            let query = promptToolsTable.filter(toolId == id.uuidString)
            try db.run(query.delete())
            print("✅ Prompt Tool 删除成功: \(id)")
            NotificationCenter.default.post(name: .promptToolsDidUpdate, object: nil)
            return true
        } catch {
            handleDatabaseError("Prompt Tool 删除失败", error: error)
            return false
        }
    }

    /// 初始化默认 Prompt Tools（首次启动时调用）
    func initializeDefaultToolsIfNeeded() {
        if !onStoreQueue { return storeQueue.sync { self.initializeDefaultToolsIfNeeded() } }
        let existingTools = fetchAllPromptTools()
        
        // 如果已有工具，不再初始化
        guard existingTools.isEmpty else {
            print("📋 已存在 \(existingTools.count) 个 Prompt Tools，跳过初始化")
            return
        }

        print("🆕 首次启动，初始化默认 Prompt Tools")
        for tool in PromptTool.defaultTools {
            insertPromptTool(tool)
        }
    }

    /// 恢复默认 Prompt Tools
    func restoreDefaultTools() {
        if !onStoreQueue { return storeQueue.sync { self.restoreDefaultTools() } }
        let existingTools = fetchAllPromptTools()
        let defaultTools = PromptTool.defaultTools

        for defaultTool in defaultTools {
            restoreOrCreateDefaultTool(defaultTool, existingTools: existingTools)
        }

        print("✅ 默认 Prompt Tools 已恢复")
    }

    /// 恢复或创建单个默认工具
    private func restoreOrCreateDefaultTool(_ defaultTool: PromptTool, existingTools: [PromptTool]) {
        if let existing = findExistingDefaultTool(defaultTool, in: existingTools) {
            resetToDefaultPrompt(existing, defaultPrompt: defaultTool.prompt)
        } else if !toolNameExists(defaultTool.name, in: existingTools) {
            insertPromptTool(defaultTool)
        }
    }

    /// 查找已存在的同名默认工具
    private func findExistingDefaultTool(_ defaultTool: PromptTool, in existingTools: [PromptTool]) -> PromptTool? {
        return existingTools.first(where: { $0.name == defaultTool.name && $0.isDefault })
    }

    /// 检查工具名称是否已存在
    private func toolNameExists(_ name: String, in existingTools: [PromptTool]) -> Bool {
        return existingTools.contains(where: { $0.name == name })
    }

    /// 重置为默认 prompt
    private func resetToDefaultPrompt(_ tool: PromptTool, defaultPrompt: String) {
        var updated = tool
        updated.prompt = defaultPrompt
        updatePromptTool(updated)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let promptToolsDidUpdate = Notification.Name("promptToolsDidUpdate")
}
