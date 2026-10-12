# Frontend palette update — 2026-10-11

## Result
Light-mode content, cards, forms and dialogs use white (#FFFFFF). Navigation, drawers, sheets and supporting panels use the previous landing-page beige (#E3E0D3). Primary actions retain coral (#FF5A49) with midnight text. Dark mode and its existing toggle remain intact.

Reusable tokens: KaripaPalette.white, contentBackground and supportingSurface. ColorScheme and component themes supply context-aware foregrounds, boundaries and surfaces. Legacy screen colors now follow those roles. Metric borders retain separation on white. Profile and Planning use Ink for existing decorated list surfaces so interaction feedback remains visible. No layout redesign, copy, route, callback, calculation, service or data change was made.

## Files changed in this task
- `mobile/lib/screens/active_tracking_screen.dart`
- `mobile/lib/screens/activity_complete_screen.dart`
- `mobile/lib/screens/activity_details_screen.dart`
- `mobile/lib/screens/activity_history_screen.dart`
- `mobile/lib/screens/activity_selection_screen.dart`
- `mobile/lib/screens/activity_setup_screen.dart`
- `mobile/lib/screens/login_screen.dart`
- `mobile/lib/screens/otp_screen.dart`
- `mobile/lib/screens/profile_screen.dart`
- `mobile/lib/screens/ready_to_start_screen.dart`
- `mobile/lib/screens/recommended_routes_screen.dart`
- `mobile/lib/screens/register_screen.dart`
- `mobile/lib/screens/route_details_screen.dart`
- `mobile/lib/screens/route_planning_screen.dart`
- `mobile/lib/screens/splash_screen.dart`
- `mobile/lib/theme/app_theme.dart`
- `mobile/lib/theme/design_tokens.dart`
- `mobile/lib/widgets/metric_tile.dart`
- `mobile/lib/widgets/status_badge.dart`
- `mobile/test/palette_screens_test.dart`: palette assertions, rendered screen coverage, button contrast and optional review PNGs.
- `mobile/AGENTS.md`: current authorized color scope.
- `mobile/README.md`: report link.
- `docs/frontend-palette-report.md`: this report.

Earlier working-tree changes in main.dart, Home, the dashboard, ThemeService, existing tests and Phase 2 documentation were preserved. Services and models were compared with the task-start source snapshot and are unchanged. Backend, AI, model, package and lockfile diffs are empty. No commits, dependency upgrades, database operations or API changes.

## Checks
- `flutter build apk --debug --no-pub`: passed. APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Installed and opened on emulator-5554; actual guest Home visually inspected.
- `flutter analyze --no-pub`: 23 informational diagnostics, no warnings/errors; exit 1. Remaining items include deprecated withOpacity/activeColor, existing mutable Home index and brace lints exposed by formatting.
- `flutter test --no-pub`: 103 passed, 3 failed. All 34 Home tests pass.
- Failures: existing splash pending 1.6-second timer; Recommendations at 390px in light and dark mode overflow right by 45px. A copy of the untouched recommendation screen reproduces both overflow failures with the same fixture. Its layout remains unchanged.
- Build warns about future support removal for Gradle 8.14.0, Android Gradle Plugin 8.11.1 and Kotlin 2.2.20. Toolchain changes are outside this task.
- `git diff --check`: passed. Formatter applied only to changed Dart files.
- Semantic theme pairs and checked primary-button text meet 4.5:1 contrast. Existing Home accessibility, enlarged-text, loading/empty/populated, data-binding and navigation checks pass.

## Visual review and limits
Reviewed Flutter renders at 390x900 and 1280x900 in light/dark modes: Home, login, registration, OTP, Profile, exit dialog, activity selection, empty history, setup, planning, ready-to-start, recommendations and completion. Desktop populated Recommendations renders; its narrow counterpart has the reported overflow. Existing compact planning chips still fade long labels; layout was preserved.

Review PNGs are generated under `mobile/build/palette-review/` (ignored build artifacts), including `android-home.png`. Widget renders use locally available Arial as a readable test substitute for Manrope/Inter; production fonts are unchanged. The Android screenshot uses production fonts.

Not visually verified end-to-end: active GPS tracking, map-backed route/activity details, live authenticated records, every error/permission state, iOS, native desktop/browser runtime, TalkBack or VoiceOver. Desktop checks are Flutter widget renders, not a desktop application launch. No live tracking, save or deletion action was performed.
