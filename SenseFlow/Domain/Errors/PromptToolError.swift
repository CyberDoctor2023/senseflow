//
//  PromptToolError.swift
//  SenseFlow
//
//  Created on 2026-02-03.
//  Domain error types for Prompt Tool operations
//

import Foundation

/// Prompt Tool 执行错误
enum PromptToolError: LocalizedError {
    case emptyClipboard
    case aiServiceNotConfigured
    case apiError(String)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .emptyClipboard:
            return "剪贴板为空或不包含文本内容"
        case .aiServiceNotConfigured:
            return "AI 服务未配置，请先在设置中配置 API Key"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .timeout:
            return "请求超时，请稍后重试"
        }
    }
}
