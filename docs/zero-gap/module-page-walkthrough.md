# Per-module page — one timed walk-through (SC-010)

| Field | Value |
|---|---|
| Feature | 010 zero-gap verified closure (task T037; FR-024, SC-010) |
| Command | `workable-items-vsc report --by-module [--repo <root>] [--db <register>] [--as-of <YYYY-MM-DD>]` |
| Code | `_tools/workable-items/internal/wi/modulereport.go`, dispatched by `report` in `_tools/workable-items/main.go` |
| Golden page | `_tests/fixtures/zero-gap/registers/module-page-golden-good.md` |
| Golden-bad register | `_tests/fixtures/zero-gap/registers/golden-bad/module-page.sql` |
| Revision | 2 — 2026-09-26 (fix round after review rev-t037: full `validate` rule set, symlink-resolved -wal/-journal refusal, safe rendering; exit-code section corrected; walk-through re-measured) |

## Contents

1. [What SC-010 asks](#what-sc-010-asks)
2. [Why a fixture register](#why-a-fixture-register)
3. [The walk-through](#the-walk-through)
4. [Result](#result)
5. [Exit codes](#exit-codes)
6. [What this does not claim](#what-this-does-not-claim)

## What SC-010 asks

SC-010: an operator can open one place and, **within two minutes**, answer for any module "what is
open, what is closed and how do I know" without reading source or asking an author. The page answers
that with one section per roster module (`## <PREFIX> — <path> (<class>)`), split into `### Open`,
`### Classified` and `### Closed`; each item lists status, disposition, severity, kind, category,
location, plan or classification, its evidence paths and its verifier/reviewer verdicts, and the
register problems found on it by the same rule set `validate` runs (the base rules plus V-G1..V-G12;
the page has no rule of its own). Register text is rendered on one line and HTML-escaped; titles are
truncated to 200 characters.

## Why a fixture register

The live register `docs/workable_items.db` is **unmigrated** (no zero-gap schema) until task T047, by
ruling. `report --by-module` on it exits **2** and prints no page, measured 2026-09-26:

```
COULD NOT DETERMINE: …/docs/workable_items.db: the register carries no zero-gap schema — run `gap migrate` first (…)
COULD NOT DETERMINE — no page was produced. A 2 is never a pass.
```

The live file's sha256 prefix was `9413fd96f2647c63` before and after that run: the report reads the
register with plain file reads, copies it into a private temporary directory (removed on return and
on SIGINT/SIGTERM) and opens only the copy.

The walk-through therefore uses the **golden-good fixture register** (six gap items, all in module
VSC), rendered against the **live roster** of this repository, so the page has the real number of
module sections (15).

## The walk-through

Build the fixture register in a scratch directory (`$SCRATCH`), then render and query it from the
repository root:

```bash
FX=_tests/fixtures/zero-gap/registers
( cd _tools/workable-items && go build -o "$SCRATCH/wi" . )
sqlite3 "$SCRATCH/good.db" < "$FX/canonical-schema.sql"
"$SCRATCH/wi" gap migrate --db "$SCRATCH/good.db"
sqlite3 "$SCRATCH/good.db" < "$FX/golden-good.sql"

t0=$(date +%s%N)
"$SCRATCH/wi" report --by-module --db "$SCRATCH/good.db" --as-of 2026-09-25 > "$SCRATCH/walk.md"
t1=$(date +%s%N)
start=$(grep -n '^## VSC — ' "$SCRATCH/walk.md" | cut -d: -f1)                 # jump to the module
end=$(awk -v s="$start" 'NR>s && /^## /{print NR; exit}' "$SCRATCH/walk.md")
sed -n "${start},$((end-1))p" "$SCRATCH/walk.md" > "$SCRATCH/vsc-section.md"
sed -n '/^### Open/,/^### Classified/p' "$SCRATCH/vsc-section.md" | grep '^#### '   # every open gap
t2=$(date +%s%N)
```

How it was measured: wall-clock nanoseconds from `date +%s%N` around the two steps (render; locate the
module section and list its open items), on this development host.

## Result

Measured 2026-09-26 (re-measured after the fix round):

| Quantity | Value |
|---|---|
| exit code | 1 (see below) |
| render time | 26 ms |
| locate-and-list time | 33 ms |
| whole page | 211 lines, 1,502 words, 9,901 bytes, 17 `## ` sections (Modules, Register problems, 15 modules); exactly one `## VSC — ` heading |
| VSC section | 77 lines, 482 words: 3 open, 2 classified, 1 closed item |
| open items found | VSC-001, VSC-006, VSC-005 — the three `disposition=open` rows of the register, nothing else |

The exit code is **1**, not 0, and that is a true statement about the live roster, not about the
fixture: V-G8 names 8 submodules declared in `.gitmodules` that carry no identifier in
`docs/workable-items/sub-projects.tsv` (the roster gap task T047 closes). Every one is listed on the
page under "Register problems", and the base rules add one could-not-determine row for the same 8
submodules (the finding outranks it, so the exit is 1). Against the fixture roster (VSC + WSP) the same
register renders the golden page with exit 0.

## Exit codes

- **0** — the page was produced and the register carries no finding.
- **1** — the page was produced and names at least one finding of the `validate` rule set. An item
  the base rules report as `id/prefix-not-in-roster` or `id/malformed` is listed under "Unplaced
  items", never dropped; legacy items under prefixes outside the roster are counted there.
- **2** — could not determine; a 2 is never a pass. Two shapes:
  - **no page**, reason on stderr, when the register could not be read: absent, unreadable,
    non-regular or non-SQLite register; unmigrated or partially migrated register; a non-empty `-wal`
    or any `-journal` beside the register (checked beside the symlink-resolved file and the given
    path); the register changed while it was being read (read twice, sha256 compared); an unreadable
    roster; a bad `--as-of`;
  - **the page IS printed** when the register was read but a rule reports an undetermined row (for
    example an evidence path that cannot be checked); the row is listed under "Register problems".
  - A page that cannot be written to stdout is also a 2.

## What this does not claim

- **The timing is an agent's scripted lookup, not a person reading the page.** It shows the answer is
  one section of 77 lines reachable by one heading search; whether a person reads it inside two
  minutes was **not measured** here. That human timing is `PENDING` an operator walk-through.
- The fixture holds six items in one module. A migrated live register (after T047) will have more
  items per section; the page size then has to be re-measured, not quoted from here.
- `closed` on the page carries the same limit as `gap summary`: structurally consistent plus
  self-recorded digests, not independently proven until the T068 chain binding.
