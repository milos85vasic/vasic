# Independent Verification — Pass 2

**Verifier role:** adversarial. Every claim below was treated as false until reproduced.
**Date:** 2026-08-27 (host `nezha`, bash 5.2.37, Linux/x86_64)
**Constraint honoured:** read-only on the real environment. No mutating git, no writes to
`~/.bashrc` / `~/.bash_profile` / agent configs / `/etc`, no `lumen index`, no `lumen purge`,
no `codegraph index|init`, no service restarts. All sandbox work ran under a throwaway `$HOME`
and a throwaway `$CLAUDE_CONFIG_DIR`. The only file created by this pass is this report.

## Scoreboard

| | Count |
|---|---|
| **REFUTED** | **4** |
| VERIFIED | 10 |
| VERIFIED WITH MATERIAL CAVEAT | 2 |
| UNVERIFIABLE | 1 |

Item 4 ("each script does what its header claims") is scored **REFUTED** and carries three
independent defects; items 6 and 10 are scored **VERIFIED WITH MATERIAL CAVEAT** because the
literal claim reproduces but the property a reader would infer from it does not.

---

# ❌ REFUTED — READ THESE FIRST

## ❌ R1 — `lumen-reindex.sh`'s Vulkan guard **cannot fire on this host**. (item 6)

The header sells the script as one that *"refuses to start on a known-bad backend."* The
refusal mechanism works when the probe reports Vulkan (proved in item 6 below) — but on this
machine **the probe can never report Vulkan**, so the guard is dead code in production.

`backend_library()` at `scripts/lumen-reindex.sh:83-86` reads only the **last 400 journal
lines**:

```bash
backend_library() {
    journalctl -u ollama --no-pager -n 400 2>/dev/null \
        | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
}
```

`library=` is logged **exactly once, at service start**. ollama has been up since
09:44:18 and has since written 51,271 journal lines. Reproduced:

```console
$ journalctl -u ollama --no-pager -n 400 2>/dev/null | grep -cE 'library='
0
$ journalctl -u ollama --no-pager -n 400 | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
        <EMPTY>
```

The script therefore takes its `else` branch and **continues anyway**. Forced with a
`journalctl` stub that reproduces exactly this shape (400 lines of runner noise, no
`library=` line):

```console
[18:00:24] === lumen-reindex: .../sb6/proj (force=0) ===
[18:00:24] backend library UNKNOWN (journal unreadable) - continuing
```

The sibling script **already fixed this exact bug and documents why**
(`scripts/ollama-vulkan-remediation.sh:50-61`):

> `library=` is logged once at service start, so scan from THAT moment rather than a fixed
> tail — a busy log otherwise pushes it out and reports UNKNOWN.

Proof the fixed version works on the same host at the same moment:

```console
$ journalctl -u ollama --no-pager --since "$(systemctl show ollama -p ActiveEnterTimestamp --value)" \
    | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
cpu
```

**`lumen-reindex.sh` was not updated with the fix.** Test `I11 reindex refuses to start on a
Vulkan backend` passes because it greps the source for the refusal branch — it never exercises
the detector, so it cannot catch this.

**Fix:** copy `backend_library()` from `ollama-vulkan-remediation.sh` into `lumen-reindex.sh`.

---

## ❌ R2 — `lumen-reindex.sh --help` **starts a full index run** instead of printing help. (item 4)

There is no `--help` handler. The argument loop (`scripts/lumen-reindex.sh:38-43`) only
recognises `--force` and `--allow-gpu`; everything else is silently discarded, and
`PROJ="${1:-$(pwd)}"; [[ "$PROJ" == --* ]] && PROJ="$(pwd)"` (line 36) turns any unrecognised
flag into *"index the current working directory."*

Reproduced in a fully stubbed sandbox (`lumen`, `curl`, `ollama`, `journalctl` all replaced
with sentinel-writing stubs, `env -i`, throwaway `$HOME`, so nothing real was indexed):

```console
$ env -i PATH="$SB/bin:/usr/bin:/bin" HOME="$SB/home" LUMEN_REINDEX_LOG="$SB/reindex.log" \
      bash scripts/lumen-reindex.sh --help
[18:06:53] === lumen-reindex: /run/media/milosvasic/DATA4TB/Projects/vasic (force=0) ===
[18:06:53] backend library=cpu
[18:06:53] batch probe OK: 32 distinct texts -> 32 distinct vectors
[18:06:53] round 1: rc=0 Done.
[18:06:53] === INDEX COMPLETE after 1 round(s) ===
REAL_EXIT_CODE=0

$ cat "$SB/INDEXED_SENTINEL"
STUB LUMEN WAS INVOKED: index /run/media/milosvasic/DATA4TB/Projects/vasic
```

A user asking for help, or typing `--forec` instead of `--force`, silently starts an
unwanted index of `$PWD`. The same class of bug means `--force` is silently dropped when
misspelled — the very flag the header calls *"REQUIRED after a corruption event."*

**Fix:** add `--help|-h)` and a `*) echo "unknown option: $a"; exit 2 ;;` arm to the loop —
`ollama-vulkan-remediation.sh` already does exactly this and returns 2 on `--bogus`.

---

## ❌ R3 — `lumen-index-doctor.sh` returns **1 ("corruption found") when it merely could not inspect**. (items 4, 7)

The header states the contract (`scripts/lumen-index-doctor.sh:19`):

> `Exit 0 = healthy · 1 = corruption found · 2 = could not inspect`

The vector scan at line 65 is unguarded:

```python
for (blob,) in c.execute("SELECT vectors FROM vec_chunks_vector_chunks00"):
```

Against an index whose sqlite-vec shadow table is absent (schema drift, a different Lumen
version, a partially-created DB), python raises and the process exits **1**:

```console
$ LUMEN_STORE="$SB/store" bash scripts/lumen-index-doctor.sh "$SB/novecproj"
integrity_check: ok
files: 0 fully indexed, 0 queued placeholders | chunks: 0
Traceback (most recent call last):
  File "<stdin>", line 40, in <module>
sqlite3.OperationalError: no such table: vec_chunks_vector_chunks00

$ LUMEN_STORE="$SB/store" bash scripts/lumen-index-doctor.sh "$SB/novecproj" >/dev/null 2>&1; echo $?
1
```

Exit 1 is documented as *"corruption found"*, and `lumen-index-doctor.sh` is the script the
other two point operators at. An inspection failure will be read as a corrupt index and will
trigger an unnecessary `--force` rebuild. `sys.exit(2)` fires only for *"no index found at
all"*, which is the one case already obvious from the message.

**Fix:** wrap the vector scan (and the whole body) in `try/except Exception` → print the
reason → `sys.exit(2)`.

---

## ❌ R4 — `ollama-vulkan-remediation.sh --help` **prints 6 lines of the script's own source**. (item 4)

`scripts/ollama-vulkan-remediation.sh:169`:

```bash
--help|-h)  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' ;;
```

The header comment ends at line **34**. Lines 35-40 are executable code, so `--help` dumps them:

```console
$ bash scripts/ollama-vulkan-remediation.sh --help
...
  ./scripts/ollama-vulkan-remediation.sh --rollback  # undo, needs sudo
------------------------------------------------------------------------------
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
bad()  { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
=== EXIT=0
```

**Fix:** `sed -n '2,34p'`, or better, terminate on the first non-`#` line.

---

# Claim table

Legend: ✅ VERIFIED · ⚠️ VERIFIED WITH MATERIAL CAVEAT · ❌ REFUTED · ❔ UNVERIFIABLE

| # | Claim | Verdict |
|---|---|---|
| A1 | `/etc/sysconfig/ollama` contains `GGML_VK_VISIBLE_DEVICES=-1`; journal reports `library=cpu` since current start | ✅ |
| A2 | Zero i915 `fence expiration` / `GPU HANG` lines since that restart | ✅ |
| A3 | One batch of 32 distinct texts → 32 distinct vectors | ❔ see below |
| B4 | Each of the three scripts does what its `--help`/header claims | ❌ **R2, R3, R4** |
| B5 | Remediation with no args defaults to read-only `--check`, modifies nothing | ✅ |
| B6 | `lumen-reindex.sh` exits 3 without indexing on a Vulkan backend | ⚠️ mechanism ✅ / detector dead — **R1** |
| B7 | `lumen-index-doctor.sh` exits 1 on corruption (checked directly, no pipe) | ✅ |
| C8 | Wizard ACTION REQUIRED detection adapts to state, both directions | ✅ |
| C9 | `MANUAL-STEPS.md` is written and gitignored | ✅ |
| C10 | All probes in that section are timeout-bounded | ⚠️ true in that section; **not** true of the wizard overall |
| D11 | `test-setup-agents-wizard.sh --no-live`: exit code, counts, groups, failures | ✅ |
| D12 | Three untold assertions from different groups actually fail when mutated | ✅ all 3 load-bearing; **0 worthless** |
| D13 | Sandboxed groups do not touch the real environment | ✅ |
| E14 | Local HEAD == remote `main`; 5 constitution submodules == their remotes | ✅ (working tree is dirty — see note) |
| E15 | Four root carriers byte-identical from line 24 | ✅ |

---

# Evidence, claim by claim

## A1 ✅ — Vulkan flag present, backend on CPU since the current start

```console
$ cat /etc/sysconfig/ollama
GGML_VK_VISIBLE_DEVICES=-1

$ sha256sum /etc/sysconfig/ollama
713ad8ca3aec6cad10fd2ca85560e229e00694c7692056ff09ebbb7b8d970de6  /etc/sysconfig/ollama

$ systemctl show ollama -p ActiveEnterTimestamp --value
Thu 2026-08-27 09:44:18 CEST

$ journalctl -u ollama --since "2026-08-27 09:44:18" | grep -oE "library=[a-z]+" | sort | uniq -c
      1 library=cpu
```

The daemon confirms it read the override:

```
Aug 27 09:44:18 nezha ollama[832740]: level=WARN source=runner.go:536
    msg="user overrode visible devices" GGML_VK_VISIBLE_DEVICES=-1
Aug 27 09:44:19 nezha ollama[832740]: source=types.go:60 msg="inference compute"
    id=cpu library=cpu compute="" name=cpu ... total="62.6 GiB" available="44.8 GiB"
```

**Honest note (not a refutation):** the Vulkan backend is still *linked in* and emits one
complaint before falling back — `ggml_vulkan: Invalid device index 18446744073709551615 in
GGML_VK_VISIBLE_DEVICES.` (once, 09:45:34). It is the only `ggml_vulkan` line since start, and
inference compute is `library=cpu`. The GPU is out of the path; the message is cosmetic.

## A2 ✅ — zero i915 faults since the restart

```console
$ journalctl -k --since "2026-08-27 09:44:18" | grep -ciE "fence expiration|GPU HANG"
0
```

**The pattern is not vacuous** — it matches 622 lines earlier in the same boot, the last one
8 h 9 min before the restart:

```console
$ journalctl -k -b | grep -ciE "fence expiration|GPU HANG"
622
$ journalctl -k -b | grep -iE "fence expiration|GPU HANG" | tail -1
Aug 27 01:35:01 nezha kernel: Fence expiration time out i915-0000:00:02.0:ollama[2946134]:9afa!
```

The faulting process was `ollama` itself. Nothing since 09:44:18. There are 4,041 kernel lines
in the window, so the journal is being read.

## A3 ❔ — UNVERIFIABLE under load. See "Probe" section at the end of this file.

## B5 ✅ — no-argument run is the read-only `--check` and mutates nothing

`case "${1:---check}"` (line 164) makes `--check` the default. Proved end-to-end. The
built-in batch probe was suppressed by pointing `OLLAMA_HOST` at a dead port, so this run
added **zero** embedding load to the concurrent rebuild — the `do_check` header line and the
i915/envfile findings still prove which branch executed.

```console
$ sha256sum /etc/sysconfig/ollama
713ad8ca3aec6cad10fd2ca85560e229e00694c7692056ff09ebbb7b8d970de6  /etc/sysconfig/ollama
$ systemctl show ollama -p NRestarts,ActiveEnterTimestamp,InvocationID --value
Thu 2026-08-27 09:44:18 CEST
5b04994aa5e94e20b6c371e38c4ff14e
0

$ OLLAMA_HOST=http://127.0.0.1:1 bash scripts/ollama-vulkan-remediation.sh
── ollama embedding backend ──────────────────────────────
✅ library=cpu - GPU is out of the inference path
✅ /etc/sysconfig/ollama contains GGML_VK_VISIBLE_DEVICES=-1
✅ 0 i915 faults since ollama started (Thu 2026-08-27 09:44:18 CEST)
ℹ️  (520 in the last 24h are pre-remediation history)
⚠️  backend unreachable at http://127.0.0.1:1 - cannot probe
EXIT=0

$ sha256sum /etc/sysconfig/ollama
713ad8ca3aec6cad10fd2ca85560e229e00694c7692056ff09ebbb7b8d970de6  /etc/sysconfig/ollama
$ systemctl show ollama -p NRestarts,ActiveEnterTimestamp,InvocationID --value
Thu 2026-08-27 09:44:18 CEST
5b04994aa5e94e20b6c371e38c4ff14e
0
=== DIFF ===
SHA UNCHANGED
SERVICE UNCHANGED
```

`NRestarts=0` and an unchanged `InvocationID` prove the daemon was not restarted.
`--bogus` correctly exits 2. `--apply` and `--rollback` were **not executed** (they call
`sudo tee`/`sudo sed -i` on `/etc/sysconfig/ollama` and `sudo systemctl restart ollama`) —
code-reviewed only, as the read-only constraint requires.

## B6 ⚠️ — the exit-3 mechanism is real; the detector that feeds it is not (see **R1**)

Forced with a stubbed `journalctl` reporting Vulkan, under `env -i` + throwaway `$HOME`, with
`lumen`, `curl` and `ollama` all replaced by sentinel-writing stubs so no indexing and no
embedding traffic was possible:

```console
$ env -i PATH="$SB/bin:/usr/bin:/bin" HOME="$SB/home" STUB_LIB=Vulkan \
      LUMEN_REINDEX_LOG="$SB/reindex.log" bash scripts/lumen-reindex.sh "$SB/proj"
[17:59:53] === lumen-reindex: .../sb6/proj (force=0) ===
[17:59:53] REFUSING TO START: ollama reports library=Vulkan.
[17:59:53] That path silently writes stale duplicate vectors. Fix it first:
[17:59:53]   ./scripts/ollama-vulkan-remediation.sh --apply
[17:59:53] Override with --allow-gpu if you accept the risk.
REAL_EXIT_CODE=3
--- did it index?  sentinel present? ---
NO lumen invocation - did not index
curl never called (no embed traffic)
ollama never called
```

Controls proving the guard is not vacuous — it fires *only* on Vulkan without `--allow-gpu`:

| stub `library=` | flags | exit | guard |
|---|---|---|---|
| `Vulkan` | — | **3** | fired, no indexing, no curl |
| `cpu` | — | 4 | did not fire (reached the batch probe) |
| `Vulkan` | `--allow-gpu` | 4 | did not fire (`WARNING … proceeding`) |
| *(none — real-world journal shape)* | — | 4 | **did not fire — `UNKNOWN … continuing`** |

Exit 4 in the control rows is the stubbed batch probe failing, i.e. the script got *past* the
guard. The last row is **R1**.

## B7 ✅ — doctor exit codes, checked directly (no pipe)

Against synthetic indexes built in a throwaway `LUMEN_STORE` (one with 50 identical
unit-norm 768-dim vectors among 100, one clean, one absent):

```console
$ LUMEN_STORE="$SB/store" bash scripts/lumen-index-doctor.sh "$SB/corruptproj"
index: .../sb7/store/proj-corrupt/index.db
model: ordis/jina-embeddings-v2-base-code
integrity_check: ok
files: 60 fully indexed, 1 queued placeholders | chunks: 100
vectors: 100 total, 51 distinct
❌ 1 duplicate-vector group(s); 50 vectors (50.00%) are not unique
   largest identical group: 50 copies of ONE vector
per-vector: 0 NaN/Inf, 0 all-zero, 0 off-norm

❌ CORRUPTION DETECTED

$ LUMEN_STORE="$SB/store" bash scripts/lumen-index-doctor.sh "$SB/corruptproj" >/dev/null 2>&1; echo $?
1
$ LUMEN_STORE="$SB/store" bash scripts/lumen-index-doctor.sh "$SB/healthyproj" >/dev/null 2>&1; echo $?
0
$ LUMEN_STORE="$SB/store" bash scripts/lumen-index-doctor.sh "$SB/noindexproj" >/dev/null 2>&1; echo $?
2
```

The duplicate group was invisible to every per-vector test (`0 NaN/Inf, 0 all-zero,
0 off-norm`) — exactly the failure mode the header describes. The *"never opens the DB for
writing"* claim also holds: with the DB at mode `444` inside a mode-`555` directory it still
returns 0, and leaves no `-wal`/`-shm`/journal side files.

Caveat, by design but worth stating: the threshold is `groups[0] >= 10`, so a stale-vector
group of 2-9 copies is reported in the output but does **not** set the failure exit code.

## C8 ✅ — the ACTION REQUIRED detection adapts, in both directions

Driven through `SETUP_WIZARD_LIB_ONLY=1` with the detection block extracted **verbatim** from
`scripts/setup-agents-wizard.sh:1249-1260`, under `env -i` with a throwaway `$HOME`,
`$CLAUDE_CONFIG_DIR` and `$PROJECT_ROOT`:

| `$CLAUDE_CONFIG_DIR` state | project genome | manual steps emitted |
|---|---|---|
| `plugins/cache/ashlr-marketplace/ashlr` only | — | **1** — *"Activate the ashlr plugin inside Claude Code"* |
| `+ plugins/marketplaces/ashlr-marketplace` | absent | **1** — *"Initialise the ashlr genome for this project"* (activation step **gone**) |
| `+ plugins/marketplaces/ashlr-marketplace` | present | **0** |

```console
################ DIRECTION 1 ################
CLAUDE_DIR resolved to: .../sb8/cfg
MANUAL_TITLES count: 1
  TITLE: Activate the ashlr plugin inside Claude Code

################ DIRECTION 2: now ALSO create plugins/marketplaces/ashlr-marketplace ################
MANUAL_TITLES count: 1
  TITLE: Initialise the ashlr genome for this project (optional, improves routing)

################ DIRECTION 2b: marketplaces present AND project genome present ################
MANUAL_TITLES count: 0
```

The distinction the comment claims — *cache = the installer cloned it; marketplaces = the
operator actually activated it* — is real and correctly implemented.

## C9 ✅ — `MANUAL-STEPS.md` written and gitignored

```console
$ ls -la MANUAL-STEPS.md
-rw-r--r-- 1 milosvasic milosvasic 913 Aug 27 17:34 MANUAL-STEPS.md
$ git check-ignore -v MANUAL-STEPS.md
.gitignore:72:MANUAL-STEPS.md	MANUAL-STEPS.md
$ git status --porcelain --ignored MANUAL-STEPS.md
!! MANUAL-STEPS.md
```

Content is real, generated (`Generated 2026-08-27T15:34:23Z by scripts/setup-agents-wizard.sh`),
5 steps, each with a runnable command block.

## C10 ⚠️ — bounded *in that section*; the wizard as a whole is not

Every probe **inside the ACTION REQUIRED section** is bounded:

- `scripts/setup-agents-wizard.sh:1263` — `timeout 20 journalctl …` whose `--since` is itself
  `$(timeout 10 systemctl show …)`
- `scripts/setup-agents-wizard.sh:1296` — `timeout 20 lumen search "x" -p … --summary -n 1`

The section-scoped claim is therefore **true**. The broader grep you asked for is **not**:

| line | invocation | bounded? |
|---|---|---|
| 552 | `journalctl -u ollama --no-pager -o cat --since "-30 days"` | **NO** (measured 2.31 s here; unbounded by construction) |
| 870 | `claude mcp get lumen` | **NO** |
| 872 | `claude mcp add-json lumen …` | **NO** |
| 1076 | `lumen index "$PROJECT_ROOT" 2>&1 \| tail -3` | **NO — a full index run with no timeout** |
| 1119 | `claude mcp get lumen` | **NO** |
| 991, 1146 | `timeout 25 mimo mcp list` | yes |
| 1263, 1296 | `timeout 20 journalctl` / `timeout 20 lumen search` | yes |

Line 1076 is the one that matters: `lumen index` on this project has been running for
**8 h 9 min** at the time of writing. It is gated behind `WIZARD_INDEX_PROJECT` (test A25), so
it is opt-in — but when opted in, the wizard has no upper bound at all.

The guarding test is narrower than its name suggests:

```bash
unbounded=$(printf '%s\n' "$src_code" | grep -cE '(^|[^a-z0-9_-])lumen search ' | head -1)
bounded=$(printf '%s\n' "$src_code" | grep -cE 'timeout [0-9]+ lumen search ')
assert_eq "A47 every 'lumen search' probe in the wizard is timeout-bounded" "$unbounded" "$bounded"
```

It covers `lumen search` **only** — not `lumen index`, not `journalctl`, not `claude mcp`.
(The trailing `| head -1` on a `grep -c` is a no-op.)

## D11 ✅ — test suite run

```console
$ bash scripts/test-setup-agents-wizard.sh --no-live
REAL_EXIT_CODE=0
  total=126 passed=119 failed=0 skipped=7
```

`summary.json`:

```json
{"timestamp_utc":"20260827T160219Z",
 "host":{"uname":"Linux/x86_64","bash":"5.2.37(1)-release"},
 "totals":{"total":126,"passed":119,"failed":0,"skipped":7},
 "exit_code":0}
```

**Groups (9): A B C D E F G H I** — emitted in the order A, B, C, D, E, F, **H, G**, I
(cosmetic: H is printed before G).

| group | | n |
|---|---|---|
| A | Static analysis of the wizard | 54 |
| B | Lumen launcher unit tests (isolated `$HOME`) | 8 |
| C | Shell configuration unit tests (isolated `$HOME`) | 10 |
| D | MCP configuration unit tests (isolated `$HOME`) | 5 |
| E | SuperSpec submodule safety (data-loss regression) | 3 |
| F | Live integration (real environment) | 7 — **all 7 skipped** by `--no-live` |
| G | Backup manifest and rollback (isolated `$HOME`) | 18 |
| H | Telemetry opt-out (isolated `$HOME`) | 7 |
| I | Operational scripts (remediation / reindex / doctor) | 14 |

**Failures: 0.** The 7 skips are exactly F1-F7, the live-integration group.

## D12 ✅ — three untold assertions, mutation-tested; **none worthless**

Method: the whole `scripts/` tree was copied to a throwaway project root. The copy reproduced
the baseline exactly (`total=126 passed=119 failed=0 skipped=7`). One mutation was applied at a
time to the **copy**; the real wizard was never touched.

### 1. `B3 launcher selects highest version (sort -V, not lexical)` — group B

Mutation at line 280: `sort -V -k1,1` → `sort -k1,1`.

```console
< done | sort -V -k1,1 | tail -n1 | cut -f2
> done | sort -k1,1 | tail -n1 | cut -f2
(mutant still parses)
  ❌ [57] B3 launcher selects highest version (sort -V, not lexical)
  total=126 passed=118 failed=1 skipped=7
```

Behavioural: the test plants 0.0.9 / 0.0.41 / 0.0.100 launchers and executes the wrapper,
asserting it prints `0.0.100`. Lexical sort picks `0.0.9`. **Load-bearing.**

### 2. `C7 PATH guard written literally ($PATH not expanded at install)` — group C

Mutation at line 348: `case ":\$PATH:"` → `case ":$PATH:"` (expands at install time).

```console
< case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH";; esac
> case ":$PATH:"  in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH";; esac
(mutant still parses)
  ❌ [69] C7 PATH guard written literally ($PATH not expanded at install)
  ❌ [70] C8 sourcing .bashrc adds ~/.local/bin exactly once
  total=126 passed=117 failed=2 skipped=7
```

Two assertions caught it. **Load-bearing.**

### 3. `E1 REGRESSION: gitlink submodule is NOT deleted` — group E

Mutation: `if [[ -e "$sub_path/.git" ]]` → `if [[ -d "$sub_path/.git" ]]` — reintroducing the
historical data-loss bug, since a checked-out submodule's `.git` is a **file**.

```console
< if [[ -e "$sub_path/.git" ]]; then
> if [[ -d "$sub_path/.git" ]]; then
(mutant still parses)
  ❌ [6]  A6 submodule presence test uses -e (gitlink is a FILE)
  ❌ [78] E1 REGRESSION: gitlink submodule is NOT deleted
  ❌ [79] E2 gitlink submodule reported as a submodule
  total=126 passed=116 failed=3 skipped=7
```

E1 builds a real git repo with a gitlink `.git` file plus a canary `IMPORTANT.txt`, runs
`setup_superspec`, and asserts the canary `SURVIVED`. Under the mutation the canary is
`rm -rf`'d. **Load-bearing, and the strongest assertion in the suite.**

After restoring the pristine copy: `total=126 passed=119 failed=0 skipped=7`.

**Worthless assertions found: none of the three.** Separately noted (not tested by mutation):
A48/A49/A50 are bare `assert_contains` string greps over the wizard source — they will detect
deletion of a literal, but assert nothing about behaviour. A47 is narrower than its name
(see C10), and I11 greps the refusal branch without exercising the detector, which is why
**R1** slipped through.

## D13 ✅ — the real environment is untouched by a `--no-live` run

```console
=== BEFORE ===
45dfceaf29b60c49da965895ee152a0ae2b4890ed18a8cfbb0940dfe2470f877  /home/milosvasic/.bashrc
5affcade3a9c2fe707518aabd7c635be9231f7d68845be94aca5daa6ecc1849b  /home/milosvasic/.bash_profile
ebf11baf1e6c90fccc8c630a32fd0a23d91cd190918f2f7d7e2a18918229ae7c  /home/milosvasic/.local/bin/lumen
52caecc09cf656a1b45bbd6e17f3cf07414157a556ef4b35541646038f9f6d21  /home/milosvasic/.claude.json

=== AFTER ===
45dfceaf29b60c49da965895ee152a0ae2b4890ed18a8cfbb0940dfe2470f877  /home/milosvasic/.bashrc
5affcade3a9c2fe707518aabd7c635be9231f7d68845be94aca5daa6ecc1849b  /home/milosvasic/.bash_profile
ebf11baf1e6c90fccc8c630a32fd0a23d91cd190918f2f7d7e2a18918229ae7c  /home/milosvasic/.local/bin/lumen
52caecc09cf656a1b45bbd6e17f3cf07414157a556ef4b35541646038f9f6d21  /home/milosvasic/.claude.json

=== DIFF ===
IDENTICAL - real environment untouched
```

The run's only side effect is `.test-evidence/<stamp>/`, which is gitignored (`.gitignore:63`).

## E14 ✅ — HEAD == remote for the root and all five carriers

```console
=== ROOT ===
local HEAD : 88ab20c7c2b0f27db2d869148035a66b74c11e10
branch     : main
ls-remote  : 88ab20c7c2b0f27db2d869148035a66b74c11e10	refs/heads/main
```

| submodule | local HEAD | superproject gitlink | `ls-remote refs/heads/main` | match |
|---|---|---|---|---|
| `ai_interviewing` | `ed73d8558e289ca0254b4ccc45e0df810767d3ae` | same | same | ✅ |
| `design-toolkit` | `efd2c3fb2f880aaf2baf7f4819ce28a1ce3609cb` | same | same | ✅ |
| `milosvasic.ru` | `66c8d607b20f0d9e984cb0e06f10a2020ebd9a10` | same | same | ✅ |
| `monetization` | `54ed7b0f5add52821d18866facb5ee8c75adef69` | same | same | ✅ |
| `vasic.digital` | `6e5411c21b3cd9c6df5addb543b1a07930c3bfa9` | same | same | ✅ |

All six are on `main`; local HEAD, the superproject's recorded gitlink, and the remote tip
agree in every case.

**Note — the working tree is NOT clean, and became dirty during this verification pass.**
Git status was reported clean at the start of this session; by 18:02 it read:

```
 M _tools/deploy-langs.sh
 M docs/setup-agents-wizard/OLLAMA-REMEDIATION.md
 M docs/setup-agents-wizard/README.md
 M milosvasic.ru
 M vasic.digital
?? .ashlrcode/
?? _tools/deploy-langs.sh.bak.20260827180158
?? docs/setup-agents-wizard/ACTION-REQUIRED.md
?? docs/setup-agents-wizard/OPERATIONAL-SCRIPTS.md
```

None of it is mine — this pass created only this report. Another actor is writing to the repo
concurrently (the `.bak.20260827180158` suffix timestamps it inside this session's window).
The two ` M` submodule entries are dirty *content* (`sitemap.xml` in each), not moved pointers;
the gitlinks are unchanged, which is why E14 still holds. **"HEAD equals remote" is true;
"the repository is in sync" is not the same statement.**

## E15 ✅ — the four root carriers share one byte-identical body

```console
$ for f in AGENTS.md CLAUDE.md GEMINI.md QWEN.md; do
      printf '%s  %s\n' "$(tail -n +24 "$f" | sha256sum | cut -d' ' -f1)" "$f"; done
961f47134720080e69eafc5f7458702ad2af91dbaa7eb279f33e9d2f417851c9  AGENTS.md
961f47134720080e69eafc5f7458702ad2af91dbaa7eb279f33e9d2f417851c9  CLAUDE.md
961f47134720080e69eafc5f7458702ad2af91dbaa7eb279f33e9d2f417851c9  GEMINI.md
961f47134720080e69eafc5f7458702ad2af91dbaa7eb279f33e9d2f417851c9  QWEN.md

distinct body hashes: 1
```

Whole-file hashes differ (`8bd411ea…`, `e8b8511f…`, `96404cfc…`, `c49127da…`) — the only
divergence is the 23-line per-tool header (tool name, inherited-from path, audience line).
All four are at their committed state (`git status --porcelain` on them is empty).
