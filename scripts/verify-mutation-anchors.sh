#!/usr/bin/env bash
# verify-mutation-anchors.sh — make ANCHOR ROT visible across the prover fleet.
#
# ============================================================================
# THE FAILURE MODE THIS EXISTS FOR: rc=2 IS EASY TO SKIM PAST.
# ============================================================================
#
# A §1.1 paired-mutation prover seeds a real defect into real source, requires
# the gate to go RED, restores, and requires GREEN again. It finds the seeding
# site with an ANCHOR — a literal snippet of the source it expects to find.
#
# Anchors rot. A rename, a moved handler, or a purely cosmetic gofmt
# realignment triggered by an edit somewhere else entirely, and the prover can
# no longer find its own seeding site. It then reports UNDETERMINED — rc=2,
# which is neither a pass nor a failure, prints no red, and is easy to read
# past. The prover looks approximately fine and proves NOTHING.
#
# That is not hypothetical here. On 2026-09-01 two provers in this tree were
# measured at rc=2 with ZERO mutations executed between them, and nobody had
# noticed. The precedent is older than that: an allow-list with no rot detector
# in this same repository accumulated 26 DEAD RULES out of 429 before anyone
# looked, for exactly the same reason — nothing was ever asked.
#
# This script asks. It walks the fleet and, for every prover, records whether
# its anchors still resolve.
#
# ============================================================================
# IT ASKS THE PROVERS. IT NEVER READS THEIR MUTATIONS OUT OF THEM.
# ============================================================================
#
# This is the single most important design rule in this file, and it is written
# in blood. On 2026-09-01 a throwaway tool tried to audit exactly this question
# by SCRAPING the `<<'PY' … PY` mutation heredoc out of a prover and `exec`ing
# it, with the path bound to a real repository file. Four untracked Go sources
# were emptied to 0 bytes; they were untracked, so there was no history, no
# stash and no dangling blob, and they had to be rebuilt by hand.
#
# Therefore:
#
#   * This script NEVER extracts, compiles, or executes any fragment of a
#     prover. It invokes the prover as a program, through the one interface the
#     prover itself declares.
#   * It invokes ONLY `--check-anchors`, whose contract is that it resolves
#     every anchor and WRITES NOTHING.
#   * It decides whether a prover supports that mode by READING the file for
#     the literal string, never by trying it. Handing a prover an argument it
#     does not understand can start a FULL MUTATION RUN against the real tree —
#     provers here treat an unrecognised first argument as "run everything" —
#     and probing by trial is how an auditor becomes the accident.
#
# A prover with no `--check-anchors` is UNINSTRUMENTED: its anchor state is not
# knowable from here. That is reported as could-not-determine, never as a pass.
#
# ============================================================================
# WHY ROT FAILS BY DEFAULT, AND UNINSTRUMENTED ONLY UNDER --strict
# ============================================================================
#
# The precedent detector in this repository chose a loud, unsuppressible NOTE
# by default with an opt-in strict mode. That was the right call THERE, because
# it found 26 pre-existing dead rules and a hard failure would have blocked
# every push on day one — a detector that must be disabled to get work done
# gets disabled.
#
# The migration argument does not apply to the ROT verdict here, and the shape
# is split accordingly:
#
#   ROT (a prover that answered, and answered "my anchors are stale") is a
#   DETERMINED finding about a real instrument that is really not working. It
#   was measured at zero on adoption, so failing on it blocks nothing that was
#   previously working, and it is the exact condition that went unnoticed for
#   hours. It exits 1 by default.
#
#   UNINSTRUMENTED is genuinely could-not-determine, and retrofitting a prover
#   is real work that should not be forced by a red gate mid-flight. It is a
#   loud, unsuppressible NOTE by default — printed in a banner, never
#   summarised away, never silenceable by a flag — and becomes rc=2 under
#   `--strict`.
#
# There is no `--allow`, no `--ignore`, no suppression list. A detector with a
# suppression file is the artefact whose rot went unnoticed in the first place.
#
# THREE-VALUED EXIT, and rc=2 is never a pass:
#   0  every discovered prover answered, and every one of them resolves
#   1  ROT: at least one prover's anchors no longer resolve
#   2  could not determine: no root, no provers discovered, a prover that
#      violated the --check-anchors contract, or (under --strict) an
#      uninstrumented prover
#
# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED, and the two counts are always
# reported separately.
#
# Usage:
#   bash scripts/verify-mutation-anchors.sh
#   bash scripts/verify-mutation-anchors.sh --strict
#   bash scripts/verify-mutation-anchors.sh --root <dir>
#   bash scripts/verify-mutation-anchors.sh --prove-failure   # §1.1 paired proof

set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SELF_DIR/.." && pwd)"
STRICT=0
PROVE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --strict)        STRICT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        --root)          ROOT="${2:-}"; shift 2 ;;
        -h|--help)       sed -n '1,95p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

RESOLVED=0; ROTTED=0; UNINSTRUMENTED=0; BROKEN=0; NOANCHOR=0
ROT_LINES=""
UNINST_LINES=""

green() { printf '  \033[32m%-14s\033[0m %s\n' "$1" "$2"; }
redln() { printf '  \033[31m%-14s\033[0m %s\n' "$1" "$2"; }
yellow(){ printf '  \033[33m%-14s\033[0m %s\n' "$1" "$2"; }

# ---------------------------------------------------------------------------
# DISCOVERY. Derived from the filesystem, never a hardcoded roster: a roster is
# the thing that silently stops matching reality, which is the same defect
# class this whole script is about.
#
# Third-party and vendored trees are excluded because their provers are not
# ours to repair, and counting an upstream's rot as this tree's finding is a
# claim with no remedy attached.
# ---------------------------------------------------------------------------
discover() {
    find "$ROOT" \
        \( -path '*/.git' -o -path '*/node_modules' -o -path '*/venv' \
           -o -path '*/vendor' -o -path '*/submodules/superspec' \
           -o -path '*/.specify' -o -path '*/engines' -o -path '*/models' \) -prune -o \
        -type f -name 'prove-*.sh' -print 2>/dev/null | sort
}

# ---------------------------------------------------------------------------
# --prove-failure: the §1.1 paired mutation for THIS detector.
#
# A detector that has never been observed reporting rot is not known to detect
# rot. This builds a throwaway fleet — never the real one — and requires:
#
#   RED    a prover whose anchor no longer resolves  -> rc 1
#   GREEN  the same prover with the anchor repaired  -> rc 0
#   NOTE   an uninstrumented prover                  -> rc 0 by default, 2 strict
#
# and it asserts the subject file is byte-identical afterwards, because a
# detector that damages what it inspects would be the whole problem again.
# ---------------------------------------------------------------------------
if [ "$PROVE" -eq 1 ]; then
    printf '== prove-failure: this detector must be seen reporting rot ==\n\n'
    LAB="$(mktemp -d)" || { printf 'UNDETERMINED: cannot create a lab directory\n' >&2; exit 2; }
    trap 'rm -rf "$LAB"' EXIT
    mkdir -p "$LAB/pkg" "$LAB/gates"

    printf 'package lab\n\nfunc Serve() string { return "anchored" }\n' > "$LAB/pkg/subject.go"
    SUBJECT_SUM="$(sha256sum "$LAB/pkg/subject.go" 2>/dev/null | awk '{print $1}')"

    # A minimal prover honouring the --check-anchors contract: rc 0 resolve,
    # rc 2 stale, and it writes nothing under that mode.
    cat > "$LAB/gates/prove-lab.sh" <<'LABPROVER'
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$HERE/../pkg/subject.go"
ANCHOR='func Serve() string { return "anchored" }'
if [ "${1:-}" = "--check-anchors" ]; then
    if grep -qF -- "$ANCHOR" "$SUBJECT"; then
        echo "anchors: 1/1 resolve"; exit 0
    fi
    echo "UNDETERMINED: 1 of 1 anchors is STALE" >&2; exit 2
fi
echo "a real run would mutate the subject here"; exit 0
LABPROVER
    chmod +x "$LAB/gates/prove-lab.sh"

    # And one with no --check-anchors at all, to exercise the NOTE path.
    printf '#!/usr/bin/env bash\nexit 0\n' > "$LAB/gates/prove-uninstrumented.sh"
    chmod +x "$LAB/gates/prove-uninstrumented.sh"

    printf -- '--- GREEN: anchors intact ---\n'
    bash "${BASH_SOURCE[0]}" --root "$LAB" >"$LAB/g.out" 2>&1; G=$?
    sed 's/^/    | /' "$LAB/g.out" | head -14
    printf '    rc=%s (expected 0)\n\n' "$G"

    printf -- '--- RED: rename the anchored symbol; the mutant still PARSES ---\n'
    printf 'package lab\n\nfunc Handle() string { return "anchored" }\n' > "$LAB/pkg/subject.go"
    if command -v gofmt >/dev/null 2>&1; then
        if gofmt -e "$LAB/pkg/subject.go" >/dev/null 2>&1; then
            printf '    the mutated subject still parses (gofmt -e): a detector that only\n'
            printf '    reddens on a syntax error would prove nothing\n'
        else
            printf 'UNDETERMINED: the seeded mutant does not parse; this proof is not\n' >&2
            printf 'measuring anchor rot, it is measuring a broken file\n' >&2
            exit 2
        fi
    else
        printf '    NOTE: no gofmt on PATH; the parse assertion was NOT made\n'
    fi
    bash "${BASH_SOURCE[0]}" --root "$LAB" >"$LAB/r.out" 2>&1; R=$?
    sed 's/^/    | /' "$LAB/r.out" | head -18
    printf '    rc=%s (expected 1)\n\n' "$R"

    printf -- '--- restore, byte-identically ---\n'
    printf 'package lab\n\nfunc Serve() string { return "anchored" }\n' > "$LAB/pkg/subject.go"
    AFTER="$(sha256sum "$LAB/pkg/subject.go" 2>/dev/null | awk '{print $1}')"
    bash "${BASH_SOURCE[0]}" --root "$LAB" >"$LAB/g2.out" 2>&1; G2=$?
    printf '    rc=%s (expected 0)   subject sha256 %s\n\n' "$G2" \
           "$( [ "$AFTER" = "$SUBJECT_SUM" ] && echo 'MATCHES the original' || echo 'DIFFERS — restore failed' )"

    printf -- '--- --strict must promote the UNINSTRUMENTED note to rc=2 ---\n'
    bash "${BASH_SOURCE[0]}" --root "$LAB" --strict >"$LAB/s.out" 2>&1; S=$?
    printf '    rc=%s (expected 2)\n\n' "$S"

    FAILS=0
    [ "$G"  -eq 0 ] || { printf 'PROBLEM: intact anchors did not yield 0 (got %s)\n' "$G" >&2;  FAILS=1; }
    [ "$R"  -eq 1 ] || { printf 'PROBLEM: a STALE anchor did not yield 1 (got %s)\n' "$R" >&2;  FAILS=1; }
    [ "$G2" -eq 0 ] || { printf 'PROBLEM: the repaired tree did not yield 0 (got %s)\n' "$G2" >&2; FAILS=1; }
    [ "$S"  -eq 2 ] || { printf 'PROBLEM: --strict did not yield 2 on an uninstrumented prover (got %s)\n' "$S" >&2; FAILS=1; }
    [ "$AFTER" = "$SUBJECT_SUM" ] || { printf 'PROBLEM: the subject was not restored byte-identically\n' >&2; FAILS=1; }
    if [ "$FAILS" -ne 0 ]; then
        printf '\nPROBLEM: this detector does not grade what it claims to.\n' >&2
        exit 1
    fi
    printf 'OK: rot was DETECTED (1), a clean fleet PASSED (0), the mutant parsed, the\n'
    printf 'subject was restored byte-identically, and --strict escalated the note (2).\n'
    printf 'MUTATION PROOF: PASS — 1 mutation caught (renaming the anchored symbol flipped\n'
    printf 'this detector 0 -> 1), over 5 assertions: control 0, mutant 1, restored control\n'
    printf '0, --strict escalates the uninstrumented NOTE to 2, and the subject sha256 is\n'
    printf 'unchanged.\n'
    exit 0
fi

# ---------------------------------------------------------------------------
[ -d "$ROOT" ] || { printf 'UNDETERMINED: --root %s is not a directory\n' "$ROOT" >&2; exit 2; }

printf '== mutation-anchor rot across the prover fleet ==\n'
printf 'root: %s\n\n' "$ROOT"

TOTAL=0
while IFS= read -r prover; do
    [ -n "$prover" ] || continue
    TOTAL=$((TOTAL+1))
    rel="${prover#"$ROOT"/}"

    # A prover may DECLARE that it carries no source anchors at all — one that
    # seeds its defects into throwaway fixtures rather than into repository
    # source has nothing that can rot. The declaration is an explicit opt-out
    # written in the prover itself, in one exact spelling, and it is NOT a
    # suppression: it asserts a property of that prover, and a prover that
    # acquires an anchor later and keeps the line is lying in its own source
    # where a reviewer can see it.
    if grep -qE '^# ANCHORS: none( |$)' "$prover" 2>/dev/null; then
        green "NO-ANCHORS" "$rel — declares it seeds no repository source"
        NOANCHOR=$((NOANCHOR+1))
        continue
    fi

    # READ to decide, never probe by invocation — see the header.
    if ! grep -q -- '--check-anchors' "$prover" 2>/dev/null; then
        yellow "UNINSTRUMENTED" "$rel"
        UNINSTRUMENTED=$((UNINSTRUMENTED+1))
        UNINST_LINES="$UNINST_LINES  $rel"$'\n'
        continue
    fi

    out="$(cd "$(dirname "$prover")" && bash "$prover" --check-anchors 2>&1)"; rc=$?
    case "$rc" in
        0) green "RESOLVE" "$rel — $(printf '%s' "$out" | head -1)"
           RESOLVED=$((RESOLVED+1)) ;;
        2) redln "ROT" "$rel"
           printf '%s\n' "$out" | sed 's/^/                 | /' | head -6
           ROTTED=$((ROTTED+1))
           ROT_LINES="$ROT_LINES  $rel"$'\n' ;;
        *) # The contract is 0 or 2. Anything else means the prover is not
           # answering this question, and guessing which way it meant would be
           # exactly the bluff this tree forbids.
           yellow "CONTRACT" "$rel — --check-anchors exited $rc; the contract is 0 or 2"
           BROKEN=$((BROKEN+1)) ;;
    esac
done < <(discover)

printf '\n'
if [ "$TOTAL" -eq 0 ]; then
    printf 'UNDETERMINED: no prove-*.sh was discovered under %s. A detector that\n' "$ROOT" >&2
    printf 'inspected nothing has not reported a clean fleet; it has failed to run.\n' >&2
    exit 2
fi

printf '=== %d prover(s): %d resolve / %d ROT / %d uninstrumented / %d no-anchors / %d contract-violating ===\n' \
       "$TOTAL" "$RESOLVED" "$ROTTED" "$UNINSTRUMENTED" "$NOANCHOR" "$BROKEN"

# THE BANNER. Unsuppressible by design: there is no flag that removes it, and
# it is printed whether or not the exit code is non-zero. The whole failure
# this file addresses is a state that was technically reported and never read.
if [ "$UNINSTRUMENTED" -gt 0 ]; then
    printf '\n'
    printf '\033[33m┌─ NOTE — %d PROVER(S) CANNOT BE INTERROGATED ────────────────\033[0m\n' "$UNINSTRUMENTED"
    printf '\033[33m│\033[0m These provers declare no --check-anchors mode, so whether their\n'
    printf '\033[33m│\033[0m anchors still resolve is NOT KNOWN from here. This is\n'
    printf '\033[33m│\033[0m could-not-determine, not a pass. Two of this fleet sat dead for\n'
    printf '\033[33m│\033[0m hours in exactly this blind spot.\n'
    printf '\033[33m│\033[0m\n'
    printf '%s' "$UNINST_LINES" | sed 's/^/\o033[33m│\o033[0m/'
    printf '\033[33m│\033[0m\n'
    printf '\033[33m│\033[0m Fix: give each a --check-anchors mode that resolves every anchor\n'
    printf '\033[33m│\033[0m and writes nothing. Run with --strict to make this block.\n'
    printf '\033[33m└────────────────────────────────────────────────────────────\033[0m\n'
fi

if [ "$ROTTED" -gt 0 ]; then
    printf '\n'
    printf '\033[31m┌─ ROT — %d PROVER(S) ARE PROVING NOTHING ────────────────────\033[0m\n' "$ROTTED"
    printf '\033[31m│\033[0m Their anchors no longer resolve. Every mutation they carry is\n'
    printf '\033[31m│\033[0m UNDETERMINED, so the gates they claim to prove are UNPROVEN —\n'
    printf '\033[31m│\033[0m and rc=2 is not a pass.\n'
    printf '\033[31m│\033[0m\n'
    printf '%s' "$ROT_LINES" | sed 's/^/\o033[31m│\o033[0m/'
    printf '\033[31m└────────────────────────────────────────────────────────────\033[0m\n'
fi

# A CONFIRMED FAILURE OUTRANKS AN UNDETERMINED.
[ "$ROTTED" -gt 0 ] && exit 1
[ "$BROKEN" -gt 0 ] && exit 2
if [ "$STRICT" -eq 1 ] && [ "$UNINSTRUMENTED" -gt 0 ]; then
    printf '\n--strict: %d uninstrumented prover(s) — could not determine, which is not a pass.\n' \
           "$UNINSTRUMENTED" >&2
    exit 2
fi
if [ "$RESOLVED" -eq 0 ] && [ "$NOANCHOR" -eq 0 ]; then
    printf 'UNDETERMINED: not one prover was actually interrogated.\n' >&2
    exit 2
fi
exit 0
