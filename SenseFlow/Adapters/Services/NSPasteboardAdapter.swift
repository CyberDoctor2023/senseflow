//
//  NSPasteboardAdapter.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - Adapter 层（适配器层）】
//  这是六边形架构（Hexagonal Architecture）的核心概念
//
//  什么是 Adapter（适配器）？
//  - Adapter 是一个"翻译器"，将外部框架的 API 翻译成我们的接口
//  - 它实现了 Port（接口），但内部调用外部框架
//
//  为什么需要 Adapter？
//  1. 隔离外部依赖：业务逻辑不直接依赖 NSPasteboard
//  2. 统一接口：不同平台用不同 Adapter，但接口相同
//  3. 易于测试：可以用 MockAdapter 替换真实 Adapter
//  4. 易于迁移：切换框架只需修改 Adapter
//
//  【六边形架构可视化】
//  ```
//  ┌─────────────────────────────────────────┐
//  │         Business Logic (核心)            │
//  │                                         │
//  │  ExecutePromptTool                      │
//  │    ↓ 依赖                               │
//  │  ClipboardReader (Port/接口)            │
//  └─────────────────────────────────────────┘
//              ↑ 实现
//              │
//  ┌───────────┴─────────────────────────────┐
//  │  NSPasteboardAdapter (Adapter/适配器)    │  ← 这个文件
//  │  - 实现 ClipboardReader 接口             │
//  │  - 调用 NSPasteboard API                │
//  └─────────────────────────────────────────┘
//              ↓ 调用
//  ┌─────────────────────────────────────────┐
//  │  NSPasteboard (外部框架)                 │
//  │  - macOS 系统 API                       │
//  │  - 我们无法控制                          │
//  └─────────────────────────────────────────┘
//  ```
//
//  【对比紧耦合方式】
//  ❌ 紧耦合（直接使用 NSPasteboard）：
//  ```swift
//  class ExecutePromptTool {
//      func execute() {
//          let text = NSPasteboard.general.string(forType: .string)  // 直接依赖
//      }
//  }
//  ```
//  问题：
//  - 无法在 iOS 上运行（iOS 用 UIPasteboard）
//  - 无法测试（依赖真实剪贴板）
//  - 业务逻辑和框架紧耦合
//
//  ✅ 松耦合（使用 Adapter）：
//  ```swift
//  class ExecutePromptTool {
//      private let clipboardReader: ClipboardReader  // 依赖接口
//
//      func execute() {
//          let text = clipboardReader.readText()  // 不知道具体实现
//      }
//  }
//  ```
//  好处：
//  - 跨平台：macOS 用 NSPasteboardAdapter，iOS 用 UIPasteboardAdapter
//  - 可测试：测试时用 MockClipboardReader
//  - 业务逻辑和框架解耦
//
//  【Adapter Pattern 适配器模式】
//  这是 GoF 23 种设计模式之一
//  目的：将一个类的接口转换成客户期望的另一个接口
//
//  现实类比：
//  - 电源适配器：将 220V 转换成 5V（手机充电）
//  - 语言翻译：将英语翻译成中文
//  - 这个 Adapter：将 NSPasteboard API 翻译成 ClipboardReader 接口
//

import AppKit

/// NSPasteboard 适配器
///
/// 【职责】
/// 将 macOS 的 NSPasteboard API 适配到我们的 ClipboardReader/Writer 接口
///
/// 【实现的接口】
/// - ClipboardReader：读取剪贴板内容
/// - ClipboardWriter：写入剪贴板内容
///
/// 【为什么实现两个接口？】
/// 因为 NSPasteboard 同时支持读和写
/// 如果分成两个 Adapter，会有重复代码
///
/// 【设计模式】
/// 1. Adapter Pattern（适配器模式）：适配外部 API
/// 2. Facade Pattern（外观模式）：简化复杂的 NSPasteboard API
///
/// 【依赖】
/// - NSPasteboard：macOS 系统剪贴板 API
/// - ClipboardMonitor：监听剪贴板变化（避免自捕获）
final class NSPasteboardAdapter: ClipboardReader, ClipboardWriter {
    /// 剪贴板监听器
    ///
    /// 【为什么需要 monitor？】
    /// 当我们写入剪贴板时，会触发剪贴板变化事件
    /// 如果不暂停监听，会导致"自捕获"：
    /// 1. 工具写入剪贴板
    /// 2. 触发剪贴板变化事件
    /// 3. 保存到历史记录
    /// 4. 用户看到重复的历史记录
    ///
    /// 解决方案：写入前暂停监听 1.5 秒
    private let monitor: ClipboardMonitor

    /// 构造器注入
    ///
    /// 【依赖注入】
    /// 即使是 Adapter 也使用依赖注入
    /// 不直接使用 ClipboardMonitor.shared
    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    // MARK: - ClipboardReader（实现读取接口）
    //
    // 【接口实现】
    // 这些方法实现了 ClipboardReader 协议
    // 调用者只知道接口，不知道这是 NSPasteboard

    /// 读取文本内容
    ///
    /// 【实现细节】
    /// 直接调用 NSPasteboard.general.string(forType: .string)
    ///
    /// 【返回值】
    /// - 如果剪贴板包含文本：返回文本
    /// - 如果剪贴板为空或不包含文本：返回 nil
    ///
    /// 【为什么这么简单？】
    /// 因为 NSPasteboard API 已经很简单了
    /// Adapter 的作用是"适配"，不是"增强"
    func readText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// 读取内容（通用）
    ///
    /// 【实现细节】
    /// 按优先级读取不同类型的内容：
    /// 1. 文本（最常用）
    /// 2. 图片（TIFF 或 PNG）
    /// 3. 文件（URL）
    /// 4. 空（没有内容）
    ///
    /// 【为什么有优先级？】
    /// 剪贴板可能同时包含多种类型
    /// 例如：复制一张图片，可能同时有图片数据和文件路径
    /// 我们优先返回最有用的类型
    ///
    /// 【Domain Model】
    /// 返回 ClipboardContent 枚举（领域模型）
    /// 而不是 NSPasteboard 的类型
    /// 这样业务逻辑不依赖 AppKit
    func readContent() -> ClipboardContent {
        let pasteboard = NSPasteboard.general

        // 【优先级 1】读取文本
        if let text = pasteboard.string(forType: .string) {
            return .text(text)
        }

        // 【优先级 2】读取图片
        // 支持 TIFF 和 PNG 两种格式
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            return .image(imageData)
        }

        // 【优先级 3】读取文件
        // 使用 readObjects 读取 URL 对象
        if let fileURL = pasteboard.readObjects(forClasses: [NSURL.self])?.first as? URL {
            return .file(fileURL)
        }

        // 【优先级 4】空内容
        return .empty
    }

    // MARK: - ClipboardWriter（实现写入接口）
    //
    // 【线程安全】
    // 写入剪贴板必须在主线程执行
    // 使用 @MainActor.run 确保线程安全

    /// 写入文本
    ///
    /// 【实现步骤】
    /// 1. 切换到主线程（NSPasteboard 要求）
    /// 2. 暂停监听（避免自捕获）
    /// 3. 清空剪贴板
    /// 4. 写入文本
    ///
    /// 【为什么是 async？】
    /// 因为需要切换到主线程（await MainActor.run）
    ///
    /// 【为什么要清空？】
    /// NSPasteboard 不会自动清空旧内容
    /// 如果不清空，可能会有多种类型的内容混在一起
    func write(_ text: String) async {
        await MainActor.run {
            // 【步骤 1】忽略下一次剪贴板变化
            // 避免写入触发剪贴板变化事件
            monitor.ignoreNextChange()

            // 【步骤 2】获取系统剪贴板
            let pasteboard = NSPasteboard.general

            // 【步骤 3】清空旧内容
            pasteboard.clearContents()

            // 【步骤 4】写入新内容
            pasteboard.setString(text, forType: .string)
        }
    }

    /// 写入内容（通用）
    ///
    /// 【实现细节】
    /// 根据 ClipboardContent 的类型，调用不同的 NSPasteboard API
    ///
    /// 【模式匹配】
    /// 使用 Swift 的 switch 语句匹配枚举
    /// 这是类型安全的，编译器会检查是否处理了所有情况
    func write(_ content: ClipboardContent) async {
        await MainActor.run {
            // 忽略下一次剪贴板变化
            monitor.ignoreNextChange()

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            // 【模式匹配】
            // 根据内容类型调用不同的 API
            switch content {
            case .text(let text):
                // 写入文本
                pasteboard.setString(text, forType: .string)

            case .image(let data):
                // 写入图片（TIFF 格式）
                pasteboard.setData(data, forType: .tiff)

            case .file(let url):
                // 写入文件 URL
                pasteboard.writeObjects([url as NSURL])

            case .empty:
                // 空内容：不写入任何东西
                break
            }
        }
    }
}

//
// 【扩展阅读】
//
// Adapter 的职责边界：
// 1. ✅ 应该做：转换接口、调用外部 API
// 2. ❌ 不应该做：业务逻辑、数据验证、复杂计算
//
// 例如：
// ✅ 好的 Adapter：
// ```swift
// func readText() -> String? {
//     return NSPasteboard.general.string(forType: .string)
// }
// ```
//
// ❌ 不好的 Adapter（包含业务逻辑）：
// ```swift
// func readText() -> String? {
//     let text = NSPasteboard.general.string(forType: .string)
//     // ❌ 业务逻辑不应该在 Adapter 中
//     if text?.isEmpty == true {
//         showError("剪贴板为空")
//         return nil
//     }
//     return text
// }
// ```
//
// Adapter 的测试策略：
// 1. 单元测试：测试 Adapter 是否正确调用外部 API
// 2. 集成测试：测试 Adapter 和外部框架的集成
// 3. Mock 测试：在测试业务逻辑时，用 Mock 替换 Adapter
//
// 跨平台支持：
// - macOS: NSPasteboardAdapter
// - iOS: UIPasteboardAdapter（未来）
// - Web: WebClipboardAdapter（未来）
// - 测试: MockClipboardAdapter
//
// 所有 Adapter 实现相同的接口（ClipboardReader/Writer）
// 业务逻辑代码无需修改，只需切换 Adapter
//
