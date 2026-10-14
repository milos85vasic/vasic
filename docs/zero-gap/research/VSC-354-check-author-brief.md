# VSC-354 check-author brief (from fixer closer-fixer-b19; the fixer must NOT edit VSC-354.probe.sh)

Text fixes landed in a3271d2 (INVENTORY.md: pinned commit and describe rows dated; `| Constitution.md | 11101 |` cell marked;
"An eighth directory" and "the other five" clauses marked). Probe currently passes on the fixed text.

## Required probe extensions (docs/zero-gap/checks/VSC-354.probe.sh)
1. Comma-less form: add `11101 lines` and a table-cell form `| Constitution.md | 11101 |` (regex `\|\s*Constitution\.md\s*\|\s*11,?101\b`)
   to the REQUIRED/OPTIONAL patterns; each occurrence needs a marker on its line.
2. Pin and describe: `448981ae3498` (any length >= 7 prefix of 448981ae...) and `v1\.0\.0-51-g448981a` occurrences each need a line marker.
3. Derived counts: `An eighth directory` / `eighth directory` and `the other five` each need a line marker.
4. Loud skip: when the class step is skipped because `submodules/constitution` is not checked out (worktree), print a line
   `CLASS STEP SKIPPED: submodules/constitution not checked out - doc-count-drift class NOT run` to stdout AND stderr, and the
   probe must not report a plain "holds" for that part: exit 2 under `--strict` / in the closure `.check` (cannot determine), never silent 0.
## Selftest cases (--selftest, mutated copies of INVENTORY.md; each must be caught, control must pass)
- extra unmarked `11101 lines`; extra unmarked table row `| Constitution.md | 11101 |`; extra unmarked `448981ae3498`;
  extra unmarked `v1.0.0-51-g448981a`; extra unmarked `An eighth directory`; extra unmarked `the other five`.
- the same strings with `historical` on the line => pass.
- run in a tree with the submodule dir emptied => must print the CLASS STEP SKIPPED line and exit 2.
