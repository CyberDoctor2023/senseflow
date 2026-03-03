//
//  PromptTool.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//

import Foundation
import Carbon

/// AI 服务类型
enum AIServiceType: String, Codable, CaseIterable {
    case openai = "openai"
    case claude = "claude"
    case gemini = "gemini"
    case deepseek = "deepseek"
    case openrouter = "openrouter"
    case ollama = "ollama"

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude (via OpenRouter)"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama"
        }
    }

    /// MacPaw OpenAI SDK 配置参数
    var sdkConfiguration: (host: String, scheme: String, port: Int) {
        switch self {
        case .openai:
            return ("api.openai.com", "https", 443)
        case .claude:
            // Claude 通过 OpenRouter 转发（MacPaw SDK 不支持 Claude 原生格式）
            return ("openrouter.ai", "https", 443)
        case .gemini:
            return ("generativelanguage.googleapis.com", "https", 443)
        case .deepseek:
            return ("api.deepseek.com", "https", 443)
        case .openrouter:
            return ("openrouter.ai", "https", 443)
        case .ollama:
            return ("localhost", "http", 11434)
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .claude: return "anthropic/claude-3.5-sonnet"
        case .gemini: return "gemini-2.5-flash"
        case .deepseek: return "deepseek-chat"
        case .openrouter: return "openai/gpt-4o-mini"
        case .ollama: return "llama2"
        }
    }

    /// 用户配置模型在 UserDefaults 的键
    private var configuredModelKey: String {
        "ai_model_\(rawValue)"
    }

    /// 当前实际使用模型（用户配置优先，缺省回退 defaultModel）
    var selectedModel: String {
        let raw = UserDefaults.standard.string(forKey: configuredModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return defaultModel
    }

    /// 保存用户模型配置（空字符串会清除配置并回退默认）
    func saveSelectedModel(_ model: String) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: configuredModelKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: configuredModelKey)
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama: return false
        default: return true
        }
    }

    /// 是否需要 relaxed parsing（非 OpenAI 服务）
    var needsRelaxedParsing: Bool {
        switch self {
        case .openai, .ollama: return false
        default: return true
        }
    }

    /// 是否支持 Vision API（图片理解）
    var supportsVision: Bool {
        switch self {
        case .openai, .gemini: return true
        case .claude, .deepseek, .ollama: return false
        case .openrouter: return true // 取决于底层模型
        }
    }
}

/// 工具来源
enum ToolSource: String, Codable {
    case builtin = "builtin"      // 内置工具
    case community = "community"  // 社区工具（prompts.chat）
    case custom = "custom"        // 用户自定义
    case langfuse = "langfuse"    // Langfuse 云端管理
    case smart = "smart"          // Smart AI 智能推荐（特殊工具）
}

/// Prompt Tool 能力标签（用于显式意图约束）
enum PromptToolCapability: String, Codable, CaseIterable, Hashable {
    case title
    case body
    case search
    case generic

    var displayName: String {
        switch self {
        case .title: return "标题"
        case .body: return "正文"
        case .search: return "搜索"
        case .generic: return "通用"
        }
    }

    static func infer(fromName name: String, prompt: String) -> [PromptToolCapability] {
        let semantic = "\(name) \(prompt)".lowercased()
        var inferred: [PromptToolCapability] = []

        if containsAny(["标题", "title", "headline", "subject", "题目"], in: semantic) {
            inferred.append(.title)
        }
        if containsAny(["正文", "内容", "body", "content", "文案", "caption", "描述", "成稿", "article"], in: semantic) {
            inferred.append(.body)
        }
        if containsAny(["搜索", "search", "find", "query", "检索"], in: semantic) {
            inferred.append(.search)
        }

        if inferred.isEmpty {
            inferred = [.generic]
        }
        return Array(Set(inferred)).sorted(by: { $0.rawValue < $1.rawValue })
    }

    private static func containsAny(_ keywords: [String], in text: String) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }
}

/// Prompt Tool 数据模型
struct PromptTool: Identifiable, Codable {

    // MARK: - Properties

    /// 唯一标识符
    let id: UUID

    /// 工具名称
    var name: String

    /// Prompt 模板
    var prompt: String

    /// 工具能力标签（显式语义约束，优先于名称启发式）
    var capabilities: [PromptToolCapability]

    /// 快捷键虚拟键码
    var shortcutKeyCode: UInt16

    /// 快捷键修饰键标志
    var shortcutModifiers: UInt32

    /// 是否为预置工具
    let isDefault: Bool

    /// 创建时间
    let createdAt: Date

    /// 更新时间
    var updatedAt: Date

    // MARK: - Remote Tool Properties (v0.4)

    /// 工具来源
    var source: ToolSource

    /// 远程工具 ID（prompts.chat）
    var remoteId: String?

    /// 远程作者
    var remoteAuthor: String?

    /// 远程点赞数
    var remoteVotes: Int

    /// 远程更新时间
    var remoteUpdatedAt: Date?

    // MARK: - Langfuse Properties (v0.5)

    /// Langfuse prompt 名称（用于匹配更新）
    var langfuseName: String?

    /// Langfuse prompt 版本号
    var langfuseVersion: Int?

    /// Langfuse prompt 标签（如 "production", "staging"）
    var langfuseLabels: [String]

    /// 最后同步时间
    var lastSyncedAt: Date?

    // MARK: - Computed Properties

    /// 是否已配置快捷键
    var hasShortcut: Bool {
        return shortcutKeyCode != 0
    }

    /// 快捷键显示字符串
    var shortcutDisplayString: String {
        guard hasShortcut else { return "未设置" }

        var parts: [String] = []

        // 修饰键
        if (shortcutModifiers & UInt32(cmdKey)) != 0 {
            parts.append("⌘")
        }
        if (shortcutModifiers & UInt32(shiftKey)) != 0 {
            parts.append("⇧")
        }
        if (shortcutModifiers & UInt32(optionKey)) != 0 {
            parts.append("⌥")
        }
        if (shortcutModifiers & UInt32(controlKey)) != 0 {
            parts.append("⌃")
        }

        // 键码到字符的映射
        let keyChar = keyCodeToString(shortcutKeyCode)
        parts.append(keyChar)

        return parts.joined()
    }

    /// 是否为社区工具
    var isCommunityTool: Bool {
        return source == .community
    }

    /// 是否可更新（社区工具且有远程 ID）
    var isUpdatable: Bool {
        return isCommunityTool && remoteId != nil
    }

    /// 是否为 Langfuse 工具
    var isLangfuseTool: Bool {
        return source == .langfuse
    }

    /// 是否为云端管理的工具（只读）
    var isCloudManaged: Bool {
        return source == .langfuse
    }

    /// 是否为 Smart AI 工具
    var isSmart: Bool {
        return source == .smart
    }

    // MARK: - Clean Architecture Bridge Properties

    /// 工具 ID（值对象）
    var toolID: ToolID {
        return ToolID(id)
    }

    /// 快捷键组合（值对象）
    var keyCombo: KeyCombo? {
        guard hasShortcut else { return nil }
        return KeyCombo(keyCode: shortcutKeyCode, modifiers: shortcutModifiers)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        capabilities: [PromptToolCapability] = [],
        shortcutKeyCode: UInt16 = 0,
        shortcutModifiers: UInt32 = 0,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: ToolSource = .custom,
        remoteId: String? = nil,
        remoteAuthor: String? = nil,
        remoteVotes: Int = 0,
        remoteUpdatedAt: Date? = nil,
        langfuseName: String? = nil,
        langfuseVersion: Int? = nil,
        langfuseLabels: [String] = [],
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.capabilities = Array(Set(capabilities)).sorted(by: { $0.rawValue < $1.rawValue })
        self.shortcutKeyCode = shortcutKeyCode
        self.shortcutModifiers = shortcutModifiers
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.remoteId = remoteId
        self.remoteAuthor = remoteAuthor
        self.remoteVotes = remoteVotes
        self.remoteUpdatedAt = remoteUpdatedAt
        self.langfuseName = langfuseName
        self.langfuseVersion = langfuseVersion
        self.langfuseLabels = langfuseLabels
        self.lastSyncedAt = lastSyncedAt
    }
    
    // MARK: - Helper Methods
    
    /// 将虚拟键码转换为显示字符
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyCodeMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x31: " ", 0x32: "`",
            0x24: "↩", 0x30: "⇥", 0x33: "⌫", 0x35: "⎋",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑"
        ]
        
        return keyCodeMap[keyCode] ?? "?"
    }
}

// MARK: - Default Tools

extension PromptTool {

    /// 创建 Smart AI 工具单例
    /// - Parameter shortcutKeyCode: 快捷键键码（默认 0x09 = V 键）
    /// - Parameter shortcutModifiers: 快捷键修饰符（默认 ⌘⌃）
    /// - Returns: Smart AI PromptTool 实例
    static func createSmartAITool(
        shortcutKeyCode: UInt16 = 0x09,
        shortcutModifiers: UInt32 = UInt32(cmdKey | controlKey)
    ) -> PromptTool {
        return PromptTool(
            name: "Smart AI Recommendation",
            prompt: "", // 不使用 prompt，由 SmartToolManager 处理
            capabilities: [.generic],
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers,
            isDefault: true,
            source: .smart
        )
    }

    /// 预置的默认工具集合
    static let defaultTools: [PromptTool] = [
        PromptTool(
            name: "Markdown 格式化",
            prompt: """
            请将以下文本转换为规范的 Markdown 格式。要求：
            1. 正确使用标题层级（# ## ###）
            2. 代码块使用 ``` 包裹并标注语言
            3. 列表使用 - 或 1. 2. 3.
            4. 链接使用 [文字](URL) 格式
            5. 保持原文内容和语义不变

            重要：只输出转换后的内容本身，不要添加任何引导语、说明或额外文字。

            文本：
            """,
            capabilities: [.generic],
            isDefault: true,
            source: .builtin
        ),
        PromptTool(
            name: "表格生成",
            prompt: """
            请将以下内容整理为 Markdown 表格格式。要求：
            1. 自动识别列标题和数据行
            2. 对齐方式根据内容类型自动选择（数字右对齐，文字左对齐）
            3. 如果内容不适合做表格，请说明原因

            重要：只输出转换后的内容本身，不要添加任何引导语、说明或额外文字。

            内容：
            """,
            capabilities: [.generic],
            isDefault: true,
            source: .builtin
        ),
        PromptTool(
            name: "小红书成稿",
            prompt: """
            请将以下内容改写为小红书风格的帖子。要求：
            1. 仅改写正文内容，不生成标题，不拼接“标题+正文”
            2. 分段清晰，每段不超过 3 行
            3. 使用适量 emoji 增加可读性
            4. 结尾添加 3-5 个相关话题标签 #
            5. 语气亲切、有活力

            重要：只输出转换后的内容本身，不要添加任何引导语、说明或额外文字。

            原文：
            """,
            capabilities: [.body],
            isDefault: true
        ),
        PromptTool(
            name: "邮件规范化",
            prompt: """
            请将以下内容改写为专业的商务邮件格式。要求：
            1. 添加合适的称呼语
            2. 正文简洁明了，分段清晰
            3. 使用礼貌、专业的措辞
            4. 添加恰当的结束语
            5. 保持原文的核心信息不变

            重要：只输出转换后的内容本身，不要添加任何引导语、说明或额外文字。

            内容：
            """,
            capabilities: [.body],
            isDefault: true
        ),
        PromptTool(
            name: "提取标题",
            prompt: """
            请从以下文本中提取或生成一个简洁、准确的标题。要求：
            1. 标题长度不超过 20 个字
            2. 准确概括文本主旨
            3. 使用肯定句
            4. 避免使用标点符号

            重要：只输出转换后的内容本身，不要添加任何引导语、说明或额外文字。

            文本：
            """,
            capabilities: [.title],
            isDefault: true
        )
    ]
}
