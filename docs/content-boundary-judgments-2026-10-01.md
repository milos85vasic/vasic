# Content boundary — class A delta pass (2026-10-01)

**Status: JUDGED. 0 REAL DISCLOSURE found. NOTHING WAS REDACTED, NOTHING WAS
ALLOW-LISTED, NO THRESHOLD OR BASELINE WAS MOVED, AND
`scripts/verify-content-boundary.sh` WAS NOT EDITED. The gate still exits 1,
and it should.**

This is a **delta** pass against
[`content-boundary-class-a-judgement.md`](content-boundary-class-a-judgement.md)
(2026-09-08, 1,933 rows judged, **0 DISCLOSURE**), prompted by the operator's
instruction to judge class-A INWARD/UNDETERMINED rows **now**, with a fresh
gate measurement rather than the cached figures either document carries. It
does **not** repeat that document's work; it establishes whether the corpus
has moved enough since 2026-09-08 to need new judgment, and judges exactly the
rows that are new. It does **not** make the detector green — that remains
explicitly out of scope per `specs/005-clone-and-clear-red/spec.md`.

No matched text, private prose, or personal data appears anywhere in this
document. Every finding is cited by path and line, exactly as
[`content-boundary-class-a-judgement.md`](content-boundary-class-a-judgement.md)
and
[`content-boundary-incident-2026-09-01.md`](content-boundary-incident-2026-09-01.md)
already do.

## Why a delta pass, not a re-run from zero

Two things changed since 2026-09-08 that could plausibly have introduced new
class-A disclosures, and both were checked directly rather than assumed:

1. **The public side moved.** `specs/001-workshop-curriculum-platform/tasks.md`
   gained 16 lines and `specs/002-knowledge-areas-deep-linking/tasks.md`
   gained 120 (commit `952f53c`, 2026-09-15); `contracts/knowledge-graph.md`
   gained 22 (commit `13325b7`, 2026-09-15). Line numbers in the 2026-09-08
   artifact no longer line up with today's files for most of the population —
   see "Why most rows read as 'uncovered'" below.
2. **The private side moved.** `workshop` landed
   `a9e0181 feat(chapter-03): onboard chapter-03, resolve privacy review,
   reintegrate 233 ambiguous-scope rows` earlier today (2026-10-01), plus two
   `fix(gates)` commits. Chapter 3 — a second private recording with the same
   two participants — did not exist in the private corpus on 2026-09-08 at
   all.

## Fresh measurement (this session, 2026-10-01)

```
bash scripts/verify-content-boundary.sh --json
```

Full run, no flags narrowing scope. **Took ~37 minutes** (14 repositories,
full prose/short/name/fingerprint passes, then the direction-subtraction git-
history walk over all four repositories' complete histories) — recorded here
because the next reader should not expect it to return quickly.

| | value |
|---|---:|
| exit | **1** |
| total leaks | **16,284** (prose 14,026, short 1,612, name 178, fingerprint 468) |
| undetermined (non-direction) | 26 |
| direction: eligible keys | 17,237 |
| direction: subtracted (OUTWARD, provably public-first) | 41,350 |
| direction: kept (INWARD or same-second) | 13,968 |
| direction: direction-undetermined | 1,670 |
| corpus | **MOVED** — 22 of 22,264 enumerated files changed between the pre- and post-analysis fingerprints |

**The corpus-moved note means this run's counts are not perfectly
reproducible**, exactly as the gate's own header warns. 22 of 22,264 files is
0.1% of the enumerated corpus; the class-A conclusions below do not rest on
any of the specific counts being exact to the row, only on the **groups and
private-source prefixes** being stable, which was checked separately (see
"Why most rows read as 'uncovered'").

**Class A** (this umbrella's own definition, carried over unchanged from the
2026-09-08 artifact: public destination under `specs/001-**` or
`specs/002-**`) = **5,468 rows** today (prose 4,978, short 443, fingerprint
41, name 6). This is the population judged below. `fingerprint` did not exist
as a class on 2026-09-08; everything else does.

**Honest scope note.** Seven further spec trees now exist
(`specs/003`–`specs/013`) that were not there on 2026-09-08 and are **not**
"class A" by this document's or the prior one's definition. They are **not**
judged here. This is the same boundary the 2026-09-08 artifact drew for
itself ("This judges class A only... not cleared by it") and this document
draws it in the same place, not a narrower one.

## The three prioritized files — exact state today

| File | Total rows | Covered by exact (public,line) match to the 2026-09-08 artifact | Not covered by line |
|---|---:|---:|---:|
| `specs/002-…/contracts/knowledge-graph.md` | 465 | 372 | 93 |
| `specs/002-…/tasks.md` | 562 | 35 | 527 |
| `specs/001-…/tasks.md` | 437 | 22 | 415 |

`knowledge-graph.md` kept most of its line alignment (its 2026-09-15 edit was
a 22-line addition near the end); both `tasks.md` files lost almost all of
theirs, because their 2026-09-15 edits inserted well before most of the
file's own content (append-style task lists, inserted mid-document). This is
the first thing to settle, because a naive "not covered by line → unjudged →
must be read" conclusion would send a reader back through ~1,000 rows of
these three files alone that are in fact the **same text, at a new line
number**.

## Chapter 3 — checked directly, named first because it is the highest-risk question

**Zero class-A rows trace to `workshop/chapters/02` or `workshop/chapters/03`,
today, after the reintegration commit.** Checked directly against the fresh
run's full leak list (not inferred): of the 5,468 class-A rows, exactly **two**
distinct private files anywhere under `workshop/chapters/` appear at all —

| Private file | Class-A rows today | Status |
|---|---:|---|
| `workshop/chapters/01/transcript/accuracy-plan.json` | 197 | **Already judged** — 2026-09-08 artifact, group `G1-CHAPTER-SAMPLING-PLAN`, verdict `NOT_A_DISCLOSURE` (a sampling-plan methodology field, no transcript text, no participant identifier — see that document for the full reasoning) |
| `workshop/chapters/01/… - Notes by Gemini.PDF` | 6 (all `fingerprint`, digest `7e93b14f`) | **Judged below**, group G10 — the filename's own date/time, already an accepted baseline per `content-boundary-incident-2026-09-01.md` §2 |

Both are chapter 1. Chapter 3's transcript, segments, words, and knowledge
files — the material
`workshop/docs/redaction-review-chapter-03.md` reviewed earlier today and
marked **NOT SAFE to publish, export or serve** inside the private
repository — **do not appear in the public class-A population at all.** This
was checked, not assumed: the private-source breakdown of every one of the
5,468 rows was enumerated and no `workshop/chapters/02/**` or
`workshop/chapters/03/**` path appears in it.

## Why most rows read as "uncovered" — and what that number is actually made of

4,686 of the 5,468 class-A rows do not exact-match a `(public, line)` pair in
the 2026-09-08 artifact (the same key `scripts/verify-content-boundary-
judgement.sh`'s own P5 coverage check uses — see "A gate defect found, not
fixed" below). Reading all 4,686 individually was neither necessary nor the
right use of time: they were grouped by **private source path**, because the
private side is unaffected by the public-side line insertions that caused
most of this.

**4,625 of the 4,686 (98.7%) come from a private-source prefix the 2026-09-08
artifact already characterized** — `workshop/platform/backend`,
`workshop/platform/gates`, `workshop/docs/session-evidence`,
`workshop/pipeline/extract`, `workshop/scripts/verify-accuracy.sh`,
`workshop/docs/training`, `workshop/chapters/01` (the two files above),
`workshop/pipeline/mentions`, `workshop/curriculum/learning`, and seventeen
further prefixes, each one a private source already placed in group G2
(platform source vs. the spec it implements), G3 (session-evidence briefs),
G4 (platform documentation), G5 (training areas), or G6 (chapter-01 redaction
review) by the prior document. The reasoning those groups give — median lead
times under an hour, source-and-spec co-authorship, shared gate/evidence
vocabulary, no transcript or participant content on either side — was not
re-derived from scratch; it was **extended** to these rows on the strength of
the private file being the same kind of artifact in the same part of the
tree, exactly as item 6 of this task's own instructions describes for a
repeating pattern. All 41 `fingerprint`-class rows are inside this 4,625 and
were, additionally, individually inspected (next section) rather than only
pattern-extended, because `fingerprint` is a class the 2026-09-08 artifact
never saw.

**61 rows come from a private-source path not represented in the 2026-09-08
artifact at all.** These were read individually, on the public side, this
session. See "The 61 new rows" below.

## Group G10 — the `fingerprint` class, read in full (new class, 41 class-A rows, 6 distinct digests)

`fingerprint` did not exist on 2026-09-08. Every one of its 41 class-A rows
was read this session by opening the **public** context around the cited
line (the private side was not opened beyond the path; the gate withholds the
matched literal by design, same discipline as the `name` class). Six distinct
digests account for all 41 rows:

| Digest | Kind (from the gate's own label) | Private source | Rows | Public context found at the cited lines |
|---|---|---|---:|---|
| `7e93b14f` | `ts` (timestamp) | chapter-01 notes PDF | 6 | `specs/001-…/spec.md:19` states the recording's own filename and its embedded date/time (`2026_08_27 09_57 CEST`) as a measured fact about the source material — the same filename-timestamp baseline `content-boundary-incident-2026-09-01.md` §2 already accepted as not a disclosure |
| `660901bf` | `hwmodel` | `workshop/docs/session-evidence/phase2c-report.md` | 5 | `specs/001-…/tasks.md` around line 409 — dense engineering status prose (tooling-detection task notes); no participant or session content |
| `5a8f9011` | `ver` | `workshop/docs/session-evidence/search-defect-evidence.md` | 16 | `specs/001-…/review.md:47` — a LAN host:port (`192.168.1.44:8087`) cited while describing how a route manifest was live-probed; infrastructure detail, not personal data |
| `2ef5f480` | `ts` | `workshop/platform/backend/internal/api/accuracy_test.go` | 3 | `specs/001-…/contracts/http-api.md:1227` — an example JSON payload's `"measured_at": "2026-09-01T09:40:12Z"` test-fixture field |
| `3f4eee54` | `ts` | `workshop/platform/frontend/.../seek.spec.ts` | 3 | `specs/001-…/contracts/http-api.md:455` region — a test-fixture timestamp in the same contract document |
| `690a8907` | `hwmodel` | `workshop/platform/gates/check-registry-001.tsv` | 8 | `specs/002-…/tasks.md` around lines 872–946 — gate-registry / CI-tooling task prose |

**Verdict: NOT_A_DISCLOSURE, all 41 rows, all 6 digests.** Every one resolves
to infrastructure or test metadata — a recording filename's own date (already
an accepted baseline), a private LAN address, test-fixture timestamps, and
tooling/hardware descriptors inside engineering status prose. None sits near
transcript text, a participant identifier, or session content on the public
side, and the two private sources that are chapter material are both the
filename-timestamp case already covered above.

## The 61 new rows — read individually, grouped by private source

| Group | Rows | Class | Private source | Public destination(s) | Verdict · reason |
|---|---:|---|---|---|---|
| G9a | 16 | prose | `monetization/.specify/memory/constitution.{md,pdf}` | `specs/001-…/contracts/pipeline-cli.md` | **NOT_A_DISCLOSURE.** `pipeline-cli.md:17` explicitly attributes the quoted text to **this umbrella's own** `.specify/memory/constitution.md`, by name, as a verbatim citation of its own "Honest Instruments" exit-code taxonomy. `monetization`'s private project-scaffold constitution carries the same boilerplate because it is the same author's standard text reused across his own projects (the same `Class N1 — shared authorship boilerplate` pattern `content-boundary-incident-2026-09-01.md` §9.2 already names). The public side names its own public source; nothing private crossed. |
| G9b | 11 | prose | `workshop/docs/user-guide.html` | `specs/001-…/contracts/http-api.html`, `specs/002-…/quickstart.html` | **NOT_A_DISCLOSURE.** An HTML render of the platform's own user-guide documentation, matched against the contract/quickstart documents that specify the same platform. Same shape as group G4 (platform documentation), a render format not individually listed there. |
| G9c | 9 | prose | `workshop/docs/faq.html` | `specs/001-…/contracts/pipeline-cli.html`, `specs/001-…/tasks.html` | **NOT_A_DISCLOSURE.** HTML render of the platform FAQ; `faq.md`/`faq.pdf` are already in G4's judged source set, this is the same document's third render. |
| G9d | 8 | prose | `workshop/docs/qa/MANUAL-TEST-PLAN.{md,sections.json}` | `specs/001-…/review.{html,pdf}` | **NOT_A_DISCLOSURE.** Read directly: `review.md:47` area discusses live-probing the platform's own route manifest and classifying HTTP responses — QA/test vocabulary about the specified platform, no session or personal content. |
| G9e | 6 | name | `workshop/docs/answering.md` | `specs/001-…/research/llm-bridging.{md,html,pdf}` | **NOT_A_DISCLOSURE.** Read directly: the public side at all three cited line regions (`llm-bridging.md:105,672`, and the html/pdf equivalents) is hardware/model engineering prose — CPU model, AVX flags, ollama instance sizing, generation-latency tables for candidate LLMs. `workshop/docs/answering.md` is the private documentation of the platform's own answering feature; the capitalised 2–3 token run the gate found is a technical term shared between the two documents about the same subsystem, not a person — consistent with the 2026-09-01 name-class triage's finding that every surviving name-class row in this tree was a false positive from the capitalised-run heuristic, never a git identity. |
| G9f | 6 | prose | `workshop/docs/redaction-review-chapter-01.html` | `specs/001-…/redaction-review-summary.html`, `specs/001-…/tasks.html` | **NOT_A_DISCLOSURE.** HTML render of the document group G6 already judged (the chapter-01 redaction review, a by-design counts-only public summary with no chapter content, no name, no `pid`). |
| G9g | 3 | short | `workshop/scripts/transcribe.sh` | `specs/001-…/tasks.{html,md,pdf}` | **NOT_A_DISCLOSURE.** A private script's own path/heading cited in task prose describing what the task implements — the ordinary G2 "spec names the file it specifies" pattern. |
| G9h | 2 | prose | `workshop/docs/README.html` | `specs/001-…/contracts/pipeline-cli.html` | **NOT_A_DISCLOSURE.** HTML render of the platform README, same G4 pattern. |
| **TOTAL** | **61** | | | | **0 DISCLOSURE · 0 UNDETERMINED** |

## Final tally

| | |
|---|---:|
| Class-A rows measured today (fresh run, 2026-10-01) | **5,468** |
| Covered by exact (public,line) match to the 2026-09-08 artifact (already `NOT_A_DISCLOSURE`, unchanged) | 782 |
| Extended to an already-judged private-source group (G1–G6), spot-verified where the class was new (`fingerprint`, 41/41 read) | 4,625 |
| Read individually this session (new private-source paths, groups G9a–G9h) | 61 |
| **REAL DISCLOSURE found** | **0** |
| **NOT A DISCLOSURE** | **5,468 (100%)** |
| **UNDETERMINED** | **0** |
| Class-A rows tracing to `workshop/chapters/02` or `/03` (today's reintegration) | **0** |

**No row in today's class-A population is classified REAL DISCLOSURE.** This
document does not claim the full 1,933+5,468-row history is clean in some
stronger sense than that — see "Honest boundary" below — only that every row
checked, by direct read or by documented, evidence-based extension of an
established group, resolved to `NOT_A_DISCLOSURE`.

## A gate defect found, not fixed

`scripts/verify-content-boundary-judgement.sh`'s P5 coverage check
(`--against <gate --json>`) computes an `unjudged` counter
(`run_check`'s Python body) but **never uses it** — the loop that would
increment it on an uncovered `(public, line)` key `continue`s without an
`else` branch, so `unjudged` stays `0` on every run and is not surfaced in
the `coverage` object or as a defect/undetermined row. The script's own
`--help` text promises *"A row the gate reports and the artefact does not
name is UNJUDGED, and unjudged is a finding"* — today it silently is not one.
Confirmed by reading the script
(`scripts/verify-content-boundary-judgement.sh`, the `run_check` Python
heredoc, the block beginning `# P5 coverage, only when a gate run is
supplied`), not by running it with `--against`, because a 37-minute gate run
was already in hand from this session and re-running the judgement script
against it would not have exercised a different code path. **Not fixed** —
fixing a verification gate was not in scope for this task and deserves its
own review. Recorded here so it is not silently rediscovered.

Separately, `scripts/verify-content-boundary-judgement.sh`'s own run (without
`--against`) reported `P4 token set could not be DERIVED from the private
index (submodule uninitialised or unreadable)` even though `workshop` is
initialised and `git -C workshop ls-files chapters` returns 12 files when run
by hand. The exact cause was not isolated (deprioritized in favor of the
primary task); it is a **1 unresolved row → exit 2** on that script today,
separate from anything in this document.

## What this did NOT do

- **No public file was edited.** No redaction was performed.
- **`.content-boundary-allow` was not touched.**
- **`scripts/verify-content-boundary.sh` was not edited.**
- **No baseline was moved.** The gate exits **1**, as it should.
- **`specs/003`–`specs/013` were not judged.** They are not "class A" by this
  document's own definition and no claim is made about them.
- **The 4,625 pattern-extended rows were not read one by one.** They were
  grouped by private-source prefix against the 2026-09-08 artifact's own
  groups, and the one genuinely new class among them (`fingerprint`) was read
  in full rather than extended. This mirrors that artifact's own stated
  method ("Judgement is by GROUP... not by reading all 1,138 distinct digests
  one at a time").
- **`workshop/chapters/02` and `workshop/chapters/03` were not opened at
  all.** They were not needed: the fresh gate run itself shows zero class-A
  rows reference either.

## Honest boundary — read this before quoting any number above

1. **This judges class A only**, using this umbrella's own prior definition
   (`specs/001-**` + `specs/002-**`). The much larger non-class-A population
   (16,284 − 5,468 = 10,816 rows) is untouched by this document.
2. **The corpus moved during the measuring run** (22 of 22,264 files). The
   fresh totals quoted above are a reading of a tree that was not perfectly
   still, exactly like every prior content-boundary measurement in this
   repository's history. The conclusions rest on private-source **prefixes**
   and **groups**, which are far more stable than any single count.
3. **4,625 rows were judged by extension, not by individual reading.** A
   reader who wants every one of them opened individually can do so; the
   private path, public path, and line of each is in the fresh `--json`
   output this document was built from
   (`/tmp/claude-1000/.../cbdir-run1.json` in this session's scratchpad — not
   committed, and not reproducible by path since scratch directories are
   session-scoped; re-run the gate to regenerate it).
4. **This does not re-validate the 2026-09-08 artifact's own 1,933 judged
   rows.** They are taken as already decided, per that document's own
   standing.
5. **`workshop/chapters/03`'s redaction review marks it NOT SAFE to publish,
   export, or serve — inside the private repository.** That verdict governs
   publication FROM the private repository. This document's only claim about
   chapter 3 is narrower and different: nothing from it has crossed INTO this
   public repository's class-A population as measured today.

## Re-derive rather than trusting this document

```bash
bash scripts/verify-content-boundary.sh --json > /tmp/cb-fresh.json   # ~35-40 minutes
python3 -c "
import json
d = json.load(open('/tmp/cb-fresh.json'))
classA = [r for r in d['leaks'] if r['public'].split(':')[0].startswith(('specs/001-','specs/002-'))]
print(len(classA))
print(sorted(set(r['private'] for r in classA if 'workshop/chapters/' in r['private'])))
"
bash scripts/verify-content-boundary-judgement.sh --against /tmp/cb-fresh.json
```
