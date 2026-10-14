# Workshop authenticated UI QA, 2026-10-14

| Field | Value |
|---|---|
| Revision | 1 |
| Date | 2026-10-14 |
| Target | QA instance only (`http://127.0.0.1:8187`, loopback), never the live container on :8087 |
| Access doc | [workshop-qa-access.md](workshop-qa-access.md) |
| Build under test | `fb798e9` (`/api/health` reports a `-dirty` build stamp) |
| Browsers | chromium 149.0.7827.55, firefox 151.0, webkit 26.5 (Playwright, headless, one at a time) |
| Visibility | Public-safe: statuses, counts, page titles and rule ids only. No curriculum text, no secret. |

## Contents

1. Result matrix
2. Own Playwright specs
3. Defects and root causes
4. Observations
5. Method, limits and repeat commands

## 1. Result matrix

PASS for every check on all three browsers unless marked. Counts are identical across browsers unless stated.

| Check | chromium | firefox | webkit | Evidence (counts only) |
|---|---|---|---|---|
| Unauthenticated `/chapters` redirects to `/login` with `returnUrl=/chapters` | PASS | PASS | PASS | path `/login`, returnUrl `/chapters` |
| Login with QA password, lands on returnUrl | PASS | PASS | PASS | `/chapters` |
| Wrong password shows generic error | PASS | PASS | PASS | one fixed 69-character message, names neither field |
| Unknown user gets the same message as wrong password | PASS | not run | not run | identical text (run once, chromium only, to spare the rate limiter) |
| Login inputs are labelled | PASS | PASS | PASS | 2 of 2 |
| Login keyboard order username, password, submit | PASS | PASS | PASS | see section 4 note 1 |
| Shell loads, account name visible, 5 primary nav items | PASS | PASS | PASS | Curriculum, Chapters, Ask or search, Progress, Status |
| Nav pages load with expected title | PASS | PASS | PASS | titles: "Curriculum · Workshop", "Chapters · Workshop Curriculum", "Ask or search · Workshop Curriculum", "Progress · Workshop Curriculum", "Platform status · Workshop Curriculum" |
| 6 chapter cards | PASS | PASS | PASS | slugs 01, 02, 02.01, 02.02, 03, 04 |
| Chapter page and transcript non-empty, all 6 | PASS | PASS | PASS | chapter pages 1.6k to 4.3k characters, transcripts 9.9k to 111k characters |
| Lesson bodies on knowledge-area pages | PASS | PASS | PASS | 12 area links on the curriculum page; 6 opened, 6 had lesson bodies |
| Search, 3 terms (keyword + meaning legs) | PASS | PASS | PASS | HTTP 200 each, 20 result nodes each, legs: keyword ran, meaning ran, code search not run |
| Ask a question shows answering-unavailable state | PASS | PASS | PASS | `/api/ask` HTTP 503, reason code `no_provider`, UI shows the unavailable state |
| axe-core (login, curriculum, chapters, search, status, progress) | PASS | PASS | PASS | 0 violations on all 6 pages |
| No horizontal overflow, 390x844 and 1440x900 | PASS | PASS | PASS | 12 page/viewport pairs, scrollWidth == clientWidth |
| Page load timing, `/chapters` x5 | p50 79, p95 97 ms | p50 215, p95 262 ms | p50 141, p95 219 ms | load plus chapter grid visible |
| Logout ends session | PASS | PASS | PASS | redirected to `/login`, auth key removed, revisit redirects to `/login` |

Console and network (whole run per browser, including the deliberate wrong-password and ask steps):

| | chromium | firefox | webkit |
|---|---|---|---|
| console errors / warnings | 11 / 4 | 1 / 0 | 10 / 2 |
| HTTP responses >= 400 | 11 | 10 | 10 |
| request failures that are not navigation aborts | 0 | 10 (see section 4 note 3) | 0 |

Every console error corresponds to an HTTP status line, not a script exception. The distinct HTTP errors are: 401 `/api/auth/login` (the deliberate wrong password), 404 `/api/progress`, 503 `/api/passages/<id>/crossrefs`, 503 `/api/ask`. See sections 3 and 4 for each.

## 2. Own Playwright specs

`workshop/platform/frontend/e2e/`, project `desktop-chromium`, against the QA base through `WORKSHOP_BASE_URL`, one spec at a time, each under a 175 s cap.

| Spec | Result | Time |
|---|---|---|
| `served.spec.ts` | 6 passed | 8 s |
| `a11y-responsive.spec.ts` | 38 passed, 1 skipped (phone screenshots) | 140 s |
| `browse-and-watch.spec.ts` | 9 passed, 2 failed | 27 s |
| `curriculum-chapter-rails.spec.ts` | 3 passed, 2 failed, 1 skipped | 45 s |
| `search-degradation.spec.ts` | 10 passed, 1 failed | 9 s |

The 5 failures are analysed in section 3. None is a defect in the served application; none was fixed (the task forbade editing workshop source).

## 3. Defects and root causes

No application defect was found. Five spec failures, each investigated to a cause:

| # | Failing test | Root cause | Class |
|---|---|---|---|
| 1 | browse-and-watch: "a reduced payload is LABELLED reduced rather than padded with zeros" | The assertion `not.toContainText('0 passages')` is a substring match. The curriculum page legitimately prints larger counts that end in "0 passages" (three occurrences, preceded by the digits `11`, `1` and `9`, that is 110, 10 and 90). The page is not printing a zero count. | Test defect (substring too loose) |
| 2 | browse-and-watch: "supporting material is reachable via its API route" | The detail of chapter 01 lists a PDF material. GET on its href returns HTTP 410 with reason `export_carries_suppressed_content`. This is the suppression guard (`internal/suppression/httpguard.go`, `writeWithheld`) withholding an export that contains suppressed passage text, by design. The spec expects 200 for any non-video material and predates the guard. Other materials: markdown 200, code 200 in chapters 01, 03; PDF 200 in chapters 02 and 03; markdown 200 in chapter 04. | Spec stale versus designed behaviour |
| 3, 4 | curriculum-chapter-rails: "first chapter expanded, others collapsed" and "collapsed chapter opened with the keyboard" | `chapter-rail.component.ts` sets `autoOpen = openByDefault() || recordingState() === 'available'`, so every chapter whose recording is available opens by default (its own comment says "not only whichever one happens to sit at list index 0"). Chapter 02 therefore starts open and the spec's "only the first" expectation fails. | Spec stale versus current component |
| 5 | search-degradation: "catalogue rows render as text; rows with a deep_link keep it verbatim" | The test requires the mixed-population probe query to return both linked and unlinked rows. On this QA corpus the first 20 rows were all linked, so the test refuses to pass vacuously (its own message says so). | Data precondition, not a UI fault |

Whether to update those specs is a decision in the private `workshop` repository and was not taken here.

## 4. Observations (not defects)

1. Login Tab order is skip link, brand, 5 nav links, "Log in" link, theme toggle, username, password, submit. With empty fields the submit button was skipped by Tab in all three browsers and was reached once both fields had text (checked separately, all three browsers). Why it is skipped when empty was not investigated: UNCONFIRMED whether that is a disabled state.
2. After logout the auth key is removed. A separate key `workshop-session` (36 characters) remains in local storage. The source (`core/api.ts`, `SESSION_KEY`) shows it is a per-browser identifier, not the login token. No claim is made about its privacy properties.
3. Firefox reported 10 failed requests to `/api/chapters/<id>/recording` with `NS_ERROR_PARSED_DATA_CACHED`, with no console error attached and no HTTP status. Cause not investigated: UNCONFIRMED. Chromium and webkit showed none.
4. The `/api/progress` 404 is documented in `progress.component.ts` ("answers 404 with status not_found") and the page rendered normally.
5. The 503 on `/api/passages/<id>/crossrefs` matches this QA instance's startup log: the prebuilt crossrefs bundle was built over a different corpus checksum than the one served, so nothing was imported. Whether the live instance has the same condition was not measured.
6. All 6 chapter cards on the curriculum page carry the "minimal" badge (`data-code="minimal"`). Whether that is correct for this payload was not judged.
7. "Ask or search" has three modes (`mode-auto`, `mode-answer`, `mode-search`). The ask step was run with answer mode selected.
8. The QA scope reported inactive to `systemctl --user is-active workshop-qa-instance.scope`, yet `/api/health` answered HTTP 200 and port 8187 was listening, so QA proceeded. UNKNOWN why the unit query and the process disagree; nothing was restarted.
9. Webkit launched on this host (version 26.5); an older note that webkit could not start is not reproduced for this QA suite.

## 5. Method, limits and repeat commands

- Scratch is disk-only under `~/.cache/agent-scratch/workshop-ui-qa` (mode 0700). No screenshots or DOM text were committed; the spec runs wrote their artifacts inside the git-ignored `workshop/platform/frontend/e2e/artifacts/`.
- The password was loaded inside each command from `~/.config/workshop-qa/seed.env` and never printed. The login limiter was not tripped: one wrong-password attempt per browser (two in chromium), spaced by at least 3 s, runs separated by about a minute.
- Limits: 5 loads per timing sample is a small sample; axe-core was run on the default rule set only; lessons were opened through knowledge-area pages (6 of 12), and chapter pages plus transcripts were opened for all 6 chapters; only the `desktop-chromium` project of the repo's own specs was run.
- This QA instance shares its content with the live one but not its network binding, LAN login behaviour or volume, so a pass here is not evidence about them.

Repeat (from the repository root, the harness scripts live in the scratch directory and are not committed):

```bash
curl -s http://127.0.0.1:8187/api/health | head -c 200
mkdir -p -m 700 ~/.cache/agent-scratch/workshop-ui-qa/tmp
cd ~/.cache/agent-scratch/workshop-ui-qa && export TMPDIR=$PWD/tmp
sed -n 2p /proc/pressure/memory      # wait while full avg10 >= 30
for b in chromium firefox webkit; do
  ( set -a; . ~/.config/workshop-qa/seed.env; . ~/.config/workshop-qa/base.env; set +a
    ~/.local/bin/bounded-run -m 6G -T 580 -- node qa.js "$b" )
  sleep 70
done

# the repo's own specs, one at a time
( set -a; . ~/.config/workshop-qa/seed.env; . ~/.config/workshop-qa/base.env; set +a
  export WORKSHOP_BASE_URL="$WORKSHOP_QA_BASE"
  cd workshop/platform/frontend
  ~/.local/bin/bounded-run -m 6G -T 175 -- \
    npx playwright test e2e/served.spec.ts --project=desktop-chromium --reporter=list )
```

`qa.js` drives Playwright from `_tests/node_modules` (playwright and axe-core) and writes `result-<browser>.json` with only statuses and counts.
