//
//  ClipboardReader.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - Port 层（端口层）】
//  这是 Clean Architecture 和 Hexagonal Architecture 的核心概念
//
//  什么是 Port（端口）？
//  - Port 是一个接口（Protocol），定义了业务逻辑需要的能力
//  - Port 不关心具体实现，只定义"做什么"，不定义"怎么做"
//
//  为什么需要 Port？
//  1. 依赖倒置原则（DIP）：高层模块不依赖低层模块，都依赖抽象
//  2. 解耦：业务逻辑不依赖具体的框架（NSPasteboard、UIPasteboard）
//  3. 可测试：可以用 Mock 实现替换真实实现
//  4. 可替换：可以轻松切换不同的实现
//
//  六边形架构（Hexagonal Architecture）：
//  ```
//  ┌─────────────────────────────────────┐
//  │         Business Logic              │
//  │    (Use Cases, Domain Logic)        │
//  │                                     │
//  │  依赖 → ClipboardReader (Port)      │
//  └─────────────────────────────────────┘
//              ↑ 依赖方向
//              │
//  ┌───────────┴─────────────┐
//  │  NSPasteboardAdapter    │  ← Adapter（适配器）
//  │  (实现 ClipboardReader)  │
//  └─────────────────────────┘
//              ↓
//  ┌─────────────────────────┐
//  │    NSPasteboard         │  ← 外部框架
//  │  (macOS Framework)      │
//  └─────────────────────────┘
//  ```
//
//  对比传统方式：
//  ❌ 传统方式（紧耦合）：
//  ```swift
//  class ExecutePromptTool {
//      func execute() {
//          let text = NSPasteboard.general.string(forType: .string)  // 直接依赖 NSPasteboard
//      }
//  }
//  ```
//  问题：
//  - 无法在 iOS 上运行（iOS 用 UIPasteboard）
//  - 无法单元测试（依赖真实剪贴板）
//  - 无法 Mock（紧耦合）
//
//  ✅ Port 方式（松耦合）：
//  ```swift
//  class ExecutePromptTool {
//      private let clipboardReader: ClipboardReader  // 依赖接口
//
//      func execute() {
//          let text = clipboardReader.readText()  // 不关心具体实现
//      }
//  }
//  ```
//  好处：
//  - 跨平台：macOS 用 NSPasteboardAdapter，iOS 用 UIPasteboardAdapter
//  - 可测试：测试时用 MockClipboardReader
//  - 可替换：可以切换到其他剪贴板实现
//

import Foundation

/// 剪贴板读取协议（Port）
///
/// 【职责】
/// 定义读取剪贴板内容的能力
///
/// 【设计原则】
/// 1. 接口隔离原则（ISP）：只定义读取能力，不包含写入
/// 2. 最小接口：只暴露必要的方法
/// 3. 平台无关：不依赖 macOS/iOS 特定 API
///
/// 【实现者】
/// - NSPasteboardAdapter：macOS 实现（使用 NSPasteboard）
/// - MockClipboardReader：测试实现（返回预设数据）
/// - 未来可能：UIPasteboardAdapter（iOS）、WebClipboardAdapter（Web）
///
/// 【Sendable 协议】
/// Sendable 表示这个类型可以安全地在并发环境中传递
/// 这是 Swift 6 的并发安全要求
protocol ClipboardReader: Sendable {
    /// 读取文本内容
    ///
    /// 【返回值】
    /// - 如果剪贴板包含文本：返回文本内容
    /// - 如果剪贴板为空或不包含文本：返回 nil
    ///
    /// 【使用场景】
    /// 最常用的方法，大多数工具只需要文本内容
    func readText() -> String?

    /// 读取内容（通用）
    ///
    /// 【返回值】
    /// 返回 ClipboardContent 对象，包含所有类型的内容
    /// - 文本
    /// - 图片
    /// - 文件路径
    /// - 等等
    ///
    /// 【使用场景】
    /// 需要处理多种类型内容时使用（例如 Smart AI）
    func readContent() -> ClipboardContent
}

/// 剪贴板写入协议（Port）
///
/// 【为什么分离 Reader 和 Writer？】
/// 这是接口隔离原则（ISP）的体现：
/// - 有些组件只需要读取（例如上下文收集器）
/// - 有些组件只需要写入（例如结果输出器）
/// - 分离接口让依赖更清晰
///
/// 【对比合并接口】
/// ❌ 合并接口（违反 ISP）：
/// ```swift
/// protocol Clipboard {
///     func readText() -> String?
///     func write(_ text: String)
/// }
/// ```
/// 问题：
/// - 只需要读取的组件也被迫依赖写入能力
/// - 测试时需要 Mock 不需要的方法
///
/// ✅ 分离接口（符合 ISP）：
/// ```swift
/// protocol ClipboardReader { func readText() -> String? }
/// protocol ClipboardWriter { func write(_ text: String) }
/// ```
/// 好处：
/// - 依赖最小化
/// - 测试更简单
/// - 职责更清晰
protocol ClipboardWriter: Sendable {
    /// 写入文本
    ///
    /// 【异步方法】
    /// 为什么是 async？
    /// - 写入剪贴板可能涉及主线程操作
    /// - 避免阻塞当前线程
    ///
    /// 【使用场景】
    /// 工具执行完成后，将结果写入剪贴板
    func write(_ text: String) async

    /// 写入内容（通用）
    ///
    /// 【使用场景】
    /// 需要写入非文本内容时使用（例如图片、文件）
    func write(_ content: ClipboardContent) async
}
