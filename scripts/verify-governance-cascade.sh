#!/usr/bin/env bash
# verify-governance-cascade.sh — the §11.4.32 step-1 governance-cascade verifier
# for the `vasic` umbrella.
#
# ── Why this file exists ─────────────────────────────────────────────────────
# §11.4.32 ("Post-Constitution-Pull Validation Mandate",
# `submodules/constitution/Constitution.md:2026`) defines the validation-sweep
# contract, and its step 1 names this file verbatim:
#
#   "**Validation sweep contract.** The sweep is implemented as
#    `scripts/verify-all-constitution-rules.sh` (canonical name) which:
#     1. Re-runs the existing governance-cascade verifier (`scripts/
#        verify-governance-cascade.sh`) covering every §11.9 + CONST-*
#        anchor across every owned submodule (recursive per CONST-047)."
#
# Until this file existed, `scripts/verify-all-constitution-rules.sh` printed
#   "⏭ STEP1 SKIP — scripts/verify-governance-cascade.sh does not exist"
# which is a §11.4.3 reasoned skip, never a pass, and was tracked as open
# conflict OC-3. This file closes it. No edit to the sweep was needed: the
# sweep already resolves `${root}/scripts/verify-governance-cascade.sh` and
# runs it with no arguments when it is readable.
#
# ── What §11.4.32 step 1 literally asks for, and what is achievable ──────────
# Step 1's scope phrase is "every §11.9 + CONST-* anchor across every owned
# submodule (recursive per CONST-047)". Measured against the pinned corpus
# (`submodules/constitution/Constitution.md`, HEAD 448981ae…):
#
#   * There is NO `§11.9` section in the corpus. The string `§11.9` occurs
#     exactly once in the whole file — inside §11.4.32's own sentence above
#     (`grep -no '§11\.9[0-9.]*' Constitution.md` -> one hit, line 2047).
#   * There is NO `CONST-NNN` anchor SECTION either. Sixteen CONST ids are
#     referenced (CONST-035/038/042…054/061) but every one of them appears only
#     as a cross-reference, most often as an equivalence to a §11.4.x anchor
#     (e.g. "§11.4.30 / CONST-053", "§11.4.31 / CONST-054", "§11.4.28 /
#     CONST-051"). `grep -nE '^#+ .*CONST-'` finds no defining heading.
#
# So "enumerate every §11.9 + CONST-* anchor and check each one per submodule"
# is not implementable against THIS corpus — the anchor namespaces it names are
# not defined here. That is recorded as an honest boundary (§11.4.6) rather than
# faked with an invented anchor list.
#
# What IS implementable, and is what this file does, is the mechanism those
# anchors cascade THROUGH. Under §11.4.35 a consumer inherits the corpus BY
# POINTER — the whole corpus, not an enumerated subset (§11.4.28 / §11.4.177:
# "inherited by reference, never copied"). Therefore: proving that every owned
# submodule carries a real, resolvable pointer carrier IS proving that every
# anchor in the corpus — whatever its namespace — is in force there. A missing
# or non-pointer carrier is exactly the "cascade gap" §11.4.26 step 6 says
# "MUST be closed in the same change-window". That is the property checked here.
#
# ── Checks (each cites the clause it comes from) ─────────────────────────────
#   C0 PREDICATE-NOT-BLIND   the shared §11.4.35 predicate self-tests clean.
#                            §11.4.201(7)(b) — a null result is not evidence
#                            until the instrument is proven to see. C3 rests
#                            entirely on this predicate, so it is proven first.
#   C1 FLEET-CLASSIFIED      every `path =` in `.gitmodules` is classified
#                            owned / governance-source / third-party by the
#                            roster below, and every rostered root is still
#                            declared. An unclassified submodule is a cascade
#                            gap of unknown size (§11.4.26 step 6).
#   C2 OWNED-CARRIERS-PRESENT  every owned submodule carries all four agent
#                            carriers, non-empty (§11.4.157(A)+(D): the lockstep
#                            "binds the consuming project's repository-root
#                            context files"; §11.4.32 step 1 "every owned
#                            submodule").
#   C3 OWNED-CARRIERS-POINTER  each of those carriers is recognised by the
#                            canonical `is_pointer_carrier` predicate — a real,
#                            non-fenced, line-anchored `## INHERITED FROM `
#                            heading (§11.4.35 invariant 6). Reused BY REFERENCE
#                            from the constitution submodule; never reimplemented.
#   C4 THIRD-PARTY-EXCLUDED  third-party roots are excluded BY NAME and the
#                            exclusion is DOCUMENTED in `helix-deps.yaml`, not
#                            silently missed. §4 excludes "third-party
#                            submodules (libraries not under the project's
#                            control)"; §11.4.156(C) puts them out of CI scope.
#   C5 ROOT-LOCKSTEP         the umbrella's five root carriers exist, and the
#                            four agent mirrors are byte-identical from line
#                            ${LOCKSTEP_FROM} down (§11.4.157(B) "no silent
#                            drift"). The line-24 split is this project's chosen
#                            mechanism, recorded in `Constitution.md`'s header
#                            table and in `docs/constitution-adoption/README.md`
#                            §4 — §11.4.157 mandates lockstep but prescribes no
#                            particular proof, so the mechanism is ours, the
#                            requirement is the constitution's.
#   C6 MANIFEST-FLEET-SYNC   `helix-deps.yaml`'s recorded submodule set equals
#                            what `.gitmodules` declares, in BOTH directions.
#                            §11.4.31 mandates the manifest; a manifest that
#                            names a submodule the fleet no longer has (or
#                            misses one the fleet gained) means governance is
#                            tracking a fleet that does not exist.
#   C7 RECURSION             owned submodules' own `.gitmodules` (CONST-047 /
#                            §11.4.32's "deep recursively") are read and every
#                            nested gitlink is classified too.
#   R1 KNOWN-UNCLEARABLE     REPORTED, never failed on. Four governance carriers
#                            inside repositories this project does not own; no
#                            commit this project can make changes them. Full
#                            forensics in `docs/constitution-adoption/
#                            POST-APPLY-STATE.md` §3 and in `Constitution.md`
#                            -> "Known-excluded gate findings". A verifier that
#                            FAILs on what nobody can fix trains its readers to
#                            ignore it, so these are printed and excluded from
#                            the verdict — the propagation-gate family in
#                            `scripts/verify-all-constitution-rules.sh` still
#                            reports them as FAILs, so they are not suppressed
#                            anywhere, merely not double-counted here.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-governance-cascade.sh [--root <project-root>] [--quiet]
#   scripts/verify-governance-cascade.sh <project-root> [--quiet]
#   scripts/verify-governance-cascade.sh --prove-failure [--quiet]
#     --root <dir>     project root to verify (default: this script's parent
#                      directory). A bare positional <dir> means the same thing.
#                      Mirrors the convention of every gate under
#                      submodules/constitution/scripts/gates/ and of
#                      tests/test_constitution_inheritance.sh, and lets
#                      --prove-failure point this SAME verifier at a disposable
#                      mutated COPY so the real tree is never touched.
#     --quiet          suppress per-check PASS/NOTE lines. FAIL, ENV and the
#                      summary are ALWAYS shown.
#     --prove-failure  run the paired §1.1 mutation proof (see below).
#     -h|--help        this header.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   None. Default mode only reads. --prove-failure writes ONLY inside a
#   `mktemp -d` sandbox that is trap-removed on EXIT/INT/TERM. No file in this
#   repository and no file in ANY submodule working tree is ever written. No git
#   command is run at all — not even a read-only one — so there is nothing to
#   mutate. No sudo, no network.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, POSIX awk/grep/sed/cp/mkdir/find, sha256sum (coreutils). bash -n clean.
#
# ── Cross-references ─────────────────────────────────────────────────────────
#   §11.4.32 (this verifier is its step 1), §1.1 (paired mutation — a gate that
#   cannot FAIL is a sham), §11.4.35 (pointer inheritance + consumer supplies
#   its roster as DATA), §11.4.157 (five-carrier lockstep, GEMINI.md included),
#   §11.4.31 (helix-deps.yaml manifest), §11.4.28 / §11.4.177 (by reference,
#   never copied — hence the shared predicate is sourced, not re-typed),
#   §11.4.26 step 6 (cascade gaps close in the same change-window), §11.4.3
#   (SKIP/NOTE with a reason, never a silent pass), §11.4.6 (report the
#   verified state; the §11.9/CONST-* boundary above), §11.4.201(7)(b)
#   (a blind instrument is never a pass), §11.4.84 (quiescence: mutate a copy).
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0 — the cascade is intact: every check above holds.
#   1 — a REAL violation: a cascade gap, a lockstep break, a manifest desync,
#       or an unclassified fleet member.
#   2 — COULD NOT VERIFY: an environment or instrument problem (root missing,
#       constitution submodule not initialised, an owned submodule not checked
#       out, an unreadable file, the shared predicate failing its own self-test,
#       mktemp failing). An internal error is NEVER reported as 1 — a verifier
#       that cannot see must say so, not accuse the tree.
#       In --prove-failure: 0 = control passed and every mutation was caught;
#       1 = a mutation was NOT caught (this verifier would be a sham, §1.1);
#       2 = the sandbox could not be built.

set -uo pipefail

GATE="CM-GOVERNANCE-CASCADE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

root=""
quiet=""
prove=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  root="${2:-}"; shift 2 ;;
        --quiet) quiet="1"; shift ;;
        --prove-failure) prove="1"; shift ;;
        # Print the comment header and stop at the first line of code, so the
        # help can never bleed into the script body as the header grows.
        -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        -*) echo "${GATE}: unknown arg '$1'" >&2; exit 2 ;;
        *)  if [ -n "$root" ]; then
                echo "${GATE}: more than one target root given ('${root}', '$1')" >&2; exit 2
            fi
            root="$1"; shift ;;
    esac
done

[ -n "$root" ] || root="${REPO_ROOT}"
[ -d "$root" ] || { echo "${GATE}: project root not found: '${root}'" >&2; exit 2; }
root="$(cd "$root" && pwd)"

# ─────────────────────────────────────────────────────────────────────────────
# DATA — the fleet roster. §11.4.35 classification: universal rule, project
# literals supplied by the consumer as DATA. Sources, all verifiable:
#   owned            : `.gitmodules` urls under milos85vasic/ + vasic-digital/,
#                      and the `deps:` list in helix-deps.yaml.
#   governance source: `.gitmodules` -> HelixDevelopment/HelixConstitution.
#                      This is the HEAD of the cascade, not a consumer of it.
#   third-party      : `.gitmodules` -> WangX0111/superspec — outside every
#                      operator-listed org, recorded as such in the trailing
#                      comment block of helix-deps.yaml.
#   nested 3rd-party : milosvasic.ru/.gitmodules -> red-elf/Upstreamable.
# C1/C7 FAIL on any submodule path NOT in one of these lists, so the roster
# cannot silently go stale: a new gitlink is a FAIL until it is classified here.
# ─────────────────────────────────────────────────────────────────────────────
OWNED_ROOTS="ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital"
GOVERNANCE_ROOT="submodules/constitution"
THIRD_PARTY_ROOTS="submodules/superspec"
NESTED_THIRD_PARTY="milosvasic.ru/Upstreamable"

CARRIERS_AGENT="AGENTS.md CLAUDE.md QWEN.md GEMINI.md"
ROOT_CARRIERS="AGENTS.md CLAUDE.md QWEN.md GEMINI.md Constitution.md"
GOVERNANCE_FILES="Constitution.md AGENTS.md CLAUDE.md QWEN.md GEMINI.md"

# §11.4.157 lockstep mechanism: lines 1..23 of each root agent mirror are the
# per-agent header (title / base file named / which agent reads it); everything
# from line 24 down must be byte-identical. Recorded in Constitution.md's header
# table: "bodies byte-identical from line 24; verify with
# `tail -n +24 <file> | sha256sum`".
LOCKSTEP_FROM=24

# R1 — carriers inside repositories this project does not own. `path|owner`.
KNOWN_UNCLEARABLE="milosvasic.ru/Upstreamable/AGENTS.md|red-elf/Upstreamable (nested gitlink of milosvasic.ru)
milosvasic.ru/Upstreamable/CLAUDE.md|red-elf/Upstreamable (nested gitlink of milosvasic.ru)
submodules/superspec/examples/static-landing-page/CLAUDE.md|WangX0111/superspec (third-party submodule)
.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md|WangX0111/superspec (vendored spec-kit extension copy)"

# The INSTRUMENT always comes from the REAL submodule — only the SPECIMEN is
# ever a copy. Resolving the predicate relative to $root would let a mutated
# sandbox supply its own (possibly mutated) predicate, which is circular.
PC_LIB="${REPO_ROOT}/${GOVERNANCE_ROOT}/scripts/gates/lib/pointer_carrier.sh"
if [ ! -r "$PC_LIB" ]; then
    echo "${GATE}: ENV — canonical pointer predicate not readable at ${PC_LIB}" >&2
    echo "${GATE}: cannot verify. fix: git submodule update --init ${GOVERNANCE_ROOT}" >&2
    exit 2
fi
# shellcheck source=/dev/null
. "$PC_LIB"

pass=0; fail=0; envf=0; note=0

ok()   { pass=$((pass+1)); [ -n "$quiet" ] || echo "✅ PASS  $1"; }
bad()  { fail=$((fail+1)); echo "❌ FAIL  $1"; }
env_() { envf=$((envf+1)); echo "⚠ ENV   $1"; }
inf()  { note=$((note+1)); [ -n "$quiet" ] || echo "ℹ NOTE  $1"; }

# in_list <needle> <space-separated-haystack>
in_list() {
    local needle="$1" hay="$2" item
    for item in $hay; do [ "$item" = "$needle" ] && return 0; done
    return 1
}

# gitmodules_paths <file> — echoes one submodule path per line.
gitmodules_paths() {
    awk -F'=' '
        /^[[:space:]]*path[[:space:]]*=/ {
            v = $2
            gsub(/^[[:space:]]+/, "", v); gsub(/[[:space:]]+$/, "", v)
            if (v != "") print v
        }
    ' "$1"
}

# helix_dep_paths <file> — echoes the filesystem path each `deps:` entry
# resolves to, using the layout mapping helix-deps.yaml documents itself:
#   layout: flat    -> <root>/<name>
#   layout: grouped -> <root>/submodules/<name>
helix_dep_paths() {
    awk '
        /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
            if (name != "") print (layout == "grouped" ? "submodules/" name : name)
            name = $NF; layout = "flat"; next
        }
        /^[[:space:]]*layout:[[:space:]]*/ { layout = $NF; next }
        END { if (name != "") print (layout == "grouped" ? "submodules/" name : name) }
    ' "$1"
}

# helix_excluded_paths <file> — echoes each third-party gitlink recorded in the
# trailing commentary block. helix-deps.yaml's own header explains why they are
# comments: "The schema defines no field for recording an exclusion, so these
# are recorded as comments rather than as entries under a key that does not
# exist." Shape: `#   <path>  -> git@host:owner/repo.git`
helix_excluded_paths() {
    sed -nE 's/^#[[:space:]]+([^[:space:]]+)[[:space:]]+->[[:space:]]+git@.*/\1/p' "$1"
}

# ── C0 — the shared predicate is not blind ──────────────────────────────────
c0_predicate() {
    local out rc
    out="$(bash "$PC_LIB" --selftest 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "C0 PREDICATE-NOT-BLIND — $(printf '%s' "$out" | tail -n1) (§11.4.201(7)(b))"
        return 0
    fi
    env_ "C0 PREDICATE-NOT-BLIND — pointer_carrier.sh --selftest FAILED (rc=${rc}); C3's verdict would be untrustworthy, so this run cannot verify (§11.4.201(7)(b))"
    printf '%s\n' "$out" | sed 's/^/        /'
    return 1
}

# ── ENV — the head of the cascade must be present before anything is judged ──
c_env_source() {
    local missing="" f
    if [ ! -d "${root}/${GOVERNANCE_ROOT}" ]; then
        env_ "ENV GOVERNANCE-SOURCE — ${GOVERNANCE_ROOT}/ absent; the cascade has no head to verify against. fix: git submodule update --init ${GOVERNANCE_ROOT}"
        return 1
    fi
    for f in $GOVERNANCE_FILES; do
        [ -s "${root}/${GOVERNANCE_ROOT}/${f}" ] || missing="${missing} ${GOVERNANCE_ROOT}/${f}"
    done
    if [ -n "$missing" ]; then
        env_ "ENV GOVERNANCE-SOURCE — canonical root incomplete; missing or empty:${missing}. fix: git submodule update --init ${GOVERNANCE_ROOT}"
        return 1
    fi
    ok "ENV GOVERNANCE-SOURCE — ${GOVERNANCE_ROOT}/ populated (Constitution.md + 4 mirrors); the cascade has a head"
    return 0
}

# ── C1 — every declared submodule is classified ─────────────────────────────
c1_fleet() {
    local gm="${root}/.gitmodules" declared p unknown="" missing="" seen=""
    if [ ! -r "$gm" ]; then
        env_ "C1 FLEET-CLASSIFIED — .gitmodules unreadable at ${gm}; the fleet cannot be enumerated"
        return 1
    fi
    declared="$(gitmodules_paths "$gm")"
    if [ -z "${declared//[$' \t\r\n']/}" ]; then
        env_ "C1 FLEET-CLASSIFIED — .gitmodules declares zero submodule paths; nothing to verify (a blind instrument, §11.4.201(7)(b))"
        return 1
    fi
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        seen="${seen} ${p}"
        if in_list "$p" "$OWNED_ROOTS" || [ "$p" = "$GOVERNANCE_ROOT" ] || in_list "$p" "$THIRD_PARTY_ROOTS"; then
            continue
        fi
        unknown="${unknown} ${p}"
    done <<< "$declared"

    for p in $OWNED_ROOTS $GOVERNANCE_ROOT $THIRD_PARTY_ROOTS; do
        in_list "$p" "$seen" || missing="${missing} ${p}"
    done

    local bad_any=0
    if [ -n "$unknown" ]; then
        bad "C1 FLEET-CLASSIFIED — .gitmodules declares submodule(s) this verifier's roster does not classify:${unknown}"
        echo "         fix: classify each in scripts/verify-governance-cascade.sh (OWNED_ROOTS / THIRD_PARTY_ROOTS)"
        echo "              and record it in helix-deps.yaml. An unclassified submodule is a cascade"
        echo "              gap of unknown size (§11.4.26 step 6)."
        bad_any=1
    fi
    if [ -n "$missing" ]; then
        bad "C1 FLEET-CLASSIFIED — roster names submodule(s) .gitmodules no longer declares:${missing}"
        echo "         fix: governance is tracking a fleet that does not exist — drop the entry from the"
        echo "              roster and from helix-deps.yaml, or restore the .gitmodules declaration."
        bad_any=1
    fi
    [ "$bad_any" -eq 0 ] || return 1
    ok "C1 FLEET-CLASSIFIED — all $(printf '%s\n' "$declared" | grep -c .) declared submodule(s) classified: $(printf '%s' "$OWNED_ROOTS" | wc -w) owned, 1 governance source, $(printf '%s' "$THIRD_PARTY_ROOTS" | wc -w) third-party"
    return 0
}

# ── C2 / C3 — the cascade actually reached every owned submodule ────────────
c23_owned_carriers() {
    local d f p missing="" notptr="" unreadable="" checked=0 uninit=""
    for d in $OWNED_ROOTS; do
        if [ ! -d "${root}/${d}" ]; then
            uninit="${uninit} ${d}(absent)"; continue
        fi
        if [ -z "$(find "${root}/${d}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
            uninit="${uninit} ${d}(empty)"; continue
        fi
        for f in $CARRIERS_AGENT; do
            p="${root}/${d}/${f}"
            if [ ! -s "$p" ]; then
                missing="${missing} ${d}/${f}"; continue
            fi
            if [ ! -r "$p" ]; then
                unreadable="${unreadable} ${d}/${f}"; continue
            fi
            checked=$((checked+1))
            is_pointer_carrier "$p" || notptr="${notptr} ${d}/${f}"
        done
    done

    if [ -n "$uninit" ]; then
        env_ "C2 OWNED-CARRIERS-PRESENT — owned submodule(s) not checked out:${uninit}; their cascade state cannot be read. fix: git submodule update --init --recursive"
    fi
    if [ -n "$unreadable" ]; then
        env_ "C2 OWNED-CARRIERS-PRESENT — carrier(s) present but unreadable:${unreadable}"
    fi
    if [ -n "$missing" ]; then
        bad "C2 OWNED-CARRIERS-PRESENT — owned submodule(s) missing or empty governance carrier(s):${missing}"
        echo "         fix: every owned submodule carries all four of ${CARRIERS_AGENT} (§11.4.157(A)+(D));"
        echo "              a missing carrier is a cascade gap that §11.4.26 step 6 requires closed in the"
        echo "              same change-window."
    elif [ -z "$uninit" ] && [ -z "$unreadable" ]; then
        ok "C2 OWNED-CARRIERS-PRESENT — all $(printf '%s' "$OWNED_ROOTS" | wc -w)×4 = ${checked} owned-submodule carriers present and non-empty (§11.4.157(A)+(D))"
    fi

    if [ -n "$notptr" ]; then
        bad "C3 OWNED-CARRIERS-POINTER — carrier(s) with no real, non-fenced '## INHERITED FROM ' heading:${notptr}"
        echo "         fix: the carrier must open with the §11.4.35 invariant-6 pointer block. Without it the"
        echo "              submodule inherits nothing — every anchor in the corpus is out of force there."
    elif [ "$checked" -gt 0 ]; then
        ok "C3 OWNED-CARRIERS-POINTER — all ${checked} recognised by the canonical is_pointer_carrier predicate (§11.4.35 inv. 6)"
    fi

    { [ -z "$missing" ] && [ -z "$notptr" ]; } || return 1
    return 0
}

# ── C4 — third-party exclusion is deliberate and documented ─────────────────
c4_third_party() {
    local hd="${root}/helix-deps.yaml" excluded p undocumented="" rc=0
    if [ ! -r "$hd" ]; then
        env_ "C4 THIRD-PARTY-EXCLUDED — helix-deps.yaml unreadable at ${hd}; cannot confirm the exclusions are documented"
        return 1
    fi
    excluded="$(helix_excluded_paths "$hd")"
    for p in $THIRD_PARTY_ROOTS $NESTED_THIRD_PARTY; do
        printf '%s\n' "$excluded" | grep -qxF "$p" || undocumented="${undocumented} ${p}"
    done
    if [ -n "$undocumented" ]; then
        bad "C4 THIRD-PARTY-EXCLUDED — third-party gitlink(s) excluded from the cascade but NOT recorded in helix-deps.yaml:${undocumented}"
        echo "         fix: an undocumented exclusion is indistinguishable from an oversight. Record each in"
        echo "              helix-deps.yaml's third-party comment block (§4: third-party submodules are out"
        echo "              of scope; §11.4.6: say so, do not leave it implied)."
        rc=1
    else
        ok "C4 THIRD-PARTY-EXCLUDED — $(printf '%s' "$THIRD_PARTY_ROOTS $NESTED_THIRD_PARTY" | wc -w) third-party gitlink(s) excluded BY NAME and documented in helix-deps.yaml (§4 / §11.4.156(C))"
    fi
    # Exclusion must be a decision, not blindness: state what was skipped and why.
    for p in $THIRD_PARTY_ROOTS; do
        if [ -d "${root}/${p}" ]; then
            inf "C4 · skipped ${p}/ — third-party; zero governance carriers required or expected of it"
        else
            inf "C4 · skipped ${p}/ — third-party and not checked out; nothing required of it either way"
        fi
    done
    inf "C4 · ${GOVERNANCE_ROOT}/ is the governance SOURCE, not a cascade consumer — it is the head of the cascade, checked by ENV GOVERNANCE-SOURCE above"
    return $rc
}

# ── C5 — the umbrella's own five carriers, and their lockstep ───────────────
c5_root_lockstep() {
    local f missing="" digests="" d distinct rc=0
    for f in $ROOT_CARRIERS; do
        [ -s "${root}/${f}" ] || missing="${missing} ${f}"
    done
    if [ -n "$missing" ]; then
        bad "C5 ROOT-CARRIERS — missing or empty at the project root:${missing} (§11.4.157(A): all five carriers, GEMINI.md included)"
        rc=1
    else
        ok "C5 ROOT-CARRIERS — ${ROOT_CARRIERS} all present at the project root (§11.4.157(A))"
    fi
    for f in $CARRIERS_AGENT; do
        if [ ! -r "${root}/${f}" ]; then
            env_ "C5 ROOT-LOCKSTEP — ${f} unreadable; the lockstep digest cannot be computed"
            return 1
        fi
        d="$(tail -n "+${LOCKSTEP_FROM}" "${root}/${f}" | sha256sum | cut -d' ' -f1)"
        [ -n "$d" ] || { env_ "C5 ROOT-LOCKSTEP — sha256sum produced no digest for ${f}"; return 1; }
        digests="${digests}${d} ${f}"$'\n'
    done
    distinct="$(printf '%s' "$digests" | awk '{print $1}' | sort -u | grep -c .)"
    if [ "$distinct" -ne 1 ]; then
        bad "C5 ROOT-LOCKSTEP — the four root agent mirrors are NOT byte-identical from line ${LOCKSTEP_FROM} down: ${distinct} distinct digests (§11.4.157(B) no silent drift)"
        printf '%s' "$digests" | sed 's/^/           /'
        echo "         fix: diff <(tail -n +${LOCKSTEP_FROM} CLAUDE.md) <(tail -n +${LOCKSTEP_FROM} GEMINI.md) names what drifted."
        echo "              A governance edit lands in all four carriers or in none (§11.4.157(A))."
        rc=1
    else
        ok "C5 ROOT-LOCKSTEP — the four root agent mirrors are byte-identical from line ${LOCKSTEP_FROM} down; shared digest $(printf '%s' "$digests" | head -n1 | awk '{print $1}') (§11.4.157(B))"
    fi
    return $rc
}

# ── C6 — the manifest and the real fleet agree, both directions ─────────────
c6_manifest_sync() {
    local hd="${root}/helix-deps.yaml" gm="${root}/.gitmodules"
    local dep_paths excl_paths declared p rc=0 unrecorded="" phantom=""
    if [ ! -r "$hd" ]; then
        env_ "C6 MANIFEST-FLEET-SYNC — helix-deps.yaml unreadable at ${hd}; nothing to compare .gitmodules against"
        return 1
    fi
    if [ ! -r "$gm" ]; then
        env_ "C6 MANIFEST-FLEET-SYNC — .gitmodules unreadable at ${gm}"
        return 1
    fi
    dep_paths="$(helix_dep_paths "$hd")"
    excl_paths="$(helix_excluded_paths "$hd")"
    declared="$(gitmodules_paths "$gm")"

    while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf '%s\n' "$dep_paths" | grep -qxF "$p" && continue
        printf '%s\n' "$excl_paths" | grep -qxF "$p" && continue
        unrecorded="${unrecorded} ${p}"
    done <<< "$declared"

    while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf '%s\n' "$declared" | grep -qxF "$p" || phantom="${phantom} ${p}"
    done <<< "$dep_paths"

    if [ -n "$unrecorded" ]; then
        bad "C6 MANIFEST-FLEET-SYNC — .gitmodules declares submodule(s) helix-deps.yaml records nowhere:${unrecorded}"
        echo "         fix: add a deps[] entry (owned) or a third-party comment line (not ours) — §11.4.31."
        rc=1
    fi
    if [ -n "$phantom" ]; then
        bad "C6 MANIFEST-FLEET-SYNC — helix-deps.yaml deps[] names submodule(s) .gitmodules does not declare:${phantom}"
        echo "         fix: governance is tracking a fleet that no longer exists. Drop the stale deps[] entry"
        echo "              or restore the .gitmodules declaration — §11.4.31."
        rc=1
    fi
    [ "$rc" -eq 0 ] && ok "C6 MANIFEST-FLEET-SYNC — helix-deps.yaml records exactly the $(printf '%s\n' "$declared" | grep -c .) submodule(s) .gitmodules declares ($(printf '%s\n' "$dep_paths" | grep -c .) deps[] + third-party comments), both directions (§11.4.31)"
    return $rc
}

# ── C7 — recursion into owned submodules' own gitlinks (CONST-047) ──────────
c7_recursion() {
    local d gm p unknown="" found=0
    for d in $OWNED_ROOTS; do
        gm="${root}/${d}/.gitmodules"
        [ -f "$gm" ] || continue
        if [ ! -r "$gm" ]; then
            env_ "C7 RECURSION — ${d}/.gitmodules present but unreadable"
            continue
        fi
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            found=$((found+1))
            if in_list "${d}/${p}" "$NESTED_THIRD_PARTY" || in_list "${d}/${p}" "$OWNED_ROOTS"; then
                inf "C7 · ${d}/${p} — nested gitlink, classified third-party; excluded from the cascade by name"
                continue
            fi
            unknown="${unknown} ${d}/${p}"
        done <<< "$(gitmodules_paths "$gm")"
    done
    if [ -n "$unknown" ]; then
        bad "C7 RECURSION — nested gitlink(s) this verifier's roster does not classify:${unknown}"
        echo "         fix: classify each in NESTED_THIRD_PARTY (or OWNED_ROOTS if it is ours and must carry"
        echo "              the four carriers). CONST-047 / §11.4.32 make the cascade recursive, so an"
        echo "              unclassified nested gitlink is an unmeasured part of the fleet."
        return 1
    fi
    ok "C7 RECURSION — ${found} nested gitlink(s) under the $(printf '%s' "$OWNED_ROOTS" | wc -w) owned submodules, all classified (CONST-047 recursive scope)"
    return 0
}

# ── R1 — reported, never failed on ──────────────────────────────────────────
r1_known_unclearable() {
    local line p owner present=0 absent=0
    [ -n "$quiet" ] || {
        echo "----------------------------------------------------------------------"
        echo "REPORT — known-unclearable third-party carriers (NOT a verdict input)"
    }
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        p="${line%%|*}"; owner="${line#*|}"
        if [ -e "${root}/${p}" ]; then
            present=$((present+1))
            [ -n "$quiet" ] || printf '   present  %-62s  owned by %s\n' "$p" "$owner"
        else
            absent=$((absent+1))
            [ -n "$quiet" ] || printf '   absent   %-62s  owned by %s\n' "$p" "$owner"
        fi
    done <<< "$KNOWN_UNCLEARABLE"
    [ -n "$quiet" ] || {
        echo "   ${present} present, ${absent} absent. No commit this repository can make changes any of"
        echo "   them; the umbrella's only lever is the gitlink, and no upstream commit carries the"
        echo "   anchors. Forensics: docs/constitution-adoption/POST-APPLY-STATE.md §3 and"
        echo "   Constitution.md -> 'Known-excluded gate findings'. They are still reported as FAILs by"
        echo "   the propagation-gate family inside scripts/verify-all-constitution-rules.sh — excluded"
        echo "   here means not double-counted, never suppressed (§11.4.6)."
    }
}

run_checks() {
    [ -n "$quiet" ] || {
        echo "${GATE}: verifying the governance cascade under ${root}"
        echo "  §11.4.32 step 1 · predicate reused by reference from ${GOVERNANCE_ROOT}/scripts/gates/lib/pointer_carrier.sh"
        echo "----------------------------------------------------------------------"
    }
    c0_predicate
    c_env_source
    c1_fleet
    c23_owned_carriers
    c4_third_party
    c5_root_lockstep
    c6_manifest_sync
    c7_recursion
    r1_known_unclearable

    echo "----------------------------------------------------------------------"
    echo "${GATE}: ${pass} PASS, ${fail} FAIL, ${envf} ENV, ${note} NOTE  (root ${root})"
    if [ "$envf" -gt 0 ]; then
        echo "⚠ ${GATE}: COULD NOT VERIFY — ${envf} environment/instrument problem(s); rc=2, NOT a violation verdict"
        return 2
    fi
    if [ "$fail" -gt 0 ]; then
        echo "❌ ${GATE}: FAIL — ${fail} real cascade violation(s)"
        return 1
    fi
    echo "✅ ${GATE}: PASS — governance cascades to every owned submodule; third-party roots excluded by name; root lockstep intact; manifest matches the fleet"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired §1.1 mutation proof. Every mutation is applied to a COPY inside a
# mktemp sandbox. The real tree and every submodule working tree are untouched
# (§11.4.84 quiescence by construction).
# ─────────────────────────────────────────────────────────────────────────────
build_sandbox() {
    local dest="$1" d f rel
    mkdir -p "${dest}/${GOVERNANCE_ROOT}" || return 1
    for f in $ROOT_CARRIERS; do
        cp "${REPO_ROOT}/${f}" "${dest}/${f}" || return 1
    done
    cp "${REPO_ROOT}/.gitmodules"     "${dest}/.gitmodules"     || return 1
    cp "${REPO_ROOT}/helix-deps.yaml" "${dest}/helix-deps.yaml" || return 1
    for f in $GOVERNANCE_FILES; do
        cp "${REPO_ROOT}/${GOVERNANCE_ROOT}/${f}" "${dest}/${GOVERNANCE_ROOT}/${f}" || return 1
    done
    for d in $OWNED_ROOTS; do
        mkdir -p "${dest}/${d}" || return 1
        for f in $CARRIERS_AGENT; do
            cp "${REPO_ROOT}/${d}/${f}" "${dest}/${d}/${f}" || return 1
        done
        [ -f "${REPO_ROOT}/${d}/.gitmodules" ] && { cp "${REPO_ROOT}/${d}/.gitmodules" "${dest}/${d}/.gitmodules" || return 1; }
    done
    # Third-party roots and the R1 fixtures: copied only so the NOTE/REPORT
    # lines describe the same shape the real tree has. Nothing is required of
    # them, so a missing one is not an error here either.
    for d in $THIRD_PARTY_ROOTS; do mkdir -p "${dest}/${d}" || return 1; done
    while IFS= read -r rel; do
        rel="${rel%%|*}"
        [ -f "${REPO_ROOT}/${rel}" ] || continue
        mkdir -p "${dest}/$(dirname "$rel")" || return 1
        cp "${REPO_ROOT}/${rel}" "${dest}/${rel}" || return 1
    done <<< "$KNOWN_UNCLEARABLE"
    return 0
}

prove_failure() {
    local sandbox pristine rc mut_fails=0

    sandbox="$(mktemp -d)" || { echo "${GATE}: ENV — mktemp -d failed" >&2; exit 2; }
    trap 'rm -rf "$sandbox"' EXIT INT TERM

    echo "${GATE} §1.1 PAIRED MUTATION PROOF"
    echo "  sandbox: ${sandbox}"
    echo "  Every mutation below is applied to a THROWAWAY COPY. Neither this repository"
    echo "  nor any submodule working tree is written to, and no git command is run."
    echo "----------------------------------------------------------------------"

    pristine="${sandbox}/pristine"
    if ! build_sandbox "$pristine"; then
        echo "${GATE}: ENV — could not build the sandbox copy" >&2
        trap - EXIT INT TERM; rm -rf "$sandbox"; exit 2
    fi

    # Golden-good control. Without it, "the mutations failed" proves nothing —
    # the sandbox could have been failing for an unrelated reason.
    bash "$0" --root "$pristine" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "✅ CONTROL golden-good   — unmutated sandbox COPY passes (rc=0)"
    else
        echo "❌ CONTROL golden-good   — unmutated sandbox COPY returned rc=${rc}; the proof below would be meaningless"
        bash "$0" --root "$pristine" 2>&1 | sed 's/^/        /'
        trap - EXIT INT TERM; rm -rf "$sandbox"
        return 1
    fi

    # mutate_and_assert <label> <description> <expected-rc> <targets> <fn>
    mutate_and_assert() {
        local name="$1" desc="$2" want="$3" targets="$4"; shift 4
        local slug dir
        slug="$(printf '%s' "$name" | tr -cd 'A-Za-z0-9')"
        dir="${sandbox}/mut_${slug}"
        rm -rf "$dir"
        if ! cp -r "$pristine" "$dir"; then
            echo "❌ ${name} — could not copy the sandbox"; mut_fails=$((mut_fails+1)); return
        fi
        if ! "$@" "$dir"; then
            echo "❌ ${name} — could not apply the mutation (${desc})"; mut_fails=$((mut_fails+1)); rm -rf "$dir"; return
        fi
        bash "$0" --root "$dir" --quiet >/dev/null 2>&1; local mrc=$?
        if [ "$mrc" -eq "$want" ]; then
            echo "✅ ${name} — ${desc}"
            echo "                        -> rc=${mrc} (wanted ${want})  [${targets}]"
        else
            echo "❌ ${name} — ${desc}"
            echo "                        -> rc=${mrc}, wanted ${want}. THIS VERIFIER IS A SHAM (§1.1)."
            bash "$0" --root "$dir" 2>&1 | sed 's/^/        /'
            mut_fails=$((mut_fails+1))
        fi
        rm -rf "$dir"
    }

    # M1 — remove a carrier from an OWNED submodule.
    m1() { rm -f "$1/ai_interviewing/QWEN.md"; }
    # M2 — an owned carrier that exists but no longer inherits anything.
    m2() { local d="$1"; grep -v '^## INHERITED FROM ' "${d}/design-toolkit/GEMINI.md" > "${d}/g.new" && mv "${d}/g.new" "${d}/design-toolkit/GEMINI.md"; }
    # M3 — break the §11.4.157 root lockstep by editing ONE root carrier below
    #      the header split, exactly the silent-drift clause (B) forbids.
    m3() { printf '\nAn edit that landed in GEMINI.md and nowhere else.\n' >> "$1/GEMINI.md"; }
    # M4 — desync helix-deps.yaml from the real fleet (a dep renamed).
    m4() { sed -i 's/^  - name: monetization$/  - name: monetisation-renamed/' "$1/helix-deps.yaml"; }
    # M5 — a submodule joins the fleet unclassified and unrecorded.
    m5() { printf '[submodule "surprise_module"]\n\tpath = surprise_module\n\turl = git@github.com:someone/surprise_module.git\n' >> "$1/.gitmodules"; }
    # M6 — an ENVIRONMENT fault must return 2, never 1. This is the paired proof
    #      for the exit contract itself: an internal error must not masquerade as
    #      a violation verdict.
    m6() { rm -f "$1/${GOVERNANCE_ROOT}/Constitution.md"; }

    mutate_and_assert "M1 owned-carrier-removed " "ai_interviewing/QWEN.md deleted from an OWNED submodule            " 1 "C2" m1
    mutate_and_assert "M2 owned-pointer-stripped" "design-toolkit/GEMINI.md loses its '## INHERITED FROM ' heading    " 1 "C3" m2
    mutate_and_assert "M3 root-lockstep-broken  " "root GEMINI.md edited below line ${LOCKSTEP_FROM}; the other three unchanged  " 1 "C5" m3
    mutate_and_assert "M4 manifest-desynced     " "helix-deps.yaml renames the 'monetization' dep; .gitmodules did not " 1 "C6" m4
    mutate_and_assert "M5 fleet-member-unknown  " ".gitmodules gains an unclassified, unrecorded submodule             " 1 "C1+C6" m5
    mutate_and_assert "M6 source-missing (ENV)  " "submodules/constitution/Constitution.md removed — an INTERNAL fault " 2 "ENV" m6

    trap - EXIT INT TERM; rm -rf "$sandbox"
    echo "----------------------------------------------------------------------"
    if [ "$mut_fails" -eq 0 ]; then
        echo "✅ ${GATE} §1.1 MUTATION PROOF: PASS — control passed, 5 violations were caught as rc=1,"
        echo "   and the environment fault was reported as rc=2 rather than accusing the tree."
        return 0
    fi
    echo "❌ ${GATE} §1.1 MUTATION PROOF: FAIL — ${mut_fails} mutation(s) did not produce the required exit code"
    return 1
}

if [ -n "$prove" ]; then
    prove_failure
    exit $?
fi

run_checks
exit $?
