# Cross-Artifact Analysis — Workshop Curriculum Platform

**Feature**: `specs/001-workshop-curriculum-platform` | **Date**: 2026-09-01
**Scope**: spec, plan, research (×4), data-model, contracts (×3), quickstart, tasks, checklist,
project constitution — 8,433 lines.

## Severity counts

| Severity | Count |
|---|---|
| CRITICAL | **4** |
| HIGH | 17 |
| MEDIUM | 22 |
| LOW | 6 |
| **Total** | **49** |

## Coverage headline

- **FRs with no covering task (2)**: FR-006, FR-039
- **FRs partially covered (7)**: FR-005, FR-011, FR-012, FR-016, FR-017, FR-018, FR-029
- **SCs with no executing task (3)**: SC-007, SC-008, SC-016a
- **SC partially validated (1)**: SC-018
- **Scope creep: 0.** Four tasks trace to a decision/anchor rather than an FR (T003, T026, T039, T074) — all justified.
- `tasks.md`'s own count is correct by enumeration: 7+9+16+10+14+14+6+15 = **91**.

**Tree facts measured during analysis** (not read off a document): `.gitmodules` declares **9**
submodules including a populated `submodules/containers`; `workshop/` carries all four carriers;
`workshop/chapters/01/` holds 36 parts; the reference control plane is
`ai_interviewing/platform/scripts/`, not `ai_interviewing/scripts/`; `workshop/docs/` already exists.

---

## CRITICAL

### C1 — Container orchestration: two incompatible architectures on a claim the tree disproves

`plan.md:73` and `tasks.md:123,145` assume `submodules/containers` exists and is consumed. But
`research.md:281`, `contracts/pipeline-cli.md:809` and `quickstart.md:992` all still state it is
**"not a submodule of this tree"** — false as of this feature's own work, never withdrawn
(the constitution requires an explicit withdrawal, not a silent replacement).

Worse, the two are architecturally incompatible: `pipeline-cli.md` §4.8 specifies **native**
launch ("run the built binary natively, as `ai_interviewing` does"), while T015 specifies
**container** wrappers over `cmd/boot`.

Third strand: `plan.md:96` records that the containers submodule's own carriers were a
§11.4.157(B) violation "which currently blocks the pre-push hook", and no task clears it.
*(Resolved 2026-09-01 upstream at `4dab992`; the plan text is now stale in the other direction.)*

**Resolution**: one operator decision (native vs containerised), then withdraw the stale claim in
all three documents and align `pipeline-cli.md` §4.8 with T015 or the reverse.

### C2 — FR-039 (redaction) is a MUST with zero tasks

`spec.md:219` requires a documented redaction step that MUST have run before any export or
publication. It exists because the Chapter 1 recording features an identifiable third party.

It is **fully contracted**: `pipeline-cli.md` §4.6 (`redact.sh`) and §4.7 B5 (publish
precondition); `passage-contract.md` §4.3 (`redactions` table), §7.3 rules R1–R7, gate G-PID-5;
`http-api.md` §3.8 (`410 Gone`), §3.9 (`redacted_omitted`), §3.10 A4.

**`tasks.md` has no redaction task.** "redact" appears once (T064) as a *fixture kind*.
Consequentially T071 describes add-chapter as "transcribe → ingest → index → cross-link" against
`pipeline-cli.md:559`'s nine stages — dropping **preflight, verify-accuracy and
redaction-review**, the last of which gates publication.

### C3 — SC-016a has no implementing and no validating task

`spec.md:258` requires code-passage identity keyed on symbol path with a rename alias table, such
that 100% of stale code references **fail loudly**. Contracted at `passage-contract.md` §6.2–6.5,
§4.3 (`symbol_aliases` DDL), §8 rule R4, gate G-PID-4.

T011 proves only G-PID-1/G-PID-2 (the two SC-016 survival guarantees). `symbol_aliases`, R4 and
G-PID-4 appear in no task. SC-016a's only mention is T081 — which *documents* a guarantee nothing
implements.

Compounded by `passage-contract.md:631` (P-U1): "Lumen exposes no symbol table through its CLI or
MCP surface … the matching key has no confirmed producer" — in no task and no register.

### C4 — The Answer contract is forked

| | `data-model.md:144` | `http-api.md:824` |
|---|---|---|
| field | `verdict` | `status` |
| refusal member | `refused` | `declined` |
| reason field | `refusal_reason` | `reason` |
| reason members | `below_threshold, margin_too_small, unsupported, no_provider` | `below_threshold, margin_too_small, unsupported, no_citations, redacted_evidence` |

Four incompatibilities — and `data-model.md` files `no_provider` (an *unavailable* cause) as a
**refusal** reason, conflating exactly the two states `http-api.md:847` A7 declares distinct.
`plan.md:247` marks refusal and citation the two highest-risk `[TDD]` components, so tests land
first against one of two shapes. T057–T068 cite `http-api.md` and never `data-model.md`.

---

## HIGH (17, abbreviated)

| # | Finding |
|---|---|
| H1 | `plan.md` contradicts itself three times: Phase 0 "IN PROGRESS"/Phase 1 "NOT STARTED" vs a post-Phase-1 re-check and 91 tasks; carriers "present and committed" vs "absent today"; `[REVIEW] Container definitions` vs "NO containers/ dir — deliberately NOT created". |
| H2 | SC-002 says "random sample of ≥30 **passages**"; research D-TRANS-3 samples **audio-timeline windows** (to remove deletion bias) — a reinterpretation repeated in four documents while `tasks.md:26` claims values are "copied verbatim from spec.md". "random" vs "seeded, stratified" are also different designs. The criterion was never amended. |
| H3 | FR-016 requires indexing "the recordings themselves"; Lumen's allowlist is a compile-time var with no override. Satisfied by *reduction to text*, which is a re-reading, not compliance. No task indexes a recording. |
| H4 | `passage-contract.md` §6.6 quotes the **pre-split** SC-016 as "unqualified" and recommends a change already applied. `plan.md:244` shares the stale reading and never mentions SC-016a; `data-model.md` mentions neither SC-016a nor `symbol_aliases`. |
| H5 | Decision ids collide: `research.md` D-LLM-1…5 and `llm-bridging.md` D-LLM-1…11 mean different things (research D-LLM-1 = provider seam; llm-bridging D-LLM-1 = no generative model exists). T069 cites D-LLM-10 in the llm-bridging sense — valid but unresolvable from `research.md`, which `tasks.md:27` names as its source. `D-SEARCH-*`/`D-TRANS-*` exist only in `research.md`. |
| H6 | Control plane specified at two paths with two script sets. `pipeline-cli.md:125` names six scripts and justifies via `ai_interviewing`'s `scripts/` — but the real reference is `ai_interviewing/platform/scripts/`. T015 creates 3 of 6; missing are `restart.sh`, `build.sh` and **`verify.sh`** — the aggregation point that runs every gate and implements SC-012/SC-013 precedence. Seven of eight contracted pipeline wrappers are untasked. |
| H7 | T053 **builds** the SC-007/SC-008 benchmark; **no task runs it**. Compare T064/T065, which do it correctly. `quickstart.md:620` specifies the missing `bench-retrieval.sh`. Both criteria are also `BLOCKED: U5`, stated flatly in Global Constraints with no caveat. |
| H8 | SC-006 feasibility rests on an unverified assumption. `tasks.md:29-31` juxtaposes "embedding 18.2–21.0 s" and "results ≤2 s p95" without reconciliation. `search-architecture.md:377` asserts the 2.2 s warm-up is "not paid per call" while its own C-3 marks that UNVERIFIED with counter-evidence (`index_status` cost 2.6–5.1 s on three consecutive calls in one warm session). No task settles U4/C-3, and the "reserved embedding capacity — a hard requirement" is untasked. |
| H9 | Phase 3's checkpoint cannot be met by Phase 3's tasks: (a) the blind human reference (1–2 h) is contractually required and **no task produces it**, so T031 terminates at exit 2 by contract; (b) T030 claims to settle U1, but U1 is settled by the venv install — T005, thirteen tasks earlier — while T018–T029 presume a working `faster-whisper` with no failure branch; (c) the `whisper.cpp` fallback is itself unverified (U9, absent from `research.md`). |
| H10 | The project constitution asserts two facts this feature measured false: "ffmpeg/**ffprobe** 7.0.2" (a Playwright symlink that fails `-show_format`), and "**8** submodules are declared" (measured: 9) — against its own principle that "a hardcoded list silently goes stale the moment the set grows". Root `CLAUDE.md`'s owned-submodule list omits both `workshop` and `containers`. |
| H11 | `quickstart.md` states two counts of its own preflight failures — "Three of its six checks" vs "anything other than four `1`s and two `0`s has not understood the host". The table shows four. |
| H12 | FR-006 (preserve source material unmodified) has no task, though it is contracted with gate G-CLI-2. `plan.md:158` asserts the property as already true about a pipeline that does not exist. |
| H13 | `sections[]` is served by the API (`http-api.md:333`, traced to FR-011) but modelled nowhere and built by no task. FR-011 is effectively untasked. |
| H14 | The unverified register loses 17 of 22 entries and **collides on two identifiers**: transcription U4/U5 mean different things from research U4/U5. Transcription U6–U9 reach nothing downstream; two orphan UNVERIFIEDs sit in no register. Phase-1 contracts add P-U1/P-U2/P-U3 and C-U6/C-U7, all untasked — P-U2 in particular is the mechanism SC-016 rests on. |
| H15 | T070 states the generation-latency estimates as fact, dropping the UNVERIFIED marker every other artifact carries — while the same task correctly forbids the API from publishing an estimate. The source contradicts itself: "engineering estimates, not measurements" vs "measured in tens of seconds". |
| H16 | SC-003's "within 5 seconds" carries no statistic; downstream invents p95 in three places. Its feasibility rests on `transcription.md:724`'s "**probably** sufficient" — a hedge the governing rules forbid for causal claims — and U5 registers it unverified. |
| H17 | SC-005's sole evidence (FTS5 p95 9.58 ms) was measured over the **existing monorepo's** 58,726 symbols, 92.7% of which are markdown headings — not curriculum passages, which do not exist. The architectural conclusion is robust; the *headroom* claim is not. Constitution: "A claim measured on one member of a set is NOT a claim about the set." |

## MEDIUM (22, abbreviated)

M1 paired-mutation inventory counted three ways (14 / "of 24" / actual 28), and **no task cites any `G-*` id** · M2 evidence path forked `workshop/evidence/` vs `workshop/_evidence/` · M3 `pipeline-cli.md:796` claims "42 FRs / 18 SCs" fully covered — there are 19 SCs and the claim is false for SC-015 and SC-016a · M4 "five corrected premises" does not decompose (premise 2 is "superseded by premise 5") · M5 "Open items entering Phase 1" lists three, one already resolved and still marked pending, and omits U3–U5 · M6 T055 proves SC-016 over citations built in a later phase · M7 checklist maps FR-039 to link-survival criteria · M8 provider env var forked, and the fallback makes the mismatch **silent** · M9 quickstart corrects a `plan.md` statement it no longer makes · M10 six contracted endpoints untasked · M11 `data-model.md` is a strict subset of the same-day contracts with no note that it is an abstraction · M12 SC-008's denominator ambiguous · M13 SC-004's 15-min budget has no host baseline while reassembly may dominate it · M14 SC-011's "hands-on time" undefined · M15 US3 called independently testable but declared to need US2 · M16 SC-018 has a writing task but nothing asserting 100% · M17 FR-029's progress half untasked · M18 FR-005's "state where it cannot" half untasked; `speaker_source` missing from the data model · M19 T017 inherits a two-valued script and adds no classifier, so an unreadable part reports 1 instead of 2 · M20 tombstones have no resolution outcome · M21 the withdrawn "75 s" figure is restated as fact in `llm-bridging.md:657` · M22 `llm-bridging.md` defines two disjoint L1–L4 sets (grounding and privacy), so a bare "L3" is ambiguous.

## LOW (6)

L1 `spec.md:21` "single word 'Tbd.'" — measured: a heading plus `Tbd.` · L2 `workshop/docs/` marked NEW but exists; T001 must be non-destructive · L3 `WORKSHOP_CHUNK_SECONDS` is a flat 300 among derived neighbours · L4 registry path globbed two ways · L5 `pipeline-cli.md:702`'s example total matches no enumeration · L6 decision ordinal `2b` round-trips through no `\d+` scheme.

## Categories genuinely clean — reported as such

- **§11.4.156 / no CI: clean.** Guarded at four independent points, including a gate whose
  mutation is "add one — must FAIL". The `workshop` tree contains no `.github/`.
- **Every contracted gate carries a paired mutation: clean.** All 28 name a specific mutation and
  require it to redden. The real-entry-point rule and the grep-is-not-a-test rule are both carried
  through, and a gate whose mutation fails to redden it is defined as vacuous → FAIL. M1 concerns
  *counting* the inventory, not any gate lacking a proof.
- **Three-valued reporting: clean by design**, including a mechanical `ERR` trap mapping
  unclassified failures to 2. Only defect is M19, a task omission.
- **No frozen host assumptions in the design: clean.** Only L3 remains.
- **No scope creep: clean.** All 91 tasks trace to a requirement, decision, assumption or anchor.

**Verified negatives** (checked and sound): the 91-task count and per-phase split; T069's
`D-LLM-10` is **not** dangling; `plan.md`'s "14 proofs" is an accurate count of quickstart's table;
the constitution's "8 registered pre-push gates" (E + 0–6); the 36-part count.

## Readiness verdict

**NOT READY.** Two MUST-level obligations (FR-039 redaction, SC-016a code identity) are fully
contracted and entirely absent from 91 tasks — building now yields a system that cannot redact and
that silently re-points code citations, the exact failures those requirements exist to prevent.
Container orchestration is split across two incompatible architectures resting on a claim the tree
disproves. The Answer contract is forked in the two components the plan itself marks highest-risk.

**Suggested order**: (1) the container decision — it changes T003, T015, `pipeline-cli.md` §4.8 and
H6; (2) coverage gaps C2, C3, H12, H13, M10, M16–M19 — mechanical additions against contracts that
already specify the work; (3) contract/data-model reconciliation C4, H4, M11 — must land before
Phase 2's `[TDD]` work; (4) spec amendments H2, H3, H16, M12–M14, M7; (5) open-item handling
H7–H9, H14 — consolidate the register, add settling tasks, assign the human reference;
(6) consistency and count corrections.

**Every CRITICAL and HIGH finding is a document reconciliation or a missing task — none requires
rethinking the architecture.** Two need more than editing: C1 needs an operator decision, and
H9(a) needs the 1–2 hours of blind human transcription nobody has been assigned.

## A note on why this analysis was possible

The artifacts are unusually strong where it matters most: the three-valued instrument design, the
measured rejection of Lumen chunk ids and the ULID scheme built in its place, the D-TRANS-3
deletion-bias argument, the egress-denied negative control, and above all the unverified registers.
The documents repeatedly refuse to claim what they have not measured — **including about
themselves**: `plan.md` withdraws its own `ffprobe` claim, `spec.md:145` withdraws the 75 s figure.
That discipline is the only reason this analysis could find drift at all. In a set of documents
that bluffed, none of these 49 contradictions would have been visible.
