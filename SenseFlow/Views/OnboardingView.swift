//
//  OnboardingView.swift
//  SenseFlow
//
//  Created on 2026-01-23.
//  SwiftUI version of onboarding - replaces OnboardingViewController
//

import SwiftUI
import ApplicationServices
import UserNotifications
import ScreenCaptureKit

/// SwiftUI Onboarding View
struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var hasAccessibility = false
    @State private var hasScreenRecording = false
    @State private var hasNotification = false

    // 定时器，用于持续检查权限状态
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Title
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(Strings.Onboarding.title)
                    .font(.system(size: DesignSystem.FontSize.largeTitle, weight: .bold))

                Text(Strings.Onboarding.subtitle)
                    .font(.system(size: DesignSystem.FontSize.bodyLarge))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Constants.Onboarding.topPadding)

            Divider()

            // Mandatory permissions
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text(Strings.Onboarding.mandatorySection)
                    .font(.system(size: DesignSystem.FontSize.title, weight: .semibold))

                PermissionRow(
                    icon: "hand.raised.fill",
                    title: Strings.Permissions.accessibility,
                    subtitle: Strings.Permissions.accessibilityDesc,
                    isGranted: hasAccessibility,
                    action: requestAccessibility
                )
            }

            Divider()

            // Optional permissions
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text(Strings.Onboarding.optionalSection)
                    .font(.system(size: DesignSystem.FontSize.title, weight: .semibold))

                PermissionRow(
                    icon: "camera.metering.matrix",
                    title: Strings.Permissions.screenRecording,
                    subtitle: Strings.Permissions.screenRecordingDesc,
                    isGranted: hasScreenRecording,
                    action: requestScreenRecording
                )

                PermissionRow(
                    icon: "bell.fill",
                    title: Strings.Permissions.notification,
                    subtitle: Strings.Permissions.notificationDesc,
                    isGranted: hasNotification,
                    action: requestNotification
                )
            }

            Spacer()

            // Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(Strings.Buttons.skip) {
                    skipOnboarding()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(Strings.Buttons.continue_) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasAccessibility)
            }
            .padding(.bottom, Constants.Onboarding.bottomPadding)

            Text(Strings.Onboarding.skipHint)
                .font(.system(size: DesignSystem.FontSize.caption))
                .foregroundStyle(.secondary)
                .padding(.bottom, Constants.spacing8)
        }
        .padding(.horizontal, Constants.Onboarding.horizontalPadding)
        .frame(width: Constants.DialogWindow.onboarding.width, height: Constants.DialogWindow.onboarding.height)
        .onAppear {
            checkPermissions()
            startPermissionCheckTimer()
        }
        .onDisappear {
            stopPermissionCheckTimer()
        }
    }

    // MARK: - Permission Checks

    private func checkPermissions() {
        Task {
            let status = await checkAllPermissions()
            await MainActor.run {
                hasAccessibility = status.accessibility
                hasScreenRecording = status.screenRecording
                hasNotification = status.notification
            }
        }
    }

    /// 检查所有权限状态
    private func checkAllPermissions() async -> PermissionStatus {
        let accessibility = AXIsProcessTrusted()
        let screenRecording = CGPreflightScreenCaptureAccess()
        let notification = await checkNotificationPermission()

        return PermissionStatus(
            accessibility: accessibility,
            screenRecording: screenRecording,
            notification: notification
        )
    }

    /// 检查通知权限
    private func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// 权限状态结构
    private struct PermissionStatus {
        let accessibility: Bool
        let screenRecording: Bool
        let notification: Bool
    }

    private func startPermissionCheckTimer() {
        // 每 0.5 秒检查一次权限状态，以便实时更新 UI
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: BusinessRules.Permissions.checkInterval, repeats: true) { _ in
            checkPermissions()
        }
    }

    private func stopPermissionCheckTimer() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    // MARK: - Permission Requests

    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // Recheck after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.Permissions.recheckDelayLong) {
            checkPermissions()
        }
    }

    private func requestScreenRecording() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.Permissions.recheckDelayLong) {
                        checkPermissions()
                    }
                }
            } catch {
                print("⚠️ Screen recording permission denied: \(error)")
                await MainActor.run {
                    checkPermissions()
                }
            }
        }
    }

    private func requestNotification() {
        Task {
            await NotificationService.shared.requestAuthorization()

            DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.Permissions.recheckDelayShort) {
                checkPermissions()
            }
        }
    }

    private func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.skipOnboardingPermissions)
        dismiss()
    }
}

/// Permission row component
struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: isGranted ? "checkmark.circle.fill" : icon)
                .font(.system(size: DesignSystem.FontSize.largeTitle))
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: Constants.Onboarding.iconSize)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: DesignSystem.FontSize.body, weight: .medium))

                Text(subtitle)
                    .font(.system(size: DesignSystem.FontSize.small))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Button
            if !isGranted {
                Button(Strings.Buttons.authorize) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(Constants.spacing12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
