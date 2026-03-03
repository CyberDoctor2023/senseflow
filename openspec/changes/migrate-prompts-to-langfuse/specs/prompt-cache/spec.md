# Capability: Prompt Cache Management

## Overview
Multi-tier caching system for prompts with memory cache, persistent SQLite storage, and API fallback.

## ADDED Requirements

### Requirement: Three-Tier Cache Architecture
The system SHALL implement a three-tier cache hierarchy for prompt retrieval.

#### Scenario: Memory Cache Hit
**Given** a prompt was fetched within the last 60 seconds
**When** the prompt is requested again
**Then** the system SHALL return the prompt from memory cache
**And** complete the operation in < 1ms
**And** NOT make any database or network calls

#### Scenario: SQLite Cache Hit
**Given** a prompt is not in memory cache
**And** the prompt exists in SQLite database
**When** the prompt is requested
**Then** the system SHALL return the prompt from SQLite
**And** update the memory cache
**And** complete the operation in < 10ms

#### Scenario: API Fallback
**Given** a prompt is not in memory or SQLite cache
**When** the prompt is requested
**Then** the system SHALL fetch from Langfuse API
**And** update both memory and SQLite caches
**And** complete the operation in < 2 seconds

---

### Requirement: Memory Cache TTL
The system SHALL expire memory cache entries after 60 seconds.

#### Scenario: Fresh Cache Entry
**Given** a prompt was cached 30 seconds ago
**When** the prompt is requested
**Then** the system SHALL return the cached version
**And** NOT check SQLite or API

#### Scenario: Expired Cache Entry
**Given** a prompt was cached 65 seconds ago
**When** the prompt is requested
**Then** the system SHALL treat it as cache miss
**And** check SQLite cache next
**And** refresh memory cache with current version

---

### Requirement: Persistent Storage
The system SHALL persist prompts in SQLite for offline access.

#### Scenario: Store Synced Prompt
**Given** a prompt is fetched from Langfuse API
**When** storing in cache
**Then** the system SHALL save to SQLite with all metadata
**And** include langfuseName, version, labels, updatedAt
**And** set lastSyncedAt to current timestamp

#### Scenario: Retrieve Offline
**Given** the device is offline
**When** a prompt is requested
**Then** the system SHALL retrieve from SQLite
**And** return the last synced version
**And** NOT show errors to user

---

### Requirement: Cache Invalidation
The system SHALL invalidate cache entries when prompts are updated.

#### Scenario: Sync Updates Prompt
**Given** a sync operation detects a prompt update
**When** updating the SQLite cache
**Then** the system SHALL remove the old memory cache entry
**And** store the new version in SQLite
**And** notify PromptToolManager of the change

#### Scenario: Manual Cache Clear
**Given** the user triggers "Clear Cache" in settings
**When** processing the request
**Then** the system SHALL clear all memory cache entries
**And** keep SQLite cache intact (for offline support)
**And** confirm action to user

---

### Requirement: Cache Size Management
The system SHALL limit cache size to prevent excessive memory usage.

#### Scenario: Memory Cache Limit
**Given** memory cache contains 100 prompts
**When** a new prompt is added
**Then** the system SHALL evict the least recently used entry
**And** maintain cache size at or below 100 entries
**And** keep total memory usage < 1MB

#### Scenario: SQLite Cache Unlimited
**Given** SQLite cache contains any number of prompts
**When** storing a new prompt
**Then** the system SHALL NOT enforce size limits
**And** rely on database storage capacity

---

### Requirement: Atomic Cache Updates
The system SHALL update cache atomically to prevent inconsistent state.

#### Scenario: Batch Sync Update
**Given** a sync operation updates 10 prompts
**When** writing to SQLite cache
**Then** the system SHALL use a database transaction
**And** commit all updates atomically
**And** rollback on any error

#### Scenario: Concurrent Access
**Given** multiple threads access the cache
**When** reading and writing simultaneously
**Then** the system SHALL use thread-safe operations
**And** prevent race conditions
**And** ensure data consistency

---

### Requirement: Cache Metrics
The system SHALL track cache performance metrics.

#### Scenario: Hit Rate Tracking
**Given** the app is running
**When** prompts are requested
**Then** the system SHALL track cache hits and misses
**And** calculate hit rate percentage
**And** expose metrics for monitoring

#### Scenario: Performance Monitoring
**Given** cache operations are performed
**When** measuring performance
**Then** the system SHALL track average response times
**And** identify slow operations (> 50ms)
**And** log performance issues

---

## MODIFIED Requirements

### REQ-CACHE-MOD-001: PromptTool Data Model
The PromptTool model SHALL be extended to support Langfuse metadata.

**Before**: PromptTool only stored local fields (name, prompt, shortcuts, source, remoteId)

**After**: PromptTool SHALL include:
- `langfuseName: String?` - Langfuse prompt identifier
- `langfuseVersion: Int?` - Version number from Langfuse
- `langfuseLabels: [String]` - Labels (e.g., ["production", "staging"])
- `lastSyncedAt: Date?` - Last successful sync timestamp

#### Scenario: Langfuse Prompt Storage
**Given** a prompt is fetched from Langfuse
**When** storing in database
**Then** the system SHALL populate all Langfuse fields
**And** set source to .langfuse
**And** preserve backward compatibility with existing prompts

---

## Related Capabilities
- **prompt-sync**: Populates cache with synced prompts
- **prompt-credentials**: Required for API access
- **ui-main-panel**: Displays cached prompts
