# Safety and Rollback

Authoritative reference for the transactional backup manifest written by
`scripts/setup-agents-wizard.sh` and for the rollback tool that replays it,
`scripts/rollback-agents-wizard.sh`.

Every statement here was read out of those two scripts. For the wizard's own reference see
[`MANUAL.md`](./MANUAL.md); for symptom-first fixes see
[`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md).

The short version:

```bash
./scripts/rollback-agents-wizard.sh --list       # which runs can be undone
./scripts/rollback-agents-wizard.sh --dry-run    # what would change
./scripts/rollback-agents-wizard.sh --yes        # undo the newest run
```

---

## What gets backed up, and where

The wizard calls `backup_init` once, immediately after it prints the project root and
**before Step 1**. That creates a fresh **session directory** named for the UTC start time
and prints it:

```
ℹ️  Backup session: /home/<you>/.local/share/setup-agents-wizard/backups/20260826T210411Z
ℹ️  Undo everything later with: /path/to/repo/scripts/rollback-agents-wizard.sh
```

Layout:

```
~/.local/share/setup-agents-wizard/            <- WIZARD_STATE_DIR
└── backups/                                   <- BACKUP_ROOT
    ├── 20260826T210411Z/                      <- one session per wizard run
    │   ├── manifest.tsv                       <- the transaction log
    │   ├── files/                             <- byte-exact copies of the originals
    │   │   ├── 9f2c1ab30e7d4415__.bashrc
    │   │   ├── 4b7e0d9a1c6f2238__.bash_profile
    │   │   └── 2d5ae8b17c034f90__settings.json
    │   └── pre-rollback-20260826T221530Z/     <- written by the rollback tool, not the wizard
    ├── 20260827T090300Z/                      <- the next run gets its own session
    └── latest -> 20260827T090300Z             <- symlink to the newest session
```

| Property | Value |
| :--- | :--- |
| State directory | `$WIZARD_STATE_DIR`, default `$HOME/.local/share/setup-agents-wizard` |
| Backup root | `$WIZARD_STATE_DIR/backups` |
| Session id | `date -u +%Y%m%dT%H%M%SZ` — e.g. `20260826T210411Z` |
| Manifest | `<session>/manifest.tsv`, tab-separated, one header row |
| Stored originals | `<session>/files/<first-16-hex-of-sha256(target-path)>__<basename>` |
| Newest session | `<backup root>/latest`, a symlink refreshed by `ln -sfn` on every run |
| Copy mode | `cp -p` — content, permissions and timestamps are preserved (test **G7**) |

`WIZARD_STATE_DIR` is re-resolved **inside `backup_init`**, not when the script is sourced,
so exporting it after sourcing the wizard in library mode still takes effect:

```bash
SETUP_WIZARD_LIB_ONLY=1 . scripts/setup-agents-wizard.sh
export WIZARD_STATE_DIR="$PWD/.wizard-state"
backup_init            # session lands under $PWD/.wizard-state/backups/
```

The rollback tool reads the same variable, so both sides must agree:

```bash
WIZARD_STATE_DIR="$PWD/.wizard-state" ./scripts/rollback-agents-wizard.sh --list
```

### The familiar `.bak.<ts>` siblings are still written

`backup_file` does **two** things: it registers the file in the manifest *and* keeps the
old sibling copy next to the original, `<file>.bak.YYYYMMDDHHMMSS` (local time, unlike the
UTC session id). Those siblings accumulate — nothing rotates or removes them, including
rollback. Prune them yourself:

```bash
ls -1 ~/.bashrc.bak.* ~/.bash_profile.bak.* ~/.local/bin/lumen.bak.* \
      ~/.claude/*.bak.* ~/.kimi-code/*.bak.* ~/.qwen/*.bak.* 2>/dev/null
```

`install_lumen_completion` uses `snapshot_before` directly rather than `backup_file`, so
`~/.local/share/bash-completion/completions/lumen` is in the manifest but gets **no**
`.bak.<ts>` sibling.

In the other direction, `~/.bashrc` collects **two** siblings per run: both
`configure_telemetry_optout` and `configure_lumen_shell` call `backup_file` on it. The
manifest still holds a single row for it, because the first snapshot wins.

### What is *not* recorded

The manifest covers what the wizard writes itself. It does not cover work delegated to
third-party installers or to other tools:

| Not recorded | Why |
| :--- | :--- |
| Bun (`~/.bun`), WOZCODE | Vendor `curl \| bash` installers; they write their own files and may edit rc files themselves |
| ashlr (`~/.claude/plugins/cache/ashlr-marketplace/ashlr/`) | Vendor `curl \| bash` installer. It clones a plugin directory and creates **no binary** — remove it with `rm -rf` on that path. Whatever `/plugin install` then registers inside Claude Code is Claude Code's state, not the wizard's |
| `<project>/MANUAL-STEPS.md` | Written on **every** run from the manual-step registry. It is a regenerated snapshot of what is still pending, not a wizard "edit" — `rm` it, or `.gitignore` it |
| `<project>/.ashlrcode/genome/` | Created by `/ashlr:ashlr-genome-init` inside Claude Code. The wizard only detects its absence |
| `<project>/.lumen-reindex.log` | Appended by `scripts/lumen-reindex.sh` |
| `/etc/sysconfig/ollama` | Written **only** by `scripts/ollama-vulkan-remediation.sh --apply`, never by the wizard (test **A41**). It has its own undo: `--rollback` |
| Ollama, its systemd unit, and the pulled embedding model | Installed by `https://ollama.com/install.sh` / `brew`, enabled with `systemctl` |
| `~/.claude/plugins/marketplaces/Sagargupta16/…` and `…/JCodesMore/…` | Plain `git clone`s, skipped when the directory already exists |
| `submodules/`, `submodules/superspec`, `.specify/`, `specs/` | Project content created in Step 6 — treat it as repository state, not wizard leftovers |
| `~/.local/share/lumen/` | Index databases written by `lumen index`, never by the wizard. Use `lumen purge` |
| `<project>/.codegraph/` | The CodeGraph database, created by `codegraph init` in the opt-in Step 7 (and updated in place by `codegraph sync`). Written by CodeGraph, not the wizard. Remove with `rm -rf .codegraph` |
| `~/.codegraph/telemetry.json` | Written by `codegraph telemetry off` during the Step 3 telemetry opt-out. CodeGraph owns the file; the wizard only invokes the CLI |

> `uv tool install specify-cli` used to be on this list. It is not any more — see
> [Components](#components) — it records `ACTION uv tool uninstall specify-cli` under the
> `speckit` component, so `--run-actions` **will** uninstall SpecKit unless you scope the
> rollback with `--component`.

---

## The manifest format

`manifest.tsv` is tab-separated with exactly six columns and one header row:

```
component	action	target	backup	sha256_before	timestamp
```

| Column | Meaning |
| :--- | :--- |
| `component` | Which part of the wizard made the change — the unit `--component` filters on |
| `action` | `MODIFIED`, `CREATED` or `ACTION` (below) |
| `target` | Absolute path of the file, **or** for `ACTION` rows the literal undo command |
| `backup` | Absolute path of the stored original, or `-` |
| `sha256_before` | `sha256sum` of the file before the change, or `-` |
| `timestamp` | `date -u +%Y-%m-%dT%H:%M:%SZ` when the row was written |

### The three action types

| Action | Recorded when | Rollback does |
| :--- | :--- | :--- |
| `MODIFIED` | The target already existed | Restores the stored copy over it with `cp -p` — byte-exact, mode preserved |
| `CREATED` | The target did not exist | Deletes the target (`rm -f`) |
| `ACTION` | The change is not a file at all — an `npm install -g`, a `claude mcp` registration | **Prints** the undo command. Executes it only with `--run-actions` |

### Worked example

A first run on a machine that has Claude Code, Kimi, Opencode and Qwen Code installed, and
that was missing `glyphdown` and `specify`, produces a manifest like this (rows appear in
execution order; `sha256_before` is a full 64-character digest, abbreviated here):

| component | action | target | backup | sha256_before | timestamp |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `npm` | `ACTION` | `npm uninstall -g glyphdown` | `-` | `-` | `2026-08-26T21:04:19Z` |
| `speckit` | `ACTION` | `uv tool uninstall specify-cli` | `-` | `-` | `2026-08-26T21:04:22Z` |
| `shell` | `MODIFIED` | `/home/you/.bashrc` | `…/files/9f2c1ab30e7d4415__.bashrc` | `c1f9a4…` | `2026-08-26T21:04:24Z` |
| `qwen` | `MODIFIED` | `/home/you/.qwen/settings.json` | `…/files/aa17bf3c25e60d84__settings.json` | `55c2ab…` | `2026-08-26T21:04:25Z` |
| `lumen` | `CREATED` | `/home/you/.local/bin/lumen` | `-` | `-` | `2026-08-26T21:04:26Z` |
| `lumen` | `CREATED` | `/home/you/.local/share/bash-completion/completions/lumen` | `-` | `-` | `2026-08-26T21:04:26Z` |
| `shell` | `MODIFIED` | `/home/you/.bash_profile` | `…/files/4b7e0d9a1c6f2238__.bash_profile` | `7a0233…` | `2026-08-26T21:04:27Z` |
| `claude` | `ACTION` | `claude mcp remove lumen -s user` | `-` | `-` | `2026-08-26T21:05:02Z` |
| `claude` | `MODIFIED` | `/home/you/.claude/settings.json` | `…/files/2d5ae8b17c034f90__settings.json` | `3e11bd…` | `2026-08-26T21:05:03Z` |
| `kimi` | `MODIFIED` | `/home/you/.kimi-code/mcp.json` | `…/files/8c04f2a99b1d3e57__mcp.json` | `1b7c40…` | `2026-08-26T21:05:03Z` |
| `opencode` | `MODIFIED` | `/home/you/.config/opencode/opencode.json` | `…/files/61ae3c008df4b912__opencode.json` | `d904e7…` | `2026-08-26T21:05:04Z` |

Two things to read out of that shape:

- **`~/.bashrc` and `~/.qwen/settings.json` are snapshotted in Step 3**, by
  `configure_telemetry_optout`, before the Lumen block and the MCP merge touch them again in
  Steps 3 and 5. First snapshot wins, so one row covers every later edit to the same file.
- **Every `MODIFIED` above assumes the file already existed.** On a clean machine
  `~/.claude/settings.json`, `~/.kimi-code/mcp.json` and `~/.qwen/settings.json` are recorded
  `CREATED` instead, and rollback deletes them rather than restoring an empty `{}`.

Read it directly whenever you want to know what a run touched:

```bash
column -t -s $'\t' ~/.local/share/setup-agents-wizard/backups/latest/manifest.tsv
awk -F'\t' 'NR>1 {print $1, $2, $3}' ~/.local/share/setup-agents-wizard/backups/latest/manifest.tsv
```

### First snapshot wins

`snapshot_before` skips a target that is already present in column 3 of this session's
manifest. Several wizard steps can touch the same file within one run; only the **first**
snapshot is kept, so the stored copy is always the true pre-run original and rollback
restores that, not an intermediate state. Test **G6** asserts exactly this.

Consequently a session's manifest holds **at most one row per file path**, and rows for a
file whose `cp -p` failed are omitted entirely — the wizard prints
`⚠️ Could not back up <path>` in that case.

### Components

| Component | Written by | Covers |
| :--- | :--- | :--- |
| `lumen` | `install_lumen_wrapper`, `install_lumen_completion` (Step 3) | `~/.local/bin/lumen`, `~/.local/share/bash-completion/completions/lumen` |
| `shell` | `configure_lumen_shell` **and** `configure_telemetry_optout` (both Step 3) | `~/.bashrc`, `~/.bash_profile`. Both functions call `backup_file "$HOME/.bashrc" shell`, so that file gets two `.bak.<ts>` siblings per run but only one manifest row |
| `claude` | Step 5 | `ACTION` `claude mcp remove lumen -s user`, `~/.claude/settings.json` for the Glyphdown hooks, **and `~/.claude.json`** for the Lumen mirror that MiMo and other inheritors read |
| `kimi` | Step 5 | `~/.kimi-code/mcp.json` |
| `opencode` | Step 5 | `~/.config/opencode/opencode.json` |
| `qwen` | Step 3 (telemetry) and Step 5 (MCP) | `~/.qwen/settings.json` — snapshotted by whichever step touches it first, so one row covers both the `.usageStatisticsEnabled` edit and the `.mcpServers` merge |
| `npm` | `npm_install_if_missing` (Step 2) | One `ACTION` `npm uninstall -g <pkg>` per package the wizard actually installed |
| `speckit` | The `uv` branch of Step 2 | One `ACTION` `uv tool uninstall specify-cli`, written only when `specify` was missing and the install succeeded |
| `misc` | Fallback | The default second argument of `backup_file` and third of `configure_mcp_for_agent`. Every call site in the current wizard passes an explicit component, so `misc` should not appear in a real manifest |

MiMo Code has no component of its own because there is no MiMo-specific file: it **inherits**
MCP servers from `~/.claude.json`, which the `claude` component covers. Rolling back `claude`
therefore removes Lumen from MiMo too — along with the Glyphdown hooks and the Claude Code
registration. (An earlier revision of this document said the wizard "writes nothing for it and
prints a manual-step warning". The warning is gone; the mirror is what configures MiMo.)

---

## Rollback CLI reference

```
scripts/rollback-agents-wizard.sh [--list] [--session <id|latest>]
                                  [--component <name>]... [--dry-run]
                                  [--yes] [--run-actions] [--help]
```

Runs under `set -uo pipefail` (no `-e`). It takes no positional arguments.

| Option | Short | Effect |
| :--- | :--- | :--- |
| `--list` | — | Print every session that has a `manifest.tsv`: id, change count, components. Exits immediately afterwards |
| `--session <id\|latest>` | — | Choose a session by directory name, e.g. `20260826T210411Z`. `latest`, or omitting the option, selects the newest session by name |
| `--component <name>` | `-c` | Restrict the rollback to one component. **Repeatable.** `all` matches everything. Default: every component in the manifest |
| `--dry-run` | `-n` | Print the plan and exit `0` without changing anything (test **G10**) |
| `--yes` | `-y` | Skip the `Apply this rollback? [y/N]` prompt |
| `--run-actions` | — | Also `eval` the undo command of every `ACTION` row. Without it those rows are printed only |
| `--help` | `-h` | Print the script's header comment as usage and exit `0` |

Any other argument prints `❌ Unknown option: …` and exits **2**.

### Exit codes

| Code | Condition |
| :--- | :--- |
| `0` | Rollback applied with no failures. Also: `--list`, `--help`, `--dry-run`, "nothing to roll back for the selected components", and answering `n` at the prompt |
| `1` | At least one entry failed — a missing backup file, or a `cp`/`rm` that did not succeed. Also: no backup root at all, or no `manifest.tsv` for the chosen session |
| `2` | An unrecognised option |

A failed `ACTION` undo command is a **warning**, not a failure: it prints
`⚠️ undo command failed (may already be undone): …` and does not affect the exit code.

### What a run looks like

```
$ ./scripts/rollback-agents-wizard.sh --dry-run

========================================
 Rollback plan
========================================
ℹ️  Session   : 20260826T210411Z
ℹ️  Components: all
⚠️  DRY RUN - nothing will be changed.
  manual   [npm] npm uninstall -g glyphdown   (use --run-actions to execute)
  delete   [lumen] /home/you/.local/bin/lumen
  delete   [lumen] /home/you/.local/share/bash-completion/completions/lumen
  restore  [shell] /home/you/.bashrc
  restore  [shell] /home/you/.bash_profile
  manual   [claude] claude mcp remove lumen -s user   (use --run-actions to execute)
  restore  [claude] /home/you/.claude/settings.json
  restore  [kimi] /home/you/.kimi-code/mcp.json
  restore  [opencode] /home/you/.config/opencode/opencode.json
  restore  [qwen] /home/you/.qwen/settings.json
```

Without `--dry-run` it asks once, then applies, then reports:

```
Apply this rollback? [y/N] y
ℹ️  Current state is being saved to /home/you/.local/share/setup-agents-wizard/backups/20260826T210411Z/pre-rollback-20260826T221530Z

========================================
 Applying rollback
========================================
✅ restored [shell] /home/you/.bashrc
…
========================================
 Rollback complete
========================================
ℹ️  restored/removed: 8    failures: 0
ℹ️  Pre-rollback state kept at: …/pre-rollback-20260826T221530Z
ℹ️  Open a new shell for PATH changes to take effect.
```

`ACTION` rows are printed twice by design — once in the plan, once while applying — which
is what test **G14** pins down. They are never executed without `--run-actions`.

### Rollback is itself reversible

Before touching anything (and only after the prompt is answered), the tool creates

```
<session>/pre-rollback-<UTC timestamp>/
```

and copies the **current** on-disk content of every file it is about to restore or delete
into it, under the same `<16-hex>__<basename>` naming scheme as `files/`. Nothing the
rollback overwrites or removes is lost. Test **G13** asserts the snapshot is created.

`ACTION` rows are not snapshotted — there is no file to copy. Redo them by hand
(see [Reversing a rollback](#reversing-a-rollback)).

---

## Recipes

All commands are run from the repository root.

### See what can be undone

```bash
./scripts/rollback-agents-wizard.sh --list
```

```
========================================
 Backup sessions
========================================
  20260826T210411Z      11 changes   components: claude kimi lumen npm opencode qwen shell speckit
  20260827T090300Z       4 changes   components: claude shell
```

Each session is **one wizard run** and contains only what *that* run changed.

### Undo the newest run completely

```bash
./scripts/rollback-agents-wizard.sh --dry-run     # read the plan first
./scripts/rollback-agents-wizard.sh --yes
exec bash -l                                      # pick up the restored PATH
```

Add `--run-actions` to also undo the `claude mcp` registration and the npm global installs:

```bash
./scripts/rollback-agents-wizard.sh --run-actions --yes
```

### Undo only the shell PATH changes

Restores `~/.bashrc` and `~/.bash_profile` byte-exactly as they were before the run — which
removes the managed `lumen` and `user bin on PATH` blocks along with them, and preserves
whatever else you had in those files.

```bash
./scripts/rollback-agents-wizard.sh --component shell --dry-run
./scripts/rollback-agents-wizard.sh --component shell --yes
exec bash -l
```

Nothing else is touched — test **G11** asserts that a component filter leaves other
components alone.

### Remove Lumen from Opencode only

```bash
./scripts/rollback-agents-wizard.sh -c opencode -n
./scripts/rollback-agents-wizard.sh -c opencode -y
jq '.mcp.lumen' ~/.config/opencode/opencode.json     # -> null
```

Restart Opencode afterwards; MCP servers are launched at session start.

### Undo one or two agents, keep the rest

`--component` is repeatable:

```bash
./scripts/rollback-agents-wizard.sh -c kimi -c qwen --yes
```

`-c all` is accepted and is equivalent to passing no filter.

### Unregister Lumen from Claude Code

The registration is an `ACTION` row, so it needs `--run-actions`:

```bash
./scripts/rollback-agents-wizard.sh -c claude --run-actions --dry-run
./scripts/rollback-agents-wizard.sh -c claude --run-actions --yes
claude mcp get lumen        # -> not found
```

Note that component `claude` also owns `~/.claude/settings.json` (the Glyphdown hooks), so
that file is restored in the same pass. To undo *only* the MCP registration, run the undo
command the manifest records, by hand:

```bash
claude mcp remove lumen -s user
```

### Undo the npm global installs

```bash
./scripts/rollback-agents-wizard.sh -c npm --run-actions --dry-run   # see exactly which packages
./scripts/rollback-agents-wizard.sh -c npm --run-actions --yes
```

Only packages the wizard actually installed have an `ACTION` row — `npm_install_if_missing`
skips anything already on `PATH`, so a pre-existing `glyphdown` is never uninstalled.

### Undo the SpecKit install

SpecKit is not an npm package, so it has its own component:

```bash
./scripts/rollback-agents-wizard.sh -c speckit --run-actions --dry-run
./scripts/rollback-agents-wizard.sh -c speckit --run-actions --yes    # uv tool uninstall specify-cli
```

The reverse matters too: a bare `--run-actions --yes` with **no** `--component` will
uninstall SpecKit along with everything else. Scope the rollback if you want to keep it.

### Roll back an older run

```bash
./scripts/rollback-agents-wizard.sh --list
./scripts/rollback-agents-wizard.sh --session 20260826T210411Z --dry-run
./scripts/rollback-agents-wizard.sh --session 20260826T210411Z --yes
```

### Undo several runs

Sessions are independent snapshots taken at different times. Roll them back **newest
first**, one at a time, so each restore lands on the state that session expected:

```bash
./scripts/rollback-agents-wizard.sh --session 20260827T090300Z --yes
./scripts/rollback-agents-wizard.sh --session 20260826T210411Z --yes
```

Rolling back only the newest session returns you to the state immediately before *that*
run — not to a pristine machine.

---

## Reversing a rollback

Every applied rollback leaves `<session>/pre-rollback-<UTC>/` holding the content that was
on disk at that moment. Files are named `<first-16-hex-of-sha256(path)>__<basename>`, the
same scheme as `files/`.

```bash
SESSION=~/.local/share/setup-agents-wizard/backups/20260826T210411Z
ls -1 "$SESSION"/pre-rollback-*/
```

To put one file back, compute its key and copy it over:

```bash
PRE="$SESSION/pre-rollback-20260826T221530Z"
KEY=$(printf '%s' "$HOME/.bashrc" | sha256sum | cut -c1-16)
cp -p "$PRE/${KEY}__.bashrc" "$HOME/.bashrc"
```

To put everything back, walk the snapshot and match each file to its manifest target:

```bash
PRE="$SESSION/pre-rollback-20260826T221530Z"
awk -F'\t' 'NR>1 && ($2=="MODIFIED" || $2=="CREATED") {print $3}' "$SESSION/manifest.tsv" |
while read -r target; do
    key=$(printf '%s' "$target" | sha256sum | cut -c1-16)
    src="$PRE/${key}__$(basename "$target")"
    [ -f "$src" ] && cp -p "$src" "$target" && echo "restored $target"
done
```

`ACTION` rows have no snapshot. Redo them explicitly:

```bash
claude mcp add-json lumen "{\"command\":\"$HOME/.local/bin/lumen\",\"args\":[\"stdio\"]}" -s user
npm install -g glyphdown
```

Or simply re-run the wizard — it is idempotent, and it opens a new backup session of its
own.

---

## Manual uninstall, if the manifest is lost

Use this when `~/.local/share/setup-agents-wizard/` was deleted, when `WIZARD_STATE_DIR`
pointed somewhere that no longer exists, or when you want to remove the wizard's footprint
without a session to replay. Each block is independent — skip anything you want to keep.

### `lumen` — launcher and completions

```bash
rm -f ~/.local/bin/lumen ~/.local/bin/lumen.bak.*
rm -f ~/.local/share/bash-completion/completions/lumen
```

### `shell` — the managed `PATH` blocks

Reuse the wizard's own remover in library mode, so the markers (which contain regex
metacharacters) and the file's mode and inode are handled correctly:

```bash
cd /path/to/this/repo
SETUP_WIZARD_LIB_ONLY=1 . scripts/setup-agents-wizard.sh
strip_managed_block "$HOME/.bashrc"       "$LUMEN_BLOCK_START"   "$LUMEN_BLOCK_END"
strip_managed_block "$HOME/.bashrc"       "$PRIVACY_BLOCK_START" "$PRIVACY_BLOCK_END"
strip_managed_block "$HOME/.bash_profile" "$USERBIN_BLOCK_START" "$USERBIN_BLOCK_END"
```

There are three blocks, not two: `~/.bashrc` carries both the Lumen block and the telemetry
opt-out block.

Verify:

```bash
grep -c '>>> lumen semantic search' ~/.bashrc        # -> 0
grep -c '>>> telemetry opt-out'     ~/.bashrc        # -> 0
grep -c '>>> user bin on PATH'      ~/.bash_profile  # -> 0
```

### `claude` — MCP registration, hooks, marketplace clones

```bash
claude mcp remove lumen -s user
tmp=$(mktemp) && jq 'del(.mcpServers.lumen)' ~/.claude.json > "$tmp" && mv "$tmp" ~/.claude.json
```

Two commands, because there are two places. `claude mcp` owns the registration in the **active**
`CLAUDE_CONFIG_DIR`, and the wizard additionally `jq`-merges the single `.mcpServers.lumen` key
into `~/.claude.json` so that tools inheriting from the default config — MiMo Code lists its
servers as `claude:~/.claude.json` — can see it. Never hand-edit the rest of `~/.claude.json`;
it also holds session and project state.

A full `-c claude` rollback restores `~/.claude.json` byte-exactly, which removes the mirror
along with the Glyphdown hooks and the `claude mcp` `ACTION`.

Remove the Glyphdown `PreToolUse` / `PostToolUse` entries while preserving your own hooks:

```bash
tmp=$(mktemp)
jq '
  def strip: (. // []) | map(select(([.hooks[]?.command] | index("glyphdown")) | not));
  .hooks.PreToolUse |= strip | .hooks.PostToolUse |= strip
' ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
```

The two marketplace repositories the wizard cloned:

```bash
rm -rf ~/.claude/plugins/marketplaces/Sagargupta16/claude-cost-optimizer
rm -rf ~/.claude/plugins/marketplaces/JCodesMore/jcodesmore-plugins
```

### `kimi` — `~/.kimi-code/mcp.json`

```bash
tmp=$(mktemp)
jq 'del(.mcpServers.lumen, .mcpServers.codegraph)' ~/.kimi-code/mcp.json > "$tmp" \
  && mv "$tmp" ~/.kimi-code/mcp.json
```

### `opencode` — `~/.config/opencode/opencode.json`

Opencode uses a `.mcp` object, **not** `.mcpServers`, and the wizard only adds `lumen`
there:

```bash
tmp=$(mktemp)
jq 'del(.mcp.lumen)' ~/.config/opencode/opencode.json > "$tmp" \
  && mv "$tmp" ~/.config/opencode/opencode.json
```

### `qwen` — `~/.qwen/settings.json`

Two separate edits live in this file: the MCP merge from Step 5 and the
`.usageStatisticsEnabled` flag from the Step 3 telemetry opt-out. Remove whichever you want
back:

```bash
tmp=$(mktemp)
jq 'del(.mcpServers.lumen, .mcpServers.codegraph)' ~/.qwen/settings.json > "$tmp" \
  && mv "$tmp" ~/.qwen/settings.json

tmp=$(mktemp)
jq 'del(.usageStatisticsEnabled)' ~/.qwen/settings.json > "$tmp" \
  && mv "$tmp" ~/.qwen/settings.json      # back to Qwen's own default
```

### `speckit` — the SpecKit CLI

```bash
uv tool uninstall specify-cli
```

This is the exact command the manifest records under component `speckit`, so
`./scripts/rollback-agents-wizard.sh -c speckit --run-actions --yes` does the same thing.

### Telemetry settings

The `~/.bashrc` opt-out block is covered by the `shell` block above, and the Qwen flag by
the `qwen` block. CodeGraph's own switch is out of band — the wizard ran
`codegraph telemetry off`, and CodeGraph persists that in `~/.codegraph/telemetry.json`:

```bash
codegraph telemetry --help    # its own re-enable command
```

There is nothing to undo for Lumen: it ships no telemetry, so the wizard never set anything
for it.

### MiMo Code

There is no MiMo-specific config file to undo. MiMo **inherits** MCP servers from
`~/.claude.json` (it lists them as `claude:~/.claude.json`), so removing the mirror is what
removes Lumen from MiMo:

```bash
jq 'del(.mcpServers.lumen)' ~/.claude.json > /tmp/cj && mv /tmp/cj ~/.claude.json
mimo mcp list | grep lumen        # should now find nothing
```

Restart MiMo afterwards — MCP servers are launched at session start.

### `npm` and `uv` — global CLI tools

Uninstall only what you want gone, and only if the wizard installed it (it skips anything
already present):

```bash
npm uninstall -g @colbymchenry/codegraph glyphdown @qwen-code/qwen-code
uv tool uninstall specify-cli
```

Kimi, Opencode and MiMo Code are **not** npm-installed by the wizard — they ship their own
installers and are only detected. Remove them with their vendors' instructions.

### Everything else

```bash
lumen purge                                   # drop every index under ~/.local/share/lumen (do this before deleting the launcher)
rm -rf ~/.local/share/setup-agents-wizard     # the backup sessions themselves — only once you are sure
```

Bun (`~/.bun`), the ashlr **plugin** (`~/.claude/plugins/cache/ashlr-marketplace/ashlr/` — a
clone, not a binary), Ollama and the embedding model were installed by their own vendors'
scripts; see [`FAQ.md`](./FAQ.md#how-do-i-completely-uninstall-what-the-wizard-added) for the
full ordered procedure. The wizard-adjacent project files it also leaves behind:

```bash
rm -f  MANUAL-STEPS.md .lumen-reindex.log     # regenerated artifacts, not in the manifest
rm -rf .ashlrcode                             # the ashlr genome, if you ran /ashlr:ashlr-genome-init
./scripts/ollama-vulkan-remediation.sh --rollback   # ONLY if you applied it; restores the defect
```

---

## Safety guarantees

### What is reversible

| Guarantee | Mechanism |
| :--- | :--- |
| A file the wizard **modified** is restored byte-exactly, with its original permissions | `cp -p` both ways; `sha256_before` records the original digest for verification (tests **G5**, **G7**, **G8**) |
| A file the wizard **created** is deleted | `CREATED` rows (test **G9**) |
| An agent config the wizard had to **create from scratch** is deleted, not left behind as an empty `{}` | `configure_mcp_for_agent` and the Glyphdown hook step call `snapshot_before` **before** seeding `{}`, so the row is `CREATED`. Applies to `~/.kimi-code/mcp.json`, `~/.qwen/settings.json` and `~/.claude/settings.json` on a clean machine (tests **G16**, **G17**; **G18** checks a pre-existing config still restores to its real content) |
| A file touched by several steps restores to its **true** pre-run original | First snapshot wins in `snapshot_before` (test **G6**) |
| Every install the wizard performs itself can be undone | `npm_install_if_missing` writes an `ACTION` under `npm`, and the `uv` branch writes `uv tool uninstall specify-cli` under `speckit` (test **A28**). Only the third-party installers — Bun, ashlr, WOZCODE — record nothing |
| You can preview any rollback without risk | `--dry-run` changes nothing and exits `0` (test **G10**) |
| You can undo one part without disturbing the others | `--component`, repeatable (tests **G11**, **G12**) |
| The rollback itself can be undone | `<session>/pre-rollback-<UTC>/` is written before anything is touched (test **G13**) |
| Non-file changes are never executed behind your back | `ACTION` rows are printed; `--run-actions` is required to run them (test **G14**) |
| Your own content in `~/.bashrc` / `~/.bash_profile` survives both directions | The wizard only rewrites its marker-delimited blocks; rollback restores the whole file from its snapshot |
| Pre-existing MCP servers and config keys survive | Every merge is a `jq` merge that preserves foreign keys (test **D4**) |

### What is *not* reversible, or not covered

- **Anything outside the manifest.** Bun, ashlr, WOZCODE, Ollama, its systemd unit, the
  pulled embedding model, the two `git clone`d marketplaces, `specify init` output, the
  SuperSpec checkout, `<project>/.codegraph/`, `<project>/MANUAL-STEPS.md`,
  `<project>/.ashlrcode/genome/`, `<project>/.lumen-reindex.log` and
  `~/.codegraph/telemetry.json` have no rows and are untouched by rollback.
- **Nothing the three operational scripts do is in the manifest.** They run outside the
  wizard's transaction entirely, and each has its own undo:

  | Change | Made by | Undo |
  | :--- | :--- | :--- |
  | `GGML_VK_VISIBLE_DEVICES=-1` in `/etc/sysconfig/ollama`, plus a service restart | `ollama-vulkan-remediation.sh --apply` | `./scripts/ollama-vulkan-remediation.sh --rollback` (needs `sudo`; **restores the defect**) |
  | A rebuilt Lumen index | `lumen-reindex.sh` | `lumen purge <path>`, then re-index |
  | `<project>/.lumen-reindex.log` | `lumen-reindex.sh` | `rm` it |
  | *(nothing)* | `lumen-index-doctor.sh` | Read-only by construction — it opens the database `mode=ro` and never calls the embedding backend (tests **I10**, **I14**) |

  See [`OPERATIONAL-SCRIPTS.md`](./OPERATIONAL-SCRIPTS.md).
- **The telemetry opt-out is only *partly* covered.** The `~/.bashrc` block is inside the
  `shell` snapshot and the `~/.qwen/settings.json` edit inside the `qwen` one, so both come
  back with a normal restore. But `codegraph telemetry off` is an out-of-band CLI call with
  no `ACTION` row — CodeGraph keeps that state in `~/.codegraph/telemetry.json`, and you
  re-enable it yourself (`codegraph telemetry --help`).
- **Changes you made after the wizard ran are overwritten** by a `MODIFIED` restore. They
  are not lost — they are in the `pre-rollback-<UTC>` snapshot — but they do not survive in
  place. Run `--dry-run` first.
- **`ACTION` failures do not fail the run.** A failed undo command warns and the exit code
  stays `0`. Verify with `claude mcp get lumen` or `npm ls -g`.
- **The manifest stores absolute paths.** Moving or renaming the state directory after a
  run breaks restore: `MODIFIED` rows fail with
  `❌ Backup missing for <target> (<backup>)` and the tool exits `1`.
- **A session is one run, not a machine state.** Rolling back the newest session returns
  you to the state immediately before it, not to a pristine system.
- **`.bak.<ts>` siblings are never removed** by rollback, and neither are the session
  directories themselves.
- **Lumen indexes are out of scope.** `~/.local/share/lumen/` is written by `lumen index`;
  use `lumen purge`.
- **Rollback does not restart anything.** Open a new shell for `PATH` changes, and restart
  each agent for MCP changes — the tool prints the reminder for the shell case.

---

## Related

- [`README.md`](./README.md) — what the wizard installs, and the doc index.
- [`MANUAL.md`](./MANUAL.md) — function-by-function reference, including `backup_init`,
  `snapshot_before`, `record_action` and `_sha`.
- [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md#12-restoring-from-a-backup-session) — restoring
  from a session, and `Backup missing` failures.
- [`FAQ.md`](./FAQ.md#how-do-i-completely-uninstall-what-the-wizard-added) — the full
  uninstall procedure.
- [`OPERATIONAL-SCRIPTS.md`](./OPERATIONAL-SCRIPTS.md) — the three post-install scripts, none
  of which is covered by this manifest, and how to undo each of them.
- [`ACTION-REQUIRED.md`](./ACTION-REQUIRED.md) — `MANUAL-STEPS.md` and the other artifacts the
  rollback tool deliberately leaves alone.
- `scripts/rollback-agents-wizard.sh` — the tool itself; `--help` prints its header comment.
