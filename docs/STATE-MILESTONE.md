# Milestone State: milosvasic.ru career rework

_Revision 3 (2026-11-23, post-merge-review rewrite). Canonical resume point for this workstream. Every figure carries the command or evidence file that produced it; anything not measured says UNCONFIRMED. No personal data values are recorded here._

Guides: `docs/career/vault-guide.md`, `docs/career/site-build-guide.md`, `docs/career/deploy-guide.md`. Plan: `docs/plans/2026-11-19-milosvasic-ru-rework/PLAN.md`.

## DONE (committed and pushed)

- **Site commit.** `git ls-files -s milosvasic.ru` gives gitlink `b5896642ce7b`; `git -C milosvasic.ru log --oneline -1` = `b589664 feat(site): v2.0.0 rework ...`; it is on `milos85vasic/milosvasic.ru` main. The Pages workflow run `45281909132` succeeded (reported by the orchestrator; run id not re-queried here, UNCONFIRMED by this document's own command).
- **Live verifier, milosvasic.ru** (`docs/qa/live-site/post/verify-live-site-milosvasic_ru-20261123T224227Z.txt`): sitemap URLs 690, pages HTTP 200 690/690, resources 58 (non-200: 0), baseline `docs/qa/live-site/baseline-live-2026-11-23.json` regressions=0 (new_paths=176), `VERDICT: PASS (rc 0)`. `/admin/` and `/downloads/vault/` return 404 live (operator-reported check; the vault directory is not tracked: `git -C milosvasic.ru ls-files downloads/vault | wc -l` = 0).
- **Live verifier, digital.vasic.dev** (`.../post/verify-live-site-digital_vasic_dev-20261123T224322Z.txt`): 527/527 pages 200, 52 resources, regressions=0 against `baseline-live-digital-vasic-dev-2026-11-23.json`. `vasic.digital` tree fingerprint unchanged: `docs/qa/live-site/vasic-digital-tree-fingerprint.txt` records `6d157cc9f41371a1e02d86b3b3b85d14f2cd84a1bb9b1028ffee2c28564fbe3f`.
- **Sitemap.** `grep -c '<loc>' milosvasic.ru/sitemap.xml` = 690; `grep -c 'xhtml:link' milosvasic.ru/sitemap.xml` = 2640 alternates over 165 expertise URLs. (The revision-2 statement that hreflang was unconfirmed is withdrawn.)
- **Umbrella PR #1** (`pr/milosvasic-ru-v2-rework`, state OPEN per `env -u GITHUB_TOKEN gh pr view 1`): carries the milosvasic.ru gitlink, the `helix-deps.yaml` ref, the constitution pin `6d93ccd1` (`git -C submodules/constitution rev-parse --short=8 HEAD`; equals remote head per the orchestrator), and the deploy-script hardening. `bash scripts/verify-manifest-pins.sh`: 21 MATCH / 0 DRIFT / 0 UNDETERMINED. `sha256sum _tools/deploy-langs.sh` = `d77332880759857d...` (was a different value in revision 2).
- **Career engine**: 10 areas, 15 languages. Evidence committed in `docs/qa/career/` (hashes in `SHA256SUMS`):
  - `verify-2026-11-23.txt`: `verified 300/300 artifact(s) passing; expected 300; 0 completeness problem(s)`, rc=0.
  - `build-2026-11-23.txt`: the build log.
  - `unittest-career-2026-11-23.txt`: 268 tests OK, 1 expected failure.
  - `playwright-local-2026-11-23.txt`: 1520 passed, 3 failed. The 3 failures came from a spec edit made in that run; the spec was fixed and re-run, 6/6 passed. This is stated honestly: the committed local file shows the 3 failures, not a clean run.
  - `playwright-live-2026-11-23.txt`: 83 passed, 5 failed. All 5 are on digital.vasic.dev because that static site's own pages still declare canonical host `vasic.digital` (pre-existing; operator decision pending). The milosvasic.ru live specs all passed.
- **Where the PDFs are.** The 300 career PDFs (10 areas x 15 languages x CV and cover letter) are in the git-ignored `.cache-career/` (`git check-ignore -v .cache-career` -> `.gitignore:232`; `find .cache-career -maxdepth 1 -name '*.pdf' | wc -l` = 300). They are NOT shipped on the public site; they are inputs for the sealed vault in the PRIVATE repository. The 45 document PDFs (CV, cover, portfolio) that ARE shipped are under `milosvasic.ru/downloads` (`find milosvasic.ru/downloads -name '*.pdf' -not -path '*vault*' | wc -l` = 45) and were regenerated with contact host `digital.vasic.dev`. (`find milosvasic.ru/downloads -name '*.pdf' | wc -l` = 65 on disk includes untracked vault files; tracked PDFs under downloads: 46.)
- **Expertise pages**: `find milosvasic.ru/expertise -type f | wc -l` = 165 (1 hub, 10 area, 14 localized hubs, 140 localized area pages).
- **Review**: round 1 fixed, round 2 fixed, round 3 GO; PR review GO x2 (security, pins) and docs fixes (orchestrator-reported).

## DECISIONS

- `career_private` is now `vasic-digital/career_private` (private, owner milos85vasic, `rnabulsi` read invite pending). `rnabulsi` already has write on `workshop_curriculum`, `ai_interviewing`, `monetization`.
- PR-driven workflow is the operator-decided mode (§11.4.297): task branch, PR, independent review agents, merge to main. Use `env -u GITHUB_TOKEN gh` (keyring login); the `GITHUB_TOKEN` PAT cannot create PRs.

## PENDING

1. Merge PR #1 (operator/review-gated; fast-forward semantics, never force).
2. Real vault seal: needs the operator passphrase as a file under `_secure/` or an env var (`docs/career/vault-guide.md` section 3). Never printed or committed. Local vault files on disk are untracked and not a real seal (UNCONFIRMED which seal they are).
3. Carriers/index lag versus canon (anchors 289-298; 279 anchors, 13108 lines): `scripts/verify-claim-ledger.sh` shows 4 FALSE claims in the carriers/README.
4. Static-site canonicals still `vasic.digital` (cause of the 5 live failures): operator decision.
5. Moving the 3 personal private repos into the org: not requested.
6. `job_seeker` kickoff: `docs/plans/job-seeker-kickoff-readiness-2026-11-23.md`; ff-only possible, 0 divergent / 1 behind. Operator decides scope.
7. Tag `vasic-1.0.0-dev-0.0.8` after merge. Playwright webkit is not needed.

## Resume

```bash
python3 _tools/career/career.py model     # ok=true, errors=[]
python3 _tools/career/career.py verify    # 300/300
bash scripts/verify-manifest-pins.sh
env -u GITHUB_TOKEN gh pr view 1
```
