# Contract: register CLI (`_tools/workable-items`, `gap` subcommands)

Umbrella add-on Go tool (`workable-items-vsc`). Existing subcommands stay unchanged:
`roster, seed-roster, backfill, provenance, validate, report`. New subcommands are additive.
Exit codes everywhere: **0** condition holds, **1** condition violated, **2** could not determine
(never a pass). Flags common to all: `--repo <root>`, `--db <path>` (default `docs/workable_items.db`).

| Command | Purpose | Key flags | Exit |
|---|---|---|---|
| `gap migrate` | additive schema migration (idempotent; `--dry-run` prints DDL) | `--dry-run` | 0 ok / 2 cannot open DB |
| `gap add` | open an item from a sweep finding | `--type --severity --category --title --description --closure-criteria --sweep-class --measurable-target` | 0 / 1 invalid |
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
