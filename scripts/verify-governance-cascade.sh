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
#                            owned / governance-source / third-party — and the
#                            classification is DERIVED from evidence (remote
#                            namespace + helix-deps.yaml), never read off a
#                            hardcoded roster. See the DERIVED FLEET ROSTER
#                            block below for the evidence classes and for the
#                            case that deliberately stays a FAIL. An
#                            unclassified submodule is a cascade gap of unknown
#                            size (§11.4.26 step 6).
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
#   C4 THIRD-PARTY-EXCLUDED  the DOCUMENTED exclusions in `helix-deps.yaml` are
#                            honest in both converse directions: none names a
#                            gitlink no `.gitmodules` declares (a phantom
#                            exclusion), and none sits in a namespace this tree
#                            OWNS (a self-exclusion that would drop one of our
#                            own repos out of C2/C3 silently). The forward
#                            direction is not checked because the derivation
#                            READS this block — checking it would be a
#                            tautology, and a tautological gate is a §11.4.201
#                            bluff. §4 excludes "third-party submodules
#                            (libraries not under the project's control)";
#                            §11.4.156(C) puts them out of CI scope.
#   C5 ROOT-LOCKSTEP         the umbrella's five root carriers exist, and the
#                            four agent mirrors are byte-identical from line
#                            ${LOCKSTEP_FROM} down (§11.4.157(B) "no silent
#                            drift"), AND the declared split is not looser than
#                            the header actually needs. §11.4.157 mandates
#                            lockstep but prescribes no particular proof, so the
#                            mechanism is ours, the requirement is the
#                            constitution's — but a mechanism that gates less
#                            than it claims is a bluff, so C5 now reports the
#                            MEASURED convergence line beside the declared one.
#   C6 MANIFEST-FLEET-SYNC   `helix-deps.yaml`'s recorded submodule set equals
#                            what `.gitmodules` declares, in BOTH directions.
#                            §11.4.31 mandates the manifest; a manifest that
#                            names a submodule the fleet no longer has (or
#                            misses one the fleet gained) means governance is
#                            tracking a fleet that does not exist.
#   C7 RECURSION             owned submodules' own `.gitmodules` (CONST-047 /
#                            §11.4.32's "deep recursively") are read and every
#                            nested gitlink is classified too — by the same
#                            derived evidence. A nested gitlink in a namespace
#                            this tree OWNS is a §11.4.28(C) forbidden own-org
#                            chain and FAILs even if it were documented.
#   C8 IN-SUBMODULE-LOCKSTEP  the four agent carriers INSIDE each owned submodule
#                            agree with one another, once their per-agent header
#                            is normalised (§11.4.157(B) "no silent drift" —
#                            the same clause C5 enforces at the root, applied
#                            where C2/C3 only ever looked at each carrier ALONE).
#                            C2 asks "does it exist", C3 asks "does it inherit";
#                            neither compares a submodule's carriers to EACH
#                            OTHER, so until this check existed a submodule could
#                            carry four carriers that all passed C2 and C3 while
#                            saying four different things. That was not
#                            hypothetical: on 2026-09-01 vasic.digital/QWEN.md
#                            was found carrying a truncated pointer block plus 55
#                            lines of stale 2025 project description while its
#                            three siblings carried the canonical body — a real
#                            §11.4.157 break that this verifier reported as
#                            10 PASS / 0 FAIL / rc=0. See "the in-submodule
#                            recipe" below for why the root's line-24 split
#                            cannot be reused verbatim here.
#   C9 MANIFEST-PIN-SYNC     every `helix-deps.yaml` `deps[].ref` equals the
#                            gitlink the repository actually records for that
#                            submodule (§11.4.31). C6 above compares dep NAMES;
#                            this is the other half. Measured 2026-09-01: SEVEN
#                            of seven recorded refs named commits nothing pointed
#                            at, while this verifier reported 10 PASS / rc=0 —
#                            a manifest that certified nothing. DELEGATED to
#                            `scripts/verify-manifest-pins.sh` (which owns the
#                            git access and its own §1.1 proof) because this file
#                            must stay runnable against a plain directory; see
#                            the long comment on c9_manifest_pins for why an
#                            inline implementation would destroy the mutation
#                            proof below.
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
#   repository and no file in ANY submodule working tree is ever written.
#   No sudo, no network.
#   GIT USAGE, stated precisely because this header used to say "no git command
#   is run at all": C9 runs `git rev-parse --show-toplevel` on the target, and
#   delegates to scripts/verify-manifest-pins.sh, which runs read-only git
#   plumbing (`ls-files -s`, `ls-tree`, `rev-parse`). Every one of those is a
#   read. Nothing is checked out, staged, committed or fetched, and
#   `git submodule update` is never run. Checks C0..C8 still run no git at all,
#   which is what keeps this file pointable at a plain directory — C9 detects
#   that case and records a reasoned NOTE instead of a verdict.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, POSIX awk/grep/sed/cp/mkdir/find/sort/cut/tr, sha256sum (coreutils).
#   git, for C9 only (read-only plumbing; see Side-effects). bash -n clean.
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

# ── INTERNAL-FAULT TRAP: a crash is rc=2, never rc=1 ─────────────────────────
# `set -u` aborts with status 1 — the code this file's exit contract reserves
# for a REAL cascade violation. So a broken instrument accused the tree, which
# is exactly the §11.4.201(1) false-positive refusal this project has now had to
# fix three times (the index doctor's exit contract; the §11.4.32 sweep's step-1
# rc handling; and, on 2026-08-31, this file — a `local a="$1" b="${a}/x"`
# unbound-variable abort exited 1 mid-run and read as "governance violation").
#
# `trap ... ERR` is NOT usable here: without `-e` the ERR trap still fires on
# every non-zero simple command, and this script legitimately runs `grep` for
# absence dozens of times. The decidable signal is instead: exited 1 WITHOUT
# having emitted a verdict line. Every deliberate rc=1 path sets the flag first;
# every deliberate rc=2 path is already the honest code and passes through.
_verdict_emitted=0
_sandbox_to_clean=""
_on_exit() {
    local rc=$?
    trap - EXIT INT TERM
    # Sandbox cleanup lives HERE rather than in a second EXIT trap, because a
    # second `trap ... EXIT` would REPLACE this one and silently disarm the
    # fault mapping for the whole of --prove-failure.
    [ -n "$_sandbox_to_clean" ] && rm -rf "$_sandbox_to_clean"
    if [ "$rc" -eq 1 ] && [ "$_verdict_emitted" -eq 0 ]; then
        echo "${GATE}: INTERNAL-FAULT — aborted with status 1 before emitting any verdict." >&2
        echo "${GATE}: an instrument that crashes MUST NOT accuse the tree (§11.4.201(1))." >&2
        echo "${GATE}: re-mapped to rc=2 COULD NOT VERIFY — this is NOT a violation verdict." >&2
        exit 2
    fi
    exit "$rc"
}
trap '_on_exit' EXIT INT TERM

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
# THE FLEET ROSTER IS DERIVED, NOT DECLARED.
#
# It used to be four literals:
#     OWNED_ROOTS="ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital"
#     GOVERNANCE_ROOT="submodules/constitution"
#     THIRD_PARTY_ROOTS="submodules/superspec"
#     NESTED_THIRD_PARTY="milosvasic.ru/Upstreamable"
# — a list that had to be hand-edited every time the fleet changed. On
# 2026-08-28 commit e22d6b1 added the `workshop` submodule and the verifier
# FAILed C1 for a reason that was not a cascade defect at all: the ROSTER had
# gone stale, not the tree. That is a frozen assumption, and the operator's
# standing directive is explicit — "Make sure all this is fully dynamic and
# adaptable based on the environment!"
#
# So classification is now DERIVED from evidence the repository already keeps,
# by the same discipline `scripts/verify-provider-ci.sh` uses for ownership
# (its parse_remote_url + OWNED_NS block: derive from the tree's own remotes and
# from provider identity, "never from a name list"):
#
#   GOVERNANCE  the declared submodule that SUPPLIES the canonical §11.4.35
#               pointer predicate `scripts/gates/lib/pointer_carrier.sh`.
#               Structural, not nominal: whichever submodule C3 reuses BY
#               REFERENCE (§11.4.28 / §11.4.177) IS the head of the cascade.
#   OWNED       a submodule whose remote NAMESPACE (host/owner, parsed from the
#               `.gitmodules` url) is an OWNED namespace. A namespace is owned
#               on either of two independent evidences:
#                 E1 tree-shared    — it hosts >= 2 declared submodules of this
#                                     tree (verify-provider-ci.sh's
#                                     `tree-shared` evidence class);
#                 E2 manifest-named — it is the namespace of a `deps[].ssh_url`
#                                     in helix-deps.yaml (§11.4.31).
#   THIRD-PARTY a submodule recorded BY NAME in helix-deps.yaml's trailing
#               third-party exclusion block (§4 / §11.4.156(C)).
#   UNCLASSIFIED anything else — C1 FAILs.
#
# C1 KEEPS ITS TEETH. This is the point of the design, and it is checked by the
# §1.1 mutation M5: a gitlink from an unknown namespace (one submodule, absent
# from deps[], undocumented as third-party) is UNCLASSIFIED and FAILs, exactly
# as it did under the literal roster. What changed is that a submodule from a
# namespace this tree DEMONSTRABLY owns classifies itself — no hand edit, and
# no window in which a real cascade gap hides behind a stale-roster FAIL.
#
# What the derivation does NOT do, stated plainly (§11.4.6): it cannot decide
# ownership of a brand-new namespace holding exactly ONE submodule that is not
# yet in helix-deps.yaml. That case is UNCLASSIFIED — a FAIL, not a guess — and
# is cleared by recording the submodule in helix-deps.yaml (as a dep if it is
# ours, in the exclusion block if it is not). The manifest is the operator's
# declaration; this verifier reads it, it never invents one.
#
# The old C1 "roster names submodule(s) .gitmodules no longer declares" half is
# not lost, it MOVED: a derived roster cannot name a phantom. The same property
# is now checked by C6 (deps[] naming an undeclared submodule) and by C4 (an
# exclusion naming an undeclared gitlink) — once each, never double-counted.
# ─────────────────────────────────────────────────────────────────────────────
GOVERNANCE_ROOT=""          # derived: derive_governance_root
GOVERNANCE_ROOT_EVIDENCE=""
OWNED_ROOTS=""              # derived: derive_fleet
THIRD_PARTY_ROOTS=""        # derived: derive_fleet
UNCLASSIFIED_ROOTS=""       # derived: derive_fleet
OWNED_NAMESPACES=""         # derived: derive_fleet
NAMESPACE_EVIDENCE=""       # derived: derive_fleet (one "ns=evidence" per line)
FLEET_URLS=""               # derived: derive_fleet ("path<TAB>url" per line)

CARRIERS_AGENT="AGENTS.md CLAUDE.md QWEN.md GEMINI.md"
ROOT_CARRIERS="AGENTS.md CLAUDE.md QWEN.md GEMINI.md Constitution.md"
GOVERNANCE_FILES="Constitution.md AGENTS.md CLAUDE.md QWEN.md GEMINI.md"

# §11.4.157 lockstep mechanism: the leading lines of each root agent mirror are
# the per-agent header (title / base file named / which agent reads it);
# everything below it must be byte-identical.
#
# WHERE THE HEADER ACTUALLY ENDS, and why this is not 24 any more.
# Constitution.md's header table records the recipe as `tail -n +24`, and this
# gate used LOCKSTEP_FROM=24 to match it. That under-enforced. Measured
# 2026-09-01 against the real root carriers, only lines 1, 3, 5, 12 and 18
# differ across the four mirrors; lines 19..23 are identical IN FACT but were
# UNGATED, so an edit there would have drifted silently. Reproduced concretely:
# altering line 21 of GEMINI.md alone still yielded ONE shared `tail -n +24`
# digest, i.e. C5 reported PASS on a drifted tree. Lines 19..22 are shared
# governance prose ("It is one of the four repository-root governance context
# carriers ... requires to be maintained in lockstep"), not per-agent text, so
# gating them is a correction, not an over-reach.
#
# Enforcing from 19 is a STRICT TIGHTENING of the documented contract, never a
# conflict with it: a tree byte-identical from line 19 is necessarily
# byte-identical from line 24, so `tail -n +24` still holds wherever it is
# quoted. Nothing that passes C5 can fail the constitution's own recipe.
#
# WHY A DECLARED CONSTANT AND NOT A DERIVED ONE. Deriving the split from the
# files (e.g. "the last line at which they differ") would make the check
# tautological: any drift would move the boundary and the gate would pass by
# construction — precisely the blind-instrument defect this gate exists to
# catch. So the boundary is DECLARED, and guarded from both sides:
#   * looser than reality  -> the measured convergence is printed on every run
#     and NOTEd when it is earlier than the declaration, so a silent gap like
#     the 19-vs-24 one can never sit unnoticed for months again.
#   * pushed down to hide a failure -> LOCKSTEP_FROM_MAX is a ratchet. The
#     declaration may never exceed the constitution's documented budget; an
#     agent "fixing" a lockstep FAIL by raising the number fails the gate.
# Loosening therefore stays possible but must be deliberate, reviewed, and
# within the documented budget — never automatic.
#
# CONSEQUENCE, STATED (§11.4.6): the mirrors are LINE-ALIGNED by construction.
# If per-agent header text ever needs more room (a reader list that wraps, say),
# all four carriers must keep the header the SAME number of lines — pad them
# equally — or the declaration must move, up to LOCKSTEP_FROM_MAX. That is not
# an accident of this implementation; it is what "byte-identical from line N"
# means, and the FAIL message says so.
LOCKSTEP_FROM=19

# The ratchet ceiling: the per-agent header budget documented in
# Constitution.md's header table ("bodies byte-identical from line 24"). The
# declaration above may be tighter than this, never looser.
LOCKSTEP_FROM_MAX=24

# ── The IN-SUBMODULE lockstep recipe (C8) — why it is NOT the line-24 split ───
# §11.4.157(B) forbids silent drift between the four agent carriers. At the
# umbrella ROOT this project proves it with `tail -n +24` (above), because the
# root carriers confine their per-agent variance to lines 1..23.
#
# Inside a submodule the carriers are a DIFFERENT document — the module pointer
# carrier — and their per-agent variance is not confined to a leading block. It
# is scattered: the title (line 1), the `## INHERITED FROM constitution/<NAME>.md`
# heading (line 3), the "canonical name of the base file" sentence (line ~20),
# the `@constitution/<NAME>.md` import warning (line ~42), and the "This carrier
# is read by ..." reader line (line ~51). `tail -n +24` therefore yields FOUR
# distinct digests for EVERY owned submodule, compliant ones included — measured
# across all six on 2026-09-01. Reusing the root recipe here would be a gate
# that FAILs on correct trees, which is worse than no gate at all.
#
# So C8 normalises the variance instead of skipping past it:
#   1. each carrier's OWN name token -> @@SELF@@. Only its own: substituting all
#      four names in every file would let `CLAUDE.md` say "see AGENTS.md" while
#      `QWEN.md` says "see GEMINI.md" and call that a match. Measured across the
#      fleet: no submodule carrier references a FOREIGN carrier name, so nothing
#      legitimate is caught by the stricter form.
#   2. the reader line -> @@READER@@, a PLACEHOLDER rather than a deletion, so a
#      carrier that DROPS its reader line differs from three that keep it and is
#      reported, instead of being normalised into agreement.
# Everything else — every governance sentence — is compared byte for byte.
#
# Honest boundary (§11.4.6): rule 1 is blind to a drift that consists ONLY of
# one carrier substituting its own name where a sibling correctly names a real
# file (e.g. a body sentence mutated from "QWEN.md" to "CLAUDE.md" inside
# CLAUDE.md). That is inherent to any name-normalising recipe; the alternative —
# comparing raw bytes — cannot express legitimate per-agent variance at all.
LOCKSTEP_READER_RE='^This carrier is read by .*$'

# in_submodule_digest <carrier-path> — echoes the normalised sha256 of one
# in-submodule carrier under the recipe documented above. Empty on failure.
in_submodule_digest() {
    # Split across statements: inside ONE `local`, every RHS is expanded before
    # any name is declared, so a later name could not reference an earlier one
    # under `set -u` (the house rule this file learned on 2026-08-31).
    local p="$1"
    local base
    base="${p##*/}"; base="${base%.md}"
    [ -n "$base" ] || return 1
    sed -e "s/${base}/@@SELF@@/g" -e "s|${LOCKSTEP_READER_RE}|@@READER@@|" "$p" \
        | sha256sum | cut -d' ' -f1
}

# R1 — carriers inside repositories this project does not own. `path|owner`.
KNOWN_UNCLEARABLE="milosvasic.ru/Upstreamable/AGENTS.md|red-elf/Upstreamable (nested gitlink of milosvasic.ru)
milosvasic.ru/Upstreamable/CLAUDE.md|red-elf/Upstreamable (nested gitlink of milosvasic.ru)
submodules/superspec/examples/static-landing-page/CLAUDE.md|WangX0111/superspec (third-party submodule)
.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md|WangX0111/superspec (vendored spec-kit extension copy)"

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

# list_has <newline-separated-list> <exact-line> — THREE-VALUED membership.
#
# `grep -qxF` has THREE outcomes, not two: 0 the line is present, 1 it is
# absent, and 2 GREP ITSELF FAILED — a resource fault, a killed child, an
# unreadable stream. The bare `grep -qxF "$p" || <record a finding>` idiom this
# file used inline folded that 2 into the 1, so a transient TOOL fault was
# reported as a GOVERNANCE VIOLATION naming a submodule that is, in fact,
# declared in both files.
#
# MEASURED 2026-09-05, not inferred. C6 was observed producing
#     helix-deps.yaml deps[] names submodule(s) .gitmodules does not declare:
#     submodules/constitution
# in ONE of five otherwise identical runs, on a tree where .gitmodules line 2
# and helix-deps.yaml provably both carry that path and neither file was
# written during the runs. Forcing grep to exit 2 for exactly that one pattern
# — and for nothing else — reproduces that sentence VERBATIM. The concurrency
# hypothesis offered instead (a sibling --prove-failure run corrupting the
# reading) is DISPROVED by construction: that path builds a wholly SYNTHETIC
# fleet under mktemp -d, mutates only per-mutation cp -r copies, names its
# modules syn-alpha/syn-beta/syn-vendor, and runs no git command against this
# tree at all.
#
# A tool error is a COULD-NOT-DETERMINE, never a finding — the same
# three-valued rule this file already applies to child exit codes, and the same
# rule scripts/pre-push-gates.sh's run_gate had to learn when it mapped every
# non-zero child return onto FAILED.
#
# rc: 0 present - 1 absent - 2 the membership test could not be performed.
list_has() {
    printf '%s\n' "$1" | grep -qxF -- "$2"
    case $? in
        0) return 0 ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
}

# helix_dep_urls <file> — echoes every `deps[].ssh_url` value. Used only to
# derive OWNED NAMESPACES (evidence E2), never to derive a path.
helix_dep_urls() {
    sed -nE 's/^[[:space:]]*ssh_url:[[:space:]]*([^[:space:]#]+).*/\1/p' "$1"
}

# gitmodules_entries <file> — echoes "path<TAB>url" for every declared
# submodule. The path-only view (gitmodules_paths) cannot answer an ownership
# question; the url is where the namespace lives.
gitmodules_entries() {
    awk '
        function trim(v) { gsub(/^[[:space:]]+/, "", v); gsub(/[[:space:]]+$/, "", v); return v }
        /^[[:space:]]*\[submodule/            { p = ""; u = ""; next }
        /^[[:space:]]*path[[:space:]]*=/      { p = trim(substr($0, index($0, "=") + 1)) }
        /^[[:space:]]*url[[:space:]]*=/       { u = trim(substr($0, index($0, "=") + 1)) }
        { if (p != "" && u != "") { print p "\t" u; p = ""; u = "" } }
    ' "$1"
}

# url_namespace <url> — echoes "host/owner", lowercased, for the git URL forms
# this fleet uses (scp-like `git@host:owner/repo.git`, `ssh://…`, `https://…`).
# Deliberately the same decomposition scripts/verify-provider-ci.sh performs in
# its parse_remote_url, so "who owns this" is answered identically by both
# verifiers rather than by two divergent parsers.
url_namespace() {
    local url="$1" rest host path
    case "$url" in
        *://*) rest="${url#*://}"; rest="${rest#*@}"
               host="${rest%%/*}"; path="${rest#*/}" ;;
        *@*:*) rest="${url#*@}"
               host="${rest%%:*}"; path="${rest#*:}" ;;
        *:*/*) host="${url%%:*}";  path="${url#*:}" ;;
        *)     return 1 ;;
    esac
    host="${host%%:*}"; path="${path#/}"
    [ -n "$host" ] && [ -n "$path" ] || return 1
    printf '%s/%s\n' "$(printf '%s' "$host" | tr 'A-Z' 'a-z')" \
                     "$(printf '%s' "${path%%/*}" | tr 'A-Z' 'a-z')"
}

# derive_governance_root <tree> — echoes the .gitmodules path of the submodule
# that SUPPLIES the canonical pointer predicate. Structural, never nominal.
#   rc 0  exactly one candidate (echoed)
#   rc 1  no candidate (submodule absent / not initialised)
#   rc 2  MORE THAN ONE candidate — ambiguous instrument, never guessed
derive_governance_root() {
    local tree="$1" gm="$1/.gitmodules" p hits="" n=0
    [ -r "$gm" ] || return 1
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        [ -r "${tree}/${p}/scripts/gates/lib/pointer_carrier.sh" ] || continue
        hits="${hits} ${p}"; n=$((n + 1))
    done <<< "$(gitmodules_paths "$gm")"
    [ "$n" -eq 0 ] && return 1
    if [ "$n" -gt 1 ]; then
        echo "${GATE}: ENV — more than one declared submodule supplies the pointer predicate:${hits}" >&2
        return 2
    fi
    printf '%s\n' "${hits# }"
    return 0
}

# derive_fleet <tree> — classifies every declared submodule of <tree> from
# evidence, filling OWNED_ROOTS / THIRD_PARTY_ROOTS / UNCLASSIFIED_ROOTS /
# OWNED_NAMESPACES / NAMESPACE_EVIDENCE / FLEET_URLS. Read-only; no git command.
derive_fleet() {
    # Split across statements deliberately: inside ONE `local`, every RHS is
    # expanded before any name is declared, so `gm="${tree}/…"` would read an
    # unbound `tree` under `set -u`.
    local tree="$1"
    local gm="${tree}/.gitmodules" hd="${tree}/helix-deps.yaml"
    local line p u ns d ndecl excl url
    OWNED_ROOTS=""; THIRD_PARTY_ROOTS=""; UNCLASSIFIED_ROOTS=""
    OWNED_NAMESPACES=""; NAMESPACE_EVIDENCE=""; FLEET_URLS=""
    [ -r "$gm" ] || return 1

    # Root-level (path,url) pairs, plus the nested pairs C7 needs.
    FLEET_URLS="$(gitmodules_entries "$gm")"
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        [ -r "${tree}/${p}/.gitmodules" ] || continue
        while IFS=$'\t' read -r d url; do
            [ -n "$d" ] || continue
            FLEET_URLS="${FLEET_URLS}"$'\n'"${p}/${d}"$'\t'"${url}"
        done <<< "$(gitmodules_entries "${tree}/${p}/.gitmodules")"
    done <<< "$(gitmodules_paths "$gm")"

    # ── E1 tree-shared: a namespace hosting >= 2 declared submodules ─────────
    while IFS= read -r ns; do
        [ -n "$ns" ] || continue
        ndecl="$(gitmodules_entries "$gm" | cut -f2 | while IFS= read -r u; do
                     url_namespace "$u" || true; done | grep -cxF "$ns")"
        if [ "$ndecl" -ge 2 ] && ! in_list "$ns" "$OWNED_NAMESPACES"; then
            OWNED_NAMESPACES="${OWNED_NAMESPACES} ${ns}"
            NAMESPACE_EVIDENCE="${NAMESPACE_EVIDENCE}${ns}=tree-shared(${ndecl} declared submodules)"$'\n'
        fi
    done <<< "$(gitmodules_entries "$gm" | cut -f2 | while IFS= read -r u; do url_namespace "$u" || true; done | sort -u)"

    # ── E2 manifest-named: the namespace of a helix-deps.yaml deps[].ssh_url ──
    if [ -r "$hd" ]; then
        while IFS= read -r u; do
            [ -n "$u" ] || continue
            ns="$(url_namespace "$u")" || continue
            in_list "$ns" "$OWNED_NAMESPACES" && continue
            OWNED_NAMESPACES="${OWNED_NAMESPACES} ${ns}"
            NAMESPACE_EVIDENCE="${NAMESPACE_EVIDENCE}${ns}=helix-deps.yaml deps[].ssh_url"$'\n'
        done <<< "$(helix_dep_urls "$hd")"
    fi

    # ── classify every ROOT-level declared submodule ─────────────────────────
    excl=""
    [ -r "$hd" ] && excl="$(helix_excluded_paths "$hd")"
    while IFS=$'\t' read -r p u; do
        [ -n "$p" ] || continue
        if [ "$p" = "$GOVERNANCE_ROOT" ]; then continue; fi
        ns="$(url_namespace "$u")" || ns=""
        if [ -n "$ns" ] && in_list "$ns" "$OWNED_NAMESPACES"; then
            OWNED_ROOTS="${OWNED_ROOTS} ${p}"
        elif grep -qxF "$p" <<<"$excl"; then
            THIRD_PARTY_ROOTS="${THIRD_PARTY_ROOTS} ${p}"
        else
            UNCLASSIFIED_ROOTS="${UNCLASSIFIED_ROOTS} ${p}"
        fi
    done <<< "$(gitmodules_entries "$gm")"

    # Stable ordering so the report reads the same on every run. An empty list
    # stays empty — `printf` on nothing would otherwise mint a blank member.
    [ -n "${OWNED_ROOTS// /}" ] && OWNED_ROOTS="$(printf '%s\n' $OWNED_ROOTS | sort | tr '\n' ' ')"
    OWNED_ROOTS="${OWNED_ROOTS#"${OWNED_ROOTS%%[![:space:]]*}"}"; OWNED_ROOTS="${OWNED_ROOTS%"${OWNED_ROOTS##*[![:space:]]}"}"
    [ -n "${THIRD_PARTY_ROOTS// /}" ] && THIRD_PARTY_ROOTS="$(printf '%s\n' $THIRD_PARTY_ROOTS | sort | tr '\n' ' ')"
    THIRD_PARTY_ROOTS="${THIRD_PARTY_ROOTS#"${THIRD_PARTY_ROOTS%%[![:space:]]*}"}"; THIRD_PARTY_ROOTS="${THIRD_PARTY_ROOTS%"${THIRD_PARTY_ROOTS##*[![:space:]]}"}"
    return 0
}

# fleet_url <path> — echoes the declared url for a root or nested gitlink path.
fleet_url() {
    printf '%s\n' "$FLEET_URLS" | awk -F'\t' -v p="$1" '$1==p{print $2; exit}'
}

# ── Resolve the governance source, then the predicate it supplies ────────────
# The SPECIMEN is preferred: a checkout given via --root describes its own
# layout. The REAL tree is the fallback, because --prove-failure's sandbox is a
# partial COPY that deliberately does not carry the gate library. An AMBIGUOUS
# specimen is never silently replaced by the real tree's answer (rc 2).
GOVERNANCE_ROOT="$(derive_governance_root "$root")"; _grc=$?
if [ "$_grc" -eq 0 ]; then
    GOVERNANCE_ROOT_EVIDENCE="derived from the target tree: it supplies scripts/gates/lib/pointer_carrier.sh"
elif [ "$_grc" -eq 2 ]; then
    echo "${GATE}: cannot verify — the governance source is ambiguous in '${root}'" >&2
    exit 2
else
    GOVERNANCE_ROOT="$(derive_governance_root "$REPO_ROOT")" || {
        echo "${GATE}: ENV — no declared submodule supplies scripts/gates/lib/pointer_carrier.sh" >&2
        echo "${GATE}: cannot verify. fix: git submodule update --init --recursive" >&2
        exit 2
    }
    GOVERNANCE_ROOT_EVIDENCE="derived from ${REPO_ROOT} (the target tree carries no gate library — expected for a --prove-failure sandbox)"
fi

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

# ── C1 — every declared submodule is classified, from evidence ──────────────
c1_fleet() {
    local gm="${root}/.gitmodules" declared line ns
    if [ ! -r "$gm" ]; then
        env_ "C1 FLEET-CLASSIFIED — .gitmodules unreadable at ${gm}; the fleet cannot be enumerated"
        return 1
    fi
    declared="$(gitmodules_paths "$gm")"
    if [ -z "${declared//[$' \t\r\n']/}" ]; then
        env_ "C1 FLEET-CLASSIFIED — .gitmodules declares zero submodule paths; nothing to verify (a blind instrument, §11.4.201(7)(b))"
        return 1
    fi

    # Print the derived evidence BEFORE the verdict. A classification whose
    # basis is not shown is indistinguishable from a hardcoded list (§11.4.6).
    inf "C1 · governance source — ${GOVERNANCE_ROOT} (${GOVERNANCE_ROOT_EVIDENCE})"
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        inf "C1 · owned namespace — ${line%%=*}  [evidence: ${line#*=}]"
    done <<< "$NAMESPACE_EVIDENCE"

    if [ -n "$UNCLASSIFIED_ROOTS" ]; then
        bad "C1 FLEET-CLASSIFIED — .gitmodules declares submodule(s) no ownership evidence classifies:${UNCLASSIFIED_ROOTS}"
        for line in $UNCLASSIFIED_ROOTS; do
            ns="$(url_namespace "$(fleet_url "$line")")" || ns="<unparseable url>"
            echo "         ${line}  namespace ${ns} — hosts only 1 declared submodule and is absent from helix-deps.yaml"
        done
        echo "         fix: record it in helix-deps.yaml — a deps[] entry if it is ours (which also makes its"
        echo "              namespace an owned namespace for every future submodule under it), or a line in the"
        echo "              third-party exclusion comment block if it is not. Do NOT add a literal to this"
        echo "              script: the roster is derived, and a hand-edited roster is the frozen assumption"
        echo "              this design removed. An unclassified submodule is a cascade gap of unknown size"
        echo "              (§11.4.26 step 6)."
        return 1
    fi
    ok "C1 FLEET-CLASSIFIED — all $(printf '%s\n' "$declared" | grep -c .) declared submodule(s) classified FROM EVIDENCE: $(printf '%s' "$OWNED_ROOTS" | wc -w) owned, 1 governance source, $(printf '%s' "$THIRD_PARTY_ROOTS" | wc -w) third-party (no hardcoded roster)"
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
    local hd="${root}/helix-deps.yaml" excluded p rc=0
    if [ ! -r "$hd" ]; then
        env_ "C4 THIRD-PARTY-EXCLUDED — helix-deps.yaml unreadable at ${hd}; cannot confirm the exclusions are documented"
        return 1
    fi
    excluded="$(helix_excluded_paths "$hd")"
    # The FORWARD direction ("a third-party root is documented") is true by
    # construction now that the classification READS the exclusion block — a
    # check of it would be a tautology, and a tautological gate is a §11.4.201
    # bluff. So C4 checks the two CONVERSE properties the derivation cannot
    # make true by itself:
    #   (i)  no PHANTOM exclusion — every documented exclusion names a gitlink
    #        that some .gitmodules in this tree actually declares. This is where
    #        the old C1 "roster names a submodule .gitmodules no longer
    #        declares" half now lives for the third-party set (C6 carries it
    #        for the deps[] set).
    #   (ii) no SELF-EXCLUSION — a documented exclusion whose namespace this
    #        tree demonstrably OWNS is a contradiction: it would drop one of our
    #        own repositories out of C2/C3 silently, which is exactly the
    #        cascade gap §11.4.26 step 6 forbids.
    local phantom="" selfexcl="" u ns
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        u="$(fleet_url "$p")"
        if [ -z "$u" ]; then
            phantom="${phantom} ${p}"
            continue
        fi
        ns="$(url_namespace "$u")" || ns=""
        if [ -n "$ns" ] && in_list "$ns" "$OWNED_NAMESPACES"; then
            selfexcl="${selfexcl} ${p}(${ns})"
        fi
    done <<< "$excluded"
    if [ -n "$phantom" ]; then
        bad "C4 THIRD-PARTY-EXCLUDED — helix-deps.yaml excludes gitlink(s) no .gitmodules in this tree declares:${phantom}"
        echo "         fix: governance is excluding a fleet member that does not exist. Drop the stale"
        echo "              exclusion line, or restore the .gitmodules declaration (§11.4.31 / §11.4.6)."
        rc=1
    fi
    if [ -n "$selfexcl" ]; then
        bad "C4 THIRD-PARTY-EXCLUDED — gitlink(s) documented as third-party but sitting in a namespace this tree OWNS:${selfexcl}"
        echo "         fix: an owned repository excluded from the cascade never gets checked for the four"
        echo "              carriers, so the gap is invisible. Either remove the exclusion (and let C2/C3"
        echo "              cover it) or explain why the namespace is not ours (§4 / §11.4.28(A))."
        rc=1
    fi
    if [ "$rc" -eq 0 ]; then
        ok "C4 THIRD-PARTY-EXCLUDED — $(printf '%s\n' "$excluded" | grep -c .) documented exclusion(s), each naming a really-declared gitlink outside every owned namespace (§4 / §11.4.156(C))"
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
    local converged n c
    for f in $ROOT_CARRIERS; do
        [ -s "${root}/${f}" ] || missing="${missing} ${f}"
    done
    if [ -n "$missing" ]; then
        bad "C5 ROOT-CARRIERS — missing or empty at the project root:${missing} (§11.4.157(A): all five carriers, GEMINI.md included)"
        rc=1
    else
        ok "C5 ROOT-CARRIERS — ${ROOT_CARRIERS} all present at the project root (§11.4.157(A))"
    fi
    # The ratchet, checked BEFORE anything is measured. If the declaration has
    # been pushed past the documented header budget, every verdict below it is
    # worthless — so this is a hard failure of the gate's own configuration, not
    # a finding about the tree.
    if [ "$LOCKSTEP_FROM" -gt "$LOCKSTEP_FROM_MAX" ]; then
        bad "C5 ROOT-LOCKSTEP — LOCKSTEP_FROM=${LOCKSTEP_FROM} exceeds the documented per-agent header budget of ${LOCKSTEP_FROM_MAX} (Constitution.md header table). A lockstep FAIL is never fixed by raising the split; that converts the gate into a bluff (§11.4.6)."
        return 1
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
        echo "              The mirrors are LINE-ALIGNED: if per-agent header text legitimately"
        echo "              needs more room, pad all four to the SAME header length. Do NOT raise"
        echo "              LOCKSTEP_FROM to silence this — ${LOCKSTEP_FROM_MAX} is the hard ceiling and the"
        echo "              ratchet above rejects anything past it."
        rc=1
    else
        ok "C5 ROOT-LOCKSTEP — the four root agent mirrors are byte-identical from line ${LOCKSTEP_FROM} down; shared digest $(printf '%s' "$digests" | head -n1 | awk '{print $1}') (§11.4.157(B))"
    fi

    # ── The anti-slack half: is the DECLARED split as tight as the evidence? ──
    # This is the half whose absence let 19-vs-24 hide. It cannot itself gate —
    # lines above the true convergence point are ALLOWED to differ, so a repo
    # that happens to be more uniform than required is not in violation — but it
    # is printed on every run, so the gap is never invisible again.
    converged=""
    n=1
    while [ "$n" -le "$LOCKSTEP_FROM" ]; do
        c="$(for f in $CARRIERS_AGENT; do
                 tail -n "+${n}" "${root}/${f}" | sha256sum | cut -d' ' -f1
             done | sort -u | grep -c .)"
        if [ "$c" -eq 1 ]; then converged="$n"; break; fi
        n=$((n + 1))
    done

    if [ -z "$converged" ]; then
        # Only reachable when the mirrors differ even at LOCKSTEP_FROM — the
        # FAIL branch above already fired and already named it. Not double
        # counted here (§11.4.3).
        :
    elif [ "$converged" -lt "$LOCKSTEP_FROM" ]; then
        inf "C5 · the mirrors actually converge at line ${converged}, but the gate is declared from ${LOCKSTEP_FROM} — lines ${converged}..$((LOCKSTEP_FROM - 1)) are identical in fact yet UNGATED. That is slack, not a violation (those lines may legitimately carry per-agent text). Tighten deliberately by setting LOCKSTEP_FROM=${converged} if they are shared prose."
    else
        inf "C5 · declared split ${LOCKSTEP_FROM} equals the measured convergence line ${converged} — the gate enforces exactly the range it claims, with no ungated identical remainder (ceiling ${LOCKSTEP_FROM_MAX})"
    fi
    return $rc
}

# ── C6 — the manifest and the real fleet agree, both directions ─────────────
c6_manifest_sync() {
    local hd="${root}/helix-deps.yaml" gm="${root}/.gitmodules"
    local dep_paths excl_paths declared p rc=0 unrecorded="" phantom="" undet=""
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

    # Every membership test below goes through list_has, which reports a grep
    # ERROR as 2 instead of letting it masquerade as "absent". A path whose test
    # could not be performed is collected in $undet and reported as ENV; it is
    # NEVER counted as unrecorded or phantom. See list_has for the measurement
    # that made this necessary.
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        list_has "$dep_paths" "$p"
        case $? in
            0) continue ;;
            2) undet="${undet} ${p}"; continue ;;
        esac
        list_has "$excl_paths" "$p"
        case $? in
            0) continue ;;
            2) undet="${undet} ${p}"; continue ;;
        esac
        unrecorded="${unrecorded} ${p}"
    done <<< "$declared"

    while IFS= read -r p; do
        [ -n "$p" ] || continue
        list_has "$declared" "$p"
        case $? in
            0) ;;
            2) undet="${undet} ${p}" ;;
            *) phantom="${phantom} ${p}" ;;
        esac
    done <<< "$dep_paths"

    if [ -n "$undet" ]; then
        # The two loops test overlapping sets, so one path can fail twice. Report
        # each path once: a duplicated token reads as a bug in the report.
        undet="$(printf '%s\n' $undet | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
        env_ "C6 MANIFEST-FLEET-SYNC — the membership test itself FAILED for: ${undet}"
        echo "         grep returned an ERROR (rc>1), not an answer, so this is a COULD-NOT-DETERMINE"
        echo "         and NOT a finding about helix-deps.yaml or .gitmodules. Neither file has been"
        echo "         shown to be wrong. Re-run; if it persists the fault is in the environment"
        echo "         (resource exhaustion, a killed child), not in the manifest."
        rc=1
    fi
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
    local d gm hd="${root}/helix-deps.yaml" excluded="" p u ns
    local unknown="" ownnest="" found=0
    [ -r "$hd" ] && excluded="$(helix_excluded_paths "$hd")"
    for d in $OWNED_ROOTS; do
        gm="${root}/${d}/.gitmodules"
        [ -f "$gm" ] || continue
        if [ ! -r "$gm" ]; then
            env_ "C7 RECURSION — ${d}/.gitmodules present but unreadable"
            continue
        fi
        while IFS=$'\t' read -r p u; do
            [ -n "$p" ] || continue
            found=$((found+1))
            ns="$(url_namespace "$u")" || ns=""
            if [ -n "$ns" ] && in_list "$ns" "$OWNED_NAMESPACES"; then
                # §11.4.28(C): nested OWN-ORG submodule chains are FORBIDDEN.
                # Documenting one as an exclusion would not make it legal, so
                # this branch is checked BEFORE the exclusion branch.
                ownnest="${ownnest} ${d}/${p}(${ns})"
                continue
            fi
            if grep -qxF "${d}/${p}" <<<"$excluded"; then
                inf "C7 · ${d}/${p} — nested gitlink in namespace ${ns:-<unparseable>}; not an owned namespace, documented as third-party in helix-deps.yaml, excluded from the cascade"
                continue
            fi
            unknown="${unknown} ${d}/${p}"
        done <<< "$(gitmodules_entries "$gm")"
    done
    local rc=0
    if [ -n "$ownnest" ]; then
        bad "C7 RECURSION — nested gitlink(s) in a namespace this tree OWNS — a forbidden own-org chain:${ownnest}"
        echo "         fix: §11.4.28(C) forbids an owned submodule nesting a further own-org submodule. Hoist"
        echo "              it to the project root (<root>/<name>/ or <root>/submodules/<name>/) and declare"
        echo "              it in the root .gitmodules + helix-deps.yaml, so it is reached by C2/C3."
        rc=1
    fi
    if [ -n "$unknown" ]; then
        bad "C7 RECURSION — nested gitlink(s) neither owned nor documented as third-party:${unknown}"
        echo "         fix: record each in helix-deps.yaml's third-party exclusion comment block. CONST-047 /"
        echo "              §11.4.32 make the cascade recursive, so an unclassified nested gitlink is an"
        echo "              unmeasured part of the fleet."
        rc=1
    fi
    [ "$rc" -eq 0 ] || return 1
    ok "C7 RECURSION — ${found} nested gitlink(s) under the $(printf '%s' "$OWNED_ROOTS" | wc -w) owned submodules, all classified from evidence (CONST-047 recursive scope)"
    return 0
}

# ── C8 — the four carriers INSIDE each owned submodule agree with each other ─
c8_submodule_lockstep() {
    local d f p rc=0 subs=0 uninit="" deferred="" broken=""
    local digests distinct majority majcount outliers line

    for d in $OWNED_ROOTS; do
        # An uninitialised submodule is COULD-NOT-DETERMINE, never a pass. C2
        # already ENVs this, so saying so again cannot mask a FAIL: an absent
        # submodule produces no C2 FAIL of its own, and rc is 2 either way.
        if [ ! -d "${root}/${d}" ]; then
            uninit="${uninit} ${d}(absent)"; continue
        fi
        if [ -z "$(find "${root}/${d}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
            uninit="${uninit} ${d}(empty)"; continue
        fi

        # A missing / empty / unreadable carrier is C2's and C3's finding, and
        # theirs ALONE. If C8 raised ENV here it would push envf>0, and
        # run_checks returns 2 BEFORE it looks at fail>0 — so a real C2 FAIL
        # would be reported as "COULD NOT VERIFY" and the violation would
        # vanish. Deferring with a NOTE keeps the rc=1 verdict intact.
        digests=""; local incomplete=""
        for f in $CARRIERS_AGENT; do
            p="${root}/${d}/${f}"
            if [ ! -s "$p" ] || [ ! -r "$p" ]; then
                incomplete="${incomplete} ${f}"; continue
            fi
            line="$(in_submodule_digest "$p")" || line=""
            if [ -z "$line" ]; then
                incomplete="${incomplete} ${f}(digest-failed)"; continue
            fi
            digests="${digests}${line} ${d}/${f}"$'\n'
        done
        if [ -n "$incomplete" ]; then
            # Newline-separated: a bracketed list contains spaces, so word
            # splitting on it would shred one entry into several.
            deferred="${deferred}${d}[${incomplete# }]"$'\n'
            continue
        fi

        subs=$((subs+1))
        distinct="$(printf '%s' "$digests" | awk '{print $1}' | sort -u | grep -c .)"
        [ "$distinct" -eq 1 ] && continue

        # Name the file. A lockstep verdict that does not say WHICH carrier
        # drifted sends its reader to diff four files by hand (§11.4.6).
        majority="$(printf '%s' "$digests" | awk '{print $1}' | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')"
        majcount="$(printf '%s' "$digests" | awk -v m="$majority" '$1==m' | grep -c .)"
        if [ "$majcount" -ge 3 ]; then
            outliers="$(printf '%s' "$digests" | awk -v m="$majority" '$1!=m{printf " %s", $2}')"
            broken="${broken}${d}: ${outliers# } diverges from the other ${majcount}"$'\n'
        else
            outliers="$(printf '%s' "$digests" | awk '{printf " %s", $2}')"
            broken="${broken}${d}: no majority — ${distinct} distinct bodies across${outliers}"$'\n'
        fi
        broken="${broken}$(printf '%s' "$digests" | sed 's/^/             /')"$'\n'
    done

    if [ -n "$uninit" ]; then
        env_ "C8 IN-SUBMODULE-LOCKSTEP — owned submodule(s) not checked out:${uninit}; their internal lockstep cannot be read, so this is COULD NOT VERIFY, never a pass. fix: git submodule update --init --recursive"
        rc=2
    fi
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        inf "C8 · ${line} — carrier(s) missing or unreadable; internal lockstep not evaluated for this submodule. That finding belongs to C2/C3 above and is not double-counted here (§11.4.3)"
    done <<< "$deferred"

    if [ -n "$broken" ]; then
        bad "C8 IN-SUBMODULE-LOCKSTEP — owned submodule(s) whose four agent carriers are NOT in lockstep once the per-agent header is normalised (§11.4.157(B) no silent drift)"
        printf '%s' "$broken" | sed 's/^/         /'
        echo "         fix: a governance edit lands in all four carriers of a submodule or in none. The"
        echo "              per-agent header (title, the constitution/<NAME>.md the pointer names, and the"
        echo "              'This carrier is read by ...' line) is legitimate variance and is normalised"
        echo "              away before comparison — anything this check reports is a REAL body difference."
        echo "              Reproduce one file's normalised digest with:"
        echo "                b=\$(basename <carrier> .md); sed -e \"s/\${b}/@@SELF@@/g\" \\"
        echo "                  -e 's|${LOCKSTEP_READER_RE}|@@READER@@|' <carrier> | sha256sum"
        return 1
    fi
    [ "$rc" -eq 2 ] && return 2
    if [ "$subs" -eq 0 ]; then
        env_ "C8 IN-SUBMODULE-LOCKSTEP — no owned submodule had a complete, readable carrier set; nothing was actually compared (a blind instrument is not a pass, §11.4.201(7)(b))"
        return 2
    fi
    ok "C8 IN-SUBMODULE-LOCKSTEP — all ${subs} owned submodule(s) carry four agent carriers with byte-identical bodies once the per-agent header is normalised (§11.4.157(B))"
    return 0
}

# ── C9 — the manifest's REFS agree with the real gitlinks ───────────────────
# C6 above compares dep NAMES in both directions. That is only half of
# §11.4.31, and the missing half was not theoretical: measured on 2026-09-01 at
# HEAD 16cd4ba8, SEVEN of seven `deps[].ref` values named commits nothing pointed
# at, and this verifier reported 10 PASS / 0 FAIL / rc=0 over it. A manifest can
# name exactly the right submodules and record entirely wrong commits.
# (That HEAD has been renamed twice by authorized content-boundary rewrites:
# `63ac4df` → `fc7574b2` on 2026-09-01 → `16cd4ba8` on 2026-09-02. Only the last
# resolves; the measurement is unchanged. Mapping:
# docs/content-boundary-incident-2026-09-01.md §8B and §11.4.)
#
# WHY A SIBLING SCRIPT AND NOT INLINE HERE. Two hard constraints of this file
# forbid an inline implementation, and both are load-bearing:
#   1. This verifier's contract is "no git command is run at all" (Side-effects
#      header) precisely so it can be pointed at a plain DIRECTORY. A pin check
#      is impossible without git.
#   2. --prove-failure's specimens are `cp` copies inside a mktemp sandbox —
#      not git repositories. An inline git check would return COULD-NOT-VERIFY
#      for every one of them, pushing envf>0 and turning all eight existing
#      mutations into rc=2. The §1.1 proof this file already carries would be
#      destroyed by adding a check to it.
# So the pin half lives in scripts/verify-manifest-pins.sh with its own
# three-valued contract and its own paired §1.1 proof (8 mutations), and C9 is
# the delegation that puts it on the same entry points as everything else here:
# the §11.4.32 sweep's step 1, and the local pre-push hook.
#
# THE SKIP IS DECIDABLE AND NARROW. When the target root is not the top level of
# a git work tree — the case that describes every --prove-failure specimen, and
# nothing else — C9 records a §11.4.3 reasoned NOTE naming what was not checked
# and where it IS checked. It is not a silent pass, and it cannot be reached on
# a real checkout: you cannot make this repository stop being a git work tree
# without destroying it. On the real tree C9 always runs, so the PRE-FLIGHT
# live-run in --prove-failure below exercises it end to end on real data.
c9_manifest_pins() {
    local pin="${REPO_ROOT}/scripts/verify-manifest-pins.sh" out rc toplevel
    if [ ! -r "$pin" ]; then
        env_ "C9 MANIFEST-PIN-SYNC — the pin checker is not readable at ${pin}; the refs half of §11.4.31 cannot be evaluated"
        echo "         fix: restore scripts/verify-manifest-pins.sh. C6 above only compares dep NAMES; with"
        echo "              this file gone the manifest could record any commits at all and stay green."
        return 1
    fi
    if ! command -v git >/dev/null 2>&1; then
        env_ "C9 MANIFEST-PIN-SYNC — git is not on PATH; the live gitlinks cannot be read"
        return 1
    fi
    toplevel="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || toplevel=""
    if [ -z "$toplevel" ] || [ "$(cd "$toplevel" 2>/dev/null && pwd -P)" != "$(cd "$root" && pwd -P)" ]; then
        inf "C9 · skipped — '${root}' is not the top level of a git work tree, so it HAS no gitlinks to compare the manifest's refs against (this is the expected shape of a --prove-failure specimen copy). The pins ARE checked on the real tree: bash scripts/verify-manifest-pins.sh"
        return 0
    fi
    out="$(bash "$pin" --root "$root" --quiet 2>&1)"; rc=$?
    case "$rc" in
        0) ok "C9 MANIFEST-PIN-SYNC — every helix-deps.yaml deps[].ref equals its live gitlink (§11.4.31); re-derive with scripts/verify-manifest-pins.sh"
           return 0 ;;
        1) bad "C9 MANIFEST-PIN-SYNC — helix-deps.yaml records ref(s) that do not match the live gitlink (§11.4.31)"
           printf '%s\n' "$out" | sed 's/^/         /'
           return 1 ;;
        *) env_ "C9 MANIFEST-PIN-SYNC — the pin checker returned rc=${rc} COULD NOT DETERMINE; the refs were not all compared"
           printf '%s\n' "$out" | sed 's/^/         /'
           return 1 ;;
    esac
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
    if ! derive_fleet "$root"; then
        env_ "FLEET-DERIVATION — .gitmodules unreadable at ${root}/.gitmodules; the fleet cannot be classified"
        echo "----------------------------------------------------------------------"
        echo "${GATE}: ${pass} PASS, ${fail} FAIL, ${envf} ENV, ${note} NOTE  (root ${root})"
        echo "⚠ ${GATE}: COULD NOT VERIFY — the fleet roster could not be derived; rc=2, NOT a violation verdict"
        return 2
    fi
    c0_predicate
    c_env_source
    c1_fleet
    c23_owned_carriers
    c4_third_party
    c5_root_lockstep
    c6_manifest_sync
    c7_recursion
    c8_submodule_lockstep
    c9_manifest_pins
    r1_known_unclearable

    echo "----------------------------------------------------------------------"
    echo "${GATE}: ${pass} PASS, ${fail} FAIL, ${envf} ENV, ${note} NOTE  (root ${root})"
    _verdict_emitted=1     # past this line an rc=1 is a real verdict, not a crash
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
#
# ── WHY THE SANDBOX IS SYNTHETIC (a measured defect, not a refactor) ─────────
# Until 2026-09-01 this proof was INOPERATIVE the moment the tree was anything
# other than green, in two independent ways:
#
#   1. the PRE-FLIGHT live run GATED the battery — it `return 1`-ed on rc 1 and
#      on rc 2 — so ONE real cascade violation meant ZERO mutations executed and
#      the proof exited 1 having demonstrated nothing;
#   2. the sandbox was a COPY of the real tree, so the golden-good control
#      inherited every real defect. A drifted root carrier, a submodule carrier
#      that lost its pointer block, an uninitialised owned submodule — each of
#      them is a condition this verifier exists to DETECT, and each of them
#      reddened the control, which returned before the first mutation. Worse,
#      an uninitialised owned submodule made `build_sandbox` itself fail (`cp`
#      of an absent carrier), which exited 2 without printing a single line.
#
# Measured, not inferred: on 2026-09-01 this file was copied into a bare
# directory and `--prove-failure` run there. It exited 2 with 0 of 8 mutations
# executed, and without even reaching its own PRE-FLIGHT report.
#
# The shape below is the one `scripts/verify-check-registry.sh --prove-failure`
# already uses, copied deliberately rather than reinvented:
#
#   * the CONTROL is SYNTHETIC and green BY CONSTRUCTION. Every conformance-
#     relevant byte — the fleet, the manifest, all five root carriers, every
#     module carrier — is GENERATED here so that C1..C9 hold by construction.
#     No state of this repository can redden it.
#   * the LIVE run still happens, FIRST, with the REAL entry point against the
#     REAL tree, because a proof that only ever touches a sandbox while the real
#     verifier cannot start is the other half of the same defect — and this file
#     shipped that half too, on 2026-08-31. It is REPORTED, never gating.
#
# WHAT IS DELIBERATELY *NOT* SYNTHESISED, and why that is still honest: the
# pointer predicate (PC_LIB) is always sourced from the REAL constitution
# submodule, exactly as it is on a live run. It is the INSTRUMENT, not the
# specimen, and letting a sandbox supply its own predicate would be circular
# (the comment on the PC_LIB resolution above says so). If it is missing the
# script exits 2 COULD NOT VERIFY before reaching here, which is the correct
# three-valued answer for a proof that cannot be performed.
#
# COST, STATED (§11.4.6): the mutations no longer name real fleet members, so
# M7 is no longer literally the 2026-09-01 vasic.digital/QWEN.md defect — it is
# that defect's SHAPE, applied to a synthetic module. The property proved is
# identical (C8 detects in-submodule carrier drift and NAMES the outlier); what
# is given up is the coincidence that the fixture matched a historical bug. In
# exchange the battery no longer depends on the real fleet's composition, which
# is the same frozen-assumption defect the derived roster removed from C1.
# ─────────────────────────────────────────────────────────────────────────────

# The synthetic fleet. Two owned modules sharing one namespace (so E1
# tree-shared classifies them), one governance source at whatever path this
# tree's GOVERNANCE_ROOT resolves to, and one third-party module documented in
# the manifest's exclusion block.
SYN_OWNED="syn-alpha syn-beta"
SYN_OWNED_NS="git@github.com:synthetic-owned"
SYN_VENDOR="submodules/syn-vendor"
SYN_VENDOR_URL="git@github.com:synthetic-vendor/syn-vendor.git"

# syn_root_carrier <path> <name> — exactly ${LOCKSTEP_FROM}-1 lines of
# per-agent header, then a body shared verbatim with its three siblings. That IS
# this project's §11.4.157 lockstep mechanism, so C5 passes by construction
# rather than by luck.
#
# The header length is DERIVED from LOCKSTEP_FROM, never written as a literal.
# When the declaration was tightened 24 -> 19 this fixture followed it
# automatically; a hardcoded 23 would have made the synthetic control FAIL and
# aborted the whole battery. A fixture that must be hand-edited whenever the
# thing it tests moves is the same frozen-assumption defect the derived roster
# removed from C1.
#
# The body is deliberately long enough that lines LOCKSTEP_FROM..LOCKSTEP_MAX
# all exist inside it, which is what M12 needs in order to mutate the window
# that used to be ungated.
syn_root_carrier() {
    local path="$1" name="$2" i
    {
        printf '# %s — synthetic root carrier (--prove-failure control)\n' "$name"
        printf '#\n'
        printf '# Generated inside a mktemp sandbox. It is never written to the real tree.\n'
        i=4
        while [ "$i" -le $((LOCKSTEP_FROM - 1)) ]; do
            printf '# per-agent header line %s, deliberately different in each mirror (%s)\n' "$i" "$name"
            i=$((i + 1))
        done
        cat <<BODY
## INHERITED FROM constitution/CLAUDE.md

The shared body starts at line ${LOCKSTEP_FROM} and is byte-identical across the
four root agent mirrors. Everything above this point is the per-agent header
that the lockstep recipe deliberately excludes.

This paragraph exists so that the body extends past line ${LOCKSTEP_FROM_MAX}.
The window between the declared split and that ceiling is exactly the range C5
was once blind to, and M12 mutates a line inside it. Without these lines the
mutation would have nothing to bite on and the proof would be vacuous.
BODY
    } > "$path"
}

# syn_sub_carrier <path> <base> <module> — one module carrier. The four
# carriers of a module differ ONLY in occurrences of their own name and in the
# reader line, which is precisely the variance C8's recipe normalises away — so
# their normalised digests agree by construction.
syn_sub_carrier() {
    local path="$1" base="$2" mod="$3"
    cat > "$path" <<EOF
# ${base}.md — synthetic module carrier for ${mod}

## INHERITED FROM constitution/${base}.md

This carrier is read by the ${base} agent.

All rules in the canonical corpus apply here by pointer, never by copy. The
body below is byte-identical across this module's four carriers once the
per-agent header is normalised, which is exactly the property C8 measures.
EOF
}

build_synthetic_sandbox() {
    local dest="$1" d f base gov_name gov_layout

    # The governance dep must resolve, through helix_dep_paths' own layout
    # mapping, to whatever GOVERNANCE_ROOT this tree derived — never a literal.
    case "$GOVERNANCE_ROOT" in
        submodules/*) gov_name="${GOVERNANCE_ROOT#submodules/}"; gov_layout="grouped" ;;
        *)            gov_name="${GOVERNANCE_ROOT}";             gov_layout="flat" ;;
    esac

    mkdir -p "${dest}/${GOVERNANCE_ROOT}" "${dest}/${SYN_VENDOR}" || return 1

    for f in $CARRIERS_AGENT; do
        syn_root_carrier "${dest}/${f}" "$f" || return 1
    done
    printf '# Constitution.md — synthetic root constitution (proof control)\n' > "${dest}/Constitution.md" || return 1

    # The governance SOURCE only has to be present and non-empty (ENV
    # GOVERNANCE-SOURCE checks -s and nothing more), so it is synthesised too.
    for f in $GOVERNANCE_FILES; do
        printf '# %s — synthetic governance source file (proof control)\n' "$f" \
            > "${dest}/${GOVERNANCE_ROOT}/${f}" || return 1
    done

    for d in $SYN_OWNED; do
        mkdir -p "${dest}/${d}" || return 1
        for f in $CARRIERS_AGENT; do
            base="${f%.md}"
            syn_sub_carrier "${dest}/${d}/${f}" "$base" "$d" || return 1
        done
    done

    {
        for d in $SYN_OWNED; do
            printf '[submodule "%s"]\n\tpath = %s\n\turl = %s/%s.git\n' "$d" "$d" "$SYN_OWNED_NS" "$d"
        done
        printf '[submodule "%s"]\n\tpath = %s\n\turl = git@github.com:synthetic-governance/%s.git\n' \
               "$GOVERNANCE_ROOT" "$GOVERNANCE_ROOT" "$gov_name"
        printf '[submodule "%s"]\n\tpath = %s\n\turl = %s\n' "$SYN_VENDOR" "$SYN_VENDOR" "$SYN_VENDOR_URL"
    } > "${dest}/.gitmodules" || return 1

    {
        printf 'schema_version: 1\n\ndeps:\n'
        for d in $SYN_OWNED; do
            printf '  - name: %s\n    ssh_url: %s/%s.git\n    ref: "%040d"\n    layout: flat\n\n' \
                   "$d" "$SYN_OWNED_NS" "$d" 0
        done
        printf '  - name: %s\n    ssh_url: git@github.com:synthetic-governance/%s.git\n    ref: "%040d"\n    layout: %s\n\n' \
               "$gov_name" "$gov_name" 0 "$gov_layout"
        printf 'language_specific_subtree: false\n\n'
        printf '# ─── Third-party gitlinks — commentary, NOT deps ───\n'
        printf '#   %s  -> %s\n' "$SYN_VENDOR" "$SYN_VENDOR_URL"
    } > "${dest}/helix-deps.yaml" || return 1

    return 0
}

prove_failure() {
    local sandbox pristine rc mut_fails=0 grep_shim m14out m14rc

    echo "${GATE} §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    # ── PRE-FLIGHT: the REAL entry point, on the REAL tree — FIRST, always ────
    # A proof that only ever exercises sandboxed COPIES can go green over a
    # verifier that cannot even START. That is not hypothetical: on 2026-08-31 a
    # `local a="$1" b="${a}/x"` unbound-variable abort killed every live run of
    # this file while this proof still reported PASS, because build_sandbox and
    # the mutations never reached the crashing derivation path.
    #
    # It runs BEFORE anything else this function does — before derive_fleet,
    # before mktemp — because every one of those steps executes the very code
    # the pre-flight exists to vet. A pre-flight placed after them crashes with
    # them and never reports (measured: it exited 2 with no PRE-FLIGHT line).
    #
    # Two distinct failure causes are reported distinctly, so a dirty tree can
    # never be misread as "the gate is a sham" (§11.4.201(1)):
    #   INSTRUMENT  a crash marker on stderr, or an exit code outside the
    #               documented 0/1/2 contract  -> the proof itself is void.
    #   TREE        the instrument ran and returned a real non-zero verdict
    #               -> named as a tree state, with the live run printed.
    # It GATES NOTHING. A proof whose battery a red tree can switch off
    # demonstrates nothing at all, and this file shipped exactly that: rc 1 and
    # rc 2 both `return 1`-ed here, before the first mutation. Only an
    # INSTRUMENT fault — a crash marker, or an exit code outside the documented
    # 0/1/2 contract — is counted as a proof failure, because that genuinely
    # voids the instrument instead of merely describing the tree.
    local live_out live_rc
    live_out="$(bash "$0" --root "$REPO_ROOT" 2>&1)"; live_rc=$?
    if grep -qE 'INTERNAL-FAULT|unbound variable|command not found|syntax error near' <<<"$live_out"; then
        echo "❌ PRE-FLIGHT live-run   — INSTRUMENT FAULT: the real entry point aborted on the real tree"
        echo "                        -> a verifier that cannot start proves nothing (§11.4.201(7)(b))."
        echo "                           Counted as a proof FAILURE; the battery below still runs."
        printf '%s\n' "$live_out" | sed 's/^/        /'
        mut_fails=$((mut_fails+1))
    else
        case "$live_rc" in
            0) echo "✅ PRE-FLIGHT live-run   — real entry point, real tree, rc=0 (instrument runs; tree clean)" ;;
            1) echo "ℹ PRE-FLIGHT live-run   — the real entry point RAN against the real tree and returned rc=1,"
               echo "                          a REAL cascade violation. REPORTED, NOT GATING: the battery below"
               echo "                          uses a synthetic control precisely so a red tree cannot silently"
               echo "                          disable the proof. Fix the violation for the TREE's sake, not this proof's."
               printf '%s\n' "$live_out" | sed 's/^/        /' ;;
            2) echo "ℹ PRE-FLIGHT live-run   — the real entry point RAN against the real tree and returned rc=2,"
               echo "                          COULD NOT VERIFY. REPORTED, NOT GATING; the battery still runs."
               printf '%s\n' "$live_out" | sed 's/^/        /' ;;
            *) echo "❌ PRE-FLIGHT live-run   — INSTRUMENT FAULT: undocumented exit code ${live_rc}; the contract is 0/1/2 only"
               printf '%s\n' "$live_out" | sed 's/^/        /'
               mut_fails=$((mut_fails+1)) ;;
        esac
    fi

    sandbox="$(mktemp -d)" || { echo "${GATE}: ENV — mktemp -d failed" >&2; exit 2; }
    # NOT a second `trap ... EXIT` — that would REPLACE the internal-fault trap
    # installed at the top of this file and silently disarm it for the whole
    # proof. The one EXIT handler cleans this up instead.
    _sandbox_to_clean="$sandbox"

    echo "  sandbox: ${sandbox}"
    echo "  Every mutation below is applied to a THROWAWAY copy of a SYNTHETIC tree that is"
    echo "  green by construction. Neither this repository nor any submodule working tree is"
    echo "  read for content or written to, and no git command is run."
    echo "----------------------------------------------------------------------"

    pristine="${sandbox}/pristine"
    if ! build_synthetic_sandbox "$pristine"; then
        echo "${GATE}: ENV — could not build the synthetic sandbox" >&2
        rm -rf "$sandbox"; _sandbox_to_clean=""; exit 2
    fi

    # Synthetic control. Green BY CONSTRUCTION, so no state of the real tree can
    # reach it. Without a control, "the mutations failed" proves nothing — the
    # sandbox could have been failing for an unrelated reason.
    bash "$0" --root "$pristine" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "✅ CONTROL synthetic-green — unmutated synthetic tree passes (rc=0), by construction"
    else
        echo "❌ CONTROL synthetic-green — unmutated synthetic tree returned rc=${rc}."
        echo "                        -> ABORTING: ZERO mutations were run, so NOTHING below was proved."
        echo "                           This is a fault in the proof harness itself, NOT a statement"
        echo "                           about this repository's governance cascade."
        bash "$0" --root "$pristine" 2>&1 | sed 's/^/        /'
        rm -rf "$sandbox"; _sandbox_to_clean=""
        return 1
    fi

    # mutate_and_assert <label> <description> <expected-rc> <targets> <expect-substr> <fn>
    # <expect-substr> "" means rc alone is the assertion. A non-empty value is
    # additionally required to appear in the mutated run's output — for C8 the
    # exit code is not enough: §11.4.6 asks the verdict to NAME what broke, and a
    # gate that FAILs without naming the file is a gate its reader will ignore.
    mutate_and_assert() {
        local name="$1" desc="$2" want="$3" targets="$4" expect="$5"; shift 5
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
        local mout mrc
        mout="$(bash "$0" --root "$dir" 2>&1)"; mrc=$?
        if [ "$mrc" -ne "$want" ]; then
            echo "❌ ${name} — ${desc}"
            echo "                        -> rc=${mrc}, wanted ${want}. THIS VERIFIER IS A SHAM (§1.1)."
            printf '%s\n' "$mout" | sed 's/^/        /'
            mut_fails=$((mut_fails+1))
            rm -rf "$dir"; return
        fi
        if [ -n "$expect" ] && ! grep -qF -- "$expect" <<<"$mout"; then
            echo "❌ ${name} — ${desc}"
            echo "                        -> rc=${mrc} as wanted, but the verdict never NAMED '${expect}'."
            echo "                           A gate that fails without saying what broke is unactionable (§11.4.6)."
            printf '%s\n' "$mout" | sed 's/^/        /'
            mut_fails=$((mut_fails+1))
            rm -rf "$dir"; return
        fi
        echo "✅ ${name} — ${desc}"
        if [ -n "$expect" ]; then
            echo "                        -> rc=${mrc} (wanted ${want})  [${targets}]  named '${expect}'"
        else
            echo "                        -> rc=${mrc} (wanted ${want})  [${targets}]"
        fi
        rm -rf "$dir"
    }

    # Every mutation targets the SYNTHETIC fleet, so none of them depends on
    # which submodules this repository happens to have today. Each is required
    # to FLIP the verdict AND to NAME the offending thing: an exit code that
    # changes while the message stays silent is a weak proof (§11.4.6).

    # M1 — remove a carrier from an OWNED submodule.
    m1() { rm -f "$1/syn-alpha/QWEN.md"; }
    # M2 — an owned carrier that exists but no longer inherits anything.
    m2() { local d="$1"; grep -v '^## INHERITED FROM ' "${d}/syn-beta/GEMINI.md" > "${d}/g.new" && mv "${d}/g.new" "${d}/syn-beta/GEMINI.md"; }
    # M3 — break the §11.4.157 root lockstep by editing ONE root carrier below
    #      the header split, exactly the silent-drift clause (B) forbids.
    m3() { printf '\nAn edit that landed in one root mirror and nowhere else.\n' >> "$1/GEMINI.md"; }
    # M4 — desync helix-deps.yaml from the fleet (a dep renamed).
    m4() { sed -i 's/^  - name: syn-beta$/  - name: syn-beta-renamed/' "$1/helix-deps.yaml"; }
    # M5 — a submodule joins the fleet unclassified and unrecorded.
    m5() { printf '[submodule "surprise_module"]\n\tpath = surprise_module\n\turl = git@github.com:someone/surprise_module.git\n' >> "$1/.gitmodules"; }
    # M6 — an ENVIRONMENT fault must return 2, never 1. This is the paired proof
    #      for the exit contract itself: an internal error must not masquerade as
    #      a violation verdict.
    m6() { rm -f "$1/${GOVERNANCE_ROOT}/Constitution.md"; }
    # M7 — the §11.4.157 break C2/C3/C5 were all blind to: ONE carrier inside an
    #      owned submodule drifts from its three siblings, while remaining
    #      present, non-empty and a valid pointer carrier. This is the SHAPE of
    #      the real vasic.digital/QWEN.md defect found on 2026-09-01, applied to
    #      a synthetic module. The edit is deliberately placed BELOW the
    #      per-agent header so it cannot be dismissed as legitimate variance.
    m7() { printf '\nA governance sentence that landed in one carrier and nowhere else.\n' \
                  >> "$1/syn-alpha/QWEN.md"; }
    # M8 — an owned submodule that is not checked out must read as COULD NOT
    #      DETERMINE (rc=2), NEVER as a pass. Distinct from M6, which removes the
    #      governance SOURCE; this removes a cascade CONSUMER's contents. Without
    #      this pairing, C8 could "pass" a fleet it never actually looked at.
    m8() { rm -f "$1/syn-beta"/*.md; }
    # M9 — C4 (i) PHANTOM EXCLUSION: governance excludes a gitlink no .gitmodules
    #      declares. Previously unproven — the old real-tree sandbox had no way
    #      to reach this branch without editing the real manifest.
    m9() { printf '#   submodules/ghost-vendor  -> git@github.com:ghost/ghost.git\n' >> "$1/helix-deps.yaml"; }
    # M10 — C4 (ii) SELF-EXCLUSION: a module in a namespace this tree OWNS is
    #      documented as third-party, which would drop one of our own
    #      repositories out of C2/C3 silently. Also previously unproven.
    m10() { printf '#   syn-alpha  -> %s/syn-alpha.git\n' "$SYN_OWNED_NS" >> "$1/helix-deps.yaml"; }
    # M11 — C7 §11.4.28(C) forbidden own-org chain: an owned module nests a
    #      further submodule from an owned namespace. Previously unproven.
    m11() { printf '[submodule "nested-own"]\n\tpath = nested-own\n\turl = %s/nested-own.git\n' \
                   "$SYN_OWNED_NS" > "$1/syn-alpha/.gitmodules"; }
    # M12 — THE BLIND SPOT THIS GATE WAS FIXED FOR (2026-09-01). An edit landed
    #      in ONE root mirror at line 21: below the true end of the per-agent
    #      header (18), but ABOVE the line-24 split C5 used to compare from. The
    #      old recipe hashed `tail -n +24`, so this edit produced FOUR IDENTICAL
    #      digests and C5 reported PASS on a drifted tree. Reproduced on copies
    #      of the real carriers before the fix; it is now a rc=1 FAIL.
    #      Distinct from M3, which appends far below the split and was always
    #      caught — M12 is specifically the 19..23 window, and it must edit IN
    #      PLACE so the file's line count is unchanged and only the content of
    #      the previously-ungated region differs.
    m12() { sed -i "21s/.*/An edit inside the once-ungated window: line 21 of one mirror only./" \
                   "$1/GEMINI.md"; }

    mutate_and_assert "M1 owned-carrier-removed " "syn-alpha/QWEN.md deleted from an OWNED submodule                  " 1 "C2" "syn-alpha/QWEN.md" m1
    mutate_and_assert "M2 owned-pointer-stripped" "syn-beta/GEMINI.md loses its '## INHERITED FROM ' heading          " 1 "C3" "syn-beta/GEMINI.md" m2
    mutate_and_assert "M3 root-lockstep-broken  " "root GEMINI.md edited below line ${LOCKSTEP_FROM}; the other three unchanged  " 1 "C5" "GEMINI.md" m3
    mutate_and_assert "M4 manifest-desynced     " "helix-deps.yaml renames the 'syn-beta' dep; .gitmodules did not    " 1 "C6" "syn-beta-renamed" m4
    mutate_and_assert "M5 fleet-member-unknown  " ".gitmodules gains an unclassified, unrecorded submodule             " 1 "C1+C6" "surprise_module" m5
    mutate_and_assert "M6 source-missing (ENV)  " "${GOVERNANCE_ROOT}/Constitution.md removed — an INTERNAL fault      " 2 "ENV" "Constitution.md" m6
    mutate_and_assert "M7 sub-lockstep-broken   " "syn-alpha/QWEN.md drifts from its 3 siblings; still a valid carrier " 1 "C8" "syn-alpha/QWEN.md" m7
    mutate_and_assert "M8 owned-sub-uninit (ENV)" "syn-beta/ emptied — an uninitialised consumer is NOT a pass         " 2 "C2+C8" "syn-beta" m8
    mutate_and_assert "M9 phantom-exclusion     " "an exclusion naming a gitlink no .gitmodules declares               " 1 "C4" "ghost-vendor" m9
    mutate_and_assert "M10 self-exclusion       " "an OWNED-namespace module documented as third-party                 " 1 "C4" "syn-alpha" m10
    mutate_and_assert "M11 own-org-nesting      " "an owned module nests a further own-org submodule (§11.4.28(C))     " 1 "C7" "syn-alpha/nested-own" m11
    mutate_and_assert "M12 lockstep-blind-window" "root GEMINI.md line 21 edited IN PLACE — the window C5 could not see " 1 "C5" "GEMINI.md" m12

    # ── M13, the RATCHET, proved separately ──────────────────────────────────
    # mutate_and_assert always runs the REAL "$0" against a mutated ROOT, so it
    # can only mutate the specimen, never the instrument. The ratchet is a
    # property of the instrument's own configuration, so it needs a copy of the
    # script with the ceiling deliberately breached, run against the PRISTINE
    # tree. Asserting against the pristine tree is what makes it conclusive: the
    # rc=1 cannot be blamed on anything about the specimen, which is green.
    #
    # Staging matters here, and it took two measured failures to get right.
    # This script derives REPO_ROOT from its OWN dirname, then resolves the
    # governance source by reading ${REPO_ROOT}/.gitmodules and asking which
    # declared submodule actually supplies
    # scripts/gates/lib/pointer_carrier.sh. A copy dropped anywhere else
    # satisfies NEITHER condition and exits 2 COULD NOT VERIFY before reaching
    # C5 — correct three-valued behaviour, but it proves nothing about the
    # ratchet, so the assertion below would report a false negative.
    #
    # The stage therefore reproduces, by SYMLINK to the real tree, exactly what
    # resolution needs: `.gitmodules` (so the governance source is declared),
    # ${GOVERNANCE_ROOT} (so it is supplied), and the SIBLING scripts this gate
    # shells out to — C9 invokes scripts/verify-manifest-pins.sh by path, and a
    # stage without it returns a perfectly correct rc=2 COULD NOT DETERMINE that
    # has nothing to do with the ratchet. That third measured failure is why the
    # siblings are linked: an incomplete stage makes the ASSERTION wrong, not
    # the instrument. The loosened instrument still sources the REAL predicate
    # and the REAL siblings — only its one LOCKSTEP_FROM line differs.
    #
    # Order is load-bearing: siblings are linked FIRST and this script's own
    # name is skipped, then the copy is written. Linking our own name first and
    # `cp`-ing over it would follow the symlink and overwrite the REAL script in
    # the developer's tree.
    local ratchet_stage="${sandbox}/ratchet-stage"
    local ratchet_script="${ratchet_stage}/scripts/verify-governance-cascade.sh" rout rrc sib
    if mkdir -p "${ratchet_stage}/scripts" "${ratchet_stage}/$(dirname "$GOVERNANCE_ROOT")" \
       && ln -sfn "${REPO_ROOT}/${GOVERNANCE_ROOT}" "${ratchet_stage}/${GOVERNANCE_ROOT}" \
       && ln -sfn "${REPO_ROOT}/.gitmodules" "${ratchet_stage}/.gitmodules"; then
        for sib in "${SCRIPT_DIR}"/*.sh; do
            [ -e "$sib" ] || continue
            [ "$(basename "$sib")" = "$(basename "$0")" ] && continue
            ln -sfn "$sib" "${ratchet_stage}/scripts/$(basename "$sib")"
        done
    fi
    if [ -d "${ratchet_stage}/scripts" ] \
       && cp "$0" "$ratchet_script" \
       && sed -i "s/^LOCKSTEP_FROM=${LOCKSTEP_FROM}\$/LOCKSTEP_FROM=$((LOCKSTEP_FROM_MAX + 1))/" "$ratchet_script" \
       && grep -q "^LOCKSTEP_FROM=$((LOCKSTEP_FROM_MAX + 1))\$" "$ratchet_script"; then
        rout="$(bash "$ratchet_script" --root "$pristine" 2>&1)"; rrc=$?
        if [ "$rrc" -eq 1 ] && grep -qF "exceeds the documented per-agent header budget" <<<"$rout"; then
            echo "✅ M13 ratchet-breached     — LOCKSTEP_FROM raised to $((LOCKSTEP_FROM_MAX + 1)) (past the ${LOCKSTEP_FROM_MAX} ceiling) on a GREEN tree"
            echo "                        -> rc=${rrc} (wanted 1)  [C5]  named 'exceeds the documented per-agent header budget'"
        else
            echo "❌ M13 ratchet-breached     — a loosened LOCKSTEP_FROM was NOT rejected"
            echo "                        -> rc=${rrc}, wanted 1 with the ceiling named. The ratchet is decorative (§1.1)."
            printf '%s\n' "$rout" | sed 's/^/        /'
            mut_fails=$((mut_fails+1))
        fi
    else
        echo "❌ M13 ratchet-breached     — could not build the loosened copy of the instrument"
        mut_fails=$((mut_fails+1))
    fi
    rm -rf "$ratchet_stage"

    # ── M14 — THE INSTRUMENT'S OWN THREE-VALUED CONTRACT ─────────────────────
    # Every mutation above breaks the TREE. This one breaks the TOOL, because
    # that is the failure this check actually shipped: `grep -qxF` answers 0
    # found / 1 absent / 2 GREP ITSELF FAILED, and C6 used to fold the 2 into
    # the 1 — reporting a transient resource fault as a governance violation
    # naming a submodule that is declared in both files. See list_has.
    #
    # The shim is as narrow as it can be made: it errors ONLY on the exact argv
    # shape list_has uses (`-qxF -- <pattern>`) and ONLY for one synthetic
    # module, and delegates everything else to the real grep. So this asserts
    # the membership predicate's contract and nothing else.
    grep_shim="${sandbox}/shim"
    if mkdir -p "$grep_shim" && cat > "${grep_shim}/grep" <<'SHIM'
#!/bin/sh
# --prove-failure M14 shim: a grep that ERRORS (rc 2) for exactly one
# list_has lookup. Everything else is delegated to the real grep unchanged.
_dashdash=0; _qxf=0; _target=0
for a in "$@"; do
    case "$a" in
        -qxF) _qxf=1 ;;
        --)   _dashdash=1 ;;
        syn-alpha) _target=1 ;;
    esac
done
if [ "$_qxf" = 1 ] && [ "$_dashdash" = 1 ] && [ "$_target" = 1 ]; then
    echo "grep: simulated resource failure (--prove-failure M14)" >&2
    exit 2
fi
exec /usr/bin/grep "$@"
SHIM
    then
        chmod +x "${grep_shim}/grep"
        m14out="$(PATH="${grep_shim}:$PATH" bash "$0" --root "$pristine" 2>&1)"; m14rc=$?
        if [ "$m14rc" -eq 2 ] && grep -qF "the membership test itself FAILED" <<<"$m14out"; then
            echo "✅ M14 membership-tool-fault — C6's grep ERRORS (rc 2) instead of answering, for 'syn-alpha'"
            echo "                        -> rc=${m14rc} (wanted 2)  [C6]  COULD-NOT-DETERMINE, not a phantom FAIL"
        else
            echo "❌ M14 membership-tool-fault — a FAILED membership test was not reported as rc=2"
            echo "                        -> rc=${m14rc}, wanted 2 naming the failed test. A tool fault is being"
            echo "                           reported as a governance finding — the exact defect list_has fixes."
            printf '%s\n' "$m14out" | sed 's/^/        /'
            mut_fails=$((mut_fails+1))
        fi
    else
        echo "❌ M14 membership-tool-fault — could not build the grep shim"
        mut_fails=$((mut_fails+1))
    fi
    rm -rf "$grep_shim"

    # ── RESTORED CONTROL ─────────────────────────────────────────────────────
    # Each mutation ran on its own throwaway copy, so the pristine synthetic tree
    # must still be green. Showing it again is what separates "every mutation was
    # caught" from "the specimen decayed part-way through the battery".
    bash "$0" --root "$pristine" --quiet >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "✅ CONTROL restored        — the unmutated synthetic tree is still green (rc=0)"
    else
        echo "❌ CONTROL restored        — it no longer passes (rc=${rc}); a mutation leaked out of its copy"
        mut_fails=$((mut_fails+1))
    fi

    rm -rf "$sandbox"; _sandbox_to_clean=""
    echo "----------------------------------------------------------------------"
    if [ "$mut_fails" -eq 0 ]; then
        echo "✅ ${GATE} §1.1 MUTATION PROOF: PASS — the REAL entry point ran against the REAL tree"
        echo "   (reported, never gating), a SYNTHETIC control that is green by construction passed,"
        echo "   and 14 mutations each FLIPPED the verdict while NAMING the offending thing: 10 real"
        echo "   violations as rc=1 (C1..C8 including the in-submodule lockstep break, both C4"
        echo "   converse directions and the §11.4.28(C) own-org chain), 2 environment faults —"
        echo "   a missing governance source and an uninitialised cascade consumer — as rc=2 rather"
        echo "   than accusing the tree or being waved through as a pass, and M13 against the"
        echo "   INSTRUMENT itself: a LOCKSTEP_FROM raised past the ${LOCKSTEP_FROM_MAX} ceiling is refused on a"
        echo "   green tree, so a lockstep FAIL can never be 'fixed' by moving the split."
        echo "   M14 is the OTHER kind of instrument fault: C6's membership grep made to ERROR"
        echo "   rather than answer must come back rc=2 COULD-NOT-DETERMINE, never a phantom"
        echo "   FAIL naming a submodule that is in fact declared in both files."
        echo "   M12 is the 2026-09-01 blind spot: an edit at line 21 of one mirror, which the old"
        echo "   line-24 recipe hashed away into four identical digests. The control is still green."
        return 0
    fi
    echo "❌ ${GATE} §1.1 MUTATION PROOF: FAIL — ${mut_fails} case(s) did not produce the required result"
    return 1
}

if [ -n "$prove" ]; then
    prove_failure; _prc=$?
    _verdict_emitted=1   # reaching here means the proof produced a real verdict
    exit "$_prc"
fi

run_checks
exit $?
