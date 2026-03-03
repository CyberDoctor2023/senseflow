# Change: Upgrade to macOS 26 Liquid Glass Design Language (v0.2.1)

## Why
Version 0.2 achieved basic usability, but the main interface and settings still use "application UI" patterns that don't align with macOS 26 (Tahoe 26)'s Liquid Glass design system. This upgrade unifies the visual appearance to match the system-level layering and material language promoted by macOS 26.

### Design References
- **macOS Tahoe 26**: System-level visual updates, Liquid Glass multi-layer material language
- **Apple HIG**: Sidebar / Layout / Lists & Tables structural guidance (for settings dual-column and information organization)

## What Changes

### Main Panel (Bottom Sheet)
- **MODIFIED**: Window size from 300pt height → 280pt height (tighter vertical spacing)
- **MODIFIED**: Window width from (screen width - 40pt) → edge-to-edge full width (0pt margin)
- **MODIFIED**: Corner radius from 12pt → 20pt (aligns with macOS 26 system apps)
- **MODIFIED**: Background from `NSVisualEffectView(.popover)` → **SwiftUI `.glassEffect(.regular)`** (macOS 26 official Liquid Glass API)
  - **Fallback**: Use `.background(.ultraThinMaterial)` on macOS 12-25
  - **Tint**: Optional subtle tint color for glass effect using `.glassEffect(.regular.tint(.color))`
- **MODIFIED**: Window appears fully transparent when no content (no visible frame)
- **ADDED**: Invisible top padding 12pt (breathing room)
- **MODIFIED**: Horizontal padding from default → 16pt L/R (system spacing)
- **ADDED**: Two-region layout structure (top: search bar, bottom: content area)
- **ADDED**: Content area uses Grid layout for horizontal scrolling
- **ADDED**: Only content area scrolls when items exceed space (panel height remains fixed)

### Search Bar
- **MODIFIED**: Visual style from "6% white background + 8pt corner radius" → **completely transparent with no visible frame**
- **MODIFIED**: Display only text input cursor and placeholder (minimalist design per PRD)
- **MODIFIED**: Divider style from single line → dual-line gradient (top 0.5pt white 8%, bottom 0.5pt black 12%)
- **MODIFIED**: Divider serves as the ONLY visual separator between search and content regions
- **MODIFIED**: Vertical spacing to 12pt top + 8pt bottom (balanced breathing)

### Cards
- **MODIFIED**: Aspect ratio from 160×200pt (4:5) → Square 180×180pt (1:1)
- **MODIFIED**: Corner radius from 10pt → 20pt (MUST match panel radius exactly for visual consistency)
- **MODIFIED**: Background from `NSVisualEffectView(.regular)` → **SwiftUI `.glassEffect(.clear)`** (macOS 26+)
  - **Design rationale**: Layered material approach (panel `.regular` + cards `.clear`) follows macOS 26 system app patterns
  - **Fallback**: Use `.background(.thinMaterial)` on macOS 12-25
  - **Performance**: Use `GlassEffectContainer` (SwiftUI view) to merge nearby cards (reduces rendering passes)
- **MODIFIED**: Shadow from strong → System-level subtle shadow (y-offset 2pt, blur 8pt, 10% black)
- **MODIFIED**: Color stripe height from 4pt → 3pt (more subtle)
- **REMOVED**: Separate app icon + app name at bottom
- **ADDED**: Unified metadata bar at bottom (app icon 14pt + app name + timestamp, single line, 8pt L/R padding)
- **MODIFIED**: Text preview from 3 lines → 4-5 lines (fill card better)

### Animations
- **MODIFIED**: Panel show animation from `.spring(0.45s, damping 1.2)` → **`.snappy(duration: 0.4, extraBounce: 0.0)`** (modern iOS feel)
- **MODIFIED**: Panel hide animation from `.easeOut(0.35s)` → **`.smooth(duration: 0.3, extraBounce: 0.0)`** (graceful exit)
- **MODIFIED**: Card entrance from `.spring(0.5s)` → **`.snappy(duration: 0.5, extraBounce: 0.15)`** (lively with subtle bounce)
- **MODIFIED**: Card hover scale from `.spring(0.2s)` → **`.snappy(duration: 0.25, extraBounce: 0.0)`** (responsive feedback)
- **ADDED**: Card scale-in starts from 0.9x → 1.0x (instead of 0.8x, more subtle)
- **PERFORMANCE NOTE**: macOS 26 early versions have reported animation performance issues (15 fps in some cases); fallback to simplified animations if needed

### Settings Window
- **BREAKING**: Replace TabView with NavigationSplitView (Sidebar + Detail dual-column layout, macOS 26 standard)
- **MODIFIED**: Window background from default → **SwiftUI `.glassEffect(.regular)`** (macOS 26+) / `.background(.ultraThinMaterial)` fallback (macOS 14-25)
- **ADDED**: Left sidebar (200pt fixed width) with navigation list
- **ADDED**: Right detail pane (min 500pt width) with module content
- **ADDED**: Window supports user resizing (draggable edges and corners) with minimum size constraints
- **MODIFIED**: Module backgrounds from `.grouped` form → Individual cards with 16pt padding + 12pt corner radius
- **MODIFIED**: Card backgrounds to **SwiftUI `.glassEffect(.clear)`** / `.background(.thinMaterial)` fallback (layered on window background)
- **MODIFIED**: Layering system (window background + module cards) SHALL be consistent across all settings pages including subpages
- **ADDED**: Sidebar items use system-standard SF Symbols + labels
- **ADDED**: Sidebar menu structure (5 items):
  1. General (gear icon)
  2. Shortcuts (keyboard icon)
  3. **Tools (wrench icon)** - NEW placeholder for future features
  4. Privacy (lock icon)
  5. Advanced (slider icon)
- **ADDED**: Hover states on sidebar items (subtle background highlight)
- **BEST PRACTICE**: Use `.task` instead of `.onAppear` for setting initial `columnVisibility` (recommended pattern for NavigationSplitView)

### Settings IA Changes
- **ADDED**: "Tools" menu item (3rd position) as placeholder for future tool-related features
- **ADDED**: "Advanced" section in sidebar with "Reset to Defaults" option
- **MODIFIED**: Organize settings into logical groups (5 menu items total)
- **MODIFIED**: Ensure "Privacy / App Filters" is accessible (critical feature preservation)

## Impact

### Affected Specs
- `specs/ui-main-panel/spec.md` - Window configuration, dimensions, materials
- `specs/ui-search/spec.md` - Divider styling, field background
- `specs/ui-cards/spec.md` - Dimensions, materials, metadata layout
- `specs/ui-animations/spec.md` - Timing, damping, scale values
- `specs/ui-settings/spec.md` - **BREAKING** - Complete layout restructure (TabView → Sidebar)

### Affected Code
- `Managers/FloatingWindowManager.swift` - Panel size, corner radius, material
- `Views/ClipboardListView.swift` - Padding, search bar divider
- `Views/ClipboardCardView.swift` - Card dimensions, corner radius, material, metadata layout
- `Views/SettingsView.swift` - **BREAKING** - Complete rewrite to NavigationSplitView
- `Views/Settings/*.swift` - Module views need card-based layout instead of Form

### Breaking Changes
- **Settings window layout**: Users familiar with tab-based settings will see a new sidebar layout (aligned with macOS 26 System Settings style)
- **Settings window code**: Requires significant refactor from TabView to NavigationSplitView
- **Minimum macOS version consideration**: NavigationSplitView requires macOS 14.0+ (settings window only; main panel works on macOS 12+)

## Migration Notes
- All visual changes are non-functional (no data model or API changes)
- Settings layout change is visual only (all settings remain accessible)
- No user data migration required
- Existing hotkeys and preferences will work unchanged

## QA Checklist (from PRD Section 7)
- [ ] Panel 280pt height, edge-to-edge full width, 20pt corner radius
- [ ] Panel uses SwiftUI `.glassEffect(.regular)` (macOS 26+) / `.background(.ultraThinMaterial)` fallback
- [ ] Panel has two-region layout (search bar + content area with Grid)
- [ ] Search bar completely transparent with NO background color or corner radius
- [ ] Search divider dual-line gradient (white 8% / black 12%, each 0.5pt)
- [ ] Cards 180×180pt square, 20pt corner radius (MUST match panel radius)
- [ ] Cards use SwiftUI `.glassEffect(.clear)` for layered material hierarchy
- [ ] Cards use `GlassEffectContainer` (SwiftUI view) for performance optimization
- [ ] Settings sidebar 200pt, detail pane min 500pt, window supports user resizing
- [ ] Settings sidebar has 5 menu items (General, Shortcuts, Tools, Privacy, Advanced)
- [ ] Settings module cards 16pt padding + 12pt radius, layered on window background
- [ ] Settings use NavigationSplitView with `.task` for columnVisibility initialization
- [ ] All animations use `.snappy` / `.smooth` curves (no traditional spring)
- [ ] Hover states work on sidebar items
- [ ] No visual regression in macOS 14-25 (fallback to material backgrounds works correctly)
- [ ] Performance acceptable on macOS 26 (monitor for animation frame drops)

## Technical References
- API Cache: `spec/MACOS_26_API_CACHE.md`
- WWDC 2025 Session 219: Meet Liquid Glass
- WWDC 2025 Session 310: Build an AppKit app with the new design
- SwiftUI Animation Masterclass: [dev.to article](https://dev.to/sebastienlato/swiftui-animation-masterclass-springs-curves-smooth-motion-3e4o)
