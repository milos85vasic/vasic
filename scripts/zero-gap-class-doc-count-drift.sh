#!/usr/bin/env bash
# zero-gap-class-doc-count-drift.sh — sweep class `doc-count-drift` (feature 010, task T031).
#
# WHAT IT DETECTS
#   Documented COUNTS that no longer match the MEASURED count of their subject: a tracked
#   Markdown document says "N <unit>" about files / gates / scripts / lines / anchors /
#   submodules / specs, and re-measuring that subject today gives a different number.
#   Example (the known seed, verified 2026-09-25): an owned module's carrier records
#   23 `verify-*.sh` / 27 `prove-*.sh` / 20 `*.sh` while its tree holds 101 / 94 / 47.
#
# POPULATION (row `doc-count-drift` of docs/zero-gap/sweep-classes.tsv) AND WHY
#   Every numeric count claim found by SCANNING the tracked Markdown of the umbrella and of
#   every checked-out OWNED module, MINUS the claims already re-measured by a row of
#   docs/claim-ledger.tsv (class `stale-figures` owns those; subtracting them avoids double
#   registration). Deriving the set from the documents — not from the claims that already
#   have a re-measure command — is the point: that set is exactly the one least likely to
#   drift.
#     Documents (BOUNDARY RULING, progress.yml reconcile 6 / review fix (a)):
#       umbrella: docs/**/*.md and specs/**/*.md ONLY — the umbrella's CLAUDE.md, AGENTS.md,
#         QWEN.md, GEMINI.md, README.md and CONTINUATION.md belong to class stale-figures;
#       each owned module M: M/README.md, M/CLAUDE.md, M/AGENTS.md, M/QWEN.md, M/GEMINI.md,
#         M/docs/**/*.md, M/specs/**/*.md;
#       tracked files only (`git -C M ls-files`), never under _tests/fixtures/zero-gap/.
#     Owned modules: derived exactly like verify-governance-cascade.sh C1 — a `.gitmodules`
#       submodule whose URL namespace (host/owner) hosts >= 2 declared submodules or is the
#       namespace of a helix-deps.yaml `ssh_url`, EXCLUDING the governance source (the
#       submodule that carries scripts/gates/lib/pointer_carrier.sh). Third-party and
#       governance-source documents are not ours to correct and are not scanned.
#     A claim: `<number>[**] <unit>` where the number is not part of a version, date, path,
#       section or approximation (`~150`), across at most ONE line break (a paragraph break
#       ends a claim), with
#         unit ∈ files, tests, test files, gates, verify scripts, prove scripts, scripts,
#                commits, items, rows, checks, services, submodules, anchors, lines, specs
#                (optionally `tracked <unit>`, optionally with a backticked token between);
#       or `<number> `<glob>` <word>` where the backticked token is a wildcard glob (the glob
#       IS the subject, so any trailing word counts: "27 `prove-*.sh` proofs");
#       or the pair `<n> verify / <m> prove`. PASS/FAIL splits are NOT implemented.
#     POPULATION ITEMS: `<doc path>:<line>` per document line carrying at least one such claim
#       that is not ledger-backed, and `figures:<doc path>` per document carrying one (the home
#       of that document's LOW aggregate) — umbrella-relative, percent-encoded.
#     Ledger-backed: the claim's number lies inside a match (capture group 1 when present)
#       of a `claim` row's anchor (Python re, MULTILINE) on that row's surface.
#
# POINT-IN-TIME DOCUMENTS (review fix (c)): docs/zero-gap/point-in-time.tsv (tracked DATA, one
#   `path<TAB>reason` row per document, exact path or fnmatch pattern) lists documents whose
#   counts were true when written (session reports, dated audits, superseded specs). Their claims
#   are population items but are never reported. A row with no reason, or matching no scanned
#   document, is COULD-NOT-INSPECT `docs/zero-gap/point-in-time.tsv:<n>` — no exemption lives in
#   this code.
#
# THE NOUN -> MEASURE TABLE (a claim is re-measured ONLY by one of these; each states how it
# counts; "tracked" = `git ls-files` of the repository holding the path; in --corpus mode
# "tracked" = present on disk under the corpus)
#   glob      `N `<dir>/<pat>` word` or `N `<pat>` word` with <dir> = the NEAREST preceding
#             backticked `<dir>/` token of the same paragraph (only that one; it must resolve
#             to a tracked directory of the document's module, else of the umbrella):
#             count of tracked DIRECT entries of <dir> matching <pat> (fnmatch; `ls dir/pat`).
#   files     `N [tracked] files (in|under|inside|below) `<dir>``: tracked files under <dir>,
#             recursively.
#   lines     "`<file>` (N lines" / "`<file>` is|has|holds N lines" / "`<file>`: N lines" /
#             "N lines (in|of) `<file>`": newline count of that tracked file (`wc -l`).
#   anchors   the same line names a tracked `.../Constitution.md` in backticks: count of lines
#             starting `### §` (`grep -c '^### §'`).
#   submodules  the same line names `.gitmodules`: `path` entries of the document module's
#             .gitmodules (`git config -f .gitmodules --get-regexp '\.path$' | wc -l`).
#   specs     the same line names `specs/`: directories `specs/NNN-*` of the document's module
#             that hold at least one tracked file.
#   verify scripts / prove scripts / `n verify / m prove`: with the nearest preceding
#             backticked `<dir>/` of the paragraph (as for glob): tracked direct entries
#             `verify-*.sh` / `prove-*.sh` of <dir>.
#   Every other claim (tests, gates, checks, rows, items, commits, services, test files,
#   scripts without a glob, any unit without a resolvable subject) is UNMEASURABLE.
#
# OUTPUT (docs/zero-gap/README.md class contract)
#   FINDING doc-count-drift medium docs-drift <doc:line> recorded N <unit>, measured M by: <how>
#       [; also in <doc:line> ...]; claim-key=<12 hex> <doc:line>
#       (severity high when the document is a MODULE-root governance carrier CLAUDE.md /
#       AGENTS.md / QWEN.md / GEMINI.md). claim-key is the sha256 (12 hex) of the whitespace-
#       normalised claim line: a content-anchored secondary key that survives a line shift
#       (review fix (e), for cross-cycle dedupe).
#   LOCKSTEP (review fix (b)): the four root carriers of one module carry the same text; the
#       same claim on an identical line is ONE finding at the first carrier in the order
#       CLAUDE, AGENTS, QWEN, GEMINI with an `also in` list; a carrier line that drifted from
#       its siblings is reported on its own.
#   FINDING doc-count-drift low docs-drift figures:<doc> N unmeasurable recorded count(s) on
#       line(s) <first 30 lines>[ (+K more)]: ... <doc:first line>   (review fix (d): ONE
#       aggregate per document instead of one finding per unmeasurable claim)
#   COULD-NOT-INSPECT <part> <reason>   (an owned module not checked out, an unreadable
#       document, a document or measured subject that is a symlink / FIFO / device / outside
#       the tree — never opened —, an anchor that does not compile, a missing tool, a defective
#       point-in-time row, an empty population)
#   INSPECTED <n>   POPULATION-SHA <sha256>   (printed on EVERY live rc, including rc 2;
#       a failed --emit-population prints nothing on stdout and its reason on stderr)
#   Private modules (workshop, ai_interviewing, monetization) are read for COUNTS ONLY: an
#   output line carries paths, numbers, globs, a 12-hex digest and this script's own words —
#   never document text.
#
# MEASURED ON THE LIVE TREE (2026-09-26, after the review fix round)
#   rc 1 in 4 s: 3 high (the KNOWN SEED: workshop carriers 23 verify / 27 prove / 20 *.sh,
#   each with its 3 lockstep copies in `also in`), 9 medium, 221 LOW aggregates (from 1484
#   per-claim lows); INSPECTED 1518. Before: 16 high / 27 medium / 1484 low. Hand-read of the
#   12 drift findings: 7 are counts stale today; 5 are dated measurements inside task notes of
#   the live specs/008-unified-workshop-platform/tasks.md (true when written, not listable as
#   a whole document). Hand-read of 10 aggregates (every 22nd): all 10 first lines are count
#   claims. Cost: a 240 KB one-line paragraph of glob claims 0.24 s (55.9 s before), 1 MB 0.65 s.
#
# EXIT CODES: 0 every item inspected, no finding; 1 at least one FINDING (outranks 2);
#   2 could not determine (absent --root, missing python3/git, an empty population, an owned
#   module not checked out, an unreadable/linked/special document or subject, a defective
#   point-in-time row) — 2 is never a pass.
#
# WHAT IT DOES NOT SEE (stated, not implied)
#   - A claim on a line that marks itself historical (WITHDRAWN, SUPERSEDED, withdrawn,
#     superseded, HISTORICAL, historical, or ~~strikethrough~~) is inspected and never
#     reported: it does not assert the count today. A stale figure on such a line is invisible.
#     The same holds for every claim of a document listed in docs/zero-gap/point-in-time.tsv.
#   - A past-tense narrative figure on an unmarked line of a live document ("measured
#     2026-09-02: 17 verify") is read as a present claim; its measure (if any) is today's count.
#   - Units outside the list, spelled-out numbers ("three submodules"), counts separated
#     from their unit by other words ("12 owned submodules"), approximations (~N), counts in
#     documents outside the listed paths (nested README.md files, the umbrella carriers,
#     CONTINUATION.md, *.txt), PASS/FAIL splits.
#   - A subject whose scope is not stated right beside the count is not guessed: the claim is
#     counted in its document's LOW aggregate as unmeasurable, never as drift. So a genuinely
#     stale "18 gates" without a glob and a directory is recorded as unmeasurable, not as stale.
#   - "tracked" counts ignore untracked files on disk (a doc counting `ls dir/*.sh` on a tree
#     with untracked scripts can differ from this measure by exactly those files).
#   - Ledger-backed claims are left to `stale-figures` entirely, including when the ledger
#     anchor is too loose and backs more than it should.
#   - Third-party and governance-source modules; owned modules nested inside owned modules.
#   - Two claims of one aggregate are not told apart by location: the aggregate's line list is
#     the evidence (a new unmeasurable claim in a document that already has one changes only
#     the count and the list).
#
# USAGE
#   zero-gap-class-doc-count-drift.sh --root <dir> [--corpus <dir>] [--emit-population]
#   zero-gap-class-doc-count-drift.sh --prove-failure
#       paired proof on THROWAWAY git repositories built from the corpus: control => 0;
#       planted => every expect.tsv location and nothing else (rc 1); single mutations each
#       flip one location; removing the ledger / the historical marker / the third-party
#       status exposes the skipped claim; empty population, absent root, missing python3 and
#       an owned module not checked out => 2; the live tree is byte-identical around a live run.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1 LC_ALL=C

ID=doc-count-drift
SELF_DIR=$(cd "$(dirname "$0")" && pwd)

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

EMPTY_SHA=$(printf '' | sha256sum | cut -d' ' -f1)

# scan <emit|run> <root> <corpus-or-empty> <workdir>: the Python scanner. Writes, NUL-separated
# where a field may carry a path: items.z (raw population items), find.loc.z + find.rest
# (raw finding locations; "severity<TAB>category<TAB>description" lines in the same order),
# cni.part.z + cni.why. Encoding, sorting and the output grammar stay in bash (the helper above).
scan() {
    python3 - "$@" <<'PY'
import bisect, fnmatch, hashlib, os, posixpath, re, stat, subprocess, sys

mode, root, corpus, W = sys.argv[1:5]
base = corpus if corpus else root
live = not corpus
FIXPFX = '_tests/fixtures/zero-gap/'
CARRIERS = ('CLAUDE.md', 'AGENTS.md', 'QWEN.md', 'GEMINI.md')
ROOTDOCS = CARRIERS + ('README.md',)
items, finds, cnis = set(), [], []

def cni(part, why): cnis.append((part, why))
def dec(b): return os.fsdecode(b)
def git(args, cwd):
    p = subprocess.run(['git', '-C', cwd] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    return p.returncode, p.stdout
def join(m, p): return p if not m else (m if not p else m + '/' + p)
_rbase = os.path.realpath(base)
def unsafe(rel):
    """None when <base>/<rel> is a regular file (not a symlink) whose real path stays inside the
    scanned tree; else the reason. Nothing is opened: a FIFO would block, /dev/zero would exhaust
    memory (host-memory 12.6), a link leaving the tree would expose outside text."""
    a = os.path.join(base, rel)
    try: st = os.lstat(a)
    except OSError: return 'absent on disk'
    if stat.S_ISLNK(st.st_mode): return 'a symbolic link (never followed): not read'
    if not stat.S_ISREG(st.st_mode): return 'not a regular file (FIFO, device or socket): never opened'
    rp = os.path.realpath(a)
    if not (rp == _rbase or rp.startswith(_rbase.rstrip('/') + '/')): return 'resolves outside the scanned tree (a linked directory): not read'
    return None

# ---- modules (derived like verify-governance-cascade.sh C1) ---------------------------------
def gitmodules(dirabs):
    f = os.path.join(dirabs, '.gitmodules')
    if not os.path.lexists(f): return None
    why = unsafe(os.path.relpath(f, base))
    if why:
        cni(os.path.relpath(f, base), why + ': the modules it declares are not read'); return None
    rc, o = git(['config', '-f', f, '-z', '--get-regexp', r'^submodule\..*\.(path|url)$'], dirabs)
    if rc not in (0, 1): raise SystemExit('git config -f .gitmodules failed')
    d = {}
    for rec in o.split(b'\0'):
        if not rec: continue
        k, _, v = rec.partition(b'\n'); k, v = dec(k), dec(v)
        name, _, attr = k[len('submodule.'):].rpartition('.')
        d.setdefault(name, {})[attr] = v
    return [(e['path'].strip('/'), e.get('url', '')) for _, e in sorted(d.items()) if e.get('path', '').strip('/')]

def namespace(u):
    u = u.strip()
    m = re.match(r'^[\w.-]+@([\w.-]+):/?([^/]+)/', u) or re.match(r'^(?:ssh|https?|git)://(?:[^@/]+@)?([^/:]+)(?::\d+)?/([^/]+)/', u)
    return (m.group(1) + '/' + m.group(2)).lower() if m else None

decl = gitmodules(base) or []
nscount = {}
for p, u in decl:
    n = namespace(u)
    if n: nscount[n] = nscount.get(n, 0) + 1
owned_ns = {n for n, c in nscount.items() if c >= 2}
hd = os.path.join(base, 'helix-deps.yaml')
if os.path.isfile(hd):
    with open(hd, 'rb') as fh:
        for m in re.finditer(r'^\s*-?\s*ssh_url:\s*["\']?([^"\'\s#]+)', dec(fh.read()), re.M):
            n = namespace(m.group(1))
            if n: owned_ns.add(n)
gov = {p for p, _ in decl if os.path.isfile(os.path.join(base, p, 'scripts/gates/lib/pointer_carrier.sh'))}

def checked_out(p):
    a = os.path.join(base, p)
    if not os.path.isdir(a): return False
    if not live: return True
    rc, o = git(['rev-parse', '--show-toplevel'], a)
    return rc == 0 and os.path.realpath(dec(o.strip())) == os.path.realpath(a)

present = sorted({p for p, _ in decl if checked_out(p)}, key=len, reverse=True)
owned = []
for p, u in decl:
    if p in gov or namespace(u) not in owned_ns: continue
    if p in present: owned.append(p)
    else: cni('gitlink:' + p, 'owned module declared in .gitmodules is not checked out; its documents could not be read')
owned = sorted(set(owned))

# ---- "tracked" listings ---------------------------------------------------------------------
_list, _set, _under = {}, {}, {}
def listing(repo):
    if repo in _list: return _list[repo]
    a = os.path.join(base, repo) if repo else base
    out = []
    if live:
        rc, o = git(['ls-files', '-z'], a)
        if rc != 0: raise SystemExit('git ls-files failed in ' + (repo or '.'))
        out = [dec(x) for x in o.split(b'\0') if x]
    else:
        skip = {p for p in present if repo == ''}
        for dp, dns, fns in os.walk(a):
            rel = os.path.relpath(dp, a).replace(os.sep, '/')
            rel = '' if rel == '.' else rel
            dns[:] = sorted(d for d in dns if join(rel, d) not in skip)
            out.extend(join(rel, f) for f in fns)
    out.sort(); _list[repo] = out; _set[repo] = set(out)
    return out
def repo_of(path):
    for p in present:
        if path == p or path.startswith(p + '/'): return p
    return ''
def rel_in(repo, path): return path if not repo else path[len(repo) + 1:]
def files_under(d):
    if d in _under: return _under[d]
    repo = repo_of(d); r = rel_in(repo, d); L = listing(repo)
    res = list(L) if r == '' else [f[len(r) + 1:] for f in L if f.startswith(r + '/')]
    _under[d] = res
    return res
def is_file(path):
    # tracked (or present, in --corpus mode) and present on disk; whether it is SAFE to read is
    # decided by unsafe() at the point of reading, so a linked/special subject is reported
    repo = repo_of(path); r = rel_in(repo, path)
    listing(repo)
    return r in _set[repo] and os.path.lexists(os.path.join(base, path))
def clean_rel(t):
    t = t.strip()
    if not t or t.startswith('/') or re.search(r'[\s*?\[\]]', t): return None
    n = posixpath.normpath(t)
    if n in ('.', '') or n.startswith('..'): return None
    return n
def cands(t, m):
    # a single-segment name is resolved in the document's own module only; the umbrella is
    # consulted only for a multi-segment path (a bare `scripts/` or `.gitmodules` in a module
    # document never silently means the umbrella's)
    return list(dict.fromkeys([join(m, t), t] if '/' in t else [join(m, t)]))
def resolve_dir(t, m):
    t = clean_rel(t)
    if t is None: return None
    for c in cands(t, m):
        if files_under(c): return c
    return None
def resolve_file(t, m, need_dir_part=False):
    t = clean_rel(t)
    if t is None or (need_dir_part and '/' not in t): return None
    for c in cands(t, m):
        if is_file(c): return c
    return None
def read_text(path):
    with open(os.path.join(base, path), 'rb') as fh:
        return fh.read().decode('utf-8', 'surrogateescape')

# ---- documents --------------------------------------------------------------------------------
def is_doc(f, m):
    # BOUNDARY RULING (progress.yml reconcile 6 / (a)): the UMBRELLA's root carriers, README.md and
    # CONTINUATION.md belong to class stale-figures; an owned MODULE's root carriers and README are
    # scanned here, and docs/** and specs/** everywhere.
    if f.endswith('.md') and (f.startswith('docs/') or f.startswith('specs/')): return True
    return bool(m) and f in ROOTDOCS
docs = []
for m in [''] + owned:
    for f in listing(m):
        if is_doc(f, m):
            d = join(m, f)
            if live and d.startswith(FIXPFX): continue
            docs.append((d, m))

# ---- point-in-time exemptions (docs/zero-gap/point-in-time.tsv; tracked DATA with a reason per row) --
PIT = 'docs/zero-gap/point-in-time.tsv'
pit = []
if os.path.lexists(os.path.join(base, PIT)):
    why = unsafe(PIT)
    if why:
        cni(PIT, why + ': no point-in-time exemption is applied')
    else:
        for n, ln in enumerate(read_text(PIT).split('\n'), 1):
            if not ln.strip() or ln.startswith('#'): continue
            f = ln.split('\t')
            if len(f) >= 2 and f[0] == 'path' and f[1].strip() == 'reason': continue
            if len(f) < 2 or not f[0].strip() or not f[1].strip():
                cni('%s:%d' % (PIT, n), 'row carries no path or no reason: not applied (an exemption without its reason is refused)'); continue
            pit.append((n, f[0].strip()))
        for n, pat in pit:
            if not any(fnmatch.fnmatchcase(d, pat) for d, _ in docs):
                cni('%s:%d' % (PIT, n), 'row matches no scanned document: a stale exemption is reported, never silently kept')

# ---- ledger-backed spans (docs/claim-ledger.tsv; class stale-figures owns these) -------------
backed = {}
lp = 'docs/claim-ledger.tsv'
if os.path.lexists(os.path.join(base, lp)):
    try:
        if unsafe(lp): raise OSError(unsafe(lp))
        ledger = read_text(lp).split('\n')
    except OSError:
        ledger = []; cni(lp, 'the claim ledger could not be read (or is not a regular file inside the tree), so ledger-backed claims cannot be subtracted')
    for ln in ledger:
        f = ln.split('\t')
        if len(f) < 10 or f[0] != 'claim': continue
        surf = f[2]
        try: rx = re.compile(f[8], re.M)
        except re.error:
            cni(lp, 'a claim anchor does not compile, so the claims it backs cannot be subtracted'); continue
        if not os.path.lexists(os.path.join(base, surf)) or unsafe(surf): continue
        try: txt = read_text(surf)
        except OSError: continue
        for mm in rx.finditer(txt):
            backed.setdefault(surf, []).append(mm.span(1) if rx.groups >= 1 else mm.span(0))

# ---- claim grammar ---------------------------------------------------------------------------
SEP = r'(?:[ \t]+|[ \t]*\n[ \t]*(?:>[ \t]*)?)'
NUM = r'(?<![\w.\-/:#§$~≈±+])(\d{1,3}(?:,\d{3})+|\d+)(?![.,]?\d)'
EMPH = r'(?:\*\*|__|\*|_)?'
NOUNS = ['test files', 'verify scripts', 'prove scripts', 'submodules', 'anchors', 'commits',
         'services', 'scripts', 'checks', 'files', 'tests', 'gates', 'items', 'lines', 'specs', 'rows']
NOUNRX = '|'.join(n.replace(' ', r'[ \t]+') for n in NOUNS)
R_NOUN = re.compile(NUM + EMPH + SEP + r'(?:`([^`\n\t]{1,160})`' + SEP + r')?(?:(tracked)' + SEP + r')?(' + NOUNRX + r')\b')
R_GLOB = re.compile(NUM + EMPH + SEP + r'`([^`\s]*[*?][^`\s]*)`' + SEP + r'(?:\*\*|__)?[a-z][a-z-]*\b')
R_PAIR = re.compile(NUM + r'[ \t]+verify[ \t]*/[ \t]*(\d+)[ \t]+prove\b')
R_HIST = re.compile(r'WITHDRAWN|SUPERSEDED|[Ww]ithdrawn|[Ss]uperseded|HISTORICAL|[Hh]istorical|~~')
R_TICK = re.compile(r'`([^`\n\t]+)`')
R_PARA = re.compile(r'\n[ \t]*(?:>[ \t]*)?\n')
R_LINES_PRE = re.compile(r'`([^`\n\t]+)`[ \t]*(?:\(|:|,|—|–|-|is|has|holds|at)?[ \t]*(?:\*\*|__)?$')
R_LINES_POST = re.compile(SEP + r'(?:in|of)' + SEP + r'`([^`\n\t]+)`')
R_FILES_POST = re.compile(SEP + r'(?:in|under|inside|below)' + SEP + r'`([^`\n\t]+)`(?=[ \t]*(?:[.,;:)|]|\n|$))')

def claims(text):
    got = {}
    for mm in R_GLOB.finditer(text):
        got[mm.start(1)] = dict(num=mm.group(1), end=mm.end(), kind='glob', tok=mm.group(2), noun=None)
    for mm in R_PAIR.finditer(text):
        got.setdefault(mm.start(1), dict(num=mm.group(1), end=mm.end(), kind='verify', tok=None, noun='verify'))
        got.setdefault(mm.start(2), dict(num=mm.group(2), end=mm.end(), kind='prove', tok=None, noun='prove'))
    for mm in R_NOUN.finditer(text):
        noun = re.sub(r'[ \t]+', ' ', mm.group(4))
        kind = {'verify scripts': 'verify', 'prove scripts': 'prove'}.get(noun, 'noun')
        got.setdefault(mm.start(1), dict(num=mm.group(1), end=mm.end(), kind=kind, tok=mm.group(2), noun=noun, qual=mm.group(3)))
    return got

PREDS = {'dir': lambda x: x.endswith('/'),
         'gm': lambda x: posixpath.basename(x.strip()) == '.gitmodules'}
class Ticks:
    """Backticked tokens of each paragraph, computed ONCE per paragraph and looked up by bisection
    (review fix: a per-claim re-scan of the paragraph made the cost quadratic in paragraph size).
    The tokens of text[ps:start] are exactly the paragraph's tokens that END at or before start:
    a token cannot span a newline or a backtick, so the pairing from ps is the same."""
    def __init__(self, text, paras):
        self.text, self.paras, self.cache = text, paras, {}
    def nearest(self, ps, start, pred):
        k = (ps, pred)
        if k not in self.cache:
            i = bisect.bisect_right(self.paras, ps)
            pe = self.paras[i] if i < len(self.paras) else len(self.text)
            ends, toks = [], []
            for mm in R_TICK.finditer(self.text, ps, pe):
                if PREDS[pred](mm.group(1)):
                    ends.append(mm.end()); toks.append(mm.group(1))
            self.cache[k] = (ends, toks)
        ends, toks = self.cache[k]
        j = bisect.bisect_right(ends, start)
        return toks[j - 1] if j else None
def nearest_tick(T, ps, start, pred):
    # the NEAREST preceding backticked token of the paragraph satisfying pred, and only that one
    return T.nearest(ps, start, pred)
def scope_dir(T, ps, start, m):
    t = nearest_tick(T, ps, start, 'dir')
    return resolve_dir(t, m) if t else None

_direct = {}
def count_direct(d, pat):
    if (d, pat) not in _direct:
        _direct[(d, pat)] = sum(1 for f in files_under(d) if '/' not in f and fnmatch.fnmatchcase(f, pat)
                                and (pat.startswith('.') or not f.startswith('.')))
    return _direct[(d, pat)]

UNSAFE = object()
def unsafe_subject(f, loc):
    why = unsafe(f)
    if why: cni(f, why + ' (the count claimed at %s is not measured)' % loc)
    return why
def measure(c, text, T, start, ps, line_text, m, loc):
    """-> (label, value, how) or (label, None, None) when no rule of the table resolves the subject;
    value UNSAFE when the subject is a linked/special file (COULD-NOT-INSPECT recorded)"""
    kind, noun, num = c['kind'], c['noun'], c['num']
    if kind == 'glob':
        tok = c['tok']
        if '**' in tok: return tok, None, None
        if '/' in tok:
            dpart, pat = tok.rsplit('/', 1)
            d = resolve_dir(dpart, m) if dpart and not re.search(r'[*?\[]', dpart) else None
        else:
            pat, d = tok, scope_dir(T, ps, start, m)
        if not pat or d is None or not re.search(r'[^*?]', pat): return tok, None, None
        n = count_direct(d, pat)
        if n == 0: return tok, None, None   # subject not located in that scope: never drift
        return pat, n, 'tracked direct entries of %s/ matching %s' % (d, pat)
    if kind in ('verify', 'prove'):
        pat = kind + '-*.sh'
        d = scope_dir(T, ps, start, m)
        label = noun if noun in ('verify', 'prove') else noun
        n = count_direct(d, pat) if d is not None else 0
        if n == 0: return label, None, None   # no scope, or subject not located in it
        return label, n, 'tracked direct entries of %s/ matching %s' % (d, pat)
    if noun == 'files':
        mm = R_FILES_POST.match(text, c['end']) if c.get('qual') else None
        d = resolve_dir(mm.group(1).rstrip('/'), m) if mm else None
        if d is None: return noun, None, None
        return noun, len(files_under(d)), 'tracked files under %s/ (recursive)' % d
    if noun == 'lines':
        mm = R_LINES_PRE.search(text, max(ps, start - 240), start)
        f = resolve_file(mm.group(1), m, True) if mm else None
        if f is None:
            mm = R_LINES_POST.match(text, c['end'])
            f = resolve_file(mm.group(1), m, True) if mm else None
        if f is None: return noun, None, None
        if unsafe_subject(f, loc): return noun, UNSAFE, None
        with open(os.path.join(base, f), 'rb') as fh:
            b = fh.read()
        return noun, b.count(b'\n') + (1 if b and not b.endswith(b'\n') else 0), 'line count of %s (wc -l, plus an unterminated last line)' % f
    if noun == 'anchors':
        for t in R_TICK.findall(line_text):
            if posixpath.basename(t.strip()) == 'Constitution.md':
                f = resolve_file(t, m, True)
                if f and unsafe_subject(f, loc): return noun, UNSAFE, None
                if f:
                    with open(os.path.join(base, f), 'rb') as fh:
                        n = sum(1 for l in fh.read().split(b'\n') if l.startswith('### §'.encode()))
                    return noun, n, "grep -c '^### §' %s" % f
        return noun, None, None
    if noun == 'submodules':
        t = nearest_tick(T, ps, start, 'gm')
        gm = resolve_file(t, m) if t else None
        if gm is None: return noun, None, None
        if unsafe_subject(gm, loc): return noun, UNSAFE, None
        return noun, len(gitmodules(os.path.join(base, posixpath.dirname(gm))) or []), 'path entries of %s' % gm
    if noun == 'specs':
        sp = join(m, 'specs')
        fs = files_under(sp) if scope_dir(T, ps, start, m) == sp else []
        if not fs: return noun, None, None
        n = len({f.split('/')[0] for f in fs if '/' in f and re.match(r'\d{3}-', f)})
        return noun, n, 'specs/NNN-* directories holding tracked files under %s/' % sp
    return noun, None, None

def clean_desc(s):
    s = re.sub(r'[\x00-\x1f\x7f\u0080-\u009f  ‎‏‪-‮⁦-⁩]', ' ', s)
    return s.encode('utf-8', 'replace').decode('utf-8')

def claim_key(line_text):
    # content-anchored secondary key (review fix (e)): a location doc:line moves when a line is
    # inserted above it; the key (sha256 of the whitespace-normalised line, 12 hex) does not
    return hashlib.sha256(' '.join(line_text.split()).encode('utf-8', 'surrogateescape')).hexdigest()[:12]

results = []
for d, m in docs:
    why = unsafe(d)
    if why:
        cni(d, why); continue
    try:
        text = read_text(d)
    except OSError:
        cni(d, 'tracked document could not be read'); continue
    got = claims(text)
    if not got: continue
    nl = [i for i, ch in enumerate(text) if ch == '\n'] if len(got) else []
    paras = [mm.end() for mm in R_PARA.finditer(text)]
    T = Ticks(text, paras)
    spans = backed.get(d, [])
    carrier = posixpath.basename(d) in CARRIERS and posixpath.dirname(d) == m and m != ''
    exempt = any(fnmatch.fnmatchcase(d, pat) for _, pat in pit)
    perline = {}     # line -> (line_text, historical?, key, normalised text): computed ONCE per line
    for start in sorted(got):
        c = got[start]; e = start + len(c['num'])
        if any(s < e and start < t for s, t in spans): continue
        line = bisect.bisect_left(nl, start) + 1
        items.add('%s:%d' % (d, line)); items.add('figures:' + d)
        if mode == 'emit': continue
        if exempt: continue          # point-in-time: true when written (docs/zero-gap/point-in-time.tsv)
        if line not in perline:
            ls = nl[line - 2] + 1 if line >= 2 else 0
            le = nl[line - 1] if line - 1 < len(nl) else len(text)
            lt = text[ls:le]
            perline[line] = (lt, bool(R_HIST.search(lt)), claim_key(lt), ' '.join(lt.split()))
        line_text, hist, key, norm = perline[line]
        if hist: continue
        i = bisect.bisect_right(paras, start)
        ps = paras[i - 1] if i else 0
        rec = int(c['num'].replace(',', ''))
        loc = '%s:%d' % (d, line)
        label, val, how = measure(c, text, T, start, ps, line_text, m, loc)
        if val is UNSAFE: continue
        if val is not None and val == rec: continue
        if val is None and c['kind'] == 'glob': label = 'entries of a backticked glob'   # never echo document tokens
        results.append(dict(d=d, m=m, line=line, loc=loc, key=key, norm=norm,
                            carrier=carrier, rec=rec, label=label, val=val, how=how, also=[], dup=False))

# LOCKSTEP (review fix (b)): the root carriers CLAUDE/AGENTS/QWEN/GEMINI of one module carry the same
# text; an identical line carrying the same claim is ONE finding, at the first carrier in that order,
# with an `also in` list. A carrier line that drifted from its siblings is not identical: reported alone.
ORDER = {c: i for i, c in enumerate(('CLAUDE.md', 'AGENTS.md', 'QWEN.md', 'GEMINI.md'))}
groups = {}
for r in results:
    if r['carrier']:
        groups.setdefault((r['m'], r['norm'], r['rec'], r['label'], r['val']), []).append(r)
for g in groups.values():
    g.sort(key=lambda r: (ORDER[posixpath.basename(r['d'])], r['line']))
    for r in g[1:]:
        r['dup'] = True
        if r['loc'] not in g[0]['also']: g[0]['also'].append(r['loc'])

low = {}
for r in results:
    if r['dup']: continue
    if r['val'] is None:
        low.setdefault(r['d'], []).append(r)
        continue
    also = ('; also in ' + ' '.join(sorted(r['also']))) if r['also'] else ''
    finds.append((r['loc'], 'high' if r['carrier'] else 'medium', 'docs-drift', clean_desc(
        'recorded %d %s, measured %d by: %s%s; claim-key=%s' % (r['rec'], r['label'], r['val'], r['how'], also, r['key'])), r['loc']))
# the LOW tier (review fix (d)): ONE aggregate per document, located figures:<doc>
AGG_MAX = 30
for d, rs in low.items():
    lines = sorted({r['line'] for r in rs})
    nums = ' '.join(str(x) for x in lines[:AGG_MAX]) + (' (+%d more)' % (len(lines) - AGG_MAX) if len(lines) > AGG_MAX else '')
    first = min(rs, key=lambda r: r['line'])
    finds.append(('figures:' + d, 'low', 'docs-drift', clean_desc(
        '%d unmeasurable recorded count(s) on line(s) %s: no rule of the noun-to-measure table resolves their subject (recorded, not drift); first: %d %s' % (len(rs), nums, first['rec'], first['label'])), first['loc']))

def wz(name, xs):
    with open(os.path.join(W, name), 'wb') as fh:
        for x in xs: fh.write(os.fsencode(x) + b'\0')
wz('items.z', sorted(items))
wz('find.loc.z', [f[0] for f in finds])
wz('find.ev.z', [f[4] for f in finds])
with open(os.path.join(W, 'find.rest'), 'w', encoding='utf-8') as fh:
    for f in finds: fh.write('%s\t%s\t%s\n' % f[1:4])
wz('cni.part.z', [c[0] for c in cnis])
with open(os.path.join(W, 'cni.why'), 'w', encoding='utf-8') as fh:
    for c in cnis: fh.write(clean_desc(c[1]) + '\n')
PY
}

# undet <mode> <reason>: the whole run could not determine. A live run prints the contract lines
# (COULD-NOT-INSPECT + INSPECTED 0 + POPULATION-SHA of nothing) on stdout; --emit-population prints
# NOTHING on stdout (its stdout is the population) and the reason on stderr. Always rc 2.
undet() {
    if [ "$1" = emit ]; then printf '[%s] %s\n' "$ID" "$2" >&2
    else printf 'COULD-NOT-INSPECT - %s\nINSPECTED 0\nPOPULATION-SHA %s\n' "$2" "$EMPTY_SHA"; fi
    return 2
}

# core <emit|run> <root> <corpus-or-empty>: prints the class output, returns 0/1/2
core() {
    local mode=$1 prc=0 walked n nf nc t
    for t in git python3 od awk sort sha256sum paste; do
        command -v "$t" >/dev/null 2>&1 || { undet "$mode" "$t not found on PATH (the class cannot scan)"; return 2; }
    done
    W=$(mktemp -d "${TMPDIR:-/tmp}/zg-dcd.XXXXXX") || { undet "$mode" "mktemp failed"; return 2; }
    trap 'rm -rf "${W:-}"' EXIT   # W is global on purpose: the EXIT trap runs after core returns
    scan "$mode" "$2" "$3" "$W" 2>"$W/py.err" || prc=$?
    if [ "$prc" -ne 0 ]; then
        sed "s/^/[$ID] /" "$W/py.err" >&2
        undet "$mode" "the scanner failed (python3 exit $prc)"; return 2
    fi
    walked=$(zg_pct_encode_z <"$W/items.z" | awk 'NF' | LC_ALL=C sort -u)
    if [ "$mode" = emit ]; then
        if [ -n "$walked" ]; then printf '%s\n' "$walked"; fi
        return 0
    fi
    nf=$(tr -cd '\0' <"$W/find.loc.z" | wc -c)
    nc=$(tr -cd '\0' <"$W/cni.part.z" | wc -c)
    if [ "$nf" -gt 0 ]; then
        zg_pct_encode_z <"$W/find.loc.z" >"$W/find.loc"
        zg_pct_encode_z <"$W/find.ev.z" >"$W/find.ev"
        if [ "$(awk 'END{print NR}' "$W/find.loc")" -ne "$(awk 'END{print NR}' "$W/find.rest")" ] ||
           [ "$(awk 'END{print NR}' "$W/find.ev")" -ne "$(awk 'END{print NR}' "$W/find.rest")" ]; then
            undet run "internal: finding locations, evidence and records disagree in number"; return 2
        fi
        paste -d'\t' "$W/find.loc" "$W/find.rest" "$W/find.ev" |
            awk -F'\t' -v id="$ID" '{ print "FINDING " id " " $2 " " $3 " " $1 " " $4 " " $5 }' | LC_ALL=C sort -u
    fi
    if [ "$nc" -gt 0 ]; then
        zg_pct_encode_z <"$W/cni.part.z" | paste -d' ' - "$W/cni.why" | sed 's/^/COULD-NOT-INSPECT /' | LC_ALL=C sort -u
    fi
    if [ -z "$walked" ]; then
        echo "COULD-NOT-INSPECT - population enumerated to zero count claims: a class that inspects nothing is never clean"
        nc=$((nc + 1)); n=0
        echo "INSPECTED 0"; echo "POPULATION-SHA $EMPTY_SHA"
    else
        n=$(printf '%s\n' "$walked" | awk 'END{print NR}')
        echo "INSPECTED $n"
        echo "POPULATION-SHA $(printf '%s\n' "$walked" | sha256sum | cut -d' ' -f1)"
    fi
    if [ "$nf" -gt 0 ]; then return 1; fi
    if [ "$nc" -gt 0 ]; then return 2; fi
    return 0
}

# ---------------------------------------------------------------------------------------------
# prove_failure: the paired proof. Throwaway repositories only; the live tree is only READ.
prove_failure() (
    set -uo pipefail
    local T fails=0 undet=0 CORP="$SELF_DIR/../_tests/fixtures/zero-gap/$ID" SCRIPT="$SELF_DIR/$(basename "$0")"
    T=$(mktemp -d) || { echo "PROOF UNDETERMINED: mktemp failed"; exit 2; }
    trap 'rm -rf "$T"' EXIT
    for t in git python3 sha256sum od awk; do
        command -v "$t" >/dev/null 2>&1 || { echo "PROOF UNDETERMINED: $t not on PATH"; exit 2; }
    done
    [ -f "$CORP/expect.tsv" ] && [ -d "$CORP/planted" ] && [ -d "$CORP/clean" ] || { echo "PROOF UNDETERMINED: corpus $CORP incomplete"; exit 2; }
    ok()  { echo "  ok   $*"; }
    bad() { echo "  FAIL $*"; fails=$((fails + 1)); }
    und() { echo "  UNDET $*"; undet=$((undet + 1)); }
    # mkrepo <src> <dst>: copy a corpus tree and make it a git repository whose declared
    # submodule directories are nested repositories (gitlinks), like a real checkout.
    mkrepo() {
        local p
        cp -R "$1" "$2" || return 1
        while IFS= read -r p; do
            [ -d "$2/$p" ] || continue
            git -C "$2/$p" init -q && git -C "$2/$p" add -A &&
                git -C "$2/$p" -c user.name=zg -c user.email=zg@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m fixture || return 1
        done < <(git config -f "$2/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}')
        git -C "$2" init -q && git -C "$2" -c advice.addEmbeddedRepo=false add -A 2>/dev/null
    }
    # run <outfile> <args...>: invoke the class under a minimal environment; sets RC
    run() { local o=$1; shift; RC=0; env -i PATH="$PATH" HOME="${HOME:-/tmp}" TMPDIR="$T" LC_ALL=C bash "$SCRIPT" "$@" >"$o" 2>"$o.err" </dev/null || RC=$?; }
    locs() { awk '$1 == "FINDING" { print $5 }' "$1" | LC_ALL=C sort -u; }
    expected() { awk -F'\t' '!/^#/ && NF { print $1 }' "$CORP/expect.tsv" | LC_ALL=C sort -u; }
    contract_ok() { # <out> <emitfile>: every line in the grammar, INSPECTED == emitted items, SHA agrees
        local o=$1 e=$2 n sha
        if LC_ALL=C grep -Evq '^(FINDING doc-count-drift (critical|high|medium|low) docs-drift [^ ]+ .+ [^ ]+|COULD-NOT-INSPECT [^ ]+ .+|INSPECTED [0-9]+|POPULATION-SHA [0-9a-f]{64})$' "$o"; then return 1; fi
        n=$(awk '$1 == "INSPECTED" { print $2 }' "$o")
        [ "$n" = "$(awk 'END{print NR}' "$e")" ] || return 1
        sha=$(awk '$1 == "POPULATION-SHA" { print $2 }' "$o")
        [ "$sha" = "$(sha256sum <"$e" | cut -d' ' -f1)" ] || return 1
        LC_ALL=C sort -u "$e" | cmp -s - "$e"
    }

    echo "P1 control: clean corpus as a live repository => rc 0, no finding, contract holds"
    mkrepo "$CORP/clean" "$T/c" || { echo "PROOF UNDETERMINED: cannot build repositories"; exit 2; }
    run "$T/c.emit" --root "$T/c" --emit-population; erc=$RC
    run "$T/c.out" --root "$T/c"
    if [ "$erc" -eq 0 ] && [ "$RC" -eq 0 ] && ! grep -q '^FINDING' "$T/c.out" && contract_ok "$T/c.out" "$T/c.emit" && [ -s "$T/c.emit" ]; then ok "P1 control rc 0, $(awk 'END{print NR}' "$T/c.emit") items"; else bad "P1 control rc=$RC emit-rc=$erc"; fi

    echo "P2 planted: planted corpus as a live repository => rc 1, exactly the expect.tsv locations"
    mkrepo "$CORP/planted" "$T/p" || { echo "PROOF UNDETERMINED: cannot build repositories"; exit 2; }
    run "$T/p.emit" --root "$T/p" --emit-population
    run "$T/p.out" --root "$T/p"
    if [ "$RC" -eq 1 ] && [ "$(locs "$T/p.out")" = "$(expected)" ] && contract_ok "$T/p.out" "$T/p.emit"; then ok "P2 planted rc 1, $(locs "$T/p.out" | awk 'END{print NR}') locations = expect.tsv"; else bad "P2 planted rc=$RC; diff: $(diff <(locs "$T/p.out") <(expected) | tr '\n' ' ')"; fi

    echo "P2b severities: drift on a MODULE carrier is high, elsewhere medium; unresolvable subjects are one LOW aggregate per document"
    sev() { awk -v l="$2" '$1 == "FINDING" && $5 == l { print $3 }' "$1" | LC_ALL=C sort -u | tr '\n' ' '; }
    desc() { awk -v l="$2" '$1 == "FINDING" && $5 == l' "$1" | LC_ALL=C sort | head -n 1; }
    s2ok=1
    for l in mod/CLAUDE.md:3 mod/CLAUDE.md:6 mod/GEMINI.md:6; do [ "$(sev "$T/p.out" "$l")" = "high " ] || { s2ok=0; bad "P2b $l is '$(sev "$T/p.out" "$l")', want high"; }; done
    for l in docs/files.md:3 docs/lines.md:3 docs/glob.md:3 docs/submodules.md:3; do [ "$(sev "$T/p.out" "$l")" = "medium " ] || { s2ok=0; bad "P2b $l is '$(sev "$T/p.out" "$l")', want medium"; }; done
    for l in figures:docs/scope.md figures:docs/unmeasurable.md figures:mod/docs/scripts.md; do
        [ "$(sev "$T/p.out" "$l")" = "low " ] || { s2ok=0; bad "P2b $l is '$(sev "$T/p.out" "$l")', want low (unmeasurable, not drift)"; }
    done
    if [ "$s2ok" -eq 1 ]; then ok "P2b severities: 3 high (module carriers), 4 medium, 3 low aggregates"; fi

    echo "P2c each aggregate names exactly its lines"
    agl() { desc "$1" "$2" | sed -n 's/.* on line(s) \([0-9 ]*\):.*/\1/p'; }
    a1=$(agl "$T/p.out" figures:docs/scope.md); a2=$(agl "$T/p.out" figures:docs/unmeasurable.md); a3=$(agl "$T/p.out" figures:mod/docs/scripts.md)
    if [ "$a1" = "3 5 7 9 11" ] && [ "$a2" = "3 5 7" ] && [ "$a3" = "5" ]; then ok "P2c aggregates: scope 3 5 7 9 11, unmeasurable 3 5 7, mod/docs/scripts.md 5"
    else bad "P2c aggregate lines: scope '$a1' unmeasurable '$a2' mod/docs/scripts.md '$a3'"; fi

    echo "P2d lockstep carrier copies of one module collapse into ONE finding with an 'also in' list"
    d3=$(desc "$T/p.out" mod/CLAUDE.md:3); d6=$(awk '$1 == "FINDING" && $5 == "mod/CLAUDE.md:6"' "$T/p.out")
    if grep -q 'also in mod/AGENTS.md:3 mod/GEMINI.md:3 mod/QWEN.md:3' <<<"$d3" && grep -q 'also in mod/AGENTS.md:6 mod/QWEN.md:6[^ ]' <<<"$d6" \
       && ! grep -q 'GEMINI' <<<"$d6"; then ok "P2d mod/CLAUDE.md:3 also in AGENTS/GEMINI/QWEN; mod/CLAUDE.md:6 also in AGENTS/QWEN only (GEMINI drifted)"
    else bad "P2d lockstep collapse: '$d3' / '$d6'"; fi

    echo "P2e every drift finding carries a content-anchored claim key that survives a line shift"
    k1=$(desc "$T/p.out" docs/lines.md:3 | grep -o 'claim-key=[0-9a-f]\{12\}')
    nk=$(awk '$1 == "FINDING" && $5 !~ /^figures:/' "$T/p.out" | grep -vc 'claim-key=[0-9a-f]\{12\}')
    mkrepo "$CORP/planted" "$T/ks" && sed -i.bak '1i\
' "$T/ks/docs/lines.md" && rm -f "$T/ks/docs/lines.md.bak" && git -C "$T/ks" add -A 2>/dev/null
    run "$T/ks.out" --root "$T/ks"
    k2=$(desc "$T/ks.out" docs/lines.md:4 | grep -o 'claim-key=[0-9a-f]\{12\}')
    if [ -n "$k1" ] && [ "$k1" = "$k2" ] && [ "$nk" -eq 0 ]; then ok "P2e $k1 at docs/lines.md:3 and, after a line is inserted above, at docs/lines.md:4; no drift finding lacks a key"
    else bad "P2e keys '$k1' / '$k2', $nk drift finding(s) without a key"; fi

    echo "P3/P4 corpus mode (what the sweep's recall engine runs)"
    run "$T/cp.out" --root "$T/c" --corpus "$CORP/planted"
    if [ "$RC" -eq 1 ] && [ "$(locs "$T/cp.out")" = "$(expected)" ]; then ok "P3 --corpus planted: recall 1.0, no unexpected location"; else bad "P3 --corpus planted rc=$RC"; fi
    run "$T/cc.out" --root "$T/c" --corpus "$CORP/clean"
    if [ "$RC" -eq 0 ] && ! grep -q '^FINDING' "$T/cc.out"; then ok "P4 --corpus clean: no finding"; else bad "P4 --corpus clean rc=$RC"; fi

    # mutate <name> <file-in-clean-repo> <sed-expr> <expected-location>: one edit => exactly one location
    mutate() {
        local n=$1 f=$2 e=$3 want=$4 R="$T/m-$1"
        mkrepo "$CORP/clean" "$R" || { und "$n cannot build"; return; }
        sed -i.bak "$e" "$R/$f" && rm -f "$R/$f.bak"
        git -C "$R" add -A 2>/dev/null
        run "$R.out" --root "$R"
        if [ -z "$want" ]; then
            if [ "$RC" -eq 0 ] && ! grep -q '^FINDING' "$R.out"; then ok "$n => no finding"; else bad "$n rc=$RC got '$(locs "$R.out" | tr '\n' ' ')' want none"; fi
        elif [ "$RC" -eq 1 ] && [ "$(locs "$R.out")" = "$want" ]; then ok "$n => $want"; else bad "$n rc=$RC got '$(locs "$R.out" | tr '\n' ' ')' want '$want'"; fi
    }
    echo "P5 single mutations each flip exactly one location"
    mutate files-count  docs/files.md  's/There are 4 tracked files in/There are 5 tracked files in/' docs/files.md:3
    mutate lines-count  docs/lines.md  's/(5 lines)/(6 lines)/'                        docs/lines.md:3
    mutate glob-count   docs/glob.md   's/\*\*3\*\*/**9**/'                              docs/glob.md:3
    mutate lockstep-one mod/QWEN.md    's/\*\*2\*\*/**7**/'                              mod/QWEN.md:3
    echo "P6 the skips are what hide a stale claim (remove the reason => it is reported)"
    mutate no-ledger     docs/claim-ledger.tsv '/^claim/d'           figures:docs/ledgered.md
    mutate no-historical docs/historical.md    's/ (SUPERSEDED)//'    figures:docs/historical.md
    mutate ext-owned     .gitmodules           's#github.com:other/ext#github.com:acme/ext#' figures:ext/README.md
    mutate no-pit        docs/zero-gap/point-in-time.tsv '/^docs\/report.md/d'  docs/report.md:3
    echo "P6b a point-in-time row without a reason is not applied and is COULD-NOT-INSPECT (never a silent exemption)"
    mkrepo "$CORP/clean" "$T/pr" && printf 'docs/files.md\t\n' >>"$T/pr/docs/zero-gap/point-in-time.tsv" && git -C "$T/pr" add -A 2>/dev/null
    run "$T/pr.out" --root "$T/pr"
    if [ "$RC" -eq 2 ] && grep -q '^COULD-NOT-INSPECT docs/zero-gap/point-in-time.tsv:4 ' "$T/pr.out"; then ok "P6b reasonless row => COULD-NOT-INSPECT docs/zero-gap/point-in-time.tsv:4, rc 2"; else bad "P6b rc=$RC"; fi
    echo "P6c the umbrella carriers and README are outside the population (stale-figures owns them)"
    mkrepo "$CORP/clean" "$T/uc" && sed -i.bak 's/declares 4 submodules/declares 9 submodules/' "$T/uc/CLAUDE.md" && rm -f "$T/uc/CLAUDE.md.bak" && git -C "$T/uc" add -A 2>/dev/null
    run "$T/uc.out" --root "$T/uc"
    if [ "$RC" -eq 0 ] && ! grep -q '^FINDING' "$T/uc.out"; then ok "P6c a drifting umbrella CLAUDE.md count yields nothing here"; else bad "P6c rc=$RC"; fi

    echo "P7 empty population => rc 2, never clean"
    mkdir -p "$T/e" && printf '# Nothing to count\n\nNo figure here.\n' >"$T/e/README.md" && git -C "$T/e" init -q && git -C "$T/e" add -A
    run "$T/e.out" --root "$T/e"
    if [ "$RC" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' "$T/e.out"; then ok "P7 zero claims => rc 2"; else bad "P7 rc=$RC"; fi

    echo "P8 absent root => rc 2"
    run "$T/a.out" --root /nonexistent
    if [ "$RC" -eq 2 ] && grep -qx 'INSPECTED 0' "$T/a.out" && grep -qx "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)" "$T/a.out"; then ok "P8 --root /nonexistent rc 2 (INSPECTED 0 and POPULATION-SHA printed)"; else bad "P8 rc=$RC"; fi
    run "$T/a2.out" --root /nonexistent --emit-population
    if [ "$RC" -eq 2 ] && [ ! -s "$T/a2.out" ]; then ok "P8b a failed --emit-population prints nothing on stdout (reason on stderr), rc 2"; else bad "P8b emit rc=$RC stdout: $(head -c 120 "$T/a2.out")"; fi

    echo "P9 missing python3 => rc 2 (live run and --emit-population)"
    mkdir -p "$T/bin"
    for t in bash env git od awk sort sha256sum cut mktemp rm cat tr paste sed grep wc dirname basename head mkdir cp find uniq; do
        p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$T/bin/$t"
    done
    RC=0; env -i PATH="$T/bin" HOME="${HOME:-/tmp}" TMPDIR="$T" LC_ALL=C "$T/bin/bash" "$SCRIPT" --root "$T/c" >"$T/np.out" 2>/dev/null </dev/null || RC=$?; r1=$RC
    RC=0; env -i PATH="$T/bin" HOME="${HOME:-/tmp}" TMPDIR="$T" LC_ALL=C "$T/bin/bash" "$SCRIPT" --root "$T/c" --emit-population >"$T/npe.out" 2>/dev/null </dev/null || RC=$?; r2=$RC
    if [ "$r1" -eq 2 ] && [ "$r2" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' "$T/np.out" && grep -qx 'INSPECTED 0' "$T/np.out" && grep -q '^POPULATION-SHA ' "$T/np.out" && [ ! -s "$T/npe.out" ]; then ok "P9 no python3 => rc 2 / 2 (INSPECTED 0 + POPULATION-SHA; emit stdout empty)"; else bad "P9 rc=$r1 emit-rc=$r2"; fi

    echo "P10 an owned module that is not checked out => rc 2"
    mkrepo "$CORP/clean" "$T/g" && rm -rf "$T/g/mod2"
    run "$T/g.out" --root "$T/g"
    if [ "$RC" -eq 2 ] && grep -q '^COULD-NOT-INSPECT gitlink:mod2 ' "$T/g.out"; then ok "P10 mod2 absent => COULD-NOT-INSPECT gitlink:mod2, rc 2"; else bad "P10 rc=$RC"; fi

    echo "P13 cost is not quadratic in paragraph size: one ~240 KB paragraph of glob claims ends in time"
    mkrepo "$CORP/clean" "$T/big" && python3 -c 'import sys; sys.stdout.write("# Big\n\n" + "In `data/` there are 3 `*.txt` files and " * 6000 + "done.\n")' >"$T/big/docs/big.md" && git -C "$T/big" add -A 2>/dev/null
    s0=$(date +%s); RC=0; env -i PATH="$PATH" HOME="${HOME:-/tmp}" TMPDIR="$T" LC_ALL=C timeout -k 5 20 bash "$SCRIPT" --root "$T/big" >"$T/big.out" 2>&1 </dev/null || RC=$?; s1=$(date +%s)
    if [ "$RC" -eq 0 ]; then ok "P13 240 KB paragraph: rc 0 in $((s1 - s0)) s (limit 20 s; the pre-fix scanner took 52-56 s)"; else bad "P13 240 KB paragraph rc=$RC after $((s1 - s0)) s (124 = over the 20 s limit)"; fi

    echo "P14 symlinks and special files are COULD-NOT-INSPECT, never read, never a hang"
    if command -v mkfifo >/dev/null 2>&1; then
        printf 'ZGOUTSIDEMARKER: 77 tracked files in `data/`.\n' >"$T/outside.md"
        for c in fifo zero outside subject; do
            R="$T/sy-$c"; mkrepo "$CORP/clean" "$R" || { und "P14 $c cannot build"; continue; }
            case $c in
                fifo)    mkfifo "$T/pipe-$c"; ln -s "$T/pipe-$c" "$R/docs/link.md"; want=docs/link.md ;;
                zero)    ln -s /dev/zero "$R/docs/link.md"; want=docs/link.md ;;
                outside) ln -s "$T/outside.md" "$R/docs/link.md"; want=docs/link.md ;;
                subject) mkfifo "$T/pipe-$c"; mkdir -p "$R/pipes"; ln -s "$T/pipe-$c" "$R/pipes/pipe.txt"
                         printf '# P\n\nThe table `pipes/pipe.txt` (5 lines) is small.\n' >"$R/docs/pipe.md"; want=pipes/pipe.txt ;;
            esac
            git -C "$R" add -A 2>/dev/null
            RC=0; env -i PATH="$PATH" HOME="${HOME:-/tmp}" TMPDIR="$T" LC_ALL=C timeout -k 5 60 bash "$SCRIPT" --root "$R" >"$R.out" 2>"$R.err" </dev/null || RC=$?
            if [ "$RC" -eq 2 ] && grep -q "^COULD-NOT-INSPECT $want " "$R.out" && ! grep -q ZGOUTSIDEMARKER "$R.out" "$R.err" && grep -q '^INSPECTED ' "$R.out"; then ok "P14 $c => COULD-NOT-INSPECT $want, rc 2, nothing read"
            else bad "P14 $c rc=$RC (124 = hang): $(head -c 200 "$R.out")"; fi
        done
    else und "P14 mkfifo absent"; fi

    echo "P11 determinism: two runs on the planted repository are byte-identical"
    run "$T/p2.out" --root "$T/p"
    if cmp -s "$T/p.out" "$T/p2.out"; then ok "P11 byte-identical"; else bad "P11 outputs differ"; fi

    echo "P12 the live tree is byte-identical around a live run (read-only class)"
    LIVE=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$LIVE" ] || [ ! -f "$SELF_DIR/zero-gap-lib.sh" ]; then und "P12 live tree or scripts/zero-gap-lib.sh not found"
    else
        # shellcheck source=/dev/null
        . "$SELF_DIR/zero-gap-lib.sh"
        f1=$(zg_fingerprint "$LIVE" 2>/dev/null) || f1=""
        run "$T/live.out" --root "$LIVE"; lrc=$RC
        f2=$(zg_fingerprint "$LIVE" 2>/dev/null) || f2=""
        if [ -z "$f1" ] || [ -z "$f2" ]; then und "P12 fingerprint could not be taken"
        elif [ "$f1" != "$f2" ]; then und "P12 the live tree moved during the run (a concurrent editor cannot be attributed)"
        elif [ "$lrc" -eq 0 ] || [ "$lrc" -eq 1 ] || [ "$lrc" -eq 2 ]; then ok "P12 live run rc $lrc, tree unchanged"
        else bad "P12 live rc=$lrc outside 0/1/2"; fi
    fi

    if [ "$fails" -gt 0 ]; then echo "PROOF FAILED: $fails case(s) slipped through"; exit 1; fi
    if [ "$undet" -gt 0 ]; then echo "PROOF UNDETERMINED: $undet case(s)"; exit 2; fi
    echo "PROOF PASSED"; exit 0
)

# ---------------------------------------------------------------------------------------------
ROOT="" CORPUS="" EMIT=0
while [ $# -gt 0 ]; do
    case "$1" in
--prove-failure)
            prove_failure; exit $? ;;
        --root) ROOT="${2:-}"; shift 2 || shift ;;
        --corpus) CORPUS="${2:-}"; shift 2 || shift ;;
        --emit-population) EMIT=1; shift ;;
        -h|--help) sed -n '2,/^set -uo/p' "$0" | sed '$d'; exit 0 ;;
        *) undet run "unknown argument"; exit 2 ;;
    esac
done
MODE=run; [ "$EMIT" -eq 1 ] && MODE=emit
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then undet "$MODE" "--root is not a directory"; exit 2; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then undet "$MODE" "--corpus is not a directory"; exit 2; fi
ROOT=$(cd "$ROOT" && pwd)
if [ -n "$CORPUS" ]; then CORPUS=$(cd "$CORPUS" && pwd); fi

rc=0
core "$([ "$EMIT" -eq 1 ] && echo emit || echo run)" "$ROOT" "$CORPUS" || rc=$?
exit "$rc"
