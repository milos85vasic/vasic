# Gate triage — sweep failures

| Field | Value |
|---|---|
| Revision | 2 |
| Created | 2026-08-27 |
| Last modified | 2026-09-02 |
| Status | active |
| Status summary | Triage of every FAIL reported by `scripts/verify-all-constitution-rules.sh`. **§1–§8 are the 2026-08-27 triage of a 58-gate sweep at the PRE-fast-forward constitution and are SUPERSEDED — they are kept because the reasoning is still sound and the arithmetic in §3.1 is still instructive, not because the numbers are current.** [**§9 is the current measurement**](#9-2026-09-02--the-first-completed-post-fast-forward-sweep): the first sweep to run to completion after the constitution was fast-forwarded, **186 PASS / 95 FAIL / 6 ERROR of 287 gates, exit 1**, triaged into (a) third-party & staged carriers, (b) constitution-internal defects, (c) genuinely ours. No verdict was suppressed, allowlisted or downgraded in either round. |
| Sweep under triage | `scripts/verify-all-constitution-rules.sh` — 58 gates in §1–§8; **287 gates in §9** |
| Constitution HEAD | `448981ae3498229c734dc60719f4b19f01d7a75f` in §1–§8; **`f5876a3b700eb9a8792c1f19baca77959a2a7e88` in §9** |
| Scope | Triage only. No submodule working tree was written to. No mutating git command was run. §1–§8 additionally carried one comment-accuracy correction in the umbrella's own sweep script. |

> **§11.4.65 disclosure.** This document ships without its `.html` and `.pdf`
> siblings — the same known, disclosed deviation
> [`INVENTORY.md`](INVENTORY.md) records as gap **G8**. Stated rather than left
> to be discovered.

> **Reading order (§11.4.6).** The document's original H1 was *"the 21 sweep
> failures"*. That title is now wrong — the completed post-fast-forward sweep
> reports 95 FAIL and 6 ERROR — so it was corrected rather than left to mislead
> a reader who stops at the heading. **Every count in §1–§8 is withdrawn as a
> statement about the present tree**; not one of them is comparable to §9,
> because the gate population moved 57 → 286 when the constitution submodule was
> fast-forwarded. §1–§8 remain readable as the record of a different, earlier
> corpus.

---

## 1. How the sweep was run

```
bash scripts/verify-all-constitution-rules.sh 2>&1 | tee /tmp/sweep.txt
```

Every failing gate was then re-run **directly**, with the argv the gate's own
usage header dictates. `--root` means three different things across this family,
and passing the wrong one produces a false verdict in *both* directions —
verified, not assumed:

| Gate family | Header says | Correct root |
|---|---|---|
| `cm_covenant_114_*_propagation.sh` | `--root <consumer-root>` | repo root |
| `cm_continuum_resume_engine_present.sh`, `cm_gate_ledger_ratchet.sh` | `--root <constitution-root>` | `submodules/constitution` |
| `cm_track_branch_label*.sh` | no `--root` | gate defaults |
| `lib/pointer_carrier.sh` | — | `--selftest` |
| `gate_ledger.sh` | — | `selfcheck <scratchdir>` |

Proof that the root matters (both runs are read-only):

```
$ bash submodules/constitution/scripts/gates/cm_covenant_114_162_propagation.sh --root submodules/constitution
CM-COVENANT-114-162-PROPAGATION: 4 PRESENT, 7 POINTER-INHERITANCE-SKIP, 0 MISSING (anchor 11.4.162)
✅ CM-COVENANT-114-162-PROPAGATION: PASS — every owned carrier carries §11.4.162     <-- FALSE PASS

$ bash submodules/constitution/scripts/gates/cm_continuum_resume_engine_present.sh --root .   ; echo rc=$?
❌ MISSING  engine directory: submodules/continuum (expected under …/vasic)
rc=1                                                                                  <-- FALSE FAIL
```

The sweep resolves both correctly — its `--list` output prints every resolved
argv, and it matches the table above for all 57 discovered gates plus the
project-side inheritance test.

### `gate_ledger.sh` — the sweep handles it correctly

`gate_ledger.sh` is a multi-subcommand tool, not a gate with a default action.
The sweep detects its `selfcheck)` branch and invokes
`bash gate_ledger.sh selfcheck <scratch>` — confirmed in the run log:

```
PASS   rc=0       679ms  gate_ledger.sh                         selfcheck <scratch>
```

Two corrections to the premise, both verified on 2026-08-27:

- Invoked **bare**, `gate_ledger.sh` exits **2**, not 0 (`usage >&2; exit 2`).
  Under this sweep an rc=2 scores **ERROR** — "a blind instrument, never a
  pass" (§11.4.201(7)(b)) — so a bare invocation could not have produced a
  false PASS here either. It still proves nothing, so using the documented
  self-test is right regardless.
- The sweep's own header comment claimed the bare exit was `0`. That claim was
  false. It is corrected in §4 below.

`lib/pointer_carrier.sh --selftest` is a real 5-fixture golden test, not a
formality: `pointer_carrier.sh selftest: PASS (5/5)`, including the two decoys
(mid-line backticked heading, `~~~`-fenced heading) that would otherwise let a
non-pointer carrier be silently skipped.

---

## 2. Before — the sweep as found

```
gates run           : 58
  PASS              : 37
  FAIL   (rc=1)     : 21
  ERROR  (rc!=0,1)  : 0
§11.4.32 step 1     : skip
❌ SWEEP: FAIL — 21 FAIL + 0 ERROR out of 58 gate(s).
```

The 21 are exactly: the 17 `cm_covenant_114_*_propagation.sh` gates, plus
`cm_continuum_resume_engine_present.sh`, `cm_gate_ledger_ratchet.sh`,
`cm_track_branch_label.sh`, `cm_track_branch_label_mutation_test.sh`.

**Verified, not assumed:** the 17 propagation gates emit **85 `MISSING` lines**
in total, and those 85 resolve to exactly **five distinct carriers**
(17 × 5 = 85, no sixth carrier anywhere):

```
$ grep -c "❌ MISSING" /tmp/sweep.txt
85
$ grep "❌ MISSING" /tmp/sweep.txt | sed 's/.*MISSING *//; s/ *— .*//' | sort -u | wc -l
5
```

All 17 report the identical shape: `4 PRESENT, 11 POINTER-INHERITANCE-SKIP,
5 MISSING`, and the five fence-aware ones (230/231/232/233/235) additionally
report `0 DIVERGENT` — i.e. **no carrier holds a corrupted or duplicated anchor
block**; the only defect is absence.

---

## 3. The 21 rows

Category key — **(a)** fixable inside this umbrella repo · **(b)** requires
writing into a submodule working tree (operator decision, push blast radius) ·
**(c)** genuinely upstream / third-party, not ours.

The 17 propagation gates are **mixed (b + c)**: each one is held FAIL by five
carriers at once — one owned-submodule carrier (b) and four third-party
carriers (c). Clearing the (b) carrier alone does **not** flip any of them.

| # | Gate | Exact failing assertion (quoted from its own output) | File(s) named | Cat. | Category (a) fix |
|---|---|---|---|---|---|
| 1 | `cm_covenant_114_162_propagation.sh` | `❌ CM-COVENANT-114-162-PROPAGATION: FAIL — 5 owned carrier(s) missing §11.4.162 anchor` — `❌ MISSING  <carrier>  — lacks anchor literal 11.4.162` ×5 | the five carriers of §3.1 | b+c | — |
| 2 | `cm_covenant_114_167_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.167` ×5 | same five | b+c | — |
| 3 | `cm_covenant_114_176_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.176` ×5 | same five | b+c | — |
| 4 | `cm_covenant_114_187_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.187` ×5 | same five | b+c | — |
| 5 | `cm_covenant_114_191_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.191` ×5 | same five | b+c | — |
| 6 | `cm_covenant_114_196_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.196` ×5 | same five | b+c | — |
| 7 | `cm_covenant_114_199_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.199` ×5 | same five | b+c | — |
| 8 | `cm_covenant_114_200_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.200` ×5 | same five | b+c | — |
| 9 | `cm_covenant_114_201_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.201` ×5 | same five | b+c | — |
| 10 | `cm_covenant_114_202_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.202` ×5 | same five | b+c | — |
| 11 | `cm_covenant_114_207_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.207` ×5 | same five | b+c | — |
| 12 | `cm_covenant_114_213_propagation.sh` | `❌ MISSING  <carrier>  — lacks anchor literal 11.4.213` ×5 | same five | b+c | — |
| 13 | `cm_covenant_114_230_propagation.sh` | `❌ CM-COVENANT-114-230-PROPAGATION: FAIL — anchor-block integrity violated for §11.4.230`; `❌ MISSING     <carrier>  — zero 11.4.230 block-starts (bare-literal citations elsewhere do not count, §11.4.201(7)(a))` ×5 | same five | b+c | — |
| 14 | `cm_covenant_114_231_propagation.sh` | `❌ MISSING     <carrier>  — zero 11.4.231 block-starts (…§11.4.201(7)(a))` ×5 | same five | b+c | — |
| 15 | `cm_covenant_114_232_propagation.sh` | `❌ MISSING     <carrier>  — zero 11.4.232 block-starts (…§11.4.201(7)(a))` ×5 | same five | b+c | — |
| 16 | `cm_covenant_114_233_propagation.sh` | `❌ MISSING     <carrier>  — zero 11.4.233 block-starts (…§11.4.201(7)(a))` ×5 | same five | b+c | — |
| 17 | `cm_covenant_114_235_propagation.sh` | `❌ MISSING     <carrier>  — zero 11.4.235 block-starts (…§11.4.201(7)(a))` ×5 | same five | b+c | — |
| 18 | `cm_continuum_resume_engine_present.sh` | `❌ FOUND    project-specific literal(s) inside the engine (decoupling violation):` / `            submodules/continuum/test/e2e/e2e_test.go` | `submodules/constitution/submodules/continuum/test/e2e/e2e_test.go` line 118 | b | — |
| 19 | `cm_gate_ledger_ratchet.sh` | `LEDGER-FAIL: ratchet violated — unimplemented=432 exceeds checked-in baseline=420 (a CM-* gate was named with neither an implementation nor a registered deferral…)` | `submodules/constitution/scripts/gates/gate_ledger_baseline.txt`, `…/gate_ledger_deferrals.tsv`, `submodules/constitution/Constitution.md` | b | — |
| 20 | `cm_track_branch_label.sh` | `❌ ALIAS-VALIDATION: labeler did not yield the known synthetic alias (got 'xhigh' from '(T1/main - cmgatechk - ? - xhigh)')` | `submodules/constitution/scripts/gates/cm_track_branch_label.sh` (`_label_alias`, lines 91–97) vs `submodules/constitution/scripts/multitrack/track_branch_label.sh:268` | b | — |
| 21 | `cm_track_branch_label_mutation_test.sh` | `❌ META FAIL: clean fixture (real hook validates the alias field) — gate FAILed unexpectedly (false alarm!)`; `❌ META FAIL: RESTORED fixture (real hook re-audited) — gate FAILed unexpectedly (false alarm!)`; `❌ META FAIL: CM-TRACK-BRANCH-LABEL failed the §1.1 discriminator` | same two files as #20 | b | — |

**Row-level counts: (a) 0 · pure (b) 4 · pure (c) 0 · mixed (b + c) 17.**

**Root-cause counts** (the five carriers behind rows 1–17, plus the three
constitution-internal defects behind rows 18–21): **(a) 0 · (b) 4 · (c) 4.**

### 3.1 The five carriers behind rows 1–17

| Carrier | Lives in | Owning repo | Cat. | Why it is not an umbrella fix |
|---|---|---|---|---|
| `milosvasic.ru/Upstreamable/AGENTS.md` | gitlink **inside** the `milosvasic.ru` submodule | `red-elf/Upstreamable` (`milosvasic.ru/.gitmodules:3`) | c | Third-party, two levels down. This project neither owns nor pushes it. |
| `milosvasic.ru/Upstreamable/CLAUDE.md` | same | `red-elf/Upstreamable` | c | same |
| `submodules/superspec/examples/static-landing-page/CLAUDE.md` | `submodules/superspec` submodule | `WangX0111/superspec` | c | Third-party. A 5-line demo fixture that points at `specs/001-static-landing-page/plan.md`; it is not a governance carrier, it is only *named* like one. |
| `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` | **umbrella working tree** (`git ls-files` tracks it) | vendored copy of `WangX0111/superspec` v1.0.2 | c | **Physically writable here — deliberately not written.** It is one of 59 tracked files of a vendored third-party spec-kit extension (`.specify/extensions/.registry` pins `manifest_hash: sha256:6e23ee6c…`), byte-identical to the submodule copy. Injecting 17 constitution anchor blocks into a third-party demo fixture would fork the vendored artifact from its upstream and invalidate its manifest hash, to satisfy a gate that is misreading a demo file as a governance carrier. Recorded as a non-fix, not as an impossibility. |
| `vasic.digital/QWEN.md` | `vasic.digital` submodule | `vasic-digital/vasic-digital.github.io` — **owned** | b | The only owned gap. Requires writing into a submodule working tree and a push that redeploys a live GitHub Pages site — see §6. |

Note the arithmetic that decides rows 1–17: even if the operator applies the
(b) fix to `vasic.digital/QWEN.md`, **four (c) carriers remain and all 17 gates
still FAIL.** There is no umbrella-side change that flips any of the 21.

---

## 4. What was actually fixed

**One change, in the umbrella repo, verdict-neutral.**

`scripts/verify-all-constitution-rules.sh` — the header comment describing how
`gate_ledger.sh` is invoked stated that a bare invocation "prints its usage and
exits 0, which would be a false PASS". Measured behaviour is `exit 2`. Under
this sweep rc=2 scores ERROR (§11.4.201(7)(b)), never PASS, so the comment
misdescribed both the exit code and the hazard it was warning about. §11.4.6
forbids leaving a verified-false statement in place. The comment now reads:

```
#   2. Else if it offers a `selfcheck)` subcommand    -> run `selfcheck <tmpdir>`.
#      (`gate_ledger.sh` is a multi-subcommand tool: invoked bare it prints its
#      usage and exits 2 — verified 2026-08-27 — so the sweep would score it
#      ERROR (a blind instrument, §11.4.201(7)(b)), never PASS. Either way a
#      bare invocation proves nothing, so its documented self-test is used
#      instead.)
```

`bash -n scripts/verify-all-constitution-rules.sh` → clean. Executable logic
untouched: the resolution branch it documents (`grep -qE
'^[[:space:]]*selfcheck\)'`) is unchanged, and `gate_ledger.sh` still runs as
`selfcheck <scratch>`.

**Nothing else was changed.** In particular:

- No submodule working tree was written to.
- No mutating git command was run (no `add`/`commit`/`push`/`fetch`/
  `checkout`/`submodule update`).
- The four root carriers `CLAUDE.md` / `AGENTS.md` / `QWEN.md` / `GEMINI.md`
  were **not** modified by this triage — no fix required it.
  §11.4.157 lockstep verified twice with
  `tail -n +24 <f> | sha256sum`: `d26e2c31252d8837…` for all four at the start
  of the triage, `961f47134720080e…` for all four at the end. The bodies
  changed under this task — an edit from work outside it, visible as `9 ++---`
  on each of the four plus one line of `Constitution.md` in `git status`. All
  four moved together, so the lockstep held; it is recorded here because a
  reader comparing digests would otherwise think this task moved them.
- No gate verdict was suppressed, allowlisted or downgraded.

---

## 5. After — the sweep re-run

```
gates run           : 58
  PASS              : 37
  FAIL   (rc=1)     : 21
  ERROR  (rc!=0,1)  : 0
§11.4.32 step 1     : skip
❌ SWEEP: FAIL — 21 FAIL + 0 ERROR out of 58 gate(s).
```

Sweep exit code: `1`. The failure **set** is byte-identical to the before run,
not merely the same size:

```
$ diff <(sed -n '/^FAILED:/,/^$/p' /tmp/sweep.txt) \
       <(sed -n '/^FAILED:/,/^$/p' /tmp/sweep-after.txt) && echo IDENTICAL
IDENTICAL
$ grep -c "❌ MISSING" /tmp/sweep-after.txt
85
```

**Before → after: 37 PASS / 21 FAIL / 0 ERROR → 37 PASS / 21 FAIL / 0 ERROR.**
Unchanged, and that is the correct outcome: every one of the 21 is blocked
behind a submodule write or a third-party repository. A number that improved
here would have meant a verdict was gamed.

---

## 6. Requires operator decision — the category (b) items

Each item below needs a write into a submodule working tree and a push. The
push fan-out is stated because it is the real cost of the decision.

### 6.1 `vasic.digital/QWEN.md` — blocks rows 1–17 (partially)

- **Change:** give `vasic.digital/QWEN.md` the 17 anchors (or make it a genuine
  §11.4.35 pointer consumer so the propagation gates skip it).
- **Push blast radius:** `vasic.digital` — `origin`, `github`, `upstream` all
  fetch **and** push the single URL
  `git@github.com:vasic-digital/vasic-digital.github.io.git`. **One distinct
  URL — and it is a live GitHub Pages site: a push redeploys the site.**
- **⚠ The staged fix does not do what the record claims.**
  `Constitution.md` → "Known-excluded gate findings" says the fix "is staged at
  `docs/constitution-adoption/propagation/vasic.digital/QWEN.insert-block.md`".
  Read as staged, it would **not** clear a single propagation gate:
  - `QWEN.insert-block.md` contains **none** of the 17 anchor literals
    (`11.4.162`, `11.4.167`, … `11.4.235`) — it cites only §11.4.28.
  - It opens `> **Base agent rules:** …`, a blockquote — **not** a real,
    non-fenced, line-anchored `## INHERITED FROM ` heading — so
    `is_pointer_carrier()` will not recognise it and the gates will not skip
    the file.
  - Worse, `APPLY.md` §4.6 also copies `AGENTS.md.staged`, `CLAUDE.md.staged`
    and `GEMINI.md.staged` into `vasic.digital/`. Those three open
    `# CLAUDE.md — vasic.digital` / `## Helix Constitution inheritance` —
    again not `## INHERITED FROM `. Applying §4.6 as written would create
    **three new discovered carriers that also lack every anchor**, taking the
    fleet from 5 MISSING carriers to 8 and the total from **85 MISSING lines
    to 136**. The 17 gates would still FAIL, louder.
  - **Operator action required before applying §4.6:** either add the anchors
    to all four vasic.digital carriers, or restructure them to start with a
    real `## INHERITED FROM ` heading. Applying the staged files unchanged
    makes the sweep worse.

### 6.2 `cm_continuum_resume_engine_present.sh` — row 18

- **Change:** remove the single ATMOSphere literal from the resume engine —
  `submodules/constitution/submodules/continuum/test/e2e/e2e_test.go:118`:
  `b, err := resume.Render(fresh, "", resume.Options{Title: "ATMOSphere fleet resume"})`.
  The gate's denylist is
  `atmosphere|rockchip|kinopoisk|orange[[:space:]]*pi|/mnt/track`; this is the
  only hit in the whole engine. Everything else in the gate passes, including
  `go test -race ./...` and the continuum selfcheck.
- **Push blast radius:** `submodules/constitution/submodules/continuum` —
  `origin` only, `git@github.com:vasic-digital/continuum.git`. **One URL.**
  A **nested** submodule (a gitlink of `submodules/constitution`), so landing it
  also bumps the constitution's gitlink → §6.4's 6-URL fan-out.

### 6.3 `cm_track_branch_label.sh` + its mutation test — rows 20 and 21

- **Root cause (a real defect, not an environment quirk):** the reference
  labeler `submodules/constitution/scripts/multitrack/track_branch_label.sh:268`
  now emits a **five**-field label —
  `printf '(T%s/%s - %s - %s - %s)\n' "$_n" "$_br" "$_al" "$_mo" "$_ef"` →
  `(T1/main - cmgatechk - ? - xhigh)` — while the gate's helper `_label_alias()`
  (`cm_track_branch_label.sh:91-97`) still extracts the alias with
  `${_p##* - }`, i.e. the **last** field. It therefore reads the *effort*
  (`xhigh`) where it expects the *alias* (`cmgatechk`). This is unconditional:
  whatever the effort field resolves to, the last field is never the alias.
  The gate/labeler pair drifted apart; the gate was not updated when the label
  grew model + effort fields.
- **Change:** in `_label_alias()`, select the alias **positionally** (field 2 of
  the ` - `-separated label) instead of taking the trailing field.
- **Row 21 is a consequence, not an independent defect.** The mutation test's
  own output proves it: its two `❌ META FAIL` lines are both on the *clean* and
  the *RESTORED* fixtures ("gate FAILed unexpectedly (false alarm!)"), while all
  three genuine mutations were caught (`✅ META OK` ×3). The discriminator is
  intact; it fails only because the gate it audits false-alarms. Fixing #20
  fixes #21.
- **Push blast radius:** `submodules/constitution` — see §6.4.

### 6.4 `cm_gate_ledger_ratchet.sh` — row 19

- **Change:** inside `submodules/constitution`, either land the ~12 missing
  gate implementations, register their deferrals in
  `scripts/gates/gate_ledger_deferrals.tsv` against tracked items, or make an
  explicit, reviewable commit raising `scripts/gates/gate_ledger_baseline.txt`
  from `420`. Every input — `Constitution.md`, `scripts/`, and the three
  registries — lives inside the submodule. **Nothing in the umbrella can move
  this number.**
- **Push blast radius:** `submodules/constitution` — `origin` **pushes to 6
  URLs** in one command:
  `git@gitflic.ru:helixdevelopment/helixconstitution.git`,
  `git@github.com:HelixDevelopment/HelixConstitution.git`,
  `git@gitlab.com:helixdevelopment1/helixconstitution.git`,
  `git@gitverse.ru:helixdevelopment/HelixConstitution.git`,
  `git@github.com:vasic-digital/HelixConstitution.git`,
  `git@gitlab.com:vasic-digital/HelixConstitution.git`.
  Rows 18, 19, 20 and 21 all land here, and each one changes the constitution
  every consuming project inherits.

### 6.5 For completeness — other owned submodules named in `APPLY.md`

Not implicated in any of the 21 failures, but the same operator decision
governs them, and their fan-out is larger:

- `monetization` — `origin` **pushes to 4 URLs**:
  `git@gitflic.ru:milosvasic/monetization.git`,
  `git@github.com:milos85vasic/monetization.git`,
  `git@gitlab.com:milos85vasic/monetization.git`,
  `ssh://git@gitverse.ru:2222/milosvasic/monetization.git`.
- `milosvasic.ru` — `origin` **pushes to 2 URLs** it does **not** fetch from
  (`gitflic.ru:milosvasic/milosvasic-net-v-2`,
  `github.com:milos85vasic/milosvasic.net.v2`), while fetching from a third
  that receives nothing. That fetch/push asymmetry is already recorded in
  `Constitution.md` as an open operator decision.

---

## 7. Category (c) — upstream / third-party, not ours

| Item | Repo | Where it would have to be fixed |
|---|---|---|
| `milosvasic.ru/Upstreamable/AGENTS.md` | `red-elf/Upstreamable` | upstream, a gitlink of a submodule |
| `milosvasic.ru/Upstreamable/CLAUDE.md` | `red-elf/Upstreamable` | upstream, same |
| `submodules/superspec/examples/static-landing-page/CLAUDE.md` | `WangX0111/superspec` | upstream |
| `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` | vendored `WangX0111/superspec` v1.0.2 | upstream — writable here, deliberately not written (see §3.1) |

The more durable fix for all four is **upstream in the gate family**, per
§11.4.26: the propagation gates discover carriers by bare filename and prune
only `node_modules|.git|out|build|dist|prebuilts|external|vendor|target`. A
third-party submodule tree and a vendored extension's demo fixture are neither
owned nor governance carriers, yet both are scored as owned carriers. Any
in-repo workaround for that would be an allowlist, which this triage will not
write.

---

## 8. False failures and false passes found

### 8.1 No false failure among the 21

All 21 were reproduced by hand, with the argv each gate's own usage header
dictates. Every failing assertion is a true statement about the tree. Two
false-verdict *hazards* exist but the sweep avoids both:

- **Wrong `--root` → false PASS.** `cm_covenant_114_162_propagation.sh --root
  submodules/constitution` reports `0 MISSING` and exits 0, because it then
  only sees the constitution's own carriers. The sweep passes the repo root.
- **Wrong `--root` → false FAIL.** `cm_continuum_resume_engine_present.sh
  --root .` reports the engine, `go.mod` and `helix-deps.yaml` all MISSING and
  exits 1. The sweep passes `submodules/constitution`.

Every gate that accepts `--root` declares its kind in its usage header — checked
across all 57 — so the sweep's header-driven resolution has no undeclared case
to fall through on.

### 8.2 `CM-OPENDESIGN-UI-SYSTEM` is a false PASS

```
PASS  rc=0  cm_opendesign_ui_system.sh  --root /run/media/…/vasic
  ⏭️  SKIP CM-OPENDESIGN-UI-SYSTEM: no UI surface detected under …/vasic
      (no theme/token/visreg sources matched OD_*_GLOBS) — §11.4.3
      SKIP-with-reason, not a fake PASS
```

The skip **reason is factually false for this repository.** There is a real UI
surface — `design-system/learning-kit/kit-tokens.css`,
`design-system/brand-vasic-digital/vasic-digital.css`,
`design-system/brand-milosvasic/milosvasic.css`,
`design-system/components-extended.css`, `design-system/motion/*.css`,
`design-system/fonts/fonts.css`. The gate's defaults
(`OD_THEME_GLOBS="src/theme/* src/styles/* styles/* theme/* …"`,
`OD_TOKEN_GLOBS="tokens.json design-tokens/* …"`) simply do not describe this
repo's layout, and the umbrella never binds `OD_*_GLOBS`. The gate is therefore
scored PASS while never having looked at the design system §11.4.162 governs.

**Not changed here**, for two reasons: it is not one of the 21 under triage, and
binding `OD_*_GLOBS` would turn a PASS into a FAIL — the honest direction, but a
scope and configuration decision for the operator, not a silent edit. Recorded
as the outstanding action.

### 8.3 The "37 PASS" figure includes 3 reasoned SKIPs

Three gates exit 0 via an explicit §11.4.3 skip and are counted as PASS, because
the sweep's SUMMARY has no SKIP column:

| Gate | Skip reason | Honest? |
|---|---|---|
| `cm_build_on_source_proven_not_test_side.sh` | `feature_disabled_by_config: no consumer marker-binding config` | yes — the feature genuinely is unbound |
| `cm_version_increment_on_deploy.sh` | `feature_disabled_by_config: no consumer deploy-ledger binding` | yes — same |
| `cm_opendesign_ui_system.sh` | `no UI surface detected` | **no** — see §8.2 |

So `37 PASS` is more precisely **34 enforced PASS + 2 honest unbound-feature
SKIPs + 1 false SKIP**. Adding a SKIP column to the sweep's summary would make
the sweep's own reporting §11.4.6-honest; it is a reporting change with no
verdict impact, and is left as an operator call alongside §8.2.

### 8.4 The `Constitution.md` "staged fix" claim is optimistic

Section 6.1 above. The record says the `vasic.digital/QWEN.md` fix "is staged
and awaits operator application"; the staged artefact would not clear the gates,
and applying `APPLY.md` §4.6 unchanged would raise the MISSING count from 85 to
136. This is the one item in the existing record that a reader could act on and
be worse off for.

---

## 9. 2026-09-02 — the first completed post-fast-forward sweep

Everything above this line describes a **58-gate** sweep against the
pre-fast-forward constitution. This section is the first sweep to **run to
completion** after the fast-forward, and it supersedes §1–§8 entirely.

### 9.1 How it was run

```
bash scripts/verify-all-constitution-rules.sh > <scratch>/sweep-2026-09-02.txt 2>&1
```

No flags. No `--quiet`. Nothing silenced, nothing narrowed. The run was launched
detached and polled to completion; wall clock **≈ 2 h 45 min**, output
**718,345 lines / 105,209,937 bytes** (see §9.6 — 714,162 of those lines come
from a single gate that was pointed at the wrong tree).

Evidence file, preserved:
`<scratch>/sweep-2026-09-02.txt` under
`/tmp/.private/milosvasic/claude-1000/-run-media-milosvasic-DATA4TB-Projects-vasic/8b2dcbd5-36ee-4998-811b-54668193abff/scratchpad/`.

### 9.2 The exact split

Quoted verbatim from the run's own `SUMMARY` block (lines 3305–3312):

```
gates run           : 287
  PASS              : 186
  FAIL   (rc=1)     : 95
  ERROR  (rc!=0,1)  : 6
§11.4.32 step 1     : pass
```

Closing line and exit code, verbatim:

```
❌ SWEEP: FAIL — 95 FAIL + 6 ERROR out of 287 gate(s).
EXIT_CODE=1
```

- **287 gates** = 286 discovered dynamically under
  `submodules/constitution/scripts/gates/**` + 1 project-side
  `tests/test_constitution_inheritance.sh` (which **PASSed**, 8 PASS / 0 SKIP /
  0 FAIL).
- **§11.4.32 step 1 = pass** — `scripts/verify-governance-cascade.sh` returned
  rc=0 inside the sweep. Step 1 is no longer a SKIP; OC-3 stays resolved.
- **Constitution HEAD at run time: `f5876a3b700eb9a8792c1f19baca77959a2a7e88`**,
  as the sweep's own header line records.

> **The pin moved under this measurement, and that is stated rather than hidden
> (§11.4.6).** Re-measured immediately after the run,
> `git -C submodules/constitution rev-parse HEAD` returns
> **`3be10826f3d236edcdb62b7cba81cda4e6d0d47a`** — a different commit from the
> `f5876a3b700e` the sweep ran against, and different again from the
> `f16ea779b82a` the root carriers record. Concurrent work moved the gitlink
> while this sweep was running. **The split in §9.2 is a measurement of
> `f5876a3b700e` and of nothing else**; a re-run today may differ, and the
> honest response is to re-run, not to quote this number as standing fact.

The prior figure on record — *"186 PASS / 95 FAIL / 6 ERROR of 287 gates"*,
carried in the root carriers as a **reported prior measurement** from a run that
never finished — is now **CONFIRMED by a completed run**. It was accurate. It is
no longer a report of somebody else's number.

### 9.3 The three buckets

Row-level assignment — each of the 101 non-PASS rows gets exactly one primary
bucket, so nothing is double-counted:

| Bucket | Rows | Of which FAIL | Of which ERROR |
|---|---:|---:|---:|
| **(a)** third-party and staged carriers | **82** | 82 | 0 |
| **(b)** defects internal to the constitution submodule | **5** | 4 | 1 |
| **(c)** genuinely ours | **14** | 9 | 5 |
| **Total** | **101** | 95 | 6 |

Four of the fourteen (c) rows are **mixed (b + c)** and are counted in (c)
deliberately — see §9.5 item **C6**: an upstream path-derivation defect points
them at the wrong directory, *and* the artifact they look for does not exist at
the right directory either, so clearing the upstream half alone would not flip
any of them.

**Neither (a) nor (b) licenses treating this sweep as green.** Both classes
still FAIL, both still make the sweep exit 1, and both are still printed in
full. Excluded from `verify-governance-cascade.sh`'s own verdict means *not
double-counted there*, never *suppressed anywhere* (§11.4.6).

### 9.4 Bucket (a) — third-party and staged carriers · 82 rows

Every one of the 82 rows is a `cm_covenant_114_<N>_propagation.sh` gate. Run at
the correct root, each reports the **identical shape** and is held FAIL by
**exactly five carriers**, none of which any commit in this repository can
change:

| # | Carrier | Owning repository | Why it is not ours |
|---|---|---|---|
| 1 | `milosvasic.ru/Upstreamable/AGENTS.md` | `red-elf/Upstreamable` | third-party, a gitlink **inside** the `milosvasic.ru` submodule — two levels down |
| 2 | `milosvasic.ru/Upstreamable/CLAUDE.md` | `red-elf/Upstreamable` | same |
| 3 | `submodules/superspec/examples/static-landing-page/CLAUDE.md` | `WangX0111/superspec` | third-party; a 5-line demo fixture only *named* like a governance carrier |
| 4 | `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` | vendored `WangX0111/superspec` v1.0.2 | tracked here and physically writable — **deliberately not written** (§3.1 of this document explains why: it would fork the vendored artifact from upstream and invalidate its manifest hash) |
| 5 | `workshop/pipeline/engines/whisper.cpp/AGENTS.md` | upstream **whisper.cpp** | **NEW since the 2026-08-27 triage** — the vendored whisper.cpp build tree inside the private `workshop` submodule. It is a third-party inference engine's own repository file, not a governance carrier; it was pulled in when the ASR stack was built |

Measured, quoted from the one propagation gate the sweep argv-resolved correctly
(`cm_covenant_114_167_propagation.sh`):

```
CM-COVENANT-114-167-PROPAGATION: 4 PRESENT, 64 POINTER-INHERITANCE-SKIP, 5 MISSING
  (anchor 11.4.167) under /run/media/milosvasic/DATA4TB/Projects/vasic
```

and re-derived independently for a fence-aware member of the family
(`cm_covenant_114_162_propagation.sh --root <repo>`):

```
CM-COVENANT-114-162-PROPAGATION: 4 single-block-PRESENT, 64 POINTER-INHERITANCE-SKIP,
  5 MISSING/DUPLICATED, 0 DIVERGENT (anchor 11.4.162) under /run/media/…/vasic
```

**`0 DIVERGENT` — no carrier holds a corrupted or duplicated anchor block. The
only defect in this family is absence.**

**One real improvement since 2026-08-27, measured not assumed:**
`vasic.digital/QWEN.md` — the single *owned* carrier §3.1 named as the lone
category-(b) gap — **no longer appears in any MISSING list**. The owned half of
the propagation problem is closed; what remains is entirely third-party. The
`POINTER-INHERITANCE-SKIP` count also moved 11 → 64 as the fleet grew and the
new carriers were authored as genuine §11.4.35 pointer consumers.

### 9.5 Bucket (b) — internal to the constitution submodule · 5 rows

Upstream code this repository consumes rather than owns. **No commit made here
can clear any of these.**

| # | Gate | Verdict | The defect, quoted from its own output |
|---|---|---|---|
| 1 | `cm_continuum_resume_engine_present.sh` | FAIL | `❌ FOUND project-specific literal(s) inside the engine (decoupling violation):` naming `submodules/continuum/pkg/chain/exec_call_test.go` **and** `submodules/continuum/test/e2e/e2e_test.go`. Everything else in the gate passes (`go test -race ./...` race-clean; continuum selfcheck good=PASS bad=FAIL negctrl=PASS). **Two files now, not one** — §6.2 of this document recorded only `e2e_test.go`. Both live in a *nested* gitlink of the constitution. |
| 2 | `cm_opendesign_ui_system_mutation_test.sh` | FAIL | `❌ META FAIL: propagation gate / clean fleet — gate FAILed on a clean fixture (false alarm!)`. Three of its four meta-assertions pass. This is a **§11.4.201(1) false-positive refusal inside the constitution's own §1.1 mutation pair** — the gate accuses a clean fixture. |
| 3 | `cm_dependency_register_verdicts_mutation_test.sh` | FAIL | `[FAIL] baseline DRV-A4-NAME-COLLISION-AMBIGUOUS = ABSENT_ID — a mutation cannot be shown to flip an assertion that is not passing to begin with`, and the same for `DRV-A2`, `DRV-A3`, `DRV-A5`. The mutation test cannot establish a surgical control because its own gate has no consumer register to assert against (§9.5 C6). |
| 4 | `cm_instrument_trap_scan_mutation_test.sh` | FAIL | `PAIR-NOT-DEMONSTRATED: required file absent: …/submodules/scripts/testing/anti_slop/us2_trap_scan_red.sh` |
| 5 | `lib/instrument_trap_scan.sh` | ERROR rc=2 | `SELFTEST-BLIND fixtures not found at …/scripts/gates/lib/../../../../scripts/testing/anti_slop/fixtures/traps — reporting blindness, not compliance`. The `../../../../` walk assumes the constitution sits at `<consumer>/constitution`; this repository places it at `<consumer>/submodules/constitution`, so the walk lands one level short. Honest of the gate to report blindness rather than pass — the defect is the hardcoded walk, and it is upstream. |

### 9.6 Bucket (c) — genuinely ours · 14 rows

**This is the actionable output.** Every item below names the gate, the file, and
what it would take to fix.

---

#### C1 — `resolve_argv` in our own sweep points 85 of 287 gates at the WRONG TREE — **FIXED 2026-09-02, see the block at the end of this item**

**This is the largest finding in the run, and it is entirely ours.**

- **Gate(s) affected:** 81 `cm_covenant_114_*_propagation.sh` +
  `cm_oracle_strategy_named_and_independent.sh` +
  `cm_test_mock_pid_explicit_int.sh` +
  `cm_dangerous_combination_fail_closed.sh` + `cm_killpg_pgid_guard.sh`
  = **85 gates**.
- **File:** `scripts/verify-all-constitution-rules.sh`, `resolve_argv()`,
  lines 199–219.

**What happens.** With no `--root` resolved, each gate falls back to its own
default consumer root — `root="${CONSUMER_ROOT:-..}"` in
`lib/covenant_propagation_engine.sh:182` — and `..` from the sweep's cwd is
**`/run/media/milosvasic/DATA4TB/Projects`, the parent of this repository**: the
operator's entire projects directory, dozens of unrelated repositories.

**Two distinct sub-defects, both in our resolver:**

- **C1a — the header lookup is gated behind a case-branch grep.** `resolve_argv`
  only consults a gate's usage header *after*
  `grep -qE '^[[:space:]]*--root\)' "$g"` succeeds. The propagation family was
  refactored upstream into **thin wrappers** (§11.4.251 role-as-data-pack): 61
  lines each, arg parsing delegated to the sourced
  `lib/covenant_propagation_engine.sh`, so **no `--root)` branch exists in the
  wrapper file** — even though its usage header plainly says
  `--root <consumer-root>`. Measured: `grep -c '^\s*--root)'` returns **0** for
  `cm_covenant_114_162_propagation.sh` (61 lines) and **1** for the one
  non-wrapper `cm_covenant_114_167_propagation.sh` (127 lines) — which is
  exactly why 81 of 82 got no root and one did.
- **C1b — the `root_kind` case has an unhandled vocabulary.** The case handles
  `constitution-root` and `consumer-root|project-root` only.
  `cm_oracle_strategy_named_and_independent.sh` and
  `cm_test_mock_pid_explicit_int.sh` both declare **`--root <dir>`**, which falls
  through to `*) argv=""` and takes the gate's default.

**Measured consequences — four separate harms, none of them hypothetical:**

1. **81 propagation gates FAIL with ZERO BYTES of output.** Reproduced directly:
   ```
   $ bash submodules/constitution/scripts/gates/cm_covenant_114_162_propagation.sh
   rc=1  output_bytes=0          # stdout AND stderr both empty
   ```
   The engine dies under `set -euo pipefail` mid-scan of the parent directory —
   it has no `exit 1` path of its own (`grep -nE 'exit [0-9]' engine` returns
   one line, an `exit 2`). A silent rc=1 is scored **FAIL** by the sweep, i.e.
   **a blind instrument is being reported as an accusation against this tree** —
   the §11.4.201(7)(b) hazard, inverted.
2. **`cm_test_mock_pid_explicit_int.sh` is a FALSE FAIL.** At the correct root it
   **PASSES**:
   ```
   $ bash …/cm_test_mock_pid_explicit_int.sh --root /run/media/…/vasic
   rc=0
   ✅ CM-TEST-MOCK-PID-EXPLICIT-INT: PASS — every '.pid'-read Mock/MagicMock/AsyncMock
      in scanned test files sets '.pid' explicitly as an int (§11.4.263)
   ```
   A §11.4.201(1) false-positive refusal produced by our own instrument.
3. **`cm_oracle_strategy_named_and_independent.sh` emitted 714,162 lines** — the
   105 MB in §9.1 is almost entirely this one gate reading unrelated projects. At
   the correct root it emits **15,156** and reaches a verdict about *this* tree
   (see **C5**).
4. **Two gates hit the 900 s `GATE_TIMEOUT` and scored ERROR rc=124** —
   `cm_dangerous_combination_fail_closed.sh` and `cm_killpg_pgid_guard.sh`. Both
   detail blocks open with
   `find: '/run/media/milosvasic/DATA4TB/Projects/proxy/cache/squid/00': Permission denied`,
   which is the direct proof they were walking the parent tree. They are ERRORs
   because the wrong tree is enormous, not because anything here is wrong.

**Proof the diagnosis is right, not merely plausible:**

```
$ CONSUMER_ROOT=/run/media/…/vasic bash …/cm_covenant_114_162_propagation.sh
rc=1  lines=76
CM-COVENANT-114-162-PROPAGATION: 4 single-block-PRESENT, 64 POINTER-INHERITANCE-SKIP,
  5 MISSING/DUPLICATED, 0 DIVERGENT (anchor 11.4.162) under /run/media/…/vasic
```

Zero bytes → a full, readable, correctly-scoped verdict.

**The fix (three lines of our own script, no submodule write):**

1. In `resolve_argv`, consult the gate's **usage header first** — the
   `grep -oE -- '--root <[a-z-]+>'` lookup already exists; **ungate it** from the
   `--root)` case-branch grep so a thin wrapper that documents `--root` gets one.
2. Add **`dir`** to the `root_kind` case as a consumer root, alongside
   `consumer-root|project-root`.
3. Belt and braces: `export CONSUMER_ROOT="$root"` next to the existing
   `OD_*_GLOBS` exports, so any gate reading that variable defaults correctly
   even if its header says nothing.

~~**Until this is fixed, 85 of the 287 verdicts in §9.2 are statements about the
wrong directory and must not be read as findings about this repository.** The
95/6 split is a true report of what the sweep did; it is not yet a true report
of what this tree is.~~

**FIXED 2026-09-02, and re-measured by a completed sweep. The strike-through
above is kept because the number it carries is what the fix had to move.**

**The change.** `resolve_argv` in `scripts/verify-all-constitution-rules.sh` no
longer gates the usage-header lookup behind the gate's own `--root)` case arm. It
now asks three questions of the gate, each with a real counter-example in this
pin's corpus, and one of the three was NOT in the remedy as written above:

| | Question | Why it is not optional |
|---|---|---|
| A | Is the `--root <kind>` text in the gate's OWN leading comment header? | `covenant_propagation_wrappers_generate.sh` carries `--root <consumer-root>` inside the **heredoc template it emits** — the interface of the wrappers it generates, not its own. A file-wide grep reads generated text as a declaration. Header-scoping changes the answer for exactly **1** file of 286, and it is that one. |
| B | Will some parser actually RECEIVE it — its own `--root)` arm, or one in a `lib/*.sh` it names? | **Not in the prescribed remedy, and required.** `covenant_propagation_suite.sh` documents `suite gates [--root <consumer-root>]` but parses no flags and needs a subcommand first; handing it a root turns a usage refusal into an rc=2 ERROR scored against this tree. Ungating without this test trades one wrong verdict for another. |
| C | Which root does the generic `<dir>` mean? | `cm_first_refusal_observed.sh` declares `--root <dir>` and means the **constitution** root (`root="${CONSTITUTION_ROOT:-…}"`); `cm_oracle_strategy_named_and_independent.sh` declares the same `<dir>` and means the tree under test. The discriminator is the gate's own description on that line, folded across every `--root <dir>` header line — the first such line is usually the bare SYNOPSIS, which describes nothing. |

Plus `export CONSUMER_ROOT="$root"` as prescribed — authoritative, not
`${CONSUMER_ROOT:-$root}`, so a stale value in the caller's shell cannot redirect
286 gates at another tree.

**Root resolution, before and after** (`--list`, counted from its own output):

| | project root | constitution root | own default |
|---|---:|---:|---:|
| before | 17 | 3 | 266 |
| after | **104** | 3 | 179 |

**87 gates newly receive a root; nothing lost one and no gate's resolved root
changed side.** 81 are the propagation wrappers; the other 6 are
`cm_dangerous_combination_fail_closed`, `cm_killpg_pgid_guard`,
`cm_ledger_row_typed_from_closed_vocabulary`,
`cm_oracle_strategy_named_and_independent`, `cm_test_mock_pid_explicit_int` and
`cm_unchallenged_capability_blocks_release`. The last two of those six were not
in the 85: their own default is `${CONSUMER_ROOT:-.}`, which was already the
right directory when the sweep is run from the repository root. They are now
explicit rather than accidentally correct.

**All four measured harms are cleared, each re-measured rather than inferred:**

| Harm (as recorded above) | Before | After |
|---|---|---|
| 81 propagation gates FAIL emitting zero bytes | **81** zero-output detail blocks | **0** |
| `cm_test_mock_pid_explicit_int.sh` FALSE FAIL | FAIL rc=1 | **PASS rc=0** |
| `cm_oracle_strategy…` output volume | 714,162 lines | **15,158** |
| two gates at the 900 s timeout | ERROR rc=124 ×2 | **FAIL rc=1** in 62 s and 65 s — real findings about this tree |

**The re-run split, and the whole diff between the two runs.** Same command, no
flags, nothing silenced:

```
gates run           : 287
  PASS              : 187
  FAIL   (rc=1)     : 96
  ERROR  (rc!=0,1)  : 4
§11.4.32 step 1     : pass
expected-gate ledger: clean
❌ SWEEP: FAIL — 96 FAIL + 4 ERROR out of 287 gate(s).
```

Against §9.2's **186 / 95 / 6**, exactly **three** rows changed verdict, and they
are the three the fix predicted:

```
cm_dangerous_combination_fail_closed.sh   ERROR rc=124 -> FAIL rc=1
cm_killpg_pgid_guard.sh                   ERROR rc=124 -> FAIL rc=1
cm_test_mock_pid_explicit_int.sh          FAIL  rc=1   -> PASS rc=0
```

Wall clock **867 s** (14 m 27 s) against ≈2 h 45 min, output **3,676,727 bytes /
25,970 lines** against 105,209,937 bytes / 718,345 lines. Evidence file:
`<scratch>/sweep-2026-09-02-postC1.txt`; the pre-fix run is preserved beside it.
Constitution HEAD at run time `3be10826f3d2` — a different pin from the
`f5876a3b700e` §9.2 ran against, so **the two splits are not a controlled
comparison of this fix alone**; the three-row diff above is, because it is a
per-gate join of the two runs.

**Still 96 FAIL, and that is the point.** Nothing was made green by pointing a
gate somewhere convenient. The 81 propagation gates still FAIL at the correct
root — they now say so in 76 readable lines each instead of in silence, and what
holds them red is the same five third-party carriers §9.4 names.

**Proved, not asserted.** `--prove-failure` grew four cases, M16–M19, and its
summary count is now DERIVED from the cases that ran (it said "16 mutations"
while 18 were running — the §11.4.6 defect this sweep exists to catch elsewhere).
It reports **22 mutations, 25/25 green, exit 0**. Each new case reads the gate in
BOTH directions — the control shows the right root arriving, the mutation changes
what the specimen gate DECLARES and requires the resolved root to follow, so a
resolver with any of these answers written down would pass the control and fail
the mutation. Four regressed copies of the sweep were built and run to confirm
the battery is not inoperative:

| Regression applied to a scratch copy | Caught by | Exit |
|---|---|---|
| re-gate the header lookup behind the gate's own `--root)` arm (the original C1a) | **M16** | 1 |
| delete the `dir` arm from the `root_kind` case (the original C1b) | **M17** | 1 |
| ungate without the parser-evidence test (test B) | **M18** | 1 |
| remove `export CONSUMER_ROOT` | **M19** | 1 |

M17 earned its keep during development rather than after it: the first
implementation read only the FIRST header line mentioning `--root <dir>`, which
is the bare synopsis, and M17 failed on the spot.

**Honest boundary (§11.4.6).** The `<dir>` → constitution-root branch is correct
and is proved by M17 on a specimen, but it changes no real gate at this pin:
`cm_first_refusal_observed.sh` is the only gate that would take it, and it
declares `--selftest`, which `resolve_argv` prefers and returns on first. The
branch is a guard against the next gate of that shape, not a change to this run.

**FOUND WHILE FIXING, NOT FIXED — the sweep WRITES into the submodule it
consumes.** `covenant_propagation_wrappers_generate.sh` is discovered as a gate
and invoked bare, and bare is its WRITE mode (`--check` is the read-only one its
own header documents). Its row in the run above reads
`covenant_propagation_wrappers_generate.sh: wrote 162 wrapper file(s)` and it is
scored **PASS**. No damage today — the generated bytes are identical to what is
already there, and `git -C submodules/constitution status --short` is unchanged
after the run — but a read-only verification sweep is mutating a consumed
submodule on every invocation, and only idempotence is standing between that and
a real edit. This belongs with **C8** (non-gate files invoked as gates) and is
left for that item rather than folded into C1.

---

#### C2 — `README.md` has no badge row

- **Gate:** `cm_readme_badge_row_at_top.sh` (§11.4.259), argv `--root <repo>` —
  correctly resolved, so this is a real finding.
- **Output:** `FAIL — no badge row found at the top of …/README.md (first
  non-blank line after the H1 must be a pure badge row)`.
- **File:** `README.md`. Measured: the first non-blank line after `# vasic` is a
  blockquote (`> **No server-side CI at this umbrella root…**`).
- **Fix:** author a machine-derived badge row per §11.4.259 (each badge derived
  from a real source, never hand-typed colours), or record the gap as a tracked
  §11.4.197 item. Note the existing blockquote is load-bearing content and should
  move below the badge row, not be deleted.

---

#### C3 — `scripts/audit/zero_findings_sweep.sh` does not exist

- **Gate:** `cm_zero_findings_audit_sweep.sh` (§11.4.261), argv `--root <repo>`.
- **Output:** `FAIL … reason=SWEEP_SCRIPT_MISSING (§11.4.261 mandates a
  mechanical audit sweep — none declared/found)`.
- **File:** `scripts/audit/zero_findings_sweep.sh` — **verified absent** at the
  repository root.
- **Fix:** write the sweep (closed 10-class finding vocabulary, machine-readable
  ledger), or record the gap. If written it must also be registered in
  `scripts/check-registry.tsv` or R5 will fail the registry check.

---

#### C4 — `docs/findings/zero_findings_ratchet.tsv` does not exist

- **Gate:** `cm_zero_findings_monotone_ratchet.sh` (§11.4.261(C)), argv
  `--root <repo>`.
- **Output:** `FAIL … reason=RATCHET_SNAPSHOT_MISSING (§11.4.261(C) mandates a
  checked-in brownfield ceiling -- none found)`.
- **File:** `docs/findings/zero_findings_ratchet.tsv` — **verified absent**.
- **Fix:** snapshot the brownfield ceiling. **This is an operator decision, not
  an agent one** — §11.4.224(E) / §11.4.66 require the adoption question
  (immediate hard floor vs one-time ratchet vs phase-in) to be put to the
  operator before first enforcement. Depends on C3 existing first.

---

#### C5 — 7,577 test functions carry no oracle-strategy annotation

- **Gate:** `cm_oracle_strategy_named_and_independent.sh` (§11.4.245).
- **Output at the CORRECT root** (the run's own figure is invalid per C1):
  ```
  ❌ CM-ORACLE-STRATEGY-NAMED-AND-INDEPENDENT: FAIL — 7577 test function(s)
     with no valid closed-set oracle-strategy annotation (§11.4.245)
  ```
- **Files:** distributed across the owned fleet's test corpora.
- **Fix, in order:** (i) fix C1 so the number is measured against this tree on
  every run; (ii) decide the corpus scope — the gate currently walks every owned
  submodule, and §11.4.35 lets a consumer bind a scoped corpus as DATA; (iii)
  annotate each test with its closed-set oracle strategy, or adopt a
  §11.4.135-style monotone-decreasing ratchet. **7,577 is not a one-session fix
  and should not be presented as one.**

---

#### C6 — four consumer-side artifacts the §11.4.268-family gates require were never created

Mixed **(b + c)**, counted in (c). The upstream half: these gates derive the
consumer root as `<constitution>/..`, which under this repository's
`submodules/constitution/` layout resolves to **`<repo>/submodules/`** instead of
`<repo>/` — so their error messages name a path that could never exist. Measured:
neither `--root` nor `CONSUMER_ROOT` overrides it. **The ours half, and the
reason these rows sit in (c): the artifacts are absent at the correct path
too**, so fixing the upstream walk alone would flip nothing.

| Gate | Missing artifact (checked at BOTH `<repo>/` and `<repo>/submodules/` — absent at both) | Verdict detail |
|---|---|---|
| `cm_dependency_register_verdicts.sh` | `docs/requests/dependency_register.jsonl` (§11.4.270) | `DRV-A0-SEAM-PRESENT FAIL — the E6 register is absent or unreadable` |
| `cm_mechanism_observed_refusing.sh` | `docs/requests/verification_mechanisms.jsonl` | `MOR-A0-REGISTRY-PRESENT FAIL` + `MOR-A4-REAL-REGISTRY-RESOLVES FAIL`; A1/A2/A3 all PASS |
| `cm_control_needle_required.sh` | `scripts/lib/critical_blocker_gate.sh` (the §11.4.236 acceptance seam) | `CNR-A5-WIRED-AT-SEAM BLIND — the wiring question is UNDECIDED, and undecided is never reported as wired`; A0–A4 all PASS (5 PASS / 0 FAIL / 1 BLIND) |
| `cm_instrument_trap_scan.sh` | `scripts/testing/anti_slop/fixtures/traps` | `ITS-A0-SCANNER-SIGHTED BLIND — this scanner cannot be shown to see anything, so no corpus result below can be believed` |

**Fix:** create the four artifacts (or record each as a tracked §11.4.197 gap).
Note the honesty of these gates — three of the four report **BLIND**, not PASS,
when they cannot see. That is §11.4.201(7)(b) working correctly and should not be
"fixed" by making them quieter. `cm_control_needle_required.sh` is 5 PASS / 0
FAIL / 1 BLIND: it is one artifact away from green.

---

#### C7 — `cm_healthcheck_covers_served_ports.sh` has no consumer binding

- **Verdict:** ERROR rc=2 —
  `ERROR — both --compose and --manifest are required (this engine is
  project-agnostic: it never guesses a consumer's paths, §11.4.28/§11.4.35)`.
- **File:** `scripts/verify-all-constitution-rules.sh` — the §11.4.35
  consumer-registered block that already binds `OD_THEME_GLOBS` /
  `OD_TOKEN_GLOBS` / `OD_VISREG_GLOBS` / `OD_MANIFEST_GLOBS`.
- **Fix:** bind `--compose` / `--manifest` the same way the `OD_*` inputs are
  bound. **Honest boundary:** nothing in this repository has been built or run in
  a container yet (`submodules/containers` is present but unused), so the correct
  binding today may be an explicit §11.4.3 SKIP-with-reason rather than an
  invented compose file. rc=2 is COULD-NOT-DETERMINE and is **never a pass** —
  it must not be silenced into one.

---

#### C8 — the sweep discovers library files and batch runners as if they were gates

- **Rows:** `lib/wiring_sweep_precondition.sh` (ERROR rc=2) and
  `covenant_propagation_suite.sh` (ERROR rc=2).
- **File:** `scripts/verify-all-constitution-rules.sh`, the discovery line
  `find "$GATES_DIR" -type f -name '*.sh'`.
- **What they actually are:**
  - `lib/wiring_sweep_precondition.sh` is a **sourced helper**, not a gate. Bare
    invocation: `REFUSE: command_field_ABSENT — wiring_sweep_precondition needs
    <result-tsv> and <current-fingerprint>; got result="" fingerprint=""`. It is
    behaving correctly; we are calling it wrongly.
  - `covenant_propagation_suite.sh` is a **multi-subcommand batch runner**
    (`suite gates` / `suite mutations`) that prints its usage and exits 2 when
    invoked bare — exactly the shape `gate_ledger.sh` has, which the sweep
    already special-cases.
- **Fix:** extend the existing special-case pattern in `resolve_argv` — it
  already has `--selftest)` and `selfcheck)` branches. Add a `gates)`
  subcommand branch for the suite, and either give `lib/*.sh` helpers a
  `--selftest` invocation or exclude non-gate library files from discovery with
  a stated reason. **Do not simply prune `lib/` blindly** —
  `lib/pointer_carrier.sh --selftest` is a real 5-fixture golden test the sweep
  correctly runs and should keep running.

> **FIXED 2026-09-02, together with C8a below — see that item for the design,
> the signals chosen and rejected with counts, and the measured before/after.**
> The suite is EXCLUDED rather than given a `gates)` branch, and the reason is
> measurable rather than stylistic: **all 81** gate names in the suite's data
> pack `covenant_propagation_anchors.tsv` resolve to a
> `cm_covenant_114_<N>_propagation.sh` wrapper that is ALREADY ledgered and run
> individually (81 pack rows, 81 matched, 0 missing), so a `gates)` branch would
> run the whole family a second time and report 81 duplicate verdicts. (The
> suite's own header still says "29 script names"; that is stale upstream prose,
> not a count of this pin.) The `lib/` warning in the fix above was heeded exactly: 8 of the 15
> `lib/` files expose `--selftest` or `selfcheck` and every one of them is still
> discovered and still run, `lib/pointer_carrier.sh` among them.

---

#### C8a — the sweep invoked a GENERATOR whose bare mode WRITES into the consumed constitution submodule

- **Row:** `covenant_propagation_wrappers_generate.sh`, invoked with
  `argv: (gate defaults)` — and **bare is its WRITE mode**. Its sweep row read
  `wrote 162 wrapper file(s)` and was scored **PASS**.
- **File:** `scripts/verify-all-constitution-rules.sh`, the same discovery line
  as C8: `find "$GATES_DIR" -type f -name '*.sh'`.
- **Damage measured: none.** The generator is idempotent — a re-run over an
  unchanged data pack rewrites byte-identical files — and
  `git -C submodules/constitution status --porcelain` showed only the
  pre-existing nested `submodules/design-toolkit` dirt, never a wrapper.
  **That is the whole finding.** The only thing standing between a read-only
  audit and a mutated consumed submodule was IDEMPOTENCE: not a guard, not a
  read-only mode, not intent. This repository does not commit to the
  constitution submodule at all, so any write there is outside what it owns.
- **Fix (landed 2026-09-02):** a non-gate classifier above the discovery block
  in `scripts/verify-all-constitution-rules.sh`. It reads EVIDENCE out of each
  file — never a name list, because the gate population moved 57 → 286 on one
  fast-forward and a list written into the sweep is wrong at the next pin.
  - **RESCUE, evaluated first:** a file parsing `--selftest` or `selfcheck`
    exposes a self-verifying entry point and is never excluded. 18 of 286 files
    qualify; the rescue is what keeps `gate_ledger.sh` and 8 `lib/` files in.
  - **N1 FIXTURE** — a `fixtures/` path component. 6 matched, 6 excluded.
  - **N2 SOURCED** — the file's own Usage shows `. <file>` / `source <file>`.
    5 matched, 3 rescued, **2 excluded**.
  - **N3 HELPER** — a `lib/` component or `lib_` prefix, **and** a sibling
    names it as a path on a non-comment line, **and** no self-verifying entry
    point. 7 excluded.
  - **N4 SUBCOMMAND** — the Usage declares a mandatory bare positional.
    3 matched, 2 rescued, **1 excluded** (the C8 suite).
  - **N5 WRITES-BARE** — one header line binds `(no args)`/`(default)` to a
    write verb. **1 matched**, and it is the generator. It correctly spares
    `cm_instrument_trap_scan.sh`, whose `(no args)` line is a read-only mode.
- **Signals rejected, with the counts that killed them:** the executable bit
  (278/286 are +x; all three C8/C8a offenders are among them); a `lib/` path
  alone (15 files, 8 of them real self-verifying checks — excluding on the path
  would have been a coverage cut); a `GATE=` self-name assignment (58/286 carry
  none and many are unambiguous gates, and the generator DOES carry one inside
  the heredoc it emits, so it classifies the dangerous file as a gate);
  a `Side-effects` block mentioning writing (102/286, because every mutation
  test honestly documents its temp fixture); `chmod +x` in the body (~280/286);
  a missing `CM-` token (20/286, and it flags a real gate while missing both
  offenders, which name the token in prose).
- **Direction of error, chosen deliberately:** wrongly excluding a real gate
  silently reduces coverage — the blind-instrument failure this repository
  polices. Wrongly including a non-gate produces a visible bad row. So every
  rule demands positive evidence, a file matching nothing is KEPT, and the
  excluded set is printed with its reason by the run header and by `--list`.
- **Measured result:** discovery 286 → **270**, with **16 excluded** and every
  one named. The expected-gate ledger was re-baselined through the deliberate
  `--update-ledger` path (286 → 270 rows, 16 removals, 0 additions, pin
  `3be10826f3d2` unchanged). `--prove-failure` grew from 22 to **25**
  mutations, still exit 0: **M20** proves the generator is not executed (by a
  sentinel it writes when it runs, not by reading the sweep's own summary),
  that it is NAMED as excluded, that a real gate in the SAME run is still
  discovered AND executed, and that deleting the one declaration line re-admits
  it and the write happens; **M20b** proves the SUBCOMMAND class from the same
  file with only its usage line changed; **M20c** proves the excluded set is
  reported rather than dropped in silence.
- **The new split, measured twice.** `bash scripts/verify-all-constitution-rules.sh`
  now reports **173 PASS / 96 FAIL / 2 ERROR of 271** (270 discovered gates plus
  the project-side inheritance test), exit **1**, step 1 PASS, ledger clean. The
  post-C1 baseline it replaces was **187 PASS / 96 FAIL / 4 ERROR of 287**, and
  the delta reconciles exactly and only against the exclusions:
  287 − 271 = **16**, 187 − 173 = **14**, 4 − 2 = **2**, 14 + 2 = 16, and
  **FAIL is unchanged at 96**. So the 16 excluded rows were 14 PASSes (the
  generator's `wrote 162 wrapper file(s)` among them) and the 2 C8 ERRORs.
  **No FAIL was removed, and no failing gate was hidden by this change.** The
  figure was measured twice because the first run overlapped two comment-only
  edits to the sweep and an in-place edit of a running shell script is a real
  hazard; the second, clean run reproduced it byte for byte.
  `git -C submodules/constitution status --porcelain` shows only the
  pre-existing ` M submodules/design-toolkit` after both full sweeps — no
  wrapper file was written.
- **The 2 surviving ERRORs are left VISIBLE, not excluded:**
  `cm_healthcheck_covers_served_ports.sh` (C7 above, an unbound consumer input)
  and `lib/instrument_trap_scan.sh`, which is rescued by its own `--selftest`
  and exits 2. Both are rc-2 could-not-determine and neither is a pass. A `lib/`
  file that returns a real verdict keeps returning it.
- **Regression caught by the existing battery:** the new SUBCOMMAND rule
  excluded M18's own specimen, which had borrowed the suite's
  `g8_suite.sh gates [--root …]` header. M18 went red and the specimen was
  re-cut to isolate the withhold-until-a-parser-exists property, which is
  independent of the subcommand shape. **The proof caught the coverage cut in
  its own harness before any human did.**

---

### 9.7 What this run does and does not establish

**Establishes.** The sweep runs to completion; §11.4.32 step 1 is a measured
PASS; the project-side inheritance test passes; the propagation family's owned
carrier gap is closed (§9.4); and the tree's own §11.4.259 / §11.4.261 /
§11.4.245 / §11.4.268-family obligations are unmet in four concretely-named ways
(C2–C6).

**Does not establish.** **85 of the 101 non-PASS verdicts are about the wrong
directory** (C1). Until that is fixed, this split measures the sweep's argv
resolution as much as it measures this repository. A future run after the C1 fix
will produce a different — and for the first time meaningful — 95-equivalent
figure, and that run's number must be measured, never extrapolated from this one.

> **Superseded the same day — C1 is FIXED and the successor run is measured, not
> extrapolated.** The paragraph above stands as written about the §9.2 run and is
> kept unedited, because "this number is not yet about this tree" is exactly the
> statement a later reader needs in order to know why a second run exists. The
> successor figure is **187 PASS / 96 FAIL / 4 ERROR of 287**, exit 1, and the
> per-gate join of the two runs shows exactly **three** changed verdicts. See the
> FIXED block at the end of **C1** for the change, the before/after root-resolution
> counts, all four cleared harms and the four regression proofs. Both run files
> are preserved side by side; do not quote either split as a standing fact.

**Nothing was suppressed, allowlisted, downgraded or silenced to produce this
section.** No `2>/dev/null` was used anywhere in the run. No scan was narrowed.
No gate was skipped. The exit code is 1 and stays 1.
