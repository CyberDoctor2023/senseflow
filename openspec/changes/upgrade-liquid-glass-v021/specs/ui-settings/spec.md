## MODIFIED Requirements

### Requirement: Settings Window Structure
The system SHALL display settings in a macOS 26-aligned window with sidebar navigation.

#### Scenario: Settings window layout
- **WHEN** the settings window is opened
- **THEN** it SHALL use a NavigationSplitView with sidebar and detail panes
- **AND** the sidebar SHALL be 200pt fixed width
- **AND** the detail pane SHALL have minimum 500pt width
- **AND** the window SHALL support user resizing (draggable edges and corners)
- **AND** the window SHALL maintain minimum size constraints to keep content readable
- **AND** the window background SHALL use `NSGlassEffectView` with `.regular` style on macOS 26+
- **AND** it SHALL fall back to `NSVisualEffectView` with `.hudWindow` material on macOS 13-15
- **AND** it SHALL require macOS 13.0+ (NavigationSplitView requirement)
- **AND** it SHALL show a version warning for macOS 12
- **BUG WORKAROUND**: It SHALL use `.task` modifier (not `.onAppear`) to set `columnVisibility` to work around macOS 26.0.1 NavigationSplitView bug

#### Scenario: Sidebar navigation
- **WHEN** viewing the settings sidebar
- **THEN** it SHALL display navigation items with SF Symbols icons
- **AND** it SHALL include these menu items in order:
  1. General (gear icon)
  2. Shortcuts (keyboard icon)
  3. Tools (wrench icon)
  4. Privacy (lock icon)
  5. Advanced (slider icon)
- **AND** sidebar items SHALL show hover states (subtle background highlight)
- **AND** the selected item SHALL be visually highlighted

#### Scenario: Module card styling
- **WHEN** rendering settings module content
- **THEN** each module SHALL be displayed as a card
- **AND** the card SHALL use `NSGlassEffectView` with `.clear` style on macOS 26+
- **AND** it SHALL fall back to `NSVisualEffectView` with `.hudWindow` material + 6% white overlay on macOS 13-15
- **AND** the card SHALL have 16pt internal padding
- **AND** the card SHALL have 12pt corner radius
- **AND** cards SHALL be layered on top of the window background
- **AND** this layering system (window background + module cards) SHALL be consistent across all settings pages including subpages

### Requirement: General Settings Tab
The system SHALL provide general configuration options in card-based layout.

#### Scenario: General settings options
- **WHEN** viewing the General section
- **THEN** settings SHALL be organized in cards instead of Form
- **AND** it SHALL show a history limit slider (50-500 items, default 200)
- **AND** it SHALL show an auto-paste toggle
- **AND** it SHALL show a launch at login toggle (macOS 13+ using SMAppService)

### Requirement: Shortcuts Settings Tab
The system SHALL allow customization of global hotkeys in card-based layout.

#### Scenario: Hotkey recorder
- **WHEN** viewing the Shortcuts section
- **THEN** the hotkey recorder SHALL be displayed in a card
- **AND** it SHALL display the current hotkey combination
- **AND** it SHALL provide a recording interface to capture new key combinations
- **AND** it SHALL detect and warn about hotkey conflicts
- **AND** it SHALL validate that at least one modifier key is pressed

### Requirement: Tools Settings Tab
The system SHALL provide a dedicated Tools section for utility features.

#### Scenario: Tools menu placeholder
- **WHEN** viewing the Tools section
- **THEN** it SHALL display as the third menu item in the sidebar
- **AND** it SHALL use a wrench icon (SF Symbol: wrench.fill)
- **AND** it SHALL follow the same card-based layout as other settings pages
- **NOTE**: This is a placeholder for future tool-related features (plugins, extensions, integrations)

### Requirement: Privacy Settings Tab
The system SHALL provide privacy and filtering controls in card-based layout.

#### Scenario: Application filtering
- **WHEN** viewing the Privacy section
- **THEN** filtering options SHALL be displayed in cards
- **AND** it SHALL show toggles for password manager filtering
- **AND** it SHALL allow adding/removing apps from the ignore list
- **AND** it SHALL display the list of currently filtered applications

## ADDED Requirements

### Requirement: Advanced Settings Section
The system SHALL provide an Advanced section with system-level controls.

#### Scenario: Reset to defaults
- **WHEN** viewing the Advanced section
- **THEN** it SHALL display a "Reset to Defaults" button
- **AND** clicking the button SHALL show a confirmation dialog
- **AND** confirming SHALL reset all settings to factory defaults
- **AND** the action SHALL be logged and reversible (via backup)

## REMOVED Requirements

### Requirement: Tab-Based Layout
**Reason**: Replaced by sidebar navigation to align with macOS 26 System Settings style
**Migration**: All tabs converted to sidebar items; TabView code replaced with NavigationSplitView
