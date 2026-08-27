# Post-apply state — what is now MEASURED

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-08-27 |
| Status | active |
| Status summary | The constitution propagation described in [`propagation/APPLY.md`](propagation/APPLY.md) has been applied and pushed to five owned submodules. This document replaces the projections in [`propagation/PROOF.md`](propagation/PROOF.md) §7 with measurements taken against the live tree. Sweep verdict is unchanged (37 PASS / 21 FAIL / 0 ERROR, exit 1) and that is the correct outcome; the *inside* of the propagation gates moved as predicted. Two previously projected effects are settled: one materialised, one did **not**. |
| Constitution HEAD | `448981ae3498229c734dc60719f4b19f01d7a75f` |
| Scope | Read-only measurement. No submodule working tree was written to. No mutating git command was run. No gate, script, test, `Constitution.md`, `helix-deps.yaml` or root carrier was modified. The only file created is this one. |

> **§11.4.65 disclosure.** This document ships without its `.html` and `.pdf`
> siblings — the same known, disclosed deviation `INVENTORY.md` records as gap
> **G8** and `RISKS.md` records as R7 for this whole directory.

---

## 1. The sweep — before and after

Command, verbatim:

```
$ bash scripts/verify-all-constitution-rules.sh ; echo "EXIT=$?"
EXIT=1
```

Summary block, verbatim from the post-apply run:

```
======================================================================
SUMMARY
======================================================================
gates run           : 58
  PASS              : 37
  FAIL   (rc=1)     : 21
  ERROR  (rc!=0,1)  : 0
§11.4.32 step 1     : skip

FAILED:
  ❌ cm_continuum_resume_engine_present.sh
  ❌ cm_covenant_114_162_propagation.sh
  ❌ cm_covenant_114_167_propagation.sh
  ❌ cm_covenant_114_176_propagation.sh
  ❌ cm_covenant_114_187_propagation.sh
  ❌ cm_covenant_114_191_propagation.sh
  ❌ cm_covenant_114_196_propagation.sh
  ❌ cm_covenant_114_199_propagation.sh
  ❌ cm_covenant_114_200_propagation.sh
  ❌ cm_covenant_114_201_propagation.sh
  ❌ cm_covenant_114_202_propagation.sh
  ❌ cm_covenant_114_207_propagation.sh
  ❌ cm_covenant_114_213_propagation.sh
  ❌ cm_covenant_114_230_propagation.sh
  ❌ cm_covenant_114_231_propagation.sh
  ❌ cm_covenant_114_232_propagation.sh
  ❌ cm_covenant_114_233_propagation.sh
  ❌ cm_covenant_114_235_propagation.sh
  ❌ cm_gate_ledger_ratchet.sh
  ❌ cm_track_branch_label_mutation_test.sh
  ❌ cm_track_branch_label.sh

======================================================================
❌ SWEEP: FAIL — 21 FAIL + 0 ERROR out of 58 gate(s).
```

### 1.1 Verdict split: unchanged. Gate internals: moved.

| Metric | Before (GATE-TRIAGE §5) | After (this run) | Δ |
|---|---|---|---|
| gates run | 58 | 58 | — |
| PASS | 37 | 37 | — |
| FAIL (rc=1) | 21 | 21 | — |
| ERROR (rc≠0,1) | 0 | 0 | — |
| sweep exit code | 1 | **1** | — |
| failing gate **set** | 21 names | **the same 21 names** | identical |
| `❌ MISSING` lines across the 17 propagation gates | 85 | **68** | **−17** |
| distinct MISSING carriers | 5 | **4** | **−1** |
| `POINTER-INHERITANCE-SKIP` per gate | 11 | **31** | **+20** |
| `POINTER-INHERITANCE-SKIP` lines in the run (incl. 17 summary lines) | 204 + 17 | **544** | +323 |
| `DIVERGENT` (the 5 fence-aware gates) | 0 | **0** | — |

Measured:

```
$ grep -c "❌ MISSING" <post-apply sweep>
68
$ grep "❌ MISSING" <post-apply sweep> | sed 's/.*MISSING *//; s/  *—.*//' | sort | uniq -c
     17 milosvasic.ru/Upstreamable/AGENTS.md
     17 milosvasic.ru/Upstreamable/CLAUDE.md
     17 .specify/extensions/superspec/examples/static-landing-page/CLAUDE.md
     17 submodules/superspec/examples/static-landing-page/CLAUDE.md
```

Every one of the 17 gates now reports the identical shape:

```
CM-COVENANT-114-162-PROPAGATION: 4 PRESENT, 31 POINTER-INHERITANCE-SKIP, 4 MISSING (anchor 11.4.162)
CM-COVENANT-114-230-PROPAGATION: 4 single-block-PRESENT, 31 POINTER-INHERITANCE-SKIP, 4 MISSING/DUPLICATED, 0 DIVERGENT
```

**Explanation of the non-change.** The verdict split *could not* have improved.
`GATE-TRIAGE.md` §3.1 states the arithmetic that decides rows 1–17: each of the
17 gates was held FAIL by five carriers at once, one owned (category b) and four
third-party (category c). The apply cleared the one owned carrier. Four category-(c)
carriers remain, so all 17 gates still exit 1. Rows 18–21 live inside
`submodules/constitution` and were never in the apply's scope. The correct
success signal here is the **−17 MISSING lines / −1 carrier / +20 SKIP**
movement inside the gates, not the summary line — and `PROOF.md` §7 said so in
advance ("It does not show the gates go green. They do not.").

`31 = 11 + 20`: the 11 pre-existing pointer carriers (4 repository-root carriers
+ 3 `docs_chain` + 4 `helix_perf_cache`) plus the 20 newly applied ones
(5 submodules × 4 carriers). `544 = 17 gates × (31 skip lines + 1 summary line)`.
No carrier is double-counted and none is missing.

### 1.2 Nothing regressed

- The failing set is name-for-name the set recorded in `GATE-TRIAGE.md` §3.
  No gate that previously passed now fails.
- `0 DIVERGENT` still holds on all five fence-aware gates: no carrier holds a
  corrupted or duplicated anchor block. The 20 new files introduced no
  divergence.
- `pointer_carrier.sh --selftest` → `PASS (5/5)`, including both decoys. The
  instrument that produced the +20 is not blind (§11.4.201(7)(b)).
- `tests/test_constitution_inheritance.sh` → `CM-CONSTITUTION-INHERITANCE:
  8 PASS, 0 SKIP, 0 FAIL`.

### 1.3 `Constitution.md` § "Known-excluded gate findings" is now stale

Not corrected here — that file is out of this task's scope — but recorded so a
reader does not act on it:

- Section A still lists **five** carriers and **85** MISSING lines. Both numbers
  are now wrong: **four** and **68**.
- The `vasic.digital/QWEN.md` row still says "the fix **is staged** at
  `docs/constitution-adoption/propagation/vasic.digital/QWEN.insert-block.md`
  and awaits operator application". It has been applied and pushed
  (`vasic.digital` HEAD `6e5411c`). That row should be struck, leaving section A
  with four third-party rows and **zero owned-repository gaps**.

---

## 2. The `design-toolkit` two-parent question — SETTLED: it did **not** materialise

`PROOF.md` §7 projected: "after a commit + push + submodule update its four
carriers would appear at a *second* path
(`submodules/constitution/submodules/design-toolkit/`) … the count of SKIP lines
would grow by 4 × 17. This is projected, not measured."

**Measured: the second path shows nothing at all.** The gates emit exactly 31
SKIP lines, not 35. `submodules/constitution/submodules/design-toolkit` appears
in **no** gate output — not as PRESENT, not as SKIP, not as MISSING.

### 2.1 Why — two independent git object stores, not one working tree

`design-toolkit` is a gitlink of both parents at the same URL:

| Parent | `.gitmodules` path | URL |
|---|---|---|
| umbrella (`vasic`) | `design-toolkit` | `git@github.com:vasic-digital/design-toolkit.git` |
| `submodules/constitution` | `submodules/design-toolkit` | `git@github.com:vasic-digital/design-toolkit.git` |

But the two checkouts have **separate git directories**:

```
$ cat design-toolkit/.git
gitdir: ../.git/modules/design-toolkit

$ cat submodules/constitution/submodules/design-toolkit/.git
gitdir: ../../../../.git/modules/submodules/constitution/modules/design-toolkit
```

A commit made in one is invisible to the other until the other's parent bumps
its gitlink and runs `submodule update`. Nothing propagates automatically. The
projection's premise ("after a commit + push + submodule update") named the
third step, and that third step has not been taken.

### 2.2 The measured divergence

```
$ git -C design-toolkit log --oneline -2
efd2c3f Add constitution pointer carriers (AGENTS/CLAUDE/QWEN/GEMINI)
725e456 cascade: feat(002): anti-slop spec — credential-seam sanitisation + 2 scanner findings

$ git -C submodules/constitution/submodules/design-toolkit log --oneline -2
16e4e76 feat(proposed): OpenDesign Learning Kit — reusable, decoupled component pack
520c436 feat(§11.4.162): brand-hue anchoring + HelixQA token bank + hybrid-pipeline guide
```

| Path | HEAD | `describe` | Recorded gitlink | Dirty? |
|---|---|---|---|---|
| `design-toolkit` (umbrella) | `efd2c3fb2f88…` | `v0.2.2-6-gefd2c3f` | umbrella records `efd2c3fb2f88…` | no |
| `submodules/constitution/submodules/design-toolkit` | `16e4e76d57ab…` | `v0.2.2-4-g16e4e76` | constitution records `16e4e76d57ab…` | no |

```
$ git ls-tree HEAD design-toolkit
160000 commit efd2c3fb2f880aaf2baf7f4819ce28a1ce3609cb	design-toolkit

$ git -C submodules/constitution ls-tree HEAD submodules/design-toolkit
160000 commit 16e4e76d57ab61b5f3b46fae3372b2e6d6cc73e3	submodules/design-toolkit
```

### 2.3 Answers to the three questions asked

1. **Has the nested checkout also picked up the carriers?**
   **No.** `submodules/constitution/submodules/design-toolkit/` exists and is
   fully populated (agents, docs, evidence, generators, knowledge, mcp, proposed,
   qa, submodules, `README.md`) but contains **zero** of `AGENTS.md`,
   `CLAUDE.md`, `QWEN.md`, `GEMINI.md`. Its HEAD `16e4e76` predates the carrier
   commit `efd2c3f` by two commits.

2. **Is the constitution's own gitlink for it now stale?**
   **Yes — stale by exactly two commits**, but *consistently* stale: the
   constitution's recorded gitlink (`16e4e76`) and its checked-out HEAD agree, so
   `git -C submodules/constitution submodule status` shows no `+` marker and the
   constitution's working tree is clean with respect to it. The staleness is
   relative to the `design-toolkit` remote, which now carries `efd2c3f` (pushed;
   0 unpushed commits). Two commits behind: `725e456` (cascade / anti-slop spec)
   and `efd2c3f` (the carriers).

3. **What do the propagation gates see at each path?**

   | Path | Carriers discovered | Gate verdict lines |
   |---|---|---|
   | `design-toolkit/{AGENTS,CLAUDE,GEMINI,QWEN}.md` | 4 | 4 × `⏭ POINTER-INHERITANCE-SKIP … §11.4.35 pointer consumer` per gate (68 lines across 17 gates) |
   | `submodules/constitution/submodules/design-toolkit/` | **0** | **no lines emitted at all** |

   A directory with no carrier filenames contributes nothing to any of the three
   buckets. This is why the nested path is not merely "not SKIP" — it is
   entirely absent from the output.

### 2.4 What happens if the operator does bump it

If `submodules/constitution` bumps `submodules/design-toolkit` to `efd2c3f` and
runs `submodule update`, the four carriers appear at the second path. They are
byte-identical files and `is_pointer_carrier()` is path-independent (it reads
only the file's own text for a non-fenced, line-anchored `## INHERITED FROM `
heading), so they would be scored `POINTER-INHERITANCE-SKIP` there too:

- SKIP per gate: 31 → 35; SKIP lines in the sweep: 544 → 612.
- MISSING lines: **68, unchanged**. Distinct MISSING carriers: **4, unchanged**.
- Failing gate count: **21, unchanged**.

So `PROOF.md`'s *direction* was right (the second copy costs nothing and adds
+4 × 17 SKIP lines) but its *mechanism* was wrong: the effect is not automatic,
it requires a deliberate gitlink bump inside `submodules/constitution`, whose
push fan-out is the 6-URL one recorded in `GATE-TRIAGE.md` §6.4. **The cheapest
honest reading today is: the two-parent effect is latent, not live.**

### 2.5 `git submodule status --recursive` — the known failure, worked around

Reproduced, not fought:

```
$ git submodule status --recursive
 ed73d855… ai_interviewing (heads/main)
 efd2c3fb… design-toolkit (v0.2.2-6-gefd2c3f)
 66c8d607… milosvasic.ru (v1.8.0-6-g66c8d60)
 94f9831b… milosvasic.ru/Upstreamable (heads/main)
fatal: no submodule mapping found in .gitmodules for path 'Upstreamable'
fatal: failed to recurse into submodule 'Upstreamable'
fatal: failed to recurse into submodule 'milosvasic.ru'
rc=128
```

Root cause, measured: `milosvasic.ru/Upstreamable/.gitmodules` is **0 bytes**,
yet the `Upstreamable` repository records a gitlink *at its own root, named
after itself*:

```
$ git -C milosvasic.ru/Upstreamable ls-files -s | awk '$1=="160000"'
160000 3da17555b83ea647f5e602e5e6ee3ba4308d5f8f 0	Upstreamable
```

`3da1755` is `Upstreamable`'s own parent commit. A self-referential gitlink with
no `.gitmodules` mapping is unresolvable by design, and it aborts the whole
recursion — which is why the traversal never reaches
`submodules/constitution`'s children.

**Workaround used** (non-recursive, one level at a time — read-only, complete):

```
$ git submodule status                       # 7 top-level entries, all in sync (no '+')
$ for s in <each>; do git -C "$s" submodule status; done
```

which yields the constitution's children including the design-toolkit row:

```
 16e4e76d57ab61b5f3b46fae3372b2e6d6cc73e3 submodules/design-toolkit (v0.2.2-4-g16e4e76)
```

Top-level `git submodule status` shows **no `+` prefix on any entry**: every
gitlink the umbrella records matches the checked-out HEAD, i.e. the five carrier
commits are committed at the umbrella level, not left dangling.

---

## 3. The remaining 4 MISSING carriers — confirmed and adjudicated

Confirmed **exactly** as anticipated. Each appears 17 times (once per gate),
17 × 4 = 68, no fifth carrier anywhere in the run.

### 3.1 `milosvasic.ru/Upstreamable/AGENTS.md` and `.../CLAUDE.md`

- **Owning repository:** `red-elf/Upstreamable`.
  `milosvasic.ru/.gitmodules` maps it to `git@github.com:red-elf/Upstreamable.git`.
  Its own remotes are `github.com:red-elf/Upstreamable.git` and
  `gitflic.ru:red-elf/upstreamable.git` — the `red-elf` namespace, which is not
  among the namespaces this project pushes to (`vasic-digital`, `milos85vasic`,
  `milosvasic`, `HelixDevelopment` / `helixdevelopment`).
- **Can anything in a repo the user OWNS clear it? No.** The files are two
  levels down: a gitlink of the `milosvasic.ru` submodule. Clearing them means
  committing into `red-elf/Upstreamable` and pushing to a repository this
  project neither owns nor has a push path to. The only owned lever is
  `milosvasic.ru`'s **gitlink**, and moving a gitlink cannot change the content
  of the commit it points at — it can only point at a *different* upstream
  commit, which would have to already contain the anchors, which no upstream
  commit does.
- **Aggravating factor:** even a hypothetical upstream fix would land in a repo
  whose root carries a broken self-referential gitlink and a 0-byte
  `.gitmodules` (§2.5). Writing into it from here would be a fork, not a fix.
- **Category (c)**, unchanged from `GATE-TRIAGE.md` §7.

### 3.2 `submodules/superspec/examples/static-landing-page/CLAUDE.md`

- **Owning repository:** `WangX0111/superspec` (`git -C submodules/superspec
  remote -v` → `git@github.com:WangX0111/superspec.git`, fetch and push).
  Third-party, not the user's.
- **What the file actually is** — five lines, verbatim:

  ```
  <!-- SPECKIT START -->
  For additional context about technologies to be used, project structure,
  shell commands, and other important information, read the current plan:
  specs/001-static-landing-page/plan.md
  <!-- SPECKIT END -->
  ```

  A spec-kit demo fixture for an example landing page. It is not a governance
  carrier; it is only *named* like one, and the gates discover carriers by bare
  filename.
- **Can anything in a repo the user OWNS clear it? No.** The write would have to
  land in `WangX0111/superspec`. The umbrella's only lever is the gitlink, and
  no upstream `superspec` commit carries the 17 anchors.

### 3.3 `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md`

- **Physically writable here.** `git ls-files --error-unmatch` confirms the
  umbrella tracks it. It is byte-identical to §3.2:

  ```
  80df9a6dcb0455736fc24e39963c64b17d3ebd0f571e441343558c416fc775a3  submodules/superspec/examples/static-landing-page/CLAUDE.md
  80df9a6dcb0455736fc24e39963c64b17d3ebd0f571e441343558c416fc775a3  .specify/extensions/superspec/examples/static-landing-page/CLAUDE.md
  ```

- **Can a repo the user OWNS clear it? Physically yes, legitimately no —
  deliberately not written, and this document does not write it either.** It is
  one file of a vendored third-party spec-kit extension pinned in
  `.specify/extensions/.registry` at `"version": "1.0.2"` with
  `"manifest_hash": "sha256:6e23ee6c18f9e05d077293c7cd3ab8aaa982f1b7e35996267dc32b51e5fc8e54"`.
  Injecting 17 constitution anchor blocks into a vendored demo fixture would
  fork the artifact from its upstream and invalidate the pinned manifest hash,
  in order to satisfy a gate that is misreading a demo file as a governance
  carrier. That trades a true FAIL for a false PASS plus a corrupted vendor pin.
  Recorded as a **non-fix**, not as an impossibility — exactly as
  `GATE-TRIAGE.md` §3.1 recorded it.

### 3.4 Verdict on the four

**Zero of the four can be cleared by any write into a repository the user owns.**
Two require a push to `red-elf`, one requires a push to `WangX0111`, and the
fourth is a vendored byte-copy of the third whose only "fix" is a deliberate
corruption of a pinned vendor artifact. The durable remedy for all four is the
one `GATE-TRIAGE.md` §7 already names, upstream in the gate family per §11.4.26:
the propagation gates prune only
`node_modules|.git|out|build|dist|prebuilts|external|vendor|target` and treat
every `CLAUDE.md`/`AGENTS.md`/`QWEN.md`/`GEMINI.md` under `--root` as an owned
governance carrier. A third-party submodule tree and a vendored extension's demo
fixture are neither. Any in-repo workaround would be an allowlist.

---

## 4. Did the applied carriers survive? — YES, all 20

### 4.1 Files present, tracked, clean, committed and pushed

| Submodule | HEAD | carriers tracked | carriers dirty | unpushed commits |
|---|---|---|---|---|
| `ai_interviewing` | `ed73d85` Add constitution pointer carriers (AGENTS/CLAUDE/QWEN/GEMINI) | 4/4 | 0 | 0 |
| `design-toolkit` | `efd2c3f` Add constitution pointer carriers (AGENTS/CLAUDE/QWEN/GEMINI) | 4/4 | 0 | 0 |
| `milosvasic.ru` | `66c8d60` Add constitution pointer carriers (AGENTS/CLAUDE/QWEN/GEMINI) | 4/4 | 0 | 0 |
| `monetization` | `54ed7b0` Add constitution pointer carriers (AGENTS/CLAUDE/QWEN/GEMINI) | 4/4 | 0 | 0 |
| `vasic.digital` | `6e5411c` Add constitution pointer carriers (AGENTS/CLAUDE/GEMINI) + QWEN.md pointer block | 4/4 | 0 | 0 |

Sizes and line counts (three new 55-line carriers per module, `vasic.digital`'s
`QWEN.md` being the pre-existing file with a block prepended):

```
ai_interviewing  AGENTS.md 2573B/55L  CLAUDE.md 2510B/55L  QWEN.md 2481B/55L  GEMINI.md 2492B/55L
design-toolkit   AGENTS.md 2572B/55L  CLAUDE.md 2509B/55L  QWEN.md 2480B/55L  GEMINI.md 2491B/55L
milosvasic.ru    AGENTS.md 2571B/55L  CLAUDE.md 2508B/55L  QWEN.md 2479B/55L  GEMINI.md 2490B/55L
monetization     AGENTS.md 2570B/55L  CLAUDE.md 2507B/55L  QWEN.md 2478B/55L  GEMINI.md 2489B/55L
vasic.digital    AGENTS.md 2571B/55L  CLAUDE.md 2508B/55L  QWEN.md 5069B/103L GEMINI.md 2490B/55L
```

The only dirty paths anywhere in the five are `milosvasic.ru/sitemap.xml` and
`vasic.digital/sitemap.xml` — unrelated to this work, and neither is a carrier.

### 4.2 Still recognised by `is_pointer_carrier()`

Sourced live from `submodules/constitution/scripts/gates/lib/pointer_carrier.sh`
and run over all 20 files:

```
ai_interviewing/{AGENTS,CLAUDE,QWEN,GEMINI}.md    TRUE TRUE TRUE TRUE
design-toolkit/{AGENTS,CLAUDE,QWEN,GEMINI}.md     TRUE TRUE TRUE TRUE
milosvasic.ru/{AGENTS,CLAUDE,QWEN,GEMINI}.md      TRUE TRUE TRUE TRUE
monetization/{AGENTS,CLAUDE,QWEN,GEMINI}.md       TRUE TRUE TRUE TRUE
vasic.digital/{AGENTS,CLAUDE,QWEN,GEMINI}.md      TRUE TRUE TRUE TRUE
```

**20/20 TRUE.** The predicate library's own golden test, run unmodified:

```
$ bash submodules/constitution/scripts/gates/lib/pointer_carrier.sh --selftest
PASS golden-good: real pointer consumer recognised
PASS golden-bad: fenced-carrier heading correctly NOT recognised
PASS negative: no-heading doc correctly NOT recognised
PASS golden-bad-midline: mid-line backticked heading correctly NOT recognised
PASS golden-bad-tilde: ~~~-fenced heading correctly NOT recognised
pointer_carrier.sh selftest: PASS (5/5)
rc=0
```

Independently corroborated by the sweep itself: each of the 17 gates prints all
20 files by name as `⏭ POINTER-INHERITANCE-SKIP`.

### 4.3 `vasic.digital/QWEN.md` — 55 original lines intact, but the shape is **not** the one `PROOF.md` §5 describes

**Losslessness: confirmed, three independent ways.**

```
$ git -C vasic.digital show --numstat --format= HEAD
55	0	AGENTS.md
55	0	CLAUDE.md
55	0	GEMINI.md
48	0	QWEN.md
```

Zero deletions on `QWEN.md`; 48 lines inserted.

```
$ git -C vasic.digital show HEAD~1:QWEN.md > orig      # 55 lines, 2754 bytes
$ tail -n +49 vasic.digital/QWEN.md        > tail      # current lines 49..103
$ diff orig tail && echo IDENTICAL
IDENTICAL
$ sha256sum orig tail
3084a5b72a629af7dd9be9d7e97526ef13cc55b20d6e9baf3c818778c05c5b01  orig
3084a5b72a629af7dd9be9d7e97526ef13cc55b20d6e9baf3c818778c05c5b01  tail
```

All 55 original lines are byte-identical, in order, with a matching SHA-256.

**Deviation from the documented recipe — recorded, not corrected.**
`APPLY.md` §4.6's recipe is
`{ head -n 1 QWEN.md; echo; cat "$B"; tail -n +2 QWEN.md; }` and `PROOF.md` §5
records its result as:

```
first 3 lines:
  # Vasic-Digital GitHub Pages Project
  (blank)
  ## INHERITED FROM constitution/QWEN.md
'## Project Overview' now at line 52
```

What was actually applied is a **pure prepend**, not an insert-under-the-H1:

```
$ head -3 vasic.digital/QWEN.md
## INHERITED FROM constitution/QWEN.md
(blank)
**The inheritance below is conditional. Both cases are stated; neither is

$ grep -n '^# Vasic-Digital GitHub Pages Project' vasic.digital/QWEN.md
49:# Vasic-Digital GitHub Pages Project
$ grep -n '^## Project Overview' vasic.digital/QWEN.md
51:## Project Overview
```

Consequences, stated plainly:

- **Gate impact: none.** `is_pointer_carrier()` scans the whole file for a
  non-fenced, line-anchored `## INHERITED FROM ` heading; both shapes satisfy it,
  and the file is scored `POINTER-INHERITANCE-SKIP` by all 17 gates.
- **`CM-CANONICAL-ROOT-CLARITY` clause (a):** the applied shape is *stronger*
  than the documented one — the pointer literally opens the file. (That gate is
  recommended but unimplemented; this is a reading of the anchor text, not a
  gate result.)
- **One cosmetic defect.** There is **no blank line** between the inserted
  block's last line (line 48, `weaken or override them.`) and the original H1
  (line 49, `# Vasic-Digital GitHub Pages Project`). CommonMark lets an ATX
  heading interrupt a paragraph, so it still renders as a heading; it is a
  style nit, not a correctness one. Left as-is — fixing it means writing into a
  submodule working tree and re-pushing a live GitHub Pages site.
- **Line-count note.** `PROOF.md` §5 records "orig lines: 55 new lines: 104"; the
  live file measures `wc -l` 55 → 103. Both are right about different things:
  the file has **no trailing newline**, so it holds 56 physical lines
  (55 newlines) before and 104 after, i.e. `wc -l` reports 55 → 103. The
  substance — 48 inserted, 0 deleted — is unaffected.

---

## 5. `cm_opendesign_ui_system.sh` — the FALSE PASS, still false, now quantified

### 5.1 It still falsely passes

```
$ bash submodules/constitution/scripts/gates/cm_opendesign_ui_system.sh --root .
⏭️  SKIP CM-OPENDESIGN-UI-SYSTEM: no UI surface detected under /run/media/…/vasic
    (no theme/token/visreg sources matched OD_*_GLOBS) — §11.4.3 SKIP-with-reason, not a fake PASS
rc=0
```

and in the sweep:

```
PASS   rc=0        30ms  cm_opendesign_ui_system.sh   --root /run/media/…/vasic
```

The skip **reason is factually false**. The repository has a real UI surface —
eight CSS files under `design-system/`:

```
design-system/brand-milosvasic/milosvasic.css
design-system/brand-vasic-digital/vasic-digital.css
design-system/components-extended.css
design-system/fonts/fonts.css
design-system/learning-kit/kit-tokens.css
design-system/learning-kit/learning-kit.css
design-system/motion/animations.css
design-system/motion/overlays.css
```

### 5.2 Precisely why it skips

The gate's binding, `submodules/constitution/scripts/gates/cm_opendesign_ui_system.sh`
**line 82**:

```bash
OD_THEME_GLOBS="${OD_THEME_GLOBS:-src/theme/* src/styles/* styles/* theme/* themes/* ui/theme/* assets/theme/* *.theme.css tailwind.config.* tokens.css}"
```

None of those patterns names `design-system/`. Lines 83–84 (`OD_TOKEN_GLOBS`,
`OD_VISREG_GLOBS`) miss for the same reason — and `OD_VISREG_GLOBS`'s `**/…`
patterns cannot recurse at all, because `_expand()` (lines 88–99) uses plain
shell globbing with `globstar` unset. With all three lists empty, the
no-UI-surface branch at **lines 107–111** fires and `exit 0`.

The umbrella never binds any `OD_*_GLOBS`: `scripts/verify-all-constitution-rules.sh`
contains no `export`, no env-binding mechanism, and no `OD_` string anywhere. It
invokes each gate as bare `bash "$g" $argv` (line 249), inheriting the ambient
environment.

### 5.3 Exactly what would have to change — one binding, one file

**The single load-bearing change is binding `OD_THEME_GLOBS` in the environment
the sweep hands to the gate**, i.e. in
`/run/media/milosvasic/DATA4TB/Projects/vasic/scripts/verify-all-constitution-rules.sh`
at the gate-invocation site (`run_one … bash "$g" $argv`, **line 249**) — or, if
the operator prefers a per-gate override table, in a new resolution branch
alongside `resolve_argv()` (**lines 139–160**). It must NOT be changed inside
`cm_opendesign_ui_system.sh` itself: that file lives in `submodules/constitution`
and its defaults are the *generic* consumer defaults §11.4.28 mandates; the
consumer-specific layout is exactly what §11.4.35 says the consumer registers.

Binding `OD_THEME_GLOBS` alone is sufficient to defeat the false SKIP — the
branch requires **all three** lists to be empty.

**Nothing here has been changed. These are read-only measurements of what each
binding would produce, run with `VAR=… bash <gate> --root .`:**

| Scenario | Bindings | (a) dep | (b) tokens | (c) light+dark | (d) visreg | Verdict | rc |
|---|---|---|---|---|---|---|---|
| **0 — today** | none | — | — | — | — | **SKIP → scored PASS** | **0** |
| 1 | `OD_THEME_GLOBS='design-system/*.css design-system/*/*.css'` | ❌ | ❌ | ✅ | ❌ | **FAIL — 3/4 failed** | 1 |
| 2 | + `OD_TOKEN_GLOBS='design-system/learning-kit/kit-tokens.css …'`, `OD_VISREG_GLOBS='design-system/preview/* tests/visual/*'` | ❌ | ❌ | ✅ | ✅ | **FAIL — 2/4 failed** | 1 |
| 3 | + `OD_MANIFEST_GLOBS='helix-deps.yaml'` | ✅ | ❌ | ✅ | ✅ | **FAIL — 1/4 failed** | 1 |

Notes on each sub-check, measured:

- **(a) OpenDesign declared dependency.** Fails under the default
  `OD_MANIFEST_GLOBS` because **none** of `.mcp.json`, `package.json`, `go.mod`,
  `Cargo.toml`, `pubspec.yaml`, `requirements.txt`, `opencode.json`,
  `.qwen/settings.json` exists at the umbrella root, and `open-design-mcp` is not
  on `PATH`. It **passes** the moment `OD_MANIFEST_GLOBS='helix-deps.yaml'` is
  bound: `helix-deps.yaml:100` already declares the dependency
  (`"§11.4.162 OpenDesign UI design-system engine …"`), producing
  `✅ (a) OpenDesign declared dependency — declared in helix-deps.yaml`.
- **(b) design tokens consumed.** **This is the irreducible finding and it does
  not go away under any binding.** The theme sources carry **187 six-digit hex
  colour literals** across five files:
  `design-system/brand-milosvasic/milosvasic.css`,
  `design-system/brand-vasic-digital/vasic-digital.css`,
  `design-system/learning-kit/kit-tokens.css`,
  `design-system/learning-kit/learning-kit.css`,
  `design-system/motion/animations.css`. With no token artifact bound the gate
  reports "NO design-token artifact AND theme sources carry hardcoded hex";
  with `kit-tokens.css` bound as the token artifact it reports "token artifact
  exists but theme sources still inline hardcoded hex (token not consumed)".
  Either way, ❌.
- **(c) light + dark.** Passes honestly in every scenario — all five theme files
  match both `\blight\b` and `\bdark\b`.
- **(d) visual regression.** Fails under defaults (`**/…` cannot recurse; no
  `tests/visual/` or `test/visual/` exists; a repo-wide search for `*visreg*`,
  `*visual*regression*` and `*.snap.png` outside the submodules returns nothing).
  It "passes" in scenarios 2–3 only because `design-system/preview/*` was bound
  as a visreg glob — that is a **generous** binding the operator should scrutinise
  before adopting: a preview directory is not a pixel-diff harness. The
  conservative honest binding leaves (d) ❌ and yields **2/4 failed**.

### 5.4 The operator's decision, stated in one line

Binding `OD_THEME_GLOBS` (one line in the umbrella's own sweep script — a file
this task did not touch) converts a **false PASS into a true FAIL**, taking the
sweep from **37 PASS / 21 FAIL** to **36 PASS / 22 FAIL**. It is the honest
direction and it is not free: it puts a 187-literal token-consumption debt on
the board (sub-check (b)) that no glob binding can argue away. It is a scope and
configuration decision, not a silent edit, and it remains **not made**.

Related and unchanged: `GATE-TRIAGE.md` §8.3's observation still holds — the
`37 PASS` figure is more precisely **34 enforced PASS + 2 honest
unbound-feature SKIPs + 1 false SKIP**, because the sweep's SUMMARY has no SKIP
column.

---

## 6. Rows 20/21 — diagnosis confirmed, and it needs **two** lines, not one

### 6.1 The failure, reproduced post-apply

```
===== cm_track_branch_label.sh  [FAIL rc=1]
✅ PRESENCE+EXEC: hook -> …/scripts/hooks/guard-track-branch-label.sh
✅ PRESENCE+EXEC: labeler -> …/scripts/multitrack/track_branch_label.sh
✅ PARSEABILITY: hook clean (bash -n)
✅ PARSEABILITY: labeler clean (bash -n)
✅ DOC: convention doc present -> …/docs/scripts/guard-track-branch-label.md
❌ ALIAS-VALIDATION: labeler did not yield the known synthetic alias (got 'xhigh' from '(T1/main - cmgatechk - ? - xhigh)')
❌ CM-TRACK-BRANCH-LABEL: FAIL — see violations above
```

```
===== cm_track_branch_label_mutation_test.sh  [FAIL rc=1]
❌ META FAIL: clean fixture (real hook validates the alias field) — gate FAILed unexpectedly (false alarm!)
✅ META OK:   MUTATION: format-only hook (alias check stripped) — gate correctly FAILed on the mutation
❌ META FAIL: RESTORED fixture (real hook re-audited) — gate FAILed unexpectedly (false alarm!)
✅ META OK:   doc-missing fixture (§11.4.18 convention doc absent) — gate correctly FAILed on the mutation
✅ META OK:   parse-broken fixture (unbalanced quote in hook) — gate correctly FAILed on the mutation
❌ META FAIL: CM-TRACK-BRANCH-LABEL failed the §1.1 discriminator
```

### 6.2 `GATE-TRIAGE.md`'s diagnosis: CONFIRMED (with one wording correction)

`submodules/constitution/scripts/multitrack/track_branch_label.sh:268`:

```bash
printf '(T%s/%s - %s - %s - %s)\n' "$_n" "$_br" "$_al" "$_mo" "$_ef"
```

`submodules/constitution/scripts/gates/cm_track_branch_label.sh:90–97`:

```bash
# Extract the <alias> field from a "(T<N>/<branch> - <alias>) ..." label.
_label_alias() {
    local _p="${1%%)*}"
    case "$_p" in
        *' - '*) printf '%s' "${_p##* - }" ;;
        *)       printf '%s' '' ;;
    esac
}
```

Measured against the live labeler:

```
live label              : (T1/main - cmgatechk - ? - xhigh)
current  ${_p##* - }    : 'xhigh'        <-- read as the alias
positional field 2      : 'cmgatechk'    <-- the actual alias
```

`${_p##* - }` takes the **last** ` - `-separated field, which is now the *effort*.
This is unconditional: whatever the effort resolves to, the last field is never
the alias. **The diagnosis is correct.**

*Wording correction (§11.4.6).* `GATE-TRIAGE.md` §6.3 calls it a "**five**-field
label". The `printf` has five `%s` conversions, but `T%s/%s` joins the track and
branch with `/`, not ` - `, so the emitted label has **four** ` - `-separated
fields: `(T1/main`, `cmgatechk`, `?`, `xhigh`. The count is off by one; the
conclusion is not.

*The gate's own comment is also stale* — it documents a two-field label
`"(T<N>/<branch> - <alias>) ..."`, which is the shape `${_p##* - }` was written
for.

### 6.3 The corrected extractor already exists — in the hook

`submodules/constitution/scripts/hooks/guard-track-branch-label.sh:207–218`
carries the *right* implementation, with a comment that predicted this exact bug:

```bash
# … <alias> is everything BEFORE the NEXT ' - ' if one follows (4-field form:
# alias precedes model) or the remainder (3-field legacy form …). This stays
# correct whether or not an optional <model> 3rd field is present — unlike a
# naive "take everything after the LAST ' - '" rule, which would silently
# grab <model> instead of <alias> once dispatchers start emitting 4-field
# labels (§11.4.182 §11.4.6 — the extraction must not regress under the new field).
_label_alias() {
  local _pfx="${1%%)*}"
  local _rest
  case "$_pfx" in
    *' - '*) _rest="${_pfx#*' - '}" ;;
    *)       printf '%s' ''; return ;;
  esac
  case "$_rest" in
    *' - '*) printf '%s' "${_rest%%' - '*}" ;;   # 4-field: alias is BEFORE the next ' - '
    *)       printf '%s' "$_rest" ;;              # 3-field: alias is the remainder
  esac
}
```

**So the gate and the hook hold two divergent copies of the same helper, and
only the gate's copy is stale.** The one-line fix is a drop-in replacement of
`cm_track_branch_label.sh:94` with the hook's two-stage extraction, or — cleaner
and DRY per §11.4.28 — sourcing the hook's helper from a shared library.

### 6.4 **New finding: the one-line fix is necessary but NOT sufficient**

`cm_track_branch_label.sh:141–142` builds the mutation probe by appending after
the *last* ` - `:

```bash
_head="${_correct% - *}"                # comment claims: "(T<N>/<branch>"
_wrong="${_head} - ${_known}_MUT)"      # concrete alias that disagrees with live
```

Against the live four-field label this produces, measured:

```
_head  = '(T1/main - cmgatechk - ?'                       <-- comment says "(T1/main"
_wrong = '(T1/main - cmgatechk - ? - cmgatechk_MUT)'      <-- mutates the EFFORT slot
```

The mutation lands in the effort position, not the alias position. Today that is
unreachable — the gate exits at the `_live != _known` check on line 138 — but
**fixing `_label_alias` alone makes it reachable and the gate still FAILs**,
now with a *false accusation against a hook that is provably correct*. Verified
by driving the real hook read-only with each payload:

| Payload | Hook rc | Gate expects |
|---|---|---|
| `(T1/main - cmgatechk - ? - cmgatechk_MUT)` — what line 142 builds | **0** (allowed) | 2 → `❌ WRONG alias NOT blocked … hook does NOT validate the alias field` |
| `(T1/main - cmgatechk_MUT - ? - xhigh)` — alias slot genuinely mutated | **2** (blocked) | 2 ✅ |
| `(T1/main - cmgatechk - ? - xhigh)` — the correct live label | **0** | 0 ✅ |
| `(T1/main - ?) gate probe` with `CLAUDE_CONFIG_DIR` unset | **0** | 0 ✅ |

The hook is behaving exactly as documented (`guard-track-branch-label.sh:148–151`
reads "the alias field … regardless" of trailing fields). It is the gate's probe
construction that is wrong.

### 6.5 The exact change — two lines, both inside `submodules/constitution`

Both live in
`submodules/constitution/scripts/gates/cm_track_branch_label.sh`. **Neither has
been made.**

**Change 1 — line 94** (the one-line fix `GATE-TRIAGE.md` §6.3 names). Replace

```bash
        *' - '*) printf '%s' "${_p##* - }" ;;
```

with the hook's positional two-stage extraction (mirror
`guard-track-branch-label.sh:207–218` verbatim, and refresh the stale comment on
line 90 to describe the 4-field label).

**Change 2 — lines 141–142** (required, or Change 1 merely relocates the
failure). Replace the trailing-append construction with an in-place mutation of
the **alias** field, safe for both the 3-field legacy and 4/5-field forms.
Verified read-only to produce `(T1/main - cmgatechk_MUT - ? - xhigh)` → hook
rc = 2 (the expected BLOCK), and `(T1/main - cmgatechk_MUT)` for the legacy form:

```bash
_pfx="${_correct%%)*}"; _tail="${_correct#*)}"
_t1="${_pfx%%' - '*}"                    # "(T<N>/<branch>"
_restf="${_pfx#*' - '}"                  # "<alias>[ - <model>[ - <effort>]]"
case "$_restf" in *' - '*) _after=" - ${_restf#*' - '}" ;; *) _after="" ;; esac
_wrong="${_t1} - ${_known}_MUT${_after})${_tail}"
```

**Projected outcome, measured probe-by-probe:** with both changes, `_rc_w = 2`,
`_rc_c = 0`, `_rc_q = 0` — all three ALIAS-VALIDATION assertions satisfied, and
invariants 1–3 (presence/exec, parseability, doc) already pass. **Row 20 would
PASS.**

**Row 21 — reasoned, not measured.** `cm_track_branch_label_mutation_test.sh`
derives the gate under test from its own `SCRIPT_DIR` (line 45) and accepts no
override, so it cannot be re-run against a corrected copy without writing into
the submodule — which this task must not do. The reasoning: its only two `META
FAIL`s are on the *clean* and *RESTORED* fixtures ("gate FAILed unexpectedly
(false alarm!)"), both of which run the real gate against the real hook; fixing
row 20 removes the false alarm on both. The three genuine mutations already
score `✅ META OK`, and the format-only mutation strips the hook's alias check
so `_rc_w` becomes 0 → the corrected gate still FAILs it → still caught. Row 21
is a consequence of row 20, as `GATE-TRIAGE.md` §6.3 states.

### 6.6 Upstream decision required

Both changes are inside `submodules/constitution`, whose `origin` **pushes to
six URLs in one command** (`GATE-TRIAGE.md` §6.4):

```
git@gitflic.ru:helixdevelopment/helixconstitution.git
git@github.com:HelixDevelopment/HelixConstitution.git
git@gitlab.com:helixdevelopment1/helixconstitution.git
git@gitverse.ru:helixdevelopment/HelixConstitution.git
git@github.com:vasic-digital/HelixConstitution.git
git@gitlab.com:vasic-digital/HelixConstitution.git
```

Landing them changes the constitution every consuming project inherits.
**Nothing in the umbrella can move rows 20 or 21.**

---

## 7. Honest boundary — what this document does not establish

- **It does not show the sweep improved.** It did not, and could not: 21 FAIL,
  exit 1, unchanged. What moved is inside the propagation gates (85 → 68 MISSING
  lines, 5 → 4 carriers, 11 → 31 SKIP), and that movement is the whole of the
  measurable result.
- **It does not measure row 21.** §6.5 states the reasoning and labels it as
  reasoning.
- **It does not measure the two-parent effect after a gitlink bump.** §2.4's
  numbers (31 → 35 SKIP, MISSING unchanged) are derived from the predicate's
  path-independence and the byte-identity of the files, not from a run — making
  that run requires a commit inside `submodules/constitution`.
- **It applies neither §5 nor §6.** Both are quantified so the operator can
  decide; both remain unmade.
- **It does not correct `Constitution.md`.** §1.3 records that its
  "Known-excluded gate findings" section is now stale in three places, and
  leaves the correction to the operator.
- **It does not assess whether the carriers' prose is the right governance
  answer**, only that all 20 are recognised as §11.4.35 pointer consumers and
  that `vasic.digital/QWEN.md`'s original 55 lines are byte-intact.
