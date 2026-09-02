#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Fail the build on FROZEN ENVIRONMENT ASSUMPTIONS.
#
# WHY
# ---
# scripts/audit-hardcoded-paths.sh catches one narrow class: machine-specific
# absolute PATHS (`/Volumes/T7/...`). It is blind to everything else that ties
# this tree to one box. This is its sibling for the broader class, written
# against the operator directive:
#
#     "Make sure all this is fully dynamic and adaptable based on the
#      environment!"
#
# The failure mode this exists to prevent is NOT a loud crash — it is SILENT
# MISBEHAVIOUR. Three already-observed shapes in this repository:
#
#   * scripts/lumen-reindex.sh reads the Ollama backend via `systemctl show` +
#     `journalctl`. On a host with no systemd both return empty through
#     `2>/dev/null`, `backend_library()` yields "", and the Vulkan refusal that
#     the function exists to trigger NEVER FIRES. The script reports success
#     while doing none of its safety work.
#   * _tools/od/start-daemon.sh hardcodes /Applications/Open Design.app. On
#     Linux the `-x` test fails and the daemon simply never starts, so every
#     downstream diagram generation silently produces nothing.
#   * scripts/ollama-vulkan-remediation.sh writes /etc/sysconfig/ollama. On a
#     Debian-family host that file is /etc/default/ollama; the write "succeeds"
#     into a file systemd never reads.
#
# So `2>/dev/null` is NOT treated as a guard by this audit. It is the delivery
# mechanism for the bug.
#
# WHAT COUNTS AS DYNAMIC
# ----------------------
#   shell   HOST="${OLLAMA_HOST:-http://localhost:11434}"
#   python  os.environ.get("UI_WORKERS", "5")
#   node    process.env.VD_BASE || 'http://localhost:8401'
#   go      os.Getenv("...")
#   caps    command -v systemctl   /  check_command brew  /  case $(uname -s)
#   os      $OSTYPE / process.platform / sys.platform / runtime.GOOS
#
# A literal that sits behind ANY of those is a DEFAULT, not an assumption, and
# is not reported. A bare literal with no such escape hatch is the defect.
#
#   ./scripts/audit-environment-assumptions.sh               # this repo + fleet
#   ./scripts/audit-environment-assumptions.sh /path/to/repo # another checkout
#   ./scripts/audit-environment-assumptions.sh --list        # scanned universe
#   ./scripts/audit-environment-assumptions.sh --classes     # class reference
#   ./scripts/audit-environment-assumptions.sh --allow-list  # effective rules
#   ./scripts/audit-environment-assumptions.sh --no-submodules   # this repo only
#   ./scripts/audit-environment-assumptions.sh --stale-rules     # allow-list rot
#   ./scripts/audit-environment-assumptions.sh --strict-allow-list  # rot fails
#
# Exit 0 = clean · 1 = findings · 2 = could not do its job
# (three-valued convention, same as scripts/lumen-index-doctor.sh — rc 2 must
#  never be collapsed into rc 1: a broken checker is not a clean tree, and it is
#  not a violating tree either.)
#
# THE GITLINK BLIND SPOT (fixed 2026-09-01)
# -----------------------------------------
# This gate used to enumerate files with a bare `git ls-files` at the umbrella
# root. A submodule appears there as a GITLINK — one directory entry, no
# contents — and the `[ -f ... ]` filter below dropped it, because a gitlink is
# a directory, not a regular file. MEASURED before the fix: `--list` reported
# 179 files, ZERO of them inside any of the nine declared submodules. The same
# blind spot was found and fixed in pre-push gate E first; this gate follows
# that fix's approach so the two cannot drift apart.
#
# OWNERSHIP IS DERIVED, NEVER HARDCODED
# -------------------------------------
# The fleet comes from `.gitmodules`, so a submodule added tomorrow is swept
# without editing this file. Ownership comes from `helix-deps.yaml`'s declared
# `deps[].ssh_url` set — guarded in BOTH directions by
# `scripts/verify-governance-cascade.sh` check C6, so it cannot drift from
# `.gitmodules` unnoticed. Same evidence source as `gate_E`.
#
#   OWNED         -> findings are real. They FAIL (rc 1).
#   THIRD-PARTY   -> REPORTED as an out-of-scope NOTE, never a failure and never
#                    silently omitted (§11.4.156(C) scope, §11.4.29 no
#                    mass-editing of vendored source).
#   UNINITIALISED -> rc 2, COULD NOT DETERMINE. Never a pass, never a failure.
#
# `submodules/constitution` is OWNED, deliberately: it is declared in
# `helix-deps.yaml` `deps[]` with an own-org ssh_url, and that declared set IS
# the rule. Carving it out by name would re-introduce the hardcoded list this
# sweep exists to avoid — a hardcoded list of one. This tree cannot FIX a
# finding inside it (§11.4.28 / §11.4.177 — inherited by reference, never
# copied): the fix lands upstream and returns as a gitlink bump. Until then the
# finding is carried as an enumerated baseline.
#
# HONEST BOUNDARY (§11.4.6): the sweep is ONE level deep, from the repository
# that declares the fleet. A gitlink OF a submodule is REPORTED as not-swept,
# never silently skipped, because a nested checkout ships no `helix-deps.yaml`
# and this gate refuses to classify ownership by guesswork.
#
# ALLOW-LIST
# ----------
# Embedded below in ALLOW_RULES (the audit that produced this gate was allowed
# to add exactly two files to the tree, so the list could not be a third file).
# An external `.environment-assumptions-allow`, or $ENV_ASSUMPTIONS_ALLOW, is
# read IN ADDITION when present, so the list can be externalised later without
# touching this script.
#
# Rule syntax — three whitespace-separated fields, MATCH may contain spaces:
#
#     # REASON: <why this literal is genuinely justified>
#     path/to/file            CLASS    substring-of-the-offending-line
#
#     # BASELINE: <known defect, ticket/section reference>
#     path/to/file            CLASS    substring-of-the-offending-line
#
# PATH may end in `*` to prefix-match. CLASS and MATCH may each be `*`.
# EVERY rule MUST be immediately preceded by a `# REASON:` or `# BASELINE:`
# line. A rule without one is a MALFORMED ALLOW-LIST and exits 2 — an
# unexplained suppression is indistinguishable from a bluff.
#
# REASON  = justified forever; invisible in the summary beyond a count.
# BASELINE = a REAL defect, deliberately not fixed yet. Baselines are counted
#            and printed loudly on every clean run so the tree can never go
#            quietly green over known breakage.
#
# ALLOW-LIST ROT  (added 2026-09-01)
# ----------------------------------
# Until this was written the allow-list could only ever GROW. Nothing checked
# whether a rule still suppressed anything, and the measured consequence was
# already in the tree: an agent fixed a `#!/bin/bash` shebang, left the rule
# behind, and noted the same was already true of two sibling copies. Nobody
# would ever have noticed — a rule that suppresses nothing produces no output.
#
# WHY THIS IS NOT MERELY UNTIDY. A rule is a standing exemption AT A PATH, not
# at an occurrence. `foo/bar.sh SHEBANG *` keeps suppressing SHEBANG findings in
# `foo/bar.sh` forever. Delete the file and the rule survives; restore the path
# later — a revert, a re-added directory, a new file that reuses the name — and
# the exemption applies to code no human ever vetted, silently, at rc 0. An
# allow-list that only grows stops being a record of judgements and becomes
# noise, and noise is what a reviewer skims.
#
# THE CENSUS. Every rule is counted as it is used. `isallowed()` therefore no
# longer returns on the FIRST matching rule: it scores every rule that matches,
# and only the first one decides REASON-vs-BASELINE. Without that, a rule
# shadowed by a broader rule above it would read as dead when it is merely
# redundant — a false accusation, and §11.4.6 forbids reporting a state that was
# not measured. Two verdicts are emitted, because they are not the same defect:
#
#   STALE        the rule's PATH is inside this run's scan universe, and the
#                rule still matched nothing. The occurrence it named is GONE.
#                This is rot: delete the rule.
#   PATH-ABSENT  no scanned file matches the rule's PATH at all. Either the file
#                was deleted or renamed (rot), or this particular run did not
#                scan it (`--no-submodules`, an explicit target directory, an
#                uninitialised gitlink). The two are indistinguishable from
#                inside one run, so the verdict SAYS SO rather than picking one.
#
# WHY A NOTE AND NOT A FAILURE, BY DEFAULT. Silence is what caused this, so the
# report is unconditional, unsuppressible, and printed on EVERY run exactly as
# the baselined-occurrence block is. What it is not, by default, is rc 1 — for
# three reasons that are about correctness, not comfort:
#
#   1. The verdict is a function of the INVOCATION, not only of the tree.
#      `--no-submodules` makes every fleet-facing rule look unused; so does
#      pointing the gate at another checkout. A check whose PASS/FAIL flips on
#      an unrelated CLI flag must not be the thing that blocks a push.
#   2. A rule is legitimately unused for the duration of a fix. This tree runs
#      several agents at once; one fixes the defect, and the rule is dead for
#      the minutes before the same agent deletes it. Failing there teaches the
#      wrong lesson — the cheapest way to go green would be to widen the rule
#      or put the defect back.
#   3. Staleness is a property of the LEDGER; the gate's verdict is about the
#      SOURCE. Conflating them makes a clean tree unpushable over bookkeeping.
#
# So the precedent followed is this file's own BASELINE handling — loud on every
# run, never suppressible, not by itself fatal — plus the deliberate escalation
# that `scripts/verify-check-registry.sh --strict` already establishes in this
# repository. `--strict-allow-list` (or ENV_ASSUMPTIONS_STRICT_ALLOW=1) turns
# every STALE row into a finding and exits 1. PATH-ABSENT never escalates: it is
# a could-not-distinguish, and §11.4.6 does not let a maybe become an accusation.
# ------------------------------------------------------------------------------
set -uo pipefail

# ---- target ------------------------------------------------------------------
# Defaults to this script's own repository, but accepts an explicit directory so
# the gate can be pointed at any checkout — and so its own mutation proofs can
# run against throwaway repos instead of the live tree.
TARGET=""
MODE="audit"
SWEEP=1
# Stale allow rules are REPORTED on every run and, by default, do not fail the
# gate. See "ALLOW-LIST ROT" in the header for why that default is deliberate
# and not a softening. `--strict-allow-list` (or ENV_ASSUMPTIONS_STRICT_ALLOW=1
# in the environment, which is how the §1.1 battery drives it) escalates a stale
# rule to a finding, rc 1.
STRICT_ALLOW="${ENV_ASSUMPTIONS_STRICT_ALLOW:-0}"
for arg in "$@"; do
    case "$arg" in
        --list)               MODE="list" ;;
        --classes)            MODE="classes" ;;
        --allow-list)         MODE="allow" ;;
        --help|-h)            MODE="help" ;;
        --no-submodules)      SWEEP=0 ;;
        --prove-failure)      MODE="prove" ;;
        --strict-allow-list)  STRICT_ALLOW=1 ;;
        --stale-rules)        MODE="stale" ;;
        -*)               echo "FATAL: unknown option '$arg'" >&2; exit 2 ;;
        *)                TARGET="$arg" ;;
    esac
done

# Absolute path to THIS file, captured BEFORE the `cd` below. The §1.1 proof
# re-invokes the real entry point from inside a sandbox, and a relative
# ${BASH_SOURCE[0]} stops resolving the moment the working directory moves.
SELF_ABS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

if [ -n "$TARGET" ]; then
    ROOT="$(cd -- "$TARGET" 2>/dev/null && pwd)" \
        || { echo "FATAL: no such directory '$TARGET'" >&2; exit 2; }
else
    ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" \
        || { echo "FATAL: cannot resolve script directory" >&2; exit 2; }
fi
cd "$ROOT" || { echo "FATAL: cannot cd to '$ROOT'" >&2; exit 2; }

# ---- prerequisites (rc 2, never rc 0) ---------------------------------------
for _bin in git awk grep; do
    command -v "$_bin" >/dev/null 2>&1 \
        || { echo "FATAL: required tool '$_bin' not on PATH" >&2; exit 2; }
done
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "FATAL: '$ROOT' is not a git working tree" >&2; exit 2; }

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    DIM=$'\033[2m';    NC=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; DIM=""; NC=""
fi

# ------------------------------------------------------------------------------
# §1.1 PAIRED MUTATION PROOF  (--prove-failure)
#
# WHY IT EXISTS
# -------------
# The header above already said this gate accepts an explicit directory "so its
# own mutation proofs can run against throwaway repos instead of the live tree".
# Until 2026-09-01 no such proof existed: the affordance was built, the proof was
# never written, and `scripts/check-registry.tsv` carried the gap as a `debt`
# row. §1.1 requires the demonstration, and a gate never observed failing is not
# known to work.
#
# WHY THE CONTROL IS SYNTHETIC — this one is not hypothetical
# -----------------------------------------------------------
# THIS GATE HAS BEEN RED ON THIS TREE, TWICE IN ONE DAY. Measured 2026-09-01
# 09:12: rc=1 with 8 findings (GNU `sed -i` in several gate scripts, plus a
# third-party TOOLVER). Measured again 2026-09-01 11:20, after `LLMProvider` and
# `RAG` joined the fleet: rc=1 with 476. Both were triaged and it is rc=0 as of
# 11:55 — which changes NOTHING about this design. Had this proof used the live
# tree as its control — the mistake `verify-governance-cascade.sh` and
# `verify-manifest-pins.sh` both shipped — the control would have failed on
# every run for those hours, ZERO mutations would have executed, and the proof
# would have exited 1 having demonstrated nothing while still reading as
# coverage. A control that is green only while the tree happens to be green is
# not a control. The live run stays a REPORTED pre-flight that cannot disable
# the battery, and the pre-flight branches on rc rather than asserting one.
#
# So the control is a SYNTHETIC throwaway repository, green BY CONSTRUCTION, and
# the live run is a REPORTED pre-flight that cannot disable the battery. The
# shape is copied from `scripts/verify-check-registry.sh --prove-failure`.
#
# Every byte written lands inside a `mktemp -d`. Nothing under the target
# repository is created, modified or removed, so no restore is required.
# ------------------------------------------------------------------------------
if [ "$MODE" = "prove" ]; then
    echo "CM-ENV-ASSUMPTIONS §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    p_fails=0

    # ---- PRE-FLIGHT: the REAL entry point against the REAL tree -------------
    pf_out="$(bash "$SELF_ABS" "$ROOT" 2>&1)"; pf_rc=$?
    case "$pf_rc" in
        0) printf '✅ %-26s the real audit ran against the real tree and returned rc=0 (clean)\n' "PRE-FLIGHT live-run" ;;
        1) printf 'ℹ %-26s the real audit RAN against the real tree and returned rc=1 — REAL\n' "PRE-FLIGHT live-run"
           printf '                           findings exist on this tree TODAY. REPORTED, NOT GATING: this is\n'
           printf '                           exactly the state that would have made a live-tree control run\n'
           printf '                           zero mutations. The synthetic battery below runs regardless.\n' ;;
        2) printf 'ℹ %-26s the real audit RAN and returned rc=2 (could not determine) on the\n' "PRE-FLIGHT live-run"
           printf '                           real tree. REPORTED, NOT GATING; the battery still runs.\n' ;;
        *) printf '❌ %-26s undocumented exit code %s; the contract is 0/1/2 only\n' "PRE-FLIGHT live-run" "$pf_rc"
           p_fails=$((p_fails+1)) ;;
    esac

    SB="$(mktemp -d "${TMPDIR:-/tmp}/envassum-proof.XXXXXX")" \
        || { echo "UNDET: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM

    sgit() { git -c user.name=env-proof -c user.email=env-proof@invalid \
                 -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }

    # Green by construction: two files that KEEP_SUFFIX actually scans, neither
    # carrying any frozen assumption. `git add` suffices — the audit enumerates
    # with `git ls-files`, which reads the INDEX, so no commit is needed.
    mk_control() {
        d="$1"
        rm -rf "$d"; mkdir -p "$d/scripts" "$d/src" || return 1
        sgit -C "." init -q "$d" >/dev/null 2>&1 || return 1
        {
            printf '#!/usr/bin/env bash\n'
            printf 'ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"\n'
            printf 'HOST="${DEMO_HOST:-example.invalid}"\n'
            printf 'echo "$ROOT $HOST"\n'
        } > "$d/scripts/tool.sh"
        printf 'package main\n\nfunc main() {}\n' > "$d/src/main.go"
        sgit -C "$d" add -A >/dev/null 2>&1 || return 1
        return 0
    }

    # p_assert <label> <desc> <want-rc> <needle> <fn...>
    # A mutation that changes the exit code without NAMING the offending thing
    # is a weak proof: its reader cannot act on it (§11.4.6). So the needle is
    # required, not optional.
    #
    # P_ENV carries a one-shot environment assignment into the child and is
    # cleared immediately after, so an opt-in mode cannot leak into the next
    # assertion and quietly change what the rest of the battery proves. It is a
    # variable rather than a flag argument because every existing call site is
    # positional and rewriting all ten to add an argument they do not use would
    # be a larger change than the thing being proved.
    P_ENV=""
    p_assert() {
        label="$1"; desc="$2"; want="$3"; needle="$4"; shift 4
        slug="$(printf '%s' "$label" | tr -cd 'A-Za-z0-9')"
        dir="${SB}/mut_${slug}"
        rm -rf "$dir"
        if ! cp -r "$PRISTINE" "$dir"; then
            printf '❌ %-26s could not copy the control\n' "$label"; p_fails=$((p_fails+1)); P_ENV=""; return
        fi
        if ! "$@" "$dir"; then
            printf '❌ %-26s could not apply the mutation (%s)\n' "$label" "$desc"; p_fails=$((p_fails+1)); rm -rf "$dir"; P_ENV=""; return
        fi
        # shellcheck disable=SC2086  # P_ENV is an internal, deliberately split assignment list
        out="$(env $P_ENV bash "$SELF_ABS" "$dir" 2>&1)"; rc=$?
        P_ENV=""
        if [ "$rc" -ne "$want" ]; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> rc=%s, wanted %s. THIS GATE WOULD BE A SHAM (§1.1).\n' "$rc" "$want"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
            printf '❌ %-26s %s\n' "$label" "$desc"
            printf '                           -> rc=%s as wanted, but the output never NAMED %s.\n' "$rc" "'$needle'"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            p_fails=$((p_fails+1)); rm -rf "$dir"; return
        fi
        printf '✅ %-26s %s\n' "$label" "$desc"
        printf '                           -> rc=%s (wanted %s)  [names %s]\n' "$rc" "$want" "'$needle'"
        rm -rf "$dir"
    }

    PRISTINE="${SB}/pristine"
    if ! mk_control "$PRISTINE"; then
        echo "UNDET: could not build the synthetic control repository" >&2; exit 2
    fi

    echo "  sandbox: ${SB}"
    echo "----------------------------------------------------------------------"

    ctl_out="$(bash "$SELF_ABS" "$PRISTINE" 2>&1)"; ctl_rc=$?
    if [ "$ctl_rc" -eq 0 ]; then
        printf '✅ %-26s unmutated synthetic repository passes (rc=0), by construction\n' "CONTROL synthetic-green"
    else
        printf '❌ %-26s returned rc=%s\n' "CONTROL synthetic-green" "$ctl_rc"
        printf '                           -> ABORTING: ZERO mutations ran, so NOTHING was proved. This is a\n'
        printf '                              fault in the proof harness, not a statement about this tree.\n'
        printf '%s\n' "$ctl_out" | tail -8 | sed 's/^/        /'
        exit 1
    fi

    # ---- the mutations -------------------------------------------------------
    # SHEBANG: an absolute interpreter path instead of /usr/bin/env.
    plant_shebang() {
        d="$1"
        { printf '#!/bin/bash\n'; tail -n +2 "$d/scripts/tool.sh"; } > "$d/scripts/tool.new" \
            && mv "$d/scripts/tool.new" "$d/scripts/tool.sh"
    }
    # ENDPOINT: a host:port literal with no environment override.
    plant_endpoint()  { printf 'BASE_URL="http://127.0.0.1:8401"\n' >> "$1/scripts/tool.sh"; }
    # The SAME endpoint, but env-defaulted — the form the rule asks for. It must
    # NOT fire. This is the pair that shows the detector discriminates rather
    # than merely matching a substring (§11.4.201(7)(a)).
    plant_endpoint_ok() { printf 'BASE_URL="${VD_BASE:-http://127.0.0.1:8401}"\n' >> "$1/scripts/tool.sh"; }

    # A LIVE rule plus a STALE one, in the same file. The live rule suppresses
    # the planted shebang, so the run is otherwise clean; the second names a
    # PATH THAT IS SCANNED with a MATCH that occurs nowhere in it, which is the
    # exact shape of a rule whose defect was fixed and whose row was left
    # behind. Both must be true at once — if the mutant were stale-only, an
    # rc=1 would prove nothing, because the unsuppressed shebang would produce
    # it. Pairing them is what makes the rc attributable to the rot alone.
    allow_stale() {
        plant_shebang "$1" && {
            printf '# REASON: synthetic, justified for the proof\n'
            printf 'scripts/tool.sh SHEBANG *\n'
            printf '\n'
            printf '# BASELINE: synthetic ROT - this MATCH occurs in no scanned line\n'
            printf 'scripts/tool.sh ENDPOINT ZZ-no-such-substring-ZZ\n'
        } > "$1/.environment-assumptions-allow"
    }

    allow_reason()   { plant_shebang "$1" && printf '# REASON: synthetic, justified for the proof\nscripts/tool.sh SHEBANG *\n' > "$1/.environment-assumptions-allow"; }
    allow_baseline() { plant_shebang "$1" && printf '# BASELINE: synthetic known-unfixed defect, finding F-PROOF\nscripts/tool.sh SHEBANG *\n' > "$1/.environment-assumptions-allow"; }
    allow_malformed(){ printf 'scripts/tool.sh SHEBANG *\n' > "$1/.environment-assumptions-allow"; }

    not_a_repo()     { rm -rf "$1/.git"; }
    no_such_dir()    { rm -rf "$1"; }
    empty_universe() { d="$1"; rm -rf "$d"; mkdir -p "$d" && sgit -C "." init -q "$d" >/dev/null 2>&1; }
    uninit_sub()     {
        d="$1"
        printf '[submodule "vendor/thing"]\n\tpath = vendor/thing\n\turl = git@github.com:someone/thing.git\n' > "$d/.gitmodules"
        printf 'schema_version: 1\ndeps:\n  - name: thing\n    ssh_url: git@github.com:someone/thing.git\n'    > "$d/helix-deps.yaml"
        mkdir -p "$d/vendor/thing" || return 1
        sgit -C "$d" add -A >/dev/null 2>&1 || true
        return 0
    }

    p_assert "E1 shebang-violation"  "an absolute interpreter path instead of /usr/bin/env            " 1 "SHEBANG"                plant_shebang
    p_assert "E2 REASON-suppresses"  "the SAME violation, allow-listed with '# REASON:'               " 0 "allow-listed"           allow_reason
    p_assert "E3 BASELINE-is-loud"   "the SAME violation, allow-listed with '# BASELINE:'             " 0 "baselined occurrence"   allow_baseline
    p_assert "E4 endpoint-violation" "a host:port literal frozen in source with no env override       " 1 "ENDPOINT"               plant_endpoint
    p_assert "E5 endpoint-env-ok"    "the SAME endpoint, env-defaulted — the fixed form must NOT fire " 0 "no NEW frozen"          plant_endpoint_ok
    p_assert "E6 malformed-allow"    "an allow rule with no '# REASON:'/'# BASELINE:' above it        " 2 "malformed allow-list"   allow_malformed
    p_assert "E7 target-absent"      "the target directory does not exist — cannot be inspected       " 2 "no such directory"      no_such_dir
    p_assert "E8 not-a-git-tree"     "the target is not a git working tree — nothing to enumerate     " 2 "not a git working tree" not_a_repo
    p_assert "E9 empty-universe"     "zero scannable files — a clean verdict over nothing is a bluff  " 2 "scan universe is empty" empty_universe
    p_assert "E10 uninit-submodule"  "a declared submodule is not checked out — NOT a pass, NOT a fail" 2 "not initialised"        uninit_sub

    # ---- allow-list rot (added 2026-09-01) ----------------------------------
    # Three assertions, because the detector has to be shown doing three
    # different things and any one of them alone would be a weak proof:
    #   E11 it SEES rot and says so on a run that is otherwise clean (rc 0);
    #   E12 the SAME mutant fails when the operator asks it to (rc 1), so the
    #       NOTE-by-default is a policy choice and not an inability to fail;
    #   E13 a LIVE rule under the SAME strict setting stays green — without
    #       this, a detector that simply called every rule stale would pass
    #       E11 and E12 and be worthless.
    p_assert "E11 stale-rule-visible" "an allow rule that suppresses nothing — loud, but NOT fatal       " 0 "STALE allow rule"       allow_stale
    P_ENV="ENV_ASSUMPTIONS_STRICT_ALLOW=1"
    p_assert "E12 stale-rule-strict"  "the SAME rot, escalated by ENV_ASSUMPTIONS_STRICT_ALLOW=1        " 1 "STALE allow rule"       allow_stale
    P_ENV="ENV_ASSUMPTIONS_STRICT_ALLOW=1"
    p_assert "E13 live-rule-strict"   "a rule that DOES suppress — must stay green even under strict    " 0 "no NEW frozen"          allow_reason

    # ---- restored control ----------------------------------------------------
    bash "$SELF_ABS" "$PRISTINE" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '✅ %-26s the unmutated control is still green after the battery (rc=0)\n' "CONTROL restored"
    else
        printf '❌ %-26s the control no longer passes (rc=%s); a mutation leaked out of its copy\n' "CONTROL restored" "$rc"
        p_fails=$((p_fails+1))
    fi

    echo "----------------------------------------------------------------------"
    if [ "$p_fails" -eq 0 ]; then
        echo "✅ CM-ENV-ASSUMPTIONS §1.1 MUTATION PROOF: PASS — the REAL entry point ran against"
        echo "   the REAL tree (reported above, never gating: whatever it returned, that verdict"
        echo "   is why the control below is synthetic and not the live tree), a control green by"
        echo "   construction passed, and the"
        echo "   13 mutations each produced the required THREE-VALUED verdict while NAMING the"
        echo "   offending thing: two distinct detector classes caught as rc=1; the env-defaulted"
        echo "   form of the same endpoint correctly NOT flagged; both suppression kinds honoured"
        echo "   at rc=0 while still naming what they suppressed; five could-not-determine"
        echo "   states as rc=2 — never a pass, never an accusation; and the allow-list ROT"
        echo "   detector shown SEEING a rule that suppresses nothing without failing (E11),"
        echo "   FAILING on the same rot when asked to (E12), and NOT accusing a rule that does"
        echo "   its job under the identical setting (E13). The control is still green."
        exit 0
    fi
    echo "❌ CM-ENV-ASSUMPTIONS §1.1 MUTATION PROOF: FAIL — ${p_fails} case(s) did not behave as required"
    exit 1
fi

# ---- class reference ---------------------------------------------------------
CLASS_DOC='ENDPOINT  host:port literal (backend URL, bound port) with no env override
PARALLEL  CPU / thread / worker / concurrency count frozen to one box
MODEL     LLM or embedding model id, or a vector dimension, frozen in source
OSPATH    OS- or distro-specific filesystem location (/etc/sysconfig, /Applications, ...)
SERVICE   service-manager call (systemctl/journalctl/launchctl) with no capability guard
PKGMGR    package-manager call (apt-get/yum/dnf/pacman/apk/brew) with no capability guard
GNUBSD    tool invocation whose flags differ between GNU coreutils and BSD/macOS
HOSTNAME  a specific machine name baked into source
TOOLVER   toolchain version duplicated away from the manifest that already pins it
GITREF    git remote or branch name written as a literal instead of derived
GPU       GPU / driver / accelerator assumption with no capability guard
SHEBANG   absolute interpreter path instead of /usr/bin/env (except /bin/sh)'

# ---- embedded allow-list -----------------------------------------------------
# Two kinds only. Read the header before adding anything here.
ALLOW_RULES="$(cat <<'ALLOW_EOF'
# REASON: this IS the detector. Its class patterns must literally contain every
# token it searches for (systemctl, /etc/sysconfig, llama-, *.local, sed -i,
# nvidia-smi ...). Exempting the detector from its own patterns is not an
# exemption from the rule - the same precedent as .hardcoded-paths-allow
# exempting scripts/audit-hardcoded-paths.sh.
scripts/audit-environment-assumptions.sh * *

# DELETED 2026-09-02 - the rule `scripts/audit-hardcoded-paths.sh * *` (REASON)
# stood here. The gate reported it STALE and the claim was re-derived by hand
# before deleting: of the twelve class patterns, exactly ONE matches anywhere in
# that file - an OSPATH hit at line 38, and that line is a `#` comment, which
# the scanner blanks for `.sh` before any class is tested. Every other class
# pattern matches zero times and the shebang is already /usr/bin/env. So the
# rule suppressed nothing, while standing as a blanket `* *` exemption over a
# whole file: any literal added to it later would have been pardoned silently,
# at rc 0, with no human ever reading it. Re-derive before restoring it, and if
# it must come back, come back with a precise MATCH rather than `* *` - the
# lesson the two GNUBSD rules below already record the hard way.

# REASON: _tools/pdf/build-pdfs.sh runs each spelling SEPARATELY and validates
# that the OUTPUT is a bare integer before accepting it - portable_mtime, and
# the deliberately independent readback helper inside --prove-mtime. Validating
# output, not exit status, IS the portable form for this pair, so the MATCH
# below is the whole validated two-spelling dispatch rather than a loose token.
#
# The rule that stood here until 2026-09-01 said the opposite and was wrong on
# the facts. It read `_tools/pdf/build-pdfs.sh GNUBSD stat -f %m` and claimed
# the file "already dispatches BSD-first with a GNU fallback". It did not. On
# GNU coreutils `-f` is --file-system and takes no argument, so `%m` is parsed
# as a FILE operand: stat fails on `%m` (stderr, swallowed), SUCCEEDS on the
# real file, writes a filesystem report to STDOUT and exits 1, whereupon the
# `||` fires and the GNU spelling appends the epoch to that report. Measured on
# GNU coreutils 9.4: 244 bytes, not an epoch. Downstream, `[ "$m" -gt ... ]`
# then died with "integer expression expected" on every file after the first,
# so the newest-mtime selection never ran - silently, at rc 0.
#
# Two lessons are encoded in the MATCH string, not just in this prose. First, a
# `||` chain is not a portability dispatch when the losing spelling can
# half-succeed on stdout. Second, the old loose token `stat -f %m` was ALSO a
# substring of that broken one-liner, so this allow-list was suppressing the
# very defect it advertised as the fix - a rule can only be trusted to the
# precision of its pattern. The pattern below does not match the broken form.
# Re-derive both halves: `bash _tools/pdf/build-pdfs.sh --prove-mtime` exits 0
# now and exits 1 when the one-liner is seeded back into portable_mtime.
_tools/pdf/build-pdfs.sh GNUBSD stat -c %Y "$1" 2>/dev/null)" "$(stat -f %m "$1" 2>/dev/null)

# REASON: verify-check-registry.sh runs each spelling SEPARATELY inside its
# _file_mode helper and validates that the OUTPUT is three or four octal digits
# before accepting it; a literal question mark marks could-not-determine rather
# than inventing a mode. Validating output, not exit status, IS the portable
# form for this pair, so the MATCH below is the whole validated two-spelling
# dispatch rather than a loose token.
#
# The rule that stood here until 2026-09-01 matched the bare token stat dash c,
# which is a SUBSTRING OF THE BROKEN FORM as well as of the fixed one - it would
# have suppressed the very defect it advertised as blessing. That is the same
# failure the build-pdfs.sh rule above records, and a rule can only be trusted
# to the precision of its pattern. The MATCH below does not match an || chain.
# It also covers the deliberately duplicated readback probe inside
# --prove-filemode, whose dispatch line is byte-identical by design.
# Re-derive both halves: `bash scripts/verify-check-registry.sh
# --prove-filemode` exits 0 now, and exits 1 when the || chain is seeded back.
scripts/verify-check-registry.sh GNUBSD stat -c %a "$1" 2>/dev/null)" "$(stat -f %Lp "$1" 2>/dev/null)

# REASON: verify-manifest-pins.sh carries the same _file_mode helper and the
# same duplicated readback probe, validated the same way and matched by the same
# precise pattern rather than by the loose token this rule used to carry.
# Re-derive: `bash scripts/verify-manifest-pins.sh --prove-filemode`.
scripts/verify-manifest-pins.sh GNUBSD stat -c %a "$1" 2>/dev/null)" "$(stat -f %Lp "$1" 2>/dev/null)



# BASELINE: known defect F3 - docs/environment-adaptability/AUDIT.md.
# GNU `sed -i` in-place form; BSD/macOS sed requires an explicit backup suffix.
scripts/ollama-vulkan-remediation.sh GNUBSD sed -i

# BASELINE: known defect F6 - docs/environment-adaptability/AUDIT.md.
# GNU `sed -i` inside the mutation harness m4().
scripts/verify-governance-cascade.sh GNUBSD sed -i

# BASELINE: known defect F7 - docs/environment-adaptability/AUDIT.md.
# `readlink -f` is GNU-only; BSD/macOS readlink has no -f.
scripts/setup-agents-wizard.sh GNUBSD readlink -f

# BASELINE: known defect F8 - docs/environment-adaptability/AUDIT.md.
# `sort -V` is GNU-only; BSD sort has no version sort.
scripts/setup-agents-wizard.sh GNUBSD sort -V

# BASELINE: known defect F9 - docs/environment-adaptability/AUDIT.md.
# `stat -c` is GNU-only; the BSD/macOS spelling is `stat -f`.
scripts/test-setup-agents-wizard.sh GNUBSD stat -c

# REASON: test fixture - `sort -V` appears only inside the TITLE STRING of an
# assertion ("B3 launcher selects highest version (sort -V, not lexical)"). No
# sort is invoked on this line. The wizards real `sort -V` call is baselined
# separately as F8 against scripts/setup-agents-wizard.sh.
scripts/test-setup-agents-wizard.sh GNUBSD sort -V

# BASELINE: known defect F10 - docs/environment-adaptability/AUDIT.md.
# /Applications/Open Design.app is macOS-only with NO env override at all.
_tools/od/start-daemon.sh OSPATH /Applications/

# BASELINE: known defect F11 - docs/environment-adaptability/AUDIT.md.
# thinker.local / amber.local are the operators own two machines.
_tools/translate-fleet.sh HOSTNAME *

# BASELINE: known defect F11 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/helixtranslate-container.sh HOSTNAME *

# BASELINE: known defect F12 - docs/environment-adaptability/AUDIT.md.
# /usr/local/bin/unified-translator is the in-container install prefix, but it
# is written as a literal on the host side of the ssh boundary with no override.
_tools/helixtranslate-container/run.sh OSPATH /usr/local/bin/
# BASELINE: known defect F12 (mirror) - docs/environment-adaptability/AUDIT.md.
_tools/helixtranslate-local.sh OSPATH /usr/local/bin/

# DELETED 2026-09-02 - the six BASELINE rows for F13 and F14 stood here,
# carrying 45 baselined ENDPOINT occurrences across 22 files under `_tests/`:
# `_tests/playwright.config.js` and `_tests/visual-effects.config.js` (F13,
# frozen bound ports), and `_tests/tests/*`, `_tests/tools/motion-audit.cjs`,
# `_tests/ui-l10n2-verify.js`, `_tests/visual-effects.spec.js` (F14, frozen base
# URLs). They are gone because the DEFECT is gone, not because the row moved:
# `_tests/env.js` now derives every port and base from the environment
# (VD_PORT/MV_PORT, VD_BASE/MV_BASE, MOTION_*, UI_L10N2_*), and both configs,
# every spec and both standalone drivers read it. That also closes the half of
# F13/F14 no allow rule could express - the port a config BOUND and the base a
# spec REQUESTED were two independent literals that could disagree; they are now
# one value. Measured after the change: the suite runs green on NON-DEFAULT
# ports, which it could not do at all before. See AUDIT.md F13/F14.

# DELETED 2026-09-02 - the nine BASELINE rows for F15 stood here and below,
# carrying 17 baselined MODEL occurrences across nine files under `_tools/gen/`:
# translate_home.py (4), translate_aria_footer.py (3), translate_ui_headroom.py
# (3), translate_ui_chunked.py (2), and repair_ui_terms.py, translate-ui.py,
# translate_ui_all.py, translate_ui_batch.py, translate_ui_slow.py (1 each).
# They are gone because the DEFECT is gone, not because the row moved: every
# frozen model id is now read from the environment with the former literal as
# its documented default - UI_TRANSLATOR_PROVIDER / UI_TRANSLATOR_MODEL for the
# six HelixTranslate engine drivers, UI_HEADROOM_*, ARIA_FOOTER_* and HOME_* for
# the three direct-HTTP drivers, plus UI_REASONING_EFFORT_MODELS for the
# capability test that used to compare against a frozen id with `==`. Two of the
# 17 were DOCSTRING prose (translate_ui_chunked.py:2, translate_home.py:312),
# already recorded in AUDIT.md §4.6 rows 12-13 as non-defects; they were reworded
# to name the variable instead of the literal rather than converted into a
# `# REASON:` row, so the count falls on a real change in both cases. Measured
# after the change: with the variables unset every constant resolves to the exact
# former literal, and with them set the engine argv carries the override - see
# AUDIT.md F15.
# DELETED 2026-09-02 - the rule `_tools/gen/review_ui_all.py MODEL *`
# (BASELINE, citing F15) stood here. The gate reported it STALE and the claim
# was re-derived: the file still exists and is still scanned, and the ONLY
# MODEL-class token in it is groq/llama-3.3-70b on line 3, inside the module
# DOCSTRING. The MODEL class requires a quote character on the same line before
# it counts a model id as CODE rather than prose, and that line carries none, so
# no occurrence was ever suppressed. `git log -p` over the whole history of that
# file shows the docstring line is the only occurrence it has ever had - there
# was never a bare module constant here - which is also why the F15 file list in
# AUDIT.md never named it. A BASELINE that cites a finding id not covering it
# and suppresses nothing is rot twice over: it inflated the recorded debt AND
# stood as a standing MODEL exemption at a path no human would re-read.
# REASON: this is a PROVIDER REGISTRY - each row is (canonical API endpoint,
# api-key env var, that providers own default model). The endpoints are the
# vendors published URLs and the model is overridden by the --model flag that
# the CLI already documents. Nothing here is bound to a machine.
_tools/review_translation.py MODEL *

# BASELINE: known defect F16 - docs/environment-adaptability/AUDIT.md.
# BYOK provider/model/base-url pinned with no override on the prompt driver.
design-system/diagrams/_prompts/build-and-generate.sh * *

# BASELINE: known defect F18 - docs/environment-adaptability/AUDIT.md.
# Go/Node/Ruby versions restated in the workflow instead of read from go.mod,
# _tests/package.json engines, and milosvasic.ru/.ruby-version.
.github/workflows/ci.yml.disabled TOOLVER *
# BASELINE: known defect F18 (mirror) - apt-get assumed as THE package manager.
.github/workflows/ci.yml.disabled PKGMGR *

# BASELINE: known defect F19 - docs/environment-adaptability/AUDIT.md.
# `#!/bin/bash` instead of `#!/usr/bin/env bash`; /bin/bash is absent on NixOS
# and is bash 3.2 on macOS.
upstreams/GitHub.sh SHEBANG *

# BASELINE: known defect F20 - docs/environment-adaptability/AUDIT.md.
# Fixed worker/parallelism counts and a 1200s sleep tuned to one machine.
_tools/watch-deploy.sh PARALLEL *

# REASON: .specify/extensions/superspec is THIRD-PARTY vendored upstream
# (WangX0111/superspec), outside the owned-submodule set. Its pinned
# python-version and installer calls are upstreams to change, not this repos.
.specify/extensions/* * *

# BASELINE: known defect F11 (mirror) - docs/environment-adaptability/AUDIT.md.
# thinker.local / amber.local plus the operators own ssh login are literals.
_tools/distribute-helixtranslate.sh HOSTNAME *

# DELETED 2026-09-02 - the last three F15 BASELINE rows
# (`_tools/gen/repair_ui_terms.py`, `translate_aria_footer.py`,
# `translate_ui_slow.py`, all `MODEL *`) stood here. See the block above for why
# all nine were removed together.

# BASELINE: known defect F22 - docs/environment-adaptability/AUDIT.md.
# /proc/uptime is Linux-only. The `|| echo` keeps it non-fatal, so this is LOW,
# but the started-at marker silently becomes blank on macOS/BSD.
_tools/watch-deploy.sh OSPATH /proc/uptime

# ---- genuinely justified, NOT defects ---------------------------------------
# Everything below this line was hand-checked and is a FALSE POSITIVE of the
# class pattern. Each states why. See the false-positive analysis in
# docs/environment-adaptability/AUDIT.md.

# REASON: the port is env-derived one line earlier (PORT="${OD_PORT:-4321}") and
# 127.0.0.1 is the loopback constant, deliberately chosen so the daemon is not
# reachable off-box. This specific line is a log message, not a binding.
_tools/od/start-daemon.sh ENDPOINT http://127.0.0.1:${PORT}

# REASON: "codestral" here is an entry in the NON-TRANSLATABLE technology-term
# list, alongside "Playwright", "pandoc" and "Jekyll". It configures nothing.
_tools/translate/glossary.json MODEL *

# REASON: this file defines its own `env(name, default)` os.environ wrapper
# (line ~86) and every literal is the last term of an
# `env(X) or cfg.get(Y) or "<literal>"` chain - the precedence is copied from
# the lumen upstream applyEnvOverrides. The literals ARE the documented final
# fallback. (No apostrophes in this block: ALLOW_RULES is a single-quoted here-
# string, and one stray quote would end it and let the rest run as shell.)
scripts/lumen-index-doctor.sh MODEL *
# REASON: as above - `env("OLLAMA_HOST") or cfg.get("host") or "http://..."`.
scripts/lumen-index-doctor.sh ENDPOINT *

# REASON: test fixture, not configuration. This grep PATTERN asserts that the
# wizard never restarts ollama nor writes /etc/sysconfig/ollama; the literal is
# the thing being forbidden.
scripts/test-setup-agents-wizard.sh OSPATH grep -cE
# REASON: test fixture - a synthetic throwaway repo is written with these lines
# to prove the sibling paths audit does NOT flag standard system locations.
scripts/test-setup-agents-wizard.sh OSPATH printf
# REASON: test fixture - port 1 is deliberately unreachable, proving the wizard
# survives an absent ollama backend. A reachable value would break the test.
scripts/test-setup-agents-wizard.sh ENDPOINT OLLAMA_HOST="http://127.0.0.1:1"
ALLOW_EOF
)"

# ---- collect the scan universe ----------------------------------------------
# Generated evidence, prose and translated content are not source: a documented
# example is not a defect (the false-positive rule this project learned the hard
# way when 167 of 187 raw grep hits turned out to be legitimate).
SKIP_PREFIX='^(_content|_analysis|_tests/evidence/|docs/|\.superpowers/|node_modules/|.*/node_modules/|.*/vendor/)'
KEEP_SUFFIX='\.(sh|bash|py|js|mjs|cjs|ts|go|yml|yaml|toml|cfg|conf|json|disabled)$'
SKIP_NAME='(package-lock\.json|Gemfile\.lock|go\.sum|\.min\.(js|css)$)'

# ---- the submodule fleet -----------------------------------------------------
# DERIVED from .gitmodules; ownership DERIVED from helix-deps.yaml. No list of
# submodule names appears anywhere in this file.
FLEET_OWNED=""      # newline-separated submodule paths
FLEET_THIRD=""      # newline-separated "path<TAB>url"
FLEET_UNINIT=""     # newline-separated "path<TAB>reason"
FLEET_UNCLASSED=""  # gitlinks present but not classifiable from this checkout

if [ "$SWEEP" = "1" ] && [ -r "$ROOT/.gitmodules" ]; then
    _paths="$(git config -f "$ROOT/.gitmodules" --get-regexp 'submodule\..*\.path' 2>/dev/null | awk '{print $2}')"
    if [ -n "$_paths" ]; then
        if [ -r "$ROOT/helix-deps.yaml" ]; then
            _owned_urls="$(sed -n -E 's/^[[:space:]]*ssh_url:[[:space:]]*(.+)$/\1/p' \
                           "$ROOT/helix-deps.yaml" 2>/dev/null | tr -d '\r' | sort -u)"
            while IFS= read -r _p; do
                [ -n "$_p" ] || continue
                if [ ! -e "$ROOT/$_p/.git" ] \
                   || ! git -C "$ROOT/$_p" rev-parse --git-dir >/dev/null 2>&1; then
                    FLEET_UNINIT="${FLEET_UNINIT}${_p}	not initialised (no usable .git)
"
                    continue
                fi
                _url="$(git config -f "$ROOT/.gitmodules" --get "submodule.${_p}.url" 2>/dev/null || echo '')"
                if [ -n "$_url" ] && ! printf '%s\n' "$_owned_urls" | grep -qxF "$_url"; then
                    FLEET_THIRD="${FLEET_THIRD}${_p}	${_url}
"
                else
                    FLEET_OWNED="${FLEET_OWNED}${_p}
"
                fi
            done <<EOF
$_paths
EOF
        else
            FLEET_UNCLASSED="$_paths"
        fi
    fi
fi

repo_filelist() {   # $1 = repo path relative to $ROOT ("" = the root itself)
    _rel="$1"; _dir="$ROOT"; _pfx=""
    if [ -n "$_rel" ]; then _dir="$ROOT/$_rel"; _pfx="$_rel/"; fi
    git -C "$_dir" ls-files 2>/dev/null \
        | grep -Ev "$SKIP_PREFIX" \
        | grep -E "$KEEP_SUFFIX" \
        | grep -Ev "$SKIP_NAME" \
        | awk -v p="$_pfx" '$0 != "" { print p $0 }'
}

# The SKIP/KEEP filters are applied to each repository's OWN relative paths, so
# `<submodule>/docs/...` is skipped for the same reason `docs/...` is skipped
# here — and only then is the submodule prefix attached.
FILELIST="$(repo_filelist "")" || true
SWEPT=0
SWEPT_PATHS=""
THIRD_PATHS=""
while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    FILELIST="$FILELIST
$(repo_filelist "$_p")"
    SWEPT=$((SWEPT+1)); SWEPT_PATHS="${SWEPT_PATHS}${_p}
"
done <<EOF
$FLEET_OWNED
EOF
while IFS= read -r _row; do
    [ -n "$_row" ] || continue
    _p="${_row%%	*}"
    THIRD_PATHS="${THIRD_PATHS}${_p}
"
    FILELIST="$FILELIST
$(repo_filelist "$_p")"
    SWEPT=$((SWEPT+1)); SWEPT_PATHS="${SWEPT_PATHS}${_p}
"
done <<EOF
$FLEET_THIRD
EOF

# `git ls-files` also lists gitlinks (submodule directories). Drop anything that
# is not a regular readable file — including files deleted from the work tree.
# Collected through ONE command substitution rather than by appending to a shell
# variable in the loop: at 179 files the quadratic form was invisible, at the
# fleet's 1 526 it was measurable.
SCANNED="$(
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$ROOT/$f" ] || continue
        [ -r "$ROOT/$f" ] || continue
        printf '%s\n' "$f"
    done <<EOF
$FILELIST
EOF
)
"

FILE_COUNT=$(printf '%s' "$SCANNED" | grep -c . || true)

# Per-repository breakdown of the SCANNED universe, so the table and the verdict
# can never describe different populations.
BREAKDOWN=""
_rootn=$FILE_COUNT
while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    _c=$(printf '%s' "$SCANNED" | grep -c "^$_p/" || true)
    _rootn=$((_rootn - _c))
done <<EOF
$SWEPT_PATHS
EOF
BREAKDOWN="$(printf '%-34s %7s  %s' "(umbrella root)" "$_rootn" "self")
"
while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    BREAKDOWN="$BREAKDOWN$(printf '%-34s %7s  %s' "$_p" \
        "$(printf '%s' "$SCANNED" | grep -c "^$_p/" || true)" "OWNED")
"
done <<EOF
$FLEET_OWNED
EOF
while IFS= read -r _row; do
    [ -n "$_row" ] || continue
    _p="${_row%%	*}"
    BREAKDOWN="$BREAKDOWN$(printf '%-34s %7s  %s' "$_p" \
        "$(printf '%s' "$SCANNED" | grep -c "^$_p/" || true)" \
        "THIRD-PARTY (reported, not enforced)")
"
done <<EOF
$FLEET_THIRD
EOF
while IFS= read -r _row; do
    [ -n "$_row" ] || continue
    BREAKDOWN="$BREAKDOWN$(printf '%-34s %7s  %s' "${_row%%	*}" "-" \
        "NOT INITIALISED — could not determine")
"
done <<EOF
$FLEET_UNINIT
EOF

case "$MODE" in
    help)
        grep -E '^#' "${BASH_SOURCE[0]}" | sed -n '2,80p' | sed 's/^# \{0,1\}//'
        exit 0 ;;
    classes)
        printf '%s\n' "$CLASS_DOC"; exit 0 ;;
    list)
        printf '%s' "$SCANNED"
        echo "────────────────────────────────────────────────────────"
        printf '%s' "$BREAKDOWN"
        printf -- '---- %s file(s) in the scan universe\n' "$FILE_COUNT"
        exit 0 ;;
esac

# ANTI-BLUFF: a gate that finds nothing because it looked at nothing is the
# empty-build success this project has already been burned by. Zero files is a
# broken run (rc 2), never a clean one (rc 0).
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "FATAL: scan universe is empty - refusing to report a clean tree over" >&2
    echo "       zero files. Check the SKIP/KEEP filters or the target repo." >&2
    exit 2
fi

# ANTI-BLUFF, regression guard for the gitlink blind spot this fix closed: if
# submodules were swept and contributed NOTHING, the sweep is broken again.
if [ "$SWEPT" -gt 0 ]; then
    SUB_ONLY=0
    while IFS= read -r _p; do
        [ -n "$_p" ] || continue
        _c=$(printf '%s' "$SCANNED" | grep -c "^$_p/" || true)
        SUB_ONLY=$((SUB_ONLY + _c))
    done <<EOF
$SWEPT_PATHS
EOF
    if [ "$SUB_ONLY" -eq 0 ]; then
        echo "FATAL: $SWEPT submodule(s) were swept and contributed ZERO files." >&2
        echo "       That is the exact signature of the gitlink blind spot this" >&2
        echo "       sweep exists to close. Refusing to report a verdict." >&2
        exit 2
    fi
fi

# ---- assemble the effective allow-list --------------------------------------
TMPDIR_SAFE="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMPDIR_SAFE%/}/audit-envassume.XXXXXX")" \
    || { echo "FATAL: cannot create a temporary directory" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT INT TERM

ALLOW_FILE="${ENV_ASSUMPTIONS_ALLOW:-$ROOT/.environment-assumptions-allow}"
printf '%s\n' "$ALLOW_RULES" > "$WORK/allow.raw"
if [ -f "$ALLOW_FILE" ]; then
    printf '\n# ---- external: %s\n' "$ALLOW_FILE" >> "$WORK/allow.raw"
    cat "$ALLOW_FILE" >> "$WORK/allow.raw"
fi

# Validate: every rule needs a REASON/BASELINE on the line directly above it.
# A silent suppression is a bluff, so a malformed list is rc 2, not rc 1.
# The REASON may span several `#` lines; what matters is that the contiguous
# comment block directly above the rule carries one, with nothing between them.
BAD_RULES="$(awk '
    { line = $0 }
    line ~ /^[[:space:]]*$/ { blk = 0; next }
    line ~ /^[[:space:]]*#/ {
        if (line ~ /REASON:/ || line ~ /BASELINE:/) blk = 1
        next
    }
    {
        if (!blk) printf "line %d: %s\n", NR, line
        blk = 0
    }
' "$WORK/allow.raw")"

if [ -n "$BAD_RULES" ]; then
    echo "FATAL: malformed allow-list - every rule needs a '# REASON:' or" >&2
    echo "       '# BASELINE:' comment on the line directly above it." >&2
    printf '%s\n' "$BAD_RULES" | sed 's/^/       /' >&2
    exit 2
fi

if [ "$MODE" = "allow" ]; then
    cat "$WORK/allow.raw"; exit 0
fi

# Normalise to  KIND<TAB>PATH<TAB>CLASS<TAB>MATCH<TAB>SRC<TAB>SRCLINE
#
# SRC/SRCLINE exist for the rot report and nothing else: telling an operator a
# rule is dead without telling them WHERE TO DELETE IT is a finding they cannot
# act on (§11.4.6). `allow.raw` is the embedded ALLOW_RULES followed by the
# external file, so the marker line that separates them also fixes the offset
# that converts a concatenated NR back into a line number in the real file.
awk '
    { line = $0 }
    line ~ /^# ---- external: / {
        srcname = line
        sub(/^# ---- external: /, "", srcname)
        off = NR
        blkkind = ""
        next
    }
    line ~ /^[[:space:]]*$/ { blkkind = ""; next }
    line ~ /^[[:space:]]*#/ {
        if (line ~ /BASELINE:/)    blkkind = "BASELINE"
        else if (line ~ /REASON:/) blkkind = "REASON"
        next
    }
    {
        kind = (blkkind == "BASELINE") ? "BASELINE" : "REASON"
        n = split(line, f, /[[:space:]]+/)
        # f[1] may be empty when the line is indented
        i = (f[1] == "") ? 2 : 1
        p = f[i]; c = f[i+1]
        m = ""
        # MATCH is the remainder of the line after PATH and CLASS.
        rest = line
        sub(/^[[:space:]]+/, "", rest)
        sub(/^[^[:space:]]+[[:space:]]+/, "", rest)   # drop PATH
        sub(/^[^[:space:]]+[[:space:]]*/, "", rest)   # drop CLASS
        m = rest
        if (m == "") m = "*"
        if (c == "") c = "*"
        src = (off ? srcname : "(embedded ALLOW_RULES)")
        sl  = (off ? NR - off : NR)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", kind, p, c, m, src, sl
        blkkind = ""
    }
' "$WORK/allow.raw" > "$WORK/allow.tsv"

printf '%s' "$SCANNED" > "$WORK/files.txt"

# ---- the scan ---------------------------------------------------------------
# ONE awk process over the whole universe. No per-file subshells, no GNU-only
# awk extensions (no ENDFILE, no gensub, no interval quantifiers - mawk 1.3.3
# does not support {n,m}), so the gate is itself free of the assumptions it
# polices and stays fast enough for a pre-push hook.
AWK_PROG='
# pathmatch is the ONE place the PATH-matching convention lives (exact, or a
# trailing `*` prefix match). It was inlined in isallowed(); the rot census
# needs the identical predicate to decide whether a rule PATH is even inside
# this run scan universe, and two copies of a matching rule would eventually
# disagree — at which point the census would accuse rules that are fine.
function pathmatch(ap, path) {
    if (ap == path) return 1
    if (substr(ap, length(ap), 1) == "*" &&
        substr(path, 1, length(ap) - 1) == substr(ap, 1, length(ap) - 1)) return 1
    return 0
}

# isallowed scores EVERY rule that matches, not just the first.
#
# It used to `return 1` on the first hit, which was correct for the verdict and
# wrong for the census: a rule shadowed by a broader rule above it would record
# zero uses and be reported dead when it is merely redundant. The verdict is
# unchanged — `allowkind` is still taken from the FIRST match, so REASON-vs-
# BASELINE precedence is exactly what it was — but every matching rule now gets
# its use counted.
function isallowed(path, cls, line,   i, matched) {
    matched = 0
    for (i = 1; i <= arn; i++) {
        if (!pathmatch(arp[i], path)) continue
        if (arc[i] != "*" && arc[i] != cls) continue
        if (arm[i] != "*" && index(line, arm[i]) == 0) continue
        aru[i]++
        if (!matched) { allowkind = ark[i]; matched = 1 }
    }
    return matched
}

function flush(   i, k, cls, ln, txt) {
    for (i = 1; i <= bn; i++) {
        cls = bc[i]; ln = bl[i]; txt = bt[i]
        # File-scope capability guard clears the three capability classes.
        if ((cls == "SERVICE" || cls == "PKGMGR" || cls == "GPU") && guarded) continue
        if (isallowed(bf[i], cls, txt)) {
            if (allowkind == "BASELINE") { basecount++; basefiles[bf[i]] = 1 }
            else                         { allowcount++ }
            continue
        }
        printf "HIT\t%s\t%d\t%s\t%s\n", bf[i], ln, cls, txt
        hits++
    }
    bn = 0; guarded = 0
}

BEGIN { FS = "\t" }

# ---- pass 0: the allow rules -------------------------------------------------
NR == FNR {
    arn++
    ark[arn] = $1; arp[arn] = $2; arc[arn] = $3; arm[arn] = $4
    ars[arn] = $5; arl[arn] = $6
    aru[arn] = 0
    next
}

# ---- per-file bookkeeping ----------------------------------------------------
FNR == 1 {
    if (cur != "") flush()
    cur = FILENAME
    guarded = 0
    # The scanned universe, recorded for the rot census so it can tell "the
    # defect is gone" from "the file is gone".
    #
    # HONEST BOUNDARY (§11.4.6): this fires per RECORD, so a zero-byte file
    # never reaches it and a rule naming only that file reads as PATH-ABSENT
    # rather than STALE. Both are reported, neither is suppressed, and an empty
    # file cannot carry a finding for a rule to suppress in the first place.
    seen[++seenn] = FILENAME
}

{
    raw = $0
    line = raw

    # SHEBANG is read from the raw first line, before comment blanking.
    if (FNR == 1) {
        if (line ~ /^#![ ]*\/(bin|usr\/bin|usr\/local\/bin)\/(bash|python|python3|node|perl|ruby|zsh|ksh)[ ]*$/) {
            bn++; bf[bn] = FILENAME; bl[bn] = FNR; bc[bn] = "SHEBANG"; bt[bn] = line
        }
    }

    # ---- capability guards are file-scoped ----------------------------------
    if (line ~ /command -v/ || line ~ /check_command/ || line ~ /uname -s/ ||
        line ~ /uname\)/    || line ~ /OSTYPE/        || line ~ /process\.platform/ ||
        line ~ /sys\.platform/ || line ~ /runtime\.GOOS/ || line ~ /type -p /)
        guarded = 1

    # ---- comment blanking, numbering preserved ------------------------------
    name = FILENAME
    sub(/\.disabled$/, "", name)
    sub(/\.disabled-local-only$/, "", name)
    if (name ~ /\.(py|sh|bash|yml|yaml|toml|cfg|conf)$/) {
        if (line ~ /^[[:space:]]*#/) line = ""
    } else if (name ~ /\.(js|mjs|cjs|ts|go)$/) {
        if (line ~ /^[[:space:]]*(\/\/|\*|\/\*)/) line = ""
    }
    if (line == "") next

    # ---- env-override escape hatch ------------------------------------------
    # Applies to the value classes only. No env var can make `sed -i` portable,
    # so GNUBSD / SHEBANG / SERVICE / PKGMGR / GITREF are not exempted here.
    envd = 0
    if (line ~ /\$\{[A-Za-z_][A-Za-z0-9_]*:[-=?]/ ||
        line ~ /os\.environ/     || line ~ /os\.getenv/  ||
        line ~ /process\.env/    || line ~ /os\.Getenv/  ||
        line ~ /System\.getenv/  || line ~ /getenv\(/    ||
        line ~ /ENV\[/)
        envd = 1

    # ---- classes -------------------------------------------------------------
    if (!envd) {
        if (line ~ /\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)/ ||
            line ~ /(localhost|127\.0\.0\.1|0\.0\.0\.0):[0-9]/ ||
            line ~ /[Pp][Oo][Rr][Tt][ ]*[:=][ ]*[0-9][0-9][0-9][0-9]/)
            add("ENDPOINT", raw)

        if (line ~ /(max_workers|maxWorkers|NUM_PARALLEL|OMP_NUM_THREADS|GOMAXPROCS|num_thread|MAXPAR|CONCURRENCY|FLEET_PARALLEL)[ ]*[:=][ ]*["'"'"']?[0-9]/ ||
            line ~ /[ ]-j[0-9]/ || line ~ /--jobs[ =][0-9]/ ||
            line ~ /--max-old-space-size=[0-9]/ ||
            line ~ /[ ]sleep [0-9][0-9][0-9]/)
            add("PARALLEL", raw)

        # A model id only counts as CODE when it is a quoted literal. The same
        # token in prose (a module docstring explaining which model was used) is
        # documentation, not a frozen assumption - see the false-positive rule
        # in docs/environment-adaptability/AUDIT.md.
        # A variable whose NAME says "fallback"/"default" is declaring the last
        # resort of an env/config precedence chain, not freezing a choice.
        isfallback = (line ~ /^[[:space:]]*[A-Za-z_]*([Ff]allback|[Dd]efault|DEFAULT|FALLBACK)[A-Za-z_]*[[:space:]]*=/)
        if (!isfallback && ((line ~ /["'"'"']/ &&
             line ~ /(llama-[0-9]|llama3|mistral-[a-z]|codestral|nomic-embed|jina-embeddings|command-r|glm-[0-9]|gpt-oss-|zai-glm|qwen[0-9]|all-minilm|text-embedding-|deepseek-)/) ||
            line ~ /(EMBED_DIM|embedding_dim|n_dims|vector_size)[ ]*[:=][ ]*[0-9]/))
            add("MODEL", raw)

        # A path is a PROBE, not an assumption, when the line either tests for
        # its existence or lists it alongside the sibling layouts of other
        # distributions. Flagging a working `for f in /etc/sysconfig/x
        # /etc/default/x /etc/conf.d/x` loop would punish the correct fix.
        nprobe = 0
        if (line ~ /\/etc\/sysconfig/) nprobe++
        if (line ~ /\/etc\/default/)   nprobe++
        if (line ~ /\/etc\/conf\.d/)   nprobe++
        isprobe = (nprobe > 1) || (line ~ /-[defrx][ ]+["$]*\/(etc|usr|opt|Applications|Library|proc)/)
        if (!isprobe &&
            line ~ /(\/etc\/sysconfig\/|\/etc\/default\/[a-z]|\/etc\/init\.d\/|\/Applications\/|\/Library\/|\/System\/Library|\/opt\/homebrew|\/usr\/local\/bin\/[a-z]|\/usr\/local\/lib\/[a-z]|\/proc\/[a-z]|C:\\\\)/)
            add("OSPATH", raw)

        if (line ~ /[a-z0-9][a-z0-9-]*\.(local|lan|home\.arpa)([^a-zA-Z0-9]|$)/ &&
            line !~ /localhost/)
            add("HOSTNAME", raw)

        if (line ~ /(go-version|node-version|ruby-version|python-version|java-version)[ ]*:[ ]*["'"'"']?[0-9]/ ||
            line ~ /(golang|node|ruby|python):[0-9]+\.[0-9]+/ ||
            line ~ /nvm use [0-9]/)
            add("TOOLVER", raw)

        if (line ~ /(nvidia-smi|CUDA_VISIBLE_DEVICES|GGML_VK_|HSA_OVERRIDE|rocm-smi|\/dev\/dri|\/dev\/nvidia)/)
            add("GPU", raw)
    }

    if (line ~ /(systemctl |journalctl |launchctl |rc-service |\/etc\/systemd)/ ||
        line ~ /service [a-z][a-z-]* (start|stop|restart|status)/)
        add("SERVICE", raw)

    if (line ~ /(apt-get |apt install|yum install|dnf install|pacman -S|apk add|brew install|zypper install)/)
        add("PKGMGR", raw)

    if (line ~ /(sed -i[ "'"'"']|readlink -f|stat -c |date -d |date --date|grep -P |xargs -r |sort -V|mktemp -p |du -b |cp --parents|base64 -w)/)
        add("GNUBSD", raw)

    if (line ~ /git [a-z-]+ [^;|&]*(origin|upstream)[ \/]/ ||
        line ~ /(origin|upstream)\/(main|master|develop)/ ||
        line ~ /refs\/heads\/(main|master)/)
        add("GITREF", raw)
}

function add(cls, txt) {
    bn++; bf[bn] = FILENAME; bl[bn] = FNR; bc[bn] = cls; bt[bn] = txt
}

END {
    if (cur != "") flush()
    printf "SUMMARY\t%d\t%d\t%d\n", hits, allowcount, basecount
    for (f in basefiles) printf "BASEFILE\t%s\n", f

    # ---- allow-list rot census ----------------------------------------------
    # A rule that scored zero uses suppressed nothing on this run. Which of the
    # two verdicts it earns depends on whether its PATH is even in the universe
    # that was scanned — see "ALLOW-LIST ROT" in the header. The inner loop is
    # over the scanned universe and runs only for rules that already scored
    # zero, so the cost is (dead rules x files), not (rules x files).
    for (i = 1; i <= arn; i++) {
        if (aru[i] > 0) continue
        covered = 0
        for (j = 1; j <= seenn; j++) {
            if (pathmatch(arp[i], seen[j])) { covered = 1; break }
        }
        printf "STALE\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
            (covered ? "STALE" : "PATH-ABSENT"), \
            ark[i], arp[i], arc[i], arm[i], ars[i], arl[i]
    }
}
'

# Relative paths on purpose: we are already cd'd to $ROOT, awk's FILENAME then
# matches the allow-list rules verbatim and the report needs no path surgery.
#
# A quoted ARRAY expansion, not `$(cat ...)`: once the fleet is swept, tracked
# filenames containing spaces enter the universe (workshop/ has them), and word
# splitting would hand awk a set of paths that do not exist.
AFILES=()
while IFS= read -r _af; do
    [ -n "$_af" ] || continue
    AFILES[${#AFILES[@]}]="$_af"
done < "$WORK/files.txt"
RESULT="$(awk "$AWK_PROG" "$WORK/allow.tsv" "${AFILES[@]}" 2>"$WORK/awk.err")"
AWK_RC=$?
if [ $AWK_RC -ne 0 ]; then
    echo "FATAL: the scan itself failed (awk rc=$AWK_RC)" >&2
    sed 's/^/       /' "$WORK/awk.err" >&2
    exit 2
fi

# ---- report ------------------------------------------------------------------
printf '%s\n' "$RESULT" | grep '^HIT' > "$WORK/hits.all" || true

SUMMARY_LINE="$(printf '%s\n' "$RESULT" | grep '^SUMMARY' | head -1)"
[ -n "$SUMMARY_LINE" ] || { echo "FATAL: scan produced no summary record" >&2; exit 2; }

ALLOWED=$(printf '%s' "$SUMMARY_LINE" | cut -f3)
BASELINED=$(printf '%s' "$SUMMARY_LINE" | cut -f4)

# ---- allow-list rot ----------------------------------------------------------
printf '%s\n' "$RESULT" | grep '^STALE' > "$WORK/stale.all" || true
grep -c '	STALE	' "$WORK/stale.all" > "$WORK/n.stale" 2>/dev/null || true
grep -c '	PATH-ABSENT	' "$WORK/stale.all" > "$WORK/n.absent" 2>/dev/null || true
STALE_N=$(cat "$WORK/n.stale" 2>/dev/null || echo 0);  STALE_N=${STALE_N:-0}
ABSENT_N=$(cat "$WORK/n.absent" 2>/dev/null || echo 0); ABSENT_N=${ABSENT_N:-0}
RULE_N=$(grep -c . "$WORK/allow.tsv" || true)

# Renders one rot section. Kept as a function because `--stale-rules` and the
# tail of a normal run print the identical thing, and two copies of a report
# drift until they describe different states.
print_rot() {   # $1 = verdict token to print
    _v="$1"; _cur=""
    while IFS="$(printf '\t')" read -r _tag verdict kind rpath rcls rmatch rsrc rline; do
        [ "$verdict" = "$_v" ] || continue
        if [ "$rsrc" != "$_cur" ]; then
            printf '     %sin %s:%s\n' "$DIM" "$rsrc" "$NC"
            _cur="$rsrc"
        fi
        printf '       line %-5s %-8s %s %s %s\n' "$rline" "$kind" "$rpath" "$rcls" "$rmatch"
    done < "$WORK/stale.all"
}

if [ "$MODE" = "stale" ]; then
    printf 'ALLOW-LIST ROT CENSUS — %d rule(s) in the effective allow-list\n' "$RULE_N"
    printf 'scanned %d file(s) across %d repositor%s\n' "$FILE_COUNT" "$((SWEPT + 1))" \
        "$( [ "$((SWEPT+1))" -eq 1 ] && echo y || echo ies )"
    echo "────────────────────────────────────────────────────────"
    printf 'STALE — path IS scanned, rule matched nothing: %d\n' "$STALE_N"
    print_rot STALE
    printf 'PATH-ABSENT — no scanned file matches the rule path: %d\n' "$ABSENT_N"
    print_rot PATH-ABSENT
    echo "────────────────────────────────────────────────────────"
    [ "$STALE_N" -eq 0 ] && exit 0
    exit 1
fi

# Split the findings by OWNERSHIP. A finding in a third-party gitlink is real
# and is printed, but it is not this tree's to fix and does not fail the gate.
: > "$WORK/hits.tsv"
: > "$WORK/hits.third"
printf '%s' "$THIRD_PATHS" > "$WORK/third.txt"
if [ -s "$WORK/third.txt" ] && [ -s "$WORK/hits.all" ]; then
    awk -F'\t' -v OW="$WORK/hits.tsv" -v TH="$WORK/hits.third" '
        NR == FNR { if ($0 != "") t[++n] = $0 "/"; next }
        {
            own = 1
            for (i = 1; i <= n; i++) if (index($2, t[i]) == 1) { own = 0; break }
            if (own) print >> OW; else print >> TH
        }
    ' "$WORK/third.txt" "$WORK/hits.all"
else
    cp "$WORK/hits.all" "$WORK/hits.tsv" 2>/dev/null || true
fi

HITS=$(grep -c . "$WORK/hits.tsv" || true)
NOTES=$(grep -c . "$WORK/hits.third" || true)

if [ -s "$WORK/hits.tsv" ]; then
    cur_file=""
    while IFS="$(printf '\t')" read -r _tag path lineno cls text; do
        if [ "$path" != "$cur_file" ]; then
            printf '%s❌ %s%s\n' "$RED" "$path" "$NC"
            cur_file="$path"
        fi
        # Pure parameter expansion: `printf | sed | cut` spawned THREE
        # processes per finding line, which at fleet scale was the single
        # largest cost in the report phase.
        trimmed="${text#"${text%%[![:space:]]*}"}"
        trimmed="${trimmed:0:96}"
        printf '     %s%-9s%s line %-5s %s\n' "$YELLOW" "$cls" "$NC" "$lineno" "$trimmed"
    done < "$WORK/hits.tsv"
fi

echo "────────────────────────────────────────────────────────"
printf '%sscanned %d file(s) across %d repositor%s · %d class(es)%s\n' \
    "$DIM" "$FILE_COUNT" "$((SWEPT+1))" \
    "$( [ "$((SWEPT+1))" -eq 1 ] && echo y || echo ies )" \
    "$(printf '%s\n' "$CLASS_DOC" | grep -c .)" "$NC"

if [ "$BASELINED" -gt 0 ]; then
    printf '%s⚠️  %d baselined occurrence(s) — REAL, KNOWN, UNFIXED defects in:%s\n' \
        "$YELLOW" "$BASELINED" "$NC"
    printf '%s\n' "$RESULT" | grep '^BASEFILE' | cut -f2 | sort | sed 's/^/     /'
    printf '%s   see docs/environment-adaptability/AUDIT.md — a baseline is a debt,%s\n' "$YELLOW" "$NC"
    printf '%s   not a justification. Do not add to it without a finding id.%s\n' "$YELLOW" "$NC"
fi

# ALLOW-LIST ROT — printed on EVERY run, exactly like the baseline block above
# and for the same reason: a suppression nobody can see is indistinguishable
# from a bluff. Whether it also FAILS is a separate, deliberate decision; see
# "ALLOW-LIST ROT" in the header for why the default is a loud NOTE.
if [ "$STALE_N" -gt 0 ]; then
    printf '%s⚠️  %d STALE allow rule(s) of %d — the occurrence each one names is GONE,%s\n' \
        "$YELLOW" "$STALE_N" "$RULE_N" "$NC"
    printf '%s   yet the exemption still stands at that path. Delete them:%s\n' "$YELLOW" "$NC"
    print_rot STALE
    printf '%s   A rule is an exemption at a PATH, not at an occurrence: recreate the%s\n' "$YELLOW" "$NC"
    printf '%s   path and unvetted code inherits it silently. (A rule can also read as%s\n' "$YELLOW" "$NC"
    printf '%s   stale because a file-scope capability guard already clears its class —%s\n' "$YELLOW" "$NC"
    printf '%s   it suppresses nothing either way.)  Escalate with --strict-allow-list.%s\n' "$YELLOW" "$NC"
fi
if [ "$ABSENT_N" -gt 0 ]; then
    printf '%sNOTE — %d allow rule(s) name a path NOT in this run scan universe.%s\n' \
        "$YELLOW" "$ABSENT_N" "$NC"
    printf '%sEither the file is gone (rot — delete the rule) or this run did not scan%s\n' "$YELLOW" "$NC"
    printf '%sit (--no-submodules, an explicit target, an uninitialised gitlink). ONE run%s\n' "$YELLOW" "$NC"
    printf '%scannot tell those apart, so this is never escalated to a finding:%s\n' "$YELLOW" "$NC"
    print_rot PATH-ABSENT
fi

if [ "$NOTES" -gt 0 ]; then
    printf '%sNOTE — %d frozen environment assumption(s) in THIRD-PARTY gitlink(s).%s\n' \
        "$YELLOW" "$NOTES" "$NC"
    printf '%sOUT OF SCOPE per §11.4.156(C) / §11.4.29 — reported so they are never%s\n' "$YELLOW" "$NC"
    printf '%ssilently omitted; NOT edited here, NOT a failure of this tree:%s\n' "$YELLOW" "$NC"
    cur_file=""
    while IFS="$(printf '\t')" read -r _tag path lineno cls text; do
        if [ "$path" != "$cur_file" ]; then
            printf '  %s\n' "$path"
            cur_file="$path"
        fi
        trimmed="${text#"${text%%[![:space:]]*}"}"
        trimmed="${trimmed:0:96}"
        printf '       %-9s line %-5s %s\n' "$cls" "$lineno" "$trimmed"
    done < "$WORK/hits.third"
fi

if [ -n "$FLEET_UNCLASSED" ]; then
    printf '%sNOT SWEPT — gitlink(s) declared here, but this checkout ships no%s\n' "$YELLOW" "$NC"
    printf '%shelix-deps.yaml, so ownership cannot be derived and is not guessed:%s\n' "$YELLOW" "$NC"
    printf '%s\n' "$FLEET_UNCLASSED" | sed 's/^/     /'
fi

if [ -n "$FLEET_UNINIT" ]; then
    printf '%s⚠️  COULD NOT DETERMINE — submodule(s) not initialised:%s\n' "$RED" "$NC"
    printf '%s' "$FLEET_UNINIT" | sed 's/	/: /' | sed 's/^/     /'
    printf '%s   Their contents are unknown, so this run cannot report a clean tree%s\n' "$RED" "$NC"
    printf '%s   and cannot report a violating one. NOT a pass, NOT a failure.%s\n' "$RED" "$NC"
    echo   "   Run: git submodule update --init --recursive"
    [ "$HITS" -gt 0 ] && printf '%s❌ %d frozen environment assumption(s) also found in owned repos%s\n' \
        "$RED" "$HITS" "$NC"
    exit 2
fi

if [ "$HITS" -eq 0 ]; then
    if [ "$STRICT_ALLOW" = "1" ] && [ "$STALE_N" -gt 0 ]; then
        printf '%s❌ %d STALE allow rule(s) — escalated to a finding by%s\n' \
            "$RED" "$STALE_N" "$NC"
        printf '%s   --strict-allow-list / ENV_ASSUMPTIONS_STRICT_ALLOW=1.%s\n' "$RED" "$NC"
        printf '%s   The SOURCE is clean: no NEW frozen environment assumptions. The LEDGER%s\n' "$RED" "$NC"
        printf '%s   is not — the rules listed above suppress nothing and must be deleted.%s\n' "$RED" "$NC"
        exit 1
    fi
    printf '%s✅ no NEW frozen environment assumptions%s' "$GREEN" "$NC"
    [ "$ALLOWED" -gt 0 ] && printf ' (%d justified occurrence(s) allow-listed)' "$ALLOWED"
    echo
    exit 0
fi

printf '%s❌ %d frozen environment assumption(s)%s\n' "$RED" "$HITS" "$NC"
echo
echo "Derive it from the environment instead of freezing it:"
echo "  shell   HOST=\"\${OLLAMA_HOST:-http://localhost:11434}\""
echo "  python  os.environ.get(\"UI_WORKERS\", \"5\")"
echo "  node    process.env.VD_BASE || 'http://localhost:8401'"
echo "  caps    command -v systemctl >/dev/null 2>&1 || fallback"
echo "  os      case \"\$(uname -s)\" in Darwin) ...;; Linux) ...;; esac"
echo
echo "\`2>/dev/null\` is NOT a guard — it is how the bug stays silent."
echo
echo "If an occurrence is genuinely justified, add a rule to ALLOW_RULES in"
echo "  scripts/audit-environment-assumptions.sh   (or .environment-assumptions-allow)"
echo "with a '# REASON:' line above it. A known-but-unfixed defect uses"
echo "'# BASELINE:' instead and must carry an AUDIT.md finding id."
exit 1
