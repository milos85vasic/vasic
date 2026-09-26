#!/usr/bin/env bash
# zero-gap-class-pointer-drift.sh — sweep class `pointer-drift` (feature 010, task T022).
#
# ── What it detects ──────────────────────────────────────────────────────────
# A submodule pin can drift in four places: the INDEX gitlink, the recorded
# `helix-deps.yaml` deps[].ref, the pin SHAs quoted in the four root carriers,
# and ANY remote the submodule checkout has configured — not only `origin`.
# scripts/verify-submodule-remote-sync.sh probes the declared .gitmodules URL
# only, so a lagging mirror (the design-toolkit GitLab lag the carriers record)
# is invisible to it. This class reads every configured remote. Findings:
#   gitlink:<p>@<r>            the gitlink differs from remote <r>'s tip (the
#                              .gitmodules `branch`, else HEAD): BEHIND, AHEAD
#                              (the remote lags / the pin is not on the clone
#                              URL's ref), DIVERGED, or DIFFERS with direction
#                              UNDETERMINED when the remote commit is absent from
#                              the submodule object store (never fetched here).
#   gitlink:<p>@<r>:pushurl<N> remote <r>'s N-th pushurl names a DIFFERENTLY
#                              NAMED repository than <r> fetches from (so an
#                              origin sync check does not cover pushes), or that
#                              pushurl's tip differs from the gitlink.
#   gitlink:<p>:gitmodules-url the .gitmodules clone URL, when no configured
#                              remote fetches it, differs from the gitlink.
#   gitlink:<p>                .gitmodules declares <p> but the index has no
#                              gitlink; or <p> has no helix-deps.yaml deps[] entry
#                              and is not documented third-party.
#   helix-deps:<name>          the recorded ref differs from the gitlink
#                              (verdict of scripts/verify-manifest-pins.sh), the
#                              entry has no ref, or it names a path with no gitlink.
#   carrier:<file>@<p>         <file> quotes commits of <p> and none of them is
#                              the current gitlink (the carrier quotes no current pin).
#                              The four carriers are kept in lockstep (§11.4.157):
#                              ONE finding per submodule, at the first stale carrier
#                              in the order CLAUDE AGENTS QWEN GEMINI, with an
#                              `also in <file>:<line> ...` list of the others.
# Evidence: a live finding cites .gitmodules (remote, pushurl and gitlink
# findings), helix-deps.yaml:<line> or <carrier>:<line> — always a regular file
# (a submodule directory is never cited); a corpus finding cites its scenario.
#
# ── Population (sweep-classes.tsv row, population_kind `wire`) ───────────────
# Derived at run time, never a roster: every `path` in .gitmodules
# (`gitlink:<p>`), crossed with every remote configured in that checkout
# (`gitlink:<p>@<r>`, from `git -C <p> remote`); every deps[] entry of
# helix-deps.yaml (`helix-deps:<name>`, parsed by verify-manifest-pins.sh's own
# manifest_entries); and every (carrier, submodule) pair where one of CLAUDE.md,
# AGENTS.md, QWEN.md, GEMINI.md quotes a hex token (7-40 chars) that resolves to
# a commit in that submodule's object store (`carrier:<file>@<p>`). Why: the
# pin can drift in each of those places, and a mirror is a remote like any other.
#
# ── Reuse, not a fork ────────────────────────────────────────────────────────
# * helix-deps.yaml is parsed by `manifest_entries`, extracted at run time from
#   scripts/verify-manifest-pins.sh, and the ref-vs-gitlink VERDICT is that
#   script's own (it is invoked with --root and its PASS/DRIFT/ENV line per dep
#   is read). A dep with no verdict line is COULD-NOT-INSPECT, never clean.
# * third-party gitlinks are classified by `helix_excluded_paths`, extracted at
#   run time from scripts/verify-governance-cascade.sh (the C1/C4/C6 rule).
# * the remote comparison follows scripts/verify-submodule-remote-sync.sh (index
#   gitlink vs `ls-remote` of the declared branch, else HEAD; direction only via
#   `merge-base --is-ancestor` when BOTH commits are local) across all remotes.
# If either extraction fails the class exits 2 (it never re-implements them).
#
# ── Network and safety ───────────────────────────────────────────────────────
# `git ls-remote` ONLY (never fetch/pull), run outside any repository on the
# URL `git remote get-url` expands, so no repository-config `uploadpack` runs.
# GIT_ALLOW_PROTOCOL=ssh:https:file is set by the class, so a git config that
# enables ext:: (or git://, http://) cannot turn a remote URL into a command:
# such a remote is COULD-NOT-INSPECT (--prove-failure C13 proves nothing runs).
# ssh: BatchMode, ConnectTimeout=10, StrictHostKeyChecking=yes, UpdateHostKeys=no,
# no ControlMaster (nothing is written to ~/.ssh). Each distinct URL is probed
# once, `timeout -k 2 20`, 8 in parallel, no new probe after a 150 s budget.
# A failed, timed-out, unauthenticated or skipped probe is COULD-NOT-INSPECT for
# that item (rc 2), never clean. Writes only under a mktemp dir in $TMPDIR.
#
# ── Usage and exit codes ─────────────────────────────────────────────────────
#   zero-gap-class-pointer-drift.sh --root <dir> [--emit-population]
#   zero-gap-class-pointer-drift.sh --root <dir> --corpus <dir>
#   zero-gap-class-pointer-drift.sh --prove-failure
# Output grammar: docs/zero-gap/README.md "The class contract".
# Exit 0 no finding over a full non-empty population; 1 at least one FINDING
# (outranks 2); 2 could not determine (a zero population, --root /nonexistent,
# git or a reused script missing, an unreachable remote). 2 is never a pass.
#
# ── Corpus scenario grammar (--corpus) ───────────────────────────────────────
# Each file under --corpus is one scenario; the class materialises it into a
# scratch umbrella under $TMPDIR with LOCAL bare repositories as remotes (no
# network, git config isolated) and reports `<file>:<location>`. One directive
# per line, fields blank-separated and percent-decoded (`be%20hind`), `#` comments:
#   sub <path> <n>                   submodule with commits c1..c<n> on main and x1
#                                    on a side branch forked at c1; origin = a bare
#                                    clone (the .gitmodules URL); gitlink c<n>
#   gmbranch <path> <branch> <c>     .gitmodules branch=<branch>, created at <c>
#   gitlink <path> <c>               set the index gitlink
#   remote <path> <name> <c|y1|unreachable> [<repo>]
#                                    add/repoint remote <name>, tip of the tracked
#                                    branch = <c>; y1 = a new commit made in that
#                                    remote only; <repo> = its repository name
#   nogitlink <path>                 remove the index gitlink (.gitmodules still declares it)
#   rawurl <path> <remote> <url>     add/repoint remote <name> to a literal URL (proof use:
#                                    a transport the class must refuse)
#   pushurl <path> <remote> <repo> [<c>]  add a pushurl to a bare named <repo>.git whose
#                                    tracked branch tip is <c> (default: the source tip)
#   nohead <path> <remote> [keep|empty]  that remote stops advertising HEAD (HEAD points
#                                    at a missing branch); without `keep` every branch
#                                    but the tracked one is deleted; `empty` deletes
#                                    every branch (no HEAD and no branch at all)
#   delref <path> <remote> <branch>  delete refs/heads/<branch> in that remote
#   dep <name> <flat|grouped> <c|sha:<hex>|none>   a helix-deps.yaml deps[] entry
#                                    (`none`: the entry records no ref line)
#   nomanifest                       write no helix-deps.yaml at all
#   thirdparty <path>                a helix-deps.yaml third-party comment line
#   carrier <file> <path> <c>        <file> quotes the 12-char sha of <c>
#
# ── Measured on the live tree (2026-09-26, after the review fix round) ───────
# rc 1 in 13 s over 132 items: 23 medium findings (was 35: the 16 carrier
# findings, 4 carriers x 4 submodules, are now 4 with `also in` lists) —
# 8 remotes of submodules/constitution DIFFER (direction undetermined), 4
# remotes of LLMProvider + llm_provider + llms_verifier BEHIND, 5 pushurl
# repository-name mismatches (milosvasic.ru, submodules/qa), 4 stale carrier
# quotes. Every finding is an ls-remote / index / file fact re-derivable with the
# command it names; whether a pushurl rename or a historical carrier SHA is a
# defect is an operator judgement the class does not make.
#
# ── What it does NOT see ─────────────────────────────────────────────────────
# * A remote's other refs: one ref per remote (declared branch, else HEAD).
# * A carrier sentence that states a stale pin while the same carrier quotes the
#   current gitlink elsewhere; and it cannot tell a pin claim from any other
#   commit reference (a quote is a commit of <p> resolvable in its object store).
# * Uninitialised submodules' remotes (COULD-NOT-INSPECT, not clean); nested
#   gitlinks inside submodules; only the first fetch URL of a remote.
# * Whether a remote tip is a GOOD commit; only that it is not the pinned one.
# * A remote's state after the probe: an ls-remote reading is dated to the run.
set -uo pipefail

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

# GIT_ALLOW_PROTOCOL is set EXPLICITLY (review minor): a user or system git config that enables a
# dangerous transport (protocol.ext.allow=always) must not turn a remote URL into a command. ssh and
# https are the fleet's transports, file the corpus's local bare repositories; ext, git and http are
# refused whatever the configuration says.
export LC_ALL=C LANG=C GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0 GIT_ALLOW_PROTOCOL=ssh:https:file
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
CLASS=pointer-drift
EMPTY_SHA=$(printf '' | sha256sum | cut -d' ' -f1)

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 || shift ;;
        --corpus) CORPUS="${2:-}"; shift 2 || shift ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure)
            PROVE=1; shift ;;
        -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
        *) echo "COULD-NOT-INSPECT - unknown argument"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; exit 2 ;;
    esac
done

# percent-decode one field
pdec() { printf '%b' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"; }

# ── corpus scenario builder (fixture infrastructure; isolated git config) ──
bgit() {
    env GIT_AUTHOR_NAME=zg GIT_AUTHOR_EMAIL=zg@example.invalid GIT_COMMITTER_NAME=zg \
        GIT_COMMITTER_EMAIL=zg@example.invalid GIT_AUTHOR_DATE='2026-01-01T00:00:00+0000' \
        GIT_COMMITTER_DATE='2026-01-01T00:00:00+0000' \
        git -c core.hooksPath=/dev/null -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}
# mkcommit <bare> <parent|-> <message> -> sha (tree holds one file with the message)
mkcommit() {
    local b=$1 p=$2 m=$3 blob tree
    blob=$(printf '%s\n' "$m" | bgit -C "$b" hash-object -w --stdin) || return 1
    tree=$(printf '100644 blob %s\tf\n' "$blob" | bgit -C "$b" mktree) || return 1
    if [ "$p" = - ]; then bgit -C "$b" commit-tree "$tree" -m "$m"
    else bgit -C "$b" commit-tree "$tree" -p "$p" -m "$m"; fi
}
# build_scenario <file> <dir> -> 0 and <dir>/root, or 2 with a reason on stderr
build_scenario() {
    local f=$1 W=$2 line d n k sha i path name tip repo bare url br layout ref kind rec
    local -a a L=() R=()
    local -A SYM=() SRC=() ORIG=() IDX=() GMB=() NREM=() RBARE=()
    local nsub=0 deps="" third="" noman=0 US=$'\x1f'
    mapfile -t L <"$f" || return 2
    for line in "${L[@]}"; do                       # parse and percent-decode ONCE
        line=${line%%#*}
        read -r -a a <<<"$line" || true
        [ "${#a[@]}" -gt 0 ] || continue
        for ((k = 0; k < ${#a[@]}; k++)); do case "${a[k]}" in *%*) a[k]=$(pdec "${a[k]}") ;; esac; done
        case "${a[0]}" in sub|gmbranch|gitlink|nogitlink|rawurl|remote|pushurl|nohead|delref|dep|nomanifest|thirdparty|carrier) ;;
            *) echo "unknown directive '${a[0]}'" >&2; return 2 ;; esac
        rec=""; for ((k = 0; k < ${#a[@]}; k++)); do rec+="${a[k]}$US"; done
        R+=("$rec")
    done
    bgit init -q "$W/root" || return 2
    for kind in sub gmbranch clone gitlink nogitlink remote rawurl pushurl nohead delref dep nomanifest thirdparty carrier; do
        if [ "$kind" = clone ]; then
            for path in "${!IDX[@]}"; do
                i=${IDX[$path]}; bare="$W/remotes/$i/origin/$(basename "$path").git"
                mkdir -p "$(dirname "$bare")" "$(dirname "$W/root/$path")" || return 2
                bgit clone -q --bare "${SRC[$path]}" "$bare" || return 2
                ORIG[$path]=$bare
                bgit clone -q --no-checkout "$bare" "$W/root/$path" || return 2
                bgit config -f "$W/root/.gitmodules" "submodule.$path.path" "$path" || return 2
                bgit config -f "$W/root/.gitmodules" "submodule.$path.url" "$bare" || return 2
                if [ -n "${GMB[$path]:-}" ]; then
                    bgit config -f "$W/root/.gitmodules" "submodule.$path.branch" "${GMB[$path]}" || return 2
                fi
                bgit -C "$W/root" update-index --add --cacheinfo "160000,${SYM["$path|default"]},$path" || return 2
            done
            continue
        fi
        for rec in "${R[@]}"; do
            IFS=$US read -r -a a <<<"$rec" || true
            [ "${a[0]}" = "$kind" ] || continue
            path=${a[1]:-}
            case "$kind" in
                sub)
                    n=${a[2]:-}
                    case "$n" in ''|*[!0-9]*|0) echo "sub needs <path> <n>" >&2; return 2 ;; esac
                    [ -z "${IDX[$path]:-}" ] || { echo "sub declared twice" >&2; return 2; }
                    i=$nsub; nsub=$((nsub + 1)); IDX[$path]=$i
                    SRC[$path]="$W/src/$i.git"; bgit init -q --bare "${SRC[$path]}" || return 2
                    sha=-
                    for ((k = 1; k <= n; k++)); do
                        sha=$(mkcommit "${SRC[$path]}" "$sha" "c$k $path") || return 2; SYM["$path|c$k"]=$sha
                    done
                    bgit -C "${SRC[$path]}" update-ref refs/heads/main "$sha" || return 2
                    SYM["$path|x1"]=$(mkcommit "${SRC[$path]}" "${SYM["$path|c1"]}" "x1 $path") || return 2
                    bgit -C "${SRC[$path]}" update-ref refs/heads/side "${SYM["$path|x1"]}" || return 2
                    SYM["$path|default"]=$sha ;;
                gmbranch)
                    br=${a[2]:-}; sha=${SYM["$path|${a[3]:-}"]:-}
                    [ -n "$sha" ] && [ -n "$br" ] || { echo "gmbranch: unknown sub or commit" >&2; return 2; }
                    bgit -C "${SRC[$path]}" update-ref "refs/heads/$br" "$sha" || return 2
                    GMB[$path]=$br ;;
                gitlink)
                    sha=${SYM["$path|${a[2]:-}"]:-}; [ -n "$sha" ] || { echo "gitlink: unknown commit" >&2; return 2; }
                    bgit -C "$W/root" update-index --cacheinfo "160000,$sha,$path" || return 2 ;;
                nogitlink)
                    [ -n "${IDX[$path]:-}" ] || { echo "nogitlink: unknown sub" >&2; return 2; }
                    bgit -C "$W/root" update-index --force-remove -- "$path" || return 2 ;;
                nomanifest) noman=1 ;;
                rawurl)
                    name=${a[2]:-}; url=${a[3]:-}
                    [ -n "${IDX[$path]:-}" ] && [ -n "$name" ] && [ -n "$url" ] || { echo "rawurl: bad fields" >&2; return 2; }
                    if bgit -C "$W/root/$path" remote get-url "$name" >/dev/null 2>&1; then
                        bgit -C "$W/root/$path" remote set-url "$name" "$url" || return 2
                    else bgit -C "$W/root/$path" remote add "$name" "$url" || return 2; fi ;;
                delref)
                    name=${a[2]:-}; br=${a[3]:-}; bare=${RBARE["$path|$name"]:-}
                    [ -n "$bare" ] && [ -d "$bare" ] && [ -n "$br" ] || { echo "delref: remote not declared by a remote directive" >&2; return 2; }
                    bgit -C "$bare" update-ref -d "refs/heads/$br" || return 2 ;;
                remote)
                    name=${a[2]:-}; tip=${a[3]:-}; repo=${a[4]:-}
                    [ -n "${IDX[$path]:-}" ] && [ -n "$name" ] && [ -n "$tip" ] || { echo "remote: bad fields" >&2; return 2; }
                    i=${IDX[$path]}; br=${GMB[$path]:-main}
                    NREM[$path]=$(( ${NREM[$path]:-0} + 1 ))
                    if [ "$name" = origin ] && [ -z "$repo" ]; then bare=${ORIG[$path]}
                    else bare="$W/remotes/$i/$name.${NREM[$path]}/${repo:-$(basename "$path")}.git"; fi
                    if [ "$tip" = unreachable ]; then
                        url="$W/remotes/$i/absent/$(basename "$path").git"
                    else
                        url=$bare
                        [ -d "$bare" ] || bgit clone -q --bare "${SRC[$path]}" "$bare" || return 2
                        if [ "$tip" = y1 ]; then
                            sha=$(bgit -C "$bare" rev-parse "refs/heads/$br") || return 2
                            sha=$(mkcommit "$bare" "$sha" "y1 $path $name") || return 2
                        else
                            sha=${SYM["$path|$tip"]:-}; [ -n "$sha" ] || { echo "remote: unknown tip" >&2; return 2; }
                        fi
                        bgit -C "$bare" update-ref "refs/heads/$br" "$sha" || return 2
                    fi
                    RBARE["$path|$name"]=$url
                    if bgit -C "$W/root/$path" remote get-url "$name" >/dev/null 2>&1; then
                        bgit -C "$W/root/$path" remote set-url "$name" "$url" || return 2
                    else
                        bgit -C "$W/root/$path" remote add "$name" "$url" || return 2
                    fi ;;
                pushurl)
                    name=${a[2]:-}; repo=${a[3]:-}
                    [ -n "${IDX[$path]:-}" ] && [ -n "$repo" ] || { echo "pushurl: bad fields" >&2; return 2; }
                    bare="$W/push/${IDX[$path]}/$repo.git"
                    [ -d "$bare" ] || bgit clone -q --bare "${SRC[$path]}" "$bare" || return 2
                    if [ -n "${a[4]:-}" ]; then
                        sha=${SYM["$path|${a[4]}"]:-}; [ -n "$sha" ] || { echo "pushurl: unknown tip" >&2; return 2; }
                        bgit -C "$bare" update-ref "refs/heads/${GMB[$path]:-main}" "$sha" || return 2
                    fi
                    bgit -C "$W/root/$path" config --add "remote.$name.pushurl" "$bare" || return 2 ;;
                nohead)
                    name=${a[2]:-}; bare=${RBARE["$path|$name"]:-}
                    [ -n "$bare" ] && [ -d "$bare" ] || { echo "nohead: remote not declared by a remote directive" >&2; return 2; }
                    br=${GMB[$path]:-main}
                    if [ "${a[3]:-}" != keep ]; then
                        bgit -C "$bare" for-each-ref --format='%(refname)' refs/heads/ | while IFS= read -r ref; do
                            [ "$ref" = "refs/heads/$br" ] && [ "${a[3]:-}" != empty ] || bgit -C "$bare" update-ref -d "$ref"; done
                    fi
                    bgit -C "$bare" symbolic-ref HEAD refs/heads/zg-absent || return 2 ;;
                dep)
                    name=$path; layout=${a[2]:-}; ref=${a[3]:-}
                    if [ "$layout" = grouped ]; then path="submodules/$name"; else path=$name; fi
                    case "$ref" in sha:*) ref=${ref#sha:} ;; none) ref=none ;; *) ref=${SYM["$path|$ref"]:-} ;; esac
                    [ -n "$ref" ] || { echo "dep: unknown ref" >&2; return 2; }
                    if [ "$ref" = none ]; then
                        deps+=$(printf '  - name: "%s"\n    ssh_url: git@example.invalid:zg/%s.git\n    layout: %s' \
                            "$name" "$(basename "$name")" "$layout")$'\n'
                    else
                        deps+=$(printf '  - name: "%s"\n    ssh_url: git@example.invalid:zg/%s.git\n    ref: "%s"\n    layout: %s' \
                            "$name" "$(basename "$name")" "$ref" "$layout")$'\n'
                    fi ;;
                thirdparty)
                    third+="#   $path  -> git@example.invalid:vendor/$(basename "$path").git"$'\n' ;;
                carrier)
                    name=$path; path=${a[2]:-}; sha=${SYM["$path|${a[3]:-}"]:-}
                    [ -n "$sha" ] || { echo "carrier: unknown commit" >&2; return 2; }
                    printf 'pin of %s: `%s`\n' "$path" "${sha:0:12}" >>"$W/root/$name" || return 2 ;;
            esac
        done
    done
    [ "$noman" -eq 1 ] && return 0
    printf '# scratch manifest (pointer-drift corpus)\nschema_version: 1\ndeps:\n%s\n# third-party gitlinks\n%s' \
        "$deps" "$third" >"$W/root/helix-deps.yaml" || return 2
    return 0
}

# ── the class ──
PROBE_TIMEOUT=20 PROBE_PAR=8 PROBE_BUDGET=150
CARRIER_FILES="AGENTS.md CLAUDE.md GEMINI.md QWEN.md"   # the four root carriers (§11.4.157)
SSH_CMD='ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ControlMaster=no -o ControlPath=none'
EMDASH=$(printf '\342\200\224')

# enc <raw> -> canonical token (fast path when every byte is already safe)
enc() { if [[ $1 =~ ^[A-Za-z0-9._~/+:@,=-]+$ ]]; then printf '%s' "$1"; else zg_pct_encode "$1"; fi; }
s12() { printf '%s' "${1:0:12}"; }
repo_name() { local u=${1%/}; u=${u%.git}; u=${u##*/}; u=${u##*:}; printf '%s' "$u" | tr 'A-Z' 'a-z'; }

# load_reuse: the manifest parser and the third-party rule come from the scripts that own them
load_reuse() {
    local f="$HERE/verify-manifest-pins.sh" g="$HERE/verify-governance-cascade.sh" body
    [ -r "$f" ] && [ -r "$g" ] || return 1
    body=$(sed -n '/^manifest_entries() {$/,/^}$/p' "$f"); [ -n "$body" ] || return 1
    eval "$body" || return 1
    body=$(sed -n '/^helix_excluded_paths() {$/,/^}$/p' "$g"); [ -n "$body" ] || return 1
    eval "$body" || return 1
    declare -F manifest_entries >/dev/null && declare -F helix_excluded_paths >/dev/null
}

# enumerate <root> -> 0 (state filled, $WK/pop = sorted tokens) | 2 (ENUM_WHY)
enumerate() {
    local R=$1 rec key val name p r f t tok n pth ref ln sha typ k
    GM_PATHS=(); DEP_NAMES=(); CPAIRS=()
    declare -gA GM_URL=() GM_BR=() INIT=() GL=() REMS=() DEP_PATH=() DEP_REF=() DEP_LINE=() DEP_BYPATH=() EXCLSET=() CPAIR_Q=() CPAIR_T=() CPAIR_LINE=() SEEN=()
    HD_OK=0; ENUM_WHY=""
    git --version >/dev/null 2>&1 || { ENUM_WHY="git is absent or does not run"; return 2; }
    load_reuse || { ENUM_WHY="cannot load manifest_entries (scripts/verify-manifest-pins.sh) and helix_excluded_paths (scripts/verify-governance-cascade.sh): the class reuses them and never re-implements them"; return 2; }
    t=$(git -C "$R" rev-parse --show-toplevel 2>/dev/null) && [ "$(cd "$t" 2>/dev/null && pwd -P)" = "$R" ] \
        || { ENUM_WHY="--root is not the top level of a git work tree (no index gitlinks to read)"; return 2; }
    if [ -e "$R/.gitmodules" ]; then
        git config -f "$R/.gitmodules" --list >/dev/null 2>&1 || { ENUM_WHY=".gitmodules exists but git cannot parse it"; return 2; }
        while IFS= read -r -d '' rec; do
            key=${rec%%$'\n'*}; val=${rec#*$'\n'}; name=${key#submodule.}; name=${name%.path}
            [ -n "$val" ] && [ -z "${SEEN[$val]:-}" ] || continue
            SEEN[$val]=1; GM_PATHS+=("$val")
            GM_URL[$val]=$(git config -f "$R/.gitmodules" --get "submodule.$name.url" 2>/dev/null) || GM_URL[$val]=""
            GM_BR[$val]=$(git config -f "$R/.gitmodules" --get "submodule.$name.branch" 2>/dev/null) || GM_BR[$val]=""
        done < <(git config -z -f "$R/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null)
    fi
    for p in "${GM_PATHS[@]}"; do
        GL[$p]=$(git --literal-pathspecs -C "$R" ls-files -s -- "$p" 2>/dev/null | awk '$1 == "160000" { print $2; exit }')
        INIT[$p]=0
        if [ -e "$R/$p/.git" ] && t=$(git -C "$R/$p" rev-parse --show-toplevel 2>/dev/null) \
           && [ "$(cd "$t" 2>/dev/null && pwd -P)" = "$(cd "$R/$p" 2>/dev/null && pwd -P)" ]; then
            if REMS[$p]=$(git -C "$R/$p" remote 2>/dev/null | LC_ALL=C sort -u); then INIT[$p]=1; else INIT[$p]=2; REMS[$p]=""; fi
        fi
    done
    if [ -e "$R/helix-deps.yaml" ]; then
        if [ -r "$R/helix-deps.yaml" ]; then
            HD_OK=1
            while IFS=$'\t' read -r n pth ref; do
                [ -n "$n" ] && [ -z "${DEP_PATH[$n]:-}" ] || continue
                DEP_NAMES+=("$n"); DEP_PATH[$n]=$pth; DEP_REF[$n]=$ref; DEP_BYPATH[$pth]=$n
                ln=$(awk -v n="$n" '/^[[:space:]]*-[[:space:]]*name[[:space:]]*:/ && index($0, n) { print NR; exit }' "$R/helix-deps.yaml")
                DEP_LINE[$n]=${ln:-1}
            done < <(manifest_entries "$R/helix-deps.yaml")
            while IFS= read -r p; do [ -n "$p" ] && EXCLSET[$p]=1; done < <(helix_excluded_paths "$R/helix-deps.yaml")
        else HD_OK=2; fi
    fi
    # carrier quotes: hex tokens that resolve to a commit in an initialised submodule
    : >"$WK/quotes"
    for f in $CARRIER_FILES; do
        [ -f "$R/$f" ] || continue
        grep -noE '\<[0-9a-f]{7,40}\>' "$R/$f" 2>/dev/null | awk -v f="$f" -F: '{ print f "\t" $1 "\t" $2 }' >>"$WK/quotes"
    done
    if [ -s "$WK/quotes" ]; then
        cut -f3 "$WK/quotes" | LC_ALL=C sort -u >"$WK/toks"
        sed 's/$/^{commit}/' "$WK/toks" >"$WK/toks.q"
        for p in "${GM_PATHS[@]}"; do
            [ "${INIT[$p]}" = 1 ] || continue
            git -C "$R/$p" cat-file --batch-check='%(objectname) %(objecttype)' <"$WK/toks.q" >"$WK/res" 2>/dev/null || continue
            unset RES; declare -A RES=()
            while IFS=$'\t' read -r tok rec; do
                sha=${rec%% *}; typ=${rec#* }
                [ "$typ" = commit ] && RES[$tok]=$sha
            done < <(paste "$WK/toks" "$WK/res")
            [ "${#RES[@]}" -gt 0 ] || continue
            while IFS=$'\t' read -r f ln tok; do
                sha=${RES[$tok]:-}; [ -n "$sha" ] || continue
                k="$f|$p"
                if [ -z "${CPAIR_Q[$k]:-}" ]; then CPAIRS+=("$k"); CPAIR_LINE[$k]=$ln; fi
                case " ${CPAIR_Q[$k]:-} " in *" $sha "*) ;; *) CPAIR_Q[$k]+=" $sha"; CPAIR_T[$k]+=" $tok" ;; esac
            done <"$WK/quotes"
        done
    fi
    {
        for p in "${GM_PATHS[@]}"; do
            printf 'gitlink:%s\0' "$p"
            if [ "${INIT[$p]}" = 1 ]; then
                while IFS= read -r r; do [ -n "$r" ] && printf 'gitlink:%s@%s\0' "$p" "$r"; done <<<"${REMS[$p]}"
            fi
        done
        for n in "${DEP_NAMES[@]}"; do printf 'helix-deps:%s\0' "$n"; done
        for k in "${CPAIRS[@]}"; do printf 'carrier:%s@%s\0' "${k%%|*}" "${k#*|}"; done
    } | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u >"$WK/pop"
    return 0
}

# result collection
add_find() { # <sev> <cat> <raw location> <description> <raw evidence>
    local d; d=$(printf '%s' "$4" | tr -d '\000-\037\177' | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null)
    FIND+=("$(enc "$3")"$'\t'"$1"$'\t'"$2"$'\t'"$d"$'\t'"$(enc "$5")")
}
add_cni() { # <raw item> <raw part> <reason>
    local d; d=$(printf '%s' "$3" | tr -d '\000-\037\177' | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null)
    CNI+=("$(enc "$2")"$'\t'"$d"); FAILED[$1]=1
}

# probes: distinct (url, ref) pairs, ls-remote only, outside any repository
queue_probe() { # <url> -> PIDX (every advertised ref of <url> is listed once)
    local key=$1
    if [ -z "${PROBE_OF[$key]:-}" ]; then
        PROBE_OF[$key]=$NPROBE
        printf '%s' "$1" >"$WK/probe/$NPROBE.url"
        NPROBE=$((NPROBE + 1))
    fi
    PIDX=${PROBE_OF[$key]}
}
run_probes() {
    local dl
    [ "$NPROBE" -gt 0 ] || return 0
    dl=$(( $(date +%s) + PROBE_BUDGET ))
    seq 0 $((NPROBE - 1)) | xargs -P "$PROBE_PAR" -I{} bash -c '
        d=$1 i=$2 dl=$3 to=$4
        if [ "$(date +%s)" -ge "$dl" ]; then echo budget >"$d/$i.rc"; exit 0; fi
        cd "$d/cwd" || { echo cwd >"$d/$i.rc"; exit 0; }
        GIT_CEILING_DIRECTORIES="$d" timeout -k 2 "$to" git ls-remote "$(cat "$d/$i.url")" >"$d/$i.out" 2>"$d/$i.err"
        echo "$?" >"$d/$i.rc"; exit 0' _ "$WK/probe" {} "$dl" "$PROBE_TIMEOUT"
}

# analyse <root> (after enumerate): fills FIND, CNI, INSP
analyse() {
    local R=$1 p r n k f G url ref br third sev pfx item loc label kind idx N rc tip dir hl hr why fname pn i ev
    local -a PU PX CHECKS=()
    declare -gA FAILED=() PROBE_OF=() FETCHSET=()
    FIND=(); CNI=(); NPROBE=0; INSP=0
    rm -rf "$WK/probe"; mkdir -p "$WK/probe/cwd"
    for p in "${GM_PATHS[@]}"; do
        item="gitlink:$p"; G=${GL[$p]}
        third=0; [ -n "${EXCLSET[$p]:-}" ] && third=1
        if [ -z "$G" ]; then
            add_find medium governance-drift "$item" ".gitmodules declares $p but the index holds no gitlink at that path (nothing is pinned)" "$(ev .gitmodules)"
        fi
        case "$HD_OK" in
            1) if [ -z "${DEP_BYPATH[$p]:-}" ] && [ "$third" -eq 0 ]; then
                   add_find medium governance-drift "$item" "gitlink $p has no helix-deps.yaml deps[] entry and is not documented third-party in its exclusion block (§11.4.31, the C6 rule of verify-governance-cascade.sh)" "$(ev helix-deps.yaml)"
               fi ;;
            0) add_find medium governance-drift "$item" "helix-deps.yaml is absent, so gitlink $p has no deps[] entry (§11.4.31)" "$(ev .gitmodules)" ;;
            *) add_cni "$item" "$item" "helix-deps.yaml exists but is unreadable: deps[] membership of $p undetermined" ;;
        esac
        if [ "${INIT[$p]}" != 1 ]; then
            if [ "${INIT[$p]}" = 2 ]; then add_cni "$item" "$item" "git -C $p remote failed: its configured remotes cannot be enumerated"
            else add_cni "$item" "$item" "not initialised (no checkout at $p): its configured remotes cannot be enumerated, so no remote was compared"; fi
            continue
        fi
        if [ -z "${REMS[$p]}" ]; then add_cni "$item" "$item" "checkout $p configures no remote: the gitlink cannot be compared with any remote"; fi
        br=${GM_BR[$p]}; if [ -n "$br" ]; then ref="refs/heads/$br"; else ref=HEAD; fi
        while IFS= read -r r; do
            [ -n "$r" ] || continue
            if [ -z "$G" ]; then add_cni "gitlink:$p@$r" "gitlink:$p@$r" "no gitlink in the index to compare with remote $r"; continue; fi
            if ! url=$(git -C "$R/$p" remote get-url "$r" 2>/dev/null) || [ -z "$url" ]; then add_cni "gitlink:$p@$r" "gitlink:$p@$r" "remote $r has no readable fetch URL"; continue; fi
            case "$url" in -*) add_cni "gitlink:$p@$r" "gitlink:$p@$r" "remote $r fetch URL begins with '-': refused, not probed"; continue ;; esac
            FETCHSET["$p|$url"]=1
            queue_probe "$url"; CHECKS+=("fetch"$'\t'"$p"$'\t'"$r"$'\t'"$url"$'\t'"$ref"$'\t'"$PIDX"$'\t'"-")
        done <<<"${REMS[$p]}"
        [ -n "$G" ] || continue
        while IFS= read -r r; do
            [ -n "$r" ] || continue
            mapfile -t PU < <(git -C "$R/$p" config --get-all "remote.$r.pushurl" 2>/dev/null)
            [ "${#PU[@]}" -gt 0 ] || continue
            mapfile -t PX < <(git -C "$R/$p" remote get-url --push --all "$r" 2>/dev/null)
            [ "${#PX[@]}" -eq "${#PU[@]}" ] || PX=("${PU[@]}")
            url=$(git -C "$R/$p" remote get-url "$r" 2>/dev/null) || url=""
            fname=$(repo_name "$url")
            for ((i = 0; i < ${#PX[@]}; i++)); do
                N=$((i + 1)); pn=$(repo_name "${PX[i]}")
                pfx=""; sev=medium; if [ "$third" -eq 1 ]; then pfx="third-party (helix-deps.yaml exclusion block), reported not gating: "; sev=low; fi
                if [ -n "$fname" ] && [ "$pn" != "$fname" ]; then
                    add_find "$sev" governance-drift "gitlink:$p@$r:pushurl$N" "${pfx}remote $r pushes (pushurl $N) to repository name '$pn' but fetches from '$fname': an origin sync check does not cover pushes to that repository" "$(ev .gitmodules)"
                fi
                case "${PX[i]}" in -*) add_cni "gitlink:$p@$r" "gitlink:$p@$r:pushurl$N" "pushurl $N begins with '-': refused, not probed"; continue ;; esac
                if [ -z "${FETCHSET["$p|${PX[i]}"]:-}" ]; then
                    queue_probe "${PX[i]}"; CHECKS+=("push"$'\t'"$p"$'\t'"$r"$'\t'"${PX[i]}"$'\t'"$ref"$'\t'"$PIDX"$'\t'"$N")
                fi
            done
        done <<<"${REMS[$p]}"
        url=${GM_URL[$p]}
        if [ -n "$url" ] && [ -z "${FETCHSET["$p|$url"]:-}" ]; then
            case "$url" in
                -*) add_cni "$item" "gitlink:$p:gitmodules-url" "the .gitmodules URL begins with '-': refused, not probed" ;;
                *) queue_probe "$url"; CHECKS+=("gm"$'\t'"$p"$'\t'"-"$'\t'"$url"$'\t'"$ref"$'\t'"$PIDX"$'\t'"-") ;;
            esac
        fi
    done
    run_probes
    for k in "${CHECKS[@]}"; do
        IFS=$'\t' read -r kind p r url ref idx N <<<"$k"
        G=${GL[$p]}; third=0; [ -n "${EXCLSET[$p]:-}" ] && third=1
        case "$kind" in
            fetch) item="gitlink:$p@$r"; loc=$item; label="remote $r" ;;
            push) item="gitlink:$p@$r"; loc="$item:pushurl$N"; label="remote $r pushurl $N" ;;
            *) item="gitlink:$p"; loc="$item:gitmodules-url"; label="the .gitmodules URL (fetched by no configured remote)" ;;
        esac
        rc=$(cat "$WK/probe/$idx.rc" 2>/dev/null) || rc=missing
        if [ "$rc" = budget ]; then add_cni "$item" "$loc" "$label not probed: the ${PROBE_BUDGET}s probe budget ran out"; continue; fi
        if [ "$rc" != 0 ]; then
            case "$rc" in 124|137) why="timed out after ${PROBE_TIMEOUT}s" ;; *) why="git ls-remote exited $rc (offline, authentication refused and repository gone are indistinguishable here)" ;; esac
            add_cni "$item" "$loc" "$label could not be read: $why; never read as current"; continue
        fi
        tip=$(awk -F'\t' -v r="$ref" '$2 == r { print $1; exit }' "$WK/probe/$idx.out")
        pfx=""; sev=medium; if [ "$third" -eq 1 ]; then pfx="third-party (helix-deps.yaml exclusion block), reported not gating: "; sev=low; fi
        if [ -z "$tip" ] && [ "$ref" = HEAD ]; then
            # HEAD not advertised: the remote's only branch is its line; several branches => undetermined
            n=$(awk -F'\t' '$2 ~ /^refs\/heads\// { c++ } END { print c + 0 }' "$WK/probe/$idx.out")
            if [ "$n" -eq 1 ]; then
                tip=$(awk -F'\t' '$2 ~ /^refs\/heads\// { print $1; exit }' "$WK/probe/$idx.out")
                ref="$(awk -F'\t' '$2 ~ /^refs\/heads\// { print $2; exit }' "$WK/probe/$idx.out") (its only branch; HEAD not advertised)"
            elif [ "$n" -gt 1 ]; then
                add_cni "$item" "$loc" "$label advertises no HEAD and $n branches: its default line is undetermined, so the pin was not compared"; continue
            else
                add_find "$sev" governance-drift "$loc" "${pfx}$label advertises no HEAD and no branch (ls-remote succeeded): it carries no line holding the pin $(s12 "$G")" "$(ev .gitmodules)"; continue
            fi
        elif [ -z "$tip" ]; then
            add_find "$sev" governance-drift "$loc" "${pfx}$label has no $ref, the branch .gitmodules declares (ls-remote succeeded; the ref is absent)" "$(ev .gitmodules)"; continue
        fi
        [ "$tip" != "$G" ] || continue
        dir=DIFFERS; hl=0; hr=0
        git -C "$R/$p" cat-file -e "$G^{commit}" 2>/dev/null && hl=1
        git -C "$R/$p" cat-file -e "$tip^{commit}" 2>/dev/null && hr=1
        if [ "$hl" -eq 1 ] && [ "$hr" -eq 1 ]; then
            if git -C "$R/$p" merge-base --is-ancestor "$G" "$tip" 2>/dev/null; then dir=BEHIND
            elif git -C "$R/$p" merge-base --is-ancestor "$tip" "$G" 2>/dev/null; then dir=AHEAD
            else dir=DIVERGED; fi
        fi
        case "$dir" in
            BEHIND) add_find "$sev" governance-drift "$loc" "${pfx}gitlink $(s12 "$G") is behind $label ($ref $(s12 "$tip")): the gitlink is an ancestor of the remote tip (fast-forwardable)" "$(ev .gitmodules)" ;;
            AHEAD)
                if [ "$kind" = gm ] || { [ "$kind" = fetch ] && [ "$url" = "${GM_URL[$p]}" ]; }; then
                    [ "$third" -eq 1 ] || sev=high
                    add_find "$sev" availability "$loc" "${pfx}gitlink $(s12 "$G") is not on $ref of the .gitmodules clone URL: $label tip $(s12 "$tip") is an ancestor of it (the pinned commit is unpushed to that ref)" "$(ev .gitmodules)"
                else
                    add_find "$sev" governance-drift "$loc" "${pfx}$label lags the gitlink: its $ref tip $(s12 "$tip") is an ancestor of the gitlink $(s12 "$G") (mirror lag)" "$(ev .gitmodules)"
                fi ;;
            DIVERGED) add_find "$sev" governance-drift "$loc" "${pfx}gitlink $(s12 "$G") and $label $ref tip $(s12 "$tip") diverged: neither is an ancestor of the other (operator reconciliation)" "$(ev .gitmodules)" ;;
            *)  if [ "$hr" -eq 0 ]; then why="the remote tip is not in the $p object store"; else why="the pinned commit is not in the $p object store"; fi
                add_find "$sev" governance-drift "$loc" "${pfx}gitlink $(s12 "$G") differs from $label $ref tip $(s12 "$tip"); direction UNDETERMINED: $why (ls-remote only, nothing fetched); git -C $p merge-base --is-ancestor classifies it once both commits are present" "$(ev .gitmodules)" ;;
        esac
    done
    # helix-deps.yaml: the verdict of verify-manifest-pins.sh per dep
    if [ "${#DEP_NAMES[@]}" -gt 0 ]; then
        local vout vrc=0 vl
        vout=$(bash "$HERE/verify-manifest-pins.sh" --root "$R" 2>&1) || vrc=$?
        for n in "${DEP_NAMES[@]}"; do
            item="helix-deps:$n"
            if [ "$vrc" -gt 2 ]; then add_cni "$item" "$item" "scripts/verify-manifest-pins.sh exited $vrc"; continue; fi
            vl=$(awk -v k="PIN-SYNC $n $EMDASH " 'index($0, k) { print; exit }' <<<"$vout")
            p=${DEP_PATH[$n]}; G=$(git --literal-pathspecs -C "$R" ls-files -s -- "$p" 2>/dev/null | awk '$1 == "160000" { print $2; exit }')
            case "$vl" in
                *"PASS  PIN-SYNC "*) ;;
                *"DRIFT PIN-SYNC "*) add_find high governance-drift "$item" "helix-deps.yaml records $(s12 "${DEP_REF[$n]}") for dep $n (path $p) but the index gitlink is $(s12 "$G"): the recorded pin drifted (scripts/verify-manifest-pins.sh DRIFT)" "$(ev "helix-deps.yaml:${DEP_LINE[$n]}")" ;;
                *"ENV   PIN-SYNC "*"no gitlink at"*) add_find medium governance-drift "$item" "helix-deps.yaml deps[] entry $n names path $p, which has no gitlink in the index (a dep .gitmodules does not pin)" "$(ev "helix-deps.yaml:${DEP_LINE[$n]}")" ;;
                *"ENV   PIN-SYNC "*"no 'ref:' recorded"*) add_find medium governance-drift "$item" "helix-deps.yaml deps[] entry $n records no ref (§11.4.31 requires one)" "$(ev "helix-deps.yaml:${DEP_LINE[$n]}")" ;;
                *"ENV   PIN-SYNC "*) add_cni "$item" "$item" "scripts/verify-manifest-pins.sh could not determine dep $n (ENV: symbolic ref unresolvable or submodule not initialised)" ;;
                *) add_cni "$item" "$item" "scripts/verify-manifest-pins.sh printed no verdict for dep $n (exit $vrc)" ;;
            esac
        done
    fi
    # carriers: a quoted commit of <p> that is the current gitlink. The four root carriers are
    # kept in LOCKSTEP (§11.4.157), so a stale quote is normally present in all four: ONE finding per
    # submodule, at the first stale carrier in the order CLAUDE AGENTS QWEN GEMINI, naming the other
    # stale carriers (file:line) in an `also in` list (review fix 3). Every pair stays a population item.
    local -A STALE_OF=()
    local -a STALE_P=()
    for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do
        for k in "${CPAIRS[@]}"; do
            [ "${k%%|*}" = "$f" ] || continue
            p=${k#*|}; item="carrier:$f@$p"; G=${GL[$p]}
            if [ -z "$G" ]; then add_cni "$item" "$item" "no gitlink in the index for $p to compare the carrier quotes with"; continue; fi
            case "${CPAIR_Q[$k]} " in *" $G "*) continue ;; esac
            [ -n "${STALE_OF[$p]:-}" ] || STALE_P+=("$p")
            STALE_OF[$p]+="$k"$'\n'
        done
    done
    for p in "${STALE_P[@]}"; do
        local first="" also="" kk
        while IFS= read -r kk; do
            [ -n "$kk" ] || continue
            if [ -z "$first" ]; then first=$kk; else also+=" ${kk%%|*}:${CPAIR_LINE[$kk]}"; fi
        done <<<"${STALE_OF[$p]}"
        f=${first%%|*}; G=${GL[$p]}
        n=$(wc -w <<<"${CPAIR_Q[$first]}")
        [ -z "$also" ] || also="; also in$(tr ' ' '\n' <<<"$also" | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//; s/^/ /')"
        add_find medium docs-drift "carrier:$f@$p" "$f quotes $n commit(s) of $p ($(tr ' ' '\n' <<<"${CPAIR_T[$first]}" | sed '/^$/d' | head -n 4 | tr '\n' ' ' | sed 's/ $//')), none of which is the current gitlink $(s12 "$G"): the carrier quotes no current pin of $p$also" "$(ev "$f:${CPAIR_LINE[$first]}")"
    done
}

# ev <raw evidence> -> evidence token source (live: the path; corpus: the scenario file)
ev() { if [ -n "${SCN_TOK:-}" ]; then printf '%s' "$SCN_TOK"; else printf '%s' "$1"; fi; }

finish_failed() { # map raw FAILED items to encoded tokens
    local x; declare -gA FAILEDENC=()
    for x in "${!FAILED[@]}"; do FAILEDENC[$(enc "$x")]=1; done
}

print_result() { # <inspected> <population sha>; exit code from the lines
    local l nf=0 nc=0
    if [ "${#FIND[@]}" -gt 0 ]; then
        printf '%s\n' "${FIND[@]}" | LC_ALL=C sort -u | while IFS=$'\t' read -r loc sev cat d ref; do
            printf 'FINDING %s %s %s %s %s %s\n' "$CLASS" "$sev" "$cat" "$loc" "$d" "$ref"; done
        nf=${#FIND[@]}
    fi
    if [ "${#CNI[@]}" -gt 0 ]; then
        printf '%s\n' "${CNI[@]}" | LC_ALL=C sort -u | while IFS=$'\t' read -r part d; do
            printf 'COULD-NOT-INSPECT %s %s\n' "$part" "$d"; done
        nc=${#CNI[@]}
    fi
    echo "INSPECTED $1"
    echo "POPULATION-SHA $2"
    if [ "$nf" -gt 0 ]; then return 1; fi
    if [ "$nc" -gt 0 ]; then return 2; fi
    return 0
}

main() {
    local out
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
        echo "COULD-NOT-INSPECT - --root is not a directory"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2
    fi
    ROOT=$(cd "$ROOT" && pwd -P)
    WK=$(mktemp -d "${TMPDIR:-/tmp}/zg-pointer-drift.XXXXXX") || {
        echo "COULD-NOT-INSPECT - no scratch directory under TMPDIR"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2; }
    PD_CLEAN=$WK; trap 'rm -rf "$PD_CLEAN"' EXIT INT TERM
    export GIT_SSH_COMMAND="$SSH_CMD"
    if [ -n "$CORPUS" ]; then corpus_main; return $?; fi
    SCN_TOK=""
    if ! enumerate "$ROOT"; then
        [ "$EMIT" -eq 1 ] && { echo "pointer-drift: $ENUM_WHY" >&2; return 2; }
        FIND=(); CNI=("-"$'\t'"$ENUM_WHY"); print_result 0 "$EMPTY_SHA"; return $?
    fi
    if [ "$EMIT" -eq 1 ]; then cat "$WK/pop"; return 0; fi
    if [ ! -s "$WK/pop" ]; then
        FIND=(); CNI=("-"$'\t'"population enumerated to zero items (no gitlink, no deps[] entry, no carrier quote): a class that inspects nothing is never clean")
        print_result 0 "$EMPTY_SHA"; return $?
    fi
    analyse "$ROOT"; finish_failed
    INSP=0; while IFS= read -r out; do [ -z "${FAILEDENC[$out]:-}" ] && INSP=$((INSP + 1)); done <"$WK/pop"
    print_result "$INSP" "$(sha256sum <"$WK/pop" | cut -d' ' -f1)"
}

corpus_main() {
    local rel tok WS R n=0 okn=0 l f loc sev cat d ref part
    local -a AF=() AC=()
    if [ ! -d "$CORPUS" ]; then FIND=(); CNI=("-"$'\t'"--corpus is not a directory"); print_result 0 "$EMPTY_SHA"; return $?; fi
    CORPUS=$(cd "$CORPUS" && pwd -P)
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    ( cd "$CORPUS" && find . -type f -print0 ) | sed -z 's|^\./||' | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u >"$WK/cpop"
    if [ ! -s "$WK/cpop" ]; then FIND=(); CNI=("-"$'\t'"the corpus holds no scenario file: zero population is never clean"); print_result 0 "$EMPTY_SHA"; return $?; fi
    while IFS= read -r tok; do
        n=$((n + 1)); rel=$(pdec "$tok")
        WS=$(mktemp -d "$WK/scn.XXXXXX") || { AC+=("$tok"$'\t'"no scratch directory"); continue; }
        if ! build_scenario "$CORPUS/$rel" "$WS" 2>"$WK/berr"; then
            AC+=("$tok"$'\t'"scenario could not be materialised: $(head -n 1 "$WK/berr" | tr -d '\000-\037\177' | cut -c1-160)"); rm -rf "$WS"; continue
        fi
        R=$(cd "$WS/root" && pwd -P); SCN_TOK=$tok
        if ! enumerate "$R"; then AC+=("$tok"$'\t'"$ENUM_WHY"); rm -rf "$WS"; continue; fi
        if [ ! -s "$WK/pop" ]; then AC+=("$tok"$'\t'"scenario population is empty"); rm -rf "$WS"; continue; fi
        analyse "$R"
        for l in "${FIND[@]}"; do IFS=$'\t' read -r loc sev cat d ref <<<"$l"; AF+=("$tok:$loc"$'\t'"$sev"$'\t'"$cat"$'\t'"$d"$'\t'"$ref"); done
        for l in "${CNI[@]}"; do IFS=$'\t' read -r part d <<<"$l"; AC+=("$tok:$part"$'\t'"$d"); done
        [ "${#CNI[@]}" -eq 0 ] && okn=$((okn + 1))
        rm -rf "$WS"
    done <"$WK/cpop"
    SCN_TOK=""; FIND=("${AF[@]}"); CNI=("${AC[@]}")
    print_result "$okn" "$(sha256sum <"$WK/cpop" | cut -d' ' -f1)"
}

# ── paired proof: throwaway copies only; no network ──
prove() {
    local T LIVE CORP pass=0 fail=0 out rc fpb fpa got want
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-pointer-drift-proof.XXXXXX") || { echo "UNDETERMINED: no sandbox"; return 2; }
    PD_CLEAN=$T; trap 'rm -rf "$PD_CLEAN"' EXIT INT TERM
    LIVE=$(cd "$HERE/.." && pwd -P); CORP="$LIVE/_tests/fixtures/zero-gap/pointer-drift"
    ok() { pass=$((pass + 1)); echo "PASS $1"; }
    bad() { fail=$((fail + 1)); echo "FAIL $1"; }
    fp() { { sha256sum "$SELF"; find "$CORP" -type f -printf '%p %s %T@ %i\n' | sort; ( cd "$CORP" && find . -type f -print0 | sort -z | xargs -0 sha256sum ); \
             git -C "$LIVE" ls-files -s -- scripts/zero-gap-class-pointer-drift.sh _tests/fixtures/zero-gap/pointer-drift; git -C "$LIVE" rev-parse HEAD; } 2>&1 | sha256sum | cut -d' ' -f1; }
    run() { rc=0; out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C bash "$@" 2>"$T/err") || rc=$?; }
    mkdir -p "$T/tmp"
    [ -d "$CORP/planted" ] && [ -d "$CORP/clean" ] && [ -f "$CORP/expect.tsv" ] || { echo "UNDETERMINED: corpus missing at $CORP"; return 2; }
    fpb=$(fp)
    cp -R "$CORP" "$T/corpus"
    # C1 control
    run "$SELF" --root "$LIVE" --corpus "$T/corpus/clean"
    if [ "$rc" -eq 0 ] && ! grep -qE '^(FINDING|COULD-NOT-INSPECT) ' <<<"$out" && grep -qx 'INSPECTED 2' <<<"$out"; then ok "C1 clean corpus => rc 0, no finding, INSPECTED 2"
    else bad "C1 clean corpus rc=$rc: $(head -c 400 <<<"$out")"; fi
    # C2 planted: exact recall, no unexpected, no undetermined
    run "$SELF" --root "$LIVE" --corpus "$T/corpus/planted"
    got=$(awk '$1 == "FINDING" { print $5 }' <<<"$out" | sort -u)
    want=$(grep -v '^#' "$T/corpus/expect.tsv" | cut -f1 | sed '/^$/d' | sort -u)
    if [ "$rc" -eq 1 ] && [ "$got" = "$want" ] && ! grep -q '^COULD-NOT-INSPECT ' <<<"$out"; then ok "C2 planted corpus => rc 1, all $(wc -l <<<"$want") planted locations, none unexpected"
    else bad "C2 planted rc=$rc; missing: $(comm -13 <(printf '%s\n' "$got") <(printf '%s\n' "$want") | tr '\n' ' ') unexpected: $(comm -23 <(printf '%s\n' "$got") <(printf '%s\n' "$want") | tr '\n' ' ')"; fi
    # C2b severity, category and DIRECTION are part of each claim (a BEHIND/AHEAD swap, a
    #     third-party finding reported as owned drift, or dropped push probes must fail here)
    local c2ok=1 loc sevcat kw line
    while IFS='|' read -r loc sevcat kw; do
        line=$(awk -v l="$loc" '$1 == "FINDING" && $5 == l' <<<"$out")
        if [ "$(awk '{ print $3 " " $4 }' <<<"$line" | sort -u)" != "$sevcat" ] || ! grep -qF -- "$kw" <<<"$line"; then
            c2ok=0; bad "C2b $loc wanted '$sevcat' with '$kw', got: $(cut -c1-220 <<<"$line")"; fi
    done <<'TABLE'
behind.scn:gitlink:be%20hind@origin|medium governance-drift|is behind remote origin
diverged.scn:gitlink:d@origin|medium governance-drift|diverged: neither is an ancestor
undetermined.scn:gitlink:u@origin|medium governance-drift|direction UNDETERMINED
mirror-lag.scn:gitlink:m@mirror|medium governance-drift|(mirror lag)
second-remote.scn:gitlink:s@upstream|medium governance-drift|is behind remote upstream
ahead-clone.scn:gitlink:a@origin|high availability|is not on HEAD of the .gitmodules clone URL
pin-mismatch.scn:helix-deps:p|high governance-drift|the recorded pin drifted
pushurl.scn:gitlink:q@origin:pushurl2|medium governance-drift|pushes (pushurl 2) to repository name 'helixq'
undeclared.scn:gitlink:orphan|medium governance-drift|has no helix-deps.yaml deps[] entry
phantom-dep.scn:helix-deps:ghost|medium governance-drift|which has no gitlink in the index
carrier.scn:carrier:CLAUDE.md@k|medium docs-drift|the carrier quotes no current pin of k
thirdparty.scn:gitlink:vendor/lib@origin|low governance-drift|third-party (helix-deps.yaml exclusion block), reported not gating: gitlink
gmurl.scn:gitlink:g:gitmodules-url|medium governance-drift|is behind the .gitmodules URL
noref.scn:helix-deps:n|medium governance-drift|records no ref
nomanifest.scn:gitlink:z|medium governance-drift|helix-deps.yaml is absent
nobranch.scn:gitlink:b@mirror|medium governance-drift|has no refs/heads/dev
emptyremote.scn:gitlink:e@mirror|medium governance-drift|advertises no HEAD and no branch
pushtip.scn:gitlink:t@origin:pushurl1|medium governance-drift|remote origin pushurl 1 lags the gitlink
lockstep.scn:carrier:CLAUDE.md@k2|medium docs-drift|also in AGENTS.md:1 GEMINI.md:1 QWEN.md:1
TABLE
    [ "$c2ok" -eq 1 ] && ok "C2b every planted finding carries its severity, category and direction wording (19 cases)"
    # C3 determinism
    local first=$out; run "$SELF" --root "$LIVE" --corpus "$T/corpus/planted"
    if [ "$out" = "$first" ] && [ -n "$out" ]; then ok "C3 two planted runs are byte-identical"; else bad "C3 planted output differs between runs (or is empty)"; fi
    # C4 empty corpus => rc 2
    mkdir -p "$T/empty"; run "$SELF" --root "$LIVE" --corpus "$T/empty"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT ' <<<"$out"; then ok "C4 empty corpus => rc 2 (never clean)"; else bad "C4 empty corpus rc=$rc"; fi
    # C5 a git root with zero gitlinks and no manifest => rc 2
    git init -q "$T/zero" && run "$SELF" --root "$T/zero"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT ' <<<"$out"; then ok "C5 zero population => rc 2"; else bad "C5 zero population rc=$rc"; fi
    # C6 --root /nonexistent => rc 2
    run "$SELF" --root /nonexistent
    if [ "$rc" -eq 2 ]; then ok "C6 --root /nonexistent => rc 2"; else bad "C6 rc=$rc"; fi
    # C7 unreachable remote => COULD-NOT-INSPECT naming the item, rc 2, no finding
    mkdir -p "$T/unreach"; printf 'sub z 2\nremote z mirror unreachable\ndep z flat c2\n' >"$T/unreach/x.scn"
    run "$SELF" --root "$LIVE" --corpus "$T/unreach"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT x.scn:gitlink:z@mirror ' <<<"$out" && ! grep -q '^FINDING ' <<<"$out"; then ok "C7 unreachable remote => COULD-NOT-INSPECT x.scn:gitlink:z@mirror, rc 2"
    else bad "C7 unreachable rc=$rc: $(head -c 300 <<<"$out")"; fi
    # C11 a remote that advertises no HEAD and several branches => COULD-NOT-INSPECT, never clean
    mkdir -p "$T/nohead"; printf 'sub h 2\nremote h mirror c2\nnohead h mirror keep\ndep h flat c2\n' >"$T/nohead/h.scn"
    run "$SELF" --root "$LIVE" --corpus "$T/nohead"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT h.scn:gitlink:h@mirror .*advertises no HEAD and 2 branches' <<<"$out" && ! grep -q '^FINDING ' <<<"$out"; then ok "C11 no HEAD + 2 branches => COULD-NOT-INSPECT h.scn:gitlink:h@mirror, rc 2"
    else bad "C11 no-HEAD rc=$rc: $(head -c 300 <<<"$out")"; fi
    # C12 .gitmodules declares a path whose index gitlink is gone => FINDING at gitlink:<p>
    mkdir -p "$T/nogl"; printf 'sub x 2\nnogitlink x\ndep x flat c2\n' >"$T/nogl/x.scn"
    run "$SELF" --root "$LIVE" --corpus "$T/nogl"
    if [ "$rc" -eq 1 ] && grep -q '^FINDING pointer-drift medium governance-drift x.scn:gitlink:x .gitmodules declares x but the index holds no gitlink' <<<"$out" \
       && grep -q '^FINDING pointer-drift medium governance-drift x.scn:helix-deps:x ' <<<"$out"; then ok "C12 declared path with no gitlink => FINDING x.scn:gitlink:x (and its dep names no gitlink), rc 1"
    else bad "C12 no-gitlink rc=$rc: $(head -c 400 <<<"$out")"; fi
    # C13 a remote URL with a dangerous transport is REFUSED even when the user's git config
    #     allows it: GIT_ALLOW_PROTOCOL is set by the class, not inherited from config
    mkdir -p "$T/evilhome" "$T/ev"
    printf '[protocol "ext"]\n\tallow = always\n' >"$T/evilhome/.gitconfig"
    printf 'sub x 2\nrawurl x evil ext::sh%%20-c%%20touch%%25%%20%s/pwned\ndep x flat c2\n' "$T" >"$T/ev.scn"
    if ( export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; build_scenario "$T/ev.scn" "$T/ev" ) 2>"$T/err"; then
        rc=0; out=$(env -i PATH="$PATH" HOME="$T/evilhome" TMPDIR="$T/tmp" LC_ALL=C bash "$SELF" --root "$T/ev/root" 2>"$T/err") || rc=$?
        if [ ! -e "$T/pwned" ] && [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT gitlink:x@evil ' <<<"$out"; then ok "C13 ext:: remote refused (nothing executed), COULD-NOT-INSPECT gitlink:x@evil, rc 2"
        else bad "C13 ext:: remote rc=$rc pwned=$([ -e "$T/pwned" ] && echo EXECUTED || echo no): $(head -c 300 <<<"$out")"; fi
    else bad "C13 scenario could not be materialised: $(head -c 200 "$T/err")"; fi
    # C8a broken git => rc 2
    mkdir -p "$T/brokenbin"; printf '#!/bin/sh\nexit 127\n' >"$T/brokenbin/git"; chmod +x "$T/brokenbin/git"
    rc=0; out=$(env -i PATH="$T/brokenbin:$PATH" HOME="${HOME:-/}" TMPDIR="$T/tmp" LC_ALL=C bash "$SELF" --root "$LIVE" --corpus "$T/corpus/clean" 2>/dev/null) || rc=$?
    if [ "$rc" -eq 2 ]; then ok "C8a broken git => rc 2"; else bad "C8a broken git rc=$rc"; fi
    # C8b the reused verify-manifest-pins.sh absent (script copied alone) => rc 2
    mkdir -p "$T/lone"; cp "$SELF" "$T/lone/"; run "$T/lone/$(basename "$SELF")" --root "$LIVE" --corpus "$T/corpus/clean"
    if [ "$rc" -eq 2 ]; then ok "C8b reused script missing => rc 2"; else bad "C8b rc=$rc"; fi
    # C9 live mode on a materialised scratch umbrella (local remotes): emit == walked, planted finding found
    mkdir -p "$T/m"
    if ( export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; build_scenario "$CORP/planted/second-remote.scn" "$T/m" ) 2>"$T/err"; then
        run "$SELF" --root "$T/m/root" --emit-population; local emit=$out erc=$rc
        run "$SELF" --root "$T/m/root"
        if [ "$erc" -eq 0 ] && [ "$rc" -eq 1 ] && grep -qx "POPULATION-SHA $(printf '%s\n' "$emit" | sha256sum | cut -d' ' -f1)" <<<"$out" \
           && grep -qx "INSPECTED $(grep -c . <<<"$emit")" <<<"$out" && grep -q '^FINDING pointer-drift medium governance-drift gitlink:s@upstream ' <<<"$out"; then
            ok "C9 live mode: POPULATION-SHA == sha(--emit-population), INSPECTED == $(grep -c . <<<"$emit"), finding at gitlink:s@upstream"
        else bad "C9 live mode emit-rc=$erc rc=$rc: $(head -c 400 <<<"$out")"; fi
        # C9b every live evidence_ref names a REGULAR file inside --root, outside .git (README rule)
        local evbad="" evr evp
        while IFS= read -r evr; do
            evp=${evr%%:*}
            case "$evp" in .git|.git/*|*/.git|*/.git/*) evbad+=" $evr"; continue ;; esac
            [ -f "$T/m/root/$evp" ] && [ ! -L "$T/m/root/$evp" ] || evbad+=" $evr"
        done < <(awk '$1 == "FINDING" { print $NF }' <<<"$out")
        if [ -z "$evbad" ] && grep -q '^FINDING ' <<<"$out"; then ok "C9b every live evidence_ref is a regular file inside --root, outside .git"
        else bad "C9b evidence_ref not a regular file:$evbad"; fi
    else bad "C9 scenario could not be materialised: $(head -c 200 "$T/err")"; fi
    # C10 the live tree is byte-identical
    fpa=$(fp)
    if [ "$fpb" = "$fpa" ]; then ok "C10 live script, corpus, index entries and HEAD byte-identical before/after"; else bad "C10 live tree changed during the proof"; fi
    echo "pointer-drift --prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ] && return 0 || return 1
}

if [ "$PROVE" -eq 1 ]; then prove; exit $?; fi
main
exit $?
