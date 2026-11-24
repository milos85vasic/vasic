# job_seeker — matching, area mapping, application flow, data model, tests

Status: design research (read-only on repo, no commits). Date: 2026-11-24.
Inputs read: `_tools/career/{model,catalog,resolve,vault,overlay}.py`, `_content/career/areas/*.yaml` (10), `_content/career/profile.yaml`, `_content/career/locales/*.yaml` (14 non-EN locales), `job_seeker/docs/materials/mvp/inputs.md`, Constitution §11.4.169, §11.4.289.
Operator decisions binding: 1:1 position -> one of the 10 existing areas (no new areas in v1); human-in-the-loop, dry-run default; no personal data in git (private overlay in `career_private`, via `CAREER_PRIVATE_DIR`); hosted TypeSafe Jev only (override §11.4.279-286), no local models.

## 0. Facts taken from the repo (not invented)

- Areas (id): `ai-engineering, android-aosp, android-tv, android, desktop, flutter, go, mobile, react-native, web-frontend`. Each has `keywords[]` (tech tokens), `competencies`, `emphasis`, `projects`, `experience`, `cover_letter.angle`.
- Profile: `identity.years_experience: 16`, `since: 2009`; `skills[]` groups (languages, backend, data, frontend, infra, ai); `languages_spoken`: sr (native), en (C1/C2), ru (professional working), de (basic); `ats.base` tokens.
- Output matrix: area x language x {cv, cover} is the "300 PDFs" (10 areas x 15 languages x 2 kinds = 300; EN + the 14 locale files). Sealed in the vault; slot = (area, lang, kind). Salary/phone/address belong to the private overlay (overlay.py allows only declared keys; `salary_expectation` is NOT in the public profile and must be added to the private overlay allow-list, never to profile.yaml). As of JSK-T011 the overlay allow-list also carries the job_seeker scoring keys `salary_min`, `salary_currency`, `salary_period`, `tz_window`, `allowed_onsite_cities`, `blocked_companies`, `eligible_countries` (shape-validated, never merged into PDF/vault identity; contract: `job_seeker/specs/001-job-seeker-mvp/contracts/overlay-and-config.md`).
- Gap found: two areas overlap by design (`mobile` is the umbrella of `android`, `flutter`, `react-native`; `android` is the parent of `android-tv`, `android-aosp`). 1:1 mapping therefore needs a specificity rule (section 1.3).

## 1. Position -> area classifier

### 1.1 Pipeline (deterministic first, LLM optional)

1. Normalise: NFKC, lowercase, strip HTML, transliterate nothing (RU/SR matched natively; SR Latin and Cyrillic both listed). Split into `title`, `tags`, `body` (first 4000 chars).
2. Rule score per area = sum of weighted hits: title pattern 6, explicit tag 4, strong tech keyword in title 5, tech keyword in body 1 (cap 5 per area), negative pattern -6. Hits are recorded (rule id, field, matched span, weight).
3. Specificity precedence (applied before ranking, only among areas that reached the floor): `android-tv` > `android-aosp` > `android` > `mobile`; `react-native`/`flutter` > `mobile`; `ai-engineering` beats `go` only when title or tags contain an AI token (a "Go engineer building LLM gateways" with AI absent from the title stays `go`). A parent area wins only when no child reached the floor.
4. Decision from top score `S1`, runner-up `S2`, margin `M=S1-S2`:
   - `S1 >= 10` and `M >= 4`: mapped, confidence `high` (conf = min(1, S1/16) * margin_factor).
   - `6 <= S1 < 10` or `M < 4` with `S1 >= 6`: `ambiguous` -> LLM tiebreak if enabled, else human picks in review queue (default).
   - `S1 < 6`: `unmapped`. Stored with `area_id = NULL`, reason `no_rule_floor`. Never forced to the nearest area, never a new area. Unmapped positions are scored 0 for application purposes and are excluded from shortlist; they are visible in the review queue with the top-3 candidates and hits so the operator can map manually (manual mapping is audited and recorded as `mapped_by=human`).
5. Hard exclusions before mapping (reject with reason): onsite-only outside constraints (section 2), non-engineering roles (`sales`, `recruiter`, `designer`), seniority junior/intern.

### 1.2 Rule tables (data files in `job_seeker/rules/area_rules.yaml`, public, no personal data; tech tokens seeded from `areas/*.yaml` keywords via a build step so drift is caught by a test)

Title patterns are case-insensitive regex; EN / RU / SR (Latin; Cyrillic variants noted by `ћир` in the file).

| area | title patterns (weight 6) | tags / strong tech (4-5) | body tech (1) | negatives (-6) |
|---|---|---|---|---|
| go | `\bgo(lang)?\b.*(engineer|developer|backend)`, `golang`, `backend.*go`; RU `разработчик go`, `бэкенд.*go`; SR `go programer`, `backend programer` | go, golang, gin, grpc, protobuf, quic, clickhouse, postgres | kubernetes, prometheus, opentelemetry, redis, docker, concurrency | `\bandroid\b`, `\bios\b` in title |
| ai-engineering | `ai engineer`, `ml engineer`, `llm`, `machine learning engineer`, `applied ai`, `prompt engineer`; RU `инженер ии`, `ml-инженер`, `нейросет`; SR `ai inženjer`, `veštačka inteligencija` | llm, rag, mcp, embeddings, vector database, langchain, agents, llmops | python, evaluation, guardrails, fine-tuning | `data analyst`, `research scientist` (pure research) |
| android-aosp | `aosp`, `android (platform|framework|system|bsp|hal)`, `android os engineer`, `embedded android`; RU `разработчик aosp`, `платформа android` | aosp, hal, binder, aidl, selinux, device tree, fastboot, bsp, system server | c++, java, kernel, yocto | `app developer` |
| android-tv | `android tv`, `google tv`, `set-?top`, `leanback`, `stb`, `tv (app|platform) (developer|engineer)`; RU `android tv`, `приставк`; SR `android tv` | leanback, exoplayer, media3, d-pad, hls, dash, atsc, drm, widevine | compose for tv, adb | none |
| android | `android (developer|engineer|sdk|app)`, `kotlin (developer|engineer)`; RU `android-разработчик`, `разработчик android`; SR `android programer` | android, kotlin, jetpack compose, gradle, coroutines, room, retrofit | java, espresso, material | `\bios\b` only title with no android |
| mobile | `mobile (engineer|developer|sdk)`, `ios.*android`, `cross-?platform mobile`, `kotlin multiplatform`; RU `мобильный разработчик`; SR `mobilni programer` | kmp, ios+android pair, app store, google play, fastlane, swift+kotlin | ci/cd, accessibility | pure `ios`-only (title `ios developer` without android/kmp) -> unmapped, not forced |
| flutter | `flutter`, `dart (developer|engineer)`; RU `flutter-разработчик`; SR `flutter programer` | flutter, dart, riverpod, bloc, pub.dev, platform channel, ffi | widget testing | none |
| react-native | `react[ -]native`, `rn (developer|engineer)`; RU `react native разработчик` | react native, turbomodules, fabric, metro, detox, expo | typescript, jest | `reactjs only` web roles |
| desktop | `desktop (engineer|developer|app)`, `electron`, `tauri`, `qt (developer|engineer)`; RU `десктоп`; SR `desktop programer` | electron, tauri, qt, ipc, auto-update, code signing, packaging | rust, c++, offline-first | none |
| web-frontend | `front-?end`, `web (developer|engineer)`, `react (developer|engineer)`, `angular`, `ui engineer`; RU `фронтенд`, `веб-разработчик`; SR `frontend programer`, `veb programer` | react, angular, typescript, tailwind, redux, wcag, core web vitals, vite, ssr | playwright, design systems, i18next | `react native` in title (belongs to react-native) |

Keyword `unmapped` examples that must stay unmapped: "Data Engineer", "DevOps Engineer", "QA Automation only", "Rust systems", "Java Spring backend" (no Go). Test corpus enforces this (section 5, unit + e2e).

### 1.3 Optional LLM tiebreak (flag `JS_LLM_TIEBREAK=1`, default OFF)

- Only invoked for `ambiguous` (S1 in [6,10) or margin < 4). Never for `unmapped`, never to create areas, never overriding a `high` rule result.
- Hosted TypeSafe Jev only, via the toolkit's jev loaders; credential by env-var NAME `TYPESAFE_API_KEY`, never printed/logged; mode `shadow`, `JEV_GATE` not `off`. No local model, no llmctl decide-*. Prompt carries title + tags + first 1500 chars of body, no personal data; closed answer set = candidate area ids (top-3) + `none`.
- Accept rule: LLM answer must be one of the top-3 rule candidates AND returned confidence >= 0.75; then result `mapped`, `method=rules+llm`, and the provider request id/model id are stored. Otherwise `unmapped` or human queue. Disagreement with rules' top-1 is allowed only inside the top-3; the LLM cannot elevate an area the rules scored 0.
- Evidence captured per call: request id, model id as reported, usage fields, latency (§11.4.289(D)).

### 1.4 Mapping output (explainability)

`{area_id|null, status: mapped|ambiguous|unmapped, confidence, method, S1, S2, margin, hits:[{rule_id, field, span, weight}], excluded:[...], ruleset_sha}`.

## 2. Scoring model

Defined only for `mapped` positions. Score 0-100, deterministic, versioned (`score_version`).

```
score = round( 100 * ( w_skill*skills + w_area*area_fit + w_sen*seniority
                       + w_loc*location + w_rec*recency + w_sal*salary ) )
        then HARD GATES may set score = 0 with gate reason
weights (sum = 1.0):  skills 0.35, area_fit 0.20, seniority 0.15,
                      location 0.15, salary 0.10, recency 0.05
```

Component definitions (each in [0,1]):

- skills: `|req ∩ have| / |req|`, where `req` = tech tokens extracted from posting (title+tags+body, dictionary = union of all `profile.skills[].items` + all area `keywords` + `ats.base`, with alias table e.g. `golang`->Go, `k8s`->Kubernetes) and `have` = same dictionary from profile.yaml. Required terms (marked "must/required/обязательно") weight 2, nice-to-have 1. `req` empty -> 0.5 (unknown, flagged `no_skills_signal`).
- area_fit: mapping confidence from section 1 (high -> its conf, ambiguous-accepted -> conf * 0.8).
- seniority: parse years ("5+ years") and level words (junior/mid/senior/lead/staff/principal). `have_years = 16` (from `identity.years_experience`). Years req <= 16 -> 1.0; level senior/lead/staff/principal -> 1.0; mid -> 0.7; junior/intern -> 0 and hard gate. Req years > 16 -> 0.8 (cap, never 0).
- location: remote worldwide 1.0; remote with allowed countries including the candidate's eligibility set 1.0; remote restricted to excluded regions 0 + hard gate; hybrid/onsite 0 unless city in private overlay `allowed_onsite_cities`. Timezone: overlap hours with candidate window (overlay `tz_window`) / required overlap hours, clipped to [0,1]. Candidate country/tz are overlay values, never committed.
- salary: if posting range present and overlay `salary_min` set: 1.0 when max >= min, linearly down to 0 at 0.6*min; hard gate when max < 0.6*min. Unknown salary -> 0.5, flagged. Currency converted with a dated rate record stored in the audit row (rate source captured live).
- recency: `exp(-age_days/14)` (half-life about 10 days), age from provider `posted_at`; > 45 days -> 0 and soft gate `stale`.

Hard gates (score forced 0, reason recorded): `junior_only`, `excluded_region`, `onsite_unreachable`, `salary_below_floor`, `duplicate_of:<id>`, `blocked_company` (overlay list), `unmapped`.

Thresholds: shortlist >= 70; review band 55-69 (human may promote); < 55 discarded (kept, not deleted).

Explainability payload (`score_explain` JSON stored with the match): `{score_version, weights, components:{skills:{value, req:[...], have:[...], missing:[...], must_missing:[...]}, area_fit:{...}, seniority:{parsed_years, level, value}, location:{mode, countries, tz_overlap_h, value}, salary:{posted:{min,max,cur}|null, value, floor_used:"overlay:present|absent"}, recency:{age_days,value}}, gates:[...], total, shortlist_decision}`. Salary floor VALUE is never written to the payload (only whether overlay was present); private numbers stay in the private DB/overlay.

## 3. Application flow state machine

States: `discovered -> mapped -> scored -> shortlisted -> draft_prepared -> awaiting_human_approval -> {sent | dry_run_recorded | rejected_by_human} -> tracked`; side states `unmapped`, `discarded`, `expired`, `failed_retryable`, `failed_terminal`, `withdrawn`.

| from | event | to | guard |
|---|---|---|---|
| discovered | map ok | mapped | status mapped |
| discovered | map unmapped | unmapped | terminal until human maps |
| mapped | score >= 70, no gate | shortlisted (via scored) | |
| mapped | score < 55 or gate | discarded | reason stored |
| shortlisted | prepare | draft_prepared | CV/cover slot resolvable |
| draft_prepared | submit-request | awaiting_human_approval | draft hash frozen |
| awaiting_human_approval | approve (human token) | sent | `--live` AND approval id AND hash match AND not dry-run |
| awaiting_human_approval | approve in dry-run | dry_run_recorded | default; makes NO external call that mutates the provider |
| awaiting_human_approval | reject / timeout 14d | rejected_by_human / expired | |
| sent / dry_run_recorded | tracking update | tracked | |

Rules:
- Dry-run is the default at every layer (CLI flag, config, per-application). `sent` is reachable only with all of: explicit `--live`, a per-application human approval record (approver id, UTC time, draft hash), draft hash equal to approved hash (editing a draft invalidates approval), kill-switch off, daily cap not exceeded. `submitted(dry-run)` is never the same row value as `sent`; dry runs produce `dry_run_recorded` with `would_send` payload and no provider mutation. No auto-apply to any provider without a human step; for providers with no apply API (remotive/remoteok/himalayas expose listings) the "send" is a `handoff` (opens apply URL / prepares email) that the human completes, and the human then marks `sent` with a confirmation reference.
- Draft selection: area_id from mapping; language rule from posting language detection (langid on title+body, deterministic library, confidence >= 0.8): posting language in the 15 available languages -> that language; else EN. Cover/CV language may be overridden by explicit posting requirement ("apply in German" -> `de`, flagged since German is basic level: requires human confirmation; also RU only if posting RU-language). Slot = (area, lang, cv|cover) from the vault manifest; the actual PDF is decrypted only locally with the operator passphrase from env at send time, never stored in the DB, never committed. Missing slot -> state stays `shortlisted`, reason `slot_missing`.
- Idempotency key: `sha256(provider || provider_job_id || candidate_id || kind)` for application attempts; `sha256(provider || canonical_url)` for postings; cross-provider duplicate detection by `sha256(norm(company)||norm(title)||location)` plus fuzzy 0.92 similarity -> `duplicate_of`. Re-running a discovery/mapping/scoring/draft step with same inputs and same `ruleset_sha`/`score_version` yields identical rows (upsert on key); sending uses a UNIQUE constraint so a second send for the same key is refused and logged.
- Audit log: append-only, every transition writes `(id, application_id, from, to, actor(system|human:<id>|llm), reason, evidence_json, prev_hash, this_hash, ts)`; hash chain (`this_hash = sha256(prev_hash || row_canonical)`) so tampering is detectable (§11.4.268 style). Verifier command recomputes the chain.

## 4. SQLite data model (public schema; the private DB file lives in `career_private`, never in git)

All timestamps UTC ISO-8601. FK enforcement ON, WAL mode.

```
provider(id PK, name UNIQUE, base_url, kind, rate_limit_rpm, enabled)
posting(id PK, provider_id FK, provider_job_id, idem_key UNIQUE, canonical_url, title, company, location_raw,
        remote_mode, countries_json, tz_hint, salary_min, salary_max, salary_cur, tags_json, body_text,
        lang, lang_conf, posted_at, fetched_at, raw_sha256, raw_blob_path, dup_of FK NULL,
        UNIQUE(provider_id, provider_job_id))
mapping(id PK, posting_id FK UNIQUE, area_id TEXT NULL, status CHECK(status IN('mapped','ambiguous','unmapped')),
        confidence REAL, method CHECK(method IN('rules','rules+llm','human')), s1, s2, hits_json,
        ruleset_sha, llm_request_id, llm_model, mapped_by, mapped_at)
score(id PK, posting_id FK, score_version, total REAL, components_json, gates_json, explain_json,
      ruleset_sha, scored_at, UNIQUE(posting_id, score_version))
application(id PK, posting_id FK UNIQUE, idem_key UNIQUE, state CHECK(state IN(...states above...)),
            area_id, cv_slot, cover_slot, lang, lang_rule, draft_hash, dry_run INTEGER NOT NULL DEFAULT 1,
            approved_by, approved_at, approved_hash, sent_at, provider_ref, created_at, updated_at)
draft(id PK, application_id FK, kind CHECK(kind IN('cv','cover','message')), slot TEXT, lang,
      content_sha256, path_private, created_at)           -- path_private points into career_private
approval(id PK, application_id FK, approver, decision CHECK(decision IN('approve','reject')), draft_hash, ts, note)
audit_log(id PK, application_id FK NULL, posting_id FK NULL, from_state, to_state, actor, reason,
          evidence_json, prev_hash, this_hash, ts)          -- append-only trigger blocks UPDATE/DELETE
tracking(id PK, application_id FK, status CHECK(status IN('sent','viewed','replied','interview','offer','rejected','ghosted')),
         source, note_private_ref, ts)
run(id PK, kind, started_at, ended_at, provider_id, requests, ok, errors, git_rev, config_sha)  -- live-run evidence
provider_call(id PK, run_id FK, url_host, method, status, req_id, latency_ms, resp_sha256, ts)  -- real-call proof, no bodies
```
Private-only table (exists only in the private DB): `candidate_private(key, value)` for salary floor, tz window, allowed cities, blocked companies. Public DB stores only `overlay_present` booleans. A repo gate (grep + schema test) fails if any column named `salary_floor|phone|address|email_personal` appears in a tracked file or the public DB.

## 5. The 13 mandatory test types (§11.4.169, closed set) mapped to job_seeker

Common rule (§11.4.289): outside unit tests there are no stubs/mocks/fixture servers as evidence. A live-labelled result carries machine fields: provider host+resolved IP, TLS identity, HTTP status, provider request id/headers, response sha256, artifact fingerprint (git rev + ruleset_sha + score_version), run id, N>=3 identical deterministic results. Missing dependency (provider down, no `TYPESAFE_API_KEY`, no vault passphrase) = honest SKIP with closed reason code (`credentials_absent`, `topology_unsupported`, ...), never a stand-in. Sending is always dry-run in tests; "live" for send paths means the real provider apply endpoint is NOT called without human approval, and the live proof is the real fetch/discovery plus the real handoff-record; the only real `sent` test is a human-attended acceptance run (recorded as `operator_attended`, one tracked item).

| # | Type | Concrete test ideas for job_seeker | Anti-bluff evidence required |
|---|---|---|---|
| 1 | Unit | Rule tables: each of 10 areas x EN/RU/SR title corpus (>=15 titles/area, incl. Cyrillic/Latin SR) -> expected area; precedence (android-tv over android over mobile); unmapped corpus (Data Engineer, DevOps, ios-only); score component math, gates, weights sum to 1.0; idempotency key derivation; state-machine transition table (illegal transitions raise); hash-chain function; tz/salary parsing; drift test: rule tech tokens superset of `areas/*.yaml` keywords. Doubles allowed here only. | Test report with counts; mutation pairs (§1.1): break a rule/weight/guard -> named test fails; coverage report |
| 2 | Integration | Real SQLite file + real migrations; discovery against the real providers (remotive, remoteok, himalayas, jobspipe) into DB; mapping+scoring on those fetched postings; vault manifest slot resolution against the real built manifest and a real decrypt of one slot with passphrase from env; overlay merge from a real `CAREER_PRIVATE_DIR`. Infra (if any service e.g. job-ops submodule) booted via containers submodule rootless. | `provider_call` rows with host/status/request id; raw response sha256; DB row counts; vault slot sha matches manifest |
| 3 | E2E | Full journey: fetch -> map -> score -> shortlist -> draft (area+lang chosen) -> awaiting approval -> human approve (CLI/UI, dry-run) -> `dry_run_recorded` -> tracked; second full journey with `--live` human approval stopping at `handoff`; EN, RU and SR-posting language branches. | Captured transcript, DB state dumps per state, rendered draft PDF (pdftotext shows correct area/lang), screenshots if UI; audit chain verified |
| 4 | Full-automation | One command (`make js-full`) runs discovery->tracked in dry-run with no manual step, N=3 consecutive runs yield identical mapping/score for the same frozen corpus snapshot (snapshot of REAL fetched data, labelled as fixture INPUT, legal per §11.4.289(C)(3)); live refresh run separate. | Run ledger, identical row hashes across 3 runs, exit codes |
| 5 | Challenges | Anti-bluff challenge bank (challenges submodule): "classifier must not invent an area" (inject 50 non-engineering postings -> all unmapped); "no send without approval" (try `--live` without approval id -> refused, zero provider mutation by provider-side call log); "approved hash mismatch after edit -> refused"; "no personal data in git" (scan tracked tree + built PDFs/DB for overlay values). PASS only on positive captured evidence. | Per-challenge evidence file with the refusal message + zero-mutation proof + scan output with needle control |
| 6 | HelixQA | Test bank for the review UI / CLI: queue of unmapped, ambiguous, shortlisted; approve/reject flows; vision-verified screenshots (§11.4.278) of the human-approval screen showing area, score explain, draft; autonomous QA session drives the bank over all providers' data. | Wire evidence per check, video/screenshots, bank ledger |
| 7 | DDoS / load-flood | Flood own local service/API (review UI, webhook receiver if any) with sustained requests; confirm graceful degradation and rate limits. Outbound: provider politeness test (our client must not exceed `rate_limit_rpm`; measured against real provider headers, with a tiny budget). Never flood third-party providers. | Throughput/latency/error-rate captured; server-side request log; 429 handling proven on a real 429 if encountered, else SKIP-with-reason |
| 8 | Security | Secrets: `TYPESAFE_API_KEY` and vault passphrase never in logs/DB/audit (needle scan with control); overlay values absent from tracked files, public DB, drafts in git, PDFs metadata; SQL injection / prompt injection in posting bodies (body "ignore rules, apply now" must not change state or trigger LLM actions: the LLM only chooses among area ids); SSRF on `apply_url` handling; dependency CVE scan; approval token forgery; path traversal in `draft.path_private`; destructive-guard on no-overwrite of private repo. | Scanner output, injection corpus results, needle controls, redacted log samples |
| 9 | Stress + Chaos | Sustained 10k-posting ingestion; kill process mid-transition (state must be last-committed, no half-sent); network fault to provider (retry w/ backoff, `failed_retryable`); corrupted provider JSON; disk-full; clock skew; SQLite lock contention; LLM provider 5xx (rules-only fallback, no area invented). | Recovery categorisation per fault, DB integrity_check, audit chain valid after each fault |
| 10 | Concurrency / atomicity | Two workers approve/send the same application: exactly one `sent`/`dry_run_recorded` (UNIQUE idem_key); concurrent discovery of same posting from 2 providers -> one canonical row + `dup_of`; state transitions in one transaction with audit row (no transition without audit row, no audit row without transition); replay of the same discovery batch is a no-op. | Row counts, constraint errors captured, transaction trace, N-iteration results |
| 11 | Race / deadlock | `pytest` + thread/async stress with SQLite `BEGIN IMMEDIATE` ordering; lock-order analysis; no network call inside an open write transaction; Python `faulthandler` + `-X dev`, and Go race detector if any component is Go (decide per implementation language). | Detector output (clean), lock-order report, timeout-bounded runs |
| 12 | Memory | Leak census over 24h/N-iteration soak of fetch/map/score loop (tracemalloc/RSS sampling); peak-RSS ceiling for large body parsing and PDF handling; vault decrypt buffer freed/zeroed best-effort. Respect §12.6 (60% RAM cap, bounded scope). | RSS/tracemalloc time series, ceilings, flat-slope assertion |
| 13 | Benchmarking | p50/p95/p99 for classify (target < 5 ms/posting rules-only), score (< 5 ms), ingest throughput, LLM tiebreak latency (real hosted calls, small N, budget-bounded per §11.4.289(G)); classifier accuracy benchmark: precision/recall per area on a hand-labelled REAL-posting gold set (>= 30/area incl. RU/SR), regression vs recorded baseline is a finding. | Baseline file in repo, run output, labelled-set provenance (provider, id, fetch date), delta report |

Per-type meta-gate: pre-build gate checks every type present-or-honestly-SKIPPED per feature, with a paired §1.1 mutation (strip type's evidence capture -> gate fails). Coverage ledger classifies feature x type x evidence-state; `OPERATOR_ATTENDED_ONLY` blocks release.

## 6. Open points (UNCONFIRMED / for operator)

- UNCONFIRMED: exact count of vault slots (300 = 10x15x2 inferred from 14 locale files + EN; verify against the vault manifest before relying on it).
- UNCONFIRMED: whether any listed provider (Sprout AI, SmartApplier, jobspipe) offers an apply API; none was probed in this research. Default: listings-only providers => handoff, not send.
- Decision needed: add `salary_*`, `tz_window`, `allowed_onsite_cities`, `blocked_companies` keys to the private overlay allow-list in `overlay.py` (change belongs to the career tooling, not done here).
- Decision needed: German postings (candidate level basic): auto-select EN or require human confirmation (design above: human confirmation).
- Weights/thresholds are initial proposals, to be calibrated on the gold set (§11.4.285-style, hosted layer only); not measured here.
