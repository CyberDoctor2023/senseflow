//
//  WindowConfigurator.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import Cocoa

/// 窗口配置器：负责配置窗口属性
/// 职责：设置窗口层级、透明度、行为等属性
final class WindowConfigurator {

    /// 配置面板属性
    func configurePanel(_ panel: NSPanel) {
        configureWindowLevel(panel)
        configureTransparency(panel)
        configureBehavior(panel)
    }

    /// 配置窗口层级
    /// 使用 .popUpMenu 层级：专门设计用于显示在 Dock 之上的弹出 UI
    /// 窗口层级（从低到高）：
    /// - .dock (Dock)
    /// - .normal (普通窗口)
    /// - .floating (浮动面板)
    /// - .modalPanel (模态面板)
    /// - .popUpMenu (弹出菜单) ← 我们使用这个
    /// - .statusBar (状态栏)
    /// - IME 输入法（更高层级，系统管理）
    private func configureWindowLevel(_ panel: NSPanel) {
        panel.level = .popUpMenu
    }

    /// 配置透明度属性
    private func configureTransparency(_ panel: NSPanel) {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // 禁用系统阴影，让 glassEffect 独立渲染阴影
        // 系统阴影会与 glassEffect 阴影冲突，产生锯齿状边缘
        panel.hasShadow = false
    }

    /// 配置窗口行为
    private func configureBehavior(_ panel: NSPanel) {
        panel.animationBehavior = .none  // 禁用系统自动动画，使用手动控制
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false  // 不自动隐藏（手动控制）
    }
}
