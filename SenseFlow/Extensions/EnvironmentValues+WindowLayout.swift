//
//  EnvironmentValues+WindowLayout.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import SwiftUI

/// 扩展 EnvironmentValues 以支持窗口布局配置
/// 使用 @Entry 宏（Swift 5.9+）创建自定义环境值
extension EnvironmentValues {

    /// 窗口布局配置环境值
    /// 可在视图层级中传播和覆盖
    ///
    /// 使用示例：
    /// ```swift
    /// // 在父视图中设置
    /// ContentView()
    ///     .environment(\.windowLayoutConfig, customConfig)
    ///
    /// // 在子视图中读取
    /// @Environment(\.windowLayoutConfig) var layoutConfig
    /// ```
    @Entry var windowLayoutConfig: WindowLayoutConfigurable = WindowLayoutConfig.default
}

/// 视图扩展：提供便捷的配置方法
extension View {

    /// 设置窗口布局配置
    /// - Parameter config: 窗口布局配置
    /// - Returns: 应用了配置的视图
    func windowLayoutConfig(_ config: WindowLayoutConfigurable) -> some View {
        environment(\.windowLayoutConfig, config)
    }
}
