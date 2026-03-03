# Proposal: Integrate Smart Tool Selection into Settings UI

## Metadata
- **Change ID**: integrate-smart-settings
- **Type**: Enhancement
- **Related Changes**: add-smart-context-aware-tools (dependency)
- **Scope**: UI Settings Integration
- **Priority**: High

## Why

**Problem:**
The Smart Context-Aware Tool Selection feature (Phase 1 MVP) has been implemented with full backend functionality, but users cannot configure or control it through the UI. The feature is invisible in the settings panel, making it impossible for users to:
- Enable/disable the Smart recommendation feature
- View or configure the Smart hotkey (Cmd+Ctrl+V)
- Toggle lightweight mode (text-only vs screenshot-enabled)
- Check screen recording permission status
- Understand how to use the feature

**User Impact:**
- Feature discoverability: Users don't know the Smart feature exists
- No control: Cannot turn off the feature if unwanted
- Permission confusion: No guidance on screen recording permission
- Poor UX: Hidden feature contradicts "intelligent recommendation" value proposition

**Opportunity:**
Position Smart as a premium "global tool" in the Prompt Tools settings page, appearing above all regular tools to emphasize its special role as an AI-powered orchestrator that can intelligently select from all available tools.

## What Changes

Add Smart Tool Selection configuration UI to the Prompt Tools settings page:

1. **SmartToolRowView Component** (置顶特殊卡片)
   - Visually distinct from regular tools (special icon, highlight styling)
   - Positioned above the tool list separator
   - Shows "Global AI Recommendation" badge
   - Displays current hotkey (Cmd+Ctrl+V)

2. **Configuration Options**
   - Toggle: Enable/Disable Smart recommendations
   - Hotkey display (read-only in MVP, configurable in future)
   - Toggle: Lightweight mode (text-only vs screenshot)
   - Permission status indicator (Screen Recording)
   - Link to System Settings for permissions

3. **Integration Points**
   - Modify `PromptToolsSettingsView.swift` to include SmartToolRowView
   - Use @AppStorage for persistent settings
   - Real-time permission check via ScreenCaptureManager

## Summary

Integrate Smart Context-Aware Tool Selection settings into the Prompt Tools settings page as a prominent, visually distinct global tool card positioned above regular tools, with configuration options for enable/disable, hotkey display, lightweight mode, and permission status.

## Motivation

**Current Pain Points:**
- Smart feature exists but is completely hidden from users
- No way to disable the feature via UI (only code-level changes)
- Screen recording permission issues have no user-facing guidance
- Missing integration makes the feature feel incomplete

**User Need:**
- Discoverability: "What is this Smart feature and how do I use it?"
- Control: "I want to disable Smart recommendations temporarily"
- Guidance: "How do I grant screen recording permission?"
- Transparency: "Is the feature using screenshots or just text?"

## Goals

1. **Discoverability**: Make Smart feature immediately visible in settings
2. **Control**: Allow users to enable/disable and configure the feature
3. **Guidance**: Provide clear permission status and help
4. **Integration**: Seamlessly blend into existing Prompt Tools UI
5. **Future-proof**: Design extensible for Phase 2 enhancements (Liquid Glass window, custom hotkey recorder, etc.)

## Non-Goals

- Hotkey recorder (deferred to future enhancement)
- UserDefaults persistence for hotkey code/modifiers (Phase 1 uses hardcoded Cmd+Ctrl+V)
- Liquid Glass window configuration (Phase 2 feature)
- Recommendation history viewer (Phase 3 feature)
- Custom AI prompts (Phase 3 feature)

## Proposed Changes

### 1. New Component: SmartToolRowView

**File**: `SenseFlow/Views/Settings/PromptToolsSettingsView.swift` (append to file)

**Design**:
```swift
@available(macOS 26.0, *)
struct SmartToolRowView: View {
    @AppStorage("smartFeatureEnabled") private var isEnabled = true
    @AppStorage("smartLightweightMode") private var isLightweightMode = false
    @State private var hasScreenRecordingPermission = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with toggle
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("Smart AI Recommendation")
                    .fontWeight(.semibold)

                Text("GLOBAL")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2))
                    .cornerRadius(4)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }

            // Description
            Text("AI-powered context-aware tool selection based on your current app, clipboard, and screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Hotkey display
            HStack {
                Image(systemName: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Hotkey:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("⌘⌃V")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .cornerRadius(4)
            }

            if isEnabled {
                Divider()

                // Lightweight mode toggle
                Toggle("Lightweight Mode (text-only, faster)", isOn: $isLightweightMode)
                    .font(.caption)

                if !isLightweightMode {
                    // Permission status
                    HStack(spacing: 6) {
                        Image(systemName: hasScreenRecordingPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(hasScreenRecordingPermission ? .green : .orange)
                            .font(.caption)

                        Text(hasScreenRecordingPermission ? "Screen Recording granted" : "Permission required")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !hasScreenRecordingPermission {
                            Button("Open Settings") {
                                openSystemSettings()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            checkPermission()
        }
    }

    private func checkPermission() {
        hasScreenRecordingPermission = ScreenCaptureManager.shared.checkPermission()
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### 2. Modify PromptToolsSettingsView

**File**: `SenseFlow/Views/Settings/PromptToolsSettingsView.swift`

**Change**: Insert SmartToolRowView above tool list

**Location**: Line ~103 (after "Prompt Tools" label, before tool list)

```swift
// BEFORE:
Label("Prompt Tools", systemImage: "wand.and.stars")
    .font(.headline)

if tools.isEmpty {
    ...
} else {
    ForEach(tools) { tool in
        ...
    }
}

// AFTER:
Label("Prompt Tools", systemImage: "wand.and.stars")
    .font(.headline)

// Smart global tool (置顶)
SmartToolRowView()

Divider()
    .padding(.vertical, 4)

if tools.isEmpty {
    ...
} else {
    ForEach(tools) { tool in
        ...
    }
}
```

### 3. UserDefaults Keys

**File**: `SenseFlow/Managers/SmartToolManager.swift`

**Current**: `isLightweightMode` uses UserDefaults.standard

**Enhancement**: Ensure key consistency:
- `smartFeatureEnabled`: Bool (default: true)
- `smartLightweightMode`: Bool (default: false)

## Implementation Phases

### Phase 1: Core UI Integration (This Proposal)
1. Create SmartToolRowView component
2. Integrate into PromptToolsSettingsView
3. Wire up @AppStorage bindings
4. Test permission status display

### Phase 2: Future Enhancements (Out of Scope)
- Hotkey recorder integration (custom hotkey support)
- Liquid Glass window preview in settings
- Recommendation history viewer
- Custom AI system prompt editor

## Dependencies

**Requires**:
- `add-smart-context-aware-tools` Phase 1 MVP (completed)
- ScreenCaptureManager.checkPermission() method
- @AppStorage keys defined

**Blocks**:
- None (this is a pure UI enhancement)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Permission check performance | UI lag on settings open | Cache permission status, only check onAppear |
| @AppStorage conflicts | Settings don't persist | Use unique key prefixes ("smart*") |
| UI clutter | Settings page too long | Keep card compact, collapsible details optional |
| Inconsistent styling | Visual mismatch with other tools | Follow ToolRowView design patterns, use blue accent for differentiation |

## Open Questions

None - all requirements clarified with user.

## Success Metrics

**Acceptance Criteria**:
- [ ] SmartToolRowView appears above tool list in Prompt Tools settings
- [ ] Enable/disable toggle works and persists across app launches
- [ ] Lightweight mode toggle works and affects screenshot capture
- [ ] Permission status shows correct state (green checkmark or orange warning)
- [ ] "Open Settings" link opens System Preferences Privacy pane
- [ ] Hotkey display shows "⌘⌃V"
- [ ] Visual styling distinguishes Smart from regular tools (blue accent, GLOBAL badge)

## Alternatives Considered

### Alternative 1: Separate Settings Section
**Rejected**: User explicitly requested integration into Prompt Tools page, not separate section.

### Alternative 2: Bottom of Tool List
**Rejected**: Smart should be prominent (top position) as a "global orchestrator" tool.

### Alternative 3: Inline with Regular Tools
**Rejected**: Needs visual distinction to emphasize its special role.

## References

- **Parent Change**: `add-smart-context-aware-tools` (Phase 1 MVP implementation)
- **User Requirement**: "作为置顶的特殊工具卡片" + 4 configuration options
- **Related Files**:
  - `SenseFlow/Views/Settings/PromptToolsSettingsView.swift`
  - `SenseFlow/Managers/ScreenCaptureManager.swift`
  - `SenseFlow/Managers/SmartToolManager.swift`

---

**Version**: 1.1
**Date**: 2026-01-22
**Status**: ✅ Completed - Implemented in commit f9bebae
**Implementation Date**: 2026-01-22
