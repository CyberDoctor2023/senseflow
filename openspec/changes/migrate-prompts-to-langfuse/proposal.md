# Proposal: Migrate Prompts to Langfuse

## Change ID
`migrate-prompts-to-langfuse`

## Summary
Migrate prompt management from local-only storage and prompts.chat community tools to Langfuse Prompt Management, enabling centralized prompt versioning, remote updates, and automatic client-side synchronization.

## Motivation

### Current State
- **Local Storage**: Prompts stored only in local SQLite database
- **Community Tools**: Fetched from prompts.chat API (limited to TEXT type, manual filtering)
- **No Version Control**: No prompt versioning or rollback capability
- **No Remote Updates**: Cannot update prompts without app updates
- **Manual Sync**: Users must manually check for community tool updates

### Problems
1. **Deployment Friction**: Prompt changes require app recompilation and redistribution
2. **No A/B Testing**: Cannot test different prompt versions with different users
3. **Limited Collaboration**: No centralized prompt management for teams
4. **Poor Observability**: No tracking of which prompt version produced which result
5. **Fragmented Sources**: Built-in prompts vs community prompts vs custom prompts

### Desired State
- **Centralized Management**: All prompts managed in Langfuse with version control
- **Remote Updates**: Admin updates prompts in Langfuse UI, clients auto-sync
- **Version Control**: Track prompt versions, labels (production/staging), rollback capability
- **Observability**: Link traces to specific prompt versions for debugging
- **Offline Support**: Local cache ensures functionality without network

## Scope

### In Scope
1. **Langfuse Integration**
   - Fetch prompts from Langfuse API with caching
   - Support version and label-based retrieval
   - Handle authentication and error cases

2. **Sync Mechanism**
   - Background polling for prompt updates (configurable interval)
   - Local cache with TTL-based refresh
   - Conflict resolution (remote vs local changes)

3. **Data Model Updates**
   - Extend PromptTool to store Langfuse metadata (version, labels, updatedAt)
   - Add sync status tracking (synced, pending, conflict)
   - Maintain backward compatibility with existing tools

4. **UI Enhancements**
   - Show prompt source (Langfuse vs local)
   - Display version and last sync time
   - Manual sync trigger in settings
   - Sync status indicators

### Out of Scope
- Webhook-based real-time updates (future enhancement)
- Bi-directional sync (client → Langfuse push)
- Prompt analytics dashboard
- Multi-project support
- Prompt composition/nesting

## Design Approach

### Architecture
```
Langfuse Cloud
    ↓ (REST API)
LangfusePromptSyncService
    ↓ (fetch & cache)
DatabaseManager (local cache)
    ↓ (read)
PromptToolManager
    ↓ (execute)
AIService
```

### Key Components

1. **LangfusePromptSyncService** (new)
   - Replaces ToolUpdateService for Langfuse prompts
   - Handles periodic sync (default: 5 minutes)
   - Manages cache invalidation and refresh
   - Resolves conflicts (remote wins by default)

2. **PromptTool Model** (extend)
   - Add `langfuseVersion: Int?`
   - Add `langfuseLabels: [String]`
   - Add `langfuseName: String?` (Langfuse prompt name)
   - Add `lastSyncedAt: Date?`
   - Keep existing `remoteId` for backward compatibility

3. **DatabaseManager** (extend)
   - Add methods for Langfuse-specific queries
   - Support upsert based on langfuseName + version
   - Track sync status per prompt

4. **PromptToolManager** (modify)
   - Check Langfuse cache before execution
   - Fall back to local cache if network unavailable
   - Trigger sync on app launch and periodically

### Sync Strategy

**Polling-Based Sync** (Phase 1)
- Check for updates every 5 minutes (configurable)
- Use `listPrompts` API to get metadata
- Compare `updatedAt` timestamps
- Fetch full prompt only if changed
- Update local cache atomically

**Cache Hierarchy**
1. Memory cache (60s TTL) - fastest
2. SQLite cache (persistent) - offline support
3. Langfuse API (authoritative) - source of truth

**Conflict Resolution**
- Remote always wins (no client-side edits to Langfuse prompts)
- Local custom prompts remain untouched
- Clear distinction in UI between Langfuse and local prompts

## Migration Path

### Phase 1: Dual Mode (v0.5)
- Keep existing local prompts working
- Add Langfuse sync as opt-in feature
- Require Langfuse credentials in settings
- Default to local-only if not configured

### Phase 2: Langfuse Primary (v0.6)
- Migrate built-in prompts to Langfuse
- Deprecate prompts.chat integration
- Make Langfuse the default for new users
- Keep local custom prompts supported

### Phase 3: Full Migration (v1.0)
- All prompts managed via Langfuse
- Local storage only for cache
- Remove prompts.chat code
- Add prompt creation UI (push to Langfuse)

## Success Criteria

1. **Functional**
   - Prompts sync from Langfuse within 5 minutes of update
   - App works offline with cached prompts
   - No data loss during migration
   - Backward compatible with existing tools

2. **Performance**
   - Sync operation < 2 seconds for 50 prompts
   - No UI blocking during sync
   - Memory cache hit rate > 90%
   - Network requests < 1 per minute average

3. **User Experience**
   - Clear sync status in UI
   - Manual sync completes in < 3 seconds
   - Error messages actionable
   - No disruption to existing workflows

## Risks & Mitigations

### Risk: Network Dependency
- **Mitigation**: Robust local caching, offline mode, fallback to last known good state

### Risk: API Rate Limits
- **Mitigation**: Respect cache TTL, exponential backoff, batch operations

### Risk: Data Migration Failures
- **Mitigation**: Atomic transactions, rollback capability, backup before migration

### Risk: Breaking Changes
- **Mitigation**: Versioned data model, feature flags, gradual rollout

## Open Questions

1. **Credentials Management**: Where to store Langfuse API keys? (Keychain vs UserDefaults)
2. **Sync Interval**: Should it be user-configurable or fixed?
3. **Prompt Naming**: How to map local prompt names to Langfuse prompt names?
4. **Multi-User**: Should we support multiple Langfuse projects per user?
5. **Fallback Strategy**: What happens if Langfuse is down for extended period?

## Dependencies

- Existing `LangfusePromptService.swift` (already implemented)
- SQLite database schema v0.4+ (already migrated)
- Keychain access for secure credential storage
- Background task scheduling (Timer or DispatchQueue)

## Related Changes

- `add-prompt-tools` - Original prompt tools implementation
- `integrate-smart-settings` - Settings UI for configuration
- Future: `add-prompt-webhooks` - Real-time updates via webhooks
