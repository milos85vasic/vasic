# 03 — Carrier snippets (PROPOSED)

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-14 |
| Status | proposal — paste targets named; nothing pasted |

Replace `ANCHOR-A..E` by the final numbers if they change (see `01_rule_texts.md`).

## 1. Constitution-side carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`)

The constitution's own carriers hold one compact-summary paragraph per anchor
(the existing pattern is `**§11.4.N — Title (provenance).** Compact summary: …`).
The same five paragraphs go into all four files, byte-identical (§11.4.157,
§11.4.227(B)), immediately after the §11.4.276 paragraph.

```markdown
**§11.4.277 — Constitution-owned `llmctl` wrapper (User mandate, 2026-10-12).** Compact summary: every governed project, service, test harness and nested submodule obtains, starts, queries, validates and require-validates local models ONLY through the constitution's `scripts/llm/` wrapper (resolved by `find_constitution.sh`, never copied); the wrapper pins the `llmctl` version, refuses to hand out an endpoint for a model whose `require-validated` is not 0, validates after start, exits 0/1/2, and audits each call without content or credentials; direct `llmctl` invocation in any tracked file outside the `llmctl` repo and the wrapper is banned; remote hosts are reached by running the wrapper on them via untracked host config, named by role only. Full text in `Constitution.md`.

**§11.4.278 — Validated-before-use (User mandate, 2026-10-12).** Compact summary: no model `llmctl` runs is used by anything before a machine-written validation record — every model-file sha256, engine tag, `llmctl` and wrapper version, suite content hash, host fingerprint, sampling, ≥3 runs with identical per-probe verdicts and output hashes on that host — is a fresh PASS; any key change invalidates it, the age ceiling is 30 days (consumers may be stricter), each host of use validates separately, every model kind has a suite, and `require-validated` rc ≠ 0 refuses use. Full text in `Constitution.md`.

**§11.4.279 — Golden-content oracle bank (User mandate, 2026-10-12).** Compact summary: vision models are validated on a constitution-owned base bank (plus each project's bank) of reproducibly generated screenshots of KNOWN content, with machine-readable expectations from a closed deterministic check vocabulary (no LLM judge), and a flagged golden-bad control for every probe category; a failed golden or a passed control is a defect classified from a closed set — only fixture/expectation/prompt defects may change the bank, with ground truth and review, and a model-capability gap never loosens an expectation; other kinds carry known-answer suites. Full text in `Constitution.md`.

**§11.4.280 — Vision-eyed full-suite UI QA (User mandate, 2026-10-12).** Compact summary: every project with an interactive UI (web, desktop, mobile, TV, wizard, TUI; not non-interactive CLIs) keeps a screens × states × platforms ledger derived from its §11.4.219 IA, runs HelixQA suites over every row, flow, use case and edge case, with every on-screen assertion decided by a validated local vision model on a hashed captured frame; vision absent/erroring/unvalidated = BLOCKED, never PASS; each run self-validates with golden-good/bad frames; each platform has a seeded defect the suite must catch; release is blocked on any missing, failing, blocked, uncovered or stale row. Full text in `Constitution.md`.

**§11.4.281 — Vision-family docs + propagation in the same change (User mandate, 2026-10-12).** Compact summary: the wrapper user guide, validation-record reference, golden-bank and HelixQA vision-suite authoring guides, FAQ, data-flow / state-machine / sequence diagrams and the ledger coverage graph are updated (and re-exported per §11.4.65) in the same change that alters the behaviour they describe; `post_update_hook.sh` checks consumers resolve the wrapper and parse the ledger schema; templates carry the pointer paragraph. Full text in `Constitution.md`.
```

## 2. Consumer pointer paragraph (consumer `CLAUDE.md` / `AGENTS.md` / `QWEN.md` / `GEMINI.md`)

Consumers in pointer form (§11.4.35 invariant 6) add one paragraph to the shared
(lockstep) region of all four root carriers. In this repository the shared
region starts after the per-agent opening block; edit it once and recompose
(see the C5 note in this repository's `CLAUDE.md`).

```markdown
### Local models, validation and vision QA (11.4.277–11.4.281)

Local models are obtained and used ONLY through the constitution wrapper
(`submodules/constitution/scripts/llm/`, 11.4.277) — never by calling `llmctl`
directly from a tracked file. No model is used before a fresh, deterministic,
per-host validation record passes (11.4.278); vision validation uses the
golden-content bank with golden-bad controls and a deterministic judge
(11.4.279). If this project ships an interactive UI, its HelixQA suites keep a
screens × states × platforms ledger with vision-decided, frame-bound verdicts,
BLOCKED-never-PASS, and a seeded defect per platform (11.4.280); docs and
diagrams change in the same commit (11.4.281). Hosts are named by role only;
no credential or host name enters a tracked file. Read the blocks in
`submodules/constitution/Constitution.md`; do not reason from this paragraph.
```

Adapt the path (`constitution/` versus `submodules/constitution/`) to the
consumer's layout; `find_constitution.sh` accepts both.

## 3. Templates (`submodules/constitution/templates/`)

Measured 2026-10-14: the directory holds exactly three templates —
`AGENTS.project.md.template`, `CLAUDE.project.md.template`,
`Constitution.project.md.template`. There is NO `QWEN` or `GEMINI` template;
whether one should be added is listed in `06_open_questions.md` (Q9).

- `CLAUDE.project.md.template` and `AGENTS.project.md.template`: add the
  section-2 paragraph, with `{{CONSTITUTION_PATH}}` (or the template's existing
  placeholder convention — UNCONFIRMED which one it uses; read before editing)
  in place of the literal path.
- `Constitution.project.md.template`: add a DATA block for consumers to fill:

```markdown
## Local-model and vision-QA declarations (11.4.277–11.4.281)

| Key | Value |
|---|---|
| Profiles used | e.g. `vision`, `small` |
| Host roles of use | e.g. development host, remote GPU host |
| Validation max age (days, ≤ 30) | |
| Interactive UI shipped | yes / no |
| Surfaces × platforms | |
| IA contract path (11.4.219) | |
| Coverage ledger path | |
| Seeded-defect manifest path | |
| Max ledger row age (days) | |
```

## 4. User-scope index lines (`~/.claude*/CLAUDE.md` INDEX)

Insert after `11.4.276` (the host INDEX currently ends at `11.4.271`; the
integrator adds 272–276 first if they are still missing):

```
11.4.277 Constitution-owned llmctl wrapper; direct llmctl calls banned
11.4.278 Validated-before-use: fresh deterministic per-host model record
11.4.279 Golden-content oracle bank + golden-bad controls, no LLM judge
11.4.280 Vision-eyed full-suite UI QA: ledger, BLOCKED never PASS, seeds
11.4.281 Vision-family docs/diagrams/exports in the same change + propagation
```
