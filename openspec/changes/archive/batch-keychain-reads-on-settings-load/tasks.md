# Tasks: Batch Keychain Reads on Settings Load

## Implementation Tasks

### Phase 1: KeychainManager Enhancement (1 task)

- [x] **Add batch read method to KeychainManager**
   - Add `getAllSettingsKeys()` method that returns all keys in a single call
   - Method should read: current service API key, Langfuse public key, Langfuse secret key
   - Return a struct with all keys (use optionals for missing keys)
   - Ensure reads happen synchronously to share authorization context
   - **Validation**: Unit test that method returns correct keys

### Phase 2: Settings View Refactoring (2 tasks)

- [x] **Refactor PromptToolsSettingsView to use batch read**
   - Replace individual `loadAPIKey()` and `loadLangfuseConfig()` calls with single batch read
   - Update `onAppear` to call new batch read method once
   - Populate all state variables from batch read result
   - **Validation**: Manual test - open Settings, verify only 1 authorization prompt

- [x] **Update LangfuseSyncService.getConfiguration()**
   - Refactor to accept pre-loaded keys as parameters (optional)
   - Keep existing behavior as fallback (read from Keychain if not provided)
   - **Validation**: Verify existing callers still work correctly

### Phase 3: Testing & Documentation (2 tasks)

- [ ] **Add integration test**
   - Test that opening Settings triggers only 1 Keychain read authorization
   - Test that all keys are loaded correctly
   - Test edge case: some keys missing (should not fail)
   - **Validation**: All tests pass

- [x] **Update documentation**
   - Add comment in KeychainManager explaining batch read pattern
   - Update DECISIONS.md with rationale for batch reads
   - Link to Phase 3 (batch save) for consistency
   - **Validation**: Documentation review

## Task Dependencies

```
1 (KeychainManager) → 2 (Settings View) → 4 (Testing)
                    → 3 (LangfuseSyncService) → 4 (Testing)
                                              → 5 (Documentation)
```

## Estimated Effort

- **Total**: 5 tasks
- **Critical path**: Tasks 1 → 2 → 4
- **Parallelizable**: Tasks 3 and 5 can be done independently after Task 2

## Success Metrics

- ✅ Opening Settings triggers maximum 1 authorization prompt
- ✅ All 3 keys load correctly
- ✅ No performance regression (< 100ms to load all keys)
- ✅ Unit tests pass
- ✅ Integration tests pass
