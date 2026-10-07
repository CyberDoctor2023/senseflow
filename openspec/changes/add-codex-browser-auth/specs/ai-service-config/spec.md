# Spec: AI Service Configuration

**Capability**: AI Service Configuration
**Change**: add-codex-browser-auth

## ADDED Requirements

### Requirement: Codex Browser Authentication

The system SHALL support a Codex AI service option that authenticates through a SenseFlow-owned Codex browser OAuth flow instead of requiring a manually pasted API key.

#### Scenario: Launch Codex browser login
- **GIVEN** user selects Codex in AI Service settings
- **WHEN** user clicks the Codex login action
- **THEN** the system launches Codex OAuth in the browser with a local callback
- **AND** stores successful credentials in SenseFlow Keychain
- **AND** the system does not display or copy any Codex token into the UI

#### Scenario: Show Codex auth status
- **GIVEN** user selects Codex in AI Service settings
- **WHEN** settings loads or user refreshes status
- **THEN** the system reports whether SenseFlow-owned Codex ChatGPT auth is available
- **AND** any displayed account metadata excludes bearer and refresh tokens

#### Scenario: Ignore global CLI auth state
- **GIVEN** the user has a global Codex CLI login in `~/.codex/auth.json`
- **AND** SenseFlow has no Codex credentials in its own Keychain item
- **WHEN** user opens Codex settings
- **THEN** the system reports Codex as not logged in

### Requirement: Codex Authenticated Text Generation

The system SHALL use SenseFlow-owned Codex ChatGPT auth credentials for Codex-backed text generation.

#### Scenario: Generate with Codex auth
- **GIVEN** user selects Codex as the AI service
- **AND** local Codex ChatGPT auth is available
- **WHEN** Prompt Tools requests text generation
- **THEN** SenseFlow sends a Codex-authenticated text request
- **AND** the request body uses a Responses message-array `input` with `input_text` content
- **AND** records a redacted request payload in the API inspector

#### Scenario: Missing Codex auth
- **GIVEN** user selects Codex as the AI service
- **AND** local Codex ChatGPT auth is not available
- **WHEN** Prompt Tools requests text generation or connection testing
- **THEN** the system fails with the existing AI service not configured error
