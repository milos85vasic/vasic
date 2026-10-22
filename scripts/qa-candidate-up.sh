#!/usr/bin/env bash
# =============================================================================
# qa-candidate-up.sh — stand up / tear down / reset the ISOLATED manual-QA
# instance of the workshop QA CANDIDATE (see scripts/qa-candidate.sh and
# docs/QA-CANDIDATE.md).
#
# WHAT THE INSTANCE IS
#   The qa-candidate worktree's server + Angular bundle, run as a PLAIN PROCESS
#   (no compose, no podman) on its own loopback port against a COPY of the live
#   registry / corpus / textbooks / research documents. It shares NOTHING
#   writable with the live service: the live stack (compose project
#   workshop-curriculum, :8087, the workshop-index volume, the live checkout's
#   curriculum/passages.jsonl) is only ever READ, to make copies. Answering stays
#   OFF (-answer-provider none), no hosted provider, no API key file, no
#   ApiKey_* variable is passed, nothing billable is called.
#
# SUBCOMMANDS
#   build      build server + tools from the candidate worktree and copy the Angular bundle
#   data       copy the live curriculum / docs / chapters / prebuilt into the QA root (once)
#   research   stage + apply the research-library re-ingest on the COPY (searchable docs)
#   accounts   provision milosvasic, rami (administrators) and student1..student5
#   up         build (if needed), data, research, accounts, start, wait healthy; print URL
#   down       stop the instance (only the process this script started)
#   status     print URL, pid, port, state; rc 0 up and healthy, 1 down, 2 unknown
#   health     probe /api/health and a sign-in for each account class (no value printed)
#   reset      down, wipe the QA data copy (NOT the binaries), then data + research + accounts
#   --prove-failure  paired proof of the refusal paths (no server is started)
#
# ENVIRONMENT (all optional)
#   QA_CANDIDATE_QA_ROOT   instance root     (default ~/.cache/workshop-qa-candidate; on disk, not /tmp)
#   QA_CANDIDATE_WT        candidate worktree (default <umbrella>/../vasic-wt/qa-candidate)
#   QA_CANDIDATE_SRC       live checkout to COPY from, read-only (default <umbrella>/workshop)
#   QA_CANDIDATE_PORT      port (default: first free in 18300..18399; 8087 is REFUSED)
#   QA_CANDIDATE_BIND      address (default 127.0.0.1; 0.0.0.0 exposes the recording of a third
#                          party to the LAN - the script says so before binding)
#   QA_CANDIDATE_CREDS     credentials file, mode 0600 (default ~/.cache/claude-tmp/qa/credentials.env);
#                          generated with random 20-character values when absent; values are never printed
#   QA_CANDIDATE_NG_WRAPPER command prefix for ng build (default 'nice -n 10'; e.g. a load-aware governor)
#   QA_CANDIDATE_SKIP_WEB  1 = 'build' compiles the Go binaries only (use when the Angular bundle was built separately)
#   QA_CANDIDATE_OLLAMA    local embedding endpoint (default http://127.0.0.1:11434; "" = lexical search only)
#
# EXIT  0 ok | 1 failed / refused by a rule | 2 could not determine (a tool or input is missing)
# =============================================================================
set -uo pipefail

SELF="$(readlink -f -- "${BASH_SOURCE[0]}")"
ROOT="$(cd -- "$(dirname -- "$SELF")/.." && pwd -P)"
QA_ROOT="${QA_CANDIDATE_QA_ROOT:-$HOME/.cache/workshop-qa-candidate}"
WT="${QA_CANDIDATE_WT:-$(dirname "$ROOT")/vasic-wt/qa-candidate}"
SRC="${QA_CANDIDATE_SRC:-$ROOT/workshop}"
CREDS="${QA_CANDIDATE_CREDS:-$HOME/.cache/claude-tmp/qa/credentials.env}"
BIND="${QA_CANDIDATE_BIND:-127.0.0.1}"
OLLAMA="${QA_CANDIDATE_OLLAMA-http://127.0.0.1:11434}"
LIVE_PORT=8087
MARK=".qa-candidate-instance"

say()  { printf '>> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die1() { printf 'REFUSED: %s\n' "$*" >&2; exit 1; }
die2() { printf 'UNDETERMINED: %s\n' "$*" >&2; exit 2; }

D="$QA_ROOT/data"; B="$QA_ROOT/bin"; S="$QA_ROOT/state"

# ---------------------------------------------------------------- safety rules
phys() { ( cd -P -- "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"; }
guard_root() {
  case "$QA_ROOT" in /*) ;; *) die1 "QA root must be absolute: $QA_ROOT" ;; esac
  local r; r="$(readlink -m -- "$QA_ROOT")"
  case "$r" in
    /|/usr*|/etc*|/var/lib/workshop*|*/containers/storage*|/var/lib/containers*|/var/lib/docker*) die1 "QA root $r is a system or live-state path" ;;
  esac
  local live; live="$(readlink -m -- "$SRC")"
  case "$r/" in "$live/"*) die1 "QA root $r is inside the live checkout $live" ;; esac
  case "$live/" in "$r/"*) die1 "QA root $r contains the live checkout $live" ;; esac
  [ "$r" != "$(readlink -m -- "$HOME")" ] || die1 "QA root must not be \$HOME"
}
guard_port() {
  case "$1" in ''|*[!0-9]*) die1 "port must be a number: '$1'" ;; esac
  [ "$1" -ge 1024 ] && [ "$1" -le 65535 ] || die1 "port out of range: $1"
  [ "$1" != "$LIVE_PORT" ] || die1 "port $LIVE_PORT is the LIVE workshop service; the QA instance never uses it"
  [ "$1" != "${WORKSHOP_HTTP_PORT:-}" ] || die1 "port $1 equals WORKSHOP_HTTP_PORT (the live stack)"
}
port_free() { ! ss -ltn "sport = :$1" 2>/dev/null | grep -q LISTEN; }
pick_port() {
  local p
  if [ -n "${QA_CANDIDATE_PORT:-}" ]; then guard_port "$QA_CANDIDATE_PORT"; port_free "$QA_CANDIDATE_PORT" || die1 "port $QA_CANDIDATE_PORT is already in use"; printf '%s' "$QA_CANDIDATE_PORT"; return; fi
  for p in $(seq 18300 18399); do port_free "$p" && { guard_port "$p"; printf '%s' "$p"; return; }; done
  die2 "no free port in 18300..18399"
}
pid_is_ours() { # $1 pid ; ours = alive AND /proc exe is our QA binary
  local p="$1" exe
  [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null || return 1
  exe="$(readlink -f "/proc/$p/exe" 2>/dev/null)" || return 1
  [ "$exe" = "$(readlink -f "$B/workshop-server" 2>/dev/null)" ]
}

# --------------------------------------------------------------------- prove
prove_failure() {
  local T pass=0 fail=0 rc out; T="$(mktemp -d "${TMPDIR:-/tmp}/qa-up-prove.XXXXXX")" || die2 mktemp
  ok() { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
  bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
  local E=(env QA_CANDIDATE_QA_ROOT="$T/qa" QA_CANDIDATE_SRC="$T/live" QA_CANDIDATE_WT="$T/wt")
  mkdir -p "$T/live"
  "${E[@]}" QA_CANDIDATE_PORT=8087 bash "$SELF" up >/dev/null 2>&1; rc=$?; [ "$rc" = 1 ] && ok "port 8087 (the live port) refused rc 1" || bad "8087 rc $rc"
  "${E[@]}" QA_CANDIDATE_PORT=abc bash "$SELF" up >/dev/null 2>&1; rc=$?; [ "$rc" = 1 ] && ok "non-numeric port refused rc 1" || bad "port abc rc $rc"
  env QA_CANDIDATE_QA_ROOT="$T/live/inside" QA_CANDIDATE_SRC="$T/live" bash "$SELF" data >/dev/null 2>&1; rc=$?; [ "$rc" = 1 ] && ok "QA root inside the live checkout refused rc 1" || bad "inside-live rc $rc"
  env QA_CANDIDATE_QA_ROOT="/var/lib/workshop/x" QA_CANDIDATE_SRC="$T/live" bash "$SELF" data >/dev/null 2>&1; rc=$?; [ "$rc" = 1 ] && ok "QA root under the live state path refused rc 1" || bad "live-state root rc $rc"
  env QA_CANDIDATE_QA_ROOT="relative/path" QA_CANDIDATE_SRC="$T/live" bash "$SELF" data >/dev/null 2>&1; rc=$?; [ "$rc" = 1 ] && ok "relative QA root refused rc 1" || bad "relative root rc $rc"
  "${E[@]}" bash "$SELF" bogus >/dev/null 2>&1; rc=$?; [ "$rc" = 2 ] && ok "unknown subcommand rc 2" || bad "bogus rc $rc"
  "${E[@]}" bash "$SELF" status >/dev/null 2>&1; rc=$?; [ "$rc" = 1 ] && ok "status of a never-started instance rc 1 (down, not a pass)" || bad "status rc $rc"
  "${E[@]}" bash "$SELF" down >/dev/null 2>&1; rc=$?; [ "$rc" = 0 ] && ok "down of a never-started instance is a no-op rc 0" || bad "down rc $rc"
  "${E[@]}" bash "$SELF" data >/dev/null 2>&1; rc=$?; [ "$rc" != 0 ] && ok "data from an empty source is not a pass (rc $rc)" || bad "data from empty source rc 0"
  # a foreign pid must never be signalled: plant a pid file naming this shell
  mkdir -p "$T/qa/state"; echo "$$" > "$T/qa/state/server.pid"; : > "$T/qa/.qa-candidate-instance"
  "${E[@]}" bash "$SELF" down >/dev/null 2>&1; kill -0 $$ 2>/dev/null && ok "down did not signal a pid that is not our binary" || bad "down signalled a foreign pid"
  # the script body must contain no podman/compose call and no live port literal outside its refusal
  local pm="pod""man" dk="doc""ker"
  if grep -v '^[[:space:]]*#' "$SELF" | grep -Eq "(^|[^[:alnum:]_])($pm|$dk)([^[:alnum:]_]|\$)"; then bad "script calls podman/docker"; else ok "script body never calls podman or docker"; fi
  rm -rf "$T"
  printf 'prove-failure: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}

CMD="${1:-}"
case "$CMD" in
  --prove-failure) prove_failure; exit $? ;;
  -h|--help) sed -n '2,/^set -uo/p' "$SELF" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
  build|data|research|accounts|up|down|status|health|reset) ;;
  *) die2 "unknown subcommand '$CMD' (see --help)" ;;
esac
shift
guard_root

# ------------------------------------------------------------------ operations
need() { command -v "$1" >/dev/null 2>&1 || die2 "required tool not found: $1"; }

do_build() {
  need go; [ -d "$WT/platform/backend" ] || die2 "candidate worktree not found at $WT (run scripts/qa-candidate.sh)"
  mkdir -p "$B" "$S" || die2 "cannot create $B"
  : > "$QA_ROOT/$MARK"
  local sha dirty; sha="$(git -C "$WT" rev-parse HEAD)"; dirty=0; [ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ] && dirty=1
  say "building server + tools from candidate $sha"
  ( cd "$WT/platform/backend" && for c in workshop-server workshop-accounts ingest-transcript workshop-passwd; do
      [ -d "cmd/$c" ] || { warn "cmd/$c absent - skipped"; continue; }
      CGO_ENABLED=0 nice -n 10 go build -trimpath -ldflags "-X main.sourceCommit=$sha -X main.sourceDirty=$dirty" -o "$B/$c" "./cmd/$c" || exit 1
    done ) || die1 "go build failed"
  [ -x "$B/workshop-server" ] || die1 "workshop-server was not produced"
  [ "${QA_CANDIDATE_SKIP_WEB:-0}" != 1 ] || { say "binaries built (QA_CANDIDATE_SKIP_WEB=1: web bundle not touched)"; return 0; }
  local dist="$WT/platform/frontend/dist/workshop-curriculum"
  if [ ! -e "$dist/browser/index.html" ] && [ ! -e "$dist/index.html" ]; then
    need npx; say "ng build (no bundle at $dist yet; this takes minutes)"
    ( cd "$WT/platform/frontend" && ${QA_CANDIDATE_NG_WRAPPER:-nice -n 10} npx ng build ) || die1 "ng build failed"
  fi
  local src="$dist"; [ -e "$dist/browser/index.html" ] && src="$dist/browser"
  [ -e "$src/index.html" ] || die1 "no Angular bundle found under $dist"
  rm -rf "$S/web.new" && mkdir -p "$S/web.new" && cp -a "$src/." "$S/web.new/" && rm -rf "$S/web" && mv "$S/web.new" "$S/web" || die1 "cannot stage web bundle"
  printf '%s\n' "$sha" > "$S/built-from.txt"
  say "built: $B/workshop-server, bundle in $S/web (from candidate $sha)"
}

do_data() {
  [ -d "$SRC/curriculum" ] || die2 "source curriculum not found: $SRC/curriculum (QA_CANDIDATE_SRC)"
  [ -f "$SRC/curriculum/passages.jsonl" ] || die2 "source registry not found: $SRC/curriculum/passages.jsonl"
  mkdir -p "$D" "$S" || die2 "cannot create $D"; : > "$QA_ROOT/$MARK"
  if [ -f "$D/.copied" ]; then say "data copy already present ($D)"; return 0; fi
  say "copying curriculum, docs, prebuilt, chapters (read-only source: $SRC) -> $D"
  for d in curriculum docs prebuilt; do
    [ -d "$SRC/$d" ] || { [ "$d" = prebuilt ] && SRC_PB="$SRC/platform/prebuilt" || die2 "missing $SRC/$d"; }
  done
  rm -rf "$D/curriculum" "$D/docs" "$D/prebuilt" "$D/chapters" "$D/index" "$D/run"
  cp -a "$SRC/curriculum" "$D/curriculum" || die1 "copy curriculum failed"
  cp -a "$SRC/docs" "$D/docs" || die1 "copy docs failed"
  if [ -d "$SRC/platform/prebuilt" ]; then cp -a "$SRC/platform/prebuilt" "$D/prebuilt" || die1 "copy prebuilt failed"; else mkdir -p "$D/prebuilt"; fi
  mkdir -p "$D/chapters" "$D/index" "$D/run"
  if [ -d "$SRC/chapters" ]; then
    ( cd "$SRC/chapters" && find . -type f ! -name '*.tar.gz.part-*' -print0 | cpio -0 -pdm --quiet "$D/chapters" ) || die1 "copy chapters failed"
  fi
  : > "$D/.copied"; say "data copied"
}

do_research() {
  [ -f "$D/.copied" ] || die2 "run 'data' first"
  [ -f "$D/.research-applied" ] && { say "research documents already applied"; return 0; }
  need bwrap; need strace
  local ing="$B/ingest-transcript"; [ -x "$ing" ] || die2 "ingest-transcript not built (run 'build')"
  local out="$S/research-stage"; rm -rf "$out"
  local py="${WORKSHOP_PYTHON:-}"; [ -n "$py" ] || { [ -x "$SRC/pipeline/venv/bin/python" ] && py="$SRC/pipeline/venv/bin/python"; }
  say "staging the research re-ingest on the COPY"
  ( cd "$WT" && INGEST_TRANSCRIPT="$ing" WORKSHOP_PYTHON="$py" bash scripts/ingest-research-docs.sh stage \
      --out "$out" --registry "$D/curriculum/passages.jsonl" --docs-root "$D/docs/research" ) || die1 "research stage failed (see output above; rc != 0 is not a pass)"
  say "applying the staged candidate to the COPY"
  ( cd "$WT" && WORKSHOP_ORCH=1 bash "$out/apply.sh" --no-shared-lock ) || die1 "research apply failed"
  : > "$D/.research-applied"; say "research documents are searchable in the QA copy"
}

ensure_creds() {
  mkdir -p "$(dirname "$CREDS")" || die2 "cannot create $(dirname "$CREDS")"
  if [ -e "$CREDS" ]; then
    [ ! -L "$CREDS" ] || die1 "credentials file is a symlink: refused"
    [ "$(stat -c '%a' "$CREDS")" = 600 ] || die1 "credentials file $CREDS is not mode 0600: refused"
    return 0
  fi
  local old; old="$(umask)"; umask 077
  rnd() { head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20; }
  { printf 'WORKSHOP_ADMIN_PASSWORD_MILOSVASIC=%s\n' "$(rnd)"
    printf 'WORKSHOP_ADMIN_PASSWORD_RAMI=%s\n' "$(rnd)"
    printf 'WORKSHOP_STUDENT_INITIAL_PASSWORD=%s\n' "$(rnd)"; } > "$CREDS"
  umask "$old"; chmod 600 "$CREDS"
  say "generated $CREDS (mode 0600; values are random, 20 characters, never printed)"
}

do_accounts() {
  [ -f "$D/.copied" ] || die2 "run 'data' first"
  ensure_creds
  [ -x "$B/workshop-accounts" ] || die2 "workshop-accounts not built (run 'build')"
  say "provisioning accounts into the QA auth store ($D/index)"
  ( cd "$WT" && WORKSHOP_ACCOUNTS_BIN="$B/workshop-accounts" bash scripts/provision-accounts.sh \
      --index "$D/index" --secrets-file "$CREDS" --create-store ) || die1 "account provisioning refused (nothing is claimed provisioned)"
}

health_url() { printf 'http://%s:%s' "${BIND/0.0.0.0/127.0.0.1}" "$(cat "$S/port" 2>/dev/null)"; }

do_up() {
  [ -z "${QA_CANDIDATE_PORT:-}" ] || guard_port "$QA_CANDIDATE_PORT"
  need curl; need ss
  [ -x "$B/workshop-server" ] && [ -f "$S/web/index.html" ] || do_build
  do_data; do_research; do_accounts
  if [ -f "$S/server.pid" ] && pid_is_ours "$(cat "$S/server.pid")"; then say "already running: $(health_url) (pid $(cat "$S/server.pid"))"; return 0; fi
  rm -rf "$D/web" && cp -a "$S/web" "$D/web" || die1 "cannot stage the web bundle"
  local port; port="$(pick_port)"; guard_port "$port"
  case "$BIND" in 127.*|localhost|::1) ;; *) warn "binding $BIND is NOT loopback: the third-party recording served by this instance becomes reachable from the network" ;; esac
  printf '%s\n' "$port" > "$S/port"
  local args=(-http "$BIND:$port" -port-fallback 0 -state "$D/run/server.json"
    -chapters "$D/chapters" -curriculum "$D/curriculum"
    -knowledge-taxonomy "$D/curriculum/taxonomy.jsonl" -knowledge-reviews "$D/curriculum/publication-reviews.jsonl"
    -knowledge-materials "$D/curriculum/area-materials.jsonl" -knowledge-questions "$D/curriculum/questions"
    -learning-catalog "$D/curriculum/learning" -docs "$D/docs" -web "$D/web" -index "$D/index"
    -registry "$D/curriculum/passages.jsonl" -prebuilt "$D/prebuilt"
    -embed-model nomic-embed-text -embed-doc-prefix 'search_document: ' -embed-query-prefix 'search_query: '
    -embed-max-chars 6000 -embed-max-batch-chars 12000 -embed-carry-forward=true
    -answer-provider none -question-verify none)
  [ -z "$OLLAMA" ] || args+=(-ollama "$OLLAMA")
  say "starting on $BIND:$port (answering OFF, no hosted provider, no API key file)"
  ( cd "$D" && exec setsid env -i PATH="$PATH" HOME="$HOME" TMPDIR="$S" \
      "$B/workshop-server" "${args[@]}" > "$S/server.log" 2>&1 < /dev/null ) &
  local sp=$! ok=0 i
  printf '%s\n' "$sp" > "$S/server.pid"
  for i in $(seq 1 "${QA_CANDIDATE_WAIT:-900}"); do
    curl -fsS -m 3 "$(health_url)/api/health" >/dev/null 2>&1 && { ok=1; break; }
    kill -0 "$sp" 2>/dev/null || { warn "server exited early; last log lines:"; tail -15 "$S/server.log" >&2; exit 1; }
    sleep 2
  done
  [ "$ok" = 1 ] || { warn "not healthy after the wait; log: $S/server.log"; exit 1; }
  local lp; lp="$(ss -ltnp "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
  [ -z "$lp" ] || ! pid_is_ours "$lp" || printf '%s\n' "$lp" > "$S/server.pid"
  say "UP: $(health_url)   (pid $(cat "$S/server.pid"), log $S/server.log)"
  say "credentials file (values never printed): $CREDS"
}

do_down() {
  [ -f "$S/server.pid" ] || { say "not running (no pid file)"; return 0; }
  local p; p="$(cat "$S/server.pid")"
  if pid_is_ours "$p"; then kill -TERM "$p" 2>/dev/null; for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$p" 2>/dev/null || break; sleep 1; done
    kill -0 "$p" 2>/dev/null && { warn "pid $p ignored TERM; sending KILL to that single pid"; kill -KILL "$p" 2>/dev/null; }
    say "stopped pid $p"
  else say "pid $p is not our server (stale file); nothing signalled"; fi
  rm -f "$S/server.pid"
}

do_status() {
  [ -f "$S/server.pid" ] && pid_is_ours "$(cat "$S/server.pid")" || { say "DOWN"; exit 1; }
  if curl -fsS -m 5 "$(health_url)/api/health" >/dev/null 2>&1; then say "UP $(health_url) pid $(cat "$S/server.pid") built-from $(cat "$S/built-from.txt" 2>/dev/null)"; exit 0; fi
  say "process alive but /api/health does not answer"; exit 1
}

do_health() {
  need curl; ( do_status >/dev/null ) || die1 "instance is not up"
  local url bad=0 k u pw code; url="$(health_url)"
  curl -fsS -m 5 "$url/api/health" | head -c 400; echo
  ensure_creds
  for k in MILOSVASIC RAMI; do
    u="$(printf '%s' "$k" | tr 'A-Z' 'a-z')"; pw="$(grep "^WORKSHOP_ADMIN_PASSWORD_$k=" "$CREDS" | cut -d= -f2-)"
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 -H 'Content-Type: application/json' -d "{\"username\":\"$u\",\"password\":\"$pw\"}" "$url/api/auth/login")"
    [ "$code" = 200 ] && say "sign-in $u: 200" || { warn "sign-in $u: HTTP $code"; bad=1; }
  done
  pw="$(grep '^WORKSHOP_STUDENT_INITIAL_PASSWORD=' "$CREDS" | cut -d= -f2-)"
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 -H 'Content-Type: application/json' -d "{\"username\":\"student1\",\"password\":\"$pw\"}" "$url/api/auth/login")"
  [ "$code" = 200 ] && say "sign-in student1 (initial password, must-change flagged): 200" || { warn "sign-in student1: HTTP $code (a student who already changed the password is expected to get 401 here)"; }
  [ "$bad" = 0 ]
}

do_reset() {
  do_down
  [ -f "$QA_ROOT/$MARK" ] || die1 "$QA_ROOT does not carry the $MARK marker; refusing to wipe a directory this script did not create"
  say "wiping the QA data copy (binaries and credentials are kept)"
  rm -rf -- "$D" "$S/research-stage" "$S/web"
  do_data; do_research; do_accounts
  say "reset done; run '$0 up' to start"
}

case "$CMD" in
  build) do_build ;; data) do_data ;; research) do_research ;; accounts) do_accounts ;;
  up) do_up ;; down) do_down ;; status) do_status ;; health) do_health ;; reset) do_reset ;;
esac
