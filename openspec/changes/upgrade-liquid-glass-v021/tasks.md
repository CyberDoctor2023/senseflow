## 1. Main Panel Updates
- [ ] 1.1 Modify FloatingWindowManager to set panel height to 280pt (from 300pt)
- [ ] 1.2 Modify FloatingWindowManager to set corner radius to 20pt (from 12pt)
- [ ] 1.3 Update panel background to SwiftUI `.glassEffect(.regular)` (macOS 26+) with `.background(.ultraThinMaterial)` fallback
- [ ] 1.4 Add 12pt invisible top padding to panel content
- [ ] 1.5 Add 16pt horizontal padding (left/right) to panel content
- [ ] 1.6 Update panel show animation to `.snappy(duration: 0.4, extraBounce: 0.0)`
- [ ] 1.7 Update panel hide animation to `.smooth(duration: 0.3, extraBounce: 0.0)`

## 2. Search Bar Updates
- [ ] 2.1 Replace single divider line with dual-line gradient (0.5pt white 8% + 0.5pt black 12%)
- [ ] 2.2 Update search field background to 6% white semi-transparent
- [ ] 2.3 Set search field corner radius to 8pt
- [ ] 2.4 Apply vertical spacing: 12pt top + 8pt bottom

## 3. Card Visual Updates
- [ ] 3.1 Change card dimensions from 160×200pt to 180×180pt (square aspect ratio)
- [ ] 3.2 Update card corner radius to 20pt (from 10pt)
- [ ] 3.3 Change card background to SwiftUI `.glassEffect(.clear)` (macOS 26+) with `.background(.thinMaterial)` fallback
- [ ] 3.4 Update shadow to system-level subtle (y-offset 2pt, blur 8pt, 10% black opacity)
- [ ] 3.5 Reduce color stripe height to 3pt (from 4pt)
- [ ] 3.6 Increase text preview lines to 4-5 (from 3)
- [ ] 3.7 Remove separate app icon + app name layout
- [ ] 3.8 Add unified metadata bar at bottom (icon 14pt + name + timestamp, 8pt L/R padding)

## 4. Animation Refinements
- [ ] 4.1 Update card entrance animation to `.snappy(duration: 0.5, extraBounce: 0.15)` (lively with subtle bounce)
- [ ] 4.2 Change card scale-in from 0.8x → 0.9x start value
- [ ] 4.3 Verify all animation timing changes applied (panel 0.4s/0.3s)

## 5. Settings Window Restructure
- [ ] 5.1 Replace TabView with NavigationSplitView (sidebar + detail)
- [ ] 5.2 Set window background to SwiftUI `.glassEffect(.regular)` (macOS 26+) with `.background(.ultraThinMaterial)` fallback
- [ ] 5.3 Create sidebar view (200pt fixed width)
- [ ] 5.4 Add sidebar navigation items with SF Symbols:
  - [ ] 5.4.1 General (gear icon)
  - [ ] 5.4.2 Shortcuts (keyboard icon)
  - [ ] 5.4.3 Privacy (lock icon)
  - [ ] 5.4.4 Advanced (wrench icon)
- [ ] 5.5 Implement sidebar hover states (background highlight)
- [ ] 5.6 Create detail pane container (min 500pt width)
- [ ] 5.7 Refactor GeneralSettingsView to card-based layout
- [ ] 5.8 Refactor ShortcutSettingsView to card-based layout
- [ ] 5.9 Refactor PrivacySettingsView to card-based layout
- [ ] 5.10 Create AdvancedSettingsView with "Reset to Defaults" option
- [ ] 5.11 Apply module card styling: SwiftUI `.glassEffect(.clear)` (macOS 26+) with `.background(.thinMaterial)` fallback + 16pt padding + 12pt corner radius

## 6. Testing & Validation
- [ ] 6.1 Test on macOS 26+ (Liquid Glass effects via `.glassEffect()`)
- [ ] 6.2 Test on macOS 12-25 (fallback to `.background(.material)`)
- [ ] 6.3 Verify panel dimensions and spacing
- [ ] 6.4 Verify card square aspect ratio and layout
- [ ] 6.5 Verify search divider dual-line gradient
- [ ] 6.6 Verify settings sidebar navigation works
- [ ] 6.7 Verify all settings options remain accessible
- [ ] 6.8 Verify animation timing feels "snappier"
- [ ] 6.9 Verify no visual regressions

## 7. Documentation Updates
- [ ] 7.1 Update CLAUDE.md with v0.2.1 changes
- [ ] 7.2 Update README.md version and screenshots
- [ ] 7.3 Document settings layout migration (TabView → Sidebar)
- [ ] 7.4 Update UI specification values in project docs
