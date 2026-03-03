//
//  AppDelegate+ToolUpdate.swift
//  SenseFlow
//
//  Created on 2026-01-26.
//

import Foundation

extension AppDelegate {

    /// 启动时检查工具更新
    func checkToolUpdatesOnLaunch() {
        Task {
            do {
                let service = ToolUpdateService.shared
                let updateInfo = try await service.checkForUpdates()

                if updateInfo.hasUpdates {
                    // 显示通知
                    NotificationService.shared.showSuccess(
                        title: "发现工具更新",
                        body: "社区工具库有 \(updateInfo.newTools.count + updateInfo.updatedTools.count) 个更新可用"
                    )

                    print("📦 发现 \(updateInfo.newTools.count) 个新工具")
                    print("🔄 发现 \(updateInfo.updatedTools.count) 个工具更新")
                }
            } catch {
                print("❌ 检查工具更新失败: \(error)")
            }
        }
    }

    /// 自动安装推荐的社区工具（首次启动）
    func installRecommendedToolsIfNeeded() {
        let hasInstalledRecommended = UserDefaults.standard.bool(forKey: "hasInstalledRecommendedTools")

        guard !hasInstalledRecommended else { return }

        Task {
            do {
                let service = ToolUpdateService.shared
                let updateInfo = try await service.checkForUpdates()

                // 只安装前 5 个最受欢迎的工具
                let topTools = Array(updateInfo.availableTools.prefix(5))

                let result = await service.installTools(topTools)

                if result.success > 0 {
                    print("✅ 自动安装了 \(result.success) 个推荐工具")

                    NotificationService.shared.showSuccess(
                        title: "欢迎使用 SenseFlow",
                        body: "已为你安装 \(result.success) 个热门社区工具"
                    )
                }

                UserDefaults.standard.set(true, forKey: "hasInstalledRecommendedTools")
            } catch {
                print("❌ 安装推荐工具失败: \(error)")
            }
        }
    }
}

// MARK: - 使用示例

/*
 在 AppDelegate.applicationDidFinishLaunching() 中添加：

 func applicationDidFinishLaunching(_ notification: Notification) {
     // ... 现有代码 ...

     // 检查工具更新（24小时一次）
     checkToolUpdatesOnLaunch()

     // 首次启动时安装推荐工具
     installRecommendedToolsIfNeeded()
 }
 */
