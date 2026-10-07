# Card UI Specification

## Overview
Each clipboard item is displayed as a card with preview content, metadata, and visual indicators.

## Requirements

### Requirement: Card Dimensions
The system SHALL display each clipboard item as a fixed-size square card.

#### Scenario: Card size
- **WHEN** rendering a clipboard card
- **THEN** the card SHALL be 180pt wide and 180pt tall
- **AND** the card SHALL have 20pt corner radius
- **AND** cards SHALL be spaced 12pt apart horizontally

### Requirement: Card Visual Hierarchy
The system SHALL use visual elements to distinguish card types and provide metadata.

#### Scenario: Type indicator stripe
- **WHEN** rendering a card
- **THEN** the top SHALL have a 3pt colored stripe
- **AND** text items SHALL use #007AFF (system blue)
- **AND** image items SHALL use #AF52DE (system purple)

#### Scenario: Content preview
- **WHEN** displaying text content
- **THEN** it SHALL show up to 8 lines of preview
- **AND** longer text SHALL be truncated with ellipsis
- **WHEN** displaying image content
- **THEN** it SHALL show a scaled thumbnail
- **AND** the thumbnail SHALL fit within 120pt max height

#### Scenario: Metadata display
- **WHEN** rendering a card
- **THEN** the bottom SHALL show the source app icon (14pt)
- **AND** it SHALL show the source app name
- **AND** it SHALL show a relative timestamp

### Requirement: Card Interactions
The system SHALL provide visual feedback and actions on card interaction.

#### Scenario: Hover effect
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x with smooth animation
- **AND** a delete button (red X icon) SHALL appear in the top-right corner

#### Scenario: Click to paste
- **WHEN** the user clicks a card
- **THEN** the card content SHALL be written to the system clipboard
- **AND** if auto-paste is enabled, the system SHALL simulate Cmd+V after 0.3s
- **AND** the panel SHALL hide immediately

#### Scenario: Delete action
- **WHEN** the user clicks the delete button
- **THEN** a confirmation dialog SHALL appear
- **AND** if confirmed, the item SHALL be deleted from history
- **AND** the card SHALL be removed from the view with animation

### Requirement: Card Background Material
The system SHALL use appropriate background materials for cards.

#### Scenario: Card material
- **WHEN** rendering a card background
- **THEN** it SHALL use `.thinMaterial` SwiftUI material
- **AND** it SHALL have 20pt corner radius matching card shape
- **AND** it SHALL have subtle shadow (8pt radius, 2pt y-offset, 10% black opacity)
- **AND** the material SHALL provide automatic vibrancy for foreground content
