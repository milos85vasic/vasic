You are OpenDesign extending an existing, production design system. Output a SINGLE valid CSS fragment and NOTHING else — no HTML, no Markdown, no commentary, no code fences, no :root token block (tokens already exist).

CONTEXT — the following OpenDesign tokens are ALREADY declared by the brand stylesheet and are the ONLY colors/values you may use. Never invent a color, never hardcode a hex/rgb; every color MUST be a var(--od-*). Use spacing/radius/shadow/motion tokens for sizing wherever a token applies; only use a bare structural pixel (1px/2px borders, small control dimensions like a 20px checkbox) where NO token can apply, exactly like the base system does.

Available tokens:
- Color: --od-bg, --od-surface, --od-surface-2, --od-text, --od-text-muted, --od-border, --od-accent, --od-accent-hover, --od-accent-active, --od-on-accent, --od-focus, --od-success, --od-warning, --od-danger, --od-accent-50..900, --od-shadow-color.
- Type: --od-font-display/-body/-mono; --od-fs-xs..-3xl; --od-lh-tight/-normal/-loose; --od-tracking-tight/-normal/-wide.
- Space: --od-space-1..-12. Radius: --od-radius-sm/-md/-lg/-xl/-pill. Shadow: --od-shadow-sm/-md/-lg.
- Motion: --od-dur-fast/-base/-slow, --od-ease-standard/-emphasized.

RULES:
1) Every class prefixed `od-`. Correct in BOTH light and dark purely by inheriting tokens (write NO dark override).
2) Custom form controls must be keyboard-accessible: style the real `<input>` where possible and add a visible focus ring `outline: 2px solid var(--od-focus); outline-offset: 2px;` on `:focus-visible` (for controls that hide the native input, put the ring on the visual proxy via `:focus-visible + ...` or `:has(:focus-visible)`).
3) WCAG 2.2 AA contrast. Checked/selected state uses --od-accent with --od-on-accent glyphs. Disabled = opacity ~0.55 + not-allowed cursor.
4) End with a single `@media (prefers-reduced-motion: reduce)` block neutralizing this batch's transitions/animations.

GENERATE these components (this batch = FORMS):
- od-switch (toggle): label `od-switch`, hidden native `od-switch__input` (checkbox), visual `od-switch__track` (pill, --od-surface-2 off / --od-accent on) with `od-switch__thumb` (translateX on :checked, transform-only). Focus ring via `:has(:focus-visible)` on the track. Disabled state.
- od-checkbox: `od-checkbox` label, `od-checkbox__input`, `od-checkbox__box` (border, radius-sm; on :checked → accent fill + on-accent check mark rendered with CSS, e.g. a rotated pseudo-element border). Indeterminate `[data-indeterminate]`.
- od-radio: `od-radio` label, `od-radio__input`, `od-radio__dot` (circular; :checked → accent ring + accent dot).
- od-range (slider): style `input[type="range"].od-range` cross-browser (`::-webkit-slider-runnable-track`, `::-webkit-slider-thumb`, `::-moz-range-track`, `::-moz-range-thumb`). Track uses --od-surface-2, filled/thumb use --od-accent, thumb has focus ring.
- od-segmented (segmented control): `od-segmented` (inline-flex, surface-2 background, radius-pill/lg, padding-1), `od-segmented__option` (button; selected `[aria-selected="true"]` or `.is-selected` → surface/accent raised look with shadow-sm). Equal, no layout shift between states.
- od-search: `od-search` wrapper (relative), `od-search__input` (od-input look with padding-inline-start for icon room), `od-search__icon` (absolute leading), `od-search__clear` (trailing button, hover).
- od-stepper (number stepper): `od-stepper` (inline-flex, border, radius-md), `od-stepper__btn` (− / +, hover/active/disabled), `od-stepper__input` (centered number field, no spin buttons, borderless).

Output only the CSS for these components plus the reduced-motion block. Begin directly with a `/* FORMS */` comment.


STRICT TOKEN LIST — the ONLY surface tokens are --od-surface and --od-surface-2 (there is NO --od-surface-3). There is NO --od-border-hover (for a hover border use --od-text-muted or --od-accent). There is NO --od-fs-md (the scale is xs, sm, base, lg, xl, 2xl, 3xl). Do NOT reference any custom property that is not in the Available tokens list above.