# Contract: Textbook Catalogue Builder

**Implements**: FR-005 | **Tool**: `workshop/pipeline/textbook_catalogue.py` (NEW, stdlib only; no network-capable import) | **Consumer**: `internal/textbooks.Load`

## CLI

```text
python3 -I pipeline/textbook_catalogue.py --books curriculum/textbooks/books.json --dir curriculum/textbooks \
        --out curriculum/textbooks/catalogue.json [--draft | --final]
```
- `--draft`: sections may lack `pid` (dry run, before ingest); `catalogue.json` is NOT written into the tree, only to the scratch path given.
- `--final`: every section must have a `pid`; writes atomically (temp + rename).

## Exit contract *(three-valued)*

`0` written · `1` real problem (missing pid in `--final`, two sections on one page, `UNVERIFIED` licence, report/sidecar page mismatch, invalid id) · `2` could not determine (unreadable file, invalid JSON,
tool missing). 2 is never a pass.

## Algorithm *(deterministic)*

1. Validate `books.json` (data-model §1). 2. For each book read `<id>.sections.json` and `<id>.report.json`. 3. Join report sections to main-sidecar sections **by page**
(`report.sections[].line == main.sections[].line_start`); title from the report, pid from the main sidecar. 4. Build `chapters` as maximal runs of identical titles over ascending pages.
5. Read the diagram sidecar `diagrams.json` if present; rewrite `raster_path` to the bare file name; add `sha256`, `bytes` of each file under `diagrams/<id>/`. 6. Emit JSON with sorted keys, 1-space indent,
`ensure_ascii=False`, trailing newline. 7. Grep own output for `/home/`, `\\`, the PDF base names, and `..`; any hit → rc 1.

## Test oracle

Golden file typed by hand for a 3-book fixture; byte-identical across two runs; Go loader decodes the same golden (`internal/textbooks/catalogue_test.go`).
