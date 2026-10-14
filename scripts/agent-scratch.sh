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

ensure_root() {
    if ! mkdir -p -- "$R" 2>/dev/null || [ ! -d "$R" ]; then say "cannot create scratch root $R"; return 2; fi
    chmod 700 -- "$R" 2>/dev/null || { say "cannot chmod 0700 $R"; return 2; }
    local t; t=$(stat -f -c %T -- "$R" 2>/dev/null) || { say "cannot stat filesystem of $R"; return 2; }
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
    printf '%s' "$label" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$' \
        || { say "bad label '$label' (^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$)"; return 2; }
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
    local repo='' rc gitdir rt rd pt pd src lnk same hl=fails
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
    rt=$(stat -f -c %T -- "$R" 2>/dev/null) && rd=$(stat -c %d -- "$R" 2>/dev/null) || { say "cannot stat $R"; return 2; }
    pt=$(stat -f -c %T -- "$repo" 2>/dev/null) && pd=$(stat -c %d -- "$repo" 2>/dev/null) || { say "cannot stat $repo"; return 2; }
    [ "$rd" = "$pd" ] && same=yes || same=no
    gitdir=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null) || gitdir=$repo
    src=$(mktemp -- "$gitdir/agent-scratch-probe.XXXXXX" 2>/dev/null) || { say "cannot create a probe file in $gitdir"; return 2; }
    lnk="$R/.hardlink-probe.$$"
    if ln -- "$src" "$lnk" 2>/dev/null; then hl=works; fi
    rm -f -- "$src" "$lnk"
    printf 'scratch_root=%s\nscratch_fs=%s\nscratch_dev=%s\nrepo=%s\nrepo_fs=%s\nrepo_dev=%s\nsame_filesystem=%s\nhardlink_repo_to_scratch=%s\nscratch_ram_backed=%s\n' \
        "$R" "$rt" "$rd" "$repo" "$pt" "$pd" "$same" "$hl" "$(is_ram_fs "$rt" && echo yes || echo no)"
    if [ "$rc" -eq 1 ] || [ "$same" = no ] || [ "$hl" != works ]; then
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
    tfs=$(stat -f -c %T -- "$R" 2>/dev/null || stat -f -c %T -- "$(dirname -- "$R")" 2>/dev/null) || tfs=unknown
    if is_ram_fs "$tfs"; then st="RAM-BACKED ($tfs): lost on reboot"; bad=1; else st="disk ($tfs); recreated 0700 by 'new' when absent"; fi
    printf '%-62s %s\n' "host: scratch root $R" "$st"
    printf '%-62s %s\n' "host: slot files $R/slots" "ephemeral by design (flock state is per boot; stale files are reused)"
    wired=no; grep -q 'guard-project-catalogue' "$repo/.claude/settings.json" 2>/dev/null && wired=yes
    printf '%-62s %s\n' "hook wiring in .claude/settings.json (tmpfs rule live?)" "$wired (operator decision; reported, not gated)"
    sysd=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^TMPDIR=//p')
    printf '%-62s %s\n' "systemd --user environment TMPDIR (GUI terminals)" "${sysd:-unset} (reported)"
    # TMPDIR in a FRESH login environment: what a newly started shell (and the claude it launches) sees
    tmpd=$(env -i HOME="$phome" USER="${USER:-}" LOGNAME="${LOGNAME:-}" PATH=/usr/local/bin:/usr/bin:/bin \
        timeout 30 bash -lc 'printf "\nAGENT_PERSIST_TMPDIR=%s\n" "${TMPDIR:-}"' 2>/dev/null </dev/null \
        | sed -n 's/^AGENT_PERSIST_TMPDIR=//p' | tail -n 1)
    if [ "${PIPESTATUS[0]:-0}" -ne 0 ] && [ -z "$tmpd" ]; then :; fi
    if ! env -i HOME="$phome" PATH=/usr/bin:/bin timeout 30 bash -lc 'exit 0' </dev/null >/dev/null 2>&1; then
        say "CANNOT DETERMINE: a fresh login shell (env -i HOME=$phome bash -lc) did not start"; undet=1
    fi
    if [ -z "$tmpd" ]; then
        st="UNSET -> the harness falls back to /tmp (RAM). OPERATOR STEP: docs/AGENT_GUARDRAILS.md section (D)"; bad=1
    else
        rtmp=$(stat -f -c %T -- "$tmpd" 2>/dev/null || true)
        if case "$tmpd" in /tmp|/tmp/*|/dev/shm|/dev/shm/*|/run/user/*) true ;; *) false ;; esac || is_ram_fs "${rtmp:-}"; then
            st="$tmpd is RAM-backed (${rtmp:-tmpfs path}). OPERATOR STEP: docs/AGENT_GUARDRAILS.md section (D)"; bad=1
        else st="$tmpd (${rtmp:-not yet created}) - on disk"; fi
    fi
    printf '%-62s %s\n' "fresh login: TMPDIR (env -i HOME=... bash -lc)" "$st"
    [ "$undet" -eq 0 ] || return 2
    if [ "$bad" -ne 0 ]; then say "verify-persistence: NOT reboot-safe yet (rows above in CAPITALS)"; return 1; fi
    echo "verify-persistence: every artifact persists and a fresh login resolves TMPDIR to disk"
    return 0
}

prove() {
    local pass=0 fail=0 T rc out d1 d2 d3 shm
    ok() { pass=$((pass + 1)); echo "  ok   $*"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $*"; }
    T=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/agent-scratch-prove.XXXXXX") || { echo "COULD-NOT-PROVE: no temp dir on disk"; return 2; }
    shm=''
    for c in /dev/shm /tmp; do [ "$(stat -f -c %T "$c" 2>/dev/null)" = tmpfs ] && { shm=$c; break; }; done
    local SHMROOT=''
    [ -n "$shm" ] && SHMROOT=$(mktemp -d "$shm/agent-scratch-prove.XXXXXX")
    cleanup() { rm -rf -- "$T"; [ -n "$SHMROOT" ] && rm -rf -- "$SHMROOT"; }
    trap cleanup RETURN
    run() { local root=$1; shift; AGENT_SCRATCH_ROOT=$root bash "${SCRIPT:-$SELF}" "$@"; }
    SCRIPT=$SELF
    # S1 new: a 0700 dir directly under the root, with the marker, path printed
    out=$(run "$T/root" new probe-s1 2>/dev/null); rc=$?
    if [ "$rc" -eq 0 ] && [ -d "$out" ] && [ "$(dirname "$out")" = "$T/root" ] && [ "$(stat -c %a "$out")" = 700 ] \
        && [ "$(head -1 "$out/.agent-scratch")" = "$MARK_LINE" ]; then ok "S1 new prints a 0700 marked dir under the root"; else bad "S1 rc=$rc out=$out"; fi
    d1=$out
    case "$d1" in "$T"/root/*) ;; *) echo "COULD-NOT-PROVE: new did not yield a dir under the test root; later cases need one"; echo "agent-scratch --prove-failure: $pass passed, $((fail + 1)) failed"; return 1 ;; esac
    # S2 bad labels are rc 2 and create nothing
    local nb=0
    for l in '../x' '' '-x' 'a/b' "$(printf 'a%.0s' $(seq 1 70))"; do run "$T/root" new "$l" >/dev/null 2>&1; [ $? -eq 2 ] || nb=$((nb + 1)); done
    [ "$nb" -eq 0 ] && ok "S2 5 bad labels refused with rc 2" || bad "S2 $nb bad labels not rc 2"
    # S3 a RAM-backed root is refused (rc 1) and nothing is created
    if [ -n "$SHMROOT" ]; then
        run "$SHMROOT/r" new probe-s3 >/dev/null 2>&1; rc=$?
        [ "$rc" -eq 1 ] && [ -z "$(ls -A "$SHMROOT/r" 2>/dev/null)" ] && ok "S3 tmpfs root refused rc 1, nothing created" || bad "S3 rc=$rc"
    else bad "S3 no tmpfs available to test the RAM refusal"; fi
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
    # S8 df-check: a disk root on the repo's filesystem => hardlink works, rc 0
    out=$(run "$T/root" df-check --repo "$UMBRELLA" 2>/dev/null); rc=$?
    [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^hardlink_repo_to_scratch=works$' && ok "S8 df-check on disk: same fs, hardlink works, rc 0" || bad "S8 rc=$rc out=$out"
    # S9 df-check with a RAM-backed root => rc 1 (the incident's cross-device case)
    if [ -n "$SHMROOT" ]; then
        out=$(run "$SHMROOT/r2" df-check --repo "$UMBRELLA" 2>/dev/null); rc=$?
        [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^hardlink_repo_to_scratch=fails$' && ok "S9 df-check on tmpfs: hardlink fails, rc 1" || bad "S9 rc=$rc out=$out"
    else bad "S9 no tmpfs available"; fi
    # S10 an uncreatable root is rc 2 (never a pass)
    run /proc/agent-scratch-nonexistent df-check >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && ok "S10 uncreatable root: df-check rc 2" || bad "S10 rc=$rc"
    # M1 mutation: marker check neutered => S5's detector sees a foreign dir deleted
    sed 's/^marker_ok() {$/marker_ok() { [ -d "$1" ]; return; /' "$SELF" >"$T/m1.sh"
    mkdir -p "$T/mroot/foreign"; touch -d '3 days ago' "$T/mroot/foreign"
    AGENT_SCRATCH_ROOT="$T/mroot" bash "$T/m1.sh" gc --older-than 1d >/dev/null 2>&1
    [ ! -e "$T/mroot/foreign" ] && ok "M1 a mutant without the marker check deletes a foreign dir (S5 would FAIL)" || bad "M1 mutant not caught"
    # M2 mutation: RAM check neutered => S3's detector sees a tmpfs root accepted
    if [ -n "$SHMROOT" ]; then
        sed 's/^is_ram_fs() {.*$/is_ram_fs() { return 1; }/' "$SELF" >"$T/m2.sh"
        AGENT_SCRATCH_ROOT="$SHMROOT/m2" bash "$T/m2.sh" new probe-m2 >/dev/null 2>&1; rc=$?
        [ "$rc" -eq 0 ] && ok "M2 a mutant without the RAM check accepts a tmpfs root (S3 would FAIL)" || bad "M2 mutant rc=$rc"
    else bad "M2 no tmpfs available"; fi
    # S11 fresh boot: the root does not exist (first use after a reboot / cache wipe) => `new` recreates it 0700
    rm -rf "$T/fresh"; out=$(run "$T/fresh/a/b" new probe-boot 2>/dev/null); rc=$?
    [ "$rc" -eq 0 ] && [ -d "$out" ] && [ "$(stat -c %a "$T/fresh/a/b")" = 700 ] && ok "S11 missing root recreated 0700 by new" || bad "S11 rc=$rc"
    # P1-P4 verify-persistence against fixture repos and fixture login homes
    local FR="$T/prepo" FH="$T/phome"
    mkdir -p "$FR" "$FH/disk-tmp"; git -C "$FR" init -q 2>/dev/null
    for f in $PERSIST_TRACKED; do mkdir -p "$FR/$(dirname "$f")"; printf 'x\n' >"$FR/$f"; done
    printf '## (D) HOST RESOURCE SAFETY\n' >"$FR/docs/AGENT_GUARDRAILS.md"
    git -C "$FR" add -A >/dev/null 2>&1; git -C "$FR" -c user.name=p -c user.email=p@p -c commit.gpgsign=false commit -qm fixture >/dev/null 2>&1
    vp() { AGENT_PERSIST_HOME="$FH" AGENT_SCRATCH_ROOT="$T/root" bash "${SCRIPT:-$SELF}" verify-persistence --repo "$FR" >"$T/vp.out" 2>&1; }
    printf 'export TMPDIR="%s/disk-tmp"\n' "$FH" >"$FH/.profile"
    vp; rc=$?
    { [ "$rc" -eq 0 ] || ! command -v bounded-run >/dev/null; } && grep -q 'disk-tmp' "$T/vp.out" && ok "P1 committed artifacts + disk TMPDIR in a fresh login => rc 0" || bad "P1 rc=$rc $(tail -3 "$T/vp.out")"
    printf 'export TMPDIR=/tmp/claude-sessions\n' >"$FH/.profile"; vp; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'RAM-backed' "$T/vp.out" && ok "P2 TMPDIR under /tmp in a fresh login => rc 1" || bad "P2 rc=$rc"
    : >"$FH/.profile"; vp; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'UNSET' "$T/vp.out" && ok "P3 TMPDIR unset in a fresh login => rc 1" || bad "P3 rc=$rc"
    printf 'export TMPDIR="%s/disk-tmp"\n' "$FH" >"$FH/.profile"; printf 'y\n' >>"$FR/scripts/agent-admit.sh"; vp; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'UNCOMMITTED' "$T/vp.out" && ok "P4 an uncommitted artifact => rc 1" || bad "P4 rc=$rc"
    git -C "$FR" checkout -q -- scripts/agent-admit.sh
    AGENT_PERSIST_HOME="$FH" bash "$SELF" verify-persistence --repo /nonexistent >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && ok "P5 no git work tree => rc 2" || bad "P5 rc=$rc"
    # M3 mutation: the RAM-path test on TMPDIR removed => P2's detector sees /tmp accepted as persistent
    sed 's/^        if case "\$tmpd" in .*$/        if false; then/' "$SELF" >"$T/m3.sh"
    printf 'export TMPDIR=/tmp/claude-sessions\n' >"$FH/.profile"; SCRIPT="$T/m3.sh" vp; rc=$?
    { [ "$rc" -eq 0 ] || ! grep -q 'RAM-backed' "$T/vp.out"; } && ok "M3 a mutant without the TMPDIR RAM test passes /tmp (P2 would FAIL)" || bad "M3 rc=$rc"
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
    *) say "usage: $0 new <label> | du | gc --older-than DUR [--dry-run] | df-check [--repo DIR] | --prove-failure"; exit 2 ;;
esac
