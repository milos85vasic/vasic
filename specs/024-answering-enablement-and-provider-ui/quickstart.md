# Quickstart: Answering Enablement + Provider Status UI

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Validation scenarios per story. Commands run from `workshop/` unless noted. Worktree streams run
them against a SCRATCH server only; the live stack is the orchestrator's.

## Scenario 1 - See the state (US1)

```bash
# scratch server per gates/answer-eval/README.md, extractive provider, index COPY
bash platform/backend/gates/answer-eval/eval.sh --variant smoke --answer-provider extractive --print-cmd
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:$PORT/api/answering/overview | python3 -m json.tool | head -40
```
Expect `state` of `on_cleared` ONLY if a matching PASS verdict exists, otherwise `off_gate_not_cleared`
(the scratch server uses the production boot path in this scenario). `providers` lists the catalogue.

## Scenario 2 - Measure and read a verdict (US2)

```bash
bash scripts/answering-measure.sh --provider extractive --runs 3      # writes evidence/answering-verdicts/verdict-*.json
cmd/answering-verdict-check evidence/answering-verdicts                # rc 0: all files valid
python3 -c "import json,glob;print(json.load(open(sorted(glob.glob('evidence/answering-verdicts/verdict-*.json'))[-1]))['result'])"
```
PASS or FAIL are both valid outcomes; the `sides` object says which side decided.

## Scenario 3 - Boot gate (US2)

Start a scratch server with `-answer-provider ollama` and (a) an empty verdict dir, (b) a FAIL verdict,
(c) a PASS for a different model. In all three: `/api/ask/status.enabled` is false, `GET /api/ask` is
503 `no_provider`, a search request is 200. With a matching PASS: enabled true.

## Scenario 4 - Fabrication fixtures (US3)

```bash
cd platform/backend && go test ./pkg/answer/ -run Fabrication -count=1 -v
```
RED on the pre-fix commit, GREEN after. Replay on a scratch server per `tasks.md` T063.

## Scenario 5 - Guarded procedure (US5)

```bash
bash scripts/answering-enable.sh --provider ollama --model qwen2.5:3b-instruct-q4_K_M --dry-run   # rc 1 without a verdict
bash scripts/answering-postcheck.sh --expect off --out evidence/024-answering-enablement/live/pre
```

## Operator acceptance (UI-visible; this is the step that lets the operator SEE it)

1. Log in to the platform and open `/settings/providers`.
2. You should see: a state card (today: "OFF - not configured"), a sentence saying search and browsing
   are unaffected, the provider table (every catalogue row, incl. `extractive`, `ollama` and the hosted vendors; the
   `openai_compatible` stub marked as not selectable), the gate card ("no verdict" or the newest
   verdict with PASS/FAIL per side), and - as an administrator - the audit card ("not available on
   this build" until spec 011 US2).
3. Open `/ask`: with answering off you should see the off banner with a link back to the status page;
   the Search tab still returns results.
4. Confirm there is no button anywhere that turns answering on.
5. Compare the short fingerprint on the gate card with `ls workshop/evidence/answering-verdicts`.
6. On a phone-width window (390 px) the table scrolls inside its own container and nothing overflows
   the page.
Sign-off is recorded by the orchestrator in the progress notes.
