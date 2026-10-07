# Proposal: Smart Context-Aware Tool Selection (v2 - Crash-Free Implementation)

> **Version**: 2.0
> **Previous Attempt**: Failed with application startup crashes (commit `59a171e`)
> **Key Improvement**: Redesigned architecture to eliminate all async/permission crash vectors
> **See Also**: `crash-analysis.md`, `solution-v2.md`

---

## Why

**Problem:**
Users waste time manually selecting the right Prompt Tool from a list or trying to remember specific hotkeys for each tool. There's no contextual awareness—users must decide which tool fits their current task every time, creating cognitive overhead and workflow interruption.

**User Impact:**
- Every tool invocation requires conscious decision-making
- Context switching between work and tool selection
- Underutilization of Prompt Tools due to friction

**Opportunity:**
Automatically recommend the most suitable Prompt Tool based on current context (active application, clipboard content, screen capture), reducing the workflow to a single hotkey press with AI-powered intelligence.

---

## What Changes

Add Smart Context-Aware Tool Selection feature triggered by Cmd+Ctrl+V:
1. Captures current context (app, clipboard, optional screenshot)
2. AI analyzes context and recommends best-matching Prompt Tool
3. Shows recommendation with reason for user confirmation
4. Executes tool upon approval

---

## Summary

Add a Smart feature that uses screen capture and AI analysis to automatically recommend the most suitable Prompt Tool based on current context (application, clipboard, screenshot). Triggered by global hotkey Cmd+Ctrl+V.

## Motivation

**Current Pain Points:**
- Users must manually select tools from a list or remember specific hotkeys
- No contextual awareness - same manual process regardless of scenario
- Cognitive overhead in choosing the right tool for the task
- Workflow interruption when switching to SenseFlow

**User Need:**
- Intelligent tool recommendation based on what they're doing
- Minimal friction - one hotkey to analyze and execute
- Context-aware automation similar to Friendware.ai

## Goals

1. **Context Collection**: Capture current application, clipboard content, and optional screenshot
2. **AI Recommendation**: Use existing AIService to analyze context and recommend best tool
3. **User Confirmation**: Show recommendation with brief explanation, allow accept/reject
4. **Seamless Integration**: Reuse existing PromptToolManager for execution

## Non-Goals

- Machine learning / local model training (Phase 3+)
- Multi-tool workflows / chaining (Future enhancement)
- Custom screenshot regions (Start with full window only)

## Proposed Changes

### Architecture Principles (v2)

**Critical Design Constraints** (learned from v1 crash):
1. ❌ **NEVER** call `CGRequestScreenCaptureAccess()` in async context
2. ❌ **NEVER** use `@available` checks (project requires macOS 26.0+ only)
3. ✅ **ALWAYS** use `@MainActor` for window/task coordination
4. ✅ **ALWAYS** support Task cancellation for rapid triggers
5. ✅ **ALWAYS** use single window instance with content enum

### New Components

1. **ScreenCaptureManager** (`SenseFlow/Managers/ScreenCaptureManager.swift`)
   - ⚠️ **SIMPLIFIED**: No permission request methods
   - Wrap ScreenCaptureKit APIs for capture only
   - Throw errors on permission failure (let caller handle)
   - Convert CGImage to base64 for AI
   - **Key Change**: Direct capture, fail-fast on permission errors

2. **SmartCoordinator** (`SenseFlow/Managers/SmartCoordinator.swift`) **[NEW]**
   - ⭐ **Core orchestrator** - replaces SmartToolManager
   - Manage Task lifecycle with cancellation support
   - Single entry point: `handleTrigger()` called from hotkey
   - Coordinates: context collection → AI call → UI display
   - **Crash Prevention**: Actor-isolated, cancellable tasks

3. **SmartWindowManager** (`SenseFlow/Managers/SmartWindowManager.swift`) **[NEW]**
   - Single window instance management
   - Content-based switching: `.loading` | `.recommendation` | `.error`
   - Prevent duplicate windows
   - **Crash Prevention**: Actor-protected singleton

4. **SmartRecommendationView** (`SenseFlow/Views/SmartRecommendationView.swift`)
   - Display recommendation in Liquid Glass window
   - Show tool name + reason + confidence
   - Keyboard support (Enter/Esc)
   - Execute via PromptToolManager

5. **Models**:
   - `SmartContext.swift`: Context data model
   - `SmartRecommendation.swift`: AI response model
   - `SmartWindowContent.swift`: Enum for window states **[NEW]**
   - `SmartError.swift`: Typed error handling **[NEW]**

### Modified Components

1. **AIService.swift**
   - Add `recommendTool(context:availableTools:)` method
   - Support vision/multimodal input (base64 images)
   - Parse JSON response into SmartRecommendation
   - **No changes from v1**

2. **HotKeyManager.swift**
   - Register Smart hotkey (Cmd+Ctrl+V, configurable)
   - **v2 Change**: Callback uses `@MainActor` closure directly
   ```swift
   // ✅ v2: Direct @MainActor callback
   registerSmartHotKey { @MainActor in
       Task {
           await SmartCoordinator.shared.handleTrigger()
       }
   }
   ```

3. **Settings** (New `SmartSettingsView`)
   - Enable/disable Smart feature
   - Configure hotkey
   - Screenshot mode toggle (enabled/disabled)
   - ⚠️ **v2 Change**: No "Request Permission" button (only guide link)
   - Permission status indicator (read-only)

### Info.plist

- Add `NSScreenCaptureDescription`: "SenseFlow uses screen capture to analyze your current context and recommend the best tool. Screenshots are only taken when you press the Smart hotkey and are not saved."

## Implementation Phases

### Phase 1: MVP (Core Functionality)
**Goal**: Minimal working feature

- Screen capture implementation (ScreenCaptureManager)
- Context collection (SmartContext)
- AI recommendation (AIService extension)
- Basic confirmation UI (Alert-style)
- Hotkey registration (Cmd+Ctrl+V)

**Success Criteria**:
- User presses Cmd+Ctrl+V → sees recommendation → executes tool
- Works with configured AI service (OpenAI/DeepSeek/etc.)
- Handles permission errors gracefully

### Phase 2: UX Polish
**Goal**: Production-ready experience

- Liquid Glass recommendation window
- Loading animations + timeout handling
- Permission guide UI
- Settings panel integration
- Error states (no permission, AI not configured, etc.)

**Success Criteria**:
- Matches existing UI/UX standards (Liquid Glass, animations)
- Clear error messages and recovery paths
- User can configure via Settings

### Phase 3: Advanced Features (Future)
**Goal**: Power user enhancements

- Lightweight mode (no screenshot, text-only)
- Recommendation history tracking
- User feedback collection (improve accuracy)
- Custom recommendation prompts
- Multi-tool suggestions (top 3 instead of 1)

## Dependencies

**Requires**:
- ✅ macOS 26.0+ (project minimum, ScreenCaptureKit stable)
- ⚠️ Screen Recording permission (user-granted, no auto-request)
- ✅ AI service configured (existing requirement)
- ✅ Vision-capable model (gpt-4o, claude-3.5-sonnet, etc.) for screenshot analysis

**Reuses**:
- PromptToolManager (tool execution)
- AIService (AI calls)
- HotKeyManager (hotkey registration)
- ~~NotificationService~~ → Replaced with in-window error display

**v2 Changes**:
- Removed macOS 12.3+ fallback (project is 26.0+ only)
- Removed NotificationService dependency (use dedicated error UI)

## Risks & Mitigations

| Risk | Impact | Mitigation (v2) |
|------|--------|-----------------|
| **Application startup crashes** | Critical | ✅ **ELIMINATED** - No `CGRequestScreenCaptureAccess()` in async context |
| **@available conflicts** | Critical | ✅ **ELIMINATED** - macOS 26.0+ only, no version checks |
| **Window management crashes** | High | ✅ **MITIGATED** - Single window instance, actor-protected |
| **Rapid hotkey triggers** | Medium | ✅ **MITIGATED** - Task cancellation support |
| Users reject Screen Recording permission | Feature degraded | Fallback to text-only mode, clear permission guide |
| AI recommendation latency (>5s) | Poor UX | Loading indicator, 10s timeout, use fast models |
| Inaccurate recommendations | User frustration | Allow manual override, show confidence score |
| High API costs (vision models) | User concern | Display cost in settings, offer text-only mode |
| Permission confusion | Support burden | Static guide UI, deep link to System Settings |

**v2 Risk Summary**:
- ✅ All critical crash vectors eliminated
- ⚠️ User experience risks remain (same as v1)
- ✅ Permission handling now fully non-blocking

## Open Questions

1. **Screenshot Scope**: Default to current window or full screen?
   - **v2 Decision**: Current window only (simpler, less resource-intensive)

2. **Recommendation Display**: Show only top recommendation or top 3?
   - **v2 Decision**: MVP shows top 1, Phase 3 adds multi-select

3. **Lightweight Mode Default**: Should users opt-in to screenshots or opt-out?
   - **v2 Decision**: ✅ **Opt-in** (first trigger attempts screenshot, falls back on error)

4. **Tool Matching**: How to handle "no good match" scenario?
   - **v2 Decision**: Return confidence score, show "Manual Select" option if <0.5

5. **Permission Request Timing**: ❓ **NEW** - When to show permission guide?
   - **v2 Proposal**: After first screenshot failure, show non-blocking guide UI

6. **Rapid Trigger Behavior**: ❓ **NEW** - What happens to cancelled tasks?
   - **v2 Decision**: ✅ **Cancel previous, start new** (user confirmed)

## Success Metrics

**MVP Acceptance**:
- [ ] Cmd+Ctrl+V triggers recommendation flow
- [ ] AI returns recommendation in <10s (p95)
- [ ] User can execute recommended tool
- [ ] Handles missing permissions gracefully

**Quality Targets** (post-MVP):
- Recommendation accuracy >70% (user accepts suggestion)
- Latency <5s (p90)
- Memory usage <20MB (temporary during analysis)
- No impact on existing features

## Alternatives Considered

### Alternative 1: Rule-Based Matching
Match tools based on simple rules (app name, clipboard content type)

**Pros**: Fast, no AI cost, works offline
**Cons**: Limited accuracy, high maintenance, inflexible

**Decision**: Rejected - AI-based is core value prop

### Alternative 2: Always Show Tool List
Don't recommend, just show filtered list based on context

**Pros**: No wrong recommendations
**Cons**: Still requires user decision, minimal value add

**Decision**: Rejected - doesn't reduce cognitive load

### Alternative 3: Automatic Execution (No Confirmation)
AI picks and executes immediately

**Pros**: Fastest workflow
**Cons**: High risk if wrong, user loses control

**Decision**: Rejected - too aggressive, keep confirmation step

### Alternative 4 (NEW): Keep v1 Architecture with Patches
Fix individual crash issues in v1 codebase

**Pros**: Faster iteration, reuse existing code
**Cons**: High risk of new crashes, complex async interactions

**v2 Decision**: ✅ **REJECTED** - Complete architectural rewrite is safer

### Alternative 5 (NEW): Defer Permission to Settings Only
Never request permission automatically, force users to enable in Settings

**Pros**: Zero crash risk
**Cons**: Poor discoverability, low adoption

**v2 Decision**: ⚠️ **PARTIAL ADOPTION** - Try first, guide after failure

## References

- **Previous Implementation**: Commit `59a171e` (reverted due to crashes)
- **Crash Analysis**: `crash-analysis.md` (detailed root cause)
- **v2 Solution**: `solution-v2.md` (architectural improvements)
- **Friendware.ai**: Context-aware AI automation ([research](https://www.funblocks.net/aitools/reviews/friendware))
- **ScreenCaptureKit**: Apple docs ([docs/refs.md](../../../docs/refs.md))
- **Existing Prompt Tools**: `SenseFlow/Models/PromptTool.swift`
- **AI Service**: `SenseFlow/Services/AIService.swift`

---

## v2 Changelog

**Major Changes from v1**:
1. ✅ Added `SmartCoordinator` - centralized task orchestration
2. ✅ Added `SmartWindowManager` - single window instance pattern
3. ✅ Removed `CGRequestScreenCaptureAccess()` - no blocking permission dialogs
4. ✅ Removed all `@available` checks - macOS 26.0+ only
5. ✅ Added Task cancellation - handle rapid triggers
6. ✅ Changed permission strategy - try first, guide after failure
7. ✅ Simplified ScreenCaptureManager - capture only, no permission methods

**Validation Checklist**:
- [ ] No `CGRequestScreenCaptureAccess()` calls anywhere
- [ ] No `@available(macOS XX, *)` checks
- [ ] Single `@MainActor` coordinator class
- [ ] Single window instance with enum content
- [ ] Task cancellation on rapid triggers
- [ ] All errors display UI feedback (no crashes)
- [ ] Permission guide is static (no action buttons that trigger system dialogs)
