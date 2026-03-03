# Capability: Settings UI

## Overview
Backward compatibility validation for settings UI (already compatible with macOS 13+).

## MODIFIED Requirements

### Requirement: Settings Window Layout
The system SHALL display settings in a NavigationSplitView layout on macOS 13+.

#### Scenario: Settings window on macOS 13+
- **WHEN** opening settings on macOS 13 or later
- **THEN** it SHALL use NavigationSplitView (available since macOS 13)
- **AND** display sidebar with 5 categories
- **AND** display detail view with Form-based content
- **AND** support window resizing with .contentSize

#### Scenario: Settings Scene lifecycle
- **WHEN** using Settings Scene on macOS 13+
- **THEN** it SHALL use native Settings scene (available since macOS 11)
- **AND** automatically manage window lifecycle
- **AND** provide ⌘, keyboard shortcut
- **AND** integrate with App menu

## ADDED Requirements

### Requirement: Settings Material Compatibility
The system SHALL ensure settings UI uses compatible materials on all macOS versions.

#### Scenario: Settings background material
- **WHEN** rendering settings window background
- **THEN** it SHALL use system default window background
- **AND** NOT use .glassEffect() (settings should use standard appearance)
- **AND** maintain consistent appearance on macOS 13-26

#### Scenario: Settings form controls
- **WHEN** rendering form controls in settings
- **THEN** all controls SHALL be compatible with macOS 13+
- **AND** Toggle, Picker, TextField, SecureField SHALL work identically
- **AND** no version-specific UI components SHALL be used
