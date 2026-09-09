# Workable items — the procedure

| | |
|---|---|
| **Document** | `docs/workable-items/PROCEDURE.md` |
| **Revision** | 1 |
| **Created** | 2026-09-08 |
| **Anchors** | §11.4.93, §11.4.95, §11.4.54, §11.4.15, §11.4.16, §11.4.33, §11.4.90, §11.4.148, §11.4.63, §11.4.208 |
| **Status of this document** | The single source of truth for HOW work is tracked here (§11.4.63). Where it disagrees with `submodules/constitution/Constitution.md`, the constitution wins. |

## What exists, and where

| Artefact | Path | Authored by |
|---|---|---|
| The database — the single source of truth | `docs/workable_items.db` | the canonical binary (schema) + the umbrella tool (rows) |
| The identifier roster | `docs/workable-items/sub-projects.tsv` | the operator (five names) + this agent (ten proposals) |
| The canonical tracker binary | `submodules/constitution/scripts/workable-items/bin/workable-items-linux` | upstream, consumed |
| The umbrella-local tool | `_tools/workable-items/` | this repository |
| The gate | `scripts/verify-workable-items.sh` | this repository |

## Why there are two binaries and not one

§11.4.93 places the tracker upstream and says so in terms:

> "The Go binary lives in the constitution submodule
> (`constitution/scripts/workable-items/`) so consumers reference it from there
> per §11.4.74 catalogue-first discipline — **never reimplement**."

That binary is present, builds nothing here, and runs on this host. It owns the
schema and every lifecycle mutation: `add`, `update`, `reopen`, `move`, `block`,
`close`, `obsolete-details`, `report`, `diary`, `export`, `sync db-to-md`,
`sync md-to-db`, `diff`, `validate`. **Use it for all of those.** Writing a
second one would be the reimplementation the anchor forbids.

The umbrella tool exists for the two things the canonical binary does not do,
and could not: this monorepo has FIFTEEN identifier-bearing sub-projects while
the canonical tool derives exactly ONE three-letter key from the project root
directory name (`cmd/workable-items/prefix.go`), and this repository's backfill
sources are its own.

The split is also deliberate on evidence grounds (§11.4.240, producer ≠
verifier): the rows are written by the tool this repository authors and checked
by the binary it does not. That is not decorative. During the adoption work the
upstream validator caught two real defects the umbrella validator was not
looking for — items with no `doc_segments` row, which `db-to-md` would have
silently dropped, and closure `evidence_path` values that were well-formed but
resolved to nothing on disk.

## The identifier scheme

`<THREE UPPERCASE LETTERS>-<zero-padded number>`, e.g. `WSP-142`.

§11.4.54 names `ATM-NNN`. §11.4.148 then makes the prefix consumer-supplied, in
terms: *"the consuming project supplies its concrete DB path, **id prefix**,
external-tracker service + list/board id + field map + default-assignee env var,
and docs_chain context per §11.4.35."* The three-letter shape is also what the
canonical tracker's own heading grammar requires (`^## [A-Z]{3}-…`). So the
operator's `VSC` / `WSP` / `AII` / `MVR` / `VDT` scheme is an instance of the
mandate, not a deviation from it — no override is needed and none is claimed.

**The FLEET is derived; the NAMES are not.** The set of sub-projects comes from
`.gitmodules` cross-checked against `helix-deps.yaml` at run time. The roster
file supplies only the name for each derived member, because a name is an
operator decision and cannot be measured. A submodule with no roster row makes
the gate report **rc 2 — could not determine**, never a pass, so a new submodule
cannot be silently dropped out of tracking.

Five names were stated by the operator. **Ten are PROPOSALS awaiting
ratification** and are marked `proposed` in the roster file; `workable-items-vsc
roster` prints the split on every run so a proposal is never mistaken for a
decision.

## Day-to-day

```bash
# What is open, and where
submodules/constitution/scripts/workable-items/bin/workable-items-linux \
    report --db docs/workable_items.db --by-status

# Open a new item (the canonical binary owns every mutation)
submodules/constitution/scripts/workable-items/bin/workable-items-linux \
    add Task medium --db docs/workable_items.db --prefix WSP \
    --title "<what>" --description "<WHAT / manifests / repro / acceptance>"

# Close one — evidence is mandatory and the path must RESOLVE
submodules/constitution/scripts/workable-items/bin/workable-items-linux \
    close WSP-142 --db docs/workable_items.db --status completed \
    --evidence docs/qa/<artefact>

# The umbrella's own legs
_tools/workable-items/bin/workable-items-vsc roster     # fleet vs identifiers
_tools/workable-items/bin/workable-items-vsc validate   # integrity contract
_tools/workable-items/bin/workable-items-vsc report     # tallies incl. evidence class

# The gate, and its §1.1 paired proof
bash scripts/verify-workable-items.sh
bash scripts/verify-workable-items.sh --prove-failure
```

Build the umbrella tool with
`cd _tools/workable-items && CGO_ENABLED=0 GOPROXY=off go build -o bin/workable-items-vsc .`
It is pure Go on `modernc.org/sqlite`, following the `monetization/tools/repodb`
precedent — no CGO, no network, no `sqlite3` CLI dependency.

## The vocabularies, and the one place they live

Status, type and the closure mapping are the constitution's, not this
repository's. They are enforced twice: by `CHECK` constraints in the canonical
schema, and by the umbrella validator.

| Type (§11.4.16) | Closes as (§11.4.33) |
|---|---|
| `Bug` | `Fixed (→ Fixed.md)` |
| `Feature` | `Implemented (→ Fixed.md)` |
| `Task` | `Completed (→ Fixed.md)` |

`Obsolete (→ Fixed.md)` is §11.4.90's fourth terminal value and applies
regardless of type. It requires an `obsolete_details` row carrying the
triple-check evidence; the anchor's words are *"There MUST NOT be any mistake"*.

## The database is TRACKED. Never ignore it.

§11.4.95, verbatim:

> "**TRACKED in git** at canonical path `docs/workable_items.db`. NEVER
> gitignored regardless of file-size or 'build-artefact-class' heuristics — the
> DB is NOT a build artefact, it IS authoritative source data."

The `.db-wal` and `.db-shm` sidecars ARE ignored — the same anchor names them.
The gate checks both directions and its paired proof drives the ignore predicate
red against a throwaway repository, so "the DB is tracked" is a measured claim
rather than a habit.

## Honest boundaries (§11.4.6)

1. **The evidence class of a backfilled closure is recorded, and it is not a
   re-run.** Every item carries an `item_provenance` row naming the artefact its
   status rests on and the CLASS of that evidence: `document-assertion` (an
   operator-decision document states the outcome), `checkbox-state` (a tracked
   task list marks the row `[x]`), or `undetermined`. **No backfilled closure was
   re-verified by executing anything.** A `Completed` row backfilled from a
   `[x]` means the task list says so — nothing stronger. Query it:
   `SELECT evidence_class, count(*) FROM item_provenance GROUP BY 1;`
2. **The content-boundary gate cannot see inside this database.**
   `scripts/verify-content-boundary.sh` selects its corpus with `grep -Il .`,
   which excludes binary files, and a SQLite database is binary. The boundary
   argument for the DB therefore rests on provenance, not on that gate: every
   backfilled title is a verbatim substring of the already-public umbrella file
   it cites (checked mechanically over all 529 rows, 0 exceptions), and no row
   was sourced from a private submodule's own files.
3. **Type is `Task` on every backfilled row, by the anchor's own fallback.**
   §11.4.16: *"When ambiguous, fall back to `Task`."* Classifying 529 rows into
   Bug/Feature/Task from their prose would have been a guess wearing a
   classification's clothes. Re-typing an item is a one-command `update`.
4. **Severity is unset on every backfilled row.** No source states one, and
   §11.4.93 marks the column informational.
5. **Sub-project attribution is by measured path mention, not by subject.** A
   row naming no sub-project path, or naming paths in more than one, is
   attributed to the parent `VSC` — which is truthful, because the source
   document lives in the umbrella. One known conservative miss: an
   org-qualified name like `vasic-digital/design-toolkit` does not match the
   tree path `design-toolkit`, and lands on `VSC`.
6. **`[BLOCKED: …]` task rows are recorded `Queued`, not `Operator-blocked`.**
   §11.4.21 and §11.4.148(D3) require a WHY, an exhausted-alternatives
   statement and an ENUMERATED set of unblock choices. The source rows supply
   none of the three, and inventing them to reach the stronger status would be
   the fabrication §11.4.6 forbids. Each such row says so in its own
   description.
7. **`sync db-to-md` has not been run and no Markdown surface is generated
   yet.** §11.4.93's bidirectional round-trip guarantee is therefore NOT
   demonstrated here. It is a tracked follow-up, not a shipped property.
