# Vision / `llmctl` / HelixQA constitution proposal

| Field | Value |
|---|---|
| Revision | 2 |
| Created | 2026-10-14 |
| Last modified | 2026-10-14 |
| Status | proposal — NOT canon; not placed in `submodules/constitution` |
| Status summary | Revision 2: upstream now carries §11.4.277 and §11.4.278 with overlapping content. `07_reconciliation_after_upstream_merge.md` supersedes the numbering and the new-anchor framing below: no new anchors, amendments to 277/278 instead, tentative §11.4.277–§11.4.281 released. Files 01–05 stay as the record of the original draft (ANCHOR-A..E for the operator mandate of 2026-10-12). |
| Issues | Independent review (§11.4.142) not yet run; gate code not written; see `06_open_questions.md` and `07_reconciliation_after_upstream_merge.md` §13 |

## Why this directory exists

The first draft of these rules lived under `/tmp` and was lost in a host reset.
This is the redo, kept in a tracked location so it cannot be lost the same way
(§11.4.215: a document that binds work lives, tracked, in the repository).

`submodules/constitution` was deliberately NOT edited: other agents have
uncommitted work there. A later integrator places the text into the
constitution using these files.

This repository is PUBLIC. These files contain no credentials, no host
passwords and no private host names; hosts are named by role only.

## Files

| File | Contents |
|---|---|
| `00_README.md` | This index, provenance, measured facts, placement steps |
| `01_rule_texts.md` | The five full anchor blocks in canon format |
| `02_gate_design.md` | Every gate: `cm_` name, assertion, inputs, rc 0/1/2, fixtures, paired mutation, golden-FALSE case |
| `03_carrier_snippets.md` | Compact summaries for the constitution carriers, consumer pointer paragraph, template additions, user-scope index lines |
| `04_toc_status_changelog.md` | ToC entries, metadata-header values, changelog entry |
| `05_consumer_adoption.md` | Adoption checklist and the phased rollout for the reference multi-platform consumer |
| `06_open_questions.md` | Open questions with the defaults chosen; review slicing |
| `07_reconciliation_after_upstream_merge.md` | Clause-level matrix of A–E against upstream §11.4.277/§11.4.278, amendment plan and text, gate impact, implementation status, consumer pins, operator questions — **read this first** |

## The anchors in one line each

| Placeholder | Tentative | One line |
|---|---|---|
| ANCHOR-A | §11.4.277 | Every local-model obtain/run/query goes through ONE constitution-owned wrapper; direct `llmctl` calls in tracked files are banned. |
| ANCHOR-B | §11.4.278 | No model is used before a fresh, deterministic (≥3 identical runs), per-host validation record passes; `require-validated` is a precondition. |
| ANCHOR-C | §11.4.279 | Vision validation uses reproducibly generated golden screenshots of known content, machine-readable expectations, golden-bad controls and a deterministic judge; wrong answers are defects, never loosened. |
| ANCHOR-D | §11.4.280 | Every interactive-UI project runs HelixQA full suites over a screens × states × platforms ledger, with vision-decided frame-bound verdicts, BLOCKED never PASS, and a caught seeded defect per platform before release. |
| ANCHOR-E | §11.4.281 | Guides, FAQ, diagrams and exports change in the same commit; post-update hook and templates propagate. |

## Measured facts this proposal rests on

| Fact | Source | When |
|---|---|---|
| Canon's highest anchor is §11.4.276; 277+ free on both sides | orchestrator upstream fetch; drafting agent re-read local `Constitution.md` (heading list ends at §11.4.276; `Revision 72`, last modified 2026-10-05) | 2026-10-12 / 2026-10-14 |
| `llmctl` is its own repository; was 3.1.0 | orchestrator | 2026-10-12/13 |
| `llmctl` is now `VERSION` 3.2.2, `git describe` `v3.2.2-8-g3afac16` | drafting agent | 2026-10-14 |
| `llmctl` 3.2.2 ships `validate`, `vision validate`, `validate-all`, `require-validated`; deterministic judge; 7-day default freshness | `lib/validate.sh` header, `bin/llmctl` dispatcher | 2026-10-14 |
| Vision profiles `vision` :8082 (Gemma 3 4B + mmproj), `vision-pro` :8083 (Gemma 3 12B + mmproj); file sha256 pinned; `hf_revision` = `main` | `models/catalog.json` | 2026-10-14 |
| Suites: `chat-v1`, `coder-v1`, `embedding-v1`, `vision-golden-v1` (11 fixtures, golden + control-bad roles, byte-reproducible generator, fixed sampling) | `validation/suites/` | 2026-10-14 |
| Live runs: `vision` ×2 on 2026-10-13 (rc 0; run 2: 21 pass / 0 fail / 0 undetermined), `small` ×1 on 2026-10-14 (PASS) — one host only | `docs/qa/*/verdict.txt`, `validate.out` | read 2026-10-14 |
| HelixQA vision verdict engine had bluff paths; fix on `submodules/qa` branch `feature/vision-no-bluff` | orchestrator; drafting agent confirmed only the checked-out branch name | 2026-10-12/13; 2026-10-14 |
| Reference consumer: 46 UI screens (web 16, desktop 6, wizard 10, Android 4, Android TV 10), ~6–9 with screenshot assertions, most bank steps TODO prose | orchestrator | 2026-10-12/13 |
| Gate convention `scripts/gates/cm_<name>.sh` + `cm_<name>_mutation_test.sh`; ledger `gate_ledger*`; 3 project templates; anchor tooling `scripts/anchors/` | constitution checkout | 2026-10-14 |

Facts attributed to the orchestrator were NOT re-measured by the drafting
agent unless stated.

## Placement steps for the integrator

1. Re-check that §11.4.277–§11.4.281 are still free upstream; renumber
   placeholders if not.
2. Run the four review slices of `06_open_questions.md` (§11.4.276 budget,
   §11.4.209 review substrate).
3. Place the blocks from `01_rule_texts.md` after §11.4.276 in
   `Constitution.md`; the compact summaries from `03_carrier_snippets.md` §1 in
   the four constitution carriers, in lockstep.
4. Update the metadata header, ToC and changelog per `04_toc_status_changelog.md`;
   regenerate exports with the existing tooling.
5. Write the propagation gates first (they are mechanical), register them in the
   gate ledger with their mutation tests; schedule the mechanism gates of
   `02_gate_design.md` as tracked work items.
6. Then the consumer side: pointer paragraph and templates (`03` §2–§4), and the
   adoption checklist (`05`).

## Honest boundary (§11.4.6)

This is text, not mechanism. No wrapper, no gate, no relocated bank, no ledger
exists because of this commit. Nothing here has passed an independent review.
Where a fact was not measured it is marked UNCONFIRMED in the file that uses it.
