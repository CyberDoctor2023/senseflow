//
//  Strings.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//  用户可见文本常量（支持国际化）
//

import Foundation

/// 用户可见文本 - 集中管理便于国际化
enum Strings {
    /// 通用按钮
    enum Buttons {
        static let cancel = "取消"
        static let confirm = "确定"
        static let skip = "跳过"
        static let continue_ = "继续"
        static let execute = "Execute"
        static let authorize = "授权"
        static let reset = "恢复默认"
    }

    /// Onboarding
    enum Onboarding {
        static let title = "欢迎使用 \(AppConstants.productName)"
        static let subtitle = "我们需要一些权限来提供最佳体验"
        static let mandatorySection = "必需权限"
        static let optionalSection = "Smart 功能权限（可选）"
        static let skipHint = "（点击跳过后下次启动不再显示）"
    }

    /// 权限
    enum Permissions {
        static let accessibility = "辅助功能权限"
        static let accessibilityDesc = "用于自动粘贴"
        static let screenRecording = "录屏权限"
        static let screenRecordingDesc = "用于 Smart 功能截图"
        static let notification = "通知权限"
        static let notificationDesc = "用于剪切板操作状态反馈"
    }

    /// 快捷键
    enum HotKey {
        static let title = "全局快捷键"
        static let recordingPrompt = "按下快捷键..."
        static let startRecording = "开始录制"
        static let recording = "录制中..."
        static let conflictTitle = "快捷键冲突"
        static let conflictMessage = "该快捷键已被其他应用占用，请选择其他组合。"
        static let successMessage = "✓ 快捷键已更新"
        static let helpText = "点击录制按钮或直接点击上方输入框，然后按下想要设置的快捷键组合"
    }

    /// Smart 推荐
    enum SmartRecommendation {
        static let title = "Smart Recommendation"
        static let toolLabel = "Tool:"
        static let reasonLabel = "Why:"
        static let confidenceLabel = "Confidence:"
    }

    /// 快捷键冲突
    enum HotKeyConflict {
        static let title = "快捷键冲突"
        static func message(_ hotKeyDisplay: String) -> String {
            """
            快捷键 \(hotKeyDisplay) 已被其他应用占用。

            可能的冲突来源：
            • 浏览器扩展（如 Grammarly）
            • 其他剪贴板工具
            • 系统快捷键设置

            请关闭冲突应用或在系统设置中修改其快捷键，然后重新启动本应用。
            """
        }
    }

    /// 辅助功能权限
    enum AccessibilityPermission {
        static let title = "需要辅助功能权限"
        static let message = "\(AppConstants.productName) 需要辅助功能权限来实现自动粘贴功能。\n\n点击「打开设置」后，在系统设置中勾选 \(AppConstants.productName)。"
        static let openSettings = "打开设置"
        static let later = "稍后"
    }

    /// 自动粘贴
    enum AutoPaste {
        static let manualPasteMessage = "请手动按 Cmd+V 粘贴"
        static let permissionRequired = "需要辅助功能权限才能自动粘贴。\n\n您可以在系统设置中授予权限。"
        static let understood = "知道了"
    }

    /// 窗口标题
    enum WindowTitles {
        static let onboardingSetup = "\(AppConstants.productName) 设置向导"
    }

    /// 通用设置
    enum GeneralSettings {
        static let historySection = "历史记录"
        static func historyLimitLabel(_ limit: Int) -> String {
            "历史记录上限: \(limit) 条"
        }
        static let historyLimitHelp = "最多保存多少条剪贴板历史记录"

        static let behaviorSection = "行为"
        static let autoPasteToggle = "启用自动粘贴"
        static let autoPasteHelp = "点击卡片后自动粘贴到目标应用（需要 Accessibility 权限）"
        static let launchAtLoginToggle = "开机自启动"
        static let launchAtLoginHelp = "系统启动时自动运行 \(AppConstants.productName)"

        static let previewRequirement = "需要 macOS 13.0+"
    }

    /// 隐私设置
    enum PrivacySettings {
        static let privacySection = "隐私权限"
        static let accessibilityGranted = "辅助功能权限已授予"
        static let accessibilityDenied = "辅助功能权限未授予"
        static let accessibilityDescription = "用于自动粘贴功能"
        static let screenRecordingGranted = "录屏权限已授予"
        static let screenRecordingDenied = "录屏权限未授予"
        static let screenRecordingDescription = "用于 Smart 功能截图"
        static let notificationGranted = "通知权限已授予"
        static let notificationDenied = "通知权限未授予"
        static let notificationDescription = "用于剪切板操作状态反馈"

        static let guideSection = "权限引导"
        static let guideStatus = "已跳过权限引导"
        static let guideDescription = "如需重新查看权限引导，请点击下方按钮"
        static let testButton = "测试权限检查"
        static let restoreGuideButton = "恢复权限引导"
        static let restoreGuideHelp = "下次启动时重新显示权限引导页"

        static let sensitiveDataSection = "敏感数据过滤"
        static let sensitiveDataDescription = "系统会自动过滤以下类型的剪贴板数据："
        static let sensitiveDataNote = "这些类型由密码管理器和系统自动标记，无需手动配置"

        static let appFilterSection = "应用过滤"
        static let appFilterDescription = "输入要过滤的应用名称（每行一个）"
        static let appFilterPlaceholder = "例如：Xcode, Terminal"
        static let appFilterHelp = "来自这些应用的剪贴板内容将不会被记录"

        static let previewFallback = "需要 macOS 13.0+"
    }

    /// 快捷键设置
    enum ShortcutSettings {
        static let sectionTitle = "全局快捷键"
        static let recorderHelp = "点击录制按钮设置快捷键"
        static let description = "设置用于打开剪贴板历史窗口的全局快捷键"
        static let previewFallback = "需要 macOS 13.0+"
    }

    /// 高级设置
    enum AdvancedSettings {
        static let textSelectionSection = "划词即复制"
        static let textSelectionToggle = "启用划词即复制"
        static let textSelectionDescription = "选中文本后自动复制到剪贴板历史"
        static func minLengthLabel(_ length: Int) -> String {
            "最小文本长度: \(length) 字符"
        }
        static let minLengthHelp = "只有选中文本长度达到此值才会自动复制"

        static let forcedExtractionToggle = "启用强制取词"
        static let forcedExtractionDescription = "当标准方法失败时，模拟 Cmd+C 强制复制（适用于 Electron 应用如 VSCode、Cursor）"
        static let forcedExtractionHelp = "提高兼容性，但可能触发系统提示音"

        static let sectionTitle = "重置设置"
        static let description = "将所有设置恢复为默认值，包括快捷键、历史记录限制、自动粘贴等"
        static let resetButton = "重置所有设置"
        static let resetButtonHelp = "此操作将清除所有自定义设置"
        static let successMessage = "设置已重置"

        static let confirmTitle = "确认重置"
        static let confirmMessage = "此操作将清除所有自定义设置，包括快捷键、历史记录限制等。是否继续？"
        static let confirmButton = "重置"
        static let cancelButton = "取消"

        static let previewFallback = "需要 macOS 13.0+"
    }

    /// Smart AI 设置
    enum SmartAISettings {
        static let title = "Smart AI"
        static let subtitle = "智能剪贴板助手"
        static let description = "Smart AI 可以根据剪贴板内容智能推荐合适的 Prompt Tool，帮助您更高效地处理文本。"

        static let configSection = "基本配置"
        static let enableToggle = "启用 Smart AI"
        static let enableHelp = "开启后，复制内容时会自动分析并推荐合适的工具"
        static let shortcutLabel = "快捷键"
        static let shortcutKey = "⌘⌃V"
        static let shortcutHelp = "使用此快捷键快速调用 Smart AI"
        static let lightweightToggle = "轻量模式"
        static let lightweightDescription = "仅发送文本内容，不包含截图（节省 API 调用成本）"

        static let permissionSection = "权限状态"
        static let screenRecordingTitle = "屏幕录制权限"
        static let permissionGranted = "已授予"
        static let permissionDenied = "未授予"
        static let openGuideButton = "打开权限引导"
        static let permissionDescription = "Smart AI 需要屏幕录制权限来截取当前窗口内容"

        static let previewFallback = "需要 macOS 13.0+"
    }

    /// Prompt Tools 设置
    enum PromptToolsSettings {
        static let aiServiceSection = "AI 服务配置"
        static let aiServicePicker = "AI 服务"
        static let aiServiceHelp = "选择用于 Prompt Tools 的 AI 服务"
        static let apiKeyPlaceholder = "API Key"
        static func apiKeyHelp(_ serviceName: String) -> String {
            "输入 \(serviceName) 的 API Key"
        }
        static let modelPlaceholder = "模型名称（例如 gpt-4.1 / gemini-2.5-pro）"
        static func modelHelp(_ serviceName: String, _ fallback: String) -> String {
            "设置 \(serviceName) 的模型（留空将使用默认：\(fallback)）"
        }
        static let saveButtonDefault = "保存配置"
        static let saveButtonSaved = "已保存"
        static let saveButtonHelp = "保存当前服务的 API Key 与模型配置"
        static let unsavedChanges = "有未保存的更改"
        static let testConnectionButton = "测试连接"
        static let testConnectionHelp = "测试 API 连接是否正常"
        static let connectionSuccess = "连接成功"
        static let toolsSection = "Prompt Tools"
        static let emptyToolsMessage = "暂无自定义 Tool，点击下方按钮添加"
        static let toolCopySuffix = " (副本)"
        static let previewFallback = "需要 macOS 13.0+"
    }

    /// 开发者选项
    enum DeveloperOptions {
        static let sectionHeader = "Langfuse 集成"
        static let langfuseTitle = "Langfuse"
        static let langfuseDescription = "连接到 Langfuse 进行 LLM 调用追踪和分析"

        static let publicKeyPlaceholder = "Public Key"
        static let secretKeyPlaceholder = "Secret Key"

        static func syncIntervalText(_ minutes: Int) -> String {
            "同步间隔: \(minutes) 分钟"
        }

        static let labelFieldTitle = "Active Label"
        static let labelPlaceholder = "production"

        static let saveButtonDefault = "保存密钥"
        static let saveButtonSaved = "已保存"
        static let saveButtonHelp = "保存 Langfuse 公钥和私钥"
        static let unsavedChanges = "有未保存的更改"

        static let syncNowButton = "立即同步"

        static let previewFallback = "需要 macOS 13.0+"
    }
}
