# a11y target-size findings — reproduction follow-up (2026-08-08, post-v1.7.2)

The a11y audit (axe-core) reported 3 `target-size` (WCAG 2.5.8) violations on milosvasic.ru:
`a.brand`, and RTL `#lang-btn`/`#theme-btn` at "38×5.9px partiallyObscured".

**Reproduction (Playwright, live https://milosvasic.ru/ar/, systematic-debugging Phase 1):**
- Probed at 375 / 414 / 768 / 1280 px. At EVERY width, `#lang-btn` and `#theme-btn` measure a
  clean **38×38 px** and `elementFromPoint(center)` returns the button itself → **not obscured**,
  and 38 ≥ the 24 px AA minimum → **PASS**.
- `.brand` measures **114×24 px** — exactly at the 24 px threshold (borderline PASS).

**Conclusion (no bluff):** the reported RTL "5.9px partiallyObscured" does **not reproduce** on the
current live site; it was an axe measurement artifact (adjacent-target spacing heuristic / transient
render state), not a real usability defect. No fix applied — fixing an unreproducible finding would
violate NO-FIX-WITHOUT-ROOT-CAUSE. Optional hardening only: `.brand{min-height:24px}` as a safety
margin against the borderline case. vasic.digital remains 0 violations.
