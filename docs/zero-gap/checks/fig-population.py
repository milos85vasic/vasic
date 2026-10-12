#!/usr/bin/env python3 -I
"""Independent oracle for VSC-349 / VSC-351 (producer != oracle): lists recorded-figure lines that carry no
line-level historical marker, mirroring the documented shapes of scripts/zero-gap-class-stale-figures.sh
(<n> <unit>, <n> of <n>, <n>/<n>, exit/rc N) and its skip words.  usage: fig-population.py <file> [--outside-s3]
Exit 0 none / 1 some (printed) / 2 unreadable."""
import re,sys
MK=r'[*`_]*'; NUM=r'[0-9][0-9,]*'
RC=r'\b(?:exit(?:s|ed)?|rc)'+MK+r'(?:\s+|\s*=\s*)'+MK+r'[0-9]+\b'
SH=[re.compile(r'\b'+NUM+MK+r'\s+'+MK+r'(?:files?|tests?|gates?|scripts?|anchors?|lines?|commits?|items?|rows?|checks?|submodules?|bytes?|PASS|FAIL|CURRENT|DRIFT)\b'),
    re.compile(r'\b'+NUM+MK+r'\s+of\s+'+MK+NUM+r'\b'), re.compile(r'\b[0-9]+/[0-9]+\b'), re.compile(RC,re.I)]
SK=re.compile(r'\b(?:withdrawn|superseded|historical|obsolete)\b',re.I); ST=re.compile(r'~~.*?~~')
try: ls=open(sys.argv[1],encoding='utf-8').read().split('\n')
except Exception as e: print('unreadable',e); sys.exit(2)
outside='--outside-s3' in sys.argv
cur=''; hits=[]
for i,l in enumerate(ls,1):
    if l.startswith('## '): cur=l
    if outside and '§3' in cur: continue
    t=ST.sub('',l)
    if SK.search(t): continue
    if any(s.search(t) for s in SH): hits.append((i,l[:110]))
for h in hits[:12]: print('%d: %s'%h)
print('unmarked figure lines: %d'%len(hits))
sys.exit(1 if hits else 0)
