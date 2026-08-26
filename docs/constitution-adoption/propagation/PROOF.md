# Constitution Propagation — PROOF (temp-dir gate run)

> **Note on filenames.** The staged carrier drafts in this directory are stored with a
> `.staged` suffix (e.g. `AGENTS.md.staged`). The constitution's propagation gates discover
> carriers by exact filename (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`), so drafts
> named that way inside the repo are counted as real carriers and fail the gate. Drop the
> `.staged` suffix when you copy a file into its target submodule.

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-08-27 |
| Last modified | 2026-08-27 |
| Status | active |
| Status summary | Empirical before/after for the corrected staging in this directory, measured by running all 17 `CM-COVENANT-114-*-PROPAGATION` gates against temp directories that mirror the real fleet. Includes a control run on the uncorrected Revision-1 drafts, so the result is not vacuous. Nothing was applied; no submodule working tree was written to; no mutating git command was run. |
| Continuation | Operator reads this before executing [`APPLY.md`](APPLY.md) §4. |

> **§11.4.65 disclosure.** This document ships without its `.html` and `.pdf`
> siblings — the same known, disclosed deviation `INVENTORY.md` records as gap
> **G8** and [`RISKS.md`](RISKS.md) R7 records for this whole directory.

---

## 1. What was being tested, and against what

[`GATE-TRIAGE.md`](../GATE-TRIAGE.md) §6.1 found that the Revision-1 staging in
this directory would make the constitution gates **strictly worse**: applying
`APPLY.md` §4.6 as written would take the fleet from 5 MISSING carriers / 85
MISSING lines to 8 / 136. This document is the measurement that (a) reproduces
that finding, (b) shows the corrected Revision-2 staging does the opposite, and
(c) proves the harness can tell the two apart.

The mechanism under test is one predicate, sourced by all 17 gates from
`submodules/constitution/scripts/gates/lib/pointer_carrier.sh`:

````awk
BEGIN { fenced = 0; found = 0 }
/^(```|~~~)/ { fenced = !fenced; next }
!fenced && /^## INHERITED FROM / { found = 1; exit }
END { exit !found }
````

A carrier that satisfies it is scored `POINTER-INHERITANCE-SKIP` (§11.4.35
pointer consumer — legitimately omits every anchor literal). A carrier that
does not, and that also lacks the anchor literal, is scored `MISSING`.

The Revision-1 drafts opened with a `>` blockquote (`AGENTS.md`, `QWEN.md`,
`GEMINI.md`, the `QWEN.insert-block.md`) or with
`# CLAUDE.md — <module>` + `## Helix Constitution inheritance` (`CLAUDE.md`).
None of those is a line-anchored, non-fenced `## INHERITED FROM ` heading, so
every one of them registered as a **new anchor-less carrier**.

## 2. The first thing checked — does the claimed resolution actually hold?

Before rewriting 19 files, one candidate file was built and run through the
real predicate and two real gates. The claim being tested: *the gate requires
the heading to be present, non-fenced, at column zero — it does not require the
path written in that heading to resolve from the file's own depth.*

```
$ . submodules/constitution/scripts/gates/lib/pointer_carrier.sh
$ is_pointer_carrier <candidate with '## INHERITED FROM constitution/CLAUDE.md'>
PREDICATE: TRUE (pointer carrier)
$ is_pointer_carrier docs/constitution-adoption/propagation/ai_interviewing/CLAUDE.md.staged
STAGED-CONTROL: FALSE (as triaged)
```

and through the gates themselves, on a temp dir holding only that one file:

```
$ bash submodules/constitution/scripts/gates/cm_covenant_114_162_propagation.sh --root <tmp>
⏭ POINTER-INHERITANCE-SKIP  CLAUDE.md  — §11.4.35 pointer consumer (inherits 11.4.162 by pointer)
CM-COVENANT-114-162-PROPAGATION: 0 PRESENT, 1 POINTER-INHERITANCE-SKIP, 0 MISSING (anchor 11.4.162)
✅ CM-COVENANT-114-162-PROPAGATION: PASS
rc=0

$ bash submodules/constitution/scripts/gates/cm_covenant_114_230_propagation.sh --root <tmp>
⏭ POINTER-INHERITANCE-SKIP CLAUDE.md  — §11.4.35 pointer consumer (engine-rules-only mirror; zero 11.4.230 blocks expected, not a violation)
CM-COVENANT-114-230-PROPAGATION: 0 single-block-PRESENT, 1 POINTER-INHERITANCE-SKIP, 0 MISSING/DUPLICATED, 0 DIVERGENT
✅ CM-COVENANT-114-230-PROPAGATION: PASS
rc=0
```

Both gate families — the 12 legacy bare-literal gates and the 5 fence-aware
§11.4.227(B) block-integrity gates — skip the file. **The resolution holds.**
Only then were the remaining files rewritten.

## 3. The harness

Five temp roots, each a directory tree of `CLAUDE.md` / `AGENTS.md` /
`QWEN.md` / `GEMINI.md` files at the relative paths the real repository has
them at. Nothing else is needed: the gates discover carriers by filename under
`--root` and read nothing else.

| Root | Contents |
|---|---|
| `baseline` | byte-copies of all **20** carriers the real repository currently exposes to the gates (4 root PRESENT, 11 constitution-side pointer carriers, 5 MISSING) |
| `defective-46` | `baseline` + `APPLY.md` §4.6 applied with the **Revision-1** files |
| `defective-full` | `baseline` + `APPLY.md` §4.2 – §4.6 applied with the **Revision-1** files |
| `corrected-46` | `baseline` + `APPLY.md` §4.6 applied with the **Revision-2** files |
| `corrected-full` | `baseline` + `APPLY.md` §4.2 – §4.6 applied with the **Revision-2** files |

`defective-46` and `defective-full` are the **control**: the same harness, the
same gates, the uncorrected files. If the harness could not tell them from the
corrected set, the proof would be worth nothing.

The carrier list was produced with the gates' own `find` expression, and the
`§4.6` insertion used `APPLY.md`'s own recipe verbatim
(`{ head -n 1 QWEN.md; echo; cat "$B"; tail -n +2 QWEN.md; }`).

Then, for each root:

```bash
for a in 162 167 176 187 191 196 199 200 201 202 207 213 230 231 232 233 235; do
  bash submodules/constitution/scripts/gates/cm_covenant_114_${a}_propagation.sh --root <root>
done
```

### 3.1 Control needle — the harness reproduces reality exactly

The same 17 gates were first run against the **live repository root**,
read-only:

```
$ grep -c '❌ MISSING' <live-run>
85
$ grep '❌ MISSING' <live-run> | sed 's/.*MISSING *//; s/  *—.*//' | sort -u
milosvasic.ru/Upstreamable/AGENTS.md
milosvasic.ru/Upstreamable/CLAUDE.md
.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md
submodules/superspec/examples/static-landing-page/CLAUDE.md
vasic.digital/QWEN.md
```

`CM-COVENANT-114-162-PROPAGATION: 4 PRESENT, 11 POINTER-INHERITANCE-SKIP, 5 MISSING`,
17/17 gates FAIL. The `baseline` temp root reproduces those numbers exactly —
85 MISSING lines, the same 5 carriers, 17 FAIL — so a zero elsewhere in this
document is a real zero, not a blind instrument (§11.4.201(7)(b)).

The predicate library's own golden test was also run, unmodified:
`pointer_carrier.sh selftest: PASS (5/5)`, including the mid-line-backtick and
`~~~`-fence decoys.

## 4. Results

| Root | gates PASS / FAIL | MISSING lines | distinct MISSING carriers | POINTER-INHERITANCE-SKIP lines |
|---|---|---|---|---|
| `baseline` (= live repo) | 0 / 17 | **85** | **5** | 204 |
| `defective-46` (control) | 0 / 17 | **136** | **8** | 204 |
| `defective-full` (control) | 0 / 17 | **408** | **24** | 204 |
| `corrected-46` | 0 / 17 | **68** | **4** | 272 |
| `corrected-full` | 0 / 17 | **68** | **4** | 544 |

Read the two rows that matter side by side, on the same gate:

```
defective-full   CM-COVENANT-114-213-PROPAGATION: 4 PRESENT, 11 POINTER-INHERITANCE-SKIP, 24 MISSING (anchor 11.4.213)
                 ❌ CM-COVENANT-114-213-PROPAGATION: FAIL — 24 owned carrier(s) missing §11.4.213 anchor

corrected-full   CM-COVENANT-114-213-PROPAGATION: 4 PRESENT, 31 POINTER-INHERITANCE-SKIP, 4 MISSING (anchor 11.4.213)
                 ❌ CM-COVENANT-114-213-PROPAGATION: FAIL — 4 owned carrier(s) missing §11.4.213 anchor
```

and on a fence-aware one:

```
defective-full   CM-COVENANT-114-230-PROPAGATION: 4 single-block-PRESENT, 11 POINTER-INHERITANCE-SKIP, 24 MISSING/DUPLICATED, 0 DIVERGENT
corrected-full   CM-COVENANT-114-230-PROPAGATION: 4 single-block-PRESENT, 31 POINTER-INHERITANCE-SKIP, 4 MISSING/DUPLICATED, 0 DIVERGENT
```

Every one of the 20 applied carriers is skipped by name in the corrected run:

```
⏭ POINTER-INHERITANCE-SKIP ai_interviewing/AGENTS.md  — §11.4.35 pointer consumer …
⏭ POINTER-INHERITANCE-SKIP ai_interviewing/CLAUDE.md  — …
⏭ POINTER-INHERITANCE-SKIP ai_interviewing/GEMINI.md  — …
⏭ POINTER-INHERITANCE-SKIP ai_interviewing/QWEN.md  — …
⏭ POINTER-INHERITANCE-SKIP design-toolkit/{AGENTS,CLAUDE,GEMINI,QWEN}.md  — …
⏭ POINTER-INHERITANCE-SKIP milosvasic.ru/{AGENTS,CLAUDE,GEMINI,QWEN}.md  — …
⏭ POINTER-INHERITANCE-SKIP monetization/{AGENTS,CLAUDE,GEMINI,QWEN}.md  — …
⏭ POINTER-INHERITANCE-SKIP vasic.digital/{AGENTS,CLAUDE,GEMINI,QWEN}.md  — …
```

(The `{…}` braces are this document's abbreviation; the gate prints one line per
file. 544 − 204 = 340 = 20 carriers × 17 gates, which is the arithmetic check
that no carrier was missed.)

### 4.1 The triage's exact claim, reproduced

`GATE-TRIAGE.md` §6.1 said applying §4.6 as written takes the fleet **from 5
MISSING carriers to 8 and from 85 MISSING lines to 136**. `defective-46`
measures exactly 136 / 8, and names the three new failures:

```
vasic.digital/AGENTS.md
vasic.digital/CLAUDE.md
vasic.digital/GEMINI.md
```

on top of the pre-existing five. The triage was right.

### 4.2 What the corrected §4.6 does instead

`corrected-46` leaves **68 / 4**. The three new carriers are skipped, and
`vasic.digital/QWEN.md` — one of the original five MISSING — leaves the failing
set entirely, because the inserted block gives it a real pointer heading. The
remaining four are exactly the category-(c) third-party carriers:

```
milosvasic.ru/Upstreamable/AGENTS.md
milosvasic.ru/Upstreamable/CLAUDE.md
.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md
submodules/superspec/examples/static-landing-page/CLAUDE.md
```

Applying the *full* §4.2 – §4.6 adds 16 more carriers and changes nothing else:
still 68 / 4. Sixteen new files, zero new failures.

### 4.3 Per-file predicate result, corrected vs. defective

All 20 target files, one command per file, both versions:

```
ai_interviewing/AGENTS.md                corrected=TRUE  defective=FALSE
ai_interviewing/CLAUDE.md                corrected=TRUE  defective=FALSE
ai_interviewing/QWEN.md                  corrected=TRUE  defective=FALSE
ai_interviewing/GEMINI.md                corrected=TRUE  defective=FALSE
design-toolkit/AGENTS.md                 corrected=TRUE  defective=FALSE
design-toolkit/CLAUDE.md                 corrected=TRUE  defective=FALSE
design-toolkit/QWEN.md                   corrected=TRUE  defective=FALSE
design-toolkit/GEMINI.md                 corrected=TRUE  defective=FALSE
milosvasic.ru/AGENTS.md                  corrected=TRUE  defective=FALSE
milosvasic.ru/CLAUDE.md                  corrected=TRUE  defective=FALSE
milosvasic.ru/QWEN.md                    corrected=TRUE  defective=FALSE
milosvasic.ru/GEMINI.md                  corrected=TRUE  defective=FALSE
monetization/AGENTS.md                   corrected=TRUE  defective=FALSE
monetization/CLAUDE.md                   corrected=TRUE  defective=FALSE
monetization/QWEN.md                     corrected=TRUE  defective=FALSE
monetization/GEMINI.md                   corrected=TRUE  defective=FALSE
vasic.digital/AGENTS.md                  corrected=TRUE  defective=FALSE
vasic.digital/CLAUDE.md                  corrected=TRUE  defective=FALSE
vasic.digital/QWEN.md                    corrected=TRUE  defective=FALSE
vasic.digital/GEMINI.md                  corrected=TRUE  defective=FALSE
```

20 / 20 corrected TRUE, 20 / 20 defective FALSE. No partial credit anywhere.

## 5. `vasic.digital/QWEN.md` — the insertion is lossless

Produced with `APPLY.md` §4.6's own recipe, then checked:

```
orig lines: 55   new lines: 104
first 3 lines:
  # Vasic-Digital GitHub Pages Project
  (blank)
  ## INHERITED FROM constitution/QWEN.md
'## Project Overview' now at line 52

$ diff <(tail -n +2 QWEN.md.orig) <(tail -n +51 QWEN.md.new)
IDENTICAL — all 55 original lines preserved, pure insertion

$ is_pointer_carrier QWEN.md.new   -> TRUE
$ is_pointer_carrier QWEN.md.defective -> FALSE
```

Zero deletions, zero modifications to the existing 55 lines. The pointer
heading sits under the file's existing H1 title, which is the shape of the four
repository-root carriers that pass all 17 gates today and of the predicate's own
`golden-good` fixture; `is_pointer_carrier()` scans the whole file, so the
heading is found either way.

## 6. `APPLY.md` §5 checks, run against the corrected set

```
all 20 carriers: resolver named, no hardcoded parent path,
                 no dangling @import, pointer heading present
```

i.e. every file contains `find_constitution.sh`, none contains the umbrella's
`submodules/constitution` layout string (a §11.4.28(B) violation), none opens
with an `@constitution/` import (which would silently resolve to nothing inside
a submodule), and every one carries the `## INHERITED FROM ` heading.

## 7. Honest boundary — what this proof does **not** show

- **It does not show the gates go green.** They do not. All 17 still exit 1,
  held by the four category-(c) third-party carriers
  ([`GATE-TRIAGE.md`](../GATE-TRIAGE.md) §3.1, §7). No change confined to this
  directory can clear them, and none was attempted. What is proven is the
  direction: 85 → 68, 5 → 4, and 16–19 new files that cost nothing.
- **It does not prove the propagation was applied.** Nothing was applied. Every
  number above comes from temp directories; no submodule working tree was
  written to and no mutating git command was run.
- **It does not prove the carriers' prose is correct**, only that the gates
  score them as pointer consumers. Whether the conditional wording is the right
  governance answer is [`APPLY.md`](APPLY.md) §3's argument, not a gate result.
- **It does not model the `design-toolkit` two-parent effect.** `design-toolkit`
  is a gitlink of both the umbrella and the constitution, so after a commit +
  push + submodule update its four carriers would appear at a *second* path
  (`submodules/constitution/submodules/design-toolkit/`). Those copies would be
  pointer carriers too — the same files — so the direction does not change; the
  count of SKIP lines would grow by 4 × 17. This is projected, not measured
  (measuring it needs the commit this task must not make).
- **It does not evaluate `CM-CANONICAL-ROOT-CLARITY`.** That §11.4.35 gate is
  *recommended* but not implemented (it appears in
  `scripts/gates/gate_ledger_prev_names.txt` with no gate script). Its clause
  (a) — "consumer's `CLAUDE.md` opens with the inheritance pointer" — would be
  satisfied by the corrected form and violated by the Revision-1 form, which is
  a second, independent reason for the change; but that is a reading of the
  anchor text, not a gate run.
