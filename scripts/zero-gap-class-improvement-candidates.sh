#!/usr/bin/env bash
# zero-gap-class-improvement-candidates.sh - sweep class `improvement-candidates` (feature 010, T081).
#
# WHAT IT DETECTS
#   Improvement candidates for capabilities that already exist (spec FR-001 / FR-025): a
#   limitation, a deferred minor or a blocked/queued shortcoming recorded in the umbrella's own
#   public sources. One FINDING per candidate, severity low|medium, category other:
#     improvement candidate: <one line>; measurable target: <derived | MISSING>
#   A candidate with no measurable target is STILL a finding, flagged `measurable target: MISSING`
#   (V-G4 refuses to close it until a target is written). The class never invents a target and
#   never adds a register item or edits a document (the controller seeds the register at T038).
#
# POPULATION (docs/zero-gap/sweep-classes.tsv row `improvement-candidates`, kind `source`)
#   Typed tokens, item-level wherever the row names items (class review rev-register I2, controller
#   ruling: item-level tokens, the vocabulary filter is the DECISION RULE, not a population filter):
#     - `candidate:<doc>` for every TRACKED docs/OPERATOR-DECISIONS-*.md and every TRACKED
#       docs/**/KNOWN-LIMITATIONS*.md (the row names the documents; an empty glob is not a failure
#       while the other sources are non-empty)
#     - `candidate:specs/010-zero-gap-verified-closure/progress.yml:<line>` for every list line that
#       STARTS with `minor (deferred)` (a line that only mentions the phrase mid-line is not a member)
#     - `candidate:docs/workable_items.db:<atm_id>` for EVERY Operator-blocked and EVERY Queued item
#       (read through a COPY in $TMPDIR, with its -wal when present; the live file is never opened)
#   So a new Queued item or deferred line moves INSPECTED and POPULATION-SHA. Tokens are encoded from
#   the raw path bytes inside the walker (a newline in a tracked path stays one token). A finding
#   location is `candidate:<doc>:<line>` (an item of a document) or the item token itself.
#
# CANDIDATE RULES (the decision rule: which population member is a FINDING)
#   - Markdown source: a list item or table row (not a heading, not a table header row, not a
#     separator, not a line inside a fenced block, not free prose). In a KNOWN-LIMITATIONS* file every
#     such record is a candidate; in OPERATOR-DECISIONS-*.md it is a candidate when it matches the
#     limitation vocabulary (limitation, deferred, improv*, shortcoming, residual, still/remains open,
#     not yet, unmeasured, unverified, unproven, cannot be closed, not closed, follow-up, known gap,
#     workaround, weakness, debt).
#   - progress.yml: every member (every `minor (deferred)` line) is a candidate.
#   - database: every Operator-blocked item; a Queued item when its title, description or block detail
#     matches the limitation vocabulary. A Queued item without it is a member that is not a finding.
#   Severity: medium for an Operator-blocked item and for an OPERATOR-DECISIONS line, else low.
#
# MEASURABLE TARGET (derived only from the source's own text, never invented; class review I1)
#   A TARGET is only: a comparator + number (>=, <=, at most, at least, no more than, fewer/less than,
#   under, below, within), a `target:` / `goal:` / `objective:` phrase up to its first figure, or an
#   improvement verb (reduce, drop, bring, cut, improve, lower, raise, increase, shrink, speed up)
#   followed by `to <figure>` / `to zero`. The earliest-starting target in the text wins, whichever
#   rule found it. Any OTHER figure (a number with a unit, `N of M`, `rc N`, `exit N`, `zero`) usually
#   states today's state, so it is shown as `measurable target: MISSING; figure in source (not a
#   target): <figure>` and the register is seeded with the target MISSING (V-G4 then refuses closure
#   until a target is written). The recogniser still cannot tell a comparator that describes a check
#   that already exists from one that states this improvement's goal.
#
# DEDUPE RULE
#   Candidates are normalised (lower case, every run of non-alphanumerics is one space, a leading
#   `T<digits>[ N<digits>]:` label removed) and keyed on the first 200 characters. The first record
#   in source-token order (byte order) then file order wins; later ones are merged into it and the
#   winner's description says `(also stated in N other place(s))`. T038 must also dedupe against
#   known-open-decisions, which reports every Operator-blocked item that lacks options or a cost.
#
# EXIT CODES: 0 the full non-empty population was read and holds no candidate; 1 at least one
#   FINDING (a finding outranks an undetermined); 2 could not determine (absent, unreadable,
#   symlinked or FIFO named source — never opened: O_NOFOLLOW + O_NONBLOCK + regular-file check —, an
#   empty population, a missing tool, a relative or missing --root/--corpus). Every rc prints INSPECTED
#   and POPULATION-SHA (an early exit prints INSPECTED 0 and the empty-set sha).
#
# MEASURED (live tree, 2026-09-26, after the rev-register fix round): rc 1, INSPECTED 216
#   = 3 tracked OPERATOR-DECISIONS documents + 10 deferred lines + 203 Queued items; 0 items are
#   Operator-blocked and no KNOWN-LIMITATIONS document is tracked; 30 findings (2 medium, 28 low); 18
#   of the 203 Queued items pass the vocabulary rule. Targets: 1 of 30 findings derives a target
#   (`≥20`, a floor of an existing check, NOT the item's goal: 0 of 1
#   derived targets is real); 29 are MISSING, 15 of them with a labelled state figure. Ten findings
#   read by hand: 7 are real improvement candidates for existing capabilities (the deferred minors, a
#   PARTIAL task, a blocked provider check), 3 are not (a DECIDED operator row that carries the word
#   "unverified", a list intro line "not yet decided", a new-feature task); the target field was
#   correct under the rule above for 9 of the 10.
#
# WHAT IT DOES NOT SEE
#   Private submodule documents (never read); operator decisions recorded only in chat or in a
#   carrier; candidates phrased without the vocabulary above (the manual `gap add --kind improvement`
#   intake path covers those); continuation lines of a wrapped list item; whether a derived target is
#   a real objective. Queued items that state no limitation are members but not candidates. A table
#   whose header row is not followed by a separator line is read as data rows.
#
# Usage: --root <abs dir> [--corpus <abs dir>] [--emit-population] | --prove-failure
# The corpus mode reads the same layout under <corpus>; there docs/workable_items.sql (a text dump) is
# loaded into a scratch database when docs/workable_items.db is absent (corpus-only affordance), and a
# database finding's evidence_ref is then docs/workable_items.sql (the path that exists in the corpus).
set -uo pipefail

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

CLASS=improvement-candidates
SELF=$(readlink -f "${BASH_SOURCE[0]}")
export PYTHONDONTWRITEBYTECODE=1
TMPBASE=${TMPDIR:-/tmp}

ROOT="" CORPUS="" EMIT=0 PROVE=0
# early <reason>: an undetermined run before any population was walked. A normal run still prints
# INSPECTED 0 and the POPULATION-SHA of the empty set (every rc carries both lines); an
# --emit-population run prints nothing on stdout (its stdout IS the population) and says why on stderr.
early() {
    if [ "$EMIT" -eq 1 ]; then echo "$CLASS: $1" >&2; return 0; fi
    echo "COULD-NOT-INSPECT - $1"
    echo "INSPECTED 0"
    echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"
}
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --corpus) CORPUS="${2:-}"; shift 2 ;;
        --emit-population) EMIT=1; shift ;;
        --prove-failure) PROVE=1; shift ;;
        *) early "unknown argument"; exit 2 ;;
    esac
done

# ---- the Python walker: enumerates the population itself (tokens encoded from the raw bytes), and in
# run mode reads every item and prints POP / FINDING / COULD-NOT-INSPECT lines and #STATS
walker_py() {
cat <<'PYEOF'
import os, re, sqlite3, sys, unicodedata, shutil, stat, subprocess

base, corpus_mode, work, mode = sys.argv[1], sys.argv[2] == "1", sys.argv[3], sys.argv[4]
PROG = "specs/010-zero-gap-verified-closure/progress.yml"
DB = "docs/workable_items.db"
SQL = "docs/workable_items.sql"
SAFE = frozenset(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-")

def pct(b):
    return "".join(chr(x) if x in SAFE else "%%%02X" % x for x in b)

def encp(path):   # a path: its own bytes (a newline or an undecodable byte stays in ONE token)
    return pct(os.fsencode(path))

def enct(text):   # a text id (an ATM id)
    return pct(text.encode("utf-8", "surrogateescape"))

def clean(t):
    t = "".join(" " if unicodedata.category(c) in ("Cc", "Cf", "Cs", "Co", "Cn", "Zl", "Zp") else c for c in t)
    return re.sub(r"\s+", " ", t).strip()

def clip(t, n=160):
    return t if len(t) <= n else t[: n - 3].rstrip() + "..."

LIMIT_RE = re.compile(
    r"\b(limitations?|deferred|defer|improv\w*|shortcomings?|residual|remains? open|still open|not yet|"
    r"unmeasured|unverified|unproven|cannot be closed|not closed|follow-?up|known gap|workarounds?|weakness\w*|debt)\b", re.I)
UNITS = (r"(?:%|percent\b|ms\b|milliseconds?\b|seconds?\b|secs?\b|minutes?\b|mins?\b|hours?\b|days?\b|files?\b|rows?\b|"
         r"items?\b|tests?\b|cases?\b|commits?\b|gates?\b|findings?\b|matches\b|occurrences?\b|lines?\b|claims?\b|"
         r"passed\b|failed\b|MB\b|GB\b|KB\b)")
NUM = r"(?<![\w.#-])\d[\d,]*(?:\.\d+)?"
# any figure: reported, never as a target, when no target rule matches
FIGURE_RES = [
    re.compile(NUM + r"\s?" + UNITS, re.I),
    re.compile(r"(?<![\w.#-])\d+ of \d+\b", re.I),
    re.compile(r"\b(?:rc|exit(?:s|ed)?(?: code)?)\s*[=:]?\s*\d+\b", re.I),
    re.compile(r"\bzero\b", re.I),
]
# a measurable TARGET: only a comparator, a target/goal phrase, or an improvement verb followed by
# `to <figure>`. Group `t`, when present, is the phrase shown; the earliest-starting match wins.
CMP = r"(?:>=|<=|≥|≤|\bat most\b|\bat least\b|\bno more than\b|\bfewer than\b|\bless than\b|\bunder\b|\bbelow\b|\bwithin\b)"
FIG = NUM + r"(?:\s?" + UNITS + r")?"
TARGET_RES = [
    re.compile(CMP + r"\s*" + FIG, re.I),
    re.compile(r"\b(?:targets?|goals?|objectives?)\b\s*(?::|=|\bis\b|\bof\b)\s*(?P<t>[^;.\n]{0,40}?" + FIG + r")", re.I),
    re.compile(r"\b(?:reduc\w*|drop\w*|bring\w*|cut\w*|improv\w*|lower\w*|rais\w*|increas\w*|shrink\w*|speed\w* up)\b"
               r"[^;.\n]{0,40}?\bto\s+(?P<t>(?:" + CMP + r"\s*)?" + FIG + r"|zero\b)", re.I),
]

def earliest(res, blob):
    best = None
    for rx in res:
        m = rx.search(blob)
        if m and (best is None or m.start() < best.start()):
            best = m
    return best

def target(blob):
    m = earliest(TARGET_RES, blob)
    if m:
        return clip(clean(m.groupdict().get("t") or m.group(0)), 60)
    f = earliest(FIGURE_RES, blob)
    if f:
        return "MISSING; figure in source (not a target): " + clip(clean(f.group(0)), 60)
    return "MISSING"

def norm(t):
    t = re.sub(r"^T\d+(?: N\d+)?:\s*", "", t.strip())
    return re.sub(r"[^a-z0-9]+", " ", t.lower()).strip()[:200]

out, pop = [], []
inspected = 0
cands = []  # (source token, record order) order

def cni(part, why):
    out.append("COULD-NOT-INSPECT %s %s" % (part, clean(why)))

def open_regular(rel):
    """open base/rel only when it is a regular file: a symlink, FIFO, socket or device is refused
    before any read (O_NOFOLLOW + O_NONBLOCK, then a regular-file check)"""
    fd = os.open(os.path.join(base, rel), os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise OSError("not a regular file")
    except BaseException:
        os.close(fd); raise
    return os.fdopen(fd, "rb")

def read_text(rel):
    with open_regular(rel) as fh:
        return fh.read().decode("utf-8")

def why(e):
    return "source unreadable: %s" % type(e).__name__ + (" (%s)" % e.strerror if isinstance(e, OSError) and e.strerror else (" (%s)" % e if isinstance(e, OSError) else ""))

def add(srctok, n, text, blob, sev, evref):
    cands.append({"src": srctok, "tok": srctok + ":" + n, "text": clean(text), "blob": clean(blob), "sev": sev, "ev": evref})

# ---- enumerate the documents (file-level population items)
DOCRE = re.compile(r"docs/(OPERATOR-DECISIONS-[^/]*\.md|(?:.*/)?KNOWN-LIMITATIONS[^/]*\.md)", re.S)
docs = []
if corpus_mode:
    for d, dirs, fs in os.walk(base):
        for f in fs + [x for x in dirs if os.path.islink(os.path.join(d, x))]:
            rel = os.path.relpath(os.path.join(d, f), base)
            if DOCRE.fullmatch(rel):
                docs.append(rel)
else:
    p = subprocess.run(["git", "-C", base, "ls-files", "-z", "--", ":(glob)docs/OPERATOR-DECISIONS-*.md",
                        ":(glob)docs/**/KNOWN-LIMITATIONS*.md"], capture_output=True)
    if p.returncode != 0:
        cni("-", "git ls-files failed at --root")
    docs = [os.fsdecode(x) for x in p.stdout.split(b"\0") if x]
docs = sorted(set(x for x in docs if not x.startswith("_tests/fixtures/zero-gap/")), key=os.fsencode)

# ---- enumerate progress.yml `minor (deferred)` lines (item-level)
PROGRE = re.compile(r"""^\s*-\s*["']?minor \(deferred\)\s*(.*?)["']?\s*$""")
progtok = "candidate:" + encp(PROG)
prog_items = []
try:
    for i, line in enumerate(read_text(PROG).split("\n"), 1):
        m = PROGRE.match(line)
        if m:
            prog_items.append((i, m.group(1)))
except (OSError, UnicodeDecodeError) as e:
    cni(progtok, why(e))

# ---- enumerate Operator-blocked and Queued items of the database (item-level), read through a COPY
dbtok = "candidate:" + encp(DB)
db_items = []
db_evid = encp(DB)
try:
    scratch = os.path.join(work, "wi-copy.db")
    if os.path.lexists(os.path.join(base, DB)) or not corpus_mode:
        with open_regular(DB) as f, open(scratch, "wb") as g:
            shutil.copyfileobj(f, g)
        if os.path.lexists(os.path.join(base, DB + "-wal")):
            with open_regular(DB + "-wal") as f, open(scratch + "-wal", "wb") as g:
                shutil.copyfileobj(f, g)
    else:
        db_evid = encp(SQL)   # the corpus carries a text dump; evidence must name a path that exists there
        c0 = sqlite3.connect(scratch)
        c0.executescript(read_text(SQL))
        c0.commit(); c0.close()
    con = sqlite3.connect(scratch)
    try:
        names = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
        if "items" not in names:
            raise OSError("the database has no items table")
        join = "operator_block_details" in names
        q = ("select i.atm_id, i.status, i.title, i.description, %s from items i %s "
             "where i.status in ('Queued','Operator-blocked') order by i.atm_id, i.status") % (
            "coalesce(o.what,''), coalesce(o.unblock_condition,'')" if join else "'', ''",
            "left join operator_block_details o on o.atm_id = i.atm_id" if join else "")
        byid = {}
        for atm, status, title, desc, what, unb in con.execute(q):
            e = byid.setdefault(str(atm), {"blocked": False, "title": str(title), "blob": []})
            e["blocked"] = e["blocked"] or status == "Operator-blocked"
            e["blob"].append(" ".join(str(x) for x in (title, desc, what, unb) if x))
        for atm in sorted(byid):
            db_items.append((atm, byid[atm]))
    finally:
        con.close()
except (OSError, UnicodeDecodeError, sqlite3.Error) as e:
    cni(dbtok, why(e))

doctoks = [("candidate:" + encp(d), d) for d in docs]
pop = [t for t, _ in doctoks] + ["%s:%d" % (progtok, i) for i, _ in prog_items] + ["%s:%s" % (dbtok, enct(a)) for a, _ in db_items]

if mode == "run":
    SEPRE = re.compile(r"\|[\s:|-]+\|?")
    LISTRE = re.compile(r"([-*+]|\d+[.)])\s+\S")
    LISTSTRIP = re.compile(r"^([-*+]|\d+[.)])\s+")
    sources = []   # (source token, reader) in source-token byte order: this order decides dedupe winners
    def read_doc(tok, src):
        text = read_text(src)
        is_kl = os.path.basename(src).startswith("KNOWN-LIMITATIONS")
        sev = "low" if is_kl else "medium"
        lines = text.split("\n")
        fence = False
        for i, line in enumerate(lines, 1):
            s = line.strip()
            if s.startswith("```") or s.startswith("~~~"):
                fence = not fence
                continue
            if fence:
                continue
            table = s.startswith("|") and not SEPRE.fullmatch(s)
            lst = LISTRE.match(s) is not None
            if not (table or lst):
                continue
            if table:
                nxt = lines[i].strip() if i < len(lines) else ""
                if SEPRE.fullmatch(nxt):
                    continue  # header row of a table
                body = " / ".join(c.strip() for c in s.strip("|").split("|") if c.strip())
            else:
                body = LISTSTRIP.sub("", s)
            if is_kl or LIMIT_RE.search(body):
                add(tok, str(i), body, body, sev, "%s:%d" % (encp(src), i))
    for tok, src in doctoks:
        sources.append((tok, lambda tok=tok, src=src: read_doc(tok, src)))
    def read_prog():
        for i, text in prog_items:
            add(progtok, str(i), text, text, "low", "%s:%d" % (encp(PROG), i))
    def read_db():
        for atm, e in db_items:
            blob = " ".join(e["blob"])
            if e["blocked"] or LIMIT_RE.search(blob):
                add(dbtok, enct(atm), e["title"], blob, "medium" if e["blocked"] else "low", db_evid)
    sources.append((progtok, read_prog))
    sources.append((dbtok, read_db))
    for tok, reader in sorted(sources, key=lambda x: x[0]):
        try:
            reader()
        except (OSError, UnicodeDecodeError) as e:
            cni(tok, why(e))
            continue
        inspected += len(prog_items) if tok == progtok else len(db_items) if tok == dbtok else 1
    seen, order = {}, []
    for c in cands:
        k = norm(c["text"])
        if k in seen:
            seen[k]["dups"] += 1
            continue
        c["dups"] = 0
        seen[k] = c
        order.append(c)
    for c in order:
        dup = ""
        if c["dups"]:
            dup = " (also stated in %d other place%s)" % (c["dups"], "" if c["dups"] == 1 else "s")
        desc = "improvement candidate: %s%s; measurable target: %s" % (clip(c["text"]), dup, target(c["blob"]))
        out.append("FINDING improvement-candidates %s other %s %s %s" % (c["sev"], c["tok"], desc, c["ev"]))

w = sys.stdout.buffer.write
for t in pop:
    w(("POP %s\n" % t).encode("ascii"))
for l in out:
    w((l + "\n").encode("utf-8"))
w(("#STATS %d\n" % inspected).encode("ascii"))
PYEOF
}

run_class() { # emits the class output for --root/--corpus on stdout, returns the class rc
    local base mode tokens W walkout findings=0 cni=0 insp prc
    case "$ROOT" in /*) ;; *) early "--root must be an absolute directory"; return 2 ;; esac
    if [ ! -d "$ROOT" ]; then early "--root is not a directory"; return 2; fi
    case "$CORPUS" in ''|/*) ;; *) early "--corpus must be an absolute directory"; return 2 ;; esac
    if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then early "--corpus is not a directory"; return 2; fi
    for t in python3 git sha256sum awk sort mktemp cut grep; do
        command -v "$t" >/dev/null 2>&1 || { early "required tool missing: $t"; return 2; }
    done
    if [ -n "$CORPUS" ]; then base=$CORPUS mode=corpus
    else
        base=$ROOT mode=live
        git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { early "--root is not a git work tree"; return 2; }
    fi
    W=$(mktemp -d "$TMPBASE/zg-impr.XXXXXX") || { early "cannot create a scratch directory"; return 2; }
    walker_py >"$W/walk.py"
    walkout=$W/out
    prc=0
    python3 -B "$W/walk.py" "$base" "$([ "$mode" = corpus ] && echo 1 || echo 0)" "$W" "$([ "$EMIT" -eq 1 ] && echo emit || echo run)" >"$walkout" 2>"$W/err" || prc=$?
    if [ "$prc" -ne 0 ] || ! LC_ALL=C grep -q '^#STATS ' "$walkout"; then
        rm -rf "$W"; early "the walker failed (rc $prc)"; return 2
    fi
    tokens=$(LC_ALL=C awk '$1 == "POP" { print $2 }' "$walkout" | LC_ALL=C sort -u)
    cni=$(LC_ALL=C grep -c '^COULD-NOT-INSPECT ' "$walkout")
    if [ "$EMIT" -eq 1 ]; then
        [ -n "$tokens" ] && printf '%s\n' "$tokens"
        LC_ALL=C grep '^COULD-NOT-INSPECT ' "$walkout" >&2
        rm -rf "$W"
        if [ "$cni" -gt 0 ] || [ -z "$tokens" ]; then return 2; fi
        return 0
    fi
    insp=$(LC_ALL=C awk '$1 == "#STATS" { n = $2 } END { print n + 0 }' "$walkout")
    LC_ALL=C grep -E '^(FINDING|COULD-NOT-INSPECT) ' "$walkout"
    findings=$(LC_ALL=C grep -c '^FINDING ' "$walkout")
    if [ -z "$tokens" ]; then
        echo "COULD-NOT-INSPECT - the population is empty (no decisions or limitations document, no deferred line, no Queued or Operator-blocked item): an empty population is never clean"; cni=$((cni + 1))
    fi
    echo "INSPECTED $insp"
    echo "POPULATION-SHA $({ if [ -n "$tokens" ]; then printf '%s\n' "$tokens"; fi; } | sha256sum | cut -d' ' -f1)"
    rm -rf "$W"
    if [ "$findings" -gt 0 ]; then return 1; fi
    if [ "$cni" -gt 0 ]; then return 2; fi
    return 0
}

if [ "$PROVE" -eq 0 ]; then run_class; exit $?; fi

prove_failure() {
    local FIX pass=0 fail=0 out rc bin before walked emitted HERE livebefore
    HERE=$(cd "$(dirname "$SELF")/.." && pwd)
    FIX=$HERE/_tests/fixtures/zero-gap/$CLASS
    T=$(mktemp -d "$TMPBASE/zg-impr-proof.XXXXXX") || { echo "COULD-NOT-INSPECT - no scratch directory"; return 2; }
    trap 'rm -rf "$T"' EXIT
    export TMPDIR=$T
    ok() { pass=$((pass + 1)); echo "  PASS $1"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
    fp() { ( cd "$1" && find . -type f -not -path './.git/*' -printf '%p %s %T@\n' | LC_ALL=C sort; find . -type f -not -path './.git/*' -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum ) | sha256sum | cut -d' ' -f1; }
    livefp() { { git -C "$HERE" status --porcelain=v1 -z | sha256sum; ls -la --time-style=+%s "$HERE"/docs/workable_items.db* 2>/dev/null; } | sha256sum; }
    gcommit() { ( cd "$1" && git add -A && git -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -q -m "$2" ); }
    mkroot() { # <dir> <fixture dir>: throwaway git work tree with the .sql dump turned into the .db
        mkdir -p "$1" && cp -R "$2/." "$1/" || return 1
        if [ -f "$1/docs/workable_items.sql" ]; then
            python3 -B -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[2]); c.executescript(open(sys.argv[1],encoding="utf-8").read()); c.commit(); c.close()' \
                "$1/docs/workable_items.sql" "$1/docs/workable_items.db" && rm -f "$1/docs/workable_items.sql"
        fi
        ( cd "$1" && git init -q . ) && gcommit "$1" fixture
    }
    # --- the runner's acceptance rules (scripts/zero-gap-sweep.sh canon/pathok/refok/parse_output), restated
    local TOK='([A-Za-z0-9._~/+:@,=-]|%[0-9A-F]{2})+'
    local NONCANON='%(2[B-F]|3[0-9AD]|4[0-9A-F]|5[0-9AF]|6[1-9A-F]|7[0-9AE])'
    canon() { [[ $1 =~ ^$TOK$ ]] && ! [[ $1 =~ $NONCANON ]]; }
    pathok() {
        local IFS=: seg
        case "$1" in ''|:*|*:|*::*) return 1 ;; esac
        for seg in $1; do case "$seg" in /*|./*|../*|*//*|*/./*|*/../*|*/.|*/..|.|..) return 1 ;; esac; done
        return 0
    }
    refok() { local c=$2 d; while :; do printf -v d '%b' "${c//%/\\x}"; [ -e "$1/$d" ] && return 0; case "$c" in *:*) c=${c%:*} ;; *) return 1 ;; esac; done; }
    vout() { # <base>: 0 when every line of $out would be accepted by the runner and $rc agrees
        local base=$1 l ni=0 np=0 nf=0 nc=0 why=""
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
        done <<<"$out"
        [ "$ni" -eq 1 ] && [ "$np" -eq 1 ] || why+=" inspected=$ni population-sha=$np"
        case "$rc" in
            0) [ "$nf" -eq 0 ] && [ "$nc" -eq 0 ] || why+=" rc0-with-lines" ;;
            1) [ "$nf" -gt 0 ] || why+=" rc1-without-finding" ;;
            2) [ "$nc" -gt 0 ] && [ "$nf" -eq 0 ] || why+=" rc2-disagrees" ;;
            *) why+=" rc=$rc" ;;
        esac
        VWHY=$why; [ -z "$why" ]
    }
    runc() { out=$("$BASH" "$SELF" "$@" 2>/dev/null); rc=$?; }
    locs() { printf '%s\n' "$out" | LC_ALL=C awk '$1 == "FINDING" { print $5 }' | LC_ALL=C sort; }
    want() { LC_ALL=C grep -v '^#' "$FIX/expect.tsv" | cut -f1 | LC_ALL=C sort; }
    psha() { printf '%s\n' "$out" | LC_ALL=C awk '$1 == "POPULATION-SHA" { print $2 }'; }
    d() { printf '%s\n' "$out" | LC_ALL=C awk -v l="candidate:$1" '$1 == "FINDING" && $5 == l'; }
    echo "prove-failure: $CLASS"
    if [ ! -f "$FIX/expect.tsv" ] || [ ! -d "$FIX/planted" ] || [ ! -d "$FIX/clean" ]; then echo "COULD-NOT-INSPECT - corpus missing at $FIX"; return 2; fi
    livebefore=$(livefp)

    mkroot "$T/clean" "$FIX/clean"; mkroot "$T/planted" "$FIX/planted"
    echo "C0 control: the clean root is read in full and yields no finding"
    runc --root "$T/clean"
    if [ "$rc" -eq 0 ] && grep -q '^INSPECTED 2$' <<<"$out" && ! grep -q '^FINDING' <<<"$out"; then ok "C0 rc 0, INSPECTED 2 (the decisions doc and the Queued item SYN-003)"; else bad "C0 rc=$rc $(grep INSPECTED <<<"$out")"; fi
    if vout "$T/clean"; then ok "C0b every line accepted by the runner rules"; else bad "C0b rejected:$VWHY"; fi

    echo "C1 planted defects: every planted candidate is reported, and only those"
    before=$(fp "$T/planted"); runc --root "$T/planted"
    if [ "$rc" -eq 1 ] && [ "$(locs)" = "$(want)" ]; then ok "C1 rc 1, $(locs | wc -l) locations equal expect.tsv"; else bad "C1 rc=$rc got: $(locs | tr '\n' ' ')"; fi
    if vout "$T/planted"; then ok "C1a live-mode output accepted by the runner rules"; else bad "C1a rejected:$VWHY"; fi
    if [ "$(fp "$T/planted")" = "$before" ]; then ok "C1b throwaway root byte-identical (database copy only)"; else bad "C1b the root changed"; fi

    echo "C2 corpus mode reads the corpus and matches the same locations; every line passes the runner's refok"
    runc --root "$T/clean" --corpus "$FIX/planted"
    if [ "$rc" -eq 1 ] && [ "$(locs)" = "$(want)" ]; then ok "C2 planted corpus"; else bad "C2 rc=$rc"; fi
    if vout "$FIX/planted"; then ok "C2a planted-corpus output accepted (database evidence names the corpus .sql)"; else bad "C2a rejected:$VWHY"; fi
    runc --root "$T/clean" --corpus "$FIX/clean"
    if [ "$rc" -eq 0 ] && vout "$FIX/clean"; then ok "C2b clean corpus rc 0, accepted"; else bad "C2b rc=$rc:$VWHY"; fi

    echo "C3 measurable target: a comparator / target phrase / improve-to figure only; other figures are labelled, target MISSING"
    runc --root "$T/planted"
    if d docs/OPERATOR-DECISIONS-2026-01-01.md:7 | grep -q 'measurable target: under 30 seconds [^ ]*$'; then ok "C3a comparator target 'under 30 seconds' beats the earlier state figure"; else bad "C3a $(d docs/OPERATOR-DECISIONS-2026-01-01.md:7 | grep -o 'measurable target:.*')"; fi
    if d docs/OPERATOR-DECISIONS-2026-01-01.md:8 | grep -q 'measurable target: MISSING [^ ]*$'; then ok "C3b no figure => MISSING"; else bad "C3b"; fi
    if d docs/OPERATOR-DECISIONS-2026-01-01.md:12 | grep -q 'measurable target: MISSING; figure in source (not a target): 40% [^ ]*$'; then ok "C3c a state percentage is labelled, target MISSING"; else bad "C3c $(d docs/OPERATOR-DECISIONS-2026-01-01.md:12 | grep -o 'measurable target:.*')"; fi
    if d specs/010-zero-gap-verified-closure/progress.yml:2 | grep -q 'measurable target: MISSING; figure in source (not a target): rc 0 [^ ]*$'; then ok "C3d rc 0 behaviour is labelled, target MISSING"; else bad "C3d"; fi
    if d docs/workable_items.db:SYN-002 | grep -q 'measurable target: MISSING; figure in source (not a target): 800 ms [^ ]*$'; then ok "C3e database state figure labelled, target MISSING"; else bad "C3e"; fi
    if d docs/workable_items.db:SYN-001 | grep -q 'measurable target: MISSING [^ ]*$'; then ok "C3f blocked item without figure => MISSING"; else bad "C3f"; fi
    if d docs/sub/KNOWN-LIMITATIONS-synthetic.md:5 | grep -q 'measurable target: MISSING [^ ]*$'; then ok "C3g plain KNOWN-LIMITATIONS bullet => MISSING"; else bad "C3g"; fi
    if d docs/sub/KNOWN-LIMITATIONS-synthetic.md:6 | grep -q 'measurable target: p95 under 200 ms [^ ]*$'; then ok "C3h 'target:' phrase derived"; else bad "C3h $(d docs/sub/KNOWN-LIMITATIONS-synthetic.md:6 | grep -o 'measurable target:.*')"; fi
    if d docs/OPERATOR-DECISIONS-2026-01-01.md:19 | grep -q 'measurable target: 5 minutes [^ ]*$'; then ok "C3i a later target rule matching earlier in the text wins (earliest target, not first rule)"; else bad "C3i $(d docs/OPERATOR-DECISIONS-2026-01-01.md:19 | grep -o 'measurable target:.*')"; fi

    echo "C4 dedupe: the same text on two sources is one finding at the first source"
    if d docs/OPERATOR-DECISIONS-2026-01-01.md:18 | grep -q 'also stated in 1 other place'; then ok "C4a winner records the merge"; else bad "C4a"; fi
    if [ -z "$(d specs/010-zero-gap-verified-closure/progress.yml:4)" ]; then ok "C4b the duplicate location is not reported"; else bad "C4b"; fi

    echo "C5 non-candidates stay silent (prose, fence, separator, header row with 'limitation', mid-line mention, plain queued, completed)"
    if [ "$(locs | wc -l)" -eq 12 ]; then ok "C5 exactly 12 findings"; else bad "C5 count $(locs | wc -l)"; fi
    if [ -z "$(d docs/OPERATOR-DECISIONS-2026-01-01.md:21)" ]; then ok "C5b a table header row carrying 'limitation' is not a candidate"; else bad "C5b header row reported"; fi

    echo "C6 an empty population is rc 2, never clean"
    mkroot "$T/empty" "$FIX/clean"
    ( cd "$T/empty" && git rm -q docs/OPERATOR-DECISIONS-2026-01-01.md && printf 'x: 1\n' >specs/010-zero-gap-verified-closure/progress.yml \
        && python3 -B -c 'import sqlite3; c=sqlite3.connect("docs/workable_items.db"); c.execute("delete from items"); c.commit()' ) && gcommit "$T/empty" empty
    runc --root "$T/empty"
    if [ "$rc" -eq 2 ] && grep -q 'empty' <<<"$out" && ! grep -q '^FINDING' <<<"$out" && vout "$T/empty"; then ok "C6 rc 2, empty population named, INSPECTED/POPULATION-SHA printed"; else bad "C6 rc=$rc:$VWHY"; fi

    echo "C7 an empty glob is not a failure while the other sources are non-empty"
    mkroot "$T/noglob" "$FIX/clean"
    ( cd "$T/noglob" && git rm -q docs/OPERATOR-DECISIONS-2026-01-01.md ) && gcommit "$T/noglob" noglob
    runc --root "$T/noglob"
    if [ "$rc" -eq 0 ] && grep -q '^INSPECTED 1$' <<<"$out"; then ok "C7 rc 0 with the glob empty"; else bad "C7 rc=$rc"; fi

    echo "C8 an absent named source is COULD-NOT-INSPECT; a finding outranks it"
    mkroot "$T/nodb" "$FIX/clean"
    ( cd "$T/nodb" && git rm -q -f docs/workable_items.db ) && gcommit "$T/nodb" nodb
    runc --root "$T/nodb"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT candidate:docs/workable_items.db ' <<<"$out" && vout "$T/nodb"; then ok "C8a absent database rc 2"; else bad "C8a rc=$rc:$VWHY"; fi
    mkroot "$T/nodb2" "$FIX/planted"
    ( cd "$T/nodb2" && git rm -q -f docs/workable_items.db ) && gcommit "$T/nodb2" nodb
    runc --root "$T/nodb2"
    if [ "$rc" -eq 1 ] && grep -q '^COULD-NOT-INSPECT candidate:docs/workable_items.db ' <<<"$out" && grep -q '^FINDING' <<<"$out"; then ok "C8b finding outranks the undetermined"; else bad "C8b rc=$rc"; fi
    mkroot "$T/noprog" "$FIX/clean"
    ( cd "$T/noprog" && git rm -q -f specs/010-zero-gap-verified-closure/progress.yml ) && gcommit "$T/noprog" noprog
    runc --root "$T/noprog"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT candidate:specs/010-zero-gap-verified-closure/progress.yml ' <<<"$out"; then ok "C8c absent progress.yml rc 2"; else bad "C8c rc=$rc"; fi

    echo "C9 an unreadable (non-UTF-8, symlinked or FIFO) source is COULD-NOT-INSPECT, never opened"
    mkroot "$T/badutf" "$FIX/clean"
    printf -- '- limitation \377 byte\n' >"$T/badutf/docs/OPERATOR-DECISIONS-2026-01-01.md"; gcommit "$T/badutf" bad
    runc --root "$T/badutf"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT candidate:docs/OPERATOR-DECISIONS-2026-01-01.md ' <<<"$out"; then ok "C9a non-UTF-8 rc 2"; else bad "C9a rc=$rc"; fi
    cp -R "$FIX/clean" "$T/csym"; rm "$T/csym/docs/OPERATOR-DECISIONS-2026-01-01.md"; ln -s ../specs/010-zero-gap-verified-closure/progress.yml "$T/csym/docs/OPERATOR-DECISIONS-2026-01-01.md"
    runc --root "$T/clean" --corpus "$T/csym"
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT candidate:docs/OPERATOR-DECISIONS-2026-01-01.md ' <<<"$out"; then ok "C9b a symlinked decisions doc in a corpus is COULD-NOT-INSPECT, not skipped"; else bad "C9b rc=$rc"; fi
    cp -R "$FIX/clean" "$T/cfifo"; rm "$T/cfifo/specs/010-zero-gap-verified-closure/progress.yml"; mkfifo "$T/cfifo/specs/010-zero-gap-verified-closure/progress.yml"
    out=$(timeout 30 "$BASH" "$SELF" --root "$T/clean" --corpus "$T/cfifo" 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT candidate:specs/010-zero-gap-verified-closure/progress.yml ' <<<"$out"; then ok "C9c a FIFO progress.yml is COULD-NOT-INSPECT (no hang)"; else bad "C9c rc=$rc"; fi

    echo "C10 a missing tool is rc 2, and a bad --root is rc 2; every early exit still prints INSPECTED/POPULATION-SHA"
    bin=$T/bin; mkdir -p "$bin"
    for t in cat git od awk sort sha256sum find sed mktemp dirname readlink cut grep tr head tail rm mkdir cp wc xargs env; do
        [ -e "$(command -v "$t")" ] && ln -sf "$(command -v "$t")" "$bin/$t"
    done
    out=$(PATH="$bin" "$BASH" "$SELF" --root "$T/clean" 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'required tool missing: python3' <<<"$out" && vout "$T"; then ok "C10a no python3 => rc 2"; else bad "C10a rc=$rc:$VWHY"; fi
    runc --root /nonexistent
    if [ "$rc" -eq 2 ] && vout "$T"; then ok "C10b --root /nonexistent => rc 2"; else bad "C10b rc=$rc:$VWHY"; fi
    runc --root relative/dir
    if [ "$rc" -eq 2 ] && grep -q 'absolute' <<<"$out" && vout "$T"; then ok "C10c a relative --root is refused (rc 2)"; else bad "C10c rc=$rc:$VWHY"; fi

    echo "C11 the emitted population equals the walked population, item by item"
    runc --root "$T/planted"; walked=$(psha)
    emitted=$("$BASH" "$SELF" --root "$T/planted" --emit-population 2>/dev/null | sha256sum | cut -d' ' -f1)
    if [ -n "$walked" ] && [ "$walked" = "$emitted" ]; then ok "C11 POPULATION-SHA == sha256(--emit-population)"; else bad "C11 $walked vs $emitted"; fi
    if "$BASH" "$SELF" --root "$T/planted" --emit-population 2>/dev/null | grep -qx 'candidate:docs/workable_items.db:SYN-003' \
        && "$BASH" "$SELF" --root "$T/planted" --emit-population 2>/dev/null | grep -qx 'candidate:specs/010-zero-gap-verified-closure/progress.yml:4'; then
        ok "C11b every Queued item and every deferred line is its own population item"; else bad "C11b item-level tokens missing"; fi
    python3 -B -c 'import sqlite3; c=sqlite3.connect("'"$T"'/planted/docs/workable_items.db"); c.execute("insert into items values (?,?,?,?)", ("SYN-005","Queued","a new plain request","nothing more")); c.commit()'
    runc --root "$T/planted"
    if [ "$(psha)" != "$walked" ] && grep -q '^INSPECTED 9$' <<<"$out"; then ok "C11c a new Queued item moves POPULATION-SHA and INSPECTED (8 -> 9)"; else bad "C11c sha unchanged or $(grep INSPECTED <<<"$out")"; fi

    echo "C12 live mode: a newline in a tracked path stays one token; the live tree output is accepted and unchanged"
    mkroot "$T/nl" "$FIX/clean"
    mkdir -p "$T/nl/docs/x"; printf -- '- a limitation with a newline path\n' >"$T/nl/docs/x/KNOWN-LIMITATIONS-a"$'\n'"b.md"; gcommit "$T/nl" nl
    runc --root "$T/nl"
    if [ "$rc" -eq 1 ] && grep -q '^FINDING improvement-candidates low other candidate:docs/x/KNOWN-LIMITATIONS-a%0Ab.md:1 ' <<<"$out" && vout "$T/nl"; then ok "C12a %0A token, every line accepted"; else bad "C12a rc=$rc:$VWHY"; fi
    runc --root "$HERE"
    if [ "$rc" -ne 2 ] && vout "$HERE"; then ok "C12b live-tree output accepted by the runner rules (rc $rc)"; else bad "C12b live rc=$rc:$VWHY"; fi
    if [ "$(livefp)" = "$livebefore" ]; then ok "C12c live tree unchanged (git status, database files listing)"; else bad "C12c live tree changed"; fi

    echo "C13 a database whose newest rows sit only in the -wal file: the copy carries the -wal"
    mkroot "$T/wal" "$FIX/clean"
    python3 -B -c '
import sqlite3, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
shutil.copyfile(dst, src)
con = sqlite3.connect(src)
con.execute("PRAGMA journal_mode=WAL"); con.execute("PRAGMA wal_autocheckpoint=0")
con.execute("INSERT INTO items VALUES (?, ?, ?, ?)", ("SYN-009", "Operator-blocked", "wal only blocked item", "only in the -wal file"))
con.commit()
shutil.copyfile(src, dst); shutil.copyfile(src + "-wal", dst + "-wal")
con.close()' "$T/walsrc.db" "$T/wal/docs/workable_items.db"
    runc --root "$T/wal"
    if [ -s "$T/wal/docs/workable_items.db-wal" ] && [ -n "$(d docs/workable_items.db:SYN-009)" ]; then ok "C13 a row that lives only in docs/workable_items.db-wal is read"; else bad "C13 rc=$rc"; fi

    echo "prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ] && return 0
    return 1
}
case "$PROVE" in
1)
prove_failure
exit $?
;;
esac
