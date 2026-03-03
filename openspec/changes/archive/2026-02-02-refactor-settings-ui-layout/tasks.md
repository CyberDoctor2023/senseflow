# Tasks: Refactor Settings UI Layout

## Overview
Replace NavigationSplitView with TabView in SettingsView.swift to match macOS design guidelines.

## Task List

### Phase 1: Preparation (1 task)
- [x] **Read current SettingsView.swift implementation**
  - Understand current NavigationSplitView structure
  - Identify all settings sections and their icons
  - Note any custom styling or modifiers

### Phase 2: UI Refactoring (3 tasks)
- [x] **Replace NavigationSplitView with TabView**
  - Remove SettingsSidebarView struct
  - Remove SettingsDetailView struct
  - Implement TabView with 5 Tab items
  - Use `Tab("Label", systemImage: "icon") { ContentView() }` syntax

- [x] **Update window sizing**
  - Change from `.frame(width: 750, height: 500)` to `.frame(maxWidth: 350, minHeight: 100)`
  - Add `.scenePadding()` for system margins
  - Remove `.background(.regularMaterial)` (TabView handles this)

- [x] **Update SettingsSection enum if needed**
  - Keep existing enum structure
  - Verify icon names match Tab systemImage requirements
  - Ensure all 5 sections are properly mapped

### Phase 3: Validation (2 tasks)
- [x] **Build and test UI**
  - Verify all 5 tabs appear in toolbar
  - Check window size matches standards
  - Test tab switching functionality
  - Verify content views display correctly

- [x] **Visual QA**
  - Compare with macOS System Settings appearance
  - Check toolbar icon spacing and alignment
  - Verify scenePadding creates proper margins
  - Test in both Light and Dark mode

### Phase 4: Documentation (1 task)
- [x] **Update code comments**
  - Update file header comment (remove "NavigationSplitView" reference)
  - Add comment explaining TabView choice per HIG
  - Update any inline comments referencing old layout

## Total: 7 tasks

## Dependencies
- None (independent UI change)

## Validation
- All 5 settings sections accessible via toolbar tabs
- Window size ≤ 350pt width
- Visual appearance matches macOS standards
- No functionality regressions
