# job_seeker kickoff readiness (prepared 2026-11-23, NOT started)

| | |
|---|---|
| Status | PREPARED. Nothing merged, pulled, committed, or created. Only `git -C job_seeker fetch` was run (approved). |
| Prefix | JSK (operator-decided) |
| Measurements | All below taken 2026-11-23 in this session; anything not measured is labelled UNCONFIRMED. |

## 1. Live-session check (read-only)

- Processes: `ps` shows two Claude sessions, `vasic` (this one) and `helix-reader` (cwd `Projects/helix_reader`, a different repo). Checking `/proc/<pid>/cwd` of all claude/codex processes for `job_seeker` returned nothing. No gemini/qwen/opencode agent matched.
- Git: `git -C job_seeker status --short` is empty. Reflog has only 2 entries: clone (2026-11-19 21:31) and one Auto-commit (2026-11-19 21:43). No `index.lock` or other lock files.
- File recency: no non-`.git` file in `job_seeker/` modified in the last 120 min. The tree was last touched 2026-11-19.
- Verdict: NO live session found working in `job_seeker`. UNCONFIRMED: sessions on other hosts or agents that do not appear in local `ps` cannot be seen from here. The remote did receive one commit (see 2), so some actor pushed to `origin/main` after the clone; its origin is UNKNOWN.
- Re-run immediately before the kickoff ff.

## 2. Fetch + classification (`git -C job_seeker fetch` rc 0)

| Item | Result |
|---|---|
| Branch | `main`, tracking `origin/main` |
| Local HEAD | `8066233` (Auto-commit 1795120997505) |
| Upstream | `cc7b074` "Update inputs.md" |
| `rev-list --left-right --count HEAD...@{u}` | `0  1` (0 divergent, 1 behind) |
| `merge-base --is-ancestor HEAD @{u}` | TRUE |
| `diff --stat HEAD..@{u}` | 1 file: `docs/materials/mvp/inputs.md`, 1 insertion, 7 deletions |
| Uncommitted changes | none |
| ff-only possible NOW | YES (0 divergent, ancestor TRUE, clean tree). Not performed. |

At kickoff: repeat the live-session check, re-run the classification (the remote may have moved again), then `git -C job_seeker merge --ff-only @{u}` only if still 0 divergent. Any divergence: STOP and report.

Note: the incoming commit changed `inputs.md` after this agent's earlier read. Re-read `docs/materials/mvp/inputs.md` after the ff; the summary in section 3 is of the PRE-ff text (local HEAD) and may be outdated.

## 3. Current state of job_seeker

- Contents: `README.md` (19 bytes, "# Job Seeker / Tbd."), `docs/materials/mvp/inputs.md`, `upstreams/GitHub.sh` (origin `git@github.com:milos85vasic/job_seeker.git`). Nothing else.
- Carriers: `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` all MISSING. `.specify/` MISSING. `helix-deps.yaml` MISSING. `.gitignore` MISSING locally (the umbrella's `.gitignore` already carries a `.cache-career/` rule, a separate matter). No `specs/`, no `CONTINUATION.md`, no `submodules/constitution` inside it.
- Remotes: `origin`, `github`, `upstream`, all the same GitHub URL, no GitLab mirror.
- Visibility: `gh api repos/milos85vasic/job_seeker --jq .visibility` returns `private`. Satisfies "private repo".
- Access rule for `rnalbusi` (operator decision): new private repos must grant that GitHub user read access. Handle UNVERIFIED and the token lacked scope earlier. Status for job_seeker: UNCONFIRMED (not probed, because granting is a mutation). Flag to operator: confirm the handle, then add as read collaborator.
- inputs.md summary (pre-ff text): ATS-optimised CV drawn from the `milosvasic.ru` submodule; per-position CV variants (AI, Android, Android TV, AOSP, Flutter, React Native, Mobile, Go engineer); LaTeX section toggles exporting to PDF/HTML/Markdown/Docx; job sources remotive, remoteok, himalayas, jobspipe, plus Sprout AI and SmartApplier; jobops (`DaKheera47/job-ops`) to be included as a submodule.
- Scope decision vs inputs: operator chose 3 keyless APIs for v1 (remotive, remoteok, himalayas); jobspipe, Sprout AI and SmartApplier are deferred (UNCONFIRMED whether any needs a key).

## 4. Umbrella model (measured)

- `.gitmodules` ALREADY declares `job_seeker` (path `job_seeker`, url `git@github.com:milos85vasic/job_seeker.git`, line 67). `helix-deps.yaml` has NO `job_seeker` entry. `sub-projects.tsv` has NO JSK row. So cascade C6 (manifest vs `.gitmodules`) is expected RED today (UNCONFIRMED: not run, to avoid side effects), and C2/C3 will flag missing carriers.
- Layout correction: `curriculum-kit` is `layout: grouped` (path `submodules/curriculum-kit`), NOT flat. A root-level repo like `job_seeker` follows the flat model used by `ai_interviewing`, `monetization`, `milosvasic.ru` (`layout: flat`, path `<root>/<name>/`). Use `flat` for job_seeker. Use curriculum-kit only as an example of a manifest entry's shape (`name`, `ssh_url`, `ref`, `why`, `layout`).
- Roster file format: TAB-separated `prefix path class ratified note`; classes `parent|owned|governance-source|third-party`. `ratified=operator` only for operator-stated ids.
- Reference carrier shape: `ai_interviewing/{CLAUDE,AGENTS,QWEN,GEMINI}.md` are 71 lines each, with the "INHERITED FROM constitution/CLAUDE.md" conditional-inheritance header. Copy that shape and header form.

## 5. Kickoff checklist (exact, in order)

1. Live-session re-check, `git fetch`, classify, ff-only only if 0 divergent (section 2).
2. Re-read `docs/materials/mvp/inputs.md`.
3. Carriers: add `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` to `job_seeker/` in pointer form (`## INHERITED FROM constitution/CLAUDE.md`), byte-identical to each other apart from the per-agent header block. Derive from `ai_interviewing`'s four carriers (71 lines, lockstep per C8 / §11.4.157). Edit the shared tail once and recompose rather than hand-editing four files.
4. `job_seeker/helix-deps.yaml` (own manifest, as `ai_interviewing` has one) referencing the constitution; UNCONFIRMED exact schema, copy from `ai_interviewing/helix-deps.yaml`.
5. Umbrella `helix-deps.yaml`: add `deps[]` entry `name: job_seeker`, `ssh_url: git@github.com:milos85vasic/job_seeker.git`, `ref: <git ls-files -s job_seeker sha>`, `why:`, `layout: flat`. Stage the gitlink bump and this entry in the SAME change (C9).
6. `docs/workable-items/sub-projects.tsv`: add row `JSK	job_seeker	owned	operator	<note: private repo; no personal data in git; career_private overlay>`.
7. Third-party jobops: add as submodule inside `job_seeker` (UNCONFIRMED path, propose `submodules/job-ops`), behind an adapter package; classify as `third-party` in cascade terms (like `superspec`); never edit it. Needs its own `.gitmodules` entry in job_seeker. UNCONFIRMED: jobops licence and stack (not read).
8. `.gitignore` in job_seeker: `career_private/`, `.cache-career/`, `.env*`, build outputs. Personal data (CV values, contact data) lives only in the `career_private` overlay, never in git.
9. Cascade expectations after steps 3-6: run `bash scripts/verify-governance-cascade.sh`. Expected C1 classifies it as owned; C2 (4 carriers present) and C3 (pointer-carrier predicate) GREEN; C6 GREEN (`.gitmodules` and manifest agree both ways); C8 GREEN (lockstep); C9 GREEN (ref equals gitlink). Also `bash scripts/verify-manifest-pins.sh`. All of this is EXPECTED, UNCONFIRMED until run. Counts will change (owned carriers 20x4=80 as measured 2026-10-14 become 21x4=84, UNCONFIRMED).
10. Registry hygiene: no new `scripts/*.sh` at the umbrella without a `scripts/check-registry.tsv` row (R5).
11. Commit through the project's wrapper, not raw git; no force-push (§11.4.113); push all upstreams; work lands on `main` (§11.4.288). Independent review before accepting (§11.4.142).
12. Speckit inside job_seeker (initialise `.specify/` first; `ai_interviewing` has none, so use the umbrella `.specify/` as template, UNCONFIRMED): `speckit-specify` -> `speckit-clarify` -> `speckit-plan` -> `speckit-tasks` -> `speckit-analyze` -> `speckit-superspec-execute` (implementation must go through superspec-execute per standing memory).

## 6. Product decisions to carry into the spec

- Stack: Go API (Gin + HTTP/3 via quic-go + Brotli), modeled on `ai_interviewing/platform/backend/internal/server/server.go` (path confirmed to exist at the umbrella level; its contents were NOT read here, so UNCONFIRMED what to reuse); minimal web console; single operator; no multi-user.
- Sources v1: remotive (`https://remotive.com/api/remote-jobs`), remoteok (`https://remoteok.com/api`), himalayas (`https://himalayas.app/jobs/api/search?...`), all keyless. Per-source adapter plus rate-limit and terms-of-use review: UNCONFIRMED.
- Applying: human-in-the-loop; dry-run is the default; any real submission needs explicit operator confirmation per application.
- Positions: 1:1 position to area mapping, no new areas in v1 (the inputs list eight positions).
- CV: ATS-optimised, LaTeX section toggles per position, from the `milosvasic.ru` content; personal values only via `career_private`.
- Containers: any containerised workload goes through `submodules/containers` (§11.4.76); do not hand-roll runtime logic.
- Hosted decision layer only per the 2026-10-28 override (`TYPESAFE_API_KEY` by env-var name, never printed).

## 7. Test types (§11.4.169, 13 types)

UNCONFIRMED: the exact 13-type list was NOT re-read from `Constitution.md` in this session. At kickoff run
`grep -n '^### §11.4.169 ' submodules/constitution/Constitution.md` and copy the enumerated list into the spec's test plan, with anti-bluff runtime evidence for every PASS (§11.4). For a Go API plus web console expect at minimum unit, integration, contract, e2e/UI (HelixQA vision per §11.4.278), security, performance/stress, chaos, regression-guard; confirm against canon, do not rely on this sentence.

## 8. Blockers and open items

1. `rnalbusi` access: handle unverified, token lacked scope. Operator action needed; not done here.
2. Remote moved by one commit with unknown author; rerun the live-session check at kickoff.
3. Layout wording: curriculum-kit is `grouped`, not `flat`; job_seeker should be `flat`.
4. `.gitmodules` already declares job_seeker while the manifest and roster lack it, so the umbrella is likely cascade-RED (C6) until step 5-6 land. UNCONFIRMED: run not performed.
5. jobops licence, stack and adapter boundary unread. UNCONFIRMED.
6. Umbrella working tree is dirty (many `_content*` files modified, outside this task); stage only the files listed above at kickoff.
