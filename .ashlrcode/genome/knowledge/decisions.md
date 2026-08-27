# Architectural Decision Records

> Each non-obvious decision gets an ADR entry. Append — do not rewrite history.

---

## ADR-0000: Initialize genome

- **Status:** Accepted
- **Date:** 2026-08-27
- **Context:** This project now uses an ashlr genome so the agent can route
  grep/recall through retrieval instead of re-reading files (~-84% token
  savings on repeated queries).
- **Decision:** Store durable context in `.ashlrcode/genome/` keyed by the
  manifest so retrieval stays cheap and deterministic.
- **Consequences:** Agents must keep the genome current as the project evolves.
  Stale knowledge sections degrade retrieval quality.

---

## ADR-0001: Inherit governance by pointer block, not `@import`

- **Status:** Accepted
- **Date:** 2026-08-26 (recorded in `CLAUDE.md:54-66`)
- **Context:** §11.4.35 invariant 6 declares the native
  `@constitution/CLAUDE.md` import and the portable `## INHERITED FROM ` pointer
  block **equivalent**. `submodules/constitution/CLAUDE.md` is 654 KB and
  `Constitution.md` is 1.53 MB — a native import would load ~165k tokens into
  every session before any work begins.
- **Decision:** All five root carriers use the pointer block. Nothing from the
  corpus is copied; the one bounded exception is the nine-item "Critical base
  rules restated" block, which the constitution itself authors at
  `templates/AGENTS.project.md.template` for exactly this purpose.
- **Consequences:** Read anchors on demand (`grep -n '^### §11.4.35 '`), never
  eagerly. `scripts/gates/lib/pointer_carrier.sh` recognises the form, so the
  propagation gates still classify these carriers correctly.

---

## ADR-0002: Place the governance submodule at `submodules/constitution/`

- **Status:** Accepted
- **Date:** 2026-08-26 (`Constitution.md` path note; `CLAUDE.md:41-47`)
- **Context:** The constitution's own prose and templates use a top-level
  `constitution/` path in every example.
- **Decision:** This repository uses `submodules/constitution/` — the §11.4.28
  dependency-layout form. `find_constitution.sh` resolves it natively (its
  candidate list is `constitution` then `submodules/constitution`).
- **Consequences:** Every quoted `constitution/<file>` in a universal clause
  means `submodules/constitution/<file>` here. This substitution is the **only**
  systematic edit made while instantiating the project template. The five
  owned-submodule `CLAUDE.md` files still use the `constitution/` form.

---

## ADR-0003: Exclude `submodules/superspec` from the owned set

- **Status:** Accepted
- **Date:** 2026-08-26 (`Constitution.md` §103 + superspec subsection)
- **Context:** `submodules/superspec` → `git@github.com:WangX0111/superspec.git`.
  `WangX0111` is outside every operator-listed org (`milos85vasic`,
  `vasic-digital`, `HelixDevelopment`).
- **Decision:** Third-party. No §4 tag mirroring, no §11.4.157 carrier
  propagation, no §11.4.156 CI action, no `helix-deps.yaml` `deps` entry (a
  comment instead). Same treatment for `milosvasic.ru/Upstreamable`
  (`red-elf/Upstreamable`, a fourth-level repository).
- **Consequences:** The propagation gates discover vendored example carriers
  inside it and report them MISSING. Those findings are **known-excluded** and
  documented, never "fixed" by writing into a repository this project does not
  own. The sweep still exits non-zero on them — exclusion means "not ours to
  fix", never "suppressed".

---

## ADR-0004: Carve the governance submodule out of §4 tag mirroring

- **Status:** Accepted — and explicitly flagged as a *project* decision
- **Date:** 2026-08-26 (`Constitution.md`, "the governance submodule itself")
- **Context:** `submodules/constitution` is own-org
  (`HelixDevelopment/HelixConstitution`) but is not a product submodule. Its
  release line (`v1.0.0…`) is unrelated to this repository's (`v1.7.1`,
  `v1.7.2`, `v1.8.0`).
- **Decision:** It is declared in `helix-deps.yaml` as a dependency but is not
  in the §4 tag-mirroring block.
- **Consequences:** The universal §4 wording is *"every owned submodule"* and
  carves out no governance submodule, so this is a deviation recorded openly so
  the operator can reverse it — not a universal rule.

---

## ADR-0005: Propagation is staged in the umbrella, applied by the operator

- **Status:** Accepted; the resulting gap (G7) is **OPEN**
- **Date:** 2026-08-26 (`Constitution.md` §102)
- **Context:** §3 requires the submodule commit and push to land **before** the
  parent captures the pointer.
- **Decision:** Never write a governance carrier into an owned submodule working
  tree from the umbrella. Drafts live at
  `docs/constitution-adoption/propagation/<submodule>/` with a **`.staged`**
  suffix; the operator applies them per `.../propagation/APPLY.md`.
- **Consequences:** The suffix is load-bearing — the propagation gates discover
  carriers by exact filename, so a draft named `CLAUDE.md` inside this
  repository would be counted as a real carrier and fail the gate. Until the
  operator applies them, the propagation gaps stay open and are stated as such.

---

## ADR-0006: Keep the root CI workflow despite §11.4.156(A)

- **Status:** **UNRESOLVED — operator decision, deliberately not acted on**
- **Date:** 2026-08-26 (`Constitution.md` OC-1; `CLAUDE.md:170-173` gap G4)
- **Context:** §11.4.156(A) forbids any active workflow at the root of a
  governed repository, with no escape hatch. `.github/workflows/ci.yml` is
  active here and advertised by a badge at `README.md:3`. Before it existed the
  only Actions in play was a Jekyll *deploy*; nothing ran the test suite.
- **Decision:** Neither disable nor override. Record it as an open conflict.
  Disabling today would remove the only mechanical check that exists and put
  nothing in its place, because the §11.4.75 local layers are absent (gap G5).
- **Consequences:** Release-blocker state, knowingly held. Three resolutions
  exist and none may be picked by an agent: (1) disable per §11.4.156(B) *after*
  standing up the local layers, (2) record an explicit `Override §11.4.156`,
  (3) keep both and accept the state. `milosvasic.ru/.github/workflows/pages.yml`
  is the same conflict inside an owned submodule (OC-2).

---

## ADR-0007: Exclude `_tests/evidence/` from semantic indexing only

- **Status:** Accepted
- **Date:** recorded in `.lumenignore`
- **Context:** 4,526 tracked evidence files against 95 real source files in
  `_tests/`. Embedding them cost ~14 of the ~15 hours a full index needed and
  made search return screenshots and logs.
- **Decision:** One line in `.lumenignore`: `_tests/evidence/`. Everything else
  — all source, all submodules, all docs — is still indexed. The tree stays
  **tracked** in git (`.gitignore` has an explicit `!_tests/evidence/`).
- **Consequences:** Semantic search cannot find run artifacts; use `git`/`ls`
  for those. Reversible by deleting the line and re-running `lumen index .`.

---

## ADR-NNNN: _Template_

- **Status:** Proposed | Accepted | Superseded
- **Date:** YYYY-MM-DD
- **Context:** …
- **Decision:** …
- **Consequences:** …
