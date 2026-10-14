#!/usr/bin/env bash
# scripts/agent-scratch.sh — an ON-DISK scratch root for agents (host-hang fix WP1, 2026-10-14).
#
# WHY. /tmp, /dev/shm and /run/user/* are RAM-backed tmpfs on this host. Pages written there are shmem,
# charged to the writer's cgroup and unreclaimable without swap. On 2026-10-14 (host anton) ~20 parallel
# agents wrote multi-GB copies (git clones of a 1.6 GB repo, a 1.4 GB `cp -a` gitdir backup, rsync copies,
# gate temp files) into the harness scratchpad /tmp/claude-1000/...; tmpfs shmem grew 0.33 -> 8.1 GB,
# app.slice hit MemoryHigh and the box stalled in direct reclaim (load 430, PSI memory full 53-92%).
# A second effect pushed agents into those full copies: `cp -al` hardlink backups (constitution §9) FAIL
# from the repo filesystem to /tmp (cross-device), so agents fell back to `cp -a`.
#
# This helper gives every agent a scratch directory on DISK, on the same filesystem as ~/Projects, so a
# hardlink backup (`cp -al <repo-path> "$S/backup"`) costs no data blocks and no RAM.
#
# ROOT   ${AGENT_SCRATCH_ROOT:-$HOME/.cache/agent-scratch}   (created 0700; refused when RAM-backed)
#
# USAGE
#   agent-scratch.sh new <label>                print a fresh 0700 dir  <root>/<label>.<stamp>.XXXXXX
#   agent-scratch.sh du                          KiB per scratch dir this helper created, then a total
#   agent-scratch.sh gc --older-than DUR [--dry-run]
#                                                remove dirs THIS HELPER CREATED (marker file
#                                                .agent-scratch, first line created_by=agent-scratch.sh)
#                                                with no entry modified within DUR (Ns|Nm|Nh|Nd; bare N =
#                                                seconds). Never follows a symlink, never touches an
#                                                unmarked dir (slots/, backups/, anything else).
#   agent-scratch.sh df-check [--repo DIR]      filesystem of the scratch root vs the repo (default: the
#                                                git toplevel of $PWD, else this umbrella) and whether a
#                                                hardlink from the repo's git dir into the root works
#   agent-scratch.sh verify-persistence [--repo DIR]
#                                                does this fix SURVIVE A REBOOT? Lists every persistent
#                                                artifact (tracked + committed in git, or a host file on
#                                                disk) and where TMPDIR resolves in a FRESH login
#                                                environment (env -i HOME=$HOME bash -lc). FAILS (rc 1)
#                                                while TMPDIR is unset or RAM-backed there: that is the
#                                                operator-applied launcher step in docs/AGENT_GUARDRAILS.md
#                                                section (D), not a defect of this tree.
#   agent-scratch.sh --prove-failure            §1.1 paired proof (controls + mutations)
#
# EXIT  0 ok | 1 a determined negative (root is RAM-backed; different filesystem / hardlink refused;
#       a gc removal failed) | 2 cannot determine (bad usage, root not creatable/readable, stat failed).
#       2 is never a pass.
# Dependencies: bash, coreutils (stat, mktemp, du, ln, realpath), find, git (df-check only).
set -u
SELF="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
UMBRELLA="$(CDPATH='' cd -- "$(dirname -- "$SELF")/.." && pwd)"
R="${AGENT_SCRATCH_ROOT:-$HOME/.cache/agent-scratch}"
MARK=.agent-scratch
MARK_LINE='created_by=agent-scratch.sh'

say() { printf 'agent-scratch: %s\n' "$*" >&2; }

# RAM-backed filesystem types: a scratch root there reproduces the incident.
is_ram_fs() { case "$1" in tmpfs|ramfs) return 0 ;; *) return 1 ;; esac; }

# Filesystem type of $1. Test seam AGENT_SCRATCH_TEST_RAMFS_PREFIX: a path under it is REPORTED as tmpfs, so
# the proof needs no real tmpfs directory. The seam can only make this helper stricter (refuse more); it can
# never make a real RAM filesystem look like disk.
fs_type() {
    if [ -n "${AGENT_SCRATCH_TEST_RAMFS_PREFIX:-}" ]; then
        case "$1/" in "${AGENT_SCRATCH_TEST_RAMFS_PREFIX%/}/"*) echo tmpfs; return 0 ;; esac
    fi
    stat -f -c %T -- "$1" 2>/dev/null
}

ensure_root() {
    if [ -L "$R" ]; then   # chmod/mkdir would follow it and change (and fill) whatever it points at
        say "REFUSED: scratch root $R is a symlink; point AGENT_SCRATCH_ROOT at the real directory"
        return 1
    fi
    if ! mkdir -p -- "$R" 2>/dev/null || [ ! -d "$R" ]; then say "cannot create scratch root $R"; return 2; fi
    chmod 700 -- "$R" 2>/dev/null || { say "cannot chmod 0700 $R"; return 2; }
    local t; t=$(fs_type "$R") || { say "cannot stat filesystem of $R"; return 2; }
    if is_ram_fs "$t"; then
        say "REFUSED: scratch root $R is on $t (RAM). Point AGENT_SCRATCH_ROOT at a disk path, e.g. \$HOME/.cache/agent-scratch"
        return 1
    fi
    return 0
}

# A dir is ours only if it is a real directory directly under the root (not a symlink) and holds the
# marker as a regular file whose first line is the marker line.
marker_ok() {
    local d="$1" first
    [ -d "$d" ] && [ ! -L "$d" ] || return 1
    [ -f "$d/$MARK" ] && [ ! -L "$d/$MARK" ] || return 1
    IFS= read -r first <"$d/$MARK" 2>/dev/null || return 1
    [ "$first" = "$MARK_LINE" ]
}

cmd_new() {
    local label="${1:-}" d rc
    [ "$#" -eq 1 ] || { say "usage: new <label>"; return 2; }
    [[ "$label" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$ ]] \
        || { say "bad label (the whole value must match ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\$)"; return 2; }
    ensure_root; rc=$?; [ "$rc" -eq 0 ] || return "$rc"
    d=$(mktemp -d -- "$R/$label.$(date +%Y%m%dT%H%M%S).XXXXXX") || { say "mktemp failed under $R"; return 2; }
    chmod 700 -- "$d" || { say "cannot chmod 0700 $d"; return 2; }
    printf '%s\nlabel=%s\ncreated=%s\npid=%s\n' "$MARK_LINE" "$label" "$(date -Is)" "$$" >"$d/$MARK" \
        || { say "cannot write marker in $d"; return 2; }
    printf '%s\n' "$d"
}

cmd_du() {
    [ "$#" -eq 0 ] || { say "usage: du"; return 2; }
    if [ ! -e "$R" ]; then printf 'total\t0\t(no scratch root yet: %s)\n' "$R"; return 0; fi
    [ -d "$R" ] && [ -r "$R" ] && [ -x "$R" ] || { say "scratch root unreadable: $R"; return 2; }
    local d k total=0
    for d in "$R"/*/; do
        d=${d%/}
        marker_ok "$d" || continue
        k=$(du -sk -- "$d" 2>/dev/null | cut -f1) || k=''
        [ -n "$k" ] || { say "du failed on $d"; return 2; }
        printf '%s\t%s\n' "$k" "$d"
        total=$((total + k))
    done
    printf 'total\t%s\tKiB under %s (helper-created dirs only)\n' "$total" "$R"
}

dur_seconds() {
    local v="$1" n u
    printf '%s' "$v" | grep -Eq '^[0-9]+[smhd]?$' || return 1
    n=${v%[smhd]}; u=${v#"$n"}
    case "$u" in ''|s) echo "$n" ;; m) echo $((n * 60)) ;; h) echo $((n * 3600)) ;; d) echo $((n * 86400)) ;; esac
}

cmd_gc() {
    local older='' dry=0 secs cutoff d rroot dparent removed=0 kept=0 failed=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --older-than) [ "$#" -ge 2 ] || { say "--older-than needs a value"; return 2; }; older=$2; shift 2 ;;
            --dry-run) dry=1; shift ;;
            *) say "gc: unknown argument '$1'"; return 2 ;;
        esac
    done
    [ -n "$older" ] || { say "gc needs --older-than DUR (Ns|Nm|Nh|Nd)"; return 2; }
    secs=$(dur_seconds "$older") || { say "bad duration '$older' (Ns|Nm|Nh|Nd)"; return 2; }
    if [ ! -e "$R" ]; then echo "gc: no scratch root ($R): nothing to do"; return 0; fi
    [ -d "$R" ] && [ -r "$R" ] && [ -x "$R" ] || { say "scratch root unreadable: $R"; return 2; }
    rroot=$(realpath -e -- "$R") || { say "cannot resolve $R"; return 2; }
    cutoff=$(( $(date +%s) - secs ))
    for d in "$R"/* "$R"/.[!.]*; do
        [ -e "$d" ] || [ -L "$d" ] || continue
        marker_ok "$d" || continue
        dparent=$(dirname -- "$(realpath -e -- "$d")") || continue
        [ "$dparent" = "$rroot" ] || continue
        # any entry modified after the cutoff => the dir is in use; keep it
        if [ -n "$(find "$d" -newermt "@$cutoff" -print -quit 2>/dev/null)" ]; then
            kept=$((kept + 1)); continue
        fi
        if [ "$dry" -eq 1 ]; then echo "would remove $d"; removed=$((removed + 1)); continue; fi
        if rm -rf --one-file-system -- "$d" 2>/dev/null && [ ! -e "$d" ]; then
            echo "removed $d"; removed=$((removed + 1))
        else
            say "could not remove $d"; failed=$((failed + 1))
        fi
    done
    echo "gc: $removed $( [ "$dry" -eq 1 ] && echo 'would be removed' || echo removed ), $kept kept (active), $failed failed"
    [ "$failed" -eq 0 ] || return 1
    return 0
}

cmd_df_check() {
    local repo='' rc rt rd rmnt pt pd pmnt src same hlfs=no hl=fails
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --repo) [ "$#" -ge 2 ] || { say "--repo needs a value"; return 2; }; repo=$2; shift 2 ;;
            *) say "df-check: unknown argument '$1'"; return 2 ;;
        esac
    done
    [ -n "$repo" ] || repo=$(git rev-parse --show-toplevel 2>/dev/null) || repo=''
    [ -n "$repo" ] || repo=$UMBRELLA
    [ -d "$repo" ] || { say "repo is not a directory: $repo"; return 2; }
    ensure_root; rc=$?
    [ "$rc" -ne 2 ] || return 2
    [ -d "$R" ] && [ ! -L "$R" ] || { say "no usable scratch root at $R"; return 1; }
    rt=$(fs_type "$R") && rd=$(stat -c %d -- "$R" 2>/dev/null) && rmnt=$(stat -c %m -- "$R" 2>/dev/null) || { say "cannot stat $R"; return 2; }
    pt=$(fs_type "$repo") && pd=$(stat -c %d -- "$repo" 2>/dev/null) && pmnt=$(stat -c %m -- "$repo" 2>/dev/null) || { say "cannot stat $repo"; return 2; }
    # link(2) works only within one filesystem AND one mount (a bind mount of the same device is EXDEV)
    [ "$rd" = "$pd" ] && [ "$rmnt" = "$pmnt" ] && same=yes || same=no
    # prove the filesystem supports hardlinks with a probe INSIDE the scratch root; nothing is written in the repo
    src=$(mktemp -- "$R/.hardlink-probe.XXXXXX" 2>/dev/null) || { say "cannot create a probe file in $R"; return 2; }
    ln -- "$src" "$src.l" 2>/dev/null && hlfs=yes
    rm -f -- "$src" "$src.l"
    [ "$same" = yes ] && [ "$hlfs" = yes ] && hl=works
    printf 'scratch_root=%s\nscratch_fs=%s\nscratch_dev=%s\nscratch_mount=%s\nrepo=%s\nrepo_fs=%s\nrepo_dev=%s\nrepo_mount=%s\nsame_filesystem=%s\nhardlinks_supported=%s\nhardlink_repo_to_scratch=%s\nscratch_ram_backed=%s\n' \
        "$R" "$rt" "$rd" "$rmnt" "$repo" "$pt" "$pd" "$pmnt" "$same" "$hlfs" "$hl" "$(is_ram_fs "$rt" && echo yes || echo no)"
    if [ "$rc" -eq 1 ] || [ "$hl" != works ]; then
        say "NOT OK: hardlink backups (cp -al) from $repo into $R will not work; full copies would follow"
        return 1
    fi
    return 0
}

# Tracked files that carry this fix; a reboot keeps only what is committed (or on disk outside tmpfs).
PERSIST_TRACKED="scripts/agent-scratch.sh scripts/agent-admit.sh scripts/hooks/guard-project-catalogue.sh
scripts/hooks/fixtures/tmpfs-guard/golden-bad.tsv scripts/hooks/fixtures/tmpfs-guard/golden-good.tsv
docs/AGENT_GUARDRAILS.md scripts/check-registry.tsv scripts/pre-push-gates.sh scripts/zero-gap-verify.sh
scripts/verify-content-boundary.sh"

cmd_verify_persistence() {
    local repo=$UMBRELLA phome="${AGENT_PERSIST_HOME:-$HOME}" f st bad=0 undet=0 tmpd rtmp tfs br sysd wired
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --repo) [ "$#" -ge 2 ] || { say "--repo needs a value"; return 2; }; repo=$2; shift 2 ;;
            *) say "verify-persistence: unknown argument '$1'"; return 2 ;;
        esac
    done
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { say "not a git work tree: $repo"; return 2; }
    printf '%-62s %s\n' "ARTIFACT" "PERSISTENCE"
    for f in $PERSIST_TRACKED; do
        if ! git -C "$repo" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then st="UNTRACKED (lost unless committed)"; bad=1
        elif ! git -C "$repo" diff --quiet HEAD -- "$f" 2>/dev/null; then st="tracked, UNCOMMITTED changes (lost on a checkout/reset)"; bad=1
        else st="tracked+committed"; fi
        printf '%-62s %s\n' "$f" "$st"
    done
    if grep -q '(D) HOST RESOURCE SAFETY' "$repo/docs/AGENT_GUARDRAILS.md" 2>/dev/null; then st="present"; else st="MISSING"; bad=1; fi
    printf '%-62s %s\n' "docs/AGENT_GUARDRAILS.md section (D)" "$st"
    # host artifacts (persist on disk, outside git)
    br=$(command -v bounded-run 2>/dev/null) && st="present ($br)" || { st="ABSENT (admission refuses heavy work: rc 2)"; bad=1; }
    printf '%-62s %s\n' "host: bounded-run on PATH" "$st"
    tfs=$(fs_type "$R" || fs_type "$(dirname -- "$R")") || tfs=unknown
    if is_ram_fs "$tfs"; then st="RAM-BACKED ($tfs): lost on reboot"; bad=1; else st="disk ($tfs); recreated 0700 by 'new' when absent"; fi
    printf '%-62s %s\n' "host: scratch root $R" "$st"
    printf '%-62s %s\n' "host: slot files $R/slots" "ephemeral by design (flock state is per boot; stale files are reused)"
    wired=no; grep -q 'guard-project-catalogue' "$repo/.claude/settings.json" 2>/dev/null && wired=yes
    printf '%-62s %s\n' "hook wiring in .claude/settings.json (tmpfs rule live?)" "$wired (operator decision; reported, not gated)"
    sysd=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^TMPDIR=//p')
    printf '%-62s %s\n' "systemd --user environment TMPDIR (GUI terminals)" "${sysd:-unset} (reported)"
    # TMPDIR in FRESH shells, each started from a clean environment (env -i): what a newly opened login, terminal
    # tab or tmux pane — and the claude it launches — will see after a reboot. The verdict must not depend on
    # the caller's cwd, so every probe starts from an explicit directory. Rows:
    #   login from HOME (bash -lc)   interactive login from HOME (bash -lic)   interactive from HOME (bash -ic)
    #   login from a non-HOME directory (bash -lc): tmux panes / `bash -l` started elsewhere; a relative
    #   `. .bashrc` in ~/.bash_profile resolves against THAT directory.
    local other="${AGENT_PERSIST_OTHER_DIR:-/}" row dir flags label
    for row in "$phome|-lc|fresh login from HOME (bash -lc)" "$phome|-lic|fresh interactive login from HOME (bash -lic)" \
               "$phome|-ic|fresh interactive shell from HOME (bash -ic)" "$other|-lc|fresh login from $other (bash -lc, not HOME)"; do
        dir=${row%%|*}; flags=${row#*|}; label=${flags#*|}; flags=${flags%%|*}
        tmpd=$( ( cd "$dir" 2>/dev/null || exit 3
                  env -i HOME="$phome" USER="${USER:-}" LOGNAME="${LOGNAME:-}" TERM=dumb PATH=/usr/local/bin:/usr/bin:/bin \
                      timeout 30 bash $flags 'printf "\nAGENT_PERSIST_TMPDIR=%s\n" "${TMPDIR:-}"' </dev/null 2>/dev/null ) \
                | sed -n 's/^AGENT_PERSIST_TMPDIR=//p' | tail -n 1)
        if ! ( cd "$dir" 2>/dev/null && env -i HOME="$phome" PATH=/usr/bin:/bin timeout 30 bash -c 'exit 0' </dev/null >/dev/null 2>&1 ); then
            say "CANNOT DETERMINE: a fresh shell could not be started in $dir"; undet=1
        fi
        if [ -z "$tmpd" ]; then
            st="UNSET -> the harness falls back to /tmp (RAM). OPERATOR STEP: docs/AGENT_GUARDRAILS.md section (D)"; bad=1
        else
            rtmp=$(stat -f -c %T -- "$tmpd" 2>/dev/null || true)
            if case "$tmpd" in /tmp|/tmp/*|/dev/shm|/dev/shm/*|/run/user/*) true ;; *) false ;; esac || is_ram_fs "${rtmp:-}"; then
                st="$tmpd is RAM-backed (${rtmp:-tmpfs path}). OPERATOR STEP: docs/AGENT_GUARDRAILS.md section (D)"; bad=1
            else st="$tmpd (${rtmp:-not yet created}) - on disk"; fi
        fi
        printf '%-62s %s\n' "$label" "$st"
    done
    [ "$undet" -eq 0 ] || return 2
    if [ "$bad" -ne 0 ]; then say "verify-persistence: NOT reboot-safe yet (rows above in CAPITALS)"; return 1; fi
    echo "verify-persistence: every artifact persists and a fresh login resolves TMPDIR to disk"
    return 0
}

prove() {
    local pass=0 fail=0 T rc out d1 d2 d3
    ok() { pass=$((pass + 1)); echo "  ok   $*"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $*"; }
    T=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/agent-scratch-prove.XXXXXX") || { echo "COULD-NOT-PROVE: no temp dir on disk"; return 2; }
    cleanup() { chmod -R u+rwx -- "$T" 2>/dev/null; rm -rf -- "$T"; }
    trap cleanup RETURN
    # Everything lives under $T on disk. A "RAM-backed" root is simulated with the stricter-only seam
    # AGENT_SCRATCH_TEST_RAMFS_PREFIX, so the proof writes nothing to /tmp, /dev/shm or any .git directory.
    local RAMP="$T/ramfs"
    run() { local root=$1; shift; AGENT_SCRATCH_TEST_RAMFS_PREFIX="$RAMP" AGENT_SCRATCH_ROOT=$root bash "${SCRIPT:-$SELF}" "$@"; }
    SCRIPT=$SELF
    # S1 new: a 0700 dir directly under the root, with the marker, path printed
    out=$(run "$T/root" new probe-s1 2>/dev/null); rc=$?
    if [ "$rc" -eq 0 ] && [ -d "$out" ] && [ "$(dirname "$out")" = "$T/root" ] && [ "$(stat -c %a "$out")" = 700 ] \
        && [ "$(head -1 "$out/.agent-scratch")" = "$MARK_LINE" ]; then ok "S1 new prints a 0700 marked dir under the root"; else bad "S1 rc=$rc out=$out"; fi
    d1=$out
    case "$d1" in "$T"/root/*) ;; *) echo "COULD-NOT-PROVE: new did not yield a dir under the test root; later cases need one"; echo "agent-scratch --prove-failure: $pass passed, $((fail + 1)) failed"; return 1 ;; esac
    # S2 bad labels (incl. a newline, which a line-wise grep accepted) are rc 2 and create nothing
    local nb=0 before after
    before=$(find "$T/root" -mindepth 1 -maxdepth 1 | wc -l)
    for l in '../x' '' '-x' 'a/b' "$(printf 'a%.0s' $(seq 1 70))" $'ok\nsecond' $'ok\n../../escape'; do
        run "$T/root" new "$l" >/dev/null 2>&1; [ $? -eq 2 ] || nb=$((nb + 1))
    done
    after=$(find "$T/root" -mindepth 1 -maxdepth 1 | wc -l)
    [ "$nb" -eq 0 ] && [ "$before" = "$after" ] && ok "S2 7 bad labels (2 with a newline) refused rc 2, nothing created" || bad "S2 $nb not rc 2; entries $before -> $after"
    # S3 a RAM-backed root is refused (rc 1) and nothing is created
    run "$RAMP/r" new probe-s3 >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 1 ] && [ -z "$(ls -A "$RAMP/r" 2>/dev/null)" ] && ok "S3 RAM-backed root refused rc 1, nothing created" || bad "S3 rc=$rc"
    # S4 du lists the created dir and a total
    printf 'x%.0s' $(seq 1 5000) >"$d1/blob"
    out=$(run "$T/root" du 2>/dev/null); rc=$?
    [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "	$d1\$" && printf '%s' "$out" | grep -q '^total	' && ok "S4 du lists the dir and a total" || bad "S4 rc=$rc out=$out"
    # S5 gc removes ONLY marked, old, real dirs directly under the root
    d2=$(run "$T/root" new probe-recent 2>/dev/null)
    mkdir -p "$T/root/foreign-old" "$T/outside/victim"
    printf '%s\n' "$MARK_LINE" >"$T/outside/victim/.agent-scratch"
    ln -s "$T/outside/victim" "$T/root/link-to-outside"
    printf 'impostor\n' >"$T/root/foreign-old/.agent-scratch"
    find "$d1" "$T/root/foreign-old" "$T/outside" -exec touch -h -d '3 days ago' {} +
    out=$(run "$T/root" gc --older-than 1d 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ ! -e "$d1" ] && [ -d "$d2" ] && [ -d "$T/root/foreign-old" ] && [ -f "$T/outside/victim/.agent-scratch" ]; then
        ok "S5 gc removed only the old marked dir (recent, foreign, symlinked kept)"
    else bad "S5 rc=$rc d1-exists=$([ -e "$d1" ] && echo y) out=$out"; fi
    # S6 --dry-run removes nothing
    d3=$(run "$T/root" new probe-dry 2>/dev/null); find "$d3" -exec touch -d '3 days ago' {} +
    run "$T/root" gc --older-than 1d --dry-run >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] && [ -d "$d3" ] && ok "S6 gc --dry-run removed nothing" || bad "S6 rc=$rc"
    # S7 bad durations / usage are rc 2
    local nu=0
    run "$T/root" gc --older-than 3x >/dev/null 2>&1; [ $? -eq 2 ] || nu=$((nu + 1))
    run "$T/root" gc >/dev/null 2>&1; [ $? -eq 2 ] || nu=$((nu + 1))
    run "$T/root" bogus >/dev/null 2>&1; [ $? -eq 2 ] || nu=$((nu + 1))
    [ "$nu" -eq 0 ] && ok "S7 bad duration / missing arg / unknown subcommand are rc 2" || bad "S7 $nu not rc 2"
    # S8 df-check: a disk root on the repo's filesystem and mount => hardlink works, rc 0; NOTHING written in the repo
    local gd snap1 snap2; gd=$(git -C "$UMBRELLA" rev-parse --absolute-git-dir 2>/dev/null)
    snap1=$(find "$gd" -maxdepth 1 -name 'agent-scratch-probe*' 2>/dev/null | wc -l)
    out=$(run "$T/root" df-check --repo "$UMBRELLA" 2>/dev/null); rc=$?
    snap2=$(find "$gd" -maxdepth 1 -name 'agent-scratch-probe*' -newer "$T/root" 2>/dev/null | wc -l)
    [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^hardlink_repo_to_scratch=works$' && [ "$snap2" -eq 0 ] \
        && ok "S8 df-check on disk: same fs+mount, hardlink works, rc 0, no probe file in .git" || bad "S8 rc=$rc probes=$snap1/$snap2 out=$out"
    # S9 df-check with a RAM-backed root => rc 1
    out=$(run "$RAMP/r2" df-check --repo "$UMBRELLA" 2>/dev/null); rc=$?
    [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^scratch_ram_backed=yes$' && ok "S9 df-check on a RAM-backed root: rc 1" || bad "S9 rc=$rc out=$out"
    # S9b df-check against a repo on ANOTHER filesystem => no hardlink, rc 1 (the incident's cross-device case)
    out=$(run "$T/root" df-check --repo /proc 2>/dev/null); rc=$?
    [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^same_filesystem=no$' && ok "S9b df-check across filesystems: same_filesystem=no, rc 1" || bad "S9b rc=$rc out=$out"
    # S10 an uncreatable root is rc 2 (never a pass)
    run /proc/agent-scratch-nonexistent df-check >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && ok "S10 uncreatable root: df-check rc 2" || bad "S10 rc=$rc"
    # S11 fresh boot: the root does not exist (first use after a reboot / cache wipe) => `new` recreates it 0700
    rm -rf "$T/fresh"; out=$(run "$T/fresh/a/b" new probe-boot 2>/dev/null); rc=$?
    [ "$rc" -eq 0 ] && [ -d "$out" ] && [ "$(stat -c %a "$T/fresh/a/b")" = 700 ] && ok "S11 missing root recreated 0700 by new" || bad "S11 rc=$rc"
    # S12 a SYMLINKED root is refused and its target is not chmod-ed (review X8: 755 -> 700)
    mkdir -p "$T/target"; chmod 755 "$T/target"; ln -sfn "$T/target" "$T/linkroot"
    run "$T/linkroot" new probe-s12 >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 1 ] && [ "$(stat -c %a "$T/target")" = 755 ] && [ -z "$(ls -A "$T/target")" ] && ok "S12 symlinked root refused rc 1, target untouched (755)" || bad "S12 rc=$rc mode=$(stat -c %a "$T/target")"
    # M1 mutation: marker check neutered => S5's detector sees a foreign dir deleted
    sed 's/^marker_ok() {$/marker_ok() { [ -d "$1" ]; return; /' "$SELF" >"$T/m1.sh"
    mkdir -p "$T/mroot/foreign"; touch -d '3 days ago' "$T/mroot/foreign"
    AGENT_SCRATCH_ROOT="$T/mroot" bash "$T/m1.sh" gc --older-than 1d >/dev/null 2>&1
    [ ! -e "$T/mroot/foreign" ] && ok "M1 a mutant without the marker check deletes a foreign dir (S5 would FAIL)" || bad "M1 mutant not caught"
    # M2 mutation: RAM check neutered => S3's detector sees a RAM-backed root accepted
    sed 's/^is_ram_fs() {.*$/is_ram_fs() { return 1; }/' "$SELF" >"$T/m2.sh"
    SCRIPT="$T/m2.sh" run "$RAMP/m2" new probe-m2 >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] && ok "M2 a mutant without the RAM check accepts a RAM-backed root (S3 would FAIL)" || bad "M2 mutant rc=$rc"
    mut() { python3 -I -c 'import sys
s=open(sys.argv[1]).read(); o,n=sys.argv[2],sys.argv[3]
sys.exit(3) if o not in s else open(sys.argv[4],"w").write(s.replace(o,n,1))' "$SELF" "$2" "$3" "$T/$1.sh" || bad "$1 mutation anchor not found"; }
    # M4 whole-string label check replaced by a line-wise grep => S2's newline label creates entries
    mut m4 '[[ "$label" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$ ]]' "printf '%s' \"\$label\" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\$'"
    SCRIPT="$T/m4.sh" run "$T/m4root" new $'ok\nsecond' >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] && ok "M4 a mutant with line-wise label validation accepts a newline label (S2 would FAIL)" || bad "M4 rc=$rc"
    # M5 symlink refusal removed => S12's target gets chmod-ed
    mut m5 '    if [ -L "$R" ]; then' '    if false; then'
    mkdir -p "$T/target5"; chmod 755 "$T/target5"; ln -sfn "$T/target5" "$T/linkroot5"
    SCRIPT="$T/m5.sh" run "$T/linkroot5" new probe-m5 >/dev/null 2>&1
    [ "$(stat -c %a "$T/target5")" = 700 ] && ok "M5 a mutant without the symlink refusal chmods the target to 700 (S12 would FAIL)" || bad "M5 mode=$(stat -c %a "$T/target5")"
    # P1-P6 verify-persistence against fixture repos and fixture login homes (no real dotfile is read)
    local FR="$T/prepo" FH="$T/phome" OD="$T/elsewhere"
    mkdir -p "$FR" "$FH/disk-tmp" "$OD"; git -C "$FR" init -q 2>/dev/null
    for f in $PERSIST_TRACKED; do mkdir -p "$FR/$(dirname "$f")"; printf 'x\n' >"$FR/$f"; done
    printf '## (D) HOST RESOURCE SAFETY\n' >"$FR/docs/AGENT_GUARDRAILS.md"
    git -C "$FR" add -A >/dev/null 2>&1; git -C "$FR" -c user.name=p -c user.email=p@p -c commit.gpgsign=false commit -qm fixture >/dev/null 2>&1
    vp() { ( cd "$T" && AGENT_PERSIST_HOME="$FH" AGENT_PERSIST_OTHER_DIR="$OD" AGENT_SCRATCH_ROOT="$T/root" bash "${SCRIPT:-$SELF}" verify-persistence --repo "$FR" >"$T/vp.out" 2>&1 ); }
    fxhome() { # $1 TMPDIR value ('' = none)  $2 abs|rel: how ~/.bash_profile sources ~/.bashrc
        rm -f "$FH/.profile" "$FH/.bash_profile" "$FH/.bashrc"
        if [ -n "$1" ]; then printf 'export TMPDIR="%s"\n' "$1" >"$FH/.bashrc"; else : >"$FH/.bashrc"; fi
        if [ "$2" = rel ]; then printf '. .bashrc\n' >"$FH/.bash_profile"; else printf '. "$HOME/.bashrc"\n' >"$FH/.bash_profile"; fi
    }
    local hasbr=0; command -v bounded-run >/dev/null && hasbr=1
    fxhome "$FH/disk-tmp" abs; vp; rc=$?
    { [ "$rc" -eq 0 ] || [ "$hasbr" -eq 0 ]; } && [ "$(grep -c 'disk-tmp.*on disk' "$T/vp.out")" -eq 4 ] && ok "P1 committed artifacts + disk TMPDIR in all 4 fresh-shell rows => rc 0" || bad "P1 rc=$rc $(grep -E 'fresh' "$T/vp.out")"
    fxhome /tmp/claude-sessions abs; vp; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'RAM-backed' "$T/vp.out" && ok "P2 TMPDIR under /tmp in a fresh shell => rc 1" || bad "P2 rc=$rc"
    fxhome '' abs; vp; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'UNSET' "$T/vp.out" && ok "P3 TMPDIR unset in a fresh shell => rc 1" || bad "P3 rc=$rc"
    fxhome "$FH/disk-tmp" abs; printf 'y\n' >>"$FR/scripts/agent-admit.sh"; vp; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'UNCOMMITTED' "$T/vp.out" && ok "P4 an uncommitted artifact => rc 1" || bad "P4 rc=$rc"
    git -C "$FR" checkout -q -- scripts/agent-admit.sh
    AGENT_PERSIST_HOME="$FH" bash "$SELF" verify-persistence --repo /nonexistent >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && ok "P5 no git work tree => rc 2" || bad "P5 rc=$rc"
    # P6 the operator's real shape: ~/.bash_profile `. .bashrc` (RELATIVE). From HOME every row is on disk; a login
    #    started elsewhere does not find .bashrc => UNSET => rc 1, independent of the CALLER's cwd (review finding 8)
    fxhome "$FH/disk-tmp" rel; vp; rc=$?
    if [ "$rc" -eq 1 ] && grep -q 'fresh login from HOME (bash -lc).*disk-tmp.*on disk' "$T/vp.out" \
        && grep -q "fresh login from $OD (bash -lc, not HOME).*UNSET" "$T/vp.out"; then
        ok "P6 relative '. .bashrc': HOME rows on disk, non-HOME login UNSET => rc 1 (caller cwd irrelevant)"
    else bad "P6 rc=$rc $(grep -E 'fresh' "$T/vp.out")"; fi
    # M3 mutation: the RAM-path test on TMPDIR removed => P2's detector sees /tmp accepted as persistent
    mut m3 '            if case "$tmpd" in /tmp|/tmp/*|/dev/shm|/dev/shm/*|/run/user/*) true ;; *) false ;; esac || is_ram_fs "${rtmp:-}"; then' '            if false; then'
    fxhome /tmp/claude-sessions abs; SCRIPT="$T/m3.sh" vp; rc=$?
    ! grep -q 'RAM-backed' "$T/vp.out" && ok "M3 a mutant without the TMPDIR RAM test passes /tmp (P2 would FAIL)" || bad "M3 rc=$rc"
    # M6 the probes no longer cd to their start directory => P6's HOME login row depends on the caller's cwd
    mut m6 '( cd "$dir" 2>/dev/null || exit 3' '( :'
    fxhome "$FH/disk-tmp" rel; SCRIPT="$T/m6.sh" vp
    ! grep -q 'fresh login from HOME (bash -lc).*on disk' "$T/vp.out" && ok "M6 a mutant probing from the caller's cwd loses the HOME login row (P6 would FAIL)" || bad "M6 not caught"
    echo "agent-scratch --prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}

case "${1:-}" in
    new) shift; cmd_new "$@"; exit $? ;;
    du) shift; cmd_du "$@"; exit $? ;;
    gc) shift; cmd_gc "$@"; exit $? ;;
    df-check) shift; cmd_df_check "$@"; exit $? ;;
    verify-persistence) shift; cmd_verify_persistence "$@"; exit $? ;;
    --prove-failure) prove; exit $? ;;
    -h|--help) sed -n '2,32p' "$SELF"; exit 0 ;;
    *) say "usage: $0 new <label> | du | gc --older-than DUR [--dry-run] | df-check [--repo DIR] | verify-persistence [--repo DIR] | --prove-failure"; exit 2 ;;
esac
