# Search UI Specification

## Overview
The search bar allows users to filter clipboard history by text content, app name, and OCR text.

## Requirements

### Requirement: Search Bar Placement
The system SHALL display a search bar at the top of the main panel.

#### Scenario: Search bar layout
- **WHEN** the panel is shown
- **THEN** the search bar SHALL be positioned at the top above the card list
- **AND** it SHALL have a semi-transparent black background (5% opacity white)
- **AND** it SHALL auto-focus when the panel appears

### Requirement: Real-time Search Filtering
The system SHALL filter clipboard items in real-time as the user types.

#### Scenario: Search with debounce
- **WHEN** the user types in the search field
- **THEN** the system SHALL debounce input for 300ms
- **AND** it SHALL filter items matching the search query
- **AND** it SHALL search across text content, app name, and OCR text

#### Scenario: Empty search results
- **WHEN** the search query returns no matches
- **THEN** the system SHALL display a friendly "No results found" message
- **AND** it SHALL suggest clearing the search or trying different keywords

### Requirement: Search Text Selection
The system SHALL allow users to select and copy text from the search field.

#### Scenario: Text selection
- **WHEN** the user selects text in the search field
- **THEN** the system SHALL enable text selection (.textSelection(.enabled))
- **AND** it SHALL allow copying via Cmd+C
- **AND** it SHALL support standard text editing shortcuts (Cmd+A, Cmd+X, Cmd+V)
