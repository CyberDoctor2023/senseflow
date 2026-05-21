# Change: Add Codex Browser Auth for AI Service

## Why
Users should be able to use the Codex/ChatGPT browser login flow for SenseFlow AI service configuration instead of pasting an OpenAI API key.

## What Changes
- Add a `Codex` AI service option backed by SenseFlow-owned Codex OAuth state.
- Add Settings controls to launch a Codex browser OAuth login, refresh login status, and sign out.
- Store Codex access/refresh credentials only in SenseFlow's Keychain item.
- Use Codex ChatGPT bearer credentials from SenseFlow Keychain for Codex-backed text generation.
- Send Codex Responses requests with message-array `input` content rather than a bare string.

## Impact
- Affected specs: `ai-service-config`
- Affected code: `AIServiceType`, `AIService`, `KeychainManager`, `UserAPISettingsServiceAdapter`, `PromptToolsSettingsView`, settings strings

## Non-Goals
- Do not display, persist, or copy Codex access/refresh tokens into SenseFlow settings.
- Do not infer SenseFlow login state from the user's global Codex CLI `~/.codex/auth.json`.
- Do not replace existing API-key providers.
- Do not add Codex vision support in this change.

## Completion Conditions
- Settings exposes a Codex service option with browser login and status refresh.
- Codex service does not require manual API key input.
- Fresh installs show Codex as logged out until the user completes SenseFlow's own browser login.
- Prompt Tools connection test can attempt a Codex-authenticated text request when Codex is logged in.
- Codex test requests no longer fail with `Input must be a list`.
- Existing OpenAI/Gemini/DeepSeek/OpenRouter/Ollama paths remain unchanged.

## Validation Plan
- Static review for all `AIServiceType.allCases` switch sites.
- Run OpenSpec validation for the new change.
- Do not run full Xcode build unless explicitly requested by the user, per project rule.
