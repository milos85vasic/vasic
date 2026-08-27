# Decision — §11.4.156: comply at the umbrella root; `pages.yml` stays ACTIVE

| Field | Value |
|---|---|
| Revision | 2 |
| Created | 2026-08-27 |
| Last modified | 2026-08-27 (revision 2 — partial reversal, see §0) |
| Status | active — decision made and then **partially reversed the same day**; C1/C3 applied and measured, **C2 REVERSED** (`pages.yml` restored to ACTIVE and staying active), provider-side steps (§5) **not done** |
| Status summary | The operator decided the §11.4.156 conflict recorded as **OC-1** and **OC-2**. First decision: **comply — disable both, enforce locally.** A material fact then emerged (§0) and the operator issued an overriding directive prioritising production uptime. **Net result:** `.github/workflows/ci.yml` (umbrella root) is renamed to `ci.yml.disabled` and its gates are wired into a **local pre-push hook** — the umbrella root complies. `milosvasic.ru/.github/workflows/pages.yml` is **RESTORED TO ACTIVE and will not be disabled**, because it is the sole publish path for a live production website; that submodule is a **known, documented deviation**. **No amendment to the shared constitution is made, and no project-local `Override §11.4.156` is recorded** — the second was sought and found structurally unavailable, and the deviation in §0 is emphatically **not** one. |
| Supersedes | The plan previously recorded in `Constitution.md` OC-1 option 2, `docs/constitution-adoption/README.md` §7 OC-1 option 2, `docs/constitution-adoption/INVENTORY.md` G4, and `docs/constitution-adoption/REMOTE-ASYMMETRY.md` §9 — all of which describe recording an `Override §11.4.156` as an available resolution. It is not. |
| Cross-reference | [`CI-INVENTORY-11-4-156.md`](CI-INVENTORY-11-4-156.md) — the per-file CI surface inventory for this decision, produced separately. It did not exist when this record was first drafted; it is now present (40,232 B, 2026-08-27 21:34) and is the authority for the per-file surface list. This record does not restate its contents. |
| Continuation | Operator-only provider-side steps (§5) and the hook-install step (§6) remain open. The `milosvasic.ru` deviation (§0) is **not** scheduled for closure. |

---

## 0. Revision 2 — the partial reversal (read this before anything below)

Revision 1 of this record, and roughly a dozen documents reconciled with it,
stated that **both** workflows were disabled. **That is no longer true, and for
`milosvasic.ru` it will not become true again.** Revision 1's text is retained
below rather than deleted, so the decision history stays legible; every place it
is now falsified carries an inline correction.

### 0.1 The material fact that forced the reversal

`milosvasic.ru/.github/workflows/pages.yml` is not merely *a* publish path for
`https://milosvasic.ru/`. It is the **only** one. Measured 2026-08-27:

```
$ gh api repos/milos85vasic/milosvasic.ru/pages
{... "status":"built", "cname":"milosvasic.ru", "html_url":"https://milosvasic.ru/",
 "build_type":"workflow", "source":{"branch":"main","path":"/"}, ...}
```

`build_type: "workflow"` means GitHub Pages publishes that site **exclusively**
by running that workflow. Three facts close every alternative:

1. There is **no `gh-pages` branch** and **no `docs/` folder** to serve from.
2. The repository root is Jekyll **SOURCE** — Liquid templates and YAML front
   matter — so it cannot be served raw from a branch even if the source setting
   were switched. The built output (`_site/`) is git-ignored by design.
3. **`_tools/deploy-langs.sh` is NOT a substitute.** It regenerates content,
   commits, and pushes the source, and then `sleep`s waiting for the server to
   rebuild. It covers generation and push; it covers **none** of the publish
   step. Reading it as a replacement deploy path was the error that made
   revision 1 look survivable.

Renaming `pages.yml` to `pages.yml.disabled` therefore does not "remove an
automated deploy" that a human could perform by hand later. It **takes a live
production website offline at its next content change** — the site freezes at
whatever was last published and never updates again.

### 0.2 The operator's overriding directive, verbatim

> **"Make sure all pages websites work flawlessly! No website can be broken! All
> websites we have here are running deployed in production!"**

That directive overrides the `pages.yml` half of *"Comply — disable both,
enforce locally."* It does not touch the `ci.yml` half, which publishes nothing
and therefore costs no uptime.

### 0.3 The state that actually stands

| Surface | State | §11.4.156 posture |
|---|---|---|
| `.github/workflows/ci.yml` (umbrella root) | **DISABLED** — renamed `ci.yml.disabled`; gates relocated to tracked `scripts/pre-push-gates.sh` + an installed `.git/hooks/pre-push` shim. Stands. | **COMPLIANT at file level** (clause (A)+(B)); clause (B)'s *"a push triggers ZERO runs"* still unproven pending §5 |
| `milosvasic.ru/.github/workflows/pages.yml` | **ACTIVE.** Restored, byte-identical to the version publishing today. Verified 2026-08-27: `git status` clean, `git diff HEAD` empty, YAML parses, both `build` and `deploy` jobs intact, `on: push [main]` + `workflow_dispatch`. **It will NOT be disabled.** | **NOT COMPLIANT — known, documented deviation** |
| `vasic.digital` | **Zero workflow files in its tree.** Pages source is `build_type: "legacy"`, and every push triggers a provider-side `pages build and deployment` run (`dynamic/pages/pages-build-deployment`; runs observed 2026-08-27, 2026-08-10). | **NOT COMPLIANT at the PROVIDER level — no file-level remedy exists** |

### 0.4 This is a DEVIATION, not an Override — and the distinction is load-bearing

§11.4.156's closing formula forbids an exemption by name: *"No escape hatch — no
`--allow-ci`, `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`,
`--ci-exempt` flag."* §2 of this record shows at length why an
`Override §11.4.156` is structurally unavailable. **Nothing in revision 2
changes that.** The `milosvasic.ru` state is not an override, not an exemption,
and not a resolution:

- An **override** would claim the rule no longer applies. It still applies.
- A **deviation** admits the rule applies, is being knowingly broken, and says
  why. §11.4.156 makes that *"a release blocker regardless of context"* — that
  characterisation is accepted here, not argued away.

`milosvasic.ru` is therefore recorded as **permanently non-compliant with
§11.4.156(A) by explicit operator decision, prioritising production uptime over
the clause**. Anyone writing this up as an `Override §11.4.156` — in this file,
in the project `Constitution.md`, in a carrier, or in a report — is introducing
a governance error. Do not do it.

`vasic.digital` cannot be made compliant by any change to its tree at all: it
has no workflow file to disable, and the runs come from the Pages **source
setting**. Only the operator, in the GitHub UI, could change that, and doing so
would unpublish the site.

---

## 1. The conflict, stated precisely

§11.4.156 — *"All CI/CD automation (GitHub Actions / GitLab pipelines /
equivalents) MUST be disabled"* (User mandate, 2026-06-15) — clause (A):

> **(A) Zero active CI at the repository root.** No active
> `.github/workflows/*.yml|*.yaml`, no `.gitlab-ci.yml`, no `.gitlab/**`
> pipeline include, nor any equivalent provider config may exist at the ROOT of
> any governed repository/submodule — the only location a provider executes.

clause (B), which defines what "disabled" means:

> **(B) Disabled means a push triggers ZERO runs.** Delete the config OR rename
> it to a non-active name (the §11.4.75 `.disabled` / `.disabled-local-only`
> convention — a provider ignores any name that is not its exact trigger
> filename); a workflow left with live `on:` triggers but `if: false` jobs still
> queues runs and is NOT compliant.

clause (C), which scopes it:

> **(C) Scope = repositories we author + push.** […] the test is "does a push to
> one of OUR upstreams trigger a run?" — yes ⇒ disable, structurally-inert ⇒
> document + leave (§11.4.6 — verify inertness as FACT, never assume).

and its closing formula, which is the sentence that killed the previous plan:

> Non-compliance is a release blocker regardless of context. No escape hatch —
> no `--allow-ci`, `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`,
> `--ci-exempt` flag.

**The two files in conflict**, as measured in the working tree on 2026-08-27
before any rename landed:

| File | Size | Triggers | §11.4.156(C) test | Conflict ID |
|---|---|---|---|---|
| `.github/workflows/ci.yml` | 12,421 B | `on: push [main]`, `on: pull_request [main]` | authored and pushed by this project ⇒ **in scope** | **OC-1** |
| `milosvasic.ru/.github/workflows/pages.yml` | 1,333 B | `on: push [main]`, `workflow_dispatch` | owned submodule, authored and pushed ⇒ **in scope** | **OC-2** |

> **Revision 2 note.** OC-2 remains in scope and remains a conflict. What changed
> is the resolution, not the diagnosis: `pages.yml` is the sole publish path for
> a live production site (§0.1), so it stays **ACTIVE** and OC-2 stays **open as
> a documented deviation** (§0.4). OC-1 is unaffected and was resolved by
> compliance.

`submodules/superspec/.github/workflows/ci.yml` remains **out of scope** and is
not touched: §11.4.156(C) scopes the clause to *"repositories we author +
push"*, and `superspec` (`WangX0111/superspec`) is third-party. The same holds
for its vendored mirror under `.specify/extensions/superspec/.github/`, which is
not at a repository root and is therefore structurally inert.

---

## 2. Why an Override was not available

The previously recorded plan — visible in `Constitution.md` OC-1 option 2 and
mirrored in three other documents — was to *"record an explicit
`Override §11.4.156` in the project `Constitution.md`, with the operator's
justification."* That option does not exist. Two independent reasons, either of
which alone is sufficient:

**Reason 1 — the rule forbids one by name.** §11.4.156's closing formula does
not merely set a high bar for exemption; it enumerates and refuses the exemption
vocabulary: *"No escape hatch — no `--allow-ci`, `--enable-workflow`,
`--keep-pipeline`, `--remote-ci-OK`, `--ci-exempt` flag."* A project-local
`Override §11.4.156` is precisely a `--ci-exempt` by another spelling. Writing
one would not resolve the conflict; it would restate it in the document that is
supposed to resolve it.

**Reason 2 — the inheritance contract makes a project-local override
structurally impossible.** This repository inherits by the portable pointer
form, and every carrier states the contract in the same words. From this
repository's own `CLAUDE.md` / `AGENTS.md` / `QWEN.md` / `GEMINI.md`:

> Project-specific rules below extend them — they do NOT weaken or override any
> universal clause.
>
> When this file disagrees with the constitution submodule, the constitution
> wins.

and from the constitution's own consumer scaffold
`submodules/constitution/templates/AGENTS.project.md.template`:

> This file extends them with project-specific rules; it never weakens them.

A project carrier that recorded an `Override §11.4.156` would be weakening an
inherited universal clause, which is the one thing the inheritance contract says
a consumer carrier cannot do. The project `Constitution.md` had already reached
the same conclusion in general terms before this decision, in its `## Overrides`
section:

> An unresolved contradiction between this repository's live state and a
> universal clause is **not** an override.

So the override path was never a path. Recording one would have been a
governance error dressed as a resolution.

**Consequence.** Once the override is unavailable, compliance is the only
remaining option that does not amend shared governance. That is the whole of the
reasoning: not that compliance was preferred on its merits over an override, but
that there was nothing to prefer it over.

---

## 3. The four options and the choice

Options 1, 3 and 4 below are the three already on record in `Constitution.md`
OC-1; option 2 is the amendment path, which becomes the only alternative once
the project-local override is disqualified. The operator's decision is quoted
verbatim; the option framing is reconstructed from the recorded conflict plus
the two disqualifiers in §2 above, and is labelled as such rather than presented
as a transcript.

| # | Option | Outcome |
|---|---|---|
| 1 | **Comply.** Disable both workflows per §11.4.156(B) (rename to a `.disabled` name), and move the same gates to the local §11.4.75 layer so enforcement is *relocated* rather than deleted. | ✅ **CHOSEN — then partially reversed the same day (§0).** Applied to `ci.yml` and standing. Reversed for `pages.yml`. |
| 2 | **Amend the shared constitution.** Edit `submodules/constitution/Constitution.md` to create an exemption for this class of workflow. | ❌ Not taken. It would change governance for every consuming project, not just this one, and `submodules/constitution` fans out to **six push URLs**. The decision explicitly states no constitution amendment is being made. |
| 3 | **Record a project-local `Override §11.4.156`.** | ❌ **Structurally unavailable** — see §2. |
| 4 | **Keep both workflows and knowingly accept the release-blocker state.** | ❌ Not taken. §11.4.156 makes non-compliance *"a release blocker regardless of context"*, and names silence as the one posture it does not permit. |

**Operator decision, verbatim:** *"Comply — disable both, enforce locally."*

**Overriding operator directive, issued later the same day, verbatim:**

> **"Make sure all pages websites work flawlessly! No website can be broken! All
> websites we have here are running deployed in production!"**

The second directive does not reopen the option table. It removes `pages.yml`
from the scope of option 1 on a ground the table never weighed — that disabling
it takes a **production website** offline, because it is the site's only publish
path (§0.1). Option 1 stands for `ci.yml`. For `pages.yml` the outcome is a
**fifth** posture the original table did not contain: **knowing, documented
non-compliance**, which is option 4's *state* accepted deliberately and on the
record, without option 3's false claim of an override.

---

## 4. What is changed as a result

Three mechanical changes, all applied by other actors in the same work window.
Each row states what was **measured**, and when.

| # | Change | Clause satisfied | State |
|---|---|---|---|
| C1 | `.github/workflows/ci.yml` → `.github/workflows/ci.yml.disabled` | §11.4.156(A) + (B) | ✅ **APPLIED.** Measured 2026-08-27 21:36 — `.github/workflows/` contains exactly one entry, `ci.yml.disabled` (15,164 B); no `.yml`/`.yaml` remains. `git status` shows the rename staged as `RM`. *(Earlier in this same session the file was still `ci.yml`, 12,421 B, with live `on: push` / `on: pull_request` triggers — this row was rewritten from PENDING once the rename landed.)* |
| C2 | ~~`milosvasic.ru/.github/workflows/pages.yml` → `pages.yml.disabled`~~ | ~~§11.4.156(A) + (B), in an owned submodule~~ | ❌ **REVERSED — NOT APPLIED, and will not be.** The rename was briefly present in the submodule working tree (measured 2026-08-27 21:28) and was **never committed or pushed**, so the live site was never interrupted. It has been undone. Verified 2026-08-27 21:41: `milosvasic.ru/.github/workflows/` contains exactly one entry, **`pages.yml` (1,333 B, ACTIVE)**; `git status` in the submodule is clean and `git diff HEAD` is empty, i.e. the file is byte-identical to the version publishing today; the YAML parses and both the `build` and `deploy` jobs are intact. Reason: `build_type: "workflow"` makes this the **sole** publish path for a production website — see §0. |
| C3 | The gates the umbrella workflow ran are wired into a **local pre-push hook** | §11.4.75 Layer 5 / §11.4.156's *"Enforcement migrates to the LOCAL §11.4.75 five-layer git-hook ritual"* | ✅ **APPLIED on this machine.** Measured 2026-08-27 21:30 — `.git/hooks/pre-push` exists (1,224 B, executable). It is a thin shim that `exec`s the tracked `scripts/pre-push-gates.sh`, installed by `bash scripts/pre-push-gates.sh --install`. The runner reproduces the disabled workflow's gates in order and adds a **gate E** implementing §11.4.156(E)'s own pre-push self-check. ⚠ **The hook is per-clone local state — see §6.** |

**§11.4.156(E) self-check, executed 2026-08-27:**

```
$ git ls-files | grep -E '^\.github/workflows/.*\.ya?ml$'
(no output)
```

Empty output is the compliant result for clause (E) at the umbrella root.
Note what this proves and what it does not: it proves no *tracked, root-level,
actively-named* workflow file remains. It does not prove clause (B)'s actual
test — *"a push triggers ZERO runs"* — which depends on the provider-side
settings in §5.

The gate set relocated by C3 is the one the umbrella workflow ran, which
`README.md` documents as runnable from a fresh clone and which
`scripts/pre-push-gates.sh` now runs in the same order — Gate 0 (hardcoded path
audit), Gate 1 (Go unit tests), Gate 2 (hardcoding audit), Gate 3 (translate
reproducibility self-test), Gate 4 (portfolio §1.1 self-validation), Gate 5
(harness self-validation), Gate 6 (Playwright chromium) — **plus a gate E** that
the remote runner could not perform: §11.4.156(E)'s own pre-push check that no
root-level active CI file has reappeared.

One audit finding carries over and should be tracked against the runner rather
than the retired workflow: `CI-WORKFLOW-AUDIT.md` **S2** records that Gate 2's
`_tools/audit-hardcoding.sh` has a **vacuous-pass path** (`set -uo pipefail`
without `-e`, and a generator loop whose exit status is never checked). That
finding is now more load-bearing, not less, because the local hook is the only
thing running it.

**`pages.yml` is not a test workflow.** It is
a Jekyll *deploy* — it publishes `https://milosvasic.ru/`. Disabling it does not
relocate an enforcement check; it removes an automated deploy.
~~Publishing that site becomes a local/manual step (`_tools/deploy-langs.sh` is
the existing local deploy path).~~

> **Corrected in revision 2 — this was the decisive error.**
> `_tools/deploy-langs.sh` is **not** a local deploy path for the *published*
> site. It regenerates content, commits, and pushes **source**, then `sleep`s
> waiting for the server to rebuild. The rebuild it waits for **is** the
> workflow. With `build_type: "workflow"` and no `gh-pages` branch, no `docs/`
> folder, and a Jekyll-source repository root, there is **no** manual or local
> substitute at all — disabling `pages.yml` does not degrade the deploy to
> manual, it **ends** it. That is why C2 was reversed (§0).

That asymmetry between OC-1 and OC-2 was already recorded in
[`REMOTE-ASYMMETRY.md`](REMOTE-ASYMMETRY.md) §9 and survives this decision
unchanged — indeed revision 2 sharpens it into the reason the two conflicts now
end differently. Only the override recommendation in that section is superseded.

The per-file inventory of every CI surface considered under this decision —
including the ones ruled structurally inert — is
[`CI-INVENTORY-11-4-156.md`](CI-INVENTORY-11-4-156.md), produced separately and
not yet present when this record was written.

---

## 5. Honest boundary (§11.4.6) — what this decision does NOT reach

§11.4.156 states this boundary itself, and it is reproduced here because it is
the difference between "compliant" and "the file was renamed":

> Honest boundary (§11.4.6): file-level disabling stops FILE-triggered runs; it
> does NOT disable provider-side server settings the agent cannot reach
> (org-default required workflows, branch-protection required checks,
> provider-side scheduled exports) — those MUST be turned off in provider
> settings by the operator, and the agent documents what it cannot reach rather
> than claiming a completeness it did not achieve.

Applied to this repository, the following are **operator-only manual steps in a
provider web UI**. None of them is done. None of them can be done from this
working tree, and no rename in §4 touches any of them:

| # | Provider-side surface | Where it lives | State |
|---|---|---|---|
| P1 | **Org-default / required workflows** that GitHub can inject into a repository without a file in that repository's tree | GitHub org settings for `milos85vasic`, `vasic-digital`, `HelixDevelopment` | **NOT VERIFIED, NOT DISABLED.** Not reachable from the working tree. |
| P2 | **Branch-protection required status checks** on `main` — a required check whose workflow no longer exists blocks merges rather than passing them | GitHub repo settings → Branches | **NOT VERIFIED, NOT DISABLED.** If `CI` is configured as a required check, renaming `ci.yml` will make PRs unmergeable until the requirement is removed. |
| P3 | **The GitHub Pages "source" setting** for `milosvasic.ru` | GitHub repo settings → Pages | ✅ **NOW VERIFIED (2026-08-27), and deliberately NOT DISABLED.** `gh api repos/milos85vasic/milosvasic.ru/pages` → `build_type: "workflow"`, `source: {branch: main, path: /}`, `status: "built"`, `cname: milosvasic.ru`. This is the finding that reversed C2: the setting does **not** fall back to the built-in action — it delegates publishing entirely to `pages.yml`. Disabling the workflow would leave the site with no publisher. **Permanent documented deviation, not an override (§0.4).** |
| P3b | **The GitHub Pages "source" setting** for `vasic.digital` | GitHub repo settings → Pages | ✅ **VERIFIED (2026-08-27), NOT DISABLED and not disable-able from the tree.** `gh api repos/vasic-digital/vasic-digital.github.io/pages` → `build_type: "legacy"`, and the Actions run list shows `pages build and deployment` (`dynamic/pages/pages-build-deployment`, event `dynamic`) on 2026-08-27 and 2026-08-10. So `vasic.digital` triggers provider-side Actions runs on every push **with zero workflow files in its tree**. §11.4.156(A) is unsatisfiable there by any file-level change; only the operator, in the Pages UI, could stop it, and that would unpublish the site. **Documented provider-level non-compliance.** |
| P4 | **Provider-side scheduled exports / cron-like automation** not expressed as a workflow file | Provider settings, per host | **NOT VERIFIED, NOT DISABLED.** Note that `milosvasic.ru`, `monetization` and `submodules/constitution` push to GitFlic, GitLab and GitVerse as well as GitHub; each host has its own automation settings. |

**Therefore: this repository is not §11.4.156-compliant, and will not become
so.** Stated per surface, so no reader can round it up:

- **Umbrella root** — *file-level* compliant after C1+C3. Clause (B)'s actual
  test, *"a push triggers ZERO runs"*, remains unproven until **P1, P2 and P4**
  are checked in the provider UIs by the operator. **PARTIAL**, never CLOSED.
- **`milosvasic.ru`** — **NOT compliant, permanently, by decision.** P3 is
  verified and the answer is that the workflow must stay. Documented deviation
  (§0.4), not an override.
- **`vasic.digital`** — **NOT compliant at the provider level**, verified at
  P3b, with **no file-level remedy** available to any agent or to this tree.

Recording any of this as "§11.4.156 CLOSED" would be exactly the completeness
claim §11.4.6 forbids. G4 moves from **OPEN** to **PARTIAL** and stays there.

---

## 6. What is lost by this decision

Stated plainly, because it is the real cost and the operator should read it here
rather than discover it later:

**There is no longer any server-side enforcement on push or pull request.**

**The headline cost, stated once and up front so it is not buried in the list
below:** the umbrella's seven gates now depend on a hook living in
**`.git/hooks/`, which git does not track**. Two consequences follow directly,
and neither has a technical fix inside this repository:

> 1. **A fresh clone has NO enforcement whatsoever** until somebody runs
>    `bash scripts/pre-push-gates.sh --install` by hand. Not weaker enforcement
>    — none. Nothing in the repository can detect a clone where that step was
>    skipped, and nothing warns the person pushing.
> 2. **`git push --no-verify` bypasses the hook entirely**, silently, leaving no
>    record that anything was skipped.
>
> The enforcement guarantee this repository now has is therefore **"someone
> remembered, and chose not to skip"** — not "the system checks". That is a
> categorically weaker property than the workflow provided, and it is the price
> of §11.4.156 compliance at this root.

The itemised breakdown follows.

1. **The gates become opt-in.** They run only if the local pre-push hook is
   installed on the machine doing the push. Nothing on the server checks
   anything. A push from a machine without the hook is unchecked, and the
   provider will accept it silently.

2. **`.git/hooks/` is not tracked by git.** It is per-clone local state; it is
   not part of the repository's content and cannot be. **A fresh clone therefore
   has zero protection until this is run by hand:**

   ```bash
   bash scripts/pre-push-gates.sh --install
   ```

   The design mitigates this as far as it can — the *logic* lives in the tracked,
   reviewable `scripts/pre-push-gates.sh`, and only a thin shim is written into
   `.git/hooks/pre-push` — but the shim itself can never be tracked. This is not
   a defect in the hook; it is a property of git. It means the enforcement
   guarantee this repository now has is **"someone remembered"**, not "the system
   checks". Nothing in the repository can detect a clone where the install step
   was skipped.

3. **Pull requests lose their check entirely.** A pre-push hook fires on the
   push that *creates or updates* a branch; it does not run when a PR is opened,
   when a PR is merged through the GitHub UI, or on any push made from a
   different clone, from a web editor, or by a bot. The umbrella workflow ran on
   `pull_request`. Nothing replaces that.

4. **A pre-push hook is bypassable by design.** `git push --no-verify` skips it,
   with no record that it was skipped.

5. **The gap this workflow was created to fill returns.** The workflow's own
   header records why it was added: *"Before this workflow existed, the ONLY
   GitHub Actions in play was milosvasic.ru/.github/workflows/pages.yml — a
   Jekyll deploy. Nothing ran the test suite, so a regression could only be
   caught by hand."* Compliance with §11.4.156 restores that condition, mitigated
   only by the local hook and by the §11.4.40 pre-tag sweep.

6. ~~**`milosvasic.ru` loses its automated deploy** (see the note in §4). The
   site is published by whoever runs the local deploy path, when they run it.~~
   **Revision 2: this cost is NOT paid, because it turned out to be
   unaffordable.** There is no "local deploy path" for the published site to
   fall back to (§0.1). The real cost of disabling `pages.yml` was not a
   downgrade to manual publishing but the **permanent freezing of a live
   production website**, and that is why C2 was reversed. What is lost instead
   is compliance: `milosvasic.ru` stays knowingly outside §11.4.156(A), on the
   record, indefinitely.

7. **The repository can no longer claim §11.4.156 as a whole.** Two of three
   surfaces are non-compliant and are staying that way — one by decision
   (`milosvasic.ru`), one by provider mechanics with no file-level remedy
   (`vasic.digital`). Any future gate, report, or release checklist that asserts
   "§11.4.156 satisfied" for this repository is asserting something false. It
   may only assert it of the **umbrella root**, and only at file level.

The `ci.yml` half of the decision is still correct — the rule permits nothing
else there, and §11.4.156 makes that trade deliberately, moving enforcement from
a remote runner to a local ritual. But the trade is real, and the mitigation
(item 2) is the weakest link: **install the hook on every clone, or the
compliance is nominal.** The `pages.yml` half is no longer claimed at all: it
was attempted, found to cost a production outage, and withdrawn under the
operator's directive quoted in §0.2.

---

## 7. Documents reconciled with this decision

Every document below previously stated something this decision falsifies. Each
now carries the reversal alongside the original text; none was silently
rewritten.

> **Revision 2 addendum.** The same documents were reconciled a *second* time on
> 2026-08-27, because revision 1 propagated the claim that **both** workflows
> were disabled. Every one of them now states: `ci.yml` disabled with gates
> local; `pages.yml` **ACTIVE and staying active**; `milosvasic.ru` a
> **documented deviation, not an override**; `vasic.digital` non-compliant at
> the provider level with no file-level remedy. The stale "both disabled" text
> is struck through in place rather than deleted, so the decision history
> remains readable.

| Document | What was stale |
|---|---|
| `Constitution.md` (project) | OC-1 / OC-2 recorded as unresolved with an `Override §11.4.156` among the resolutions; `## Overrides` reasoning; G4 gap row |
| `docs/constitution-adoption/README.md` | §7 OC-1 / OC-2, and the G4 row in the gap table |
| `docs/constitution-adoption/INVENTORY.md` | G4 (*"or record an explicit `Override §11.4.156`"*) and the §11.4.156 compliance row |
| `docs/constitution-adoption/REMOTE-ASYMMETRY.md` | §9 — a recommendation to extend the `Override §11.4.156` to `pages.yml` |
| `docs/SESSION-REPORT.md` | §6.3 OC-1 / OC-2 rows, which list the override as decision option 2 |
| `docs/setup-agents-wizard/CI-WORKFLOW-AUDIT.md` | §6 — *"still marked OPEN — operator decision"* |
| `README.md` (root) | CI status badge; the `.github/workflows/ci.yml` path row; *"The commands below mirror `.github/workflows/ci.yml` exactly"*; *"versions match CI"* |
| `docs/setup-agents-wizard/RESIDUAL-PATHS-AUDIT.md` | §2.1 CORRECTIVE row naming `.github/workflows/ci.yml` — path note only; occurrences and verdict unchanged |
| `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` | *"The gates mirror `.github/workflows/ci.yml`"* and the G4 bullet naming the override as an option — corrected in lockstep per §11.4.157 |

`docs/constitution-adoption/GATE-TRIAGE.md` and
`docs/constitution-adoption/POST-APPLY-STATE.md` were searched and make **no**
§11.4.156, CI, workflow, OC-1, OC-2 or G4 claim. They needed no change.
