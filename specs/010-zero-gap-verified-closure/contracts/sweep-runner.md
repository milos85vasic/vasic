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

Initial class set (each a separate subagent-sized unit; corpora required before a class may print a
numeric recall): stale/false recorded figures (extends claim ledger toward `--completeness`);
vacuous/empty-population gates; gates without paired proofs; carriers/manifest/gitlink drift;
submodule-vs-remote drift (all remotes, not only `origin`); content-boundary rows (registered, never
allow-listed); live-vs-source drift (running binary/stamp vs HEAD); build-only-if-missing start
scripts; missing toolchain → rc-2 gates; unbounded/unregistered scripts (R5); unsealed evidence;
untracked-file blind windows; private-content in public records; documentation counts vs measured
counts; test-kind coverage cells that are gaps.

Never mutates tracked files. `--out` writes only under `.remember/logs/zero-gap/`.
