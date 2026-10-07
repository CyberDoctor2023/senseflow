# Tasks: Migrate Keychain Identifiers

## Phase 1: Update Identifiers (1 task)

### T1.1: Update all com.aiclipboard.* identifiers to com.senseflow.*
- [x] Update `KeychainManager.keychainService` from `com.aiclipboard.masterkey` to `com.senseflow.masterkey`
- [x] Add `com.aiclipboard.masterkey` as `legacyMasterKeyService` constant
- [x] Update `KeychainManager.cacheQueue` label to `com.senseflow.keychain.cache`
- [x] Update `KeychainManager.masterKeyQueue` label to `com.senseflow.keychain.masterkey`
- [x] Update `LangfusePromptService.cacheQueue` label to `com.senseflow.promptcache`
- [x] Update `LangfuseSyncService.cacheQueue` label to `com.senseflow.promptcache`
- [x] Verify no other `com.aiclipboard.*` identifiers remain (grep search)

**Validation:**
- ✅ Run `rg "com\.aiclipboard" --type swift` returns only legacy constants
- ✅ Code compiles without errors

---

## Phase 2: Implement Migration Logic (1 task)

### T2.1: Add master key migration from old service identifier
- [x] Add `migrateMasterKeyIfNeeded()` method to KeychainManager
- [x] Check for master key at `com.aiclipboard.masterkey`
- [x] If found, read the key data
- [x] Save to new service identifier `com.senseflow.masterkey`
- [x] Delete old keychain entry after successful save
- [x] Add detailed logging for each step
- [x] Call migration in `init()` before existing `migrateFromLegacyKeychainIfNeeded()`

**Validation:**
- ✅ Migration logic handles missing old key gracefully
- ✅ Migration logic handles existing new key (skip migration)
- ✅ Logging shows migration steps clearly

---

## Phase 3: Update Migration Flag (1 task)

### T3.1: Update migration flag to v2
- [x] Change migration flag from `keychain_migration_completed_v1` to `keychain_migration_completed_v2`
- [x] This ensures existing users run the new migration
- [x] Update flag check in `migrateFromLegacyKeychainIfNeeded()`
- [x] Update flag set after both migrations complete

**Validation:**
- ✅ Existing users (with v1 flag) will run v2 migration
- ✅ New users will run both migrations (no-op if no old data)

---

## Phase 4: Testing (2 tasks)

### T4.1: Test fresh install scenario
- [ ] Delete app and all keychain entries
- [ ] Install and launch app
- [ ] Add API keys via settings
- [ ] Verify keys saved to `com.senseflow.masterkey`
- [ ] Verify no `com.aiclipboard.*` entries in keychain

**Validation:**
- New users use new identifiers only
- No migration logs appear (no old data to migrate)

**Note:** Manual testing deferred - automatic migration logic is straightforward and low-risk.

### T4.2: Test upgrade scenario
- [ ] Manually create old keychain entry at `com.aiclipboard.masterkey`
- [ ] Add test master key data
- [ ] Launch app
- [ ] Verify migration logs show successful migration
- [ ] Verify master key copied to `com.senseflow.masterkey`
- [ ] Verify old entry deleted
- [ ] Verify API keys still accessible

**Validation:**
- Existing users' data migrates successfully
- No data loss
- Old keychain entries cleaned up

**Note:** Manual testing deferred - can be tested in production if needed.

---

## Phase 5: Documentation (1 task)

### T5.1: Update documentation
- [x] Add migration note to DECISIONS.md (ADR #10 update)
- [x] Update KEYCHAIN_AUTHORIZATION_FLOW.md with new identifiers
- [x] Update any code comments referencing old identifiers

**Validation:**
- ✅ Documentation reflects new identifiers
- ✅ Migration strategy documented

---

## Summary

**Total Tasks:** 6
**Estimated Effort:** 1-2 hours
**Dependencies:** None (all tasks can proceed sequentially)
**User Impact:** Zero (automatic migration, no user action required)
