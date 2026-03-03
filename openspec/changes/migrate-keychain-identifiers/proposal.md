# Proposal: Migrate Keychain Identifiers

## Why

The project was renamed from AIClipboard to SenseFlow, but internal keychain identifiers still use the old `com.aiclipboard.*` naming. This creates:

1. **Brand inconsistency** - Bundle identifier is `com.senseflow.SenseFlow` but keychain uses `com.aiclipboard.*`
2. **Developer confusion** - Debugging keychain issues shows outdated identifiers
3. **Technical debt** - Will be harder to fix later as more users accumulate data

Migrating now ensures clean branding and prevents future migration complexity.

## Problem Statement

The project has been renamed from AIClipboard to SenseFlow, but keychain service identifiers and internal queue labels still use the old `com.aiclipboard.*` naming convention. This creates inconsistency and confusion:

**Current State:**
- Bundle identifier: `com.senseflow.SenseFlow` ✅
- Keychain master key service: `com.aiclipboard.masterkey` ❌
- Legacy keychain service: `com.aiclipboard.apikeys` ❌
- Queue labels: `com.aiclipboard.keychain.*` ❌
- Other service queues: `com.aiclipboard.promptcache` ❌

**Impact:**
- Brand inconsistency (internal identifiers don't match product name)
- Confusion for developers debugging keychain issues
- Technical debt that will be harder to fix later

## Proposed Solution

Migrate all internal identifiers from `com.aiclipboard.*` to `com.senseflow.*` with automatic data migration to ensure zero data loss for existing users.

### Migration Strategy

1. **Update KeychainManager identifiers:**
   - `com.aiclipboard.masterkey` → `com.senseflow.masterkey`
   - Keep `com.aiclipboard.apikeys` as legacy identifier (already used for migration)
   - Add `com.aiclipboard.masterkey` as second legacy identifier

2. **Update queue labels:**
   - `com.aiclipboard.keychain.cache` → `com.senseflow.keychain.cache`
   - `com.aiclipboard.keychain.masterkey` → `com.senseflow.keychain.masterkey`
   - `com.aiclipboard.promptcache` → `com.senseflow.promptcache`

3. **Automatic migration on first launch:**
   - Check for existing master key at old service identifier
   - Copy to new service identifier
   - Delete old keychain entry after successful migration
   - Use existing migration flag mechanism

### Backward Compatibility

- Existing users: Automatic migration on first launch after update
- New users: Use new identifiers from the start
- No user action required
- No data loss

## Scope

**In Scope:**
- KeychainManager service identifiers
- All DispatchQueue labels using `com.aiclipboard.*`
- Migration logic for master key
- Update migration flag to v2

**Out of Scope:**
- Bundle identifier (already updated to `com.senseflow.SenseFlow`)
- UserDefaults keys (encrypted_* prefix is identifier-agnostic)
- Database schema (no keychain identifiers stored)

## Success Criteria

1. All `com.aiclipboard.*` identifiers replaced with `com.senseflow.*`
2. Existing users can upgrade without re-entering API keys
3. Migration completes silently on first launch
4. No keychain authorization prompts during migration
5. All tests pass after migration

## Risks & Mitigation

**Risk:** Migration fails and user loses API keys
**Mitigation:**
- Test migration logic thoroughly
- Keep old keychain entries until migration confirmed successful
- Add detailed logging for debugging

**Risk:** Multiple authorization prompts during migration
**Mitigation:**
- Migration reads old key once, writes new key once (2 prompts max)
- Use existing cached master key if available (0-1 prompts)

## Related Work

- ADR #10: Keychain single-key encryption strategy (Deck mode)
- Existing migration: `com.aiclipboard.apikeys` → encrypted UserDefaults
- Migration flag: `keychain_migration_completed_v1`
