# Design: Card Animation Separation

## Current Architecture

```swift
// ClipboardCardView.swift:74-84
.scaleEffect(appeared ? (isHovered ? 1.05 : 1.0) : 0.9)
.opacity(appeared ? 1.0 : 0)
.animation(.snappy(duration: 0.25, extraBounce: 0.0), value: isHovered)
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.snappy(duration: 0.5, extraBounce: 0.15)) {
            appeared = true
        }
    }
}
```

**Problem**: The `.animation(value: isHovered)` binding applies to ALL preceding modifiers, including `.opacity` which depends on `appeared`, not `isHovered`.

## Proposed Architecture

### Option A: Nested scaleEffect (Recommended)

```swift
.scaleEffect(appeared ? 1.0 : 0.9)           // Entrance scale
.opacity(appeared ? 1.0 : 0)                 // Entrance fade
.animation(.snappy(duration: 0.5, extraBounce: 0.15), value: appeared)
.scaleEffect(isHovered ? 1.05 : 1.0)         // Hover scale (multiplicative)
.animation(.snappy(duration: 0.25, extraBounce: 0.0), value: isHovered)
```

**Rationale**:
- Each `.animation()` only affects modifiers between it and the previous `.animation()`
- Two `scaleEffect` modifiers multiply: entrance (0.9→1.0) × hover (1.0→1.05)
- Clear separation of concerns

### Option B: Transaction-based (Alternative)

Use `withAnimation` for both entrance and hover, remove `.animation()` binding entirely.

**Rejected because**:
- Requires moving hover logic into explicit `withAnimation` calls
- Less declarative than Option A
- More verbose

## Animation Timeline

```
Time 0s:       Card appears (appeared = false)
               - scale: 0.9, opacity: 0

Time 0.1s:     Entrance animation starts
               - withAnimation(.snappy(0.5s, bounce: 0.15))

Time 0.6s:     Entrance complete (appeared = true)
               - scale: 1.0, opacity: 1.0

User hovers:   Hover animation triggers
               - .animation(..., value: isHovered)
               - scale: 1.0 × 1.05 = 1.05
```

## Implementation Impact

**Files to modify**:
- `SenseFlow/Views/ClipboardCardView.swift` (lines 74-76)

**No spec changes required**: This is a bug fix aligning implementation with existing requirements in `ui-animations/spec.md`.

## Testing Strategy

1. **Visual test**: Open floating window, observe cards entering
2. **Hover test**: Hover over card during entrance animation
3. **Delete button test**: Verify delete button still animates correctly (separate binding on line 109)
4. **Performance**: Run with Instruments to confirm 60fps

## Alternatives Considered

### Alt 1: Single animation binding with transaction
- **Pro**: Simpler modifier chain
- **Con**: Loses declarative value-binding clarity

### Alt 2: Separate views for entrance/hover states
- **Pro**: Complete isolation
- **Con**: Unnecessary complexity for this use case
