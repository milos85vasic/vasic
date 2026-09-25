# Contract: sweep runner (`scripts/zero-gap-sweep.sh`)

```
zero-gap-sweep.sh [--class <id>]... [--json] [--out <dir>] [--expect-fingerprint <sha256>]
zero-gap-sweep.sh --prove-failure      # paired proof: plant a defect per class, expect rc 1; break the runner, expect rc 2
```
Exit **0** no findings AND every class inspected its full population AND every printed recall is
numeric; **1** at least one finding; **2** anything could not be inspected, the tree moved during
the run (fingerprint before ≠ after), a class has no corpus and is asked to certify, or a tool is
missing. A finding outranks an undetermined (`1` beats `2`); an undetermined can never be masked.

Input: `docs/zero-gap/sweep-classes.tsv` (schema in data-model.md). The class list is DATA; adding a
class is a data change plus its planted corpus.

Output (stdout, deterministic, sorted): one line per finding
`FINDING <class_id> <severity> <category> <location> <one-line description> <evidence_ref>`,
then `COULD-NOT-INSPECT <part> <reason>` lines, then a per-class table
`CLASS <id> population=<n> inspected=<n> recall=<0..1|UNKNOWN>`, then the fingerprint pair and the
verdict line. Two runs on an unchanged fingerprinted state MUST be byte-identical (SC-001).

Initial class set (16; each a separate subagent-sized unit named as in tasks T019–T034 and T081; corpora
required before a class may print a numeric recall): `stale-figures` (extends the claim ledger toward
`--completeness`); `vacuous-gates` (empty population / zero cases); `unproven-checks` (no paired proof);
`pointer-drift` (gitlink vs `helix-deps.yaml` vs carriers vs ALL configured remotes, not only `origin`);
`content-boundary-rows` (registered, never allow-listed); `live-vs-source` (running binary/stamp vs `HEAD`,
population `wire`); `build-if-missing` (start scripts that build only a missing binary);
`missing-toolchain` (rc-2 gates → `Operator-blocked`); `unregistered-scripts` (R5); `unsealed-evidence`;
`untracked-blind-window`; `private-in-public` (FR-020); `doc-count-drift`; `coverage-gaps` (each `gap` cell
of the coverage map); `guard-gaps` (destructive commands the PreToolUse guard does not block; upstream code,
classified `third-party` with a reporting route); `known-open-decisions` (the operator-decision backlog with
options and cost, FR-009); plus `improvement-candidates` (T081).

Never mutates tracked files. `--out` writes only under `.remember/logs/zero-gap/`.
