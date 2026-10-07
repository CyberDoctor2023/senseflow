# Capability: Prompt UI Integration

## Overview
User interface components for displaying Langfuse prompt metadata, sync status, and credential management.

## ADDED Requirements

### Requirement: Langfuse Settings Section
The system SHALL provide a dedicated settings section for Langfuse configuration.

#### Scenario: Settings Panel Display
**Given** the user opens Prompt Tools settings
**When** viewing the settings panel
**Then** the system SHALL show a "Langfuse Integration" section
**And** display credential input fields (public key, secret key)
**And** show connection status indicator
**And** provide "Test Connection" and "Sync Now" buttons

#### Scenario: Connection Status Display
**Given** Langfuse credentials are configured
**When** viewing settings
**Then** the system SHALL show connection status as:
  - "Connected" (green) if credentials are valid
  - "Disconnected" (gray) if no credentials
  - "Error" (red) if credentials are invalid
**And** show last sync time if connected

#### Scenario: Sync Configuration
**Given** the user is in Langfuse settings
**When** viewing sync options
**Then** the system SHALL show sync interval slider (1-60 minutes)
**And** show "Enable automatic sync" toggle
**And** show "Clear cache" button
**And** update settings immediately on change

---

### Requirement: Prompt Source Badges
The system SHALL display visual indicators for prompt sources.

#### Scenario: Langfuse Prompt Badge
**Given** a prompt has source = .langfuse
**When** displaying in prompt list
**Then** the system SHALL show "Langfuse" badge with cloud icon
**And** use blue color (#007AFF)
**And** position badge in top-right corner

#### Scenario: Local Prompt Badge
**Given** a prompt has source = .custom
**When** displaying in prompt list
**Then** the system SHALL show "Local" badge
**And** use gray color
**And** indicate user-created content

#### Scenario: Built-in Prompt Badge
**Given** a prompt has source = .builtin
**When** displaying in prompt list
**Then** the system SHALL show "Built-in" badge
**And** use system accent color
**And** indicate default content

---

### Requirement: Version and Label Display
The system SHALL display Langfuse version and label information.

#### Scenario: Version Number Display
**Given** a Langfuse prompt with version 5
**When** viewing prompt details
**Then** the system SHALL show "v5" label
**And** position it next to the prompt name
**And** use monospace font

#### Scenario: Production Label Display
**Given** a Langfuse prompt with "production" label
**When** viewing prompt list
**Then** the system SHALL show "production" tag
**And** use green color to indicate active deployment
**And** show as primary label if multiple labels exist

#### Scenario: Multiple Labels Display
**Given** a Langfuse prompt with labels ["production", "staging", "experiment-a"]
**When** viewing prompt details
**Then** the system SHALL show all labels as tags
**And** highlight "production" label prominently
**And** show others in secondary style

---

### Requirement: Sync Status Indicators
The system SHALL display real-time sync status information.

#### Scenario: Syncing Indicator
**Given** a sync operation is in progress
**When** viewing prompt list
**Then** the system SHALL show animated sync icon
**And** display progress text (e.g., "Syncing 3/10")
**And** disable manual sync button

#### Scenario: Last Sync Time
**Given** sync completed successfully
**When** viewing settings
**Then** the system SHALL show "Last synced: 2 minutes ago"
**And** update the time display every minute
**And** use relative time format (e.g., "just now", "5 minutes ago")

#### Scenario: Sync Error Display
**Given** sync failed with error
**When** viewing settings
**Then** the system SHALL show error icon with red color
**And** display error message (e.g., "Network error")
**And** provide "Retry" button
**And** show last successful sync time

---

### Requirement: Prompt Editor Restrictions
The system SHALL restrict editing of Langfuse-managed prompts.

#### Scenario: Langfuse Prompt Read-Only
**Given** the user opens a Langfuse prompt for editing
**When** viewing the editor
**Then** the system SHALL disable all edit fields
**And** show "Managed by Langfuse" notice
**And** provide "View in Langfuse" link
**And** allow viewing but not editing

#### Scenario: Local Prompt Editable
**Given** the user opens a local custom prompt
**When** viewing the editor
**Then** the system SHALL enable all edit fields
**And** allow full editing capabilities
**And** show "Save" button

#### Scenario: Convert to Local Option
**Given** the user views a Langfuse prompt
**When** clicking "Convert to Local" button
**Then** the system SHALL create a local copy
**And** disconnect from Langfuse sync
**And** allow editing the local copy
**And** keep original Langfuse prompt unchanged

---

### Requirement: Manual Sync Trigger
The system SHALL provide manual sync controls.

#### Scenario: Sync Now Button
**Given** the user is in Langfuse settings
**When** clicking "Sync Now" button
**Then** the system SHALL start immediate sync
**And** show progress indicator
**And** disable button during sync
**And** show completion message

#### Scenario: Pull-to-Refresh
**Given** the user is viewing prompt list
**When** performing pull-to-refresh gesture
**Then** the system SHALL trigger manual sync
**And** show refresh animation
**And** update list when complete

---

### Requirement: Sync Notifications
The system SHALL notify users of sync events.

#### Scenario: Sync Success Notification
**Given** sync completed successfully
**And** prompts were updated
**When** sync finishes
**Then** the system SHALL show notification
**And** display count of updated prompts (e.g., "3 prompts updated")
**And** auto-dismiss after 3 seconds

#### Scenario: Sync Error Notification
**Given** sync failed with error
**When** sync finishes
**Then** the system SHALL show error notification
**And** display actionable error message
**And** provide "Retry" action
**And** NOT auto-dismiss (require user action)

#### Scenario: Silent Sync
**Given** sync completed with no changes
**When** sync finishes
**Then** the system SHALL NOT show notification
**And** update last sync time silently
**And** log success for debugging

---

### Requirement: Prompt List Filtering
The system SHALL allow filtering prompts by source.

#### Scenario: Filter by Source
**Given** the user is viewing prompt list
**When** selecting "Langfuse" filter
**Then** the system SHALL show only Langfuse prompts
**And** hide local and built-in prompts
**And** update count indicator

#### Scenario: Show All Prompts
**Given** a filter is active
**When** selecting "All" filter
**Then** the system SHALL show all prompts regardless of source
**And** display source badges for each prompt

---

### Requirement: Credential Input Validation
The system SHALL validate credential input in real-time.

#### Scenario: Public Key Format
**Given** the user is entering public key
**When** typing in the field
**Then** the system SHALL validate format (starts with "pk-lf-")
**And** show error if format is invalid
**And** prevent saving invalid format

#### Scenario: Secret Key Format
**Given** the user is entering secret key
**When** typing in the field
**Then** the system SHALL validate format (starts with "sk-lf-")
**And** mask the input (show dots)
**And** show error if format is invalid

#### Scenario: Empty Credentials
**Given** credential fields are empty
**When** attempting to save
**Then** the system SHALL show validation error
**And** highlight empty fields
**And** prevent saving

---

### Requirement: Onboarding and Help
The system SHALL provide guidance for Langfuse setup.

#### Scenario: First-Time Setup Guide
**Given** no Langfuse credentials are configured
**When** user opens Langfuse settings
**Then** the system SHALL show setup instructions
**And** provide link to Langfuse documentation
**And** explain benefits of integration

#### Scenario: Help Documentation
**Given** the user clicks help icon
**When** viewing Langfuse settings
**Then** the system SHALL show inline help
**And** explain each setting
**And** provide troubleshooting tips

---

## MODIFIED Requirements

### Requirement: Prompt List View
The existing prompt list view SHALL be enhanced to display Langfuse metadata.

**Before**: Prompt list showed only name, shortcut, and basic info

**After**: Prompt list SHALL additionally show:
- Source badge (Langfuse/Local/Built-in)
- Version number for Langfuse prompts
- Primary label (production/staging)
- Last sync time for Langfuse prompts
- Sync status indicator

#### Scenario: Enhanced Prompt Card
**Given** viewing a Langfuse prompt in list
**When** displaying the card
**Then** the system SHALL show all metadata
**And** maintain existing layout structure
**And** use consistent visual hierarchy

---

### Requirement: Settings Navigation
The settings panel SHALL include Langfuse section in navigation.

**Before**: Settings had 5 sections (General, Shortcuts, Prompt Tools, Privacy, Advanced)

**After**: Prompt Tools section SHALL include Langfuse subsection with:
- Credential management
- Sync configuration
- Connection status
- Manual sync trigger

#### Scenario: Langfuse Subsection in Settings
**Given** the user opens Prompt Tools settings
**When** viewing the navigation
**Then** the system SHALL show "Langfuse Integration" subsection
**And** include all configuration options
**And** maintain existing Prompt Tools functionality

---

## Related Capabilities
- **prompt-sync**: Provides sync status data for display
- **prompt-credentials**: Provides credential management backend
- **prompt-cache**: Provides prompt data with metadata
- **ui-settings**: Existing settings panel to extend
