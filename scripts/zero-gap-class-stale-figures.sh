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
# ── THE SKIP RULE (historical / withdrawn text), PRECISELY ────────────────────
# A scanned line whose text — after `~~...~~` spans are removed — contains, as a
# whole word and case-insensitively, one of  withdrawn  superseded  historical
# obsolete  is an ANNOTATED HISTORICAL line: it is not a live claim and is NOT
# part of the unledgered-figure population. A figure that only occurs inside a
# `~~...~~` span is likewise not a figure. The rule is LINE-level: a withdrawal
# stated on the previous line does not cover the next one (this repository often
# puts a withdrawn and a live figure in one paragraph, so a paragraph-level rule
# would hide live figures). Lines matched by a ledger anchor are ALWAYS in the
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
# ── MEASURED ON THE LIVE TREE (2026-09-26, after the review fix round) ──────
# rc 1 in 9 s: 1 high (the ledger row the KNOWN SEED describes), 514 medium
# (CONTINUATION.md 412, CLAUDE.md 96, README.md 7 — AGENTS/QWEN/GEMINI lines are
# byte-identical to CLAUDE.md and deduped) and 2 low aggregates (CLAUDE.md 59
# lines, CONTINUATION.md 475 lines); INSPECTED 1540. Before the fix round:
# 2676 findings over docs/** with hex ids counted. Hand-read of 10 medium hits
# (every 52nd): 7 are recorded figures stated as measured facts; 3 are not (a
# withdrawn quote whose WITHDRAWN marker is on the next line; two lines stating
# exit-code SEMANTICS, "exit 0 = push OK", "a skip exits 0"). Precision 7/10.
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
#   * A withdrawal stated on a different line from the figure it withdraws (the
#     figure is then reported); an unannotated historical figure (reported);
#     an exit-code SEMANTICS line ("exit 0 = pass") is reported as a figure.
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
    # M1e — docs/** is outside the population (boundary ruling: doc-count-drift owns it).
    if grep -q '^FINDING [^ ]* [^ ]* [^ ]* figures\?:docs/' "$lab/out.m1"; then bad "M1e a docs/** line was reported" "$lab/out.m1"
    else ok "M1e planted docs/notes.md and docs/sub/deep.md (figures, hex) yield nothing: docs/** is not scanned"; fi

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

    fp1=$(live_fp)
    if [ "$fp0" = "$fp1" ]; then ok "L1  the live corpus, this script and the ledger gate are byte-identical after the battery"
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
import os, re, stat, sys, hashlib
from collections import defaultdict

CLASS = 'stale-figures'
LEDGER_REL = b'docs/claim-ledger.tsv'
TOP = {b'CLAUDE.md', b'AGENTS.md', b'QWEN.md', b'GEMINI.md', b'CONTINUATION.md', b'README.md'}
MIRRORS = {b'AGENTS.md', b'QWEN.md', b'GEMINI.md'}
FIXPFX = b'_tests/fixtures/zero-gap/'

MK = r'[*`_]*'
NUM = r'[0-9][0-9,]*'
# A hex id (a commit/blob sha) is NOT a figure (reconcile 5): a line whose only number-like
# token is a hex id is not in the population. `bytes` and the exit/rc shape are (review RULING 2).
RC = r'\b(?:exit(?:s|ed)?|rc)' + MK + r'(?:\s+|\s*=\s*)' + MK + r'[0-9]+\b'
SHAPES = [
    re.compile(r'\b' + NUM + MK + r'\s+' + MK + r'(?:files?|tests?|gates?|scripts?|anchors?|lines?|commits?|items?|rows?|checks?|submodules?|bytes?|PASS|FAIL|CURRENT|DRIFT)\b'),
    re.compile(r'\b' + NUM + MK + r'\s+of\s+' + MK + NUM + r'\b'),
    re.compile(r'\b[0-9]+/[0-9]+\b'),
    re.compile(RC, re.I),
]
STRIKE = re.compile(r'~~.*?~~')
SKIP = re.compile(r'\b(?:withdrawn|superseded|historical|obsolete)\b', re.I)
STATUS = re.compile(r'\b(?:PASS|FAIL|UNDET|UNDETERMINED|CURRENT|DRIFT|VERIFIED|DEBT)\b|' + RC + r'|\b(?:security|credential|secret|leak)', re.I)
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
        for i, l in enumerate(ls, 1):
            s = STRIKE.sub(' ', l)
            m = first_figure(s)
            if m is None or SKIP.search(s):
                continue
            t = 'figure:%s:%d' % (e(doc), i)
            fig[t] = (doc, i, l, m)
            pop.add(t)

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
        if t in covered:
            continue
        if doc in MIRRORS and l in cl_texts:
            continue
        if STATUS.search(l):
            findings.add(('medium', t, 'recorded figure %s has no re-measure command: no docs/claim-ledger.tsv row anchors this line' % ("'" + clean(m.group(0)) + "'"), '%s:%d' % (e(doc), i)))
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
