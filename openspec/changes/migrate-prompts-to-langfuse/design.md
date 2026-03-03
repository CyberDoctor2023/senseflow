# Design Document: Langfuse Prompt Management Integration

## Overview
This document captures the architectural decisions and design rationale for migrating prompt management from local-only storage to Langfuse-based centralized management with client-side caching.

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                        Langfuse Cloud                        │
│  - Prompt versioning & labels                                │
│  - REST API (BasicAuth)                                      │
│  - Redis cache + PostgreSQL                                  │
└─────────────────────────────────────────────────────────────┘
                              ↓ HTTPS
┌─────────────────────────────────────────────────────────────┐
│              LangfusePromptSyncService (new)                 │
│  - Periodic polling (5 min default)                          │
│  - Memory cache (60s TTL)                                    │
│  - Conflict resolution (remote wins)                         │
│  - Error handling & retry                                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              DatabaseManager (SQLite cache)                  │
│  - Persistent storage                                        │
│  - Offline support                                           │
│  - Sync status tracking                                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    PromptToolManager                         │
│  - Prompt execution                                          │
│  - Hotkey registration                                       │
│  - Cache-first retrieval                                     │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

**Sync Flow (Background)**
```
Timer (5 min) → LangfusePromptSyncService.sync()
                ↓
        listPrompts API (metadata only)
                ↓
        Compare updatedAt timestamps
                ↓
        Fetch changed prompts (getPrompt API)
                ↓
        Update SQLite cache atomically
                ↓
        Invalidate memory cache
                ↓
        Notify PromptToolManager
```

**Execution Flow (Runtime)**
```
User triggers prompt → PromptToolManager.executeTool()
                       ↓
               Check memory cache (60s TTL)
                       ↓ (miss)
               Check SQLite cache
                       ↓ (miss)
               Fetch from Langfuse API
                       ↓
               Update caches
                       ↓
               Execute with AIService
```

## Key Design Decisions

### 1. Polling vs Webhooks

**Decision**: Use polling for Phase 1, add webhooks in Phase 2

**Rationale**:
- Polling is simpler to implement and test
- No need for public endpoint or ngrok tunneling
- Langfuse webhooks require HTTPS endpoint (complex for desktop app)
- 5-minute polling is acceptable for prompt updates (not real-time critical)
- Can add webhooks later for power users who need instant updates

**Trade-offs**:
- ✅ Simpler implementation
- ✅ Works behind firewalls/VPNs
- ✅ No server infrastructure needed
- ❌ 5-minute delay for updates
- ❌ Unnecessary API calls if no changes

### 2. Cache Strategy

**Decision**: Three-tier cache (memory → SQLite → API)

**Rationale**:
- Memory cache (60s TTL) eliminates network calls for frequent executions
- SQLite cache provides offline support and persistence
- API is authoritative source of truth
- Matches Langfuse SDK's recommended pattern

**Trade-offs**:
- ✅ Fast execution (memory cache hit)
- ✅ Offline support (SQLite cache)
- ✅ Always eventually consistent
- ❌ Complexity of managing three layers
- ❌ Potential for stale data (max 5 min + 60s)

### 3. Conflict Resolution

**Decision**: Remote always wins (no client-side edits to Langfuse prompts)

**Rationale**:
- Langfuse is the source of truth for managed prompts
- Prevents sync conflicts and merge complexity
- Users can still create local custom prompts
- Clear separation: Langfuse prompts (read-only) vs local prompts (editable)

**Trade-offs**:
- ✅ Simple conflict resolution
- ✅ No merge logic needed
- ✅ Clear ownership model
- ❌ Cannot edit Langfuse prompts locally
- ❌ Must use Langfuse UI for changes

### 4. Data Model Extension

**Decision**: Extend PromptTool with optional Langfuse fields

**Rationale**:
- Backward compatible with existing prompts
- Single model for all prompt types (local, community, Langfuse)
- Optional fields allow gradual migration
- Source enum distinguishes prompt types

**Schema**:
```swift
struct PromptTool {
    // Existing fields
    let id: UUID
    var name: String
    var prompt: String
    var source: ToolSource  // .builtin, .community, .custom, .langfuse

    // New Langfuse fields (optional)
    var langfuseName: String?      // Langfuse prompt name
    var langfuseVersion: Int?      // Version number
    var langfuseLabels: [String]   // e.g., ["production", "staging"]
    var lastSyncedAt: Date?        // Last successful sync
}
```

### 5. Credential Storage

**Decision**: Store Langfuse API keys in macOS Keychain

**Rationale**:
- Keychain provides OS-level encryption
- More secure than UserDefaults or plain files
- Standard practice for sensitive credentials
- Already have KeychainManager infrastructure

**Implementation**:
```swift
extension KeychainManager {
    func getLangfusePublicKey() -> String?
    func getLangfuseSecretKey() -> String?
    func setLangfuseKeys(publicKey: String, secretKey: String)
}
```

### 6. Sync Interval

**Decision**: 5 minutes default, user-configurable (1-60 min range)

**Rationale**:
- 5 minutes balances freshness vs API load
- Langfuse API has no documented rate limits, but be respectful
- User-configurable for power users who need faster/slower sync
- Can disable sync entirely for offline-only mode

**Configuration**:
```swift
@AppStorage("langfuseSyncInterval") var syncInterval: Int = 300  // seconds
@AppStorage("langfuseSyncEnabled") var syncEnabled: Bool = true
```

### 7. Error Handling Strategy

**Decision**: Fail gracefully with fallback to cached data

**Rationale**:
- Network failures should not break app functionality
- Always prefer stale data over no data
- Show clear error messages but don't block user
- Retry with exponential backoff (1s, 2s, 4s, 8s, max 60s)

**Error Hierarchy**:
1. Memory cache (instant)
2. SQLite cache (fast, offline)
3. API with retry (slow, requires network)
4. Fallback prompt (last resort)

### 8. Migration Strategy

**Decision**: Dual-mode operation (local + Langfuse coexist)

**Rationale**:
- Gradual migration reduces risk
- Users can opt-in to Langfuse
- Existing workflows unaffected
- Can deprecate local prompts in future version

**Migration Path**:
- v0.5: Add Langfuse support (opt-in)
- v0.6: Migrate built-in prompts to Langfuse (default)
- v1.0: Langfuse-only (local custom prompts still supported)

## Performance Considerations

### Sync Performance
- **Target**: < 2 seconds for 50 prompts
- **Optimization**: Batch API calls, parallel fetching
- **Monitoring**: Track sync duration, cache hit rate

### Memory Usage
- **Memory Cache**: Max 100 prompts × ~2KB = ~200KB
- **Acceptable**: < 1MB total for prompt management
- **Monitoring**: Profile memory usage in Instruments

### Network Usage
- **Polling**: 1 API call per 5 minutes = 288 calls/day
- **Fetch**: Only changed prompts (delta sync)
- **Acceptable**: < 1MB/day for typical usage

## Security Considerations

### Credential Security
- Store API keys in Keychain (encrypted)
- Never log credentials
- Clear credentials on logout
- Validate credentials before storing

### Network Security
- Always use HTTPS for API calls
- Validate SSL certificates
- Handle man-in-the-middle scenarios
- Timeout requests after 20 seconds

### Data Privacy
- Prompts may contain sensitive instructions
- Cache encrypted on disk (FileVault)
- Clear cache on app uninstall
- No telemetry of prompt content

## Testing Strategy

### Unit Tests
- Cache hit/miss logic
- Conflict resolution
- Error handling and retry
- Data model serialization

### Integration Tests
- API communication (mock server)
- Database operations
- Sync flow end-to-end
- Offline mode

### Manual Tests
- Network failure scenarios
- Slow network (throttled)
- Invalid credentials
- Large prompt sets (100+)
- Migration from v0.4

## Rollback Plan

If Langfuse integration causes issues:
1. Disable sync via feature flag
2. Fall back to local prompts only
3. Keep SQLite cache intact
4. No data loss (local prompts preserved)
5. Can re-enable after fix

## Future Enhancements

### Phase 2 (v0.6)
- Webhook support for real-time updates
- Prompt analytics (usage tracking)
- Multi-project support
- Prompt composition (nested prompts)

### Phase 3 (v1.0)
- Bi-directional sync (push local prompts to Langfuse)
- Prompt creation UI (integrated with Langfuse)
- Team collaboration features
- Prompt A/B testing

## Open Questions

1. **Q**: Should we support multiple Langfuse projects?
   **A**: Not in Phase 1. Single project per user is sufficient.

2. **Q**: How to handle prompt name conflicts?
   **A**: Langfuse name takes precedence. Local prompts can be renamed.

3. **Q**: What if user has no internet for extended period?
   **A**: App works normally with cached prompts. Sync resumes when online.

4. **Q**: Should sync be automatic or manual?
   **A**: Automatic by default, with manual trigger option.

5. **Q**: How to migrate existing built-in prompts?
   **A**: Create matching prompts in Langfuse, map by name during migration.
