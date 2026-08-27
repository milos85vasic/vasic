# Workspace

> Auto-discovered from child directories at genome init, then extended by hand
> with what each repository IS and where it pushes. Remote data verified with
> `git -C <path> remote -v` on 2026-08-27; it matches the table in
> `Constitution.md` ("Project-specific remotes", captured 2026-08-26).

- **Total directories:** 30
- **Git repositories:** 5 discovered as child checkouts (+ 2 under `submodules/`)
- **Projects with CLAUDE.md or .claude/:** 5

## The gitlink set (`.gitmodules`, 7 entries)

| Path | What it IS | Owned? |
|---|---|---|
| `vasic.digital` | Company site — **committed static HTML**, served as-is, no build step. Output of `_tools/gen/`. | Yes |
| `milosvasic.ru` | Personal site — **Jekyll source**; rendered `_site/` is git-ignored. Embeds `red-elf/Upstreamable` (third-party, 0-byte gitlink → breaks recursive checkout). | Yes |
| `design-toolkit` | Deterministic, license-clean design-capability layer over OpenDesign. Self-declared **"FIRST INCREMENT — review-ready local scaffold"**; generator code specified but not vendored. No CI gate reads it. | Yes |
| `ai_interviewing` | Interview-preparation corpus + employer due-diligence kit for a specific role, exported to the four Constitution-mandated formats. Content, not code. | Yes |
| `monetization` | "Monetization of existing projects" (its whole README body). Docs + `repos.txt`. | Yes |
| `submodules/constitution` | `HelixDevelopment/HelixConstitution` — the **governance submodule** this project consumes. Own-org, but deliberately carved out of §4 tag mirroring. | Governance |
| `submodules/superspec` | `WangX0111/superspec` — **THIRD-PARTY**, outside every operator-listed org. Never tagged, never given a carrier, never edited (`Constitution.md` §103). | **No** |

Owned set per `Constitution.md`: `ai_interviewing`, `design-toolkit`,
`milosvasic.ru`, `monetization`, `vasic.digital`.

## Remote fan-out (verified 2026-08-27)

| Repo | Distinct push URLs | Detail |
|---|---|---|
| main `vasic` | **1** | `origin`, `github`, `upstream` all ↔ `git@github.com:milos85vasic/vasic.git` |
| `ai_interviewing` | **1** | three names, one URL (`milos85vasic/ai_interviewing`) |
| `vasic.digital` | **1** | three names, one URL (`vasic-digital/vasic-digital.github.io`) |
| `design-toolkit` | **1** | `origin` only (`vasic-digital/design-toolkit`) |
| `milosvasic.ru` | **2** | ⚠ fetch/push asymmetry — see below |
| `monetization` | **4** | `origin` push → gitflic, github, gitlab, gitverse (`ssh://…:2222`). Named peers `gitflic`/`github`/`gitlab`/`gitverse`, `upstream` ↔ gitflic |
| `submodules/constitution` | **6** | `origin` push → gitflic, github, gitlab, gitverse, **plus** `vasic-digital/HelixConstitution` on GitHub and GitLab. Named peers incl. `vasic_digital_github`, `vasic_digital_gitlab` |
| `submodules/superspec` | 1 | third-party; this project pushes nothing here |

All remotes are SSH. Not one `https://` remote exists in the set.

Four repos have exactly one distinct URL — a GitHub outage makes the umbrella,
`ai_interviewing`, `vasic.digital` and `design-toolkit` unreachable. §2.1 is a
SHOULD for consuming projects, so this is a recorded posture, not a violation.

### ⚠ `milosvasic.ru` — fetches from a URL it never pushes to

```
origin  fetch  git@github.com:milos85vasic/milosvasic.ru.git
origin  push   git@gitflic.ru:milosvasic/milosvasic-net-v-2.git
origin  push   git@github.com:milos85vasic/milosvasic.net.v2.git
```

`milosvasic.ru.git` is in **no** remote's push list. `.gitmodules` pins the
submodule URL to that same fetch-only repository, so a fresh
`git submodule update --init` clones the repo that receives **no** pushes — a
fresh clone and a long-lived working tree can be looking at different histories.
Reconciling it is an **operator decision** (add the URL to `origin`'s push list,
or repoint fetch/`.gitmodules` at `milosvasic.net.v2`); it is never normalised
from here. Full write-up: `Constitution.md`, "⚠ Hazard" subsection.

## Local-only directories (no remote)

`_analysis`, `_content` + 14 `_content_<lang>` siblings (`ar be de es fa fr hi
ja kk ko ru sr tr zh`), `_tests`, `_tools`, `data`, `design-system`, `docs`,
`scripts`, `submodules`, `tests`, `upstreams`.

## Carriers in the child repos

All five owned submodules carry a `CLAUDE.md` opening with
`## INHERITED FROM constitution/CLAUDE.md` and a **conditional** inheritance
preamble ("The inheritance below is conditional. Both cases are stated; neither
is assumed"). Note the path form there is `constitution/`, not this repository's
`submodules/constitution/`.

Governance-carrier propagation to the owned submodules is **staged, not
applied**: drafts live at `docs/constitution-adoption/propagation/<submodule>/*.staged`
and the operator applies them per `docs/constitution-adoption/propagation/APPLY.md`
(`Constitution.md` §102; gap G7 OPEN).
