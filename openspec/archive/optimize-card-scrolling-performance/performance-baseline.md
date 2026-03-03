# Performance Baseline

## Current Implementation (HStack)

**Date**: 2026-01-30
**Code Location**: ClipboardListView.swift:112-124

### Expected Behavior (Based on Apple Documentation)

**HStack Characteristics**:
- Loads ALL child views immediately on render
- With 200 items: 200 ClipboardCardView instances created at once
- Each card triggers: onAppear, entrance animation, image loading
- Estimated initial load: 200 views × ~50ms = 10,000ms worst case

**Memory Usage**:
- 200 card views in memory simultaneously
- Each card: ~100KB (view hierarchy + image data)
- Total: ~20MB for card views alone

**Animation Overhead**:
- All 200 cards trigger entrance animation simultaneously
- Stagger implemented via index-based delay
- High CPU usage during initial render

### Expected Issues
- Slow panel opening (>1 second with 200 items)
- High memory usage
- Potential frame drops during initial animation burst

## Expected Improvement (LazyHStack)

**LazyHStack Characteristics**:
- On-demand rendering: only visible views created
- Panel width ~1400pt, card width 180pt + 12pt spacing = ~7-8 visible cards
- Initial load: ~10 views (including buffer)
- 95% reduction in initial view count (200 → 10)

**Expected Metrics**:
- Initial load time: <200ms (50%+ improvement)
- Memory usage: ~2MB (90% reduction)
- Scrolling: 60fps maintained
- Natural animation stagger (views appear as scrolled)

## Validation Method

Since we don't have automated Instruments profiling in this workflow:
1. Manual testing with various item counts (1, 10, 50, 200)
2. Observe panel open responsiveness
3. Check scrolling smoothness
4. Monitor Activity Monitor for memory usage

## Baseline Documented: ✅
