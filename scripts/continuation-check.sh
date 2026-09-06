#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# CONTINUATION.md staleness detector — Constitution §12.10 enforcement.
#
# WHY THIS EXISTS
# ---------------
# §12.10 makes CONTINUATION.md a "sacred invariant": it "must always reflect the
# live state of the project", it "MUST update ... in the same commit as the work
# itself", and "stale timestamps trigger gate failure". A hand-written status
# file satisfies none of that on its own — it is correct for exactly as long as
# nobody changes anything. This script is the machine that keeps it honest.
#
# It never asserts that a string is present. Every check compares a CLAIM the
# document makes against OBSERVED state — git history, the filesystem, the live
# gate runner's own gate table, the mounted constitution's §12.10 body, and the
# four governance carriers. A document that merely mentions the right words but
# describes a tree that no longer exists FAILS here.
#
#   bash scripts/continuation-check.sh [repo-root]
#   bash scripts/continuation-check.sh --list           # print the checks, run none
#   bash scripts/continuation-check.sh --prove-failure  # paired §1.1 mutation proof
#   bash scripts/continuation-check.sh --help
#
# Exit 0 = in sync · 1 = drift detected · 2 = could not determine
# (the three-valued convention of scripts/lumen-index-doctor.sh). A check that
# cannot be performed is reported UNDET and forces exit 2 — it is NEVER counted
# as a pass (§11.4.3 / §11.4.6: absence of a gate is not a pass).
#
# NO HARDCODED PATHS (§ gate 0). The root is DERIVED from `git rev-parse
# --show-toplevel` with a BASH_SOURCE fallback, or taken from argv so the
# checker can be pointed at any checkout — including a throwaway one, which is
# how the rc=2 branch is proven without touching the live tree.
#
# NO `set -e`. Deliberate: this script must collect and NAME every drift, not
# abort on the first one. (`_tools/deploy-langs.sh` is the cautionary tale for
# `set -uo pipefail` without `-e` — every command's status here is handled
# explicitly.)
# ------------------------------------------------------------------------------
set -uo pipefail

# ------------------------------------------------------------------------------
# Resolve the target root (argv > git toplevel > this script's parent dir).
# ------------------------------------------------------------------------------
MODE="run"
TARGET=""
for arg in "$@"; do
    case "$arg" in
        --list)          MODE="list" ;;
        --prove-failure) MODE="prove" ;;
        --help|-h)       MODE="help" ;;
        -*)              printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
        *)               TARGET="$arg" ;;
    esac
done

if [[ -n "$TARGET" ]]; then
    ROOT="$(cd -- "$TARGET" 2>/dev/null && pwd)" || {
        printf 'UNDET  target root does not exist: %s\n' "$TARGET" >&2; exit 2; }
else
    SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2
    ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null)" \
        || ROOT="$(cd -- "$SELF_DIR/.." && pwd)" || exit 2
fi

DOC="$ROOT/CONTINUATION.md"
CARRIERS=(CLAUDE.md AGENTS.md QWEN.md GEMINI.md)

# ------------------------------------------------------------------------------
# Reporting
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi
N_PASS=0; N_DRIFT=0; N_UNDET=0; N_NOTE=0
pass()  { N_PASS=$((N_PASS+1));  printf '%sPASS%s   [%s] %s\n' "$G" "$N" "$1" "$2"; }
drift() { N_DRIFT=$((N_DRIFT+1)); printf '%sDRIFT%s  [%s] %s\n' "$R" "$N" "$1" "$2"; }
undet() { N_UNDET=$((N_UNDET+1)); printf '%sUNDET%s  [%s] %s\n' "$Y" "$N" "$1" "$2"; }
note()  { N_NOTE=$((N_NOTE+1));  printf 'NOTE   [%s] %s\n' "$1" "$2"; }

# Normalise a string to its alphanumeric skeleton, so quoting, markdown escapes
# and whitespace differences cannot mask (or fabricate) a mismatch.
norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'; }
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

CHECKS=(
"C1|§12.10 structure: Last-Updated / Synced-Commit / Authority-Root header fields parse, §0 'How to use this document' and §3 'Active work' sections exist, §3 is non-empty"
"C2|§12.10 quote fidelity: the 'Mandatory protections' block quoted in the document is still verbatim in the mounted constitution's §12.10 body"
"C3|§12.10 protection 2: no commit since Synced-Commit touched a watched governance file WITHOUT also touching CONTINUATION.md (Synced-Commit must be a real ancestor of HEAD)"
"C4|Gap register: every G-identifier status in §4 matches EVERY root carrier that mentions that gap, and no carrier-listed gap is missing from §4 (§11.4.157 lockstep folded in)"
"C5|Entry points exist: every repo-internal *.sh the document names is present and non-empty (references outside the tree are reported NOTE, never silently skipped)"
"C6|Entry points executable: every script the document invokes DIRECTLY (no 'bash '/'sh ' prefix) carries the executable bit"
"C7|Gate table: §6's gate ids and commands match the live runner's own table (scripts/pre-push-gates.sh --list), extracted from the runner, not restated"
"C8|Production facts (§5): root has no tracked active CI, ci.yml.disabled is still tracked, milosvasic.ru/.github/workflows/pages.yml is present, vasic.digital carries zero workflow files"
)

if [[ "$MODE" == "help" ]]; then
    sed -n '2,36p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi
if [[ "$MODE" == "list" ]]; then
    printf '%sCONTINUATION.md drift checks%s  (root: %s)\n\n' "$B" "$N" "$ROOT"
    for c in "${CHECKS[@]}"; do printf '  %-4s %s\n' "${c%%|*}" "${c#*|}"; done
    printf '\nExit 0 = in sync · 1 = drift detected · 2 = could not determine\n'
    exit 0
fi

# ------------------------------------------------------------------------------
# --prove-failure : the paired §1.1 mutation proof.
# Hardlink-backs-up the live document (§9), seeds each violation class, asserts
# the checker catches it and NAMES it, then restores and re-verifies byte
# equality plus a clean run. Restores on any exit path.
# ------------------------------------------------------------------------------
if [[ "$MODE" == "prove" ]]; then
    [[ -f "$DOC" ]] || { printf 'UNDET  no CONTINUATION.md at %s\n' "$ROOT" >&2; exit 2; }
    BK="$(mktemp -d)/CONTINUATION.md.bak"
    ln "$DOC" "$BK" 2>/dev/null || cp -p "$DOC" "$BK"
    SUM0="$(cksum < "$DOC")"
    restore() { cp -p "$BK" "$DOC"; }
    trap restore EXIT
    fails=0
    run_case() {                       # name | expect_rc | expect_substring
        local name="$1" want="$2" needle="$3" out rc
        out="$(bash "${BASH_SOURCE[0]}" "$ROOT" 2>&1)"; rc=$?
        if [[ "$rc" == "$want" ]] && printf '%s' "$out" | grep -qF -- "$needle"; then
            printf '%sPROOF OK%s   %-34s rc=%s and named: %s\n' "$G" "$N" "$name" "$rc" "$needle"
        else
            printf '%sPROOF FAIL%s %-34s rc=%s (wanted %s) needle=%s\n' "$R" "$N" "$name" "$rc" "$want" "$needle"
            fails=$((fails+1))
        fi
    }
    printf '%s=== paired mutation proof (§1.1) ===%s\n' "$B" "$N"
    run_case "baseline, unmutated" 0 "PASS"
    # M1 — flip a gap status the carriers pin.
    perl -0pi -e 's/^\| G4 \| PARTIAL \|/| G4 | CLOSED |/m' "$DOC"
    run_case "M1 gap status flipped" 1 "G4"
    restore
    # M2 — remove a named entry point from the document's reach by renaming it
    #      inside the document to one that does not exist on disk.
    perl -0pi -e 's{scripts/lumen-index-doctor\.sh}{scripts/lumen-index-doctor-GONE.sh}g' "$DOC"
    run_case "M2 named entry point missing" 1 "scripts/lumen-index-doctor-GONE.sh"
    restore
    # M3 — corrupt the top-of-file timestamp field (§12.10 protection 3).
    perl -0pi -e 's/^ {4}Last-Updated: .*$/    Last-Updated: not-a-timestamp/m' "$DOC"
    run_case "M3 timestamp unparseable" 1 "Last-Updated"
    restore
    # M4 — reword the quoted §12.10 protections so they no longer match upstream.
    perl -0pi -e 's/absence is a release blocker/absence is fine actually/' "$DOC"
    run_case "M4 §12.10 quote drifted" 1 "quote"
    restore
    # M5 — desynchronise the gate table from the live runner.
    perl -0pi -e 's{bash _tools/audit-hardcoding\.sh}{bash _tools/audit-NOTHING.sh}' "$DOC"
    run_case "M5 gate table desynced" 1 "gate"
    restore
    # M6 — §12.10 protection 2: rewind Synced-Commit past a commit that changed
    #      a watched governance file without touching CONTINUATION.md. Finds a
    #      real such commit in this repository's own history; skips honestly if
    #      the history does not contain one.
    old=""
    while read -r c; do
        [[ -n "$c" ]] || continue
        git -C "$ROOT" show --name-only --format= "$c" 2>/dev/null | grep -qx 'CONTINUATION.md' && continue
        old="$(git -C "$ROOT" rev-parse "${c}^" 2>/dev/null)"; [[ -n "$old" ]] && break
    done < <(git -C "$ROOT" log --format=%H -40 -- CLAUDE.md README.md scripts/pre-push-gates.sh 2>/dev/null)
    if [[ -n "$old" ]]; then
        perl -0pi -e "s/^ {4}Synced-Commit: .*\$/    Synced-Commit: $old/m" "$DOC"
        run_case "M6 unsynced governance commit" 1 "protection 2"
        restore
    else
        printf 'SKIP       %-34s no qualifying historical commit to rewind to (§11.4.3: stated, not silent)\n' "M6 unsynced commit"
    fi
    printf '\n%s=== rc=2 branch (could not determine) ===%s\n' "$B" "$N"
    # A STRUCTURALLY VALID document in an environment that cannot answer:
    # no git repository, no carriers, no constitution, no gate runner. Drift
    # correctly outranks undetermined, so the fixture must carry no drift at
    # all — otherwise this would prove rc=1, not rc=2.
    SCRATCH="$(mktemp -d)"
    cp -p "$BK" "$SCRATCH/CONTINUATION.md"
    out="$(bash "${BASH_SOURCE[0]}" "$SCRATCH" 2>&1)"; rc=$?
    if [[ "$rc" == 2 ]] && printf '%s' "$out" | grep -q 'UNDET'; then
        printf '%sPROOF OK%s   %-34s rc=2, %s UNDET line(s) (no git repo, no carriers, no constitution, no runner)\n' \
            "$G" "$N" "unanswerable environment" "$(printf '%s' "$out" | grep -c 'UNDET  ')"
    else
        printf '%sPROOF FAIL%s %-34s rc=%s (wanted 2)\n%s\n' "$R" "$N" "unanswerable environment" "$rc" "$out"; fails=$((fails+1))
    fi
    rm -rf "$SCRATCH"
    restore; trap - EXIT
    SUM1="$(cksum < "$DOC")"
    printf '\n%s=== restore ===%s\n' "$B" "$N"
    if [[ "$SUM0" == "$SUM1" ]]; then
        printf '%sPROOF OK%s   %-34s cksum %s unchanged\n' "$G" "$N" "document restored" "${SUM0%% *}"
    else
        printf '%sPROOF FAIL%s %-34s cksum %s -> %s\n' "$R" "$N" "document restored" "${SUM0%% *}" "${SUM1%% *}"; fails=$((fails+1))
    fi
    bash "${BASH_SOURCE[0]}" "$ROOT" >/dev/null 2>&1 && \
        printf '%sPROOF OK%s   %-34s rc=0 after restore\n' "$G" "$N" "clean run" || {
        printf '%sPROOF FAIL%s %-34s non-zero after restore\n' "$R" "$N" "clean run"; fails=$((fails+1)); }
    [[ $fails -eq 0 ]] && { printf '\n%sALL MUTATIONS CAUGHT%s\n' "$G$B" "$N"; exit 0; }
    printf '\n%s%s PROOF CASE(S) FAILED%s\n' "$R$B" "$fails" "$N"; exit 1
fi

# ==============================================================================
# RUN
# ==============================================================================
printf '%sCONTINUATION.md drift check%s  root=%s\n\n' "$B" "$N" "$ROOT"

if [[ ! -f "$DOC" ]]; then
    drift C1 "CONTINUATION.md is absent from the repository root — §12.10 protection 1 calls its absence a release blocker."
    printf '\n%s1 DRIFT%s\n' "$R$B" "$N"; exit 1
fi

# ---- C1 : structure -----------------------------------------------------------
hdr() { grep -m1 -E "^[[:space:]]*$1:[[:space:]]*" "$DOC" 2>/dev/null | sed -E "s/^[[:space:]]*$1:[[:space:]]*//" | tr -d '\r'; }
LAST_UPDATED="$(hdr Last-Updated)"
SYNCED="$(hdr Synced-Commit)"
AUTH_ROOT="$(hdr Authority-Root)"

c1_ok=1
if [[ -z "$LAST_UPDATED" ]]; then
    drift C1 "no 'Last-Updated:' field — §12.10 protection 3 requires a top-of-file timestamp."; c1_ok=0
elif ! date -u -d "$LAST_UPDATED" +%s >/dev/null 2>&1; then
    drift C1 "Last-Updated is not a parseable timestamp: '$LAST_UPDATED' (§12.10 protection 3)."; c1_ok=0
else
    lu="$(date -u -d "$LAST_UPDATED" +%s)"; now="$(date -u +%s)"
    if (( lu > now + 86400 )); then
        drift C1 "Last-Updated '$LAST_UPDATED' is in the future — the timestamp is fabricated, not observed."; c1_ok=0
    fi
fi
[[ -n "$SYNCED"    ]] || { drift C1 "no 'Synced-Commit:' field — nothing to measure staleness against."; c1_ok=0; }
[[ -n "$AUTH_ROOT" ]] || { drift C1 "no 'Authority-Root:' field — the constitution mount point is undeclared."; c1_ok=0; }

grep -qE '^#{1,3} §0 .*How to use this document' "$DOC" \
    || { drift C1 "§0 'How to use this document' section is missing (§12.10 protection 5)."; c1_ok=0; }
grep -qE '^#{1,3} §3 .*Active work' "$DOC" \
    || { drift C1 "§3 'Active work' section is missing (§12.10 protection 4)."; c1_ok=0; }

# §3 must carry substance, not a placeholder heading.
sec3="$(awk '/^#{1,3} §3 /{f=1;next} f&&/^#{1,3} §/{exit} f{print}' "$DOC" | tr -d '[:space:]')"
if [[ ${#sec3} -lt 40 ]]; then
    drift C1 "§3 'Active work' is empty or a stub (${#sec3} non-space chars) — §12.10 protection 4 requires every IN PROGRESS / BLOCKED item, resumable without conversation context."; c1_ok=0
fi
# The resumption prompt must be a real paste-ready block, not a promise of one.
prompt_lines="$(awk '/^#{1,3} §0 /{f=1} f&&/^#{1,3} §1 /{exit} f&&/^```/{b=!b;next} f&&b{print}' "$DOC" | wc -l)"
if [[ "$prompt_lines" -lt 5 ]]; then
    drift C1 "§0 carries no paste-ready resumption block (found $prompt_lines fenced lines) — §12.10 protection 5."; c1_ok=0
fi
[[ $c1_ok -eq 1 ]] && pass C1 "structure intact: Last-Updated='$LAST_UPDATED', Synced-Commit=${SYNCED:0:12}, §0 + §3 present, §3 carries ${#sec3} chars, resumption block ${prompt_lines} lines."

# ---- C2 : §12.10 quote fidelity ----------------------------------------------
CONST="$ROOT/${AUTH_ROOT:-submodules/constitution}/Constitution.md"
if [[ ! -f "$CONST" ]]; then
    if [[ -d "$ROOT/${AUTH_ROOT:-submodules/constitution}" ]]; then
        undet C2 "constitution submodule at '${AUTH_ROOT}' is present but uninitialised (no Constitution.md) — cannot verify the §12.10 quote. Run: git submodule update --init ${AUTH_ROOT}"
    else
        undet C2 "declared Authority-Root '${AUTH_ROOT}' does not exist under the root — cannot verify the §12.10 quote."
    fi
else
    anchor="$(awk '/^### §12\.10 /{f=1} f&&/^### §12\.11 /{exit} f{print}' "$CONST")"
    if [[ -z "$anchor" ]]; then
        drift C2 "anchor '### §12.10' no longer exists in $CONST — the document quotes a rule that moved or was renamed."
    else
        upstream="$(printf '%s' "$anchor" | awk '/^1\. \*\*/{f=1} f' )"
        quoted="$(awk '/^> /{print; g=1; next} g{exit}' "$DOC" | sed -E 's/^> ?//')"
        if [[ -z "$quoted" ]]; then
            drift C2 "the document quotes no §12.10 text — its binding requirements are asserted, not shown."
        elif [[ "$(norm "$upstream")" == *"$(norm "$quoted")"* ]]; then
            pass C2 "the quoted 'Mandatory protections' block is verbatim in $CONST §12.10."
        else
            drift C2 "the §12.10 quote in CONTINUATION.md no longer matches the mounted constitution's §12.10 body — upstream reworded the rule, or the quote was edited. Re-read: awk '/^### §12.10 /{f=1} f&&/^### §12.11 /{exit} f{print}' ${AUTH_ROOT}/Constitution.md"
        fi
    fi
fi

# ---- C3 : protection 2, same-commit sync -------------------------------------
if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    undet C3 "'$ROOT' is not a git repository — cannot measure staleness against history."
elif [[ -z "$SYNCED" ]]; then
    undet C3 "no Synced-Commit to measure from (see C1)."
elif ! git -C "$ROOT" cat-file -e "${SYNCED}^{commit}" 2>/dev/null; then
    drift C3 "Synced-Commit ${SYNCED:0:12} is not a commit in this repository — the document pins a state that does not exist."
elif ! git -C "$ROOT" merge-base --is-ancestor "$SYNCED" HEAD 2>/dev/null; then
    undet C3 "Synced-Commit ${SYNCED:0:12} is not an ancestor of HEAD (rebase, reset, or a detached branch) — the range is not meaningful; re-sync the document."
else
    WATCHED=()
    for w in "${CARRIERS[@]}" README.md helix-deps.yaml \
             docs/constitution-adoption/INVENTORY.md \
             scripts/pre-push-gates.sh .github/workflows/ci.yml.disabled; do
        [[ -e "$ROOT/$w" ]] && WATCHED+=("$w")
    done
    if [[ ${#WATCHED[@]} -eq 0 ]]; then
        undet C3 "none of the watched governance files exist — nothing to measure."
    else
        offenders=""
        while read -r c; do
            [[ -n "$c" ]] || continue
            if ! git -C "$ROOT" show --name-only --format= "$c" 2>/dev/null | grep -qx 'CONTINUATION.md'; then
                touched="$(git -C "$ROOT" show --name-only --format= "$c" 2>/dev/null | grep -Fx -f <(printf '%s\n' "${WATCHED[@]}") | tr '\n' ' ')"
                offenders+="    ${c:0:12} $(git -C "$ROOT" log -1 --format=%s "$c" 2>/dev/null) -> ${touched}"$'\n'
            fi
        done < <(git -C "$ROOT" log --format=%H "${SYNCED}..HEAD" -- "${WATCHED[@]}" 2>/dev/null)
        if [[ -n "$offenders" ]]; then
            drift C3 "commit(s) since Synced-Commit changed a watched governance file WITHOUT updating CONTINUATION.md in the same commit (§12.10 protection 2):"$'\n'"$offenders"
        else
            n=$(git -C "$ROOT" rev-list --count "${SYNCED}..HEAD" 2>/dev/null || echo '?')
            pass C3 "no unsynced governance commit: ${n} commit(s) since ${SYNCED:0:12}, none touched ${#WATCHED[@]} watched file(s) without also updating CONTINUATION.md."
        fi
    fi
fi

# ---- C4 : gap register agreement ---------------------------------------------
carrier_status() {                      # carrier-file gap-id  ->  status | ""
    local line rest
    line="$(grep -m1 -E "^- $2 — " "$ROOT/$1" 2>/dev/null)" || return 1
    [[ -n "$line" ]] || return 1
    rest="${line#*— }"
    case "$rest" in
        "PARTIALLY CLOSED"*) printf 'PARTIALLY CLOSED' ;;
        "PARTIALLY OPEN"*)   printf 'PARTIALLY OPEN' ;;
        CLOSED*)             printf 'CLOSED' ;;
        PARTIAL*)            printf 'PARTIAL' ;;
        RESOLVED*)           printf 'RESOLVED' ;;
        OPEN*)               printf 'OPEN' ;;
        BLOCKED*)            printf 'BLOCKED' ;;
        *)                   printf 'OPEN' ;;   # prose with no status token = still open
    esac
}

have_carrier=0
for c in "${CARRIERS[@]}"; do [[ -f "$ROOT/$c" ]] && have_carrier=1; done
if [[ $have_carrier -eq 0 ]]; then
    undet C4 "no governance carrier (${CARRIERS[*]}) exists under the root — the authoritative gap statuses cannot be read."
else
    declare -A DOCGAP=()
    while IFS='|' read -r _ g s _; do
        g="$(trim "$g")"; s="$(trim "$s")"
        [[ "$g" =~ ^G[0-9]+$ ]] || continue
        DOCGAP["$g"]="$(printf '%s' "$s" | tr '[:lower:]' '[:upper:]')"
    done < <(grep -E '^\|[[:space:]]*G[0-9]+[[:space:]]*\|' "$DOC")

    carrier_gaps=""
    for c in "${CARRIERS[@]}"; do
        [[ -f "$ROOT/$c" ]] || continue
        carrier_gaps+="$(grep -oE '^- G[0-9]+ —' "$ROOT/$c" 2>/dev/null | grep -oE 'G[0-9]+')"$'\n'
    done
    carrier_gaps="$(printf '%s' "$carrier_gaps" | grep -E '^G[0-9]+$' | sort -u)"

    if [[ ${#DOCGAP[@]} -eq 0 && -z "$carrier_gaps" ]]; then
        undet C4 "neither CONTINUATION.md nor any carrier exposes a parseable gap register — the format changed under both."
    elif [[ -z "$carrier_gaps" ]]; then
        undet C4 "no carrier exposes a parseable '- G<n> — <STATUS>' gap list — cannot confirm the ${#DOCGAP[@]} status(es) in §4."
    else
        c4_bad=0 c4_seen=0
        while read -r g; do
            [[ -n "$g" ]] || continue
            c4_seen=$((c4_seen+1))
            if [[ -z "${DOCGAP[$g]:-}" ]]; then
                drift C4 "gap $g is listed by a root carrier but is MISSING from CONTINUATION.md §4 — the register is behind the carriers."
                c4_bad=1; continue
            fi
            for c in "${CARRIERS[@]}"; do
                [[ -f "$ROOT/$c" ]] || continue
                st="$(carrier_status "$c" "$g")" || continue
                [[ -n "$st" ]] || continue
                if [[ "$st" != "${DOCGAP[$g]}" ]]; then
                    drift C4 "gap $g: CONTINUATION.md §4 says '${DOCGAP[$g]}', $c says '$st'. One of them is stale."
                    c4_bad=1
                fi
            done
        done <<< "$carrier_gaps"
        for g in "${!DOCGAP[@]}"; do
            grep -qx "$g" <<< "$carrier_gaps" && continue
            note C4 "gap $g is described in CONTINUATION.md §4 but no carrier lists it — its status has no authority behind it."
        done
        [[ $c4_bad -eq 0 ]] && pass C4 "all $c4_seen carrier-listed gap(s) agree with §4 across every carrier that mentions them."
    fi
fi

# ---- C5 / C6 : entry points ---------------------------------------------------
# Match the WHOLE path-ish token first, then keep only those that end exactly in
# `.sh`. The previous form anchored on `\.sh` with no right-hand boundary, so
# `upstreams/gitlab.sh.disabled` matched as `upstreams/gitlab.sh` — a path the
# document never names — and C5 reported DRIFT against it. That is not a corner
# case here: this repository deliberately neutralises files by appending
# `.disabled` (`ci.yml.disabled`, `upstreams/gitlab.sh.disabled`), so a truncating
# extractor manufactures a fresh false DRIFT every time one is mentioned, and a
# gate that cries wolf on its own conventions gets ignored.
#
# A `*.sh.disabled` is deliberately NOT treated as an entry point: it is a recipe
# that has been switched off on purpose, and asserting it is runnable would
# invert its meaning. Two greps rather than one lookahead, because `grep -oP` is
# GNU-only and this tree runs its scripts on BSD too.
mapfile -t SH_TOKENS < <(grep -oE '[A-Za-z_][A-Za-z0-9_.-]*(/[A-Za-z0-9_.-]+)+' "$DOC" \
                         | grep -E '\.sh$' | sort -u)
if [[ ${#SH_TOKENS[@]} -eq 0 ]]; then
    undet C5 "the document names no script paths at all — there are no entry points to verify."
    undet C6 "no entry points to test for executability."
else
    c5_bad=0; c5_n=0; c6_bad=0; c6_n=0
    for t in "${SH_TOKENS[@]}"; do
        seg="${t%%/*}"
        if [[ -e "$ROOT/$t" ]]; then
            if [[ -s "$ROOT/$t" ]]; then c5_n=$((c5_n+1)); else
                drift C5 "named entry point '$t' exists but is EMPTY — a zero-byte script is not a working entry point."; c5_bad=1
            fi
        elif [[ -e "$ROOT/$seg" ]]; then
            drift C5 "named entry point '$t' does not exist (its parent '$seg/' does) — the document points at a script that is gone or renamed."
            c5_bad=1
        else
            note C5 "'$t' resolves outside this tree ('$seg' is not a root entry) — treated as an external reference, NOT verified here."
            continue
        fi
        # C6: executable required only where the document invokes it directly.
        if grep -qE "(^|[^A-Za-z0-9_./-])\./${t//\//\\/}" "$DOC" 2>/dev/null; then
            c6_n=$((c6_n+1))
            if [[ ! -x "$ROOT/$t" ]]; then
                drift C6 "'$t' is invoked directly ('./$t') by the document but is NOT executable — the command it prints would fail."
                c6_bad=1
            fi
        fi
    done
    if [[ $c5_bad -eq 0 ]]; then
        if [[ $c5_n -eq 0 ]]; then
            undet C5 "every script path the document names resolved outside this tree — no entry point could be verified here. This is NOT a pass."
        else
            pass C5 "$c5_n repo-internal entry point(s) named by the document exist and are non-empty."
        fi
    fi
    if [[ $c6_bad -eq 0 ]]; then
        if [[ $c6_n -eq 0 ]]; then
            undet C6 "the document invokes no script directly ('./path.sh') — the executable-bit check had nothing to assert. This is NOT a pass."
        else
            pass C6 "$c6_n directly-invoked script(s) carry the executable bit."
        fi
    fi
fi

# ---- C7 : gate table vs the live runner --------------------------------------
RUNNER="$ROOT/scripts/pre-push-gates.sh"
if [[ ! -f "$RUNNER" ]]; then
    undet C7 "scripts/pre-push-gates.sh is absent — the live gate table cannot be read, so §6 cannot be confirmed."
else
    # Pull the runner's OWN gate table out of it and evaluate THAT, so §6 is
    # compared against the definition that actually runs — never against a copy
    # restated here. Only three shapes are lifted: GATE_IDS, gate_cmd_text(),
    # and single-quoted literal scalars (gate_cmd_text interpolates the
    # §11.4.156(E) probe regex). Anything with a command substitution, a
    # continuation, or a lowercase/mixed name is deliberately NOT lifted — it
    # could have side effects or clobber this script's own state.
    gsrc="$(awk "
        /^[A-Z][A-Z0-9_]*='[^']*'\$/ {print}
        /^GATE_IDS=\(/               {print}
        /^gate_cmd_text\(\)/,/^}/    {print}
    " "$RUNNER" 2>/dev/null)"
    if [[ -z "$gsrc" || "$gsrc" != *"GATE_IDS="* || "$gsrc" != *"gate_cmd_text"* ]]; then
        undet C7 "could not extract GATE_IDS / gate_cmd_text() from scripts/pre-push-gates.sh — the runner was refactored; this check needs updating before it can speak."
    else
        # Evaluate in a SUBSHELL and take only its printed id<TAB>command lines.
        RUNTABLE="$(
            eval "$gsrc" >/dev/null 2>&1 || exit 9
            for id in "${GATE_IDS[@]}"; do printf '%s\t%s\n' "$id" "$(gate_cmd_text "$id")"; done
        )"
        if [[ $? -ne 0 || -z "$RUNTABLE" ]]; then
            undet C7 "the extracted gate table from scripts/pre-push-gates.sh did not evaluate — cannot compare §6 against it."
        else
            declare -A RUNGATE=()
            RUN_IDS=()
            while IFS=$'\t' read -r rid rcmd; do
                [[ -n "$rid" ]] || continue
                RUNGATE["$rid"]="$rcmd"; RUN_IDS+=("$rid")
            done <<< "$RUNTABLE"
            declare -A DOCGATE=()
            while IFS='|' read -r _ gid gcmd _; do
                gid="$(trim "$gid")"; gcmd="$(trim "$gcmd")"
                [[ "$gid" =~ ^[A-Z0-9]$ ]] || continue
                DOCGATE["$gid"]="$gcmd"
            done < <(awk '/^#{1,3} §6 /{f=1;next} f&&/^#{1,3} §/{exit} f' "$DOC" | grep -E '^\|[[:space:]]*[A-Z0-9][[:space:]]*\|')
            c7_bad=0
            if [[ ${#DOCGATE[@]} -eq 0 ]]; then
                drift C7 "§6 exposes no parseable gate table, but the live runner defines ${#RUN_IDS[@]} gate(s) (${RUN_IDS[*]}) — the document does not tell anyone how to run them."
                c7_bad=1
            fi
            for id in "${RUN_IDS[@]}"; do
                if [[ -z "${DOCGATE[$id]:-}" ]]; then
                    drift C7 "gate '$id' exists in scripts/pre-push-gates.sh but is MISSING from CONTINUATION.md §6."
                    c7_bad=1; continue
                fi
                want="$(norm "${RUNGATE[$id]}")"
                got="$(norm "${DOCGATE[$id]}")"
                if [[ "$want" != "$got" && "$want" != *"$got"* && "$got" != *"$want"* ]]; then
                    drift C7 "gate '$id' command in §6 does not match the runner. runner: ${RUNGATE[$id]} | document: ${DOCGATE[$id]}"
                    c7_bad=1
                fi
            done
            for id in "${!DOCGATE[@]}"; do
                printf '%s\n' "${RUN_IDS[@]}" | grep -qx -- "$id" && continue
                drift C7 "§6 documents gate '$id', which the live runner does not define — the table describes a gate that no longer runs."
                c7_bad=1
            done
            [[ $c7_bad -eq 0 ]] && pass C7 "§6 matches the live runner: ${#RUN_IDS[@]} gate(s) (${RUN_IDS[*]}), ids and commands agree."
        fi
    fi
fi

# ---- C8 : production / CI facts ----------------------------------------------
if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    undet C8 "'$ROOT' is not a git repository — the §11.4.156 tracked-CI fact cannot be checked."
else
    c8_bad=0; c8_msgs=()
    active="$(git -C "$ROOT" ls-files | grep -E '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$' || true)"
    if [[ -n "$active" ]]; then
        drift C8 "an ACTIVE root CI config is tracked, contradicting §5/§6 gate E: $(printf '%s' "$active" | tr '\n' ' ')"; c8_bad=1
    else c8_msgs+=("root CI inert"); fi

    if grep -q 'ci\.yml\.disabled' "$DOC"; then
        if git -C "$ROOT" ls-files --error-unmatch .github/workflows/ci.yml.disabled >/dev/null 2>&1; then
            c8_msgs+=("ci.yml.disabled tracked")
        else
            drift C8 "the document cites '.github/workflows/ci.yml.disabled' as the preserved definition, but it is not tracked here."; c8_bad=1
        fi
    fi

    if grep -q 'milosvasic\.ru/\.github/workflows/pages\.yml' "$DOC"; then
        if [[ ! -d "$ROOT/milosvasic.ru/.git" && -z "$(ls -A "$ROOT/milosvasic.ru" 2>/dev/null)" ]]; then
            undet C8 "submodule milosvasic.ru is not initialised — cannot confirm pages.yml is still present. Run: git submodule update --init milosvasic.ru"
        elif [[ -f "$ROOT/milosvasic.ru/.github/workflows/pages.yml" ]]; then
            c8_msgs+=("milosvasic.ru pages.yml present (ACTIVE — production publish path)")
        else
            drift C8 "milosvasic.ru/.github/workflows/pages.yml is GONE. The document names it the sole publish path for the live site; if it was disabled or renamed, the production site stops updating."; c8_bad=1
        fi
    fi

    if grep -q 'vasic\.digital' "$DOC"; then
        if [[ -z "$(ls -A "$ROOT/vasic.digital" 2>/dev/null)" ]]; then
            undet C8 "submodule vasic.digital is not initialised — cannot confirm it still carries zero workflow files."
        else
            vd="$(find "$ROOT/vasic.digital/.github/workflows" -maxdepth 1 -name '*.yml' -o -maxdepth 1 -name '*.yaml' 2>/dev/null | wc -l)"
            if [[ "$vd" -eq 0 ]]; then c8_msgs+=("vasic.digital workflow-free")
            else drift C8 "vasic.digital now carries $vd workflow file(s); the document states it has zero (its non-compliance is provider-level, with no file-level remedy)."; c8_bad=1; fi
        fi
    fi
    if [[ $c8_bad -eq 0 && ${#c8_msgs[@]} -gt 0 ]]; then
        joined="$(printf '%s; ' "${c8_msgs[@]}")"
        pass C8 "production facts hold: ${joined%; }."
    fi
fi

# ------------------------------------------------------------------------------
printf '\n%s%d PASS · %d DRIFT · %d UNDET · %d NOTE%s\n' "$B" "$N_PASS" "$N_DRIFT" "$N_UNDET" "$N_NOTE" "$N"
if [[ $N_DRIFT -gt 0 ]]; then
    printf '%sCONTINUATION.md IS STALE%s — §12.10 requires it to be corrected in the same commit as the work that moved.\n' "$R$B" "$N"
    exit 1
fi
if [[ $N_UNDET -gt 0 ]]; then
    printf '%sUNDETERMINED%s — one or more checks could not be performed. This is NOT a pass (§11.4.3).\n' "$Y$B" "$N"
    exit 2
fi
printf '%sCONTINUATION.md IS IN SYNC%s\n' "$G$B" "$N"
exit 0
