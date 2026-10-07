# Tasks: Migrate to SwiftUI Settings Scene

## Implementation Order

### Phase 1: Add SwiftUI App Entry Point
- [x] 1.1 Create `SenseFlowApp.swift` with `@main struct SenseFlowApp: App`
- [x] 1.2 Add `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`
- [x] 1.3 Add empty `WindowGroup` scene (placeholder for future migration)
- [x] 1.4 Build and verify app launches normally
- **Files**: `SenseFlowApp.swift` (NEW)
- **Validation**: App launches, status bar icon appears

### Phase 2: Add Settings Scene
- [x] 2.1 Add `Settings { SettingsView() }` scene to App body
- [x] 2.2 Wrap in `#if os(macOS)` for platform safety
- [x] 2.3 Build and verify Settings menu item appears in App menu
- [x] 2.4 Test ⌘, shortcut opens settings window
- **Files**: `SenseFlowApp.swift`
- **Validation**: Settings window opens via menu/shortcut

### Phase 3: Remove Manual Window Management
- [x] 3.1 Remove `SettingsWindowController.swift` file
- [x] 3.2 Remove manual "设置" menu item from AppDelegate
- [x] 3.3 Update Xcode project.pbxproj (remove file references)
- [x] 3.4 Build and verify no compilation errors
- **Files**: `SettingsWindowController.swift` (DELETE), `AppDelegate.swift`
- **Validation**: Clean build, no references to old controller

### Phase 4: Update Info.plist
- [x] 4.1 Remove `NSPrincipalClass` key (SwiftUI App handles this)
- [x] 4.2 Verify app still launches correctly
- **Files**: `Info.plist`
- **Validation**: App launches, all functionality works

### Phase 5: Testing
- [x] 5.1 Test API key input → focus stays on settings window
- [x] 5.2 Test "测试连接" button → focus stays on settings window
- [x] 5.3 Test AI service dropdown → focus stays on settings window
- [x] 5.4 Test ⌘, shortcut opens/closes settings
- [x] 5.5 Test window position persists across launches
- **Validation**: All focus issues resolved, standard macOS behavior

## Dependencies

Phase 1 must complete before Phase 2.
Phase 2 must complete before Phase 3.
Phases 3-4 can run in parallel.
Phase 5 is final validation.

## Rollback Plan

If issues arise, revert commits and restore `SettingsWindowController.swift`.

