# Experimental Strategies

Approaches being tested this generation. Each is labelled in-repo as unfinished
— none of them is a settled practice yet.

## `design-toolkit` as a deterministic UI-generation layer

`design-toolkit/README.md` describes a "reusable, license-clean design-capability
layer" that combines with OpenDesign to produce non-repeatable UI/UX from a
per-project seed. Its own status line says:

> "**Status: FIRST INCREMENT — review-ready local scaffold.** … No remote repos
> are created yet, no git submodules are added yet, and the generator code is
> specified but not yet vendored."

It is checked out here and declared in `helix-deps.yaml`, but nothing in the
six CI gates reads it.

## The five-agent tooling stack (`scripts/setup-agents-wizard.sh`)

Installs and wires Claude Code, Kimi, Opencode, MiMo Code and Qwen Code with
Lumen (+ CodeGraph for Kimi and Qwen) and `ashlr` / Glyphdown / SpecKit /
SuperSpec. Documented across seven files under `docs/setup-agents-wizard/`,
with `scripts/rollback-agents-wizard.sh` as the undo path and
`scripts/test-setup-agents-wizard.sh` as its test suite.

Deliberately incomplete edges, stated by the wizard itself: MiMo Code has no
documented MCP config file, so the wizard prints values instead of inventing a
path; project indexing is opt-in behind `WIZARD_INDEX_PROJECT=1`; the Glyphdown
`PreToolUse`/`PostToolUse` hook is skippable and "fires on EVERY tool call —
enable deliberately" (`MANUAL-STEPS.md`, generated per run and git-ignored).

## This genome

`.ashlrcode/genome/` was initialised 2026-08-27 (`manifest.json`,
generation 1, milestone "Initial setup"). Its own maintenance contract is in
`meta/maintenance.md`. Treat retrieval quality as the experiment's success
metric; nothing has measured it yet.

## Not yet tried, and named as such

- `scripts/verify-governance-cascade.sh` — required by §11.4.32 step 1, does not
  exist; the sweep records it as SKIP-with-reason (`Constitution.md` OC-3).
- A lint proving **zero** non-token colour/space literals across CSS and inline
  styles — demanded by the OpenDesign adoption plan, not implemented
  (`_tests/GATES.md`, residual coverage gaps).
- OpenDesign consumed as an external dependency rather than as generated output
  (`_tests/GATES.md`, same section).
