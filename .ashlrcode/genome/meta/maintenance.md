# Genome maintenance — how this genome stays honest

> `meta/` did not exist at genome init (the 15 manifest sections are 4 vision +
> 3 strategies + 6 knowledge + 2 milestones). This directory and file were added
> to hold the maintenance contract. It is **not** listed in `manifest.json`, so
> it is not part of retrieval routing — treat it as a contract for humans and
> agents editing the genome, not as routing context.

## The one rule that outranks the rest

This repository's governing principle is §11.4.6: **do not report a state you
have not verified.** The genome is subject to it. A genome section that states
something no file supports is a bluff with a nicer filename.

Concretely:
- Every non-obvious claim carries the file it came from — path plus line range
  where the line is stable.
- Anything not stated in the repository is labelled **(inferred)** inline.
- A template section with no honest content **stays a template**. Padding it
  with plausible prose is worse than leaving it empty.

## Where each kind of fact belongs

| Fact | Section |
|---|---|
| Why the project exists | `vision/north-star.md` |
| Why the layout is shaped this way | `vision/architecture.md` (intent) |
| Scanned file/extension inventory | `knowledge/architecture.md` (auto-populated — do not hand-duplicate) |
| Enforced rules, with enforcement point | `vision/principles.md` |
| Concrete failures + explicit prohibitions | `vision/anti-patterns.md` |
| How to build / test / deploy / commit | `strategies/active.md` |
| In-flight, self-labelled-unfinished work | `strategies/experiments.md` |
| Something tried and abandoned, with the post-mortem | `strategies/graveyard.md` |
| A decision and its consequences | `knowledge/decisions.md` (**append only**) |
| A surprising, verified fact | `knowledge/discoveries.md` |
| Toolchains, packages, hosting contract | `knowledge/dependencies.md` |
| Repo identity + remote fan-out | `knowledge/workspace.md` |
| Style/layout/commit conventions | `knowledge/conventions.md` |
| Open work, with evidence | `milestones/current.md`, `milestones/backlog.md` |
| Shipped, tagged work | `milestones/completed/` |

## Triggers to refresh

Refresh the named section when one of these lands:

- **`git remote -v` changes anywhere** → `knowledge/workspace.md`. The
  `milosvasic.ru` fetch/push asymmetry and the `monetization` (4) /
  `submodules/constitution` (6) fan-outs are the volatile parts.
- **`.gitmodules` gains or loses an entry** → `knowledge/workspace.md` +
  `knowledge/decisions.md` if ownership changes.
- **A gap in `Constitution.md`'s table flips CLOSED/OPEN, or an OC resolves** →
  `milestones/current.md` and `milestones/backlog.md`. Copy the repository's own
  state word; do not re-adjudicate.
- **A new tag** → `milestones/completed/releases.md`.
- **A gate is added, removed, or reclassified in `_tests/GATES.md` /
  `_tests/TEST-TYPES.md`** → `strategies/active.md`.
- **`.github/workflows/ci.yml` or `_tools/deploy-langs.sh` changes** →
  `strategies/active.md` (and `knowledge/discoveries.md` if the hardcoded
  `/Volumes/T7` paths are finally fixed).
- **`.lumenignore` or the embedding model changes** →
  `knowledge/dependencies.md` + `knowledge/decisions.md` (ADR-0007).

## Boundaries

- **The genome never edits the repository.** It is derived context. If the
  genome and a source file disagree, the source file wins and the genome is the
  thing to fix.
- **Precedence when sources disagree:** `submodules/constitution` >
  root `Constitution.md` > the four agent carriers > `README.md` > everything
  else (`CLAUDE.md:10`, `Constitution.md` §101). Where two roots contradict each
  other today, record the contradiction rather than picking a winner.
- **`knowledge/architecture.md` and `knowledge/workspace.md` have auto-populated
  headers.** Extend below them; a re-scan may overwrite the scanned portion.
- **`knowledge/decisions.md` is append-only** — its own header says so.
- Do not run `lumen index` / `lumen purge` / `codegraph index` as part of a
  genome refresh. Use `scripts/lumen-reindex.sh` and
  `scripts/lumen-index-doctor.sh`, and `codegraph sync` for the graph.

## Mechanics

- `.ashlrcode/genome/manifest.json` indexes the 15 original sections with
  per-section `tokens` and `updatedAt`. **Hand edits to section files do not
  update it.** After a substantial hand edit, refresh it with the ashlr genome
  tooling rather than editing the counts by hand.
- `proposals.jsonl` collects agent-proposed additions (`section`, `operation`,
  `content`, `rationale`, `contentHash`) awaiting consolidation. Use
  `ashlr__genome_propose` to add and `ashlr__genome_consolidate` to merge;
  `ashlr__genome_status` reports state.
- `.git/hooks/post-commit` backgrounds `scripts/genome-commit-watcher.ts` via
  bun (best-effort, never blocks a commit). It is an ashlr hook, **not** a
  §11.4.75 governance layer — do not count it toward gap G5.
- `evolution/` is empty at generation 1.
