//
//  SenseFlowApp.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-23.
//  Migration to SwiftUI App architecture for native Settings scene support
//

import SwiftUI

@main
struct SenseFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// 设置数据模型（App 层创建，通过 .environment() 注入，对标 Landmarks 的 ModelData）
    @State private var settingsModel = SettingsModel()

    var body: some Scene {
        // MenuBarExtra for status bar icon with animated dots
        MenuBarExtra {
            MenuBarContentView()
                .font(.pingFang(size: 13))
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.menu)

        // 设置窗口（Window 场景，支持最小化/全屏/关闭三个按钮）
        Window("设置", id: "settings") {
            SettingsView()
                .environment(settingsModel)
                .frame(minWidth: Constants.SettingsWindow.minWidth, minHeight: Constants.SettingsWindow.minHeight)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: Constants.SettingsWindow.defaultWidth,
            height: Constants.SettingsWindow.defaultHeight
        )
        .commands {
            CommandGroup(after: .appInfo) {
                Button("重新体验引导") {
                    FloatingWindowManager.shared.restartTutorial()
                }
            }
        }
    }

}

// Menu bar content view
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开历史 (\(HotKeyPreferences.load().displayString))") {
            FloatingWindowManager.shared.toggleWindow()
        }

        Divider()

        Button("设置...") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("重新体验引导") {
            FloatingWindowManager.shared.restartTutorial()
        }


        Divider()

        Button("清空历史记录") {
            clearHistory()
        }

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "清空历史记录"
        alert.informativeText = "确定要删除全部历史记录、未归档草稿及当前打开文档的修改吗？此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            FloatingWindowManager.shared.documentPreview.historyCleared()
            Task {
                _ = try? await DatabaseManager.shared.performStoreOperation { DatabaseManager.shared.clearAllItems() }
            }
        }
    }
}
