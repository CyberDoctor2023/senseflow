# Implementation Tasks

## 1. Foundation & Migration
- [x] 1.1 Add `checkPermission()` and `hasPermission` to NotificationService
- [x] 1.2 Create UserDefaults migration logic in AppDelegate (onboardingCompleted → skipOnboardingPermissions)
- [x] 1.3 Update `OnboardingViewController.shouldShow()` to check skipOnboardingPermissions

## 2. Onboarding Restructure
- [x] 2.1 Add notification permission UI to OnboardingViewController (3rd permission row)
- [x] 2.2 Add section headers: "必需权限" and "Smart 功能权限（可选）"
- [x] 2.3 Update "继续" button logic (enabled when Accessibility granted)
- [x] 2.4 Rename "跳过" to "跳过 Smart 权限", set skipOnboardingPermissions flag
- [x] 2.5 Remove auto-close on all permissions granted

## 3. Advanced Settings Integration
- [x] 3.1 Add "权限引导" card to AdvancedSettingsView
- [x] 3.2 Add "下次启动已跳过" status text (conditional on skipOnboardingPermissions)
- [x] 3.3 Add "重新打开权限引导页" button (resets flag + shows onboarding)
- [x] 3.4 Add notification permission to Privacy card

## 4. Validation
- [x] 4.1 Test fresh install flow (skip accessibility → blocked, grant → can enter)
- [x] 4.2 Test "跳过 Smart 权限" → app enters, skipOnboardingPermissions = true
- [x] 4.3 Test restore onboarding from Settings → onboarding shows immediately
- [x] 4.4 Test migration (onboardingCompleted = true → skipOnboardingPermissions = true)
- [x] 4.5 Test all 3 permission system dialogs (Accessibility opens Settings, others show system dialog)
