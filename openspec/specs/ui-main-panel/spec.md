# Main Panel UI Specification

## Overview
The main panel is a floating bottom sheet that displays clipboard history items in a horizontal scrollable layout.

## Requirements

### Requirement: Panel Window Configuration
The system SHALL display the main panel as a floating window at the bottom of the screen.

#### Scenario: Panel positioning
- **WHEN** the panel is shown
- **THEN** it SHALL be positioned at the bottom center of the screen, 20pt from the bottom edge
- **AND** the panel height SHALL be 300pt
- **AND** the panel width SHALL auto-fit content with maximum of (screen width - 40pt)

#### Scenario: Panel appearance
- **WHEN** rendering the panel background
- **THEN** it SHALL use `.popover` NSVisualEffectView material on macOS 15+
- **AND** it SHALL fall back to `.regular` material on macOS 12-14
- **AND** the panel SHALL have 12pt corner radius
- **AND** the panel SHALL be borderless (NSPanel.styleMask = .borderless)

#### Scenario: Panel window level
- **WHEN** the panel is shown
- **THEN** it SHALL use .statusBar window level to float above other windows
- **AND** it SHALL have collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

### Requirement: Panel Auto-hide Behavior
The system SHALL automatically hide the panel when it loses focus.

#### Scenario: Focus loss
- **WHEN** the user clicks outside the panel
- **THEN** the panel SHALL hide with animation
- **AND** the previous application SHALL regain focus

### Requirement: Panel Content Layout
The system SHALL display clipboard items in a horizontal scrolling layout within the panel.

#### Scenario: Horizontal scrolling
- **WHEN** there are multiple clipboard items
- **THEN** they SHALL be arranged horizontally in a ScrollView
- **AND** the user SHALL be able to scroll left/right to view more items
- **AND** the most recent item SHALL be displayed on the left

#### Scenario: Empty state
- **WHEN** there are no clipboard items
- **THEN** the panel SHALL display a friendly empty state message
- **AND** the message SHALL guide users on how to start using the app
