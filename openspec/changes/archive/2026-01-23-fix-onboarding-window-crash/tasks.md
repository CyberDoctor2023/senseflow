# Tasks: Fix Onboarding Window Crash

## Implementation Order

- [x] **Task 1**: Fix window close crash
  - Wrap `window.close()` in `DispatchQueue.main.async` for both `continueButtonClicked()` and `skipButtonClicked()`
  - **Validation**: Click Continue/Skip buttons → no crash
  - **Files**: `OnboardingViewController.swift` lines 209-228

- [x] **Task 2**: Increase permission check delays
  - Change `requestAccessibility()` delay from 1.0s → 2.0s
  - Change `requestScreenRecording()` Task completion delay from 1.0s → 2.0s
  - **Validation**: Grant permissions → checkboxes update within 2 seconds
  - **Files**: `OnboardingViewController.swift` lines 167, 185

- [x] **Task 3**: Replace checkbox icons with green/orange indicators
  - Change checkbox appearance: green `checkmark.circle.fill` when granted, orange `exclamationmark.triangle.fill` when not granted
  - Ensure icons are same size and visually aligned
  - **Validation**: Visual inspection → green clearly indicates granted state
  - **Files**: `OnboardingViewController.swift` setup and update methods

- [x] **Task 4**: Manual testing
  - Test all 3 permission flows (accessibility, screen recording, notification)
  - Test both Continue and Skip buttons
  - Verify no crashes, smooth animations, clear visual feedback
  - **Validation**: All scenarios pass without crashes or UI glitches

## Parallelization

Tasks 1-3 can be done in sequence (small changes, ~5 min each).
Task 4 is final validation.

## Dependencies

None - all changes within single file.
