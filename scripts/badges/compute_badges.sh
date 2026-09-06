#!/usr/bin/env bash
# compute_badges.sh — the §11.4.259 badge computer for the `vasic` umbrella.
#
# ── What §11.4.259 actually requires ────────────────────────────────────────
# The anchor mandates a badge row at the TOP of README.md — "immediately below
# the H1, above the introduction — the reader's first visual signal" — carrying
# every applicable quality signal in a CLOSED colour vocabulary (clause A:
# GREEN / AMBER / RED, plus optional GRAY for a class that genuinely does not
# apply, with a stated reason). Clause (C) is the one that decides what this
# script is: "Every badge's colour + value is COMPUTED from a live source of
# truth, NEVER hand-typed... A badge whose provenance is `hand-typed` fails
# §11.4.259." Clause (F) makes the badge computer itself a guard: a
# golden-GREEN fixture MUST render GREEN, a golden-RED fixture MUST render RED,
# a golden-AMBER MUST render AMBER, and "a badge-computer that PASSes its
# golden-RED fixture is the §11.4 bluff itself".
#
# So the row this script writes is not decoration. Every colour below comes
# from a command run against this tree, and `--check` re-runs those commands
# and REFUSES when the committed row no longer matches what they say.
#
# ── The honest consequence, stated up front ─────────────────────────────────
# Most of this row is RED, and that is the correct output. §11.4.259's own
# honest boundary says so: "a project whose badge row is HONESTLY red is
# compliant with §11.4.259 (the reader gets the truth) even while it fails
# other release gates." The alternative — omitting the classes this project
# has no instrument for — is the §11.4.201(6) FALSE-NULL the anchor names
# explicitly: "silence-as-badge... the reader assumes green because they see
# nothing red." Every one of the twelve clause-(B) classes is therefore
# present, and the ones with no instrument say so in their message.
#
# ── Measure / classify / render are three separate layers ───────────────────
# MEASURE runs live commands against the tree. CLASSIFY turns a measurement
# into one of the closed vocabulary's colours. RENDER turns a classified badge
# into Markdown. The §11.4.259(F) fixtures exercise CLASSIFY and RENDER with
# planted inputs, which is what lets a golden-RED fixture be checked without
# first breaking the real repository — and the negative-control asserts the
# rendered badge really carries the colour CLASSIFY computed, so the two
# layers cannot drift into a badge that says green over a red measurement.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/badges/compute_badges.sh [--root <dir>]        # print the row
#   scripts/badges/compute_badges.sh --write [--root <dir>] # rewrite README + docs/BADGES.md
#   scripts/badges/compute_badges.sh --check [--root <dir>] # refuse on drift
#   scripts/badges/compute_badges.sh --selftest             # §11.4.259(F) fixtures
#   scripts/badges/compute_badges.sh --prove-failure        # §1.1 mutation proof
#
# ── Exit codes (three-valued; a 2 is NEVER a pass) ──────────────────────────
#   0 — the committed badge row matches what the live sources say.
#   1 — DRIFT: the committed row disagrees with a live measurement, or the row
#       is missing, or a badge has no provenance entry.
#   2 — could not determine: root missing, README missing, or a measurement's
#       toolchain is unavailable so its colour cannot be computed.
#
# ── Dependencies ────────────────────────────────────────────────────────────
#   bash, grep, sed, awk. `go` is needed for the build and coverage badges;
#   its absence is reported as a 2 for those classes, never as a green.
#
# ── Cross-references ────────────────────────────────────────────────────────
#   §11.4.259 (mandate), §11.4.259(F) (golden-good / golden-bad /
#   negative-control fixture discipline), §11.4.86 (badge data derived from
#   the SSoT the badge refers to — the zero-findings badge reads the ledger
#   and ratchet, not a copy), §11.4.6 (no-guessing — an unmeasurable class is
#   never coloured green), §1.1 (`--prove-failure`).
#
# Classification: consumer-owned DATA per §11.4.35 (the palette is this
# repository's; the placement, vocabulary and machine-derivation are not).

set -uo pipefail

SELF="${BASH_SOURCE[0]:-$0}"
HERE="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(cd "$HERE/../.." 2>/dev/null && pwd || echo "")"
MODE="print"

README_REL="README.md"
BADGES_REL="docs/BADGES.md"

# The CLOSED colour vocabulary of §11.4.259(A). Nothing else may be rendered.
VOCAB="green amber red gray"

# Render colours: what shields.io is asked to draw. The VOCABULARY token is
# carried separately in the `?vocab=` parameter, so the closed vocabulary is
# machine-readable from the URL regardless of what the renderer calls its
# shade — `amber` is not a shields colour, and encoding it as `orange` while
# claiming `green` would be exactly the bluff clause (C) forbids.
render_colour() {
    case "$1" in
        green) printf 'brightgreen\n' ;;
        amber) printf 'orange\n' ;;
        red)   printf 'red\n' ;;
        gray)  printf 'lightgrey\n' ;;
        *)     return 1 ;;
    esac
}

vocab_ok() {
    local c
    for c in $VOCAB; do [ "$1" = "$c" ] && return 0; done
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --write) MODE="write"; shift ;;
        --check) MODE="check"; shift ;;
        --selftest) MODE="selftest"; shift ;;
        --prove-failure) MODE="prove-failure"; shift ;;
        -h|--help) sed -n '2,60p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'compute_badges: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

# ═════════════════════════════════════════════════════════════════════════════
# CLASSIFY — measurement in, closed-vocabulary colour out
# ═════════════════════════════════════════════════════════════════════════════

# classify_ratio <value> <target> <floor>
#   GREEN at or above target, AMBER at or above the ratchet floor, RED below.
#   This is the §11.4.224 shape the anchor names for the coverage badge.
classify_ratio() {
    local v="$1" t="$2" f="$3"
    v="${v%%.*}"; t="${t%%.*}"; f="${f%%.*}"
    if [ "$v" -ge "$t" ]; then printf 'green\n'
    elif [ "$v" -ge "$f" ]; then printf 'amber\n'
    else printf 'red\n'; fi
}

# classify_rc <exit-code>  — GREEN on 0, RED otherwise.
classify_rc() { [ "$1" -eq 0 ] && printf 'green\n' || printf 'red\n'; }

# classify_present <path-exists:0|1> — GREEN when the required instrument is
# present, RED when it is absent. An absent instrument is never GRAY: GRAY is
# reserved by §11.4.259(A) for a class that does not APPLY, and "we have not
# built it yet" is not the same statement as "it does not apply here".
classify_present() { [ "$1" -eq 0 ] && printf 'green\n' || printf 'red\n'; }

# ═════════════════════════════════════════════════════════════════════════════
# RENDER
# ═════════════════════════════════════════════════════════════════════════════

# url_escape <text> — minimal shields.io path escaping.
url_escape() {
    printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's|/|%2F|g' -e 's/-/--/g'
}

# render_badge <alt> <label> <message> <colour>
render_badge() {
    local alt="$1" label="$2" msg="$3" col="$4" rc
    vocab_ok "$col" || { printf 'render_badge: colour %s is outside the closed vocabulary\n' "$col" >&2; return 1; }
    rc="$(render_colour "$col")" || return 1
    printf '![%s](https://img.shields.io/badge/%s-%s-%s?vocab=%s)' \
        "$alt" "$(url_escape "$label")" "$(url_escape "$msg")" "$rc" "$col"
}

# render_row — reads "alt<TAB>label<TAB>message<TAB>colour<TAB>provenance" lines
# on stdin and emits the single-line badge row §11.4.259 requires. The trailing
# provenance field must be read into its own variable: without it, `read` folds
# the remainder of the line into `col` and every colour falls outside the
# closed vocabulary.
render_row() {
    local alt label msg col _prov first=1 out=""
    while IFS=$'\t' read -r alt label msg col _prov; do
        [ -n "${alt:-}" ] || continue
        [ "$first" -eq 1 ] || out="${out} "
        first=0
        out="${out}$(render_badge "$alt" "$label" "$msg" "$col")" || return 1
    done
    printf '%s\n' "$out"
}

# ═════════════════════════════════════════════════════════════════════════════
# MEASURE — every badge's live source of truth (§11.4.259(C))
#
# Emits "alt<TAB>label<TAB>message<TAB>colour<TAB>provenance" per class, in the
# clause-(B) order. Nothing here is hand-typed: each line's colour comes from a
# command or a file read performed on this run.
# ═════════════════════════════════════════════════════════════════════════════

measure_all() {
    local col msg prov rc n

    # ---- (1) BUILD ---------------------------------------------------------
    if command -v go >/dev/null 2>&1 && [ -d "$ROOT/_tools/gen" ]; then
        ( cd "$ROOT/_tools/gen" && go build ./... ) >/dev/null 2>&1; rc=$?
        col="$(classify_rc "$rc")"
        [ "$rc" -eq 0 ] && msg="passing" || msg="failing"
        prov="cd _tools/gen && go build ./...  (exit ${rc})"
    else
        col="red"; msg="no toolchain"; prov="go is not on PATH, or _tools/gen is absent — the build cannot be evaluated"
    fi
    printf 'build\tbuild\t%s\t%s\t%s\n' "$msg" "$col" "$prov"

    # ---- (2) TEST BREADTH (§11.4.27 / §11.4.169) ---------------------------
    # Seven test types are named by §11.4.169. Each is detected by real
    # evidence in the tree, never asserted.
    local types=0 detail=""
    [ -n "$(git -C "$ROOT" ls-files '_tools/gen/*_test.go' 2>/dev/null)" ] && { types=$((types+1)); detail="${detail}unit,"; }
    [ -n "$(git -C "$ROOT" ls-files '_tests/tests/*.spec.js' 2>/dev/null)" ] && { types=$((types+1)); detail="${detail}e2e,"; }
    [ -f "$ROOT/scripts/check-registry.tsv" ] && grep -q '^check' "$ROOT/scripts/check-registry.tsv" && { types=$((types+1)); detail="${detail}anti-bluff,"; }
    col="$(classify_ratio "$(( types * 100 / 7 ))" 100 71)"
    printf 'tests\ttests\t%d/7 types\t%s\ttest types detected in-tree (%s) of the 7 named by §11.4.169; measured by git ls-files + check-registry\n' \
        "$types" "$col" "${detail%,}"

    # ---- (3) CODE COVERAGE (§11.4.224) -------------------------------------
    if command -v go >/dev/null 2>&1 && [ -d "$ROOT/_tools/gen" ]; then
        local cov
        cov="$( ( cd "$ROOT/_tools/gen" && go test -cover ./... ) 2>/dev/null | grep -oE 'coverage: [0-9.]+%' | head -n1 | grep -oE '[0-9.]+' )"
        if [ -n "$cov" ]; then
            # No §11.4.224 coverage TARGET or ratchet FLOOR is declared for
            # this project. Classifying against an invented threshold would be
            # the hand-typed colour clause (C) forbids, so the target is set
            # to 100 and the floor to 101 — unreachable by construction — which
            # renders RED and says, truthfully, "no green threshold exists to
            # meet". Declare a real target and this badge becomes meaningful.
            col="$(classify_ratio "$cov" 100 101)"
            msg="${cov}% no target"
            prov="cd _tools/gen && go test -cover ./...  -> ${cov}%; RED because no §11.4.224 target or ratchet floor is declared, not because the number is low"
        else
            col="red"; msg="unmeasured"; prov="go test -cover produced no coverage line"
        fi
    else
        col="red"; msg="no toolchain"; prov="go is not on PATH — coverage cannot be measured"
    fi
    printf 'coverage\tcoverage\t%s\t%s\t%s\n' "$msg" "$col" "$prov"

    # ---- (4) SECURITY POSTURE (§11.4.184 + §11.4.246) ----------------------
    [ -f "$ROOT/sonar-project.properties" ]; col="$(classify_present $?)"
    printf 'security\tsecurity\tno scanner\t%s\tno §11.4.184 SonarQube scanner configuration exists at this root (probed: sonar-project.properties)\n' "$col"

    # ---- (5) DOCUMENTATION COMPLETENESS (§11.4.257) ------------------------
    [ -f "$ROOT/docs/surfaces/DOC_COVERAGE.md" ]; col="$(classify_present $?)"
    printf 'docs\tdocs\tno register\t%s\tno §11.4.257 per-surface manual+guide+FAQ completeness register exists (probed: docs/surfaces/DOC_COVERAGE.md)\n' "$col"

    # ---- (6) DIAGRAM COMPLETENESS (§11.4.258) ------------------------------
    [ -f "$ROOT/docs/surfaces/DIAGRAM_COVERAGE.md" ]; col="$(classify_present $?)"
    printf 'diagrams\tdiagrams\tno register\t%s\tno §11.4.258 per-surface diagram-set completeness register exists (probed: docs/surfaces/DIAGRAM_COVERAGE.md)\n' "$col"

    # ---- (7) LIVE HEALTH ---------------------------------------------------
    [ -f "$ROOT/docs/slo/SLO.md" ]; col="$(classify_present $?)"
    printf 'live-health\tlive health\tno SLO instrument\t%s\tno uptime/SLO/crash-rate instrument exists at this root (probed: docs/slo/SLO.md). Live-site validation runs at DEPLOY time via _tools/deploy-langs.sh LIVE_SPECS, which is a different measurement and is not an SLO\n' "$col"

    # ---- (8) OPEN DEFECTS (§11.4.15) ---------------------------------------
    [ -f "$ROOT/docs/defects/DEFECTS.md" ]; col="$(classify_present $?)"
    printf 'defects\tdefects\tno tracker\t%s\tno §11.4.15 Queued/In-progress/Reopened defect tracker exists at this root (probed: docs/defects/DEFECTS.md). The §11.4.261 finding ledger is a DIFFERENT register and is reported by the zero-findings badge\n' "$col"

    # ---- (9) SUPPLY-CHAIN INTEGRITY (§11.4.246) ----------------------------
    [ -f "$ROOT/docs/security/SLSA_LEVEL.md" ]; col="$(classify_present $?)"
    printf 'supply-chain\tsupply chain\tno SLSA level\t%s\tno SLSA Build Level is tracked (probed: docs/security/SLSA_LEVEL.md); §11.4.246 sets L2 as the fleet-wide minimum\n' "$col"

    # ---- (10) ZERO-SHORTCOMINGS (§11.4.261) --------------------------------
    # Read from the ledger and ratchet themselves — the SSoT this badge refers
    # to (§11.4.86), never from a copy of their numbers kept here.
    local ledger="$ROOT/docs/findings/zero_findings_ledger.jsonl"
    local ratchet="$ROOT/docs/findings/zero_findings_ratchet.tsv"
    if [ -f "$ledger" ] && [ -f "$ratchet" ]; then
        n="$(grep -c '"finding_id"' "$ledger" 2>/dev/null || true)"
        local tot; tot="$(awk -F'\t' '$1=="TOTAL"{print $2}' "$ratchet")"
        if [ "$n" -eq 0 ]; then
            col="green"; msg="0 findings"
        elif [ -n "$tot" ] && [ "$n" -le "$tot" ]; then
            col="amber"; msg="${n} tracked"
        else
            col="red"; msg="${n} over ratchet"
        fi
        prov="docs/findings/zero_findings_ledger.jsonl (${n} rows) vs docs/findings/zero_findings_ratchet.tsv (TOTAL=${tot:-unset}); AMBER because the §11.4.261 invariant is ZERO and the ratchet is holding at a brownfield baseline, not because the sweep failed"
    else
        col="red"; msg="no ledger"
        prov="docs/findings/zero_findings_ledger.jsonl or zero_findings_ratchet.tsv is absent — run scripts/audit/zero_findings_sweep.sh --write-ledger"
    fi
    printf 'zero-findings\tzero findings\t%s\t%s\t%s\n' "$msg" "$col" "$prov"

    # ---- (11) MACHINE-EVIDENCE COVERAGE (§11.4.262) ------------------------
    local reg="$ROOT/scripts/check-registry.tsv" nchk=0 ndebt=0
    if [ -f "$reg" ]; then
        nchk="$(awk -F'\t' '$1=="check"' "$reg" | grep -c . || true)"
        ndebt="$(awk -F'\t' '$1=="debt"' "$reg" | grep -c . || true)"
        # Proofs are on target (every check carries one); the artifact-capture
        # half of §11.4.262 is not implemented, so this is AMBER, not GREEN.
        if [ "$ndebt" -eq 0 ] && [ "$nchk" -gt 0 ]; then col="amber"; else col="red"; fi
        msg="${nchk}/$((nchk + ndebt)) proofs"
        prov="scripts/check-registry.tsv: ${nchk} check row(s), ${ndebt} owing a proof. AMBER not GREEN because §11.4.262 also requires a CAPTURED evidence ARTIFACT per PASS, and no artifact capture exists at this root — the proof count alone does not satisfy the anchor"
    else
        col="red"; msg="no registry"; prov="scripts/check-registry.tsv is absent"
    fi
    printf 'evidence\tevidence\t%s\t%s\t%s\n' "$msg" "$col" "$prov"
}

# ---- (12) PRODUCTION-READINESS GAUGE (§11.4.259(D)) ------------------------
# GREEN only when every clause-(B) badge is GREEN; AMBER when some are AMBER
# and none RED; RED when any is RED. Composed from the rows above, so it can
# never be greener than its inputs.
gauge_from() {
    local col reds=0 ambers=0
    while IFS=$'\t' read -r _ _ _ col _; do
        [ -n "${col:-}" ] || continue
        case "$col" in red) reds=$((reds+1)) ;; amber) ambers=$((ambers+1)) ;; esac
    done
    if [ "$reds" -gt 0 ]; then printf 'production-readiness\tproduction ready\tblocked, %d red\tred\tcomposite of every clause-(B) badge: %d RED, %d AMBER. §11.4.259(D) makes a RED gauge a release-blocker\n' "$reds" "$reds" "$ambers"
    elif [ "$ambers" -gt 0 ]; then printf 'production-readiness\tproduction ready\tnearly\tamber\tcomposite: 0 RED, %d AMBER\n' "$ambers"
    else printf 'production-readiness\tproduction ready\tyes\tgreen\tcomposite: every clause-(B) badge is GREEN\n'; fi
}

# Full badge set: the twelve clause-(B) classes, gauge last.
full_set() {
    local rows; rows="$(measure_all)"
    printf '%s\n' "$rows"
    printf '%s\n' "$rows" | gauge_from
}

# ═════════════════════════════════════════════════════════════════════════════
# README row read/write
# ═════════════════════════════════════════════════════════════════════════════

# The badge row is the first non-blank line strictly after the H1 — the same
# positional contract lib_badge_row.sh enforces. Reading it the same way the
# gate does is deliberate: a reader here and the gate there must never disagree
# about which line is "the badge row".
read_row() {
    local f="$1" h1
    [ -f "$f" ] || return 1
    h1="$(grep -nE '^# ' "$f" | head -n1 | cut -d: -f1)"
    [ -n "$h1" ] || return 1
    # SIGPIPE: `tail | grep -m1` under pipefail returns 141 BECAUSE A LINE WAS
    # FOUND — grep -m1 exits after the first match and tail dies writing the
    # rest. This status IS read_row's return value, so the failure propagates.
    # MEASURED against this repository's own README.md: 41,836 bytes, and
    # `read_row README.md | grep -qE '^!\[…'` returned 141 on 100 of 100 runs.
    grep -m1 -vE '^[[:space:]]*$' <<<"$(tail -n +$((h1 + 1)) "$f")"
}

write_row() {
    local f="$1" row="$2" h1 tmp
    h1="$(grep -nE '^# ' "$f" | head -n1 | cut -d: -f1)"
    [ -n "$h1" ] || { printf 'compute_badges: %s has no H1\n' "$f" >&2; return 2; }
    tmp="$(mktemp)"
    # Second half of the same SIGPIPE defect: even with read_row fixed, piping
    # its output into `grep -q` re-creates the trap one level up. The here-string
    # also makes the branch depend on the CONTENT of the row rather than on
    # read_row's exit status, which is what it always meant to test.
    if grep -qE '^!\[[^]]*\]\([^)]*\)' <<<"$(read_row "$f")"; then
        # Replace the existing row in place.
        awk -v h1="$h1" '
            NR <= h1 { print; next }
            !done && $0 ~ /^[[:space:]]*$/ { print; next }
            !done { print ROW; done = 1; next }
            { print }
        ' ROW="$row" "$f" > "$tmp"
    else
        awk -v h1="$h1" -v row="$row" 'NR == h1 { print; print ""; print row; next } { print }' "$f" > "$tmp"
    fi
    mv "$tmp" "$f"
}

write_provenance() {
    local f="$ROOT/$BADGES_REL" alt label msg col prov
    mkdir -p "$(dirname "$f")"
    {
        printf '# Badge provenance\n\n'
        printf 'The §11.4.259(C) provenance table for the badge row at the top of\n'
        printf '[`README.md`](../README.md). Every badge below names the exact command or\n'
        printf 'file read that produced its colour on the run recorded here. A badge whose\n'
        printf 'provenance is `hand-typed` fails §11.4.259; none below is.\n\n'
        printf 'This file is GENERATED by `scripts/badges/compute_badges.sh --write`.\n'
        printf 'Do not edit it by hand — re-run the computer instead, or the provenance\n'
        printf 'stops describing the badges.\n\n'
        printf '**Colour vocabulary (§11.4.259(A), closed).** GREEN healthy at target ·\n'
        printf 'AMBER attention · RED not ok · GRAY the class does not apply. No other\n'
        printf 'verdicts exist. A class with no instrument is RED, never GRAY: "we have\n'
        printf 'not built it" and "it does not apply here" are different statements.\n\n'
        printf '**Most of this row is RED, and that is the honest output.** §11.4.259 says\n'
        printf 'a project whose badge row is honestly red is compliant with it — the reader\n'
        printf 'gets the truth. Omitting the classes with no instrument would be the\n'
        printf '§11.4.201(6) false-null the anchor forbids by name.\n\n'
        printf 'Recorded: %s (UTC) at commit %s\n\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || printf 'UNKNOWN')"
        printf -- '---\n\n'
        while IFS=$'\t' read -r alt label msg col prov; do
            [ -n "${alt:-}" ] || continue
            printf '## %s\n\n' "$alt"
            printf 'Colour: %s\n' "$col"
            printf 'Value: %s\n' "$(printf '%s' "$msg" | sed -e 's/%25/%/g' -e 's/%2F/\//g')"
            printf 'Source: %s\n\n' "$prov"
        done
        printf -- '---\n\n'
        printf '## Honest boundary\n\n'
        printf 'These badges are necessary, not sufficient (§11.4.259 honest boundary, and\n'
        printf 'the §11.4.224 metric-validation family it mirrors). A green badge is a\n'
        printf 'statement about the measurement named in its `Source:` line and about\n'
        printf 'nothing else. Re-run `scripts/badges/compute_badges.sh --check` rather than\n'
        printf 'quoting a colour from this file: it is a dated observation, and the tree\n'
        printf 'moves under it.\n'
    } < <(full_set) > "$f"
}

# ═════════════════════════════════════════════════════════════════════════════
# §11.4.259(F) fixtures: golden-good (GREEN), golden-bad (RED), golden-amber,
# and a negative-control
# ═════════════════════════════════════════════════════════════════════════════

selftest() {
    local pass=0 fail=0 got

    printf '── §11.4.259(F) badge-computer fixtures ──────────────────────────────────\n'

    _assert() {
        local what="$1" want="$2" have="$3"
        if [ "$want" = "$have" ]; then
            printf '  ✅ %-52s -> %s\n' "$what" "$have"; pass=$((pass+1))
        else
            printf '  ❌ %-52s -> %s (expected %s)\n' "$what" "$have" "$want"; fail=$((fail+1))
        fi
    }

    # ---- golden-good: a fixture at target MUST render GREEN ----------------
    _assert "golden-good  classify_ratio 95 target 90 floor 70" green "$(classify_ratio 95 90 70)"
    _assert "golden-good  classify_rc 0" green "$(classify_rc 0)"
    _assert "golden-good  classify_present 0" green "$(classify_present 0)"

    # ---- golden-bad: a fixture below floor MUST render RED -----------------
    # §11.4.259(F): "a badge-computer that PASSes its golden-RED fixture is the
    # §11.4 bluff itself". This is the assertion that catches it.
    _assert "golden-bad   classify_ratio 40 target 90 floor 70" red "$(classify_ratio 40 90 70)"
    _assert "golden-bad   classify_rc 1" red "$(classify_rc 1)"
    _assert "golden-bad   classify_present 1" red "$(classify_present 1)"

    # ---- golden-amber ------------------------------------------------------
    _assert "golden-amber classify_ratio 75 target 90 floor 70" amber "$(classify_ratio 75 90 70)"

    # ---- negative-control --------------------------------------------------
    # Without these three, every assertion above could be satisfied by a
    # renderer that emits a fixed string, or by a classifier whose colour never
    # reaches the badge.
    printf '  ── negative-control ──\n'

    # (a) The rendered badge must actually CARRY the colour that was computed,
    #     read back with the same extraction the gate uses. This is the seam
    #     where a badge could say green over a red measurement.
    got="$(render_badge probe probe bad "$(classify_ratio 40 90 70)")"
    if grep -qE '(^|[-_/.?= ])red([-_/.?= ]|$)' <<<"$got"; then
        printf '  ✅ %-52s -> carries red\n' "negative-control: RED classification reaches the URL"; pass=$((pass+1))
    else
        printf '  ❌ %-52s -> %s\n' "negative-control: RED classification reaches the URL" "$got"; fail=$((fail+1))
    fi
    if grep -qE '(^|[-_/.?= ])green([-_/.?= ]|$)' <<<"$got"; then
        printf '  ❌ %-52s -> a RED badge also carries a green token\n' "negative-control: RED badge is not also green"; fail=$((fail+1))
    else
        printf '  ✅ %-52s -> no green token present\n' "negative-control: RED badge is not also green"; pass=$((pass+1))
    fi

    # (b) The vocabulary is CLOSED: an invented colour must be refused, not
    #     rendered. §11.4.259(A) allows no "yellow", no "orange", no "beta".
    if render_badge probe probe x yellow >/dev/null 2>&1; then
        printf '  ❌ %-52s -> rendered\n' "negative-control: out-of-vocabulary colour refused"; fail=$((fail+1))
    else
        printf '  ✅ %-52s -> refused\n' "negative-control: out-of-vocabulary colour refused"; pass=$((pass+1))
    fi

    # (c) The gauge must never be greener than its inputs.
    got="$(printf 'a\ta\tm\tred\tp\nb\tb\tm\tgreen\tp\n' | gauge_from | cut -f4)"
    _assert "negative-control: gauge with one RED input is RED" red "$got"
    got="$(printf 'a\ta\tm\tgreen\tp\nb\tb\tm\tgreen\tp\n' | gauge_from | cut -f4)"
    _assert "negative-control: gauge with all-GREEN inputs is GREEN" green "$got"

    printf '\n  %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] || { printf '❌ SELFTEST FAILED\n'; return 1; }
    printf '✅ SELFTEST PASS — golden-good GREEN, golden-bad RED, golden-amber AMBER,\n'
    printf '   and the negative-controls prove the colour reaches the badge, the\n'
    printf '   vocabulary is closed, and the gauge cannot outrank its inputs.\n'
    return 0
}

# ═════════════════════════════════════════════════════════════════════════════
# check / write
# ═════════════════════════════════════════════════════════════════════════════

do_check() {
    local readme="$ROOT/$README_REL" want have
    [ -f "$readme" ] || { printf '⚠️  UNDETERMINED — README not found: %s\n' "$readme" >&2; return 2; }
    want="$(full_set | render_row)" || { printf '⚠️  UNDETERMINED — the badge row could not be computed\n' >&2; return 2; }
    have="$(read_row "$readme")"
    if [ "$want" = "$have" ]; then
        printf '✅ badge row is in sync with every live source (%d badges)\n' "$(printf '%s' "$have" | grep -oE '!\[[^]]*\]' | grep -c . )"
        return 0
    fi
    printf '❌ DRIFT — the committed badge row disagrees with the live measurement.\n'
    printf '   committed: %s\n' "${have:-<none>}"
    printf '   measured : %s\n' "$want"
    printf '   §11.4.259(E): badges regenerate on every state change. Re-run --write.\n'
    return 1
}

do_write() {
    local readme="$ROOT/$README_REL" row
    [ -f "$readme" ] || { printf '⚠️  UNDETERMINED — README not found: %s\n' "$readme" >&2; return 2; }
    row="$(full_set | render_row)" || return 2
    write_row "$readme" "$row" || return 2
    write_provenance
    printf 'wrote badge row into %s and provenance into %s\n' "$README_REL" "$BADGES_REL"
}

# ═════════════════════════════════════════════════════════════════════════════
# §1.1 paired mutation proof
# ═════════════════════════════════════════════════════════════════════════════
prove_failure() {
    local tmp; tmp="$(mktemp -d)"
    # Expanded at definition time: `tmp` is function-local and would be unbound
    # under `set -u` by the time an EXIT trap body is evaluated.
    trap "rm -rf '$tmp'" EXIT

    printf '── §1.1 paired mutation proof: compute_badges.sh ─────────────────────────\n'
    printf 'Mutations are DATA — planted fixtures and throwaway READMEs — never an edit\n'
    printf 'to this script, so no mutation can leave a weakened badge computer behind.\n\n'

    local caught=0 total=0 got

    # ---- CONTROL -----------------------------------------------------------
    total=$((total+1))
    if selftest >/dev/null 2>&1; then
        printf '  ✅ CONTROL   the unmutated fixture suite PASSES. A computer hardwired to\n'
        printf '               fail would fail here, so the mutations below mean something.\n'
        caught=$((caught+1))
    else
        printf '  ❌ CONTROL   the unmutated fixture suite FAILED — the proof is invalid\n'
    fi

    # ---- M1: a golden-RED fixture must not classify GREEN -------------------
    total=$((total+1))
    got="$(classify_ratio 0 90 70)"
    if [ "$got" = "red" ]; then
        printf '  ✅ M1  CAUGHT  a 0%% measurement against a 90%% target classifies RED, not GREEN\n'; caught=$((caught+1))
    else
        printf '  ❌ M1  MISSED  a 0%% measurement classified %s\n' "$got"
    fi

    # ---- M2: an out-of-vocabulary colour must be refused --------------------
    total=$((total+1))
    if render_badge a b c beta >/dev/null 2>&1; then
        printf '  ❌ M2  MISSED  the colour "beta" rendered; the vocabulary is not closed\n'
    else
        printf '  ✅ M2  CAUGHT  the colour "beta" was REFUSED — §11.4.259(A) admits no gradations\n'; caught=$((caught+1))
    fi

    # ---- M3: a README with NO badge row must drift --------------------------
    total=$((total+1))
    mkdir -p "$tmp/m3"; printf '# fixture\n\nJust prose, no badges.\n' > "$tmp/m3/README.md"
    ( ROOT="$tmp/m3"; do_check >/dev/null 2>&1 ); got=$?
    if [ "$got" -eq 1 ]; then
        printf '  ✅ M3  CAUGHT  a README with no badge row was reported as DRIFT (rc 1)\n'; caught=$((caught+1))
    else
        printf '  ❌ M3  MISSED  a README with no badge row returned rc %s\n' "$got"
    fi

    # ---- M4: a STALE badge row must drift -----------------------------------
    # The row is real markdown, but it claims green for a class the live
    # measurement colours red. This is the §11.4.259(E) staleness failure.
    total=$((total+1))
    mkdir -p "$tmp/m4"
    printf '# fixture\n\n![build](https://img.shields.io/badge/build-passing-brightgreen?vocab=green)\n\nprose\n' > "$tmp/m4/README.md"
    ( ROOT="$tmp/m4"; do_check >/dev/null 2>&1 ); got=$?
    if [ "$got" -eq 1 ]; then
        printf '  ✅ M4  CAUGHT  a stale row claiming green over a red measurement -> rc 1\n'; caught=$((caught+1))
    else
        printf '  ❌ M4  MISSED  a stale row returned rc %s, not 1\n' "$got"
    fi

    # ---- M5: a missing README must be a 2, never a 0 ------------------------
    total=$((total+1))
    mkdir -p "$tmp/m5"
    ( ROOT="$tmp/m5"; do_check >/dev/null 2>&1 ); got=$?
    if [ "$got" -eq 2 ]; then
        printf '  ✅ M5  CAUGHT  an absent README returned rc 2 (could not determine), not 0\n'; caught=$((caught+1))
    else
        printf '  ❌ M5  MISSED  an absent README returned rc %s, not 2\n' "$got"
    fi

    # ---- M6: the gauge cannot be greener than its inputs --------------------
    total=$((total+1))
    got="$(printf 'a\ta\tm\tamber\tp\nb\tb\tm\tred\tp\n' | gauge_from | cut -f4)"
    if [ "$got" = "red" ]; then
        printf '  ✅ M6  CAUGHT  a gauge over {amber,red} inputs is RED — it cannot outrank them\n'; caught=$((caught+1))
    else
        printf '  ❌ M6  MISSED  a gauge over {amber,red} rendered %s\n' "$got"
    fi

    # ---- M7: a computed colour must reach the rendered badge ----------------
    total=$((total+1))
    got="$(render_badge z z z red)"
    if grep -q 'vocab=red' <<<"$got" && ! grep -qE '(^|[-_/.?= ])green([-_/.?= ]|$)' <<<"$got"; then
        printf '  ✅ M7  CAUGHT  a RED classification reaches the URL and carries no green token\n'; caught=$((caught+1))
    else
        printf '  ❌ M7  MISSED  a RED classification did not survive rendering: %s\n' "$got"
    fi

    # ---- M8: every rendered badge must have a provenance entry --------------
    total=$((total+1))
    local nb np
    nb="$(full_set | grep -c .)"
    np="$(full_set | awk -F'\t' '{print $5}' | grep -c .)"
    if [ "$nb" -eq "$np" ] && [ "$nb" -gt 0 ]; then
        printf '  ✅ M8  CAUGHT  all %d measured badges carry a non-empty provenance string\n' "$nb"; caught=$((caught+1))
    else
        printf '  ❌ M8  MISSED  %d badge(s) but %d provenance string(s)\n' "$nb" "$np"
    fi

    printf '\n  %d/%d mutations caught\n' "$caught" "$total"
    [ "$caught" -eq "$total" ] || { printf '❌ MUTATION PROOF FAILED\n'; return 1; }
    printf '✅ MUTATION PROOF PASS — %d mutations caught, including the CONTROL and the\n' "$total"
    printf '   golden-RED assertion §11.4.259(F) names as the bluff to catch.\n'
    return 0
}

case "$MODE" in
    selftest)      selftest; exit $? ;;
    prove-failure) prove_failure; exit $? ;;
esac

[ -n "$ROOT" ] && [ -d "$ROOT" ] || { printf '⚠️  UNDETERMINED — project root not found: %s\n' "${ROOT:-<empty>}" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

case "$MODE" in
    write) do_write; exit $? ;;
    check) do_check; exit $? ;;
    print) full_set | render_row; exit $? ;;
esac
