# Contract — The authored content format

`workshop/curriculum/learning/NN-<slug>.json` — one `curriculum-kit` `Document`
per authored area.

## Identity

`NN-` is a **sort key only**. **Identity is the area's taxonomy ULID inside the
file.** An authored document binds itself to an extracted area, so there is no
mapping table to maintain and a rename orphans nothing.

## Strictness

Decoded with `DecodeDocument`, which **rejects unknown fields**.

This is the load-bearing property. A misspelled key otherwise drops its material
**silently**, and a lesson quietly missing a diagram is indistinguishable from a
lesson that never had one. Failing loudly at load is worth the strictness — so
**write one file and prove it decodes before writing the rest**.

## Absence states

| Condition | Response |
|---|---|
| catalogue not configured | a **determined** `no_learning_catalog` |
| catalogue unreadable | **503** |

"Not configured" is a known state; "cannot read" is a fault. Collapsing them
would report a missing flag as a broken server.

## Content obligations

- Lessons carry title, `ord`, body, `estimated_minutes`.
- The **required** lesson set may be a proper subset of the lessons.
- Materials carry `kind` from the closed vocabulary, a caption, and a text
  alternative conveying **content**, not a file name.
- Video anchors carry chapter, measured start, optional end, and a transcript
  anchor that resolves.
- An assessment declares `pass_percent` and its required lessons.

## The honest-absence rule

An area may have lessons and **no assessment**. Where no authored question bank
exists, the area carries none and says so. **A fabricated question bank is worse
than a missing one** — it is a test a learner can fail for the wrong reason.

Currently: **5** authored senior banks against **37** areas. The other 32 are not
to be padded to make the numbers match.
