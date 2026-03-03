# Animation Specification

## Overview
Animations provide smooth transitions and visual feedback throughout the UI.

## Requirements

### Requirement: Panel Show Animation
The system SHALL animate the panel appearance when invoked.

#### Scenario: Show animation timing
- **WHEN** the panel is shown
- **THEN** it SHALL use .snappy(duration: 0.35, extraBounce: 0.0) animation
- **AND** the panel SHALL slide up 30pt from below
- **AND** the panel SHALL fade from opacity 0.0 to 1.0

### Requirement: Panel Hide Animation
The system SHALL animate the panel disappearance when dismissed.

#### Scenario: Hide animation timing
- **WHEN** the panel is hidden
- **THEN** it SHALL use .smooth(duration: 0.3, extraBounce: 0.0) animation
- **AND** the panel SHALL fade out (opacity 1.0 → 0.0)
- **AND** the panel SHALL slide down toward the bottom

### Requirement: Card Entrance Animation
The system SHALL animate cards as they appear in the list using PhaseAnimator.

#### Scenario: Card entrance with PhaseAnimator
- **WHEN** a card view appears in the viewport
- **THEN** it SHALL use PhaseAnimator with two phases: [false, true]
- **AND** the initial phase SHALL have scale 0.9 and opacity 0.0
- **AND** the active phase SHALL have scale 1.0 and opacity 1.0
- **AND** the transition SHALL use .snappy(duration: 0.5, extraBounce: 0.15) animation
- **AND** the system SHALL handle phase timing automatically

#### Scenario: Natural stagger with lazy loading
- **WHEN** cards are loaded with LazyHStack
- **THEN** entrance animations SHALL trigger as each card scrolls into viewport
- **AND** this SHALL create natural stagger effect without manual delays
- **AND** only visible cards SHALL animate on initial panel open

### Requirement: Card Hover Animation
The system SHALL provide smooth hover feedback on cards.

#### Scenario: Hover scale
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x with .snappy(duration: 0.25, extraBounce: 0.0) animation
- **AND** the delete button SHALL fade in with opacity 0→1 and scale 0.8→1.0
- **AND** the delete button SHALL use .snappy(duration: 0.3) animation
- **WHEN** the user stops hovering
- **THEN** the card SHALL scale back to 1.0x
- **AND** the delete button SHALL fade out

### Requirement: Lazy Loading Performance
The system SHALL use lazy loading for horizontal card scrolling to optimize performance.

#### Scenario: On-demand card rendering
- **WHEN** displaying clipboard history with LazyHStack
- **THEN** only visible cards SHALL be rendered initially (approximately 10 cards)
- **AND** additional cards SHALL be rendered as the user scrolls
- **AND** each card SHALL maintain stable identity via .id(item.id) modifier

#### Scenario: Initial load performance
- **WHEN** opening the panel with 200 history items
- **THEN** the panel SHALL open in less than 200ms
- **AND** only visible cards SHALL trigger entrance animations
- **AND** memory usage SHALL be less than 50MB for 200 items

#### Scenario: Scrolling performance
- **WHEN** the user scrolls horizontally through card list
- **THEN** the frame rate SHALL maintain 60fps
- **AND** cards SHALL render smoothly as they enter viewport
- **AND** entrance animations SHALL not cause frame drops

### Requirement: Animation Performance Characteristics
The system SHALL maintain efficient animation performance under all conditions.

#### Scenario: CPU usage during animations
- **WHEN** cards are animating (entrance, hover, or transitions)
- **THEN** CPU usage SHALL remain below 5% on modern Macs
- **AND** animations SHALL not block the main thread
- **AND** the system SHALL maintain 60fps during all animations
