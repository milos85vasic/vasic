You are OpenDesign extending an existing, production design system. Output a SINGLE valid CSS fragment and NOTHING else — no HTML, no Markdown, no commentary, no code fences, no :root token block (tokens already exist).

CONTEXT — the following OpenDesign tokens are ALREADY declared by the brand stylesheet and are the ONLY colors/values you may use. Never invent a color, never hardcode a hex/rgb; every color MUST be a var(--od-*). Use spacing/radius/shadow/motion tokens for sizing wherever a token applies; only use a bare structural pixel (1px/2px borders, small fixed dimensions like a 40px avatar, spinner ring) where NO token can apply, exactly like the base system does.

Available tokens:
- Color: --od-bg, --od-surface, --od-surface-2, --od-text, --od-text-muted, --od-border, --od-accent, --od-accent-hover, --od-accent-active, --od-on-accent, --od-focus, --od-success, --od-warning, --od-danger, --od-accent-50..900, --od-shadow-color.
- Type: --od-font-display/-body/-mono; --od-fs-xs..-3xl; --od-lh-tight/-normal/-loose; --od-tracking-tight/-normal/-wide.
- Space: --od-space-1..-12. Radius: --od-radius-sm/-md/-lg/-xl/-pill. Shadow: --od-shadow-sm/-md/-lg.
- Motion: --od-dur-fast/-base/-slow, --od-ease-standard/-emphasized.

RULES:
1) Every class prefixed `od-`. Correct in BOTH light and dark purely by inheriting tokens (write NO dark override).
2) Interactive elements get a visible :focus-visible ring: `outline: 2px solid var(--od-focus); outline-offset: 2px;`.
3) WCAG 2.2 AA contrast. CRITICAL for od-alert/od-banner: they are NEUTRAL --od-surface panels whose ONLY colored part is the left border and the icon. ALL alert text MUST stay on the neutral surface: `var(--od-text)` for the title, `var(--od-text-muted)` for the body. NEVER set a literal text color and NEVER use --od-on-accent for alert text (would fail contrast in one theme). For pagination's current page (an actual --od-accent FILL) use --od-on-accent for its glyph — that is the only place on-accent text is correct.
4) End with a single `@media (prefers-reduced-motion: reduce)` block neutralizing this batch's transitions AND stopping the spinner/skeleton keyframe animations (set animation:none, and for skeleton show a static surface-2).

GENERATE these components (this batch = NAV + FEEDBACK):
- od-tabs: `od-tabs`, `od-tabs__list` [role=tablist] (flex, bottom border), `od-tabs__tab` [role=tab] (button; hover text→accent; selected `[aria-selected="true"]` → accent text + 2px accent underline via bottom border/box-shadow, no layout shift), `od-tabs__panel` [role=tabpanel] (padding-block), `[hidden]` hidden.
- od-breadcrumb: `od-breadcrumb` [nav] + ol `od-breadcrumb__list` (flex, gap), `od-breadcrumb__item`, `od-breadcrumb__link` (muted→accent on hover), separator via `od-breadcrumb__item + od-breadcrumb__item::before` content "/" in --od-text-muted, current `[aria-current="page"]` → --od-text non-link.
- od-pagination: `od-pagination` (flex, gap), `od-pagination__link` (min square, border, radius-md, hover surface-2), current `[aria-current="page"]` → accent fill + on-accent, disabled `[aria-disabled]`.
- od-progress: `od-progress` (track, surface-2, radius-pill, fixed small height), `od-progress__bar` (accent fill, width via inline style, transition width). Also `od-progress--indeterminate` with a keyframe sliding accent segment (transform-only).
- od-spinner: `od-spinner` (inline-block circular, border with transparent top, accent color, `@keyframes od-spin` rotate 360). Sizes `od-spinner--sm`/`--lg`. Must have accessible companion class `od-visually-hidden` for label text (clip pattern).
- od-skeleton: `od-skeleton` (block, surface-2, radius-md, shimmer via `@keyframes od-shimmer` using a background-position or transform pseudo — keep GPU-friendly). Variants `od-skeleton--text` (line, smaller height, last-child shorter), `od-skeleton--circle`.
- od-alert (callout/banner): `od-alert` (--od-surface fill, border-inline-start 3px semantic, radius-md, padding, flex with `od-alert__icon`, `od-alert__title` in --od-text, `od-alert__body` in --od-text-muted). Variants `od-alert--success/--warning/--danger/--info` (info→accent) change ONLY the `border-inline-start` color and the `od-alert__icon` color to the matching semantic token — NEVER the text color. `od-banner` full-width variant.
- od-avatar: `od-avatar` (circle, fixed size, surface-2 bg, overflow hidden, `od-avatar__img` cover, `od-avatar__initials` centered display font). Sizes `--sm/--lg`. `od-avatar--ring` (accent ring). `od-avatar-group` (overlapping via negative margin-inline-start + border in --od-bg).
- od-empty-state: `od-empty-state` (centered column, padding-12), `od-empty-state__icon` (muted, large), `od-empty-state__title` (display), `od-empty-state__msg` (muted), `od-empty-state__action`.

Output only the CSS for these components plus the reduced-motion block. Begin directly with a `/* NAV + FEEDBACK */` comment.


STRICT TOKEN LIST — the ONLY surface tokens are --od-surface and --od-surface-2 (there is NO --od-surface-3). There is NO --od-border-hover (for a hover border use --od-text-muted or --od-accent). There is NO --od-fs-md (the scale is xs, sm, base, lg, xl, 2xl, 3xl). Do NOT reference any custom property that is not in the Available tokens list above.