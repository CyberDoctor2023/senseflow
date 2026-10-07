# Capability: Prompt Synchronization

## Overview
Background synchronization service that fetches prompts from Langfuse API and maintains local cache consistency.

## ADDED Requirements

### Requirement: Periodic Background Sync
The system SHALL perform automatic background synchronization with Langfuse at configurable intervals.

#### Scenario: Default Sync Interval
**Given** the app is running and Langfuse credentials are configured
**When** 5 minutes have elapsed since the last sync
**Then** the system SHALL automatically fetch prompt updates from Langfuse
**And** update the local cache with any changes
**And** notify PromptToolManager of updated prompts

#### Scenario: User-Configured Interval
**Given** the user has set sync interval to 10 minutes in settings
**When** the sync timer fires
**Then** the system SHALL wait 10 minutes between sync operations
**And** respect the user's preference

#### Scenario: Sync on App Launch
**Given** the app is launching
**When** Langfuse credentials are configured
**Then** the system SHALL perform an immediate sync
**And** complete within 5 seconds or continue in background

---

### Requirement: Delta Synchronization
The system SHALL only fetch prompts that have changed since the last sync.

#### Scenario: Detect Changed Prompts
**Given** the last sync completed at timestamp T1
**When** performing a new sync at timestamp T2
**Then** the system SHALL call `listPrompts` API to get metadata
**And** compare `updatedAt` timestamps with local cache
**And** only fetch full prompt content for changed prompts

#### Scenario: No Changes Available
**Given** no prompts have been updated in Langfuse
**When** performing a sync
**Then** the system SHALL detect no changes from metadata
**And** skip fetching full prompt content
**And** complete sync in < 500ms

---

### Requirement: Conflict Resolution
The system SHALL resolve conflicts between local and remote prompts using a remote-wins strategy.

#### Scenario: Remote Prompt Updated
**Given** a Langfuse prompt exists in local cache
**When** the remote version has a newer `updatedAt` timestamp
**Then** the system SHALL replace the local version with the remote version
**And** preserve the local prompt ID
**And** update `lastSyncedAt` timestamp

#### Scenario: Local Custom Prompt Preserved
**Given** a local custom prompt (source = .custom)
**When** performing sync
**Then** the system SHALL NOT modify the local prompt
**And** SHALL NOT attempt to sync it to Langfuse

---

### Requirement: Error Handling and Retry
The system SHALL handle sync failures gracefully with exponential backoff retry.

#### Scenario: Network Failure
**Given** a sync operation is in progress
**When** the network request fails
**Then** the system SHALL retry after 1 second
**And** double the retry interval on each failure (1s, 2s, 4s, 8s)
**And** cap retry interval at 60 seconds
**And** continue using cached prompts

#### Scenario: Invalid Credentials
**Given** Langfuse credentials are configured
**When** API returns 401 Unauthorized
**Then** the system SHALL stop retrying
**And** notify the user of invalid credentials
**And** disable automatic sync until credentials are updated

#### Scenario: Rate Limit Exceeded
**Given** API returns 429 Too Many Requests
**When** processing the response
**Then** the system SHALL respect the Retry-After header
**And** wait the specified duration before retrying
**And** log the rate limit event

---

### Requirement: Sync Status Tracking
The system SHALL track and expose sync status for UI display.

#### Scenario: Sync in Progress
**Given** a sync operation is running
**When** the UI queries sync status
**Then** the system SHALL return status = .syncing
**And** provide progress information (e.g., "Syncing 5/10 prompts")

#### Scenario: Sync Completed Successfully
**Given** a sync operation completed without errors
**When** the UI queries sync status
**Then** the system SHALL return status = .success
**And** provide last sync timestamp
**And** provide count of updated prompts

#### Scenario: Sync Failed
**Given** a sync operation failed
**When** the UI queries sync status
**Then** the system SHALL return status = .error
**And** provide error message
**And** provide last successful sync timestamp

---

### Requirement: Manual Sync Trigger
The system SHALL allow users to manually trigger synchronization.

#### Scenario: User Triggers Manual Sync
**Given** the user clicks "Sync Now" button
**When** no sync is currently in progress
**Then** the system SHALL immediately start a sync operation
**And** provide real-time progress feedback
**And** complete within 3 seconds for typical prompt sets

#### Scenario: Sync Already in Progress
**Given** a sync operation is already running
**When** the user clicks "Sync Now"
**Then** the system SHALL show "Sync in progress" message
**And** NOT start a duplicate sync operation

---

### Requirement: Offline Mode Support
The system SHALL function normally when offline using cached prompts.

#### Scenario: No Network Available
**Given** the device has no network connectivity
**When** a sync operation is attempted
**Then** the system SHALL detect offline state
**And** skip sync without errors
**And** continue using cached prompts
**And** retry when network becomes available

#### Scenario: Prompt Execution Offline
**Given** the device is offline
**When** user executes a prompt
**Then** the system SHALL use cached prompt from SQLite
**And** execute normally without network calls
**And** NOT show sync errors to user

---

## Related Capabilities
- **prompt-cache**: Provides persistent storage for synced prompts
- **prompt-credentials**: Provides authentication for API calls
- **prompt-ui**: Displays sync status and manual trigger
