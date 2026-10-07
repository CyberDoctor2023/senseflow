## MODIFIED Requirements

### Requirement: Panel Window Configuration
The system SHALL display the main panel as a floating window at the bottom of the screen.

#### Scenario: Panel positioning
- **WHEN** the panel is shown
- **THEN** it SHALL be positioned at the bottom center of the screen, 20pt from the bottom edge
- **AND** the panel height SHALL be 280pt (fixed, does not change when content scrolls)
- **AND** the panel SHALL be edge-to-edge full width (left and right edges touch screen edges)
- **AND** the panel width SHALL equal screen width minus 0pt horizontal margin (full width layout)

#### Scenario: Panel appearance
- **WHEN** rendering the panel background
- **THEN** it SHALL use `NSGlassEffectView` with `.regular` style on macOS 26+
- **AND** the glass effect SHALL have optional subtle tint color
- **AND** it SHALL fall back to `NSVisualEffectView` with `.hudWindow` material + 18% white overlay on macOS 12-15
- **AND** the panel SHALL have 20pt corner radius (matches macOS 26 system apps)
- **AND** the panel SHALL be borderless (NSPanel.styleMask = .borderless)
- **AND** the panel SHALL appear fully transparent when empty (no visible frame)

#### Scenario: Panel window level
- **WHEN** the panel is shown
- **THEN** it SHALL use .statusBar window level to float above other windows
- **AND** it SHALL have collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

## ADDED Requirements

### Requirement: Panel Content Padding
The system SHALL apply appropriate spacing around panel content for visual breathing room.

#### Scenario: Padding application
- **WHEN** rendering panel content
- **THEN** it SHALL add 12pt invisible top padding
- **AND** it SHALL add 16pt horizontal padding on left and right sides
- **AND** the padding SHALL not affect the background material rendering

### Requirement: Panel Content Structure
The system SHALL organize panel content into two distinct regions.

#### Scenario: Two-region layout
- **WHEN** displaying the panel
- **THEN** the top region SHALL contain the search bar
- **AND** the bottom region SHALL contain the content area (clipboard items)
- **AND** the search bar region SHALL be fixed height (does not scroll)
- **AND** the content area SHALL scroll when items exceed visible space
- **AND** the panel height SHALL remain fixed at 280pt regardless of scroll state

### Requirement: Content Area Grid Layout
The system SHALL display clipboard items in a grid layout for browsing.

#### Scenario: Grid configuration
- **WHEN** rendering clipboard items in the content area
- **THEN** items SHALL be arranged in a horizontal scrolling grid
- **AND** the grid SHALL adapt to available height (may show multiple rows if height permits)
- **AND** when content exceeds visible area, ONLY the content area SHALL scroll (not the entire panel)
- **AND** the panel background SHALL remain stationary during scrolling
