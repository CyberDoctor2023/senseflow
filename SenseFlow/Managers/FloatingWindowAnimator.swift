//
//  FloatingWindowAnimator.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Cocoa

/// 悬浮窗口动画器（负责窗口显示/隐藏动画）
/// - Warning: 动画参数（duration / timingFunction / slideOffset）和动画逻辑已调优，禁止修改。
///   调用方只能控制调用时序，不得更改此文件中的任何动画实现。
struct FloatingWindowAnimator {

    // MARK: - Animation Constants

    /// 动画时长
    static let duration: TimeInterval = 0.35

    /// 动画时间函数（自定义贝塞尔曲线）
    static let timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 1.0, 0.89, 1.0)

    /// 滑动偏移量
    static let slideOffset: CGFloat = 30

    // MARK: - Animation Methods

    /// 统一的滑入动画（淡入 + 上滑）
    /// - Parameters:
    ///   - window: 要显示的窗口
    ///   - makeKey: 是否让窗口成为 key window（默认 true）
    ///   - completion: 动画完成回调
    static func animateSlideIn(window: NSPanel, makeKey: Bool = true, completion: (() -> Void)? = nil) {
        // 设置初始状态：完全透明 + 向下偏移
        window.alphaValue = 0.0
        var frame = window.frame
        let initialY = frame.origin.y - slideOffset
        frame.origin.y = initialY
        window.setFrame(frame, display: false)

        // 显示窗口（此时不可见）
        window.orderFront(nil)
        if makeKey {
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)

        // 执行淡入 + 上移动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = timingFunction

            var finalFrame = window.frame
            finalFrame.origin.y = initialY + slideOffset
            window.animator().setFrame(finalFrame, display: true)
            window.animator().alphaValue = 1.0
        }, completionHandler: {
            completion?()
        })
    }

    /// 统一的滑出动画（淡出 + 下滑）
    static func animateSlideOut(window: NSPanel, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = timingFunction

            var finalFrame = window.frame
            finalFrame.origin.y -= slideOffset
            window.animator().setFrame(finalFrame, display: true)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            completion?()
        })
    }
}
