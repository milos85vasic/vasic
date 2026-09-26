#!/usr/bin/env bash
# zero-gap-class-unsealed-evidence.sh — feature 010 sweep class `unsealed-evidence` (task T028).
#
# WHAT IT DETECTS
#   Producers of PASS verdicts whose result is NOT sealed into the evidence chain
#   (§11.4.262 machine-created evidence, §11.4.268 tamper-evident chain), and the
#   state of the chain itself:
#     gate:<id>    a pre-push gate of scripts/pre-push-gates.sh (every word of its
#                  literal `GATE_IDS=(...)` line) whose invocation does not go
#                  through `scripts/zero-gap-evidence.sh record` — neither the
#                  body of `run_gate` nor the body of `gate_<id>` carries such a
#                  call. FINDING high false-evidence.
#     check:<id>   a `check` row of scripts/check-registry.tsv that NO runner seals:
#                  no runner file carries a `zero-gap-evidence.sh record` call with
#                  the LITERAL `--check-id <id>` (or `--check-id=<id>`, quoted or
#                  not) on the same logical line. FINDING medium false-evidence.
#                  The id is printed as its percent-encoded token in the location
#                  AND the description (a raw U+202E once made the runner reject
#                  the whole class output); an id longer than 200 characters is
#                  COULD-NOT-INSPECT at scripts/check-registry.tsv:<line>, and a
#                  failed sealed-id comparison (grep rc 2) is COULD-NOT-INSPECT,
#                  never read as "unsealed".
#     store:.remember/logs/zero-gap/evidence
#                  the two-file evidence store. Absent => FINDING medium
#                  false-evidence ("no evidence store yet": absence IS the
#                  finding, nothing is COULD-NOT-INSPECT). Present => it is
#                  verified READ-ONLY with `scripts/zero-gap-evidence-chain.sh
#                  --verify` (bounded by a 300 s timeout): HOLDS => nothing;
#                  VIOLATED => FINDING high data-integrity carrying the verdict
#                  line; anything else => COULD-NOT-INSPECT naming the verdict.
#     anchor:docs/zero-gap/anchor.json
#                  the tracked anchor. Absent => FINDING medium false-evidence
#                  (the strict verify returns rc 2 until it exists); present but
#                  not tracked (live mode) => FINDING medium false-evidence.
#   A producer's missing fields are the ones a sealed record carries: a recorded
#   timestamp, the before/after state fingerprint, the stream digests and the
#   chain seal. Nothing here RUNS a gate or a check: sealing is judged statically.
#
# POPULATION AND WHY (docs/zero-gap/sweep-classes.tsv row `unsealed-evidence`)
#   Every gate run by scripts/pre-push-gates.sh and every `check` row of
#   scripts/check-registry.tsv (all of them — the TSV row is binding; `exempt`,
#   `debt` and `scanroot` rows are not producers of PASS verdicts), matched
#   against the evidence chain. The gates and checks are the complete set of
#   producers of PASS verdicts (FR-014), so a producer with no sealed record is
#   an unsealed claim. The store and the anchor are the "sealed records of the
#   evidence chain" the producers are matched against, so they are two typed
#   population items of their own: that is where the absence findings live.
#   Tokens: gate:<id>, check:<id>, store:<path>, anchor:<path> (percent-encoded).
#   RUNNER FILES (where a sealing call is looked for): tracked `scripts/*.sh` and
#   everything tracked under `ops/`, EXCLUDING scripts/zero-gap-evidence.sh,
#   scripts/zero-gap-evidence-chain.sh (the adapter and its verifier, whose own
#   proofs call `record`) and scripts/zero-gap-class-*.sh (sweep classes and
#   their corpora are not runners). Corpus mode uses the same rule per case.
#
# USAGE (class contract, docs/zero-gap/README.md)
#   zero-gap-class-unsealed-evidence.sh --root <dir> --emit-population
#   zero-gap-class-unsealed-evidence.sh --root <dir>
#   zero-gap-class-unsealed-evidence.sh --root <dir> --corpus <dir>
#   zero-gap-class-unsealed-evidence.sh --prove-failure
#   Corpus mode: every immediate subdirectory of --corpus is one mini-root
#   ("case") laid out like a repository (scripts/pre-push-gates.sh,
#   scripts/check-registry.tsv, optional .remember/logs/zero-gap/evidence/ and
#   docs/zero-gap/anchor.json); locations are `<case>/<token>`, evidence refs
#   are REGULAR files relative to --corpus (store/anchor findings cite the
#   case's runner, else its registry, or the store's chain.jsonl); runner files are found with `find`, and the
#   "anchor tracked" test (a git property) is not applied.
#
# EXIT CODES (three-valued; a finding outranks an undetermined)
#   0  every producer is sealed, the store verifies HOLDS and the anchor is present
#      and tracked — over a non-empty producer population
#   1  at least one FINDING
#   2  could not determine: --root not a directory / not a git work tree, a
#      required tool missing, the runner or the registry absent, a non-literal
#      GATE_IDS entry, a check id over 200 characters, an EMPTY producer
#      population (never clean), or a store
#      whose verify did not decide. --emit-population exits 2 when the gate or
#      check population cannot be enumerated.
#
# MEASURED ON THE LIVE TREE (2026-09-26, fix round; the registry grows while the
#   class wave lands, so the check count moves): rc 1, 68 items, 68 findings —
#   8 high (every pre-push gate), 58 medium check rows, the store absent and the
#   anchor absent. Precision 68/68: `git grep -E 'zero-gap-evidence\.sh.?\s+record'`
#   over the runner files returns nothing, the store and anchor paths do not exist,
#   so every finding is real and all share one root cause (nothing feeds sealed
#   records yet: T065).
#
# WHAT IT DOES NOT SEE (§11.4.6)
#   - Static only: a sealing call reached through a helper function, a variable
#     holding the adapter path, `eval`, or a runner outside the RUNNER FILES is
#     not credited (the producer is reported unsealed — a visible false positive,
#     never a false clean). A `--check-id` computed at run time (`"$id"`) is
#     never credited for a check; per-gate sealing inside run_gate IS credited
#     because run_gate runs every gate.
#   - A string that merely CONTAINS `zero-gap-evidence.sh record` on an
#     executable line (e.g. inside an echo) would be credited: the reader strips
#     comments (quote-aware) and joins backslash continuations, it does not parse
#     bash. Multi-line quoted strings are not tracked across lines.
#   - It does not match individual sidecar records to producers (no check_id
#     convention for gates exists yet), so a runner that is sealed in source but
#     never ran leaves no trace here; the store verdict covers the chain as a
#     whole.
#   - Part 4 (anchor history) of the chain verify is NEVER run: it fetches from a
#     remote and writes a private ref, which a read-only sweep must not do. The
#     verify therefore runs with a COPY of the anchor under TMPDIR and
#     --allow-untracked-anchor (parts 1-3: chain, sidecar, anchor); the
#     "tracked" property of the anchor is checked separately with git ls-files.
#
# SIDE EFFECTS
#   Writes only under $TMPDIR (a private mktemp dir, removed on exit). When a
#   store is present the verifier binaries are built offline by the chain script
#   into that dir with GOCACHE and XDG_CONFIG_HOME redirected into it (unless
#   ZG_CHAIN_BIN / ZG_INTEGRITY_BIN name prebuilt binaries); the verify takes a
#   SHARED flock on the store directory and reads it. No network, no fetch, no
#   write into --root, no background process.
#
# DEPENDENCIES
#   bash, git, gawk/awk, od, sort, sha256sum, cut, find, xargs, mktemp, timeout;
#   for a present store: scripts/zero-gap-evidence-chain.sh (+ go, unless prebuilt
#   binaries are given).
#
# REGISTRATION
#   scripts/check-registry.tsv row `zero-gap-class-unsealed-evidence`
#   (flag --prove-failure, undet-probe `--root /nonexistent`); corpus
#   _tests/fixtures/zero-gap/unsealed-evidence/.
set -uo pipefail
export LC_ALL=C LANG=C
unset CDPATH

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
HERE="$(dirname "$SELF")"
LIVE_ROOT="$(cd "$HERE/.." && pwd)"
CORPUS_REL="_tests/fixtures/zero-gap/unsealed-evidence"
CHAIN="$HERE/zero-gap-evidence-chain.sh"
CLASS=unsealed-evidence
RUNNER_REL=scripts/pre-push-gates.sh
REGISTRY_REL=scripts/check-registry.tsv
STORE_REL=.remember/logs/zero-gap/evidence
ANCHOR_REL=docs/zero-gap/anchor.json
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
VERIFY_TIMEOUT=300
MAX_ID=200   # a registry check id longer than this is COULD-NOT-INSPECT (a 1 MB id once made grep fail)
# A sealing call: the adapter path followed by its `record` subcommand.
ADRE='zero-gap-evidence[.]sh["'"'"']?[[:space:]]+record([[:space:]]|$)'

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root)
            [ $# -ge 2 ] || { echo "unsealed-evidence: --root needs a value" >&2; exit 2; }
            ROOT=$2; shift 2 ;;
        --corpus)
            [ $# -ge 2 ] || { echo "unsealed-evidence: --corpus needs a value" >&2; exit 2; }
            CORPUS=$2; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "unsealed-evidence: unknown argument: $1" >&2; exit 2 ;;
    esac
done

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

# LOGICAL_AWK: physical lines -> logical lines. A comment (a `#` at the start of
# a word, outside quotes) is dropped; a trailing backslash joins the next line.
# Per-file state resets at FNR == 1. Needs -v SQ="'".
LOGICAL_AWK='
function strip(s,   i, n, c, q, out, prev) {
    q = ""; out = ""; prev = " "; n = length(s)
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q == "") {
            if (c == "#" && prev ~ /[[:space:];&|(]/) break
            if (c == "\\") { out = out c substr(s, i + 1, 1); prev = "x"; i++; continue }
            if (c == SQ || c == "\"") q = c
        } else if (q == "\"" && c == "\\") { out = out c substr(s, i + 1, 1); prev = "x"; i++; continue }
        else if (c == q) q = ""
        out = out c; prev = c
    }
    return out
}
FNR == 1 { if (acc != "") print acc; acc = "" }
{
    l = strip($0)
    if (acc != "") l = acc " " l
    if (l ~ /\\$/) { acc = substr(l, 1, length(l) - 1); next }
    acc = ""
    print l
}
END { if (acc != "") print acc }'

# CHECKID_AWK: logical lines -> the literal --check-id values of sealing calls.
CHECKID_AWK='
$0 ~ re {
    s = $0
    while (match(s, /--check-id(=|[[:space:]]+)[^[:space:];|&)]+/)) {
        tok = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/^--check-id(=|[[:space:]]+)/, "", tok)
        if (length(tok) >= 2 && substr(tok, 1, 1) == SQ && substr(tok, length(tok), 1) == SQ) tok = substr(tok, 2, length(tok) - 2)
        else if (tok ~ /^"[^"$`\\]*"$/) tok = substr(tok, 2, length(tok) - 2)
        if (tok ~ /^[A-Za-z0-9._:+@,=-]+$/) print tok
    }
}'

# fn_body <file> <name> -> the physical lines of function <name> (definition line
# included; a one-line definition is its own body). Empty when not defined.
fn_body() {
    awk -v name="$2" '
        !inb && $0 ~ ("^[[:space:]]*(function[[:space:]]+)?" name "[[:space:]]*\\(\\)") {
            print; inb = 1
            if ($0 ~ /\{.*\}[[:space:]]*;?[[:space:]]*$/) exit
            next
        }
        inb { print; if ($0 ~ /^\}/) exit }' "$1"
}
fn_line() {
    awk -v name="$2" '$0 ~ ("^[[:space:]]*(function[[:space:]]+)?" name "[[:space:]]*\\(\\)") { print NR; exit }' "$1"
}
# sealed_text: stdin physical lines -> rc 0 when a logical line is a sealing call.
sealed_text() {
    local t
    t=$(awk -v SQ="'" "$LOGICAL_AWK") || return 2
    grep -Eq -- "$ADRE" <<<"$t"
}

# ── output accumulation ──────────────────────────────────────────────────────
TMP="" FIND="" CNIF="" POP=""
setup_tmp() {
    TMP=$(mktemp -d) || return 2
    ZGU_TMP=$TMP
    trap 'rm -rf -- "$ZGU_TMP"' EXIT
    FIND="$TMP/find" CNIF="$TMP/cni" POP="$TMP/pop"
    : >"$FIND"; : >"$CNIF"; : >"$POP"
}
add_find() { # sev cat loc desc ref
    local d=${4//[[:cntrl:]]/ }
    printf 'FINDING %s %s %s %s %s %s\n' "$CLASS" "$1" "$2" "$3" "$d" "$5" >>"$FIND"
}
add_cni() { # part reason
    local d=${2//[[:cntrl:]]/ }
    printf 'COULD-NOT-INSPECT %s %s\n' "$1" "$d" >>"$CNIF"
}
enc() { zg_pct_encode "$1"; }

# enumerate <base> <prefix-token> -> appends "kind<TAB>raw<TAB>line<TAB>token" rows
# to $TMP/items; sets ENUM_OK=0 when the gate or check population is incomplete.
ENUM_OK=1
enumerate() {
    local base=$1 pfx=$2 line ids w f
    local rpart="${pfx}$(enc "$RUNNER_REL")" gpart="${pfx}$(enc "$REGISTRY_REL")"
    f="$base/$RUNNER_REL"
    if [ ! -f "$f" ]; then
        add_cni "$rpart" "absent: the pre-push gate population cannot be enumerated"; ENUM_OK=0
    else
        line=$(grep -nE '^[[:space:]]*(readonly[[:space:]]+|declare[[:space:]]+-a[[:space:]]+)?GATE_IDS=\(' "$f" | head -n 1)
        if [ -z "$line" ] || ! [[ ${line#*:} =~ GATE_IDS=\(([^\)]*)\) ]]; then
            add_cni "$rpart" "no one-line literal GATE_IDS=(...) array: the pre-push gate population cannot be enumerated"; ENUM_OK=0
        else
            read -r -a ids <<<"${BASH_REMATCH[1]}"
            for w in ${ids[@]+"${ids[@]}"}; do
                w=${w#\"}; w=${w%\"}; w=${w#\'}; w=${w%\'}
                if [[ $w =~ ^[A-Za-z0-9_-]+$ ]]; then
                    printf 'gate\t%s\t%s\t%s\n' "$w" "$(fn_line "$f" "gate_$w")" "${pfx}gate:$(enc "$w")" >>"$TMP/items"
                else
                    add_cni "$rpart:${line%%:*}" "GATE_IDS entry is not a literal gate id, so the gate population is not statically known"; ENUM_OK=0
                fi
            done
            GATE_IDS_LINE=${line%%:*}
        fi
    fi
    f="$base/$REGISTRY_REL"
    if [ ! -f "$f" ]; then
        add_cni "$gpart" "absent: the check population cannot be enumerated"; ENUM_OK=0
    else
        awk -F'\t' '$1 == "check" { print NR "\t" $2 }' "$f" >"$TMP/chk" || { add_cni "$gpart" "unreadable"; ENUM_OK=0; }
        while IFS=$'\t' read -r line w; do
            if [ -z "$w" ]; then add_cni "$gpart:$line" "check row with an empty id"; ENUM_OK=0; continue; fi
            if [ "${#w}" -gt "$MAX_ID" ]; then add_cni "$gpart:$line" "check id longer than $MAX_ID characters: not inspected (the row is not a usable registry id)"; ENUM_OK=0; continue; fi
            printf 'check\t%s\t%s\t%s\n' "$w" "$line" "${pfx}check:$(enc "$w")" >>"$TMP/items"
        done <"$TMP/chk"
    fi
    printf 'store\t%s\t0\t%s\n' "$STORE_REL" "${pfx}store:$(enc "$STORE_REL")" >>"$TMP/items"
    printf 'anchor\t%s\t0\t%s\n' "$ANCHOR_REL" "${pfx}anchor:$(enc "$ANCHOR_REL")" >>"$TMP/items"
}

# runner_files <base> <mode> -> NUL-separated relative paths of the runner files
runner_files() {
    local base=$1 mode=$2
    if [ "$mode" = live ]; then
        git -C "$base" ls-files -z -- 'scripts/*.sh' 'ops/*'
    else
        ( cd "$base" && find scripts ops -type f \( -path 'scripts/*.sh' -o -path 'ops/*' \) -print0 2>/dev/null )
    fi | while IFS= read -r -d '' f; do
        case "$f" in
            scripts/zero-gap-evidence.sh|scripts/zero-gap-evidence-chain.sh|scripts/zero-gap-class-*.sh) continue ;;
        esac
        [ -f "$base/$f" ] && [ ! -L "$base/$f" ] && printf '%s\0' "$f"
    done
}

# verify_store <store dir> <anchor file> -> V_RC, V_LINE
verify_store() {
    local sd=$1 af=$2 v="$TMP/verify" out
    mkdir -p "$v/tmp" "$v/xdg"
    if [ -f "$af" ]; then cat -- "$af" >"$v/anchor.json" 2>/dev/null || rm -f -- "$v/anchor.json"; fi
    out=$( cd "$v" && GOCACHE="$v/gocache" XDG_CONFIG_HOME="$v/xdg" TMPDIR="$v/tmp" ZG_LOCK_TIMEOUT=30s \
        timeout --foreground -k 5 "$VERIFY_TIMEOUT" bash "$CHAIN" --verify "$sd" --anchor "$v/anchor.json" --allow-untracked-anchor 2>&1 </dev/null )
    V_RC=$?
    V_LINE=$(printf '%s\n' "$out" | grep '^VERDICT ' | tail -n 1)
    V_LINE=${V_LINE//[[:cntrl:]]/ }
}

# analyze <base> <prefix-token> <mode live|corpus> <ref-prefix> : judge every item of this base
analyze() {
    local base=$1 pfx=$2 mode=$3 rp=$4 kind raw line tok ngp=0 run_sealed=0 body ids
    # caseref: a REGULAR file of this corpus case for the store/anchor findings (the runner refuses a
    # directory as an evidence_ref): the case's runner, else its registry.
    local caseref="" cf
    for cf in "$RUNNER_REL" "$REGISTRY_REL"; do
        if [ -f "$base/$cf" ] && [ ! -L "$base/$cf" ]; then caseref="${rp}$(enc "$cf")"; break; fi
    done
    [ -n "$caseref" ] || caseref=${rp%/}
    : >"$TMP/items"; GATE_IDS_LINE=""
    enumerate "$base" "$pfx"
    # sealed check ids, from every runner file
    : >"$TMP/sealed"
    runner_files "$base" "$mode" >"$TMP/rf" || true
    if [ -s "$TMP/rf" ]; then
        ( cd "$base" && xargs -0 awk -v SQ="'" "$LOGICAL_AWK" <"$TMP/rf" ) >"$TMP/logical" 2>/dev/null
        awk -v SQ="'" -v re="$ADRE" "$CHECKID_AWK" "$TMP/logical" | LC_ALL=C sort -u >"$TMP/sealed"
    fi
    if [ -f "$base/$RUNNER_REL" ] && fn_body "$base/$RUNNER_REL" run_gate | sealed_text; then run_sealed=1; fi
    while IFS=$'\t' read -r kind raw line tok; do
        printf '%s\n' "$tok" >>"$POP"
        case "$kind" in
            gate)
                ngp=$((ngp + 1))
                [ -n "$line" ] || line=${GATE_IDS_LINE:-1}
                if [ "$run_sealed" -eq 1 ] || fn_body "$base/$RUNNER_REL" "gate_$raw" | sealed_text; then continue; fi
                add_find high false-evidence "$tok" \
                    "pre-push gate $raw produces no sealed evidence record: neither run_gate nor gate_$raw in $RUNNER_REL invokes scripts/zero-gap-evidence.sh record, so its PASS carries no recorded timestamp, no before/after state fingerprint, no stream digest and no chain seal" \
                    "${rp}$(enc "$RUNNER_REL"):$line" ;;
            check)
                ngp=$((ngp + 1))
                grep -qxF -- "$raw" "$TMP/sealed"; local grc=$?
                if [ "$grc" -eq 0 ]; then continue; fi
                if [ "$grc" -gt 1 ]; then add_cni "$tok" "the sealed-id comparison failed (grep rc $grc), so whether this check is sealed is not known"; continue; fi
                local etok; etok=$(enc "$raw")
                add_find medium false-evidence "$tok" \
                    "registered check $etok is sealed by no runner: no runner file invokes scripts/zero-gap-evidence.sh record with the literal --check-id $etok, so its PASS carries no recorded timestamp, no before/after state fingerprint, no stream digest and no chain seal" \
                    "${rp}$(enc "$REGISTRY_REL"):$line" ;;
            store)
                local sd="$base/$STORE_REL" sref
                if [ "$mode" = live ]; then sref=scripts/zero-gap-evidence.sh; else sref=$caseref; fi
                if [ ! -e "$sd" ] && [ ! -L "$sd" ]; then
                    add_find medium false-evidence "$tok" \
                        "no evidence store yet: $STORE_REL is absent, so no gate or check result in this tree has a sealed record (every PASS here is unsealed)" "$sref"
                elif [ ! -d "$sd" ] || [ -L "$sd" ]; then
                    add_find medium false-evidence "$tok" "the evidence store path $STORE_REL exists but is not a directory, so it holds no sealed record" "$sref"
                else
                    if [ "$mode" = live ]; then sref=scripts/zero-gap-evidence-chain.sh
                    elif [ -f "$sd/chain.jsonl" ] && [ ! -L "$sd/chain.jsonl" ]; then sref="${rp}$(enc "$STORE_REL/chain.jsonl")"; fi
                    verify_store "$sd" "$base/$ANCHOR_REL"
                    if [ "$V_RC" -eq 0 ] && [[ $V_LINE == 'VERDICT HOLDS '* ]]; then :
                    elif [ "$V_RC" -eq 1 ] && [[ $V_LINE == 'VERDICT VIOLATED '* ]]; then
                        add_find high data-integrity "$tok" "the evidence chain verify (parts 1-3, read-only) DETECTED an alteration of the store: $V_LINE" "$sref"
                    else
                        add_cni "$tok" "the evidence chain verify did not decide (rc $V_RC): ${V_LINE:-no VERDICT line}"
                    fi
                fi ;;
            anchor)
                local af="$base/$ANCHOR_REL" aref
                if [ "$mode" = live ]; then aref=scripts/zero-gap-evidence-chain.sh; else aref=$caseref; fi
                if [ ! -e "$af" ] && [ ! -L "$af" ]; then
                    add_find medium false-evidence "$tok" \
                        "the evidence anchor $ANCHOR_REL is absent: the strict chain verify (zero-gap-evidence-chain.sh --verify) returns rc 2 until it exists, so the completeness of the evidence chain is anchored by nothing" "$aref"
                elif [ "$mode" = live ] && ! git -C "$base" ls-files --error-unmatch -- "$ANCHOR_REL" >/dev/null 2>&1; then
                    add_find medium false-evidence "$tok" \
                        "the evidence anchor $ANCHOR_REL is present but not tracked: an untracked anchor can be rewritten to any lower entry count unseen, and the strict chain verify refuses it" "$aref"
                fi ;;
        esac
    done <"$TMP/items"
    if [ "$ENUM_OK" -eq 1 ] && [ "$ngp" -eq 0 ]; then
        if [ -n "$pfx" ]; then line=${pfx%/}; else line=-; fi
        add_cni "$line" "producer population is empty: no gate in GATE_IDS and no check row in $REGISTRY_REL — a class that inspects no producer is never clean"
    fi
}

finish() { # prints the report and exits with the agreeing code
    local n sha
    LC_ALL=C sort -u "$POP" >"$TMP/pop.s"
    n=$(awk 'END { print NR }' "$TMP/pop.s")
    sha=$(sha256sum <"$TMP/pop.s" | cut -d' ' -f1)
    LC_ALL=C sort -u "$FIND"
    LC_ALL=C sort -u "$CNIF"
    printf 'INSPECTED %s\nPOPULATION-SHA %s\n' "$n" "$sha"
    if [ -s "$FIND" ]; then exit 1; fi
    if [ -s "$CNIF" ]; then exit 2; fi
    exit 0
}

bail() { # part reason: could not start at all
    printf 'COULD-NOT-INSPECT %s %s\nINSPECTED 0\nPOPULATION-SHA %s\n' "$1" "$2" "$EMPTY_SHA"
    exit 2
}

main() {
    local t c cname
    for t in git awk od sort sha256sum cut find xargs mktemp grep; do
        command -v "$t" >/dev/null 2>&1 || { [ "$EMIT" -eq 1 ] && exit 2; bail - "required tool '$t' is not on PATH"; }
    done
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then [ "$EMIT" -eq 1 ] && exit 2; bail - "--root is not a directory"; fi
    ROOT=$(cd "$ROOT" && pwd) || bail - "--root cannot be entered"
    setup_tmp || { [ "$EMIT" -eq 1 ] && exit 2; bail - "mktemp failed"; }
    if [ -n "$CORPUS" ]; then
        [ -d "$CORPUS" ] || bail - "--corpus is not a directory"
        CORPUS=$(cd "$CORPUS" && pwd)
        ( cd "$CORPUS" && find . -mindepth 1 -maxdepth 1 -type d -print0 ) | LC_ALL=C sort -z >"$TMP/cases"
        while IFS= read -r -d '' c; do
            cname=${c#./}
            ENUM_OK=1
            analyze "$CORPUS/$cname" "$(enc "$cname")/" corpus "$(enc "$cname")/"
        done <"$TMP/cases"
        [ -s "$POP" ] || add_cni - "the corpus holds no case directory: nothing to inspect"
        finish
    fi
    if [ "$(git -C "$ROOT" rev-parse --is-inside-work-tree 2>/dev/null)" != true ]; then
        [ "$EMIT" -eq 1 ] && exit 2; bail - "--root is not a git work tree (the runner files are the TRACKED ones)"
    fi
    if [ "$EMIT" -eq 1 ]; then
        : >"$TMP/items"
        enumerate "$ROOT" ""
        [ "$ENUM_OK" -eq 1 ] || exit 2
        cut -f4 "$TMP/items" | LC_ALL=C sort -u
        exit 0
    fi
    analyze "$ROOT" "" live ""
    finish
}

# ── paired proof (§1.1): every case on THROWAWAY copies under mktemp ─────────
prove_failure() {
    local pass=0 fail=0 rc out bins live0 live1 st0 CO="$LIVE_ROOT/$CORPUS_REL"
    ok()  { pass=$((pass + 1)); printf '  PASS %s\n' "$1"; }
    bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }
    T=$(mktemp -d) || { echo "  UNDETERMINED: mktemp failed"; return 2; }
    ZGU_PROOF_TMP=$T
    trap 'rm -rf -- "$ZGU_PROOF_TMP"' EXIT
    # The live tree must be byte-identical around the whole proof.
    livefp() {
        { sha256sum -- "$SELF" "$LIVE_ROOT/scripts/pre-push-gates.sh"
          ( cd "$CO" && find . -type f -print0 | sort -z | xargs -0 sha256sum )
          for p in .remember/logs/zero-gap/evidence docs/zero-gap/anchor.json; do
              if [ -e "$LIVE_ROOT/$p" ]; then echo "present $p"; else echo "absent $p"; fi
          done; } 2>&1 | sha256sum | cut -d' ' -f1
    }
    live0=$(livefp)
    [ -d "$CO/planted" ] && [ -d "$CO/clean" ] && [ -f "$CO/expect.tsv" ] \
        || { echo "  UNDETERMINED: corpus $CORPUS_REL is incomplete"; return 2; }
    command -v git >/dev/null 2>&1 || { echo "  UNDETERMINED: git absent"; return 2; }
    # Prebuilt verifier binaries for speed (one case below runs WITHOUT them).
    mkdir -p "$T/bin" "$T/tmp"
    bins=$(GOCACHE="$T/gocache" TMPDIR="$T/tmp" bash "$HERE/zero-gap-evidence.sh" --build-bins "$T/bin" 2>"$T/build.err") \
        || { echo "  UNDETERMINED: verifier build failed: $(head -2 "$T/build.err" | tr '\n' ' ')"; return 2; }
    local CB=${bins%% *} IB=${bins##* }

    # K <out> <env-assignments...> -- <class args...>: run the class under env -i.
    K() {
        local o=$1; shift
        local envs=()
        while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
        mkdir -p "$T/ktmp"
        env -i PATH="$PATH" HOME="$HOME" TMPDIR="$T/ktmp" LC_ALL=C LANG=C ${envs[@]+"${envs[@]}"} \
            bash "$SELF" "$@" </dev/null >"$o" 2>"$o.err"
    }
    WB=("ZG_CHAIN_BIN=$CB" "ZG_INTEGRITY_BIN=$IB")
    finds() { awk '$1 == "FINDING" { print $5 }' "$1" | LC_ALL=C sort; }
    has()   { grep -qE -- "$2" "$1"; }

    # mkrepo <dir>: a throwaway git repository built from the clean corpus case.
    mkrepo() {
        rm -rf -- "$1"; mkdir -p "$1"
        cp -R "$CO/clean/sealed/." "$1/"
        git -C "$1" init -q && git -C "$1" add scripts docs &&
            git -C "$1" -c user.email=t@example.invalid -c user.name=t commit -qm fixture
    }
    commitall() { git -C "$1" add -A scripts docs 2>/dev/null; git -C "$1" -c user.email=t@example.invalid -c user.name=t commit -qam change >/dev/null 2>&1; true; }

    # C1 control: live mode on a sealed repository => rc 0, no finding, full population, SHA agrees.
    mkrepo "$T/r" || { echo "  UNDETERMINED: cannot build the scratch repository"; return 2; }
    st0=$( { git -C "$T/r" status --porcelain --ignored; find "$T/r" -path "$T/r/.git" -prune -o -type f -print0 | sort -z | xargs -0 sha256sum; } 2>&1 | sha256sum)
    K "$T/o1" "${WB[@]}" -- --root "$T/r"; rc=$?
    K "$T/p1" -- --root "$T/r" --emit-population; local prc=$?
    if [ "$rc" -eq 0 ] && ! has "$T/o1" '^(FINDING|COULD-NOT-INSPECT) ' && has "$T/o1" '^INSPECTED 7$' && [ "$prc" -eq 0 ] \
       && [ "$(awk '$1=="POPULATION-SHA"{print $2}' "$T/o1")" = "$(sha256sum <"$T/p1" | cut -d' ' -f1)" ] \
       && [ "$(wc -l <"$T/p1")" -eq 7 ]; then
        ok "C1 control: sealed repository => rc 0, 7 items inspected, POPULATION-SHA equals --emit-population"
    else bad "C1 control rc=$rc emit-rc=$prc: $(head -5 "$T/o1" | tr '\n' ' ')"; fi

    # C2/C3 corpus: planted => exactly the expect.tsv locations; clean => nothing.
    K "$T/o2" "${WB[@]}" -- --root "$T/r" --corpus "$CO/planted"; rc=$?
    grep -v '^#' "$CO/expect.tsv" | awk -F'\t' 'NF { print $1 }' | LC_ALL=C sort >"$T/exp"
    finds "$T/o2" >"$T/got2"
    if [ "$rc" -eq 1 ] && cmp -s "$T/exp" "$T/got2"; then ok "C2 planted corpus => rc 1, recall 1.0, no unexpected location ($(wc -l <"$T/exp") planted)"
    else bad "C2 planted corpus rc=$rc; diff: $(diff "$T/exp" "$T/got2" | tr '\n' ' ' | cut -c1-300)"; fi
    K "$T/o3" "${WB[@]}" -- --root "$T/r" --corpus "$CO/clean"; rc=$?
    if [ "$rc" -eq 0 ] && ! has "$T/o3" '^(FINDING|COULD-NOT-INSPECT) '; then ok "C3 clean corpus => rc 0, no finding"
    else bad "C3 clean corpus rc=$rc: $(grep -E '^(FINDING|COULD)' "$T/o3" | head -3 | tr '\n' ' ')"; fi

    # C21 every corpus evidence_ref names a REGULAR file inside the corpus (the runner refuses a directory
    # or an invented path; a refused ref makes the recall run UNKNOWN).
    local ref bad21=0 d21
    while IFS= read -r ref; do
        d21=${ref%%:*}; printf -v d21 '%b' "${d21//%/\\x}"
        [ -f "$CO/planted/$d21" ] && [ ! -L "$CO/planted/$d21" ] || { bad21=$((bad21 + 1)); echo "    non-file ref: $ref"; }
    done < <(awk '$1 == "FINDING" { print $NF }' "$T/o2")
    if [ "$bad21" -eq 0 ] && [ -s "$T/o2" ]; then ok "C21 every planted-corpus evidence_ref is a regular file inside the corpus"
    else bad "C21 $bad21 planted-corpus evidence_ref(s) are not regular files"; fi

    # C4 determinism: the same state gives the same bytes.
    K "$T/o4" "${WB[@]}" -- --root "$T/r" --corpus "$CO/planted"
    if cmp -s "$T/o2" "$T/o4"; then ok "C4 deterministic: two planted runs are byte-identical"
    else bad "C4 two planted runs differ"; fi

    # C5 an unsealed runner (live mode) => high false-evidence per gate.
    mkrepo "$T/r5" && cp "$CO/planted/unsealed/scripts/pre-push-gates.sh" "$T/r5/scripts/pre-push-gates.sh" && commitall "$T/r5"
    K "$T/o5" "${WB[@]}" -- --root "$T/r5"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o5" '^FINDING unsealed-evidence high false-evidence gate:E .* scripts/pre-push-gates\.sh:[0-9]+$' \
       && has "$T/o5" '^FINDING unsealed-evidence high false-evidence gate:0 ' && ! has "$T/o5" ' gate:1 '; then
        ok "C5 run_gate without the adapter => FINDING high false-evidence gate:E and gate:0 (evidence at the gate definition)"
    else bad "C5 unsealed runner rc=$rc: $(grep -E '^FINDING' "$T/o5" | head -3 | tr '\n' ' ')"; fi

    # C6 a commented-out adapter call in run_gate is NOT sealing.
    mkrepo "$T/r6"
    sed -i.bak 's|^    bash "\$ROOT/scripts/zero-gap-evidence.sh" record|    # bash "$ROOT/scripts/zero-gap-evidence.sh" record|' "$T/r6/scripts/pre-push-gates.sh" && rm -f "$T/r6/scripts/pre-push-gates.sh.bak"
    K "$T/o6" "${WB[@]}" -- --root "$T/r6"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o6" '^FINDING unsealed-evidence high false-evidence gate:1 '; then ok "C6 adapter call commented out in run_gate => gates unsealed (rc 1)"
    else bad "C6 commented adapter rc=$rc: $(head -3 "$T/o6" | tr '\n' ' ')"; fi

    # C7 a registry check no runner seals => medium false-evidence at check:<id>.
    mkrepo "$T/r7" && printf 'check\tunsealed-q\tscripts/q.sh\tflag\t--prove-failure\t--root /nonexistent\n' >>"$T/r7/scripts/check-registry.tsv" && commitall "$T/r7"
    K "$T/o7" "${WB[@]}" -- --root "$T/r7"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o7" '^FINDING unsealed-evidence medium false-evidence check:unsealed-q .* scripts/check-registry\.tsv:[0-9]+$' \
       && [ "$(grep -c '^FINDING' "$T/o7")" -eq 1 ]; then ok "C7 unsealed registry check => exactly one FINDING medium false-evidence check:unsealed-q"
    else bad "C7 unsealed check rc=$rc: $(grep -E '^FINDING' "$T/o7" | head -3 | tr '\n' ' ')"; fi

    # C8 a sealing line inside an excluded file (a class script) credits nothing.
    mkrepo "$T/r8" && printf 'check\tghost-seal\tscripts/g.sh\tflag\t--prove-failure\t--root /nonexistent\n' >>"$T/r8/scripts/check-registry.tsv"
    printf '#!/usr/bin/env bash\nbash scripts/zero-gap-evidence.sh record --check-id ghost-seal -- true\n' >"$T/r8/scripts/zero-gap-class-demo.sh"
    commitall "$T/r8"
    K "$T/o8" "${WB[@]}" -- --root "$T/r8"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o8" '^FINDING unsealed-evidence medium false-evidence check:ghost-seal '; then ok "C8 a sealing line inside scripts/zero-gap-class-*.sh is not a runner => check:ghost-seal unsealed"
    else bad "C8 excluded-file seal rc=$rc: $(head -3 "$T/o8" | tr '\n' ' ')"; fi

    # C9 store absent => ONE medium finding, no COULD-NOT-INSPECT for it.
    mkrepo "$T/r9" && rm -rf -- "$T/r9/.remember"
    K "$T/o9" "${WB[@]}" -- --root "$T/r9"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o9" '^FINDING unsealed-evidence medium false-evidence store:\.remember/logs/zero-gap/evidence .*no evidence store' \
       && ! has "$T/o9" '^COULD-NOT-INSPECT ' && [ "$(grep -c '^FINDING' "$T/o9")" -eq 1 ]; then ok "C9 store absent => exactly one FINDING medium (absence is the finding)"
    else bad "C9 store absent rc=$rc: $(head -4 "$T/o9" | tr '\n' ' ')"; fi

    # C10 anchor absent => medium finding; the strict verify cannot decide the store (named).
    mkrepo "$T/r10" && git -C "$T/r10" rm -q docs/zero-gap/anchor.json && commitall "$T/r10"
    K "$T/o10" "${WB[@]}" -- --root "$T/r10"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o10" '^FINDING unsealed-evidence medium false-evidence anchor:docs/zero-gap/anchor\.json .*absent' \
       && has "$T/o10" '^COULD-NOT-INSPECT store:\.remember/logs/zero-gap/evidence .*UNDETERMINED'; then
        ok "C10 anchor absent => FINDING medium anchor, store verify UNDETERMINED named (rc 1)"
    else bad "C10 anchor absent rc=$rc: $(head -4 "$T/o10" | tr '\n' ' ')"; fi

    # C11 anchor present but untracked => medium finding.
    mkrepo "$T/r11" && git -C "$T/r11" rm -q --cached docs/zero-gap/anchor.json \
        && git -C "$T/r11" -c user.email=t@example.invalid -c user.name=t commit -qm untrack
    K "$T/o11" "${WB[@]}" -- --root "$T/r11"; rc=$?
    if [ "$rc" -eq 1 ] && has "$T/o11" '^FINDING unsealed-evidence medium false-evidence anchor:docs/zero-gap/anchor\.json .*not tracked'; then
        ok "C11 anchor present but untracked => FINDING medium"
    else bad "C11 untracked anchor rc=$rc: $(head -4 "$T/o11" | tr '\n' ' ')"; fi

    # C12 a store written NOW by the real adapter (healthy => rc 0), then tampered => high data-integrity.
    mkrepo "$T/r12"; rm -rf -- "$T/r12/.remember"; rm -f -- "$T/r12/docs/zero-gap/anchor.json"
    mkdir -p "$T/w12" && git -C "$T/w12" init -q && printf 'x\n' >"$T/w12/f"
    local i st="$T/r12/.remember/logs/zero-gap/evidence" okrec=1
    for i in 1 2; do
        ( cd "$T" && ZG_CHAIN_BIN=$CB ZG_INTEGRITY_BIN=$IB ZG_SESSION_ID=proof-session TMPDIR="$T/tmp" \
            bash "$HERE/zero-gap-evidence.sh" record --store "$st" --streams "$T/tampered-streams" --fp-dir "$T/w12" \
            --item-id "ATM-00$i" --check-id "proof-c$i" --population-kind source --verdict-role author \
            --independence-tier instance --evidence-class runtime --verdict-exit -- /bin/sh -c 'exit 0' ) >>"$T/c12.log" 2>&1 || okrec=0
    done
    ( cd "$T" && ZG_CHAIN_BIN=$CB ZG_INTEGRITY_BIN=$IB TMPDIR="$T/tmp" bash "$HERE/zero-gap-evidence-chain.sh" --anchor-write "$st" \
        --anchor "$T/r12/docs/zero-gap/anchor.json" --unprobed ) >>"$T/c12.log" 2>&1 || okrec=0
    commitall "$T/r12"
    if [ "$okrec" -eq 1 ]; then
        K "$T/o12a" "${WB[@]}" -- --root "$T/r12"; rc=$?
        if [ "$rc" -eq 0 ] && ! has "$T/o12a" '^(FINDING|COULD-NOT-INSPECT) '; then ok "C12a store freshly written by the real adapter + anchor => rc 0 (HOLDS)"
        else bad "C12a fresh healthy store rc=$rc: $(head -3 "$T/o12a" | tr '\n' ' ')"; fi
        cp -R "$st" "$T/tampered"
        awk 'NR == 1 { sub(/"exit_status":0/, "\"exit_status\":1") } 1' "$st/sidecar.jsonl" >"$T/sc" && cat "$T/sc" >"$st/sidecar.jsonl"
        K "$T/o12b" "${WB[@]}" -- --root "$T/r12"; rc=$?
        if [ "$rc" -eq 1 ] && has "$T/o12b" '^FINDING unsealed-evidence high data-integrity store:\.remember/logs/zero-gap/evidence .*VIOLATED'; then
            ok "C12b the same store with one sidecar byte altered => FINDING high data-integrity (VIOLATED)"
        else bad "C12b tampered store rc=$rc: $(head -3 "$T/o12b" | tr '\n' ' ')"; fi
    else bad "C12 the real adapter could not write the scratch store: $(tail -3 "$T/c12.log" | tr '\n' ' ')"; fi

    # C13 an empty producer population => rc 2, never clean.
    mkrepo "$T/r13" && sed -i.bak 's/^GATE_IDS=(.*)$/GATE_IDS=()/' "$T/r13/scripts/pre-push-gates.sh" && rm -f "$T/r13/scripts/pre-push-gates.sh.bak"
    awk -F'\t' '$1 != "check"' "$T/r13/scripts/check-registry.tsv" >"$T/reg" && cat "$T/reg" >"$T/r13/scripts/check-registry.tsv" && commitall "$T/r13"
    K "$T/o13" "${WB[@]}" -- --root "$T/r13"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/o13" '^COULD-NOT-INSPECT ' && ! has "$T/o13" '^FINDING '; then ok "C13 zero gates and zero check rows => rc 2 COULD-NOT-INSPECT, never clean"
    else bad "C13 empty population rc=$rc: $(head -3 "$T/o13" | tr '\n' ' ')"; fi

    # C14 the runner or the registry absent => rc 2 (nothing to enumerate), also for --emit-population.
    mkrepo "$T/r14" && git -C "$T/r14" rm -q scripts/pre-push-gates.sh && commitall "$T/r14"
    K "$T/o14" "${WB[@]}" -- --root "$T/r14"; rc=$?
    K "$T/p14" -- --root "$T/r14" --emit-population; prc=$?
    if [ "$rc" -eq 2 ] && [ "$prc" -eq 2 ] && has "$T/o14" '^COULD-NOT-INSPECT scripts/pre-push-gates\.sh '; then ok "C14a runner absent => rc 2 (class and --emit-population)"
    else bad "C14a runner absent rc=$rc emit=$prc: $(head -3 "$T/o14" | tr '\n' ' ')"; fi
    mkrepo "$T/r14b" && git -C "$T/r14b" rm -q scripts/check-registry.tsv && commitall "$T/r14b"
    K "$T/o14b" "${WB[@]}" -- --root "$T/r14b"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/o14b" '^COULD-NOT-INSPECT scripts/check-registry\.tsv '; then ok "C14b registry absent => rc 2"
    else bad "C14b registry absent rc=$rc: $(head -3 "$T/o14b" | tr '\n' ' ')"; fi

    # C15 broken tools => rc 2: no git on PATH; no go and no prebuilt verifier with a store present.
    mkdir -p "$T/nogit"; local tool
    for tool in bash awk gawk od sort sha256sum cut find xargs mktemp grep dirname basename rm cat timeout mkdir tail head tr sed wc env go; do
        command -v "$tool" >/dev/null 2>&1 && ln -sf "$(command -v "$tool")" "$T/nogit/$tool"
    done
    K "$T/o15" "PATH=$T/nogit" -- --root "$T/r"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/o15" "^COULD-NOT-INSPECT - required tool 'git' is not on PATH"; then ok "C15a git not on PATH (every other tool present) => rc 2 naming git"
    else bad "C15a no git rc=$rc: $(head -3 "$T/o15" | tr '\n' ' ')"; fi
    K "$T/o15b" "ZG_GO=/nonexistent-zg-go" -- --root "$T/r"; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/o15b" '^COULD-NOT-INSPECT store:\.remember/logs/zero-gap/evidence .*UNDETERMINED'; then ok "C15b verifier cannot be built (no go) => store COULD-NOT-INSPECT, rc 2"
    else bad "C15b no go rc=$rc: $(head -3 "$T/o15b" | tr '\n' ' ')"; fi
    # C15c the class builds the verifier itself (no prebuilt binaries): the control still holds.
    K "$T/o15c" -- --root "$T/r"; rc=$?
    if [ "$rc" -eq 0 ] && ! has "$T/o15c" '^(FINDING|COULD-NOT-INSPECT) '; then ok "C15c without prebuilt binaries the class builds the verifier offline into TMPDIR => control rc 0"
    else bad "C15c self-built verifier rc=$rc: $(head -3 "$T/o15c" | tr '\n' ' ')"; fi

    # C16 --root /nonexistent => rc 2 (the registry undet-probe).
    K "$T/o16" -- --root /nonexistent; rc=$?
    if [ "$rc" -eq 2 ] && has "$T/o16" '^COULD-NOT-INSPECT '; then ok "C16 --root /nonexistent => rc 2"
    else bad "C16 --root /nonexistent rc=$rc"; fi

    # C19 a check id carrying U+202E (a direction override) is never printed raw: the runner rejects a whole
    # class output that carries one, so the location AND the description use the encoded token.
    mkrepo "$T/r19" && printf 'check\tbad%sid\tscripts/q.sh\tflag\t--prove-failure\t--root /nonexistent\n' "$(printf '\342\200\256')" >>"$T/r19/scripts/check-registry.tsv" && commitall "$T/r19"
    K "$T/o19" "${WB[@]}" -- --root "$T/r19"; rc=$?
    if [ "$rc" -eq 1 ] && ! LC_ALL=C grep -q "$(printf '\342\200\256')" "$T/o19" \
       && has "$T/o19" '^FINDING unsealed-evidence medium false-evidence check:bad%E2%80%AEid registered check bad%E2%80%AEid is sealed by no runner'; then
        ok "C19 U+202E in a registry id => encoded token in location and description, no raw override byte"
    else bad "C19 U+202E id rc=$rc: $(grep '^FINDING' "$T/o19" | head -2 | LC_ALL=C tr -c '[:print:]\n' '?' | tr '\n' ' ' | cut -c1-300)"; fi

    # C20 a 1 MB check id => COULD-NOT-INSPECT naming the row (id length capped), never read as unsealed.
    mkrepo "$T/r20" && { printf 'check\t'; head -c 1048576 /dev/zero | tr '\0' a; printf '\tscripts/q.sh\tflag\t--prove-failure\t--root /nonexistent\n'; } >>"$T/r20/scripts/check-registry.tsv" && commitall "$T/r20"
    K "$T/o20" "${WB[@]}" -- --root "$T/r20"; rc=$?
    K "$T/p20" -- --root "$T/r20" --emit-population; prc=$?
    if [ "$rc" -eq 2 ] && [ "$prc" -eq 2 ] && ! has "$T/o20" '^FINDING ' && has "$T/o20" '^COULD-NOT-INSPECT scripts/check-registry\.tsv:[0-9]+ .*longer than' \
       && [ "$(wc -c <"$T/o20")" -lt 4096 ]; then
        ok "C20 1 MB check id => rc 2 COULD-NOT-INSPECT naming the registry line (class and --emit-population), no finding, output small"
    else bad "C20 1 MB id rc=$rc emit=$prc bytes=$(wc -c <"$T/o20"): $(head -3 "$T/o20" | cut -c1-200 | tr '\n' ' ')"; fi

    # C17 no write into --root: the control repository is byte-identical after all runs above.
    if [ "$st0" = "$( { git -C "$T/r" status --porcelain --ignored; find "$T/r" -path "$T/r/.git" -prune -o -type f -print0 | sort -z | xargs -0 sha256sum; } 2>&1 | sha256sum)" ]; then
        ok "C17 the class wrote nothing into --root (control repository: git status and every file's sha256 unchanged)"
    else bad "C17 --root changed during the class runs"; fi

    live1=$(livefp)
    if [ "$live0" = "$live1" ]; then ok "C18 the live tree (class script, corpus, runner, store/anchor presence) is byte-identical before/after"
    else bad "C18 the live tree CHANGED during the proof"; fi

    printf 'unsealed-evidence --prove-failure: %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] && return 0 || return 1
}

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi
main
