# Karipa frontend development guide

Phase 0 baseline: 2026-10-10 (Asia/Manila). PathCraft remains the academic and technical project; Karipa is the displayed mobile application name.

Read [mobile/AGENTS.md](../mobile/AGENTS.md) for scope and protected boundaries. The [approved design system](karipa-design-system.md) replaces the historical palette exploration. See the [Phase 1 report](frontend-phase1-report.md) for current checks, the [Phase 0 report](frontend-phase0-report.md) for the original baseline, and [Graphify evaluation](graphify-evaluation.md) for the tooling decision.

## Environment verified locally

| Item | Observed value |
| --- | --- |
| Flutter | 3.47.7, stable |
| Dart | 3.13.5 |
| DevTools | 2.60.0 |
| Host | Windows 11, PowerShell |
| Android SDK / emulator | SDK 36.0.0 / emulator 37.2.12.0 |
| Application version | 1.0.0+1 |
| Dart manifest constraint | `>=3.3.0 <4.0.0` |
| Local resolved SDK requirements | Dart `>=3.13.0 <4.0.0`, Flutter `>=3.44.0` |

The selected SDK is under `C:\Users\alzat\OneDrive\Documents\flutter_windows_3.47.7-stable\flutter`. This is a machine-specific observation, not a portable path to copy into shared settings. `mobile/android/local.properties` and PATH selected the same SDK.

The local `pubspec.lock` is ignored by Git. Agree on a reproducible SDK/dependency baseline with the team; do not run dependency upgrades as part of UI work. Current dependencies are already resolved locally, so validation uses `--no-pub`.

Doctor currently reports missing Android command-line tools and unknown Android license status. No Android device was connected; Windows and Edge were detected. Chrome and the Visual Studio Windows desktop toolchain are unavailable. Android tooling repair and license acceptance are separate setup actions; they were not performed in Phase 0. Windows desktop support is unnecessary for Android-only work.

## Existing architecture

- `lib/main.dart`: Material app, authentication Provider, named navigation via `onGenerateRoute`.
- `lib/screens/`: 17 screen files, 15 registered screens. `routes_screen.dart` is a placeholder and `activity_setup_screen.dart` is an unused simulated flow.
- `lib/widgets/`: shared map, metric tile, status badge, and Phase 1 presentation components for actions, activity choice, route cards, headings, feedback, and progress. New components are not yet wired into screen redesigns.
- `lib/theme/`: explicit five-color Material 3 schemes, Inter/Manrope, `PathCraftColors`, and spacing/radius/size tokens. Many screens still override the theme. Light mode remains forced by the existing app; dark component styling is available for later screen work.
- `lib/services/` and `lib/models/`: protected integrations/data. Authentication uses Provider/ChangeNotifier and SharedPreferences; other state resides in screens.
- `test/widget_test.dart`: existing app-launch smoke test with a known pending-timer failure; `test/design_system_test.dart`: focused Phase 1 contrast, responsiveness, semantics, and callback tests.

Existing flow: splash -> authentication or guest entry -> home -> activity selection -> distance/preferences/current GPS location -> recommendations -> route details -> ready -> active tracking -> completion/history. Home also opens history and profile. Preserve route names, arguments, callbacks, and back-stack behavior.

Some screen methods own functional logic. Later presentation components should accept existing values and callbacks while the original screen retains operational state. This does not require a new state framework, router, dependency-injection layer, or feature-directory migration.

## Start and inspect the application

From the repository root:

```powershell
Set-Location mobile
flutter doctor -v
flutter devices
flutter run --no-pub -d <device-id>
```

Replace `<device-id>` with the actual identifier from `flutter devices`. On a fresh checkout, dependency setup must first be agreed with the team; do not treat `--no-pub` as an installation command. Backend availability and credentials are supplied by the backend team. This guide does not authorize starting backend tests or modifying database records.

### VS Code

Use the Flutter and Dart extensions, select the configured SDK, and open `mobile/lib/main.dart`. Configure a mobile launch with working directory `mobile/` if the repository-root workspace does not discover it automatically. Start debugging with F5 and select the intended device. No launch/settings file was added in Phase 0.

VS Code and Codex extension files were observed locally. Flutter/Dart extension activation was not established: they were not present in the standard extension directory inspected. Verify the active VS Code profile. Installing the Flutter extension also installs Dart; do not install or change tooling without the user's approval. [Official VS Code setup](https://docs.flutter.dev/tools/vs-code).

Recommended Dart-only editor preferences are format-on-save and the Dart formatter (`Dart-Code.dart-code`). Keep broad automatic fixes and repository-wide formatting off for narrow changes.

### Emulator and physical device

- Use Android Studio Device Manager for a small and a standard phone AVD. Confirm detection with `flutter devices` before starting Flutter.
- The existing Android API client assumes the emulator host alias `10.0.2.2:3000`. A physical phone normally needs a different network arrangement; do not modify the protected API client to make a visual task work. Coordinate a supported connection with the backend/integration owner.
- Use emulator controls for known GPS locations and routes. `set_emulator_location.ps1` exists, but invoking it changes emulator location and may contact geolocation services; it was not run in Phase 0.
- On a physical device, enable USB debugging, authorize the host, and verify detection. Test brightness, touch reach, permission prompts, and outdoor map/metric readability while stationary. Physical-device performance is not inferred from emulator performance.
- iOS runtime checks require a Mac/Xcode environment; the Windows host can inspect the iOS display-name configuration only.

### Reload, restart, and inspection

Hot reload is for most widget/layout edits and preserves state. Hot restart reruns initialization and resets in-memory state. The current static-final theme objects may need hot restart to pick up initializer changes. Android/iOS display-name changes need a full native rebuild/relaunch. Do not restart a workout whose in-memory data must be retained. [Flutter reload behavior](https://docs.flutter.dev/tools/hot-reload).

Use the Widget Inspector to inspect constraints, padding, hierarchy, and overflow. Use repaint highlighting and DevTools performance profiling when diagnosing tracking/map rendering; evaluate performance on a supported physical device in profile mode. Do not change GPS/timer logic to solve a presentation issue. [Widget Inspector](https://docs.flutter.dev/tools/devtools/inspector).

## Validation workflow

From `mobile/`, with existing packages resolved:

```powershell
flutter analyze --no-pub
flutter test --no-pub
dart format --output=none --set-exit-if-changed lib test
```

For a focused test, append its path to `flutter test --no-pub`. The formatting command is read-only even when it prints "Changed". Format only authorized edited files when needed; do not rewrite protected models/services or unrelated screens. Existing lint/format failures are recorded in the Phase 0 report, not suppressed.

Before and after each task, inspect Git status. From the repository root, review:

```powershell
git diff --check
git diff --stat
git diff --name-only
git diff -- backend ai mobile/lib/services mobile/lib/models mobile/pubspec.yaml
git diff -- mobile
```

Also inspect staged changes if present, untracked documentation, and local lockfile changes. Preserve callbacks and data bindings in the actual hunks, not just the changed-file list.

### Screenshots and UI checks

1. Record SDK, device model, logical viewport, pixel ratio, text scale, locale, theme, and app state.
2. Capture the same screen before/after at 320, 360, and approximately 412 logical-pixel widths where available; include landscape, keyboard-visible forms, and 100%, 150%, and 200% text scaling.
3. Compare spacing, wrapping, clipping, contrast, focus, controls, and information order. Verify TalkBack labels and selected states.
4. Use fixed test fixtures for dates, distances, scores, and names. Live maps, GPS, and network-loaded fonts make full-screen golden comparisons unstable.
5. Begin golden tests with pure components using existing `flutter_test`. Do not call real auth, GPS, or activity-save services in presentation tests. Add test-only fixtures without changing production contracts.
6. Record untested devices/states explicitly. Phase 0 captured no emulator/device screenshots.

Use Codex for one bounded screen/component task, providing allowed files, protected methods, and acceptance criteria. Review its diff and the running UI together. Use a Git checkpoint per reviewed increment when authorized; no commits were made in Phase 0. [Codex IDE guidance](https://learn.chatgpt.com/docs/codex/ide).

## Supplied requirements versus verified behavior

The user supplied these capstone requirements: four activity modes; target distance/preferences; GPS starting location; route generation, suitability and selection; tracking; distance/time; pace for walking/jogging/running and speed for cycling; estimated remaining distance/time and calories; completion and history. Outdoor readability, accessible controls, accurate estimate labels, and clear errors are required.

The repository contains these broad flows, but does not establish reliable save confirmation, guest persistence, verified terrain/safety data, or robust GPS status reporting. Those gaps require team review. The full Chapter 1/2 paper has not been read because it is absent from the repository. Obtain the approved paper, usability rubric, target platforms/devices, and approved design references before later phases. A visual proposal is not proof of implemented behavior or an approved academic requirement.
