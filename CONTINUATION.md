# CONTINUATION.md — vasic umbrella monorepo

<!-- The three fields below are MACHINE-READ by scripts/continuation-check.sh.
     Keep the exact `Field: value` shape. -->

    Last-Updated: 2026-09-01T22:30:00Z
    Synced-Commit: 562ecf9cca2d01beaf9ba8bde7474c465f0169ee
    Authority-Root: submodules/constitution

This file is the single canonical handoff document mandated by **Constitution
§12.10** ("Continuation document — sacred invariant"). Its binding requirements,
quoted from `submodules/constitution/Constitution.md`:

> 1. **`docs/CONTINUATION.md` MUST exist** at the project root. Its
>    absence is a release blocker.
> 2. **Every non-trivial state change** MUST update this document in
>    the same commit as the work itself.
> 3. **Top-of-file timestamp** is updated on every edit. Stale
>    timestamps trigger gate failure.
> 4. **Section §3 "Active work"** lists every IN PROGRESS / BLOCKED
>    item with enough detail that any agent can resume without
>    conversation context — concrete commands, file paths,
>    monitor IDs.
> 5. **Section §0 "How to use this document"** contains the verbatim
>    resumption prompt — a single block any operator can paste into
>    any CLI agent.
> 6. **Document MUST be self-contained.** No hyperlinks to ephemeral
>    external systems as the only source of truth.

**Path note (honest boundary, §11.4.6).** §12.10's protection 1 is internally
inconsistent: it names `docs/CONTINUATION.md` but requires it "at the project
root". This repository resolves that in favour of the **repository root** —
`CONTINUATION.md` — because that is where the file already existed (tracked
since commit `18c84ff`) and where all four governance carriers restate the rule
("`CONTINUATION.md` kept in sync"). No `docs/CONTINUATION.md` exists here; if
one is ever added, one of the two must become a pointer, not a rival.

---

## §0 How to use this document

Read this file **first**, before any other file in the repository. It is
self-contained: every fact below is reproduced here, not linked to.

Verify it is not stale before trusting it:

```bash
bash scripts/continuation-check.sh     # 0 = in sync · 1 = drift · 2 = undetermined
```

If that exits `1`, it names the drift. **Fix the drift before doing anything
else** — a stale continuation document is a §12.10 violation, and §12.10 has no
override flag.

### Verbatim resumption prompt (§12.10 protection 5)

Paste this block, unedited, into any CLI agent (Claude Code, Codex, Cursor,
Aider, Gemini CLI, Qwen Code, OpenCode, Crush, Kimi CLI):

```text
You are resuming work on the `vasic` umbrella monorepo.

1. Read CONTINUATION.md at the repository root, in full, before anything else.
2. Run `bash scripts/continuation-check.sh`. If it exits 1, that document is
   stale — reconcile it against the four governance carriers (CLAUDE.md,
   AGENTS.md, QWEN.md, GEMINI.md) and docs/constitution-adoption/INVENTORY.md
   before starting new work. If it exits 2, report what could not be determined
   and why; do not treat 2 as a pass.
3. Read CLAUDE.md (or the carrier for your agent: AGENTS.md / QWEN.md /
   GEMINI.md — they are byte-identical below their opening section). The
   authority it points at is the git submodule at `submodules/constitution/`,
   NOT the top-level `constitution/` used as an example in the constitution's
   own prose. Read anchors on demand, never eagerly:
     awk '/^### §12.10 /{f=1} f&&/^### §12.11 /{exit} f{print}' \
         submodules/constitution/Constitution.md
4. Binding rules you inherit unconditionally: no bluffing (every PASS carries
   positive evidence, §11.4); no guessing language — "likely", "probably",
   "seems", "appears" are forbidden when reporting causes (§11.4.6); every new
   gate ships with a paired mutation proving it catches regressions (§1.1);
   never force-push; hardlinked backup before any destructive operation (§9);
   keep CONTINUATION.md in sync in the SAME commit as the work (§12.10).
5. Two PRODUCTION websites are published from this tree. Do not disable
   `milosvasic.ru/.github/workflows/pages.yml` — it is the sole publish path
   for the live site. See §5 of CONTINUATION.md before touching any CI or
   deploy file.
6. Do not commit or push unless the operator asks. If asked, use the `commit`
   wrapper on PATH, never bare `git add` / `git commit` / `git push`. Note the
   wrapper runs `git add .` — check `.gitignore` first.
7. SpecKit feature 001 (`specs/001-workshop-curriculum-platform/`) has moved
   from planning into building, and none of it is committed yet — an untracked
   `workshop/pipeline/` tree and an untracked `analysis.md` exist. Claim no
   completion you have not measured. Host capability changed on 2026-09-01:
   a dual ASR stack (faster-whisper 1.2.1 + whisper.cpp v1.9.1, CPU-only) and a
   generative model (`qwen2.5:3b-instruct-q4_K_M`) ARE now installed, but the
   ASR engines live in `workshop/pipeline/venv`, NOT on the system `python3`.
   `/usr/bin/whisper` is still an unrelated GTK desktop app, not a transcriber —
   `command -v whisper` still proves nothing. Verify a capability before you
   plan around it. See §3 A1 and §5 H9.
8. Report the current §3 "Active work" items and ask which to take, unless the
   operator already told you.
```

Short one-line variant:

```text
Read CONTINUATION.md at the repo root, run `bash scripts/continuation-check.sh`,
then continue the §3 "Active work" items under the constitution mounted at
`submodules/constitution/`.
```

---

## §1 What this repository is

`vasic` is the umbrella monorepo for two personal/portfolio websites and the
shared tooling that builds, translates and validates them. It is not a
framework; the sites are git submodules and everything that generates or checks
them lives at the top level.

| Path | What it is |
| --- | --- |
| `vasic.digital/` | Site submodule — committed **static HTML**, no build step. |
| `milosvasic.ru/` | Site submodule — **Jekyll** source; rendered `_site/` is git-ignored. |
| `_tools/gen/` | **Go generator** (Go 1.26) that renders the localized pages for both sites. |
| `_tools/` | Translation (`translate/`), PDF (`pdf/`), portfolio (`portfolio/`) tooling + `deploy-langs.sh`. |
| `design-system/` | Shared per-brand tokens, fonts, icons, motion, component CSS. |
| `_tests/` | Playwright + self-validating harness (visual oracle, PDF/OCR export checks, link/sitemap integrity). |
| `_content/` | English source content. Per-language siblings are `_content_<lang>/`. |
| `scripts/` | Repo-level operational scripts, including the local gate runner and the governance verifiers. |
| `docs/constitution-adoption/` | The governance audit: `INVENTORY.md` (gap register G1–G12) and the §11.4.156 decision records. |
| `specs/001-workshop-curriculum-platform/` | SpecKit feature 001 — planning artifacts, plus an **untracked** `analysis.md`. Building has started, in an untracked `workshop/pipeline/` tree. Nothing is committed. See §3 item A1. |
| `submodules/containers/` | Owned submodule (`vasic-digital/containers`), added per §11.4.76 for the containerised workload feature 001 plans. **Nothing in this repository has been built or run in a container yet.** |

**Languages.** 14 translation trees exist: `ar be de es fa fr hi ja kk ko ru sr
tr zh`. `_tools/deploy-langs.sh` computes which are *complete* at run time from
its `LANGS` list and the document count — it does not trust a static list of
"shipped" languages.

**Submodules.** `.gitmodules` declares **13** gitlinks (re-measured 2026-09-01).
**11** are owned consumers of the governance cascade: `milosvasic.ru`,
`vasic.digital`, `design-toolkit`, `ai_interviewing`, `monetization`,
`workshop`, `submodules/containers`, `submodules/LLMProvider`,
`submodules/RAG`, `submodules/verdict` and `submodules/passage`.
`submodules/constitution` is the governance **source**
(the head of the cascade, not a consumer). `submodules/superspec` is
**third-party** (upstream `WangX0111/superspec`) and is outside the
owned-submodule set for tagging and propagation purposes.
`scripts/verify-governance-cascade.sh` derives all of this from `.gitmodules`
plus `helix-deps.yaml` — no roster is hardcoded anywhere, and C6 guards the two
files against each other in both directions.

**The earlier "9 gitlinks / seven owned" figure is WITHDRAWN, not restated.**
Four submodules joined on 2026-09-01: `submodules/LLMProvider` and
`submodules/RAG` were **adopted** under the §11.4.74 catalogue-check (reuse
before reimplement), and `submodules/verdict` and `submodules/passage` are
**newly created PUBLIC reusables** extracted from `workshop/`. All four are
**STAGED, not committed**, which is why `scripts/verify-manifest-pins.sh`
compares against the INDEX (`git ls-files -s`) rather than `HEAD` — it prints a
`NOTE` naming each as newly STAGED.

Gitlinks as they stand in the INDEX (`git ls-files -s`), each re-checked
against `git ls-remote <url> HEAD` on 2026-09-01. `scripts/verify-manifest-pins.sh`
independently reports **12 MATCH / 0 DRIFT / 0 UNDETERMINED of 12 declared
deps**, exit **0** — but note what that measures: it compares
`helix-deps.yaml`'s recorded `ref` against the **local gitlink**, not against
the remote. The two questions are different and only one of them is gated.
(12 deps, 13 gitlinks: `submodules/superspec` is carried as a third-party
comment in the manifest, not a `deps[]` entry, and C6 checks that both ways.)

| Submodule | Gitlink | Notes |
| --- | --- | --- |
| `submodules/constitution` | `f16ea779b82a757daf5e2af013ab4898beb9de1d` | match — **FAST-FORWARDED 2026-09-01** from `902979027a90` (0 divergent, 3 behind, `--ff-only`); `Constitution.md` is the same blob at both ends. Re-verified 2026-09-01: `git ls-remote` returns this exact sha. |
| `submodules/passage` | `80f65382007f11d461d8f3065efc3f0b9933b9a9` | match — **v0.2.0 PUBLISHED 2026-09-01** to both mirrors, verified by `git ls-remote`. STAGED, not committed. |
| `submodules/verdict` | `6e3026d737f85e48f136e0b917ceeab9d9e7698c` | **NEW 2026-09-01** — public reusable extracted from `workshop/`. STAGED, not committed. |
| `submodules/LLMProvider` | `36eb28eaf2d28e37ae7f961add0ca4518c427b92` | **NEW 2026-09-01** — adopted per §11.4.74. STAGED, not committed. |
| `submodules/RAG` | `be673d2c9a5122ae705b5b7e55397fbd4e70ec7d` | **NEW 2026-09-01** — adopted per §11.4.74. STAGED, not committed. |
| `submodules/containers` | `4dab992582666a64a4353cd593704cdc969aaa1e` | match |
| `submodules/superspec` | `c20ac6c1ba069cc9a72dacb8044b7b193d3dde81` | match — third-party, not a `deps[]` entry |
| `milosvasic.ru` | `8166fdba295dedc3114188c56e84248717ee7167` | match |
| `vasic.digital` | `0bc25012cc33202ced47788a9c301b6a9c15e192` | match |
| `design-toolkit` | `efd2c3fb2f880aaf2baf7f4819ce28a1ce3609cb` | match against the INDEX. The **working tree** is checked out at `5467a888…` (uncommitted local state, not a verdict input — the verifier says so). See the mirror warning below. |
| `ai_interviewing` | `5ef07e08f202f75f6c0a9d7eda193f6740a1a333` | match |
| `monetization` | `54ed7b0f5add52821d18866facb5ee8c75adef69` | match |
| `workshop` | `55076bf943a5158c91dede839ac319c43ddca1ab` | match |

**`design-toolkit` went PUBLIC on 2026-09-01, and its two mirrors do not
match.** The GitHub origin `vasic-digital/design-toolkit` was flipped **public**
after a clean full-history privacy audit; it ships **0** tracked workflow files
(`git ls-files '.github/workflows/*'`), so it creates no §11.4.156 CI surface.
Its **GitLab mirror is reported to remain private** and is measurably **5
commits behind**: GitLab HEAD `520c436c…` is a strict ancestor of GitHub HEAD
`5467a888…` (`merge-base --is-ancestor` TRUE; `rev-list --left-right --count` =
`0` / `5`), so this is lag, not divergence. Honest boundary (§11.4.6): this
checkout wires up **no** GitLab remote for it, so the *visibility* half is
UNVERIFIED from this tree and recorded as reported; the lag is measured. Do not
write as though the mirrors agree.

**Only THREE submodules are private now**, re-measured 2026-09-01 with
`gh api repos/<owner>/<name> --jq '.visibility'`: `milos85vasic/workshop_curriculum`,
`milos85vasic/ai_interviewing`, `milos85vasic/monetization`. Everything else —
including `design-toolkit`, `containers`, `LLMProvider`, `RAG`, `verdict`,
`passage`, both sites — is **public**. The "four private submodules" figure this
document and the carriers used to carry is withdrawn.

**The governance source was FAST-FORWARDED to its upstream head on 2026-09-01
on explicit operator authorization. The gap is closed; the hole that let it open
unnoticed is not.** `submodules/constitution` is now at `f16ea779b82a`, on
branch `main`, equal to
`git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD`.
Four measured findings:

1. **A true fast-forward, not a rebase.** `merge-base --is-ancestor pin remote`
   returned TRUE; `rev-list --left-right --count pin...remote` returned `0` /
   `3` — 3 behind, **0** divergent. The move used `git merge --ff-only`, which
   would have refused anything else. `902979027a90` was a local commit made in
   this checkout and is an ancestor of the remote head, so no local work was
   lost. **Nothing was pushed to the constitution repository.**
2. **No recorded anchor or line count in this repository went stale.**
   `Constitution.md` is the same git blob at both ends —
   `34eff9d86cadb325721c958d35a411feaad27681` — re-measured ON DISK AFTER the
   checkout at 11,700 lines and 252 `### §` anchors, so the "11,700 lines / 252
   anchors" figure in §2 describes the new pin unchanged. `diff --stat` touches
   only `design-toolkit` (1 +), `docs/codegraph/Status.md` (12 +) and the
   `submodules/design-toolkit` gitlink.
3. **`helix-deps.yaml` moved in the SAME change**, gitlink and manifest staged
   together — a bumped gitlink with a stale `ref:` is exactly what C9 catches.
   Re-measured after: `verify-manifest-pins.sh` exit **0**, 12 MATCH / 0 DRIFT /
   0 UNDETERMINED; `verify-governance-cascade.sh` exit **0**, 12 PASS / 0 FAIL.
4. **No gate catches local-vs-remote drift, and the bump did not change that.**
   C9 and `verify-manifest-pins.sh` compare the manifest to the **local
   gitlink**. Both exited **0** while the pin sat 3 behind, and both exit **0**
   now — they cannot tell the two states apart, so neither exit code is
   evidence about the remote.

**Upstream defect carried in, recorded and NOT fixed here:** `f16ea779b82a`
adds a second `design-toolkit` gitlink at the constitution's own ROOT alongside
`submodules/design-toolkit`, while its `.gitmodules` maps the entry named
`design-toolkit` to `submodules/design-toolkit` only — the root gitlink is
unregistered. Fixing it means committing to the constitution submodule, which
this repository does not do. The `design-toolkit` ref CONFLICT recorded in
`helix-deps.yaml` is **unchanged**: the constitution's own manifest says
`ref: 16e4e76` at both `902979027a90` and `f16ea779b82a`.

**Residual risk, exposed but not closed: any submodule here can sit arbitrarily
far behind its upstream — corpus changes included — with every gate green,
because C9 compares the manifest to the local gitlink and nothing compares the
gitlink to the remote. The bump closed one INSTANCE, not the CLASS.**

Re-derive without touching the submodule:

```bash
git -C submodules/constitution rev-parse HEAD
git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD
P="$(mktemp -d)/probe.git"
git clone --bare git@github.com:HelixDevelopment/HelixConstitution.git "$P"
PIN="$(git -C submodules/constitution rev-parse HEAD)"
REM="$(git -C "$P" rev-parse HEAD)"
git -C "$P" merge-base --is-ancestor "$PIN" "$REM" && echo 'fast-forward safe'
git -C "$P" rev-list --left-right --count "$PIN...$REM"
git -C "$P" diff --stat "$PIN" "$REM"
for R in "$PIN" "$REM"; do
    git -C "$P" rev-parse "$R:Constitution.md"
    git -C "$P" show "$R:Constitution.md" | grep -c '^### §'
done
```

The umbrella itself is pushed: `HEAD` = `562ecf9cca2d…` = `refs/heads/main` on
all three configured remotes (`github`, `origin`, `upstream` — all the same URL,
`git@github.com:milos85vasic/vasic.git`). That tip is the result of the
**2026-09-01 authorized history rewrite and force-push** (A9 below); the value
this line carried before, `ee3933d46211…`, names a commit that no longer exists
in this repository.

**Clone caveat.** Init the site submodules **non-recursively**:
`git submodule update --init vasic.digital milosvasic.ru`. `milosvasic.ru`
embeds a nested submodule (`Upstreamable`) whose `.gitmodules` is a broken
0-byte gitlink, so a recursive checkout of the umbrella fails.

---

## §2 Where the authority lives

All rules come from the constitution submodule. **This repository mounts it at
`submodules/constitution/`, not the top-level `constitution/` that the
constitution's own prose and templates use as their example.** Wherever a quoted
snippet says `constitution/<file>`, the file here is
`submodules/constitution/<file>`. `submodules/constitution/find_constitution.sh`
resolves either layout from any nested depth.

| What | Path |
| --- | --- |
| The universal constitution | `submodules/constitution/Constitution.md` |
| Claude Code carrier (upstream) | `submodules/constitution/CLAUDE.md` |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Parent-walk resolver | `submodules/constitution/find_constitution.sh` |
| Forbidden-command PreToolUse guard (present, **not wired** — see G12) | `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` |

Measured on the currently checked-out gitlink (`f16ea779b82a`; superseded pin
`902979027a90` carried the SAME `Constitution.md` blob
`34eff9d86cadb325721c958d35a411feaad27681`, so this figure did not move when
the pin did): `Constitution.md` is 11,700 lines / 1.7 MB and carries 252
`### §…` anchor headings (`wc -l`, `grep -cE '^### §'`).

**Inheritance form used here: the pointer block, not `@import`.** Anchor
§11.4.35 invariant 6 declares the two forms equivalent. This repository's four
root carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) each open with
`## INHERITED FROM submodules/constitution/CLAUDE.md`. The reason is cost: the
upstream carrier is 784 KB and `Constitution.md` is 1.7 MB, so a native import
would load roughly 165k tokens into every session before any work begins.

**Lockstep (§11.4.157).** The four root carriers must be byte-identical below
their opening section; only the opening section differs per agent. The
mechanical form of that rule used here is **line 19 to EOF**, which is what
`scripts/verify-governance-cascade.sh` C5 ROOT-LOCKSTEP measures. Measured
2026-09-01, after this revision's own carrier edits: all four are **831 lines**
and share the digest

    sha256(tail -n +19) = bef157d5a8992aaef4b0f52ad83f112f8407154ca6db386902365a6ef289874e

(prior digests, superseded and listed so a stale one is recognisable rather than
trusted: `bc945d409dfdea5f…` and `722d31ebbd30f863…` and `a1f3a936e0ff6817…`
earlier the same day — the first two under the tightened line-19 and the old
line-24 windows respectively — and
`792d878a3907c8491be99762005931c08ecf77b9ae3ee66ab139b7a1fb963939` at the
previous `Synced-Commit`. **A digest is only comparable to another taken with
the same window.**)

(re-derive: `for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do tail -n +19 "$f"
| sha256sum; done` — four identical lines, or the lockstep is broken).
**Any edit to one carrier must be applied to all four in the same commit.**

**C5 was TIGHTENED on 2026-09-01 and no longer splits at a hardcoded 24.** It
now measures where the four carriers actually converge and enforces from there,
and prints a NOTE stating the two agree:

> `C5 · declared split 19 equals the measured convergence line 19 — the gate
> enforces exactly the range it claims, with no ungated identical remainder
> (ceiling 24)`

That closed a real blind spot, and it is worth naming because this document
asserted the old form as recently as this revision's first draft: a line-24
window is a strict **subset** of the shared region, so the old C5 could pass on
carriers that differed at lines 19–23. Lines 1–18 are the per-agent opening
block. Measured by bisecting `tail -n +N | sha256sum` across the four: N=18
gives 4 distinct digests, N=19 gives 1. **Edit the shared region as ONE
artifact** — split the head off, edit the tail once, recompose — rather than
editing four files by hand and trusting a gate to catch the slip:

```bash
for N in 18 19; do
  printf 'from %s: ' "$N"
  for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do tail -n +$N "$f" | sha256sum; done \
    | sort -u | wc -l
done   # expect 4, then 1
```

The same lockstep rule applies *inside* every owned submodule, and is measured
separately by cascade check **C8** — which normalises the per-agent header
rather than splitting at a fixed line, because submodule carriers do not share
this root's header geometry. C8 passed for all **11** owned submodules on 2026-09-01
(the earlier "7" is withdrawn; the fleet grew the same day).

**Project overrides of universal rules: NONE.** In particular, do not propose an
`Override §11.4.156` — that rule names and refuses the exemption vocabulary
("No escape hatch — no `--allow-ci` … `--ci-exempt` flag"), and a consumer
carrier may only extend inherited rules, never weaken them. A **documented
deviation is not an override** and must never be written up as one.

---

## §3 Active work

Everything in this section was re-measured on 2026-09-01 against the live tree.
Statements of the form "X is done" name the command that produced the evidence.

### A1 — SpecKit feature 001: building has STARTED, nothing is committed

`specs/001-workshop-curriculum-platform/` is the only feature directory. Its
artifacts exist and were counted mechanically on 2026-09-01:

| Artifact | Measured |
| --- | --- |
| `spec.md` | 359 lines · **42** distinct `FR-###` ids (FR-001…FR-042) · **18** numbered success criteria (SC-001…SC-018) **plus** `SC-016a` = 19 criteria in total |
| `plan.md` | 311 lines |
| `research.md` + `research/` | 283 lines + 3 files (`transcription.md` 1249, `search-architecture.md` 837, `llm-bridging.md` 735) |
| `data-model.md` | 205 lines |
| `contracts/` | 3 files (`http-api.md` 1122, `pipeline-cli.md` 817, `passage-contract.md` 640) |
| `quickstart.md` | 1127 lines |
| `tasks.md` | 342 lines · **91** distinct `T###` ids |
| `checklists/requirements.md` | 120 lines |

**The claim this section used to carry — "`analyze`, `implement` and `review`
have NOT run … not one of its 91 tasks has been executed, no source file for
this feature exists outside `specs/`" — is WITHDRAWN.** Measured 2026-09-01:

- `specs/001-workshop-curriculum-platform/analysis.md` exists (15,555 bytes) and
  is **untracked** (`git ls-files` returns nothing for it).
- `git -C workshop status --short` shows an untracked `pipeline/` tree carrying
  real implementation — `run_faster_whisper.py`, `run_whispercpp.sh`,
  `build_whispercpp.sh`, `compare_engines.py`, `detect_media.sh`, `calibrate.sh`,
  `requirements.txt`, `CALIBRATION.md`, a built `venv/`, `engines/whisper.cpp`
  and 2.4 GB of `models/` — plus untracked `curriculum/`, `platform/`,
  `evidence/` and seven `docs/` pages.

**No completion claim is made, and none should be inferred.** Everything named
is UNTRACKED in both repositories, the work was in flight while this was
written, and **no task-by-task status was measured** — do not report any `T###`
as done on the strength of this paragraph. Nothing has been built or run in a
container. Re-derive before relying on any of it:

```bash
ls specs/001-workshop-curriculum-platform/
git -C workshop status --short
```

**Known internal inconsistency, not fixable from here.** `plan.md`'s own
`## Phase Status` section still reads "Phase 0 (Research): IN PROGRESS" and
"Phase 1 (Design & Contracts): NOT STARTED", while the Phase-1 artifacts
(`data-model.md`, `contracts/`, `quickstart.md`) exist and the same file carries
a "Post-design re-check (2026-09-01, after Phase 1)" block. That section is
**stale within `plan.md`**. It was deliberately not corrected: `specs/**` was
under concurrent edit by the analysis agent when this was measured, and editing
another agent's live working set is how two agents silently overwrite each
other. Whoever runs `analyze` next should reconcile it there.

**Where to resume:** `/speckit-analyze`, then `/speckit-implement`. Read
`tasks.md` first — T001 onward — and `plan.md`'s "Constitution Check" blocks,
which are the acceptance conditions the tasks were derived from.

**No longer blocked on host capability — see §5 H9.** The blocker this section
used to record ("**Neither is installed on this host**") is **WITHDRAWN**: a
dual ASR stack and a generative model were installed on 2026-09-01. Read H9
before planning around them — the ASR engines resolve only through
`workshop/pipeline/venv/bin/python`, not the system `python3`.

### A2 — G7 propagation: **CLOSED**, re-measured 44/44 (was 28/28, was 20/24)

`workshop/` onboarding, which was the open item at the previous
`Synced-Commit`, is **done**; `submodules/containers` was onboarded with it, and
four more submodules joined on 2026-09-01. Re-measured 2026-09-01 by
`bash scripts/verify-governance-cascade.sh`, exit 0 (12 PASS / 0 FAIL / 0 ENV /
8 NOTE):

- **C1** classified all **13** declared submodules from evidence — **11 owned**,
  1 governance source, 1 third-party — with no hardcoded roster.
- **C2** found all **11 × 4 = 44** owned-submodule carriers present and non-empty.
- **C3** found all 44 recognised by the canonical `is_pointer_carrier` predicate.
- **C5 ROOT-LOCKSTEP** found the four root carriers byte-identical from line 19
  down, shared digest `bef157d5a8992aae…`, plus a NOTE that the declared split
  equals the measured convergence line (see §2).
- **C6** found `helix-deps.yaml` and `.gitmodules` in agreement in both
  directions — 13 submodules = 12 `deps[]` + third-party comments.
- **C7** classified the 1 nested gitlink under the 11 owned submodules.
- **C8** found all 11 owned submodules internally in lockstep.

Independent spot-check: `workshop/{CLAUDE,AGENTS,QWEN,GEMINI}.md` are 118 lines
each and each opens with a real `## INHERITED FROM ` heading;
`submodules/containers/{CLAUDE,AGENTS,QWEN,GEMINI}.md` are 703 lines each and
likewise. **Every earlier count is superseded, not confirmed**, and the sequence
is kept because the reason each died is the lesson: "20/20" enumerated a
hardcoded five-submodule list; "20/24" was correct until `workshop` and
`containers` landed; "24/24" was 6 × 4, before `containers`; "**28/28**" was
7 × 4 and was correct on the MORNING of 2026-09-01, superseded the same day when
`LLMProvider`, `RAG`, `verdict` and `passage` joined. A "36/36" figure
circulating verbally was never measured and is wrong — 36 is 9 × 4, and the
owned fleet is 11. **Do not hand-derive this number; run the verifier and quote
what it prints.**

### A3 — Constitution sweep split: still not a settled number

`scripts/verify-all-constitution-rules.sh` discovers its gates dynamically. The
gate population moved 57 → 286 when the constitution was fast-forwarded, so
**every split published before that fast-forward is withdrawn and none is
comparable to a present-day run.** Do not restate an old number.

The most recent measurement available to this document is **186 PASS / 95 FAIL /
6 ERROR of 287 gates**. It is recorded here as a *reported prior measurement*,
not as something this revision observed to completion: a re-run started on
2026-09-01 was still executing when this document was written, so no fresh
split is claimed. Re-run it and record what you get.

The failures are known to include two classes that no commit this repository can
make will clear:
1. **Third-party and staged carriers** — `submodules/superspec/examples/…`,
   `milosvasic.ru/Upstreamable/…`, and the vendored spec-kit copy under
   `.specify/extensions/`. The cascade reports these as *known-unclearable* and
   excludes them from ITS verdict; the propagation-gate family inside the sweep
   still counts them as FAILs. Excluded there means **not double-counted, never
   suppressed**.
2. **Defects internal to the constitution submodule itself**, which is upstream
   code this repository consumes rather than owns.

Neither class is a reason to treat the sweep as green. **Where to resume:**
`bash scripts/verify-all-constitution-rules.sh`, then triage the FAIL list
against `docs/constitution-adoption/GATE-TRIAGE.md`.

### A4 — `scripts/audit-environment-assumptions.sh` — GREEN, then **RED again**

**Both verdicts are real and both are recorded, because the movement is the
point.** The 7 frozen GNU-vs-BSD assumptions this section originally carried —
6 in `scripts/verify-check-registry.sh` (GNU-only in-place `sed -i`,
`stat -c '%a'`) and 1 in `scripts/verify-manifest-pins.sh` — **were** fixed with
portable helpers by their owning agent, and the audit went **green (exit 0)** at
1763 files across 14 repositories, printing:

    ✅ no NEW frozen environment assumptions (441 justified occurrence(s) allow-listed)

**Re-measured later on 2026-09-01: exit 1, 10 frozen environment assumptions**,
scanning **1794 files across 14 repositories in 12 classes**. All 10 are inside
`submodules/LLMProvider`, which joined the owned fleet the same day and brought
its own occurrences into scope:

- `submodules/LLMProvider/pkg/providers/ai21/ai21_test.go` — 2 `MODEL`
- `submodules/LLMProvider/pkg/providers/openrouter/openrouter_test.go` — 5 `MODEL`
- `submodules/LLMProvider/scripts/prove-offline-discovery.sh` — 2 `ENDPOINT` +
  1 `MODEL`

**The coverage moved with the fleet on its own, with no edit to the audit.**
That is exactly what the fleet-derivation fix was for, so a red verdict earned
this way is the instrument working rather than a regression in this tree.

**Red is not the whole story either.** Read the rest of its output:

- **712 baselined occurrences** remain — declared, known, **unfixed** defects,
  printed on every run by design. A baseline is recorded debt, not a
  justification.
- **2 STALE allow rules of 405** — the occurrence each one names is GONE. A rule
  is an exemption at a PATH, not at an occurrence; recreate the occurrence or
  delete the rule.
- **1 frozen assumption inside a third-party gitlink** —
  `submodules/superspec/.github/workflows/ci.yml`, a pinned
  `python-version: "3.12"` — reported OUT OF SCOPE under §11.4.156(C) /
  §11.4.29 so it is never silently omitted. Not ours to fix.

**Where to resume:** the 10 new `submodules/LLMProvider` rows first — they are
in an owned submodule and are in scope — then the baseline, worked down file by
file, deriving behaviour (`sed -i.bak … && rm -f *.bak`, or `stat -c` with a BSD
`stat -f` fallback) rather than adding allow rows. Do not silence anything with
`2>/dev/null`, and do not clear the red by narrowing the scan.

### A5 — live-production specs: out of gate 6, **into deploy** (uncommitted)

Three specs left the pre-push set and are now claimed by the deploy step
instead. Measured 2026-09-01:

- `_tests/playwright.config.js` carries
  `testIgnore: /(restyle-seo-regression|v170-fixes|v171-hardcoding)\.spec\.js/`,
  so **gate 6 does not run them**.
- Those three specs contain **32 `test(...)` blocks and 97 `expect(` call
  sites** (`restyle-seo-regression` 13/40, `v170-fixes` 12/41,
  `v171-hardcoding` 7/16). The "86" figure in circulation is a different
  quantity — a Playwright **test-case pass count** ("86 passed / 2 failed")
  observed across the four-spec live suite, not a count of assertions in these
  three. Both numbers are real; they do not measure the same thing. Do not
  restate "86 assertions".
- They are claimed by `_tests/playwright.live.config.js`, whose `testMatch`
  names all four live specs.

**They ARE now wired into the deploy step — as of an UNCOMMITTED working-tree
change made by a concurrent agent on 2026-09-01.** `_tools/deploy-langs.sh` now
declares `LIVE_SPECS="all-languages-link-integrity restyle-seo-regression
v170-fixes v171-hardcoding"`, pre-flights each one's file, and runs the live
config with **no spec name on the command line** (line ~514), so the whole
`testMatch` set executes after a deploy. **At `HEAD` this is NOT yet true** —
`git show HEAD:_tools/deploy-langs.sh` still names
`all-languages-link-integrity.spec.js` alone (line 365). Until that working-tree
change is committed, a fresh clone gets the single-spec behaviour.

`playwright.live.config.js` was fixed in the same uncommitted change, and the
defect it closes is worth knowing: the config *claimed* four specs but supplied
environment for only three. `all-languages-link-integrity.spec.js` reads
`VD_BASE`/`MV_BASE` (defaulting to `localhost:8401`/`:8082`) while the other
three read `VASIC_BASE`/`MILOS_BASE` (defaulting to the production origins). With
no `webServer` and no `VD_BASE`, that spec hit a dead localhost, and its `get()`
helper turns a network throw into `last = 0`, so the refusal arrived at the
assertion as a status: `Error: sitemap.xml must resolve  Expected: 200
Received: 0`. A connection refusal laundered through an `expect()` and reported
as a production defect. All four origin variables are now derived from the
published `CNAME` files, explicit exports still winning.

The gate-6 deferral itself is sound and should not be reverted blindly: the
measured cause was runner reachability (12 `net::ERR_TIMED_OUT`, 8
`net::ERR_NAME_NOT_RESOLVED`, 5 `EAI_AGAIN`, 77 60-second `page.goto` timeouts,
and **zero** genuine assertion failures) while `curl` reached both sites with
`http=200`. Gating a push of undeployed source on public DNS is the defect. The
question was always *where* they run, not *whether* — and the answer landed:
after deployment, against what was actually shipped.

### A6 — `scripts/verify-check-registry.sh`: R5 FAIL cleared — **DONE**, debt is not

**The RED verdict this section used to carry is WITHDRAWN.** Re-measured
2026-09-01: **exit 0, 25 PASS / 0 FAIL / 5 DEBT / 0 UNDET / 0 NOTE.** The single
R5 anti-drift FAIL —

> `[R5] UNREGISTERED — scripts/verify-content-boundary.sh is under a declared
> scanroot but appears in no check, debt, or exempt row.`

— is gone: `scripts/verify-content-boundary.sh` is now **registered** as
`content-boundary` in `scripts/check-registry.tsv`, and the registry verifies
both halves of its contract (`SC-012` paired proof `--prove-failure` is a real,
non-trivial case arm; `SC-013` three-valued exit — `--root /nonexistent` → rc 2,
distinct from 0 and 1). Three real states were measured across the one day, and
all three are recorded rather than collapsed to the last: **0** at 21 PASS /
0 FAIL / 5 DEBT in the morning; **1** at 20 PASS / 1 FAIL / 5 DEBT once the
unregistered file appeared — R5 doing exactly its job; **0** at 23 PASS /
0 FAIL / 5 DEBT once it was registered; **0** at **25 PASS** / 0 FAIL / 5 DEBT
later the same day, as further checks — `submodule-remote-sync` among them —
landed and were registered. The PASS count moving 23 → 25 is R5 working, not
drift; quote the run, not this line.

**The FAIL is cleared. The 5 DEBT rows are not** — `constitution-rules-sweep`,
`lumen-index-doctor`, `ollama-tune`, `prepush-gates` and
`setup-agents-wizard-suite` still owe a §1.1 paired proof. The `prepush-gates`
row was NARROWED, not closed: three-valued exit is now satisfied
(`run_gate` has a distinct UNDET verdict for a child rc=2), and the earlier
claim that it maps every non-zero rc into FAILED is withdrawn. **Where to
resume:** §5 H11 — write the five missing paired proofs, then re-run with
`--run-proofs` (a plain run verifies proof *structure* only and says so) and
`--strict` to make debt block.

### A7 — constitution pin drift: measured, claim narrowed, gap still open

**Done (2026-09-01).** The four root carriers' "the pin is BEHIND its upstream"
block asserted two things that were measured and found wrong: that the
fast-forward question was **UNVERIFIED**, and that this repository's recorded
anchor and line counts describe the pin "not what upstream currently ships".
A **scratch bare clone** (`git clone --bare` into a temp dir — no fetch, no
checkout, no `git submodule update` inside `submodules/constitution`) measured:
`merge-base --is-ancestor 902979027a90 f16ea779b82a` **TRUE**;
`rev-list --left-right --count` = `0` / `3` (3 behind, 0 divergent);
`diff --stat` touches only `design-toolkit`, `docs/codegraph/Status.md` and the
`submodules/design-toolkit` gitlink; `Constitution.md` is the **same blob**
`34eff9d86cadb325721c958d35a411feaad27681` at both ends — 11,700 lines, 252
`### §` anchors, 1,779,401 bytes. The block was rewritten identically in all
four carriers (below-line-19 shared body; C5 ROOT-LOCKSTEP re-verified byte
identity from line 24 down) and in §1 and §5 H12 here.

**Pin BUMPED (2026-09-01), on explicit operator authorization — "Fast-forward
the pin".** Option (a) below was taken. The submodule was fetched and moved
`902979027a90` -> `f16ea779b82a` with `git merge --ff-only` (which would have
refused a non-fast-forward), on branch `main`, and the ancestry was re-verified
in the submodule itself before the move: `--is-ancestor` TRUE, `0` / `3`. The
`helix-deps.yaml` `constitution` `ref:` moved in the SAME change and both were
staged together, so C9 never saw a bumped gitlink against a stale ref.
Post-checkout re-measurement: `Constitution.md` blob still
`34eff9d86cadb325721c958d35a411feaad27681`, 252 anchors, 11,700 lines, sha256
unchanged. **Nothing was pushed to the constitution repository.** The
constitution's nested `submodules/design-toolkit` working tree was re-synced to
its recorded gitlink so the submodule is clean, as it was found.
`verify-manifest-pins.sh` 0 (12 MATCH / 0 DRIFT / 0 UNDET);
`verify-governance-cascade.sh` 0 (12 PASS / 0 FAIL / 0 ENV / 7 NOTE).

**The GAP is closed. The HOLE is now WATCHED, and the watcher is RED.** Until
2026-09-01 **no gate in this tree detected local-vs-remote submodule drift** —
C9 and `scripts/verify-manifest-pins.sh` compare `helix-deps.yaml` to the local
gitlink, and they exited **0** while the pin sat 3 behind and exit **0** now.
They cannot distinguish the two states, and never could; that is the reason a
second instrument was needed, and the reason a green manifest check is not
evidence about any remote.

**Option (b) is DONE.** `scripts/verify-submodule-remote-sync.sh` exists,
compares every declared gitlink to its remote (`git ls-remote` on the declared
branch, else `HEAD`), is three-valued so an unreachable remote is rc 2 and never
a pass, and is registered as `submodule-remote-sync` in
`scripts/check-registry.tsv` with a `--prove-failure` paired proof — which is
what R5 demanded.

**It exits 1, and the 1 is a real finding.** Measured 2026-09-01:
**6 CURRENT / 6 DRIFT / 0 UNDETERMINED of 12 owned gitlinks probed, 13
declared.** CURRENT: `milosvasic.ru`, `vasic.digital`, `monetization`,
`workshop`, `submodules/verdict`, `submodules/passage`. BEHIND and
fast-forwardable: `design-toolkit`, `ai_interviewing`, `submodules/containers`,
`submodules/LLMProvider`, `submodules/RAG`. DIFFERS:
**`submodules/constitution`** — remote HEAD `b9096acd98d2` against gitlink
`f16ea779b82a`; the difference is DETERMINED, the DIRECTION is **not**, because
the remote commit is not in this checkout's object store. The pin bumped this
morning is already behind again, which is the class this gate exists to make
visible.

**Where to resume:** the bumps themselves. Each one is an operator decision —
`--fetch` classifies the constitution's direction, and fetching is a mutating
command. **Do not silence the 1** by deleting the gate, allow-listing a
submodule, or bumping pins to make it green. Also unfixed and NOT ours:
`f16ea779b82a` adds an unregistered `design-toolkit` gitlink at the
constitution's own root; fixing it means committing to that submodule, which
this repository does not do.

### A8 — `submodules/passage` v0.2.0: **PUBLISHED**, breaking, consumer NOT updated

**Done (2026-09-01), on explicit operator authorization — "Publish v0.2.0 now".**
`submodules/passage` is now at `80f65382007f11d461d8f3065efc3f0b9933b9a9`,
annotated tag `v0.2.0` (tag object `a82f3cc2f8781ac8b2e969bb631eb6bddac89460`),
pushed to BOTH mirrors and verified on each **independently with `git
ls-remote`**, never from push output. The two remotes agree ref-for-ref.

**Tags are immutable (§11.4.113) and none was moved.** `v0.1.0`
(`e31e6fb` -> `c6e6938`) and `v0.1.1` (`992f5c2` -> `bde026f`) were read on both
remotes before AND after the push and are byte-identical. `v0.2.0` did not exist
anywhere beforehand; it is a new object, so the Go proxy has no prior answer for
it to contradict.

**What v0.2.0 is.** The library documented itself as project-not-aware in four
places while its API carried a consuming application's nouns in a struct field,
a JSON tag, a closed enum, two SQL columns and an index name. The old guard read
`go.mod` and never opened a source file of the package it vouched for.
Removed -> replacement: `ChapterSlug` -> `Scope`; `TStartS` -> `ScopeOrder`;
`TEndS` / `Speaker` / `SpeakerSource` -> the opaque `Attrs` map; type
`SpeakerSource` and `Kind`'s four constants deleted (`Kind` stays open, asserted
by AST); `SyncFile` now takes the consumer's `Kind`; `NewRegistry` and
`Unavailable` are variadic; `WithRecordValidator` added so consumer domain rules
run at the same write-path choke point. Schema v1 -> v2, stamped in
`PRAGMA user_version` with a foreign version REFUSED rather than migrated;
`passages_by_chapter` -> `passages_by_scope`; `LoadJSONL` sets
`DisallowUnknownFields`. Full mapping and upgrade procedure:
`submodules/passage/CHANGELOG.md`. Eight gates in
`pkg/passage/decoupling_test.go`, four with paired mutations (§1.1) observed to
fail. Verified at `80f65382` before tagging: `go build ./...` 0, `go vet ./...`
0, `go test -race -count=1 ./...` 0 at 45 PASS / 0 FAIL.

**NOT done — this is the resumption point.** The consumer
`workshop/platform/backend/internal/passagestore/` (1 modified + 2 new files)
is **uncommitted** and was NOT touched by this work. Nothing verifies the
consumer against the published v0.2.0 yet. The umbrella was deliberately **not
committed**: the gitlink and `helix-deps.yaml` are STAGED only, because other
agents were editing this tree concurrently.

**BLOCKED / NOT STARTED** — see §4. **G8** (markdown export mandate) and **G12**
(no `PreToolUse` guard wired) are open with no work in flight. **G4** will not
reach CLOSED from inside this tree; its remainder is operator-only. **G5**
remains PARTIALLY CLOSED — the wrapper exists, tracked git hooks do not.

**Background jobs.** A `scripts/verify-all-constitution-rules.sh` run was
started on 2026-09-01 and had not finished when this was written (see A3);
nothing else is recorded. `.lumen-reindex.log` at the root is the running record
for the semantic index. If an index rebuild or gate sweep is running when you
arrive, **do not kill it and do not restart ollama** — run
`bash scripts/lumen-index-doctor.sh` (0 healthy / 1 corruption / 2 could not
inspect) rather than assuming. Measured 2026-09-01, exit **0**: 2510 files fully
indexed, 0 queued placeholders, 59,059 chunks, **59,059 vectors of which 59,059
distinct**, 0 NaN/Inf, 0 all-zero, 0 off-norm, 0 ragged blocks,
`integrity_check: ok`. The duplicate-vector corruption previously tracked in
this file is cleared.

### A9 — content-boundary incident: **history REWRITTEN and force-pushed; NOT closed**

**Read [`docs/content-boundary-incident-2026-09-01.md`](docs/content-boundary-incident-2026-09-01.md)
before touching `docs/workshop-curriculum/RECON.md` or
`specs/001-workshop-curriculum-platform/research/transcription.md`.**

Private material from the notes PDF in the **private** `workshop` submodule was
committed and **pushed to this public repository** in `63ac4df` (2026-09-01
06:47 CEST) and was carried unchanged by `d0b3c64`, `96b2988` and `ee3933d`.
Three classes: verbatim prose, the PDF's complete section-heading list, and
**a third party's full real name** — personal data about someone who is not the
repository owner.

**Those four SHAs are deliberately left as written. They name a history that was
discarded on 2026-09-01 and they no longer resolve in this repository** — that is
the correct record, not an error to be silently repaired (§11.4.6). The old→new
mapping is in `docs/content-boundary-incident-2026-09-01.md` §8B.

**Done (2026-09-01, working tree only, nothing committed):** both files
redacted — quotes replaced by verified-distant paraphrase, heading lists
replaced by counts, the name removed everywhere, content-boundary callouts
added to both. Verified independently at a **six**-word shingle window (stricter
than the gate's eight): **zero prose overlap remains**; the only surviving
overlap is the artifact's own filename, which carries a first name only and is
the accepted baseline.

**DONE (2026-09-01, AUTHORIZED, EXECUTED): the history rewrite and force-push.**
The operator gave explicit per-session §11.4.113 authorization. `git filter-repo`
replaced the four leak-bearing blobs across the four affected commits keyed on
`blob.original_id`; `refs/heads/main` moved `4df8401 → 562ecf9` on the single
public remote via `--force-with-lease` (a deliberately wrong lease was refused
first, as the §1.1 paired mutation). Verified afterwards: **51 of 51 disclosed
literals absent from all 6,230 blobs** under `--batch-all-objects`, the tree at
`HEAD` **6,260 of 6,260 entries byte-identical**, all **13 gitlinks** and all
**102 historical gitlink pairs** unchanged, all **4 tags** unchanged, commit
identity envelope identical for all **104** commits, **98 of 104** SHAs
unchanged, `git fsck` clean with **0 unreachable / 0 dangling**. Full record with
measurements: `docs/content-boundary-incident-2026-09-01.md` §8B.

**STILL NOT CLOSED, and this is the part that matters.** A force-push does not
delete anything from GitHub's storage. The four orphaned commits and all four
leak blobs remain **fetchable by SHA** from `github.com/milos85vasic/vasic` by
anyone who recorded them, until GitHub runs a server-side garbage collection —
whose timing is not the repository owner's to control. Ending the exposure needs
a **GitHub Support purge request** (text prepared at incident note §8A.7, first
changed commit `63ac4df32e5f… → fc7574b27c7f…`) and, ahead of it, **telling the
third party**. Both are outward-facing and are the **operator's** to send; no
agent has taken or may take either. Forks, mirrors, existing clones and
search/archive caches are unreachable by any of this.

**Two instrument gaps this incident exposed, both OPEN:**
`scripts/verify-content-boundary.sh` matches on an **eight-word** window, so it
**cannot see** a five- or six-word heading (it scored the heading list in
`transcription.md` clean) and **cannot see a bare personal name** at all. It
found the verbatim-prose class only. This leak was caught by a human-directed
audit, not by the gate. Do not read a green run as "no private material here".

**The gate is now REGISTERED and exits 1 BY DESIGN.** It is
`content-boundary` in `scripts/check-registry.tsv`, with a `--prove-failure`
paired proof and a three-valued exit (`--root /nonexistent` → rc 2), and the R5
FAIL it caused is cleared (§3 A6). Re-measured 2026-09-01 it exits **1** and
prints:

```
LEAK — 285 surviving match(es) (prose 207, short 35, name 43); 0 row(s) also could not be determined
```

**The figure this section used to carry — `LEAK — 10293 surviving match(es)
(prose 203, short 8535, name 1568)` — is WITHDRAWN, not restated.** It was a
MID-TUNING snapshot taken while the detector was still being rewritten, so it
measured the detector's own noise floor rather than this tree. **The two numbers
are not a before/after of any cleanup: nothing was redacted between them.** The
`short` class fell 8535 → 35 and the `name` class 1568 → 43 because the detector
learned to subtract keys already public in two or more public repositories,
public git identity forms, a scale-free name-frequency floor (33 occurrences
over 1,325,759 prose tokens = 25 per million) and path-reference matches — each
subtraction printed on every run with its RECALL COST stated, so what the gate
can no longer see is visible rather than assumed.

The **207 prose** matches are the judged class. Honest boundary (§11.4.6): §9 of
the incident note assessed **232** matches — 29 redacted, 203 judged not to be
disclosures — so 207 and 203 are close but are **not the same set**, and the
difference is not accounted for here. Do not read 207 as "207 rows individually
cleared". They are left **visible rather than allow-listed**, deliberately: an
allow-list entry buys a green exit by hiding the row from the next reader.
`.content-boundary-allow` carried 9 declared pairs at that measurement,
pardoning 4193 matches. **Do not force this gate green.** A gate a human must
read is worth more than one that is quietly green.

**A second wave WAS assessed, and partly remediated.** The "~200+ further
matches" sourced from `ai_interviewing/` and `workshop/` that this section
previously deferred are §9 of the incident note: **232 assessed, 29 redacted as
real disclosures, 203 judged not to be.** The remaining out-of-scope material —
`design-toolkit/`-sourced matches in `_analysis/`, `_content/products/` — is
affected by `design-toolkit` having gone **public** on 2026-09-01, which changes
the boundary question for that source but has **not been re-assessed**. Not
decided; do not treat the flip as retroactive clearance.

> **Comparing gate runs across this window is unsound.** Another agent was
> concurrently building `workshop/platform/**` inside the private submodule, so
> the private corpus the gate indexes changed between runs and the derived
> exoneration sets moved with it. The attributable figure is the per-source one:
> matches sourced from the notes PDF went **29 → 0**, and `RECON.md` went
> **42 → 13** (−29 exactly), with the residual 13 all `ai_interviewing`-sourced.

**Operator-only manual steps** that no script here can perform are recorded in
`MANUAL-STEPS.md`.

### A10 — two carrier sets corrected in lockstep — **DONE**, nothing committed

**Done (2026-09-01).** Two four-file governance carrier sets carried claims that
were measurably false when re-derived. Both were corrected as ONE artifact each,
by a single script applying byte-identical replacements to all four members, so
the four cannot drift apart. **Nothing was committed or pushed**; other agents
were editing this tree concurrently.

**Set 1 — the four ROOT carriers.** Lockstep boundary measured at **line 19**
(`tail -n +18` gives 4 distinct digests, `tail -n +19` gives 1), which is what
C5 ROOT-LOCKSTEP declares and enforces, with a ceiling of 24. What was false and
what replaced it:

| Claim | Re-derived |
| --- | --- |
| `LEAK — 10293 surviving match(es) (prose 203, short 8535, name 1568)` | `LEAK — 285 surviving match(es) (prose 207, short 35, name 43)`, rc 1. The old figure was a MID-TUNING snapshot of the detector, not a state of this tree; **nothing was redacted between the two numbers**. |
| `audit-environment-assumptions.sh` → **0**, "no NEW frozen assumptions" | **1** — 10 frozen assumptions, all in `submodules/LLMProvider`; 1794 files / 14 repos / 12 classes; 712 baselined; 2 stale allow rules of 405 |
| `verify-check-registry.sh` → 0 at **23** PASS | 0 at **25** PASS / 0 FAIL / 5 DEBT / 0 UNDET / 0 NOTE |
| "no gate compares a gitlink to its remote … that is not started" | `scripts/verify-submodule-remote-sync.sh` exists, is registered with a paired proof, and exits **1** at 6 CURRENT / 6 DRIFT / 0 UNDETERMINED |
| the constitution pin "equal to `git ls-remote … HEAD` as measured that day" | still true **as of that measurement only** — the remote has since moved to `b9096acd98d2` and the gitlink now DIFFERS |

Three figures on the correction list turned out **NOT** to be stale and were
left as they stood, each re-derived rather than assumed: `.gitmodules` declares
**13** gitlinks; the cascade reports C2/C3 at **44/44** (11 owned × 4); and
`verify-governance-cascade.sh` exits **0** at 12 PASS / 0 FAIL / 0 ENV / 8 NOTE.

**Set 2 — the four `workshop/` carriers.** Lockstep boundary measured
**empirically and it is NOT line 19**: the per-agent tokens sit at lines
**1, 3, 9, 20, 42 and 51**, so a `tail`-based test converges only at line 52.
That is why cascade check C8 normalises the per-agent header instead of
splitting at a fixed line — the workshop set has no single split point. Two
false claims were corrected:

1. *"derives its root from `git rev-parse --show-toplevel`"* — false, and
   **`show-toplevel` was the DEFECT, not the drift**. It answers for the
   CALLER's cwd, so a run from a parent repository resolved the root to the
   umbrella; `extract-videos.sh` broke exactly that way. Every script now
   anchors on `${BASH_SOURCE[0]}`. The only two remaining call sites are
   `scripts/git-hooks/post-commit` and `post-checkout`, where git guarantees the
   cwd and the caller-relative answer is correct.
2. *"a teaching corpus, not a software product"* — no longer true. Measured
   2026-09-01 the module ships `pipeline/` (two CPU-only ASR engines,
   faster-whisper 1.2.1 / CTranslate2 4.8.2 and whisper.cpp v1.9.1),
   `curriculum/` (a real chapter-01 transcript and exercise document plus an
   825 KB `passages.jsonl`), `platform/` (a Go backend with five commands, an
   Angular frontend, four `verify`/`prove` gate pairs — **serving** on
   `http://127.0.0.1:8087` at the time of measurement), and a 16-script control
   plane. *"No absolute path is hardcoded anywhere in the module"* was
   re-derived and **still holds**.

Preserved verbatim in the workshop set because each is still true and
load-bearing: the conditional-inheritance preamble and its `find_constitution.sh`
resolver (the §11.4.28(B) / §11.4.35 contract — not touched), the video-archive
pipeline description and its scripts, and the five module-local rules. A sixth
rule was ADDED: chapter and `curriculum/` content never leaves the module as
content, only by path.

**Where to resume:** nothing is owed by this item. The three gates it names —
`verify-governance-cascade.sh`, `continuation-check.sh`,
`verify-content-boundary.sh` — were re-run after the edit and are recorded in
§6.

---

## §4 Open gaps

Gap identifiers are `docs/constitution-adoption/INVENTORY.md`'s own (G1–G12).
The **current status** of each lives in the four root carriers, not in
`INVENTORY.md` — the inventory headings preserve the original discovery text and
were not rewritten as gaps moved. `scripts/continuation-check.sh` compares the
table below against every carrier that mentions the gap and fails on any
disagreement.

| Gap | Status | What is actually missing |
| --- | --- | --- |
| G3 | CLOSED | §11.4.32 sweep contract: both halves exist and run. `scripts/verify-governance-cascade.sh` supplies step 1 with a `--prove-failure` paired mutation; the step-1 caller distinguishes rc=1 (violation) from rc=2 (broken check) instead of collapsing both to FAIL. Step 1 re-measured 2026-09-01: **12 PASS / 0 FAIL / 0 ENV / 8 NOTE, exit 0** — grown from 10 checks to 12 by the addition of **C8** (in-submodule carrier lockstep) and **C9** (manifest pin sync). Note this closes the *contract*, not the sweep's verdict — for the sweep's own PASS/FAIL split see §3 A3. |
| G4 | PARTIAL | §11.4.156. **Umbrella root complies**: `.github/workflows/ci.yml.disabled` is inert, enforcement is the local pre-push hook. **Will not reach CLOSED** — file-level disabling cannot reach provider-side settings (org-default required workflows, branch-protection required checks, the Pages source setting), which are operator-only and unverified. `milosvasic.ru` keeps an ACTIVE `pages.yml` as a documented deviation; `vasic.digital` is non-compliant at the provider level with no file-level remedy. |
| G5 | PARTIALLY CLOSED | The commit **wrapper** exists (`commit` on PATH → `$SUBMODULES_HOME/Upstreamable/commit` → `Software-Toolkit/Utils/Git/commit.sh` + `push_all.sh`, driven by the tracked `upstreams/GitHub.sh`). What is still missing is git **hooks** as a tracked, travelling artefact. The wrapper runs `git add .` — keep `.gitignore` accurate before using it. |
| G6 | CLOSED | `helix-deps.yaml` exists at the root and parses under `yaml.safe_load`. |
| G7 | CLOSED | Constitution-aware governance carriers across the owned submodules. **44 of 44**, re-measured 2026-09-01. Fleet DERIVED from `.gitmodules` + `helix-deps.yaml`, never hardcoded: **eleven** owned submodules (`milosvasic.ru`, `vasic.digital`, `design-toolkit`, `ai_interviewing`, `monetization`, `workshop`, `submodules/containers`, `submodules/LLMProvider`, `submodules/RAG`, `submodules/verdict`, `submodules/passage`), each carrying all four carriers, each opening with a real `## INHERITED FROM ` heading and each accepted by the canonical `is_pointer_carrier` predicate. `bash scripts/verify-governance-cascade.sh` exits **0** — C1/C2/C3/C5/C6/C7/C8 all PASS — which is the closure condition this row previously named. **Every earlier figure is WITHDRAWN, not restated:** "20/20 CLOSED" (a hardcoded five-submodule list that missed `workshop`); "20/24" (correct at the time, superseded when `workshop` and `submodules/containers` landed); "24/24" (6 × 4, before `containers`); "**28/28**" (7 × 4, correct on the morning of 2026-09-01, superseded the same day when `LLMProvider`, `RAG`, `verdict` and `passage` joined). A "36/36" figure circulating verbally was never measured and is wrong — 36 is 9 × 4 and the owned fleet is 11. Run the verifier; do not hand-derive. |
| G8 | OPEN | The §11.4.65 markdown/export mandate is unmet across the repository. |
| G12 | OPEN | No `PreToolUse` guard is wired. `.claude/settings.json` declares only `enabledPlugins`; the canonical guard script sits unused at `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh`. |

**Not listed above:** G1, G2, G9, G10, G11 are not carried in the carriers'
"Known open gaps" list. G1 (no consumer governance layer) and G2 (no inheritance
pointer) are answered by the four root carriers existing. G9, G10 and G11 have
**no verified current status recorded anywhere in this tree** — do not report
them as closed, and do not report them as open, without re-auditing
`docs/constitution-adoption/INVENTORY.md` first. G11 (`design-toolkit` checked
out twice — at the root and under `submodules/constitution/submodules/`) is
still *described* in `helix-deps.yaml` around its `design-toolkit` entry, with
the two-command re-derivation recipe; that description is not a status.

**Where a gap status is authoritative.** Four places record gap statuses and
they are ranked, because they are not equally current:

1. **The four root carriers** (`- G<n> — <STATUS>` lines) — authoritative.
   `scripts/continuation-check.sh` C4 fails if any of them disagrees with the
   table above, so these two can never silently diverge.
2. **This §4 table** — authoritative, mechanically tied to (1).
3. **`Constitution.md` §"Adoption gap register"** — the project constitution's
   own G1–G12 table. It is NOT machine-compared to (1); treat a disagreement as
   a defect in (3) and fix it there.
4. **`docs/constitution-adoption/INVENTORY.md`** — a dated forensic record of
   the 2026-08-26 discovery pass. Its G-headings preserve the ORIGINAL evidence
   and are deliberately not rewritten as gaps move; a "current status ledger"
   block at the head of its §8 carries the live statuses instead. **Never quote
   an INVENTORY G-heading as a current status.**

**Do not claim this repository passes a constitutional gate you have not
actually run. Do not treat the absence of a gate as a pass.**

---

## §5 Operational hazards

**H1 — Two live production websites are published from this tree.** Operator
directive, standing: *"Make sure all pages websites work flawlessly! No website
can be broken! All websites we have here are running deployed in production!"*

**H2 — `milosvasic.ru/.github/workflows/pages.yml` is ACTIVE and must stay
active.** `gh api repos/milos85vasic/milosvasic.ru/pages` returns
`build_type: "workflow"` — that workflow is the **sole** publish path for
`https://milosvasic.ru/`. There is no `gh-pages` branch, no `docs/` folder, and
the repository root is Jekyll **source** (Liquid + front matter), so it cannot
be served raw from a branch. `_tools/deploy-langs.sh` is **not** a substitute:
it generates, commits and pushes *source*, then `sleep`s waiting for the server
to rebuild — the rebuild it waits for **is** that workflow. It was renamed to a
`.disabled` name once, on 2026-08-27, and reversed the same day before anything
was committed or pushed. **Do not disable, rename, or "fix" it.** It is a known,
documented **deviation** from §11.4.156 taken for uptime — never an override.

**H3 — `vasic.digital` is non-compliant at the provider level with no file-level
remedy.** Its Pages source is `build_type: "legacy"`, so every push triggers a
provider-side `pages build and deployment` Actions run even though the tree
contains **zero** workflow files (verified: `vasic.digital/.github/workflows/`
does not exist). Nothing in that repository can change this.

**H4 — There is no server-side CI at this umbrella root, and the hook does not
travel.** `.git/hooks/` is not tracked by git, so a **fresh clone runs no gates
at all** until `bash scripts/pre-push-gates.sh --install` is run. `git push
--no-verify` bypasses the hook with **no record**. At `Synced-Commit` the hook
is installed in this working tree (`.git/hooks/pre-push` present, executable) —
that fact does not travel with a clone. Run the gates by hand until you have
confirmed the hook is in place.

**H5 — No hardcoded absolute paths, ever.** 18 tracked files once hardcoded the
original author's macOS external-volume prefix, which pointed at nothing on
every other checkout. `_tools/deploy-langs.sh` uses `set -uo pipefail` *without*
`-e`, so its `cd "$ROOT"` failed silently and the script carried on in the
caller's working directory — then committed and pushed both site submodules.
`scripts/audit-hardcoded-paths.sh` (gate 0) is the guard. Derive roots; never
write them literally. `.hardcoded-paths-allow` is the only exemption list and is
deliberately one entry long.

**H6 — Do not force-push.** Force-push requires explicit per-session
authorization AND a green §9.1.5 post-op gate. Take a hardlinked backup before
any destructive operation (§9).

**H7 — Use the commit wrapper.** No direct `git add` / `git commit` / `git push`
on the main repository. The wrapper stages everything untracked (`git add .`).

**H8 — A test once stayed green while the thing it tested was deleted.** Assert
against observed state, never against the presence of a string. Every new gate
ships with its paired mutation (§1.1). Two measured instances of the same class,
both now fixed, both worth remembering because each looked correct on a casual
reading: (a) gate E enforced §11.4.156 **only at the umbrella root** —
`git ls-files` sees a gitlink as ONE entry, so an active `pages.yml` in
`milosvasic.ru` and an active `ci.yml` in `superspec` both passed the gate;
(b) `audit-hardcoded-paths.sh` and `audit-environment-assumptions.sh` scanned
**zero files inside the 9 submodules declared at the time**. All three now derive
the fleet from `.gitmodules` + `helix-deps.yaml` — which is why their coverage
moved with the fleet on its own when four submodules were added on 2026-09-01
(the environment audit reported **14 repositories** that day, with no edit to
the audit). A blind instrument reports PASS.

**H9 — Host capability CHANGED on 2026-09-01. Two claims this hazard used to
carry — "NO ASR engine" and "NO generative model" — are WITHDRAWN, not
restated.** Re-measured on the development host after the installs:

- **A dual ASR stack IS installed — inside a project venv, not on the system
  interpreter.** Both target the same model family; neither needs a GPU.
  - **faster-whisper 1.2.1** on **CTranslate2 4.8.2** in
    `workshop/pipeline/venv` (Python 3.14.6), weights at
    `workshop/pipeline/models/ct2/faster-whisper-large-v3-turbo` (1.6 GB).
    Installed from **prebuilt wheels**; `torch` is **not** present even there,
    and is not needed.
  - **whisper.cpp v1.9.1**, built **CPU-only** at
    `workshop/pipeline/engines/whisper.cpp`, binary `build/bin/whisper-cli`,
    model `models/ggml/ggml-large-v3-turbo-q8_0.bin` (834 MB).
- **The system `python3` still has no ASR engine, and that distinction is the
  whole hazard.** `faster_whisper`, `whisper`, `vosk`, `transformers` and
  `torch` are all still **absent** from `python3`'s import path; the engine
  resolves only through `workshop/pipeline/venv/bin/python`. A probe that runs
  bare `python3` will conclude there is no transcriber, and be wrong.
- **`/usr/bin/whisper` EXISTS and is still a trap — unchanged and still
  load-bearing.** It is a GTK desktop notification client (a Python/GObject
  application, GPL, © 2023 Lorenzo Paderi), **not** an ASR engine.
  `command -v whisper` succeeding proves nothing — and it now succeeds on a host
  that genuinely HAS a transcriber, which makes the trap **worse**: the name on
  `PATH` still resolves to the wrong program. Any capability probe that tests
  only for the name on `PATH` will report an engine that is not there while
  missing the two that are.
- **A generative model IS available.** `ollama list` holds **three** models, not
  two: `qwen2.5:3b-instruct-q4_K_M` (1.9 GB, **generative**, pulled 2026-09-01)
  alongside the two **embedding** models `ordis/jina-embeddings-v2-base-code`
  and `jina-embeddings-code-cpu` (323 MB each). What a 3B q4 instruct model is
  fit FOR is a separate question this hazard does not answer.
- `podman` is present, `docker` is **absent**; the images on this host belong to
  unrelated projects. Nothing for this repository has been built or run in a
  container.

Re-derive rather than trusting the list — this hazard has now been wrong in each
direction, once each:

```bash
ollama list
command -v podman docker
python3 -c 'import faster_whisper'                       # expect ModuleNotFoundError
workshop/pipeline/venv/bin/python -c 'import faster_whisper, ctranslate2; \
  print(faster_whisper.__version__, ctranslate2.__version__)'
git -C workshop/pipeline/engines/whisper.cpp describe --tags
workshop/pipeline/engines/whisper.cpp/build/bin/whisper-cli --help | head -3
```

Record what you install before relying on it; do not let a plan assume it.

**H10 — Live-production coverage moved, and the move is UNCOMMITTED.**
Three specs (32 `test()` blocks, 97 `expect()` call sites) are deferred out of
gate 6 by `testIgnore` in `_tests/playwright.config.js`. The working tree wires
them into `_tools/deploy-langs.sh` via `LIVE_SPECS`, so they run after a deploy
— but **`HEAD` still names `all-languages-link-integrity.spec.js` alone**, so
until that change is committed a fresh clone runs those three **nowhere**.
Full detail in §3 A5. Until it lands, run
`cd _tests && npx playwright test --config=playwright.live.config.js` by hand
before any release.

**H12 — No gate in this tree detects local-vs-remote submodule drift.**
`submodules/constitution` was fast-forwarded `902979027a90` -> `f16ea779b82a`
on 2026-09-01, so that particular pin now matches its remote. **The hazard is
unchanged**, because it was never about that one pin: cascade check C9 and
`scripts/verify-manifest-pins.sh` both compare `helix-deps.yaml` to the **local
gitlink**, never to the remote, so a submodule can sit arbitrarily far behind
its upstream — corpus changes included — with every gate green. Both exited 0
while the pin was 3 behind AND both exit 0 now; they cannot tell the two states
apart, which is precisely why neither exit code is evidence about any remote.
Full detail in §1.

**H11 — Registered DEBT is visible, not resolved.**
`scripts/verify-check-registry.sh` prints **5 DEBT** rows on every run — by
design, so a known gap can never go quietly green. Re-measured 2026-09-01 it
exits **0** at 23 PASS / 0 FAIL / 5 DEBT / 0 UNDET, and **that zero is not a
clean bill**: it means "every registered check is accounted for", **not** "every
check has a paired proof". The run states this itself — *"Proof STRUCTURE was
verified; no paired proof was EXECUTED."* (The R5 anti-drift FAIL recorded here
earlier is cleared — see §3 A6.) Four scripts owe a §1.1 paired proof
(`verify-all-constitution-rules.sh`, `lumen-index-doctor.sh`, `ollama-tune.sh`,
`pre-push-gates.sh`) and one owes both proof and a three-valued exit
(`test-setup-agents-wizard.sh`). The `pre-push-gates.sh` row was **narrowed**:
its three-valued contract is now satisfied (`run_gate` has a distinct UNDET
verdict for a child rc=2, the summary prints `undetermined=` as its own counter,
and an UNDET run blocks WITHOUT accusing the tree), so only the proof is owed.
Re-run with `--strict` to make debt block, and with `--run-proofs` to actually
EXECUTE the proofs.

---

## §6 Gates — how to run them

There is **no active workflow at this root**. The definitions are preserved,
inert, in `.github/workflows/ci.yml.disabled`; the runnable replacement is
`scripts/pre-push-gates.sh`. Run from the repository root.

| Gate | Command |
| --- | --- |
| E | `git ls-files \| grep -E '^\.github/workflows/.*\.ya?ml$\|^\.gitlab-ci\.yml$'` (must be EMPTY) |
| 0 | `./scripts/audit-hardcoded-paths.sh` |
| 1 | `cd _tools/gen && go test ./...` |
| 2 | `bash _tools/audit-hardcoding.sh` |
| 3 | `bash _tools/translate/reproducibility-selftest.sh` |
| 4 | `bash _tools/portfolio/self-validate.sh` |
| 5 | `bash _tests/run-harness-selfvalidation.sh` |
| 6 | `cd _tests && npx playwright test --project=chromium --grep-invert 'all-language'` |

Run them all at once, and manage the hook:

```bash
bash scripts/pre-push-gates.sh              # run every gate (exit 0 = push OK)
bash scripts/pre-push-gates.sh --list       # print the gate table, run nothing
bash scripts/pre-push-gates.sh --install    # write the untracked .git/hooks/pre-push shim
bash scripts/pre-push-gates.sh --uninstall  # remove that shim
```

Switches: `PREPUSH_VERBOSE=1` (stream output live), `PREPUSH_SKIP_SLOW=1` (skip
gate 6 with a printed reason), `PREPUSH_STRICT=1` (treat every SKIP as a
FAILURE — use before a release or a §11.4.40 pre-tag sweep), `PREPUSH_ONLY="E 0
1"` (run only the listed ids). There is deliberately **no** switch that skips
gate E.

Gates 5 and 6 SKIP with a stated reason when `_tests/node_modules` or the built
`milosvasic.ru/_site` is absent. **A SKIP is reported loudly and is not a pass.**

Gate 6 no longer runs three live-production specs; they moved to
`_tests/playwright.live.config.js`. They **are** wired into deploy in the
working tree, and **are not** at `HEAD` — see §3 A5 and §5 H10. Until that
change is committed this is the one place where coverage left the automated set,
so run the live config by hand before any release.

Governance sweeps and audits (not part of the pre-push set). Every one is
three-valued: **0 = in sync / clean · 1 = a real finding · 2 = COULD NOT
DETERMINE, which is never a pass.** Results below are from 2026-09-01 on this
working tree:

| Command | Measured |
| --- | --- |
| `bash scripts/continuation-check.sh` | this document is not stale; `--prove-failure` runs its paired mutation |
| `bash scripts/verify-governance-cascade.sh` | **0** — 12 PASS / 0 FAIL / 0 ENV / 8 NOTE (C0–C9) |
| `bash scripts/verify-manifest-pins.sh` | **0** — 12 MATCH / 0 DRIFT / 0 UNDETERMINED of 12 declared deps |
| `bash scripts/verify-check-registry.sh` | **0** — 25 PASS / 0 FAIL / 5 DEBT / 0 UNDET / 0 NOTE. The R5 FAIL recorded earlier is cleared; the 5 DEBT rows are not (§3 A6, §5 H11). Zero here means "accounted for", not "proved". |
| `bash scripts/audit-hardcoded-paths.sh` | **0** — no machine-specific paths; 6 files explicitly allowed |
| `bash scripts/audit-environment-assumptions.sh` | **1** — RED again: **10 frozen assumptions**, all in `submodules/LLMProvider`, which joined the fleet the same day; 1794 files / 14 repos / 12 classes. **712 baselined** occurrences, **2 stale allow rules of 405** and 1 third-party out-of-scope finding also print. See §3 A4. |
| `bash scripts/verify-content-boundary.sh` | **1** — RED **BY DESIGN**: `LEAK — 285 surviving match(es) (prose 207, short 35, name 43)`. The prose rows are the judged class, left visible rather than allow-listed. The old `10293 / 203 / 8535 / 1568` figure was a mid-tuning snapshot and is withdrawn. See §3 A9. **Do not force it green.** |
| `bash scripts/verify-submodule-remote-sync.sh` | **1** — a REAL finding, not a designed one: 6 CURRENT / 6 DRIFT / 0 UNDETERMINED of 12 owned gitlinks probed, 13 declared. The only instrument here that looks at a remote at all. See §3 A7. |
| `bash scripts/verify-provider-ci.sh` | not run in this pass — 2 means UNVERIFIED, not a pass |
| `bash scripts/verify-all-constitution-rules.sh` | run started, did not finish; see §3 A3 |
| `bash scripts/lumen-index-doctor.sh` | **0** — index healthy, 59,059/59,059 distinct vectors |

`scripts/verify-governance-cascade.sh` is §11.4.32 step 1 and supports
`--prove-failure`. `scripts/verify-manifest-pins.sh` is cascade check **C9**
re-derivable standalone. `scripts/check-registry.tsv` is the registry
`scripts/verify-check-registry.sh` enforces, documented in
`docs/check-registry.md`; its R5 anti-drift rule means **a new `*.sh` under
`scripts/` fails the registry until it is registered as a check, a debt, or an
exemption** — register it when you add it.

Toolchains the gates expect on `PATH`: Go 1.26, Node 20, Ruby 3.3 + Bundler,
poppler-utils, tesseract-ocr. Playwright additionally needs `npm ci` and
`npx playwright install chromium` inside `_tests/`, and a built
`milosvasic.ru/_site`.

**Deploys** are driven by `bash _tools/deploy-langs.sh` — it regenerates EN plus
every complete language into both site submodules, commits and pushes each site
only when something changed, then validates the LIVE sites. `--dry-run` previews
without committing. Its exit codes: `0` deploy completed and live validation
passed (or was explicitly skipped); `1` deploy completed but the live validator
found broken links; `2` deploy completed but the live validator could not run.

---

## §7 How this document is kept honest

A hand-written status file goes stale the moment it is written. This one is
machine-checked:

```bash
bash scripts/continuation-check.sh          # 0 in sync · 1 drift · 2 undetermined
bash scripts/continuation-check.sh --list   # print every check, run none
bash scripts/continuation-check.sh --prove-failure   # paired §1.1 mutation proof
```

It verifies, against the live tree rather than against its own text: the §12.10
structural requirements above; that the `Synced-Commit` is a real ancestor of
`HEAD`; that no commit since `Synced-Commit` touched a watched governance file
**without** also touching this document (§12.10 protection 2, mechanically); that
every gap status in §4 agrees with **every** carrier that mentions that gap
(§11.4.157 lockstep folded in); that every `*.sh` this document names exists,
and is executable when §6 invokes it directly; that §12.10 still exists under
that anchor name in the mounted constitution; and that the §5 production facts
(root CI inert, `pages.yml` present, `vasic.digital` workflow-free) still hold.

**Follow-up owed at the previous `Synced-Commit`: DISCHARGED.** All four root
carriers once contained the sentence "There is also no `CONTINUATION.md` at this
root yet…", which had become false. It has been replaced in all four, in
lockstep, with a paragraph pointing at this file and at
`scripts/continuation-check.sh`. Verified 2026-09-01: `grep -c 'There is also
no ' CLAUDE.md AGENTS.md QWEN.md GEMINI.md` → 0 in each, and cascade check C5
ROOT-LOCKSTEP reports one shared line-24-to-EOF digest across all four.

**Follow-up owed at THIS revision.** Two items, both stated so they cannot be
quietly dropped:

1. **The staged submodules must land with this document.** Four gitlinks
   (`LLMProvider`, `RAG`, `verdict`, `passage`), `helix-deps.yaml` and the four
   carriers are staged or modified but **not committed**. `verify-manifest-pins.sh`
   checks the INDEX precisely so they are gated meanwhile, but the counts in §1
   and §4 describe the index, not `HEAD`. Until the commit lands, `git ls-tree
   HEAD` and this document disagree — by design, and only until then.
2. **`design-toolkit`'s GitLab mirror is 5 commits behind and its visibility is
   unverified from this tree.** §1 records both. Push the mirror or record why
   not; and if the mirror is meant to be private while the origin is public,
   that asymmetry needs a decision, not a footnote.

Still open and unchanged from earlier revisions: **no gate detects
local-vs-remote submodule drift** (§5 H12), and the `design-toolkit` mirror lag
above is a live instance of exactly that class — no gate in this tree saw it;
it was found by hand.

**When you change anything non-trivial, update this document in the same
commit** (§12.10 protection 2) and refresh `Last-Updated` and `Synced-Commit`
(protection 3). `scripts/continuation-check.sh` will tell you when you forgot —
C3 walks `git log` from `Synced-Commit` to `HEAD` and names any commit that
touched a watched governance file without also touching this document. The
watched set is `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`, `README.md`,
`helix-deps.yaml`, `docs/constitution-adoption/INVENTORY.md`,
`scripts/pre-push-gates.sh`, `.github/workflows/ci.yml.disabled`. Note what that
implies: `Constitution.md` and `specs/**` are **not** watched, so a change there
will not be caught mechanically — update this document by hand when you touch
them.

**Honest boundary on this revision (§11.4.6).** It was written without
committing anything, so `Synced-Commit` above still points at `HEAD`
(`562ecf9cca2d…`, re-verified) while this document sits modified in the working
tree. That is the intended pre-commit state and it makes C3 pass, but it also
means **the very next commit must carry this document with it** or the guarantee
is void.

This revision touched **only** the four root carriers and this file. Three other
agents were active in the tree while it was written, and their working sets were
deliberately NOT touched: `scripts/**` (the content-boundary gate's author),
`specs/**` and `workshop/**` (the feature-001 build),
`docs/content-boundary-incident-2026-09-01.md`, `helix-deps.yaml` and
`.gitmodules`. **Every measurement above was taken from the WORKING TREE, not
from `HEAD`**, and several of the things measured are themselves uncommitted —
four staged submodule gitlinks, an untracked `analysis.md`, an untracked
`workshop/pipeline/`, an uncommitted `_tools/deploy-langs.sh`. A figure here can
therefore be true of this checkout and false of a fresh clone. Re-run the
commands rather than quoting the numbers.

The four carriers were edited as **one shared artifact**, not four files: the
per-agent head (lines 1–18) was split off, the shared tail edited once, and the
four recomposed and proved byte-identical from line 19 before anything was
written. C5 ROOT-LOCKSTEP re-verified afterwards, one shared digest
`bef157d5a8992aae…`.

One caution, learned the hard way inside this very revision: **C5 itself moved
mid-session.** Its window was tightened from a hardcoded line 24 to the measured
convergence line 19 by a concurrent agent, between the first cascade run and the
last, which invalidated a digest this document had already recorded. When you
quote a gate's output, quote the window as well as the number — and re-run the
gate after any session in which another agent touched `scripts/`.
