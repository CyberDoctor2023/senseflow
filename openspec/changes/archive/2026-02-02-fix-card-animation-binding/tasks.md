# Tasks: Fix Card Animation Binding

## Implementation Tasks

- [x] **Separate entrance and hover animations in ClipboardCardView**
  - Read `SenseFlow/Views/ClipboardCardView.swift`
  - Replace lines 74-76 with nested animation bindings
  - Entrance: `.scaleEffect(appeared ? 1.0 : 0.9)` + `.opacity()` + `.animation(..., value: appeared)`
  - Hover: `.scaleEffect(isHovered ? 1.05 : 1.0)` + `.animation(..., value: isHovered)`
  - Remove nested ternary in scaleEffect (separate concerns)
  - Verify delete button animation (line 109) remains unchanged

## Validation Tasks

- [x] **Build verification**
  - Run `xcodebuild -project SenseFlow.xcodeproj -scheme SenseFlow build`
  - Verify no compilation errors

- [x] **Visual testing**
  - Launch app and open floating window (Cmd+Shift+V)
  - Observe card entrance animations (should scale 0.9→1.0 with bounce)
  - Hover over cards during entrance (both animations should work independently)
  - Verify hover scale (1.0→1.05) is smooth
  - Check delete button appears/disappears on hover

- [x] **Performance testing**
  - Run `/perf-test` to verify 60fps animation performance
  - Check CPU usage during card animations (should remain <0.5%)

## Documentation Tasks

- [x] **Update animation standards**
  - Verify `.claude/skills/animation-standards.md` matches implementation
  - Card entrance: 0.5s + 0.15 extraBounce
  - Card hover: 0.25s + 0.0 extraBounce

- [x] **Git commit**
  - Stage changes: `git add SenseFlow/Views/ClipboardCardView.swift`
  - Commit: `fix(animation): separate card entrance and hover animation bindings`
  - Include Co-Authored-By tag

## Dependencies

- None (isolated change to single view file)

## Estimated Duration

- Implementation: 10 minutes
- Testing: 5 minutes
- Total: 15 minutes
