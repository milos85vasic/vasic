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
| Last re-measured | 2026-09-01 |
| Governance submodule | `submodules/constitution` @ `902979027a907051dc036668a9c353bd27aedf47` (`git describe` → `helixconstitution-v68-51-g9029790`); corpus measures 11,700 lines / 1.7 MB / 252 `### §` anchors. The pin moved from `448981ae…` (`v1.0.0-51-g448981a`), which this row carried until 2026-09-01; whether that move was a fast-forward was not verified. **The pin is BEHIND its remote — see the warning under "The set in detail".** |
| Peer carriers | `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` (bodies byte-identical from line 24; verify with `tail -n +24 <file> \| sha256sum`) — §11.4.157 five-carrier lockstep. Measured 2026-09-01: 520 lines each, shared digest `a1f3a936e0ff6817ce05a9c3ba59b4a84aa57ba3d4b15308a6818befdcc5e2b4`. |
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

> **Status update 2026-09-01: the application HAS happened.** Propagation is no
> longer staged-and-unapplied. All **seven** owned submodules carry all four
> carriers — **28 of 28** — verified by `bash scripts/verify-governance-cascade.sh`
> (exit 0; C2 presence, C3 canonical-predicate acceptance, C8 in-submodule
> lockstep). G7 is **CLOSED**. The staging mechanism and the submodule-first
> ordering described above remain the governing procedure for any *future*
> carrier change; only the "gaps are open" sentence is superseded.

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
is where the active-CI conflict lived — precisely because nobody had decided to
override anything.

> **Update 2026-08-27 — an `Override §11.4.156` was sought and found
> structurally unavailable.** OC-1 and OC-2 below previously listed *"record an
> explicit `Override §11.4.156`"* as one of three resolutions. That resolution
> does not exist, for two independent reasons. **(1)** §11.4.156's closing
> formula does not merely set a high bar; it names and refuses the exemption
> vocabulary — *"No escape hatch — no `--allow-ci`, `--enable-workflow`,
> `--keep-pipeline`, `--remote-ci-OK`, `--ci-exempt` flag."* A project-local
> override is a `--ci-exempt` by another spelling. **(2)** The inheritance
> contract this repository's carriers state — *"Project-specific rules below
> extend them — they do NOT weaken or override any universal clause"* — makes a
> project-local override of an inherited clause structurally impossible, not
> merely disfavoured. Compliance was therefore the only path left that does not
> amend shared governance, and the operator chose it. **This section remains
> "None", and it is now known that it cannot become anything else for
> §11.4.156.** Full record:
> [`docs/constitution-adoption/DECISION-11-4-156-COMPLY.md`](docs/constitution-adoption/DECISION-11-4-156-COMPLY.md).
>
> **Addendum, same day (revision 2).** The compliance decision was then
> **partially reversed**: `milosvasic.ru/.github/workflows/pages.yml` is the sole
> publish path for a live production website, so it stays **ACTIVE**, and
> `vasic.digital` triggers provider-side Pages runs with no workflow file to
> disable. Both are recorded in [Open conflicts](#open-conflicts-with-the-universal-constitution)
> as **OC-2** and **OC-2b**. **Neither is an override, and neither may be written
> up as one.** An override claims a clause no longer applies; these admit the
> clause applies and is knowingly unmet, with the reason on the record. That is
> exactly the distinction the paragraph above this box already draws — *"an
> unresolved contradiction … is **not** an override"* — and it is why this
> section still reads "None" even though two surfaces are now knowingly
> non-compliant.

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

Pinned commits below were re-measured on **2026-09-01** with `git ls-tree HEAD`
and each was re-checked against `git ls-remote <url> HEAD`. **Eight of nine
match their remote tip; `submodules/constitution` does NOT** — see the warning
under the table. `bash scripts/verify-manifest-pins.sh` reports 8 MATCH /
0 DRIFT / 0 UNDETERMINED against `helix-deps.yaml`, but that measures the
manifest against the **local gitlink**, not against the remote; the two
questions are different and only one is gated. Two rows are new since this table
was first written (`workshop`, `submodules/containers`) and every pre-existing
row had moved — re-derive rather than trusting the table.

| Path | Upstream (`.gitmodules`) | Pinned commit | Owned? |
|---|---|---|---|
| `ai_interviewing` | `git@github.com:milos85vasic/ai_interviewing.git` | `5ef07e08f202f75f6c0a9d7eda193f6740a1a333` | **Yes** |
| `design-toolkit` | `git@github.com:vasic-digital/design-toolkit.git` | `efd2c3fb2f880aaf2baf7f4819ce28a1ce3609cb` | **Yes** |
| `milosvasic.ru` | `git@github.com:milos85vasic/milosvasic.ru.git` | `8166fdba295dedc3114188c56e84248717ee7167` | **Yes** |
| `monetization` | `git@github.com:milos85vasic/monetization.git` | `54ed7b0f5add52821d18866facb5ee8c75adef69` | **Yes** |
| `vasic.digital` | `git@github.com:vasic-digital/vasic-digital.github.io.git` | `0bc25012cc33202ced47788a9c301b6a9c15e192` | **Yes** |
| `workshop` | `git@github.com:milos85vasic/workshop_curriculum.git` | `55076bf943a5158c91dede839ac319c43ddca1ab` | **Yes** |
| `submodules/containers` | `git@github.com:vasic-digital/containers.git` | `4dab992582666a64a4353cd593704cdc969aaa1e` | **Yes** — added under §11.4.76 |
| `submodules/constitution` | `git@github.com:HelixDevelopment/HelixConstitution.git` | `902979027a907051dc036668a9c353bd27aedf47` | **Governance submodule** — see below |
| `submodules/superspec` | `git@github.com:WangX0111/superspec.git` | `c20ac6c1ba069cc9a72dacb8044b7b193d3dde81` | **No — third-party, EXCLUDED** |

> **The governance source is pinned BEHIND its upstream (measured 2026-09-01).**
> `submodules/constitution` is checked out at `902979027a90` while
> `git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD`
> returns `f16ea779b82a`. Every anchor quotation, line count and gate population
> recorded anywhere in this repository describes `902979027a90`, **not what
> upstream currently ships**. Whether `f16ea779b82a` is a fast-forward of the
> pin is **UNVERIFIED** — answering it needs a `git fetch` inside the submodule,
> a mutating command that was not run without authorization. **No cascade check
> catches this:** C9 and `scripts/verify-manifest-pins.sh` compare the manifest
> to the **local gitlink**, so a pin stale against its remote passes both.

`submodules/containers` (`vasic-digital/containers`) is mandated by **§11.4.76**
for ANY containerised workload, which also forbids reimplementing it — a
hand-rolled `Containerfile` would be a violation, not merely an inferior choice.
Its four carriers were a §11.4.157(B) lockstep break upstream and were repaired
**at source** and pushed as `4dab992` ("govern(carriers): restore §11.4.157(B)
four-carrier lockstep"); they now measure 703 lines each and cascade check C8
accepts them. **Honest boundary (§11.4.6): nothing in this repository has yet
been built or run in a container.** The submodule is present for the workload
`specs/001-workshop-curriculum-platform/` plans but has not implemented.

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

> **RESOLVED 2026-08-27 by operator decision — the text below is retained as the
> original record and is no longer the current state.**
> Decision, verbatim: *"Comply — disable both, enforce locally."*
> `.github/workflows/ci.yml` is renamed to a non-active `.disabled` name per
> §11.4.156(B), and the gates it ran move to a **local pre-push hook**.
> **⚠ Scope note (added 2026-08-27, revision 2): the *"disable both"* half of
> that decision now applies only to `ci.yml`.** The `pages.yml` half was
> reversed the same day on an overriding operator directive — see **OC-2** below.
> OC-1 itself is unaffected: `ci.yml` publishes nothing, so disabling it costs no
> production uptime, and it remains disabled.
> **Resolution 2 below — record an `Override §11.4.156` — turned out not to
> exist.** §11.4.156's closing formula refuses the exemption vocabulary by name
> (*"No escape hatch … `--ci-exempt`"*), and the inheritance contract this
> repository's carriers state (*"extend them — they do NOT weaken or override
> any universal clause"*) makes a project-local override of an inherited clause
> structurally impossible. With the override gone, compliance was the only
> remaining option that does not amend shared governance; no constitution
> amendment was made. Resolution 1's precondition ("stand up the §11.4.75 layers
> first") is honoured by C3 of the decision record, and resolution 3 was
> rejected because §11.4.156 makes non-compliance *"a release blocker regardless
> of context"*.
> **Honest boundary (§11.4.6):** renaming the file stops FILE-triggered runs. It
> does **not** reach provider-side settings — org-default required workflows,
> branch-protection required checks, the GitHub Pages source setting,
> provider-side scheduled exports. Those are operator-only manual steps in the
> provider UI and are **not done**. G4 therefore moves to **PARTIAL**, not
> CLOSED.
> **What is lost:** no server-side enforcement on push or PR. The gates now
> depend on a local hook, and `.git/hooks/` is not tracked by git, so a fresh
> clone has **no** protection until the install step is run.
> Full record, including the four options and the complete loss analysis:
> [`docs/constitution-adoption/DECISION-11-4-156-COMPLY.md`](docs/constitution-adoption/DECISION-11-4-156-COMPLY.md).
> CI surface inventory: `docs/constitution-adoption/CI-INVENTORY-11-4-156.md`.

**Clause.** §11.4.156(A) (`submodules/constitution/Constitution.md:9548`):

> **(A) Zero active CI at the repository root.** No active
> `.github/workflows/*.yml|*.yaml`, no `.gitlab-ci.yml`, no `.gitlab/**`
> pipeline include, nor any equivalent provider config may exist at the ROOT of
> any governed repository/submodule — the only location a provider executes.

and its closing formula:

> Non-compliance is a release blocker regardless of context. No escape hatch —
> no `--allow-ci`, `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`,
> `--ci-exempt` flag.

**Live state at the time this conflict was recorded.** `.github/workflows/ci.yml`
exists at this repository's root (~~9,526 bytes~~ — stale; measured **12,421 B**
on 2026-08-27) with live `on: push [main]` / `on: pull_request [main]` triggers,
and `README.md:3` advertises it with a status badge. *(Both the file and the
badge are removed by the 2026-08-27 decision.)*

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

**Status: ~~UNRESOLVED — operator decision. Deliberately not acted on.~~
SUPERSEDED 2026-08-27 — resolution 1 chosen; see the banner above.**
The three resolutions as originally recorded, none of which an agent could pick
unilaterally (resolution 2 has since been shown not to exist at all):

1. Disable per §11.4.156(B) — rename to `ci.yml.disabled-local-only` — **and**
   stand up the §11.4.75 local layers first, so enforcement is moved rather
   than deleted.
2. Record an explicit `Override §11.4.156` in the Overrides section above, with
   the operator's justification.
3. Keep both and accept the release-blocker state knowingly.

~~Nothing in this repository disables, edits, or re-enables that workflow.~~
**Superseded 2026-08-27:** resolution 1 was chosen and the workflow is being
renamed to a non-active `.disabled` name under the decision record.

### OC-2 — `milosvasic.ru/.github/workflows/pages.yml` — the same clause, in an owned submodule

> **STATUS: OPEN — PERMANENT DOCUMENTED DEVIATION (2026-08-27). NOT an override.**
>
> ~~**RESOLVED 2026-08-27 by the same operator decision — *"Comply — disable
> both, enforce locally."*** `pages.yml` is renamed to a non-active `.disabled`
> name per §11.4.156(B).~~ **That half of the decision was reversed the same
> day.** A material fact emerged after it was recorded:
>
> ```
> $ gh api repos/milos85vasic/milosvasic.ru/pages
> ... "build_type":"workflow", "status":"built", "html_url":"https://milosvasic.ru/" ...
> ```
>
> `build_type: "workflow"` means GitHub Pages publishes that **live production
> site** exclusively by running `pages.yml`. There is no `gh-pages` branch, no
> `docs/` folder, and the repository root is Jekyll SOURCE (Liquid + front
> matter), so it cannot be served raw from a branch. `_tools/deploy-langs.sh` is
> **not** a substitute — it generates, commits and pushes source and then
> `sleep`s waiting for the server to rebuild; it covers none of the publish step.
> Disabling `pages.yml` does not downgrade the deploy to manual: it **ends** it.
>
> **Operator's overriding directive, verbatim:** ***"Make sure all pages websites
> work flawlessly! No website can be broken! All websites we have here are
> running deployed in production!"***
>
> **Current state (verified 2026-08-27): `pages.yml` is ACTIVE**, byte-identical
> to the version publishing today (submodule `git status` clean, `git diff HEAD`
> empty, YAML parses, `build` and `deploy` jobs both intact). **It will not be
> disabled.**
>
> **This is a DEVIATION, not an `Override §11.4.156`.** §11.4.156 forbids an
> override by name (*"No escape hatch"*), and the Overrides section above
> explains why a project-local one is structurally impossible. An override would
> claim the clause no longer applies; it does apply, this repository is knowingly
> breaking it, and §11.4.156's characterisation of that as *"a release blocker
> regardless of context"* is accepted here rather than argued away. **Never
> record, report, or rationalise this as an override.**
>
> The recommendation in
> [`docs/constitution-adoption/REMOTE-ASYMMETRY.md`](docs/constitution-adoption/REMOTE-ASYMMETRY.md)
> §9 — to extend an `Override §11.4.156` to cover this file — remains **void**:
> there is no override to extend, and this deviation is not one either.
> Full record:
> [`docs/constitution-adoption/DECISION-11-4-156-COMPLY.md`](docs/constitution-adoption/DECISION-11-4-156-COMPLY.md) §0.

### OC-2b — `vasic.digital` triggers CI with no workflow file at all

> **STATUS: OPEN — PROVIDER-LEVEL NON-COMPLIANCE WITH NO FILE-LEVEL REMEDY
> (verified 2026-08-27).**
>
> `vasic.digital` (`vasic-digital/vasic-digital.github.io`) contains **zero**
> workflow files — it has no `.github/` directory. It is nonetheless
> §11.4.156-non-compliant, because its GitHub Pages source setting alone starts
> an Actions run on every push:
>
> ```
> $ gh api repos/vasic-digital/vasic-digital.github.io/pages
> ... "build_type":"legacy", "status":"built", "html_url":"https://vasic.digital/" ...
> $ gh api "repos/vasic-digital/vasic-digital.github.io/actions/runs?per_page=3"
> pages build and deployment | dynamic/pages/pages-build-deployment | dynamic | 2026-08-27T00:14:51Z
> pages build and deployment | dynamic/pages/pages-build-deployment | dynamic | 2026-08-10T13:46:15Z
> ```
>
> §11.4.156(A) is about files at a repository root; there is no file here to
> disable, so **no change to that repository's tree can make it compliant**.
> Only the operator, in the GitHub Pages UI, could stop those runs, and doing so
> would unpublish a live production site — which the directive quoted in OC-2
> forbids. Recorded, not resolved; and, like OC-2, **not an override**.

`milosvasic.ru` is an **owned** submodule and carries an active root workflow,
so §11.4.156(A) and (C) apply to it exactly as they apply to OC-1. It is listed
separately because resolving it means committing inside a submodule working
tree, which §102 above reserves to the operator.

`submodules/superspec/.github/workflows/ci.yml` is **not** listed as a conflict:
§11.4.156(C) scopes the clause to *"repositories we author + push"*, and
superspec is third-party.

### OC-3 — §11.4.32 step 1 had no cascade verifier to re-run — **RESOLVED 2026-08-27**

§11.4.32's sweep contract, step 1, requires the sweep to *"Re-run the existing
governance-cascade verifier (`scripts/verify-governance-cascade.sh`)"*.

**Original conflict (retained for history):** that file did not exist, so
`scripts/verify-all-constitution-rules.sh` reported step 1 as an explicit
**SKIP with reason** naming the missing file, never counting it as a pass.

**Resolution.** `scripts/verify-governance-cascade.sh` now exists, is tracked
and executable, and was committed in `9ed96fb`. Measured: **10 PASS, 0 FAIL,
0 ENV, 3 NOTE, exit 0**. It is not a vacuous gate — `--prove-failure` runs a
paired mutation proof against throwaway copies: a golden-good control passes,
five seeded violations are each caught as rc=1, and a deliberately broken
environment returns rc=2 rather than accusing the tree.

Two honest boundaries are recorded rather than papered over. First, §11.4.32's
phrase *"every §11.9 + CONST-\* anchor"* is not implementable against the
pinned corpus: `§11.9` occurs exactly once — inside §11.4.32's own sentence —
and no `CONST-NNN` defining heading exists anywhere; the sixteen `CONST-*` ids
appear only as cross-references. The verifier therefore proves the §11.4.35
*pointer* mechanism those anchors cascade through, rather than enumerating an
anchor list that does not exist. Second, §11.4.32 clause 4's Issues-tracker
population (§11.4.15 `Status: Reopened` / `Type: Bug`) is not implemented; the
verifier prints directed FAIL lines with fixes, but writes to no tracker.

The step-1 **caller** was fixed in the same pass: it had mapped any non-zero rc
to `STEP1 FAIL`, collapsing this verifier's documented three-valued contract
(0 pass / 1 violation / 2 could-not-verify) and so reporting a broken *check*
as a violation of the *tree*. It now branches on rc, with a distinct ERROR
state that exits non-zero without accusing the tree — consistent with the
sweep's existing `err` counter convention for blind instruments.

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

**Authority note (added 2026-09-01).** This table is **not** the authoritative
gap ledger and is not machine-compared to anything. The authority is the
`- G<n> — <STATUS>` lines in the four root carriers, which
`scripts/continuation-check.sh` C4 holds in agreement with `CONTINUATION.md` §4
on every run. If this table disagrees with those, **this table is the defect**.
Rows below were reconciled against the carriers on 2026-09-01.

| Gap | State |
|---|---|
| G1 — no consumer governance layer | **CLOSED** — `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` at the root |
| G2 — no inheritance pointer | **CLOSED** — all four carriers plus this file open with `## INHERITED FROM ` |
| G3 — no post-pull validation sweep | **CLOSED** — `scripts/verify-all-constitution-rules.sh` and `scripts/verify-governance-cascade.sh` both exist and run; step 1 re-measured 2026-09-01 as **12 PASS / 0 FAIL / 0 ENV / 7 NOTE, exit 0**, mutation-proven — OC-3 resolved. Grew from 10 to 12 checks with **C8** (four carriers INSIDE each owned submodule agree, per-agent header normalised) and **C9** (every `helix-deps.yaml` `deps[].ref` equals its live gitlink; standalone as `scripts/verify-manifest-pins.sh`). This closes the sweep **contract**; for the sweep's own verdict see the note under this table. |
| G4 — active CI contradicts §11.4.156 | ~~**OPEN** — OC-1 / OC-2, operator decision~~ → **PARTIAL** (2026-08-27, revised same day). Decided *"Comply — disable both, enforce locally."*, then **partially reversed**. **OC-1: `.github/workflows/ci.yml` → `ci.yml.disabled`, gates moved to a local pre-push hook — umbrella root compliant at file level.** **OC-2: `milosvasic.ru/.github/workflows/pages.yml` stays ACTIVE** — it is the sole publish path (`build_type: "workflow"`) for a live production site; operator directive: *"Make sure all pages websites work flawlessly! No website can be broken! All websites we have here are running deployed in production!"* Permanent **documented deviation, NOT an override**. **OC-2b: `vasic.digital`** triggers `pages build and deployment` on every push from its Pages source setting alone (`build_type: "legacy"`, zero workflow files) — **non-compliant at the provider level with no file-level remedy**. **Not CLOSED and will not close**: §11.4.156(B)'s real test is *"a push triggers ZERO runs"*, and the remaining provider-side settings (org-default required workflows, branch-protection required checks, scheduled exports) are operator-only and unverified. [Decision record](docs/constitution-adoption/DECISION-11-4-156-COMPLY.md) |
| G5 — no §11.4.75 mechanical enforcement layers | **PARTIALLY CLOSED** (row corrected 2026-09-01; the previous "OPEN — no git hook, no commit wrapper at this root" was wrong on the wrapper half and is withdrawn). A commit **wrapper** exists: `commit` on PATH → `$SUBMODULES_HOME/Upstreamable/commit` → `Software-Toolkit/Utils/Git/commit.sh` + `push_all.sh`, driven by the tracked `upstreams/GitHub.sh`. It runs `git add .`, so keep `.gitignore` accurate before using it. What is still missing is git **hooks as a tracked, travelling artefact**: `.git/hooks/pre-push` is installed and executable in the current working tree, but `.git/hooks/` is not tracked, so a fresh clone runs nothing until `bash scripts/pre-push-gates.sh --install`. |
| G6 — no `helix-deps.yaml` | **CLOSED** — `helix-deps.yaml` at the root |
| G7 — no propagation to owned submodules | **CLOSED** (measured 2026-09-01; **28 of 28**). No longer staged — applied. `bash scripts/verify-governance-cascade.sh` exits **0**: C1 classifies all 9 declared gitlinks from evidence (7 owned, 1 governance source, 1 third-party, no hardcoded roster); C2 finds all **7 × 4 = 28** owned-submodule carriers present and non-empty; C3 finds all 28 accepted by the canonical `is_pointer_carrier` predicate; C6 finds `helix-deps.yaml` and `.gitmodules` in agreement both ways; C8 finds every owned submodule internally in four-carrier lockstep. Superseded figures, withdrawn not restated: "20/20 CLOSED" (hardcoded five-submodule list, missed `workshop`), "PARTIAL 20/24", and a verbally circulated "24/24" (6 × 4, before `submodules/containers` joined the fleet). |
| G8 — §11.4.65 markdown export mandate | **OPEN** — no `.html` / `.pdf` siblings anywhere, this file included |
| G9 — §11.4.212 README-orphan | **OPEN** — `README.md` links to nothing but the CI badge |
| G10 — §4 tag mirroring incomplete | **OPEN** — `v1.8.0` is on `milosvasic.ru` and `vasic.digital` only |
| G11 — `design-toolkit` checked out twice | **OPEN** — declared in `helix-deps.yaml`; the shas match today |
| G12 — §11.4.109 anti-forgetting layer absent | **OPEN** — the canonical guard script is present in the submodule and wired nowhere |

**The sweep's own verdict is not this table (added 2026-09-01).** G3 above
closes the *contract* that a sweep exists, runs, and is mutation-proven. It says
nothing about how many gates the sweep passes.
`scripts/verify-all-constitution-rules.sh` discovers its gates dynamically and
that population moved **57 → 286** when the constitution pin was fast-forwarded,
so **every split published before the fast-forward is withdrawn and none is
comparable to a present-day run**. The most recent measurement on record is
**186 PASS / 95 FAIL / 6 ERROR of 287 gates**, recorded here as a *reported
prior measurement*: a re-run started 2026-09-01 had not completed when this text
was written, so no fresh split is claimed. Its failures are known to include two
classes no commit this repository can make will clear — (1) third-party and
staged carriers (`submodules/superspec/examples/…`,
`milosvasic.ru/Upstreamable/…`, the vendored spec-kit copy under
`.specify/extensions/`), which `verify-governance-cascade.sh` reports as
*known-unclearable* and excludes from its own verdict while the sweep's
propagation-gate family still counts them as FAILs — excluded means **not
double-counted, never suppressed**; and (2) defects internal to the constitution
submodule, which is upstream code this project consumes rather than owns.

**Provider-side CI remains unverified (§11.4.6).** File-level disabling stops
FILE-triggered runs. It cannot reach org-default required workflows,
branch-protection required checks, the GitHub Pages source setting, or
provider-side scheduled exports. Those are **operator-only, in a provider UI**,
and their current state is not known to this document. `bash
scripts/verify-provider-ci.sh` measures on demand — **exit 2 means COULD NOT
DETERMINE and is never a pass.**

Do not claim this repository passes a gate you have not actually run. Do not
treat the absence of a gate as a pass.

---
