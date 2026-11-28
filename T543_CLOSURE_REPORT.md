# T543 Closure Report — investigation only, no files modified

**Task:** T543 (unified), source task `003/T037`
**Location:** `specs/008-unified-workshop-platform/tasks.md` (unified), Phase 17 — Polish and cross-cutting concerns
**Source location:** `specs/003-chapter-hierarchy/tasks.md` Phase 6 — Gates, manifest, closure
**State:** `[ ]` — NOT started / open in both files
**Marker:** `[REVIEW]`
**Back-reference:** `(was: 003/T037)`

---

## 1. Full task text

### Unified (T543) — `specs/008-unified-workshop-platform/tasks.md`, Phase 17

```
- [ ] T543 (was: 003/T037) [REVIEW] Closure: publish `max_depth_present` as a **measurement** and assert no constant
      bounds depth (H6, 003:SC-021→unified SC-025); record the feature's limits in `workshop/docs/limits.md`,
      including that `02` and `02.01` remain **archived and uningested** and that nothing here
      ingests them; update `CONTINUATION.md` in the same change; and run the gate-coverage check
      below to confirm every contracted gate is carried by a task (FR-003→unified FR-017, SC-021→unified SC-025)
      — AUDIT 2026-09-08: PARTIAL — `max_depth_present` IS published as a measurement (LIVE: `GET /api/chapters` 200 returns `"max_depth_present": 2`, computed by `MaxDepthPresent`, pkg/curriculum/chapterid.go:325). MISSING: `workshop/docs/limits.md` exists but records nothing about hierarchy, the archived/uningested status of `02` and `02.01`, or a no-constant-bounds-depth assertion; and no gate-coverage check confirms every contracted gate is carried by a task.
```

### Source (T037) — `specs/003-chapter-hierarchy/tasks.md`, Phase 6

```
- [ ] T037 [REVIEW] Closure: publish `max_depth_present` as a **measurement** and assert no constant
      bounds depth (H6, 003:SC-021); record the feature's limits in `workshop/docs/limits.md`,
      including that `02` and `02.01` remain **archived and uningested** and that nothing here
      ingests them; update `CONTINUATION.md` in the same change; and run the gate-coverage check
      below to confirm every contracted gate is carried by a task (FR-003, SC-021)
      — AUDIT 2026-09-08: PARTIAL — `max_depth_present` IS published as a measurement (LIVE: `GET /api/chapters` 200 returns `"max_depth_present": 2`, computed by `MaxDepthPresent`, pkg/curriculum/chapterid.go:325). MISSING: `workshop/docs/limits.md` exists but records nothing about hierarchy, the archived/uningested status of `02` and `02.01`, or a no-constant-bounds-depth assertion; and no gate-coverage check confirms every contracted gate is carried by a task.
```

**Requirement anchors:** `003:SC-021` → unified `SC-025`; `003:FR-003` → unified `FR-017`; H6 (no constant bounds depth). SC-025 verbatim from `specs/003-chapter-hierarchy/spec.md`: *"The maximum depth present is measured and published, and no depth limit is asserted anywhere."*

---

## 2. What already EXISTS (measurement side — the task is PARTIAL, not from-zero)

| Item | State | Evidence |
|---|---|---|
| `max_depth_present` published on `/api/chapters` | **LIVE** | `GET /api/chapters` 200 returns `"max_depth_present": 2` |
| Computed by | `MaxDepthPresent` | `workshop/platform/backend/pkg/curriculum/chapterid.go:325` |
| Serialized in API response | `workshop/platform/backend/cmd/workshop-server/main.go:3404` field `MaxDepthPresent int`, emitted at `:3668` | `"max_depth_present": list.MaxDepthPresent` |
| Doc comment states "measurement, never a limit" | `main.go:3398` | "`- `max_depth_present` — H6. A MEASUREMENT, never a limit. No constant..." |
| Measured over WHOLE tree, not filtered set | `cmd/workshop-server/chapters_filter_test.go:145-148` | asserts `max_depth_present = 2` "measured over the whole tree, not the filtered set" |
| Three-deep fixture asserts 3 | `cmd/workshop-server/chapters_hierarchy_test.go:59,142` | `MaxDepthPresent int`, asserts `want 3` |
| Front-end flat spec | `workshop/platform/frontend/src/app/core/api-chapters-flat.spec.ts:40,82,141` | `"max_depth_present": 2` / `:1` variants |
| Contract examples | `specs/003-chapter-hierarchy/contracts/http-api.md:82,204,381` | `"max_depth_present": 2` // MEASURED, never a limit; U3 measured at 2 |
| Unified spec anchor | `specs/008-unified-workshop-platform/spec.md:1987` | SC-025 (was: 003/SC-021) |
| "No constant bounds it (H6)" | `workshop/platform/backend/pkg/curriculum/chapterid.go:98` | Depth() comment |
| Gate asserting no depth limit | `workshop/platform/gates/verify-chapter-depth-unbounded.sh` (G-CH-22, for 008/FR-017, was 003/FR-003) | rc 0 path / rc 1 real problem / rc 2 could-not-determine |
| Paired prover | `workshop/platform/gates/prove-chapter-depth-unbounded.sh` | mutation arms M11, post-restore re-green |
| Registry row | `workshop/platform/gates/check-registry-002.tsv:1317` | `check G-CH-22 shell platform/gates/verify-chapter-depth-unbounded.sh` |

**Conclusion on the measurement half:** `max_depth_present` IS already published as a measurement, and the no-constant-bounds-depth gate exists and is registered. This half of T543 is done; the audit's "MISSING" verdict predates this work.

---

## 3. What is MISSING / still open (per the task text and the 2026-09-08 audit)

### 3a. `workshop/docs/limits.md` hierarchy section

`workshop/docs/limits.md` exists (2,273 lines, 117 headings per earlier measurements) but **records nothing about chapter hierarchy**. Per the task, it must record:

1. `max_depth_present` as a **measurement** (value + corpus size it was measured against, side by side).
2. A **no-constant-bounds-depth assertion** (search for a hardcoded chapter-count/depth ceiling must return nothing — this is SC-032's companion: "no assertion of a maximum chapter count exists anywhere in the codebase").
3. The status of `02` and `02.01` — task text says they should remain **archived and uningested** and that nothing here ingests them.

**Critical conflict found:** The task text's claim that `02` and `02.01` "remain archived and uningested" is **FALSE at the current tip**. `limits.md` §10.29 (re-measured 2026-10-21) states this explicitly and records measured ingestion:

| chapter scope | passages in `curriculum/passages.jsonl` | directory |
|---|---:|---|
| `02` | **1369** | present (`transcript.md`, `.segments.json`, `.words.json`, `knowledge/`) |
| `02.01` | **54** | present |

`CONTINUATION.md` session 2026-09-05 confirms: "Sub-chapter `02.01` is transcribed, ingested, knowledge-extracted and served" and "Chapter `02` is ingested and knowledge-extracted."

**So an honest implementation of T543 must NOT repeat the stale "archived and uningested" claim.** It must record the actual measured state (`02` and `02.01` are ingested) and note that the earlier archival decision was superseded by events, with the date/deciding record unconfirmed/not traced — exactly as `limits.md` §10.29 already does. The operator must decide whether to keep that wording or restate it.

### 3b. `CONTINUATION.md` sync

Current `CONTINUATION.md` state:
- `Last-Updated: 2026-11-25T21:00:00Z`
- `Synced-Commit: a2d694731096`
- `Authority-Root: submodules/constitution`

The file references `limits.md` in several places (§3 active work mentions per-session limits updates; lines 2923, 3197, 3288, 3339, 3429, 4145, 9712, 9772, 9782, 9970, 10152, 10444, 10720, 10782, 10934), but **does not mention T543, `003/T037`, `max_depth_present`, or the hierarchy-limits section of `limits.md`**. A `max_depth_present`/`limits.md` §10.x entry does not appear in §3 active work.

Per §12.10 protection 2, every non-trivial state change must update `CONTINUATION.md` in the same commit. Closing T543 (limits.md edit + gate-coverage check run) is a non-trivial state change, so `CONTINUATION.md` needs a §3 "Active work" entry recording T543's closure, the files touched, the measurement basis, and commands to resume/re-verify.

### 3c. Gate-coverage check ("every contracted gate is carried by a task")

The task says to "run the gate-coverage check below to confirm every contracted gate is carried by a task."

Mechanism found: `workshop/scripts/verify.sh` implements `gate_contract_coverage()` (line 624), which reads the canonical G-CLI/G-HTTP/G-PID identifier set live from the 3 contract files and cross-references every discovered gate. T529 extended `verify.sh` (850→1124 lines) with `gate_contract_coverage()` (V8) and `prove_fleet()`, which executes every discovered gate's real sibling `prove-*.sh` or self-hosted `--prove-failure` arm and classifies PROVEN/VACUOUS/UNDET.

For the chapter-hierarchy gate family specifically:
- `check-registry-003.tsv` registers the G-CH-* family as one row (per T542's completion note).
- `verify-chapter-depth-unbounded.sh` (G-CH-22) is registered in `check-registry-002.tsv:1317` (note: cross-registry — the G-CH gate lives in 002's registry file).

Per the T543 audit note: **"no gate-coverage check confirms every contracted gate is carried by a task."** This remains the open item. Running `verify.sh` with `--prove-failure` (or the gate-coverage path) is the required check; the operator decides whether the existing `gate_contract_coverage()`/`prove_fleet()` coverage satisfies "every contracted gate is carried by a task" or whether a dedicated check is needed.

---

## 4. Hierarchy-limits documentation searched

Relevant hierarchy-limit material found:

- `specs/003-chapter-hierarchy/spec.md:679` — SC-021 (measured/published, no depth limit)
- `specs/003-chapter-hierarchy/spec.md:779` — "A depth limit. Measured and published, never asserted."
- `specs/003-chapter-hierarchy/data-model.md:265` — "No depth limit. H6."
- `specs/003-chapter-hierarchy/contracts/http-api.md:82,204,381` — `max_depth_present` examples marked MEASURED
- `specs/008-unified-workshop-platform/spec.md:1987` — SC-025 unified anchor
- `specs/008-unified-workshop-platform/spec.md:2763` — "A nested chapter tree on the wire; the array stays flat. A depth limit; measured and published, never asserted."
- `workshop/platform/backend/pkg/curriculum/chapterid.go:98` — "No constant bounds it (H6)"
- `workshop/platform/gates/verify-chapter-depth-unbounded.sh` — G-CH-22 gate + paired prover
- `workshop/docs/limits.md` §10.29 (re-measured 2026-10-21) — already records `max_depth_present` as measurement, no-constant-bound assertion via gate, and the `02`/`02.01` ingested-status correction

---

## 5. CONTINUATION.md — current state and what needs syncing

**Current header (verified):**
```
Last-Updated: 2026-11-25T21:00:00Z
Synced-Commit: a2d694731096
Authority-Root: submodules/constitution
```

**What references `limits.md` / hierarchy already:** multiple places (lines 2923, 3197, 3288, 3339, 3429, 4145, 9712, 9772, 9782, 9970, 10152, 10444, 10720, 10782, 10934), but none name T543, `003/T037`, `max_depth_present`, or a hierarchy-limits section. §3 "Active work" has no T543 entry.

**What T543 requires for CONTINUATION.md:** a §3 active-work entry (in the same change as the limits.md edit) recording:
- T543 / `003/T037` closure: `max_depth_present` published as measurement (value 2, over whole tree), no-constant-bounds-depth assertion via `verify-chapter-depth-unbounded.sh` (G-CH-22), hierarchy limits recorded in `workshop/docs/limits.md` §10.29.
- The corrected `02`/`02.01` status (ingested, not archived — with the unconfirmed date/deciding record caveat).
- Gate-coverage check run (`verify.sh` `--prove-failure` / `gate_contract_coverage`) and its result.
- Commands to re-verify: `curl .../api/chapters | jq .max_depth_present`, `bash workshop/platform/gates/verify-chapter-depth-unbounded.sh`, `bash workshop/scripts/verify.sh --prove-failure`.

Note per §12.10 honest boundary: a `CONTINUATION.md` edit is a dated observation, rc=0 on `continuation-check.sh` is a moment-in-time measurement; it goes stale as the tree moves.

---

## 6. Summary — what T543 requires and the files to create/modify

**T543 requires (all four clauses):**

1. **Publish `max_depth_present` as a measurement** — ALREADY DONE (live on `/api/chapters`, value 2, computed by `MaxDepthPresent` in `pkg/curriculum/chapterid.go`, asserted in two tests). No code change needed; the report must state this is measured, not a limit.
2. **Assert no constant bounds depth** — ALREADY GATED (G-CH-22 `verify-chapter-depth-unbounded.sh` + paired prover, registered). No code change needed; the report must cite it.
3. **Record the feature's limits in `workshop/docs/limits.md`** — §10.29 already exists (re-measured 2026-10-21) recording the measurement, the no-constant-bound assertion, and the corrected `02`/`02.01` ingested status. The task text's "archived and uningested" claim is FALSE at this tip; the implementation must record the measured state instead. The operator decides final wording.
4. **Update `CONTINUATION.md` in the same change** — NOT done for T543; needs a §3 active-work entry.
5. **Run the gate-coverage check** — NOT confirmed done; run `verify.sh --prove-failure` / `gate_contract_coverage()` and confirm every contracted gate is carried by a task.

**Files to create/modify (investigation only — not modified by me):**

| File | Action | Reason |
|---|---|---|
| `workshop/docs/limits.md` | Modify — verify/complete §10.29 hierarchy section | Record `max_depth_present` measurement + corpus size, no-constant-bounds-depth assertion, `02`/`02.01` ingested status (corrected, not "archived and uningested") |
| `CONTINUATION.md` | Modify — §3 active work entry | §12.10: same-commit sync of the limits.md change; record T543 closure, measurement basis, re-verify commands |
| (no new file) | Run `bash workshop/scripts/verify.sh --prove-failure` | Gate-coverage check: every contracted gate carried by a task |
| (no new file) | Run `bash workshop/platform/gates/verify-chapter-depth-unbounded.sh` | Re-confirm G-CH-22 green (rc 0) |
| (no new file) | `curl -s http://127.0.0.1:8087/api/chapters \| jq .max_depth_present` | Confirm live measurement returns 2 |

**Open decisions for the operator:**
- Whether `limits.md` §10.29's wording (`02`/`02.01` ingested, not archived) is acceptable, given the task text still says "archived and uningested."
- Whether existing `gate_contract_coverage()`/`prove_fleet()` coverage satisfies "every contracted gate is carried by a task," or a dedicated gate-coverage check must be added.
- The unconfirmed date/deciding record of the `02`/`02.01` un-archival (not traced in the tree).

**No files were modified in this investigation.** This report is the sole artifact produced.
