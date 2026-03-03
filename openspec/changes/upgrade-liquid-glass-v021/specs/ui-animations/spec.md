## MODIFIED Requirements

### Requirement: Panel Show Animation
The system SHALL animate the panel appearance with snappier timing when invoked.

#### Scenario: Show animation timing
- **WHEN** the panel is shown
- **THEN** it SHALL use `.snappy(duration: 0.4, extraBounce: 0.0)` animation curve
- **AND** the panel SHALL slide up 30pt from below
- **AND** the animation SHALL provide a fast, crisp, modern iOS-style feel

### Requirement: Panel Hide Animation
The system SHALL animate the panel disappearance with quicker timing when dismissed.

#### Scenario: Hide animation timing
- **WHEN** the panel is hidden
- **THEN** it SHALL use `.smooth(duration: 0.3, extraBounce: 0.0)` animation curve
- **AND** the panel SHALL fade out (opacity 1.0 → 0.0)
- **AND** the panel SHALL slide down toward the bottom
- **AND** the animation SHALL provide a graceful, gentle exit

### Requirement: Card Entrance Animation
The system SHALL animate cards with bouncier, more playful timing as they appear in the list.

#### Scenario: Staggered entrance
- **WHEN** cards are loaded into the view
- **THEN** each card SHALL animate in with `.snappy(duration: 0.5, extraBounce: 0.15)` curve
- **AND** the animation SHALL provide a lively feel with subtle bounce
- **AND** each card SHALL have a 0.1s delay multiplied by its index
- **AND** cards SHALL scale from 0.9x to 1.0x (more subtle than before)
- **AND** cards SHALL fade from opacity 0.0 to 1.0
- **NOTE**: Card hover animations use `.snappy(duration: 0.25, extraBounce: 0.0)` for responsive feedback
