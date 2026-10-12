#!/usr/bin/env bash
# scripts/prove-umbrella-mutants.sh - mutation proofs for the UMBRELLA Go modules (spec 010 T057 + T058).
#
# WHAT IT PROVES. For every row of docs/zero-gap/mutants/umbrella.tsv it copies the row's module into a
# scratch tree, applies ONE small source mutation to the COPY (exact-string replace; the old text must occur
# exactly once), runs the module's tests and REQUIRES them to FAIL; the unmutated copy must PASS first.
#   set=fuzz      the mutant must be killed by the FuzzXxx seed corpus alone (T057: the fuzz targets are real
#                 detectors, not decoration)
#   set=mutation  the mutant must be killed by the module's pre-existing tests with the fuzz seeds skipped
#                 (T058: umbrella _tools/gen has a mutation proof of its own)
# The real tree is never written. A mutant that does not apply, does not compile, or SURVIVES is a failure.
#
# Usage: prove-umbrella-mutants.sh [--set fuzz|mutation|all] [--fuzz-secs N] [--spec FILE] [--root DIR]
#                                  [--go PATH] [--prove-failure] [--help]
#   --fuzz-secs N   also run each distinct FuzzXxx target for N seconds on the UNMUTATED copy (default 0 = off)
#   --prove-failure the paired section 1.1 proof: drives THIS harness over a throwaway fixture module and
#                   requires it to report a killed mutant as KILLED, a survivor / unapplied / non-compiling
#                   mutant / red baseline as rc 1, and a missing go toolchain as rc 2.
# Exit: 0 every mutant killed and every baseline green; 1 a mutant survived / was not applied / did not
# compile, or a baseline is red; 2 could not determine (no go toolchain, spec unreadable) - 2 is never a pass.
# Memory: each go invocation runs under `systemd-run --user --scope -p MemoryMax=8G` when available.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SET=all; FUZZ_SECS=0; SPEC=""; GO=go; PROVE=0

usage() { sed -n '2,/^set -u/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --set) SET="${2:-}"; shift 2 ;;
        --fuzz-secs) FUZZ_SECS="${2:-0}"; shift 2 ;;
        --spec) SPEC="${2:-}"; shift 2 ;;
        --root) ROOT="${2:-}"; shift 2 ;;
        --go) GO="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
[ -n "$SPEC" ] || SPEC="$ROOT/docs/zero-gap/mutants/umbrella.tsv"

SP="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "$SP/umbrella-mutants.XXXXXX")" || { echo "cannot create scratch dir" >&2; exit 2; }
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

bounded() {
    if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope -q -p MemoryMax=8G true >/dev/null 2>&1; then
        systemd-run --user --scope -q -p MemoryMax=8G "$@"
    else
        "$@"
    fi
}

# Scratch copy of one module at the same depth under a scratch repo root, so ../.. and replace => ../../x
# paths keep resolving. Only read-only top-level data dirs are linked in (tests write to t.TempDir only).
make_copy() { # module-rel dest-root
    local mod="$1" dest="$2" e
    mkdir -p "$dest/$(dirname "$mod")"
    cp -R "$ROOT/$mod" "$dest/$mod"
    for e in "$ROOT"/_content "$ROOT"/submodules; do
        [ -e "$e" ] && [ ! -e "$dest/$(basename "$e")" ] && ln -s "$e" "$dest/$(basename "$e")"
    done
    # availableLangs() lists REAL directories named _content_<lang> (a symlink is not IsDir): mirror the names.
    for e in "$ROOT"/_content_*; do
        [ -d "$e" ] && mkdir -p "$dest/$(basename "$e")"
    done
    return 0
}

apply_mutation() { # file old new  -> rc 0 applied, 3 old text not found exactly once
    python3 -I - "$1" "$2" "$3" <<'PY'
import sys
f, old, new = sys.argv[1:4]
dec = lambda s: "" if s == "<EMPTY>" else s.replace("<NL>", "\n").replace("<TAB>", "\t")
old, new = dec(old), dec(new)
s = open(f, encoding="utf-8").read()
if s.count(old) != 1:
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new))
PY
}

gotest() { # dir args...  -> sets OUT, RC
    local dir="$1"; shift
    OUT="$(cd "$dir" && GOPROXY=off GOTOOLCHAIN=local GOFLAGS=-mod=mod bounded "$GO" test -count=1 -p 2 "$@" 2>&1)"
    RC=$?
}

command -v "$GO" >/dev/null 2>&1 || { echo "COULD NOT DETERMINE: go toolchain '$GO' not found" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "COULD NOT DETERMINE: python3 not found" >&2; exit 2; }
[ -r "$SPEC" ] || { echo "COULD NOT DETERMINE: spec $SPEC unreadable" >&2; exit 2; }

killed=0; survived=0; notapplied=0; broken=0; basered=0; total=0
declare -A BASE_OK=()

run_all() {
    local id set mod file old new targs key dest base
    while IFS=$'\t' read -r id set mod file old new targs; do
        case "$id" in ''|'#'*) continue ;; esac
        [ "$SET" = all ] || [ "$SET" = "$set" ] || continue
        total=$((total+1))
        key="$mod|$targs"
        # shellcheck disable=SC2086
        if [ -z "${BASE_OK[$key]:-}" ]; then
            base="$WORK/base.$(printf '%s' "$key" | cksum | cut -d' ' -f1)"
            make_copy "$mod" "$base"
            gotest "$base/$mod" $targs
            if [ "$RC" -ne 0 ]; then
                BASE_OK[$key]=red
                echo "BASELINE-RED  $mod ($targs): unmutated copy fails (rc $RC)"; printf '%s\n' "$OUT" | tail -8 | sed 's/^/    /'
            else
                BASE_OK[$key]=green
                echo "BASELINE-OK   $mod ($targs)"
                if [ "$FUZZ_SECS" -gt 0 ] && [ "$set" = fuzz ]; then :; fi
            fi
        fi
        if [ "${BASE_OK[$key]}" = red ]; then basered=$((basered+1)); continue; fi
        dest="$WORK/m.$total"
        make_copy "$mod" "$dest"
        apply_mutation "$dest/$mod/$file" "$old" "$new"; local arc=$?
        if [ "$arc" -ne 0 ]; then
            notapplied=$((notapplied+1)); echo "NOT-APPLIED   $id: old text not found exactly once in $mod/$file"; rm -rf "$dest"; continue
        fi
        # shellcheck disable=SC2086
        gotest "$dest/$mod" $targs
        if [ "$RC" -eq 0 ]; then
            survived=$((survived+1)); echo "SURVIVED      $id: tests PASS on the mutant ($mod/$file)"
        elif printf '%s\n' "$OUT" | grep -qE '\[build failed\]|\[setup failed\]|^# |cannot find|undefined:|declared and not used'; then
            broken=$((broken+1)); echo "BUILD-BROKEN  $id: the mutant does not compile - not a kill"; printf '%s\n' "$OUT" | head -4 | sed 's/^/    /'
        else
            killed=$((killed+1))
            echo "KILLED        $id by $(printf '%s\n' "$OUT" | grep -oE -- '--- FAIL: [A-Za-z0-9_/#]+' | head -2 | sed 's/--- FAIL: //' | paste -sd, -)"
        fi
        rm -rf "$dest"
    done < "$SPEC"
}

fuzz_unmutated() { # real coverage-guided fuzzing of every distinct target, unmutated copy
    local mod targs t seen=""
    [ "$FUZZ_SECS" -gt 0 ] || return 0
    while IFS=$'\t' read -r id set mod file old new targs; do
        case "$id" in ''|'#'*) continue ;; esac
        [ "$set" = fuzz ] || continue
        for t in $(printf '%s' "$targs" | grep -oE 'Fuzz[A-Za-z0-9_]+'); do
            case " $seen " in *" $mod:$t "*) continue ;; esac
            seen="$seen $mod:$t"
            local d="$WORK/fz.$(printf '%s' "$mod:$t" | cksum | cut -d' ' -f1)" pkg=.
            make_copy "$mod" "$d"
            case "$targs" in *./internal/wi*) pkg=./internal/wi ;; esac
            gotest "$d/$mod" -run '^$' -fuzz "^$t\$" -fuzztime "${FUZZ_SECS}s" -parallel 4 "$pkg"
            if [ "$RC" -eq 0 ]; then echo "FUZZ-OK       $mod $t $(printf '%s\n' "$OUT" | grep -oE 'execs: [0-9]+' | tail -1)"
            else echo "FUZZ-FINDING  $mod $t (rc $RC)"; printf '%s\n' "$OUT" | tail -12 | sed 's/^/    /'; basered=$((basered+1)); fi
        done
    done < "$SPEC"
}

if [ "$PROVE" -eq 1 ]; then
    # ---- paired section 1.1 proof, over a throwaway fixture module ---------------------------------------
    FX="$WORK/fx"; mkdir -p "$FX/_tools/fx"
    printf 'module fx\n\ngo 1.22\n' > "$FX/_tools/fx/go.mod"
    printf 'package fx\n\nfunc Add(a, b int) int {\n\treturn a + b\n}\n' > "$FX/_tools/fx/add.go"
    printf 'package fx\n\nimport "testing"\n\nfunc TestAdd(t *testing.T) {\n\tif Add(2, 3) != 5 {\n\t\tt.Fatal("add")\n\t}\n}\n' > "$FX/_tools/fx/add_test.go"
    spec1() { printf '%s\tfuzz\t_tools/fx\tadd.go\t%s\t%s\t.\n' "$1" "$2" "$3" > "$WORK/spec.tsv"; }
    fails=0
    expect() { # name want_rc want_text -- args...
        local name="$1" want="$2" text="$3"; shift 4
        local out rc; out="$(bash "$HERE/prove-umbrella-mutants.sh" "$@" 2>&1)"; rc=$?
        if [ "$rc" = "$want" ] && printf '%s' "$out" | grep -q -- "$text"; then echo "  ok    $name (rc $rc, '$text')"
        else echo "  FAIL  $name: want rc $want + '$text', got rc $rc"; printf '%s\n' "$out" | tail -5 | sed 's/^/        /'; fails=$((fails+1)); fi
    }
    spec1 P0-control 'return a + b' 'return a - b';   expect "M0 control: a real killer is KILLED and the run passes" 0 "KILLED" -- --root "$FX" --spec "$WORK/spec.tsv"
    spec1 P1-survivor 'return a + b' 'return b + a';  expect "M1 a behaviour-preserving mutant SURVIVES -> rc 1" 1 "SURVIVED" -- --root "$FX" --spec "$WORK/spec.tsv"
    spec1 P2-missing 'return a * b' 'return a - b';   expect "M2 a mutation whose old text is absent is NOT-APPLIED -> rc 1" 1 "NOT-APPLIED" -- --root "$FX" --spec "$WORK/spec.tsv"
    spec1 P3-broken 'return a + b' 'return a +';      expect "M3 a mutant that does not compile is not a kill -> rc 1" 1 "BUILD-BROKEN" -- --root "$FX" --spec "$WORK/spec.tsv"
    spec1 P4-dup 'a' 'b';                             expect "M4 an old text that occurs more than once is NOT-APPLIED -> rc 1" 1 "NOT-APPLIED" -- --root "$FX" --spec "$WORK/spec.tsv"
    # M5: red baseline - make the fixture's own test fail
    cp -R "$FX" "$WORK/fx_red"; printf 'package fx\n\nimport "testing"\n\nfunc TestAdd(t *testing.T) { t.Fatal("red baseline") }\n' > "$WORK/fx_red/_tools/fx/add_test.go"
    spec1 P5-red 'return a + b' 'return a - b';       expect "M5 a red baseline is reported, never credited -> rc 1" 1 "BASELINE-RED" -- --root "$WORK/fx_red" --spec "$WORK/spec.tsv"
    expect "M6 a missing go toolchain is rc 2 (could not determine)" 2 "COULD NOT DETERMINE" -- --go /nonexistent/go --root "$FX" --spec "$WORK/spec.tsv"
    expect "M7 an unreadable spec is rc 2" 2 "COULD NOT DETERMINE" -- --root "$FX" --spec "$WORK/no-such.tsv"
    if [ "$fails" -eq 0 ]; then echo "prove-failure: 8 assertions, all mutations caught (M0-M7)"; exit 0; fi
    echo "prove-failure: $fails assertion(s) FAILED"; exit 1
fi

run_all
fuzz_unmutated
echo "----"
echo "summary: $total mutant(s): $killed killed, $survived survived, $notapplied not applied, $broken build-broken, $basered red baseline/finding"
if [ "$total" -eq 0 ]; then echo "COULD NOT DETERMINE: no mutant selected (set '$SET')"; exit 2; fi
if [ $((survived+notapplied+broken+basered)) -eq 0 ] && [ "$killed" -eq "$total" ]; then exit 0; fi
exit 1
