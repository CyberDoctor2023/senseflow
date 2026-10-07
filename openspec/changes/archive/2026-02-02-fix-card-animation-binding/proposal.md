# Proposal: Fix Card Animation Binding

## Problem Statement

ClipboardCardView has conflicting animation bindings that cause unexpected visual behavior:

1. **Current issue**: Line 76 uses `.animation(..., value: isHovered)` but the modifiers depend on BOTH `appeared` and `isHovered` states
2. **Consequence**: Entrance animation (0.5s + bounce) and hover animation (0.25s) interfere with each other
3. **Root cause**: Mixing `withAnimation` (for entrance) and `.animation(value:)` (for hover) on the same property chain

**Code location**: `SenseFlow/Views/ClipboardCardView.swift:74-76`

```swift
.scaleEffect(appeared ? (isHovered ? 1.05 : 1.0) : 0.9)  // Depends on TWO states
.opacity(appeared ? 1.0 : 0)                              // Depends on appeared
.animation(.snappy(duration: 0.25, extraBounce: 0.0), value: isHovered)  // Only bound to isHovered
```

## Proposed Solution

Separate entrance and hover animations by binding them to their respective state variables:

- `.scaleEffect` + `.opacity` → bind to `appeared` (entrance)
- Additional `.scaleEffect` modifier → bind to `isHovered` (hover)

This aligns with SwiftUI best practices where each animation binding controls specific modifiers.

## Success Criteria

1. Card entrance animation plays smoothly (0.5s + 0.15 bounce)
2. Hover animation plays independently (0.25s scale to 1.05x)
3. No visual glitches when hovering during entrance
4. Delete button animation remains consistent

## Related Specs

- `ui-animations/spec.md` - Card Entrance Animation requirement
- `ui-animations/spec.md` - Card Hover Animation requirement

## Non-Goals

- Changing animation timing parameters (already compliant with `.claude/skills/animation-standards.md`)
- Modifying delete button behavior
- Altering card layout or styling
