# Change: Align Permission System with PRD v0.3.1

## Why

Current permission system doesn't match PRD requirements (PRD_所有权限问题_0.3.1). Key gaps:
- Missing notification permission request
- No distinction between mandatory (Accessibility) and optional (Smart) permissions
- Uses `onboardingCompleted` flag - once skipped, never shows again
- No re-entry path from Smart page or Advanced Settings to restore onboarding

This causes confusion when users skip onboarding and later want to enable Smart features.

## What Changes

- **Add notification permission** to onboarding flow (3rd permission)
- **Split permissions** into mandatory (Accessibility) vs optional (Smart: Screen Recording + Notification)
- **Migrate UserDefaults** from `onboardingCompleted` to `skipOnboardingPermissions`
- **Add re-entry paths**:
  - Advanced Settings: "重新打开权限引导页" button + "下次启动已跳过" status display
  - Smart page (future): Permission restriction banner with "开启权限" button
- **Update flow**: Users can enter app after Accessibility granted, Smart features show "restricted" state if skipped

## Impact

**Affected Specs**:
- `permissions-onboarding` (NEW): Complete onboarding flow with mandatory/optional split
- `permissions-ui` (MODIFIED): Advanced Settings restore onboarding functionality
- `smart-features-permissions` (NEW): Permission-restricted state for Smart features

**Affected Code**:
- `SenseFlow/Views/OnboardingViewController.swift` - Add notification, restructure UI, update flow logic
- `SenseFlow/Views/Settings/AdvancedSettingsView.swift` - Add "权限引导" card with restore button
- `SenseFlow/Services/NotificationService.swift` - Expose permission check method
- `SenseFlow/AppDelegate.swift` - Update onboarding trigger logic + UserDefaults migration

**Migration Required**: Existing users with `onboardingCompleted = true` will be migrated to `skipOnboardingPermissions = true`
