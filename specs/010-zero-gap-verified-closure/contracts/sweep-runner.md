# Contract: sweep runner (`scripts/zero-gap-sweep.sh`)

```
zero-gap-sweep.sh [--class <id>]... [--json] [--out <dir>] [--expect-fingerprint <sha256>] [--root <dir>]
zero-gap-sweep.sh --prove-failure      # paired proof on THROWAWAY repos built from _tests/fixtures/zero-gap/sweep/: a fixture-only
                                        # demo class copied under one name per hostile behaviour (blind, moving, malformed, escaping,
                                        # over budget, ...) must yield the stated rc; the live tree must stay byte-identical (else rc 2).
                                        # Each REAL class's planted-defect proof is its own corpus (recall engine) and its own --prove-failure.
```
Exit 0: no finding, and every class inspected its full non-empty population with recall 1.0 and no false positive. Exit 1: at least one FINDING. Exit 2 otherwise. A finding outranks a class-level undetermined. A tree that moves between the before and after fingerprints is UNSTABLE, rc 2 even with findings; its FINDING lines are not evidence. Each class prints exactly one `INSPECTED <n>`, compared with `--emit-population`. Output, sorted: `FINDING …`; `COULD-NOT-INSPECT <class>:<part> <reason>` (`-` = whole class); `CLASS <id> population=<n> inspected=<n> recall=<0..1|UNKNOWN> findings=<n> status=<clean|findings|could-not-inspect|unproven|not-implemented>`; `FINGERPRINT before=<sha> files=<n>`; `FINGERPRINT after=<sha> files=<n>`; `VERDICT <HOLDS|VIOLATED|UNDETERMINED|UNSTABLE> rc=<n> …`. Pseudo class `sweep` carries the runner's own findings. The ids `sweep`, `evidence` and `registers` are reserved. RECALL-MISS, RECALL-UNEXPECTED, RECALL-FALSE-POSITIVE and RECALL-MISMATCH are FINDINGs. Locations are single percent-encoded tokens.

Reconciled with the implementation (fix round 1):
- The fingerprint is taken before the first class and after EVERY class, so a move inside any class's
  window is UNSTABLE even when before equals after; the COULD-NOT-INSPECT line names the class that was
  running. It covers zg_manifest (tracked + untracked-not-ignored content), HEAD, refs, local config, the
  index, the contents of `<git-dir>/hooks` and `<git-dir>/info`, and each population file's
  mtime/ctime/size/inode. Ignored paths are outside it; a write to one
  during a class (every ignored file listed and stat'ed on both sides: created, removed, written, `cp -p`) is a
  COULD-NOT-INSPECT (not UNSTABLE), except under `ZG_IGNORED_EXCLUDE` (default
  `.remember/tmp/:.remember/logs/:.service-registry/qa/` — host session tooling, and the access logs of QA servers
  a class probes read-only).
- RECALL-* findings are located at the class script (`scripts/zero-gap-class-<id>.sh`), with the corpus
  path in the description.
- Each class also prints exactly one `POPULATION-SHA <sha256>`: the sha256 of the sorted, percent-encoded
  population it WALKED (one token per line, newline-terminated); it must equal the sha256 of the
  `--emit-population` output, else the class is COULD-NOT-INSPECT. `--emit-population` only enumerates.
- Percent-encoding: `location`, `evidence_ref`, a COULD-NOT-INSPECT `part` and every population item are
  single canonical tokens — every byte outside `A-Z a-z 0-9 . _ ~ / + : @ , = -` is `%XX` (uppercase hex),
  and a safe byte is never encoded. A live FINDING location must be a population item OR a path tracked at
  `--root`, either optionally followed by `:` and a suffix (see Paths below); a line that fails any rule,
  carries a forbidden byte sequence or is not valid UTF-8 is rejected and the class is COULD-NOT-INSPECT.
  The shared helper is in `docs/zero-gap/README.md`.
- A population item or live FINDING location under `_tests/fixtures/zero-gap/` makes the class
  COULD-NOT-INSPECT, naming it.
- Budgets: `ZG_CLASS_BUDGET` (default 900 s, all runs of one class) and `ZG_SWEEP_BUDGET` (default
  10800 s); each class runs in its own process group (`setsid`); on overrun, or when a class exits leaving
  processes in its group, that group only is sent TERM then KILL, and the class is COULD-NOT-INSPECT.
- Environment: the runner re-executes itself ONCE as `env -i <allow-list> bash --norc --noprofile` (guard
  `ZG_SWEEP_REEXEC` equal to its own pid); runner and classes also get `GIT_CONFIG_COUNT=2` pinning
  `core.excludesFile` and `core.attributesFile` to `/dev/null` (git's implicit XDG ignore/attributes).
  `SHELLOPTS=noexec` and `BASH_ENV`/`ENV` reach the FIRST bash before line 1 and cannot be refused
  (`noexec` gives rc 0 with EMPTY output, measured): a consumer must require the `VERDICT` line, never
  treat a bare rc 0 as a pass. Runner allow-list: `PATH HOME TMPDIR USER LOGNAME XDG_RUNTIME_DIR
  ZG_CLASS_BUDGET ZG_SWEEP_BUDGET ZG_IGNORED_EXCLUDE` (when set) plus `LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null
  GIT_CONFIG_SYSTEM=/dev/null GOTOOLCHAIN=local GOMAXPROCS` (default 4). Classes run under `env -i` with only
  `PATH HOME TMPDIR USER LOGNAME XDG_RUNTIME_DIR` (when set), `LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null
  GIT_CONFIG_SYSTEM=/dev/null GOTOOLCHAIN=local GOMAXPROCS PYTHONDONTWRITEBYTECODE=1` and `ZG_RUN` (a random
  token of the run).
- Processes: after every class invocation the runner scans `/proc` for processes of its uid still carrying
  `ZG_RUN` (a descendant that left the class process group, e.g. via `setsid`); all are frozen (SIGSTOP) with
  rescans until no new one appears, then KILLed by pid after re-reading each start time; the class is
  COULD-NOT-INSPECT. A descendant that drops `ZG_RUN` and leaves the group is not found; the only containment
  that would close that here is a cgroup scope (`systemd-run --user --scope`, available on this host) — not
  adopted (recorded residual). A group is signalled only when
  verified as the run's (leader start time, or a member carrying `ZG_RUN`).
- Bytes: a class output (or population, or expect.tsv) carrying NUL, invalid UTF-8, a C1 control, U+2028/9, a
  direction mark/embedding/override/isolate (including U+061C) or U+FEFF is rejected whole (COULD-NOT-INSPECT).
- Paths: location, evidence_ref, part and population items are normal relative paths per `:`-separated segment
  (no `./`, `../`, `//`, absolute path or empty segment); the fixture exclusion matches
  `(^|/|:)_tests/fixtures/zero-gap/`. `evidence_ref` must name a REGULAR file (or `file:suffix`) whose real
  path is inside `--root` (live) or the corpus directory (corpus runs), outside any `.git` directory, and not
  matching the fixture pattern. A live location may be a population item OR a path tracked at
  `--root`, each optionally followed by `:suffix`.
- Output rendering is linear in the number of findings (one awk pass per section).
- Registration: see `docs/zero-gap/README.md` "Registering a class" (TSV rows pre-seeded; each class task
  appends one registry row; nobody stages; one wave commit by the controller).

Input: `docs/zero-gap/sweep-classes.tsv` (schema in data-model.md). The class list is DATA; adding a
class is a data change plus its planted corpus.

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
