//
//  DependencyEnvironment.swift
//  SenseFlow
//
//  Created on 2026-02-03.
//  SwiftUI 环境对象：为 SwiftUI 视图提供依赖注入
//

import SwiftUI

/// SwiftUI 依赖环境（用于 @EnvironmentObject）
///
/// 职责：
/// - 包装 DependencyContainer 为 ObservableObject
/// - 为 SwiftUI 视图提供依赖注入
/// - 暴露 Coordinators 给视图层
///
/// 使用方式：
/// ```swift
/// @StateObject private var dependencies = DependencyEnvironment()
///
/// var body: some Scene {
///     Settings {
///         SettingsView()
///             .environmentObject(dependencies)
///     }
/// }
/// ```
final class DependencyEnvironment: ObservableObject {

    /// 内部依赖容器
    let container: DependencyContainer

    /// Prompt Tool 协调器
    var promptToolCoordinator: PromptToolCoordinator {
        container.promptToolCoordinator
    }

    /// Smart Tool 协调器
    var smartToolCoordinator: SmartToolCoordinator {
        container.smartToolCoordinator
    }

    /// 用户可见 AI API 配置服务（不包含 Langfuse）
    var userAPISettingsService: UserAPISettingsServiceProtocol {
        container.userAPISettingsService
    }

    /// API 请求展示服务（开发者面板）
    var apiRequestInspectionService: APIRequestInspectionService {
        container.apiRequestInspectionService
    }

    init() {
        self.container = DependencyContainer()
    }
}
