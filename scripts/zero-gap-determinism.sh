#!/usr/bin/env bash
# zero-gap-determinism.sh — feature 010 T035: DETERMINISM HARNESS for the sweep runner.
#
# ── Purpose ──────────────────────────────────────────────────────────────────
# Proves (or refutes) that scripts/zero-gap-sweep.sh prints BYTE-IDENTICAL
# reports when it is run N times against ONE frozen state. It makes a REAL copy
# of the tree (rsync -a, never hardlinks) into a private DISK-backed scratch directory,
# proves the copy is faithful to the source and stays frozen, runs the COPY's
# own runner N times against the copy, and compares the sha256 of the N stdout
# reports. A difference on a proven-frozen copy is a determinism defect (FR-003,
# FR-015, SC-001, SC-006): such a sweep report is UNSTABLE and is never evidence.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   zero-gap-determinism.sh [--runs N] [--root <dir>] [--check <class_id>] [--class <id>]...
#                           [--scratch <dir>] [--include <relpath>]...
#                           [--reports <dir>] [--run-timeout <s>]
#                           [--diff-lines <n>] [--keep] [--allow-tmpfs]
#   zero-gap-determinism.sh --prove-failure   paired proof (§1.1) on throwaway repos
#   zero-gap-determinism.sh --help
#
#   --runs N            how many sweeps to compare (default 5, per tasks.md T035; N >= 2)
#   --root <dir>        the tree to copy (default: this repository). Must be a git
#                       work tree whose .git is a DIRECTORY (submodule git dirs under
#                       .git/modules are copied with it)
#   --check <class_id>  per-class identity check: sweep ONLY this class (passed to the
#                       runner as --class). The id must be a class_id row of the source's
#                       docs/zero-gap/sweep-classes.tsv, else rc 2. Absent => full sweep
#   --class <id>        passed through to the runner unvalidated (repeatable): a subset
#   --scratch <dir>     parent of the private copy (default: $TMPDIR, else /tmp; when
#                       that default is RAM-backed it falls back to /var/tmp, and is
#                       refused if /var/tmp is RAM-backed too). The copy of THIS
#                       repository is ~14 GB (measured 2026-09-26: ~3.6 GB tracked
#                       content of 76 checked-out repositories plus the whole .git,
#                       ~10 GB of it .git/modules); on this host /tmp is a RAM-backed
#                       tmpfs (16 GB, ~6 GB free, measured 2026-09-26), so pass a
#                       DISK-backed directory, e.g. --scratch /var/tmp/<private-dir>
#                       (§12.6). An explicit --scratch on tmpfs/ramfs (findmnt -T,
#                       else stat -f) is refused (rc 2) unless --allow-tmpfs. Before
#                       copying, the size is estimated (listed files + every .git +
#                       --include paths); less than 1.2x that free (df) => rc 2.
#                       Refused when it lies inside --root
#   --include <relpath> ALSO copy this IGNORED path (file or directory, relative to
#                       --root; repeatable; trailing slashes stripped). Refused (rc 2)
#                       when any component is a symlink or its realpath is not under
#                       --root. Ignored inputs are copied ONLY this way:
#                       T036 must pass every ignored input its classes read, e.g.
#                       --include .remember/logs/zero-gap (the content-boundary-rows
#                       cache), or those classes report "absent" on the copy
#   --reports <dir>     also copy the N reports, stderr logs and the diff there
#                       (created; refused when inside --root)
#   --run-timeout <s>   wall-clock bound for ONE runner invocation (default
#                       ZG_SWEEP_BUDGET + 900, i.e. 11700 s): on expiry TERM then
#                       KILL; the run is an infrastructure failure (rc 2)
#   --diff-lines <n>    at most this many unified-diff lines are printed (default 40)
#   --keep              keep the scratch directory (copy, reports) and print its path
#   --allow-tmpfs       permit a RAM-backed --scratch (for a SMALL tree only)
#
# ── What is compared ─────────────────────────────────────────────────────────
# The runner's STDOUT, whole, by sha256. Per the runner contract
# (specs/010-zero-gap-verified-closure/contracts/sweep-runner.md) stdout is
# "byte-identical for an unchanged fingerprinted state" (scripts/zero-gap-sweep.sh:47,
# header "Output") and the cost of each
# fingerprint window goes to STDERR; the contract lists NO volatile stdout field,
# so NOTHING is masked. Stderr is kept (--reports) but never compared.
#
# ── Frozen-copy proof (all must hold, else rc 2) ─────────────────────────────
#  1. copy is faithful: zg_fingerprint (scripts/zero-gap-lib.sh: content of every
#     tracked + untracked-not-ignored file, exec bit, symlink target, gitlinks by
#     commit + HEAD + status) of the SOURCE before the copy == of the COPY == of
#     the SOURCE after the copy (a source that moved during the copy, or a copy
#     that dropped or altered a file, is rc 2)
#  2. no hardlinks: no regular file in the copy has a link count above 1
#  3. frozen: before EVERY run and after EVERY run, both zg_fingerprint of the copy
#     AND a full stat listing of the copy (every path incl. .git and ignored files:
#     type, size, mtime, ctime, inode, mode, link count, symlink target; a
#     DIRECTORY by path, type, inode and mode only, because a transient entry —
#     git's opportunistic index.lock — moves its mtime without changing any state,
#     while a persistent create/remove still shows as a changed child path) equal
#     the values taken right after the copy. A change is attributed: "during run k" or
#     "between run k and run k+1". Either way no comparison is made (rc 2, not 1):
#     the runs did not see one state.
# The copy's git indexes are refreshed once (git update-index --refresh) BEFORE
# the frozen baseline is taken, so later read-only git calls find nothing to
# rewrite.
#
# ── Exit (three-valued; 2 is NEVER a pass) ───────────────────────────────────
#   0  IDENTICAL: every run's report is byte-identical, every run printed a
#      VERDICT line whose rc equals the runner's exit code, and the copy was
#      proven faithful, hardlink-free and frozen throughout. A runner rc 2 that
#      is DETERMINISTIC (e.g. a class that reports "cache absent" every time) is
#      part of the identity, not a failure of it
#   1  DIFFERS: every precondition above held, and two reports differ. Prints the
#      first differing run's unified diff against run 1 (at most --diff-lines
#      lines, never the full reports) and the count of differing lines
#   2  UNDETERMINED: bad usage; --root absent / not a git work tree / .git not a
#      directory; a tool missing; scratch RAM-backed (without --allow-tmpfs) or
#      with less free space than 1.2x the estimate; an --include through a symlink
#      or outside --root; the copy failed, was unfaithful, shared inodes,
#      or moved during or between runs; the runner crashed, timed out, exited
#      outside {0,1,2}, printed no VERDICT line or one whose rc disagrees with
#      its exit code, or reported VERDICT UNSTABLE
#   128+n  interrupted by SIGHUP/SIGINT/SIGTERM (1/2/15): the running runner is sent
#      TERM by its recorded pid (the `timeout` process, which forwards it to the
#      runner's process group), awaited, and the scratch removed. A signal that
#      arrives during the COPY phase takes effect when the current copy step ends
#
# ── Output (stdout) ──────────────────────────────────────────────────────────
#   DETERMINISM-COPY files=<n> fingerprint=<sha256> state=<sha256> seconds=<s>
#   DETERMINISM-RUN <i> rc=<n> verdict=<V> sha256=<sha256> bytes=<n> seconds=<s>
#   DETERMINISM-DIFF run=1 other=<k> differing-lines=<n> shown=<m>
#   <unified diff lines, at most --diff-lines>
#   DETERMINISM <IDENTICAL|DIFFERS|UNDETERMINED> rc=<n> runs=<done>/<N> reason=<text>
# Progress and the scratch path go to stderr.
#
# ── Inputs ───────────────────────────────────────────────────────────────────
# The --root tree (read only); its scripts/zero-gap-sweep.sh, scripts/zero-gap-
# lib.sh, class scripts and docs/zero-gap/sweep-classes.tsv are run FROM THE COPY.
# Environment: TMPDIR, ZG_SWEEP_BUDGET (default run timeout), and whatever the
# runner itself passes through (see its header). This script pins LC_ALL=C,
# GIT_CONFIG_GLOBAL/SYSTEM=/dev/null and core.excludesFile/attributesFile=/dev/null
# (as the runner does) and unsets GIT_DIR-style variables, so the set of files
# copied equals the set the runner fingerprints.
#
# ── Side effects ─────────────────────────────────────────────────────────────
# Writes ONLY under a fresh `mktemp -d <scratch>/zg-determinism.XXXXXX` (removed
# at exit, also on HUP/INT/TERM, unless --keep) and, with --reports, into that
# directory. Untracked NESTED repositories are copied through their own
# `git ls-files -c -o --exclude-standard` list plus their .git, so their ignored
# files (a .env) are never copied. Never writes
# into --root. Makes no network call itself; the runner's classes may (e.g.
# pointer-drift runs `git ls-remote`). Never signals a process by name/pattern.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
# bash, git, rsync, sha256sum, find (GNU -printf), stat, sort, diff, timeout,
# mktemp, awk, sed, grep, du, df, xargs, findmnt (util-linux; stat -f fallback)
# (coreutils/findutils/diffutils/rsync packages); --prove-failure also needs
# `env --default-signal` (coreutils >= 8.31). The
# runner's own dependencies (setsid, python3, iconv, ...). --prove-failure also
# needs the fixture _tests/fixtures/zero-gap/sweep/ (demo class + corpus).
#
# ── What this does NOT see (stated limits) ───────────────────────────────────
# - State OUTSIDE the copy is not frozen: remotes probed by `git ls-remote`,
#   running services/containers, host tools, $HOME. If one changes between runs,
#   the reports differ and this prints rc 1 — the diff names the class; check
#   whether the input it reads is external before calling it a runner defect.
# - Ignored files are NOT copied unless named with --include, so a class that
#   reads an ignored input (e.g. content-boundary-rows' cached gate result) sees
#   it absent in the copy. That is still ONE state for determinism purposes, but
#   the report is not the live tree's report (T036 decides what to --include).
# - Absolute symlinks in the tree still point at the live filesystem.
# - A class process the runner itself placed in its OWN session (setsid) is outside
#   the runner's process group, so a TERM forwarded by `timeout` (on --run-timeout
#   or on a signal to this harness) does not reach it; the runner's own per-class
#   budgets and ZG_RUN scan are what bound those (runner contract).
# - A change that moves ONLY a directory's mtime (an entry created and removed
#   again) is not a "move" here (directories are listed by identity), so if such a
#   transient entry changed a report, the result is rc 1 DIFFERS, not rc 2.
# - Two runs in one process tree share $HOME and host caches (go build cache, ...).
#
# ── Cross-references ─────────────────────────────────────────────────────────
# scripts/zero-gap-sweep.sh (runner), scripts/zero-gap-lib.sh (zg_fingerprint),
# docs/zero-gap/README.md, specs/010-zero-gap-verified-closure/contracts/
# sweep-runner.md, tasks.md T035. Registered in scripts/check-registry.tsv as
# `zero-gap-determinism` (proof: --prove-failure; rc-2 probe: --root /nonexistent).
set -uo pipefail

export LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
       GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
       GIT_CONFIG_KEY_1=core.attributesFile GIT_CONFIG_VALUE_1=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
      GIT_COMMON_DIR GIT_NAMESPACE GIT_CEILING_DIRECTORIES GIT_PREFIX CDPATH 2>/dev/null || true

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
HERE="$(dirname "$SELF")"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=zero-gap-lib.sh
. "$HERE/zero-gap-lib.sh" || { echo "zero-gap-determinism: COULD NOT DETERMINE — scripts/zero-gap-lib.sh unreadable" >&2; exit 2; }

usage() { sed -n '/^# ── Usage/,/^# ── What is compared/p' "$SELF" | sed '$d' | sed 's/^# \{0,1\}//'; }

# ── Hooks (overridden ONLY inside --prove-failure's in-process subshells) ────
# det_rsync_copy <src> <dst> <nul-file-list> <nul-gitdir-list>: a REAL copy (rsync -a, no -H, so
# every file in <dst> is a new inode). Copies the listed paths — the tracked + untracked-not-ignored
# files of every checked-out submodule AND of every untracked nested repository (each enumerated by
# its OWN `git ls-files -c -o --exclude-standard`, so its ignored files such as a .env are NOT
# copied), plus each submodule's .git file — then each nested repository's .git DIRECTORY and the
# umbrella .git directory whole (submodule git dirs live under .git/modules). A listed path that
# vanished (a deleted tracked file) stays absent, as in the source.
det_rsync_copy() {
    local src=$1 dst=$2 list=$3 gitdirs=$4 d
    mkdir -p "$dst" || return 1
    rsync -a --from0 --files-from="$list" --ignore-missing-args -- "$src/" "$dst/" || return 1
    rsync -a -- "$src/.git/" "$dst/.git/" || return 1
    while IFS= read -r -d '' d; do
        mkdir -p "$dst/$d/.git" && rsync -a -- "$src/$d/.git/" "$dst/$d/.git/" || return 1
    done <"$gitdirs"
    return 0
}
det_copy_files() { det_rsync_copy "$@"; }
det_between_runs() { :; }
# det_fstype <existing dir> -> filesystem type (findmnt, else stat -f); det_avail <dir> -> free bytes
det_fstype() { findmnt -no FSTYPE -T "$1" 2>/dev/null || stat -f -c %T -- "$1" 2>/dev/null; }
det_avail() { df -B1 --output=avail -- "$1" 2>/dev/null | tail -n 1 | tr -d ' '; }
# Where the DEFAULT scratch goes when $TMPDIR (or /tmp) is RAM-backed. A plain assignment, so the
# environment cannot redirect it; --prove-failure points it into its own throwaway directory.
DET_DISK_FALLBACK=/var/tmp

# det_state <dir> <listing-file> -> sha256 of a full stat listing of EVERY path under <dir> (incl.
# .git and ignored files): relative path, type, size, mtime, ctime, inode, mode, link count,
# symlink target. The NUL-separated listing is kept in <listing-file> so a move can be NAMED.
# A DIRECTORY is listed by path, type, inode and mode only: its size/mtime/ctime move whenever an
# entry is created and removed again (git's opportunistic index.lock does exactly that — measured:
# one sweep run on this repository's copy moved the mtime of 76 git directories and nothing else),
# and a persistent create/remove still shows as a changed CHILD path.
det_state() {
    { ( cd "$1" && find . -type d -printf '%P\t%y\t-\t-\t-\t%i\t%m\t-\t-\0' ) || return 1
      ( cd "$1" && find . ! -type d -printf '%P\t%y\t%s\t%T@\t%C@\t%i\t%m\t%n\t%l\0' ) || return 1
    } | LC_ALL=C sort -z >"$2" || return 1
    sha256sum <"$2" | cut -d' ' -f1
}
# det_changed <old-listing> <new-listing> -> up to 8 changed paths (percent-free, one line, paths only)
det_changed() {
    LC_ALL=C comm -z -3 "$1" "$2" | awk 'BEGIN { RS = "\0" } { sub(/^\t+/, ""); split($0, f, "\t"); if (!(f[1] in seen)) { seen[f[1]] = 1; n++; if (n <= 8) printf "%s%s", (n > 1 ? ", " : ""), (f[1] == "" ? "." : f[1]) } } END { if (n > 8) printf " (+%d more)", n - 8; if (n == 0) printf "none" }'
}

det_main() {
    local runs=5 root="$REPO_ROOT" scratch="${TMPDIR:-/tmp}" reports="" keep=0 difflines=40 allow_tmpfs=0 scratch_given=0
    local run_timeout=$(( ${ZG_SWEEP_BUDGET:-10800} + 900 ))
    local -a cargs=() includes=() checks=()
    local done_runs=0 b S="" COPY p pfx base inc live_a live_b copy_fp copy_line files base_fp base_st
    local i rc vr v sha bytes t0 t1 tc k n shown first_sha other=0 nl est need avail acc c rp d fst RUNNER_PID=""
    local -a incs=() parts=()
    local -a shas=()

    det_line() { printf 'DETERMINISM %s rc=%s runs=%s/%s reason=%s\n' "$1" "$2" "$done_runs" "$runs" "$3"; }
    undet() { det_line UNDETERMINED 2 "$*"; printf 'zero-gap-determinism: COULD NOT DETERMINE — %s\n' "$*" >&2; exit 2; }

    while [ $# -gt 0 ]; do
        case "$1" in
            --runs)        [ $# -ge 2 ] || undet "--runs needs a value"; runs=$2; shift 2 ;;
            --root)        [ $# -ge 2 ] || undet "--root needs a value"; root=$2; shift 2 ;;
            --check)       [ $# -ge 2 ] || undet "--check needs a value"; checks+=("$2"); shift 2 ;;
            --class)       [ $# -ge 2 ] || undet "--class needs a value"; cargs+=(--class "$2"); shift 2 ;;
            --scratch)     [ $# -ge 2 ] || undet "--scratch needs a value"; scratch=$2; scratch_given=1; shift 2 ;;
            --include)     [ $# -ge 2 ] || undet "--include needs a value"; includes+=("$2"); shift 2 ;;
            --reports)     [ $# -ge 2 ] || undet "--reports needs a value"; reports=$2; shift 2 ;;
            --run-timeout) [ $# -ge 2 ] || undet "--run-timeout needs a value"; run_timeout=$2; shift 2 ;;
            --diff-lines)  [ $# -ge 2 ] || undet "--diff-lines needs a value"; difflines=$2; shift 2 ;;
            --keep)        keep=1; shift ;;
            --allow-tmpfs) allow_tmpfs=1; shift ;;
            *)             undet "unknown argument '$1' (see --help)" ;;
        esac
    done
    [[ "$runs" =~ ^[0-9]+$ ]] || undet "--runs '$runs' is not a number"
    [ "$runs" -ge 2 ] || undet "--runs $runs: at least 2 runs are needed to compare anything"
    [[ "$run_timeout" =~ ^[1-9][0-9]*$ ]] || undet "--run-timeout '$run_timeout' is not a positive number of seconds"
    [[ "$difflines" =~ ^[0-9]+$ ]] || undet "--diff-lines '$difflines' is not a number"
    for b in git rsync sha256sum find stat sort diff timeout mktemp awk sed grep date realpath cp seq wc head tail tr cut du df xargs; do
        command -v "$b" >/dev/null 2>&1 || undet "required tool '$b' is not installed"
    done

    [ -d "$root" ] || undet "--root '$root' is not a directory"
    root=$(cd "$root" && pwd -P) || undet "cannot enter --root"
    git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || undet "--root $root is not a git work tree"
    [ "$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" = "$root" ] || undet "--root $root is not the TOP of its git work tree"
    [ -d "$root/.git" ] || undet "$root/.git is not a directory (a linked worktree or absorbed layout is not supported)"
    [ -f "$root/scripts/zero-gap-sweep.sh" ] || undet "$root has no scripts/zero-gap-sweep.sh to run"
    det_existing() { local x=$1; while [ ! -e "$x" ]; do x=$(dirname -- "$x"); done; printf '%s' "$x"; }
    det_is_ram() { # <dir>: 0 RAM-backed, 1 not, exits rc 2 when the type cannot be read
        local t; t=$(det_fstype "$(det_existing "$1")") || t=""
        [ -n "$t" ] || undet "cannot determine the filesystem type of $1 (findmnt and stat -f both failed)"
        case "$t" in tmpfs|ramfs) return 0 ;; esac; return 1
    }
    scratch=$(realpath -m -- "$scratch") || undet "cannot resolve --scratch"
    case "$scratch/" in "$root/"*) undet "--scratch $scratch lies inside --root: the copy would be part of the tree it copies" ;; esac
    if [ "$allow_tmpfs" -eq 0 ] && det_is_ram "$scratch"; then
        if [ "$scratch_given" -eq 0 ] && ! det_is_ram "$DET_DISK_FALLBACK"; then
            echo "zero-gap-determinism: the default scratch $scratch is RAM-backed (tmpfs); falls back to $DET_DISK_FALLBACK (disk-backed)" >&2
            scratch=$(realpath -m -- "$DET_DISK_FALLBACK") || undet "cannot resolve $DET_DISK_FALLBACK"
            case "$scratch/" in "$root/"*) undet "--scratch $scratch lies inside --root: the copy would be part of the tree it copies" ;; esac
        else
            undet "scratch $scratch is on a RAM-backed tmpfs/ramfs (the copy of this repository is ~14 GB, measured 2026-09-26): pass a disk-backed directory, e.g. --scratch /var/tmp/<private-dir>, or --allow-tmpfs for a small tree"
        fi
    fi
    if [ -n "$reports" ]; then
        reports=$(realpath -m -- "$reports") || undet "cannot resolve --reports"
        case "$reports/" in "$root/"*) undet "--reports $reports lies inside --root: nothing is ever written into the swept tree" ;; esac
    fi
    for inc in ${checks[@]+"${checks[@]}"}; do
        [ -f "$root/docs/zero-gap/sweep-classes.tsv" ] || undet "--check '$inc': $root has no docs/zero-gap/sweep-classes.tsv to validate it against"
        awk -F'\t' -v c="$inc" 'BEGIN { f = 0 } /^#/ || NF == 0 { next } !h { h = 1; next } $1 == c { f = 1 } END { exit !f }' \
            "$root/docs/zero-gap/sweep-classes.tsv" || undet "--check '$inc' is not listed in docs/zero-gap/sweep-classes.tsv (not a class_id row)"
        cargs+=(--class "$inc")
    done
    for inc in ${includes[@]+"${includes[@]}"}; do
        while [ "${inc%/}" != "$inc" ]; do inc=${inc%/}; done
        [ -n "$inc" ] || undet "--include needs a path below --root, not the root itself"
        case "/$inc/" in */../*|*/./*|//*) undet "--include '$inc' must be a normal relative path" ;; esac
        acc=""; IFS=/ read -r -a parts <<<"$inc"
        for c in "${parts[@]}"; do
            acc=${acc:+$acc/}$c
            [ ! -L "$root/$acc" ] || undet "--include '$inc': component '$acc' is a symlink (it could lead outside --root); name the real path instead"
        done
        rp=$(realpath -e -- "$root/$inc" 2>/dev/null) || undet "--include '$inc' does not exist under --root"
        case "$rp/" in "$root/"*) ;; *) undet "--include '$inc' resolves outside --root ($rp)" ;; esac
        incs+=("$inc")
    done

    mkdir -p "$scratch" || undet "cannot create --scratch $scratch"
    S=$(mktemp -d "$scratch/zg-determinism.XXXXXX") || undet "mktemp in $scratch failed"
    # shellcheck disable=SC2064
    trap "det_cleanup" EXIT
    det_cleanup() {
        if [ -n "$reports" ] && [ -d "$S/runs" ]; then mkdir -p "$reports" && cp -p "$S"/runs/* "$reports"/ 2>/dev/null; fi
        if [ "$keep" -eq 1 ]; then echo "zero-gap-determinism: kept scratch $S" >&2; else rm -rf "$S"; fi
    }
    det_on_signal() { # <name> <number>: end the runner we started (by its recorded pid), clean up, 128+n
        trap - INT TERM HUP
        if [ -n "$RUNNER_PID" ]; then kill -TERM "$RUNNER_PID" 2>/dev/null; wait "$RUNNER_PID" 2>/dev/null; fi
        echo "zero-gap-determinism: interrupted by SIG$1 — the runner was ended and the scratch is removed" >&2
        exit $((128 + $2))
    }
    trap 'det_on_signal TERM 15' TERM; trap 'det_on_signal INT 2' INT; trap 'det_on_signal HUP 1' HUP
    COPY="$S/copy"; mkdir -p "$S/runs" "$S/tmp"
    echo "zero-gap-determinism: copying $root -> $COPY" >&2

    # ── 1. the copy ─────────────────────────────────────────────────────────
    t0=$(date +%s)
    live_a=$(zg_fingerprint "$root" 2>"$S/fp.err" | cut -d' ' -f1)
    [ -n "$live_a" ] || undet "fingerprint of the source failed: $(head -c 300 "$S/fp.err")"
    : >"$S/list"; : >"$S/gitdirs"; : >"$S/queue"
    { printf '\0'; git -C "$root" submodule foreach --quiet --recursive 'printf "%s\0" "$displaypath"'; } >"$S/repos" 2>"$S/repos.err" \
        || undet "cannot enumerate the checked-out submodules: $(head -c 300 "$S/repos.err")"
    det_enum() { # <relative repo path, "" = umbrella>: its files into list, its untracked nested repos into queue
        local p=$1 base pfx
        base=$root${p:+/$p}; pfx=${p:+$p/}
        git -C "$base" ls-files -z -c -o --exclude-standard >"$S/ls" 2>"$S/ls.err" || undet "git ls-files failed in '${p:-.}': $(head -c 300 "$S/ls.err")"
        awk -v p="$pfx" 'BEGIN { RS = ORS = "\0" } !/\/$/ { print p $0 }' "$S/ls" >>"$S/list"
        awk -v p="$pfx" 'BEGIN { RS = ORS = "\0" } /\/$/ { sub(/\/$/, ""); print p $0 }' "$S/ls" >>"$S/queue"
    }
    while IFS= read -r -d '' p; do
        det_enum "$p"
        if [ -n "$p" ]; then printf '%s/.git\0' "$p" >>"$S/list"; fi
    done <"$S/repos"
    # untracked NESTED repositories (not submodules): each by its own ls-files, at any depth
    k=0
    while [ -s "$S/queue" ]; do
        k=$((k + 1)); [ "$k" -le 10000 ] || undet "more than 10000 nested repositories: refusing to enumerate"
        IFS= read -r -d '' d <"$S/queue"; tail -z -n +2 "$S/queue" >"$S/queue.t" && mv "$S/queue.t" "$S/queue"
        [ "$(git -C "$root/$d" rev-parse --show-toplevel 2>/dev/null)" = "$root/$d" ] \
            || undet "untracked directory '$d' is listed as a nested repository but is not the top of one"
        det_enum "$d"
        if [ -d "$root/$d/.git" ]; then printf '%s\0' "$d" >>"$S/gitdirs"; else printf '%s/.git\0' "$d" >>"$S/list"; fi
    done
    # ── 0. room for it: estimate (listed files + every .git + --include), refuse below 1.2x ──
    est=$( { ( cd "$root" && xargs -0 -r stat -c '%s' -- <"$S/list" 2>/dev/null ) || true
             du -sb -- "$root/.git" 2>/dev/null | cut -f1
             while IFS= read -r -d '' d; do du -sb -- "$root/$d/.git" 2>/dev/null | cut -f1; done <"$S/gitdirs"
             for inc in ${incs[@]+"${incs[@]}"}; do du -sb -- "$root/$inc" 2>/dev/null | cut -f1; done
           } | awk '{ s += $1 } END { printf "%d", s }')
    avail=$(det_avail "$S")
    [[ "$est" =~ ^[0-9]+$ ]] && [[ "$avail" =~ ^[0-9]+$ ]] || undet "cannot estimate the copy size ('$est') or the free space on $scratch ('$avail')"
    need=$(( est + est / 5 ))
    [ "$avail" -ge "$need" ] || undet "the copy needs ${need} bytes (estimate $est x 1.2) but only $avail bytes are available on $scratch: pass a --scratch with more free space"
    echo "zero-gap-determinism: estimated copy $est bytes; $avail bytes available on $scratch" >&2
    det_copy_files "$root" "$COPY" "$S/list" "$S/gitdirs" >"$S/copy.log" 2>&1 || undet "the copy failed: $(tail -c 300 "$S/copy.log")"
    for inc in ${incs[@]+"${incs[@]}"}; do
        rsync -a -R -- "$root/./$inc" "$COPY/" >>"$S/copy.log" 2>&1 || undet "copying --include '$inc' failed"
    done
    live_b=$(zg_fingerprint "$root" 2>"$S/fp.err" | cut -d' ' -f1)
    [ -n "$live_b" ] || undet "fingerprint of the source failed after the copy: $(head -c 300 "$S/fp.err")"
    [ "$live_a" = "$live_b" ] || undet "the source moved during the copy (fingerprint ${live_a:0:16}… -> ${live_b:0:16}…): the copy is of no single state"
    # ── 2. no hardlinks (checked BEFORE anything writes into the copy) ──────
    nl=$(find "$COPY" -type f -links +1 -printf '%P\n' 2>/dev/null | head -3)
    [ -z "$nl" ] || undet "the copy shares inodes with other files (hardlink, link count > 1), e.g. $(printf '%s' "$nl" | tr '\n' ' '): a write would reach the source"
    # ── 3. faithful ─────────────────────────────────────────────────────────
    git -C "$COPY" update-index -q --refresh >/dev/null 2>&1
    git -C "$COPY" submodule foreach --quiet --recursive 'git update-index -q --refresh >/dev/null 2>&1; true' >/dev/null 2>&1
    copy_line=$(zg_fingerprint "$COPY" 2>"$S/fp.err") || undet "fingerprint of the copy failed: $(head -c 300 "$S/fp.err")"
    copy_fp=${copy_line%% *}; files=$(printf '%s' "$copy_line" | sed -n 's/.* files=\([0-9]*\) .*/\1/p')
    [ "$copy_fp" = "$live_a" ] || undet "the copy is not faithful to the source (content fingerprint ${live_a:0:16}… vs copy ${copy_fp:0:16}…)"
    base_fp=$copy_fp; base_st=$(det_state "$COPY" "$S/state.0")
    [ -n "$base_st" ] || undet "stat listing of the copy failed"
    t1=$(date +%s)
    printf 'DETERMINISM-COPY files=%s fingerprint=%s state=%s seconds=%s\n' "$files" "$base_fp" "$base_st" "$((t1 - t0))"

    det_frozen() { # <when>
        local f s
        f=$(zg_fingerprint "$COPY" 2>/dev/null | cut -d' ' -f1)
        s=$(det_state "$COPY" "$S/state.now")
        [ "$f" = "$base_fp" ] || undet "the copy moved $1 (content fingerprint ${base_fp:0:16}… -> ${f:0:16}…; changed: $(det_changed "$S/state.0" "$S/state.now")): the runs did not see one state, so no comparison is made"
        [ "$s" = "$base_st" ] || undet "the copy moved $1 (stat listing changed: a write, touch, create or remove; changed: $(det_changed "$S/state.0" "$S/state.now")): the runs did not see one state, so no comparison is made"
    }

    # ── 4. the runs ─────────────────────────────────────────────────────────
    [ -f "$COPY/scripts/zero-gap-sweep.sh" ] || undet "the copy has no scripts/zero-gap-sweep.sh"
    i=1
    while [ "$i" -le "$runs" ]; do
        if [ "$i" -gt 1 ]; then det_frozen "between run $((i - 1)) and run $i"; fi
        rm -rf "$S/tmp" && mkdir -p "$S/tmp" || undet "cannot reset the per-run TMPDIR"
        echo "zero-gap-determinism: run $i/$runs" >&2
        t0=$(date +%s); rc=0
        # Started with & and awaited, so a trapped TERM/INT/HUP interrupts `wait` at once; the
        # subshell execs `timeout`, so RUNNER_PID is the timeout process, which forwards the signal
        # to the runner's process group.
        ( cd "$COPY" && TMPDIR="$S/tmp" exec timeout -k 30 "$run_timeout" bash "$COPY/scripts/zero-gap-sweep.sh" --root "$COPY" ${cargs[@]+"${cargs[@]}"} ) \
            </dev/null >"$S/runs/report.$i" 2>"$S/runs/stderr.$i" &
        RUNNER_PID=$!
        wait "$RUNNER_PID" || rc=$?
        RUNNER_PID=""
        t1=$(date +%s)
        done_runs=$i
        det_frozen "during run $i"
        case "$rc" in
            0|1|2) ;;
            124|137) undet "run $i timed out after ${run_timeout}s (rc=$rc); see stderr.$i" ;;
            *) undet "run $i: the runner exited rc=$rc (crash or infrastructure failure, outside {0,1,2}); last stderr: $(tail -c 200 "$S/runs/stderr.$i" | tr '\n' ' ')" ;;
        esac
        n=$(grep -c '^VERDICT ' "$S/runs/report.$i")
        v=$(sed -n 's/^VERDICT \([A-Z]*\) rc=\([0-9]*\) .*/\1 \2/p' "$S/runs/report.$i")
        if [ "$n" -ne 1 ] || [ -z "$v" ]; then undet "run $i printed $n VERDICT line(s) (rc=$rc): a report without exactly one VERDICT line is never evidence"; fi
        vr=${v#* }; v=${v%% *}
        [ "$vr" = "$rc" ] || undet "run $i: VERDICT says rc=$vr but the runner exited $rc"
        [ "$v" != UNSTABLE ] || undet "run $i: the runner reported VERDICT UNSTABLE (the tree moved inside its own fingerprint window): its report is not evidence"
        sha=$(sha256sum <"$S/runs/report.$i" | cut -d' ' -f1); bytes=$(wc -c <"$S/runs/report.$i")
        shas+=("$sha")
        printf 'DETERMINISM-RUN %s rc=%s verdict=%s sha256=%s bytes=%s seconds=%s\n' "$i" "$rc" "$v" "$sha" "$bytes" "$((t1 - t0))"
        if [ "$i" -lt "$runs" ]; then det_between_runs "$COPY" "$i"; fi
        i=$((i + 1))
    done

    # ── 5. compare ──────────────────────────────────────────────────────────
    first_sha=${shas[0]}
    for k in $(seq 2 "$runs"); do
        if [ "${shas[$((k - 1))]}" != "$first_sha" ]; then other=$k; break; fi
    done
    if [ "$other" -eq 0 ]; then
        det_line IDENTICAL 0 "all $runs reports byte-identical (sha256 $first_sha) on a copy proven faithful, hardlink-free and frozen"
        exit 0
    fi
    diff "$S/runs/report.1" "$S/runs/report.$other" >"$S/runs/diff.normal"
    n=$(grep -c '^[<>]' "$S/runs/diff.normal")
    diff -U1 "$S/runs/report.1" "$S/runs/report.$other" | sed '1,2d' | head -n "$difflines" >"$S/runs/diff.shown"
    shown=$(wc -l <"$S/runs/diff.shown")
    printf 'DETERMINISM-DIFF run=1 other=%s differing-lines=%s shown=%s\n' "$other" "$n" "$shown"
    cat "$S/runs/diff.shown"
    det_line DIFFERS 1 "report of run $other differs from run 1 ($n differing lines) although the copy was proven frozen: a runner or class output is not deterministic, or a class read an input outside the copy (remote, service, host tool)"
    exit 1
}

prove_failure() (
    local T FIX RUNNER LIB pass=0 fail=0 RC b live0 live1 st0 st1 strc=0 t0 t1 n w left want sig inc c p nctl=0
    for b in git rsync sha256sum mktemp find stat sort diff timeout awk sed grep cp touch setsid; do
        if ! command -v "$b" >/dev/null 2>&1; then echo "prove-failure: cannot determine — '$b' missing" >&2; exit 2; fi
    done
    FIX="$REPO_ROOT/_tests/fixtures/zero-gap/sweep"
    RUNNER="$HERE/zero-gap-sweep.sh"; LIB="$HERE/zero-gap-lib.sh"
    for b in "$FIX/demo-class.sh" "$FIX/corpus/expect.tsv" "$FIX/corpus/planted" "$FIX/corpus/clean" "$RUNNER" "$LIB"; do
        if [ ! -e "$b" ]; then echo "prove-failure: cannot determine — '$b' absent" >&2; exit 2; fi
    done
    live0=$(zg_fingerprint "$REPO_ROOT" 2>/dev/null | cut -d' ' -f1) || live0=""
    st0=$(git --no-optional-locks -C "$REPO_ROOT" status --porcelain 2>&1) || strc=$?
    if [ -z "$live0" ] || [ "$strc" -ne 0 ]; then echo "prove-failure: cannot determine — live tree fingerprint failed" >&2; exit 2; fi
    if ! env --default-signal=INT true 2>/dev/null; then echo "prove-failure: cannot determine — 'env --default-signal' (coreutils >= 8.31) is needed for the signal cases" >&2; exit 2; fi
    T=$(mktemp -d) || exit 2
    trap 'rm -rf "$T"' EXIT
    mkdir -p "$T/tmp" "$T/s"
    ok()  { pass=$((pass + 1)); echo "  PASS $1"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
    HDR=$'class_id\tpopulation\tpopulation_why\twindow\tentrypoint\tcorpus\trecall\tpopulation_kind'
    row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "demo population of $1" "fixture-only demonstration class" none \
                "scripts/zero-gap-class-$1.sh" "_tests/fixtures/zero-gap/$1/" UNKNOWN source; }
    commit() { ( cd "$1" && git add -A . && git -c user.name=t -c user.email=t@t commit -qm fixture ) >/dev/null 2>&1; }
    mkfix() { # <dir> <mode> [notes-count] [nocorpus] — throwaway repo: runner + lib + one demo class (+ corpus)
        local d=$1 m=$2 k=${3:-0} nc=${4:-} i
        rm -rf "$d"; mkdir -p "$d/notes" "$d/docs/zero-gap" "$d/scripts" "$d/_tests/fixtures/zero-gap"
        printf '.remember/\n_site/\n' >"$d/.gitignore"
        printf 'a clean note\n' >"$d/notes/ok.txt"; printf '# a clean readme\n' >"$d/notes/readme.md"
        i=0; while [ "$i" -lt "$k" ]; do printf 'note %s\n' "$i" >"$d/notes/n$i.txt"; i=$((i + 1)); done
        mkdir -p "$d/_site"; printf '<html>built</html>\n' >"$d/_site/index.html"
        cp "$RUNNER" "$d/scripts/zero-gap-sweep.sh" && cp "$LIB" "$d/scripts/zero-gap-lib.sh" || return 1
        cp "$FIX/demo-class.sh" "$d/scripts/zero-gap-class-$m.sh" && chmod +x "$d/scripts/zero-gap-class-$m.sh" || return 1
        if [ "$nc" != nocorpus ]; then cp -R "$FIX/corpus" "$d/_tests/fixtures/zero-gap/$m" || return 1; fi
        { printf '%s\n' "$HDR"; row "$m"; } >"$d/docs/zero-gap/sweep-classes.tsv"
        ( cd "$d" && git init -q ) >/dev/null 2>&1 && commit "$d"
    }
    det() { RC=0; TMPDIR="$T/tmp" timeout -k 10 600 bash "$SELF" --allow-tmpfs --scratch "$T/s" "$@" >"$T/out" 2>"$T/err" || RC=$?; }
    nctl=0; okc() { nctl=$((nctl + 1)); ok "$@"; }
    zgin() { find "$1" -name 'zg-determinism.*' 2>/dev/null | head -1; }   # any scratch entry ever made under <dir>
    alive() { local l; { read -r l <"/proc/$1/stat"; } 2>/dev/null || return 1; l=${l##*) }; [ "${l%% *}" != Z ]; }
    # fakerunner <repo> <body>: replace the fixture's runner with a tiny script (committed)
    fakerunner() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1/scripts/zero-gap-sweep.sh"; commit "$1"; }
    has() { grep -qE -- "$1" "$T/out"; }
    why() { printf '%s' "$(cat "$T/out" "$T/err" 2>/dev/null | tail -c 400 | tr '\n' ' ')"; }
    empty_scratch() { [ -z "$(find "$T/s" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]; }
    # In-process variant: run det_main in a subshell with hook overrides (defined by the caller
    # as functions named ovr_copy / ovr_between before calling deti).
    # DI_ARGS: leading arguments (default: --allow-tmpfs --scratch $T/s); ovr_fstype / ovr_avail stub the
    # filesystem-type and free-space probes; DET_DISK_FALLBACK is pointed into $T.
    deti() { RC=0; ( export TMPDIR="$T/tmp"; DET_DISK_FALLBACK="$T/disk"
                     if declare -F ovr_copy >/dev/null; then det_copy_files() { ovr_copy "$@"; }; fi
                     if declare -F ovr_between >/dev/null; then det_between_runs() { ovr_between "$@"; }; fi
                     if declare -F ovr_fstype >/dev/null; then det_fstype() { ovr_fstype "$@"; }; fi
                     if declare -F ovr_avail >/dev/null; then det_avail() { ovr_avail "$@"; }; fi
                     det_main ${DI_ARGS---allow-tmpfs --scratch "$T/s"} "$@" ) >"$T/out" 2>"$T/err" </dev/null || RC=$?
             unset -f ovr_copy ovr_between ovr_fstype ovr_avail; unset DI_ARGS; }

    body() {
    local R
    echo "C0 control: deterministic demo class, DEFAULT run count (T035: N=5)"
    R=$T/c0; mkfix "$R" demo || { bad "C0 fixture"; return; }
    det --root "$R"
    if [ "$RC" -eq 0 ] && has '^DETERMINISM IDENTICAL rc=0 runs=5/5 ' && [ "$(grep -c '^DETERMINISM-RUN ' "$T/out")" -eq 5 ] \
       && [ "$(sed -n 's/^DETERMINISM-RUN [0-9]* .* sha256=\([0-9a-f]*\) .*/\1/p' "$T/out" | sort -u | wc -l)" -eq 1 ] \
       && has '^DETERMINISM-RUN 1 rc=0 verdict=HOLDS '; then okc "C0a default N is 5: five identical HOLDS runs => rc 0 IDENTICAL"; else bad "C0a rc=$RC $(why)"; fi
    if empty_scratch; then okc "C0b scratch copy removed at exit"; else bad "C0b scratch left behind"; fi
    if has '^DETERMINISM-COPY files=[0-9]+ fingerprint=[0-9a-f]{64} state=[0-9a-f]{64} '; then okc "C0c copy line reports fingerprint and state"; else bad "C0c $(why)"; fi

    echo "C1 a DETERMINISTIC runner rc 2 (class with an empty population, no corpus) is part of the identity"
    R=$T/c1; mkfix "$R" zeropop 0 nocorpus || { bad "C1 fixture"; return; }
    det --root "$R" --runs 2
    if [ "$RC" -eq 0 ] && has '^DETERMINISM IDENTICAL rc=0 runs=2/2 ' && has '^DETERMINISM-RUN 2 rc=2 verdict=UNDETERMINED '; then okc "C1 deterministic rc-2 sweep => rc 0 IDENTICAL"; else bad "C1 rc=$RC $(why)"; fi

    echo "M1 a class emitting a RANDOM value per finding"
    R=$T/m1; mkfix "$R" nondet || { bad "M1 fixture"; return; }
    det --root "$R" --runs 2
    if [ "$RC" -eq 1 ] && has '^DETERMINISM DIFFERS rc=1 ' && has '^DETERMINISM-DIFF run=1 other=2 differing-lines=[1-9]' && has '^[-+]FINDING nondet '; then ok "M1 random finding text => rc 1 DIFFERS with a unified diff"; else bad "M1 rc=$RC $(why)"; fi

    echo "M2 a class emitting a TIMESTAMP"
    R=$T/m2; mkfix "$R" nondet || { bad "M2 fixture"; return; }
    sed -i.bak 's/run-\$RANDOM-\$\$/at-$(date +%s%N)/' "$R/scripts/zero-gap-class-nondet.sh" && rm -f "$R/scripts/zero-gap-class-nondet.sh.bak" && commit "$R"
    if grep -q 'date +%s%N' "$R/scripts/zero-gap-class-nondet.sh"; then
        det --root "$R" --runs 2
        if [ "$RC" -eq 1 ] && has '^DETERMINISM DIFFERS rc=1 ' && has '^[-+]FINDING nondet .* at-[0-9]+ '; then ok "M2 timestamp in a finding => rc 1 DIFFERS"; else bad "M2 rc=$RC $(why)"; fi
    else bad "M2 fixture patch did not apply"; fi

    echo "M3 the copy's CONTENT edited between runs"
    R=$T/m3; mkfix "$R" demo || { bad "M3 fixture"; return; }
    ovr_between() { if [ "$2" -eq 1 ]; then echo edited >>"$1/notes/ok.txt"; fi; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 ' && grep -q 'between run 1 and run 2' "$T/out" "$T/err"; then ok "M3 content edit between runs => rc 2 (not 1)"; else bad "M3 rc=$RC $(why)"; fi

    echo "M4 the copy only TOUCHED (mtime) between runs — content unchanged"
    R=$T/m4; mkfix "$R" demo || { bad "M4 fixture"; return; }
    ovr_between() { if [ "$2" -eq 1 ]; then touch -d '2001-01-01 00:00:00' "$1/notes/ok.txt"; fi; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && grep -q 'between run 1 and run 2 .*changed: notes/ok.txt)' "$T/out"; then ok "M4 mtime-only move between runs => rc 2 (stat listing, not only content), naming notes/ok.txt"; else bad "M4 rc=$RC $(why)"; fi

    echo "C2 a TRANSIENT entry (lock file created and removed) between runs is not a move"
    R=$T/c2; mkfix "$R" demo || { bad "C2 fixture"; return; }
    ovr_between() { if [ "$2" -eq 1 ]; then : >"$1/.git/index.lock" && rm -f "$1/.git/index.lock"; fi; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 0 ] && has '^DETERMINISM IDENTICAL rc=0 runs=2/2 '; then okc "C2 transient index.lock between runs => still rc 0 IDENTICAL"; else bad "C2 rc=$RC $(why)"; fi

    echo "M4b a PERSISTENT new file inside .git between runs (invisible to the content fingerprint)"
    R=$T/m4b; mkfix "$R" demo || { bad "M4b fixture"; return; }
    ovr_between() { if [ "$2" -eq 1 ]; then printf 'new\n' >"$1/.git/zg-probe"; fi; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && grep -q 'between run 1 and run 2 .*changed: .git/zg-probe)' "$T/out"; then ok "M4b file created in .git between runs => rc 2, naming it"; else bad "M4b rc=$RC $(why)"; fi

    echo "M5 a class that writes into the tree DURING a run"
    R=$T/m5; mkfix "$R" mover || { bad "M5 fixture"; return; }
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 ' && ! has '^DETERMINISM DIFFERS'; then ok "M5 tree moved during a run => rc 2 (not 1)"; else bad "M5 rc=$RC $(why)"; fi

    echo "M6 runner infrastructure failures"
    R=$T/m6a; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\necho "FINDING demo low other notes/ok.txt partial notes/ok.txt"\nkill -SEGV $$\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 ' && has 'rc=139'; then ok "M6a runner killed by SIGSEGV => rc 2"; else bad "M6a rc=$RC $(why)"; fi
    R=$T/m6b; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\nexit 0\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*VERDICT'; then ok "M6b runner rc 0 with EMPTY output (no VERDICT) => rc 2, never identical"; else bad "M6b rc=$RC $(why)"; fi
    R=$T/m6c; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\necho "VERDICT HOLDS rc=0 findings=0 could-not-inspect=0 classes=1 unknown-recall=0"\nexit 1\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 '; then ok "M6c VERDICT rc disagrees with exit code => rc 2"; else bad "M6c rc=$RC $(why)"; fi
    R=$T/m6d; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\nsleep 30\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    t0=$(date +%s); det --root "$R" --runs 2 --run-timeout 2; t1=$(date +%s)
    if [ "$RC" -eq 2 ] && [ $((t1 - t0)) -lt 25 ] && has 'timed out|rc=124|rc=137'; then ok "M6d hanging runner bounded by --run-timeout => rc 2"; else bad "M6d rc=$RC after $((t1 - t0)) s $(why)"; fi
    R=$T/m6e; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\necho "VERDICT UNSTABLE rc=2 findings=0 could-not-inspect=1 classes=1 unknown-recall=0"\nexit 2\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*UNSTABLE'; then ok "M6e runner VERDICT UNSTABLE (identical each time) => rc 2, never identical"; else bad "M6e rc=$RC $(why)"; fi

    R=$T/m6f; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\necho "VERDICT HOLDS rc=0 findings=0 could-not-inspect=0 classes=1 unknown-recall=0"\necho "VERDICT second line outside the grammar"\nexit 0\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*2 VERDICT line'; then ok "M6f two VERDICT lines (one outside the grammar) => rc 2, never identical"; else bad "M6f rc=$RC $(why)"; fi

    R=$T/m6g; mkfix "$R" demo || { bad "M6 fixture"; return; }
    printf '#!/usr/bin/env bash\necho "VERDICT HOLDS rc=139 findings=0 could-not-inspect=0 classes=1 unknown-recall=0"\nexit 139\n' >"$R/scripts/zero-gap-sweep.sh"; commit "$R"
    det --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*rc=139 .*outside'; then ok "M6g runner exit 139 with a self-consistent VERDICT rc=139 => rc 2 (exit outside {0,1,2})"; else bad "M6g rc=$RC $(why)"; fi

    echo "M7 a copier that HARDLINKS instead of copying"
    R=$T/m7; mkfix "$R" demo || { bad "M7 fixture"; return; }
    ovr_copy() { rm -rf "$2" && cp -al "$1" "$2"; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && grep -qi 'hardlink\|link count' "$T/out" "$T/err"; then ok "M7 hardlinked copy => rc 2"; else bad "M7 rc=$RC $(why)"; fi

    echo "M8 the SOURCE moves while it is being copied"
    R=$T/m8; mkfix "$R" demo || { bad "M8 fixture"; return; }
    ovr_copy() { det_rsync_copy "$@"; local rc=$?; echo moved >>"$1/notes/ok.txt"; return "$rc"; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && grep -qi 'moved during the copy' "$T/out" "$T/err"; then ok "M8 source moved during copy => rc 2"; else bad "M8 rc=$RC $(why)"; fi

    echo "M9 an UNFAITHFUL copy (a tracked file dropped)"
    R=$T/m9; mkfix "$R" demo || { bad "M9 fixture"; return; }
    ovr_copy() { det_rsync_copy "$@"; local rc=$?; rm -f "$2/notes/readme.md"; return "$rc"; }
    deti --root "$R" --runs 2
    if [ "$RC" -eq 2 ] && grep -qi 'not faithful' "$T/out" "$T/err"; then ok "M9 copy differs from source => rc 2"; else bad "M9 rc=$RC $(why)"; fi

    echo "M10 bad usage and absent roots"
    det --root /nonexistent;                   if [ "$RC" -eq 2 ]; then ok "M10a --root /nonexistent => rc 2"; else bad "M10a rc=$RC"; fi
    mkdir -p "$T/plain"; echo x >"$T/plain/f"
    det --root "$T/plain";                     if [ "$RC" -eq 2 ]; then ok "M10b non-git --root => rc 2"; else bad "M10b rc=$RC"; fi
    det --root "$T/c0" --runs 1;               if [ "$RC" -eq 2 ]; then ok "M10c --runs 1 => rc 2 (nothing to compare)"; else bad "M10c rc=$RC"; fi
    det --root "$T/c0" --runs abc;             if [ "$RC" -eq 2 ]; then ok "M10d --runs abc => rc 2"; else bad "M10d rc=$RC"; fi
    det --root "$T/c0" --bogus;                if [ "$RC" -eq 2 ]; then ok "M10e unknown option => rc 2"; else bad "M10e rc=$RC"; fi
    RC=0; TMPDIR="$T/tmp" timeout -k 10 120 bash "$SELF" --root "$T/c0" --scratch "$T/c0/notes" >"$T/out" 2>"$T/err" || RC=$?
    if [ "$RC" -eq 2 ] && grep -q '^DETERMINISM UNDETERMINED rc=2 .*lies inside --root' "$T/out" && [ -z "$(zgin "$T/c0")" ] \
       && [ -z "$(git -C "$T/c0" status --porcelain)" ]; then ok "M10f --scratch inside --root => rc 2 'lies inside --root', no zg-determinism.* ever created under the root"; else bad "M10f rc=$RC $(why)"; fi

    echo "C3 --check <class_id> restricts the sweep to that ONE class (two listed)"
    R=$T/c3; mkfix "$R" demo || { bad "C3 fixture"; return; }
    cp "$FIX/demo-class.sh" "$R/scripts/zero-gap-class-zeropop.sh" && row zeropop >>"$R/docs/zero-gap/sweep-classes.tsv" && commit "$R"
    rm -rf "$T/rep"; det --root "$R" --runs 2 --check demo --reports "$T/rep"
    if [ "$RC" -eq 0 ] && has '^DETERMINISM IDENTICAL rc=0 runs=2/2 ' && has '^DETERMINISM-RUN 1 rc=0 verdict=HOLDS ' \
       && [ -f "$T/rep/report.1" ] && [ "$(grep -c '^CLASS ' "$T/rep/report.1")" -eq 1 ] && grep -q '^CLASS demo ' "$T/rep/report.1"; then okc "C3a --check demo => one CLASS line (demo), HOLDS, rc 0"; else bad "C3a rc=$RC $(why)"; fi
    rm -rf "$T/rep"; det --root "$R" --runs 2 --reports "$T/rep"
    if [ "$RC" -eq 0 ] && [ -f "$T/rep/report.1" ] && [ "$(grep -c '^CLASS ' "$T/rep/report.1")" -eq 2 ]; then okc "C3b without --check the full sweep runs (both CLASS lines)"; else bad "C3b rc=$RC $(why)"; fi

    echo "M12 --check with an id that sweep-classes.tsv does not list"
    det --root "$T/c3" --runs 2 --check nosuch
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*nosuch.*not listed in docs/zero-gap/sweep-classes.tsv'; then ok "M12a unknown --check id => rc 2, named"; else bad "M12a rc=$RC $(why)"; fi
    det --root "$T/c3" --runs 2 --check 'demo;x'
    if [ "$RC" -eq 2 ] && has 'not listed in docs/zero-gap/sweep-classes.tsv'; then ok "M12b malformed --check id => rc 2"; else bad "M12b rc=$RC $(why)"; fi
    det --root "$T/c3" --runs 2 --check class_id
    if [ "$RC" -eq 2 ] && has 'not listed in docs/zero-gap/sweep-classes.tsv'; then ok "M12c the TSV header word is not a class id => rc 2"; else bad "M12c rc=$RC $(why)"; fi

    echo "S1 scratch on a RAM-backed filesystem"
    ovr_fstype() { echo tmpfs; }
    DI_ARGS="--scratch $T/s" deti --root "$T/c0" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*tmpfs.*--scratch /var/tmp' && [ -z "$(zgin "$T/s")" ]; then ok "S1a explicit tmpfs --scratch => rc 2 naming the fix, nothing created"; else bad "S1a rc=$RC $(why)"; fi
    ovr_fstype() { echo ramfs; }
    DI_ARGS="--scratch $T/s --allow-tmpfs" deti --root "$T/c0" --runs 2
    if [ "$RC" -eq 0 ] && has '^DETERMINISM IDENTICAL rc=0 '; then okc "S1b --allow-tmpfs overrides the refusal (tiny fixture)"; else bad "S1b rc=$RC $(why)"; fi
    mkdir -p "$T/disk"
    ovr_fstype() { case "$1" in "$T/disk"*) echo ext4 ;; *) echo tmpfs ;; esac; }
    DI_ARGS="" deti --root "$T/c0" --runs 2
    if [ "$RC" -eq 0 ] && grep -q "falls back to $T/disk" "$T/err" && [ -z "$(zgin "$T/tmp")" ] && [ -z "$(zgin "$T/disk")" ]; then ok "S1c DEFAULT scratch on tmpfs => falls back to the disk directory (and cleans it)"; else bad "S1c rc=$RC $(why)"; fi
    ovr_fstype() { echo tmpfs; }
    DI_ARGS="" deti --root "$T/c0" --runs 2
    if [ "$RC" -eq 2 ] && has 'tmpfs.*--scratch /var/tmp' && [ -z "$(zgin "$T/tmp")" ] && [ -z "$(zgin "$T/disk")" ]; then ok "S1d default AND fallback on tmpfs => rc 2 with the fix wording"; else bad "S1d rc=$RC $(why)"; fi
    if [ "$(findmnt -no FSTYPE -T "$T/s" 2>/dev/null)" = tmpfs ]; then
        RC=0; TMPDIR="$T/tmp" timeout -k 10 120 bash "$SELF" --scratch "$T/s" --root "$T/c0" --runs 2 >"$T/out" 2>"$T/err" || RC=$?
        if [ "$RC" -eq 2 ] && has 'tmpfs' && [ -z "$(zgin "$T/s")" ]; then ok "S1e REAL findmnt probe: $T/s is tmpfs on this host => rc 2"; else bad "S1e rc=$RC $(why)"; fi
    else echo "  NOTE S1e skipped: $T/s is not a tmpfs on this host (the stubbed cases S1a-S1d still ran)"; fi

    echo "S2 not enough free space for the estimated copy"
    ovr_avail() { echo 10; }
    deti --root "$T/c0" --runs 2
    if [ "$RC" -eq 2 ] && has '^DETERMINISM UNDETERMINED rc=2 .*needs .* bytes .*available' && [ -z "$(zgin "$T/s")" ]; then ok "S2 estimate x1.2 above free space => rc 2 before any copy"; else bad "S2 rc=$RC $(why)"; fi

    echo "G signals mid-run: the runner (timeout, runner, its child) is ended and the scratch removed"
    for sig in TERM INT; do
        R=$T/g$sig; mkfix "$R" demo || { bad "G$sig fixture"; return; }
        rm -f "$T/pids.$sig" "$T/hpid" "$T/hrc"
        fakerunner "$R" "printf '%s\n%s\n' \"\$PPID\" \"\$\$\" >$T/pids.$sig.t; sleep 60 & echo \$! >>$T/pids.$sig.t; mv $T/pids.$sig.t $T/pids.$sig; wait"
        # a background job of a non-interactive shell starts with SIGINT IGNORED (and an ignored-at-entry
        # signal cannot be trapped), so the harness is started with the default disposition restored,
        # as a foreground job in an interactive terminal would have it
        ( TMPDIR="$T/tmp" env --default-signal=INT,TERM,HUP bash "$SELF" --allow-tmpfs --scratch "$T/s" --root "$R" --runs 2 >"$T/out" 2>"$T/err" & echo $! >"$T/hpid"; wait $!; echo $? >"$T/hrc" ) &
        w=$!
        n=0; while [ ! -s "$T/pids.$sig" ] && [ "$n" -lt 300 ]; do sleep 0.1; n=$((n + 1)); done
        if [ -s "$T/pids.$sig" ]; then kill "-$sig" "$(cat "$T/hpid")"; fi
        wait "$w"
        n=0; while [ "$n" -lt 50 ]; do left=""; for p in $(cat "$T/pids.$sig" 2>/dev/null); do alive "$p" && left="$left $p"; done; [ -z "$left" ] && break; sleep 0.1; n=$((n + 1)); done
        want=143; [ "$sig" = INT ] && want=130
        if [ -s "$T/pids.$sig" ] && [ "$(cat "$T/hrc" 2>/dev/null)" = "$want" ] && [ -z "$left" ] && [ -z "$(zgin "$T/s")" ]; then ok "G$sig SIG$sig mid-run => exit $want, timeout/runner/child pids gone, scratch removed"
        else bad "G$sig rc=$(cat "$T/hrc" 2>/dev/null) left=[$left] scratch=[$(zgin "$T/s")] $(why)"; for p in $left; do kill -KILL "$p" 2>/dev/null; done; rm -rf "$T"/s/zg-determinism.*; fi
    done

    echo "N an UNTRACKED nested repository: only ITS tracked + untracked-not-ignored files (+ its .git) are copied"
    R=$T/n1; mkfix "$R" demo || { bad "N fixture"; return; }
    mkdir -p "$R/vendor/nr" && ( cd "$R/vendor/nr" && git init -q && printf '.env\n' >.gitignore && echo kept >a.txt && git add -A && git -c user.name=t -c user.email=t@t commit -qm n && printf 'SECRET=1\n' >.env && echo loose >b.txt ) >/dev/null 2>&1
    rm -rf "$T"/s/zg-determinism.*; det --root "$R" --runs 2 --keep
    c=$(zgin "$T/s")/copy
    if [ "$RC" -eq 0 ] && [ -f "$c/vendor/nr/a.txt" ] && [ -f "$c/vendor/nr/b.txt" ] && [ -d "$c/vendor/nr/.git" ] && [ ! -e "$c/vendor/nr/.env" ]; then ok "N1 nested repo copied without its ignored .env (a.txt, b.txt, .git present)"; else bad "N1 rc=$RC env=$([ -e "$c/vendor/nr/.env" ] && echo COPIED) $(why)"; fi
    rm -rf "$T"/s/zg-determinism.*

    echo "I --include hardening"
    mkdir -p "$T/outside" && echo outside-secret >"$T/outside/secret.txt" && ln -s "$T/outside" "$T/c0/_site/ext"
    for inc in _site/ext _site/ext/ _site/ext/secret.txt; do
        rm -rf "$T"/s/zg-determinism.*; det --root "$T/c0" --runs 2 --include "$inc" --keep
        if [ "$RC" -eq 2 ] && has 'symlink|outside --root' && [ -z "$(grep -rl outside-secret "$T/s" 2>/dev/null)" ] && [ -z "$(zgin "$T/s")" ]; then ok "I1 --include '$inc' through a symlink to an outside dir => rc 2, nothing outside copied"; else bad "I1 '$inc' rc=$RC $(why)"; fi
    done
    ln -s ../notes "$T/c0/_site/inlink"
    rm -rf "$T"/s/zg-determinism.*; det --root "$T/c0" --runs 2 --include _site/inlink --keep
    if [ "$RC" -eq 2 ] && has 'is a symlink' && [ -z "$(zgin "$T/s")" ]; then ok "I3 --include through a symlink resolving INSIDE --root => still rc 2 (every symlink component refused)"; else bad "I3 rc=$RC $(why)"; fi
    rm -f "$T/c0/_site/ext" "$T/c0/_site/inlink"; rm -rf "$T"/s/zg-determinism.*
    det --root "$T/c0" --runs 2 --include _site/ --keep
    c=$(zgin "$T/s")/copy
    if [ "$RC" -eq 0 ] && [ -f "$c/_site/index.html" ] && [ ! -e "$c/_site/_site" ]; then okc "I2 --include with a trailing slash copies the ignored dir once"; else bad "I2 rc=$RC $(why)"; fi
    rm -rf "$T"/s/zg-determinism.*

    echo "D a difference that appears only at run 3 (default N=5; state outside the copy)"
    R=$T/d5; mkfix "$R" demo || { bad "D fixture"; return; }
    fakerunner "$R" "n=\$(cat $T/cnt 2>/dev/null || echo 0); n=\$((n + 1)); echo \$n >$T/cnt; echo 'CLASS demo population=1 inspected=1 recall=UNKNOWN findings=0 status=unproven'; if [ \$n -ge 3 ]; then echo 'CLASS late population=1 inspected=1 recall=UNKNOWN findings=0 status=unproven'; fi; echo 'VERDICT HOLDS rc=0 findings=0 could-not-inspect=0 classes=1 unknown-recall=0'"
    rm -f "$T/cnt"; det --root "$R"
    if [ "$RC" -eq 1 ] && has '^DETERMINISM-DIFF run=1 other=3 ' && has '^DETERMINISM DIFFERS rc=1 runs=5/5 '; then ok "D5 run-3-only difference at default N=5 => rc 1, other=3"; else bad "D5 rc=$RC $(why)"; fi

    echo "M11 a large difference prints a BOUNDED diff, never the full reports"
    R=$T/m11; mkfix "$R" nondet 120 || { bad "M11 fixture"; return; }
    det --root "$R" --runs 2 --diff-lines 25
    n=$(sed -n 's/^DETERMINISM-DIFF .* differing-lines=\([0-9]*\) shown=\([0-9]*\)$/\1 \2/p' "$T/out")
    if [ "$RC" -eq 1 ] && [ -n "$n" ] && [ "${n%% *}" -gt 25 ] && [ "${n##* }" -le 25 ] \
       && [ "$(sed -n '/^DETERMINISM-DIFF /,/^DETERMINISM /p' "$T/out" | wc -l)" -le 27 ]; then ok "M11 diff bounded to 25 of ${n%% *} differing lines"; else bad "M11 rc=$RC n='$n' $(why)"; fi
    }

    t0=$(date +%s)
    body
    t1=$(date +%s)
    live1=$(zg_fingerprint "$REPO_ROOT" 2>/dev/null | cut -d' ' -f1) || live1=""
    st1=$(git --no-optional-locks -C "$REPO_ROOT" status --porcelain 2>&1) || strc=$?
    echo "prove-failure: $pass passed / $fail failed in $((t1 - t0)) s"
    if [ "$live1" != "$live0" ] || [ "$st1" != "$st0" ]; then
        echo "prove-failure: COULD NOT DETERMINE — the live tree changed while the proof ran (a concurrent editor cannot be told apart from this proof)" >&2
        exit 2
    fi
    echo "prove-failure: live tree byte-identical before/after (fingerprint ${live0:0:16}…)"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    echo "prove-failure: all $pass cases held ($nctl controls, $((pass - nctl)) mutations caught)"
    exit 0
)

case "${1:-}" in
    --prove-failure)
        prove_failure; exit $? ;;
    --help|-h)
        usage; exit 0 ;;
esac
det_main "$@"
