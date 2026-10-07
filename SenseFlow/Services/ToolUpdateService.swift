//
//  ToolUpdateService.swift
//  SenseFlow
//
//  Created on 2026-01-26.
//

import Foundation

/// 工具更新服务
/// 负责从 prompts.chat 获取和更新社区工具
class ToolUpdateService {

    // MARK: - Singleton

    static let shared = ToolUpdateService()

    // MARK: - Properties

    private let apiBaseURL = "https://prompts.chat/api"
    private let userDefaults = UserDefaults.standard

    // UserDefaults Keys
    private let lastUpdateCheckKey = "lastToolUpdateCheck"
    private let installedToolsVersionKey = "installedToolsVersion"

    // MARK: - Public Methods

    /// 检查是否有可用更新
    func checkForUpdates() async throws -> UpdateInfo {
        let lastCheck = userDefaults.double(forKey: lastUpdateCheckKey)
        let now = Date().timeIntervalSince1970

        // 24 小时内不重复检查
        if now - lastCheck < 86400 {
            return UpdateInfo(hasUpdates: false, availableTools: [])
        }

        // 获取远程工具列表
        let remoteTools = try await fetchClipboardFriendlyTools()

        // 获取本地已安装的社区工具
        let installedTools = DatabaseManager.shared.fetchCommunityTools()

        // 比较版本，找出新工具和更新的工具
        let newTools = remoteTools.filter { remote in
            !installedTools.contains { $0.remoteId == remote.id }
        }

        let updatedTools = remoteTools.filter { remote in
            installedTools.contains { local in
                local.remoteId == remote.id &&
                (local.remoteUpdatedAt == nil || remote.updatedAt > local.remoteUpdatedAt!)
            }
        }

        userDefaults.set(now, forKey: lastUpdateCheckKey)

        return UpdateInfo(
            hasUpdates: !newTools.isEmpty || !updatedTools.isEmpty,
            availableTools: remoteTools,
            newTools: newTools,
            updatedTools: updatedTools
        )
    }

    /// 安装或更新工具
    func installTool(_ remoteTool: RemoteTool) -> Bool {
        let localTool = PromptTool(
            name: remoteTool.title,
            prompt: remoteTool.content,
            capabilities: PromptToolCapability.infer(fromName: remoteTool.title, prompt: remoteTool.content),
            shortcutKeyCode: 0,
            shortcutModifiers: 0,
            isDefault: false,
            source: .community,
            remoteId: remoteTool.id,
            remoteAuthor: remoteTool.author.name,
            remoteVotes: remoteTool.voteCount,
            remoteUpdatedAt: remoteTool.updatedAt
        )

        // 检查是否已存在
        if let existingTool = DatabaseManager.shared.fetchToolByRemoteId(remoteTool.id) {
            // 更新现有工具
            var updatedTool = existingTool
            updatedTool.name = localTool.name
            updatedTool.prompt = localTool.prompt
            updatedTool.remoteVotes = localTool.remoteVotes
            updatedTool.remoteUpdatedAt = localTool.remoteUpdatedAt

            return DatabaseManager.shared.updatePromptTool(updatedTool)
        } else {
            // 插入新工具
            return DatabaseManager.shared.insertPromptTool(localTool)
        }
    }

    /// 批量安装工具
    func installTools(_ remoteTools: [RemoteTool]) async -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        for tool in remoteTools {
            if installTool(tool) {
                successCount += 1
            } else {
                failedCount += 1
            }
        }

        return (successCount, failedCount)
    }

    /// 卸载社区工具
    func uninstallTool(id: UUID) -> Bool {
        return DatabaseManager.shared.deletePromptTool(id: id)
    }

    // MARK: - Private Methods

    /// 获取适合剪贴板处理的工具
    private func fetchClipboardFriendlyTools() async throws -> [RemoteTool] {
        // 1. 获取 TEXT 类型的 prompts
        var components = URLComponents(string: "\(apiBaseURL)/prompts")!
        components.queryItems = [
            URLQueryItem(name: "type", value: "TEXT"),
            URLQueryItem(name: "limit", value: "100")
        ]

        guard let url = components.url else {
            throw ToolUpdateError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ToolUpdateError.networkError
        }

        let result = try JSONDecoder().decode(PromptsResponse.self, from: data)

        // 2. 过滤出适合剪贴板处理的工具
        let filtered = result.prompts.filter { tool in
            ToolFilter.isContentProcessing(tool)
        }

        // 3. 按点赞数排序
        return filtered.sorted { $0.voteCount > $1.voteCount }
    }
}

// MARK: - Models

/// 更新信息
struct UpdateInfo {
    let hasUpdates: Bool
    let availableTools: [RemoteTool]
    let newTools: [RemoteTool]
    let updatedTools: [RemoteTool]

    init(hasUpdates: Bool, availableTools: [RemoteTool], newTools: [RemoteTool] = [], updatedTools: [RemoteTool] = []) {
        self.hasUpdates = hasUpdates
        self.availableTools = availableTools
        self.newTools = newTools
        self.updatedTools = updatedTools
    }
}

/// 远程工具
struct RemoteTool: Codable, Identifiable {
    let id: String
    let title: String
    let slug: String?
    let description: String?
    let content: String
    let type: String
    let viewCount: Int
    let createdAt: Date
    let updatedAt: Date
    let author: RemoteAuthor
    let category: RemoteCategory?
    let tags: [RemoteTag]
    let voteCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, content, type
        case viewCount, createdAt, updatedAt, author, category, tags
        case voteCount = "_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(String.self, forKey: .type)
        viewCount = try container.decode(Int.self, forKey: .viewCount)

        // 解析日期
        let dateFormatter = ISO8601DateFormatter()
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()

        author = try container.decode(RemoteAuthor.self, forKey: .author)
        category = try container.decodeIfPresent(RemoteCategory.self, forKey: .category)
        tags = try container.decode([RemoteTag].self, forKey: .tags)

        // 解析 voteCount
        let countContainer = try container.nestedContainer(keyedBy: VoteCountKeys.self, forKey: .voteCount)
        voteCount = try countContainer.decode(Int.self, forKey: .votes)
    }

    private enum VoteCountKeys: String, CodingKey {
        case votes
    }
}

struct RemoteAuthor: Codable {
    let id: String
    let name: String?
    let username: String
    let avatar: String?
    let verified: Bool
}

struct RemoteCategory: Codable {
    let id: String
    let name: String
    let slug: String
    let description: String?
}

struct RemoteTag: Codable {
    let promptId: String
    let tagId: String
    let tag: TagInfo

    struct TagInfo: Codable {
        let id: String
        let name: String
        let slug: String
        let color: String
    }
}

struct PromptsResponse: Codable {
    let prompts: [RemoteTool]
}

// MARK: - Tool Filter

/// 工具过滤器
struct ToolFilter {

    // 内容处理关键词
    private static let processingKeywords = [
        "translate", "translator", "翻译",
        "improve", "improver", "改进",
        "correct", "corrector", "纠正",
        "format", "formatter", "格式化",
        "rewrite", "改写",
        "polish", "润色",
        "summarize", "summary", "总结",
        "extract", "提取",
        "convert", "转换",
        "edit", "editor", "编辑",
        "proofread", "校对",
        "simplify", "简化",
        "expand", "扩写"
    ]

    // 内容生成关键词
    private static let generationKeywords = [
        "create", "创建",
        "generate", "生成",
        "write a", "写一",
        "come up with", "想出",
        "design", "设计",
        "develop", "开发",
        "build", "构建",
        "make", "制作"
    ]

    /// 判断是否为内容处理类工具
    static func isContentProcessing(_ tool: RemoteTool) -> Bool {
        let text = ([tool.title, tool.description ?? "", tool.content].joined(separator: " ")).lowercased()

        // 1. 排除非文本类型
        if tool.type != "TEXT" {
            return false
        }

        // 2. 检查处理关键词
        let hasProcessingKeyword = processingKeywords.contains { keyword in
            text.contains(keyword.lowercased())
        }

        // 3. 检查生成关键词
        let hasGenerationKeyword = generationKeywords.contains { keyword in
            text.contains(keyword.lowercased())
        }

        // 4. 检查是否期待输入
        let expectsInput = text.contains("i will provide") ||
                          text.contains("i will give") ||
                          text.contains("i will type") ||
                          text.contains("i will write")

        // 5. 判断逻辑
        if hasProcessingKeyword && !hasGenerationKeyword {
            return true
        }

        if expectsInput && !hasGenerationKeyword {
            return true
        }

        return false
    }
}

// MARK: - Errors

enum ToolUpdateError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case databaseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .networkError:
            return "网络请求失败"
        case .decodingError:
            return "数据解析失败"
        case .databaseError:
            return "数据库操作失败"
        }
    }
}
