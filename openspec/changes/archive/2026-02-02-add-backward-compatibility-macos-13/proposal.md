# Change: Add Backward Compatibility for macOS 13+

## Why
Current app requires macOS 26.0+, excluding users on macOS 13-25 (Ventura through Sequoia). Core functionality doesn't require macOS 26 features - only visual effects (Liquid Glass) and animations (PhaseAnimator) are version-specific. Extending support to macOS 13+ significantly increases potential user base without sacrificing functionality.

## What Changes
- Create compatibility wrappers for version-specific APIs (`.glassEffect()` → `.thinMaterial`, `PhaseAnimator` → `.animation()`)
- Update deployment target from macOS 26.0 to macOS 13.0
- Modify UI components to use compatibility wrappers instead of direct API calls
- Add `if #available` checks for graceful degradation
- Update documentation to reflect macOS 13.0+ support
- Test on macOS 13, 14, 15, and 26 to ensure consistent behavior

## Impact
- **Affected specs**: ui-main-panel, ui-cards, ui-animations, ui-settings
- **Affected code**:
  - `ClipboardCardView.swift` - Replace `.glassEffect()` and `PhaseAnimator`
  - `FloatingWindowManager.swift` - Replace `.glassEffect()`
  - `ClipboardListView.swift` - Replace panel background effects
  - New files: `ViewModifiers+Compatibility.swift`, `CompatiblePhaseAnimator.swift`
- **Build configuration**: Xcode deployment target, Info.plist minimum version
- **Testing**: Requires VMs for macOS 13-15 testing
- **Documentation**: SPEC.md, README.md, new COMPATIBILITY.md guide

## Scope

### In Scope

1. **API Compatibility Wrappers**
   - GlassEffectModifier: `.glassEffect()` (26+) → `.thinMaterial` (13-25)
   - PhaseAnimatorWrapper: `PhaseAnimator` (14+) → `.animation()` (13)
   - Maintain existing NavigationSplitView (already 13+ compatible)

2. **Affected UI Components**
   - Main panel background (Liquid Glass → thin material)
   - Card backgrounds (Liquid Glass → thin material)
   - Card entrance animations (PhaseAnimator → .animation())
   - Settings window (already compatible)

3. **Build Configuration**
   - Update deployment target to macOS 13.0
   - Update Info.plist minimum version
   - Verify all dependencies support macOS 13+

4. **Testing**
   - Test on macOS 13 (Ventura)
   - Test on macOS 14 (Sonoma)
   - Test on macOS 15 (Sequoia)
   - Test on macOS 26 (Tahoe)

### Out of Scope
- macOS 12 and earlier (Settings Scene requires 13+)
- iOS/iPadOS support
- Feature parity with macOS 26 exclusive APIs
- Performance optimization for older hardware

## Design Approach

### Architecture Pattern: Wrapper Views

**Principle**: Use `if #available` to conditionally render modern or legacy implementations.

**Example 1: Glass Effect Modifier**
```swift
extension View {
    @ViewBuilder
    func compatibleGlassEffect() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular)
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
```

**Example 2: Phase Animator Wrapper**
```swift
struct CompatiblePhaseAnimator<Content: View>: View {
    let phases: [Bool]
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        if #available(macOS 14, *) {
            PhaseAnimator(phases) { phase in
                content(phase)
            }
        } else {
            // Fallback to simple .animation()
            content(true)
                .animation(.snappy(duration: 0.5), value: true)
        }
    }
}
```

### Key Components

1. **ViewModifiers+Compatibility.swift** (new)
   - `compatibleGlassEffect()` modifier
   - `compatibleMaterial(_:)` modifier
   - Centralized compatibility layer

2. **CompatiblePhaseAnimator.swift** (new)
   - Generic wrapper for PhaseAnimator
   - Fallback to .animation() on macOS 13

3. **ClipboardCardView.swift** (modify)
   - Replace `.glassEffect()` with `.compatibleGlassEffect()`
   - Replace `PhaseAnimator` with `CompatiblePhaseAnimator`

4. **FloatingWindowManager.swift** (modify)
   - Replace `.glassEffect()` with `.compatibleGlassEffect()`
   - Update material selection logic

### API Compatibility Matrix

| Feature | macOS 13 | macOS 14-25 | macOS 26+ |
|---------|----------|-------------|-----------|
| Glass Effect | .thinMaterial | .thinMaterial | .glassEffect() |
| Card Animation | .animation() | PhaseAnimator | PhaseAnimator |
| Navigation | NavigationSplitView | NavigationSplitView | NavigationSplitView |
| Settings | Settings Scene | Settings Scene | Settings Scene |

### Visual Differences by Version

**macOS 26+**:
- Liquid Glass with dynamic blur
- PhaseAnimator smooth entrance

**macOS 14-25**:
- Thin material (static blur)
- PhaseAnimator smooth entrance

**macOS 13**:
- Thin material (static blur)
- Simple .animation() entrance

## Migration Path

### Phase 1: Create Compatibility Layer (Week 1)
1. Create `ViewModifiers+Compatibility.swift`
2. Create `CompatiblePhaseAnimator.swift`
3. Write unit tests for wrappers
4. Update deployment target to 13.0

### Phase 2: Migrate UI Components (Week 2)
1. Update ClipboardCardView
2. Update FloatingWindowManager
3. Update main panel background
4. Verify visual consistency

### Phase 3: Testing & Validation (Week 3)
1. Test on macOS 13 VM
2. Test on macOS 14 VM
3. Test on macOS 15 VM
4. Test on macOS 26 (current)
5. Performance profiling on older versions

### Phase 4: Documentation & Release (Week 4)
1. Update SPEC.md minimum version
2. Update README system requirements
3. Create migration guide
4. Release notes

## Success Criteria

1. **Functional**
   - App launches and runs on macOS 13.0+
   - All core features work on macOS 13
   - No crashes or API unavailability errors
   - Visual degradation is acceptable

2. **Performance**
   - No performance regression on macOS 26
   - Acceptable performance on macOS 13 (60fps animations)
   - Memory usage within limits on older systems

3. **Code Quality**
   - No code duplication
   - Clear separation of compatibility logic
   - Easy to maintain and extend
   - Well-documented availability checks

## Risks & Mitigations

### Risk: Performance on Older Hardware
- **Mitigation**: Profile on macOS 13, optimize if needed, consider reduced animation complexity

### Risk: Visual Inconsistency
- **Mitigation**: Design review for fallback materials, ensure brand consistency

### Risk: Testing Coverage
- **Mitigation**: Set up VMs for macOS 13-15, automated testing on multiple versions

### Risk: Dependency Compatibility
- **Mitigation**: Verify SQLite.swift and other dependencies support macOS 13

## Open Questions

1. **Should we support macOS 12?** - No, Settings Scene requires 13+
2. **Performance targets for macOS 13?** - Same as 26 (60fps, <0.1% CPU)
3. **Visual design approval for fallbacks?** - Need design review
4. **Release strategy?** - Separate release or bundled with v0.5?

## Dependencies

- Existing UI components (ClipboardCardView, FloatingWindowManager)
- SwiftUI availability checks
- Xcode 14+ for macOS 13 deployment target

## Related Changes

- `upgrade-liquid-glass-v021` - Original Liquid Glass implementation
- `migrate-to-phase-animator` - PhaseAnimator migration
- Future: `optimize-performance-macos-13` - Performance tuning for older versions
