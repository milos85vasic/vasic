#!/usr/bin/env bash
# verify-claim-ledger.sh — §11.4.266. Every recorded claim is re-measured
# against the thing it describes, on every run, from scratch.
#
# ── THE DEFECT CLASS, MEASURED BEFORE IT WAS GENERALISED ─────────────────────
#
# Nine instances on 2026-09-07/08/09, in one week, in this tree:
#
#   1. `submodules/containers` shipped the ephemeral-run primitive on
#      2026-09-04, TWO COMMITS BEFORE the pin this tree already consumed. Nine
#      tracked files went on asserting the gap for five days.
#   2. Three "actionable FAILs" were recorded as work to do. All three already
#      existed and were tracked.
#   3. Two of those gates were PASSING OVER A STALE LEDGER — it recorded 26
#      findings while the live sweep measured 35, and both the ratchet gate and
#      the README badge read the LEDGER rather than the live sweep. The README
#      showed a friendlier picture than the tree.
#   4. A CLI flag recorded as unrecognised had already landed in `5642dd6`.
#   5. A database table recorded as holding 0 rows had already materialised.
#   6. "34 runs no setting readable today explains" — it is 43, and they are
#      explained.
#   7. "the sweep keeps no expected-gate ledger" — the ledger exists.
#   8. A note claimed 66 rows against a 49-row artefact, and its gate exited 0
#      because nothing read the prose.
#   9. A stop-rule asserted a PROXY that fires on the safe case.
#
# EVERY GATE IN THIS TREE VERIFIES ITS SUBJECT. NOT ONE VERIFIED WHAT THE
# REPOSITORY SAYS ABOUT ITS SUBJECT. A gitlink moves, every gate stays green,
# and the documents keep asserting a gap that closed days ago. §11.4.266 keys
# the enumeration from the CLAIM side; this gate is that keying, made
# mechanical.
#
# ── WHAT IT ASSERTS ──────────────────────────────────────────────────────────
#
#   L1  THE CLAIM IS STILL MADE. Every ledger row's anchor must still match in
#       its surface. A row whose anchor matches nothing is an ORPHAN: the
#       ledger describes a claim the repository no longer advertises, so the
#       row has silently stopped protecting anything. §11.4.266(A) requires
#       claim and row to resolve to each other; an orphan is a FINDING, not a
#       tidy-up.
#
#   L2  THE CLAIM AGREES WITH REALITY, AND REALITY IS RE-MEASURED HERE.
#       For a `prose` row the CLAIMED value is read out of the document by the
#       anchor's capture group and the REAL value is produced by running the
#       probe FRESH. Nothing is cached. There is no figure in the ledger that
#       can go stale, and no way to make such a row green by editing the
#       ledger.
#
#       THIS IS THE PART THAT KEEPS THE GATE FROM BECOMING INSTANCE TEN. A
#       gate that read a recorded figure and compared it to another recorded
#       figure would be defect 3 above, wearing a gate's name.
#
#   L3  EVERY OCCURRENCE, NOT THE FIRST. A claim shape occurring N times must
#       satisfy the comparison N times. A dead figure written in a live
#       figure's clothes is a finding — this repository deliberately records
#       superseded numbers in prose, so an anchor must be specific enough to
#       match only the live assertion, and a too-loose anchor surfaces as a
#       FALSE rather than as silence.
#
#   L4  THE ROW IS TYPED FROM THE CLOSED VOCABULARY. §11.4.266(B) fixes SEVEN
#       bluff types. An invented type is a FAIL. The type is a ROUTING KEY to
#       the anchor that owns its counter-gate (§11.4.266(C)), so an untypeable
#       finding must be an honest tracked GAP, never a new type.
#
#   L5  A CLAIM THAT CANNOT BE RE-MEASURED IS NOT VERIFIED. A probe that will
#       not run, a surface that is absent, a missing interpreter — every one of
#       those is UNDETERMINED. §11.4.266(D) makes an unchallenged capability
#       block exactly as a failing one does, so a 2 here is never a pass and
#       must never be recorded as one.
#
# ── WHAT IT DOES NOT ASSERT — READ THIS BEFORE QUOTING A GREEN EXIT ──────────
#
#   * COMPLETENESS. §11.4.266(A) requires EVERY advertised capability on every
#     declared surface to resolve to exactly one row.
#     `CM-CLAIM-REALITY-LEDGER-COMPLETE` IS NOT SATISFIED BY THIS GATE. The
#     ledger is a bounded slice and says so. `--completeness` counts the
#     unregistered countable-claim shapes on the declared surfaces and reports
#     them as waves an operator can approve. It is a NOTE, not a verdict input,
#     because a heuristic claim-shape scanner cannot decide what is a claim.
#
#   * ORACLE STRENGTH. A row proves the claim agrees with what its probe
#     measured. It does not prove the probe measures the right thing. That
#     stays §11.4.245 and §1.1.
#
#   * `assert` ROWS CARRY A RESIDUAL HOLE AND IT IS NAMED. An `assert` row
#     stores an expected value because its claim states no number. Someone
#     could make such a row green by editing `expected` while the prose still
#     asserts the old proposition. `prose` rows have no such hole because they
#     store nothing. Prefer `prose`.
#
# ── THREE-VALUED, AND 2 IS NEVER A PASS ──────────────────────────────────────
#
#   0  every row's claim is still made and still agrees with a fresh
#      measurement
#   1  a real finding — a claim is FALSE, a row is an ORPHAN, a row carries an
#      invented bluff type, or a row is malformed
#   2  COULD NOT DETERMINE — no python3, no ledger, a ledger with zero claim
#      rows (VACUITY: a gate that reports 0 over nothing has certified
#      nothing), an absent surface, or a probe that would not run
#
#   PRECEDENCE, ASSERTED BY A MUTATION AND NOT MERELY DECLARED: 1 OUTRANKS 2.
#   A tree that is partly unmeasurable must not be able to mask a claim that is
#   measurably false.
#
# ── CONCURRENCY — THIS TREE MOVES WHILE THE GATE READS IT ────────────────────
#
# Nine agents work in this checkout. The gate fingerprints the exact files it
# reads before and after the run and NAMES any that changed — paths only, never
# content. A moving corpus is reported so a reading is not mistaken for a
# stable one. It does not suppress a finding, for the reason above.
#
# ── USAGE ────────────────────────────────────────────────────────────────────
#
#   bash scripts/verify-claim-ledger.sh                  # the gate
#   bash scripts/verify-claim-ledger.sh --verbose        # one line per row
#   bash scripts/verify-claim-ledger.sh --completeness    # the remaining waves
#   bash scripts/verify-claim-ledger.sh --prove-failure  # §1.1 paired mutations
#   bash scripts/verify-claim-ledger.sh --root /nonexistent   # drives rc 2
#
# PRIVACY — BINDING. This repository is PUBLIC and three of its submodules are
# not. This gate prints IDENTIFIERS, PATHS, COUNTS and MEASURED VALUES from the
# declared surfaces only, all of which are already public files at this root. It
# never reads a private submodule and never prints matched document prose beyond
# the captured value a public carrier already states.

set -u

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
ROOT="$(cd -- "$(dirname -- "$SELF")/.." && pwd -P)"
LEDGER_REL="docs/claim-ledger.tsv"
VERBOSE=0
COMPLETENESS=0
PROVE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --root)          ROOT="${2:-}"; shift 2 ;;
        --ledger)        LEDGER_REL="${2:-}"; shift 2 ;;
        --verbose)       VERBOSE=1; shift ;;
        --completeness)  COMPLETENESS=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help)       sed -n '1,140p' "$SELF"; exit 0 ;;
        *) printf 'UNDETERMINED: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

# The closed seven-member bluff-type vocabulary of §11.4.266(B), verbatim.
# EXTENSIBLE ONLY BY AN EXPLICIT, VISIBLE AMENDMENT. An un-typeable finding is
# an honest tracked GAP (§11.4.6 / §11.4.197), never an invented type.
BLUFF_TYPES="green-but-broken coverage-theater rubber-stamp-verified stubbed-core doc-vs-code-drift config-present-but-unwired byte-identical-fork"

# ---------------------------------------------------------------------------
# --prove-failure — the §1.1 paired mutation battery.
#
# EVERY ARM IS A DATA EDIT INSIDE A THROWAWAY LAB. Nothing here edits this
# gate, and nothing here runs against the live tree — a battery that mutated
# the gate would prove the gate can be broken, which nobody doubts.
#
# AN ARM THAT DOES NOT MUTATE IS AN INOPERATIVE PROOF, AND THIS HARNESS
# REFUSES IT. Adopted from the lesson recorded in
# `workshop/platform/gates/prove-plan-coverage-proposal.sh`: three of its arms
# silently became no-ops when the figures they named literally moved, and only
# surfaced because they wanted rc 1. An arm wanting rc 0 that mutates nothing
# would pass for ever while testing nothing. So every arm declares
# `expect_change`, and an arm whose body leaves the lab byte-identical FAILS
# with a message saying so.
# ---------------------------------------------------------------------------
if [ "$PROVE" -eq 1 ]; then
    printf '== prove-failure: this gate must be seen distinguishing a TRUE claim\n'
    printf '   from a FALSE one, in BOTH directions, and refusing to guess ==\n\n'

    command -v python3 >/dev/null 2>&1 || { printf 'UNDETERMINED: no python3, so the battery cannot build its fixtures\n' >&2; exit 2; }
    command -v sha256sum >/dev/null 2>&1 || { printf 'UNDETERMINED: no sha256sum, so an inoperative arm cannot be PROVED\n' >&2; printf 'inoperative and will not be claimed operative.\n' >&2; exit 2; }

    LAB="$(mktemp -d)" || { printf 'UNDETERMINED: cannot create a lab directory\n' >&2; exit 2; }
    trap 'rm -rf "$LAB"' EXIT

    build_base() {
        rm -rf "${LAB:?}/w"; mkdir -p "$LAB/w/docs" "$LAB/w/data"
        cat > "$LAB/w/surf.md" <<'SURF'
# Lab surface

The tree declares **3** widgets (measured today).

The runtime keeps **no expected-gate ledger**.
SURF
        printf 'alpha\nbeta\ngamma\n' > "$LAB/w/data/widgets.txt"
        printf 'surface\tsurf.md\n' > "$LAB/w/docs/l.tsv"
        printf 'claim\tlab-widget-count\tsurf.md\tprose\tdoc-vs-code-drift\tminor\teq\t-\tdeclares \\*\\*(\\d+)\\*\\* widgets\twc -l < data/widgets.txt\n' >> "$LAB/w/docs/l.tsv"
        printf 'claim\tlab-ledger-absent\tsurf.md\tassert\tdoc-vs-code-drift\tmajor\teq\tabsent\tkeeps \\*\\*no expected-gate ledger\\*\\*\ttest -f data/gate-ledger.tsv && echo present || echo absent\n' >> "$LAB/w/docs/l.tsv"
    }

    lab_sum() { find "$LAB/w" -type f -print0 | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1; }

    passed=0; failed=0
    # arm <label> <wanted-rc> <expect_change 0|1> <shell body applied to $LAB/w>
    arm() {
        local label="$1" want="$2" expect_change="$3" body="$4"
        build_base
        local before after rc
        before="$(lab_sum)"
        # `bash -c` rather than `eval`: same semantics for a literal body
        # written in this file, one fewer §11.4.261 danger-zone row, and the
        # arm cannot touch this shell's state even by accident.
        ( cd "$LAB/w" && bash -c "$body" ) >/dev/null 2>&1
        after="$(lab_sum)"
        if [ "$expect_change" = "1" ] && [ "$before" = "$after" ]; then
            printf 'FAIL %s\n     the arm body left the lab BYTE-IDENTICAL, so this arm would test\n     nothing. An inoperative mutation is not a passing one.\n' "$label"
            failed=$((failed+1)); return
        fi
        if [ "$expect_change" = "0" ] && [ "$before" != "$after" ]; then
            printf 'FAIL %s\n     a CONTROL arm changed the lab; it is not the control it claims to be.\n' "$label"
            failed=$((failed+1)); return
        fi
        bash "$SELF" --root "$LAB/w" --ledger docs/l.tsv >"$LAB/out" 2>&1; rc=$?
        if [ "$rc" = "$want" ]; then
            printf 'PASS %s  (rc %s)\n' "$label" "$rc"; passed=$((passed+1))
        else
            printf 'FAIL %s  (wanted rc %s, got %s)\n' "$label" "$want" "$rc"
            sed 's/^/       | /' "$LAB/out" | head -12
            failed=$((failed+1))
        fi
    }

    # -- THE CONTROLS COME FIRST AND THEY ARE NOT OPTIONAL. A battery of
    #    red-only arms is satisfied by a gate hardwired to fail. C0 is the
    #    §11.4.201(1) golden-FALSE fixture: a fully-populated ledger whose every
    #    row is TRUE must fire NOTHING.
    arm "C0  CONTROL — a fully TRUE ledger over a matching tree fires nothing" 0 0 "true"

    arm "C1  CONTROL — a SUPERSEDED figure recorded in prose, outside the anchor, stays green" 0 1 \
        "printf '\nAn earlier revision of this page said **9** widgets; that reading is withdrawn.\n' >> surf.md"

    # -- DIRECTION A: the CLAIM is falsified while reality stays put.
    arm "M1  the DOCUMENT'S asserted figure is falsified — claim != reality" 1 1 \
        "python3 -c \"import re,io;p='surf.md';t=open(p).read();t=re.sub(r'declares \\*\\*(\\d+)\\*\\* widgets',lambda m:'declares **%d** widgets'%(int(m.group(1))+4),t,count=1);open(p,'w').write(t)\""

    # -- DIRECTION B: THE ACTUAL DEFECT CLASS. Reality moves; the claim does
    #    not. Nine of the nine measured instances have THIS shape, and a gate
    #    that caught only direction A would have caught none of them.
    arm "M2  REALITY MOVES while the claim stays put — THE measured defect class" 1 1 \
        "printf 'delta\nepsilon\n' >> data/widgets.txt"

    arm "M3  ORPHAN — the claim is deleted from the document, the row survives" 1 1 \
        "python3 -c \"import re;p='surf.md';t=open(p).read();t=re.sub(r'^The tree declares.*\$','',t,flags=re.M);open(p,'w').write(t)\""

    # -- L3: a SECOND occurrence carrying a dead figure. Checking only the
    #    first match would report green over a document that states two
    #    different answers to the same question.
    arm "M4  a SECOND occurrence of the claim shape carries a DEAD figure" 1 1 \
        "printf '\nThe tree declares **99** widgets (an old reading nobody withdrew).\n' >> surf.md"

    # -- L4: the closed vocabulary of §11.4.266(B).
    arm "M5  an INVENTED bluff type outside the seven-member closed set" 1 1 \
        "sed -i 's/doc-vs-code-drift/made-up-type/' docs/l.tsv"

    arm "M6  a MALFORMED row — fewer fields than the format requires" 1 1 \
        "sed -i '2s/\t[^\t]*\$//' docs/l.tsv"

    # -- an `assert` row whose REALITY moved: the qualitative half of M2.
    arm "M7  an ASSERT row's reality moves — the thing it denies now exists" 1 1 \
        "touch data/gate-ledger.tsv"

    # -- L5 / rc 2: unable to verify is not a pass.
    arm "U1  a probe that WILL NOT RUN is UNDETERMINED, never verified" 2 1 \
        "sed -i 's|wc -l < data/widgets.txt|definitely-not-a-real-binary-xyzzy|' docs/l.tsv"

    arm "U2  an ABSENT SURFACE is UNDETERMINED — nothing was measured" 2 1 "rm -f surf.md"

    arm "U3  VACUITY — a ledger with zero claim rows certifies nothing" 2 1 \
        "printf '# only comments\n' > docs/l.tsv"

    # -- PRECEDENCE, ASSERTED RATHER THAN DECLARED. A tree carrying BOTH an
    #    unmeasurable row AND a measurably false one must exit 1. If 2 won,
    #    one broken probe anywhere would mask every false claim in the file.
    arm "P1  PRECEDENCE — a FALSE claim outranks an UNDETERMINED one (1, not 2)" 1 1 \
        "printf 'delta\n' >> data/widgets.txt; sed -i 's|test -f data/gate-ledger.tsv \&\& echo present |absolutely-not-a-binary-qqq |' docs/l.tsv"

    printf '\n== %d passed / %d failed / 13 arms ==\n' "$passed" "$failed"
    [ "$failed" -eq 0 ] || exit 1
    exit 0
fi

# ---------------------------------------------------------------------------
# preconditions
# ---------------------------------------------------------------------------
[ -d "$ROOT" ] || { printf 'UNDETERMINED: --root %s is not a directory\n' "$ROOT" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'UNDETERMINED: no python3 on PATH, so no anchor can be matched\n' >&2; exit 2; }

LEDGER="$ROOT/$LEDGER_REL"
[ -f "$LEDGER" ] || { printf 'UNDETERMINED: ledger %s does not exist\n' "$LEDGER_REL" >&2; exit 2; }
[ -r "$LEDGER" ] || { printf 'UNDETERMINED: ledger %s is not readable\n' "$LEDGER_REL" >&2; exit 2; }

cd "$ROOT" || { printf 'UNDETERMINED: cannot enter %s\n' "$ROOT" >&2; exit 2; }

# ---------------------------------------------------------------------------
# the file set this run reads — fingerprinted BEFORE and AFTER, so a moving
# corpus is reported rather than absorbed.
# ---------------------------------------------------------------------------
readset() {
    { printf '%s\n' "$LEDGER_REL"
      awk -F'\t' '$1=="surface"{print $2} $1=="claim"{print $3}' "$LEDGER" 2>/dev/null
    } | sort -u
}
fingerprint() {
    readset | while IFS= read -r f; do
        if [ -f "$f" ]; then printf '%s  %s\n' "$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)" "$f"
        else printf 'ABSENT  %s\n' "$f"; fi
    done
}
FP_BEFORE="$(fingerprint)"

# ---------------------------------------------------------------------------
# completeness scan — a NOTE, never a verdict input
# ---------------------------------------------------------------------------
if [ "$COMPLETENESS" -eq 1 ]; then
    python3 - "$LEDGER" <<'PY'
import re, sys, os
ledger = sys.argv[1]
surfaces, anchors = [], []
for line in open(ledger, encoding='utf-8'):
    if line.startswith('#') or not line.strip():
        continue
    f = line.rstrip('\n').split('\t')
    if f[0] == 'surface' and len(f) >= 2:
        surfaces.append(f[1])
    elif f[0] == 'claim' and len(f) >= 10:
        anchors.append((f[2], f[8]))

# A COUNTABLE CLAIM SHAPE, defined narrowly and stated rather than implied:
# a bolded or backticked integer of two or more digits, or a bolded integer of
# any length, sitting in prose. This is a HEURISTIC. It over-counts (a date, a
# section number) and under-counts (a claim stated in words). It is reported as
# a wave to be READ, never as a finding.
FIGURE = re.compile(r'\*\*[\d,]{1,12}\*\*|`[\d,]{2,12}`')
BADGE  = re.compile(r'!\[[^\]]+\]\(https://img\.shields\.io/badge/[^)]*\)')
print("COMPLETENESS — §11.4.266(A) requires EVERY advertised capability to")
print("resolve to exactly one row. THIS LEDGER IS A BOUNDED SLICE AND DOES NOT")
print("SATISFY THAT. The waves below are countable claim SHAPES, found by a")
print("heuristic that over- and under-counts; they are a reading assignment for")
print("an operator to approve, not a defect list.\n")
print("  TWO SHAPES ARE COUNTED, AND NEITHER IS 'a claim'. `figure` is a bolded")
print("  or backticked integer sitting in prose. `badge` is a shields.io badge,")
print("  the surface §11.4.266(A) names explicitly; ONE badge asserts SEVERAL")
print("  things (a subject, a value and a colour), so a badge count UNDER-states")
print("  its own claim count. Neither number is a defect count.\n")
total_reg = len(anchors)
grand_f = grand_b = 0
for s in sorted(set(surfaces)):
    if not os.path.exists(s):
        print("  %-12s ABSENT — not scanned" % s)
        continue
    t = open(s, encoding='utf-8', errors='replace').read()
    nf, nb = len(FIGURE.findall(t)), len(BADGE.findall(t))
    reg = sum(1 for (sf, _) in anchors if sf == s)
    grand_f += nf; grand_b += nb
    print("  %-12s %5d figure(s)  %3d badge(s)   %2d registered" % (s, nf, nb, reg))
print("\n  TOTAL       %5d figure(s)  %3d badge(s)" % (grand_f, grand_b))
print("              %5d registered ledger row(s)" % total_reg)
print("""
  A `0 registered` ROW IS NOT NECESSARILY A GAP. `AGENTS.md`, `QWEN.md` and
  `GEMINI.md` are byte-identical to `CLAUDE.md` from the measured convergence
  line down and cascade check C5 enforces it, so a shared-region claim is
  registered ONCE against `CLAUDE.md` and its three mirrors are covered by
  byte-identity, not by a row here. Their figure counts are therefore MIRRORS
  of CLAUDE.md's, not additional work — the honest remaining figure for the
  carriers is CLAUDE.md's alone, and the three mirror rows should be read as
  zero additional reading.""")
print("""
  WAVES AN OPERATOR CAN APPROVE, in the order that buys the most per row read:

    wave 1  README.md badge row + capability table  — the §11.4.259 badge
            assertions and the "What is in here" table are what a NEW READER
            acts on first, and the badge row is the surface §11.4.266(A) names
            explicitly. Bounded and small.
    wave 2  the carriers' MEASURED-FIGURE code blocks — every `# <n>` comment
            in a re-derive block is a claim with its own probe already written
            beside it. The cheapest rows in the tree to register, because the
            probe is the line above the number.
    wave 3  the carriers' gate-verdict paragraphs — every "exits N at X PASS /
            Y FAIL" reading. Highest value and highest cost: each needs its
            gate run, and several take minutes.
    wave 4  the remainder — dated narrative measurements. Many are DELIBERATELY
            historical (this repository records superseded figures by name), so
            this wave needs a human to separate a live assertion from a
            withdrawn one before any row can be written.""")
PY
    exit 0
fi

# ---------------------------------------------------------------------------
# the gate
# ---------------------------------------------------------------------------
VERIFIED=0; FALSE=0; ORPHAN=0; UNDET=0; MALFORMED=0; ROWS=0
FINDINGS=""
note() { FINDINGS="${FINDINGS}$1
"; }

while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    kind0="${line%%	*}"
    [ "$kind0" = "claim" ] || continue
    ROWS=$((ROWS+1))

    # 10 tab-separated fields; anything else is malformed and is a FINDING,
    # because a row nobody can parse is a claim nobody is checking.
    nf="$(printf '%s' "$line" | awk -F'\t' '{print NF}')"
    if [ "$nf" != "10" ]; then
        id="$(printf '%s' "$line" | cut -f2)"
        note "FALSE   [malformed] row '${id:-<unnamed>}' has $nf field(s), not 10 — a row that cannot be parsed is a claim that is not being checked"
        MALFORMED=$((MALFORMED+1)); continue
    fi

    id="$(printf '%s' "$line" | cut -f2)"
    surface="$(printf '%s' "$line" | cut -f3)"
    ckind="$(printf '%s' "$line" | cut -f4)"
    btype="$(printf '%s' "$line" | cut -f5)"
    sev="$(printf '%s' "$line" | cut -f6)"
    op="$(printf '%s' "$line" | cut -f7)"
    expected="$(printf '%s' "$line" | cut -f8)"
    anchor="$(printf '%s' "$line" | cut -f9)"
    probe="$(printf '%s' "$line" | cut -f10)"

    # L4 — the closed vocabulary. Checked BEFORE any measurement, because an
    # untyped row cannot be routed to a counter-gate even if its claim is true.
    typed=0
    for t in $BLUFF_TYPES; do [ "$t" = "$btype" ] && typed=1; done
    if [ "$typed" -eq 0 ]; then
        note "FALSE   [untyped]  $id carries bluff type '$btype', which is not one of the seven in §11.4.266(B). An un-typeable finding is an honest tracked GAP, never an invented type."
        MALFORMED=$((MALFORMED+1)); continue
    fi
    case "$ckind" in prose|assert) : ;; *)
        note "FALSE   [malformed] $id has kind '$ckind'; only 'prose' and 'assert' exist"
        MALFORMED=$((MALFORMED+1)); continue ;;
    esac

    # L5 — an absent surface is UNDETERMINED. It is not a pass and it is not a
    # finding: a claim on a file that is not here was not measured.
    if [ ! -f "$surface" ]; then
        note "UNDET   [surface]  $id — surface '$surface' does not exist, so the claim was NOT measured"
        UNDET=$((UNDET+1)); continue
    fi

    # L1/L3 — extract EVERY occurrence's claimed value.
    claimed="$(python3 - "$surface" "$anchor" "$ckind" <<'PY'
import re, sys
path, pat, kind = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    t = open(path, encoding='utf-8', errors='replace').read()
except OSError as e:
    print("__ERR__ cannot read: %s" % e); raise SystemExit(0)
try:
    rx = re.compile(pat, re.M)
except re.error as e:
    print("__ERR__ anchor is not a valid pattern: %s" % e); raise SystemExit(0)
if kind == 'prose' and rx.groups != 1:
    print("__ERR__ a prose anchor must carry EXACTLY ONE capture group; this one has %d" % rx.groups)
    raise SystemExit(0)
if kind == 'assert' and rx.groups != 0:
    print("__ERR__ an assert anchor must carry NO capture group; this one has %d" % rx.groups)
    raise SystemExit(0)
ms = list(rx.finditer(t))
if not ms:
    print("__NONE__"); raise SystemExit(0)
for m in ms:
    print(m.group(1) if kind == 'prose' else '__PRESENT__')
PY
)"
    case "$claimed" in
        __ERR__*)
            note "UNDET   [anchor]   $id — ${claimed#__ERR__ }"
            UNDET=$((UNDET+1)); continue ;;
        __NONE__)
            note "FALSE   [orphan]   $id — the anchor matches NOTHING in $surface. The ledger describes a claim this repository no longer advertises, so the row has silently stopped protecting anything (§11.4.266(A))."
            ORPHAN=$((ORPHAN+1)); continue ;;
    esac

    # reality, re-measured FRESH. Nothing here reads a recorded figure.
    real="$(bash -c "$probe" 2>/dev/null)"; prc=$?
    real="$(printf '%s' "$real" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ "$prc" -ne 0 ]; then
        note "UNDET   [probe]    $id — the re-measurement command exited $prc, so REALITY IS UNKNOWN here. §11.4.266(D): an unchallenged claim blocks exactly as a failing one does."
        UNDET=$((UNDET+1)); continue
    fi
    if [ -z "$real" ]; then
        note "UNDET   [probe]    $id — the re-measurement command produced NO output, so there is nothing to compare the claim against"
        UNDET=$((UNDET+1)); continue
    fi

    # L2/L3 — compare EVERY occurrence.
    occ=0; bad=0
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        occ=$((occ+1))
        lhs="$c"
        [ "$ckind" = "assert" ] && lhs="$expected"
        lhs="$(printf '%s' "$lhs" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[,_]//g')"
        rhs="$(printf '%s' "$real"  | sed -e 's/[,_]//g')"
        ok=0
        case "$op" in
            eq)      [ "$lhs" = "$rhs" ] && ok=1 ;;
            ne)      [ "$lhs" != "$rhs" ] && ok=1 ;;
            matches) printf '%s' "$rhs" | grep -Eq -- "$lhs" && ok=1 ;;
            *)       note "FALSE   [malformed] $id has operator '$op'; only eq, ne and matches exist"
                     MALFORMED=$((MALFORMED+1)); bad=2; break ;;
        esac
        if [ "$ok" -eq 0 ]; then
            note "FALSE   [$sev/$btype] $id — occurrence $occ of the claim in $surface says '$lhs'; a fresh measurement says '$rhs'.
                  probe: $probe"
            bad=1
        fi
    done <<EOF
$claimed
EOF
    [ "$bad" = "2" ] && continue
    if [ "$bad" = "1" ]; then
        FALSE=$((FALSE+1))
    else
        VERIFIED=$((VERIFIED+1))
        [ "$VERBOSE" -eq 1 ] && printf 'VERIFIED %-42s %s occurrence(s) == %s\n' "$id" "$occ" "$real"
    fi
done < "$LEDGER"

FP_AFTER="$(fingerprint)"

printf '\n== claim-vs-reality ledger — §11.4.266 ==\n'
printf '   ledger:  %s\n' "$LEDGER_REL"
printf '   rows:    %d claim row(s) over %d declared surface(s)\n' "$ROWS" \
    "$(awk -F'\t' '$1=="surface"' "$LEDGER" | wc -l | tr -d ' ')"
printf '   verdict: %d VERIFIED · %d FALSE · %d ORPHAN · %d MALFORMED/UNTYPED · %d UNDETERMINED\n\n' \
    "$VERIFIED" "$FALSE" "$ORPHAN" "$MALFORMED" "$UNDET"

[ -n "$FINDINGS" ] && printf '%s\n' "$FINDINGS"

if [ "$FP_BEFORE" != "$FP_AFTER" ]; then
    printf 'NOTE — the corpus MOVED while this gate read it. Paths that changed:\n'
    diff <(printf '%s\n' "$FP_BEFORE") <(printf '%s\n' "$FP_AFTER") 2>/dev/null \
        | sed -nE 's/^[<>] [^ ]+  (.*)$/       \1/p' | sort -u
    printf '       The counts above are a reading of a tree that was measurably\n'
    printf '       moving. A finding is still a finding — a moving corpus does not\n'
    printf '       mask one — but a clean run over a moving tree is weaker evidence\n'
    printf '       than a clean run over a quiet one.\n\n'
fi

# VACUITY: a gate that reports 0 over nothing has certified nothing.
if [ "$ROWS" -eq 0 ]; then
    printf 'UNDETERMINED: the ledger holds ZERO claim rows. A 0 over an empty\n' >&2
    printf 'ledger would certify nothing, so it is refused.\n' >&2
    exit 2
fi

printf 'COVERAGE — BOUNDED AND STATED. §11.4.266(A) requires EVERY advertised\n'
printf 'capability to resolve to exactly one row. This ledger is a slice of %d.\n' "$ROWS"
printf 'CM-CLAIM-REALITY-LEDGER-COMPLETE is NOT satisfied; run --completeness for\n'
printf 'the remaining waves. Do NOT read a green exit as ledger completeness.\n\n'

# PRECEDENCE: a finding outranks an unmeasurable row.
if [ $((FALSE + ORPHAN + MALFORMED)) -gt 0 ]; then
    printf '❌ CLAIM-VS-REALITY: %d recorded claim(s) do not survive re-measurement.\n' \
        $((FALSE + ORPHAN + MALFORMED))
    exit 1
fi
if [ "$UNDET" -gt 0 ]; then
    printf '⚠️  UNDETERMINED: %d row(s) could not be re-measured. This is NOT a pass\n' "$UNDET"
    printf '   (§11.4.266(D)): an unchallenged claim blocks exactly as a failing one does.\n'
    exit 2
fi
printf '✅ every one of the %d recorded claim(s) is still made and still agrees\n' "$ROWS"
printf '   with a measurement taken during THIS run.\n'
exit 0
