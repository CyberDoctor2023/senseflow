# Capability: UI Animations

## Overview
Backward compatibility updates for animations to support macOS 13+.

## MODIFIED Requirements

### Requirement: Card Entrance Animation
The system SHALL animate cards entering the view with version-appropriate animation APIs.

#### Scenario: Entrance animation on macOS 14+
- **WHEN** a card appears on macOS 14 or later
- **THEN** it SHALL use PhaseAnimator for multi-phase animation
- **AND** animate from scale 0.8 to 1.0
- **AND** animate from opacity 0 to 1
- **AND** use .snappy(duration: 0.5, extraBounce: 0.15) curve

#### Scenario: Entrance animation on macOS 13
- **WHEN** a card appears on macOS 13
- **THEN** it SHALL use .animation() modifier as fallback
- **AND** animate from scale 0.8 to 1.0
- **AND** animate from opacity 0 to 1
- **AND** use .snappy(duration: 0.5) curve (no extraBounce parameter)
- **AND** the animation SHALL be visually acceptable

#### Scenario: Animation performance
- **WHEN** animating multiple cards simultaneously
- **THEN** the frame rate SHALL maintain 60fps on all supported macOS versions
- **AND** the CPU usage SHALL remain below 5% during animations
- **AND** the animations SHALL complete within expected duration

### Requirement: Card Hover Animation
The system SHALL animate card hover state consistently across macOS versions.

#### Scenario: Hover scale animation
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x
- **AND** use .smooth(duration: 0.2) animation curve
- **AND** the animation SHALL work identically on macOS 13-26

#### Scenario: Delete button appearance
- **WHEN** the card is hovered
- **THEN** the delete button SHALL fade in with opacity animation
- **AND** use .smooth(duration: 0.15) curve
- **AND** the button SHALL be fully visible within 150ms

## ADDED Requirements

### Requirement: Animation Compatibility Wrapper
The system SHALL provide a compatibility wrapper for PhaseAnimator that works on macOS 13+.

#### Scenario: CompatiblePhaseAnimator on macOS 14+
- **WHEN** using CompatiblePhaseAnimator on macOS 14 or later
- **THEN** it SHALL use native PhaseAnimator implementation
- **AND** support all phase-based animation features
- **AND** maintain full API compatibility

#### Scenario: CompatiblePhaseAnimator on macOS 13
- **WHEN** using CompatiblePhaseAnimator on macOS 13
- **THEN** it SHALL fall back to .animation() modifier
- **AND** simulate phase-based behavior with single animation
- **AND** preserve animation parameters (duration, curve)
- **AND** provide acceptable visual result

#### Scenario: Animation parameter preservation
- **WHEN** falling back to .animation() on macOS 13
- **THEN** the wrapper SHALL preserve duration parameter
- **AND** map animation curve appropriately (.snappy → .spring)
- **AND** ignore unsupported parameters gracefully (extraBounce)
- **AND** document parameter limitations in code comments
