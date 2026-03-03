# Proposal: Optimize Card Scrolling Performance

## Why

**Problem**: Clipboard history panel exhibits performance issues when displaying large numbers of cards (100-200 items).

**Root Cause - Eager Loading with HStack**:
- Current implementation uses `HStack` inside `ScrollView` (ClipboardListView.swift:113)
- `HStack` loads ALL child views immediately, even those off-screen
- With 200 items × complex card views = significant memory and CPU overhead
- Results in slow initial render, frame drops during scrolling, and poor responsiveness

**Apple Documentation Research** (docs/refs.md:755-762):
- **Official Guide**: "Creating performant scrollable stacks" (https://developer.apple.com/documentation/swiftui/creating-performant-scrollable-stacks)
- **Key Finding**: "Lazy stacks load and render their subviews on-demand, providing significant performance gains when loading large numbers of subviews"
- **Instruments Evidence**: Standard stacks load 1,000 views at once; lazy stacks load only 4 visible views initially
- **Apple Recommendation**: "Always start with a standard stack view and only switch to a lazy stack if profiling your code shows a worthwhile performance improvement"

**Current Implementation Issues**:
```swift
// ClipboardListView.swift:112-124
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {  // ❌ Loads all 200 cards immediately
        ForEach(viewModel.items) { item in
            ClipboardCardView(item: item) { ... }
        }
    }
}
```

**Secondary Issue - Outdated Animation API**:
- Uses `.animation(_:value:)` modifier (iOS 13 era)
- Manual delays with `DispatchQueue.main.asyncAfter` (fragile)
- No multi-phase animation support
- PhaseAnimator (iOS 17+/macOS 14+) offers better performance and control

**User Impact**:
- Slow panel opening when history is large (>50 items)
- Stuttering during horizontal scrolling
- High CPU usage during animations
- Poor perceived performance despite correct animation parameters

## What Changes

**Solution**: Replace `HStack` with `LazyHStack` for on-demand rendering, and migrate to `PhaseAnimator` for modern animation system.

### Architecture Changes

**Phase 1: Critical Performance Fix (LazyHStack)**
- Replace `HStack` with `LazyHStack` in ClipboardListView
- Maintain exact same layout and spacing (12pt)
- Add stable view identity with `.id()` modifier
- Verify with Instruments that only visible cards load

**Phase 2: Animation Modernization (PhaseAnimator)**
- Replace `.animation(_:value:)` with `PhaseAnimator` in ClipboardCardView
- Remove manual `DispatchQueue.main.asyncAfter` delays
- Use declarative phase-based animations
- Keep exact same timing parameters (.snappy, .smooth)

**Phase 3: Spec Alignment**
- Update ui-cards spec to reflect current 180×180pt dimensions
- Update ui-animations spec with PhaseAnimator requirements
- Document LazyHStack performance characteristics

### Minimal Scope

**Changed Files**:
- `SenseFlow/Views/ClipboardListView.swift` - HStack → LazyHStack (1 line change)
- `SenseFlow/Views/ClipboardCardView.swift` - Animation modernization (~20 lines)
- `openspec/specs/ui-cards/spec.md` - Update dimensions
- `openspec/specs/ui-animations/spec.md` - Add PhaseAnimator requirements

**Unchanged**:
- Window show/hide animations (NSPanel-based, not SwiftUI)
- Settings panel animations (simple, no benefit)
- Card layout, spacing, colors, materials
- Search functionality, deletion logic

### Success Criteria

**Performance**:
- Initial panel load time reduced by >50% (measured with Instruments)
- Scrolling maintains 60fps with 200 items
- Memory usage reduced (only visible cards in memory)
- CPU usage during animations <5%

**Functionality**:
- All existing animations preserved (same timing, same feel)
- No visual regressions
- Hover, click, delete interactions unchanged

**Code Quality**:
- Clearer animation code (declarative vs imperative)
- No manual timing delays
- Better maintainability

## Risks & Mitigation

**Risk**: LazyHStack layout differences from HStack
- **Mitigation**: LazyHStack has identical API; only rendering strategy differs
- **Validation**: Visual regression testing with 1, 10, 50, 200 items

**Risk**: PhaseAnimator learning curve
- **Mitigation**: Start with simple card entrance animation, validate before expanding
- **Fallback**: Keep `.animation()` for hover (simpler use case)

**Risk**: Breaking existing animation timing
- **Mitigation**: Keep exact same duration/spring parameters, only change mechanism
- **Validation**: Side-by-side comparison before/after

**Risk**: macOS version compatibility
- **Mitigation**: Project already requires macOS 26.0+ (project.md:85), PhaseAnimator available since macOS 14.0+

## Dependencies

**Blocks**: None (independent optimization)

**Blocked By**: None

**Related Changes**:
- `migrate-to-phase-animator` - Similar animation work, can merge learnings
- `upgrade-liquid-glass-v021` - Visual effects, no conflict

## Validation Plan

1. **Instruments Profiling**:
   - Capture SwiftUI View Body timeline before/after
   - Measure initial view count (expect 200 → ~10)
   - Verify 60fps during scrolling

2. **Manual Testing**:
   - Test with 1, 10, 50, 100, 200 items
   - Verify all animations feel identical
   - Check hover, click, delete interactions

3. **Performance Benchmarks**:
   - Panel open time: <200ms (target)
   - Scroll frame rate: 60fps sustained
   - Memory usage: <50MB for 200 items
