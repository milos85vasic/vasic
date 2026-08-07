# Changelog (umbrella / `_analysis`)

Design and delivery changelog for the vasic umbrella repo. Newest first.

## v1.6.0 — Bold re-style (both sites)

Shipped a bold re-style on both properties, each generated as two distinct
candidates with Candidate A shipping. **vasic.digital** adopted Candidate A
**"MACHINA"** (Bricolage Grotesque display, sharp 0–4px corners, whole-page
blueprint grid, GPU-only scanline/aurora motion, deep dark-red `#8f1d2d` hue
kept); **milosvasic.ru** adopted Candidate A **"TERMINAL BRUTALIST"** (uppercase
Anton display, 2px ink frames, hard offset print-shadows, engineering-grid
texture, crimson `#a31e39` hue kept). The rejected alternates — vasic
**"VOLTAGE"** (Fraunces serif / frosted glass) and milos **"LUMINOUS CRIMSON
GLASS"** (Fraunces serif / glass) — are retained as re-appliable drop-ins; their
fonts are already deployed. New self-hosted OFL faces (latin+latin-ext, no CDN):
Bricolage Grotesque + Fraunces on vasic, Anton + Fraunces on milos; Inter/
JetBrains Mono unchanged. Accessibility/safety verified from
`_tests/evidence/restyle/`: **0 serious/critical and 0 total axe violations** on
every page/theme, **0 horizontal overflow** desktop and mobile, milos behavior
intact (hamburger, 15-item lang switcher, 15-lang download modal, back-to-top),
and reduced-motion / reduced-transparency fallbacks in place. Rollback restore
points: vasic **v1.5.0**, milos **v1.5.2**, umbrella **pre-restyle**. Full
detail: [`RESTYLE-v1.6.0.md`](RESTYLE-v1.6.0.md).
