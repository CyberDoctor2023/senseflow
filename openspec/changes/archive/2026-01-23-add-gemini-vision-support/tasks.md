# Tasks: Add Gemini Vision API Support

**Change ID**: `add-gemini-vision-support`

---

## Task List

### 1. Implement Gemini Vision API in GeminiService
- [x] **File**: `SenseFlow/Services/GeminiService.swift`
- [x] **Action**: Replace `generateWithImage()` stub with real implementation
  - Convert base64 string to `Data`
  - Create `InlineDataPart` with image data and MIME type
  - Build multimodal `ModelContent` with text + image parts
  - Call `model.generateContent()` with multimodal input
  - Handle errors and extract response text
- [x] **Validation**: Build succeeds, no compiler errors

### 2. Add Vision capability detection to AIServiceType
- [x] **File**: `SenseFlow/Models/PromptTool.swift`
- [x] **Action**: Add `supportsVision` computed property to `AIServiceType`
  - Return `true` for `.openai` and `.gemini`
  - Return `false` for `.claude`, `.deepseek`, `.ollama`
  - Return `true` for `.openrouter` (model-dependent)
- [x] **Validation**: Type-safe capability checks

### 3. Update UI warnings in Settings
- [x] **File**: `SenseFlow/Views/Settings/PromptToolsSettingsView.swift`
- [x] **Action**: Replace hardcoded OpenAI check with `supportsVision` check
  - Change condition from `selectedService != .openai` to `!selectedService.supportsVision`
  - Update warning text to list supported services: "Vision requires OpenAI or Gemini"
- [x] **Validation**: Warning appears correctly for unsupported services

### 4. Manual testing with Gemini
- [x] **Action**:
  - Switch to Gemini in Settings
  - Trigger Smart AI (⌘⌃V) with visible UI elements
  - Verify recommendation references screenshot content
- [x] **Validation**: Gemini successfully analyzes screenshot context
- [x] **Success Criteria**: AI response mentions visual elements (e.g., "I see code on screen")

### 5. Error handling verification
- [x] **Action**: Test edge cases
  - Invalid base64 data
  - API key issues
  - Network failures
- [x] **Validation**: Graceful fallback to text-only mode
- [x] **Success Criteria**: User sees meaningful error messages

---

## Dependencies

- Google GenerativeAI SDK (already integrated)
- No blocking dependencies

---

## Estimated Effort

- Implementation: 30 minutes
- Testing: 15 minutes
- Total: ~45 minutes
