#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# verify-directive-register.sh — prove that docs/directive-register.md is a
# HONEST record, not merely a present one.
#
# WHY THIS GATE EXISTS
# --------------------
# The operator has now asked THREE times that every directive be archived and
# regularly checked (workshop/docs/work-register.md rows R15, R22, R24, and again
# on 2026-09-05). Twice the answer was a DOCUMENT. A document is not a promise:
#
#     $ grep -c 'work-register\|instruction-audit\|directive' scripts/check-registry.tsv
#     0        # measured 2026-09-05, before this gate existed
#
# Nothing verified either register was complete or honest, so a row could rot, a
# directive could go unrecorded, and no instrument would notice. The operator's
# requirement is the CHECKING half — "ALWAYS regularly checked". This is it.
#
# WHAT IT ENFORCES — and each rule exists because its absence is a real failure
#   C1  the register exists and is readable
#   C2  every directive row carries a disposition from the FIXED vocabulary.
#       An invented disposition ("mostly done", "wip") is how a register stops
#       being machine-checkable, one well-meant row at a time.
#   C3  every DONE row names evidence. §11.4: every PASS carries positive
#       evidence. A DONE with an empty evidence cell is a bluff, and it is the
#       single most likely way this file would come to lie.
#   C4  no directive row has empty directive text — a row that records an id and
#       nothing else records nothing.
#   C5  at least one directive row exists at all. An empty register that passes
#       every other rule would be the most misleading possible green.
#
# WHAT IT DELIBERATELY DOES NOT ENFORCE, stated so the limit is not mistaken for
# a guarantee: it CANNOT know whether a directive the operator gave was ever
# written down. Nothing in this tree can — the prompts live outside it. This gate
# proves the register is internally honest; keeping it COMPLETE is a discipline,
# step 2 of the file's own "How to use" section. Do not read a green here as
# "every directive was captured".
#
# EXIT CODES (three-valued — 2 is NEVER a pass)
#   0  every rule passed
#   1  a real finding — a row violates C2..C5
#   2  could not determine — the root is not a readable directory, or the
#       register is absent. Nothing was judged, so this is not a pass.
#
# USAGE
#   bash scripts/verify-directive-register.sh
#   bash scripts/verify-directive-register.sh --root <dir>
#   bash scripts/verify-directive-register.sh --prove-failure    # §1.1 proof
# ------------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DEFAULT="$(cd -- "$HERE/.." && pwd -P)"
ROOT="$ROOT_DEFAULT"
REGISTER_REL="docs/directive-register.md"
MODE="verify"

# The vocabulary is FIXED here and documented in the register itself. If the two
# ever disagree, this list is the contract — a register may not invent a state.
VALID_DISPOSITIONS="DONE IN-PROGRESS OPEN BLOCKED STANDING SUPERSEDED"

while [ $# -gt 0 ]; do
    case "$1" in
        --root) shift; [ $# -gt 0 ] || { printf 'UNDETERMINED: --root needs an argument\n' >&2; exit 2; }; ROOT="$1" ;;
        --prove-failure) MODE="prove" ;;
        -h|--help) sed -n '2,52p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

log()  { printf '>> %s\n' "$*"; }
fail() { printf 'FINDING: %s\n' "$*" >&2; }

# ---- the analysis, factored so --prove-failure can run it over a fixture ------
# Returns 0 clean, 1 finding, 2 undetermined. Prints its own reasons.
analyse() {
    local root="$1" reg="$1/$REGISTER_REL"
    local findings=0 rows=0

    [ -d "$root" ] || { printf 'UNDETERMINED: not a readable directory: %s\n' "$root" >&2; return 2; }
    [ -r "$reg" ]  || { printf 'UNDETERMINED: register absent or unreadable: %s\n' "$reg" >&2; return 2; }

    # Directive rows are table rows whose first cell is a directive id: D<digits>,
    # optionally suffixed (D012-CONFLICT is prose, not a directive row, and is
    # excluded by requiring the id to be ONLY digits after the D).
    local line id text disp evid
    while IFS= read -r line; do
        id="$(printf '%s' "$line"   | awk -F'|' '{print $2}' | tr -d ' ')"
        text="$(printf '%s' "$line" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')"
        disp="$(printf '%s' "$line" | awk -F'|' '{print $4}' | tr -d ' `')"
        evid="$(printf '%s' "$line" | awk -F'|' '{print $5}' | sed 's/^ *//;s/ *$//')"

        rows=$((rows + 1))

        # C4 — a row with an id and no text records nothing.
        if [ -z "$text" ]; then
            fail "C4 $id has an empty directive text"
            findings=$((findings + 1))
        fi

        # C2 — the disposition must be one of the fixed vocabulary. A disposition
        # cell may carry a trailing qualifier ("STANDING — one exception found"),
        # so the FIRST token is what is matched.
        local first_tok
        first_tok="$(printf '%s' "$disp" | awk '{print $1}' | cut -d'—' -f1 | tr -d ' ')"
        case " $VALID_DISPOSITIONS " in
            *" $first_tok "*) : ;;
            *) fail "C2 $id has disposition '$first_tok', which is not in the fixed vocabulary ($VALID_DISPOSITIONS)"
               findings=$((findings + 1)) ;;
        esac

        # C3 — a DONE row without evidence is a bluff (§11.4).
        if [ "$first_tok" = "DONE" ] && [ -z "$evid" ]; then
            fail "C3 $id is DONE but names no evidence — §11.4 requires positive evidence for every PASS"
            findings=$((findings + 1))
        fi
    done < <(grep -E '^\| *D[0-9]+ *\|' "$reg")

    # C5 — an empty register passing everything else would be the worst green.
    if [ "$rows" -eq 0 ]; then
        fail "C5 the register contains no directive rows at all"
        return 1
    fi

    if [ "$findings" -gt 0 ]; then
        printf 'CM-DIRECTIVE-REGISTER: %d row(s) examined, %d finding(s)\n' "$rows" "$findings"
        return 1
    fi
    printf 'CM-DIRECTIVE-REGISTER: %d row(s) examined, 0 finding(s)\n' "$rows"
    return 0
}

# ---- §1.1 paired-failure proof ------------------------------------------------
# Every mutation is DATA, never a code edit: the gate under test is the real one,
# run unmodified against a deliberately broken copy of the register. A proof that
# edits the checker proves nothing about the checker that ships.
prove() {
    local caught=0 total=0 missed=0
    # NOT `local`: the EXIT trap fires after this function has returned, so a
    # local would be out of scope and `set -u` would report it as unbound —
    # leaking the temp dir AND printing an error after an otherwise clean pass.
    # The trap body is DOUBLE-quoted so the path is baked in when the trap is
    # SET, not resolved when it fires.
    PROVE_TMP="$(mktemp -d)" || { printf 'UNDETERMINED: no writable temp dir\n' >&2; exit 2; }
    trap "rm -rf '$PROVE_TMP'" EXIT
    local tmp="$PROVE_TMP"
    mkdir -p "$tmp/docs"

    # CONTROL — a healthy fixture must still PASS. This is the half with teeth:
    # a gate that fails everything would "catch" every mutation and be useless.
    {
        echo '| # | Directive | Disposition | Evidence |'
        echo '|---|---|---|---|'
        echo '| D001 | a real directive | `DONE` | proven by scripts/x.sh exit 0 |'
        echo '| D002 | another directive | `OPEN` | not started |'
    } > "$tmp/docs/directive-register.md"
    if analyse "$tmp" >/dev/null 2>&1; then
        printf 'PROVE: control PASSES on a healthy fixture (uncounted, and the half with teeth)\n'
    else
        printf 'PROVE: CONTROL FAILED — the gate rejects a healthy register; it is not trustworthy\n' >&2
        return 1
    fi

    # M1 — an invented disposition.
    total=$((total + 1))
    sed 's/`OPEN`/`mostly-done`/' "$tmp/docs/directive-register.md" > "$tmp/docs/m1.md"
    cp "$tmp/docs/m1.md" "$tmp/docs/directive-register.md.bak"
    mv "$tmp/docs/m1.md" "$tmp/docs/directive-register.md"
    if analyse "$tmp" >/dev/null 2>&1; then
        printf 'PROVE: M1 MISSED — an invented disposition was not caught\n' >&2
        missed=$((missed + 1))
    else
        printf 'PROVE: M1 caught — invented disposition rejected\n'; caught=$((caught + 1))
    fi
    mv "$tmp/docs/directive-register.md.bak" "$tmp/docs/directive-register.md"

    # M2 — DONE with no evidence. The bluff this gate exists to stop.
    total=$((total + 1))
    sed 's/| `DONE` | proven by scripts\/x.sh exit 0 |/| `DONE` |  |/' \
        "$tmp/docs/directive-register.md" > "$tmp/docs/m2.md"
    cp "$tmp/docs/directive-register.md" "$tmp/docs/directive-register.md.bak"
    mv "$tmp/docs/m2.md" "$tmp/docs/directive-register.md"
    if analyse "$tmp" >/dev/null 2>&1; then
        printf 'PROVE: M2 MISSED — a DONE row with no evidence was not caught\n' >&2
        missed=$((missed + 1))
    else
        printf 'PROVE: M2 caught — DONE without evidence rejected\n'; caught=$((caught + 1))
    fi
    mv "$tmp/docs/directive-register.md.bak" "$tmp/docs/directive-register.md"

    # M3 — a row with an empty directive text.
    total=$((total + 1))
    sed 's/| a real directive |/|  |/' "$tmp/docs/directive-register.md" > "$tmp/docs/m3.md"
    cp "$tmp/docs/directive-register.md" "$tmp/docs/directive-register.md.bak"
    mv "$tmp/docs/m3.md" "$tmp/docs/directive-register.md"
    if analyse "$tmp" >/dev/null 2>&1; then
        printf 'PROVE: M3 MISSED — an empty directive text was not caught\n' >&2
        missed=$((missed + 1))
    else
        printf 'PROVE: M3 caught — empty directive text rejected\n'; caught=$((caught + 1))
    fi
    mv "$tmp/docs/directive-register.md.bak" "$tmp/docs/directive-register.md"

    # M4 — a register with no directive rows (C5).
    total=$((total + 1))
    printf '# empty register\n\nno rows here\n' > "$tmp/docs/directive-register.md"
    if analyse "$tmp" >/dev/null 2>&1; then
        printf 'PROVE: M4 MISSED — an empty register was not caught\n' >&2
        missed=$((missed + 1))
    else
        printf 'PROVE: M4 caught — empty register rejected\n'; caught=$((caught + 1))
    fi

    # M5 — the rc-2 arm must be ARGV-reachable and must PRINT its state, and it
    # must not be the unknown-argument arm. A missing register is the real rc-2.
    total=$((total + 1))
    rm -f "$tmp/docs/directive-register.md"
    local out rc
    out="$(analyse "$tmp" 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'UNDETERMINED' <<<"$out"; then
        printf 'PROVE: M5 caught — absent register returns rc 2 and prints UNDETERMINED\n'
        caught=$((caught + 1))
    else
        printf 'PROVE: M5 MISSED — absent register gave rc %s without an UNDETERMINED line\n' "$rc" >&2
        missed=$((missed + 1))
    fi

    printf 'PROVE: %d mutations, %d caught, %d missed\n' "$total" "$caught" "$missed"
    [ "$missed" -eq 0 ] || return 1
    return 0
}

if [ "$MODE" = "prove" ]; then
    prove; exit $?
fi

log "register: $ROOT/$REGISTER_REL"
analyse "$ROOT"
rc=$?
case "$rc" in
    0) printf 'RESULT 0 CLEAN — every directive row carries a valid disposition, and every DONE names evidence\n' ;;
    1) printf 'RESULT 1 FINDING — the register contains rows that are not honest; see the FINDING lines above\n' ;;
    2) printf 'RESULT 2 UNDETERMINED — nothing was judged. This is NOT a pass and NOT a failure.\n' ;;
esac
exit "$rc"
