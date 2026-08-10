# Constitution gate → check traceability

Backlog **D3**. Every named constitution gate literal (`CM-*`) should be
greppable inside the exact script that satisfies it, so a reviewer can go from
the gate name in the governance docs
(`_analysis/OPENDESIGN-ADOPTION-PLAN.md`, constitution submodule) straight to
the runnable check and its evidence — no guessing, no bluff.

The gate literals are now embedded as `GATE:` echo lines near the top **and** in
the final PASS/FAIL summary of each satisfying script, so:

```
grep -rn "CM-HOST-RENDERED-UI-VISUAL-PROOF\|CM-EXPORTED-DOC-VISUALLY-VALIDATED\|CM-OPENDESIGN-UI-SYSTEM" _tests _tools
```

lands on the check itself, not only on the docs.

> The `GATE:` echo lines are **additive logging only** — they change no exit
> codes and no behaviour. The checks pass/fail exactly as they did before.

## Traceability table

| Gate literal | § | Satisfied by (exact command) | Evidence produced |
|---|---|---|---|
| `CM-HOST-RENDERED-UI-VISUAL-PROOF` | §11.4.170 | `bash _tests/visual/self-validate.sh` (also run via `bash _tests/run-harness-selfvalidation.sh`). Drives `_tests/visual/visual-oracle.js` over `fixtures/good.html` (expect PASS) and `fixtures/bad.html` (expect FAIL); exits 0 only if good=PASS **and** bad=FAIL. | Per-theme host-rendered PNGs + oracle verdict under `_tests/evidence/harness/visual/` (golden-good.*, golden-bad.*). Self-validated (golden-good/golden-bad), so the oracle is proven able to FAIL. |
| `CM-EXPORTED-DOC-VISUALLY-VALIDATED` | §11.4.168 | `bash _tests/export/self-validate.sh` (also run via `bash _tests/run-harness-selfvalidation.sh`). Builds fixtures if missing, then drives `_tests/export/validate-pdf.js` over `golden-good.pdf` (expect PASS) and `golden-bad.pdf` (expect FAIL) across content + textual + full-visual (`pdftotext`/`pdfimages`/`pdftoppm`→OCR) layers; exits 0 only if good=PASS **and** bad=FAIL. | Validator verdicts + extracted text/image/OCR artifacts under `_tests/evidence/harness/export/`. Self-validated (golden-good/golden-bad). |
| `PORTFOLIO-DATA-INTEGRITY` (sibling gate; **not** a `CM-*` literal) | §1.1 (anti-bluff) | `bash _tools/portfolio/self-validate.sh`. Drives `_tools/portfolio/validate.mjs` over `selfvalidate-fixtures/good.json` (expect PASS) and `bad.json` (expect FAIL); exits 0 only if the validator is mutation-paired (good=PASS, bad=FAIL). | `golden-good.verdict.json` + `golden-bad.verdict.json` under `_tests/evidence/harness/portfolio/`. The adoption plan (line 169) lists this as "a portfolio-data-integrity gate" alongside the three `CM-*` gates; it has no `CM-*` literal of its own. |
| `CM-OPENDESIGN-UI-SYSTEM` | §11.4.162 | **No single self-validate exists.** See the partial-evidence section below. | See below. |

## `CM-OPENDESIGN-UI-SYSTEM` — honest partial evidence (§11.4.6, no bluff)

There is **no** self-validated (golden-good/golden-bad) analyzer that satisfies
`CM-OPENDESIGN-UI-SYSTEM` end-to-end. Do **not** treat this gate as green. What
currently exists is a set of real artifacts that each evidence *part* of the
"design-token / no-ad-hoc-CSS, both themes, AA contrast" intent:

- **Token-driven diagram rendering** — `node _tests/tools/diagram-brand-accent-proof.js`
  loads real generated product pages in a headless browser, reads the
  **computed** SVG stroke and the resolved `--od-accent` root token per
  `{light,dark}`, and asserts diagrams resolve to the correct brand token
  (company ≠ personal crimson). This proves colour comes from a resolved design
  token at render time, not an ad-hoc literal. Evidence: PNGs + `verdict.json`
  under `_tests/evidence/diagrams/brand-accent-proof/`.
- **Rendered-pixel AA contrast** — `_tests/tests/vasic-digital-a11y.spec.js` and
  `_tests/tests/milosvasic-ru-a11y.spec.js` (axe-core) keep the `color-contrast`
  (WCAG "serious") rule enforced on real pages in the browser, evidencing that
  the token palette meets AA in the rendered UI (§11.4.107).
- **No-hardcoding regression** — `_tests/tests/v171-hardcoding.spec.js` guards
  against hardcoded/leaked content on rendered pages (content-level, not
  token-level).

### Residual coverage gaps (do NOT claim these are covered)

- **No self-validated analyzer** for the gate itself (no golden-good/golden-bad
  proving the token check can FAIL) — unlike §11.4.168/.170.
- **No lint proving ZERO non-token colour/space literals** across CSS/inline
  styles. The adoption plan (line 100) demands "zero non-token color/space
  literals remain (lint)"; that lint is **not yet implemented**.
- **OpenDesign is not yet consumed as an external dependency.** §11.4.162
  mandates OpenDesign as *the* token system consumed as a dependency, with
  tokens "never in CSS custom properties or inline styles." The sites currently
  use bespoke `--od-*` CSS custom properties, so this core clause is **not
  satisfied** — the evidence above proves *token-driven* rendering, not
  *OpenDesign-sourced* tokens.

Until a self-validated token analyzer **and** the zero-literal lint exist, and
the sites consume OpenDesign as a dependency, `CM-OPENDESIGN-UI-SYSTEM` is
**partial / provisional**, not green.

## Other `CM-*` literals in the docs (out of scope for D3)

These appear in the governance docs but are not wired by the three self-validate
scripts above and are **not** claimed here: `CM-NO-LOCAL-RUNTIME`,
`CM-SCRIPT-DOCS-SYNC`, `CM-TEST-CATALOG-FRESH`, and the
`CM-COVENANT-114-*-PROPAGATION` family. They are listed for completeness so this
file is not mistaken for a full gate registry.

## How to re-verify

```bash
# §11.4.170 + §11.4.168 — must end with: OVERALL RESULT: PASS
bash _tests/run-harness-selfvalidation.sh 2>&1 | tail -4

# portfolio-data-integrity — must be rc=0
bash _tools/portfolio/self-validate.sh; echo rc=$?

# gate literals are now greppable inside the checks
grep -rn "CM-HOST-RENDERED-UI-VISUAL-PROOF\|CM-EXPORTED-DOC-VISUALLY-VALIDATED\|CM-OPENDESIGN-UI-SYSTEM" _tests _tools
```
