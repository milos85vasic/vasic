#!/usr/bin/env python3
"""VSC-359 negative check (round 2, author: closer-fixer-b13): present-tense pin wording in the root carriers.

A clause of CLAUDE.md / AGENTS.md / QWEN.md / GEMINI.md that states a pin in the PRESENT tense must name the live
index gitlink, or carry its OWN withdrawn / superseded / historical / obsolete marker (carrier_claims.Clause.covers:
a marker on a neighbouring clause does not count; a marker inside a parenthesis covers only that parenthesis).
Rules, per clause:
  P1  "currently|now (checked out) at|on `<hex 7-40>`"          -> <hex> must be a prefix of a live gitlink of the
                                                                  five narrated modules, else FINDING.
  P2  "current pin ... `<hex 7-40>`" (within 60 chars)           -> same.
  P3  the words "current pin" with no live gitlink hash in the   -> FINDING (drop "current pin" wording for the
      clause                                                       re-derive command `git ls-files -s <path>`).
Recall cost, stated: a present-tense pin phrased another way ("the pin is `abc...`", "HEAD sits at ...") is NOT
detected; only the three shapes above are.  Companion check VSC-359.probe.sh still requires every live gitlink to be
quoted in all four carriers.
Exit 0 holds / 1 a finding / 2 cannot determine (never a pass).  `--selftest` runs the mutation self-test.
"""
import sys
sys.dont_write_bytecode = True
import os
import re
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import carrier_claims as cc  # noqa: E402

MODULES = ['submodules/constitution', 'design-toolkit', 'submodules/containers', 'submodules/curriculum-kit', 'workshop']
FILES = ['CLAUDE.md', 'AGENTS.md', 'QWEN.md', 'GEMINI.md']
P1 = re.compile(r'(?:currently|now)\s+(?:checked\s+out\s+)?(?:at|on)\s+`([0-9a-f]{7,40})')
P2 = re.compile(r'current\s+pin[^`]{0,60}`([0-9a-f]{7,40})')
P3 = re.compile(r'current\s+pin', re.I)
HEXTOK = re.compile(r'`([0-9a-f]{7,40})')


class Undet(Exception):
    pass


def live_pins(root):
    out = []
    for m in MODULES:
        p = subprocess.run(['git', 'ls-files', '-s', '--', m], cwd=root, capture_output=True, text=True)
        f = p.stdout.split()
        if p.returncode != 0 or len(f) < 2 or not re.fullmatch(r'[0-9a-f]{40}', f[1]):
            raise Undet('no gitlink for %s in %s' % (m, root))
        out.append(f[1])
    return out


def is_live(h, live):
    return any(l.startswith(h) for l in live)


def scan_file(path, live, label):
    fnd = []
    for u in cc.units_of(path):
        for c in u.clauses:
            t = c.text
            hits = []
            for rx, rule in ((P1, 'P1'), (P2, 'P2')):
                for m in rx.finditer(t):
                    if not is_live(m.group(1), live) and not c.covers(m.start(1), m.end(1)):
                        hits.append((rule, m.group(1), m.start()))
            has_live = any(is_live(m.group(1), live) for m in HEXTOK.finditer(t))
            for m in P3.finditer(t):
                if not has_live and not c.covers(m.start(), m.end()):
                    hits.append(('P3', 'current pin', m.start()))
            for rule, tok, off in hits:
                fnd.append('FINDING pin-wording %s:%d %s %s :: %s' % (label, c.line_of(off), rule, tok,
                                                                    re.sub(r'\s+', ' ', t.strip())[:110]))
    return fnd


def run(root):
    live = live_pins(root)
    fnd, n = [], 0
    for f in FILES:
        p = os.path.join(root, f)
        if not os.path.isfile(p):
            raise Undet('%s missing' % f)
        n += 1
        fnd += scan_file(p, live, f)
    return fnd, n


def selftest():
    live = ['a71b1767b40229c8e88140924352fbe990b3049e'] + ['%040x' % (i + 1) for i in range(4)]
    cases = [  # (name, text, expected findings)
        ('control-live-hash', '`submodules/constitution` is currently checked out at `a71b1767b402`, on branch main.', 0),
        ('mutation-stale-hash', '`submodules/constitution` is currently checked out at `2887b42e9349`, on branch main.', 1),
        ('mutation-stale-40hex', 'It is now at `2887b42e9349c3d8a1b1d2e3f4a5b6c7d8e9f001`, on main.', 1),
        ('own-clause-marker-covers', 'Historical reading, superseded: it is currently checked out at `2887b42e9349`, on main.', 0),
        ('neighbour-marker-does-not-cover', 'That reading is historical. It is currently checked out at `2887b42e9349`, on main.', 1),
        ('marker-in-paren-covers-only-paren', 'It is currently checked out at `2887b42e9349` (historical, a stale reading), on main.', 1),
        ('bare-current-pin', 'The fix landed two commits before the current pin, so we consumed it.', 1),
        ('current-pin-with-live-hash', 'The current pin `a71b1767b402` is the index gitlink.', 0),
        ('current-pin-stale-hash', 'The current pin `2887b42e9349` is the index gitlink.', 1),
        ('current-pin-with-marker', 'The reading of the current pin is superseded and historical.', 0),
        ('dated-live-pin-phrase', 'Re-derive the live pin with `git ls-files -s submodules/containers`.', 0),
    ]
    fail = 0
    d = tempfile.mkdtemp(prefix='pinw-')
    for name, text, want in cases:
        p = os.path.join(d, 'c.md')
        with open(p, 'w', encoding='utf-8') as fh:
            fh.write(text + '\n')
        got = len(scan_file(p, live, 'c.md'))
        ok = (got > 0) == (want > 0)
        print('%s %s (want %d finding(s), got %d)' % ('ok  ' if ok else 'FAIL', name, want, got))
        fail += 0 if ok else 1
    os.unlink(os.path.join(d, 'c.md'))
    os.rmdir(d)
    print('selftest: %d case(s), %d failure(s)' % (len(cases), fail))
    return 1 if fail else 0


def main():
    a = sys.argv[1:]
    if a[:1] == ['--selftest']:
        return selftest()
    root = a[a.index('--root') + 1] if '--root' in a else subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True).stdout.strip()
    try:
        fnd, n = run(root)
    except (Undet, OSError) as e:
        print('UNDETERMINED %s' % e)
        return 2
    for x in fnd:
        print(x)
    print('SUMMARY pin-wording files=%d findings=%d rc=%d' % (n, len(fnd), 1 if fnd else 0))
    return 1 if fnd else 0


if __name__ == '__main__':
    sys.exit(main())
