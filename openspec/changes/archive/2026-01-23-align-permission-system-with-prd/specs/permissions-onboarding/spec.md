# Spec Delta: Permissions Onboarding

**Capability**: `permissions-onboarding`
**Change**: ADDED

---

## ADDED Requirements

### Requirement: Three-Tier Permission Request

The onboarding page MUST request three system permissions with clear categorization: mandatory (Accessibility) and optional (Smart features: Screen Recording + Notification).

#### Scenario: First launch shows onboarding with three permissions

**Given** the user launches the app for the first time
**And** `skipOnboardingPermissions` is false or unset in UserDefaults
**When** the onboarding page is displayed
**Then** the page MUST show three permission rows:
1. Accessibility Permission (under "必需权限" section)
2. Screen Recording Permission (under "Smart 功能权限（可选）" section)
3. Notification Permission (under "Smart 功能权限（可选）" section)
**And** each permission row MUST display:
- Permission name and purpose description
- "授权" button
- Status indicator (❌ 未授权 or ✅ 已授权)

#### Scenario: Accessibility permission blocks app entry

**Given** the onboarding page is displayed
**And** Accessibility permission is not granted
**When** the user attempts to click "继续" button
**Then** the button MUST be disabled
**And** the button MUST remain disabled until Accessibility permission is granted

#### Scenario: Smart permissions are optional

**Given** the onboarding page is displayed
**And** Accessibility permission is granted
**When** Screen Recording or Notification permissions are not granted
**Then** the "继续" button MUST still be enabled
**And** the user SHALL be able to proceed to the app

---

### Requirement: Permission Request Triggers Real System Dialogs

Each permission "授权" button MUST trigger the actual macOS system permission request, ensuring the app appears in System Settings.

#### Scenario: Accessibility permission opens System Settings

**Given** Accessibility permission is not granted
**When** the user clicks "授权" button for Accessibility
**Then** the system MUST open System Settings → Privacy & Security → Accessibility
**And** "SenseFlow" MUST appear in the app list
**And** the user can manually check the checkbox to grant permission

**Implementation Note**: Use `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`

#### Scenario: Screen Recording permission shows system dialog

**Given** Screen Recording permission is not granted
**And** this is the first time requesting Screen Recording
**When** the user clicks "授权" button for Screen Recording
**Then** the system MUST show a native dialog: "SenseFlow wants to record this screen"
**And** user can click "Allow" or "Deny"

**Implementation Note**: Use `CGRequestScreenCaptureAccess()` - only triggers dialog on first call

#### Scenario: Notification permission shows system dialog

**Given** Notification permission is not determined
**When** the user clicks "授权" button for Notification
**Then** the system MUST show a native dialog: "SenseFlow wants to send you notifications"
**And** user can click "Allow" or "Don't Allow"

**Implementation Note**: Use `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`

---

### Requirement: Skip Smart Permissions Behavior

Users MUST be able to skip Smart permissions (Screen Recording + Notification) while still entering the app with basic features.

#### Scenario: User skips Smart permissions

**Given** the onboarding page is displayed
**And** Accessibility permission is granted
**And** Smart permissions (Screen Recording or Notification) are not granted
**When** the user clicks "跳过 Smart 权限" button
**Then** the system MUST set `UserDefaults["skipOnboardingPermissions"] = true`
**And** the onboarding window MUST close
**And** the app MUST enter with basic features available
**And** Smart features MUST show "restricted" state

#### Scenario: Continue after all permissions granted

**Given** all three permissions are granted
**When** the user clicks "继续" button
**Then** the onboarding window MUST close
**And** `skipOnboardingPermissions` SHOULD remain false (user didn't skip)
**And** the app MUST enter with all features available

---

### Requirement: Permission Status Real-Time Updates

Permission status indicators MUST update in real-time when permissions are granted without requiring app restart.

#### Scenario: Accessibility status updates after granting

**Given** the onboarding page is displayed
**And** Accessibility permission status is "未授权"
**When** the user clicks "授权", grants permission in System Settings, and returns to the app
**Then** the status indicator MUST update to "✅ 已授权"
**And** the "继续" button MUST become enabled

**Implementation Note**: Poll `AXIsProcessTrusted()` on window focus or use timer

#### Scenario: Screen Recording status updates after granting

**Given** Screen Recording permission dialog is shown
**When** the user clicks "Allow"
**Then** the status indicator MUST immediately update to "✅ 已授权"

---

### Requirement: UserDefaults Flag Semantics

The system MUST use `skipOnboardingPermissions` boolean to control whether onboarding shows on next launch.

#### Scenario: Flag controls onboarding display

**Given** `UserDefaults["skipOnboardingPermissions"]` is false or unset
**When** the app launches
**Then** the onboarding page MUST be displayed

**Given** `UserDefaults["skipOnboardingPermissions"]` is true
**When** the app launches
**Then** the onboarding page MUST NOT be displayed

#### Scenario: Migration from old onboardingCompleted flag

**Given** `UserDefaults["onboardingCompleted"]` exists and is true
**When** the app launches for the first time with new permission system
**Then** the system MUST set `skipOnboardingPermissions = true`
**And** MUST remove the old `onboardingCompleted` key
**And** MUST NOT show onboarding (respecting user's previous skip)
