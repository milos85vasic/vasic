# Chapter 1 redaction review — public summary (T040 / FR-039)

**Counts and verdict only. This file deliberately contains no chapter content, no personal
name, no `pid`, and no transcript line reference.** It exists so that a reader of the public
umbrella repository learns *that* the review happened, *what* it found by category, and *what
it concluded* — without learning any of the material it reviewed.

The review itself, with every finding located by path, line, segment index, `pid` and word
index, lives in the **private** `workshop` submodule:

> `workshop/docs/redaction-review-chapter-01.md`

Detail and locations belong there, not here — see `docs/content-boundary.md`. Naming a private
path is allowed; reproducing what sits inside it is not, and nothing has been reproduced here.

T040 nominates no file in this directory for a summary, so this file was created for the
purpose.

| | |
|---|---|
| Reviewed | `workshop/curriculum/chapter-01/` — 4 in-scope artifacts, plus a 34-file blast-radius sweep |
| Reviewed on | 2026-09-02 |
| Reviewer | agent:redaction-review — a **recorded review**, not human sign-off |
| Requirement | FR-039 (`spec.md`), R1–R7 (`contracts/passage-contract.md` §7.3), publish precondition B5 (`contracts/pipeline-cli.md` §4.6/§4.7) |

## Findings by category — counts only

| Category | Count |
|---|---:|
| Natural persons named | **5** — of whom **3 are not parties to the recording** |
| Organisations named | **1** |
| Direct-identifier occurrences, total | **47** across 3 artifacts |
| Distinct passages (`pid`s) carrying a name or organisation | **12** |
| Occurrences reachable by no `pid` at all | **1** — a document title line, structurally outside the registry |
| Indirect-identifier findings | **6** |
| Third-party-confidential findings | **6** |
| Redaction decisions recorded | **17** — 13 REDACT, 3 KEEP, 1 NOT REMEDIABLE |
| Passages currently marked redacted in the registry | **0** of 11 622 |

## Measured negatives — actual empty results

Zero across all four in-scope artifacts: email addresses, `@handles`, URLs, bare domains,
telephone numbers, IP addresses, home/user filesystem paths, organisation legal suffixes,
identity-document references, credential values, high-entropy secret-shaped strings,
repository URLs, and any surname whatsoever. The curriculum exercise document and its sidecar,
and the whole `knowledge/` subtree of the chapter, contain **none** of the six confirmed
name or organisation tokens.

## Mechanism coverage

The registry carries a `redacted` field on every row and the API's redacted-passage path is
proven on the invented fixture corpus. **The tooling that would set it does not exist**:
`redact.sh` (T038), `redact.sh --review-only` and `chapters/NN/redaction-review.json` (T039),
and the append-only redactions log (T012) were each measured absent. Four propagation gaps are
recorded in the private review, including one derived index that promotes every reviewed name
to a first-class term row and carries no redaction field at all.

## Verdict — three-valued

| Question | Answer |
|---|---|
| May the `workshop` gitlink be pushed as-is? | **SAFE — and already moot.** All four artifacts sit in the submodule's committed tree, and that commit has already reached its private remote. The umbrella exposes only a commit SHA. Recorded honestly: T040 wants the review *before* the commit, and the commit came first. |
| May Chapter 1 be published, exported or served? | **NOT SAFE.** Two independent grounds: the substantive findings above, and publish precondition **B5** — `chapters/01/redaction-review.json` does not exist and cannot be produced until T038/T039 are built, so **R7 blocks publication and export irrespective of this review's conclusions**. This summary is not that artifact and must not be counted as satisfying B5. |
| Anything undetermined? | **YES — 4 items, none of them a pass.** No consent record for the named third parties exists anywhere in the module; the identity of the referent behind the already-public occurrence below was not verified; the 108 KB transcript was swept exhaustively by pattern but not read exhaustively by eye (the private review states that coverage boundary precisely); and one organisation name is redacted on shape rather than on confirmed spelling. |

## One finding is already public and is not fixable by redaction

A personal name appearing in the private chapter also appears in a **tracked, committed and
already-pushed** file of this public repository:

> `docs/setup-agents-wizard/LUMEN-STORE-INVENTORY.md`

The occurrence sits in the committed tree, and that commit has reached the public remote. Same
class as `docs/content-boundary-incident-2026-09-01.md`: a working-tree edit contains it and
does not remedy it, and excising it from history is an operator call, not a cleanup. Exact
locations are in the private review. The four other name probes return **zero** hits across
every tracked file of this repository.

## Does this unblock T104?

**No.** T104 is blocked on T040, and T040 has three halves: record the review, apply what it
identifies, and re-emit the transcript asserting R2. **Only the first is done.** The apply
half cannot run until T038 exists, and the contract artifact B5 requires cannot be written
until T039 exists. T040 should not be marked complete on the strength of this document.
