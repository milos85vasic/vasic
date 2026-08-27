# Constitution adoption — closing the open gaps

Status: In Progress
Generation: 1

> **Evidence basis.** This is not an invented milestone. It is the work item the
> repository documents at length: `docs/constitution-adoption/INVENTORY.md`, the
> "Known open gaps" table in `Constitution.md`, and the "Honest boundary" section
> of `CLAUDE.md:155-193`. Sub-item states are the repository's own, not a
> re-assessment.

## Where it stands

`scripts/verify-all-constitution-rules.sh` — last recorded sweep (2026-08-26,
constitution HEAD `448981ae`): **58 gates, 37 PASS / 21 FAIL / 0 ERROR**,
exit `1`. All 21 failures are classified in `Constitution.md` §"Known-excluded
gate findings" — 17 propagation gates reporting the same five carriers, plus 4
gates failing inside the constitution submodule's own tree.

## Gap ledger (identifiers are `INVENTORY.md`'s own)

| Gap | State | Note |
|---|---|---|
| G1 — consumer governance layer | **CLOSED** | four carriers at the root |
| G2 — inheritance pointer | **CLOSED** | all five open with `## INHERITED FROM ` |
| G3 — post-pull validation sweep | **PARTIAL** | `verify-all-constitution-rules.sh` exists; `verify-governance-cascade.sh` does not → OC-3 |
| G4 — active root CI vs §11.4.156 | **OPEN** | operator decision → OC-1 / OC-2 |
| G5 — §11.4.75 mechanical layers | **OPEN** | commit wrapper exists (`CLAUDE.md:174-181`); git hooks do not |
| G6 — `helix-deps.yaml` | **CLOSED** | verified 2026-08-27 |
| G7 — propagation to owned submodules | **OPEN** | staged, unapplied (§102) |
| G8 — §11.4.65 markdown export mandate | **OPEN** | no `.html`/`.pdf` siblings anywhere |
| G9 — §11.4.212 README-orphan | **OPEN** | `README.md` links to nothing but the CI badge |
| G10 — §4 tag mirroring | **OPEN** | `v1.8.0` on `milosvasic.ru` + `vasic.digital` only |
| G11 — `design-toolkit` checked out twice | **OPEN** | shas matched at capture |
| G12 — §11.4.109 anti-forgetting layer | **OPEN** | guard script present in the submodule, wired nowhere |

Also open, and not in the gap table: there is **no `CONTINUATION.md`** at this
root (`CLAUDE.md:189-190`).

## Success criteria

- [ ] G3 → CLOSED: `scripts/verify-governance-cascade.sh` written, so §11.4.32
      step 1 stops being a SKIP-with-reason (OC-3).
- [ ] G4 → decided by the operator: disable per §11.4.156(B) **after** standing
      up the §11.4.75 layers, or record an explicit `Override §11.4.156`.
      *(An agent may not pick.)*
- [ ] G5 → CLOSED: §11.4.75 git-hook layers installed at this root.
- [ ] G7 → CLOSED: operator applies the staged carriers per
      `docs/constitution-adoption/propagation/APPLY.md`, submodule-first;
      `vasic.digital/QWEN.md` is the one owned carrier the gates flag.
- [ ] G12 → CLOSED: `guard-forbidden-commands.sh` wired as a `PreToolUse` guard.
- [ ] Sweep exits non-zero **only** on findings classified as known-excluded or
      upstream.

## Explicitly out of scope

Anything requiring a commit inside a submodule working tree, any edit to
`submodules/superspec` or `milosvasic.ru/Upstreamable`, and the four gate
failures that belong upstream in `HelixDevelopment/HelixConstitution`
(§11.4.26).
