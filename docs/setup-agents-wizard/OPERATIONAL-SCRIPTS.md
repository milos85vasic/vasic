# Operational Scripts

Three scripts sit beside the wizard and handle the things that go wrong *after* installation:
a corrupting embedding backend, an index that has to be rebuilt because of it, and the
question "is this index actually trustworthy?"

| Script | One line | Mutates anything? |
| :--- | :--- | :--- |
| [`scripts/ollama-vulkan-remediation.sh`](#ollama-vulkan-remediationsh) | Take the GPU out of ollama's embedding path | Only with `--apply` / `--rollback` (both need `sudo`) |
| [`scripts/lumen-reindex.sh`](#lumen-reindexsh) | Rebuild a Lumen index, refusing to run on a backend known to corrupt it | Yes — writes the index and a log file |
| [`scripts/lumen-index-doctor.sh`](#lumen-index-doctorsh) | Detect **silently** corrupt embeddings in an existing index | No. Read-only, always |

They are deliberately separate from `scripts/setup-agents-wizard.sh`. The wizard **observes and
reports**; it never restarts a service, never writes under `/etc`, and never calls `sudo` in the
embedding path. Test `A41` enforces that. Anything privileged lives here, behind an explicit
subcommand, so applying a host-wide change is always a decision someone made on purpose.

> **Why these exist at all:** on 2026-08-26 this project's Lumen index was found to contain
> **758 stale duplicate vectors** spanning **695 distinct texts across 55 files**, written under
> HTTP 200 by an ollama runner using `library=Vulkan` on an Intel iGPU. Read
> [`INDEX-CORRUPTION-RECONCILIATION.md`](./INDEX-CORRUPTION-RECONCILIATION.md) for the settled
> forensic verdict and [`OLLAMA-REMEDIATION.md`](./OLLAMA-REMEDIATION.md) for the runbook.

---

## The four failure modes these scripts are built around

All three scripts share one model of the defect. A large embedding batch trips an i915 fence
timeout; the kernel abandons the dispatch and **ollama reads the result buffer anyway**. What
comes back depends on what was in that buffer:

| # | Signature | HTTP | Visible to a per-vector check? |
| :-- | :--- | :--- | :--- |
| 1 | `{"error":"…unsupported value: NaN"}` | 500 | Yes — loud, impossible to miss |
| 2 | All-zero vector | **200** | Yes — a zero-norm test catches it |
| 3 | Runner wedges; every later request returns `NaN` until the model is unloaded | 500 | Yes, but usually **misattributed** to the caller |
| 4 | **A repeated STALE vector** — well-formed, 768 dims, unit norm | **200** | **NO.** Invisible to NaN, Inf, all-zero and L2-norm checks alike |

**Mode 4 is the one that matters.** It is what corrupted the index, and it is why every probe in
these scripts tests **aggregate distinctness** — *N* distinct input texts must produce *N*
distinct output vectors — instead of inspecting vectors one at a time. Tests `I7` and `I8` exist
specifically to stop that check being quietly removed.

---

## `ollama-vulkan-remediation.sh`

```
./scripts/ollama-vulkan-remediation.sh [--check | --apply | --verify | --rollback | --help]
```

**Default is `--check`** — running it with no argument does a read-only diagnosis and nothing
else (test `I6` asserts the literal `case "${1:---check}"`). You cannot accidentally reconfigure
your host by forgetting an argument.

### What the fix actually is

One line appended to `/etc/sysconfig/ollama`:

```
GGML_VK_VISIBLE_DEVICES=-1
```

The packaged unit already sources that file optionally (`EnvironmentFile=-`), so nothing
packaged is edited and no drop-in is created. After a service restart ollama never discovers
the Vulkan device, and its own journal reports `library=cpu`.

> **`OLLAMA_VULKAN=false` and `OLLAMA_LLM_LIBRARY=cpu` are both NO-OPS on this build.** They were
> tested. `OLLAMA_VULKAN` is *already* false in the running service and Vulkan is used anyway.
> `GGML_VK_VISIBLE_DEVICES=-1` is the only variable that changes the outcome.

The model **name** does not change, which is the whole point: Lumen keys each index database by
`project_meta.embedding_model`, so switching `LUMEN_EMBED_MODEL` to a CPU-pinned copy would
start a second index from zero and orphan the existing one. Disabling Vulkan daemon-wide keeps
the model name *and* the index.

### The subcommands

| Flag | Privileged? | What it does |
| :--- | :--- | :--- |
| `--check` *(default)* | no | Reports the backend library, whether `/etc/sysconfig/ollama` carries the flag, the i915 fault count, and runs the 32-vector batch probe. Writes nothing. |
| `--apply` | **yes — `sudo`** | Appends the flag to `/etc/sysconfig/ollama` if absent, `sudo systemctl restart ollama`, sleeps 6 s, then runs `--verify`. |
| `--verify` | no | Asserts `library=cpu` *and* a clean batch probe. This is the only subcommand whose exit status is a meaningful pass/fail. |
| `--rollback` | **yes — `sudo`** | `sed`s the flag line out of `/etc/sysconfig/ollama`, restarts ollama, warns that the corrupting path is back, then runs `--check`. |
| `--help` / `-h` | no | Prints the script's comment header. |

### The four things `--check` reports

1. **Backend library.** Read from ollama's own journal, scanned **from the service's
   `ActiveEnterTimestamp`** rather than a fixed `tail`. `library=` is logged once at start-up, so
   a fixed tail on a busy log pushes it out of range and reports `UNKNOWN`. An unreadable journal
   is reported as `UNKNOWN` — never guessed at.
2. **Whether `/etc/sysconfig/ollama` contains the flag.** Three outcomes: present, file exists
   without the flag, file absent entirely.
3. **i915 fault count *since ollama started*.** Deliberately not a 24-hour window: on a host that
   was just remediated, the last 24 h still contain the pre-fix history, and a 24 h count would
   cry wolf forever. When the since-start count is 0 and the 24 h count is not, the older number
   is printed as informational context.
4. **The batch probe.** 32 distinct short functions, each repeated 12×, sent as one `/api/embed`
   request. It requires **32 of 32 distinct vectors back**. `DEGENERATE n/32` means mode 4.
   `MALFORMED` means the response could not be parsed as embeddings at all.

### Exit codes

| Code | When |
| :--- | :--- |
| `0` | `--check`, `--rollback`, `--help`, and a `--verify` / `--apply` that passed |
| `1` | `--verify` failed the batch probe; or `--apply` / `--rollback` could not write `/etc/sysconfig/ollama` or could not restart the service |
| `2` | Unrecognised option |

> **`--check` does not signal through its exit status.** It ends `0` whatever it finds — even
> `library=Vulkan` with a degenerate probe. Read its output, or use `--verify`, which does fail
> loudly. Automating on `--check`'s exit code will silently pass on a corrupting host.

### What it will **not** do

- **It will not change `LUMEN_EMBED_MODEL`.** That would orphan your index.
- **It will not repair vectors already written.** It changes what happens next. Everything
  written while Vulkan was active stays wrong — see [`lumen-reindex.sh`](#lumen-reindexsh).
- **It will not fix the upstream bug** (llama.cpp [#18969], [#26044]; ollama [#13086], [#15248]).
  It avoids it. Upgrading ollama does not help.
- **It will not run `--apply` for you.** No subcommand escalates on its own, and the wizard never
  invokes this script — it only *tells you to*.
- **It will not scope the change to embeddings.** `GGML_VK_VISIBLE_DEVICES=-1` disables Vulkan
  for **everything** the daemon serves, chat models included. That is the stated price.

### When to reach for it

Run `--check` whenever a search returns something that feels wrong, whenever the wizard prints
the `library=Vulkan` warning, or as the first step of any embedding investigation. Run `--apply`
once, deliberately, when `--check` confirms `library=Vulkan`. Run `--verify` after any ollama
upgrade or host reboot — a package update that replaces the unit or the environment file puts
you straight back on the corrupting path with no other warning.

---

## `lumen-reindex.sh`

```
./scripts/lumen-reindex.sh [project-path] [--force] [--allow-gpu]
```

A resilient wrapper around `lumen index`. `project-path` defaults to `$(pwd)`; a leading `--`
argument is recognised as a flag rather than a path, so `./scripts/lumen-reindex.sh --force`
targets the current directory as expected.

### It refuses to start on a Vulkan backend

This is its defining behaviour and test `I11` guards it:

```
REFUSING TO START: ollama reports library=Vulkan.
That path silently writes stale duplicate vectors. Fix it first:
  ./scripts/ollama-vulkan-remediation.sh --apply
Override with --allow-gpu if you accept the risk.
```

→ **exit 3.** `--allow-gpu` downgrades the refusal to a warning and proceeds.

> **Caveat, from the code:** this script reads the backend library from the **last 400 journal
> lines** (`journalctl -u ollama -n 400`), not from the service start timestamp the way
> `ollama-vulkan-remediation.sh` does. `library=` is logged once at start-up, so on a host whose
> ollama has been up a long time under load, that line has scrolled out and the script logs
> `backend library UNKNOWN (journal unreadable) - continuing` and runs anyway. **The refusal is
> best-effort, not a guarantee.** The batch probe below is the check that always runs.

### Then it probes for mode 4 before writing anything

Independently of the journal, it sends the same 32-distinct-texts batch and requires 32 distinct
vectors. On failure it unloads the model (`ollama stop`) to clear a wedged runner, waits 5 s and
retries once. Still failing → **exit 4**, nothing indexed.

### Then it loops

Up to `MAX_ROUNDS` (default 40) rounds. Each round:

1. Health-check `/api/embed` with a trivial input; reset the runner if unhealthy.
2. Run `lumen index` (with `-f` on the first round if `--force` was given).
3. `rc=0` → done, exit 0.
4. Otherwise: drop `-f` (a forced rebuild only needs forcing once — later rounds resume), then
   either reset the runner (if the output mentions `NaN` or `embedding servers exhausted`) or
   back off 30 s.

Every round is appended to the log **and** echoed to stdout.

### `--force` is not optional after a corruption event

A corrupted file still carries a non-empty content hash in the index, so an **incremental** run
treats it as already done and skips it — *forever*. `--force` maps to `lumen index -f`, which
re-embeds everything. Tests `I12` (the flag really reaches `lumen index -f`) and `I13` (the
reason is documented in the script) guard this.

### Flags, environment and exit codes

| Argument | Effect |
| :--- | :--- |
| `[project-path]` | Project to index. Default `$(pwd)`. |
| `--force` | Full rebuild — `lumen index -f` on round 1. **Required after corruption.** |
| `--allow-gpu` | Proceed despite `library=Vulkan`. Off by default, on purpose. |

Unrecognised flags are **silently ignored**; there is no argument validation. A typo like
`--forse` gets you an incremental run with no complaint.

| Variable | Default | Effect |
| :--- | :--- | :--- |
| `MAX_ROUNDS` | `40` | Retry rounds before giving up |
| `LUMEN_REINDEX_LOG` | `<project>/.lumen-reindex.log` | Where the run log is appended |
| `LUMEN_EMBED_MODEL` | `ordis/jina-embeddings-v2-base-code` | Model used by both probes |
| `OLLAMA_HOST` | `http://localhost:11434` | Backend endpoint |

| Code | Meaning |
| :--- | :--- |
| `0` | Index completed (`lumen index` returned 0) |
| `1` | Gave up after `MAX_ROUNDS` rounds |
| `3` | **Refused to start**: backend reports `library=Vulkan` and `--allow-gpu` was not given |
| `4` | Batch probe still failing after a runner reset — the backend is not safe to index with |

### What it will **not** do

- **It will not use `sudo`.** Test `I14` asserts the string is absent from this script and the
  doctor alike.
- **It will not fix the backend.** It refuses, and points at the remediation script.
- **It will not purge.** It never calls `lumen purge`; nothing here deletes an index.
- **It will not verify the result.** Run `lumen-index-doctor.sh` afterwards — a `lumen index`
  exit code of 0 says the run finished, not that the vectors are good.
- **It will not install Lumen.** It prepends `~/.local/bin` to `PATH` and assumes the wizard put
  the launcher there. With `lumen` genuinely missing, every round fails and you wait out 40
  rounds of 30 s back-off (~20 minutes) before exit 1.

### When to reach for it

After applying the Vulkan remediation (`--force`, mandatory). After
`lumen-index-doctor.sh` exits 1 (`--force`, mandatory). And as the general-purpose way to run a
long index unattended, because it survives the transient backend faults that make a bare
`lumen index` die halfway with Lumen's usage text on screen.

---

## `lumen-index-doctor.sh`

```
./scripts/lumen-index-doctor.sh [project-path]
```

Read-only inspection of the index a project actually uses. It globs
`${LUMEN_STORE:-$HOME/.local/share/lumen}/*/index.db`, opens each **`file:…?mode=ro`** (test
`I10`), and picks the one whose `project_meta.project_path` resolves to your project. No write
is ever issued and no `lumen` subcommand is invoked, so it is safe to run while an index is
building.

### What it reports

```
index: /home/you/.local/share/lumen/<hash>/index.db
model: ordis/jina-embeddings-v2-base-code
integrity_check: ok
files: 2413 fully indexed, 0 queued placeholders | chunks: 35717
vectors: 35717 total, 34959 distinct
❌ 1 duplicate-vector group(s); 758 vectors (2.12%) are not unique
   largest identical group: 758 copies of ONE vector
per-vector: 0 NaN/Inf, 0 all-zero, 0 off-norm
```

- **`integrity_check`** — SQLite's own `PRAGMA integrity_check`.
- **File accounting** — a row in `files` with an empty `hash` is a queued placeholder, not an
  indexed file. This is how you tell "2413 files" from "2413 files *done*".
- **Aggregate distinctness** — the shadow table `vec_chunks_vector_chunks00` is decoded directly
  as contiguous little-endian float32, 768 dims per vector, and identical byte sequences are
  counted. **This is the test the earlier forensic audit did not complete**, and the only one
  that sees failure mode 4.
- **Per-vector checks** — NaN/Inf, all-zero, and L2 norm outside `0.99–1.01`, retained because
  they catch the louder modes. Note these are computed over **distinct** vectors, so the numbers
  are counts of distinct bad vectors, not of affected chunks.

### Exit codes

| Code | Meaning |
| :--- | :--- |
| `0` | Healthy — or "no vectors stored yet", which also exits 0 with a warning line |
| `1` | **Corruption found** |
| `2` | Could not inspect: no index found for that project under the store |

**What actually sets exit 1** — read this before wiring it into anything:

- any NaN/Inf, all-zero, or off-norm vector; **or**
- a duplicate-vector group whose **largest** member count is **≥ 10**.

A handful of genuinely identical vectors (real duplicated boilerplate) is plausible, so small
groups are **printed with a ❌ line but do not set the exit code**. If you are gating on this
script, gate on the output as well as the status.

> **Two caveats the code makes plain.** The decoder hardcodes `DIM = 768` and the shadow-table
> name `vec_chunks_vector_chunks00`. If a future Lumen changes either, the embedded Python
> raises, and an unhandled exception also exits `1` — indistinguishable from "corruption found"
> unless you read the traceback. Separately, the script initialises a `wrongdim` counter that is
> never incremented or printed: **wrong-dimension vectors are not actually checked**, despite
> being one of the columns in the forensic report.

### What it will **not** do

- **It will not write, repair, or purge anything.** It has no remediation path at all.
- **It will not use `sudo`** (test `I14`).
- **It will not call the embedding backend.** It reads the database only — which is precisely
  why it is safe to run mid-index.
- **It will not tell you *which files* are affected.** It reports group sizes and percentages.
  The file-level breakdown lives in
  [`INDEX-CORRUPTION-RECONCILIATION.md`](./INDEX-CORRUPTION-RECONCILIATION.md) §5.

### When to reach for it

Before trusting a search result you find surprising. After any `lumen-reindex.sh --force`. After
`ollama-vulkan-remediation.sh --apply`, to confirm the *index* is clean and not merely the
*backend*. And periodically on any host that has ever run embeddings on a GPU — a per-vector
health check will keep telling you everything is fine.

---

## The standard sequence

```bash
# 1. Is the backend safe?
./scripts/ollama-vulkan-remediation.sh --check

# 2. If it reports library=Vulkan — fix it (sudo, one restart), then prove it
./scripts/ollama-vulkan-remediation.sh --apply

# 3. Is the existing index already poisoned?
./scripts/lumen-index-doctor.sh "$PWD"          # exit 1 => yes

# 4. Rebuild. --force is mandatory: corrupted files keep their hash and are
#    skipped forever by an incremental run.
./scripts/lumen-reindex.sh "$PWD" --force

# 5. Confirm
./scripts/lumen-index-doctor.sh "$PWD"          # exit 0 => clean
```

Step 3 is the one people skip, and it is the one that matters: the backend being fixed today
says nothing about the vectors written last week.

---

## Relationship to the wizard and the rollback manifest

`scripts/setup-agents-wizard.sh` never calls these scripts. When it detects `library=Vulkan` it
adds an **ACTION REQUIRED** entry naming the remediation commands, and when it cannot confirm a
usable index it adds one naming the reindex and doctor commands — see
[`ACTION-REQUIRED.md`](./ACTION-REQUIRED.md).

**None of the three writes to the wizard's rollback manifest.** They are outside that
transaction, so `scripts/rollback-agents-wizard.sh` will not undo them:

| Change | How to undo it |
| :--- | :--- |
| `GGML_VK_VISIBLE_DEVICES=-1` in `/etc/sysconfig/ollama` | `./scripts/ollama-vulkan-remediation.sh --rollback` |
| A rebuilt Lumen index | `lumen purge <path>`, then re-index |
| `<project>/.lumen-reindex.log` | `rm` it; nothing reads it back |

---

## Test coverage — group `I`

`scripts/test-setup-agents-wizard.sh` covers all three in group **I**:

| Test | Asserts |
| :--- | :--- |
| `I1`–`I3` | Each script is executable and parses (`bash -n`) — one record per script |
| `I4`, `I5` | The remediation script offers `--check` and `--rollback` |
| `I6` | It **defaults** to the read-only action |
| `I7` | Its probe tests aggregate **distinctness**, not per-vector health |
| `I8` | The doctor checks duplicate-vector groups |
| `I9` | The doctor still runs the per-vector NaN / all-zero checks |
| `I10` | The doctor opens the database `mode=ro` |
| `I11` | Reindex refuses to start on a Vulkan backend |
| `I12` | `--force` is parsed **and** actually reaches `lumen index -f` (behavioural, not a grep) |
| `I13` | Reindex documents why `--force` is required after corruption |
| `I14` | Neither reindex nor doctor calls `sudo` |

Fourteen records in total: eleven assertions plus the three-script parse loop.

---

## Known rough edges

Verified against the current sources, and listed here so nobody re-reports them:

- **`--help` over-prints.** `ollama-vulkan-remediation.sh --help` runs `sed -n '2,40p'` over
  itself, but the comment header ends at line 34 — so the last six lines of "help" are the
  script's own `set -uo pipefail` and colour definitions. Harmless, confusing.
- **The applied file is bare.** `--apply` appends the single line
  `GGML_VK_VISIBLE_DEVICES=-1`. The runbook's Step 2 heredoc writes the same line with an
  explanatory comment block and `chmod 0644`. If `/etc/sysconfig/ollama` on your host has no
  comment header, it was written by the script, not by hand.
- **`--check` always exits 0** (see above).
- **The doctor does not check dimensions** despite the dead `wrongdim` counter.
- **`lumen-reindex.sh` ignores unknown flags** and reads the journal by fixed tail.

---

## Related

- [`OLLAMA-REMEDIATION.md`](./OLLAMA-REMEDIATION.md) — the full operator runbook, all three
  tiers, and the resolution record for this host.
- [`INDEX-CORRUPTION-RECONCILIATION.md`](./INDEX-CORRUPTION-RECONCILIATION.md) — the settled
  verdict on what was in the index. **Historical record; do not edit.**
- [`OLLAMA-NAN-WEDGE.md`](./OLLAMA-NAN-WEDGE.md) — the original evidence and harness for the
  loud failure modes. **Historical record; do not edit.**
- [`LUMEN-INDEX-INTEGRITY.md`](./LUMEN-INDEX-INTEGRITY.md) — the earlier audit that concluded
  "TRUSTWORTHY". Its measurements are correct; its conclusion is **superseded**. **Historical
  record; do not edit.**
- [`ACTION-REQUIRED.md`](./ACTION-REQUIRED.md) — how the wizard surfaces these scripts.
- [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md) — symptom-first entry points.

[#18969]: https://github.com/ggml-org/llama.cpp/issues/18969
[#26044]: https://github.com/ggml-org/llama.cpp/issues/26044
[#13086]: https://github.com/ollama/ollama/issues/13086
[#15248]: https://github.com/ollama/ollama/issues/15248
