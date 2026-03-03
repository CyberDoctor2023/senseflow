# Proposal: Add Gemini Vision API Support

**Change ID**: `add-gemini-vision-support`
**Status**: Draft
**Created**: 2026-01-22

---

## Problem Statement

Currently, Smart AI Recommendation's Vision API (screenshot-based context) only works with OpenAI. When users select Gemini or other AI services, the system falls back to text-only mode, even though Gemini has native Vision API support.

**Current Behavior**:
- OpenAI: Vision API supported ✅
- Gemini: Falls back to text-only (Vision API exists but not implemented) ❌
- Claude/DeepSeek/OpenRouter: Falls back to text-only ❌

**User Impact**:
- Gemini users cannot leverage screenshot context for smarter tool recommendations
- Settings UI warns "Vision feature requires OpenAI" even though Gemini supports it

---

## Proposed Solution

Implement Gemini Vision API support in `GeminiService.generateWithImage()` using the Google GenerativeAI SDK's multimodal capabilities.

**Key Changes**:
1. Replace stub implementation with real Gemini Vision API call
2. Convert base64 image to `InlineDataPart` format required by Gemini
3. Update UI warnings to reflect actual Vision API support per service

**Vision API Support Matrix** (after implementation):
- OpenAI: ✅ Supported (existing)
- **Gemini: ✅ Supported (NEW)**
- Claude: ❌ Not supported (API limitation)
- DeepSeek: ❌ Not supported (API limitation)
- OpenRouter: ⚠️ Depends on underlying model
- Ollama: ⚠️ Depends on model capabilities

---

## Scope

**Affected Files**:
- `SenseFlow/Services/GeminiService.swift` - Implement Vision API
- `SenseFlow/Services/AIService.swift` - Update service capability checks
- `SenseFlow/Views/Settings/PromptToolsSettingsView.swift` - Update UI warnings

**Specs**:
- `ai-vision-api` (NEW): Define Vision API requirements and service capabilities

---

## Technical Design

### Gemini Vision API Format

Based on Context7 research (https://ai.google.dev/gemini-api/docs/image-understanding):

```swift
// Input format required by Gemini SDK
let imagePart = InlineDataPart(
    data: Data(base64Encoded: imageBase64)!,
    mimeType: "image/jpeg"
)

let textPart = try ModelContent.Part.text(userPrompt)

let content = [ModelContent(
    role: "user",
    parts: [textPart, imagePart]
)]

let response = try await model.generateContent(content)
```

**Key Differences from OpenAI**:
- Gemini uses `InlineDataPart` with raw `Data`
- OpenAI uses data URL format: `data:image/jpeg;base64,...`
- Both support mixing text and images in a single request

### Service Capability Detection

Add capability checking to `AIServiceType`:

```swift
extension AIServiceType {
    var supportsVision: Bool {
        switch self {
        case .openai, .gemini: return true
        case .claude, .deepseek, .ollama: return false
        case .openrouter: return true // Depends on model
        }
    }
}
```

---

## Validation

### Manual Testing:
1. Select Gemini as AI service
2. Configure Gemini API key
3. Trigger Smart AI Recommendation (⌘⌃V)
4. Verify screenshot is included in context
5. Check AI response references visual elements

### Expected Behavior:
- Gemini receives both text prompt AND screenshot
- Recommendation considers visual context (e.g., detects code in screenshot)
- No "Vision requires OpenAI" warning for Gemini users

---

## Risks & Considerations

**Low Risk**:
- Self-contained change in `GeminiService`
- Existing OpenAI Vision implementation provides reference
- Graceful fallback to text-only if Vision fails

**API Cost**:
- Gemini Vision API may have different pricing than text-only
- Users should be aware of cost implications (document in settings)

**Dependencies**:
- Requires Google GenerativeAI SDK (already integrated)
- No changes to screenshot capture logic

---

## Related Changes

- Cross-references `integrate-smart-settings` for UI warnings
- Builds on `add-smart-context-aware-tools` Vision architecture

---

## Out of Scope

- Adding Vision support for Claude/DeepSeek (not supported by their APIs)
- Implementing Vision for Ollama (requires per-model capability detection)
- OpenRouter Vision (depends on underlying model, complex to implement)
