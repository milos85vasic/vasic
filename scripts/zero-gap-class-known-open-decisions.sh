#!/usr/bin/env bash
# zero-gap-class-known-open-decisions.sh — sweep class `known-open-decisions`
# (feature 010, task T034; class contract: docs/zero-gap/README.md).
#
# WHAT IT DETECTS
#   Operator decisions that are recorded as pending but state NEITHER an option
#   list NOR the cost of the options (FR-009: an Operator-blocked item lists its
#   unblock options and the cost of each). One FINDING per pending decision that
#   lacks an option list, a cost, or both:
#     FINDING known-open-decisions medium docs-drift <decision:doc:n> ... <doc:line>
#   Pending decisions are NOT findings by themselves; the count is printed to
#   stderr as `INFO pending decisions: <n>`.
#
# POPULATION (derived, never a hand list) — one typed token per PENDING decision,
#   `decision:<doc>:<n>` (n = line where the decision starts; a later decision
#   starting on the same line gets `.2`, `.3`; for the database n = atm_id). The
#   parser percent-encodes each token from the path's own bytes, so a newline or
#   an undecodable byte in a tracked path stays inside ONE token.
#   1. tracked docs/OPERATOR-DECISIONS-*.md and docs/constitution-adoption/
#      DECISION-*.md. Rule A: a table row whose last cell is exactly PENDING or
#      OPEN. Rule B: a prose paragraph matching (case-sensitive PENDING | "decision
#      pending" | "awaiting operator" | "needs your call" | "Operator-blocked")
#      unless it also matches the resolved rule.
#   2. CONTINUATION.md, section "## §3", only the entries whose heading carries
#      the newest ISO date found in §3 headings (the most recent entries).
#      Paragraphs are split at "; " outside parentheses; a segment is pending when
#      it matches PENDING_RE (decision pending, awaits a decision, awaiting the
#      operator, operator decision, needs your call, declined for now, not applied,
#      drafted not filed, should be rotated, nothing decided, off by design,
#      operator-blocked) and is not resolved (the word "resolved" in any case but
#      NOT "unresolved", or an upper-case DECIDED / DONE / ANSWERED / CLOSED / FIXED).
#   3. tracked specs/*/progress.yml list lines containing "decision pending",
#      "awaiting operator", "Operator-blocked" or "needs your call". NOT members
#      (controller ruling, class review rev-register I1 and the class-wave reconcile
#      list item 1): `minor (deferred)` lines — improvement-candidates owns them —
#      and `REQUIRED BEFORE` lines, which are review fixes the programme owes, not
#      operator decisions.
#   4. docs/workable_items.db items whose status is Operator-blocked, READ
#      THROUGH A COPY in $TMPDIR (the live file is never opened by sqlite; its
#      -wal file, when present, is copied with it so rows not yet checkpointed
#      are seen). A blocked item with no operator_block_details row, or whose
#      detail row (what + why + unblock_condition) states no option or no cost, is
#      a finding.
#   Corpus mode (--corpus <dir>) reads the same layout under <dir>; the database
#   comes from <dir>/docs/workable_items.sql, loaded into a scratch database, and
#   a database finding's evidence_ref is then docs/workable_items.sql (the path
#   that exists in the corpus; the location token keeps docs/workable_items.db).
#   "Options stated" = the decision text matches option|alternative|either|(a)|
#   choice (progress.yml lines also accept "Fix:"); "cost stated" = cost|
#   consequence|risk|trade-off (progress.yml also accepts "Cost if").
#   A source that is a symlink, FIFO, socket or device is COULD-NOT-INSPECT and is
#   never opened (O_NOFOLLOW + O_NONBLOCK, then a regular-file check).
#
# EXIT: 0 clean (full non-empty population inspected); 1 at least one FINDING;
#   2 could not determine (root/tool/source missing or not a regular file, empty
#   population, relative --root/--corpus). Every rc prints INSPECTED and
#   POPULATION-SHA (an early exit prints INSPECTED 0 and the empty-set sha).
#   Flags: --root <abs dir> [--corpus <abs dir>] [--emit-population]
#          --prove-failure (paired proof on throwaway copies, 20 cases; it also
#          checks every output line against the runner's canon/pathok/refok rules).
#
# MEASURED (live tree, 2026-09-26, after the rev-register fix round): rc 1, 13
#   pending decisions, 13 findings (was 26 before the fix round). All 13 were read
#   by hand: 10 are real pending operator decisions stated without options and
#   cost (one of them, CONTINUATION.md:565, restates the CONTINUATION.md:550
#   decision); 3 are false positives — CONTINUATION.md:597 (a decision the
#   operator already took, "not now"), CONTINUATION.md:616 (a design statement,
#   "off by design"), and a progress.yml review note that merely quotes the word
#   "Operator-blocked". Precision 10/13 = 0.77 (was 12/25 = 0.48).
#
# WHAT IT DOES NOT SEE
#   Decisions phrased without one of the recognition markers; decisions in files
#   outside the four sources (other docs, specs/*/tasks.md, carriers' prose);
#   CONTINUATION.md entries older than the newest date; remote state — the BEHIND
#   rows of verify-submodule-remote-sync.sh and UNVERIFIED rows of
#   verify-provider-ci.sh need network probes, and remote probing is owned by the
#   pointer-drift class (class-wave reconcile list item 1), so this class makes no
#   network call at all; whether a stated option list is a good one — only that
#   one is stated. A segment split at "; " can merge two decisions or split one.
#   A decision the operator already took but whose text still carries a marker
#   ("not applied", "off by design") is reported; the same decision restated in
#   two places is two findings (T038 must dedupe, and must also dedupe against
#   improvement-candidates, which reports every Operator-blocked item too).
set -uo pipefail
export LC_ALL=C PYTHONDONTWRITEBYTECODE=1

CLASS=known-open-decisions

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

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

# The parser: prints records "raw_token<TAB>evidence<TAB>missing<TAB>excerpt".
# missing in {none, options, cost, neither}. Exit 0 ok, 2 cannot determine
# (reason lines on stdout as "CNI<TAB>part<TAB>reason").
parse_py() {
python3 - "$@" <<'PY'
import os, re, sys, sqlite3, subprocess, tempfile, bisect, stat, shutil

root, corpus, tmpdir = sys.argv[1], sys.argv[2], sys.argv[3]
base = corpus or root
cni = []
recs = []

SAFE = frozenset(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-")

def pct(s):
    """the class contract's canonical percent-encoding, applied to the path's own bytes (a newline
    or an undecodable byte in a tracked path stays inside ONE token)"""
    b = os.fsencode(s)
    return "".join(chr(x) if x in SAFE else "%%%02X" % x for x in b)

def cn(part, reason):
    cni.append((part, reason))

def list_files():
    if corpus:
        out = []
        for d, dirs, fs in os.walk(corpus):
            # a symlinked or special entry is listed (and refused at read time), never followed
            for f in fs + [x for x in dirs if os.path.islink(os.path.join(d, x))]:
                out.append(os.path.relpath(os.path.join(d, f), corpus))
        return sorted(out)
    p = subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True)
    if p.returncode != 0:
        cn("git", "git ls-files failed at --root")
        return []
    fs = [os.fsdecode(x) for x in p.stdout.split(b"\0") if x]
    return sorted(f for f in fs if not f.startswith("_tests/fixtures/zero-gap/"))

def open_regular(rel, mode="r"):
    """open base/rel only when it is a regular file: a symlink, FIFO, socket or device is refused
    before any read (O_NOFOLLOW + O_NONBLOCK so neither a link nor a FIFO can be entered)"""
    fd = os.open(os.path.join(base, rel), os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise IsADirectoryError("not a regular file")
    except BaseException:
        os.close(fd); raise
    if mode == "rb":
        return os.fdopen(fd, "rb")
    return os.fdopen(fd, "r", encoding="utf-8")

OPT = re.compile(r"\boptions?\b|\balternatives?\b|\beither\b|\(a\)|\bchoices?\b", re.I)
COST = re.compile(r"\bcosts?\b|\bconsequences?\b|\brisks?\b|\btrade-?offs?\b", re.I)
OPT_Y = re.compile(OPT.pattern + r"|\bFix:", re.I)
COST_Y = re.compile(COST.pattern + r"|\bCost if\b", re.I)
RESOLVED = re.compile(r"(?<!un)\bresolved\b", re.I)
RESOLVED_UP = re.compile(r"\b(DECIDED|DONE|ANSWERED|CLOSED|FIXED)\b")
STRONG = re.compile(r"\bPENDING\b|decision pending|awaiting (the )?operator|needs your call|Operator-blocked")
PENDING = re.compile(
    r"decision pending|awaits? (a|the|an) (per-bump )?(operator )?decision|awaiting (the |a )?(per-bump )?operator|"
    r"operator decision|needs your call|declined for now|not applied|drafted, not filed|should be rotated|"
    r"nothing decided|off by design|operator-blocked", re.I)
# `minor (deferred)` and `REQUIRED BEFORE` lines are NOT operator decisions (controller ruling, class
# review rev-register I1): deferred minors belong to improvement-candidates, REQUIRED BEFORE lines are
# review fixes the programme itself owes.
PYML = re.compile(r"decision pending|awaiting operator|Operator-blocked|needs your call")

def excerpt(s):
    s = re.sub(r"\s+", " ", s)
    s = "".join(c if 32 <= ord(c) < 127 else "?" for c in s).replace('"', "'")
    return s[:60].strip()

def missing(text, opt=OPT, cost=COST):
    o, c = bool(opt.search(text)), bool(cost.search(text))
    return "none" if o and c else "cost" if o else "options" if c else "neither"

seen = {}
def add(doc, line, text, opt=OPT, cost=COST, evid=None):
    key = "%s:%d" % (doc, line)
    seen[key] = seen.get(key, 0) + 1
    tok = "decision:" + key + ("" if seen[key] == 1 else ".%d" % seen[key])
    recs.append((pct(tok), pct(evid or ("%s:%d" % (doc, line))), missing(text, opt, cost), excerpt(text)))

def read(rel):
    try:
        with open_regular(rel) as f:
            return f.read().split("\n")
    except (OSError, UnicodeDecodeError) as e:
        cn(rel, "unreadable: %s" % type(e).__name__)
        return None

def paragraphs(lines, lo=0, hi=None):
    """yield (start_line_1based, [(lineno, text)...]) paragraphs, skipping fences/tables/headings."""
    hi = len(lines) if hi is None else hi
    cur, fence = [], False
    for i in range(lo, hi):
        t = lines[i]
        if t.lstrip().startswith("```"):
            fence = not fence
            if cur: yield cur; cur = []
            continue
        if fence: continue
        brk = (not t.strip()) or t.startswith("#") or t.lstrip().startswith("|")
        newp = bool(re.match(r"\s*([-*]|\d+\.)\s", t))
        if brk or newp:
            if cur: yield cur; cur = []
        if brk: continue
        cur.append((i + 1, t))
    if cur: yield cur

def split_semis(text):
    """split at '; ' outside parentheses; return [(offset, segment)]"""
    out, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch == "(": depth += 1
        elif ch == ")": depth = max(0, depth - 1)
        elif ch == ";" and depth == 0 and text[i + 1:i + 2] == " ":
            out.append((start, text[start:i])); start = i + 2
    out.append((start, text[start:]))
    return out

def seg_line(par, offset):
    starts, pos = [], 0
    for ln, t in par:
        starts.append(pos); pos += len(t) + 1
    return par[bisect.bisect_right(starts, offset) - 1][0]

def resolved(t):
    return bool(RESOLVED.search(t) or RESOLVED_UP.search(t))

files = list_files()
fset = set(files)
n_docs = 0

# 1. decision documents
for rel in files:
    if not (re.fullmatch(r"docs/OPERATOR-DECISIONS-[^/]*\.md", rel) or re.fullmatch(r"docs/constitution-adoption/DECISION-[^/]*\.md", rel)):
        continue
    lines = read(rel)
    if lines is None: continue
    n_docs += 1
    fence = False
    for i, t in enumerate(lines):
        if t.lstrip().startswith("```"): fence = not fence; continue
        if fence or not t.lstrip().startswith("|"): continue
        cells = [c.strip().strip("*` ").strip() for c in t.strip().strip("|").split("|")]
        cells = [c for c in cells if c]
        if cells and cells[-1] in ("PENDING", "OPEN"):
            add(rel, i + 1, t)
    for par in paragraphs(lines):
        text = " ".join(x[1].strip() for x in par)
        if STRONG.search(text) and not resolved(text):
            add(rel, par[0][0], text)

# 2. CONTINUATION.md, newest-dated entries of section 3
if "CONTINUATION.md" in fset:
    lines = read("CONTINUATION.md")
    if lines is not None:
        n_docs += 1
        s3 = next((i for i, t in enumerate(lines) if re.match(r"## §3\b", t)), None)
        if s3 is None:
            cn("CONTINUATION.md", "no '## §3' section found")
        else:
            end = next((i for i in range(s3 + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
            heads = [i for i in range(s3 + 1, end) if lines[i].startswith("### ")]
            dated = []
            for k, h in enumerate(heads):
                m = re.search(r"20\d\d-\d\d-\d\d", lines[h])
                dated.append((m.group(0) if m else "", h, heads[k + 1] if k + 1 < len(heads) else end))
            newest = max((d[0] for d in dated), default="")
            if not newest:
                cn("CONTINUATION.md", "no dated '###' entry in section 3")
            for d, h, e in dated:
                if d != newest: continue
                for par in paragraphs(lines, h + 1, e):
                    text = " ".join(x[1].strip() for x in par)
                    # offsets must be computed on the joined text with the same 1-char separators
                    joined_par = [(ln, x.strip()) for ln, x in par]
                    for off, seg in split_semis(text):
                        if PENDING.search(seg) and not resolved(seg):
                            add("CONTINUATION.md", seg_line(joined_par, off), seg)
else:
    cn("CONTINUATION.md", "not present in the population source")

# 3. progress.yml files
for rel in files:
    if not re.fullmatch(r"specs/[^/]+/progress\.yml", rel): continue
    lines = read(rel)
    if lines is None: continue
    n_docs += 1
    for i, t in enumerate(lines):
        if t.lstrip().startswith("- ") and PYML.search(t):
            add(rel, i + 1, t, OPT_Y, COST_Y)

# 4. Operator-blocked items, through a copy
dbrel = "docs/workable_items.sql" if corpus else "docs/workable_items.db"
dbdoc = "docs/workable_items.db"
# evidence must name a real path under the inspected base: the corpus carries the .sql dump only
dbevid = dbrel
if dbrel not in fset:
    cn(dbrel, "database source not present")
else:
    work = tempfile.mkdtemp(prefix="zg-kod.", dir=tmpdir)
    try:
        scratch = os.path.join(work, "w.db")
        if corpus:
            con = sqlite3.connect(scratch)
            with open_regular(dbrel) as f:
                con.executescript(f.read())
        else:
            # copy the database AND its -wal (rows not yet checkpointed live only there); the live
            # files are only ever read, never opened by sqlite
            with open_regular(dbrel, "rb") as f, open(scratch, "wb") as g:
                shutil.copyfileobj(f, g)
            if os.path.lexists(os.path.join(base, dbrel + "-wal")):
                with open_regular(dbrel + "-wal", "rb") as f, open(scratch + "-wal", "wb") as g:
                    shutil.copyfileobj(f, g)
            con = sqlite3.connect(scratch)
        rows = con.execute("SELECT DISTINCT atm_id FROM items WHERE status = 'Operator-blocked' ORDER BY atm_id").fetchall()
        for (atm,) in rows:
            d = con.execute("SELECT what, why_exhausted_alternatives, unblock_condition FROM operator_block_details WHERE atm_id = ?", (atm,)).fetchone()
            tok = pct("decision:%s:%s" % (dbdoc, atm))
            if d is None:
                recs.append((tok, pct(dbevid), "neither", excerpt("Operator-blocked item %s has no operator_block_details row" % atm)))
            else:
                text = " ".join(d)
                recs.append((tok, pct(dbevid), missing(text), excerpt("Operator-blocked item %s unblock_condition: %s" % (atm, d[2]))))
        n_docs += 1
        con.close()
    except Exception as e:
        cn(dbrel, "database read failed: %s" % type(e).__name__)
    finally:
        shutil.rmtree(work, ignore_errors=True)

if n_docs == 0:
    cn("population", "none of the four population sources exists")
for part, reason in cni:
    print("CNI\t%s\t%s" % (pct(part), reason))
for r in sorted(set(recs)):
    print("REC\t" + "\t".join(r))
sys.exit(2 if cni else 0)
PY
}

# collect ROOT CORPUS -> sets RC (parser rc), fills $W/recs (raw) and $W/cni
collect() {
    local w=$1 rc
    parse_py "$ROOT" "$CORPUS" "$TMPDIR" >"$w/py.out" 2>"$w/py.err"; rc=$?
    grep -a '^CNI	' "$w/py.out" >"$w/cni" || true
    grep -a '^REC	' "$w/py.out" | cut -f2- >"$w/recs" || true
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
        printf 'CNI\tparser\tinternal failure rc=%s\n' "$rc" >>"$w/cni"; rc=2
    fi
    # tokens and evidence arrive already percent-encoded (the parser encodes the raw bytes, so a
    # newline inside a tracked path can never split a record)
    cut -f1 "$w/recs" >"$w/tok"; cut -f2 "$w/recs" >"$w/evd"
    return "$rc"
}

run_class() {
    local w rc
    [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] || { early tmpdir "TMPDIR-is-not-a-directory"; return 2; }
    w=$(mktemp -d "$TMPDIR/zg-kod-run.XXXXXX") || { early tmpdir mktemp-failed; return 2; }
    trap 'rm -rf "$w"' RETURN
    collect "$w"; rc=$?
    local sorted; sorted=$(LC_ALL=C sort -u "$w/tok")
    if [ "$EMIT" -eq 1 ]; then
        [ -n "$sorted" ] && printf '%s\n' "$sorted"
        if [ "$rc" -ne 0 ] || [ -z "$sorted" ]; then return 2; fi
        return 0
    fi
    local part reason found=0 n=0 miss tok evd exc
    while IFS=$'\t' read -r _ part reason; do
        [ -n "$part" ] || continue
        echo "COULD-NOT-INSPECT $part $(printf '%s' "$reason" | tr -c 'A-Za-z0-9 ._:=,()/-' '?' | tr ' ' '_')"
    done <"$w/cni"
    if [ -z "$sorted" ]; then echo "COULD-NOT-INSPECT population zero-pending-decisions-found"; rc=2; fi
    n=$(printf '%s\n' "$sorted" | awk 'NF' | wc -l | tr -d ' ')
    local i=0 total; total=$(wc -l <"$w/recs" | tr -d ' ')
    while [ "$i" -lt "$total" ]; do
        i=$((i + 1))
        tok=$(sed -n "${i}p" "$w/tok"); evd=$(sed -n "${i}p" "$w/evd")
        miss=$(sed -n "${i}p" "$w/recs" | cut -f3); exc=$(sed -n "${i}p" "$w/recs" | cut -f4)
        [ "$miss" = none ] && continue
        case "$miss" in
            neither) miss="states neither an option list nor a cost" ;;
            options) miss="states a cost but no option list" ;;
            cost)    miss="states an option list but no cost" ;;
        esac
        echo "FINDING $CLASS medium docs-drift $tok operator decision without options+cost: $miss ($exc) $evd"
        found=$((found + 1))
    done
    echo "INFO pending decisions: $n (findings: $found)" >&2
    echo "INSPECTED $n"
    echo "POPULATION-SHA $(printf '%s\n' "$sorted" | { if [ -n "$sorted" ]; then cat; fi; } | sha256sum | cut -d' ' -f1)"
    [ "$found" -gt 0 ] && return 1
    [ "$rc" -ne 0 ] && return 2
    return 0
}

prove_failure() (
    set -u
    HERE=$(cd "$(dirname "$SELF")/.." && pwd)
    T=$(mktemp -d "${TMPDIR:-/tmp}/zg-kod-proof.XXXXXX") || exit 2
    trap 'rm -rf "$T"' EXIT
    export TMPDIR=$T
    FIX=$HERE/_tests/fixtures/zero-gap/known-open-decisions
    pass=0 fail=0
    ok()  { echo "PASS $*"; pass=$((pass + 1)); }
    bad() { echo "FAIL $*"; fail=$((fail + 1)); }
    fp() { { git -C "$HERE" status --porcelain=v1 -z | sha256sum; ls -la --time-style=+%s "$HERE"/docs/workable_items.db* 2>/dev/null; ls -la --time-style=+%s "$HERE/CONTINUATION.md" 2>/dev/null; } | sha256sum; }
    # --- the runner's acceptance rules (scripts/zero-gap-sweep.sh canon/pathok/refok/parse_output), restated
    TOK='([A-Za-z0-9._~/+:@,=-]|%[0-9A-F]{2})+'
    NONCANON='%(2[B-F]|3[0-9AD]|4[0-9A-F]|5[0-9AF]|6[1-9A-F]|7[0-9AE])'
    canon() { [[ $1 =~ ^$TOK$ ]] && ! [[ $1 =~ $NONCANON ]]; }
    pathok() {
        local IFS=: seg
        case "$1" in ''|:*|*:|*::*) return 1 ;; esac
        for seg in $1; do case "$seg" in /*|./*|../*|*//*|*/./*|*/../*|*/.|*/..|.|..) return 1 ;; esac; done
        return 0
    }
    refok() { local c=$2 d; while :; do printf -v d '%b' "${c//%/\\x}"; [ -e "$1/$d" ] && return 0; case "$c" in *:*) c=${c%:*} ;; *) return 1 ;; esac; done; }
    # vout <base> <rc> <output>: 0 when every line would be accepted by the runner and rc agrees
    vout() {
        local base=$1 rc=$2 l ni=0 np=0 nf=0 nc=0 why=""
        local -a m
        local re_f="^FINDING $CLASS (critical|high|medium|low) (security|data-integrity|false-evidence|content-boundary|availability|build-freshness|governance-drift|docs-drift|test-coverage|ux-accessibility|host-capability|other) ($TOK) (.+) ($TOK)\$"
        local re_c="^COULD-NOT-INSPECT ($TOK) (.+)\$"
        while IFS= read -r l; do
            [ -n "$l" ] || continue
            case "$l" in *[[:cntrl:]]*) why+=" control-char"; continue ;; *'/home/'*) why+=" home-path" ;; esac
            if [[ $l =~ $re_f ]]; then
                m=("${BASH_REMATCH[@]}"); nf=$((nf + 1))
                canon "${m[3]}" && pathok "${m[3]}" || why+=" bad-location:${m[3]}"
                canon "${m[6]}" && pathok "${m[6]}" && refok "$base" "${m[6]}" || why+=" bad-evidence:${m[6]}"
            elif [[ $l =~ $re_c ]]; then
                m=("${BASH_REMATCH[@]}"); nc=$((nc + 1))
                canon "${m[1]}" && pathok "${m[1]}" || why+=" bad-part:${m[1]}"
            elif [[ $l =~ ^INSPECTED\ [0-9]+$ ]]; then ni=$((ni + 1))
            elif [[ $l =~ ^POPULATION-SHA\ [0-9a-f]{64}$ ]]; then np=$((np + 1))
            else why+=" unparsed-line"
            fi
        done <<<"$3"
        [ "$ni" -eq 1 ] && [ "$np" -eq 1 ] || why+=" inspected=$ni population-sha=$np"
        case "$rc" in
            0) [ "$nf" -eq 0 ] && [ "$nc" -eq 0 ] || why+=" rc0-with-lines" ;;
            1) [ "$nf" -gt 0 ] || why+=" rc1-without-finding" ;;
            2) [ "$nc" -gt 0 ] && [ "$nf" -eq 0 ] || why+=" rc2-disagrees" ;;
            *) why+=" rc=$rc" ;;
        esac
        VWHY=$why; [ -z "$why" ]
    }
    run() { OUT=$("$BASH" "$SELF" "$@" 2>/dev/null); RC=$?; }
    sha_line() { awk '$1 == "POPULATION-SHA" { print $2 }' <<<"$OUT"; }
    mkgit() { # <dir> <fixture part>: throwaway git work tree, .sql dump turned into the tracked .db
        cp -R "$FIX/$2" "$1" || return 1
        python3 -B -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[2]); c.executescript(open(sys.argv[1],encoding="utf-8").read()); c.commit(); c.close()' \
            "$1/docs/workable_items.sql" "$1/docs/workable_items.db" && rm -f "$1/docs/workable_items.sql" || return 1
        ( cd "$1" && git init -q . && git add -A && git -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -q -m fixture )
    }
    before=$(fp)
    [ -d "$FIX/planted" ] && [ -d "$FIX/clean" ] && [ -f "$FIX/expect.tsv" ] || { echo "FAIL corpus missing"; exit 2; }
    cp -R "$FIX/clean" "$T/c"; cp -R "$FIX/planted" "$T/p"

    run --root "$T" --corpus "$T/c"
    if [ "$RC" -eq 0 ] && ! grep -q '^FINDING' <<<"$OUT" && grep -q '^INSPECTED [1-9]' <<<"$OUT"; then ok "K1 control: clean corpus rc 0, non-empty population inspected (its deferred minor and REQUIRED BEFORE lines are not members)"; else bad "K1 control rc=$RC"; fi
    if vout "$T/c" "$RC" "$OUT"; then ok "K2 clean-corpus output accepted line by line by the runner rules"; else bad "K2 clean output rejected:$VWHY"; fi
    emitted=$("$BASH" "$SELF" --root "$T" --corpus "$T/c" --emit-population 2>/dev/null | sha256sum | cut -d' ' -f1)
    if [ "$(sha_line)" = "$emitted" ]; then ok "K3 POPULATION-SHA == sha256(--emit-population) on the clean corpus"; else bad "K3 walked $(sha_line) vs emitted $emitted"; fi

    run --root "$T" --corpus "$T/p"
    missed=0
    while IFS=$'\t' read -r loc _; do
        case "$loc" in ''|'#'*) continue ;; esac
        grep -qF "FINDING $CLASS medium docs-drift $loc " <<<"$OUT" || { missed=$((missed + 1)); echo "  missed planted $loc"; }
    done <"$FIX/expect.tsv"
    extra=$(grep -c '^FINDING' <<<"$OUT"); want=$(grep -vc '^#\|^$' "$FIX/expect.tsv")
    if [ "$RC" -eq 1 ] && [ "$missed" -eq 0 ] && [ "$extra" -eq "$want" ]; then ok "K4 planted corpus: rc 1, all $want planted decisions reported, none extra"; else bad "K4 planted rc=$RC missed=$missed findings=$extra want=$want"; fi
    if vout "$T/p" "$RC" "$OUT"; then ok "K5 planted-corpus output accepted by the runner rules (DB evidence names the corpus .sql)"; else bad "K5 planted output rejected:$VWHY"; fi
    if ! grep -q 'decision:specs/900-demo/progress.yml:[34] ' <<<"$OUT"; then ok "K6 progress.yml minor (deferred) and REQUIRED BEFORE lines are not decisions"; else bad "K6 deferred/REQUIRED BEFORE line reported"; fi

    printf '| 9 | Rotate the throwaway key | Rotate it later | PENDING |\n' >>"$T/c/docs/OPERATOR-DECISIONS-2099-01-01.md"
    run --root "$T" --corpus "$T/c"
    if [ "$RC" -eq 1 ] && grep -q '^FINDING known-open-decisions medium docs-drift decision:docs/OPERATOR-DECISIONS-2099-01-01.md:[0-9]* ' <<<"$OUT"; then ok "K7 planted defect on a throwaway copy: rc 1 with a finding"; else bad "K7 planted-defect rc=$RC"; fi

    mkdir "$T/empty"; run --root "$T" --corpus "$T/empty"
    if [ "$RC" -eq 2 ] && vout "$T/empty" "$RC" "$OUT"; then ok "K8 empty population: rc 2, INSPECTED and POPULATION-SHA still printed"; else bad "K8 empty rc=$RC:$VWHY"; fi
    mkdir -p "$T/res/docs"; cp "$FIX/clean/docs/workable_items.sql" "$T/res/docs/"; sed -i "/DEM-002/d" "$T/res/docs/workable_items.sql"
    printf '# Doc\n\n| # | x | y | Status |\n|---|---|---|---|\n| 1 | a | b | DECIDED |\n' >"$T/res/docs/OPERATOR-DECISIONS-2099-01-02.md"
    run --root "$T" --corpus "$T/res"
    if [ "$RC" -eq 2 ]; then ok "K9 all decisions resolved (zero pending) is rc 2, not clean"; else bad "K9 resolved-only rc=$RC"; fi
    if ! grep -q 'decision:docs/OPERATOR-DECISIONS-2099-01-01.md:6$' <<<"$("$BASH" "$SELF" --root "$T" --corpus "$T/c" --emit-population 2>/dev/null)"; then ok "K10 resolved/decided rows are not in the population"; else bad "K10 resolved row in population"; fi

    # a FIFO or a symlink in place of a source is refused, never opened (a FIFO open would block)
    cp -R "$FIX/clean" "$T/fifo"; rm "$T/fifo/specs/900-demo/progress.yml"; mkfifo "$T/fifo/specs/900-demo/progress.yml"
    OUT=$(timeout 30 "$BASH" "$SELF" --root "$T" --corpus "$T/fifo" 2>/dev/null); RC=$?
    if [ "$RC" -eq 2 ] && grep -q '^COULD-NOT-INSPECT specs/900-demo/progress.yml ' <<<"$OUT"; then ok "K11 a FIFO source is COULD-NOT-INSPECT (rc 2), not opened"; else bad "K11 fifo rc=$RC"; fi
    cp -R "$FIX/clean" "$T/sym"; rm "$T/sym/specs/900-demo/progress.yml"; ln -s ../../CONTINUATION.md "$T/sym/specs/900-demo/progress.yml"
    run --root "$T" --corpus "$T/sym"
    if [ "$RC" -eq 2 ] && grep -q '^COULD-NOT-INSPECT specs/900-demo/progress.yml ' <<<"$OUT"; then ok "K12 a symlinked source is COULD-NOT-INSPECT (rc 2), not followed"; else bad "K12 symlink rc=$RC"; fi

    # live mode on a throwaway git root: a tracked path with a newline stays ONE canonical token
    mkgit "$T/g" clean || bad "K13 fixture git root"
    nl=$'docs/OPERATOR-DECISIONS-2099-01-03\nx.md'
    printf '| # | a | b | Status |\n|---|---|---|---|\n| 1 | Rename the demo host | later | PENDING |\n' >"$T/g/$nl"
    ( cd "$T/g" && git add -A && git -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -q -m nl )
    run --root "$T/g"
    if [ "$RC" -eq 1 ] && grep -q '^FINDING known-open-decisions medium docs-drift decision:docs/OPERATOR-DECISIONS-2099-01-03%0Ax.md:3 ' <<<"$OUT" && vout "$T/g" "$RC" "$OUT"; then ok "K13 newline in a tracked path: one %0A token, every line accepted"; else bad "K13 newline rc=$RC:$VWHY"; fi
    emitted=$("$BASH" "$SELF" --root "$T/g" --emit-population 2>/dev/null | sha256sum | cut -d' ' -f1)
    if [ "$(sha_line)" = "$emitted" ]; then ok "K14 live mode POPULATION-SHA == sha256(--emit-population)"; else bad "K14 walked $(sha_line) vs emitted $emitted"; fi

    # a database whose newest rows sit in the -wal file: the copy must carry the -wal too
    mkgit "$T/w" clean || bad "K15 fixture git root"
    python3 -B -c '
import sqlite3, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
shutil.copyfile(dst, src)
con = sqlite3.connect(src)
con.execute("PRAGMA journal_mode=WAL"); con.execute("PRAGMA wal_autocheckpoint=0")
con.execute("INSERT INTO items VALUES (?, ?, ?, ?)", ("DEM-009", "Operator-blocked", "wal only", "only in the -wal file"))
con.commit()
shutil.copyfile(src, dst); shutil.copyfile(src + "-wal", dst + "-wal")
con.close()' "$T/wsrc.db" "$T/w/docs/workable_items.db"
    run --root "$T/w"
    if [ -s "$T/w/docs/workable_items.db-wal" ] && grep -q '^FINDING known-open-decisions medium docs-drift decision:docs/workable_items.db:DEM-009 ' <<<"$OUT"; then ok "K15 a row that lives only in docs/workable_items.db-wal is read (the -wal is copied with the .db)"; else bad "K15 wal rc=$RC"; fi

    mkdir "$T/nopy"; for b in bash git awk od sort sed cut tr grep sha256sum wc mktemp rm cat dirname basename; do p=$(command -v "$b") && ln -s "$p" "$T/nopy/$b"; done
    OUT=$(PATH=$T/nopy "$BASH" "$SELF" --root "$T" --corpus "$T/c" 2>/dev/null); RC=$?
    if [ "$RC" -eq 2 ] && ! grep -q '^FINDING' <<<"$OUT" && vout "$T" "$RC" "$OUT"; then ok "K16 python3 unavailable: rc 2, no clean claim, INSPECTED/POPULATION-SHA printed"; else bad "K16 no-python rc=$RC:$VWHY"; fi
    run --root /nonexistent
    if [ "$RC" -eq 2 ] && vout "$T" "$RC" "$OUT"; then ok "K17 --root /nonexistent: rc 2 with INSPECTED/POPULATION-SHA"; else bad "K17 nonexistent rc=$RC:$VWHY"; fi
    run --root relative/dir
    if [ "$RC" -eq 2 ] && vout "$T" "$RC" "$OUT"; then ok "K18 relative --root refused: rc 2"; else bad "K18 relative rc=$RC:$VWHY"; fi

    # the live tree: every line accepted, and nothing moved
    run --root "$HERE"
    if [ "$RC" -ne 2 ] && vout "$HERE" "$RC" "$OUT"; then ok "K19 live-tree output accepted by the runner rules (rc $RC)"; else bad "K19 live rc=$RC:$VWHY"; fi
    after=$(fp)
    if [ "$before" = "$after" ]; then ok "K20 live tree fingerprint unchanged (status, db and its -shm/-wal listing, CONTINUATION.md)"; else bad "K20 live tree changed"; fi
    echo "prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
)

# early <part> <reason>: an undetermined run before any population was walked. A normal run still
# prints INSPECTED 0 and the POPULATION-SHA of the empty set (every rc carries both lines); an
# --emit-population run prints nothing on stdout (its stdout is the population) and says why on stderr.
early() {
    if [ "$EMIT" -eq 1 ]; then echo "$CLASS: $1: $2" >&2; return 0; fi
    echo "COULD-NOT-INSPECT $1 $2"
    echo "INSPECTED 0"
    echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"
}

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) early arguments unknown-argument; exit 2 ;;
    esac
done
if [ "$PROVE" -eq 1 ] && [ -z "$ROOT" ]; then
    prove_failure; exit $?
fi
case "$ROOT" in /*) ;; *) early root --root-must-be-an-absolute-directory; exit 2 ;; esac
[ -d "$ROOT" ] || { early root --root-is-not-a-directory; exit 2; }
case "$CORPUS" in ''|/*) ;; *) early corpus --corpus-must-be-an-absolute-directory; exit 2 ;; esac
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then early corpus --corpus-is-not-a-directory; exit 2; fi
command -v python3 >/dev/null 2>&1 || { early python3 tool-missing; exit 2; }
command -v git >/dev/null 2>&1 || { early git tool-missing; exit 2; }
run_class
exit $?
