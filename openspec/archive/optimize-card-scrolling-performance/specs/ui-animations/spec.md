# UI Animations Spec Delta

## MODIFIED Requirements

### Requirement: Card Entrance Animation
The system SHALL animate cards as they appear in the list using modern animation APIs.

**Change Rationale**: Migrated from `.animation(_:value:)` to `PhaseAnimator` for better performance, declarative phase sequencing, and elimination of manual timing delays. PhaseAnimator is Apple's recommended modern animation system (iOS 17+/macOS 14+).

#### Scenario: Card entrance with PhaseAnimator
- **WHEN** a card view appears in the viewport
- **THEN** it SHALL use PhaseAnimator with two phases: [initial, active]
- **AND** the initial phase SHALL have scale 0.9 and opacity 0.0
- **AND** the active phase SHALL have scale 1.0 and opacity 1.0
- **AND** the transition SHALL use .snappy(duration: 0.5, extraBounce: 0.15) animation
- **AND** the system SHALL handle phase timing automatically (no manual delays)

#### Scenario: Natural stagger with lazy loading
- **WHEN** cards are loaded with LazyHStack
- **THEN** entrance animations SHALL trigger as each card scrolls into viewport
- **AND** this SHALL create natural stagger effect without index-based delays
- **AND** only visible cards SHALL animate on initial panel open

### Requirement: Card Hover Animation
The system SHALL provide smooth hover feedback on cards.

**Change Rationale**: No changes to hover animation; simple state toggle is appropriate for `.animation(_:value:)` API.

#### Scenario: Hover scale
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x with .snappy(duration: 0.25, extraBounce: 0.0) animation (unchanged)
- **AND** the delete button SHALL fade in with opacity 0→1 and scale 0.8→1.0 (unchanged)
- **AND** the animation SHALL use .snappy(duration: 0.3) for delete button (unchanged)
- **WHEN** the user stops hovering
- **THEN** the card SHALL scale back to 1.0x (unchanged)
- **AND** the delete button SHALL fade out (unchanged)

### Requirement: Panel Show Animation
The system SHALL animate the panel appearance when invoked.

**Change Rationale**: Updated timing to match v0.2.1 implementation (.snappy instead of spring).

#### Scenario: Show animation timing
- **WHEN** the panel is shown
- **THEN** it SHALL use .snappy(duration: 0.35, extraBounce: 0.0) animation (changed from 0.45s spring)
- **AND** the panel SHALL slide up 30pt from below (unchanged)
- **AND** the panel SHALL fade from opacity 0.0 to 1.0 (unchanged)

### Requirement: Panel Hide Animation
The system SHALL animate the panel disappearance when dismissed.

**Change Rationale**: Updated timing to match v0.2.1 implementation (.smooth instead of ease-out).

#### Scenario: Hide animation timing
- **WHEN** the panel is hidden
- **THEN** it SHALL use .smooth(duration: 0.3, extraBounce: 0.0) animation (changed from 0.35s ease-out)
- **AND** the panel SHALL fade out (opacity 1.0 → 0.0) (unchanged)
- **AND** the panel SHALL slide down toward the bottom (unchanged)

## ADDED Requirements

### Requirement: Lazy Loading Performance
The system SHALL use lazy loading for horizontal card scrolling to optimize performance with large item counts.

**Change Rationale**: Replace eager HStack with LazyHStack to enable on-demand rendering. Apple documentation shows 95%+ reduction in initial view count (1000 views → 4 views) with lazy stacks.

#### Scenario: On-demand card rendering
- **WHEN** displaying clipboard history with LazyHStack
- **THEN** only visible cards SHALL be rendered initially (approximately 10 cards for 280pt panel height)
- **AND** additional cards SHALL be rendered as the user scrolls
- **AND** off-screen cards MAY be deallocated to conserve memory
- **AND** each card SHALL maintain stable identity via `.id(item.id)` modifier

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
- **AND** the system SHALL handle rapid scrolling without stuttering

#### Scenario: View identity during updates
- **WHEN** the card list updates (search filter, new item, deletion)
- **THEN** each card SHALL maintain stable identity via item.id
- **AND** animations SHALL not break during list updates
- **AND** cards SHALL not flicker or re-render unnecessarily

### Requirement: Animation Performance Characteristics
The system SHALL maintain efficient animation performance under all conditions.

**Change Rationale**: Document measurable performance targets for animation system.

#### Scenario: CPU usage during animations
- **WHEN** cards are animating (entrance, hover, or transitions)
- **THEN** CPU usage SHALL remain below 5% on modern Macs (2020+)
- **AND** animations SHALL not block the main thread
- **AND** the system SHALL maintain 60fps during all animations

#### Scenario: Animation timing accuracy
- **WHEN** using PhaseAnimator for card entrance
- **THEN** the animation duration SHALL be 0.5 seconds (±10ms)
- **AND** the spring parameters SHALL match .snappy(extraBounce: 0.15)
- **AND** the animation SHALL feel identical to previous .animation() implementation

## Cross-References

**Related Capabilities**:
- `ui-cards` - Card dimensions (180×180pt) affect animation viewport calculations
- `ui-main-panel` - Panel height (280pt) determines number of initially visible cards (~10)

**Dependencies**:
- LazyHStack requires stable view identity (`.id()` modifier)
- PhaseAnimator requires macOS 14.0+ (project already requires 26.0+)
- Performance targets assume modern hardware (2020+ Macs with Apple Silicon or Intel)
