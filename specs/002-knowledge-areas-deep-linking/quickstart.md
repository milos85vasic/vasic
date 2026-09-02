# Quickstart & Validation Guide — Knowledge Areas & Bidirectional Deep Linking

**Feature**: `specs/002-knowledge-areas-deep-linking` | **Date**: 2026-09-01

How to verify this feature is actually done, rather than looking done. Every success criterion
appears below with the command or procedure that measures it. A criterion with no entry here is a
specification defect — feature 001 shipped one and it was found late, which is why this document
exists as a Phase 1 artifact rather than an afterthought.

## 0. Before anything: re-derive the starting state

None of the figures in the specification may be quoted from a document. Each is re-derivable, and a
stale figure is worse than none because it will be believed.

```bash
# The platform is reachable and answering
curl -s -o /dev/null -w '%{http_code}\n' "$WORKSHOP_BASE/api/health"

# Corpus composition — 1,101 / 1,055 / 44 / 2, and 267 uncertain when last measured
jq -r .kind  workshop/curriculum/passages.jsonl | sort | uniq -c
jq -r 'select(.uncertain) | .pid' workshop/curriculum/passages.jsonl | wc -l
wc -l < workshop/curriculum/passages.jsonl

# Word-timing availability, per chapter — NOT corpus-wide (contract V2)
jq '.counts' workshop/curriculum/chapter-*/transcript.words.json

# The extracted taxonomy — counts and coverage, re-derived not quoted
jq '.track_count, .module_count' workshop/curriculum/chapter-*/knowledge/areas.json
jq '.term_count'                 workshop/curriculum/chapter-*/knowledge/terms.json
jq '.transcript_coverage'        workshop/curriculum/chapter-*/knowledge/coverage.json
wc -l < workshop/curriculum/chapter-*/knowledge/linkage.jsonl   # must equal the passage count

# The endpoints this feature adds do not exist yet
for p in /api/areas /api/terms /api/areas/x/questions; do
  printf '%s -> %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' "$WORKSHOP_BASE$p")"
done

# Export and diagram tooling — probe CAPABILITY, never just the name (contract V1)
for t in pandoc weasyprint pdftotext mmdc tesseract; do
  printf '%-12s %s\n' "$t" "$(command -v "$t" || echo ABSENT)"
done
```

**The last one is not a formality.** Every one of those tools resolves into a *user-local*
directory on this host, and this repository has already shipped a defect where a name on `PATH` was
a symlink into an unrelated cache: the binary answered a version query happily and rejected the flag
that mattered. A probe that tests for a name reports a tool that is not there.

## 1. Validating the taxonomy (US1)

| Criterion | How to measure it |
|---|---|
| **SC-001** — every published area and term has evidence | Join the taxonomy to the mention set; count entries with zero mentions. Must be **0**. Then run **G-KG-10**: publish one area with its mentions removed and confirm the check goes red. |
| **SC-002** — extracted terms are genuine, not noise | Draw ≥30 terms with a **recorded seed**, have a reviewer judge each, require ≥90%. Store the seed with the judgements so the sample is reproducible and the verdict is challengeable. A sample drawn after seeing the result is not a measurement. |
| **SC-003** — every passage is accounted for | Assert `attached + classified_unattached == registry_count`, exactly. Then **publish the attached proportion**. Do **not** compare it to a threshold — none exists, and research U2 says why. |
| **SC-004** — extraction is idempotent | Run twice over unchanged content; diff the taxonomy file byte-for-byte; assert **0** identifiers reassigned. Then **G-KG-13**: make one identifier depend on content and confirm red. |

**The judgement call to watch for**: SC-003 is the criterion most likely to be quietly "improved" by
lowering what counts as attached. The check is arithmetic — a total, not a ratio — precisely so that
it cannot be satisfied by redefining the numerator.

## 2. Validating the materials (US1)

| Criterion | How to measure it |
|---|---|
| **SC-005** — every area has all seven skeleton sections | Heading-presence check across every area source document. Any missing section fails. |
| **SC-006** — every substantive claim is cited or marked editorial | Parse each document into claims, resolve every citation, assert no claim is both unmarked and uncited. |
| **SC-007** — nothing is published without a review | Enumerate published areas; assert each has a review **newer than the materials it reviews**. A stale review fails; it does not warn. |

## 3. Validating the deep links (US2) — the heart of the feature

| Criterion | How to measure it |
|---|---|
| **SC-008** — every relationship is bidirectional | Enumerate **every** relationship, traverse it in reverse through the platform's own interface, count failures. Must be **0**. Not a sample — the whole set, because a one-way link is indistinguishable from a two-way one when read forward. |
| **SC-009** — media links land inside the cited span | For every media-backed citation assert `t_start ≤ landed < t_end`. **Publish the precision split** — how many resolved at word precision and how many at segment — alongside the pass rate. A 100% pass rate at segment precision and at word precision are different products. |
| **SC-010** — links survive correction and insertion | Replay the identifier-survival experiment already measured for passages, extended to the five new identifier kinds. Compare the full link set before and after **by hash**. |
| **SC-011** — unresolvable links fail loudly | Delete a target; assert a loud outcome. **G-KG-8** paired mutation: make the resolver re-point by nearest match; confirm red. |
| **SC-012** — redaction reaches everything | Redact a passage; assert its text is absent from **all eight** propagation targets. **G-KG-7** paired mutation: skip exactly one target; confirm red. |

**How SC-009 goes wrong silently**: a test that only asserts "landed inside the span" passes equally
for a word-precise link and a link that jumped to the start of a twenty-second segment. The
precision split is what distinguishes them, which is why it is published rather than summarised.

## 4. Validating search (US3)

| Criterion | How to measure it |
|---|---|
| **SC-013** — every kind is actually searchable | For each kind, plant a known target and require a query to return it. **Not a row count** — a row count cannot distinguish a populated index from a populated table nobody queries, and the corpus already advertises one kind with zero entries. |
| **SC-014** — every hit carries a resolving locus | Assert the property on **every** hit of the benchmark run. A hit without a resolving locus fails the run, not just that hit. |
| **SC-015** — retrieval quality over the new kinds | A stored benchmark of ≥20 query-to-expected-identifier pairs; the gate prints **per-query** outcomes, not only the aggregate — an aggregate hides which queries fail, and which ones fail is the useful information. |
| **SC-016 / SC-017** — latency survives corpus growth | Re-run the existing latency harness and **publish the before and after together**. A single after-figure cannot show a regression that stayed inside the threshold. |

**Also verify, though it is a contract rule rather than a criterion**: the suggestion path still
holds no embedder. Type-ahead must remain lexical; the structural guarantee is easy to lose by
adding "just one" semantic lookup for the new kinds.

## 5. Validating assessment (US4) — where the workshop exceeds its reference

| Criterion | How to measure it |
|---|---|
| **SC-018** — every served question has a resolving citation | Enumerate every served question, resolve every citation, count failures. Must be **0**. Record the reference module's measured value for the same property — **0 of 785** — beside it, so the comparison is measured rather than claimed. |
| **SC-019** — question-to-moment round trip | Traverse from question to cited moment and back for every eligible question; if exhaustive traversal is impractical, sample ≥30 with a recorded seed **and publish the population size**. |
| **SC-020** — assembled answers are marked | Schema assertion over the whole set. An unmarked assembled answer fails. |
| **SC-017a** — short and long differ by depth | Assert both sets exist per area; assert every long-set question cites **more than one distinct** passage. |
| **SC-017b** — every lesson section is assessed | Join sections to questions; count sections with zero. Must be **0**. |
| **SC-017c** — coverage is honest | Emit the **per-area** table. **G-KG-12** paired mutation: replace it with a mean; confirm red. |

## 6. Validating the surface (US5)

| Criterion | How to measure it |
|---|---|
| **SC-021** — accessibility and keyboard operability | Automated audit per view, zero Level A/AA violations; plus a keyboard-only traversal that **visits every deep-link affordance** and asserts each can be reached, activated and returned from. |
| **SC-022** — styling resolves through tokens | Run the design toolkit's own token conformance check **and** a literal-value scan. Both are required: the first proves the tokens are valid, the second proves they are actually used. Either alone passes a stylesheet that defines perfect tokens and ignores them. |
| **SC-023** — nothing existing was lost | Enumerate the four existing capabilities **before** the change; assert each is still reachable **after**. A before-and-after list, written down first — not a recollection. |
| **SC-029b** — interaction decisions are sourced | Traceability check over the interaction inventory; an entry with no named research finding fails. |

## 7. Validating export (US6)

| Criterion | How to measure it |
|---|---|
| **SC-024** — four formats, complete | File-existence matrix over every published area. **The reference achieves 25 of 34**; this criterion requires complete, and the comparison is stated so nobody later matches the reference and calls it done. |
| **SC-025** — exports are reproducible | Re-export unchanged material; **extract text and diff**. Extraction rather than byte comparison, because embedded timestamps make byte equality unachievable for some formats — and a criterion nobody can meet is worse than none. |

## 8. Validating the pipeline (US7) — the criterion that proves repeatability

This is the one that distinguishes a finished chapter from a finished feature.

| Criterion | How to measure it |
|---|---|
| **SC-015a** — all six traversals exercised | For each row of the connectivity matrix, pick **every** eligible origin and assert a result, or an explicit "none exists". A row with **zero exercised origins fails** — an unexercised traversal is unmeasured, not passing. |
| **SC-015b** — nothing is keyed on time | Inspect every stored relationship for its join key. **G-KG-6** paired mutation: introduce one time-keyed link; confirm red. |
| **SC-015c** — a new chapter needs no hand-assembly | Run the documented procedure against a **small synthetic chapter**; assert every output exists; assert the diff contains **no manually created structural file** and **no code change**. |
| **SC-015d** — the taxonomy is updated, not rebuilt | Capture the taxonomy before and after; assert **0** established identifiers changed; assert the contradiction report is non-empty when a contradiction was seeded. |
| **SC-015e** — incomplete never ships as complete | Withhold one required input; assert the run names exactly what is missing and publishes nothing. |

**Use a synthetic chapter, not the real one.** Re-running the real chapter tests idempotency, which
is SC-004. It cannot test whether a *new* chapter works, because every identifier it needs already
exists — the run would pass by matching, never by minting, and the minting path is exactly what a
second chapter exercises.

## 9. Validating honesty and governance

| Criterion | How to measure it |
|---|---|
| **SC-026** — limits document names every open defect | Cross-check recorded defects against the limits document; an unnamed defect fails. **Paired mutation**: remove one; confirm red. The two that must appear are the measured fabrication rate on unanswerable questions and the undefended topically-related-but-non-answering case. |
| **SC-027** — every check has a paired proof | The check registry. Note it prints known debt on every run **by design** — a zero exit means every check is accounted for, **not** that every check has a paired proof. Read the debt rows. |
| **SC-028** — every check is three-valued | Drive each into a could-not-determine condition — remove a dependency, make a service unreachable — and assert the **third** state, not either of the other two. |
| **SC-029** — no workshop content in public repositories | The content-boundary check across the public surface, including this specification directory. |
| **SC-029a** — no reference content in the workshop | The same check run in the **opposite direction**. **G-KG-16** paired mutation: scope it to outbound only; confirm red. |
| **SC-030** — no server-side CI anywhere | The existing fleet-wide gate. |

## 10. The eighteen gates and their proofs

Every gate in [`contracts/knowledge-graph.md`](./contracts/knowledge-graph.md) §8 owes a paired
mutation that turns it red. They are **owed**, not assumed — listed here so that a missing one is
visible rather than discovered.

```
G-KG-1  route manifest completeness          G-KG-10 unevidenced entity never served
G-KG-2  unprovenanced question withheld      G-KG-11 advertised kind actually retrievable
G-KG-3  long-set citation breadth            G-KG-12 coverage per area, never a mean
G-KG-4  precision declared                   G-KG-13 idempotency: zero mints on re-run
G-KG-5  offsets populated or field absent    G-KG-14 contradiction reported, not merged
G-KG-6  no time-keyed relationship           G-KG-15 unjoined fraction measured
G-KG-7  redaction reaches all eight targets  G-KG-16 content boundary, BOTH directions
G-KG-8  unresolvable link fails loudly       G-KG-17 synthetic chapter, no hand-assembly
G-KG-9  export unavailable ⇒ state 2         G-KG-18 incomplete names what is missing
```

**Every proof must include a case that runs the real entry point against the real tree.** This
repository has twice shipped a proof that could not fail: one whose control step failed so zero
mutations were ever reached, and one that exercised only sandboxed copies while the real entry point
could not start. Both reported green.

## 11. What this feature will not be able to claim

Stated here so it is not discovered during a review.

- **Answering is not fixed by this feature.** The measured fabrication rate on unanswerable
  questions stands, and the topically-related-but-non-answering case remains undefended unless the
  third clarification is resolved towards closing it. Retrieval over the new kinds is safe because
  it refuses rather than generates; generation about the new kinds is gated.
- **Word precision is available, not uniform.** 17.4% of words fall below the recorded confidence
  threshold and 0.48% of words join to no segment at all. Every mention states which precision it
  used; none claims more.
- **No coverage threshold is asserted.** SC-003 and SC-017c publish measured figures with no target.
  Extraction has since measured chapter 01 at **83.79% of transcript passages** and **91.54% of
  words** covered — and that is a *measurement*, not a bar the next chapter must clear. The moment a
  measured figure becomes a target it starts being optimised toward, which is why the criterion
  requires publication rather than a threshold.
- **No area count is promised.** Extraction has since produced **7 tracks, 37 modules and 137 terms**
  for chapter 01 (research U3, settled). That 37 sits near the reference's 34 is a coincidence of
  magnitude and **must not be cited as parity** — one is an interview-preparation corpus, the other
  an extraction from a single working session, and they are not comparable quantities. No count was
  aimed at, and matching the reference's would have meant inventing coverage.
- **Prose generation cannot run on this host.** There is no generative model here. Two of the three
  authorship options work today; the third needs an operator action first.
