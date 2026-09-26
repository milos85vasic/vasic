# Zero-gap sweep — runner, class contract, registration

| Field | Value |
|---|---|
| Feature | 010 zero-gap verified closure (tasks T017, T018) |
| Runner | `scripts/zero-gap-sweep.sh` (registered check `zero-gap-sweep`) |
| Class list (data) | `docs/zero-gap/sweep-classes.tsv` |
| Catalogues (data) | `docs/zero-gap/toolchains.tsv`, `docs/zero-gap/guarded-commands.tsv` |
| Runner contract | `specs/010-zero-gap-verified-closure/contracts/sweep-runner.md` |
| Revision | 4 — 2026-09-26 (fix round 3: implicit git ignore/attributes pinned, ignored-path removals and cp -p, .git hooks/info in the fingerprint, stricter evidence_ref, freeze-then-kill escapees, U+061C, SHELLOPTS=noexec residual) |

## Contents

1. [What the sweep does](#what-the-sweep-does)
2. [The class list](#the-class-list)
3. [The class contract](#the-class-contract)
4. [Percent-encoding helper](#percent-encoding-helper)
5. [Corpora and the recall engine](#corpora-and-the-recall-engine)
6. [Isolation: environment, budgets, fingerprint windows](#isolation-environment-budgets-fingerprint-windows)
7. [Registering a class](#registering-a-class)
8. [Rules for class implementers](#rules-for-class-implementers)
9. [The demonstration class and golden output](#the-demonstration-class-and-golden-output)
10. [What this does not claim](#what-this-does-not-claim)

## What the sweep does

`bash scripts/zero-gap-sweep.sh` reads the class list, runs every class, measures each class's recall
on its planted-defect corpus, and prints one sorted report: `FINDING` lines, `COULD-NOT-INSPECT`
lines, one `CLASS` line per class, the state fingerprint before and after, and a `VERDICT` line.

- **rc 0** means: no finding, and every class inspected its full non-empty population with **recall 1.0
  and zero false positives** (a missed planted defect and a finding on a clean control are themselves
  FINDINGs, so rc 0 cannot coexist with either).
- **rc 1**: at least one FINDING. A finding outranks a class-level undetermined.
- **rc 2** otherwise, including a tree that moved during the run (`VERDICT UNSTABLE`) — rc 2 even with
  findings. **T036 (the baseline) and every register seeding step MUST refuse FINDING lines from an
  UNSTABLE run**: they describe no single state.

The option list and output grammar are in the runner's header (`--help`). The runner never writes into
the swept tree; `--out <dir>` also writes the report (temp file + `mv`) under
`<root>/.remember/logs/zero-gap/` and nowhere else.

## The class list

`docs/zero-gap/sweep-classes.tsv` — tab-separated, `#` comments allowed, one header, one row per class:

| Column | Rule |
|---|---|
| `class_id` | `[a-z0-9]` words joined by `-`; unique; `sweep`, `evidence`, `registers` are reserved |
| `population` | what the class enumerates, DERIVED from a named tracked source — never a hand list |
| `population_why` | why that set is the right set (constitution: "A Gate's Population Is Part of Its Claim") |
| `window` | the comparison window when bounded, else `none` |
| `entrypoint` | exactly `scripts/zero-gap-class-<class_id>.sh` |
| `corpus` | exactly `_tests/fixtures/zero-gap/<class_id>/` |
| `recall` | the last PUBLISHED figure, `UNKNOWN` or a number in 0..1 — never read as a measurement |
| `population_kind` | `source`, `process` or `wire` (FR-014, FR-017) |

Any defect makes the runner exit 2 before it runs anything; an empty list is rc 2. All 17 rows are
pre-seeded (T017); a class task does NOT edit this file. A listed class whose script does not exist is
`COULD-NOT-INSPECT <id>:- class not implemented …` with `status=not-implemented` on every run. A
`scripts/zero-gap-class-*.sh` that no row lists is `FINDING sweep medium governance-drift …`.

## The class contract

A class is `scripts/zero-gap-class-<id>.sh`, invoked with cwd `<root>` and stdin `/dev/null`:

| Invocation | Meaning |
|---|---|
| `--root <abs dir> --emit-population` | print the live population: one canonical token per line, sorted and unique under `LC_ALL=C`; exit 0 (2 if it cannot enumerate). It must ONLY enumerate — any write is caught by the fingerprint window |
| `--root <abs dir>` | inspect the live tree |
| `--root <abs dir> --corpus <abs dir>` | inspect the corpus directory instead (population = the files under it; locations relative to it) |

Stdout carries these lines and nothing else (blank lines are ignored):

```
FINDING <class_id> <severity> <category> <location> <one-line description> <evidence_ref>
COULD-NOT-INSPECT <part> <reason>
INSPECTED <n>
POPULATION-SHA <sha256>
```

- `severity` ∈ `critical high medium low`; `category` ∈ `security data-integrity false-evidence
  content-boundary availability build-freshness governance-drift docs-drift test-coverage
  ux-accessibility host-capability other` (data-model.md rubric).
- `location`, `evidence_ref`, `part` and every population item are **single canonical
  percent-encoded tokens**: every byte outside `A-Z a-z 0-9 . _ ~ / + : @ , = -` is written `%XX`
  (uppercase hex) — blank `%20`, `%` itself `%25`, tab `%09`, newline `%0A`, UTF-8 bytes too (`é` is
  `%C3%A9`) — and a safe byte is never encoded. Use the helper below; do not hand-roll it.
- Every token is a normal RELATIVE path in each `:`-separated segment: no leading `/`, no `./` or `../`
  segment, no `//`, no empty segment (`./notes/ok.txt`, `/etc/x`, `a//b`, `a:` are rejected).
- A live FINDING's location must be a population item, OR a path tracked at `--root` (`git ls-files`),
  either optionally followed by `:` and a suffix (for example `path:line`). This makes an unencoded blank
  detectable (`notes/a b.txt` splits into location `notes/a`, which is neither) and lets a class point at a
  line of any tracked file. A location or item matching `(^|/|:)_tests/fixtures/zero-gap/` is rejected.
- `evidence_ref` is validated exactly like a location and must be **an existing regular file**
  (optionally followed by `:suffix`) whose real path lies inside `--root` (live runs) or inside the corpus
  directory (corpus runs), outside any `.git` directory, and not matching the corpus-fixture pattern. A directory
  (`notes`), `.git/config`, a symlink leading out of the tree, a corpus fixture file, and a split or
  invented reference are all rejected.
- The description is one line of valid UTF-8 with no control character. The whole output is rejected
  when it carries a NUL byte, invalid UTF-8, a C1 control (U+0080–U+009F), U+2028/U+2029, a direction
  mark, embedding, override or isolate (U+200E/F, U+061C, U+202A–E, U+2066–9) or a BOM (U+FEFF).
- `INSPECTED <n>` appears exactly once and states how many population items the class actually read.
- `POPULATION-SHA <sha256>` appears exactly once: the sha256 of the sorted, encoded population the run
  WALKED, one token per line, each followed by a newline — byte-identical to what
  `--emit-population` prints (`printf '%s\n' "$tokens" | sha256sum`). The runner compares it with the
  sha of the `--emit-population` output, so a run that walks a different set of the same size is caught.
- Exit code and output must agree: 0 no FINDING, 1 at least one FINDING, 2 at least one
  COULD-NOT-INSPECT.
- The live population must EXCLUDE `_tests/fixtures/zero-gap/` (corpora are deliberately defective).
  The runner enforces it: a population item or live FINDING location there makes the class
  COULD-NOT-INSPECT, naming the item.
- Deterministic: the same state gives the same bytes.
- Never write into `--root`, and never leave processes behind (see Isolation).
- Registry requirements (so the appended row holds): executable; a `--prove-failure)` case arm that
  **starts its own line** (`scripts/verify-check-registry.sh` matches the arm at the start of a line, so
  a one-line `case "$1" in --prove-failure) …` is not recognised) and whose body builds a throwaway
  fixture (`mktemp` + `trap` + cleanup) and exercises a planted defect; `--root /nonexistent` exits 2.

Any violation — a malformed line, a non-canonical token, a control character, invalid UTF-8, a
missing `INSPECTED`/`POPULATION-SHA`, a disagreeing exit code, fewer items inspected than enumerated,
a different set walked — makes the class COULD-NOT-INSPECT; a FINDING line that cannot be validated
is not accepted (it is counted and reported, never silently kept).

## Percent-encoding helper

Copy this block verbatim into a class (the runner and the demonstration class carry the identical
block, and the proof checks that this README's copy equals the fixture's):

```bash
# >>> zg_pct_encode (feature 010 class contract; copy verbatim)
# zg_pct_encode_z: NUL-separated raw items on stdin -> one canonical token per line.
# Every byte outside A-Z a-z 0-9 . _ ~ / + : @ , = - becomes %XX (uppercase hex).
zg_pct_encode_z() {
    LC_ALL=C od -An -v -tx1 | LC_ALL=C awk '
        BEGIN { hx = "0123456789abcdef"; safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-"; tok = ""; pending = 0 }
        { for (i = 1; i <= NF; i++) {
              if ($i == "00") { print tok; tok = ""; pending = 0; continue }
              pending = 1
              v = (index(hx, substr($i, 1, 1)) - 1) * 16 + index(hx, substr($i, 2, 1)) - 1
              c = (v > 32 && v < 127) ? sprintf("%c", v) : ""
              if (c != "" && index(safe, c) > 0) tok = tok c; else tok = tok "%" toupper($i)
          } }
        END { if (pending) print tok }'
}
# zg_pct_encode <string>: one item -> one canonical token.
zg_pct_encode() { printf '%s\0' "$1" | zg_pct_encode_z; }
# <<< zg_pct_encode
```

Typical use: `git -C "$ROOT" ls-files -z -- '*.md' | zg_pct_encode_z | LC_ALL=C sort -u`.

## Corpora and the recall engine

`_tests/fixtures/zero-gap/<id>/` holds `planted/`, `clean/` and `expect.tsv` (`<canonical location
relative to planted/>` TAB `<what is planted>`; `#` comments allowed). On every run the class also
runs on `planted/` and `clean/`; `recall = planted locations reported / planted rows` (exact token
match; a class reporting `path:line` must plant `path:line`), recomputed every run, never read from
the TSV. RECALL-MISS (a missed planted defect), RECALL-UNEXPECTED (a finding on an unplanted
`planted/` location), RECALL-FALSE-POSITIVE (any finding on `clean/`) and RECALL-MISMATCH (a
published figure that differs from the measured one) are FINDINGs **located at the class script**
(`scripts/zero-gap-class-<id>.sh`) with the corpus path in the description. No corpus directory ⇒
`recall=UNKNOWN`, `status=unproven` next to no findings, rc 2. A corpus missing a part, planting
nothing, or with a non-canonical location is COULD-NOT-INSPECT.

## Isolation: environment, budgets, fingerprint windows

- **Environment.** The runner re-executes itself ONCE as `env -i <allow-list> bash --norc --noprofile`
  (guard `ZG_SWEEP_REEXEC` = its own pid), so `SHELLOPTS`, exported shell functions, `GIT_*`, `CDPATH`,
  `POSIXLY_CORRECT` and every other inherited variable are gone, and the user's global and XDG git
  config are off (`GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null`), and so are git's IMPLICIT
  `~/.config/git/ignore` and `attributes` (`GIT_CONFIG_COUNT=2` pins `core.excludesFile` and
  `core.attributesFile` to `/dev/null`). Classes run under `env -i`
  with EXACTLY: `PATH HOME TMPDIR USER LOGNAME XDG_RUNTIME_DIR` (each only when set; `TMPDIR` defaults to a
  private directory of the run), `LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  GOTOOLCHAIN=local GOMAXPROCS=<4 unless set> PYTHONDONTWRITEBYTECODE=1`, the same five
  `GIT_CONFIG_COUNT`/`KEY`/`VALUE` pins, and `ZG_RUN` (a random token of the run). A class that needs
  anything else must derive it from tracked files. Two things reach the runner's FIRST bash before its
  first line and cannot be refused by it: a `BASH_ENV`/`ENV` file, and `SHELLOPTS=noexec`, which makes bash
  parse the file, run nothing and exit **0 with empty output** (measured). **A consumer must therefore
  require the `VERDICT HOLDS rc=0` line; an rc 0 without it is not a pass.**
- **Budgets.** `ZG_CLASS_BUDGET` (default 900 s) covers ALL runs of one class; `ZG_SWEEP_BUDGET`
  (default 10800 s = 3 h) covers the sweep. Each class runs in its own session (`setsid`); on overrun,
  or when a class exits leaving processes in its group, the runner sends TERM, then KILL after 2 s, to
  THAT group only, after verifying it is the run's (leader start time, or a member carrying `ZG_RUN`) —
  never a signal by name or pattern — and the class is COULD-NOT-INSPECT. After every invocation the
  runner scans `/proc` for processes of its uid still carrying `ZG_RUN`: every such descendant (one that
  left the group, for example via `setsid`) is FROZEN with SIGSTOP and `/proc` rescanned until no new one
  appears, so an escapee that keeps spawning cannot outrun it; then each is sent KILL, its start time
  re-read before every signal, and the class is reported ("outlived …"). Stated limit: a descendant that
  drops `ZG_RUN` from its environment AND leaves the group is not found. The only containment that would
  close it on this host is a cgroup scope (`systemd-run --user --scope`, measured available, rc 0); an
  unprivileged user namespace is not available (`unshare -Ur` is refused). Adopting a scope is a design
  change not made here — a recorded residual.
- **Fingerprint windows.** The state fingerprint (zg_manifest + HEAD + refs + local config + index +
  the contents of `<git-dir>/hooks` and `<git-dir>/info` + every population file's mtime/ctime/size/inode) is taken before the first class and after every
  class; a change names the class that was running (`COULD-NOT-INSPECT <id>:<path> changed while this
  class ran`, `VERDICT UNSTABLE`). Each window's cost is printed on stderr (about 4 s on the live
  tree). IGNORED paths are outside the fingerprint; every ignored FILE is listed individually and
  stat'ed before and after each class, so one created, removed, written, or replaced by a `cp -p` that
  keeps an old mtime (its ctime moves) is `COULD-NOT-INSPECT <id>:<path> written while this class ran`
  (not UNSTABLE); empty ignored directories are not seen. Excepted is anything under
  `ZG_IGNORED_EXCLUDE` (default `.remember/tmp/:.remember/logs/:.service-registry/qa/`). Reasons:
  `.remember/tmp/` and `.remember/logs/` are written continuously by host session tooling; under
  `.service-registry/qa/` the servers this sweep probes append their own access logs (a read-only GET by
  the live-vs-source class makes the qa-up static servers log it), so without the exclusion that class
  could never come out clean. A write to any OTHER ignored path during a class is still reported.

## Registering a class

Every `scripts/zero-gap-class-<id>.sh` is under the `scripts` scanroot, so R5 of
`scripts/verify-check-registry.sh` fails the moment the file exists without a row, and R3 fails for a
row whose script does not exist. Measured 2026-09-26 on a copy of the tree: a pre-seeded `check` row
for an absent script fails R3, an `exempt` row fails R2 (both rc 1). So the rows cannot be pre-seeded,
and git commits are per file, not per class: staging `scripts/check-registry.tsv` ships every other
class's appended row while their scripts may still be uncommitted (HEAD then fails R3), and a script
without its row fails R5 and blocks pushes. **The protocol (controller ruling, fix round 1):**

1. The `sweep-classes.tsv` rows are PRE-SEEDED (T017). A class task never edits that file.
2. The REGISTRY row is APPENDED by the class task itself, exactly one line, never an edit:

   ```bash
   ID=<class_id>
   printf 'check\tzero-gap-class-%s\tscripts/zero-gap-class-%s.sh\tflag\t--prove-failure\t--root /nonexistent\n' "$ID" "$ID" >> scripts/check-registry.tsv
   ```

   One bash `printf` is one `write(2)` on an `O_APPEND` descriptor; 300 trials of 17 concurrent
   appenders lost or corrupted no line on this ext4 tree (re-measured in this fix round).
3. **Class implementers never stage and never commit anything** — not the script, not the corpus, not
   the registry row; nobody stages during the wave. (The `commit` wrapper stages the whole tree, so per-class commits are impossible.)
4. The controller makes **ONE commit for the whole class wave**, after every class script and its row
   exist and `bash scripts/verify-check-registry.sh` exits 0 on the full wave.

During the wave nobody edits `scripts/check-registry.tsv` with an editor or `sed -i` (a read-modify-
write can drop an appended row; a dropped row is loud — R5 reports the script UNREGISTERED).

## Rules for class implementers

- No daemons, no background processes that outlive the class, no `setsid`: every process you start must
  end before you exit (the runner reports and ends survivors, and the class is COULD-NOT-INSPECT).
- Never write into `--root`. To read a SQLite file (for example `docs/workable_items.db`), COPY it into
  `$TMPDIR` first and open the copy — opening the tracked file can create `-journal`/`-wal` files.
- Python: `PYTHONDONTWRITEBYTECODE=1` is set for you; do not re-enable bytecode writing (`__pycache__`
  writes are caught by the ignored-path detector).
- Remotes: `git ls-remote` only; never `git fetch`, `pull` or any command that writes refs or objects.
- Go: build with `GOMAXPROCS=4 GOTOOLCHAIN=local` (both set for you) into `$TMPDIR`, never into the tree.
- A class that probes a live service must expect that service to log the probe. Such logs are excluded
  only through the runner DEFAULT of `ZG_IGNORED_EXCLUDE` (a reviewed change to the runner), never per
  class.
- Subjects that are not files (a service, a remote, a command id, a claim) are TYPED population tokens,
  for example `service:workshop-platform`, `remote:design-toolkit@gitlab`, `command:add-all` — still
  canonical, still normal relative segments; a finding's location is that token (or `token:suffix`).
- `evidence_ref` must be an existing regular file under `--root` (or `file:line`) — the file that shows
  the defect; never a directory, a symlink out of the tree, anything in `.git/`, or a corpus fixture.
- No `./`, `../`, `//` or absolute tokens anywhere; build tokens with `zg_pct_encode_z` from
  repository-relative paths.
- Exclude `_tests/fixtures/zero-gap/` from the live population.

## The demonstration class and golden output

`_tests/fixtures/zero-gap/sweep/` is fixture-only and never listed: `demo-class.sh` (one file; the proof
copies it as `scripts/zero-gap-class-<mode>.sh` into throwaway repositories and the mode comes from that
name — see its header for the list), ONE golden corpus `corpus/`, and `golden/control.txt` (the control
report with the two fingerprint hashes written `<sha256>`). `bash scripts/zero-gap-sweep.sh
--prove-failure` runs the battery; regenerate the golden file only for a deliberate grammar change,
and review the diff by hand.

## What this does not claim

- A class's recall is only as good as its corpus; recall 1.0 on a small corpus is a floor for that
  corpus, not completeness.
- A class cannot be proven deterministic within one run; T035's harness and the proof's repeat check do that.
- A concurrent editor and the running class cannot be told apart; UNSTABLE says which class was running,
  not who moved the tree. Ignored paths are covered only by the write detector, and only for files
  modified during the class (a same-tick rewrite of a file already modified in the preceding 2 s with an
  identical size is not seen).
