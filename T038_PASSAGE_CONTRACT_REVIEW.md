# T038 Passage Contract Review — specs/008-unified-workshop-platform

## Task text

> Review the passage contract implementation against `contracts/passage-contract.md` before anything consumes it — every other component depends on its shape.

## Back-reference

- Source task: **001/T022** (specs/001-workshop-curriculum-platform)
- Status: `[ ] [REVIEW]`
- Owner: human reviewer
- Requirement mapping: FR-037 → unified FR-010
- Claimed commit `1e361bd` (75/75 tests): **does NOT exist** in this checkout

## Passage contract requirements

Contract: `specs/001-workshop-curriculum-platform/contracts/passage-contract.md`

**Shape / identity**
- `pid` = ULID minted at ingest
- anchors
- registry: `passages.jsonl` + `passages.db`
- survival guarantees G1 / G2
- `content_hash` never identity

**Failure modes**
- code passages: weak / loud failure

**Resolver**
- four-outcome: `found` / `redacted` / `not_in_registry` / `undetermined`

**Ingest**
- matching R1a – R6

**Idempotency**
- I1 – I6

**Gates**
- G-PID-1 … G-PID-6, each with paired mutations

**Unverified register**
- P-U1 = symbol producer for code passages

**spec.md passage-contract requirements**
- FR-010, FR-011, FR-012, FR-017, FR-018, FR-021, FR-027, FR-146, FR-149, FR-150, FR-152, FR-165, FR-180
- SC-009, SC-013, SC-016, SC-016a
- EC-045, EC-046, EC-047, EC-048, EC-052

## Review evidence needed

- Diff/patch of the passage contract implementation (unified FR-010 vs. spec/001 contract) against `specs/008-unified-workshop-platform/contracts/passage-contract.md` and `specs/008-unified-workshop-platform/spec.md`
- Confirmation that every consumer importing `github.com/vasic-digital/passage/pkg/passage` was gated behind T038 sign-off
- Test suite for T038: which tests exist, which pass/fail, coverage of G-PID-1…G-PID-6 paired mutations and P-U1
- Evidence that `pid` ULID minting, anchors, `passages.jsonl` + `passages.db` registry, G1/G2 survival guarantees, and `content_hash`-never-identity all hold in the unified implementation
- Evidence that code passages fail weak/loud and the four-outcome resolver returns exactly `found` / `redacted` / `not_in_registry` / `undetermined`
- Evidence that ingest matching covers R1a–R6 and idempotency covers I1–I6

## Blockers / conflicts

1. **Claimed commit `1e361bd` (75/75 tests) does NOT exist in this checkout.** No test baseline can be verified against that commit. T038 cannot be marked complete on the strength of a nonexistent commit.
2. **Premature consumers.** Components already import `github.com/vasic-digital/passage/pkg/passage`, violating T038's "before anything consumes it" premise. The contract is being consumed before it has been reviewed, so shape changes forced by the review will ripple into existing consumers.
3. **Unverified register P-U1.** Symbol producer for code passages is not yet verified; review must establish whether P-U1 holds or whether the register needs to be gated.

## Key findings

- **Missing commit:** `1e361bd` is not reachable in this checkout, so the claimed 75/75 test result cannot be reproduced or trusted as evidence for T038.
- **Premature consumption:** `github.com/vasic-digital/passage/pkg/passage` is already imported by consumers before T038 review sign-off, directly contradicting the task's own ordering requirement ("before anything consumes it — every other component depends on its shape").
- The unified requirement FR-010 (from 001/T022) depends on the passage contract shape being frozen; with consumers already in place, any contract correction from this review becomes a breaking change to existing code rather than a clean design decision.
