# Quickstart — validating this feature end to end

**Feature**: Authored AI/IT Knowledge Areas · **Date**: 2026-09-07

Runnable scenarios that prove the feature works. Every command below has been
executed; where a result is **not** yet obtainable, that is stated rather than
written as an expectation.

**Exit-code contract throughout: `0` clean · `1` a real finding · `2` could not
determine. A `2` is never a pass.**

## Prerequisites

- `podman` (no `docker` on this host)
- Go 1.26+, Node 20, Python 3
- The private `workshop` submodule initialised
- `submodules/curriculum-kit` present (it is a plain directory — see the caveat at the end)

## 0 — Build and unit gates

```bash
cd workshop/platform/backend
go build ./... && go vet ./... && go test ./... -count=1
```

Expected: **rc 0**, 19 packages ok. Measured: rc 0 before and after this work.

## 1 — The catalogue tells the truth about itself (US1, FR-018)

The property: **`areas[]` is exactly the set whose `href` answers 200.**

```bash
bash workshop/platform/gates/verify-area-publication-consistency.sh
bash workshop/platform/gates/prove-area-publication-consistency.sh
```

Expected: **0** — `6 passed / 0 failed / 0 could-not-determine`, then **0** —
`7 passed / 0 failed / 7 mutations`. Both measured.

The prover's mutations are **data**, read from `MUTATION=`; the stub's source is
byte-identical on every run. Mutation 0 is a control that must go **green** — a
gate that failed on everything would "catch" everything and prove nothing.

**Vacuity check A6**: nothing served *and* nothing held back must exit **2**.
The prover asserts this, so a gate reporting "no inconsistencies" over an empty
catalogue cannot pass.

## 2 — A test cannot be taken early, and cannot leak (US2, FR-010, SC-009)

```bash
bash workshop/platform/gates/verify-assessment-gate.sh
bash workshop/platform/gates/prove-assessment-gate.sh
```

Expected: **0** — `9 passed`, then **0** — `17 passed / 17 mutations`. Measured.

Watch **B4/M7** specifically: it is the mutation that opens the gate as soon as
*any* lesson completes, and it passes five of the other assertions. If you
change the fixture so its required set equals its lesson set, B4 stops catching
it — the fixture, not the gate, is what makes this detectable.

**Vacuity checks B9/B10** exit **2** on a test gated on nothing.

## 3 — Video anchors resolve and land correctly (US3, FR-016, SC-008)

```bash
python3 workshop/pipeline/extract/verify_curriculum_areas.py
python3 workshop/pipeline/extract/verify_curriculum_areas.py --prove-failure
```

Measured: plain run **rc 1** — `A1 37 docs OK · A2/A3/A4 479 links, 0 link
defects · A5 3 FAIL`; prover **rc 0** at `11 passed / 0 failed, 11 mutations`.

**The rc 1 is correct and must not be silenced.** The three failures are the
three area documents with 62, 54 and 58 uncited claim blocks. Leaving them
failing is the point; stamping them would be the bypass.

Spot-check one link by hand in the browser and confirm all four consumer
obligations: the player is at `t`, the passage is in view **without scrolling**,
it is visually distinguished, and the range extent is discernible.

## 4 — The whole learner journey (US1 + US2, SC-006)

```bash
bash workshop/platform/qa/challenges/api-challenges.sh
```

Measured: **rc 0**, `111 passed, 0 FAILED, 0 could not be determined`.

Then, by hand: open the catalogue → open an area → read its lessons → attempt the
test before finishing (expect a stated remaining requirement and **no** question
text) → finish the lessons → take the test → read the result → reload and confirm
the result is unchanged.

> **This journey CANNOT yet be completed against real content.** Every real area
> answers a determined `no_learning_catalog` until
> `curriculum/learning/NN-<slug>.json` is authored. The six routes are proved
> against a synthetic bicycle-maintenance fixture only. This is a **2**, not a
> pass, and it is the largest open item.

## 5 — Served state matches on-disk state (FR-023a, defect D8)

```bash
bash workshop/platform/gates/verify-server-unity.sh                 # against the live container
bash workshop/platform/gates/verify-server-unity.sh --base <fresh>  # against a server built from this tree
```

Measured **right now**: against the live container **RED — `PASS=37 FAIL=6`**,
all six the new routes answering a plain-text 404 because the container is
running the **old binary**. Against a server built from this tree:
**`PASS=43 FAIL=0 UNDET=0 DEBT=8`**.

**This is the feature's own headline defect, live.** A verified on-disk state is
not evidence about what is served. It clears on restart:

```bash
bash workshop/scripts/restart.sh     # full down/up, never `compose restart`
```

> **Never pass `--destroy-volumes` to `stop.sh`.** The `workshop-index` volume
> holds hours of transcription output.

Restart **once**, after every writer has stopped — a restart mid-write measures
a tree that is still moving.

## 6 — Presentation (US5, SC-010, SC-011)

> **No instrument exists yet.** SC-010 (≥6 hue families across principal
> surfaces) and SC-011 (contrast floors in both light and dark) have no check.
>
> A check written here must read **the served stylesheet**, not the token
> source. A token-level measurement is evidence about tokens, and reporting it
> as evidence about the interface is exactly defect D6. Rebuild immediately
> before measuring and state which build was measured.

## 7 — Standalone cloneability (US6, FR-024)

```bash
bash workshop/scripts/verify-standalone-clone.sh
```

Measured: **3 gaps**, up from 2. The new row is truthful and is the gate working:

```
platform/backend/go.mod: replace target ../../../submodules/curriculum-kit
resolves OUTSIDE this repository and 'curriculum-kit' is not declared in
helix-deps.yaml
```

`submodules/curriculum-kit` **is not a git repository**. It has no commit, so no
truthful `helix-deps.yaml` entry can be written, and a fabricated `ref:` would be
a bluff. **Inside the umbrella this builds; a standalone clone does not.**
Remedy — publish it and mount it as a gitlink — is upstream and is an operator
decision.

## Summary of what this quickstart can and cannot prove today

| Scenario | Status |
|---|---|
| 0 Build and unit gates | **PASS**, rc 0 |
| 1 Catalogue consistency | **PASS**, rc 0 both arms |
| 2 Assessment gating and non-disclosure | **PASS**, rc 0 both arms |
| 3 Anchors resolve | **rc 1, correctly** — 0 link defects, 3 documents fail review |
| 4 Full journey, synthetic | **PASS**, 111/0/0 |
| 4 Full journey, real content | **UNDETERMINED** — no authored catalogue yet |
| 5 Served == on-disk | **RED** — container runs the old binary |
| 6 Presentation | **UNDETERMINED** — no instrument |
| 7 Standalone clone | **1 real finding**, blocked upstream |
