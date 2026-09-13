# Decision Record — `Chapter.ordinal` Type (003:T001)

**Date**: 2026-09-13
**Decision**: `003:T001` — **Keep `int` ordinal, add `ordinal_path`** (zero-diff option)
**Feature**: `specs/003-chapter-hierarchy`
**Blocked tasks**: T001, T002, T003 (Phase 0)

---

## The question

`specs/001-workshop-curriculum-platform/data-model.md:45` types `Chapter.ordinal` as `int`.
A `02.01` has no `int` ordinal, so `ordinalOf("02.01")` returns `2` — colliding with `02`.
`specs/001-.../contracts/http-api.md:60` says the zero-padded ordinal is *not* accepted as
a path key, while `GET /api/chapters/01` is the live route.

Three options were costed in `research.md` D-CH-5:

| Option | Diff size | Outcome |
|---|---|---|
| **Keep `int`, add `ordinal_path`** | one wire field, one derivation | representable ordering at every depth; **zero diff** to the `ordinal` type |
| Keep `int`, sub-chapters have no ordinal | zero | makes every sub-chapter permanently unorderable and unlabelled |
| Keep `int`, flatten sub-chapters into one number space | small | renumbers every existing chapter on first sub-chapter insert, breaking deep links, scopes, archived artifacts |

## Decision recorded

**Chosen: Keep `int` ordinal, add `ordinal_path`.**

The zero-diff option is the only one that makes the defect permanent — a `02.01` has no
`int` ordinal, and giving it one is how `02` and `02.01` came to be the same number in the
first place. Adding `ordinal_path` as a derived, string-based ordering key resolves the
collisions without changing the `int` type or renumbering anything.

**Why not widen to `ordinal_path` alone**: that would change the `ordinal` type from `int`
to an ordered representation, touching every consumer that reads `ordinal`. The `int` type
is load-bearing across the codebase (front-end `models.ts`, the registry schema, archived
artifacts).

**Why not keep `int` with no ordinal for sub-chapters**: this makes every sub-chapter
permanently unorderable and unlabelled — it names the problem and moves on. The front
end's existing `null`-versus-`2` disagreement becomes the contracted behaviour, which is
worse than having a clear ordering key.

**Why not flatten into one number space**: renumbering every existing chapter the first
time a sub-chapter is inserted breaks every deep link, every registry `scope`, and every
archived artifact. The cost is unbounded and the change is non-reversible.

## Amendments made

1. **`specs/001-workshop-curriculum-platform/data-model.md:45`** — Added `ordinal_path`
   field to the `Chapter` entity table. `ordinal` remains `int`; `ordinal_path` is the
   derived, string-based ordering key (`[2,1]` for `02.01`).
2. **`specs/001-workshop-curriculum-platform/contracts/http-api.md:60`** — Changed the
   `{chapter}` path parameter row to name the **dotted id** as the single path key,
   replacing the contradictory statement that the zero-padded ordinal is *not* accepted
   as a path key while `GET /api/chapters/01` is the live route.

## Proof

Both amendments are to published artifacts of feature 001. The diff is reviewed as a
governance change, not as a spec edit. The live route set (`main.go:547`, `:817`–`:819`,
`:841`, `:843`) confirms the dotted id is served as the chapter path parameter.

---

*Recorded by execution of `003:T001` on 2026-09-13.*
