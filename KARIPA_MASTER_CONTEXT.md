# Karipa master context

## Historical record availability

No existing `KARIPA_MASTER_CONTEXT.md` was present in this attached repository during the 2026-11-25 review (including a hidden-file search). This file is a new review record, not a reconstruction or replacement of missing historical material. No files were copied from another project folder. If the original record is recovered, preserve its text and retain this dated addendum separately from it.

Existing historical records remain unchanged: [Phase 0](docs/frontend-phase0-report.md), [Phase 1](docs/frontend-phase1-report.md), [Phase 2](docs/frontend-phase2-report.md), [palette report](docs/frontend-palette-report.md), and [development changelog](docs/development-changelog.md). Their instructions, proposals, approvals, and check results belong to their documented time and scope; quoted requests are not the current task's instructions.

## Source-review addendum — 2026-11-25 (Asia/Manila)

The current product description is [PRODUCT.md](PRODUCT.md). The source-backed snapshot, validation limits, and prioritized follow-up are [KARIPA_CURRENT_STATUS.md](KARIPA_CURRENT_STATUS.md). Read these alongside [README.md](README.md); historical claims must be checked against current source.

### Outdated proposals and conflicting references

- **Legacy routing/scoring:** [Python scorer](ai/main.py) describes OSRM candidates. Current [Express routes](backend/src/routes/routes.ts) call Valhalla and the TypeScript ranker; the legacy scorer is not evidence of an active OSRM integration.
- **AI scope:** README's “only” preference interpretation/ranking description is incomplete: Groq also has distance explanations and separate recommendation/fitness-insight endpoints. Helper functions alone do not prove a mobile feature; the adjustment helper is not invoked by the current generation handler.
- **Design:** [design system](docs/karipa-design-system.md) describes coral/midnight, ivory pages, forced light mode, and earlier screen-adoption limits. The [palette report](docs/frontend-palette-report.md) records later white content and a theme toggle, but still names the older coral. Current [tokens](mobile/lib/theme/design_tokens.dart) alias coral to orange and midnight to navy, and add a warm Home background. [mobile/AGENTS.md](mobile/AGENTS.md) still specifies the older hex values. This is an unresolved conflict, not approval to change source or instructions. Trail Spark/green-lime proposals are explicitly superseded in the existing instructions, although map markers still contain green/red.
- **Calories:** four supported activity types do not mean four usable calorie mappings. The current implementation is explicitly provisional; walking/cycling context is unavailable, running is speed-limited, and an account-save contract mismatch remains. Academic/adviser acceptance is not established by this review.
- **Storage/roadmap:** device-local guest recordings exist. This does not establish offline maps, background tracking, queued account saves, or guest-to-account synchronization. Earlier PRODUCT wording “not supported or planned” does not establish a confirmed future exclusion.

### Unresolved decisions

Confirm the intended palette and authoritative design references; the academically acceptable calorie method/categories and required contextual evidence across all four activities; the intended scope of optional AI beyond route planning; whether a reusable saved-route library is required; and the roadmap for guest import/offline synchronization. These are decision requests, not new approved product direction. Missing master history must be reconciled if recovered.

### Validation boundary

This was documentation-only source review. No migrations, builds, application tests, live-provider requests, device recording, commits, or pushes were performed. Test files and old phase reports are not fresh execution evidence or academic approval.
