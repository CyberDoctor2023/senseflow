# Proposal: Refactor Settings UI Layout

## Why

**Problem**: Settings window UI layout doesn't follow macOS design guidelines and feels cluttered.

**Current Issues**:
1. **Wrong Layout Pattern**: Uses `NavigationSplitView` (750×500pt) instead of standard `TabView`
2. **Oversized Window**: 750×500pt vs Apple's recommended maxWidth: 350
3. **Non-standard Design**: Sidebar + detail pane pattern is for document apps, not settings
4. **Inconsistent with macOS**: System Settings and most Mac apps use toolbar-based tabs

**Context7 Research** (docs/refs.md lines 374-394):
- Apple HIG explicitly recommends `TabView` for settings windows
- Standard size: `.frame(maxWidth: 350, minHeight: 100)` + `.scenePadding()`
- TabView auto-generates toolbar icon buttons (macOS standard style)
- NavigationSplitView is for multi-pane document apps, not preferences

**Current Architecture**:
```swift
// SettingsView.swift (lines 17-28)
NavigationSplitView {
    SettingsSidebarView(selectedSection: $selectedSection)
        .navigationSplitViewColumnWidth(200)
} detail: {
    SettingsDetailView(selectedSection: selectedSection ?? .general)
        .frame(minWidth: 500)
}
.frame(width: 750, height: 500)  // Too large!
```

**User Impact**:
- Settings window feels bloated and non-native
- Wastes screen space (750pt width for simple settings)
- Doesn't match macOS design language
- Harder to navigate than standard tab-based settings

## What Changes

**Solution**: Replace NavigationSplitView with TabView following Apple HIG.

### UI Layout Migration

**Before** (NavigationSplitView):
- Sidebar: 200pt fixed width
- Detail pane: 500pt minimum width
- Total: 750×500pt window
- 5 sections in sidebar list

**After** (TabView):
- Toolbar with 5 icon buttons
- Content area: maxWidth 350pt
- Auto-sized height based on content
- Standard macOS settings appearance

### Minimal Scope

**Changed Files**:
- `SettingsView.swift` (MODIFIED) - Replace NavigationSplitView with TabView
  - Remove `SettingsSidebarView` struct
  - Remove `SettingsDetailView` struct
  - Use `Tab("Label", systemImage: "icon") { ContentView() }` syntax
  - Update frame to `.frame(maxWidth: 350, minHeight: 100)`
  - Add `.scenePadding()` for system margins

**Unchanged**:
- All settings content views (GeneralSettingsView, ShortcutSettingsView, etc.)
- Settings functionality and logic
- Window management (handled by existing SettingsWindowController)
- Data persistence (@AppStorage)

### Success Criteria

- Settings window uses TabView with toolbar icons
- Window size matches macOS standards (maxWidth: 350)
- All 5 settings sections accessible via toolbar tabs
- Visual appearance matches system Settings app style
- All existing settings functionality works identically

## Risks & Mitigation

**Risk**: TabView requires macOS 14.0+ for Tab syntax
- **Mitigation**: Project already requires macOS 26.0+ (no new constraint)

**Risk**: Content might not fit in 350pt width
- **Mitigation**: Current content views already use responsive layouts with padding

**Risk**: Users might prefer sidebar navigation
- **Mitigation**: TabView is Apple's recommended pattern, matches system Settings

## Dependencies

**Blocks**: None (independent UI change)

**Blocked By**: None (can be done immediately)

**Related Changes**:
- `migrate-to-swiftui-settings-scene` (0/19 tasks) - Handles window lifecycle
- This change focuses purely on UI layout (NavigationSplitView → TabView)
- Both changes are complementary and can be done in either order
