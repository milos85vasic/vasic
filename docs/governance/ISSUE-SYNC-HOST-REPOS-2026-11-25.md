# Issue-sync host repositories created 2026-11-25

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-11-25 |
| Authority | Operator decisions 2026-11-25 (create all missing repos via host APIs, visibility matches the owning repository, never make anything public that is private); anchor 11.4.300 |
| Secrets | none recorded; tokens are referenced by variable NAME only |

Empty repositories (no code pushed) created only so the workable-items Issues mirror has a target. Visibility equals the owning repository: `vasic` (umbrella) is public on GitHub, so its mirrors are public; `job_seeker` is private on GitHub, so its mirrors are private.

| Host | Repository | Visibility | Issues | Token variable |
|---|---|---|---|---|
| gitlab.com | vasic-digital/job_seeker | private | on | GITLAB_TOKEN |
| gitlab.com | milos85vasic/vasic | public | on | GITLAB_TOKEN |
| codeberg.org | vasic-digital/job_seeker | private | on | CODEBERG_GITEA_TOKEN |
| codeberg.org | milosvasic/vasic | public | on | CODEBERG_GITEA_TOKEN |
| git.m3w.org | vasic-digital/job_seeker | private | on | M3W_GITEA_TOKEN |
| git.m3w.org | milos85vasic/vasic | public | on | M3W_GITEA_TOKEN |
| gitflic.ru | milosvasic/job_seeker | private | on | GITFLIC_TOKEN |
| gitflic.ru | milosvasic/vasic | public | on | GITFLIC_TOKEN |
| gitverse.ru | milosvasic/job_seeker | private | on | GITVERSE_TOKEN |
| gitverse.ru | milosvasic/vasic | public | on | GITVERSE_TOKEN |

Read access for `rnabulsi` on private repositories: granted on gitlab.com (Reporter on vasic-digital/job_seeker). That user does not exist on codeberg.org, git.m3w.org, gitflic.ru or gitverse.ru (HTTP 404 on each user lookup), so no grant was possible there.

GitHub: nothing was created. The plan rows reported `repo-absent` for `vasic-digital/ai_interviewing`, `vasic-digital/monetization` and `vasic-digital/workshop_curriculum` are a token-scope artefact: those private repositories exist (`git ls-remote` over SSH answers, and the operator's gh keyring login sees them with admin), but the `GITHUB_TOKEN` fine-grained token in `~/api_keys.sh` is not granted them and gets 404. `milos85vasic/workshop_curriculum` in the plan is a stale owner; the repository lives at `vasic-digital/workshop_curriculum`.

Throwaway test issues titled `[LIVETEST-ISSUESYNC] ...` exist in: git.m3w.org, codeberg.org, gitlab.com `vasic-digital/job_seeker` (closed), gitverse.ru none (create refused), gitflic.ru `milosvasic/job_seeker` #1 (OPEN; no close endpoint found), github.com `milos85vasic/vasic` #110 (closed, not planned) plus one later closed run.
