# Spec Delta: Smart Features Permissions

**Capability**: `smart-features-permissions`
**Change**: ADDED

---

## ADDED Requirements

### Requirement: Smart Features Permission Check

Smart features (Smart AI Recommendations) MUST check for required permissions (Screen Recording + Notification) and indicate restricted state when missing.

#### Scenario: All Smart permissions granted

**Given** Screen Recording permission is granted
**And** Notification permission is granted
**When** the user accesses Smart features
**Then** all Smart features MUST be fully functional
**And** no permission warnings SHALL be displayed

#### Scenario: Smart permissions missing (restricted state)

**Given** Screen Recording permission is not granted OR Notification permission is not granted
**When** the user attempts to use Smart features
**Then** the system MUST display a "Smart 功能受限" indicator
**And** MAY provide a re-entry path to onboarding (implementation deferred)

**Note**: Full Smart page UI implementation is deferred to a separate change. This spec defines the permission restriction behavior only.

---

### Requirement: Permission Restriction Banner (Deferred)

When Smart permissions are not granted, Smart-related UI SHALL display a banner with a re-entry option to the onboarding page.

#### Scenario: Re-entry to onboarding from Smart page (Future)

**Given** the user is on a Smart features page
**And** Smart permissions are restricted
**When** the user sees the permission restriction banner
**And** clicks the "开启权限" button
**Then** the system MUST set `skipOnboardingPermissions = false`
**And** MUST display the onboarding window immediately
**And** the user can grant the missing Smart permissions

**Implementation Status**: DEFERRED - Smart page UI may not fully exist yet. Implement when Smart features UI is complete.
