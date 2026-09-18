# HelixQA integration — design

**Status:** approved by operator, 2026-09-18 (chat approval of the design summary; this document is the written record per the brainstorming skill's architectural path).

## Why

The Helix Constitution's §11.4.160 ("Vision-verified recording + HelixQA bridge mandate")
requires every project it governs to run generated/served content through an
anti-bluff QA framework named HelixQA, with automated read-the-screen
verification before evidence is accepted. This umbrella (`vasic`) has never
actually added that framework — investigated 2026-09-18 and confirmed there is
no `helixqa` submodule anywhere in `.gitmodules` or `helix-deps.yaml`. The only
artifact with that name is `_tests/helixqa/`, a plain directory of static
test-bank documents scoped to `vasic.digital`/`milosvasic.ru`, not a submodule
and not the framework the constitution describes.

Separately, this session found and fixed six real, user-visible bugs in
`workshop` and `ai_interviewing` (dotted-slug routing 404s, mislabeled error
codes, a 403 shown as an outage, an unstyled button, etc.) through ad-hoc
Playwright crawls run by fanned-out subagents. That worked, but it is not
durable: nothing runs it automatically, nothing enforces it as a gate, and
nothing reviews model-generated content before it is served. The operator
asked for this scanning to become a **mandatory validation/verification
step**, for HelixQA to be used "as much as possible" to achieve it, and for
all model-generated content to go through review by independent specialized
agents before being considered done.

## What already exists (do not rebuild)

`https://github.com/HelixDevelopment/qa` is a real, mature Go project
(module `digital.vasic.helixqa`) already implementing almost exactly what
§11.4.160 asks for:

- YAML test banks (`banks/`, `challenges/`), platform-targeted
  (android/androidtv/web/desktop), priority-tagged.
- A CLI (`cmd/helixqa`: `run`, `list`, `report`, `autonomous`, `version`).
- Real-time crash/ANR detection per platform (`pkg/detector`).
- Step-by-step validation with **evidence collection** — screenshots, video,
  logcat, stack traces (`pkg/evidence`, `pkg/session`).
- **`pkg/issuedetector`** — LLM-powered bug detection across visual, UX,
  accessibility, and functional categories.
- **An autonomous QA session mode** — LLM agents + a `VisionEngine` navigate a
  running app, verify documented features against it, explore undiscovered
  areas, and produce a QA report (Markdown/HTML/JSON) with video evidence
  linked by timestamp. This is the vision-verification bridge §11.4.160 asks
  for, already built.
- Web platform support goes through Playwright (`pkg/navigator`).
- Markdown ticket generation shaped for AI fix pipelines (`pkg/ticket`).

It declares two sibling-submodule dependencies via `go.mod` replace
directives (per its own CONST-051(C) rule: it must not nest its own copies of
these — the *consuming* project adds them):

- `digital.vasic.challenges => ../challenges` — confirmed as
  `github.com:vasic-digital/challenges.git` (`git ls-remote` succeeds).
  Provides the test-execution/reporting foundation HelixQA is "built on".
- `digital.vasic.containers => ../containers` — **already satisfied**. This
  umbrella's existing `submodules/containers` (`vasic-digital/containers`)
  has `module digital.vasic.containers` in its own `go.mod`; no new
  dependency needed.

It also declares a long list of `tools/opensource/*` nested submodules
(scrcpy, allure2, leakcanary, docker-android, appium, midscene, mem0,
moondream, ui-tars, perfetto) — these back its **Android/mobile** testing
paths (device control, crash symbolication, emulator provisioning). Neither
`workshop` nor `ai_interviewing` is a mobile app; both are served web
applications. Initializing these submodules is explicitly OUT of scope for
this integration — `git submodule update --init` will target only
`submodules/qa` and `submodules/challenges` themselves, never their own
nested `tools/opensource/*` tree. If a future project under this umbrella
needs Android/mobile QA, that is a separate, explicitly-scoped decision.

## Scope of this integration

1. **Add two new submodules** at the umbrella root, alongside the existing
   `submodules/containers`:
   - `submodules/qa` → `git@github.com:HelixDevelopment/qa.git`
   - `submodules/challenges` → `git@github.com:vasic-digital/challenges.git`

   Both go through the same process every other owned submodule in this
   umbrella already went through: `.gitmodules` entry, `helix-deps.yaml`
   entry with a real `ref` and a `why`, `scripts/verify-manifest-pins.sh`
   and `scripts/verify-governance-cascade.sh` re-run to confirm the fleet
   stays green, `scripts/install_upstreams.sh` (if that's how this umbrella
   wires push remotes — verify against the existing pattern before assuming).

2. **Build the `helixqa` binary** from the new submodule (`make build` per
   its own README, or the umbrella's equivalent build wrapper) and confirm
   it runs (`helixqa version`) before writing any test banks.

3. **Write real YAML test banks** for `workshop` and `ai_interviewing`,
   `--platform web`, covering at minimum the same surfaces this session's
   ad-hoc Playwright crawls already covered by hand (every chapter/tab in
   workshop, every module/practice/plan page in ai_interviewing, both seeded
   accounts) — this converts one-off manual crawling into a durable,
   re-runnable asset. Test-bank authoring itself is TDD-shaped: write a bank
   entry, confirm it fails against a known-broken state (or a deliberately
   reverted fix from this session, as a golden-bad control), confirm it
   passes against the current, fixed state.

4. **Wire HelixQA into the mandatory validation path.** Exactly how depends
   on what `workshop`'s and the umbrella's own pre-push gate machinery
   already look like (both have one: workshop's `platform/gates/verify-*.sh`
   family, the umbrella's `scripts/pre-push-gates.sh`). Add a new gate (or
   extend an existing one) that runs `helixqa run --banks <path>
   --platform web` against the live, loopback-bound server and fails the
   push on a real finding — mirroring every other gate in this tree's
   three-valued contract (0 clean · 1 real defect · 2 could not determine,
   never silently downgraded).

5. **A new Claude Code skill, `independent-content-review`, for the
   review-dispatch step** (separate from
   HelixQA itself, per the operator's explicit choice on this point during
   brainstorming). HelixQA defines the *contract* — what evidence a review
   verdict must carry to count as "reviewed" (reviewer identity, the content
   reviewed, a pass/fail/needs-revision verdict, and — for a fail — a
   specific, actionable reason, not a vague "needs polish"). The new skill
   is what actually **dispatches independent specialized reviewer subagents**
   against a piece of model-generated content (e.g., a newly-authored
   curriculum section, an area write-up, an autonomously-generated QA
   ticket) and writes its result in the shape HelixQA's contract expects, so
   `helixqa report`/`helixqa run` can verify a review actually happened and
   actually reached a verdict — not merely that some text got appended.
   "Independent" means: the reviewer subagent must not be the same
   conversation/context that produced the content, and (where the content
   has a specific quality dimension — accuracy, tone, redaction-safety,
   accessibility) the skill dispatches a reviewer scoped to that dimension
   rather than one generic "look this over" pass.

## What this integration explicitly does NOT do

- It does not attempt real pixel-level OCR in this pass (tesseract is absent
  from this host, confirmed earlier this session) — DOM/text/screenshot-diff
  checks via Playwright, which is most of what these two web apps need day
  to day, ship now. HelixQA's own `VisionEngine`/autonomous-session mode may
  already do more than that once actually exercised; this design does not
  assume either way and will report what's actually measured once the
  submodule is live in this tree, rather than trusting its README's claims
  uninspected.
- It does not initialize any `tools/opensource/*` Android/mobile submodule.
- It does not touch `vasic.digital`/`milosvasic.ru`'s existing `_tests/`
  Challenge-bank setup — that stays as is; a future, separately-scoped pass
  could migrate it onto the same `vasic-digital/challenges` foundation
  HelixQA itself uses, but that is not part of this work.
- It does not resolve the open `verify-suppressed-residue.sh` G5
  redaction-integrity finding from earlier this session — that remains
  blocked on operator direction, tracked in `workshop/docs/work-register.md`.

## Success criteria

- `submodules/qa` and `submodules/challenges` are added, pinned, and pass
  `verify-manifest-pins.sh` / `verify-governance-cascade.sh`.
- `helixqa version` runs successfully from the umbrella checkout.
- At least one real, executable YAML test bank exists for `workshop` and one
  for `ai_interviewing`, each provably catching at least one of the six bugs
  already fixed this session as a golden-bad control (proving the bank
  actually bites, not merely that it exists).
- A gate exists that runs HelixQA against both live services and fails on a
  real finding, wired into the existing pre-push/verify machinery rather
  than as a standalone script nobody calls.
- A new skill, `independent-content-review`, exists in this project's Claude
  Code skills directory, dispatches independent reviewer subagents against
  model-generated content, and records a verdict HelixQA's contract can
  check.
