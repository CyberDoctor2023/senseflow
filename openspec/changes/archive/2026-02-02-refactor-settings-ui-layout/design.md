# Design: Refactor Settings UI Layout

## Architecture Decision

### Problem Statement
Current settings window uses NavigationSplitView (sidebar + detail pane), which is:
- Not recommended by Apple HIG for settings windows
- Oversized (750×500pt vs standard 350pt width)
- Inconsistent with macOS design language

### Solution: TabView with Toolbar Icons

**Rationale**:
1. **Apple HIG Compliance**: Official recommendation for settings windows
2. **Standard macOS Pattern**: Matches System Settings and most Mac apps
3. **Space Efficiency**: 350pt width vs 750pt (53% reduction)
4. **Better UX**: Toolbar icons are faster to navigate than sidebar list

### Design Comparison

#### Current Design (NavigationSplitView)
```
┌─────────────────────────────────────────────────────┐
│  Settings                                     ○ ○ ○ │
├──────────┬──────────────────────────────────────────┤
│          │                                           │
│ 通用     │  [General Settings Content]              │
│ 快捷键   │                                           │
│ Prompt   │                                           │
│ 隐私     │                                           │
│ 高级     │                                           │
│          │                                           │
│  200pt   │           500pt minimum                   │
└──────────┴──────────────────────────────────────────┘
         750pt × 500pt
```

#### New Design (TabView)
```
┌──────────────────────────────────────┐
│  Settings                      ○ ○ ○ │
├──────────────────────────────────────┤
│  ⚙️  ⌨️  ✨  🔒  🔧                  │  ← Toolbar
├──────────────────────────────────────┤
│                                      │
│  [General Settings Content]          │
│                                      │
│                                      │
│                                      │
│         350pt maximum                │
└──────────────────────────────────────┘
      Auto-height based on content
```

## Implementation Strategy

### Phase 1: Structure Replacement

**Before**:
```swift
struct SettingsView: View {
    @State private var selectedSection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            SettingsSidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(200)
        } detail: {
            SettingsDetailView(selectedSection: selectedSection ?? .general)
                .frame(minWidth: 500)
        }
        .background(.regularMaterial)
        .frame(width: 750, height: 500)
    }
}
```

**After**:
```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("通用", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("快捷键", systemImage: "keyboard") {
                ShortcutSettingsView()
            }
            Tab("Prompt Tools", systemImage: "wand.and.stars") {
                PromptToolsSettingsView()
            }
            Tab("隐私", systemImage: "lock") {
                PrivacySettingsView()
            }
            Tab("高级", systemImage: "wrench.and.screwdriver") {
                AdvancedSettingsView()
            }
        }
        .scenePadding()
        .frame(maxWidth: 350, minHeight: 100)
    }
}
```

### Phase 2: Simplification

**Deleted Structs**:
- `SettingsSidebarView` - No longer needed (TabView handles navigation)
- `SettingsDetailView` - No longer needed (direct content embedding)

**Kept Unchanged**:
- `SettingsSection` enum - Can be kept for programmatic tab selection if needed
- All content views (GeneralSettingsView, etc.) - Zero changes required

### Phase 3: Sizing & Spacing

**Old Approach**:
- Fixed width: 750pt
- Fixed height: 500pt
- Manual background: `.background(.regularMaterial)`

**New Approach**:
- Maximum width: 350pt (recommended by Apple)
- Minimum height: 100pt (auto-expands based on content)
- System margins: `.scenePadding()` (standard macOS spacing)
- No manual background (TabView provides system-standard appearance)

## Technical Details

### Tab Syntax (macOS 14.0+)

```swift
Tab("Label", systemImage: "icon.name") {
    ContentView()
}
```

**Benefits**:
- Auto-generates toolbar button with icon
- System handles tab selection state
- No need for @State binding
- Supports keyboard navigation (⌃Tab / ⌃⇧Tab)

### Scene Padding

`.scenePadding()` applies standard macOS window content margins:
- Top: 20pt (below toolbar)
- Sides: 20pt (left/right margins)
- Bottom: 20pt (above window edge)

### Responsive Width

`maxWidth: 350` allows window to:
- Shrink below 350pt if needed (responsive)
- Never exceed 350pt (follows HIG)
- Auto-center content within available space

## Trade-offs

### Advantages
✅ Matches macOS design standards
✅ 53% smaller window footprint
✅ Simpler code (50+ lines removed)
✅ Faster navigation (toolbar vs sidebar clicks)
✅ Better keyboard shortcuts (⌃Tab)

### Disadvantages
⚠️ Less vertical space for section labels (toolbar icons vs sidebar text)
⚠️ No hierarchical navigation (flat tab structure)

**Mitigation**: Settings only have 5 top-level sections (no hierarchy needed), and toolbar icons are standard macOS pattern.

## References

- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/settings
- SwiftUI TabView: https://developer.apple.com/documentation/swiftui/tabview
- Context7 Research: docs/refs.md lines 385-394
