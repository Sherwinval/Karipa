# Karipa Phase 0 report

Historical Phase 0 snapshot. Its palette recommendation and approval stop point were superseded by the user's Phase 1 brief. See the [approved design system](karipa-design-system.md) and [Phase 1 report](frontend-phase1-report.md) for current work.

Completed 2026-10-10 on Windows. Scope: persistent frontend guidance, initial mobile display-name update, design exploration, Graphify evaluation, and before/after frontend checks. The later project-wide rebrand aligned the technical and user-facing identity on Karipa. No palette or full UI redesign had been implemented at this historical checkpoint.

## Completed work and file inventory

Five files were added and twelve existing files updated. All application/test/native changes are string substitutions: fourteen changed lines across eleven files. The twelfth existing file is the mobile README.

### Documentation

| File | Change |
| --- | --- |
| `mobile/AGENTS.md` | Added persistent frontend scope, protected paths and embedded business logic, conventions, accessibility, navigation/state rules, and diff/validation requirements. No existing repository AGENTS file was found to overwrite. |
| `mobile/README.md` | Replaced Flutter starter text with Karipa identity and links to the actual frontend documentation. |
| `docs/frontend-development.md` | Added verified environment, architecture, running/debugging, VS Code, device workflow, reload/restart, read-only validation, and screenshot comparison guidance. |
| `docs/karipa-design-exploration.md` | Added four-palette comparison, explicit ColorScheme/component/map/status proposals, calculated contrast, UI language, and proposed Phase 1 sequence. |
| `docs/graphify-evaluation.md` | Added separate knowledge-graph and Flutter-chart assessments, primary sources, uncertainty, and adoption recommendation. |
| `docs/frontend-phase0-report.md` | This change inventory, baseline comparison, unresolved issues, and approval boundary. |

### Initial display-name changes

Paths below are relative to the repository root. Other content in these files is unchanged.

| File | Result |
| --- | --- |
| `mobile/lib/main.dart` | The app title is Karipa. |
| `mobile/lib/screens/` | Visible app and account copy uses the Karipa name. |
| `mobile/android/app/src/main/AndroidManifest.xml` | The Android display label is Karipa. |
| `mobile/ios/Runner/Info.plist` | The iOS display name is Karipa. |
| `mobile/test/widget_test.dart` | Smoke-test descriptions and brand expectations use Karipa. |

That initial pass changed only displayed names and left technical identifiers intact. The subsequent project-wide rebrand also aligned Flutter package/type names, native application identifiers, backend and AI messages, local service names, and documentation with Karipa. Business logic and API paths were not changed.

## Validation: baseline versus after rebrand

SDK: Flutter **3.47.7 stable**, Dart **3.13.5**, DevTools **2.60.0**. Commands ran from `mobile/`. Existing dependencies were used with `--no-pub`; no package resolution/upgrade command was run. The formatter used `--output=none` and did not rewrite files.

| Command | Before | After | Assessment |
| --- | --- | --- | --- |
| `flutter doctor -v` | Issues in 3 categories | Same 3 categories | Android command-line tools missing and licenses unknown; Chrome executable unavailable; Visual Studio desktop tooling missing |
| `flutter devices` | Windows and Edge only | Windows and Edge only | No Android device/emulator connected |
| `flutter analyze --no-pub` | Exit 1, 40 informational diagnostics | Exit 1, 40 informational diagnostics | Same existing lint/deprecation categories; no analyzer errors or warnings |
| `flutter test --no-pub` | Exit 1, one failed smoke test | Exit 1, same pending-timer failure | The updated Karipa text assertion did not fail; the whole test still fails at teardown |
| `dart format --output=none --set-exit-if-changed lib test` | Exit 1; 28 files checked, 24 would change | Exit 1; same 28/24 counts and file set | Existing formatting drift; no bulk formatting applied |
| `git diff --check` (repository root) | Clean baseline | Passed | No whitespace errors in tracked diffs |
| Protected-path/native/full-hunk review | Working tree initially clean | Only authorized documentation/string edits | No protected source changes |

The smoke test pumps the splash once. `SplashScreen._checkSession` schedules a 1.6-second delayed callback, which remains pending when the test finishes. Only the test name and text expectation were changed; lifecycle/test-harness repairs need a separate scoped task. Do not present this test run as passing.

Analyzer findings concern `withOpacity`, `Switch.activeColor`, const opportunities, and one field that could be final. The tracked `mobile/flutter_analyze.txt` is an older snapshot and is not the current check result. No new diagnostic category or test failure was observed in this change.

The first restricted doctor invocation stalled on the SDK cache lock and was stopped; checks were rerun with approval for SDK-cache access outside the project. This is a tooling-access limitation, not an app regression. No Android/iOS build, running-device check, visual screenshot, or end-to-end backend check was performed. Native launcher/display behavior requires a later full rebuild on supported devices.

Final review includes `git diff --check`, full hunks, changed-file inventory, staged changes, and explicit protected paths (`backend/`, `ai/`, services, models, and `pubspec.yaml`). No theme/widget changes, schemas/migrations, database operations, backend tests, commits, or pushes were made. The ignored local lockfile still has SHA-256 `951F8366A61B84C8DFB11F1A68FF97EB52B7F10BA2E9840D3E9E1D09D30B1DB5`; it was not edited by this task.

## Repository behavior and existing gaps

These are source observations, not a successful runtime certification or new approved features.

| Area | Implemented in source | Existing limitation / follow-up |
| --- | --- | --- |
| Entry and identity | Splash, login/register/OTP, guest entry, profile, Provider authentication state | Profile still says `Guest Runner` / `Verified Runner Account`; broader inclusive/accurate copy was outside this name-only change. Security/About rows are informational rather than complete settings pages. |
| Activity and planning | Walking/jogging/running/cycling selection, target distance, preferences, location acquisition, API route generation, recommendations/details | API availability and recommendation quality were not exercised. Suitability values must not be described as safety guarantees. |
| Tracking | GPS stream, pause/resume, elapsed active time, distance, pace or cycling speed, remaining distance/time, calorie estimate | Calories assume 70 kg and fixed activity MET values. GPS errors are logged; robust user-visible live GPS status is not established. Measurements/forecasts need careful estimate wording. |
| Completion/persistence | Save request followed by completion screen; activity history/detail screens | Save exceptions are logged and navigation still reaches a summary saying the workout was saved. Persistence success must be handled by the integration owner before UI can truthfully guarantee it. Guest persistence is not established by the frontend. |
| Navigation | Fifteen screens registered through `onGenerateRoute`; home opens history/profile | Existing bottom navigation pushes screens rather than using a persistent tab shell. Required arguments contain casts; preserve contracts during UI work. |
| Unused screens | Seventeen screen files overall | `routes_screen.dart` is placeholder copy; `activity_setup_screen.dart` simulates generation and supplies arguments incompatible with the registered route-details constructor. Neither is wired into the active named routes. Do not enable them as a styling task. |
| Visual foundation | Material 3, Inter/Manrope, theme extension, map/metric/status widgets | Hardcoded screen colors and spacing bypass the central theme. Light mode is forced. Responsive/large-text/outdoor behavior has not been tested on devices in Phase 0. |
| Reproducibility | Existing manifest and local resolved packages | Ignored lockfile and a much older manifest Dart lower bound than the resolved packages complicate clean-checkout reproducibility. Team-owned SDK/dependency decisions are needed. |

Protected logic was inspected to identify these boundaries; none of these functional gaps was repaired in Phase 0.

## Design recommendation — not implemented

| Candidate | Assessment | Key contrast constraint |
| --- | --- | --- |
| Trail Spark | **Primary recommendation:** outdoor identity, broad activity appeal, closest to existing forest/lime tokens | Main text/page 14.34:1; white/forest 12.33:1. Lime needs dark text; green text on the page fails ordinary-text AA. |
| Sunset Stride | Warm and energetic; workable with disciplined dark controls | Main text/page 12.36:1. Both white/orange and supplied charcoal/orange fail ordinary-text AA; proposed deeper text passes. |
| Coastal Motion | **Alternative:** approachable and related to current teal screen styling | Main text/page 12.58:1. White fails on teal and sky; use dark text. |
| Velocity Ink | Strong contrast and a performance character; more visual distance from current theme | Main text/page 15.89:1. White/iris and ink/iris fail ordinary-text AA; lime needs dark text. |

The [full proposal](karipa-design-exploration.md) gives each candidate's ColorScheme roles, primary/secondary buttons, card/page surfaces, navigation, workout dashboard, route/marker treatments, common semantic states, and checked foreground/background ratios. It also defines Inter/Manrope usage, spacing/radii, readable metrics, existing Material activity icons, accessible controls, restrained motion, and responsive review criteria. None guarantees sunlight or map-tile contrast without device validation.

## Graphify recommendation

Adopt neither tool now. The knowledge-graph tool advertises Dart and Codex support, but no local benchmark establishes a benefit for this frontend's size. The Flutter charting package adds a WebView/ECharts layer without an approved chart requirement, and its upstream repository is archived. Compatibility, privacy behavior, and device performance were not tested. See the [separate evaluation and maintainer sources](graphify-evaluation.md). No installation, graph generation, indexing, configuration, or source upload was performed.

## Unresolved decisions and proposed next phase

Before Phase 1, obtain:

1. Final palette approval and explicit approval to implement the design system.
2. The full approved Chapter 1/2 paper and evaluation rubric. Only the requirements supplied in the user request are available; this report does not claim to have read the paper.
3. Approved visual references or a Figma design, if any; a logo/asset brief can follow before asset work.
4. Target Android/iOS versions and representative devices, accessibility expectations, and a functioning device-validation environment.
5. Team decisions on guest history/save behavior, save-failure feedback, live GPS status, meaning of route suitability, inclusive profile wording, and reproducible SDK/dependencies. These may require separate integration work.

Proposed Phase 1: approve exact tokens; consolidate the existing light theme and component styles; introduce only justified presentation components with existing callbacks/data; review a representative screen and tracking-metric layout; add focused accessibility/visual checks; then agree on screen-by-screen rollout. The smoke-test timer fix should be reviewed independently from the theme work.

**Stop point:** Phase 0 is complete. Await the user's final palette choice and Phase 1 approval before implementation. The user's explicit phase boundary is the reason further UI work has not begun.
