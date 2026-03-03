//
//  OnboardingWindowManager.swift
//  SenseFlow
//
//  Created on 2026-02-04.
//

import Cocoa
import SwiftUI

/// Onboarding 窗口管理器（单例）
class OnboardingWindowManager {

    // MARK: - Singleton

    static let shared = OnboardingWindowManager()

    // MARK: - Properties

    private var window: NSWindow?

    // MARK: - Window Constants

    private let windowTitle = Strings.WindowTitles.onboardingSetup

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 显示 Onboarding 窗口
    func showWindow() {
        // 如果窗口已存在且可见，直接激活
        if let existingWindow = window, existingWindow.isVisible {
            print("🔧 [Debug] Reusing existing visible onboarding window")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ Onboarding 窗口已显示（已存在）")
            return
        }

        // 创建新窗口
        print("🔧 [Debug] Creating new onboarding window")
        let window = createWindow()

        // 保存窗口引用
        self.window = window
        print("🔧 [Debug] Window reference saved")

        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ Onboarding 窗口已创建并显示")
        print("🔧 [Debug] Window visible: \(window.isVisible)")
    }

    // MARK: - Private Methods

    /// 创建 Onboarding 窗口
    private func createWindow() -> NSWindow {
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)

        let windowSize = Constants.DialogWindow.onboarding
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = windowTitle
        window.titlebarAppearsTransparent = true
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        return window
    }
}
