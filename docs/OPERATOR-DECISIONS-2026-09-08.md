# Operator decisions — 2026-09-08

Recorded per §11.4.208 so a decision is not re-litigated and not silently
reinterpreted. Each row states the question, the decision, and what it obliges.

**CONTENT BOUNDARY.** This is a PUBLIC repository. Every row below refers to
private `workshop` material BY IDENTIFIER OR PATH ONLY. No transcript text, no
note text, no area title, no question text and no person's name appears here.

| # | Question | Decision | Status |
|---|---|---|---|
| 1 | Semantic-search leg needs an embedder; local models now off | **Keep semantic OFF.** Measured identical quality (top-1 18/22, top-5 19/22) at 9.4x the speed. Reversible with one env var | DECIDED |
| 2 | `meeting-notes` route deliberately NOT_BUILT on one undecided row | **Brainstorm fully, then implement — including Meeting Notes** | DECIDED |
| 3 | 3 documents unpublished on W2 violations | **Cite them, then publish** | DECIDED |
| 4 | 12 served areas carry no assessment | **Fill / generate what is missing. "Stick to common sense"** | DECIDED |
| 5 | The one flagged span (id `01M1H9DKFTVEJMW5YFZ1GC7PYN`) | **Serve it.** Operator inspected the span and judged it carries nothing private. Add a reason code for "flagged withheld-only by corpus statistics, judged not private" and record the decision against the row | DECIDED |
| 6 | The word-run rule that flagged it | **Keep the rule as-is.** It caught 4 genuine rows because it is wide. Future flags route to the operator as judgements | DECIDED |
| 7 | `meeting-notes` contract shape | **Match the three siblings exactly** — same cumulative `count` vs `own_count` split, same status set | DECIDED |
| 8 | 66 plan-coverage rows, 0 decided | **Show all in one pass** | DONE (sheet produced) |
| 9 | Sequencing against the QA session | **One batch, then QA.** Land everything, restart once, run the second adversarial review, then hand over | DECIDED |
| 10 | 20-passage evidence floor sorts on the wrong quantity (r = -0.066 against actual authorability) | **Re-baseline the floor onto anchored usable citable passages at 8, and author the banks.** REVISES decision #3 of 2026-09-07 on measured grounds | DECIDED |
| 11 | Filling every area empties the M4 proof arm's population | **Fill everything, give M4 a synthetic no-bank fixture** so the arm keeps detecting | DECIDED |
| 12 | 8 rows read as likely covered | **All 7 distinct points recorded COVERED** (one appears in two chapters). 5 carry evidence locators; 1 rests on operator judgement with no locator and says so in its own reason field | DONE |
| 13 | 11 plan rows are ASR fragments naming no deliverable | **Fix the extractor, retire the 11 as extraction defects** — NOT as `dropped`, which would put them in the commitment ledger | DECIDED |
| 14 | `MIN_SEGMENTS_FOR_INFORMATIVE_ABSENCE = 500` makes `not_covered` unreachable for short chapters | **Scale the guard to chapter length**, with its own validation and a paired mutation | DECIDED |
| 15 | Document 04's last 8 blocks cite evidence that has no passage id | **Ingest `pipeline/{README,CALIBRATION,AUDIT}.md`.** Operator rejected deleting the 8 measured claims and rejected the editorial exemption | DECIDED |
| 16 | 264 pre-existing citations of unverified relevance | **Audit them all**, and the same pattern in the already-published areas 01 and 03. Depublication is an acceptable outcome | DECIDED |
| 17 | `publication-reviews.jsonl` / `area-materials.jsonl` gitignored — the files gating what is served are not in version control | **Track them** | DECIDED |

| 18 | Every graded question answerable by shape alone: 138/138 keys are the longest option (100%), 122/138 at position 1 (88%), pass mark 70%, no shuffle anywhere in the serving path | **Fix properly: deterministic shuffle AND distractor rebalancing**, plus a gate that fails if either heuristic beats chance, with a paired mutation and a control | DECIDED |
| 19 | The producer/verifier split is process-scoped only; two invocations 2s apart publish on same-minted citations, and the prover's key arm is inverted so it passes with the protection removed | **Make it durable, fix the prover**, register it in the check registry, and close the `promote_curriculum_areas.py --apply` path that wrote 37 of 41 live review rows with no citation checking | DECIDED |
| 20 | QA session timing given the above | **Fix the blockers first, then QA.** The shape leak and the split are fixable in hours; everything else is measured and sound | DECIDED |

| 21 | 32 answer keys appear verbatim in the lesson section the question links to (31 of 290) — all against area-document prose, never a transcript | **Separate study mode from assessment mode.** Keep the keys and the study links; suppress `lesson_sections` in assessment/interview rendering. Rewording 31 correct keys was rejected as degrading good prose to defend a property only one mode needs | DECIDED |
| 22 | Two questions carry answers the evidence contradicts (an asserted absence the corpus refutes; "appears in neither transcript" where a redacted passage names it) | **Rewrite both to what the evidence supports**, neither withdrawn. The second preserves the ABSENT vs WITHHELD distinction the platform is built on | DONE |
| 23 | 52 flagged rows in the 30 older committed banks, unread | **Read and repair all 52.** Result: 51 repaired, 1 confirmed already supported — 98% PRECISION, which says nothing about recall | DONE |
| 24 | Areas 26 (5 anchored) and 23 (6) serve tests while 19 (5), 27 (6) and 28 (6) are refused — authorship date, not evidence, is the selector | **Author banks for 19, 27 and 28 to match.** Level up rather than withdraw two real banks. An agent may still decline any of the three if the evidence genuinely cannot support one | DECIDED |
| 25 | Four `kg_*` kinds (226 rows of TODOs, meeting notes, open questions, next-meeting points) exist in the index but were never in the advertised vocabulary | **Make them first-class searchable.** This is the session-record content built today — reachable through chapter routes but not through search | DECIDED |
| 26 | ROOT CAUSE: a bank obeying its own "cite nothing outside the evidence pack" constraint could not cite its own evidence | **SUPERSEDED — see 26a.** Originally "re-cut the packs on sentence boundaries"; the premise was measured false | WITHDRAWN |
| 26a | Re-measured: there is NO pack producer and NO artefact — the pack is derived by reading a Markdown file, and NO gate ever enforced membership (B1–B8 check resolution, redaction and lesson-section path, never pack membership). Only 30.6% of outside-pack citations sit at distance 1; the rest reach up to 644 segments away. Best closure admits 41.3% at 3.75× pack growth. Corpus re-cut separately proven unsafe: one merged pair moves `root_hash` `62e62eea…` → `960db1d2…`, orphans an anchor, and models are off so nothing can be re-embedded | **Withdraw the constraint entirely.** Replacement rule: cite the passage that carries the fact; admissible iff it RESOLVES UNREDACTED and AN AUTHOR HAS READ IT against the prompt. The constraint is wrong in KIND, not granularity | DECIDED |
| 26b | The withdrawn constraint's prose still stands verbatim in 6 banks, instructing future authors to obey the rule that caused the defect | **The agent already reading those files corrects the 6 `$comment` blocks in-pass** — recording what the rule said, that it is withdrawn, and why, rather than deleting it silently | DECIDED |
| 27 | 182 older-bank questions the screen never flagged, unread. Precision is 98%; recall is known poor (reading found 73% where the screen flagged 37.5%) | **Read all 182.** The measured defect rate in the UNFLAGGED population is the first honest estimate of the screen's recall | DECIDED |

## The defect behind the defect — recorded because the pattern repeated six times

Every stream today found that the reported symptom was real and the stated
mechanism was wrong. Fixing the stated mechanism would have produced a green
gate over an unfixed product in at least three cases.

- Shuffling choices would NOT have fixed the shape leak: the choice **id** was
  itself the key (`-c1` on 88.4%), so the key would have moved with its label on.
- The graded path was not BYPASSING citation withholding — the type it uses has
  no citations field, so the protection is **inapplicable**, and wiring it would
  have shipped an inoperative gate reading green forever.
- `proposer` was empty because a downstream check inferred independence from it;
  the field was lying to protect a **proxy**, and fixing the inference let the
  field tell the truth.
- The anchor defect was **fleet-wide**, not introduced this session — 34.2% in
  the older banks against 37.5% in the new ones.
- The evidence-pack constraint **guaranteed** the defect it existed to prevent.
- CK021 counted "no bank authored" and was read as "below the floor" — a correct
  number over the wrong set.

## Claims WITHDRAWN on 2026-09-08 after an adversarial review

Recorded because a withdrawn claim is worth more than a quiet correction.

- **"01 and 03 serve on hand-verified citations."** OVERSTATED. The citations were
  hand-read, but the review artifact records only a MECHANICAL check and says so
  in its own stamped text: it establishes that a citation RESOLVES, not that the
  cited passage SUPPORTS the claim. `reviewer` is the pipeline, not a person.
- **"dropped 0, vanished 0."** `dropped=0` is a real measurement. `vanished=0` is
  arithmetically FORCED — it is a residual, every branch increments exactly one
  counter, and the gate asserting it is therefore a false-green control
  (§11.4.201). The two must never be reported together as if both were measured.
- **"5 areas below the evidence floor."** WRONG POPULATION. CK021 fires on "no
  bank was authored", not "below the floor". Seven areas are below 8; two areas
  serve 9-question banks on 6 and 5 anchored passages because they predate the
  re-baseline and were grandfathered without a decision.
- **"261 questions across 34 banks"**, reported as an achievement without ever
  checking whether the questions test anything. See decision 18.
- **"The producer has been split from the verifier."** REFUTED. See decision 19.

## Still not put to the operator

- Document 05's four umbrella-facts have no citation path from inside this private
  repo. Options: rewrite to what this corpus supports (losing true content),
  ingest public umbrella governance output into the private corpus, or leave 05
  unpublished. None taken.
- Document 04's nine calibration blocks stay uncitable while the ingest is
  stopped. The ingest is blocked by a DETERMINED NEGATIVE: with models off there
  is no embedding endpoint, so new passages would enter the index with no vectors
  and be silently absent from semantic retrieval.
- The served `redactions` table holds 0 rows while the log records 162 effective
  suppressions. No text is exposed; the artifact simply cannot state WHY a row is
  withheld. Materialising it is an index rebuild.
- `-question-verify none` is not a recognised value (`focus|llm`), so L5 is
  unwired. The server reports it as unwired rather than silently selecting one.

## Decisions that overruled a recommendation

Recorded because a recommendation overruled is worth more than one accepted.

- **#12, the "three-hours web build" point.** The coordinating session advised
  AGAINST recording it, because the session demonstrates a web surface but no
  instrument established it is the SAME artefact the planned point refers to.
  **The operator recorded it anyway.** Obligation, and it is discharged: the
  disposition row carries NO evidence locator and its `reason` field states in
  full that it rests on operator judgement alone and must not be cited as
  evidence-backed. A `covered` decision is the only irreversible direction here
  — an undecided point merely carries forward — so this row is the one to
  revisit first if the plan later looks short.
- **#11 vs #10.** These two answers pull against each other: the re-baseline at
  8 clears 8 of the 12 areas, while "fill everything" reaches all 12 including
  the 4 a measurement calls genuinely thin. Resolved as: fill every area the
  evidence honestly supports, fabricate nothing, and REPORT any area that
  cannot be authored truthfully. An honest empty bank beats a padded one, and
  the M4 fixture removes the proof-population objection either way.

## Not yet put to the operator

- The served database's `redactions` table holds **0** rows while the log
  records **162** effective suppressions. No text is exposed — measured by S1 —
  but the served artifact cannot state WHY any row is withheld. Materialising
  it is an index rebuild.
- `-question-verify none` is not a recognised value (`focus|llm`), so **L5 is
  unwired**. The server reports it as unwired rather than silently selecting
  one, which is correct; but "none" arguably ought to be a legal value meaning
  deliberately-off.
- The 8 weakest evidence rows still await confirmation.
