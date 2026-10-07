# Implementation Tasks

## Phase 1: Foundation (Week 1)

### 1. Extend Data Model
- [ ] Add Langfuse fields to PromptTool model (langfuseVersion, langfuseLabels, langfuseName, lastSyncedAt)
- [ ] Create database migration script for new fields
- [ ] Add ToolSource.langfuse enum case
- [ ] Update DatabaseManager with Langfuse-specific queries
- [ ] Write unit tests for model changes
- **Validation**: Run migration on test database, verify schema

### 2. Implement LangfusePromptSyncService
- [ ] Create LangfusePromptSyncService.swift with singleton pattern
- [ ] Implement fetchPrompts() using existing LangfusePromptService
- [ ] Add memory cache with 60s TTL
- [ ] Implement sync() method with conflict resolution
- [ ] Add error handling and retry logic
- [ ] Write unit tests for sync logic
- **Validation**: Mock API calls, verify cache behavior

### 3. Integrate Keychain for Credentials
- [ ] Create KeychainManager extension for Langfuse keys
- [ ] Add getLangfusePublicKey() and getLangfuseSecretKey() methods
- [ ] Implement setLangfuseKeys() with secure storage
- [ ] Add credential validation on app launch
- [ ] Handle missing/invalid credentials gracefully
- **Validation**: Store and retrieve test credentials, verify encryption

## Phase 2: Sync Mechanism (Week 2)

### 4. Implement Background Sync
- [ ] Add Timer-based polling (5 minute interval)
- [ ] Implement sync on app launch
- [ ] Add manual sync trigger method
- [ ] Handle app background/foreground transitions
- [ ] Add sync status tracking (syncing, success, error)
- [ ] Implement exponential backoff on failures
- **Validation**: Monitor sync logs, verify timing

### 5. Cache Management
- [ ] Implement three-tier cache (memory → SQLite → API)
- [ ] Add cache invalidation logic
- [ ] Implement offline mode detection
- [ ] Add fallback to last known good state
- [ ] Track cache hit/miss metrics
- **Validation**: Test offline mode, verify cache hits

### 6. Conflict Resolution
- [ ] Implement remote-wins strategy
- [ ] Detect local modifications to Langfuse prompts
- [ ] Add conflict notification to user
- [ ] Preserve local custom prompts
- [ ] Add sync history tracking
- **Validation**: Create conflicts, verify resolution

## Phase 3: UI Integration (Week 3)

### 7. Settings UI for Langfuse
- [ ] Add Langfuse section to PromptToolsSettingsView
- [ ] Create credential input fields (public key, secret key)
- [ ] Add "Test Connection" button
- [ ] Show sync status (last sync time, next sync)
- [ ] Add manual "Sync Now" button
- [ ] Display sync errors with actionable messages
- **Validation**: Configure credentials, trigger sync

### 8. Prompt List UI Updates
- [ ] Add source badge (Langfuse/Local/Community)
- [ ] Show version number for Langfuse prompts
- [ ] Display last sync time
- [ ] Add sync status indicator (synced/pending/error)
- [ ] Show labels (production/staging) as tags
- [ ] Add filter by source
- **Validation**: Visual inspection, verify all states

### 9. Prompt Editor UI Updates
- [ ] Disable editing for Langfuse prompts
- [ ] Show "Managed by Langfuse" notice
- [ ] Add "View in Langfuse" link
- [ ] Keep editing enabled for local prompts
- [ ] Add "Convert to Local" option for Langfuse prompts
- **Validation**: Try editing both types, verify restrictions

## Phase 4: Migration & Polish (Week 4)

### 10. Data Migration
- [ ] Create migration script for existing prompts
- [ ] Map built-in prompts to Langfuse names
- [ ] Preserve user customizations
- [ ] Add rollback capability
- [ ] Test migration on production-like data
- **Validation**: Migrate test database, verify data integrity

### 11. Error Handling & Logging
- [ ] Add comprehensive error messages
- [ ] Implement retry logic with backoff
- [ ] Add sync failure notifications
- [ ] Log sync operations for debugging
- [ ] Add telemetry for sync metrics
- **Validation**: Trigger errors, verify messages

### 12. Performance Optimization
- [ ] Optimize database queries for sync
- [ ] Implement batch operations
- [ ] Add request deduplication
- [ ] Profile memory usage
- [ ] Measure sync latency
- **Validation**: Run performance tests, verify < 2s sync

### 13. Documentation
- [ ] Update SPEC.md with Langfuse integration
- [ ] Create user guide for Langfuse setup
- [ ] Document API usage and rate limits
- [ ] Add troubleshooting guide
- [ ] Update README with new features
- **Validation**: Follow docs to set up from scratch

### 14. Testing & QA
- [ ] Test offline mode thoroughly
- [ ] Test with slow/unreliable network
- [ ] Test with invalid credentials
- [ ] Test with large number of prompts (100+)
- [ ] Test migration from v0.4 to v0.5
- [ ] Verify backward compatibility
- **Validation**: All test scenarios pass

## Dependencies

- **Blocks**: None (can start immediately)
- **Blocked By**: None
- **Parallel Work**: Tasks 1-3 can run in parallel, Tasks 7-9 can run in parallel

## Validation Checklist

- [ ] All prompts sync within 5 minutes of Langfuse update
- [ ] App works offline with cached prompts
- [ ] No data loss during migration
- [ ] Sync operation completes in < 2 seconds
- [ ] Memory cache hit rate > 90%
- [ ] UI shows accurate sync status
- [ ] Error messages are actionable
- [ ] Credentials stored securely in Keychain
- [ ] Background sync doesn't block UI
- [ ] Manual sync provides immediate feedback
