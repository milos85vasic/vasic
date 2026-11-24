# Exports classification, 2026-11-24

| Field | Value |
|---|---|
| Revision | 1 |
| Last modified | 2026-11-24 |
| Status | Classification complete; drops in flight as PRs #66, #67, #68, #69; Docs Chain change landed as #63 |
| Authority | Operator decision 2026-11-24 (Markdown-only amendment of 11.4.65); 11.4.124 (investigate before removing) |

## Contents

1. Question and method
2. Result
3. Per-directory classification
4. Kept, with the reason
5. Unpaired html/pdf (not touched)
6. Docs Chain change
7. Gates

## 1. Question and method

1838 tracked html/pdf/docx files existed. 1824 of them sit beside a tracked same-named `.md` (912 html + 912 pdf). For each, "export or real input?" was decided by evidence, not by name:

* Provenance: every one of the 912 html files carries `<meta name="generator" content="pandoc ...">`; every one of the 912 pdf files reports `Creator: pandoc 3.x, Producer: WeasyPrint 69` (`pdfinfo`). First commit of almost all is `12ecc0b` (2026-09-04, "1,642 exports land").
* Consumers: a full-path and a two-component-suffix (`dir/Name.ext`, case-exact) token search over every tracked non-export text file, excluding generated Docs Chain contexts, found references only in: generated contexts, `.gitignore` negations, `.hardcoded-paths-allow`, historical ledgers (`specs/010-*`, `docs/zero-gap/*`, `docs/findings/*`) and prose. No script, generator, test or gate reads them.
* Behavioural proof for `_content*/`: `_tools/gen/build.sh --no-jekyll --lang <l>` for 15 languages with `SOURCE_DATE_EPOCH` fixed, output diffed with and without the exports: `diff -r` IDENTICAL over 1069 files. The generator reads `_content/products/*.md`, `_content/sites/*.json` and `design-system/diagrams/<slug>.svg` only.
* The one coupling found: `_tools/career/test_profile_facts.py` asserts the file count written in `_content/career/profile.yaml` evidence (99 -> 33); updated in the drop.
* Live sites: no submodule (`milosvasic.ru`, `vasic.digital`) was changed. Sitemaps re-fetched 2026-11-24: `milosvasic.ru` 690/690 URLs HTTP 200, `digital.vasic.dev` 525/525 HTTP 200.

## 2. Result

| Disposition | Files | Where |
|---|---:|---|
| Exports, dropped | 1630 | PRs #66 (1140), #67 (154), #68 (100), #69 (236) |
| Exports, kept (ambiguous or out of scope) | 194 | section 4 |
| Real content inputs found | 0 among the 1824 paired files | |

## 3. Per-directory classification

| Directory or pattern | Files | Class | Evidence | PR |
|---|---:|---|---|---|
| `_content*/products/*` | 990 | generated export | generator byte-identical without them | #66 |
| `_content*/docs/*` | 90 | generated export | build-pdfs.sh reads `*.md` only | #66 |
| `_content*/sites/*` | 60 | generated export | generator reads `*.home*.json` | #66 |
| `design-system/**` | 154 | generated export | prompts/diagrams consumers read `.md`/`.svg` only | #67 |
| `_analysis/**` | 100 | generated export | no consumer | #68 |
| repo root carriers (README, CLAUDE, AGENTS, QWEN, GEMINI, CONTINUATION, Constitution) | 14 | generated export | `.gitignore` negations only | #69 |
| `docs/**` | 110 | generated export | `.hardcoded-paths-allow` entries (8, removed) and prose | #69 |
| `specs/**` | 110 | generated export | historical ledgers and prose | #69 |
| `_tools/containers/README.*` | 2 | generated export | none | #69 |

## 4. Kept, with the reason (194 files, left for the operator)

| Path | Files | Reason kept |
|---|---:|---|
| `_tests/evidence/**` | 66 | recorded evidence archive (11.4.2/11.4.5); derivative renderings, but rewriting an evidence record is the operator's call |
| `.claude/skills/**`, `.opencode/commands/**`, `.kimi-code/skills/**`, `.ashlrcode/genome/**`, `.specify/**` | 116 | agent/tool-managed trees (installer-owned); pandoc output of the same run, no consumer found, but removal belongs with a tool-tree decision |
| `_tests/export/**` | 4 | validator fixtures (`golden-good`/`golden-bad`): real test inputs of `validate-pdf.js`, must stay |
| `_tests/GATES.*`, `_tests/TEST-TYPES.*`, `_tests/helixqa/**` | 8 | pandoc exports, consumers not individually audited in this pass |

## 5. Unpaired html/pdf (not touched)

`.opencode/commands/*.superspec.*` and `.kimi-code/skills/*superspec*/SKILL.*` (20 files, `.md` not tracked), `design-system/preview` and `fonts` samples, `_tests/visual` fixtures, and 157 files under `_tests/evidence` (CV/PDF verdict artefacts) are real artefacts or tool output with no tracked Markdown source and were not classified as exports.

## 6. Docs Chain change (PR #63)

`scripts/gen-docs-chain-contexts.sh` now emits markdown nodes only (`edges: []`, `transforms: {}`). `scripts/verify-docs-chain.sh` C5 now fails if an html/pdf/docx node or `derive-from` edge reappears; `--prove-failure` mutations M1, M2, M2b cover it. RED first: new checks against the old generator made `--prove-failure` exit 1; after the change it exits 0. The tree went from C3+C4 FAIL (pre-existing) to 5/5 PASS.

## 7. Gates (captured exit codes)

| Gate | Result |
|---|---|
| `verify-docs-chain.sh` | rc 0 (after #63) |
| `verify-docs-chain.sh --prove-failure` | rc 0 |
| `verify-check-registry.sh` | rc 0 on every PR |
| gen output diff, 15 languages | identical |
| `verify-content-boundary.sh` in a worktree without private submodules | rc 2, could not determine (never a pass) |
| `continuation-check.sh` | rc 1, 33 DRIFT, identical on unmodified main (pre-existing) |
| `audit-hardcoded-paths.sh` in the worktree | rc 2, submodules not initialised; the 8 stale docs entries were removed |
