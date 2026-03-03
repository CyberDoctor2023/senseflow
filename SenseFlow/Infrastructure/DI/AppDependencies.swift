//
//  AppDependencies.swift
//  SenseFlow
//
//  Created on 2026-02-03.
//  受控单例：为非 SwiftUI 组件提供依赖注入
//

import Foundation

/// 全局依赖容器（受控单例，仅用于非 SwiftUI 上下文）
///
/// ⚠️ 重要说明：
/// - 这是一个**受控单例**，只能在应用启动时初始化一次
/// - SwiftUI 视图应该使用 `@EnvironmentObject DependencyEnvironment`
/// - 只有 AppDelegate 等非 SwiftUI 组件才应该使用这个单例
/// - 这是对 `@NSApplicationDelegateAdaptor` 限制的妥协方案
///
/// 使用场景：
/// - ✅ AppDelegate（无法使用 @EnvironmentObject）
/// - ✅ 旧的 Manager 类（迁移期间）
/// - ❌ SwiftUI 视图（应该使用 @EnvironmentObject）
/// - ❌ 新代码（应该使用构造器注入）
class AppDependencies {
    private static var _shared: AppDependencies?

    /// 获取共享实例
    /// - Warning: 只能在 `setSharedContainer()` 调用后使用
    static var shared: AppDependencies {
        guard let instance = _shared else {
            fatalError("AppDependencies.shared accessed before initialization. Call setSharedContainer() first.")
        }
        return instance
    }

    /// 设置共享容器（只能调用一次，在应用启动时）
    /// - Parameter container: 依赖容器
    static func setSharedContainer(_ container: DependencyContainer) {
        guard _shared == nil else {
            print("⚠️ AppDependencies.setSharedContainer() called multiple times. Ignoring.")
            return
        }
        _shared = AppDependencies(container: container)
        print("✅ AppDependencies initialized with DI container")
    }

    private let container: DependencyContainer

    var promptToolCoordinator: PromptToolCoordinator {
        container.promptToolCoordinator
    }

    var smartToolCoordinator: SmartToolCoordinator {
        container.smartToolCoordinator
    }

    private init(container: DependencyContainer) {
        self.container = container
    }
}
