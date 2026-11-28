# T289 — Video Text Alternatives (205 materials)

**Spec:** `specs/008-unified-workshop-platform`
**Report date:** 2026-11-27
**Source of task text:** `specs/008-unified-workshop-platform/tasks.md` line 1442 (and source `specs/006-session-record-and-qa-readiness/tasks.md` line 138)

---

## 1. Full task text and source back-reference

### Unified task (specs/008-unified-workshop-platform/tasks.md, line 1442)

```
- [ ] T289 (was: 006/T044) [P] [SUBAGENT] [US4] Author text alternatives for the 205 video materials (FR-016→unified FR-119, FR-028→unified FR-268). **Evidence needed**: 205 of 213 carry `alt: ""`; the interface names the absence rather than hiding it, so this is a disclosed gap, not a hidden one.
```

- **Unified id:** T289
- **Source id:** 006/T044
- **Phase:** Phase 8 — US13 + US14 + US15 — deep linking, video anchors and materials
- **State:** `[ ]` open (unticked)
- **Markers:** `[P] [SUBAGENT] [US4]`
- **FR mapping:** FR-016 → unified FR-119; FR-028 → unified FR-268

### Source task (specs/006-session-record-and-qa-readiness/tasks.md, line 138)

```
- [ ] T044 [P] [SUBAGENT] [US4] Author text alternatives for the 205 video materials (FR-016, FR-028). **Evidence needed**: 205 of 213 carry `alt: ""`; the interface names the absence rather than hiding it, so this is a disclosed gap, not a hidden one.
```

### Unblocked summary (TASKS-008-UNBLOCKED.md, section 3)

| Field | Value |
|---|---|
| Unified id | T289 |
| Source | (was: 006/T044) |
| Phase | Phase 8 — US13 + US14 + US15 |
| State | `[ ]` open (genuinely unblocked) |
| Files mentioned | `workshop/curriculum/` video materials (213 total; 205 carry `alt: ""`), `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts` (renders materials in place with captions, T321) |
| Markers | `[P] [SUBAGENT] [US4]` |
| Dependencies | None block starting. Genuine editorial/accessibility work — author text alternatives for 205 video materials, not auto-generable from outside this scope. The interface already names the absence (`alt: ""`) rather than hiding it — a disclosed gap, not a hidden one. |
| First command | `grep -rn 'alt' workshop/curriculum/ --include='*.json' --include='*.jsonl'` |
| Notes | Editorial task, not engineering. Counts only (205 of 213) — no transcript text, no personal names. |

### Cross-references

- `docs/QA-CANDIDATE.md` line 412 (QA-006-13): lists T289 as a KNOWN-DEFECT — "205 of 213 video materials have `alt: ""`; the UI names the absence (`material-noalt-<id>` in `area-lessons.component.ts`) but the text is not authored." **This appears stale** — see Section 2.
- `workshop/evidence/n7/verification/cluster-4.tsv` line 28: FR-119 marked PARTIAL — alt portion passes (`verify-material-alt rc0`), but 8 diagram materials lack captions (a separate concern, not T289).
- `workshop/docs/superpowers/plans/2026-09-08-qa-handover-remainder.md` section "Task A1": original task plan with steps 1–7 (measure, write failing gate, confirm fail, author alternatives, regenerate, prove gate, register/commit).
- `SPECS008_UNBLOCKED_REPORT.md`: T289 listed as autonomously startable ("No blocker stated"); one of four agent-startable open tasks (T038, T289, T462, T543).

---

## 2. What video text alternatives exist in the repository

### Current measured state (authoritative, measured 2026-11-27)

| Metric | Value |
|---|---|
| Total materials across all catalogs | 213 |
| Video materials | 205 |
| Diagram materials | 8 |
| Video materials with non-empty `alt` | **205 (100%)** |
| Video materials with empty `alt` (`""`) | **0** |
| Video materials missing `alt` key | **0** |
| Diagram materials with non-empty `alt` | 8 |
| Diagram materials with empty `caption` | 8 (separate concern — FR-119 PARTIAL due to diagram captions) |

**Gate verification:** `TestEveryServedMaterialCarriesTextAlternative` (`workshop/platform/backend/pkg/learning/material_alt_test.go`) — **PASS**:

```
MEASURED: 213 material(s) across 42 area(s), every one carrying a non-empty served `alt` distinct from its own title and caption
```

**The three offence arms all pass:**
- A1 absent key: 0 offenders
- A2 empty or blank alt: 0 offenders
- A3 restatement of title/caption: 0 offenders

### Where alternatives live

Each video material in `workshop/curriculum/learning/NN-<slug>.json` carries an `alt` field inside its `materials[]` entry, alongside `id`, `kind`, `title`, `caption`, `uri`, and `video` (with `chapterId`, `startMillis`, `endMillis`, `transcriptAnchor`).

Example from `02-context-window-and-compression.json`, lesson `l02`, material `v00`:

```json
{
  "id": "01M1XZB0ZDG9C311SHFQDYRQCS-l02-v00",
  "kind": "video",
  "title": "Chapter 01 — 3:04",
  "caption": "1 matching passage(s) across 12s of recording",
  "uri": "/chapters/01/transcript?t=184.4&end=196.0#p-01M1ET0MFJ4NDK0ZECKNTQFVXS",
  "video": {
    "chapterId": "01",
    "startMillis": 184380,
    "endMillis": 196020,
    "transcriptAnchor": "01M1ET0MFJ4NDK0ZECKNTQFVXS"
  },
  "alt": "The setup, one sentence long. Context size is named as \"the main difference that works for us now,\" and immediately as \"where things are becoming problematic.\" This is the hinge out of Area 01 and into this one; it states the problem without yet naming the mechanism."
}
```

All 37 catalog JSON files contain video materials with populated `alt` fields. The alternatives convey **content** (what is taught in that stretch), derived from the area document's prose around the time link — they do not restate the title or caption.

### Existing gates and tests (already created)

| File | Purpose | Status |
|---|---|---|
| `workshop/platform/gates/verify-material-alt.sh` | Three-valued gate (0/1/2) asserting every material carries a usable `alt` | Created, executable, passes |
| `workshop/platform/gates/prove-material-alt.sh` | §1.1 paired mutation proof (M1–M9: control, empty, absent-key, whitespace-only, restatement, vacuity, precedence) | Created, executable, passes |
| `workshop/platform/backend/pkg/learning/material_alt_test.go` | Go test driving A1 arm over the authored catalog | Created, passes |
| `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts` | Renders materials; line 267 has `material-noalt-<id>` fallback for materials without alt (dead code — never triggers since all materials now have alt) | Exists |

### Stale / contradictory documentation

- `docs/QA-CANDIDATE.md` line 412 (QA-006-13): still lists T289 as KNOWN-DEFECT claiming "205 of 213 video materials have `alt: ""`". **Contradicted by live measurement** — all 205 have non-empty `alt`.
- `specs/008-unified-workshop-platform/tasks.md` line 1442: T289 still marked `[ ]` open. **Contradicted by live measurement** — the alternatives appear already authored.
- `specs/006-session-record-and-qa-readiness/tasks.md` line 138: T044 still marked `[ ]` open. Same contradiction.
- `workshop/docs/qa/MANUAL-TEST-PLAN.md` step 9.2 and 14.4: "all 205 videos carry a non-empty `caption` AND a non-empty `alt` — the F4 empty-alt finding is FIXED; do not file it." Consistent with live measurement.

---

## 3. What needs to be created/modified

Based on the handover plan (`workshop/docs/superpowers/plans/2026-09-08-qa-handover-remainder.md`, Task A1):

| Step | Plan | Current state |
|---|---|---|
| 1 | Measure the real state before writing anything | **Done** — 205/205 videos have non-empty `alt`; gate passes |
| 2 | Write the failing gate first | **Done** — `verify-material-alt.sh` exists |
| 3 | Run it and confirm it FAILS | **N/A** — gate passes on current tree (rc 0) |
| 4 | Author the alternatives | **Appears done** — all 205 videos have content-carrying `alt` |
| 5 | Regenerate and re-run | **Done** — `build_learning_catalog.py` produces catalog with alt populated; gate rc 0 |
| 6 | Prove the gate detects | **Done** — `prove-material-alt.sh` passes all mutations M1–M9 |
| 7 | Register and commit | `verify-material-alt.sh` should be registered in `platform/gates/check-registry-006.tsv` (verify registration status) |

### What appears to already be in place

- All 205 video `alt` fields authored across 37 catalog JSON files
- `verify-material-alt.sh` gate (A1 in-process + A2 live arms)
- `prove-material-alt.sh` mutation proof
- `material_alt_test.go` Go test
- Gate registration should be verified in `platform/gates/check-registry-006.tsv`

### What may still need attention (not T289 proper, but related)

- The 8 `diagram` materials have empty `caption` fields (surviving half of F4 per manual test plan §0c) — this is tracked under FR-119 PARTIAL in `cluster-4.tsv`, **not** under T289.
- The `material-noalt-<id>` fallback in `area-lessons.component.ts` line 267 is now dead code (no material lacks alt). It may be safe to leave or remove, but that is outside T289's scope.
- `docs/QA-CANDIDATE.md` line 412 and `tasks.md` line 1442 both still reference the old "205 of 213 have `alt: ""`" state — these records are stale and should be updated to reflect the current state, but that is documentation maintenance, not T289's authoring work.

---

## 4. Any blockers

| Blocker | Source | Status |
|---|---|---|
| None stated | SPECS008_UNBLOCKED_REPORT.md §3 | **No blocker** — "No blocker stated" |
| None stated | TASKS-008-UNBLOCKED.md section 3 | **None block starting** — "genuine editorial/accessibility work" |
| Migration gates M1–M6 | SPECS008_UNBLOCKED_REPORT.md §5 | Unsatisfied but **block nothing** currently open outside Phase 16; M0 satisfied |
| Operator/human gating | SPECS008_UNBLOCKED_REPORT.md §5 | T289 is **not** in the operator/human-blocked list (T521, T527, T530, T553, T554, T573 are) |

### Summary assessment

**T289 appears to be substantially complete based on live measurement.** All 205 video materials carry non-empty, content-carrying `alt` text distinct from title and caption. The gate `verify-material-alt.sh` passes (rc 0), its paired mutation proof `prove-material-alt.sh` passes all mutations, and the Go test `TestEveryServedMaterialCarriesTextAlternative` passes. No operator, human, predecessor, or structural blocker applies.

However, the task remains marked `[ ]` open in both `specs/008-unified-workshop-platform/tasks.md` and `specs/006-session-record-and-qa-readiness/tasks.md`, and `docs/QA-CANDIDATE.md` still lists it as a KNOWN-DEFECT. These records appear **stale** relative to the measured state of the repository. If the intent is to close T289, the next steps would be:

1. Re-verify the gate passes (done — rc 0).
2. Confirm gate registration in `platform/gates/check-registry-006.tsv`.
3. Tick T289 as complete in `specs/008-unified-workshop-platform/tasks.md` (and source `specs/006-session-record-and-qa-readiness/tasks.md`).
4. Update `docs/QA-CANDIDATE.md` QA-006-13 to reflect that the empty-alt finding is fixed.
5. Consider whether the `material-noalt-<id>` dead-code path in `area-lessons.component.ts` should be removed.

**No source files were modified in producing this report.**
