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
    private let maxHistoryCount = 200  // 最大历史记录数
    private let largeFileSizeThreshold = 512 * 1024  // 512KB

    // MARK: - Initialization

    private init() {
        setupDatabase()
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
            let dbPath = appDirectory.appendingPathComponent("clipboard.sqlite").path
            db = try Connection(dbPath)

            print("📂 数据库路径: \(dbPath)")

            // 创建表
            try createTable()

            // 创建索引
            try createIndexes()

            // 数据库迁移（必须在表创建后执行）
            print("🔍 开始检查数据库迁移...")
            try migrateIfNeeded()

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

    /// 剪贴板项目插入请求
    struct ClipboardItemInsertRequest {
        let type: ClipboardItemType
        let textContent: String?
        let imageData: Data?
        let appName: String
        let appPath: String?

        init(type: ClipboardItemType, textContent: String? = nil, imageData: Data? = nil, appName: String, appPath: String? = nil) {
            self.type = type
            self.textContent = textContent
            self.imageData = imageData
            self.appName = appName
            self.appPath = appPath
        }
    }

    /// 插入新条目（自动去重，重复内容移到最前面）
    func insertItem(_ request: ClipboardItemInsertRequest) -> Bool {
        guard let db = db else { return false }

        do {
            let uniqueIdValue = try validateAndGenerateUniqueId(
                type: request.type,
                textContent: request.textContent,
                imageData: request.imageData
            )

            // 如果内容已存在，删除旧记录（新记录会自动排在最前面）
            if itemExists(uniqueId: uniqueIdValue) {
                deleteItemByUniqueId(uniqueId: uniqueIdValue)
                print("🔄 内容已存在，移到最前面")
            }

            let rowId = try insertToDatabase(
                db: db,
                uniqueId: uniqueIdValue,
                type: request.type,
                textContent: request.textContent,
                imageData: request.imageData,
                appName: request.appName,
                appPath: request.appPath
            )

            try cleanupOldRecords()
            print("✅ 插入成功: \(request.type.rawValue)")

            scheduleOCRIfNeeded(type: request.type, rowId: rowId, imageData: request.imageData)

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
    private func insertToDatabase(db: Connection, uniqueId: String, type: ClipboardItemType, textContent: String?, imageData: Data?, appName: String, appPath: String?) throws -> Int64 {
        let (finalImageData, blobPathValue) = try processImageData(imageData, uniqueId: uniqueId)
        let timestampValue = Int64(Date().timeIntervalSince1970)

        return try db.run(historyTable.insert(
            self.uniqueId <- uniqueId,
            self.type <- type.rawValue,
            self.textContent <- textContent,
            self.imageData <- finalImageData,
            self.blobPath <- blobPathValue,
            self.timestamp <- timestampValue,
            self.appName <- appName,
            self.appPath <- appPath,
            self.ocrText <- nil
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
                print("✅ OCR 完成: \(ocrResult.prefix(BusinessRules.TextPreview.logPreview))... (\(String(format: "%.2f", elapsed))s)")

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
        guard let db = db else { return }

        do {
            let item = historyTable.filter(id == rowId)
            try db.run(item.update(self.ocrText <- ocrText))
            print("✅ OCR 文本已更新到数据库")
        } catch {
            handleDatabaseError("更新 OCR 文本失败", error: error)
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
                    ocrText: row[ocrText]  // v0.2: OCR 文本
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
                    ocrText: row[ocrText]  // v0.2: OCR 文本
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
    func fetchRecentItemsAsync(limit: Int = 200) async -> [ClipboardItem] {
        return await Task.detached(priority: .userInitiated) {
            return self.fetchRecentItems(limit: limit)
        }.value
    }

    /// 异步搜索剪贴板历史（async/await 版本）
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - limit: 最大返回数量
    /// - Returns: 匹配的剪贴板项数组
    func searchItemsAsync(query: String, limit: Int = 200) async -> [ClipboardItem] {
        return await Task.detached(priority: .userInitiated) {
            return self.searchItems(query: query, limit: limit)
        }.value
    }

    /// 删除单条记录
    /// - Parameter itemId: 要删除的记录 ID
    func deleteItem(id itemId: Int64) {
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

    /// 根据 uniqueId 删除记录（用于去重时删除旧记录）
    /// - Parameter uniqueId: 记录的唯一 ID
    private func deleteItemByUniqueId(uniqueId: String) {
        guard let db = db else { return }

        do {
            let query = historyTable.filter(self.uniqueId == uniqueId)
            if let row = try db.pluck(query) {
                if let path = row[blobPath] {
                    BlobFileManager.shared.deleteBlobFile(at: path)
                }
            }

            try db.run(query.delete())
            print("🗑️ 已删除旧记录: \(uniqueId.prefix(8))...")

        } catch {
            handleDatabaseError("删除旧记录失败", error: error)
        }
    }

    /// 删除所有记录
    func clearAllItems() {
        guard let db = db else { return }

        do {
            try db.run(historyTable.delete())
            try BlobFileManager.shared.cleanupAllBlobFiles()

            print("✅ 已清空所有记录")

            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)

        } catch {
            handleDatabaseError("清空失败", error: error)
        }
    }


    /// 清理旧记录（保持最大数量限制）
    private func cleanupOldRecords() throws {
        try cleanupRecordsExceeding(limit: maxHistoryCount)
    }


    /// 强制执行历史记录上限（从设置中调用）
    /// - Parameter limit: 新的历史记录上限
    func enforceHistoryLimit(limit: Int) {
        do {
            try cleanupRecordsExceeding(limit: limit)
            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
        } catch {
            handleDatabaseError("强制清理失败", error: error)
        }
    }

    /// 清理超过指定上限的记录（公共逻辑）
    private func cleanupRecordsExceeding(limit: Int) throws {
        guard let db = db else { return }

        let count = try db.scalar(historyTable.count)
        guard count > limit else {
            print("📊 当前记录数 \(count) 未超过上限 \(limit)，无需清理")
            return
        }

        let deleteCount = count - limit
        try deleteOldestRecords(count: deleteCount)
        print("🧹 清理了 \(deleteCount) 条旧记录")
    }

    /// 删除最旧的 N 条记录
    private func deleteOldestRecords(count: Int) throws {
        guard let db = db else { return }

        let oldestItems = historyTable
            .order(timestamp.asc)
            .limit(count)

        // 删除关联的 blob 文件
        for row in try db.prepare(oldestItems) {
            if let path = row[blobPath] {
                BlobFileManager.shared.deleteBlobFile(at: path)
            }
        }

        // 删除数据库记录
        let oldestTimestamp = try db.prepare(oldestItems).map { $0[timestamp] }.max() ?? 0
        try db.run(historyTable.filter(timestamp <= oldestTimestamp).delete())
    }

    // MARK: - Prompt Tools CRUD Operations

    /// 获取所有 Prompt Tools
    func fetchAllPromptTools() -> [PromptTool] {
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
