# UI Cards Spec Delta

## MODIFIED Requirements

### Requirement: Card Dimensions
The system SHALL display each clipboard item as a fixed-size square card.

**Change Rationale**: v0.2.1 updated card design to square format (180×180pt) with larger corner radius (20pt) for modern macOS aesthetic.

#### Scenario: Card size
- **WHEN** rendering a clipboard card
- **THEN** the card SHALL be 180pt wide and 180pt tall (changed from 160×200pt)
- **AND** the card SHALL have 20pt corner radius (changed from 10pt)
- **AND** cards SHALL be spaced 12pt apart horizontally (unchanged)

### Requirement: Card Visual Hierarchy
The system SHALL use visual elements to distinguish card types and provide metadata.

**Change Rationale**: Reduced stripe height for more subtle visual indicator, aligns with macOS 26 design language.

#### Scenario: Type indicator stripe
- **WHEN** rendering a card
- **THEN** the top SHALL have a 3pt colored stripe (changed from 4pt)
- **AND** text items SHALL use #007AFF (system blue) (unchanged)
- **AND** image items SHALL use #AF52DE (system purple) (unchanged)

#### Scenario: Content preview
- **WHEN** displaying text content
- **THEN** it SHALL show up to 8 lines of preview (changed from 3 lines)
- **AND** longer text SHALL be truncated with ellipsis (unchanged)
- **AND** text SHALL use 13pt system font (unchanged)
- **WHEN** displaying image content
- **THEN** it SHALL show a scaled thumbnail (unchanged)
- **AND** the thumbnail SHALL fit within 120pt max height (unchanged)
- **AND** the thumbnail SHALL have 6pt corner radius (unchanged)

#### Scenario: Metadata display
- **WHEN** rendering a card
- **THEN** the bottom SHALL show the source app icon at 14pt size (changed from 16pt)
- **AND** it SHALL show the source app name at 10pt font (unchanged)
- **AND** it SHALL show a relative timestamp at 10pt font (unchanged)
- **AND** metadata SHALL have 8pt horizontal padding (unchanged)

### Requirement: Card Background Material
The system SHALL use appropriate background materials for cards.

**Change Rationale**: Switched to .thinMaterial for better translucency and vibrancy, aligns with Apple's material design guidelines.

#### Scenario: Card material
- **WHEN** rendering a card background
- **THEN** it SHALL use `.thinMaterial` SwiftUI material (changed from .regular NSVisualEffectView)
- **AND** it SHALL have 20pt corner radius matching card shape (changed from 10pt)
- **AND** it SHALL have subtle shadow (8pt radius, 2pt y-offset, 10% black opacity) (unchanged)
- **AND** the material SHALL provide automatic vibrancy for foreground content (new)

### Requirement: Card Interactions
The system SHALL provide visual feedback and actions on card interaction.

**Change Rationale**: No changes to interaction behavior, only visual refinements.

#### Scenario: Hover effect
- **WHEN** the user hovers over a card
- **THEN** the card SHALL scale to 1.05x with .snappy(duration: 0.25) animation (unchanged)
- **AND** a delete button (20pt red circle with X icon) SHALL appear in top-right corner (unchanged)
- **AND** the delete button SHALL fade in with opacity 0→1 and scale 0.8→1.0 (unchanged)

#### Scenario: Click to paste
- **WHEN** the user clicks a card
- **THEN** the card content SHALL be written to the system clipboard (unchanged)
- **AND** if auto-paste is enabled, the system SHALL simulate Cmd+V after 0.3s (unchanged)
- **AND** the panel SHALL hide immediately (unchanged)

#### Scenario: Delete action
- **WHEN** the user clicks the delete button
- **THEN** a confirmation dialog SHALL appear (unchanged)
- **AND** if confirmed, the item SHALL be deleted from history (unchanged)
- **AND** the card SHALL be removed from the view with animation (unchanged)

## Cross-References

**Related Capabilities**:
- `ui-animations` - Card entrance and hover animations depend on card dimensions
- `ui-main-panel` - Panel height (280pt) accommodates 180pt card height + padding
