# Karipa design exploration — proposal only

**SUPERSEDED — 2026-10-11:** The user approved the coral/midnight/stone/ivory/charcoal identity for Phase 1. Trail Spark and every other palette below are historical exploration, not current implementation guidance. Use the [approved Karipa design system](karipa-design-system.md).

Phase 0, 2026-10-10. No palette, typography, component, or map-style changes have been applied. The user's preference for Trail Spark is not final approval. PathCraft remains the academic/technical identity; Karipa represents movement and determination for walking, jogging, running, and cycling equally.

## Current foundation

`mobile/lib/theme/app_theme.dart` already defines Material 3, `PathCraftColors`, Inter body text, Manrope headings, 24-pixel card corners, and 16-pixel input corners. Existing forest/lime values are close to Trail Spark but not identical. Many screens instead hardcode teal `#0D9488`, slate, white, and their own spacing. `main.dart` forces light mode; the presence of `darkTheme` does not establish a finished dark design.

Preserve these technical names and the current architecture. After approval, consolidate colors and component themes before changing screen layouts. A seed-generated ColorScheme alone will not fix hardcoded screen colors or guarantee the exact contrast pairs below.

## Candidate comparison

| Criterion | A — Trail Spark | B — Sunset Stride | C — Coastal Motion | D — Velocity Ink |
| --- | --- | --- | --- | --- |
| Supplied palette | Forest `#193B2C`, green `#36845C`, lime `#D1F36B`, background `#F5F7EF`, text `#15281F` | Charcoal `#26342E`, orange `#F46C3A`, gold `#E9B84B`, background `#FFF8F0`, text `#26342E` | Ocean `#103F50`, teal `#09B99D`, sky `#5EB8DB`, background `#F1FAF9`, text `#17333B` | Ink `#171C25`, lime `#CCF553`, iris `#7568DA`, background `#F6F7F4`, text `#171C25` |
| Brand/emotion | Grounded outdoor character with energetic lime; welcoming across activity levels | Warm, social and energetic; can emphasize effort/reward without a racing identity | Calm, fresh and approachable; strongest alternative to the current teal screens | Sport/performance emphasis; may feel more competitive to casual walkers |
| Outdoor alignment | Strong park/trail association | Strong sunrise/sunset association | Air/water association; works across urban and coastal exercise | Modern fitness identity, less place-specific |
| Sunlight strategy | Dark forest actions, dark text on light pages; reserve lime for emphasis | Charcoal for essential controls; orange/gold need dark labels | Ocean for critical actions; teal is too light for white labels | Strongest body contrast; keep lime limited and essential labels away from iris |
| OSM compatibility | Forest can merge with park/vegetation fills; outlined route required | Orange can merge with road colors; prefer charcoal planned route | Ocean/teal can merge with water; white route halo required | Iris gives useful separation from many tiles; still needs casing near labels/roads |
| Buttons/navigation | Forest primary, outlined forest secondary; lime selected indicator | Charcoal primary, outlined charcoal secondary; gold selection | Ocean primary, outlined ocean secondary; sky selection | Ink primary, outlined ink secondary; lime selection |
| States | Separate brand green from explicit success using icon/label | Never use gold/orange alone to distinguish warning/selection | Distinguish teal selection from success with icon/label | Do not use iris alone for errors or disabled controls |
| Workout dashboard | Forest + white metrics; lime highlights | Charcoal + white metrics; gold highlights | Ocean + white metrics; sky highlights | Ink + white metrics; lime highlights; avoid broad bright fills |
| Relative effort | Closest to existing theme tokens; screen overrides still require moderate work | Same component work plus new warm accents | Close to actual teal screen styling, less close to declared theme | Most visual change, particularly dashboard/accent balance |

All four can support readable layouts with the proposed pairings. Contrast calculations cannot certify bright-sunlight readability: screen luminance, glare, font weight, map detail, and real-device testing still matter. Implementation effort is a relative assessment, not a measured schedule.

## Proposed ColorScheme and surface roles

Values below deliberately assign foreground/background pairs; do not rely on generated `on*` values without checking the resolved theme. All additions beyond the supplied palettes are explicit proposals. White is `#FFFFFF`.

| Role | Trail Spark | Sunset Stride | Coastal Motion | Velocity Ink |
| --- | --- | --- | --- | --- |
| `primary` / `onPrimary` | Forest / white | Charcoal / white | Ocean / white | Ink / white |
| `secondary` / `onSecondary` | Green / white | Orange / **additional** deep text `#0F1712` | Teal / main text | Lime / ink |
| `tertiary` / `onTertiary` | Lime / main text | Gold / charcoal | Sky / main text | Iris / **additional** black `#000000` |
| `primaryContainer` / `onPrimaryContainer` | Lime / main text | Gold / charcoal | Sky / main text | Lime / ink |
| `surface` / `onSurface` | Supplied background / main text | Supplied background / main text | Supplied background / main text | Supplied background / main text |
| `surfaceContainerLow` / text | White / main text | White / main text | White / main text | White / main text |
| `inverseSurface` / `onInverseSurface` | Forest / white | Charcoal / white | Ocean / white | Ink / white |
| `outline` for essential controls | Forest | Charcoal | Ocean | Ink |
| `error` / `onError` | `#B53E35` / white | Same | Same | Same |
| `errorContainer` / `onErrorContainer` | `#FFF0EC` / `#B53E35` | Same | Same | Same |

The other Material surface/container roles need a complete approved light theme in Phase 1. Do not extrapolate this proposal into an unreviewed dark mode. Keep application-specific map/status colors in the existing ThemeExtension rather than overloading Material error or primary roles.

### Checked contrast

Computed from the supplied hex values using WCAG sRGB relative luminance: linearize each channel (`s/12.92` when `s <= 0.04045`, otherwise `((s + 0.055)/1.055)^2.4`), calculate `L = 0.2126R + 0.7152G + 0.0722B`, then `(Llighter + 0.05)/(Ldarker + 0.05)`. Ratios rounded to two decimals. These are opaque color-pair checks, not rendered-screen audits.

Target at least 4.5:1 for ordinary text, 3:1 for qualifying large text, and 3:1 for meaningful non-text control/graphic boundaries against adjacent colors. [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

| Pair | A | B | C | D |
| --- | --- | --- | --- | --- |
| Main text on supplied page | **14.34:1** | **12.36:1** | **12.58:1** | **15.89:1** |
| White on primary | **12.33:1** | **13.02:1** | **11.36:1** | **17.08:1** |
| Proposed `onSecondary` on secondary | White/green **4.55:1** | Deep text/orange **6.12:1** | Main text/teal **5.36:1** | Ink/lime **13.63:1** |
| Proposed `onTertiary` on tertiary | Main text/lime **12.36:1** | Charcoal/gold **7.08:1** | Main text/sky **5.95:1** | Black/iris **4.75:1** |

Avoid these tempting combinations:

- A: white/lime **1.25:1**, main text/green **3.40:1**, green text/page **4.21:1**. White/green only narrowly passes ordinary text; use forest for small critical labels.
- B: white/orange **2.98:1**, charcoal/orange **4.37:1**, white/gold **1.84:1**. Orange buttons require the proposed deeper foreground; charcoal is insufficient for ordinary text.
- C: white/teal **2.49:1**, white/sky **2.24:1**. Both require dark labels.
- D: white/lime **1.25:1**, white/iris **4.42:1**, ink/iris **3.86:1**. Black/iris narrowly passes; keep iris chiefly decorative or graphical, not the primary surface for dense metric text.

Main text on white cards has more contrast than on each supplied page. Outlined secondary buttons use the primary color on white and therefore share the checked white/primary ratios. State overlays, opacity, image backgrounds, and disabled defaults require fresh checks after rendering.

## Component and interaction pairings

| Use | Trail Spark | Sunset Stride | Coastal Motion | Velocity Ink |
| --- | --- | --- | --- | --- |
| Primary CTA | Forest fill, white label | Charcoal fill, white label | Ocean fill, white label | Ink fill, white label |
| Secondary action | Forest outline/text on white; optional green fill/white | Charcoal outline/text on white; optional orange/deep text | Ocean outline/text on white; optional teal/main text | Ink outline/text on white; optional lime/ink |
| Page/card | Off-white page, white card, dark main text | Warm white page, white card, charcoal | Cool white page, white card, dark main text | Neutral page, white card, ink |
| Navigation | White surface, forest labels/icons, lime selected pill with main text | White surface, charcoal labels/icons, gold selected pill with charcoal | White surface, ocean labels/icons, sky selected pill with main text | White surface, ink labels/icons, lime selected pill with ink |
| Dashboard | Forest panel, white values, lime badges/main text | Charcoal panel, white values, gold badges/charcoal | Ocean panel, white values, sky badges/main text | Ink panel, white values, lime badges/ink |

Keep navigation labels visible. Selected states also change icon/check/border treatment; color alone is insufficient. These are styling proposals for existing navigation, not authorization for a new persistent tab shell. Use an opaque surface beneath map controls. Essential input borders and focus rings use the listed dark outline, not a pale decorative divider.

### Shared semantic states for every candidate

Semantic colors are additional proposed tokens, mostly aligned with the existing extension. Use a label/icon plus color. Apply the same roles across all four candidates so brand selection does not change the meaning of an error.

| State | Foreground / background | Contrast | Presentation |
| --- | --- | --- | --- |
| Success | `#176B45` / `#EAF3E9` | **5.73:1** | Check + explicit success text, only when supported by state |
| Warning / paused | `#85430F` / `#FFF0DE` | **6.69:1** | Warning/pause icon + distinct message |
| Error | `#B53E35` / `#FFF0EC` | **5.11:1** | Error icon + cause + existing recovery action |
| Information | `#175B78` / `#EAF4FA` | **6.71:1** | Information icon + concise guidance |
| Disabled | `#59645E` / `#E2E7E0` | **4.91:1** | Inactive behavior/semantics and explanation where useful; no blanket opacity fade |

White on filled error `#B53E35` is **5.67:1**. Disabled controls have WCAG exceptions, but the proposed pair deliberately stays readable. An accent badge must not imply GPS accuracy, route safety, account verification, or saved activity without real supporting state.

## Map routes and markers

Tile contrast varies by location and zoom. A single line color cannot be certified against all OpenStreetMap imagery. Keep attribution visible. Proposed widths are starting points for a device review, not changes to geometry, tracking, or map control.

| Candidate | Planned route | Recorded track | Marker treatment |
| --- | --- | --- | --- |
| A | Forest `#193B2C` with white casing | Rust `#B23F1D` with white casing | Lime current marker with forest edge; start/end letter or icon |
| B | Charcoal `#26342E` with white casing | Blue `#175B78` with white casing | Gold marker with charcoal edge; avoid orange road-like route lines |
| C | Ocean `#103F50` with white casing | Rust `#B23F1D` with white casing | Sky marker with ocean edge; preserve casing over water |
| D | Iris `#7568DA` with white casing and an outer ink edge where needed | Rust `#B23F1D` with white casing | Lime marker with ink edge; retain distinct start/end symbols |

Against white casing: forest **12.33:1**, charcoal **13.02:1**, ocean **11.36:1**, iris **4.42:1**, rust **5.80:1**, blue **7.49:1**. These establish route-to-casing contrast, not casing-to-every-tile contrast. Try approximately 5-pixel route strokes inside 8-pixel casings, with distinct track styling and a text legend. Review urban roads, parks, water, dense labels, overlap, color-vision simulations, and outdoor brightness. Do not change GPS-follow/recenter behavior or subscriptions during a visual update.

## Cohesive UI language

- **Type:** retain existing Inter for labels/body and Manrope for headings and large metrics. Proposed body 16, secondary labels 14, screen headings 24–28, primary workout values 36–48 logical pixels with 600–800 weight. Prefer tabular figures where supported. Keep units adjacent and smaller but readable. Do not add a font dependency or asset in Phase 0.
- **Information:** show activity, target distance, and existing preference/suitability values in a consistent order. Pace uses min/km for walking/jogging/running; cycling speed uses km/h. Explicitly label calorie expenditure and remaining completion time as estimates. Missing values stay unavailable, never fabricated zeroes.
- **Activity identity:** use existing Material walking, running, and cycling icons, always with text. Jogging/running may share a movement icon; their labels carry the distinction. Give all four choices equal area, contrast, and prominence.
- **Spacing/radii:** propose a 4/8/12/16/24/32 scale; page padding 16 on compact widths and 24 where space permits. Retain 24 card and 16 input corners initially. Use 16 for buttons and pills only for compact statuses. Avoid ornamental nesting of cards.
- **Controls:** minimum 48 logical-pixel targets; aim for 56-pixel primary workout buttons. Keep pause/finish distinguishable and preserve existing confirmation callbacks. Use existing button types/component themes, not a new design library.
- **Cards/overlays:** flat white cards, modest borders, little elevation; opaque map overlays with clear text and unobstructed attribution. Loading states describe the current operation without invented percentages. Empty states explain the next existing action. Error states preserve actual messages and supported recovery options.
- **Motion:** restrained 150–250 ms color/selection transitions where useful. Respect platform reduced-motion settings; remove nonessential movement. Do not animate every timer tick or repeatedly announce live values.
- **Responsive behavior:** use constraints, wrapping metric groups and scrollable content; account for safe areas, keyboard, landscape, and large text. No fixed-height text containers or disabled text scaling to force a fit. Test 320/360/412 logical-pixel widths and 100/150/200% text scaling.

## Recommendation and Phase 1 proposal

**Primary: Trail Spark.** It combines a grounded outdoor identity and lively highlights, offers strong forest/white and text/background contrast, and fits the existing theme's forest/lime direction. Keep green out of small text on the off-white page and reserve lime for dark-labelled highlights.

**Alternative: Coastal Motion.** It is approachable across all four activities and relates to current teal UI styling. Use ocean for essential controls and dark labels on teal/sky. Water-heavy map areas need careful route casing review.

Subject to approval, Phase 1 should:

1. Confirm the palette, exact contrast-safe roles, supplied capstone requirements, target devices, and design reference. Record the final decision separately from this exploration.
2. Consolidate existing `AppTheme`/`PathCraftColors` into an approved light Material 3 theme: colors, typography, spacing, radii, buttons, inputs, cards, and statuses. Preserve internal identifiers and avoid dependencies.
3. Establish small reusable presentation components for activity choice, metric/unit display, status, and primary/secondary actions. Pass existing data/callbacks; preserve screen state/lifecycle ownership.
4. Review one approved representative screen and a workout-metric example at compact/standard widths and enlarged text before widening the migration. A sample/review harness would require Phase 1 authorization; none was generated here.
5. Add focused component/accessibility tests and deterministic visual comparisons; preserve the current baseline separately. Coordinate the splash smoke-test timer issue as its own scoped test fix.
6. Review protected-path diffs and approve screen-by-screen rollout in a later phase. Save-state, GPS, guest persistence, navigation architecture, and route suitability semantics remain integration-owner questions rather than theme work.

Needed references: full approved Chapter 1/2, usability/evaluation rubric, supported platform/device and minimum OS targets, approved Figma/screenshots if any, and a future logo/asset brief. None should be invented from the academic title or supplied feature list.
