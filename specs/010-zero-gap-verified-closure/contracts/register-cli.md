# Contract: register CLI (`_tools/workable-items`, `gap` subcommands)

Umbrella add-on Go tool (`workable-items-vsc`). Existing subcommands stay unchanged:
`roster, seed-roster, backfill, provenance, validate, report`. New subcommands are additive.
Exit codes everywhere: **0** condition holds, **1** condition violated, **2** could not determine
(never a pass). Flags common to all: `--repo <root>`, `--db <path>` (default `docs/workable_items.db`).

| Command | Purpose | Key flags | Exit |
|---|---|---|---|
| `gap migrate` | additive schema migration (idempotent; `--dry-run` prints DDL) | `--dry-run` | 0 ok / 2 cannot open DB |
| `gap add` | open an item from a sweep finding | `--type --severity --category --title --description --closure-criteria --sweep-class --measurable-target` | 0 / 1 invalid |
| `gap adopt` (T090+, fix-adopt) | back-fill an EXISTING non-gap item's 14 gap columns in place, via UPDATE (never INSERT) — the mirror of `gap add`; see the dedicated amendment below | `--id --kind --severity --category --title --root-cause --proposed-fix --closure-criteria [--anchor --owner --evidence --plan-due --measurable-target --disposition open\|classified --classification-reason --classification-owner --classification-recheck --block-what --block-why --block-options --block-who --as-of]` | 0 / 1 invalid or already a gap item or adopted concurrently / 2 environment fault |
| `gap classify` | set disposition=classified | `--id --reason --owner --recheck` | 1 unless reason ∈ the four |
| `gap close` | attempt closure | `--id --red-evidence --green-evidence --verdict-ref` | 1 unless every FR-007/018/022 precondition holds |
| `gap reopen` | reopen with failing evidence | `--id --evidence` | 0; increments `reopens_count` |
| `gap link` | set `recurrence_of` | `--id --of` | 1 on cycle / unresolved id |
| `gap apply-queue` | apply queued reopen requests from `.remember/logs/zero-gap/reopen-queue.jsonl` (run inside an explicit commit) | `--queue --as-of` | 0 |
| `gap freeze` | freeze a cycle | `--cycle` | 0 writes freeze.json; 2 if tree unstable |
| `gap summary` | derived counts + per-class recall | `--json` | 0 |
| `report --by-module` (T037) | per-module Markdown page (FR-024, SC-010): one section per roster module (sorted by prefix), gap items grouped open / classified / closed with status, disposition, severity, kind, category, evidence and verdicts; every finding of the `validate` rule set (base rules + V-G1..V-G12) named; items the base rules report `id/prefix-not-in-roster` / `id/malformed` listed under "Unplaced items"; no timestamps | `--as-of <date>` (default today UTC, printed on stderr) | 0 page + no finding / 1 page + named finding(s) / 2 no page when the register cannot be read (absent, unreadable, non-SQLite, unmigrated, partial schema, non-empty `-wal` or any `-journal` beside the symlink-resolved file, changed while read, unreadable roster, bad `--as-of`), page printed when a rule row is undetermined, or the page cannot be written |
| `validate` (extended) | adds rules V-G1..V-G9 below | — | 0/1/2 |

Validator rules (each has a Go test RED-first and a mutation). Every date rule is evaluated against an
explicit `--as-of <date>` (default: the run's recorded date, stored in the evidence record), so an
unchanged state gives the same verdict on every repeat (SC-006). **V-G1** every gap item has
type+status+id+kind+category+severity(closed set)+owner+location(`forensic_anchor`)+an evidence reference;
**V-G10** every `open` item has a `plan_due` date; **V-G12** every `item_verdicts.item_id` resolves to an existing item; **V-G11** every `Operator-blocked` item lists unblock options and the cost of each in `operator_block_details`; **V-G2** `classified` ⇒ reason ∈ 4 + owner + `recheck` not elapsed at `--as-of`; **V-G3** `closed` ⇒ RED+GREEN evidence for the same check id + independent verdict (`item_verdicts`)
from a different actor + review verdict + the closure check authored by someone other than the fixer
(§11.4.240(C)(1)) + `research_ref` (§11.4.150); **V-G4** `kind='improvement'` ⇒ non-empty `measurable_target`;
**V-G5** `recurrence_of` acyclic, resolves to a head; **V-G6** no item-set change in a frozen cycle;
**V-G7** no `accepted-as-is`/unknown disposition; **V-G8** roster: every declared submodule has an
identifier (closes the G4 finding); **V-G9** no closed item whose latest evidence outcome ≠ 0.

Output (`gap summary --json`) is derived from rows and is byte-stable for an unchanged DB.

## Amendments accepted after the T009 review (2026-09-25)

- **New subcommand `gap verdict`** — the only writer of `item_verdicts`:
  `gap verdict --id --role verifier|reviewer --actor --actor-kind agent|script --outcome 0|1|2 --evidence <path> --on <date>`.
  A `verifier` verdict's evidence is PARSED as a sidecar EvidenceRecord (same item_id, the GREEN check id, outcome 0,
  `verdict_role=verifier`, ts ≥ GREEN); a `reviewer` verdict's evidence must be a non-empty REGULAR file.
- **Extra flags** on `add`, `classify`, `close`, `reopen`, `apply-queue`, `freeze` exist so an item can satisfy V-G1/V-G10 when written;
  `--verdict-ref` on `close` is the evidence path of the verifier's verdict row. `validate` takes `--as-of <date>` (UTC everywhere;
  the date used is printed).
- **Rules** are V-G1..V-G12 (not V-G1..V-G9). Only evidence and verdict rows NEWER than the latest `Reopened` row count toward V-G3.
- **Exit codes**: `reopen` and `apply-queue` exit 1 (invalid request) or 2; `freeze` exits 1 on a membership change; `link` exits 1 to a CLOSED
  head (it would commit a state the validator rejects); every command exits 2 when the DB is unmigrated, read-only or locked (never 1).
- **`item_verdicts`** columns are all NOT NULL (stricter than the first data-model draft).
- **Ordering constraint**: do NOT migrate the LIVE `docs/workable_items.db` before T047. Migrating flips `scripts/verify-workable-items.sh` G5
  from rc 2 to rc 1 (8 V-G8 roster findings) and its `--prove-failure` control (which copies the live DB and expects rc 0) cannot pass until the
  roster gap is closed. T047 closes it, and G5 must then pass `--as-of`.
- **Upstream defect (report, do not patch)**: the canonical tool's `close` wipes all 14 gap columns and skips closure checks. Mitigated on our side
  (any item whose history has a `zero-gap:` row stays in scope; a 'closed outside gap close' finding). Whether canonical `sync`/`move` also wipe
  the columns is UNCONFIRMED.

## Amendment: `report --by-module` (T037, 2026-09-26; fix round after review rev-t037)

- Read-only on the register: its path is resolved through symlinks, it is read twice with plain file
  reads (sha256 compared) and copied into a private temporary directory that is removed on return and
  on SIGINT/SIGTERM. Only the copy is opened by SQLite — first the way `validate` opens a register (so
  the umbrella extension tables exist exactly as `validate` would see them), then `mode=ro&immutable=1`.
- The finding set equals `validate`'s on the same register (tested on the golden-bad register and on a
  register missing a provenance row); the page has no rule of its own.
- Register text is rendered on one line and HTML-escaped; a malformed identifier is shown quoted
  (`strconv.Quote`) in a code span; titles are truncated to 200 characters; `|` is escaped in table cells.

## Amendment: `gap adopt` (impl-adopt, T090+; concurrency-hardened by fix-adopt, 2026-09-26)

`gap adopt` back-fills the 14 zero-gap columns onto an EXISTING item that predates them (typically a
legacy row migrated by `gap migrate`), so it becomes an ordinary gap item without minting a new id or
touching `atm_id`/`type`/`status`/`current_location`. It is the mirror image of `gap add`: `add`
INSERTs a new row; `adopt` UPDATEs one in place.

```
gap adopt --id <existing-id> --kind <...> --severity <...> --category <...> --title <...>
    --root-cause <...> --proposed-fix <...> --closure-criteria <...>
    [--anchor <...>] [--owner <handle>] [--evidence <path>] [--plan-due YYYY-MM-DD]
    [--measurable-target <...>] [--disposition open|classified] [--classification-reason ...]
    [--classification-owner ...] [--classification-recheck YYYY-MM-DD]
    [--block-what ...] [--block-why ...] [--block-options ...] [--block-who ...]
    [--as-of YYYY-MM-DD]
```

Flags:

| Flag | Meaning |
|---|---|
| `--id` | the existing item's `atm_id`; must exist and must NOT already be a gap item |
| `--kind` | one of `GapKinds` (`defect \| unfinished-promise \| weak-spot \| danger-zone \| improvement`) |
| `--severity` | one of `GapSeverities` (closed set, see the severity rubric above) |
| `--category` | root-cause category, research D4 closed set |
| `--title` | one-line title; overwrites `items.title` |
| `--root-cause` | root-cause narrative; folded into `items.description` together with `--proposed-fix` |
| `--proposed-fix` | proposed-fix narrative; the two together must clear the §11.4.91 floor (≥6 words or ≥40 chars) |
| `--closure-criteria` | what must be true to close it; default keeps the item's existing value when omitted |
| `--anchor` | `forensic_anchor`; default keeps the item's existing value |
| `--owner` | `assigned_to`; default keeps the item's existing value — added beyond the flag list originally dispatched because V-G1 requires a non-empty owner and legacy rows carry none |
| `--evidence` | repository-relative path of the evidence supporting the adoption |
| `--plan-due` | dated plan `YYYY-MM-DD`; required by V-G10 when `--disposition=open` |
| `--measurable-target` | required when `--kind=improvement` (V-G4/FR-025) |
| `--disposition` | `open` (default) \| `classified`; **adopt never closes an item** — `--disposition closed` is refused |
| `--classification-reason`, `--classification-owner`, `--classification-recheck` | required iff `--disposition=classified` |
| `--block-what`, `--block-why`, `--block-options`, `--block-who` | operator-reason detail, required when the classification reason is `operator-decision`/`operator-action` (FR-009); `--block-who` defaults to `--classification-owner` |
| `--as-of` | the date rules use; default today |

Behaviour and refusals:

- **One-time.** An item already carrying any gap column, or any `zero-gap:` history row (the same
  `gapPredicate` `report --by-module` and `validate` use), is refused: `"<id> is already a gap item;
  adopt is one-time — use classify/verdict/close to change it"`. Re-adopting requires `classify` /
  `verdict` / `close` instead.
- **Status untouched, disposition must already agree with it.** `adopt` never writes `status`. The
  requested `--disposition` is checked up front against the item's CURRENT status: `open` needs an
  open status; `classified` under an operator reason needs `Operator-blocked`; `classified` under a
  non-operator reason needs the exact status `Queued`. A mismatch is refused before any write, with the
  same wording V-G7 would use after the fact.
- **Isolation.** The write is a single `UPDATE ... WHERE atm_id=? AND current_location=?`, so no other
  row's columns are touched; `item_provenance` uses `INSERT OR IGNORE`, so pre-existing provenance is
  preserved rather than overwritten, and an item with none gets a row naming `gap adopt` as its source.
- **Atomicity.** The whole write (items UPDATE, optional `operator_block_details`, provenance,
  `item_history`, `ValidateGap` re-check) runs inside one transaction; any failure at any point —
  including a validator finding the write itself introduces — rolls back the entire transaction, never
  a partial write.
- **Concurrency (§11.4.253, fix-adopt, 2026-09-26).** The one-time refusal above is read via `loadItem`
  BEFORE the write transaction opens (a TOCTOU window in principle), so the UPDATE itself carries its
  own DB-level guard: `... WHERE atm_id=? AND current_location=? AND kind IS NULL`. `kind` is one of
  the 14 additive gap columns (see `GapItem` above) that `gapAdopt` is the only writer of, and every
  item this command's own refusal check accepted has `kind IS NULL` at that instant — so the guard
  matches only for as long as no transaction (this one or a concurrent one) has yet committed a
  non-NULL `kind` for the id. When two `gap adopt` calls race the same id, the first to commit wins;
  the UPDATE of the one that loses the race touches 0 rows (`RowsAffected()==0`), and that call rolls
  back and refuses with `"<id> was adopted concurrently by another process between this command's
  check and its write (kind is no longer NULL); nothing was written — re-run to see its current
  state"` — never a silent no-op and never a partial apply. Exactly one `zero-gap:adopted`
  `item_history` row results from any number of racing callers on the same id. Proven by
  `TestGapAdoptRaceRefusesConcurrentDoubleAdopt` (goroutines + a transaction-ordering hook) and,
  independently, by two real OS processes racing the compiled binary (see that test's comment for the
  exact recipe).
