#!/usr/bin/env python3
"""Carrier-claims probe for VSC-349 (root carriers) and VSC-351 (CONTINUATION.md).

Independent of the stale-figures class and of fig-population.py: it does NOT mirror their patterns or their
"a marker anywhere on the line hides the line" rule.

Method.  A fixed, explicit table (CLAIMS, GATES below) names the load-bearing figures of the carriers.  Each
claim is located at CLAUSE level (a clause is the text between sentence terminators `. ! ?` at parenthesis
depth 0 and `;` at any depth, backtick spans ignored, table cells and fenced-code lines treated as their own units), the stated
figure is compared with a LIVE re-measurement, and the claim passes only if

  (a) the stated figure equals the live measurement, or
  (b) the claim's OWN clause carries a withdrawn / superseded / historical / obsolete marker that applies to it:
        - a marker at parenthesis depth 0 covers the whole clause;
        - a marker inside a parenthesis covers only figures inside that same parenthesis, unless the
          parenthesis is a pure tag such as `(historical)` (then it covers its clause);
        - a pure tag that FOLLOWS a clause terminator (`... exits 0**. (historical)`) tags the clause it
          follows and nothing else;
        - the word `historical` directly after a count or slash (`2 HISTORICAL`, a verdict noun) is not a marker;
        - a marker on a DIFFERENT clause of the same line is irrelevant.
      A dated phrase such as `re-measured 2026-09-03` is NOT a marker: the figure is still presented as true.

Gate figures (`# 0 - 12 PASS/...` lines in fenced blocks, `| bash scripts/x.sh | **0** - ...` table rows) are
re-measured by running the gate when it is in GATES; an unmarked gate figure whose gate is NOT in GATES is a
finding too (no figure may stand with neither a re-measure nor a marker).  For VSC-351 a figure tuple that
CLAUDE.md carries under a marker must not be restated unmarked in CONTINUATION.md.

Exit codes: 0 holds, 1 a stale/unmeasured/unmarked claim (a finding outranks an undetermined), 2 cannot
determine (a re-measure command failed, an anchor was not found, a file is missing).  2 is never a pass.

Usage:  carrier_claims.py --suite 349|351 [--root DIR] [--live-root DIR] [--no-lockstep]
        carrier_claims.py --prove-failure        (mutation self-test, builds fixtures in a scratch dir)
Measurements run against --live-root (default: the main checkout, derived from `git rev-parse
--git-common-dir`); the claims are read from --root (default: `git rev-parse --show-toplevel`).
"""
import sys
sys.dont_write_bytecode = True
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import tempfile


class Undet(Exception):
    pass


# ----------------------------------------------------------------------------------------------------------
# clause machinery
# ----------------------------------------------------------------------------------------------------------
MARK = re.compile(r'(?<![\w/-])(withdrawn|superseded|historical|obsolete)\b', re.I)
TAG_INNER = re.compile(r'^[\s*_]*(?:\d{4}-\d{2}-\d{2}[\s,;:]*)?(?:withdrawn|superseded|historical|obsolete)[\s*_.]*$', re.I)
TAG_ONLY = re.compile(r'^[\s*_(\[]*(?:\d{4}-\d{2}-\d{2}[\s,;:]*)?(?:withdrawn|superseded|historical|obsolete)[\s*_)\].]*$', re.I)
LEAD_TAG = re.compile(r'^\s*\(([^()]*)\)')


def paren_groups(t):
    st, out, bt = [], [], False
    for i, c in enumerate(t):
        if c == '`':
            bt = not bt
        elif bt:
            continue
        elif c == '(':
            st.append(i)
        elif c == ')' and st:
            out.append((st.pop(), i))
    return out


def split_clauses(t):
    res, s, depth, bt, i, n = [], 0, 0, False, 0, len(t)
    while i < n:
        c = t[i]
        if c == '`':
            bt = not bt
        elif not bt:
            if c == '(':
                depth += 1
            elif c == ')':
                depth = max(0, depth - 1)
            elif c == ';' or (c in '.!?' and depth == 0):
                j = i + 1
                while j < n and t[j] in '*_"\'':
                    j += 1
                if j >= n or t[j].isspace():
                    if not t[max(0, i - 3):i + 1].lower().endswith(('e.g.', 'i.e.', 'vs.')):
                        res.append([s, j])
                        s = j
                        i = j
                        continue
        i += 1
    if s < n:
        res.append([s, n])
    return res


class Clause:
    def __init__(self, unit, s, e):
        self.unit, self.s, self.e = unit, s, e
        self.tagged = False

    @property
    def text(self):
        return self.unit.text[self.s:self.e]

    def line_of(self, off):
        ln = self.unit.lines[0][1]
        for o, l in self.unit.lines:
            if o <= self.s + off:
                ln = l
        return ln

    def covers(self, a, b):
        """does a marker apply to the figure at [a, b) of this clause's text?"""
        if self.tagged:
            return True
        t = self.text
        groups = paren_groups(t)
        for m in MARK.finditer(t):
            if m.group(1).lower() == 'historical' and re.search(r'(?:\d\s*|/)$', t[:m.start()]):
                continue  # a verdict noun after a count ("2 HISTORICAL"), not a marker
            inside = [g for g in groups if g[0] < m.start() < g[1]]
            if not inside:
                return True
            g = min(inside, key=lambda g: g[1] - g[0])
            if TAG_INNER.match(t[g[0] + 1:g[1]]):
                return True
            if g[0] <= a and b <= g[1]:
                return True
        return False


class Unit:
    """a run of text clauses are cut from; carries a per-offset line map and the gate context."""
    def __init__(self, text, lines, code=False, gate=None, section=None):
        self.text, self.lines, self.code, self.gate, self.section = text, lines, code, gate, section
        self.clauses = []
        if code:
            self.clauses = [Clause(self, 0, len(text))]
            return
        prev = None
        for s, e in split_clauses(text):
            c = Clause(self, s, e)
            m = LEAD_TAG.match(c.text)
            if m and prev is not None and TAG_INNER.match(m.group(1)):
                prev.tagged = True
                c.s += m.end()
            if TAG_ONLY.match(c.text) and prev is not None:
                prev.tagged = True
                continue
            if not c.text.strip():
                continue
            self.clauses.append(c)
            prev = c


GATE_CMD = re.compile(r'`bash scripts/([\w.-]+\.sh)')
FENCE_GATE = re.compile(r'^\s*bash scripts/([\w.-]+\.sh)\b')


def units_of(path):
    """split a markdown file into Units; fenced lines and table cells are units of their own."""
    with open(path, encoding='utf-8') as fh:
        raw = fh.read().split('\n')
    out, para, fence, section = [], [], False, None

    def flush():
        if para:
            text, lines, off = '', [], 0
            for ln, l in para:
                piece = (l.strip() + ' ')
                lines.append((off, ln))
                text += piece
                off += len(piece)
            out.append(Unit(text, lines, section=section))
            para.clear()

    for ln, l in enumerate(raw, 1):
        if l.lstrip().startswith('```'):
            flush()
            fence = not fence
            continue
        if fence:
            g = FENCE_GATE.match(l)
            out.append(Unit(l, [(0, ln)], code=True, gate=g.group(1) if g else None, section=section))
            continue
        if l.startswith('## '):
            flush()
            section = l
            continue
        if not l.strip() or l.startswith('#'):
            flush()
            continue
        if l.startswith('|'):
            flush()
            cells = l.split('|')
            gate = None
            if len(cells) > 2:
                g = GATE_CMD.search(cells[1])
                gate = g.group(1) if g else None
            for k, cell in enumerate(cells):
                if cell.strip() and set(cell.strip()) - set('-: '):
                    out.append(Unit(cell.strip() + ' ', [(0, ln)], gate=(gate if k > 1 else None), section=section))
            continue
        if re.match(r'^\s*(?:[-*+]|\d+\.)\s', l):
            flush()
        para.append((ln, l))
    flush()
    return out


# ----------------------------------------------------------------------------------------------------------
# live measurements (run against live_root; memoised; any failure is Undet, never a quiet pass)
# ----------------------------------------------------------------------------------------------------------
class Live:
    def __init__(self, root):
        self.root, self._c = root, {}

    def _run(self, argv, cwd=None, timeout=900):
        key = (tuple(argv), cwd)
        if key not in self._c:
            try:
                p = subprocess.run(argv, cwd=cwd or self.root, capture_output=True, text=True, timeout=timeout,
                                   env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
            except (OSError, subprocess.SubprocessError) as e:
                raise Undet('cannot run %s: %s' % (' '.join(argv[:4]), e))
            self._c[key] = p
        return self._c[key]

    def pin(self):
        p = self._run(['git', 'ls-files', '-s', 'submodules/constitution'])
        f = p.stdout.split()
        if p.returncode != 0 or len(f) < 2:
            raise Undet('constitution pin not resolvable in %s' % self.root)
        return f[1]

    def const_blob(self):
        pin = self.pin()
        p = self._run(['git', '-C', os.path.join(self.root, 'submodules/constitution'), 'show', pin + ':Constitution.md'])
        if p.returncode != 0:
            raise Undet('Constitution.md at pin %s not readable' % pin[:12])
        t = p.stdout
        return {'lines': str(t.count('\n')), 'anchors': str(len(re.findall(r'(?m)^### §', t))),
                'bytes': str(len(t.encode('utf-8')))}

    def gitlink(self, path):
        p = self._run(['git', 'ls-files', '-s', path])
        f = p.stdout.split()
        if p.returncode != 0 or len(f) < 2:
            raise Undet('gitlink %s not resolvable' % path)
        return f[1][:12]

    def gitmodules_count(self):
        gm = os.path.join(self.root, '.gitmodules')
        p = self._run(['git', 'config', '-f', gm, '--get-regexp', r'submodule\..*\.path'])
        if p.returncode != 0:
            raise Undet('.gitmodules unreadable')
        return str(len([l for l in p.stdout.split('\n') if l.strip()]))

    def deploy_literal(self):
        fp = os.path.join(self.root, '_tools/deploy-langs.sh')
        try:
            with open(fp, encoding='utf-8') as fh:
                return '|| build_warn "jekyll _site rebuild"' in fh.read()
        except OSError as e:
            raise Undet('deploy-langs.sh unreadable: %s' % e)

    def gate(self, name):
        spec = GATES[name]
        p = self._run(['bash', 'scripts/' + name])
        res = {'rc': str(p.returncode)}
        if spec:
            m = re.search(spec, p.stdout + p.stderr)
            if not m:
                raise Undet('%s: summary line not found in its output' % name)
            labels = GATE_LABELS[name]
            for k, v in zip(labels, m.groups()):
                res[k] = v
        elif p.returncode not in (0, 1):
            raise Undet('%s: rc %d' % (name, p.returncode))
        return res


GATES = {
    'verify-check-registry.sh': r'CM-CHECK-REGISTRY: (\d+) PASS, (\d+) FAIL, (\d+) DEBT, (\d+) UNDET, (\d+) NOTE',
    'verify-governance-cascade.sh': r'CM-GOVERNANCE-CASCADE: (\d+) PASS, (\d+) FAIL, (\d+) ENV, (\d+) NOTE',
    'verify-manifest-pins.sh': r'CM-MANIFEST-PIN-SYNC: (\d+) MATCH, (\d+) DRIFT, (\d+) UNDETERMINED',
    'audit-hardcoded-paths.sh': None,
    'verify-pretooluse-guard.sh': None,
    'continuation-check.sh': None,
}
GATE_LABELS = {
    'verify-check-registry.sh': ['PASS', 'FAIL', 'DEBT', 'UNDET', 'NOTE'],
    'verify-governance-cascade.sh': ['PASS', 'FAIL', 'ENV', 'NOTE'],
    'verify-manifest-pins.sh': ['MATCH', 'DRIFT', 'UNDET'],
}

# explicit claims: (id, suite set, file, anchor regex searched per CLAUSE, measure name)
CLAIMS = [
    ('const-table', {349}, 'CLAUDE.md',
     r'\((?P<lines>[\d,]+) lines, (?P<anchors>\d+) `### §` anchors, (?P<bytes>[\d,]+) bytes', 'const_blob'),
    ('const-checked-out', {349}, 'CLAUDE.md',
     r'`submodules/constitution` is currently checked out at `(?P<sha>[0-9a-f]{12})[0-9a-f]*`', 'pin'),
    ('gitlink-table', {349}, 'CLAUDE.md',
     r'`(?P<path>submodules/constitution|design-toolkit|submodules/containers|submodules/curriculum-kit|workshop)` '
     r'`(?P<sha>[0-9a-f]{12})`', 'gitlink'),
    ('gitmodules-declared', {349}, 'CLAUDE.md',
     r'`\.gitmodules` declares \*\*(?P<n>\d+)\*\* gitlinks', 'gitmodules'),
    ('deploy-literal', {349}, 'CLAUDE.md',
     r'\|\| build_warn "jekyll _site rebuild"', 'deploy'),
    ('deploy-tolerated', {349}, 'CLAUDE.md',
     r'The failure is tolerated by design', 'deploy'),
    ('deploy-dryrun', {349}, 'CLAUDE.md',
     r'A `--dry-run` therefore reports success while having built nothing', 'deploy'),
    ('cont-declared', {351}, 'CONTINUATION.md',
     r'of (?P<owned>\d+) owned gitlinks probed, (?P<n>\d+) declared', 'gitmodules'),
]

FIG = re.compile(r'(\d+)\s*(PASS|FAIL|DEBT|UNDET\w*|NOTE|ENV|MATCH|DRIFT)\b')
TUPLE = re.compile(r'\d+\s*(?:PASS|CURRENT|MATCH)\s*/\s*\d+\s*(?:FAIL|DRIFT)(?:\s*/\s*\d+\s*(?:UNDET\w*|ENV|DEBT|NOTE))*')
RC_FENCE = re.compile(r'#\s*(\d)\s*[—-]')
RC_TABLE = re.compile(r'^\s*\*\*(\d)\*\*')


def norm(v):
    return str(v).replace(',', '').strip()


def snip(c, a=0):
    t = re.sub(r'[\s*`]+', ' ', c.text).strip()
    return t[:70]


_LIVE = {}


class Run:
    def __init__(self, suite, root, live_root, lockstep):
        # one Live per live_root per process: every gate runs at most once per invocation
        self.suite, self.root, self.live = suite, root, _LIVE.setdefault(live_root, Live(live_root))
        self.lockstep = lockstep
        self.findings, self.undet, self.n = [], [], 0

    def f(self, *a):
        self.findings.append(' '.join(str(x) for x in a))

    # -- explicit claims --
    def explicit(self, fname, units):
        for cid, suites, cfile, anchor, measure in CLAIMS:
            if self.suite not in suites or cfile != fname:
                continue
            rx, hits = re.compile(anchor), 0
            for u in units:
                if self.suite == 351 and u.section and '§3' in u.section:
                    continue
                for c in u.clauses:
                    for m in rx.finditer(c.text):
                        hits += 1
                        self.n += 1
                        try:
                            mism = self.compare(measure, m)
                        except Undet as e:
                            self.undet.append('%s: %s' % (cid, e))
                            continue
                        if mism and not c.covers(m.start(), m.end()):
                            self.f('FINDING', cid, '%s:%d' % (fname, c.line_of(m.start())), 'unmarked-stale',
                                   ' '.join('%s stated=%s live=%s' % x for x in mism), '::', snip(c))
            if hits == 0:
                self.undet.append('%s: anchor not found in %s (carrier rewritten? the check author must update '
                                  'the table - this is not a pass)' % (cid, fname))

    def compare(self, measure, m):
        g = m.groupdict()
        L = self.live
        if measure == 'const_blob':
            live = L.const_blob()
            return [(k, norm(g[k]), live[k]) for k in ('lines', 'anchors', 'bytes') if norm(g[k]) != live[k]]
        if measure == 'pin':
            live = L.pin()[:12]
            return [] if g['sha'] == live else [('sha', g['sha'], live)]
        if measure == 'gitlink':
            live = L.gitlink(g['path'])
            return [] if g['sha'] == live else [(g['path'], g['sha'], live)]
        if measure == 'gitmodules':
            live = L.gitmodules_count()
            return [] if g['n'] == live else [('declared', g['n'], live)]
        if measure == 'deploy':
            return [] if L.deploy_literal() else [('build_warn-jekyll-step', 'present', 'absent')]
        raise Undet('unknown measure ' + measure)

    # -- gate figures --
    def gates(self, fname, units):
        for u in units:
            if u.gate is None:
                continue
            if self.suite == 351 and u.section and '§3' in u.section:
                continue
            # a table cell's status reading is its FIRST clause; later clauses narrate (and are covered by the
            # explicit-claim and cross-reference rules); a fenced line is one clause
            for c in u.clauses[:1]:
                t = c.text
                figs = []  # (label, stated, a, b)
                rc = (RC_FENCE if u.code else RC_TABLE).search(t)
                if rc:
                    figs.append(('rc', rc.group(1), rc.start(1), rc.end(1)))
                for m in FIG.finditer(t):
                    lab = m.group(2).upper()
                    lab = 'UNDET' if lab.startswith('UNDET') else lab
                    figs.append((lab, m.group(1), m.start(), m.end()))
                if not figs:
                    continue
                self.n += 1
                bare = [x for x in figs if not c.covers(x[2], x[3])]
                if not bare:
                    continue
                ln = '%s:%d' % (fname, c.line_of(0))
                if u.gate not in GATES:
                    self.f('FINDING', 'gate-figure', ln, 'unmarked-unmeasured', u.gate, 'figure(s)',
                           ','.join('%s=%s' % (x[0], x[1]) for x in bare), '::', snip(c))
                    continue
                try:
                    live = self.live.gate(u.gate)
                except Undet as e:
                    self.undet.append('%s: %s' % (u.gate, e))
                    continue
                mism = [(x[0], x[1], live[x[0]]) for x in bare if x[0] in live and x[1] != live[x[0]]]
                if mism:
                    self.f('FINDING', 'gate-figure', ln, 'unmarked-stale', u.gate,
                           ' '.join('%s stated=%s live=%s' % m for m in mism), '::', snip(c))

    # -- 351: a tuple withdrawn in CLAUDE.md must not be restated unmarked in CONTINUATION.md --
    def crossref(self, cont_units):
        cl = os.path.join(self.root, 'CLAUDE.md')
        if not os.path.isfile(cl):
            self.undet.append('crossref: CLAUDE.md missing')
            return
        withdrawn = {}
        for u in units_of(cl):
            for c in u.clauses:
                for m in TUPLE.finditer(c.text):
                    if c.covers(m.start(), m.end()):
                        withdrawn.setdefault(re.sub(r'\s+', '', m.group(0)).upper(), c.line_of(m.start()))
        for u in cont_units:
            if u.section and '§3' in u.section:
                continue
            for c in u.clauses:
                for m in TUPLE.finditer(c.text):
                    key = re.sub(r'\s+', '', m.group(0)).upper()
                    if key in withdrawn and not c.covers(m.start(), m.end()):
                        self.n += 1
                        self.f('FINDING', 'withdrawn-restated', 'CONTINUATION.md:%d' % c.line_of(m.start()),
                               'withdrawn at CLAUDE.md:%d' % withdrawn[key], 'tuple', key, '::', snip(c))


def lockstep_ok(root):
    names = ['CLAUDE.md', 'AGENTS.md', 'QWEN.md', 'GEMINI.md']
    hs = set()
    for n in names:
        p = os.path.join(root, n)
        if not os.path.isfile(p):
            raise Undet('missing carrier ' + n)
        with open(p, 'rb') as fh:
            hs.add(hashlib.sha256(b''.join(fh.readlines()[18:])).hexdigest())
    return len(hs) == 1


def run_suite(suite, root, live_root, lockstep=True):
    r = Run(suite, root, live_root, lockstep)
    files = ['CLAUDE.md'] if suite == 349 else ['CONTINUATION.md']
    for fn in files:
        p = os.path.join(root, fn)
        if not os.path.isfile(p):
            r.undet.append('missing ' + fn)
            continue
        units = units_of(p)
        r.explicit(fn, units)
        r.gates(fn, units)
        if suite == 351:
            r.crossref(units)
    if suite == 349 and lockstep:
        try:
            if not lockstep_ok(root):
                r.f('FINDING', 'lockstep', 'CLAUDE.md', 'the four carriers differ from line 19 (C5)')
        except Undet as e:
            r.undet.append(str(e))
    if r.findings:
        rc = 1
    elif r.undet:
        rc = 2
    else:
        rc = 0
    return rc, r


# ----------------------------------------------------------------------------------------------------------
# --prove-failure: mutation self-test on synthetic carrier fixtures built from LIVE values
# ----------------------------------------------------------------------------------------------------------
def prove(live_root):
    live = _LIVE.setdefault(live_root, Live(live_root))
    keep = os.environ.get('ZG_KEEP_SCRATCH') == '1'
    scratch = tempfile.mkdtemp(prefix='carrier-claims-')
    ok, bad = [], []
    try:
        blob = live.const_blob()
        pin = live.pin()[:12]
        gl = live.gitlink('workshop')
        n_decl = live.gitmodules_count()
        reg = live.gate('verify-check-registry.sh')
        man = live.gate('verify-manifest-pins.sh')
        regfig = '%s PASS/%s FAIL/%s DEBT' % (reg['PASS'], reg['FAIL'], reg['DEBT'])
        STALE_LINES = '11,787'

        def claude(table=None, gates=None, deploy=None, extra=''):
            table = table or ('| The universal constitution (%s lines, %s `### §` anchors, %s bytes) measured. | `x` |'
                              % (blob['lines'], blob['anchors'], blob['bytes']))
            gates = gates or ('bash scripts/verify-check-registry.sh   # %s — %s\n' % (reg['rc'], regfig))
            deploy = deploy or ('The failure is tolerated by design. A `--dry-run` therefore reports success while having '
                                'built nothing. It runs `|| build_warn "jekyll _site rebuild"` on one line.\n'
                                if live.deploy_literal() else
                                'The failure used to be tolerated (historical). The step now aborts the deploy.\n')
            # anchors for the claims that are absent from the live tree in the fixture shape
            body = ('# fixture\n\n' + table + '\n\n'
                    '`submodules/constitution` is currently checked out at `%s`, on branch main.\n\n'
                    '`.gitmodules` declares **%s** gitlinks.\n\n'
                    '`workshop` `%s`\n\n' % (pin, n_decl, gl) + deploy + '\n```bash\n' + gates + '```\n' + extra)
            return body

        def need_deploy_anchors(txt):
            # the three deploy anchors must be found for rc 0/1 (else rc 2); supply them in a marked-historical form
            for a in ('The failure is tolerated by design', 'A `--dry-run` therefore reports success while having built nothing',
                      '|| build_warn "jekyll _site rebuild"'):
                if a not in txt:
                    txt += '\nNote: %s (historical).\n' % a
            return txt

        def case(name, text, want, suite=349, fname='CLAUDE.md', live_root_override=None):
            d = tempfile.mkdtemp(dir=scratch)
            with open(os.path.join(d, fname), 'w', encoding='utf-8') as fh:
                fh.write(text)
            rc, r = run_suite(suite, d, live_root_override or live_root, lockstep=False)
            (ok if rc == want else bad).append('%-62s rc %d (want %d)%s' % (
                name, rc, want, '' if rc == want else ' :: ' + ' | '.join((r.findings + r.undet)[:2])))

        # in the fixture the deploy anchors are always present and, if the live script lacks the warn step,
        # marked historical; control: all live-true figures -> rc 0
        base = need_deploy_anchors(claude())
        case('control: every figure equals its live value', base, 0)
        stale_t = '| The universal constitution (%s lines, %s `### §` anchors, %s bytes) measured. | `x` |' % (
            STALE_LINES, blob['anchors'], blob['bytes'])
        case('M1 stale constitution line count planted', need_deploy_anchors(claude(table=stale_t)), 1)
        case('M2 same stale figure, marker on the SAME clause',
             need_deploy_anchors(claude(table=stale_t.replace('measured.', 'measured, SUPERSEDED.'))), 0)
        case('M3 same stale figure, marker on a DIFFERENT clause of the same line',
             need_deploy_anchors(claude(table=stale_t.replace('measured.', 'measured. Another sentence is WITHDRAWN.'))), 1)
        case('M3b marker on the NEXT clause after a terminator',
             need_deploy_anchors(claude(table=stale_t.replace('measured. |', 'measured. This is withdrawn. |'))), 1)
        case('M3c real line-30 shape: marker word later in the SAME open parenthesis, other clause',
             need_deploy_anchors(claude(table=stale_t.replace('bytes) measured.', 'bytes, **re-measured**; the same blob as all four superseded pins) done.'))), 1)
        case('M4 marker inside a parenthesis about another figure',
             need_deploy_anchors(claude(gates='bash scripts/verify-check-registry.sh   # %s — 1 PASS/%s FAIL/%s DEBT '
                                              '(2026-09-06; 43/45 superseded)\n' % (reg['rc'], reg['FAIL'], reg['DEBT']))), 1)
        case('M4b pure tag "(historical)" after the stale figure covers its clause',
             need_deploy_anchors(claude(gates='bash scripts/verify-check-registry.sh   # %s — 1 PASS/%s FAIL/%s DEBT '
                                              '(historical)\n' % (reg['rc'], reg['FAIL'], reg['DEBT']))), 0)
        case('M5 trailing "# historical" after the stale gate figure',
             need_deploy_anchors(claude(gates='bash scripts/verify-check-registry.sh   # %s — 1 PASS/%s FAIL/%s DEBT   # historical\n'
                                              % (reg['rc'], reg['FAIL'], reg['DEBT']))), 0)
        case('M6 "2 HISTORICAL" verdict noun does not mask an unmeasured gate figure',
             need_deploy_anchors(claude(gates='bash scripts/verify-provider-ci.sh   # 1 — 1 CONFIRMED/6 UNVERIFIED/2 HISTORICAL\n')), 1)
        case('M6b unmeasured gate figure with a real marker is accepted',
             need_deploy_anchors(claude(gates='bash scripts/verify-provider-ci.sh   # 1 — 2 NOTE   # historical\n')), 0)
        case('M7 gate exit code `# 0 —` stated, live gate says otherwise',
             need_deploy_anchors(claude(gates='bash scripts/verify-manifest-pins.sh   # %d — %s MATCH/%s DRIFT/%s UNDET\n'
                                              % (1 - int(man['rc']), man['MATCH'], man['DRIFT'], man['UNDET']))), 1)
        case('M8 anchor removed -> cannot determine, never 0',
             need_deploy_anchors(claude().replace('`.gitmodules` declares **%s** gitlinks.' % n_decl, 'x')), 2)
        case('M9 live root unusable -> cannot determine', base, 2, live_root_override=scratch)
        case('M10 stale checked-out pin planted',
             need_deploy_anchors(claude()).replace('checked out at `%s`' % pin, 'checked out at `2887b42e9349`'), 1)
        case('M10b stale pin followed by a standalone "(historical)" tag after the terminator',
             need_deploy_anchors(claude()).replace('checked out at `%s`, on branch main.' % pin,
                                                   'checked out at `2887b42e9349`, on branch main. (historical)'), 0)

        # 351
        cont_rows = ('## §6 Gates\n\n| `bash scripts/verify-check-registry.sh` | **%s** — %s |\n\n'
                     'Of 12 owned gitlinks probed, %s declared.\n' % (reg['rc'], regfig.replace('/', ' / '), n_decl))
        ccase = lambda name, txt, want, **k: case(name, txt, want, suite=351, fname='CONTINUATION.md', **k)
        os.makedirs(os.path.join(scratch, 'x'), exist_ok=True)
        cont_ok = cont_rows.replace('Of 12 owned gitlinks probed, %s declared.' % n_decl,
                                    'Result: 12 owned gitlinks probed, %s declared.' % n_decl)
        # cross-ref needs a CLAUDE.md in the same root: build both files per case
        def case2(name, claude_txt, cont_txt, want):
            d = tempfile.mkdtemp(dir=scratch)
            with open(os.path.join(d, 'CLAUDE.md'), 'w', encoding='utf-8') as fh:
                fh.write(claude_txt)
            with open(os.path.join(d, 'CONTINUATION.md'), 'w', encoding='utf-8') as fh:
                fh.write(cont_txt)
            rc, r = run_suite(351, d, live_root, lockstep=False)
            (ok if rc == want else bad).append('%-62s rc %d (want %d)%s' % (
                name, rc, want, '' if rc == want else ' :: ' + ' | '.join((r.findings + r.undet)[:2])))

        decl_row = 'The probe reads 12 CURRENT of 12 owned gitlinks probed, %s declared.\n' % n_decl
        good_cont = ('## §6 Gates\n\n| `bash scripts/verify-check-registry.sh` | **%s** — %s |\n\n' % (reg['rc'], regfig.replace('/', ' / '))
                     + decl_row)
        cl_with = 'The old gate said 54 PASS / 5 FAIL and that is WITHDRAWN.\n'
        cl_without = 'Nothing relevant.\n'
        case2('351 control: live-true row, live declared count', cl_with, good_cont, 0)
        case2('351 M1 stale registry PASS count in a table row', cl_with,
              good_cont.replace(reg['PASS'] + ' PASS', '41 PASS'), 1)
        case2('351 M2 same, marker on the same clause', cl_with,
              good_cont.replace(reg['PASS'] + ' PASS', '41 PASS').replace(' |\n', ' (historical) |\n', 1), 0)
        case2('351 M3 same, marker on a different clause of the same row', cl_with,
              good_cont.replace(reg['PASS'] + ' PASS', '41 PASS').replace(' |\n', '. Elsewhere this is superseded. |\n', 1), 1)
        case2('351 M4 stale declared count', cl_with,
              good_cont.replace('%s declared' % n_decl, '13 declared'), 1)
        case2('351 M5 tuple withdrawn in CLAUDE.md restated unmarked', cl_with,
              good_cont + '\nBut --run-proofs exits 1 at 54 PASS / 5 FAIL here.\n', 1)
        case2('351 M5b same restated tuple but marked in its own clause', cl_with,
              good_cont + '\nBut --run-proofs exits 1 at 54 PASS / 5 FAIL here (withdrawn).\n', 0)
        case2('351 M5c tuple restated in a section 3 (historical log) is out of scope', cl_with,
              good_cont + '\n## §3 Active work\n\nBut --run-proofs exits 1 at 54 PASS / 5 FAIL here.\n', 0)
        case2('351 M6 restated tuple where CLAUDE.md never withdrew it -> not a cross-ref finding', cl_without,
              good_cont + '\nBut --run-proofs exits 1 at 54 PASS / 5 FAIL here.\n', 0)
    finally:
        if not keep:
            shutil.rmtree(scratch, ignore_errors=True)
    for l in ok:
        print('  ok   ' + l)
    for l in bad:
        print('  FAIL ' + l)
    print('prove-failure: %d ok, %d wrong%s' % (len(ok), len(bad), ' (scratch kept at %s)' % scratch if keep else ''))
    return 0 if not bad else 1


def toplevel():
    p = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True)
    if p.returncode != 0:
        raise Undet('not inside a git work tree')
    return p.stdout.strip()


def main_root():
    p = subprocess.run(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'], capture_output=True, text=True)
    if p.returncode != 0:
        raise Undet('git common dir unresolvable')
    d = p.stdout.strip()
    return os.path.dirname(d) if os.path.basename(d) == '.git' else toplevel()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--suite', type=int, choices=(349, 351))
    ap.add_argument('--root')
    ap.add_argument('--live-root')
    ap.add_argument('--no-lockstep', action='store_true')
    ap.add_argument('--prove-failure', action='store_true')
    a = ap.parse_args()
    try:
        live_root = a.live_root or main_root()
        if a.prove_failure:
            return prove(live_root)
        if not a.suite:
            ap.error('--suite required')
        root = a.root or toplevel()
    except Undet as e:
        print('UNDETERMINED:', e)
        return 2
    rc, r = run_suite(a.suite, root, live_root, lockstep=not a.no_lockstep)
    for f in r.findings:
        print(f)
    for u in r.undet:
        print('UNDET', u)
    print('SUMMARY suite=%d claims-evaluated=%d findings=%d undetermined=%d rc=%d' % (a.suite, r.n, len(r.findings), len(r.undet), rc))
    return rc


if __name__ == '__main__':
    sys.exit(main())
