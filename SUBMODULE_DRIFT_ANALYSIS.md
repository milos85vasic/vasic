# Submodule Drift Analysis — `vasic` umbrella

**Branch:** `pr/root-fixes-2026-11-27`
**HEAD:** `a9f71a5776b78ee864c4c569eb3bb46b7b9ef88c`
**Analysis date:** read-only snapshot, no mutations performed
**Constraint:** `workshop` and `ai_interviewing` submodules MUST NOT be touched (operator directive)

---

## 1. `git submodule status` — full output (drifted rows flagged)

```
+d508b8e16697e19490b3b8d24f08669a70b6bc0f ai_interviewing (vasic-1.0.0-dev-0.0.7-8-gd508b8e)
 e5fee6c660b9556cc1edbccffa864c9f8362d0dc design-toolkit (vasic-1.0.0-dev-0.0.7-8-ge5fee6c)
 8c7986f94dc57da128f9d0148a152abfab159a26 job_seeker (job_seeker-0.1.0-dev-0.0.1-2-g8c7986f)
 805111bad2595eb9d80a52cfb5a6d057660ba292 milosvasic.ru (v2.0.0-13-g805111b)
 35efbe8329b1276b36e82444c5d4ea7cf8271305 monetization (vasic-1.0.0-dev-0.0.7-4-g35efbe8)
+53e4b2ec008f18ceb8fbf2ed031a381f79aada77 submodules/LLMProvider (vasic-1.0.0-dev-0.0.7)
 f53c5033fdead71590a0db5a28857b4355ce8ee4 submodules/RAG (vasic-1.0.0-dev-0.0.7)
 d94e55492f10e29b2bd6eeca3c1be2adbef597f4 submodules/challenges (vasic-1.0.0-dev-0.0.7-1-gd94e554)
 2c0b3ad16a12799eefa7d8a59cdd5544857ce277 submodules/constitution (helixconstitution-v73.4-85-g2c0b3ad1)
 ec32935dbed61806b2d8b65c2ad31c5fddbe02da submodules/containers (vasic-1.0.0-dev-0.0.7-44-gec32935)
 277b96efcca472d961e9706c9416c6c9a1f49dc8 submodules/curriculum-kit (vasic-1.0.0-dev-0.0.2-1-g277b96e)
 01084c9ef060549121d5304ada0adceb4c4481db submodules/doc_processor (helix-code-1.0.0-dev-0.0.1-13-g01084c9)
 c84c410daa05fa6532f8baca826e6d0427e72c11 submodules/llm_orchestrator (helix-code-1.0.0-dev-0.0.1-17-gc84c410)
+53e4b2ec008f18ceb8fbf2ed031a381f79aada77 submodules/llm_provider (vasic-1.0.0-dev-0.0.7)
 94e666d416f0bde022d784555ec81ddd4389bb04 submodules/llms_verifier (vasic-1.0.0-dev-0.0.7)
 9d97166c481b8f95306472f6e8bc4dcfdab8bf3f submodules/passage (vasic-1.0.0-dev-0.0.7)
 b16a0897d85eb2360038d62a875854d0bfcb217b submodules/qa (helixcode-v1.1.0-205-gb16a089)
 0513361e2f9cdfa2c3b1da687a0d66e5eb7c8fd1 submodules/security (vasic-1.0.0-dev-0.0.7)
 c20ac6c1ba069cc9a72dacb8044b7b193d3dde81 submodules/superspec (v1.0.1-7-gc20ac6c)
 66984ecacf11ab8421a3a512fe4ed33532b46c09 submodules/verdict (vasic-1.0.0-dev-0.0.7)
 d52fa447d168b2023613cdd6e0bcf7e9c2148bbb submodules/vision_engine (helix-code-1.0.0-dev-0.0.1-15-gd52fa44)
 b63a3c7d23b777b7628b69510096054c5ed6d6a4 vasic.digital (v1.9.0-4-gb63a3c7)
 5a7acdd1ffe21f10e648fdcb653a2d987a8e5502 workshop (vasic-1.0.0-dev-0.0.7-9-g5a7acdd1)
```

The `+` prefix marks **worktree HEAD != index gitlink**. Exactly **3 submodules** carry it:

1. `ai_interviewing`
2. `submodules/LLMProvider`
3. `submodules/llm_provider`

All 22 remaining submodules are clean (` ` prefix, worktree == index).

---

## 2. Drift detail per submodule

### 2.1 ai_interviewing

| Source | SHA | Short |
|--------|-----|-------|
| Index gitlink (`git ls-files -s ai_interviewing`) | `30da69613e88a7cc62ecd4b99b1849f864a48b44` | `30da6961` |
| Worktree HEAD (`git -C ai_interviewing rev-parse HEAD`) | `d508b8e16697e19490b3b8d24f08669a70b6bc0f` | `d508b8e` |
| Remote `origin HEAD` (`git -C ai_interviewing ls-remote origin HEAD`) | `d508b8e16697e19490b3b8d24f08669a70b6bc0f` | `d508b8e` |

**Relationship:** Worktree == remote. The index is behind both.

Ancestry check inside `ai_interviewing`: `git merge-base --is-ancestor 30da6961 d508b8e` → TRUE. The index SHA is an ancestor of the worktree/remote SHA, so **FF from index → worktree is possible** (1 commit ahead).

**Constraint:** Operator directive — `ai_interviewing` MUST NOT be touched. No remediation may be applied to this submodule.

---

### 2.2 submodules/LLMProvider

| Source | SHA | Short |
|--------|-----|-------|
| Index gitlink (`git ls-files -s submodules/LLMProvider`) | `bd302c8ab57d0040df87ccbb90c8ccf969bf687b` | `bd302c8a` |
| Worktree HEAD (`git -C submodules/LLMProvider rev-parse HEAD`) | `53e4b2ec008f18ceb8fbf2ed031a381f79aada77` | `53e4b2ec` |
| Remote `origin HEAD` (`git -C submodules/LLMProvider ls-remote origin HEAD`) | `97af6f0c7ef43f47f1100937b6e3a12835c9b1e4` | `97af6f0c` |

**Relationship:** All three SHAs differ, but they are **linear, not branched**:

- `git merge-base --is-ancestor 53e4b2ec bd302c8a` → TRUE → worktree is an ancestor of index
- `git merge-base --is-ancestor bd302c8a 97af6f0c` → TRUE → index is an ancestor of remote
- `git merge-base --is-ancestor 53e4b2ec 97af6f0c` → TRUE → worktree is an ancestor of remote

So the true ordering is:

```
worktree (53e4b2ec) → index (bd302c8a) → remote (97af6f0c)
   oldest                      newest
```

The working tree is **behind both** index and remote, on the same line of history. There is no true divergence (no commit exists on one branch that is not an ancestor of another). FF is possible in both directions:

- `git -C submodules/LLMProvider submodule update` → aligns worktree to index (`bd302c8a`), FF-able
- `git -C submodules/LLMProvider pull` → aligns worktree to remote (`97af6f0c`), FF-able

---

### 2.3 submodules/llm_provider

| Source | SHA | Short |
|--------|-----|-------|
| Index gitlink (`git ls-files -s submodules/llm_provider`) | `bd302c8ab57d0040df87ccbb90c8ccf969bf687b` | `bd302c8a` |
| Worktree HEAD (`git -C submodules/llm_provider rev-parse HEAD`) | `53e4b2ec008f18ceb8fbf2ed031a381f79aada77` | `53e4b2ec` |
| Remote `origin HEAD` (`git -C submodules/llm_provider ls-remote origin HEAD`) | `97af6f0c7ef43f47f1100937b6e3a12835c9b1e4` | `97af6f0c` |

**Relationship:** Identical to `submodules/LLMProvider`. All three SHAs differ but are linear:

```
worktree (53e4b2ec) → index (bd302c8a) → remote (97af6f0c)
   oldest                      newest
```

Same FF possibilities as LLMProvider. This is the same underlying repository (vasic-digital/LLMProvider) checked out at two different paths (`submodules/LLMProvider` and `submodules/llm_provider`), both with the same worktree SHA.

---

## 3. ai_interviewing relationship (index vs worktree vs remote)

- **Index** `30da6961` — what the umbrella will commit if `git add ai_interviewing` is run; also what `verify-manifest-pins.sh` and `helix-deps.yaml` record.
- **Worktree** `d508b8e` — what is actually checked out on disk right now.
- **Remote** `d508b8e` — what `origin` reports as its HEAD.

Worktree == remote: the on-disk checkout matches the upstream tip exactly. The index is one commit behind (`30da6961` is an ancestor of `d508b8e`). From the umbrella's perspective, the worktree has moved forward to match remote but the index gitlink was never updated, so `git submodule status` shows `+`.

**Operator directive:** `ai_interviewing` MUST NOT be touched. The drift is pre-existing (not caused by this session) and must remain as-is. No `git submodule update`, no `git add`, no `git commit` on this submodule.

---

## 4. Why `submodules/LLMProvider` and `submodules/llm_provider` diverged

They did not diverge in the branch-and-merge sense. All three commits (`worktree` `53e4b2ec`, `index` `bd302c8a`, `remote` `97af6f0c`) lie on one straight line:

```
53e4b2ec (worktree) ← bd302c8a (index) ← 97af6f0c (remote)
  oldest                 middle          newest
```

The worktree is simply checked out at an older commit than both the index and the remote. This is pre-existing drift (not caused by this session). Both paths point at the same underlying repository (`vasic-digital/LLMProvider`) and both worktrees happen to sit at `53e4b2ec`, while both index gitlinks record `bd302c8a` and both remotes report `97af6f0c`.

Because the relationship is linear, either alignment target is FF-able:
- Aligning worktree → index: `git -C submodules/LLMProvider submodule update` (FF, `53e4b2ec` → `bd302c8a`)
- Aligning worktree → remote: `git -C submodules/LLMProvider pull` (FF, `53e4b2ec` → `97af6f0c`)

The same applies to `submodules/llm_provider`.

---

## 5. Drift summary table

| Submodule | Index SHA | Worktree SHA | Remote SHA | Relationship | Recommended action | Operator decision needed? |
|-----------|-----------|--------------|------------|--------------|-------------------|---------------------------|
| `ai_interviewing` | `30da6961...` | `d508b8e...` | `d508b8e...` | Worktree == remote; index is 1 behind (FF-able index→worktree) | **Leave as-is** — operator directive forbids touching | YES (directive already given: do not touch) |
| `submodules/LLMProvider` | `bd302c8a...` | `53e4b2ec...` | `97af6f0c...` | Linear: worktree → index → remote; worktree behind both | FF worktree to index (`submodule update`) OR FF worktree to remote (`pull`) | YES — choose alignment target |
| `submodules/llm_provider` | `bd302c8a...` | `53e4b2ec...` | `97af6f0c...` | Linear: worktree → index → remote; worktree behind both | FF worktree to index (`submodule update`) OR FF worktree to remote (`pull`) | YES — choose alignment target |

---

## 6. `helix-deps.yaml` entries vs index vs worktree SHAs

| Submodule | `helix-deps.yaml` ref | Index gitlink | Worktree HEAD | Match index? | Match worktree? |
|-----------|----------------------|---------------|---------------|--------------|-----------------|
| `ai_interviewing` | `30da69613e88a7cc62ecd4b99b1849f864a48b44` | `30da6961...` | `d508b8e...` | YES | NO |
| `submodules/LLMProvider` | `bd302c8ab57d0040df87ccbb90c8ccf969bf687b` | `bd302c8a...` | `53e4b2ec...` | YES | NO |
| `submodules/llm_provider` | `bd302c8ab57d0040df87ccbb90c8ccf969bf687b` | `bd302c8a...` | `53e4b2ec...` | YES | NO |

All three `helix-deps.yaml` entries match their **index** SHAs, not their worktree SHAs. This is by design — `verify-manifest-pins.sh` compares manifest refs against the index gitlink, and it passes (22 MATCH / 0 DRIFT) precisely because the manifest and index agree even where the working tree does not.

---

## 7. What `verify-manifest-pins.sh` sees vs what `git submodule status` sees

**`verify-manifest-pins.sh`** (exit 0, 22 MATCH / 0 DRIFT):
- Compares `helix-deps.yaml` `deps[].ref` against the **index gitlink** (`git ls-files -s -- <path>`).
- Reports MATCH for all three drifted submodules because their manifest refs equal their index SHAs.
- Emits an `ℹ NOTE` for each drifted submodule noting the working tree is checked out at a different SHA, but explicitly states: *"not a verdict input (uncommitted local state)"*.
- **Passes despite drift** because it never looks at the submodule working tree's HEAD. It is a record-vs-index check, not a record-vs-worktree check.

**`git submodule status`** (shows `+` prefix):
- Compares the **index gitlink** against the **submodule working tree HEAD** (`git -C <submodule> rev-parse HEAD`).
- Reports `+` for exactly the three drifted submodules because worktree != index.
- Is blind to whether worktree == remote or whether the manifest matches the index.

**Why `verify-manifest-pins.sh` passes despite drift:** The gate's contract (§11.4.31 PIN half) is "every `deps[].ref` equals the gitlink this repository will commit" — i.e. manifest vs index. Working-tree state inside a submodule is uncommitted local exploration, not a recorded state. The gate treats it as a NOTE, never as a DRIFT verdict, precisely so that a developer checking a submodule out to look at something does not red-line the tree. The drift is real but invisible to this instrument by design.

---

## 8. What can be fixed without an operator decision (read-only analysis)

| Submodule | Can be fixed without operator decision? | Reason |
|-----------|-----------------------------------------|--------|
| `ai_interviewing` | **NO** | Operator directive forbids touching it. |
| `submodules/LLMProvider` | **NO** (read-only session) | FF is technically possible, but choosing index vs remote as alignment target is an operator decision. This session must not mutate anything. |
| `submodules/llm_provider` | **NO** (read-only session) | Same as LLMProvider. |

**No drift can be remediated in this session** — the constraint is read-only (no edit, commit, or push). Even where FF is technically trivial, performing it would require a commit to the umbrella (updating the gitlink) or a submodule working-tree change, both of which are mutations outside this session's scope.

---

## 9. Priority order for remediation

1. **`submodules/LLMProvider`** — highest priority among actionable items. It is an owned consumer submodule adopted under §11.4.74 catalogue-check, consumed by Go code via `replace digital.vasic.llmprovider => ./submodules/LLMProvider`. Its worktree is behind both index and remote; aligning it restores worktree == index. Decision needed: align worktree to index (`submodule update`, matches what the umbrella will commit) or to remote (`pull`, picks up upstream changes not yet in the index).
2. **`submodules/llm_provider`** — same priority profile as LLMProvider; same underlying repository, same divergence shape. Decision needed: same alignment choice.
3. **`ai_interviewing`** — worktree == remote (already aligned with upstream), index is 1 behind. Remediation would be FF index → worktree (`git add ai_interviewing`), but **operator directive forbids touching it**. Leave as-is; document as accepted pre-existing drift.

---

## 10. Honest boundary

This is a read-only analysis. No files were edited, no submodules were checked out or updated, no commits were made, and no pushes were performed. All SHAs were measured live from the working tree, the index, and the remotes during this session. The drift is pre-existing and not caused by this session.
