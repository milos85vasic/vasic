# Phase 0 Research — Workshop Curriculum Platform

**Feature**: `specs/001-workshop-curriculum-platform` | **Date**: 2026-09-01

Consolidated from three research streams. Each stream's full evidence — commands, real output,
and its own UNVERIFIED register — is in `research/`:

| Stream | File | Lines |
|---|---|---|
| Transcription | [research/transcription.md](./research/transcription.md) | 1,249 |
| Search architecture | [research/search-architecture.md](./research/search-architecture.md) | 837 |
| LLM bridging | [research/llm-bridging.md](./research/llm-bridging.md) | 735 |
| Reference recon | [../../docs/workshop-curriculum/RECON.md](../../docs/workshop-curriculum/RECON.md) | 1,544 |

## Headline: four assumptions the feature request rests on are false

Stated first because every downstream decision follows from them.

1. **`ai_interviewing` is not containerised.** Zero container definitions. It runs as a native Go
   binary (`platform/bin/aicur`) serving an Angular frontend. "Run it through the containers same
   way" describes something that does not exist.
2. **No speech-recognition engine is installed.** `/usr/bin/whisper` is `whisper-1.3.1-alt1`, a
   microphone-loopback GUI by a different author. `import whisper` fails.
3. **No generative model exists.** ollama serves exactly two models and they are the *same*
   embedding model (`jina-bert-v2`, 160.28M, an encoder with no LM head). The entire model store
   is 309 MB — too small to hold a decoder. User Story 4 cannot run today under any design.
4. **Lumen cannot index media, and its chunk IDs are content-derived.** Both are disqualifying
   for requirements the spec states literally. See D-SEARCH-1 and D-SEARCH-2.

---

## D-TRANS-1 — Speech recognition engine

**Decision**: `faster-whisper` (CTranslate2 backend), CPU int8, model `large-v3-turbo`, installed
into a project-local virtual environment.

**Rationale**: it is the only candidate that returns `avg_logprob`, `no_speech_prob`,
`compression_ratio` and per-word probability. FR-003 requires unclear speech to be *marked* rather
than guessed; without a confidence signal that requirement has nothing to key on and becomes
editorial opinion. CTranslate2 also avoids the ~900 MB PyTorch wheel.

**Alternatives considered**:
- *ollama `/v1/audio/transcriptions`* — the endpoint is real (verified: it validates content-type,
  then model presence). But the binary's Whisper strings are an **encoder** projecting audio into
  an LLM token space (`AudioProjector`, `<|audio_bos|>`); `word_timestamps`, `avg_logprob` and
  `no_speech_prob` appear nowhere in it. No timestamps kills FR-002/SC-003. Rejected on evidence,
  not assumption — "assume it can't" would have been wrong about the endpoint existing.
- *`whisper.cpp` 1.9.1* — retained as fallback. Its ALT packaging hard-depends on the CUDA and
  Vulkan backends, on a machine where this repo deliberately excluded the GPU after an i915 fault
  silently corrupted embeddings.
- *OpenAI hosted API* — rejected by decision D1 (local-only).

**Measured**: recording is **01:55:28.75 (6928.75 s)**, H.264 1080p24, AAC-LC 48 kHz. The
"stereo" is **dual-mono** (L−R difference −90.3 dB), so channel-based speaker separation is
impossible. Uniformly AGC-compressed. 8 long silences totalling 41.33 s (0.597%).

**Estimate**: 40–80 minutes idle — **UNVERIFIED**, and roughly doubled under current load.
Settled by a 5-minute calibration on an already-extracted 300 s sample.

## D-TRANS-2 — Speaker attribution is human, not automatic

**Decision**: attribute speakers by human review. Do not run diarization.

**Rationale**: both cues that make diarization tractable are *measurably absent* — no channel
separation (dual-mono) and AGC has flattened loudness differences. pyannote would reintroduce the
PyTorch dependency D-TRANS-1 avoids, plus a gated model token, to produce a result the audio does
not support. FR-005 explicitly permits stating inability.

## D-TRANS-3 — Accuracy is measured on the audio timeline, not on passages

**Decision**: word error rate against a blind human reference over **≥30 seeded, stratified
30-second audio windows**.

**Rationale**: this is the load-bearing choice in the whole measurement design. Sampling *machine
passages* makes whole-region deletions structurally invisible — a dropped span produces no passage
to sample, so accuracy is biased upward precisely where the transcript is worst. Sampling the
timeline cannot miss them. Thirty 30 s windows span well over 30 passages, so SC-002's wording is
satisfied on its own terms while the bias is removed.

Normaliser hashed and frozen before first measurement. Companion metrics: coverage-gap rate
(SC-001), timestamp error median/p95 against the 5 s bound (SC-003), speaker accuracy (FR-005).
Honest cost: 1–2 hours of human transcription.

## D-TRANS-4 — Coverage is provable by construction

**Decision**: chunk at ≤300 s cut *inside measured silence*, `condition_on_previous_text=False`,
atomic checkpoint per chunk, resume by deterministic re-partition plus hash match.

**Rationale**: passage spans ∪ VAD non-speech spans must equal `[0, 6928.75)` exactly — so SC-001
becomes an arithmetic identity rather than a judgement. The same setting that makes it resumable
(`condition_on_previous_text=False`) also suppresses Whisper's repetition-loop hallucinations. The
8 measured silences are a free VAD test fixture.

FR-007 is already implemented by `workshop/scripts/extract-videos.sh`, which verifies per-part,
archive and extracted-video hashes. The pipeline **invokes** it; it does not reimplement it.

## D-TRANS-5 — The notes PDF is a cross-check, never ground truth

**Decision**: use the PDF for section structure, a proper-noun gazetteer, and coverage
cross-checking only.

**Rationale**: it has a real text layer (3,034 words — no OCR needed, so `tesseract` is not on the
path) but it is a **summary**: ~26 words per minute of recording. It demonstrably errs, rendering
"Spatkit" for SpecKit and "Llama CPP" for llama.cpp. That is concrete evidence for the spec's rule
that the recording wins.

---

## D-SEARCH-1 — Lumen chunk IDs cannot carry passage identity

**Decision**: build a passage-identity (PID) layer. Do **not** cite Lumen chunk IDs.

**Rationale — measured, by controlled three-run re-index**:

| Change | Observed |
|---|---|
| Fix one typo inside a section, line numbers unchanged | ID changed `4b98e295c112a429` → `610e608a50f273a6` |
| Prepend a section, shifting every later section by 4 lines | **all IDs unchanged**; line ranges moved |

The IDs are **content-derived and position-independent** — precisely one of the two forms FR-037
forbids, and the one that breaks on the operation this feature performs most often (FR-038 human
corrections). Built on them, **SC-016 would score 0% for every corrected passage, silently** —
links keep rendering, they just point elsewhere. The IDs are not exposed through the CLI or MCP
anyway, leaving only a positional key, which run 3 shows moves. Both available keys fail, in
opposite directions.

**Design**: ULIDs minted once at ingest, written back into the source artifact as
`<!-- pid: … -->` anchors, plus a committed registry (`passages.jsonl` → `passages.db`) carrying a
`content_hash` column *named so nobody mistakes it for identity*. Citations, cross-references and
redactions all resolve through the registry. Code passages get honestly weaker identity
(symbol-path keyed with a rename alias table), and that limit is documented rather than hidden.

**Alternatives considered**: reuse Lumen IDs (rejected on the measurement above); positional keys
(rejected by run 3); content hashes (identical to the failing case).

## D-SEARCH-2 — Two search paths, not one

**Decision**: lexical FTS5 prefix index for type-ahead; semantic embedding search on submit.

**Rationale — measured under load**: a query embedding takes **18.2–21.0 s**, plus a fixed
~2,202 ms indexer setup per CLI process. An FTS5 prefix index over the 58,726 real symbols builds
in 0.93 s / 15.9 MB and answers at **p50 0.25 ms, p95 9.58 ms, p99 19.2 ms**. SC-005's 200 ms
budget is unreachable semantically and comfortable lexically, leaving ~190 ms for HTTP and paint.
FTS5 works in `modernc.org/sqlite`, already in `ai_interviewing`'s `go.mod` — no new dependency.

Suggestions therefore return *navigational targets*; submit fuses lexical and semantic.

## D-SEARCH-3 — Media is indexed via text reduction, or not claimed

**Decision**: index transcripts, documentation, code and diagram *descriptions*. Audio and video
are searchable **through their transcripts and captions**, not directly.

**Rationale**: Lumen's extension allowlist is a compile-time `var` with no override — 25 code and
doc extensions, and **no** image, audio, video, PDF, HTML or SVG. Measured: zero indexed files for
`.sh .html .css .txt .svg .mmd .puml .vtt .srt .pdf`, against 55 tracked `.sh`, 146 `.html` and 32
`.css` in the root module. That is exclusion, not absence. The spec's "all content indexed" is
therefore satisfied by reduction to text, and the boundary is stated in the docs (FR-031) rather
than implied away.

## D-SEARCH-4 — Health checks must not gate degradation

**Decision**: derive the three-state contract from the *search call's* own result, never from a
health probe.

**Rationale — measured in one MCP session**: `health_check` returned `Status: OK / service is
healthy` in 2 ms, and seconds later `semantic_search` failed with `all embedding servers
exhausted … context deadline exceeded`. It is a liveness probe, not a saturation probe.
Separately, Lumen returns `"No results found. | Warning: Index is being updated in the
background…"` as one unstructured string — the service must parse that and promote it to
`Degraded`, never forward it as "no results". The anti-pattern already ships in this repo:
`ai_interviewing/.../search.component.ts` renders backend errors as the empty state.

## D-SEARCH-5 — Generations and atomic swap

**Decision**: index generations with a verification gate and atomic swap; ingest holds an
exclusive lock; reserved embedding capacity for interactive queries.

**Rationale**: measured during the live rebuild, `chunks` moved 58,734 → 58,744 while
`last_indexed_at`/`root_hash` still advertised the previous generation — a half-written, readable
index. Reserved capacity is a hard requirement, not a nicety: SC-006 fails on every chapter ingest
without it.

---

## D-LLM-1 — Provider seam with four adapters

**Decision**: a three-method `Provider` interface with adapters `none` (default), `extractive`,
`ollama`, `openai_compatible`. Config resolution mirrors `scripts/lumen-reindex.sh` (env → config
→ live probe → fallback), the repo's existing precedent. Defaults `enabled: false`.

**Rationale**: `openai_compatible` covers LM Studio, HelixLLM (its own brief says
OpenAI-compatible, and `SSL_CERT_FILE` already trusts its cert) and every external vendor — so
FR-023 costs two adapters, not many. Defaulting to disabled means a fresh clone can neither leak
nor bluff. FR-025 is enforced by **separate route trees** (compile-time), not a runtime check.

**Alternatives considered**: depend on `LLMProvider` (`git@github.com:HelixDevelopment/LLMProvider`),
which genuinely exists at `…/Projects/helix_translate/LLMProvider` with 43 adapters and exactly
the interface shape wanted — but its module path `digital.vasic.llmprovider` is unresolvable and
it carries `replace digital.vasic.models => ../Models`, a relative-path dependency on a sibling
checkout absent from `.gitmodules`. **Copy the interface shape, not the dependency.**

**Trap recorded**: `~/helix-agent` is a 23.7 MB Go binary that is **not** an LLM agent — `--help`
shows `-bind-addr` (SWIM), `-wg-key` (WireGuard), `-etcd-endpoints`. It is a cluster mesh node.
HelixLLM appears in this repository only as portfolio marketing copy.

## D-LLM-2 — Four-layer grounding, refusal by default

**Decision**: L1 calibrated retrieval gate (`min_score` **and** `min_margin`); L2 JSON-schema-
constrained generation where `"minItems": 1` on citations makes an uncited claim structurally
undecodable; L3 deterministic citation-ID set membership against the PID registry; L4 support
verification (embedding floor, then batched entailment). Any layer failing ⇒ refuse the whole
answer; never strip claims silently.

**Rationale**: the margin test is what catches the near-miss case ("what Docker version did he
say?") that scores high on similarity while being unanswerable. **SC-009 is unreachable without
L3** — attaching a citation is easy, proving it points at a real passage requires a deterministic
set check, which costs microseconds. The design deliberately inverts the usual trust relationship:
deterministic checks gate a probabilistic generator.

**Depends on D-SEARCH-1**: L3 requires stable passage IDs. Since Lumen's are not, the PID layer is
a prerequisite for grounding, not an independent nicety.

## D-LLM-3 — SC-010 needs adversarial questions

**Decision**: the ≥10 unanswerable questions are drawn from a 10-item adversarial taxonomy —
near-miss attribute, false premise, uncomputable aggregate, misattributed speaker,
lexically-overlapping-but-unanswerable, redacted passage, inaudible segment, and others.

**Rationale**: ten astrophysics questions would pass any threshold and prove nothing. Recorded
honestly: 10/10 at temperature 0 is *reproducible*, not *generalising*, and must never be
paraphrased as "never fabricates".

## D-LLM-4 — Privacy is enforced, not configured

**Decision**: resolved-address allowlist (`net.LookupIP` + `IsLoopback`, not string matching);
egress-denied network namespace with a **negative control** — `curl https://example.com` from
inside the namespace MUST fail; packet capture asserting zero non-loopback packets across the full
20-answer and 10-refusal runs.

**Rationale**: a config flag is not a guarantee. The negative control is what upgrades "we
observed no egress" into "egress was impossible". Hostname string-matching is not a security
boundary, so `locality` is **declared**, never inferred.

## D-LLM-5 — "Instant answers" is not achievable; route the ambition

**Decision**: answering is asynchronous. The `extractive` adapter is the default *working* path.

**Rationale — measured**: three identical two-word embed calls, model resident, minutes apart:
**20.16 s / 11.05 s / 0.10 s** at load 8.25. That 200× spread is queue wait, not compute variance
— ollama serves one queue and generation contends directly with indexing. Estimated CPU-only
generation (UNVERIFIED, method shown): ~21 s (1.5B) / ~42 s (3B) / ~95 s (7B) **idle**, ×1.4 with
verification. So "instant" is off by two orders of magnitude and no prompt engineering closes it.

Where the ambition *is* reachable: search and autocomplete (SC-005/SC-006 are comfortable). The
`extractive` adapter answers in ~0.3 s, is genuinely grounded, **cannot fabricate**, and works
today with zero generative capability.

Enabling the GPU is rejected outright — this repository already refused that bargain once, after
Vulkan silently corrupted the index.

---

## Open items carried into Phase 1

| # | Item | Settles by |
|---|---|---|
| U1 | cp314 wheels for CTranslate2/faster-whisper install and run on this host | attempting the venv install |
| U2 | Real transcription throughput on this CPU | 5-minute calibration on the extracted 300 s sample |
| U3 | The recording contains intelligible speech in a known language | same calibration run — nobody has listened and no ASR has run |
| U4 | Idle embedding latency | requires the rebuild to finish |
| U5 | SC-007/SC-008 retrieval quality | no corpus exists yet |

U1–U3 all close in the same short calibration, which is the single recommended next action.

## Constitution constraints confirmed for Phase 1

- **§11.4.156** — no CI may be added, including inside `workshop/`. Note: the umbrella's pre-push
  gate E was blind to submodules until fixed on 2026-09-01; it now derives the owned fleet from
  `helix-deps.yaml` and is mutation-proven against two submodules.
- **§11.4.76** requires `vasic-digital/containers` as the sole orchestration layer.
  ~~It is **not** a submodule of this tree. Container work must resolve this before adding a
  bespoke stack.~~ **WITHDRAWN 2026-09-01 — not silently replaced.** *What was believed when this
  line was written (2026-08-31): the tree declared no `vasic-digital/containers` gitlink, so the
  §11.4.76(2) submodule obligation was an unmet prerequisite and any container work was blocked
  behind an operator decision. What is measured now (2026-09-01):
  `git config -f .gitmodules --get-regexp containers` returns
  `submodule.submodules/containers.path submodules/containers` and
  `submodule.submodules/containers.url git@github.com:vasic-digital/containers.git`;
  `submodules/containers` is populated and the gitlink is pinned at
  `4dab992`. `scripts/verify-governance-cascade.sh` classifies **9** declared submodules —
  7 owned (containers among them), 1 governance source, 1 third-party. When it changed: during this
  feature's own Phase 1 work, after this line was written and before this correction. The
  prerequisite is therefore **satisfied, not pending**, and the architecture is settled:
  containerised, consuming `submodules/containers`. A bespoke stack remains forbidden by
  §11.4.76(4) — that half of the original sentence was, and is, correct.*
- **§11.4.161** mandates rootless podman. Host has podman 5.7.1 rootless; docker is absent.
- **§1.1** — every gate needs a paired mutation proof that includes a real end-to-end run.
