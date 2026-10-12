# Karipa UI foundation — Stage 1
PathCraft remains the repository and technical identity; Karipa is the UI brand.
Represent walking, jogging, running, and cycling equally.
Primary orange: #FF5A24 for energetic actions and accents.
Deep navy: #1A1E27 for brand backgrounds, dark mode, and light-mode ink.
Clean content surface: #FFFFFF; supporting ivory: #E3E0D3.
Stone #CFCDBE and charcoal #2B2B2B support borders and secondary content.
Use ColorScheme and PathCraftColors roles rather than per-screen palettes.
Legacy coral/midnight identifiers alias orange/navy for compatibility.
Use navy foregrounds on orange controls; avoid small white text on orange.
Official assets: mobile/assets/branding/karipa-logo.png and karipa-wordmark.png.
Both PNGs are fully opaque, with baked-in textured navy backgrounds.
Preserve artwork, backgrounds, aspect ratios, and internal whitespace.
Never crop, recolor, stretch, or remove the official backgrounds.
KaripaLogo provides the emblem and optional wordmark with one semantic label.
Splash uses a navy canvas, official lockup, and orange loading indicator.
Typography: existing Manrope headings and Inter body styles.
Spacing: existing 4/8/12/16/24/32/48 logical-pixel tokens.
Corners: existing 12px controls, 16px panels, and 24px cards.
Maintain 48px touch targets, readable contrast, safe areas, and text scaling.
Respect reduced motion; preserve the existing dark-mode toggle.
Future stages should reuse these foundations without changing business logic.
