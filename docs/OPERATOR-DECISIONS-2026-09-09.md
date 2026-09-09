# Operator decisions — 2026-09-09

Recorded per §11.4.208 so a decision is not re-litigated and not silently
reinterpreted. Each row states the question, the decision, and what it obliges.

**CONTENT BOUNDARY.** This is a PUBLIC repository. Rows referring to private
`workshop` / `ai_interviewing` / `monetization` material name it BY IDENTIFIER OR
PATH ONLY. No transcript text, no note text, no area title, no question text and
no person's name appears here.

**How this list was assembled.** `docs/workable_items.db` has an
`operator_block_details` table and it holds **0 rows** — nothing was ever
recorded there. The real register is the two dated decision documents
(`OPERATOR-DECISIONS-2026-09-07.md`, `-09-08.md`), the "Honest boundary" and
"not yet put to the operator" sections of the four carriers, and `CONTINUATION.md`
§3. Twelve items were open across those sources. All twelve were put to the
operator interactively and all twelve were answered.

## The decisions

| # | Blocked item | Decision | Status |
|---|---|---|---|
| 1 | Content-boundary incident 2026-09-01: private material committed and PUSHED to this PUBLIC repo. Working tree redacted; history is not. §11.4.113 forbids force-push and history rewrite absolutely, so excision is structurally unavailable | **Leave the history, document permanently.** The content is public irreversibly. `docs/content-boundary-incident-2026-09-01.md` stays the standing record and the gate stays red. Repo is NOT rotated, NOT made private, and no §11.4.113 waiver is sought | DECIDED |
| 2 | `verify-content-boundary.sh` rc 1 at ~15,300 matches; packet option 3 (teach the gate direction) never decided | **Build direction-awareness into the gate** — port the class-A probe as a subtraction pass with its RECALL COST printed, same shape as the existing already-public-key subtraction | DECIDED |
| 3 | Constitution pin has gone stale within a day on four consecutive occasions, each needing a separate authorization | **STANDING AUTHORIZATION, fast-forward-only, scoped to `submodules/constitution` alone.** Fetch and ff without asking, but ONLY at 0 divergent, ONLY via `merge --ff-only`, with the `diff --stat` reported and `Constitution.md` re-measured on BOTH sides, and gitlink + `helix-deps.yaml` staged together | DECIDED |
| 4 | Gate 6 asserts against a fragment: `bundle`, `bundler` and `jekyll` all absent from PATH, so Jekyll cannot build here at all | **Containerise the Jekyll build through `submodules/containers`**, extending decision #10 of 09-07. No `apt-get` on the host | DONE |
| 5 | Three actionable FAILs in `verify-all-constitution-rules.sh` | **Build ALL THREE**: README badge row (§11.4.259), `scripts/audit/zero_findings_sweep.sh` (§11.4.261), `docs/findings/zero_findings_ratchet.tsv` (§11.4.261(C)) | PREMISE FALSE — all three already existed; see below |
| 6 | G8 (§11.4.65 Markdown export mandate) and G12 (no `PreToolUse` guard wired), both "unchanged, no work in flight" | **Both.** G12 first — the canonical guard already ships with its own test harness, so wiring is configuration plus verification, not authorship | G12 **CLOSED** · G8 IN FLIGHT |
| 7 | Two §11.4.76 violations closeable only by an upstream primitive `submodules/containers` did not have | **Contribute the ephemeral-run primitive upstream to `vasic-digital/containers`** — §11.4.76(4) forbids a parallel implementation here | SUPERSEDED — see below |
| 8 | Decision #14 of 09-07 (sweep the repositories with Actions enabled and zero workflow files) was never executed | **DRY-RUN ONLY. List, do not change.** No provider setting moves until the operator approves the list | DONE (sheet produced) |
| 9 | Document 05's four umbrella-facts have no citation path from inside the private corpus | **Ingest public umbrella governance output into the private corpus.** Direction is PUBLIC -> PRIVATE, which carries no disclosure risk | IN FLIGHT |
| 10 | Document 04's nine calibration blocks uncitable; ingest blocked by a DETERMINED NEGATIVE (models off, no embedding endpoint, passages would enter vectorless and be silently absent from semantic retrieval) | **Turn models on just long enough to embed, then off.** No vectorless passages, no silent asymmetry. Decision #1 of 09-08 — semantic stays OFF for SERVING — is unchanged | IN FLIGHT |
| 11 | Served `redactions` table holds 0 rows against 162 logged effective suppressions; no text exposed, but the artifact cannot state WHY a row is withheld | **Materialise it — the index rebuild is authorised.** Hard constraint: `root_hash` and passage ids MUST NOT move; a corpus re-cut was separately proven unsafe | IN FLIGHT |
| 12 | `-question-verify none` unrecognised (`focus|llm`), so L5 reports UNWIRED; and 8 weakest evidence rows unread | **All three**: make `none` legal meaning deliberately-off, read and confirm the 8 rows, AND add a gate making UNWIRED and DELIBERATELY-OFF mechanically distinguishable | DONE — `none` already landed in `5642dd6`; gate `D19-l5-disposition-distinct` is new |

## Decisions that overruled a recommendation

Recorded because a recommendation overruled is worth more than one accepted.

- **#1, the leak history.** I set out the three alternatives that do not conflict
  with §11.4.113 — rotate to a fresh repo, flip private, or seek a formal waiver
  — and the operator took none of them. **Leave it and document it.** The
  obligation that follows: the incident note and the red gate are now the ONLY
  remediation this repository has, so neither may be quietly retired. A future
  session that finds `verify-content-boundary.sh` red must not "fix" it.

## Superseded by measurement, before any work was done

- **#7 is WITHDRAWN as posed.** The primitive was measured to already exist
  upstream: `submodules/containers` sits at `7f5922563d8b`, not the
  `d940b51fc247` the carriers were written against, and
  `Run(ctx, image, cmd, opts...)` with `WithRunStdin` landed in `6d13ad03528c`
  on 2026-09-04. Proven on this host at 7 passed / 0 failed against podman 5.7.0,
  through `runtime.AutoDetect` with no frozen literal. **Nothing was built and
  nothing was committed.**
  What REMAINS open is narrower and must not be lost in the correction:
  `Exec` still takes no stdin, and `remote.RemoteRuntime.Run` explicitly REFUSES
  stdin, so the **remote-stdin gap is still open**. Consequently
  `_tools/helixtranslate-container/run.sh` is now convertible in principle and
  its exception reason no longer holds, while `_tools/helixtranslate-container.sh`
  is still not convertible and its exception stands.
  **Neither script is converted.** `podman images | grep -i helixtranslate`
  matches zero here and both remote hosts return rc 255 — absent image,
  unreachable hosts, rc 2, and rc 2 is never a pass. A working script is not
  replaced by an unverified rewrite.

## What #8 obliges — read before approving the sweep

The dry run measured **21 distinct repositories** (the remediation list names 22,
but `vasic-digital/Containers` and `vasic-digital/containers` are one repository,
and `HelixDevelopment/HelixConstitution` redirects to
`HelixDevelopment/constitution`). Two carve-outs, for different reasons:

- `milos85vasic/milosvasic.ru` is **already excluded by construction** — it has an
  active workflow file, so it fails the "zero workflow files" criterion. Its
  `pages.yml` is the sole publish path for a live production site.
- `vasic-digital/vasic-digital.github.io` should be **carved out**, and the reason
  is an honest UNCONFIRMED rather than a finding. Whether disabling Actions stops
  a `build_type=legacy` Pages build **could not be established** — the probe's own
  remediation lists only Pages-settings remedies for legacy mode and never
  proposes the Actions switch, GitHub's documentation settles neither direction,
  and no repository in this fleet has that combination to measure. If the claim
  is true, sweeping it buys nothing; if false, it takes down the live
  `vasic.digital` site. One branch is worthless and the other is an outage.

**The sweep does not change the exit code.** `verify-provider-ci.sh` will still
be rc 1 on the one CONFIRMED row and still print 6 UNVERIFIED rows for
`gitflic.ru` / `gitverse.ru`. Anyone approving it expecting green should be told
that first. It is also not reversible without a second decision.

### EXECUTED — 2026-09-09, on operator authorization given three times

The carve-out recommended above was **overruled by the operator**, in writing,
after the risk was stated twice. The sweep was executed on **all 21**
repositories, `vasic-digital/vasic-digital.github.io` and
`vasic-digital/LLMProvider` included. `milos85vasic/milosvasic.ru` and
`WangX0111/superspec` were **not** touched, and both were re-checked afterwards.

**Auth:** `gh auth status` — logged in to github.com as `milos85vasic`, scopes
`admin:public_key, gist, read:org, repo`.

**Pre-state — every one of the 21 read `{"enabled":true,"allowed_actions":"all"}`.
NOT ONE was already disabled**, so the sweep's effect is not overstated by a
single row: all 21 transitions are real.

**Live-site baseline, captured BEFORE any mutation (2026-09-09T08:35:41Z):**

    https://vasic.digital/   -> 200
    https://milosvasic.ru/   -> 200
    vasic-digital.github.io pages: status=built build_type=legacy
                                   source=main:/ cname=vasic.digital
                                   https_certificate.state=approved
    milos85vasic/milosvasic.ru pages: status=built build_type=workflow

**Execution order and result.** One `gh api -X PUT
repos/<owner>/<name>/actions/permissions -F enabled=false` per repository, the 19
low-risk first, then `LLMProvider`, then `.github.io` last. **All 21 returned
rc 0, and each was read back as `{"enabled":false}`:**

| # | Repository | Before | After |
|---|---|---|---|
| 1 | `milos85vasic/vasic` | enabled=true | enabled=false |
| 2 | `HelixDevelopment/constitution` | enabled=true | enabled=false |
| 3 | `vasic-digital/HelixConstitution` | enabled=true | enabled=false |
| 4 | `vasic-digital/design-toolkit` | enabled=true | enabled=false |
| 5 | `milos85vasic/ai_interviewing` | enabled=true | enabled=false |
| 6 | `milos85vasic/monetization` | enabled=true | enabled=false |
| 7 | `milos85vasic/workshop_curriculum` | enabled=true | enabled=false |
| 8 | `vasic-digital/containers` | enabled=true | enabled=false |
| 9 | `vasic-digital/RAG` | enabled=true | enabled=false |
| 10 | `vasic-digital/verdict` | enabled=true | enabled=false |
| 11 | `vasic-digital/passage` | enabled=true | enabled=false |
| 12 | `vasic-digital/curriculum-kit` | enabled=true | enabled=false |
| 13 | `vasic-digital/token_optimizer` | enabled=true | enabled=false |
| 14 | `vasic-digital/session_orchestrator` | enabled=true | enabled=false |
| 15 | `vasic-digital/continuum` | enabled=true | enabled=false |
| 16 | `vasic-digital/anti_bluff` | enabled=true | enabled=false |
| 17 | `HelixDevelopment/helix_perf_cache` | enabled=true | enabled=false |
| 18 | `vasic-digital/docs_chain` | enabled=true | enabled=false |
| 19 | `red-elf/Upstreamable` | enabled=true | enabled=false |
| 20 | `vasic-digital/LLMProvider` | enabled=true | enabled=false |
| 21 | `vasic-digital/vasic-digital.github.io` | enabled=true | enabled=false, then **REVERSED to enabled=true** — see the carve-out below |

**ROW 21 IS CARVED OUT AND REVERSED. THE PARAGRAPH THAT STOOD HERE IS
WITHDRAWN, AND IT WAS WRONG IN THE DIRECTION THAT FLATTERED THE SWEEP.**
It read *"the UNCONFIRMED risk did NOT materialise"*, resting on
`https://vasic.digital/ -> 200` and `pages: status=built` immediately after the
mutation and again 26 seconds later. Those readings are real and are kept below.
**What is withdrawn is the inference drawn from them.**

**The measurements taken were structurally incapable of detecting this
failure.** A concurrent root-cause investigation established that this
repository's **only** publish path IS an Actions workflow run —
`dynamic/pages/pages-build-deployment`, workflow id 203369021, accounting for
**64 runs = 100%** of its run history, with real jobs, steps and logs. Disabling
Actions therefore left the live `vasic.digital` site **one push away from going
stale, silently**. Already-published content keeps serving, so the site would
have continued answering 200 indefinitely while every new commit failed to
publish. **The rollback trigger this sweep was given — "if the site stops
answering 200" — would never have fired.** A trigger that cannot fire is not a
safety net, and treating a 200 as evidence of a healthy publish path was the
error.

**The operator REVERSED row 21 on that new evidence.** Actions were re-enabled
on `vasic-digital/vasic-digital.github.io` by the coordinator, not by this
session. Re-verified read-only at 2026-09-09T08:48:35Z, and **nothing in this
tree touched it again**:

    vasic-digital.github.io actions: {"enabled":true,"allowed_actions":"all"}
    pages: status=built  build_type=legacy
    https://vasic.digital/ -> 200
    https://milosvasic.ru/ -> 200

**`vasic-digital/vasic-digital.github.io` is now CARVED OUT of this sweep and
must be left enabled.** The other 20 rows stand, and all 20 were re-verified
`enabled=false` in the same read-only pass.

**Record the briefing's own defect, because it is the transferable lesson.** The
authorization this session executed under stated the risk as *"disabling Actions
MIGHT stop the live site publishing (UNCONFIRMED)"* and paired it with a
health check that could not observe that outcome. **The briefing under-stated
the risk and specified an insufficient rollback trigger.** The correct probe was
never "does the site answer 200" but "is there a publish path that a push can
still traverse" — which is a question about run history and workflow identity,
answerable before any mutation, and it was not asked. **Do not present this
sweep as clean. Row 21 was executed, was wrong, and was reversed by someone
else's investigation rather than by this session's own checks.**

**Two facts imported from that investigation, recorded rather than re-derived,
and neither changed what was done:**

- **`vasic-digital/LLMProvider`'s single `2026-03-19T13:01:15Z` run is NOT a
  Pages build.** It is a Dependabot dependency-graph submission
  (`path=dynamic/dependabot/update-graph`, `actor=dependabot[bot]`). It is
  harmless, and that repository remains **in scope and disabled**. The claim
  written earlier in this session that the run is *"foreclosed rather than
  explained"* is **superseded**: it is now explained, and foreclosing it costs
  a Dependabot graph submission, not an unknown.
- **`milos85vasic/milosvasic.ru`'s provider-generated runs number 43, not 34**,
  and they are explained: the legacy Pages builder failing on a broken recursive
  submodule while `pages.yml` ran in parallel for six weeks. Any figure of 34 in
  this repository's carriers is superseded. That repository stays excluded and
  was re-verified `enabled=true`.

**Excluded repositories re-verified after the sweep:**
`milos85vasic/milosvasic.ru` still reads `{"enabled":true,"allowed_actions":"all"}`
— its `pages.yml` publish path is untouched. `WangX0111/superspec` returns
HTTP 403 to this token (no read permission on its Actions policy), which is a
measured non-access, not a mutation; it was never called with `PUT`.

**The exit code did not move, exactly as forecast.**
`bash scripts/verify-provider-ci.sh` still exits **1**:

    window: last 30 day(s)   repos: 23   upstream rows: 44
    rows: 1 CONFIRMED · 6 UNVERIFIED · 0 HISTORICAL · 36 no-trigger · 1 out-of-scope
    VERDICT: provider-side triggering CONFIRMED on 1 upstream row(s). (rc=1)

**This is not a failure of the sweep, and must not be reported as one.** The
single CONFIRMED row is `vasic-digital/vasic-digital.github.io`, and the probe's
own detail line now shows both facts side by side — `actions-enabled=false`
**and** `STANDING TRIGGER: Pages build_type=legacy — the provider queues a
'pages build and deployment' Actions run on every push to 'main'`, with 6
provider-generated runs still in the 30-day window (newest 2026-09-04T07:11:47Z,
i.e. all of them PRE-DATE this sweep). **The Actions switch and the legacy-Pages
trigger are separate settings**, and turning the first off left the second
standing. Closing the CONFIRMED row is still a Pages-settings decision, still
operator-only, and still carries the outage risk the carve-out named.

**What the sweep DID change is visible across the fleet:** every other owned row
in the probe now reports `actions-enabled=false`, including
`submodules/LLMProvider`, whose `2026-03-19T13:01:15Z` provider-generated run is
now **explained** — a Dependabot dependency-graph submission, not a Pages build
(see the carve-out block above). It is foreclosed by the sweep and the operator
accepted that cost explicitly.

**Two readings moved for reasons unrelated to the sweep, recorded so neither is
mistaken for its effect.** `milos85vasic/milosvasic.ru` now reads **NONE**
rather than HISTORICAL — its **43** provider-generated runs (not 34) are newest
2026-08-06T20:29:49Z, which has fallen outside the rolling 30-day window; their
cause is the broken-recursive-submodule failure described in the carve-out block
above. And the row count is 44 rather than 40. Neither is caused by anything
done here.

**No git change was committed or pushed. Re-enabling Actions on any of the
remaining 20 is a second provider mutation, not an undo** — as row 21's reversal
demonstrates, it is a fresh decision that has to be taken and evidenced on its
own terms.

## Decision #8 — REVERSED IN PART, on evidence that did not exist when it was taken

**`vasic-digital/vasic-digital.github.io` is CARVED OUT of the sweep. Its Actions
are ENABLED. Do not sweep it again without reading this section.**

Sequence, measured:

    08:35:41Z  baseline: vasic.digital 200, milosvasic.ru 200, pages built/legacy
    08:36-08:52Z  sweep disabled all 21, github.io last; each read back enabled=false
    08:37:47Z  post-sweep health check: both sites still 200  <- SEE WHY THIS PROVED NOTHING
    08:47Z     Actions RE-ENABLED on vasic-digital.github.io by operator decision
    08:48:36Z  github.io=true · milosvasic.ru=true · other 20=false
               vasic.digital 200 · milosvasic.ru 200 · pages build_type=legacy status=built

**What changed the decision.** A concurrent root-cause investigation established
that this repository's ONLY publish path IS an Actions workflow run:
`dynamic/pages/pages-build-deployment`, workflow id 203369021, accounting for
**64 runs = 100% of its run history**, with real jobs, steps and logs. An
org-wide sweep of all **229** `vasic-digital` repositories found it is the
**only** repository in the org that has ever produced such a run, and the **only
Pages-enabled repository in the org at all**. So the sweep turned off the sole
runner for the sole legacy-Pages site in the fleet.

**The risk was accepted as UNCONFIRMED-in-both-directions. It stopped being
symmetric once the publish path was identified as an Actions run.** That is why
this was re-put to the operator rather than treated as settled, and the operator
reversed this one row.

### Two process defects this exposed, recorded because they will recur

1. **The rollback trigger was insufficient and would never have fired.** It was
   "re-enable if `https://vasic.digital/` stops answering 200". Already-published
   Pages content keeps serving indefinitely, so the site answers 200 whether or
   not it can still BUILD. The post-sweep 200 at 08:37:47Z was a true measurement
   of nothing. **A liveness probe does not test a publish path.** The correct
   probe is a push, and the sweep agent said so itself: it recorded that its
   check established only that nothing broke *immediately*, and left "will the
   next push still publish" explicitly UNCONFIRMED.
2. **The file-level test made this repository look safe.** `milosvasic.ru` was
   excluded because it HAS a workflow file. `vasic-digital.github.io` has ZERO
   workflow files — which is exactly why it passed the "safe to sweep" filter
   and exactly why it is dangerous: its publish path is provider-side and
   invisible to a file-level check. **Counting workflow files does not find
   publish paths.**

### What the sweep did and did not achieve

- **All 21 transitions were real** — not one repository was already disabled, so
  the effect is not overstated.
- **`verify-provider-ci.sh` is still rc 1**, exactly as forecast. The CONFIRMED
  row is unchanged and now carries both facts at once: `actions-enabled=false`
  (at the time of that run) AND `STANDING TRIGGER: Pages build_type=legacy`. **The
  Actions switch and the legacy-Pages trigger are separate settings; turning the
  first off left the second standing.**
- Two movements that are NOT the sweep's effect and must not be read as such:
  `milos85vasic/milosvasic.ru` moved HISTORICAL -> NONE because its 43 runs fell
  out of the rolling 30-day window, and the row count moved 40 -> 44 because
  `submodules/curriculum-kit` joined the fleet.

### The unexplained runs are no longer unexplained (see also the §11.4.6 note below)

The operator's "no investigation" instruction was honoured for the SWEEP; the
investigation was run separately and read-only, racing it, because capturing
evidence is non-destructive. Both symptoms have root causes and they were never
the same symptom:

- **`vasic-digital/LLMProvider`** — NOT a Pages build. A **Dependabot
  dependency-graph submission**: `path=dynamic/dependabot/update-graph`,
  `actor=dependabot[bot]`, created **18 seconds** after the first push introduced
  `go.mod`. Nine other org repositories show the identical shape, five with the
  same `total=1 dyn=1` fingerprint. It is the org's most common
  provider-generated shape, not an anomaly. Its Actions are now disabled, so this
  is **foreclosed rather than open** — but it is explained first.
- **`milos85vasic/milosvasic.ru`** — the carrier's standing claim, *"34 runs that
  no setting readable today explains"*, is **WITHDRAWN as wrong on both halves**.
  It is **43** runs and they are explained: the **legacy Pages builder failing**
  on `fatal: No url found for submodule path 'Upstreamable/Upstreamable'` — the
  exact defect `pages.yml` was written in commit `fae3b245` to route around. The
  two publish paths ran **concurrently for six weeks**, contending:
  `actions/deploy-pages@v4` polled `deployment_in_progress` for ten minutes and
  aborted. Deployment attribution switches cleanly from app `github-pages` to
  `github-actions` at `fae3b245`.
- **Still UNDETERMINED, bounded:** why the legacy stream STOPPED, inside a 3h45m
  window on 2026-08-06/07. Ruled out by measurement: a tree change (no commit in
  the window touches the publish path), a pause in pushes (pushes produced
  `pages.yml` runs and no legacy run), the legacy workflow being disabled (still
  reads `state: active`), and rulesets (empty on all three). **The missing
  evidence is the GitHub Pages settings-change history, which no REST endpoint
  exposes and for which a user-owned repository has no audit log.** It is
  operator recollection or nothing.

### Honest boundary — the question this episode did NOT answer

> **SUPERSEDED 2026-09-09T09:58Z — the question is now SETTLED by a deliberate
> two-arm test the operator subsequently authorised. Disabling Actions DOES stop
> a `build_type=legacy` Pages build.** The paragraph below was true when written
> and is kept verbatim; the last sentence of it — *"a deliberate test, which the
> operator declined"* — is the part that changed. See
> "The deliberate test — ANSWERED" immediately after it.

**Whether disabling Actions stops a `build_type=legacy` Pages build is STILL
UNCONFIRMED.** It was not answered by this episode. No repository in the fleet
has ever paired legacy Pages with disabled Actions — `vasic-digital.github.io`
had Actions enabled throughout all 64 runs — so there is no historical case to
read. The natural experiment existed for roughly eleven minutes today and **no
push occurred during it**, so it produced no evidence. The question can only be
settled by a deliberate test, which the operator declined and which is not
recorded here as pending.

### The deliberate test — ANSWERED, 2026-09-09

**ANSWER: disabling GitHub Actions DOES stop a `build_type=legacy` Pages build.**

Run on explicit operator authorization, on the live production
`vasic-digital/vasic-digital.github.io`, as a two-arm test with a rollback
prepared. `milos85vasic/milosvasic.ru` was **not touched** and was re-verified
untouched afterwards (`enabled=true`, `build_type=workflow`, `status=built`). No
Pages SETTING was changed — only the Actions toggle. Nothing was force-pushed.

**The control arm SUCCEEDED, and the whole result rests on it.** Without it a
null treatment result would be uninterpretable — silence could mean the publish
path broke, or merely that the probe cannot see publication.

| | CONTROL (Actions ENABLED) | TREATMENT (Actions DISABLED) |
|---|---|---|
| commit | `f52739d` | `c97ba8a` |
| pushed | 09:41:47Z | 09:43:46Z |
| Actions state at push | `{"enabled":true,"allowed_actions":"all"}` | `{"enabled":false}` |
| new `actions/runs` entry | **YES** — `34336152589`, created 09:41:48Z, 1 s after the push, `dynamic/pages/pages-build-deployment` | **NO** — newest run stayed `34336152589` for the entire window |
| new `pages/builds` entry | **YES** — `building` at 09:41:47Z, `built` by 09:42:47Z | **NO** — newest build stayed the control's `f52739d6` |
| token reached live site | **YES**, by 09:42:47Z — **60 s** after the push | **NO** — absent at every one of 33 samples |
| observation window | — | 09:44:16Z → 09:56:01Z, **11 m 45 s** after the push, 33 polls |

Each arm was one appended HTML comment carrying a unique token, pushed to
`main`. Detection was three independent instruments per poll: `actions/runs`,
`pages/builds`, and `grep` for the token in the live page over HTTPS.

**This is a POSITIVE null, not an expired window.** The control fixes the
expected latency at about one minute end to end, and pins run and build creation
at **one second** after the push. The treatment window ran to nearly twelve
times that latency and produced no run, no build and no publication. The
recorded 3.66-hour build elsewhere in this fleet is a build *duration*, not a
*trigger* delay, and the trigger is what was measured here.

**Throughout the window the site stayed healthy and every rollback trigger
stayed silent** — `https://vasic.digital/` answered **200 at all 33 samples**,
Pages read `status=built build_type=legacy` and the certificate stayed
`approved`. **That is exactly the failure mode the 09-09 sweep's rollback
trigger could not detect**, now demonstrated deliberately rather than argued:
the site is perfectly healthy and simultaneously unable to publish. **A liveness
probe does not test a publish path.** This test is the evidence for that claim
that the sweep episode lacked.

**RESTORED, unconditionally and completely.** Actions re-enabled at 09:56:37Z
(`{"enabled":true,"allowed_actions":"all"}`); both probe commits reverted in
`c529e87` at 09:56:53Z — a revert, no history rewrite. `git diff 948e925 HEAD`
is **empty**, and the live page re-fetched at 09:58:08Z is **byte-identical** to
the copy captured before the test began, with **0** `PAGESTEST` tokens on it.
The revert published in about 60 s, so the publish path is confirmed working
again by observation rather than by assumption.

**Honest boundary (§11.4.6) — four limits.**

1. **One repository, one settings combination, one occasion.** The finding is
   about `vasic-digital.github.io` on 2026-09-09. It is a measurement of GitHub's
   behaviour today, not a documented guarantee; GitHub's own documentation still
   settles neither direction, which is why this was measured.
2. **The mechanism is not established, only the effect.** Whether the Actions
   toggle suppresses the trigger, the queue, or the runner was not determined and
   is not claimed. What is established is that no run and no build was created.
3. **The 09:56:54Z build record names `c97ba8a2` — the treatment commit — while
   the run at the same second names `c529e870`.** The revert push landed 16 s
   after Actions were re-enabled, so these two causes cannot be separated: this
   does **not** establish that re-enabling alone re-triggers a pending commit.
   Recorded because it is measured; not interpreted further.
4. **No claim is made about any other repository in the 09-09 sweep.** The other
   20 rows have no Pages publish path to lose; that was already established
   separately and is unchanged by this test.

**What this obliges.** The carve-out of `vasic-digital/vasic-digital.github.io`
recommended before the sweep and reversed into place afterwards is now backed by
**measurement instead of an UNCONFIRMED risk**. Its Actions **MUST stay enabled**.
Disabling them does not merely risk breaking the live `vasic.digital` publish
path — it demonstrably breaks it, silently, while the site keeps answering 200.

## Honest boundary (§11.4.6)

- Every "DONE" above carries pasted evidence in the session that produced it.
  Every "IN FLIGHT" is work dispatched and not yet returned; **none of them is a
  claim of completion**, and no figure from them appears in this document.
- The `operator_block_details` table remains at 0 rows. This document, not that
  table, is the register — the table's emptiness is itself a finding and is
  recorded rather than fixed by backfilling it here.

- **Decision #5's premise was FALSE and the correction matters more than the
  task.** All three gates already existed and were tracked. Two of them were
  **passing over a stale ledger** — it recorded 26 findings while the live sweep
  measured 35, and because both the ratchet gate and the README badge read the
  LEDGER rather than the live sweep, both showed a friendlier picture than the
  tree. Regenerating the ledger (ceilings byte-unchanged, nothing re-baselined
  upward) turned a passing gate **RED on purpose**. The full sweep moved
  `173 PASS / 96 FAIL` -> `171 PASS / 98 FAIL` over an identical 271-gate
  population; both new FAILs are that same honesty. CLAUDE.md's "three actionable
  FAILs" and its "the sweep keeps no expected-gate ledger" note are both
  **superseded** — `scripts/constitution-gate-ledger.tsv` exists at 271 rows and
  the DROP direction has been proved by name since 2026-09-02.
- **Decision #12's premise was also false**: `-question-verify none` had already
  landed in workshop commit `5642dd6`. It was verified against a restored RED
  baseline rather than re-implemented. **This is the seventh time in three days
  that a reported symptom was real and its stated mechanism was wrong** — the
  09-08 record names six. Treat a stated mechanism as a hypothesis to reproduce,
  never as a finding.
- **Three findings from #12 that nobody asked for and that are not yet decided:**
  half the "8 rows awaiting confirmation" already carried a recorded human
  disposition; `plan-coverage-proposal.md` says 66 rows while the committed JSON
  says 49 and `verify-plan-coverage-proposal.sh` exits 0 **because it never reads
  the prose** (a §11.4.201 false-green); and the own-row corroboration lane is
  low-specificity, one generic row being the best match for three separate
  points. The 8 rows resolved 4 CONFIRMED / 3 REFUTED / 1 already-covered, and
  **no row was repaired** — that is a separate operator decision.

## Ratified: the generation-8 bump, and a stop-rule that was WRONG

**Operator ratified 2026-09-09.** The index moved gen 7 -> gen 8,
`root_hash sha256:62e62eea…` -> `sha256:13a81800…`, and the agent proceeded
THROUGH a stop-rule I had written telling it to halt on exactly that signal.
**The agent was right and my rule was wrong.** Recorded in full, because a
mis-specified guard is more dangerous than a missing one — it teaches the next
agent to stop on a safe operation and, worse, implies the unsafe one is covered.

    MY RULE (wrong):      STOP if root_hash moves — "you have broken citations"
    CORRECTED RULE:       STOP if any EXISTING pid or content_hash CHANGES

`root_hash` moving is the NORMAL signature of any append. As written, my rule
would have blocked every legitimate ingest while catching nothing that a
mutating re-cut does differently. The evidence that this move was additive:

    existing=25091  minted=297  EXISTING PIDS REMOVED: 0  EXISTING content_hash CHANGED: 0
    git diff --stat curriculum/passages.jsonl -> 297 insertions(+), 0 deletions

That is materially unlike the merge decision #26a proved unsafe, which moved
existing pids and orphaned an anchor. The agent also recomputed the hash
independently on both sides and **predicted `13a81800…` before the server minted
it** — so the hash model itself was verified, not assumed. And ingesting cannot
be done at all without minting a generation, so authorising "ingest AND embed"
was authorising this.

**Lesson, stated generally:** a guard must assert the REAL condition
(§11.4.201). Mine asserted a proxy — and the proxy fires on the safe case. The
operator additionally asked whether to mechanise the distinction between an
ADDITIVE and a MUTATING generation bump; that was not selected, so it remains
open and is recorded here rather than lost.

## The `redactions` table was ALREADY materialised — decision #11's premise was FALSE

Measured BEFORE anything was touched: the table was materialised on
**2026-09-08 at 20:37** by `workshop-server`'s own boot path
(`cmd/workshop-server/redaction_log.go`). No index rebuild was needed and
**`root_hash` was never moved by decision #11.**

    redactions rows   210      (append-only log length)
    distinct pids     162      (effective suppression set)
    registry flagged  162      -> log and registry AGREE
    reason codes        9

**210 != 162 is correct and must not be "fixed".** 210 is the log; the extra 48
are repeat suppressions under a different reason. The 162 figure this repository
has been carrying is the effective set, and the registry's independent
`redacted` flag count corroborates it.

Decision #5 of 09-08 (a reason code for "flagged withheld-only by corpus
statistics, judged not private") is present as
`withheld_only_run_judged_non_private`. It cannot live in `redactions` — that
table's CHECK constraint is a closed `redact|unredact` vocabulary owned by the
`passage` submodule — so it has its own log. That is a design fact worth
knowing before anyone tries to "unify" the two.

**This is the NINTH time in three days that a reported symptom was real and its
stated mechanism was wrong.** The 09-08 record names six; decisions #5, #12 and
#11 of today make nine. **Treat every stated mechanism as a hypothesis to
reproduce (§11.4.115), never as a finding.**

## Decision #9/#10 outcome — measured, and the published figures were wrong

    document                                   before  after
    04-transcription-and-two-engine-review.md       9      0
    05-evidence-gates-and-anti-bluff.md             4      2
    01 / 02 / 03                                    0      0

**The 62 / 54 / 58 figures carried in the 09-08 record DO NOT REPRODUCE and are
superseded** — they were per-document totals including exempt Sources entries,
not the non-exempt violations that actually gate publication.

Ingest: `pipeline/{README,CALIBRATION,AUDIT}.md` plus 4 PUBLIC umbrella files,
direction verified before ingesting (`gh api` -> `visibility=public`, and all
four `git ls-files`-TRACKED, i.e. already published). 297 passages minted,
**25,226 of 25,226 members carry vectors — zero vectorless**, which was the
whole point of the model-on window. Embedder stopped and proven stopped;
`ollama serve` pid 9044 predates the session, is not ours, and was left running
(§11.4.174).

**Neither document is publishable yet, and not for a citation reason:** W3
reports all five documents' publication reviews STALE. The agent deliberately
refused to hand-write a review row, because decision #19 closed exactly that
path. That refusal is correct and is why step 3 below exists.

Doc 05's two survivors are genuinely uncitable, for different reasons:
**L230** cites gate RUN OUTPUT (transient measurements living in no artifact);
**L156** cites a statement that lives in `platform/gates/verify-server-unity.sh`
— a shell script, and **no shell-source ingest path exists**. That second one is
a real gap in the ingest surface: gate LOGIC lives in shell and nothing in the
corpus can cite it.

**Operator decisions taken 2026-09-09 on the above:** build a shell-source
ingest path for L156 and REWRITE L230 to what a durable artifact supports;
re-export the prebuilt bundle to the final generation; and run the producer/
verifier path to record fresh reviews. They carry a HARD ORDERING — a
shell-source ingest mints a new generation, which would immediately re-stale a
bundle exported to generation 8 — so they were given to ONE owner, sequenced.

## Second pass — 14 further decisions, 2026-09-09

Taken after the first twelve, on items this session's own work surfaced. Same
recording rule (§11.4.208).

| # | Item | Decision |
|---|---|---|
| 13 | Nothing committed since `e1de4d5` (75 umbrella files, 158 in `workshop`); decision #16 of 09-07 still PENDING | **Wait for every writer, then commit + push recursively.** Honours §11.4.84 quiescence. Submodules first, then the umbrella with gitlinks and `helix-deps.yaml` staged together or C9 correctly reports DRIFT |
| 14 | 3 of the 8 weakest evidence rows came back REFUTED | **Investigate the RULE that produced them first** — operator declined rewrite, correct-to-covered and withdraw |
| 15 | `plan-coverage-proposal.md` says 66 rows, the JSON says 49, and the gate exits 0 because it never reads the prose (§11.4.201 false-green) | **Fix the gate to read the prose, THEN regenerate the sheet** |
| 16 | 20 repositories left with Actions disabled; Pages ruled out for all of them, other consumers never checked | **Audit the 20 for NON-Pages consumers before declaring them safe** |
| 17 | Why the `milosvasic.ru` legacy Pages stream stopped, bounded to 3h45m on 2026-08-06/07 | **Close as permanently UNDETERMINED.** The evidence class needed (Pages settings-change history) does not exist for a user-owned repo. Stop carrying it as an open investigation |
| 18 | Does disabling Actions stop a `build_type=legacy` Pages build? UNCONFIRMED in both directions | **Test it deliberately, with a rollback ready** — on the live site, because it is the only legacy-Pages repo in a 229-repo org |
| 19 | Four 09-08 decisions recorded DECIDED with no completion evidence | **Execute all four**: #27 read the 182 unflagged bank questions · #16 audit the 264 citations · #24 author banks for areas 19/27/28 · #25 make the four `kg_*` kinds searchable |
| 20 | Content-boundary follow-ups after the direction subtraction shipped | **All four**: update the carriers · attribute the 1,138 UNDETERMINED rows · check subtracted rows against recall-cost class 1 · characterise the new `fingerprint` class |
| 21 | The coverage rule's two candidate fixes | **Fix A now, Fix C after review.** A is decision #14's precedent applied to the branch it was never applied to (1 row moves); C demotes the chance-level lane (6 rows move) |
| 22 | The 66 -> 49 arithmetic reconciles exactly but was never traced per row | **Trace the per-row correspondence, then regenerate** — an exact total can hide two offsetting errors |
| 23 | §11.4.65 vs §11.4.30: exports mandated but `.gitignore` ignores them, so a fresh clone is RED on arrival | **Track the exports — narrow `.gitignore`** |
| 24 | §11.4.65 protection 4: the docs-chain gate exists but no build path runs it | **Run waves 1+2 first, then wire it.** Wiring a red gate into pre-push blocks all work, and a gate people bypass with `--no-verify` is worse than no gate |
| 25 | Export-wave sequencing against a moving content-boundary corpus | **Wait for the CB agent, then run both waves** |
| 26 | The generation-8 bump and my mis-specified stop-rule | **Ratify the override.** See the ratification section above |

## The coverage rule — ROOT CAUSE FOUND, and it is a measurement

The rule scores two lanes against a 300-trial matched null; `covered` requires
**both**. Each lane was measured against the 7 recorded human `covered`
decisions (one-sided hypergeometric):

    lane        fires   captures human-covered   expected by chance   p
    transcript   7/49          4/7                     1.00           0.0049
    own-row      5/49          1/7                     0.71           0.55

**The transcript lane carries measurable signal about the human verdict. The
own-row lane's agreement is indistinguishable from chance — and it is a
mandatory conjunct, so a signal-free lane can veto the informative one.**

**Two distinct causes, not one, and the investigation refused to force one story:**

1. **`01M1SD6HJ78ZTKAXSW0185YKH8` (ch 02.01)** — decision #14's defect class,
   **uncorrected on the `covered` branch**. The rule measures the own-row lane as
   blind (`o_q_upper95 = 0.8618`), disqualifies it from CREATING a negative, and
   still lets it VETO a positive. **The guard exists, computes the right number,
   prints it, and is not consulted.**
2. **`...KCB` and `...KCC` (ch 02)** — blindness does NOT explain these; there
   `o_q_upper95 = 0.0099`, so the lane could see, looked, and did not
   corroborate. Its local reasoning is valid. The defect is one level up: the
   lane should not be a mandatory conjunct at all.

Excluded by measurement, not assumption: threshold and seed instability (across
four seeds only 2–3 of 49 rows move any lane's significance and `covered` stays
1 every time); a mid-p tie correction (changes nothing); chapter length (both
ch-02 rows sit in a 1206-segment chapter). Widening the own-row lane to a union
over all rows makes it **worse** (fires 1/49), so this is a redesign question,
not a tuning one.

**A claim was withdrawn mid-investigation**, and it is recorded because the
withdrawal is the quality signal: an intermediate finding that `covered` was
"physically unreachable for 44/49 rows" was **mislabelled** — it merely restated
the observed lane failure. Checked properly, a single own row carrying 1–2 of a
point's rarest terms would suffice everywhere. **There is no unreachability
theorem; there is an extreme power deficit.**

**No recorded human decision is contradicted by either fix.** All 7 human
dispositions are `covered`, so no rule change can overturn one — it can only
move rows toward or away from agreement.

## The 66 -> 49 divergence is EXPLAINED, and it reshapes the gate

    66  the sheet's population
   -11  decision #13 — ASR fragments naming no deliverable, retired as EXTRACTION
        DEFECTS (deliberately NOT as `dropped`, which would have entered them in
        the commitment ledger)
    -6  rows in `curriculum/plan-point-retractions.jsonl`
   ---
    49  the committed JSON

The sheet is **not wrong about a count** — it predates two retirement waves.
**Consequence for the gate being built:** a check asserting naive equality
between prose and JSON would report this as a divergence forever, or force the
prose to forget that 17 rows were deliberately retired. The honest assertion is
that the two agree **once the recorded retirements are accounted for** — the
gate reconciles through the retraction ledger and prints the reconciliation.
The rationale-code discrepancy (four in the prose, five in the JSON) is a
genuine divergence and is exactly what a total-only check would miss.
