Source: https://github.com/riko2chen/AskForPermission
Revision: 91f4dde33f9f5dd58a89d72f3f05aa4b149a1f0e
Local Swift package dependency. Local patches: optional showWhenAuthorized replay; Chinese PingFang guide; adjacent placement. Original flight, drag, tracker retained.

Accessibility completion patch: detect newly granted AX access while waiting for drag, so toggling an existing Settings row completes without restart. Cancel the observer with the flow; preserve authorized replay. Accessibility post-drop wait uses actual AX status for up to 120 seconds instead of focus/window heuristics.

2026-10-19 companion visual/input patch: local feathered material replaces opaque card and row borders; PingFang title 32pt and draggable label 18pt. Hosting size locked to 680x210pt. Opening Settings no longer reactivates senseflow or orders the source window above it. Guide remains a bounded nonactivating panel; flight overlay ignores mouse events. File drag and live Settings tracking remain intact.

Superseding companion shape: use bounded rounded regularMaterial instead of an elliptical feather mask. Preserve 32pt typography with semantic line break after “拖入列表”; no opaque black fill or border. Main onboarding launches permission directly from its title action.

Compact companion overrides oversized tutorial typography: 480x136pt, 18pt single-line instruction, 14pt app label, 18pt corners. Main tutorial remains 32pt. Shared visual language does not imply identical scale across surfaces.

Following placement supersedes adjacent docking: fixed 16pt inset inside Settings' bottom-right, no side switching; maximum screen intersection determines visible-frame clamp. Tracker interval 33ms, updates only on changed geometry; no screen capture or AX requirement added.
