# Operator decisions — 2026-09-07

Sixteen blocked items were put to the operator interactively and answered. This
file is the record: what was blocked, what was decided, and what the decision
obliges. Recorded per §11.4.208 so a decision is not re-litigated and not
misremembered.

**Status vocabulary**: DECIDED (answered, not yet executed) · IN FLIGHT ·
DONE (executed with captured evidence).

## The decisions

| # | Blocked item | Decision | Status |
|---|---|---|---|
| 1 | `submodules/curriculum-kit` is not a git repository; `go.mod` reaches outside the repo and no truthful manifest entry can be written | **Publish as `vasic-digital/curriculum-kit`, PUBLIC**, mount as a gitlink, declare in `helix-deps.yaml` | DECIDED |
| 2 | 3 area documents fail publication review on 62/54/58 uncited claim blocks | **Operator reads them.** Produce a bounded per-document list of exactly which claim blocks lack citations first | DECIDED |
| 3 | Only 5 of 42 areas carry a test | **Author senior banks for the 25 strongly + moderately evidenced areas**, against real transcript evidence, area by area. The 12 thin areas stay honestly without tests | DECIDED |
| 4 | FR-002 asked for a topical classification the reviews decline to make | **Build an automated topical classifier**, recorded with its confidence and given its own review | DECIDED |
| 5 | Four authored schema values (70% pass, mcq 2 / short 3, the 91–95 prefix shift, anchor attachment) | **Accept all four as-is** | DONE |
| 6 | SC-010 hue floor: gate reported 4 families over a defective instrument | **Fix the gate, then judge the real number.** Fixed; the corrected gate reports **2** | DONE (fix) / OPEN (the design finding) |
| 7 | Two chapter-card implementations; `/chapters` never uses the component extracted for it | **Converge onto the shared component** | DECIDED |
| 8 | The 37-area lexicon is chapter-01-derived; chapters 02 and 02.01 were never mined | **Mine both, propose new areas**, operator approves additions before they publish | DECIDED |
| 9 | 12 documents' ingested `.sections.json` are stale; regenerating mints new passage ids | **Leave stale, record it explicitly.** All 251 ids resolve; regenerating would churn the corpus and break existing citations | DECIDED |
| 10 | `tesseract` absent (gate 5 → rc 2); `bundle`/`bundler`/`jekyll` absent (gate 6 asserts against an 8-file fragment) | **Provide both — CONTAINERISED, through `submodules/containers`**, not host packages. Operator directive: *"Make sure everything runs in containers, use our containers Submodule for all containers related work!"* | DECIDED |
| 11 | Content-boundary gate red at ~15,300 matches; decision packet never acted on | **Judge the ~1,540 class-A inward rows** — 1,084 against private source, 68 against teaching material, three public files holding 1,120 | DECIDED |
| 12 | `deploy-langs.sh` downgrades a failed Jekyll build to a warning and still exits 0 | **Fail the deploy on a failed build**, behind a flag for deliberate override | DECIDED |
| 13 | `milosvasic.ru/_site/` tracked: 8 files, 1 page, answers 1 of 525 sitemap URLs | **Untrack it, keep the ignore rule** | DECIDED |
| 14 | 21 repositories have Actions enabled while declaring zero workflow files | **Sweep the 20, exclude `milosvasic.ru`** — its `pages.yml` is the sole publish path for the live site | DECIDED |
| 15 | `design-toolkit` GitLab mirror 7 commits behind, recipe deliberately `.disabled` | **Enable the recipe and sync the mirror** | DECIDED |
| 16 | Nothing committed this session; container serves the old binary | Restart once when all writers stop, then commit and push recursively | PENDING |

## Decisions that reversed a recommendation

Recorded because a recommendation overruled is worth more than one accepted.

- **#4 topicality** — I recommended a human checkpoint on the grounds that 42
  areas is an afternoon's reading and a classifier inherits the jargon-free-title
  blind spot. **Operator chose the classifier.** Obligation: it must read the
  area **body**, not the title, or it reproduces exactly the blind spot that made
  the term-in-name probe understate its own result.
- **#10 host toolchains** — I offered host package installs. **Operator required
  containers**, invoking `submodules/containers` per §11.4.76. Obligation: no
  `apt-get` on the host; both workloads reached through that module, and the
  module's own runtime detection rather than a frozen `podman` literal.
- **#15 GitLab mirror** — I recommended leaving it disabled because enabling it
  starts publishing to a private mirror on every push. **Operator chose to
  enable and sync.** Obligation: the mirror is PRIVATE and the source is PUBLIC,
  so this is a public→private flow, which carries no disclosure risk in that
  direction. Verified before acting.

## What #6 now obliges — the finding is real and it got worse

The gate had three confirmed defects and all three are fixed, verified by me
before the fix and by an independent prover after:

| Defect | Was | Now |
|---|---|---|
| Non-text rows graded the ground *behind* an indicator, so a coloured chip could never contribute a family | `bg` only | sampler emits `paint` (own background, else own border); palette families over `bg ∪ paint`; **contrast gate untouched** |
| One-ULP bucketing split one ramp in two (`29.999999999999998` vs `30.0`) | 2 families | 1 |
| HSL saturation called a 3-unit RGB spread chromatic at one end of a ramp and neutral at the other | ramp split 3 ways | OKLab chroma, floor 0.01 — the whole ramp is neutral |

**The corrected gate reports 2 families against a floor of 6 — down from the
broken gate's 4.** Three of those four were one warm surface ramp counted three
times. Nothing was widened, lowered or padded to reach that number.

Two boundaries the fix did not close, both stated rather than absorbed:

1. **The non-text fix contributed nothing to the live count**, because the
   sampler matched **zero** non-text rows on the sampled route — no `input`,
   `hr`, `.badge`, `.chip`, `.tag` or `[role=status]`. The chip, rule and rail
   hues measured elsewhere are still outside the sampler's population. Widening
   the selector list is a separate decision and was **not** taken, because doing
   it while chasing a count is how an instrument gets tuned to a result.
2. The design finding is now unambiguous: **the served interface paints two hue
   families across its principal surfaces.** The theming agent's counter-measurement
   found the taxonomy families painting on rules, chips, washes and the rail
   ground — real, and reaching only elements the population excludes. Both facts
   are true: the palette exists, and it is not on the principal surfaces.
