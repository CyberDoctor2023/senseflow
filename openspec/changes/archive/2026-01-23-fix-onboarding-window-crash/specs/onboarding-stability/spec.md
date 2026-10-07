# Capability: Onboarding Stability

## MODIFIED Requirements

### Requirement: Window Close Safety

The onboarding window SHALL close without crashes when user completes or skips the wizard.

#### Scenario: User clicks Continue button

**Given** the onboarding window is open and accessibility permission is granted
**When** user clicks the "继续" (Continue) button
**Then** the window closes smoothly without application crash
**And** no `EXC_BAD_ACCESS` errors occur

#### Scenario: User clicks Skip button

**Given** the onboarding window is open
**When** user clicks the "跳过" (Skip) button
**Then** the window closes smoothly without application crash
**And** no `EXC_BAD_ACCESS` errors occur
**And** `skipOnboardingPermissions` flag is set to `true`

### Requirement: Permission Status Feedback

Permission status indicators SHALL update within 2 seconds and use clear visual cues for granted vs not-granted states.

#### Scenario: Accessibility permission granted

**Given** the onboarding window is showing accessibility permission as not granted
**When** user clicks "授权" and grants the permission in System Settings
**Then** the checkbox updates to show granted state within 2 seconds
**And** a green checkmark icon indicates the granted state

#### Scenario: Screen recording permission granted

**Given** the onboarding window is showing screen recording permission as not granted
**When** user clicks "授权" and grants the permission in system dialog
**Then** the checkbox updates to show granted state within 2 seconds
**And** a green checkmark icon indicates the granted state

#### Scenario: Permission not granted

**Given** any permission is not granted
**When** the onboarding window displays the permission status
**Then** an orange warning icon clearly indicates the not-granted state
