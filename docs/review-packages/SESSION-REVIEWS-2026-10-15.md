# Independent reviews recorded for the 2026-10-14/15 session

| Field | Value |
|---|---|
| Revision | 1 (2026-10-15) |
| Author | orchestrating session (relays verdicts; did not review) |
| Reviewers | independent reviewer sessions (Fable model, xhigh/high effort), each a separate agent that did not write the reviewed change |
| Scope | verdicts delivered this session that were previously held only in session reports (§11.4.215: a doc that binds work must live tracked) |
| Content rule | ids, counts, verdicts and evidence pointers only; no private text, no secrets |

The evidence pointers below are untracked scratch directories on the development host
(`~/.cache/agent-scratch/<dir>`); they are hints for re-derivation, not records.
Every claim here was reproduced by the named reviewer with its own runs. Re-derive before relying.

## Verdicts

| Reviewed | Verdict | Findings (follow-ups, none blocking unless stated) | Scratch pointer |
|---|---|---|---|
| Workshop `source_ref` redaction `9af629d`, `d3a2304`, `1d4cdfa` | GO | flattened-record generality, alias collisions, Windows path basename, doc sync, RAM-backed tmp default: all fixed in `9cf260a`, `398c5ef` | `rev-srcref` |
| Workshop selection work `e50fb20`, `0a68a0c` | GO | verifier prints at most 40 findings | `rev-srcref` |
| Sweep `3ff5c2e`, `9b4da86` | GO | precision (2 false positives), runtime 93-101 s vs claimed 60-80 s, harness gaps: fixed in `01f6f6c` | `rev-sweep`, `rev5-w2` |
| Sweep follow-ups `01f6f6c` | GO | redirect/`#` glued to a path honoured an exemption (LOW), `[ ]` proof path credited lexically (LOW, pre-existing), 2 of 4 quoted timing samples have no saved artefact | `rev-sweep2` |
| Workshop ingest/answering/auth/owner `a4190db`, `ead58cd`, `f25b6e7`, `83ffa49` | GO | 7 LOW/INFO follow-ups, fixed in `e6b9eba`, `1e79147`, `4094a7e`, `7ea39b1`, `63b2f97` | `rev5-w2` |
| CONST-050(B) floors `RAG 90b7058`, `LLMProvider/llm_provider 261cfde`, `security 0513361`, `doc_processor b2ad2f7`, `llm_orchestrator c84c410`, `vision_engine d52fa44` + umbrella bumps `f681787 a7cae60 1717dfe bd9674f d7a10e3 bf14c0a 99921c1` + docs `85b631e` | GO | MEDIUM: integer overflow (2^64) defeats the 1..100 rule (needs the explicit override; documentation sentence false for these values); MEDIUM: scaling precedence (`env-single-replica` rc 2 outranks the down-replica finding); LOW: proof-strength gaps (override prefix/case, WARNING line, evidence fields), newline in replica list drops replicas, URL userinfo echoed | `rev-floors` |
| VSC-368 scanner cascade (9 submodule commits, umbrella `f323414`, `e2dfe37`) | GO | LOW/MED: `bin out build dist target obj` excluded from the scan scope; LOW: allowlist substring over-match; known misses `systemctl -i suspend`, `shutdown +5`, `/sys/power/state` | `rev-prepush/A` |
| ai_interviewing `275928e`, `5c0ed32` | GO | LOW: proof arm cannot tell a 500 from a dead port; `source_dirty` scoped to `platform/` | `rev-prepush/B` |
| llms_verifier `568c9182`, `6674ad4b`, `7623a2c8` | GO | LOW: self-fragile `--prove-failure` anchor; `exec_cmd` without pipefail logs a failed build as success (pre-existing) | `rev-prepush/C` |
| catalogizer `f3f013a` | GO | LOW: 3 of 10 scripts converted to the 0/1/2 contract; literal admin credentials in `run-helixqa-web.sh` (pre-existing) | `rev-prepush/D` |
| Workshop `9cf260a`, `398c5ef` | GO | none | `rev-prepush/E` |
| Workshop `b6d6ab2` (quick-start credential step) | NO-GO as written (live-password hazard), superseded by `47beafb`, `4e25937` | HIGH: step 5a resolved the LIVE volume and `workshop-passwd` rotates the real password | `rev-prepush/E`, `rev-qs` |
| Workshop `47beafb` (quick-start safety fix) | GO (conditional) | guard was a bypassable denylist; cold start can replace the shared live binary: addressed in `4e25937` | `rev-qs` |
| Workshop SC-009 chain `f8ec8b0`, `e934bf6`, `fb277ab`, `22abfea`, `5518c23`, `da916c1` | GO | MEDIUM proof gap (non-vacuity check has no paired mutant); reason codes overstate for 9 of 11 rows; 3 removals look re-citable; catalog/bank drift of 10 entries predating SC-009 | `rev-sc009` |
| Workshop lows `e6b9eba`, `1e79147`, `4094a7e`, `7ea39b1`, `63b2f97`; umbrella `2f0d442` | GO | LOW: xattrs not preserved by the temp+rename helper; dangling symlink replaced | `rev-prepush/H` |

## Verdicts that are not GO (recorded so they cannot be lost)

| Reviewed | Verdict | Why |
|---|---|---|
| llmctl `43ad7b1..18b6728` (round 4) | NO-GO | 41 clear false PASS remain in probes judged by blocked words (`contains_all`/`contains_any`/`forbidden`); MEDIUM: failed env-record write swallowed and the unit started with the stale record; marker present-but-malformed fails open. One fix round of the §11.4.276 budget remains. Do not run `llmctl install`. Pointer `rev-llmctl4` |
| constitution `feature/label-sync` `9c75e88..4ea4d74` | NO-GO (conditional) | `render/labelrun` signal window before traps and a test narrowed instead of fixed; step 1 of the post-update hook drops renamed skills; round 5 of the budget. Pointer `rev-labelsync4` |

## Not covered by this record

Reviews of the remaining unpushed commits are tracked separately:
`docs/review-packages/WORKSHOP-BATCH-REVIEW-2026-10-15.md` and
`docs/review-packages/UMBRELLA-BATCH-REVIEW-2026-10-15.md` (written by their reviewers when they finish).
