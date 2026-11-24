# Operator decision: drop non-Markdown exports of the workable-items docs; accept the new perf-budget baseline

| Field | Value |
|---|---|
| Date | 2026-11-24 |
| Decision source | Operator, recorded in the housekeeping order of 2026-11-24 |
| Anchors | §11.4.65 (amendment 2026-10-26: agents work only with Markdown), §11.4.66, §11.4.6 |
| Supersedes | PR #38 (merged 2026-11-24T15:23:29Z) as to its `.html` / `.pdf` / `.docx` files |

## 1. Non-Markdown exports

PR #38 had already merged when this decision was taken, so it is carried out as a follow-up change rather than by
closing #38. Removed from `docs/workable-items/`: 14 tracked files (`Fixed`, `Fixed_Summary`, `Issues`,
`Issues_Summary` as `.html`/`.pdf`/`.docx`, and `PROCEDURE.html` / `PROCEDURE.pdf`). The `.md` files, `sub-projects.tsv`
and the SQLite database are untouched. The two `PROCEDURE` derive-from edges and their html/pdf nodes were removed from
`.docs_chain/contexts/umbrella-docs.yaml` so the context does not name files that no longer exist.

**Honest boundary (§11.4.6).** This is scoped to the files PR #38 added or refreshed. A measurement of the tree at
`github/main` found 1838 other tracked `.html`/`.pdf`/`.docx` files that sit beside a same-named `.md` (917 html, 917 pdf,
4 docx, mostly `_content*/products`, `design-system/diagrams`, `specs/`, `docs/`). They were NOT removed: some may be
content inputs rather than exports, and `scripts/gen-docs-chain-contexts.sh` still DERIVES html/pdf nodes for every
Markdown document, so a repository-wide drop needs a separate decision and a generator change.

## 2. perf-budget baseline

`_tests/evidence/test-types/perf-budget.json` is accepted at its newly measured values: the chromium rows for
`milosvasic.ru` `/` and `/products/helixtrack.html` rose by about 25.9 KB raw each (about 5 KB gzip), and firefox and
webkit rows were added. Operator judgement: this is the cost of the current site content, not a regression, and the
file is a recorded baseline rather than a ceiling. The values are the ones measured in the shared checkout on
2026-11-24.
