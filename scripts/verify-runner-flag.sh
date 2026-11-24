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
    expect "qa-up: forced absent runner refused rc2 before booting anything" 2 --grep 'refusing to fall back' -- \
        env QA_STATE_DIR="$T/qa" bash "$R/scripts/qa-up.sh" --runner="$ABSENT" --only vd
    expect "qa-up: unknown runner refused rc2 (also on --stop)" 2 --grep 'unknown container runner' -- \
        env QA_STATE_DIR="$T/qa" bash "$R/scripts/qa-up.sh" --runner=bogus --stop
    expect "qa-up: --runner=$GOOD --stop accepted, selected by flag" 0 --grep "runner: $GOOD \\(selected by flag\\)" -- \
        env QA_STATE_DIR="$T/qa" QA_REGISTRY_DIR="$T/qa-reg" bash "$R/scripts/qa-up.sh" --runner="$GOOD" --stop
    expect "qa-up: module helper missing -> rc2" 2 --grep 'COULD NOT DETERMINE' -- \
        env CONTAINERS_DIR="$T/nonexistent" bash "$R/scripts/qa-up.sh" --runner="$GOOD" --stop
    expect "qa-up: --help documents --runner" 0 --grep '[-][-]runner=podman' -- bash "$R/scripts/qa-up.sh" --help
    expect "deploy-langs: forced absent runner refused rc2 BEFORE any build/git" 2 --grep 'refusing to fall back' -- \
        bash "$R/_tools/deploy-langs.sh" --runner="$ABSENT" --dry-run
    expect "deploy-langs: --runner without value rc2" 2 --grep 'needs a value' -- bash "$R/_tools/deploy-langs.sh" --dry-run --runner
    expect "deploy-langs: unknown runner rc2" 2 --grep 'unknown container runner' -- bash "$R/_tools/deploy-langs.sh" --runner=bogus
    expect "deploy-langs: --help documents --runner" 0 --grep '[-][-]runner=NAME' -- bash "$R/_tools/deploy-langs.sh" --help
    expect "hawkscan: forced absent runner refused rc2 (not the skip rc0)" 2 --grep 'refusing to fall back' -- \
        env -u HAWK_API_KEY bash "$R/_tools/hawkscan/run.sh" --runner="$ABSENT"
    expect "hawkscan: forced $GOOD accepted (skips later for the missing key, rc0)" 0 --grep "runner: $GOOD" -- \
        env -u HAWK_API_KEY bash "$R/_tools/hawkscan/run.sh" --runner="$GOOD"
    expect "prove-ocr: forced absent runner refused rc2" 2 --grep 'refusing to fall back' -- \
        bash "$R/_tools/containers/prove-ocr.sh" --runner="$ABSENT"
    expect "od/start-daemon: accepts --runner and says no containers used" 1 --grep 'no containers used' -- \
        bash "$R/_tools/od/start-daemon.sh" --runner="$ABSENT"
    expect "od/start-daemon: --runner without value rc2" 2 -- bash "$R/_tools/od/start-daemon.sh" --runner
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
echo "--- $survivors survivor(s)"
[ "$survivors" -eq 0 ] && exit 0
exit 1
