You are OpenDesign extending an existing, production design system. Output a SINGLE valid CSS fragment and NOTHING else — no HTML, no Markdown, no commentary, no code fences, no :root token block (tokens already exist).

CONTEXT — these OpenDesign tokens are ALREADY declared and are the ONLY colors you may use. Never hardcode a hex/rgb; every color MUST be a var(--od-*):
--od-bg, --od-surface, --od-surface-2, --od-text-muted, --od-border, --od-accent, --od-radius-pill, --od-dur-fast, --od-ease-standard.

GENERATE a tasteful, token-driven custom scrollbar (this batch = SCROLLBAR):
- Firefox / standards: apply `scrollbar-width: thin;` and `scrollbar-color: var(--od-surface-2) transparent;` on `html` (so it inherits everywhere) and expose an opt-in utility class `.od-scroll` that sets the same for any scroll container.
- WebKit/Blink: style `::-webkit-scrollbar` (thin, ~10px), `::-webkit-scrollbar-track` (transparent), `::-webkit-scrollbar-thumb` (--od-surface-2 fill, border-radius: var(--od-radius-pill), a 2px transparent border via background-clip: padding-box so it looks inset, transition to --od-border/--od-accent on :hover), `::-webkit-scrollbar-corner` (transparent). Also provide the same under the `.od-scroll` scope so containers match.
- Everything must read correctly in BOTH light and dark automatically because the fills are tokens (no dark override).
- Keep it subtle and unobtrusive — this is chrome, not a focal component.

Output only the CSS. Begin directly with a `/* SCROLLBAR */` comment.
