# Contract — Catalogue

Governs the area list and the area detail. **Both are consumers of one
publication decision**; neither re-implements it (R1, invariant I1).

## `GET /api/areas`

| Field | Guarantee |
|---|---|
| `areas[]` | **Exactly** the set whose `href` answers 200. Asserted end to end. |
| `held_back[]` | `{id, reason}` for every withheld area; a derived `title`/`tags`/`summary` when derivable. |
| `reason_table` | The closed reason vocabulary, in the same response. |
| `total_areas` | The population, so a filtered list never hides its denominator. |
| `corpus_revision` | What this catalogue was built from. |

`?include=held_back` returns full objects for held-back rows — being withheld
never makes an area unreachable.

`tags` is **never `null`**; an empty array instead.

## `GET /api/areas/{area}`

| Outcome | Body |
|---|---|
| published | the area |
| withheld | `reason` (closed vocabulary), `published:false`, `whole_list`, and an `area` object with derived title/tags/summary **when derivable** |
| build inconsistent | **503** — a broken build, not an editorial refusal |

**Why a withheld area still discloses its name**: the reported symptom was a
page saying only "withheld pending review". An area held back for a missing
review has a perfectly good name, and withholding it helped nobody.

## Closed reason vocabulary

`no_title` · `no_evidence` · `no_publication_review` ·
`stale_publication_review` · `no_materials_record` · `build_inconsistent`

Three of these were previously computed by one handler and invisible to the
other. **A shared vocabulary is not the fix** — both handlers already shared it.
The fix is a shared *decision*.

## Asserted by

`verify-area-publication-consistency.sh` (**0**, 6 passed / 0 failed / 0 undetermined)
· `prove-area-publication-consistency.sh` (**0**, 7 passed / 7 mutations)
· Go `TestAreaListAndDetailAgree` — the assertion on the *pair*, which is what
was missing while both handlers' own tests passed.

Vacuity refusal **A6**: nothing served **and** nothing held back exits **2**,
never 0.
