You are OpenDesign extending an existing, production design system. Output a SINGLE valid CSS fragment and NOTHING else — no HTML, no Markdown, no commentary, no code fences, no :root token block (tokens already exist).

CONTEXT — the following OpenDesign tokens are ALREADY declared by the brand stylesheet and are the ONLY colors/values you may use. Never invent a color, never hardcode a hex/rgb; every color MUST be a var(--od-*). Use spacing/radius/shadow/motion tokens for sizing wherever a token applies; only use a bare structural pixel (1px/2px borders, small control dimensions) where NO token can apply, exactly like the base system does.

Available tokens:
- Color: --od-bg, --od-surface, --od-surface-2, --od-text, --od-text-muted, --od-border, --od-accent, --od-accent-hover, --od-accent-active, --od-on-accent, --od-focus, --od-success, --od-warning, --od-danger, --od-accent-50..900, --od-shadow-color.
- Type: --od-font-display/-body/-mono; --od-fs-xs..-3xl; --od-lh-tight/-normal/-loose; --od-tracking-tight/-normal/-wide.
- Space: --od-space-1..-12. Radius: --od-radius-sm/-md/-lg/-xl/-pill. Shadow: --od-shadow-sm/-md/-lg.
- Motion: --od-dur-fast/-base/-slow, --od-ease-standard/-emphasized. Z: --od-z-nav/-modal/-toast.

RULES:
1) Every class prefixed `od-`. Correct in BOTH light and dark purely by inheriting the tokens above (do NOT write any dark-theme override — the tokens flip themselves).
2) Interactive elements get a visible :focus-visible ring: `outline: 2px solid var(--od-focus); outline-offset: 2px;`.
3) WCAG 2.2 AA text contrast. CRITICAL: the toast is a NEUTRAL --od-surface panel — its ONLY colored part is the left accent border and the icon. ALL toast text MUST stay on the neutral surface: use `var(--od-text)` for titles and `var(--od-text-muted)` for the message. NEVER set a literal text color and NEVER use --od-on-accent for toast text (those would fail contrast in one theme). Per variant, change ONLY `border-left-color` and the `od-toast__icon { color: <semantic token> }` — do not touch text color.
4) End with a single `@media (prefers-reduced-motion: reduce)` block neutralizing this batch's transitions/animations.
5) Provide hover / active / selected / disabled states and ARIA-friendly hooks (e.g. [aria-selected], [aria-disabled], [hidden], [role="menu"]).

GENERATE these components (this batch = OVERLAYS):
- od-toast (notification): container `od-toast` (--od-surface fill, --od-text title, --od-text-muted message), region `od-toast-region` (fixed stack, top/bottom, gap, z = --od-z-toast), `od-toast__icon`, `od-toast__body`, `od-toast__title`, `od-toast__msg`, `od-toast__close`. Variants `od-toast--success`, `od-toast--warning`, `od-toast--danger`, `od-toast--info` (info uses --od-accent) change ONLY the left `border-left-color` and `od-toast__icon` color to the matching semantic token (--od-success/--od-warning/--od-danger/--od-accent). Text color is NEVER overridden.
- od-menu / dropdown: `od-menu` (surface panel, border, radius, shadow-lg, padding), `od-menu__item` (hover/focus background --od-surface-2, [aria-disabled] dimmed), `od-menu__separator`, `od-menu__label` (mono eyebrow), `od-menu[hidden]` hidden. A `od-dropdown` wrapper (position:relative).
- od-select: styled `od-select` wrapper + `.od-select__control` (looks like od-input) with a chevron via `.od-select__chevron`; open state `[aria-expanded="true"]`. Reuse input look from tokens.
- od-tooltip: `od-tooltip` (position:relative host) + `od-tooltip__bubble` (absolute, surface-2/inverse, small, radius, shadow, opacity+transform transition, appears on :hover/:focus-within of host), with `[data-placement]` top/bottom.
- od-popover: `od-popover` panel (surface, border, radius-lg, shadow-lg, padding-6, max-width), `od-popover__arrow`, `od-popover__title`, `od-popover__body`, `[hidden]` hidden.
- od-fab (floating action button): `od-fab` (fixed bottom-inline-end, circular via radius-pill, accent fill, on-accent icon, shadow-lg, hover-lift via transform, active). `od-fab--sm` variant.

Output only the CSS for these components plus the reduced-motion block. Begin directly with a `/* OVERLAYS */` comment.


STRICT TOKEN LIST — the ONLY surface tokens are --od-surface and --od-surface-2 (there is NO --od-surface-3). There is NO --od-border-hover (for a hover border use --od-text-muted or --od-accent). There is NO --od-fs-md (the scale is xs, sm, base, lg, xl, 2xl, 3xl). Do NOT reference any custom property that is not in the Available tokens list above.