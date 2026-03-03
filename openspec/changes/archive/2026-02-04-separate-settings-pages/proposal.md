# Proposal: Separate Developer Options and Smart AI into Independent Sidebar Pages

## Metadata
- **Change ID**: separate-settings-pages
- **Type**: Refactoring
- **Related Changes**: integrate-smart-settings (context)
- **Scope**: UI Settings Architecture
- **Priority**: Medium

## Why

**Problem:**
Currently, Developer Options is nested inside the Prompt Tools settings page as a DisclosureGroup, and Smart AI configuration is also embedded within Prompt Tools. This creates several UX issues:

1. **Poor Discoverability**: Developer Options is hidden behind a disclosure group, making it hard to find
2. **Inconsistent Navigation**: Other settings are top-level sidebar items, but these are nested
3. **Cluttered UI**: Prompt Tools page contains too many unrelated concerns (AI service config, tools list, developer options, Langfuse sync)
4. **Scalability**: As Smart AI grows, it needs its own dedicated space for configuration

**User Impact:**
- Developers struggle to find Langfuse integration settings
- Smart AI configuration lacks prominence despite being a key feature
- Settings navigation feels inconsistent and cluttered

**Opportunity:**
Align with macOS HIG by giving each major feature area its own sidebar page, improving discoverability and creating room for future expansion.

## What Changes

Restructure Settings UI to separate Developer Options and Smart AI into independent sidebar pages:

### 1. Update SettingsSection Enum
Add two new cases to `SettingsSection` in `SettingsView.swift`:
- `.developerOptions` - Developer tools and integrations
- `.smartAI` - Smart AI configuration and controls

### 2. Create DeveloperOptionsSettingsView
New file: `SenseFlow/Views/Settings/DeveloperOptionsSettingsView.swift`

**Content moved from PromptToolsSettingsView:**
- Show Prompt Labels toggle
- Langfuse integration section:
  - Enable/disable toggle
  - Public Key field
  - Secret Key field
  - Sync interval slider
  - Active label field
  - Sync now button
  - Last sync timestamp

**Layout:** Form-based with grouped sections, following existing settings patterns

### 3. Create SmartAISettingsView
New file: `SenseFlow/Views/Settings/SmartAISettingsView.swift`

**Initial content:**
- Smart AI feature overview
- Enable/disable toggle
- Hotkey display (Cmd+Ctrl+V)
- Lightweight mode toggle
- Screen recording permission status
- Link to System Settings for permissions

**Future expansion space:**
- Model selection
- Context window configuration
- Custom prompts for Smart AI
- Usage statistics

### 4. Update SettingsView Sidebar
Add two new NavigationLink items:
```swift
NavigationLink(value: SettingsSection.smartAI) {
    Label("Smart AI", systemImage: "sparkles")
}
NavigationLink(value: SettingsSection.developerOptions) {
    Label("开发者选项", systemImage: "hammer")
}
```

Position: After "Prompt Tools", before "Privacy"

### 5. Refactor PromptToolsSettingsView
**Remove:**
- Developer Options DisclosureGroup (lines 199-305)
- `developerOptionsExpanded` @AppStorage
- `showPromptLabels` @AppStorage (move to DeveloperOptionsSettingsView)
- All Langfuse-related state and methods

**Keep:**
- AI Service Configuration section
- Prompt Tools list section
- Tool editor sheet

**Result:** Cleaner, focused view for managing prompt tools only

## How to Implement

### Phase 1: Create New Views
1. Create `DeveloperOptionsSettingsView.swift`
2. Create `SmartAISettingsView.swift`
3. Move state management and logic from PromptToolsSettingsView

### Phase 2: Update Navigation
1. Add new cases to `SettingsSection` enum
2. Update SettingsView sidebar with new NavigationLinks
3. Add switch cases in detail view

### Phase 3: Refactor PromptToolsSettingsView
1. Remove Developer Options section
2. Remove Langfuse-related code
3. Test that tool management still works

### Phase 4: Update Constants
1. Add any new Constants for DeveloperOptions layout
2. Add Constants for SmartAI layout

## Success Criteria

- [x] Developer Options appears as independent sidebar item
- [x] Smart AI appears as independent sidebar item
- [x] All Langfuse functionality works in new location
- [x] Show Prompt Labels toggle works in new location
- [x] PromptToolsSettingsView is simplified and focused
- [x] Navigation between settings pages is smooth
- [x] No regressions in existing settings functionality
- [x] Follows existing Form-based layout patterns

## Technical Notes

**State Management:**
- Use @AppStorage for persistent toggles
- Use @State for transient UI state
- Maintain existing KeychainManager integration for secrets

**Dependencies:**
- Requires @EnvironmentObject DependencyEnvironment
- Uses existing LangfuseSyncService
- Uses existing KeychainManager

**Compatibility:**
- macOS 13+ (NavigationSplitView)
- No breaking changes to existing APIs

## Future Enhancements

After this refactoring:
1. Smart AI page can expand with model selection, context config
2. Developer Options can add more debugging tools
3. Each page has room to grow independently
4. Settings architecture scales better

