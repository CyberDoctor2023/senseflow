# Spec Delta: AI Vision API

**Capability**: `ai-vision-api`
**Change**: ADDED

---

## ADDED Requirements

### Requirement: Vision API Service Support

AI services MUST declare their Vision API capabilities to enable multimodal context analysis in Smart AI Recommendations.

#### Scenario: Gemini Vision API with screenshot context

**Given** the user has selected Gemini as their AI service
**And** the user has configured a valid Gemini API key
**And** Smart AI lightweight mode is disabled
**When** the user triggers Smart AI Recommendation with a screenshot available
**Then** the system MUST send both text prompt AND base64-encoded screenshot to Gemini
**And** Gemini MUST receive the data in `InlineDataPart` format with MIME type
**And** the AI response MUST consider visual elements from the screenshot

**Implementation Note**: Use Google GenerativeAI SDK's `InlineDataPart(data: Data, mimeType: String)` to construct multimodal input.

#### Scenario: Service capability declaration

**Given** an AI service type (OpenAI, Gemini, Claude, etc.)
**When** the system checks Vision API support
**Then** the service MUST accurately report its Vision capabilities:
- OpenAI: MUST return `true` (supported)
- Gemini: MUST return `true` (supported)
- Claude: MUST return `false` (not supported in current implementation)
- DeepSeek: MUST return `false` (API does not support Vision)
- Ollama: MUST return `false` (capability varies by model)
- OpenRouter: MAY return `true` (depends on underlying model)

**Implementation Note**: Add `supportsVision` computed property to `AIServiceType` enum.

#### Scenario: Graceful fallback for unsupported services

**Given** the user has selected a service without Vision support (e.g., DeepSeek)
**And** a screenshot is available in the context
**When** Smart AI Recommendation is triggered
**Then** the system SHALL fall back to text-only mode
**And** SHALL NOT send the screenshot to the API
**And** MAY log a debug message indicating Vision fallback

---

### Requirement: Vision API Error Handling

Vision API calls MUST handle errors gracefully and provide meaningful feedback to users.

#### Scenario: Invalid image data

**Given** a base64-encoded screenshot is corrupted or invalid
**When** the system attempts to create `InlineDataPart` from the data
**Then** the system MUST catch the decoding error
**And** MUST fall back to text-only mode
**And** SHALL log an error message for debugging

#### Scenario: API quota exceeded

**Given** the Gemini API quota has been exceeded
**When** a Vision API request is made
**Then** the system MUST catch the API error
**And** MUST present a user-friendly error message
**And** SHALL NOT crash or hang the application

---

### Requirement: UI Feedback for Vision Support

Settings UI MUST accurately reflect which AI services support Vision API.

#### Scenario: Warning for unsupported services

**Given** the user has selected DeepSeek as their AI service
**When** viewing the Prompt Tools settings
**Then** the UI MUST display a warning: "Vision feature requires OpenAI or Gemini"
**And** the warning SHALL NOT appear when OpenAI or Gemini is selected

**Implementation Note**: Replace hardcoded `.openai` check with `supportsVision` property check.
