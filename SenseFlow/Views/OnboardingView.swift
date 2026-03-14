//
//  OnboardingView.swift
//  SenseFlow
//
//  Created on 2026-01-23.
//  SwiftUI version of onboarding - replaces OnboardingViewController
//

import SwiftUI
import ApplicationServices
import ScreenCaptureKit

/// SwiftUI Onboarding View
struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var permissionCoordinator = PermissionStatusCoordinator.shared

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
                    isGranted: permissionCoordinator.snapshot.accessibilityGranted,
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
                    isGranted: permissionCoordinator.snapshot.screenRecordingGranted,
                    action: requestScreenRecording
                )

                PermissionRow(
                    icon: "bell.fill",
                    title: Strings.Permissions.notification,
                    subtitle: Strings.Permissions.notificationDesc,
                    isGranted: permissionCoordinator.snapshot.notificationGranted,
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
                .disabled(!permissionCoordinator.snapshot.accessibilityGranted)
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
            permissionCoordinator.start(consumer: .onboarding)
        }
        .onDisappear {
            permissionCoordinator.stop(consumer: .onboarding)
        }
    }

    // MARK: - Permission Requests

    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // Recheck after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.Permissions.recheckDelayLong) {
            permissionCoordinator.refreshNow()
        }
    }

    private func requestScreenRecording() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.Permissions.recheckDelayLong) {
                        permissionCoordinator.refreshNow()
                    }
                }
            } catch {
                print("⚠️ Screen recording permission denied: \(error)")
                await MainActor.run {
                    permissionCoordinator.refreshNow()
                }
            }
        }
    }

    private func requestNotification() {
        Task { @MainActor in
            await NotificationService.shared.requestAuthorization()

            DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.Permissions.recheckDelayShort) {
                permissionCoordinator.refreshNow()
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
