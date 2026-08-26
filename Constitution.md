# vasic Constitution

## INHERITED FROM submodules/constitution/Constitution.md

This constitution **extends** the Helix Universal Constitution at
`submodules/constitution/Constitution.md`. All clauses there apply unless
explicitly overridden below.

> **Path note.** The constitution's own template and prose write the submodule
> path as `constitution/`. This repository places it at
> `submodules/constitution/` — the §11.4.28 dependency-layout form that
> `submodules/constitution/find_constitution.sh` resolves natively (its
> candidate list is `( "constitution" "submodules/constitution" )`, lines
> 41–46). Every `constitution/<file>` in a quoted universal clause means
> `submodules/constitution/<file>` here. This substitution is the only
> systematic edit made while instantiating
> `submodules/constitution/templates/Constitution.project.md.template`.

| Field | Value |
|---|---|
| Instantiated from | `submodules/constitution/templates/Constitution.project.md.template` |
| Created | 2026-08-26 |
| Governance submodule | `submodules/constitution` @ `448981ae3498229c734dc60719f4b19f01d7a75f` (`git describe` → `v1.0.0-51-g448981a`) |
| Peer carriers | `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` (bodies byte-identical from line 24; verify with `tail -n +24 <file> | sha256sum`) — §11.4.157 five-carrier lockstep |
| Verification | `tests/test_constitution_inheritance.sh`, `scripts/verify-all-constitution-rules.sh` |
| Dependency manifest | `helix-deps.yaml` (§11.4.31) |

> **§11.4.65 disclosure.** This document ships without its `.html` and `.pdf`
> siblings. That is a known, disclosed deviation of the same class
> `docs/constitution-adoption/INVENTORY.md` already records as gap G8 — not an
> oversight, and not a claim of compliance.

---

## Project Articles

### §101. The constitution submodule lives at `submodules/constitution/`, and nothing is copied out of it

Every governance artifact this repository relies on is inherited **by
reference**: the universal `Constitution.md`, the four canonical per-agent
mirrors, `find_constitution.sh`, `scripts/post_update_hook.sh`,
`scripts/hooks/guard-forbidden-commands.sh`, and everything under
`scripts/gates/`. No file in this repository restates the universal corpus.

The one bounded exception is the nine-item "Critical base rules restated"
block reproduced in the four root carriers. That block is authored by the
constitution itself, at
`submodules/constitution/templates/AGENTS.project.md.template`, for exactly
that purpose. Reproducing it is the prescribed mechanism (§11.4.35 invariant 6
declares the native-import and pointer-block forms equivalent), not a
duplication of the corpus.

Consequence for agents: a rule that is not in one of the five root carriers is
not absent — read it from `submodules/constitution/Constitution.md` before
acting. Do not assume, and do not re-author a §11.4.X anchor at this layer
(§11.4.35 invariant 7).

### §102. Owned-submodule propagation is staged in the umbrella and applied by the operator, submodule-first

§3 of the universal constitution requires the submodule commit and push to land
**before** the parent captures the pointer. This repository therefore never
writes a governance carrier directly into an owned submodule working tree from
the umbrella. Carriers are prepared as drafts under
`docs/constitution-adoption/propagation/<submodule>/` with a `.staged` suffix
(the suffix is required: the propagation gates discover carriers by exact
filename, so a draft named `CLAUDE.md` inside this repository would be counted
as a real carrier and fail the gate), and the operator applies them following
`docs/constitution-adoption/propagation/APPLY.md`.

Until that application happens, the propagation gaps are **open**, and this
document says so rather than implying coverage that does not exist. See
[Known open gaps](#known-open-gaps-1146-honest-boundary) below.

### §103. Third-party gitlinks are never edited from this repository

Two repositories reachable from this checkout are outside the owned set and
outside every operator-listed org:

- `submodules/superspec` → `git@github.com:WangX0111/superspec.git`
- `milosvasic.ru/Upstreamable` → `git@github.com:red-elf/Upstreamable.git`
  (a gitlink of the `milosvasic.ru` submodule, i.e. a fourth-level repository)

Neither receives a governance carrier, neither is tagged under §4, and neither
is edited to make a gate pass. Files inside them that a propagation gate
discovers and reports as MISSING are recorded as **known-excluded** in this
document, never "fixed" by writing into a repository this project does not own
(§11.4.156(C) applies the same reasoning to their CI config: a third-party
config is out of scope and MUST NOT be mass-edited).

---

## Overrides of Universal Constitution

(rare — every override MUST be justified explicitly here)

**None.** No clause of the Helix Universal Constitution is overridden,
weakened, or relaxed by this project. The four root carriers state the same
thing in their closing section.

Any future override MUST be recorded here in the template's form:

```markdown
### Override §X.Y — <reason>

<the override>
```

An unresolved contradiction between this repository's live state and a
universal clause is **not** an override. Such a contradiction is recorded in
[Open conflicts](#open-conflicts-with-the-universal-constitution) below, which
is where the active-CI conflict lives — precisely because nobody has decided to
override anything.

---

## Owned-submodule set

(per Universal §4 — list the submodules this project owns and tags)

```
ai_interviewing
design-toolkit
milosvasic.ru
monetization
vasic.digital
```

Third-party submodules excluded.

### The set in detail

| Path | Upstream (`.gitmodules`) | Pinned commit | `git describe` | Owned? |
|---|---|---|---|---|
| `ai_interviewing` | `git@github.com:milos85vasic/ai_interviewing.git` | `023abbfdfe12a604144cf420d1ec3d9efaa6e89c` | *(no tag reachable)* | **Yes** |
| `design-toolkit` | `git@github.com:vasic-digital/design-toolkit.git` | `16e4e76d57ab61b5f3b46fae3372b2e6d6cc73e3` | `v0.2.2-4-g16e4e76` | **Yes** |
| `milosvasic.ru` | `git@github.com:milos85vasic/milosvasic.ru.git` | `8385025500ce0595b1fad3ff3fb4c58e93b88504` | `v1.8.0-5-g8385025` | **Yes** |
| `monetization` | `git@github.com:milos85vasic/monetization.git` | `1f9f52042a81c9a2d0e0f2f42e3ca9fbf4d7fbfe` | *(no tag reachable)* | **Yes** |
| `vasic.digital` | `git@github.com:vasic-digital/vasic-digital.github.io.git` | `5a4c3bba8689e9d2c35887b77ee0a6c3da6248b6` | `v1.8.0-4-g5a4c3bb` | **Yes** |
| `submodules/constitution` | `git@github.com:HelixDevelopment/HelixConstitution.git` | `448981ae3498229c734dc60719f4b19f01d7a75f` | `v1.0.0-51-g448981a` | **Governance submodule** — see below |
| `submodules/superspec` | `git@github.com:WangX0111/superspec.git` | `c20ac6c1ba069cc9a72dacb8044b7b193d3dde81` | `v1.0.2` | **No — third-party, EXCLUDED** |

### `submodules/constitution` — the governance submodule itself

`submodules/constitution` is an own-org repository
(`HelixDevelopment/HelixConstitution`), but it is **not** a product submodule of
this project. It is the constitution this project consumes. It is listed above
for completeness and is declared in `helix-deps.yaml` as a dependency, and it is
deliberately **not** in the §4 tag-mirroring block: mirroring a `vasic` release
tag onto the universal constitution would tag a repository whose release cadence
belongs to a different project, and its own tag line (`v1.0.0…`) is unrelated to
this repository's (`v1.7.1`, `v1.7.2`, `v1.8.0`).

The universal §4 wording is *"every owned submodule"* and does not carve out a
governance submodule explicitly. **This carve-out is therefore a project
decision recorded here, not a universal rule.** It is stated openly so it can be
reversed by the operator rather than discovered later as an unexplained omission.

### `submodules/superspec` — excluded, with the reason

`submodules/superspec` is a gitlink to `git@github.com:WangX0111/superspec.git`.
The `WangX0111` account is outside every operator-listed org (`milos85vasic`,
`vasic-digital`, `HelixDevelopment`), so the repository is third-party under the
universal §4 sentence *"Third-party submodules (libraries not under the
project's control) are excluded."*

Concretely, the exclusion means:

1. **No §4 tag mirroring.** A `vasic` release tag is never pushed to it — this
    project has no push rights and no release authority over it.
2. **No §11.4.157 carrier propagation.** No `CLAUDE.md` / `AGENTS.md` /
    `QWEN.md` / `GEMINI.md` is written into it.
3. **No §11.4.156 CI action.** Its root `.github/workflows/ci.yml` is a
    third-party config this project neither authors nor pushes; §11.4.156(C)
    puts it explicitly out of scope and forbids mass-editing it.
4. **No §11.4.31 manifest entry.** `helix-deps.yaml` declares own-org deps; a
    third-party gitlink is recorded there as a comment, not as a `deps` entry.

Two carriers vendored inside it — `submodules/superspec/examples/static-landing-page/CLAUDE.md`
and its mirror at `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` —
are example fixtures of that third-party project. The propagation gates discover
them by filename and report them MISSING. They are known-excluded; see
[Known-excluded gate findings](#known-excluded-gate-findings).

---

## Project-specific remotes

| Repo | Remotes |
|---|---|
| Main (`vasic`) | `origin`, `github`, `upstream` — all three fetch **and** push `git@github.com:milos85vasic/vasic.git`. **One distinct URL.** |
| `ai_interviewing` | `origin`, `github`, `upstream` — all three fetch **and** push `git@github.com:milos85vasic/ai_interviewing.git`. **One distinct URL.** |
| `design-toolkit` | `origin` only — fetch **and** push `git@github.com:vasic-digital/design-toolkit.git`. **One distinct URL.** |
| `milosvasic.ru` | `origin` **fetch** `git@github.com:milos85vasic/milosvasic.ru.git`; `origin` **push ×2** → `git@gitflic.ru:milosvasic/milosvasic-net-v-2.git`, `git@github.com:milos85vasic/milosvasic.net.v2.git`. `gitflic` ↔ `git@gitflic.ru:milosvasic/milosvasic-net-v-2.git`. `github` ↔ `git@github.com:milos85vasic/milosvasic.net.v2.git`. `upstream` ↔ `git@gitflic.ru:milosvasic/milosvasic-net-v-2.git`. **⚠ fetch/push asymmetry — see below.** |
| `monetization` | `origin` **fetch** `git@github.com:milos85vasic/monetization.git`; `origin` **push ×4** → `git@gitflic.ru:milosvasic/monetization.git`, `git@github.com:milos85vasic/monetization.git`, `git@gitlab.com:milos85vasic/monetization.git`, `ssh://git@gitverse.ru:2222/milosvasic/monetization.git`. Named peers: `gitflic`, `github`, `gitlab`, `gitverse` (each fetch+push its own URL), `upstream` ↔ gitflic. |
| `vasic.digital` | `origin`, `github`, `upstream` — all three fetch **and** push `git@github.com:vasic-digital/vasic-digital.github.io.git`. **One distinct URL.** |
| `submodules/constitution` | `origin` **fetch** `git@github.com:HelixDevelopment/HelixConstitution.git`; `origin` **push ×6** → `git@gitflic.ru:helixdevelopment/helixconstitution.git`, `git@github.com:HelixDevelopment/HelixConstitution.git`, `git@gitlab.com:helixdevelopment1/helixconstitution.git`, `git@gitverse.ru:helixdevelopment/HelixConstitution.git`, `git@github.com:vasic-digital/HelixConstitution.git`, `git@gitlab.com:vasic-digital/HelixConstitution.git`. Named peers: `gitflic`, `github`, `gitlab`, `gitverse`, `vasic_digital_github`, `vasic_digital_gitlab`, `upstream` ↔ gitflic. |
| `submodules/superspec` *(third-party, not ours)* | `origin` only — fetch **and** push `git@github.com:WangX0111/superspec.git`. Recorded for completeness; this project pushes nothing here. |

Source: `git remote -v` run in each working tree on 2026-08-26. All URLs are
SSH; there is not one `https://` remote in the set.

### ⚠ Hazard — `milosvasic.ru` fetches from a URL it never pushes to

`milosvasic.ru`'s `origin` **fetches** from
`git@github.com:milos85vasic/milosvasic.ru.git` and **pushes** to two entirely
different URLs (`gitflic.ru:milosvasic/milosvasic-net-v-2` and
`github.com:milos85vasic/milosvasic.net.v2`). `milosvasic.ru.git` is not in
`origin`'s push list, and no other remote in that working tree pushes to it.

This is a real operational hazard, not a cosmetic naming quirk:

- Work pulled from `milosvasic.ru.git` and pushed back will **never** reach
  `milosvasic.ru.git`. The fetch source silently diverges from the three
  repositories that actually receive commits.
- The `.gitmodules` entry pins the submodule URL to
  `git@github.com:milos85vasic/milosvasic.ru.git`, so a fresh
  `git submodule update --init` clones the repository that receives **no**
  pushes. A fresh clone and a long-lived working tree can therefore be looking
  at different histories.
- §2.1 ("a commit that lives on only one remote is a future operational risk")
  is satisfied on the push side — two remotes receive every commit — but the
  fetch side points at a third repository that receives none.

Reconciling this is an **operator decision** (add `milosvasic.ru.git` to
`origin`'s push list, or repoint the fetch URL / `.gitmodules` entry at
`milosvasic.net.v2`). It is recorded here rather than silently normalised,
because either fix rewrites remote configuration this project must not change
on its own authority.

### §2.1 honest boundary — three repositories have exactly one remote URL

§2.1 is a **SHOULD** for consuming projects (*"Consuming projects SHOULD do the
same for their own multi-remote topology"*), so the single-URL topologies below
are not violations. They are recorded because §11.4.6 forbids implying a
multi-upstream posture that does not exist:

- Main `vasic` — three remote names, one URL. A GitHub outage makes the
  umbrella unreachable.
- `ai_interviewing` — three remote names, one URL.
- `vasic.digital` — three remote names, one URL.
- `design-toolkit` — one remote, one URL.

`monetization` (4 push URLs), `submodules/constitution` (6 push URLs), and
`milosvasic.ru` (2 push URLs) do have genuine fan-out.

---

## Open conflicts with the Universal Constitution

> **Not specified by `Constitution.project.md.template`.** The template offers
> `## Overrides` and nothing else. An override is a decision; the items below
> are undecided contradictions, and recording them as overrides would claim an
> authorization nobody has given. §11.4.6 forbids reporting a state that was
> not verified, and §11.4.156 names silence as the one option it does not
> allow — so this section exists. It is an addition to the template, marked as
> such.

### OC-1 — Active CI at the repository root contradicts §11.4.156(A)

**Clause.** §11.4.156(A) (`submodules/constitution/Constitution.md:9548`):

> **(A) Zero active CI at the repository root.** No active
> `.github/workflows/*.yml|*.yaml`, no `.gitlab-ci.yml`, no `.gitlab/**`
> pipeline include, nor any equivalent provider config may exist at the ROOT of
> any governed repository/submodule — the only location a provider executes.

and its closing formula:

> Non-compliance is a release blocker regardless of context. No escape hatch —
> no `--allow-ci`, `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`,
> `--ci-exempt` flag.

**Live state.** `.github/workflows/ci.yml` exists at this repository's root
(9,526 bytes) with live `on:` triggers, and `README.md:3` advertises it with a
status badge.

**Why this is a conflict of intent and not neglect.** The workflow's own header
records why it was added:

> Before this workflow existed, the ONLY GitHub Actions in play was
> milosvasic.ru/.github/workflows/pages.yml — a Jekyll *deploy*. Nothing ran the
> test suite, so a regression could only be caught by hand.

Two documented purposes collide: §11.4.156 moves enforcement to the local
§11.4.75 five-layer git-hook ritual; this repository has **none** of those five
layers (INVENTORY gap G5 — no non-sample hook in `.git/hooks/`, no commit
wrapper). Disabling the workflow today would remove the only mechanical check
that exists here and put nothing in its place.

**Status: UNRESOLVED — operator decision. Deliberately not acted on.**
The three available resolutions, none of which an agent may pick unilaterally:

1. Disable per §11.4.156(B) — rename to `ci.yml.disabled-local-only` — **and**
   stand up the §11.4.75 local layers first, so enforcement is moved rather
   than deleted.
2. Record an explicit `Override §11.4.156` in the Overrides section above, with
   the operator's justification.
3. Keep both and accept the release-blocker state knowingly.

Nothing in this repository disables, edits, or re-enables that workflow.

### OC-2 — `milosvasic.ru/.github/workflows/pages.yml` — the same clause, in an owned submodule

`milosvasic.ru` is an **owned** submodule and carries an active root workflow,
so §11.4.156(A) and (C) apply to it exactly as they apply to OC-1. It is listed
separately because resolving it means committing inside a submodule working
tree, which §102 above reserves to the operator.

`submodules/superspec/.github/workflows/ci.yml` is **not** listed as a conflict:
§11.4.156(C) scopes the clause to *"repositories we author + push"*, and
superspec is third-party.

### OC-3 — §11.4.32 step 1 has no cascade verifier to re-run

§11.4.32's sweep contract, step 1, requires the sweep to *"Re-run the existing
governance-cascade verifier (`scripts/verify-governance-cascade.sh`)"*.

`scripts/verify-governance-cascade.sh` does not exist in this repository.
`scripts/verify-all-constitution-rules.sh` therefore reports step 1 as an
explicit **SKIP with reason** naming the missing file, and never counts it as a
pass. Writing that verifier is remaining work, not a resolved item.

---

## Known-excluded gate findings

`scripts/verify-all-constitution-rules.sh` runs the constitution's own gates
against this checkout. Some findings are structural and are **not** this
repository's to fix. They are listed here so that a reader can tell an excluded
finding from a real regression — and note that the sweep still **exits
non-zero** on them. Exclusion means "not ours to fix", never "suppressed".

Observed on 2026-08-26 (`bash scripts/verify-all-constitution-rules.sh --quiet`,
constitution HEAD `448981ae3498229c734dc60719f4b19f01d7a75f`): **58 gates run —
37 PASS, 21 FAIL, 0 ERROR**, sweep exit `1`. The 21 failures are exactly the 17
`cm_covenant_114_*_propagation.sh` gates (each reporting the same five carriers
in section A below — 17 × 5 = 85 `MISSING` lines, and no sixth carrier anywhere)
plus the four constitution-internal gates in section B. Nothing else failed.

### A. Five carriers the propagation gates report MISSING

Every `cm_covenant_114_*_propagation.sh` gate discovers governance carriers by
filename under `--root` and reports these five:

| Carrier | Owning repository | Why excluded |
|---|---|---|
| `milosvasic.ru/Upstreamable/AGENTS.md` | `red-elf/Upstreamable` (third-party, a gitlink **of** the `milosvasic.ru` submodule) | §103 — this project does not own or push it |
| `milosvasic.ru/Upstreamable/CLAUDE.md` | `red-elf/Upstreamable` (same) | §103 |
| `submodules/superspec/examples/static-landing-page/CLAUDE.md` | `WangX0111/superspec` (third-party) | §103 — vendored example fixture |
| `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` | vendored copy of the same superspec fixture | §103 |
| `vasic.digital/QWEN.md` | `vasic-digital/vasic-digital.github.io` — **owned** | §102 — the fix is staged at `docs/constitution-adoption/propagation/vasic.digital/QWEN.insert-block.md` and awaits operator application; it is not applied from the umbrella |

Only the last is an owned-repository gap. The first four are third-party.

### B. Four gate failures inside the constitution submodule's own tree

These fail against `submodules/constitution` itself, are unrelated to this
repository's adoption, and cannot be fixed from here without writing into a
submodule working tree:

| Gate | Finding |
|---|---|
| `cm_continuum_resume_engine_present.sh` | project-specific literal inside the engine: `submodules/continuum/test/e2e/e2e_test.go` (decoupling violation, §11.4.28(B)) |
| `cm_gate_ledger_ratchet.sh` | ratchet violated — `unimplemented=432` exceeds checked-in `baseline=420` |
| `cm_track_branch_label.sh` | ALIAS-VALIDATION: labeler yielded `xhigh`, not the expected synthetic alias |
| `cm_track_branch_label_mutation_test.sh` | its paired §1.1 mutation test, failing because the gate above fails |

Per §11.4.26 these belong upstream in `HelixDevelopment/HelixConstitution`, as
does the missing `QWEN.project.md.template` / `GEMINI.project.md.template` pair
(INVENTORY gap G7b) that forces every consumer to hand-derive two of the five
carriers §11.4.157 makes equal.

---

## Known open gaps (§11.4.6 honest boundary)

This repository is **not** fully constitution-compliant. The full audit is
[`docs/constitution-adoption/INVENTORY.md`](docs/constitution-adoption/INVENTORY.md);
identifiers below are the inventory's own. Gaps closed since it was written are
marked.

| Gap | State |
|---|---|
| G1 — no consumer governance layer | **CLOSED** — `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` at the root |
| G2 — no inheritance pointer | **CLOSED** — all four carriers plus this file open with `## INHERITED FROM ` |
| G3 — no post-pull validation sweep | **PARTIAL** — `scripts/verify-all-constitution-rules.sh` exists; `scripts/verify-governance-cascade.sh` (step 1) does not — see OC-3 |
| G4 — active CI contradicts §11.4.156 | **OPEN** — OC-1 / OC-2, operator decision |
| G5 — no §11.4.75 mechanical enforcement layers | **OPEN** — no git hook, no commit wrapper at this root |
| G6 — no `helix-deps.yaml` | **CLOSED** — `helix-deps.yaml` at the root |
| G7 — no propagation to owned submodules | **OPEN** — staged under `docs/constitution-adoption/propagation/`, unapplied (§102) |
| G8 — §11.4.65 markdown export mandate | **OPEN** — no `.html` / `.pdf` siblings anywhere, this file included |
| G9 — §11.4.212 README-orphan | **OPEN** — `README.md` links to nothing but the CI badge |
| G10 — §4 tag mirroring incomplete | **OPEN** — `v1.8.0` is on `milosvasic.ru` and `vasic.digital` only |
| G11 — `design-toolkit` checked out twice | **OPEN** — declared in `helix-deps.yaml`; the shas match today |
| G12 — §11.4.109 anti-forgetting layer absent | **OPEN** — the canonical guard script is present in the submodule and wired nowhere |

Do not claim this repository passes a gate you have not actually run. Do not
treat the absence of a gate as a pass.

---
