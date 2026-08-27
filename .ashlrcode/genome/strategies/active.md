# Active Strategies

Development approaches that have proven effective.

- Explore existing codebase patterns before writing new code
- Write tests alongside implementation
- Keep changes small and reviewable

---

## Build & CI — six named gates, run identically local and remote

`README.md:56-71` and `.github/workflows/ci.yml` are kept in exact
correspondence ("The commands below mirror `.github/workflows/ci.yml` exactly").
Run from the repository root:

```bash
cd _tools/gen && go test ./... && cd -        # 1 Go unit tests (generator)
bash _tools/audit-hardcoding.sh               # 2 hardcoding audit (builds gen)
bash _tools/translate/reproducibility-selftest.sh   # 3 translate reproducibility
bash _tools/portfolio/self-validate.sh        # 4 portfolio §1.1 data integrity
bash _tests/run-harness-selfvalidation.sh     # 5 visual §11.4.170 + export §11.4.168
# 6 Playwright chromium, excluding the LIVE all-language crawl:
cd _tests && npm ci && npx playwright install chromium
npx playwright test --project=chromium --grep-invert "all-language"
```

Toolchains (CI-matched): **Go 1.26, Node 20, Ruby 3.3 + Bundler,
poppler-utils, tesseract-ocr** (`CLAUDE.md:132-134`, `README.md:45-52`).
`milosvasic.ru/_site` must be built with Jekyll before gate 6 — it is git-ignored
in that submodule. `vasic.digital` needs no build.

**The `all-language` crawl is deliberately excluded from per-run CI** — it is
designed to run LIVE against production, from the deploy path, not per commit
(`README.md:76-78`).

## Testing — self-validation over assertion

The harness proves itself before it judges anything: each self-validate drives a
`golden-good` fixture (expect PASS) and a `golden-bad` fixture (expect FAIL) and
exits 0 only when both hold (`_tests/GATES.md` traceability table). Gate
literals (`CM-HOST-RENDERED-UI-VISUAL-PROOF`, `CM-EXPORTED-DOC-VISUALLY-VALIDATED`,
`CM-OPENDESIGN-UI-SYSTEM`) are embedded as `GATE:` echo lines inside the
satisfying script so a reviewer can grep from doc → runnable check → evidence.

`_tests/TEST-TYPES.md` maps all 14 §11.4.169 test types to PRESENT / ADDED /
N/A-with-reason. Stack: `@playwright/test`, `@axe-core/playwright`,
`pixelmatch` + `pngjs` (`_tests/package.json`).

`CM-OPENDESIGN-UI-SYSTEM` is **not green** — no self-validated analyzer and no
"zero non-token literal" lint exists yet (`_tests/GATES.md`, honest-partial
section). Do not report it as covered.

## Deploy — incremental, idempotent, PASS-gated

`bash _tools/deploy-langs.sh` (`--dry-run` / `-n` previews):

1. A language counts COMPLETE only when its `PASS` verdict count under
   `_tests/evidence/translate-new/<lang>/` reaches the source-doc count.
2. Builds `gen` once with the © year pinned via `-ldflags`.
3. Regenerates EN, then every COMPLETE language, into **both** site submodules.
4. Rebuilds PDFs (skips with a warning if pandoc/weasyprint are missing).
5. Rebuilds the Jekyll `_site`.
6. Commits and pushes each site **only if something changed**.
7. Validates the LIVE sites with the exhaustive all-language link/sitemap crawl.

Idempotent by construction: deterministic output means an unchanged run is a git
no-op. Safe to run repeatedly while a translation batch is still writing.

## Governance — pointer inheritance, verified

Five root carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`,
`Constitution.md`) each open with `## INHERITED FROM `. The four agent carriers
are byte-identical from line 24 down — verify with
`tail -n +24 <file> | sha256sum` (`Constitution.md` header table). Pointer form
is used instead of `@import` because the corpus is 654 KB + 1.53 MB, ~165k
tokens per session (`CLAUDE.md:54-66`).

Verifiers: `tests/test_constitution_inheritance.sh` and
`scripts/verify-all-constitution-rules.sh` (last recorded sweep: **58 gates —
37 PASS / 21 FAIL / 0 ERROR**, exit 1, all 21 failures classified as
known-excluded or upstream in `Constitution.md`).

## Commits — the wrapper, not raw git

`commit "<message>"` resolves on PATH to `<toolkit>/Upstreamable/commit`, which
chains `git add .` + `git commit` then `push_all.sh`; `push_all.sh` reads the
`upstreams/*.sh` recipes, and this root has a tracked `upstreams/GitHub.sh`
exporting `UPSTREAMABLE_REPOSITORY=git@github.com:milos85vasic/vasic.git`
(`CLAUDE.md:174-181`). Because it runs `git add .`, keep `.gitignore` accurate.

## Semantic tooling

Lumen (local embeddings via ollama, model `ordis/jina-embeddings-v2-base-code` —
`scripts/lumen-reindex.sh:45`) plus CodeGraph (`.codegraph/codegraph.db`).
`_tests/evidence/` is excluded from the Lumen index via `.lumenignore`;
everything else, submodules included, is indexed.
Helpers: `scripts/lumen-reindex.sh`, `scripts/lumen-index-doctor.sh`.
