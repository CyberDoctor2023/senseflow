# Spec: Keychain Batch Read

## Overview
Reduce Keychain authorization prompts when loading Settings by batching all read operations into a single authorization request.

## Problem Statement
Current implementation reads each key individually when Settings opens:
1. Current AI service API key → Authorization prompt #1
2. Langfuse Public Key → Authorization prompt #2
3. Langfuse Secret Key → Authorization prompt #3

This occurs in Debug builds because ad-hoc code signing changes with each build, breaking Keychain trust relationships. Each read operation triggers a separate authorization prompt.

## ADDED Requirements

### Requirement: Keychain reads are batched to minimize authorization prompts
KeychainManager MUST provide a batch read method that retrieves all Settings-related keys in a single operation to minimize authorization prompts.

**ID**: `keychain-read-001`
**Priority**: High
**Rationale**: Complements Phase 3's batch save functionality; provides consistent developer experience.

#### Scenario: Batch read retrieves all keys with single authorization
**Given** user has saved API keys and Langfuse keys in Keychain
**When** Settings view calls batch read method
**Then** all keys should be retrieved in a single operation
**And** user should see maximum 1 authorization prompt (on first read)
**And** subsequent reads should not trigger additional prompts

#### Scenario: Batch read handles missing keys gracefully
**Given** some keys are not saved in Keychain
**When** Settings view calls batch read method
**Then** method should return nil for missing keys
**And** method should not fail or throw errors
**And** Settings UI should display empty fields for missing keys

#### Scenario: Batch read returns correct keys for current service
**Given** user has multiple AI service keys saved
**When** Settings view calls batch read with current service type
**Then** method should return the correct API key for that service
**And** method should return Langfuse keys regardless of service type

### Requirement: Settings view loads all keys in single batch operation
PromptToolsSettingsView MUST load all Keychain keys in a single batch operation during onAppear, replacing individual read calls.

**ID**: `keychain-read-002`
**Priority**: High
**Rationale**: Eliminates multiple authorization prompts when opening Settings.

#### Scenario: Settings onAppear triggers single batch read
**Given** user opens Settings window
**When** PromptToolsSettingsView.onAppear executes
**Then** view should call batch read method once
**And** view should populate all key fields from batch result
**And** view should not call individual read methods

#### Scenario: Settings displays all loaded keys correctly
**Given** batch read returns all keys
**When** Settings view renders
**Then** API key field should display current service key
**And** Langfuse Public Key field should display public key
**And** Langfuse Secret Key field should display secret key (masked)

### Requirement: Batch read performance is acceptable
Batch read operation MUST complete within 100ms to avoid UI lag.

**ID**: `keychain-read-003`
**Priority**: Medium
**Rationale**: Settings should open quickly without noticeable delay.

#### Scenario: Batch read completes quickly
**Given** all keys are saved in Keychain
**When** batch read method is called
**Then** operation should complete within 100ms
**And** UI should not show loading indicators
**And** keys should appear immediately in Settings

## MODIFIED Requirements

None - this is a new capability that complements existing keychain-batch-save spec.

## REMOVED Requirements

None - individual read methods remain available for other use cases.

## Implementation Notes

### KeychainManager API

```swift
extension KeychainManager {
    /// Batch read all Settings-related keys
    /// Returns all keys in a single operation to minimize authorization prompts
    struct SettingsKeys {
        let apiKey: String?           // Current service API key
        let langfusePublicKey: String?
        let langfuseSecretKey: String?
    }

    func getAllSettingsKeys(for serviceType: AIServiceType) -> SettingsKeys {
        // Read all keys synchronously to share authorization context
        let apiKey = getAPIKey(for: serviceType)
        let publicKey = getLangfusePublicKey()
        let secretKey = getLangfuseSecretKey()

        return SettingsKeys(
            apiKey: apiKey,
            langfusePublicKey: publicKey,
            langfuseSecretKey: secretKey
        )
    }
}
```

### Settings View Changes

```swift
// Before (3 separate reads):
.onAppear {
    loadTools()
    loadAPIKey()           // Read #1
    loadLangfuseConfig()   // Reads #2 and #3
}

// After (1 batch read):
.onAppear {
    loadTools()
    loadAllKeys()          // Single batch read
}

private func loadAllKeys() {
    let keys = KeychainManager.shared.getAllSettingsKeys(for: selectedService)
    apiKey = keys.apiKey ?? ""
    langfusePublicKey = keys.langfusePublicKey ?? ""
    langfuseSecretKey = keys.langfuseSecretKey ?? ""
    // Load other Langfuse config from UserDefaults
    langfuseEnabled = UserDefaults.standard.bool(forKey: "langfuseSyncEnabled")
    langfuseSyncInterval = UserDefaults.standard.double(forKey: "langfuseSyncInterval")
    langfuseActiveLabel = UserDefaults.standard.string(forKey: "langfuseActiveLabel") ?? "production"
}
```

### Testing Strategy

1. **Unit test**: Verify `getAllSettingsKeys()` returns correct keys
2. **Integration test**: Open Settings, verify only 1 authorization prompt
3. **Edge case test**: Missing keys should not cause failures
4. **Performance test**: Batch read completes within 100ms

## Related Specs

- `keychain-batch-save` (Phase 3) - Batch save operations for consistency
- `settings-ui-layout` - Settings view structure
- `developer-options` - Langfuse keys location in UI

## References

- [Apple: Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- Phase 3 implementation: `fix-settings-ui-and-smart-ai-tool/specs/keychain-batch-save`
- Context7 research: `docs/refs.md` (2026-01-28 entries)
