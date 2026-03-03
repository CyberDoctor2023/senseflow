//
//  NotificationService.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - 通知服务接口】
//  这是一个简单但重要的接口，展示了"面向接口编程"的价值
//
//  为什么需要通知服务接口？
//  1. 跨平台：macOS 用 UserNotification，iOS 用 UNUserNotificationCenter
//  2. 可测试：测试时不需要真的弹出通知
//  3. 可替换：可以切换到其他通知方式（Toast、Banner、Console）
//
//  【接口设计原则】
//  1. 语义化方法名：showInProgress、showSuccess、showError
//     - 不是 show(type: .inProgress)，而是独立方法
//     - 为什么？更清晰、更易用、更难误用
//
//  2. 最小参数：只要 title 和 body
//     - 不暴露平台特定参数（sound、badge、category）
//     - 为什么？保持接口简单、平台无关
//
//  3. 同步方法：不需要 async
//     - 通知是"发射后不管"（Fire and Forget）
//     - 不需要等待通知显示完成
//
//  【对比不同的接口设计】
//
//  ❌ 设计 1：过于通用（失去语义）
//  ```swift
//  protocol NotificationService {
//      func show(title: String, body: String, type: NotificationType)
//  }
//  ```
//  问题：
//  - 调用时需要传递 type 参数
//  - 容易传错类型
//  - 不够语义化
//
//  ❌ 设计 2：过于复杂（暴露实现细节）
//  ```swift
//  protocol NotificationService {
//      func show(
//          title: String,
//          body: String,
//          sound: UNNotificationSound?,
//          badge: Int?,
//          category: String?
//      )
//  }
//  ```
//  问题：
//  - 暴露了 UserNotification 的实现细节
//  - 跨平台困难（iOS 和 macOS 参数不同）
//  - 调用复杂
//
//  ✅ 设计 3：语义化 + 最小化（当前设计）
//  ```swift
//  protocol NotificationService {
//      func showInProgress(title: String, body: String)
//      func showSuccess(title: String, body: String)
//      func showError(title: String, body: String)
//  }
//  ```
//  好处：
//  - 语义清晰：一看就知道是什么类型的通知
//  - 参数最小：只要必需的 title 和 body
//  - 平台无关：不暴露实现细节
//  - 易于使用：不会传错参数
//

import Foundation

/// 通知服务协议（Port）
///
/// 【职责】
/// 定义显示用户通知的能力
///
/// 【设计哲学】
/// "Tell, Don't Ask"（告诉，不要询问）
/// - 我们"告诉"通知服务显示通知
/// - 不"询问"通知服务是否可以显示
/// - 不关心通知是否真的显示了
///
/// 【实现者】
/// - UserNotificationAdapter：使用 macOS UserNotification
/// - MockNotificationService：测试实现（记录调用，不显示通知）
/// - ConsoleNotificationAdapter：控制台实现（打印到控制台）
/// - ToastNotificationAdapter：Toast 实现（轻量级提示）
///
/// 【使用场景】
/// 1. 工具执行开始：showInProgress("翻译", "正在处理...")
/// 2. 工具执行成功：showSuccess("翻译", "已完成")
/// 3. 工具执行失败：showError("翻译", "失败: API 错误")
protocol NotificationServiceProtocol: Sendable {
    /// 显示进行中通知
    ///
    /// 【使用时机】
    /// 长时间操作开始时，给用户即时反馈
    ///
    /// 【视觉效果】
    /// - 图标：⏳ 或进度指示器
    /// - 颜色：蓝色或中性色
    /// - 声音：无声或轻微提示音
    ///
    /// 【实现建议】
    /// - 不要阻塞主线程
    /// - 可以显示进度条（如果支持）
    /// - 可以自动消失（3-5 秒）
    ///
    /// - Parameters:
    ///   - title: 通知标题（例如："翻译"）
    ///   - body: 通知内容（例如："正在处理剪贴板内容..."）
    func showInProgress(title: String, body: String)

    /// 显示成功通知
    ///
    /// 【使用时机】
    /// 操作成功完成时，告知用户结果
    ///
    /// 【视觉效果】
    /// - 图标：✅ 或对勾
    /// - 颜色：绿色
    /// - 声音：成功提示音（可选）
    ///
    /// 【实现建议】
    /// - 自动消失（2-3 秒）
    /// - 可以点击查看详情
    /// - 可以撤销操作（如果支持）
    ///
    /// - Parameters:
    ///   - title: 通知标题（例如："翻译"）
    ///   - body: 通知内容（例如："已完成并写入剪贴板"）
    func showSuccess(title: String, body: String)

    /// 显示错误通知
    ///
    /// 【使用时机】
    /// 操作失败时，告知用户错误原因
    ///
    /// 【视觉效果】
    /// - 图标：❌ 或警告标志
    /// - 颜色：红色
    /// - 声音：错误提示音
    ///
    /// 【实现建议】
    /// - 不要自动消失（让用户有时间阅读）
    /// - 提供详细错误信息
    /// - 提供解决方案（如果可能）
    ///
    /// 【错误信息设计】
    /// ✅ 好的错误信息：
    /// - "API Key 无效，请在设置中配置"
    /// - "网络连接失败，请检查网络"
    /// - "剪贴板为空，请先复制内容"
    ///
    /// ❌ 不好的错误信息：
    /// - "错误"（太模糊）
    /// - "Error: 401"（技术术语）
    /// - "失败"（没有原因）
    ///
    /// - Parameters:
    ///   - title: 通知标题（例如："翻译"）
    ///   - body: 通知内容（例如："失败: API Key 无效"）
    func showError(title: String, body: String)
}

//
// 【扩展阅读】
//
// 接口演化（Interface Evolution）：
// 如果未来需要新功能怎么办？
//
// 方案 1：添加新方法（推荐）
// ```swift
// extension NotificationServiceProtocol {
//     func showWarning(title: String, body: String) {
//         // 默认实现：当作错误处理
//         showError(title: "⚠️ " + title, body: body)
//     }
// }
// ```
// 好处：
// - 不破坏现有实现
// - 提供默认行为
// - 可选实现
//
// 方案 2：添加可选参数（不推荐）
// ```swift
// func showSuccess(title: String, body: String, duration: TimeInterval = 3.0)
// ```
// 问题：
// - 破坏现有实现
// - 需要修改所有实现者
//
// 方案 3：创建新接口（适合大改）
// ```swift
// protocol NotificationServiceV2: NotificationServiceProtocol {
//     func show(notification: Notification)
// }
// ```
// 好处：
// - 保持旧接口兼容
// - 新功能用新接口
//
