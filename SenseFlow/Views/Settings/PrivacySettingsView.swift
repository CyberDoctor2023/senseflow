//
//  PrivacySettingsView.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//  Updated on 2026-02-10 for @Observable + @Bindable pattern
//

import SwiftUI
import Cocoa                // For NSWindow, NSHostingController
import ApplicationServices  // For AXIsProcessTrusted()
import UserNotifications    // For notification permission check

/// 隐私设置（使用 @Bindable 接收 SettingsModel 双向绑定）
struct PrivacySettingsView: View {
    @Bindable var model: SettingsModel

    @State private var hasAccessibilityPermission = false
    @State private var hasScreenRecordingPermission = false
    @State private var hasNotificationPermission = false
    @State private var skipOnboardingPermissions = false

    var body: some View {
        Form {
                // 隐私权限
                Section(Strings.PrivacySettings.privacySection) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(hasAccessibilityPermission ? .green : .orange)
                                .symbolRenderingMode(.multicolor)
                                .font(.caption)

                            Text(hasAccessibilityPermission ? Strings.PrivacySettings.accessibilityGranted : Strings.PrivacySettings.accessibilityDenied)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text(Strings.PrivacySettings.accessibilityDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: hasScreenRecordingPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(hasScreenRecordingPermission ? .green : .orange)
                                .symbolRenderingMode(.multicolor)
                                .font(.caption)

                            Text(hasScreenRecordingPermission ? Strings.PrivacySettings.screenRecordingGranted : Strings.PrivacySettings.screenRecordingDenied)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text(Strings.PrivacySettings.screenRecordingDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: hasNotificationPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(hasNotificationPermission ? .green : .orange)
                                .symbolRenderingMode(.multicolor)
                                .font(.caption)

                            Text(hasNotificationPermission ? Strings.PrivacySettings.notificationGranted : Strings.PrivacySettings.notificationDenied)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text(Strings.PrivacySettings.notificationDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                // 权限引导
                Section(Strings.PrivacySettings.guideSection) {
                    if skipOnboardingPermissions {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)

                            Text(Strings.PrivacySettings.guideStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(Strings.PrivacySettings.guideDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    #if DEBUG
                    Button(Strings.PrivacySettings.testButton) {
                        print("🧪 测试权限检查按钮被点击")
                    }
                    .compatibleButtonStyle()
                    #endif

                    Button(Strings.PrivacySettings.restoreGuideButton) {
                        restoreOnboarding()
                    }
                    .compatibleButtonStyle(prominent: true)
                    .help(Strings.PrivacySettings.restoreGuideHelp)
                }

                // 敏感数据过滤
                Section(Strings.PrivacySettings.sensitiveDataSection) {
                    Text(Strings.PrivacySettings.sensitiveDataDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("[开发者] 自动过滤的数据类型：")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Text("• org.nspasteboard.ConcealedType")
                            .font(.system(size: DesignSystem.FontSize.small, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  （密码/隐藏数据）")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text("• org.nspasteboard.TransientType")
                            .font(.system(size: DesignSystem.FontSize.small, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  （临时数据）")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text("• org.nspasteboard.AutoGeneratedType")
                            .font(.system(size: DesignSystem.FontSize.small, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  （自动生成数据）")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)

                    Text(Strings.PrivacySettings.sensitiveDataNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 应用过滤
                Section(Strings.PrivacySettings.appFilterSection) {
                    Text(Strings.PrivacySettings.appFilterDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $model.filterAppListString)
                        .frame(height: DesignSystem.TextEditor.height)
                        .font(.system(size: DesignSystem.FontSize.small, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .stroke(Color(NSColor.separatorColor), lineWidth: DesignSystem.BorderWidth.thin)
                        )
                        .help(Strings.PrivacySettings.appFilterPlaceholder)

                    Text(Strings.PrivacySettings.appFilterHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .compatibleControlSize()
            .onAppear {
                checkPermissions()
            }
    }

    // MARK: - Private Methods

    private func checkPermissions() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        hasScreenRecordingPermission = ScreenCaptureManager.shared.checkPermission()

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                hasNotificationPermission = settings.authorizationStatus == .authorized
            }
        }

        skipOnboardingPermissions = UserDefaults.standard.bool(forKey: UserDefaultsKeys.skipOnboardingPermissions)
    }

    private func restoreOnboarding() {
        print("🔄 恢复权限引导被调用")
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.skipOnboardingPermissions)
        print("✅ UserDefaults 已重置")

        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
            print("⚠️ AppDelegate 转换失败: \(type(of: NSApplication.shared.delegate))")
            OnboardingWindowManager.shared.showWindow()
            print("✅ 直接创建 Onboarding 窗口")
            return
        }

        print("✅ 找到 AppDelegate")
        appDelegate.showOnboardingWindow()
        skipOnboardingPermissions = false
        print("✅ skipOnboardingPermissions 标志已设置为 false")
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        PrivacySettingsView(model: SettingsModel())
            .frame(
                width: DesignSystem.WindowSize.settingsWindow.width,
                height: DesignSystem.WindowSize.settingsWindow.height
            )
    } else {
        Text(Strings.PrivacySettings.previewFallback)
    }
}
