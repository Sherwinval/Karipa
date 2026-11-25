# Karipa current implementation status

Source review: **2026-11-25, Asia/Manila**. Scope: the repository attached to this chat. [Product](PRODUCT.md), [review addendum](KARIPA_MASTER_CONTEXT.md), [setup README](README.md), and applicable [mobile instructions](mobile/AGENTS.md).

This snapshot separates source behavior from execution evidence and approval. No builds, migrations, application tests, live API/provider calls, or device validation were run. The original master-context file was absent; the new master file records that gap rather than inventing its contents.

## Architecture

| Layer | Source-backed implementation | Limits |
| --- | --- | --- |
| Mobile | Flutter/Material 3, Provider/ChangeNotifier for auth/theme/units, screen-local tracking state, named routes through [main.dart](mobile/lib/main.dart) | Android is the primary target; platform folders are not tested support claims. No persistent recording service is established. |
| API | Express/TypeScript with auth, activities, routes, and AI routers in [server.ts](backend/src/server.ts); JWT middleware | Runtime availability, deployed versions, and actual credentials/configuration were not checked. |
| Storage | Prisma/PostgreSQL [schema](backend/prisma/schema.prisma); setup documents PostGIS in [database guide](docs/database-setup.md) | A schema or migration file does not prove deployment. Current generation calls Valhalla rather than performing PostGIS routing. |
| Location data | [AES-256-GCM envelopes](backend/src/lib/locationEncryption.ts) for nonempty saved GPS/route JSON | Reads accept legacy plaintext too; encryption of every existing row is not established. Guest SharedPreferences JSON does not use this encryption layer. |
| Connectivity | Central [API configuration](mobile/lib/config/api_config.dart), optional [tunnel discovery](backend/tunnel-discovery/README.md) | Network-dependent services remain necessary; discovery is not offline synchronization. |

## Implemented flows and limits

### Planned routes, routing providers, and maps

[Activity selection](mobile/lib/screens/activity_selection_screen.dart) offers walking, jogging, running, and cycling with either planning or Free Recording. [Planning](mobile/lib/screens/route_planning_screen.dart) obtains GPS and sends activity, target distance, and structured switches. Controls use 3–30 km and custom >30–100 km in 0.5 km increments. They remain km-based despite the unit setting. The screen does not expose the API's additional-notes or avoid-hills controls.

[Generation handler](backend/src/routes/routes.ts) accepts guests and accounts. [Routing service](backend/src/services/routingService.ts) constructs loop/out-and-back waypoint candidates and asks the configured Valhalla `/route` service for geometry, distance, and duration. Walking, jogging, and running share pedestrian costing; cycling uses bicycle costing. Validation checks geometry continuity, summary/geometry agreement, endpoint snapping, duplication, and target deviation. Default maximum deviation is **0.5 km**, configurable through `ROUTE_MAX_DISTANCE_DEVIATION_KM`. No surviving candidate produces an unavailable-route response; no fabricated geometry fallback is present.

[Ranking](backend/src/services/routeRankingService.ts) orders by absolute distance deviation, then available preference measurements and ID. The displayed score is a distance score, not a safety score. Generated features currently contain distance deviation, loop status, and empty road types; sidewalk/major-road/cycling-lane ratios are not populated by this generator. Costing options bias routing but do not verify those features, hills, shade, scenery, accessibility, or safety. Noncycling major-road avoidance is explicitly reported as unverifiable. Valhalla's pedestrian duration is not a personalized jogging/running forecast.

[Map widget](mobile/lib/widgets/route_map_widget.dart) uses `flutter_map` and `tile.openstreetmap.org`, route/track overlays, current location, and recentering. Tiles require connectivity; no offline map package is established. There is no explicit attribution overlay. Green/red endpoint markers remain despite palette-only language in older documents. This is a map and recording flow, not implemented route-progress map matching or turn-by-turn navigation.

### Optional AI assistance

[Groq service](backend/src/services/groqService.ts) calls Groq's OpenAI-compatible chat-completions endpoint. Default model identifier is `openai/gpt-oss-20b`, overridable by `GROQ_MODEL`; this is a Groq-hosted integration, not evidence of direct OpenAI API use. Enablement requires a key and `GROQ_ENABLED` not false. No secret values were inspected or reproduced.

The generation handler can interpret free-text preferences conservatively, preserving explicit switches, and explain an unavailable target. Ranking can request reasons and use AI order only among candidates within 0.05 km of the nearest deviation; `AI_ROUTE_RANKING_ENABLED=false` disables that ranking assistance. Invalid/unavailable AI falls back to deterministic behavior; Valhalla remains required. The mobile service accepts notes but current planning UI does not supply them. `suggestCandidateAdjustments` exists as a helper but is not called by the generation handler.

[AI endpoints](backend/src/routes/ai.ts) additionally expose authenticated route-characteristic recommendations and fitness insights through [controller](backend/src/controllers/aiController.ts). These are backend capabilities, not a mobile coaching screen wired in [navigation](mobile/lib/main.dart) or [mobile API service](mobile/lib/services/api_service.dart). The [legacy Python scorer](ai/main.py) mentions OSRM and scikit-learn but is not in the current Express generation call path. README's narrower AI wording is incomplete.

### Recording, review, persistence, and history

[Tracking screen](mobile/lib/screens/active_tracking_screen.dart) accepts a nullable planned route. Free Recording passes `free_recording` without a target/route; [backend validation](backend/src/routes/activities.ts) rejects either field in that mode. Both modes share observed GPS distance, active stopwatch, elapsed time, pause/resume, pace for walking/jogging/running, and cycling speed. Planned route distance is not substituted for observed travel. Remaining route distance and estimated finish time are explicitly unavailable because progress is not map-matched.

[Location service](mobile/lib/services/location_service.dart) rejects stale/future fixes and jumps above 35 m/s. Tracking rejects accuracy worse than 30 m; segment distance counts only positive time gaps up to 30 seconds and movement at least 1.5 m. These filters are not proof of GPS accuracy. Timers can count while GPS is unavailable; active duration is not automatically moving time. Leaving foreground pauses except for the `inactive` lifecycle state, which is ignored; manual resume restarts recording. No background-service implementation, durable draft, or crash/process-death recovery is established.

Finish stops recording and opens [review](mobile/lib/screens/activity_complete_screen.dart); **Save is explicit**. Review distinguishes pending, error/retry, server-confirmed save, local save, and discard. Data remains in memory before save. [API service](mobile/lib/services/api_service.dart) branches on a stored token: no token saves JSON under `guestActivities` in SharedPreferences with local idempotency; a token submits to the account API. Account failure is not silently saved locally and has no durable retry queue. Guest data is not automatically uploaded after sign-in, and account history replaces the guest history source while authenticated. Guest profile lookup returns null height/weight, so live guest calorie estimates lack weight.

[Activity API](backend/src/routes/activities.ts) scopes CRUD to the authenticated owner, stores timing, metrics, optional calorie basis, GPS and route summary, and handles repeated per-user idempotency keys (also constrained in [schema](backend/prisma/schema.prisma)). This confirms code paths, not successful persistence in a deployed database. [History](mobile/lib/screens/activity_history_screen.dart) and [details](mobile/lib/screens/activity_details_screen.dart) support review/deletion. Completion persists route summary without geometry, while details attempts to read `routeData.geometry`: planned-route reconstruction is incomplete, although recorded GPS is separate.

The independent route-save API stores metrics with empty route data; [RoutesScreen](mobile/lib/screens/routes_screen.dart) is a placeholder and is not registered as a saved-route destination in main.dart. Do not describe a complete reusable saved-route library. Split storage exists in the schema/API, but this recorder does not submit kilometer splits.

### Accounts, profiles, units, themes, and leaderboard

[Auth API](backend/src/routes/auth.ts) and [mobile auth](mobile/lib/services/auth_service.dart) implement registration, email OTP, login, remembered sessions, and logout. Email delivery depends on [email service](backend/src/services/emailService.ts) configuration. Startup restores locally stored session state; that is not fresh server validation of token validity. [Profile UI](mobile/lib/screens/profile_screen.dart) and API implement name, photo, optional height/weight, and profile refresh using ETags. Measurements persist as cm/kg. Photo upload is bounded; the UI rejects files above 2.5 MB. These are implemented paths, not verified device/media or SMTP results.

[Unit preferences](mobile/lib/services/unit_preferences.dart) persist metric/imperial locally and convert distance, speed, pace, height, and weight for participating screens. Planning remains kilometers. [Theme service](mobile/lib/services/theme_service.dart) and main.dart wire an in-memory light/dark selection, contradicting the older forced-light description. Theme choice is not persisted and defaults to light on restart.

The [weekly leaderboard](backend/src/routes/activities.ts) requires authentication and includes verified accounts with positive saved distances completed since Sunday midnight **Asia/Manila** through now ([period helper](backend/src/lib/weeklyLeaderboardPeriod.ts)). It combines all four activities and both recording modes, orders distance descending then name/user ID for ties, and returns the top 50 plus the current user's qualifying row. [Leaderboard screen](mobile/lib/screens/leaderboard_screen.dart) handles display/access states. No guest totals, activity balancing, independent GPS verification, or anti-cheat guarantee is established.

## Calories: implementation and academic boundary

[Mobile estimator](mobile/lib/services/calorie_estimation_service.dart) and [server validator](backend/src/services/calorieEstimationService.ts) use **gross session kcal = MET × kg × active minutes / 60**, rounded to two decimals, version `karipa-proposed-met-v1`. Gross includes resting expenditure; this is not net activity energy or clinical measurement. Valid weight, at least 50 m, 5 active seconds, and two accepted fixes gate mobile estimates. Height is not used. Category labels and test wording that call values “published” do not establish academic acceptance or verify their bibliography.

| Activity | Mobile mapping and live coverage | Backend acceptance |
| --- | --- | --- |
| Walking | Helper has code 17190 / 3.8 MET at 2.8–3.4 mph only with confirmed level firm ground. Live estimator never supplies that confirmation, so unavailable. | No walking mapping accepted for calorie metadata; null calories are allowed. |
| Jogging | Code 12020 / 7.5 MET; general self-selected category with no extra speed band after movement/weight gates. | Accepted only with complete basis, valid speed consistent with distance/time, and at least two GPS entries. Current mobile save mismatch below blocks such saves. |
| Running | Code 12030 / 8.5 MET only at average 5.0–5.2 mph. Other running speeds yield unavailable. | Same band and basis checks; current mobile save mismatch below applies. |
| Cycling | Helper has code 01010 / 4.0 MET below 10 mph only with confirmed leisure context. Live estimator never supplies confirmation, so unavailable. | No cycling mapping accepted for calorie metadata; null calories are allowed. |

**Source-backed contract discrepancy:** tracking sends `averageSpeedKmh` only for cycling, and sends null for jogging/running. Completion forwards that value unchanged. The backend requires positive finite `averageSpeedKmh` whenever calorie metadata is submitted. Therefore a jogging/running recording with an available mobile estimate is expected to receive a validation error on account save. This conclusion follows the call chain; it was not reproduced in an application test. Standalone server tests provide speed explicitly and do not prove this mobile contract works.

The backend recalculates submitted calories and checks metadata completeness/version, duration and speed consistency. It does not independently derive distance from GPS entries or verify the submitted weight against current profile weight. Mobile minimum movement thresholds are stronger than the backend's positive-distance/duration checks. No adviser approval, validated all-four-activity method, or medical accuracy evidence was found in the reviewed material; tracking explicitly says adviser review is pending.

## Design conflicts and historical discrepancies

| Reference | Conflict with current source | Status |
| --- | --- | --- |
| [mobile instructions](mobile/AGENTS.md), [design system](docs/karipa-design-system.md) | Specify coral `#FF5A49` and midnight `#0C0B10`; [live tokens](mobile/lib/theme/design_tokens.dart) use coral→orange `#FF5A24`, midnight→navy `#1A1E27`, plus Home `#F6F5F1`. | Unresolved approval/reference conflict. No palette chosen by this review. |
| Design-system foundation | Describes ivory page, five colors, forced light, no green/red map hue. Current theme uses white light content, an active toggle, and map marker colors outside that palette. | Historical scope is outdated; old contrast ratios cannot certify current colors. |
| [Palette report](docs/frontend-palette-report.md) | White/supporting beige and toggle align in part, but its exact coral value differs from live tokens. | Preserve report as a historical observation, not current palette proof. |
| Older phase scope/adoption statements | Later Home/shared-screen implementations and selection/recording flows exist. | Phase instructions quoted in documents are historical, not a new authorization. |
| [Mobile README](mobile/README.md) | Project link points to `../README.md#setup`, while root README uses “Quick start.” | Known pre-existing anchor mismatch; outside this edit scope. |

## Validation evidence and gaps

Test definitions exist for [mobile calories](mobile/test/calorie_estimation_test.dart), [backend calories](backend/src/tests/calorieEstimation.test.ts), [routing/ranking](backend/src/tests/routingService.test.ts), [Groq](backend/src/tests/groqService.test.ts), [activity validation](backend/src/tests/activityValidation.test.ts), [API](backend/src/tests/api.test.ts), [GPS segments](mobile/test/gps_segment_distance_test.dart), [local history](mobile/test/local_activity_history_test.dart), [completion](mobile/test/activity_complete_screen_test.dart), [units](mobile/test/unit_preferences_test.dart), [profiles](mobile/test/profile_measurements_display_test.dart), [leaderboard](mobile/test/leaderboard_screen_test.dart), and [design system](mobile/test/design_system_test.dart). These show intended coverage, not current passing results. Calorie helper tests explicitly unlock walking/cycling context while live recording does not; arithmetic examples are not four-activity integration coverage or academic validation.

The historical [palette report](docs/frontend-palette-report.md) records a debug build/emulator inspection, 103 tests passing and three failing (splash timer and two recommendation overflow cases), and 23 analyzer informational diagnostics. Those are attributed historical results, not rerun or confirmed against this checkout. It explicitly excludes live GPS/persistence and several device/accessibility states. No fresh test-pass claim is made here.

Current review validation is limited to source inspection, relative-link checking for these three documents, Markdown diff/whitespace review, and checking the final changed-file scope. Deployment/database state, real Valhalla coverage, Groq availability, SMTP, foreground lifecycle/device GPS accuracy, process-death behavior, account save round-trips, media selection, TalkBack/VoiceOver, sunlight readability, and current contrast require later authorized validation.

## Prioritized next steps (proposed, not approval)

1. **Persistence blocker:** resolve the jogging/running calorie speed contract at the responsible layer, then validate full mobile-to-account saves with available and unavailable calories, retries, and all four activities. This documentation task does not authorize code changes.
2. **Academic decision:** confirm the gross-versus-net method, category citations, speed/context requirements, and adviser acceptance. Decide how walking/cycling evidence could support estimates; retain unavailable values until that decision is implemented and validated.
3. **Design decision:** reconcile the orange/navy/Home tokens with mobile instructions and design references, then recheck contrast, markers, and narrow/enlarged-text layouts using the confirmed palette. Do not silently reinterpret historical approval.
4. **Routing validation:** verify real regional Valhalla coverage, costing behavior and preference limits, target tolerance outcomes, pedestrian duration wording, map attribution, and network-failure handling. Decide whether notes/AI endpoints should be exposed in mobile; no new AI scope is approved here.
5. **Recording/storage validation:** verify foreground/pause/manual-resume, permission loss, poor GPS, explicit review/discard, guest versus account history, expired tokens, and deletion on a device. Decide reusable planned-route geometry/library scope and whether draft recovery, guest import, or offline synchronization belong on the roadmap.
6. **Evidence upkeep:** recover/reconcile missing master history if available; after separately authorized checks, update this snapshot with dated actual results and reconcile stale setup/design references without rewriting historical phase reports.
