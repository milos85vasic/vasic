# Storage policy: keep the root filesystem free

| Field | Value |
|---|---|
| Status | In force from 2026-11-24 (operator directive: root filesystem repeatedly filled to 100%) |
| Applies to | The development host; every agent, script and service run as the operator account |
| Instrument | `scripts/storage-report.sh` (read-only, three-valued; registered as `storage-report`) |
| Env file | `~/.config/vasic/storage.env` (host-local, not tracked; reproduced below) |

## Contents

1. Rule
2. Which path holds what
3. The env file
4. How to add a new storage consumer
5. Moving an existing directory safely
6. Podman graphroot specifics
7. Checking the policy
8. Honest boundaries

## 1. Rule

The root filesystem (`/`, one NVMe) must never carry caches, model stores, container
images or other bulk, regenerable data. Two data drives exist and are mounted from
`/etc/fstab`:

| Alias | Mount | Medium | Use for |
|---|---|---|---|
| FAST | `/mnt/DATA1TB` | NVMe, ext4 | build and package caches, container storage, anything latency-sensitive |
| BULK | `/mnt/DATA7TB` | SATA, ext4 | model weights, archives, cold scratch, old transcripts and evidence |

Everything is user-level. No privileged command is part of this policy.
User data and work are relocated (copy, verify, then swap), never deleted; only
provably regenerable caches may be dropped, and their size is recorded.

## 2. Which path holds what

| Consumer | Original path | Now | Drive |
|---|---|---|---|
| Podman graphroot (images, containers, volumes) | `~/.local/share/containers/storage` | symlink to `/mnt/DATA1TB/containers/storage` | FAST |
| Podman runroot | `/run/user/1000/containers` | unchanged (tmpfs) | n/a |
| Go build cache | `~/.cache/go-build` | `GOCACHE=/mnt/DATA1TB/claude-work/gocache` | FAST |
| Go module cache | `~/go/pkg/mod` | `GOMODCACHE=/mnt/DATA1TB/claude-work/gomodcache` (and symlink) | FAST |
| npm cache | `~/.npm` | `npm_config_cache=/mnt/DATA1TB/claude-work/npm` (and symlink) | FAST |
| Gradle home | `~/.gradle` | `GRADLE_USER_HOME=/mnt/DATA1TB/claude-work/gradle` (and symlink) | FAST |
| Maven repository | `~/.m2` | symlink to `/mnt/DATA1TB/claude-work/m2` | FAST |
| pip cache | `~/.cache/pip` | `PIP_CACHE_DIR=/mnt/DATA1TB/claude-work/pip-cache` | FAST |
| Cargo / rustup (if ever installed) | `~/.cargo`, `~/.rustup` | `CARGO_HOME`, `RUSTUP_HOME` under `/mnt/DATA1TB/claude-work` | FAST |
| LSP servers (clangd, swift/sourcekit-lsp, kotlin-lsp, lsp-dl, ruby gems) | `~/.local/share/{clangd,swift,kotlin-lsp,lsp-dl,gem}` | symlinks to `/mnt/DATA1TB/claude-work/lsp/*`; `~/.local/bin` wrappers unchanged | FAST |
| Local model weights (llmctl) | `~/.local/share/llmctl/models` | symlink to `/mnt/DATA7TB/claude-work/llmctl/models` | BULK |
| Cold agent scratch and archives | `~/.cache/claude-tmp/...` (idle sessions) | symlinks into `/mnt/DATA7TB/claude-work/scratch-archive` | BULK |
| Agent scratch (current session) | `$TMPDIR` set by the agent harness | unchanged; keep large outputs on FAST or BULK explicitly | n/a |

`~/Projects` (the repositories and their worktrees) stays on the root filesystem. Working
trees are never relocated by this policy; remove merged, clean agent worktrees with
`git worktree remove` instead.

## 3. The env file

`~/.config/vasic/storage.env` is sourced from `~/.bashrc` and `~/.profile`. It is the single
place that names the drives; a new shell on this host inherits every variable.

```sh
VASIC_FAST_STORE=/mnt/DATA1TB/claude-work
VASIC_BULK_STORE=/mnt/DATA7TB/claude-work
export VASIC_FAST_STORE VASIC_BULK_STORE
if [ -d "$VASIC_FAST_STORE" ]; then
  export GOCACHE="$VASIC_FAST_STORE/gocache"
  export GOMODCACHE="$VASIC_FAST_STORE/gomodcache"
  export npm_config_cache="$VASIC_FAST_STORE/npm"
  export PIP_CACHE_DIR="$VASIC_FAST_STORE/pip-cache"
  export GRADLE_USER_HOME="$VASIC_FAST_STORE/gradle"
  export CARGO_HOME="$VASIC_FAST_STORE/cargo"
  export RUSTUP_HOME="$VASIC_FAST_STORE/rustup"
fi
```

It carries no secrets. The `-d` guard means a host without the drives falls back to tool
defaults instead of failing. `TMPDIR` and `XDG_CACHE_HOME` are intentionally not set here:
the agent harness and desktop applications own them.

## 4. How to add a new storage consumer

1. Decide the drive: latency-sensitive or rebuilt often means FAST; large, rarely read, or
   archival means BULK.
2. Prefer the tool's own relocation setting (an environment variable or config key) and add
   it to `storage.env`. If the tool has none, relocate the directory and leave a symlink at
   the original path (section 5).
3. Add the original path to the `CONSUMERS` array in `scripts/storage-report.sh` so a
   regression to the root filesystem fails the check.
4. Add a row to the table in section 2 in the same change.
5. Never point a new consumer at `/tmp`-like paths on root, `~/.cache` or `~/.local/share`
   for anything that can exceed a few hundred MiB.

## 5. Moving an existing directory safely

```bash
SRC=~/.some/cache; DST=/mnt/DATA1TB/claude-work/some-cache
mkdir -p "$DST"
rsync -a "$SRC"/ "$DST"/              # bulk copy while the tool may still run
rsync -a -n -i "$SRC"/ "$DST"/        # dry run: empty output means identical
mv "$SRC" "$SRC.old-premove" && ln -s "$DST" "$SRC"
# use the tool, confirm it works, then remove "$SRC.old-premove"
```

Copy from source to target only; never stage data on root. Keep `*.old-premove` until the
tool has been exercised. Roll back with `rm "$SRC" && mv "$SRC.old-premove" "$SRC"`.

## 6. Podman graphroot specifics

- Rootless storage holds files owned by sub-uids, so copy with
  `podman unshare rsync -aHAX --numeric-ids`, and remove the old tree with
  `podman unshare rm -rf`.
- Keep the original path as a symlink to the new location. The libpod database records the
  graph root path; podman evaluates symlinks when it compares, so the symlink keeps the
  database valid and keeps volume mount points stable. This was verified on podman 5.7.0
  with a scratch root before the real move.
- Stop every container before the final sync (no concurrent writers), then start the same
  containers again and check `podman ps` health.
- Do not edit `graphroot` in `~/.config/containers/storage.conf` to a different path: the
  database would then disagree with the configuration.

## 7. Checking the policy

```bash
bash scripts/storage-report.sh               # report + verdict
bash scripts/storage-report.sh --no-sizes    # fast
bash scripts/storage-report.sh --threshold 85
bash scripts/storage-report.sh --prove-failure
```

Exit codes: 0 root within threshold and every present consumer off-root; 1 a finding (root
usage above the threshold, default 90 percent, or a listed consumer resolving to the root
filesystem); 2 could not determine, which is never a pass.

## 8. Honest boundaries

- `~/Projects` (hundreds of GiB, including worktrees) and `~/.local/share/JetBrains`,
  `~/.local/share/lumen`, application data under `~/.config`, and `/usr/share/ollama`
  (owned by another account, needs privileges) are not covered by this policy's moves.
- `storage-report.sh` checks placement and usage only for the listed consumers; it does not
  scan for new large directories. Run `du -xk -d1 ~ | sort -rn | head` periodically.
- Symlinks protect only the tools that follow them. A tool that resolves and rewrites its
  own path (rare) must be re-pointed through its setting instead.
