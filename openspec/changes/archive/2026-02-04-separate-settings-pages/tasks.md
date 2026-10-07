# Tasks: Separate Developer Options and Smart AI into Independent Sidebar Pages

## Phase 1: Update Navigation Structure
- [x] Add `.smartAI` and `.developerOptions` cases to `SettingsSection` enum in `SettingsView.swift`
- [x] Add NavigationLink for "Smart AI" with sparkles icon in sidebar
- [x] Add NavigationLink for "开发者选项" with hammer icon in sidebar
- [x] Update detail view switch statement to handle new cases

## Phase 2: Create DeveloperOptionsSettingsView
- [x] Create new file `SenseFlow/Views/Settings/DeveloperOptionsSettingsView.swift`
- [x] Move "Show Prompt Labels" toggle from PromptToolsSettingsView
- [x] Move Langfuse integration section (enable/disable, keys, sync interval, label)
- [x] Implement `loadLangfuseConfig()` method
- [x] Implement `saveAllKeys()` method for Keychain integration
- [x] Implement `syncNow()` method for manual sync
- [x] Implement `updateSyncStatus()` helper method
- [x] Add Form-based layout with grouped sections
- [x] Add preview for macOS 26.0+

## Phase 3: Create SmartAISettingsView
- [x] Create new file `SenseFlow/Views/Settings/SmartAISettingsView.swift`
- [x] Add Smart AI feature overview section with icon and description
- [x] Add "启用 Smart AI" toggle with @AppStorage
- [x] Add hotkey display (⌘⌃V) as read-only field
- [x] Add "轻量模式" toggle with @AppStorage
- [x] Add screen recording permission status check
- [x] Add "打开系统设置" button for permission management
- [x] Implement `checkPermissions()` method
- [x] Implement `openSystemSettings()` method
- [x] Add Form-based layout with grouped sections
- [x] Add preview for macOS 26.0+

## Phase 4: Refactor PromptToolsSettingsView
- [x] Remove `developerOptionsExpanded` @AppStorage variable
- [x] Remove `showPromptLabels` @AppStorage variable
- [x] Remove all Langfuse-related state variables (enabled, keys, interval, label, syncing, status)
- [x] Remove Developer Options DisclosureGroup section (lines 199-305)
- [x] Remove `loadLangfuseConfig()` method
- [x] Remove `saveLangfuseConfig()` method
- [x] Remove `syncNow()` method
- [x] Remove `updateSyncStatus()` method
- [x] Remove `dateFormatter` property
- [x] Update `loadAllKeys()` to remove Langfuse configuration loading
- [x] Update `saveAllKeys()` to remove Langfuse configuration saving
- [x] Remove `loadLangfuseConfig()` call from `onAppear`
- [x] Verify AI Service Configuration section still works
- [x] Verify Prompt Tools list section still works
- [x] Verify Tool editor sheet still works

## Phase 5: Documentation
- [x] Update `docs/refs.md` with NavigationSplitView Context7 research
- [x] Update proposal.md success criteria to mark all items as completed

## Phase 6: Testing & Validation
- [x] Verify all files compile without errors
- [x] Commit changes with descriptive commit message
- [x] Update OpenSpec proposal with completion status

## Summary
- **Files Created**: 2 (DeveloperOptionsSettingsView.swift, SmartAISettingsView.swift)
- **Files Modified**: 3 (SettingsView.swift, PromptToolsSettingsView.swift, docs/refs.md)
- **Lines Added**: ~424
- **Lines Removed**: ~220
- **Net Change**: Cleaner architecture with better separation of concerns
