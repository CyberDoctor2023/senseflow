# Design: Migrate Keychain Identifiers

## Overview

This change updates all internal identifiers from the legacy `com.aiclipboard.*` naming to the current `com.senseflow.*` branding, with automatic data migration to ensure zero data loss.

## Architecture

### Current Architecture (v0.4.1)

```
KeychainManager
├── Master Key Storage
│   └── Service: "com.aiclipboard.masterkey" ❌
├── Legacy API Keys (for migration)
│   └── Service: "com.aiclipboard.apikeys" ✅ (kept for backward compat)
├── Encrypted Storage (UserDefaults)
│   └── Keys: "encrypted_openai_api_key", etc. ✅ (identifier-agnostic)
└── Migration Flag
    └── "keychain_migration_completed_v1"
```

### Target Architecture (v0.5)

```
KeychainManager
├── Master Key Storage
│   └── Service: "com.senseflow.masterkey" ✅
├── Legacy Identifiers (for migration only)
│   ├── "com.aiclipboard.apikeys" (Phase 1 migration)
│   └── "com.aiclipboard.masterkey" (Phase 2 migration - NEW)
├── Encrypted Storage (UserDefaults)
│   └── Keys: "encrypted_openai_api_key", etc. ✅ (unchanged)
└── Migration Flag
    └── "keychain_migration_completed_v2" (bumped version)
```

## Migration Flow

### Scenario 1: Fresh Install (New User)

```
1. App launches
2. KeychainManager.init()
3. Check migration flag v2 → not set
4. migrateMasterKeyIfNeeded()
   - Check old service "com.aiclipboard.masterkey" → not found
   - Skip migration
5. migrateFromLegacyKeychainIfNeeded()
   - Check old service "com.aiclipboard.apikeys" → not found
   - Skip migration
6. Set migration flag v2
7. User adds API keys → saved to new identifiers
```

**Result:** Clean install with new identifiers only.

### Scenario 2: Upgrade from v0.4.1 (Existing User)

```
1. App launches (user has data at "com.aiclipboard.masterkey")
2. KeychainManager.init()
3. Check migration flag v2 → not set (only v1 exists)
4. migrateMasterKeyIfNeeded()
   - Check old service "com.aiclipboard.masterkey" → FOUND
   - Read master key data (1 keychain access)
   - Save to new service "com.senseflow.masterkey" (1 keychain access)
   - Delete old entry
   - Log: "✅ Master key migrated to com.senseflow.masterkey"
5. migrateFromLegacyKeychainIfNeeded()
   - Check old service "com.aiclipboard.apikeys" → not found (already migrated in v0.4.1)
   - Skip migration
6. Set migration flag v2
7. User's API keys remain accessible (encrypted in UserDefaults, decrypted with migrated master key)
```

**Result:** Seamless upgrade, 2 keychain prompts max (read old + write new).

### Scenario 3: Upgrade from v0.3 (Pre-Deck User)

```
1. App launches (user has data at both "com.aiclipboard.apikeys" and "com.aiclipboard.masterkey")
2. KeychainManager.init()
3. Check migration flag v2 → not set
4. migrateMasterKeyIfNeeded()
   - Migrate master key (as in Scenario 2)
5. migrateFromLegacyKeychainIfNeeded()
   - Check old service "com.aiclipboard.apikeys" → FOUND
   - Migrate API keys to encrypted UserDefaults (existing logic)
   - Delete old entries
6. Set migration flag v2
7. All data migrated to new architecture
```

**Result:** Full migration from old architecture to new identifiers.

## Implementation Details

### Code Changes

#### KeychainManager.swift

```swift
// Constants (updated)
private let keychainService = "com.senseflow.masterkey"  // NEW
private let legacyKeychainService = "com.aiclipboard.apikeys"  // existing
private let legacyMasterKeyService = "com.aiclipboard.masterkey"  // NEW

private let cacheQueue = DispatchQueue(label: "com.senseflow.keychain.cache")  // NEW
private let masterKeyQueue = DispatchQueue(label: "com.senseflow.keychain.masterkey")  // NEW

// Migration flag (updated)
private let migrationKey = "keychain_migration_completed_v2"  // NEW

// New migration method
private func migrateMasterKeyIfNeeded() {
    // Check for old master key
    if let oldKeyData = getMasterKeyFromKeychain(service: legacyMasterKeyService) {
        print("🔄 [Migration] Found old master key, migrating...")

        // Save to new service
        if saveMasterKeyToKeychain(oldKeyData, service: keychainService) {
            print("✅ [Migration] Master key migrated to \(keychainService)")

            // Delete old entry
            deleteFromKeychain(service: legacyMasterKeyService, account: keychainAccount)
            print("🗑️ [Migration] Old master key deleted")
        } else {
            print("❌ [Migration] Failed to migrate master key")
        }
    } else {
        print("ℹ️ [Migration] No old master key found, skipping migration")
    }
}

// Updated init
private init() {
    // Run master key migration first
    migrateMasterKeyIfNeeded()

    // Then run API keys migration (existing)
    migrateFromLegacyKeychainIfNeeded()
}
```

#### Other Services

```swift
// LangfusePromptService.swift
private let cacheQueue = DispatchQueue(label: "com.senseflow.promptcache")  // NEW

// LangfuseSyncService.swift
private let cacheQueue = DispatchQueue(label: "com.senseflow.promptcache")  // NEW
```

### Migration Safety

**Idempotency:**
- Migration can run multiple times safely
- Checks for old data before attempting migration
- Checks for new data to avoid overwriting

**Error Handling:**
- If migration fails, old data remains intact
- User can retry by deleting migration flag
- Detailed logging for debugging

**Rollback:**
- If needed, user can manually restore old keychain entries
- Encrypted UserDefaults data is identifier-agnostic (no rollback needed)

## Testing Strategy

### Unit Tests (Manual)

1. **Test fresh install:**
   - Delete app and keychain entries
   - Launch app
   - Verify new identifiers used

2. **Test upgrade with old master key:**
   - Manually create old keychain entry
   - Launch app
   - Verify migration logs
   - Verify new entry exists, old entry deleted

3. **Test upgrade with no old data:**
   - Launch app with v1 flag set
   - Verify migration skipped gracefully

### Integration Tests

1. **End-to-end flow:**
   - Migrate from old identifiers
   - Add new API key
   - Verify key accessible
   - Restart app
   - Verify key still accessible

## Rollout Plan

1. **Development:** Test migration locally
2. **Internal Testing:** Verify on clean and upgrade scenarios
3. **Release:** Include in v0.5 release notes
4. **Monitoring:** Check logs for migration issues

## Alternative Approaches Considered

### Alternative 1: Keep Old Identifiers
**Pros:** No migration needed, zero risk
**Cons:** Technical debt, brand inconsistency
**Decision:** Rejected - better to fix now than later

### Alternative 2: Manual Migration (User Action Required)
**Pros:** Simpler implementation
**Cons:** Poor user experience, data loss risk
**Decision:** Rejected - automatic migration is better UX

### Alternative 3: Dual Support (Read from Both)
**Pros:** No migration needed, backward compatible
**Cons:** Complexity, never cleans up old data
**Decision:** Rejected - migration is cleaner long-term

## Open Questions

None - design is straightforward and follows existing migration patterns.
