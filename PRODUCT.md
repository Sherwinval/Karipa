# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

People preparing for or starting an outdoor workout who want to plan and track a walk, jog, run, or cycling activity. They choose an activity, target distance, and route preferences.

## Product Purpose

Karipa brings route planning and activity tracking together so users can find a route that fits their activity and distance, follow it, and track their workout without confusion.

## Positioning

Karipa combines planned routes and Free Recording Mode across walking, jogging, running, and cycling. Valhalla calculates planned geometry and distance; verification means source-level routing and validation checks, not a guarantee of safety or real-world accessibility. No comparative or exclusive market claim has been established.

## Operating Context

Users either plan a route or start recording without a route or target. Recording requires the app in the foreground; leaving it pauses counting and requires manual resume. Online services are needed for route generation, map tiles, account records, and leaderboard access. Device-local guest saves are distinct from offline synchronization.

## Capabilities and Constraints

- All four activities have planning and recording entry points. Planning uses current GPS, target distance, and structured preferences. The current distance controls use kilometers (3–30 km, custom above 30 through 100 km in 0.5 km steps), even when imperial display units are selected.
- Valhalla uses pedestrian costing for walking/jogging/running and bicycle costing for cycling. Candidates are validated and deduplicated, then filtered by a configurable distance tolerance (default ±0.5 km). Requests can return no suitable route. Preference switches are routing biases, not verified terrain, sidewalk, safety, shade, or scenery guarantees.
- Maps use Flutter Map with OpenStreetMap tiles. Planned and recorded tracks are displayed; route-progress map matching, remaining distance, and finish-time estimation are unavailable. The map widget has no explicit attribution overlay.
- Optional Groq assistance interprets notes, explains candidates/unavailable distances, and can order near-distance ties. Valhalla remains authoritative. Deterministic routing/ranking continues without Groq. Separate AI recommendation/insight endpoints exist, but are not a wired mobile coaching feature.
- Free Recording Mode skips route generation and target distance. Foreground GPS recording supports pause/resume, active versus elapsed time, distance, and pace or cycling speed. Finish opens review; saving is explicit and can fail. There is no durable in-progress recovery or background tracking guarantee.
- Guests save completed recordings in device SharedPreferences. Signed-in saves and history use the authenticated API/database. Guest records are not automatically imported or synchronized to an account; failed account saves have no offline queue.
- Registration, login, email OTP verification, remembered sessions, and profile name/photo/height/weight editing have source implementations. Guest profile measurements are unavailable. SMTP delivery and session validity depend on services/configuration.
- Metric/imperial display preferences persist locally. A light/dark toggle is wired, but theme choice is held in memory and defaults to light on restart. Internal activity/profile values retain metric units; conversion is not universal (planning remains in km).
- The authenticated weekly leaderboard sums saved positive distances across all four activities and both recording modes for verified accounts, from Sunday midnight Asia/Manila to now. It returns the top 50 plus the current user's qualifying row. Guest/unsaved recordings are excluded; no activity normalization or GPS anti-cheat verification is established.
- Provisional gross calorie estimation uses MET × weight in kg × active minutes / 60, not net exercise calories. Jogging has a general 7.5 MET mapping; running uses 8.5 MET only at 5.0–5.2 mph. Walking and cycling remain unavailable in the live estimator because required context is unconfirmed. Valid weight and measured movement are required. A mobile/backend speed-contract discrepancy can prevent account saves containing jogging/running estimates; see the status document.
- Offline synchronization is absent. Earlier wording that it is “not planned” is not evidence of a confirmed roadmap decision.
- Preserve existing Flutter patterns and Android conventions. Saved-route library support is incomplete; an API save stores summary metrics without usable geometry.

## Brand Commitments

The product name is Karipa.

Current source tokens use orange `#FF5A24`, navy `#1A1E27`, white content, warm Home `#F6F5F1`, stone, ivory, and charcoal. These conflict with coral `#FF5A49` / midnight `#0C0B10` in [mobile instructions](mobile/AGENTS.md) and older design references. This documents implementation, not approval of a replacement palette.

## Evidence on Hand

- This 2026-11-25 review inspected [mobile navigation](mobile/lib/main.dart), [routing](backend/src/services/routingService.ts), [recording](mobile/lib/screens/active_tracking_screen.dart), and [persistence](mobile/lib/services/api_service.dart). Detailed evidence, discrepancies, and test-source links are in [current status](KARIPA_CURRENT_STATUS.md).
- Source implementation and test definitions are evidence of intended behavior, not a passing runtime result. No builds, migrations, application tests, or device sessions were run for this review. Historical reports retain their original validation scope.
- MET mappings and their academic/adviser approval remain unresolved; the source explicitly calls them provisional. No academic acceptance is inferred from code, test examples, or historical design approval language.
- No customer testimonials or quantified outcome claims were supplied; do not invent them.

## Product Principles

- Give all four supported activity types equal product consideration.
- Let activity, target distance, and route preferences guide route planning.
- Explain Valhalla validation and distance matching without promising safety or exact requested distance.
- Make foreground tracking, device-local guest storage, and lack of account offline synchronization clear.
- Display unavailable measurements honestly; all-four-activity recording does not imply all-four-activity calorie coverage.

## Accessibility & Inclusion

Follow standard Android accessibility practices, including readable contrast, scalable text, accessible control labels, and comfortable outdoor controls. These are requirements, not accessibility certification. Older contrast calculations used different palette values and must not be applied to current tokens without revalidation. See [source-review history](KARIPA_MASTER_CONTEXT.md) and [current status](KARIPA_CURRENT_STATUS.md) for unresolved evidence and approval boundaries.
