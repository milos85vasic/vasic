<!--
SYNC IMPACT REPORT — .specify/memory/constitution.md
====================================================
Version change: 1.0.0 → 1.1.0  (MINOR)

Bump rationale: two new principles added and several sections materially expanded.
No principle was removed or redefined, so this is not MAJOR. The changes are more
than wording, so it is not PATCH.

Modified principles:
  - (no renames)
  - "Evidence-Based Claims"      — expanded with the measured-not-asserted rule
  - "Isolation by Default"       — expanded with the no-vacuous-gate rule
  - "Comprehensive Documentation"— expanded; CONTINUATION.md now EXISTS (386 lines)

Added principles:
  + "Honest Instruments"         — a check that cannot run reports neither pass nor fail
  + "Environment Adaptability"   — no frozen assumption about the host

Added sections:
  + "Governance" (amendment procedure, versioning policy, compliance review)
  + "Local Gate Suite" (the 8 registered pre-push gates)
  + "Verification Scripts" (the governance/adaptability instrument inventory)

Corrected factual errors carried from v1.0.0:
  ! "11,101 lines, 261 anchors" → measured 11,700 lines, 252 anchors at pin 90297902
  ! submodule fleet was implicit → now 8 declared, enumerated
  ! Testing Strategy listed 5 commands → the local gate runner registers 8 (E, 0-6)

Templates requiring updates — verified by reading each, not assumed:
  NOTE: TWO plan templates exist. `setup-plan.sh` resolves the superspec one, not
  the core one. An earlier draft of this report named only the core template; that
  was wrong and is corrected here rather than silently amended.
  ✅ .specify/extensions/superspec/templates/plan-template.md (the one actually
     resolved) — its Constitution Check is a table of generic
     `[Principle N from constitution]` rows, so the two new principles slot in with
     no template edit required.
  ✅ .specify/templates/plan-template.md (core, not resolved here) — its
     Constitution Check is the placeholder line
     `[Gates determined based on constitution file]`; principle-agnostic, no edit.
  ✅ .specify/templates/spec-template.md   — 0 constitution references; no change needed.
  ✅ .specify/templates/tasks-template.md  — 0 constitution references; no change needed.
  ✅ README.md                             — already carries the CI/local-gate notice.

Follow-up TODOs: none. No placeholder tokens remain (verified: 0 matches for
`[ALL_CAPS]` tokens).
-->
---
version: 1.1.0
ratified: '2026-08-26'
last_updated: '2026-08-31'
---

# vasic Constitution

This project constitution EXTENDS the universal Helix Constitution mounted at
`submodules/constitution/`. It never weakens or overrides an inherited clause — where the two
disagree, the submodule wins. Measured at pin `90297902`: **11,700 lines, 252 anchors**.

## Core Principles

### Evidence-Based Claims

Every assertion MUST be backed by verifiable evidence. Never guess, assume, or fabricate.
Constitution §11.4 applies — no bluffing, no speculation disguised as fact.

A claim measured on one member of a set is NOT a claim about the set. Enumerate the set from its
authoritative source rather than from a hand-written list; a hardcoded list silently goes stale
the moment the set grows. When a number is reported it MUST be a count of things that were
listed, never a line count from a text search.

When a previously stated figure turns out to be wrong, it MUST be withdrawn explicitly rather
than quietly replaced, and the reason recorded.

### Honest Instruments

A check that cannot run MUST report that it could not run. It MUST NOT report success, and it
MUST NOT report failure. Three states are mandatory and distinct:

- `0` — the condition was checked and holds
- `1` — the condition was checked and is violated
- `2` — the condition could NOT be checked

Collapsing state 2 into state 1 makes a broken tool accuse a healthy codebase. Collapsing it into
state 0 makes a broken tool certify code nobody inspected. Both are release blockers. A missing
credential, an unreachable service, a saturated backend, or a crashed helper are all state 2.

Rationale: this exact conflation has been found and fixed four separate times in this repository
— in the index doctor's exit contract, in the constitution sweep's step-1 handling, in the deploy
script's live-link validator, and in the governance cascade verifier. It is the most frequently
recurring defect class here, which is why it is a principle rather than a style note.

### Governance Fidelity

All governance carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) MUST stay in lockstep
— byte-identical below their per-agent header. The constitution submodule is the single source of
truth; no carrier may weaken or override a universal clause.

Every owned submodule MUST carry the four carriers, each opening with a real, non-fenced
`## INHERITED FROM ` pointer heading (§11.4.35 invariant 6). The fleet is DERIVED from
`.gitmodules`, never hardcoded: **8 submodules are declared** — `submodules/constitution` (the
governance source), `submodules/superspec` (third-party, out of scope per §11.4.156(C)), and six
owned: `milosvasic.ru`, `vasic.digital`, `design-toolkit`, `ai_interviewing`, `monetization`,
`workshop`.

### Isolation by Default

Mutation-paired gates catch regressions. Every new gate MUST have a paired mutation proving it
FAILS when the thing it guards is broken. A gate that has never been observed failing is not
known to work.

An assertion that greps a file for a string is not a test — it checks that code *mentions*
something, not that it *does* it. Such an assertion stays green while the behaviour it claims to
cover is deleted. Assertions MUST execute the behaviour and check the observable result.

A mutation proof that exercises only sandboxed copies can go green over an instrument that cannot
start at all; proofs MUST include at least one case that runs the real entry point end to end.

No naked writes — every destructive operation requires a hardlinked backup first (§9).

### Comprehensive Documentation

`CONTINUATION.md` exists at the repository root and MUST be updated in the same commit as any
non-trivial state change (§12.10). `scripts/continuation-check.sh` enforces this mechanically and
is three-valued per **Honest Instruments**.

Every architectural decision is recorded. Honest boundaries — gaps are stated openly, never
hidden. A document that states a status MUST name the command that re-derives it, so the reader
can tell a current fact from a stale one.

### Environment Adaptability

No file in this repository may freeze an assumption about the machine it runs on. Paths, service
managers, package layouts, CPU and memory limits, model names, vector dimensions, endpoints,
ports, container runtimes and GPU vendors MUST be DERIVED at run time, with an environment
variable available to override the derivation when detection is wrong.

A tuned value MUST be computed from measured host facts and MUST print its inputs so the
arithmetic can be audited. A recommendation that returns the same number regardless of the host
has failed this principle even when the number happens to be right.

`scripts/audit-environment-assumptions.sh` enforces this class. Its allow-list entries each carry
a `REASON:` or `BASELINE:` comment; a baseline is a recorded debt, never a justification, and
baselined files are printed on every clean run so the tree can never go quietly green over known
breakage.

Rationale: this repository has been bitten repeatedly — a hardcoded macOS path in a deploy script
that pushes to production, a distro-specific service config path, an i915-only log pattern that
would report "0 faults" forever on AMD hardware, and a GNU-vs-`ugrep` difference that silently
broke a test assertion on this very host.

### Quality Over Speed

60% RAM cap on heavy work. TDD where possible. Lint and typecheck before claiming done. No
shortcuts that compromise integrity.

Never edit a shell script while it is executing — bash reads scripts lazily and a live edit makes
the running shell execute garbage. Never commit while another agent is writing; a blind
`git add .` has already been caught about to roll back three submodule pins and to re-introduce a
cyclic gitlink that had been deliberately removed.

## Project Structure

The vasic umbrella monorepo owns two personal/portfolio sites, a curriculum module, and shared
tooling:

- **vasic.digital/** — committed static HTML served as-is (no build step)
- **milosvasic.ru/** — Jekyll source; rendered `_site/` is git-ignored; self-publishes on push
  via `.github/workflows/pages.yml` (ACTIVE, do not disable)
- **workshop/** — workshop curriculum; chapter recordings stored as size-bounded split parts
- **ai_interviewing/** — curriculum reference implementation: Go backend + Angular frontend,
  run as a native binary (`platform/bin/aicur`). It defines **no containers**.
- **_tools/gen/** — Go generator rendering localized pages for both sites
- **design-system/** — shared per-brand tokens and component CSS
- **_tests/** — Playwright plus self-validating harness
- **_content/** — English source; `_content_<lang>/` siblings for translations
- **submodules/constitution/** — the universal constitution (see measurement above)

Toolchains, measured on this host: Go 1.26.2, Node 22.19.0, npm 10.9.3, Ruby 3.3.8,
Python 3.14.6, ffmpeg/ffprobe 7.0.2, podman + podman-compose (**docker is absent**),
poppler-utils, tesseract-ocr.

## CI/CD Policy

Remote CI is disabled at the umbrella root per §11.4.156. `.github/workflows/ci.yml` is renamed
to `ci.yml.disabled`; enforcement is a local pre-push hook:

```
bash scripts/pre-push-gates.sh --install
```

The hook MUST be installed on fresh clones — `.git/hooks/` is not tracked by git, so a fresh
clone has zero enforcement until that command is run, and `git push --no-verify` bypasses it.
This cost is stated plainly rather than buried.

**milosvasic.ru** keeps its active deploy workflow (`pages.yml`) as a **documented deviation**
for production uptime. It is NOT an override — §11.4.156 forbids overrides ("No escape hatch"),
and it must never be written up as one. Verified basis: the GitHub Pages API reports
`build_type: "workflow"`, making that workflow the sole publish path.

**vasic.digital** is non-compliant at the **provider** level with no file-level remedy: it
triggers `pages build and deployment` runs on every push while containing zero workflow files.

File-level disabling cannot reach provider-side settings. Their CURRENT status is measured on
demand by `scripts/verify-provider-ci.sh`, not asserted here.

**No new CI may be added.** Introducing an active workflow is a release blocker.

## Local Gate Suite

`scripts/pre-push-gates.sh` registers 8 gates. A SKIP is never a PASS; `PREPUSH_STRICT=1`
converts skips to failures for release use.

| ID | Gate |
|----|------|
| E  | §11.4.156(E) — no active root CI config tracked |
| 0  | hardcoded path audit |
| 1  | Go unit tests (`_tools/gen`) |
| 2  | hardcoding audit (builds the Go generator) |
| 3  | HelixTranslate reproducibility self-test |
| 4  | portfolio §1.1 data-integrity self-validation |
| 5  | harness self-validation (§11.4.170 visual + §11.4.168 export) |
| 6  | Playwright chromium, excluding the all-language crawl |

## Verification Scripts

Governance and adaptability instruments. Each is three-valued per **Honest Instruments**.

| Script | Verifies |
|---|---|
| `scripts/verify-all-constitution-rules.sh` | full constitution gate sweep |
| `scripts/verify-governance-cascade.sh` | §11.4.32 step 1 — carriers cascade to every owned submodule |
| `scripts/continuation-check.sh` | CONTINUATION.md has not gone stale (§12.10) |
| `scripts/audit-hardcoded-paths.sh` | no machine-specific absolute paths |
| `scripts/audit-environment-assumptions.sh` | no frozen host assumptions |
| `scripts/verify-provider-ci.sh` | provider-side CI triggers that file checks cannot see |
| `scripts/ollama-tune.sh` | local inference concurrency, derived from host facts |
| `scripts/lumen-index-doctor.sh` | semantic index integrity |

## Testing Strategy

Run the full local suite via `bash scripts/pre-push-gates.sh`. The individual commands:

```bash
cd _tools/gen && go test ./... && cd -        # Go unit tests (generator)
bash _tools/audit-hardcoding.sh               # hardcoding audit
bash _tools/translate/reproducibility-selftest.sh
bash _tools/portfolio/self-validate.sh
bash _tests/run-harness-selfvalidation.sh     # harness self-validation
```

Playwright (chromium) requires `npm ci` and `npx playwright install chromium` inside `_tests/`,
plus a built `milosvasic.ru/_site`.

## Deploys

Driven by `bash _tools/deploy-langs.sh`. Regenerates EN plus every complete language into both
site submodules, commits and pushes each site only when something changed, then validates live
sites. `--dry-run` previews without committing.

It stages an explicit path list rather than everything, and ABORTS when unrelated changes are
present, so a deploy cannot sweep unrelated work into a production commit. Its live validator
distinguishes "found broken links" from "could not run the validator" per **Honest Instruments**.

## Governance

**Authority.** The universal constitution in `submodules/constitution/` is authoritative for
every topic. This document extends it with project-specific facts and discipline. Any conflict
resolves in favour of the submodule.

**Amendment procedure.** Amendments are made by running `/speckit-constitution`, which MUST:
re-measure every factual claim before restating it; record a Sync Impact Report at the top of
this file; propagate consequences to the Spec Kit templates and runtime guidance docs; and leave
no unexplained placeholder tokens. A factual correction MUST be called out in the report rather
than silently applied.

**Versioning policy.** Semantic versioning of governance:

- **MAJOR** — a principle is removed, or redefined in a backward-incompatible way.
- **MINOR** — a principle is added, or guidance is materially expanded.
- **PATCH** — clarifications, wording, typo and factual corrections that change no rule.

**Compliance review.** The local gate suite is the enforcement point; there is no server-side
check. Before a release or a tag, run the full sweep plus the verification scripts above, and
record the result. An unrunnable check is reported as such — never as a pass. Claims of
compliance require the command output that demonstrates it.
