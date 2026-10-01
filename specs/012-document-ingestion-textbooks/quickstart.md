# Quickstart: Document Ingestion for Textbooks (EPUB, Phase 1)

Runnable validation scenarios. Run from `$VASIC_ROOT/workshop` unless noted.
Per this repository's anti-bluff discipline, every command below is expected
to be run for real, with real output pasted into the implementing task's
report — "ran the plan" is not evidence; the command's actual output is.

**What is real today vs. what Phase 1 still has to build, stated up front so
this file is not read as a claim of completion.** The mechanism is proven —
a real, assertion-verified POC exists and its captured output (§4.1 of the
research) is reproduced below. The **production** module
(`pipeline/epub_sections.py`), its `ebooklib`/`defusedxml` dependencies, and
the license-gate CLI flag do **not** exist yet as of this plan — Scenario 1
below runs the existing POC as evidence of the mechanism; Scenarios 2+ name
what a Phase 1 implementer still has to build and verify before this
feature can be reported done.

## Prerequisites

```bash
workshop/pipeline/venv/bin/python --version
# Expected: Python 3.14.x (measured 3.14.4 this session)

workshop/pipeline/venv/bin/python -c 'import ebooklib' 2>&1
# Expected TODAY: ModuleNotFoundError — not yet installed; a Phase 1 task
workshop/pipeline/venv/bin/python -c 'import defusedxml' 2>&1
# Expected TODAY: ModuleNotFoundError — not yet installed; a Phase 1 task

PYTHONPATH="." workshop/pipeline/venv/bin/python -m pytest \
    workshop/pipeline/test_build_transcript.py -v
# Baseline: today's sibling-module suite, must be green before starting —
# confirms the pipeline/ test convention this feature's own tests will follow
```

## Scenario 1: The proven mechanism, run today, real captured output

This is the POC (`docs/research/education-platform/poc/epub_extract_poc.py`)
— generates a synthetic three-chapter EPUB and extracts it back out using
only the Python standard library, proving spine-order detection,
heading-delimited sectioning, and the exact ingest-shaped JSON output.

```bash
cd workshop/docs/research/education-platform/poc
python3 epub_extract_poc.py
```

Expected (the real, captured run already recorded in the research document,
§4.1 — re-running it reproduces the same structural result deterministically
against the same synthetic input):

```
Generating synthetic EPUB -> sample-textbook.epub
  wrote 6589 bytes, 3 chapter XHTML documents

Spine order detected (from the OPF <spine>, not from a directory listing or filename sort):
  idref=ch1  href=ch1.xhtml    sections=2 chars=1206
  idref=ch2  href=ch2.xhtml    sections=2 chars=1029
  idref=ch3  href=ch3.xhtml    sections=2 chars=1064

Sections extracted: 6
...
All structural assertions passed (6 sections, correct spine order ch1->ch2->ch3, correct kind, correct first section).
```

```bash
cat sample-textbook.sections.json | python3 -m json.tool | head -20
```

Expected: the exact `{chapter_slug, source_file, sections[].{text, path,
line_start, line_end, kind}}` shape `ingest-transcript -docs` already
decodes — inspectable by eye against `main.go`'s `docPayload` struct, per
the research's §4.2 claim ("the real ingest binary could consume this exact
file with `-docs` today, with no code change on the Go side" — not run
against the real binary in the research session, and not run against it
here either: this scenario proves the shape match, not a live ingest).

**What this scenario proves**: the mechanism (container → OPF → spine →
XHTML → sections → ingest-shaped JSON) works, end to end, deterministically.
**What it does not prove**: anything about a real, non-synthetic textbook
(malformed XHTML, DRM, encoding edge cases — the POC's own stated
limitations, §4.2), and nothing about the license gate (the POC has no
license concept — it generates its own original, uncopyrighted synthetic
content specifically to sidestep that question for research purposes).

## Scenario 2: Production module exists and enforces the license gate (Phase 1 build target)

```bash
# Once pipeline/epub_sections.py exists:
workshop/pipeline/venv/bin/python pipeline/epub_sections.py \
    /path/to/some.epub /tmp/out.json --chapter-slug textbook-test
echo "exit: $?"
```

Expected: **exit 1**, zero bytes (or an empty/absent) `/tmp/out.json` — the
run is refused because `--license-basis` was not supplied, before any EPUB
byte is read (FR-005, SC-003). This is the single most important behavior
to verify before anything else, because it is the gate the research names
as "the single largest non-technical risk in this whole research area"
(§5.2).

```bash
workshop/pipeline/venv/bin/python pipeline/epub_sections.py \
    /path/to/some.epub /tmp/out.json --chapter-slug textbook-test \
    --license-basis "public-domain"
echo "exit: $?"
cat /tmp/out.json | python3 -m json.tool | head -20
```

Expected: exit 0, a real sidecar JSON matching the shape Scenario 1's POC
already demonstrated, but for real EPUB content rather than the synthetic
sample.

## Scenario 3: A real, licensed EPUB textbook, end to end (SC-001, SC-002, SC-006)

Requires one real, well-formed EPUB textbook with a recorded, genuine
license basis (e.g. a Project Gutenberg public-domain EPUB — an easily
obtainable real fixture matching FR-005's accepted examples) and a spine
order that differs from its own directory/filename listing order (SC-002's
specific fixture requirement).

```bash
workshop/pipeline/venv/bin/python pipeline/epub_sections.py \
    real-textbook.epub curriculum/textbook-real-sample/sections.json \
    --chapter-slug textbook-real-sample --license-basis "public-domain"

go run ./platform/backend/cmd/ingest-transcript \
    -docs curriculum/textbook-real-sample/sections.json \
    -db curriculum/passages.jsonl

go run ./platform/backend/cmd/index-embed -db curriculum/passages.jsonl

grep '"scope": *"textbook-real-sample"' curriculum/passages.jsonl | wc -l
```

Expected: a non-zero count of minted `doc_section` rows under the
`textbook-real-sample` scope. Follow one of the minted `pid`s to
`/passage/{pid}` (via the running `workshop-server`) and confirm it serves.
Query the search endpoint for text unique to one ingested section and
confirm it is returned by both the lexical and semantic paths (SC-006).

**Run against a scratch copy of `curriculum/passages.jsonl` first** if you
want to inspect without committing to the real, served registry — matching
spec 009's own `TestRealBridgeMinting` precedent for exactly this reason.

## Scenario 4: Idempotency across a re-ingested, lightly-edited edition (FR-007, SC-004)

```bash
cp curriculum/passages.jsonl /tmp/passages-run1.jsonl
# re-run Scenario 3's ingestion against the SAME, unchanged EPUB
diff /tmp/passages-run1.jsonl curriculum/passages.jsonl
```

Expected: no diff (byte-identical) — a second run over unchanged input
mints zero new passages.

```bash
# then, against a deliberately lightly-edited copy of the same EPUB
# (e.g. a corrected typo in one section's prose, same section boundaries)
```

Expected: zero *new* passages minted for the unchanged section identities;
only the edited section's text changes, attached to its existing `pid` via
the exact-text-match/position-range tiers, not re-minted as a duplicate.

## Scenario 5: `/api/chapters` correctly excludes the textbook (FR-006, SC-005)

```bash
curl -s http://127.0.0.1:8087/api/chapters | python3 -c \
    'import json,sys; data=json.load(sys.stdin); \
     print("textbook-real-sample" in [c.get("scope") for c in data])'
```

Expected: `False` — the textbook's scope never appears in the chapter
listing, while its sections remain independently reachable at
`/passage/{pid}` (verified in Scenario 3).

## Scenario 6: DRM and malformed-XHTML refusal (FR-009, FR-010)

```bash
PYTHONPATH="." workshop/pipeline/venv/bin/python -m pytest \
    pipeline/test_epub_sections.py -k "drm or malformed" -v
```

Expected: fixture-based tests demonstrating (a) a DRM-wrapped EPUB is
refused with an explicit reason naming DRM, never attempting decryption; and
(b) an EPUB with one malformed spine document still processes its remaining
well-formed documents, naming the failed one explicitly rather than
aborting the whole run or silently dropping it.

## Full regression

```bash
PYTHONPATH="." workshop/pipeline/venv/bin/python -m pytest pipeline/ -v
```

Expected: every existing test passes (no regression to `md_sections.py` or
any other `pipeline/` module), plus the new `test_epub_sections.py` suite.
