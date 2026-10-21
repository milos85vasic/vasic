# Implementation Plan: Research Gap Closure

**Branch**: `027-research-gap-closure` (none created) | **Date**: 2026-10-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/027-research-gap-closure/spec.md`

## Summary

One umbrella-repo deliverable (a research-register check, a tooling register and a drift report) and a set of workshop-repo deliverables (a repeat-attempt policy flag, an admin report and an item-parameter export that sit on spec 013's detector and shadow fit, a scanned-PDF/table/self-report extension of the textbook extractor, a draft-outline generator, an evidence-gated format view, and seven quality gates). Everything that needs a fact only the operator or the client holds is a NEEDS-OPERATOR entry with a recommended default and a task that stays unstarted until it is answered.

## Technical Context

**Languages**: Go 1.26 (workshop backend), Python 3 (pipeline), bash (gates and umbrella scripts), TypeScript/Angular (one notice component, hook-line only).
**Primary dependencies**: none new by default. Any new library (a property-test library, a spell checker) passes a §11.4.270 dependency verdict first; the in-repo alternative is the default.
**Storage**: reads the existing append-only response log (spec 013) without a schema change; writes only operator-side files (fit report, draft outlines, gate evidence). Nothing writes the registry or `curriculum/learning/`.
**Testing**: RED first on the broken artifact, paired mutation for every gate, three-valued exits, golden fixtures generated at test time (no private text).
**Constraints**: OR-04 token rule (no model over recordings, transcripts or textbooks) and D-06; content boundary (public repo, private `workshop`); single-writer files per spec 026 (corrected rule 2); never run lifecycle commands against the live stack from a worktree.
**Scale**: the live registry holds 36,492 rows including 1,675 `textbook_section` rows (`docs/OPERATOR-DECISIONS-2026-10-21.md` DC-01); the practice bank holds 292 questions (D-07).

## Constitution Check

| Rule | Status | Note |
|---|---|---|
| §11.4 anti-bluff | PASS (design) | Every gate has a paired mutation and an rc-2 branch; reference-dependent checks report UNDETERMINED, never zero |
| §11.4.6 no guessing | PASS | Unverified items are marked UNCONFIRMED in `research.md`; operator-only facts are NEEDS-OPERATOR entries |
| §11.4.122 no silent removal | PASS | The doc fixes this feature applied to specs 011-026 are append-only annotations marked "Reconciled by 027" |
| §11.4.142 independent review | PENDING | T007, T070 |
| §11.4.224 test-first | PASS (design) | Each BUILD task starts with RED |
| §11.4.270 dependency verdict | PENDING | Required before any new library (T060, T057) |
| §11.4.156 no CI | PASS | Gates run locally and register in `scripts/check-registry.tsv` |
| Content boundary | PASS | Paths, counts, line numbers; no private text |

## Project Structure

```text
specs/027-research-gap-closure/
  spec.md  plan.md  research.md  tasks.md
  contracts/requirement-register.md   # RG-01..RG-48, machine-checked
  contracts/tooling-decisions.md      # 33 rows, seeds docs/tooling/TOOLING-REGISTER.md
  checklists/requirements.md

umbrella:
  scripts/verify-research-register.sh      # NEW  (+ --prove-failure, check-registry row)
  scripts/report-tooling-drift.sh          # NEW
  scripts/lib/wrap-third-party-gate.sh     # NEW
  docs/tooling/TOOLING-REGISTER.md         # NEW

workshop (private; one branch + worktree per stream):
  (no new package for detection or the 2PL fit: 013 T050-T053 on branch n1-013-adaptive own pkg/scoring/gaming.go and irt.go)
  policy flag + admin report + item_irt export: patches to 013-owned files delivered to the 013 stream after n1-013-adaptive merges
  pipeline/pdf_textbook_sections.py        # OCR opt-in path, table notice (single PDF implementation, 026 D8)
  pipeline/textbook_draft_outline.py       # NEW
  platform/gates/verify-{quiz-bank,transcript-wer,token-usage}.sh + prove-*.sh   # NEW
  platform/frontend/src/app/features/{textbooks,practice}/   # notice components, hook-line edits only
```

## Hot-spot ownership (per spec 026 plan, rule 2 as corrected by 027)

`cmd/workshop-server/main.go` is single-writer: this feature never edits it. A new stream registers through `wire_hooks.go`'s documented procedure (its own header: add `wire_<name>.go`, a field in `streamConfigs`, one call line per aggregator). Submit-path integration for the repeat-attempt policy touches `pkg/scoring` (spec 013's package); it is delivered to the 013 owner as a patch against the scoring submit seam, together with the `ServeNext` options seam that `021` T048a and `013` T036b both need (`pkg/scoring/serve.go:93` has none).

## Sequencing

Umbrella phase (T001-T007) has no dependencies and can start immediately. The operator answers (T010) gate every `[NO-n]` task but not the others. Adaptive integrity (T020-T029) is residue on top of 013 T050-T053, which are on branch `n1-013-adaptive` and not yet merged: the stream waits for that merge. Ingestion (T030-T041) needs nothing from scoring. Gates (T050-T062) are independent and parallel-safe.

## Risks

- **OR-04 reading of OCR (NO-1).** If the operator rules OCR a forbidden vision pass, RG-16 becomes REJECT and only the refusal path remains; the table notice and self-report work are unaffected.
- **Repeat policy surprises learners (NO-5).** Mitigated by shipping `record-only` first, a neutral notice, and a feature flag default OFF for the UI.
- **Gates that read a host config directory** (T005) must never print values: names only, asserted by a test.
