---
description: "Task breakdown for a repository that clones, and a fleet with no unexplained red"
---

# Tasks: A Repository That Clones, and a Fleet With No Unexplained Red

**Input**: [spec.md](spec.md) · [checklists/requirements.md](checklists/requirements.md)

## How to read this file

**This file was written AFTER much of the work landed, and it says so rather than
pretending otherwise.** Spec 005 had no `tasks.md` at all: its 26 FR and 15 SC
were unmapped, its work was done ad-hoc by parallel agents, and completion was
therefore not measurable. This file reconciles the requirements against what is
actually in the tree — it is not a greenfield plan and must never be read as one.

**`[x]` means a command was run and its exit code or output observed**, with the
evidence on the task line. **`[ ]` carries an explicit state marker** — one of
**PARTIAL**, **OPEN** or **BLOCKED** — so that an unticked box says *which kind*
of not-done it is. That distinction is FR-006 applied to this document itself.

**Every ticked line carries its evidence, and every measurement claim carries its
population** — `source` (files in the tree), `in_process` (a program run outside
the deployed service) or `served` (measured through the running service). Where a
population could not be determined from the evidence as recorded, the line says
`(population: unstated)` rather than guessing. A ticked box with no evidence is
the bluff this project forbids, and an evidence line with no population is the
defect the constitution principle *Source Is Not Served* exists to catch.

**Dates.** Every re-measurement below was taken **2026-09-08** from the umbrella
root at `<repo-root>`. Three of them contradict an earlier
recorded state, and the contradiction is written on the line rather than absorbed.

## Task Format

```
[ID] [P] [TDD] [REVIEW] [SUBAGENT] [Story] Description with file path (FR-…, SC-…)
```

`[P]` parallelizable · `[TDD]` RED-GREEN-REFACTOR · `[REVIEW]` operator gate · `[SUBAGENT]` delegable

## Paths

Repository-relative from the umbrella root. `workshop/` is the PRIVATE module;
this umbrella and `specs/` are PUBLIC. Counts, paths and identifiers only.

---

## Phase 1: User Story 1 — a second engineer obtains the repository (P1)

**Goal**: a clone that completes on a machine that has never held this work.
**Independent test**: clone into an empty directory on a fresh machine, run the documented bootstrap, read the status output.

- [x] T001 [US1] Untrack the 54 `*.tar.gz.part-*` archive chunks with `git rm --cached` and add the pattern to `workshop/.gitignore` (FR-002, FR-005, SC-002). **Evidence** (source): `git -C workshop ls-files '*.part*'` returns **0** tracked parts, down from 54 totalling 2,624.8 MB; `workshop/.gitignore:112` carries `*.tar.gz.part-*`, which is what stops the project's `git add .` commit wrapper putting them back; commit `c182e6a` shows all 54 deletions at 52,428,800 bytes each. Files stay on disk — nothing was deleted.
- [x] T002 [US1] Keep the three `*.sha256` manifests TRACKED (≈9 KB) so a chunk fetched from elsewhere is still verifiable (FR-002, SC-003). **Evidence** (source): recorded in `workshop/scripts/verify-obtainability.sh` header — "without them a fetched file is unverifiable". The integrity record is the thing that makes moving the bytes out survivable.
- [x] T003 [US1] Record that the Git LFS remedy the spec's own clarification chose was **prepared and WITHDRAWN before it was committed** (FR-002). **Evidence** (source): `workshop/scripts/verify-obtainability.sh` quotes the superseding operator instruction verbatim — remove archives from git entirely, fetch them from storage servers in a later iteration. **This is a divergence between spec.md's Clarifications section and what was built, and it is stated here rather than left for a reader to trip over.** The spec still records LFS as the answer; the tree does not implement it.
- [x] T004 [US1] Put the documented clone command in the repository's front-door documentation (FR-001, FR-003, SC-001). **Evidence** (source): `workshop/README.md:57-60` carries `git clone --filter=blob:none …` with the single flag justified in the same document at lines 105-160, including the REFUTED HTTP/2 hypothesis and the established no-resume mechanism.
- [x] T005 [US1] Document `--filter=blob:none` as **ROBUST, not merely fast** (FR-001, FR-003). **Evidence** (source): `workshop/README.md:140` states it; the reasoning is that a 540 KB transfer that fails costs nothing to retry while a 2.6 GB one costs everything. This is the design consequence the spec's root-cause section demanded be written down.
- [x] T006 [US1] State plainly, in the guard itself, that untracking **does not shrink the repository** (FR-005, SC-004). **Evidence** (source): `workshop/scripts/verify-obtainability.sh` — "`git count-objects -vH` does not fall, and a naive full-history `git clone` still transfers all of it"; `workshop/README.md:159-160` repeats it. History rewriting is forbidden, so this limit is permanent and is printed rather than softened.
- [x] T007 [TDD] [US1] Ship `workshop/scripts/verify-obtainability.sh` — the obtainability-cost guard that warns **before** the failure point (FR-004, SC-002). **Evidence** (source): 3-valued exit contract documented in-file (0 below warning · 1 WARN/BREACH/half-finished-untracking · 2 could-not-ask); ceiling **adopted from SC-002's 250 MB rather than selected**, `WARN_AT = CEILING − (largest single blob at HEAD)` capped at 80% of ceiling. **Both threshold rules are stated without reference to any count**, which is FR-010 applied to the guard's own design.
- [x] T008 [US1] Make the guard measure the CHECKOUT PAYLOAD of the documented path, and report full history as a NOTE only (FR-004, SC-002). **Evidence** (source): recorded in-file — "a gate that failed on history would demand a remedy nobody is allowed to perform, and a gate whose remedy is forbidden is decoration."
- [x] T009 [US1] Catch the half-finished untracking — a path `.gitignore` matches while git still tracks it (FR-002, FR-004). **Evidence** (source): that state is an explicit exit-1 finding in the guard's contract. It is the failure mode where the rule was added and `git rm --cached` was not, so the rule does nothing and the bytes ship anyway.
- [ ] T010 [TDD] [US1] **PARTIAL** — run `verify-obtainability.sh --prove-failure`, the §1.1 paired proof, and record its pass/mutation counts (FR-021, SC-014). The proof's interface and mutation **M7** (a FINDING outranks an UNDETERMINED, never inverted) are declared in the guard's header, but **no run of it was captured in this session**, so no count is claimed here.
- [ ] T011 [US1] **OPEN** — perform SC-001's actual trial: **3 of 3** clones by the documented command, on a machine that has never held the repository, with **0** transport failures (FR-001, SC-001). The refuting two-arm HTTPS test recorded in spec.md was run from a third host and proves the transport works; it is **not** the 3-of-3 acceptance run, and must not be reported as one.
- [ ] T012 [US1] **BLOCKED — operator decision.** Publish the documented step by which recorded material is obtained from storage outside the repository, with its stated availability condition (FR-003, SC-003). The superseding instruction was explicit that the fetch instructions come in a later iteration. **Until it exists, SC-003's "100% remains obtainable by a documented step" is NOT met** — the bytes are on one disk and the step is unwritten.
- [ ] T013 [US1] **OPEN** — warn on the growth TREND, not only on the breach (Edge case: *a repository shrinks below the threshold but keeps growing*). The guard thresholds on a point-in-time size; nothing reads a series.

**Checkpoint**: the documented path is small and guarded; the acceptance trial (T011) and the retrieval step (T012) are the two things standing between this and SC-001/SC-003.

---

## Phase 2: User Story 2 — a reader can tell a finding from a designed state (P1)

**Goal**: every red states whether it is a defect, a declared condition, or a check that could not run.
**Independent test**: run every instrument; for each red, answer three questions from its output alone.

- [x] T014 [US2] Give `workshop/scripts/verify-obtainability.sh` a three-valued exit where **2 is never a pass** (FR-006, FR-008, SC-006). **Evidence** (source): contract stated in-file; precedence asserted by mutation **M7** so a moving tree cannot mask a breach already measured.
- [x] T015 [TDD] [US2] Make `_tools/watch-deploy.sh` read its exit codes and fold each cycle into a three-valued verdict (FR-006, FR-008, SC-006). **Evidence** (source, from `scripts/check-registry.tsv` and commit `f824cd1`): verdict is 0 clean / 2 a cycle could not run / 5 a cycle ran and failed, **failure outranking could-not-determine**. Before this, the watcher discarded `$?` and could loop 240 times against a deploy failing every cycle and still exit 0.
- [x] T016 [TDD] [US2] Ship `_tools/prove-watch-deploy-verdict.sh`, the §1.1 paired proof, driven by **data** rather than by editing its subject (FR-021, SC-014). **Evidence** (in_process, recorded in `scripts/check-registry.tsv`): **9 passed / 0 failed / 8 mutations** against the current watcher, and **3 passed / 6 failed** against a reconstruction of the pre-fix watcher — every one of the 6 reporting `got 0` where a verdict was owed. Mutations are stub exit codes via `WATCH_DEPLOY_CMD`; the watcher's source `sha256` is captured before the battery and re-asserted after, so a mutation that edited the subject would fail the proof.
- [x] T017 [US2] Rewrite the `_tools/watch-deploy.sh` registry exemption to carry its evidence and WITHDRAW the expired reason (FR-007). **Evidence** (source): `scripts/check-registry.tsv` — the prior reason *"it judges nothing"* is marked WITHDRAWN by name, with the date and the change that expired it. **An exemption whose justification expired still looks reviewed**; this is the fix for that class.
- [x] T018 [US2] Write read-only provider adapters for the two hosts that had none — `gitflic.ru` and `gitverse.ru` (FR-011c, SC-005). **Evidence** (source): `scripts/verify-provider-ci.sh` grew 585 lines in commit `f824cd1`; both adapters speak HTTP directly because neither host ships a CLI, and each declares its own honest ceiling in-file (gitflic **cannot** reach a NONE verdict by construction and says so on every row; gitverse can, its route set established empirically).
- [x] T019 [TDD] [US2] Prove the two adapters with the M8..M13 battery, including the case that stops an adapter hardwired to refuse from passing (FR-011c, FR-021). **Evidence** (source): `scripts/verify-provider-ci.sh:408-540` — M8 unreachable ⇒ rc 2 with the row UNVERIFIED; **M9 a control that goes green** ⇒ rc 0 with the row NONE. Without M9 the battery would be satisfied by an adapter that can only ever say no.
- [ ] T020 [US2] **BLOCKED — operator credential.** Turn the 6 UNVERIFIED provider rows into verdicts (FR-011c, SC-005). **Re-measured 2026-09-08** (served, provider APIs): `bash scripts/verify-provider-ci.sh` exits **1** — 22 repositories / 40 upstream rows, **1 CONFIRMED**, and the 6 rows now report *"an adapter IS registered for this host but could not run"* rather than *"no adapter registered"*. `https://api.gitflic.ru` answers **HTTP 403** and `https://api.gitverse.ru` answers **HTTP 401**; both require a credential on every route and none is configured. **This is FR-011c working exactly as written** — "never asked" became "asked and could not determine", which is progress, and it was NOT converted into a pass. Lifting it needs `GITFLIC_TOKEN` / `GITVERSE_TOKEN`, which only the operator can issue.
- [x] T021 [US2] Judge the content-boundary class A INWARD rows rather than allow-listing them (FR-007, FR-011, SC-007). **Evidence** (source): `docs/findings/content-boundary-class-a-judgement.jsonl` holds **1,933 rows, every one `verdict: NOT_A_DISCLOSURE`, 0 unjudged** — verified by counting the file's own verdict field, not by transcription. `docs/content-boundary-class-a-judgement.md` groups them G1–G8 with a per-group reason. **Nothing was redacted, allow-listed, re-baselined, and `scripts/verify-content-boundary.sh` was not edited. The gate still exits 1, and it should.**
- [x] T022 [US2] Judge the **union** of two gate runs' INWARD rows, not the more convenient one (FR-023, SC-007). **Evidence** (source): both runs are tabled in `docs/content-boundary-class-a-judgement.md` — totals 16,155 and 9,945, tied together with `--expect-corpus`; **51 rows appeared only in run 2** and are included. Judging the union is what stops a moving tree quietly dropping a row out of the reading queue.
- [x] T023 [US2] Attribute the total's fall rather than banking it (FR-011, FR-023). **Evidence** (source): the same document tests four candidate mechanisms for the 16,155 → 9,945 drop in 39 minutes and states *"nothing was silenced to achieve it"*. **An unexplained fall is worse than a stable red.**
- [x] T024 [US2] Report the direction split across five populations whose totals differ by more than 3,000 rows (FR-011, FR-018). **Evidence** (source): OUTWARD landed at 79.7 / 79.3 / 79.1 / 80.2 / 82.1 % every time. **The totals move; the direction does not** — that is the figure to act on, and it is what bounded the reading assignment.
- [x] T025 [TDD] [US2] Register `scripts/verify-content-boundary-judgement.sh` as a check with a `--prove-failure` paired proof (FR-020, FR-021, SC-014). **Evidence** (source): row added in `scripts/check-registry.tsv` in commit `f824cd1`; the gate is 450 lines.
- [x] T026 [US2] Install the pre-push gate hook, since `.git/hooks/` is untracked and a fresh clone runs no gates (FR-020). **Evidence** (source): `.git/hooks/pre-push` is present, executable, 1,224 bytes, dated 2026-09-08 10:58. **Honest limit**: `git push --no-verify` still bypasses it with no record, and this hook protects only this checkout.
- [x] T027 [US2] Take the R3 hardcoded-path red to green by a real fix, not a re-baseline (FR-011, FR-011a, SC-007). **Re-measured 2026-09-08** (source): `bash scripts/audit-hardcoded-paths.sh` exits **0** — *"no machine-specific hardcoded paths"*, 16 file(s) explicitly allowed. The R3 baseline of 17 live occurrences is cleared.
- [ ] T028 [US2] **PARTIAL** — work through the 387 baselined path occurrences, partitioned by owning repository (FR-011a, FR-011b). **Evidence so far** (source): commit `f824cd1`'s own message records the partition and that **51% can only be fixed by an upstream commit returning as a gitlink bump**. The partition exists; the campaign does not. **FR-011b's re-derivation requirement is unmet**: no row has been re-derived to prune debt already fixed upstream, so the 387 is still an unpruned figure that overstates.
- [x] T029 [US2] Close the R2 continuation red and the R4 governance-pin red (FR-011). **Evidence** (source): commit `f824cd1` updated `CONTINUATION.md` (+207 lines) and moved `submodules/constitution` three commits, the first move in six that was **not** corpus-neutral — the constitution gained anchor 11.4.272 and every recorded figure in the four carriers was stale and was updated in lockstep. **BOTH REDS HAVE SINCE REOPENED, re-measured 2026-09-08 from the umbrella root** (source): `bash scripts/continuation-check.sh` exits **1** at *7 PASS · 1 DRIFT · 0 UNDET · 15 NOTE* — "CONTINUATION.md IS STALE"; `bash scripts/verify-submodule-remote-sync.sh` exits **1** at *12 CURRENT / 1 DRIFT / 0 UNDETERMINED*, the single DRIFT row being `submodules/constitution` (gitlink `71ac4373…` vs remote `2db64ee8…`, **difference DETERMINED, direction NOT**, because the remote commit is absent from this object store). **Closing an instance is not closing the class, and this pin has now gone stale six times. Do not read T029's tick as a green fleet.**
- [x] T030 [US2] Confirm the manifest and gitlinks moved together (FR-011). **Re-measured 2026-09-08** (source): `bash scripts/verify-manifest-pins.sh` exits **0** — **13 MATCH / 0 DRIFT / 0 UNDETERMINED** of 13 declared deps. C9 caught the manifest lagging its gitlinks **twice on 2026-09-08** (commits `bfe2931`, `3922e35`) and both were repaired; that is the gate working.
- [ ] T031 [US2] **OPEN** — build the fleet summary that reports **defect count and declared-condition count separately and never merges them** (FR-009, SC-008). **No such instrument exists.** Every gate reports its own verdict; nothing aggregates them into the two-number statement FR-009 requires, so SC-008's "unexplained reds reaches 0, from a baseline of 11" is **not computable today**.
- [ ] T032 [US2] **OPEN** — give every non-clean instrument an explicit KIND on its own output line: defect / declared / could-not-run (FR-006, SC-005). Several instruments do this well (T014, T015, T020); **it is not universal**, and SC-005's "100% of non-clean results state their kind" has not been measured across the fleet.
- [ ] T033 [US2] **OPEN** — make a declared condition name **who may lift it and what evidence would** (FR-007, SC-015). `scripts/check-registry.tsv` exemptions now carry evidence and reasons (T017), and T020's row names the credential, but no instrument requires a lifting authority as a structural field.
- [ ] T034 [TDD] [US2] **OPEN** — assert FR-010 mechanically: any threshold, bucket, allow-list or baseline change must carry a principle stated independently of the count it produces (FR-010, SC-007). Two guards do this in prose by construction — `verify-obtainability.sh`'s two threshold rules (T007) and the palette gate's fixed floor — but **nothing detects a weakening change**. This is the requirement most exposed to being satisfied by assertion.
- [ ] T035 [REVIEW] [US2] **OPEN** — run SC-015's acceptance: a reader answers *"is this a defect, what is the evidence, what happens next"* for every red from instrument output alone, without consulting a person. Not attempted; it depends on T031–T033.

---

## Phase 3: User Story 3 — every learner-facing defect is repaired or disclosed (P2)

**Goal**: nothing silently broken; every omission stated.
**Independent test**: walk one area end to end and confirm nothing is silently absent.

- [x] T036 [TDD] [US3] Ship the B6/B7 detector for questions citing withheld material in `workshop/pipeline/extract/verify_question_banks.py` (FR-012, SC-009). **Evidence** (source): 478 lines added in commit `c182e6a`; **B6** asserts every citation resolves in the registry AND is `redacted: false`, **B7** the same for every `lesson_sections` pid. The file records the mechanism in its own header: a question citing a redacted passage is withheld under `WithholdCitationRedacted`, **so a learner opening those areas was served a shorter test with nothing saying so.**
- [ ] T037 [US3] **PARTIAL** — repair or record the removal of every question citing withheld material (FR-012, SC-009). The **detector** landed (T036); **whether the affected questions were repaired was NOT confirmed in this session**, because confirming it means running the bank verifier against the private corpus. **SC-009's "0 questions cite material the server withholds, down from 5" is therefore UNVERIFIED here** — the instrument that would answer it exists and was not run. `(population: unstated)` — the R8 baseline of 5 was a source count over the authored banks; the served count was never separately established.
- [ ] T038 [US3] **OPEN** — tell a learner, in the interface, that an area has no assessment and why (FR-013, SC-010). No task in the tree implements the learner-facing disclosure; the platform's absence-honesty gates (`workshop/platform/gates/verify-absence-honesty.sh`) govern what the *server* asserts, not what the *learner reads*.
- [x] T039 [US3] Remove R7's structural obstacle — area documents never sectioned into the passage registry, so no citation could resolve and no question could be authored (FR-015, SC-011). **Evidence** (source): `git -C workshop ls-files 'docs/training/curriculum-areas/*.md'` returns **37** and `…*.sections.json` returns **37** — **37 of 37 sectioned**, against R7's baseline of 25 of 37 unsectioned. The obstacle is gone at source.
- [ ] T040 [US3] **PARTIAL** — report the resulting coverage figure, and report **separately and honestly** the areas that carry no assessment because the corpus cannot support one (FR-015, SC-011). The structural blocker is cleared (T039); **the two populations have not been counted apart**, and SC-011 requires exactly that separation. Merging them would let a corpus limitation be reported as progress.
- [ ] T041 [REVIEW] [US3] **BLOCKED — operator gate.** Read the 3 documents failing publication review on **62, 54 and 58** uncited claim blocks and decide publish-or-not (FR-014, SC-010). They remain unpublished, so a client sees fewer areas than are authored. This is the same gate carried as T060 in [`../006-session-record-and-qa-readiness/tasks.md`](../006-session-record-and-qa-readiness/tasks.md) — **one decision, recorded in two specs, not two decisions.**
- [ ] T042 [US3] **OPEN** — assert FR-014 mechanically: a published document's primary references resolve to material a reader can actually reach. T041 is a human read of three documents; **no check enumerates published documents and resolves their primary references.**

---

## Phase 4: User Story 4 — the interface looks designed on the surfaces people use (P2)

**Goal**: materially more hue variety on principal surfaces; contrast floors hold in both presentations.
**Independent test**: sample what is painted on principal surfaces in both presentations; count hue variety and measure contrast within each pairing.

- [x] T043 [TDD] [US4] Make `workshop/platform/gates/verify-served-palette.sh` read the **SERVED bundle only**, through `lib/served_css.sh`, and never `src/styles/**` (FR-016, FR-018, SC-012). **Evidence** (source): stated as the gate's entire reason for existing — measured defect **D6** was that the token source's hue span was widened, nothing regenerated the served stylesheets, and the token measurement was then reported as evidence about the interface. **"A check that read the token source to reach its verdict would have returned SUCCESS over exactly that defect."**
- [x] T044 [US4] Family the colour an element **paints of its own** (`paint`), not only the ground behind it (`bg`) — defect **D-A** (FR-016, FR-018). **Evidence** (source): recorded in the same gate. For a `non-text` row the sampler sets `bg` to the ground *behind* the indicator, which is correct for contrast but meant **a coloured chip, wash, rule or fill could not contribute a hue family AT ALL, by construction**. The population excluded the very elements an interface uses to carry colour. A row with no `paint` still grades exactly as before, so an older sample is unaffected.
- [x] T045 [US4] Define a hue family as a 30° bucket (12 buckets), with imperceptible-chroma colours collapsing into ONE `neutral` family counted once (FR-016, FR-018, SC-012). **Evidence** (source): stated in-gate — *"counting each grey as its own hue would let a monochrome interface pass"*. Two colour spaces are used on purpose: HSL for the hue ANGLE (it need only partition colours that already have a hue), and a different measure for whether a colour has a hue at all, because HSL saturation divides by a span that vanishes near white and black. **The floor of 6 is fixed by the specification, not chosen by the gate** — FR-010 applied to the instrument.
- [ ] T046 [US4] **PARTIAL** — re-measure the served hue-family count and record it against SC-012's floor of 6, up from a baseline of 2 (FR-016, SC-012). The corrected instrument exists (T043–T045) and `workshop/platform/gates/sample-served-surfaces.mjs` takes the browser sample. **No served run was captured in this session, so no post-fix count is claimed here.** `CONTINUATION.md:646` still records the baseline *"the served interface paints 2 hue families against a floor of 6"*, and until a served run supersedes it, **that is the last measured figure in this tree.** Note the shape of the trap this gate was built against: when the instrument became honest the count went **down** from 4 to 2 — a corrected gate reporting a worse number than the broken one it replaced.
- [ ] T047 [US4] **OPEN** — give every hue present a stated classification job, so no hue is added only to raise a count (FR-017, SC-012). The design-system documents landed in commit `f11a3c1` (`workshop/docs/design-system/TOKENS.md`, `RATIONALE.md`, `COMPONENTS.md`, `wk-semantic-tokens.css`), but **nothing asserts the mapping from every painted hue to a declared job**, which is what SC-012's second half requires.
- [x] T048 [TDD] [US4] Ship `workshop/platform/gates/verify-served-contrast.sh` with its paired prover, measuring text and non-text pairings separately in both presentations (FR-019, SC-013). **Evidence** (source): both `verify-served-contrast.sh` and `prove-served-contrast.sh` are tracked; `workshop/docs/design-system/contrast.py` (245 lines, commit `f11a3c1`) is the measurement, and its own commit records that **nine of the specification's own colours were short** — the spec was wrong and the instrument found it.
- [ ] T049 [US4] **PARTIAL** — record the served contrast result: **0** failures across text and non-text pairings in both presentations (FR-019, SC-013). The gate and its prover exist; **no served run was captured in this session.**
- [ ] T050 [US4] **OPEN** — justify the measured population independently of its effect on the count, and record that justification whenever the population changes (FR-018, SC-012). T044 **changed the population** (adding `paint`) for a stated defect reason, which is the right shape — but no rule requires the next change to do the same, and the edge case *"a red is fixed by making the instrument weaker"* lives exactly here.

---

## Phase 5: Evidence discipline — cross-cutting

- [x] T051 [TDD] Drive every palette mutation by **data**, not by altering the check (FR-021, SC-014). **Evidence** (source): 8 fixtures tracked under `workshop/platform/gates/fixtures/palette/` — `empty`, `flat`, `good`, `low-contrast`, `near-grey-ramp`, `scheme-split`, `indicator-only`, `boundary-ulp`. `indicator-only` is the fixture that pins defect D-A; `boundary-ulp` pins the bucket edge. **A gate green by construction is the inoperative-proof defect this project has already caught once.**
- [x] T052 Make the content-boundary gate carry evidence its corpus did not move during the measurement (FR-023). **Evidence** (source): both runs in `docs/content-boundary-class-a-judgement.md` report `corpus MOVED` with the changed-file count (66 of 14,891; 4 of 14,837) and are tied together by `--expect-corpus`. **The gate reports its own instability instead of absorbing it silently.**
- [ ] T053 [TDD] **PARTIAL** — make every check whose subject is a set establish the set is **non-empty** before reporting the set contains no defects (FR-022, SC-014). Two instruments do this: `verify-obtainability.sh` returns **2** when nothing is tracked to measure, and `workshop/platform/gates/verify-bank-reachability.sh` was written precisely because the prior gate checked one fixture area while 89 questions were unreachable. **It is not universal, and no sweep asserts it across the fleet.**
- [ ] T054 **OPEN** — satisfy SC-014: **100%** of requirements map to at least one automated check, and every such check ships a data-driven paired demonstration (FR-020, SC-014). **This file is the first half of that criterion and does not complete it.** Every FR and SC in spec.md is now cited by at least one task above — but a task is not a check, and 22 of the 54 tasks here are not ticked. **Requirements with no automated check at all: FR-009, FR-010, FR-013, FR-014, FR-017 and SC-015.** Those six are the real coverage gap.

---

## Status

Counted from this file by script, not transcribed.

| Phase | tasks | DONE | PARTIAL | OPEN | BLOCKED |
|---|---:|---:|---:|---:|---:|
| 1 US1 obtainability | 13 | 9 | 1 | 2 | 1 |
| 2 US2 red-state discipline | 22 | 15 | 1 | 5 | 1 |
| 3 US3 learner-facing | 7 | 2 | 2 | 2 | 1 |
| 4 US4 presentation | 8 | 4 | 2 | 2 | 0 |
| 5 Evidence | 4 | 2 | 1 | 1 | 0 |
| **Total** | **54** | **32** | **7** | **12** | **3** |

```bash
grep -c '^- \[' specs/005-clone-and-clear-red/tasks.md      # 54
grep -c '^- \[x\]' specs/005-clone-and-clear-red/tasks.md   # 32
grep -c 'PARTIAL' specs/005-clone-and-clear-red/tasks.md    # 7 task lines
grep -c 'BLOCKED' specs/005-clone-and-clear-red/tasks.md    # 3 task lines
```

**32 of 54 carry a captured run or an observed artefact.** Of the 22 not ticked,
**3 are BLOCKED on an operator** (T012 the storage-fetch instructions, T020 the
two provider credentials, T041 the three unpublished documents), **7 are PARTIAL**
— the instrument exists and the measurement or the campaign does not — and
**12 are OPEN**, with no implementation found in the tree.

**Read the PARTIAL column before the DONE column.** Five of the seven are the same
shape: *a corrected instrument exists and was never run against the served
product*. T037, T046 and T049 each name a number this specification claims to have
moved, and **none of the three post-fix figures was captured in this session.**

## The three reds that reopened

**T029's tick is the most misreadable line in this file, so it is restated here.**
R2 and R4 were both closed in commit `f824cd1`, and both were measured RED again
on 2026-09-08 from the umbrella root:

```
bash scripts/continuation-check.sh            # rc 1 — 7 PASS · 1 DRIFT · 15 NOTE
bash scripts/verify-submodule-remote-sync.sh  # rc 1 — 12 CURRENT / 1 DRIFT
bash scripts/verify-manifest-pins.sh          # rc 0 — 13 MATCH / 0 DRIFT
bash scripts/audit-hardcoded-paths.sh         # rc 0 — 16 file(s) allowed
bash scripts/verify-provider-ci.sh            # rc 1 — 1 CONFIRMED, 6 could-not-run
```

The governance pin has now gone stale **six** times. **Treat it as a standing
operator decision that recurs, not a task that completes** — and never quote a
green from this document as current. Re-run the five commands.

## Dependencies

```
T001 untrack ──> T007 guard ──> T010 proof
                      └────────> T011 the 3-of-3 trial      ← the SC-001 acceptance
T012 storage-fetch instructions  ← BLOCKED, and SC-003 is unmet without it

T014/T015/T018 three-valued instruments ──> T031 the fleet summary ──> T035 SC-015
                                                  └──> T032 kind on every red
                                                  └──> T033 lifting authority

T039 sectioning ──> T040 the two coverage populations, counted apart
T043/T044/T045 corrected palette gate ──> T046 the served re-measurement
```

**T031 blocks SC-008.** Nothing today can state how many reds are defects and how
many are declared, so the headline criterion of this specification — unexplained
reds reaching 0 from a baseline of 11 — **is not computable**, however many
individual gates are green.

## Requirement coverage

Every FR and SC in [spec.md](spec.md) is cited by at least one task above:
**26 of 26 FR** and **15 of 15 SC**, verified by script rather than transcribed.

```bash
python3 - <<'PY'
import re
s=open('specs/005-clone-and-clear-red/spec.md').read()
t=open('specs/005-clone-and-clear-red/tasks.md').read()
ids=[]
for m in re.finditer(r'\*\*(FR-[0-9]+[a-z]?|SC-[0-9]+[a-z]?)\*\*', s):
    if m.group(1) not in ids: ids.append(m.group(1))
un=[i for i in ids if not re.search(r'(?<![0-9a-z])'+i+r'(?![0-9a-z])', t)]
print(len(ids), 'ids ·', len(un), 'uncited'); print(' '.join(un))
PY
```

**A citation is not a check.** The six requirements with no automated check
anywhere in the tree are named in T054, and that list — not the coverage
percentage — is the finding this file exists to surface.
