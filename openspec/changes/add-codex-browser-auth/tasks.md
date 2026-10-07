# Tasks: Add Codex Browser Auth

## 1. Spec and References
- [x] 1.1 Record current Codex auth documentation and local CLI behavior in `docs/refs.md`
- [x] 1.2 Add OpenSpec delta for Codex auth settings behavior
- [x] 1.3 Validate OpenSpec change
- [x] 1.4 Compare Lifenotes Codex Auth implementation and record request-shape correction

## 2. Authentication Model
- [x] 2.1 Add `codex` to `AIServiceType`
- [x] 2.2 Add a Codex auth status/credential reader that redacts token details from UI
- [x] 2.3 Add a browser-login launcher using Codex OAuth PKCE flow
- [x] 2.4 Replace global CLI auth-file status with SenseFlow-owned OAuth + Keychain
- [x] 2.5 Add explicit Codex sign-out for SenseFlow credentials

## 3. AI Service Integration
- [x] 3.1 Route Codex text generation through Codex-authenticated Responses endpoint
- [x] 3.2 Keep Codex out of API-key storage requirements
- [x] 3.3 Keep unsupported Codex vision calls on text fallback
- [x] 3.4 Send Codex Responses `input` as a message list with `input_text` content

## 4. Settings UI
- [x] 4.1 Hide API Key field for Codex
- [x] 4.2 Show Codex login status and login/refresh buttons
- [x] 4.3 Preserve existing save/test behavior for API-key providers
- [x] 4.4 Show logged-out state on machines that only have CLI Codex auth

## 5. Verification
- [x] 5.1 Review switch exhaustiveness and request logging payloads
- [x] 5.2 Run lightweight syntax/static checks that do not require full build
- [x] 5.3 Run OpenSpec validation after auth/request-shape fix
- [x] 5.4 Run user-requested Xcode build before publishing the fix
