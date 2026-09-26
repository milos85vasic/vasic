#!/usr/bin/env bash
# =============================================================================================
# zero-gap-class-live-vs-source.sh — feature 010 sweep class `live-vs-source` (task T024).
#
# WHAT IT DETECTS (constitution "Source Is Not Served"; population_kind `wire`)
#   Users are served by the RUNNING build, not by the source. For every service this host is
#   meant to run, the class asks the running thing what it is and compares that with the
#   source it claims to be built from:
#     high   build-freshness  <item>:commit    the served build's source identity (/api/health
#                                              `source_commit`, else the running Go binary's
#                                              `vcs.revision`) is not the source repo's HEAD
#     high   build-freshness  <item>:dirty     the served build says it was built from a dirty
#                                              tree (`source_dirty=true` / `vcs.modified=true`)
#     medium false-evidence   <item>:stamp     the served build carries no source identity, or
#                                              its `vcs.revision` is not a commit of its source
#                                              repo — the running build cannot be tied to source
#     medium build-freshness  <item>:build-age with NO verified identity: the running binary is
#                                              older than the source HEAD commit; for a built
#                                              static site: a tracked source file is newer than
#                                              the built index.html (scripts/qa-up.sh's own rule)
#     high   availability     <item>:health    a container is running and its healthcheck says
#                                              `unhealthy`
#     medium build-freshness  <item>:started   a container whose executable is bind-mounted
#                                              from the source tree started before the source
#                                              HEAD commit was made: the binary it loaded
#                                              predates that commit
#     high   build-freshness  <item>:index     a static server's `/` is not the committed
#                                              HEAD:index.html (tracked docroot), or not the
#                                              built docroot's index.html (build docroot)
#
# POPULATION AND WHY (docs/zero-gap/sweep-classes.tsv row `live-vs-source`; DERIVED, not listed)
#   typed tokens `service:<...>`, the union of
#     service:qa-up/<name>                 every service scripts/qa-up.sh boots — the names are
#                                          read from its `--only` argument list, the static
#                                          docroots from its `start_static <name> "$ROOT/..."`
#                                          lines, its state dir from its STATE_DIR default
#     service:compose/<project>/<service>  every service of workshop/platform/compose.yml
#                                          (project = its `name:`), PLUS every container
#                                          `podman ps` shows RUNNING whose compose config-file
#                                          label is a git-tracked file under --root
#   so a service added to either definition, or a running container of any tracked compose
#   file, is covered without editing this class. HOW each qa-up name is probed is a small
#   table below (stack services: workshop, ai); a qa-up name with no probe method and no
#   start_static docroot is COULD-NOT-INSPECT, never skipped.
#
# RULES
#   * A defined service that is NOT running is REPORTED as COULD-NOT-INSPECT (its freshness was
#     not inspected), and is NOT a finding: a stopped service serves nobody stale code. So a sweep
#     with any defined service stopped exits 2 for this class, by design (controller ruling in the
#     feature-010 class review): rc 2 is the honest answer, never rewritten to a pass or a finding.
#   * A health endpoint that does not answer while the service's own state says it is up is
#     COULD-NOT-INSPECT for that item; a container that is up but `unhealthy` is a FINDING.
#   * The build-age heuristics fire only when no verified identity exists (commit time and build
#     time are not an identity; a build-then-commit sequence shows the same order).
#   * LIVE SAFETY: read-only. Loopback GETs only (`curl -s --max-time 5`, non-loopback addresses
#     are refused), `podman ps`/`podman inspect`, `git` read commands with --no-optional-locks,
#     `go version -m` on the running binary (with HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME in the
#     class's private temp dir, so go's telemetry counter never writes under the real HOME),
#     `podman inspect` with a NIL-SAFE template (`{{if .State.Health}}...{{end}}`: in podman 5.x
#     .State.Health is a pointer, nil for a container without a healthcheck), /proc/<pid>/cmdline of a pid the service's own state
#     file records (checked to be that service's binary before anything else is read). Nothing is
#     restarted, signalled, written or logged in to; workshop/platform/bin is never touched.
#
# CORPUS MODE (--corpus <dir>): each file is one service fixture (key=value, see
#   _tests/fixtures/zero-gap/live-vs-source/). The class builds a scratch git repository with two
#   commits at fixed dates (so commit ids are deterministic), serves each fixture's health JSON
#   and index pages from ONE python3 http.server on a free loopback port that it starts itself
#   and kills by its own pid before exiting, and answers `podman inspect` / `go version -m`
#   from fixture data through PATH shims in its private temp dir. The SAME probe functions run
#   in both modes; only discovery differs.
#
# USAGE   zero-gap-class-live-vs-source.sh --root <abs dir> [--emit-population | --corpus <abs dir>]
#         zero-gap-class-live-vs-source.sh --prove-failure
# EXIT    0 every item inspected, no finding · 1 at least one FINDING · 2 could not determine
#         (an item not running, unreachable, a tool absent, an empty population) — never a pass.
#
# MEASURED (live tree, 2026-09-26, review fix round; three runs byte-identical, about 0.7 s each)
#   5 services, all running, 3 FINDINGs (1 high, 2 medium), 0 COULD-NOT-INSPECT; all 3 hand-read
#   and real (precision 3/3): workshop serves source_commit 185fb158c4f4 while workshop HEAD is
#   1 commit ahead; the workshop container started before that HEAD commit; the ai binary's
#   vcs.revision is a commit of the umbrella, not of ai_interviewing. The nil-health template case
#   is UNCONFIRMED on this host (every running container here has a healthcheck); it is guarded
#   and proven against a shim that fails the unguarded template the way podman 5.x does.
#
# WHAT IT DOES NOT SEE
#   * a service started by hand outside scripts/qa-up.sh and outside a tracked compose file;
#   * whether the served build equals HEAD when the service exposes no identity and the binary
#     is not a Go binary with VCS stamping (only the build-age heuristic is left);
#   * a stale static page other than `/` (only index.html is compared), and asset hashes;
#   * an untracked source file: the static build-age rule reads `git ls-files` (tracked files only),
#     so an untracked source newer than the built index.html is not seen (the corpus fixture
#     repositories the class builds for itself hold tracked files only);
#   * a container whose executable comes from its IMAGE (no source relation is derivable);
#   * WORKSHOP_PROJECT_NAME variants of the workshop state file (the class runs under env -i,
#     so it reads the default platform/run/server.json, exactly as workshop/scripts/_common.sh
#     resolves it with that variable unset); their CONTAINERS are still covered via podman.
# =============================================================================================
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
SELF_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SELF="$SELF_ROOT/scripts/$(basename -- "${BASH_SOURCE[0]}")"

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

# ---------------------------------------------------------------------------------------------
# --prove-failure: the paired proof, on THROWAWAY copies of the corpus (never on the live tree).
# ---------------------------------------------------------------------------------------------
prove_failure() {
    local FIX="$SELF_ROOT/_tests/fixtures/zero-gap/live-vs-source" T pass=0 fail=0 rc before after loc n exp
    ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$*"; }
    bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$*"; }
    fp() { { find "$FIX" "$SELF" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 sha256sum 2>/dev/null; } | sha256sum | cut -d' ' -f1; }
    for d in planted clean; do [ -d "$FIX/$d" ] || { echo "live-vs-source prove-failure: corpus part $d missing — cannot determine" >&2; return 2; }; done
    [ -f "$FIX/expect.tsv" ] || { echo "live-vs-source prove-failure: expect.tsv missing — cannot determine" >&2; return 2; }
    before=$(fp)
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-lvs-prove.XXXXXX") || return 2
    trap 'rm -rf "$T"' RETURN
    mkdir -p "$T/tmp" "$T/root"
    cp -R "$FIX/planted" "$T/planted"; cp -R "$FIX/clean" "$T/clean"
    # run <out-prefix> <args...>: the class under a minimal environment (the runner's allow-list), cwd = a throwaway root
    run() {
        local o=$1; shift
        ( cd "$T/root" && exec env -i PATH="${PROVE_PATH:-$PATH}" HOME="${HOME:-/nonexistent}" TMPDIR="$T/tmp" LC_ALL=C LANG=C \
            bash "$SELF" "$@" ) </dev/null >"$T/$o.out" 2>"$T/$o.err"
        rc=$?
    }
    leftovers() { pgrep -u "$(id -u)" -f -- "$T/tmp/" 2>/dev/null || true; }

    # C0 control: the clean corpus yields no finding, rc 0, every item inspected.
    run c0 --root "$T/root" --corpus "$T/clean"
    n=$(find "$T/clean" -type f | wc -l)
    if [ "$rc" -eq 0 ] && ! grep -q '^FINDING' "$T/c0.out" && ! grep -q '^COULD-NOT-INSPECT' "$T/c0.out" && grep -qx "INSPECTED $n" "$T/c0.out"; then
        ok "C0 clean corpus => rc 0, no finding, INSPECTED $n"
    else bad "C0 rc=$rc $(head -c 600 "$T/c0.out" "$T/c0.err" | tr '\n' '|')"; fi

    # P1 planted corpus: rc 1, every expect.tsv location reported (recall 1.0), nothing unplanted.
    run p1 --root "$T/root" --corpus "$T/planted"
    exp=$(grep -v '^#' "$FIX/expect.tsv" | cut -f1 | LC_ALL=C sort -u)
    local got; got=$(awk '$1 == "FINDING" { print $5 }' "$T/p1.out" | LC_ALL=C sort -u)
    if [ "$rc" -eq 1 ] && [ -n "$exp" ] && [ "$got" = "$exp" ]; then ok "P1 planted corpus => rc 1, all $(printf '%s\n' "$exp" | wc -l) planted locations reported, none unplanted"
    else bad "P1 rc=$rc missing=[$(comm -23 <(printf '%s\n' "$exp") <(printf '%s\n' "$got") | tr '\n' ' ')] unexpected=[$(comm -13 <(printf '%s\n' "$exp") <(printf '%s\n' "$got") | tr '\n' ' ')] $(head -c 400 "$T/p1.err" | tr '\n' '|')"; fi

    # P2 determinism: the planted run is byte-identical on a second run.
    cp "$T/p1.out" "$T/p1.first"; run p1 --root "$T/root" --corpus "$T/planted"
    if cmp -s "$T/p1.first" "$T/p1.out"; then ok "P2 planted run byte-identical twice"; else bad "P2 output differs between two runs"; fi

    # P3 unreachable health endpoint: COULD-NOT-INSPECT for that item, never a finding, never clean.
    mkdir -p "$T/unreach"; printf 'probe=stack\nhealth=none\n' >"$T/unreach/down.svc"; cp "$T/clean/stack-match.svc" "$T/unreach/"
    run p3 --root "$T/root" --corpus "$T/unreach"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT down.svc ' "$T/p3.out" && ! grep -q '^FINDING' "$T/p3.out"; then ok "P3 unreachable health => COULD-NOT-INSPECT down.svc, no finding, rc 2"
    else bad "P3 rc=$rc $(head -c 400 "$T/p3.out" | tr '\n' '|')"; fi

    # P4 empty population: rc 2, never clean.
    mkdir -p "$T/empty"; run p4 --root "$T/root" --corpus "$T/empty"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' "$T/p4.out"; then ok "P4 empty corpus => rc 2"; else bad "P4 rc=$rc"; fi

    # P5 --root /nonexistent: rc 2.
    run p5 --root /nonexistent
    if [ "$rc" -eq 2 ] && grep -qx 'INSPECTED 0' "$T/p5.out" && grep -q '^POPULATION-SHA ' "$T/p5.out"; then ok "P5 --root /nonexistent => rc 2, INSPECTED and POPULATION-SHA still printed"; else bad "P5 rc=$rc $(tr '\n' '|' <"$T/p5.out")"; fi
    run p5e --root /nonexistent --emit-population
    if [ "$rc" -eq 2 ]; then ok "P5e --root /nonexistent --emit-population => rc 2"; else bad "P5e rc=$rc"; fi

    # P6 a broken tool (curl that always fails) on the CLEAN corpus: rc 2, never 0.
    mkdir -p "$T/brokenbin"; printf '#!/bin/sh\nexit 7\n' >"$T/brokenbin/curl"; chmod +x "$T/brokenbin/curl"
    PROVE_PATH="$T/brokenbin:$PATH" run p6 --root "$T/root" --corpus "$T/clean"
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' "$T/p6.out"; then ok "P6 broken curl => rc 2, no finding"; else bad "P6 rc=$rc"; fi

    # P7 a missing interpreter (python3 that cannot run): rc 2, never 0.
    rm -rf "$T/brokenbin"; mkdir -p "$T/brokenbin"; printf '#!/bin/sh\nexit 127\n' >"$T/brokenbin/python3"; chmod +x "$T/brokenbin/python3"
    PROVE_PATH="$T/brokenbin:$PATH" run p7 --root "$T/root" --corpus "$T/clean"
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' "$T/p7.out"; then ok "P7 unusable python3 => rc 2, no finding"; else bad "P7 rc=$rc"; fi

    # P8 a non-git --root (the qa-up/compose definitions are absent): cannot enumerate => rc 2.
    run p8 --root "$T/root" --emit-population
    if [ "$rc" -eq 2 ]; then ok "P8 root without the tracked service definitions => --emit-population rc 2"; else bad "P8 rc=$rc"; fi

    # P9 no process outlives the class (the corpus HTTP server is killed by its own pid).
    loc=$(leftovers)
    if [ -z "$loc" ]; then ok "P9 no process left behind under the proof's TMPDIR"
    else bad "P9 leftover pid(s): $loc"; for n in $loc; do kill "$n" 2>/dev/null; done; fi

    # P10 the live population, when enumerable, is typed service tokens only (never corpus fixtures).
    run p10 --root "$SELF_ROOT" --emit-population
    if { [ "$rc" -eq 0 ] && [ -s "$T/p10.out" ] && ! grep -qv '^service:' "$T/p10.out"; } || [ "$rc" -eq 2 ]; then ok "P10 live --emit-population rc=$rc, every token typed service:*"
    else bad "P10 rc=$rc $(head -c 300 "$T/p10.out" | tr '\n' '|')"; fi

    # I1 the live corpus and this script are byte-identical before and after the proof.
    after=$(fp)
    if [ "$before" = "$after" ]; then ok "I1 live corpus and class script byte-identical before/after the proof"; else bad "I1 the live tree changed"; fi

    printf 'live-vs-source prove-failure: %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] && return 0 || return 1
}

CLASS=live-vs-source
QA_REL=scripts/qa-up.sh
COMPOSE_REL=workshop/platform/compose.yml
FOREIGN_REV=0123456789abcdef0123456789abcdef01234567   # corpus only: a commit id no fixture repo holds
EMPTY_SHA=$(printf '' | sha256sum | cut -d' ' -f1)

FOUT=() COUT=()
# one-line, ASCII-only, control-free text for a description / reason
txt() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' | LC_ALL=C tr -c ' -~' '?'; }
# a value that came from a server or a file: keep only a small safe alphabet, cap its length
safe() { printf '%s' "$1" | LC_ALL=C tr -cd 'A-Za-z0-9._:+@=,/-' | cut -c1-64; }
finding() { FOUT+=("FINDING $CLASS $1 $2 $3 $(txt "$4") $5"); }   # sev cat loc desc ref
cni() { COUT+=("COULD-NOT-INSPECT $1 $(txt "$2")"); }             # part reason
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '@%s' "$1"; }
g() { local d=$1; shift; git --no-optional-locks -C "$d" "$@"; }
is_hex40() { [[ $1 =~ ^[0-9a-f]{40}$ ]]; }
sha_of() { sha256sum "$1" 2>/dev/null | cut -c1-12; }

# jget <json file> <key>... -> one line per key (bool as true/false, absent as empty); rc 3 = not a JSON object
jget() {
    python3 -c 'import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
except Exception:
    sys.exit(3)
if not isinstance(d, dict):
    sys.exit(3)
for k in sys.argv[2:]:
    v = d.get(k)
    if isinstance(v, bool):
        v = "true" if v else "false"
    elif v is None or isinstance(v, (dict, list)):
        v = ""
    print(str(v).replace("\n", " ").replace("\r", " "))' "$@"
}

# get <url> <outfile> -> HTTP code on stdout (000 when nothing answered). Loopback only.
get() {
    local host code
    host=$(printf '%s' "$1" | sed -n 's#^https\{0,1\}://\(\[[^]]*\]\|[^/:]*\).*#\1#p')
    case "$host" in 127.0.0.1|localhost|'[::1]') ;; *) printf 'nonloopback'; return 0 ;; esac
    code=$(curl -s -g --noproxy '*' --connect-timeout 3 --max-time 5 -o "$2" -w '%{http_code}' -- "$1" 2>/dev/null) || code=000
    case "$code" in [0-9][0-9][0-9]) printf '%s' "$code" ;; *) printf '000' ;; esac
}

# relation <repo> <rev> <head> -> short text how <rev> relates to <head>
relation() {
    local n
    if g "$1" merge-base --is-ancestor "$2" "$3" 2>/dev/null; then
        n=$(g "$1" rev-list --count "$2..$3" 2>/dev/null) || n='?'
        printf 'HEAD is %s commit(s) ahead of it' "$n"
    elif g "$1" cat-file -e "$2^{commit}" 2>/dev/null; then printf 'it is not an ancestor of HEAD'
    else printf 'it is not a commit of the source repository'; fi
}

# ---- probe: a stack service that answers /api/health (+ optional running binary) -------------
# probe_stack <token> <evref> <repo dir> <repo display> <base url> <exe or ''>
probe_stack() {
    local tok=$1 ref=$2 repo=$3 rd=$4 url=$5 exe=$6 head ct body code vals commit dirty build info rev mod verified=0 mt
    head=$(g "$repo" rev-parse --verify -q 'HEAD^{commit}' 2>/dev/null) || { cni "$tok" "source repository $rd has no readable HEAD"; return; }
    body="$WORK/body.$RANDOM"
    code=$(get "$url/api/health" "$body")
    if [ "$code" = nonloopback ]; then cni "$tok" "health address is not loopback; not probed"; return; fi
    if [ "$code" != 200 ]; then
        cni "$tok" "/api/health did not answer HTTP 200 (got $code) while the service's state says it is up; build freshness not inspected (not a finding)"; return
    fi
    if ! vals=$(jget "$body" source_commit source_dirty build); then
        cni "$tok" "/api/health answered but is not a JSON object (or python3 is unusable); build freshness not inspected"; return
    fi
    { IFS= read -r commit; IFS= read -r dirty; IFS= read -r build; } <<<"$vals"
    build=$(safe "$build"); [ -n "$build" ] || build='(no build id)'
    if is_hex40 "$commit"; then
        if [ "$commit" != "$head" ]; then
            finding high build-freshness "$tok:commit" "served build $build reports source_commit ${commit:0:12} but source HEAD of $rd is ${head:0:12} ($(relation "$repo" "$commit" "$head"))" "$ref"
        fi
        if [ "$dirty" = true ]; then
            finding high build-freshness "$tok:dirty" "served build $build reports source_dirty=true: it was built from uncommitted changes of $rd, not from any commit" "$ref"
        fi
        return
    fi
    if [ -z "$exe" ]; then
        finding medium false-evidence "$tok:stamp" "the served build exposes no source identity (no 40-hex source_commit in /api/health, no running binary to read a stamp from): it cannot be tied to $rd" "$ref"
        return
    fi
    command -v go >/dev/null 2>&1 || { cni "$tok" "go is absent: the running binary's build stamp cannot be read"; return; }
    # HOME / XDG_CONFIG_HOME point into the private scratch dir: `go` keeps a telemetry counter file
    # under the user's config dir, and the class must never write outside $TMPDIR
    mkdir -p "$WORK/gohome/.config" "$WORK/gohome/.cache" 2>/dev/null
    info=$(HOME="$WORK/gohome" XDG_CONFIG_HOME="$WORK/gohome/.config" XDG_CACHE_HOME="$WORK/gohome/.cache" \
           GOTOOLCHAIN=local GOFLAGS='' go version -m "$exe" 2>/dev/null) || { cni "$tok" "go version -m could not read the running binary"; return; }
    rev=$(awk '$1 == "build" && $2 ~ /^vcs\.revision=/ { sub(/^vcs\.revision=/, "", $2); print $2; exit }' <<<"$info")
    mod=$(awk '$1 == "build" && $2 ~ /^vcs\.modified=/ { sub(/^vcs\.modified=/, "", $2); print $2; exit }' <<<"$info")
    if is_hex40 "$rev" && g "$repo" cat-file -e "$rev^{commit}" 2>/dev/null; then
        verified=1
        if [ "$rev" != "$head" ]; then
            finding high build-freshness "$tok:commit" "the running binary's vcs.revision is ${rev:0:12} but source HEAD of $rd is ${head:0:12} ($(relation "$repo" "$rev" "$head"))" "$ref"
        fi
        if [ "$mod" = true ]; then
            finding high build-freshness "$tok:dirty" "the running binary's vcs.modified=true: it was built from uncommitted changes of $rd" "$ref"
        fi
    elif is_hex40 "$rev"; then
        local where="it is not a commit of $rd"
        if [ -n "${ROOT:-}" ] && [ -z "$CORPUS" ] && g "$ROOT" cat-file -e "$rev^{commit}" 2>/dev/null; then
            where="it is a commit of the repository at --root, not of $rd"
        fi
        finding medium false-evidence "$tok:stamp" "the running binary's vcs.revision ${rev:0:12} does not identify its source: $where; /api/health carries no source_commit, so the served build cannot be tied to $rd" "$ref"
    else
        finding medium false-evidence "$tok:stamp" "neither /api/health (no source_commit) nor the running binary (no vcs.revision) carries a source identity: the served build cannot be tied to $rd" "$ref"
    fi
    if [ "$verified" -eq 0 ]; then
        mt=$(stat -L -c %Y "$exe" 2>/dev/null) || { cni "$tok" "the running binary's mtime cannot be read"; return; }
        ct=$(g "$repo" log -1 --format=%ct HEAD 2>/dev/null) || { cni "$tok" "source HEAD commit time of $rd cannot be read"; return; }
        if [ "$mt" -lt "$ct" ]; then
            finding medium build-freshness "$tok:build-age" "with no verified identity, the running binary (mtime $(iso "$mt")) is older than source HEAD ${head:0:12} of $rd (committed $(iso "$ct"))" "$ref"
        fi
    fi
}

# ---- probe: compose containers of a service -------------------------------------------------
# probe_compose <token> <evref> <repo dir> <repo display> <container ids (space separated)>
probe_compose() {
    local tok=$1 ref=$2 repo=$3 rd=$4 ids=$5 id line st hs started path mounts m src dst host rtop ct head
    command -v podman >/dev/null 2>&1 || { cni "$tok" "podman is absent: the container cannot be inspected"; return; }
    if [ -z "$ids" ]; then
        cni "$tok" "defined in $ref but no container of it is running: a stopped service serves nobody (not a finding); its freshness is not inspected"; return
    fi
    for id in $ids; do
        line=$(podman inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}|{{.State.StartedAt.Unix}}|{{.Path}}|{{range .Mounts}}{{.Source}}>{{.Destination}};{{end}}' "$id" 2>/dev/null) \
            || { cni "$tok" "podman inspect ${id:0:12} failed (the container is gone or podman refused)"; continue; }
        IFS='|' read -r st hs started path mounts <<<"$line"
        if [ "$st" != running ]; then cni "$tok" "container ${id:0:12} is $(safe "$st"), not running; not inspected"; continue; fi
        case "$hs" in
            unhealthy) finding high availability "$tok:health" "container ${id:0:12} is running but its healthcheck reports unhealthy" "$ref" ;;
            starting)  cni "$tok" "container ${id:0:12} healthcheck is still starting; health not determined" ;;
        esac
        [[ $started =~ ^[0-9]+$ ]] || { cni "$tok" "container ${id:0:12} start time is unreadable"; continue; }
        host=""
        IFS=';' read -r -a marr <<<"$mounts"
        for m in "${marr[@]}"; do
            [ -n "$m" ] || continue
            src=${m%%>*}; dst=${m#*>}
            if [ "$path" = "$dst" ] || [ "${path#"$dst"/}" != "$path" ]; then host="$src${path#"$dst"}"; fi
        done
        [ -n "$host" ] || continue                       # executable from the image: no source relation
        rtop=$(readlink -m -- "$repo")
        case "$(readlink -m -- "$host")" in "$rtop"/*) ;; *) continue ;; esac
        head=$(g "$repo" rev-parse --verify -q 'HEAD^{commit}' 2>/dev/null) || { cni "$tok" "source repository $rd has no readable HEAD"; continue; }
        ct=$(g "$repo" log -1 --format=%ct HEAD 2>/dev/null) || { cni "$tok" "source HEAD commit time of $rd cannot be read"; continue; }
        if [ "$started" -lt "$ct" ]; then
            finding medium build-freshness "$tok:started" "container ${id:0:12} started $(iso "$started") running $(safe "$path"), bind-mounted from $rd, but source HEAD ${head:0:12} was committed later ($(iso "$ct")): the binary it loaded predates that commit" "$ref"
        fi
    done
}

# ---- probe: a static server ------------------------------------------------------------------
# probe_static <token> <evref> <docroot dir> <docroot display> <url ending in />
probe_static() {
    local tok=$1 ref=$2 doc=$3 dd=$4 url=$5 top prefix body code sb hb db im newest nm nf
    [ -d "$doc" ] || { cni "$tok" "docroot $dd does not exist"; return; }
    top=$(g "$doc" rev-parse --show-toplevel 2>/dev/null) || { cni "$tok" "docroot $dd is not inside a git work tree"; return; }
    prefix=$(g "$doc" rev-parse --show-prefix 2>/dev/null) || prefix=""
    body="$WORK/body.$RANDOM"
    code=$(get "$url" "$body")
    if [ "$code" != 200 ]; then cni "$tok" "/ did not answer HTTP 200 (got $code) while a server of ours is on record; not inspected (not a finding)"; return; fi
    sb=$(sha_of "$body")
    if g "$top" ls-files --error-unmatch -- "${prefix}index.html" >/dev/null 2>&1; then
        hb=$(g "$top" show "HEAD:${prefix}index.html" 2>/dev/null | sha256sum | cut -c1-12) || { cni "$tok" "HEAD:${prefix}index.html cannot be read"; return; }
        if [ "$sb" != "$hb" ]; then
            finding high build-freshness "$tok:index" "served / (sha256 $sb) differs from the committed HEAD:${prefix}index.html of $dd (sha256 $hb): the server does not serve the committed source" "$ref"
        fi
        return
    fi
    [ -f "$doc/index.html" ] || { cni "$tok" "built docroot $dd has no index.html"; return; }
    db=$(sha_of "$doc/index.html")
    if [ "$sb" != "$db" ]; then
        finding high build-freshness "$tok:index" "served / (sha256 $sb) is not $dd/index.html (sha256 $db): the server serves other content than the built docroot" "$ref"
    fi
    im=$(stat -c %Y "$doc/index.html" 2>/dev/null) || { cni "$tok" "$dd/index.html mtime cannot be read"; return; }
    newest=$(g "$top" ls-files -z 2>/dev/null | awk -v p="$prefix" 'BEGIN { RS = ORS = "\0" } p == "" || index($0, p) != 1' \
             | (cd "$top" && xargs -0 -r stat -c '%Y %n' 2>/dev/null) | LC_ALL=C sort -n -k1,1 | tail -1)
    [ -n "$newest" ] || { cni "$tok" "no tracked source file of $dd could be read"; return; }
    nm=${newest%% *}; nf=${newest#* }
    if [ "$nm" -gt "$im" ]; then
        finding medium build-freshness "$tok:build-age" "the built $dd/index.html ($(iso "$im")) is older than tracked source $(safe "$nf") ($(iso "$nm")): the served build predates its source (the staleness rule scripts/qa-up.sh rebuilds on)" "$ref"
    fi
}

# ---- live discovery ----------------------------------------------------------------------------
declare -A IT_KIND IT_REF IT_IDS IT_REPO
ITEMS=()
DISC_ERR=""
add_item() { # <token> <kind> <ref> <repo>
    if [ -z "${IT_KIND[$1]:-}" ]; then ITEMS+=("$1"); IT_KIND[$1]=$2; IT_REF[$1]=$3; IT_REPO[$1]=$4; IT_IDS[$1]=""; fi
}
discover_live() {
    local qa="$ROOT/$QA_REL" cf="$ROOT/$COMPOSE_REL" names n proj svcs s ps id p sv cfg rel tok cdir
    [ -f "$qa" ] || { DISC_ERR="$QA_REL is absent: the qa-up service set cannot be derived"; return 2; }
    [ -f "$cf" ] || { DISC_ERR="$COMPOSE_REL is absent: the compose service set cannot be derived"; return 2; }
    names=$(sed -n 's/.*case "\$2" in \([a-z0-9_|-]*\)).*/\1/p' "$qa" | head -1 | tr '|' '\n')
    [ -n "$names" ] || { DISC_ERR="$QA_REL carries no --only service list: the qa-up service set cannot be derived"; return 2; }
    while IFS= read -r n; do [ -n "$n" ] && add_item "service:qa-up/$n" qa "$QA_REL" ""; done <<<"$names"
    proj=$(sed -n 's/^name:[[:space:]]*\([A-Za-z0-9._-]\{1,\}\)[[:space:]]*$/\1/p' "$cf" | head -1)
    [ -n "$proj" ] || proj=$(basename -- "$(dirname -- "$cf")")
    svcs=$(awk '/^services:[[:space:]]*$/ { f = 1; next } f && /^[^[:space:]#]/ { f = 0 } f && /^  [A-Za-z0-9._-]+:[[:space:]]*$/ { sub(/^  /, ""); sub(/:.*/, ""); print }' "$cf")
    [ -n "$svcs" ] || { DISC_ERR="$COMPOSE_REL defines no service: the compose service set cannot be derived"; return 2; }
    while IFS= read -r s; do [ -n "$s" ] && add_item "service:compose/$proj/$s" compose "$COMPOSE_REL" "$(dirname -- "$cf")"; done <<<"$svcs"
    command -v podman >/dev/null 2>&1 || { DISC_ERR="podman is absent: the running set cannot be enumerated"; return 2; }
    ps=$(podman ps --no-trunc --format '{{.ID}}|{{index .Labels "com.docker.compose.project"}}|{{index .Labels "com.docker.compose.service"}}|{{index .Labels "com.docker.compose.project.config_files"}}' 2>/dev/null) \
        || { DISC_ERR="podman ps failed: the running set cannot be enumerated"; return 2; }
    while IFS='|' read -r id p sv cfg; do
        [ -n "$id" ] || continue
        cfg=${cfg%%,*}
        case "$cfg" in "$ROOT"/*) rel=${cfg#"$ROOT"/} ;; *) continue ;; esac
        cdir=$(dirname -- "$cfg")
        g "$cdir" ls-files --error-unmatch -- "$(basename -- "$cfg")" >/dev/null 2>&1 || continue
        tok="service:compose/$(zg_pct_encode "$p")/$(zg_pct_encode "$sv")"
        add_item "$tok" compose "$(zg_pct_encode "$rel")" "$cdir"
        IT_IDS[$tok]=$(printf '%s\n' ${IT_IDS[$tok]} "$id" | LC_ALL=C sort -u | tr '\n' ' ')
    done <<<"$ps"
    return 0
}

# probe_qa <token>: the per-name probe method (the SET comes from scripts/qa-up.sh)
probe_qa() {
    local tok=$1 name=${1#service:qa-up/} repo state exe_expect url pid a0 sd port rootf doc
    case "$name" in
        workshop) repo=workshop;        state=workshop/platform/run/server.json;        exe_expect="" ;;
        ai)       repo=ai_interviewing; state=ai_interviewing/platform/run/server.json; exe_expect=ai_interviewing/platform/bin/aicur ;;
        *)        repo="" ;;
    esac
    if [ -n "$repo" ]; then
        command -v python3 >/dev/null 2>&1 || { cni "$tok" "python3 is absent: the state file and /api/health cannot be parsed"; return; }
        [ -f "$ROOT/$state" ] || { cni "$tok" "not running: no state file $state (a stopped service serves nobody; not a finding)"; return; }
        url=$(jget "$ROOT/$state" http | head -1) || { cni "$tok" "state file $state is not a JSON object"; return; }
        [ -n "$url" ] || { cni "$tok" "state file $state publishes no http address"; return; }
        local exe=""
        if [ -n "$exe_expect" ]; then
            pid=$(jget "$ROOT/$state" pid | head -1)
            [[ $pid =~ ^[0-9]+$ ]] || { cni "$tok" "state file $state records no pid"; return; }
            if ! [ -r "/proc/$pid/cmdline" ]; then cni "$tok" "not running: the pid its state file records is gone (not a finding)"; return; fi
            a0=$( { tr '\0' '\n' <"/proc/$pid/cmdline"; } 2>/dev/null | head -1)
            if [ "$(readlink -m -- "$a0")" != "$(readlink -m -- "$ROOT/$exe_expect")" ]; then
                cni "$tok" "the pid its state file records is not $exe_expect (not ours); not inspected"; return
            fi
            exe="/proc/$pid/exe"
        fi
        probe_stack "$tok" "$QA_REL" "$ROOT/$repo" "$repo" "${url%/}" "$exe"
        return
    fi
    doc=$(sed -n "s/.*start_static $name \"\\\$ROOT\\/\\([^\"]*\\)\".*/\\1/p" "$ROOT/$QA_REL" | head -1)
    if [ -z "$doc" ]; then cni "$tok" "scripts/qa-up.sh boots $name but this class knows no probe method for it"; return; fi
    sd=$(sed -n 's/^STATE_DIR="\${QA_STATE_DIR:-\$ROOT\/\([^}"]*\)}".*/\1/p' "$ROOT/$QA_REL" | head -1)
    [ -n "$sd" ] || { cni "$tok" "the qa-up state directory cannot be derived from $QA_REL"; return; }
    port=$(cat "$ROOT/$sd/$name.port" 2>/dev/null); pid=$(cat "$ROOT/$sd/$name.pid" 2>/dev/null); rootf=$(cat "$ROOT/$sd/$name.root" 2>/dev/null)
    if ! [[ $port =~ ^[0-9]+$ && $pid =~ ^[0-9]+$ ]]; then cni "$tok" "not running: no qa-up pid/port on record in $sd (a stopped server serves nobody; not a finding)"; return; fi
    if ! [ -r "/proc/$pid/cmdline" ]; then cni "$tok" "not running: the recorded qa-up server pid is gone (not a finding)"; return; fi
    a0=$( { tr '\0' ' ' <"/proc/$pid/cmdline"; } 2>/dev/null)
    case "$a0" in *"http.server $port "*"$ROOT/$doc"*) ;; *) cni "$tok" "the recorded pid is not the qa-up http.server for port $port and $doc (not ours); not inspected"; return ;; esac
    [ "$rootf" = "$ROOT/$doc" ] || { cni "$tok" "the recorded docroot is not $doc; not inspected"; return; }
    probe_static "$tok" "$QA_REL" "$ROOT/$doc" "$doc" "http://127.0.0.1:$port/"
}

# ---- corpus mode ---------------------------------------------------------------------------------
SRV=""
cleanup() {
    if [ -n "$SRV" ]; then kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; SRV=""; fi
    [ -n "${WORK:-}" ] && rm -rf -- "$WORK"
}
fixval() { awk -F= -v k="$2" '!/^[[:space:]]*#/ && $1 == k { sub(/^[^=]*=/, ""); print; exit }' "$1"; }
tg() {
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=zg GIT_AUTHOR_EMAIL=zg@invalid \
    GIT_COMMITTER_NAME=zg GIT_COMMITTER_EMAIL=zg@invalid \
        git -C "$WORK/tmpl" -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"
}
T_OLD=1577836800 T_HEAD=1577923200 T_BEFORE=1577880000 T_AFTER=1578009600 T_BUILT=1577966400
PYSRV='import functools, http.server, os, sys
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(H, directory=sys.argv[1]))
with open(sys.argv[2] + ".tmp", "w") as f:
    f.write(str(srv.server_address[1]))
os.rename(sys.argv[2] + ".tmp", sys.argv[2])
srv.serve_forever()'

corpus_main() {
    local tok k=0 f probe OLD HEAD port i sub dir started hs st path mounts
    mapfile -t ITEMS < <(cd "$CORPUS" && find . -type f -print0 | sed -z 's|^\./||' | zg_pct_encode_z | awk 'NF' | LC_ALL=C sort -u)
    if [ "$EMIT" -eq 1 ]; then printf '%s\n' "${ITEMS[@]}" | awk 'NF'; return 0; fi
    if [ "${#ITEMS[@]}" -eq 0 ]; then
        echo "COULD-NOT-INSPECT - empty population: the corpus holds no service fixture (never clean)"
        echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2
    fi
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/zg-lvs.XXXXXX") || { echo "COULD-NOT-INSPECT - cannot create a private temp dir"; echo "INSPECTED 0"; printf 'POPULATION-SHA %s\n' "$(printf '%s\n' "${ITEMS[@]}" | sha256sum | cut -d' ' -f1)"; return 2; }
    trap cleanup EXIT
    mkdir -p "$WORK/www" "$WORK/exe" "$WORK/pod" "$WORK/shim" "$WORK/src" "$WORK/tmpl"
    # scratch source repository: two commits at fixed dates => fixed commit ids
    tg init -q -b main >/dev/null 2>&1 || { echo "COULD-NOT-INSPECT - git cannot create the scratch source repository"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2; }
    printf '<h1>v1</h1>\n' >"$WORK/tmpl/index.html"; printf 'source\n' >"$WORK/tmpl/src.txt"; mkdir -p "$WORK/tmpl/bin"; printf 'x\n' >"$WORK/tmpl/bin/.keep"
    tg add -A >/dev/null 2>&1 && GIT_AUTHOR_DATE="$T_OLD +0000" GIT_COMMITTER_DATE="$T_OLD +0000" tg commit -q -m old >/dev/null 2>&1
    printf '<h1>v2</h1>\n' >"$WORK/tmpl/index.html"
    tg add -A >/dev/null 2>&1 && GIT_AUTHOR_DATE="$T_HEAD +0000" GIT_COMMITTER_DATE="$T_HEAD +0000" tg commit -q -m head >/dev/null 2>&1
    OLD=$(tg rev-parse HEAD~1 2>/dev/null) HEAD=$(tg rev-parse HEAD 2>/dev/null)
    if ! is_hex40 "$OLD" || ! is_hex40 "$HEAD"; then echo "COULD-NOT-INSPECT - the scratch source repository could not be committed"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2; fi
    # PATH shims answering from fixture data (private temp dir only)
    # go shim: refuses unless HOME and XDG_CONFIG_HOME are the class's private scratch dir (`go` keeps a
    # telemetry counter under the real HOME otherwise), then answers `go version -m` from fixture data
    sed "s#@W@#$WORK#g" >"$WORK/shim/go" <<'SHIM'
#!/bin/sh
case "${HOME:-}" in @W@/*) ;; *) echo "go shim: HOME is not the class scratch dir" >&2; exit 1 ;; esac
case "${XDG_CONFIG_HOME:-}" in @W@/*) ;; *) echo "go shim: XDG_CONFIG_HOME is not the class scratch dir" >&2; exit 1 ;; esac
[ "$1" = version ] && [ "$2" = -m ] && [ -f "$3.goinfo" ] && exec cat "$3.goinfo"
exit 1
SHIM
    # podman shim: answers `podman inspect --format <tpl> <id>` from fixture data; a fixture with
    # health_status=nil emulates podman 5.x, where .State.Health is a nil pointer and an UNGUARDED
    # .State.Health.Status template fails (exit 125)
    sed "s#@W@#$WORK#g" >"$WORK/shim/podman" <<'SHIM'
#!/bin/sh
[ "$1" = inspect ] || exit 1
fmt=""; [ "$2" = --format ] && fmt=$3
eval "id=\${$#}"
[ -f "@W@/pod/$id" ] || exit 1
if [ -f "@W@/pod/$id.nilhealth" ]; then
    case $fmt in
        *'{{if .State.Health}}'*) ;;
        *'.State.Health.Status'*) echo "Error: template: inspect: nil pointer evaluating *define.HealthCheckResults.Status" >&2; exit 125 ;;
    esac
fi
exec cat "@W@/pod/$id"
SHIM
    chmod +x "$WORK/shim/go" "$WORK/shim/podman"
    export PATH="$WORK/shim:$PATH"
    local -a PLAN=()
    for tok in "${ITEMS[@]}"; do
        k=$((k + 1)); f="$CORPUS/$(printf '%b' "$(printf '%s' "$tok" | sed 's/%\([0-9A-F][0-9A-F]\)/\\x\1/g')")"
        probe=$(fixval "$f" probe)
        dir="$WORK/src/$k"; cp -a "$WORK/tmpl" "$dir"
        case "$probe" in
            stack)
                sub=$(fixval "$f" health)
                if [ "$sub" != none ] && [ -n "$sub" ]; then
                    mkdir -p "$WORK/www/$k/api"
                    printf '%s\n' "$sub" | sed "s/@HEAD@/$HEAD/g; s/@OLD@/$OLD/g; s/@FOREIGN@/$FOREIGN_REV/g" >"$WORK/www/$k/api/health"
                fi
                i=""
                if [ "$(fixval "$f" exe)" = present ]; then
                    i="$WORK/exe/$k.bin"; printf 'binary\n' >"$i"
                    if [ "$(fixval "$f" exe_age)" = old ]; then touch -d "@$T_BEFORE" "$i"; else touch -d "@$T_AFTER" "$i"; fi
                    sub=$(fixval "$f" stamp_revision)
                    { printf '%s: go1.26.0\n\tpath\texample.invalid/zg\n' "$i"
                      if [ "$sub" != none ] && [ -n "$sub" ]; then
                          printf '\tbuild\tvcs=git\n\tbuild\tvcs.revision=%s\n\tbuild\tvcs.modified=%s\n' \
                              "$(printf '%s' "$sub" | sed "s/@HEAD@/$HEAD/; s/@OLD@/$OLD/; s/@FOREIGN@/$FOREIGN_REV/")" "$(fixval "$f" stamp_modified)"
                      fi; } >"$i.goinfo"
                fi
                PLAN+=("stack|$tok|$dir|$i") ;;
            compose)
                st=$(fixval "$f" status); hs=$(fixval "$f" health_status)
                if [ "$hs" = nil ]; then : >"$WORK/pod/zgc$k.nilhealth"; hs=""; fi
                [ "$hs" = none ] && hs=""
                if [ "$(fixval "$f" started)" = before ]; then started=$T_BEFORE; else started=$T_AFTER; fi
                if [ "$(fixval "$f" exe)" = bind ]; then path=/opt/app/bin/server; mounts="$dir/bin>/opt/app/bin;"
                else path=/usr/local/bin/server; mounts=""; fi
                printf '%s|%s|%s|%s|%s\n' "$st" "$hs" "$started" "$path" "$mounts" >"$WORK/pod/zgc$k"
                PLAN+=("compose|$tok|$dir|zgc$k") ;;
            static)
                mkdir -p "$WORK/www/$k"
                if [ "$(fixval "$f" docroot)" = tracked ]; then
                    if [ "$(fixval "$f" served)" = same ]; then cp "$dir/index.html" "$WORK/www/$k/index.html"; else printf '<h1>other</h1>\n' >"$WORK/www/$k/index.html"; fi
                    PLAN+=("static|$tok|$dir|")
                else
                    mkdir -p "$dir/_site"; printf '<h1>built</h1>\n' >"$dir/_site/index.html"; touch -d "@$T_BUILT" "$dir/_site/index.html"
                    if [ "$(fixval "$f" source_age)" = new ]; then sub=$T_AFTER; else sub=$T_BEFORE; fi
                    (cd "$dir" && git ls-files -z | xargs -0 -r touch -d "@$sub")
                    if [ "$(fixval "$f" served)" = same ]; then cp "$dir/_site/index.html" "$WORK/www/$k/index.html"; else printf '<h1>other</h1>\n' >"$WORK/www/$k/index.html"; fi
                    PLAN+=("static|$tok|$dir/_site|")
                fi ;;
            *) PLAN+=("bad|$tok||") ;;
        esac
    done
    # one loopback HTTP server for the whole corpus, started here and killed by its own pid on exit
    python3 -c "$PYSRV" "$WORK/www" "$WORK/port" </dev/null >/dev/null 2>&1 &
    SRV=$!
    for i in $(seq 1 100); do [ -s "$WORK/port" ] && break; kill -0 "$SRV" 2>/dev/null || break; sleep 0.05; done
    port=$(cat "$WORK/port" 2>/dev/null)
    if ! [[ $port =~ ^[0-9]+$ ]]; then
        echo "COULD-NOT-INSPECT - the corpus HTTP server did not start (python3 unusable)"
        echo "INSPECTED 0"; printf 'POPULATION-SHA %s\n' "$(printf '%s\n' "${ITEMS[@]}" | sha256sum | cut -d' ' -f1)"; return 2
    fi
    local line kind a b c n=0
    for line in "${PLAN[@]}"; do
        IFS='|' read -r kind a b c <<<"$line"
        n=$((n + 1)); k=$(printf '%s' "$b" | sed 's#.*/src/\([0-9]*\).*#\1#')
        case "$kind" in
            stack)   probe_stack "$a" "$a" "$b" fixture-repo "http://127.0.0.1:$port/$k" "$c" ;;
            compose) probe_compose "$a" "$a" "$b" fixture-repo "$c" ;;
            static)  if [ "${b%/_site}" != "$b" ]; then probe_static "$a" "$a" "$b" fixture-repo/_site "http://127.0.0.1:$port/$k/"
                     else probe_static "$a" "$a" "$b" fixture-repo "http://127.0.0.1:$port/$k/"; fi ;;
            *)       cni "$a" "not a service fixture (probe must be stack, compose or static)" ;;
        esac
    done
    report "$n"
}

# report <n inspected>: print findings, could-not-inspect lines, INSPECTED, POPULATION-SHA; return rc
report() {
    [ "${#FOUT[@]}" -gt 0 ] && printf '%s\n' "${FOUT[@]}"
    [ "${#COUT[@]}" -gt 0 ] && printf '%s\n' "${COUT[@]}"
    echo "INSPECTED $1"
    if [ "${#ITEMS[@]}" -gt 0 ]; then printf 'POPULATION-SHA %s\n' "$(printf '%s\n' "${ITEMS[@]}" | LC_ALL=C sort -u | sha256sum | cut -d' ' -f1)"
    else echo "POPULATION-SHA $EMPTY_SHA"; fi
    if [ "${#FOUT[@]}" -gt 0 ]; then return 1; fi
    if [ "${#COUT[@]}" -gt 0 ]; then return 2; fi
    return 0
}

class_main() {
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
        if [ "$EMIT" -eq 1 ]; then echo "live-vs-source: --root is not a directory" >&2; return 2; fi
        echo "COULD-NOT-INSPECT - --root is not a directory"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2
    fi
    ROOT=$(cd -- "$ROOT" && pwd -P)
    if [ -n "$CORPUS" ]; then
        [ -d "$CORPUS" ] || { echo "COULD-NOT-INSPECT - --corpus is not a directory"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2; }
        CORPUS=$(cd -- "$CORPUS" && pwd -P)
        corpus_main; return $?
    fi
    local drc=0 tok n=0
    discover_live || drc=$?
    if [ "$EMIT" -eq 1 ]; then
        [ "$drc" -eq 0 ] || { echo "live-vs-source: $DISC_ERR" >&2; return 2; }
        printf '%s\n' "${ITEMS[@]}" | LC_ALL=C sort -u; return 0
    fi
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/zg-lvs.XXXXXX") || { echo "COULD-NOT-INSPECT - cannot create a private temp dir"; echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"; return 2; }
    trap cleanup EXIT
    if [ "$drc" -ne 0 ]; then cni - "$DISC_ERR"; fi
    if [ "${#ITEMS[@]}" -eq 0 ]; then cni - "empty population: no service could be enumerated (never clean)"; report 0; return $?; fi
    while IFS= read -r tok; do
        n=$((n + 1))
        case "${IT_KIND[$tok]}" in
            qa) probe_qa "$tok" ;;
            compose) probe_compose "$tok" "${IT_REF[$tok]}" "${IT_REPO[$tok]}" "$(g "${IT_REPO[$tok]}" rev-parse --show-toplevel 2>/dev/null | sed "s#^$ROOT/##")" "${IT_IDS[$tok]}" ;;
        esac
    done < <(printf '%s\n' "${ITEMS[@]}" | LC_ALL=C sort -u)
    report "$n"
}

MODE=run ROOT="" CORPUS="" EMIT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure)
            MODE=prove; shift ;;
        *) echo "live-vs-source: unknown argument: $1" >&2; echo "COULD-NOT-INSPECT - unknown argument"; echo "INSPECTED 0"; echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; exit 2 ;;
    esac
done
if [ "$MODE" = prove ]; then prove_failure; exit $?; fi
class_main
