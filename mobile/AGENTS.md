# Karipa frontend instructions

## Identity and scope

- PathCraft is the academic/technical project: AI-Assisted Multi-Activity Route Generator and Fitness Tracking System. Karipa is the user-facing mobile brand, derived from *karipas* and associated with movement, effort, determination, and reaching a target distance.
- Give walking, jogging, running, and cycling equal prominence. Do not assume every user is a runner.
- The project owner's responsibility here is Flutter frontend development and mobile UI/UX: presentation, layouts, reusable visual components, responsive behavior, accessibility, and visual interactions.
- Current authorization is a frontend-wide color update: white light-mode content, the existing ivory/beige on supporting surfaces, and coral primary actions. Preserve layouts, content, routes, interactions, data bindings and the existing theme toggle. Dark mode remains available. This supersedes the previous Home-only color scope; it does not authorize other screen redesigns or functional changes.
- The approved identity is white `#FFFFFF`, coral `#FF5A49`, midnight `#0C0B10`, stone `#CFCDBE`, ivory `#E3E0D3`, and charcoal `#2B2B2B`. Use semantic theme roles for surfaces and readable foregrounds. Trail Spark and previous green/lime proposals are superseded. Preserve geographic map tiles and necessary platform behavior.
- See [frontend guide](../docs/frontend-development.md), [approved design system](../docs/karipa-design-system.md), and the historical [Phase 0 report](../docs/frontend-phase0-report.md). Later explicit user instructions define the active phase and scope.

## Protected boundaries

- Inspect, but do not modify, repository-root `backend/`, `ai/`, database configuration, Prisma schemas/migrations, `mobile/lib/services/`, or `mobile/lib/models/` during frontend work.
- Business logic remains protected even when embedded in a screen: authentication, API/HTTP contracts, GPS permissions/subscriptions/calculations, route generation/ranking, timers, activity persistence, and saving/error-result handling.
- Preserve callbacks, navigation destinations, route arguments, state transitions, data bindings, lifecycle ownership, and integrations. Do not move service calls into `build` or presentation widgets.
- Report any required functional change separately for team review. Do not hide a functional fix inside styling or copy changes.
- Preserve `pathcraft_mobile`, `PathCraftApp`, `PathCraftColors`, Android application ID, iOS bundle identifier, route names, repository identity, and backend names. Rebrand selected displayed strings, never global-replace identifiers.
- Native platform rebranding is limited to the Android application label and iOS `CFBundleDisplayName`. Inspect and report unexpected configuration before altering other keys.
- Do not add/remove/upgrade dependencies, introduce assets, run migrations/backend tests, or commit/push without explicit task authorization.

## Flutter and Dart conventions

- Use the existing Flutter/Material 3 stack. Keep Provider/ChangeNotifier for existing authentication state and existing local screen state; no state-management or router migration for a visual task.
- Retain `MaterialApp.onGenerateRoute`, existing navigation stack behavior, and argument contracts. Do not add a persistent tab shell or wire unused screens without functional approval.
- Prefer small `StatelessWidget` presentation components receiving typed values and existing callbacks. Retain `StatefulWidget` where lifecycle or interaction state already belongs.
- Use null-safe Dart, `final` fields, `const` constructors where valid, `UpperCamelCase` types, `lowerCamelCase` members, and `snake_case.dart` files.
- Preserve meaningful missing values; do not fabricate metrics or change model parsing. Avoid new `dynamic` interfaces when ordinary typed parameters suffice.
- Use `ThemeData`, `ColorScheme`, text themes, and approved theme-extension tokens. Prefer Material component themes to repeated per-screen styles. Do not apply unapproved palette proposals.
- Extract repeated rendering only when reuse improves clarity. Keep screen-specific widgets near their screen until shared. Avoid speculative abstractions and new architectural layers.
- Measure rebuild/repaint costs before optimizing. Preserve map-controller identity, subscription ownership, and timers during presentation extraction.

## UI and accessibility expectations

- Prioritize outdoor readability, clear hierarchy, and comfortable touch controls. Use at least 48 logical-pixel interactive targets and larger workout controls where practical.
- Support small widths, landscape, keyboard insets, safe areas, long content, and enlarged text. Use constraint-based `LayoutBuilder`, `Flexible`/`Wrap`, and `MediaQuery` where appropriate; do not suppress user text scaling to fit content.
- Use accessible labels/tooltips for icon-only actions and semantics for selected states and metrics. Do not rely on color alone. Avoid announcing live timers every second.
- Check text contrast (target at least 4.5:1 for ordinary text) and meaningful control/graphic contrast. Test TalkBack; test VoiceOver when an iOS environment is available.
- Respect reduced-motion settings. Use restrained native Flutter transitions without a new animation library.
- Distinguish loading, empty, error, success, paused, and disabled states using existing state. Report missing operational state to the team rather than inventing it.
- Recommendation scores are preference/suitability information, never safety guarantees. GPS measurements, remaining distance/time, duration forecasts, and calories require appropriate estimate wording. Do not claim successful persistence or high GPS accuracy without supporting state.
- Keep a readable map summary, distinct route/track treatments, and attribution. Changes to follow/recenter behavior require separate review.

## Validation and review

- Inspect initial Git status and relevant code before editing. Respect pre-existing changes.
- Use the installed SDK; do not upgrade packages as part of checks. With existing dependencies resolved, run `flutter analyze --no-pub` and relevant `flutter test --no-pub` checks from `mobile/`.
- Use `dart format --output=none --set-exit-if-changed lib test` for a read-only baseline. Its output can say "Changed" although no files are rewritten. Do not bulk-format protected files or unrelated code.
- Compare before/after diagnostics. Record existing failures separately from regressions; do not weaken tests or alter app behavior to conceal a baseline failure.
- Test changed components at small/standard widths, enlarged text, keyboard-visible states, and relevant empty/loading/error states. Use fixed fixtures for visual comparisons, avoiding dependence on live tiles, dates, or GPS.
- Before handoff, inspect `git diff --check`, `git diff --stat`, `git diff --name-only`, and full changed hunks. From the repository root, explicitly inspect `git diff -- backend ai mobile/lib/services mobile/lib/models mobile/pubspec.yaml` and check native changes are display-name values only.
- Review staged changes too if any exist. Include untracked files in the review. Verify local lockfile contents remain unchanged when using `--no-pub`.
- Report commands, actual outcomes, device limitations, and files changed. A passing source check does not establish Android/iOS runtime behavior. Stop at the authorized phase boundary.
