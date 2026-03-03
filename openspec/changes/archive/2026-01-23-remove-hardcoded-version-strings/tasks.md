# Tasks: Remove Hardcoded Version Strings

## Implementation Tasks

- [x] 1. Add version accessor to AppDelegate
  - Add computed property `appVersion` that reads from Bundle
  - Format: "v{CFBundleShortVersionString}"

- [x] 2. Replace hardcoded version in startup log
  - Location: AppDelegate.swift:47
  - Change: "v0.3.1" → dynamic version

- [x] 3. Replace hardcoded version in status bar menu
  - Location: AppDelegate.swift:83
  - Change: "v0.3.1" → dynamic version

- [x] 4. Update feature announcement message
  - Location: AppDelegate.swift:50
  - Make version-agnostic or remove version reference

- [x] 5. Build and test
  - Verify version displays correctly in status bar
  - Verify startup logs show correct version
  - Ensure no build warnings

- [x] 6. Create commit
  - Use standard commit format
  - Include Co-Authored-By line

## Success Criteria
- ✓ No hardcoded version strings in runtime code
- ✓ Status bar displays correct version from Info.plist
- ✓ Build succeeds without warnings
