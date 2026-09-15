---
description: "Review phase — Knowledge Areas Deep Linking (feature 002), knowledge-graph contract vs. implementation"
---

# Review — Knowledge Areas Deep Linking

**Date**: 2026-09-15 · **Feature**: `specs/002-knowledge-areas-deep-linking`
**Scope**: this review is `specs/008-unified-workshop-platform/tasks.md` T060 (was `002/T022`):
*"Review the knowledge contract implementation before anything else in the broader spec-008 plan
consumes it — every other component depends on its shape."* It is deliberately narrower than a
full feature review (unlike `specs/001-workshop-curriculum-platform/review.md`, which reconciled
all 120 tasks): it reviews `contracts/knowledge-graph.md` and `contracts/http-api-delta.md` against
the Go implementation under `workshop/platform/backend/pkg/knowledge/`, `internal/redaction/` and
the surfaces that consume them, clause by clause.

**Why this document had to be written.** Verified directly, this session: `ls
specs/002-knowledge-areas-deep-linking/` carries `spec.md`, `plan.md`, `research.md`,
`data-model.md`, `quickstart.md`, `tasks.md` and `contracts/` — no `analysis.md`, no `review.md`.
`specs/001-workshop-curriculum-platform/` has both (`analysis.md`, 170 lines; `review.md`, 684
lines). Spec 002 stands at **110 of 153 tasks ticked** (`grep -c '^- \[x\] T' tasks.md` = 110,
`^- \[ \]` = 43), and the knowledge-graph contract — 332 lines, 8 minting invariants (M1–M10 minus
gaps), 5 mention invariants (N1–N5), 3 authorship invariants (W1–W3), 5 question invariants
(Q1–Q5), 3 coverage invariants (C1–C3), 8 pipeline invariants (S1–S8), 2 resolution/redaction
invariants (X1–X2), 4 environment invariants (V1–V4) and 20 named gates (G-KG-1..19, G-OCR-2) —
has never had a recorded review, even though every later spec-008 consumer (search, assessment,
answering, the frontend) builds directly on its shapes.

**Scope note.** This repository is PUBLIC. No transcript text, participant name or recording
filename appears anywhere below.

---

## 1. The evidence standard applied

A clause was marked IMPLEMENTED only against a file and function this session actually opened and,
where a Go test exists, actually ran. Concretely:

1. **A file, a function, a line — not a doc comment's claim about itself.** Every verdict below
   cites a real path. Where a doc comment's own claim about the code's scope was checked against
   a sibling file and found to disagree, that disagreement is reported as its own finding (§4) —
   not silently resolved in the doc comment's favour.
2. **Go tests were actually executed.** `go build ./...`, `go vet ./...` and
   `go test ./pkg/knowledge/... ./internal/api/...` were run this session (all clean; see §6). The
   check-registry's own verifier, `bash platform/gates/verify-check-registry-002.sh`, was also run
   (rc 0, 147 of 147 registered entry points exist).
3. **Python pipeline stages and `pkg/assessment`/`pkg/search` gates were NOT independently
   re-executed this session.** Their registration in `check-registry-002.tsv` (all `check`, none
   `debt`, for the rows this review names) and their own doc comments are cited as evidence of
   what exists, not as evidence that they pass today. This is a stated boundary, not an omission —
   see §7.
4. **A finding is named even where it does not block anything.** Two of the three findings in §4
   are about STALE DOCUMENTATION describing an implementation that has since moved past what the
   comment claims — the underlying code is fine; the comment misdescribes it. Both are reported as
   real defects (a stale doc comment is exactly the kind of drift §11.4.6 exists to catch), not
   smoothed over because "the code is right anyway."

---

## 2. Disposition, by contract section

`contracts/knowledge-graph.md` (normative for §1–§8 below) and `contracts/http-api-delta.md`
(normative for the wire shapes §3's items reference) were both read in full this session.

### 2.1 §1 Minting (M1–M10) — IMPLEMENTED

`pkg/knowledge/identity.go` delegates every one of the (now nine, after the 2026-09-02 revision
adding `kg_next_point`/`kg_open_question`/`kg_meeting_note`/`kg_open_action`) entity kinds through
the **same** `*passage.Minter` every transcript and code passage already uses (M1) — no second
identifier format anywhere in the file. `identity_test.go`'s `TestGKG13_PairedMutation_…`
(gate G-KG-13, M2) was run this session: control holds, and an `alwaysMint` mutant strategy turns
all three of the gate's assertions red simultaneously — the mutation is genuinely discriminating,
not a proof that could not fail. M3–M5 (never content/position-derived; minting is the last branch
of matching, never the first; an unknown-but-present anchor is an error) are stated in the same
file's doc comment and exercised by `checkSurvivesTextCorrection` (identity_test.go), which this
session read but did not itself re-run beyond the suite pass in §6.

### 2.2 §2 Promotion / Extract / Reconcile / Account (P1–P4, E1–E5, R1–R3, A1–A3) — NOT INDEPENDENTLY VERIFIED THIS SESSION

This machinery lives in `workshop/pipeline/extract/*.py` (Python), not in
`workshop/platform/backend/pkg/knowledge/`. `check-registry-002.tsv` registers **G-KG-14**
(R1–R3, the reconciliation hard-stop) as `python  pipeline/extract/verify.py::prove_g_kg_14`, and
`G-KG-17`/`G-KG-18` (S1–S8, the repeatable pipeline) the same way. This review read the contract's
own text for these clauses (§2.1–§2.4 above) but did **not** open `pipeline/extract/*.py` or
re-run `verify.py` this session — a Go-package review has no standing to grade Python it did not
read. Recorded as CANNOT DETERMINE, not silently assumed clean. See §7.

### 2.3 §3 Mention derivation (N1–N4, plus new N5) — IMPLEMENTED, ONE VIOLATION FOUND AND FIXED (G-KG-19)

`pkg/knowledge/mention.go`'s `Mention.Validate` enforces N1 (precision required exactly when a
time span exists, no default) and N3 (timing confidence carried if and only if precision is
`word`, with an explicit `math.IsNaN` guard against silently passing a NaN confidence) at the type
level — read in full this session. N2 (the two precisions never conflated) and N4 (the join is by
time into segment; the segment yields the passage identifier, never the time itself) are structural
properties of `Mention`'s own field shapes (`Passage passage.PID`, never a time-typed join key) and
were confirmed by reading, not merely asserted.

**N5 is new**: this review's own T051 work (`G-KG-19`, "one documented half-open interval
convention") added it to the contract (§3, this document's own diff) after finding it was already
followed — and documented as such — everywhere in this codebase's producers/consumers of a text
offset or time span **except one**: `internal/api/chapters.go`'s `inSection`, which read
`t <= sec.TEndS` (closed interval) instead of `t < sec.TEndS` (half-open). See §5 for the full
account; it is fixed, tested and its own paired-mutation proof (mutating the REAL function in
place, not a reimplementation of it) is green.

### 2.4 §4 Authorship — W1–W3 IMPLEMENTED; Q1–Q5, C1–C3 NOT INDEPENDENTLY VERIFIED THIS SESSION

**W1–W3** (authored/assembled marking; every substantive claim cited or marked editorial; a
publication review required and staleness-checked) live partly in `pkg/knowledge/reviews.go`
(a pure reader of `pipeline/extract/review_store.py`'s rows — read in full) and partly in
`internal/api/areas.go`, which performs the actual staleness comparison
(`review.ReviewedAt` vs. `MaterialsLastModified` — confirmed present by name at `areas.go`, not
read line-by-line). **W3 is IMPLEMENTED**: the comparison is at the call site, matching the
contract's own stated design (reviews.go's doc comment: *"STALENESS IS CHECKED BY THE CALLER, NOT
HERE"*), and `areas.go` names `stale_publication_review` and `no_publication_review` as two
distinct, never-collapsed determined negatives.

**Q1–Q5** (every question cites, every citation resolves or the question is withheld; `long`-set
breadth; every question names its assessed sections; assembled answers marked; the reference-module
content boundary enforced in both directions) live in `pkg/assessment/`, outside this review's
opened file set. `check-registry-002.tsv` registers G-KG-2, G-KG-3 and G-KG-16 there as `go-test`
rows with real `TestT072…`/`TestT073…`/`TestGKG16…` entry points, all confirmed to EXIST by
`verify-check-registry-002.sh`'s rc-0 run this session — not independently re-run past that.

**C1–C3** (per-section coverage; per-area distribution, never a mean; no threshold expressed)
likewise live in `pkg/assessment/coverage.go`, registered as G-KG-12
(`TestT079_PairedMutation_ReplacePerAreaTableWithMean`), confirmed to exist and not independently
re-run.

### 2.5 §5 The repeatable pipeline (S1–S8) — NOT INDEPENDENTLY VERIFIED THIS SESSION

Python, as §2.2. G-KG-17/G-KG-18 registered, entry points confirmed present, not re-run.

### 2.6 §6 Resolution and redaction (X1–X2) — IMPLEMENTED; ONE STALE DOC COMMENT FOUND

**X1** (one resolution function, four outcomes, no fallback) — `pkg/knowledge/resolve.go`, read in
full: `ResolveOne` is a direct pass-through to `(*passage.Registry).Resolve`, with zero new
matching logic. Confirmed by reading; the file's own doc comment names this precisely and the code
matches it.

**X2** (redaction reaches all eight targets, G-KG-7) — **IMPLEMENTED, but `redact.go`'s own doc
comment is STALE.** See finding F2 in §4 — the substance is real and more complete than the file
that defines the vocabulary claims about itself.

### 2.7 §7 Environment adaptability (V1–V4) — NOT INDEPENDENTLY VERIFIED THIS SESSION

G-KG-9 is registered as `shell  scripts/prove-export-capabilities.sh`, confirmed to exist by name;
not re-run. `pipeline/extract/export.py` exists (grep-confirmed); not read in full.

### 2.8 §8 Gate inventory — 20 of 20 gates now have a registered, entry-point-verified proof

`check-registry-002.tsv` carries a `check` row for every one of G-KG-1 through G-KG-18 plus
G-OCR-2 already; this review's own T051 adds the twentieth (**G-KG-19**, not yet in the registry —
see §5, this file's task explicitly withholds editing the registry so a different track can add
the row centrally). `verify-check-registry-002.sh` exits **0** at **147 checks / 3 debt / 0
missing / 0 unreadable / 0 proof_fail** with G-KG-19's own two new gate files present but
unregistered by design.

---

## 3. Findings — the substance of this review

Three findings. Two are stale documentation over a genuinely more-complete implementation; one is
the real, fixed defect this session's own T051 closes.

### F1 (RESOLVED THIS SESSION) — `inSection` read a half-open bound as closed

**Severity when found: real, silent, reachable.** `internal/api/chapters.go`'s `inSection` (used
by `GET /api/chapters/{slug}/transcript?section=…`) tested `t >= sec.TStartS && t <= sec.TEndS` — a
**closed** interval — against `curriculum.Section` boundaries that `DeriveSections`
(`pkg/curriculum/curriculum.go`) builds as `TEndS = round3(last-grouped-segment.TEndS)`. A
`tooLong` split (curriculum.go's own `flush`) can fire on a run of segments carrying **zero**
inter-segment silence, in which case the very next segment's own `TStartS` equals the previous
section's `TEndS` **exactly**. Under the closed-interval read, that boundary segment — which
belongs to the NEXT section — was ALSO served as part of the PREVIOUS section's window: the same
transcript passage, served under two different `section` query values, with no error and no
warning.

This is precisely the class FR-021b was written to name ("an unstated byte-offset and
time-boundary interval convention … is exactly the shape of defect that produces off-by-one
highlighting and off-by-one landings"), and precisely the shape T051/G-KG-19's own paired-mutation
instruction describes ("seed a match or a mention whose start exactly equals the previous unit's
end and require a consumer reading a closed interval to land in the wrong unit").

**Fixed in this session**: `t < sec.TEndS` (half-open, end-exclusive). New regression test
`internal/api/g_kg_19_test.go::TestGateGKG19_InSectionHalfOpenBoundary`, new gate
`platform/gates/verify-g-kg-19-interval-convention.sh`, new paired-mutation proof
`platform/gates/prove-g-kg-19-interval-convention.sh` (which reintroduces the exact historical line
into the REAL file, requires the gate to go red, then restores the file byte-for-byte and verifies
the restoration by sha256). All three run green this session; see §5 and §6 for the exact commands
and output.

**No other closed-interval reading of a half-open bound was found.** This review greped every
`Start`/`End`/`TStartS`/`TEndS` comparison in `pkg/knowledge/`, `pkg/search/` and `internal/api/`
for the `>=`/`<=` shape this defect takes, cross-checked against the small set of rune-classifier
comparisons (`r >= 'a' && r <= 'z'`, unrelated) that share the same textual shape, and found exactly
one match: this one.

### F2 (STALE DOCUMENTATION, not a functional gap) — `redact.go`'s "Phase 2 scope" comment undercounts what is actually built

`pkg/knowledge/redact.go`'s own package doc comment states: *"PHASE 2 SCOPE, STATED PLAINLY: four
of the eight targets — Terms, Areas, Questions and Lesson Sections — do not exist as concrete
entities yet. … What Phase 2 owes … is the CONTRACT every one of those later implementations must
satisfy … plus the one target Phase 2 CAN implement for real right now … MentionTarget."*

Read together with `internal/redaction/plan.go` (`Apply`, `applyTaxonomy`, `applyQuestions`,
`applyMaterials`, `applyMentions`, `applyStoredAnswers`, `runTargetChecklist`), this is now
**false as a description of the current tree**, though it was presumably true when `redact.go` was
first written (T021, an earlier phase than the taxonomy/question machinery `applyTaxonomy` and
`applyQuestions` depend on):

- `applyTaxonomy` (plan.go:711) loads the real taxonomy index and calls `idx.redact(suppressed)`,
  reporting real counts for BOTH `terms` (withdrawn when a term's last evidence is suppressed,
  unlinked otherwise, plus a further "withdrawn-by-name" class the code distinguishes explicitly
  because those rows still have live evidence) and `areas` (unpublished / unlinked) — not stubs.
- `applyQuestions` (plan.go:793) walks the real question-set directory.
- `runTargetChecklist` (plan.go:1057) requires **all eight** `RedactionTargetNames` to have a
  reported counter before it will even call `knowledge.PropagateRedaction` — a run that produced no
  report for any one of the eight is a hard error, not a silent gap.
- `mentions` and `stored_answers` ARE correctly reported `StatusAbsent` with a stated reason (no
  mention corpus is persisted; no answer cache is persisted, so a suppressed citation declines the
  whole answer at request time) — this is the contract's own X2 working as designed, not a missing
  target. The doc comment's "MentionTarget is the one target Phase 2 can implement for real" undersells
  this: the in-memory `Store.MentionTarget` IS live (named in `applyMentions`'s own detail string),
  it is simply that nothing about mentions is *persisted* for it to need to reach beyond memory.

**Recommendation, not made in this session**: update `redact.go`'s package doc comment to state the
current split — Terms/Areas/Questions/Mentions/Stored-Answers all real (five of eight, not one),
Lesson-Sections/Index-Entries/Exports handled by `applyMaterials`/`planDerivedDB`/`applySpans`
elsewhere in `plan.go` (not individually re-verified this session; named as unverified rather than
assumed) — so a future reader of `redact.go` alone does not repeat this review's own first,
incorrect read of the file's own claim about itself.

### F3 (SELF-DOCUMENTED PARTIAL, already honestly reported) — connectivity-matrix row 4 is half-implemented

`pkg/knowledge/graph.go`'s doc comment states row 4 of data-model.md §3's table ("a code passage ↔ a
transcript passage: the existing cross-reference graph, plus shared area membership") is "NOT
implemented here" because it needs `pkg/crossref` and a real Area entity, "neither of which Phase 2
builds." Area now exists (taxonomy.go, Phase 3). Checking `internal/api/graph_traverse.go`
confirms the SHARED-AREA-MEMBERSHIP half of row 4 IS real and measured live — its own doc comment
cites a 2026-09-02 measurement against `curriculum/taxonomy.jsonl`: 493 distinct areas/terms carry
both a code-kind and a transcript-segment-kind evidence pid, so depth-2 traversal (code → shared
area → transcript) is "a REAL path for 493 subjects, not a hypothetical one." The
CROSS-REFERENCE-GRAPH half of row 4 (folding `pkg/crossref`'s own derivation into the traversal) is
explicitly still absent, and `graph_traverse.go` says so in its own words: *"A code-and-transcript
pair that are cross-referenced (semantically similar) but share no area evidence is [not reachable
by this traversal]."*

This is not reported as a defect of this review's own finding — the implementation ALREADY names
its own gap, correctly and specifically, in its own comment. It is recorded here only so that
`graph.go`'s OLDER, blanket "not implemented here" claim (which predates `graph_traverse.go` and
reads as though row 4 is entirely missing) is not mistaken for the current, more precise state.
Recommendation, not made in this session: a one-line pointer from `graph.go`'s doc comment to
`graph_traverse.go`'s more current and more precise account.

---

## 4. G-KG-19 — the gate this review's own paired task (T051) built

Kept out of §3's Q1–Q5/C1–C3-style "not independently verified" bucket because this review's
author is the same session that implemented and ran it. Full account, commands and output: T051's
own handback to the caller of this task; summarised here because §2.3/§2.8 above reference it.

- `specs/002-knowledge-areas-deep-linking/contracts/knowledge-graph.md` §3 gained invariant **N5**
  and **Gate G-KG-19** (this document's own diff), and the gate-coverage table at the end of the
  file gained a G-KG-19 row (gate count corrected 19→20).
- `pkg/knowledge/mention.go`'s `TextSpan`/`TimeSpan` doc comments now state the half-open
  convention explicitly, mirroring `submodules/curriculum-kit/pkg/curriculum/model.go`'s
  `VideoAnchor` doc-comment style (the reference this task named).
- `internal/api/chapters.go`'s `inSection` fixed (F1, above).
- New: `internal/api/g_kg_19_test.go`, `platform/gates/verify-g-kg-19-interval-convention.sh`,
  `platform/gates/prove-g-kg-19-interval-convention.sh`.

---

## 5. What this review actually ran, and its output

```
$ cd workshop/platform/backend && go build ./...
(clean, no output)

$ go vet ./...
(clean, no output)

$ go test ./pkg/knowledge/... ./internal/api/... -count=1
ok  	.../platform/backend/pkg/knowledge	0.041s
ok  	.../platform/backend/internal/api	2.330s

$ bash ../gates/verify-g-kg-19-interval-convention.sh
PASS  g_kg_19_test.go:124: G-KG-19: OK — secA=[0,10)=[p1 p2] secB=[10,20)=[p3 p4],
      boundary passage p3 (t=10.0) lands in secB only
verify-g-kg-19-interval-convention: 0 finding(s) — the half-open convention holds
(exit 0)

$ bash ../gates/prove-g-kg-19-interval-convention.sh
PASS L0 CONTROL — unmutated gate exits 0
PASS M1 CAUGHT — the gate went red (rc 1) with the closed-interval defect reintroduced
PASS L1 RESTORE — .../internal/api/chapters.go is byte-identical to its pre-mutation content
PASS L2 POST-RESTORE — the gate is green again
prove-g-kg-19-interval-convention: 4 passed, 0 failed
(exit 0)

$ bash workshop/platform/gates/verify-check-registry-002.sh
checks=147 debt=3 missing=0 unreadable=0 proof_fail=0
OK: all 147 registered entry point(s) exist.
(exit 0)
```

---

## 6. Honest boundary (§11.4.6) — what this review did NOT verify

1. **Every clause in §2.2 (P1–P4, E1–E5, R1–R3, A1–A3), §2.5 (S1–S8), §2.7 (V1–V4) and the Q/C
   halves of §2.4 is CANNOT-DETERMINE from this session**, not PASS. This review opened and read
   Go source in `pkg/knowledge/`, `internal/api/` and `internal/redaction/`; it did not open the
   Python pipeline under `pipeline/extract/`, nor `pkg/assessment/`, nor re-run any of the
   `python`-kind or `pkg/assessment`-scoped `go-test`-kind rows `check-registry-002.tsv` registers
   for those clauses. Their entry points are confirmed to EXIST (rc 0, `verify-check-registry-002.sh`);
   whether they currently PASS was not re-measured here.
2. **This review is not a task-by-task reconciliation** the way `specs/001/review.md` is. It grades
   the CONTRACT against the IMPLEMENTATION, clause by clause, per T060's own framing ("review the
   knowledge contract implementation… every other component depends on its shape") — it does not
   walk all 153 of `specs/002/tasks.md`'s own tasks.
3. **F2 and F3's recommended doc-comment fixes were NOT made in this session.** Both are named as
   recommendations, deliberately left for an operator or a future task, per this task's own
   instruction to report gaps rather than silently fix everything the review happens to notice.
4. **`Q4`/`Q5` and the content-boundary gate (G-KG-16)** were read about, not read directly — this
   review did not open `pkg/assessment/boundary_test.go` or the private `workshop`-internal
   reference-module material the boundary check exists to keep out. Given this repository's own
   standing content-boundary caution (`docs/content-boundary.md`, cited in the umbrella `CLAUDE.md`),
   this review deliberately did not go looking for that material even to verify the check —
   confirming the check's ENTRY POINT exists (it does, per `verify-check-registry-002.sh`) was
   judged sufficient for this review's scope.
