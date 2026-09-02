#!/usr/bin/env bash
# verify-all-constitution-rules.sh — the §11.4.32 post-constitution-pull
# validation sweep for the `vasic` umbrella.
#
# ── Purpose ──────────────────────────────────────────────────────────────────
# §11.4.32 (`submodules/constitution/Constitution.md:2026`) names this file
# verbatim:
#
#   "Validation sweep contract. The sweep is implemented as
#    `scripts/verify-all-constitution-rules.sh` (canonical name) which:
#     1. Re-runs the existing governance-cascade verifier
#        (`scripts/verify-governance-cascade.sh`) ...
#     2. For each rule whose enforcement gate is implementable
#        programmatically ... the sweep runs the corresponding gate against the
#        post-pull tree.
#     3. Any failure produces a directed FAIL entry naming the rule ...
#    Operator-explicit manual invocation MUST also be available
#    (`./scripts/verify-all-constitution-rules.sh`)."
#
# and its anti-bluff clause:
#
#   "A sweep that exits PASS without actually running every implementable gate
#    is a §11.4.32 violation."
#
# So: gates are DISCOVERED, never hardcoded. Add a gate upstream, pull the
# submodule, and this sweep picks it up with no edit here. Nothing is
# suppressed: a known-excluded finding still FAILs and still makes the sweep
# exit non-zero — exclusion is recorded in Constitution.md so a reader can tell
# an excluded finding from a regression, and is NEVER a verdict change.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/verify-all-constitution-rules.sh [--root <project-root>] [--quiet]
#     --root <dir>   project root to sweep (default: this script's parent dir).
#                    Mirrors the flag every gate in the family already takes.
#     --quiet        one line per gate instead of the gate's own output;
#                    FAIL / ERROR detail is ALWAYS shown regardless.
#     --list         print the discovered gates + their resolved invocation and
#                    exit 0 without running anything.
#     --update-ledger regenerate scripts/constitution-gate-ledger.tsv from live
#                    discovery + the live constitution pin, print what changed,
#                    and exit 0. This is the ONLY way the expected-gate baseline
#                    moves, so a population change always lands in a git diff.
#     --prove-failure run the §1.1 paired mutation proof for THIS sweep against a
#                    throwaway synthetic tree; the real tree is never written to.
#
#   Environment:
#     GATE_TIMEOUT   per-gate wall-clock cap in seconds (default 900). Applied
#                    only when coreutils `timeout` is on PATH; otherwise the
#                    sweep says so rather than pretending a cap is in force.
#     OD_THEME_GLOBS / OD_TOKEN_GLOBS / OD_VISREG_GLOBS / OD_MANIFEST_GLOBS
#                    consumer-registered inputs for CM-OPENDESIGN-UI-SYSTEM
#                    (§11.4.35). Bound below with this repository's real
#                    design-system layout; an operator export overrides them.
#
# ── How each gate's invocation is resolved (dynamically, from the gate) ──────
#   1. If the gate's arg parser offers `--selftest)`  -> run `--selftest`.
#      (This is how `lib/pointer_carrier.sh` — a sourced predicate, not a
#      standalone gate — documents its own runnable check.)
#   2. Else if it offers a `selfcheck)` subcommand    -> run `selfcheck <tmpdir>`.
#      (`gate_ledger.sh` is a multi-subcommand tool: invoked bare it prints its
#      usage and exits 2 — verified 2026-08-27 — so the sweep would score it
#      ERROR (a blind instrument, §11.4.201(7)(b)), never PASS. Either way a
#      bare invocation proves nothing, so its documented self-test is used
#      instead.)
#   3. Else, `--root` is resolved from the gate's OWN usage header, because the
#      family uses the same flag for two different things:
#        `--root <consumer-root>` / `<project-root>` -> the project root
#        `--root <constitution-root>`                -> submodules/constitution
#        (no --root in the header)                   -> the gate's own default
#   4. `--quiet` is appended only if the gate's parser offers it and --quiet
#      was requested.
#   Every resolved argv is printed, so the reader can check the resolution
#   rather than trust it (`--list`, or the per-gate line in non-quiet mode).
#
# ── Outputs ──────────────────────────────────────────────────────────────────
#   One line per gate (name, verdict, rc, elapsed, resolved argv) + a summary
#   with the pass/fail split, then the full output of every non-PASS gate.
#
# ── Side-effects ─────────────────────────────────────────────────────────────
#   None on this repository. The sweep itself only reads. Gates and mutation
#   tests under the constitution submodule create and trap-remove their own
#   `mktemp -d` sandboxes per their headers. `gate_ledger.sh selfcheck` is given
#   a scratch dir this script creates and removes. No git command that mutates
#   anything is run, and no submodule working tree is written to.
#
# ── Dependencies ─────────────────────────────────────────────────────────────
#   bash, POSIX find/grep/sed/awk, optional coreutils `timeout`. bash -n clean.
#
# ── Cross-references ─────────────────────────────────────────────────────────
#   §11.4.32 (this sweep), §11.4.164 (post-update hook that should call it),
#   §1.1 (the *_mutation_test.sh gates are the paired proofs and are run too),
#   §11.4.3 (SKIP with a reason, never a silent pass), §11.4.6 (report the
#   verified state), §11.4.201(7)(b) (rc=2 is a BLIND instrument, not a pass).
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0 — every discovered gate exited 0.
#   1 — at least one gate FAILed (rc=1) or ERRORed (rc=2 / timeout / other).
#       An rc=2 gate is a blind instrument, never a pass — §11.4.201(7)(b).
#   2 — the sweep could not run at all (root missing, submodule not
#       initialised, gates directory absent, zero gates discovered).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

root="${REPO_ROOT}"
quiet=""
list_only=""
update_ledger=""
prove=""

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  root="${2:-}"; shift 2 ;;
        --quiet) quiet="1"; shift ;;
        --list)  list_only="1"; shift ;;
        --update-ledger) update_ledger="1"; shift ;;
        --prove-failure) prove="1"; shift ;;
        -h|--help) sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "verify-all-constitution-rules.sh: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

if [ -n "$prove" ]; then
    # ══════════════════════════════════════════════════════════════════════════
    # §1.1 PAIRED MUTATION PROOF  —  --prove-failure
    #
    # WHAT IS UNDER TEST. Not the constitution's gates: THIS SWEEP. Its guarded
    # property is §11.4.32's anti-bluff clause — "a sweep that exits PASS without
    # actually running every implementable gate is a §11.4.32 violation" — plus
    # the three-valued contract in its own Exit-codes header.
    #
    # WHY THE CONTROL IS SYNTHETIC. A control built from the real constitution
    # submodule is green only while 286 upstream gates are green, which is never.
    # A red control returns before the first mutation and the proof exits having
    # demonstrated nothing — the "inoperative proof" defect recorded in
    # docs/check-registry.md, found in two of this repository's own gates on
    # 2026-09-01. So the specimen below is a throwaway tree whose gates are stubs
    # that read their exit code out of a sidecar file: the mutation is DATA, the
    # control is green BY CONSTRUCTION, and no state of the real tree can switch
    # the battery off.
    #
    # WHY THE PRE-FLIGHT IS `--list` AND NOT A FULL RUN, stated rather than left
    # to be discovered (§11.4.6): a full live sweep runs every discovered gate —
    # 286 of them at this pin — and takes far longer than any proof budget here.
    # `--list` is the REAL entry point on the REAL tree, exercising root
    # resolution, submodule detection, gate DISCOVERY and argv RESOLUTION, and it
    # is bounded. It is REPORTED, never gating. It does NOT execute the gates,
    # and this proof makes no claim that it does.
    #
    # THE LIMIT THIS BATTERY USED TO RECORD IS CLOSED (2026-09-02). Discovery is
    # live in the ADD direction (M9) and now in the DROP direction too: M11
    # deletes a gate and requires the sweep to exit 1 and NAME it. What made a
    # drop invisible was the absence of an expected-gate ledger; there is one
    # now, and M12 requires that deleting or corrupting it be reported as
    # could-not-determine rather than buying the old silence back.
    #
    # M13/M14 are the pair that keeps the ledger honest across a legitimate
    # population change — the constitution's gate count moved 57 -> 286 on one
    # fast-forward, so a ledger that cried wolf on every bump would be deleted
    # within a week, and one that pardoned every bump would prove nothing.
    #
    # THE RESIDUAL LIMIT, stated rather than asserted away (§11.4.6): when the
    # pin has moved AND the constitution is not a git work tree, attribution is
    # genuinely undecidable and the sweep says so (rc-2 class, never a pass).
    # M13/M14 require git and SKIP with a reason when it is absent.
    #
    # Nothing outside a `mktemp -d` is created, written or removed.
    # ══════════════════════════════════════════════════════════════════════════
    # P_MUT counts the MUTATION cases only — labels beginning `M<digit>` — so the
    # closing summary states a measured number instead of a written-down one. It
    # was written down until 2026-09-02 and it had gone stale: the text claimed
    # "16 mutations" while 18 were running, which is exactly the §11.4.6 defect
    # this sweep exists to catch in other people's instruments.
    P_PASS=0; P_FAIL=0; P_MUT=0
    _p_count() { case "$1" in M[0-9]*) P_MUT=$((P_MUT+1)) ;; esac; }
    p_ok()  { _p_count "$1"; P_PASS=$((P_PASS+1)); printf '✅ %-30s %s\n' "$1" "$2"; }
    p_bad() { _p_count "$1"; P_FAIL=$((P_FAIL+1)); printf '❌ %-30s %s\n' "$1" "$2"; }

    echo "§11.4.32 SWEEP §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    # ---- PRE-FLIGHT: the REAL entry point on the REAL tree, bounded ----------
    if [ -d "$root" ]; then
        pf_out="$(bash "$0" --root "$root" --list 2>&1)"; pf_rc=$?
        pf_n="$(printf '%s' "$pf_out" | sed -n 's/^Discovered \([0-9]*\) gate script(s).*/\1/p')"
        case "$pf_rc" in
            0) printf 'ℹ %-30s the real entry point ran against the real tree: %s gate(s) DISCOVERED and\n' "PRE-FLIGHT live --list" "${pf_n:-?}"
               printf '%-32s their argv resolved. Bounded on purpose (no gate was executed), REPORTED,\n' ""
               printf '%-32s never gating.\n' "" ;;
            2) printf 'ℹ %-30s the real entry point returned rc=2 on the real tree (could not run: root,\n' "PRE-FLIGHT live --list"
               printf '%-32s submodule or gates directory). REPORTED, never gating.\n' "" ;;
            *) p_bad "PRE-FLIGHT live --list" "the real entry point exited rc=${pf_rc}, outside its own 0/1/2 contract"
               printf '%s\n' "$pf_out" | tail -3 | sed 's/^/        /' ;;
        esac
    fi

    SB="$(mktemp -d "${TMPDIR:-/tmp}/sweep-proof.XXXXXX")" || {
        echo "SWEEP-PROOF-ERROR: cannot create a sandbox; nothing was proved" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM      # cleanup: the specimen lives and dies inside $SB
    echo "  sandbox: $SB"

    SPEC="$SB/tree"
    GD="$SPEC/submodules/constitution/scripts/gates"
    GIT_OK=""; command -v git >/dev/null 2>&1 && GIT_OK=1
    PG=(-c user.name=proof -c user.email=proof@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main)

    # ── Specimen gates for the ROOT-RESOLUTION battery (M16–M19) ─────────────
    # Each is emitted by a function taking the very thing under test as a
    # PARAMETER — the declared root kind, the description on the `--root <dir>`
    # line, whether a parser exists — so a mutation changes WHAT THE GATE SAYS
    # and the proof can require the resolver to follow it. A gate whose expected
    # argv were hardcoded in the emitter would prove nothing.
    #
    # Every one of them exits 0 in its control form: the synthetic control must
    # stay green by construction, or the battery below it never runs.

    # emit_g5 <declared-root-kind> — the §11.4.251 THIN WRAPPER shape. It
    # declares --root in its own header and parses NOTHING itself; the parser
    # lives in the engine it sources. 81 real propagation gates have exactly this
    # shape and got no root at all until 2026-09-02 (C1a).
    emit_g5() {
        {
            printf '#!/usr/bin/env bash\n'
            printf '# g5_wrapper.sh — thin wrapper: arg parsing delegated to the sourced engine.\n'
            printf '#   g5_wrapper.sh [--root <%s>] [--quiet]\n' "$1"
            printf '#     --root <dir>   fleet root to scan (default: $CONSUMER_ROOT or "..")\n'
            cat <<'G5BODY'
_eng="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/lib/g5_engine.sh"
[ -r "$_eng" ] || { echo "g5_wrapper: engine not found at $_eng"; exit 2; }
. "$_eng"
g5_main "$@"
G5BODY
        } > "$GD/g5_wrapper.sh"
        chmod 755 "$GD/g5_wrapper.sh"
    }

    # The engine. It carries the `--root)` arm the wrapper lacks, so it is the
    # only evidence in the tree that the wrapper can receive a root at all.
    emit_g5_engine() {
        cat > "$GD/lib/g5_engine.sh" <<'G5ENG'
#!/usr/bin/env bash
# g5_engine.sh — sourced by g5_wrapper.sh; run bare it only defines a function.
g5_main() {
    local root="${CONSUMER_ROOT:-(engine-default)}"
    while [ $# -gt 0 ]; do
        case "$1" in
            --root)  root="$2"; shift 2 ;;
            --quiet) shift ;;
            *)       shift ;;
        esac
    done
    echo "g5_wrapper RESOLVED-ROOT=${root}"
    return 0
}
G5ENG
        chmod 755 "$GD/lib/g5_engine.sh"
    }

    # emit_g6 / emit_g7 — the generic `--root <dir>` vocabulary, which names no
    # side. The DESCRIPTION on that line is the only evidence of which root the
    # gate means, and both readings exist upstream at this pin.
    #   emit_g6 : "scan root ..."         -> the tree under test
    #   emit_g7 : "constitution root ..." -> the constitution
    # Their default is a MARKER, never a real path, so "the resolver handed it a
    # root" and "the gate fell back to its own default" can never be confused.
    emit_g6() {
        {
            printf '#!/usr/bin/env bash\n'
            printf '#   g6_dir_scan.sh [--root <dir>]\n'
            printf '#     --root <dir>   %s\n' "$1"
            cat <<'G6BODY'
root="(no-root-given)"
while [ $# -gt 0 ]; do
    case "$1" in
        --root) root="$2"; shift 2 ;;
        *)      shift ;;
    esac
done
echo "g6_dir_scan RESOLVED-ROOT=${root}"
exit 0
G6BODY
        } > "$GD/g6_dir_scan.sh"
        chmod 755 "$GD/g6_dir_scan.sh"
    }

    emit_g7() {
        {
            printf '#!/usr/bin/env bash\n'
            printf '#   g7_dir_const.sh [--root <dir>]\n'
            printf '#     --root <dir>   %s\n' "$1"
            cat <<'G7BODY'
root="(no-root-given)"
while [ $# -gt 0 ]; do
    case "$1" in
        --root) root="$2"; shift 2 ;;
        *)      shift ;;
    esac
done
echo "g7_dir_const RESOLVED-ROOT=${root}"
exit 0
G7BODY
        } > "$GD/g7_dir_const.sh"
        chmod 755 "$GD/g7_dir_const.sh"
    }

    # emit_g8 <parser|noparser> — a gate that DOCUMENTS `--root` but parses no
    # flags itself. Handing it a root produces a refusal, never a verdict, so
    # the resolver must withhold one until a parser exists.
    #
    # ITS HEADER CHANGED ON 2026-09-02 AND THE REASON IS THE POINT. It used to
    # read `g8_suite.sh gates [--root <consumer-root>]`, copied from
    # `covenant_propagation_suite.sh`, the real file that motivated M18. That
    # file is now excluded from the sweep OUTRIGHT by the C8a classifier's
    # SUBCOMMAND rule — a strictly better outcome than being invoked bare — and
    # the specimen inherited the exclusion, which made M18 measure nothing while
    # still printing a verdict. The withhold-until-a-parser-exists property is
    # INDEPENDENT of the subcommand shape and still binds every thin wrapper
    # whose engine carries no `--root` arm, so the specimen keeps the property
    # and drops the borrowed subcommand. The SUBCOMMAND rule itself is proved
    # separately, by M20b.
    emit_g8() {
        {
            printf '#!/usr/bin/env bash\n'
            printf '#   g8_suite.sh [--root <consumer-root>] [--quiet]\n'
            if [ "$1" = "parser" ]; then
                cat <<'G8P'
root="(no-root-given)"
while [ $# -gt 0 ]; do
    case "$1" in
        --root) root="$2"; shift 2 ;;
        *)      shift ;;
    esac
done
echo "g8_suite RESOLVED-ROOT=${root}"
exit 0
G8P
            else
                # The REAL gate of this shape (covenant_propagation_suite.sh)
                # answers a misfed root with a usage refusal and rc=2, which the
                # sweep scores as an ERROR. This specimen deliberately refuses
                # with rc=0 instead. Reason, stated rather than left to be
                # discovered: an rc=2 here reddens the synthetic CONTROL, the
                # battery aborts before its first mutation, and the operator is
                # told "the control did not pass" — true, useless, and pointing
                # at the wrong file. Refusing loudly at rc=0 keeps the control
                # green so M18 NAMES the defect. The rc=2 consequence is real and
                # is the reason M18 exists; it is not what M18 measures.
                cat <<'G8N'
if [ $# -gt 0 ]; then
    echo "g8_suite REFUSED argv=[$*]"
    exit 0
fi
echo "g8_suite ARGV=[]"
exit 0
G8N
            fi
        } > "$GD/g8_suite.sh"
        chmod 755 "$GD/g8_suite.sh"
    }

    # emit_g9 — no --root interface at all. It reports the environment it was
    # handed, which is the only way to observe the CONSUMER_ROOT export.
    emit_g9() {
        cat > "$GD/g9_env_default.sh" <<'G9'
#!/usr/bin/env bash
# g9_env_default.sh — declares no --root; reports the root it would default to.
echo "g9_env_default CONSUMER_ROOT=[${CONSUMER_ROOT:-UNSET}]"
exit 0
G9
        chmod 755 "$GD/g9_env_default.sh"
    }

    # emit_g10 <declare|silent> — the WRITE-BY-DEFAULT GENERATOR shape, i.e.
    # `covenant_propagation_wrappers_generate.sh`. Run bare it WRITES; a flag is
    # its read-only mode. The parameter changes ONLY the single header line in
    # which it DECLARES that, and nothing else about the file — so a classifier
    # that recognised this shape by NAME would pass both forms and M20 would
    # catch it. The write target is a sentinel OUTSIDE the gates directory, so
    # "did it run?" is observable without perturbing discovery mid-sweep.
    emit_g10() {
        {
            printf '#!/usr/bin/env bash\n'
            printf '# g10_generator.sh — regeneration mechanism for the thin wrappers.\n'
            printf '#\n'
            printf '# ── Usage ───────────────────────────────────────────────────\n'
            case "$1" in
                subcommand) printf '#   g10_generator.sh gates [--check]\n' ;;
                *)          printf '#   g10_generator.sh [--check]\n' ;;
            esac
            if [ "$1" = "declare" ]; then
                printf '#     (no args)  (re)write every wrapper named in the data pack\n'
            else
                printf '#     bare       consult the data pack and report\n'
            fi
            printf '#     --check    verify only; nothing is written\n'
            printf '#\n'
            printf 'SENTINEL=%q\n' "$SB/g10-wrote-here"
            cat <<'G10'
if [ "${1:-}" = "--check" ]; then
    echo "g10_generator CHECKED (read-only)"
    exit 0
fi
echo "g10_generator RAN-BARE" > "$SENTINEL"
echo "g10_generator wrote 1 wrapper file(s)"
exit 0
G10
        } > "$GD/g10_generator.sh"
        chmod 755 "$GD/g10_generator.sh"
    }

    # build_specimen — regenerates the whole throwaway tree from constants, so
    # "restore" is a rebuild and cannot leave a mutation behind.
    build_specimen() {
        rm -rf "$SPEC"
        mkdir -p "$GD/lib" "$SPEC/scripts" || return 1
        printf '# synthetic constitution (proof specimen)\n### §0.0 nothing real lives here\n' \
            > "$SPEC/submodules/constitution/Constitution.md" || return 1

        # §11.4.32 step 1. Its rc is data in a sidecar, so step 1 can be mutated
        # independently of the gates — the sweep grades them separately and this
        # proof must be able to tell those two verdicts apart.
        cat > "$SPEC/scripts/verify-governance-cascade.sh" <<'CASCADE'
#!/usr/bin/env bash
r="$(cd -- "$(dirname -- "$0")/.." && pwd)"
rc=0; [ -f "$r/.step1rc" ] && rc="$(cat "$r/.step1rc")"
echo "synthetic cascade: rc=${rc}"
exit "$rc"
CASCADE
        chmod 755 "$SPEC/scripts/verify-governance-cascade.sh" || return 1
        printf '0\n' > "$SPEC/.step1rc" || return 1

        # g1 — a plain gate: no flags, so resolve_argv must fall through to the
        #      gate's own defaults.
        cat > "$GD/g1_plain.sh" <<'G1'
#!/usr/bin/env bash
f="${BASH_SOURCE[0]}.rc"; rc=0; [ -f "$f" ] && rc="$(cat "$f")"
echo "g1_plain argv=[$*]"
exit "$rc"
G1
        # g2 — declares a --selftest case arm, which resolve_argv must PREFER.
        cat > "$GD/g2_selftest.sh" <<'G2'
#!/usr/bin/env bash
f="${BASH_SOURCE[0]}.rc"; rc=0; [ -f "$f" ] && rc="$(cat "$f")"
case "${1:-}" in
    --selftest) echo "g2_selftest RESOLVED-AS=--selftest" ;;
    *)          echo "g2_selftest RESOLVED-AS=(none) argv=[$*]" ;;
esac
exit "$rc"
G2
        # g3 — its header names `--root <project-root>`, so resolve_argv must
        #      hand it the PROJECT root and not the constitution root.
        cat > "$GD/g3_projectroot.sh" <<'G3'
#!/usr/bin/env bash
#   g3_projectroot.sh --root <project-root>
f="${BASH_SOURCE[0]}.rc"; rc=0; [ -f "$f" ] && rc="$(cat "$f")"
got=""
while [ $# -gt 0 ]; do
    case "$1" in
        --root) got="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done
echo "g3_projectroot RESOLVED-ROOT=${got}"
exit "$rc"
G3
        # g5–g9 — the ROOT-RESOLUTION battery, in their CONTROL form. Each is
        # emitted by its own function so a mutation can re-emit exactly one of
        # them with one declaration changed and nothing else.
        emit_g5_engine
        emit_g5 "consumer-root"
        emit_g6 'scan root (default: $G6_ROOT or "..")'
        emit_g7 'constitution root (default: two dirs above this file)'
        emit_g8 "noparser"
        emit_g9
        emit_g10 "declare"
        rm -f "$SB/g10-wrote-here"

        chmod 755 "$GD"/*.sh || return 1

        # The specimen's constitution is a REAL git repository when git is
        # available, so the ledger's pin discriminator AND its git-tracked
        # fallback are exercised rather than stubbed. Without git the pin reads
        # "unknown" on both sides, which still exercises the same-pin path — the
        # cases that need a moving pin say so and SKIP with a reason (§11.4.3).
        if [ -n "$GIT_OK" ]; then
            git "${PG[@]}" -C "$SPEC/submodules/constitution" init -q >/dev/null 2>&1 || return 1
            git "${PG[@]}" -C "$SPEC/submodules/constitution" add -A >/dev/null 2>&1 || return 1
            git "${PG[@]}" -C "$SPEC/submodules/constitution" commit -qm base >/dev/null 2>&1 || return 1
        fi
        # Written by the REAL --update-ledger path, not hand-rolled here.
        bash "$0" --root "$SPEC" --update-ledger >/dev/null 2>&1 || return 1
        return 0
    }

    spec_git() { git "${PG[@]}" -C "$SPEC/submodules/constitution" "$@" >/dev/null 2>&1; }

    run_spec() { bash "$0" --root "$SPEC" "$@" 2>&1; }

    # assert <label> <want-rc> <needle-or-empty> [argv...]
    assert() {
        local label="$1" want="$2" needle="$3"; shift 3
        local out rc
        out="$(run_spec "$@")"; rc=$?
        if [ "$rc" -ne "$want" ]; then
            p_bad "$label" "expected rc=${want}, got rc=${rc}"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            return
        fi
        if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
            p_bad "$label" "rc=${want} as required, but the output never NAMED '${needle}'"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            return
        fi
        p_ok "$label" "rc=${rc}${needle:+, and it named '${needle}'}"
    }

    build_specimen || { echo "SWEEP-PROOF-ERROR: could not build the specimen" >&2; exit 2; }

    # ---- CONTROL -------------------------------------------------------------
    assert "CONTROL synthetic-green    " 0 "SWEEP: PASS" --quiet
    if [ "$P_FAIL" -gt 0 ]; then
        echo "----------------------------------------------------------------------"
        echo "❌ §11.4.32 SWEEP §1.1 PROOF: ABORTED — the synthetic control did not pass, so"
        echo "   ZERO mutations ran and nothing below would have been proved."
        exit 1
    fi

    # ---- M1  a child gate FAILS -> the sweep must fail and NAME it ------------
    printf '1\n' > "$GD/g1_plain.sh.rc"
    assert "M1 child-gate-fails        " 1 "g1_plain.sh" --quiet
    rm -f "$GD/g1_plain.sh.rc"

    # ---- M2  a child gate is BLIND (rc=2) -> ERROR, never a pass --------------
    # §11.4.201(7)(b). It must exit non-zero AND be counted apart from FAIL: a
    # gate that could not see is not a finding against the tree.
    printf '2\n' > "$GD/g2_selftest.sh.rc"
    assert "M2 child-gate-blind-rc2    " 1 "ERRORED (blind instrument" --quiet
    out="$(run_spec --quiet)"
    if printf '%s' "$out" | grep -qE '^  FAIL   \(rc=1\)     : 0$' && \
       printf '%s' "$out" | grep -qE '^  ERROR  \(rc!=0,1\)  : 1$'; then
        p_ok "M2b blind-is-not-a-FAIL   " "the summary reports 0 FAIL and 1 ERROR — the two verdicts are not conflated"
    else
        p_bad "M2b blind-is-not-a-FAIL  " "an rc=2 gate was not counted separately from FAIL"
        printf '%s\n' "$out" | grep -E 'PASS|FAIL|ERROR' | sed 's/^/        /'
    fi
    rm -f "$GD/g2_selftest.sh.rc"

    # ---- M3  §11.4.32 step 1 FAILS -------------------------------------------
    printf '1\n' > "$SPEC/.step1rc"
    assert "M3 step1-fails             " 1 "STEP1 FAIL" --quiet
    printf '0\n' > "$SPEC/.step1rc"

    # ---- M4  step 1 is BLIND (rc=2) ------------------------------------------
    # Must be ERROR, not FAIL: this reports a broken CHECK, not a violation of
    # the tree. The caller used to collapse every non-zero rc into STEP1 FAIL.
    printf '2\n' > "$SPEC/.step1rc"
    assert "M4 step1-blind-rc2         " 1 "STEP1 ERROR" --quiet
    out="$(run_spec --quiet)"
    if printf '%s' "$out" | grep -qF "COULD NOT VERIFY"; then
        p_ok "M4b step1-blind-is-named  " "it says COULD NOT VERIFY rather than accusing the tree"
    else
        p_bad "M4b step1-blind-is-named " "an rc=2 step 1 was not reported as could-not-verify"
    fi
    printf '0\n' > "$SPEC/.step1rc"

    # ---- M5  the gates directory is gone -> rc 2, never 0 ---------------------
    mv "$GD" "$SB/gates-parked"
    assert "M5 gates-dir-absent        " 2 "gates directory absent" --quiet
    mv "$SB/gates-parked" "$GD"

    # ---- M6  the gates directory is EMPTY -> rc 2 ----------------------------
    # "Nothing to run" is not "everything passed". A sweep that inspected zero
    # gates has not certified a tree.
    # `$GD/*` and not `$GD/*.sh`: the specimen now carries a `lib/` subdirectory,
    # and discovery is `find -type f -name '*.sh'`, which descends into it. A
    # top-level-only glob would leave the engine behind and this mutation would
    # be measuring one surviving gate instead of an empty directory.
    mkdir -p "$SB/gates-holding" && mv "$GD"/* "$SB/gates-holding/"
    assert "M6 zero-gates-discovered   " 2 "zero gates discovered" --quiet
    mv "$SB/gates-holding"/* "$GD/"

    # ---- M7  the constitution submodule is not initialised -> rc 2 -----------
    : > "$SPEC/submodules/constitution/Constitution.md"
    assert "M7 submodule-uninitialised " 2 "not initialised" --quiet
    build_specimen || { echo "SWEEP-PROOF-ERROR: could not rebuild the specimen" >&2; exit 2; }

    # ---- M8  a root that does not exist -> rc 2 ------------------------------
    out="$(bash "$0" --root "$SB/no-such-root" --quiet 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qF "project root not found"; then
        p_ok "M8 root-absent            " "rc=2, and it named the missing root"
    else
        p_bad "M8 root-absent           " "expected rc=2 naming the missing root, got rc=${rc}"
    fi

    # ---- M9  DISCOVERY IS LIVE: a new gate file is picked up, unedited -------
    # §11.4.32 forbids a hardcoded gate list. Adding a file to the gates
    # directory must change what the sweep runs with no edit to this script.
    before_n="$(run_spec --list | sed -n 's/^Discovered \([0-9]*\) gate script(s).*/\1/p')"
    cat > "$GD/g4_added.sh" <<'G4'
#!/usr/bin/env bash
echo "g4_added ran"
exit 1
G4
    chmod 755 "$GD/g4_added.sh"
    after_n="$(run_spec --list | sed -n 's/^Discovered \([0-9]*\) gate script(s).*/\1/p')"
    out="$(run_spec --quiet)"; rc=$?
    if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF "g4_added.sh" \
       && [ "${after_n:-0}" -eq $(( ${before_n:-0} + 1 )) ]; then
        p_ok "M9 new-gate-discovered    " "the count moved ${before_n} -> ${after_n} and the added gate's failure made the sweep rc=1, with no edit to the sweep"
    else
        p_bad "M9 new-gate-discovered   " "adding a gate did not change the sweep: count ${before_n} -> ${after_n}, rc=${rc}"
    fi
    rm -f "$GD/g4_added.sh"

    # ---- M10 the resolved argv is DERIVED from each gate, not written down ----
    out="$(run_spec)"
    if printf '%s' "$out" | grep -qF "g2_selftest RESOLVED-AS=--selftest" \
       && printf '%s' "$out" | grep -qF "g3_projectroot RESOLVED-ROOT=${SPEC}"; then
        p_ok "M10 argv-resolution       " "--selftest was preferred where declared, and '--root <project-root>' resolved to the PROJECT root"
    else
        p_bad "M10 argv-resolution      " "resolve_argv did not hand each gate the invocation its own source declares"
        printf '%s' "$out" | grep -E 'RESOLVED-' | sed 's/^/        /'
    fi

    # ---- M11 A DROPPED GATE IS CAUGHT — the blind spot this ledger closes ----
    # This case was assertion "L1" until 2026-09-02 and it recorded the OPPOSITE
    # result: the count fell, the sweep still exited 0, and the gap was printed
    # rather than caught. It is now a real mutation. The old form is kept in the
    # comment on purpose — a closed gap should show what it closed.
    lim_before="$(run_spec --list | sed -n 's/^Discovered \([0-9]*\) gate script(s).*/\1/p')"
    mv "$GD/g1_plain.sh" "$SB/g1-dropped.sh"
    lim_after="$(run_spec --list | sed -n 's/^Discovered \([0-9]*\) gate script(s).*/\1/p')"
    out="$(run_spec --quiet)"; rc=$?
    if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF "LEDGER DROP" \
       && printf '%s' "$out" | grep -qF "g1_plain.sh" \
       && [ "${lim_after:-0}" -eq $(( ${lim_before:-0} - 1 )) ]; then
        p_ok "M11 dropped-gate CAUGHT   " "the count fell ${lim_before} -> ${lim_after}, the sweep exited 1 and NAMED the vanished gate. Same pin, so the deletion is DETERMINED, not inferred."
    else
        p_bad "M11 dropped-gate CAUGHT  " "a deleted gate was not caught: rc=${rc}, count ${lim_before} -> ${lim_after}"
        printf '%s' "$out" | grep -E 'LEDGER|SWEEP:' | sed 's/^/        /'
    fi
    mv "$SB/g1-dropped.sh" "$GD/g1_plain.sh"

    # ---- M12 A LEDGER THAT CANNOT BE READ IS NOT A PASS ----------------------
    # Deleting the ledger must not buy back the old blind behaviour. Absent
    # drop-detection is could-not-determine, never clean.
    mv "$SPEC/scripts/constitution-gate-ledger.tsv" "$SB/ledger-parked.tsv"
    assert "M12 no-ledger-is-not-a-pass" 1 "NO LEDGER" --quiet
    mv "$SB/ledger-parked.tsv" "$SPEC/scripts/constitution-gate-ledger.tsv"
    printf 'nonsense\trow\n' >> "$SPEC/scripts/constitution-gate-ledger.tsv"
    assert "M12b malformed-ledger      " 1 "LEDGER UNREADABLE" --quiet
    build_specimen || { echo "SWEEP-PROOF-ERROR: could not rebuild the specimen" >&2; exit 2; }

    # ---- M13 / M14  THE DISCRIMINATOR: a moved pin vs a vanished gate --------
    # The whole reason a hardcoded expected list is wrong here: the population
    # legitimately moved 57 -> 286 when the constitution was fast-forwarded. So
    # a legitimate upstream removal must NOT read as a drop (M13), and a local
    # deletion must STILL read as a drop even though the pin moved (M14). If
    # only M13 held, the ledger would be a rubber stamp; if only M14 held, every
    # bump would be a false alarm and the ledger would be deleted within a week.
    if [ -n "$GIT_OK" ]; then
        # M13 — upstream drops a gate and the pin moves with it.
        spec_git rm -q -- scripts/gates/g1_plain.sh
        spec_git commit -qm "upstream removes a gate"
        out="$(run_spec --quiet)"; rc=$?
        if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "upstream removal" \
           && ! printf '%s' "$out" | grep -qF "LEDGER DROP"; then
            p_ok "M13 upstream-removal NOTE " "the pin MOVED and git reports the path as no longer tracked, so it is reported as an upstream removal and does NOT gate"
        else
            p_bad "M13 upstream-removal NOTE" "a legitimate upstream removal was not distinguished from a deletion (rc=${rc})"
            printf '%s' "$out" | grep -E 'LEDGER|SWEEP:' | sed 's/^/        /'
        fi

        # M14 — re-baseline, move the pin again, then delete a gate LOCALLY.
        bash "$0" --root "$SPEC" --update-ledger >/dev/null 2>&1
        printf 'a later upstream commit\n' > "$SPEC/submodules/constitution/NOTES.md"
        spec_git add -A
        spec_git commit -qm "upstream moves on"
        mv "$GD/g2_selftest.sh" "$SB/g2-dropped.sh"
        out="$(run_spec --quiet)"; rc=$?
        if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF "LEDGER DROP" \
           && printf '%s' "$out" | grep -qF "g2_selftest.sh"; then
            p_ok "M14 drop-survives-a-bump  " "the pin MOVED, yet a gate deleted from the working tree is still TRACKED at the new commit — caught as a drop and NAMED, not pardoned by the bump"
        else
            p_bad "M14 drop-survives-a-bump " "a local deletion was pardoned because the pin had moved (rc=${rc})"
            printf '%s' "$out" | grep -E 'LEDGER|SWEEP:' | sed 's/^/        /'
        fi
        mv "$SB/g2-dropped.sh" "$GD/g2_selftest.sh"

        # M15 — --update-ledger is the deliberate, visible re-baseline.
        bash "$0" --root "$SPEC" --update-ledger >/dev/null 2>&1
        assert "M15 re-baseline restores  " 0 "LEDGER OK" --quiet
    else
        printf 'ℹ %-30s %s\n' "M13/M14/M15 pin-discriminator" \
            "SKIPPED with a reason (§11.4.3): git is not on PATH, so a moving pin cannot be simulated. The same-pin drop (M11) still ran and passed."
    fi
    build_specimen || { echo "SWEEP-PROOF-ERROR: could not rebuild the specimen" >&2; exit 2; }

    # ══ M16–M19  ROOT RESOLUTION  (GATE-TRIAGE.md §9.6 C1) ═══════════════════
    # The 2026-09-02 sweep pointed 85 of 287 gates at the PARENT of this
    # repository. 81 FAILed emitting zero bytes, one was a confirmed FALSE FAIL,
    # one emitted 714,162 lines about unrelated projects, and two hit the 900 s
    # timeout walking a directory nothing here owns. Each case below fixes one
    # step of that resolution IN BOTH DIRECTIONS: the control shows the right
    # root arriving, and the mutation changes what the gate DECLARES and requires
    # the resolved root to follow. A resolver that hardcoded any of these answers
    # would pass the control and fail the mutation.

    # ---- M16 a THIN WRAPPER gets the root its header declares (C1a) ----------
    out="$(run_spec)"
    if printf '%s' "$out" | grep -qF "g5_wrapper RESOLVED-ROOT=${SPEC}"; then
        emit_g5 "constitution-root"          # mutate ONLY the declared kind
        out="$(run_spec)"
        if printf '%s' "$out" | grep -qF "g5_wrapper RESOLVED-ROOT=${SPEC}/submodules/constitution"; then
            p_ok "M16 thin-wrapper root     " "a gate with NO --root case arm of its own — parser in a sourced lib — was handed the root its header declares, and re-declaring consumer-root as constitution-root moved the resolved root with it"
        else
            p_bad "M16 thin-wrapper root    " "the resolved root did not follow the wrapper's own declaration when it changed"
            printf '%s' "$out" | grep -E 'g5_wrapper' | sed 's/^/        /'
        fi
        emit_g5 "consumer-root"
    else
        p_bad "M16 thin-wrapper root    " "a thin wrapper declaring '--root <consumer-root>' was NOT handed the project root — the C1a defect is present"
        printf '%s' "$out" | grep -E 'g5_wrapper' | sed 's/^/        /'
    fi

    # ---- M17 the generic `--root <dir>` is disambiguated FROM THE GATE (C1b) --
    # Both readings exist upstream. Getting this backwards is as damaging as not
    # resolving at all, so the discrimination is proved in both directions.
    out="$(run_spec)"
    ok16a=0; ok16b=0
    printf '%s' "$out" | grep -qF "g6_dir_scan RESOLVED-ROOT=${SPEC}" && ok16a=1
    printf '%s' "$out" | grep -qF "g7_dir_const RESOLVED-ROOT=${SPEC}/submodules/constitution" && ok16b=1
    if [ "$ok16a" -eq 1 ] && [ "$ok16b" -eq 1 ]; then
        emit_g7 'scan root (default: $G7_ROOT or "..")'   # mutate ONLY the words
        out="$(run_spec)"
        if printf '%s' "$out" | grep -qF "g7_dir_const RESOLVED-ROOT=${SPEC}" \
           && ! printf '%s' "$out" | grep -qF "g7_dir_const RESOLVED-ROOT=${SPEC}/submodules/constitution"; then
            p_ok "M17 dir-vocabulary split  " "'--root <dir>' resolved to the PROJECT root where the gate said 'scan root' and to the CONSTITUTION root where it said 'constitution root'; rewording the one line moved it, so the split is read from the gate and not from a list in this script"
        else
            p_bad "M17 dir-vocabulary split " "rewording the gate's own --root description did not change the root it was handed"
            printf '%s' "$out" | grep -E 'g7_dir_const' | sed 's/^/        /'
        fi
        emit_g7 'constitution root (default: two dirs above this file)'
    else
        p_bad "M17 dir-vocabulary split " "'--root <dir>' was misresolved (scan-root ok=${ok16a}, constitution-root ok=${ok16b}) — C1b is present, or its constitution half has regressed"
        printf '%s' "$out" | grep -E 'g6_dir_scan|g7_dir_const' | sed 's/^/        /'
    fi

    # ---- M18 a documented root is WITHHELD until a parser exists -------------
    # The other direction of the same defect: ungating the header lookup without
    # this test hands `--root` to a batch runner that cannot take one, turning a
    # usage refusal into an rc=2 ERROR the sweep would score against this tree.
    out="$(run_spec)"
    if printf '%s' "$out" | grep -qF "g8_suite ARGV=[]" \
       && ! printf '%s' "$out" | grep -qF "g8_suite REFUSED"; then
        emit_g8 "parser"                    # give it a parser, change nothing else
        out="$(run_spec)"
        if printf '%s' "$out" | grep -qF "g8_suite RESOLVED-ROOT=${SPEC}"; then
            p_ok "M18 root-withheld-no-parser" "a gate whose header documents --root but which parses no flags was invoked bare, and the SAME header started receiving the root the moment a --root arm appeared — the resolver keys on the parser, not on the prose"
        else
            p_bad "M18 root-withheld-no-parser" "adding a --root arm did not make the documented root arrive"
            printf '%s' "$out" | grep -E 'g8_suite' | sed 's/^/        /'
        fi
        emit_g8 "noparser"
    else
        p_bad "M18 root-withheld-no-parser" "a gate that cannot parse --root was handed one anyway"
        printf '%s' "$out" | grep -E 'g8_suite' | sed 's/^/        /'
    fi

    # ---- M19 CONSUMER_ROOT is exported, and the sweep's own root WINS --------
    # Belt and braces for every gate that declares no --root at all. The mutation
    # poisons the variable in the sweep's own environment: an inherited value
    # from a stale shell must never redirect 286 gates at another tree.
    out="$(run_spec)"
    if printf '%s' "$out" | grep -qF "g9_env_default CONSUMER_ROOT=[${SPEC}]"; then
        out="$(CONSUMER_ROOT="$SB/poisoned-root" bash "$0" --root "$SPEC" 2>&1)"
        if printf '%s' "$out" | grep -qF "g9_env_default CONSUMER_ROOT=[${SPEC}]" \
           && ! printf '%s' "$out" | grep -qF "poisoned-root"; then
            p_ok "M19 CONSUMER_ROOT exported" "a gate declaring no --root at all saw the sweep's own project root, and a poisoned CONSUMER_ROOT in the caller's environment was OVERRIDDEN rather than inherited"
        else
            p_bad "M19 CONSUMER_ROOT exported" "an inherited CONSUMER_ROOT survived into the gates — the sweep's own --root is not authoritative"
            printf '%s' "$out" | grep -E 'g9_env_default' | sed 's/^/        /'
        fi
    else
        p_bad "M19 CONSUMER_ROOT exported" "CONSUMER_ROOT did not reach the gates as the sweep's project root"
        printf '%s' "$out" | grep -E 'g9_env_default' | sed 's/^/        /'
    fi

    # ══ M20  A NON-GATE IS NOT INVOKED — AND A REAL GATE STILL IS ════════════
    # (GATE-TRIAGE.md §9.6 C8a.) The live defect: the sweep invoked
    # `covenant_propagation_wrappers_generate.sh` BARE, and bare is its WRITE
    # mode — its row read `wrote 162 wrapper file(s)` and scored PASS. Only
    # idempotence stood between a read-only audit and a mutated consumed
    # submodule this repository does not own.
    #
    # BOTH HALVES ARE REQUIRED, and the second is the one that stops this fix
    # from becoming a coverage cut. Excluding files is trivially easy to
    # overdo, and a sweep that runs fewer gates while still printing PASS is
    # the §11.4.32 anti-bluff violation itself. So:
    #   (a) the generator must NOT run — proved by a sentinel it writes when it
    #       does, not by reading the sweep's own summary — and it must be NAMED
    #       as excluded, because an invisible exclusion is the same blindness
    #       relocated;
    #   (b) in the SAME run, a real gate must still be discovered AND executed.
    # The mutation then removes ONLY the header line in which the file declares
    # its bare mode writes. That must put it straight back into the sweep and
    # the sentinel must appear — which is what proves the classifier reads the
    # FILE and not a list of names kept in this script.
    rm -f "$SB/g10-wrote-here"
    lst="$(run_spec --list)"
    out="$(run_spec)"; rc=$?
    m20_excluded=0; m20_named=0; m20_realgate=0
    [ ! -e "$SB/g10-wrote-here" ] && m20_excluded=1
    printf '%s\n' "$lst" | grep -F 'g10_generator.sh' | grep -qF 'EXCLUDED' && m20_named=1
    printf '%s' "$lst" | grep -F 'g1_plain.sh' | grep -qF 'argv:' \
      && printf '%s' "$out" | grep -qF 'g1_plain argv=' && m20_realgate=1
    if [ "$rc" -eq 0 ] && [ "$m20_excluded" -eq 1 ] && [ "$m20_named" -eq 1 ] && [ "$m20_realgate" -eq 1 ]; then
        emit_g10 "silent"           # drop ONLY the "(no args) (re)write" line
        rm -f "$SB/g10-wrote-here"
        lst2="$(run_spec --list)"
        out2="$(run_spec)"
        m20b_ran=0; m20b_listed=0
        [ -e "$SB/g10-wrote-here" ] && m20b_ran=1
        printf '%s' "$lst2" | grep -F 'g10_generator.sh' | grep -qvF 'EXCLUDED' && m20b_listed=1
        if [ "$m20b_ran" -eq 1 ] && [ "$m20b_listed" -eq 1 ]; then
            p_ok "M20 non-gate-not-invoked  " "a file whose own Usage binds its bare invocation to a WRITE was NOT executed (its sentinel never appeared) and was NAMED as excluded, while a real gate in the SAME run was both listed and executed; deleting that one declaration line put it straight back into the sweep and the write happened — so the classifier reads the file, not a name list"
        else
            p_bad "M20 non-gate-not-invoked " "removing the write-by-default declaration did not re-admit the file (ran=${m20b_ran}, listed-as-gate=${m20b_listed}) — the exclusion is keyed on something other than the file's own declaration"
            printf '%s' "$lst2" | grep -F 'g10_generator' | sed 's/^/        /'
        fi
        # ---- M20b the SUBCOMMAND class, from the SAME file, header only -------
        # `covenant_propagation_suite.sh` run bare prints its usage and exits 2,
        # which the sweep scored as an ERROR against this tree — an accusation
        # manufactured by the caller. Re-declaring g10's usage as
        # `g10_generator.sh gates [--check]` and changing nothing else must
        # exclude it under a DIFFERENT rule, with that rule NAMED.
        emit_g10 "subcommand"
        rm -f "$SB/g10-wrote-here"
        lst3="$(run_spec --list)"
        run_spec >/dev/null 2>&1
        if [ ! -e "$SB/g10-wrote-here" ] \
           && printf '%s\n' "$lst3" | grep -F 'g10_generator.sh' | grep -qF 'SUBCOMMAND'; then
            p_ok "M20b subcommand-excluded  " "the same file, with only its usage line re-declared as requiring a positional subcommand, was excluded under the SUBCOMMAND rule and named as such — a bare run of it would have been a usage refusal scored as an ERROR against this tree"
        else
            p_bad "M20b subcommand-excluded " "a file whose Usage requires a positional subcommand was still invoked bare, or was excluded without naming the SUBCOMMAND rule"
            printf '%s\n' "$lst3" | grep -F 'g10_generator' | sed 's/^/        /'
        fi
        emit_g10 "declare"
        rm -f "$SB/g10-wrote-here"
    else
        p_bad "M20 non-gate-not-invoked " "rc=${rc}; generator-not-run=${m20_excluded}, named-as-excluded=${m20_named}, real-gate-still-run=${m20_realgate} (all three must be 1)"
        printf '%s' "$lst" | grep -F 'g10_generator' | sed 's/^/        /'
    fi

    # ---- M20c the excluded set is REPORTED, with a count and a reason --------
    # A silent exclusion reduces coverage invisibly, which is the exact failure
    # mode this repository polices in other people's instruments. The sweep must
    # state how many *.sh it scanned, how many it is invoking, and why each
    # difference exists.
    out="$(run_spec --quiet)"
    if printf '%s' "$out" | grep -qE 'non-gates excluded  : [0-9]+ of [0-9]+ \*\.sh scanned'; then
        p_ok "M20c exclusions-are-visible" "the run header states the scanned total, the invoked total and the difference, and --list names every excluded file with its reason"
    else
        p_bad "M20c exclusions-are-visible" "the sweep did not report its excluded set — an exclusion nobody can see is a silent coverage cut"
        printf '%s' "$out" | sed -n '1,14p' | sed 's/^/        /'
    fi

    build_specimen || { echo "SWEEP-PROOF-ERROR: could not rebuild the specimen" >&2; exit 2; }

    # ---- RESTORED CONTROL ----------------------------------------------------
    assert "CONTROL restored          " 0 "SWEEP: PASS" --quiet

    echo "----------------------------------------------------------------------"
    if [ "$P_FAIL" -gt 0 ]; then
        echo "❌ §11.4.32 SWEEP §1.1 MUTATION PROOF: FAIL — ${P_FAIL} case(s) did not hold."
        exit 1
    fi
    echo "✅ §11.4.32 SWEEP §1.1 MUTATION PROOF: PASS — the real entry point ran against the"
    echo "   real tree (bounded to --list, reported, never gating), a synthetic control that is"
    echo "   green by construction passed, and ${P_MUT} mutations were each caught with the right"
    echo "   three-valued verdict: a failing child gate and a failing step 1 as rc=1 and NAMED;"
    echo "   a BLIND child gate and a blind step 1 counted as ERROR rather than as an"
    echo "   accusation; three could-not-run states as rc=2; discovery shown live in the ADD"
    echo "   direction (M9) AND in the DROP direction (M11 — a deleted gate now reddens the"
    echo "   sweep and is NAMED); an absent or malformed expected-gate ledger reported as"
    echo "   could-not-determine rather than as clean (M12); the pin discriminator proved"
    echo "   in BOTH directions — an upstream removal across a moved pin does not gate (M13)"
    echo "   while a local deletion across a moved pin still does (M14), with --update-ledger"
    echo "   as the one deliberate, diff-visible re-baseline (M15); and ROOT RESOLUTION proved"
    echo "   by reading each gate rather than by naming it — a thin wrapper whose parser lives"
    echo "   in a sourced lib is handed the root its own header declares (M16), the generic"
    echo "   '--root <dir>' is split to the project or the constitution root by the gate's own"
    echo "   description and follows it when that description is reworded (M17), a gate that"
    echo "   documents --root but parses no flags is invoked bare until a parser appears (M18),"
    echo "   and CONSUMER_ROOT reaches every remaining gate as the sweep's own root, overriding"
    echo "   a poisoned value inherited from the caller (M19). Finally, a NON-GATE is no longer"
    echo "   invoked: a file whose own Usage binds its bare invocation to a WRITE was excluded and"
    echo "   NAMED, a real gate in the same run was still discovered AND executed, and deleting"
    echo "   that one declaration line re-admitted it and the write happened (M20) — with the"
    echo "   excluded set reported by count and reason rather than dropped in silence (M20c)."
    exit 0
fi

[ -n "$root" ] && [ -d "$root" ] || { echo "SWEEP-ERROR: project root not found: '${root}'" >&2; exit 2; }
root="$(cd "$root" && pwd)"

CONSTITUTION_ROOT="${root}/submodules/constitution"
GATES_DIR="${CONSTITUTION_ROOT}/scripts/gates"
GATE_TIMEOUT="${GATE_TIMEOUT:-900}"

# ── §11.4.35 consumer-registered gate inputs — CM-OPENDESIGN-UI-SYSTEM ──────
# `cm_opendesign_ui_system.sh` is project-agnostic BY DESIGN (§11.4.28): its
# built-in OD_*_GLOBS describe a generic layout (`src/theme/*`, `tokens.json`,
# `tests/visual/*`). Not one of those patterns matches this repository, so with
# nothing bound all three lists came back EMPTY, the gate took its
# no-UI-surface branch, and it SKIPped with the reason "no UI surface detected"
# — about a repository that ships eight OpenDesign stylesheets under
# `design-system/`. §11.4.3 permits an HONEST skip; that one was factually
# false, and the sweep scored it PASS.
#
# §11.4.35 puts the fix HERE, in the consumer, never in the gate: the gate owns
# the generic defaults, the consumer registers its own layout as DATA. These
# are exported so the gate inherits them through the plain `bash "$g" $argv`
# invocation in STEP 2 below. Each is overridable from the environment.
#
#   OD_THEME_GLOBS    the CONSUMING layer — stylesheets that MUST resolve every
#                     colour through a token. Sub-check (b) scans these for
#                     ad-hoc hex, and they carry none.
#   OD_TOKEN_GLOBS    the §11.4.216 canonical token sources — the files whose
#                     `:root {}` / `[data-theme="dark"]` blocks DEFINE the
#                     `--od-*` / `--lk-*` custom properties. A token definition
#                     is the ONE place a colour literal legitimately lives, so
#                     the gate does not scan these for hex.
#   OD_VISREG_GLOBS   the real §11.4.170 host-rendered visual-proof harness
#                     (`_tests/visual/visual-oracle.js` + its self-validation +
#                     the Playwright visual-effects spec).
#                     `design-system/preview/*` is deliberately NOT bound: a
#                     preview page is not a pixel-diff harness, and binding it
#                     would buy sub-check (d) with something that cannot fail.
#   OD_MANIFEST_GLOBS the gate's own default list PLUS `helix-deps.yaml`, which
#                     is where this repo declares its dependencies (§11.4.31);
#                     it already declares the §11.4.162 OpenDesign engine.
#
# Honest scope, stated rather than left to be discovered (§11.4.6):
#   * The two brand stylesheets are registered as TOKEN sources because they
#     ARE this repository's §11.4.216 canonical token files. They also carry
#     component rules, which the gate therefore does not scan. At binding time
#     those rules held ZERO colour literals — checkable in one command:
#       grep -nE '#[0-9A-Fa-f]{6}\b' design-system/brand-*/*.css \
#         | grep -vE -- '--[A-Za-z0-9-]+[[:space:]]*:'
#     It returns exactly FIVE lines and every one of them is PROSE inside a CSS
#     comment — a §11.4.201(7)(a) carrier, not a colour: the measured-contrast
#     and brand-hue notes at milosvasic.css:2,647,648,688 and
#     vasic-digital.css:6. No declaration value in either file holds a literal.
#   * First-party CSS OUTSIDE `design-system/` is NOT registered, and is an
#     enumerated gap rather than a silent one: `ai_interviewing/assets/theme.css`
#     (53 literals) and `design-toolkit/proposed/**` (107) are separate UI
#     surfaces; `design-toolkit/qa/fixtures/golden-bad-tokens.css` (20) is a
#     golden-BAD fixture that MUST keep its literals; `<site>/assets/od/*.css`
#     are build-synced copies of the files already registered above.
export OD_THEME_GLOBS="${OD_THEME_GLOBS:-design-system/*.css design-system/fonts/*.css design-system/learning-kit/learning-kit.css design-system/motion/*.css}"
export OD_TOKEN_GLOBS="${OD_TOKEN_GLOBS:-design-system/brand-*/*.css design-system/learning-kit/kit-tokens.css}"
export OD_VISREG_GLOBS="${OD_VISREG_GLOBS:-_tests/visual/* _tests/visual-effects.spec.js}"
export OD_MANIFEST_GLOBS="${OD_MANIFEST_GLOBS:-helix-deps.yaml .mcp.json package.json go.mod Cargo.toml pubspec.yaml requirements.txt opencode.json .qwen/settings.json}"

# ── CONSUMER_ROOT — belt and braces for root resolution ─────────────────────
# Many gates take their scan root from `${CONSUMER_ROOT:-..}`, and `..` from this
# repository is the operator's entire projects directory. `resolve_argv` hands an
# explicit `--root` to every gate whose own header declares one AND whose parser
# can receive it; this covers the remainder — a gate that reads the variable but
# documents no `--root` at all, and any future gate whose header vocabulary this
# resolver has not learned. An explicit `--root` still wins: every gate examined
# sets its default from the environment FIRST and then overwrites it from argv.
#
# DELIBERATELY NOT `${CONSUMER_ROOT:-$root}`. The sweep's own `--root` IS the
# consumer root by definition, so an inherited value from a stale shell must not
# be able to silently redirect 286 gates at another tree. Proved by M19, which
# poisons the variable and requires the sweep to override it.
#
# Blast radius, measured at this pin rather than assumed: of the 286 discovered
# gate files, 106 read CONSUMER_ROOT. 104 of them are handed an explicit --root
# anyway. The two that are not are `cm_opendesign_ui_system_mutation_test.sh`,
# which neutralises the variable itself (`env CONSUMER_ROOT="" …`) at both of its
# fixture invocations, and `covenant_propagation_wrappers_generate.sh`, whose
# only reference to it is inside the heredoc template it emits. The three
# selftest-driven gates that read it — cm_canonical_root_clarity.sh,
# cm_rule_binds_to_seam.sh, cm_unreferenced_gate_bound_or_retired.sh — were run
# with and without it set: rc=0 both ways, unchanged.
export CONSUMER_ROOT="$root"

if [ ! -s "${CONSTITUTION_ROOT}/Constitution.md" ]; then
    echo "SWEEP-ERROR: constitution submodule not initialised at ${CONSTITUTION_ROOT}" >&2
    echo "             fix: git submodule update --init submodules/constitution" >&2
    exit 2
fi
if [ ! -d "$GATES_DIR" ]; then
    echo "SWEEP-ERROR: gates directory absent: ${GATES_DIR}" >&2
    exit 2
fi

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout ${GATE_TIMEOUT}"

# _gate_header <path> -> the file's OWN leading comment block
# Everything from below the shebang down to the first line that is neither
# blank nor a `#` comment. A token found BELOW that line is body text — a
# heredoc template, generated code, a fixture — and is not this file's
# interface. Defined HERE, above discovery, because the non-gate classifier
# needs it; `resolve_argv` further down uses the same function.
_gate_header() {
    awk 'NR==1 && /^#!/ { next }
         /^[[:space:]]*#/ { print; next }
         /^[[:space:]]*$/ { next }
         { exit }' "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# NON-GATE CLASSIFICATION  (GATE-TRIAGE.md §9.6 C8 / C8a)
#
# THE DEFECT. Discovery is `find -type f -name '*.sh'`, and `scripts/gates/`
# holds more than gates. Three shapes were being invoked BARE as if they were
# gates, and one of them is not merely a bad row:
#
#   * `covenant_propagation_wrappers_generate.sh` is a code GENERATOR whose
#     BARE invocation is its WRITE mode. The sweep ran it with `(gate defaults)`
#     and its row read `wrote 162 wrapper file(s)` — scored PASS. No damage has
#     been measured (the bytes are identical on a re-run, and
#     `git -C submodules/constitution status --porcelain` stayed clean of them),
#     but the ONLY thing between a read-only audit and a mutated consumed
#     submodule was IDEMPOTENCE. This repository does not commit to the
#     constitution submodule at all, so any write there is outside what it owns.
#   * `lib/wiring_sweep_precondition.sh` is a SOURCED helper — its own Usage
#     block documents `. lib/wiring_sweep_precondition.sh`, not an invocation.
#   * `covenant_propagation_suite.sh` is a BATCH RUNNER that requires a
#     subcommand; run bare it prints its usage and exits 2, which the sweep
#     scores as an ERROR against this tree.
#
# WHY NOT A NAME LIST. The same reason the gate population itself is not one:
# it moved 57 -> 286 on a single fast-forward, and a list written here is wrong
# at the next pin. Every test below reads EVIDENCE out of the file.
#
# WHICH DIRECTION TO ERR IN, stated rather than left implicit. Wrongly
# EXCLUDING a real gate silently reduces coverage — the blind-instrument
# failure this repository polices, and the worst outcome available here.
# Wrongly INCLUDING a non-gate produces a visible bad row somebody reads. So
# every rule below demands POSITIVE evidence of non-gate-ness, a file matching
# nothing is KEPT, and the excluded set is PRINTED with its reason on every run
# and in `--list` — an exclusion nobody can see is the same blindness in a new
# place.
#
# THE RESCUE, evaluated BEFORE any exclusion. A file that parses `--selftest`
# or `selfcheck` exposes a self-verifying entry point, so `resolve_argv` can
# invoke it as a gate whatever else it is. 18 of 286 files at this pin do, and
# the rescue is what keeps `gate_ledger.sh` (a subcommand tool) and 8 of the 15
# `lib/` files in the sweep instead of throwing them away.
#
# THE FOUR TESTS, with their measured hit counts at pin 3be10826f3d2 (286 files
# scanned; 16 excluded in total after the rescue):
#
#   N1 FIXTURE      a `fixtures/` path component. These are gate INPUTS —
#                   the set here is literally `golden_false_nonhook_decoys`,
#                   scripts SHAPED to look real so `cm_git_hooks_installed.sh`
#                   can be proved to reject them. Running a decoy as a gate is
#                   a category error. Matches 6, excludes 6.
#   N2 SOURCED      the file's OWN Usage block shows the invocation form
#                   `. <file>` / `source <file>`. Self-declaration, not a
#                   guess. Matches 5, of which 3 are rescued; excludes 2
#                   (`lib/gate_mutation_harness.sh`,
#                   `lib/wiring_sweep_precondition.sh`).
#   N3 HELPER       a `lib/` path component or a `lib_` basename prefix, AND
#                   at least one SIBLING `.sh` names the file as a helper path
#                   on a non-comment line, AND no self-verifying entry point.
#                   The naming convention alone is not enough — the sibling
#                   reference is the measured evidence that the file is a
#                   COMPONENT of another gate. Matches 7, excludes 7.
#   N4 SUBCOMMAND   the header Usage declares `<basename> <bare-word>` — a
#                   mandatory positional that is neither bracketed nor a flag.
#                   Matches 3 (`covenant_propagation_suite.sh`,
#                   `gate_ledger.sh`, `lib/dependency_register.sh`); the last
#                   two are rescued; excludes 1.
#                   WHY EXCLUDE THE SUITE RATHER THAN HAND IT ITS `gates`
#                   SUBCOMMAND, which is what GATE-TRIAGE C8 first proposed:
#                   all 81 gate names in its data pack
#                   `covenant_propagation_anchors.tsv` resolve to a
#                   `cm_covenant_114_<N>_propagation.sh` wrapper that discovery
#                   ALREADY finds and runs individually — measured 81 rows, 81
#                   matched, 0 missing. Running the suite would execute the
#                   whole family a second time and add 81 duplicate verdicts to
#                   the split. Excluding the runner loses no coverage at all.
#   N5 WRITES-BARE  the header binds the DEFAULT invocation to a WRITE verb on
#                   one line — `(no args)` / `(default)` together with
#                   write/rewrite/regenerate/overwrite/emit. Matches 1 and it
#                   is the generator. It correctly spares
#                   `cm_instrument_trap_scan.sh`, whose `(no args)` line
#                   describes a read-only CORPUS mode.
#
# SIGNALS EVALUATED AND REJECTED, with the counts that killed them — recorded
# so the next reader does not re-propose them:
#
#   * THE EXECUTABLE BIT. 278 of 286 are executable; the 8 that are not include
#     no gate. It would miss `lib/wiring_sweep_precondition.sh`,
#     `covenant_propagation_suite.sh` AND the generator — all three are +x.
#     Useless for the case that matters.
#   * A `lib/` PATH ALONE. 15 files, but 8 of them expose `--selftest` and are
#     real self-verifying checks. Excluding on the path alone would have cut 8
#     live checks — a coverage cut disguised as a fix. Kept only as one conjunct
#     of N3.
#   * "THE FILE ASSIGNS ITS OWN GATE NAME" (`GATE=`), the §11.4.227(A) ledger's
#     own structural notion of a gate site. 58 of 286 carry no such assignment
#     and many are unambiguously gates (`cm_escape_ratchet.sh`,
#     `cm_git_hooks_installed.sh`, `cm_rule_binds_to_seam.sh`). Worse, the
#     GENERATOR does carry one — inside the heredoc template it emits — so this
#     signal classifies the one dangerous file as a gate. Rejected outright.
#   * A `Side-effects` BLOCK THAT MENTIONS WRITING. 102 of 286 match, because
#     every mutation test honestly documents "Creates + removes a temp fixture
#     dir". Subtracting the ones that say `mktemp` still leaves ~100. Prose
#     about writing is not evidence about WHERE. Rejected; N5 keys on the
#     documented DEFAULT MODE instead, which is 1 of 286.
#   * `chmod +x` ANYWHERE IN THE BODY. Present in ~280 of 286 — every mutation
#     test chmods its fixtures. Rejected.
#   * A MISSING `CM-` TOKEN. 20 of 286, but it flags `cm_escape_ratchet_selftest.sh`
#     and misses both `covenant_propagation_suite.sh` and the generator, which
#     name `CM-COVENANT-114-<N>-PROPAGATION` in their prose. Rejected.
#
# STATED LIMIT (§11.4.6). N5 is the narrowest rule here and it rests on a
# self-declaration in the file's own documented interface: a generator that
# documents itself differently is NOT caught, and would show up as a visible
# bad row rather than as a silent exclusion. That is the direction chosen on
# purpose. Nothing below claims to detect a write by executing anything.
# ─────────────────────────────────────────────────────────────────────────────

# _names_this_file_as_helper <gates-dir> <basename> <self-path>
# 0 when some OTHER *.sh under the gates tree mentions <basename> on a line
# that is not a comment — i.e. treats it as a path it reads, sources or copies.
# EVERY sibling is examined, not the first one grep happens to return: a file
# whose only mention of the basename is in its own prose would otherwise decide
# the question, and which file that is depends on directory read order. That
# defect was present in the first draft of this function and it silently kept
# `lib/covenant_propagation_mutation_engine.sh` in the sweep.
_names_this_file_as_helper() {
    local gd="$1" b="$2" self="$3" f
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ "$f" = "$self" ] && continue
        # A NON-comment mention: the sibling treats it as a path it reads,
        # sources or copies, rather than merely writing about it.
        if grep -F -- "$b" "$f" 2>/dev/null | grep -qvE '^[[:space:]]*#'; then
            return 0
        fi
    done < <(grep -rlF --include='*.sh' -- "$b" "$gd" 2>/dev/null)
    return 1
}

# nongate_reason <path> <path-relative-to-gates-dir> -> a reason, or empty
nongate_reason() {
    local g="$1" rel="$2" hdr b
    b="$(basename "$rel")"

    # RESCUE — a self-verifying entry point makes it invocable as a gate.
    grep -qE '^[[:space:]]*(--selftest|selfcheck)\)' "$g" && return 0

    case "/$rel" in
        */fixtures/*)
            printf 'FIXTURE — a gate INPUT under fixtures/, deliberately shaped to look like a script'
            return 0 ;;
    esac

    hdr="$(_gate_header "$g")"

    if printf '%s\n' "$hdr" \
       | grep -qE '^#[[:space:]]+(\.|source)[[:space:]]+[A-Za-z0-9_./$"{}-]+\.sh'; then
        printf 'SOURCED — its own Usage documents `. <file>`, not an invocation'
        return 0
    fi

    case "/$rel" in
        */lib/*|*/lib_*)
            if _names_this_file_as_helper "$GATES_DIR" "$b" "$g"; then
                printf 'HELPER — a lib component named as a path by a sibling gate, with no self-verifying entry point'
                return 0
            fi ;;
    esac

    if printf '%s\n' "$hdr" \
       | grep -qE "^#[[:space:]]+(\./)?$(printf '%s' "$b" | sed 's/[.[\*^$]/\\&/g')[[:space:]]+[a-z][a-z0-9_-]*([[:space:]]|\$)"; then
        printf 'SUBCOMMAND — its Usage requires a positional subcommand; bare is a usage refusal, not a verdict'
        return 0
    fi

    if printf '%s\n' "$hdr" \
       | grep -qiE '\((no args?|default)\)[^#]*\b((re)?write|regenerat|overwrit|emit)'; then
        printf 'WRITES-BARE — its Usage binds the no-argument invocation to a WRITE; bare is its generator mode'
        return 0
    fi
    return 0
}

# ── Discovery — never a hardcoded list ──────────────────────────────────────
GATES_RAW="$(find "$GATES_DIR" -type f -name '*.sh' 2>/dev/null | sort)"
if [ -z "${GATES_RAW//[$' \t\r\n']/}" ]; then
    echo "SWEEP-ERROR: zero gates discovered under ${GATES_DIR}" >&2
    exit 2
fi
GATES=""; NONGATES=""
while IFS= read -r _g; do
    [ -n "$_g" ] || continue
    _rel="${_g#"$GATES_DIR"/}"
    _why="$(nongate_reason "$_g" "$_rel")"
    if [ -n "$_why" ]; then
        NONGATES="${NONGATES}${_rel}"$'\t'"${_why}"$'\n'
    else
        GATES="${GATES}${_g}"$'\n'
    fi
done <<< "$GATES_RAW"
GATES="${GATES%$'\n'}"
GATE_SCANNED="$(printf '%s\n' "$GATES_RAW" | grep -c . )"
NONGATE_COUNT="$(printf '%s' "$NONGATES" | grep -c . )"
if [ -z "${GATES//[$' \t\r\n']/}" ]; then
    echo "SWEEP-ERROR: zero gates discovered under ${GATES_DIR}" >&2
    echo "             (${GATE_SCANNED} *.sh scanned, all ${NONGATE_COUNT} classified as non-gates)" >&2
    exit 2
fi
GATE_COUNT="$(printf '%s\n' "$GATES" | grep -c . )"

# ─────────────────────────────────────────────────────────────────────────────
# THE EXPECTED-GATE LEDGER — DROP detection
#
# THE HOLE THIS CLOSES. Discovery is dynamic, which §11.4.32 requires ("gates
# are DISCOVERED, never hardcoded"). Dynamic discovery is live in the ADD
# direction — a new gate file is picked up and its failure reddens the sweep,
# with no edit here (proved as M9). It was BLIND in the DROP direction: delete a
# gate file and the discovered count simply falls, with nothing to compare it
# against, and the sweep still exits 0. A silently deleted gate was invisible.
#
# WHY A HARDCODED EXPECTED LIST IS WRONG BY CONSTRUCTION. The population moved
# 57 -> 286 when the constitution submodule was fast-forwarded. Any list written
# into this script is wrong at the next pin, and "wrong at the next pin" means
# it gets deleted or made advisory the first time it fires — which is how a gate
# dies. So the expected set is DATA, recorded in
# `scripts/constitution-gate-ledger.tsv`, updated only by an explicit
# `--update-ledger`, and visible in `git diff` when it changes.
#
# THE DISCRIMINATOR — "the pin moved" vs "a gate vanished". Two instruments,
# and the second one is what makes the separation real rather than assumed:
#
#   1. THE PIN. The gate population is a function of the constitution's commit.
#      If the ledger's pin EQUALS the live pin, the population is determined:
#      anything ledgered and now missing VANISHED. No git query needed, and this
#      is the case that holds on a tree nobody has bumped.
#
#   2. GIT ITSELF, when the pin HAS moved. A missing path that git still reports
#      as TRACKED at the current commit was deleted from the working tree — a
#      vanished gate, DETERMINED, regardless of how far the pin travelled. A
#      missing path that is NOT tracked at the current commit is a gate upstream
#      no longer carries — a legitimate population change.
#
# THE STATED LIMIT (§11.4.6), not asserted away: when the pin has moved AND the
# constitution is not a git work tree (a vendored or archive-extracted copy),
# neither instrument applies and attribution is UNDETERMINED. That is reported
# as rc-2-class ERROR — a blind instrument, never a pass (§11.4.201(7)(b)) —
# rather than guessed in either direction. A second, smaller limit: a gate
# deleted upstream AND re-added under a different name in the same bump reads as
# one removal plus one addition, which is what it is; the ledger does not track
# renames.
#
# ADDITIONS are a NOTE, never a failure. An added gate is already visible — the
# sweep runs it and its failure reddens the run. Only the DROP direction was
# blind, and only the DROP direction gates here.
# ─────────────────────────────────────────────────────────────────────────────
LEDGER_FILE="${root}/scripts/constitution-gate-ledger.tsv"

# The live pin, and whether git can be consulted about this checkout at all.
CONSTITUTION_IS_WORKTREE=0
LIVE_PIN="unknown"
_c_top="$(git -C "$CONSTITUTION_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_c_top" ] && [ -d "$_c_top" ] && [ "$(cd "$_c_top" 2>/dev/null && pwd)" = "$CONSTITUTION_ROOT" ]; then
    CONSTITUTION_IS_WORKTREE=1
    LIVE_PIN="$(git -C "$CONSTITUTION_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
fi

live_gate_names() { printf '%s\n' "$GATES" | sed "s|^${GATES_DIR}/||" | grep -v '^$' | sort; }

write_ledger() {
    {
        echo "# constitution-gate-ledger.tsv — the expected-gate baseline for"
        echo "# scripts/verify-all-constitution-rules.sh (§11.4.32)."
        echo "#"
        echo "# GENERATED, never hand-written. Regenerate deliberately with:"
        echo "#     bash scripts/verify-all-constitution-rules.sh --update-ledger"
        echo "# and review the resulting git diff: that diff IS the record that a"
        echo "# population change was intended. A gate that disappears without one is"
        echo "# a DROP, and the sweep fails on it."
        echo "#"
        echo "# TAB-separated. Field 1 is the row type, from a closed vocabulary:"
        echo "#     pin    <constitution HEAD sha, or 'unknown' if not a git work tree>"
        echo "#     gate   <path relative to submodules/constitution/scripts/gates/>"
        echo "# An unrecognised field-1 token is a MALFORMED ledger and is reported as"
        echo "# could-not-determine — never as a pass."
        echo "#"
        echo "# The pin is recorded because the gate population is a function of it:"
        echo "# at an UNCHANGED pin a missing gate vanished; at a CHANGED pin git is"
        echo "# asked whether the missing path is still tracked, which separates an"
        echo "# upstream removal from a local deletion."
        printf 'pin\t%s\n' "$LIVE_PIN"
        live_gate_names | while IFS= read -r n; do [ -n "$n" ] && printf 'gate\t%s\n' "$n"; done
    } > "$1"
}

if [ -n "$update_ledger" ]; then
    tmp_new="$(mktemp)" || { echo "SWEEP-ERROR: mktemp failed" >&2; exit 2; }
    write_ledger "$tmp_new"
    if [ -r "$LEDGER_FILE" ]; then
        old_pin="$(awk -F'\t' '$1=="pin"{print $2; exit}' "$LEDGER_FILE")"
        added="$(comm -13 <(awk -F'\t' '$1=="gate"{print $2}' "$LEDGER_FILE" | sort) <(live_gate_names))"
        removed="$(comm -23 <(awk -F'\t' '$1=="gate"{print $2}' "$LEDGER_FILE" | sort) <(live_gate_names))"
        echo "ledger: ${LEDGER_FILE#"$root"/}"
        echo "  pin   : ${old_pin:-<none>} -> ${LIVE_PIN}"
        echo "  gates : $(awk -F'\t' '$1=="gate"' "$LEDGER_FILE" | grep -c .) -> ${GATE_COUNT}"
        [ -n "$added" ]   && { echo "  ADDED:";   printf '%s\n' "$added"   | sed 's/^/    + /'; }
        [ -n "$removed" ] && { echo "  REMOVED:"; printf '%s\n' "$removed" | sed 's/^/    - /'; }
        [ -z "$added" ] && [ -z "$removed" ] && echo "  no membership change"
    else
        echo "ledger: ${LEDGER_FILE#"$root"/} (created)"
        echo "  pin   : ${LIVE_PIN}"
        echo "  gates : ${GATE_COUNT}"
    fi
    mkdir -p "$(dirname "$LEDGER_FILE")" || { echo "SWEEP-ERROR: cannot create the ledger directory" >&2; exit 2; }
    mv "$tmp_new" "$LEDGER_FILE" || { echo "SWEEP-ERROR: cannot write the ledger" >&2; exit 2; }
    echo "Ledger written. Commit it with the change that moved the population."
    exit 0
fi

# check_ledger — sets LEDGER_STATE and fills the report variables.
#   clean | added | drop | upstream | undet | absent | malformed
LEDGER_STATE="absent"
LEDGER_REPORT=""
LEDGER_DROPPED=""
check_ledger() {
    local ledger_pin="" bad_row=0 n missing added_n dropped="" upstream="" undet=""
    if [ ! -r "$LEDGER_FILE" ]; then
        LEDGER_STATE="absent"
        return
    fi
    while IFS=$'\t' read -r f1 _rest; do
        case "$f1" in
            ''|'#'*) ;;
            pin|gate) ;;
            *) bad_row=1 ;;
        esac
    done < "$LEDGER_FILE"
    if [ "$bad_row" -eq 1 ]; then
        LEDGER_STATE="malformed"
        return
    fi
    ledger_pin="$(awk -F'\t' '$1=="pin"{print $2; exit}' "$LEDGER_FILE")"
    if [ -z "$ledger_pin" ]; then
        LEDGER_STATE="malformed"
        LEDGER_REPORT="the ledger records no pin row"
        return
    fi

    missing="$(comm -23 <(awk -F'\t' '$1=="gate"{print $2}' "$LEDGER_FILE" | sort) <(live_gate_names))"
    added_n="$(comm -13 <(awk -F'\t' '$1=="gate"{print $2}' "$LEDGER_FILE" | sort) <(live_gate_names))"

    while IFS= read -r n; do
        [ -n "$n" ] || continue
        if [ "$ledger_pin" = "$LIVE_PIN" ]; then
            dropped="${dropped}${n}"$'\n'
        elif [ "$CONSTITUTION_IS_WORKTREE" -eq 1 ]; then
            if git -C "$CONSTITUTION_ROOT" ls-files --error-unmatch -- "scripts/gates/${n}" >/dev/null 2>&1; then
                dropped="${dropped}${n}"$'\n'
            else
                upstream="${upstream}${n}"$'\n'
            fi
        else
            undet="${undet}${n}"$'\n'
        fi
    done <<< "$missing"

    LEDGER_DROPPED="$dropped"
    LEDGER_REPORT="ledger pin ${ledger_pin}$( [ "$ledger_pin" = "$LIVE_PIN" ] && echo ' (UNCHANGED)' || echo " -> live ${LIVE_PIN} (MOVED)")"
    if [ -n "$dropped" ]; then
        LEDGER_STATE="drop"
    elif [ -n "$undet" ]; then
        LEDGER_STATE="undet"
        LEDGER_DROPPED="$undet"
    elif [ -n "$upstream" ]; then
        LEDGER_STATE="upstream"
        LEDGER_DROPPED="$upstream"
    elif [ -n "$added_n" ]; then
        LEDGER_STATE="added"
        LEDGER_DROPPED="$added_n"
    else
        LEDGER_STATE="clean"
    fi
}

# ── Root resolution — three pieces of EVIDENCE, never a name list ───────────
#
# THE DEFECT THIS REPLACES (docs/constitution-adoption/GATE-TRIAGE.md §9.6 C1).
# The old form consulted a gate's usage header ONLY after
# `grep -qE '^\s*--root\)' "$g"` succeeded — i.e. only if the gate parsed
# `--root` IN ITS OWN FILE. §11.4.251 moved the whole 82-gate propagation family
# to thin wrappers (61 lines) whose argument parsing lives in the sourced
# `lib/covenant_propagation_engine.sh`, so 81 of them have no such case arm even
# though their headers plainly declare `--root <consumer-root>`. They received no
# root, fell back to the engine's own `${CONSUMER_ROOT:-..}` default, and `..`
# from this repository is the operator's ENTIRE projects directory. Measured on
# the 2026-09-02 sweep: 85 of 287 verdicts described the wrong tree, 81 of them
# FAILing with ZERO BYTES of output because the engine died under `set -e`
# mid-scan — a blind instrument scored as an accusation, the §11.4.201(7)(b)
# hazard inverted. Second sub-defect: the `root_kind` case knew
# `consumer-root|project-root|constitution-root` and nothing else, so the 9 gates
# whose headers say the generic `--root <dir>` fell through to `*) argv=""`.
#
# WHY THREE TESTS AND NOT ONE. Simply ungating the header lookup would be wrong
# in two measurable ways, so each test below is answering a question that has a
# real counter-example in this pin's gate corpus:
#
#   A. WHOSE header is it? `covenant_propagation_wrappers_generate.sh` is a
#      code GENERATOR whose heredoc template contains the text
#      `--root <consumer-root>` — the interface of the wrappers it EMITS, not its
#      own. A file-wide grep reads generated text as a declaration. So the lookup
#      is scoped to the gate's own leading comment header. Measured: that scoping
#      changes the answer for exactly one file of 286, and it is that one.
#
#   B. Can the gate actually RECEIVE it? `covenant_propagation_suite.sh` is a
#      batch runner whose header documents `suite gates [--root <consumer-root>]`
#      but which parses no flags itself and requires a subcommand first. Handing
#      it `--root <path>` produces a usage refusal, not a verdict. So a gate is
#      given `--root` only on positive evidence that some parser will accept it:
#      its own `--root)` arm, or a `--root)` arm in a `lib/*.sh` it names.
#
#   C. WHICH root does it mean? `<dir>` names no side, and getting this backwards
#      is as damaging as not resolving it at all. `cm_first_refusal_observed.sh`
#      declares `--root <dir>` and means the CONSTITUTION root
#      (`root="${CONSTITUTION_ROOT:-$(cd "${here}/../.." && pwd)}"`), while
#      `cm_oracle_strategy_named_and_independent.sh` declares the same `<dir>`
#      and means the tree under test. The discriminator is the gate's own
#      description on that usage line, so a new gate is classified by what it
#      says rather than by being added to a list here.
#
# Proved in both directions by M16/M17/M18 under `--prove-failure`.

# `_gate_header` — the gate's OWN leading comment block — is defined ABOVE the
# discovery block, because the non-gate classifier needs it there. Test A below
# uses that same function: everything from below the shebang down to the first
# line that is neither blank nor a `#` comment. A `--root` token found BELOW
# that line is body text — a heredoc template, generated code, a fixture — and
# is not this gate's interface.

# _gate_parses_root <gate-path> -> 0 if some parser will accept `--root <path>`
# Its own case arm, or one in a `lib/*.sh` the gate names and that exists beside
# it. Absence of evidence is NOT evidence of a parser: the gate keeps its own
# default and the sweep says so in --list rather than guessing.
_gate_parses_root() {
    local g="$1" d lib
    grep -qE '^[[:space:]]*--root\)' "$g" && return 0
    d="$(dirname "$g")"
    for lib in $(grep -oE '\blib/[A-Za-z0-9_.-]+\.sh' "$g" | sort -u); do
        [ -r "${d}/${lib}" ] || continue
        if grep -qE '^[[:space:]]*--root\)' "${d}/${lib}"; then return 0; fi
    done
    return 1
}

# resolve_argv <gate-path> -> echoes the arguments to pass (may be empty)
resolve_argv() {
    local g="$1" argv="" root_kind hdr dir_line
    if grep -qE '^[[:space:]]*--selftest\)' "$g"; then
        printf '%s' "--selftest"; return
    fi
    if grep -qE '^[[:space:]]*selfcheck\)' "$g"; then
        printf '%s' "selfcheck"; return
    fi
    hdr="$(_gate_header "$g")"                                          # test A
    root_kind="$(printf '%s\n' "$hdr" | grep -oE -m1 -- '--root <[a-z-]+>' \
                 | head -1 | sed -E 's/.*<(.*)>/\1/')"
    if [ -n "$root_kind" ] && _gate_parses_root "$g"; then              # test B
        case "$root_kind" in
            constitution-root)          argv="--root ${CONSTITUTION_ROOT}" ;;
            consumer-root|project-root) argv="--root ${root}" ;;
            dir)                                                        # test C
                # EVERY header line that mentions `--root <dir>`, not the first.
                # The usual shape is a bare SYNOPSIS line
                # (`gate.sh [--root <dir>] [--quiet]`) followed by the OPTION
                # line that actually describes it, and the synopsis matches
                # first. Taking only the first line read the description of
                # every `<dir>` gate as blank — caught by M17, which is why that
                # case reads the gate in both directions instead of asserting
                # one. A synopsis carries no descriptive word, so folding the
                # lines together cannot invent a classification.
                dir_line="$(printf '%s\n' "$hdr" | grep -E -- '--root <dir>' | tr '\n' ' ')"
                case "$dir_line" in
                    *constitution*) argv="--root ${CONSTITUTION_ROOT}" ;;
                    *)              argv="--root ${root}" ;;
                esac
                ;;
            *) argv="" ;;   # a vocabulary this resolver has never seen -> the
                            # gate's own default, and no pretence otherwise
        esac
    fi
    if [ -n "$quiet" ] && grep -qE '^[[:space:]]*--quiet\)' "$g"; then
        argv="${argv} --quiet"
    fi
    printf '%s' "$argv"
}

if [ -n "$list_only" ]; then
    echo "Discovered ${GATE_COUNT} gate script(s) under ${GATES_DIR#"$root"/}:"
    _n_root=0; _n_croot=0; _n_default=0
    while IFS= read -r g; do
        [ -n "$g" ] || continue
        _a="$(resolve_argv "$g")"
        case "$_a" in
            "--root ${CONSTITUTION_ROOT}"*) _n_croot=$((_n_croot+1)) ;;
            "--root ${root}"*)              _n_root=$((_n_root+1)) ;;
            *)                              _n_default=$((_n_default+1)) ;;
        esac
        printf '  %-64s  argv: %s\n' "${g#"$GATES_DIR"/}" "${_a:-(gate defaults)}"
    done <<< "$GATES"
    echo
    # Root resolution is the thing this listing exists to make auditable: a gate
    # pointed at the wrong tree still returns a verdict, and the verdict is about
    # somewhere else. The three counts are printed so a regression is visible at
    # a glance rather than by reading 286 rows.
    echo "Root resolution: ${_n_root} gate(s) -> the project root, ${_n_croot} -> the constitution,"
    echo "                 ${_n_default} left on their own default (CONSUMER_ROOT=${root} is exported to those)."
    echo
    # The excluded set is PRINTED, never silently dropped: an exclusion nobody
    # can see is the blind-instrument failure moved to a new place (§11.4.6).
    echo "Non-gate exclusions: ${NONGATE_COUNT} of ${GATE_SCANNED} *.sh scanned; ${GATE_COUNT} invoked."
    if [ "$NONGATE_COUNT" -gt 0 ]; then
        printf '%s' "$NONGATES" | while IFS=$'\t' read -r _n _r; do
            [ -n "$_n" ] && printf '  %-64s  EXCLUDED: %s\n' "$_n" "$_r"
        done
    fi
    echo
    check_ledger
    echo "Expected-gate ledger: ${LEDGER_FILE#"$root"/}  state: ${LEDGER_STATE}${LEDGER_REPORT:+  (${LEDGER_REPORT})}"
    echo
    echo "Project-side gate: tests/test_constitution_inheritance.sh  argv: --root ${root}"
    echo
    echo "§11.4.35 consumer-registered env for CM-OPENDESIGN-UI-SYSTEM:"
    echo "  OD_THEME_GLOBS    : ${OD_THEME_GLOBS}"
    echo "  OD_TOKEN_GLOBS    : ${OD_TOKEN_GLOBS}"
    echo "  OD_VISREG_GLOBS   : ${OD_VISREG_GLOBS}"
    echo "  OD_MANIFEST_GLOBS : ${OD_MANIFEST_GLOBS}"
    exit 0
fi

echo "======================================================================"
echo "§11.4.32 VALIDATION SWEEP — verify-all-constitution-rules.sh"
echo "======================================================================"
echo "project root        : ${root}"
echo "constitution        : ${CONSTITUTION_ROOT}"
echo "constitution HEAD   : $(git -C "$CONSTITUTION_ROOT" rev-parse HEAD 2>/dev/null || echo 'unknown (not a git worktree)')"
echo "gates discovered    : ${GATE_COUNT} (dynamically, under scripts/gates/**)"
echo "non-gates excluded  : ${NONGATE_COUNT} of ${GATE_SCANNED} *.sh scanned — fixtures, sourced libs,"
echo "                      subcommand tools and write-by-default generators, each named"
echo "                      with its reason by --list (never silently dropped)"
echo "CONSUMER_ROOT       : ${CONSUMER_ROOT} (exported; --list shows the per-gate --root)"
echo "OD_* gate inputs    : §11.4.35 consumer-registered (see the block above the discovery section)"
echo "  OD_THEME_GLOBS    : ${OD_THEME_GLOBS}"
echo "  OD_TOKEN_GLOBS    : ${OD_TOKEN_GLOBS}"
echo "  OD_VISREG_GLOBS   : ${OD_VISREG_GLOBS}"
echo "  OD_MANIFEST_GLOBS : ${OD_MANIFEST_GLOBS}"
if [ -n "$TIMEOUT_BIN" ]; then
    echo "per-gate timeout    : ${GATE_TIMEOUT}s"
else
    echo "per-gate timeout    : NOT ENFORCED — coreutils 'timeout' is not on PATH"
fi
echo

# ── §11.4.32 step 1 — the governance-cascade verifier ───────────────────────
echo "---- STEP 0 — expected-gate ledger (DROP detection) ------------------"
check_ledger
case "$LEDGER_STATE" in
    clean)
        echo "✅ LEDGER OK — all ${GATE_COUNT} discovered gate(s) are ledgered and every"
        echo "               ledgered gate is present. ${LEDGER_REPORT}." ;;
    added)
        echo "ℹ LEDGER NOTE — nothing vanished; the tree carries gate(s) the ledger does"
        echo "                not list. An ADDED gate is already visible (the sweep runs"
        echo "                it), so this does not gate. Re-baseline deliberately with"
        echo "                --update-ledger. ${LEDGER_REPORT}."
        printf '%s' "$LEDGER_DROPPED" | sed 's/^/                  + /' ;;
    upstream)
        echo "ℹ LEDGER NOTE — gate(s) the ledger lists are gone AND the pin moved AND git"
        echo "                reports each of them as NOT TRACKED at the current commit."
        echo "                That is an upstream removal, not a local deletion, so it does"
        echo "                not gate. Re-baseline with --update-ledger."
        echo "                ${LEDGER_REPORT}."
        printf '%s' "$LEDGER_DROPPED" | sed 's/^/                  - /' ;;
    drop)
        echo "❌ LEDGER DROP — gate(s) recorded in the ledger are GONE from this tree, and"
        echo "                 the deletion is DETERMINED, not inferred: ${LEDGER_REPORT}."
        printf '%s' "$LEDGER_DROPPED" | sed 's/^/                   - /'
        echo "                 A silently deleted gate is a §11.4.32 anti-bluff violation:"
        echo "                 the sweep would otherwise exit PASS having run fewer gates"
        echo "                 than it is supposed to. If the removal is intended, record"
        echo "                 it with --update-ledger so the change lands in the diff." ;;
    undet)
        echo "⚠ LEDGER UNDETERMINED — gate(s) the ledger lists are missing, the pin has"
        echo "                MOVED, and the constitution is not a git work tree here, so"
        echo "                nothing can say whether upstream dropped them or somebody"
        echo "                deleted them. That is could-not-determine, and a blind"
        echo "                instrument is never a pass (§11.4.201(7)(b)). ${LEDGER_REPORT}."
        printf '%s' "$LEDGER_DROPPED" | sed 's/^/                  ? /' ;;
    malformed)
        echo "⚠ LEDGER UNREADABLE — ${LEDGER_FILE#"$root"/} does not parse${LEDGER_REPORT:+ (${LEDGER_REPORT})}."
        echo "                The row vocabulary is closed {pin,gate}. A ledger that cannot"
        echo "                be read has certified nothing; regenerate it deliberately"
        echo "                with --update-ledger." ;;
    absent)
        echo "⚠ NO LEDGER — ${LEDGER_FILE#"$root"/} does not exist, so DROP detection is"
        echo "                OFF: a deleted gate would lower the discovered count with"
        echo "                nothing to compare against, and this sweep would still exit 0."
        echo "                That is the blind state the ledger exists to end, so it is"
        echo "                reported as could-not-determine, never as a pass."
        echo "                Fix: bash scripts/verify-all-constitution-rules.sh --update-ledger" ;;
esac
echo

# ── §11.4.32 step 1 — the governance-cascade verifier ───────────────────────
echo "---- STEP 1 — governance-cascade verifier (§11.4.32 step 1) ----------"
CASCADE="${root}/scripts/verify-governance-cascade.sh"
step1_state="skip"
if [ -x "$CASCADE" ] || [ -r "$CASCADE" ]; then
    echo "running: ${CASCADE#"$root"/}"
    if [ -n "$quiet" ]; then
        $TIMEOUT_BIN bash "$CASCADE" >/dev/null 2>&1
    else
        $TIMEOUT_BIN bash "$CASCADE"
    fi
    step1_rc=$?
    # The cascade verifier's exit contract is THREE-valued, not two-valued (see
    # its own "Exit codes" header in scripts/verify-governance-cascade.sh):
    #     0 = the cascade is intact
    #     1 = a REAL violation in the tree
    #     2 = COULD NOT VERIFY — an environment/instrument fault (root missing,
    #         submodule uninitialised, unreadable file, mktemp failure). That
    #         file states it verbatim: "An internal error is NEVER reported as 1
    #         — a verifier that cannot see must say so, not accuse the tree."
    # This block used to collapse EVERY non-zero rc into STEP1 FAIL, which threw
    # that distinction away and made a broken INSTRUMENT read as a governance
    # violation of the TREE. Branch on the real code instead. Anything that is
    # neither 0 nor 1 — rc=2, a 124 from the `timeout` wrapper, a 126/127 exec
    # failure, a signal death — is the same class of event: step 1 never reached
    # a verdict, so it must be reported as ERROR, not FAIL.
    case "$step1_rc" in
        0)  step1_state="pass"
            echo "✅ STEP1 PASS" ;;
        1)  step1_state="fail"
            echo "❌ STEP1 FAIL — the cascade verifier reported a real governance"
            echo "               violation in this tree (rc=1)." ;;
        *)  step1_state="error"
            echo "⚠ STEP1 ERROR — the cascade verifier could not complete (rc=${step1_rc});"
            echo "                this reports a BROKEN CHECK, not a governance violation."
            echo "                Per that verifier's own exit contract, rc=2 means COULD"
            echo "                NOT VERIFY (environment / instrument fault). NOTHING is"
            echo "                being alleged about this tree — step 1 simply did not"
            echo "                run to a verdict. An unrunnable check is never a pass"
            echo "                either (§11.4.201(7)(b), blind instrument), so it still"
            echo "                makes this sweep exit non-zero — exactly like the ERROR"
            echo "                class in the per-gate counters below." ;;
    esac
else
    step1_state="skip"
    echo "⏭ STEP1 SKIP — scripts/verify-governance-cascade.sh does not exist in this"
    echo "               repository. §11.4.32 step 1 requires the sweep to re-run it;"
    echo "               writing it is outstanding work. This is an explicit SKIP with"
    echo "               a reason (§11.4.3), NOT a pass, and it is recorded as open"
    echo "               conflict OC-3 in Constitution.md."
fi
echo

# ── §11.4.32 step 2 — run every discovered gate ─────────────────────────────
echo "---- STEP 2 — every gate under submodules/constitution/scripts/gates --"
pass=0; fail=0; err=0
FAIL_NAMES=""; ERR_NAMES=""
DETAIL_DIR="$(mktemp -d)"
trap 'rm -rf "$DETAIL_DIR"' EXIT INT TERM

run_one() {
    local label="$1" cmd_display="$2"; shift 2
    local out rc start end ms
    start="$(date +%s%N)"
    out="$("$@" 2>&1)"; rc=$?
    end="$(date +%s%N)"; ms=$(( (end - start) / 1000000 ))
    local verdict
    case "$rc" in
        0) verdict="PASS"; pass=$((pass+1)) ;;
        1) verdict="FAIL"; fail=$((fail+1)); FAIL_NAMES="${FAIL_NAMES}${label}"$'\n' ;;
        *) verdict="ERROR"; err=$((err+1)); ERR_NAMES="${ERR_NAMES}${label} (rc=${rc})"$'\n' ;;
    esac
    if [ "$verdict" != "PASS" ]; then
        { echo "===== ${label}  [${verdict} rc=${rc}]"; echo "      argv: ${cmd_display}"; printf '%s\n' "$out"; echo; } \
            >> "${DETAIL_DIR}/detail.txt"
    fi
    printf '%-6s rc=%-3s %7sms  %-58s  %s\n' "$verdict" "$rc" "$ms" "$label" "$cmd_display"
    if [ -z "$quiet" ] && [ "$verdict" = "PASS" ]; then
        printf '%s\n' "$out" | sed 's/^/        /'
    fi
}

while IFS= read -r g; do
    [ -n "$g" ] || continue
    label="${g#"$GATES_DIR"/}"
    argv="$(resolve_argv "$g")"
    scratch=""
    if [ "$argv" = "selfcheck" ]; then
        scratch="$(mktemp -d)"
        run_one "$label" "selfcheck <scratch>" bash "$g" selfcheck "$scratch"
        rm -rf "$scratch"
    elif [ -n "$argv" ]; then
        # shellcheck disable=SC2086
        run_one "$label" "$argv" $TIMEOUT_BIN bash "$g" $argv
    else
        run_one "$label" "(gate defaults)" $TIMEOUT_BIN bash "$g"
    fi
done <<< "$GATES"

echo
echo "---- STEP 2b — project-side gates -------------------------------------"
INHERITANCE="${root}/tests/test_constitution_inheritance.sh"
if [ -r "$INHERITANCE" ]; then
    if [ -n "$quiet" ]; then
        run_one "tests/test_constitution_inheritance.sh" "--root <root> --quiet" $TIMEOUT_BIN bash "$INHERITANCE" --root "$root" --quiet
    else
        run_one "tests/test_constitution_inheritance.sh" "--root <root>" $TIMEOUT_BIN bash "$INHERITANCE" --root "$root"
    fi
    GATE_COUNT=$((GATE_COUNT+1))
else
    echo "⏭ SKIP — tests/test_constitution_inheritance.sh absent (§11.4.3 reasoned skip)"
fi

echo
echo "======================================================================"
echo "SUMMARY"
echo "======================================================================"
echo "gates run           : ${GATE_COUNT}"
echo "  PASS              : ${pass}"
echo "  FAIL   (rc=1)     : ${fail}"
echo "  ERROR  (rc!=0,1)  : ${err}"
echo "§11.4.32 step 1     : ${step1_state}"
if [ "$step1_state" = "error" ]; then
    echo "                      (COULD NOT VERIFY — broken check, not a tree violation)"
fi
echo "expected-gate ledger: ${LEDGER_STATE}"
case "$LEDGER_STATE" in
    drop)      echo "                      (a ledgered gate VANISHED — see STEP 0)" ;;
    undet|absent|malformed)
               echo "                      (COULD NOT VERIFY the gate population — never a pass)" ;;
esac
if [ -n "$FAIL_NAMES" ]; then
    echo
    echo "FAILED:"
    printf '%s' "$FAIL_NAMES" | sed 's/^/  ❌ /'
fi
if [ -n "$ERR_NAMES" ]; then
    echo
    echo "ERRORED (blind instrument — §11.4.201(7)(b), never a pass):"
    printf '%s' "$ERR_NAMES" | sed 's/^/  ⚠ /'
fi

if [ -s "${DETAIL_DIR}/detail.txt" ]; then
    echo
    echo "======================================================================"
    echo "DETAIL — full output of every non-PASS gate"
    echo "======================================================================"
    cat "${DETAIL_DIR}/detail.txt"
fi

echo "======================================================================"
# Step 1's ERROR state exits non-zero for the SAME reason the `err` counter does:
# §11.4.201(7)(b) — a blind instrument is never a pass. It is deliberately NOT
# folded into `fail`, because nothing about this tree has been shown to be wrong;
# an unrunnable check must not be silently swallowed, and must not be dressed up
# as a violation either. This mirrors the existing ERROR convention rather than
# inventing a second one.
ledger_gates=0
case "$LEDGER_STATE" in
    drop|undet|absent|malformed) ledger_gates=1 ;;
esac
if [ $((fail + err)) -gt 0 ] || [ "$step1_state" = "fail" ] || [ "$step1_state" = "error" ] || [ "$ledger_gates" -eq 1 ]; then
    echo "❌ SWEEP: FAIL — ${fail} FAIL + ${err} ERROR out of ${GATE_COUNT} gate(s)."
    case "$LEDGER_STATE" in
        drop)
            echo "   plus STEP 0 = LEDGER DROP — a gate recorded in the expected-gate"
            echo "   ledger is gone from this tree. Every count above was taken over a"
            echo "   population smaller than the one this sweep is supposed to run." ;;
        undet|absent|malformed)
            echo "   plus STEP 0 = ${LEDGER_STATE} — the gate population COULD NOT BE"
            echo "   VERIFIED, so nothing here rules out a silently deleted gate. That is"
            echo "   a blind instrument, never a pass (§11.4.201(7)(b))." ;;
    esac
    if [ "$step1_state" = "error" ]; then
        echo "   plus §11.4.32 step 1 = ERROR — the cascade verifier COULD NOT VERIFY."
        echo "   That is a broken check, NOT a violation of this tree. Fix the"
        echo "   instrument (or its environment) and re-run before reading anything"
        echo "   into step 1."
    fi
    echo
    echo "Before treating any of these as a regression, read"
    echo "  Constitution.md -> 'Known-excluded gate findings'"
    echo "which names the five third-party / staged carriers the propagation"
    echo "gates report, and the four failures internal to the constitution"
    echo "submodule's own tree. Those are recorded, NOT suppressed: they still"
    echo "FAIL here and they still make this sweep exit non-zero."
    exit 1
fi
echo "✅ SWEEP: PASS — all ${GATE_COUNT} gate(s) exited 0."
exit 0
