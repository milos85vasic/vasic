## VSC-001 — adopt the §11.4.93 workable-items SQLite SSoT at the umbrella root, with per-sub-project identifiers

**Status:** Queued
**Type:** Task
**Severity:** high
**Created-By:** User

WHAT — this repository tracked work in prose (docs/OPERATOR-DECISIONS-*.md, specs/*/tasks.md) with no §11.4.93 single source of truth, which §11.4.93 calls a release blocker. HOW IT MANIFESTS — no item carried a stable id, a closed-set status or a closed-set type, so no query could answer what is open. HOW TO REPRODUCE — before this item, git ls-files docs/workable_items.db returned nothing. ACCEPTANCE CRITERIA — a tracked docs/workable_items.db exists, every item carries a valid status, type and prefixed id, the identifier roster is derived from .gitmodules, and a registered gate with a paired mutation proves the integrity check is not a bluff gate.

## CKT-001 — operator decision 2026-09-07 #1 — submodules/curriculum-kit is not a git repository; go.mod reaches outside the repo and no…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 1 of 2026-09-07. The question put to the operator was: `submodules/curriculum-kit` is not a git repository; `go.mod` reaches outside the repo and no truthful manifest entry can be written

DECISION — **Publish as `vasic-digital/curriculum-kit`, PUBLIC**, mount as a gitlink, declare in `helix-deps.yaml`

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 1; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 1.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — the source row names the path submodules/curriculum-kit.
## VSC-002 — operator decision 2026-09-07 #2 — 3 area documents fail publication review on 62/54/58 uncited claim blocks

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 2 of 2026-09-07. The question put to the operator was: 3 area documents fail publication review on 62/54/58 uncited claim blocks

DECISION — **Operator reads them.** Produce a bounded per-document list of exactly which claim blocks lack citations first

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 2; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 2.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-003 — operator decision 2026-09-07 #3 — Only 5 of 42 areas carry a test

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 3 of 2026-09-07. The question put to the operator was: Only 5 of 42 areas carry a test

DECISION — **Author senior banks for the 25 strongly + moderately evidenced areas**, against real transcript evidence, area by area. The 12 thin areas stay honestly without tests

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 3; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 3.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-004 — operator decision 2026-09-07 #4 — FR-002 asked for a topical classification the reviews decline to make

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 4 of 2026-09-07. The question put to the operator was: FR-002 asked for a topical classification the reviews decline to make

DECISION — **Build an automated topical classifier**, recorded with its confidence and given its own review

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 4; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 4.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-006 — operator decision 2026-09-07 #6 — SC-010 hue floor: gate reported 4 families over a defective instrument

**Status:** In progress
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 6 of 2026-09-07. The question put to the operator was: SC-010 hue floor: gate reported 4 families over a defective instrument

DECISION — **Fix the gate, then judge the real number.** Fixed; the corrected gate reports **2**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 6; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 6.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row is split — part DONE, part still OPEN — so neither a terminal status nor Queued is true; recorded as In progress

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-007 — operator decision 2026-09-07 #7 — Two chapter-card implementations; /chapters never uses the component extracted for it

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 7 of 2026-09-07. The question put to the operator was: Two chapter-card implementations; `/chapters` never uses the component extracted for it

DECISION — **Converge onto the shared component**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 7; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 7.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-008 — operator decision 2026-09-07 #8 — The 37-area lexicon is chapter-01-derived; chapters 02 and 02.01 were never mined

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 8 of 2026-09-07. The question put to the operator was: The 37-area lexicon is chapter-01-derived; chapters 02 and 02.01 were never mined

DECISION — **Mine both, propose new areas**, operator approves additions before they publish

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 8; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 8.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-009 — operator decision 2026-09-07 #9 — 12 documents' ingested .sections.json are stale; regenerating mints new passage ids

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 9 of 2026-09-07. The question put to the operator was: 12 documents' ingested `.sections.json` are stale; regenerating mints new passage ids

DECISION — **Leave stale, record it explicitly.** All 251 ids resolve; regenerating would churn the corpus and break existing citations

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 9; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 9.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## CNT-001 — operator decision 2026-09-07 #10 — tesseract absent (gate 5 → rc 2); bundle/bundler/jekyll absent (gate 6 asserts against…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 10 of 2026-09-07. The question put to the operator was: `tesseract` absent (gate 5 → rc 2); `bundle`/`bundler`/`jekyll` absent (gate 6 asserts against an 8-file fragment)

DECISION — **Provide both — CONTAINERISED, through `submodules/containers`**, not host packages. Operator directive: *"Make sure everything runs in containers, use our containers Submodule for all containers related work!"*

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 10; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 10.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — the source row names the path submodules/containers.
## VSC-010 — operator decision 2026-09-07 #11 — Content-boundary gate red at ~15,300 matches; decision packet never acted on

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 11 of 2026-09-07. The question put to the operator was: Content-boundary gate red at ~15,300 matches; decision packet never acted on

DECISION — **Judge the ~1,540 class-A inward rows** — 1,084 against private source, 68 against teaching material, three public files holding 1,120

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 11; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 11.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-011 — operator decision 2026-09-07 #12 — deploy-langs.sh downgrades a failed Jekyll build to a warning and still exits 0

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 12 of 2026-09-07. The question put to the operator was: `deploy-langs.sh` downgrades a failed Jekyll build to a warning and still exits 0

DECISION — **Fail the deploy on a failed build**, behind a flag for deliberate override

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 12; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 12.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## MVR-001 — operator decision 2026-09-07 #13 — milosvasic.ru/_site/ tracked: 8 files, 1 page, answers 1 of 525 sitemap URLs

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 13 of 2026-09-07. The question put to the operator was: `milosvasic.ru/_site/` tracked: 8 files, 1 page, answers 1 of 525 sitemap URLs

DECISION — **Untrack it, keep the ignore rule**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 13; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 13.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — the source row names the path milosvasic.ru.
## MVR-002 — operator decision 2026-09-07 #14 — 21 repositories have Actions enabled while declaring zero workflow files

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 14 of 2026-09-07. The question put to the operator was: 21 repositories have Actions enabled while declaring zero workflow files

DECISION — **Sweep the 20, exclude `milosvasic.ru`** — its `pages.yml` is the sole publish path for the live site

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 14; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 14.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — the source row names the path milosvasic.ru.
## DTK-001 — operator decision 2026-09-07 #15 — design-toolkit GitLab mirror 7 commits behind, recipe deliberately .disabled

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 15 of 2026-09-07. The question put to the operator was: `design-toolkit` GitLab mirror 7 commits behind, recipe deliberately `.disabled`

DECISION — **Enable the recipe and sync the mirror**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 15; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 15.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — the source row names the path design-toolkit.
## VSC-012 — operator decision 2026-09-07 #16 — Nothing committed this session; container serves the old binary

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 16 of 2026-09-07. The question put to the operator was: Nothing committed this session; container serves the old binary

DECISION — Restart once when all writers stop, then commit and push recursively

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-07.md row 16; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-07.md, table row 16.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-013 — operator decision 2026-09-08 #1 — Semantic-search leg needs an embedder; local models now off

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 1 of 2026-09-08. The question put to the operator was: Semantic-search leg needs an embedder; local models now off

DECISION — **Keep semantic OFF.** Measured identical quality (top-1 18/22, top-5 19/22) at 9.4x the speed. Reversible with one env var

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 1; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 1.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-014 — operator decision 2026-09-08 #2 — meeting-notes route deliberately NOT_BUILT on one undecided row

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 2 of 2026-09-08. The question put to the operator was: `meeting-notes` route deliberately NOT_BUILT on one undecided row

DECISION — **Brainstorm fully, then implement — including Meeting Notes**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 2; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 2.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-015 — operator decision 2026-09-08 #3 — 3 documents unpublished on W2 violations

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 3 of 2026-09-08. The question put to the operator was: 3 documents unpublished on W2 violations

DECISION — **Cite them, then publish**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 3; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 3.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-016 — operator decision 2026-09-08 #4 — 12 served areas carry no assessment

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 4 of 2026-09-08. The question put to the operator was: 12 served areas carry no assessment

DECISION — **Fill / generate what is missing. "Stick to common sense"**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 4; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 4.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-017 — operator decision 2026-09-08 #5 — The one flagged span (id 01M1H9DKFTVEJMW5YFZ1GC7PYN)

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 5 of 2026-09-08. The question put to the operator was: The one flagged span (id `01M1H9DKFTVEJMW5YFZ1GC7PYN`)

DECISION — **Serve it.** Operator inspected the span and judged it carries nothing private. Add a reason code for "flagged withheld-only by corpus statistics, judged not private" and record the decision against the row

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 5; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 5.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-018 — operator decision 2026-09-08 #6 — The word-run rule that flagged it

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 6 of 2026-09-08. The question put to the operator was: The word-run rule that flagged it

DECISION — **Keep the rule as-is.** It caught 4 genuine rows because it is wide. Future flags route to the operator as judgements

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 6; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 6.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-019 — operator decision 2026-09-08 #7 — meeting-notes contract shape

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 7 of 2026-09-08. The question put to the operator was: `meeting-notes` contract shape

DECISION — **Match the three siblings exactly** — same cumulative `count` vs `own_count` split, same status set

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 7; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 7.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-021 — operator decision 2026-09-08 #9 — Sequencing against the QA session

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 9 of 2026-09-08. The question put to the operator was: Sequencing against the QA session

DECISION — **One batch, then QA.** Land everything, restart once, run the second adversarial review, then hand over

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 9; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 9.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-022 — operator decision 2026-09-08 #10 — 20-passage evidence floor sorts on the wrong quantity (r = -0.066 against actual…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 10 of 2026-09-08. The question put to the operator was: 20-passage evidence floor sorts on the wrong quantity (r = -0.066 against actual authorability)

DECISION — **Re-baseline the floor onto anchored usable citable passages at 8, and author the banks.** REVISES decision #3 of 2026-09-07 on measured grounds

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 10; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 10.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-023 — operator decision 2026-09-08 #11 — Filling every area empties the M4 proof arm's population

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 11 of 2026-09-08. The question put to the operator was: Filling every area empties the M4 proof arm's population

DECISION — **Fill everything, give M4 a synthetic no-bank fixture** so the arm keeps detecting

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 11; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 11.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-025 — operator decision 2026-09-08 #13 — 11 plan rows are ASR fragments naming no deliverable

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 13 of 2026-09-08. The question put to the operator was: 11 plan rows are ASR fragments naming no deliverable

DECISION — **Fix the extractor, retire the 11 as extraction defects** — NOT as `dropped`, which would put them in the commitment ledger

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 13; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 13.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-026 — operator decision 2026-09-08 #14 — MIN_SEGMENTS_FOR_INFORMATIVE_ABSENCE = 500 makes not_covered unreachable for short…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 14 of 2026-09-08. The question put to the operator was: `MIN_SEGMENTS_FOR_INFORMATIVE_ABSENCE = 500` makes `not_covered` unreachable for short chapters

DECISION — **Scale the guard to chapter length**, with its own validation and a paired mutation

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 14; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 14.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-027 — operator decision 2026-09-08 #15 — Document 04's last 8 blocks cite evidence that has no passage id

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 15 of 2026-09-08. The question put to the operator was: Document 04's last 8 blocks cite evidence that has no passage id

DECISION — **Ingest `pipeline/{README,CALIBRATION,AUDIT}.md`.** Operator rejected deleting the 8 measured claims and rejected the editorial exemption

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 15; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 15.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-028 — operator decision 2026-09-08 #16 — 264 pre-existing citations of unverified relevance

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 16 of 2026-09-08. The question put to the operator was: 264 pre-existing citations of unverified relevance

DECISION — **Audit them all**, and the same pattern in the already-published areas 01 and 03. Depublication is an acceptable outcome

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 16; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 16.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-029 — operator decision 2026-09-08 #17 — publication-reviews.jsonl / area-materials.jsonl gitignored — the files gating what is…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 17 of 2026-09-08. The question put to the operator was: `publication-reviews.jsonl` / `area-materials.jsonl` gitignored — the files gating what is served are not in version control

DECISION — **Track them**

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 17; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 17.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-030 — operator decision 2026-09-08 #18 — Every graded question answerable by shape alone: 138/138 keys are the longest option…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 18 of 2026-09-08. The question put to the operator was: Every graded question answerable by shape alone: 138/138 keys are the longest option (100%), 122/138 at position 1 (88%), pass mark 70%, no shuffle anywhere in the serving path

DECISION — **Fix properly: deterministic shuffle AND distractor rebalancing**, plus a gate that fails if either heuristic beats chance, with a paired mutation and a control

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 18; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 18.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-031 — operator decision 2026-09-08 #19 — The producer/verifier split is process-scoped only; two invocations 2s apart publish on…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 19 of 2026-09-08. The question put to the operator was: The producer/verifier split is process-scoped only; two invocations 2s apart publish on same-minted citations, and the prover's key arm is inverted so it passes with the protection removed

DECISION — **Make it durable, fix the prover**, register it in the check registry, and close the `promote_curriculum_areas.py --apply` path that wrote 37 of 41 live review rows with no citation checking

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 19; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 19.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-032 — operator decision 2026-09-08 #20 — QA session timing given the above

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 20 of 2026-09-08. The question put to the operator was: QA session timing given the above

DECISION — **Fix the blockers first, then QA.** The shape leak and the split are fixable in hours; everything else is measured and sound

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 20; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 20.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-033 — operator decision 2026-09-08 #21 — 32 answer keys appear verbatim in the lesson section the question links to (31 of 290)…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 21 of 2026-09-08. The question put to the operator was: 32 answer keys appear verbatim in the lesson section the question links to (31 of 290) — all against area-document prose, never a transcript

DECISION — **Separate study mode from assessment mode.** Keep the keys and the study links; suppress `lesson_sections` in assessment/interview rendering. Rewording 31 correct keys was rejected as degrading good prose to defend a property only one mode needs

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 21; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 21.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-036 — operator decision 2026-09-08 #24 — Areas 26 (5 anchored) and 23 (6) serve tests while 19 (5), 27 (6) and 28 (6) are refused…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 24 of 2026-09-08. The question put to the operator was: Areas 26 (5 anchored) and 23 (6) serve tests while 19 (5), 27 (6) and 28 (6) are refused — authorship date, not evidence, is the selector

DECISION — **Author banks for 19, 27 and 28 to match.** Level up rather than withdraw two real banks. An agent may still decline any of the three if the evidence genuinely cannot support one

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 24; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 24.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-037 — operator decision 2026-09-08 #25 — Four kg_* kinds (226 rows of TODOs, meeting notes, open questions, next-meeting points)…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 25 of 2026-09-08. The question put to the operator was: Four `kg_*` kinds (226 rows of TODOs, meeting notes, open questions, next-meeting points) exist in the index but were never in the advertised vocabulary

DECISION — **Make them first-class searchable.** This is the session-record content built today — reachable through chapter routes but not through search

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 25; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 25.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-039 — operator decision 2026-09-08 #26a — Re-measured: there is NO pack producer and NO artefact — the pack is derived by reading…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 26a of 2026-09-08. The question put to the operator was: Re-measured: there is NO pack producer and NO artefact — the pack is derived by reading a Markdown file, and NO gate ever enforced membership (B1–B8 check resolution, redaction and lesson-section path, never pack membership). Only 30.6% of outside-pack citations sit at distance 1; the rest reach up to 644 segments away. Best closure admits 41.3% at 3.75× pack growth. Corpus re-cut separately proven unsafe: one merged pair moves `root_hash` `62e62eea…` → `960db1d2…`, orphans an anchor, and models are off so nothing can be re-embedded

DECISION — **Withdraw the constraint entirely.** Replacement rule: cite the passage that carries the fact; admissible iff it RESOLVES UNREDACTED and AN AUTHOR HAS READ IT against the prompt. The constraint is wrong in KIND, not granularity

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 26a; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 26a.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-040 — operator decision 2026-09-08 #26b — The withdrawn constraint's prose still stands verbatim in 6 banks, instructing future…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 26b of 2026-09-08. The question put to the operator was: The withdrawn constraint's prose still stands verbatim in 6 banks, instructing future authors to obey the rule that caused the defect

DECISION — **The agent already reading those files corrects the 6 `$comment` blocks in-pass** — recording what the rule said, that it is withdrawn, and why, rather than deleting it silently

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 26b; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 26b.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-041 — operator decision 2026-09-08 #27 — 182 older-bank questions the screen never flagged, unread. Precision is 98%; recall is…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** User

WHAT — operator decision 27 of 2026-09-08. The question put to the operator was: 182 older-bank questions the screen never flagged, unread. Precision is 98%; recall is known poor (reading found 73% where the screen flagged 37.5%)

DECISION — **Read all 182.** The measured defect rate in the UNFLAGGED population is the first honest estimate of the screen's recall

HOW IT MANIFESTS — the decision is recorded in docs/OPERATOR-DECISIONS-2026-09-08.md row 27; that document is the §11.4.208 operator-request ledger for the session.

HOW TO REPRODUCE — read docs/OPERATOR-DECISIONS-2026-09-08.md, table row 27.

ACCEPTANCE CRITERIA — the obligation the decision states is discharged with captured evidence per §11.4.5, recorded against this item.

STATUS BASIS — the source row records a DECISION, not an execution: the decision is made and the work is not evidenced complete

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-045 — 001-workshop-curriculum-platform T006 — [P] Configure linting/formatting to match the reference module (gofmt, Angular ESLint…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T006: [P] Configure linting/formatting to match the reference module (`gofmt`, Angular ESLint config) — **[UNWRITTEN, AND THE TASK CONTRADICTS ITSELF. Measured 2026-09-03; NEW note.** Neither half is configured. Frontend: `workshop/platform/frontend/` has **no** `.eslintrc*` and **no** `eslint.config.*`; `package.json` declares 11 scripts and **none is `lint`**; its `devDependencies` contain **no** package whose name matches `lint` or `prettier`. Go: nothing in `workshop/` runs `gofmt` as a gate, and `gofmt -l workshop/platform/backend` reports **3** unformatted files today (`cmd/knowledge-registry-backfill/main.go`, `internal/api/publication.go`, `internal/api/passages_publication_test.go`), which is a live demonstration that no gate is enforcing it. **The self-contradiction, and it needs an operator to resolve rather than an agent to guess:** this task says *"match the reference module"*, and the reference is `ai_interviewing/platform/frontend` (plan.md Structure Decision) — measured, **that module has no ESLint config either**: 5 scripts, none `lint`, zero lint devDependencies. So "match the reference" and "Angular ESLint config" point in opposite directions and cannot both be satisfied. Adopt ESLint and DIVERGE from the reference, or match the reference and drop the ESLint half; either is defensible, neither is this note's to choose. The `gofmt` half has no such ambiguity and is unblocked work]** — **BLOCKER:** the task contradicts itself — it says "match the reference module", and the reference (`ai_interviewing/platform/frontend`) has NO ESLint config either, so there is nothing to match · **OWNER:** **operator** — pick a lint baseline, or withdraw the "match the reference" clause (FR-013)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T006.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T006`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (AII, WSP), so it is attributed to the parent.
## VSC-046 — 001-workshop-curriculum-platform T015 — [TDD] [PATH NOT BUILT — symbol.go does not exist. Measured 2026-09-02, only the SCHEMA…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T015: [TDD] **[PATH NOT BUILT — `symbol.go` does not exist. Measured 2026-09-02, only the SCHEMA landed, in `registry.go`: `Symbol *string` at `:73`, `CREATE UNIQUE INDEX … passages_symbol_key ON passages(path, symbol)` at `:934`, `CREATE TABLE … symbol_aliases` at `:966`. No code reads or writes `symbol_aliases` — `registry.go:1091` names it among the tables this package never writes — so the behaviour this task contracts is still owed at the path named here]** Implement the code-passage matching key `(path, symbol)` and the `symbol_aliases` table in `submodules/passage/pkg/passage/symbol.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) §6.2, §6.4 and the §4.3 `symbol_aliases` DDL (SC-016a) — `origin` separates `authored` (written by the maintainer performing the rename; authoritative) from `detected` (ingest's heuristic, which can mis-attach two similar helpers), so a reviewer can see exactly which links rest on a guess. ~~**Conditional on T014**~~ **— UNBLOCKED 2026-09-03. T014 now exits `0` and names the producer (`pipeline/symbols`, a `go/parser` extractor owned by this feature, at `workshop/pipeline/symbols/`); see T014's own note for the A3/A4 rejection of Lumen's store and the B1–B6 confirmation of this one. This task is therefore UNWRITTEN WORK, not blocked work, and the block that used to excuse it is gone** — **BLOCKER:** none but the work — only the SCHEMA landed in `registry.go`; `symbol.go` is unwritten · **OWNER:** **implementer** — unblocked today (SC-016a, FR-037)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T015.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T015`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (PSG, WSP), so it is attributed to the parent.
## VSC-047 — 001-workshop-curriculum-platform T016 — [TDD] [PATH NOT BUILT — ingest_match.go does not exist and no equivalent landed…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T016: [TDD] **[PATH NOT BUILT — `ingest_match.go` does not exist and no equivalent landed anywhere]** Implement the §8 ingest matching branches for code passages in `submodules/passage/pkg/passage/ingest_match.go` — R2 attach on `(path, symbol)` · R3 attach through `symbol_aliases`, recording WHICH alias was used so `detected` links stay reviewable · R4 an unaliased rename ⇒ **exit `1`** for `workshop/`-owned code (§6.6 makes an `authored` alias a mandatory step of any rename inside the tree) and, for code outside `workshop/`, mint a new pid and record the orphaned old one so the broken citation is LOUD. Minting stays the last branch (M4). ~~**Conditional on T014**~~ **— UNBLOCKED 2026-09-03. T014 now exits `0` and names the producer (`pipeline/symbols`, a `go/parser` extractor owned by this feature, at `workshop/pipeline/symbols/`); see T014's own note for the A3/A4 rejection of Lumen's store and the B1–B6 confirmation of this one. This task is therefore UNWRITTEN WORK, not blocked work, and the block that used to excuse it is gone** — **BLOCKER:** none but the work — `ingest_match.go` is unwritten and no equivalent landed anywhere · **OWNER:** **implementer** — unblocked today (SC-016a, FR-037)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T016.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T016`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (PSG, WSP), so it is attributed to the parent.
## VSC-048 — 001-workshop-curriculum-platform T017 — [TDD] [PATH NOT BUILT — symbol_test.go does not exist; measured 2026-09-02 the…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T017: [TDD] **[PATH NOT BUILT — `symbol_test.go` does not exist; measured 2026-09-02 the identifier `G-PID-4` appears nowhere in `submodules/passage`]** Prove **SC-016a** via gate **G-PID-4** in `submodules/passage/pkg/passage/symbol_test.go` ([contracts/passage-contract.md](./contracts/passage-contract.md) §6.5, §6.6): rename a `workshop/`-owned symbol WITH an `authored` alias and assert the pid is preserved and its citations still resolve; then rename one WITHOUT an alias and assert the old pid resolves `not_in_registry` — a loud dead link — and that ingest reports the unaliased rename as exit `1`. **Paired mutation**: make unaliased renames mint a new pid silently and re-point the old citation by nearest-text match; the gate MUST go red. 100% of stale code references failing loudly is the entire criterion — a confident link to the wrong code is the failure it exists to prevent. ~~**Conditional on T014**~~ **— UNBLOCKED 2026-09-03. T014 now exits `0` and names the producer (`pipeline/symbols`, a `go/parser` extractor owned by this feature, at `workshop/pipeline/symbols/`); see T014's own note for the A3/A4 rejection of Lumen's store and the B1–B6 confirmation of this one. This task is therefore UNWRITTEN WORK, not blocked work, and the block that used to excuse it is gone** — **BLOCKER:** **predecessor T015 + T016** — G-PID-4 tests code that does not exist yet · **OWNER:** **implementer**, after T015/T016 (SC-016a, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T017.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T017`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (PSG, WSP), so it is attributed to the parent.
## WSP-005 — 001-workshop-curriculum-platform T019 — [P] [TDD] [PARTIAL — BUILT AND PROVEN, BUT ITS GATE READS THE WRONG EXIT CODE AND THE…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T019: [P] [TDD] **[PARTIAL — BUILT AND PROVEN, BUT ITS GATE READS THE WRONG EXIT CODE AND THE CONTRACTED OVERRIDE DOES NOT EXIST. Measured 2026-09-03; this is a NEW note, the task previously carried none.** `workshop/pipeline/detect_media.sh` EXISTS (26,095 B, executable) and does exactly what the first half of this task asks: it probes capability, never presence. `:27` — *"Never `--version`. Never `command -v`. Never `[ -x ]`"* — with `ffprobe` exercised by `-show_format -show_streams` on a 1 s fixture (`:192`, `:209`) and `ffmpeg` by an actual decode. **§1.1 paired proof RUN: `--prove-failure` → rc 0, `PROVE: 4 mutations, 4 caught, 0 missed`**, and it opens with the control this task's own text demands — `PROVE: control — BROKEN fake PASSES a naive '--version' presence check (rc 0)`. It is registered as check `media-presence` in `workshop/platform/gates/check-registry-001.tsv` with a real rc-2 probe (`--scratch-dir /nonexistent/…` → rc **2**, measured). **The trap this task exists to catch is live on this host and the tool catches it**: a plain run resolves `ffprobe` to `/home/…/.cache/ms-playwright/ffmpeg-1011/ffmpeg-linux`, which answers `--version` and prints `Unrecognized option 'show_format'`, and the probe reports `ffprobe UNUSABLE` with that evidence. **TWO MEASURED DIVERGENCES FROM G-CLI-3, and they are the open half.** (1) **The exit code is wrong against the contract.** An unusable tool exits **`1`** (`RESULT 1 UNUSABLE — a required tool cannot do its job`), and mutations M2/M3 assert `rc=1`. But `contracts/pipeline-cli.md` §3.2 **P4** and gate **G-CLI-3** at `:317` both require exit **`2`** with `reason.code: "ffprobe_unusable"` — *"an unusable tool determines nothing"*, this task's own words. `grep -n 'ffprobe_unusable\|reason.code' workshop/pipeline/detect_media.sh` returns **zero**. (2) **`WORKSHOP_FFPROBE` / `WORKSHOP_FFMPEG` do not exist** — `grep -oE '\$\{?[A-Z_]*FFPROBE[A-Z_]*' ` over that script returns nothing — so G-CLI-3 *as written* (*"point `WORKSHOP_FFPROBE` at Playwright's ffmpeg binary"*) cannot be run at all, even though the situation it describes is the host's actual state. **Which of `1` and `2` is right is a real question and NOT a clerical one** — standing rule 2 says a missing or crashed dependency is always `2`, while a tool that is present and answers wrongly is arguably a determined finding — but the contract, the gate and this task all say `2`, and the code says `1`, so **something must change and it is not this note's call to decide which.** Until then G-CLI-3 is unsatisfied]** Implement media-tooling detection in `workshop/pipeline/detect_media.sh` — probe `ffmpeg`/`ffprobe` for actual capability, not `--version`; `ffprobe` here is a Playwright symlink that answers `--version` and rejects `-show_format`. Gate **G-CLI-3** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §3.2, §5): point `WORKSHOP_FFPROBE` at Playwright's ffmpeg binary and assert exit `2` with a tooling reason, never `1` — an unusable tool determines nothing. **Paired mutation**: replace the capability probe with `ffprobe --version`; the gate MUST go red, because that binary answers `--version` happily and the probe would pass over a tool that cannot do the job — **BLOCKER:** none but the work — the script exists and runs; its gate reads the wrong exit code and the contracted override is unwritten · **OWNER:** **implementer** — unblocked today (FR-033, SC-013, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T019.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T019`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-006 — 001-workshop-curriculum-platform T020 — [P] [TDD] Implement backend/model detection in workshop/pipeline/detect_backend.sh…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T020: [P] [TDD] Implement backend/model detection in `workshop/pipeline/detect_backend.sh` following `scripts/lumen-reindex.sh`'s env → config → live probe → documented fallback ladder — **[PATH NOT BUILT — `workshop/pipeline/detect_backend.sh` does not exist. Measured 2026-09-02, PART of the substance landed at a different path, for the ANSWERING backend only: `workshop/scripts/_capabilities.sh` carries the env-override rung, a live daemon probe and a documented read-only fallback. The config-file rung and ASR-model-backend detection are absent, so this task is not satisfied by that file — read it before rebuilding, then build the missing rungs]** — **BLOCKER:** none but the work — `detect_backend.sh` is unwritten · **OWNER:** **implementer** — unblocked today (FR-023)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T020.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T020`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-049 — 001-workshop-curriculum-platform T021 — [P] [PARTIAL — ONE OF ITS TWO GATES IS BUILT AND PROVEN, THE OTHER EXISTS NOWHERE.…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T021: [P] **[PARTIAL — ONE OF ITS TWO GATES IS BUILT AND PROVEN, THE OTHER EXISTS NOWHERE. Measured 2026-09-03; NEW note.** The scripts and the adapter are real: `workshop/scripts/start.sh`, `stop.sh`, `status.sh` and the Go adapter `workshop/platform/orchestration/cmd/workshop-boot/main.go`, which reports `RUNNING`/`STOPPED`/`DEGRADED` *"or exit 2 when it cannot tell"* (`:126`). **G-CLI-17 is DONE**: `bash workshop/platform/gates/verify-status-exit-contract.sh` → rc **0**, `PASS=3 FAIL=0 UNDET=0` — A1 an absent project prints `STOPPED` and exits **1**, A2 `status.sh` passes the control plane's code through unchanged, A3 `RUNNING → 0` while `STOPPED → 1` are distinguishable by exit code alone; and its **§1.1 paired mutation** `prove-status-exit-contract.sh` → rc **0**, `CAUGHT=2 MISSED=0`, seeding **MS1** (`STOPPED` exits 0 — the exact `return nil` regression this task names) and **MS2** (`STOPPED` filed as 2), each proven to COMPILE and LINK before being judged, then the tree restored. **G-CLI-12 IS UNBUILT, and so is the behaviour it would gate.** `grep -rn 'G-CLI-12'` over `workshop/` returns **zero** files — no gate, no fixture, no registry row — and the branch itself does not exist: `grep -rn 'unidentif\|identity cannot\|port holder'` over `cmd/workshop-boot/main.go`, `status.sh` and `_common.sh` also returns **zero**. There is no path on which `status.sh` meets a published port held by a process whose identity cannot be established and answers **2**; today that case is simply not distinguished from the `DEGRADED`/`STOPPED` negatives, which is the exact conflation standing rule 2 forbids. What remains: the unidentifiable-holder branch, its `2`, and the paired mutation that makes it return `1`]** Create `workshop/scripts/{start,stop,status}.sh` over a Go consuming adapter that calls `submodules/containers`' **Go API** — consumption, not reimplementation (§11.4.76(4)). **Do NOT wrap `cmd/boot`**: measured 2026-09-01, that CLI hardcodes a `helixagent` endpoint, accepts no `ComposeFile`, and constructs `BootManager` with neither an orchestrator nor a health checker, so pointed at this project it **exits `0` having started nothing** — a silent false pass, which standing rule 2 forbids. The adapter constructs the manager with this project's compose file and health checker; anything the adapter needs that the submodule cannot express must be contributed upstream, not forked here. Gate **G-CLI-12** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5): bind the published port with a process whose identity cannot be established and assert `status.sh` exits `2`, not `1` — an unidentifiable holder is could-not-determine, while `DEGRADED` (containers exist but not all are running) is a determined negative and stays `1`. **Paired mutation**: make the unidentifiable-holder branch return `1`; the gate MUST go red. Gate **G-CLI-17** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.8, §5) — **assigned to this task 2026-09-02 by operator decision**, because the contract itself calls it the sibling of G-CLI-12 on the same script: `status.sh` against a project with **no containers** prints `STOPPED` **and** exits `1`, a determined negative distinguishable by exit code alone from `RUNNING`'s `0`. Reproduce with `WORKSHOP_PROJECT_NAME=<unused-name> bash workshop/scripts/status.sh`. **Paired mutation**: restore the `return nil` in `cmdStatus`'s `len(statuses) == 0` branch — i.e. reproduce the behaviour measured on 2026-09-01; the gate MUST go red — **BLOCKER:** none but the work — one of the two contracted gates exists nowhere · **OWNER:** **implementer** — unblocked today (FR-012, FR-033, SC-013, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T021.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T021`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (CNT, WSP), so it is attributed to the parent.
## VSC-050 — 001-workshop-curriculum-platform T022 — [REVIEW] Review the passage contract implementation against…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T022: [REVIEW] Review the passage contract implementation against [contracts/passage-contract.md](./contracts/passage-contract.md) before anything consumes it — every other component depends on its shape — **BLOCKER:** **predecessor T015-T017** — the contract cannot be reviewed as a whole while its symbol half is unwritten; the review itself is a human judgement, not a gate · **OWNER:** **human reviewer**, after T015-T017 (FR-037)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T022.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T022`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-012 — 001-workshop-curriculum-platform T028 — [US1] [TDD] Implement atomic checkpoint/resume (write-temp → fsync → rename) in…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T028: [US1] [TDD] Implement atomic checkpoint/resume (write-temp → fsync → rename) in `workshop/pipeline/transcribe/checkpoint.py` per FR-029 — **[PATH NOT BUILT for the CHECKPOINT half; the ATOMIC-WRITE half moved. Measured 2026-09-02: `checkpoint.py` and the `transcribe/` directory do not exist, but `workshop/pipeline/run_faster_whisper.py:179`–`:184` already implements exactly the contracted shape — `tmp = out.with_suffix(out.suffix + ".tmp")` → `json.dump` → `fh.flush()` → `os.fsync(fh.fileno())` → `tmp.replace(out)`. Do NOT rebuild that. What is genuinely absent is checkpoint/resume across chunks and any `--resume` flag, and it depends on T025's chunker, ~~which is also unbuilt~~ **— UNBLOCKED 2026-09-03: T025's chunker is now BUILT, PROVEN (8/8 mutations caught) and TICKED at `workshop/pipeline/transcribe/chunker.py`, so the dependency this note named is discharged and the remaining work is unwritten, not blocked. Re-measured the same day: `workshop/pipeline/transcribe/checkpoint.py` still does not exist, and the atomic-write half at `run_faster_whisper.py:179`–`:184` is unchanged — do NOT rebuild it**]** — **BLOCKER:** none but the work — the checkpoint half is unwritten · **OWNER:** **implementer** — unblocked today (FR-029)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T028.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T028`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-013 — 001-workshop-curriculum-platform T029 — [US1] [TDD] [PATH CORRECTED 2026-09-02 for the IDENTITY, [PATH NOT BUILT] for the GATE…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T029: [US1] [TDD] **[PATH CORRECTED 2026-09-02 for the IDENTITY, `[PATH NOT BUILT]` for the GATE — this task named `workshop/pipeline/transcribe/coverage.py`, which does not exist. The identity landed in Go, in the backend: `workshop/platform/backend/pkg/curriculum/curriculum.go` `ComputeCoverage` at `:428`, `UnexplainedGapS` at `:503`, `Complete = UnexplainedGapS == 0` at `:504`, the identity string in the `Identity` field at `:376`; it is served at `internal/api/chapters.go:177`/`:362` and made a contract violation for a published chapter at `:216`. **Do not rebuild the arithmetic.** Gate G-CLI-4 and its tolerate-gaps mutation are what remain, and they must gate whatever actually computes coverage — which is this Go path, not a Python module. — **BLOCKER:** none but the work — the identity landed in Go; the GATE is unwritten · **OWNER:** **implementer** — unblocked today (FR-001, SC-001)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T029.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T029`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-051 — 001-workshop-curriculum-platform T030 — [US1] Emit the markdown transcript with pid anchors and timestamps to…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T030: [US1] Emit the markdown transcript with pid anchors and timestamps to `workshop/curriculum/chapter-01/transcript.md` — **[PATH CORRECTED 2026-09-02 — this task named `workshop/chapters/01/transcript/transcript.md`; that directory does not exist (`workshop/chapters/01/` holds the recording and its archive parts only) and the timestamped transcript landed at `workshop/curriculum/chapter-01/transcript.md`. The TIMESTAMP half is built; the **pid-anchor half is not** — `grep -rl '<!-- pid:' workshop --include='*.md'` returns zero files across the whole submodule, and passage identity currently lives only in `workshop/curriculum/passages.jsonl`. **RE-MEASURED 2026-09-03: unchanged. `workshop/curriculum/chapter-01/transcript.md` EXISTS (and T040's R2 assertion was re-run against it, 0 violations across 3 surfaces), and `grep -rl '<!-- pid:' workshop --include='*.md'` STILL returns ZERO files.** The consequence reaches further than this task: T009 built the anchor reader/writer at `submodules/passage/pkg/passage/anchor.go` and it is ticked, but nothing in the tree has ever written an anchor into a document, so T113's `--write-anchors` has nothing to switch on and the §8 R1b/R1c duplicate- and foreign-anchor branches have never been exercised against a real source. PARTIAL: timestamps done, anchors unwritten, nothing blocking]** — **BLOCKER:** none but the work · **OWNER:** **implementer** — unblocked today (FR-001, FR-002, FR-037)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T030.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T030`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (PSG, WSP), so it is attributed to the parent.
## VSC-052 — 001-workshop-curriculum-platform T031 — [US1] [TDD] Implement the immutable machine layer + append-only correction overlay in…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T031: [US1] [TDD] Implement the immutable machine layer + append-only correction overlay in `workshop/platform/backend/pkg/transcript/layers.go` per FR-038 — the machine output is evidence and must survive correction. **[PATH NOT BUILT — neither `layers.go` nor the `pkg/transcript/` directory exists, and no equivalent landed anywhere. The nearest thing on disk is the `corrections` DDL at `submodules/passage/pkg/passage/registry.go:936`–`:944`, which `registry.go:1091` says that package never writes; a table declaration is not the layered type this task contracts]** — **BLOCKER:** none but the work — `layers.go` is unwritten · **OWNER:** **implementer** — unblocked today (FR-038)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T031.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T031`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (PSG, WSP), so it is attributed to the parent.
## WSP-016 — 001-workshop-curriculum-platform T034 — [US1] Freeze and hash the normaliser in workshop/pipeline/compare_engines.py BEFORE the…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T034: [US1] Freeze and hash the normaliser in `workshop/pipeline/compare_engines.py` BEFORE the first measurement — **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/accuracy/normaliser.py`; neither it nor the `accuracy/` directory exists, and the normaliser landed inside `workshop/pipeline/compare_engines.py` (`norm_word` `:52`, `align` `:113`), which `workshop/scripts/verify-accuracy.sh:112` resolves as `$NORMALISER`. **The FREEZING is what is missing, not the normaliser**: `verify-accuracy.sh` measures its sha256 on every run and enforces it only when `--normaliser-sha256` is passed (default empty at `:113`), and no frozen hash is committed anywhere — no `*.sha256` under `workshop/pipeline/`, no normaliser record under `workshop/evidence/`. **RE-MEASURED 2026-09-03: unchanged and still accurate.** `NORMALISER_SHA=""` at `verify-accuracy.sh:113`, set only by `--normaliser-sha256` at `:132`, and enforced at `:588` — so the enforcement path is BUILT and simply never armed. The only `*.sha256` file anywhere under `workshop/` outside `venv/`/`engines/` is the chapter-01 recording's own checksum, which is a different artifact. **The whole remaining task is: measure `compare_engines.py`'s sha256 once, commit it as the frozen value, and make `verify-accuracy.sh` default to it instead of to the empty string** — after which an edit to the normaliser makes every prior accuracy figure loudly unreproducible instead of silently incomparable. This must happen BEFORE T037(b)'s reference is scored, not after. UNWRITTEN, nothing blocking]** — **BLOCKER:** none but the work — the normaliser must be frozen and hashed BEFORE the first measurement, so this gates T035 and T037 · **OWNER:** **implementer** — unblocked today, and it is the head of the accuracy chain (FR-004, SC-002)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T034.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T034`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-017 — 001-workshop-curriculum-platform T035 — [US1] [TDD] Paired mutation proof for the scorer in workshop/scripts/verify-accuracy.sh…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T035: [US1] [TDD] Paired mutation proof for the scorer in `workshop/scripts/verify-accuracy.sh --selftest` — a transcript with a known injected WER must produce that WER. **[PATH CORRECTED 2026-09-02 — this task named `workshop/pipeline/accuracy/score_mutation_test.sh`; neither it nor the `accuracy/` directory exists, and the mutation harness landed inside the scorer wrapper as `workshop/scripts/verify-accuracy.sh --selftest` (`:88`, `:140`, `:393`, `:405`). **Do not build a second harness** — extend that one. What is genuinely missing is THIS task's assertion: the existing selftest degrades a reference and checks that a threshold is crossed, which is not the same as asserting that a KNOWN INJECTED WER produces THAT WER. — **BLOCKER:** **predecessor T034** — a scorer mutation proof is meaningless until the normaliser is frozen · **OWNER:** **implementer**, after T034 (FR-004, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T035.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T035`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-054 — 001-workshop-curriculum-platform T037 — [US1] Produce and publish the Chapter 1 accuracy report: the METHOD statement (FR-004),…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T037: [US1] Produce and publish the Chapter 1 accuracy report: the METHOD statement (FR-004), the SAMPLE CENSUS, and the MEASURED accuracy figure (SC-002). — **BLOCKER:** **predecessor T034 + T035** — no accuracy figure may be published before the scorer that produced it is frozen and mutation-proved · **OWNER:** **implementer**, after T034/T035 (FR-004, SC-002)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T037.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T037`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-021 — 001-workshop-curriculum-platform T041 — [US1] [REVIEW] Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T041: [US1] [REVIEW] Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the recording is dual-mono at −90.3 dB and AGC-flattened, so both diarization cues are measurably absent) — **[BLOCKED ON THE OPERATOR. Measured 2026-09-03; NEW note.** This is human labour by construction: D-TRANS-2 measured both diarization cues absent, so no tool on this host can attribute a line to a speaker, and no agent can substitute for the person who was in the room. Nothing else blocks it. **A TRAP, AND IT IS THIS FILE'S OWN COLLISION WARNING BITING: `workshop/docs/session-evidence/t041-decision-packets.md` (untracked, written 2026-09-03) IS NOT THIS TASK.** Its subject is R3 contradiction typology over taxonomy terms — that is **`002:T041`**. Its own opening line says *"T041 remains `[ ]`"*, and a reader who resolves that bare id against this file will conclude something false about speaker attribution. Cite it as `002:T041`, per standing rule at the head of this document. **No artifact recording a human speaker-attribution review exists for `001:T041`**]** — **BLOCKER:** **operator decision, and it is human labour** — speaker attribution is HUMAN by D-TRANS-2: the recording is dual-mono at -90.3 dB and AGC-flattened, so both diarization cues are measurably absent. No amount of engineering substitutes for someone listening · **OWNER:** **operator** — nothing an agent can do closes this (FR-005)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T041.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T041`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-028 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Time a real fresh-clone-to-running run against SC-004 15-minute budget (spec 001 T051) and record it in workshop/docs/quickstart.md WHY: the change lives in the private workshop submodule's own repository, needs a live-service run, install, push or an operator choice; this wave may not edit it UNBLOCK: - [1] operator performs the timed run on a clean host and records it in workshop; cost: clean clone, container start, workshop commit + gitlink bump
- [2] drop SC-004 to unmeasured; cost: budget claim stays unevidenced WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-060 — 001-workshop-curriculum-platform T059 — [US3] [TDD] [PARTIAL — R1 IS DONE ON BOTH LEGS AND PROVEN; R5 IS A COMMENT. Measured…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T059: [US3] [TDD] **[PARTIAL — R1 IS DONE ON BOTH LEGS AND PROVEN; R5 IS A COMMENT. Measured 2026-09-03; NEW note.** **R1, lexical leg**: `pkg/index/generation.go:80`–`:101` drops `rec.Redacted` from the member set AND from the root hash at BUILD time — not at render time — with `passages_fts` exclusion by construction in `submodules/passage`'s `BuildDB` (documented at `generation.go:8`–`:14`). Proven live: `verify-redaction-propagation.sh` → rc **0** with `A10b R1 holds: a suppressed row is absent from the lexical index`, and its §1.1 pair → rc **0**, 6/6 mutations caught. **R1, embedding leg**: `pkg/search/semantic.go:381`–`:385` — `SELECT p.pid … WHERE p.redacted = 0` inside `IndexVectors`, i.e. also at build time, counter-checked at `cmd/index-embed/main.go:99`; the read-time filter at `semantic.go:136`–`:137` is additive belt-and-braces, not the primary, which is exactly what this task demands. **R5 IS NOT IMPLEMENTED.** `generation.go:57`–`:62` states the requirement *in a comment* — *"Callers that redact must therefore treat the window … as `degraded`"* — and the state vocabulary two lines away at `:46`–`:50` is `building` / `verified` / `live` / `superseded`, with **no `degraded` member**. Live `GET /api/index/status` returns 6 keys and none is `degraded`. **Do not mistake `pkg/search/degraded.go:35`–`:37` for this**: those `Degraded*` constants are upstream-Lumen SEARCH markers (T056's reindexing string), a different concept at a different layer. So between a recorded redaction and the completed rebuild, the index serves a generation it knows contains the passage and says nothing — which is the same unclosed window T038's missing *"mark the live generation as requiring a rebuild"* clause leaves open, seen from the other end. **These two are one gap and should be closed together**]** Enforce redaction rules **R1** and **R5** in `workshop/platform/backend/pkg/index/generation.go` per [contracts/passage-contract.md](./contracts/passage-contract.md) §7.3 (FR-039): redacted pids are excluded from `passages_fts` AND from the embedding set **at generation-build time**, so neither leg can return a redacted passage; and until the post-redaction rebuild completes the index reports `degraded` rather than serving a generation known to contain the passage. Filtering at render time is not compliance — the passage would still be retrievable — **BLOCKER:** none but the work — R1 is done and proven on both legs; R5 is a comment · **OWNER:** **implementer** — unblocked today (FR-039, FR-020)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T059.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T059`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names paths in more than one sub-project (PSG, WSP), so it is attributed to the parent.
## WSP-038 — 001-workshop-curriculum-platform T067 — [US3] [PATH NOT BUILT — workshop/docs/search.md does not exist, and the media boundary…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T067: [US3] **[PATH NOT BUILT — `workshop/docs/search.md` does not exist, and the media boundary is not stated at any other path either; the docs directory holds `faq.md`, `knowledge-model-contract.md`, `limits.md`, `manual.md`, `quickstart.md`, `README.md`, `user-guide.md`, `work-register.md` plus the `prompts/`, `research/`, `training/` and `session-evidence/` trees]** Document the media boundary in `workshop/docs/search.md` — audio and video are reachable THROUGH transcripts, not indexed directly; Lumen's extension allowlist is a compile-time var with no override (FR-031 requires stating what the system cannot do) — **BLOCKER:** none but the work — `docs/search.md` is unwritten. Two clauses of the task text are FALSE and must be corrected rather than transcribed; see the note · **OWNER:** **implementer** — unblocked today (FR-031, FR-016)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T067.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T067`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-039 — 001-workshop-curriculum-platform T073 — [US4] [TDD] [PARTIAL — L4 EXISTS AND IS WIRED, BUT BOTH HALVES OF THIS TASK'S OWN…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T073: [US4] [TDD] **[PARTIAL — L4 EXISTS AND IS WIRED, BUT BOTH HALVES OF THIS TASK'S OWN PARENTHESIS DIVERGE, AND IT CANNOT BE EXERCISED ON THIS HOST. Measured 2026-09-03; NEW note.** Built: `pkg/answer/verify.go:363`–`:470` `EntailmentSupport`, wired into `VerifyClaims` at `:158`; `go test ./...` across all 25 backend packages is rc **0**, `pkg/entail` and `pkg/answer` included. **Divergence 1 — the floor is LEXICAL, not an embedding floor.** `NewEntailmentSupport(lexical *LexicalSupport, judge entail.Judge)` at `:392`–`:403`. The file states this against itself at `:226`–`:227` and `:237`, which is honest, but this task says *"embedding floor"* and no embedding is consulted. **Divergence 2 — it is not BATCHED.** `pkg/entail/entail.go:57`–`:69` takes one `(premise, hypothesis)` per call and `grep -n 'Batch'` over non-test `pkg/entail/*.go` returns **0**; `verify.go` loops claim × citation. On CPU-only generation (~21 s to ~95 s per call, per T083's own figures) that is the difference between a usable layer and an unusable one. **Divergence 3 — it CANNOT RUN HERE, and the tree says so rather than pretending.** `verify-entailment-loads.sh` → rc **2 UNDETERMINED** (*"U4 was not asked"*) because no `model.onnx` exists anywhere under `workshop/` (`find` = 0 hits), even though `pipeline/venv` carries onnxruntime 1.29.0. Its pair `prove-entailment-loads.sh` → rc **0** (5 caught, 2 controls at rc 2), and `gates/prove-mutations.sh` → rc **2** at `PROVED 25 / COULD-NOT-RUN 3 of 28`, M26 and M28 skipped for that same missing model. **That rc 2 is the correct answer and is NOT a pass** — it is also why the whole answering chain above (T078, T079) is being measured with L4 effectively absent. Obtaining or building the ONNX judge model is plausibly an operator decision; the lexical-vs-embedding floor and the batching are unwritten work]** Implement L4: support verification (embedding floor, then batched entailment) — **BLOCKER:** **host capability** — L4 exists and is wired, but it cannot be exercised on this host · **OWNER:** **operator** — needs a host that can run it, or an explicit decision to record it unmeasurable (SC-009, FR-021, FR-022)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T073.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T073`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-069 — 001-workshop-curriculum-platform T075 — [US4] [TDD] [PARTIAL — THE A4 HALF IS DONE AND TESTED; THE STORED-ANSWER HALF IS…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T075: [US4] [TDD] **[PARTIAL — THE A4 HALF IS DONE AND TESTED; THE STORED-ANSWER HALF IS UNBUILT AND THERE IS A LIVE CACHE IT DOES NOT COVER. Measured 2026-09-03; NEW note.** **DONE**: `pkg/answer/verify.go:126`–`:134` maps `passage.OutcomeRedacted` to `Decline: ReasonRedactedEvidence` and withdraws the WHOLE answer — claims are never stripped to keep it presentable (§7.2 C4); the constant is `pkg/answer/outcome.go:133`, enumerated at `:160`, and it is covered by `pkg/answer/pipeline_test.go:270` and `citations_verified_test.go:173`, both passing under the rc-0 `go test ./...`. **NOT DONE, and the reasoning that excuses it is measurably out of date.** `internal/redaction/plan.go:596`–`:606` declares propagation target `stored_answers` as `StatusAbsent`, count 0, on the ground that *"no answer cache is persisted"* — **but `pkg/answer/jobs.go:25`–`:45` holds a 30-minute in-memory job cache carrying `outcome *Outcome` (`:45`, `:164`, `:200`), and `grep 'redact\|withdraw' jobs.go` returns 0 hits.** So an answer computed before a redaction and polled after it is served unchecked for up to thirty minutes. Not persisted is not the same as not served, and this task's own words are *"Redaction propagates to stored answers, not merely to the rendered transcript"*. **Do not mistake the `withdrawn` vocabulary that already exists for this one**: `internal/redaction/taxonomy.go:83`–`:136` and `internal/api/api.go:73 ErrTermWithdrawn` withdraw TAXONOMY TERMS (feature 002), not answers]** Enforce redaction rule **R4** and [contracts/http-api.md](./contracts/http-api.md) §3.10 **A4** (FR-039): a citation resolving `redacted` invalidates the WHOLE answer as `declined{redacted_evidence}` ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.2 C4 — claims are never stripped to keep an answer presentable), and any **stored** answer whose citations intersect the redaction set is marked `withdrawn` and MUST NOT be served, with re-asking required. Redaction propagates to stored answers, not merely to the rendered transcript — **BLOCKER:** none but the work — the A4 half is done and tested; the stored-answer half is unbuilt and there is a live cache it does not cover · **OWNER:** **implementer** — unblocked today (FR-039, FR-022)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T075.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T075`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-040 — 001-workshop-curriculum-platform T076 — [US4] [TDD] [PARTIAL, AND THE MISREADING THIS NOTE PREVENTS MATTERS MORE THAN THE…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T076: [US4] [TDD] **[PARTIAL, AND THE MISREADING THIS NOTE PREVENTS MATTERS MORE THAN THE CLASSIFICATION. Measured 2026-09-03; NEW note.** `tasks.md`'s own T040 note calls `workshop/platform/gates/verify-redaction-propagation.sh` "G-PID-5". **The identifier `G-PID-5` occurs NOWHERE in `workshop/**` — not in a `*.sh`, `*.go`, `*.tsv` or `*.py` — only in `contracts/passage-contract.md:557`, `analysis.md:59` and this file.** That gate is real and green (rc **0**, A1–A10b; pair rc **0**, M1–M6) but it makes **one** of this task's four assertions. Measured by `grep 'redacted_omitted\|410\|stored_answer\|crossref'` over that gate: **0 hits for all four strings.** It asserts R1 (A10b, search cannot return it) and eight-target propagation (A5). It does **not** assert `resolve` → `redacted` with the API answering **410 Gone**; it does **not** assert crossrefs omitted with a non-zero `redacted_omitted` (R3); it does **not** assert a stored answer `withdrawn` (R4 — which T075 shows is unbuilt anyway). Its six mutations are M1 derived-term-index, M2 lookup key, M3 refusal-as-success, M4 unreadable registry, M5 report-without-artifact, M6 one-of-eight-targets: **none is this task's *"propagate only to the rendered transcript"*, and none demonstrates R1, R3 and R4 individually rather than as one aggregate**, which is the clause this task adds in bold. Pieces exist elsewhere and are worth reusing: 410 Gone is implemented at `internal/api/crossrefs.go:138`, `passages.go:30`, `graph_traverse.go:165`, `knowledge_reverse.go:117`, and `redacted_omitted` is asserted by Go tests at `internal/api/crossrefs_test.go:193`/`:241`/`:395`. **Do not mistake `verify-r3-rules.sh` (rc 0) for R3** — that is spec-002's extraction-reconciliation R3, a different rule with the same name. BLOCKED-ON-PREDECESSOR on T075 for the R4 leg; the R3 and 410 legs are writable today]** Prove **G-PID-5** end to end ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.3) — this is the earliest point at which all three propagation paths exist. Redact a cited passage, then assert: search cannot return it (R1, T059), `resolve` returns `redacted` and the API answers `410 Gone` ([contracts/http-api.md](./contracts/http-api.md) §3.8), cross-references to it are omitted with a non-zero `redacted_omitted` (R3, T061), and the stored answer citing it is `withdrawn` (R4, T075). **Paired mutation**: propagate the redaction only to the rendered transcript; the gate MUST go red, and MUST demonstrate R1, R3 and R4 individually rather than as a single aggregate failure — **BLOCKER:** **predecessor** — see the note; the identifier confusion it prevents matters more than the classification · **OWNER:** **implementer**, after its named predecessor (FR-039, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T076.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T076`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-042 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: SC-010 is measured NOT met (unanswerable fabrications); decide to accept the current answering-off state or fund the verifier/flag-surface work (spec 001 T078) WHY: the change lives in the private workshop submodule's own repository, needs a live-service run, install, push or an operator choice; this wave may not edit it UNBLOCK: - [1] keep answering OFF (current deployed state); cost: no answers, SC-010 stays unmet but no fabrication is served
- [2] build the --answerable/--unanswerable/--report flag surface and further fabrication reduction in workshop; cost: workshop commits, model runs, gitlink bump WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-043 — 001-workshop-curriculum-platform T079 — [US4] [TDD] [PATH CORRECTED 2026-09-02 — T078's harness is…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T079: [US4] [TDD] **[PATH CORRECTED 2026-09-02 — T078's harness is `workshop/platform/backend/gates/bench-answers.sh`, not `workshop/scripts/bench-answers.sh`. The ≥20-answer RUN exists: `questions.tsv` holds 24 `A` rows and the evidence header records `SC-009 met (24 answerable >= 20)` with `answered+cited 17  declined 7`. **The CERTIFICATION is what this task still owes** — the same evidence file states its own honest boundary that `answered+cited` is not `answered correctly`, and records that only 6 of the 17 were re-asked and read, with 1 defect found. SC-009 requires 100% over ≥20 answers, so it is unmet on certification, not on count. — **BLOCKER:** none but the work — the >=20-answer run exists · **OWNER:** **implementer** — unblocked today (SC-009, FR-021)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T079.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T079`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-044 — 001-workshop-curriculum-platform T080 — [US4] [TDD] [REVIEW] [PARTIAL — THE ALLOWLIST IS DONE AND MUTATION-PROVED; THE PART…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T080: [US4] [TDD] [REVIEW] **[PARTIAL — THE ALLOWLIST IS DONE AND MUTATION-PROVED; THE PART THAT UPGRADES *"WE OBSERVED NO EGRESS"* TO *"EGRESS WAS IMPOSSIBLE"* DOES NOT EXIST. Measured 2026-09-03; NEW note.** **DONE, and done the right way**: `pkg/answer/locality.go:62` uses `net.LookupIP` and `:83` `!ip.IsLoopback()` — resolution, not string matching — with the asymmetric contract stated at `:39`–`:48` and covered by `pkg/answer/provider_test.go:80`–`:95`. Its §1.1 paired mutation genuinely RUNS and is genuinely CAUGHT: `gates/prove-mutations.sh` row `M10-locality-by-substring  GREEN RED OK`, whose mutation body at `prove-mutations.sh:220`–`:221` replaces resolution with `strings.Contains(endpoint, "127.0.0.1")` — i.e. it seeds the exact defect this task names — plus `M16-standin-invents-locality-fault OK`. **MISSING — all four remaining elements, and the measurement is a single zero.** `grep -rn 'unshare|ip netns|tcpdump|tshark'` over the whole of `workshop/` (excluding `pipeline/venv`) returns **0 hits**: no egress-denied namespace, no packet capture. There is no `curl https://example.com` negative control — the only `example.com` strings in the tree are test fixtures at `provider_test.go:42`/`:76`/`:85`/`:107` and doc comments. `G-CLI-14` occurs **0 times** in the entire tree, so neither the gate nor its outside-the-namespace paired mutation exists. **What is enforced today is a config flag plus a DNS check, which is precisely what this task's own last sentence refuses to accept as a guarantee.** Building the namespace may need host privileges and is plausibly an operator step; the negative control and the capture assertion are not]** Enforce FR-024 privacy: resolved-address allowlist (`net.LookupIP` + `IsLoopback`, not string matching), egress-denied namespace with a NEGATIVE CONTROL (`curl https://example.com` from inside MUST fail), and packet capture asserting zero non-loopback packets. A config flag is not a guarantee. This is gate **G-CLI-14** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §5, D-LLM-4): the negative control and the capture both run across the full 20-answer and 10-refusal runs. **Paired mutation**: run the same assertions OUTSIDE the egress-denied namespace; the gate MUST go red — if it stays green the test proved nothing about the namespace, and *"we observed no egress"* was never upgraded to *"egress was impossible"* — **BLOCKER:** none but the work — the allowlist is done and mutation-proved; the part that upgrades "we observed no egress" to "egress was impossible" does not exist · **OWNER:** **implementer** — unblocked today (FR-024, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T080.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T080`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-070 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Land workshop gates G-HTTP-5 and G-CLI-13 (spec 001 T081) in the workshop repo, then bump the gitlink WHY: the change lives in the private workshop submodule's own repository (or needs a push/gitlink bump), which this wave may not edit UNBLOCK: - [1] implement both gates with paired mutations in workshop, commit there, bump gitlink; cost: workshop commit + umbrella gitlink change
- [2] defer with dated plan; cost: FR-025 stays unproven WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-045 — 001-workshop-curriculum-platform T083 — [US4] [PATH NOT BUILT — workshop/docs/answering.md does not exist. Part of the content…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T083: [US4] **[PATH NOT BUILT — `workshop/docs/answering.md` does not exist. Part of the content landed at OTHER paths and should be reused rather than rewritten: the `estimated_seconds: null` contract is documented at `workshop/docs/faq.md:215`–`:216` and `workshop/docs/quickstart.md:388`–`:389`, and the asynchronous-answering timing story is in `workshop/docs/limits.md` §1.4. The PAGE this task contracts still does not exist]** Document in `workshop/docs/answering.md` that answering is ASYNCHRONOUS — CPU-only generation is ~21 s (1.5B) to ~95 s (7B) idle, so "instant" is off by two orders of magnitude and no prompt engineering closes it. `estimated_seconds` MUST be `null` until measured — **BLOCKER:** none but the work — `docs/answering.md` is unwritten; part of the content already landed at other paths and should be reused, not rewritten · **OWNER:** **implementer** — unblocked today (FR-031, FR-030)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T083.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T083`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-046 — 001-workshop-curriculum-platform T084 — [US5] [TDD] [PATH NOT BUILT — workshop/scripts/add-chapter.sh does not exist and none…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T084: [US5] [TDD] **[PATH NOT BUILT — `workshop/scripts/add-chapter.sh` does not exist and none of the nine contracted stages exists as a driver. Four of the stages it must call are themselves `[PATH NOT BUILT]` (`transcribe.sh` T111, `index.sh` T115, `crossref.sh` T116, `redact.sh` T038/T039); two exist (`verify-accuracy.sh` T112, `ingest.sh` T113). **This task gates T085, T086, T090 and the enforcement half of T087**. **RE-MEASURED 2026-09-03: unchanged, and now the single largest blocker in this file.** `grep -rln 'add-chapter\|add_chapter'` over `workshop/scripts/` and `workshop/platform/` returns **ZERO files**; `G-CLI-7` and `G-CLI-8` (T085, T086) appear nowhere in `workshop/`. The stage census is unchanged: of the nine, `verify-accuracy` (T112) is built and `ingest` (T113) is built but missing five of its six contracted flags, while `transcribe` (T111), `index` (T115) and `crossref` (T116) do not exist and `redaction-review` (T039) is now built, proven and ticked. **This task alone accounts for FIVE unticked tasks that are blocked on nothing else** — T085, T086, T087's enforcement half, T088 and T090 — so it is the highest-leverage unwritten item in the file. Nothing blocks it but the work and the four missing stages]** Implement `workshop/scripts/add-chapter.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7 covering **all NINE contracted stages in order** — `preflight → extract → transcribe → verify-accuracy → ingest → index → crossref → redaction-review → publish` — with `--resume`, `--only <stage>`, `--skip <stage>`, `--from <stage>`, `--dry-run`, `--json` and `--check-idempotent`, and with no code edit required to add a chapter. **No stage is optional and none is silently dropped**: `preflight` (§3.1) classifies every finding as tooling (`2`) or content (`1`) and reports ALL of them rather than the first; `verify-accuracy` (§4.2) must actually run because the presence of its `accuracy.json` is publish precondition B2 — its value may miss target, its absence blocks; and `redaction-review` is the FR-039 gate implemented in T038/T039, which is what makes `publish` legal at all. An earlier draft of this task named only four stages (transcribe → ingest → index → cross-link); dropping the publication gate is precisely how a redaction requirement becomes decorative — **BLOCKER:** **predecessor T111 + T115 + T116 + T088** — four of the nine stages this driver must call are themselves unwritten · **OWNER:** **implementer**, after those four (FR-026, FR-028, FR-029, FR-039)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T084.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T084`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-072 — 001-workshop-curriculum-platform T085 — [US5] [TDD] Prove idempotency (FR-027) as gate G-CLI-7…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T085: [US5] [TDD] Prove idempotency (FR-027) as gate **G-CLI-7** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7, §5): run `add-chapter.sh` twice on a small synthetic chapter and assert all of **J1–J6** — a second run changes nothing and duplicates no passage, keyed on pid. **Paired mutation**: make the procedure mint unconditionally; the gate MUST go red — **BLOCKER:** **predecessor T084** — G-CLI-7 runs `add-chapter.sh` twice; there is no `add-chapter.sh` · **OWNER:** **implementer**, after T084 (FR-027, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T085.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T085`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-073 — 001-workshop-curriculum-platform T086 — [US5] [TDD] Incomplete materials MUST report precisely what is missing and MUST NOT…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T086: [US5] [TDD] Incomplete materials MUST report precisely what is missing and MUST NOT publish a partial chapter as complete (FR-028), proven as gate **G-CLI-8** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7, §5): remove `chapter.yaml` and two archive parts, then assert exit `1` with **three** findings enumerated — all of them, not just the first — and nothing published. **Paired mutation**: report the first finding only and publish anyway; the gate MUST go red — **BLOCKER:** **predecessor T084** · **OWNER:** **implementer**, after T084 (FR-028, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T086.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T086`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-074 — 001-workshop-curriculum-platform T087 — [US5] [TDD] Enforce the publish preconditions B1–B6 of…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T087: [US5] [TDD] Enforce the publish preconditions **B1–B6** of [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.7 in `add-chapter.sh`: B1 `coverage.unexplained_gap_s == 0` · B2 `accuracy.json` exists · B3 every passage has a pid in `passages.jsonl` · B4 the generation containing the chapter is `live` · B5 **`redaction-review.json` exists and is newer than the transcript (FR-039)** · B6 no source file changed during the run. Failing any one of them ⇒ exit `1` with the chapter left `transcribed`, never `published`. **Paired mutation**: publish with `redaction-review.json` absent (and again with it stale); the gate MUST go red in both cases — B5 is the only thing standing between FR-039 and a decorative requirement — **BLOCKER:** **predecessor T084** — B1-B6 are enforced IN `add-chapter.sh` · **OWNER:** **implementer**, after T084 (FR-039, FR-028, FR-004, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T087.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T087`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-047 — 001-workshop-curriculum-platform T088 — [US5] Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempotency and…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T088: [US5] Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempotency and identity can be proven without running ASR — otherwise every US5 proof inherits the ASR block. **[PATHS ADDED 2026-09-02 — this task named none, and two fixture producers already exist: `workshop/pipeline/extract/fixtures/synthetic_chapter/passages.jsonl` and `workshop/platform/backend/cmd/fixture-corpus/main.go`, which writes an invented corpus so endpoints can be exercised without private content. **Do not build a third fixture.** What is missing is a PROCEDURE that accepts one, and that procedure is T084, which is `[PATH NOT BUILT]`]** — **BLOCKER:** none but the work — a pre-supplied transcript fixture is what lets every US5 proof escape the ASR block, so this is the cheapest way to unblock T085-T087 · **OWNER:** **implementer** — unblocked today (FR-027, SC-016)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T088.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T088`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-075 — 001-workshop-curriculum-platform T090 — [US5] [TDD] Prove SC-011: a new chapter integrated in under 30 minutes hands-on with zero…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T090: [US5] [TDD] Prove SC-011: a new chapter integrated in under 30 minutes hands-on with zero code or config change — **BLOCKER:** **predecessor T084 + T088** — SC-011 times the procedure end to end · **OWNER:** **implementer**, after T084/T088 (SC-011, FR-026)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T090.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T090`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-053 — 001-workshop-curriculum-platform T095 — [P] [PARTIAL — A GREEN GATE GUARDS A DIFFERENT CRITERION. Measured 2026-09-03; NEW…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T095: [P] **[PARTIAL — A GREEN GATE GUARDS A DIFFERENT CRITERION. Measured 2026-09-03; NEW note, and this is the kind of finding a glance at an exit code would invert.** `workshop/docs/limits.md` EXISTS, 2,273 lines, 117 headings, and it has a paired gate that is genuinely green: `verify-limits-completeness.sh` → rc **0**, *"checked 15 registered defect(s) against docs/limits.md … all 15 are named"*, and `prove-limits-completeness.sh` → rc **0**, one anchor removed, `CAUGHT`, restored. **But that gate's own line 2 scopes it to `SC-026`, not FR-031** — it asserts that every row of the DEFECT REGISTRY is named in the page, which is a completeness claim about a different set. Measured against FR-031's own four named classes: `grep -c 'FR-031' docs/limits.md` = **0**; `SC-016a` = **0**; `operator-only` = **0**; lines pairing media with indexing = **0**; lines pairing code-passage identity with weak/weaker = **0**. Only **asynchronous answering** is covered (3 lines: `:195`, `:375`, `:1084`). So **three of the four classes this task names are undocumented, and no instrument would notice.** Note also that the SC-016a class cannot be honestly written until T015–T017 exist to be weaker *than something* — but the media-boundary and operator-only classes are writable today, and the media boundary is T067's page, which is also unwritten]** Document every limit honestly per FR-031: no direct media indexing, asynchronous answering, code-passage identity weaker than transcript identity (SC-016a, implemented by T015–T017 and proven by G-PID-4 in T017), and every operator-only step — **BLOCKER:** none but the work — `limits.md` exists with a paired proof, but the green gate guards a DIFFERENT criterion than the one this task names · **OWNER:** **implementer** — unblocked today (FR-031, SC-016a)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T095.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T095`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-054 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Attribute and register the remaining feature-001 gates in workshop check-registry-001.tsv (spec 001 T096), incl. cross-registry-attribution WHY: the change lives in the private workshop submodule's own repository, needs a live-service run, install, push or an operator choice; this wave may not edit it UNBLOCK: - [1] per-file attribution of ~48 gate scripts in workshop, commit, bump gitlink; cost: workshop commit + reviewer time
- [2] keep the DEBT rows; cost: --strict stays rc 1 WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-055 — 001-workshop-curriculum-platform T097 — [TDD] Verify EVERY feature check has a paired mutation proof including a real-entry-point…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T097: [TDD] Verify EVERY feature check has a paired mutation proof including a real-entry-point case (SC-012) — **[PARTIAL. Measured 2026-09-03; NEW note. The PAIRING is complete where it is measured and the REAL-ENTRY-POINT case genuinely exists; what is missing is the QUANTIFIER.** `workshop/platform/gates/` holds **17** `verify-*.sh` and **19** `prove-*.sh` with **0 unpaired** by sibling name. Real-entry-point proofs were OBSERVED running, not just declared: `workshop/scripts/verify.sh:613` — `PROVE: PASS — E2E real verify.sh over a mutated tree -> rc 1 with a FAIL row` — and `bash scripts/verify-governance-cascade.sh --prove-failure` → rc 0 with *"the REAL entry point ran against the REAL tree"*. **But SC-012 says EVERY, and "every" is quantified over an enumeration that covers 19 `pipeline/` files and no others** (T096's `--strict` rc 1). Worse for this task specifically: `verify.sh --prove-failure` proves only verify.sh's OWN V1–V7 gates and **never executes the 19 sibling `prove-*.sh` scripts** — its single `prove-*.sh` reference is a synthetic fixture at `verify.sh:608`. So the proofs exist, are paired, and are not run by the thing that claims to run everything. This closes when T096's registry covers `platform/gates/` and `platform/backend/gates/`; it is BLOCKED-ON-PREDECESSOR on T096]** — **BLOCKER:** **predecessor T096** — SC-012 says EVERY, and "every" cannot be quantified over a set nobody enumerates · **OWNER:** **implementer**, after T096 (SC-012, FR-032)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T097.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T097`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-056 — 001-workshop-curriculum-platform T098 — [TDD] Verify EVERY feature check distinguishes could-not-determine from pass and fail…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T098: [TDD] Verify EVERY feature check distinguishes could-not-determine from pass and fail (SC-013) — **[PARTIAL, WITH THE SAME QUANTIFIER GAP AS T097 AND ONE EXTRA FINDING. Measured 2026-09-03; NEW note.** Structural census: **17 of 17** `workshop/platform/gates/verify-*.sh` and **10 of 10** `workshop/platform/backend/gates/*.sh` carry rc-2 vocabulary. It is DEMONSTRATED and not merely declared: registry-001's `--prove-failure` includes `M18 a sweep matching ZERO files is UNDETERMINED rc 2` (PASS), and a live `verify.sh` run produced a genuine `COULD-NOT-RUN` row for `G8 verify-entailment-loads.sh` rather than a FAIL. **The gap is the same one T096 and T097 name: 48 files sit outside any registry, and "100% of its checks" cannot be asserted over a set nobody enumerates.** One extra finding, recorded rather than resolved: `workshop/scripts/verify.sh:747`–`:752` documents IN ITS OWN SOURCE an unresolved divergence about whether a STOPPED stack is exit 0 or exit 1 — measured against `contracts/pipeline-cli.md` §4.8 and against T021's now-green G-CLI-17, which asserts **1**. A three-valued census is worth less while two instruments disagree about which value is right. BLOCKED-ON-PREDECESSOR on T096]** — **BLOCKER:** **predecessor T096** — same quantifier gap, plus an unresolved divergence about whether a STOPPED stack is exit 0 or 1 · **OWNER:** **implementer**, after T096; the exit-code divergence is an **operator** call (SC-013, FR-033)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T098.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T098`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-057 — 001-workshop-curriculum-platform T099 — Write machine evidence to workshop/evidence/ retained with the commit that produced it…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T099: Write machine evidence to `workshop/evidence/` retained with the commit that produced it (FR-040) — **[PATH SPLIT 2026-09-02 — `workshop/evidence/` EXISTS but holds only **3** tracked files (`phase2-passage-identity/README.md`, `phase2b-mentions/README.md`, `phase2b-mentions/T014-unjoined-words-u5.md` — and that last one is FEATURE 002's T014, not this file's). The machine evidence FR-040 asks for landed at `workshop/platform/backend/evidence/`: **21** tracked files, committed and clean. `workshop/platform/qa/evidence/` exists on disk with **0** tracked files, and `workshop/evidence/knowledge-pipeline/` carries untracked run output. **The substance largely exists; its contracted LOCATION does not**, so this task is a move-or-mirror decision plus the retention rule, not a from-zero build. **RE-MEASURED 2026-09-03 — the shape holds, both counts moved, and a RETENTION BREACH is now visible.** ~~3 tracked files~~ → `git -C workshop ls-files evidence | wc -l` = **6** (`chunking/README.md`, `p-u1/README.md`, `p-u1/result.json`, `phase2-passage-identity/README.md`, `phase2b-mentions/README.md`, and `phase2b-mentions/T014-unjoined-words-u5.md`, which remains **002's** T014, not this file's). ~~21~~ → `git -C workshop ls-files platform/backend/evidence | wc -l` = **22**. `workshop/platform/qa/evidence/` holds **6** subdirectories on disk (`answering`, `challenges`, `helixqa`, `prove`, `prove-state2`, `state2`) with **0 tracked AND 0 untracked-not-ignored** — it is entirely git-ignored, so none of it is retained with any commit at all. **The retention half of FR-040 is measurably breached right now, not hypothetically**: `evidence/p-u1/result.json` is ` M` in the working tree, so the bytes on disk are not the bytes any commit carries — and those bytes are T014's P-U1 settlement evidence. Nothing in the tree gates FR-040 retention]** — **BLOCKER:** **operator decision** — the substance largely exists but at a DIFFERENT path than FR-040 contracts, so this is a move-or-mirror decision plus a retention rule, not a from-zero build. A retention breach is live right now · **OWNER:** **operator** decides move-vs-mirror; **implementer** executes (FR-040, SC-018)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T099.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T099`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-060 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Commit and push umbrella and every submodule to all upstreams, verify with git ls-remote (spec 001 T104); 7 of 13 REDACT decisions are deferred by operator decision WHY: the change lives in the private workshop submodule's own repository, or is a push/publication; this wave may not edit it or push UNBLOCK: - [1] apply or decide the 7 deferred redactions, then push via the commit wrapper and verify with ls-remote; cost: publication is irreversible
- [2] hold the push; cost: upstreams stay behind WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-078 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Final review against spec 001 (T105) by a human reviewer after predecessor tasks close WHY: the change lives in the private workshop submodule's own repository (or needs a push/gitlink bump), which this wave may not edit UNBLOCK: - [1] run final review once the remaining spec-001 tasks close; cost: reviewer time, blocked on ~50 open tasks
- [2] review the drafted review.md half now; cost: FR half (5 of 48 cited) stays untraced WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-061 — 001-workshop-curriculum-platform T106 — [TDD] [PATH CORRECT, FILE PARTIAL — measured 2026-09-02, workshop/scripts/_common.sh…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T106: [TDD] **[PATH CORRECT, FILE PARTIAL — measured 2026-09-02, `workshop/scripts/_common.sh` EXISTS at 273 lines but is the CONTAINER CONTROL-PLANE helper, not the §2.1 contract. Present: the three-valued exit constants, `undetermined()`/`problem()`, derived-never-hardcoded paths, `set -euo pipefail`. Absent: the §2.2 four-rung resolution order over every `WORKSHOP_*` var, the §2.4 `(size, mtime, inode)` fingerprint helpers, the §2.9 self-hash re-check, and the §1.4 `ERR`/`EXIT` traps — `grep -c '^\s*trap '` returns **0**. **Extend that file; do not write a second one**]** Implement the shared wrapper library `workshop/scripts/_common.sh` contracted in [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §2.1 — sourced, never executed. It owns the §2.2 resolution order **environment → config file → live probe → documented fallback**, identical for every `WORKSHOP_*` variable and copied from `scripts/lumen-reindex.sh` so an operator learns one pattern rather than two, printing at `-v` the host facts it measured and the arithmetic it performed; the §2.4 source-fingerprint helpers that record `(size, mtime, inode)` for every source before a run and re-check them after; the §2.9 self-hash re-check that aborts with `2` and `reason.code: "script_modified_while_running"` when a long-running script is edited mid-flight; and the §1.4 `ERR` and `EXIT` traps. Gate **G-CLI-10** (§1.4, §5): assert every *unclassified* non-zero status maps to `2` — `126`, `127`, `128+N` and any other unclassified non-zero — that only statuses set by a command's own classification logic may be `0` or `1`, and that `3`–`125` stay reserved and unused. **Paired mutation**: remove the `ERR` trap; the gate MUST go red, because a missing binary then surfaces as `127` and a tool that was never there reads as a real problem found — **BLOCKER:** none but the work. **RE-MEASURED 2026-09-04: the LIBRARY half landed this session and the GATE half did not.** `workshop/scripts/_common.sh` gained 983 lines / 39 `ws_*` functions, purely additive (0 deletions): the §2.2 four-rung resolver `ws_resolve` with `-v` host-fact reporting, the §2.4 `(size, mtime, inode)` fingerprint helpers (inode via POSIX `ls -i`, not `stat`, per `_portable.sh`'s recorded GNU-vs-BSD trap), the §2.9 self-hash re-check aborting 2 with `reason.code: script_modified_while_running`, and the §1.4 traps — `grep -c '^\s*trap '` moved **0 -> 4**. The §1.4 mapping was DRIVEN: a fixture calling a missing binary produced `UNDETERMINED: unclassified failure — exit status 127` and rc **2**. Regression-checked in both directions: `bash -n` passes on all nine control-plane scripts and `redact.sh`/`start.sh`/`stop.sh`/`ingest.sh`/`verify.sh` `--help` output is BYTE-IDENTICAL before and after; `status.sh` still returns `RUNNING`, rc 0. **What is NOT done: gate `G-CLI-10` and its paired mutation were never written** — design settled, no file exists · **OWNER:** **implementer** — unblocked today; only the gate remains (FR-033, SC-013, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T106.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T106`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-062 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Finish the section 2.5 evidence writer across pipeline wrappers (spec 001 T107) in the workshop repo WHY: the change lives in the private workshop submodule's own repository, or is a push/publication; this wave may not edit it or push UNBLOCK: - [1] extend redact.sh-style writer (manifest.json, E1/E2/E4) to the remaining wrappers in workshop, commit, bump gitlink; cost: workshop commit + gitlink bump
- [2] keep redact.sh as the only writer; cost: other wrappers stay without evidence WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-066 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Build workshop/scripts/transcribe.sh and gate G-CLI-2 (spec 001 T111) over unbuilt checkpoint/resume module T028 WHY: the change lives in the private workshop submodule's own repository, or is a push/publication; this wave may not edit it or push UNBLOCK: - [1] implement T028 then the wrapper and gate in workshop, commit, bump gitlink; cost: workshop commits + long ASR runs
- [2] defer; cost: wrapper surface stays unbuilt WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-079 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Implement workshop/scripts/ingest.sh flag surface and gate G-PID-6 (spec 001 T113) in the workshop repo, then bump gitlink WHY: the change lives in the private workshop submodule's own repository (or needs a push/gitlink bump), which this wave may not edit UNBLOCK: - [1] implement the five missing flags + G-PID-6 with R5 mutation in workshop; cost: workshop commit + gitlink bump
- [2] amend the contract to the two existing flags; cost: operator decision to narrow pipeline-cli.md section 4.3 WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-068 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Build gate G-CLI-15 containers-actually-booted anti-bluff (spec 001 T114) in the workshop repo; needs a container start WHY: the change lives in the private workshop submodule's own repository, or is a push/publication; this wave may not edit it or push UNBLOCK: - [1] implement the gate with paired stub-boot mutation in workshop, commit, bump gitlink; running it starts workshop containers; cost: workshop commit + live container run
- [2] defer; cost: green control plane does not yet imply infra up WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-069 — 001-workshop-curriculum-platform T115 — [US3] [TDD] [PATH NOT BUILT — workshop/scripts/index.sh does not exist and no…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T115: [US3] [TDD] **[PATH NOT BUILT — `workshop/scripts/index.sh` does not exist and no equivalent landed anywhere]** Implement the `workshop/scripts/index.sh` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.4 over T058's generations — `--chapter`, `--lexical-only` (the honest escape hatch when the embedding backend is saturated), `--semantic-only`, `--verify-only`, `--swap`/`--no-swap`, and `--timeout-ms 5000` per call, because an unbounded query is how a 10-minute stall happens. It MUST reserve embedding capacity for interactive queries, which is a hard requirement rather than a nicety: `scripts/ollama-tune.sh` records that with `OLLAMA_NUM_PARALLEL` resolving to 1 a single embed went from 0.74 s to a >90 s client timeout, stalling indexing entirely — *"queue depth is not the defect — serialisation is"* — and without reservation SC-006 fails on every chapter ingest, precisely when people are using the system. Gate **G-CLI-6** (§4.4, §5): point the embedding endpoint at a closed port and assert exit `2` with `reason.code: "embedding_backend_exhausted"` **and** that the previously live generation is still live and serving. **Paired mutation**: map backend failure to exit `1`; the gate MUST go red. The line that must not be blurred: `all embedding servers exhausted` is `2`, never `1` — reporting `1` there makes a broken backend accuse a healthy curriculum — **BLOCKER:** none but the work — `index.sh` is unwritten · **OWNER:** **implementer** — unblocked today (SC-006, FR-020, FR-033, SC-013, FR-032, SC-012)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T115.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T115`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-070 — 001-workshop-curriculum-platform T116 — [US3] [PATH NOT BUILT — workshop/scripts/crossref.sh does not exist. The derivation it…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T116: [US3] **[PATH NOT BUILT — `workshop/scripts/crossref.sh` does not exist. The derivation it wraps DOES exist at `workshop/platform/backend/pkg/crossref/` (T060, ticked); the CLI over it does not, and no `--rebuild-derived`/`--check-cycles` surface exists anywhere]** Implement the `workshop/scripts/crossref.sh` wrapper per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.5 over T060's derivation — `--chapter`, `--min-score`, `--max-per-passage 20`, `--rebuild-derived`, `--check-cycles`. It rebuilds `origin: "derived"` edges for the target generation and **never touches `authored` edges**, which are content rather than derivation ([contracts/passage-contract.md](./contracts/passage-contract.md) §7.4 X4); self-references are rejected and traversal is cycle-checked. Exit `1` on a cycle among `authored` edges (a content defect a human introduced), an edge whose endpoint is not in the registry, or a self-reference in authored content; exit `2` when the embedding backend is unavailable for similarity scoring, the registry is unreadable, or the run was interrupted — an unscoreable backend is not a finding about the content — **BLOCKER:** none but the work — the derivation it wraps EXISTS (T060); the CLI over it does not · **OWNER:** **implementer** — unblocked today (FR-018, FR-033, SC-013)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T116.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T116`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-072 — 001-workshop-curriculum-platform T119 — [TDD] [UNWRITTEN — NOTHING BLOCKS IT. Measured 2026-09-03; NEW note. Searching for…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T119: [TDD] **[UNWRITTEN — NOTHING BLOCKS IT. Measured 2026-09-03; NEW note.** Searching for `G-CLI-1` with `G-CLI-1[0-9]` excluded, the identifier occurs **exactly once** anywhere under `workshop/` — `platform/backend/cmd/workshop-redact/main.go:55`, a **code comment**, not a gate. The full inventory of gate identifiers actually present under `workshop/` is `G-CLI-{1,3,5,11,13,16,17}`, `G-HTTP-{1..8,8c}` and `G-PID-4`; **nothing asserts state/exit agreement across every command, and nothing asserts the `--json` contract at all** — there is no test that stdout carries exactly one JSON object with all human text on stderr, and no `state: "ok"` hardcode mutation. Two facts make this cheaper than it looks and both were measured: `redact.sh` already writes a per-run result file (see T107), and `verify.sh` already discovers gates at run time. Two facts make it harder: that file is named `result-exit.json` and carries `{run_id, exit, at}` with **no `state` field** to compare the exit against (T107), and this task quantifies over *"every command in the control plane and the pipeline"*, several of which do not exist yet (T111, T115, T116, T084). Sequencing it last, as this phase does, is correct]** Prove gate **G-CLI-1** ([contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §1.6, §5) across **every** command in the control plane and the pipeline: `result.json.state` and the process exit status agree over all three outcomes — `"ok"`/`0`, `"problem_found"`/`1`, `"could_not_determine"`/`2` — and under `--json` stdout carries exactly one JSON object and nothing else, with all human text on stderr. **Paired mutation**: hardcode `state: "ok"` in one command's result writer; the gate MUST go red. It sits in this phase because it asserts over every command and cannot run until they all exist — **BLOCKER:** none but the work. Re-measured 2026-09-04: NOT STARTED — `grep -rn 'G-CLI-1'` under `workshop/` still returns only the one code comment at `platform/backend/cmd/workshop-redact/main.go:55`. It is now CHEAPER than it was: T107 landed `result.json` with a `state` field derived from a single exit-to-state mapping, which is the artifact G-CLI-1 must compare against the process exit · **OWNER:** **implementer** — unblocked today (FR-033, SC-013, FR-032, SC-012, FR-040)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T119.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T119`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-073 — 001-workshop-curriculum-platform T120 — [TDD] [REVIEW] [PARTIAL — BUILT, RUNNING, AND ITS HARDEST CLAUSE IS THE ONE THAT HOLDS.…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 001-workshop-curriculum-platform task T120: [TDD] [REVIEW] **[PARTIAL — BUILT, RUNNING, AND ITS HARDEST CLAUSE IS THE ONE THAT HOLDS. Measured 2026-09-03; NEW note, replacing the File Structure table's implicit reading that this is unbuilt.** `workshop/scripts/verify.sh` EXISTS, **812 lines**, and a live run exits **1** printing `PASS 24  FAIL 1  COULD-NOT-RUN 1  of 26   [scope: all]`, naming `FAIL: G12 verify-retrieval-benchmark.sh` and `COULD-NOT-RUN: G8 verify-entailment-loads.sh` separately, then `RESULT 1  a gate RAN and reported a violation (1 could not run and are listed above)`. **That is the precedence rule this task calls "the single most error-prone line in the contract", observed working on a real mixed outcome** — 1 FAIL beside 1 COULD-NOT-RUN aggregating to **1**, both counted, in the exact `PASS n FAIL n COULD-NOT-RUN n of N` vocabulary the task specifies (implementation `:795`–`:812`). `--prove-failure` → rc **0** with **26** `PROVE:` lines, all PASS, including `E2E real verify.sh over a mutated tree -> rc 1 with a FAIL row`, `precedence: 1 FAIL + 1 COULD-NOT-RUN aggregates to rc 1, both counted`, `a SKIP is never a PASS: all-green + 1 unrunnable -> rc 2`, and `V7b pairing: NO gates at all is 2, not 0` — both forbidden collapses proved in both directions. `--help` → rc 0. **TWO CLAUSES ARE UNMET AND BOTH ARE MEASURED.** (1) *"runs every gate in this contract set (all `G-CLI-*`, `G-HTTP-*` and `G-PID-*`)"* — it does not. It discovers `platform/gates/verify-*.sh` **by filename** and references only **2** of the 17 contract identifiers present in the tree (`G-CLI-11`, `G-CLI-16`); discovery answers *"what is on disk"*, never *"what the contract requires and is missing"*, and two of the required gates do not exist at all (T119's G-CLI-1, T114's G-CLI-15). (2) *"a gate whose mutation does not turn it red is reported **vacuous** and counted as **FAIL**"* — `grep -c vacuous workshop/scripts/verify.sh` = **0**; `--prove-failure` proves verify.sh's own V1–V7 and **never executes the 19 sibling `prove-*.sh` scripts**, so no mutation of a real gate is ever judged vacuous. This is also correctly sequenced last: it cannot be finished before the gates it must aggregate exist]** Implement `workshop/scripts/verify.sh` per [contracts/pipeline-cli.md](./contracts/pipeline-cli.md) §4.9 — the aggregation point that runs every gate in this contract set (all `G-CLI-*`, `G-HTTP-*` and `G-PID-*`) and aggregates them. **Sequenced last, after every gate task in every phase**, because it aggregates those gates and cannot be written before them. Three-valued: `0` every gate ran and passed · `1` at least one gate **ran** and reported a violation · `2` at least one gate **could not run** and **no** gate reported a violation. **The precedence rule is the single most error-prone line in the contract, and both directions of collapsing it are forbidden here by name**: when some gates failed (`1`) and others could not run (`2`), the aggregate is **`1`** — a confirmed violation outranks an unknown — and the summary reports the two counts separately in the repository's existing sweep vocabulary (`PASS n  FAIL n  COULD-NOT-RUN n  of N`, then each could-not-run gate named with its reason). A `verify.sh` that collapses `2` into FAIL is the specific defect to forbid: this project has shipped **seven** separate pass/fail/could-not-determine conflations, so a broken instrument must never be reported as a violated tree. The mirror defect is equally forbidden — it must never report `0` while any gate was skipped. `PREPUSH_STRICT=1` semantics apply: a SKIP is never a PASS. `verify.sh --prove-failure` runs every registered paired mutation and asserts its gate turns red; a gate whose mutation does not turn it red is reported **vacuous** and counted as **FAIL**, and at least one proof case MUST run the real entry point end to end rather than a sandboxed copy, because a proof that exercises only sandboxed copies can go green over an instrument that cannot start at all. Per §2.7 **N2** this script — a script, never a workflow — is what the umbrella's local pre-push hook calls (FR-032, FR-033, FR-040, SC-012, SC-013, SC-018) — **BLOCKER:** none but the work — `verify.sh` exists at 812 lines, is running, and its hardest clause holds; the remainder is unbuilt · **OWNER:** **implementer** — unblocked today (FR-032, FR-033, FR-040, SC-012, SC-013, SC-018)

HOW IT MANIFESTS — the task is tracked in specs/001-workshop-curriculum-platform/tasks.md as row T120.

HOW TO REPRODUCE — read specs/001-workshop-curriculum-platform/tasks.md and locate the row beginning `T120`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-097 — 002-knowledge-areas-deep-linking T022 — [REVIEW] Review the knowledge contract implementation before anything consumes it — —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T022: [REVIEW] Review the knowledge contract implementation before anything consumes it — — **BLOCKER:** none but the work — no `phase2e-report.md` exists, and `specs/002/` has NEITHER an `analysis.md` NOR a `review.md` (spec 001 has both). This is review-record authorship, and it is one of the two things holding T122 · **OWNER:** **implementer/reviewer** — unblocked today

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T022.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T022`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-104 — 002-knowledge-areas-deep-linking T031 — [US1] [BLOCKED: prose authorship] [REVIEW] Author area materials in the seven-section —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T031: [US1] [BLOCKED: prose authorship] [REVIEW] Author area materials in the **seven-section — **BLOCKER:** **operator decision** — the prose-authorship clarification is undecided (extractive vs build-time vs run-time). 5 documents are authored with 7 `## ` sections each and 489 areas serve; the earlier "host capability" excuse is WITHDRAWN. This is irreducible authorship, not engineering · **OWNER:** **operator**, then **human prose authorship**

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T031.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T031`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] and annotates it [BLOCKED: prose authorship]. Recorded as Queued rather than Operator-blocked because §11.4.21 + §11.4.148(D3) require a WHY, an exhausted-alternatives statement and an enumerated set of unblock CHOICES, and the source row supplies none of the three. Inventing them to reach the stronger status would be the fabrication §11.4.6 forbids.

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-106 — 002-knowledge-areas-deep-linking T033 — [US1] [TDD] Implement claim citation enforcement (contract W2): every substantive claim…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T033: [US1] [TDD] Implement claim citation enforcement (contract W2): every substantive claim — **BLOCKER:** **predecessor T031** — 224 of 532 claim blocks across all 5 documents are uncited or cite a non-resolving pid (48 are exempt Sources entries); W3 is reviewed for 2 of 5. Enforcement cannot land before the prose it enforces is settled · **OWNER:** **implementer**, after T031

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T033.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T033`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-111 — 002-knowledge-areas-deep-linking T038 — [US1] [TDD] Implement GET /api/areas/{area} per §3.2, and GET /api/terms and —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T038: [US1] [TDD] Implement `GET /api/areas/{area}` per §3.2, and `GET /api/terms` and — **BLOCKER:** none but the work, but the fix is in the PIPELINE not the handler — `taxonomy.py` persists only the final score and never the significance inputs; the handler is already correct and honestly reports `inputs_available:false` with `score_determined:true` over 8,507 served terms · **OWNER:** **implementer** — unblocked today

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T038.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T038`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-115 — 002-knowledge-areas-deep-linking T042 — [US1] [REVIEW] Record the content boundary check in both directions before anything is…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T042: [US1] [REVIEW] Record the content boundary check **in both directions** before anything is — **BLOCKER:** none but the work — the SC-029a INBOUND half is unbuilt and the `sc029a-not-built` row is live; §10.14 records that the naive probe was rejected, so this needs a long-shingle design rather than a quick check · **OWNER:** **implementer** — unblocked today, design work required

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T042.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T042`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-123 — 002-knowledge-areas-deep-linking T050 — [US2] [TDD] Implement the six-row connectivity matrix (FR-033a) and its exercise harness.…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T050: [US2] [TDD] Implement the six-row connectivity matrix (FR-033a) and its exercise harness. — **BLOCKER:** none but the work — the gate exits 0, but `rows_implemented` (`graph_traverse.go:200`) still EXCLUDES row 4's cross-reference-graph half, so a green gate is covering five of six rows · **OWNER:** **implementer** — unblocked today, one missing half-row

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T050.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T050`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-125 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Fix workshop gate for SC-009 (spec 002 T052): handle HTTP 410 on redacted passages and add its paired mutation, in the workshop repo WHY: the change lives in the private workshop submodule's own repository (or needs a push/gitlink bump), which this wave may not edit UNBLOCK: - [1] add the 410 branch + mutation in workshop, commit there, bump gitlink; cost: workshop commit + gitlink bump
- [2] leave the gate rc 2; cost: SC-009 stays unproven WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-140 — 002-knowledge-areas-deep-linking T067 — [US3] [TDD] Prove SC-015: the gate prints per-query outcomes, not only the — BLOCKER:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T067: [US3] [TDD] Prove **SC-015**: the gate prints **per-query** outcomes, not only the — **BLOCKER:** **retrieval quality, and nobody's decision** — the instrument is built and correct; SC-015 is MEASURED NOT MET at top-5 12/22 (54.5%), top-1 3/22, against a bar of 20/22. The `term` leg is the shortfall · **OWNER:** **implementer** — unblocked, but it is a quality problem, not a wiring problem

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T067.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T067`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-141 — 002-knowledge-areas-deep-linking T068 — [US3] [TDD] Prove SC-016 / SC-017: re-run the latency harness and publish before and —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T068: [US3] [TDD] Prove **SC-016 / SC-017**: re-run the latency harness and **publish before and — **BLOCKER:** **NOT "just a quiet host" — that remedy is now IN DOUBT, and this is the correction that matters.** Re-run 2026-09-04: rc **2**, `PASS 0 FAIL 0 UNDET 7`. The gate read the index block cleanly (generation 68, 12,979 passages, live) and then **every** endpoint refused — including the `health CONTROL`, which by the harness's own design makes the fused figure uninterpretable. Immediately afterwards `podman ps` showed `workshop-curriculum_platform_1  Up 46 seconds (starting)` and `/api/health` returned `HTTP=000`: **the container went down underneath a read-only run.** `tasks.md` already records the same sequence on 2026-09-03, so counting this it has happened **three times across two dates, every time during or immediately after `verify-search-latency.sh`**. Host load was FALLING across this run (17.5 -> 9.7), which weakens the load-average explanation the old note leans on. No causal claim is made — co-occurrence is not causation and this was not isolated — but the narrow, checkable claim is: the stated remedy *"one clean re-run, not new code"* has now failed three times identically, so treating this as bad luck risks a fourth identical result · **OWNER:** **implementer first** — find why the container dies under this harness's concurrent request pattern; that outranks the latency figure. **operator** second, for a quiet host, once the stability question is settled

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T068.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T068`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-155 — 002-knowledge-areas-deep-linking T084 — [US4] [REVIEW] Review question provenance end to end before the practice surface consumes…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T084: [US4] [REVIEW] Review question provenance end to end before the practice surface consumes — **BLOCKER:** none but the work — the only review record is `phase6-report.md` (unchanged since 2026-09-02 12:54) and it merely mentions T084; no later record exists. Pure review-record authorship, and the second of the two things holding T122 · **OWNER:** **implementer/reviewer** — unblocked today

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T084.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T084`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-171 — 002-knowledge-areas-deep-linking T101 — [US6] Port diagram rendering from text source — reproducible, unlike an embedded binary…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T101: [US6] Port diagram rendering from text source — reproducible, unlike an embedded binary — **BLOCKER:** **operator decision** — `mmdc -V` exits 0 but an actual 2-node render exits **1 with no SVG**, `grep -c mermaid` is **0** across all 5 area documents, and there is no decision on where a diagram lives in the seven-section skeleton · **OWNER:** **operator** (content/contract placement), then **implementer**

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T101.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T101`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-179 — 002-knowledge-areas-deep-linking T109 — [US7] [TDD] Prove G-KG-17 / SC-015c: run the whole pipeline against the synthetic —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T109: [US7] [TDD] Prove **G-KG-17 / SC-015c**: run the whole pipeline against the synthetic — **BLOCKER:** none but the work — `prove_g_kg_17_synthetic_chapter` self-scopes in its own docstring ("SCOPED HONESTLY") to extracted areas/themes plus taxonomy, while T109 asks for EVERY S2 output · **OWNER:** **implementer** — unblocked today

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T109.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T109`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-189 — 002-knowledge-areas-deep-linking T119 — [TDD] Prove SC-028: drive every new check into a could-not-determine condition and —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T119: [TDD] Prove **SC-028**: drive every new check into a could-not-determine condition and — **BLOCKER:** none but the work — SC-028 coverage reaches only 3 Phase-10 checks; the 18 G-KG gates have never been driven to state 2, and the registry population has since grown to 70 checks · **OWNER:** **implementer** — unblocked today

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T119.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T119`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-192 — 002-knowledge-areas-deep-linking T122 — [REVIEW] Final content-boundary check in both directions (SC-029, SC-029a), plus the —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T122: [REVIEW] Final content-boundary check **in both directions** (SC-029, SC-029a), plus the — **BLOCKER:** **predecessor T042 (SC-029a inbound), plus T022 and T084 as a final review** — 2 of its 3 halves are already green: zero workflow files, and `CONTINUATION.md` carries 19 spec-002 references · **OWNER:** **implementer**, last; needs T042/T022/T084 first

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T122.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T122`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-193 — 002-knowledge-areas-deep-linking T123 — [UNBUILT] [P] Gate G-OCR-1 — capability-probe the OCR toolchain per contract §7 V1:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T123: [UNBUILT] [P] Gate **G-OCR-1** — capability-probe the OCR toolchain per contract §7 **V1**: — **BLOCKER:** **half BUILT, half blocked on CAPABILITY not on a decision** — the `[UNBUILT]` marker is STALE: `pipeline/detect_ocr.sh` EXISTS (754 lines), is registered as `ocr-toolchain-capability` with a paired proof, and its rc-2 probe is verified live (`--scratch-dir /nonexistent` -> rc 2). What is NOT buildable is per-chapter language detection: tesseract OSD misclassified an all-caps Latin fixture as Cyrillic at the HIGHEST confidence of three fixtures, so a confidence floor selects FOR the error. Resolving it needs a bake-off against T132's hand-truthed sample · **OWNER:** **implementer** for the built half; **blocked on T132** for the language half

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T123.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T123`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-194 — 002-knowledge-areas-deep-linking T124 — [UNBUILT] [REVIEW] Settle U6 — what sampling period keeps an on-screen visibility —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T124: [UNBUILT] [REVIEW] Settle **U6** — what sampling period keeps an on-screen visibility — **BLOCKER:** **operator decision, purely** — every input is already recorded (segment median 6.74 s, p95 10.78 s, max 20.22 s) and frame sampling is measured working. What is missing is the operator CHOOSING a sampling period, which the task forbids rounding to a convenient number · **OWNER:** **operator** — unblocks T126/T127/T128

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T124.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T124`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-196 — 002-knowledge-areas-deep-linking T126 — [UNBUILT] [TDD] Implement sampling and recognition across a chapter recording, producing…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T126: [UNBUILT] [TDD] Implement sampling and recognition across a chapter recording, producing — **BLOCKER:** **predecessor T124** — sampling cannot be implemented before the sampling period is chosen · **OWNER:** **implementer**, after T124

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T126.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T126`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-197 — 002-knowledge-areas-deep-linking T127 — [UNBUILT] [TDD] Gate G-OCR-3 — implement the stability rule: text visible across —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T127: [UNBUILT] [TDD] Gate **G-OCR-3** — implement the **stability rule**: text visible across — **BLOCKER:** **predecessor T124 + T126** · **OWNER:** **implementer**, after T124/T126

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T127.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T127`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-198 — 002-knowledge-areas-deep-linking T128 — [UNBUILT] [TDD] Gate G-OCR-4 — join screen_text mentions to the existing — BLOCKER:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T128: [UNBUILT] [TDD] Gate **G-OCR-4** — join `screen_text` mentions to the **existing — **BLOCKER:** **predecessor T124 + T126** · **OWNER:** **implementer**, after T124/T126

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T128.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T128`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-199 — 002-knowledge-areas-deep-linking T129 — [UNBUILT] [TDD] Gate G-OCR-5 — record modality (spoken / on_screen) on every —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T129: [UNBUILT] [TDD] Gate **G-OCR-5** — record **modality** (`spoken` / `on_screen`) on every — **BLOCKER:** **predecessor T126** — modality cannot be recorded on mentions that do not exist yet · **OWNER:** **implementer**, after T126

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T129.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T129`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-200 — 002-knowledge-areas-deep-linking T130 — [UNBUILT] [REVIEW] Settle U7 — the corroboration window. A term is commonly —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T130: [UNBUILT] [REVIEW] Settle **U7** — the **corroboration window**. A term is commonly — **BLOCKER:** **operator decision** — the corroboration window (U7) is an unsettled parameter, same class as T124 · **OWNER:** **operator**

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T130.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T130`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-201 — 002-knowledge-areas-deep-linking T131 — [UNBUILT] [TDD] Gate G-OCR-6 — implement corroboration grouping per — BLOCKER:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T131: [UNBUILT] [TDD] Gate **G-OCR-6** — implement **corroboration grouping** per — **BLOCKER:** **predecessor T130** · **OWNER:** **implementer**, after T130

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T131.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T131`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-202 — 002-knowledge-areas-deep-linking T132 — [UNBUILT] [TDD] Build the hand-truthed ground-truth sample — drawn by a recorded seed…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T132: [UNBUILT] [TDD] Build the **hand-truthed ground-truth sample** — drawn by a recorded seed — **BLOCKER:** **irreducible HUMAN LABOUR over a private recording** — hand-truthing a ground-truth sample cannot be delegated to a machine, and this is the SINGLE HIGHEST-LEVERAGE operator item in spec 002: T133, T134, T135, T136, T142 and 002's own closure all sit behind it · **OWNER:** **operator / human labour** — nothing an agent can do

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T132.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T132`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-203 — 002-knowledge-areas-deep-linking T133 — [UNBUILT] [TDD] Gate G-OCR-7 — measure textual accuracy per chapter: word error —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T133: [UNBUILT] [TDD] Gate **G-OCR-7** — measure **textual** accuracy per chapter: word error — **BLOCKER:** **predecessor T132** — textual accuracy is measured AGAINST the hand-truthed sample · **OWNER:** **implementer**, after T132

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T133.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T133`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-204 — 002-knowledge-areas-deep-linking T134 — [UNBUILT] [TDD] Gate G-OCR-8 — measure temporal accuracy per chapter: the — BLOCKER:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T134: [UNBUILT] [TDD] Gate **G-OCR-8** — measure **temporal** accuracy per chapter: the — **BLOCKER:** **predecessor T132** — temporal accuracy is measured against the same sample · **OWNER:** **implementer**, after T132

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T134.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T134`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-205 — 002-knowledge-areas-deep-linking T135 — [UNBUILT] [TDD] Gate G-OCR-9 — implement the accuracy budget, derived and never —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T135: [UNBUILT] [TDD] Gate **G-OCR-9** — implement the **accuracy budget, derived and never — **BLOCKER:** **predecessor T132, AND a second independent operator blocker** — `CALIBRATION.md` carries NO WER figure at all, so the floor this gate must read at run time does not exist. The fix is spec 001's T037(b) blind human reference (30 seeded windows, 15 min audio, costed 1-2 h) — **one piece of human work satisfies both specs** · **OWNER:** **operator / human labour**, then **implementer**

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T135.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T135`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-206 — 002-knowledge-areas-deep-linking T136 — [UNBUILT] [TDD] Gate G-OCR-10 — implement the per-chapter publication precondition —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T136: [UNBUILT] [TDD] Gate **G-OCR-10** — implement the **per-chapter publication precondition** — **BLOCKER:** **predecessor T133 + T134 + T135** — a publication precondition cannot be enforced before the figures it gates on exist · **OWNER:** **implementer**, after the accuracy chain

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T136.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T136`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-207 — 002-knowledge-areas-deep-linking T137 — [UNBUILT] [TDD] Gate G-OCR-11 — extend the content-boundary check over OCR output and…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T137: [UNBUILT] [TDD] Gate **G-OCR-11** — extend the content-boundary check over OCR output and — **BLOCKER:** **predecessor T126** — there is no OCR output to extend the content-boundary check over · **OWNER:** **implementer**, after T126

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T137.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T137`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-208 — 002-knowledge-areas-deep-linking T138 — [UNBUILT] [TDD] Index screen_text on its own text and prove G-KG-11 for it — an —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T138: [UNBUILT] [TDD] Index `screen_text` on its own text and prove **G-KG-11** for it — an — **BLOCKER:** **predecessor T126** — nothing to index until `screen_text` mentions are produced · **OWNER:** **implementer**, after T126

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T138.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T138`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-209 — 002-knowledge-areas-deep-linking T139 — [UNBUILT] [P] Add the contract sections and route-manifest rows for the screen_text —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T139: [UNBUILT] [P] Add the contract sections and route-manifest rows for the `screen_text` — **BLOCKER:** none but the work — contract sections and route-manifest rows can be written ahead of the implementation, and doing so early is cheap · **OWNER:** **implementer** — unblocked today

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T139.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T139`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-210 — 002-knowledge-areas-deep-linking T140 — [UNBUILT] [TDD] Prove redaction reaches OCR-derived mentions across all eight targets —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T140: [UNBUILT] [TDD] Prove redaction reaches **OCR-derived** mentions across all eight targets — **BLOCKER:** **predecessor T126** — redaction cannot be proven to reach OCR-derived mentions that do not exist · **OWNER:** **implementer**, after T126

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T140.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T140`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-211 — 002-knowledge-areas-deep-linking T141 — [UNBUILT] [US7] Add the OCR stage to the platform's existing chapter-addition path per…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T141: [UNBUILT] [US7] Add the OCR stage to the platform's **existing** chapter-addition path per — **BLOCKER:** **predecessor T126 + T136** · **OWNER:** **implementer**, after T126/T136

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T141.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T141`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-212 — 002-knowledge-areas-deep-linking T142 — [UNBUILT] [REVIEW] Publish both OCR accuracy figures beside the speech-recognition —…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 002-knowledge-areas-deep-linking task T142: [UNBUILT] [REVIEW] Publish both OCR accuracy figures **beside** the speech-recognition — **BLOCKER:** **predecessor T133 + T134, and spec 001's T037** — both OCR accuracy figures must be published BESIDE the speech-recognition figure, and that figure does not exist either · **OWNER:** **implementer**, after T133/T134 and 001's T037

HOW IT MANIFESTS — the task is tracked in specs/002-knowledge-areas-deep-linking/tasks.md as row T142.

HOW TO REPRODUCE — read specs/002-knowledge-areas-deep-linking/tasks.md and locate the row beginning `T142`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-214 — 003-chapter-hierarchy T001 — [REVIEW] [BLOCKED: ordinal type] Record the decision on Chapter.ordinal in a decision

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T001: [REVIEW] [BLOCKED: ordinal type] Record the decision on `Chapter.ordinal` in a decision

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T001.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T001`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] and annotates it [BLOCKED: ordinal type]. Recorded as Queued rather than Operator-blocked because §11.4.21 + §11.4.148(D3) require a WHY, an exhausted-alternatives statement and an enumerated set of unblock CHOICES, and the source row supplies none of the three. Inventing them to reach the stronger status would be the fabrication §11.4.6 forbids.

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-215 — 003-chapter-hierarchy T002 — [REVIEW] [BLOCKED: ordinal type] Amend

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T002: [REVIEW] [BLOCKED: ordinal type] Amend

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T002.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T002`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] and annotates it [BLOCKED: ordinal type]. Recorded as Queued rather than Operator-blocked because §11.4.21 + §11.4.148(D3) require a WHY, an exhausted-alternatives statement and an enumerated set of unblock CHOICES, and the source row supplies none of the three. Inventing them to reach the stronger status would be the fabrication §11.4.6 forbids.

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-216 — 003-chapter-hierarchy T003 — [REVIEW] Confirm the two amendments agree with each other and with the live route set

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T003: [REVIEW] Confirm the two amendments agree with each other and with the live route set

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T003.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T003`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-085 — 003-chapter-hierarchy T008 — [TDD] Prove G-CH-2 in workshop/platform/gates/verify-chapter-hierarchy.sh: over a

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T008: [TDD] Prove **G-CH-2** in `workshop/platform/gates/verify-chapter-hierarchy.sh`: over a

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T008.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T008`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-220 — 003-chapter-hierarchy T009 — [TDD] Prove G-CH-3: no persisted parent_id, depth or child list exists in the

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T009: [TDD] Prove **G-CH-3**: no persisted `parent_id`, depth or child list exists in the

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T009.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T009`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-222 — 003-chapter-hierarchy T011 — [P] [TDD] Assert the four embeddings measured in research.md D-CH-2, each of which

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T011: [P] [TDD] Assert the four embeddings measured in `research.md` D-CH-2, each of which

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T011.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T011`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-223 — 003-chapter-hierarchy T012 — [REVIEW] Review the grammar and the derivations before anything consumes them. A grammar

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T012: [REVIEW] Review the grammar and the derivations before anything consumes them. A grammar

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T012.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T012`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-227 — 003-chapter-hierarchy T016 — [TDD] Implement G-CH-5 in verify-chapter-hierarchy.sh: no comparison anywhere in

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T016: [TDD] Implement **G-CH-5** in `verify-chapter-hierarchy.sh`: no comparison anywhere in

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T016.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T016`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-228 — 003-chapter-hierarchy T017 — [TDD] Prove G-CH-13. THE CODE FIX LANDED CONCURRENTLY — THE PROOF DID NOT, AND

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T017: [TDD] Prove **G-CH-13**. **THE CODE FIX LANDED CONCURRENTLY — THE PROOF DID NOT, AND

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T017.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T017`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-230 — 003-chapter-hierarchy T019 — [TDD] Prove G-CH-12 for the two patterns already widened in 266f443:

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T019: [TDD] Prove **G-CH-12** for the two patterns already widened in `266f443`:

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T019.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T019`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-231 — 003-chapter-hierarchy T020 — Implement FR-015 at both call sites: a pattern non-match on a directory that exists is

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T020: Implement FR-015 at both call sites: a pattern non-match on a directory that **exists** is

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T020.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T020`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-232 — 003-chapter-hierarchy T021 — [P] Derive the suggest source manifest instead of hardcoding it. Six rows in

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T021: [P] Derive the suggest source manifest instead of hardcoding it. Six rows in

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T021.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T021`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-233 — 003-chapter-hierarchy T022 — [P] Derive every chapter reference in

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T022: [P] Derive every chapter reference in

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T022.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T022`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-086 — 003-chapter-hierarchy T023 — [P] Remove the frozen defaults at workshop/pipeline/build_transcript.py:143–144

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T023: [P] Remove the frozen defaults at `workshop/pipeline/build_transcript.py:143`–`144`

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T023.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T023`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-087 — 003-chapter-hierarchy T024 — [P] Resolve workshop/pipeline/calibrate.sh:36 from a named chapter instead of a frozen

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T024: [P] Resolve `workshop/pipeline/calibrate.sh:36` from a named chapter instead of a frozen

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T024.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T024`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-234 — 003-chapter-hierarchy T025 — [TDD] [BLOCKED: ordinal type] Replace ordinalOf

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T025: [TDD] [BLOCKED: ordinal type] Replace `ordinalOf`

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T025.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T025`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] and annotates it [BLOCKED: ordinal type]. Recorded as Queued rather than Operator-blocked because §11.4.21 + §11.4.148(D3) require a WHY, an exhausted-alternatives statement and an enumerated set of unblock CHOICES, and the source row supplies none of the three. Inventing them to reach the stronger status would be the fabrication §11.4.6 forbids.

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-237 — 003-chapter-hierarchy T028 — [P] [TDD] Reconcile the front end's two chapter shapes in

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T028: [P] [TDD] Reconcile the front end's two chapter shapes in

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T028.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T028`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-238 — 003-chapter-hierarchy T029 — [TDD] Prove G-CH-11: core/api.ts:88 reads body['chapters'] as a flat array and

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T029: [TDD] Prove **G-CH-11**: `core/api.ts:88` reads `body['chapters']` as a flat array and

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T029.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T029`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-240 — 003-chapter-hierarchy T031 — [TDD] Add under, depth and include_self, and echo the applied filters on every

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T031: [TDD] Add `under`, `depth` and `include_self`, and echo the applied `filters` on **every**

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T031.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T031`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-241 — 003-chapter-hierarchy T032 — [TDD] Prove G-CH-8: an under naming a chapter that does not exist returns 200

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T032: [TDD] Prove **G-CH-8**: an `under` naming a chapter that does not exist returns **`200`**

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T032.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T032`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-242 — 003-chapter-hierarchy T033 — [BLOCKED: ordinal type] Add hierarchy with parent_href and child_hrefs to

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T033: [BLOCKED: ordinal type] Add `hierarchy` with `parent_href` and `child_hrefs` to

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T033.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T033`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] and annotates it [BLOCKED: ordinal type]. Recorded as Queued rather than Operator-blocked because §11.4.21 + §11.4.148(D3) require a WHY, an exhausted-alternatives statement and an enumerated set of unblock CHOICES, and the source row supplies none of the three. Inventing them to reach the stronger status would be the fabrication §11.4.6 forbids.

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-243 — 003-chapter-hierarchy T034 — [TDD] Prove G-CH-9 (H3): a sub-chapter whose parent directory is absent is served,

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T034: [TDD] Prove **G-CH-9** (H3): a sub-chapter whose parent directory is absent is **served**,

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T034.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T034`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-088 — 003-chapter-hierarchy T035 — Update workshop/platform/gates/route-manifest.tsv. Three separate changes: (a)

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T035: Update `workshop/platform/gates/route-manifest.tsv`. Three separate changes: (a)

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T035.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T035`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-244 — 003-chapter-hierarchy T036 — [TDD] Implement G-CH-10 and G-CH-14 in verify-chapter-hierarchy.sh, with

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T036: [TDD] Implement **G-CH-10** and **G-CH-14** in `verify-chapter-hierarchy.sh`, with

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T036.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T036`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-245 — 003-chapter-hierarchy T037 — [REVIEW] Closure: publish max_depth_present as a measurement and assert no constant

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 003-chapter-hierarchy task T037: [REVIEW] Closure: publish `max_depth_present` as a **measurement** and assert no constant

HOW IT MANIFESTS — the task is tracked in specs/003-chapter-hierarchy/tasks.md as row T037.

HOW TO REPRODUCE — read specs/003-chapter-hierarchy/tasks.md and locate the row beginning `T037`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-103 — 004-authored-ai-areas T028 — [US2] Render the lesson list and lesson body with prev/next in…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T028: [US2] Render the lesson list and lesson body with prev/next in `workshop/platform/frontend/src/app/features/`, using the same sorted slice the list uses (FR-007, SC-006).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T028.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T028`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-258 — 004-authored-ai-areas T038 — [P] [US3] Report an unresolvable target as unavailable rather than routing to a page that…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T038: [P] [US3] Report an unresolvable target as unavailable rather than routing to a page that reports nothing found (FR-017).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T038.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T038`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-261 — 004-authored-ai-areas T043 — [P] [US4] Play a video segment in place, bounded to its stated range (FR-013).

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T043: [P] [US4] Play a video segment in place, bounded to its stated range (FR-013).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T043.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T043`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-262 — 004-authored-ai-areas T044 — [P] [SUBAGENT] [US4] Rasterise the 8 SVGs and check text fit at the served font metric…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T044: [P] [SUBAGENT] [US4] Rasterise the 8 SVGs and check text fit at the served font metric — well-formedness and theming are verified; **text fit is not** (plan.md gap 7; FR-013).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T044.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T044`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-263 — 004-authored-ai-areas T049 — [US5] Emit corpus_revision on the served catalogue and cite it in every interface claim…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T049: [US5] Emit `corpus_revision` on the served catalogue and cite it in every interface claim (FR-023a, SC-018). **Analysis finding F7 — MISPLACED**: this is a catalogue concern owned by the backend stream, not a presentation one. Execute it with Phase 3 (US1); it is listed here only because the superspec blueprint's Track A carries a *bundle* build id, which is a different artefact, and this task must not be assumed covered by it.

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T049.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T049`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-122 — 004-authored-ai-areas T059 — [P] Add workshop/curriculum/area-timelinks.json and…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T059: [P] Add `workshop/curriculum/area-timelinks.json` and `workshop/curriculum/unpublished-areas.jsonl` to `.gitignore`, matching their siblings (FR-?).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T059.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T059`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-267 — 004-authored-ai-areas T060 — [P] Re-run the full frontend suite and account for every delta against the 162/0/8…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T060: [P] Re-run the full frontend suite and account for every delta against the 162/0/8 baseline (FR-?).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T060.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T060`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-268 — 004-authored-ai-areas T061 — [REVIEW] Human checkpoint — read the 3 area documents failing publication review on 62,…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T061: [REVIEW] **Human checkpoint** — read the 3 area documents failing publication review on 62, 54 and 58 uncited claim blocks. They stay failing until read; stamping them is the bypass (FR-002).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T061.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T061`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-269 — 004-authored-ai-areas T062 — [REVIEW] Human checkpoint — confirm or replace the 70% passPercent, the mcq-2/short-3…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T062: [REVIEW] **Human checkpoint** — confirm or replace the 70% `passPercent`, the mcq-2/short-3 point weights, the 91–95 prefix shift and the anchor attachment section. These four are authored schema choices, stated rather than measured (FR-008b, SC-017).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T062.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T062`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-270 — 004-authored-ai-areas T064 — Regenerate the 12 pre-existing documents' ingested .sections.json, or record that their…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T064: Regenerate the 12 pre-existing documents' ingested `.sections.json`, or record that their corpus copy is stale. **Regenerating mints new pids and changes the searchable corpus** — a corpus decision, not a cleanup (FR-?).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T064.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T064`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-271 — 004-authored-ai-areas T065 — [SUBAGENT] Investigate the redaction-pipeline report: one segment is marked redacted:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T065: [SUBAGENT] Investigate the redaction-pipeline report: one segment is marked `redacted: true` while the same sentence survives in the merged transcript. Reported, not acted on (FR-?).

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T065.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T065`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-272 — 004-authored-ai-areas T066 — [TDD] Assert corpus stability during measurement in every corpus-counting run (FR-030,…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T066: [TDD] Assert **corpus stability during measurement** in every corpus-counting run (FR-030, FR-027) — fingerprint the enumerated set before and after the analysis passes, sharing the enumeration with the analysis by construction, and emit `undet` rows **naming the changed paths** when they differ. **Analysis finding F2: this requirement had zero task coverage.** It was promoted from a real incident — a gate reporting 12939 / 12939 / 13058 / 12968 for the same command on a tree another agent was editing. The umbrella's `scripts/verify-content-boundary.sh` already implements exactly this; reuse its approach rather than inventing one.

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T066.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T066`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-124 — 004-authored-ai-areas T067 — [TDD] [P] Assert result stability (FR-011, FR-026) in…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T067: [TDD] [P] Assert **result stability** (FR-011, FR-026) in `workshop/platform/gates/prove-assessment-gate.sh` — submit, re-read, require a byte-identical result. **Analysis finding F4: FR-011 appeared only as a manual quickstart step, so nothing asserted it.**

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T067.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T067`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-125 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Detect duplicate subjects in workshop/pipeline/extract/verify_curriculum_areas.py or record FR-020 as deferred (spec 004 T068) WHY: the change lives in the private workshop submodule's own repository, or is a push/publication; this wave may not edit it or push UNBLOCK: - [1] implement detector in workshop, commit, bump gitlink; cost: workshop commit + gitlink bump
- [2] record FR-020 deferred with reason in workshop; cost: duplicate subjects stay undetected WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-273 — 004-authored-ai-areas T070 — [P] Append the governing FR/SC identifiers to each task line in this file (SC-013).…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 004-authored-ai-areas task T070: [P] Append the governing FR/SC identifiers to each task line in this file (SC-013). **Analysis finding F8**: 33 of 39 FRs and 14 of 18 SCs are cited nowhere by id, so **SC-013 ("100% of requirements map to a check") is mechanically unverifiable** — it can be argued but not computed. With ids present it becomes a `grep`.

HOW IT MANIFESTS — the task is tracked in specs/004-authored-ai-areas/tasks.md as row T070.

HOW TO REPRODUCE — read specs/004-authored-ai-areas/tasks.md and locate the row beginning `T070`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-276 — 005-clone-and-clear-red T010 — [TDD] [US1] PARTIAL — run verify-obtainability.sh --prove-failure, the §1.1 paired…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T010: [TDD] [US1] **PARTIAL** — run `verify-obtainability.sh --prove-failure`, the §1.1 paired proof, and record its pass/mutation counts (FR-021, SC-014). The proof's interface and mutation **M7** (a FINDING outranks an UNDETERMINED, never inverted) are declared in the guard's header, but **no run of it was captured in this session**, so no count is claimed here.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T010.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T010`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-277 — 005-clone-and-clear-red T011 — [US1] OPEN — perform SC-001's actual trial: 3 of 3 clones by the documented command, on…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T011: [US1] **OPEN** — perform SC-001's actual trial: **3 of 3** clones by the documented command, on a machine that has never held the repository, with **0** transport failures (FR-001, SC-001). The refuting two-arm HTTPS test recorded in spec.md was run from a third host and proves the transport works; it is **not** the 3-of-3 acceptance run, and must not be reported as one.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T011.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T011`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-278 — 005-clone-and-clear-red T012 — [US1] BLOCKED — operator decision. Publish the documented step by which recorded…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T012: [US1] **BLOCKED — operator decision.** Publish the documented step by which recorded material is obtained from storage outside the repository, with its stated availability condition (FR-003, SC-003). The superseding instruction was explicit that the fetch instructions come in a later iteration. **Until it exists, SC-003's "100% remains obtainable by a documented step" is NOT met** — the bytes are on one disk and the step is unwritten.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T012.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T012`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-279 — 005-clone-and-clear-red T013 — [US1] OPEN — warn on the growth TREND, not only on the breach (Edge case: *a repository…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T013: [US1] **OPEN** — warn on the growth TREND, not only on the breach (Edge case: *a repository shrinks below the threshold but keeps growing*). The guard thresholds on a point-in-time size; nothing reads a series.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T013.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T013`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-285 — 005-clone-and-clear-red T020 — [US2] BLOCKED — operator credential. Turn the 6 UNVERIFIED provider rows into verdicts…

**Status:** Operator-blocked
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T020: [US2] **BLOCKED — operator credential.** Turn the 6 UNVERIFIED provider rows into verdicts (FR-011c, SC-005). **Re-measured 2026-09-08** (served, provider APIs): `bash scripts/verify-provider-ci.sh` exits **1** — 22 repositories / 40 upstream rows, **1 CONFIRMED**, and the 6 rows now report *"an adapter IS registered for this host but could not run"* rather than *"no adapter registered"*. `https://api.gitflic.ru` answers **HTTP 403** and `https://api.gitverse.ru` answers **HTTP 401**; both require a credential on every route and none is configured. **This is FR-011c working exactly as written** — "never asked" became "asked and could not determine", which is progress, and it was NOT converted into a pass. Lifting it needs `GITFLIC_TOKEN` / `GITVERSE_TOKEN`, which only the operator can issue.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T020.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T020`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-293 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Work through the baselined hardcoded-path occurrences (spec 005 T028); about half are fixable only by upstream submodule commits then a gitlink bump WHY: the change lives in the private workshop submodule's own repository (or needs a push/gitlink bump), which this wave may not edit UNBLOCK: - [1] fix per owning repository and bump gitlinks one at a time; cost: several submodule commits + operator-approved bumps
- [2] record remaining debt as documented-deviation; cost: baseline figure keeps overstating until re-derived WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-295 — 005-clone-and-clear-red T031 — [US2] OPEN — build the fleet summary that reports defect count and declared-condition…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T031: [US2] **OPEN** — build the fleet summary that reports **defect count and declared-condition count separately and never merges them** (FR-009, SC-008). **No such instrument exists.** Every gate reports its own verdict; nothing aggregates them into the two-number statement FR-009 requires, so SC-008's "unexplained reds reaches 0, from a baseline of 11" is **not computable today**.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T031.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T031`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-296 — 005-clone-and-clear-red T032 — [US2] OPEN — give every non-clean instrument an explicit KIND on its own output line:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T032: [US2] **OPEN** — give every non-clean instrument an explicit KIND on its own output line: defect / declared / could-not-run (FR-006, SC-005). Several instruments do this well (T014, T015, T020); **it is not universal**, and SC-005's "100% of non-clean results state their kind" has not been measured across the fleet.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T032.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T032`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-297 — 005-clone-and-clear-red T033 — [US2] OPEN — make a declared condition name who may lift it and what evidence would…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T033: [US2] **OPEN** — make a declared condition name **who may lift it and what evidence would** (FR-007, SC-015). `scripts/check-registry.tsv` exemptions now carry evidence and reasons (T017), and T020's row names the credential, but no instrument requires a lifting authority as a structural field.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T033.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T033`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-298 — 005-clone-and-clear-red T034 — [TDD] [US2] OPEN — assert FR-010 mechanically: any threshold, bucket, allow-list or…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T034: [TDD] [US2] **OPEN** — assert FR-010 mechanically: any threshold, bucket, allow-list or baseline change must carry a principle stated independently of the count it produces (FR-010, SC-007). Two guards do this in prose by construction — `verify-obtainability.sh`'s two threshold rules (T007) and the palette gate's fixed floor — but **nothing detects a weakening change**. This is the requirement most exposed to being satisfied by assertion.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T034.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T034`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-299 — 005-clone-and-clear-red T035 — [REVIEW] [US2] OPEN — run SC-015's acceptance: a reader answers *"is this a defect,…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T035: [REVIEW] [US2] **OPEN** — run SC-015's acceptance: a reader answers *"is this a defect, what is the evidence, what happens next"* for every red from instrument output alone, without consulting a person. Not attempted; it depends on T031–T033.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T035.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T035`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-300 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Run the bank verifier against the private corpus to confirm SC-009 (0 questions cite withheld material), spec 005 T037 WHY: the change lives in the private workshop submodule's own repository, needs a live-service run, install, push or an operator choice; this wave may not edit it UNBLOCK: - [1] operator runs the verifier in workshop and records the count; cost: private-corpus run, result recorded by path only
- [2] leave SC-009 UNVERIFIED; cost: claim stays unproven WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## WSP-136 — 005-clone-and-clear-red T038 — [US3] OPEN — tell a learner, in the interface, that an area has no assessment and why…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T038: [US3] **OPEN** — tell a learner, in the interface, that an area has no assessment and why (FR-013, SC-010). No task in the tree implements the learner-facing disclosure; the platform's absence-honesty gates (`workshop/platform/gates/verify-absence-honesty.sh`) govern what the *server* asserts, not what the *learner reads*.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T038.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T038`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-301 — Pre-existing Queued register item adopted as a zero-gap item with no measurable target

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Count assessed vs corpus-unsupported areas separately (spec 005 T040) in the workshop repo WHY: the change lives in the private workshop submodule's own repository, needs a live-service run, install, push or an operator choice; this wave may not edit it UNBLOCK: - [1] implement the two-population count in workshop, commit, bump gitlink; cost: workshop commit + gitlink bump
- [2] leave SC-011 unreported; cost: corpus limitation could read as progress WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Items from features 001/002/004/005 are Queued as PARTIAL / NOT BUILT / UNWRITTEN with no measurable target.

Proposed fix: Backfill kind, category, plan_due and a measurable target on the existing atm id (FR-025); re-judge severity per item; then the item follows the closure rules on its own id.

## VSC-302 — 005-clone-and-clear-red T041 — [REVIEW] [US3] BLOCKED — operator gate. Read the 3 documents failing publication review…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T041: [REVIEW] [US3] **BLOCKED — operator gate.** Read the 3 documents failing publication review on **62, 54 and 58** uncited claim blocks and decide publish-or-not (FR-014, SC-010). They remain unpublished, so a client sees fewer areas than are authored. This is the same gate carried as T060 in [`../006-session-record-and-qa-readiness/tasks.md`](../006-session-record-and-qa-readiness/tasks.md) — **one decision, recorded in two specs, not two decisions.**

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T041.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T041`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-303 — 005-clone-and-clear-red T042 — [US3] OPEN — assert FR-014 mechanically: a published document's primary references…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T042: [US3] **OPEN** — assert FR-014 mechanically: a published document's primary references resolve to material a reader can actually reach. T041 is a human read of three documents; **no check enumerates published documents and resolves their primary references.**

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T042.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T042`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-139 — 005-clone-and-clear-red T046 — [US4] PARTIAL — re-measure the served hue-family count and record it against SC-012's…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T046: [US4] **PARTIAL** — re-measure the served hue-family count and record it against SC-012's floor of 6, up from a baseline of 2 (FR-016, SC-012). The corrected instrument exists (T043–T045) and `workshop/platform/gates/sample-served-surfaces.mjs` takes the browser sample. **No served run was captured in this session, so no post-fix count is claimed here.** `CONTINUATION.md:646` still records the baseline *"the served interface paints 2 hue families against a floor of 6"*, and until a served run supersedes it, **that is the last measured figure in this tree.** Note the shape of the trap this gate was built against: when the instrument became honest the count went **down** from 4 to 2 — a corrected gate reporting a worse number than the broken one it replaced.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T046.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T046`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-140 — 005-clone-and-clear-red T047 — [US4] OPEN — give every hue present a stated classification job, so no hue is added…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T047: [US4] **OPEN** — give every hue present a stated classification job, so no hue is added only to raise a count (FR-017, SC-012). The design-system documents landed in commit `f11a3c1` (`workshop/docs/design-system/TOKENS.md`, `RATIONALE.md`, `COMPONENTS.md`, `wk-semantic-tokens.css`), but **nothing asserts the mapping from every painted hue to a declared job**, which is what SC-012's second half requires.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T047.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T047`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-306 — 005-clone-and-clear-red T049 — [US4] PARTIAL — record the served contrast result: 0 failures across text and non-text…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T049: [US4] **PARTIAL** — record the served contrast result: **0** failures across text and non-text pairings in both presentations (FR-019, SC-013). The gate and its prover exist; **no served run was captured in this session.**

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T049.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T049`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-307 — 005-clone-and-clear-red T050 — [US4] OPEN — justify the measured population independently of its effect on the count,…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T050: [US4] **OPEN** — justify the measured population independently of its effect on the count, and record that justification whenever the population changes (FR-018, SC-012). T044 **changed the population** (adding `paint`) for a stated defect reason, which is the right shape — but no rule requires the next change to do the same, and the edge case *"a red is fixed by making the instrument weaker"* lives exactly here.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T050.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T050`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-143 — 005-clone-and-clear-red T053 — [TDD] PARTIAL — make every check whose subject is a set establish the set is non-empty…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T053: [TDD] **PARTIAL** — make every check whose subject is a set establish the set is **non-empty** before reporting the set contains no defects (FR-022, SC-014). Two instruments do this: `verify-obtainability.sh` returns **2** when nothing is tracked to measure, and `workshop/platform/gates/verify-bank-reachability.sh` was written precisely because the prior gate checked one fixture area while 89 questions were unreachable. **It is not universal, and no sweep asserts it across the fleet.**

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T053.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T053`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-309 — 005-clone-and-clear-red T054 — OPEN — satisfy SC-014: 100% of requirements map to at least one automated check, and…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 005-clone-and-clear-red task T054: **OPEN** — satisfy SC-014: **100%** of requirements map to at least one automated check, and every such check ships a data-driven paired demonstration (FR-020, SC-014). **This file is the first half of that criterion and does not complete it.** Every FR and SC in spec.md is now cited by at least one task above — but a task is not a check, and 22 of the 54 tasks here are not ticked. **Requirements with no automated check at all: FR-009, FR-010, FR-013, FR-014, FR-017 and SC-015.** Those six are the real coverage gap.

HOW IT MANIFESTS — the task is tracked in specs/005-clone-and-clear-red/tasks.md as row T054.

HOW TO REPRODUCE — read specs/005-clone-and-clear-red/tasks.md and locate the row beginning `T054`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-317 — 006-session-record-and-qa-readiness T015 — [US1] Build GET /api/chapters/{id}/open-questions, preserving the three-valued resolution…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T015: [US1] Build `GET /api/chapters/{id}/open-questions`, preserving the three-valued `resolution` the client already types (`answered_in_chapter`/`answered_by_research`/`unanswered`) (FR-005). **The wire must not narrow it** — the consumer already knows what it needs.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T015.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T015`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-318 — 006-session-record-and-qa-readiness T016 — [P] [US1] Build GET /api/chapters/{id}/todo reading pkg/sessionrecord, never re-deriving…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T016: [P] [US1] Build `GET /api/chapters/{id}/todo` reading `pkg/sessionrecord`, never re-deriving (FR-005).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T016.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T016`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-319 — 006-session-record-and-qa-readiness T017 — [P] [US1] Build GET /api/chapters/{id}/next-meeting reading pkg/sessionrecord (FR-005).

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T017: [P] [US1] Build `GET /api/chapters/{id}/next-meeting` reading `pkg/sessionrecord` (FR-005).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T017.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T017`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-150 — 006-session-record-and-qa-readiness T018 — [TDD] [US1] Assert the routes and the embedded key serve the same items in…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T018: [TDD] [US1] Assert the routes and the embedded key serve the **same items** in `workshop/platform/gates/verify-session-record.sh` (FR-005, FR-023). **This is the pair assertion** — a route and a key that agree today are exactly what drift, and that class produced the 819-vs-817 catalogue bug.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T018.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T018`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## WSP-151 — 006-session-record-and-qa-readiness T019 — [REVIEW] [US1] BLOCKED — operator decision. GET /api/chapters/{id}/meeting-notes is NOT…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T019: [REVIEW] [US1] **BLOCKED — operator decision.** `GET /api/chapters/{id}/meeting-notes` is NOT built. Its withholding rule **may not be guessed** (FR-005a): one note is a content judgement left undecided. Update its DEBT row in `workshop/platform/gates/route-manifest.tsv` to name that specific blocker rather than the general one (FR-028).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T019.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T019`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-325 — 006-session-record-and-qa-readiness T026 — [SUBAGENT] [US2] Propose a coverage verdict per point with per-point evidence and…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T026: [SUBAGENT] [US2] Propose a coverage verdict per point with **per-point evidence and confidence**, marked `PROPOSED`, written to a separate artefact — never into `plan-coverage.json`, which is the decision record (FR-007a).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T026.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T026`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-326 — 006-session-record-and-qa-readiness T027 — [TDD] [US2] Assert coverage_state is still undecided and the served counts have not moved…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T027: [TDD] [US2] Assert `coverage_state` is still `undecided` and the served counts have not moved after a proposal exists (FR-007a). **This is what makes "a proposal is not a decision" mechanical rather than aspirational.**

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T027.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T027`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-327 — 006-session-record-and-qa-readiness T028 — [REVIEW] [US2] Operator gate: confirm or overturn the proposed verdicts (FR-007a). Until…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T028: [REVIEW] [US2] **Operator gate**: confirm or overturn the proposed verdicts (FR-007a). Until then the served figure stays `undecided`.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T028.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T028`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-328 — 006-session-record-and-qa-readiness T031 — [SUBAGENT] [US3] Regenerate both against the current build (FR-020a). They describe 14…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T031: [SUBAGENT] [US3] **Regenerate both against the current build** (FR-020a). They describe 14 areas with tests and 0 lessons with content; live is **27** and **318 of 318**. **A stale expected-result column manufactures false defects** and spends a tester's day disproving our own fixes.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T031.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T031`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-329 — 006-session-record-and-qa-readiness T032 — [US3] Record the build identifier in both — served-CSS sha256, served area count, index…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T032: [US3] Record the build identifier in both — served-CSS `sha256`, served area count, index generation — and state they must be regenerated when it moves (FR-020a, FR-026).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T032.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T032`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-330 — 006-session-record-and-qa-readiness T033 — [US3] Disclose up front (FR-020, FR-020b): 39 served against 42 authored; 12 areas…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T033: [US3] Disclose up front (FR-020, FR-020b): 39 served against 42 authored; 12 areas carrying no test with the reason; every score indeterminate while banks mix machine-marked and free-text questions.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T033.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T033`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-331 — 006-session-record-and-qa-readiness T034 — [P] [US3] Disclose that /meeting-notes is deliberately unbuilt and that three sibling…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T034: [P] [US3] Disclose that `/meeting-notes` is deliberately unbuilt and that three sibling routes may or may not be live — **check, do not assume** (FR-020, FR-028, SC-008).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T034.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T034`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-337 — 006-session-record-and-qa-readiness T044 — [P] [SUBAGENT] [US4] Author text alternatives for the 205 video materials (FR-016,…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T044: [P] [SUBAGENT] [US4] Author text alternatives for the 205 video materials (FR-016, FR-028). **Evidence needed**: 205 of 213 carry `alt: ""`; the interface names the absence rather than hiding it, so this is a disclosed gap, not a hidden one.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T044.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T044`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-339 — 006-session-record-and-qa-readiness T050 — [TDD] [SUBAGENT] [US5] Add the build identifier to /api/health (FR-026). Evidence needed:…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T050: [TDD] [SUBAGENT] [US5] Add the build identifier to `/api/health` (FR-026). **Evidence needed**: nothing noticed the container was four hours older than the code, because no reading could be tied to a revision.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T050.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T050`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-340 — 006-session-record-and-qa-readiness T051 — [SUBAGENT] [US5] Commission a second independent adversarial review against the rebuilt…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T051: [SUBAGENT] [US5] Commission a **second** independent adversarial review against the rebuilt container (FR-029, SC-014). The first found four false headline claims; a review that confirms is worth little.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T051.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T051`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-344 — 006-session-record-and-qa-readiness T056 — Restart once when every writer has stopped, verified by two git status readings 30 s…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T056: Restart once when every writer has stopped, verified by two `git status` readings 30 s apart (FR-027). **A restart triggers a 45-minute cross-reference derivation** over 24,929 passages, during which `verify-crossref-currency.sh` correctly reports rc 1.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T056.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T056`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-345 — 006-session-record-and-qa-readiness T057 — Re-run the full gate sweep against the rebuilt container and record each figure with its…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T057: Re-run the full gate sweep against the rebuilt container and record each figure with its **population** — `source`, `in_process` or `served` (FR-023, FR-026).

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T057.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T057`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## WSP-164 — 006-session-record-and-qa-readiness T058 — [P] [SUBAGENT] Register every new gate in workshop/platform/gates/check-registry-006.tsv…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T058: [P] [SUBAGENT] Register every new gate in `workshop/platform/gates/check-registry-006.tsv` (FR-?). **Evidence needed**: an unregistered gate fails the registry's own R5 anti-drift rule, which caught one of mine today.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T058.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T058`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — the source row names the path workshop.
## VSC-346 — 006-session-record-and-qa-readiness T059 — [P] [SUBAGENT] Re-validate every exempt row whose subject changed this session (FR-028).…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T059: [P] [SUBAGENT] Re-validate every `exempt` row whose subject changed this session (FR-028). **Evidence needed**: one said *"it judges nothing"* of a script that had gained a three-valued verdict — an exemption whose justification expired still looks reviewed.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T059.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T059`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-347 — 006-session-record-and-qa-readiness T060 — [REVIEW] Operator gate: read the 3 documents failing publication review on 62, 54 and 58…

**Status:** Queued
**Type:** Task
**Severity:** unset
**Created-By:** AI

WHAT — 006-session-record-and-qa-readiness task T060: [REVIEW] **Operator gate**: read the 3 documents failing publication review on 62, 54 and 58 uncited claim blocks (FR-020b, FR-023). They stay unpublished until read; a client sees 39 areas, not 42.

HOW IT MANIFESTS — the task is tracked in specs/006-session-record-and-qa-readiness/tasks.md as row T060.

HOW TO REPRODUCE — read specs/006-session-record-and-qa-readiness/tasks.md and locate the row beginning `T060`.

ACCEPTANCE CRITERIA — the row's own stated outcome, evidenced per §11.4.5 against the artefact it names.

STATUS BASIS — the tracked task list marks this row [ ] — not started or not finished

SUB-PROJECT BASIS — no sub-project path named in the source row.
## VSC-349 — Root carriers (CLAUDE.md and its three lockstep mirrors) record status/rc and count figures with no re-measure command

**Status:** Queued
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

The carriers narrate measured figures (PASS/DRIFT splits, rc/exit values, N of M, counts) as prose; only 7 docs/claim-ledger.tsv rows anchor CLAUDE.md, so every other figure can go stale with every gate green. Class meaning (rev-base-A ruling): unanchored recorded figures, staleness unmeasured. Mirrors AGENTS.md/QWEN.md/GEMINI.md are byte-identical from line 19 and deduped onto CLAUDE.md. Per figure line, one of: (a) a docs/claim-ledger.tsv row with a re-measure command for figures stated as current; (b) the line-level historical marker (withdrawn/superseded/historical) for dated history; (c) replace the figure with the command that derives it. Edit the shared region once and recompose the four carriers (C5).

## VSC-351 — CONTINUATION.md current-state sections (0,1,4-7) record figures with no re-measure command

**Status:** Queued
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

The resumption prompt, open-gaps, hazards and gate sections state current figures in prose; no claim-ledger row anchors them. Ledger rows (re-measure command) for figures stated as current, or replace with the command; historical marker for dated ones.

## WSP-165 — workshop module documents record gate/script/line counts that drifted (verify 23 vs 101, prove 27 vs 94, scripts 20 vs 47, 1373 vs 1372 lines)

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts are typed into the four lockstep workshop carriers, workshop/README.md and workshop/docs/work-register.md; nothing re-measures them. Inside the workshop repository: replace each count with its derive command or add a workshop-side re-measure check; update all four carriers together. Returns to the umbrella as a gitlink bump.

## VSC-354 — INVENTORY.md section 2/3 phase-1 figures (11,101 lines; 7 nested submodules) read as current but the pin moved

**Status:** Queued
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

The document is a historical record plus a current status ledger (its header); the phase-1 figures of sections 2-3 are dated 2026-08-26 but not marked dated at line level, and point-in-time.tsv deliberately excludes the whole file. Mark the two figures as dated to the 2026-08-26 pin at line level (or re-measure them and cite the command); keep the file out of point-in-time.tsv.

## VSC-356 — Umbrella docs/** carry unmeasurable recorded counts (47 documents)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## VSC-357 — Umbrella specs/** carry unmeasurable recorded counts (32 documents, incl. this feature's own baseline README)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## WSP-166 — workshop documents carry unmeasurable recorded counts (59 documents)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## AII-002 — ai_interviewing documents carry unmeasurable recorded counts (53 documents)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## HQA-001 — submodules/qa documents carry unmeasurable recorded counts (22 documents)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## MON-001 — monetization documents carry unmeasurable recorded counts (5 documents)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## VSC-358 — Five small owned modules carry unmeasurable recorded counts (llms_verifier 2, security 2, challenges 1, containers 1, verdict 1)

**Status:** Queued
**Type:** Task
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Counts whose subject no rule of the class noun-to-measure table resolves ("recorded, not drift"): nothing re-measures them. Many sit in dated session reports, plans and evidence files that were true when written. Per document: (a) a docs/zero-gap/point-in-time.tsv row with the reason from the document header when it is dated; (b) a noun-to-measure rule when the subject is measurable in the tree; (c) otherwise replace the count with its derive command. Fix in the repository that owns the document.

## LLP-001 — submodules/LLMProvider gitlink 4c73c8b0dfc6 behind its remote tip e05ec64ebc48 (fast-forwardable)

**Status:** Operator-blocked
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Owned gitlink not bumped after upstream commits; 4 remotes (github, gitlab, origin, upstream) show the same tip. Operator decides per bump: fast-forward (merge --ff-only, stage gitlink and helix-deps.yaml ref together) or hold.

## HLP-001 — submodules/llm_provider gitlink f29fe2439c81 behind origin e05ec64ebc48

**Status:** Operator-blocked
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Owned gitlink not bumped. Observation: HelixDevelopment/LLMProvider and vasic-digital/LLMProvider (submodules/LLMProvider) report the SAME tip e05ec64ebc48; whether two gitlinks of one history are intended is UNCONFIRMED. Operator decides per bump; separately decide whether both gitlinks should exist (never remove without an explicit operator decision, §11.4.122).

## LMV-001 — submodules/llms_verifier gitlink 2c6602c78931 behind origin 8f2090acb907

**Status:** Operator-blocked
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Owned gitlink not bumped. Operator decides per bump (ff-only; gitlink + helix-deps.yaml ref staged together).

## CON-002 — submodules/constitution pin f8afb98ab0eb differs from all 8 remotes (direction undetermined at baseline)

**Status:** Queued
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

The pin went stale again (the carrier records five green-then-red cycles). Baseline remote tip 647f7553533a; re-probed 2026-09-26: origin HEAD now 0ff780dc4e4f. Under the STANDING AUTHORIZATION of 2026-09-09: fetch inside the submodule, require merge-base --is-ancestor TRUE and 0 divergent, git merge --ff-only, report diff --stat, re-measure Constitution.md on both sides (blob, lines, anchors, bytes, sha256), stage gitlink + helix-deps.yaml ref together, never push. Any divergence: stop and report.

## VSC-362 — Decision record 2026-09-09: three findings from #12 not yet decided (row repair)

**Status:** Operator-blocked
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

The record names three undecided findings and says the row repair is a separate operator decision; no options or cost are recorded. Prepare the decision (options + cost per FR-009) and put it to the operator; the false-green gate part is split into G-improvement-candidates-02b because it is fixable from here.

## WSP-167 — workshop verify-plan-coverage-proposal.sh passes without reading the prose it guards (66 vs 49 rows)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

Per the 2026-09-09 record the gate exits 0 while the proposal prose and the committed JSON disagree, because it never reads the prose (a false-green, §11.4.201). Current state UNCONFIRMED (not re-run this session). Make the gate read and compare the prose count; paired mutation proof.

## CON-003 — PreToolUse guard: host-power rule misses bare reboot/halt/poweroff binaries

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the guard's host-power gate matches only `systemctl|loginctl <verb>`, `pm-*` and `shutdown`; the bare binaries reboot, halt and poweroff match no pattern, so the rule declared no-override lets them through upstream: add bare-binary alternatives (reboot|halt|poweroff, incl. absolute-path and command-substitution forms) to the host-power block with RED fixtures; project side: G-guard-gaps-07 mitigation

## CON-004 — PreToolUse guard: no rule for ref and history destruction (branch -D, update-ref -d, filter-branch, push --delete, push :ref)

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the guard's git-push rule keys on --force/--force-with-lease/+refspec only and there is no rule for local ref deletion; the FORCE_MSG text names 'history rewrite' but no pattern implements it upstream: extend the push rule to --delete/-d and `:<ref>` refspecs; add a ref-destruction rule (branch -D/--delete --force, update-ref -d) and a history-rewrite rule (filter-branch, filter-repo); RED fixtures per form

## CON-005 — PreToolUse guard: no rule for uncommitted-work discard on a shared tree (reset --hard, checkout ., restore ., clean -fd/-fdx, stash)

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the guard has no working-tree-discard class; the project's own .specify/memory/constitution.md 'Shared-Tree Discipline Is Wider Than stash' names these as destructive on a shared tree, but nothing enforces it at tool-call time upstream: add a shared-tree discard rule (reset --hard, checkout [--] ., restore ., clean -f*, stash with no pathspec); RED fixtures; decide override policy (allow-marker or none)

## CON-006 — PreToolUse guard: no rule for bulk staging (git add -A, git add .)

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

no bulk-staging rule exists; on a tree shared by parallel agents bulk staging captures other agents' uncommitted files (closure-wave protocol (f) bans `add -A`) upstream: add a bulk-staging rule for agent tool calls (add -A/--all/., commit -a); note the operator's `commit` wrapper stages with `git add .` internally and is not a tool-call string, so it is unaffected

## CON-007 — PreToolUse guard: no rule for signalling processes by name or pattern (pkill -f, killall)

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

no process-signalling rule exists; §11.4.174 (verify the process is ours) and §11.4.263 (process-group signal safety) forbid name/pattern kills, and a reviewer's `pkill -f` already killed its own shell once (progress.yml process-slip ruling) upstream: add a name/pattern signalling rule (pkill, killall, kill -<sig> -<pgid>); RED fixtures incl. `pkill -f` with -u

## CON-008 — PreToolUse guard: no rule for recursive removal of / or ~

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

no bulk-removal rule exists; §9 names bulk file removal as a pre-op-backup operation, yet `rm -rf /` and `rm -rf ~` exit 0 from the guard upstream: add a recursive-removal rule for /, ~, $HOME and bare top-level targets (with --no-preserve-root forms); RED fixtures; keep scoped build-dir removals allowed (benign control rm -rf ~/Projects/x/build)

## VSC-367 — Project-level PreToolUse mitigation enforcing docs/zero-gap/guarded-commands.tsv until the upstream guard catches up

**Status:** Operator-blocked
**Type:** Task
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the only PreToolUse hook is the upstream constitution guard (tracked .claude/settings.json, matcher *), so every upstream gap (G-guard-gaps-01..06) is open on this project until a pin bump; the catalogue that names the gaps already exists as tracked data write a project hook (e.g. scripts/hooks/guard-project-catalogue.sh) that refuses (rc 2) any tool-call command matching a `refused` catalogue row's candidate ERE on the quote-scrubbed command, with --prove-failure and benign controls; register it; wire it as a SECOND PreToolUse hook entry (after the upstream one) — the settings.json edit is an operator decision

## VSC-368 — CONST-033 no-suspend scanner copied into 11 owned submodules with no paired failure proof

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: Add one paired proof to a canonical scripts/host-power-management/check-no-suspend-calls.sh and re-cascade the identical file to the 11 owned repositories, reconciling the 3 blob variants, then bump each gitlink WHY: The copies live in 11 separate submodule repositories; edits to submodule working trees are banned in this task and each gitlink bump is its own operator decision UNBLOCK: - [1] Operator authorises a cascade (cost: 11 commits in 11 repos plus up to 11 gitlink bumps; the canonical proof: planted systemctl suspend call expects rc 1, clean control rc 0, unreadable root rc 2)
- [2] Leave open (cost: the CONST-033 scanner stays unproven and its 3 blob variants stay divergent) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

scripts/host-power-management/check-no-suspend-calls.sh was cascaded (e.g. RAG 9900fec, 2026-04-27, 'add CONST-033 host-power-management guard') without a --prove-failure arm or sibling proof; 3 distinct blobs exist across the 11 copies (8ff46739 x7, d4aff5d1 x3, 4e9947e8 x1), so the copies have also diverged add a paired proof to one canonical copy (plant a systemctl suspend / loginctl / gsettings sleep call in a $TMPDIR copy, expect rc 1; clean control rc 0; unreadable root rc 2), then re-cascade the identical file + proof to all 11 repos and reconcile the 3 blob variants

## VSC-369 — CONST-050(B) anti-bluff challenge family (8 test types) cascaded into 8 owned submodules with no paired failure proofs

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: Define one proof convention for the CONST-050(B) challenge family (stub-target arm expects rc 1, unreachable target expects rc 2), apply it in each of the 8 owned modules and add a per-module check registry, then bump the gitlinks WHY: The challenges live in 8 submodule repositories; edits to submodule working trees are banned in this task and each gitlink bump is an operator decision UNBLOCK: - [1] Operator authorises the convention and per-module work (cost: commits in up to 8 repos, 8 gitlink bumps, a per-module registry each)
- [2] Leave open (cost: 8 challenge types per module remain unproven) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the CONST-050(B) submodule cascade (e.g. RAG e29009b, 2026-05-15) created chaos_failure_injection, ddos_health_flood, host_no_auto_suspend, no_suspend_calls, scaling_horizontal, stress_sustained_load, ui_terminal_interaction and ux_end_to_end_flow challenges per module without a proof-mode arm or sibling proof; 6 of the 8 names differ per module (per-module adaptations), 2 are near-identical define ONE proof convention for the family (a --prove-failure arm that points the challenge at a deliberately broken stub target and expects rc 1, plus an unreachable-target case expecting rc 2), apply it per module, register the challenges in each module (none carries a check registry)

## VSC-370 — LLMProvider-lineage shared challenges (apikeys discovery, suspend contract, upstreams recipe origin) have no failure proofs

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: Add --prove-failure arms to host_no_auto_suspend_contract, upstreams_recipe_origin and apikeys_live_discovery in LLMProvider, RAG and llm_provider (keeping identical copies identical), then bump the gitlinks WHY: The challenges live in three submodule repositories; edits to submodule working trees are banned in this task and each gitlink bump is an operator decision UNBLOCK: - [1] Operator authorises the work (cost: commits in 3 repos plus 3 gitlink bumps)
- [2] Leave open (cost: three shared challenges remain unproven) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

three challenges shared between the LLMProvider lineage repos (host_no_auto_suspend_contract and upstreams_recipe_origin byte-identical across LLMProvider/RAG; apikeys_live_discovery in LLMProvider and llm_provider with different blobs) were added without a proof arm add --prove-failure arms (planted contract break / foreign-origin recipe / fake key source) to each, keep identical copies identical

## VSC-371 — Per-module compile/functionality/unit challenge trio (RAG, security) has no failure proofs

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: Add proof arms and an executed-count floor to the compile, functionality and unit challenge trio in RAG and security, then bump the gitlinks WHY: The six challenges live in two submodule repositories; edits to submodule working trees are banned in this task and each gitlink bump is an operator decision UNBLOCK: - [1] Operator authorises the work (cost: commits in 2 repos plus 2 gitlink bumps; the count floor is what stops a repeat of the 116-of-143 false PASS)
- [2] Leave open (cost: this family keeps its demonstrated false-PASS risk) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the <module>_{compile,functionality,unit}_challenge.sh trio follows one template in both repos and none of the six carries a proof arm; RAG 13f4bac (2026-09-06) already recorded 'the unit gate tested 116 of 143 and called it a pass', i.e. this family has produced a false PASS before add proof arms per trio member (break the build / a functional assertion / a unit test in a disposable copy, expect rc 1) and an executed-count floor so a partial run cannot pass

## LMV-002 — llms_verifier local verify/validate/challenge scripts (12) have no failure proofs

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: In the llms_verifier repository triage its 12 verify/validate/challenge scripts (gate vs historical), add proof arms to the real gates, dedupe the two validate_implementation.sh copies, then bump the gitlink here WHY: The scripts live in the llms_verifier repository; edits to submodule working trees are banned in this task, retiring historical scripts needs a section 11.4.122 operator decision, and a gitlink bump is an operator decision UNBLOCK: - [1] Operator decides keep/retire for verify_day1_completion.sh and verify_providerinit_fix.sh, then proof arms are added in that repo and the gitlink bumped (cost: a triage decision plus one commit in that repo plus one umbrella commit)
- [2] Leave open (cost: 12 unproven scripts remain) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the module carries its own run_*_challenge.sh family (5), run_challenges.sh, verify-deployment.sh, security-audit.sh, verify_day1_completion.sh, verify_providerinit_fix.sh and two copies of validate_implementation.sh (root and tests/, different blobs) with no proof convention or registry triage first (which are gates vs one-shot historical scripts: verify_day1_completion / verify_providerinit_fix look historical — retire only via §11.4.122 operator decision), then add proof arms to the real gates and dedupe the two validate_implementation.sh copies

## WSP-168 — workshop: two gate-like scripts without failure proofs (private module; paths only)

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: In the workshop repository confirm whether pipeline/run_audit.sh is a verdict gate and a second gate-like script; add a proof arm or a reasoned class exemption there, then bump the workshop gitlink here WHY: Both scripts live only in the private workshop repository; this task bans edits to submodule working trees, and a gitlink bump is an operator decision UNBLOCK: - [1] Operator (or an agent in that repo) makes the per-script decision and bumps the gitlink (cost: one commit in a private repo plus one umbrella gitlink commit)
- [2] Leave open (cost: gate-like scripts stay unproven) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

two tracked scripts matching the gate-name heuristic carry no proof arm and no sibling proof; whether pipeline/run_audit.sh is a verdict gate at all is UNCONFIRMED (name-heuristic population; its only in-repo referrers are a doc and a Python helper, neither a proof) for each: confirm gate or not; gate => add proof arm + register in the workshop's own gate surface; not a gate => record why the heuristic should not flag it (class exemption with reason)

## AII-003 — ai_interviewing: two gate-like scripts without failure proofs (private module; paths only)

**Status:** Operator-blocked
**Type:** Bug
**Operator-Block-Details:** WHAT: Commit a --prove-failure arm for platform/qa/challenges/api-challenges.sh and scripts/validate-exports.sh inside the ai_interviewing repository, then bump the ai_interviewing gitlink here WHY: The files live only in the private ai_interviewing repository; this task bans edits to submodule working trees, and a gitlink bump is an operator decision UNBLOCK: - [1] Operator (or an agent in that repo) adds the proof arms and bumps the gitlink with: git -C ai_interviewing commit ... && git add ai_interviewing (cost: a commit and push in a private repo, plus one umbrella gitlink commit)
- [2] Leave open (cost: two gate-like scripts stay unproven; the unproven-checks class keeps reporting them) WHO: operator
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

platform/qa/challenges/api-challenges.sh and scripts/validate-exports.sh carry no proof arm and no sibling proof (validate-exports.sh is referenced only by build-all.sh and verify-standalone-clone.sh, which are not proofs) add --prove-failure arms (validate-exports: a deliberately corrupted export must fail; api-challenges: a stub server returning a wrong status must fail) and register them in the module's gate surface

## VSC-378 — Pre-push gates 1 (go test) and 6 (Playwright) cannot be inspected for vacuous passes; gate 1 has no zero-test refusal

**Status:** Queued
**Type:** Bug
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the class is a line-based shell analyser and reports both gates COULD-NOT-INSPECT; hand-read: gate_1 is `cd _tools/gen && go test ./...` with no executed-test count, and `go test` exits 0 for packages with no test files (standard toolchain behaviour; not re-run on this tree); gate_6's zero-case handling was not established gate_1: run `go test -json ./...` and refuse (rc 2) when the count of executed tests is 0; gate_6: assert the Playwright JSON reporter's executed count > 0; give the class a non-shell-gate rule for these two

## VSC-379 — No gate or registered check writes a sealed evidence record (8 pre-push gates, 59 checks, evidence store absent)

**Status:** Queued
**Type:** Feature
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

`git grep 'zero-gap-evidence.sh record'` finds only the recorder itself and the class; run_gate never calls it and no runner passes --check-id, so .remember/logs/zero-gap/evidence does not exist and every PASS in the tree is unsealed (FR-014/FR-016 promised, T065 planned) T065: seal every run_gate outcome (timestamp, fingerprints, seal) RED-first with a dry-run push and a documented revert plan; a runner/daily feed (T069) seals each registered check with its literal --check-id

## VSC-380 — Evidence anchor docs/zero-gap/anchor.json absent, so the strict chain verify returns rc 2

**Status:** Queued
**Type:** Feature
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the anchor is written per cycle freeze and daily; neither has run yet, so no tracked anchor exists and the forward-only history check has nothing to check write the first anchor at `gap freeze --cycle 1` (T038) through `continuum-integrity anchor write`, then daily (T069)

## AII-004 — ai_interviewing start and ingest scripts build the server only when the binary is absent: a restart runs a stale binary

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

both scripts guard the build with an existence test of the binary and no freshness test, so a source change after the first build is never compiled; build.sh:5 is a plain go build with no identity stamp. Precedent recorded in helix-deps.yaml (2026-09-17 entry): the deployed aicur was 9 days stale and lacked the auth middleware its source had port the workshop's build-freshness guard (workshop commit 185fb15, 'build-freshness guard (rebuild trap)') into ai_interviewing: rebuild when the binary's embedded source identity differs from HEAD or any tracked backend source is newer, or always run go build (incremental, cached); one shared helper used by start.sh and ingest.sh; commit inside ai_interviewing, return as a gitlink bump

## LMV-003 — LLMsVerifier scripts build their binaries only when absent (generator + provider challenge)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

`if [ ! -f/-x BIN ]` then go build, no freshness guard; the challenge harness then scores providers with a stale binary fix in vasic-digital/LLMsVerifier (always go build, or freshness test), return as a gitlink bump

## WSP-169 — workshop platform serves build 185fb15 while workshop HEAD is e076fa6: the stack was not redeployed after the last commit

**Status:** Operator-blocked
**Type:** Bug
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

container 42c12e533a91 started 2026-09-25T09:06:32Z serving source_commit 185fb158c4f4; e076fa6 was committed 10:18:12Z and nothing redeployed; scripts/qa-up.sh reuses a running stack without restarting it (header line 32). Measured: git diff --name-only 185fb158c4f4 e076fa6aa26f lists 3 *_test.go files only, so the production source is equal (identical binary output UNCONFIRMED) OPERATOR: redeploy the workshop stack from the committed tree (bash workshop/scripts/restart.sh, answering stays OFF by default). AGENT (follow-up): qa-up warns or refuses when it adopts a stack whose /api/health source_commit differs from workshop HEAD

## AII-005 — ai_interviewing's running build carries no source identity: the served binary cannot be tied to its source

**Status:** Operator-blocked
**Type:** Bug
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

ai_interviewing/platform/scripts/build.sh:5 is a plain go build with no identity stamp and the backend exposes no source_commit (0 Go files mention it, vs workshop's cmd/workshop-server/build_identity.go); the embedded vcs.revision 923779e06397 is an umbrella commit (git cat-file: commit in the umbrella, not an object in ai_interviewing). Why Go stamped the enclosing repository's revision: UNCONFIRMED port the workshop's build identity (ldflags stamp of the ai_interviewing commit and dirty flag, /api/health source_commit + source_dirty) into ai_interviewing; build with vcs stamping bound to the submodule; gitlink bump

## VSC-387 — two predefined-user passwords stated literally in the public spec 007 (15 lines, 5 files), pushed to the public remote

**Status:** Operator-blocked
**Type:** Bug
**Severity:** critical
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

a requirement line (FR-009) and its quickstart/plan/tasks/data-model copies state the two accounts' passwords in plain text; first committed ed9a34a (2026-09-12); present on github/origin/upstream main; repository visibility public (gh api). The same two values occur in 13 tracked ai_interviewing files and 15 tracked workshop files (git grep -l, values never printed). Whether they are the live credentials of the running platforms: UNCONFIRMED (no login was attempted) OPERATOR DECISION: rotate both accounts' passwords on every platform that accepts them (history cannot be rewritten, §11.4.113, so rotation is the only remedy for the published value); then AGENT: replace the literals in spec 007 with a reference to the seeded-credential source (env / untracked secret file), and move test fixtures to generated or env-provided values

## VSC-389 — content-boundary re-baseline decision: 14621 surviving gate rows over 121 public path classes await an operator choice (options 1-4 of the CLAUDE.md decision packet)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the gate detects co-occurrence (direction only for prose/short); judging a row requires reading private material, which is operator work; the packet's options: 1 do nothing (signal keeps growing), 2 allow-list classes B and C (hides rows from the next reader, pardons name rows with them), 3 teach the gate direction (SHIPPED 2026-09-09), 4 judge the surviving rows (largest cost, the only option that can find a new disclosure). The zero-gap class reads the gate's cache: on the live tree it reports rc 2 'cache stale: 71 enumerated file(s) differ' (measured 2026-09-26) until the one-time refresh (~34 min, ~760 MB) is re-run on a quiet tree operator picks an option (the packet recommends 4 over the surviving population, then 2 only for what survives); agent prepares per-group reading packets (paths, counts, private source by path) and runs the cache refresh on a frozen copy

## VSC-390 — content-boundary group A: spec trees in the public umbrella (specs/**)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

9268 surviving unjudged gate rows (2 name-class rows) under 22 path classes; private source by path: workshop 9246, monetization 22. Packet class A: text-level direction probe (2026-09-03) found about 4 in 5 rows outward and about 1 in 5 inward; the gate's direction subtraction has already removed provably public-first rows, so these are what survived it. no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## VSC-391 — content-boundary group B: public reusable modules (submodules/** except the constitution, design-toolkit)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

779 surviving unjudged gate rows (16 name-class rows) under 43 path classes; private source by path: workshop 744, ai_interviewing 35. Packet class B (public reusables extracted from the private tree); remedy lands in each module's own repo and returns as a gitlink bump. 16 of the 43 rows are name-class, so this group cannot be pardoned wholesale. no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## VSC-392 — content-boundary group C: governance prose in the umbrella (docs, scripts, carriers, manifests, allow files)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

1912 surviving unjudged gate rows (2 name-class rows) under 45 path classes; private source by path: workshop 1816 + monetization 122 + ai_interviewing 42 (sum over the group incl. -05 is 1980; this group alone 1912). Packet class C (governance prose that propagated outward, file-level sampled direction evidence). no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## CON-009 — content-boundary group C (upstream part): rows inside the constitution submodule

**Status:** Queued
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

68 surviving unjudged gate rows (0 name-class rows) under 6 path classes; private source by path: counted with group C. The constitution is upstream (data-model: third-party includes the governance source); this repository never commits into it (FR-021) — the reporting route is HelixDevelopment/HelixConstitution. no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## VSC-393 — content-boundary group E: rendered exports (PDF/HTML) of governance documents

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

1239 surviving unjudged gate rows (0 name-class rows) under 32 path classes; private source by path: workshop 1167, monetization 58, ai_interviewing 14. Exports carry the text of their Markdown source, so their judgement follows the source rows and the fix includes re-export. CONTINUATION.md itself carries no row while CONTINUATION.pdf carries 902: that the PDF export is older than the Markdown is UNCONFIRMED (not measured). no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## VSC-394 — content-boundary group S: public site content — one name-class row in each of 11 localized product page sets

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

11 surviving unjudged gate rows (11 name-class rows) under 11 path classes; private source by path: ai_interviewing 11. Every row is name-class and every row sits in content the production sites are generated from; the gate withholds the identifier. Read these first. no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## VSC-395 — content-boundary remainder: tooling, evidence and spec-kit files (.specify, _tools, _tests, _analysis, .ashlrcode, .claude, design-system)

**Status:** Operator-blocked
**Type:** Bug
**Severity:** high
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

1344 surviving unjudged gate rows (4 name-class rows) under 27 path classes; private source by path: monetization 1092, workshop 233, ai_interviewing 19. Packet 'remainder — genuinely unassessed' (no direction probe run on it). no row was judged; nothing here clears a row per the operator's option on G-content-boundary-rows-01: read and judge each row in this group (redact real disclosures in the public file, record a reasoned judgement for the rest); allow-listing is option 2 and hides the row

## VSC-396 — content-boundary gate left 137 files unindexed and 3 rows undetermined: those parts were never read

**Status:** Queued
**Type:** Task
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

the gate skips files over its size cap or machine-generated (counts.not_indexed=137) and emits 3 undetermined rows; the class registers surviving rows only, so these parts are COULD-NOT-INSPECT, never clean list the 137 files by path class; decide per class whether to index (raise the cap, chunk) or declare them out of population with a recorded reason

## VSC-397 — T086: rotate the milosvasic and <participant-handle> account passwords exposed in public specs/007 (workshop + ai_interviewing)

**Status:** Operator-blocked
**Type:** Task
**Severity:** high
**Created-By:** AI
**Assigned-To:** operator

Rotate the passwords of the two predefined accounts milosvasic (admin) and <participant-handle> (user) in BOTH modules (workshop, ai_interviewing). Their plaintext values were committed in the public specs/007-decouple-modules-auth/ tree (first public in ed9a34a, per VSC-387) and remain in git history; once a credential reaches public history rotation is the only remedy (section 11.4.10). Values are referenced by account name only and are not recorded here.

## VSC-398 — Playwright firefox and webkit browser binaries are absent: harness preflight reports CANNOT DETERMINE (rc 2), gate 6 cannot run

**Status:** Operator-blocked
**Type:** Bug
**Severity:** medium
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

System libraries libmanette-0.2-0 and libwoff1 and tesseract are now installed, but the Playwright 1.61 cache holds only chromium; firefox-1532 and webkit-2311 executables do not exist, so _tests/preflight.js exits 2 and the cross-browser suite cannot honestly run

## PSG-007 — passage: Registry.WriteJSONL, SymbolAliasStore.WriteJSONL and the Sync anchor write-back rewrite files in place (os.WriteFile), so a stopped or failing writer leaves a short registry

**Status:** Queued
**Type:** Bug
**Severity:** low
**Created-By:** AI
**Assigned-To:** zero-gap-sweep

os.WriteFile truncates then writes. A writer stopped between the truncate and the last byte (the workshop ingest wrapper TERMs ingest-transcript when an operator stops a run) or failing with ENOSPC/EFBIG leaves a SHORT passages.jsonl that is still valid JSONL and is accepted by every reader. Found by independent review rev5-w2 (finding 3). A consumer cannot fix this without committing into the public passage module, so the change is REPORTED, not made: a ready patch (temp file in the same directory, mode and owner kept, fsync, rename; tests incl. an RLIMIT_FSIZE failure injection) is at ~/.cache/agent-scratch/wl-lows/passage-atomic-write.diff against base 1e361bd6d6fa; RED TestRegistryWriteJSONLIsAtomic on the base, GREEN go test ./... with the patch (measured 2026-10-15). The evidence path is the defect's own source file.

## WSP-170 — answering gate FAIL: recall 27.5% vs 40%, fabrication 2.0-6.2% vs 2% (DeepSeek focus, 2026-10-26 pass); SC-010 unmet

**Status:** Queued
**Type:** Task
**Severity:** medium

Evidence owed before answering waivers WVR-2026-10-27-deepseek-qa (expires 2026-11-26) and WVR-2026-10-28-deepseek-qa-llm (expires 2026-11-27) lapse: see workshop docs/work-items/WSP-170.md. Row created 2026-10-29 at hand-off; id 170 matches the waiver roster tracked_item.

## WSP-176 — workshop admin password is operator-held: student-surface gate checks C05 C13 C14 C15 stay UNDETERMINED

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator supplies the workshop admin password for the four admin-only gate checks, or decides how they are run WHY: The password is held only by the operator and must never be printed, logged or committed; no agent can run C05, C13, C14, C15 without it. UNBLOCK: - [1] Operator exports the admin password in the shell environment for one gate run and an agent runs the student-surface gate (cost: secret handling, value never written to disk)
- [2] Operator runs the four checks personally and pastes the verdict lines (cost: operator time)
- [3] Accept the four checks as UNDETERMINED in the release record (cost: admin-only surfaces stay unverified) WHO: operator
**Severity:** high

On the 0.0.7 release build 5641ea85 the student-surface gate reports 35 pass, 0 fail, 4 UNDETERMINED; the four checks C05, C13, C14, C15 need the admin password, which only the operator holds. Undetermined is not a pass. Source docs/releases/0.0.7.md.

## VSC-403 — claude_toolkit GitHub release v1.34.0 not created: PAT lacks Contents write on vasic-digital/claude_toolkit

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator raises the PAT scope or creates the GitHub release for v1.34.0 WHY: The token authenticates but returns HTTP 403 on release creation; only the token owner can change its repository permissions. UNBLOCK: - [1] Operator grants Contents: write on vasic-digital/claude_toolkit to the PAT, then an agent runs gh release create v1.34.0 (cost: broader token scope)
- [2] Operator creates the release by hand in the GitHub UI from tag v1.34.0 (cost: operator time)
- [3] Leave only the GitLab release (cost: GitHub shows a tag without release notes) WHO: operator
**Severity:** medium

The GITHUB_TOKEN in the operator key file authenticates but gets HTTP 403 Resource not accessible by personal access token when creating a release. Tag v1.34.0 exists on all four remotes and the GitLab release exists. Source CONTINUATION.md final state section.

## DOC-001 — doc_processor main on the helixdevelopment_github mirror has one commit this checkout lacks (125 ahead, 1 behind)

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator decides how to integrate the one mirror commit that doc_processor main lacks WHY: Local main is 125 ahead and 1 behind the helixdevelopment_github mirror; force is forbidden so only a merge onto latest main and fast-forward push can reconcile it. UNBLOCK: - [1] Agent fetches the mirror commit, inspects it, merges it onto local main and pushes fast-forward to every upstream (cost: possible merge conflicts, review time)
- [2] Operator confirms the mirror commit is unwanted and leaves it unmerged (cost: mirror stays diverged)
- [3] Leave open (cost: divergence stays recorded and unresolved) WHO: operator
**Severity:** medium

The local main and the mirror main are diverged: 125 commits ahead and 1 behind. Nothing was touched. Fast-forward only policy forbids force; an integration decision is needed. Source CONTINUATION.md final state section.

## VSC-404 — GitHub default branch is master for LLMOrchestrator and VisionEngine while main is the working branch

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator changes the GitHub default branch of LLMOrchestrator and VisionEngine from master to main WHY: Default branch is a provider-side repository setting that only an owner can change; main already carries the same history. UNBLOCK: - [1] Operator sets the default branch to main in each repository setting (cost: open pull requests retargeted, clones track master)
- [2] Agent does it through gh api with an owner-scoped token (cost: token scope for repository administration)
- [3] Keep master as default (cost: the default branch differs from the working branch) WHO: operator
**Severity:** low

llm_orchestrator and vision_engine had main fast-forwarded to master on origin, HelixDevelopment and GitLab; the GitHub default branch setting still names master and is a provider-side setting changeable only by the operator. Source CONTINUATION.md.

## VSC-405 — helix_code constitution pin is 116 commits behind (separate repository, another session)

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator or the helix_code session moves the helix_code constitution pin forward WHY: helix_code is a separate repository owned by another session and a 116 commit pin move is its own operator-authorized change. UNBLOCK: - [1] The helix_code session fast-forwards its pin under the standing fast-forward authorization (cost: re-measure Constitution.md and re-run its gates)
- [2] Operator authorizes this session to do it in that repository (cost: cross-repository change)
- [3] Leave behind (cost: helix_code keeps stale constitution rules) WHO: operator
**Severity:** medium

The helix_code repository pins an older constitution commit, 116 behind. It is a separate repository handled by another session; moving its pin is an operator decision there. Source CONTINUATION.md final state section.

## VSC-406 — 4 phantom @anthropics plugin keys in the claude1 alias settings

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator decides whether the 4 phantom @anthropics plugin keys are removed from claude1 settings WHY: The keys live in operator-owned alias settings; removing them is a configuration edit not made without consent. UNBLOCK: - [1] Operator authorizes removal of the four keys with a backup of the settings file (cost: edit to alias config)
- [2] Operator removes them by hand (cost: operator time)
- [3] Leave them (cost: plugin load warnings persist) WHO: operator
**Severity:** low

Four enabled-plugin keys under the claude1 alias refer to plugins that do not resolve in any marketplace. Removing them edits operator-owned alias settings. Source CONTINUATION.md final state section.

## WSP-177 — Yandex Disk upload of materials and workshop-storage verify --deep still pending

**Status:** Queued
**Type:** Task
**Severity:** medium

The materials upload to Yandex Disk was running at about 40 to 90 KB per second and is not complete; workshop-storage verify --deep has not been run and pushes used the storage offline reason. Nothing has been untracked. Source CONTINUATION.md 2026-10-27 and 2026-10-29 sections.

## CON-011 — nested checkouts inside submodules/constitution are half-materialized: empty worktrees, staged deletions, gitlink drift

**Status:** Operator-blocked
**Type:** Task
**Operator-Block-Details:** WHAT: Operator authorizes restoration of the half-materialized nested checkouts inside submodules/constitution WHY: Restore needs git restore or reset --hard, which the PreToolUse guard blocks, and deletions may be staged intentionally. UNBLOCK: - [1] Operator authorizes a guarded restore of the nested worktrees after a cp -p style backup of their state (cost: discards staged deletions)
- [2] Move the nested directories aside and re-clone them fresh at their pinned commits (cost: disk and time, nothing discarded)
- [3] Leave as is (cost: gitlink drift and empty worktrees stay, verify gates may report them) WHO: operator
**Severity:** medium

git status in the umbrella shows submodules/constitution modified and nested submodule checkouts with empty worktrees and staged deletions. Restoring needs git restore or reset --hard, which the project guard blocks. No restore was attempted.

## VSC-407 — claude_toolkit full test suite stopped at file 42 of 145: test_jev_detect_https_mutation.sh runs for hours

**Status:** Queued
**Type:** Task
**Severity:** medium

The toolkit full suite was stopped at file 42 of 145 because test_jev_detect_https_mutation.sh takes hours. Files 43 to 145 were not run for v1.34.0; the release rests on the files that ran. Source CONTINUATION.md.

