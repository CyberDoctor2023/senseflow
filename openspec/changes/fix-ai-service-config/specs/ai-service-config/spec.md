# Spec: AI Service Configuration

**Capability**: AI Service Configuration
**Change**: fix-ai-service-config

## MODIFIED Requirements

### Requirement: Multi-Provider SDK Configuration

The system SHALL configure MacPaw OpenAI SDK using structured parameters (host, scheme, port) instead of parsing full URLs.

#### Scenario: OpenAI Configuration
- **GIVEN** user selects OpenAI service
- **WHEN** AIService creates client
- **THEN** Configuration uses `host: "api.openai.com"`, `scheme: "https"`, `port: 443`

#### Scenario: Gemini Configuration
- **GIVEN** user selects Gemini service
- **WHEN** AIService creates client
- **THEN** Configuration uses `host: "generativelanguage.googleapis.com"`, `scheme: "https"`, `port: 443`
- **AND** model is `"gemini-2.5-flash"`

#### Scenario: DeepSeek Configuration
- **GIVEN** user selects DeepSeek service
- **WHEN** AIService creates client
- **THEN** Configuration uses `host: "api.deepseek.com"`, `scheme: "https"`, `port: 443`

#### Scenario: Ollama Local Configuration
- **GIVEN** user selects Ollama service
- **WHEN** AIService creates client
- **THEN** Configuration uses `host: "localhost"`, `scheme: "http"`, `port: 11434`

---

### Requirement: OpenRouter Integration

The system SHALL support OpenRouter as a unified API gateway for multiple AI providers.

#### Scenario: OpenRouter Basic Configuration
- **GIVEN** user selects OpenRouter service
- **WHEN** AIService creates client
- **THEN** Configuration uses `host: "openrouter.ai"`, `scheme: "https"`, `port: 443`
- **AND** API Key is stored in Keychain with key `openrouterAPIKey`

#### Scenario: OpenRouter Model Selection
- **GIVEN** user selects OpenRouter service
- **WHEN** generating text
- **THEN** system uses default model `"openai/gpt-4o-mini"` OR user-specified model

---

### Requirement: Non-OpenAI Provider Compatibility

The system SHALL use relaxed parsing options for non-OpenAI providers to handle response format variations.

#### Scenario: Relaxed Parsing for Alternative Providers
- **GIVEN** user selects Gemini, DeepSeek, or OpenRouter
- **WHEN** AIService creates Configuration
- **THEN** Configuration includes `parsingOptions: .relaxed`

#### Scenario: Strict Parsing for OpenAI
- **GIVEN** user selects OpenAI service
- **WHEN** AIService creates Configuration
- **THEN** Configuration uses default parsing (no relaxed mode)

---

## REMOVED Requirements

- **URL Parsing for Endpoint Configuration**: The system previously parsed full URL strings to extract host, scheme, and port for SDK configuration. Removed because MacPaw SDK accepts structured parameters directly; URL parsing introduces bugs and complexity.

- **Claude Native API Support**: The system previously supported Claude native API endpoint (`api.anthropic.com`). Removed because MacPaw OpenAI SDK does not support Claude's native message format. Users should use OpenRouter for Claude models.

---

## Implementation Notes

- **Migration Path**: Existing Claude users need to switch to OpenRouter and select `anthropic/claude-3.5-sonnet` model
- **Vision API**: Limited to OpenAI service only (other providers require different formats)
- **Keychain Keys**: Add `openrouterAPIKey` to KeychainManager.Keys

## Cross-References

- Related to: `prompt-tools-reliability` (Vision API limitations)
- Depends on: MacPaw OpenAI SDK v0.3+ (already in use)
