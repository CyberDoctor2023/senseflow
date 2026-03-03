# Spec: Keychain Identifiers

## MODIFIED Requirements

### Requirement: KeychainManager MUST use consistent service identifiers
KeychainManager SHALL use `com.senseflow.*` identifiers consistently across all services and queues, with automatic migration from old `com.aiclipboard.*` identifiers.

#### Scenario: Fresh install uses new identifiers only

**Given** a user installs SenseFlow for the first time
**When** the app launches and KeychainManager initializes
**Then** the master key is stored at service identifier `com.senseflow.masterkey`
**And** no keychain entries exist at `com.aiclipboard.*` identifiers
**And** all DispatchQueue labels use `com.senseflow.*` prefix

#### Scenario: Existing user upgrades with automatic migration

**Given** a user has SenseFlow v0.4.1 installed with master key at `com.aiclipboard.masterkey`
**When** the user upgrades to v0.5 and launches the app
**Then** KeychainManager detects the old master key
**And** copies the master key to `com.senseflow.masterkey`
**And** deletes the old keychain entry at `com.aiclipboard.masterkey`
**And** sets migration flag `keychain_migration_completed_v2`
**And** all API keys remain accessible without re-entry

#### Scenario: Migration is idempotent

**Given** a user has already migrated to v0.5
**When** the app launches again
**Then** KeychainManager checks the migration flag v2
**And** skips migration (no old data to migrate)
**And** no keychain access occurs for migration

#### Scenario: Migration handles missing old data gracefully

**Given** a user upgrades to v0.5 but has no old keychain data
**When** the app launches and migration runs
**Then** KeychainManager checks for old master key
**And** finds no data at `com.aiclipboard.masterkey`
**And** skips migration without errors
**And** logs "No old master key found, skipping migration"

---

## ADDED Requirements

### Requirement: Legacy identifiers SHALL be preserved for migration only
KeychainManager MUST maintain legacy identifier constants (`com.aiclipboard.*`) for backward compatibility during migration, but SHALL never write new data to old identifiers.

#### Scenario: Legacy identifiers are read-only

**Given** KeychainManager has legacy identifier constants
**When** migration runs
**Then** old identifiers are used only for reading existing data
**And** new data is always written to `com.senseflow.*` identifiers
**And** old keychain entries are deleted after successful migration

#### Scenario: Migration logs are detailed for debugging

**Given** migration is running
**When** each migration step executes
**Then** detailed logs are printed to console
**And** logs include: "Found old master key", "Master key migrated", "Old master key deleted"
**And** logs use emoji prefixes for visibility (🔄 for migration, ✅ for success, ❌ for errors)

---

## MODIFIED Requirements

### Requirement: All service queues MUST use consistent naming
All DispatchQueue labels SHALL use `com.senseflow.*` prefix consistently across KeychainManager and all service classes.

#### Scenario: KeychainManager queues use new identifiers

**Given** KeychainManager initializes
**When** DispatchQueues are created
**Then** `cacheQueue` uses label `com.senseflow.keychain.cache`
**And** `masterKeyQueue` uses label `com.senseflow.keychain.masterkey`

#### Scenario: Service queues use new identifiers

**Given** LangfusePromptService or LangfuseSyncService initializes
**When** DispatchQueues are created
**Then** `cacheQueue` uses label `com.senseflow.promptcache`

---

## Implementation Notes

### Constants to Update

```swift
// KeychainManager.swift
private let keychainService = "com.senseflow.masterkey"  // NEW
private let legacyKeychainService = "com.aiclipboard.apikeys"  // existing
private let legacyMasterKeyService = "com.aiclipboard.masterkey"  // NEW (read-only)

private let cacheQueue = DispatchQueue(label: "com.senseflow.keychain.cache")
private let masterKeyQueue = DispatchQueue(label: "com.senseflow.keychain.masterkey")

private let migrationKey = "keychain_migration_completed_v2"  // bumped version
```

### Migration Method Signature

```swift
/// Migrate master key from old service identifier to new one
/// Called once on first launch after upgrade
private func migrateMasterKeyIfNeeded()
```

### Migration Order

1. `migrateMasterKeyIfNeeded()` - migrate master key first
2. `migrateFromLegacyKeychainIfNeeded()` - migrate API keys (existing)
3. Set migration flag v2

### Error Handling

- If old key read fails: skip migration, log warning
- If new key save fails: keep old key, log error, don't delete old entry
- If old key delete fails: log warning but continue (cleanup can happen later)

### Testing Checklist

- [ ] Fresh install: no old data, new identifiers used
- [ ] Upgrade with old master key: migration succeeds, old entry deleted
- [ ] Upgrade without old data: migration skipped gracefully
- [ ] Multiple launches: migration runs once only (idempotent)
- [ ] API keys remain accessible after migration
