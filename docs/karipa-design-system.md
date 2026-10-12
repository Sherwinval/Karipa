# Karipa Flutter design system

Approved identity implemented in Phase 1; updated 2026-10-11 (Asia/Manila). The project and mobile application share the Karipa identity. The previous green/lime Trail Spark direction and all Phase 0 candidate palettes are superseded.

This is a shared presentation foundation, not a completed screen redesign. See [frontend instructions](../mobile/AGENTS.md) and the [Phase 1 report](frontend-phase1-report.md) for scope, file inventory, validation, and limitations.

## Identity and exact palette

Karipa expresses movement, determination, and personal progress with an editorial type hierarchy, dark metric panels, warm neutral cards, and coral actions. Give walking, jogging, running, and cycling equal prominence. Use original composition and the existing text wordmark; no logo or new asset was created.

`lib/theme/design_tokens.dart` is the single source of brand hex values:

| Token | Exact value | Main use |
| --- | --- | --- |
| `KaripaPalette.coral` | `#FF5A49` | Primary actions, selected fills, planned route highlights |
| `KaripaPalette.midnight` | `#0C0B10` | Dark dashboard/panel base, text on coral, route casing |
| `KaripaPalette.stone` | `#CFCDBE` | Light cards, neutral badges, dark-theme secondary content |
| `KaripaPalette.ivory` | `#E3E0D3` | Light page, text on dark panels, recorded-track casing |
| `KaripaPalette.charcoal` | `#2B2B2B` | Supporting dark text/borders, dark cards |

No mint, green, teal, extra semantic hue, or generated seed palette was added. Geographic tile imagery remains unchanged. Material's ordinary focus/pressed state layers and theme interpolation may composite these colors; they are interaction effects, not new identity tokens. Any additional semantic/accessibility color needs user approval.

## Material roles

`AppTheme` explicitly constructs the complete modern ColorScheme rather than deriving tonal variations with `fromSeed`. `KaripaColors` remains the ThemeExtension name; its constructor, fields, copy/lerp behavior, and old `lime` identifier remain compatible. That legacy field now resolves to coral. New code should use semantic roles instead of the old color-named alias.

| Role | Light foundation | Dark foundation |
| --- | --- | --- |
| `primary`, `primaryContainer` / foreground | Coral / midnight | Coral / midnight |
| `secondary` / foreground | Charcoal / ivory | Stone / midnight |
| Secondary/tertiary containers / foreground | Stone / midnight | Charcoal / ivory |
| `tertiary` / foreground | Stone / midnight | Stone / midnight |
| Page `surface` / `onSurface` | Ivory / midnight | Midnight / ivory |
| Card/container surfaces / text | Stone / midnight | Charcoal / ivory |
| `onSurfaceVariant`, `outline` | Charcoal | Stone |
| Error / `onError` | Charcoal / ivory | Coral / midnight |
| Error container / text | Stone / midnight | Charcoal / ivory |
| Inverse surface / text | Midnight / ivory | Ivory / midnight |
| Disabled primary/secondary button / text | Stone / charcoal | Charcoal / stone |
| Selected navigation indicator / icon | Coral / midnight | Coral / midnight |
| Metric panel / text (extension) | Midnight / ivory | Midnight / ivory |
| Planned route / casing (extension) | Coral / midnight | Coral / midnight |
| Recorded track / casing (extension) | Midnight / ivory | Midnight / ivory |

Fixed roles also use the five approved colors, with dark text on coral/stone. Surface variants deliberately repeat neutrals instead of introducing additional tones. Borders, labels, and structure provide hierarchy.

Error, success, warning, information, and empty feedback are distinguished by explicit messages and different Material icons. Do not imply success, accurate GPS, or saved data from a decorative color. No green-success/red-error palette is introduced. On a light surface, use dark error text with an error message and stronger border; coral text would not pass ordinary text contrast.

Both theme foundations are implemented and component-tested. `main.dart` still forces light mode; neither app-wide dark-mode activation nor a Home redesign is part of Phase 1. A later dark dashboard should receive `AppTheme.darkTheme` through a local Theme so labels and controls inherit suitable foregrounds.

## Contrast and accessibility

Computed from opaque sRGB colors using WCAG relative luminance. Ratios are symmetric and rounded to two decimals:

| Pair | Ratio | Decision |
| --- | --- | --- |
| Midnight / coral | **6.36:1** | Primary-button labels and selected content |
| Ivory / midnight | **14.82:1** | Large and small dashboard text |
| Charcoal / ivory | **10.70:1** | Supporting text, controls, borders on light pages |
| Charcoal / stone | **8.85:1** | Card text and disabled-label pairing |
| Coral / charcoal | **4.59:1** | Passes normal text narrowly; prefer ivory for dense dark-card text |
| Coral / ivory | **2.33:1** | Fails ordinary text and 3:1 control/graphic contrast |
| Coral / stone | **1.93:1** | Fails ordinary text and 3:1 control/graphic contrast |
| White / coral (rejected comparison, not a token) | **3.08:1** | Fails ordinary text; do not use for primary buttons |
| Stone / ivory | **1.21:1** | Decorative surface separation only; not an essential control boundary |

Coral-filled actions, selections, and navigation indicators have contrasting outlines when needed. Light-theme text buttons use dark text. Focus increases the action border to 3 pixels. Use text/icons/checkmarks alongside selection and status color. Standard guidance is at least 4.5:1 for ordinary text, 3:1 for meaningful non-text graphics, and at least 48 logical pixels for interactive targets. [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [Flutter accessibility guidance](https://docs.flutter.dev/ui/accessibility).

Tests check semantic color pairings and representative rendered button contrast. They do not certify sunlight readability or arbitrary tiles. Review glare, brightness, color vision, TalkBack/VoiceOver, physical touch reach, and actual fonts on supported devices before shipping.

## Typography

Existing `google_fonts` supplies Manrope and Inter; no package or font asset was added. Manrope provides expressive headings and prominent statistics, while Inter handles route information, body copy, and controls. Type sizes are logical pixels and scale with user settings.

| Theme styles | Font / weight | Size | Use |
| --- | --- | --- | --- |
| `displayLarge/Medium/Small` | Manrope 800 | 48 / 40 / 36 | Dashboard headline, wordmark treatment, major metrics |
| `headlineLarge/Medium/Small` | Manrope 800 | 32 / 28 / 24 | Screen/section titles and standard metric value |
| `titleLarge/Medium/Small` | Inter 700 | 22 / 18 / 16 | Route/card headings and compact titles |
| `bodyLarge/Medium/Small` | Inter 400 | 18 / 16 / 14 | Main, supporting, and explanatory content |
| `labelLarge/Medium/Small` | Inter 700 / 600 / 600 | 16 / 14 / 14 | Actions, navigation, badges, units |

Manrope line height is 1.15 with restrained negative tracking; Inter line height is 1.4. Metric tiles use tabular figures where supported. `prominent: true` uses a 40-pixel value on midnight; ordinary tiles use 24-pixel values. Units are separate readable lines to avoid compressing large values into small half-width cards. Do not shrink user text or use ellipsis to hide workout values.

The app retains its existing Google Fonts runtime loading behavior. Component tests call `AppTheme.buildTheme(useGoogleFonts: false)` to keep network access out of the harness; Flutter test fonts are not an actual Manrope/Inter visual proof. Font bundling/offline guarantees require separate asset approval and testing.

## Spacing, shape, and layout

| Tokens | Values / guidance |
| --- | --- |
| `AppSpacing` | 4, 8, 12, 16, 24, 32, 48 |
| `pageMargin(width)` | 16 below 360 logical pixels, 24 otherwise |
| Control / panel / card radii | 12 / 16 / 24 |
| Buttons | Minimum 56 high, 48 wide; vertical padding lets long/scaled text grow |
| Other touch targets | At least 48 by 48 |
| Navigation | 80-pixel theme baseline, visible labels; review larger text in each screen |
| Content maximum | Suggested 640-pixel centered column for expanded layouts |
| Cards / metric padding | 16, or 24 for explanatory feedback |
| Map overlays | Opaque approved neutral, 12-pixel insets, 48-pixel recenter control |

Use `SafeArea`, constraint-based widths, `Expanded`/`Flexible`, `Wrap`, and scrollable content at the screen boundary. New components have no fixed text height. Route metrics and button contents wrap; badges accept finite-width constraints. Activity cards need a bounded width. Map preview slots need a caller-supplied finite height.

A reusable component cannot fix an unconstrained parent Row or fixed-height screen. Legacy screen layouts still need review when migrated. Do not claim full-screen accessibility from isolated component checks.

## Shared components and adoption

| Component | Contract / behavior |
| --- | --- |
| `KaripaButton` / `.secondary` | Label, optional icon, existing nullable callback; caller-owned `isLoading` disables interaction and adds an in-progress description. No async work or navigation inside. |
| `MetricTile` | Existing label/value/unit/icon/color parameters preserved; optional `prominent` flag added. One combined semantics label, no live timer announcements. No metric calculations. |
| `StatusBadge` | Existing text/color/icon parameters preserved; wraps text under finite constraints, uses an opaque approved pair. |
| `ActivitySelectionCard` | Label, optional description, existing icon, selected state, nullable callback; renders a check and selected/button semantics. No mode changes inside. |
| `RouteRecommendationCard` | Caller-formatted distance/duration/suitability/explanation, optional recommendation badge and map slot, nullable action; never computes scores or owns route navigation. |
| `SectionHeading` | Title with heading semantics and optional subtitle. |
| `KaripaFeedback` | Information/success/warning/error/empty kind selects an icon; title/message and optional labelled recovery callback supply real meaning. |
| `KaripaProgress` | Supplied operation label and optional real 0–1 value. Null means indeterminate. Reduced motion replaces an indeterminate animation with a static hourglass, not a fabricated percentage. |
| `RouteMapWidget` | Existing interface/controller/location updates/camera behavior retained. Only route/marker colors, casing, neutral recenter styling, spacing, and accessibility labels changed. |

`MetricTile.color` and `StatusBadge.color` still compile at all existing call sites. Approved palette colors are accepted; previous decorative teal/blue/orange/etc. arguments are normalized to coral for metric accents and stone for badge fills. Foregrounds are chosen from the approved palette. Do not use color arguments to encode status meaning without text/icon equivalents.

The theme also styles Filled/Elevated/Outlined/Text/Icon buttons, AppBar, Card, inputs, NavigationBar, BottomNavigationBar, chips, progress, FAB, checkbox, switch, divider, snackbar, and text selection. Native Material components provide keyboard/focus behavior; no duplicate navigation component or state framework was introduced. [Flutter ColorScheme roles](https://api.flutter.dev/flutter/material/ColorScheme-class.html).

The new standalone components are ready for later screen adoption; they have not been wired into screen flows. Existing map/metric/badge callers and components that inherit the theme receive shared styling now. Per-screen hardcoded green/teal remains until the approved screen migration. Do not bulk-replace those colors or alter embedded business logic.

## Maps

The planned route uses coral with a midnight casing; the recorded track uses midnight with ivory casing. Their core/casing contrast is 6.36:1 and 14.82:1 respectively. Play/flag symbols distinguish endpoints, and current position retains the existing concentric-dot geometry. No tile URL, coordinates, GPS subscription, camera-follow behavior, controller identity, or recenter callback was changed.

Check route overlap, parks, water, dense roads, and map labels in the later device review. Casing contrast is not a promise of visibility against every tile. Existing map attribution presentation also needs review before release; the existing widget has no explicit attribution overlay, and Phase 1 did not add one.

## Future screen directions — not implemented

- **Home:** locally apply the midnight theme, large Manrope headline, coral existing primary action, a small number of prominent metrics, and warm cards. Preserve existing data sources, guest conditions, routes, and bottom-navigation callbacks.
- **Planning:** equal activity choices, generous target-distance controls, coral selection with checks/borders, and clear preference grouping. Preserve location and API handling.
- **Recommendations:** consistent distance and estimated duration order, labelled suitability, route cards, and visually separated map previews. Do not claim safety from a recommendation score.
- **Tracking:** distance and timer first, prominent units, large pause/finish controls, readable opaque overlays, and estimate wording. Preserve timer/GPS/calculation/save ownership.
- **History:** readable dates, activity type, distance and time, consistent records, and truthful empty/error states from existing state.

For Phase 2, start with Home only after approval: inspect its current states, draft the hierarchy using these tokens, apply existing callbacks, and review compact widths/enlarged text/guest and authenticated states before widening the rollout. No new service, router, package, or data model is required for that presentation work.
