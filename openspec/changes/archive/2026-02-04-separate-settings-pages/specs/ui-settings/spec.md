# UI Settings Spec Delta

## ADDED Requirements

### Requirement: Settings Navigation Structure

The Settings window SHALL use NavigationSplitView with a sidebar containing navigation links to different settings pages. Each major feature area MUST have its own independent sidebar page.

#### Scenario: User navigates to Developer Options settings
**Given** the user opens the Settings window
**When** the user clicks on "开发者选项" in the sidebar
**Then** the Developer Options settings page is displayed
**And** the page shows "Show Prompt Labels" toggle
**And** the page shows Langfuse integration configuration

#### Scenario: User navigates to Smart AI settings
**Given** the user opens the Settings window
**When** the user clicks on "Smart AI" in the sidebar
**Then** the Smart AI settings page is displayed
**And** the page shows Smart AI enable/disable toggle
**And** the page shows hotkey display (⌘⌃V)
**And** the page shows lightweight mode toggle
**And** the page shows screen recording permission status

#### Scenario: User navigates to Prompt Tools settings
**Given** the user opens the Settings window
**When** the user clicks on "Prompt Tools" in the sidebar
**Then** the Prompt Tools settings page is displayed
**And** the page shows AI service configuration
**And** the page shows Prompt Tools list
**And** the page does NOT show Developer Options section
**And** the page does NOT show Langfuse configuration

### Requirement: Settings Sidebar Order

The Settings sidebar MUST display navigation items in a specific order for optimal user experience. The order SHALL be: General, Shortcuts, Prompt Tools, Smart AI, Developer Options, Privacy, Advanced.

#### Scenario: Settings sidebar displays all navigation items in correct order
**Given** the user opens the Settings window
**Then** the sidebar shows navigation items in this order:
1. 通用 (General)
2. 快捷键 (Shortcuts)
3. Prompt Tools
4. Smart AI
5. 开发者选项 (Developer Options)
6. 隐私 (Privacy)
7. 高级 (Advanced)
