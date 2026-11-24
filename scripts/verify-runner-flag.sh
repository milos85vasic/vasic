#!/usr/bin/env bash
# =============================================================================
# verify-runner-flag.sh -- does EVERY launcher in this repository honour the
# ecosystem-wide `--runner=NAME` contract (docs/RUNNER_FLAG.md)?
#
#   precedence   --runner=NAME | --runner NAME   >   $CONTAINERS_RUNNER   >   default
#   NAME         a runner the Containers Submodule supports, or `auto`
#   refusals     unknown NAME, or a forced runner that is not installed ->
#                exit 2 and NO fallback to another runner
#
# EVIDENCE, NOT CONFIG. Every case below EXECUTES the real launcher / binary on
# this host and reads its exit code and output. Nothing is mocked: the forced
# runner that must be refused is a REAL supported runner that is genuinely not
# installed here (derived from the module's own `runner list`, then proved
# absent with `command -v`), and the runner that must be accepted is a real one
# that is installed. Remote-host legs run the remote-side script locally (it is
# plain bash); the ssh transport itself is NOT exercised here (see HONEST
# BOUNDARY in docs/RUNNER_FLAG.md).
#
# USAGE
#   bash scripts/verify-runner-flag.sh                run the suite
#   bash scripts/verify-runner-flag.sh --prove-failure
#                       paired mutations (§1.1): sandbox copies of the shared
#                       helpers are broken one way each, and the SAME core cases
#                       must flag every mutant. The control (unmutated) must pass.
#   bash scripts/verify-runner-flag.sh --root DIR     suite against another checkout
#
# EXIT  0 all cases passed          1 a case failed / a mutant survived
#       2 COULD NOT DETERMINE (no go, no installed runner, no module helper,
#         bad --root) -- NEVER a pass
# =============================================================================
set -uo pipefail

SELF_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROOT="$SELF_ROOT"; PROVE=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --prove-failure) PROVE=1; shift ;;
        --root) [ "$#" -ge 2 ] || { echo "UNDETERMINED: --root needs a value" >&2; exit 2; }; ROOT="$2"; shift 2 ;;
        -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "UNDETERMINED: unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -d "$ROOT/_tools/lib" ] || { echo "UNDETERMINED: $ROOT is not an umbrella checkout (no _tools/lib)" >&2; exit 2; }
[ -r "$ROOT/submodules/containers/scripts/lib/runner.sh" ] || { echo "UNDETERMINED: the Containers Submodule helper is missing under $ROOT/submodules/containers (git submodule update --init submodules/containers)" >&2; exit 2; }
command -v go >/dev/null 2>&1 || { echo "UNDETERMINED: go toolchain absent (needed to build the module's runner helper)" >&2; exit 2; }

T="$(mktemp -d)" || exit 2
cleanup() { [ -n "${T:-}" ] && [ -d "$T" ] && rm -rf -- "$T"; }
trap cleanup EXIT

# ---- the REAL host: which supported runners are here? ------------------------
RB="$T/runner-bin"
( cd "$ROOT/submodules/containers" && go build -o "$RB" ./cmd/runner ) >/dev/null 2>&1 \
    || { echo "UNDETERMINED: cannot build the module's cmd/runner" >&2; exit 2; }
export CONTAINERS_RUNNER_BIN="$RB"
unset CONTAINERS_RUNNER
GOOD="" ABSENT=""
for n in $("$RB" list); do
    if command -v "$n" >/dev/null 2>&1; then [ -n "$GOOD" ] || GOOD="$n"; else [ -n "$ABSENT" ] || ABSENT="$n"; fi
done
# A runner whose binary name exists must also ANSWER; take it from the module.
if [ -n "$GOOD" ] && ! "$RB" resolve --runner "$GOOD" >/dev/null 2>&1; then GOOD=""; fi
[ -n "$GOOD" ]   || { echo "UNDETERMINED: no supported container runner is installed here" >&2; exit 2; }
[ -n "$ABSENT" ] || { echo "UNDETERMINED: every supported runner is installed here; cannot exercise the refusal path" >&2; exit 2; }
echo "host: installed runner under test = $GOOD ; supported-but-absent runner under test = $ABSENT"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/         | /' | tail -5; }
# expect LABEL WANT_RC [--grep PATTERN] -- CMD...   (captures stdout+stderr)
expect() {
    local label="$1" want="$2" pat="" out rc; shift 2
    if [ "${1:-}" = "--grep" ]; then pat="$2"; shift 2; fi
    [ "${1:-}" = "--" ] && shift
    out="$("$@" 2>&1)"; rc=$?
    if [ "$rc" != "$want" ]; then bad "$label (rc=$rc, wanted $want)" "$out"; return; fi
    if [ -n "$pat" ] && ! printf '%s' "$out" | grep -qE -- "$pat"; then bad "$label (rc ok, output lacks /$pat/)" "$out"; return; fi
    ok "$label"
}

# expect_absent LABEL WANT_RC PATTERN -- CMD...  rc must match AND output must NOT match PATTERN
expect_absent() {
    local label="$1" want="$2" pat="$3" out rc; shift 3
    [ "${1:-}" = "--" ] && shift
    out="$("$@" 2>&1)"; rc=$?
    if [ "$rc" != "$want" ]; then bad "$label (rc=$rc, wanted $want)" "$out"; return; fi
    if printf '%s' "$out" | grep -qE -- "$pat"; then bad "$label (output mentions /$pat/)" "$out"; return; fi
    ok "$label"
}

# A host with NO Go toolchain and NO cached runner binary: a PATH of symlinks to
# every real executable except go/gofmt, and an empty HOME (so no
# ~/.cache/containers-runner/runner). Built from this host's own binaries.
mk_nogo_env() {
    NOGO_BIN="$T/nogo-bin"; NOGO_HOME="$T/nogo-home"
    [ -d "$NOGO_BIN" ] && return 0
    mkdir -p "$NOGO_BIN" "$NOGO_HOME"
    local d f b
    for d in /usr/bin /bin; do
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            b="${f##*/}"
            case "$b" in go|gofmt) continue ;; esac
            [ -x "$f" ] && [ ! -e "$NOGO_BIN/$b" ] && ln -s "$f" "$NOGO_BIN/$b"
        done
    done
}
nogo() {   # nogo CMD... -- run CMD with the go-less PATH/HOME, no inherited runner state
    env -u CONTAINERS_RUNNER_BIN -u CONTAINERS_RUNNER -u XDG_CACHE_HOME PATH="$NOGO_BIN" HOME="$NOGO_HOME" "$@"
}

# ---- core cases: the shared helpers + the shell launchers, against tree $1 ----
core_cases() {
    local R="$1" E="$T/envfile" IN="$T/in.md"
    : > "$E"; echo hello > "$IN"
    # helixtranslate-local.sh: refusal, unknown, precedence, no silent fallback
    expect "local: forced absent runner ($ABSENT) refused rc2" 2 --grep 'not installed or not reachable' -- \
        env HELIX_ENVFILE="$E" bash "$R/_tools/helixtranslate-local.sh" --runner="$ABSENT" -i "$IN" -o "$T/o.md"
    expect "local: unknown runner refused rc2" 2 --grep 'unknown container runner' -- \
        env HELIX_ENVFILE="$E" bash "$R/_tools/helixtranslate-local.sh" --runner=bogus -i "$IN" -o "$T/o.md"
    expect "local: env CONTAINERS_RUNNER=absent refused rc2" 2 --grep 'selected via env' -- \
        env CONTAINERS_RUNNER="$ABSENT" HELIX_ENVFILE="$E" bash "$R/_tools/helixtranslate-local.sh" -i "$IN" -o "$T/o.md"
    # forced $GOOD beats HELIX_RUNTIME=<absent>: the failure line names $GOOD
    expect "local: --runner=$GOOD beats HELIX_RUNTIME=$ABSENT (flag wins, real run)" 1 --grep "runtime=$GOOD " -- \
        env HELIX_RUNTIME="$ABSENT" HELIX_IMAGE=localhost/vasic-runner-flag-proof-absent:none HELIX_ENVFILE="$E" \
        bash "$R/_tools/helixtranslate-local.sh" --runner="$GOOD" -i "$IN" -o "$T/o.md"
    expect "local: flag --runner=$ABSENT beats env CONTAINERS_RUNNER=$GOOD (refused)" 2 --grep "\"$ABSENT\" \\(selected via flag\\)" -- \
        env CONTAINERS_RUNNER="$GOOD" HELIX_ENVFILE="$E" bash "$R/_tools/helixtranslate-local.sh" --runner="$ABSENT" -i "$IN" -o "$T/o.md"
    # shared helper contract
    expect "helper: missing module -> rc2 with the fix named" 2 --grep 'submodule update --init' -- \
        env CONTAINERS_DIR="$T/nonexistent" bash -c '. "$1/_tools/lib/vasic-runner.sh"; vasic_runner_load' _ "$R"
    # remote-side validator (plain bash; runs locally)
    expect "remote run.sh: absent runner refused rc2, no fallback" 2 --grep 'not installed on' -- \
        env HOME="$T" bash "$R/_tools/helixtranslate-container/run.sh" "$ABSENT" p m en sr cyrillic
    expect "remote run.sh: shell-metachar runner name refused rc2" 2 --grep 'invalid runner name' -- \
        env HOME="$T" bash "$R/_tools/helixtranslate-container/run.sh" 'x;touch pwned' p m en sr cyrillic
    expect "remote run.sh: installed runner passes the check (stops later at the env file, rc90)" 90 --grep 'missing' -- \
        env HOME="$T/emptyhome" bash "$R/_tools/helixtranslate-container/run.sh" "$GOOD" p m en sr cyrillic
    # ht_runner_parse / ht_fleet_runtime (the fleet-wide override)
    expect "fleet lib: flag > env, override reaches ht_fleet_runtime" 0 --grep '^OK$' -- \
        env CONTAINERS_RUNNER=docker HT_FLEET="h1:podman h2:docker" bash -c '
            . "$1/_tools/lib/translation-fleet.sh"; ht_runner_parse --x --runner=nerdctl y 2>/dev/null || exit 9
            [ "${HT_ARGS[*]}" = "--x y" ] && [ "$(ht_fleet_runtime h1)" = nerdctl ] && [ "$(ht_fleet_runtime h2)" = nerdctl ] && echo OK' _ "$R"
    expect "fleet lib: env alone applies when no flag" 0 --grep '^OK$' -- \
        env CONTAINERS_RUNNER=docker HT_FLEET="h1:podman" bash -c '
            . "$1/_tools/lib/translation-fleet.sh"; ht_runner_parse a 2>/dev/null || exit 9
            [ "$(ht_fleet_runtime h1)" = docker ] && echo OK' _ "$R"
    expect "fleet lib: explicit auto clears the override (per-host config wins)" 0 --grep '^OK$' -- \
        env CONTAINERS_RUNNER=docker HT_FLEET="h1:podman" bash -c '
            . "$1/_tools/lib/translation-fleet.sh"; ht_runner_parse --runner=auto 2>/dev/null || exit 9
            [ "$(ht_fleet_runtime h1)" = podman ] && echo OK' _ "$R"
    expect "fleet lib: no flag, no env -> per-host config untouched" 0 --grep '^OK$' -- \
        env -u CONTAINERS_RUNNER HT_FLEET="h1:podman h2:docker" bash -c '
            . "$1/_tools/lib/translation-fleet.sh"; ht_runner_parse a 2>/dev/null || exit 9
            [ "$(ht_fleet_runtime h2)" = docker ] && echo OK' _ "$R"
    expect "fleet lib: malformed name refused rc2" 2 --grep 'invalid runner name' -- \
        bash -c '. "$1/_tools/lib/translation-fleet.sh"; ht_runner_parse "--runner=a b"' _ "$R"
    expect "fleet lib: --runner without value refused rc2" 2 -- \
        bash -c '. "$1/_tools/lib/translation-fleet.sh"; ht_runner_parse --runner' _ "$R"
    # the SSH shim refuses a malformed runner BEFORE any ssh
    expect "shim: malformed --runner refused rc2 before ssh" 2 --grep 'invalid runner name' -- \
        env HT_FLEET="h1:podman" HT_SSH_USER=u bash "$R/_tools/helixtranslate-container.sh" --runner='a;b' -i "$IN" -o "$T/o.md" -provider p -model m -target-lang sr
    expect "shim: malformed legacy HT_RUNTIME refused rc2 before ssh" 2 --grep 'invalid runner name' -- \
        env -u CONTAINERS_RUNNER HT_RUNTIME='podman;touch pwned' HT_FLEET="h1:podman" HT_SSH_USER=u bash "$R/_tools/helixtranslate-container.sh" -i "$IN" -o "$T/o.md" -provider p -model m -target-lang sr
    # B1: static servers and --stop need NO runner. On a host with no Go and no
    # cached runner binary, qa-up must still stop (and not mention a runner).
    mk_nogo_env
    command -v "$NOGO_BIN/go" >/dev/null 2>&1 && { bad "nogo PATH still resolves go"; return; }
    expect_absent "qa-up (no go, no cached runner): --stop --only vd rc0, no runner/go complaint" 0 'runner|go toolchain|COULD NOT' -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --stop --only vd
    expect_absent "qa-up (no go): --runner=$ABSENT --stop --only vd rc0 (stopping is not runner-dependent)" 0 'refusing|not installed|go toolchain' -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --runner="$ABSENT" --stop --only vd
    expect_absent "qa-up (no go): env CONTAINERS_RUNNER=bogus --stop --only mv rc0" 0 'unknown container runner|go toolchain' -- \
        nogo CONTAINERS_RUNNER=bogus QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --stop --only mv
    expect "qa-up (no go): --runner=$ABSENT --stop --only workshop rc0, warns instead of refusing" 0 --grep 'runner not selected on --stop' -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" QA_AI_HOME="$T/no-ai" bash "$R/scripts/qa-up.sh" --runner="$ABSENT" --stop --only workshop
    expect "qa-up (no go): a forced runner for a BOOT path is still refused rc2 (workshop)" 2 --grep 'go toolchain not found' -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --runner="$GOOD" --only workshop
    expect "qa-up (no go): a forced runner for a BOOT path is still refused rc2 (ai)" 2 --grep 'go toolchain not found' -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --runner="$GOOD" --only ai
    expect "qa-up (no go, no binary): malformed --runner shape refused rc2 at parse time" 2 --grep 'invalid runner name' -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --runner='A;b' --stop --only vd
    expect "qa-up (no go, no binary): well-formed unknown name cannot be checked at parse time; --stop --only vd still rc0 (B1)" 0 -- \
        nogo QA_STATE_DIR="$T/qa-nogo" QA_REGISTRY_DIR="$T/qa-nogo-reg" bash "$R/scripts/qa-up.sh" --runner=bogus --stop --only vd
    expect "qa-up: --runner without a value is a usage error rc2 even on --stop" 2 --grep 'needs a value' -- \
        env QA_STATE_DIR="$T/qa-nogo" bash "$R/scripts/qa-up.sh" --stop --only vd --runner
}

# ---- the full suite (real tree only) -----------------------------------------
full_suite() {
    local R="$ROOT" P="$T/probe" S="$T/sb" O="$T/ocr"
    core_cases "$R"
    # Go: the module-backed binaries, built fresh from this tree
    ( cd "$R/_tools/containers" && go build -o "$P" ./cmd/runtime-probe && go build -o "$S" ./cmd/site-build && go build -o "$O" ./cmd/ocr ) >/dev/null 2>&1 \
        || { bad "go build of runtime-probe / site-build / ocr"; return; }
    expect "runtime-probe: --runner=$GOOD reports runner=$GOOD source=flag" 0 --grep "runner=$GOOD source=flag" -- "$P" --runner="$GOOD"
    expect "runtime-probe: --runner $GOOD (two-arg form)" 0 --grep "runner=$GOOD source=flag" -- "$P" --runner "$GOOD"
    expect "runtime-probe: -name-only stays one bare name" 0 --grep "^$GOOD\$" -- "$P" --runner="$GOOD" -name-only
    expect "runtime-probe: forced absent $ABSENT refused rc2" 2 --grep 'refusing to fall back' -- "$P" --runner="$ABSENT"
    expect "runtime-probe: unknown runner refused rc2" 2 --grep 'unknown container runner' -- "$P" --runner=bogus
    expect "runtime-probe: env=$ABSENT refused rc2" 2 --grep 'selected via env' -- env CONTAINERS_RUNNER="$ABSENT" "$P"
    expect "runtime-probe: flag $GOOD beats env $ABSENT" 0 --grep "runner=$GOOD source=flag" -- env CONTAINERS_RUNNER="$ABSENT" "$P" --runner="$GOOD"
    expect "runtime-probe: --runner=auto beats env $ABSENT" 0 --grep "source=flag" -- env CONTAINERS_RUNNER="$ABSENT" "$P" --runner=auto
    expect "runtime-probe: default reports source=default" 0 --grep 'source=default' -- env -u CONTAINERS_RUNNER "$P"
    expect "site-build -probe: forced $GOOD" 0 --grep "runner=$GOOD source=flag" -- "$S" --runner="$GOOD" -probe
    expect "site-build -probe: forced absent refused rc2" 2 --grep 'refusing to fall back' -- "$S" --runner="$ABSENT" -probe
    expect "ocr -probe: forced $GOOD" 0 --grep "runner=$GOOD source=flag" -- "$O" --runner="$GOOD" -probe
    expect "ocr -probe: forced absent refused rc2" 2 --grep 'refusing to fall back' -- "$O" --runner="$ABSENT" -probe
    expect "go tests: runnersel + runtime-probe" 0 -- bash -c 'cd "$1/_tools/containers" && go test ./internal/runnersel ./cmd/runtime-probe' _ "$R"
    # shell launchers
    expect "qa-up: forced absent runner refused rc2 before booting anything (boot path: workshop)" 2 --grep 'refusing to fall back' -- \
        env QA_STATE_DIR="$T/qa" bash "$R/scripts/qa-up.sh" --runner="$ABSENT" --only workshop
    expect "qa-up: unknown runner refused rc2 on a boot path" 2 --grep 'unknown container runner' -- \
        env QA_STATE_DIR="$T/qa" bash "$R/scripts/qa-up.sh" --runner=bogus --only ai
    # A FORCED --runner naming an unknown / malformed runner is a typo: refused rc 2 at parse time even when
    # no container is needed (the env var form stays lenient on non-container paths). Membership uses the
    # module's runner binary when one is already available (never builds); shape is always checked.
    expect "qa-up: --runner=bogus --stop --only vd refused rc2 at parse time (unused runner is still a typo)" 2 --grep 'unknown container runner' -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner=bogus --stop --only vd
    expect "qa-up: --runner bogus (space form) --stop --only vd refused rc2" 2 --grep 'unknown container runner' -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner bogus --stop --only vd
    expect "qa-up: malformed --runner='A;b' --stop --only vd refused rc2 (shape)" 2 --grep 'invalid runner name' -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner='A;b' --stop --only vd
    expect "qa-up: --runner=$ABSENT (supported, not installed) --stop --only vd still accepted" 0 -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner="$ABSENT" --stop --only vd
    expect "qa-up: --runner=auto --stop --only vd accepted" 0 -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner=auto --stop --only vd
    expect "qa-up: env CONTAINERS_RUNNER=bogus --stop --only vd stays lenient (inherited env, not a typo here)" 0 -- \
        env CONTAINERS_RUNNER=bogus QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --stop --only vd
    expect "qa-up: --runner=$GOOD --stop accepted, selected by flag (stack stop is best-effort)" 0 --grep "runner: $GOOD \\(selected by flag\\)" -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner="$GOOD" --stop
    expect "qa-up: module helper missing -> rc2 on a boot path" 2 --grep 'COULD NOT DETERMINE' -- \
        env CONTAINERS_DIR="$T/nonexistent" bash "$R/scripts/qa-up.sh" --runner="$GOOD" --only workshop
    expect "qa-up: --help documents --runner" 0 --grep '[-][-]runner=podman' -- bash "$R/scripts/qa-up.sh" --help
    # deploy-langs publishes to LIVE sites: these cases run a COPY in a tree with
    # no sites, no git and no generator, so a regression in the refusal can fail
    # on a missing path but can never build, commit or push anything real.
    local DL="$T/dl"; rm -rf -- "$DL"; mkdir -p "$DL/_tools" "$DL/submodules"
    cp -r "$R/_tools/lib" "$DL/_tools/lib"; cp "$R/_tools/deploy-langs.sh" "$DL/_tools/"
    ln -s "$R/submodules/containers" "$DL/submodules/containers"
    expect "deploy-langs (sandbox copy): forced absent runner refused rc2 BEFORE any build/git" 2 --grep 'refusing to fall back' -- \
        bash "$DL/_tools/deploy-langs.sh" --runner="$ABSENT" --dry-run
    expect "deploy-langs (sandbox copy): --runner without value rc2" 2 --grep 'needs a value' -- bash "$DL/_tools/deploy-langs.sh" --dry-run --runner
    expect "deploy-langs (sandbox copy): unknown runner rc2" 2 --grep 'unknown container runner' -- bash "$DL/_tools/deploy-langs.sh" --runner=bogus --dry-run
    expect "deploy-langs: --help documents --runner" 0 --grep '[-][-]runner=NAME' -- bash "$R/_tools/deploy-langs.sh" --help
    expect "hawkscan: forced absent runner refused rc2 (not the skip rc0)" 2 --grep 'refusing to fall back' -- \
        env -u HAWK_API_KEY bash "$R/_tools/hawkscan/run.sh" --runner="$ABSENT"
    expect "hawkscan: forced $GOOD accepted (skips later for the missing key, rc0)" 0 --grep "runner: $GOOD" -- \
        env -u HAWK_API_KEY bash "$R/_tools/hawkscan/run.sh" --runner="$GOOD"
    # hawkscan, NO flag, a host with podman but no Go and no cached runner binary:
    # it must still pick the host runtime (legacy podman-else-docker detection)
    # and not skip. Runs a COPY of the script with a non-placeholder config and a
    # recording runtime named on PATH (logic proof only: the real scan needs a key).
    local HK="$T/hk" HKB="$T/hk-bin"; rm -rf -- "$HK" "$HKB"; mkdir -p "$HK/_tools/hawkscan" "$HKB"
    cp -r "$R/_tools/lib" "$HK/_tools/lib"; cp "$R/_tools/hawkscan/run.sh" "$HK/_tools/hawkscan/"
    sed 's/REPLACE_WITH_REAL_STACKHAWK_APPLICATION_ID/proof-app/' "$R/_tools/hawkscan/stackhawk.yml" > "$HK/_tools/hawkscan/stackhawk.yml"
    mkdir -p "$HK/submodules"; ln -sfn "$R/submodules/containers" "$HK/submodules/containers"
    printf '#!/bin/sh\necho "RECORDED-RUNTIME-CALL $*"\n' > "$HKB/podman"; chmod +x "$HKB/podman"
    mk_nogo_env
    expect "hawkscan (no flag, podman on PATH, no go, no cache): falls back to the host runtime" 0 --grep 'RECORDED-RUNTIME-CALL run --rm' -- \
        env -u CONTAINERS_RUNNER_BIN -u CONTAINERS_RUNNER PATH="$HKB:$NOGO_BIN" HOME="$NOGO_HOME" HAWK_API_KEY=x bash "$HK/_tools/hawkscan/run.sh"
    expect "hawkscan (forced runner, no go, no cache): strict rc2, no fallback" 2 --grep 'go toolchain not found' -- \
        env -u CONTAINERS_RUNNER_BIN PATH="$HKB:$NOGO_BIN" HOME="$NOGO_HOME" HAWK_API_KEY=x bash "$HK/_tools/hawkscan/run.sh" --runner=podman
    expect "prove-ocr: forced absent runner refused rc2" 2 --grep 'refusing to fall back' -- \
        bash "$R/_tools/containers/prove-ocr.sh" --runner="$ABSENT"
    expect "od/start-daemon: accepts --runner and says no containers used" 1 --grep 'no containers used' -- \
        bash "$R/_tools/od/start-daemon.sh" --runner="$ABSENT"
    expect "od/start-daemon: --runner without value rc2" 2 -- bash "$R/_tools/od/start-daemon.sh" --runner
    expect "od/start-daemon: --help rc 0 and documents --runner" 0 --grep '\-\-runner' -- bash "$R/_tools/od/start-daemon.sh" --help
    for hs in hawkscan/run.sh helixtranslate-local.sh helixtranslate-container.sh translate-fleet.sh; do
        expect "$hs: --help rc 0 and documents --runner" 0 --grep '\-\-runner' -- bash "$R/_tools/$hs" --help
    done
    # remote-fleet launchers refuse a malformed name locally, before ssh
    expect "distribute-helixtranslate.sh: malformed runner refused rc2 before ssh" 2 --grep 'invalid runner name' -- \
        env HT_SRC="$T" HT_FLEET="h1:podman" bash "$R/_tools/distribute-helixtranslate.sh" --runner='a;b'
    expect "translate-fleet.sh: malformed runner refused rc2 before any job" 2 --grep 'invalid runner name' -- \
        env HT_FLEET="h1:podman" bash "$R/_tools/translate-fleet.sh" --runner='a b' tag sr
    # the single wrapper doc lists every launcher
    local l missing=""
    for l in qa-up.sh deploy-langs.sh helixtranslate-local.sh hawkscan/run.sh start-daemon.sh helixtranslate-container.sh translate-fleet.sh distribute-helixtranslate.sh prove-ocr.sh site-build runtime-probe; do
        grep -q -- "$l" "$R/docs/RUNNER_FLAG.md" 2>/dev/null || missing="$missing $l"
    done
    if [ -z "$missing" ]; then ok "docs/RUNNER_FLAG.md lists every launcher"; else bad "docs/RUNNER_FLAG.md lacks:$missing"; fi
}

# ---- run ---------------------------------------------------------------------
if [ "$PROVE" = 0 ]; then
    echo "=== runner-flag suite against $ROOT ==="
    full_suite
    echo "--- $PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ] && [ "$PASS" -gt 0 ] && exit 0
    exit 1
fi

# ---- --prove-failure: paired mutations (data: sandbox copies are broken, the
# real tree is never edited) ---------------------------------------------------
SB="$T/sandbox"
mk_sandbox() {   # fresh copy of only what core_cases needs; module + go tree linked
    rm -rf -- "$SB"; mkdir -p "$SB/_tools/helixtranslate-container" "$SB/_tools/lib" "$SB/submodules"
    cp "$ROOT"/_tools/lib/*.sh "$SB/_tools/lib/"
    cp "$ROOT/_tools/helixtranslate-local.sh" "$ROOT/_tools/helixtranslate-container.sh" "$SB/_tools/"
    cp "$ROOT/_tools/helixtranslate-container/run.sh" "$SB/_tools/helixtranslate-container/"
    mkdir -p "$SB/scripts"; cp "$ROOT/scripts/qa-up.sh" "$SB/scripts/"
    ln -s "$ROOT/submodules/containers" "$SB/submodules/containers"
}
survivors=0
echo "=== --prove-failure: control + mutations of the shared helpers ==="
mk_sandbox; PASS=0; FAIL=0
core_cases "$SB" >/dev/null
if [ "$FAIL" -eq 0 ] && [ "$PASS" -gt 0 ]; then echo "  PASS M0 control: unmutated sandbox passes all $PASS core cases"
else echo "  FAIL M0 control: unmutated sandbox fails $FAIL case(s) -- every 'caught' below would be worthless"; exit 1; fi

mutant() {  # $1 label  $2 file (sandbox-relative)  $3 sed expression
    local label="$1" f="$2" expr="$3" before after
    mk_sandbox
    before="$(sha256sum "$SB/$f" | cut -d' ' -f1)"
    sed "$expr" "$SB/$f" > "$SB/$f.mut" && mv -f "$SB/$f.mut" "$SB/$f"
    after="$(sha256sum "$SB/$f" | cut -d' ' -f1)"
    if [ "$before" = "$after" ]; then echo "  FAIL $label: mutation did not change the file (inoperative proof)"; survivors=$((survivors+1)); return; fi
    PASS=0; FAIL=0
    core_cases "$SB" >/dev/null
    if [ "$FAIL" -gt 0 ]; then echo "  PASS $label: caught ($FAIL core case(s) failed on the mutant)"
    else echo "  FAIL $label: SURVIVED -- all core cases still pass"; survivors=$((survivors+1)); fi
}
mutant "M1 vasic_runner_maybe ignores --runner (flag silently dropped)" _tools/lib/vasic-runner.sh 's/--runner|--runner=\*) want=1/--runner|--runner=*) want=0/'
mutant "M2 vasic_runner_maybe skips runner_select (no validation)"      _tools/lib/vasic-runner.sh 's/^  runner_select || return 2$/  true/'
mutant "M3 ht_runner_parse: env beats flag"                             _tools/lib/translation-fleet.sh 's/^    if \[ "\$set" = 1 \]; then HT_RUNNER_SOURCE=flag$/    if [ "$set" = 1 ] \&\& [ -z "${CONTAINERS_RUNNER:-}" ]; then HT_RUNNER_SOURCE=flag/'
mutant "M4 ht_fleet_runtime ignores the override"                       _tools/lib/translation-fleet.sh 's/^    if \[ -n "\${HT_RUNNER_OVERRIDE:-}" \]; then printf.*$/    :/'
mutant "M5 ht_runner_parse accepts shell metacharacters"                _tools/lib/translation-fleet.sh 's/\*\[!a-z0-9-\]\*|-\*|"")/-*|"")/'
mutant "M6 remote run.sh drops its installed-check (fallback-by-failure)" _tools/helixtranslate-container/run.sh 's/^command -v "\$RUNTIME".*$/:/'
mutant "M7 helixtranslate-local: HELIX_RUNTIME outranks the forced runner" _tools/helixtranslate-local.sh 's/^RUNTIME="\${CONTAINERS_RUNNER:+\${CONTAINERS_RUNNER_CHOSEN:-}}"$/RUNTIME="${HELIX_RUNTIME:-}"/'
mutant "M8 vasic_runner_load swallows a missing helper"                 _tools/lib/vasic-runner.sh 's/^  if \[ ! -r "\$helper" \]; then$/  if false; then/'
mutant "M9 qa-up --stop refuses on a runner (B1 regression)"            scripts/qa-up.sh 's/|| { warn "runner not selected on --stop[^}]*}/|| exit 2/'
mutant "M10 qa-up selects a runner unconditionally, even for static/--stop (B1)" scripts/qa-up.sh 's/^RUNNER_NEEDED=0$/RUNNER_NEEDED=1/;s/^if \[ "\$STOP" -eq 1 \]; then { wants workshop.*$/:/;s/vasic_runner_maybe "\${QA_ORIG_ARGS\[@\]}"/{ vasic_runner_load \&\& runner_select; }/'
mutant "M12 qa-up parse-time check skipped (typo accepted when unused)"  _tools/lib/vasic-runner.sh 's/^  for n in \${names\[@\]+"\${names\[@\]}"}; do vasic_runner_check_name "\$n" || return 2; done$/  :/'
mutant "M13 parse-time shape check dropped"                              _tools/lib/vasic-runner.sh 's/^    ""|-\*|\*\[!a-z0-9-\]\*) printf/    "") printf/'
mutant "M14 parse-time membership check dropped"                         _tools/lib/vasic-runner.sh 's/^  if ! printf .%s\\n. "\$list" | grep -qx -- "\$name"; then$/  if false; then/'
mutant "M11 shim skips the runtime shape check (legacy HT_RUNTIME)"       _tools/helixtranslate-container.sh 's/^ht_runtime_check "\$RUNTIME" || exit 2$/:/'
echo "--- $survivors survivor(s)"
[ "$survivors" -eq 0 ] && exit 0
exit 1
