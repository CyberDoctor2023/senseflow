# Proposal: Remove Hardcoded Version Strings

## Overview
Replace all hardcoded version strings (e.g., "v0.2", "v0.3.1") in the codebase with dynamic version retrieval from `Bundle.main.infoDictionary`.

## Problem
Currently, version strings are hardcoded in multiple locations:
- `AppDelegate.swift:47` - Startup log message
- `AppDelegate.swift:50` - Feature announcement
- `AppDelegate.swift:83` - Status bar menu title

This creates maintenance issues:
1. Every version bump requires manual updates in 3+ locations
2. Risk of version inconsistency between Info.plist and displayed version
3. Easy to forget updating all locations

## Proposed Solution
Create a centralized version accessor that reads from `CFBundleShortVersionString` in `Bundle.main.infoDictionary`.

### Benefits
- Single source of truth (Info.plist)
- Automatic version updates
- Reduced maintenance burden
- No risk of version mismatch

### Implementation Strategy
1. Add computed property `appVersion` to AppDelegate (or create a dedicated Constants file)
2. Replace all hardcoded version strings with the dynamic value
3. Update feature announcement to be version-agnostic or use a separate key

## Scope
- **In scope**: Replace hardcoded version strings in AppDelegate
- **Out of scope**: Version strings in comments (e.g., "v0.2: feature description")

## Risks
- None identified (low-risk refactoring)

## Related Changes
- None

## Success Criteria
1. No hardcoded version strings in runtime code
2. Status bar and logs display correct version from Info.plist
3. Build succeeds without warnings
