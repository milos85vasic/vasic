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
| Passages currently marked redacted in the registry | **10** — re-measured 2026-09-03 |

> **The row above used to read `0` of 11 622, and that figure is WITHDRAWN, not restated.** It was
> true when this summary was written on 2026-09-02 and false a few hours later: `redact.sh` landed
> the same evening and operator decision 26 applied the Category 1 subset. Everything below marked
> **UPDATED 2026-09-03** moved with it.

## Measured negatives — actual empty results

Zero across all four in-scope artifacts: email addresses, `@handles`, URLs, bare domains,
telephone numbers, IP addresses, home/user filesystem paths, organisation legal suffixes,
identity-document references, credential values, high-entropy secret-shaped strings,
repository URLs, and any surname whatsoever. The curriculum exercise document and its sidecar,
and the whole `knowledge/` subtree of the chapter, contain **none** of the six confirmed
name or organisation tokens.

## Mechanism coverage — **UPDATED 2026-09-03**

The registry carries a `redacted` field on every row and the API's redacted-passage path is
proven on the invented fixture corpus.

**The claim this section used to carry — *"The tooling that would set it does not exist"*, naming
`redact.sh` (T038), `redact.sh --review-only` and `chapters/NN/redaction-review.json` (T039), and
the append-only redactions log (T012) as each measured absent — is WITHDRAWN.** All four exist and
have run. Measured 2026-09-03: `workshop/scripts/redact.sh` is present and executable; the review
artifact is present and `redact.sh --check-review --chapter 01` exits **0** (*"is fresh; B5 is met
for chapter 01"*); the append-only logs carry **10** passage records and **1** span record. The
applying run reported **8 of 8** propagation targets reached, `0 PROBLEM · 0 UNDETERMINED`.

Four propagation gaps are recorded in the private review, including one derived index that
promotes every reviewed name to a first-class term row and carries no redaction field at all.

## Verdict — three-valued

| Question | Answer |
|---|---|
| May the `workshop` gitlink be pushed as-is? | **SAFE — and already moot.** All four artifacts sit in the submodule's committed tree, and that commit has already reached its private remote. The umbrella exposes only a commit SHA. Recorded honestly: T040 wants the review *before* the commit, and the commit came first. **Measured 2026-09-03, so this is no longer asserted from memory:** the 2026-09-01 commit of the transcript carried **6 of the 10** currently-redacted passages' exact text and **0** redaction markers; the 2026-09-02 commit carries **0 of 10** and 11 markers. The other 4 are COULD NOT DETERMINE — the registry text is today's rendering and the older blob is 788 B larger, so their absence there is not evidence they were absent from that rendering. |
| May Chapter 1 be published, exported or served? | **STILL NOT SAFE — but for ONE ground now, not two. UPDATED 2026-09-03.** The **B5** half is WITHDRAWN: `chapters/01/redaction-review.json` exists, `--check-review --chapter 01` exits **0**, and R7 no longer blocks. ~~The **substantive** half stands and is the whole of the remaining answer: of the 13 REDACT decisions, **6 are applied (F1, F2, F4–F7) and 7 are DEFERRED (F8, F9, F12–F16)** by operator decision 26.~~ **THAT CLAUSE IS WITHDRAWN 2026-09-03 (later the same day): all 13 are now resolved — 12 applied (F1, F2, F4–F7 under decision 26; F8, F9, F12–F15 under decision 28) and F16 needed no corpus change.** What still blocks publication is NOT the redaction backlog: it is (a) the review-level question of whether **2 of 27** withdrawn index terms, which a regeneration re-derives from still-VISIBLE passages, mean those passages must be withheld too, and (b) F17, which is NOT REMEDIABLE — already public, escalated. Category 2 indirect identifiers and Category 3 third-party-confidential material are descriptive findings that no token-level redaction reaches, and they are untouched. This summary is still not the B5 artifact and must still not be counted as one. |
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

## Does this unblock T104? — **UPDATED 2026-09-03**

**Still no, and the reason has changed.** T104 is blocked on T040, and T040 has three parts:
record the review, apply what it identifies, and re-emit the transcript asserting R2.

**The sentence this section used to carry — *"Only the first is done"*, with the apply half unable
to run until T038 exists and the B5 artifact unwritable until T039 exists — is WITHDRAWN.** Both
tools exist. Re-measured 2026-09-03: part 1 is **DONE**; part 3 is **DONE** — the applying run's
`exports` surface re-emitted the document and both sidecars (30 artifact-level changes), and the
R2 assertion measures **0 violations** over 10 redacted rows × 2 fields × 3 surfaces, with the
longest surviving common substring at **17 characters**; every third-party identifier reads **0**
occurrences post-redaction, against **47** before.

~~**Part 2 is what remains, and it is now the sole blocker: 7 of the 13 REDACT decisions are
deferred.** T040 must still not be ticked.~~ **WITHDRAWN 2026-09-03 (later the same day): PART 2 IS
APPLIED and T040 IS TICKED.** `curriculum/redactions.jsonl` went **10 -> 142** entries — **84**
passages under six per-finding reason codes (F8 2, F9 6, F12 3, F13 2, F14 69, F15 2) plus **48**
minted registry rows (36 `kg_term`, 12 `kg_area`) as the transitive closure of rows carrying a
string that occurs in a withheld passage and in no visible ingested one. **F16 needed no corpus
change**; the listing boundary it names was already in force. Final propagate exit **0**,
`targets reached (8/8)`, `0 PROBLEM · 0 UNDETERMINED`, idempotent on re-run; §7.3 R2 re-measured at
**0** residual across `transcript.md`, both timing sidecars, `exercise-01.md`, its sections sidecar,
`taxonomy.jsonl` and `area-materials.jsonl`. The reproduction recipe and the full measured split
live in `tasks.md` under T040.

**Two things did NOT close, and neither is a tooling defect.** (1) A regeneration from clean
re-derives **2 of the 27** withdrawn index terms, and does so from passages that are still VISIBLE
(3 visible occurrences each) rather than by reading withheld text — 25 of 27 do not come back.
Whether those passages should also be withheld is a REVIEW decision about the corpus. (2) That
regeneration's own `reconcile_and_taxonomy` stage exits **2** on a 180-second minting-bridge
timeout, so the row-level rebuild is UNDETERMINED; the `extract` stage completed (rc 0) and is what
the sweep above measured.
