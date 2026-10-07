# Solution v2: Smart Context-Aware Tool Selection (Crash-Free Implementation)

## Context

This is the **second iteration** of the Smart feature after a complete rollback (commit `59a171e`).

**Previous Failure Summary**:
- Application crashed on startup due to `CGRequestScreenCaptureAccess()` blocking calls in async context
- `@available` checks conflicted with async callbacks in HotKeyManager
- Window management race conditions when hotkey triggered rapidly
- See `crash-analysis.md` for detailed root cause analysis

---

## Key Design Decisions (User-Confirmed)

Based on crash analysis and user preferences:

1. **Permission Strategy**: "First-use automatic request (recommended)"
   - Try screenshot on first Smart trigger
   - If fails, guide user to System Settings (no blocking dialogs)
   - Avoid `CGRequestScreenCaptureAccess()` entirely in async flow

2. **Debounce Strategy**: "Cancel previous, start new"
   - If analysis in progress, cancel it immediately
   - Start fresh analysis with latest context
   - Use `Task` cancellation API

3. **Version Support**: "macOS 26.0+ only (recommended)"
   - Remove all `@available` checks (project already requires 26.0+)
   - Leverage latest compiler improvements
   - Simplify code paths

---

## Core Architectural Changes

### 1. **Permission Model: Try-First, Guide-Later**

**Old (Crash-Prone)**:
```swift
// ❌ Blocking call in async context
Task {
    if !checkPermission() {
        CGRequestScreenCaptureAccess()  // 💥 Deadlock
    }
    let image = try await capture()
}
```

**New (Safe)**:
```swift
// ✅ Non-blocking, fail-fast
Task {
    do {
        let image = try await capture()  // Try directly
    } catch {
        // Show guidance UI (non-blocking)
        await showPermissionGuide()
    }
}
```

**Key Principle**: Never call `CGRequestScreenCaptureAccess()` in async context.

---

### 2. **Hotkey Integration: Single-Threaded Trigger**

**Old (Crash-Prone)**:
```swift
// ❌ Callback creates new async context
HotKeyManager.shared.registerSmartHotKey { [weak self] in
    self?.triggerSmartRecommendation()  // New Task created
}

@available(macOS 14.0, *)  // ❌ Not enforced in callback
func triggerSmartRecommendation() {
    Task { @MainActor in ...}
}
```

**New (Safe)**:
```swift
// ✅ Direct @MainActor method, no version checks
HotKeyManager.shared.registerSmartHotKey { @MainActor in
    Task {
        await SmartCoordinator.shared.handleTrigger()
    }
}

@MainActor
class SmartCoordinator {
    private var currentTask: Task<Void, Never>?

    func handleTrigger() async {
        // Cancel previous task
        currentTask?.cancel()

        // Start new task
        currentTask = Task {
            await performAnalysis()
        }
        await currentTask?.value
    }
}
```

**Key Principle**: Use `@MainActor` coordinator to manage task lifecycle.

---

### 3. **Window Management: Single Window Instance**

**Old (Crash-Prone)**:
```swift
// ❌ Multiple instances possible
private var smartLoadingWindow: NSWindow?

func showLoadingWindow() {
    let window = NSWindow(...)  // New instance
    smartLoadingWindow = window
}
```

**New (Safe)**:
```swift
// ✅ Actor-protected singleton
@MainActor
class SmartWindowManager {
    static let shared = SmartWindowManager()

    private var activeWindow: NSWindow?

    func show(_ content: SmartWindowContent) {
        // Close existing window first
        activeWindow?.close()

        // Create new window
        activeWindow = createWindow(content)
        activeWindow?.makeKeyAndOrderFront(nil)
    }
}

enum SmartWindowContent {
    case loading
    case recommendation(SmartRecommendation)
    case error(SmartError)
}
```

**Key Principle**: Single window instance, enum-based content switching.

---

## Implementation Plan

### Phase 1: Core Infrastructure (Safe Foundation)

**Goal**: Rebuild ScreenCaptureManager and permission flow without crashes.

**New Components**:

1. **ScreenCaptureManager** (Simplified)
   ```swift
   @MainActor
   class ScreenCaptureManager {
       // NO permission request methods
       // ONLY capture methods that throw on permission error

       func captureCurrentWindow() async throws -> CGImage {
           // Direct capture, let ScreenCaptureKit handle permission
           let content = try await SCShareableContent.excludingDesktopWindows(...)
           // ...
       }
   }
   ```

2. **SmartCoordinator** (Task Orchestrator)
   ```swift
   @MainActor
   class SmartCoordinator {
       private var currentTask: Task<Void, Never>?

       func handleTrigger() async {
           currentTask?.cancel()
           currentTask = Task {
               await performFullFlow()
           }
       }

       private func performFullFlow() async {
           // 1. Show loading
           // 2. Collect context
           // 3. Call AI
           // 4. Show result or error
       }
   }
   ```

3. **SmartWindowManager** (Single Window)
   ```swift
   @MainActor
   class SmartWindowManager {
       func show(_ content: SmartWindowContent) {
           // Replace current window with new content
       }
   }
   ```

**Success Criteria**:
- No crashes when triggering hotkey rapidly
- No blocking permission dialogs
- Clean task cancellation

---

### Phase 2: AI Integration

**Goal**: Connect to AIService with timeout and error handling.

**Changes**:
- Add `AIService.recommendTool(context:tools:)` method
- Use `withTimeout()` wrapper for 10s limit
- Handle all error cases gracefully

---

### Phase 3: UX Polish

**Goal**: Liquid Glass UI and animations.

**Changes**:
- Apply `.glassEffect(.regular)` to windows
- Add loading/error/success states
- Permission guide UI (static view, no buttons that trigger permission requests)

---

## Risk Mitigation

| Previous Risk | Mitigation |
|--------------|------------|
| CGRequestScreenCaptureAccess crash | **Removed entirely** - only use direct capture |
| @available conflicts | **No version checks** - macOS 26.0+ only |
| Multiple windows | **Single window instance** - actor-protected |
| Rapid triggers | **Task cancellation** - cancel previous before starting new |
| Permission confusion | **Clear guide UI** - explain manual steps, no auto-request |

---

## Open Questions

1. **Lightweight Mode**: Should we offer a "no screenshot" mode by default?
   - **Proposal**: Add toggle in Settings, default OFF (try screenshot first)

2. **Permission Guide**: What if user never grants permission?
   - **Proposal**: Fall back to text-only analysis, show persistent banner

3. **Error Recovery**: Should we retry on transient errors?
   - **Proposal**: No auto-retry, show "Try Again" button instead

---

## Validation Checklist

- [ ] No `CGRequestScreenCaptureAccess()` calls in async context
- [ ] No `@available` checks (project is macOS 26.0+)
- [ ] Single `@MainActor` coordinator for task management
- [ ] Single window instance with content enum
- [ ] Task cancellation on rapid triggers
- [ ] No blocking calls in hotkey callback
- [ ] All errors result in UI feedback, not crashes

---

**Document Version**: v2.0
**Date**: 2026-01-22
**Status**: Proposal - Awaiting OpenSpec validation
