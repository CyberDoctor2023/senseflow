# Tasks: Integrate Smart Settings into Prompt Tools UI

**Change ID**: integrate-smart-settings
**Status**: ✅ Completed
**Started**: 2026-01-22
**Completed**: 2026-01-22

---

## Phase 1: Core UI Integration (✅ Completed)

### 1. SmartToolRowView Component (✅ Completed)
- [x] Create SmartToolRowView struct in PromptToolsSettingsView.swift
- [x] Add header row with sparkles icon and "GLOBAL" badge
- [x] Add enable/disable toggle with @AppStorage binding
- [x] Add description text
- [x] Add hotkey display (⌘⌃V)
- [x] Add lightweight mode toggle
- [x] Add permission status indicator
- [x] Add "Open Settings" link for permissions
- [x] Apply blue highlight styling (background + border)

### 2. Integration into PromptToolsSettingsView (✅ Completed)
- [x] Insert SmartToolRowView() above tool list (line 100)
- [x] Add Divider separator
- [x] Verify positioning above regular tools

### 3. State Management (✅ Completed)
- [x] Use @AppStorage("smartFeatureEnabled") for enable toggle
- [x] Use @AppStorage("smartLightweightMode") for lightweight mode
- [x] Verify key consistency with SmartToolManager
- [x] Add @State for hasScreenRecordingPermission

### 4. Permission Handling (✅ Completed)
- [x] Implement checkPermission() using ScreenCaptureManager
- [x] Call checkPermission() in .onAppear
- [x] Implement openSystemSettings() with deep link
- [x] Display permission status (green checkmark / orange warning)
- [x] Conditionally show "Open Settings" button

### 5. Testing & Validation (✅ Completed)
- [x] Build succeeds without errors
- [x] SmartToolRowView appears above tool list
- [x] Enable/disable toggle works
- [x] Lightweight mode toggle works
- [x] Permission status displays correctly
- [x] "Open Settings" link opens System Preferences

### 6. Documentation (✅ Completed)
- [x] Context7 research (Toggle + AppStorage API)
- [x] Context7 research (ScreenCaptureKit permissions)
- [x] Update docs/refs.md with references
- [x] Git commit with detailed message

---

## Implementation Summary

**Files Modified**:
- `SenseFlow/Views/Settings/PromptToolsSettingsView.swift` (+112 lines)
  - Added SmartToolRowView component (lines 276-380)
  - Integrated SmartToolRowView() call (line 100)
  - Added Divider separator (line 102)

**Files Updated**:
- `docs/refs.md` (+2 Context7 references)

**Commit**: `f9bebae` - feat(smart): integrate Smart settings into Prompt Tools UI

---

## Acceptance Criteria (All Met ✅)

- [x] SmartToolRowView appears above tool list in Prompt Tools settings
- [x] Enable/disable toggle works and persists across app launches
- [x] Lightweight mode toggle works and affects screenshot capture
- [x] Permission status shows correct state (green checkmark or orange warning)
- [x] "Open Settings" link opens System Preferences Privacy pane
- [x] Hotkey display shows "⌘⌃V"
- [x] Visual styling distinguishes Smart from regular tools (blue accent, GLOBAL badge)

---

## Future Enhancements (Out of Scope)

- [ ] Hotkey recorder integration (custom hotkey support)
- [ ] Liquid Glass window preview in settings
- [ ] Recommendation history viewer
- [ ] Custom AI system prompt editor

---

**Last Updated**: 2026-01-22
**Completed By**: Claude Sonnet 4.5
