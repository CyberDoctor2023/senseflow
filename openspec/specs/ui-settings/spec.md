# Settings UI Specification

## Purpose

The Settings UI provides users with a centralized interface to configure application behavior, manage privacy settings, customize keyboard shortcuts, and control advanced features. It follows macOS Human Interface Guidelines for settings windows.

## Overview
The settings window provides configuration options organized in a tabbed interface.
## Requirements
### Requirement: Settings Window Structure
The system SHALL display settings in a macOS-standard window with tabs.

#### Scenario: Settings window layout
- **WHEN** the settings window is opened
- **THEN** it SHALL use a standard macOS window (not a panel)
- **AND** it SHALL contain three tabs: General, Shortcuts, Privacy
- **AND** it SHALL use `.formStyle(.grouped)` for macOS 13+
- **AND** it SHALL show a version warning for macOS 12

### Requirement: General Settings Tab
The system SHALL provide general configuration options.

#### Scenario: General settings options
- **WHEN** viewing the General tab
- **THEN** it SHALL show a history limit slider (50-500 items, default 200)
- **AND** it SHALL show an auto-paste toggle
- **AND** it SHALL show a launch at login toggle (macOS 13+ using SMAppService)

### Requirement: Shortcuts Settings Tab
The system SHALL allow customization of global hotkeys.

#### Scenario: Hotkey recorder
- **WHEN** viewing the Shortcuts tab
- **THEN** it SHALL display the current hotkey combination
- **AND** it SHALL provide a recording interface to capture new key combinations
- **AND** it SHALL detect and warn about hotkey conflicts
- **AND** it SHALL validate that at least one modifier key is pressed

### Requirement: Privacy Settings Tab
The system SHALL provide privacy and filtering controls.

#### Scenario: Application filtering
- **WHEN** viewing the Privacy tab
- **THEN** it SHALL show toggles for password manager filtering
- **AND** it SHALL allow adding/removing apps from the ignore list
- **AND** it SHALL display the list of currently filtered applications

### Requirement: Settings Navigation Structure

The Settings window SHALL use NavigationSplitView with a sidebar containing navigation links to different settings pages. Each major feature area MUST have its own independent sidebar page.

#### Scenario: User navigates to Developer Options settings
**Given** the user opens the Settings window
**When** the user clicks on "开发者选项" in the sidebar
**Then** the Developer Options settings page is displayed
**And** the page shows "Show Prompt Labels" toggle
**And** the page shows Langfuse integration configuration

#### Scenario: User navigates to Smart AI settings
**Given** the user opens the Settings window
**When** the user clicks on "Smart AI" in the sidebar
**Then** the Smart AI settings page is displayed
**And** the page shows Smart AI enable/disable toggle
**And** the page shows hotkey display (⌘⌃V)
**And** the page shows lightweight mode toggle
**And** the page shows screen recording permission status

#### Scenario: User navigates to Prompt Tools settings
**Given** the user opens the Settings window
**When** the user clicks on "Prompt Tools" in the sidebar
**Then** the Prompt Tools settings page is displayed
**And** the page shows AI service configuration
**And** the page shows Prompt Tools list
**And** the page does NOT show Developer Options section
**And** the page does NOT show Langfuse configuration

### Requirement: Settings Sidebar Order

The Settings sidebar MUST display navigation items in a specific order for optimal user experience. The order SHALL be: General, Shortcuts, Prompt Tools, Smart AI, Developer Options, Privacy, Advanced.

#### Scenario: Settings sidebar displays all navigation items in correct order
**Given** the user opens the Settings window
**Then** the sidebar shows navigation items in this order:
1. 通用 (General)
2. 快捷键 (Shortcuts)
3. Prompt Tools
4. Smart AI
5. 开发者选项 (Developer Options)
6. 隐私 (Privacy)
7. 高级 (Advanced)

