#!/usr/bin/env bash
# zero-gap-evidence.sh — feature 010 evidence ADAPTER (task T013).
#
# Purpose
#   Runs one check through the constitution's execution recorder and seals the
#   result into a TWO-FILE evidence store (data-model.md "EvidenceRecord — TWO
#   files", research.md T001 addendum):
#     <store>/chain.jsonl    verifier-native: exactly the 9 fields
#                            `continuum-integrity` reads, genesis prev_digest "",
#                            each record produced by upstream
#                            chain.ExecRow.ToRecord and linked by chain.Digest;
#     <store>/sidecar.jsonl  the rich record, validated against
#                            specs/010-zero-gap-verified-closure/contracts/
#                            evidence-record.schema.json;
#   bound by chain artifact_path = "sha256:<hex of the exact sidecar line bytes>".
#
# Where things live (operator ruling, review T015 finding 2)
#   store (chain + sidecar) and streams: UNTRACKED under the git-ignored
#   .remember/logs/zero-gap/evidence/ (defaults below). The anchor is the TRACKED
#   docs/zero-gap/anchor.json, written/verified by zero-gap-evidence-chain.sh.
#   Recorded paths carry no machine specifics: cwd under this repository is
#   stored as `<repo>/...` (a cwd outside it stays as it is) and stream_ref is
#   the stream id relative to the streams root.
#
# Usage
#   zero-gap-evidence.sh record [--store DIR] [--streams DIR] --fp-dir DIR
#       [--fp-pathspec P]... --item-id ID --check-id ID
#       --population-kind source|process|wire --verdict-role author|verifier
#       --independence-tier instance|model|capability
#       --evidence-class runtime|artifact|source
#       (--verdict-exit | --verdict-file PATH) [--session ID] -- CMD [ARGS...]
#   zero-gap-evidence.sh --prove-failure
#   zero-gap-evidence.sh --build-bins DIR        (prints the two built paths)
#
# Inputs
#   --store / $ZG_STORE_DIR      default .remember/logs/zero-gap/evidence
#   --streams / $ZG_STREAMS_DIR  default <store>/streams. REFUSED when inside a
#                     git work tree and not ignored: streams live outside VCS.
#   --verdict-exit    the check declares the three-valued EXIT contract: its exit
#                     status 0|1|2 IS its verdict; any other status => outcome 2.
#   --verdict-file F  the check writes its verdict (0|1|2) to F; absent/garbage
#                     => outcome 2. The outcome is the CHECK's own result, never
#                     inferred from a process exit code alone (§11.4.232).
#                     F is DELETED before the run (a stale verdict must not be
#                     read as this run's), so F is refused when it is a tracked
#                     file, a symlink, or exists as anything but a regular file.
#   --session / $ZG_SESSION_ID   author_session_id; refused when empty (the
#                     recorder row does not carry one and it is never invented).
#   $ZG_CRED_LIB      credential scanner (default: the constitution's
#                     scripts/hooks/credential_scan_lib.sh).
#   $ZG_SCAN_MAX_LINE / $ZG_SCAN_TIMEOUT   scan bounds (default 16384 bytes per
#                     line / 30 s). Exceeding either FAILS CLOSED: the whole
#                     stream is replaced by a placeholder, stream_redacted=true
#                     (the upstream scanner took 94.6 s on one 70 KB line).
#   $ZG_CHAIN_BIN     prebuilt zg-chain (else built into a temp dir with go).
#   $ZG_GO            go binary (default `go`).
#
# Outputs / exit codes (three-valued, a finding outranks an undetermined):
#   0 recorded, outcome 0 (holds)
#   1 outcome 1 (violated) — recorded, or 1 even if sealing failed (a finding
#     is never downgraded to "could not determine")
#   2 outcome 2 (could not determine / unstable), OR not recorded: bad usage,
#     scanner unreachable or blind, fingerprint failed, streams inside VCS,
#     shim missing, a credential-shaped command line, a stale .incoming dir
#     that cannot be removed, or a store that fails pre-flight. In every
#     refusal before the run the wrapped command is NOT executed.
#
# Side effects
#   Before the run: removes stale `.incoming.*` dirs left by a KILLED record
#   (they were never sealed and may hold unredacted output) and refuses to run
#   the check at all unless the store passes pre-flight (every adapter
#   invariant, the chain byte rule, the upstream chain walk).
#   The EXCLUSIVE store lock is taken before pre-flight and before the check
#   runs, and held through sealing, so the check never runs without its
#   record being sealable; a lock not obtained within ZG_LOCK_TIMEOUT
#   (default 120s) refuses the run (rc 2, nothing executed, nothing written).
#   Readers (--verify) therefore wait while a check runs, up to their bound.
#   After the run: appends one line to <store>/sidecar.jsonl and one to
#   <store>/chain.jsonl (under an exclusive lock), one strict FR-045 row to
#   <streams>/exec_rows.jsonl (upstream DecodeExecRows reads it; it is what
#   continuum-unionrule reuses), moves the redacted+truncated streams into
#   <streams>/<id>/ and appends the recorder's raw row to
#   <streams>/recorder.jsonl as FORENSIC evidence only (not JSON whenever argv
#   carries a quote/tab/newline, and it names the private incoming path).
#   Streams land in a 0700 `.incoming.<pid>.*` dir first and are renamed into
#   place only after redaction. TERM/INT/HUP interrupt the run: the trap kills
#   the command's process tree and removes the incoming dir at once.
#
# Redaction (two layers, both needed)
#   The recorder redacts in place, but when its scanner cannot be loaded it
#   silently records stream_redacted=false. So this adapter (1) refuses to run
#   unless the (bounded) scanner loads AND a control needle proves it can see
#   (§11.4.273), and (2) re-scans both stored streams itself afterwards and
#   redacts anything the recorder missed (stream_redacted is then true). The
#   scanner's convention is INVERTED: rc 0 means a credential WAS found.
#   Stream digests are the recorder's, taken over the FULL stream BEFORE any
#   redaction or truncation (execution_record.sh computes them first).
#   argv and cwd cannot be redacted without falsifying the record, so BEFORE
#   the run, and with the command NOT executed on a refusal, two independent
#   gates apply:
#   (a) the argv NAME/SHAPE policy (`zg-chain argv-policy`, _tools/zero-gap-
#       chain/argvpolicy.go; ONE process, linear in the argv length). Every
#       argument is first NORMALISED so shell quoting cannot hide a name from
#       the policy: `'` and `"` are removed, `$'…'` ANSI-C bodies and every
#       `\xHH` / `\uHHHH` / `\UHHHHHHHH` / octal `\NNN` escape are decoded
#       wherever they occur, any other `\c` reads `c`, zero-width/format
#       characters are dropped and full-width ASCII is folded to ASCII — so
#       `'--password'`, `"--password"`, `\--password`, `$'--pass\x77ord'`,
#       `-''p` and `－－token` all read as their plain form. Then every
#       argument is judged whole AND word by word (split on whitespace), so a
#       quoted script body (`sh -c 'sshpass -p X …'`) is scanned too; the words
#       of all arguments form one sequence, so a flag's value may be the next
#       word or the next argument. Refused, whatever the value:
#         - a flag word (`-x…`, `--name[=v]`) whose NAME is secret-shaped;
#         - `-p` / `-pVALUE` and `-P` / `-PVALUE` (single dash; the earlier
#           "`-P` passes" exemption is WITHDRAWN as of review T015d);
#         - `-u` / `--user` / `--user=` / `-uVALUE` whose value holds `:`;
#         - a secret-shaped KEY in ANY `key=value` / `key:value` segment of a
#           word, segments being split on `= : , ; & ?` — INCLUDING a flag's
#           value and a URL query string: `DB_PASS=`, `MYSQL_PWD=`, `Cookie:`,
#           `Set-Cookie:`, `X-Api-Key:`, `--build-arg=TOKEN=x`, `--env=DB_PASSWORD=x`,
#           `--header=Cookie:s=x`, `--opt=a:b,token=x`, `--set=db.password=x`,
#           `--dsn=username=u,password=x`, `?access_token=x`, `?token=x`, `?key=x`;
#         - `Authorization:` anywhere; `Bearer <word>`;
#         - URL credentials `scheme://user:pass@host` AND a token-only URL
#           `scheme://TOKEN@host` (userinfo without a password) — the exact
#           user `git@` (`ssh://git@github…`) is the one exemption.
#       A NAME/KEY is secret-shaped when, after the Cyrillic/Greek look-alike
#       letters are folded onto Latin (so `--раssword` reads `password`), it
#       contains secret, password, passwd, passphrase, token, apikey, api-key,
#       api_key, credential, cookie or authoriz; or a segment (split on
#       non-alphanumerics) is `pw`, starts with pass/pwd, or ends in pwd, or
#       ends in pass (storepass, keypass, db-pass) other than bypass/compass/
#       encompass/overpass/underpass/trespass/surpass; or it is `key`/`keys` or
#       a qualified key (access-, secret-, private-, api-, auth-, signing-,
#       encryption-, master-, client-, session-key). A NAME/KEY that mixes
#       Latin with Cyrillic or Greek letters is refused as a look-alike
#       whatever it spells (the mix is judged before the fold, so a whole-
#       script `--файл` or a Latin `--größe` is NOT refused).
#       FALSE POSITIVES, accepted (there is NO opt-out: the sidecar contract is
#       closed, so an opt-out could not be recorded, and an unrecorded bypass is
#       the leak itself): `go test -p 1`, `mkdir -p`, `make -j4 -p`, and every
#       single-dash `-p…` / `-P…` option (`find -path/-print/-prune/-perm`,
#       `gcc -pthread/-pedantic/-pipe`, `go test -parallel`, `grep -P`,
#       `mysql -P 3306`, `scp -P 22`, `rsync -P`, `cp -P`); `--passes`,
#       `--passive`, `--passthrough`; `--max-tokens`, `--tokenizer`;
#       a bare `--key` that is not a secret (`--sort-key` is NOT refused) and
#       any `KEY=value` / `key:value` segment (`--build-arg=KEY=1`);
#       `-u a:b` used for anything but a credential; a legitimate username in
#       a URL (`https://alice@host/…`, since a token-only URL has that shape —
#       drop the userinfo and let the credential helper supply it); a `\xHH`
#       in an UNQUOTED argument that a shell would pass literally (decoded
#       anyway: fail closed). RECIPE for such a check: wrap it in a small
#       script (its argv is then only the script path), or move the option
#       into the environment — e.g. `GOFLAGS=-p=1 go test ./...` instead of
#       `go test -p 1 ./...`, `REDISCLI_AUTH=… redis-cli` instead of `-a`.
#   (b) the upstream scanner over argv + cwd, in bounded views: per argument,
#       every window of three adjacent arguments space-joined, and every
#       adjacent pair as `name=value` (the scanner needs `:` or `=`).
#
# Residual risks (stated, not hidden — review finding 12)
#   * The stdout/stderr DIGESTS are kept even when a stream is redacted. For a
#     SHORT secret output, anyone holding the record can confirm a guess by
#     hashing it. Do not wrap checks that print secrets; pass secrets through
#     the environment and keep them out of output.
#   * UPSTREAM LIMITATION (registered, not fixed here): the upstream scanner
#     (credential_scan_lib.sh) is the ONLY guard on STREAMS, and its keyword
#     coverage is limited — measured to miss `token=`, `pass=`/`pass:`, bare
#     `Bearer x`, URL credentials and passwords shorter than 8 characters.
#     Those printed to stdout/stderr are NOT redacted.
#   * On the COMMAND LINE exactly the shapes in (a) are refused, plus what (b)
#     happens to match. NOT caught, and stored VERBATIM if the check runs:
#     a NAME-LESS value — one with no secret-shaped flag, key, header or URL
#     userinfo around it: `redis-cli -a X` (`-a` is refused by NO rule: it is
#     ls/cp/rsync/grep/git territory and a blanket refusal would make the
#     adapter unusable; recipe REDISCLI_AUTH), `sshpass X` positional, a bare
#     `X`; an obfuscated, encoded or computed secret (base64, `printf %s "$X"
#     | cmd`, `$(cat keyfile)` expanded only at run time, a value read from a
#     file or the environment by the check itself) — the argv holds only what
#     the shell passed, and the policy judges its words; a look-alike the fold
#     table does not know in a name that is NOT mixed-script (e.g. a whole
#     non-Latin word that some tool happens to accept); the `ssh user@host`
#     scp-style form (no scheme, so it is not a URL). STREAMS (stdout/stderr)
#     are guarded ONLY by the upstream scanner's keyword coverage: a secret
#     printed as `token=…`, `pass:…`, a bare `Bearer x`, `https://u:p@h` or a
#     password shorter than 8 characters is NOT redacted there.
#   * UPSTREAM LIMITATION (registered, not fixed here): the constitution
#     recorder (execution_record.sh line 71) forks sed/tr/sed PER ARGUMENT, so
#     a record of 3000 arguments takes ~31 s of which ~28 s is the recorder
#     (this adapter's own gates take ~2.3 s; measured 2026-09-25, printed as a
#     NOTE by every proof run). The daily job MUST run records ONE AT A TIME,
#     or set ZG_LOCK_TIMEOUT above its longest check: the exclusive store lock
#     is held for the whole record, so a PARALLEL sweep gets rc 2 refusals
#     ("store lock was not obtained"), never a corrupted store.
#   * SIGKILL cannot be trapped: until the NEXT record (or --verify) runs, the
#     killed record's `.incoming.<pid>.*` may hold unredacted output on disk
#     (0700). `record` removes it; the chain verifier reports it as rc 2.
#   * Crash between the sidecar write and the chain write leaves ONE unbound
#     sidecar line (I2): verify reports it and every later record refuses.
#     Manual repair after checking that the last sidecar line is unbound:
#       n=$(wc -l < chain.jsonl); head -n "$n" sidecar.jsonl > s.tmp && mv s.tmp sidecar.jsonl
#     (its streams remain under <streams>/ and its exec row in exec_rows.jsonl).
#
# Dependencies
#   bash, git, sha256sum, go (unless $ZG_CHAIN_BIN), scripts/zero-gap-lib.sh,
#   submodules/constitution/scripts/gates/lib/execution_record.sh,
#   submodules/constitution/scripts/hooks/credential_scan_lib.sh, _tools/zero-gap-chain.
#
# Cross-references
#   T013 (tasks.md), data-model.md, contracts/evidence-record.schema.json,
#   scripts/zero-gap-evidence-chain.sh (T014 verifier), §11.4.115(H), §11.4.268.

set -u

ZGE_HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZGE_ROOT=$(CDPATH='' cd -- "$ZGE_HERE/.." && pwd)
ZGE_CONTRACT="$ZGE_ROOT/specs/010-zero-gap-verified-closure/contracts/evidence-record.schema.json"
ZGE_MODULE="$ZGE_ROOT/_tools/zero-gap-chain"
ZGE_RECORDER="$ZGE_ROOT/submodules/constitution/scripts/gates/lib/execution_record.sh"
ZGE_CRED_DEFAULT="$ZGE_ROOT/submodules/constitution/scripts/hooks/credential_scan_lib.sh"

# shellcheck source=scripts/zero-gap-lib.sh
. "$ZGE_ROOT/scripts/zero-gap-lib.sh"

zge_say() { printf 'zero-gap-evidence: %s\n' "$*" >&2; }

# zge_build_bins OUTDIR -> prints "<zg-chain> <continuum-integrity>". rc 2 on failure.
# Offline by construction: GOPROXY=off, GOTOOLCHAIN=local, -mod=readonly. The
# module's `replace` points inside this repository, so nothing is fetched; a
# build that needs the network FAILS here and is reported, never worked around.
zge_build_bins() {
    local out=$1 go=${ZG_GO:-go} log
    if ! command -v "$go" >/dev/null 2>&1; then
        zge_say "missing verifier build: go toolchain '$go' not found"; return 2
    fi
    log=$(mktemp) || return 2
    if ! ( cd "$ZGE_MODULE" && GOPROXY=off GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOMAXPROCS=${GOMAXPROCS:-4} \
            "$go" build -o "$out/zg-chain" . &&
          GOPROXY=off GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOMAXPROCS=${GOMAXPROCS:-4} \
            "$go" build -o "$out/continuum-integrity" github.com/vasic-digital/continuum/cmd/continuum-integrity ) >"$log" 2>&1; then
        zge_say "missing verifier build: go build failed: $(head -3 "$log" | tr '\n' ' ')"
        rm -f "$log"; return 2
    fi
    rm -f "$log"
    printf '%s %s\n' "$out/zg-chain" "$out/continuum-integrity"
}

# Ruled locations (operator ruling, review T015 finding 2): chain + sidecar +
# streams live UNTRACKED under the git-ignored .remember/logs/zero-gap/evidence;
# the ANCHOR is the TRACKED docs/zero-gap/anchor.json (see the chain script).
ZGE_DEFAULT_STORE="$ZGE_ROOT/.remember/logs/zero-gap/evidence"
ZGE_DEFAULT_STREAMS="$ZGE_ROOT/.remember/logs/zero-gap/evidence/streams"

# zge_scan <wrapper-lib> <file> -> 0 credential FOUND (or unscannable: fail
# CLOSED), 1 clean, 2 scanner fault. NOTE the INVERTED convention of
# helix_cred_scan_file (0 = found).
zge_scan() {
    ( . "$1" >/dev/null 2>&1 || exit 2
      command -v helix_cred_scan_file >/dev/null 2>&1 || exit 2
      helix_cred_scan_file "$2" >/dev/null 2>&1
      r=$?; case $r in 0|1) exit "$r" ;; *) exit 2 ;; esac )
}

# zge_make_wrapper <real-lib> <out> — a bounded scanner (review finding 7).
# The upstream scanner took 94.6 s on ONE 70 KB line (0.14 s on the same bytes
# split into lines). Lines are NEVER re-wrapped before scanning (a credential
# split at the wrap point would be missed); instead a line longer than
# $ZG_SCAN_MAX_LINE (default 16384 bytes) or a scan that outlives
# $ZG_SCAN_TIMEOUT (default 30 s) FAILS CLOSED: it reports "found", so the
# recorder and this adapter replace the WHOLE stream with the placeholder and
# stream_redacted=true. The same wrapper is handed to the recorder. It leaves a
# `<file>.zg-reason` marker saying WHY it failed closed, so the placeholder the
# adapter stores names the real cause (size cap / time bound) instead of
# claiming a credential was detected (review T015b M3).
zge_make_wrapper() {
    local real=$1 out=$2 cap=${ZG_SCAN_MAX_LINE:-16384} to=${ZG_SCAN_TIMEOUT:-30}
    case $cap in ''|*[!0-9]*) zge_say "ZG_SCAN_MAX_LINE '$cap' is not an integer"; return 2 ;; esac
    printf '%s' "$to" | grep -Eq '^[0-9]+(\.[0-9]+)?$' || { zge_say "ZG_SCAN_TIMEOUT '$to' is not a number"; return 2; }
    command -v timeout >/dev/null 2>&1 || { zge_say "coreutils timeout is absent: the scan cannot be bounded"; return 2; }
    {
        printf '_zg_real_lib=%q\n_zg_cap=%s\n_zg_to=%s\n' "$real" "$cap" "$to"
        cat <<'WRAP'
helix_cred_scan_file() {
    local _m _r
    [ -r "$1" ] || return 2
    _m=$(LC_ALL=C awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$1" 2>/dev/null) || return 0
    case $_m in ''|*[!0-9]*) return 0 ;; esac
    if [ "$_m" -gt "$_zg_cap" ]; then
        printf 'line-over-size-cap %s %s\n' "$_m" "$_zg_cap" > "$1.zg-reason" 2>/dev/null
        return 0
    fi
    timeout "$_zg_to" bash -c '. "$1" >/dev/null 2>&1 || exit 2; helix_cred_scan_file "$2"' _ "$_zg_real_lib" "$1"
    _r=$?
    case $_r in
        0|1) return "$_r" ;;
        124|137) printf 'scan-time-bound %s\n' "$_zg_to" > "$1.zg-reason" 2>/dev/null; return 0 ;;
        *) return 2 ;;
    esac
}
WRAP
    } > "$out"
}

# zge_scanner_ready <wrapper-lib> — proves with control needles that the
# scanner can see (§11.4.273): a known credential shape MUST be found, clean
# text MUST NOT. The needle is assembled at run time so this file carries none.
zge_scanner_ready() {
    local lib=$1 t r
    t=$(mktemp -d) || return 2
    printf 'api%s=%s%s\n' '_key' 'AKIA' 'Q7X2M4B8N1V5C3Z9' > "$t/pos"
    printf 'nothing secret here\n' > "$t/neg"
    zge_scan "$lib" "$t/pos"; r=$?
    if [ "$r" -ne 0 ]; then rm -rf "$t"; zge_say "credential scanner cannot see: positive control not found (rc=$r)"; return 2; fi
    zge_scan "$lib" "$t/neg"; r=$?
    rm -rf "$t"
    if [ "$r" -ne 1 ]; then zge_say "credential scanner blind or broken: negative control rc=$r (expected 1 clean)"; return 2; fi
    return 0
}

# zge_streams_outside_vcs <dir> — rc 0 when <dir> is outside every git work
# tree, or inside one but ignored. Checked BEFORE anything is created there.
zge_streams_outside_vcs() {
    local abs=$1 anc tail="" top real rel
    case $abs in /*) ;; *) abs="$PWD/$abs" ;; esac
    anc=$abs
    while [ ! -d "$anc" ]; do tail="/${anc##*/}$tail"; anc=$(dirname -- "$anc"); done
    [ "$(git -C "$anc" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] || return 0
    top=$(git -C "$anc" rev-parse --show-toplevel 2>/dev/null) || return 1
    real=$(CDPATH='' cd -- "$anc" && pwd -P) || return 1
    top=$(CDPATH='' cd -- "$top" && pwd -P) || return 1
    rel=${real#"$top"}$tail
    rel=${rel#/}
    git -C "$top" check-ignore -q --no-index -- "${rel:+$rel/}.zg-streams-probe" 2>/dev/null
}

# Process start time (Linux /proc field 22), used with the pid to recognise a
# REUSED pid; empty where /proc is unavailable (then the pid alone decides).
zge_starttime() { [ -r "/proc/$1/stat" ] && sed 's/.*) //' "/proc/$1/stat" | cut -d' ' -f20; }

# zge_incoming_live <dir> — rc 0 when a process that owns this private
# .incoming.<pid>.* directory is still running (so it must not be touched):
# the adapter itself or the wrapped command's subshell, each recorded in
# `owner` as "<pid> <start time>" (a matching start time guards against a
# reused pid). Without an owner file the pid in the directory name decides.
zge_incoming_live() {
    local d=$1 name pid st now
    if [ -r "$d/owner" ]; then
        while read -r pid st; do
            case $pid in ''|*[!0-9]*) continue ;; esac
            [ "$pid" -gt 1 ] || continue
            ps -p "$pid" >/dev/null 2>&1 || continue
            now=$(zge_starttime "$pid")
            if [ -z "$st" ] || [ -z "$now" ] || [ "$st" = "$now" ]; then return 0; fi
        done < "$d/owner"
        return 1
    fi
    name=${d##*/}; pid=${name#.incoming.}; pid=${pid%%.*}
    case $pid in ''|*[!0-9]*) return 1 ;; esac
    [ "$pid" -gt 1 ] && ps -p "$pid" >/dev/null 2>&1
}

# zge_incoming_sweep <streams> clean|report — a record killed by an
# untrappable signal leaves its private .incoming dir behind, possibly holding
# UNREDACTED output (review finding 3). `clean` removes every stale one (they
# were never sealed; nothing in them is evidence) and reports it; `report`
# (the read-only verifier) only names them. rc 2 while any stale one remains.
zge_incoming_sweep() {
    local streams=$1 mode=$2 d stale=0
    [ -d "$streams" ] || return 0
    for d in "$streams"/.incoming.*; do
        [ -d "$d" ] || continue
        zge_incoming_live "$d" && continue
        if [ "$mode" = clean ]; then
            rm -rf -- "$d"
            if [ -e "$d" ]; then
                zge_say "stale incoming ${d##*/} could NOT be removed (it may hold unredacted output)"; stale=1
            else
                zge_say "removed stale incoming ${d##*/}: its owner is gone; it was never sealed and may have held unredacted output"
            fi
        else
            echo "STALE incoming ${d##*/} under $streams: an interrupted record left it (may hold unredacted output); the next record removes it"
            stale=1
        fi
    done
    [ "$stale" -eq 0 ] || return 2
}

# zge_kill_tree <pid> — the wrapped command's process tree, children first.
# Never a process group, never pid <= 1, never this shell (§11.4.263).
zge_kill_tree() {
    local p=$1 c
    case $p in ''|*[!0-9]*) return 0 ;; esac
    [ "$p" -gt 1 ] && [ "$p" -ne $$ ] || return 0
    for c in $(ps -o pid= --ppid "$p" 2>/dev/null); do zge_kill_tree "$c"; done
    kill -KILL "$p" 2>/dev/null
}

ZGE_INC="" ZGE_CHILD="" ZGE_WRAP="" ZGE_BINDIR="" ZGE_LOCKFD=""
zge_cleanup() {
    if [ -n "$ZGE_LOCKFD" ]; then exec {ZGE_LOCKFD}<&-; ZGE_LOCKFD=""; unset ZG_LOCK_FD ZG_LOCK_MODE; fi
    [ -z "$ZGE_CHILD" ] || zge_kill_tree "$ZGE_CHILD"
    [ -z "$ZGE_INC" ] || rm -rf -- "$ZGE_INC"
    [ -z "$ZGE_WRAP" ] || rm -f -- "$ZGE_WRAP"
    [ -z "$ZGE_BINDIR" ] || rm -rf -- "$ZGE_BINDIR"
    ZGE_INC="" ZGE_CHILD="" ZGE_WRAP="" ZGE_BINDIR=""
}

zge_record() {
    local store="${ZG_STORE_DIR:-$ZGE_DEFAULT_STORE}" streams="${ZG_STREAMS_DIR:-}"
    local fpdir="" item="" check="" pop="" role="" tier="" class="" session="${ZG_SESSION_ID:-}"
    local vmode="" vfile="" lib="${ZG_CRED_LIB:-$ZGE_CRED_DEFAULT}"
    local ps=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --store) store=${2:-}; shift 2 ;;
            --streams) streams=${2:-}; shift 2 ;;
            --fp-dir) fpdir=${2:-}; shift 2 ;;
            --fp-pathspec) ps+=("${2:-}"); shift 2 ;;
            --item-id) item=${2:-}; shift 2 ;;
            --check-id) check=${2:-}; shift 2 ;;
            --population-kind) pop=${2:-}; shift 2 ;;
            --verdict-role) role=${2:-}; shift 2 ;;
            --independence-tier) tier=${2:-}; shift 2 ;;
            --evidence-class) class=${2:-}; shift 2 ;;
            --session) session=${2:-}; shift 2 ;;
            --verdict-exit) vmode=exit; shift ;;
            --verdict-file) vmode=file; vfile=${2:-}; shift 2 ;;
            --) shift; break ;;
            *) zge_say "record: unknown argument '$1'"; return 2 ;;
        esac
    done
    [ "$#" -gt 0 ] || { zge_say "record: no command after --"; return 2; }
    [ -n "$streams" ] || streams="$store/streams"
    [ -n "$vmode" ] || { zge_say "record: no verdict source declared (--verdict-exit or --verdict-file); the outcome is never inferred from an exit code the check did not declare"; return 2; }
    [ "$vmode" != file ] || [ -n "$vfile" ] || { zge_say "record: --verdict-file needs a path"; return 2; }
    [ -n "$session" ] || { zge_say "record: author session id is empty (--session or ZG_SESSION_ID); it is never invented"; return 2; }
    local v r
    for v in store fpdir item check pop role tier class; do
        [ -n "${!v}" ] || { zge_say "record: --${v} is required"; return 2; }
    done
    case $tier in instance|model|capability) ;; *) zge_say "record: independence_tier '$tier' is not instance|model|capability"; return 2 ;; esac
    case $class in runtime|artifact|source) ;; *) zge_say "record: evidence_class '$class' is not runtime|artifact|source"; return 2 ;; esac
    case $pop in source|process|wire) ;; *) zge_say "record: population_kind '$pop' is not source|process|wire"; return 2 ;; esac
    case $role in author|verifier) ;; *) zge_say "record: verdict_role '$role' is not author|verifier"; return 2 ;; esac
    # --verdict-file is deleted before the run (a stale verdict must not be
    # read as this run's), so it may never name a tracked file or a non-file.
    if [ "$vmode" = file ]; then
        if [ -L "$vfile" ] || { [ -e "$vfile" ] && [ ! -f "$vfile" ]; }; then
            zge_say "record: --verdict-file '$vfile' exists and is not a regular file; refused"; return 2
        fi
        r=$(dirname -- "$vfile")
        if [ -d "$r" ] && git -C "$r" ls-files --error-unmatch -- "${vfile##*/}" >/dev/null 2>&1; then
            zge_say "record: --verdict-file '$vfile' is a TRACKED file; it would be deleted — refused"; return 2
        fi
    fi
    zge_streams_outside_vcs "$streams" || { zge_say "record: streams directory '$streams' is inside version control and not ignored; streams must live outside VCS"; return 2; }
    [ -r "$ZGE_RECORDER" ] || { zge_say "record: constitution recorder unreachable: $ZGE_RECORDER"; return 2; }
    [ -r "$lib" ] || { zge_say "record: credential scanner unreachable: $lib"; return 2; }

    trap 'zge_cleanup' EXIT
    trap 'zge_cleanup; exit 143' TERM
    trap 'zge_cleanup; exit 130' INT
    trap 'zge_cleanup; exit 129' HUP
    ZGE_WRAP=$(umask 077; mktemp) || return 2
    zge_make_wrapper "$lib" "$ZGE_WRAP" || return 2
    zge_scanner_ready "$ZGE_WRAP" || return 2

    local chainbin="${ZG_CHAIN_BIN:-}"
    if [ -z "$chainbin" ]; then
        ZGE_BINDIR=$(mktemp -d) || return 2
        chainbin=$(zge_build_bins "$ZGE_BINDIR") || return 2
        chainbin=${chainbin%% *}
    fi
    [ -x "$chainbin" ] || { zge_say "record: missing shim build: $chainbin"; return 2; }

    # argv and cwd are recorded VERBATIM (the record must describe what ran),
    # so they cannot be redacted without falsifying it: a credential-shaped
    # command line is refused BEFORE the command runs (§11.4.10), by two
    # independent gates.
    # (a) The argv NAME/SHAPE policy (zg-chain argv-policy, ONE process, linear
    #     in the argv length): every argument whole AND word by word — see the
    #     header for the exact shapes. It prints the rule, never the value.
    local why prc
    why=$("$chainbin" argv-policy -- "$@"); prc=$?
    case $prc in
        0) ;;
        1) zge_say "record: the command line carries a credential-shaped argument (argv secret policy: $why); it would be stored verbatim — refused, NOT run, nothing recorded"; return 2 ;;
        *) zge_say "record: the argv secret policy could not judge the command line (rc $prc); refused, NOT run"; return 2 ;;
    esac
    # (b) The upstream scanner over argv + cwd, in bounded views (review
    #     finding 4): one argument per line; every window of three adjacent
    #     arguments space-joined (never the whole argv on one line, which a long
    #     argv would push over the scan cap); every adjacent pair as
    #     `name=value` with the flag's leading dashes removed — the scanner
    #     needs `:` or `=`, so `--password hunter2hunter2` is only caught there.
    local argf prev k a av=("$@") n=$#
    argf=$(umask 077; mktemp) || return 2
    {
        printf '%s\n' "$PWD" "$@"
        for ((k = 0; k < n; k++)); do
            printf '%s\n' "${av[*]:k:3}"
        done
        prev=""
        for a in "$@"; do
            if [ -n "$prev" ]; then
                k=$prev
                while [ "${k#-}" != "$k" ]; do k=${k#-}; done
                printf '%s=%s\n' "$k" "$a"
            fi
            prev=$a
        done
    } > "$argf"
    zge_scan "$ZGE_WRAP" "$argf"; r=$?
    rm -f "$argf" "$argf.zg-reason"
    case $r in
        0) zge_say "record: the command line or cwd carries a credential-shaped value (or an argument too long to scan within bounds); it would be stored verbatim — refused, NOT run, nothing recorded"; return 2 ;;
        1) ;;
        *) zge_say "record: the command line could not be scanned for credentials; refused, NOT run"; return 2 ;;
    esac

    # The store lock is taken HERE, before pre-flight and before the check
    # runs, and held through sealing (review T015c I2): an append can then
    # never time out AFTER the check ran, leaving a check that ran with no
    # record. The descriptor is this shell's own ({ZGE_LOCKFD}); zg-chain
    # lock-fd flocks it and exits, the lock staying with this shell (released
    # when it exits or is killed). zg-chain children re-assert it through
    # ZG_LOCK_FD/ZG_LOCK_MODE; the wrapped command does NOT inherit it.
    # A lock not obtained within ZG_LOCK_TIMEOUT (default 120s) refuses the
    # RUN: rc 2, the check is not executed, nothing is written.
    ( umask 077; mkdir -p -- "$store" ) || { zge_say "record: cannot create the store '$store'"; return 2; }
    exec {ZGE_LOCKFD}<"$store" || { zge_say "record: cannot open the store '$store' to lock it; refused, NOT run"; return 2; }
    if ! "$chainbin" lock-fd --store "$store" --fd "$ZGE_LOCKFD" --exclusive --timeout "${ZG_LOCK_TIMEOUT:-120s}"; then
        zge_say "record: the store lock was not obtained within ${ZG_LOCK_TIMEOUT:-120s} (another append or a reader holds '$store'); refused, NOT run, NOT SEALED, nothing recorded"
        return 2
    fi
    export ZG_LOCK_FD=$ZGE_LOCKFD ZG_LOCK_MODE=exclusive

    # Pre-flight (review findings 3 and 11): scrub what an untrappable kill
    # left behind, and never run the check against a store that cannot take
    # its record.
    zge_incoming_sweep "$streams" clean || { zge_say "record: stale incoming directories remain; refused, NOT run"; return 2; }
    "$chainbin" preflight --store "$store" --schema "$ZGE_CONTRACT" >&2 \
        || { zge_say "record: pre-flight refused the store '$store'; the check is NOT run"; return 2; }

    local fpb fpa sroot rawrec sdir final verdict outcome cmd_rc f override=0 rc cwd_rec proot pcwd
    fpb=$(zg_fingerprint "$fpdir" ${ps[@]+"${ps[@]}"}) || { zge_say "record: pre-run state fingerprint failed; nothing recorded"; return 2; }
    fpb=${fpb%% *}
    ( umask 077; mkdir -p "$streams" ) || { zge_say "record: cannot create streams dir '$streams'"; return 2; }
    ZGE_INC=$(umask 077; mktemp -d "$streams/.incoming.$$.XXXXXX") || { zge_say "record: cannot create a private incoming dir"; return 2; }
    printf '%s %s\n' "$$" "$(zge_starttime $$)" > "$ZGE_INC/owner"
    rawrec="$ZGE_INC/recorder.jsonl"; sroot="$ZGE_INC/s"
    [ "$vmode" != file ] || rm -f -- "$vfile"   # a stale verdict file must not be read as this run's
    # In the background + `wait`, so a TERM/INT/HUP interrupts the wait and the
    # trap scrubs the unredacted streams at once. stdin is passed through
    # explicitly (an async command would otherwise read /dev/null).
    (
        umask 077
        # shellcheck source=/dev/null
        . "$ZGE_RECORDER"
        exec {ZGE_LOCKFD}<&-
        unset ZG_LOCK_FD ZG_LOCK_MODE
        XR_CRED_LIB=$ZGE_WRAP exec_record_run "$rawrec" "$sroot" -- "$@" >/dev/null
    ) <&0 &
    ZGE_CHILD=$!
    # The wrapped command's subshell is an owner too: if THIS adapter is
    # SIGKILLed while the command still runs, the dir is live, not stale (M1).
    printf '%s %s\n' "$ZGE_CHILD" "$(zge_starttime "$ZGE_CHILD")" >> "$ZGE_INC/owner"
    wait "$ZGE_CHILD"
    cmd_rc=$?
    ZGE_CHILD=""
    fpa=$(zg_fingerprint "$fpdir" ${ps[@]+"${ps[@]}"}) || { zge_say "record: post-run state fingerprint failed; nothing recorded"; return 2; }
    fpa=${fpa%% *}

    if [ "$vmode" = exit ]; then
        case $cmd_rc in 0|1|2) verdict=$cmd_rc ;; *) verdict=2; zge_say "record: exit $cmd_rc is not a three-valued verdict; the check's outcome is 2" ;; esac
    else
        r=$(tr -d ' \t\r\n' < "$vfile" 2>/dev/null) || r=""
        case $r in 0|1|2) verdict=$r ;; *) verdict=2; zge_say "record: verdict file '$vfile' absent or not 0|1|2 ('$r'); the check's outcome is 2" ;; esac
    fi
    outcome=$verdict
    [ "$fpb" = "$fpa" ] || { outcome=2; zge_say "record: UNSTABLE — the fingerprinted population changed during the run; outcome 2"; }

    # The private recorder file holds exactly ONE row, which may span several
    # physical lines: the recorder writes `command` as "$*" unescaped, so an
    # argument carrying a newline splits it. zg-chain parses the whole file.
    if [ ! -s "$rawrec" ]; then
        zge_say "record: the recorder wrote no row; nothing recorded"
        zg_combine "$outcome" 2; return $?
    fi
    sdir=$(find "$sroot" -mindepth 1 -maxdepth 1 -type d | head -2)
    if [ -z "$sdir" ] || [ "$(printf '%s\n' "$sdir" | wc -l | tr -d ' ')" != 1 ]; then
        zge_say "record: the recorder did not leave exactly one stream directory"
        zg_combine "$outcome" 2; return $?
    fi
    # Second redaction layer: whatever the recorder missed is redacted here.
    for f in stdout stderr; do
        if [ -e "$sdir/$f.zg-reason" ]; then
            r=0   # the recorder's scan already failed closed on this stream
        else
            zge_scan "$ZGE_WRAP" "$sdir/$f"; r=$?
        fi
        case $r in
            0) local why_r=""
               [ -r "$sdir/$f.zg-reason" ] && read -r why_r _ < "$sdir/$f.zg-reason"
               case $why_r in
                   line-over-size-cap) printf '[REPLACED by zero-gap-evidence.sh — the stream holds a line over the scan size cap (ZG_SCAN_MAX_LINE), which cannot be scanned for credentials in bounded time, so the WHOLE stream was withheld. Nothing was detected; nothing was scanned. The digest on the record is of the ORIGINAL stream]\n' > "$sdir/$f" ;;
                   scan-time-bound)    printf '[REPLACED by zero-gap-evidence.sh — the credential scan of this stream exceeded its time bound (ZG_SCAN_TIMEOUT), so the WHOLE stream was withheld. Nothing was detected; the scan did not finish. The digest on the record is of the ORIGINAL stream]\n' > "$sdir/$f" ;;
                   *)                  printf '[REDACTED by zero-gap-evidence.sh — a credential-shaped value was found in this stream; the digest on the record is of the ORIGINAL stream]\n' > "$sdir/$f" ;;
               esac
               rm -f "$sdir/$f.zg-reason"
               override=1 ;;
            1) ;;
            *) zge_say "record: re-scan of the stored $f failed; the stream is not provably redacted — nothing recorded"
               zg_combine "$outcome" 2; return $? ;;
        esac
    done
    final="$streams/${sdir##*/}"
    if [ -e "$final" ]; then
        zge_say "record: stream id collision at '$final'; refusing to overwrite preserved evidence"
        zg_combine "$outcome" 2; return $?
    fi
    mv -- "$sdir" "$final" || { zg_combine "$outcome" 2; return $?; }
    # Raw recorder row: FORENSIC evidence only (it is not JSON for quoted
    # argv and names the private incoming path). The strict, reusable row is
    # exec_rows.jsonl, written by zg-chain (review finding 5).
    ( umask 077; cat -- "$rawrec" >> "$streams/recorder.jsonl" )

    # Paths recorded without machine specifics (review finding 6): cwd under
    # this repository as <repo>/..., stream_ref as the stream id relative to
    # the streams root. A cwd outside the repository stays as it is.
    cwd_rec=$PWD
    proot=$(CDPATH='' cd -- "$ZGE_ROOT" && pwd -P); pcwd=$(pwd -P)
    case "$PWD" in
        "$ZGE_ROOT") cwd_rec='<repo>' ;;
        "$ZGE_ROOT"/*) cwd_rec="<repo>${PWD#"$ZGE_ROOT"}" ;;
        *) case "$pcwd" in
               "$proot") cwd_rec='<repo>' ;;
               "$proot"/*) cwd_rec="<repo>${pcwd#"$proot"}" ;;
           esac ;;
    esac

    local extra=()
    [ "$override" -eq 0 ] || extra+=(--redacted-override)
    "$chainbin" append --store "$store" --schema "$ZGE_CONTRACT" --session "$session" --cwd "$cwd_rec" \
        --raw-row "$rawrec" --stream-ref "${final##*/}" --exec-rows "$streams/exec_rows.jsonl" \
        --item-id "$item" --check-id "$check" \
        --population-kind "$pop" --verdict-role "$role" --independence-tier "$tier" \
        --evidence-class "$class" --fp-before "$fpb" --fp-after "$fpa" --check-verdict "$verdict" \
        ${extra[@]+"${extra[@]}"} -- "$@"
    rc=$?
    zge_cleanup
    if [ "$rc" -ne 0 ]; then
        zge_say "record: NOT SEALED (the streams are kept at $final)"
        zg_combine "$outcome" 2; return $?
    fi
    return "$outcome"
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired proof. Every case runs the REAL adapter against throwaway stores,
# streams and a throwaway git work tree; nothing shipped is modified.
# ─────────────────────────────────────────────────────────────────────────────
zge_prove_failure() (
    set -u
    pass=0 fail=0
    ok()  { pass=$((pass+1)); printf '  PASS %s\n' "$1"; }
    bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
    T=$(mktemp -d) || exit 2
    trap 'rm -rf "$T" "$T.live0" "$T.live1"' EXIT
    LIVE=(scripts/zero-gap-evidence.sh scripts/zero-gap-evidence-chain.sh scripts/zero-gap-lib.sh
          _tools/zero-gap-chain specs/010-zero-gap-verified-closure/contracts)
    zg_manifest "$ZGE_ROOT" "${LIVE[@]}" > "$T.live0" 2>/dev/null \
        || { echo "  UNDETERMINED: cannot fingerprint the live inputs"; exit 2; }
    mkdir -p "$T/bin"
    bins=$(zge_build_bins "$T/bin") || { echo "  UNDETERMINED: the shim/verifier cannot be built"; exit 2; }
    export ZG_CHAIN_BIN=${bins%% *}
    INTEG=${bins##* }
    command -v jq >/dev/null 2>&1 || { echo "  UNDETERMINED: jq absent (the proof reads records with it)"; exit 2; }
    W="$T/work"; mkdir -p "$W"
    git -C "$W" init -q && printf 'x\n' > "$W/f" && git -C "$W" add f &&
        git -C "$W" -c user.email=t@example.invalid -c user.name=t commit -qm init \
        || { echo "  UNDETERMINED: cannot build the scratch work tree"; exit 2; }
    S="$T/store"; ST="$T/streams"
    export ZG_SESSION_ID=proof-session
    rec_in() { # store extra-args... -- cmd...
        local st=$1; shift
        bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$st" --streams "$ST" --fp-dir "$W" \
            --item-id ATM-001 --check-id proof --population-kind source --verdict-role author \
            --independence-tier instance --evidence-class runtime "$@"
    }
    rec() { rec_in "$S" "$@"; }
    NEEDLE_TAIL=Q7X2M4B8N1V5C3Z9
    desc() { local c; for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do desc "$c"; echo "$c"; done; }
    kill_pids() { local p; for p in "$@"; do [ "$p" -gt 1 ] 2>/dev/null && [ "$p" -ne $$ ] && kill -9 "$p" 2>/dev/null; done; }
    lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
    last() { tail -n 1 "$S/sidecar.jsonl"; }
    field() { last | jq -r "$1"; }

    # E1 — a holding check: outcome 0, verifier-native chain, command == argv[0]
    rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 0 ] && [ "$(field .outcome)" = 0 ] && [ "$(field .state_fingerprint_before)" = "$(field .state_fingerprint_after)" ] &&
       [ "$(tail -n 1 "$S/chain.jsonl" | jq -r .command)" = /bin/sh ] &&
       [ "$(tail -n 1 "$S/chain.jsonl" | jq -r '.prev_digest')" = "" ] &&
       [ "$(tail -n 1 "$S/chain.jsonl" | jq -r 'keys|length')" = 9 ]; then
        ok "E1 holding check sealed: outcome 0, genesis prev \"\", 9 chain fields, command == argv[0]"
    else bad "E1 holding check (rc=$rc): $(tail -3 "$T/o" | tr '\n' ' ')"; fi

    # E2 — a violated check
    rec --verdict-exit -- /bin/sh -c 'exit 1' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 1 ] && [ "$(field .outcome)" = 1 ] && ok "E2 violated check: rc 1, outcome 1" \
        || bad "E2 violated check (rc=$rc outcome=$(field .outcome))"

    # E3 — exit 7 is not a three-valued verdict
    rec --verdict-exit -- /bin/sh -c 'exit 7' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(field .outcome)" = 2 ] && [ "$(field .exit_status)" = 7 ] \
        && ok "E3 exit 7 under --verdict-exit: outcome 2, exit_status 7 kept" \
        || bad "E3 exit 7 (rc=$rc outcome=$(field .outcome) exit=$(field .exit_status))"

    # E4 — the population moves during the run: outcome 2 even though the check said 0
    rec --verdict-exit -- /bin/sh -c 'echo more >> "$1"; exit 0' x "$W/f" >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(field .outcome)" = 2 ] && [ "$(field .state_fingerprint_before)" != "$(field .state_fingerprint_after)" ] \
        && ok "E4 fingerprint drift: outcome 2 though the check exited 0" \
        || bad "E4 fingerprint drift (rc=$rc outcome=$(field .outcome))"
    git -C "$W" checkout -q -- f

    # E5 — digest over the FULL stream before truncation. Multi-line on purpose:
    # the constitution's credential scanner takes ~95 s on ONE 70 KB line
    # (measured 2026-09-25; an upstream cost, reported, not worked around here).
    rec --verdict-exit -- /bin/sh -c 'yes 0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw | head -c 70000; exit 0' >"$T/o" 2>&1; rc=$?
    full=$(yes 0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw | head -c 70000 | sha256sum | cut -d' ' -f1)
    sref="$ST/$(field .stream_ref)"
    kept=$(wc -c < "$sref/stdout" 2>/dev/null | tr -d ' ')
    if [ "$rc" -eq 0 ] && [ "$(field .stream_truncated)" = true ] && [ "$(field .stdout_bytes)" = 70000 ] &&
       [ "$(field .stdout_digest)" = "$full" ] && [ "$kept" = 65536 ]; then
        ok "E5 70000-byte stream: digest+bytes of the FULL stream, 65536 kept, stream_truncated=true"
    else bad "E5 truncation (rc=$rc truncated=$(field .stream_truncated) bytes=$(field .stdout_bytes) kept=$kept digest_ok=$([ "$(field .stdout_digest)" = "$full" ] && echo y || echo n))"; fi

    # E6 — a credential-shaped stream is redacted before it is stored
    needle=$(printf 'api%s=%s%s' '_key' 'AKIA' 'Q7X2M4B8N1V5C3Z9')
    ZG_PROOF_NEEDLE=$needle rec --verdict-exit -- /bin/sh -c 'printf "%s\n" "$ZG_PROOF_NEEDLE"; exit 0' >"$T/o" 2>&1; rc=$?
    want=$(printf '%s\n' "$needle" | sha256sum | cut -d' ' -f1)
    if [ "$rc" -eq 0 ] && [ "$(field .stream_redacted)" = true ] && ! grep -rqF "Q7X2M4B8N1V5C3Z9" "$ST" "$S" &&
       [ "$(field .stdout_digest)" = "$want" ]; then
        ok "E6 credential stream: stored redacted, stream_redacted=true, digest of the ORIGINAL"
    else bad "E6 redaction (rc=$rc redacted=$(field .stream_redacted) leaked=$(grep -rlF Q7X2M4B8N1V5C3Z9 "$ST" 2>/dev/null | head -1))"; fi

    # E6b — a credential on the COMMAND LINE cannot be redacted without
    # falsifying argv, so the command is refused before it runs
    n6=$(lines "$S/sidecar.jsonl")
    rec --verdict-exit -- /bin/sh -c 'touch "$1"; exit 0' x "$T/ran-marker" "$needle" >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 2 ] && [ ! -e "$T/ran-marker" ] && [ "$(lines "$S/sidecar.jsonl")" = "$n6" ] &&
       ! grep -rqF "Q7X2M4B8N1V5C3Z9" "$ST" "$S" && grep -q "credential-shaped" "$T/o"; then
        ok "E6b credential on the command line: refused, NOT run, nothing recorded, nothing leaked"
    else bad "E6b argv credential (rc=$rc ran=$([ -e "$T/ran-marker" ] && echo y || echo n))"; fi

    # E7 — --verdict-file: the check's own verdict, not the exit status
    rec --verdict-file "$T/v" -- /bin/sh -c 'echo 1 > "$1"; exit 0' x "$T/v" >"$T/o" 2>&1; rc=$?
    r1=$rc o1=$(field .outcome)
    rec --verdict-file "$T/v" -- /bin/sh -c 'echo maybe > "$1"; exit 0' x "$T/v" >"$T/o" 2>&1; rc=$?
    r2=$rc o2=$(field .outcome)
    rm -f "$T/v"
    rec --verdict-file "$T/v" -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    r3=$rc o3=$(field .outcome)
    [ "$r1/$o1" = 1/1 ] && [ "$r2/$o2" = 2/2 ] && [ "$r3/$o3" = 2/2 ] \
        && ok "E7 verdict file: 1 read as 1 despite exit 0; garbage and absent => 2" \
        || bad "E7 verdict file (valid=$r1/$o1 garbage=$r2/$o2 absent=$r3/$o3)"

    # E8 — argv carrying quote, tab and newline round-trips exactly
    rec --verdict-exit -- /bin/sh -c 'exit 0' 'a"b' "$(printf 'c\td')" "$(printf 'e\nf')" >"$T/o" 2>&1; rc=$?
    got=$(last | jq -c .argv)
    want=$(jq -cn --arg a 'a"b' --arg b "$(printf 'c\td')" --arg c "$(printf 'e\nf')" '["/bin/sh","-c","exit 0",$a,$b,$c]')
    [ "$rc" -eq 0 ] && [ "$got" = "$want" ] && ok "E8 argv with quote/tab/newline recorded exactly as an array" \
        || bad "E8 argv (rc=$rc got=$got want=$want)"

    n0=$(lines "$S/sidecar.jsonl")
    # E18 — strict exec rows (review finding 5)
    er="$ST/exec_rows.jsonl"
    nrow=$(jq -c . "$er" 2>/dev/null | wc -l | tr -d ' ')
    keys=$(head -n 1 "$er" 2>/dev/null | jq -c 'keys' 2>/dev/null)
    e8row=$(tail -n 1 "$er" 2>/dev/null | jq -c .argv 2>/dev/null)
    refs_ok=1; for r in $(jq -r .stream_ref "$er" 2>/dev/null); do case $r in /*|*..*) refs_ok=0 ;; esac; [ -d "$ST/$r" ] || refs_ok=0; done
    if [ "$nrow" = "$(lines "$S/chain.jsonl")" ] && [ "$nrow" -gt 0 ] && [ "$e8row" = "$want" ] && [ "$refs_ok" = 1 ] &&
       [ "$keys" = '["argv","command","cwd","duration_ms","exit_status","stderr_bytes","stderr_digest","stdout_bytes","stdout_digest","stream_redacted","stream_ref","stream_truncated","ts"]' ]; then
        ok "E18 exec_rows.jsonl: strict JSON, one row per record, exact argv, the 13 FR-045 fields, stream_ref resolvable"
    else bad "E18 exec rows (rows=$nrow chain=$(lines "$S/chain.jsonl") argv=$e8row refs_ok=$refs_ok keys=$keys)"; fi

    # E19 — cwd under the repo is stored as <repo>/..., stream_ref as an id (finding 6)
    ( cd "$ZGE_ROOT/scripts" && rec --verdict-exit -- /bin/sh -c 'exit 0' ) >"$T/o" 2>&1; rc=$?
    sref=$(field .stream_ref)
    if [ "$rc" -eq 0 ] && [ "$(field .cwd)" = "<repo>/scripts" ] && [ -d "$ST/$sref" ] &&
       case $sref in /*|*/*|*..*) false ;; *) true ;; esac; then
        ok "E19 cwd recorded as <repo>/scripts and stream_ref as a bare stream id"
    else bad "E19 cwd/stream_ref (rc=$rc cwd=$(field .cwd) ref=$sref)"; fi

    # E17 — a password split over two arguments (finding 4)
    rec --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m17" --password hunter2hunter2 >"$T/o" 2>&1; rc=$?
    if [ "$rc" -eq 2 ] && [ ! -e "$T/m17" ] && ! grep -rqF hunter2hunter2 "$S" "$ST"; then
        ok "E17 --password <value> as two arguments: refused, NOT run, nothing stored"
    else bad "E17 split password (rc=$rc ran=$([ -e "$T/m17" ] && echo y || echo n))"; fi

    # E20 — one 70 KB line: the upstream scan takes ~95 s; the per-line cap fails
    # CLOSED (whole stream replaced, stream_redacted=true), digest of the ORIGINAL (finding 7)
    t0=$(date +%s)
    timeout 60 bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$S" --streams "$ST" --fp-dir "$W" \
        --item-id ATM-001 --check-id proof --population-kind source --verdict-role author \
        --independence-tier instance --evidence-class runtime --verdict-exit \
        -- /bin/sh -c 'head -c 70000 /dev/zero | tr "\000" a; exit 0' >"$T/o" 2>&1; rc=$?
    t1=$(date +%s)
    full=$(head -c 70000 /dev/zero | tr '\000' a | sha256sum | cut -d' ' -f1)
    if [ "$rc" -eq 0 ] && [ "$(field .stream_redacted)" = true ] && [ "$(field .stdout_digest)" = "$full" ] &&
       ! grep -q aaaaaaaaaa "$ST/$(field .stream_ref)/stdout"; then
        if grep -q 'line over the scan size cap' "$ST/$(field .stream_ref)/stdout" && ! grep -q 'credential-shaped' "$ST/$(field .stream_ref)/stdout"; then
            ok "E20 70 KB single line: over the scan cap => whole stream replaced (placeholder names the size cap), redacted=true, digest of the original, $((t1-t0)) s"
        else bad "E20 placeholder does not name the size cap: $(head -c 160 "$ST/$(field .stream_ref)/stdout")"; fi
    else bad "E20 long line (rc=$rc in $((t1-t0)) s, redacted=$(field .stream_redacted))"; fi
    # E21 — the scan TIMEOUT also fails closed (cap raised so the line is scanned)
    t0=$(date +%s)
    ZG_SCAN_MAX_LINE=1000000 ZG_SCAN_TIMEOUT=1 timeout 60 bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$S" --streams "$ST" --fp-dir "$W" \
        --item-id ATM-001 --check-id proof --population-kind source --verdict-role author \
        --independence-tier instance --evidence-class runtime --verdict-exit \
        -- /bin/sh -c 'head -c 70000 /dev/zero | tr "\000" a; exit 0' >"$T/o" 2>&1; rc=$?
    t1=$(date +%s)
    [ "$rc" -eq 0 ] && [ "$(field .stream_redacted)" = true ] && [ $((t1-t0)) -lt 30 ] &&
        grep -q 'time bound' "$ST/$(field .stream_ref)/stdout" && ! grep -q 'credential-shaped' "$ST/$(field .stream_ref)/stdout" \
        && ok "E21 scan timeout (1 s) fails closed: redacted=true in $((t1-t0)) s, placeholder names the time bound" \
        || bad "E21 scan timeout (rc=$rc in $((t1-t0)) s, redacted=$(field .stream_redacted))"

    # E22 — pre-flight: the check must NOT run against a store that cannot take it (finding 11)
    cp -r "$S" "$T/S22"; sed -n '1p' "$T/S22/sidecar.jsonl" >> "$T/S22/sidecar.jsonl"
    rec_in "$T/S22" --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m22" >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ ! -e "$T/m22" ] && grep -qi 'preflight' "$T/o" \
        && ok "E22 store with an unbound sidecar line: pre-flight refuses, the check is NOT run" \
        || bad "E22 pre-flight unbound (rc=$rc ran=$([ -e "$T/m22" ] && echo y || echo n))"
    cp -r "$S" "$T/S22b"; n=$(wc -c < "$T/S22b/chain.jsonl" | tr -d ' ')
    head -c $((n-1)) "$T/S22b/chain.jsonl" > "$T/x" && mv "$T/x" "$T/S22b/chain.jsonl"
    rec_in "$T/S22b" --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m22b" >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ ! -e "$T/m22b" ] && [ "$(wc -c < "$T/S22b/chain.jsonl" | tr -d ' ')" = $((n-1)) ] \
        && ok "E22b chain missing its final newline: refused before running, the chain is not glued onto" \
        || bad "E22b chain without final newline (rc=$rc ran=$([ -e "$T/m22b" ] && echo y || echo n))"

    # E23 — SIGTERM mid-run: nothing unredacted may remain (finding 3)
    mkdir -p "$T/S23"   # an empty (fresh) store dir, so every grep target exists
    ZG_PROOF_NEEDLE=$needle rec_in "$T/S23" --verdict-exit -- /bin/sh -c 'printf "%s\n" "$ZG_PROOF_NEEDLE"; exec sleep 30' >"$T/o23" 2>&1 &
    apid=$!
    for i in $(seq 1 100); do grep -rqF "$NEEDLE_TAIL" "$ST" 2>/dev/null && break; sleep 0.1; done
    pre=$(grep -rlF "$NEEDLE_TAIL" "$ST" 2>/dev/null | head -1)
    tree=$(desc "$apid")
    t0=$(date +%s); kill -TERM "$apid"; wait "$apid"; arc=$?; t1=$(date +%s)
    kill_pids $tree
    left=$(find "$ST" -maxdepth 1 -name '.incoming.*' | wc -l | tr -d ' ')
    if [ -n "$pre" ] && [ "$arc" -ne 0 ] && [ $((t1-t0)) -lt 10 ] && [ "$left" = 0 ] && ! grep -rqF "$NEEDLE_TAIL" "$ST" "$T/S23"; then
        ok "E23 SIGTERM mid-run (plaintext was on disk: precondition met): trap removed it in $((t1-t0)) s, rc $arc"
    else bad "E23 SIGTERM (precondition=${pre:+met} rc=$arc took=$((t1-t0))s incoming_left=$left leaked=$(grep -rlF "$NEEDLE_TAIL" "$ST" 2>/dev/null | head -1))"; fi

    # E24 — SIGKILL mid-run (untrappable): the NEXT run must scrub it (finding 3)
    mkdir -p "$T/S24"   # an empty (fresh) store dir, so every grep target exists
    ZG_PROOF_NEEDLE=$needle rec_in "$T/S24" --verdict-exit -- /bin/sh -c 'printf "%s\n" "$ZG_PROOF_NEEDLE"; exec sleep 30' >"$T/o24" 2>&1 &
    apid=$!
    for i in $(seq 1 100); do grep -rqF "$NEEDLE_TAIL" "$ST" 2>/dev/null && break; sleep 0.1; done
    tree=$(desc "$apid")
    kill -9 "$apid"; kill_pids $tree; wait "$apid" 2>/dev/null
    pre=$(grep -rlF "$NEEDLE_TAIL" "$ST" 2>/dev/null | head -1)
    rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    left=$(find "$ST" -maxdepth 1 -name '.incoming.*' | wc -l | tr -d ' ')
    if [ -n "$pre" ] && [ "$rc" -eq 0 ] && [ "$left" = 0 ] && grep -q 'stale' "$T/o" && ! grep -rqF "$NEEDLE_TAIL" "$ST" "$S" "$T/S24"; then
        ok "E24 SIGKILL left plaintext on disk (precondition met); the next run scrubbed it and reported it"
    else bad "E24 SIGKILL (precondition=${pre:+met} rc=$rc incoming_left=$left leaked=$(grep -rlF "$NEEDLE_TAIL" "$ST" "$S" 2>/dev/null | head -1))"; fi

    # E27 — argv secret POLICY by argument NAME/SHAPE (review T015b I1). Each
    # variant carries a distinct value that must appear NOWHERE afterwards.
    e27=0; i=0
    pol() { # label, then argv tail
        local label=$1; shift; i=$((i+1))
        rm -f "$T/m27"
        rec --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m27" "$@" >"$T/o" 2>&1; local r=$?
        if [ "$r" -eq 2 ] && [ ! -e "$T/m27" ] && ! grep -rqE "zgv${i}([^0-9]|\$)" "$S" "$ST"; then :; else
            e27=1; echo "    FAIL detail: [$label] rc=$r ran=$([ -e "$T/m27" ] && echo y || echo n) stored=$(grep -rlE "zgv${i}([^0-9]|\$)" "$S" "$ST" 2>/dev/null | head -1)"
        fi
    }
    pol '--pass X'            --pass "zgv1aa"
    pol '-p X'                -p "zgv2aa"
    pol '-pX'                 "-pzgv3aa"
    pol 'sshpass -p X'        sshpass -p "zgv4aa"
    pol '--password 7 chars'  --password "zgv5abc"
    pol '--password "" X'     --password "" "zgv6aa"
    pol '--password -- X'     --password -- "zgv7aa"
    pol '--token X'           --token "zgv8aa"
    pol 'TOKEN=X'             "TOKEN=zgv9aa"
    pol 'password=short'      "password=zgv10"
    pol 'Authorization Bearer' "Authorization: Bearer zgv11aa"
    pol 'bearer lowercase'    "bearer zgv12aa"
    pol 'URL credentials'     "https://u:zgv13aa@h.example.invalid/x"
    pol 'MY_API_KEY=X'        "MY_API_KEY=zgv14aa"
    pol '--pwd X'             --pwd "zgv15aa"
    pol '--client-secret X'   --client-secret "zgv16aa"
    [ "$e27" -eq 0 ] && ok "E27 16 secret-shaped command lines (incl. -p/-pX/--pass/--token/TOKEN=/short password/Bearer/URL credentials): all refused, NOT run, value stored nowhere" \
        || bad "E27 argv secret policy (details above)"
    # E27b — false-positive controls: ordinary flags must still run
    fp=0
    for a in --prove-failure --port=8080 --output-dir --bypass compass "https://example.invalid/x" "a=b" -c --parse; do
        rm -f "$T/m27"
        rec --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m27" "$a" >"$T/o" 2>&1 || { fp=1; echo "    FAIL detail: '$a' refused: $(grep -o 'refused.*' "$T/o" | head -1)"; }
        [ -e "$T/m27" ] || fp=1
    done
    [ "$fp" -eq 0 ] && ok "E27b false-positive controls (--prove-failure --port=8080 --output-dir --bypass compass plain-URL a=b -c --parse) all ran" \
        || bad "E27b a legitimate argument was refused (details above)"

    # E28 — a SIGKILLed adapter whose wrapped command is still RUNNING: its
    # incoming dir is live and must NOT be swept (review T015b M1)
    rec_in "$T/S28" --verdict-exit -- /bin/sh -c 'exec sleep 30' >"$T/o28" 2>&1 &
    apid=$!
    for i in $(seq 1 100); do
        idir=$(ls -d "$ST"/.incoming."$apid".* 2>/dev/null | head -1)
        [ -n "$idir" ] && [ -n "$(desc "$apid")" ] && [ "$(wc -l < "$idir/owner" 2>/dev/null || echo 0)" -ge 2 ] && break
        sleep 0.1
    done
    tree=$(desc "$apid")
    kill -9 "$apid"; wait "$apid" 2>/dev/null
    idir=$(ls -d "$ST"/.incoming."$apid".* 2>/dev/null | head -1)
    rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; r1=$?
    kept=$([ -n "$idir" ] && [ -d "$idir" ] && echo y || echo n)
    kill_pids $tree
    for i in $(seq 1 50); do alive=0; for p in $tree; do ps -p "$p" >/dev/null 2>&1 && alive=1; done; [ "$alive" = 0 ] && break; sleep 0.1; done
    rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; r2=$?
    gone=$([ -n "$idir" ] && [ ! -e "$idir" ] && echo y || echo n)
    [ -n "$idir" ] && [ "$r1" -eq 0 ] && [ "$kept" = y ] && [ "$r2" -eq 0 ] && [ "$gone" = y ] \
        && ok "E28 adapter SIGKILLed while its command still runs: the live dir is kept; once the command is gone the next run sweeps it" \
        || bad "E28 live child (dir=${idir:+found} kept=$kept r1=$r1 gone=$gone r2=$r2)"

    # E27c — review T015c I1: secrets INSIDE a quoted script body, name
    # segments/suffixes, -u user:pw, Cookie/Set-Cookie, --key, --credentials,
    # --access-key. Same oracle as E27: refused, NOT run, value stored nowhere.
    e27=0; i=100
    pol 'sh -c --password X'  "curl --password zgv101aa https://h.invalid"
    pol 'sh -c sshpass -p X'  "sshpass -p zgv102aa ssh h"
    pol '--db-pass X'         --db-pass "zgv103aa"
    pol 'DB_PASS=X'           "DB_PASS=zgv104aa"
    pol 'MYSQL_PWD=X'         "MYSQL_PWD=zgv105aa"
    pol '-storepass X'        -storepass "zgv106aa"
    pol '-keypass X'          -keypass "zgv107aa"
    pol 'curl -u admin:pw'    -u "admin:zgv108aa"
    pol '--user a:b'          --user "a:zgv109aa"
    pol 'Cookie: header'      "Cookie: sid=zgv110aa"
    pol '--key X'             --key "zgv111aa"
    pol '--credentials X'     --credentials "zgv112aa"
    pol '--access-key X'      --access-key "zgv113aa"
    pol 'Set-Cookie: header'  "Set-Cookie: sid=zgv114aa"
    [ "$e27" -eq 0 ] && ok "E27c 14 more secret-shaped command lines (quoted script bodies word-scanned, db-pass/DB_PASS/MYSQL_PWD/-storepass/-keypass, -u/--user x:y, Cookie/Set-Cookie, --key/--credentials/--access-key): all refused, NOT run, stored nowhere" \
        || bad "E27c argv secret policy, round 3 (details above)"

    # E27d — review T015d F1: quoted/escaped flags inside a script body, a
    # secret NAME= nested in a flag's value, a token-only URL, -P and a
    # homoglyph flag. Same oracle: refused, NOT run, value stored nowhere.
    e27=0; i=200
    pol "sh -c '--password' X"     "curl '--password' zgv201aa https://h.invalid"
    pol 'sh -c "--password" X'     'curl "--password" zgv202aa https://h.invalid'
    pol "sh -c '-p' X"             "sshpass '-p' zgv203aa ssh h"
    pol 'sh -c \--password X'      'curl \--password zgv204aa https://h.invalid'
    pol "sh -c \$'--pass\\x77ord'" "curl \$'--pass\\x77ord' zgv205aa https://h.invalid"
    pol '--build-arg=TOKEN=X'      --build-arg=TOKEN=zgv206aa
    pol '--header=Cookie:s=X'      --header=Cookie:s=zgv207aa
    pol '--opt=a:b,token=X'        --opt=a:b,token=zgv208aa
    pol 'token-only URL'           https://zgv209aa@github.invalid/x/y.git
    pol '-P X'                     -P zgv210aa
    pol 'homoglyph --раssword'     --раssword zgv211aa
    pol 'query ?access_token='     'https://h.invalid/x?access_token=zgv212aa'
    [ "$e27" -eq 0 ] && ok "E27d 12 obfuscated command lines (quoted/escaped/ANSI-C flags in a script body, NAME= nested in a flag value, token-only URL, -P, Cyrillic homoglyph, ?access_token=): all refused, NOT run, stored nowhere" \
        || bad "E27d argv secret policy, round 4 (details above)"
    # E27e — documented misses and false-positive controls of round 4: the
    # header must tell the truth in BOTH directions.
    fp=0
    for a in "ssh://git@github.invalid/x/y.git" "--format=%H:%s" "12:30:00" "--label=env:prod,tier=web" "--build-arg=VERSION=1.2"; do
        rm -f "$T/m27"
        rec --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m27" "$a" >"$T/o" 2>&1 || { fp=1; echo "    FAIL detail: '$a' refused: $(grep -o 'refused.*' "$T/o" | head -1)"; }
        [ -e "$T/m27" ] || fp=1
    done
    rm -f "$T/m27"
    rec --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m27" redis-cli -a zgv220aa >"$T/o" 2>&1; ra=$?
    [ "$ra" -eq 0 ] && [ -e "$T/m27" ] || { fp=1; echo "    FAIL detail: 'redis-cli -a X' is documented as NOT caught (a name-less value) but rc=$ra"; }
    [ "$fp" -eq 0 ] && ok "E27e round-4 controls: git@ URL, --format=%H:%s, 12:30:00, env:prod,tier=web, --build-arg=VERSION= all ran; 'redis-cli -a X' ran (documented miss: name-less value, recipe REDISCLI_AUTH)" \
        || bad "E27e round-4 controls (details above)"

    # E31 — review T015d F2: every path the scripts or a plain `go build` /
    # `go test -c` in the shim module would drop INSIDE the repository must be
    # git-ignored (§11.4.30: the `commit` wrapper runs `git add .`).
    ig=0
    for p in _tools/zero-gap-chain/zero-gap-chain _tools/zero-gap-chain/zero-gap-chain.test _tools/zero-gap-chain/bin/zg-chain _tools/zero-gap-chain/bin/continuum-integrity; do
        git -C "$ZGE_ROOT" check-ignore -q -- "$p" || { ig=1; echo "    FAIL detail: $p is NOT git-ignored"; }
    done
    [ "$ig" -eq 0 ] && ok "E31 build artefacts of the shim module (go build ./zero-gap-chain, go test -c *.test, bin/) are git-ignored" \
        || bad "E31 build artefacts not ignored (details above)"

    # E29 — the adapter's OWN pre-run gates are linear, one process each
    # (review T015c I1): 3000 short arguments must clear (a) the argv policy
    # and (b) the bounded upstream-scan views in < 5 s. (a) is timed with a
    # secret-shaped flag as the LAST word, so the whole argv is traversed;
    # (b) with 3000 clean arguments refused at the NEXT gate, a store lock held
    # by a holder started here (bound 1 s, killed by its own pid). The full
    # record is also timed and PRINTED: the constitution recorder serialises
    # argv with four processes per argument (execution_record.sh line 71), an
    # upstream cost this adapter cannot change — registered, not hidden.
    set -- ; for i in $(seq 1 3000); do set -- "$@" "a$i"; done
    t0=$(date +%s%N)
    rec_in "$T/S29" --verdict-exit -- /bin/sh -c 'exit 0' x "$@" --token zgv29a >"$T/o29" 2>&1; r=$?
    t1=$(date +%s%N); msa=$(( (t1-t0)/1000000 ))
    rec_in "$T/S29" --verdict-exit -- /bin/sh -c 'exit 0' >/dev/null 2>&1
    rm -f "$T/held29"
    "$ZG_CHAIN_BIN" with-lock --store "$T/S29" --shared -- /bin/sh -c ': > "$1"; exec sleep 60' x "$T/held29" >/dev/null 2>&1 &
    hpid29=$!
    for i in $(seq 1 100); do [ -e "$T/held29" ] && break; sleep 0.05; done
    t0=$(date +%s%N)
    ZG_LOCK_TIMEOUT=1s rec_in "$T/S29" --verdict-exit -- /bin/sh -c 'exit 0' x "$@" >"$T/o29b" 2>&1; rb=$?
    t1=$(date +%s%N); msb=$(( (t1-t0)/1000000 ))
    kill -9 "$hpid29" 2>/dev/null; wait "$hpid29" 2>/dev/null
    t0=$(date +%s%N)
    rec_in "$T/S29" --verdict-exit -- /bin/sh -c 'exit 0' x "$@" >"$T/o29c" 2>&1; rcf=$?
    t1=$(date +%s%N); msc=$(( (t1-t0)/1000000 ))
    set --
    if [ "$r" -eq 2 ] && grep -q 'argv secret policy' "$T/o29" && [ "$msa" -lt 5000 ] &&
       [ "$rb" -eq 2 ] && grep -q 'store lock was not obtained' "$T/o29b" && [ "$msb" -lt 5000 ]; then
        ok "E29 3000 short arguments: argv policy ${msa} ms, policy + bounded scan views + lock gate ${msb} ms (both < 5 s)"
    else bad "E29 3000 arguments (policy rc=$r ${msa} ms; scan+lock rc=$rb ${msb} ms): $(tail -1 "$T/o29" "$T/o29b" | tr '\n' ' ')"; fi
    echo "    NOTE E29 full record of 3000 arguments: rc $rcf in ${msc} ms — dominated by the upstream recorder's per-argument serialisation (upstream limitation)"

    # E30 — the store lock is taken BEFORE the check runs and held through
    # sealing; a lock not obtained within the bound refuses the RUN (rc 2,
    # command NOT executed, nothing written). The stuck holder is started here
    # and killed by its own pid.
    rec_in "$T/S30" --verdict-exit -- /bin/sh -c 'exit 0' >/dev/null 2>&1
    before30=$(cat "$T/S30/sidecar.jsonl" 2>/dev/null | sha256sum)
    rm -f "$T/held30" "$T/m30"
    "$ZG_CHAIN_BIN" with-lock --store "$T/S30" --shared -- /bin/sh -c ': > "$1"; exec sleep 60' x "$T/held30" >/dev/null 2>&1 &
    hpid30=$!
    for i in $(seq 1 100); do [ -e "$T/held30" ] && break; sleep 0.05; done
    t0=$(date +%s)
    ZG_LOCK_TIMEOUT=1s rec_in "$T/S30" --verdict-exit -- /bin/sh -c 'touch "$1"' x "$T/m30" >"$T/o30" 2>&1 &
    rpid30=$!
    for i in $(seq 1 200); do ps -p "$rpid30" >/dev/null 2>&1 || break; sleep 0.1; done
    if ps -p "$rpid30" >/dev/null 2>&1; then kill -9 "$rpid30" 2>/dev/null; r=hung; else wait "$rpid30"; r=$?; fi
    t1=$(date +%s)
    kill -9 "$hpid30" 2>/dev/null; wait "$hpid30" 2>/dev/null
    after30=$(cat "$T/S30/sidecar.jsonl" 2>/dev/null | sha256sum)
    [ "$r" = 2 ] && [ ! -e "$T/m30" ] && [ "$before30" = "$after30" ] && grep -q 'store lock was not obtained' "$T/o30" \
        && ok "E30 store lock held elsewhere (bound 1 s): rc 2 in $((t1-t0)) s, the check NOT run, nothing written" \
        || bad "E30 stuck lock (rc=$r ran=$([ -e "$T/m30" ] && echo y || echo n) written=$([ "$before30" = "$after30" ] && echo n || echo y)): $(tail -2 "$T/o30" | tr '\n' ' ')"

    # E25 — the ruled locations: store+streams UNTRACKED under .remember (finding 2)
    if [ "${ZGE_DEFAULT_STORE:-}" = "$ZGE_ROOT/.remember/logs/zero-gap/evidence" ] &&
       [ "${ZGE_DEFAULT_STREAMS:-}" = "$ZGE_ROOT/.remember/logs/zero-gap/evidence/streams" ] &&
       zge_streams_outside_vcs "$ZGE_DEFAULT_STREAMS"; then
        ok "E25 defaults: store and streams under the git-ignored .remember/logs/zero-gap/evidence"
    else bad "E25 defaults (store=${ZGE_DEFAULT_STORE:-unset} streams=${ZGE_DEFAULT_STREAMS:-unset})"; fi

    # E26 — --verdict-file never deletes a TRACKED file (finding 12)
    rec --verdict-file "$W/f" -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ -f "$W/f" ] && ok "E26 --verdict-file naming a tracked file: refused, the file is untouched" \
        || bad "E26 verdict file tracked (rc=$rc exists=$([ -f "$W/f" ] && echo y || echo n))"
    git -C "$W" checkout -q -- f 2>/dev/null

    n0=$(lines "$S/sidecar.jsonl")   # re-snapshot: the cases above append records
    # E9 — scanner unreachable: refused, nothing recorded
    ZG_CRED_LIB="$T/no-such-scanner.sh" rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(lines "$S/sidecar.jsonl")" = "$n0" ] && grep -q "credential scanner" "$T/o" && ok "E9 unreachable credential scanner: rc 2, nothing recorded" \
        || bad "E9 scanner unreachable (rc=$rc lines $n0 -> $(lines "$S/sidecar.jsonl"))"
    # E10 — streams inside a git work tree, not ignored: refused
    bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$S" --streams "$W/streams" --fp-dir "$W" \
        --item-id ATM-001 --check-id proof --population-kind source --verdict-role author \
        --independence-tier instance --evidence-class runtime --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(lines "$S/sidecar.jsonl")" = "$n0" ] && [ ! -e "$W/streams" ] && grep -q "version control" "$T/o" && ok "E10 streams inside version control: rc 2, nothing recorded" \
        || bad "E10 streams in VCS (rc=$rc)"
    # E11 — no verdict mode: refused
    rec -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(lines "$S/sidecar.jsonl")" = "$n0" ] && grep -q "verdict source" "$T/o" && ok "E11 no verdict source declared: rc 2, nothing recorded" \
        || bad "E11 no verdict mode (rc=$rc)"
    # E12 — no session id: refused, never invented
    ZG_SESSION_ID='' rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(lines "$S/sidecar.jsonl")" = "$n0" ] && grep -q "session" "$T/o" && ok "E12 empty session id: rc 2, nothing recorded" \
        || bad "E12 empty session (rc=$rc)"
    # E13 — closed-set violation: refused
    bash "$ZGE_HERE/zero-gap-evidence.sh" record --store "$S" --streams "$ST" --fp-dir "$W" \
        --item-id ATM-001 --check-id proof --population-kind source --verdict-role author \
        --independence-tier bogus --evidence-class runtime --verdict-exit -- /bin/sh -c 'exit 0' >"$T/o" 2>&1; rc=$?
    [ "$rc" -eq 2 ] && [ "$(lines "$S/sidecar.jsonl")" = "$n0" ] && grep -q "independence_tier" "$T/o" && ok "E13 independence tier outside the closed set: rc 2, nothing recorded" \
        || bad "E13 closed set (rc=$rc)"
    # E14 — concurrent records serialise into one consistent store
    for i in 1 2 3 4; do rec --verdict-exit -- /bin/sh -c 'exit 0' >"$T/c$i" 2>&1 & done
    crc=0; for j in 1 2 3 4; do wait -n || crc=1; done
    seqs=$(jq -r .chain_seq "$S/sidecar.jsonl" | tr '\n' ' ')
    want=$(seq 1 "$(lines "$S/sidecar.jsonl")" | tr '\n' ' ')
    [ "$crc" -eq 0 ] && [ "$seqs" = "$want" ] && ok "E14 four concurrent records: chain_seq contiguous 1..N" \
        || bad "E14 concurrency (crc=$crc seqs=$seqs)"

    # E15 — the whole store the adapter produced verifies: adapter invariants
    # AND the upstream verifier reads it natively
    "$ZG_CHAIN_BIN" verify --store "$S" --schema "$ZGE_CONTRACT" >"$T/o" 2>&1; v1=$?
    "$INTEG" chain verify --chain "$S/chain.jsonl" >/dev/null 2>"$T/o2"; v2=$?
    [ "$v1" -eq 0 ] && [ "$v2" -eq 0 ] && ok "E15 produced store: every adapter invariant holds and continuum-integrity chain verify PASSes" \
        || bad "E15 produced store (sidecar rc=$v1: $(tail -2 "$T/o" | tr '\n' ' ') chain rc=$v2: $(cat "$T/o2"))"

    zg_manifest "$ZGE_ROOT" "${LIVE[@]}" > "$T.live1" 2>/dev/null || : > "$T.live1"
    if ! cmp -s "$T.live0" "$T.live1"; then
        echo "  UNDETERMINED: the live inputs changed while the proof ran (a concurrent editor cannot be attributed):"
        { diff "$T.live0" "$T.live1" || true; } | sed -n 's/^[<>] //p' | cut -f1 | LC_ALL=C sort -u | sed 's/^/    /'
        echo "prove-failure: $pass passed, $fail failed (live inputs moved)"; exit 2
    fi
    ok "E16 live inputs byte-identical before and after (the proof wrote only to throwaway paths)"
    echo "prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ] && exit 0
    exit 1
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        record)          shift; zge_record "$@"; exit $? ;;
        --prove-failure) zge_prove_failure; exit $? ;;
        --build-bins)    [ -n "${2:-}" ] || { zge_say "--build-bins needs a directory"; exit 2; }
                         zge_build_bins "$2"; exit $? ;;
        -h|--help)       sed -n '2,211p' "$0"; exit 0 ;;
        *)               zge_say "usage: record ... -- CMD | --prove-failure | --build-bins DIR (see --help)"; exit 2 ;;
    esac
fi
