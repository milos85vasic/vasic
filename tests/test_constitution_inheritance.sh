#!/usr/bin/env bash
# test_constitution_inheritance.sh — the consumer-side inheritance gate for the
# `vasic` umbrella.
#
# ── Purpose ──────────────────────────────────────────────────────────────────
# `submodules/constitution/README.md` -> "How to consume" -> step 4 states the
# contract this file implements:
#
#   "Every consuming project should ship a test that verifies the constitution
#    submodule is present, at the expected pinned revision, and that the
#    project's CLAUDE.md / AGENTS.md / QWEN.md / Constitution all reference the
#    submodule."
#
# The two reference implementations that step names (the ATMOSphere project's
# `test_constitution_inheritance.sh` and the Herald project's
# `tests/test_constitution_inheritance.sh`) are NOT present in this checkout and
# were not available to copy. This gate is therefore modeled on what the
# constitution itself ships and on the clauses those files are described as
# enforcing — every invariant below cites the clause or the shipped artifact it
# comes from, and nothing is asserted that the constitution does not require.
#
# It reuses, BY REFERENCE and never by copy (§11.4.28 / §11.4.177), the
# canonical §11.4.35 pointer predicate from
# `submodules/constitution/scripts/gates/lib/pointer_carrier.sh`, and the
# `cm_covenant_114_*_propagation.sh` gate family via their documented
# `--root <dir>` flag.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   tests/test_constitution_inheritance.sh [--root <project-root>] [--quiet]
#   tests/test_constitution_inheritance.sh --prove-failure [--quiet]
#     --root <dir>      project root to check (default: this script's parent
#                       dir, i.e. the repository root). Mirrors the house
#                       convention every gate under
#                       submodules/constitution/scripts/gates/ uses, and lets
#                       --prove-failure point this SAME gate at a disposable
#                       mutated COPY so the real tree is never touched
#                       (§11.4.84 quiescence by construction).
#     --quiet           suppress per-invariant PASS lines (FAIL/SKIP always shown)
#     --prove-failure   run the paired §1.1 mutation proof: build a throwaway
#                       COPY of the governance surface, assert the gate PASSes
#                       on it unmutated (golden-good control), then apply four
#                       single-point mutations one at a time and assert the gate
#                       FAILs on each. A gate that cannot be made to fail "is a
#                       sham and must be rewritten" (§1.1).
#
# ── Inputs ───────────────────────────────────────────────────────────────────
#   <root>/{CLAUDE,AGENTS,QWEN,GEMINI,Constitution}.md   — the five carriers
#   <root>/submodules/constitution/**                     — the canonical root
#   The gate family + shared predicate are always resolved from the REAL
#   submodule (they are the instrument; only the specimen is ever copied).
#
# ── Outputs ──────────────────────────────────────────────────────────────────
#   One PASS / FAIL / SKIP line per invariant + a summary line.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   None on the repository. --prove-failure writes ONLY inside a `mktemp -d`
#   sandbox that is trap-removed on EXIT/INT/TERM. No file in this repository
#   and no file in ANY submodule working tree is ever written, and no git
#   command that mutates anything is ever run.
#
#   Deliberately NOT invoked: `submodules/constitution/meta_test_inheritance.sh`.
#   That harness mutates the REAL `submodules/constitution/Constitution.md` in
#   place and restores it afterwards. Invariant I6's mutation (M3 below) applies
#   that same mutation — deleting the `### §11.4 ` anchor line — to a COPY
#   instead, so this gate is proven non-bluff against the identical regression
#   without writing into a submodule working tree.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, POSIX cp/grep/find/awk, git (read-only, for I2 only). bash -n clean.
#
# ── Cross-references ─────────────────────────────────────────────────────────
#   §1.1 (paired mutation — a gate that cannot FAIL is a sham), §11.4.35
#   (canonical root / consumer extensions / invariant 6 pointer-or-import),
#   §11.4.157 (five-carrier lockstep, GEMINI.md INCLUDED), §11.4.28 / §11.4.177
#   (inherited by reference, never copied), §11.4.3 (SKIP with reason),
#   §11.4.201(7)(b) (a null result is not evidence until the instrument is
#   proven to see — invariant I7), §11.4.84 (quiescence: mutate a copy).
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0 — every invariant holds (default mode), or every mutation was caught and
#       the golden-good control passed (--prove-failure).
#   1 — at least one invariant FAILed, or a mutation did NOT make the gate fail
#       (i.e. this gate is a bluff gate), or the golden-good control failed.
#   2 — environment error (root not found, canonical predicate unreadable,
#       gate family not found).

set -uo pipefail

GATE="CM-CONSTITUTION-INHERITANCE"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

root="${REPO_ROOT}"
quiet=""
prove=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  root="${2:-}"; shift 2 ;;
        --quiet) quiet="1"; shift ;;
        --prove-failure) prove="1"; shift ;;
        -h|--help) sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "${GATE}: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

[ -n "$root" ] && [ -d "$root" ] || { echo "${GATE}: project root not found: '${root}'" >&2; exit 2; }
root="$(cd "$root" && pwd)"

# The INSTRUMENT always comes from the real submodule — only the SPECIMEN is
# ever a copy. Resolving the gate family relative to $root would let a mutated
# sandbox supply its own (possibly mutated) gates, which would be circular.
GATES_DIR="${REPO_ROOT}/submodules/constitution/scripts/gates"
PC_LIB="${GATES_DIR}/lib/pointer_carrier.sh"

[ -r "$PC_LIB" ] || { echo "${GATE}: canonical pointer predicate not readable at ${PC_LIB}" >&2; exit 2; }
# shellcheck source=/dev/null
. "$PC_LIB"

CARRIERS_AGENT="CLAUDE.md AGENTS.md QWEN.md GEMINI.md"
CARRIERS_ALL="${CARRIERS_AGENT} Constitution.md"
SUBMODULE_REL="submodules/constitution"
# The exact line meta_test_inheritance.sh deletes to prove a consumer gate real.
SENTINEL_ANCHOR='### §11.4 End-user quality guarantee'

pass=0; fail=0; skip=0

ok()   { pass=$((pass+1)); [ -n "$quiet" ] || echo "✅ PASS  $1"; }
bad()  { fail=$((fail+1)); echo "❌ FAIL  $1"; }
skp()  { skip=$((skip+1)); echo "⏭ SKIP  $1"; }

# ── I1 — the constitution submodule is present and populated ────────────────
# §11.4.35: the files in the constitution submodule are the CANONICAL ROOT.
# An empty submodule directory means it was never initialised.
i1() {
    local missing="" f
    for f in Constitution.md CLAUDE.md AGENTS.md QWEN.md GEMINI.md find_constitution.sh; do
        if [ ! -s "${root}/${SUBMODULE_REL}/${f}" ]; then
            missing="${missing} ${SUBMODULE_REL}/${f}"
        fi
    done
    if [ -n "$missing" ]; then
        bad "I1 SUBMODULE-PRESENT — canonical root incomplete; missing or empty:${missing}"
    else
        ok "I1 SUBMODULE-PRESENT — canonical root complete at ${SUBMODULE_REL}/ (§11.4.35)"
    fi
}

# ── I2 — the submodule is at the revision this repository pinned ────────────
# README "How to consume" step 4: "at the expected pinned revision".
# The expected revision is the gitlink recorded in this repository's index.
i2() {
    if [ ! -e "${root}/.git" ]; then
        skp "I2 PINNED-REVISION — '${root}' is not a git worktree (no .git); cannot read the gitlink. Runs for real at the repository root."
        return
    fi
    local recorded head
    recorded="$(git -C "$root" ls-files -s -- "$SUBMODULE_REL" 2>/dev/null | awk '$1=="160000"{print $2}')"
    if [ -z "$recorded" ]; then
        bad "I2 PINNED-REVISION — no gitlink recorded for ${SUBMODULE_REL} in the index"
        return
    fi
    head="$(git -C "${root}/${SUBMODULE_REL}" rev-parse HEAD 2>/dev/null)"
    if [ -z "$head" ]; then
        bad "I2 PINNED-REVISION — ${SUBMODULE_REL} has no resolvable HEAD (submodule not initialised?)"
    elif [ "$head" = "$recorded" ]; then
        ok "I2 PINNED-REVISION — ${SUBMODULE_REL} HEAD == pinned gitlink ${recorded}"
    else
        bad "I2 PINNED-REVISION — ${SUBMODULE_REL} HEAD ${head} != pinned gitlink ${recorded}"
    fi
}

# ── I3 — all five carriers exist ────────────────────────────────────────────
# §11.4.157(A): "Every governance addition or edit MUST land in ALL FIVE
# carriers in lockstep: the canonical Constitution.md PLUS each per-agent
# mirror CLAUDE.md + AGENTS.md + QWEN.md + GEMINI.md".
i3() {
    local missing="" f
    for f in $CARRIERS_ALL; do
        [ -s "${root}/${f}" ] || missing="${missing} ${f}"
    done
    if [ -n "$missing" ]; then
        bad "I3 FIVE-CARRIERS — missing or empty at the project root:${missing} (§11.4.157)"
    else
        ok "I3 FIVE-CARRIERS — CLAUDE.md AGENTS.md QWEN.md GEMINI.md Constitution.md all present (§11.4.157)"
    fi
}

# ── I4 — every carrier carries the inheritance pointer ──────────────────────
# §11.4.35 invariant 6: the consumer's carrier MUST start with EITHER the
# native `@constitution/CLAUDE.md` import OR the portable
# `## INHERITED FROM ...` pointer block — the two are declared equivalent.
# Recognition uses the constitution's OWN predicate, sourced above.
i4() {
    local bad_list="" f
    for f in $CARRIERS_ALL; do
        [ -s "${root}/${f}" ] || { bad_list="${bad_list} ${f}(absent)"; continue; }
        if is_pointer_carrier "${root}/${f}"; then
            continue
        fi
        if grep -qE '^@[A-Za-z0-9_./-]*constitution/CLAUDE\.md[[:space:]]*$' "${root}/${f}"; then
            continue
        fi
        bad_list="${bad_list} ${f}"
    done
    if [ -n "$bad_list" ]; then
        bad "I4 POINTER-INHERITANCE — no '## INHERITED FROM ' heading and no native @import in:${bad_list} (§11.4.35 inv. 6)"
    else
        ok "I4 POINTER-INHERITANCE — all five carriers open with a real, non-fenced '## INHERITED FROM ' heading (§11.4.35 inv. 6)"
    fi
}

# ── I5 — every carrier actually references the submodule ────────────────────
# README "How to consume" step 4: the carriers must "reference the submodule".
# This repository's real path is submodules/constitution/, not constitution/.
i5() {
    local bad_list="" f
    for f in $CARRIERS_ALL; do
        [ -s "${root}/${f}" ] || { bad_list="${bad_list} ${f}(absent)"; continue; }
        grep -qF "${SUBMODULE_REL}/" "${root}/${f}" || bad_list="${bad_list} ${f}"
    done
    if [ -n "$bad_list" ]; then
        bad "I5 SUBMODULE-REFERENCED — carriers with no '${SUBMODULE_REL}/' reference:${bad_list}"
    else
        ok "I5 SUBMODULE-REFERENCED — all five carriers name '${SUBMODULE_REL}/'"
    fi
}

# ── I6 — the inherited corpus still carries the §11.4 anchor ────────────────
# This is the exact assertion submodules/constitution/meta_test_inheritance.sh
# mutates to decide whether a consumer's gate is a bluff gate. Asserting it here
# is what makes this gate answer that harness honestly.
i6() {
    local f="${root}/${SUBMODULE_REL}/Constitution.md"
    if [ ! -s "$f" ]; then
        bad "I6 ANCHOR-PRESENT — ${SUBMODULE_REL}/Constitution.md missing or empty"
    elif grep -qF "$SENTINEL_ANCHOR" "$f"; then
        ok "I6 ANCHOR-PRESENT — '${SENTINEL_ANCHOR}' present in the inherited corpus"
    else
        bad "I6 ANCHOR-PRESENT — '${SENTINEL_ANCHOR}' MISSING from ${SUBMODULE_REL}/Constitution.md — the inherited corpus was weakened"
    fi
}

# ── I7 — the predicate is not blind (control needle) ────────────────────────
# §11.4.201(7)(b): a null result is not evidence until the instrument is proven
# to see. I4 rests entirely on is_pointer_carrier, so prove it first.
i7() {
    local out rc
    out="$(bash "$PC_LIB" --selftest 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "I7 PREDICATE-NOT-BLIND — pointer_carrier.sh --selftest: $(printf '%s' "$out" | tail -n1)"
    else
        bad "I7 PREDICATE-NOT-BLIND — pointer_carrier.sh --selftest FAILED (rc=${rc}); I4's verdict is untrustworthy"
        printf '%s\n' "$out" | sed 's/^/        /'
    fi
}

# ── I8 — the root carriers pass the constitution's own propagation gates ────
# Every cm_covenant_114_*_propagation.sh gate takes `--root <consumer-root>` and
# discovers carriers by filename beneath it. Pointing them at a directory that
# contains ONLY this project's four root carriers scopes the assertion to the
# carriers this gate owns — carriers belonging to third-party repositories
# reachable from the umbrella are out of scope here by construction, and are
# reported (still failing) by scripts/verify-all-constitution-rules.sh instead.
i8() {
    local gates tmp g n gpass=0 gfail=0 failed=""
    gates="$(find "$GATES_DIR" -maxdepth 1 -type f -name 'cm_covenant_114_*_propagation.sh' 2>/dev/null | sort)"
    if [ -z "${gates//[$' \t\r\n']/}" ]; then
        bad "I8 PROPAGATION-GATES — no cm_covenant_114_*_propagation.sh found under ${GATES_DIR}"
        return
    fi
    tmp="$(mktemp -d)" || { bad "I8 PROPAGATION-GATES — mktemp -d failed"; return; }
    for n in $CARRIERS_AGENT; do
        [ -s "${root}/${n}" ] && cp "${root}/${n}" "${tmp}/${n}"
    done
    if [ -z "$(find "$tmp" -maxdepth 1 -type f -name '*.md' -print -quit)" ]; then
        rm -rf "$tmp"
        bad "I8 PROPAGATION-GATES — no root agent carrier could be staged from ${root}"
        return
    fi
    while IFS= read -r g; do
        [ -n "$g" ] || continue
        if bash "$g" --root "$tmp" --quiet >/dev/null 2>&1; then
            gpass=$((gpass+1))
        else
            gfail=$((gfail+1)); failed="${failed} $(basename "$g")"
        fi
    done <<< "$gates"
    rm -rf "$tmp"
    if [ "$gfail" -gt 0 ]; then
        bad "I8 PROPAGATION-GATES — ${gfail}/$((gpass+gfail)) FAILed on the root carriers:${failed}"
    else
        ok "I8 PROPAGATION-GATES — ${gpass}/${gpass} cm_covenant_114_*_propagation gates PASS on the root carriers"
    fi
}

run_invariants() {
    [ -n "$quiet" ] || echo "${GATE}: checking ${root}"
    i7; i1; i2; i3; i4; i5; i6; i8
    echo "----------------------------------------------------------------------"
    echo "${GATE}: ${pass} PASS, ${skip} SKIP, ${fail} FAIL  (root ${root})"
    if [ "$fail" -gt 0 ]; then
        echo "❌ ${GATE}: FAIL — ${fail} invariant(s) violated"
        return 1
    fi
    echo "✅ ${GATE}: PASS — constitution inheritance is wired"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired §1.1 mutation proof. Every mutation is applied to a COPY inside a
# mktemp sandbox; the real tree and every submodule working tree are untouched.
# ─────────────────────────────────────────────────────────────────────────────
build_sandbox() {
    local dest="$1" n
    mkdir -p "${dest}/${SUBMODULE_REL}" || return 1
    for n in $CARRIERS_ALL; do
        cp "${REPO_ROOT}/${n}" "${dest}/${n}" || return 1
    done
    for n in Constitution.md CLAUDE.md AGENTS.md QWEN.md GEMINI.md find_constitution.sh; do
        cp "${REPO_ROOT}/${SUBMODULE_REL}/${n}" "${dest}/${SUBMODULE_REL}/${n}" || return 1
    done
    return 0
}

prove_failure() {
    local sandbox rc mut_fails=0 label
    sandbox="$(mktemp -d)" || { echo "${GATE}: mktemp -d failed" >&2; exit 2; }
    trap 'rm -rf "$sandbox"' EXIT INT TERM

    echo "${GATE} §1.1 PAIRED MUTATION PROOF"
    echo "  sandbox: ${sandbox}   (every mutation below is applied to a COPY;"
    echo "  neither this repository nor any submodule working tree is written to)"
    echo "----------------------------------------------------------------------"

    local pristine="${sandbox}/pristine"
    if ! build_sandbox "$pristine"; then
        echo "${GATE}: could not build the sandbox copy" >&2; exit 2
    fi

    # ── Golden-good control ─────────────────────────────────────────────────
    # Without this, "the mutations failed" proves nothing: the sandbox itself
    # could have been failing for an unrelated reason.
    bash "$0" --root "$pristine" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "✅ CONTROL golden-good  — unmutated sandbox copy PASSes (rc=0)"
    else
        echo "❌ CONTROL golden-good  — unmutated sandbox copy FAILED (rc=${rc}); the proof below would be meaningless"
        bash "$0" --root "$pristine" 2>&1 | sed 's/^/        /'
        trap - EXIT INT TERM; rm -rf "$sandbox"
        return 1
    fi

    # Each mutation: fresh copy of the pristine sandbox, one single-point edit,
    # re-run THIS gate against it, assert non-zero.
    mutate_and_assert() {
        local name="$1" desc="$2" targets_inv="$3"; shift 3
        local dir="${sandbox}/mut_${name}"
        rm -rf "$dir"; cp -r "$pristine" "$dir" || { echo "❌ ${name} — could not copy sandbox"; mut_fails=$((mut_fails+1)); return; }
        if ! "$@" "$dir"; then
            echo "❌ ${name} — could not apply the mutation (${desc})"
            mut_fails=$((mut_fails+1)); return
        fi
        bash "$0" --root "$dir" --quiet >/dev/null 2>&1; local mrc=$?
        if [ "$mrc" -ne 0 ]; then
            echo "✅ ${name} — ${desc} -> gate FAILed (rc=${mrc}), as it must  [${targets_inv}]"
        else
            echo "❌ ${name} — ${desc} -> gate still returned 0. THIS GATE IS A BLUFF GATE (§1.1)."
            mut_fails=$((mut_fails+1))
        fi
        rm -rf "$dir"
    }

    m1() { local d="$1"; grep -v '^## INHERITED FROM ' "${d}/CLAUDE.md" > "${d}/CLAUDE.md.new" && mv "${d}/CLAUDE.md.new" "${d}/CLAUDE.md"; }
    m2() { local d="$1"; rm -f "${d}/GEMINI.md"; }
    m3() { local d="$1"; grep -vF "$SENTINEL_ANCHOR" "${d}/${SUBMODULE_REL}/Constitution.md" > "${d}/C.new" && mv "${d}/C.new" "${d}/${SUBMODULE_REL}/Constitution.md"; }
    m4() { local d="$1"; : > "${d}/${SUBMODULE_REL}/GEMINI.md"; }

    mutate_and_assert "M1 pointer-stripped " "root CLAUDE.md loses its '## INHERITED FROM ' pointer heading" "I4 + I8" m1
    mutate_and_assert "M2 carrier-deleted  " "root GEMINI.md deleted (five-carrier lockstep broken)         " "I3 + I4 + I5" m2
    mutate_and_assert "M3 anchor-deleted   " "'### §11.4 ...' anchor deleted from the inherited corpus      " "I6" m3
    mutate_and_assert "M4 canonical-emptied" "submodules/constitution/GEMINI.md emptied (canonical root gap)" "I1" m4

    trap - EXIT INT TERM; rm -rf "$sandbox"
    echo "----------------------------------------------------------------------"
    if [ "$mut_fails" -eq 0 ]; then
        echo "✅ ${GATE} §1.1 MUTATION PROOF: PASS — control passed and all 4 mutations were caught"
        return 0
    fi
    echo "❌ ${GATE} §1.1 MUTATION PROOF: FAIL — ${mut_fails} mutation(s) not caught"
    return 1
}

if [ -n "$prove" ]; then
    prove_failure
    exit $?
fi

run_invariants
exit $?
