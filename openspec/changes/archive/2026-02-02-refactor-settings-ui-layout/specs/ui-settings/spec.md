# UI Settings Specification Delta

## MODIFIED Requirements

### Requirement: Settings Window Structure
The system SHALL display settings in a TabView following macOS HIG standards.

#### Scenario: Settings window uses TabView layout
- **WHEN** the settings window is opened
- **THEN** it SHALL use `TabView` with toolbar-based tab navigation
- **AND** it SHALL contain five tabs: 通用, 快捷键, Prompt Tools, 隐私, 高级
- **AND** each tab SHALL use `Tab("Label", systemImage: "icon") { ContentView() }` syntax
- **AND** the window SHALL have `.frame(maxWidth: 350, minHeight: 100)`
- **AND** the window SHALL use `.scenePadding()` for system margins

#### Scenario: Settings window sizing follows HIG
- **WHEN** the settings window is displayed
- **THEN** the window width SHALL NOT exceed 350pt
- **AND** the window height SHALL auto-expand based on content (minimum 100pt)
- **AND** the window SHALL NOT use fixed width/height dimensions
- **AND** the content SHALL use responsive layouts to fit within 350pt width

### Requirement: Tab Navigation Icons
The system SHALL display toolbar icons for each settings section.

#### Scenario: Toolbar icons for settings sections
- **WHEN** the settings window is displayed
- **THEN** the "通用" tab SHALL use systemImage "gear"
- **AND** the "快捷键" tab SHALL use systemImage "keyboard"
- **AND** the "Prompt Tools" tab SHALL use systemImage "wand.and.stars"
- **AND** the "隐私" tab SHALL use systemImage "lock"
- **AND** the "高级" tab SHALL use systemImage "wrench.and.screwdriver"

#### Scenario: Tab selection state management
- **WHEN** a user clicks a toolbar icon
- **THEN** the system SHALL automatically switch to the corresponding tab
- **AND** the selected tab icon SHALL be visually highlighted
- **AND** keyboard shortcuts (⌃Tab / ⌃⇧Tab) SHALL cycle through tabs

## REMOVED Requirements

### Requirement: NavigationSplitView Layout
~~The system SHALL use NavigationSplitView with sidebar.~~

**Rationale**: NavigationSplitView is for document apps, not settings windows. Apple HIG recommends TabView for settings.

#### Scenario: Sidebar navigation (REMOVED)
~~- **WHEN** the settings window is opened~~
~~- **THEN** it SHALL display a sidebar with section list~~
~~- **AND** the sidebar SHALL be 200pt fixed width~~
~~- **AND** the detail pane SHALL be minimum 500pt width~~

**Replacement**: See "Settings window uses TabView layout" scenario above.

### Requirement: Fixed Window Dimensions
~~The system SHALL use 750×500pt window size.~~

**Rationale**: 750pt width violates macOS HIG recommendations (maxWidth: 350). Fixed dimensions prevent responsive layouts.

#### Scenario: Fixed 750×500pt window (REMOVED)
~~- **WHEN** the settings window is displayed~~
~~- **THEN** the window SHALL be exactly 750pt wide~~
~~- **AND** the window SHALL be exactly 500pt tall~~

**Replacement**: See "Settings window sizing follows HIG" scenario above.

## ADDED Requirements

### Requirement: Settings Content Views Unchanged
The system SHALL preserve all existing settings functionality.

#### Scenario: Content views remain unchanged
- **WHEN** any settings tab is displayed
- **THEN** the content view (GeneralSettingsView, etc.) SHALL render identically to before
- **AND** all settings controls SHALL function as before
- **AND** all data persistence (@AppStorage) SHALL work as before
- **AND** NO settings logic SHALL be modified

#### Scenario: Five settings sections
- **WHEN** the settings window is displayed
- **THEN** all five tabs SHALL be accessible
- **AND** the tabs SHALL be in order: 通用, 快捷键, Prompt Tools, 隐私, 高级
- **AND** each tab SHALL display its corresponding content view

## Migration Notes

This spec delta refactors the UI layout from NavigationSplitView to TabView while preserving all settings functionality. The change affects only the container structure in SettingsView.swift (lines 17-97), not the individual settings content views.

**Changed Components**:
- SettingsView.swift: Replace NavigationSplitView with TabView
- Remove SettingsSidebarView struct
- Remove SettingsDetailView struct

**Unchanged Components**:
- GeneralSettingsView.swift
- ShortcutSettingsView.swift
- PromptToolsSettingsView.swift
- PrivacySettingsView.swift
- AdvancedSettingsView.swift
- SettingsSection enum (kept for compatibility)

## References

- Apple HIG Settings: https://developer.apple.com/design/human-interface-guidelines/settings
- SwiftUI TabView: https://developer.apple.com/documentation/swiftui/tabview
- Context7 Research: docs/refs.md lines 385-394
