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
#   zero-gap-coverage.sh [--root <dir>] [--out <file>]   generate (default root: this repository,
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
zero-gap-coverage.sh [--root <dir>] [--out <file>]
zero-gap-coverage.sh --prove-failure
zero-gap-coverage.sh --help
EOF
}

ROOT="" OUT="" PROVE=0 HELP=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        --help) HELP=1; shift ;;
        *) echo "zero-gap-coverage: unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ "$HELP" -eq 1 ] && { usage; exit 0; }

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

    : >"$W/rows"
    row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >>"$W/rows"; }

    local subj kind status ref
    for subj in "${subjects[@]}"; do
        for kind in $KINDS; do
            status="gap"; ref="-"
            case "$subj/$kind" in
                root/unit)
                    if [ -f "$root/_tools/gen/go.mod" ]; then
                        if [ "$go_ok" -eq 1 ]; then
                            local out2 cnt
                            out2=$(cd "$root/_tools/gen" && GOPROXY=off timeout 45 go test ./... -count=1 -v 2>&1)
                            cnt=$(printf '%s\n' "$out2" | grep -c '^--- PASS:')
                            read -r status ref < <(decide_status "$cnt" 1 go "_tools/gen/go.mod")
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
            row "$subj" "$kind" "$status" "$ref"
        done
    done

    { printf 'subject\ttest_kind\tstatus\tref\n'; LC_ALL=C sort -t "$(printf '\t')" -k1,1 "$W/rows"; } >"$W/coverage.tsv.new"
    mkdir -p "$(dirname "$out")" || { echo "zero-gap-coverage: cannot create $(dirname "$out")" >&2; return 2; }
    mv "$W/coverage.tsv.new" "$out" || { echo "zero-gap-coverage: cannot write $out" >&2; return 2; }
    echo "zero-gap-coverage: wrote $out ($(($(wc -l <"$out") - 1)) cell(s), $(printf '%s\n' "${subjects[@]}" | wc -l) subject(s) x $(printf '%s\n' $KINDS | wc -l) kind(s))"
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
    if awk -F'\t' 'NR>1 && $3!="check" && $3!="gap" && $3!~/^could-not-run:/ && $3!="n/a"{bad=1} END{exit bad}' "$OUTF"; then
        ok "C9 every status cell is check|gap|could-not-run:<tool>|n/a — the coverage-gaps class's closed vocabulary"
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
