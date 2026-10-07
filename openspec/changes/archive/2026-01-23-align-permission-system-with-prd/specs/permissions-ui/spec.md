# Spec Delta: Permissions UI

**Capability**: `permissions-ui`
**Change**: MODIFIED

---

## ADDED Requirements

### Requirement: Onboarding Restore Card in Advanced Settings

Advanced Settings MUST provide a way to restore the onboarding page for users who previously skipped Smart permissions.

#### Scenario: Display "下次启动已跳过" status

**Given** the user is in Advanced Settings
**And** `UserDefaults["skipOnboardingPermissions"]` is true
**When** viewing the "权限引导" card
**Then** the card MUST display status text: "状态：下次启动已跳过"
**And** the status MUST be hidden when `skipOnboardingPermissions` is false

#### Scenario: Restore onboarding immediately

**Given** the user is in Advanced Settings
**When** the user clicks "重新打开权限引导页" button
**Then** the system MUST set `skipOnboardingPermissions = false`
**And** the onboarding window MUST appear immediately (without requiring app restart)
**And** the user can grant any missing Smart permissions

#### Scenario: Restore onboarding persists across launches

**Given** the user clicked "重新打开权限引导页"
**And** `skipOnboardingPermissions` was reset to false
**When** the user restarts the app
**Then** the onboarding page MUST appear again on launch

---

### Requirement: Notification Permission Display

The Privacy settings card MUST display notification permission status alongside existing accessibility and screen recording permissions.

#### Scenario: Notification permission status in Privacy card

**Given** the user is viewing the Privacy settings card (隐私权限)
**When** the card is rendered
**Then** the card MUST include a third row for Notification Permission:
- Icon: system bell icon
- Title: "通知权限"
- Status: "已授权" (green checkmark) or "未授权" (orange warning)
- Description: "用于剪切板操作状态通知反馈。请在「系统设置 > 通知」中手动授权。"

**Implementation Note**: Check permission via `UNUserNotificationCenter.current().notificationSettings().authorizationStatus`

---

## MODIFIED Requirements

### Requirement: Accessibility Permission Status Display

The Privacy settings page MUST display the status and purpose of Accessibility permission. It SHALL include status indicator, description, and manual authorization guidance.

#### Scenario: Permission Granted

**Given** the user is in the "隐私" settings Tab
**And** Accessibility permission is granted in System Settings
**When** the user views the permission status card
**Then** the system MUST display:
- Card title: "辅助功能权限" (with `hand.tap` icon)
- Status indicator: ✅ "已授权" (green)
- Description: "用于 Prompt Tools 的自动粘贴功能。请在「系统设置 > 隐私与安全性 > 辅助功能」中手动授权。"

**Acceptance Criteria**:
- Uses `AXIsProcessTrusted()` to check permission
- Status icon is clearly visible (`checkmark.circle.fill`)
- Description text displays completely (using `fixedSize(horizontal: false, vertical: true)`)

#### Scenario: Permission Denied

**Given** the user is in the "隐私" settings Tab
**And** Accessibility permission is **not** granted in System Settings
**When** the user views the permission status card
**Then** the system MUST display:
- Card title: "辅助功能权限" (with `hand.tap` icon)
- Status indicator: ⚠️ "未授权" (orange)
- Description: "用于 Prompt Tools 的自动粘贴功能。请在「系统设置 > 隐私与安全性 > 辅助功能」中手动授权。"
- **No** "打开设置" button

**Acceptance Criteria**:
- Status icon uses `exclamationmark.triangle.fill`
- Description text remains consistent (regardless of permission status)
- No clickable jump-to-settings button

---

## REMOVED Requirements

None
