#!/usr/bin/env bash
# zero-gap-determinism-modules.sh — feature 010 T060 (umbrella part): MODULE determinism tests.
#
# ── Purpose ──────────────────────────────────────────────────────────────────
# scripts/zero-gap-determinism.sh proves the SWEEP RUNNER is byte-stable, and
# _tools/translate/reproducibility-selftest.sh is a static guard. Neither runs the
# umbrella's other deterministic generators/validators twice. This script does:
# every target below is run N times (default 5) against ONE frozen input and the
# sha256 of its captured output must be identical across all N runs.
#
#   gen-vd-all           _tools/gen  -site vasic.digital -lang en -what all  (whole output tree hashed)
#   gen-mv-all      _tools/gen  -site milosvasic.ru -lang en -what all (whole output tree hashed)
#   wi-gap-summary     workable-items-vsc gap summary --json   (on a COPY of the register)
#   wi-report-module   workable-items-vsc report --by-module --as-of <fixed date> (on the same COPY)
#   repro-selftest     _tools/translate/reproducibility-selftest.sh (stdout)
#
# Deferred, stated: scripts/zero-gap-coverage.sh (executes `go test` and four proofs per run;
# minutes per run, and another agent regenerates coverage.tsv) and scripts/zero-gap-sweep.sh
# (covered by scripts/zero-gap-determinism.sh on a full tree copy).
#
# ── Frozen input ─────────────────────────────────────────────────────────────
# The register DB is COPIED to a private scratch dir and the copy is what the commands read.
# Every other declared input (the files/dirs a target reads) is fingerprinted (sha256 over
# `find -type f | sort`) BEFORE the first run and AFTER the last. If it moved, the verdict is
# rc 2: a difference on a moving input is not a determinism finding, and identity on a moving
# input proves nothing.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   zero-gap-determinism-modules.sh [--runs N] [--root <dir>] [--only <name>]...
#                                   [--wi-bin <path>] [--gen-bin <path>]
#                                   [--cmd 'name::inputs::command']... [--no-builtin]
#   zero-gap-determinism-modules.sh --prove-failure     paired proof (section 1.1)
#   zero-gap-determinism-modules.sh --help
#
#   --runs N      repetitions (default 5; N >= 2)
#   --root <dir>  repository (default: this one); not a directory / not a git tree => rc 2
#   --only <n>    run only the named built-in target (repeatable); an unknown name => rc 2
#   --wi-bin/--gen-bin  prebuilt binaries; absent => built from source into the scratch dir
#                (`go build`, never into the tree)
#   --cmd 'name::inputs::command'  add a custom target. `inputs` is a space-separated list of
#                paths (relative to --root) to freeze-check, `command` runs under `bash -c` with
#                $ROOT, $RUN (a fresh per-run directory), $WI, $GEN, $DB exported. Its STDOUT is
#                the compared artifact. Used by --prove-failure to seed nondeterminism.
#   --no-builtin  do not register the built-in targets (custom --cmd targets only)
#
# ── Exit (three-valued; 2 is NEVER a pass) ───────────────────────────────────
#   0  every target produced N byte-identical outputs, at least one target ran, none were empty
#   1  a target's outputs differ across runs (the unified diff head and the first differing
#      run pair are printed)
#   2  COULD NOT DETERMINE: bad argument, tool missing, build failure, a target exited non-zero
#      (an identical failure is not determinism evidence), an EMPTY output (a hash of nothing is
#      identical by construction), zero targets, or an input moved while the runs executed.
#
# Wall clock: ~1 minute for the built-ins when the binaries are prebuilt. Memory: the commands
# are small; the one heavy step is `go build` — run the whole script under
# `systemd-run --user -p MemoryMax=8G` (section 12.6).

set -u
export LC_ALL=C

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
RUNS=5
ROOT=""
WI_BIN=""
GEN_BIN=""
BUILTIN=1
ONLY=()
CUSTOM=()
PROVE=0

die2() { echo "zero-gap-determinism-modules: COULD NOT DETERMINE: $*" >&2; exit 2; }

usage() { sed -n '2,/^set -u/p' "$SELF" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
    case "$1" in
        --runs) [ "$#" -ge 2 ] || die2 "--runs needs a value"; RUNS="$2"; shift 2 ;;
        --root) [ "$#" -ge 2 ] || die2 "--root needs a value"; ROOT="$2"; shift 2 ;;
        --only) [ "$#" -ge 2 ] || die2 "--only needs a value"; ONLY+=("$2"); shift 2 ;;
        --wi-bin) [ "$#" -ge 2 ] || die2 "--wi-bin needs a value"; WI_BIN="$2"; shift 2 ;;
        --gen-bin) [ "$#" -ge 2 ] || die2 "--gen-bin needs a value"; GEN_BIN="$2"; shift 2 ;;
        --cmd) [ "$#" -ge 2 ] || die2 "--cmd needs a value"; CUSTOM+=("$2"); shift 2 ;;
        --no-builtin) BUILTIN=0; shift ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die2 "unknown argument: $1" ;;
    esac
done

case "$RUNS" in ''|*[!0-9]*) die2 "--runs must be an integer" ;; esac
[ "$RUNS" -ge 2 ] || die2 "--runs must be >= 2 (one run compares nothing)"

if [ -z "$ROOT" ]; then ROOT="$(cd -- "$(dirname -- "$SELF")/.." && pwd -P)"; fi

# ─────────────────────────────────────────────────────────────────────────────
# Engine
# ─────────────────────────────────────────────────────────────────────────────
fingerprint() {   # $1 root, rest = relative paths -> sha256 over names+contents; "ABSENT" if none exist
    local root="$1"; shift
    local p f any=0
    {
        for p in "$@"; do
            [ -e "$root/$p" ] || { echo "MISSING $p"; continue; }
            any=1
            if [ -d "$root/$p" ]; then
                ( cd "$root" && find "$p" -type f -print0 | sort -z | xargs -0 -r sha256sum )
            else
                ( cd "$root" && sha256sum "$p" )
            fi
        done
    } | sha256sum | cut -d' ' -f1
    [ "$any" -eq 1 ] || return 0
}

run_engine() {   # uses globals ROOT RUNS TNAME[] TINPUTS[] TCMD[]; prints a report; returns 0/1/2
    local n=${#TNAME[@]} i r rc worst=0 undet=0 diffc=0
    [ "$n" -gt 0 ] || { echo "no targets registered: zero cases is never a pass" >&2; return 2; }
    local work; work="$(mktemp -d "${TMPDIR:-/tmp}/zgdm.XXXXXX")" || { echo "mktemp failed" >&2; return 2; }
    for ((i = 0; i < n; i++)); do
        local name="${TNAME[$i]}" inputs="${TINPUTS[$i]}" cmd="${TCMD[$i]}"
        local fp_before fp_after hashes=() first=""
        # shellcheck disable=SC2086
        fp_before="$(fingerprint "$ROOT" $inputs)"
        for ((r = 1; r <= RUNS; r++)); do
            local rd="$work/$name/run$r"; mkdir -p "$rd"
            ( export ROOT RUN="$rd" WI="$WI_BIN" GEN="$GEN_BIN" DB="$work/register.db"; cd "$ROOT" && bash -c "$cmd" ) \
                > "$work/$name/out$r" 2> "$work/$name/err$r"
            rc=$?
            if [ "$rc" -ne 0 ]; then
                echo "UNDET  $name run $r: command exited $rc (an identical failure is not determinism evidence); stderr head:" >&2
                head -5 "$work/$name/err$r" >&2
                undet=1; continue 2
            fi
            if [ ! -s "$work/$name/out$r" ]; then
                echo "UNDET  $name run $r: EMPTY output (the hash of nothing is identical by construction)" >&2
                undet=1; continue 2
            fi
            hashes+=("$(sha256sum < "$work/$name/out$r" | cut -d' ' -f1)")
        done
        # shellcheck disable=SC2086
        fp_after="$(fingerprint "$ROOT" $inputs)"
        if [ "$fp_before" != "$fp_after" ]; then
            echo "UNDET  $name: input fingerprint MOVED while the runs executed ($inputs) — not a determinism verdict" >&2
            undet=1; continue
        fi
        local uniq; uniq="$(printf '%s\n' "${hashes[@]}" | sort -u | wc -l)"
        if [ "$uniq" -eq 1 ]; then
            echo "PASS   $name: $RUNS runs, 1 distinct sha256 ${hashes[0]:0:16}…, $(wc -c < "$work/$name/out1") bytes"
        else
            diffc=1
            first=""
            for ((r = 2; r <= RUNS; r++)); do
                if [ "${hashes[$((r - 1))]}" != "${hashes[0]}" ]; then first="$r"; break; fi
            done
            echo "FAIL   $name: $RUNS runs, $uniq distinct sha256 — run 1 vs run $first differ:"
            diff -u "$work/$name/out1" "$work/$name/out$first" | head -20 | sed 's/^/         /'
        fi
    done
    [ -n "${ZGDM_KEEP:-}" ] && echo "kept: $work" || rm -rf "$work"
    if [ "$diffc" -eq 1 ]; then return 1; fi
    if [ "$undet" -eq 1 ]; then return 2; fi
    return 0
}

register() { TNAME+=("$1"); TINPUTS+=("$2"); TCMD+=("$3"); }

build_builtin() {
    want() { [ "${#ONLY[@]}" -eq 0 ] && return 0; local o; for o in "${ONLY[@]}"; do [ "$o" = "$1" ] && return 0; done; return 1; }
    local known="gen-vd-all gen-mv-all wi-gap-summary wi-report-module repro-selftest" o
    for o in "${ONLY[@]+"${ONLY[@]}"}"; do
        case " $known " in *" $o "*) ;; *) die2 "--only: unknown target '$o' (known: $known)" ;; esac
    done
    if want gen-vd-all || want gen-mv-all; then
        command -v go >/dev/null 2>&1 || [ -x "$GEN_BIN" ] || die2 "go toolchain absent and no --gen-bin"
        [ -d "$ROOT/_tools/gen" ] || die2 "$ROOT/_tools/gen missing"
        [ -x "$GEN_BIN" ] || { GEN_BIN="$SCRATCH/gen"; ( cd "$ROOT/_tools/gen" && go build -o "$GEN_BIN" . ) 2>"$SCRATCH/gen-build.err" || { head -5 "$SCRATCH/gen-build.err" >&2; die2 "go build _tools/gen failed"; }; }
        # the output tree is hashed whole; the generator reads _content/ and the site shells
        want gen-vd-all && register gen-vd-all "_content" \
            '"$GEN" -site vasic.digital -lang en -what all -root "$ROOT" -out "$RUN" >/dev/null && cd "$RUN" && find . -type f -print0 | sort -z | xargs -0 sha256sum'
        want gen-mv-all && register gen-mv-all "_content" \
            '"$GEN" -site milosvasic.ru -lang en -what all -root "$ROOT" -out "$RUN" >/dev/null && cd "$RUN" && find . -type f -print0 | sort -z | xargs -0 sha256sum'
    fi
    if want wi-gap-summary || want wi-report-module; then
        [ -f "$ROOT/docs/workable_items.db" ] || die2 "docs/workable_items.db absent"
        command -v go >/dev/null 2>&1 || [ -x "$WI_BIN" ] || die2 "go toolchain absent and no --wi-bin"
        [ -x "$WI_BIN" ] || { WI_BIN="$SCRATCH/wi"; ( cd "$ROOT/_tools/workable-items" && go build -o "$WI_BIN" . ) 2>"$SCRATCH/wi-build.err" || { head -5 "$SCRATCH/wi-build.err" >&2; die2 "go build workable-items failed"; }; }
        cp -- "$ROOT/docs/workable_items.db" "$SCRATCH/register.db" || die2 "cannot copy the register"
        # the engine's DB path is $work/register.db — point it at the frozen copy
        REGISTER_COPY="$SCRATCH/register.db"
        want wi-gap-summary && register wi-gap-summary "" \
            '"$WI" gap summary --json --repo "$ROOT" --db "$DB"'
        want wi-report-module && register wi-report-module "" \
            '"$WI" report --by-module --as-of 2026-10-08 --repo "$ROOT" --db "$DB" 2>/dev/null; [ $? -le 1 ]'  # rc 1 = register findings, still a rendered report
    fi
    if want repro-selftest; then
        [ -f "$ROOT/_tools/translate/reproducibility-selftest.sh" ] || die2 "reproducibility-selftest.sh absent"
        register repro-selftest "_tools" 'bash _tools/translate/reproducibility-selftest.sh 2>&1'
    fi
}

run_main() {
    [ -d "$ROOT" ] || die2 "--root is not a directory: $ROOT"
    { [ -d "$ROOT/.git" ] || [ -f "$ROOT/.git" ]; } || die2 "--root is not a git work tree: $ROOT"
    TNAME=(); TINPUTS=(); TCMD=()
    SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/zgdm-build.XXXXXX")" || die2 "mktemp failed"
    trap 'rm -rf "$SCRATCH"' EXIT
    REGISTER_COPY=""
    if [ "$BUILTIN" -eq 1 ]; then build_builtin; fi
    local c
    for c in "${CUSTOM[@]+"${CUSTOM[@]}"}"; do
        case "$c" in *::*::*) ;; *) die2 "--cmd must be 'name::inputs::command': $c" ;; esac
        register "${c%%::*}" "$(printf '%s' "${c#*::}" | sed 's/::.*//')" "${c#*::*::}"
    done
    # engine reads the frozen register copy through $DB; make it visible there
    if [ -n "$REGISTER_COPY" ]; then export ZGDM_REGISTER_COPY="$REGISTER_COPY"; fi
    run_engine_with_db
    return $?
}

run_engine_with_db() {
    # run_engine mktemps its own work dir and exports DB=$work/register.db; seed that path
    # from the frozen copy by wrapping the commands.
    if [ -n "${ZGDM_REGISTER_COPY:-}" ]; then
        local i
        for i in "${!TCMD[@]}"; do
            TCMD[$i]="DB='$ZGDM_REGISTER_COPY'; export DB; ${TCMD[$i]}"
        done
    fi
    run_engine
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired proof (section 1.1): seeded nondeterminism must be caught; the control must pass;
# rc 2 states must be demonstrated. Throwaway git repo — the real tree is never touched.
# ─────────────────────────────────────────────────────────────────────────────
prove_failure() {
    local pass=0 fail=0 rc out
    T="$(mktemp -d "${TMPDIR:-/tmp}/zgdm-proof.XXXXXX")" || die2 "mktemp failed"
    trap 'rm -rf "$T"' EXIT
    ( cd "$T" && git init -q . && echo frozen > in.txt && git add in.txt && git -c user.email=x@x -c user.name=x commit -qm i ) \
        || die2 "cannot create the throwaway repo"
    ok()  { echo "  PASS $1"; pass=$((pass + 1)); }
    bad() { echo "  FAIL $1"; fail=$((fail + 1)); }
    expect() {  # $1 label, $2 want rc, rest = args
        local label="$1" want="$2"; shift 2
        out="$(bash "$SELF" --root "$T" --no-builtin --runs 3 "$@" 2>&1)"; rc=$?
        if [ "$rc" -eq "$want" ]; then ok "$label (rc $rc)"; else bad "$label: wanted rc $want got $rc"; echo "$out" | head -8 | sed 's/^/       /'; fi
    }
    echo "zero-gap-determinism-modules --prove-failure"
    # control: a stable target passes
    expect "C0 control: stable target => 0" 0 --cmd 'stable::in.txt::cat in.txt; echo constant'
    # RED: timestamp leak (nanoseconds)
    expect "M1 seeded timestamp leak is caught" 1 --cmd 'ts::in.txt::date +%s%N'
    # RED: map-order leak (hash randomisation of a set of strings)
    expect "M2 seeded map-order leak is caught" 1 \
        --cmd "maporder::in.txt::PYTHONHASHSEED=random python3 -c 'print(list({\"a\",\"b\",\"c\",\"d\",\"e\",\"f\",\"g\",\"h\"}))'"
    # RED: pid leak
    expect "M3 seeded pid leak is caught" 1 --cmd 'pid::in.txt::echo $$'
    # RED mixed: one stable + one unstable => 1 (the unstable one must not be masked)
    expect "M4 one unstable among stable targets => 1" 1 \
        --cmd 'a::in.txt::echo same' --cmd 'b::in.txt::date +%N'
    # rc 2 states
    expect "U1 EMPTY output is never a pass" 2 --cmd 'empty::in.txt::true'
    expect "U2 identical failure is never a pass" 2 --cmd 'failing::in.txt::echo boom; exit 3'
    expect "U3 input that moves during the runs is rc 2, not a verdict" 2 \
        --cmd 'moving::in.txt::date +%s%N >> in.txt; echo constant'
    expect "U4 zero targets is never a pass" 2
    expect "U5 --runs 1 is refused" 2 --runs 1 --cmd 'x::in.txt::echo y'
    out="$(bash "$SELF" --root /nonexistent --no-builtin --cmd 'x::in.txt::echo y' 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ]; then ok "U6 --root /nonexistent => 2"; else bad "U6 got $rc"; fi
    out="$(bash "$SELF" --root "$T" --only no-such-target 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ]; then ok "U7 unknown --only => 2"; else bad "U7 got $rc"; fi
    echo "  $pass passed / $fail failed"
    [ "$fail" -eq 0 ] && return 0 || return 1
}

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi

run_main
rc=$?
case "$rc" in
    0) echo "VERDICT: PASS — every target byte-identical across $RUNS runs" ;;
    1) echo "VERDICT: FAIL — nondeterminism found" ;;
    *) echo "VERDICT: COULD NOT DETERMINE — not a pass" ;;
esac
exit "$rc"
