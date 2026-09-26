#!/usr/bin/env bash
# zero-gap-sweep.sh — the feature-010 sweep RUNNER (T017) and its RECALL ENGINE (T018).
#
# Enumerates the estate class by class from the DATA file
# docs/zero-gap/sweep-classes.tsv, runs each class's entry point
# `scripts/zero-gap-class-<id>.sh`, measures each class's recall against its
# planted-defect corpus `_tests/fixtures/zero-gap/<id>/`, and prints one
# deterministic, sorted report. Contract: specs/010-zero-gap-verified-closure/
# contracts/sweep-runner.md; the class contract, the percent-encoding helper and
# the registration protocol: docs/zero-gap/README.md.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   zero-gap-sweep.sh [--class <id>]... [--json] [--out <dir>]
#                     [--expect-fingerprint <sha256>] [--root <dir>]
#   zero-gap-sweep.sh --prove-failure      paired proof (§1.1) on throwaway repos
#
#   --class <id>              run only these classes (repeatable; unknown id => rc 2)
#   --json                    print the same report as one JSON document
#   --out <dir>               ALSO write the report (temp file + mv) into <dir>, which
#                             must resolve under <root>/.remember/logs/zero-gap/
#                             (git-ignored, no symlink); anything else => rc 2, nothing run
#   --expect-fingerprint <h>  refuse (rc 2, nothing run) unless the state
#                             fingerprint taken before the run equals <h>
#   --root <dir>              the tree to sweep (default: this repository)
#
#   ZG_CLASS_BUDGET     seconds for ALL runs of one class (default 900)
#   ZG_SWEEP_BUDGET     seconds for the whole sweep (default 10800 = 3 h)
#   ZG_IGNORED_EXCLUDE  ':'-separated path prefixes of IGNORED paths whose writes
#                       are not attributed to a class (default
#                       .remember/tmp/:.remember/logs/:.service-registry/qa/ —
#                       host session tooling, and the access logs of the QA
#                       servers a class may probe read-only)
#
# ── Exit (three-valued; 2 is NEVER a pass) ───────────────────────────────────
#   0  no finding, and every class inspected its full non-empty population with
#      recall 1.0 and no false positive (a recall below 1.0 or a false positive is
#      itself a FINDING)
#   1  at least one FINDING (a finding outranks a class-level undetermined)
#   2  otherwise: a TSV defect, an empty class list, a class not implemented /
#      over budget / outside its output contract / inspecting less than or a
#      different set than its population / enumerating zero items / reaching
#      corpus fixtures, a recall=UNKNOWN, a malformed corpus, a failed fingerprint,
#      a fingerprint other than --expect-fingerprint, a refused --out, bad usage —
#      or the tree MOVED during the run (UNSTABLE: rc 2 even with findings; its
#      FINDING lines are not evidence and must not seed the register)
#
# ── Output (stdout, byte-identical for an unchanged fingerprinted state) ─────
#   FINDING <class_id> <severity> <category> <location> <description> <evidence_ref>
#   COULD-NOT-INSPECT <class_id>:<part> <reason>        (`-` part = whole class)
#   CLASS <id> population=<n> inspected=<n> recall=<0..1|UNKNOWN> findings=<n> status=<s>
#   FINGERPRINT before=<sha256> files=<n>
#   FINGERPRINT after=<sha256> files=<n>
#   VERDICT <HOLDS|VIOLATED|UNDETERMINED|UNSTABLE> rc=<n> findings=<n> could-not-inspect=<n> classes=<n> unknown-recall=<n>
# Findings sort by class then location; COULD-NOT-INSPECT by part; CLASS by id.
# status: clean | findings | could-not-inspect | unproven (no finding, recall
# UNKNOWN — never evidence of absence) | not-implemented. The pseudo class
# `sweep` carries the runner's own findings and parts. Locations, evidence refs
# and parts are single percent-encoded tokens (README "The class contract").
# The report is ASCII apart from class descriptions, which are valid UTF-8 with
# no control character (a class line that is not is rejected).
#
# ── State fingerprint ────────────────────────────────────────────────────────
# zero-gap-lib.sh's zg_manifest over the whole --root (tracked + untracked-not-
# ignored files by content, exec bit, symlink target; gitlinks by commit and
# status) PLUS the HEAD commit, a digest of `git for-each-ref`, of `git config
# --local --list`, of `git ls-files -s` and of the contents of <git-dir>/hooks and
# <git-dir>/info (a planted hook or info/exclude line), PLUS (mtime, ctime, size, inode) of
# every tracked and untracked-not-ignored file — so a write-then-restore, a
# commit and a config change are all visible. files= counts zg_manifest entries.
# It is taken before the first class and after EVERY class; a difference names
# the class that was running (a concurrent editor cannot be told apart from the
# class, and either way no verdict about that state is valid). The cost of each
# window is printed on stderr. IGNORED paths are outside the fingerprint; a change
# to an ignored FILE during a class (created, removed, written, or replaced by cp -p:
# its ctime moves) is reported separately as COULD-NOT-INSPECT (not UNSTABLE),
# except under ZG_IGNORED_EXCLUDE. Empty ignored directories are not seen.
#
# ── Environment ──────────────────────────────────────────────────────────────
# The runner first re-executes itself ONCE as `env -i <allow-list> bash --norc
# --noprofile` (guard: ZG_SWEEP_REEXEC equals its own pid). Runner allow-list:
# PATH HOME TMPDIR USER LOGNAME XDG_RUNTIME_DIR ZG_CLASS_BUDGET ZG_SWEEP_BUDGET
# ZG_IGNORED_EXCLUDE (when set) plus LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null
# GIT_CONFIG_SYSTEM=/dev/null GOTOOLCHAIN=local GOMAXPROCS (default 4) and
# GIT_CONFIG_COUNT/KEY/VALUE pinning core.excludesFile and core.attributesFile to
# /dev/null (git's IMPLICIT ~/.config/git/ignore and attributes otherwise apply).
# So SHELLOPTS, exported functions, GIT_*, CDPATH, POSIXLY_CORRECT and the user's
# global/XDG git config cannot change a verdict. Two things are read by the FIRST
# bash before line 1 and cannot be refused from here: a BASH_ENV/ENV file, and
# SHELLOPTS=noexec (bash then parses the file, runs nothing and exits 0 with EMPTY
# output — measured). A consumer MUST therefore require the VERDICT line; an rc 0
# without `VERDICT HOLDS rc=0` is not a pass.
# Classes run as `env -i` with ONLY: PATH HOME TMPDIR USER LOGNAME
# XDG_RUNTIME_DIR (each only when set; TMPDIR defaults to a private directory
# of the run), LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
# the same GIT_CONFIG_COUNT/KEY/VALUE pins, GOTOOLCHAIN=local GOMAXPROCS PYTHONDONTWRITEBYTECODE=1
# and ZG_RUN (a random token of this run); each in its own session/process group
# (setsid), cwd <root>, stdin /dev/null. Signals: a class over budget, or one that
# exits leaving processes in its group, gets TERM then KILL sent to THAT group only,
# after verifying the group is ours (leader start time, or a member carrying
# ZG_RUN); after every invocation /proc is scanned for processes of our uid that
# still carry ZG_RUN (escaped the group, e.g. via setsid): every such pid is FROZEN
# with SIGSTOP and /proc rescanned until no new one appears (so an escapee that keeps
# spawning cannot outrun it; bounded), then each is sent KILL — the start time
# re-read before every signal. Never a signal by name or pattern. Stated limit: a
# descendant that drops ZG_RUN from its environment AND leaves the group is not
# found. The only containment that closes it here is a cgroup scope
# (`systemd-run --user --scope`, measured available on this host, rc 0); an
# unprivileged user namespace is not (`unshare -Ur`: uid_map write not permitted).
# Adopting a scope is a design change NOT made in this runner (recorded residual).
#
# ── Recall engine (T018) ─────────────────────────────────────────────────────
# Recomputed on EVERY run; the TSV `recall` column is only the last PUBLISHED
# figure. For a class whose corpus directory exists, the class also runs with
# --corpus planted/ and --corpus clean/. recall = (expect.tsv rows whose location
# the class reports) / (expect.tsv rows). RECALL-MISS, RECALL-UNEXPECTED,
# RECALL-FALSE-POSITIVE and RECALL-MISMATCH are FINDINGs located at the class
# script, with the corpus path in the description. No corpus directory =>
# recall=UNKNOWN; a malformed corpus => COULD-NOT-INSPECT.
#
# ── Registration ─────────────────────────────────────────────────────────────
# This runner is registered in scripts/check-registry.tsv as `zero-gap-sweep`.
# Class scripts: one appended registry row each, nobody stages, one wave commit
# (docs/zero-gap/README.md "Registering a class").
#
# Dependencies: bash, git, coreutils (sha256sum sort comm cut od stat realpath
# mktemp setsid touch), awk, iconv, find, xargs, scripts/zero-gap-lib.sh.
# --prove-failure also needs python3.

# ── re-exec ONCE under `env -i` + an explicit allow-list: FIRST, before anything reads the
# environment. SHELLOPTS, BASHOPTS, exported functions (BASH_FUNC_*%%), GIT_*, POSIXLY_CORRECT,
# CDPATH, BASH_ENV/ENV and every other inherited variable are dropped; `exec` keeps the pid, so
# ZG_SWEEP_REEXEC == $$ proves the re-exec happened (a copy of the variable from a caller cannot
# carry this process's pid).
if [ "${ZG_SWEEP_REEXEC:-}" != "$$" ]; then
    _zg_env=("ZG_SWEEP_REEXEC=$$" "LC_ALL=C" "LANG=C" "GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_SYSTEM=/dev/null" "GOTOOLCHAIN=local" "GOMAXPROCS=${GOMAXPROCS:-4}"
             "GIT_CONFIG_COUNT=2" "GIT_CONFIG_KEY_0=core.excludesFile" "GIT_CONFIG_VALUE_0=/dev/null" "GIT_CONFIG_KEY_1=core.attributesFile" "GIT_CONFIG_VALUE_1=/dev/null")
    for _zg_v in PATH HOME TMPDIR USER LOGNAME XDG_RUNTIME_DIR ZG_CLASS_BUDGET ZG_SWEEP_BUDGET ZG_IGNORED_EXCLUDE; do
        if [ -n "${!_zg_v+x}" ]; then _zg_env+=("$_zg_v=${!_zg_v}"); fi
    done
    shopt -s execfail 2>/dev/null
    exec env -i "${_zg_env[@]}" "$BASH" --norc --noprofile "${BASH_SOURCE[0]:-$0}" "$@"
    echo "zero-gap-sweep: COULD NOT DETERMINE — cannot re-execute under a clean environment" >&2
    exit 2
fi
unset ZG_SWEEP_REEXEC _zg_env _zg_v
set +o posix
export LC_ALL=C LANG=C GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GOTOOLCHAIN=local \
       GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null \
       GIT_CONFIG_KEY_1=core.attributesFile GIT_CONFIG_VALUE_1=/dev/null
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
HERE="$(dirname "$SELF")"
ROOT="$(cd "$HERE/.." && pwd)"
LIVE_ROOT="$ROOT"
PROVE=0 JSON=0 OUT="" EXPECT_FP=""
SEL=()
CLASS_BUDGET="${ZG_CLASS_BUDGET:-900}"
SWEEP_BUDGET="${ZG_SWEEP_BUDGET:-10800}"
IGN_EXCLUDE="${ZG_IGNORED_EXCLUDE-.remember/tmp/:.remember/logs/:.service-registry/qa/}"
REL_TSV="docs/zero-gap/sweep-classes.tsv"
HDR=$'class_id\tpopulation\tpopulation_why\twindow\tentrypoint\tcorpus\trecall\tpopulation_kind'
SEVERITIES=" critical high medium low "
CATEGORIES=" security data-integrity false-evidence content-boundary availability build-freshness governance-drift docs-drift test-coverage ux-accessibility host-capability other "
KINDS=" source process wire "
RESERVED=" sweep evidence registers "
FIXPFX="_tests/fixtures/zero-gap/"
FIXRE='(^|/|:)_tests/fixtures/zero-gap/'
BADSEQ=$'\xc2[\x80-\x9f]|\xe2\x80[\x8e\x8f\xa8-\xae]|\xe2\x81[\xa6-\xa9]|\xef\xbb\xbf|\xd8\x9c'
TOK='([A-Za-z0-9._~/+:@,=-]|%[0-9A-F]{2})+'
NONCANON='%(2[B-F]|3[0-9AD]|4[0-9A-F]|5[0-9AF]|6[1-9A-F]|7[0-9AE])'
RE_FIND="^FINDING ([a-z0-9]+(-[a-z0-9]+)*) ([a-z]+) ([a-z-]+) ($TOK) (.+) ($TOK)\$"
RE_CNI="^COULD-NOT-INSPECT ($TOK) (.+)\$"
RE_INSP='^INSPECTED ([0-9]+)$'
RE_PSHA='^POPULATION-SHA ([0-9a-f]{64})$'

usage() { sed -n '/^# ── Usage/,/^# ── Exit/p' "$SELF" | sed '$d' | sed 's/^# \{0,1\}//'; }
die2() { printf 'zero-gap-sweep: COULD NOT DETERMINE — %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
    case "$1" in
        --root) [ $# -ge 2 ] || die2 "--root needs a value"; ROOT=$2; shift 2 ;;
        --class) [ $# -ge 2 ] || die2 "--class needs a value"; SEL+=("$2"); shift 2 ;;
        --json) JSON=1; shift ;;
        --out) [ $# -ge 2 ] || die2 "--out needs a value"; OUT=$2; shift 2 ;;
        --expect-fingerprint) [ $# -ge 2 ] || die2 "--expect-fingerprint needs a value"; EXPECT_FP=$2; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'zero-gap-sweep: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

inset() { case "$2" in *" $1 "*) return 0 ;; esac; return 1; }
# canon <token> -> 0 when it is one canonical percent-encoded token
canon() { [[ $1 =~ ^$TOK$ ]] && ! [[ $1 =~ $NONCANON ]]; }
# pathok <token>: every ':'-separated segment is a normal relative path — no leading '/',
# no '.' or '..' segment, no '//', no empty segment
pathok() {
    local IFS=: seg
    case "$1" in ''|:*|*:|*::*) return 1 ;; esac
    for seg in $1; do
        case "$seg" in /*|./*|../*|*//*|*/./*|*/../*|*/.|*/..|.|..) return 1 ;; esac
    done
    return 0
}
# bad_bytes <file>: 0 when the file carries a NUL, is not valid UTF-8, or carries a C1
# control (U+0080-U+009F), a line/paragraph separator (U+2028/9), a direction mark,
# embedding, override or isolate (U+200E/F, U+061C, U+202A-E, U+2066-9) or a BOM (U+FEFF)
bad_bytes() {
    [ "$(tr -d '\000' <"$1" | wc -c)" -eq "$(wc -c <"$1")" ] || return 0
    iconv -f UTF-8 -t UTF-8 "$1" >/dev/null 2>&1 || return 0
    if LC_ALL=C grep -Eq "$BADSEQ" "$1"; then return 0; fi
    return 1
}
# refok <base> <token>: the token, or a prefix of it ending before a ':', names a REGULAR file
# whose real path is inside base, which is not inside a .git directory and does not match the
# corpus-fixture pattern (a directory, a symlink out of the tree, .git/config or a corpus file is refused)
declare -A REFOK=() BASERP=()
refok() {
    local base=$1 c=$2 d rp br
    br=${BASERP[$base]:-}
    if [ -z "$br" ]; then br=$(realpath -e -- "$base" 2>/dev/null) || return 1; BASERP[$base]=$br; fi
    while :; do
        if [ -n "${REFOK[$base$'\t'$c]:-}" ]; then return 0; fi
        printf -v d '%b' "${c//%/\\x}"
        if [ -f "$base/$d" ] && ! [[ $c =~ $FIXRE ]] && ! [[ $c =~ (^|/)\.git(/|$) ]]; then
            rp=$(realpath -e -- "$base/$d" 2>/dev/null) || rp=""
            case "$rp" in
                "$br"/*/.git/*|"$br"/.git/*) ;;
                "$br"/*) REFOK[$base$'\t'$c]=1; return 0 ;;
            esac
        fi
        case "$c" in *:*) c=${c%:*} ;; *) return 1 ;; esac
    done
}
# pid_st <pid> -> PST (start time, field 22) and PSTATE; rc 1 when the process is gone
pid_st() {
    local l; local -a f
    { read -r l <"/proc/$1/stat"; } 2>/dev/null || return 1
    read -ra f <<<"${l##*) }"
    PSTATE=${f[0]}; PST=${f[19]}
    return 0
}
# alive_as <pid> <starttime>: the SAME process (not a reused pid) is still running (zombies are not)
alive_as() { pid_st "$1" && [ "$PST" = "$2" ] && [ "$PSTATE" != Z ]; }
# kill_verified <pid> <starttime>: TERM, 2 s grace, KILL — each signal only after re-reading the start time
kill_verified() {
    local p=$1 st=$2 k
    alive_as "$p" "$st" || return 0
    kill -TERM "$p" 2>/dev/null
    for k in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        alive_as "$p" "$st" || return 0
        sleep 0.1
    done
    if alive_as "$p" "$st"; then kill -KILL "$p" 2>/dev/null; fi
    # wait (bounded) until it is really gone, so no later scan sees a dying process
    for k in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        alive_as "$p" "$st" || return 0
        sleep 0.1
    done
    return 0
}
# group_members <pgid>: live (non-zombie) pids whose process group is pgid. A bash loop, not awk
# over /proc/*/stat: gawk treats a vanished input file as FATAL and stops at the first process that
# exited after the glob was expanded, which silently hid group members under load (measured).
group_members() {
    local f l p; local -a x
    for f in /proc/[0-9]*/stat; do
        { read -r l <"$f"; } 2>/dev/null || continue
        read -ra x <<<"${l##*) }"
        if [ "${x[2]:-}" = "$1" ] && [ "${x[0]:-}" != Z ]; then p=${f#/proc/}; echo "${p%/stat}"; fi
    done
}
# end_escapees: freeze every pid still carrying this run's token (SIGSTOP), rescan until no new
# one appears (bounded), then KILL each frozen pid by verified start time and wait (bounded) for
# it to go. rc 0 when at least one was found.
end_escapees() {
    local r p k new
    local -A frz=()
    for r in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
        new=0
        for p in $(token_pids); do
            [ -z "${frz[$p]:-}" ] || continue
            if pid_st "$p" && [ "$PSTATE" != Z ]; then frz[$p]=$PST; kill -STOP "$p" 2>/dev/null; new=1; fi
        done
        [ "$new" -eq 1 ] || break
    done
    [ "${#frz[@]}" -gt 0 ] || return 1
    for p in "${!frz[@]}"; do if alive_as "$p" "${frz[$p]}"; then kill -KILL "$p" 2>/dev/null; fi; done
    for k in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        new=0
        for p in "${!frz[@]}"; do if alive_as "$p" "${frz[$p]}"; then new=1; fi; done
        [ "$new" -eq 1 ] || return 0
        sleep 0.1
    done
    return 0
}
# token_pids: pids of our uid that still carry this run's class token
token_pids() {
    local f p
    grep -lzxF -- "ZG_RUN=$ZG_TOKEN" /proc/[0-9]*/environ 2>/dev/null | while IFS= read -r f; do
        p=${f#/proc/}; p=${p%/environ}
        if [ "$p" != "$$" ] && [ -O "/proc/$p" ]; then echo "$p"; fi
    done
}

# >>> zg_pct_encode (feature 010 class contract; copy verbatim)
# zg_pct_encode_z: NUL-separated raw items on stdin -> one canonical token per line.
# Every byte outside A-Z a-z 0-9 . _ ~ / + : @ , = - becomes %XX (uppercase hex).
zg_pct_encode_z() {
    LC_ALL=C od -An -v -tx1 | LC_ALL=C awk '
        BEGIN { hx = "0123456789abcdef"; safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-"; tok = ""; pending = 0 }
        { for (i = 1; i <= NF; i++) {
              if ($i == "00") { print tok; tok = ""; pending = 0; continue }
              pending = 1
              v = (index(hx, substr($i, 1, 1)) - 1) * 16 + index(hx, substr($i, 2, 1)) - 1
              c = (v > 32 && v < 127) ? sprintf("%c", v) : ""
              if (c != "" && index(safe, c) > 0) tok = tok c; else tok = tok "%" toupper($i)
          } }
        END { if (pending) print tok }'
}
# zg_pct_encode <string>: one item -> one canonical token.
zg_pct_encode() { printf '%s\0' "$1" | zg_pct_encode_z; }
# <<< zg_pct_encode

# ── TSV loading (every defect => rc 2; the class list is DATA, so it is validated) ──
C_ID=(); C_ENTRY=(); C_CORPUS=(); C_RECALL=(); C_KIND=(); C_LINE=()
load_tsv() {
    local tsv="$ROOT/$REL_TSV" line lineno=0 seen=0 tabs rest k id pop why win entry corpus recall kind
    local -A dup=()
    local -a f
    [ -f "$tsv" ] || die2 "no class list at $REL_TSV"
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        case "$line" in ''|'#'*) continue ;; esac
        case "$line" in *$'\r'*) die2 "$REL_TSV:$lineno carries a CR" ;; esac
        if [ "$seen" -eq 0 ]; then
            [ "$line" = "$HDR" ] || die2 "$REL_TSV:$lineno: the header must be exactly: ${HDR//$'\t'/<TAB>}"
            seen=1; continue
        fi
        tabs=${line//[!$'\t']/}
        [ "${#tabs}" -eq 7 ] || die2 "$REL_TSV:$lineno: expected 8 tab-separated fields, found $(( ${#tabs} + 1 ))"
        f=(); rest=$line
        for k in 1 2 3 4 5 6 7; do f+=("${rest%%$'\t'*}"); rest=${rest#*$'\t'}; done
        f+=("$rest")
        id=${f[0]} pop=${f[1]} why=${f[2]} win=${f[3]} entry=${f[4]} corpus=${f[5]} recall=${f[6]} kind=${f[7]}
        [[ $id =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die2 "$REL_TSV:$lineno: class_id '$id' is not [a-z0-9] words joined by '-'"
        ! inset "$id" "$RESERVED" || die2 "$REL_TSV:$lineno: class_id '$id' is reserved (${RESERVED# })"
        [ -z "${dup[$id]:-}" ] || die2 "$REL_TSV:$lineno: duplicate class_id '$id' (first at line ${dup[$id]})"
        dup[$id]=$lineno
        [ -n "${pop// /}" ] || die2 "$REL_TSV:$lineno: empty population"
        [ -n "${why// /}" ] || die2 "$REL_TSV:$lineno: empty population_why (a population must say why it is the right set)"
        [ -n "${win// /}" ] || die2 "$REL_TSV:$lineno: empty window (write 'none' when unbounded)"
        [ -n "$entry" ] || die2 "$REL_TSV:$lineno: missing entrypoint"
        [ "$entry" = "scripts/zero-gap-class-$id.sh" ] || die2 "$REL_TSV:$lineno: entrypoint must be scripts/zero-gap-class-$id.sh, got '$entry'"
        [ "$corpus" = "$FIXPFX$id/" ] || die2 "$REL_TSV:$lineno: corpus must be $FIXPFX$id/, got '$corpus'"
        [ "$recall" = UNKNOWN ] || [[ $recall =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] || die2 "$REL_TSV:$lineno: recall '$recall' is neither UNKNOWN nor a number in 0..1"
        inset "$kind" "$KINDS" || die2 "$REL_TSV:$lineno: population_kind '$kind' is not one of source|process|wire"
        C_ID+=("$id"); C_ENTRY+=("$entry"); C_CORPUS+=("$corpus"); C_RECALL+=("$recall"); C_KIND+=("$kind"); C_LINE+=("$lineno")
    done <"$tsv"
    [ "$seen" -eq 1 ] || die2 "$REL_TSV has no header line"
    [ "${#C_ID[@]}" -gt 0 ] || die2 "$REL_TSV lists no class: a sweep of nothing is not a clean sweep"
}

# ── accumulators (all in $W, all TSV, sorted only at the end) ──
add_finding() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$4" "$2" "$3" "$5" "$6" >>"$W/findings"; } # id sev cat loc desc ref
add_cni() { printf '%s\t%s\n' "$1" "$2" >>"$W/cni"; }                                          # part reason
now_ms() { NOW=${EPOCHREALTIME/./}; NOW=$((10#$NOW / 1000)); }

# kill_group <pgid> <leader starttime>: signal the group only when it is verifiably ours — its
# leader is still the process we started, or a member carries this run's token. A pgid stays
# reserved while the group has members, so a verified group cannot be a stranger's.
kill_group() {
    local g=$1 lst=$2 k m ok=0
    m=$(group_members "$g")
    [ -n "$m" ] || return 0
    if [ -n "$lst" ] && alive_as "$g" "$lst"; then ok=1
    else
        for k in $m; do
            if grep -qzxF -- "ZG_RUN=$ZG_TOKEN" "/proc/$k/environ" 2>/dev/null; then ok=1; break; fi
        done
    fi
    if [ "$ok" -eq 0 ]; then INV_UNVER=1; return 0; fi
    kill -TERM -- "-$g" 2>/dev/null || return 0
    for k in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        [ -n "$(group_members "$g")" ] || return 0
        sleep 0.1
    done
    kill -STOP -- "-$g" 2>/dev/null || true
    kill -KILL -- "-$g" 2>/dev/null || true
    # wait (bounded) until no live member remains, so the escaped-process scan that follows
    # never mistakes a member that is still dying for one that escaped (a determinism fix)
    for k in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        [ -n "$(group_members "$g")" ] || return 0
        sleep 0.1
    done
}

# invoke <entry> <stdout> <stderr> <args...> -> rc of the class; INV_WHY set to
# '' | class-budget | sweep-budget | leftover; INV_ESC=1 when a process carrying
# ZG_RUN outlived the invocation outside its group; INV_UNVER=1 when a group could
# not be verified as ours and was therefore not signalled. The class runs in a new
# session (setsid => pgid == its pid; job control is off after the re-exec, so setsid
# never forks), polled against the nearer of the class and sweep deadlines.
invoke() {
    local entry=$1 out=$2 err=$3 pid rc=0 dl why=class-budget lst="" p
    shift 3
    INV_WHY=""; INV_ESC=0; INV_UNVER=0
    dl=$CLASS_DEADLINE
    if [ "$SWEEP_DEADLINE" -lt "$dl" ]; then dl=$SWEEP_DEADLINE; why=sweep-budget; fi
    now_ms
    if [ "$NOW" -ge "$dl" ]; then INV_WHY=$why; : >"$out"; : >"$err"; return 124; fi
    ( cd "$ROOT" && exec env -i "${CLASS_ENV[@]}" setsid bash --norc --noprofile "$ROOT/$entry" "$@" ) </dev/null >"$out" 2>"$err" &
    pid=$!
    if pid_st "$pid"; then lst=$PST; fi
    while [ -n "$lst" ] && alive_as "$pid" "$lst"; do
        now_ms
        if [ "$NOW" -ge "$dl" ]; then INV_WHY=$why; kill_group "$pid" "$lst"; break; fi
        sleep 0.1
    done
    wait "$pid" 2>/dev/null || rc=$?
    if [ -z "$INV_WHY" ] && [ -n "$(group_members "$pid")" ]; then INV_WHY=leftover; kill_group "$pid" ""; fi
    if end_escapees; then INV_ESC=1; fi
    if [ "$INV_WHY" = class-budget ] || [ "$INV_WHY" = sweep-budget ]; then return 124; fi
    return "$rc"
}

# parse_output <file> <class_id> <base dir for evidence_ref> -> $W/p.find (loc sev cat desc ref),
# $W/p.cni, P_INSP (-1 absent), P_PSHA ('' absent), P_BAD, P_UTF8 (1 = forbidden bytes), P_NF, P_NC
parse_output() {
    local l n=0 fdf fdc
    local -a m
    : >"$W/p.find"; : >"$W/p.cni"
    P_INSP=-1; P_PSHA=""; P_BAD=""; P_UTF8=0; P_NF=0; P_NC=0
    if bad_bytes "$1"; then P_UTF8=1; return 0; fi
    exec {fdf}>>"$W/p.find" {fdc}>>"$W/p.cni"
    while IFS= read -r l || [ -n "$l" ]; do
        n=$((n + 1))
        [ -n "$l" ] || continue
        case "$l" in *[[:cntrl:]]*) P_BAD+=" $n"; continue ;; esac
        if [[ $l =~ $RE_FIND ]]; then
            m=("${BASH_REMATCH[@]}")
            if [ "${m[1]}" != "$2" ] || ! inset "${m[3]}" "$SEVERITIES" || ! inset "${m[4]}" "$CATEGORIES" \
               || ! canon "${m[5]}" || ! canon "${m[8]}" || ! pathok "${m[5]}" || ! pathok "${m[8]}" || ! refok "$3" "${m[8]}"; then
                P_BAD+=" $n"; continue
            fi
            printf '%s\t%s\t%s\t%s\t%s\n' "${m[5]}" "${m[3]}" "${m[4]}" "${m[7]}" "${m[8]}" >&$fdf
            P_NF=$((P_NF + 1))
        elif [[ $l =~ $RE_CNI ]]; then
            m=("${BASH_REMATCH[@]}")
            if ! canon "${m[1]}" || ! pathok "${m[1]}"; then P_BAD+=" $n"; continue; fi
            printf '%s\t%s\n' "${m[1]}" "${m[3]}" >&$fdc
            P_NC=$((P_NC + 1))
        elif [[ $l =~ $RE_INSP ]]; then
            if [ "$P_INSP" -ne -1 ]; then P_BAD+=" $n"; continue; fi
            P_INSP=$((10#${BASH_REMATCH[1]}))
        elif [[ $l =~ $RE_PSHA ]]; then
            if [ -n "$P_PSHA" ]; then P_BAD+=" $n"; continue; fi
            P_PSHA=${BASH_REMATCH[1]}
        else
            P_BAD+=" $n"
        fi
    done <"$1"
    exec {fdf}>&- {fdc}>&-
}

# contract_problems <rc> -> prints one reason per violated rule of the exit/output agreement
contract_problems() {
    local rc=$1 bad
    case "$INV_WHY" in
        class-budget) echo "class exceeded its class budget of ${CLASS_BUDGET}s (ZG_CLASS_BUDGET); its process group was terminated"; return 0 ;;
        sweep-budget) echo "the sweep budget of ${SWEEP_BUDGET}s (ZG_SWEEP_BUDGET) ran out; the class process group was terminated"; return 0 ;;
        leftover) echo "class exited but left processes running in its group; they were terminated" ;;
    esac
    if [ "$INV_ESC" -eq 1 ]; then echo "a process carrying this run's class token outlived the class outside its process group (escaped, e.g. via setsid); it was terminated by verified pid"; fi
    if [ "$INV_UNVER" -eq 1 ]; then echo "processes remained in the class process group that could not be verified as this run's; they were NOT signalled"; fi
    if [ "$P_UTF8" -eq 1 ]; then echo "class output violates the class output contract: it carries a NUL, invalid UTF-8, a C1 control, or an invisible direction/line character"; return 0; fi
    case "$rc" in
        0|1|2) ;;
        *) echo "class exited $rc (the contract allows only 0, 1, 2)" ;;
    esac
    if [ -n "$P_BAD" ]; then
        bad=$(printf '%s\n' $P_BAD | head -n 10 | tr '\n' ' ')
        echo "class output violates the class output contract at line(s) ${bad% }"
    fi
    if [ "$rc" -eq 0 ] && [ "$P_NF" -gt 0 ]; then echo "class exited 0 but reported $P_NF finding(s)"; fi
    if [ "$rc" -eq 1 ] && [ "$P_NF" -eq 0 ]; then echo "class exited 1 but reported no finding"; fi
    if [ "$rc" -eq 2 ] && [ "$P_NC" -eq 0 ]; then echo "class exited 2 without naming what it could not inspect"; fi
    if [ "$P_INSP" -eq -1 ]; then echo "class did not report INSPECTED <n>"; fi
    if [ -z "$P_PSHA" ]; then echo "class did not report POPULATION-SHA <sha256>"; fi
    return 0
}

fmt_recall() { awk -v h="$1" -v n="$2" 'BEGIN{ r = h / n; if (r == 1) { print "1.0" } else if (r == 0) { print "0.0" } else { s = sprintf("%.4f", r); sub(/0+$/, "", s); print s } }'; }
num_differs() { awk -v a="$1" -v b="$2" 'BEGIN{ d = a - b; exit !(d > 1e-9 || d < -1e-9) }'; }
sanitize() { LC_ALL=C tr -d '\000-\010\013-\037\177' | LC_ALL=C sed -E "s/$BADSEQ//g"; }

# ── state fingerprint: zg_manifest + git state + file metadata ──
# state_manifest <file> -> 0 ok (STATE_FILES = zg_manifest entries) | 2
state_manifest() {
    local out=$1 h gd sub
    zg_manifest "$ROOT" >"$out.z" 2>"$out.e" || return 2
    STATE_FILES=$(awk 'END{print NR}' "$out.z")
    {
        cat "$out.z"
        h=$(git -C "$ROOT" rev-parse -q --verify HEAD 2>/dev/null) || h=none
        printf '@git:HEAD\t%s\n' "$h"
        printf '@git:refs\t%s\n' "$(git -C "$ROOT" for-each-ref --format='%(refname) %(objectname)' 2>&1 | sha256sum | cut -d' ' -f1)"
        printf '@git:config\t%s\n' "$(git -C "$ROOT" config --local --list 2>&1 | sha256sum | cut -d' ' -f1)"
        printf '@git:index\t%s\n' "$(git -C "$ROOT" ls-files -s -z 2>&1 | sha256sum | cut -d' ' -f1)"
        gd=$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null) || gd=""
        for sub in hooks info; do
            if [ -n "$gd" ] && [ -d "$gd/$sub" ]; then
                printf '@git:%s\t%s\n' "$sub" "$( cd "$gd/$sub" && { find . \( -type f -o -type l \) -printf '%p %m %l\n' | LC_ALL=C sort; find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum; } | sha256sum | cut -d' ' -f1 )"
            else
                printf '@git:%s\tabsent\n' "$sub"
            fi
        done
        git -C "$ROOT" ls-files -z --cached --others --exclude-standard 2>/dev/null \
            | ( cd "$ROOT" && xargs -0 -r stat --printf '@mtime:%n\t%y %z %s %i\n' 2>/dev/null )
    } | LC_ALL=C sort -u >"$out"
    rm -f "$out.z" "$out.e"
    return 0
}

# ign_snapshot <out> — one line "<path>\t<ctime> <size> <inode>" for EVERY ignored FILE (git status
# --ignored --untracked-files=all lists them individually), minus paths equal to or under a
# ZG_IGNORED_EXCLUDE prefix. Diffing two snapshots shows ignored files created, removed, written, or
# replaced by `cp -p` that keeps an old mtime (ctime moves). Symmetric by construction: both sides
# stat the full list, so a directory that merely starts to be listed cannot look changed (the defect of
# the round-3 draft, which scanned only entries listed at each moment). Empty directories are not files
# and are not seen (stated limit).
ign_snapshot() {
    ( cd "$ROOT" && git --no-optional-locks status --ignored --untracked-files=all --porcelain -z --ignore-submodules=all 2>/dev/null ) \
        | tr '\0' '\n' | sed -n 's/^!! //p' \
        | awk -v ex="$IGN_EXCLUDE" 'BEGIN { n = split(ex, p, ":") }
            { for (i = 1; i <= n; i++) { e = p[i]; if (e == "") continue; f = e; sub(/\/$/, "", f)
                  if ($0 == f || index($0, e) == 1) next }
              print }' >"$W/ign.files"
    if [ -s "$W/ign.files" ]; then
        ( cd "$ROOT" && xargs -d '\n' -r -a "$W/ign.files" stat --printf '%n\t%z %s %i\n' 2>/dev/null ) | LC_ALL=C sort >"$1"
    else
        : >"$1"
    fi
}

# window_open / window_close <id>: fingerprint around one class (all of its runs)
window_open() {
    local s; now_ms; WIN_T0=$NOW; s=${EPOCHREALTIME%.*}
    touch -d "@$((s - 2))" "$W/mark"
    ign_snapshot "$W/ign.before"
}
window_close() {
    local id=$1 p rest ms
    if state_manifest "$W/state.new"; then
        if ! cmp -s "$W/state.cur" "$W/state.new"; then
            UNSTABLE=1
            LC_ALL=C comm -3 "$W/state.cur" "$W/state.new" | sed 's/^\t//' | cut -f1 | LC_ALL=C sort -u >"$W/moved"
            while IFS= read -r p; do
                add_cni "$id:$(zg_pct_encode "$p")" "changed while this class ran (UNSTABLE: the class or a concurrent editor moved the tree; no verdict about this state is valid)"
            done <"$W/moved"
        fi
        mv -f "$W/state.new" "$W/state.cur"; FILES1=$STATE_FILES
    else
        add_cni "$id:-" "state fingerprint could not be taken after this class ran"; FP_FAIL=1
    fi
    if [ "$id" != sweep ]; then
        ign_snapshot "$W/ign.after"
        LC_ALL=C comm -3 "$W/ign.before" "$W/ign.after" | sed 's/^\t//' | cut -f1 | LC_ALL=C sort -u | while IFS= read -r p; do
            add_cni "$id:$(zg_pct_encode "$p")" "written while this class ran (created, changed or removed; an IGNORED path, outside the fingerprint; ZG_IGNORED_EXCLUDE is only for paths owned by concurrent host tooling)"
        done
    fi
    now_ms; ms=$((NOW - WIN_T0))
    printf 'zero-gap-sweep: class %s: fingerprint window %s ms\n' "$id" "$ms" >&2
}

# recall_for <index> -> RECALL (numeric string or UNKNOWN); findings/cni appended
recall_for() {
    local i=$1 id=${C_ID[$1]} entry=${C_ENTRY[$1]} corpus=${C_CORPUS[$1]} pub=${C_RECALL[$1]} tl=${C_LINE[$1]}
    local cdir="$ROOT/${C_CORPUS[$1]}" l loc note np=0 hits=0 prc crc probs missing="" where kind
    local -A exp=()
    RECALL=UNKNOWN
    [ -e "$ROOT/${corpus%/}" ] || return 0
    [ -d "$cdir/planted" ] || missing+=" planted/"
    [ -d "$cdir/clean" ] || missing+=" clean/"
    [ -f "$cdir/expect.tsv" ] || missing+=" expect.tsv"
    if [ -n "$missing" ]; then add_cni "$id:$corpus" "corpus malformed: missing${missing}"; return 0; fi
    if bad_bytes "$cdir/expect.tsv"; then add_cni "$id:${corpus}expect.tsv" "corpus malformed: expect.tsv carries a NUL, invalid UTF-8 or a forbidden character"; return 0; fi
    : >"$W/exp"
    while IFS= read -r l || [ -n "$l" ]; do
        case "$l" in ''|'#'*) continue ;; esac
        loc=${l%%$'\t'*}
        if [ "$loc" = "$l" ]; then note="planted defect"; else note=${l#*$'\t'}; note=${note//$'\t'/ }; fi
        case "$note" in *[[:cntrl:]]*) add_cni "$id:${corpus}expect.tsv" "corpus malformed: a note carries a control character"; return 0 ;; esac
        if ! canon "$loc" || ! pathok "$loc"; then add_cni "$id:${corpus}expect.tsv" "corpus malformed: a location is not one canonical percent-encoded token"; return 0; fi
        if [ -n "${exp[$loc]:-}" ]; then add_cni "$id:${corpus}expect.tsv" "corpus malformed: location $loc planted twice"; return 0; fi
        exp[$loc]=1; np=$((np + 1))
        printf '%s\t%s\n' "$loc" "$note" >>"$W/exp"
    done <"$cdir/expect.tsv"
    if [ "$np" -eq 0 ]; then add_cni "$id:${corpus}expect.tsv" "corpus plants nothing: recall over zero planted defects is undefined"; return 0; fi

    for kind in planted clean; do
        prc=0; invoke "$entry" "$W/c.out" "$W/c.err" --root "$ROOT" --corpus "$cdir/$kind" || prc=$?
        if [ -s "$W/c.err" ]; then sanitize <"$W/c.err" | sed "s/^/[class $id $kind] /" >&2; fi
        parse_output "$W/c.out" "$id" "$cdir/$kind"
        probs=$(contract_problems "$prc")
        if [ "$prc" -eq 2 ] && [ -z "$INV_WHY" ]; then probs+=$'\n'"class could not determine on its $kind corpus"; fi
        if [ -n "${probs//$'\n'/}" ]; then
            while IFS= read -r l; do [ -n "$l" ] && add_cni "$id:${corpus}$kind/" "recall not measured: $l"; done <<<"$probs"
            return 0
        fi
        cp "$W/p.find" "$W/$kind.find"
    done
    where="scripts/zero-gap-class-$id.sh"
    cut -f1 "$W/planted.find" | LC_ALL=C sort -u >"$W/found"
    while IFS=$'\t' read -r loc note; do
        if grep -qxF -- "$loc" "$W/found"; then hits=$((hits + 1))
        else add_finding "$id" high false-evidence "$where" "RECALL-MISS: planted defect ${corpus}planted/$loc not reported by the class ($note)" "${corpus}expect.tsv"; fi
    done <"$W/exp"
    while IFS= read -r loc; do
        [ -n "$loc" ] || continue
        [ -n "${exp[$loc]:-}" ] || add_finding "$id" medium false-evidence "$where" "RECALL-UNEXPECTED: finding on ${corpus}planted/$loc, which expect.tsv does not plant" "${corpus}expect.tsv"
    done <"$W/found"
    while IFS=$'\t' read -r loc _ _ note _; do
        [ -n "$loc" ] || continue
        add_finding "$id" high false-evidence "$where" "RECALL-FALSE-POSITIVE: finding on the clean control ${corpus}clean/$loc: $note" "${corpus}clean/"
    done <"$W/clean.find"
    RECALL=$(fmt_recall "$hits" "$np")
    if [ "$pub" != UNKNOWN ] && num_differs "$pub" "$RECALL"; then
        add_finding "$id" medium docs-drift "$where" "RECALL-MISMATCH: published recall $pub at $REL_TSV:$tl differs from the measured $RECALL" "$REL_TSV:$tl"
    fi
    return 0
}

# in_population <location>: the location, or a prefix of it ending before a ':', is a population item
in_population() {
    local c=$1
    while :; do
        if [ -n "${POPSET[$c]:-}" ] || [ -n "${TRACKED[$c]:-}" ]; then return 0; fi
        case "$c" in *:*) c=${c%:*} ;; *) return 1 ;; esac
    done
}

# run_class <index> -> appends one line to $W/classes (id pop insp recall kind status)
declare -A POPSET=() TRACKED=()
run_class() {
    local i=$1 id=${C_ID[$1]} entry=${C_ENTRY[$1]} pop=0 insp=0 prc=0 lrc=0 l probs popok=0 nf nc status sev cat desc ref dropped=0 first
    RECALL=UNKNOWN
    if [ ! -f "$ROOT/$entry" ]; then
        add_cni "$id:-" "class not implemented: $entry is absent (listed, never run, never clean)"
        printf '%s\t0\t0\tUNKNOWN\t%s\tnot-implemented\n' "$id" "${C_KIND[$i]}" >>"$W/classes"
        return 0
    fi
    now_ms
    if [ "$NOW" -ge "$SWEEP_DEADLINE" ]; then
        add_cni "$id:-" "not run: the sweep budget of ${SWEEP_BUDGET}s (ZG_SWEEP_BUDGET) ran out"
        printf '%s\t0\t0\tUNKNOWN\t%s\tcould-not-inspect\n' "$id" "${C_KIND[$i]}" >>"$W/classes"
        return 0
    fi
    CLASS_DEADLINE=$((NOW + CLASS_BUDGET * 1000))
    RAN=1
    window_open
    POPSET=()
    invoke "$entry" "$W/pop.out" "$W/pop.err" --root "$ROOT" --emit-population || prc=$?
    if [ -n "$INV_WHY" ] && [ "$INV_WHY" != leftover ]; then
        add_cni "$id:-" "$(contract_problems "$prc")"
    else
        if [ "$INV_WHY" = leftover ]; then add_cni "$id:-" "--emit-population exited but left processes running in its group; they were terminated"; fi
        if [ "$INV_ESC" -eq 1 ]; then add_cni "$id:-" "a process started by --emit-population outlived it outside its process group (escaped, e.g. via setsid); it was terminated by verified pid"; fi
        if [ "$INV_UNVER" -eq 1 ]; then add_cni "$id:-" "processes remained in the --emit-population process group that could not be verified as this run's; they were NOT signalled"; fi
        if [ "$prc" -ne 0 ]; then add_cni "$id:-" "population could not be enumerated (--emit-population exited $prc)"
        elif bad_bytes "$W/pop.out" || LC_ALL=C grep -Evxq "$TOK" "$W/pop.out" || LC_ALL=C grep -Eq "$NONCANON" "$W/pop.out" \
             || LC_ALL=C grep -Eq '(^|:)(/|\.\.?(/|:|$))|//|/\.\.?(/|:|$)|::|:$|^:' "$W/pop.out"; then
            add_cni "$id:-" "population output violates the contract: every item must be one canonical percent-encoded, normal relative path token per line (no ./, ../, //, absolute path or empty segment)"
        elif ! LC_ALL=C sort -u "$W/pop.out" | cmp -s - "$W/pop.out"; then
            add_cni "$id:-" "population output is not sorted and unique under LC_ALL=C (a nondeterministic enumeration)"
        elif first=$(LC_ALL=C grep -m1 -E -- "$FIXRE" "$W/pop.out") && [ -n "$first" ]; then
            add_cni "$id:$first" "the live population reaches corpus fixtures under $FIXPFX (they must be excluded: they are deliberately defective)"
        else
            pop=$(awk 'END{print NR}' "$W/pop.out"); popok=1
            if [ "$pop" -eq 0 ]; then add_cni "$id:-" "population enumerated to zero items: a class that inspects nothing is never clean"; popok=0; fi
            while IFS= read -r l; do POPSET[$l]=1; done <"$W/pop.out"
        fi
    fi
    if [ -z "$INV_WHY" ] || [ "$INV_WHY" = leftover ]; then
        invoke "$entry" "$W/live.out" "$W/live.err" --root "$ROOT" || lrc=$?
        if [ -s "$W/live.err" ]; then sanitize <"$W/live.err" | sed "s/^/[class $id] /" >&2; fi
        parse_output "$W/live.out" "$id" "$ROOT"
        probs=$(contract_problems "$lrc")
        while IFS= read -r l; do [ -n "$l" ] && add_cni "$id:-" "$l"; done <<<"$probs"
        while IFS=$'\t' read -r l sev cat desc ref; do
            [ -n "$l" ] || continue
            if [ "$popok" -eq 1 ] && ! [[ $l =~ $FIXRE ]] && in_population "$l"; then
                add_finding "$id" "$sev" "$cat" "$l" "$desc" "$ref"
            else
                dropped=$((dropped + 1))
                if [ "$dropped" -eq 1 ]; then first=$l; fi
            fi
        done <"$W/p.find"
        if [ "$dropped" -gt 0 ]; then
            add_cni "$id:-" "$dropped FINDING line(s) not accepted: the location is neither a validated population item nor a path tracked at --root (nor either followed by :suffix), or it reaches a corpus fixture, or the population itself was invalid"
        fi
        while IFS=$'\t' read -r l desc; do
            [ -n "$l" ] && add_cni "$id:$l" "$desc"
        done <"$W/p.cni"
        if [ "$P_INSP" -ge 0 ]; then insp=$P_INSP; fi
        if [ "$popok" -eq 1 ] && [ "$P_INSP" -ge 0 ] && [ "$insp" -ne "$pop" ]; then
            add_cni "$id:-" "inspected $insp of $pop population items"
        fi
        if [ "$popok" -eq 1 ] && [ -n "$P_PSHA" ] && [ "$P_PSHA" != "$(sha256sum <"$W/pop.out" | cut -d' ' -f1)" ]; then
            add_cni "$id:-" "the live run walked a different population than --emit-population printed (POPULATION-SHA differs)"
        fi
        if [ -z "$INV_WHY" ] || [ "$INV_WHY" = leftover ]; then recall_for "$i"; fi
    fi
    window_close "$id"
    nf=$(awk -F'\t' -v c="$id" '$1 == c' "$W/findings" | awk 'END{print NR}')
    nc=$(awk -F'\t' -v c="$id" 'index($1, c ":") == 1' "$W/cni" | awk 'END{print NR}')
    if [ "$nf" -gt 0 ]; then status=findings
    elif [ "$nc" -gt 0 ]; then status=could-not-inspect
    elif [ "$RECALL" = UNKNOWN ]; then status=unproven
    else status=clean; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$pop" "$insp" "$RECALL" "${C_KIND[$i]}" "$status" >>"$W/classes"
}

jsonq() { awk 'BEGIN{ORS=""} { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); print "\"" $0 "\"" }' <<<"$1"; }

prove_failure() (
    local T FIX LIB pass=0 fail=0 R RC b i sums fp st0 st1 strc=0 rc t0 pid ref
    for b in git sha256sum mktemp sort cmp sed awk grep timeout realpath find cp python3 setsid iconv stat; do
        if ! command -v "$b" >/dev/null 2>&1; then echo "prove-failure: cannot determine — '$b' missing" >&2; exit 2; fi
    done
    FIX="$LIVE_ROOT/_tests/fixtures/zero-gap/sweep"
    for b in demo-class.sh corpus/expect.tsv corpus/planted corpus/clean golden/control.txt; do
        if [ ! -e "$FIX/$b" ]; then echo "prove-failure: cannot determine — fixture '$b' absent under _tests/fixtures/zero-gap/sweep" >&2; exit 2; fi
    done
    LIB="$HERE/zero-gap-lib.sh"
    # shellcheck source=zero-gap-lib.sh
    . "$LIB" || { echo "prove-failure: cannot determine — library unreadable" >&2; exit 2; }
    T=$(mktemp -d) || exit 2
    trap 'rm -rf "$T"' EXIT
    mkdir -p "$T/tmp"
    ok()  { pass=$((pass + 1)); echo "  PASS $1"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
    HDR=$'class_id\tpopulation\tpopulation_why\twindow\tentrypoint\tcorpus\trecall\tpopulation_kind'
    row() { # <id> [recall] [kind] [entrypoint] [corpus]
        local id=$1 r=${2:-UNKNOWN} k=${3:-source}
        local e=${4-scripts/zero-gap-class-$id.sh} c=${5-_tests/fixtures/zero-gap/$id/}
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "demo population of $id" "fixture-only demonstration class" none "$e" "$c" "$r" "$k"
    }
    mkroot() { # <dir> — base throwaway repository, no classes yet
        rm -rf "$1"; mkdir -p "$1/notes" "$1/docs/zero-gap" "$1/scripts" "$1/_tests/fixtures/zero-gap"
        printf '.remember/\n_site/\n.service-registry/\n' >"$1/.gitignore"
        printf 'a clean note\n' >"$1/notes/ok.txt"
        mkdir -p "$1/.remember/tmp" "$1/.remember/logs" "$1/.service-registry/qa" "$1/_site"
        printf '<html>built page</html>\n' >"$1/_site/index.html"
        printf '# a clean readme\n' >"$1/notes/readme.md"
        ( cd "$1" && git init -q ) >/dev/null 2>&1
    }
    addclass() { # <dir> <mode> [nocorpus]
        cp "$FIX/demo-class.sh" "$1/scripts/zero-gap-class-$2.sh" && chmod +x "$1/scripts/zero-gap-class-$2.sh"
        if [ "${3:-}" != nocorpus ]; then cp -R "$FIX/corpus" "$1/_tests/fixtures/zero-gap/$2"; fi
    }
    settsv() { # <dir> <rows...>
        local d=$1; shift
        { printf '%s\n' "$HDR"; if [ "$#" -gt 0 ]; then printf '%s' "$@"; fi; } >"$d/docs/zero-gap/sweep-classes.tsv"
    }
    commit() { ( cd "$1" && git add . && git -c user.name=t -c user.email=t@t commit -qm fixture ) >/dev/null 2>&1; }
    run() { # <root> [args...] -> $T/out $T/err, RC   (caller environment passes through)
        local r=$1; shift
        RC=0; TMPDIR="$T/tmp" bash "$SELF" --root "$r" "$@" >"$T/out" 2>"$T/err" || RC=$?
    }
    runenv() { # <VAR=value>... -- <root> [args...]  (hostile environment for the runner)
        local -a e=()
        while [ "$1" != -- ]; do e+=("$1"); shift; done; shift
        local r=$1; shift
        RC=0; env TMPDIR="$T/tmp" "${e[@]}" bash "$SELF" --root "$r" "$@" >"$T/out" 2>"$T/err" || RC=$?
    }
    has() { grep -qF -- "$1" "$T/out"; }
    sess_members() { # <sid>: live pids whose session id is <sid>
        local f l p; local -a x
        for f in /proc/[0-9]*/stat; do
            { read -r l <"$f"; } 2>/dev/null || continue
            read -ra x <<<"${l##*) }"
            if [ "${x[3]:-}" = "$1" ] && [ "${x[0]:-}" != Z ]; then p=${f#/proc/}; echo "${p%/stat}"; fi
        done
    }
    running() { # <pid>: exists and is not a zombie (a killed orphan may linger as Z until its new parent reaps it)
        local l; { read -r l <"/proc/$1/stat"; } 2>/dev/null || return 1
        l=${l##*) }; [ "${l%% *}" != Z ]
    }
    jsonok() { python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$1" 2>/dev/null; }
    std() { mkroot "$1"; addclass "$1" demo; settsv "$1" "$(row demo)"$'\n'; commit "$1"; }
    one() { mkroot "$1"; addclass "$1" "$2" ${3:-}; settsv "$1" "$(row "$2")"$'\n'; commit "$1"; }

    body() {
    echo "C0 control: demo class, planted corpus found, clean control clean"
    R=$T/c0; std "$R"; run "$R"
    if [ "$RC" -eq 0 ]; then ok "C0a control rc 0"; else bad "C0a control rc=$RC ($(head -c 300 "$T/out" "$T/err" | tr '\n' ' '))"; fi
    if sed -E 's/(before|after)=[0-9a-f]{64}/\1=<sha256>/' "$T/out" | cmp -s - "$FIX/golden/control.txt"; then ok "C0b output equals golden/control.txt (sha masked)"; else bad "C0b output differs from golden"; fi
    fp=$(zg_fingerprint "$R" | sed -n 's/.* files=\([0-9]*\) .*/\1/p')
    if [ -n "$fp" ] && grep -q "^FINGERPRINT before=[0-9a-f]\{64\} files=$fp\$" "$T/out" && grep -q "^FINGERPRINT after=[0-9a-f]\{64\} files=$fp\$" "$T/out"; then ok "C0c files= equals the zg_manifest population count"; else bad "C0c files= mismatch (lib says $fp)"; fi
    cp "$T/out" "$T/c0.ref"

    echo "C1 determinism: 5 runs on an unchanged state are byte-identical"
    sums=0
    for i in 1 2 3 4 5; do run "$R"; if cmp -s "$T/out" "$T/c0.ref"; then sums=$((sums + 1)); fi; done
    if [ "$sums" -eq 5 ]; then ok "C1 5/5 runs cmp-identical"; else bad "C1 only $sums/5 identical"; fi

    echo "M1 empty class list"
    R=$T/m1; mkroot "$R"; settsv "$R"; commit "$R"; run "$R"
    if [ "$RC" -eq 2 ]; then ok "M1 empty class list => rc 2"; else bad "M1 rc=$RC"; fi

    echo "M2 missing entrypoint"
    R=$T/m2; mkroot "$R"; settsv "$R" "$(row ghost)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 2 ] && has "COULD-NOT-INSPECT ghost:- class not implemented" && grep -q '^CLASS ghost .*status=not-implemented' "$T/out"; then ok "M2 missing entrypoint => COULD-NOT-INSPECT, rc 2"; else bad "M2 rc=$RC"; fi

    echo "M3 moving tree during a class"
    R=$T/m3; one "$R" mover; run "$R"
    if [ "$RC" -eq 2 ] && has "VERDICT UNSTABLE" && has "COULD-NOT-INSPECT mover:" && has "mover-was-here.txt"; then ok "M3 moving tree => UNSTABLE rc 2 naming the class and the path"; else bad "M3 rc=$RC"; fi

    echo "M4 zero-population class"
    R=$T/m4; one "$R" zeropop nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "zero items" && ! grep -q 'status=clean' "$T/out"; then ok "M4a zero population => COULD-NOT-INSPECT, never clean"; else bad "M4a rc=$RC"; fi
    R=$T/m4b; one "$R" zeropop; run "$R"
    if [ "$RC" -eq 1 ] && has "zero items" && grep -q '^CLASS zeropop .*recall=0.0 ' "$T/out"; then ok "M4b zero population with a corpus => recall 0.0, misses outrank"; else bad "M4b rc=$RC"; fi

    echo "M5 nondeterministic class is detected by the repeat check"
    R=$T/m5; one "$R" nondet
    : >"$T/sums"
    for i in 1 2 3 4 5; do run "$R"; sha256sum <"$T/out" | cut -d' ' -f1 >>"$T/sums"; done
    if [ "$(sort -u "$T/sums" | wc -l)" -gt 1 ]; then ok "M5 repeat check sees $(sort -u "$T/sums" | wc -l) distinct outputs"; else bad "M5 nondeterminism masked"; fi

    echo "M6 a finding outranks an undetermined class"
    R=$T/m6; mkroot "$R"; addclass "$R" demo; printf 'PLANTED-DEFECT in a live file\n' >"$R/notes/bad.txt"
    settsv "$R" "$(row demo)"$'\n' "$(row ghost)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 1 ] && has "FINDING demo low other notes/bad.txt" && has "COULD-NOT-INSPECT ghost:-"; then ok "M6 finding + undetermined => rc 1"; else bad "M6 rc=$RC"; fi

    echo "M7 --out is confined to .remember/logs/zero-gap/ and written atomically"
    R=$T/m7; std "$R"
    run "$R" --out "$T/elsewhere"
    if [ "$RC" -eq 2 ] && [ ! -e "$T/elsewhere" ]; then ok "M7a --out outside => refused rc 2, nothing written"; else bad "M7a rc=$RC"; fi
    run "$R" --out "$R/.remember/logs/zero-gap-evil"
    if [ "$RC" -eq 2 ] && [ ! -e "$R/.remember/logs/zero-gap-evil" ]; then ok "M7b prefix look-alike refused"; else bad "M7b rc=$RC"; fi
    mkdir -p "$R/.remember/logs/zero-gap" "$T/esc"; ln -s "$T/esc" "$R/.remember/logs/zero-gap/esc"
    run "$R" --out "$R/.remember/logs/zero-gap/esc/x"
    if [ "$RC" -eq 2 ] && [ -z "$(ls -A "$T/esc")" ]; then ok "M7c symlink escape refused"; else bad "M7c rc=$RC"; fi
    run "$R" --out "$R/.remember/logs/zero-gap/run1"
    if [ "$RC" -eq 0 ] && [ "$(ls -A "$R/.remember/logs/zero-gap/run1" 2>/dev/null)" = sweep.txt ] && cmp -s "$T/out" "$R/.remember/logs/zero-gap/run1/sweep.txt"; then ok "M7d --out inside writes exactly stdout as sweep.txt, no temp file left"; else bad "M7d rc=$RC ($(ls -A "$R/.remember/logs/zero-gap/run1" 2>/dev/null | tr '\n' ' '))"; fi

    echo "M8 unknown flag"
    run "$T/c0" --bogus
    if [ "$RC" -eq 2 ]; then ok "M8 unknown flag => usage rc 2"; else bad "M8 rc=$RC"; fi

    echo "M9 a deliberately blind class"
    R=$T/m9; one "$R" blind; run "$R"; cp "$T/out" "$T/m9.ref"
    if [ "$RC" -eq 1 ] && grep -q '^CLASS blind .*recall=0.5 ' "$T/out" && grep -q '^FINDING blind high false-evidence scripts/zero-gap-class-blind.sh RECALL-MISS: .*_tests/fixtures/zero-gap/blind/planted/beta.md' "$T/out"; then ok "M9 blind class => recall 0.5, RECALL-MISS at the class script naming the missed planted file, rc 1"; else bad "M9 rc=$RC"; fi

    echo "M10 clean control with a finding"
    R=$T/m10; mkroot "$R"; addclass "$R" demo; printf 'PLANTED-DEFECT on the control\n' >>"$R/_tests/fixtures/zero-gap/demo/clean/alpha.txt"
    settsv "$R" "$(row demo)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 1 ] && grep -q '^FINDING demo high false-evidence scripts/zero-gap-class-demo.sh RECALL-FALSE-POSITIVE: .*_tests/fixtures/zero-gap/demo/clean/alpha.txt' "$T/out"; then ok "M10 false positive on clean control => rc 1, located at the class script"; else bad "M10 rc=$RC"; fi

    echo "M11 class without a corpus"
    R=$T/m11; one "$R" demo nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && grep -q '^CLASS demo .*recall=UNKNOWN .*status=unproven' "$T/out"; then ok "M11 no corpus => recall=UNKNOWN next to no findings, rc 2"; else bad "M11 rc=$RC"; fi

    echo "M12 the TSV is validated (every defect => rc 2)"
    R=$T/m12; std "$R"
    tsvcase() { # <label> <full file content>
        printf '%s' "$2" >"$R/docs/zero-gap/sweep-classes.tsv"; run "$R"
        if [ "$RC" -eq 2 ]; then ok "M12 $1 => rc 2"; else bad "M12 $1 rc=$RC"; fi
    }
    tsvcase "duplicate id" "$HDR"$'\n'"$(row demo)"$'\n'"$(row demo)"$'\n'
    tsvcase "population_kind outside source|process|wire" "$HDR"$'\n'"$(row demo UNKNOWN bogus)"$'\n'
    tsvcase "non-numeric recall" "$HDR"$'\n'"$(row demo high)"$'\n'
    tsvcase "recall above 1" "$HDR"$'\n'"$(row demo 1.5)"$'\n'
    tsvcase "empty entrypoint" "$HDR"$'\n'"$(row demo UNKNOWN source '')"$'\n'
    tsvcase "entrypoint off-convention" "$HDR"$'\n'"$(row demo UNKNOWN source scripts/other.sh)"$'\n'
    tsvcase "corpus off-convention" "$HDR"$'\n'"$(row demo UNKNOWN source scripts/zero-gap-class-demo.sh _tests/other/)"$'\n'
    tsvcase "wrong header" "${HDR/recall/recal}"$'\n'"$(row demo)"$'\n'
    tsvcase "seven fields" "$HDR"$'\n'"$(row demo | cut -f1-7)"$'\n'
    tsvcase "reserved id sweep" "$HDR"$'\n'"$(row sweep)"$'\n'
    tsvcase "id outside [a-z0-9-]" "$HDR"$'\n'"$(row Demo_X)"$'\n'
    tsvcase "empty population_why" "$HDR"$'\n'"$(row demo | awk -F'\t' -v OFS='\t' '{$3=""; print}')"$'\n'
    tsvcase "empty file" ""
    rm -f "$R/docs/zero-gap/sweep-classes.tsv"; run "$R"
    if [ "$RC" -eq 2 ]; then ok "M12 missing TSV file => rc 2"; else bad "M12 missing TSV rc=$RC"; fi

    echo "M13 --expect-fingerprint"
    R=$T/c0; fp=$(sed -n 's/^FINGERPRINT before=\([0-9a-f]*\) .*/\1/p' "$T/c0.ref")
    run "$R" --expect-fingerprint "$fp"
    if [ "$RC" -eq 0 ]; then ok "M13a matching fingerprint => rc 0"; else bad "M13a rc=$RC"; fi
    run "$R" --expect-fingerprint 0000000000000000000000000000000000000000000000000000000000000000
    if [ "$RC" -eq 2 ] && has "differs from --expect-fingerprint"; then ok "M13b other fingerprint => rc 2"; else bad "M13b rc=$RC"; fi

    echo "M14 --class selection"
    R=$T/m14; mkroot "$R"; addclass "$R" demo; settsv "$R" "$(row demo)"$'\n' "$(row ghost)"$'\n'; commit "$R"
    run "$R" --class demo
    if [ "$RC" -eq 0 ] && ! has "ghost"; then ok "M14a --class demo runs only demo"; else bad "M14a rc=$RC"; fi
    run "$R" --class nosuch
    if [ "$RC" -eq 2 ]; then ok "M14b unknown --class id => rc 2"; else bad "M14b rc=$RC"; fi

    echo "M15 class output outside the contract"
    R=$T/m15; one "$R" malformed; run "$R"
    if [ "$RC" -eq 2 ] && has "violates the class output contract"; then ok "M15 malformed output => COULD-NOT-INSPECT rc 2"; else bad "M15 rc=$RC"; fi

    echo "M16 --json is valid and deterministic"
    R=$T/c0; run "$R" --json; cp "$T/out" "$T/j1"; run "$R" --json
    if [ "$RC" -eq 0 ] && cmp -s "$T/out" "$T/j1" && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["verdict"]=="HOLDS" and d["rc"]==0 and d["classes"][0]["recall"]=="1.0"' "$T/out" 2>/dev/null; then ok "M16 --json parses, verdict HOLDS, identical twice"; else bad "M16 rc=$RC"; fi

    echo "M17 published recall disagrees with the measured one"
    R=$T/m17; mkroot "$R"; addclass "$R" demo; settsv "$R" "$(row demo 0.5)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 1 ] && grep -q '^FINDING demo medium docs-drift scripts/zero-gap-class-demo.sh RECALL-MISMATCH: ' "$T/out"; then ok "M17 recall recomputed; stale published figure => rc 1"; else bad "M17 rc=$RC"; fi

    echo "M18 malformed corpus"
    R=$T/m18; mkroot "$R"; addclass "$R" demo; rm "$R/_tests/fixtures/zero-gap/demo/expect.tsv"; settsv "$R" "$(row demo)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 2 ] && has "corpus malformed"; then ok "M18 corpus without expect.tsv => rc 2"; else bad "M18 rc=$RC"; fi

    echo "M19 absent root"
    run /nonexistent
    if [ "$RC" -eq 2 ]; then ok "M19 --root /nonexistent => rc 2"; else bad "M19 rc=$RC"; fi

    echo "M20 class script present but absent from the TSV"
    R=$T/m20; std "$R"; cp "$R/scripts/zero-gap-class-demo.sh" "$R/scripts/zero-gap-class-stray.sh"; commit "$R"; run "$R"
    if [ "$RC" -eq 1 ] && has "FINDING sweep medium governance-drift scripts/zero-gap-class-stray.sh"; then ok "M20 unlisted class script => finding"; else bad "M20 rc=$RC"; fi
    cp "$T/out" "$T/m20.ref"

    echo "M21 class inspecting less than its population"
    R=$T/m21; one "$R" partial; run "$R"
    if [ "$RC" -eq 2 ] && has "inspected 1 of 2"; then ok "M21 partial inspection => rc 2"; else bad "M21 rc=$RC"; fi

    echo "I1 percent-encoded locations (spaces, unicode, %, newline)"
    for b in "$FIX/demo-class.sh" "$LIVE_ROOT/docs/zero-gap/README.md"; do
        awk '/^# >>> zg_pct_encode/{f=1} f{print} /^# <<< zg_pct_encode/{exit}' "$b" >"$T/snip.$(basename "$b")"
    done
    if [ -s "$T/snip.README.md" ] && cmp -s "$T/snip.README.md" "$T/snip.demo-class.sh"; then ok "I1a README zg_pct_encode snippet is byte-identical to the fixture class's copy"; else bad "I1a README snippet absent or differs from the fixture class"; fi
    ref=$(bash -c '. "$1"; zg_pct_encode "a b%é"; printf "x\ny\0-A.z_0~/+:@,=\0" | zg_pct_encode_z' _ "$T/snip.README.md" 2>/dev/null | tr '\n' '|')
    if [ "$ref" = 'a%20b%25%C3%A9|x%0Ay|-A.z_0~/+:@,=|' ]; then ok "I1b snippet encodes blank, %, UTF-8 and newline; keeps the safe set"; else bad "I1b snippet gave '$ref'"; fi
    R=$T/i1; mkroot "$R"; addclass "$R" demo
    for b in "a b.txt" "é.txt" "100%.txt" $'n\nl.txt'; do printf 'PLANTED-DEFECT\n' >"$R/notes/$b"; done
    settsv "$R" "$(row demo)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 1 ] && has "FINDING demo low other notes/a%20b.txt " && has "FINDING demo low other notes/%C3%A9.txt " && has "FINDING demo low other notes/100%25.txt " && has "FINDING demo low other notes/n%0Al.txt " && ! has "COULD-NOT-INSPECT"; then ok "I1c encoded blank/unicode/%/newline paths are four findings, nothing undetermined"; else bad "I1c rc=$RC"; fi
    R=$T/i1r; mkroot "$R"; addclass "$R" rawspace; printf 'PLANTED-DEFECT\n' >"$R/notes/a b.txt"; settsv "$R" "$(row rawspace)"$'\n'; commit "$R"; run "$R"
    if [ "$RC" -eq 2 ] && ! grep -q '^FINDING rawspace low' "$T/out" && has "COULD-NOT-INSPECT rawspace:"; then ok "I1d unencoded blank => class malformed rc 2, no mis-split finding accepted"; else bad "I1d rc=$RC ($(grep -m2 -E '^(FINDING|COULD)' "$T/out" | tr '\n' ' '))"; fi
    R=$T/i1e; std "$R"; printf 'a%%2Ex\tnon-canonical\n' >>"$R/_tests/fixtures/zero-gap/demo/expect.tsv"; commit "$R"; run "$R"
    if [ "$RC" -eq 2 ] && has "corpus malformed"; then ok "I1e non-canonical expect.tsv location => corpus malformed rc 2"; else bad "I1e rc=$RC"; fi

    echo "I2 a hostile environment cannot change the verdict or the report"
    R=$T/c0; mkroot "$T/other"; printf 'PLANTED-DEFECT\n' >"$T/other/notes/other.txt"; commit "$T/other"
    envcase() { # <label> <reference file> <VAR=value>... -- <root>
        local label=$1 reff=$2; shift 2
        runenv "$@"
        if cmp -s "$T/out" "$reff"; then ok "I2 $label => identical report"; else bad "I2 $label changed the report (rc=$RC)"; fi
    }
    envcase "GIT_DIR+GIT_WORK_TREE of another repository" "$T/c0.ref" GIT_DIR="$T/other/.git" GIT_WORK_TREE="$T/other" -- "$R"
    envcase "GIT_INDEX_FILE pointing elsewhere" "$T/c0.ref" GIT_INDEX_FILE="$T/other/.git/index" -- "$R"
    envcase "POSIXLY_CORRECT on a 0.5-recall class" "$T/m9.ref" POSIXLY_CORRECT=1 -- "$T/m9"
    envcase "LC_ALL=en_DK.utf8 on a 0.5-recall class" "$T/m9.ref" LC_ALL=en_DK.utf8 LANG=en_DK.utf8 -- "$T/m9"
    envcase "GREP_OPTIONS=-v" "$T/m9.ref" GREP_OPTIONS=-v -- "$T/m9"
    printf 'case "${0##*/}" in zero-gap-class-*) echo "FINDING demo high security notes/ok.txt injected by a start-up file notes/ok.txt" ;; esac\n' >"$T/hostile-env.sh"
    envcase "BASH_ENV start-up file" "$T/c0.ref" BASH_ENV="$T/hostile-env.sh" -- "$R"
    envcase "ENV start-up file" "$T/c0.ref" ENV="$T/hostile-env.sh" -- "$R"
    envcase "a variable outside the class allow-list (ZG_ENV_LEAK_PROBE)" "$T/c0.ref" ZG_ENV_LEAK_PROBE=1 -- "$R"
    mkdir -p "$T/decoy"; std "$T/decoy/c0"; printf 'PLANTED-DEFECT\n' >"$T/decoy/c0/notes/decoy.txt"; commit "$T/decoy/c0"
    RC=0; ( cd "$T" && env TMPDIR="$T/tmp" CDPATH="$T/decoy" bash "$SELF" --root c0 ) >"$T/out" 2>"$T/err" || RC=$?
    if cmp -s "$T/out" "$T/c0.ref"; then ok "I2 CDPATH with a relative --root => the named root, identical report"; else bad "I2 CDPATH redirected the root (rc=$RC)"; fi

    echo "I3 control characters never reach the report; --json stays valid"
    for b in hostile badutf8; do
        R=$T/i3-$b; one "$R" "$b"; printf 'PLANTED-DEFECT live\n' >"$R/notes/bad.txt"; commit "$R"; run "$R"
        if [ "$RC" -eq 2 ] && has "violates the class output contract" && ! LC_ALL=C grep -q $'[\001-\011\013-\037\177-\377]' "$T/out"; then ok "I3a $b live output => class malformed rc 2, report free of control and invalid bytes"; else bad "I3a $b rc=$RC"; fi
        run "$R" --json
        if jsonok "$T/out"; then ok "I3b --json over $b class output is valid JSON"; else bad "I3b $b --json invalid (rc=$RC)"; fi
        if ! LC_ALL=C grep -q $'[\033\007]' "$T/err"; then ok "I3c $b class stderr is forwarded without ESC/BEL"; else bad "I3c $b ESC/BEL reached stderr"; fi
    done
    R=$T/i3q; one "$R" quotes; printf 'PLANTED-DEFECT live\n' >"$R/notes/bad.txt"; commit "$R"; run "$R" --json
    if [ "$RC" -eq 1 ] && jsonok "$T/out" && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert any("\"marker\" with a back\\slash" in f["description"] for f in d["findings"])' "$T/out" 2>/dev/null; then ok "I3d quotes and backslashes round-trip through --json"; else bad "I3d rc=$RC"; fi

    echo "I4 fingerprint blind spots, each attributed to the class"
    fpcase() { # <mode> <label> <needle>
        R=$T/i4-$1; one "$R" "$1"; run "$R"
        if [ "$RC" -eq 2 ] && has "VERDICT UNSTABLE" && has "COULD-NOT-INSPECT $1:$3"; then ok "I4 $2 => UNSTABLE naming class $1"; else bad "I4 $2 rc=$RC ($(grep -m1 VERDICT "$T/out"))"; fi
    }
    fpcase restorer "write-then-restore of a tracked file" "@mtime:notes/ok.txt"
    fpcase committer "git commit in the swept repository" "@git:HEAD"
    fpcase configer "git config --local in the swept repository" "@git:config"
    fpcase emitwriter "a write during --emit-population" "emitwriter-was-here.txt"
    R=$T/i4-ign; one "$R" ignwriter; run "$R"
    if [ "$RC" -eq 2 ] && has "COULD-NOT-INSPECT ignwriter:.remember/zg-probe written while this class ran"; then ok "I4 write into an ignored path => COULD-NOT-INSPECT naming class and path"; else bad "I4 ignored write rc=$RC"; fi
    R=$T/i4-tmp; one "$R" tmpwriter; run "$R"
    if [ "$RC" -eq 0 ]; then ok "I4 write under an excluded concurrent-writer path (.remember/tmp/) is not attributed"; else bad "I4 excluded path rc=$RC"; fi
    if grep -q 'fingerprint window' "$T/err"; then ok "I4 per-class fingerprint cost is printed on stderr"; else bad "I4 no fingerprint timing printed"; fi
    R=$T/i4-svc; one "$R" svclog; run "$R"
    if [ "$RC" -eq 0 ] && ! has "COULD-NOT-INSPECT svclog:"; then ok "I4 a probed server's access log under .service-registry/qa/ (default exclusion) is not attributed"; else bad "I4 service log rc=$RC"; fi

    echo "I5 budgets, process groups, population identity"
    R=$T/i5s; one "$R" sleeper nocorpus; rm -f "$T/tmp/zg-sleeper.pid"; t0=$SECONDS
    runenv ZG_CLASS_BUDGET=2 -- "$R"
    pid=$(cat "$T/tmp/zg-sleeper.pid" 2>/dev/null || true)
    if [ "$RC" -eq 2 ] && has "class budget" && [ $((SECONDS - t0)) -lt 25 ]; then ok "I5a class over its budget => COULD-NOT-INSPECT rc 2 within $((SECONDS - t0)) s"; else bad "I5a rc=$RC after $((SECONDS - t0)) s"; fi
    if [ -n "$pid" ] && ! running "$pid"; then ok "I5b its TERM-ignoring child did not outlive the class"; else bad "I5b child ${pid:-<no pid>} survived"; [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null; fi
    R=$T/i5o; one "$R" orphaner nocorpus; rm -f "$T/tmp/zg-orphan.pid"; run "$R"
    pid=$(cat "$T/tmp/zg-orphan.pid" 2>/dev/null || true)
    if [ "$RC" -eq 2 ] && has "left processes" && ! has "outlived" && [ -n "$pid" ] && ! running "$pid"; then ok "I5c a child left behind by an exited class is terminated and reported"; else bad "I5c rc=$RC pid=${pid:-none}"; [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null; fi
    R=$T/i5n; one "$R" nap nocorpus; runenv ZG_SWEEP_BUDGET=1 -- "$R"
    if [ "$RC" -eq 2 ] && has "sweep budget"; then ok "I5d sweep budget exhausted => COULD-NOT-INSPECT rc 2"; else bad "I5d rc=$RC"; fi
    runenv ZG_CLASS_BUDGET=abc -- "$T/c0"
    if [ "$RC" -eq 2 ]; then ok "I5e a non-numeric budget => rc 2"; else bad "I5e rc=$RC"; fi
    R=$T/i5p; one "$R" sameset nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "POPULATION-SHA"; then ok "I5f same-size different set => POPULATION-SHA mismatch rc 2"; else bad "I5f rc=$RC"; fi

    echo "I7 corpus fixtures are excluded from every live population"
    R=$T/i7; one "$R" fixturepop; run "$R"
    if [ "$RC" -eq 2 ] && has "COULD-NOT-INSPECT fixturepop:_tests/fixtures/zero-gap/"; then ok "I7 a live population reaching _tests/fixtures/zero-gap/ => COULD-NOT-INSPECT naming it"; else bad "I7 rc=$RC"; fi

    echo "R2-I2 the runner re-executes under a clean environment"
    envcase "SHELLOPTS=noglob (stray-class check)" "$T/m20.ref" SHELLOPTS=noglob -- "$T/m20"
    envcase "SHELLOPTS=noclobber" "$T/m20.ref" SHELLOPTS=noclobber -- "$T/m20"
    envcase "SHELLOPTS=monitor (job control)" "$T/c0.ref" SHELLOPTS=monitor -- "$T/c0"
    envcase "exported function BASH_FUNC_sort%%" "$T/m20.ref" 'BASH_FUNC_sort%%=() {  cat; }' -- "$T/m20"
    mkdir -p "$T/evilhome"; printf '*\n' >"$T/evilhome/ignore-all"
    printf '[core]\n\texcludesFile = %s\n' "$T/evilhome/ignore-all" >"$T/evilhome/.gitconfig"
    R=$T/r2home; std "$R"; printf 'an untracked, not ignored note\n' >"$R/notes/untracked.txt"; run "$R"; cp "$T/out" "$T/r2home.ref"
    envcase "HOME with a global gitconfig that ignores every file" "$T/r2home.ref" HOME="$T/evilhome" -- "$R"
    mkdir -p "$T/evilhome/xdg/git"; cp "$T/evilhome/.gitconfig" "$T/evilhome/xdg/git/config"
    envcase "XDG_CONFIG_HOME with the same git config" "$T/r2home.ref" XDG_CONFIG_HOME="$T/evilhome/xdg" -- "$R"
    mkdir -p "$T/xdghome/.config/git"; printf '*.txt\n' >"$T/xdghome/.config/git/ignore"; printf '* -text\n' >"$T/xdghome/.config/git/attributes"
    envcase "HOME with an implicit ~/.config/git/ignore and attributes" "$T/r2home.ref" HOME="$T/xdghome" -- "$R"
    R=$T/r2env; one "$R" envdump nocorpus; rm -f "$T/tmp/zg-env.txt" "$T/tmp/zg-envval.txt"
    RC=0; env -i PATH="$PATH" HOME="$T/home" TMPDIR="$T/tmp" SHELLOPTS=noglob EVIL_VAR=1 GIT_DIR="$T/other/.git" bash "$SELF" --root "$R" >"$T/out" 2>"$T/err" || RC=$?
    if [ "$(tr '\n' ' ' <"$T/tmp/zg-env.txt" 2>/dev/null)" = "GIT_CONFIG_COUNT GIT_CONFIG_GLOBAL GIT_CONFIG_KEY_0 GIT_CONFIG_KEY_1 GIT_CONFIG_SYSTEM GIT_CONFIG_VALUE_0 GIT_CONFIG_VALUE_1 GOMAXPROCS GOTOOLCHAIN HOME LANG LC_ALL PATH PYTHONDONTWRITEBYTECODE TMPDIR ZG_RUN " ]; then ok "R2-I2 the class environment is exactly the allow-list"; else bad "R2-I2 class environment: $(tr '\n' ' ' <"$T/tmp/zg-env.txt" 2>/dev/null)"; fi
    if [ "$(tr '\n' ' ' <"$T/tmp/zg-envval.txt" 2>/dev/null)" = "GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GOTOOLCHAIN=local GOMAXPROCS=4 PYTHONDONTWRITEBYTECODE=1 LC_ALL=C LANG=C " ]; then ok "R2-I2 allow-list values: global/system git config off, GOTOOLCHAIN=local, GOMAXPROCS=4, no bytecode"; else bad "R2-I2 values: $(tr '\n' ' ' <"$T/tmp/zg-envval.txt" 2>/dev/null)"; fi

    echo "R2-I3 NUL, C1 controls and invisible direction/line characters are rejected as bytes"
    for b in nulbyte c1ctrl bidi linesep alm; do
        R=$T/r2-$b; one "$R" "$b" nocorpus; run "$R"
        if [ "$RC" -eq 2 ] && has "violates the class output contract" && ! grep -q "^FINDING $b " "$T/out" \
           && ! LC_ALL=C grep -q $'\xc2[\x80-\x9f]\|\xe2\x80[\xa8-\xae]\|\xd8\x9c' "$T/out" && [ "$(tr -d '\000' <"$T/out" | wc -c)" -eq "$(wc -c <"$T/out")" ]; then ok "R2-I3 $b => class malformed rc 2, the sequence never reaches the report"; else bad "R2-I3 $b rc=$RC"; fi
        run "$R" --json
        if jsonok "$T/out" && ! LC_ALL=C grep -q $'\xc2[\x80-\x9f]\|\xe2\x80[\xa8-\xae]' "$T/out"; then ok "R2-I3 $b --json valid and free of it"; else bad "R2-I3 $b --json (rc=$RC)"; fi
    done

    echo "R2-I5 a grandchild that escaped the process group via setsid is found, reported and ended"
    R=$T/r2esc; one "$R" escaper nocorpus; rm -f "$T/tmp/zg-escaper.pid"; run "$R"
    pid=$(cat "$T/tmp/zg-escaper.pid" 2>/dev/null || true)
    if [ "$RC" -eq 2 ] && has "outlived" && [ -n "$pid" ] && ! running "$pid"; then ok "R2-I5 escaped setsid grandchild => COULD-NOT-INSPECT rc 2 and it is gone"; else bad "R2-I5 rc=$RC pid=${pid:-none} alive=$(kill -0 "${pid:-0}" 2>/dev/null && echo yes || echo no)"; fi
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null; fi
    R=$T/r2flood; one "$R" flood nocorpus; t0=$SECONDS; run "$R" --json
    if [ "$RC" -eq 1 ] && [ $((SECONDS - t0)) -lt 120 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert len(d["findings"]) == 200000' "$T/out" 2>/dev/null; then ok "R2-I5 200000 findings render as valid JSON in $((SECONDS - t0)) s"; else bad "R2-I5 flood rc=$RC after $((SECONDS - t0)) s"; fi

    echo "R2-I7 non-normal path tokens and fixture paths anywhere in a token are rejected"
    R=$T/r2dot; one "$R" dotslash nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "population output violates the contract" && ! grep -q '^FINDING dotslash ' "$T/out"; then ok "R2-I7 ./ population items => rc 2, nothing accepted"; else bad "R2-I7 dotslash rc=$RC"; fi
    R=$T/r2dotfix; one "$R" dotfix nocorpus; mkdir -p "$R/_tests/fixtures/zero-gap/x"; printf 'PLANTED-DEFECT\n' >"$R/_tests/fixtures/zero-gap/x/p.txt"; commit "$R"; run "$R"
    if [ "$RC" -eq 2 ] && ! grep -q '^FINDING dotfix ' "$T/out"; then ok "R2-I7 ./_tests/fixtures/zero-gap/x/p.txt never produces a finding"; else bad "R2-I7 dotted fixture rc=$RC"; fi
    for b in dotloc colonfix ghostloc; do
        R=$T/r2-$b; one "$R" "$b" nocorpus; run "$R"
        if [ "$RC" -eq 2 ] && ! grep -q "^FINDING $b " "$T/out" && { has "not accepted" || has "violates the class output contract"; }; then ok "R2-I7 $b location => not accepted, rc 2"; else bad "R2-I7 $b rc=$RC"; fi
    done

    echo "R2-I1 evidence_ref must be a real path (or path:suffix); a tracked file may be a location"
    for b in badref rawref; do
        R=$T/r2-$b; one "$R" "$b" nocorpus
        if [ "$b" = rawref ]; then printf 'PLANTED-DEFECT\n' >"$R/notes/a b.txt"; commit "$R"; fi
        run "$R"
        if [ "$RC" -eq 2 ] && ! grep -q "^FINDING $b " "$T/out"; then ok "R2-I1 $b evidence_ref => class malformed, nothing accepted, rc 2"; else bad "R2-I1 $b rc=$RC ($(grep -m1 '^FINDING' "$T/out"))"; fi
    done
    for b in dotref absref; do
        R=$T/r2-$b; one "$R" "$b" nocorpus; run "$R"
        if [ "$RC" -eq 2 ] && ! grep -q "^FINDING $b " "$T/out" && has "violates the class output contract"; then ok "R2-I1 $b: an existing but non-normal evidence path is rejected, rc 2"; else bad "R2-I1 $b rc=$RC"; fi
    done
    R=$T/r2-trackedloc; one "$R" trackedloc nocorpus; run "$R"
    if [ "$RC" -eq 1 ] && has "FINDING trackedloc low other docs/zero-gap/sweep-classes.tsv:3 " && ! has "not accepted"; then ok "R2-I1 a tracked file with a line suffix is an accepted location"; else bad "R2-I1 trackedloc rc=$RC"; fi

    echo "R3-IC side effects outside the content fingerprint are attributed to the class"
    R=$T/r3-ignrm; one "$R" ignrm nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "COULD-NOT-INSPECT ignrm:_site"; then ok "R3-IC removing an ignored file (_site/index.html) => COULD-NOT-INSPECT naming it"; else bad "R3-IC ignrm rc=$RC"; fi
    R=$T/r3-igncpp; one "$R" igncpp nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "COULD-NOT-INSPECT igncpp:_site/index.html"; then ok "R3-IC cp -p over an ignored file (old mtime kept) => COULD-NOT-INSPECT naming it"; else bad "R3-IC igncpp rc=$RC"; fi
    R=$T/r3-hook; one "$R" hookwriter nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "VERDICT UNSTABLE" && has "COULD-NOT-INSPECT hookwriter:@git:hooks"; then ok "R3-IC a write to .git/hooks/pre-push => UNSTABLE naming the class"; else bad "R3-IC hookwriter rc=$RC"; fi
    R=$T/r3-excl; one "$R" excludewriter nocorpus; run "$R"
    if [ "$RC" -eq 2 ] && has "VERDICT UNSTABLE" && has "COULD-NOT-INSPECT excludewriter:@git:info"; then ok "R3-IC a write to .git/info/exclude => UNSTABLE naming the class"; else bad "R3-IC excludewriter rc=$RC"; fi

    echo "R3 evidence_ref must be a regular file inside --root, outside .git/ and the corpus fixtures"
    for b in dirref gitref linkref fixref; do
        R=$T/r3-$b
        if [ "$b" = fixref ]; then one "$R" "$b"; else one "$R" "$b" nocorpus; fi
        if [ "$b" = linkref ]; then ln -s /etc/hostname "$R/notes/host"; commit "$R"; fi
        run "$R"
        if [ "$RC" -eq 2 ] && ! grep -q "^FINDING $b " "$T/out" && has "violates the class output contract"; then ok "R3 $b evidence_ref rejected, nothing accepted, rc 2"; else bad "R3 $b rc=$RC ($(grep -m1 "^FINDING $b" "$T/out" | cut -c1-80))"; fi
    done

    echo "R3 an escapee that keeps spawning is frozen and ended with all its descendants"
    R=$T/r3-spawn; one "$R" spawner nocorpus; rm -f "$T/tmp/zg-spawner.pid"; run "$R"
    pid=$(cat "$T/tmp/zg-spawner.pid" 2>/dev/null || true)
    left=$(sess_members "${pid:-0}")
    if [ "$RC" -eq 2 ] && has "outlived" && [ -n "$pid" ] && [ -z "$left" ]; then ok "R3 spawning escapee => COULD-NOT-INSPECT rc 2, no process of its session remains"; else bad "R3 spawner rc=$RC pid=${pid:-none} left=[$left]"; fi
    for p in $left; do kill -KILL "$p" 2>/dev/null; done

    echo "I6 the live class list derives each disputed population from a named tracked source"
    rowcase() { # <class_id> <path substring>...
        local id=$1 pop p okk=1; shift
        pop=$(awk -F'\t' -v c="$id" '$1 == c { print $2 }' "$LIVE_ROOT/docs/zero-gap/sweep-classes.tsv")
        for p in "$@"; do
            case "$pop" in *"$p"*) ;; *) okk=0 ;; esac
            compgen -G "$LIVE_ROOT/$p*" >/dev/null || okk=0
        done
        if [ "$okk" -eq 1 ]; then ok "I6 $id names $* and each exists"; else bad "I6 $id does not name an existing $*"; fi
    }
    rowcase live-vs-source workshop/platform/compose.yml scripts/qa-up.sh
    rowcase unproven-checks scripts/check-registry.tsv
    rowcase doc-count-drift docs/claim-ledger.tsv
    rowcase build-if-missing ai_interviewing/platform/scripts/start.sh
    rowcase improvement-candidates docs/OPERATOR-DECISIONS- docs/workable_items.db
    rowcase missing-toolchain docs/zero-gap/toolchains.tsv
    rowcase guard-gaps docs/zero-gap/guarded-commands.tsv
    # The catalogue files' SCHEMAS are owned by their classes (missing-toolchain, guard-gaps) and asserted
    # by those classes' own proofs; this battery only checks that each named source exists (round-3 I-A).
    return 0
    }

    echo "LIVE the live tree is unchanged across the whole proof (read-only; rc 2 if it moved)"
    st0=$(git --no-optional-locks -C "$LIVE_ROOT" status --porcelain 2>&1) || strc=$?
    if [ "$strc" -ne 0 ]; then echo "prove-failure: cannot read live git status — cannot determine" >&2; exit 2; fi
    rc=0; zg_with_fingerprint --dir "$LIVE_ROOT" -- body || rc=$?
    st1=$(git --no-optional-locks -C "$LIVE_ROOT" status --porcelain 2>&1) || strc=$?
    if [ "$rc" -eq 2 ] || [ "$strc" -ne 0 ] || [ "$st0" != "$st1" ]; then
        echo "  UNDETERMINED LIVE: the live tree changed or could not be read during the proof; the cases ran but cannot be vouched for"
        echo "prove-failure: $pass passed, $fail failed (live tree moved: rc 2)"; exit 2
    fi
    ok "LIVE live tree byte-identical (whole-tree fingerprint + git status)"
    echo "prove-failure: $pass passed, $fail failed"
    if [ "$fail" -eq 0 ]; then exit 0; fi
    exit 1
)

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi

# ── preconditions: every one of them is rc 2, before anything runs ──
[ -n "$ROOT" ] && [ -d "$ROOT" ] || die2 "--root '${ROOT:-<empty>}' is not a directory"
ROOT=$(cd "$ROOT" && pwd -P) || die2 "cannot enter --root"
for b in git sha256sum mktemp sort comm cut od awk grep sed realpath cmp setsid iconv stat find xargs touch env tr wc; do
    command -v "$b" >/dev/null 2>&1 || die2 "'$b' is not on PATH"
done
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die2 "$ROOT is not a git work tree; its population cannot be enumerated"
# shellcheck source=zero-gap-lib.sh
. "$HERE/zero-gap-lib.sh" 2>/dev/null || die2 "scripts/zero-gap-lib.sh could not be loaded"
if [ -n "$EXPECT_FP" ] && ! [[ $EXPECT_FP =~ ^[0-9a-f]{64}$ ]]; then die2 "--expect-fingerprint must be 64 lowercase hex characters"; fi
[[ $CLASS_BUDGET =~ ^[1-9][0-9]*$ ]] || die2 "ZG_CLASS_BUDGET must be a positive whole number of seconds"
[[ $SWEEP_BUDGET =~ ^[1-9][0-9]*$ ]] || die2 "ZG_SWEEP_BUDGET must be a positive whole number of seconds"

OUT_DIR=""
if [ -n "$OUT" ]; then
    base="$ROOT/.remember/logs/zero-gap"
    base_r=$(realpath -m -- "$base") || die2 "cannot resolve $base"
    [ "$base_r" = "$base" ] || die2 "--out refused: .remember/logs/zero-gap under --root resolves elsewhere (a symlink); the sweep writes only inside the tree's own ignored log directory"
    out_r=$(realpath -m -- "$OUT") || die2 "cannot resolve --out '$OUT'"
    case "$out_r" in
        "$base_r"|"$base_r"/*) ;;
        *) die2 "--out refused: '$OUT' is outside .remember/logs/zero-gap/ under --root (the sweep writes nowhere else)" ;;
    esac
    git -C "$ROOT" check-ignore -q -- ".remember/logs/zero-gap/probe" \
        || die2 "--out refused: .remember/logs/zero-gap/ is not git-ignored at --root, so a report written there would change the swept population"
    OUT_DIR=$out_r
fi

load_tsv

# selection: every class, or the named ones (each must exist), in class_id order
declare -A WANT=()
for s in ${SEL[@]+"${SEL[@]}"}; do
    found=0
    for id in "${C_ID[@]}"; do [ "$id" = "$s" ] && found=1; done
    [ "$found" -eq 1 ] || die2 "--class '$s' is not listed in $REL_TSV"
    WANT[$s]=1
done
ORDER=()
while IFS=$'\t' read -r id idx; do
    if [ "${#WANT[@]}" -eq 0 ] || [ -n "${WANT[$id]:-}" ]; then ORDER+=("$idx"); fi
done < <(for idx in "${!C_ID[@]}"; do printf '%s\t%s\n' "${C_ID[$idx]}" "$idx"; done | LC_ALL=C sort)

W=$(mktemp -d) || die2 "mktemp failed"
trap 'rm -rf "$W"' EXIT
: >"$W/findings"; : >"$W/cni"; : >"$W/classes"
mkdir -p "$W/tmp"
ZG_TOKEN=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
[[ $ZG_TOKEN =~ ^[0-9a-f]{32}$ ]] || die2 "cannot draw a random run token from /dev/urandom"
CLASS_ENV=("PATH=$PATH" "LC_ALL=C" "LANG=C" "TMPDIR=${TMPDIR:-$W/tmp}" "GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_SYSTEM=/dev/null"
           "GOTOOLCHAIN=local" "GOMAXPROCS=${GOMAXPROCS:-4}" "PYTHONDONTWRITEBYTECODE=1" "ZG_RUN=$ZG_TOKEN"
           "GIT_CONFIG_COUNT=2" "GIT_CONFIG_KEY_0=core.excludesFile" "GIT_CONFIG_VALUE_0=/dev/null"
           "GIT_CONFIG_KEY_1=core.attributesFile" "GIT_CONFIG_VALUE_1=/dev/null")
for v in HOME USER LOGNAME XDG_RUNTIME_DIR; do
    if [ -n "${!v:-}" ]; then CLASS_ENV+=("$v=${!v}"); fi
done

# paths tracked at --root (encoded): a FINDING location may be one of these (or one + :suffix)
while IFS= read -r l; do [ -n "$l" ] && TRACKED[$l]=1; done < <(git -C "$ROOT" ls-files -z | zg_pct_encode_z)
now_ms; SWEEP_DEADLINE=$((NOW + SWEEP_BUDGET * 1000)); CLASS_DEADLINE=$SWEEP_DEADLINE
FP0=unavailable FP1=unavailable FILES0=0 FILES1=0 UNSTABLE=0 SKIP=0 FP_FAIL=0 RAN=0
if state_manifest "$W/state.cur"; then
    FP0=$(sha256sum <"$W/state.cur" | cut -d' ' -f1); FILES0=$STATE_FILES
else
    add_cni "sweep:-" "state fingerprint could not be taken before the run"; SKIP=1; FP_FAIL=1
fi
if [ "$SKIP" -eq 0 ] && [ -n "$EXPECT_FP" ] && [ "$FP0" != "$EXPECT_FP" ]; then
    add_cni "sweep:-" "state fingerprint $FP0 differs from --expect-fingerprint $EXPECT_FP; no class was run"; SKIP=1
fi

if [ "$SKIP" -eq 0 ]; then
    # anti-drift: a class script that no TSV row names would never run — silently
    for f in "$ROOT"/scripts/zero-gap-class-*.sh; do
        [ -e "$f" ] || continue
        id=${f##*/zero-gap-class-}; id=${id%.sh}; listed=0
        for c in "${C_ID[@]}"; do [ "$c" = "$id" ] && listed=1; done
        [ "$listed" -eq 1 ] || add_finding sweep medium governance-drift "scripts/zero-gap-class-$(zg_pct_encode "$id").sh" "class script is not listed in $REL_TSV, so no sweep ever runs it" "$REL_TSV"
    done
    for idx in "${ORDER[@]}"; do run_class "$idx"; done
fi

if [ "$FP_FAIL" -eq 0 ]; then
    if [ "$RAN" -eq 0 ]; then now_ms; WIN_T0=$NOW; window_close sweep; fi
    FP1=$(sha256sum <"$W/state.cur" | cut -d' ' -f1)
    if [ "$RAN" -eq 0 ]; then FILES1=$STATE_FILES; fi
fi

LC_ALL=C sort -u -t$'\t' -k1,1 -k2,2 -k3 "$W/findings" >"$W/findings.s"
LC_ALL=C sort -u "$W/cni" >"$W/cni.s"
LC_ALL=C sort -t$'\t' -k1,1 "$W/classes" >"$W/classes.s"
NF=$(awk 'END{print NR}' "$W/findings.s")
NC=$(awk 'END{print NR}' "$W/cni.s")
NK=$(awk 'END{print NR}' "$W/classes.s")
NU=$(awk -F'\t' '$4 == "UNKNOWN"' "$W/classes.s" | awk 'END{print NR}')
if [ "$UNSTABLE" -eq 1 ]; then VERDICT=UNSTABLE RC=2
elif [ "$NF" -gt 0 ]; then VERDICT=VIOLATED RC=1
elif [ "$NC" -gt 0 ] || [ "$NU" -gt 0 ] || [ "$NK" -eq 0 ]; then VERDICT=UNDETERMINED RC=2
else VERDICT=HOLDS RC=0; fi

if [ "$JSON" -eq 0 ]; then
    {
        awk -F'\t' -v OFS=' ' '{ print "FINDING", $1, $3, $4, $2, $5, $6 }' "$W/findings.s"
        awk -F'\t' '{ print "COULD-NOT-INSPECT " $1 " " $2 }' "$W/cni.s"
        awk -F'\t' 'FILENAME == ARGV[1] { n[$1]++; next } { print "CLASS " $1 " population=" $2 " inspected=" $3 " recall=" $4 " findings=" (n[$1] + 0) " status=" $6 }' "$W/findings.s" "$W/classes.s"
        printf 'FINGERPRINT before=%s files=%s\n' "$FP0" "$FILES0"
        printf 'FINGERPRINT after=%s files=%s\n' "$FP1" "$FILES1"
        printf 'VERDICT %s rc=%s findings=%s could-not-inspect=%s classes=%s unknown-recall=%s\n' "$VERDICT" "$RC" "$NF" "$NC" "$NK" "$NU"
    } >"$W/report"
else
    # one awk pass per section: linear in the number of findings (no process per finding)
    JQ='function q(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return "\"" s "\"" }'
    {
        printf '{\n  "schema": "zero-gap-sweep/1",\n  "findings": ['
        awk -F'\t' "$JQ"' { printf "%s\n    {\"class\": %s, \"severity\": %s, \"category\": %s, \"location\": %s, \"description\": %s, \"evidence_ref\": %s}", (NR > 1 ? "," : ""), q($1), q($3), q($4), q($2), q($5), q($6) }' "$W/findings.s"
        printf '\n  ],\n  "could_not_inspect": ['
        awk -F'\t' "$JQ"' { printf "%s\n    {\"part\": %s, \"reason\": %s}", (NR > 1 ? "," : ""), q($1), q($2) }' "$W/cni.s"
        printf '\n  ],\n  "classes": ['
        awk -F'\t' "$JQ"' FILENAME == ARGV[1] { n[$1]++; next } { printf "%s\n    {\"id\": %s, \"population\": %s, \"inspected\": %s, \"recall\": %s, \"population_kind\": %s, \"findings\": %s, \"status\": %s}", (k++ ? "," : ""), q($1), $2, $3, q($4), q($5), n[$1] + 0, q($6) }' "$W/findings.s" "$W/classes.s"
        printf '\n  ],\n  "fingerprint": {"before": "%s", "after": "%s", "files_before": %s, "files_after": %s},\n' "$FP0" "$FP1" "$FILES0" "$FILES1"
        printf '  "verdict": "%s",\n  "rc": %s\n}\n' "$VERDICT" "$RC"
    } >"$W/report"
fi

cat "$W/report"
if [ -n "$OUT_DIR" ]; then
    wrc=0
    mkdir -p -- "$OUT_DIR" || wrc=2
    if [ "$wrc" -eq 0 ]; then
        case "$(realpath -e -- "$OUT_DIR" 2>/dev/null)" in
            "$base_r"|"$base_r"/*) ;;
            *) wrc=2 ;;
        esac
    fi
    if [ "$wrc" -eq 0 ]; then
        if [ "$JSON" -eq 1 ]; then name=sweep.json; else name=sweep.txt; fi
        tmpf=$(mktemp "$OUT_DIR/.$name.XXXXXX") || wrc=2
        if [ "$wrc" -eq 0 ]; then
            if cp -- "$W/report" "$tmpf" && mv -f -- "$tmpf" "$OUT_DIR/$name"; then :; else rm -f -- "$tmpf"; wrc=2; fi
        fi
    fi
    if [ "$wrc" -ne 0 ]; then
        echo "zero-gap-sweep: the report could not be written under --out (it was printed above); rc 2 unless a finding outranks it" >&2
        zg_combine "$RC" 2; RC=$?
    fi
fi
exit "$RC"
