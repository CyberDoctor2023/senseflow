# PhaseAnimator Implementation Plan

## API Research Summary

**Source**: Apple Documentation (docs/refs.md:763-771)
- **Official Docs**: https://developer.apple.com/documentation/swiftui/phaseanimator
- **Availability**: iOS 17.0+, macOS 14.0+ (project requires macOS 26.0+, so compatible)

### PhaseAnimator Basics

**Concept**: Declarative multi-phase animation system
- Define phases as an array: `[initial, active]`
- System automatically transitions between phases
- No manual state management or delays needed

**API Pattern**:
```swift
.phaseAnimator([Phase1, Phase2, ...]) { content, phase in
    content
        .modifier1(phase-dependent-value)
        .modifier2(phase-dependent-value)
} animation: { phase in
    .animationType(parameters)
}
```

## Current Implementation Analysis

**File**: ClipboardCardView.swift:74-88

**Current Approach** (Outdated):
```swift
@State private var appeared = false

.scaleEffect(appeared ? 1.0 : 0.9)
.opacity(appeared ? 1.0 : 0)
.animation(.snappy(duration: 0.5, extraBounce: 0.15), value: appeared)

.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.snappy(duration: 0.5, extraBounce: 0.15)) {
            appeared = true
        }
    }
}
```

**Issues**:
1. Manual state management (`@State var appeared`)
2. Fragile delay with `DispatchQueue.main.asyncAfter`
3. Redundant animation specification (both `.animation()` and `withAnimation`)
4. Cannot easily add more phases

## Migration Plan

### Phase Definition

**Two Phases**:
1. `false` (initial): scale 0.9, opacity 0.0
2. `true` (active): scale 1.0, opacity 1.0

### New Implementation

```swift
// Remove @State var appeared

.phaseAnimator([false, true]) { content, phase in
    content
        .scaleEffect(phase ? 1.0 : 0.9)
        .opacity(phase ? 1.0 : 0)
} animation: { phase in
    .snappy(duration: 0.5, extraBounce: 0.15)
}
```

**Benefits**:
- No manual state management
- No manual delays (system handles timing)
- Declarative and clear
- Easy to add more phases if needed
- Better performance (system-optimized)

### Hover Animation (Keep Unchanged)

**Current hover implementation** (lines 79-80):
```swift
.scaleEffect(isHovered ? 1.05 : 1.0)
.animation(.snappy(duration: 0.25, extraBounce: 0.0), value: isHovered)
```

**Decision**: Keep as-is
- Simple boolean toggle, `.animation()` is appropriate
- No benefit from PhaseAnimator for single-state toggle
- Hover needs to be independent of entrance animation

### Animation Timing Preservation

**Critical**: Keep exact same parameters
- Duration: 0.5 seconds
- Animation type: `.snappy`
- Extra bounce: 0.15
- Scale range: 0.9 → 1.0
- Opacity range: 0.0 → 1.0

This ensures the animation feels identical to users.

## Implementation Plan Documented: ✅
