# Change: Add Codex Browser Auth for AI Service

## Why
Users should be able to use the Codex/ChatGPT browser login flow for SenseFlow AI service configuration instead of pasting an OpenAI API key.

## What Changes
- Add a `Codex` AI service option backed by the local Codex auth state.
- Add Settings controls to launch the official `codex login` browser flow and refresh login status.
- Use Codex ChatGPT bearer credentials from the local Codex auth file for Codex-backed text generation.

## Impact
- Affected specs: `ai-service-config`
- Affected code: `AIServiceType`, `AIService`, `KeychainManager`, `UserAPISettingsServiceAdapter`, `PromptToolsSettingsView`, settings strings

## Non-Goals
- Do not display, persist, or copy Codex access/refresh tokens into SenseFlow settings.
- Do not replace existing API-key providers.
- Do not add Codex vision support in this change.

## Completion Conditions
- Settings exposes a Codex service option with browser login and status refresh.
- Codex service does not require manual API key input.
- Prompt Tools connection test can attempt a Codex-authenticated text request when Codex is logged in.
- Existing OpenAI/Gemini/DeepSeek/OpenRouter/Ollama paths remain unchanged.

## Validation Plan
- Static review for all `AIServiceType.allCases` switch sites.
- Run OpenSpec validation for the new change.
- Do not run full Xcode build unless explicitly requested by the user, per project rule.
