## MODIFIED Requirements

### Requirement: Card Dimensions
The system SHALL display each clipboard item as a square card with consistent styling.

#### Scenario: Card size and corner radius
- **WHEN** rendering a clipboard card
- **THEN** the card SHALL be 180pt wide and 180pt tall (1:1 aspect ratio)
- **AND** the card SHALL have 20pt corner radius
- **AND** the card corner radius MUST match the panel background corner radius exactly (both 20pt for visual consistency)
- **AND** cards SHALL be spaced 12pt apart horizontally

### Requirement: Card Visual Hierarchy
The system SHALL use refined visual elements to distinguish card types and provide metadata.

#### Scenario: Type indicator stripe
- **WHEN** rendering a card
- **THEN** the top SHALL have a 3pt colored stripe
- **AND** text items SHALL use #007AFF (system blue)
- **AND** image items SHALL use #AF52DE (system purple)

#### Scenario: Content preview
- **WHEN** displaying text content
- **THEN** it SHALL show up to 4-5 lines of preview
- **AND** longer text SHALL be truncated with ellipsis
- **WHEN** displaying image content
- **THEN** it SHALL show a scaled thumbnail
- **AND** if OCR text exists, it SHALL display first 50 characters below the image

#### Scenario: Card background material
- **WHEN** rendering a card background
- **THEN** it SHALL use `NSGlassEffectView` with `.clear` style on macOS 26+
- **AND** the `.clear` material provides visual hierarchy by being less blurred than the panel's `.regular` material
- **AND** this layered material approach (panel `.regular` + cards `.clear`) follows macOS 26 system app design patterns
- **AND** multiple nearby cards SHALL use `NSGlassEffectContainerView` to merge rendering passes for performance
- **AND** the container SHALL have spacing threshold appropriate for card gaps
- **AND** it SHALL fall back to `NSVisualEffectView` with `.hudWindow` material + 6% white overlay on macOS 12-15
- **AND** it SHALL have a subtle system-level shadow (y-offset 2pt, blur 8pt, 10% black opacity)

## ADDED Requirements

### Requirement: Unified Metadata Bar
The system SHALL display all card metadata in a single unified bar at the bottom.

#### Scenario: Metadata bar layout
- **WHEN** rendering card metadata
- **THEN** it SHALL display a single horizontal bar at the bottom
- **AND** it SHALL show source app icon at 14pt size
- **AND** it SHALL show source app name next to the icon
- **AND** it SHALL show relative timestamp on the same line
- **AND** the bar SHALL have 8pt padding on left and right sides
- **AND** all elements SHALL be center-aligned vertically

## REMOVED Requirements

### Requirement: Separate Icon and Name Layout
**Reason**: Replaced by unified metadata bar for cleaner, more compact design
**Migration**: All metadata (icon, name, timestamp) now rendered in single bottom bar
