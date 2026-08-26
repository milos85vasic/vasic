# Gate triage — the 21 sweep failures

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-08-27 |
| Status | active |
| Status summary | Triage of every FAIL reported by `scripts/verify-all-constitution-rules.sh`. Each of the 21 failures is categorised (a) fixable inside this umbrella repo, (b) requires writing into a submodule — an operator decision with push blast-radius, or (c) genuinely upstream / third-party. Result: **0 of 21 are category (a)**. No verdict was suppressed, allowlisted or downgraded. |
| Sweep under triage | `scripts/verify-all-constitution-rules.sh` (58 gates) |
| Constitution HEAD | `448981ae3498229c734dc60719f4b19f01d7a75f` |
| Scope | Triage + one comment-accuracy correction in the umbrella's own sweep script. No submodule working tree was written to. No mutating git command was run. |

> **§11.4.65 disclosure.** This document ships without its `.html` and `.pdf`
> siblings — the same known, disclosed deviation
> [`INVENTORY.md`](INVENTORY.md) records as gap **G8**. Stated rather than left
> to be discovered.

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
