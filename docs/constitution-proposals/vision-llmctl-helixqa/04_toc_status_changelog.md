# 04 — ToC, status header and changelog text (PROPOSED)

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-14 |
| Status | proposal |

## 1. Table of contents entries (`Constitution.md`, under §11)

Measured 2026-10-14: the header's own `Issues summary` records that the ToC is
stale for older anchors (§11.4.71–§11.4.76). Adding these five entries does not
fix that; the integrator should not claim it does.

```markdown
  - [§11.4.277 — Constitution-owned llmctl wrapper](#11-4-277)
  - [§11.4.278 — Validated-before-use](#11-4-278)
  - [§11.4.279 — Golden-content oracle bank](#11-4-279)
  - [§11.4.280 — Vision-eyed full-suite UI QA](#11-4-280)
  - [§11.4.281 — Vision-family docs and propagation](#11-4-281)
```

The anchor slug format above is a placeholder; generate slugs with the
constitution's own tooling (`scripts/anchors/constitution_generate.py` /
`constitution_link_check.py`) rather than by hand, and run the link check after.

## 2. Metadata header (§11.4.44 / §11.4.61)

Measured 2026-10-14: `Revision | 72`, `Last modified | 2026-10-05T07:49:21Z`.
Proposed values at placement time (re-read first; another amendment may have
landed):

| Field | Proposed value |
|---|---|
| Revision | previous + 1 |
| Last modified | the placement commit's UTC time |
| Status summary | Amendment of `<date>` — NEW §11.4.277–§11.4.281 (local-model governance and vision-eyed UI QA: constitution-owned `llmctl` wrapper with a ban on direct calls; validated-before-use with fresh, deterministic, per-host records; golden-content oracle bank with golden-bad controls and a deterministic judge; HelixQA full-suite UI coverage ledger with frame-bound, vision-decided, BLOCKED-never-PASS verdicts and per-platform seeded defects; same-change docs and propagation). |

## 3. Changelog entry

```markdown
## <date> — Local-model governance and vision-eyed UI QA (§11.4.277–§11.4.281)

Added (operator mandate 2026-10-12):
- §11.4.277: every local-model obtain/run/query goes through the constitution's
  `scripts/llm/` wrapper; direct `llmctl` invocation in tracked files is banned.
- §11.4.278: no model is used before a fresh, deterministic (≥3 identical runs),
  per-host validation record passes; 30-day ceiling; any key change invalidates.
- §11.4.279: vision validation uses a constitution-owned, reproducibly generated
  golden bank with golden-bad controls and a closed deterministic check
  vocabulary; wrong answers are classified defects, never loosened for a
  model-capability gap.
- §11.4.280: every interactive-UI project keeps a screens × states × platforms
  ledger, runs HelixQA full suites with vision-decided, frame-bound verdicts,
  BLOCKED never PASS, and catches a seeded defect per platform before release.
- §11.4.281: guides, FAQ, diagrams and exports change in the same commit;
  `post_update_hook.sh` and templates carry the rules to consumers.

Gates (design; code is separate work): CM-COVENANT-114-277..281-PROPAGATION,
CM-LLMCTL-WRAPPER-ONLY, CM-LLMCTL-WRAPPER-CONTRACT,
CM-MODEL-VALIDATED-BEFORE-USE, CM-MODEL-VALIDATION-DETERMINISM,
CM-GOLDEN-BANK-REPRODUCIBLE, CM-GOLDEN-BANK-CONTROLS,
CM-GOLDEN-BANK-NO-LOOSENING, CM-UI-VISION-COVERAGE-LEDGER,
CM-UI-VISION-VERDICT-NO-BLUFF, CM-UI-VISION-SEEDED-DEFECT,
CM-VISION-FAMILY-DOCS-SYNC.

Honest boundary: no gate code, no wrapper and no relocated golden bank exist at
the time of this entry; the anchors bind, the mechanisms are tracked work.
```

Export per §5 / §11.4.65 (`.html`, `.json`, `.txt` siblings) with the
constitution's existing export script; do not hand-write exports.
