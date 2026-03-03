//
//  AppLogger.swift
//  SenseFlow
//
//  Created by Claude
//  Lazy logging system to avoid unnecessary string construction
//

import Foundation

/// 日志级别
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var prefix: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// 优化的日志工具类
/// - 使用 @autoclosure 避免无效的字符串拼接
/// - 提供 isEnabled() 检查避免昂贵的日志构造
final class AppLogger {
    /// 最小日志级别（低于此级别的日志不会输出）
    private let minimumLogLevel: LogLevel

    /// 日志分类
    private let category: String

    /// 创建日志实例
    /// - Parameters:
    ///   - category: 日志分类（如 "ClipboardMonitor", "FloatingWindow"）
    ///   - minimumLevel: 最小日志级别
    init(category: String, minimumLevel: LogLevel = .debug) {
        self.category = category
        self.minimumLogLevel = minimumLevel
    }

    // MARK: - 日志方法（使用 @autoclosure 延迟执行）

    /// Debug 级别日志
    func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message, level: .debug, file: file, line: line)
    }

    /// Info 级别日志
    func info(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message, level: .info, file: file, line: line)
    }

    /// Warning 级别日志
    func warning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message, level: .warning, file: file, line: line)
    }

    /// Error 级别日志
    func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message, level: .error, file: file, line: line)
    }

    // MARK: - 级别检查

    /// 检查指定级别的日志是否启用
    /// - Parameter level: 日志级别
    /// - Returns: 是否启用
    func isEnabled(_ level: LogLevel) -> Bool {
        level >= minimumLogLevel
    }

    // MARK: - 私有方法

    /// 内部日志方法
    /// - Parameters:
    ///   - message: 日志消息（延迟执行）
    ///   - level: 日志级别
    ///   - file: 文件名
    ///   - line: 行号
    private func log(_ message: () -> String, level: LogLevel, file: String, line: Int) {
        // 提前检查级别，避免执行 message()
        guard level >= minimumLogLevel else { return }

        // 只有通过级别检查才执行消息构造
        let resolvedMessage = message()

        let fileName = (file as NSString).lastPathComponent
        print("\(level.prefix) [\(category)] \(resolvedMessage) (\(fileName):\(line))")
    }
}

// MARK: - 全局日志实例

/// 全局日志实例（可根据需要创建更多分类）
extension AppLogger {
    /// 剪贴板监听日志
    static let clipboard = AppLogger(category: "Clipboard")

    /// 浮动窗口日志
    static let window = AppLogger(category: "Window")

    /// 数据库日志
    static let database = AppLogger(category: "Database")

    /// AI 服务日志
    static let ai = AppLogger(category: "AI")

    /// 通用日志
    static let general = AppLogger(category: "General")
}
