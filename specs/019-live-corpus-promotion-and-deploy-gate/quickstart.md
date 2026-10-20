# Quickstart: Live Corpus Promotion and Deploy Gate

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Validation scenarios, run from `workshop/` of the **primary** checkout by the orchestrator unless a scenario says "isolated server". Token handling via
`scripts/_live_auth.sh`; never printed.

## Scenario 1 — see the problem first (RED baseline, US2)

```bash
bash scripts/deploy-gate.sh --post --evidence evidence/019-$(date -u +%Y%m%dT%H%M%SZ)/red
echo "rc=$?"    # expected non-zero on today's stack; the failing check ids are the finding
```

## Scenario 2 — rebuild and promote the frontend (US1)

```bash
bash scripts/promote-web.sh --build --stage           # bounded; no live change
bash scripts/promote-web.sh --promote --require-verdict <pre-verdict.json>
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8087/            # 200
sha256sum platform/frontend/dist/**/index.html; curl -s http://127.0.0.1:8087/ | sha256sum   # equal
curl -s http://127.0.0.1:8087/build-info.json                               # commit == git -C . rev-parse HEAD
```
UI: hard reload; walk `evidence/…/ui-acceptance-us1.md`.

## Scenario 3 — the What is live panel (US3)

Open `/status`. Expected: build + commit, bundle hash, registry digest (loaded = disk), counts by kind and content type (sum = total), index generation and
passages, feature flags in words. Forced mismatch (isolated server): rewrite the registry copy after boot → banner "the file on disk is not what the server
loaded".

## Scenario 4 — promote a registry (US4), fixture first

```bash
bash scripts/promote-registry.test.sh                                  # fixtures, no live effect
bash scripts/promote-registry.sh --candidate curriculum/passages.jsonl --apply   # live no-op => rc 0 "already promoted"
bash scripts/promote-registry.sh --status --verify                      # journal chain intact
```

## Scenario 5 — the gate refuses a stale verdict (US2)

Produce a PASS `--pre` verdict, then touch the staged bundle; `restart.sh --dry-run --require-verdict <file>` → refused, reason "fingerprint changed".

## Scenario 6 — GREEN after promotion

`deploy-gate.sh --post` → rc 0; `live-019.sh` writes `result.json` + `manifest.sha256`.
