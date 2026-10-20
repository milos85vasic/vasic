# Phase 1 Data Model: Live Corpus Promotion and Deploy Gate

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

No database table is added. Entities are derived values (server), JSON documents (host evidence) and one append-only file (journal).

## 1. BundleManifest *(derived; server and host compute it identically)*

| Field | Type | Rule |
|---|---|---|
| `lines` | list | `"<relpath>\t<sha256>\n"`, relpath relative to the web dir, `/` separators, sorted bytewise (`LC_ALL=C`), no leading `./` |
| `file_count` | int | number of lines |
| `manifest_sha256` | hex string | sha256 of the concatenated lines |
| `index_html_sha256` | hex string | sha256 of `index.html` alone (the over-the-wire comparison key) |

Refusals (fail closed): a symlink resolving outside the root, an unreadable file → error, never a partial manifest. `build-info.json` is
**included** in the manifest (it is part of what is served).

## 2. BuildInfo *(file `build-info.json` inside the bundle; generated, git-ignored)*

`{ "commit": "<40 hex>", "dirty": false, "built_at": "<RFC3339 UTC>", "node": "<version>", "lockfile_sha256": "<hex>", "source": "promote-web.sh" }`
No path, no hostname, no username.

## 3. Provenance *(response of `GET /api/system/provenance`)*

```json
{
  "generated_at": "RFC3339",
  "build":    { "build": "…", "source_commit": "…", "source_dirty": false, "built_at": "…", "identity_source": "ldflags" },
  "web":      { "servable": true, "file_count": 0, "manifest_sha256": "…", "index_html_sha256": "…",
                "build_info": { "commit": "…", "dirty": false, "built_at": "…" } | null,
                "build_info_matches_server_commit": true | false | null },
  "registry": { "basename": "passages.jsonl", "loaded_sha256": "…", "loaded_rows": 0, "loaded_at": "…",
                "disk_sha256": "…", "disk_mtime": "…", "disk_matches_loaded": true | false },
  "corpus":   { "total": 0, "by_kind": { "<kind>": 0 }, "by_content_type": { "<content_type>": 0, "unclassified": 0 }, "suppressed": 0 },
  "index":    { "generation": 0, "state": "…", "pid_count": 0, "root_hash": "…", "built_at": "…", "pid_count_matches_registry": true | false | null },
  "features": { "answering": { "provider": "none", "enabled": false }, "rerank": { "window": false, "cross_encoder": false },
                "embed_model": "…", "embed_carry_forward": true, "search_vector_cache": true }
}
```
Rules: every block can independently be `{"status":"unavailable","reason":{"code":"…","message":"…"}}`; `null` means *not applicable /
not determinable*, never "false"; no key or string value matches the leak regex (contract invariant). Counts by content type sum to `total`.

## 4. CandidateFingerprint

`{ "server_bin_sha256": "<hex from stamp bin_sha256>", "bundle_manifest_sha256": "<hex>", "registry_sha256": "<hex>" }` — recomputed at use time;
the verdict's copy is only valid while all three still match.

## 5. Verdict *(`evidence/019-<run>/verdict.json`; schema in `contracts/deploy-gate-verdict.md`)*

`{ run, mode: "pre"|"post", head, candidate: CandidateFingerprint, checks: [ { id, name, expected, observed, rc, note? } ], verdict: "PASS"|"FAIL"|"UNDETERMINED", rc, created_at }`.

## 6. PromotionJournalRow *(`.backups/promotions.jsonl`, append-only)*

| Field | Type | Notes |
|---|---|---|
| `ts` | RFC3339 | |
| `run` | string | `registry-<UTC>` / `web-<UTC>` |
| `kind` | enum | `registry_promote`, `registry_rollback`, `web_promote`, `web_rollback`, `web_prune`, `override` |
| `pre_sha256` / `post_sha256` | hex | live file digest before/after (registry) or manifest hash (web) |
| `backup` | path (relative) | real-copy backup, distinct inode |
| `outcome` | enum | `ok`, `noop`, `refused`, `interrupted` |
| `reason` | string | required for `override` and `--allow-changes` |
| `prev_sha256` | hex | sha256 of the previous row's canonical JSON (first row: 64 zeros) |

Validation: `--status --verify` recomputes the chain; any mismatch → rc 1 naming the row index.

## 7. State machines

**Promotion (web):** `idle → staged → verified → promoted → pruned`; side exits `promoted → rolled_back`, any state → `interrupted` (served dir still
entirely old or entirely new). **Gate verdict:** `UNDETERMINED` (default on any unknown) → `FAIL` (any check rc 1) → `PASS` (all checks rc 0);
precedence `FAIL` over `UNDETERMINED` over `PASS` is **not** used — an unknown never hides a failure and a failure never hides an unknown:
the verdict lists both, and the exit code is 1 if any check is 1, else 2 if any is 2, else 0.
