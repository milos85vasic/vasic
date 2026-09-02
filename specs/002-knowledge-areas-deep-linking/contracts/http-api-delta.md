# HTTP API Contract — Delta for Knowledge Areas & Deep Linking

**Feature**: `specs/002-knowledge-areas-deep-linking` | **Date**: 2026-09-01

This is a **delta**. The platform's existing interface contract remains authoritative for everything
it already covers — the response envelope, the three-state contract, the header set, the error
taxonomy, the malformed-request rules. This document specifies only what this feature **adds** or
**changes**, and it restates none of the existing contract, so the two cannot drift.

## 1. Binding rules inherited, not restated

Every endpoint below inherits, without exception:

1. The **shared envelope** and its three states — a determined positive, a determined negative, and
   could-not-determine. A degraded backend is never rendered as an empty result set.
2. The **four resolution outcomes** — found, redacted, not present, could not determine — mapped to
   their existing status codes. Redacted is not absent, and could-not-determine is not absent.
3. **Malformed requests are a fourth thing**, not a fourth state, and use the existing error shape
   rather than borrowing the three-state vocabulary.
4. The **generation header**, so a client can tell which index generation answered it.
5. **No caching** on the three-state endpoints.

## 2. The route-manifest obligation — read this before adding any endpoint

The platform's server-unity verifier reads a route manifest and a contract, and it fails when a
contracted endpoint has no manifest row. Its counters are PASS, FAIL, UNDETERMINED and DEBT, and its
exit is three-valued: an undetermined result is **not** a pass.

Therefore, for every endpoint in §3:

- **R1** — it gets a row in the route manifest **and** a section here. An endpoint built but
  undeclared fails the verifier by construction. This is deliberate and must not be "fixed" by
  loosening the verifier.
- **R2** — an endpoint declared here but not yet built answers as a **not-built route**: `404`,
  with **no** status field, **no** error field, and **no** single-page-application shell in the
  body. The absence of a body is how a client distinguishes *"this route does not exist"* from
  *"the thing you asked for does not exist"*. Such a row is counted as **DEBT**, which is a standing
  visible notice rather than a failure — a known gap must never go quietly green.
- **R3** — an endpoint that returns the SPA shell instead of its own answer is a **failure**, not a
  cosmetic issue. The existing verifier already checks for this because it has already happened.

**Baseline to preserve or improve**: the verifier currently reports 25 PASS and 4 DEBT, the four
being permanent negative-route assertions. This feature adds rows; it must not add FAIL or
UNDETERMINED.

## 3. Endpoints added

### 3.1 `GET /api/areas` — the taxonomy

Returns published areas. Currently **404** — this endpoint does not exist.

Each area carries: its identifier, title, summary, ordinal, origin (`promoted` or `extracted`),
evidence certainty (`mixed` or `uncertain-only`), the chapters it draws evidence from, counts of its
lesson sections and of each question set, and a link to itself.

**A3.1.1** — an area with zero evidencing mentions is **never** returned. Publication requires
evidence (FR-008), so an unevidenced area appearing here is a contract violation, not an empty edge
case.

**A3.1.2** — the response reports the count of areas it holds back and why, rather than silently
returning a shorter list. A client cannot distinguish "five areas exist" from "eleven exist and six
failed publication" unless told.

**A3.1.3** — `uncertain-only` is carried on the wire, not computed by the client. An area resting
entirely on uncertain evidence must not be presented as a confident one (FR-012), and leaving that
derivation to each client guarantees one of them forgets.

### 3.2 `GET /api/areas/{area}` — one area with its materials

Adds to §3.1: the area's lesson sections in order, each with its identifier, heading, authorship
(`authored` or `assembled`) and citation count; the publication review record; and links to its
question sets, its evidence and its exports.

**A3.2.1** — every lesson section states its authorship. Assembled prose is never indistinguishable
from authored prose (FR-017).

**A3.2.2** — the publication review is present or the area is not served. There is no third
condition.

### 3.3 `GET /api/areas/{area}/evidence` — where this area appears

Returns the mentions evidencing the area: for each, the passage identifier, the text span, and —
for media-backed passages — the time span **and the precision that produced it**.

**A3.3.1** — `precision` is **required** on every entry carrying a time span, and takes exactly
`word` or `segment`. Omitting it is a contract violation, not a default.

**A3.3.2** — where precision is `word`, the word's timing confidence is carried. It is not
discarded because it is usually high: measured, the 5th percentile is 0.559 and 17.4% of words fall
below the recorded flag threshold, so "usually high" is precisely the reasoning that produces a
confident wrong link.

**A3.3.3** — a redacted passage contributes **no** mention and the count of omitted entries is
reported, matching how the existing cross-reference endpoint already behaves.

### 3.4 `GET /api/terms` and `GET /api/terms/{term}`

Terms with their canonical form, variants, certainty, owning areas, evidence count, and — on the
single-term response — the significance measure **and its inputs**, so the score can be audited
rather than trusted (FR-013).

**A3.4.1** — an `uncertain` term is marked on the wire and is never merged into the confident set by
the response shape.

**A3.4.2** — a term with zero evidence is not returned. If its last evidence was redacted, the term
is withdrawn from the taxonomy entirely, and the withdrawal is reflected here rather than only in
the display layer.

### 3.5 `GET /api/areas/{area}/questions` — the practice sets

Returns the area's short and long sets. Each question carries its identifier, set, kind, prompt,
choices where applicable, answer where applicable, category, difficulty, **answer authorship**, the
lesson sections it assesses, and **its citations**.

**A3.5.1 — the central invariant of this feature.** A question is served **only** if it carries at
least one citation and **every** citation resolves. A question whose citation resolves to
`redacted`, `not present` or `could not determine` is **withheld** (FR-036, D4). It is not served
with a warning, not served with the citation stripped, and not served with an empty citation list.

**A3.5.2** — each citation carries enough to jump: the passage identifier, the chapter, the time
span where the passage is media-backed, the precision, and a link that lands there.

**A3.5.3** — every question in the `long` set cites **more than one distinct** passage. This is the
structural distinction between the sets (D-KG-7); a long-set question with one citation is a
contract violation.

**A3.5.4** — an assembled answer is marked as assembled wherever it appears (FR-038). A client must
not have to infer it.

**A3.5.5** — the response reports how many questions were withheld under A3.5.1 and why. A silently
shorter set is how a provenance guarantee decays into a claim without anyone noticing.

### 3.6 `GET /api/areas/{area}/coverage` — the honest number

Returns the coverage measurement the specification requires: which lesson sections are assessed by
at least one question, and the proportion of the area's evidencing passages cited by at least one
question.

**A3.6.1** — the per-area figures are returned, **never** only an aggregate. An average across areas
is how a well-covered area conceals an empty one (SC-017c).

**A3.6.2** — **no threshold is expressed** in this response, and no field says "pass". The density
of assessable substance per passage has not been measured for this corpus (research U2), so a target
here would be a guess that later gets optimised toward.

**A3.6.3** — a section with zero questions is listed explicitly, not omitted from the enumeration.

### 3.7 `GET /api/passages/{pid}/knowledge` — what this moment teaches

The reverse direction, and the endpoint that makes the recording navigable: given a passage — which
a player resolves from a playhead position through the existing transcript window — return the areas,
terms, lesson sections and questions attached to it.

**A3.7.1** — every entry is reachable in **one** step from this response. The requirement is
one-step reachability (FR-019), so a response that returns identifiers a client must resolve
separately does not satisfy it.

**A3.7.2** — the four outcomes apply to the passage itself. A redacted passage returns the redacted
outcome, not an empty knowledge list, because an empty list reads as *"nothing is taught here"*.

**A3.7.3** — when nothing is attached, the response says the passage is **unattached and why**
(FR-010), rather than returning an empty list. Every passage is accounted for; "no areas" and "not
yet classified" are different facts.

### 3.8 `GET /api/graph/traverse` — the connectivity matrix, exercised

Traverses from any addressable thing to related things across all four content kinds, in either
direction, with a depth bound.

**A3.8.1** — traversal is **cycle-safe** and reports truncation rather than stopping silently
(FR-026), matching how the existing cross-reference endpoint already reports truncation.

**A3.8.2** — no traversal is keyed on a time. Every hop is an identifier hop (FR-033b).

**A3.8.3** — a hop whose target cannot be resolved reports the resolution outcome for that hop and
continues; it is never dropped from the response, because a dropped hop is indistinguishable from a
hop that never existed.

### 3.9 `GET /api/areas/{area}/export` — the four formats

Reports which of the four formats exist for an area and links to them.

**A3.9.1** — an area without a publication review exports nothing and **says so** (FR-048).

**A3.9.2** — when the export toolchain is unavailable, the response is **could not determine**, not
an empty format list (FR-049). The measured trap this guards against is real in this repository: a
tool that answered a version query and rejected the flag that mattered, because the name on `PATH`
was a symlink into an unrelated cache. Presence of a name proves nothing; capability must be probed.

## 4. Endpoints changed

### 4.1 `GET /api/search` — locus, offsets, new kinds, filters

**C4.1.1 — new kinds.** `area`, `term`, `lesson_section` and `question` join the existing kinds. The
corpus block that already advertises the indexed kinds must list them, and a kind advertised with
zero indexed entries is a **failure** — the corpus currently advertises one such kind, and this
feature must not add more.

**C4.1.2 — locus.** Every hit carries a locus: its containing unit and its position within it. A hit
whose locus does not resolve is not returned (FR-030).

**C4.1.3 — match offsets, the field that is currently a promise.** The hit already declares a list
of offset pairs and the construction path sets it **unconditionally to empty**; the snippet is
generated with empty match delimiters, so nothing anywhere carries an in-string position. Exactly two
outcomes are acceptable:

- **populate it** — the lexical leg produces real offsets; or
- **remove it** — and state its absence in the contract.

Leaving a field that promises a position and never carries one is forbidden. It is the
blind-instrument shape the governing principles name, and it sits in the precise field the *"link
exactly where they appear"* requirement lands on.

**C4.1.4 — legs differ, and must say so.** The semantic leg does not know which terms matched and
cannot produce offsets. It must report that it **cannot** produce them — which is a different fact
from producing none. An empty list meaning both is exactly the collapse this contract exists to
prevent.

**C4.1.5 — filters.** Results are filterable by kind and by area (FR-032), and the applied filter is
echoed in the response so a client can tell a filtered empty result from an unfiltered one.

**C4.1.6 — thresholds survive growth.** The existing latency thresholds are not renegotiated by the
corpus growing (SC-016, SC-017). The before-and-after figures are published together so a regression
is visible rather than merely absent.

### 4.2 `GET /api/suggest` — areas and terms

**C4.2.1** — area and term names join the suggestion set (FR-031).

**C4.2.2** — the suggestion path **still never embeds**. Type-ahead stays lexical; the structural
guarantee that the suggestion service holds no embedder is preserved, not weakened for the new kinds.
The measured basis is unchanged: semantic embedding under load has been observed in the tens of
seconds, which cannot meet a 200 ms budget.

### 4.3 `POST /api/ask` — bounded by an open clarification

**C4.3.1** — retrieval over the new kinds is extended. This is safe because the retrieval gate
refuses before any model runs.

**C4.3.2** — **generation about areas, lessons and questions is gated** on the third clarification.
Until it is answered, this endpoint does not generate answers about the new kinds.

**C4.3.3** — if generation is enabled, a verification layer checking the answer against the
**question** must exist and be measured first (FR-051). The existing four layers all verify the
claim against the **passage**; none verifies it against the question, which is why a topically
related fragment that does not answer what was asked passes all four.

**C4.3.4** — a verifier that was requested and could not load reports **could not determine**. It
does not degrade silently to the weaker verifier (FR-052).

### 4.4 `GET|POST /api/progress` — areas and question sets

**C4.4.1** — progress covers areas and question sets in addition to what it already covers.

**C4.4.2** — progress **survives a content re-ingest** (FR-039). The reference module deliberately
preserves its progress table while wiping everything else on rebuild; that behaviour is ported. A
learner's history is not a derived artifact.

## 5. Gates and their paired mutations

Every gate here owes a proof that it fails when its condition is broken (FR-053, SC-027). A gate
never observed failing is not known to work.

| Gate | Asserts | Paired mutation that must turn it red |
|---|---|---|
| **G-KG-1** | every endpoint in §3 has a manifest row and answers per R1–R3 | remove one manifest row |
| **G-KG-2** | a question with an unresolvable citation is withheld | serve it with the citation stripped |
| **G-KG-3** | every long-set question cites more than one distinct passage | admit a single-citation question to the long set |
| **G-KG-4** | every time-carrying entry declares its precision | omit precision and default it to `word` |
| **G-KG-5** | offsets are populated, or the field is absent and its absence stated | return an empty offset list from a leg that could produce offsets |
| **G-KG-6** | no relationship is keyed on a time | introduce one time-keyed link |
| **G-KG-7** | redaction reaches all eight propagation targets | skip exactly one target |
| **G-KG-8** | an unresolvable link fails loudly | make the resolver re-point by nearest match |
| **G-KG-9** | an unavailable export toolchain yields could-not-determine | return an empty format list instead |
| **G-KG-10** | an unevidenced area or term is never served | publish one with its mentions removed |
| **G-KG-11** | a kind advertised as indexed has retrievable content | advertise a kind with an empty index |
| **G-KG-12** | coverage is reported per area, never only as an aggregate | replace the per-area table with a mean |

**G-KG-11 is stated as retrievability, not as a row count, on purpose.** A row count cannot
distinguish a populated index from a populated table nobody queries, and the corpus already contains
one advertised kind with zero entries — which a row-count check would have caught only by accident
and a retrieval check catches by construction.

## 6. Traceability

| Requirement | Where in this contract |
|---|---|
| FR-019, FR-020 | §3.3, §3.7 |
| FR-021 | §3.3 A3.3.1–2, §5 G-KG-4 |
| FR-023, FR-024 | §1.2, §3.8 A3.8.3, §5 G-KG-8 |
| FR-026 | §3.8 A3.8.1 |
| FR-027 | §5 G-KG-7 |
| FR-028 to FR-033 | §4.1, §4.2 |
| FR-033a, FR-033b, FR-033c | §3.8, §4.1 |
| FR-034a, FR-034b | §3.5 A3.5.3, §3.6 |
| FR-035, FR-036 | §3.5 A3.5.1, §5 G-KG-2 |
| FR-037 | §3.5 A3.5.2 |
| FR-038 | §3.2 A3.2.1, §3.5 A3.5.4 |
| FR-039 | §4.4 C4.4.2 |
| FR-048, FR-049 | §3.9 |
| FR-050 to FR-052 | §4.3 |
| FR-059 | §2 |

**Requirements deliberately not covered here, and where they live**: taxonomy extraction and
promotion (FR-006 to FR-013), materials authorship and review (FR-014 to FR-017), the repeatable
pipeline (FR-033d to FR-033g), the learning surface and its visual identity (FR-040 to FR-044b), and
the governance requirements (FR-053 to FR-058) belong to the knowledge-graph contract, the pipeline,
the front end and the platform's existing governance instruments respectively. They are listed so
their absence here reads as a boundary rather than as an omission.

## 7. Unverified register

- **U1 (from research)** — whether the full-text engine exposes match positions through a supported
  interface, or whether offsets must be recomputed by re-locating query terms in the matched text.
  This decides whether C4.1.3 is cheap or a second pass, and it has a correctness edge: a
  recomputation can disagree with what the index actually matched, particularly under the prefix
  matching the lexical leg applies to the final query token. **C4.1.3 must not be implemented on an
  assumption about this.**
- **U4 (from research)** — whether an entailment model loads on this host. C4.3.3 and C4.3.4 depend
  on it. The platform's code claims it refuses to degrade silently; that claim has not been observed
  for this feature, and a claim is not a measurement.
