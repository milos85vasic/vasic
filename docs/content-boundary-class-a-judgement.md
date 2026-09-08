# Content boundary — class A INWARD rows, judged (2026-09-08)

**Status: JUDGED. NOTHING WAS REDACTED, NOTHING WAS ALLOW-LISTED, NO THRESHOLD
OR BASELINE WAS MOVED, AND `scripts/verify-content-boundary.sh` WAS NOT EDITED.
The gate still exits 1, and it should.**

This closes the option-4 half of the decision packet carried in the four root
governance carriers under *"Content-boundary re-baseline — the decision packet"*,
and answers **R11** of
[`../specs/005-clone-and-clear-red/spec.md`](../specs/005-clone-and-clear-red/spec.md).
It does **not** make the detector green — spec 005 puts that explicitly out of
scope — and it must not be read as clearing the population the gate reports.

Machine-readable artefact:
[`findings/content-boundary-class-a-judgement.jsonl`](findings/content-boundary-class-a-judgement.jsonl)
— one object per judged row. **Paths, classes, digests, epochs and counts only.
No matched text appears in it, in this document, or in any report derived from
either.**

## What was judged, and what "class A" means

**Class A** is the content-boundary population whose PUBLIC destination is one
of this umbrella's two spec trees, `specs/001-**` and `specs/002-**`. It is the
largest structural class in the packet, and the packet's recommended action was
to judge its **INWARD** rows — the rows whose text was committed on the PRIVATE
side first.

**Two full gate runs were taken, tied together with `--expect-corpus`, and BOTH
are reported — not the more convenient one.** The population moved sharply
between them; §"Why the total fell" below explains why, measured rather than
guessed.

| | run 1 · 2026-09-08 12:14 | run 2 · 2026-09-08 12:53 |
|---|---:|---:|
| gate exit | **1** | **1** |
| gate total | **16,155** (prose 15,107, short 831, name 217) | **9,945** (prose 9,456, short 373, name 116) |
| class A | **9,513** (prose 9,168, short 295, name 50) | **7,086** (prose 6,902, short 139, name 45) |
| class A **OUTWARD** — public text is older | **7,631** (80.2 %) | **5,815** (82.1 %) |
| class A **INWARD** — private text is older | **1,832** (19.3 %) | **1,226** (17.3 %) |
| class A direction **UNDETERMINED** | **50** (0.5 %) | **45** (0.6 %) |
| corpus during the run | **MOVED**, 66 of 14,891 files | **MOVED**, 4 of 14,837 files |
| corpus vs run 1's manifest | (wrote it) | **DIFFERS** |

**Judged here: the UNION of both runs' INWARD and direction-UNDETERMINED rows —
1,933.** 1,882 came from run 1, and **51 further rows appeared only in run 2**
(all `G2`, all into `specs/001-…/contracts/*`); judging the union rather than
either run alone is what stops a moving tree from quietly dropping a row out of
the reading queue.

The direction split has now been measured **five times over five populations
whose totals differ by more than 3,000 rows**, and OUTWARD has landed between
**79.1 % and 82.1 %** every single time (79.7 / 79.3 / 79.1 / 80.2 / 82.1).
**The totals move; the direction does not.** That is the finding to act on.

### Why the total fell — measured, not guessed

**An unexplained fall is worse than a stable red, so this one is attributed.**
The gate total fell 16,155 → 9,945 in 39 minutes. **Nothing was silenced to
achieve it**, and each of the four candidate mechanisms was tested rather than
assumed:

| Candidate mechanism | Measured |
|---|---|
| the instrument was weakened | **No.** `scripts/verify-content-boundary.sh` is unmodified; the path-reference mask is **identical** in both runs (1,425 long + 5,613 short shingles) |
| an exemption was added | **No.** `.content-boundary-allow` is unmodified; pardons **rose** 4,077 → 4,083, moving with the corpus |
| private files were deleted or untracked | **No.** Of the 139 private files behind the lost rows, **0** are gone from disk and **0** have left `git ls-files` |
| a new public repository exonerated them | **No.** The derived fleet is **identical** in both runs (15 rows, same roles); a 40-row sample of the lost rows found **0** whose text is present in the newest public submodule |
| **the private corpus itself shrank** | **YES.** Private prose tokens fell **3,597,903 → 3,129,293 (−13.0 %)**, name candidates 527 → 353, already-public keys 2,306 → 869 |

**The mechanism is concurrent work, not remediation.** The private `workshop`
submodule had **217 modified files** in its working tree while both runs were
taken, and the gate reads the working tree. A 13 % smaller private corpus yields
a smaller private key space and therefore fewer matches, in every class at once —
which is exactly the shape observed. **This is a measurement of a moving tree,
and neither total may be quoted as the count of any single tree.** Both runs
said so themselves.

### Method — stated so it can be attacked

Direction is measured **at the level of the text, not the file**, and **at
corpus level, not pairwise**:

1. Every class-A row's matched string is normalised exactly as the gate
   normalises (`[^A-Za-z0-9]+` → space, lowercased — the same rule at
   `scripts/verify-content-boundary.sh:1938`).
2. Every commit of every repository is walked **chronologically**, and every
   blob it adds or modifies is normalised the same way and scanned for every
   still-undated string. A string is dated at the **earliest commit whose blob
   content actually contains it**, anywhere in that repository — so a string
   that moved between files is still caught, and a file merely renamed does not
   restart its clock.
3. Public = the umbrella. Private = `workshop`, `ai_interviewing`,
   `monetization`. Blobs scanned: **6,449 public, 2,881 private** (workshop
   2,072, ai_interviewing 794, monetization 15). **Nothing sampled, nothing
   extrapolated.**
4. A string committed on one side only is **UNDETERMINED**, never a verdict.

**The probe's normalisation was validated against the gate rather than assumed
to agree with it.** On a seeded random sample of **60** class-A rows, the row's
matched string was located, under this probe's own normalisation, in the current
content of both the named public file and the named private file: **60 of 60 on
each side, 0 misses.** Two corpora normalised differently is the one failure the
gate's own header says must never happen, and this is the check that it did not.

The `name` class cannot be dated at all: the gate **withholds** the matched text
by design, so there is nothing to normalise. All 50 class-A name rows are
therefore direction-UNDETERMINED **by construction**, and defeating that
protection to date them would be the disclosure the protection exists to
prevent.

### What "private committed first" does NOT mean

It establishes an **order**, nothing more. A symbol name, a task line, an error
string, or a design decision made in code and written up afterwards all produce
INWARD rows with nothing having crossed the boundary. **1,832 rows are not 1,832
leaks and must never be reported as such.** What the number does establish is
that the reassuring story — *"the specs are outward propagation"* — is true for
four rows in five and **false for the fifth**, which is why the fifth was read.

## The 68 rows against the recorded teaching material — read first

These are the only judged rows whose private side sits under
`workshop/chapters/`, the directory holding a recording of a private teaching
session with an identifiable third party. They carry the highest cost if wrong,
so they were judged first and in the most detail.

| | |
|---|---|
| Rows | **68**, all `prose` |
| Private source | **one** file: `workshop/chapters/01/transcript/accuracy-plan.json` |
| Public destinations | `specs/001-…/tasks.md` (45, at 4 distinct lines) and `specs/002-…/tasks.md` (23, at 3 distinct lines) |
| Distinct matched strings | **30** |
| Direction | INWARD, lead **141 seconds** — private `2026-09-03T20:15:14`, public `2026-09-03T20:17:35` |

**Verdict: NOT A DISCLOSURE.** Three independent measurements, each re-derivable:

1. **The private file contains no recorded material of any kind.** It is a
   stratified **sampling plan** for measuring transcript accuracy. Its fields
   are a chapter id, a filename, a duration, a seed, thirty `{t0,t1}` window
   bounds, and five descriptive strings. It carries **no transcript text, no
   speaker turn, no utterance, no participant identifier and no personal data** —
   there is no field of that kind in it to carry any.
2. **Every one of the 30 matched strings resolves to a methodology field**, and
   the split was measured rather than asserted: `estimator_unit` **23**,
   the plan's own how-to-use instruction field **6**, and
   `reference_schema.windows[].onset_s` **1**. **Zero**
   resolve to any window, timing, content or identity field.
3. **The public side is the instruction to use that plan.** The four
   `specs/001-…/tasks.md` lines and the three `specs/002-…/tasks.md` lines are
   task prose telling a human what to produce, in what form, and why the
   estimator unit matters. Naming the plan's path is a **reference**, which this
   boundary explicitly permits.

The 141-second lead is the whole mechanism: one authoring session in which the
plan was committed privately and the public task text describing it was written
two and a half minutes later. **The direction is real and the crossing is not.**

Separately, the **5** class-A `name`-class rows whose private side is the
private notes PDF are covered under G8 below. Its **filename carries the third
party's given name**, so that path is **withheld** from the machine-readable
artefact — a path is normally quotable, this one is not.

## Every judged group, with its verdict

| Group | Rows | Digests | Private files | Public files | Median lead | Verdict · reason |
|---|---:|---:|---:|---:|---:|---|
| **G1** chapter sampling plan | 68 | 30 | 1 | 2 | 141 s | NOT A DISCLOSURE · methodology field of a sampling plan |
| **G2** platform source (`platform/`, `pipeline/`, `scripts/`, `curriculum/`) | 1,222 | 885+ | 102 | 15 | 29 min | NOT A DISCLOSURE · spec and implementation co-authored |
| **G3** session-evidence briefs | 184 | 121 | 16 | 5 | 141 s | NOT A DISCLOSURE · build-session brief about the specified platform |
| **G4** platform documentation (`limits`, `manual`, `faq`, `README`, runbooks, prompts) | 163 | 55 | 20 | 6 | 11 h | NOT A DISCLOSURE · documentation of the same platform |
| **G5** training areas | 126 | 71 | 14 | 5 | 194 s | NOT A DISCLOSURE · shared engineering argument about the public contract |
| **G6** chapter-01 redaction review | 6 | 3 | 2 | 2 | 21 h | NOT A DISCLOSURE · by-design counts-only public summary |
| **G7** evidence files and gate registries | 114 | 102 | 18 | 9 | 7 min | NOT A DISCLOSURE · gate and evidence vocabulary |
| **G8** name class (direction undetermined) | 50 | **1** | 10 | 1 | — | NOT A DISCLOSURE · digest previously adjudicated as a product brand |
| **TOTAL** | **1,933** | | | | | **0 DISCLOSURE · 0 unjudged** |

Row counts are over the **union** of both runs; the per-group digest, file and
lead-time columns are run 1's, which is the larger population.

**Every row landed in a group; none is ungrouped.** The artefact carries a
`G9-UNGROUPED` verdict of `UNDETERMINED` precisely so that a future run over a
changed corpus cannot silently absorb a row that no group describes.

### G2 — 1,222 rows, and why they are the least surprising half

Private **source code** (Go 479, Python 377, shell 323, TypeScript 13 by row)
against the public **contract and task documents that specify it**. The private
side is the implementation of the platform `specs/001-**` and `specs/002-**`
define; the public side is its specification. The overlapping text is comment,
docstring and status prose about that platform's own behaviour — the public
document's own subject matter. Median lead 29 minutes; **74.7 %** of all INWARD
rows are inside one hour and **90.1 %** inside a day, which is the signature of
one author writing spec and code in one sitting, in both orders.

### G5 — the one group where a second opinion is reasonable

126 rows, dominated by `docs/training/areas/05-evidence-gates-and-anti-bluff.md`
(64) reaching `specs/001-…/contracts/pipeline-cli.md` and `…/http-api.md`. Both
sides argue the same point about the platform's own `status.sh` exit-code
contract — a three-numbered refusal of the "benign state" reading — and the
private side is a training Q&A restating it.

**Judged NOT A DISCLOSURE**: the subject is the public contract's own subject,
the argument concerns an exit code the public document normatively defines, and
**no pedagogy, no participant, no session content and no personal data appears
on either side of any matched string.** The remaining 62 rows of the group are
short-class generic phrases and multi-format duplicates (`.md` / `.html` /
`.pdf` renders of one document each counted separately) across 13 digests.

**Recorded honestly**: this is authored curriculum material, it is private-first,
and the wording is reused. If the operator regards the *wording* of a training
area as a commercial asset distinct from the contract it describes, that is a
licensing judgement, not a boundary one — and it is the operator's to make. It
does not change the boundary verdict.

### G6 — the pair that looks worst and is designed

`workshop/docs/redaction-review-chapter-01.{md,pdf}` reaching
`specs/001-…/redaction-review-summary.md` and `…/tasks.md`, 6 rows over 3
digests. The public file **states its own boundary in its first paragraph**:
counts and verdict only, no chapter content, no personal name, no `pid`, no
transcript line reference, with the detailed review named by private path.
The overlap is the vocabulary of the category headings and the decision counts.
That is the design working, not failing.

### G8 — 50 rows, one digest, and a limit that is the protection

All 50 class-A `name`-class rows carry the **single** digest `04bc71a2`, all in
`specs/001-…/research/transcription.md`, from 10 private files across `workshop`
and `ai_interviewing`. That digest was resolved in
[`content-boundary-incident-2026-09-01.md` §12.2](content-boundary-incident-2026-09-01.md)
to a **machine-learning model-hub brand, two tokens — not a person**, by
re-implementing the gate's own `h()` and rebuilding the reported line's
capitalised runs.

**Honest boundary (§11.4.6): that resolution was NOT independently re-derived in
this session.** The identity evidence carried here is narrower and is stated as
such: same gate, same digest function, same 8-hex digest, same public file, same
class. The verdict rests on the earlier wave's adjudication, and a reader who
wants it re-derived should re-run §12.2's method rather than trust this sentence.

**Direction for these 50 rows remains UNDETERMINED and cannot be resolved with
this instrument**, because the gate redacts the matched text by design. That is
the same mechanism which keeps a real person's name out of an archived artefact:
**the protection and the blind spot are one thing**, and trading the first for
the second would be the wrong trade.

## Two checks that do not rely on the gate's own exonerations

Both bypass the detector entirely. Both were re-run in this session.

1. **The third party's given name is measured absent.** The candidate tokens are
   **derived programmatically from the private artefact's own path** — never
   typed, never written down — and searched as whole words across every tracked
   file of all ten in-scope public repositories, and separately across every
   untracked file of this public working tree. Of 5 derived tokens, 4 are
   ordinary words with 182–1,269 public files each; **exactly 1 has zero
   occurrences anywhere public**, tracked or untracked. §11.3's redaction holds.
2. **No judged row's private path was published if the path itself discloses.**
   The one private path whose basename carries that token is masked in the
   machine-readable artefact by the same derived rule, so the artefact cannot
   publish what the redaction removed.

## What this did NOT do

- **No public file was edited to remove a match.** No redaction was performed.
- **`.content-boundary-allow` was not touched.** No pair was added, and none is
  proposed. An allow-list entry buys a green exit at the cost of hiding the row
  from the next reader, and adding one here would assert boundary flows that do
  not exist.
- **`scripts/verify-content-boundary.sh` was not edited.** No window, floor,
  rank, bucket or filter was moved. The counts this document reports are the
  unmodified gate's.
- **No baseline was moved and no count was re-based.** The gate exits **1**.
- **Nothing about the incident's §3, §8B or §11.4 changed.** History still
  carries the wave-1 and wave-2 material; the provider purge is still unsent;
  the conversation with the third party is still the substantive remedy and is
  still the operator's to have.

## Honest boundary — read this before quoting any number above

1. **The corpus MOVED during both measuring runs, and the gate said so.** Run 1
   reported `corpus MOVED — 66 of 14,891 enumerated file(s) changed`; run 2
   reported `4 of 14,837` **and** `corpus DIFFERS from --expect-corpus`. So
   **neither 16,155 nor 9,945 may be quoted as the count of any single tree**,
   and this document does not quote either as one. The movement is concurrent
   work by other agents in this one checkout — a 13 % contraction of the private
   corpus, attributed above. **This is the reason the union of both runs is
   judged rather than either alone.**
2. **What the instability does not touch is the direction split**, which is the
   figure this document acts on. It has now been measured on five populations
   whose totals differ by more than 3,000 rows, and OUTWARD has landed between
   **79.1 % and 82.1 %** every time.
3. **Judgement is by GROUP, evidenced by inspection of the largest and the
   riskiest members — not by reading all 1,138 distinct digests one at a time.**
   G1 was resolved string-by-string (30 of 30). G5, G6 and the 182 rows whose
   lead exceeds 24 hours — the rows where the same-session mechanism is weakest —
   were opened individually. The remainder was judged on its group's measured
   shape. **The 51 rows seen only in run 2 were direction-measured but were not
   separately opened**; all 51 are `G2`, into `specs/001-…/contracts/*`, and they
   inherit that group's verdict rather than carrying an independent one. A reader who disagrees with a group can re-derive it from the artefact,
   which names every row's private path, public path and line.
4. **This judges class A only.** The other ~6,600 rows of the population —
   public reusables extracted from the private tree, the governance cascade, and
   a genuinely unassessed remainder — are **not** judged here and are **not**
   cleared by it.
5. **This says nothing about git history.** Every pass reads the working tree.

## What the operator is asked to decide next

Nothing here requires a decision to stand; the judgement is recorded and the
gate is unchanged. Three things are worth deciding, in this order:

1. **Nothing, for class A.** The recommended action of the decision packet has
   now been carried out and found **0 disclosures over 1,882 rows**. Option 2 of
   that packet — allow-listing classes B and C — is still **not recommended**:
   it would hide rows from the next reader, and its direction evidence remains
   file-level and sampled, which is weaker than what class A now has twice over.
2. **Option 3 — teach the gate direction.** This is now the only remaining
   option that raises precision without hiding a row, and its feasibility is no
   longer in question: the probe behind this document dated 16,599 rows
   across two runs, against 9,330 blobs, in about four minutes per run. Subtracting **OUTWARD** rows with the
   recall cost printed, exactly as the detector already prints its already-public
   subtractions, would remove ~80 % of class A from the reading queue **without
   asserting a single boundary flow that does not exist**.
3. **The G5 wording question**, if the operator regards a training area's
   wording as a commercial asset. That is a licensing decision and is not a
   boundary one.

## Re-derive rather than trusting this document

```bash
bash scripts/verify-content-boundary.sh --json --expect-corpus /tmp/cb.manifest
bash scripts/verify-content-boundary-judgement.sh            # 0 / 1 / 2
bash scripts/verify-content-boundary-judgement.sh --prove-failure
```
