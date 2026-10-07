# Tasks: add-smart-context-aware-tools

## Phase 1: MVP Implementation

### 1. Screen Capture Infrastructure
- [x] Create `ScreenCaptureManager.swift` singleton
- [x] Implement permission check (`CGPreflightScreenCaptureAccess`)
- [x] Implement `captureCurrentWindow()` using SCScreenshotManager
- [x] Implement `captureFullScreen()` fallback
- [x] Add `imageToBase64()` helper (JPEG compression, quality 0.7)
- [x] Add `NSScreenCaptureDescription` to Info.plist
- [x] Test: Verify permission flow works
- [x] Test: Capture returns valid CGImage

### 2. Context Collection
- [x] Create `SmartContext.swift` model with fields: app name, bundle ID, clipboard text, clipboard has image, screenshot
- [x] Create context collection logic in `SmartToolManager`
- [x] Use `NSWorkspace.shared.frontmostApplication` for active app
- [x] Read clipboard via `NSPasteboard.general`
- [x] Call `ScreenCaptureManager` for screenshot
- [x] Test: Print collected context, verify completeness

### 3. AI Service Extension
- [x] Add `SmartRecommendation.swift` model (toolID, toolName, reason, confidence)
- [x] Extend `AIService` with `recommendTool(context:availableTools:)` method
- [x] Build multimodal prompt (system + user message + image)
- [x] Serialize available tools to JSON
- [x] Parse AI response JSON into `SmartRecommendation`
- [x] Add error handling (timeout, parse errors)
- [x] Test: Mock context returns valid recommendation

### 4. Smart Tool Manager
- [x] Create `SmartToolManager.swift` singleton
- [x] Implement `analyzeCurrentContext()` orchestration method
- [x] Add error states: no permission, no AI config, empty context
- [x] Integrate `NotificationService` for loading/error messages (using Alert for MVP)
- [x] Add 10-second timeout for AI call
- [x] Test: End-to-end flow (context → AI → recommendation)

### 5. Hotkey Registration
- [x] Add Smart hotkey to `HotKeyManager` (Cmd+Ctrl+V default)
- [ ] Add UserDefaults keys: `smartHotkeyEnabled`, `smartHotkeyCode`, `smartHotkeyModifiers`
- [x] Register callback to trigger `SmartToolManager.analyzeCurrentContext()`
- [x] Add conflict detection with existing hotkeys
- [x] Test: Press Cmd+Ctrl+V triggers analysis

### 6. Basic Confirmation UI
- [x] Create `SmartRecommendationView.swift` (SwiftUI Alert or simple window)
- [x] Display: tool name, reason, [Execute] / [Cancel] buttons
- [x] Handle Enter key → execute tool
- [x] Handle Esc key → cancel
- [x] On execute: call `PromptToolManager.shared.executeTool(toolID)`
- [x] Test: Recommendation shows, Execute runs tool correctly

## Phase 2: UX Polish

### 7. Liquid Glass Recommendation Window
- [ ] Create `SmartRecommendationWindowManager.swift`
- [ ] Apply `.glassEffect(.regular)` background
- [ ] Center window on screen
- [ ] Add 0.3s fade-in animation (`.smooth`)
- [ ] Auto-dismiss after 10s if no interaction
- [ ] Test: Visual consistency with main window

### 8. Loading & Error States
- [ ] Show loading animation during AI analysis
- [ ] Display timeout message if >10s
- [ ] Handle permission denied → show guide button
- [ ] Handle AI service not configured → link to settings
- [ ] Handle empty clipboard → clear message
- [ ] Test: All error paths display correct UI

### 9. Permission Guide UI
- [ ] Create `PermissionGuideView.swift`
- [ ] Explain why permission is needed
- [ ] Add "Open System Settings" button (`NSWorkspace.open(URL)`)
- [ ] Add "Use Lightweight Mode" fallback option
- [ ] Test: Guide appears when permission missing

### 10. Settings Integration
- [ ] Add "Smart Tool Selection" section to Settings
- [ ] Toggle: Enable/Disable Smart feature
- [ ] Hotkey recorder for Smart hotkey
- [ ] Dropdown: Screenshot mode (Window / Full Screen / Disabled)
- [ ] Permission status indicator + guide button
- [ ] Test: Settings changes take effect immediately

## Phase 3: Advanced Features (Future)

### 11. Lightweight Mode
- [ ] Add `smartLightweightMode` UserDefaults flag
- [ ] Skip screenshot if lightweight mode enabled
- [ ] Optimize prompt for text-only context
- [ ] Test: Works without Screen Recording permission

### 12. Recommendation History
- [ ] Create `smart_recommendations` database table
- [ ] Log: timestamp, context summary, recommended tool, user accepted
- [ ] Add history view in Settings
- [ ] Calculate acceptance rate metric
- [ ] Test: History persists and displays correctly

### 13. User Feedback Collection
- [ ] Add "Not Accurate" button to confirmation UI
- [ ] Show all tools list on click
- [ ] Log user correction (recommended X → chose Y)
- [ ] Export feedback data for prompt iteration
- [ ] Test: Feedback recorded correctly

### 14. Custom Recommendation Prompt
- [ ] Add "Advanced" section in Settings
- [ ] Editable text area for custom system prompt
- [ ] Template variables: {app_name}, {clipboard}, {tools_json}
- [ ] Validate prompt before saving
- [ ] Test: Custom prompt generates valid recommendations

## Validation

### Testing
- [ ] Unit test: `ScreenCaptureManager` permission checks
- [ ] Unit test: `SmartContext` JSON serialization
- [ ] Unit test: `SmartRecommendation` parsing
- [ ] Integration test: Full flow (trigger → recommend → execute)
- [ ] Performance test: Screenshot capture <2s
- [ ] Performance test: AI recommendation <10s (p95)
- [ ] Performance test: Memory usage <20MB during analysis

### Documentation
- [ ] Update `docs/SPEC.md` with Smart feature section
- [ ] Update `docs/TODO.md` mark completed tasks
- [ ] Add `docs/SMART_FEATURE.md` detailed guide
- [ ] Update README.md feature list

### Release Readiness
- [ ] All Phase 1 tasks complete
- [ ] All Phase 2 tasks complete
- [ ] No critical bugs
- [ ] Performance targets met
- [ ] Documentation updated
- [ ] User onboarding flow tested
