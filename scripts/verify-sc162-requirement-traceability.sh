#!/usr/bin/env bash
# ==============================================================================
# verify-sc162-requirement-traceability.sh — the mechanical cross-check unified
# SC-162 describes (specs/008-unified-workshop-platform/spec.md), added as a
# 2026-09-15-remediation-pass task with no source-spec origin (unified T582):
# the merge from specifications 001-007 into 008 is itself a piece of work
# that can be wrong, and this is the check that would catch it being wrong.
#
# WHAT IT ANSWERS — two residues, both targeting 0, reported BY ID
# -------------------------------------------------------------------
#   (a) every unified FR/SC requirement declared in spec.md carries either a
#       `*(was: ...)*` back-reference (merged from an earlier specification)
#       or a `*(new, ...)*` annotation (introduced fresh in the merge) —
#       i.e. no unified requirement's provenance is left unstated.
#   (b) every FR/SC id declared in specifications 001-007's own spec.md files
#       appears in at least one unified `*(was: ...)*` back-reference — i.e.
#       no source requirement was silently dropped by the merge.
#
# WHY THIS IS CHEAP BY CONSTRUCTION (its own task's own words): it is a grep
# and a set difference. It does not judge whether a MERGE was semantically
# correct, only whether every requirement on both sides is ACCOUNTED FOR —
# the same enumeration-not-judgement discipline every check-registry-*.tsv
# anti-drift sweep in this tree already applies to gates.
#
# DISCOVERY, NEVER HARDCODED
# ---------------------------
# The unified spec is discovered by glob (`specs/*unified*/spec.md`, the
# lexicographically LAST match — today there is exactly one), never a
# hardcoded path naming the number "008", so a future re-merge/renumbering is
# picked up without editing this file. The source specifications are
# discovered as `specs/00[1-7]-*/spec.md` — the numeric range specs/008's own
# unified SC-162 wording names ("specifications 001-007") — not a hardcoded
# directory-name list, so a future addition inside that numeric range needs
# no edit here either.
#
# WHAT COUNTS AS A BACK-REFERENCE
# ---------------------------------
# Every `NNN/FR-nnn` or `NNN/SC-nnn` token found inside a `*(was: ...)*`
# parenthetical anywhere in the unified spec — including a MERGED entry
# citing several source ids in one parenthetical
# (`*(was: 004/US1, 002/US1 — MERGED)*`). User-story (`US-n`) back-references
# are read for completeness of the parse but are NOT scored against — SC-162
# and this task's own wording are both about FR/SC ids specifically.
#
# EXIT CONTRACT — three values, never two
#   0  residue (a) is empty AND residue (b) is empty
#   1  at least one unified FR/SC lacks a was:/new: annotation, OR at least
#      one specs/001-007 FR/SC id has no unified back-reference — every
#      offending id is printed BY NAME, never only a count
#   2  COULD NOT DETERMINE: no unified spec.md discovered, no specs/001-007
#      spec.md discovered, or a discovered spec.md could not be read
#
# Usage:
#   verify-sc162-requirement-traceability.sh [--root DIR] [--quiet]
#   verify-sc162-requirement-traceability.sh --prove-failure   # this file's own §1.1
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

ROOT="$DEFAULT_ROOT"
QUIET=0
PROVE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --root)  shift; ROOT="${1:-}" ;;
        --quiet) QUIET=1 ;;
        --prove-failure) PROVE=1 ;;
        -h|--help) sed -n '2,55p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) printf 'verify-sc162-requirement-traceability.sh: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

command -v python3 >/dev/null 2>&1 || {
    printf 'UNDETERMINED: python3 is not on PATH — the check cannot run\n' >&2
    exit 2
}

run_check() {
    ROOT="$1" QUIET="$2" python3 - <<'PY'
import glob, os, re, sys

ROOT  = os.environ["ROOT"]
QUIET = os.environ["QUIET"] == "1"

def say(m):
    if not QUIET:
        print(m)

specs_dir = os.path.join(ROOT, "specs")
if not os.path.isdir(specs_dir):
    print("UNDETERMINED: no specs/ directory found under %s" % ROOT)
    sys.exit(2)

# ── discover the unified spec — glob, lexicographically last match ---------
unified_candidates = sorted(glob.glob(os.path.join(specs_dir, "*unified*", "spec.md")))
if not unified_candidates:
    print("UNDETERMINED: no specs/*unified*/spec.md discovered under %s" % specs_dir)
    sys.exit(2)
unified_path = unified_candidates[-1]

try:
    with open(unified_path, encoding="utf-8", errors="strict") as f:
        unified_text = f.read()
except OSError as e:
    print("UNDETERMINED: could not read unified spec %s: %s" % (unified_path, e))
    sys.exit(2)
except UnicodeDecodeError as e:
    print("UNDETERMINED: could not decode unified spec %s: %s" % (unified_path, e))
    sys.exit(2)

# ── discover source specifications 001-007 -----------------------------------
source_candidates = sorted(glob.glob(os.path.join(specs_dir, "00[1-7]-*", "spec.md")))
if not source_candidates:
    print("UNDETERMINED: no specs/00[1-7]-*/spec.md discovered under %s" % specs_dir)
    sys.exit(2)

REQ_LINE_RE = re.compile(
    r'^-\s+\*\*(?P<id>(?:FR|SC)-\d+[a-z]?)\*\*\s*(?P<annot>\*\([^)]*\)\*)?\s*:',
    re.MULTILINE,
)
WAS_RE   = re.compile(r'\*\(was:\s*([^)]*)\)\*')
NEW_RE   = re.compile(r'^\*\(new\b', re.IGNORECASE)
BACKREF_TOKEN_RE = re.compile(r'\b(\d{3})/(FR|SC)-(\d+[a-z]?)\b')

# ---- (a) every unified requirement carries was: or new: --------------------
missing_annotation = []
unified_id_count = 0
for m in REQ_LINE_RE.finditer(unified_text):
    unified_id_count += 1
    rid = m.group("id")
    annot = m.group("annot") or ""
    has_was = bool(WAS_RE.match(annot)) or ("*(was:" in annot)
    has_new = bool(NEW_RE.match(annot))
    if not (has_was or has_new):
        missing_annotation.append(rid)

if unified_id_count == 0:
    print("UNDETERMINED: 0 FR/SC requirement lines matched in unified spec %s — "
          "a check with nothing to check must never read as clean" % unified_path)
    sys.exit(2)

# ---- back-reference set: every NNN/FR-x or NNN/SC-x named inside a was: ----
backrefs = set()
for wm in WAS_RE.finditer(unified_text):
    body = wm.group(1)
    for tm in BACKREF_TOKEN_RE.finditer(body):
        specnum, kind, num = tm.group(1), tm.group(2), tm.group(3)
        backrefs.add((specnum, "%s-%s" % (kind, num)))

# ---- (b) every specs/001-007 FR/SC id appears in some back-reference -------
absent = []
source_id_count = 0
per_spec_counts = {}
for path in source_candidates:
    specnum = os.path.basename(os.path.dirname(path)).split("-", 1)[0]
    try:
        with open(path, encoding="utf-8", errors="strict") as f:
            text = f.read()
    except OSError as e:
        print("UNDETERMINED: could not read source spec %s: %s" % (path, e))
        sys.exit(2)
    except UnicodeDecodeError as e:
        print("UNDETERMINED: could not decode source spec %s: %s" % (path, e))
        sys.exit(2)
    n_here = 0
    for m in REQ_LINE_RE.finditer(text):
        rid = m.group("id")
        n_here += 1
        source_id_count += 1
        if (specnum, rid) not in backrefs:
            absent.append("%s/%s" % (specnum, rid))
    per_spec_counts[specnum] = n_here

if source_id_count == 0:
    print("UNDETERMINED: 0 FR/SC requirement lines matched across %d discovered "
          "specs/001-007 spec.md file(s) — a check with nothing to check must "
          "never read as clean" % len(source_candidates))
    sys.exit(2)

say("SC-162 traceability: unified spec %s carries %d FR/SC requirement(s); "
    "%d source spec.md file(s) under specs/001-007 carry %d FR/SC requirement(s) "
    "(%s); %d distinct back-reference(s) parsed from unified was: annotations"
    % (unified_path.replace(ROOT + os.sep, ""), unified_id_count,
       len(source_candidates), source_id_count,
       ", ".join("%s=%d" % (k, v) for k, v in sorted(per_spec_counts.items())),
       len(backrefs)))

ok = True
if missing_annotation:
    ok = False
    for rid in missing_annotation:
        print("MISSING-ANNOTATION  unified %s carries neither a was: back-reference "
              "nor a new: annotation" % rid)
if absent:
    ok = False
    for aid in absent:
        print("ABSENT  specs/%s has no unified was: back-reference to it" % aid)

if not ok:
    print("FAIL — %d unified requirement(s) without provenance, %d source "
          "requirement(s) with no unified back-reference"
          % (len(missing_annotation), len(absent)))
    sys.exit(1)

say("PASS — every unified FR/SC carries a was:/new: annotation (0 of %d missing); "
    "every specs/001-007 FR/SC has a unified back-reference (0 of %d absent)"
    % (unified_id_count, source_id_count))
sys.exit(0)
PY
}

if [ "$PROVE" = "1" ]; then
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT INT TERM
    FAIL=0
    M=0
    P=0

    expect() {
        local label="$1" rc="$2" want="$3"
        M=$((M+1))
        if [ "$rc" = "$want" ]; then
            P=$((P+1))
            printf 'PROVE PASS  %s (rc=%s)\n' "$label" "$rc"
        else
            FAIL=1
            printf 'PROVE FAIL  %s (rc=%s, want=%s)\n' "$label" "$rc" "$want"
        fi
    }

    build_fixture() {
        rm -rf "$TMP/fx"
        mkdir -p "$TMP/fx/specs/009-unified-demo" "$TMP/fx/specs/001-demo-alpha" "$TMP/fx/specs/002-demo-beta"
        cat > "$TMP/fx/specs/001-demo-alpha/spec.md" <<'MD'
# Demo Alpha
- **FR-001**: alpha requirement one.
- **SC-001**: alpha success criterion one.
MD
        cat > "$TMP/fx/specs/002-demo-beta/spec.md" <<'MD'
# Demo Beta
- **FR-001**: beta requirement one.
MD
        cat > "$TMP/fx/specs/009-unified-demo/spec.md" <<'MD'
# Unified Demo
- **FR-101** *(was: 001/FR-001)*: alpha requirement one, merged.
- **SC-101** *(was: 001/SC-001)*: alpha success criterion one, merged.
- **FR-102** *(was: 002/FR-001)*: beta requirement one, merged.
- **FR-103** *(new, derived from remediation)*: a fresh unified-only requirement.
MD
    }

    # M1 — control: fully traceable fixture is clean
    build_fixture
    run_check "$TMP/fx" 1 >/tmp/sc162_m1.$$ 2>&1
    expect "M1 control: fully-traceable fixture is clean" "$?" 0

    # M2 — strip one back-reference (FR-102's was:) from a THROWAWAY COPY —
    # the check must go red NAMING that specific id, both directions
    build_fixture
    python3 - "$TMP/fx/specs/009-unified-demo/spec.md" <<'PY'
import sys
p = sys.argv[1]
with open(p) as f:
    text = f.read()
text = text.replace(
    '- **FR-102** *(was: 002/FR-001)*: beta requirement one, merged.\n',
    '- **FR-102**: beta requirement one, merged (annotation stripped).\n',
)
with open(p, "w") as f:
    f.write(text)
PY
    OUT="$(run_check "$TMP/fx" 1 2>&1)"
    RC=$?
    expect "M2 stripped back-reference -> rc 1" "$RC" 1
    case "$OUT" in
        *"MISSING-ANNOTATION  unified FR-102"*) ;;
        *) FAIL=1; printf 'PROVE FAIL  M2a did not name unified FR-102 as MISSING-ANNOTATION\n%s\n' "$OUT" ;;
    esac
    case "$OUT" in
        *"ABSENT  specs/002/FR-001"*) ;;
        *) FAIL=1; printf 'PROVE FAIL  M2b did not name specs/002/FR-001 as ABSENT\n%s\n' "$OUT" ;;
    esac
    M=$((M+2)); P=$((P+2))
    [ "$FAIL" = "1" ] || printf 'PROVE PASS  M2a/M2b flagged rows NAME the specific stripped id, both directions\n'

    # M3 — a source id given a `new`-style annotation instead of a real was:
    # reference is still ABSENT from the back-reference set (annotation
    # presence alone does not satisfy part (b))
    build_fixture
    python3 - "$TMP/fx/specs/009-unified-demo/spec.md" <<'PY'
import sys
p = sys.argv[1]
with open(p) as f:
    text = f.read()
text = text.replace(
    '- **FR-102** *(was: 002/FR-001)*: beta requirement one, merged.\n',
    '- **FR-102** *(new, restated rather than cited)*: beta requirement one.\n',
)
with open(p, "w") as f:
    f.write(text)
PY
    OUT="$(run_check "$TMP/fx" 1 2>&1)"
    RC=$?
    expect "M3 real source id with no was: reference -> rc 1" "$RC" 1
    case "$OUT" in
        *"ABSENT  specs/002/FR-001"*) P=$((P+1)); printf 'PROVE PASS  M3b flagged specs/002/FR-001 as ABSENT despite a new: elsewhere\n' ;;
        *) FAIL=1; printf 'PROVE FAIL  M3b did not name specs/002/FR-001 as ABSENT\n%s\n' "$OUT" ;;
    esac
    M=$((M+1))

    # M4 — no unified spec discovered -> rc 2
    rm -rf "$TMP/fx2"
    mkdir -p "$TMP/fx2/specs/001-demo-alpha"
    cat > "$TMP/fx2/specs/001-demo-alpha/spec.md" <<'MD'
- **FR-001**: alpha.
MD
    run_check "$TMP/fx2" 1 >/tmp/sc162_m4.$$ 2>&1
    expect "M4 no unified spec.md discovered -> rc 2 UNDETERMINED" "$?" 2

    # M5 — no specs/001-007 discovered -> rc 2
    rm -rf "$TMP/fx3"
    mkdir -p "$TMP/fx3/specs/009-unified-demo"
    cat > "$TMP/fx3/specs/009-unified-demo/spec.md" <<'MD'
- **FR-101** *(new, nothing to merge)*: solo.
MD
    run_check "$TMP/fx3" 1 >/tmp/sc162_m5.$$ 2>&1
    expect "M5 no specs/001-007 discovered -> rc 2 UNDETERMINED" "$?" 2

    # M6 — a specs/00N spec.md that exists but is unreadable (permission) -> rc 2
    build_fixture
    chmod 000 "$TMP/fx/specs/002-demo-beta/spec.md"
    if [ "$(id -u)" != "0" ]; then
        run_check "$TMP/fx" 1 >/tmp/sc162_m6.$$ 2>&1
        expect "M6 unreadable source spec.md -> rc 2 UNDETERMINED" "$?" 2
    else
        printf 'PROVE SKIP  M6 running as root — permission bits do not deny root; not counted\n'
    fi
    chmod 644 "$TMP/fx/specs/002-demo-beta/spec.md" 2>/dev/null || true

    rm -f /tmp/sc162_m*.$$
    echo "----------------------------------------------------------------------"
    echo "PROVE: $P/$M mutation(s) passed"
    if [ "$FAIL" = "1" ]; then
        echo "PROVE: RESULT — at least one mutation FAILED; this check does NOT"
        echo "        reliably distinguish traceable requirements from untraceable ones."
        exit 1
    fi
    echo "PROVE: RESULT — all mutations behaved as required."
    exit 0
fi

run_check "$ROOT" "$QUIET"
exit $?
