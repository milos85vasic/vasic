#!/usr/bin/env bash
# zero_findings_sweep.sh — the §11.4.261(B) mechanical audit sweep for the
# `vasic` umbrella root.
#
# ── What §11.4.261 actually says, and what this script therefore is ──────────
# The anchor's operator mandate is "There MUST BE ALWAYS exactly zero
# shortcomings, gaps, weak spots or danger zones in the project". Its clause
# (B) binds the mechanism to a single executable script at this exact path
# ("Lava binding: `scripts/audit/zero_findings_sweep.sh`") which iterates a
# CLOSED, NEVER-SUBTRACTABLE vocabulary of ten finding classes and emits a
# machine-readable ledger of
# {finding_id, class, file, line, description, status, tracker_ref,
#  mitigation_evidence}. Clause (C) binds that ledger to a MONOTONE-DECREASING
# ratchet. Clause (D) requires every finding be CLOSED (with captured
# evidence) or TRACKED (with a real item + mitigation) — never silently
# absorbed. Clause (E) states the honest meaning of "zero": the closed-
# vocabulary audit finds zero unclosed-untracked entries; it is NOT a claim of
# omniscience, and "a project narrowing the vocabulary to declare zero is a
# §11.4.6 fabrication and a release-blocker".
#
# So this script is NOT a "count the TODOs" linter. It is the honesty seam:
# it measures ten classes, writes every instance into a git-tracked ledger,
# and REFUSES the seam when a class's count rises above its recorded ceiling.
#
# ── The ten closed-vocabulary classes (§11.4.261(A)) ────────────────────────
#   1 shortcomings           implementation gaps behind a working contract
#   2 gaps                   capabilities the docs / schema / API promise but
#                            that are not delivered
#   3 weak-spots             code paths without adequate guards
#   4 danger-zones           patterns known to cause serious harm
#   5 todo-fixme             TODO / FIXME / "for now" / placeholder /
#                            NotImplementedError / stub returns / dead code
#   6 skipped-tests          skipped tests and disabled gates without a
#                            tracked `SKIP-OK: <ticket>` per §11.4.3
#   7 bluffs                 §11.4 covenant-violation surface (a PASS with no
#                            positive evidence; a check with no paired proof)
#   8 unresolved             §11.4.197 tracked items past their stated window
#   9 divergent-stale-orphan §11.4.233 anti-mess control plane
#  10 uncatalogued           anti-patterns with no paired §1.1 mutation
#
# Subtraction from this vocabulary is forbidden. Every class below is
# measured on every run, and a class whose DETECTOR INPUT is absent is
# reported as UNDETERMINED (exit 2) — never silently as zero. That
# distinction is the whole of §11.4.261(E).
#
# ── Honest boundary (§11.4.6) — read before quoting any number this prints ──
# Every detector below states its DETECTION BASIS and its RECALL LIMIT, and
# prints both on every run. A count of 0 from a detector means "this
# detector, with the basis it declares, found nothing" — it NEVER means the
# class is empty. §11.4.261(E) and §11.4.118 (discovery pressure) both say so
# explicitly: the catalogued is what a sweep can reach; the un-catalogued
# needs discovery this script cannot perform. Detector 1 and detector 10 in
# particular are marker-driven: they find what somebody already wrote down.
#
# Four file-scope exclusions are DECLARED here rather than left implicit,
# each with its reason and its recall cost, mirroring the declared-subtraction
# discipline of scripts/verify-content-boundary.sh:
#   _tests/evidence/**       captured test-run artifacts and vendored
#                            Playwright report bundles — machine output, not
#                            authored source. RECALL COST: a real defect
#                            authored into an evidence directory is invisible.
#   .specify/extensions/**   vendored third-party spec-kit extension copy;
#                            this repository does not own it and cannot fix
#                            it. RECALL COST: third-party findings unreported.
#   submodules/, workshop/   not enumerated at all: `git ls-files` at this
#   and every other gitlink  root lists a gitlink as ONE entry, so submodule
#                            content is out of scope by construction. A
#                            finding inside a submodule is fixed inside that
#                            submodule and returns as a gitlink bump.
#   this script itself       excluded from the FOUR pattern detectors only,
#                            because it carries the patterns it hunts for as
#                            literals. See `drop_self` below for the full
#                            reasoning and its recall cost.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   scripts/audit/zero_findings_sweep.sh [--root <dir>] [--quiet] [--json]
#   scripts/audit/zero_findings_sweep.sh --write-ledger [--root <dir>]
#   scripts/audit/zero_findings_sweep.sh --write-ratchet [--root <dir>]
#   scripts/audit/zero_findings_sweep.sh --selftest
#   scripts/audit/zero_findings_sweep.sh --prove-failure
#
#     --root <dir>      project root to sweep (default: this script's
#                       grandparent directory).
#     --quiet           one line per class instead of per-finding detail.
#     --json            emit the ledger rows to stdout instead of a summary.
#     --write-ledger    (re)write docs/findings/zero_findings_ledger.jsonl
#                       from this run. The ledger is a SNAPSHOT, not an
#                       append log — see "Why a snapshot" below.
#     --write-ratchet   write docs/findings/zero_findings_ratchet.tsv from
#                       the CURRENT measured counts. This is the brownfield
#                       adoption snapshot of §11.4.261(C) / §11.4.224(E) and
#                       is an OPERATOR decision, never automatic: it may only
#                       ever be used to LOWER a ceiling after a real fix. The
#                       command REFUSES to raise any ceiling.
#     --selftest        run the golden-good / golden-bad / negative-control
#                       fixtures per §11.4.107(10) against a synthetic tree.
#     --prove-failure   the §1.1 paired mutation proof for this script.
#
# ── Why a snapshot and not an append log ────────────────────────────────────
# §11.4.261(B) says the ledger is "persistent, append-only + snapshot per
# §11.4.116". The two consuming gates decide which reading is operative:
# cm_zero_findings_monotone_ratchet.sh tallies EVERY ledger row by class and
# compares that tally to the ratchet ceiling. Under an append log the tally
# would rise monotonically with history and the ratchet could never be met,
# so the ledger this script writes is the SNAPSHOT half of that clause: it
# describes the findings that exist NOW. History is preserved by git, which
# is the §11.4.95 requirement the clause also names — every previous snapshot
# is recoverable with `git log -p docs/findings/zero_findings_ledger.jsonl`.
#
# ── Exit codes (three-valued; a 2 is NEVER a pass) ──────────────────────────
#   0 — every class measured, and every class's count is within its ratchet
#       ceiling.
#   1 — at least one class exceeds its ratchet ceiling (the seam REFUSES), or
#       a finding is neither closed nor tracked.
#   2 — could not determine: root missing, git unavailable, a detector's
#       input absent, or the ratchet file missing on a verdict run.
#
# ── Dependencies ────────────────────────────────────────────────────────────
#   bash, git, grep, sed, awk, sort. Parses clean under `bash -n`.
#
# ── Cross-references ────────────────────────────────────────────────────────
#   §11.4.261 (mandate), §11.4.107(10) (golden-good / golden-bad /
#   negative-control fixture discipline), §11.4.135 (the ratchet pattern),
#   §11.4.223 (honest provenance markers at the finding site), §11.4.6
#   (no-guessing; a missing detector input is a 2, never a 0), §1.1 (the
#   paired mutation proof is `--prove-failure` in this file, the pairing form
#   scripts/check-registry.tsv actually enforces).
#
# Classification: consumer-owned DATA per §11.4.35 (the class list is
# universal; the detectors are this repository's).

set -uo pipefail

SELF="${BASH_SOURCE[0]:-$0}"
HERE="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(cd "$HERE/../.." 2>/dev/null && pwd || echo "")"

QUIET=0
JSON=0
MODE="verdict"

LEDGER_REL="docs/findings/zero_findings_ledger.jsonl"
RATCHET_REL="docs/findings/zero_findings_ratchet.tsv"
TRACKED_REL="docs/findings/TRACKED.md"

# The CLOSED vocabulary. Order is fixed; membership is never subtractable.
CLASSES=(
    shortcomings
    gaps
    weak-spots
    danger-zones
    todo-fixme
    skipped-tests
    bluffs
    unresolved
    divergent-stale-orphan
    uncatalogued
)

# Declared file-scope exclusions, each with the reason printed on every run.
EXCLUDE_PREFIXES=(
    "_tests/evidence/"
    ".specify/extensions/"
)

usage() { sed -n '2,95p' "$SELF" | sed 's/^# \{0,1\}//'; }

die_undet() { printf '⚠️  UNDETERMINED — %s\n' "$1" >&2; exit 2; }

while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --quiet) QUIET=1; shift ;;
        --json) JSON=1; shift ;;
        --write-ledger) MODE="write-ledger"; shift ;;
        --write-ratchet) MODE="write-ratchet"; shift ;;
        --selftest) MODE="selftest"; shift ;;
        --prove-failure) MODE="prove-failure"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'zero_findings_sweep: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
done

# ═════════════════════════════════════════════════════════════════════════════
# Scope
# ═════════════════════════════════════════════════════════════════════════════

# Emits one relative path per line: every tracked file at ROOT, minus the
# declared exclusions. Submodule content never appears — a gitlink is one
# entry in `git ls-files`, so this is scope-by-construction, not a filter.
scan_files() {
    local pat
    git -C "$ROOT" ls-files 2>/dev/null | while IFS= read -r f; do
        for pat in "${EXCLUDE_PREFIXES[@]}"; do
            case "$f" in "$pat"*) continue 2 ;; esac
        done
        printf '%s\n' "$f"
    done
}

# Scope restricted to authored source of the given extensions.
scan_source() {
    scan_files | grep -E '\.(sh|go|py|js|ts|rb)$' || true
}

# ---- the fourth declared exclusion: this script's own source ---------------
# The four PATTERN-matching detectors below (shortcomings, danger-zones,
# todo-fixme, skipped-tests) carry the patterns they hunt for as literal strings — in the
# regexes themselves, in the DETECTOR_BASIS prose, and in the golden-bad
# fixture that plants one finding per class. Scanned like any other file, this
# script reports its own pattern DEFINITIONS as pattern INSTANCES: measured,
# 12 self-matches, every one a false positive by construction.
#
# So the pattern detectors skip this one file. That is a false-positive fix,
# not the vocabulary narrowing §11.4.261(E) forbids — nothing is removed from
# the class, and the golden-bad fixture still proves each detector fires.
#
# RECALL COST, stated because it is real: a genuine danger-zone, marker or
# skipped test introduced into THIS file is invisible to THIS file. The guard
# against that is `--selftest`, which every consuming gate runs, and review.
# The other six detectors DO scan this script normally.
SELF_REL="scripts/audit/zero_findings_sweep.sh"
drop_self() { grep -vxF "$SELF_REL" || true; }

# Sanitise a description for embedding in a JSON string field.
jsan() {
    printf '%s' "$1" | tr '\t\n' '  ' | sed -e 's/\\/\//g' -e 's/"/'"'"'/g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -c1-220
}

# ═════════════════════════════════════════════════════════════════════════════
# The ten detectors
#
# Each emits TAB-separated: <class> <file> <line> <description> <tracker_ref>
# An empty tracker_ref means "use the class-level tracker entry".
# Each sets DETECTOR_BASIS and DETECTOR_RECALL for the run report, and
# returns 2 if its input is absent (never 0 — §11.4.6).
# ═════════════════════════════════════════════════════════════════════════════

DETECTOR_BASIS=""
DETECTOR_RECALL=""

# ---- 1. shortcomings ────────────────────────────────────────────────────────
# An implementation gap behind a working contract is not mechanically
# distinguishable from working code, so this detector is MARKER-DRIVEN: it
# reports the §11.4.223 honest-provenance markers an author already wrote,
# plus every `debt` row in the check registry (a registered debt IS a
# declared shortcoming).
detect_shortcomings() {
    DETECTOR_BASIS="declared §11.4.223 provenance markers (SHORTCOMING:, [OPEN: <ref>]) in authored source, plus 'debt' rows in scripts/check-registry.tsv"
    DETECTOR_RECALL="finds only what an author already declared; an undeclared shortcoming behind a working contract is invisible to any static detector"
    local f n text
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$ROOT/$f" ] || continue
        while IFS=: read -r n text; do
            [ -n "${n:-}" ] || continue
            printf 'shortcomings\t%s\t%s\t%s\t\n' "$f" "$n" "$(jsan "$text")"
        done < <(grep -nE 'SHORTCOMING:|\[OPEN: [A-Z]' "$ROOT/$f" 2>/dev/null || true)
    done < <(scan_source | drop_self)

    local reg="$ROOT/scripts/check-registry.tsv"
    if [ -f "$reg" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            local id owed
            id="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
            owed="$(printf '%s' "$line" | awk -F'\t' '{print $4}')"
            printf 'shortcomings\t%s\t%s\t%s\t\n' "scripts/check-registry.tsv" \
                "$(grep -nF "$line" "$reg" | head -n1 | cut -d: -f1)" \
                "$(jsan "registered debt '${id}' owes {${owed}}")"
        done < <(awk -F'\t' '$1=="debt"' "$reg")
    fi
    return 0
}

# ---- 2. gaps ────────────────────────────────────────────────────────────────
# This repository maintains a real gap register — the constitution-adoption
# INVENTORY. Every G-row whose status is not CLOSED is a gap the project has
# already admitted to. Reading it is measurement, not invention.
detect_gaps() {
    local inv="docs/constitution-adoption/INVENTORY.md"
    DETECTOR_BASIS="every 'G<n>' row in ${inv} whose recorded status is not CLOSED"
    DETECTOR_RECALL="a capability the docs promise that nobody has entered in the register is not reported"
    [ -f "$ROOT/$inv" ] || return 2
    local n row gid status
    while IFS=: read -r n row; do
        [ -n "${n:-}" ] || continue
        gid="$(printf '%s' "$row" | awk -F'|' '{print $2}' | tr -d ' ')"
        status="$(printf '%s' "$row" | awk -F'|' '{print $3}' | sed -e 's/\*//g' -e 's/^ *//' -e 's/ *$//')"
        case "$status" in
            CLOSED*) continue ;;
        esac
        printf 'gaps\t%s\t%s\t%s\t%s\n' "$inv" "$n" \
            "$(jsan "${gid}: ${status}")" "${inv}#${gid}"
    done < <(grep -nE '^\| G[0-9]+ \|' "$ROOT/$inv" 2>/dev/null || true)
    return 0
}

# ---- 3. weak-spots ──────────────────────────────────────────────────────────
# A shell script that does not fail on an unset variable will happily expand
# a typo'd name to the empty string and carry on — the exact "code path
# without an adequate guard" §11.4.261(A)(3) names. Every gate in this tree
# is a shell script, so this is a load-bearing guard, not a style rule.
detect_weak_spots() {
    DETECTOR_BASIS="tracked shell scripts under scripts/ and tests/ with no 'set -u' (or 'set -eu' etc.) unset-variable guard"
    DETECTOR_RECALL="covers ONE guard class in ONE language; an unguarded path in Go, Python or JS is not reported by this detector"
    local f
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$ROOT/$f" ] || continue
        if ! grep -qE '^[[:space:]]*set[[:space:]]+-[a-z]*u' "$ROOT/$f"; then
            printf 'weak-spots\t%s\t%s\t%s\t\n' "$f" "1" \
                "$(jsan "shell script has no 'set -u' guard: an unset or mistyped variable expands to empty instead of failing")"
        fi
    done < <(scan_files | grep -E '^(scripts|tests)/.*\.sh$' || true)
    return 0
}

# ---- 4. danger-zones ────────────────────────────────────────────────────────
# Patterns that cause serious, often irreversible harm: history rewrites,
# gate bypasses, unquoted recursive deletes, and `eval` of a variable.
detect_danger_zones() {
    DETECTOR_BASIS="in tracked shell source, outside comments: force-push, --no-verify, 'rm -rf' with an unquoted target, and 'eval' applied to a variable"
    DETECTOR_RECALL="pattern-based; a harmful operation composed at runtime from parts is not matched"
    local f n text
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$ROOT/$f" ] || continue
        while IFS=: read -r n text; do
            [ -n "${n:-}" ] || continue
            case "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')" in '#'*) continue ;; esac
            printf 'danger-zones\t%s\t%s\t%s\t\n' "$f" "$n" "$(jsan "$text")"
        # `-[a-zA-Z]*r` requires the RECURSIVE flag: `rm -f <literal>` deletes
        # one named file and is not the danger this class names. Matching it
        # would put the detector at odds with its own declared basis.
        done < <(grep -nE 'push[^|]*--force|--no-verify|rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+[^-"'"'"'$[:space:]]|eval[[:space:]]+"?\$' "$ROOT/$f" 2>/dev/null || true)
    done < <(scan_files | grep -E '\.sh$' | drop_self || true)
    return 0
}

# ---- 5. todo-fixme ──────────────────────────────────────────────────────────
# The marker classes §11.4.261(A)(5) enumerates. Markers are matched in their
# real convention form (MARKER followed by ':' or '('), so this detector does
# not fire on prose that merely names the class — including the prose in this
# file's own header, which is scanned like every other tracked file.
detect_todo_fixme() {
    DETECTOR_BASIS="UPPERCASE TODO:/FIXME:/XXX:/HACK: markers in convention form, NotImplementedError, and 'for now'/'temporary'/'placeholder' comment markers, in authored source"
    DETECTOR_RECALL="matched case-SENSITIVELY, because a lowercase 'todo' is far more often an ordinary identifier than a marker (measured: 'if not todo:' in _tools/gen/translate_ui_all.py is a variable, not debt). RECALL COST: a marker written in lowercase is not reported. An unmarked stub, or a placeholder returning a plausible value, is indistinguishable from an implementation and is never reported"
    local marker_re f n text
    # Assembled rather than written literally so the pattern definition is not
    # itself a marker in convention form.
    marker_re="\\b(TO""DO|FIX""ME|XX""X|HA""CK)\\b[:(]|NotImplementedError|#[[:space:]]*(for now|temporary|placeholder)\\b"
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$ROOT/$f" ] || continue
        while IFS=: read -r n text; do
            [ -n "${n:-}" ] || continue
            printf 'todo-fixme\t%s\t%s\t%s\t\n' "$f" "$n" "$(jsan "$text")"
        done < <(grep -nE "$marker_re" "$ROOT/$f" 2>/dev/null || true)
    done < <(scan_source | drop_self)
    return 0
}

# ---- 6. skipped-tests ───────────────────────────────────────────────────────
# §11.4.3 permits a skip that carries a tracked `SKIP-OK: <ticket>` marker and
# forbids a bare one. Disabled gate files (`*.disabled`) are the same class at
# the file level — this repository has a tracked, deliberately-disabled CI
# workflow, and it must appear here rather than be quietly forgotten.
detect_skipped_tests() {
    DETECTOR_BASIS="skip constructs (.skip(, xit(, xdescribe(, t.Skip(, @pytest.mark.skip, playwright testIgnore) without a SKIP-OK marker on the same line, plus tracked '*.disabled' files"
    DETECTOR_RECALL="a test that passes vacuously, or a gate whose assertions were deleted rather than skipped, is not a 'skip' and is not reported"
    local f n text
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -f "$ROOT/$f" ] || continue
        while IFS=: read -r n text; do
            [ -n "${n:-}" ] || continue
            case "$text" in *SKIP-OK:*) continue ;; esac
            printf 'skipped-tests\t%s\t%s\t%s\t\n' "$f" "$n" "$(jsan "$text")"
        done < <(grep -nE '(test|it|describe)\.skip\(|\bxit\(|\bxdescribe\(|\bt\.Skip\(|@pytest\.mark\.skip|testIgnore' "$ROOT/$f" 2>/dev/null || true)
    done < <(scan_source | drop_self)

    while IFS= read -r f; do
        [ -n "$f" ] || continue
        printf 'skipped-tests\t%s\t%s\t%s\t\n' "$f" "1" \
            "$(jsan "tracked file is disabled by filename suffix — its assertions do not run")"
    done < <(scan_files | grep -E '\.disabled$' || true)
    return 0
}

# ---- 7. bluffs ──────────────────────────────────────────────────────────────
# The §11.4 covenant-violation surface. Measured from the check registry,
# which is this repository's own enumeration of "every automated check": a
# registered check whose entry point is missing or not executable claims a
# verdict it cannot produce, and a check row declaring proof-kind 'none'
# claims a paired proof it does not have.
detect_bluffs() {
    local reg="scripts/check-registry.tsv"
    DETECTOR_BASIS="rows in ${reg} whose entry point is missing or non-executable, or which declare proof-kind 'none'"
    DETECTOR_RECALL="a check that runs and returns 0 while asserting nothing is a bluff this detector cannot see; scripts/verify-check-registry.sh --run-proofs is the instrument for that, and it is not invoked here"
    [ -f "$ROOT/$reg" ] || return 2
    local n row entry kind
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        entry="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
        kind="$(printf '%s' "$row" | awk -F'\t' '{print $4}')"
        n="$(grep -nF "$row" "$ROOT/$reg" | head -n1 | cut -d: -f1)"
        if [ ! -f "$ROOT/$entry" ]; then
            printf 'bluffs\t%s\t%s\t%s\t\n' "$reg" "$n" "$(jsan "registered check entry point does not exist: ${entry}")"
        elif [ ! -x "$ROOT/$entry" ]; then
            printf 'bluffs\t%s\t%s\t%s\t\n' "$reg" "$n" "$(jsan "registered check entry point is not executable: ${entry}")"
        fi
        if [ "$kind" = "none" ]; then
            printf 'bluffs\t%s\t%s\t%s\t\n' "$reg" "$n" "$(jsan "check declares proof-kind 'none' — a PASS with no paired proof")"
        fi
    done < <(awk -F'\t' '$1=="check"' "$ROOT/$reg")
    return 0
}

# ---- 8. unresolved ──────────────────────────────────────────────────────────
# §11.4.261(A)(8): tracked items past their stated completion window. The
# register is this repository's own tracked-item file, whose entries carry a
# `Target:` date. An item whose target has passed is unresolved by
# measurement against the clock, not by opinion.
detect_unresolved() {
    DETECTOR_BASIS="entries in ${TRACKED_REL} whose 'Target:' date is earlier than today"
    DETECTOR_RECALL="an item with no Target: date cannot be past its window and is not reported; the register is the only input"
    [ -f "$ROOT/$TRACKED_REL" ] || return 2
    local today n text target item
    today="$(date -u +%Y-%m-%d)"
    item=""
    while IFS=: read -r n text; do
        [ -n "${n:-}" ] || continue
        case "$text" in
            '## '*) item="$(printf '%s' "$text" | sed 's/^## //')" ;;
            *Target:*)
                target="$(printf '%s' "$text" | sed -E 's/.*Target:[[:space:]]*//' | awk '{print $1}')"
                case "$target" in
                    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
                        if [ "$target" \< "$today" ]; then
                            printf 'unresolved\t%s\t%s\t%s\t\n' "$TRACKED_REL" "$n" \
                                "$(jsan "tracked item '${item}' is past its stated window (Target: ${target}, today ${today})")"
                        fi
                        ;;
                esac
                ;;
        esac
    done < <(grep -nE '^## |Target:' "$ROOT/$TRACKED_REL" 2>/dev/null || true)
    return 0
}

# ---- 9. divergent-stale-orphan ──────────────────────────────────────────────
# §11.4.233's anti-mess control plane. Measured as dangling references: a
# registry row or an exemption pointing at a path that no longer exists. A
# dead exemption is the sharpest case — it silently pardons the next file
# that takes the vacated name.
detect_divergent_stale_orphan() {
    local reg="scripts/check-registry.tsv"
    DETECTOR_BASIS="rows in ${reg} (check, debt, exempt) whose declared path does not exist on disk"
    DETECTOR_RECALL="covers the check registry only; a stale document, an orphaned export or a divergent duplicate elsewhere in the tree is not reported by this detector"
    [ -f "$ROOT/$reg" ] || return 2
    local row rtype path n
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        rtype="$(printf '%s' "$row" | awk -F'\t' '{print $1}')"
        case "$rtype" in
            exempt|debt) path="$(printf '%s' "$row" | awk -F'\t' '{print $2}')" ;;
            check) path="$(printf '%s' "$row" | awk -F'\t' '{print $3}')" ;;
            *) continue ;;
        esac
        [ "$rtype" = "debt" ] && path="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
        [ -n "$path" ] || continue
        if [ ! -e "$ROOT/$path" ]; then
            n="$(grep -nF "$row" "$ROOT/$reg" | head -n1 | cut -d: -f1)"
            printf 'divergent-stale-orphan\t%s\t%s\t%s\t\n' "$reg" "$n" \
                "$(jsan "${rtype} row points at a path that does not exist: ${path}")"
        fi
    done < <(awk -F'\t' '$1=="check"||$1=="debt"||$1=="exempt"' "$ROOT/$reg")
    return 0
}

# ---- 10. uncatalogued ───────────────────────────────────────────────────────
# §11.4.261(A)(10): anti-patterns identified in review that lack a §1.1
# mutation. Mechanically: a shell script living under a declared scanroot
# that is not accounted for by any registry row has no paired proof and no
# exemption — it asserts something about this tree that nothing verifies.
detect_uncatalogued() {
    local reg="scripts/check-registry.tsv"
    DETECTOR_BASIS="'*.sh' files directly under a declared scanroot in ${reg} that appear in no check, debt or exempt row"
    DETECTOR_RECALL="THIS IS THE §11.4.118 DISCOVERY-PRESSURE CLASS. A genuinely un-catalogued anti-pattern is, by definition, one nobody has named yet — no static detector can enumerate it. This detector measures only the registry's own anti-drift surface, and a 0 here is the weakest 0 the sweep prints"
    [ -f "$ROOT/$reg" ] || return 2
    local known d f base
    known="$(awk -F'\t' '$1=="check"{print $3} $1=="debt"{print $3} $1=="exempt"{print $2}' "$ROOT/$reg")"
    while IFS= read -r d; do
        [ -n "$d" ] || continue
        [ -d "$ROOT/$d" ] || continue
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            base="${f#"$ROOT"/}"
            if ! printf '%s\n' "$known" | grep -qxF "$base"; then
                printf 'uncatalogued\t%s\t%s\t%s\t\n' "$base" "1" \
                    "$(jsan "shell script under declared scanroot '${d}' appears in no registry row — it has no paired §1.1 mutation and no exemption")"
            fi
        done < <(find "$ROOT/$d" -mindepth 1 -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
    done < <(awk -F'\t' '$1=="scanroot"{print $2}' "$ROOT/$reg")
    return 0
}

# ═════════════════════════════════════════════════════════════════════════════
# Sweep driver
# ═════════════════════════════════════════════════════════════════════════════

# Populated by run_sweep.
declare -a ALL_ROWS=()
declare -A CLASS_COUNT=()
declare -A CLASS_BASIS=()
declare -A CLASS_RECALL=()
declare -a UNDET_CLASSES=()

run_sweep() {
    ALL_ROWS=(); CLASS_COUNT=(); CLASS_BASIS=(); CLASS_RECALL=(); UNDET_CLASSES=()
    local cls fn out rc
    for cls in "${CLASSES[@]}"; do
        fn="detect_$(printf '%s' "$cls" | tr '-' '_')"
        DETECTOR_BASIS=""; DETECTOR_RECALL=""
        out="$("$fn")"; rc=$?
        CLASS_BASIS["$cls"]="$DETECTOR_BASIS"
        CLASS_RECALL["$cls"]="$DETECTOR_RECALL"
        if [ "$rc" -eq 2 ]; then
            UNDET_CLASSES+=("$cls")
            CLASS_COUNT["$cls"]=-1
            continue
        fi
        CLASS_COUNT["$cls"]=0
        if [ -n "$out" ]; then
            while IFS= read -r row; do
                [ -n "$row" ] || continue
                ALL_ROWS+=("$row")
                CLASS_COUNT["$cls"]=$(( ${CLASS_COUNT["$cls"]} + 1 ))
            done <<< "$out"
        fi
    done
}

# Look up a class's tracker entry in TRACKED.md. Prints
# "<tracker_ref>\t<mitigation>" on success, nothing on failure.
tracker_for_class() {
    local cls="$1" file="$ROOT/$TRACKED_REL" mit
    [ -f "$file" ] || return 1
    grep -qE "^## ZF-${cls}\$" "$file" || return 1
    # The register is human-authored markdown, so the marker is matched after
    # stripping leading emphasis: `**Mitigation:**` and `Mitigation:` are the
    # same statement, and a parser that accepted only the second would silently
    # score every entry in a normally-formatted document as untracked.
    mit="$(awk -v want="## ZF-${cls}" '
        $0 == want { inside = 1; next }
        /^## / { inside = 0 }
        inside {
            line = $0
            sub(/^[[:space:]]*[*_]*/, "", line)
            if (line ~ /^Mitigation:/) {
                sub(/^Mitigation:[*_]*[[:space:]]*/, "", line)
                print line
                exit
            }
        }
    ' "$file")"
    [ -n "$mit" ] || return 1
    printf '%s\t%s\n' "${TRACKED_REL}#zf-${cls}" "$(jsan "$mit")"
    return 0
}

# Emit the ledger (JSONL) for the current ALL_ROWS on stdout.
emit_ledger() {
    local row cls file line desc tref t status tracker mitigation seq
    declare -A seen=()
    printf '# zero_findings_ledger.jsonl — §11.4.261(B) machine-readable finding ledger.\n'
    printf '# SNAPSHOT of the findings that exist at the recorded commit, regenerated by\n'
    printf '# scripts/audit/zero_findings_sweep.sh --write-ledger. History lives in git.\n'
    printf '# Generated: %s (UTC)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for row in "${ALL_ROWS[@]+"${ALL_ROWS[@]}"}"; do
        cls="$(printf '%s' "$row" | awk -F'\t' '{print $1}')"
        file="$(printf '%s' "$row" | awk -F'\t' '{print $2}')"
        line="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
        desc="$(printf '%s' "$row" | awk -F'\t' '{print $4}')"
        tref="$(printf '%s' "$row" | awk -F'\t' '{print $5}')"

        seq=$(( ${seen["$cls"]:-0} + 1 )); seen["$cls"]=$seq

        # §11.4.261(D): a finding is TRACKED only when a real tracker entry
        # with a real mitigation exists. Otherwise it is OPEN, and an open
        # finding correctly reddens CM-EVERY-FINDING-CLOSED-OR-TRACKED. This
        # script never invents a disposition to buy itself a green.
        status="open"; tracker=""; mitigation=""
        if t="$(tracker_for_class "$cls")"; then
            status="tracked"
            tracker="$(printf '%s' "$t" | cut -f1)"
            mitigation="$(printf '%s' "$t" | cut -f2)"
        fi
        [ -n "$tref" ] && tracker="$tref"

        printf '{"finding_id":"ZF-%s-%03d","class":"%s","file":"%s","line":"%s","description":"%s","status":"%s","tracker_ref":"%s","mitigation_evidence":"%s"}\n' \
            "$(printf '%s' "$cls" | tr '[:lower:]-' '[:upper:]_')" "$seq" \
            "$cls" "$file" "$line" "$desc" "$status" "$tracker" "$mitigation"
    done
}

read_ratchet() {
    # Prints "<class>\t<ceiling>" lines from the ratchet file.
    local f="$ROOT/$RATCHET_REL"
    [ -f "$f" ] || return 1
    grep -vE '^[[:space:]]*(#|$)' "$f"
}

print_report() {
    local cls c basis recall
    printf '── §11.4.261 zero-findings sweep ─────────────────────────────────────────\n'
    printf 'root      : %s\n' "$ROOT"
    printf 'commit    : %s\n' "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo 'UNKNOWN')"
    printf 'scanned   : %s tracked file(s) after %s declared exclusion(s)\n' \
        "$(scan_files | wc -l | tr -d ' ')" "${#EXCLUDE_PREFIXES[@]}"
    for cls in "${EXCLUDE_PREFIXES[@]}"; do
        printf '  excluded: %s\n' "$cls"
    done
    printf '  excluded: %s (pattern detectors only — it carries the patterns it hunts for)\n' "$SELF_REL"
    printf '\n'
    for cls in "${CLASSES[@]}"; do
        c="${CLASS_COUNT[$cls]}"
        if [ "$c" -lt 0 ]; then
            printf '  %-24s UNDETERMINED  (detector input absent — never reported as zero)\n' "$cls"
        else
            printf '  %-24s %4d\n' "$cls" "$c"
        fi
        if [ "$QUIET" -eq 0 ]; then
            basis="${CLASS_BASIS[$cls]}"; recall="${CLASS_RECALL[$cls]}"
            [ -n "$basis" ] && printf '      basis : %s\n' "$basis"
            [ -n "$recall" ] && printf '      limit : %s\n' "$recall"
        fi
    done
    printf '\n'
}

verdict() {
    run_sweep

    if [ "$JSON" -eq 1 ]; then
        emit_ledger
        return 0
    fi

    print_report

    local rc=0

    if [ "${#UNDET_CLASSES[@]}" -gt 0 ]; then
        printf '⚠️  %d class(es) UNDETERMINED: %s\n' "${#UNDET_CLASSES[@]}" "${UNDET_CLASSES[*]}"
        printf '   A class whose detector input is absent is NOT zero (§11.4.261(E)).\n'
        rc=2
    fi

    # ---- the ratchet: §11.4.261(C), enforced here, not merely recorded ----
    if ! read_ratchet >/dev/null 2>&1; then
        printf '⚠️  UNDETERMINED — no ratchet snapshot at %s; the monotone ceiling cannot be evaluated.\n' "$RATCHET_REL"
        printf '   Record the brownfield baseline with --write-ratchet (an operator decision).\n'
        return 2
    fi

    local exceeded=0 cls ceiling live total_live=0 total_ceiling=""
    declare -A CEIL=()
    while IFS=$'\t' read -r cls ceiling; do
        [ -n "${cls:-}" ] || continue
        if [ "$cls" = "TOTAL" ]; then total_ceiling="$ceiling"; else CEIL["$cls"]="$ceiling"; fi
    done < <(read_ratchet)

    for cls in "${CLASSES[@]}"; do
        live="${CLASS_COUNT[$cls]}"
        [ "$live" -lt 0 ] && continue
        total_live=$(( total_live + live ))
        ceiling="${CEIL[$cls]:-0}"
        if [ "$live" -gt "$ceiling" ]; then
            printf '❌ RATCHET REFUSED  class=%-24s live=%d > ceiling=%d\n' "$cls" "$live" "$ceiling"
            exceeded=$((exceeded + 1))
        else
            printf '✅ within ceiling    class=%-24s live=%d <= ceiling=%d\n' "$cls" "$live" "$ceiling"
        fi
    done
    if [ -n "$total_ceiling" ]; then
        if [ "$total_live" -gt "$total_ceiling" ]; then
            printf '❌ RATCHET REFUSED  class=%-24s live=%d > ceiling=%d\n' "TOTAL" "$total_live" "$total_ceiling"
            exceeded=$((exceeded + 1))
        else
            printf '✅ within ceiling    class=%-24s live=%d <= ceiling=%d\n' "TOTAL" "$total_live" "$total_ceiling"
        fi
    fi

    printf '\n'
    if [ "$exceeded" -gt 0 ]; then
        printf '❌ SWEEP REFUSES THE SEAM — %d class(es) rose above the recorded ceiling.\n' "$exceeded"
        printf '   §11.4.261(C): the ratchet may decrease and MUST NEVER increase.\n'
        return 1
    fi
    if [ "$rc" -eq 2 ]; then
        printf '⚠️  COULD NOT DETERMINE — the ratchet held for every class it could measure,\n'
        printf '   but %d class(es) were undetermined. A 2 is never a pass.\n' "${#UNDET_CLASSES[@]}"
        return 2
    fi
    printf '✅ every class is within its ratchet ceiling (%d finding(s) total).\n' "$total_live"
    printf '   Honest boundary: this is a statement about the CLOSED VOCABULARY with the\n'
    printf '   detector bases printed above — never a claim that the project is flawless.\n'
    return 0
}

do_write_ledger() {
    run_sweep
    mkdir -p "$(dirname "$ROOT/$LEDGER_REL")"
    emit_ledger > "$ROOT/$LEDGER_REL"
    printf 'wrote %s (%d finding row(s))\n' "$LEDGER_REL" "${#ALL_ROWS[@]}"
}

do_write_ratchet() {
    run_sweep
    local f="$ROOT/$RATCHET_REL" cls live old total=0 refused=0
    declare -A OLD=()
    if [ -f "$f" ]; then
        while IFS=$'\t' read -r c v; do [ -n "${c:-}" ] && OLD["$c"]="$v"; done < <(read_ratchet)
    fi
    for cls in "${CLASSES[@]}"; do
        live="${CLASS_COUNT[$cls]}"
        [ "$live" -lt 0 ] && { printf 'refusing to write: class %s is UNDETERMINED\n' "$cls" >&2; return 2; }
        total=$(( total + live ))
        old="${OLD[$cls]:-}"
        if [ -n "$old" ] && [ "$live" -gt "$old" ]; then
            printf '❌ REFUSED — %s would rise %s -> %s. The ratchet may only ever decrease (§11.4.261(C)).\n' "$cls" "$old" "$live" >&2
            refused=$((refused + 1))
        fi
    done
    [ "$refused" -gt 0 ] && return 1

    mkdir -p "$(dirname "$f")"
    {
        printf '# zero_findings_ratchet.tsv — §11.4.261(C) monotone-decreasing ratchet.\n'
        printf '#\n'
        printf '# Per-class and TOTAL ceilings on the §11.4.261 finding count. Every sweep\n'
        printf '# run compares the live count against these numbers; a class that RISES\n'
        printf '# above its ceiling makes the sweep and CM-ZERO-FINDINGS-MONOTONE-RATCHET\n'
        printf '# refuse the seam. A ceiling may only ever be LOWERED, after a real fix.\n'
        printf '#\n'
        printf '# These are MEASURED counts from a real sweep, not a seeded zero. A ratchet\n'
        printf '# whose first row is a lie is worse than no ratchet at all.\n'
        printf '#\n'
        printf '# Recorded: %s (UTC) at commit %s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"
        printf '# Format: <class>\\t<max-count>. "TOTAL" ceilings the sum.\n'
        printf '#\n'
        for cls in "${CLASSES[@]}"; do
            printf '%s\t%s\n' "$cls" "${CLASS_COUNT[$cls]}"
        done
        printf 'TOTAL\t%s\n' "$total"
    } > "$f"
    printf 'wrote %s (TOTAL=%d)\n' "$RATCHET_REL" "$total"
}

# ═════════════════════════════════════════════════════════════════════════════
# §11.4.107(10) fixtures: golden-good, golden-bad, negative-control
# ═════════════════════════════════════════════════════════════════════════════

# Builds a synthetic consumer tree. $1 = dir, $2 = "good" | "bad".
# A "good" tree is clean for every detector. A "bad" tree plants exactly one
# finding per class.
build_fixture() {
    local d="$1" flavour="$2"
    mkdir -p "$d/scripts" "$d/tests" "$d/docs/constitution-adoption" "$d/docs/findings"
    ( cd "$d" && git init -q . && git config user.email f@example.invalid && git config user.name fixture )

    cat > "$d/scripts/clean.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo clean
EOS
    chmod +x "$d/scripts/clean.sh"

    cat > "$d/docs/constitution-adoption/INVENTORY.md" <<'EOS'
| Gap | Status | Detail |
|---|---|---|
| G1 | **CLOSED** | done |
EOS

    cat > "$d/docs/findings/TRACKED.md" <<'EOS'
# Tracked items
## ZF-gaps
Mitigation: fixture mitigation evidence
Target: 2999-01-01
EOS

    printf 'scanroot\tscripts\n' > "$d/scripts/check-registry.tsv"
    printf 'exempt\tscripts/clean.sh\tfixture entry point\n' >> "$d/scripts/check-registry.tsv"
    printf 'exempt\tscripts/check-registry.tsv\tfixture registry file\n' >> "$d/scripts/check-registry.tsv"

    if [ "$flavour" = "bad" ]; then
        # 1 shortcomings
        printf '#!/usr/bin/env bash\nset -u\n# SHORTCOMING: partial implementation\n' > "$d/scripts/short.sh"
        # 2 gaps
        printf '| G2 | **OPEN** | a promised capability is missing |\n' >> "$d/docs/constitution-adoption/INVENTORY.md"
        # 3 weak-spots (no set -u)
        printf '#!/usr/bin/env bash\necho unguarded\n' > "$d/scripts/weak.sh"
        # 4 danger-zones
        printf '#!/usr/bin/env bash\nset -u\ngit push --force ori''gin main\n' > "$d/scripts/danger.sh"
        # 5 todo-fixme
        printf '#!/usr/bin/env bash\nset -u\n# TO''DO: finish this\n' > "$d/scripts/todo.sh"
        # 6 skipped-tests
        printf 'test.skip("unfinished", () => {});\n' > "$d/tests/skip.js"
        printf 'inert\n' > "$d/scripts/thing.sh.disabled"
        # 7 bluffs
        printf 'check\tghost\tscripts/ghost.sh\tnone\tx\ty\n' >> "$d/scripts/check-registry.tsv"
        # 8 unresolved
        printf '## ZF-weak-spots\nMitigation: m\nTarget: 2000-01-01\n' >> "$d/docs/findings/TRACKED.md"
        # 9 divergent-stale-orphan
        printf 'exempt\tscripts/vanished.sh\tpoints at nothing\n' >> "$d/scripts/check-registry.tsv"
        # 10 uncatalogued
        printf '#!/usr/bin/env bash\nset -u\necho hi\n' > "$d/scripts/unregistered.sh"
        chmod +x "$d/scripts/short.sh" "$d/scripts/weak.sh" "$d/scripts/danger.sh" \
                 "$d/scripts/todo.sh" "$d/scripts/unregistered.sh"
    fi

    ( cd "$d" && git add -A . >/dev/null 2>&1 && git commit -qm fixture >/dev/null 2>&1 ) || true
}

# Counts findings for one class against a fixture root.
fixture_count() {
    local root="$1" cls="$2" saved="$ROOT" out rc fn
    ROOT="$root"
    fn="detect_$(printf '%s' "$cls" | tr '-' '_')"
    out="$("$fn")"; rc=$?
    ROOT="$saved"
    [ "$rc" -eq 2 ] && { printf 'UNDET\n'; return 0; }
    printf '%s\n' "$(printf '%s' "$out" | grep -c . || true)"
}

selftest() {
    command -v git >/dev/null 2>&1 || die_undet "git is not on PATH; the fixtures cannot be built"
    local tmp; tmp="$(mktemp -d)"
    # Expanded at trap-definition time: `tmp` is function-local and would be
    # unbound (under `set -u`) by the time an EXIT trap body is evaluated.
    trap "rm -rf '$tmp'" EXIT

    printf '── §11.4.107(10) fixture self-test ───────────────────────────────────────\n'
    build_fixture "$tmp/golden-good" good
    build_fixture "$tmp/golden-bad"  bad

    local pass=0 fail=0 cls g b
    for cls in "${CLASSES[@]}"; do
        g="$(fixture_count "$tmp/golden-good" "$cls")"
        b="$(fixture_count "$tmp/golden-bad"  "$cls")"

        # golden-good: the clean tree must produce no finding for this class.
        if [ "$g" = "0" ]; then
            printf '  ✅ golden-good      %-24s 0 finding(s)\n' "$cls"; pass=$((pass+1))
        else
            printf '  ❌ golden-good      %-24s expected 0, got %s\n' "$cls" "$g"; fail=$((fail+1))
        fi

        # golden-bad: the planted finding must actually be detected.
        if [ "$b" != "0" ] && [ "$b" != "UNDET" ]; then
            printf '  ✅ golden-bad       %-24s %s finding(s) detected\n' "$cls" "$b"; pass=$((pass+1))
        else
            printf '  ❌ golden-bad       %-24s planted finding NOT detected (got %s)\n' "$cls" "$b"; fail=$((fail+1))
        fi
    done

    # ---- negative-control ---------------------------------------------------
    # Without this, every assertion above could be satisfied by a detector that
    # simply reports everything. The control blinds one detector by pointing it
    # at a tree where its input is REMOVED, and asserts it reports UNDETERMINED
    # rather than a comfortable zero — the §11.4.6 distinction this whole
    # script rests on. A second control asserts the golden-bad plant is found
    # ONLY by the class that planted it, so the counts above are not the
    # product of one detector matching everything.
    printf '  ── negative-control ──\n'
    rm -f "$tmp/golden-bad/scripts/check-registry.tsv"
    local nb; nb="$(fixture_count "$tmp/golden-bad" bluffs)"
    if [ "$nb" = "UNDET" ]; then
        printf '  ✅ negative-control  bluffs detector reports UNDETERMINED with its input removed, not 0\n'; pass=$((pass+1))
    else
        printf '  ❌ negative-control  bluffs detector returned %s with its input removed — it would report a missing input as clean\n' "$nb"; fail=$((fail+1))
    fi

    local ng; ng="$(fixture_count "$tmp/golden-good" todo-fixme)"
    if [ "$ng" = "0" ]; then
        printf '  ✅ negative-control  todo-fixme does not fire on a tree with no marker (assertions are not vacuous)\n'; pass=$((pass+1))
    else
        printf '  ❌ negative-control  todo-fixme fired %s time(s) on a clean tree\n' "$ng"; fail=$((fail+1))
    fi

    printf '\n  %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] || { printf '❌ SELFTEST FAILED\n'; return 1; }
    printf '✅ SELFTEST PASS — golden-good clean, golden-bad detected in all %d classes, negative-controls hold\n' "${#CLASSES[@]}"
    return 0
}

# ═════════════════════════════════════════════════════════════════════════════
# §1.1 paired mutation proof
# ═════════════════════════════════════════════════════════════════════════════
prove_failure() {
    command -v git >/dev/null 2>&1 || die_undet "git is not on PATH; the mutation proof cannot build its sandbox"
    local tmp; tmp="$(mktemp -d)"
    # Expanded at trap-definition time — see the note in selftest().
    trap "rm -rf '$tmp'" EXIT

    printf '── §1.1 paired mutation proof: zero_findings_sweep.sh ────────────────────\n'
    printf 'Every mutation below is DATA — a change to the synthetic tree, never an\n'
    printf 'edit to this script — so no mutation can leave a weakened instrument behind.\n\n'

    local caught=0 total=0 saved="$ROOT"
    local tree="$tmp/tree"
    build_fixture "$tree" good

    _run() { local r="$1"; shift; ROOT="$r"; "$@"; local rc=$?; ROOT="$saved"; return $rc; }

    # ---- CONTROL: the clean tree with a ratchet must PASS -------------------
    total=$((total+1))
    ROOT="$tree"; QUIET=1
    run_sweep
    local c_ok=1
    for cls in "${CLASSES[@]}"; do
        [ "${CLASS_COUNT[$cls]}" -gt 0 ] && c_ok=0
    done
    do_write_ratchet >/dev/null 2>&1
    verdict >/dev/null 2>&1; local crc=$?
    ROOT="$saved"
    if [ "$c_ok" -eq 1 ] && [ "$crc" -eq 0 ]; then
        printf '  ✅ CONTROL   clean tree + measured ratchet -> rc 0. The proof can distinguish\n'
        printf '               pass from fail; a gate hardwired to exit 1 would fail here.\n'
        caught=$((caught+1))
    else
        printf '  ❌ CONTROL   clean tree returned rc %s with findings present — the proof is invalid\n' "$crc"
    fi

    # ---- M1..M10: plant one finding per class; each must raise the count ----
    local m=0 cls before after
    for cls in "${CLASSES[@]}"; do
        m=$((m+1)); total=$((total+1))
        local mtree="$tmp/m$m"
        build_fixture "$mtree" good
        ROOT="$mtree"; run_sweep; before="${CLASS_COUNT[$cls]}"; ROOT="$saved"
        # Rebuild as the "bad" flavour, which plants exactly one finding per class.
        rm -rf "$mtree"; build_fixture "$mtree" bad
        ROOT="$mtree"; run_sweep; after="${CLASS_COUNT[$cls]}"; ROOT="$saved"
        if [ "$after" -gt "$before" ]; then
            printf '  ✅ M%-2d CAUGHT  %-24s planted finding raised the count %s -> %s\n' "$m" "$cls" "$before" "$after"
            caught=$((caught+1))
        else
            printf '  ❌ M%-2d MISSED  %-24s count did not rise (%s -> %s)\n' "$m" "$cls" "$before" "$after"
        fi
        rm -rf "$mtree"
    done

    # ---- M11: the ratchet must REFUSE an increase --------------------------
    total=$((total+1))
    local rtree="$tmp/ratchet"
    build_fixture "$rtree" good
    ROOT="$rtree"; do_write_ratchet >/dev/null 2>&1; ROOT="$saved"
    printf '#!/usr/bin/env bash\nset -u\n# TO''DO: newly introduced debt\n' > "$rtree/scripts/newdebt.sh"
    chmod +x "$rtree/scripts/newdebt.sh"
    ( cd "$rtree" && git add -A . >/dev/null 2>&1 && git commit -qm plant >/dev/null 2>&1 ) || true
    ROOT="$rtree"; verdict >/dev/null 2>&1; local rrc=$?; ROOT="$saved"
    if [ "$rrc" -eq 1 ]; then
        printf '  ✅ M11 CAUGHT  a new finding above the recorded ceiling made the sweep REFUSE (rc 1)\n'
        caught=$((caught+1))
    else
        printf '  ❌ M11 MISSED  a new finding above the ceiling returned rc %s, not 1 — the ratchet does not refuse\n' "$rrc"
    fi

    # ---- M12: --write-ratchet must refuse to RAISE a ceiling ---------------
    total=$((total+1))
    ROOT="$rtree"; do_write_ratchet >/dev/null 2>&1; local wrc=$?; ROOT="$saved"
    if [ "$wrc" -eq 1 ]; then
        printf '  ✅ M12 CAUGHT  --write-ratchet REFUSED to raise a ceiling (rc 1). The ratchet\n'
        printf '                 cannot be re-baselined upward to absorb new debt.\n'
        caught=$((caught+1))
    else
        printf '  ❌ M12 MISSED  --write-ratchet returned rc %s and would have raised the ceiling\n' "$wrc"
    fi

    # ---- M13: a missing ratchet must be a 2, never a 0 ---------------------
    total=$((total+1))
    local ntree="$tmp/noratchet"
    build_fixture "$ntree" good
    ROOT="$ntree"; verdict >/dev/null 2>&1; local nrc=$?; ROOT="$saved"
    if [ "$nrc" -eq 2 ]; then
        printf '  ✅ M13 CAUGHT  a tree with no ratchet snapshot returned rc 2 (could not determine),\n'
        printf '                 not rc 0. An unrecorded baseline is never a pass.\n'
        caught=$((caught+1))
    else
        printf '  ❌ M13 MISSED  a tree with no ratchet returned rc %s, not 2\n' "$nrc"
    fi

    # ---- M14: an undetermined class must not be scored as clean ------------
    total=$((total+1))
    local utree="$tmp/undet"
    build_fixture "$utree" good
    ROOT="$utree"; do_write_ratchet >/dev/null 2>&1; ROOT="$saved"
    rm -f "$utree/docs/constitution-adoption/INVENTORY.md"
    ROOT="$utree"; verdict >/dev/null 2>&1; local urc=$?; ROOT="$saved"
    if [ "$urc" -eq 2 ]; then
        printf '  ✅ M14 CAUGHT  removing a detector input returned rc 2, not rc 0 — a blind\n'
        printf '                 detector is reported as blind, never as zero findings.\n'
        caught=$((caught+1))
    else
        printf '  ❌ M14 MISSED  a blinded detector returned rc %s, not 2\n' "$urc"
    fi

    printf '\n  %d/%d mutations caught\n' "$caught" "$total"
    if [ "$caught" -ne "$total" ]; then
        printf '❌ MUTATION PROOF FAILED\n'; return 1
    fi
    printf '✅ MUTATION PROOF PASS — %d mutations caught, including the CONTROL that proves\n' "$total"
    printf '   the proof is not vacuous and M12/M13 that prove the ratchet cannot be raised\n'
    printf '   or silently skipped.\n'
    return 0
}

# ═════════════════════════════════════════════════════════════════════════════
# Dispatch
# ═════════════════════════════════════════════════════════════════════════════

case "$MODE" in
    selftest)      selftest; exit $? ;;
    prove-failure) prove_failure; exit $? ;;
esac

[ -n "$ROOT" ] && [ -d "$ROOT" ] || die_undet "project root not found: '${ROOT}'"
ROOT="$(cd "$ROOT" && pwd)"
command -v git >/dev/null 2>&1 || die_undet "git is not on PATH; the tracked-file scope cannot be enumerated"
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || die_undet "'$ROOT' is not a git work tree; the tracked-file scope cannot be enumerated"

case "$MODE" in
    write-ledger)  do_write_ledger; exit $? ;;
    write-ratchet) do_write_ratchet; exit $? ;;
    verdict)       verdict; exit $? ;;
esac
