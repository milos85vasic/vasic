# Workable-items to Issues sync: design (2026-11-24)

| Field | Value |
|---|---|
| Status | DESIGN, proposal only; operator decisions of 2026-11-24 recorded in section 8.1. No issue was created anywhere, no constitution file edited. |
| Operator order | 2026-11-24 (CRITICAL): all workable items (to do, in progress, done) are always created and kept up to date in the Issues of every supported upstream of the umbrella and of every submodule recursively (GitHub, GitLab, Gitea at m3w and Codeberg, GitFlic, GitVerse), in sync with Docs Chain, the SQLite DB, the status docs and all trackers. Constitution-level default mechanism, OFF by default, ON for this project. Addendum: engine, adapters, verifier, template config, hooks and anchor live in the Constitution submodule; consumers carry only a small config and call the constitution's scripts through existing inheritance. |
| Evidence date | 2026-11-24, read-only probes from this host (section 1 and 2). Anything not probed is marked UNKNOWN. |
| Related canon | 11.4.15/16/33/54/55/56/63/86/90/93/95/106/148/153, 11.4.296 (inbound), 11.4.299 |

## 1. Inventory (measured)

### 1.1 Workable-items DBs

SQLite, tracked in git (11.4.95). Three DBs exist at depth under this tree:

| DB | items | by status | by type | location | id prefixes |
|---|---:|---|---|---|---|
| `docs/workable_items.db` (umbrella, schema_version 8) | 659 | Completed 351, Queued 226, Operator-blocked 57, Fixed 17, In progress 5, Implemented 2, Obsolete 1 | Task 602, Bug 50, Feature 7 | Issues 288, Fixed 371 | VSC 430, WSP 178, MVR 11, CON 11, PSG 7, CKT 6, AII 5, LMV 3, and one each CNT DOC DTK HLP HQA LLP MON VDC |
| `job_seeker/docs/workable_items.db` | 27 | Queued 27 | Feature 27 | Issues 27 | JSK 27 (job_seeker also keeps `specs/001-job-seeker-mvp/tasks.md`: 299 task lines, 134 checked, a SECOND tracking system that is not in this DB) |
| `submodules/constitution/docs/workable_items.db` | 564 | Queued 463, In progress 57, Ready for testing 30, Completed 6, Fixed 3, Obsolete 3, Operator-blocked 2 | Task 396, Bug 166, Feature 2 | Issues 552, Fixed 12 | CON 564 (the constitution repo's own DB; the umbrella DB holds 11 other CON rows) |

Total 1250 rows. Open (not in Fixed) is 288 + 27 + 552 = 867. No other own-org submodule has a `docs/workable_items.db`; their items live in the umbrella DB under their prefix (`sub_projects` table maps prefix to path, ownership, URL). Workshop has no separate DB: WSP items (178: 119 Completed, 5 Fixed, 15 Operator-blocked, 45 Queued) are rows in the umbrella DB.

Schema facts that matter: PK is `(atm_id, current_location, representation)` (the same id may appear as a section and a table row, so the sync key must collapse by `atm_id`); `type` in {Bug, Feature, Task}; 10 status values; `current_location` Issues or Fixed; `body_md`, `closure_date`, `commit_ref`, `parent_atm_id`, `recurrence_of`, reproduction and investigation state columns; separate tables `item_history`, `test_diary`, `item_provenance`, `meta`, `sub_projects`. `sub_projects` URLs are stale for three rows (ai_interviewing, monetization, workshop list `milos85vasic/...`; the real remotes are `vasic-digital/...`). That table must be corrected before any routing uses it.

Tooling: Go CLI `_tools/workable-items/` (`internal/wi/{store,validate,backfill,roster,modulereport,gap*}.go`). Docs Chain: contexts under `.docs_chain/contexts/` (`umbrella-docs`, `umbrella-root`, `umbrella-specs`), verified by `scripts/verify-docs-chain.sh` (registered `docs-chain-sync`). The Docs Chain engine is NOT a submodule here (`.gitmodules` has no docs_chain entry, `which docs_chain` empty, `~/Projects/docs_chain` absent), so the CLI cannot be invoked from a clean clone of this repo; 11.4.106's own status note says the same about its registration. This is a prerequisite blocker (Q7, decided in section 8.1: add as submodule).

### 1.2 Existing issue-touching scripts

- `submodules/constitution/scripts/forge/forge.sh` plus `providers/{github,gitlab,gitea,gitflic,gitverse}.sh`, `config/forge/hosts.tsv`: release API only (no issue verbs), credentials by variable NAME with `lib/credentials.sh`, `lib/http.sh` (no token in argv). This is the natural home for issue verbs and the host map (host to provider to token variable names): github.com GITHUB_TOKEN/GH_TOKEN; gitlab.com GITLAB_TOKEN; codeberg.org CODEBERG_GITEA_TOKEN/CODEBERG_TOKEN; git.m3w.org M3W_GITEA_TOKEN; gitflic.ru GITFLIC_TOKEN; gitverse.ru GITVERSE_TOKEN.
- `scripts/verify-provider-ci.sh`, `scripts/verify-push-topology.sh` (umbrella): read-only provider probes, reusable patterns.
- `submodules/constitution/scripts/gates/cm_github_issues_source_anchor_wired{,_mutation_test}.sh`: checks only that the 11.4.296 TEXT is wired. The constitution states the item-level gate `CM-GITHUB-ISSUES-SYNC-EVIDENCE` is deferred (`OWED-GATE-181`) and that it ships no sync engine, platform client or run-record store. So nothing implements 11.4.296 today; grep of umbrella `scripts/` finds no `gh issue` writer.
- Repo-wide: no tool creates or updates issues. The 11.4.294(I) one-way DB-to-external-tracker mirror is specified, not implemented here (UNCONFIRMED beyond grep).

### 1.3 Per-repo matrix (GitHub measured with `env -u GITHUB_TOKEN gh api`; has_issues true on every repo probed)

| Repo | Visibility | Open issues now | Notes |
|---|---|---:|---|
| milos85vasic/vasic (umbrella) | public | 1 | GitLab: 404 |
| milos85vasic/milosvasic.ru | public | 0 | |
| vasic-digital/vasic-digital.github.io | public | 0 | |
| vasic-digital/design-toolkit | public | 0 | GitHub plus a private GitLab mirror (per carrier) |
| vasic-digital/ai_interviewing | PRIVATE | 0 | |
| vasic-digital/monetization | PRIVATE | 0 | |
| vasic-digital/workshop_curriculum | PRIVATE | 0 | |
| vasic-digital/job_seeker | PRIVATE | 0 | GitLab 404; has disabled recipes for codeberg, gitflic, gitlab, gitverse, m3w pointing at `job_seeker_public` (a different, public repo) |
| vasic-digital/containers | public | 1 | GitLab exists, public, issues enabled |
| LLMProvider, RAG, verdict, passage, curriculum-kit, HelixQA, challenges, DocProcessor, LLMOrchestrator, LLMsVerifier (1 open), security, VisionEngine | public | 0 (one has 1) | other hosts UNPROBED per repo |
| HelixDevelopment/HelixConstitution | public | 0 | the constitution repo itself (governance source) |
| HelixDevelopment/{qa,LLMProvider,DocProcessor,LLMOrchestrator} | public | 0 | second org names for modules also under vasic-digital; `submodules/llm_provider` and `submodules/LLMProvider` both point at vasic-digital/LLMProvider.git (duplicate gitlink, prefixes HLP vs LLP) |

Non-GitHub hosts (authenticated read probes, token read by name, values never printed): codeberg.org, git.m3w.org and gitflic.ru accept the tokens (HTTP 200 on the user endpoint); GitVerse answered 415 to a bare call (needs the header `Accept: application/vnd.gitverse.object+json;version=1`, per its docs). Org membership: Codeberg has `vasic-digital` and `HelixDevelopment`; m3w has `vasic-digital`, `helix`, `m3w`. BUT `vasic-digital/containers`, `vasic-digital/job_seeker` and `HelixDevelopment/HelixConstitution` return not found on Codeberg and m3w, and the umbrella is not found under `milos85vasic` there. GitFlic returns ProjectNotFound for `vasic-digital/containers` and `milosvasic/vasic`. Finding: outside GitHub, and GitLab for some repos, the repositories (and hence their Issues) mostly DO NOT EXIST on these hosts today; the only non-GitHub/GitLab upstream recipes declared in the tree are job_seeker's disabled ones. Sync can only go to a tracker whose repo exists, so the effective upstream set per repo must be derived from declared `upstreams/*.sh` plus remotes, not from the order's host list (Q1).

### 1.4 Host API capability (official docs read 2026-11-24; UNKNOWN where not verified)

| Host | Create / update / close | Labels | Milestones | Issue number | Enable Issues by API | Rate limits and auth |
|---|---|---|---|---|---|---|
| GitHub | `POST /repos/{o}/{r}/issues`; `PATCH .../{n}` with `state` open/closed and `state_reason` completed/not_planned/reopened | in body, PATCH replaces the set | yes | `number` per repo | `PATCH /repos/{o}/{r}` `has_issues` (documented GitHub feature; not re-probed here). Create on a repo with issues disabled returns 410 | secondary limit warns on rapid content creation; token Bearer; batch with 1 s spacing and Retry-After |
| GitLab | `POST /projects/:id/issues`; `PUT .../:iid` `state_event` close/reopen | `labels`, `add_labels`, `remove_labels`; auto-creates project labels | yes | `iid` (not `id`) | project `issues_access_level` via project edit (UNVERIFIED here) | content-creation limit on create; updates 1,200 req/min/user; private token |
| Gitea (m3w, Codeberg) | create and edit issue operations exist (swagger 1.22); `state` field on edit and `has_issues` on repo edit are standard Gitea but NOT confirmed from the page fetched (UNVERIFIED) | add/replace/remove label endpoints exist | yes (standard) | `number` per repo | repo edit `has_issues`: UNVERIFIED | rate limit not stated (UNKNOWN); Codeberg has Forgejo-specific limits UNKNOWN; token auth works |
| GitVerse | docs page lists `GET/POST /repos/{o}/{r}/issues`, `PATCH .../issues/{n}` (title, description, labels, assignees, type); labels and milestones CRUD present | yes | yes | per repo number | UNKNOWN (repo PATCH documented without issue settings) | Rate Limits page not read: UNKNOWN; 429 exists. Closing an issue: UNKNOWN (no `state` field documented on the issue PATCH). Header `Accept: application/vnd.gitverse.object+json;version=1` required |
| GitFlic | NOT VERIFIED: docs host returned 403 to the fetch tool and a web search found no endpoint. The constitution's own provider notes say only releases/tags are known and write paths are "LIVE-UNPROVEN", rate limit 500 requests/hour | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | 500 req/hour (from forge notes) |

Consequence: the adapter contract must have capability flags per host and repo (`can_create`, `can_close`, `can_label`, `issues_enabled`). A host that cannot close an issue gets a status label plus a trailing comment instead, and the verifier reports it as `PARTIAL-CAPABILITY`, never in sync (3-valued: capability absence is rc 2 for that leg, not a pass).

## 2. Content boundary (visibility rule)

Risk: private repos (workshop_curriculum, ai_interviewing, monetization, job_seeker) hold items whose text may carry private material; the umbrella is public and its DB already holds 184 private-prefix rows (WSP 178, AII 5, MON 1; 15 WSP are Operator-blocked, 45 Queued). Mirroring them to a public tracker is an irreversible disclosure.

Rule (data, enforced by the engine, not by convention):
1. An item's visibility equals the visibility of its OWNING repo, resolved from the prefix through `sub_projects` plus the live provider answer (never from a cached claim). Unresolvable visibility is `undetermined`, which blocks the item (rc 2), never defaults to public.
2. An item is created only in trackers of its owning repo. WSP items go only to the private `workshop_curriculum` trackers; AII to `ai_interviewing`; MON to `monetization`; JSK to `job_seeker`. Never into the umbrella's trackers, and never the reverse direction either: a public repo's tracker never receives a pointer carrying private title text.
3. Umbrella rows with private prefixes get NO public issue. The umbrella's own tracker may carry at most an opaque counter if the operator asks (Q4); default none.
4. Redaction gate before any write: the outgoing payload (title, body, labels) is scanned for secret patterns (token shapes, `.env` values, key-file lines), personal data patterns, and, for any public target, for fingerprints of the private corpus using the existing content-boundary gate (`scripts/verify-content-boundary.sh`) as the engine. A hit is a hard stop with the item named by id only.
5. A repo's visibility change (private to public) re-runs the gate over everything already mirrored; a private-to-public flip with unredacted items is rc 1.
6. Only the DB fields `atm_id`, `type`, `status`, `title`, `severity`, `description` (floor text) and a link to the in-repo document are mirrored; `forensic_anchor` (verbatim operator quotes), `body_md`, reproduction evidence and test diaries are NOT sent to any tracker by default (they carry operator text); the issue body holds a repo-relative path, resolvable only by someone who can read the repo.

Nested and private cases:
- Nested constitution: `submodules/constitution` is the governance source (not consumer-owned). Its 564 CON items belong to HelixDevelopment/HelixConstitution trackers. The umbrella's 11 CON rows (items ABOUT the pin) stay in the umbrella tracker; `sub_projects` already says "no item may be filed INTO that repository" for the umbrella, and the engine honors that: CON-prefix routing is by DB location (which DB holds the row), not by prefix alone.
- Constitution repo itself consumes its own mechanism: enabled flag in its own config, scope recursive false (it has no own-org submodules of interest here beyond `design-toolkit`).
- Third party (`superspec`, prefix SSP): never synced, `enabled:false` forced.
- Private submodule inside a public parent: the parent's run walks submodules via the existing fleet derivation (`.gitmodules` plus `helix-deps.yaml`), resolves each module's visibility independently, and writes ONLY to that module's own trackers. A public parent's run record lists private modules by id count only (no titles) because run records are tracked in a public repo.
- Duplicate gitlinks (`llm_provider` and `LLMProvider`): dedupe by canonical remote URL; one sync target per repo.

## 3. Mechanism

### 3.1 Principles
DB is the single source of truth (11.4.93). Trackers are a one-way mirror (DB to tracker). A tracker edit never changes an item's status or closure. The only inbound path is 11.4.296 intake (issues assigned to a declared account become items once).

### 3.2 Components (all in the constitution repo, consumed by reference)
- `scripts/issue_sync/issue_sync.sh` (or a Go binary under the constitution's tool layout): subcommands `plan`, `apply`, `verify`, `status`, `backfill`, `intake`, each three-valued (0 / 1 / 2), dry-run default, `--apply` required to write.
- `scripts/issue_sync/adapters/{github,gitlab,gitea,gitflic,gitverse}.sh`, built on `scripts/forge/lib/{common,credentials,http}.sh` and `config/forge/hosts.tsv` (new verbs `issue-get`, `issue-find-by-key`, `issue-create`, `issue-update`, `issue-close`, `issue-reopen`, `labels-ensure`, `issues-enabled`, `capabilities`).
- `scripts/gates/cm_issue_sync_*.sh` plus paired mutation tests; verifier `scripts/gates/verify_issues_sync.sh`.
- `templates/workable-items-sync.yaml.template` (consumer config, default `enabled: false`).
- Docs Chain context template `templates/docs_chain/issues-sync.yaml`.

### 3.3 Identity, mapping and idempotency
- Stable external key: `[VSC-123]` as the title prefix, plus a hidden body footer `<!-- workable-item: VSC-123 | db: <relative DB path> | sha256: <canonical content hash> -->`. Lookup is by footer key first (list with state=all, paginated), then title prefix; the issue number is never the identity.
- New DB table `issue_sync_map(atm_id, tracker, host, repo, issue_number, issue_url, content_hash, last_synced_at, state, last_error)` PK `(atm_id, tracker, host, repo)`. The `schema_version` bumps (8 to 9) with a lossless migration (`migrateColumns` precedent).
- Content hash = sha256 over canonical JSON of the mirrored fields only (section 2 rule 6) after redaction; unchanged hash means no API call (this is also the quota saver).
- Create when no map row and no key found; update when hash differs; close when the item enters a Fixed/Completed/Implemented/Obsolete status (Obsolete closes with `not_planned` where supported); reopen when a Reopened status or a status leaving the closed set is seen; a closed tracker issue whose item is still open is reopened by the next run (tracker edits never win).
- Labels (ensured idempotently per repo): `status:<slug>` (one at a time, previous removed), `type:bug|feature|task`, `wi-sync`. Milestones: optional, from release tags (Q6); default none.
- Duplicates: two issues with one key are reported rc 1 and resolved by keeping the lowest number and closing the others with a comment, only under `--apply --dedupe`.
- Rate and resume: per host token bucket from the capability table, exponential backoff honoring Retry-After, batches checkpointed in `issue_sync_map` (resume without repeating), a run lock, and a run record (`qa-results/issue_sync/<run-id>/`, counts only for private modules).

### 3.4 Triggers
1. Docs Chain: a new `issues-sync` context makes the DB the upstream node and the status docs, `Issues.md`, `Fixed.md`, summaries and the tracker mirror downstream nodes of one `docs_chain sync`; `verify` fails if any is stale. The sync node is a transform that calls `issue_sync.sh plan`, and `apply` only when config mode is `apply`.
2. Git hooks (from the constitution's installed hook set): pre-commit refuses a commit whose DB change is not yet reflected in the plan (dry-run plan must be empty or acknowledged), post-merge triggers `apply` in the background (11.4.88 style, commit lock released first).
3. Scheduled: cron/systemd timer or the `/schedule` facility calling `issue_sync.sh verify` at most every 6 h, `apply` per config interval (cap 24 h, same cap as 11.4.296(B)).
4. Post-merge delivery step of 11.4.299 calls `verify` after the push read-back.
5. Never inside CI/CD (11.4.156): local hooks and timers only.

### 3.5 Verifier `verify-issues-sync`
0 = every enabled tracker matches the DB (every mapped item exists with matching hash, labels and state; no unmapped issue with a key; no duplicate keys; visibility rule holds); 1 = drift (names item ids and trackers); 2 = cannot determine (no token, host unreachable, capability unverified, visibility undetermined, API quota exhausted). Precedence 1 over 2 over 0. Reads only. `--prove-failure` mutations (each must flip the verdict): delete a tracker issue; edit a title; close an issue whose item is open; add a duplicate key; set a private item to a public target (must be refused at plan time AND detected); strip the hidden footer; token env unset (must be 2, not 0); host returns 429 for all (2); corrupt map hash (1); DB status change without sync (1); redaction canary string in a body (hard stop); remove the sync from the Docs Chain context (gate fails). Registered in the consumer `check-registry` and the constitution gate ledger.

### 3.6 Inbound (11.4.296 interplay, no loop)
Intake imports only issues that did not originate from this engine. Origin test: the hidden footer. An issue with the footer is ours and is ignored by intake; an issue without it, assigned to a declared account, becomes a workable item once (key `GitHub-Issue: owner/repo#n` per 11.4.296(C)), and the engine then adopts that same issue as its mirror (it writes the footer and `[ID]` title prefix into the SAME issue, no second issue is created). Content-hash rules of 11.4.296(D) apply to fields the engine does not own; the engine owns title prefix, footer, status/type labels. Closing a human issue never closes the item.

## 4. Default-OFF switch and anchor

### 4.1 Config `.workable-items-sync.yaml` (consumer root)
```
enabled: false            # constitution default; template ships false
scope:
  recursive: false        # true: walk own-org submodules (fleet derived from .gitmodules + helix-deps.yaml)
mode: dry-run             # dry-run | apply
trackers: []              # [] means derive from declared upstreams/*.sh and remotes; or explicit list
visibility_policy: owning-repo   # only value allowed
interval_hours: 24        # max 24
inbound: { enabled: false, assignees: [] }   # 11.4.296 intake
docs_chain: { context: issues-sync }
token_vars: {}            # NAMES only; defaults from config/forge/hosts.tsv
```
Umbrella ships `enabled: true`, `recursive: true`, `mode: dry-run` until backfill review, then `apply` by an operator decision recorded as data. Submodules inherit by their parent walk; each also carries its own file so a standalone clone is self-contained.

### 4.2 Proposed anchor text (next free number after 11.4.299; confirm in the constitution before use)
```
### §11.4.300 — Workable items are mirrored to the Issues of every declared upstream, recursively and always in sync, as a default-OFF mechanism a project turns on (User mandate, 2026-11-24)

(A) DEFAULT AND SWITCH. The mechanism is OFF for every project. A project turns it on by a tracked
declaration `.workable-items-sync.yaml` (`enabled: true`); recursion over own-org submodules is a
declared key. The constitution ships the engine, the host adapters, the verifier, the template and the
hook and Docs Chain wiring; a consumer never copies them (11.4.28, 11.4.106).
(B) DIRECTION. The database (11.4.93) is the source of truth; the tracker is a mirror. No tracker edit
changes an item. Inbound issues are admitted only by 11.4.296, once, and never loop.
(C) SCOPE. Every item (any status, any type, to do, in progress, done) of an enabled project appears as
exactly one issue per declared upstream whose repo exists and whose Issues are enabled; a host or repo
that cannot take it is reported UNCONFIRMED, never in sync.
(D) VISIBILITY. An item is mirrored only to trackers of its owning repo; visibility is resolved live;
undetermined blocks. A redaction gate stops secrets, personal data and private-corpus text before any
write. No cross-repo write into a more public tracker.
(E) NEVER OUT OF SYNC. Stable key in the title and a hidden footer, a per-tracker mapping in the
database, a content hash, idempotent create/update/close/reopen, dry-run default, rate-limit-aware
resumable batches. A three-valued verifier (0 / 1 / 2, 2 never a pass) with paired mutations runs on
every commit/merge trigger, on the Docs Chain verify and on a schedule of at most 24 hours.
(F) DOCS CHAIN. The mirror is a node of the Docs Chain context of the project: DB, status docs, exports
and trackers are regenerated and verified together (11.4.106).
(G) HONEST BOUNDARY. A host whose API cannot be verified for a verb is reported UNKNOWN; the mirror for
that leg is UNCONFIRMED until a live create/read-back proves it.
Composes with 11.4.15/16/33/54/55/56/63/86/90/93/95/106/148/153/156/288/296/299.
```
Companion edits (constitution): `Constitution.md`, four carriers, `CLAUDE_ANCHORS_FULL.md`, anchor index, propagation covenant gate `CM-COVENANT-114-300-PROPAGATION` plus wired-gate and mutation tests, and `INDEX` lines in user-scope carriers.

## 5. Work breakdown (constitution first, then consumers)

Each is an independent PR on its own task branch, merge commit, independent review (11.4.142), fast-forward push to every upstream with `ls-remote` read-back (11.4.299). All items must name a Roadmap item (11.4.293).

Constitution repo (HelixDevelopment/HelixConstitution):
- C1 Anchor 11.4.300 text, carriers, anchors index, propagation gate and mutation test (11.4.26/164).
- C2 Template config, config schema validator, visibility resolver and redaction gate library (default-off proven by a gate that fails if the template ships `enabled: true`).
- C3 `forge` issue verbs and the five adapters plus capability probing; each adapter lands with a hermetic test double used only for the tool's own logic and a LIVE read-only probe as evidence (11.4.289).
- C4 Engine (`plan`/`apply`/`verify`/`status`/`backfill`), `issue_sync_map` migration of the workable-items store, run records, locks, rate limiter.
- C5 Verifier gate with `--prove-failure` mutations (section 3.5), gate-ledger entry, sweep integration.
- C6 Docs Chain integration: context template, hooks (pre-commit, post-merge), `post_update_hook.sh` wiring, `find_constitution.sh` resolution, scheduler recipe. Blocked on Docs Chain being a submodule (Q7).
- C7 Inbound intake adapter implementing OWED-GATE-181 (11.4.296) using the footer origin test.
- C8 Operator guide, manual and FAQ (11.4.257), exports (11.4.65), translations only if required.

Consumers (after pin bump; each bump is a fast-forward by the standing authorization for the constitution pin; every other gitlink needs an operator decision):
- U1 Umbrella: pin bump plus `helix-deps.yaml` ref in one change, `.workable-items-sync.yaml` (enabled, recursive, dry-run), correct `sub_projects` URLs, Docs Chain context, registry entries (`issues-sync`, `--prove-failure`), carrier lockstep.
- U2..Un Per own-org submodule (one PR each): job_seeker (reconcile `specs/*/tasks.md` into the DB or declare it a derived view; 299 task lines), workshop (private, own trackers only), ai_interviewing, monetization (private), design-toolkit, containers, LLMProvider, RAG, verdict, passage, curriculum-kit, HelixQA, challenges, DocProcessor, LLMOrchestrator, LLMsVerifier, security, VisionEngine, milosvasic.ru, vasic.digital. Each carries its config only.
- B1 Backfill dry-run (plan only, counts and visibility report, redaction hits) reviewed by the operator; B2 apply per repo in order: umbrella public, public modules, then private modules, then job_seeker.
- M1 Monitoring: scheduled `verify`, alert on rc 1/2, run records.
Sequence: C1 and C2 first; C3 (GitHub and GitLab adapters first, Gitea next, GitVerse and GitFlic last behind live proof); C4, C5; C6, C7; then U1, B1 dry run, operator review, U2..Un, B2, M1.

## 6. Backfill quota estimate (create calls; every later run is hash-gated)

Per tracker, creates = items; each issue also needs labels ensured (about 20 label calls per repo once) and one close call for closed items (371 + 12 + 0 closed rows to close after create; GitHub allows `state` in the create payload for some APIs but not reliably, so assume create then PATCH).

| Scope | Items | Create | Close | Total per tracker |
|---|---:|---:|---:|---:|
| Umbrella DB, public prefixes (VSC, MVR, CKT, PSG, CON(11), LMV, CNT, DOC, DTK, HLP, HQA, LLP, VDC = 475) | 475 | 475 | about 245 | about 720 |
| Private prefixes (WSP 178, AII 5, MON 1) | 184 | 184 | 124 | about 310 |
| job_seeker DB | 27 | 27 | 0 | 27 |
| Constitution DB | 564 | 564 | about 12 | about 576 |
| Total per tracker | 1250 | 1250 | about 381 | about 1630 + labels |

Across hosts: GitHub about 1630 calls (spread over at least 1 h at 1 s spacing to respect secondary limits), GitLab same count but only for repos that exist there, Gitea hosts and GitVerse same if the repos exist, GitFlic at 500 requests/hour means about 3.3 h for 1630 calls (and its API is unverified). The all-hosts upper bound is 1630 x 6 = 9780 calls, but the real multiplier today is about 1 to 2 hosts per repo (section 1.3).

## 7. Operator-provided inputs still needed

- Token variable NAMES (all already present in `~/api_keys.sh`): GITHUB_TOKEN, GITLAB_TOKEN, CODEBERG_GITEA_TOKEN, M3W_GITEA_TOKEN, GITFLIC_TOKEN, GITVERSE_TOKEN. Verify scopes (issue write on GitHub fine-grained token for each org; GitLab `api`; Gitea `write:issue`) before apply. Note: the token set works for read on Codeberg, m3w, GitFlic; write scope is UNVERIFIED.
- Create the missing repos on Codeberg, m3w, GitFlic, GitVerse (or declare them out of scope), and add the upstream recipes (`upstreams/*.sh`).
- Confirm Issues are enabled on each repo of each host (GitHub: all enabled today).
- Correct the stale `sub_projects` URLs (a repo change, not an operator input).

## 8. Operator decisions (2026-11-24) and open defaults

### 8.1 DECIDED (operator decisions in force, 2026-11-24)

- Upstream set (was Q1): per repo, derived from its EXISTING remotes and declared upstream recipes. Option (a). A host where the repo does not exist is not a target (not drift); creating mirrors is a separate later decision.
- GitFlic and GitVerse (was Q2): adapters are built BEHIND live proof. Their legs are UNCONFIRMED until a live create/read-back/close proves them; they are not excluded from the mandate and not claimed in sync before proof.
- Private repos (was Q3): private items are mirrored ONLY to the trackers of the owning private repo (workshop_curriculum, ai_interviewing, monetization, job_seeker).
- The 184 private-prefix rows in the public umbrella DB (was Q4): never mirrored to the umbrella tracker (option a). A repo whose visibility is unknown BLOCKS (rc 2), it never defaults to public.
- Backfill (was Q9): dry-run first, then tiered apply (umbrella public, public modules, private modules, job_seeker), each tier an operator-reviewed step.
- Docs Chain (was Q7): `docs_chain` is to be added as a submodule (umbrella and constitution), which unblocks C6. Adding it is a separate PR and a per-bump operator step for the gitlink.
- Switch: OFF by default in the constitution, ON per project (already section 4).

### 8.2 DEFAULTS pending operator veto (NOT decisions)

- Mirrored fields (Q5): title and description only; `forensic_anchor`, operator quotes, `body_md`, evidence and diaries never sent.
- Milestones (Q6): none.
- Closure semantics (Q8): Obsolete closes as not-planned; Operator-blocked stays open with a label.
- job_seeker `tasks.md` (Q10): fold into the DB.
- Duplicate gitlink (Q11): one canonical `llm_provider`/`LLMProvider` gitlink to be chosen; deduped by remote URL in the engine meanwhile.
- Anchor number and engine language (Q12): 11.4.300 (confirm against the constitution at authoring time); shell versus Go undecided.

## 9. Honest boundary

Nothing in this document is implemented. Counts are from DB reads on 2026-11-24. Host capability beyond GitHub and GitLab is from documentation fetched with a small-model summarizer (not source of record) and a few authenticated GETs; GitFlic issue support and Gitea `state`/`has_issues` field details are UNVERIFIED and must be proven by live read-back before any claim of sync. No issue, label or setting was created or changed on any host.
