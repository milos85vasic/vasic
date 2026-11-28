# T038 Briefing — Passage-contract review checkpoint

**Source repo:** `/home/milosvasic/Projects/vasic` (umbrella `vasic`), branch `pr/root-fixes-2026-11-27`
**Spec:** `specs/008-unified-workshop-platform` (the ACTIVE unified spec, supersedes specs/001–007)
**Task id:** `T038` (was: `001/T022`)
**Status:** `[ ]` open — human-review checkpoint, **not self-approvable**, owner: **human reviewer**
**Constraint honored:** `workshop` submodule NOT touched; read-only inspection of `submodules/passage` only.

---

## 1. Exact task text (specs/008-unified-workshop-platform/tasks.md, line 306)

```
- [ ] T038 (was: 001/T022) [REVIEW] Review the passage contract implementation against
  [contracts/passage-contract.md](../001-workshop-curriculum-platform/contracts/passage-contract.md)
  before anything consumes it — every other component depends on its shape.
  **UNBLOCKED 2026-09-15: T031-T033 (unified numbering; the predecessor tasks named here) are now done**
  — `submodules/passage/pkg/passage/symbol.go`/`ingest_match.go`/`symbol_test.go`, commit `1e361bd`,
  75/75 tests passing. The review itself remains a human judgement, not something this pass self-approves
  — **BLOCKER:** none but the review · **OWNER:** **human reviewer** (FR-037→unified FR-010)
```

Phase heading (line 285–287): **Phase 2 — Foundational — blocking prerequisites** ("52 tasks — 51 complete, 1 open… T038 remains — a human-review checkpoint, not self-approvable").

Execution marker: `[REVIEW]` = "requires an independent code or content review before it is accepted."

---

## 2. Blocker status — what "unblocked" means

**Blocker: none but the review itself.** There is no code blocker.

- Predecessors T031/T032/T033 are DONE (committed `2026-09-15`): `submodules/passage/pkg/passage/symbol.go`, `ingest_match.go`, `symbol_test.go`, all in commit `1e361bd`.
- All-code work on the passage-contract implementation is complete.
- "Unblocked" means: the implementation exists and is green, so the review can now be performed. It does **NOT** mean the task is complete — the `[ ]` state remains because a human must review and record the review.
- T038 is a **human judgement review**, not self-approvable. Owner: human reviewer.

Per `TASKS-008-UNBLOCKED.md`, T038 is one of 7 genuinely unblocked tasks (T038, T196, T289, T356, T357, T462, T543) and is the only one of them that is a pure human-review checkpoint.

---

## 3. What needs human review (specific files / contracts)

### The contract (the review standard)
**File:** `specs/001-workshop-curriculum-platform/contracts/passage-contract.md`
(Note: specs/008 itself has no `contracts/` directory — only `plan.md`, `spec.md`, `tasks.md`; the link target resolves into `specs/001-…`.)

Clauses to verify the implementation against:

| Contract area | What to check |
|---|---|
| §1–2 `pid` format/minting | ULID, 26 chars, uppercase, minted exactly once at ingest, never content-derived or positional; minting is the last branch (M4) |
| §3 source anchors | Anchor syntax `<!-- pid: … -->`, placement rules, per-format syntax, registry-only for code |
| §4 registry schema | `passages.jsonl` (source of truth) + `passages.db` (derived cache); `symbol_aliases` table; `corrections`, `redactions`, `crossrefs`, `generations` tables |
| §5.1 G1 | `pid` survives text correction; `content_hash` changes, `pid` does not; `machine_text` immutable |
| §5.2 G2 | `pid` survives line movement; `source_ref` is a cache, never a key |
| §5.3 `content_hash` | Change detection **never** identity — exhaustive permitted/forbidden uses |
| §6 code passages | Weaker, stated guarantee; `(path, symbol)` matching key; `symbol_aliases` authored vs detected; unaliased rename → loud failure (`not_in_registry`), never silent repoint |
| §7 resolution | Exactly four outcomes `found`/`redacted`/`not_in_registry`/`undetermined`; `undetermined` never collapsed into `not_in_registry`; no fuzzy/nearest-neighbour/prefix/hash fallback |
| §7.3 redaction | R1–R7 propagation (search exclusion, redacted 410, crossref suppression with `redacted_omitted`, stored-answer withdrawal, degraded generation until rebuild, append-only unredact, publication blocked until review recorded) |
| §8 ingest matching | R1a–R6 order, minting last (M4), duplicate/foreign anchor → exit 1 |
| §9 traceability | FR-037/SC-016/SC-016a mapping; G-PID-1…G-PID-6 gates each with paired mutation |

### The implementation under review
All three files live in `submodules/passage/pkg/passage/` (commit `1e361bd`):

1. **`symbol.go`** (+331 lines) — `SymbolAlias`/`SymbolAliasStore` with `byOld`/`byNew` indexes, `origin` (`authored`/`detected`), `Put` refusing a `detected` guess to overwrite an `authored` decision (`ErrAliasDowngrade`), JSONL round-trip (`LoadSymbolAliasesJSONL`/`WriteJSONL`), `SyncDB` rebuilding the `symbol_aliases` table cache.
2. **`ingest_match.go`** (+404 lines) — `IngestCode` running §8 branches R2 (exact `(path, symbol)` attach), R3 (attach through `symbol_aliases`, recording which alias used), R4 (unaliased rename: refuse + orphan old row so old pid → `not_in_registry`), M4 (mint last). `RequireAliasFunc` policy hook (caller-supplied, keeps package project-unaware). `CodeBranch` result tags every observation.
3. **`symbol_test.go`** (+499 lines) — Direct coverage of T031/T032/T033 plus **G-PID-4** (`TestGPID4_CodeIdentityGate`) and its paired mutation (`TestGPID4_PairedMutation_SilentRenameIsCaught`: silent rename-and-repoint must be caught).

### Review-record convention (pattern to follow)
Per `TASKS-008-UNBLOCKED.md` first command:
1. `cd submodules/passage && go test -count=1 ./pkg/passage/...` → confirm green.
2. Read `contracts/passage-contract.md` end-to-end.
3. Write the review record at a `specs/001-workshop-curriculum-platform/review.md`-style location for the passage contract — **not a rubber stamp**: real findings with file/line citations (this is how T060 discharged its own `[REVIEW]`, producing `specs/002-knowledge-areas-deep-linking/review.md` with findings F1–F3).

---

## 4. Dependencies and prerequisites

**Prerequisites (all satisfied):**
- T031/T032/T033 done — commit `1e361bd`, 75/75 tests passing (measured: 77 PASS / 0 FAIL at current passage HEAD; commit message records 75/75 race-enabled).
- `go build`/`go vet`/`gofmt -l` clean per commit notes; consumer-vocabulary and `Kind`-openness gates re-run (13 files scanned, 0 hits).

**Open caveat (not a blocker, record it in the review):**
- **P-U1 (UNVERIFIED)** — contract §10: the source of `symbol` for code passages has no confirmed producer. Lumen exposes no symbol table through CLI/MCP; the 58,726-symbol figure comes from its internal store. Until settled, §6's `(path, symbol)` matching key has no confirmed producer. Settle via Lumen SQLite store directly, or a Go/TS parser owned by this feature (this is T030's P-U1 settlement; T031–T033 proceeded on it being unwritten, which is fine for the review, but the review should note P-U1 as an open item).

**What consumes T038 (downstream dependents):**
- `contracts/http-api.md` — `{pid}` path parameter, citations, `410 redacted` responses.
- `contracts/pipeline-cli.md` — ingest, index, crossref, redact stages.
- Everything: "every other component depends on its shape" — a shape change after adoption is a migration.
- Redaction propagation follows in T331/T333/T353; the gate is T354 (`verify-redaction-propagation.sh`).

**T038 blocks nothing else directly** — it is itself unblocked and blocks nothing named. It is a checkpoint before consumption.

---

## 5. Commit `1e361bd` — existence and state

**Does NOT exist in the `workshop` submodule** (`git -C workshop log --oneline \| grep 1e361bd` → no match). That is expected: the commit is in `submodules/passage`, not `workshop`.

**Exists in `submodules/passage`:**
- SHA: `1e361bd6d6faf6a73813a038c1f6f78088a9cc43`
- Message: `implement T031-T033: (path,symbol) matching key, ingest_match, G-PID-4`
- Author: Милош Васић <i@mvasic.ru>, Tue Sep 15 16:05:14 2026 +0200
- Co-authored-by: Claude Sonnet 5
- Files changed (3): `pkg/passage/ingest_match.go` (+404), `pkg/passage/symbol.go` (+331), `pkg/passage/symbol_test.go` (+499); **1,234 insertions, 0 deletions**
- `git show --stat` lists exactly those 3 files.

**State at the commit:**
- `go build/vet` clean; `go test ./... -race -count=1` → `ok` (75/75 `--- PASS`, 0 FAIL), independently re-run; `gofmt -l` clean.
- Current passage HEAD is `9d97166`, which is a descendant of `1e361bd` (3 commits after it) — the implementation is still present, not reverted.

**Measured at current passage HEAD (read-only, this session):** `go test -count=1 ./pkg/passage/...` → `ok` (77 PASS / 0 FAIL). The 77 vs 75 difference is subtest counting at a later HEAD; either way, **0 failures**.

---

## 6. Recommended next action for the operator to clear T038

**This is a human-review action; it cannot be self-approved or delegated to an agent.** Recommended operator steps:

1. **Run the gate:** `cd submodules/passage && go test -count=1 ./pkg/passage/...` → confirm green (measured 77 PASS / 0 FAIL this session).
2. **Read the contract end-to-end:** `specs/001-workshop-curriculum-platform/contracts/passage-contract.md` (§1–§10), especially §5 (G1/G2 survival), §5.3 (`content_hash` never identity), §6 (code-passage weaker guarantee + `symbol_aliases` authored/detected), §7 (four-outcome resolution, no `undetermined` collapse), §7.3 (redaction R1–R7), §8 (ingest order, minting last).
3. **Read the implementation:** `submodules/passage/pkg/passage/{symbol.go,ingest_match.go,symbol_test.go}` at commit `1e361bd`; confirm each contract clause above has a corresponding implementation and gate.
4. **Record the review** at `specs/001-workshop-curriculum-platform/review.md` (matching spec 001's house style, as T060 did for the knowledge contract). Content: real findings with file/line citations, a decision (accept / require changes), the P-U1 open caveat noted, and explicit "not a rubber stamp" disposition per clause.
5. **Tick T038** `[ ]` → `[x]` only after the review record exists. Do not close on the green tests alone.

**Do not touch `workshop`** (operator directive) — the review concerns `submodules/passage` and `specs/001-…/contracts/passage-contract.md` only.
