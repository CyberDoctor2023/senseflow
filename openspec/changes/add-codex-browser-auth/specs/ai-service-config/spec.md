# Spec: AI Service Configuration

**Capability**: AI Service Configuration
**Change**: add-codex-browser-auth

## ADDED Requirements

### Requirement: Codex Browser Authentication

The system SHALL support a Codex AI service option that authenticates through the local Codex browser login flow instead of requiring a manually pasted API key.

#### Scenario: Launch Codex browser login
- **GIVEN** user selects Codex in AI Service settings
- **WHEN** user clicks the Codex login action
- **THEN** the system launches the official `codex login` browser flow
- **AND** the system does not display or copy any Codex token into the UI

#### Scenario: Show Codex auth status
- **GIVEN** user selects Codex in AI Service settings
- **WHEN** settings loads or user refreshes status
- **THEN** the system reports whether local Codex ChatGPT auth is available
- **AND** any displayed account metadata excludes bearer and refresh tokens

### Requirement: Codex Authenticated Text Generation

The system SHALL use local Codex ChatGPT auth credentials for Codex-backed text generation.

#### Scenario: Generate with Codex auth
- **GIVEN** user selects Codex as the AI service
- **AND** local Codex ChatGPT auth is available
- **WHEN** Prompt Tools requests text generation
- **THEN** SenseFlow sends a Codex-authenticated text request
- **AND** records a redacted request payload in the API inspector

#### Scenario: Missing Codex auth
- **GIVEN** user selects Codex as the AI service
- **AND** local Codex ChatGPT auth is not available
- **WHEN** Prompt Tools requests text generation or connection testing
- **THEN** the system fails with the existing AI service not configured error
