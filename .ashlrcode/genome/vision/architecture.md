# Architecture (intent)

> This file records *why* the layout is what it is. The scanned file/extension
> snapshot lives in `knowledge/architecture.md` — do not duplicate it here.

## The one-way pipeline

```
_content/  (English source, markdown)
   └─ translate ─► _content_<lang>/  (14 languages, PASS-gated)
          │
          ▼
   _tools/gen/  (Go 1.26, module vasic.digital/tools/gen)
          │  renders localized pages for BOTH sites
          ├──────────────► vasic.digital/     (static HTML, committed, served as-is)
          └──────────────► milosvasic.ru/     (Jekyll source ─ jekyll build ─► _site/, git-ignored)
                                  │
   design-system/  ──── tokens/CSS ───────────┘
          │
   _tools/pdf/  ──── same tokens ────► downloadable PDFs
          │
   _tests/  (Playwright + self-validating harness) verifies the rendered output
          │
   _tools/deploy-langs.sh  regenerates → commits → pushes each site only if changed,
                           then validates the LIVE sites
```

Sources: `README.md` "What's in here" table; `_tools/deploy-langs.sh`;
`design-system/README.md` "How each surface consumes it".

## Boundaries that matter

- **The generator is the only writer of site pages.** Both site submodules are
  *outputs*. `_tools/gen/` renders into them; `deploy-langs.sh` commits inside
  them. Editing generated HTML in a site submodule by hand loses on the next
  regeneration.
- **The two sites differ only in accent ramp.** Both brand stylesheets share an
  identical foundation — type scale, spacing, radius, shadow, motion, z-index,
  container width and the same `.od-*` component set — and diverge *only* in the
  accent colour and its dark value (`design-system/README.md`, "Architecture —
  shared foundation + two brand themes").
- **`_tests/evidence/` is tracked output, not source.** 4,526 tracked files
  (1,353 json, 1,167 txt, 1,142 png, 515 log) against 95 real source files in
  all of `_tests/` (`.lumenignore` header). `.gitignore` even carries an
  explicit `!_tests/evidence/` negation to keep it tracked. It is excluded from
  semantic indexing only.
- **Governance is inherited by reference, never copied.** `submodules/constitution`
  holds the corpus; the five root carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`,
  `GEMINI.md`, `Constitution.md`) are pointers. `Constitution.md` §101 forbids
  restating any anchor at this layer.

## Why submodules and not directories

The two sites are separately deployable GitHub Pages repositories with their own
release tags (`v1.8.0` is on `milosvasic.ru` and `vasic.digital` only —
`Constitution.md` gap G10). `ai_interviewing`, `monetization` and
`design-toolkit` are independent bodies of work that happen to be checked out
here; see `knowledge/workspace.md`.

## Known structural hazards

Recorded in full in `knowledge/discoveries.md`: a recursive submodule checkout
of this umbrella **fails**.

**Resolved:** two build scripts once hardcoded an absolute macOS root from the
author's machine. Both now derive their root from their own file location
(`_tools/deploy-langs.sh:14`, `_tests/playwright.config.js:7`), the CI symlink
that worked around them is gone, and `scripts/audit-hardcoded-paths.sh` blocks a
relapse as CI Gate 0. Every path in the pipeline above is derived, so the whole
chain reproduces from a clean clone at any location.
