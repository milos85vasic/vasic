#!/usr/bin/env bash
# zero-gap-coverage.sh — coverage-map GENERATOR (feature 010, task T052).
#
# WHAT IT DOES
#   Writes docs/zero-gap/coverage.tsv, one row `subject<TAB>test_kind<TAB>status<TAB>ref` per
#   (subject x test kind) cell, status in {check, n/a, gap, could-not-run}. This is the
#   GENERATOR the sweep class scripts/zero-gap-class-coverage-gaps.sh (T032) reads; that class's
#   REQ_KINDS constant and this script's KINDS list are, by design, THE SAME twelve ids — the
#   source is spec.md User Story 3 / FR-010 (unit integration e2e contract security accessibility
#   perf-load stress-chaos mutation determinism regression manual-qa-readiness). No extra kind is
#   emitted: none of the D10-proposed extras (content-boundary, claim-ledger, ...) has a defect
#   class that needs one yet (FR-010's own trigger for adding one).
#
# STATUS VOCABULARY (T061 review, 2026-10-12; closed, enforced by scripts/zero-gap-class-coverage-gaps.sh)
#   check          cases>0 AND failed==0 AND rc==0, evidence bound to its row
#   check-red      cases>0 but a case failed or rc!=0: applied, NOT proven, NOT coverage (FR-010/FR-011/SC-005)
#   designed-red   as check-red, but (subject, kind) is declared in docs/zero-gap/designed-red.tsv and the
#                  measured rc EQUALS the declared expected_rc (a declaration excuses only the failure it names)
#   gap[:note]     zero cases, no test, `gap:evidence-mismatch` (evidence header does not bind to the row, the head is
#                  all-zero/malformed/unknown/not an ancestor of HEAD) or `gap:evidence-stale` (measured head is
#                  more than --max-behind commits behind HEAD)
#   could-not-run:<tool>   n/a:<reason>
#                  could-not-run:go-build:<cause> = the measurer's ENVIRONMENT could not build a Go package
#                  (goproxy-off | missing-replace-dir | missing-module); never used when a real test failed
#   Every gap*, check-red and could-not-run cell is also written, by this generator only, to the DERIVED
#   file <out-dir>/cycle-2-candidates.tsv (subject, test_kind, status, reason, ref): cycle-2 intake, because
#   the register is frozen at cycle 1 (T038). It adds no register row and reopens no frozen item.
#   NOTE (counting): a subject listed in docs/zero-gap/duplicate-subjects.tsv (duplicate, of, reason) is the same
#   code as another subject under a second gitlink (submodules/llm_provider = submodules/LLMProvider). Both rows
#   stay in coverage.tsv; the totals printed by this generator give the RAW count and the DE-DUPLICATED count.
#   A declaration is honoured only while both checked-out HEADs are the identical commit; otherwise it is
#   refused loudly and nothing is de-duplicated.
#
# EVIDENCE BINDING AND FRESHNESS (T061 round 2, finding F1)
#   A `check` / `check-red` cell rests on a measured row (coverage-measured.tsv: ... evidence cmd head tree) and an
#   evidence file whose header carries `head= tree= ts= limit=`. The generator requires: head is 40 hex and not
#   all zeros; tree is 64 hex and not all zeros; the header's head/tree EQUAL the TSV row's; the head resolves to a
#   commit in this repository's object store; and that commit is HEAD or an ancestor of HEAD. Any failure =>
#   `gap:evidence-mismatch: <fields>`. Allowance: by default ANY ancestor is accepted and the row reports how many
#   commits behind HEAD it was measured; `--max-behind N` (or ZERO_GAP_COVERAGE_MAX_BEHIND=N) makes a head more than
#   N commits behind `gap:evidence-stale`. HONEST LIMIT: `tree` is sha256(head + `git status --porcelain`) at
#   measurement time and the dirty tree is not reproducible afterwards, so it is bound only for presence, non-zero
#   and TSV/header agreement; an actor who rewrites BOTH files consistently with a different REAL ancestor head
#   cannot be told apart from a measurement taken there (an unsigned evidence file proves no more than that).
#
# SUBJECTS — DERIVED, NEVER HAND-LISTED
#   "root" (the umbrella project itself) + every OWNED submodule that is checked out. "Owned" is
#   computed EXACTLY like verify-governance-cascade.sh's C1 and like the sibling class
#   scripts/zero-gap-class-doc-count-drift.sh already does (that class's own header: "derived
#   exactly like verify-governance-cascade.sh C1"): a `.gitmodules` submodule whose URL namespace
#   (host/owner) hosts >= 2 declared submodules, OR is the namespace of a helix-deps.yaml
#   `ssh_url`, EXCLUDING the governance source (the submodule carrying
#   scripts/gates/lib/pointer_carrier.sh) and third-party (submodules/superspec: one declared
#   submodule in its namespace, absent from helix-deps.yaml). This is the SAME algorithm text as
#   doc-count-drift.sh's `gitmodules()`/`namespace()` Python functions — reused verbatim (cited),
#   not reinvented, because it is this repository's established, non-hand-listed ownership rule.
#   A module declared but not checked out (directory absent, or present but not a real git work
#   tree rooted there) is EXCLUDED from the subject set, same as doc-count-drift.sh's `present`
#   filter — there is nothing there to test.
#
# STATUS DETERMINATION — REAL EVIDENCE ONLY, NEVER A GUESS
#   Every `check` cell below is backed by an ACTUAL EXECUTION performed by THIS run, not by a
#   name match, a file's mere existence, or a stale claim:
#     root / unit                 `cd _tools/gen && go test ./... -v` (the umbrella's own
#                                  documented canonical Go entry point, CLAUDE.md "Build and test
#                                  entry points": `cd _tools/gen && go test ./...`). Pass count =
#                                  `grep -c '^--- PASS:'` of `go test -v` output.
#     root / mutation              `bash scripts/verify-mutation-anchors.sh --prove-failure`
#                                  (registered check id `mutation-anchor-rot`), case count parsed
#                                  from its own "N assertions" / "N mutation(s) caught" report.
#     root / security               `bash scripts/verify-pretooluse-guard.sh --prove-failure`
#                                  (registered check id `pretooluse-guard`), case count parsed
#                                  from its own "N passed / M failed / K cases" report; a nonzero
#                                  `failed` or a nonzero exit still counts as evidence executed,
#                                  but a proof that itself cannot run (nonzero rc from the proof
#                                  process) is NOT trusted as evidence this run (falls to gap).
#     root / manual-qa-readiness   `git ls-files -- docs/qa` at --root is non-empty — §11.4.83's
#                                  own docs/qa/ convention IS the manual-QA-readiness artifact;
#                                  presence of a tracked, non-empty file is the evidence (no case
#                                  count applies to a documentation artifact — see the honest-limits
#                                  note below). Module subjects do NOT get this treatment — see
#                                  "WHY EVERY OTHER CELL IS gap" below: their docs/qa/ evidence is
#                                  real but its ref would sit inside a submodule, which the
#                                  coverage-gaps class's live-mode ref resolution cannot verify.
#   PASS-COUNT ZERO RULE (FR-011, reuse of the check-registry meta-check's own "hollow proof"
#   test — scripts/verify-check-registry.sh's --run-proofs uses
#   `grep -qE '(^|[^A-Za-z])M[0-9]|[0-9]+[[:space:]]+(mutation|mutations|drift|drifts|caught|passed)'`
#   to refuse crediting a proof that "exited 0 but reported no mutation results"; this generator's
#   `decide_status()` applies the SAME rule generically — a resolved evidence source whose parsed
#   case count is 0 (or whose count cannot be parsed at all) NEVER becomes `check`; it becomes
#   `gap`. This is deliberately the SAME logic class as `vacuous-gates`' zero-fail-pass detector
#   (a verdict reached over zero executed cases is not a pass) — reused by APPLYING IT, at the
#   point where THIS generator's own evidence is parsed, rather than re-implementing
#   vacuous-gates' static source-scan (that class reads OTHER scripts' source; this generator
#   reads the ACTUAL RUNTIME OUTPUT of the checks it invokes — the same principle, the applicable
#   instrument for what is actually available here).
#   MISSING-TOOL RULE: when the tool a mapped evidence source needs (currently: `go`, for
#   root/unit) is absent from PATH, the cell becomes `could-not-run:<tool>` — never silently
#   skipped, never `n/a`. `bash` is not probed (POSIX baseline, every entry point in this
#   repository already assumes it).
#   REF-RESOLUTION BOUNDARY (found by actually running the consumer class against this
#   generator's own output, this session): scripts/zero-gap-class-coverage-gaps.sh resolves a
#   `check` cell's tracked-file ref with `git -C <root> ls-files` in LIVE mode — which, because a
#   submodule is a gitlink, NEVER lists a path INSIDE an owned submodule. An earlier revision of
#   this generator cited `<module>/docs/qa/<file>` as evidence for three modules that genuinely
#   have real docs/qa/ content (challenges, llms_verifier, workshop) and the consumer class
#   correctly flagged all three `high false-evidence` — the ref was real but unverifiable from
#   root. Fixed by NOT claiming that cell for module subjects (root/manual-qa-readiness only,
#   above) rather than by working around the class's ref check.
#
# WHY EVERY OTHER CELL IS `gap`, NOT FABRICATED — MEASURED, NOT ASSUMED
#   FR-010/FR-011 forbid crediting a cell without a REAL recorded run. Root has no registered
#   check for unit/integration/e2e/contract/accessibility/perf-load/stress-chaos/determinism/
#   regression beyond the three named above (verified: `awk -F'\t' '$1=="check"{print $2}'
#   scripts/check-registry.tsv` has no id whose name is one of those kinds — only
#   `mutation-anchor-rot` and `pretooluse-guard` match). Owned SUBMODULES were investigated for a
#   safe, fast, real per-kind evidence source (many DO carry a `tests/{unit,integration,e2e,
#   security,stress,chaos,benchmark,performance}/` convention with `//go:build <kind>`-tagged Go
#   suites — see research.md D10's own seed). Running them was ATTEMPTED and MEASURED, this
#   session, on this host: `cd submodules/qa && go test -short ./...` fails outright ("go: -mod
#   may only be set to readonly or vendor when in workspace mode" / `GOPROXY=off` build errors
#   for unresolved deps in some packages), and `cd submodules/challenges && go test -short ./...`
#   did not return inside 30s (terminated). A module-wide `go test ./...` pulls in EVERY package
#   under the module root, including unrelated command binaries with their own (sometimes
#   network-requiring) dependency graphs — not a safe or bounded operation to run unconditionally
#   from a generator. Reporting these cells `gap` is therefore the HONEST outcome of a measured
#   attempt, not a shortcut: there is no fast, safe, bounded, offline way for THIS generator to
#   obtain a real per-module per-kind case count today. Closing them for real (a narrower,
#   per-directory, per-tag invocation with its own timeout and dependency isolation) is exactly
#   the kind of work spec.md assigns to **T053** ("Re-measure every cell of the seed matrix from
#   research D10 with real runs ... and write the true map") — a SEPARATE task from this one. This
#   generator's job is the MECHANISM and its own decision logic, proven by --prove-failure; T053
#   re-runs it as ground truth accumulates.
#
# HONEST LIMITS (§11.4.6)
#   - manual-qa-readiness has no "case count": file PRESENCE is the evidence for a documentation
#     artifact, which is what the kind actually asks for (readiness DOCUMENTATION, not an
#     executable suite). A present-but-empty docs/qa/ (zero tracked files) is `gap`.
#   - `n/a` is never emitted by this generator: this repository has, as measured, no subject for
#     which a required kind is KNOWN not to apply (a declared not-applicable reason is an
#     operator/reviewer judgement call this generator does not make for itself).
#   - The umbrella "root" subject's non-Go, non-registry kinds (e2e, contract, accessibility,
#     perf-load, stress-chaos, integration, determinism, regression) are real Playwright / gate
#     infrastructure that EXISTS (CLAUDE.md "Build and test entry points", "Live-production test
#     coverage") but is not wired to a fast, bounded, offline entry point this generator can run
#     safely on every invocation (Playwright needs a built site + browsers; zero-gap-determinism.sh
#     and zero-gap-sweep.sh each do a full ~14 GB rsync copy of the tree per run, measured this
#     session at > 90 s each with --prove-failure alone) — `gap`, honestly, not `could-not-run`
#     (the tools ARE present; running them here is unsafe/slow, which is a different fact).
#
# USAGE
#   zero-gap-coverage.sh [--root <dir>] [--out <file>] [--max-behind N]
#                                                         generate (default root: this repository,
#                                                         default out: <root>/docs/zero-gap/coverage.tsv)
#   zero-gap-coverage.sh --prove-failure                 paired proof (§1.1)
#   zero-gap-coverage.sh --help
# Exit: 0 generated, 2 could not generate (bad --root, missing required tool, write failure).
#       --prove-failure: 0 every case passed, 1 a case failed.
set -uo pipefail
export LC_ALL=C PYTHONDONTWRITEBYTECODE=1

SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
KINDS="unit integration e2e contract security accessibility perf-load stress-chaos mutation determinism regression manual-qa-readiness"

usage() {
    cat <<'EOF'
zero-gap-coverage.sh [--root <dir>] [--out <file>] [--max-behind N] [--allow-dirty-evidence]
zero-gap-coverage.sh --prove-failure
zero-gap-coverage.sh --help
EOF
}

ROOT="" OUT="" PROVE=0 HELP=0 MAX_BEHIND="${ZERO_GAP_COVERAGE_MAX_BEHIND:-}" ALLOW_DIRTY="${ZERO_GAP_COVERAGE_ALLOW_DIRTY:-0}"
while [ $# -gt 0 ]; do
    case "$1" in
        --max-behind) MAX_BEHIND="${2:-}"; shift 2 ;;
        --allow-dirty-evidence) ALLOW_DIRTY=1; shift ;;
        --root) ROOT="${2:-}"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        --help) HELP=1; shift ;;
        *) echo "zero-gap-coverage: unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ "$HELP" -eq 1 ] && { usage; exit 0; }
case "$MAX_BEHIND" in ''|*[!0-9]*) [ -z "$MAX_BEHIND" ] || { echo "zero-gap-coverage: --max-behind must be a non-negative integer" >&2; exit 2; } ;; esac

need() { local t; for t in "$@"; do command -v "$t" >/dev/null 2>&1 || { echo "zero-gap-coverage: required tool missing: $t" >&2; exit 2; }; done; }

# ── decide_status <count> <tool-available:0|1> <tool-name> <ref> ────────────────────────────
# The generic evidence-to-status rule (FR-011 zero-case rule + missing-tool rule), shared by
# every kind mapping below and independently unit-tested by --prove-failure. Prints one line
# "<status>\t<ref>".
decide_status() {
    local count="$1" avail="$2" tool="$3" ref="$4"
    if [ "$avail" -eq 0 ]; then printf 'could-not-run:%s\t%s\n' "$tool" "$tool"; return; fi
    if ! [ "$count" -gt 0 ] 2>/dev/null; then printf 'gap\t%s\n' "-"; return; fi
    printf 'check\t%s\n' "$ref"
}

# parse_count <pattern-kind> <text>: extracts a case count from a proof's own report, using the
# SAME token vocabulary scripts/verify-check-registry.sh's --run-proofs hollow-proof detector
# already looks for (mutation|mutations|caught|passed|assertions), reused rather than reinvented.
# SPECIFICITY (T052 review IMPORTANT fix): a bare "digit + trigger word anywhere in the text"
# match is not enough — "N mutations attempted" / "N assertions planned" / "expected N
# assertions" name a count that was never actually ACHIEVED, and the old regex credited
# whichever such phrase happened to appear first, even ahead of the real result. This version
# scans word-by-word, left to right, and:
#   - a number DIRECTLY adjacent to `caught` or `passed` (the words that denote an actual
#     positive result) is trusted immediately;
#   - a number adjacent to `assertion(s)`/`mutation(s)` alone is trusted ONLY when neither the
#     word immediately preceding the number nor the word immediately following the trigger is
#     `attempted`/`planned`/`expected` (the vocabulary of a count that was NOT achieved); a
#     candidate that fails this check is skipped and the scan continues rightward, so a real
#     result later in the same line (e.g. "5 mutations planned, 0 caught") is still found.
# Prints the first surviving matched integer in reading order, or nothing when no candidate
# survives (which feeds decide_status's zero/unparseable rule => gap, never a fabricated check).
parse_count() {
    printf '%s\n' "$2" | awk '
    {
        for (i = 1; i <= NF; i++) {
            tok = $i
            if (tok !~ /^[0-9]+([^0-9A-Za-z].*)?$/) continue
            if (i == NF) continue
            match(tok, /^[0-9]+/)
            num = substr(tok, RSTART, RLENGTH)
            nxt = $(i + 1); gsub(/[^A-Za-z]/, "", nxt); nxt = tolower(nxt)
            if (nxt == "caught" || nxt == "passed") { print num; exit }
            if (nxt == "assertion" || nxt == "assertions" || nxt == "mutation" || nxt == "mutations") {
                before = ""
                if (i > 1) { before = $(i - 1); gsub(/[^A-Za-z]/, "", before); before = tolower(before) }
                after = ""
                if (i + 2 <= NF) { after = $(i + 2); gsub(/[^A-Za-z]/, "", after); after = tolower(after) }
                if (before == "expected" || after == "attempted" || after == "planned" || after == "expected") continue
                print num; exit
            }
        }
    }'
}


# ── evidence_mismatch <file> <subj> <kind> <status> <cases> <failed> <rc> <tsv-head> <tsv-tree> <tsv-evsha> <tsv-dirty> <root>
#    prints a comma list of the fields that do NOT bind the evidence file to its TSV row (empty output = bound). The
#    evidence file written by scripts/zero-gap-coverage-measure.py carries `subject= kind= status= cases= failed= rc=`
#    on line 1 and `head= tree= ts= limit= dirty= dirtydigest=` on line 2. Required (T061 rounds 2-3):
#      * every line-1 field EQUALS the TSV row's, status included (a TSV-only relabel, in either direction, is refused);
#      * head/tree non-zero, equal to the TSV's, and head a commit of <root> that is HEAD or an ancestor of HEAD;
#      * the sha256 of the SEALED region (everything after line 1) EQUALS the TSV `evsha` column: a replaced body, or an
#        edited ts/limit/dirty line, no longer matches;
#      * the sealed region's `recorded: status= cases= failed= rc=` line EQUALS the TSV row (header, TSV and body must
#        state ONE verdict: editing the rc in header+TSV alone is refused);
#      * header `dirty=` equals the TSV `dirty` column (`?` = legacy evidence sealed after the fact, header carries none);
#      * the listed `failing-tests (N...)` block: N == failed=, and the lines actually listed == N minus the omitted count;
#      * a `could-not-run:go-build:<cause>` label: every cause is environmental (goproxy-off | missing-replace-dir) and
#        the evidence lists no DEFECT package, no compile error, no package-level failure and no failing test.
#    HONEST LIMIT (§11.4.6): an actor who recomputes EVERY column (header, TSV, recorded line, evsha) consistently is not
#    detected by this check; the binding is to the head recorded in the row plus the COMMITTED TSV / evidence files, i.e.
#    the git history is where such a rewrite shows. An unsigned file proves no more than that.
evidence_mismatch() {
    local f="$1" subj="$2" kind="$3" status="$4" cases="$5" failed="$6" rc="$7" thead="$8" ttree="$9" tevsha="${10}" tdirty="${11}" root="${12}" hdr bad="" v eh et ed rec act c fb
    if [ ! -f "$f" ]; then printf 'file-absent'; return 0; fi
    hdr=$(head -2 "$f" 2>/dev/null | tr ' ' '\n')
    kv() { printf '%s\n' "$hdr" | sed -n "s/^$1=//p" | head -1; }
    [ "$(kv subject)" = "$subj" ] || bad="$bad,subject"
    [ "$(kv kind)" = "$kind" ] || bad="$bad,kind"
    [ "$(kv status)" = "$status" ] || bad="$bad,status"
    [ "$(kv cases)" = "$cases" ] || bad="$bad,cases"
    [ "$(kv failed)" = "$failed" ] || bad="$bad,failed"
    [ "$(kv rc)" = "$rc" ] || bad="$bad,rc"
    eh=$(kv head); et=$(kv tree)
    if ! printf '%s' "$eh" | grep -qE '^[0-9a-f]{40}$' || printf '%s' "$eh" | grep -qE '^0{40}$'; then bad="$bad,head"
    else
        [ "$eh" = "$thead" ] || bad="$bad,head-differs-from-tsv"
        if ! git -C "$root" cat-file -e "${eh}^{commit}" 2>/dev/null; then bad="$bad,head-not-in-object-store"
        elif ! git -C "$root" merge-base --is-ancestor "$eh" HEAD 2>/dev/null; then bad="$bad,head-not-ancestor-of-HEAD"; fi
    fi
    if ! printf '%s' "$et" | grep -qE '^[0-9a-f]{64}$' || printf '%s' "$et" | grep -qE '^0{64}$'; then bad="$bad,tree"
    else [ "$et" = "$ttree" ] || bad="$bad,tree-differs-from-tsv"; fi
    v=$(kv ts); printf '%s' "$v" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' || bad="$bad,ts"
    # sealed region
    if ! printf '%s' "$tevsha" | grep -qE '^[0-9a-f]{64}$'; then bad="$bad,evsha-absent"
    else
        act=$(tail -n +2 "$f" | sha256sum | cut -d' ' -f1)
        [ "$act" = "$tevsha" ] || bad="$bad,evidence-body-sha"
    fi
    ed=$(kv dirty)
    if [ -n "$ed" ]; then [ "$ed" = "$tdirty" ] || bad="$bad,dirty-differs-from-tsv"
    else [ "$tdirty" = "?" ] || bad="$bad,dirty-absent-in-header"; fi
    rec=$(tail -n +2 "$f" | sed -n 's/^recorded: //p' | head -1)
    if [ -n "$rec" ]; then [ "$rec" = "status=$status cases=$cases failed=$failed rc=$rc" ] || bad="$bad,recorded-line-differs"
    elif [ "$tdirty" != "?" ]; then bad="$bad,recorded-line-absent"; fi
    # failing-tests block: count it against failed=
    c=$(awk '/^---$/ {exit} /^failing-tests \(/ { m = $0; sub(/^failing-tests \(/, "", m); n = m + 0; om = 0; if (match(m, /; [0-9]+ omitted/)) { o = substr(m, RSTART + 2, RLENGTH - 2); om = o + 0 } blk = 1; next }
                 blk && /^  / { l++; next } blk { blk = 0 } END { if (n != "") printf "%d %d %d", n, om, l }' "$f")
    if [ -n "$c" ]; then
        set -- $c
        [ "$1" = "$failed" ] || bad="$bad,failing-tests-count-differs-from-failed"
        [ "$3" = "$(($1 - $2))" ] || bad="$bad,failing-tests-listed-differs-from-count"
    fi
    # environment label discipline
    case "$status" in could-not-run:go-build:*)
        for fb in $(printf '%s' "${status#could-not-run:go-build:}" | tr '+' ' '); do
            case "$fb" in goproxy-off|missing-replace-dir) ;; *) bad="$bad,go-build-label-not-environmental"; break ;; esac
        done
        if sed -n '1,/^---$/p' "$f" | grep -qE '\[DEFECT:|^compile-error=yes|^package-level-failures|^failing-tests \([1-9]'; then bad="$bad,env-label-with-defect-evidence"; fi ;;
    esac
    printf '%s' "${bad#,}"
}

# evidence_limit <file> ─ the `limit=` (seconds) recorded in the evidence header, or "unrecorded".
evidence_limit() {
    local v
    v=$(head -2 "$1" 2>/dev/null | tr ' ' '\n' | sed -n 's/^limit=//p' | head -1)
    case "$v" in ''|-|*[!0-9]*) printf 'unrecorded' ;; *) printf '%s' "$v" ;; esac
}

# ── red_or_check <cases> <failed> <rc> <ref> ─ the FR-010/FR-011/SC-005 rule for a kind that RAN:
#    covered only when cases>0 AND failed==0 AND rc==0; cases>0 otherwise is `check-red` (applied, not
#    proven); cases==0 is `gap`. Prints "<status>\t<ref>".
red_or_check() {
    local cases="$1" failed="$2" rc="$3" ref="$4"
    if ! [ "$cases" -gt 0 ] 2>/dev/null; then printf 'gap\t-\n'; return; fi
    if [ "${failed:-0}" -eq 0 ] 2>/dev/null && [ "${rc:-0}" -eq 0 ] 2>/dev/null; then printf 'check\t%s\n' "$ref"; return; fi
    printf 'check-red\t%s\n' "$ref"
}

# ── designed_red <designed-red.tsv> <subj> <kind> <rc> ─ true only when docs/zero-gap/designed-red.tsv
#    DECLARES this (subject, kind) and its declared expected_rc EQUALS the measured rc: a declaration
#    excuses exactly the failure it names, never a different one.
designed_red() {
    local f="$1" subj="$2" kind="$3" rc="$4"
    [ -f "$f" ] || return 1
    awk -F'\t' -v s="$subj" -v k="$kind" -v r="$rc" '$0 !~ /^#/ && $1==s && $2==k && $3==r && $4!="" {f=1} END{exit !f}' "$f"
}

# ── measured_cell <measured.tsv> <subject> <kind> <root> ─ prints "<status>\t<ref>\t<reason>" for a
#    REAL-RUN row of scripts/zero-gap-coverage-measure.py (T053; columns subject kind status cases failed rc evidence
#    cmd head tree evsha dirty), re-derived here from the numbers (the measurer's label is never trusted upward) and
#    bound to its evidence file for EVERY status that cites evidence (check, check-red, gap, could-not-run:* alike: a
#    TSV-only downgrade to could-not-run is refused exactly like an upgrade to check). A row that cites no evidence while
#    the canonical evidence file of that cell exists in coverage-evidence/ is refused too (an evidence reference cannot be
#    dropped to dodge the binding). Prints nothing when the cell was never measured. Side output: one line per bound
#    cell is appended to $FRESH_FILE (subject kind head12 behind dirty) for the freshness / cleanliness report; the
#    cell's own reason never embeds "N commits behind HEAD" (that is a property of the run, not of the cell).
measured_cell() {
    local f="$1" subj="$2" kind="$3" root="$4" st cases failed rc ev mhead mtree mevsha mdirty mm cs rf behind lim canon note=""
    [ -f "$f" ] || return 0
    IFS=$'\t' read -r st cases failed rc ev mhead mtree mevsha mdirty < <(awk -F'\t' -v s="$subj" -v k="$kind" '$1==s && $2==k {print $3 "\t" $4 "\t" $5 "\t" $6 "\t" ($7==""?"-":$7) "\t" $9 "\t" $10 "\t" ($11==""?"-":$11) "\t" ($12==""?"-":$12); exit}' "$f")
    [ -n "${st:-}" ] || return 0
    if [ "$ev" = "-" ]; then
        canon="docs/zero-gap/coverage-evidence/$(printf '%s__%s' "$subj" "$kind" | sed 's/[^A-Za-z0-9._-]\{1,\}/_/g').txt"
        if [ -f "$root/$canon" ]; then printf 'gap:evidence-mismatch\t-\tevidence-mismatch: evidence-reference-dropped (the row cites no evidence but %s exists)\n' "$canon"; return 0; fi
    else
        mm=$(evidence_mismatch "$root/$ev" "$subj" "$kind" "$st" "${cases:-}" "${failed:-}" "${rc:-}" "${mhead:-}" "${mtree:-}" "${mevsha:-}" "${mdirty:-}" "$root")
        if [ -n "$mm" ]; then printf 'gap:evidence-mismatch\t-\tevidence-mismatch: %s\n' "$mm"; return 0; fi
        behind=$(git -C "$root" rev-list --count "${mhead}..HEAD" 2>/dev/null); behind="${behind:-0}"
        printf '%s\t%s\t%s\t%s\t%s\n' "$subj" "$kind" "${mhead:0:12}" "$behind" "${mdirty:-?}" >>"${FRESH_FILE:-/dev/null}"
        case "$st" in check|check-red)
            if [ -n "$MAX_BEHIND" ] && [ "$behind" -gt "$MAX_BEHIND" ]; then
                printf 'gap:evidence-stale\t-\tevidence-stale: measured at %s, %s commit(s) behind HEAD (allowance %s): re-measure\n' "${mhead:0:12}" "$behind" "$MAX_BEHIND"; return 0
            fi ;;
        esac
    fi
    case "${mdirty:-?}" in 1) note="measured on a DIRTY working tree" ;; \?) note="dirty state UNKNOWN: legacy evidence sealed after measurement" ;; esac
    case "$st" in
        check|check-red)
            IFS=$'\t' read -r cs rf < <(red_or_check "${cases:-0}" "${failed:-0}" "${rc:-0}" "$ev")
            if [ "$st" = "check-red" ] && [ "$cs" = "gap" ] && [ "${rc:-0}" != "0" ] && [ "${cases:-0}" = "0" ]; then cs="check-red-zero"; fi
            case "$cs" in
                check)
                    if [ "${mdirty:-?}" = "1" ] && [ "$ALLOW_DIRTY" != "1" ]; then
                        printf 'gap:evidence-dirty\t-\tevidence-dirty: measured on a DIRTY working tree: not fully trusted; re-measure from a clean checkout (or pass --allow-dirty-evidence)\n'; return 0
                    fi
                    printf 'check\t%s\tfailed=0 rc=0 cases=%s%s\n' "$rf" "$cases" "${note:+; $note}${note:+$([ "${mdirty:-?}" = 1 ] && printf ' (allowed by --allow-dirty-evidence)')}" ;;
                gap) printf 'gap\t-\tinvocation executed zero cases\n' ;;
                check-red-zero) printf 'check-red\t%s\tzero cases ran and rc=%s: a build/compile defect or an unexplained failure stopped every case (see evidence); applied, not proven%s\n' "$ev" "$rc" "${note:+; $note}" ;;
                *)
                    if designed_red "$root/docs/zero-gap/designed-red.tsv" "$subj" "$kind" "$rc"; then
                        printf 'designed-red\tdocs/zero-gap/designed-red.tsv\tdeclared designed-red, rc=%s cases=%s failed=%s%s\n' "$rc" "$cases" "$failed" "${note:+; $note}"
                    else
                        printf 'check-red\t%s\tcases=%s failed=%s rc=%s (red kind is applied, not proven)%s\n' "$ev" "$cases" "$failed" "$rc" "${note:+; $note}"
                    fi ;;
            esac ;;
        gap) printf 'gap\t-\tmeasured: no invocation or zero cases\n' ;;
        n/a:*) printf '%s\t-\tdeclared not applicable\n' "$st" ;;
        could-not-run:timeout)
            lim=$(evidence_limit "$root/$ev")
            printf '%s\t-\ttimed out: the measured run was cut off at its configured limit of %ss (cases=%s rc=%s); evidence %s\n' "$st" "$lim" "${cases:-0}" "${rc:-}" "$ev" ;;
        could-not-run:go-build:*)
            printf '%s\t-\tenvironment build failure (%s), not a test failure: cases=%s passing cases of the packages that did run, failed=%s; unbuilt packages listed in %s\n' "$st" "${st#could-not-run:go-build:}" "${cases:-0}" "${failed:-0}" "$ev" ;;
        could-not-run:*) printf '%s\t-\ttool %s unusable in the measured run\n' "$st" "${st#could-not-run:}" ;;
        *) printf 'gap\t-\tmeasured status %s is outside the vocabulary\n' "$st" ;;
    esac
}

# cell_note <root> <subject> <kind> ─ the reviewed annotation of a cell from docs/zero-gap/cell-notes.tsv (subject, kind,
#    note, ref): data, never a status change. It is appended to the cell's reason in cycle-2-candidates.tsv so an
#    UNCONFIRMED hypothesis about a red cell travels with the cell without softening it.
cell_note() {
    local f="$1/docs/zero-gap/cell-notes.tsv"
    [ -f "$f" ] || return 0
    awk -F'\t' -v s="$2" -v k="$3" '$0 !~ /^#/ && $1==s && $2==k && $3!="" {print $3; exit}' "$f"
}

# ── ownership derivation (reused verbatim from zero-gap-class-doc-count-drift.sh's
#    gitmodules()/namespace()/owned-namespace algorithm, itself "derived exactly like
#    verify-governance-cascade.sh C1") ────────────────────────────────────────────────────────
owned_subjects() { # <root> -> one checked-out owned module path per line, sorted
    python3 - "$1" <<'PY'
import os, re, subprocess, sys
base = sys.argv[1]

def git(args, cwd):
    p = subprocess.run(['git'] + args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.returncode, p.stdout

def namespace(u):
    u = u.strip()
    m = re.match(r'^[\w.-]+@([\w.-]+):/?([^/]+)/', u) or re.match(r'^(?:ssh|https?|git)://(?:[^@/]+@)?([^/:]+)(?::\d+)?/([^/]+)/', u)
    return (m.group(1) + '/' + m.group(2)).lower() if m else None

gm = os.path.join(base, '.gitmodules')
if not os.path.isfile(gm):
    sys.exit(0)
rc, o = git(['config', '-f', gm, '-z', '--get-regexp', r'^submodule\..*\.(path|url)$'], base)
if rc not in (0, 1):
    sys.exit(2)
d = {}
for rec in o.split(b'\0'):
    if not rec:
        continue
    k, _, v = rec.partition(b'\n')
    k = k.decode(errors='replace'); v = v.decode(errors='replace')
    name, _, attr = k[len('submodule.'):].rpartition('.')
    d.setdefault(name, {})[attr] = v
decl = [(e['path'].strip('/'), e.get('url', '')) for _, e in sorted(d.items()) if e.get('path', '').strip('/')]

nscount = {}
for p, u in decl:
    n = namespace(u)
    if n:
        nscount[n] = nscount.get(n, 0) + 1
owned_ns = {n for n, c in nscount.items() if c >= 2}
hd = os.path.join(base, 'helix-deps.yaml')
if os.path.isfile(hd):
    with open(hd, 'rb') as fh:
        txt = fh.read().decode(errors='replace')
    for m in re.finditer(r'^\s*-?\s*ssh_url:\s*["\']?([^"\'\s#]+)', txt, re.M):
        n = namespace(m.group(1))
        if n:
            owned_ns.add(n)

gov = {p for p, _ in decl if os.path.isfile(os.path.join(base, p, 'scripts/gates/lib/pointer_carrier.sh'))}

def checked_out(p):
    a = os.path.join(base, p)
    if not os.path.isdir(a):
        return False
    rc, o = git(['rev-parse', '--show-toplevel'], a)
    return rc == 0 and os.path.realpath(o.decode(errors='replace').strip()) == os.path.realpath(a)

owned = sorted({p for p, u in decl if p not in gov and namespace(u) in owned_ns and checked_out(p)})
for p in owned:
    print(p)
PY
}

# ── duplicate_subjects <root> <subject>... ─ prints "<duplicate>\t<of>" for every declaration in
#    docs/zero-gap/duplicate-subjects.tsv (duplicate, of, reason) that is HONOURED: both subjects are in the
#    subject list, they differ, `of` is not itself a duplicate (no chains), the reason is non-empty, and both
#    checked-out HEADs are the IDENTICAL commit. Every refused declaration is reported on stderr and
#    de-duplicates nothing (F5): a declaration cannot hide a subject whose code differs.
duplicate_subjects() {
    local root="$1" f dup of reason h1 h2 subjects=" "; shift
    f="$root/docs/zero-gap/duplicate-subjects.tsv"
    [ -f "$f" ] || return 0
    local x; for x in "$@"; do subjects="$subjects$x "; done
    while IFS=$'\t' read -r dup of reason; do
        case "$dup" in ''|'#'*) continue ;; esac
        [ "$dup" = "duplicate" ] && continue
        if [ -z "$of" ] || [ -z "$reason" ]; then echo "zero-gap-coverage: duplicate-subjects.tsv: '$dup' refused: columns duplicate, of and a non-empty reason are required" >&2; continue; fi
        case "$subjects" in *" $dup "*) ;; *) echo "zero-gap-coverage: duplicate-subjects.tsv: '$dup' refused: not a subject of this run" >&2; continue ;; esac
        case "$subjects" in *" $of "*) ;; *) echo "zero-gap-coverage: duplicate-subjects.tsv: '$dup' refused: '$of' is not a subject of this run" >&2; continue ;; esac
        if [ "$dup" = "$of" ]; then echo "zero-gap-coverage: duplicate-subjects.tsv: '$dup' refused: a subject cannot duplicate itself" >&2; continue; fi
        if awk -F'\t' -v d="$of" '$0 !~ /^#/ && $1==d {f=1} END{exit !f}' "$f"; then echo "zero-gap-coverage: duplicate-subjects.tsv: '$dup' refused: '$of' is itself declared a duplicate (no chains)" >&2; continue; fi
        h1=$(git -C "$root/$dup" rev-parse HEAD 2>/dev/null); h2=$(git -C "$root/$of" rev-parse HEAD 2>/dev/null)
        if [ -z "$h1" ] || [ "$h1" != "$h2" ]; then echo "zero-gap-coverage: duplicate-subjects.tsv: '$dup' refused: checked-out HEADs differ (${h1:0:12} vs ${h2:0:12}), so it is not the same code" >&2; continue; fi
        printf '%s\t%s\n' "$dup" "$of"
    done <"$f"
}

# ── totals <rows-file> <dups-file> <fresh-file> ─ per-status counts, RAW and DE-DUPLICATED (rows of a duplicate subject
#    are kept in coverage.tsv but not counted in the de-duplicated column), then the evidence-freshness lines (per measured
#    head: how many commits behind HEAD, how many cells) and the evidence-cleanliness line with every cell measured on a
#    DIRTY tree named. Printed by the generator; nothing hand-typed.
totals() {
    awk -F'\t' '
        FILENAME == ARGV[1] { dup[$1] = $2; next }
        FILENAME == ARGV[3] { fresh[$3 " behind=" $4]++; if ($5 == "1") { dirty++; dl = dl (dl == "" ? "" : ", ") $1 "/" $2 } else if ($5 == "0") clean++; else unknown++; next }
        { raw[$3]++; nraw++; sraw[$1] = 1; if (!($1 in dup)) { dd[$3]++; ndd++; sdd[$1] = 1 } }
        END {
            for (k in sraw) cr++; for (k in sdd) cd++; for (k in dup) nd++
            printf "coverage totals: RAW %d cell(s) over %d subject(s); DE-DUPLICATED %d cell(s) over %d subject(s) (%d duplicate subject(s) excluded from the de-duplicated count)\n", nraw, cr, ndd, cd, nd
            for (k in raw) printf "  %-48s raw=%-4d dedup=%d\n", k, raw[k], dd[k] + 0
            for (k in fresh) { split(k, w, " "); printf "  evidence-freshness measured-at=%s %s cells=%d\n", w[1], w[2], fresh[k] }
            printf "  evidence-cleanliness clean=%d dirty=%d unknown=%d (cells with bound evidence; unknown = legacy evidence sealed after measurement)\n", clean + 0, dirty + 0, unknown + 0
            if (dirty > 0) printf "  evidence-dirty-cells (%d): %s\n", dirty, dl
        }' "$2" "$1" "$3" | { IFS= read -r first; printf '%s\n' "$first"; LC_ALL=C sort; }
}

# ── the generator itself ─────────────────────────────────────────────────────────────────────
generate() { # <root> <outfile> -> rc 0 written, 2 could not generate
    local root="$1" out="$2"
    if [ -z "$root" ] || [ ! -d "$root" ]; then echo "zero-gap-coverage: --root is not a directory" >&2; return 2; fi
    if [ ! -d "$root/.git" ] && [ ! -f "$root/.git" ]; then echo "zero-gap-coverage: --root is not a git work tree" >&2; return 2; fi
    need git awk sha256sum python3 grep mktemp timeout
    local W subjects=() m go_ok=1
    W=$(mktemp -d "${TMPDIR:-/tmp}/zg-coverage.XXXXXX") || { echo "zero-gap-coverage: cannot create a scratch directory" >&2; return 2; }
    trap '[ -n "${W:-}" ] && rm -rf "$W"' RETURN
    command -v go >/dev/null 2>&1 || go_ok=0

    subjects=("root")
    while IFS= read -r m; do [ -n "$m" ] && subjects+=("$m"); done < <(owned_subjects "$root")

    : >"$W/rows"; : >"$W/fresh"; export FRESH_FILE="$W/fresh"
    row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5:-}" >>"$W/rows"; }

    local subj kind status ref reason note
    for subj in "${subjects[@]}"; do
        for kind in $KINDS; do
            status="gap"; ref="-"; reason="no registered or measured test for this kind"
            case "$subj/$kind" in
                root/unit)
                    if [ -f "$root/_tools/gen/go.mod" ]; then
                        if [ "$go_ok" -eq 1 ]; then
                            local out2 cnt fcnt rcu
                            out2=$(cd "$root/_tools/gen" && GOPROXY=off timeout 45 go test ./... -count=1 -v 2>&1); rcu=$?
                            cnt=$(printf '%s\n' "$out2" | grep -c '^--- PASS:')
                            fcnt=$(printf '%s\n' "$out2" | grep -c '^--- FAIL:')
                            read -r status ref < <(decide_status "$cnt" 1 go "_tools/gen/go.mod")
                            if [ "$status" = "check" ] && { [ "$fcnt" -gt 0 ] || [ "$rcu" -ne 0 ]; }; then status="check-red"; reason="cases=$cnt failed=$fcnt rc=$rcu (red kind is applied, not proven)"; fi
                        else
                            read -r status ref < <(decide_status 0 0 go "_tools/gen/go.mod")
                        fi
                    fi
                    ;;
                root/mutation)
                    if [ -x "$root/scripts/verify-mutation-anchors.sh" ] || [ -f "$root/scripts/verify-mutation-anchors.sh" ]; then
                        local out2 cnt rc2
                        out2=$(cd "$root" && timeout 60 bash scripts/verify-mutation-anchors.sh --prove-failure 2>&1); rc2=$?
                        if [ "$rc2" -eq 0 ]; then
                            cnt=$(parse_count mutation "$out2")
                            read -r status ref < <(decide_status "${cnt:-0}" 1 bash "mutation-anchor-rot")
                        fi
                    fi
                    ;;
                root/security)
                    if [ -x "$root/scripts/verify-pretooluse-guard.sh" ] || [ -f "$root/scripts/verify-pretooluse-guard.sh" ]; then
                        local out2 cnt rc2
                        out2=$(cd "$root" && timeout 60 bash scripts/verify-pretooluse-guard.sh --prove-failure 2>&1); rc2=$?
                        if [ "$rc2" -eq 0 ]; then
                            cnt=$(parse_count security "$out2")
                            read -r status ref < <(decide_status "${cnt:-0}" 1 bash "pretooluse-guard")
                        fi
                    fi
                    ;;
                root/manual-qa-readiness)
                    # Module subjects are deliberately NOT given this treatment: the coverage-gaps
                    # class resolves a `check` ref's tracked-file half against `git -C <root>
                    # ls-files` ONLY (verified live, this session — a gitlink hides everything
                    # inside a submodule from the superproject's own ls-files), so a path inside an
                    # owned submodule can never resolve there and a "check" claiming one would be
                    # exactly the FALSE-EVIDENCE case that class exists to catch. Several owned
                    # submodules DO carry real docs/qa/ evidence (challenges, llms_verifier,
                    # workshop, measured this session) — that evidence is real, but is not something
                    # THIS umbrella-scoped generator can cite a root-resolvable ref for; it is
                    # reported `gap` here rather than a ref the consumer cannot verify.
                    local n
                    n=$(git -C "$root" ls-files -- docs/qa 2>/dev/null | grep -c .)
                    if [ "${n:-0}" -gt 0 ]; then
                        local first
                        first=$(git -C "$root" ls-files -- docs/qa 2>/dev/null | LC_ALL=C sort | head -1)
                        read -r status ref < <(decide_status "$n" 1 git "$first")
                    fi
                    ;;
            esac
            # REAL-RUN overlay (T053): a measured row (scripts/zero-gap-coverage-measure.py) wins over the
            # default `gap` of a cell this generator does not run itself; the three cells it runs
            # itself (root unit/mutation/security) are kept as executed above.
            case "$subj/$kind" in root/unit|root/mutation|root/security) ;; *)
                local mc; mc=$(measured_cell "$root/docs/zero-gap/coverage-measured.tsv" "$subj" "$kind" "$root")
                [ -n "$mc" ] && IFS=$'\t' read -r status ref reason <<<"$mc" ;;
            esac
            note=$(cell_note "$root" "$subj" "$kind"); [ -n "$note" ] && reason="$reason; NOTE: $note"
            row "$subj" "$kind" "$status" "$ref" "$reason"
        done
        # extra kinds (T053; allowed by FR-010 clarification 5): any measured kind outside KINDS
        local xk
        while IFS= read -r xk; do
            [ -n "$xk" ] || continue
            local mc2; mc2=$(measured_cell "$root/docs/zero-gap/coverage-measured.tsv" "$subj" "$xk" "$root")
            [ -n "$mc2" ] && { IFS=$'\t' read -r status ref reason <<<"$mc2"; note=$(cell_note "$root" "$subj" "$xk"); [ -n "$note" ] && reason="$reason; NOTE: $note"; row "$subj" "$xk" "$status" "$ref" "$reason"; }
        done < <(awk -F'\t' -v s="$subj" -v K=" $KINDS " 'NR>1 && $1==s && index(K, " " $2 " ")==0 {print $2}' "$root/docs/zero-gap/coverage-measured.tsv" 2>/dev/null | LC_ALL=C sort -u)
    done

    { printf 'subject\ttest_kind\tstatus\tref\n'; LC_ALL=C sort -t "$(printf '\t')" -k1,1 "$W/rows" | cut -f1-4; } >"$W/coverage.tsv.new"
    # cycle-2 intake (SC-005): every cell that is not proven (gap*, check-red, could-not-run) is DERIVED
    # here, never hand-typed; the register is frozen at cycle 1 so this file is intake, not register rows.
    { printf 'subject\ttest_kind\tstatus\treason\tref\n'
      LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2 "$W/rows" | awk -F'\t' -v OFS='\t' '$3 ~ /^(gap|check-red|could-not-run)/ { print $1, $2, $3, $5, $4 }'
    } >"$W/cand.new"
    mkdir -p "$(dirname "$out")" || { echo "zero-gap-coverage: cannot create $(dirname "$out")" >&2; return 2; }
    mv "$W/cand.new" "$(dirname "$out")/cycle-2-candidates.tsv" || { echo "zero-gap-coverage: cannot write cycle-2-candidates.tsv" >&2; return 2; }
    mv "$W/coverage.tsv.new" "$out" || { echo "zero-gap-coverage: cannot write $out" >&2; return 2; }
    echo "zero-gap-coverage: wrote $out ($(($(wc -l <"$out") - 1)) cell(s), $(printf '%s\n' "${subjects[@]}" | wc -l) subject(s) x $(printf '%s\n' $KINDS | wc -l) kind(s))"
    duplicate_subjects "$root" "${subjects[@]}" >"$W/dups"
    : >>"$W/dups"
    totals "$W/rows" "$W/dups" "$W/fresh"
    return 0
}

# ── §1.1 paired proof ────────────────────────────────────────────────────────────────────────
prove_failure() {
    local pass=0 fail=0 T LIVE h0 h1
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-coverage-proof.XXXXXX") || { echo "prove-failure: cannot create a scratch directory" >&2; return 2; }
    trap '[ -n "${T:-}" ] && rm -rf "$T"' EXIT INT TERM
    LIVE=$(cd "$(dirname "$SELF")/.." && pwd)
    ok() { pass=$((pass + 1)); echo "  PASS $1"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $1"; }

    echo "zero-gap-coverage paired proof"

    # C0/C1/C2: decide_status unit logic (the FR-011 zero-case and missing-tool rules)
    local s r
    read -r s r < <(decide_status 5 1 go ref-a)
    if [ "$s" = "check" ] && [ "$r" = "ref-a" ]; then ok "C0 count>0, tool present => check, ref preserved"; else bad "C0 got status=$s ref=$r"; fi
    read -r s r < <(decide_status 0 1 go ref-b)
    if [ "$s" = "gap" ]; then ok "C1 count==0, tool present => gap (never check)"; else bad "C1 got status=$s ref=$r"; fi
    read -r s r < <(decide_status "" 1 go ref-c)
    if [ "$s" = "gap" ]; then ok "C1b unparseable (empty) count => gap"; else bad "C1b got status=$s ref=$r"; fi
    read -r s r < <(decide_status 9 0 go ref-d)
    if [ "$s" = "could-not-run:go" ]; then ok "C2 tool absent => could-not-run:go (never check, never silently skipped)"; else bad "C2 got status=$s ref=$r"; fi

    # C3 parse_count reuses the check-registry hollow-proof vocabulary
    r=$(parse_count x "some noise then 7 assertions: control 0")
    [ "$r" = "7" ] && ok "C3a parse_count reads 'N assertions'" || bad "C3a got '$r'"
    r=$(parse_count x "  12 passed / 0 failed / 12 cases")
    [ "$r" = "12" ] && ok "C3b parse_count reads 'N passed'" || bad "C3b got '$r'"
    r=$(parse_count x "1 mutation caught (renaming ...)")
    [ "$r" = "1" ] && ok "C3c parse_count reads 'N mutation caught'" || bad "C3c got '$r'"
    r=$(parse_count x "nothing here resembles a count")
    [ -z "$r" ] && ok "C3d parse_count finds nothing => empty (feeds C1b, never fabricates a count)" || bad "C3d got '$r'"

    # C3e-h (T052 review IMPORTANT fix): parse_count must not credit an attempted/planned/expected
    # count as a real positive result just because a trigger word appears somewhere after it.
    r=$(parse_count x "0 of 5 mutations attempted")
    if [ "$r" != "5" ]; then ok "C3e parse_count: '0 of 5 mutations attempted' does not extract 5 (attempted is not a positive-result word); got '$r'"; else bad "C3e got '5' (WRONG: credited the attempted count)"; fi
    r=$(parse_count x "5 mutations planned, 0 caught")
    [ "$r" = "0" ] && ok "C3f parse_count: '5 mutations planned, 0 caught' extracts the real 0 caught, not the 5 planned" || bad "C3f got '$r'"
    r=$(parse_count x "expected 10 assertions")
    if [ "$r" != "10" ]; then ok "C3g parse_count: 'expected 10 assertions' does not extract 10 (expected is not a positive-result word); got '$r'"; else bad "C3g got '10' (WRONG: credited the expected count)"; fi
    r=$(parse_count x "10 mutations expected, 3 caught")
    [ "$r" = "3" ] && ok "C3h parse_count: '10 mutations expected, 3 caught' extracts the real 3 caught, not the 10 expected" || bad "C3h got '$r'"

    # ── synthetic corpus: subject derivation must be DERIVED, never hand-listed ────────────
    mkgm() { # <dir>: two owned modules sharing a namespace, one governance source, one
             # single-submodule (unowned) namespace, one owned-but-not-checked-out module
        mkdir -p "$1"
        cat >"$1/.gitmodules" <<'GM'
[submodule "modA"]
	path = modA
	url = git@github.com:acme/modA.git
[submodule "modB"]
	path = modB
	url = git@github.com:acme/modB.git
[submodule "gov"]
	path = gov
	url = git@github.com:gov-org/constitution.git
[submodule "lonewolf"]
	path = lonewolf
	url = git@github.com:onlyone/lonewolf.git
[submodule "absent"]
	path = absent
	url = git@github.com:acme/absent.git
GM
        for m in modA modB absent; do
            mkdir -p "$1/$m"; ( cd "$1/$m" && git init -q . && git config user.email t@t && git config user.name t && printf 'x\n' >f && git add f && git commit -q -m x )
        done
        mkdir -p "$1/gov/scripts/gates/lib"; ( cd "$1/gov" && git init -q . && git config user.email t@t && git config user.name t && printf 'x\n' >scripts/gates/lib/pointer_carrier.sh && git add -A && git commit -q -m x )
        rm -rf "$1/absent/.git"   # declared, present on disk, but NOT a checked-out git work tree
        ( cd "$1" && git init -q . && git config user.email t@t && git config user.name t && printf 'root\n' >README.md && git add README.md .gitmodules && git commit -q -m root )
    }
    S="$T/synth"; mkgm "$S"
    o=$(owned_subjects "$S" | LC_ALL=C sort | tr '\n' ' ')
    if [ "$o" = "modA modB " ]; then
        ok "C4 owned_subjects: modA+modB (shared namespace, checked out) => owned; gov excluded (governance source); lonewolf excluded (singleton namespace, absent from helix-deps.yaml); absent excluded (not checked out) — DERIVED, not hand-listed"
    else
        bad "C4 owned_subjects got '$o'"
    fi
    # C4b: an unowned singleton namespace joins OWNED once helix-deps.yaml names its ssh_url
    printf 'deps:\n  - name: lonewolf\n    ssh_url: git@github.com:onlyone/lonewolf.git\n    ref: deadbeef\n' >"$S/helix-deps.yaml"
    mkdir -p "$S/lonewolf"; ( cd "$S/lonewolf" && git init -q . && git config user.email t@t && git config user.name t && printf 'x\n' >f && git add f && git commit -q -m x )
    o=$(owned_subjects "$S" | LC_ALL=C sort | tr '\n' ' ')
    if [ "$o" = "lonewolf modA modB " ]; then ok "C4b helix-deps.yaml ssh_url promotes a singleton namespace to owned"; else bad "C4b got '$o'"; fi
    rm -f "$S/helix-deps.yaml"; rm -rf "$S/lonewolf"

    # ── end-to-end: manual-qa-readiness real evidence (docs/qa presence), derived subjects ──
    # modA gets a REAL docs/qa file too, to prove the ref-resolution-boundary fix: a module's own
    # docs/qa is real evidence the coverage-gaps class cannot verify a ref into (git ls-files at
    # --root never crosses a gitlink), so it MUST stay `gap` there even though the file exists;
    # only root's own docs/qa may become `check`.
    E="$T/e2e"; mkgm "$E"
    mkdir -p "$E/docs/qa" "$E/modA/docs/qa"
    printf '# root readiness\n' >"$E/docs/qa/root-checklist.md"
    ( cd "$E" && git add -A && git commit -q -m root2 ) >/dev/null 2>&1
    printf '# readiness\n' >"$E/modA/docs/qa/checklist.md"
    ( cd "$E/modA" && git add docs/qa/checklist.md && git commit -q -m qa )
    OUTF="$T/out1.tsv"
    outp=$(bash "$SELF" --root "$E" --out "$OUTF" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ -f "$OUTF" ]; then
        nrows=$(($(wc -l <"$OUTF") - 1))
        nkinds=$(printf '%s\n' $KINDS | wc -l)
        exp=$((3 * nkinds))   # root + modA + modB
        modA_qa=$(awk -F'\t' '$1=="modA" && $2=="manual-qa-readiness"{print $3"\t"$4}' "$OUTF")
        modB_qa=$(awk -F'\t' '$1=="modB" && $2=="manual-qa-readiness"{print $3"\t"$4}' "$OUTF")
        root_qa=$(awk -F'\t' '$1=="root" && $2=="manual-qa-readiness"{print $3"\t"$4}' "$OUTF")
        if [ "$nrows" -eq "$exp" ] && [ "$modA_qa" = "gap	-" ] && [ "$modB_qa" = "gap	-" ] && [ "$root_qa" = "check	docs/qa/root-checklist.md" ]; then
            ok "C5 end-to-end: 3 subjects x $nkinds kinds = $exp rows; root's own real docs/qa file => check with a root-resolvable ref; modA's EQUALLY REAL docs/qa file stays gap (its ref would sit inside a submodule, unverifiable by the consumer class) and modB (no docs/qa) stays gap too — not fabricated either way"
        else
            bad "C5 nrows=$nrows exp=$exp modA='$modA_qa' modB='$modB_qa' root='$root_qa'"
        fi
    else
        bad "C5 generation rc=$rc out=$outp"
    fi

    # C6 determinism: two runs on the identical frozen synthetic tree are byte-identical
    OUTF2="$T/out2.tsv"
    bash "$SELF" --root "$E" --out "$OUTF2" >/dev/null 2>&1
    if [ -f "$OUTF" ] && [ -f "$OUTF2" ] && cmp -s "$OUTF" "$OUTF2"; then ok "C6 two runs on the same frozen tree are byte-identical"; else bad "C6 outputs differ or missing"; fi

    # C7 --root /nonexistent => rc 2
    bash "$SELF" --root /nonexistent --out "$T/out3.tsv" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ] && [ ! -f "$T/out3.tsv" ]; then ok "C7 --root /nonexistent => rc 2, nothing written"; else bad "C7 rc=$rc"; fi

    # C8 --root not a git work tree => rc 2
    mkdir -p "$T/notgit"
    bash "$SELF" --root "$T/notgit" --out "$T/out4.tsv" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ] && [ ! -f "$T/out4.tsv" ]; then ok "C8 --root not a git work tree => rc 2"; else bad "C8 rc=$rc"; fi

    # C9 every emitted status is one of the four contract values (never blank, never unknown)
    if awk -F'\t' 'NR>1 && $3!="check" && $3!="check-red" && $3!="designed-red" && $3!~/^gap(:|$)/ && $3!~/^could-not-run:/ && $3!~/^n\/a/{bad=1} END{exit bad}' "$OUTF"; then
        ok "C9 every status cell is check|check-red|designed-red|gap[:note]|could-not-run:<tool>|n/a — the coverage-gaps class's closed vocabulary"
    else
        bad "C9 an out-of-vocabulary status was emitted"
    fi

    # C10 --help / --prove-failure are real case arms (mktemp+trap present in THIS file, checked
    # structurally so the file's own SC-012 posture is provable without re-invoking itself)
    if grep -q 'mktemp' "$SELF" && grep -qE 'trap[[:space:]]' "$SELF" && grep -qiE 'rm -rf' "$SELF"; then
        ok "C10 this file itself uses mktemp + trap + rm -rf (SC-012 non-trivial-proof shape)"
    else
        bad "C10 missing mktemp/trap/rm -rf in $SELF"
    fi

    # ── measured-evidence policy (T061 review: FR-010 / FR-011 / SC-005) ─────────────────────────
    # A kind that RAN but is red (failed>0 or rc!=0) is applied, not proven: `check-red`, never `check`.
    # Only a gate declared in docs/zero-gap/designed-red.tsv whose rc equals the declared one is
    # `designed-red`. Evidence must be bound (subject/kind/cases/failed/rc + head/tree/ts) or the cell is
    # `gap:evidence-mismatch`. Every gap / red / could-not-run cell is written to cycle-2-candidates.tsv.
    local M H40 H64 mrc ORPH FOREIGN hh ht th tt
    M="$T/meas"; mkgm "$M"
    H40=$(git -C "$M" rev-parse HEAD); H64=$(printf 'b%.0s' $(seq 1 64))   # a REAL commit of the fixture repo
    ORPH=$(git -C "$M" commit-tree "$(git -C "$M" rev-parse 'HEAD^{tree}')" -m orphan-not-an-ancestor)   # in the object store, NOT an ancestor of HEAD
    mkdir -p "$T/foreign" && ( cd "$T/foreign" && git init -q . && git config user.email t@t && git config user.name t && printf 'f\n' >f && git add f && git commit -q -m foreign ) >/dev/null 2>&1
    FOREIGN=$(git -C "$T/foreign" rev-parse HEAD)   # a real commit of an UNRELATED repository: absent from $M's object store
    mkdir -p "$M/docs/zero-gap/coverage-evidence"
    printf 'subject\tkind\tstatus\tcases\tfailed\trc\tevidence\tcmd\thead\ttree\tevsha\tdirty\n' >"$M/docs/zero-gap/coverage-measured.tsv"
    # mkev <subj> <kind> <cases> <failed> <rc> <hdr-cases> <bound 1|0>   (TSV row + evidence file); the head/tree written
    # to the evidence header (hh/ht) and to the TSV row (th/tt) default to the real HEAD / a fixed tree and can be
    # overridden per call to build each tamper case.
    # extra knobs (env, per call): st=<tsv+header status> hd=<header dirty> td=<tsv dirty> recrc=<rc in the recorded line>
    # ft=<failing-tests block text> noevsha=1 (TSV evsha '-') nodirtyhdr=1 (legacy header without dirty=)
    mkev() {
        local f="docs/zero-gap/coverage-evidence/$1__$2.txt" _st="${st:-check}" _hd="${hd:-0}" _td _es
        hh="${hh:-$H40}"; ht="${ht:-$H64}"; th="${th:-$hh}"; tt="${tt:-$ht}"; _td="${td:-$_hd}"
        { printf 'subject=%s kind=%s status=%s cases=%s failed=%s rc=%s\n' "$1" "$2" "$_st" "$6" "$4" "$5"
          if [ "$7" = 1 ]; then
              if [ -n "${nodirtyhdr:-}" ]; then printf 'head=%s tree=%s ts=2026-10-12T10:00:00Z limit=240\n' "$hh" "$ht"
              else printf 'head=%s tree=%s ts=2026-10-12T10:00:00Z limit=%s dirty=%s dirtydigest=-\n' "$hh" "$ht" "${lim:-240}" "$_hd"; fi
          fi
          printf 'cmd=x\n'
          [ -z "${nodirtyhdr:-}" ] && printf 'recorded: status=%s cases=%s failed=%s rc=%s\n' "$_st" "$3" "$4" "${recrc:-$5}"
          [ -n "${ft:-}" ] && printf '%b\n' "$ft"
          printf -- '---\nout\n'; } >"$M/$f"
        _es=$(tail -n +2 "$M/$f" | sha256sum | cut -d' ' -f1); [ -n "${noevsha:-}" ] && _es="-"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tx\t%s\t%s\t%s\t%s\n' "$1" "$2" "$_st" "$3" "$4" "$5" "$f" "$th" "$tt" "$_es" "$_td" >>"$M/docs/zero-gap/coverage-measured.tsv"
        hh=""; ht=""; th=""; tt=""
    }
    mkev modA integration 5 0 0 5 1      # green and bound            => check
    mkev modA e2e 5 2 0 5 1              # failed cases               => check-red
    mkev modA contract 5 0 1 5 1         # rc 1, undeclared           => check-red
    mkev modA security 5 0 1 5 1         # rc 1, declared designed-red => designed-red
    mkev modA perf-load 5 0 3 5 1        # declared rc 1, measured 3   => check-red
    mkev modA stress-chaos 5 0 0 9 1     # header cases differ         => gap:evidence-mismatch
    mkev modA regression 5 0 0 5 0       # no head/tree/ts             => gap:evidence-mismatch
    mkev modA unit 0 0 0 0 1             # zero cases                  => gap
    printf 'modA\tdeterminism\tcheck\t4\t0\t0\tdocs/zero-gap/coverage-evidence/nope.txt\tx\t%s\t%s\t-\t0\n' "$H40" "$H64" >>"$M/docs/zero-gap/coverage-measured.tsv"   # file absent => gap:evidence-mismatch
    # F1 tamper cases (extra kinds are allowed by FR-010 clarification 5): each is an otherwise GREEN, bound row
    hh=0000000000000000000000000000000000000000 mkev modA zero-head 5 0 0 5 1                                      # all-zero head in header AND TSV (consistent edit)
    hh=zzzznotahexcommitzzzznotahexcommitzzzzzz mkev modA garbage-head 5 0 0 5 1                                   # malformed head
    hh="$FOREIGN" mkev modA foreign-head 5 0 0 5 1                                                                # head of an unrelated repository's commit
    hh="$ORPH" mkev modA orphan-head 5 0 0 5 1                                                                    # real commit in the object store, not an ancestor
    hh="$H40" th="$ORPH" mkev modA tsv-head-edited 5 0 0 5 1                                                       # only the TSV edited to a different head
    hh="$ORPH" th="$ORPH" mkev modA consistent-nonancestor 5 0 0 5 1                                               # BOTH files edited consistently to a non-ancestor head
    ht=0000000000000000000000000000000000000000000000000000000000000000 mkev modA zero-tree 5 0 0 5 1             # all-zero tree
    tt=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc mkev modA tree-ne-tsv 5 0 0 5 1            # header tree differs from the TSV row's
    # F2/F4 pass-through statuses written by the measurer
    st=could-not-run:go-build:goproxy-off ft='build-failure-causes=goproxy-off\nunbuilt-packages (1):\n  m/bad [goproxy-off]' mkev modA go-env 6558 0 1 6558 1
    lim=600 st=could-not-run:timeout mkev modA timeout-gate 0 0 124 0 1
    # ── round 3 (T061/T087) fixtures: body binding, rc consistency, failing-list counts, downgrades, dirty, notes ──
    mkev modA r3-body 5 0 0 5 1;  sed -i 's/^out$/tampered-after-measurement/' "$M/docs/zero-gap/coverage-evidence/modA__r3-body.txt"     # body replaced, TSV evsha and header untouched
    recrc=1 mkev modA r3-rc 5 0 0 5 1                                                                                                       # header+TSV say rc 0, the sealed recorded line says rc 1 (a CONSISTENT header+TSV rc edit)
    ft='failing-tests (3):\n  a :: T1\n  b :: T2\n  c :: T3' mkev modA r3-ft-count 5 2 1 5 1                                                  # lists 3, failed=2
    ft='failing-tests (2):\n  a :: T1' mkev modA r3-ft-listed 5 2 1 5 1                                                                    # says 2, lists 1
    ft='failing-tests (2):\n  a :: T1\n  b :: T2' mkev modA r3-ft-ok 5 2 1 5 1                                                              # consistent
    ft='failing-tests (4; 2 omitted from this list):\n  a :: T1\n  b :: T2' mkev modA r3-ft-omit 5 4 1 5 1                                    # consistent with an omitted count
    mkev modA r3-relabel 5 0 0 5 1                                                                                                          # then: TSV-only relabel to an env could-not-run
    mkev modA r3-relabel-gap 5 0 0 5 1                                                                                                      # then: TSV-only relabel to gap
    awk -F'\t' -v OFS='\t' '$1=="modA" && $2=="r3-relabel" {$3="could-not-run:go-build:goproxy-off"} $1=="modA" && $2=="r3-relabel-gap" {$3="gap"} {print}' "$M/docs/zero-gap/coverage-measured.tsv" >"$M/m.n" && mv "$M/m.n" "$M/docs/zero-gap/coverage-measured.tsv"
    st=could-not-run:go-build:compile-error mkev modA r3-label-compile 6 0 1 6 1                                                            # a code defect labelled as environment
    st=could-not-run:go-build:missing-module mkev modA r3-label-missmod 6 0 1 6 1                                                           # the removed label
    st=could-not-run:go-build:goproxy-off ft='unbuilt-packages (2):\n  m/a [goproxy-off]\n  m/c [DEFECT:compile-error]' mkev modA r3-env-defect 6 0 1 6 1   # env label, defect package listed
    st=check-red mkev modA r3-zero-red 0 0 1 0 1                                                                                            # zero cases, rc 1: a defect, not a gap
    hd=1 mkev modA r3-dirty 5 0 0 5 1                                                                                                       # green but measured on a dirty tree
    hd=1 td=0 mkev modA r3-dirty-differs 5 0 0 5 1                                                                                          # header says dirty, TSV says clean
    nodirtyhdr=1 td='?' mkev modA r3-legacy 5 0 0 5 1                                                                                       # legacy evidence sealed after the fact
    nodirtyhdr=1 mkev modA r3-nodirty 5 0 0 5 1                                                                                             # header lacks dirty= but TSV claims 0
    noevsha=1 mkev modA r3-noevsha 5 0 0 5 1                                                                                                # no sealed hash
    mkdir -p "$M/docs/zero-gap/coverage-evidence"; printf 'subject=modA kind=r3-unref\n' >"$M/docs/zero-gap/coverage-evidence/modA__r3-unref.txt"
    printf 'modA\tr3-unref\tcheck\t5\t0\t0\t\tx\t%s\t%s\t%s\t0\n' "$H40" "$H64" "$H64" >>"$M/docs/zero-gap/coverage-measured.tsv"                # evidence reference dropped
    printf '# subject\tkind\tnote\tref\nmodA\te2e\tUNCONFIRMED: the failure may depend on the host (proof fixture)\tCLAUDE.md\n' >"$M/docs/zero-gap/cell-notes.tsv"
    printf '# subject\tkind\texpected_rc\treason\tref\nmodA\tsecurity\t1\tdeclared red by design for the proof\tCLAUDE.md\nmodA\tperf-load\t1\tdeclared rc 1\tCLAUDE.md\n' >"$M/docs/zero-gap/designed-red.tsv"
    ( cd "$M" && git add -A && git commit -q -m fixture-evidence ) >/dev/null 2>&1   # HEAD moves ONE commit past $H40: every evidence row is 1 commit behind
    bash "$SELF" --root "$M" --out "$M/out.tsv" >"$T/m.stdout" 2>"$T/m.stderr"; mrc=$?
    cell() { awk -F'\t' -v s="$1" -v k="$2" '$1==s && $2==k {print $3}' "$M/out.tsv"; }
    reasonof() { awk -F'\t' -v s="$1" -v k="$2" '$1==s && $2==k {print $4}' "$M/cycle-2-candidates.tsv"; }
    if [ "$mrc" -eq 0 ] && [ "$(cell modA integration)" = "check" ]; then ok "C13 green, bound evidence (failed=0 rc=0 cases>0) => check"; else bad "C13 rc=$mrc got '$(cell modA integration)'"; fi
    [ "$(cell modA e2e)" = "check-red" ] && ok "C14 cases>0 but failed>0 => check-red (a red kind is applied, not proven)" || bad "C14 got '$(cell modA e2e)'"
    [ "$(cell modA contract)" = "check-red" ] && ok "C15 cases>0, failed=0 but rc!=0 and NOT declared => check-red" || bad "C15 got '$(cell modA contract)'"
    [ "$(cell modA security)" = "designed-red" ] && ok "C16 rc matches the gate declared in designed-red.tsv => designed-red" || bad "C16 got '$(cell modA security)'"
    [ "$(cell modA perf-load)" = "check-red" ] && ok "C17 declared designed-red but measured rc differs from the declared rc => check-red (the declaration cannot excuse a different failure)" || bad "C17 got '$(cell modA perf-load)'"
    [ "$(cell modA stress-chaos)" = "gap:evidence-mismatch" ] && ok "C18 evidence header cases != TSV cases => gap:evidence-mismatch" || bad "C18 got '$(cell modA stress-chaos)'"
    [ "$(cell modA regression)" = "gap:evidence-mismatch" ] && ok "C19 evidence header lacks head/tree/ts => gap:evidence-mismatch" || bad "C19 got '$(cell modA regression)'"
    [ "$(cell modA determinism)" = "gap:evidence-mismatch" ] && ok "C19b evidence file absent => gap:evidence-mismatch" || bad "C19b got '$(cell modA determinism)'"
    [ "$(cell modA unit)" = "gap" ] && ok "C20 zero cases => gap (FR-011 unchanged)" || bad "C20 got '$(cell modA unit)'"
    # F1: head/tree are COMPARED, not merely format-checked
    [ "$(cell modA zero-head)" = "gap:evidence-mismatch" ] && ok "C23 F1 all-zero head (header and TSV consistently edited) => gap:evidence-mismatch" || bad "C23 got '$(cell modA zero-head)'"
    [ "$(cell modA garbage-head)" = "gap:evidence-mismatch" ] && ok "C24 F1 malformed head => gap:evidence-mismatch" || bad "C24 got '$(cell modA garbage-head)'"
    if [ "$(cell modA foreign-head)" = "gap:evidence-mismatch" ] && reasonof modA foreign-head | grep -q 'head-not-in-object-store'; then ok "C25 F1 head of an unrelated repository's commit (absent from the object store) => gap:evidence-mismatch: head-not-in-object-store"; else bad "C25 got '$(cell modA foreign-head)' / '$(reasonof modA foreign-head)'"; fi
    if [ "$(cell modA orphan-head)" = "gap:evidence-mismatch" ] && reasonof modA orphan-head | grep -q 'head-not-ancestor-of-HEAD'; then ok "C26 F1 a real commit that is NOT an ancestor of HEAD => gap:evidence-mismatch: head-not-ancestor-of-HEAD"; else bad "C26 got '$(cell modA orphan-head)' / '$(reasonof modA orphan-head)'"; fi
    if [ "$(cell modA tsv-head-edited)" = "gap:evidence-mismatch" ] && reasonof modA tsv-head-edited | grep -q 'head-differs-from-tsv'; then ok "C27 F1 only the TSV head edited => gap:evidence-mismatch: head-differs-from-tsv"; else bad "C27 got '$(cell modA tsv-head-edited)' / '$(reasonof modA tsv-head-edited)'"; fi
    [ "$(cell modA consistent-nonancestor)" = "gap:evidence-mismatch" ] && ok "C28 F1 BOTH files edited consistently with a non-ancestor head => gap:evidence-mismatch (consistency alone is not binding)" || bad "C28 got '$(cell modA consistent-nonancestor)'"
    [ "$(cell modA zero-tree)" = "gap:evidence-mismatch" ] && ok "C29 F1 all-zero tree => gap:evidence-mismatch" || bad "C29 got '$(cell modA zero-tree)'"
    if [ "$(cell modA tree-ne-tsv)" = "gap:evidence-mismatch" ] && reasonof modA tree-ne-tsv | grep -q 'tree-differs-from-tsv'; then ok "C30 F1 header tree != TSV tree => gap:evidence-mismatch: tree-differs-from-tsv"; else bad "C30 got '$(cell modA tree-ne-tsv)'"; fi
    if grep -qE 'behind=1 ' "$T/m.stdout"; then ok "C31 F1 default allowance: every ancestor is accepted and the generator prints how many commits behind HEAD the evidence was measured ($(grep -E 'behind=1 ' "$T/m.stdout" | head -1 | tr -s ' '))"; else bad "C31 no freshness line: $(grep -i fresh "$T/m.stdout" | head -2)"; fi
    # F1 staleness allowance: HEAD advances 3 commits past the evidence head
    ( cd "$M" && for i in 1 2 3; do printf '%s\n' "$i" >"adv$i"; git add "adv$i"; git commit -q -m "adv$i"; done ) >/dev/null 2>&1
    bash "$SELF" --root "$M" --out "$M/out-stale.tsv" --max-behind 2 >"$T/m2.stdout" 2>&1
    cp "$M/cycle-2-candidates.tsv" "$M/cand-stale.tsv"
    bash "$SELF" --root "$M" --out "$M/out-ok.tsv" --max-behind 4 >"$T/m3.stdout" 2>&1
    s=$(awk -F'\t' '$1=="modA" && $2=="integration" {print $3}' "$M/out-stale.tsv"); r=$(awk -F'\t' '$1=="modA" && $2=="integration" {print $3}' "$M/out-ok.tsv")
    if [ "$s" = "gap:evidence-stale" ] && [ "$r" = "check" ] && grep -q 'evidence-stale: measured at' "$M/cand-stale.tsv"; then ok "C32 F1 --max-behind 2 with evidence 4 commits behind => gap:evidence-stale (re-measure); --max-behind 4 => check"; else bad "C32 stale='$s' ok='$r'"; fi
    bash "$SELF" --root "$M" --out "$M/out-bad.tsv" --max-behind x >/dev/null 2>&1; brc=$?
    [ "$brc" -eq 2 ] && ok "C32b --max-behind must be a non-negative integer (rc 2 otherwise)" || bad "C32b rc=$brc"
    # F2/F4 statuses pass through, with their reason
    [ "$(cell modA go-env)" = "could-not-run:go-build:goproxy-off" ] && ok "C33 F2 could-not-run:go-build:goproxy-off passes through the generator unchanged and is listed as cycle-2 intake" || bad "C33 got '$(cell modA go-env)'"
    if reasonof modA go-env | grep -q 'environment build failure (goproxy-off), not a test failure: cases=6558'; then ok "C33b F2 the cycle-2 reason states it is an environment failure and keeps the passing-case count"; else bad "C33b got '$(reasonof modA go-env)'"; fi
    if [ "$(cell modA timeout-gate)" = "could-not-run:timeout" ] && reasonof modA timeout-gate | grep -q 'limit of 600s'; then ok "C34 F4 could-not-run:timeout states the configured limit (600s) recorded in the evidence"; else bad "C34 got '$(reasonof modA timeout-gate)'"; fi
    # ── round 3 assertions ──
    r3() { [ "$(cell modA "$1")" = "$2" ] && reasonof modA "$1" | grep -q "$3"; }
    r3 r3-body gap:evidence-mismatch 'evidence-body-sha' && ok "C40 R3 evidence BODY replaced after measurement (TSV evsha + header untouched) => gap:evidence-mismatch: evidence-body-sha" || bad "C40 got '$(cell modA r3-body)' / '$(reasonof modA r3-body)'"
    r3 r3-rc gap:evidence-mismatch 'recorded-line-differs' && ok "C41 R3 header+TSV rc edited CONSISTENTLY to 0 while the sealed body still records rc 1 => gap:evidence-mismatch: recorded-line-differs" || bad "C41 got '$(cell modA r3-rc)' / '$(reasonof modA r3-rc)'"
    r3 r3-ft-count gap:evidence-mismatch 'failing-tests-count-differs-from-failed' && ok "C42 R3 failing-tests list size != failed= => gap:evidence-mismatch" || bad "C42 got '$(reasonof modA r3-ft-count)'"
    r3 r3-ft-listed gap:evidence-mismatch 'failing-tests-listed-differs-from-count' && ok "C43 R3 failing-tests (2) but one name listed => gap:evidence-mismatch" || bad "C43 got '$(reasonof modA r3-ft-listed)'"
    [ "$(cell modA r3-ft-ok)" = "check-red" ] && [ "$(cell modA r3-ft-omit)" = "check-red" ] && ok "C44 R3 a consistent failing-tests block (also with an omitted count) is accepted: check-red" || bad "C44 got '$(cell modA r3-ft-ok)' '$(cell modA r3-ft-omit)'"
    r3 r3-relabel gap:evidence-mismatch 'status' && r3 r3-relabel-gap gap:evidence-mismatch 'status' && ok "C45 R3 a TSV-only downgrade of a green cell to could-not-run:* (or gap) is refused: header status differs => gap:evidence-mismatch: status" || bad "C45 got '$(cell modA r3-relabel)' '$(cell modA r3-relabel-gap)'"
    r3 r3-label-compile gap:evidence-mismatch 'go-build-label-not-environmental' && r3 r3-label-missmod gap:evidence-mismatch 'go-build-label-not-environmental' && ok "C46 R3 could-not-run:go-build:compile-error / :missing-module is refused (only goproxy-off and missing-replace-dir are environmental)" || bad "C46 got '$(reasonof modA r3-label-compile)' '$(reasonof modA r3-label-missmod)'"
    r3 r3-env-defect gap:evidence-mismatch 'env-label-with-defect-evidence' && ok "C47 R3 an environment label whose evidence lists a [DEFECT:...] package is refused" || bad "C47 got '$(reasonof modA r3-env-defect)'"
    [ "$(cell modA r3-zero-red)" = "check-red" ] && ok "C48 R3 zero cases + rc 1 recorded by the measurer as check-red stays check-red (a build defect is not a gap)" || bad "C48 got '$(cell modA r3-zero-red)'"
    [ "$(cell modA r3-dirty)" = "gap:evidence-dirty" ] && ok "C49 R3 a green cell measured on a DIRTY tree is NOT classed check by default (gap:evidence-dirty)" || bad "C49 got '$(cell modA r3-dirty)'"
    r3 r3-dirty-differs gap:evidence-mismatch 'dirty-differs-from-tsv' && ok "C50 R3 header dirty=1 vs TSV dirty=0 => gap:evidence-mismatch: dirty-differs-from-tsv" || bad "C50 got '$(reasonof modA r3-dirty-differs)'"
    r3 r3-nodirty gap:evidence-mismatch 'dirty-absent-in-header' && ok "C51 R3 header without dirty= while the TSV claims a measured dirty state => gap:evidence-mismatch" || bad "C51 got '$(reasonof modA r3-nodirty)'"
    r3 r3-noevsha gap:evidence-mismatch 'evsha-absent' && ok "C52 R3 a row without a sealed evsha is refused" || bad "C52 got '$(reasonof modA r3-noevsha)'"
    r3 r3-unref gap:evidence-mismatch 'evidence-reference-dropped' && ok "C53 R3 a row that drops its evidence reference while the canonical evidence file exists is refused" || bad "C53 got '$(reasonof modA r3-unref)'"
    local dm lm
    dm=$(ALLOW_DIRTY=1 FRESH_FILE=/dev/null measured_cell "$M/docs/zero-gap/coverage-measured.tsv" modA r3-dirty "$M"); lm=$(FRESH_FILE=/dev/null measured_cell "$M/docs/zero-gap/coverage-measured.tsv" modA r3-legacy "$M")
    case "$dm" in check*DIRTY*) ok "C54 R3 --allow-dirty-evidence keeps the cell check with a visible DIRTY note in its reason" ;; *) bad "C54 got '$dm'" ;; esac
    case "$lm" in check*UNKNOWN*) ok "C55 R3 legacy evidence (dirty '?', sealed after the fact) stays check with a visible dirty-UNKNOWN note" ;; *) bad "C55 got '$lm'" ;; esac
    if grep -q 'evidence-cleanliness clean=' "$T/m.stdout" && grep -q 'evidence-dirty-cells ([0-9]*): .*modA/r3-dirty' "$T/m.stdout"; then ok "C56 R3 the generator prints an evidence-cleanliness line and NAMES every dirty cell ($(grep -E 'evidence-cleanliness' "$T/m.stdout" | head -1 | tr -s ' '))"; else bad "C56 no cleanliness/dirty line: $(grep -i 'evidence-' "$T/m.stdout" | head -5)"; fi
    if ! awk -F'\t' 'NR>1 && $4 ~ /behind HEAD/ {x=1} END{exit x}' "$M/cycle-2-candidates.tsv"; then bad "C57 a cycle-2 reason embeds 'N commits behind HEAD'"; else ok "C57 R3 no cycle-2 reason embeds 'N commit(s) behind HEAD' (freshness is a separate generated line)"; fi
    if [ "$(cell modA e2e)" = "check-red" ] && reasonof modA e2e | grep -q 'NOTE: UNCONFIRMED'; then ok "C58 R3 docs/zero-gap/cell-notes.tsv annotates a red cell with an UNCONFIRMED note without changing its status"; else bad "C58 got '$(cell modA e2e)' / '$(reasonof modA e2e)'"; fi
    # F5 duplicate subjects: both rows stay, totals print raw and de-duplicated, and only an identical pin is honoured
    ( cd "$M/modB" && git commit -q --allow-empty -m diverge-from-modA ) >/dev/null 2>&1   # the fixture's modA/modB commits can hash identically; make modB's pin really differ
    printf 'duplicate\tof\treason\nmodB\tmodA\tdeclared although the pins differ\n' >"$M/docs/zero-gap/duplicate-subjects.tsv"
    bash "$SELF" --root "$M" --out "$M/out-d0.tsv" >"$T/d0.stdout" 2>"$T/d0.stderr"
    if grep -q "'modB' refused: checked-out HEADs differ" "$T/d0.stderr" && awk '/^coverage totals:/ { if ($4 == $10) ok = 1 } END { exit !ok }' "$T/d0.stdout"; then ok "C35 F5 a duplicate declaration whose pins DIFFER is refused loudly and de-duplicates nothing (raw == de-duplicated)"; else bad "C35 stderr=$(cat "$T/d0.stderr") totals=$(grep '^coverage totals' "$T/d0.stdout")"; fi
    printf '[submodule "modC"]\n\tpath = modC\n\turl = git@github.com:acme/modC.git\n' >>"$M/.gitmodules"
    git clone -q "$M/modA" "$M/modC" >/dev/null 2>&1
    printf 'duplicate\tof\treason\nmodC\tmodA\tsame commit under a second gitlink (proof fixture)\n' >"$M/docs/zero-gap/duplicate-subjects.tsv"
    bash "$SELF" --root "$M" --out "$M/out-d1.tsv" >"$T/d1.stdout" 2>"$T/d1.stderr"
    nraw=$(awk '/^coverage totals:/ {print $4}' "$T/d1.stdout"); ndd=$(awk '/^coverage totals:/ {print $10}' "$T/d1.stdout"); nc=$(awk -F'\t' '$1=="modC"' "$M/out-d1.tsv" | wc -l)
    if [ -n "$nraw" ] && [ "$nc" -eq 12 ] && [ "$((nraw - ndd))" -eq 12 ] && [ ! -s "$T/d1.stderr" ]; then ok "C36 F5 identical pins: modC is declared a duplicate of modA; its 12 rows stay in coverage.tsv, the totals line prints raw=$nraw and de-duplicated=$ndd"; else bad "C36 raw=$nraw dedup=$ndd modC-rows=$nc stderr=$(cat "$T/d1.stderr")"; fi
    printf 'duplicate\tof\treason\nmodC\tmodA\t\nmodX\tmodA\tnot a subject\nmodA\tmodA\tself\n' >"$M/docs/zero-gap/duplicate-subjects.tsv"
    bash "$SELF" --root "$M" --out "$M/out-d2.tsv" >"$T/d2.stdout" 2>"$T/d2.stderr"
    if [ "$(grep -c 'refused' "$T/d2.stderr")" -eq 3 ] && awk '/^coverage totals:/ { if ($4 == $10) ok = 1 } END { exit !ok }' "$T/d2.stdout"; then ok "C37 F5 refused: empty reason, a non-subject, a self-duplicate (3 refusals, nothing de-duplicated)"; else bad "C37 stderr=$(cat "$T/d2.stderr")"; fi
    rm -f "$M/docs/zero-gap/duplicate-subjects.tsv"
    local cand="$M/cycle-2-candidates.tsv"
    if [ -f "$cand" ] && [ "$(head -1 "$cand")" = "$(printf 'subject\ttest_kind\tstatus\treason\tref')" ] \
       && awk -F'\t' 'NR>1 && NF!=5 {x=1} END{exit x}' "$cand" \
       && awk -F'\t' '$1=="modA" && $2=="e2e" && $3=="check-red"{a=1} $1=="modA" && $2=="regression" && $3=="gap:evidence-mismatch"{b=1} $1=="modA" && $2=="integration"{c=1} $1=="modA" && $2=="security"{d=1} END{exit !(a&&b&&!c&&!d)}' "$cand"; then
        ok "C21 cycle-2-candidates.tsv is generated: 5 columns; lists check-red and evidence-mismatch cells; omits check and designed-red cells"
    else bad "C21 cycle-2-candidates.tsv missing or wrong ($(head -3 "$cand" 2>/dev/null | tr '\t' '|'))"; fi
    # C22 the measurer: no hard-coded rc, real failed counts, bound evidence header
    local mpy; mpy="$(dirname "$SELF")/zero-gap-coverage-measure.py"
    python3 "$mpy" --selftest >"$T/mst.out" 2>&1 && mst_rc=0 || mst_rc=1
    if [ "$mst_rc" -eq 0 ]; then ok "C22 measurer --selftest: worst rc and failed count aggregated for real, check/check-red classified, head/tree/ts bound ($(tail -1 "$T/mst.out"))"; else bad "C22 measurer --selftest failed: $(tail -3 "$T/mst.out" | tr '\n' ' ')"; fi

    # C22b one assertion per T061-round-2 rule must be PRESENT and PASSING in the measurer's own selftest
    local rule miss=""
    for rule in 'F2 env-only' 'F2 failed>0 PLUS env build failure => stays check-red' 'F2 a compile error' 'F2 timeout (rc 124) after a real failed test' 'F3 620 failing tests' 'F3 62 failures are all listable' 'F3 gate: failing case identifiers' 'records the limit' 'R3 P1 compile error' 'R3 P2 typo import' 'R3 P3 missing go.sum' 'R3 P4 init panic' 'R3 mixed unbuilt' 'R3 evidence names every unbuilt package' 'R3 the sealed region'; do
        grep -F "$rule" "$T/mst.out" | grep -q '^  PASS' || miss="$miss [$rule]"
    done
    [ -z "$miss" ] && ok "C22b measurer selftest carries and passes a case for each round-2 rule (F2 env vs real failure, F3 failing names, F4 limit recorded) and the four round-3 reviewer probes P1-P4 plus per-package cause and the sealed region" || bad "C22b missing/failed in the measurer selftest:$miss"

    # ── live tree: contract-shaped output, live tree left untouched by this proof ────────────
    h0=$(find "$LIVE/scripts/zero-gap-coverage.sh" "$LIVE/docs/zero-gap/coverage.tsv" -type f -exec sha256sum {} + 2>/dev/null | LC_ALL=C sort | sha256sum)
    out5="$T/live.tsv"
    outp=$(timeout 300 bash "$SELF" --root "$LIVE" --out "$out5" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ -f "$out5" ] && [ "$(head -1 "$out5")" = "$(printf 'subject\ttest_kind\tstatus\tref')" ] && [ "$(($(wc -l <"$out5") - 1))" -gt 0 ]; then
        ok "C11 live tree: generation succeeds (rc 0), well-formed header, at least one row"
    else
        bad "C11 live rc=$rc out5_exists=$([ -f "$out5" ] && echo y || echo n) $(printf '%s' "$outp" | head -c 200)"
    fi
    h1=$(find "$LIVE/scripts/zero-gap-coverage.sh" "$LIVE/docs/zero-gap/coverage.tsv" -type f -exec sha256sum {} + 2>/dev/null | LC_ALL=C sort | sha256sum)
    if [ "$h0" = "$h1" ]; then ok "C12 live tree's own files (this script + the tracked coverage.tsv) byte-identical before/after — the proof writes only to \$T"; else bad "C12 live files changed during the proof"; fi

    echo "zero-gap-coverage proof: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}

if [ "$PROVE" -eq 1 ]; then
    prove_failure
    exit $?
fi

if [ -z "$ROOT" ]; then ROOT=$(cd "$(dirname "$SELF")/.." && pwd); fi
if [ -z "$OUT" ]; then OUT="$ROOT/docs/zero-gap/coverage.tsv"; fi
generate "$ROOT" "$OUT"
exit $?
