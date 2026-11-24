# 02 - "jobops" candidate research (job_seeker)

Research date: 2026-11-24. Read-only; no commits, no submodule adds. Evidence is from `gh api` / `gh repo view` output taken this session.

## 1. What "jobops" refers to

`job_seeker/docs/materials/mvp/inputs.md` line 19 (local text, `cc7b074`) and line 13 of `origin/main:docs/materials/mvp/inputs.md` (after `git -C job_seeker fetch`) both say:

> "...use of the following solution (service) as Submodule: https://jobops.app/ (https://github.com/DaKheera47/job-ops), ..."

So the reference is unambiguous: **github.com/DaKheera47/job-ops** (site jobops.app). The upstream commit only shifts line numbers; the URL is identical in both versions.

Other GitHub hits for `jobops` (`gh search repos jobops`), none matching the URL, so they are not candidates:

| Repo | Stars | Note |
|---|---|---|
| reggiechan74/JobOps | 26 | resume odds pre-assessment |
| codeforamerica/JobOps | 17 | veterans job platform |
| gioamorim80/jobops | 6 | FastAPI + Next.js + Supabase + Claude |
| jobop/release, KrishnaTejaCheruku/jobops-tracker, NOTTIBOY137/jobops-ai | 5/3/1 | tiny |

## 2. Project facts (DaKheera47/job-ops)

| Item | Value (source) |
|---|---|
| Stars / forks | 4207 / 569 (`gh repo view`) |
| Created / last push | 2025-12-11 / 2026-10-30 |
| Latest release | v0.14.0, 2026-10-27 (`gh release list`); cadence about monthly (0.12.0 Aug, 0.13.0 Sep, 0.14.0 Oct) |
| Open issues | 74 (`gh api repos/..` open_issues_count, includes PRs) |
| Languages | TypeScript ~6.7 MB; Python ~20 KB; Typst, TeX, Dockerfile |
| Layout | `orchestrator/` (Express 4 + better-sqlite3 + drizzle-orm, v0.14.0), `extractors/*` (adzuna, gradcracker, hiringcafe, jobspy, golangjobs, seek, startupjobs, ukvisajobs, wazzuf, workingnomads, ...), `docs-site/`, `visa-sponsor-providers/`, `shared/`, `Dockerfile`, `docker-compose.yml` |
| Run model | `docker compose up -d`, UI/API on host port 3005 (container 3001); volumes `./data` (SQLite + PDFs), `codex-home`, `tectonic-cache` |
| Image | `ghcr.io/dakheera47/job-ops` |

### License: AGPLv3 + Commons Clause (not OSI-open)

`LICENSE` header: "Commons Clause License Condition v1.0 ... Software: JobOps; License: GNU Affero General Public License v3.0; Licensor: JobOps contributors". GitHub reports `NOASSERTION`.
- Commons Clause forbids "Sell"-ing the Software, including hosting or support services whose value derives substantially from it.
- AGPLv3 section 13 network-copyleft: if we modify it and users interact with it over a network, we must offer the modified source.

Compatibility with a private Go project:
- Separate process, talking over HTTP, unmodified, not linked or embedded: AGPL copyleft does not reach our Go code (aggregate / arm's-length). Running it internally is allowed.
- Never copy its TypeScript into our tree, never vendor code into our binary, and never fork-and-modify. A fork would trigger the AGPL section 13 source-offer duty.
- Never offer job_seeker as a paid hosted service where JobOps is the substantial value (Commons Clause). Risk exists if job_seeker is ever commercialised. UNCONFIRMED: no legal review has been done; counsel should confirm the "substantially derives value" boundary.
- Only a private or personal deployment is clearly safe.

## 3. Runtime fit (Go + Gin + HTTP/3 + Brotli)

- Stack mismatch: Node/TypeScript, Express, SQLite, Python (jobspy) and a Tectonic/Typst PDF toolchain. It cannot be imported as a Go module, so it must be a **sidecar container behind HTTP**.
- The README documents no HTTP/3 or Brotli. UNCONFIRMED; our Gin edge terminates h3/Brotli and talks plain HTTP/1.1 to the sidecar on a private network.
- The Containers submodule mandate (section 11.4.76, `submodules/containers`) applies: run it through the module's runtime/compose primitives, with no hand-rolled orchestration.
- The host has podman and no docker (per CLAUDE.md "Host capability"). Compose use must work under podman.
- Footprint: the image bundles Node, Python and LaTeX tooling, so it is heavy. UNKNOWN: image size and RAM; measure before committing (section 12.6, 60% RAM cap).

## 4. API surface (read from `orchestrator/src/server/api/routes`)

Routes observed in source (Express routers). No OpenAPI file found, so the contract is code-only, with no stability promise. Pin and contract-test it.

| Area | Endpoints (verbatim from router code) |
|---|---|
| Jobs read | `GET /api/jobs`, `GET /jobs/revision`, `GET /jobs/:id`, `GET /jobs/:id/emails`, `GET /jobs/:id/pdf` |
| Jobs actions | `POST /jobs/actions`, `POST /jobs/actions/stream`, `POST /jobs/:id/process`, `/skip`, `/rescore` |
| Jobs mutate | `PATCH /jobs/:id`, `DELETE /jobs/:id` |
| Stages | `GET /jobs/:id/events`, `/tasks`; `POST /jobs/:id/stages`; `PATCH .../outcome` |
| Application | `POST /jobs/:id/check-sponsor`, `POST /jobs/:id/apply` |
| Manual jobs | `POST /manual-jobs/fetch`, `/infer`, `/import` |
| Pipeline | `GET /pipeline/status`, `/progress`, `/progress/snapshot`, `/runs`; `GET/POST /pipeline/search-presets`; run trigger routes |
| Webhook | `POST /api/webhook/trigger` (Bearer `WEBHOOK_SECRET`, intended for n8n) |
| Other | profile, settings, onboarding, backup, watchlist, ghostwriter, design-resume, post-application-providers (Gmail), visa-sponsors, auth/SSO |

Route paths above that are prefixed by a mount point (assumed `/api/...`) are UNCONFIRMED; check `app.ts` before coding the adapter.

## 5. How it ingests / scrapes / applies

- Ingest: extractors scrape or call 10+ boards (LinkedIn, Indeed, Glassdoor via jobspy; Adzuna API; Hiring Cafe; Golang Jobs; Seek via Apify; UK Visa Jobs with login credentials; ...). Results are scored 0-100 by an LLM, a tailored CV is generated, a PDF is rendered (Tectonic/Typst, or Reactive Resume), and applications are tracked.
- Post-application tracking: Gmail OAuth, which classifies recruiter emails into Interviewing/Rejected, etc.
- Apply: the README states "It does not auto-apply... You still apply to every job yourself." `POST /jobs/:id/apply` appears to be a status transition (the demo simulator is `simulateApplyJob`). UNCONFIRMED whether it submits anything to a board; read `application.ts` fully before the adapter touches it.
- Telemetry: anonymous Umami analytics to `umami.dakheera47.com`; opt out by blocking the host at DNS or firewall. We MUST block it (privacy).

## 6. Data stored and credentials

Held by the sidecar (SQLite in `./data`): the full CV and profile (PII), job descriptions, scores, generated PDFs, email-derived status events, and in settings: LLM provider keys (OpenAI, Claude, Gemini, OpenRouter, LiteLLM, Codex login), `BASIC_AUTH_*`, `JWT_SECRET`, SSO client secrets, `GMAIL_OAUTH_*`, `RXRESUME_API_KEY`, `UKVISAJOBS_EMAIL/PASSWORD`, `APIFY_TOKEN`, `ADZUNA_*`, Stripe keys (hosted mode only).

Implications:
- This is the highest-risk personal data we handle (CV, employment history, mailbox access).
- Credentials are read via env; per CONST-042 they come from a 0600 gitignored `.env`, passed by name, never logged or committed.
- Gmail OAuth grants mailbox read: keep it off by default; enable only with an explicit operator decision.

## 7. What the adapter may call, and what it must not

CALL (read-mostly):
1. `ListJobs(filter)` -> `GET /jobs`
2. `GetJob(id)` -> `GET /jobs/:id`
3. `Revision()` -> `GET /jobs/revision` (cheap change polling)
4. `PipelineStatus()` / `Runs()` -> `GET /pipeline/status`, `/runs`
5. `TriggerSearch(preset)` -> pipeline run, only with an operator-approved preset
6. `ImportManualJob(url|text)` -> `POST /manual-jobs/import`
7. `Rescore(id)` -> `POST /jobs/:id/rescore`
8. `GetTailoredPDF(id)` -> `GET /jobs/:id/pdf`
9. `Stages(id)` / `Events(id)` -> read-only tracking state
10. `CheckSponsor(id)` -> `POST /jobs/:id/check-sponsor`

MUST NOT use:
- Any submission-to-employer path. `POST /jobs/:id/apply` is wrapped in the adapter as `MarkApplied`, and it needs an explicit human-gate token. Never call it from automation. UNCONFIRMED whether it is purely a status change.
- Gmail auto-tracking, unless separately approved.
- Scraping that breaches board ToS: LinkedIn, Indeed and Glassdoor (via jobspy) prohibit automated scraping, and UK Visa Jobs uses a logged-in account. Default these extractors OFF and allow only API-based or permissive sources (Adzuna API, Golang Jobs, manual import). The operator decides per source; this is a legal and ToS risk we record, not resolve.
- Hosted/cloud mode, Stripe, and the SSO/billing endpoints.
- Webhook trigger exposed beyond localhost.

## 8. Adapter interface (Go sketch)

```go
package jobops

import (
    "context"
    "io"
    "time"
)

type Job struct {
    ID, Title, Employer, URL, Source string
    Score     *int // 0-100, nil if unscored
    Status    string
    UpdatedAt time.Time
}

type HumanGate struct{ ApprovedBy, Reason string; At time.Time } // required for any outward action

type Client interface {
    ListJobs(ctx context.Context, f JobFilter) ([]Job, error)
    GetJob(ctx context.Context, id string) (Job, error)
    Revision(ctx context.Context) (string, error)
    PipelineStatus(ctx context.Context) (PipelineStatus, error)
    TriggerSearch(ctx context.Context, presetID string, g HumanGate) (runID string, err error)
    ImportManualJob(ctx context.Context, src ManualJobSource) (Job, error)
    Rescore(ctx context.Context, id string) error
    TailoredPDF(ctx context.Context, id string) (io.ReadCloser, error)
    Events(ctx context.Context, id string) ([]Event, error)
    CheckSponsor(ctx context.Context, id string) (SponsorResult, error)
    // Outward-facing: refuses with ErrHumanGateRequired when g is zero.
    MarkApplied(ctx context.Context, id string, g HumanGate) error
}
```

Adapter rules: a static `ErrNotSupported` for anything not listed; a version check against the pinned release (refuse to start on mismatch); response-schema validation (reject unknown shapes as rc-2 "cannot determine", never a silent pass); timeouts and context on every call; auth via env-name credentials; contract tests against a recorded fixture and a live sidecar (anti-bluff: PASS needs captured output).

## 9. Vendoring as a third-party submodule

Convention found in `helix-deps.yaml` (lines 91-94, 601-610): `submodules/superspec` is NOT listed under `deps` (the schema has no exclusion field); it is recorded in the trailing comment block with: upstream URL, pinned SHA and version, "no section 4 tag, no section 11.4.157 carrier, no section 11.4.156 CI action (out of scope per 11.4.156(C))".

Recipe (not executed here, per task rules):
1. Path: `submodules/jobops` (lowercase, section 11.4.29) with upstream `git@github.com:DaKheera47/job-ops.git`.
2. Pin to the v0.14.0 release commit SHA (resolve with `git ls-remote ... refs/tags/v0.14.0`). Never track a branch.
3. Add a trailing-comment entry to `helix-deps.yaml` mirroring the superspec one, with the licence line "AGPLv3 + Commons Clause - consumed unmodified as a separate process; never forked or linked".
4. Do not add a `deps[]` entry, so cascade checks C1 and C6 classify it as third-party. Verify with `bash scripts/verify-governance-cascade.sh` and `verify-manifest-pins.sh`.
5. Do not write the four carriers into it or modify it. The upstream ships its own `AGENTS.md`/`CLAUDE.md`, which will appear as known-excluded propagation-gate findings, exactly as superspec's do. Record them in "Known-excluded gate findings".
6. Its active `.github/workflows` are out of scope per 11.4.156(C), but note them for `verify-provider-ci.sh`.
7. Run it from a pinned container image digest (or build from the pinned submodule through `submodules/containers`), not `:latest`.
8. Bumps are an operator decision (not covered by the constitution standing authorisation). Add a contract-test gate that fails when the API drifts after a bump.

Visibility: the upstream is public and the submodule gitlink exposes only a SHA, so no private-content leak risk. Our own data (CV, DB) must live outside the repo (`.gitignore`d `data/`, section 9 backup before destructive ops).

## 10. Security / privacy risks

| Risk | Mitigation |
|---|---|
| CV/PII and tokens in SQLite on disk | Bind to localhost or a private podman network only; encrypted volume; backups under section 9; no data in git |
| Default port 3005 with weak/absent auth | Set `BASIC_AUTH_*` / JWT; never expose publicly; the adapter sends a Bearer or Basic credential from env |
| Telemetry to `umami.dakheera47.com` | Block at DNS and egress |
| LLM calls send CV text to third-party providers | Choose provider deliberately; prefer a local/OpenAI-compatible endpoint; operator decision |
| Board credentials (UKVISAJOBS) and Apify token | Env-only, per-service files, never logged |
| Gmail OAuth | Off by default |
| ToS violations by scrapers (LinkedIn/Indeed/Glassdoor) | Disable by default; allow-list sources |
| Upstream churn (monthly, 74 open issues, API untyped) | Pin, contract tests, adapter isolation |
| Bus factor: one maintainer ("Built by Shaheer Sarfaraz") | Keep the adapter small so replacement is cheap |
| Licence drift (relicense) | Re-read `LICENSE` at each bump |
| Supply chain (npm, Python, LaTeX bundle downloaded at first render, per the compose comment) | Pin image digest; offline cache the Tectonic bundle |

## 11. Recommendation: CONDITIONAL GO

GO for a **narrow, sidecar-only, read-mostly** integration. NO-GO for anything resembling a fork, embedding, or a commercial hosted offering.

Conditions: (a) the operator accepts AGPL+Commons Clause terms with the "private use, unmodified, never sold" posture, ideally after legal confirmation; (b) human gate on every outward action; (c) scrapers with ToS issues default off; (d) a spike measures image size, RAM and API stability before the adapter is built.

Alternatives (all UNVERIFIED beyond the search hits above):
- Build the thin slice natively in Go: a job-tracker table + score + tailoring calls through our own LLM seam (`submodules/LLMProvider`), plus only ToS-clean sources (Adzuna API, Golang Jobs). This removes the licence and runtime burden; it costs engineering time and contradicts the operator's "must use JobOps" directive, so it is the fallback if the licence or footprint check fails.
- reggiechan74/JobOps (26 stars) or gioamorim80/jobops (FastAPI + Supabase): smaller and less proven; licences not checked.
- Use JobOps manually as a standalone app, with no code integration: zero licence exposure, and the adapter reduces to export/import.

## Summary (12 lines)

1. "jobops" = github.com/DaKheera47/job-ops (jobops.app); the local and upstream inputs.md agree.
2. TypeScript/Express/SQLite/Python app; v0.14.0 (2026-10-27), 4207 stars, 569 forks, 74 open issues, monthly releases, single maintainer.
3. Licence is AGPLv3 + Commons Clause (GitHub shows NOASSERTION): fine privately, unmodified, as a separate process.
4. Never fork, link or embed it (AGPL s.13), and never sell or host it commercially (Commons Clause); legal review UNCONFIRMED.
5. Runtime does not fit Go/Gin/h3/Brotli, so it runs as a podman/compose sidecar behind plain HTTP, via submodules/containers.
6. API is code-only Express routes (no OpenAPI): pin the version and add contract tests.
7. The adapter calls list/get/revision/pipeline-status/import/rescore/PDF/events/sponsor-check.
8. It must not auto-apply (`/jobs/:id/apply` is gated behind a HumanGate; real semantics UNCONFIRMED), nor use Gmail tracking or ToS-breaching scrapers by default.
9. Holds CV, tokens and mailbox data; bind to localhost, set auth, block Umami telemetry, keep secrets in 0600 env.
10. Vendor as `submodules/jobops` pinned at the v0.14.0 SHA, listed in `helix-deps.yaml` trailing comments like superspec (no deps entry, no carriers, no tag/CI).
11. Recommendation: CONDITIONAL GO, sidecar and read-mostly, pending a footprint/API spike and operator acceptance of the licence.
12. Fallback alternatives: native Go slice on LLMProvider, a smaller JobOps-named project, or standalone manual use.
