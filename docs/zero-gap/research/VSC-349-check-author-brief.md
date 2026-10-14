# VSC-349 check-author brief (from fixer closer-fixer-b19; the fixer must NOT edit carrier_claims.py)

Text fixes landed in 8b63dad (all four carriers recomposed; lockstep loop from line 19 = 1). Live gate figures at
2026-10-14 (`bash scripts/verify-governance-cascade.sh`, rc 0): C1 = 22 declared: 20 owned, 1 governance source, 1 third-party; C2/C3 = 20 x 4 = 80.

## A. New CLAIMS rows for `docs/zero-gap/checks/probes/carrier_claims.py` (suite 349, file CLAUDE.md, clause-level)
1. id `remote-sync-probed`: anchor `probed \*\*(?P<n>\d+)\*\* owned gitlinks of (?P<m>\d+)` ; measure = live
   `scripts/verify-submodule-remote-sync.sh` "N owned gitlinks probed, M declared" (re-measure; gate under admission).
   Unmarked (no withdrawn/superseded/historical/obsolete in the SAME clause) and != live => finding.
   Regression: the pre-fix text put the only marker in a *different* clause after a reflow (de0e93c): this must be a finding.
2. id `c1-classified`: anchor `C1\*\* classifies \*\*(?P<owned>\d+) owned \+ (?P<src>\d+) governance source \+ (?P<tp>\d+) third-party\*\*`;
   live = the C1 PASS line of the cascade gate. Pre-fix text said 12/1/1 vs live 20/1/1.
3. id `c23-carriers`: anchor `(?P<a>\d+) × 4 = (?P<b>\d+)\*\* owned-submodule carriers`; live = C2 line (20 x 4 = 80). Pre-fix 12 x 4 = 48.
4. id `staged-not-committed`: anchor `STAGED and not yet committed` must carry a marker in its clause (no live value exists).

## B. Selftest cases (extend `--prove-failure`)
- mutate each of rows 1-3 to a stale figure with the marker in a different clause => caught (rc 1).
- same stale figure with `historical`/`superseded` in the SAME clause => passes (control).
- row 4 unmarked => caught; marked => pass.

## C. Probe defect: uncaught exception returns rc 1
`main()` calls `run_suite(...)` outside the `try`; any other exception (KeyError, re.error, UnicodeDecodeError, json error)
escapes as a Python traceback with exit code 1, indistinguishable from "a stale claim found". Required: wrap the
whole of main() (including run_suite and prove) so any non-Undet exception prints `UNDETERMINED: unexpected <type>: <msg>`
and returns 2 (2 is never a pass, never a finding). Selftest: inject a failing measure (monkeypatched exception) and
assert rc == 2, not 1.
