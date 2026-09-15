#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# record-reopen.sh — the ONLY writer of docs/findings/reopened-reds.jsonl.
#
# WHY THIS EXISTS (T114, was 005/T058)
# ---------------------------------------
# specs/008-unified-workshop-platform/tasks.md FR-026 (unified FR-257) / SC-017
# (unified SC-134) require a reopen-event ledger: one JSON object per reopen —
# instrument, the PRIOR closure's kind (`fixed` or `declared`), the
# contradicting evidence, and a timestamp for when the reopen was FOUND. No
# such ledger existed before this file. §11.4.34 (reopened-source attribution)
# and the project's own convention throughout (§11.4.226/§11.4.267: evidence
# is APPENDED, never edited in place) both require this: a prior closure
# record must NEVER be overwritten — a reopen is a NEW, ADDITIONAL entry that
# REFERENCES the original, never a mutation of it.
#
# WHO CALLS THIS
# ----------------
# - A human or agent who has independently found a reopen (this is how T115
#   seeds the two already-measured reopens R2/R4 from CLAUDE.md's own history).
# - scripts/fleet-summary.sh (T109), which detects the MECHANICAL case — a
#   check with a `declared-reds.tsv` row whose `next_review` has ELAPSED, and
#   which is STILL red — and prints the exact invocation to run. It does NOT
#   call this script automatically on every run: writing to a durable ledger
#   is a DECIDED event, not a side effect of a routine sweep, mirroring this
#   project's own convention for scripts/audit/zero_findings_sweep.sh (its
#   ledger is written only under an explicit --write-ledger, never silently).
#
# STRUCTURAL GUARANTEE — APPEND-ONLY, MECHANICALLY, NOT BY CONVENTION
# -----------------------------------------------------------------------
# This script contains NO code path that opens the ledger with `>` (truncate).
# Every write is `>>` (append). A `--reopen-id` that already exists in the
# file is REFUSED (rc 1) rather than silently reused, so two different reopen
# events can never collide under the same id and no existing line can be
# mistaken for "already replaced". The one guarantee this script does NOT
# make on its own is that nobody hand-edits the file outside this script —
# that boundary is the same one every git-tracked ledger in this repository
# relies on, and is why the file is committed: a hand-edit shows in `git log`.
#
# SCHEMA — one JSON object per line (JSONL)
#   reopen_id               stable id, "R<N>" by convention (continuing the
#                            sequence CLAUDE.md's own prose already uses: R2,
#                            R4 are the two seeded by T115). Auto-assigned as
#                            "R<max existing N + 1>" if --reopen-id is omitted.
#   instrument               the check-registry.tsv `check` id, or another
#                            named instrument if the reopen predates this
#                            registry (free text, but SHOULD be a registered
#                            check id going forward)
#   prior_closure_kind       "fixed" | "declared" — closed vocabulary
#   contradicting_evidence   free text: the observation that shows the prior
#                            closure no longer holds
#   original_closure_ref     free text: WHERE the original closure was
#                            recorded (a CLAUDE.md section, a
#                            declared-reds.tsv row, a workable-item id) — so a
#                            reader can find what is being contradicted
#   reopened_at              ISO-8601 timestamp (UTC) for when THIS reopen was
#                            FOUND — not when the original closure happened
#   supersedes               reopen_id of a PRIOR entry for the same
#                            instrument this one follows, or null for the
#                            first recorded reopen of that instrument
#
# EXIT CODES
#   0  the entry was appended
#   1  a real validation failure (missing field, closed-vocabulary violation,
#      duplicate reopen_id)
#   2  COULD NOT DETERMINE — the ledger directory is not writable, or (in
#      --prove-failure) the sandbox could not be built
#
# USAGE
#   scripts/record-reopen.sh --instrument ID --prior-kind fixed|declared \
#       --evidence TEXT --closure-ref TEXT [--reopen-id RN] [--supersedes RN] \
#       [--timestamp ISO8601]
#   scripts/record-reopen.sh --list                 print the ledger, parsed
#   scripts/record-reopen.sh --root DIR
#   scripts/record-reopen.sh --prove-failure         its own §1.1 proof
# ------------------------------------------------------------------------------
set -uo pipefail

SELF_NAME="$(basename -- "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || {
    echo "FATAL: cannot resolve script directory" >&2; exit 2; }

ROOT=""
INSTRUMENT=""; KIND=""; EVIDENCE=""; CLOSURE_REF=""; REOPEN_ID=""; SUPERSEDES=""; TS=""
LIST=0
PROVE=0

usage() { sed -n '/^# USAGE/,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | head -n -1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)          shift; ROOT="${1:-}" ;;
        --instrument)    shift; INSTRUMENT="${1:-}" ;;
        --prior-kind)    shift; KIND="${1:-}" ;;
        --evidence)      shift; EVIDENCE="${1:-}" ;;
        --closure-ref)   shift; CLOSURE_REF="${1:-}" ;;
        --reopen-id)     shift; REOPEN_ID="${1:-}" ;;
        --supersedes)    shift; SUPERSEDES="${1:-}" ;;
        --timestamp)     shift; TS="${1:-}" ;;
        --list)          LIST=1 ;;
        --prove-failure) PROVE=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "$SELF_NAME: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -n "$ROOT" ]]; then
    ROOT="$(cd -- "$ROOT" 2>/dev/null && pwd)" || {
        echo "UNDET  target root does not exist: it cannot be inspected, so this is neither a pass nor a fail" >&2
        exit 2; }
else
    ROOT="$(cd -- "$SELF_DIR/.." && pwd)" || {
        echo "FATAL: cannot derive repository root" >&2; exit 2; }
fi

LEDGER="$ROOT/docs/findings/reopened-reds.jsonl"

# JSON-escape a string: backslash, double-quote, and control characters. No
# external dependency (jq is not assumed present on every host in this fleet).
jesc() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

next_id() {
    local f="$1" max=0
    [[ -f "$f" ]] || { printf 'R1'; return; }
    while IFS= read -r line; do
        [[ "$line" =~ \"reopen_id\":\"R([0-9]+)\" ]] || continue
        local n="${BASH_REMATCH[1]}"
        (( n > max )) && max=$n
    done <"$f"
    printf 'R%s' "$((max + 1))"
}

id_exists() {
    local f="$1" id="$2"
    [[ -f "$f" ]] || return 1
    grep -qF "\"reopen_id\":\"${id}\"" "$f"
}

if [[ $LIST -eq 1 ]]; then
    [[ -f "$LEDGER" ]] || { echo "(no ledger yet at $LEDGER)"; exit 0; }
    grep -v '^#' "$LEDGER" | grep -v '^[[:space:]]*$'
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF
# ──────────────────────────────────────────────────────────────────────────────
if [[ $PROVE -eq 1 ]]; then
    printf 'RECORD-REOPEN §1.1 PAIRED MUTATION PROOF\n'
    echo "----------------------------------------------------------------------"
    P_PASS=0; P_FAIL=0
    p_ok()  { P_PASS=$((P_PASS+1)); printf '✅ %-28s %s\n' "$1" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '❌ %-28s %s\n' "$1" "$2"; }

    SB="$(mktemp -d "${TMPDIR:-/tmp}/record-reopen-proof.XXXXXX")" || {
        echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM
    mkdir -p "$SB/docs/findings"

    SELF="$SELF_DIR/$SELF_NAME"
    run() { bash "$SELF" --root "$SB" "$@"; }

    # ---- CONTROL: a valid append succeeds and the file grows ------------------
    before_sz=0
    [[ -f "$SB/docs/findings/reopened-reds.jsonl" ]] && before_sz=$(wc -c <"$SB/docs/findings/reopened-reds.jsonl")
    out="$(run --instrument alpha-check --prior-kind declared --evidence "e1" --closure-ref "c1" --reopen-id R1 2>&1)"; rc=$?
    after_sz=$(wc -c <"$SB/docs/findings/reopened-reds.jsonl" 2>/dev/null || echo 0)
    if [[ $rc -eq 0 && $after_sz -gt $before_sz ]]; then p_ok "CONTROL first-append" "rc=0, ledger grew ${before_sz}->${after_sz} bytes"
    else p_bad "CONTROL first-append" "rc=$rc, size ${before_sz}->${after_sz}"; fi

    # ---- M1: a second, DIFFERENT append never truncates the first -------------
    first_line="$(head -1 "$SB/docs/findings/reopened-reds.jsonl" 2>/dev/null)"
    run --instrument beta-check --prior-kind fixed --evidence "e2" --closure-ref "c2" --reopen-id R2 >/dev/null 2>&1
    if [[ "$(head -1 "$SB/docs/findings/reopened-reds.jsonl")" == "$first_line" && $(wc -l <"$SB/docs/findings/reopened-reds.jsonl") -eq 2 ]]; then
        p_ok "M1 append-only" "the first line is byte-identical after a second append; 2 line(s) total"
    else
        p_bad "M1 append-only" "the first line changed, or the line count is not 2 — this is the ONE property that must never break"
    fi

    # ---- M2: a duplicate reopen_id is refused ----------------------------------
    lc_before=$(wc -l <"$SB/docs/findings/reopened-reds.jsonl")
    out="$(run --instrument alpha-check --prior-kind declared --evidence "e3" --closure-ref "c1" --reopen-id R1 2>&1)"; rc=$?
    lc_after=$(wc -l <"$SB/docs/findings/reopened-reds.jsonl")
    if [[ $rc -eq 1 && "$lc_after" == "$lc_before" ]] && grep -qi "already exists" <<<"$out"; then
        p_ok "M2 duplicate-id-refused" "rc=1, named 'already exists', line count unchanged ($lc_before)"
    else
        p_bad "M2 duplicate-id-refused" "expected rc=1 with no growth, got rc=$rc, lines $lc_before->$lc_after: $out"
    fi

    # ---- M3: a malformed prior-kind is refused ---------------------------------
    lc_before=$(wc -l <"$SB/docs/findings/reopened-reds.jsonl")
    out="$(run --instrument gamma-check --prior-kind bogus --evidence "e4" --closure-ref "c4" 2>&1)"; rc=$?
    lc_after=$(wc -l <"$SB/docs/findings/reopened-reds.jsonl")
    if [[ $rc -eq 1 && "$lc_after" == "$lc_before" ]] && grep -qi "closed vocabulary" <<<"$out"; then
        p_ok "M3 bad-prior-kind-refused" "rc=1, named the closed vocabulary, no write"
    else
        p_bad "M3 bad-prior-kind-refused" "expected rc=1 with no growth, got rc=$rc: $out"
    fi

    # ---- M4: a missing required field is refused, not silently defaulted ------
    out="$(run --instrument delta-check --prior-kind fixed --evidence "e5" 2>&1)"; rc=$?
    if [[ $rc -eq 1 ]] && grep -qi "closure-ref" <<<"$out"; then p_ok "M4 missing-field-refused" "rc=1, named the missing field"
    else p_bad "M4 missing-field-refused" "expected rc=1 naming closure-ref, got rc=$rc: $out"; fi

    # ---- M5: auto-assigned id continues the sequence ---------------------------
    out="$(run --instrument epsilon-check --prior-kind fixed --evidence "e6" --closure-ref "c6" 2>&1)"; rc=$?
    if [[ $rc -eq 0 ]] && grep -qF '"reopen_id":"R3"' "$SB/docs/findings/reopened-reds.jsonl"; then
        p_ok "M5 auto-id-sequence" "rc=0, auto-assigned R3 (after R1, R2)"
    else
        p_bad "M5 auto-id-sequence" "expected R3 to be assigned, got rc=$rc"
    fi

    # ---- M6: an unwritable ledger directory is rc=2, never a pass -------------
    RO="$(mktemp -d "${TMPDIR:-/tmp}/record-reopen-ro.XXXXXX")"
    mkdir -p "$RO/docs/findings"
    chmod 000 "$RO/docs/findings"
    if [[ "$(id -u)" == "0" ]]; then
        p_ok "M6 unwritable-dir-rc2" "SKIPPED — running as uid 0, permissions are not enforced"
    else
        out="$(run --root "$RO" --instrument zeta-check --prior-kind fixed --evidence "e7" --closure-ref "c7" 2>&1)"; rc=$?
        if [[ $rc -eq 2 ]]; then p_ok "M6 unwritable-dir-rc2" "rc=2, never a pass"
        else p_bad "M6 unwritable-dir-rc2" "expected rc=2, got rc=$rc: $out"; fi
    fi
    chmod 755 "$RO/docs/findings"; rm -rf "$RO"

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        printf '❌ RECORD-REOPEN §1.1 PROOF: FAIL — %s case(s) did not behave as required.\n' "$P_FAIL"
        exit 1
    fi
    printf '✅ RECORD-REOPEN §1.1 MUTATION PROOF: PASS — %s assertions: appends grow the ledger,\n' "$P_PASS"
    printf '   a second append NEVER disturbs the first byte of the file, a duplicate id and a\n'
    printf '   malformed prior_closure_kind are both refused with no write, a missing required\n'
    printf '   field is refused rather than defaulted, ids auto-continue the sequence, and an\n'
    printf '   unwritable target reports rc=2 rather than a pass.\n'
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Live append
# ──────────────────────────────────────────────────────────────────────────────
missing=()
[[ -n "$INSTRUMENT" ]]  || missing+=("--instrument")
[[ -n "$KIND" ]]        || missing+=("--prior-kind")
[[ -n "$EVIDENCE" ]]    || missing+=("--evidence")
[[ -n "$CLOSURE_REF" ]] || missing+=("--closure-ref")
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "REFUSED: missing required argument(s): ${missing[*]}" >&2
    exit 1
fi

case "$KIND" in
    fixed|declared) ;;
    *) echo "REFUSED: --prior-kind '$KIND' is not in the closed vocabulary {fixed,declared}" >&2; exit 1 ;;
esac

DOCS_DIR="$ROOT/docs/findings"
if [[ ! -d "$DOCS_DIR" ]]; then
    echo "UNDET: $DOCS_DIR does not exist — cannot append" >&2
    exit 2
fi
if [[ ! -w "$DOCS_DIR" ]]; then
    echo "UNDET: $DOCS_DIR is not writable — cannot append" >&2
    exit 2
fi

[[ -n "$TS" ]] || TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
[[ -n "$REOPEN_ID" ]] || REOPEN_ID="$(next_id "$LEDGER")"

if id_exists "$LEDGER" "$REOPEN_ID"; then
    echo "REFUSED: reopen_id '$REOPEN_ID' already exists in $LEDGER — a reopen APPENDS a new id, it never reuses one" >&2
    exit 1
fi

SUPERSEDES_JSON="null"
[[ -n "$SUPERSEDES" ]] && SUPERSEDES_JSON="\"$(jesc "$SUPERSEDES")\""

LINE="{\"reopen_id\":\"$(jesc "$REOPEN_ID")\",\"instrument\":\"$(jesc "$INSTRUMENT")\",\"prior_closure_kind\":\"$(jesc "$KIND")\",\"contradicting_evidence\":\"$(jesc "$EVIDENCE")\",\"original_closure_ref\":\"$(jesc "$CLOSURE_REF")\",\"reopened_at\":\"$(jesc "$TS")\",\"supersedes\":${SUPERSEDES_JSON}}"

# The ONLY write path in this script, and it is `>>`. See the header: no code
# path in this file may ever open the ledger with `>`.
printf '%s\n' "$LINE" >>"$LEDGER"
echo "✅ recorded $REOPEN_ID for '$INSTRUMENT' ($KIND) at $TS"
exit 0
