# Proposal: Batch Keychain Reads on Settings Load

## What

Reduce Keychain authorization prompts from 3 to 1 when opening Settings by batching all Keychain read operations into a single authorization request.

## Why

**Current Problem:**
- Opening Settings window triggers 3 separate Keychain read operations:
  1. `loadAPIKey()` → reads current AI service API key
  2. `loadLangfuseConfig()` → reads Langfuse Public Key
  3. `loadLangfuseConfig()` → reads Langfuse Secret Key
- Each read triggers a separate authorization prompt in Debug builds (ad-hoc code signing)
- Phase 3 only fixed **save** operations (3→1), but **read** operations still cause 3 prompts

**User Impact:**
- Developers see 3 authorization dialogs every time they open Settings after a rebuild
- Interrupts workflow and creates frustration
- Makes the app feel unpolished during development

**Business Value:**
- Improved developer experience
- Consistent with Phase 3's batch save approach
- Completes the Keychain authorization optimization story

## Success Criteria

1. Opening Settings window triggers maximum 1 Keychain authorization prompt (on first read)
2. Subsequent reads within the same session do not trigger additional prompts
3. All 3 keys are loaded correctly and displayed in Settings UI
4. No performance regression (reads should complete quickly)

## Out of Scope

- Eliminating prompts entirely (requires SecAccess API, complex and incompatible with iCloud Keychain)
- Changing code signing configuration
- Modifying KeychainManager's internal caching (already works correctly)

## Dependencies

- None (builds on existing KeychainManager implementation)

## Risks

- **Low risk**: Simple refactoring of existing read operations
- **Potential issue**: If one key read fails, all keys might fail → mitigated by individual error handling

## Alternatives Considered

1. **Lazy loading (delay reads until user interacts)**
   - Pros: No prompts until user actually needs the data
   - Cons: Complicates UI state management, keys might not display immediately
   - Decision: Rejected - batch read is simpler and more predictable

2. **Cache keys in UserDefaults (unencrypted)**
   - Pros: No Keychain prompts
   - Cons: Security risk - API keys stored in plaintext
   - Decision: Rejected - violates security best practices

3. **Do nothing**
   - Pros: No work required
   - Cons: Poor developer experience, inconsistent with Phase 3
   - Decision: Rejected - completing the optimization is valuable
