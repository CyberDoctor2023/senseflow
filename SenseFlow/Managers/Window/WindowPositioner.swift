//
//  WindowPositioner.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import Cocoa

/// 窗口定位器：负责计算窗口位置和尺寸
/// 职责：检测活跃屏幕、计算窗口 frame、动态调整窗口位置
final class WindowPositioner {

    private let layoutConfig: WindowLayoutConfigurable
    private var lastScreen: NSScreen?  // 缓存上次使用的屏幕（避免不必要的 setFrame 调用）

    init(layoutConfig: WindowLayoutConfigurable) {
        self.layoutConfig = layoutConfig
    }

    /// 检测活跃屏幕（鼠标所在屏幕）
    func detectActiveScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
        return targetScreen
    }

    /// 计算窗口在目标屏幕上的 frame
    func calculateWindowFrame(for screen: NSScreen, windowHeight: CGFloat) -> NSRect {
        let screenFrame = screen.frame
        let inset = layoutConfig.mainContainer.screenEdgeInset
        let width = layoutConfig.unifiedWindowWidth(for: screenFrame.width)
        let height = windowHeight
        let x = screenFrame.origin.x + inset - Constants.ClipboardWindow.shadowBleedHorizontal
        let y = screenFrame.origin.y + inset - Constants.ClipboardWindow.shadowBleedBottom
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// 动态调整窗口尺寸和位置（支持多显示器）
    func resizeAndPositionWindow(_ window: NSWindow, windowHeight: CGFloat) {
        // 检测鼠标所在屏幕
        let targetScreen = detectActiveScreen() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = targetScreen else { return }

        let newFrame = calculateWindowFrame(for: screen, windowHeight: windowHeight)
        if window.frame != newFrame {
            window.setFrame(newFrame, display: true, animate: false)
        }
        lastScreen = screen
    }

    /// 清除屏幕缓存（用于屏幕配置变化时）
    func clearScreenCache() {
        lastScreen = nil
    }
}
