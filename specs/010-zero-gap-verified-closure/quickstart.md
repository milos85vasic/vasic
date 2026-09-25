# Quickstart: validating Zero-Gap Verified Closure

Two kinds of command appear below and they are labelled, because this plan produces no code:
**[EXISTS]** runs today against the current tree; **[TARGET]** exists only after the named task
group is implemented and is the acceptance test for it. Nothing here is a claim that a target
command already works.

Prerequisites: repo root `/home/milosvasic/Projects/vasic`, Go 1.26, `flock`, `systemd-run`; a
working tree that is clean apart from files you are deliberately reviewing. Never run these against a
moving tree — the
runners refuse (rc 2) when the fingerprint changes mid-run.

## 0. Baseline facts that already hold [EXISTS]

```bash
bash scripts/verify-workable-items.sh        # today: COULD NOT DETERMINE (G4 roster, G5 unresolved) — a real finding
bash scripts/verify-claim-ledger.sh          # expect: 10 VERIFIED / 0 FALSE / 0 ORPHAN, rc 0
bash scripts/verify-manifest-pins.sh         # expect rc 0, all refs MATCH
bash scripts/continuation-check.sh           # expect IN SYNC
git ls-files --error-unmatch docs/workable_items.db   # the register is tracked
```

## 1. US1 — one complete register [TARGET: sweep + store extension]

```bash
(cd _tools/workable-items && go test ./...)        # V-G1..V-G9 RED first, then GREEN
bash scripts/zero-gap-sweep.sh --json --out .remember/logs/zero-gap/run1
bash scripts/zero-gap-sweep.sh --json --out .remember/logs/zero-gap/run2
cmp .remember/logs/zero-gap/run1/*.json .remember/logs/zero-gap/run2/*.json   # SC-001: identical
bash scripts/zero-gap-sweep.sh --prove-failure    # plant a defect per class; expect a finding for each (SC-002)
```
Expected: findings sorted and stable; a per-class table with numeric `recall` or `UNKNOWN`;
unreachable parts listed under `COULD-NOT-INSPECT`; rc 1 while any finding exists, rc 2 if anything
could not be inspected (never 0 over an uninspected part).

## 2. US2 — closure needs RED then GREEN [TARGET]

```bash
workable-items-vsc gap add ...                    # open an item from a finding
workable-items-vsc gap close --id XXX-nnn \
  --red-evidence <pre-fix record> --green-evidence <post-fix record> --verdict-ref <verifier row>
echo $?    # 1 unless every precondition holds; 0 only with RED(pre-fix) + GREEN(current) + independent verdict + review
workable-items-vsc gap classify --id XXX-nnn --reason severity-low ...   # expect rc 1: not one of the four reasons
```

## 3. US3 — coverage map [TARGET]

```bash
bash scripts/zero-gap-coverage.sh --json
bash scripts/zero-gap-coverage.sh --prove-failure   # a cell whose check ran zero cases must become a gap
```
Expected: every (subject × test kind) cell is `check|n/a|gap|could-not-run`; zero blank cells (SC-005).

## 4. US4 — evidence that cannot lie [TARGET: evidence adapter]

```bash
bash scripts/zero-gap-determinism.sh --check verify-manifest-pins   # 5 repeats → 5 identical sha256 (SC-006)
bash submodules/constitution/scripts/gates/cm_chain_integrity_detects_alteration.sh   # [EXISTS] upstream attack corpus
bash scripts/zero-gap-scan-records.sh docs/zero-gap specs/010-zero-gap-verified-closure   # FR-020: expect zero hits (SC-008)
```
Expected: altering, deleting, reordering an evidence record is detected; a truncated tail is caught
only by the anchor and reported with its honest mechanism string; a chain that cannot be walked
REFUSES, never passes.

## 5. US5 — independent verification and drift [TARGET]

```bash
bash scripts/zero-gap-verify.sh --item XXX-nnn            # independent re-run on pre-fix ref and current ref
# reopen test: in a DISPOSABLE copy revert a closed item's fix, then
bash scripts/zero-gap-daily.sh --now                      # expect a reopen-pending entry + failing evidence in the queue (SC-009); the register changes only via `gap apply-queue` in a commit
systemctl --user list-timers | grep zero-gap              # only after the operator installed the units
```

## 6. Whole-programme acceptance [TARGET]

`gap summary --json` shows `no-state=0, no-owner=0, no-evidence=0` (SC-003), every closed item has
a second verdict (SC-004), every check has a paired proof (SC-007), and the frozen cycle's
fingerprint verifies (`gap freeze --cycle N` then re-derive).
