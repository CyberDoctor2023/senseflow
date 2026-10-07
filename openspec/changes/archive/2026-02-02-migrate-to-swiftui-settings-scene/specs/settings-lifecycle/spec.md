# Capability: Settings Lifecycle Management

## ADDED Requirements

### Requirement: Settings window must use SwiftUI Settings scene
The system SHALL use SwiftUI's native Settings scene for settings window management instead of manual NSWindow creation.

**Priority**: P0 - Architectural foundation

#### Scenario: Settings window opens via App menu
**Given** the application is running
**When** the user selects "Settings..." from the App menu
**Then** the settings window SHALL open using SwiftUI Settings scene
**And** the window SHALL be managed by the system
**And** focus SHALL be automatically maintained during user interactions

#### Scenario: Settings window opens via keyboard shortcut
**Given** the application is running
**When** the user presses ⌘,
**Then** the settings window SHALL open immediately
**And** the shortcut SHALL be automatically registered by the system
**And** no manual hotkey registration code SHALL be required

### Requirement: Settings window must retain focus during user interactions
The system SHALL automatically maintain focus on the settings window during all user interactions without manual intervention.

**Priority**: P0 - Core functionality

#### Scenario: Focus retained after API key input
**Given** the settings window is open
**When** the user enters an API key in the SecureField
**And** the system saves to Keychain
**Then** the settings window SHALL remain focused
**And** the user SHALL be able to immediately continue editing

#### Scenario: Focus retained after button clicks
**Given** the settings window is open
**When** the user clicks the "测试连接" button
**And** the connection test completes
**Then** the settings window SHALL remain the key window
**And** the test result SHALL be visible without reactivation

#### Scenario: Focus retained after dropdown selections
**Given** the settings window is open
**When** the user selects a different AI service from the Picker
**Then** the settings window SHALL remain focused
**And** the corresponding fields SHALL be immediately editable

## REMOVED Requirements

### Requirement: Manual window lifecycle management
The system SHALL NOT use manual NSWindow creation and management for settings.

**Rationale**: SwiftUI Settings scene provides superior system integration and automatic focus management.

#### Scenario: No manual window controller
**Given** the application uses SwiftUI Settings scene
**Then** SettingsWindowController class SHALL NOT exist
**And** no manual NSWindow creation code SHALL be present
**And** no manual focus management code SHALL be required

