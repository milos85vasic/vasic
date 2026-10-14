#!/usr/bin/env bash
# zero-gap-class-stale-figures.sh — sweep class `stale-figures` (feature 010, task T019).
#
# ── WHAT IT DETECTS ───────────────────────────────────────────────────────────
# RECORDED FIGURES that a reader takes as measured facts, and that either
#   (a) no longer agree with a fresh re-measurement, or
#   (b) have NO re-measure command at all.
#
#   (a) Every claim row of docs/claim-ledger.tsv is re-measured by the EXISTING
#       instrument scripts/verify-claim-ledger.sh (§11.4.266), which this class
#       RUNS (--verbose) and whose per-row verdict it maps onto located findings.
#       The re-measure mechanism is not reimplemented here: the probe is run, and
#       the claimed-vs-real comparison is made, by that gate. This class only
#       LOCATES each verdict (the Nth occurrence of a row's anchor is the Nth
#       match of that anchor in its surface, the same Python `re` pattern with
#       MULTILINE on that the gate compiles).
#         FALSE occurrence N  -> FINDING at figure:<surface>:<line of match N>
#         ORPHAN / MALFORMED / UNTYPED / duplicate id -> FINDING at claim:<id>
#         UNDETERMINED (probe would not run, absent surface, bad anchor)
#                            -> COULD-NOT-INSPECT claim:<id>, never clean
#   (b) Every OTHER recorded figure in the scanned documents is a FINDING
#       "recorded figure without a re-measure command". A figure is a line
#       matching one of four shapes (after `~~struck-through~~` spans are
#       removed; M = optional markdown markup [*`_]*):
#         <n>M<ws>M<noun>   n = [0-9][0-9,]*, noun one of files tests gates
#                           scripts anchors lines commits items rows checks
#                           submodules bytes (singular or plural) PASS FAIL
#                           CURRENT DRIFT  (case-sensitive, word-bounded)
#         <n> of <n>        e.g. "12 of 14"
#         <n>/<n>           e.g. "5/9"
#         exit/rc N         exit, exits, exited or rc, then N (blank or `=`,
#                           markup allowed): "exits **1**", "rc=2", "rc 2"
#       A hex id (a commit/blob sha) is NOT a figure: a line whose only
#       number-like token is a hex id is not in the population (reconcile 5).
#       SEVERITY AND GROUPING (reconcile 5):
#         medium, one finding per LINE at figure:<doc>:<line>, when the line
#           states a verification status (PASS FAIL UNDET CURRENT DRIFT
#           VERIFIED DEBT), an exit/rc figure, or a security word;
#         low, ONE aggregate finding per DOCUMENT at figures:<doc> for every
#           other unledgered figure line, naming the count and the first 30
#           line numbers ("on line(s) 8 12 14:"; "(+N more)" beyond 30).
#       Ledger-verified FALSE figures always stay per line (high on a status
#       line or a verification bluff type / blocker row, else medium).
#
# ── "<n> declared" vs .gitmodules (VSC-353 clause B) ──────────────────────────
# The count of paths .gitmodules declares is read from the working tree AT --root
# (lines `path = ...`; never from carrier prose). Every figure line that is still in the
# population after the exclusions below is searched for three shapes. MARKUP COVERED (round 5), exactly:
# a run of the characters * ` _ (so **, __, backtick, _ and mixtures; markdown emphasis, strong, code)
# may sit (i) immediately before the number ("**13**", "_13_"), (ii) between any two words of a shape,
# on either side of the whitespace ("gitlinks **are** declared", "are _declared_", "`are declared`"),
# (iii) after the last word, and (iv) before the closing punctuation or parenthesis of "<n> declared".
# NOT covered: any other markup (links [13](url), HTML <b>13</b>, ==highlight==, "quotes", ~~strike~~
# which is deliberately blanked); each is pinned silent by probe clause H3. The count cannot be
# glued to a letter or digit before it, and a decimal ("13.5 gitlinks") is not read as 5.
#   S1  "<n> declared" followed by end of line, closing punctuation/markup, or a fleet noun
#       (submodule(s), gitlink(s), module(s), repo(s), repositories, path(s), "in total",
#       "in all")                                          e.g. "13 declared." "13 declared submodules"
#   B1  "<n> <fleet noun> <verb> declared"                  e.g. "13 gitlinks are declared"
#       (fleet noun: submodule(s), gitlink(s), module(s), repo(s), repositories, path(s); verb: is,
#       are, was, were, each optionally followed by "now" ("are now declared"), or "has been" /
#       "have been" ("have been declared")).
#       This shape ALSO enters the figure population: a line whose only figure is
#       "13 gitlinks are declared" is a figure line (it matches no other figure shape).
#   B2  "<n> declared <adverb>", adverb one of today, now, currently, "so far"
#                                                           e.g. "**14** declared today"
# All three shapes are CASE-INSENSITIVE ("14 Declared.", "13 GITLINKS ARE DECLARED", "13 gitlinks are
# Declared" are compared; pinned by --prove-failure G19-G28). Each such n that differs from the .gitmodules path count is a medium FINDING at
# figure:<doc>:<line> reading "claims <n> declared but .gitmodules declares <m> (mismatch):
# ..." (names BOTH figures); equal counts add nothing. No .gitmodules, or one with no path
# => comparison skipped, no finding, and a "NOTE:" line on STDERR (the stdout class contract
# has no NOTE token); an unreadable/special .gitmodules is COULD-NOT-INSPECT. There is NO
# "owned" comparison: no honest source for an owned count exists in a bare tree.
# EXCLUSIONS APPLIED BEFORE THE COMPARISON (a line removed by any of them is never compared;
# the full text of each is under THE SKIP RULE and the sections after it):
#   1. a skip word (withdrawn superseded historical obsolete) anywhere on the line, even
#      when it withdraws a DIFFERENT figure than the "declared" one on that same line;
#   2. the deictic next-line rule: the NEXT physical line opens with "That/This/It/...
#      <...> WITHDRAWN|SUPERSEDED|HISTORICAL|OBSOLETE" in its first sentence;
#   3. exit-code-meaning-only lines ("exit 0 = clean, exit 1 = finding");
#   4. the dated "§3" caption gate (docs/zero-gap/point-in-time.tsv rows whose reason holds
#      "own dated caption"): an exempt line leaves the population entirely;
#   5. mirror dedup: a line of AGENTS.md/QWEN.md/GEMINI.md byte-identical to a CLAUDE.md
#      figure line is not compared again (CLAUDE.md carries it);
#   plus the text of any `~~struck~~` span, which is blanked before the shapes are tried.
# RECALL COST (the shapes below are NOT compared; the list is exhaustive for the shapes tried in
# round 5, not for every possible phrasing, and each listed shape is pinned silent by the named test
# with a paired control proving the silence is caused by the listed cost):
#   * "13 gitlinks are all declared", "...are not declared", "Thirteen gitlinks are declared", a
#     linked or HTML-wrapped number, "13.5 gitlinks", "13 gitlinks (are declared)", "13 gitlinks, all
#     declared", "13-gitlink fleet is declared", "~~declared~~", "==declared==", a quoted "declared",
#     "13 owned gitlinks are declared", "will be / got declared", "13 path-entries are declared":
#     probe clause H3 (box hz, each line with a detected twin in box ht);
#   * "declared: 14" (the number AFTER the word), "14 submodules declared" (noun between the number
#     and "declared", no verb), number words ("fourteen declared") and a number wrapped onto the
#     previous physical line before "declared": probe clause H (box hk);
#   * "13 declared in <place>", "13 declared entries", "13 declared owned": probe clause H2 (box hs;
#     any "<n> declared <other noun or word>" outside S1/B2 is the same case; "9 declared pairs"
#     and "76 declared members" are deliberate, --prove-failure G7/G8, they are not fleet counts);
#   * a fleet claim whose noun ("13" / "gitlinks are declared") or verb ("13 gitlinks are" /
#     "declared.") wraps onto the next physical line: probe clause H2 (box hs, the line is split
#     before it is read);
#   * a stale figure on a line that carries a skip word for an UNRELATED figure (exclusion 1 is
#     line-level and cannot tell which figure the word withdraws): probe clause H2 (box hs);
#   * a stale figure on a line the deictic next-line rule exempts ("That figure is WITHDRAWN." on
#     the next line): probe clause H2 (box hs, with a non-deictic next-line control that IS
#     reported), and on a line under a dated "section 3" caption (point-in-time.tsv): probe clause
#     H2 (box hc, with the undated entry as the control that IS reported);
#   * "owned" figures are detected as figures but never compared with a real count (no honest
#     source for an owned count in a bare tree): not pinned by a test, it is the absence of a
#     clause (probe clause E states it);
#   * any phrasing that is neither in the grammar above nor in the H3 list is outside it and NOT
#     pinned (a verifier can always invent another); the grammar is the specification, not a proof
#     of completeness.
# The same false-negative price is paid by a false positive of the same wording: it is
# equally not reported.
#
# ── THE SKIP RULE (historical / withdrawn text), PRECISELY ────────────────────
# A scanned line whose text — after `~~...~~` spans are removed — contains, as a
# whole word and case-insensitively, one of  withdrawn  superseded  historical
# obsolete  is an ANNOTATED HISTORICAL line: it is not a live claim and is NOT
# part of the unledgered-figure population. A figure that only occurs inside a
# `~~...~~` span is likewise not a figure. The base rule is LINE-level: a withdrawal
# stated on the PREVIOUS line does not cover the next one (this repository often
# puts a withdrawn and a live figure in one paragraph, so a paragraph-level rule
# would hide live figures), with TWO narrow, measured extensions (VSC-353):
#   DEICTIC NEXT-LINE RULE: a figure line is also dropped when the line IMMEDIATELY AFTER
#     it opens (after optional blanks, ">", "*", "_", backtick, "(" or "[") with a deictic
#     subject (that, this, the above, it, which, those, these, the figure, the reading,
#     the sentence) and names withdrawn/superseded/historical/obsolete within 100
#     characters of it WITHOUT passing a sentence end (. ! ?). "That figure is WITHDRAWN
#     and kept as a record." annotates the line above; a bare marker anywhere else on the
#     next line does NOT, and a withdrawal two lines below does NOT.
#   EXIT-MEANING RULE: a line whose every figure is an exit/rc shape immediately followed
#     by "=", an arrow (-> or the unicode arrow) or "means" ("exit 0 = clean, exit 1 =
#     finding") states what a code MEANS and is dropped. A measured status ("exits 0 at 12
#     CURRENT") has a different tail and stays a figure, as does any line that also carries
#     a non-rc figure.
# Lines matched by a ledger anchor are ALWAYS in the
# population, annotated or not, because the ledger gate checks every occurrence.
#
# ── THE MIRROR RULE ───────────────────────────────────────────────────────────
# AGENTS.md, QWEN.md and GEMINI.md mirror CLAUDE.md (cascade check C5). A figure
# line of a mirror whose FULL TEXT is byte-identical to a figure line of
# CLAUDE.md is inspected but NOT reported: the CLAUDE.md line carries the
# finding (or its ledger verdict). A mirror line that DRIFTED from CLAUDE.md is
# not identical and is reported on its own. This does not trust C5: it compares
# the text itself.
#
# ── POINT-IN-TIME §3 ENTRIES (feature 010, T091) ─────────────────────────────
# docs/zero-gap/point-in-time.tsv (the same tracked exemption list doc-count-drift
# reads; read-only DATA, never edited by this class) may carry a row whose reason
# contains the literal phrase "own dated caption". Such a row is NOT the whole-
# document exemption doc-count-drift applies for its own rows: it CAPTION-GATES
# one of this class's six documents (in practice CONTINUATION.md, the only one of
# the six inside that document's own "§3" section: a line is exempt only when (a)
# the row's path (fnmatch) matches the document, (b) the line sits under the
# nearest preceding "### ... " entry heading, (c) that heading itself contains a
# YYYY-MM-DD date, and (d) that entry's own nearest preceding "## ..." section
# heading contains "§3". An entry heading with NO date is not exempt (its lines
# stay findings); text before the first entry heading of "§3" is not exempt
# either. A caption-gated exempt line is dropped from the population entirely
# (mirrors how a WITHDRAWN/SUPERSEDED line is already excluded above), not
# merely unreported. A row missing a path or a reason is COULD-NOT-INSPECT at
# its own point-in-time.tsv:<n> (an exemption without its reason is refused,
# never silently kept). A row whose reason lacks the marker phrase is a
# doc-count-drift blanket row and is ignored here. A caption-gated row matching
# none of this class's six documents is not reported (it may be doc-count-
# drift's own row over a document this class does not scan).
#
# ── POPULATION, AND WHY (docs/zero-gap/sweep-classes.tsv row `stale-figures`) ──
# BOUNDARY RULING (progress.yml reconcile 6): this class owns the four root
# carriers CLAUDE.md AGENTS.md QWEN.md GEMINI.md, CONTINUATION.md, README.md and
# every line a docs/claim-ledger.tsv anchor matches (whatever file it is in);
# docs/**/*.md belongs to class doc-count-drift and is NOT scanned here.
# Documents are enumerated with
#   git ls-files -z --cached --others --exclude-standard -- <the six names>
# (tracked PLUS untracked-not-ignored: a new document is a claim surface before
# it is committed), plus every claim row of docs/claim-ledger.tsv. Items:
#   figures:<doc>         each scanned document (the home of its LOW aggregate)
#   figure:<doc>:<line>   a non-historical line carrying a figure, and every line
#                         a ledger anchor matches (whatever its shape)
#   claim:<id>            a claim row of docs/claim-ledger.tsv
#                         (claim:-ledger-line-<n> when the row has no id)
# These are the documents a reader takes measured facts from; the ledger alone
# re-measures a hand-picked slice (research D8), so a figure outside it can go
# stale with every gate green. Nothing is enumerated from a hand list of claims.
# With --corpus <dir> the same rules apply to the files under <dir> (find, no
# git). _tests/fixtures/zero-gap/ is outside the document set by construction.
#
# ── SYMLINKS AND SPECIAL FILES ───────────────────────────────────────────────
# A document, the ledger or a ledger surface that is a symbolic link, is not a
# regular file (FIFO, device, socket), or resolves outside the scanned tree is
# COULD-NOT-INSPECT and is never opened (a FIFO would block, /dev/zero would
# exhaust memory, a link leaving the tree would echo outside text). When any
# ledger surface is such a file, scripts/verify-claim-ledger.sh (which opens
# every surface itself) is NOT run and every row is undetermined. The gate run
# is bounded by `timeout -k 5 300`.
#
# ── ROUND 5 (2026-10-14) ── markup tolerance, "submodule paths", "14 declared (current)." ──────────
# Re-measured on the live tree after round 5: rc 1, 298 findings (1 high, 294 medium, 3 low),
# INSPECTED 679; the pre-round-5 script run on the SAME tree gives the same 298 findings, the same
# INSPECTED and the same located items (diffed), so round 5 added recall on planted shapes and
# changed no live count (the tree itself moved since the block below: README.md:462 is now the one
# mismatch, "13 gitlinks are declared" against 22). Precision re-sampled at SAMPLE OFFSET 2 (the
# 2nd, 27th, 52nd ... of the 294 medium findings in output order, 12 read with context): 9 true,
# 3 false (exit/rc behaviour lines: CONTINUATION.md 4829, 5217, 9171) = 75 percent.
#
# ── MEASURED ON THE LIVE TREE (2026-10-12; first measured after the VSC-353 B1/B2 round, re-measured
#    unchanged after round 4: case-insensitive comparison and the "have/has been", "are now" B1 forms) ───
# `bash scripts/zero-gap-class-stale-figures.sh --root .` (date -u +%F = 2026-10-12): rc 1,
# 1 high (the ledger row), 294 medium (CONTINUATION.md 293, README.md 1) and 2 low
# aggregates (CONTINUATION.md, README.md); INSPECTED 675, was 674 before B1 (+1 item: figure:README.md:457,
# the one line only the new shape puts in the population; its low aggregate is the new
# README.md low finding).
# CLAUDE.md, AGENTS.md, QWEN.md and GEMINI.md carry no FINDING in this run (cause NOT
# investigated here). The ONE new mismatch finding B1/B2 produced is README.md:457
# ("13 gitlinks are declared" against 22 .gitmodules paths, a line dated 2026-09-03); B2
# produced none live. Round 4 changed no count: INSPECTED 675 and 297 findings, as after round 3.
# Hand-read precision (re-sampled 2026-10-12 after round 4): the 294 medium findings in output order,
# SAMPLE OFFSET 2 (the 2nd, 27th, 52nd, ... every 25th: 12 findings, indices 2 27 52 77 102 127 152
# 177 202 227 252 277), each read with one line of context on each side. 9 true positives (a
# measured status or a dated reading stated as a fact: CONTINUATION.md 10242 "exits 0 today", 10815
# the 173 PASS split, 11296 the dated 6 CURRENT table row, 2386 a printed "exit 0", 4171 the ng test
# EXIT=1 table, 6254 gate table, 6760 "the run exited 2", 8137 registry 20 PASS, 9669 the chunker
# "exits 1"), 3 false positives, one class: a line describing exit-code or rc BEHAVIOUR as a
# contract rather than a measured value (CONTINUATION.md 4829 mutant-case table "-> rc 2", 5217
# "unreachable -> rc 2", 9171 "an absent scanroot rc 2"). Precision 9/12 = 75 percent (small sample,
# wide interval). The round 3 sample (7 of 12 = 58 percent) was taken at a different, unrecorded
# offset and is not comparable; read the two together as "roughly 58 to 75 percent". The aggregate
# "recorded figure without a re-measure command" findings are reported as unledgered, not
# as proven stale. The 2026-09-26 block below is HISTORICAL: it predates the deictic
# next-line and exit-meaning rules.
#
# ── MEASURED ON THE LIVE TREE (2026-09-26, after the review fix round; HISTORICAL) ──
# rc 1 in 9 s: 1 high (the ledger row the KNOWN SEED describes), 514 medium
# (CONTINUATION.md 412, CLAUDE.md 96, README.md 7 — AGENTS/QWEN/GEMINI lines are
# byte-identical to CLAUDE.md and deduped) and 2 low aggregates (CLAUDE.md 59
# lines, CONTINUATION.md 475 lines); INSPECTED 1540. Before the fix round:
# 2676 findings over docs/** with hex ids counted. Hand-read of 10 medium hits
# (every 52nd): 7 are recorded figures stated as measured facts; 3 are not (a
# withdrawn quote whose WITHDRAWN marker is on the next line; two lines stating
# exit-code SEMANTICS, "exit 0 = push OK", "a skip exits 0"). Precision 7/10 (HISTORICAL).
#
# ── WHAT IT DOES NOT SEE ─────────────────────────────────────────────────────
#   * Whether an UNLEDGERED figure is actually stale: it reports that nothing
#     re-measures it, not that it is wrong. Staleness is proven only for ledger
#     rows (a) — widening the ledger is task T066.
#   * Figures stated in words ("three gates"), percentages, byte sizes written
#     "1.7M", version strings, and nouns outside the list above.
#   * Oracle strength: a VERIFIED row proves the claim equals what its probe
#     printed, not that the probe measures the right thing (§11.4.245).
#   * docs/**/*.md (class doc-count-drift), submodule carriers, specs/**, other
#     Markdown — except lines a ledger anchor matches.
#   * A withdrawal stated on a different line from the figure it withdraws is honoured
#     ONLY by the deictic next-line rule (THE SKIP RULE); a withdrawal two or more lines
#     away, or on the previous line, leaves the figure REPORTED. An unannotated
#     historical figure is reported. An exit-code MEANING line ("exit 0 = clean, exit 1 =
#     finding") is SUPPRESSED; an exit/rc line that describes BEHAVIOUR without
#     "=", an arrow or "means" ("refused with exit 1") is still reported (a measured
#     false-positive class, see the 2026-10-12 sample).
#   * Every "<n> declared" shape the comparison misses (see the RECALL COST list under
#     the clause-B section): "declared: 14", "14 submodules declared", number words,
#     a number wrapped onto the previous line, "13 declared in <place>", and a skip
#     word that withdraws an unrelated figure on the same line.
#   * The <n>/<n> shape also matches non-claims (a fraction in a URL): such a
#     line is reported as unledgered, never silently dropped.
#   * A lone CR (not CRLF) is read as a line break, the same open mode the ledger
#     gate uses, so both agree on line numbers; `grep -n` counts such a file
#     differently.
#   * The gate's 300 s time limit is a defence only; --prove-failure does not
#     exercise it (a hanging probe would cost the battery 300 s).
#
# ── USAGE / EXIT CODES ───────────────────────────────────────────────────────
#   zero-gap-class-stale-figures.sh --root <dir> [--corpus <dir>] [--emit-population]
#   zero-gap-class-stale-figures.sh --prove-failure
#   0  every item inspected, no finding (a non-empty population)
#   1  at least one FINDING (outranks 2)
#   2  could not determine: empty population, --root not a directory, no git
#      work tree, python3 broken, the ledger gate absent or unparseable, a row
#      the gate could not re-measure. 2 is never a pass.
# Output follows docs/zero-gap/README.md "The class contract" (FINDING /
# COULD-NOT-INSPECT / INSPECTED / POPULATION-SHA; percent-encoded tokens).
# Never writes into --root or --corpus; temp files only under $TMPDIR (mktemp).
# The ledger probes it runs are the ledger's own (read-only by design; the live
# ones were read before this class adopted them).
set -uo pipefail
export LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1

# >>> zg_pct_encode (feature 010 class contract; copy verbatim)
# zg_pct_encode_z: NUL-separated raw items on stdin -> one canonical token per line.
# Every byte outside A-Z a-z 0-9 . _ ~ / + : @ , = - becomes %XX (uppercase hex).
zg_pct_encode_z() {
    LC_ALL=C od -An -v -tx1 | LC_ALL=C awk '
        BEGIN { hx = "0123456789abcdef"; safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-"; tok = ""; pending = 0 }
        { for (i = 1; i <= NF; i++) {
              if ($i == "00") { print tok; tok = ""; pending = 0; continue }
              pending = 1
              v = (index(hx, substr($i, 1, 1)) - 1) * 16 + index(hx, substr($i, 2, 1)) - 1
              c = (v > 32 && v < 127) ? sprintf("%c", v) : ""
              if (c != "" && index(safe, c) > 0) tok = tok c; else tok = tok "%" toupper($i)
          } }
        END { if (pending) print tok }'
}
# zg_pct_encode <string>: one item -> one canonical token.
zg_pct_encode() { printf '%s\0' "$1" | zg_pct_encode_z; }
# <<< zg_pct_encode

CLASS_ID=stale-figures
SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
SELFDIR="$(dirname -- "$SELF")"
EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 || shift ;;
        --corpus) CORPUS="${2:-}"; shift 2 || shift ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) sed -n '2,/^set -uo pipefail/p' "$SELF" | sed '$d'; exit 0 ;;
        *) printf 'zero-gap-class-%s: unknown argument: %s\n' "$CLASS_ID" "$1" >&2; exit 2 ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# --prove-failure: paired proof on THROWAWAY copies of the corpus. Every run is
# a real invocation of this script under a minimal environment; the live tree
# (the corpus, this script, the ledger gate) is fingerprinted before and after
# and must be byte-identical. Exit 0 all arms behave, 1 an arm misbehaved, 2 the
# battery could not be built.
# ─────────────────────────────────────────────────────────────────────────────
prove_failure() {
    local repo corp gate passed=0 failed=0 fp0 fp1 rc
    repo="$(cd -- "$SELFDIR/.." && pwd -P)"
    corp="$repo/_tests/fixtures/zero-gap/$CLASS_ID"
    gate="$SELFDIR/verify-claim-ledger.sh"
    for t in git python3 sha256sum; do
        command -v "$t" >/dev/null 2>&1 || { echo "UNDETERMINED: $t is not on PATH; the battery cannot run" >&2; return 2; }
    done
    for p in "$corp/planted" "$corp/clean" "$corp/expect.tsv" "$gate"; do
        [ -e "$p" ] || { echo "UNDETERMINED: $p is absent; the battery cannot run" >&2; return 2; }
    done
    live_fp() { { find "$corp" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum; sha256sum "$SELF" "$gate"; } 2>/dev/null | sha256sum | cut -d' ' -f1; }
    fp0=$(live_fp)
    lab=$(mktemp -d) || { echo "UNDETERMINED: mktemp failed" >&2; return 2; }
    trap 'rm -rf "$lab"' EXIT
    mkdir -p "$lab/tmp"

    # runc <outfile> <script> <args...> -> rc of the class under a minimal env
    runc() {
        local out=$1 s=$2; shift 2
        env -i PATH="${RUN_PATH:-$PATH}" HOME="$lab" TMPDIR="$lab/tmp" LC_ALL=C LANG=C \
            bash "$s" "$@" >"$out" 2>"$out.err" </dev/null
    }
    # grammar_ok <outfile> <rc>: the output obeys the class output contract
    grammar_ok() {
        local f=$1 rc=$2 ni np nf nc
        if LC_ALL=C grep -Evq '^(FINDING stale-figures (critical|high|medium|low) [a-z-]+ [^ ]+ .+ [^ ]+|COULD-NOT-INSPECT [^ ]+ .+|INSPECTED [0-9]+|POPULATION-SHA [0-9a-f]{64}|)$' "$f"; then return 1; fi
        ni=$(grep -c '^INSPECTED ' "$f"); np=$(grep -c '^POPULATION-SHA ' "$f")
        nf=$(grep -c '^FINDING ' "$f"); nc=$(grep -c '^COULD-NOT-INSPECT ' "$f")
        [ "$ni" -eq 1 ] && [ "$np" -eq 1 ] || return 1
        case "$rc" in
            0) [ "$nf" -eq 0 ] && [ "$nc" -eq 0 ] ;;
            1) [ "$nf" -gt 0 ] ;;
            2) [ "$nf" -eq 0 ] && [ "$nc" -gt 0 ] ;;
            *) return 1 ;;
        esac
    }
    locs() { awk '$1 == "FINDING" { print $5 }' "$1" | LC_ALL=C sort -u; }
    ok()  { printf 'PASS %s\n' "$1"; passed=$((passed + 1)); }
    bad() { printf 'FAIL %s\n' "$1"; [ -f "${2:-}" ] && sed 's/^/       | /' "$2" | head -12; failed=$((failed + 1)); }
    # mklab <name> <src> [git]: a throwaway copy of a corpus part
    mklab() {
        rm -rf "${lab:?}/$1"; cp -R "$2" "$lab/$1"
        if [ "${3:-}" = git ]; then git -C "$lab/$1" init -q 2>/dev/null || return 1; fi
    }
    labsum() { find "$lab/$1" -path "$lab/$1/.git" -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1; }
    # mutate <name> <shell body>: the body MUST change the lab (an inoperative mutation is refused)
    mutate() {
        local b a; b=$(labsum "$1"); ( cd "$lab/$1" && bash -c "$2" ) >/dev/null 2>&1; a=$(labsum "$1")
        [ "$b" != "$a" ]
    }
    # arm <label> <want-rc> <name> <mode corpus|live> [want-location]
    arm() {
        local label=$1 want=$2 name=$3 mode=$4 loc=${5:-} rc out="$lab/out.$3"
        if [ "$mode" = corpus ]; then runc "$out" "$SELF" --root "$lab/$name" --corpus "$lab/$name"; rc=$?
        else runc "$out" "$SELF" --root "$lab/$name"; rc=$?; fi
        if [ "$rc" != "$want" ]; then bad "$label (wanted rc $want, got $rc)" "$out"; return; fi
        if ! grammar_ok "$out" "$rc"; then bad "$label (output violates the class contract)" "$out"; return; fi
        # here-string, never `producer | grep -q` under pipefail
        if [ -n "$loc" ] && ! grep -qxF -- "$loc" <<<"$(locs "$out")"; then bad "$label (no FINDING at $loc)" "$out"; return; fi
        ok "$label (rc $rc)"
    }
    # sevof <outfile> <location> -> the severity (or severities) reported at that location
    sevof() { awk -v l="$2" '$1 == "FINDING" && $5 == l { print $3 }' "$1" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'; }
    # linesof <outfile> <location> -> the line list an aggregate figures:<doc> finding names
    linesof() { awk -v l="$2" '$1 == "FINDING" && $5 == l' "$1" | sed -n 's/.* on line(s) \([0-9 ]*\):.*/\1/p'; }
    # timed <outfile> <args...>: a run that must END (a hang is a defect, not a slow pass)
    timed() {
        local out=$1; shift
        env -i PATH="$PATH" HOME="$lab" TMPDIR="$lab/tmp" LC_ALL=C LANG=C \
            timeout -k 5 60 bash "$SELF" "$@" >"$out" 2>"$out.err" </dev/null
    }

    echo "== prove-failure: class $CLASS_ID must tell a stale or unmeasured figure from a measured one, and refuse to guess =="

    # C0 — the clean control, corpus mode: nothing fires, the population is non-empty.
    mklab c0 "$corp/clean"
    arm "C0  CONTROL: clean corpus (ledgered figures, WITHDRAWN/struck/historical lines, identical mirror) fires nothing" 0 c0 corpus
    n=$(awk '$1=="INSPECTED"{print $2}' "$lab/out.c0" 2>/dev/null)
    if [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null; then ok "C0b the clean control inspected a non-empty population ($n items)"; else bad "C0b the clean control did not report a positive INSPECTED count" "$lab/out.c0"; fi

    # C1 — the clean control in LIVE mode (a git work tree): rc 0, and the live run walks exactly
    #      the set --emit-population prints.
    mklab c1 "$corp/clean" git || { echo "UNDETERMINED: git init failed" >&2; return 2; }
    arm "C1  CONTROL: clean content as a live git work tree fires nothing" 0 c1 live
    runc "$lab/emit.c1" "$SELF" --root "$lab/c1" --emit-population
    if [ "$(sha256sum <"$lab/emit.c1" | cut -d' ' -f1)" = "$(awk '$1=="POPULATION-SHA"{print $2}' "$lab/out.c1")" ] && [ -s "$lab/emit.c1" ]; then
        ok "C1b POPULATION-SHA equals the sha of --emit-population"
    else bad "C1b POPULATION-SHA differs from --emit-population (or it is empty)" "$lab/emit.c1"; fi
    if LC_ALL=C sort -u "$lab/emit.c1" | cmp -s - "$lab/emit.c1"; then ok "C1c --emit-population is sorted and unique under LC_ALL=C"; else bad "C1c --emit-population is not sorted/unique" "$lab/emit.c1"; fi
    # C2 — determinism: the same state gives the same bytes.
    runc "$lab/out.c1b" "$SELF" --root "$lab/c1"
    if cmp -s "$lab/out.c1" "$lab/out.c1b"; then ok "C2  two runs over one state are byte-identical"; else bad "C2  two runs differ" "$lab/out.c1b"; fi

    # M1 — the planted corpus: rc 1 and the FINDING locations are EXACTLY the expect.tsv set.
    mklab m1 "$corp/planted"
    arm "M1  planted corpus fires" 1 m1 corpus
    awk -F'\t' '!/^#/ && NF { print $1 }' "$corp/expect.tsv" | LC_ALL=C sort -u >"$lab/expect.locs"
    if locs "$lab/out.m1" | cmp -s - "$lab/expect.locs"; then ok "M1b every planted location found, nothing else (recall 1.0, no unexpected finding)"
    else bad "M1b finding set differs from expect.tsv" "$lab/out.m1"; locs "$lab/out.m1" | diff - "$lab/expect.locs" | sed 's/^/       | /' | head -20; fi
    # M1c — severity is part of the claim: a ledger-verified FALSE figure on a status line is high,
    #       an unledgered status/rc figure is medium, the per-document aggregate is low.
    s1ok=1
    for pair in figure:CLAUDE.md:5=medium figure:CLAUDE.md:6=high figure:CLAUDE.md:16=medium figure:README.md:3=medium figure:README.md:9=medium \
                figure:CONTINUATION.md:3=medium figures:CLAUDE.md=low figures:README.md=low figures:QWEN.md=low \
                claim:lab-malformed=medium claim:lab-dup=medium; do
        got=$(sevof "$lab/out.m1" "${pair%%=*}")
        [ "$got" = "${pair#*=}" ] || { s1ok=0; bad "M1c ${pair%%=*} has severity '$got', want ${pair#*=}"; }
    done
    [ "$s1ok" -eq 1 ] && ok "M1c severities: FALSE-on-status high, unledgered status/rc medium, aggregates low, malformed/duplicate rows medium"
    # M1d — an aggregate names EXACTLY its lines: every LOW shape is detected on its own line, the
    #       identical mirror line is deduped, and the hex-only line (README.md:7) is not a figure.
    a1=$(linesof "$lab/out.m1" figures:CLAUDE.md); a2=$(linesof "$lab/out.m1" figures:README.md)
    a3=$(linesof "$lab/out.m1" figures:AGENTS.md)
    if [ "$a1" = "8 12 14" ] && [ "$a2" = "5" ] && [ "$a3" = "3" ]; then ok "M1d aggregates name exactly their lines (CLAUDE.md 8 12 14; README.md 5, hex-only 7 excluded; AGENTS.md 3, identical mirror line 5 deduped)"
    else bad "M1d aggregate line lists: CLAUDE.md '$a1' (want '8 12 14'), README.md '$a2' (want '5'), AGENTS.md '$a3' (want '3')" "$lab/out.m1"; fi
    # M1f — VSC-353: the "<n> declared" / "<n> owned" shapes are figures, each on its own line.
    a4=$(linesof "$lab/out.m1" figures:GEMINI.md)
    if [ "$a4" = "3 5 7 9" ]; then ok "M1f declared/owned shapes: GEMINI.md aggregate names lines 3 5 7 9 (22 declared, 12 owned of, 12 owned ... 14 declared)"
    else bad "M1f GEMINI.md aggregate line list '$a4' (want '3 5 7 9')" "$lab/out.m1"; fi
    # M1e — docs/** is outside the population (boundary ruling: doc-count-drift owns it).
    if grep -q '^FINDING [^ ]* [^ ]* [^ ]* figures\?:docs/' "$lab/out.m1"; then bad "M1e a docs/** line was reported" "$lab/out.m1"
    else ok "M1e planted docs/notes.md and docs/sub/deep.md (figures, hex) yield nothing: docs/** is not scanned"; fi

    # M10 — VSC-353: a withdrawal on the NEXT line annotates the figure above it; the clean control
    #       (CLAUDE.md lines 13-14) is quiet, and removing the withdrawal line exposes line 13.
    mklab m10 "$corp/clean"
    if mutate m10 "sed -i.bak '/^That figure is WITHDRAWN/d' CLAUDE.md && rm -f CLAUDE.md.bak"; then arm "M10 a next-line withdrawal is the reason line 13 is quiet: without it the figure is reported" 1 m10 corpus "figures:CLAUDE.md"
    else bad "M10 inoperative mutation"; fi
    # M11 — VSC-353: an exit-code MEANING line is quiet; the same line turned into a measured status is not.
    mklab m11 "$corp/clean"
    if mutate m11 "sed -i.bak 's/exit 1 = finding/exit 1 at 12 CURRENT/' CLAUDE.md && rm -f CLAUDE.md.bak"; then arm "M11 an exit-code meaning line turned into a measured status is reported" 1 m11 corpus "figure:CLAUDE.md:16"
    else bad "M11 inoperative mutation"; fi

    # M2 — REALITY MOVES under a ledgered claim (the measured defect class): FALSE, located.
    mklab m2 "$corp/clean" git
    if mutate m2 "printf 'c5\n' >> data/checks.txt"; then arm "M2  reality moves under a ledgered figure -> FALSE at its line" 1 m2 live "figure:CLAUDE.md:5"
    else bad "M2  inoperative mutation"; fi
    # M3 — a new figure with no ledger row (LOW: aggregated per document).
    mklab m3 "$corp/clean" git
    if mutate m3 "printf 'The lab holds 31 files today.\n' >> README.md"; then arm "M3  a new unledgered figure is a finding" 1 m3 live "figures:README.md"
    else bad "M3  inoperative mutation"; fi
    # M4 — the skip rule is the REASON the WITHDRAWN line is quiet, not blindness.
    mklab m4 "$corp/clean"
    if mutate m4 "sed -i.bak 's/is WITHDRAWN and/is/' CLAUDE.md && rm -f CLAUDE.md.bak"; then arm "M4  removing the WITHDRAWN annotation exposes the figure" 1 m4 corpus "figures:CLAUDE.md"
    else bad "M4  inoperative mutation"; fi
    # M5 — a DRIFTED mirror line is not deduped.
    mklab m5 "$corp/clean"
    if mutate m5 "sed -i.bak '3s/\*\*4\*\*/**5**/' AGENTS.md && rm -f AGENTS.md.bak"; then arm "M5  a mirror line that drifted from CLAUDE.md is reported" 1 m5 corpus "figures:AGENTS.md"
    else bad "M5  inoperative mutation"; fi
    # M6 — a struck-through figure that loses its strikethrough.
    mklab m6 "$corp/clean"
    if mutate m6 "sed -i.bak 's/~~//g' CLAUDE.md && rm -f CLAUDE.md.bak"; then arm "M6  a figure outside ~~strikethrough~~ is reported" 1 m6 corpus "figures:CLAUDE.md"
    else bad "M6  inoperative mutation"; fi
    # M8 — a 12-hex id beside a real count still reports the count (the hex rule drops only hex-ONLY lines).
    mklab m8 "$corp/clean"
    if mutate m8 "printf 'Pin \`3be10826f3d2\` holds 9 files.\n' >> README.md"; then arm "M8  a count on a line that also carries a hex id is reported" 1 m8 corpus "figures:README.md"
    else bad "M8  inoperative mutation"; fi

    # M9 — POINT-IN-TIME §3 CAPTION GATING (T091): a captioned entry under a matching
    #      point-in-time.tsv row is exempt; an UNCAPTIONED near-miss with IDENTICAL text in the
    #      same document, same section, is not (it must keep registering).
    mklab m9 "$corp/clean"
    if mutate m9 "mkdir -p docs/zero-gap && printf 'path\treason\nCONTINUATION.md\town dated caption entries of section §3 are point-in-time, true when written (T091 test)\n' > docs/zero-gap/point-in-time.tsv && printf '## §3 Active work\n\n### CAPTIONED STATUS NOTE — 2026-09-25 (evening)\n\nRe-measured then: the remote-sync gate exits 0 at 12 CURRENT / 0 DRIFT.\n\n### UNCAPTIONED STATUS NOTE WITH NO DATE\n\nThe remote-sync gate exits 0 at 12 CURRENT / 0 DRIFT.\n' > CONTINUATION.md"; then
        arm "M9  a §3 entry with its own dated caption is exempt (T091); an uncaptioned near-miss with identical text stays a finding" 1 m9 corpus "figure:CONTINUATION.md:9"
        if grep -q '^FINDING .* figure:CONTINUATION.md:5 ' "$lab/out.m9"; then bad "M9b the captioned line (5) was still reported" "$lab/out.m9"
        else ok "M9b the captioned line (5) is exempt: no finding there"; fi
    else bad "M9  inoperative mutation"; fi

    # M9c — RED baseline: with NO matching point-in-time.tsv row at all, a dated caption exempts
    #       nothing by itself (both the captioned and uncaptioned lines fire).
    mklab m9c "$corp/clean"
    if mutate m9c "printf '## §3 Active work\n\n### CAPTIONED STATUS NOTE — 2026-09-25 (evening)\n\nRe-measured then: the remote-sync gate exits 0 at 12 CURRENT / 0 DRIFT.\n\n### UNCAPTIONED STATUS NOTE WITH NO DATE\n\nThe remote-sync gate exits 0 at 12 CURRENT / 0 DRIFT.\n' > CONTINUATION.md"; then
        arm "M9c  with no point-in-time row present, a dated caption alone exempts nothing" 1 m9c corpus "figure:CONTINUATION.md:5"
        if grep -q '^FINDING .* figure:CONTINUATION.md:9 ' "$lab/out.m9c"; then ok "M9c both the captioned (5) and uncaptioned (9) lines are findings with no exemption row present"
        else bad "M9c the uncaptioned line (9) was not reported" "$lab/out.m9c"; fi
    else bad "M9c  inoperative mutation"; fi

    # M9e — a point-in-time row with no reason is refused (COULD-NOT-INSPECT), never a silent
    #       exemption: the same rule doc-count-drift enforces on its own rows.
    mklab m9e "$corp/clean"
    if mutate m9e "mkdir -p docs/zero-gap && printf 'path\treason\nCONTINUATION.md\t\n' > docs/zero-gap/point-in-time.tsv"; then
        arm "M9e  a point-in-time row with no reason is COULD-NOT-INSPECT, never a silent exemption" 2 m9e corpus
        if grep -q '^COULD-NOT-INSPECT docs/zero-gap/point-in-time.tsv:2 ' "$lab/out.m9e"; then ok "M9e the reasonless row is named at line 2"
        else bad "M9e the reasonless row was not named" "$lab/out.m9e"; fi
    else bad "M9e  inoperative mutation"; fi

    # S1-S4 — a symlink or special file is COULD-NOT-INSPECT, never read, never a hang: a FIFO
    #         (would block), /dev/zero (would exhaust memory, host-memory 12.6), a link leaving the
    #         tree (its text must never be echoed), a ledger surface that is a FIFO (the ledger gate
    #         would block on it).
    if command -v mkfifo >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
        printf 'ZGOUTSIDEMARKER holds 77 files.\n' >"$lab/outside.md"
        mkdir -p "$lab/outdir"; printf 'ZGOUTSIDEMARKER holds 77 pipes.\n' >"$lab/outdir/far.md"
        for s in fifo zero outside surf dir; do
            mklab "s-$s" "$corp/clean" git
            case $s in
                fifo)    mkfifo "$lab/s-$s/pipe"; ln -s pipe "$lab/s-$s/QWEN.md"; want=QWEN.md ;;
                zero)    ln -s /dev/zero "$lab/s-$s/QWEN.md"; want=QWEN.md ;;
                outside) ln -s "$lab/outside.md" "$lab/s-$s/QWEN.md"; want=QWEN.md ;;
                surf)    mkfifo "$lab/s-$s/docs/pipe.md"
                         printf 'claim\tlab-pipe\tdocs/pipe.md\tprose\tdoc-vs-code-drift\tminor\teq\t-\tholds (\\d+) pipes\techo 1\n' >>"$lab/s-$s/docs/claim-ledger.tsv"
                         want=docs/pipe.md ;;
                dir)     ln -s "$lab/outdir" "$lab/s-$s/ext"   # a regular file reached through a linked directory
                         printf 'claim\tlab-far\text/far.md\tprose\tdoc-vs-code-drift\tminor\teq\t-\tholds (\\d+) pipes\techo 77\n' >>"$lab/s-$s/docs/claim-ledger.tsv"
                         want=ext/far.md ;;
            esac
            timed "$lab/out.s-$s" --root "$lab/s-$s"; rc=$?
            if [ "$rc" -ne 2 ]; then bad "S-$s a $s entry gave rc $rc (want 2: COULD-NOT-INSPECT, no hang: 124 is a hang)" "$lab/out.s-$s"; continue; fi
            if ! grammar_ok "$lab/out.s-$s" 2; then bad "S-$s output violates the class contract" "$lab/out.s-$s"; continue; fi
            if ! grep -q "^COULD-NOT-INSPECT $want " "$lab/out.s-$s"; then bad "S-$s no COULD-NOT-INSPECT naming $want" "$lab/out.s-$s"; continue; fi
            if grep -q ZGOUTSIDEMARKER "$lab/out.s-$s" "$lab/out.s-$s.err"; then bad "S-$s text from outside the tree was printed" "$lab/out.s-$s"; continue; fi
            ok "S-$s a $s entry is COULD-NOT-INSPECT $want, rc 2, nothing read or echoed"
        done
    else
        bad "S   mkfifo/timeout absent: the symlink/special-file cases cannot run"
    fi
    # M7 — an ORPHAN ledger row.
    mklab m7 "$corp/clean"
    if mutate m7 "printf 'claim\tlab-gone\tCLAUDE.md\tprose\tdoc-vs-code-drift\tminor\teq\t-\tnever \\\\*\\\\*(\\\\d+)\\\\*\\\\* here\techo 1\n' >> docs/claim-ledger.tsv"; then
        arm "M7  an ORPHAN ledger row is a finding" 1 m7 corpus "claim:lab-gone"
    else bad "M7  inoperative mutation"; fi

    # U1 — an EMPTY population is never clean.
    mkdir -p "$lab/u1"; git -C "$lab/u1" init -q; printf 'not a document\n' >"$lab/u1/notes.txt"
    arm "U1  an empty population is COULD-NOT-INSPECT (rc 2), never clean" 2 u1 live
    # U2 — an absent root.
    runc "$lab/out.u2" "$SELF" --root /nonexistent; if [ $? -eq 2 ]; then ok "U2  --root /nonexistent -> rc 2"; else bad "U2  --root /nonexistent did not exit 2" "$lab/out.u2"; fi
    # U3 — a BROKEN python3 (a shim that fails) is rc 2, never clean.
    mkdir -p "$lab/shim"; printf '#!/bin/sh\nexit 127\n' >"$lab/shim/python3"; chmod +x "$lab/shim/python3"
    mklab u3 "$corp/clean"
    RUN_PATH="$lab/shim:$PATH" arm "U3  a broken python3 is rc 2" 2 u3 corpus
    # U4 — the ledger gate is ABSENT next to the class: nothing can be re-measured.
    mkdir -p "$lab/bin"; cp "$SELF" "$lab/bin/zero-gap-class-$CLASS_ID.sh"
    mklab u4 "$corp/clean"
    runc "$lab/out.u4" "$lab/bin/zero-gap-class-$CLASS_ID.sh" --root "$lab/u4" --corpus "$lab/u4"; rc=$?
    if [ "$rc" -eq 2 ] && grammar_ok "$lab/out.u4" 2; then ok "U4  an absent scripts/verify-claim-ledger.sh -> rc 2"; else bad "U4  absent ledger gate gave rc $rc" "$lab/out.u4"; fi
    # U5 — a probe that will not run: COULD-NOT-INSPECT on that row.
    mklab u5 "$corp/clean"
    if mutate u5 "sed -i.bak 's/grep -c \. data\/checks\.txt/definitely-not-a-binary-xyzzy/' docs/claim-ledger.tsv && rm -f docs/claim-ledger.tsv.bak"; then
        arm "U5  a ledger probe that will not run -> rc 2" 2 u5 corpus
        if grep -q '^COULD-NOT-INSPECT claim:lab-checks ' "$lab/out.u5"; then ok "U5b the undetermined row is named"; else bad "U5b the undetermined row is not named" "$lab/out.u5"; fi
    else bad "U5  inoperative mutation"; fi
    # P1 — PRECEDENCE: an undetermined row does not mask a finding.
    mklab p1 "$corp/clean"
    if mutate p1 "sed -i.bak 's/grep -c \. data\/checks\.txt/definitely-not-a-binary-xyzzy/' docs/claim-ledger.tsv && rm -f docs/claim-ledger.tsv.bak && printf 'The lab holds 31 files today.\n' >> README.md"; then
        arm "P1  a finding outranks an undetermined row (rc 1)" 1 p1 corpus "figures:README.md"
    else bad "P1  inoperative mutation"; fi

    # G — VSC-353 clause B: an unmarked "<n> declared" line is compared with the path count of the
    #     .gitmodules read from --root. G1 planted mismatch (14 vs 22) is caught and names BOTH figures;
    #     G2 equal counts stay silent; G3 a (historical)-marked line stays silent (skip rule runs BEFORE
    #     the comparison); G4 no .gitmodules -> silent, with a NOTE on stderr; G5/G6 mutants of THIS
    #     script (comparison skipped / compared against the wrong count) are each caught by the cases above.
    GM22='i=1; while [ "$i" -le 22 ]; do printf "[submodule \"m%s\"]\n\tpath = mods/m%s\n\turl = u\n" "$i" "$i" >> .gitmodules; i=$((i+1)); done'
    mmhit() { # mmhit <outfile> <location> <a> <b>: a finding at <location> naming both figures and "mismatch"
        awk -v l="$2" '$1 == "FINDING" && $5 == l' "$1" | grep -i 'mismatch' | grep -Eq "(^|[^0-9])$3([^0-9]|\$)" \
            && awk -v l="$2" '$1 == "FINDING" && $5 == l' "$1" | grep -i 'mismatch' | grep -Eq "(^|[^0-9])$4([^0-9]|\$)"
    }
    anymm() { grep '^FINDING ' "$1" | grep -qi 'mismatch'; }
    mklab g1 "$corp/clean"
    if mutate g1 "$GM22; printf 'The fleet has 14 declared.\n' >> README.md"; then
        gl=$(wc -l <"$lab/g1/README.md" | tr -d ' ')
        arm "G1  planted: 14 declared vs .gitmodules 22 paths is a finding at its line" 1 g1 corpus "figure:README.md:$gl"
        if mmhit "$lab/out.g1" "figure:README.md:$gl" 14 22; then ok "G1b the finding names BOTH figures (14 and 22) and says mismatch"
        else bad "G1b no mismatch finding naming 14 and 22 at figure:README.md:$gl" "$lab/out.g1"; fi
    else bad "G1  inoperative mutation"; fi
    mklab g2 "$corp/clean"
    if mutate g2 "$GM22; printf 'The fleet has 22 declared.\n' >> README.md"; then
        arm "G2  CONTROL: 22 declared vs 22 paths is not a mismatch (still an unledgered figure)" 1 g2 corpus "figures:README.md"
        if anymm "$lab/out.g2"; then bad "G2b equal counts were reported as a mismatch" "$lab/out.g2"; else ok "G2b equal counts: no mismatch finding"; fi
    else bad "G2  inoperative mutation"; fi
    mklab g3 "$corp/clean"
    # G3 plants TWO lines: "14 declared (historical)." and "14 declared. (historical)". The comparison
    # itself sees both (the parenthesis after "declared" does not hide the figure, and the sentence end
    # of the second never did), so the silence is caused by the skip rule alone; G3m proves that by
    # disabling the skip rule and requiring both lines to be reported.
    if mutate g3 "$GM22; printf 'The fleet has 14 declared (historical).\n\nThe fleet has 14 declared. (historical)\n' >> README.md"; then
        gl3=$(wc -l <"$lab/g3/README.md" | tr -d ' ')
        runc "$lab/out.g3" "$SELF" --root "$lab/g3" --corpus "$lab/g3"
        if anymm "$lab/out.g3"; then bad "G3  a (historical)-marked 14 declared was compared against .gitmodules" "$lab/out.g3"; else ok "G3  a (historical)-marked line is skipped BEFORE the comparison: no mismatch finding"; fi
        mkdir -p "$lab/mut3"; cp "$gate" "$lab/mut3/"
        sed 's/if m is None or SKIP[.]search(s)/if m is None/' "$SELF" >"$lab/mut3/zero-gap-class-$CLASS_ID.sh"
        if cmp -s "$SELF" "$lab/mut3/zero-gap-class-$CLASS_ID.sh"; then bad "G3m inoperative mutation (the skip-rule anchor no longer matches)"
        else
            runc "$lab/out.g3m" "$lab/mut3/zero-gap-class-$CLASS_ID.sh" --root "$lab/g3" --corpus "$lab/g3"
            if mmhit "$lab/out.g3m" "figure:README.md:$((gl3 - 2))" 14 22 && mmhit "$lab/out.g3m" "figure:README.md:$gl3" 14 22; then ok "G3m mutant with the skip rule disabled reports BOTH (historical) lines as mismatches: G3 detects that the skip rule is what keeps them silent"
            else bad "G3m the skip-rule-disabled mutant did not report both lines (G3's silence is not caused by the skip rule)" "$lab/out.g3m"; fi
        fi
    else bad "G3  inoperative mutation"; fi
    mklab g4 "$corp/clean"
    if mutate g4 "printf 'The fleet has 14 declared.\n' >> README.md"; then
        runc "$lab/out.g4" "$SELF" --root "$lab/g4" --corpus "$lab/g4"
        if anymm "$lab/out.g4"; then bad "G4  no .gitmodules but a mismatch was reported" "$lab/out.g4"
        elif grep -q '^NOTE' "$lab/out.g4.err"; then ok "G4  no .gitmodules: comparison skipped, no finding, NOTE on stderr"
        else bad "G4  no .gitmodules: comparison skipped but no NOTE on stderr" "$lab/out.g4.err"; fi
    else bad "G4  inoperative mutation"; fi
    # G5/G6 — mutants of this script. Each copy sits beside the ledger gate (the class needs it).
    mkdir -p "$lab/mut5" "$lab/mut6"
    cp "$gate" "$lab/mut5/"; cp "$gate" "$lab/mut6/"
    sed 's/if decl is not None and any[(]/if False and any(/' "$SELF" >"$lab/mut5/zero-gap-class-$CLASS_ID.sh"
    sed 's/n != decl for n in clai[m]ed/n != decl + 1 for n in claimed/' "$SELF" >"$lab/mut6/zero-gap-class-$CLASS_ID.sh"
    if cmp -s "$SELF" "$lab/mut5/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut6/zero-gap-class-$CLASS_ID.sh"; then bad "G5/G6 inoperative mutation (a sed anchor no longer matches)"
    else
        runc "$lab/out.g5" "$lab/mut5/zero-gap-class-$CLASS_ID.sh" --root "$lab/g1" --corpus "$lab/g1"
        if mmhit "$lab/out.g5" "figure:README.md:$gl" 14 22; then bad "G5  the skip-the-comparison mutant still reported the mismatch (G1 would not catch it)" "$lab/out.g5"
        else ok "G5  mutant that skips the comparison loses the G1 finding: G1 detects it"; fi
        runc "$lab/out.g6" "$lab/mut6/zero-gap-class-$CLASS_ID.sh" --root "$lab/g2" --corpus "$lab/g2"
        if anymm "$lab/out.g6"; then ok "G6  mutant that compares against the wrong count (decl+1) reports a false mismatch on the equal-count control: G2 detects it"
        else bad "G6  the wrong-count mutant stayed silent on the equal-count control (G2 would not catch it)" "$lab/out.g6"; fi
    fi

    # G7-G10 — the noun after "declared" must denote the submodule fleet (or nothing): other nouns
    #     ("declared pairs", "declared members") are NOT submodule counts and must not be compared.
    mklab g7 "$corp/clean"
    if mutate g7 "$GM22; printf 'The allow file carries 9 declared pairs today.\n' >> README.md"; then
        runc "$lab/out.g7" "$SELF" --root "$lab/g7" --corpus "$lab/g7"
        if anymm "$lab/out.g7"; then bad "G7  '9 declared pairs' was compared against the submodule count" "$lab/out.g7"; else ok "G7  '<n> declared pairs' is not a submodule claim: no mismatch finding"; fi
    else bad "G7  inoperative mutation"; fi
    mklab g8 "$corp/clean"
    if mutate g8 "$GM22; printf 'verify-ui-vocabulary.sh  0   76 declared members\n' >> README.md"; then
        runc "$lab/out.g8" "$SELF" --root "$lab/g8" --corpus "$lab/g8"
        if anymm "$lab/out.g8"; then bad "G8  '76 declared members' was compared against the submodule count" "$lab/out.g8"; else ok "G8  '<n> declared members' is not a submodule claim: no mismatch finding"; fi
    else bad "G8  inoperative mutation"; fi
    mklab g9 "$corp/clean"
    if mutate g9 "$GM22; printf 'C1 classified all 13 declared submodules from evidence.\n' >> README.md"; then
        gl9=$(wc -l <"$lab/g9/README.md" | tr -d ' ')
        runc "$lab/out.g9" "$SELF" --root "$lab/g9" --corpus "$lab/g9"
        if mmhit "$lab/out.g9" "figure:README.md:$gl9" 13 22; then ok "G9  '13 declared submodules' (planted fleet claim) is still a mismatch naming 13 and 22"; else bad "G9  planted '13 declared submodules' not reported" "$lab/out.g9"; fi
    else bad "G9  inoperative mutation"; fi
    mklab g10 "$corp/clean"
    if mutate g10 "$GM22; printf 'Of these, 12 are probed of 13 declared.\n' >> README.md"; then
        gl10=$(wc -l <"$lab/g10/README.md" | tr -d ' ')
        runc "$lab/out.g10" "$SELF" --root "$lab/g10" --corpus "$lab/g10"
        if mmhit "$lab/out.g10" "figure:README.md:$gl10" 13 22; then ok "G10 '13 declared.' (sentence-final) is still a mismatch naming 13 and 22"; else bad "G10 planted sentence-final '13 declared.' not reported" "$lab/out.g10"; fi
    else bad "G10 inoperative mutation"; fi

    # G11-G16 — VSC-353 B1/B2: the two added shapes, each with a planted mismatch arm (finding names BOTH
    #     figures), an equal-count control and a (historical) control, plus a paired mutant per shape.
    #     B1 "<n> <fleet noun> (is|are|were) declared" must ENTER the figure population and be compared;
    #     B2 "<n> declared <today|now|currently|so far>" (markup allowed) must be compared.
    mklab g11 "$corp/clean"
    if mutate g11 "$GM22; printf 'The fleet: 13 gitlinks are declared.\n' >> README.md"; then
        gl11=$(wc -l <"$lab/g11/README.md" | tr -d ' ')
        runc "$lab/out.g11" "$SELF" --root "$lab/g11" --corpus "$lab/g11"
        if mmhit "$lab/out.g11" "figure:README.md:$gl11" 13 22; then ok "G11 B1 planted '13 gitlinks are declared' vs 22 paths: finding names 13 and 22 and says mismatch"
        else bad "G11 B1 planted '13 gitlinks are declared' not reported as a mismatch naming 13 and 22" "$lab/out.g11"; fi
    else bad "G11 inoperative mutation"; fi
    mklab g12 "$corp/clean"
    if mutate g12 "$GM22; printf 'The fleet: 22 gitlinks are declared.\n' >> README.md"; then
        runc "$lab/out.g12" "$SELF" --root "$lab/g12" --corpus "$lab/g12"
        if anymm "$lab/out.g12"; then bad "G12 B1 CONTROL: 22 gitlinks are declared vs 22 paths was reported as a mismatch" "$lab/out.g12"; else ok "G12 B1 CONTROL: equal count (22 vs 22) is not a mismatch"; fi
    else bad "G12 inoperative mutation"; fi
    mklab g13 "$corp/clean"
    if mutate g13 "$GM22; printf 'The fleet: 13 gitlinks are declared (historical).\n' >> README.md"; then
        runc "$lab/out.g13" "$SELF" --root "$lab/g13" --corpus "$lab/g13"
        if anymm "$lab/out.g13"; then bad "G13 B1 a (historical)-marked '13 gitlinks are declared' was compared" "$lab/out.g13"; else ok "G13 B1 CONTROL: (historical)-marked line is not compared"; fi
    else bad "G13 inoperative mutation"; fi
    mklab g14 "$corp/clean"
    if mutate g14 "$GM22; printf 'The fleet: **14** declared today\n' >> README.md"; then
        gl14=$(wc -l <"$lab/g14/README.md" | tr -d ' ')
        runc "$lab/out.g14" "$SELF" --root "$lab/g14" --corpus "$lab/g14"
        if mmhit "$lab/out.g14" "figure:README.md:$gl14" 14 22; then ok "G14 B2 planted '**14** declared today' vs 22 paths: finding names 14 and 22 and says mismatch"
        else bad "G14 B2 planted '**14** declared today' not reported as a mismatch naming 14 and 22" "$lab/out.g14"; fi
    else bad "G14 inoperative mutation"; fi
    mklab g15 "$corp/clean"
    if mutate g15 "$GM22; printf 'The fleet: **22** declared today\n' >> README.md"; then
        runc "$lab/out.g15" "$SELF" --root "$lab/g15" --corpus "$lab/g15"
        if anymm "$lab/out.g15"; then bad "G15 B2 CONTROL: 22 declared today vs 22 paths was reported as a mismatch" "$lab/out.g15"; else ok "G15 B2 CONTROL: equal count (22 vs 22) is not a mismatch"; fi
    else bad "G15 inoperative mutation"; fi
    mklab g16 "$corp/clean"
    if mutate g16 "$GM22; printf 'The fleet: 14 declared so far (historical).\n' >> README.md"; then
        runc "$lab/out.g16" "$SELF" --root "$lab/g16" --corpus "$lab/g16"
        if anymm "$lab/out.g16"; then bad "G16 B2 a (historical)-marked '14 declared so far' was compared" "$lab/out.g16"; else ok "G16 B2 CONTROL: (historical)-marked line is not compared"; fi
    else bad "G16 inoperative mutation"; fi
    # G17/G18 — paired mutants: the comparison skipped for ONE new shape must lose that shape's finding.
    mkdir -p "$lab/mut17" "$lab/mut18"
    cp "$gate" "$lab/mut17/"; cp "$gate" "$lab/mut18/"
    sed 's/ + DECLARED_ARE_RE[.]findall(_ls)//' "$SELF" >"$lab/mut17/zero-gap-class-$CLASS_ID.sh"
    sed 's/|today|now|currently|so\\s+far//' "$SELF" >"$lab/mut18/zero-gap-class-$CLASS_ID.sh"
    if cmp -s "$SELF" "$lab/mut17/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut18/zero-gap-class-$CLASS_ID.sh"; then bad "G17/G18 inoperative mutation (a sed anchor no longer matches)"
    else
        runc "$lab/out.g17" "$lab/mut17/zero-gap-class-$CLASS_ID.sh" --root "$lab/g11" --corpus "$lab/g11"
        if mmhit "$lab/out.g17" "figure:README.md:$gl11" 13 22; then bad "G17 the B1-comparison-skipped mutant still reported the mismatch (G11 would not catch it)" "$lab/out.g17"
        else ok "G17 mutant that skips the comparison for the B1 shape loses the G11 finding: G11 detects it"; fi
        runc "$lab/out.g18" "$lab/mut18/zero-gap-class-$CLASS_ID.sh" --root "$lab/g14" --corpus "$lab/g14"
        if mmhit "$lab/out.g18" "figure:README.md:$gl14" 14 22; then bad "G18 the B2-adverb-dropped mutant still reported the mismatch (G14 would not catch it)" "$lab/out.g18"
        else ok "G18 mutant that drops the B2 adverbs loses the G14 finding: G14 detects it"; fi
    fi

    # G19-G24 — VSC-353 round 4: the comparison is case-insensitive and B1 knows the verb forms
    #     "have/has been declared" and "is/are/was/were now declared"; each arm has a paired mutant.
    mklab g19 "$corp/clean"
    if mutate g19 "$GM22; printf 'The fleet: 14 Declared.\n' >> README.md"; then
        gl19=$(wc -l <"$lab/g19/README.md" | tr -d ' ')
        runc "$lab/out.g19" "$SELF" --root "$lab/g19" --corpus "$lab/g19"
        if mmhit "$lab/out.g19" "figure:README.md:$gl19" 14 22; then ok "G19 '14 Declared.' (capital D) vs 22 paths: finding names 14 and 22 and says mismatch"
        else bad "G19 planted '14 Declared.' not reported as a mismatch naming 14 and 22" "$lab/out.g19"; fi
    else bad "G19 inoperative mutation"; fi
    mklab g20 "$corp/clean"
    if mutate g20 "$GM22; printf 'The fleet: 13 GITLINKS ARE DECLARED.\n' >> README.md"; then
        gl20=$(wc -l <"$lab/g20/README.md" | tr -d ' ')
        runc "$lab/out.g20" "$SELF" --root "$lab/g20" --corpus "$lab/g20"
        if mmhit "$lab/out.g20" "figure:README.md:$gl20" 13 22; then ok "G20 '13 GITLINKS ARE DECLARED.' (upper case) vs 22 paths: finding names 13 and 22"
        else bad "G20 planted '13 GITLINKS ARE DECLARED.' not reported as a mismatch naming 13 and 22" "$lab/out.g20"; fi
    else bad "G20 inoperative mutation"; fi
    mklab g21 "$corp/clean"
    if mutate g21 "$GM22; printf 'The fleet: 13 gitlinks are Declared.\n' >> README.md"; then
        gl21=$(wc -l <"$lab/g21/README.md" | tr -d ' ')
        runc "$lab/out.g21" "$SELF" --root "$lab/g21" --corpus "$lab/g21"
        if mmhit "$lab/out.g21" "figure:README.md:$gl21" 13 22; then ok "G21 '13 gitlinks are Declared.' (mixed case) vs 22 paths: finding names 13 and 22"
        else bad "G21 planted '13 gitlinks are Declared.' not reported as a mismatch naming 13 and 22" "$lab/out.g21"; fi
    else bad "G21 inoperative mutation"; fi
    mklab g22 "$corp/clean"
    if mutate g22 "$GM22; printf 'The fleet: 13 gitlinks have been declared.\n\nThe set: 14 submodules has been declared.\n' >> README.md"; then
        gl22=$(wc -l <"$lab/g22/README.md" | tr -d ' ')
        runc "$lab/out.g22" "$SELF" --root "$lab/g22" --corpus "$lab/g22"
        if mmhit "$lab/out.g22" "figure:README.md:$((gl22 - 2))" 13 22 && mmhit "$lab/out.g22" "figure:README.md:$gl22" 14 22; then ok "G22 '13 gitlinks have been declared' and '14 submodules has been declared' vs 22 paths: both findings name both figures"
        else bad "G22 planted 'have/has been declared' lines not both reported as mismatches" "$lab/out.g22"; fi
    else bad "G22 inoperative mutation"; fi
    mklab g23 "$corp/clean"
    if mutate g23 "$GM22; printf 'The fleet: 13 gitlinks are now declared.\n\nThe set: 14 submodules were now declared.\n' >> README.md"; then
        gl23=$(wc -l <"$lab/g23/README.md" | tr -d ' ')
        runc "$lab/out.g23" "$SELF" --root "$lab/g23" --corpus "$lab/g23"
        if mmhit "$lab/out.g23" "figure:README.md:$((gl23 - 2))" 13 22 && mmhit "$lab/out.g23" "figure:README.md:$gl23" 14 22; then ok "G23 '13 gitlinks are now declared' and '14 submodules were now declared' vs 22 paths: both findings name both figures"
        else bad "G23 planted 'are/were now declared' lines not both reported as mismatches" "$lab/out.g23"; fi
    else bad "G23 inoperative mutation"; fi
    mklab g24 "$corp/clean"
    if mutate g24 "$GM22; printf 'The fleet: 22 Gitlinks Have Been Declared.\n\nThe set: 22 DECLARED.\n\nThe set: 22 submodules are now declared.\n' >> README.md"; then
        runc "$lab/out.g24" "$SELF" --root "$lab/g24" --corpus "$lab/g24"
        if anymm "$lab/out.g24"; then bad "G24 CONTROL: equal count (22) in mixed case / new verb forms was reported as a mismatch" "$lab/out.g24"; else ok "G24 CONTROL: equal count (22 vs 22) in mixed case and new verb forms is not a mismatch"; fi
    else bad "G24 inoperative mutation"; fi
    # G25-G28 — paired mutants: removing case-insensitivity from either comparison, or either verb form, loses the finding.
    mkdir -p "$lab/mut25" "$lab/mut26" "$lab/mut27" "$lab/mut28"
    for m in mut25 mut26 mut27 mut28; do cp "$gate" "$lab/$m/"; done
    sed '/^DECLARED_RE = /s/, re[.]I)$/)/' "$SELF" >"$lab/mut25/zero-gap-class-$CLASS_ID.sh"
    sed '/^DECLARED_ARE_RE = /s/, re[.]I)$/)/' "$SELF" >"$lab/mut26/zero-gap-class-$CLASS_ID.sh"
    sed 's/|(?:has|have)'"'"' + SEP + r'"'"'been//' "$SELF" >"$lab/mut27/zero-gap-class-$CLASS_ID.sh"
    sed 's/(?:'"'"' + SEP + r'"'"'now)?//' "$SELF" >"$lab/mut28/zero-gap-class-$CLASS_ID.sh"
    if cmp -s "$SELF" "$lab/mut25/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut26/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut27/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut28/zero-gap-class-$CLASS_ID.sh"; then bad "G25-G28 inoperative mutation (a sed anchor no longer matches)"
    else
        runc "$lab/out.g25" "$lab/mut25/zero-gap-class-$CLASS_ID.sh" --root "$lab/g19" --corpus "$lab/g19"
        if mmhit "$lab/out.g25" "figure:README.md:$gl19" 14 22; then bad "G25 the case-sensitive-DECLARED_RE mutant still reported '14 Declared.' (G19 would not catch it)" "$lab/out.g25"
        else ok "G25 mutant with a case-sensitive DECLARED_RE loses the G19 finding: G19 detects it"; fi
        runc "$lab/out.g26" "$lab/mut26/zero-gap-class-$CLASS_ID.sh" --root "$lab/g20" --corpus "$lab/g20"
        if mmhit "$lab/out.g26" "figure:README.md:$gl20" 13 22; then bad "G26 the case-sensitive-DECLARED_ARE_RE mutant still reported the upper-case line (G20 would not catch it)" "$lab/out.g26"
        else ok "G26 mutant with a case-sensitive DECLARED_ARE_RE loses the G20 finding: G20 detects it"; fi
        runc "$lab/out.g27" "$lab/mut27/zero-gap-class-$CLASS_ID.sh" --root "$lab/g22" --corpus "$lab/g22"
        if mmhit "$lab/out.g27" "figure:README.md:$((gl22 - 2))" 13 22; then bad "G27 the no-'have been' mutant still reported '13 gitlinks have been declared' (G22 would not catch it)" "$lab/out.g27"
        else ok "G27 mutant without the have/has-been verb forms loses the G22 finding: G22 detects it"; fi
        runc "$lab/out.g28" "$lab/mut28/zero-gap-class-$CLASS_ID.sh" --root "$lab/g23" --corpus "$lab/g23"
        if mmhit "$lab/out.g28" "figure:README.md:$((gl23 - 2))" 13 22; then bad "G28 the no-'now' mutant still reported '13 gitlinks are now declared' (G23 would not catch it)" "$lab/out.g28"
        else ok "G28 mutant without the 'now' verb form loses the G23 finding: G23 detects it"; fi
    fi

    # G29-G37 — VSC-353 round 5: markdown markup around the number, the verb and "declared"; the compound
    #     noun "submodule paths"; a parenthesis after "declared" that is not a historical marker. Each planted
    #     box has an equal-count (22) control box with the SAME lines, and paired mutants that lose the findings.
    #     ml_lines <name> <line>...: write each line as its own paragraph (first one at n0+2).
    ml_lines() { local f="$lab/ml.$1"; shift; : >"$f"; for _l in "$@"; do printf '\n%s\n' "$_l" >>"$f"; done; }
    mlhits() { # mlhits <out> <n0> <claim> <k>...: how many of the lines n0+2k carry a mismatch finding naming <claim> and 22
        local out=$1 n0=$2 cl=$3 h=0 k; shift 3
        for k in "$@"; do mmhit "$out" "figure:README.md:$((n0 + 2 * k))" "$cl" 22 && h=$((h + 1)); done; echo "$h"
    }
    ml_lines g29 '13 gitlinks are **declared**' '13 gitlinks **are** declared' '13 gitlinks are _declared_.' '13 gitlinks `are declared`'
    ml_lines g30 '22 gitlinks are **declared**' '22 gitlinks **are** declared' '22 gitlinks are _declared_.' '22 gitlinks `are declared`'
    mklab g29 "$corp/clean"; n29=$(wc -l <"$lab/g29/README.md" | tr -d ' ')
    if mutate g29 "$GM22; cat \"$lab/ml.g29\" >> README.md"; then
        runc "$lab/out.g29" "$SELF" --root "$lab/g29" --corpus "$lab/g29"
        h=$(mlhits "$lab/out.g29" "$n29" 13 1 2 3 4)
        if [ "$h" = 4 ]; then ok "G29 markup around the verb / 'declared' (**declared**, **are**, _declared_., \`are declared\`) vs 22 paths: 4 of 4 findings name 13 and 22"
        else bad "G29 markup shapes detected $h of 4 (need 4)" "$lab/out.g29"; fi
    else bad "G29 inoperative mutation"; fi
    mklab g30 "$corp/clean"
    if mutate g30 "$GM22; cat \"$lab/ml.g30\" >> README.md"; then
        runc "$lab/out.g30" "$SELF" --root "$lab/g30" --corpus "$lab/g30"
        if anymm "$lab/out.g30"; then bad "G30 CONTROL: equal count (22) in the four markup shapes was reported as a mismatch" "$lab/out.g30"; else ok "G30 CONTROL: equal count (22 vs 22) in the four markup shapes is not a mismatch"; fi
    else bad "G30 inoperative mutation"; fi
    ml_lines g32 '_13_ gitlinks are declared' '13 submodule paths are declared' '14 declared (current).' '13 declared **(current)**' '13 declared **submodules**' '13 modules are _now_ declared'
    ml_lines g33 '_22_ gitlinks are declared' '22 submodule paths are declared' '22 declared (current).' '22 declared **(current)**' '22 declared **submodules**' '22 modules are _now_ declared'
    mklab g32 "$corp/clean"; n32=$(wc -l <"$lab/g32/README.md" | tr -d ' ')
    if mutate g32 "$GM22; cat \"$lab/ml.g32\" >> README.md"; then
        runc "$lab/out.g32" "$SELF" --root "$lab/g32" --corpus "$lab/g32"
        h=$(( $(mlhits "$lab/out.g32" "$n32" 13 1 2 4 5 6) + $(mlhits "$lab/out.g32" "$n32" 14 3) ))
        if [ "$h" = 6 ]; then ok "G32 _13_, 'submodule paths', '14 declared (current).', '**(current)**', '**submodules**', '_now_' vs 22 paths: 6 of 6 findings name both figures"
        else bad "G32 shapes detected $h of 6 (need 6)" "$lab/out.g32"; fi
    else bad "G32 inoperative mutation"; fi
    mklab g33 "$corp/clean"
    if mutate g33 "$GM22; cat \"$lab/ml.g33\" >> README.md"; then
        runc "$lab/out.g33" "$SELF" --root "$lab/g33" --corpus "$lab/g33"
        if anymm "$lab/out.g33"; then bad "G33 CONTROL: equal count (22) in the six shapes was reported as a mismatch" "$lab/out.g33"; else ok "G33 CONTROL: equal count (22 vs 22) in the six shapes is not a mismatch"; fi
    else bad "G33 inoperative mutation"; fi
    mkdir -p "$lab/mut31" "$lab/mut34" "$lab/mut35" "$lab/mut36" "$lab/mut37"
    for m in mut31 mut34 mut35 mut36 mut37; do cp "$gate" "$lab/$m/"; done
    sed 's/^SEP = .*/SEP = r"[ ]+"/' "$SELF" >"$lab/mut31/zero-gap-class-$CLASS_ID.sh"
    sed 's/^NUMLB = .*/NUMLB = r"\\b"/' "$SELF" >"$lab/mut34/zero-gap-class-$CLASS_ID.sh"
    sed 's/^FLEET_NP = .*/FLEET_NP = FLEET_NOUN/' "$SELF" >"$lab/mut35/zero-gap-class-$CLASS_ID.sh"
    sed 's/^DECL_PAREN = .*/DECL_PAREN = r"(?!)"/' "$SELF" >"$lab/mut36/zero-gap-class-$CLASS_ID.sh"
    sed 's/^MK = .*/MK = r""/' "$SELF" >"$lab/mut37/zero-gap-class-$CLASS_ID.sh"
    if cmp -s "$SELF" "$lab/mut31/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut34/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut35/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut36/zero-gap-class-$CLASS_ID.sh" || cmp -s "$SELF" "$lab/mut37/zero-gap-class-$CLASS_ID.sh"; then bad "G31-G37 inoperative mutation (a sed anchor no longer matches)"
    else
        runc "$lab/out.g31" "$lab/mut31/zero-gap-class-$CLASS_ID.sh" --root "$lab/g29" --corpus "$lab/g29"
        h=$(mlhits "$lab/out.g31" "$n29" 13 1 2 3 4)
        if [ "$h" = 0 ]; then ok "G31 mutant without markup tolerance in the word separator loses all 4 G29 findings: G29 detects it"
        else bad "G31 the no-markup-separator mutant still reported $h of the 4 G29 lines" "$lab/out.g31"; fi
        runc "$lab/out.g34" "$lab/mut34/zero-gap-class-$CLASS_ID.sh" --root "$lab/g32" --corpus "$lab/g32"
        if mmhit "$lab/out.g34" "figure:README.md:$((n32 + 2))" 13 22; then bad "G34 the plain-\\b mutant still reported '_13_ gitlinks are declared' (G32 would not catch it)" "$lab/out.g34"
        else ok "G34 mutant with a plain word boundary before the number loses the '_13_' finding: G32 detects it"; fi
        runc "$lab/out.g35" "$lab/mut35/zero-gap-class-$CLASS_ID.sh" --root "$lab/g32" --corpus "$lab/g32"
        if mmhit "$lab/out.g35" "figure:README.md:$((n32 + 4))" 13 22; then bad "G35 the single-noun mutant still reported '13 submodule paths are declared' (G32 would not catch it)" "$lab/out.g35"
        else ok "G35 mutant without the compound noun loses the 'submodule paths' finding: G32 detects it"; fi
        runc "$lab/out.g36" "$lab/mut36/zero-gap-class-$CLASS_ID.sh" --root "$lab/g32" --corpus "$lab/g32"
        if mmhit "$lab/out.g36" "figure:README.md:$((n32 + 6))" 14 22; then bad "G36 the no-parenthesis mutant still reported '14 declared (current).' (G32 would not catch it)" "$lab/out.g36"
        else ok "G36 mutant without the parenthesis after 'declared' loses the '14 declared (current).' finding: G32 detects it"; fi
        runc "$lab/out.g37" "$lab/mut37/zero-gap-class-$CLASS_ID.sh" --root "$lab/g29" --corpus "$lab/g29"
        h=$(mlhits "$lab/out.g37" "$n29" 13 1 2 3 4)
        if [ "$h" = 0 ]; then ok "G37 mutant with markup tolerance removed everywhere loses all 4 G29 findings: G29 detects it"
        else bad "G37 the no-markup mutant still reported $h of the 4 G29 lines" "$lab/out.g37"; fi
    fi

    fp1=$(live_fp)
    if [ "$fp0" = "$fp1" ]; then ok "L1the live corpus, this script and the ledger gate are byte-identical after the battery"
    else bad "L1  the live files moved during the battery"; fi
    printf '\n== %d passed / %d failed ==\n' "$passed" "$failed"
    [ "$failed" -eq 0 ]
}

if [ "$PROVE" -eq 1 ]; then
    prove_failure; exit $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# the class
# ─────────────────────────────────────────────────────────────────────────────
# die_cni <part> <reason>: the whole run could not determine (rc 2, never clean)
die_cni() {
    if [ "$EMIT" -eq 1 ]; then printf 'zero-gap-class-%s: %s\n' "$CLASS_ID" "$2" >&2; exit 2; fi
    printf 'COULD-NOT-INSPECT %s %s\nINSPECTED 0\nPOPULATION-SHA %s\n' "$1" "$2" "$EMPTY_SHA"
    exit 2
}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then die_cni - "--root is not a directory"; fi
if [ -n "$CORPUS" ]; then
    [ -d "$CORPUS" ] || die_cni - "--corpus is not a directory"
    BASE=$(cd -- "$CORPUS" && pwd -P) || die_cni - "--corpus cannot be entered"
else
    BASE=$(cd -- "$ROOT" && pwd -P) || die_cni - "--root cannot be entered"
fi
python3 -c 'import re, hashlib, os, sys' >/dev/null 2>&1 \
    || die_cni - "python3 is absent or broken: no ledger anchor can be located and no figure scanned"
WORK=$(mktemp -d) || die_cni - "mktemp failed: no private work directory"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/sf.py" <<'PY'
# The figure scanner and the ledger-verdict locator of zero-gap-class-stale-figures.sh.
# Reads only; prints ASCII only. See the script header for every rule applied here.
import fnmatch, os, re, stat, sys, hashlib
from collections import defaultdict

CLASS = 'stale-figures'
LEDGER_REL = b'docs/claim-ledger.tsv'
TOP = {b'CLAUDE.md', b'AGENTS.md', b'QWEN.md', b'GEMINI.md', b'CONTINUATION.md', b'README.md'}
MIRRORS = {b'AGENTS.md', b'QWEN.md', b'GEMINI.md'}
FIXPFX = b'_tests/fixtures/zero-gap/'

# ---- point-in-time §3 caption gating (T091; see the script header) --------------------------
PIT_REL = 'docs/zero-gap/point-in-time.tsv'
CAPTION_MARK = 'own dated caption'
SECTION_MARK = '§3'          # '§3'
ENTRY_RE = re.compile(r'^###[ \t]+\S')     # an entry heading (exactly level 3)
SECTION_RE = re.compile(r'^##[ \t]+\S')    # a section heading (exactly level 2)
DATE_CAPTION_RE = re.compile(r'\b(?:19|20)\d{2}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])\b')


def captioned(ls, i):
    """True when 1-indexed line i of the line list ls sits inside a "§3" section's own entry
    (the nearest preceding "### " heading) AND that entry heading itself carries a YYYY-MM-DD
    date. Text before the first entry of the section, or an entry heading with no date, is not
    captioned. This is the ONLY rule this class applies from docs/zero-gap/point-in-time.tsv;
    see the script header."""
    entry = None
    for k in range(i - 1, -1, -1):
        if ENTRY_RE.match(ls[k]):
            entry = k
            break
        if SECTION_RE.match(ls[k]):
            return False   # reached the section heading (or a different section) with no entry
    if entry is None or not DATE_CAPTION_RE.search(ls[entry]):
        return False
    for k in range(entry - 1, -1, -1):
        if SECTION_RE.match(ls[k]):
            return SECTION_MARK in ls[k]
    return False

MK = r'[*`_]*'
NUM = r'[0-9][0-9,]*'
# VSC-353 round 5 — markdown markup tolerance. MK is the markup run: any number of the three characters
# * ` _ (so "**", "__", "`", "_" and mixtures). SEP is the separator between two words of a shape: markup,
# whitespace, markup, so "gitlinks **are** declared", "are _declared_" and "`are declared`" are one shape
# with "gitlinks are declared". Where markup is tolerated (ONLY these places): around the number
# ("**13**", "_13_"), between any two words of a shape (SEP), after the last word, and before the closing
# punctuation / parenthesis of "<n> declared". NUMLB is the number's left boundary: not after a letter or
# digit (so "_13_" qualifies, unlike \b, because "_" is a word character) and not the fraction of a decimal
# ("13.5 gitlinks" is not a claim of 5).
SEP = MK + r'\s+' + MK
NUMLB = r'(?<![A-Za-z0-9])(?<![0-9]\.)'
# A hex id (a commit/blob sha) is NOT a figure (reconcile 5): a line whose only number-like token is a hex id is not in the population. `bytes` and the exit/rc shape are (review RULING 2).
FLEET_NOUN = r'(?:submodules?|gitlinks?|modules?|repos?|repositories|paths?)'
# a fleet noun, optionally a second one ("submodule paths", "gitlink paths")
FLEET_NP = FLEET_NOUN + r'(?:' + SEP + FLEET_NOUN + r')?'
# VSC-353 round 4/5: the verb forms of B1 ("are declared", "were now declared", "have been declared"), markup tolerant.
DECL_VERB = r'(?:(?:is|are|was|were)(?:' + SEP + r'now)?|(?:has|have)' + SEP + r'been)'
# B1 = "<n> <fleet noun> <verb> declared": the ONE pattern behind both the figure-population shape and the comparison.
B1_SRC = NUMLB + r'(' + NUM + r')' + SEP + FLEET_NP + MK + SEP + DECL_VERB + SEP + r'declared(?![A-Za-z0-9])'
RC = r'\b(?:exit(?:s|ed)?|rc)' + MK + r'(?:\s+|\s*=\s*)' + MK + r'[0-9]+\b'
SHAPES = [
    re.compile(r'(?<![A-Za-z0-9])' + NUM + MK + r'\s+' + MK + r'(?:(?:files?|tests?|gates?|scripts?|anchors?|lines?|commits?|items?|rows?|checks?|submodules?|bytes?|owned|PASS|FAIL|CURRENT|DRIFT)\b|(?i:declared)(?![A-Za-z0-9]))'),
    re.compile(r'\b' + NUM + MK + r'\s+of\s+' + MK + NUM + r'\b'),
    re.compile(r'\b[0-9]+/[0-9]+\b'),
    re.compile(RC, re.I),
    # VSC-353 B1 (appended LAST: code indexes SHAPES[3] as the exit/rc shape and SHAPES[:3] as the rest):
    # "<n> <fleet noun> (is|are|were) declared" ("13 gitlinks are declared") is a figure line.
    re.compile(B1_SRC, re.I),
]
STRIKE = re.compile(r'~~.*?~~')
SKIP = re.compile(r'\b(?:withdrawn|superseded|historical|obsolete)\b', re.I)
STATUS = re.compile(r'\b(?:PASS|FAIL|UNDET|UNDETERMINED|CURRENT|DRIFT|VERIFIED|DEBT)\b|' + RC + r'|\b(?:security|credential|secret|leak)', re.I)
# VSC-353: a withdrawal stated on the line IMMEDIATELY AFTER a figure line, when that next line opens with a
# deictic subject ("That figure is WITHDRAWN ...") and names the marker in its first sentence, annotates
# the figure line above it. A bare marker elsewhere on the next line does NOT (a live paragraph often puts
# a withdrawn and a live figure on adjacent lines).
NEXT_WITHDRAWN = re.compile(r'^[\s>*_`(\[]*(?:that|this|the above|it|which|those|these|the figure|the reading|the sentence)\b[^.!?]{0,100}?\b(?:withdrawn|superseded|historical|obsolete)\b', re.I)
# VSC-353: an exit-code MEANING line ("exit 0 = clean, exit 1 = finding"): every figure on it is an
# exit/rc shape followed by "=", an arrow or "means". A measured status ("exits 0 at 12 CURRENT") has a
# different tail and stays a figure; so does any line carrying a non-rc figure.
RC_MEANING_TAIL = re.compile(r'^[*`_]*\s*(?:=|->|→|means\b)')
# VSC-353 clause B: "<n> declared" is compared with the number of paths .gitmodules declares.
# "declared" must be followed (markup allowed between) by end of line, closing punctuation, a parenthesis
# (round 5: "14 declared (current)." is compared; a historical marker never gets here, the skip rule runs
# before the comparison), or a fleet noun (submodule, gitlink, module, repo, repository, path),
# "in total/all" or today/now/currently/so far.
# "declared pairs", "declared members" etc. are not submodule counts and are not compared.
DECL_PAREN = r'\('
DECL_PUNCT = r'[.,;:)\]*_`|—–]'
DECL_NOUN = r'(?:submodules?|gitlinks?|modules?|repos?|repositories|paths?|in' + r'\s+total|in\s+all|today|now|currently|so\s+far)'
DECLARED_RE = re.compile(NUMLB + r'(' + NUM + r')' + SEP + r'declared(?![A-Za-z0-9])(?=' + MK + r'(?:\s*' + MK + r'(?:$|' + DECL_PUNCT + r'|' + DECL_PAREN + r')|\s+' + MK + DECL_NOUN + r'(?![A-Za-z0-9])))', re.I)
# VSC-353 B1: the same pattern as the figure-population shape, compared with the same count.
DECLARED_ARE_RE = re.compile(B1_SRC, re.I)
GITMODULES_REL = '.gitmodules'
GM_PATH_RE = re.compile(r'^[ \t]*path[ \t]*=[ \t]*\S', re.M)
AGG_MAX = 30        # an aggregate lists at most this many line numbers
VERIFY_TYPES = {'green-but-broken', 'coverage-theater', 'rubber-stamp-verified'}


def b(s):
    return s.encode('utf-8', 'surrogateescape')


def read_nul(p):
    return [x for x in open(p, 'rb').read().split(b'\0') if x]


def docs_from(listfile):
    # BOUNDARY RULING (progress.yml reconcile 6): this class owns the six root documents and the
    # lines a ledger anchor matches; docs/**/*.md belongs to doc-count-drift and is not scanned.
    out = set()
    for p in read_nul(listfile):
        if p.startswith(FIXPFX):
            continue
        if p in TOP:
            out.add(p)
    return sorted(out)


def unsafe(base, rel):
    """None when <base>/<rel> is a regular file (not a symlink) whose real path stays inside
    <base>; else the reason. Nothing is opened: a FIFO would block, /dev/zero would exhaust
    memory, and a link leaving the tree would echo text from outside it."""
    p = os.path.join(base, rel)
    try:
        st = os.lstat(p)
    except OSError:
        return 'absent'
    if stat.S_ISLNK(st.st_mode):
        return 'a symbolic link: never followed (it could name a FIFO, a device or a file outside the tree)'
    if not stat.S_ISREG(st.st_mode):
        return 'not a regular file (a FIFO, device or socket): never opened'
    rb = os.path.realpath(base)
    rp = os.path.realpath(p)
    if not (rp == rb or rp.startswith(rb.rstrip(b'/') + b'/')):
        return 'resolves outside the scanned tree (a symlinked directory): never read'
    return None


def ledger_rows(base):
    """claim rows exactly as scripts/verify-claim-ledger.sh reads them
    (a final line without a newline is not read by its `while read` loop).
    None = no ledger; 'UNSAFE' = the ledger itself is not a regular file inside the tree."""
    path = os.path.join(base, LEDGER_REL)
    if not os.path.lexists(path):
        return None
    if unsafe(base, LEDGER_REL):
        return 'UNSAFE'
    data = open(path, 'rb').read().split(b'\n')[:-1]
    rows = []
    for n, raw in enumerate(data, 1):
        line = raw.decode('utf-8', 'surrogateescape')
        if line == '' or line.startswith('#'):
            continue
        f = line.split('\t')
        if f[0] == 'claim':
            rows.append((n, f))
    return rows


def surface_ok(s):
    return s != '' and not s.startswith('/') and all(seg not in ('', '.', '..') for seg in s.split('/'))


def read_text(path):
    # the same open mode the ledger gate uses, so line numbers agree with its matches
    return open(path, encoding='utf-8', errors='replace').read()


def lines_of(t):
    ls = t.split('\n')
    if ls and ls[-1] == '':
        ls.pop()
    return ls


def first_figure(s):
    best = None
    for rx in SHAPES:
        m = rx.search(s)
        if m and (best is None or m.start() < best.start()):
            best = m
    return best


def exit_meaning_only(s):
    """True when every figure on the (strike-stripped) line s is an exit/rc shape that is followed by
    '=' / an arrow / 'means', i.e. the line states what an exit code MEANS, not a measured value."""
    rcs = list(SHAPES[3].finditer(s))
    if not rcs:
        return False
    for rx in SHAPES[:3] + SHAPES[4:]:
        if rx.search(s):
            return False
    return all(RC_MEANING_TAIL.match(s[m.end():]) for m in rcs)


def all_figures(s, limit=4):
    """distinct figure texts of the line in left-to-right order (shapes may overlap; the leftmost wins)"""
    seen, out = [], []
    ms = []
    for rx in SHAPES:
        ms.extend(rx.finditer(s))
    for m in sorted(ms, key=lambda m: (m.start(), -m.end())):
        t = m.group(0)
        if t not in seen:
            seen.append(t)
            out.append(t)
        if len(out) >= limit:
            break
    return out


def clean(s, n=48):
    s = re.sub(r'[*`_]', '', s)
    s = ''.join(ch if 32 <= ord(ch) < 127 else '?' for ch in s)
    s = re.sub(r'\s+', ' ', s).strip().replace("'", '')
    return s[:n] if s else '?'


def main():
    cmd, base = sys.argv[1], os.fsencode(sys.argv[2])
    listfile = sys.argv[3]
    docs = docs_from(listfile)
    rows = ledger_rows(base)
    ledger_unsafe = rows == 'UNSAFE'
    if ledger_unsafe:
        rows = []
    # surfaces the ledger gate would open: any that is not a regular file inside the tree means
    # the gate is NOT run (it would block on a FIFO or read /dev/zero until memory runs out)
    bad_surf = set()
    for _, f in rows or []:
        surf = f[2] if len(f) > 2 else ''
        if surface_ok(surf) and os.path.lexists(os.path.join(base, b(surf))) and unsafe(base, b(surf)):
            bad_surf.add(surf)
    if cmd == 'collect':
        enc = set(docs)
        for _, f in rows or []:
            for k in (1, 2):
                if len(f) > k and f[k]:
                    enc.add(b(f[k]))
        with open(sys.argv[4], 'wb') as fh:
            fh.write(b''.join(x + b'\0' for x in sorted(enc)))
        with open(sys.argv[5], 'w') as fh:
            fh.write('%d\n' % (len(bad_surf) + (1 if ledger_unsafe else 0)))
        return 0

    raw = read_nul(sys.argv[4])
    tok = open(sys.argv[5], 'rb').read().decode('ascii').split('\n')[:-1]
    out = sys.stdout
    if len(raw) != len(tok):
        out.write('COULD-NOT-INSPECT - the percent-encoding map is inconsistent (%d items, %d tokens)\n' % (len(raw), len(tok)))
        out.write('INSPECTED 0\nPOPULATION-SHA %s\n' % hashlib.sha256(b'').hexdigest())
        return 2
    E = dict(zip(raw, tok))

    def e(s):
        return E[b(s) if isinstance(s, str) else s]

    cni, findings = set(), set()
    pop, notinsp = set(), set()
    fig = {}            # token -> (doc, line, text, match)
    text_of = {}        # doc -> list of lines

    # ---- point-in-time §3 caption gating (T091) ----------------------------------------------
    gated_docs = set()
    pit_path = os.path.join(base, b(PIT_REL))
    if os.path.lexists(pit_path):
        pit_why = unsafe(base, b(PIT_REL))
        if pit_why:
            cni.add((PIT_REL, pit_why + ': no point-in-time exemption is applied'))
        else:
            try:
                pit_text = read_text(pit_path)
            except OSError:
                cni.add((PIT_REL, 'the point-in-time exemption list could not be read'))
                pit_text = None
            if pit_text is not None:
                for n, ln in enumerate(pit_text.split('\n'), 1):
                    if not ln.strip() or ln.startswith('#'):
                        continue
                    flds = ln.split('\t')
                    if len(flds) >= 2 and flds[0] == 'path' and flds[1].strip() == 'reason':
                        continue
                    if len(flds) < 2 or not flds[0].strip() or not flds[1].strip():
                        cni.add(('%s:%d' % (PIT_REL, n), 'row carries no path or no reason: not applied (an exemption without its reason is refused)'))
                        continue
                    patpath, reason = flds[0].strip(), flds[1]
                    if CAPTION_MARK not in reason.lower():
                        continue  # a blanket-exemption row: doc-count-drift's mechanism, not this class's
                    for doc in docs:
                        if fnmatch.fnmatchcase(doc.decode('utf-8', 'surrogateescape'), patpath):
                            gated_docs.add(doc)

    for doc in docs:
        agg = 'figures:%s' % e(doc)
        pop.add(agg)
        why = unsafe(base, doc)
        if why:
            cni.add((e(doc), why))
            notinsp.add(agg)
            continue
        try:
            ls = lines_of(read_text(os.path.join(base, doc)))
        except OSError:
            cni.add((e(doc), 'listed as a document but not readable'))
            notinsp.add(agg)
            continue
        text_of[doc] = ls
        gated = doc in gated_docs
        for i, l in enumerate(ls, 1):
            s = STRIKE.sub(' ', l)
            m = first_figure(s)
            if m is None or SKIP.search(s):
                continue
            if exit_meaning_only(s):
                continue      # VSC-353: states what an exit code means, not a measured value
            if i < len(ls) and NEXT_WITHDRAWN.match(STRIKE.sub(' ', ls[i])):
                continue      # VSC-353: the next line withdraws this one ("That figure is WITHDRAWN")
            if gated and captioned(ls, i):
                continue      # point-in-time: this entry's own dated caption, true when written (T091)
            t = 'figure:%s:%d' % (e(doc), i)
            fig[t] = (doc, i, l, m)
            pop.add(t)

    # ---- VSC-353 clause B: the real count of declared submodule paths, from .gitmodules AT --root ----
    decl = None
    gm_path = os.path.join(base, b(GITMODULES_REL))
    if not os.path.lexists(gm_path):
        sys.stderr.write('NOTE: no .gitmodules at --root: the "<n> declared" comparison is skipped (no finding)\n')
    else:
        gm_why = unsafe(base, b(GITMODULES_REL))
        if gm_why:
            cni.add((GITMODULES_REL, gm_why + ': the "<n> declared" comparison is not made'))
        else:
            try:
                gm_n = len(GM_PATH_RE.findall(read_text(gm_path)))
            except OSError:
                gm_n = None
                cni.add((GITMODULES_REL, '.gitmodules could not be read: the "<n> declared" comparison is not made'))
            if gm_n:
                decl = gm_n
            elif gm_n == 0:
                sys.stderr.write('NOTE: .gitmodules at --root declares no path: the "<n> declared" comparison is skipped (no finding)\n')

    info = []           # per claim row
    idcount = defaultdict(int)
    for n, f in rows or []:
        rid = f[1] if len(f) > 1 else ''
        rtok = ('claim:' + e(rid)) if rid else ('claim:-ledger-line-%d' % n)
        idcount[rid] += 1
        occ, surf = [], (f[2] if len(f) > 2 else '')
        if len(f) == 10 and f[3] in ('prose', 'assert') and surface_ok(surf):
            sp = os.path.join(base, b(surf))
            if surf in bad_surf:
                cni.add((e(surf), 'ledger surface is ' + unsafe(base, b(surf))))
            elif os.path.isfile(sp):
                try:
                    rx = re.compile(f[8], re.M)
                    t = read_text(sp)
                except (re.error, OSError):
                    rx = None
                if rx is not None and rx.groups == (1 if f[3] == 'prose' else 0):
                    for m in rx.finditer(t):
                        val = m.group(1) if f[3] == 'prose' else '__PRESENT__'
                        pos = m.start(1) if f[3] == 'prose' and m.start(1) >= 0 else m.start()
                        ln = t.count('\n', 0, pos) + 1
                        for piece in str(val).split('\n'):
                            if piece:
                                occ.append('figure:%s:%d' % (e(surf), ln))
                    sdoc = b(surf)
                    if sdoc not in text_of:
                        text_of[sdoc] = lines_of(t)
        info.append(dict(n=n, f=f, id=rid, tok=rtok, occ=occ, surf=surf))
        pop.add(rtok)
        pop.update(occ)

    if cmd == 'emit':
        for t in sorted(pop):
            out.write(t + '\n')
        return 0

    # ── run: map the ledger gate's verdicts onto located findings ──
    gate_out, grc = sys.argv[6], sys.argv[7]
    verd = defaultdict(list)
    gate_broken = None
    ledger_tok = 'docs/claim-ledger.tsv'
    if rows is None:
        cni.add((ledger_tok, 'absent: no recorded figure in the scanned documents can be re-measured'))
    elif ledger_unsafe:
        gate_broken = 'the ledger is ' + unsafe(base, LEDGER_REL) + ': no ledger row can be read or re-measured'
    elif grc == 'UNSAFE':
        gate_broken = 'a ledger surface is not a regular file inside the tree, so scripts/verify-claim-ledger.sh (which opens every surface) was not run: no ledger row can be re-measured'
    elif grc == '124':
        gate_broken = 'scripts/verify-claim-ledger.sh did not finish within its time limit: no verdict can be read'
    elif grc == 'MISSING':
        gate_broken = 'scripts/verify-claim-ledger.sh is absent next to this class: no ledger row can be re-measured'
    else:
        try:
            g = open(gate_out, encoding='utf-8', errors='replace').read()
        except OSError:
            g = ''
        if grc not in ('0', '1', '2') or '== claim-vs-reality ledger' not in g:
            gate_broken = 'scripts/verify-claim-ledger.sh exited %s without its report: no verdict can be read' % clean(grc, 12)
        else:
            for line in g.split('\n'):
                m = re.match(r'^VERIFIED (\S+)\s', line)
                if m:
                    verd[m.group(1)].append(('ok',)); continue
                m = re.match(r"^FALSE   \[malformed\] row '(.*)' has (\d+) field", line)
                if m:
                    verd[m.group(1)].append(('malformed', 'it has %s tab-separated fields, not 10' % m.group(2))); continue
                m = re.match(r'^FALSE   \[malformed\] (\S+) has (kind|operator) ', line)
                if m:
                    verd[m.group(1)].append(('malformed', 'its %s is outside the closed set' % m.group(2))); continue
                m = re.match(r'^FALSE   \[untyped\]\s+(\S+) carries', line)
                if m:
                    verd[m.group(1)].append(('untyped',)); continue
                m = re.match(r'^FALSE   \[orphan\]\s+(\S+) ', line)
                if m:
                    verd[m.group(1)].append(('orphan',)); continue
                m = re.match(r"^FALSE   \[([^\]/]+)/([^\]]+)\] (\S+) \S+ occurrence (\d+) of the claim in .* says '(.*)'; a fresh measurement says '(.*)$", line)
                if m:
                    r = m.group(6)
                    r = r[:-2] if r.endswith("'.") else r
                    verd[m.group(3)].append(('false', int(m.group(4)), m.group(5), r)); continue
                m = re.match(r'^UNDET   \[(\w+)\]\s+(\S+) \S+ (.*)$', line)
                if m:
                    verd[m.group(2)].append(('undet', m.group(1))); continue
            if not rows:
                cni.add((ledger_tok, 'holds zero claim rows: nothing is re-measured, and a ledger over nothing certifies nothing'))

    covered, dup_seen = set(), set()
    for r in info:
        ref = 'docs/claim-ledger.tsv:%d' % r['n']
        rid_txt = clean(r['id'], 40)
        if gate_broken:
            # a row exists for these lines, it just could not be re-measured: they are
            # undetermined, never 'without a re-measure command'
            covered.update(r['occ'])
            notinsp.add(r['tok'])
            continue
        if r['id'] and idcount[r['id']] > 1 and r['id'] not in dup_seen:
            dup_seen.add(r['id'])     # one finding per duplicated id, at its FIRST row
            findings.add(('medium', r['tok'], 'ledger claim id %s is not unique (%d rows): its verdicts cannot be attributed to one claim' % (rid_txt, idcount[r['id']]), ref))
        vs = verd.get(r['id'], []) if r['id'] else []
        if not vs:
            cni.add((r['tok'], 'scripts/verify-claim-ledger.sh printed no parseable verdict for this row'))
            covered.update(r['occ'])
            notinsp.add(r['tok'])
            continue
        kinds = {v[0] for v in vs}
        if 'untyped' in kinds:
            findings.add(('medium', r['tok'], 'ledger row %s carries a bluff type outside the closed vocabulary of 11.4.266(B), so its claim is not re-measured (UNTYPED)' % rid_txt, ref))
        for v in vs:
            if v[0] == 'malformed':
                findings.add(('medium', r['tok'], 'ledger row %s is malformed (%s), so its claim is not re-measured' % (rid_txt, v[1]), ref))
        if 'orphan' in kinds:
            findings.add(('medium', r['tok'], 'ledger row %s anchor matches nothing in %s: the row protects no recorded figure (ORPHAN)' % (rid_txt, clean(r['surf'], 60)), ref))
        if kinds & {'ok', 'false', 'undet'}:
            covered.update(r['occ'])
        f = r['f']
        for v in vs:
            if v[0] != 'false':
                continue
            k = v[1]
            loc = r['occ'][k - 1] if 1 <= k <= len(r['occ']) else r['tok']
            line_txt = ''
            if loc.startswith('figure:'):
                sdoc, ln = b(r['surf']), int(loc.rsplit(':', 1)[1])
                ls = text_of.get(sdoc, [])
                line_txt = ls[ln - 1] if 0 < ln <= len(ls) else ''
                eref = '%s:%d' % (e(r['surf']), ln)
            else:
                eref = ref
            high = bool(STATUS.search(line_txt)) or (len(f) > 4 and f[4] in VERIFY_TYPES) or (len(f) > 5 and f[5] == 'blocker')
            findings.add(('high' if high else 'medium', loc,
                          'ledger row %s is FALSE: the document states %s and a fresh re-measure by scripts/verify-claim-ledger.sh gives %s' % (rid_txt, "'" + clean(v[2], 40) + "'", "'" + clean(v[3], 40) + "'"), eref))
        if 'undet' in kinds:
            why = sorted({v[1] for v in vs if v[0] == 'undet'})
            cni.add((r['tok'], 'scripts/verify-claim-ledger.sh could not re-measure this row (%s): the claim is unchallenged, never verified' % clean(','.join(why), 30)))
            notinsp.add(r['tok'])
    if gate_broken:
        cni.add((ledger_tok, gate_broken))

    cl_texts = set()
    cls = text_of.get(b'CLAUDE.md', [])
    for t in pop:
        if t.startswith('figure:CLAUDE.md:'):
            ln = int(t.rsplit(':', 1)[1])
            if 0 < ln <= len(cls):
                cl_texts.add(cls[ln - 1])
    low = defaultdict(list)     # doc -> [(line, figure text)] of LOW unledgered figures
    for t, (doc, i, l, m) in fig.items():
        if decl is not None and not (doc in MIRRORS and l in cl_texts):
            _ls = STRIKE.sub(' ', l)
            claimed = sorted({int(x.replace(',', '')) for x in DECLARED_RE.findall(_ls) + DECLARED_ARE_RE.findall(_ls)})
            if decl is not None and any(n != decl for n in claimed):  # DECL-COMPARE
                findings.add(('medium', t, 'claims %s declared but .gitmodules declares %d (mismatch): the recorded figure disagrees with the real count of declared submodule paths' % (' and '.join(str(n) for n in claimed if n != decl), decl), '%s:%d' % (e(doc), i)))
        if t in covered:
            continue
        if doc in MIRRORS and l in cl_texts:
            continue
        if STATUS.search(l):
            figs = all_figures(STRIKE.sub(' ', l))
            shown = "'" + clean(m.group(0)) + "'" + (' (also ' + ', '.join("'" + clean(x, 24) + "'" for x in figs if x != m.group(0)) + ')' if len(figs) > 1 else '')
            findings.add(('medium', t, 'recorded figure %s has no re-measure command: no docs/claim-ledger.tsv row anchors this line' % shown, '%s:%d' % (e(doc), i)))
        else:
            low[doc].append((i, m.group(0)))
    # reconcile 5: the LOW tier is ONE aggregate finding per document, located figures:<doc>
    for doc, xs in low.items():
        xs.sort()
        nums = ' '.join(str(i) for i, _ in xs[:AGG_MAX]) + (' (+%d more)' % (len(xs) - AGG_MAX) if len(xs) > AGG_MAX else '')
        findings.add(('low', 'figures:%s' % e(doc),
                      '%d recorded figure(s) with no re-measure command on line(s) %s: no docs/claim-ledger.tsv row anchors them (first: %s)' % (len(xs), nums, "'" + clean(xs[0][1]) + "'"),
                      '%s:%d' % (e(doc), xs[0][0])))

    lines = []
    for sev, loc, desc, ref in sorted(findings, key=lambda x: (x[1], x[2], x[0], x[3])):
        lines.append('FINDING %s %s docs-drift %s %s %s' % (CLASS, sev, loc, desc, ref))
    if not pop:
        cni.add(('-', 'population enumerated to zero items: no scanned document carries a figure and no ledger row exists; a class that inspects nothing is never clean'))
    for part, reason in sorted(cni):
        lines.append('COULD-NOT-INSPECT %s %s' % (part, reason))
    lines.append('INSPECTED %d' % (len(pop) - len(notinsp & pop)))
    lines.append('POPULATION-SHA %s' % hashlib.sha256(''.join(t + '\n' for t in sorted(pop)).encode('ascii')).hexdigest())
    out.write('\n'.join(lines) + '\n')
    if findings:
        return 1
    if cni:
        return 2
    return 0


try:
    RC = main()
except Exception as exc:  # a crash is exit 3, which the wrapper turns into rc 2 (never 1)
    sys.stderr.write('stale-figures scanner crashed: %s\n' % type(exc).__name__)
    RC = 3
sys.stdout.flush()
sys.exit(RC)
PY

LIST="$WORK/list"
if [ -n "$CORPUS" ]; then
    # every non-directory entry (a symlink or FIFO is listed so that it is REPORTED, never read)
    ( cd -- "$BASE" && find . ! -type d -print0 ) | sed -z 's|^\./||' >"$LIST" \
        || die_cni - "the corpus could not be listed"
else
    git -C "$BASE" ls-files -z --cached --others --exclude-standard -- \
        CLAUDE.md AGENTS.md QWEN.md GEMINI.md CONTINUATION.md README.md \
        >"$LIST" 2>"$WORK/git.err" \
        || die_cni - "--root is not a git work tree: git ls-files failed, so no document can be enumerated"
fi
python3 "$WORK/sf.py" collect "$BASE" "$LIST" "$WORK/enc.raw" "$WORK/unsafe.n" 2>"$WORK/py.err" \
    || die_cni - "the population could not be collected (python3 failed)"
zg_pct_encode_z <"$WORK/enc.raw" >"$WORK/enc.tok" || die_cni - "percent-encoding failed"

if [ "$EMIT" -eq 1 ]; then
    python3 "$WORK/sf.py" emit "$BASE" "$LIST" "$WORK/enc.raw" "$WORK/enc.tok" >"$WORK/emit.out" || exit 2
    cat "$WORK/emit.out"
    exit 0
fi

GRC=NOLEDGER
: >"$WORK/gate.out"
if [ -f "$BASE/docs/claim-ledger.tsv" ]; then
    if [ "$(cat "$WORK/unsafe.n" 2>/dev/null)" != 0 ]; then
        GRC=UNSAFE      # a surface (or the ledger) is a symlink/special file: the gate would open it
    elif [ -f "$SELFDIR/verify-claim-ledger.sh" ]; then
        # bounded: a probe that never ends is an undetermined ledger, never a hung sweep
        ( cd -- "$BASE" && timeout -k 5 300 bash "$SELFDIR/verify-claim-ledger.sh" --root "$BASE" --verbose ) \
            >"$WORK/gate.out" 2>&1 </dev/null
        GRC=$?
    else
        GRC=MISSING
    fi
fi
python3 "$WORK/sf.py" run "$BASE" "$LIST" "$WORK/enc.raw" "$WORK/enc.tok" "$WORK/gate.out" "$GRC"
rc=$?
case "$rc" in
    0|1|2) exit "$rc" ;;
    *) printf 'COULD-NOT-INSPECT - the class scanner crashed (python3 exit %s)\nINSPECTED 0\nPOPULATION-SHA %s\n' "$rc" "$EMPTY_SHA"; exit 2 ;;
esac
