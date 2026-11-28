# T462 — Contract sections + route-manifest rows for `screen_text`

**Source:** `specs/008-unified-workshop-platform/tasks.md:3266` (was: `002/T139`)
**Status:** `[ ] UNBUILT [P]` — unbuilt, planned, **no blocker; owner: implementer — unblocked today**

---

## 1. Full task text and source back-reference

Quoted verbatim from `specs/008-unified-workshop-platform/tasks.md` (lines 3266–3293):

```
- [ ] T462 (was: 002/T139) [UNBUILT] [P] Add the contract sections and route-manifest rows for the `screen_text` kind, its evidence entries and the modality and interval-bound fields (FR-059→unified FR-274). Gate **G-KG-1**. This task is also what moves gates **G-OCR-1**..**G-OCR-11** into `contracts/`, where the gate-attachment closure check enumerates them — they are attached to task lines already, so that check must still print `unattached: 0` after this task lands (FR-059→unified FR-274) **MERELY UNWRITTEN, AND DELIBERATELY NOT DONE IN THIS PASS — measured 2026-09-03.** No capability and no operator decision blocks the contract text. It was left alone anyway, because doing it first would move eleven `G-OCR-*` ids into `contracts/` while **none of the eleven gates exists**, publishing gate identifiers for gates nothing builds. The gate-attachment closure check would still report `unattached: 0` — every id is already carried on its task line — so the check would stay green while the contract described a capability the tree does not have. That is a green instrument reporting on the wrong question, and the correct order is gates first, contract second. Measured before and after this pass with the corrected extractor: **19 ids, `unattached: 0`**, unchanged
```

Scope per the task body: contract sections + route-manifest rows for
- the `screen_text` kind
- its evidence entries
- the modality field (FR-186 → unified)
- the interval-bound field (FR-184 → unified)
Governed by FR-059→unified FR-274 (every added endpoint must be declared in the interface contract AND the route manifest, and probed against the running binary) and Gate G-KG-1.

**Predecessor state:** T461 (screen_text indexing / G-KG-11) is `[x] DONE 2026-09-16` — `screen_text` was added to `kindVocabulary` (`pkg/search/kind_population.go`) and `baseIndexedKinds` (`pkg/search/service.go`); `pkg/search/screentext_kind_test.go` added; `G-KG-11-screentext` and `G-KG-11-screentext-evidence` registered in `check-registry-002.tsv`. So the kind exists and is retrievable-by-planted-target; T462's contract/manifest layer is what remains.

Spec `specs/008-unified-workshop-platform/spec.md` defines the screen_text block (FR-183…FR-191, all "specified, unbuilt") and FR-274 (the contract+manifest obligation). There is **no** `data-model.md` in spec 008; the modality and interval-bound fields are specified in-spec at FR-184 / FR-186 rather than in a separate data model.

---

## 2. Contract sections that exist vs. route-manifest rows needed

### 2.1 Contract sections that EXIST (relevant to screen_text)

| Contract file | Section | What it covers | screen_text coverage |
|---|---|---|---|
| `specs/002-knowledge-areas-deep-linking/contracts/knowledge-graph.md` | §1.1 `screen_text` — a fifth kind, not a fifth registry | M6: screen_text mints through existing minter/resolver, not a fifth registry; G-OCR-2 gate | **Ingestion/minter contract only** — says screen_text is deliberately NOT yet advertised as retrievable |
| `specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md` | §4 "Endpoints changed" | 4.1 GET /api/search (C4.1.1–C4.1.6); 4.2 GET /api/suggest (C4.2.1–C4.2.2); 4.3 POST /api/ask (C4.3.1–C4.3.4); 4.4 GET|POST /api/progress (C4.4.1–C4.4.2) | **None.** C4.1.1 ("new kinds") lists `area`, `term`, `question` — deliberately NOT screen_text. There is no screen_text section and no C4.1.1a. |
| `specs/008-unified-workshop-platform/spec.md` | On-screen text (OCR) block | FR-183…FR-191 | **Spec text, not a contract section** — all specified and unbuilt |

### 2.2 Route-manifest rows for screen_text

File: `workshop/platform/gates/route-manifest.tsv`

**Row that EXISTS** (line 98, added 2026-10-21):

```
GET	/api/search?q=index&kinds=screen_text	SERVED	200,503+json	002.4.1a	spec 008 T462 / FR-274: `screen_text` is accepted by the closed kind vocabulary (pkg/search/kind_population.go) so this probe is never a 400; the corpus block advertises it only on a non-empty disclosable census (G-KG-11), and nothing produces a row until spec 008 T449 lands, so an empty result is the EXPECTED answer today. Contract clause C4.1.1a in specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md. Row added 2026-10-21 and NOT yet exercised against a served container by this change (the live instance was deliberately not queried).
```

- Contract column: `002.4.1a`
- Cited contract clause: `C4.1.1a` in `specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md`

**Rows NOT yet present** (per T462's scope, still to write):
- Contract section + manifest row for screen_text **evidence entries** (evidence/retrieval surface for the kind)
- Contract documentation for the **modality** field (spoken / on-screen, FR-186)
- Contract documentation for the **interval-bound** field (visibility-interval bound, FR-184)
- The gate-migration work: moving `G-OCR-1`…`G-OCR-11` into `contracts/` (T462 explicitly deferred this; only G-OCR-2 currently exists, plus G-KG-11-screentext/screentext-evidence)

---

## 3. Blockers and conflicts

### Conflict (load-bearing): manifest row cites a contract clause that does not exist

The route-manifest row at `route-manifest.tsv:98` (added 2026-10-21) cites contract `002.4.1a`, with note text *"Contract clause C4.1.1a in specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md"*. **`C4.1.1a` does not exist.** §4 of http-api-delta.md contains only C4.1.1–C4.1.6, C4.2.1–C4.2.2, C4.3.1–C4.3.4, C4.4.1–C4.4.2. There is no screen_text section anywhere in that file.

Consequence: the manifest row is ahead of the contract text — it declares a route whose contract citation points at an unwritten clause. This is exactly the class of defect FR-274 exists to prevent ("an endpoint built but undeclared is a failure by construction"; here the inverse: a route declared with a contract citation that resolves to nothing).

### Deliberate deferral (not a blocker)

T462's own note says it was "**MERELY UNWRITTEN, AND DELIBERATELY NOT DONE IN THIS PASS — measured 2026-09-03**," with the rationale that moving eleven `G-OCR-*` ids into `contracts/` while none of the eleven gates exists would publish gate identifiers for gates nothing builds. The recorded order is **gates first, contract second**. Measured before/after that pass: 19 ids, `unattached: 0`, unchanged. No capability or operator decision blocks the contract text — the work is simply unstarted.

### Related state

- T461 (screen_text indexing/G-KG-11) is DONE, so `screen_text` is a valid indexed kind and the closed vocabulary accepts it (the manifest row's probe is "never a 400").
- Nothing produces a real `screen_text` row until spec 008 T449 (unified 002/T126) lands; until then an empty search result for `?kinds=screen_text` is the expected answer, and the manifest row's `SERVED` state is not yet exercised against a served container.
- Gate G-KG-1 (`TestGateKG1_TaxonomyEndpointsHaveManifestRows`) and G-KG-1-changed exist in `check-registry-002.tsv`; the screen_text evidence entries `G-KG-11-screentext` / `G-KG-11-screentext-evidence` are registered.
- T462 is NOT blocked on any predecessor; blocker is "none but the work." It can be picked up by the implementer today.

### What T462 still needs to close

1. Write the missing contract section(s) for screen_text in `specs/002-knowledge-areas-deep-linking/contracts/http-api-delta.md` — at minimum a C4.1.1a-equivalent clause (or new §4.x) documenting `GET /api/search?kinds=screen_text`, the modality field, the interval-bound field, and evidence-entry behavior — so the existing manifest row's `002.4.1a` / `C4.1.1a` citation resolves to real text (or re-point the manifest row to an existing clause).
2. Add any remaining route-manifest rows for screen_text evidence entries.
3. Decide, with the operator, whether to now move `G-OCR-1`…`G-OCR-11` into `contracts/` (T462's deferred gate-migration half) now that gates exist, or keep the "gates first, contract second" ordering.
4. Exercise the manifest row against a served container (it was deliberately not queried when added).
