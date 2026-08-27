# Remote asymmetry in the `milosvasic.ru` submodule — investigation and remediation

**Scope.** OC-2 follow-up. Investigates the reported hazard that commits in the
`milosvasic.ru` submodule are invisible to a fresh clone because `origin`
fetches from one URL and pushes to two others.

**Verified.** 2026-08-27, by direct `git ls-remote` against every configured URL
and by GitHub REST identity lookup. Every claim below was measured, not inferred.

---

## 1. The reported defect

> `origin` FETCHES from `git@github.com:milos85vasic/milosvasic.ru.git` but its
> configured push URLs are only `gitflic.ru:milosvasic/milosvasic-net-v-2` and
> `github.com:milos85vasic/milosvasic.net.v2`. A commit lands on GitFlic and
> `milosvasic.net.v2`, while `git submodule update --init` clones
> `milosvasic.ru.git`, which never receives it.

**The configuration asymmetry is real. The hazard it was believed to cause is
not.** The reasoning above assumes `milosvasic.net.v2.git` and
`milosvasic.ru.git` are two different repositories. They are one.

---

## 2. Measured configuration

`git -C milosvasic.ru remote -v`:

```
gitflic   git@gitflic.ru:milosvasic/milosvasic-net-v-2.git   (fetch)
gitflic   git@gitflic.ru:milosvasic/milosvasic-net-v-2.git   (push)
github    git@github.com:milos85vasic/milosvasic.net.v2.git  (fetch)
github    git@github.com:milos85vasic/milosvasic.net.v2.git  (push)
origin    git@github.com:milos85vasic/milosvasic.ru.git      (fetch)
origin    git@gitflic.ru:milosvasic/milosvasic-net-v-2.git   (push)
origin    git@github.com:milos85vasic/milosvasic.net.v2.git  (push)
upstream  git@gitflic.ru:milosvasic/milosvasic-net-v-2.git   (fetch)
upstream  git@gitflic.ru:milosvasic/milosvasic-net-v-2.git   (push)
```

`git config --get-all remote.origin.pushurl`:

```
git@gitflic.ru:milosvasic/milosvasic-net-v-2.git
git@github.com:milos85vasic/milosvasic.net.v2.git
```

Umbrella's recorded gitlink — `git ls-tree HEAD milosvasic.ru`:

```
160000 commit 66c8d607b20f0d9e984cb0e06f10a2020ebd9a10   milosvasic.ru
```

`.gitmodules` pins the submodule to `git@github.com:milos85vasic/milosvasic.ru.git`.

---

## 3. The three URLs' actual tips

All three were queried directly. **All three are at the identical tip, which is
exactly the umbrella's recorded gitlink**, and all three carry a byte-identical
tag set (`pre-restyle`, `v0.9.0-baseline`, `v1.0.0` … `v1.8.0`):

| URL | `refs/heads/main` | Holds gitlink `66c8d60`? |
| --- | --- | --- |
| `git@github.com:milos85vasic/milosvasic.ru.git` | `66c8d607b20f0d9e984cb0e06f10a2020ebd9a10` | yes — it *is* the tip |
| `git@gitflic.ru:milosvasic/milosvasic-net-v-2.git` | `66c8d607b20f0d9e984cb0e06f10a2020ebd9a10` | yes — it *is* the tip |
| `git@github.com:milos85vasic/milosvasic.net.v2.git` | `66c8d607b20f0d9e984cb0e06f10a2020ebd9a10` | yes — it *is* the tip |

**A fresh `git submodule update --init` resolves correctly today. There is no
dangling gitlink and no invisible commit.**

---

## 4. Mirrors or divergent repos? — the decisive finding

The three URLs are not three repositories. They are **two**:

**(a) `milosvasic.ru.git` and `milosvasic.net.v2.git` are the SAME GitHub
repository.** The GitHub REST API resolves both names to one object:

```
GET /repos/milos85vasic/milosvasic.ru      -> id 439095641, node_id R_kgDOGiwRWQ,
                                              full_name "milos85vasic/milosvasic.ru"
GET /repos/milos85vasic/milosvasic.net.v2  -> id 439095641, node_id R_kgDOGiwRWQ,
                                              full_name "milos85vasic/milosvasic.ru"
```

Same numeric id, same node id, same `created_at` (2021-12-16T18:51:56Z), same
`pushed_at`, same size (42761 KB), same `ssh_url`
(`git@github.com:milos85vasic/milosvasic.ru.git`). The canonical name that
GitHub reports for *both* lookups is `milosvasic.ru`.

The repository was renamed **from** `milosvasic.net.v2` **to** `milosvasic.ru`.
`milosvasic.net.v2.git` is a **stale rename-alias**, and GitHub's permanent
redirect for renamed repositories is what carries pushes through it. So the
fetch URL *does* receive every push — indirectly, via that redirect.
`gh repo list milos85vasic` confirms no separate `milosvasic.net.v2`
repository exists.

**(b) `gitflic.ru:milosvasic/milosvasic-net-v-2` is a genuine, separate mirror**
on a different host, carrying that host's own legacy slug for the same project.
It is **in sync** — identical `main` tip and identical tags. Not divergent.

**Conclusion: mirrors, in sync. Nothing has diverged. No history reconciliation
is needed or attempted.**

---

## 5. What the real defect is

Not invisibility — **fragile addressing**. Two smaller, genuine problems remain:

1. **The GitHub push target is named by a stale alias.** Pushes reach the
   canonical repository only because GitHub still honours the rename redirect.
   That redirect is not a permanent guarantee: it **breaks the moment anyone
   creates a new repository at `milos85vasic/milosvasic.net.v2`**. At that
   point pushes would silently begin landing in the wrong repository while the
   fetch URL quietly fell behind — producing exactly the failure originally
   reported, for real. This is not hypothetical namespace pressure: a separate
   repository `milos85vasic/milosvasic.net` **already exists**.

2. **The invariant "origin's fetch URL appears among origin's push URLs" is
   violated here and nowhere else** (see §6). Even where it is currently
   harmless, it defeats inspection: `git remote -v` cannot be read as evidence
   that pushes reach the cloned URL.

---

## 6. Same shape in the other submodules?

Checked all seven. **`milosvasic.ru` is the only submodule whose `origin` fetch
URL is absent from its own push-URL list.**

| Submodule | Fetch URL in push set? | Push targets | Mirrors in sync? |
| --- | --- | --- | --- |
| `milosvasic.ru` | **NO — only via rename alias** | 2 | yes (`66c8d60`) |
| `monetization` | yes | 4 | yes — all 4 at `54ed7b0` |
| `submodules/constitution` | yes | 6 | yes — all 6 at `a09b1ea` |
| `ai_interviewing` | yes | 1 | yes |
| `vasic.digital` | yes | 1 | yes |
| `design-toolkit` | n/a (no pushurl; pushes to `origin.url`) | — | yes |
| `submodules/superspec` | n/a (no pushurl; third-party) | — | yes |

Every umbrella gitlink was checked for presence on its remote:

- `ai_interviewing` `ed73d855`, `design-toolkit` `efd2c3fb`,
  `submodules/superspec` `c20ac6c1`, `vasic.digital` `6e5411c2`,
  `monetization` `54ed7b0f`, `milosvasic.ru` `66c8d607` — all equal their
  remote `HEAD`.
- `submodules/constitution` gitlink `448981a` differs from remote `main`
  (`a09b1ea`), but `merge-base --is-ancestor` confirms **`448981a` is an
  ancestor of `a09b1ea`** — reachable in a fresh clone. The submodule's local
  branch is simply 62 commits behind. Pinning to an older ancestor is a version
  choice, not a hazard.

**No submodule anywhere in this umbrella has an unreachable gitlink.**

---

## 7. Recommended remediation

The evidence matches the "all mirrors, in sync" branch — but the correct
implementation is **replacement, not addition**.

Adding `milosvasic.ru.git` as a *third* pushurl (the remediation proposed for
that branch) would be wrong here: it and `milosvasic.net.v2.git` are the same
repository, so every push would transmit to it **twice**, and the stale alias
would survive as the latent trap described in §5.1.

**Recommended — normalize the stale alias to the canonical name.** Same
repository, so it cannot redirect work anywhere new; it only removes the
dependency on GitHub's rename redirect and restores the readable invariant:

```
git -C milosvasic.ru config --replace-all remote.origin.pushurl \
    git@github.com:milos85vasic/milosvasic.ru.git 'milosvasic\.net\.v2'
git -C milosvasic.ru remote set-url github git@github.com:milos85vasic/milosvasic.ru.git
```

This is local, reversible git config. It is strictly de-risking: the push
destination is provably unchanged (id `439095641`), only the name used to
address it changes.

**`.gitmodules` needs no change.** It already names the canonical URL
`git@github.com:milos85vasic/milosvasic.ru.git`. No umbrella commit is required
for the remote fix.

**Out of scope by constraint.** Nothing is pushed into the submodule. Nothing
needs to be: all mirrors already hold the umbrella's gitlink.

---

## 8. Applied

Applied 2026-08-27, exactly as recommended in §7. Post-change state:

```
gitflic   git@gitflic.ru:milosvasic/milosvasic-net-v-2.git  (fetch)
gitflic   git@gitflic.ru:milosvasic/milosvasic-net-v-2.git  (push)
github    git@github.com:milos85vasic/milosvasic.ru.git     (fetch)
github    git@github.com:milos85vasic/milosvasic.ru.git     (push)
origin    git@github.com:milos85vasic/milosvasic.ru.git     (fetch)
origin    git@gitflic.ru:milosvasic/milosvasic-net-v-2.git  (push)
origin    git@github.com:milos85vasic/milosvasic.ru.git     (push)
upstream  git@gitflic.ru:milosvasic/milosvasic-net-v-2.git  (fetch)
upstream  git@gitflic.ru:milosvasic/milosvasic-net-v-2.git  (push)
```

`origin`'s fetch URL now appears among its push URLs. The GitFlic mirror is
untouched and still receives every push.

**To revert:**

```
git -C milosvasic.ru config --replace-all remote.origin.pushurl \
    git@github.com:milos85vasic/milosvasic.net.v2.git 'milosvasic\.ru'
git -C milosvasic.ru remote set-url github git@github.com:milos85vasic/milosvasic.net.v2.git
```

**Still open for the operator (agent may not do these):**

- Nothing requires pushing. All three URLs already hold gitlink `66c8d60`.
- The `gitflic` / `upstream` remotes are duplicates of one another (same URL,
  two names). Harmless, but `upstream` conveys no information here. Left alone.
- The GitFlic slug `milosvasic-net-v-2` is that host's own legacy name. Renaming
  it there is a GitFlic-side operation, not a git-config one, and was not done.

---

## 9. Note for OC-2 — ~~not acted on~~ SUPERSEDED 2026-08-27

> **This section's recommendation is void.** It recommends extending an
> `Override §11.4.156` to cover `pages.yml`. **There is no override to extend.**
> An override was sought and disqualified twice over: §11.4.156's closing formula
> names and refuses the exemption vocabulary (*"No escape hatch — no `--allow-ci`,
> `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`, `--ci-exempt`
> flag"*), and the inheritance contract (*"extend them — they do NOT weaken or
> override any universal clause"*) makes a project-local override of an inherited
> clause structurally impossible. Compliance was therefore the only remaining
> path that does not amend shared governance, and the operator chose it:
> ***"Comply — disable both, enforce locally."*** ~~`pages.yml` is renamed to a
> non-active `.disabled` name per §11.4.156(B), alongside the umbrella's
> `ci.yml`; the gates move to a local pre-push hook.~~ No constitution amendment
> was made.
>
> **Second update, same day — `pages.yml` was NOT disabled after all.** The
> deploy-vs-test asymmetry argued below is not merely correct; it is *stronger*
> than this document stated, and it reversed the decision. `gh api
> repos/milos85vasic/milosvasic.ru/pages` returns `build_type: "workflow"`:
> GitHub Pages publishes `https://milosvasic.ru/` **exclusively** by running that
> workflow. There is no `gh-pages` branch, no `docs/` folder, and the repository
> root is Jekyll SOURCE, so it cannot be served raw from a branch;
> `_tools/deploy-langs.sh` pushes source and then `sleep`s waiting for that
> workflow, so it is **not** a fallback. Disabling `pages.yml` would not make
> publishing manual — it would end it. Operator's overriding directive,
> verbatim: ***"Make sure all pages websites work flawlessly! No website can be
> broken! All websites we have here are running deployed in production!"***
>
> **`pages.yml` is ACTIVE and stays active.** Only the umbrella's `ci.yml` was
> disabled; its gates moved to a local pre-push hook. `milosvasic.ru` is a
> **known, documented deviation** from §11.4.156 — **still not an override**, and
> never to be recorded as one. **Honest boundary (§11.4.6):** the umbrella's
> remaining provider-side surfaces (org-default required workflows,
> branch-protection required checks, scheduled exports) are operator-only and
> unverified, so even `ci.yml`'s rename does not by itself prove *"a push
> triggers ZERO runs"*. Full record:
> [`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) §0.

`milosvasic.ru/.github/workflows/pages.yml` is an active root workflow in an
owned submodule (`on: push [main]`, `workflow_dispatch`; it builds Jekyll and
deploys to GitHub Pages). §11.4.156(A) forbids it and (C) scopes the clause to
*"repositories we author + push"* — `milosvasic.ru` is authored and pushed here,
so the clause applies exactly as it does to OC-1.

**Should the `Override §11.4.156` recorded for OC-1 extend to this workflow?**
An override should name it explicitly rather than absorb it silently:

- **The two are not the same case.** OC-1's `ci.yml` is a *test* workflow — the
  only mechanical check this root has, given INVENTORY gap G5. `pages.yml` is a
  *deploy* workflow: it publishes `https://milosvasic.ru/`. Disabling it does
  not weaken enforcement, it takes a live site offline. That is a stronger
  practical reason to keep it and a different justification, so it deserves its
  own sentence in the override rather than inheriting OC-1's reasoning.
- **Scope differs.** An override recorded in the umbrella's `Constitution.md`
  governs the umbrella. `pages.yml` lives inside a submodule with its own
  working tree; §102 reserves committing there to the operator. An umbrella
  override should therefore state explicitly that it covers the owned submodule
  `milosvasic.ru`, or the file remains formally unresolved.

~~**Recommendation: yes, extend it — but by naming `milosvasic.ru/.github/workflows/pages.yml`
and its deploy-not-test justification explicitly in the same
`Override §11.4.156` entry.** A single unqualified override text would leave
OC-2 ambiguous.~~

**Withdrawn 2026-08-27** — see the banner at the head of this section. The
override never existed, so there was nothing to extend or to name. What the
recommendation was actually protecting against — OC-2 being absorbed silently
into OC-1's reasoning — is instead honoured by giving `pages.yml` its own row and
its own deploy-not-test justification in
[`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) §4, and by the
separate treatment in its §0.

**Vindicated in substance, though.** The bullet above — *"Disabling it does not
weaken enforcement, it takes a live site offline"* — was the correct reading, and
it understated the case: with `build_type: "workflow"` there is no fallback
publisher at all. That argument is what carried the reversal. The mechanism it
proposed (an override) was unavailable; the conclusion it reached (`pages.yml`
must keep running) is the one that stands, recorded as a **documented deviation**
rather than an override.

`Constitution.md` was **not** edited *by this document* — another agent held it
at the time. It has since been reconciled with the decision; its OC-1 and OC-2
sections now carry the reversal.

---

## Constraints observed

No push inside any submodule. No `lumen index` / `purge`, no `codegraph index`.
`Constitution.md`, `scripts/`, `.github/workflows/ci.yml`, `.ashlrcode/` and
`design-system/` untouched. The `commit` wrapper was deliberately **not** run:
it performs `git add .`, which would stage another agent's in-flight
`Constitution.md` edits. This document is left uncommitted for the operator.
