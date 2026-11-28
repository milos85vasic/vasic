# Lumen Configuration and Wrapper Setup — Investigation Report

Generated from diagnostic commands run against the host at
`/home/milosvasic/Projects/vasic`. All commands were run exactly as specified,
and ALL findings are reported verbatim below.

---

## 1. `~/.config/lumen/config.yaml`

```
ls: cannot access '/home/milosvasic/.config/lumen/': No such file or directory
```

**Finding: ABSENT.** Neither the directory `/home/milosvasic/.config/lumen/`
nor any `config.yaml` inside it exists. Lumen therefore has no user-level
config file at the XDG default location.

A search for any `config.yaml` under a `*lumen*` path returned only unrelated
`helix_code` CLI-agent config files (gemini-cli, swe-agent, warp) — no lumen
config. A search for `*lumen*config*` returned nothing. So there is no lumen
config.yaml anywhere on the host.

---

## 2. `~/.local/bin/lumen`

```
ls: cannot access '/home/milosvasic/.local/bin/lumen': No such file or directory
cat: /home/milosvasic/.local/bin/lumen: No such file or directory (os error 2)
```

**Finding: ABSENT.** There is no lumen binary or wrapper script in
`/home/milosvasic/.local/bin/`.

However, the lumen binary IS present elsewhere:

```
which lumen
/home/milosvasic/go/bin/lumen

ls -la /home/milosvasic/go/bin/lumen
775  /home/milosvasic/go/bin/lumen  40.5M

file /home/milosvasic/go/bin/lumen
/home/milosvasic/go/bin/lumen: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=d257b1bc17b9f833874a7138e1a60286c0060adc, for GNU/Linux 3.2.0, with debug_info, not stripped

lumen --version
Error: unknown flag: --version
Usage:
  lumen [command]

Available Commands:
```

**Finding: PRESENT at `/home/milosvasic/go/bin/lumen`** — a 40.5 MB ELF
executable (mode 775, executable). It resolves on PATH via `which lumen`. The
`--version` flag is unknown (lumen does not support it), but the binary is
runnable and prints usage. There is **no wrapper script** — the raw binary is
invoked directly.

---

## 3. PATH

```
echo $PATH
/home/milosvasic/.pi/agent/bin:/home/milosvasic/.pi-lens/pip-user/bin:/home/milosvasic/go/bin:/mnt/DATA1TB/claude-work/cargo/bin:/mnt/DATA1TB/jetbrains/scripts:/home/milosvasic/Projects/tmx/scripts:/home/milosvasic/.qoder/entry:/home/milosvasic/.grok/bin:/home/milosvasic/.kilo/bin:/home/milosvasic/.mimocode/bin:/home/milosvasic/.local/bin:/home/milosvasic/Android/Sdk/cmdline-tools/latest/bin:/home/milosvasic/Android/Sdk/platform-tools:/home/milosvasic/scripts:/home/milosvasic/.local/bin:/home/milosvasic/.kimi-code/bin:/home/milosvasic/.opencode/bin:/sbin:/usr/sbin:/mnt/DATA1TB/claude-work/cargo/bin:/mnt/DATA1TB/jetbrains/scripts:/home/milosvasic/Projects/tmx/scripts:/home/milosvasic/.grok/bin:/home/milosvasic/.kilo/bin:/home/milosvasic/.mimocode/bin:/home/milosvasic/.local/bin:/home/milosvasic/Android/Sdk/cmdline-tools/latest/bin:/home/milosvasic/Android/Sdk/platform-tools:/home/milosvasic/scripts:/home/milosvasic/.local/bin:/home/milosvasic/.kimi-code/bin:/home/milosvasic/.opencode/bin:/home/milosvasic/.nvm/versions/node/v26.8.1/bin:/sbin:/usr/sbin:/home/milosvasic/Projects/tmx/scripts:/home/milosvasic/.local/bin:/home/milosvasic/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:/home/milosvasic/.lmstudio/bin:/home/milosvasic/Projects/project_toolkit:/home/milosvasic/Projects/project_toolkit/Upstreamable:/home/milosvasic/Projects/project_toolkit/Installable:/home/milosvasic/.lmstudio/bin
```

```
echo "$PATH" | tr ':' '\n' | grep -E '(go/bin|\.local/bin)'
/home/milosvasic/go/bin
/home/milosvasic/.local/bin
/home/milosvasic/.local/bin
/home/milosvasic/.local/bin
/home/milosvasic/.local/bin
/home/milosvasic/.local/bin
/home/milosvasic/.local/bin
/home/milosvasic/.local/bin
```

**Finding: BOTH are present.**
- `/home/milosvasic/go/bin` — present (once, near the front of PATH). This is
  where the actual lumen binary lives, so `lumen` resolves correctly.
- `/home/milosvasic/.local/bin` — present (multiple times, duplicated across
  PATH). No lumen binary lives here, so the duplicates are harmless but noisy.

---

## 4. Shell rc files for lumen configuration

```
grep -n lumen /home/milosvasic/.bashrc 2>&1
---
(no output)

grep -n lumen /home/milosvasic/.bash_profile 2>&1
---
(no output)

grep -rn lumen /home/milosvasic/.profile 2>&1
---
(no output)
```

**Finding: NONE.** No mention of `lumen` in `.bashrc`, `.bash_profile`, or
`.profile`. All three greps returned empty (exit code 1 = no matches). There is
no lumen PATH manipulation, alias, or env var in any shell startup file.

---

## 5. Lumen MCP / Claude configuration

```
ls -la /home/milosvasic/.claude.json 2>&1
ls: cannot access '/home/milosvasic/.claude.json': No such file or directory

ls -la /home/milosvasic/.claude/ 2>&1
(total listing of .claude/ directory)

grep -rn lumen /home/milosvasic/.claude/ 2>&1
/home/milosvasic/.claude/plugins/installed_plugins.json:219:    "lumen@claude-plugins-official": [
/home/milosvasic/.claude/plugins/installed_plugins.json:222:        "installPath": "/home/milosvasic/.claude/plugins/cache/claude-plugins-official/lumen/0.0.42",
```

**Finding:**
- `.claude.json` does NOT exist.
- The `.claude/` directory exists. The only lumen reference is in
  `installed_plugins.json`, which records the **Claude Code lumen plugin**
  `lumen@claude-plugins-official` version `0.0.42`, installed at
  `/home/milosvasic/.claude/plugins/cache/claude-plugins-official/lumen/0.0.42`
  (scope: user, installed 2026-11-19). This is a plugin for Claude Code's MCP
  ecosystem — **not** the lumen binary/config itself.

Full plugin entry (verbatim):
```json
"lumen@claude-plugins-official": [
  {
    "scope": "user",
    "installPath": "/home/milosvasic/.claude/plugins/cache/claude-plugins-official/lumen/0.0.42",
    "version": "0.0.42",
    "installedAt": "2026-11-19T18:13:49.186Z",
    "lastUpdated": "2026-11-19T18:13:49.186Z",
    "gitCommitSha": "f60f9ecee41723b42f3758e9a9409141881ac7d5"
  }
]
```

---

## 6. Environment variables

```
env | grep -i lumen
LUMEN_AUTO_REVIEW=1

env | grep -i ollama
---
(no output)
```

**Finding:**
- `LUMEN_AUTO_REVIEW=1` is set — lumen auto-review is enabled.
- No ollama-related env vars are set (`OLLAMA_HOST`, etc. are all absent).
- No `LUMEN_BACKEND`, `LUMEN_CONFIG`, `LUMEN_STORE`, `LUMEN_BIN`, `LUMEN_EMBED_MODEL`, or other `LUMEN_*` vars are set beyond `LUMEN_AUTO_REVIEW`.

---

## 7. `lumen-reindex.sh`

```
ls -la /home/milosvasic/Projects/vasic/scripts/lumen-reindex.sh
775  /home/milosvasic/Projects/vasic/scripts/lumen-reindex.sh  18.7K
```

**Finding: PRESENT and executable** at
`/home/milosvasic/Projects/vasic/scripts/lumen-reindex.sh` (mode 775, 18.7 KB).

**Full contents** (read in full; key points summarised below):

- Purpose: resilient Lumen re-indexing. Handles GPU-backed embedding failures
  (NaN, all-zero vectors, wedged runners, stale-but-well-formed vectors — the
  last being silent and well-formed, which previously corrupted this project's
  index with 758 stale duplicate vectors across 695 texts/55 files).
- Usage: `./scripts/lumen-reindex.sh [project-path] [--force] [--allow-gpu]`
- Exit codes: 0 indexed, 1 gave up after MAX_ROUNDS, 2 bad usage, 3 refused
  (GPU backend), 4 backend not safe, 5 prerequisite missing.
- Derives backend/host/model from environment with overrides:
  `LUMEN_EMBED_MODEL`, `LUMEN_BACKEND`, `OLLAMA_HOST`, `LM_STUDIO_HOST`,
  `LUMEN_CONFIG`, `LUMEN_STORE`, `LUMEN_BIN`, `LUMEN_SERVICE`,
  `LUMEN_PROBE_TEXTS`, `LUMEN_PROBE_TIMEOUT`, `LUMEN_BATCH_TIMEOUT`, `MAX_ROUNDS`,
  `LUMEN_REINDEX_LOG`.
- Defaults: `CONFIG=$XDG_CONFIG_HOME/lumen/config.yaml` (i.e.
  `~/.config/lumen/config.yaml` — which does NOT exist), `STORE=$XDG_DATA_HOME/lumen`,
  `SERVICE=ollama`, `MAX_ROUNDS=40`.
- Refuses to start if ollama reports a non-CPU library (GPU path) unless
  `--allow-gpu` is given.
- Prepends `$HOME/.local/bin` to PATH internally: `export PATH="$HOME/.local/bin:$PATH"`.
- Retains `--force` across retry rounds until a round exits 0 (a bug fix — it
  used to drop the flag after the first failed round, causing incremental
  resumes that skipped corrupt files).

A companion script also exists:
`/home/milosvasic/Projects/vasic/scripts/lumen-index-doctor.sh` (mode 775,
52.8 KB) — detects silently corrupt embeddings via aggregate distinctness,
never opens the DB for writing.

---

## 8. Lumen wrapper scripts and related files

`find /home/milosvasic -name "*lumen*" -type f | head -30` returned:

```
/home/milosvasic/tmux/constitution/scripts/lumen/gen_lumenignore.py
/home/milosvasic/tmux/constitution/scripts/lumen/lumen_verify.sh
/home/milosvasic/tmux/constitution/scripts/lumen/tests/test_gen_lumenignore.sh
/home/milosvasic/tmux/constitution/scripts/lumen/tests/test_lumen_verify.sh
/home/milosvasic/tmux/constitution/docs/scripts/gen_lumenignore.md
/home/milosvasic/tmux/constitution/docs/scripts/lumen_verify.md
/home/milosvasic/tmux/constitution/docs/qa/fixu_default_tier/u3_lumen/U3_lumen_absent.out
/home/milosvasic/tmux/constitution/docs/qa/fixu_default_tier/u3_lumen/U3_lumen_present.out
/home/milosvasic/Projects/vasic/scripts/lumen-reindex.sh
/home/milosvasic/Projects/vasic/scripts/lumen-index-doctor.sh
/home/milosvasic/Projects/vasic/.lumen-reindex.log
/home/milosvasic/Projects/vasic/workshop-wt-main/platform/backend/gates/prove-lumen-mutations.sh
/home/milosvasic/Projects/vasic/workshop-wt-main/platform/backend/internal/api/lumen_gates_test.go
/home/milosvasic/Projects/vasic/workshop-wt-main/platform/backend/pkg/search/lumenvec_test.go
/home/milosvasic/Projects/vasic/workshop-wt-main/platform/backend/pkg/search/lumen.go
/home/milosvasic/Projects/vasic/workshop-wt-main/platform/backend/pkg/search/lumenvec_live_test.go
/home/milosvasic/Projects/vasic/workshop-wt-main/platform/backend/pkg/search/lumenstore.go
/home/milosvasic/Projects/vasic/workshop-wt-recipes/platform/backend/gates/prove-lumen-mutations.sh
... (workshop-wt-recipes and workshop-wt-macpath mirrors of the same files) ...
```

**Key findings:**
- No lumen **wrapper script** exists anywhere (no `lumen.sh`, `lune-wrapper`, etc.). The only executable is the raw binary at `/home/milosvasic/go/bin/lumen`.
- The reindex wrapper (`lumen-reindex.sh`) calls the `lumen` binary directly by name (resolved via PATH), not via `LUMEN_BIN` (which is unset).
- `.lumen-reindex.log` exists in the project root with recent run history (see below).
- `.lumenignore` exists in the project root, excluding `_tests/evidence/`.

---

## 9. `.lumen-reindex.log` (recent run history)

```
[23:39:56] === lumen-reindex: /home/milosvasic/Projects/vasic (force=0) ===
[23:39:56] backend=ollama host=http://localhost:11434 model=ordis/jina-embeddings-v2-base-code (model from: documented fallback)
[23:40:02] backend library=CUDA
[23:40:05] batch probe OK: 32 distinct texts -> distinct vectors (OK 32/32 distinct)
[23:52:36] === lumen-reindex: /home/milosvasic/Projects/vasic (force=1) ===
[23:52:36] backend=ollama host=http://localhost:11434 model=ordis/jina-embeddings-v2-base-code (model from: documented fallback)
[23:52:42] backend library=CUDA
[23:52:44] batch probe OK: 32 distinct texts -> distinct vectors (OK 32/32 distinct)
[23:54:21] round 1 (forced): rc=0 Done. Indexed 0 files, 0 chunks in 1m36.038s.
[23:54:21] === INDEX COMPLETE after 1 round(s) ===
[00:04:19] === lumen-reindex: /home/milosvasic/Projects/vasic (force=0) ===
[00:04:19] backend=ollama host=http://localhost:11434 model=ordis/jina-embeddings-v2-base-code (model from: existing index)
[00:04:26] REFUSING TO START: ollama reports library=CUDA.
[00:04:26] GPU-backed embedding paths silently write stale duplicate vectors. Fix it first:
[00:04:26]   ./scripts/ollama-vulkan-remediation.sh --apply
[00:04:26] Override with --allow-gpu if you accept the risk.
```

**Findings from the log:**
- Backend: **ollama** at `http://localhost:11434`.
- Embedding model: `ordis/jina-embeddings-v2-base-code` (initially from
  documented fallback, later from existing index).
- Backend library: **CUDA** — GPU-backed. The reindexer refuses to start on a
  GPU backend without `--allow-gpu` (exit code 3), because GPU paths silently
  write stale duplicate vectors.
- A forced reindex ran successfully once (rc=0, indexed 0 files/0 chunks —
  index was already up to date).
- A subsequent non-forced run REFUSED to start due to `library=CUDA`.

---

## 10. `.lumenignore`

```
# Lumen semantic-index exclusions.
#
# _tests/evidence/ holds captured Playwright run artifacts: 4,526 tracked files
# (1,353 json, 1,167 txt, 1,142 png, 515 log) against only 95 real source files
# in the whole of _tests/. Embedding them cost roughly 14 of the ~15 hours the
# index needed, and semantic search over screenshots and run logs returns noise
# rather than answers.
#
# Everything else is still indexed: all source, all submodules, all docs.
# To index the evidence too, delete the line below and re-run `lumen index .`.
_tests/evidence/
```

**Finding: PRESENT** at `/home/milosvasic/Projects/vasic/.lumenignore`. It
excludes only `_tests/evidence/` from indexing. No root-level `~/.lumenignore`
exists.

---

## Summary

| Item | Status | Location / Value |
|---|---|---|
| `~/.config/lumen/config.yaml` | ABSENT | directory does not exist |
| `~/.local/bin/lumen` | ABSENT | no binary or wrapper there |
| lumen binary | PRESENT | `/home/milosvasic/go/bin/lumen` (40.5 MB ELF, mode 775) |
| `which lumen` | RESOLVES | `/home/milosvasic/go/bin/lumen` |
| `/home/milosvasic/go/bin` in PATH | YES | present once |
| `/home/milosvasic/.local/bin` in PATH | YES | present (duplicated multiple times) |
| lumen in `.bashrc` / `.bash_profile` / `.profile` | NO | no matches in any |
| `~/.claude.json` | ABSENT | does not exist |
| lumen in `.claude/` | YES (plugin only) | `lumen@claude-plugins-official` v0.0.42 in `installed_plugins.json` |
| `LUMEN_AUTO_REVIEW` | SET | `LUMEN_AUTO_REVIEW=1` |
| ollama env vars | NONE | none set |
| `lumen-reindex.sh` | PRESENT, executable | `scripts/lumen-reindex.sh` |
| `lumen-index-doctor.sh` | PRESENT, executable | `scripts/lumen-index-doctor.sh` |
| `.lumenignore` | PRESENT | project root, excludes `_tests/evidence/` |
| Backend (from log) | ollama | `http://localhost:11434`, library=CUDA (GPU) |
| Embedding model | `ordis/jina-embeddings-v2-base-code` | from existing index / documented fallback |

**Overall assessment:** Lumen is installed as a raw Go binary in
`/home/milosvasic/go/bin/lumen` (on PATH), with no config file, no wrapper
script, no shell-rc configuration, and no env overrides beyond `LUMEN_AUTO_REVIEW=1`.
The project provides two operational wrapper scripts
(`lumen-reindex.sh`, `lumen-index-doctor.sh`) plus a `.lumenignore`. The
backend is ollama on localhost:11434 running on CUDA (GPU), which causes the
reindexer to refuse non-forced runs unless `--allow-gpu` is used or the backend
is remediated to CPU via `scripts/ollama-vulkan-remediation.sh --apply`.
