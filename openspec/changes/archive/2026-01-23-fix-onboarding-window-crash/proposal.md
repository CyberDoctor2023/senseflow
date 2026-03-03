# Proposal: Fix Onboarding Window Crash

## Change ID
`fix-onboarding-window-crash`

## Problem Statement

The onboarding wizard (`OnboardingViewController`) has two critical issues preventing normal usage:

1. **EXC_BAD_ACCESS crash when closing**: Clicking "继续" (Continue) or "跳过" (Skip) buttons causes immediate application crash with `Thread 1: EXC_BAD_ACCESS (code=1, address=0x14c710a1f778)`

2. **Delayed and unclear permission status feedback**:
   - Permission checkboxes take 1+ seconds to update after user grants permissions
   - Blue checkmark icon doesn't clearly indicate "granted" state (green is industry standard)
   - Users are left uncertain whether permissions were actually granted

## Current Behavior

**File**: `SenseFlow/Views/OnboardingViewController.swift`

**Crash location** (lines 209-217, 219-228):
```swift
@objc private func continueButtonClicked() {
    guard let window = view.window else { return }
    window.close()  // ← CRASH HERE
}

@objc private func skipButtonClicked() {
    UserDefaults.standard.set(true, forKey: "skipOnboardingPermissions")
    guard let window = view.window else { return }
    window.close()  // ← CRASH HERE
}
```

**Permission check delays** (lines 142-156):
- Accessibility: 1.0s delay after request
- Screen recording: 1.0s delay after request
- Notification: async check, no explicit delay
- Checkboxes use default NSButton appearance (blue when `.on`)

## Root Cause

### Crash
Calling `window.close()` synchronously during button action handling violates AppKit's event loop expectations. The window is deallocated while still processing the button event, causing memory access violation.

### UI Issues
1. System permission APIs don't immediately reflect state changes - need longer polling delays
2. Blue checkbox is macOS default, but green is universal "granted/allowed" indicator
3. No visual feedback during permission request (user doesn't know if button worked)

## Proposed Solution

### 1. Deferred Window Close (fixes crash)
Defer window closing to next run loop iteration using `DispatchQueue.main.async`:
```swift
DispatchQueue.main.async {
    window.close()
}
```

### 2. Longer Permission Check Delays
- Accessibility: 1.0s → 2.0s delay
- Screen recording: 1.0s → 2.0s delay
- Allows system state to propagate before UI refresh

### 3. Green Checkmark for Granted Status
Replace checkbox state indicators:
- **Granted** (`.on`): Green `checkmark.circle.fill` icon
- **Not granted** (`.off`): Orange `exclamationmark.triangle.fill` icon
- Keep checkboxes disabled (read-only status indicator)

## Affected Components

**Modified**:
- `SenseFlow/Views/OnboardingViewController.swift`
  - `continueButtonClicked()`
  - `skipButtonClicked()`
  - `requestAccessibility()` delay timing
  - `requestScreenRecording()` delay timing
  - Checkbox appearance (if using custom view instead of NSButton)

**No spec changes required** - this is a bug fix restoring intended behavior.

## Success Criteria

- ✅ No `EXC_BAD_ACCESS` crashes when clicking Continue/Skip
- ✅ Window closes smoothly with fade animation
- ✅ Permission status updates within 2 seconds of granting
- ✅ Green checkmark clearly indicates granted permissions
- ✅ Orange warning icon clearly indicates missing permissions

## Testing Plan

1. **Crash test**: Launch app → onboarding appears → click "继续" → verify no crash
2. **Crash test**: Launch app → onboarding appears → click "跳过" → verify no crash
3. **Permission UI test**: Click "授权" for accessibility → system dialog appears → grant → verify green checkmark within 2s
4. **Permission UI test**: Click "授权" for screen recording → system dialog appears → grant → verify green checkmark within 2s
5. **Permission UI test**: Click "授权" for notification → grant → verify green checkmark within 2s
6. **Visual test**: Verify green icons are visually distinct from orange icons

## Dependencies

None - isolated bug fix in single file.

## Risks

**Low risk** - changes are minimal and localized:
- Deferred `window.close()` is standard AppKit pattern
- Longer delays only affect onboarding (not performance-critical)
- Icon changes are cosmetic

## Rollback Plan

Revert commits if:
- Crashes persist
- Window doesn't close properly
- Permission checks time out

Changes are self-contained in one file, easy to revert.

## Open Questions

None - solution is straightforward bug fix.
