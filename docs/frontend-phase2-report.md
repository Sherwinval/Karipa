# Phase 2: Home dashboard

## Implementation

Home now has an editorial greeting/headline, a full-width coral Start activity button, four all-time metrics, and the three most recent activities with dates. Walking, jogging, running and cycling receive equal prominence. Existing MetricTile, KaripaButton, KaripaFeedback, KaripaProgress, SectionHeading, typography and spacing tokens are reused. Large text switches metric cards to one column and stacks the recent-section action. Navigation labels honor text scaling.

Home retains its authentication source, API fetching, totals, guest fallback, pull-to-refresh, route arguments and existing refresh-on-return behavior. Presentation receives values and callbacks; no new backend functionality or dependencies were added. Fetch errors still fall back to the existing empty state; a distinct error state requires separate functional work.

## Files from Phase 2

- `mobile/lib/screens/home_screen.dart`: presentation delegation and recent activity cards.
- `mobile/lib/widgets/home_dashboard.dart`: dashboard and recent-record presentation.
- `mobile/test/home_dashboard_test.dart`: responsive, data, navigation and accessibility checks.
- `mobile/AGENTS.md`: Home-only phase scope.
- `docs/screenshots/phase2/home-before.png`: original guest Home.
- `docs/screenshots/phase2/home-after.png`: implemented dark guest Home, captured before the small active-time unit refinement and subsequent theme-toggle edits.
- `docs/screenshots/phase2/home-320-text200.png`: unsuccessful capture showing Login, **not evidence of Home at enlarged text**. Retained because it is now part of the newer repository checkpoint.
- `docs/frontend-phase2-report.md` and `mobile/README.md`: handoff documentation.

## Validation and theme decision

Original Phase 2 validation: 33 Home tests passed; full suite had 47 passes and the existing splash pending-timer failure. Matrix covers widths 320/360/412, text scales 100/150/200%, populated/empty/loading states, plus landscape, long names, targets, labels, contrast, routes and refresh behavior. This does not replace manual TalkBack/VoiceOver testing.

On resuming, checkpoint `4bf3602` and newer uncommitted theme-toggle edits were present in main, Profile, Home, the dashboard and a new ThemeService. These were preserved. They remove Home's local dark theme and warm-card override, so Home now follows the global theme. The user explicitly approved retaining the theme toggle. Home validation now checks that both global light and dark themes are respected. This supersedes the original local-dark-only requirement.

Before adapting validation, 32 Home tests passed and the obsolete local-dark assertion failed. Validation was updated for the approved global-theme behavior, retaining all data assertions and adding coverage for both brightness modes.

Final validation: all **34 Home tests pass**; the full suite recorded 48 passes and one smoke-test failure from the missing ThemeService in its harness. Added that provider in `mobile/test/widget_test.dart` and reran the smoke test: it now reaches the previously documented splash pending-timer failure. Production splash behavior was preserved.

Latest `flutter analyze --no-pub`: **30 informational diagnostics, no warnings/errors**, exit 1. `git diff --check` passes. Current backend, AI, models and package/lockfile diffs are empty. Phase 2 did not change services, business logic or global theme; the newer ThemeService and global-theme edits are separate existing work and were not overwritten.

Actual Android guest Home was inspected and captured at normal size. The emulator disconnected during the enlarged-text attempt. It was restarted and its original density (420) and font scale (1.0) were restored and verified. Actual Home at 320/200% remains unverified on-device; the automated matrix passed. No iOS or screen-reader verification is claimed.

No commit or push was performed by this task. No other screen redesign was undertaken. The theme choice is resolved: retain the existing global toggle.
