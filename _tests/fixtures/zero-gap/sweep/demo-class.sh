#!/usr/bin/env bash
# demo-class.sh — FIXTURE-ONLY demonstration sweep class (feature 010, T017/T018).
#
# NOT a real sweep class and never listed in docs/zero-gap/sweep-classes.tsv.
# `scripts/zero-gap-sweep.sh --prove-failure` COPIES this file into THROWAWAY
# repositories as `scripts/zero-gap-class-<mode>.sh`; the <mode> in the copy's
# file name selects the behaviour, so one source file serves every proof case
# (no byte-identical forks, §11.4.251). It implements the class contract of
# docs/zero-gap/README.md in the smallest honest way: a population item is a
# defect when it contains the literal marker PLANTED-DEFECT.
#
# Modes (from the copied file name). Conforming: demo (live population =
# tracked *.txt/*.md outside _tests/fixtures/; corpus population = every file
# under --corpus), quotes (a description with " and \). Deliberately broken:
# blind (reads *.txt only), nondet (random token per finding), zeropop (empty
# population), mover (writes into --root), malformed (a line outside the
# contract), partial (INSPECTED one short), rawspace (does not percent-encode),
# hostile (ESC and BEL in a description), badutf8 (an invalid UTF-8 byte), restorer (rewrites a tracked
# file and restores its bytes), ignwriter (writes .remember/zg-probe), tmpwriter
# (writes .remember/tmp/zg-probe, an excluded concurrent-writer path),
# committer (git commit), configer (git config --local), emitwriter (writes
# during --emit-population), sleeper (overruns with a TERM-ignoring child),
# orphaner (exits leaving a TERM-ignoring child), nap (sleeps 3 s), sameset
# (walks a different set of the same size), fixturepop (includes corpora).
# Fix round 2 modes: nulbyte / c1ctrl / bidi / linesep (a NUL, U+0085, U+202E, U+2028 in a
# description), envdump (writes the NAMES of its received environment to $TMPDIR/zg-env.txt and the
# values of a few to $TMPDIR/zg-envval.txt), escaper (starts a TERM-ignoring grandchild in its OWN
# session via setsid, pid in $TMPDIR/zg-escaper.pid), flood (200000 findings), badref (evidence_ref
# names no real path), rawref (unencoded blank in evidence_ref), trackedloc (location = a tracked
# file outside the population, with a line suffix), ghostloc (location neither population nor
# tracked), dotslash (population items start with ./), dotfix (./ plus corpus fixtures), dotloc (location ./notes/ok.txt), colonfix
# (location item:_tests/fixtures/zero-gap/...), dotref / absref (evidence_ref ./notes/ok.txt or
# /dev/null: paths that EXIST but are not normal relative tokens), svclog (appends a probed server's access log under
# .service-registry/qa/, a default ZG_IGNORED_EXCLUDE path). Round 3: alm (U+061C), dirref / gitref /
# linkref / fixref (evidence_ref a directory, inside .git, a symlink out of the tree, a corpus fixture),
# ignrm / igncpp (remove, or cp -p over, an ignored _site/index.html), hookwriter / excludewriter (write
# .git/hooks/pre-push, .git/info/exclude), spawner (a setsid escapee that keeps spawning TERM-ignoring
# children; pid in $TMPDIR/zg-spawner.pid). These special findings are printed in live runs only.
# Any mode prints an extra finding when ZG_ENV_LEAK_PROBE reaches it (the runner must
# never let a variable outside its allow-list through).
#
# Usage: <copy> --root <dir> [--corpus <dir>] [--emit-population]
# Exit:  0 no finding, 1 finding(s), 2 could not determine (never a pass).
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

ROOT="" CORPUS="" EMIT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        *) echo "demo-class: unknown argument: $1" >&2; exit 2 ;;
    esac
done

self=$(basename "$0"); mode=${self#zero-gap-class-}; mode=${mode%.sh}
case "$mode" in
    demo|quotes|blind|nondet|zeropop|mover|malformed|partial|rawspace|hostile|badutf8|restorer|ignwriter|tmpwriter|committer|configer|emitwriter|sleeper|orphaner|nap|sameset|fixturepop|nulbyte|c1ctrl|bidi|linesep|envdump|escaper|flood|badref|rawref|trackedloc|ghostloc|dotslash|dotfix|dotloc|colonfix|svclog|dotref|absref|alm|dirref|gitref|linkref|fixref|ignrm|igncpp|hookwriter|excludewriter|spawner) ;;
    *) echo "COULD-NOT-INSPECT - demo-class copied under an unknown mode name"; exit 2 ;;
esac
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then echo "COULD-NOT-INSPECT - --root is not a directory"; exit 2; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then echo "COULD-NOT-INSPECT - --corpus is not a directory"; exit 2; fi
base=${CORPUS:-$ROOT}

# raw_items -> NUL-separated raw relative paths of the population, unsorted
raw_items() {
    if [ -n "$CORPUS" ]; then
        ( cd "$CORPUS" && find . -type f -print0 ) | sed -z 's|^\./||'
    elif [ "$mode" = fixturepop ] || [ "$mode" = dotfix ]; then
        git -C "$ROOT" ls-files -z -- '*.txt' '*.md'
    else
        git -C "$ROOT" ls-files -z -- '*.txt' '*.md' | awk 'BEGIN { RS = ORS = "\0" } !/^_tests\/fixtures\//'
    fi
}

# tokens -> sorted, unique canonical tokens of the population this mode claims
tokens() {
    local raw
    case "$mode" in
        zeropop) return 0 ;;
        rawspace) raw_items | tr '\0' '\n' | awk 'NF' | LC_ALL=C sort -u; return 0 ;;
    esac
    raw_items | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u | {
        if [ "$mode" = blind ]; then awk '/\.txt$/'
        elif { [ "$mode" = dotslash ] || [ "$mode" = dotfix ]; } && [ -z "$CORPUS" ]; then sed 's|^|./|'
        else cat; fi
    }
}

# decode <token> -> raw path (for reading the file)
decode() { printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"; }

if [ "$EMIT" -eq 1 ]; then
    if [ "$mode" = emitwriter ]; then echo emitted >>"$ROOT/emitwriter-was-here.txt"; fi
    tokens
    exit 0
fi

walked=$(tokens)
if [ "$mode" = sameset ] && [ -n "$walked" ]; then
    walked=$(printf '%s\n' "$walked" | sed '1s/$/-not-the-emitted-item/' | LC_ALL=C sort -u)
fi

case "$mode" in
    mover) echo moved >>"$ROOT/mover-was-here.txt" ;;
    restorer) cp -p "$ROOT/notes/ok.txt" "$TMPDIR/zg-restore.$$" && echo x >>"$ROOT/notes/ok.txt" && cat "$TMPDIR/zg-restore.$$" >"$ROOT/notes/ok.txt"; rm -f "$TMPDIR/zg-restore.$$" ;;
    ignwriter) mkdir -p "$ROOT/.remember" && echo probe >"$ROOT/.remember/zg-probe" ;;
    tmpwriter) mkdir -p "$ROOT/.remember/tmp" && echo probe >"$ROOT/.remember/tmp/zg-probe" ;;
    svclog) mkdir -p "$ROOT/.service-registry/qa" && echo "GET / 200" >>"$ROOT/.service-registry/qa/vd.log" ;;
    ignrm) if [ -z "$CORPUS" ]; then rm -f "$ROOT/_site/index.html"; fi ;;
    igncpp) if [ -z "$CORPUS" ]; then printf 'replaced\n' >"$TMPDIR/zg-old.$$" && touch -d @1000000000 "$TMPDIR/zg-old.$$" && cp -p "$TMPDIR/zg-old.$$" "$ROOT/_site/index.html"; rm -f "$TMPDIR/zg-old.$$"; fi ;;
    hookwriter) if [ -z "$CORPUS" ]; then printf '#!/bin/sh\nexit 0\n' >"$(git -C "$ROOT" rev-parse --absolute-git-dir)/hooks/pre-push"; fi ;;
    excludewriter) if [ -z "$CORPUS" ]; then echo '# probe' >>"$(git -C "$ROOT" rev-parse --absolute-git-dir)/info/exclude"; fi ;;
    spawner) if [ -z "$CORPUS" ]; then
                 setsid bash -c 'trap "" TERM; while :; do bash -c "trap \"\" TERM; sleep 60" & sleep 0.02; done' </dev/null >/dev/null 2>&1 &
                 echo "$!" >"$TMPDIR/zg-spawner.pid"
             fi ;;
    committer) git -C "$ROOT" -c user.name=t -c user.email=t@t commit -q --allow-empty -m probe >/dev/null 2>&1 ;;
    configer) git -C "$ROOT" config --local zg.probe 1 ;;
    sleeper) if [ -z "$CORPUS" ]; then
                 bash -c 'trap "" TERM; sleep 60' & echo "$!" >"$TMPDIR/zg-sleeper.pid"
                 sleep 60
             fi ;;
    orphaner) if [ -z "$CORPUS" ]; then bash -c 'trap "" TERM; sleep 60' & echo "$!" >"$TMPDIR/zg-orphan.pid"; fi ;;
    nap) if [ -z "$CORPUS" ]; then sleep 3; fi ;;
esac

n=0 found=0
if [ -z "$CORPUS" ]; then
    case "$mode" in
        nulbyte) printf 'FINDING %s low other notes/ok.txt nul\000byte notes/ok.txt\n' "$mode"; found=$((found + 1)) ;;
        c1ctrl)  printf 'FINDING %s low other notes/ok.txt next-line\302\205control notes/ok.txt\n' "$mode"; found=$((found + 1)) ;;
        bidi)    printf 'FINDING %s low other notes/ok.txt right-to-left\342\200\256override notes/ok.txt\n' "$mode"; found=$((found + 1)) ;;
        linesep) printf 'FINDING %s low other notes/ok.txt line\342\200\250separator notes/ok.txt\n' "$mode"; found=$((found + 1)) ;;
        badref)  echo "FINDING $mode low other notes/ok.txt evidence names no real path notes/nowhere.txt:3"; found=$((found + 1)) ;;
        dotref)  echo "FINDING $mode low other notes/ok.txt a dot-slash evidence path that exists ./notes/ok.txt"; found=$((found + 1)) ;;
        alm)     printf 'FINDING %s low other notes/ok.txt arabic\330\234letter-mark notes/ok.txt\n' "$mode"; found=$((found + 1)) ;;
        dirref)  echo "FINDING $mode low other notes/ok.txt the evidence is a directory notes"; found=$((found + 1)) ;;
        gitref)  echo "FINDING $mode low other notes/ok.txt the evidence is inside the git directory .git/config"; found=$((found + 1)) ;;
        linkref) echo "FINDING $mode low other notes/ok.txt the evidence is a symlink leaving the tree notes/host"; found=$((found + 1)) ;;
        fixref)  echo "FINDING $mode low other notes/ok.txt the evidence is a corpus fixture _tests/fixtures/zero-gap/fixref/expect.tsv"; found=$((found + 1)) ;;
        absref)  echo "FINDING $mode low other notes/ok.txt an absolute evidence path that exists /dev/null"; found=$((found + 1)) ;;
        trackedloc) echo "FINDING $mode low other docs/zero-gap/sweep-classes.tsv:3 a line of a tracked file outside the population docs/zero-gap/sweep-classes.tsv:3"; found=$((found + 1)) ;;
        ghostloc) echo "FINDING $mode low other nowhere/x.txt neither a population item nor tracked notes/ok.txt"; found=$((found + 1)) ;;
        dotloc)  echo "FINDING $mode low other ./notes/ok.txt a dot-slash location notes/ok.txt"; found=$((found + 1)) ;;
        colonfix) echo "FINDING $mode low other notes/ok.txt:_tests/fixtures/zero-gap/x a fixture path after a colon notes/ok.txt"; found=$((found + 1)) ;;
        flood)   seq 1 200000 | awk -v m="$mode" '{ print "FINDING " m " low other notes/ok.txt:" $1 " flood finding notes/ok.txt:" $1 }'; found=$((found + 1)) ;;
        envdump) tr '\0' '\n' </proc/$$/environ | cut -d= -f1 | LC_ALL=C sort >"$TMPDIR/zg-env.txt"
                 for v in GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GOTOOLCHAIN GOMAXPROCS PYTHONDONTWRITEBYTECODE LC_ALL LANG; do printf '%s=%s\n' "$v" "${!v:-<unset>}"; done >"$TMPDIR/zg-envval.txt" ;;
        escaper) setsid bash -c 'trap "" TERM; sleep 60' </dev/null >/dev/null 2>&1 & echo "$!" >"$TMPDIR/zg-escaper.pid" ;;
    esac
fi
if [ -n "${ZG_ENV_LEAK_PROBE:-}" ] && [ -z "$CORPUS" ]; then
    # test hook: a variable outside the runner's class allow-list must never arrive here
    echo "FINDING $mode high security notes/ok.txt a variable outside the class environment allow-list reached the class notes/ok.txt"
    found=$((found + 1))
fi
while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    n=$((n + 1))
    if [ "$mode" = rawspace ]; then p=$tok; else p=$(decode "$tok"); fi
    [ -f "$base/$p" ] || continue
    hit=$(grep -n -m1 'PLANTED-DEFECT' -- "$base/$p" | cut -d: -f1) || hit=""
    if [ "$mode" = nondet ]; then
        echo "FINDING $mode low other $tok nondeterministic demonstration finding run-$RANDOM-$$ $tok"
        found=$((found + 1))
    elif [ -n "$hit" ]; then
        case "$mode" in
            hostile) printf 'FINDING %s low other %s carries the marker \033[31mred\033[0m bell\a %s:%s\n' "$mode" "$tok" "$tok" "$hit" ;;
            badutf8) printf 'FINDING %s low other %s carries the marker bad\377byte %s:%s\n' "$mode" "$tok" "$tok" "$hit" ;;
            quotes)  printf 'FINDING %s low other %s carries the "marker" with a back\\slash %s:%s\n' "$mode" "$tok" "$tok" "$hit" ;;
            rawref)  echo "FINDING $mode low other $tok file carries the planted demonstration marker $p:$hit" ;;
            *)       echo "FINDING $mode low other $tok file carries the planted demonstration marker $tok:$hit" ;;
        esac
        found=$((found + 1))
    fi
done <<<"$walked"
if [ "$mode" = malformed ]; then echo "this line is outside the class output contract"; fi
if [ "$mode" = partial ] && [ "$n" -gt 0 ]; then n=$((n - 1)); fi
echo "INSPECTED $n"
if [ -n "$walked" ]; then echo "POPULATION-SHA $(printf '%s\n' "$walked" | sha256sum | cut -d' ' -f1)"
else echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; fi
if [ "$found" -gt 0 ]; then exit 1; fi
exit 0
