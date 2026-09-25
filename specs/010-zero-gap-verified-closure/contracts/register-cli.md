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
| `validate` (extended) | adds rules V-G1..V-G9 below | — | 0/1/2 |

Validator rules (each has a Go test RED-first and a mutation). Every date rule is evaluated against an
explicit `--as-of <date>` (default: the run's recorded date, stored in the evidence record), so an
unchanged state gives the same verdict on every repeat (SC-006). **V-G1** every gap item has
type+status+id+kind+category+severity(closed set)+owner+location(`forensic_anchor`)+an evidence reference;
**V-G10** every `open` item has a `plan_due` date; **V-G11** every `Operator-blocked` item lists unblock options and the cost of each in `operator_block_details`; **V-G2** `classified` ⇒ reason ∈ 4 + owner + `recheck` not elapsed at `--as-of`; **V-G3** `closed` ⇒ RED+GREEN evidence for the same check id + independent verdict (`item_verdicts`)
from a different actor + review verdict + the closure check authored by someone other than the fixer
(§11.4.240(C)(1)) + `research_ref` (§11.4.150); **V-G4** `kind='improvement'` ⇒ non-empty `measurable_target`;
**V-G5** `recurrence_of` acyclic, resolves to a head; **V-G6** no item-set change in a frozen cycle;
**V-G7** no `accepted-as-is`/unknown disposition; **V-G8** roster: every declared submodule has an
identifier (closes the G4 finding); **V-G9** no closed item whose latest evidence outcome ≠ 0.

Output (`gap summary --json`) is derived from rows and is byte-stable for an unchanged DB.
