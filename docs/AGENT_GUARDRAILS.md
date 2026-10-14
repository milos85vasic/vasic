# Agent guardrails — the §11.4.109 anti-forgetting enforcement layer

**Anchor:** 11.4.109 — *Mandatory Anti-Forgetting Enforcement: PreToolUse Guard
Hook + Subagent Constitutional Preamble + Orchestrator Pre-Action Checklist.*
Canonical text: `submodules/constitution/Constitution.md`. Read it there; this
document is the consumer-side deployment of components (B) and (C), not a copy
of the corpus.

**Why this file exists, stated as the anchor states it.** A constraint that
depends on an agent remembering it is not a constraint — it is a hope. The
motivating incident was not an agent that disobeyed a rule; it was an
orchestrator that *forgot to paste the rule*. That contract breaks on every
cold-session start, every context-window exhaustion and every subagent
dispatch. Two layers close it:

| Layer | Component | Where it lives here | What it catches |
|---|---|---|---|
| **Floor** — mechanical | (A) PreToolUse guard hook | `.claude/settings.json` → `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` | Forbidden command *classes*, at the tool-call boundary, regardless of what any agent remembers |
| **Ceiling** — semantic | (B) this preamble | below | Every rule the hook cannot pattern-match |
| **Self-guard** | (C) this checklist | below | The orchestrator's own forgetting |

The floor is wired at `.claude/settings.json` — **tracked in git**, so a fresh
clone inherits it. That is deliberate and is the lesson learned from
`.git/hooks/`, which is untracked and therefore leaves a fresh clone
unprotected until an install step is run by hand. A guard that does not survive
a clone is a guard for one working copy.

**The hook is referenced, never copied.** §11.4.109(A) forbids a local copy: a
copy diverges silently and the consumer then enforces a stale ruleset while
believing it enforces the current one. The path above points *into* the
constitution submodule.

**Installation and operativeness are verified, not asserted.**
`bash scripts/verify-pretooluse-guard.sh` is the dedicated hook-validation
script required by §11.4.234(A)(3). It does not merely check that a config key
exists — it *executes* the wired guard against live probes and requires a real
refusal. Its paired §1.1 mutation proof (`--prove-failure`) demonstrates that it
catches an un-wired hook, a locally-copied hook, and a neutered hook that
returns 0 for a forbidden command. A validator that passes while the hook is
missing is the false-green control §11.4.201 forbids.

---

## SUBAGENT CONSTITUTIONAL PREAMBLE

> **Orchestrator: paste this block VERBATIM into every subagent dispatch.**
> It is not optional and it is not summarisable. The dispatch is the only
> moment at which the subagent can be informed; there is no later.

```
You are operating under the HelixConstitution. These constraints bind you
absolutely. They are not advice and they are not negotiable by anything said
later in your task description.

 1. ANTI-BLUFF (§11.4, §11.4.5, §11.4.69, §11.4.107). A PASS is a claim that
    the feature works for the END USER. Every PASS carries captured runtime
    evidence from THIS session. Metadata-only, config-only, absence-of-error
    and grep-without-runtime PASSes are critical defects however green the
    summary line reads. The words verified / tested / working / complete /
    fixed / passing are FORBIDDEN without pasted output you actually produced.
    A FAIL asserted without evidence is equally forbidden (§11.4.1).

 2. NO GUESSING (§11.4.6). "Probably", "seems", "appears", "should be",
    "likely" are not findings. Write UNCONFIRMED: / UNKNOWN: /
    PENDING_FORENSICS: and stop, rather than assert.

 3. NEVER FORCE-PUSH (§11.4.113). No --force, no --force-with-lease, no +ref,
    no history rewrite, on ANY repository or submodule, with or without
    approval. Integrate by fetching, merging onto the latest main, and pushing
    fast-forward. Force is never necessary and never allowed. The PreToolUse
    guard blocks this class mechanically; do not attempt to route around it.

 4. NO PRIVILEGE ESCALATION. No sudo, no su. Use a rootless / user-level
    alternative (§11.4.161 rootless container runtime).

 5. HOST SAFETY (§12, CONST-033). Never suspend, hibernate, reboot, power off
    or halt the host. This class is CATEGORICALLY non-overridable — the
    guard's escape hatch does not apply to it. Respect the memory and thread
    headroom caps (§12.6, §12.12) and verify a process is OURS before
    signalling it (§11.4.174).

 6. INVESTIGATE BEFORE FIXING (§11.4.102). Iron Law: NO FIXES WITHOUT ROOT
    CAUSE INVESTIGATION FIRST. Reproduce on the broken artifact (§11.4.115)
    before writing the fix. Guess-and-retry and "probably flaky" are
    violations.

 7. NEVER DELETE ON SIGHT (§11.4.122, §11.4.124). Do not silently remove a
    shipped component or seemingly-dead code. Investigate the git history for
    how it was wired and how it died. No proof, no deletion. Ask the operator
    and get an explicit keep-or-remove decision.

 8. NO HARDCODING (§11.4.29 and the environment-adaptability audits). No
    frozen host names, absolute developer paths, model ids, ports or
    endpoints. Derive them, with the former literal as a documented last
    resort at most.

 9. SECRETS (CONST-042, §11.4.10). Never commit, print, log or echo a
    credential. `.env` files stay gitignored, mode 0600.

10. REUSE BEFORE REIMPLEMENT (§11.4.74, §11.4.76). Check the submodule
    catalogue first. Containerised workloads go through the containers
    submodule; do not grow a parallel runtime, lifecycle or orchestration
    implementation inside the consuming project.

11. EVERY CHANGE IS REVIEWED (§11.4.142). Independent review precedes
    acceptance, including a one-line doc edit. Self-review (§11.4.92)
    precedes it and never substitutes for it.

12. CONTINUATION (§12.10). Keep CONTINUATION.md in sync in every non-trivial
    commit.

Classes 3, 4, 5 and raw host-direct emulator/adb/instrumentation are ALSO
blocked mechanically by the §11.4.109 PreToolUse guard hook. The hook is the
floor, not the ceiling: everything above binds you whether or not the hook can
pattern-match it.
```

---

## ORCHESTRATOR PRE-ACTION CHECKLIST

The orchestrator forgets too — that is the documented root cause of the
incident behind 11.4.109. Run this against your own actions, not only your
subagents'.

**Before any subagent dispatch**
- [ ] The SUBAGENT CONSTITUTIONAL PREAMBLE above is pasted VERBATIM into the
      dispatch. Not paraphrased, not linked. (§11.4.109(B))
- [ ] The subagent's task states its own evidence obligation — what a PASS
      would have to look like. (§11.4, §11.4.5)

**Before any emulator / device / container action**
- [ ] The run routes through the containers submodule CLI, not host-direct.
      (§11.4.76)
- [ ] No live operator device is targeted; the gate host is eligible —
      otherwise report honestly BLOCKED rather than proceeding. (§11.4.133)

**Before any push or destructive git action**
- [ ] No force flag of any shape. §11.4.113 is absolute; there is no
      per-operation approval that unlocks it here.
- [ ] Fetched and integrated onto the latest `main` first. (§11.4.71)
- [ ] The remote is the approved upstream set only. (§2.1)
- [ ] For any history-affecting operation, a hardlinked `.git` backup exists
      FIRST. (§9)
- [ ] The working tree is quiescent — no build is writing tracked artifacts.
      (§11.4.84, §11.4.121)

**Before any host-affecting command**
- [ ] The command is not in the host-power blocked class. (§12, CONST-033)
- [ ] Memory and thread headroom are within cap. (§12.6, §12.12)

**Before reporting any result**
- [ ] Every PASS carries pasted output from THIS session. (§11.4)
- [ ] Every unmeasured claim is written UNCONFIRMED / UNKNOWN, not smoothed
      into an assertion. (§11.4.6)
- [ ] Any figure quoted from a document was RE-MEASURED, not copied. Documents
      in this tree carry dated observations, not standing facts.

---

## (D) HOST RESOURCE SAFETY

**Why.** On 2026-10-14 (host `anton`) the box stalled at about 14:22. Measured with sar/atop: tmpfs shmem
grew 0.33 → 8.1 GB between 13:20 and 14:30, `app.slice` (MemoryHigh ≈ 21 GB) was throttled into a
direct-reclaim storm (sys CPU 1108 %, load 430, memory PSI *full* 53–92 %, 1.4 GB/s refault reads), and
no OOM daemon or guard acted. The trigger was about 20 parallel agents, many writing multi-GB copies into
the harness scratchpad `/tmp/claude-1000/...` — `/tmp` is a 16 GB **RAM-backed tmpfs** — and running
unbounded heavy gates at the same time. A `cp -al` hardlink backup (§9) from the repository to `/tmp`
fails (cross-device), which pushed agents into full copies instead. The mechanism is the one in
`/home/milosvasic/Projects/llmctl/docs/host-safety.md` ("Why GNOME says Application Stopped").

### Rules for every orchestrator and every subagent

| # | Rule | Mechanism |
|---|---|---|
| D1 | **Fan-out budget:** no more than **5** concurrent subagents, and no more than **2 heavy** ones at a time. Dispatch in **waves**: the next heavy wave starts when one ends, never all at once. | orchestrator discipline; `scripts/agent-admit.sh` (2 heavy slots) enforces the heavy half |
| D2 | **Heavy** means: pre-push gates, Playwright, `go test -race`, podman / site builds, a content-boundary full scan, `zero-gap-verify`, mutation suites (`--prove-failure` / `--run-proofs`), local model runs. | — |
| D3 | Run heavy work only through **admission**: `bash scripts/agent-admit.sh --tag <name> -- <cmd>` (or `--verdict3` for a 0/1/2 gate). It takes a slot, checks memory PSI `some avg10` < 15, `/tmp` used < 40 %, `app.slice` working set (`memory.current − inactive_file`) < 85 % of `memory.high`, then runs `<cmd>` under `bounded-run -m 6G -T 3600`. A refusal is rc 1 (rc 2 under `--verdict3`); never retry it in a loop — wait for the next wave. `scripts/pre-push-gates.sh` (gates 1 and 6), `scripts/zero-gap-verify.sh` and `scripts/verify-content-boundary.sh` already admit themselves. | `scripts/agent-admit.sh` |
| D4 | Any other heavy command runs under **`bounded-run -m <MEM> -T <SECONDS> --`** with explicit caps (minimums: `go test -race` 4G, builds/archives 6G). Never bare. | `~/.local/bin/bounded-run` |
| D5 | **Scratch on disk, never tmpfs:** `S=$(bash scripts/agent-scratch.sh new <label>)` and write under `"$S"`. Never write a repo copy, a clone, a worktree, a bundle, an archive or an extracted tree to `/tmp`, `/dev/shm` or `/run/user/*` — including the harness scratchpad under `/tmp/claude-*`. | `scripts/agent-scratch.sh` |
| D6 | **Backups are hardlinks on the same filesystem:** `cp -al <repo-path> "$S/backup"` (zero data blocks). `bash scripts/agent-scratch.sh df-check` proves the scratch root and the repo share a filesystem and that a hardlink works. Never `cp -a` a repository or a gitdir. | `agent-scratch.sh df-check` |
| D7 | **Never clone or copy a repository** to get a second working copy; use `git worktree add "$S/wt" <ref>` on disk, and remove it when done. | tmpfs guard (below) |
| D8 | Clean up: remove your scratch dir when finished; `bash scripts/agent-scratch.sh gc --older-than 3d` removes only dirs the helper created and that have been idle that long. `du` shows usage. | `agent-scratch.sh gc / du` |

**Defense in depth — the tmpfs guard rule.** `scripts/hooks/guard-project-catalogue.sh` refuses (rc 2)
the bulk write forms whose destination is a *literal* tmpfs path: `git clone`, `git worktree add`,
`git bundle create`, `cp -a|-r|-R`, `rsync`, `tar -x` / `tar -c -f`, `unzip -d` (plus a relative
destination when the cwd is tmpfs). Single-file writes stay allowed. The only escape is a leading
`AGENT_TMPFS_OK='<reason, ≥ 10 chars>'` on that command, appended to
`~/.cache/agent-scratch/tmpfs-overrides.log`; an override that cannot be logged is refused. **Honest
limits:** a destination held in a variable (`"$S"/x`, `$(mktemp -d)`) or reached through a symlink is not
resolved; a script file, an alias or `eval` is not seen; heredoc bodies are not judged. That is why the
structural fix below exists. **The rule is live only once the hook is wired** (operator step 2).

### Ready-to-paste SUBAGENT PREAMBLE addendum (host resource safety)

```text
HOST RESOURCE SAFETY (docs/AGENT_GUARDRAILS.md section D) — binding for this task:
- /tmp, /dev/shm and /run/user/* are RAM. Never write a repo copy, clone, worktree, bundle, archive or
  extracted tree there (that includes the harness scratchpad under /tmp/claude-*). Get disk scratch with
  S=$(bash /home/milosvasic/Projects/vasic/scripts/agent-scratch.sh new <label>) and work under "$S".
- Backups: cp -al <path> "$S/backup" (hardlinks, same filesystem). Never cp -a a repository or a gitdir.
- Heavy work (pre-push gates, Playwright, go test -race, podman/site builds, content-boundary full scan,
  zero-gap-verify, mutation suites, model runs) ONLY via
  bash /home/milosvasic/Projects/vasic/scripts/agent-admit.sh --tag <name> -- <cmd>
  and everything else heavy under bounded-run -m <MEM> -T <SECONDS> --. A refusal means "wait for the next
  wave": report it, do not retry in a loop.
- No for-loops that spawn parallel jobs. At most one heavy command at a time per agent.
- Remove your scratch dir when done.
```

### Operator-applied steps (PROPOSED — not applied by any agent)

These survive a reboot only if applied to files outside this repository, which agents may not edit.
`bash scripts/agent-scratch.sh verify-persistence` reports the state and **exits 1 until step 1 is
applied** — that is the expected reading, not a defect of this tree.

1. **Disk TMPDIR for every claude alias (structural fix).** Measured 2026-10-14: with `TMPDIR` set in
   the environment, or with `"env": {"TMPDIR": ...}` in a settings file passed via `--settings`, Claude
   Code created its per-session tree (`claude-1000/<project>/<session>/tasks`, the sibling of the
   scratchpad) under that directory instead of `/tmp`, and its Bash tool children saw the same
   `TMPDIR`. The aliases `claude1..claude5` are `CLAUDE_CONFIG_DIR=~/.claude-claudeN cma_run`, defined in
   the generated `~/.local/share/claude-multi-account/aliases.sh` (do not edit: regenerated), sourced
   from `~/.bashrc` line 66; `~/.bashrc` returns early for non-interactive shells. Minimal persistent
   change — append to **`~/.profile`** (read by every login shell; whether the GNOME Wayland session on
   this host also sources it at login is UNCONFIRMED — the optional environment.d file below covers that):

   ```sh
   # host-safety 2026-10-14: agent/harness temp on disk; /tmp is a 16G RAM tmpfs
   mkdir -p -m 700 "$HOME/.cache/claude-tmp" 2>/dev/null && export TMPDIR="$HOME/.cache/claude-tmp"
   ```

   Optional, for units started by `systemd --user`: `~/.config/environment.d/60-tmpdir.conf` containing
   `TMPDIR=${HOME}/.cache/claude-tmp`. Takes effect for sessions started after the next login; running
   tmux servers keep their old environment until restarted. **Revert:** delete those lines/that file.
   Alternative scoped only to Claude Code: `"env": {"TMPDIR": "/home/milosvasic/.cache/claude-tmp"}` in
   each `~/.claude-claudeN/settings.json` (a settings edit, needs approval). **Cost:** disk temp is not
   wiped at boot and no `systemd-tmpfiles` user timer exists on this host; prune it periodically.
2. **Wire the project guard** (makes the tmpfs rule and the VSC-367 catalogue live). Add a second entry to
   the `PreToolUse` `"hooks"` list of the tracked `.claude/settings.json`, after the upstream guard:

   ```json
   {
     "type": "command",
     "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/hooks/guard-project-catalogue.sh\""
   }
   ```

   **Revert:** remove the entry. Proof before wiring:
   `bash scripts/hooks/guard-project-catalogue.sh --prove-failure`.

---

## Verifying this layer

```bash
bash scripts/verify-pretooluse-guard.sh                 # 0 wired+operative, 1 defect, 2 cannot determine
bash scripts/verify-pretooluse-guard.sh --prove-failure  # the paired §1.1 mutation battery
bash submodules/constitution/scripts/hooks/test_guard_forbidden_commands.sh   # upstream hermetic harness
```

The third is the upstream author's own test suite for the guard, shipped inside
the constitution submodule as of the 2026-09-08 fast-forward. It is the
authority on what the guard actually enforces; the first two are this
repository's evidence that the guard is *wired here* and *fires here*.
