# Environment-adaptability audit

Operator directive that produced this document, verbatim:

> **"Make sure all this is fully dynamic and adaptable based on the environment!"**

It was issued about one specific proposal, but it generalises: this repository
should carry no frozen assumption about the machine it runs on. This file is the
audit. The enforcement is `scripts/audit-environment-assumptions.sh`.

Audit date: **2026-08-31**. Scope: the umbrella repository's own tracked files.
Submodule interiors are gitlinks and are **not** in scope.

---

## 1. What this covers, and what it does not

`scripts/audit-hardcoded-paths.sh` already exists and catches exactly one class:
machine-specific **absolute paths** (`/Volumes/T7/...`, `/home/<someone>/...`).
It is blind to everything else that ties the tree to one box.

`scripts/audit-environment-assumptions.sh` is its sibling for the broader class.
The two are complementary and both must pass; neither subsumes the other.

The failure mode being hunted is **not** a loud crash. It is silent
misbehaviour — the shape this repository has already been burned by twice (a CI
gate that reported success over an empty build; a test that stayed green while
the thing it tested had been deleted). Three concrete instances found here:

| Frozen assumption | What actually happens elsewhere |
|---|---|
| `systemctl show` + `journalctl` read the Ollama backend | On a host without systemd both return empty through `2>/dev/null`, `backend_library()` yields `""`, and the Vulkan refusal that the function exists to trigger **never fires**. The script reports success while doing none of its safety work. |
| `/Applications/Open Design.app` | On Linux the `-x` test fails, the daemon never starts, and every downstream diagram generation silently produces nothing. |
| `/etc/sysconfig/ollama` | On a Debian-family host the file systemd reads is `/etc/default/ollama`. The write "succeeds" into a file nothing reads. |

Because of that, **`2>/dev/null` is not treated as a guard by this audit.** It is
the delivery mechanism for the bug.

---

## 2. Scan universe

| | Count |
|---|---|
| Paths in `git ls-files` | 5,768 |
| Excluded: generated evidence (`_tests/evidence/`), English + 14 translated content trees (`_content*`), analysis and prose (`_analysis/`, `docs/`), binaries, lockfiles, `node_modules`/vendor, and submodule gitlinks | 5,594 |
| **Scanned** (executable + configuration source) | **174** |

`bash scripts/audit-environment-assumptions.sh --list` prints the exact list.

Excluding prose is not a loophole — it is the false-positive rule this project
learned the hard way, when a raw grep count of 187 was reported as a finding and
167 of the hits turned out to be legitimate token definitions. A literal in a
comment, a docstring, a documented example, a test fixture, or a
non-translatable-term list configures nothing and is not a defect.

---

## 3. Classification rule

Every class-pattern hit was put through one question:

> **Is there an escape hatch that lets a different machine choose a different
> value, without editing the file?**

If yes, the literal is a **default**, not an assumption, and is not a defect.
Accepted escape hatches:

| Kind | Form |
|---|---|
| shell env default | `HOST="${OLLAMA_HOST:-http://localhost:11434}"` |
| python | `os.environ.get("UI_WORKERS", "5")`, or a local `env()` wrapper over `os.environ` |
| node | `process.env.VD_BASE \|\| 'http://localhost:8401'` |
| go | `os.Getenv("...")` |
| capability probe | `command -v systemctl`, `check_command brew`, `type -p X` |
| OS dispatch | `case "$(uname -s)"`, `$OSTYPE`, `process.platform`, `sys.platform`, `runtime.GOOS` |
| existence probe | `[[ -d /etc/sysconfig ]]`, or listing `/etc/sysconfig/x /etc/default/x /etc/conf.d/x` together |
| declared fallback | a variable literally named `fallback` / `default` / `DEFAULT_*`, i.e. the last term of a precedence chain |

Escape hatches apply to the **value** classes only. No environment variable can
make `sed -i` portable, so `GNUBSD`, `SHEBANG`, `SERVICE`, `PKGMGR` and `GITREF`
are never cleared by an env override — only by a capability probe or OS dispatch
(and `GNUBSD` only by an actual dual-form call).

### Severity

| Severity | Definition |
|---|---|
| **HIGH** | Silently produces a wrong or missing result on another machine, with no error surfaced to the caller. |
| **MEDIUM** | Breaks or misbehaves elsewhere, but loudly, recoverably, or only under contention — including a **wrong pass** rather than a wrong artefact. |
| **LOW** | Degrades, drifts, or is cosmetic; overridable by a flag, or non-fatal by construction. |

---

## 4. Results

### 4.1 Headline numbers

Every number below is a count of **things**, each of which is listed. None is a
`grep -c` line count.

| | Count |
|---|---|
| Files scanned | 174 |
| Files with at least one class-pattern hit | 51 |
| Raw class-pattern occurrences | 104 |
| **Verified defects** | **85** (in 46 files) |
| **False positives** (hand-checked, not defects) | **19** (5 files are pure false positives) |
| Classes that fired | 9 of 12 |
| Classes that fired zero times | `SERVICE`, `GPU`, `GITREF` |

`SERVICE` and `GPU` fired zero times **because they were fixed by a concurrent
agent during this audit** — see §4.5. They were live findings when the sweep
started. `GITREF` has genuinely never had an instance in this repository.

### 4.2 By class

| Class | Raw hits | Defects | False positives |
|---|---:|---:|---:|
| `ENDPOINT` | 51 | 46 | 5 |
| `MODEL` | 24 | 15 | 9 |
| `GNUBSD` | 8 | 6 | 2 |
| `OSPATH` | 7 | 5 | 2 |
| `HOSTNAME` | 6 | 6 | 0 |
| `TOOLVER` | 4 | 3 | 1 |
| `PKGMGR` | 2 | 2 | 0 |
| `SHEBANG` | 1 | 1 | 0 |
| `PARALLEL` | 1 | 1 | 0 |
| `SERVICE` | 0 | 0 | 0 |
| `GPU` | 0 | 0 | 0 |
| `GITREF` | 0 | 0 | 0 |
| **Total** | **104** | **85** | **19** |

### 4.3 By severity

| Severity | Occurrences | Findings |
|---|---:|---|
| HIGH | 10 | F10, F11, F12 |
| MEDIUM | 53 | F3, F6, F7, F8, F9, F13, F14, F16, F19 |
| LOW | 22 | F15, F18, F20, F22 |

### 4.4 Findings

Line numbers are a **2026-08-31 snapshot**. Several of these files were being
edited by other agents while the sweep ran, so line numbers drift; the gate's
allow-list is keyed on path + class + literal substring, never on line number.

| ID | Sev | File : line | Literal | Why it is a portability risk | Suggested dynamic derivation |
|---|---|---|---|---|---|
| **F3** | MED | `scripts/ollama-vulkan-remediation.sh:429` | `sudo sed -i "\|^${FLAG}$\|d" "$ENVFILE"` | GNU in-place form. BSD/macOS `sed -i` consumes the next argument as a backup suffix, so this deletes the wrong thing or errors. | Write to a temp file and `mv`, or dispatch on `sed --version` / `uname -s`. |
| **F6** | MED | `scripts/verify-governance-cascade.sh:708` | `sed -i 's/^  - name: monetization$/.../'` | Same GNU-only form, inside the `m4()` mutation harness — so the mutation proof itself silently stops mutating on BSD. | Temp file + `mv`. |
| **F7** | MED | `scripts/setup-agents-wizard.sh:1507` | `readlink -f "$_lb"` | BSD/macOS `readlink` has no `-f`; returns empty, and the `2>/dev/null` hides it. | `cd "$(dirname x)" && pwd -P`, or `python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))'`. |
| **F8** | MED | `scripts/setup-agents-wizard.sh:290` | `sort -V -k1,1` | GNU-only version sort. BSD `sort` errors, so the launcher falls back to lexical order and picks `0.0.9` over `0.0.100`. | Zero-pad the key before sorting, or sort numerically field-by-field. |
| **F9** | MED | `scripts/test-setup-agents-wizard.sh:344, 609` | `stat -c %a` | GNU-only. The BSD/macOS spelling is `stat -f %Lp`. The mode assertions silently stop asserting. | Mirror the existing correct form in `_tools/pdf/build-pdfs.sh`: `stat -f ... 2>/dev/null \|\| stat -c ... 2>/dev/null`. |
| **F10** | **HIGH** | `_tools/od/start-daemon.sh:6, 7` | `/Applications/Open Design.app/...` | macOS-only, and there is **no** env override at all. On Linux the daemon never starts and every downstream diagram silently generates nothing. | `OD_APP="${OD_APP:-/Applications/Open Design.app/...}"` plus a per-OS candidate list and an explicit failure when none exists. |
| **F11** | **HIGH** | `_tools/translate-fleet.sh:56`, `_tools/helixtranslate-container.sh:45`, `_tools/distribute-helixtranslate.sh:66, 68, 73, 74` | `thinker.local`, `amber.local`, `milosvasic@amber.local` | The operator's own two machines, and the podman-vs-docker runtime is selected by matching the hostname string. On any other network the fleet silently targets hosts that do not resolve. | `HOSTS` is already an env var in `translate-fleet.sh` — extend the same treatment to the runtime map (`HT_RUNTIME_MAP`) and to `distribute-helixtranslate.sh`, and derive the runtime with `command -v podman \|\| command -v docker`. |
| **F12** | **HIGH** | `_tools/helixtranslate-container/run.sh:12`, `_tools/helixtranslate-local.sh:33` | `/usr/local/bin/unified-translator` | Written on the host side of an `ssh` boundary with no override. A container or host that installs elsewhere silently runs nothing; the `1>&2` redirect makes the failure look like normal chatter. | `TRANSLATOR_BIN="${TRANSLATOR_BIN:-unified-translator}"` and let `PATH` resolve it, failing loudly if `command -v` misses. |
| **F13** | MED | `_tests/playwright.config.js:30, 34`, `_tests/visual-effects.config.js:25` | `port: 8401`, `port: 8082` | Fixed bound ports with no override. Two checkouts cannot test concurrently, and `reuseExistingServer: false` turns an occupied port into a hard failure. | `port: Number(process.env.VD_PORT) \|\| 8401`, and build the `command` string from the same value. |
| **F14** | MED | 20 files under `_tests/` — see below | `http://localhost:8401`, `http://localhost:8082`, `:8481`, `:8482`, `:8791` | 42 occurrences with no env override. The risk is not a crash: if *another* process already serves on 8401, the suite tests that process and can **pass on the wrong site**. `_tests/tests/all-languages-link-integrity.spec.js` already does it correctly (`process.env.VD_BASE \|\| ...`) and is the model. | One shared `_tests/bases.js` exporting `VD`/`MV` from `process.env`, imported by every spec. |
| **F15** | LOW | 10 files under `_tools/gen/` and `_tools/` — see below | `"glm-4.5-flash"`, `"llama-3.3-70b-versatile"`, `"gpt-oss-120b"`, `"zai-glm-4.7"` | 15 occurrences as bare module constants and inline argv literals. A retired or rate-capped model silently changes translation output rather than failing. `_tools/translate/translate-content.sh` already does it correctly (`TRANSLATOR_MODEL="${TRANSLATOR_MODEL:-mistral-large-latest}"`). | `os.environ.get("TRANSLATOR_MODEL", "<current>")` — matching the shell pipeline's existing variable names. |
| **F16** | MED | `design-system/diagrams/_prompts/build-and-generate.sh:13` | `OD_DAEMON_URL=http://127.0.0.1:4321 BYOK_PROVIDER=openai BYOK_BASE_URL=https://api.mistral.ai/v1 BYOK_MODEL=codestral-latest` | Exported with `=`, not `:-`, so it **overwrites** whatever the caller set. `_tools/od/generate.sh` gets this right one directory away. | `export OD_DAEMON_URL="${OD_DAEMON_URL:-http://127.0.0.1:4321}"` etc., i.e. copy `_tools/od/generate.sh`. |
| **F18** | LOW | `.github/workflows/ci.yml.disabled:166, 171, 178, 185, 189` | `go-version: '1.26'`, `node-version: '20'`, `ruby-version: '3.3'`, `sudo apt-get ...` | The versions are restated instead of read from `_tools/gen/go.mod`, `_tests/package.json` and `milosvasic.ru/.ruby-version`, so they drift silently; `apt-get` is assumed to be *the* package manager. The file is disabled under §11.4.156, but `scripts/pre-push-gates.sh` mirrors its definitions. | `go-version-file:` / `node-version-file:` / `ruby-version-file:`; probe the package manager with `command -v`. |
| **F19** | MED | `upstreams/GitHub.sh:1` | `#!/bin/bash` | `/bin/bash` does not exist on NixOS and is bash 3.2 on macOS. This is the push wrapper the commit tooling chains into. | `#!/usr/bin/env bash`. |
| **F20** | LOW | `_tools/watch-deploy.sh:30` | `sleep 1200` | Tuned to one machine ("a language completes ~hourly at MAXPAR=1"). A faster or slower host either idles or overlaps cycles. | `sleep "${WATCH_INTERVAL:-1200}"`. |
| **F22** | LOW | `_tools/watch-deploy.sh:19` | `cat /proc/uptime` | Linux-only. The `\|\| echo` keeps it non-fatal, so the run continues — but the started-at marker silently becomes blank on macOS/BSD. | `uptime` (POSIX), or drop the marker. |

**F14 file list** (42 occurrences): `_tests/tests/aria-footer-l10n-runtime.spec.js` (2),
`download-switcher-perlang.spec.js` (2), `home-lang-nav.spec.js` (3),
`interactive-behavior.spec.js` (2), `link-integrity.spec.js` (2),
`milosvasic-ru-a11y.spec.js` (1), `milosvasic-ru-features.spec.js` (1),
`milosvasic-ru-i18n-articles.spec.js` (1), `milosvasic-ru.spec.js` (1),
`perf-budget.spec.js` (4), `security-hardening.spec.js` (4), `seo-meta.spec.js` (6),
`ui-l10n-chrome.spec.js` (2), `vasic-digital-a11y.spec.js` (1),
`vasic-digital-features.spec.js` (1), `vasic-digital-i18n-articles.spec.js` (1),
`vasic-digital.spec.js` (1), `_tests/tools/motion-audit.cjs` (5),
`_tests/ui-l10n2-verify.js` (1), `_tests/visual-effects.spec.js` (1).

**F15 file list** (15 occurrences): `_tools/gen/repair_ui_terms.py` (1),
`translate-ui.py` (1), `translate_aria_footer.py` (3), `translate_home.py` (3),
`translate_ui_all.py` (1), `translate_ui_batch.py` (1), `translate_ui_chunked.py` (1),
`translate_ui_headroom.py` (3), `translate_ui_slow.py` (1).

### 4.5 Findings that were fixed by a concurrent agent while this audit ran

These were live when the sweep started and are **verified fixed** in the working
tree as of the final run. They are recorded because withdrawing a finding
silently would be the same bluff as inventing one.

| ID | Was | Now |
|---|---|---|
| F1 | `ENVFILE=/etc/sysconfig/ollama` (RHEL/SUSE only) | `detect_env_file()` honours `$OLLAMA_ENV_FILE`, then asks systemd for `EnvironmentFiles`, then probes `/etc/sysconfig/`, `/etc/default/`, `/etc/conf.d/` in turn. |
| F2 | `systemctl` / `journalctl` called unguarded in `scripts/ollama-vulkan-remediation.sh` | `detect_service_manager()` dispatches over `systemctl`+`ps -p 1`, `launchctl` on Darwin, and `rc-service`, all behind `command -v`; `OS="$(uname -s)"` at the top. |
| F4 | `GGML_VK_VISIBLE_DEVICES` / Vulkan assumed as the only accelerator stack | `GPU_DRIVER`/`GPU_VENDOR` are env-overridable and otherwise read off the running kernel. |
| F5 | `systemctl` / `journalctl` unguarded in `scripts/lumen-reindex.sh` | Both are now behind `command -v ... >/dev/null 2>&1`. |

### 4.6 Deliberately classified as NOT a defect

19 occurrences. Each was opened and read; none configures anything
machine-specific.

| # | File : line | Hit | Why it is not a defect |
|---|---|---|---|
| 1 | `_tools/pdf/build-pdfs.sh:129` | `GNUBSD` `stat -f %m ... \|\| stat -c %Y ... \|\| echo 0` | This is **already the portable form** — BSD first, GNU fallback, safe default. Flagging it would punish the fix. It is the reference implementation cited in F9. |
| 2 | `_tools/translate/glossary.json:216` | `MODEL` `"codestral"` | An entry in the **non-translatable technology-term list**, alongside `"Playwright"`, `"pandoc"` and `"Jekyll"`. It selects no model. |
| 3–6 | `scripts/lumen-index-doctor.sh:113, 146, 160, 162` | `MODEL`, `ENDPOINT` | The file defines its own `env(name, default)` wrapper over `os.environ` (line ~86). Every literal is the last term of an `env(X) or cfg.get(Y) or "<literal>"` chain whose precedence is copied from lumen's own `applyEnvOverrides`. Line 146 is a docstring. |
| 7–10 | `scripts/test-setup-agents-wizard.sh:247, 290, 879, 1145` | `OSPATH`, `GNUBSD`, `ENDPOINT` | All four are **test fixtures**. 247 is a `grep -cE` pattern asserting the wizard *never* writes `/etc/sysconfig/ollama`; 290 is an assertion **title string** quoting `sort -V`; 879 writes a synthetic throwaway repo to prove the sibling paths audit does *not* flag `/etc`; 1145 sets `OLLAMA_HOST="http://127.0.0.1:1"` because port 1 must be unreachable for the negative test to mean anything. |
| 11 | `_tools/od/start-daemon.sh:10` | `ENDPOINT` | A log line. The port is `${OD_PORT:-4321}` from the line above, and `127.0.0.1` is the loopback constant, chosen deliberately so the daemon is not reachable off-box. |
| 12 | `_tools/gen/translate_ui_chunked.py:2` | `MODEL` | Module docstring prose. |
| 13 | `_tools/gen/translate_home.py:312` | `MODEL` | Function docstring prose. |
| 14–18 | `_tools/review_translation.py:64–68` | `MODEL` | A **provider registry**: each row is (the vendor's published API endpoint, that vendor's API-key env var, that vendor's own default model). The model is overridden by the documented `--model` flag. Nothing is bound to a machine. |
| 19 | `.specify/extensions/superspec/.github/workflows/ci.yml:21` | `TOOLVER` `python-version: "3.12"` | `.specify/extensions/superspec` is **third-party vendored upstream** (`WangX0111/superspec`), explicitly outside the owned-submodule set. Upstream's pin is upstream's to change. |

Two further observations recorded as INFO, below the defect bar:

- `_tools/od/od-mcp-call.mjs:10` — `process.env.OD_MCP_SERVER || '/opt/homebrew/lib/node_modules/...'`.
  Env-overridable, therefore not a defect by the rule in §3. Worth noting anyway
  that the **default** is macOS/Homebrew-only, so on Linux the variable is not
  optional in practice.
- `.github/workflows/ci.yml.disabled:119,121` — `branches: [main]`. A workflow
  trigger naming its own default branch is repository configuration, not a
  machine assumption. The `GITREF` class deliberately does not match YAML
  `branches:` keys.

### 4.7 Known blind spots

Stated rather than left implicit:

- The gate reads `git ls-files`, so **untracked files are invisible to it**. At
  the time of writing `scripts/continuation-check.sh`, `scripts/ollama-tune.sh`
  and `scripts/verify-provider-ci.sh` exist in the working tree but are
  untracked, and were therefore not scanned. They will be scanned the moment
  they are added.
- Submodule interiors (`milosvasic.ru/`, `vasic.digital/`, `design-toolkit/`,
  `ai_interviewing/`, `monetization/`, `submodules/*`) are gitlinks and are out
  of scope. Each needs its own copy of this gate.
- The env-override test is **per line**. A literal assigned on one line and
  guarded three lines later is reported. Two such cases were found and are
  handled by named allow rules rather than by loosening the rule.
- `MODEL` only fires on a **quoted** model id, so a model name written into a
  docstring is ignored — but so would one built by string concatenation.

---

## 5. The gate

```bash
bash scripts/audit-environment-assumptions.sh                # audit this repo
bash scripts/audit-environment-assumptions.sh /path/to/repo  # another checkout
bash scripts/audit-environment-assumptions.sh --list         # scanned universe
bash scripts/audit-environment-assumptions.sh --classes      # class reference
bash scripts/audit-environment-assumptions.sh --allow-list   # effective rules
```

**Exit codes** — the project's three-valued convention, same as
`scripts/lumen-index-doctor.sh`:

| rc | Meaning |
|---:|---|
| `0` | clean — no *new* frozen assumptions |
| `1` | findings |
| `2` | **could not do its job** — never collapse this into `1`. A broken checker is not a violating tree, and it is certainly not a clean one. |

`rc=2` is raised when: the target does not exist; the target is not a git working
tree; a required tool (`git`, `awk`, `grep`) is missing; the scan universe is
**empty** (an anti-bluff guard — a gate that finds nothing because it looked at
nothing is the empty-build success this project has already been burned by); the
allow-list is malformed; or the scan itself errors.

Runtime on this tree: **0.44–0.46 s** over 174 files, one `awk` process, no
per-file subshells. That is inside a pre-push budget. To wire it in, add it
alongside the existing gates in `scripts/pre-push-gates.sh` — deliberately not
done as part of this audit, which was scoped to audit-and-gate only.

### 5.1 Allow-list

Embedded in `ALLOW_RULES` inside the script (this audit was permitted to add
exactly two files to the tree, so the list could not be a third). An external
`.environment-assumptions-allow`, or `$ENV_ASSUMPTIONS_ALLOW`, is read *in
addition* when present, so it can be externalised later without touching the
script.

```
# REASON: <why this literal is genuinely justified>
path/to/file        CLASS    substring-of-the-offending-line

# BASELINE: <known defect, AUDIT.md finding id>
path/to/file        CLASS    substring-of-the-offending-line
```

`PATH` may end in `*` to prefix-match; `CLASS` and the substring may each be `*`.

Every rule **must** carry a `# REASON:` or `# BASELINE:` in the contiguous
comment block directly above it. A rule without one is a malformed allow-list
and exits `2` — an unexplained suppression is indistinguishable from a bluff.

The two kinds are not interchangeable:

- **`REASON`** — genuinely justified forever. Counted, otherwise invisible.
- **`BASELINE`** — a **real, known, unfixed defect**, deliberately carried so the
  gate can catch *new* ones. Baselines are counted and their files printed
  loudly on every clean run, so the tree can never go quietly green over known
  breakage. A baseline is a debt, not a justification, and must cite a finding
  id from §4.4.

Current state: **17 `REASON` occurrences, 87 `BASELINE` occurrences.** The
87 exceeds the 85 verified defects by exactly 2 because two file-wide `MODEL`
baselines (`translate_ui_chunked.py`, `translate_home.py`) also absorb the two
docstring false positives 12 and 13 in §4.6. That is a deliberate loss of
precision in favour of a shorter list, and it is recorded rather than smoothed
over.

---

## 6. Mutation proof

Per §1.1 of the constitution, every gate carries a paired mutation proving it
catches regressions. All probes ran against **throwaway git repositories** and a
**path-faithful mirror** of the scan universe, never against the live tree —
other agents were editing this repository concurrently.

### 6.1 Synthetic probes — 32 of 32 pass

| Group | Probe | Expected | Observed |
|---|---|---|---|
| A | clean throwaway tree | `rc=0` | `rc=0` PASS |
| B | plant `ENDPOINT` `const BASE = 'http://localhost:8401';` | `rc=1` + names file & class | PASS |
| B | plant `PARALLEL` `pool = Pool(max_workers=12)` | `rc=1` + named | PASS |
| B | plant `MODEL` `MODEL = "llama-3.3-70b-versatile"` | `rc=1` + named | PASS |
| B | plant `OSPATH` `ENVFILE=/etc/sysconfig/ollama` | `rc=1` + named | PASS |
| B | plant `SERVICE` `systemctl restart ollama` | `rc=1` + named | PASS |
| B | plant `PKGMGR` `sudo apt-get install -y jq` | `rc=1` + named | PASS |
| B | plant `GNUBSD` `sed -i "s/a/b/" f.txt` | `rc=1` + named | PASS |
| B | plant `HOSTNAME` `ssh milosvasic@thinker.local uptime` | `rc=1` + named | PASS |
| B | plant `TOOLVER` `go-version: '1.26'` | `rc=1` + named | PASS |
| B | plant `GITREF` `git push origin main` | `rc=1` + named | PASS |
| B | plant `GPU` `nvidia-smi --query-gpu=name --format=csv` | `rc=1` + named | PASS |
| B | plant `SHEBANG` `#!/bin/bash` | `rc=1` + named | PASS |
| C | `HOST="${OLLAMA_HOST:-http://localhost:11434}"` | `rc=0` | PASS |
| C | `process.env.VD_BASE \|\| 'http://localhost:8401'` | `rc=0` | PASS |
| C | `int(os.environ.get("UI_WORKERS", "5"))` | `rc=0` | PASS |
| C | comment-only line mentioning `systemctl restart ollama` | `rc=0` | PASS |
| C | `command -v systemctl >/dev/null 2>&1 && systemctl restart ollama` | `rc=0` | PASS |
| C | `case "$(uname -s)" in Linux) sudo apt-get install -y jq;; esac` | `rc=0` | PASS |
| C | `#!/bin/sh` (POSIX, guaranteed location) | `rc=0` | PASS |
| C | `for f in /etc/sysconfig/x /etc/default/x /etc/conf.d/x` | `rc=0` | PASS |
| C | `fallback = "ordis/jina-embeddings-v2-base-code"` | `rc=0` | PASS |
| D1 | real allow rule suppresses `_tools/pdf/build-pdfs.sh` `stat -f %m` line | `rc=0` | PASS |
| D2 | add `readlink -f` to that **same allow-listed file** | `rc=1`, names `readlink -f` | PASS |
| D3 | same `stat -f %m` line in a **different path** | `rc=1`, names the other file | PASS |
| D4 | add `systemctl restart ollama` to the allow-listed file (rule is `GNUBSD`-scoped) | `rc=1`, names `SERVICE` | PASS |
| E1 | target directory does not exist | `rc=2` | PASS |
| E2 | target is not a git working tree | `rc=2` | PASS |
| E3 | **empty** scan universe | `rc=2`, not `0` | PASS |
| E4 | external allow rule with no `# REASON:` | `rc=2` | PASS |
| E5 | the same rule **with** a `# REASON:` | `rc=0` | PASS |
| E6 | `git`/`awk`/`grep` absent from `PATH` | `rc=2` | PASS |

D2/D3/D4 together are the precision proof the allow-list needs: a rule
suppresses exactly its own (path, class, literal) triple and nothing adjacent.

### 6.2 Planted into the real project files

Same 12 classes, planted one at a time into a **path-faithful mirror** of all
174 scanned files (identical baseline: 174 scanned, 87 baselined, 17 allowed,
`rc=0`), then reverted:

| Class | Host file | Result |
|---|---|---|
| `ENDPOINT` | `_tools/gen/build.sh` | `rc=1`, offender named |
| `PARALLEL` | `_tools/gen/data.go` | `rc=1`, offender named |
| `MODEL` | `_tools/gen/i18n.go` | `rc=1`, offender named |
| `OSPATH` | `_tools/render-articles.sh` | `rc=1`, offender named |
| `SERVICE` | `_tools/audit-hardcoding.sh` | `rc=1`, offender named |
| `PKGMGR` | `_tools/translate-all-langs.sh` | `rc=1`, offender named |
| `GNUBSD` | `_tools/portfolio/self-validate.sh` | `rc=1`, offender named |
| `HOSTNAME` | `_tools/review-translations.sh` | `rc=1`, offender named |
| `TOOLVER` | `helix-deps.yaml` | `rc=1`, offender named |
| `GITREF` | `_tools/od/generate.sh` | `rc=1`, offender named |
| `GPU` | `_tools/parse-chrome-translations.js` | `rc=1`, offender named |
| `SHEBANG` | `_tools/gen/build.sh` (line 1) | `rc=1`, offender named |

After removing every probe, the mirror returns to its exact baseline —
`scanned 174 · 87 baselined · 17 allowed · rc=0` — and the live tree does the
same. `bash scripts/audit-hardcoded-paths.sh` remains `rc=0` throughout.

---

## 7. The gate is free of what it polices

Verified by inspection, not asserted:

| Property | Evidence |
|---|---|
| Portable interpreter | `#!/usr/bin/env bash` |
| Root derived, never literal | `ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"` |
| No GNU-only tool flags in executable position | zero matches for `sed -i`, `readlink -f`, `stat -c`, `date -d`, `grep -P`, `xargs -r`, `sort -V`, `mktemp -p`, `du -b`, `cp --parents` outside its own pattern strings |
| POSIX `awk` only | no `gensub`, no `ENDFILE`, no `asort`, no `{n,m}` interval quantifiers (mawk 1.3.3 does not support them) |
| No service or package manager invoked | zero |
| Prerequisites probed, not assumed | `for _bin in git awk grep; do command -v "$_bin" ...` → `rc=2` |
| Temp dir respects the environment | `TMPDIR_SAFE="${TMPDIR:-/tmp}"`, `mktemp -d` with a template, `trap ... EXIT INT TERM` |
| No absolute machine paths | zero |
| Colour respects `NO_COLOR` and non-TTY output | `[ -t 1 ] && [ -z "${NO_COLOR:-}" ]` |

It allow-lists **itself** (and its sibling `scripts/audit-hardcoded-paths.sh`)
with a stated reason: a detector's class patterns must literally contain every
token it searches for. That is the same precedent as `.hardcoded-paths-allow`
exempting `scripts/audit-hardcoded-paths.sh`, and probe D3 proves the exemption
is path-scoped — the identical literal in any other file is still caught.

---

## 8. Scope boundary

This audit **did not fix anything**. Fixing is a separate decision, and several
of the affected files were being edited by other agents while the sweep ran; a
concurrent rewrite would have collided. The 85 verified defects are carried as
`BASELINE` entries so the gate can be adopted immediately and catch the 86th.
