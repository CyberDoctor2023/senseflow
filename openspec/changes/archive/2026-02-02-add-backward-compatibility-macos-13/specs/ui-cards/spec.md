# Capability: Card UI

## Overview
Backward compatibility updates for clipboard card components to support macOS 13+.

## MODIFIED Requirements

### Requirement: Card Visual Appearance
The system SHALL render clipboard cards with version-appropriate visual effects and materials.

#### Scenario: Card background on macOS 26+
- **WHEN** rendering a card on macOS 26 or later
- **THEN** it SHALL use `.glassEffect(.regular)` for Liquid Glass background
- **AND** the card SHALL have 12pt corner radius
- **AND** the card SHALL have subtle shadow for depth

#### Scenario: Card background on macOS 13-25
- **WHEN** rendering a card on macOS 13-25
- **THEN** it SHALL use `.thinMaterial` as fallback background
- **AND** the card SHALL have 12pt corner radius
- **AND** the card SHALL have subtle shadow for depth
- **AND** the visual quality SHALL be acceptable for production use

#### Scenario: Card hover state
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x with smooth animation
- **AND** the delete button SHALL appear
- **AND** the animation SHALL work consistently on all macOS versions

### Requirement: Card Content Layout
The system SHALL display card content with proper spacing and typography.

#### Scenario: Text content display
- **WHEN** displaying text content in a card
- **THEN** it SHALL show up to 3 lines of text
- **AND** truncate with ellipsis if longer
- **AND** use system font with appropriate size

#### Scenario: Image content display
- **WHEN** displaying image content in a card
- **THEN** it SHALL show thumbnail with aspect ratio preserved
- **AND** fit within card bounds (200pt width)
- **AND** show OCR text if available

## ADDED Requirements

### Requirement: Compatibility Layer for Card Effects
The system SHALL provide compatibility wrappers for card visual effects.

#### Scenario: Glass effect modifier on cards
- **WHEN** a card applies `.compatibleGlassEffect()` modifier
- **THEN** the system SHALL select appropriate effect based on macOS version
- **AND** maintain consistent visual hierarchy
- **AND** ensure text remains readable on all backgrounds

#### Scenario: Material quality validation
- **WHEN** using fallback materials on macOS 13-25
- **THEN** the card SHALL maintain sufficient contrast with content
- **AND** the blur effect SHALL not interfere with readability
- **AND** the appearance SHALL match macOS design guidelines
