# Capability: Main Panel UI

## Overview
Backward compatibility updates for main panel to support macOS 13+.

## MODIFIED Requirements

### Requirement: Panel Window Configuration
The system SHALL display the main panel as a floating window at the bottom of the screen with version-appropriate visual effects.

#### Scenario: Panel positioning
- **WHEN** the panel is shown
- **THEN** it SHALL be positioned at the bottom center of the screen, 20pt from the bottom edge
- **AND** the panel height SHALL be 300pt
- **AND** the panel width SHALL auto-fit content with maximum of (screen width - 40pt)

#### Scenario: Panel appearance on macOS 26+
- **WHEN** rendering the panel background on macOS 26 or later
- **THEN** it SHALL use `.glassEffect(.regular)` for Liquid Glass effect
- **AND** the panel SHALL have 20pt corner radius
- **AND** the panel SHALL be borderless (NSPanel.styleMask = .borderless)

#### Scenario: Panel appearance on macOS 13-25
- **WHEN** rendering the panel background on macOS 13-25
- **THEN** it SHALL use `.thinMaterial` as fallback
- **AND** the panel SHALL have 20pt corner radius
- **AND** the panel SHALL be borderless (NSPanel.styleMask = .borderless)
- **AND** the visual quality SHALL be acceptable for production use

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

## ADDED Requirements

### Requirement: Compatibility Layer for Visual Effects
The system SHALL provide a compatibility layer that automatically selects appropriate visual effects based on macOS version.

#### Scenario: Glass effect modifier selection
- **WHEN** a view applies `.compatibleGlassEffect()` modifier
- **THEN** the system SHALL check macOS version using `#available`
- **AND** apply `.glassEffect(.regular)` on macOS 26+
- **AND** apply `.thinMaterial` background on macOS 13-25
- **AND** maintain consistent corner radius and padding

#### Scenario: Material fallback quality
- **WHEN** using `.thinMaterial` fallback on macOS 13-25
- **THEN** the visual quality SHALL be acceptable for production
- **AND** the blur effect SHALL provide sufficient contrast
- **AND** the appearance SHALL be consistent with macOS design guidelines
