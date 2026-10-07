# Proposal: Migrate to SwiftUI Settings Scene

## Why

**Problem**: Settings window loses focus after user interactions (API key input, button clicks, dropdowns), requiring manual reactivation.

**Root Cause - Architectural Issue**:
- Current implementation uses manual `NSHostingController` + `NSWindow` (AppKit approach)
- Requires hand-coded focus management, window lifecycle, and singleton pattern
- Conflicts with macOS system behaviors (Keychain dialogs, permission requests steal focus)
- No integration with system Settings menu infrastructure

**Context7 Research** (docs/refs.md lines 330-340):
- SwiftUI `Settings` scene is Apple's official solution (macOS 13.0+)
- System automatically manages focus, lifecycle, and window restoration
- Auto-adds ⌘, shortcut and App menu integration
- Uses `associated` WindowManagerRole (system handles focus recovery)
- **Zero NSWindowDelegate code required**

**Current Architecture**:
```swift
// Manual window management
class SettingsWindowController {
    private var window: NSWindow?
    func show() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // Still loses focus!
    }
}
```

**User Impact**:
- Frustrating UX during settings configuration
- Manual window reactivation after every Keychain interaction
- Non-standard macOS behavior (no ⌘, shortcut, no App menu item)

## What Changes

**Solution**: Replace manual NSWindow management with SwiftUI `Settings` scene.

### Architecture Migration

**Phase 1: Add SwiftUI App Entry Point**
- Create `SenseFlowApp.swift` with `@main` attribute
- Keep existing `AppDelegate` via `NSApplicationDelegateAdaptor`
- Add `Settings` scene alongside existing window management

**Phase 2: Migrate Settings UI**
- Settings view already uses pure SwiftUI (`SettingsView.swift`)
- Remove `SettingsWindowController.swift` entirely
- System handles all window management

**Phase 3: Update Menu Bar**
- Remove manual "设置" menu item creation
- System auto-adds Settings menu item with ⌘,

### Minimal Scope

**Changed Files**:
- `SenseFlowApp.swift` (NEW) - SwiftUI App entry point
- `AppDelegate.swift` (MODIFIED) - Convert to @NSApplicationDelegateAdaptor
- `SettingsWindowController.swift` (DELETED) - No longer needed
- `Info.plist` (MODIFIED) - Remove NSPrincipalClass (SwiftUI App handles this)

**Unchanged**:
- `SettingsView.swift` - No changes (already SwiftUI)
- All other windows (clipboard window, onboarding) - Keep existing NSWindow approach
- Status bar icon - Keep existing NSStatusItem

### Success Criteria

- Settings window never loses focus during user interactions
- ⌘, shortcut automatically works
- "Settings..." appears in App menu automatically
- Window position/size persists across launches (system handles this)
- All existing settings functionality works identically

## Risks & Mitigation

**Risk**: SwiftUI App + existing NSApplicationDelegate conflict
- **Mitigation**: Use `@NSApplicationDelegateAdaptor` (official Apple pattern)

**Risk**: Clipboard window (NSPanel) behavior changes
- **Mitigation**: Keep clipboard window as NSPanel, only migrate Settings

**Risk**: macOS 13.0+ requirement
- **Mitigation**: Already require macOS 26.0+ (project.md line 85), no new constraint
