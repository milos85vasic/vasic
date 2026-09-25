#!/usr/bin/env bash
# zero-gap-lib.sh — shared helpers for feature 010 (zero-gap verified closure).
#
# Sourced library (`. scripts/zero-gap-lib.sh`), plus a paired proof:
#   bash scripts/zero-gap-lib.sh --prove-failure
#
# Provides (FR-012, research D7):
#   zg_fingerprint <dir> [pathspec...]   one line: "<sha256> files=N dir=<as given> population=..."
#   zg_manifest    <dir> [pathspec...]   the sorted "<path>\t<state>" list it hashes
#   zg_with_fingerprint --dir D [--pathspec P]... -- <cmd...>
#                                        fingerprint before/after; drift => rc 2 UNSTABLE
#                                        (env fallback, only when NO flag is given:
#                                         ZG_FP_DIR, ZG_FP_PATHSPEC; `<cmd...>` without `--`)
#   zg_combine <rc>...                   finding(1) outranks undetermined(2); no input => 2
#   zg_sorted / zg_emit_sorted           LC_ALL=C deterministic output
#   ZG_HOLDS=0 ZG_VIOLATED=1 ZG_UNDET=2  three-valued codes; 2 is never a pass
#
# Population measured: tracked files UNION untracked files not ignored. Per entry:
#   regular file  blob via `git hash-object --no-filters` (raw bytes: CRLF and clean
#                 filters cannot hide a change) + owner-exec flag;
#   symlink       its readlink target (dangling is fine);
#   gitlink / nested repo  recorded commit + HEAD + sha256 of `git status --porcelain -z`;
#   deleted tracked file   DELETED.
# Ignored files are NOT measured. Paths are read with -z and printed with %q, so
# newline/quote/backslash paths work.
#
# Exit codes of --prove-failure: 0 all controls and mutations behave, 1 a mutation
# slipped through, 2 cannot determine (git/tools missing, fixtures cannot be built,
# or the LIVE repo changed while the proof ran — a concurrent editor cannot be
# attributed, so it is never a verdict). The proof builds throwaway temp repos; M6
# additionally READS the live repo (read-only: git --no-optional-locks status and a
# fingerprint of the whole tree) before and after and requires them identical.

ZG_HOLDS=0
ZG_VIOLATED=1
ZG_UNDET=2

zg_sorted() { LC_ALL=C sort; }

zg_emit_sorted() {
    if [ "$#" -eq 0 ]; then return 0; fi
    printf '%s\n' "$@" | LC_ALL=C sort
}

zg_combine() {
    local rc worst=0
    if [ "$#" -eq 0 ]; then return 2; fi
    for rc in "$@"; do
        case "$rc" in
            0) ;;
            1) worst=1 ;;
            *) if [ "$worst" -ne 1 ]; then worst=2; fi ;;
        esac
    done
    return "$worst"
}

# zg_manifest <dir> [pathspec...] -> stdout. rc 0 ok; 2 cannot determine (always with a stderr message).
zg_manifest() {
    local dir="${1:-}" abs tmp rc=0
    if [ "$#" -gt 0 ]; then shift; fi
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "zg: directory absent: '$dir'" >&2; return 2
    fi
    if ! command -v git >/dev/null 2>&1; then echo "zg: git absent" >&2; return 2; fi
    abs=$(cd "$dir" 2>/dev/null && pwd) || { echo "zg: cannot enter '$dir'" >&2; return 2; }
    tmp=$(mktemp -d) || { echo "zg: mktemp failed" >&2; return 2; }
    (
        cd "$abs" || exit 2
        if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "zg: not a git work tree: $dir" >&2; exit 2; fi
        ps=("$@")
        if [ "${#ps[@]}" -eq 0 ]; then ps=(.); fi
        git ls-files -s -z -- "${ps[@]}" >"$tmp/tracked" 2>"$tmp/e" || { echo "zg: git ls-files failed: $(cat "$tmp/e")" >&2; exit 2; }
        git ls-files -o --exclude-standard -z -- "${ps[@]}" >"$tmp/untracked" 2>"$tmp/e" || { echo "zg: git ls-files -o failed: $(cat "$tmp/e")" >&2; exit 2; }
        : >"$tmp/out"; : >"$tmp/plain"; : >"$tmp/flags"
        emit() { printf '%q\t%s\n' "$1" "$2" >>"$tmp/out"; }
        subrepo() { # $1 path $2 label $3 idx-sha (may be empty)
            local head st
            head=$(git -C "$1" rev-parse HEAD 2>/dev/null) || head=none
            st=$(git --no-optional-locks -C "$1" status --porcelain -z 2>/dev/null | sha256sum | cut -d' ' -f1)
            emit "$1" "$2:idx=$3 head=$head status=$st"
        }
        classify() { # $1 path  $2 tracked(1/0)  $3 gitlink idx sha or empty
            local p="${1%/}" fl=-
            if [ -L "$p" ]; then emit "$p" "symlink:$(readlink -- "$p")"
            elif [ -d "$p" ]; then
                if [ "$2" = 1 ]; then subrepo "$p" gitlink "$3"; else subrepo "$p" nested-repo ""; fi
            elif [ -f "$p" ]; then
                if [ -x "$p" ]; then fl=x; fi
                case "$p" in
                    *$'\n'*|*'"'*|*'\'*|*$'\r'*)
                        b=$(git hash-object --no-filters -- "$p" 2>"$tmp/e") || { echo "zg: git hash-object failed for one path: $(cat "$tmp/e")" >&2; exit 2; }
                        emit "$p" "file:$fl:$b" ;;
                    *) printf '%s\n' "$p" >>"$tmp/plain"; printf '%s\n' "$fl" >>"$tmp/flags" ;;
                esac
            elif [ -e "$p" ]; then emit "$p" "special"
            elif [ "$2" = 1 ]; then emit "$p" "DELETED"
            fi
        }
        while IFS= read -r -d '' rec; do
            meta=${rec%%$'\t'*}; path=${rec#*$'\t'}
            mode=${meta%% *}; sha=${meta#* }; sha=${sha%% *}
            if [ "$mode" = 160000 ]; then classify "$path" 1 "$sha"; else classify "$path" 1 ""; fi
        done <"$tmp/tracked"
        while IFS= read -r -d '' path; do classify "$path" 0 ""; done <"$tmp/untracked"
        if [ -s "$tmp/plain" ]; then
            git hash-object --no-filters --stdin-paths <"$tmp/plain" >"$tmp/blobs" 2>"$tmp/e" || { echo "zg: git hash-object failed: $(cat "$tmp/e")" >&2; exit 2; }
            if [ "$(wc -l <"$tmp/blobs")" -ne "$(wc -l <"$tmp/plain")" ]; then echo "zg: git hash-object returned a different number of blobs than paths" >&2; exit 2; fi
            exec 3<"$tmp/plain" 4<"$tmp/blobs" 5<"$tmp/flags"
            while IFS= read -r p <&3 && IFS= read -r b <&4 && IFS= read -r f <&5; do emit "$p" "file:$f:$b"; done
            exec 3<&- 4<&- 5<&-
        fi
        if [ ! -s "$tmp/out" ]; then echo "zg: zero files in population under $dir" >&2; exit 2; fi
        LC_ALL=C sort -u "$tmp/out"
    )
    rc=$?
    rm -rf "$tmp"
    return "$rc"
}

zg_fingerprint() {
    local out rc=0 n sha
    out=$(zg_manifest "$@") || rc=$?
    if [ "$rc" -ne 0 ]; then return 2; fi
    n=$(printf '%s\n' "$out" | wc -l)
    sha=$(printf '%s\n' "$out" | sha256sum | cut -d' ' -f1)
    printf '%s files=%s dir=%s population=tracked+untracked-not-ignored\n' "$sha" "$n" "${1:-}"
}

zg_with_fingerprint() {
    local dir="" flagged=0 abs t rc=0 crc=0
    local ps=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dir) if [ "$#" -lt 2 ]; then echo "zg: --dir needs a value" >&2; return 2; fi; dir=$2; flagged=1; shift 2 ;;
            --pathspec) if [ "$#" -lt 2 ]; then echo "zg: --pathspec needs a value" >&2; return 2; fi; ps+=("$2"); flagged=1; shift 2 ;;
            --) shift; break ;;
            *) break ;;
        esac
    done
    if [ "$flagged" -eq 0 ]; then
        dir="${ZG_FP_DIR:-.}"
        # shellcheck disable=SC2206
        ps=(${ZG_FP_PATHSPEC:-})
    fi
    if [ -z "$dir" ]; then dir=.; fi
    if [ "$#" -eq 0 ]; then echo "zg: no command to wrap" >&2; return 2; fi
    abs=$(cd "$dir" 2>/dev/null && pwd) || { echo "zg: directory absent: '$dir'" >&2; return 2; }
    t=$(mktemp -d) || { echo "zg: mktemp failed" >&2; return 2; }
    zg_manifest "$abs" ${ps[@]+"${ps[@]}"} >"$t/before" 2>"$t/e1" || rc=$?
    if [ "$rc" -ne 0 ]; then cat "$t/e1" >&2; echo "UNDETERMINED: pre-run fingerprint failed" >&2; rm -rf "$t"; return 2; fi
    "$@" || crc=$?
    zg_manifest "$abs" ${ps[@]+"${ps[@]}"} >"$t/after" 2>"$t/e2" || rc=$?
    if [ "$rc" -ne 0 ]; then cat "$t/e2" >&2; echo "UNDETERMINED: post-run fingerprint failed" >&2; rm -rf "$t"; return 2; fi
    if ! cmp -s "$t/before" "$t/after"; then
        echo "UNSTABLE: population changed during the run; no verdict is valid. Changed paths:" >&2
        { diff "$t/before" "$t/after" || true; } | sed -n 's/^[<>] //p' | cut -f1 | LC_ALL=C sort -u | sed 's/^/  /' >&2
        rm -rf "$t"; return 2
    fi
    rm -rf "$t"
    return "$crc"
}

zg_prove_failure() (
    local T here LIBFILE WFP_SRC pass=0 fail=0 rc out i sums f1 f2 f3
    for b in git sha256sum mktemp sort cut diff cmp sed wc paste readlink; do
        if ! command -v "$b" >/dev/null 2>&1; then echo "prove-failure: cannot determine — '$b' missing" >&2; exit 2; fi
    done
    T=$(mktemp -d) || exit 2
    trap 'rm -rf "$T"' EXIT
    ok()  { pass=$((pass+1)); echo "  PASS $1"; }
    bad() { fail=$((fail+1)); echo "  FAIL $1"; }
    mkrepo() { rm -rf "$1"; mkdir -p "$1"; ( cd "$1" && git init -q && echo a >a.txt && echo b >b.txt \
        && git add . && git -c user.name=t -c user.email=t@t commit -qm i ) >/dev/null 2>&1; }
    WFP_SRC='WFP() { local d=$1; shift; zg_with_fingerprint --dir "$d" -- "$@"; }'
    eval "$WFP_SRC"
    here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    LIBFILE="$here/scripts/zero-gap-lib.sh"
    mkrepo "$T/c" || { echo "prove-failure: cannot build fixture repo — cannot determine" >&2; exit 2; }

    body() {
    echo "CONTROL unchanged tree"
    f1=$(zg_fingerprint "$T/c"); f2=$(zg_fingerprint "$T/c")
    if [ -n "$f1" ] && [ "${f1%% *}" = "${f2%% *}" ]; then ok "control fingerprints equal"; else bad "control fingerprints differ"; fi
    WFP "$T/c" true >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then ok "control wrapped true => rc 0"; else bad "control rc=$rc"; fi
    WFP "$T/c" false >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 1 ]; then ok "control wrapped false => rc 1 passthrough"; else bad "passthrough rc=$rc"; fi

    echo "M1 file edited during command"
    out=$(WFP "$T/c" bash -c "echo x >> '$T/c/a.txt'" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'UNSTABLE' <<<"$out" && grep -q 'a.txt' <<<"$out"; then ok "M1 rc 2 UNSTABLE naming a.txt"; else bad "M1 rc=$rc out=$out"; fi

    echo "M2 untracked file appears during command"
    mkrepo "$T/m2"
    out=$(WFP "$T/m2" bash -c "echo n > '$T/m2/new.txt'" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'new.txt' <<<"$out"; then ok "M2 rc 2 naming new.txt"; else bad "M2 rc=$rc out=$out"; fi

    echo "M3 empty / absent population"
    zg_fingerprint "$T/does-not-exist" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ]; then ok "M3a absent dir => rc 2"; else bad "M3a rc=$rc"; fi
    mkdir -p "$T/empty"; ( cd "$T/empty" && git init -q ) >/dev/null 2>&1
    zg_fingerprint "$T/empty" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ]; then ok "M3b empty repo => rc 2"; else bad "M3b rc=$rc"; fi
    mkdir -p "$T/notrepo"; echo z >"$T/notrepo/z"
    zg_fingerprint "$T/notrepo" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ]; then ok "M3c non-repo dir => rc 2"; else bad "M3c rc=$rc"; fi

    echo "M4 combiner"
    zg_combine 0 2 1; rc=$?; if [ "$rc" -eq 1 ]; then ok "M4a finding outranks undetermined"; else bad "M4a rc=$rc"; fi
    zg_combine 0 2 0; rc=$?; if [ "$rc" -eq 2 ]; then ok "M4b undetermined outranks holds"; else bad "M4b rc=$rc"; fi
    zg_combine 0 0;   rc=$?; if [ "$rc" -eq 0 ]; then ok "M4c all holds => 0"; else bad "M4c rc=$rc"; fi
    zg_combine 7;     rc=$?; if [ "$rc" -eq 2 ]; then ok "M4d unknown rc => undetermined"; else bad "M4d rc=$rc"; fi

    echo "M5 determinism x5 (fresh identical repos)"
    sums=""
    for i in 1 2 3 4 5; do
        mkrepo "$T/d$i"; echo u >"$T/d$i/u.txt"
        sums="$sums$(zg_fingerprint "$T/d$i" | cut -d' ' -f1)"$'\n'
    done
    if [ "$(printf '%s' "$sums" | sort -u | wc -l)" -eq 1 ] && [ -n "${sums%%$'\n'*}" ]; then ok "M5 5 identical fingerprints"; else bad "M5 fingerprints differ: $sums"; fi
    echo "y" >"$T/d1/u.txt"
    if [ "$(zg_fingerprint "$T/d1" | cut -d' ' -f1)" != "$(zg_fingerprint "$T/d2" | cut -d' ' -f1)" ]; then ok "M5b content change changes fingerprint"; else bad "M5b insensitive to content"; fi

    gc() { git -c user.name=t -c user.email=t@t "$@"; }
    fp() { zg_fingerprint "$@" 2>/dev/null | cut -d' ' -f1; }
    echo "I1 CRLF rewrite under text=auto"
    mkrepo "$T/i1"; ( cd "$T/i1" && echo '* text=auto' >.gitattributes && printf 'l1\nl2\n' >a.txt && git add . && gc commit -qm x ) >/dev/null 2>&1
    f1=$(fp "$T/i1"); printf 'l1\r\nl2\r\n' >"$T/i1/a.txt"; f2=$(fp "$T/i1")
    [ -n "$f1" ] && [ "$f1" != "$f2" ] && ok "I1 CRLF change visible" || bad "I1 CRLF invisible"
    echo "I2 mode / symlink / dangling / nested repo"
    mkrepo "$T/i2"; f1=$(fp "$T/i2"); chmod +x "$T/i2/a.txt"; f2=$(fp "$T/i2")
    [ -n "$f1" ] && [ "$f1" != "$f2" ] && ok "I2a chmod +x visible" || bad "I2a chmod invisible"
    mkrepo "$T/i2b"; ( cd "$T/i2b" && cp a.txt c.txt && ln -s a.txt lnk && git add . && gc commit -qm s ) >/dev/null 2>&1
    f1=$(fp "$T/i2b"); ln -sf c.txt "$T/i2b/lnk"; f2=$(fp "$T/i2b")
    [ -n "$f1" ] && [ "$f1" != "$f2" ] && ok "I2b symlink retarget visible" || bad "I2b symlink retarget invisible"
    mkrepo "$T/i2c"; ln -s nowhere "$T/i2c/dangling"; out=$(zg_fingerprint "$T/i2c" 2>&1); rc=$?
    [ "$rc" -eq 0 ] && ok "I2c dangling symlink rc 0" || bad "I2c dangling rc=$rc msg='$out'"
    mkrepo "$T/i2d"; mkdir "$T/i2d/nest"; ( cd "$T/i2d/nest" && git init -q && echo n >n && git add . && gc commit -qm n ) >/dev/null 2>&1
    out=$(zg_fingerprint "$T/i2d" 2>&1); rc=$?; f1=${out%% *}
    ( cd "$T/i2d/nest" && echo m >>n && git add . && gc commit -qm m ) >/dev/null 2>&1; f2=$(fp "$T/i2d")
    [ "$rc" -eq 0 ] && [ "$f1" != "$f2" ] && ok "I2d nested repo rc 0 and HEAD move visible" || bad "I2d nested rc=$rc msg='$out'"
    echo "I3 submodule state"
    mkrepo "$T/s3"; mkrepo "$T/i3"
    ( cd "$T/i3" && git -c protocol.file.allow=always submodule add -q "$T/s3" sub && gc commit -qm sm ) >/dev/null 2>&1
    f1=$(fp "$T/i3"); echo z >"$T/i3/sub/dirty.txt"; f2=$(fp "$T/i3"); rm "$T/i3/sub/dirty.txt"
    ( cd "$T/i3/sub" && echo q >>a.txt && git add . && gc commit -qm mv ) >/dev/null 2>&1; f3=$(fp "$T/i3")
    [ -n "$f1" ] && [ "$f1" != "$f2" ] && ok "I3a dirty submodule visible" || bad "I3a dirty submodule invisible"
    [ "$f1" != "$f3" ] && ok "I3b moved submodule HEAD visible" || bad "I3b moved HEAD invisible"
    echo "I4 set -e caller gets rc 2 from a moving tree"
    mkrepo "$T/i4"
    bash -c ". '$LIBFILE'; $WFP_SRC; set -e; WFP '$T/i4' bash -c \"echo x >> '$T/i4/a.txt'; exit 1\"; echo reached" >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && ok "I4 set -e caller exits 2" || bad "I4 set -e caller exit $rc"
    echo "I5 combine of nothing"
    zg_combine; rc=$?; [ "$rc" -eq 2 ] && ok "I5 zg_combine () => 2" || bad "I5 rc=$rc"
    echo "I6 prover without git is rc 2"
    mkdir -p "$T/nogit"; for b in /usr/bin/*; do [ "${b##*/}" = git ] || ln -sf "$b" "$T/nogit/${b##*/}"; done
    env PATH="$T/nogit" /bin/bash "$LIBFILE" --prove-failure >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 2 ] && ok "I6 no git => rc 2" || bad "I6 no git => rc $rc"
    echo "M6m root-level README write during a wrapped command is caught as rc 2"
    mkrepo "$T/m6"; out=$(WFP "$T/m6" bash -c "echo r > '$T/m6/README'" 2>&1); rc=$?
    [ "$rc" -eq 2 ] && grep -q README <<<"$out" && ok "M6m rc 2 naming README" || bad "M6m rc=$rc"
    echo "Minors"
    mkrepo "$T/n"; nm=$'we ird\nna"me\\q.txt'; printf 1 >"$T/n/$nm"; out=$(zg_fingerprint "$T/n" 2>&1); rc=$?; f1=${out%% *}
    printf 2 >"$T/n/$nm"; f2=$(fp "$T/n")
    [ "$rc" -eq 0 ] && [ "$f1" != "$f2" ] && ok "newline/quote/backslash path handled" || bad "odd path rc=$rc"
    mkrepo "$T/r"; ( cd "$T" && WFP r bash -c 'cd /; true' ) >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] && ok "relative dir + wrapped cd => rc 0" || bad "relative dir rc=$rc"
    out=$( cd "$T" && zg_fingerprint r 2>&1 ); case "$out" in *"$T"*) bad "dir= leaks absolute path" ;; *) ok "dir= carries no absolute path" ;; esac
    ZG_FP_PATHSPEC=zzz-nonexistent WFP "$T/r" true >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 0 ] && ok "stray ZG_FP_PATHSPEC cannot change flag-form result" || bad "stray env changed result rc=$rc"
    }

    echo "M6 the LIVE repo is unchanged across the whole proof (read-only; whole tree; rc 2 if it moved)"
    local st0 st1 strc=0
    st0=$(git --no-optional-locks -C "$here" status --porcelain 2>&1) || strc=$?
    if [ "$strc" -ne 0 ]; then echo "prove-failure: cannot read live git status — cannot determine" >&2; exit 2; fi
    zg_with_fingerprint --dir "$here" -- body; rc=$?
    st1=$(git --no-optional-locks -C "$here" status --porcelain 2>&1) || strc=$?
    if [ "$rc" -eq 2 ]; then
        echo "  UNDETERMINED M6: live tree changed or could not be fingerprinted during the proof (paths above); proof cases ran but M6 cannot vouch"
        echo "prove-failure: $pass passed, $fail failed (M6 undetermined)"; exit 2
    fi
    if [ "$strc" -ne 0 ] || [ "$st0" != "$st1" ]; then echo "  UNDETERMINED M6: live git status changed"; exit 2; fi
    ok "M6 live tree byte-identical (status + whole-tree fingerprint)"
    echo "prove-failure: $pass passed, $fail failed"
    if [ "$fail" -eq 0 ]; then exit 0; fi
    exit 1
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        --prove-failure) zg_prove_failure; exit $? ;;
        *) echo "usage: . scripts/zero-gap-lib.sh  |  bash scripts/zero-gap-lib.sh --prove-failure" >&2; exit 2 ;;
    esac
fi
