# Animation Specification Delta

## MODIFIED Requirements

### Requirement: Card Entrance Animation
The system SHALL animate cards as they appear in the list.

#### Scenario: Staggered entrance
- **WHEN** cards are loaded into the view
- **THEN** each card SHALL animate in with 0.5s spring animation with 0.15 extraBounce
- **AND** each card SHALL have a 0.1s delay before animation starts
- **AND** cards SHALL scale from 0.9x to 1.0x
- **AND** cards SHALL fade from opacity 0.0 to 1.0
- **AND** the entrance animation SHALL be bound to the `appeared` state variable
- **AND** the entrance animation SHALL NOT interfere with hover animations

**Change**: Added explicit binding requirement and non-interference constraint.

### Requirement: Card Hover Animation
The system SHALL provide smooth hover feedback on cards.

#### Scenario: Hover scale
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x (multiplicative with entrance scale) with 0.25s spring animation
- **AND** the hover animation SHALL be bound to the `isHovered` state variable
- **AND** the delete button SHALL fade in with scale + opacity transition
- **WHEN** the user stops hovering
- **THEN** the card SHALL scale back to 1.0x
- **AND** the delete button SHALL fade out

#### Scenario: Hover during entrance
- **WHEN** the user hovers over a card while entrance animation is playing
- **THEN** both animations SHALL execute independently
- **AND** the final scale SHALL be the product of entrance scale and hover scale
- **AND** there SHALL be no visual glitches or animation conflicts

**Change**: Added independent animation binding and entrance-hover interaction scenario.
