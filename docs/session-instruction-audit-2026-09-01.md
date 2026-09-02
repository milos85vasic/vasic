# Session instruction audit — 2026-09-01

**What this is.** Every instruction the operator gave in session
`f190827d-5978-deb6-a880-642959ad497f` (2026-08-26 18:38 CEST → 2026-09-01 20:55 CEST),
re-derived from the transcript and checked against the tree. It answers the operator's
own request:

> *"All prompts we have given tonight MUST BE re-evaluated and checked so we confirm
> that every single one of them was processed and executed completely with no exception
> or being forgotten completely !!!"*

**Source of truth.** The session JSONL, not anyone's recollection and not the
assistant's own claims inside it — those claims are the thing being audited. The
transcript was streamed with `python3`, never read whole. Two record classes carry
operator input and **both** were extracted:

- `type=user` messages with a `role=user` text block — prompts typed at the turn boundary;
- `type=queue-operation` with `operation=enqueue` — prompts typed **mid-turn** while the
  assistant was working. These are delivered to the model as `attachment` records after
  the matching `remove`, so they count. 55 of them exist and a naive user-record scan
  misses every one that was merged into a combined delivery.

Raw counts: **96 prompt events** (55 queued + 41 direct), collapsing to **51 distinct
instructions** after de-duplicating re-issues, direct/queued pairs of the same text, and
the eleven repeats of `fan out subagents`.

**Privacy.** This repository is public. Operator instructions are quoted; **no transcript
content is quoted**, and no person's name appears here. Where an instruction itself would
carry private material it is summarised instead — and so is any instruction that a file
inside a private submodule reproduces verbatim, because quoting it here would republish
that file's text. Every such row says so at the point where it paraphrases, and cites the
private file by path. See `docs/content-boundary.md`.

---

## Method — the gate suite, measured for this audit

Every verdict below that cites a gate cites a run made **for this audit** between
23:00 and 23:20 CEST on 2026-09-01, not a figure copied from `CLAUDE.md`. The gates
carry three verdicts: **0 = clean; 1 = a real finding; 2 = undetermined, and 2 is
never a pass.**

| Gate | Exit | Result as printed |
|---|---|---|
| `scripts/verify-governance-cascade.sh` | **0** | 12 PASS / 0 FAIL / 0 ENV / 8 NOTE |
| `scripts/verify-manifest-pins.sh` | **0** | 12 MATCH / 0 DRIFT / 0 UNDETERMINED of 12 declared deps |
| `scripts/verify-submodule-remote-sync.sh` | **0** | 12 CURRENT / 0 DRIFT / 0 UNDET of 12 owned gitlinks probed, 13 declared |
| `scripts/verify-check-registry.sh` | **0** | PASS — every registered check has a paired proof; **5 registered DEBT rows** printed |
| `scripts/verify-mutation-anchors.sh` | **0** | PASS with NOTE — 3 `prove-*.sh` scripts still lack a `--check-anchors` mode |
| `scripts/verify-remedy-executability.sh` | **0** | PASS with a stated limit (does not execute discovered remedy strings) |
| `scripts/verify-private-object-exposure.sh` | **0** | 0 findings / 0 undetermined |
| `scripts/continuation-check.sh` | **0** | 8 PASS / 0 DRIFT / 0 UNDET / 1 NOTE — CONTINUATION.md in sync |
| `scripts/audit-hardcoded-paths.sh` | **0** | no machine-specific hardcoded paths (9 files allow-listed) |
| `scripts/audit-environment-assumptions.sh` | **0** | no NEW frozen assumptions (526 allow-listed); 1 third-party NOTE |
| **`scripts/verify-content-boundary.sh`** | **1** | **LEAK — 4249 surviving matches (prose 4002, short 190, name 57); 7 distinct personal names by digest** |
| **`scripts/verify-provider-ci.sh`** | **1** | **provider-side CI triggering CONFIRMED on 1 upstream row** |
| `scripts/verify-all-constitution-rules.sh` | *incomplete* | still executing when this document was written; **no split is claimed** |

**Three statements in `CLAUDE.md` are stale and are corrected here by measurement, not
by argument:**

1. *"`audit-environment-assumptions.sh` is currently RED (exit 1) … 7 frozen environment
   assumptions"* — it now exits **0**.
2. *"No ASR engine … `whisper`, `faster_whisper` … are all absent from `python3`'s import
   path"* — true of the **system** interpreter, false of the project. `faster_whisper
   1.2.1` and `ctranslate2 4.8.2` are installed in `workshop/pipeline/venv`, and they
   produced the chapter-1 transcript.
3. *"No generative model … both are embedding models"* — `ollama` now serves
   `qwen2.5:3b-instruct-q4_K_M` (1840 MB) alongside the two embedding models, and the
   live platform answers through it.

**Repository state at audit time.** Umbrella `HEAD = 9dcfc41`, identical on all three
remotes (`origin`, `github`, `upstream` — all three point at
`git@github.com:milos85vasic/vasic.git`). All 13 declared gitlinks equal their remote
tips. Working trees are **not** clean: umbrella carries 2 staged files and 1 untracked
directory; `workshop` carries 32 dirty entries; `submodules/constitution` carries 1.

---

## The table — every instruction, in the operator's own order

Status key: **DONE** · **PARTIAL** · **IN FLIGHT** · **NOT DONE** · **SUPERSEDED** ·
**N/A** (stray input or harness action).

| # | Time (CEST) | Instruction | Status | Evidence | What remains |
|---|---|---|---|---|---|
| 1 | 08-26 18:38 | `/model` | DONE | Harness confirmed the model switch in-session. | — |
| 2 | 08-26 18:38 | `/lumen:reindex` | DONE | `scripts/lumen-index-doctor.sh` → **exit 0**, "index healthy": 3313 files indexed, 71156 chunks, 71156 distinct vectors, 0 NaN/Inf/all-zero/off-norm. | — |
| 3 | 08-26 18:58 | *"Add Lumen to my path! Extend .bashrc properly … Lumen MUST WORK impeccable!"* | DONE (caveat) | `bash -lc 'command -v lumen'` → `<HOME>/…`, rc 0. `~/.bashrc` lines 162–186 carry a managed block with lazy completions and documented tunables. | Doctor warns the backend is currently running `jina-embeddings-code-cpu:latest` while the index itself was created against `ordis/jina-embeddings-v2-base-code` — a live model mismatch that risks a second index. |
| 4 | 08-26 19:18 | *"Let us know all is fixed, polished, properly configured, fully reindexed … Commit and push all work done to all upstreams! Make sure latest changes we did get indexed as well!"* | DONE | `git ls-remote` on `origin`, `github`, `upstream` all return `9dcfc41…` for `refs/heads/main`, equal to local `HEAD`. Per-submodule probe: **13/13 SYNCED** with their remote HEADs. | — |
| 5 | 08-26 19:24 | *"add proper setup steps into already existing script we have in scripts directory … all mandatory extending and polishing"* | DONE | `scripts/setup-agents-wizard.sh` (77,539 B), paired `scripts/test-setup-agents-wizard.sh` (72,561 B), `scripts/rollback-agents-wizard.sh` (8,673 B). | — |
| 6 | 08-26 19:26 | *"CRITICAL: Cover everything with exhaustive tests which will validate and verify all work with machine evidence produced!"* | **PARTIAL** | Real coverage exists: registry PASS over 21 checks; `workshop/platform/gates/` has 5 `prove-*.sh` + 4 `verify-*.sh`; `workshop/platform/qa/challenges/` has 5 scripts with recorded evidence under `qa/evidence/`; `workshop/platform/frontend/e2e/` has 7 specs. | `verify-check-registry.sh` prints **5 registered DEBT rows** on every run. `specs/001-…/tasks.md` has **0 of 120** checkboxes ticked. The newest surface (knowledge areas, quizzes) has no tests because it has no implementation — see #45/#49. |
| 7 | 08-26 19:28 | *"run the setup agent(s) script and guide us interactively … Extend and polish all existing docs … user guide(s), manuals, FAQs, graphs, diagrams and schemes!"* | DONE | `docs/setup-agents-wizard/` holds 18 documents incl. `README.md` (62,833 B), `MANUAL.md` (69,932 B), `FAQ.md` (39,733 B), `ARCHITECTURE.md` (42,386 B, **6 mermaid diagrams**), `ACTION-REQUIRED.md`. | — |
| 8 | 08-26 19:29 | *"everything is fully committed and pushed to all upstreams — main repo and all submodules fully recursively and Codegraph, Lumen and all indexable extensions fully up to date and in sync"* | **PARTIAL** | Push half proven (row 4). Index half: Lumen doctor exit 0. | **Not clean.** `git status --porcelain`: umbrella 4 entries (2 staged + `specs/002-…/` untracked), `workshop` **32 dirty**, `submodules/constitution` 1 dirty. Lumen reports **66 queued placeholders** not yet embedded. |
| 9 | 08-26 19:29 →<br>09-01 17:36 | *"fan out subagents"* (×11 across the session) | DONE | Concurrent agent work is visible in the tree by mtime clustering (specs/002 authored 22:44–22:57, research docs 23:00–23:04, knowledge model 22:45, frontend rebuild 23:01). | — |
| 10 | 08-26 19:29 / 20:40 / 08-31 10:12 | `/using-superpowers`, `/systematic-debugging`, `/subagent-driven-development` | DONE | Skills invoked; `.superpowers/sdd/progress.md` is live and carries the protocol name. | See #48 — the *implementation* half of the superpowers directive is only partly honoured. |
| 11 | 08-26 20:15 | *"use any existing CLI agents configurations and extend them properly without breaking … safety mechanism with proper backup … proper uninstall / rollback mechanism … maximal flexibility, safety and be maximally risk free!"* | DONE | `scripts/rollback-agents-wizard.sh` exists and is registered. Timestamped backups are real on disk (9 × `~/.local/bin/lumen.bak.<UTC>`). Documented in `docs/setup-agents-wizard/ARCHITECTURE.md` and `OPERATIONAL-SCRIPTS.md`. | — |
| 12 | 08-26 20:32 | *"fully and properly incorporate constitution Submodule … all of our major files — AGENTS.md, CLAUDE.md, QWEN.md, and others do inherit it … applied / inherited by all Submodules … fetch and pull the latest version … and all of its dependency Submodules fully recursively"* | DONE | `verify-governance-cascade.sh` **exit 0**, 12 PASS / 0 FAIL. `submodules/constitution` = `f5876a3b700e…`, **identical to `git ls-remote … HEAD`**. 7 nested gitlinks present under it. `verify-manifest-pins.sh` 12/12 MATCH. | — |
| 13 | 08-26 20:33 | *"All Submodule we have MUST BE fully recursively indexed and covered with all indexing extensions / services: codegraph, lumen and all others"* | **PARTIAL** | Lumen index healthy, 3313 files / 71156 chunks; coverage reasoning recorded in `docs/constitution-adoption/INDEX-COVERAGE.md`. | 66 files remain **queued placeholders**. No per-submodule completeness proof exists for either indexer; codegraph coverage is not measured by any gate in this tree. |
| 14 | 08-26 20:34 (×5, through 08-27 00:07) | *"Continue endless fully autonomous working loop … 3 - 4 subagents … rock solid physical evidence … no bluff of any kind!"* | DONE | Loop ran across six calendar days; eight feature commits on `main` since `708c8b1`. | — |
| 15 | 08-26 20:42 | *"all extensions … updated to the latest versions (automatically) … Turn off any analytics or telemetry data gathering if possible"* | **PARTIAL** | Telemetry: `~/.bashrc` exports `DO_NOT_TRACK=1` and `CODEGRAPH_TELEMETRY=0` — **done**. | "Latest versions" is **unverified**: `~/.codegraph/versions/` contains only `v1.5.0` and nothing in this tree checks it against an upstream release. No automatic update mechanism exists. |
| 16 | 08-26 21:08–21:09 | three short strings typed into the queue | **N/A** | Not instructions — stray input (a word, a number, an arithmetic fragment); each was enqueued and removed without a task. | Recorded so the count is honest, not silently dropped. |
| 17 | 08-26 21:15 | *"Fix everything now!"* | SUPERSEDED | Restated with a scope on 09-01 15:08 as *"Fix everything workable - any discovered issues we have found!"* — see #40. | — |
| 18 | 08-27 07:44 | *"All commands executed, make them part of bash scripts for future situations like these! Re-run indexing now! … Commit and push all work!"* | DONE | The ad-hoc commands became `scripts/lumen-reindex.sh`, `scripts/lumen-index-doctor.sh`, `scripts/ollama-tune.sh`, `scripts/ollama-vulkan-remediation.sh` — all executable and registered in `scripts/check-registry.tsv`. | — |
| 19 | 08-27 15:07 | *"Have we finished everything and have we executed the bash script for installation and configuration of all extensions we need? If no, complete it all and run the script. Keep us interactively in the loop"* | **PARTIAL** | Script and its 72 KB test harness exist and were exercised. | `docs/setup-agents-wizard/ACTION-REQUIRED.md` (15,710 B) still lists steps only the operator can perform. The honest answer to the question asked is "no, not everything" — see the *forgotten* section. |
| 20 | 08-27 15:19–15:20 | `/plugin marketplace add ashlrai/ashlr-plugin`, then `/plugin install ashlr@ashlr-marketplace`, then `/reload-plugins` and `/ashlr:ashlr-status` | DONE | `ashlr-marketplace/ashlr` present in the plugin cache across every CLI profile; ashlr `PreToolUse` hooks fire in the current session. | — |
| 21 | 08-27 15:20 | *"Make sure all these commands somehow interactively are the part of install bash script we are building! User MUST BE aware what it has to do!"* | DONE | `scripts/setup-agents-wizard.sh` mentions ashlr 27 times and prints the exact commands at lines 1134–1136 and 1608–1614, including `/ashlr:ashlr-genome-init`. | — |
| 22 | 08-27 15:21 / 15:35 | `/ashlr:ashlr-genome-init` | DONE | `.ashlrcode/genome/` with `manifest.json`, `knowledge/`, `strategies/`, `milestones/`, `evolution/`, and a live `proposals.jsonl` (last write 23:08 today). | — |
| 23 | 08-27 16:03 | *"We noticed mentioning of macOS host we have (hardcoded) paths. No path can be hardcoded! This all MUST BE properly fixed!"* | DONE | `scripts/audit-hardcoded-paths.sh` → **exit 0**, "no machine-specific hardcoded paths (9 file(s) explicitly allowed)". The 9 allowances are named third-party test fixtures under `submodules/containers`. | — |
| 24 | 08-27 17:17 | *"Do it all now! Make sure all is clean, bash setup script executed, all extensions properly configured and installed!"* | **PARTIAL** | Wizard runs; extensions installed (rows 20–22). | `ACTION-REQUIRED.md` remains non-empty; "all is clean" is false today (row 8). |
| 25 | 08-27 18:00 | Resolve the two waiting items the assistant had raised (a tool with no public installer; a dead symlink step in CI) — *"Tackle it all … Do interactive questions with options for us to handle these!"* | DONE | The tool was made **opt-in only** at `scripts/setup-agents-wizard.sh:1139` behind a `WOZCODE_INSTALL_CMD` hook, and the decision is locked by assertions A52/A53 in `scripts/test-setup-agents-wizard.sh:179–182`. | — |
| 26 | 08-27 18:04 | *"Go through all operator blocked items, all blockers and any show stoppers … create interactive questions for us with options … so we can answer, make decisions and unblock everything!"* | **PARTIAL** | `docs/setup-agents-wizard/ACTION-REQUIRED.md` is the register this produced. | The register is still open. Three blockers named during the session are **not** resolved: the ollama parallelism setting (row 30), the provider-side Pages/Actions setting (row 30), and the two post-incident actions in `docs/content-boundary-incident-2026-09-01.md` (a server-side GC request, and notifying the affected third party) which that document itself marks *"not done"*. |
| 27 | 08-31 10:10–17:52 | `/rate-limit-options` ×4 | **N/A** | Harness commands. | — |
| 28 | 08-31 19:01 | *"Your claude.ai usage limit has reset. Continue the task…"* | **N/A** | System-generated continuation prompt, not operator-authored. Listed so the transcript reconciles. | — |
| 29 | 08-31 19:04 / 20:07 | `/speckit-superspec-execute` | **NOT DONE** | `specs/001-workshop-curriculum-platform/tasks.md`: 120 `T###` identifiers, **0 of 120** checkboxes ticked. `.superpowers/sdd/progress.md` "Completed tasks" reads *"(none)"*. No superspec execution state exists anywhere in the tree. | The platform **was** built — but outside the tracked execute phase, so the plan and the artefact have never been reconciled. Either run the phase against the built system, or mark the tasks against what exists. |
| 30 | 08-31 19:11 | Re: an unset ollama parallelism variable, a root-owned config needing a password, and the file-vs-provider CI boundary — *"Make sure all this is fully dynamic and adaptable based on the environment!"* | **PARTIAL** | Adaptability half **done**: `scripts/audit-environment-assumptions.sh` exit 0; `docs/environment-adaptability/AUDIT.md`; `scripts/ollama-tune.sh` (75,836 B). | Underlying settings **still unset/unfixed**: `systemctl show ollama -p Environment` returns `Environment=` (empty) — the parallelism variable was never set. `verify-provider-ci.sh` → **exit 1**, "provider-side triggering CONFIRMED on 1 upstream row". Both are operator-only actions in a root shell / a provider UI. |
| 31 | 08-31 19:13 / 20:21 | `/speckit-constitution` | DONE | Commit `597bc8c` — *"feat: fill constitution template with concrete project values"*. | — |
| 32 | 08-31 19:59, re-issued 09-01 04:41 and 08:05 | **The large SpecKit brief** — chapter-1 transcription; an ai_interviewing-style curriculum; container + bash scripts; semantic/contextual search over everything; cross-reference linking; DeepWiki-class codebase understanding with Lumen; UI/UX search components with fast auto-completion; full indexing of code, graphs, diagrams, text, audio and video; ask-the-AI answers; LLM-provider bridging using the two organisations' own technology; deep research; docs, guides, manuals, FAQs, trainings, quickstarts; test coverage with machine evidence and no bluff; constitution respected with no violations; regular commit+push so `git status` is clean everywhere; and drive **all** SpecKit phases specify → clarify → plan → tasks → analyze → superspec-execute → review, validating on a LIVE container. | **PARTIAL** | Broken out below — 19 sub-items, individually evidenced. | See 32a–32s. |
| 32a | — | Full chapter-1 transcription as a markdown document | DONE | `workshop/curriculum/chapter-01/transcript.md`, 960 lines / 108,639 B, with a provenance table: faster-whisper 1.2.1 (ctranslate2 4.8.2), `large-v3-turbo` int8 CPU, 1055 segments, 15,610 words, 6928.713 s audio, audio SHA-256 recorded. Machine artefacts: `transcript.segments.json` (15,840 lines), `transcript.words.json`, `pipeline/transcripts/full_ch01.faster-whisper.json` (1.66 MB) + `.runlog`. | — |
| 32b | — | A curriculum organised the way the ai_interviewing module is | **PARTIAL** | `workshop/curriculum/chapter-01/` holds transcript, `exercise-01.md`, `exercise-01.sections.json`, and `curriculum/passages.jsonl`. | The comparison the instruction names does not hold: `ai_interviewing/docs/interview-preparation/areas/` has **110** area documents; `workshop/docs/training/areas/` has **5**, and those 5 document the *platform*, not the workshop's subject matter. |
| 32c | — | Runnable through containers, with all mandatory bash scripts | DONE | `podman ps`: `workshop-curriculum_platform_1`, **Up ~1 h (healthy)**, cgroup `libpod-…`, server reports `"pid": 1`. `workshop/platform/compose.yml` (10,099 B, services `platform` + `workshop-index`). Scripts: `setup.sh` (`--check-only`/`--start`/`--json`/`--prove-failure`), `start.sh`, `stop.sh`, `status.sh`, `restart.sh`, `build.sh`, `verify.sh`, `self-test.sh`, `ingest.sh`. | — |
| 32d | — | Browse and watch chapters | DONE | `GET /api/chapters` → 200 (4040 B); `GET /api/chapters/01/recording/probe` → 200 with a container/codec derivation that works without a media tool. | — |
| 32e | — | A prompt that extends the curriculum with each new chapter | DONE | `workshop/docs/prompts/add-a-chapter.md`, 23,414 B. | — |
| 32f | — | Semantic / contextual search covering all areas by meaning | **PARTIAL** | `GET /api/search?q=…` → 200 in 293 ms, 20 results, `legs: {lexical: ok, semantic: ok, lumen: skipped}`. | The **lumen leg reports `skipped`** on the live service — see 32i. |
| 32g | — | Cross-reference linking, point to point | DONE | `GET /api/passages/{pid}/crossrefs` → 200, scored `derived` relations with depth and preview; `legs: {index: ok, registry: ok}`. | — |
| 32h | — | Every covered area documented with curriculum materials, as ai_interviewing does | **NOT DONE** | Only a taxonomy exists (see #45), and it is uncommitted. | Per-area material documents do not exist. |
| 32i | — | Codebases understood, Lumen semantics integrated, better than a public wiki-over-code service | **NOT DONE** *(as integrated)* | The service's own search response says `"lumen": "skipped"`. `corpus.indexed_kinds` does include `code`, so a code leg exists — but not the Lumen one the instruction names. | Wire and prove the Lumen leg, or state plainly that the code leg is not Lumen. |
| 32j | — | UI/UX search components with blazing-fast auto-completion | **PARTIAL** | `GET /api/suggest?q=age` → 200 (3304 B) with typed suggestions carrying `{chapter_slug, pid, t_start_s}` targets. | Covers only `transcript_segment`, `doc_section`, `code`, `diagram`. See #49 — the instruction that superseded this one is not met. |
| 32k | — | All codebase, graphs, schemes, diagrams, text, audio and video indexed by content and semantics | **PARTIAL** | `corpus.indexed_kinds = [transcript_segment, doc_section, code, diagram]`; index generation 16, 1101 pids, root hash recorded. | The service states its own limit: `media_reached_via: "transcripts and captions only"`. Audio and video are **not** indexed as media. |
| 32l | — | Ask the AI questions and get answers | DONE (async) | `POST /api/ask` → 200 with `job_id`, `poll`, `stream`, and a `provider` object carrying `locality: local` and `locality_verified: true`, naming `qwen2.5:3b-instruct-q4_K_M` as the model behind `name: ollama`. | "Instant" it is not — the service's own measured median is **31.4 s**. |
| 32m | — | Bridge to LLM providers using the two organisations' technology | DONE | Four public gitlinks now carry it: `submodules/LLMProvider`, `submodules/RAG`, `submodules/passage`, `submodules/verdict`; server flags `-answer-provider ollama -answer-model …`. | — |
| 32n | — | Deep research, comprehensive documentation, guides, manuals, FAQs, trainings, quickstarts | DONE | `workshop/docs/`: `README.md`, `user-guide.md` (23,129 B), `manual.md` (28,009 B), `faq.md` (23,307 B), `quickstart.md` (19,830 B), `limits.md` (74,453 B), `training/` (overview + 5 areas), `research/` (2 files, 151 KB, written 23:00–23:04 tonight). | — |
| 32o | — | Test coverage asserting machine evidence, no false or faulty results, no bluff | **PARTIAL** | Same evidence as #6. | Same gaps as #6. |
| 32p | — | Constitution fully respected, no violations | **NOT MET** | `verify-content-boundary.sh` → **exit 1**: LEAK, 4249 surviving matches (prose 4002, short 190, name 57), 7 distinct personal names identified by digest. Largest public contributors by match count: `scripts/lib/anchor.py` (632), `specs/001-…/contracts/http-api.md` (295), `specs/001-…/contracts/pipeline-cli.md` (205), `specs/001-…/research/transcription.md` (145). | Triage all 4249 — many are plausibly shared technical prose rather than disclosure, but **a red gate is not a pass**, and 57 name-class matches across 7 distinct people must be resolved individually. The full-corpus sweep `verify-all-constitution-rules.sh` had not finished when this was written, so its split is **unknown**, not green. |
| 32q | — | Regular commit and push so `git status` returns clean for every repository | **NOT MET** | `workshop`: **32 dirty entries**. Umbrella: 2 staged + 1 untracked directory. `submodules/constitution`: 1 dirty. | Commit or discard; all thirteen gitlinks are otherwise already at their remote tips. |
| 32r | — | Drive every SpecKit phase in order, ending with superspec-execute then review | **PARTIAL** | 001 reached **analyze**: `specs/001-…/analysis.md` (15,555 B) exists alongside spec/plan/research/data-model/contracts/quickstart/tasks/checklists. | **`superspec-execute` and `review` never ran** for 001 (row 29). 002 stops at `tasks.md` — it has no `analysis.md`. |
| 32s | — | Validate on a LIVE running container: all content, features, use cases, edge cases, scenarios, combinations | **PARTIAL** | The container is live and reachable; `workshop/platform/qa/evidence/` holds recorded challenge output; 7 Playwright specs exist under `frontend/e2e/`. | No completed full-suite verdict was observable at audit time, and the live container predates tonight's rebuilt web bundle (container up ~1 h; `platform/web/*` rewritten at 23:01), so what is running is **not** what was last built. |
| 33 | 09-01 08:33 | *"ask us all operator blocked questions to make decisions, then solve all this and do it all"* — quoting back that analyze/superspec-execute/review were not done, nothing implemented, and the work was blocked on a missing ASR engine and a missing generative model | **PARTIAL** | **Both named blockers are now gone**: `faster_whisper 1.2.1` + `ctranslate2 4.8.2` in `workshop/pipeline/venv`, and `qwen2.5:3b-instruct-q4_K_M` in ollama. `analyze` ran (`analysis.md`). The platform was implemented and is live. | `superspec-execute` and `review` still have not run (row 29 / 32r). |
| 34 | 09-01 08:38 | *"CRITICAL: All components and services MUST BE fully decoupled and reusable"* | DONE | Four new standalone gitlinks extracted this session: `submodules/LLMProvider`, `submodules/RAG`, `submodules/verdict`, `submodules/passage` — each its own repository with its own tag history. | — |
| 35 | 09-01 08:41 | *"Follow how all HelixDevelopment and vasic-digital decoupled Submodules are made for full reusability with its own proper repos!"* | DONE | All four new repos live under `vasic-digital/`, are declared in `.gitmodules`, recorded in `helix-deps.yaml`, and pass cascade check C6 (manifest ↔ `.gitmodules` agreement, both directions) and C9 (`ref` == gitlink). | — |
| 36 | 09-01 08:42 | *"This all shall be already explained in constitution!"* | DONE | Constitution consulted at `f5876a3`; C8 finds all owned submodules internally in four-carrier lockstep. | — |
| 37 | 09-01 09:07 | *"All such reusable new repos (Submodules) MUST BE PUBLIC."* | DONE | `gh api repos/<r> --jq .visibility`: `vasic-digital/LLMProvider`, `/RAG`, `/verdict`, `/passage`, `/containers` → **public** (5/5). | `milos85vasic/workshop_curriculum` is **private** — correct and intended: it holds the private recording and transcript, and is not a reusable component repo. |
| 38 | 09-01 09:08 | *"Do not [make the] same reusables twice if we do have them already under our organization repos! Extend them freely for new features!"* | DONE | No duplicate-purpose repository was created; the four new ones are functionally distinct (provider abstraction, retrieval, passage identity, verdict). | — |
| 39 | 09-01 12:39 | *"Any discovered issues MUST BE systematically debugged, investigated, properly fixed and properly validated and verified!"* | **PARTIAL** | Genuine fixes shipped: `4ee9e8d` (runner distinguishes "could not run" from "failed"), `b0ab4b4` (live specs moved to the config that claims them), `562ecf9` (82-finding triage), `203061d` (incident record + 17 stale citations repointed), `9dcfc41` (manifest pins repointed). | Two gates are **red right now** (content-boundary rc 1, provider-ci rc 1) and 5 registry DEBT rows stand. Discovered ≠ fixed. |
| 40 | 09-01 15:08 | *"Fix everything workable - any discovered issues we have found!"* | **PARTIAL** | Same evidence as #39. | Same. |
| 41 | 09-01 15:08 | A demand for bash scripts able to install and launch the entire solution on an arbitrary host machine — **paraphrased, not quoted**, because `workshop/scripts/setup.sh` opens by reproducing the sentence verbatim and that file lives in a PRIVATE submodule, so it is cited by path only (`docs/content-boundary.md`) | DONE | `workshop/scripts/setup.sh` opens by restating that requirement, and implements detect → do-what-is-permitted → refuse-clearly-by-name, with `--check-only`, `--start`, `--json`, and a `--prove-failure` paired-mutation proof. | — |
| 42 | 09-01 16:07 | *"Investigate exhaustive mechanisms to achieve everything without exceptions!"* | DONE | Delivered as research + adaptability instruments: `docs/environment-adaptability/AUDIT.md`, `workshop/scripts/_capabilities.sh` (43,232 B), `workshop/scripts/_portable.sh` (24,302 B). | — |
| 43 | 09-01 19:50 | *"after all is done, fully committed and pushed … install and start the workshop solution so we can try it out … let us know ports … it must be accessible within the whole network!"* | DONE (precondition unmet) | `workshop-curriculum_platform_1` healthy; `ss` shows `workshop-server` bound `*:8087`; `curl http://192.168.1.44:8087/` → **HTTP 200** in 0.5 ms and `/api/health` reports `"http": "http://192.168.1.44:8087"`. A second instance answers on `127.0.0.1:8099`. Ports were reported to the operator in-session. | The stated precondition — *"after all is done, fully committed and pushed"* — was **not** satisfied when it was started, and still is not (row 32q). |
| 44 | 09-01 19:54 | *"Workshop MUST BE heavily tested, validated and verified like we did with ai_interviewing !!!"* | **PARTIAL** | Workshop has 5 `prove-*.sh` + 4 `verify-*.sh` platform gates, 5 QA challenge scripts with recorded evidence, a `helixqa/run-suite.sh`, and 7 Playwright e2e specs. | The named benchmark is not met. `ai_interviewing` carries a full `platform/qa` tree and 110 area documents; the workshop's newest surface has **no tests at all** because it has no implementation (rows 45, 49). |
| 45 | 09-01 20:26 | *"We see gaps! No knowledge covered - areas - like we have in AI Curriculum!"* — extract all terms and areas; build the same kinds of materials; link every area and term from transcript and video to areas, chapters and quizzes; reuse the ai_interviewing UI/UX technology; a unique look via OpenDesign and all available Skills; search across **all** content; video links to exact times; use every SpecKit step; cover everything with tests against machine evidence; do it with sub-agent workflows | **PARTIAL — mostly NOT DONE** | **Landed (all uncommitted):** `workshop/curriculum/chapter-01/knowledge/` — `areas.json` (**7 tracks, 37 modules**), `terms.json`, `coverage.json`, `artifacts.json`, `linkage.jsonl`, `reverse-index.json`, `lexicon.json`, `platform-mapping.json`, `TAXONOMY.md`, `build.py`, `verify.py`; `workshop/docs/knowledge-model-contract.md` (77,518 B); the whole `specs/002-knowledge-areas-deep-linking/` planning set. **OpenDesign is real in the shipped UI** — the live `index.html` carries the full `--od-*` token palette and self-hosted brand faces. Timecode deep links work: every suggestion and crossref carries `t_start_s`. | **The feature does not exist in the running system.** `GET /api/areas`, `/api/knowledge/areas`, `/api/quizzes` all return **404**, and the Go backend registers **no** area, knowledge, quiz or practice route — its 30 registered routes are transcript/search/ask/passage/progress only. Quiz content is two files literally named `question-bank-example.*.json`. SpecKit for 002 stops at `tasks.md` (**0 of 122** done); no `analysis.md`. |
| 46 | 09-01 20:30 | *"Use ai_interviewing as reference and base … Do not clone or copy it but use as the reference / port it properly … Current workshop is extremely poorly made!"* | **IN FLIGHT** | Uncommitted frontend rework in `workshop/platform/frontend/src/app/`: new `features/areas/`, `features/practice/`, `features/curriculum/`, `features/ask/`, `features/progress/`, plus `core/knowledge.ts`, `core/cite.component.ts`, `core/rail.component.ts`, `core/timecode.ts`, `styles/brand/`, `scripts/sync-brand-tokens.sh`, `scripts/sync-fonts.sh`. | Lands when `specs/002` is implemented and the container is rebuilt from the new bundle. Nothing is committed. |
| 47 | 09-01 20:40 | *"Do not just pickup materials from ai_interviewing but create the materials which are following our chapters … extract all areas and themes … with exhaustive long and short tests / quizzes! Everything MUST BE cross-referenced, searchable by meaning and context and fully connected! … new widgets and stunning new designed elements … more powerful effects, transitions, better UX! Do deep web research rounds…"* | **PARTIAL** | Deep research **delivered**: `workshop/docs/research/ux-research-2026-09-01.md` (79,459 B) and `skills-and-plugins-2026-09-01.md` (72,314 B), both written 23:00–23:04 tonight. Taxonomy is chapter-derived, not lifted (`areas.json` records `source_of_truth: curriculum/passages.jsonl`). | Long/short quizzes exist only as two **example** files. No widget, effect or transition work is committed. |
| 48 | 09-01 20:43 | *"All implementation work MUST BE done using superpowers !!! Use all additional / available Skills and Plugins we have and add more newly discovered from deep web research missions we MUST perform!"* | **PARTIAL** | The research mission ran — `skills-and-plugins-2026-09-01.md`, 72 KB. `.superpowers/sdd/progress.md` is live and names the protocol. | Its completed-task ledger reads *"(none — awaiting tasks.md from the SpecKit phase)"*. **No newly discovered skill or plugin was installed** as a result of the research. |
| 49 | 09-01 20:53 | *"Make sure that auto-complete feature is fully connected with EVERYTHING … chapters content / transcriptions, codebases, areas / chapters / paragraphs / sections, quizzes / tests and everything else"* | **NOT DONE** | `/api/suggest` covers exactly `transcript_segment`, `doc_section`, `code`, `diagram` — confirmed by the service's own `corpus.indexed_kinds`. | Areas and quizzes have no server-side representation to complete against, so this cannot be satisfied until #45 ships. Nothing was committed against it. |
| 50 | 09-01 20:54 | *"Every part of the system MUST BE covered with exhaustive tests … and fully respect all rules and mandatory constraints from the constitution Submodule! Make sure we have the latest version of constitution codebase and all its dependency submodules (fully recursively) !!!"* | **PARTIAL** | Constitution half **DONE**: pin `f5876a3` == remote HEAD, 7 nested gitlinks present, C9 12/12 MATCH, cascade 12 PASS / 0 FAIL. | Tests half **not met** (rows 6, 44, 49). Compliance half **not met**: `verify-content-boundary.sh` exit 1, and the full sweep had not finished. |
| 51 | 09-01 20:55 | *"All prompts we have given tonight MUST BE re-evaluated and checked so we confirm that every single one of them was processed and executed completely with no exception or being forgotten completely !!!"* | DONE | This document. | — |

**Breakdown of the 51 distinct instructions:** **27 DONE · 17 PARTIAL · 2 NOT DONE ·
1 IN FLIGHT · 1 SUPERSEDED · 3 N/A.**

Counting the large brief's 19 sub-items individually instead of as the single PARTIAL
row 32 — **69 evaluated items: 35 DONE · 23 PARTIAL · 6 NOT DONE · 1 IN FLIGHT ·
1 SUPERSEDED · 3 N/A.** The six NOT DONE are rows 29, 49, 32h, 32i, 32p and 32q.

---

## What was forgotten

This is the section the audit exists for. Each item was asked for, and each is provably
absent — not "in progress with a plan", absent.

**1. `speckit-superspec-execute` and `speckit-superspec-review` never ran.**
Asked twice as an explicit slash command (08-31 19:04 and 20:07) and named as the final
two phases of the large brief. `specs/001-workshop-curriculum-platform/tasks.md` carries
120 `T###` identifiers and **0 ticked checkboxes**; `.superpowers/sdd/progress.md` lists
zero completed tasks; no superspec state artefact exists in the tree. The platform got
built anyway, by hand, which is *why* this went unnoticed — the artefact exists so the
missing phase looks harmless. It is not: nothing has ever reconciled the 120 planned
tasks against what was actually built, and `review` — the step whose whole job is to
find what needs fixing — has never executed.

**2. The knowledge-area feature has no implementation — only a plan and a data file.**
The 20:26 instruction is the sharpest one of the night, and its core is unbuilt.
`GET /api/areas` → **404**. `GET /api/knowledge/areas` → **404**. `GET /api/quizzes` →
**404**. The Go backend's 30 registered routes contain **no** area, knowledge, quiz or
practice handler. What exists is a taxonomy JSON set (7 tracks, 37 modules) and a
122-task plan, both **uncommitted**. Two files named `question-bank-example.mcq.json` and
`question-bank-example.short.json` are the entirety of the "exhaustive long and short
tests / quizzes".

**3. Auto-complete is not connected to everything, as instructed at 20:53.**
`/api/suggest` reports its own corpus: `transcript_segment`, `doc_section`, `code`,
`diagram`. Areas, chapters-as-knowledge-units, paragraphs/sections-as-areas, quizzes and
tests are all absent, because item 2 is absent. Nothing was committed against this
instruction at all.

**4. `verify-content-boundary.sh` is RED and no one has said so tonight.**
Exit **1**: 4249 surviving matches, of which **57 are personal-name class across 7
distinct people**. This directly contradicts *"Constitution MUST BE fully taken into the
account, followed and respected with no violations"* (32p) and *"fully respect all rules
and mandatory constraints from the constitution Submodule"* (row 50). It is entirely
possible most of the 4002 prose matches are shared technical vocabulary rather than
disclosure — but that is a triage nobody has done, and **a red gate is never a pass.**

**5. The two post-incident actions in the content-boundary incident record are still
not done.** The 08-27 18:04 instruction asked for *every* blocker to be surfaced as a
decision. `docs/content-boundary-incident-2026-09-01.md` states in its own header that
the orphaned blobs remain fetchable by SHA until a server-side garbage collection that
**only GitHub Support can perform**, and that requesting it — and informing the affected
third party — are the operator's actions and are *"not done"*. The document is explicit
that nothing in it may be read as closure. Neither action has been taken.

**6. The ollama parallelism setting was never applied.**
Raised on 08-31 19:11 and answered with adaptability tooling. `systemctl show ollama -p
Environment` returns `Environment=` — empty. The variable is still unset. It needs a root
shell; that is an operator action, and it should be on the operator's list rather than
buried.

**7. "Latest versions" of the extensions was never verified.**
The 08-26 20:42 instruction had two halves. The telemetry half is done
(`DO_NOT_TRACK=1`, `CODEGRAPH_TELEMETRY=0`). The auto-update half has no mechanism and no
check: `~/.codegraph/versions/` contains only `v1.5.0`, and nothing in this tree compares
it to an upstream release. Absence of a check is not a pass.

**8. `git status` is not clean, which every "commit and push everything" instruction
demanded.** `workshop` has **32 dirty entries** — including the entire knowledge model
and the entire frontend rework. The umbrella has 2 staged files and one untracked
directory (`specs/002-…`). `submodules/constitution` has 1. All thirteen *gitlinks* match
their remotes, so this looks synced from the outside; the work sitting in the working
tree is what a fresh clone would not get.

**9. Deep research produced findings but no adoption.**
The 20:43 instruction says to *add* newly discovered skills and plugins. 72 KB of
research was produced. No new skill or plugin was installed.

**One near-miss worth recording as a correction, not a finding:** three "known blockers"
that shaped decisions earlier in the session are no longer true, and `CLAUDE.md` still
asserts them — no ASR engine (there is one, in `workshop/pipeline/venv`), no generative
model (there is one, in ollama), and `audit-environment-assumptions.sh` being red (it
exits 0). Any future planning that reads those lines will plan around constraints that
have already been removed.

---

## What is in flight, and when it lands

Roughly ten agents were working concurrently while this audit ran. Their output is in the
working tree, not in a commit. By file mtime:

| Work | Where | Last written | Lands when |
|---|---|---|---|
| `specs/002-knowledge-areas-deep-linking/` — spec (79,876 B), plan, research, data-model, 2 contracts, quickstart, tasks (**122 `T###`, 0 done**), checklist | `specs/002-…/` (untracked) | 22:44 – 22:57 | The plan is complete through **tasks**; it has no `analysis.md`. Nothing lands until implementation starts. |
| Knowledge model — `areas.json` (7 tracks / 37 modules), `terms.json`, `coverage.json`, `artifacts.json`, `linkage.jsonl`, `reverse-index.json`, `lexicon.json`, `platform-mapping.json`, `TAXONOMY.md`, `build.py`, `verify.py` | `workshop/curriculum/chapter-01/knowledge/` (untracked) | 22:45 | Data is ready now; it is inert until a server route reads it (item 2 above). |
| `workshop/docs/knowledge-model-contract.md` (77,518 B) | workshop (untracked) | 22:46 | Ready. |
| Angular rework — `features/areas`, `features/practice`, `features/curriculum`, `features/ask`, `features/progress`, `core/knowledge.ts`, `core/cite.component.ts`, `core/rail.component.ts`, `core/timecode.ts`, brand tokens, font sync scripts, `e2e/live-content.spec.ts` | `workshop/platform/frontend/` (7 modified, ~18 untracked) | 22:53 – 23:01 | Needs `ng build` **and a container rebuild** — the running container started ~22:00 and is serving the *previous* bundle. |
| Deep-research reports — UX (79,459 B) and skills/plugins (72,314 B) | `workshop/docs/research/` (untracked) | 23:00 – 23:04 | Delivered; adoption not started (item 9). |
| Rebuilt web bundle | `workshop/platform/web/` | 23:01 | Built, **not served**. |
| Full constitution sweep `verify-all-constitution-rules.sh` | — | running | Was still executing when this document was written. **No split is claimed for it here.** Re-run it and read its own verdict; do not quote a number from `CLAUDE.md`. |

**The single most important in-flight fact:** the live system at
`http://192.168.1.44:8087` is **older than tonight's work**. Container up ~1 h; web bundle
rewritten at 23:01; backend binary `workshop-server` dated 20:58. Anything demonstrated
against the live URL right now demonstrates the 20:58 build, not the 23:01 one.

---

## What was superseded, and by what

**Row 17 → row 40.** *"Fix everything now!"* (08-26 21:15, enqueued and removed without
a scoped task) was restated with a scope on 09-01 15:08 as *"Fix everything workable -
any discovered issues we have found!"* The later wording is the operative one; both are
tracked as PARTIAL under row 40.

**Row 32j → row 49.** The large brief asked for *"blazing fast auto-completion"* and got
`/api/suggest` — 200, typed, timecode-bearing, delivered. At 20:53 the operator narrowed
and hardened it: *"Make sure that auto-complete feature is fully connected with
EVERYTHING … chapters content / transcriptions, codebases, areas / chapters / paragraphs
/ sections, quizzes / tests and everything else."* The later instruction is the standard
that applies, and by that standard the feature is **NOT DONE** — the earlier PARTIAL must
not be read as satisfying it.

**Rows 32b / 32h → rows 45, 46 and 47, in three tightening steps.** The brief said build
a curriculum *"same thing we did for ai interviewing module"*. At 20:26 the operator
rejected what existed: *"We see gaps! No knowledge covered - areas - like we have in AI
Curriculum."* At 20:30 he set the method: *"Use ai_interviewing as reference and base …
Do not clone or copy it but use as the reference / port it properly (parts we may need)!
Current workshop is extremely poorly made!"* At 20:40 he closed the obvious shortcut:
*"Do not just pickup materials from ai_interviewing but create the materials which are
following our chapters (chapter 01 we have currently)."* The taxonomy that was produced
does obey the final form — `areas.json` records `source_of_truth:
curriculum/passages.jsonl`, so it is derived from this workshop's own content and not
lifted. The **materials** the three instructions all demand still do not exist.

**No instruction was superseded into non-existence.** Nothing on this list was cancelled
by a later prompt; the later prompts only raised the bar.

---

## Honest boundary

- Every gate result above is a **dated observation** made 2026-09-01 between 23:00 and
  23:20 CEST. Remotes move, provider settings change outside this tree, and background
  agents were writing to the working tree throughout. Re-measure before acting.
- `verify-all-constitution-rules.sh` **did not finish** inside the audit window. Its
  result is UNKNOWN here. Unknown is not a pass.
- Rows 9, 10, 14, 27, 28 and 42 concern process rather than artefacts. Their evidence is
  the transcript plus whatever shape the tree has, which is weaker than a file or an exit
  code.
  They are marked DONE on that weaker basis, and the distinction is stated rather than
  hidden.
- This audit changed nothing. It wrote exactly one file — this one. It committed nothing,
  pushed nothing, restarted nothing, and fixed nothing it found.
