# §11.4.169 Test-Type Coverage — vasic.digital + milosvasic.ru

This repository ships **two static sites** (`vasic.digital`, a standalone
OpenDesign build; `milosvasic.ru`, a Jekyll build) plus **Go/Node/Python
tooling** that generates and validates them. There is **no application server,
no database, and no runtime state** — the deployment target is GitHub Pages
(static file hosting). That fact determines which of the §11.4.169 mandatory
test types are *applicable*, which are *added by this change*, and which are
*genuinely N/A* (documented here per §11.4.3 SKIP-with-reason rather than left as
a silent gap).

Status legend: **PRESENT** (existed before this change) · **ADDED** (this change)
· **N/A** (not applicable to a static-site + build-tooling repo, with cited
reason).

| # | §11.4.169 test type | Status | Where / Evidence |
|---|---------------------|--------|------------------|
| 1 | **unit** | **ADDED** | Go table tests for the generator: `_tools/gen/*_test.go` (markdown renderer, `esc`/`escText`, frontmatter parser, `availableLangs`, `langPath`, `Site.URL`, hreflang matrix, JSON-LD nodes, `seoHead` singletons, sitemap/robots writer, license-hide, chip-cap, `repoLabel`). Python unit tests for the glossary sentinel roundtrip: `_tests/tools/glossary_protect_test.py`. Evidence: `evidence/test-types/go-test.txt`, `evidence/test-types/glossary-protect.txt`. |
| 2 | **integration** | **ADDED** | Link-integrity crawl across each generated site — nav, product cards, portfolio, downloads, and **every sitemap.xml URL** must resolve `<400`; the anti-bluff private-repo deep-link guard is re-asserted. `_tests/tests/link-integrity.spec.js`. Also the data-gate **mutation test** proving `validate.mjs` actually fails on bad portfolio data (excluded / private-leak / order-break): `_tests/tools/validate.mutation.test.mjs` → `evidence/test-types/validate-mutation.txt`. |
| 3 | **security** | **ADDED** | Per key page: no inline secrets in shipped HTML, no `http://` mixed-content subresources, no inline `on*=` handlers, `rel=noopener` on every `target=_blank`, and CSP-`<meta>` presence recorded. `_tests/tests/security-hardening.spec.js`. Server-header security (CSP/HSTS response headers, WAF) is **N/A** — GitHub Pages does not let you set response headers; the only static-site lever is a `<meta>` CSP, which is checked. |
| 4 | **performance** | **ADDED** | Real transferred-bytes + request-count budget measured from Playwright's network layer (not a faked Lighthouse score), plus LCP-candidate presence and a render-blocking-`<head>`-script check. Lighthouse/LHCI is **not** a declared/installable dependency here, so a **documented lighter proxy** is used per the task allowance. `_tests/tests/perf-budget.spec.js` → real numbers in `evidence/test-types/perf-budget.json` (e.g. vasic home 221 KB / 10 req / LCP 28 ms; budget 1.5 MB / 45 req). |
| 5 | **e2e** | PRESENT | Feature/behaviour specs: `_tests/tests/vasic-digital.spec.js`, `milosvasic-ru.spec.js`, `*-features.spec.js` (nav, hero, theme toggle + persistence, product-card links, responsive overflow). |
| 6 | **accessibility (a11y)** | PRESENT | `@axe-core/playwright` audit + keyboard/skip-link/contrast checks: `_tests/tests/milosvasic-ru-a11y.spec.js`. |
| 7 | **i18n** | PRESENT | `_tests/tests/i18n-completeness.spec.js`, `vasic-digital-i18n-articles.spec.js`, `milosvasic-ru-i18n-articles.spec.js`; hreflang reciprocity is additionally asserted by the new `seo-meta.spec.js`. |
| 8 | **visual** | PRESENT | Visual oracle + evidence screenshots: `_tests/visual/visual-oracle.js`, `_tests/visual/self-validate.sh`, per-site full-page screenshots under `evidence/homepages/`. |
| 9 | **export** | PRESENT | PDF/asset export validation: `_tests/export/validate-pdf.js`, `make-image.js`, `self-validate.sh`, fixtures. |
| 10 | **SEO / structured-data** | **ADDED** | Per key page: exactly one non-empty `<title>`, non-empty meta description, canonical, valid Open Graph + Twitter card, ≥1 parseable JSON-LD block with a schema.org `@type`, and reciprocal hreflang. `_tests/tests/seo-meta.spec.js`. (Folded under §11.4.169 SEO coverage.) |
| 11 | **ddos / rate-limiting** | **N/A** | No origin server to flood. GitHub Pages is a CDN-fronted static host; there is no application request handler, session, or compute path this repo owns that could be rate-limited or DoS-tested. Any DDoS protection is a property of GitHub's edge, not of this codebase. Nothing to assert without bluffing. |
| 12 | **concurrency / atomicity** | **N/A** | The shipped artifact is immutable static HTML/CSS/JS with **no shared mutable state, no transactions, no writes** at request time. The only concurrency in the repo is the offline build (`gen`, translate pipeline), which is single-shot and deterministic; its correctness is covered by the unit tests above (pure functions, no goroutine-shared state). There is no concurrent-write invariant to test. |
| 13 | **memory / leak** | **N/A** | No long-running process owned by this repo. Pages are served as files; the client-side JS is a tiny deferred motion/theme controller with no allocation loop or retained listeners across navigations (each page is a fresh document). The Go generator is a short-lived CLI that exits; there is no resident heap to profile for growth. (Client memory pressure would surface via the perf-budget asset ceiling.) |
| 14 | **chaos / resilience** | **N/A** | Chaos engineering targets distributed runtime failure modes (node loss, network partition, dependency brownout). A static site has no backend topology, no inter-service calls, and no failover to perturb. The analogous “resilience” property for a static site — that no page links to something that 404s or leaks a private repo — is covered as **integration** (link-integrity + private-repo guard) rather than chaos. |

## Notes on honest edges (no bluff)

- **Private-repo suppression lives at the data gate, not in the Go renderer.**
  `_tools/gen` declares `PortfolioEntry.Private` but never branches on it — the
  renderer trusts pre-validated data. Suppression is enforced upstream by
  `_tools/portfolio/validate.mjs` (fails if a `private:true` entry lists repos)
  and re-asserted at runtime by the Playwright private-repo deep-link guard. The
  Go side adds `TestPortfolioDataHasNoPrivateLeak` as a belt-and-suspenders guard
  on the data the renderer consumes. This is documented rather than papered over.

- **milosvasic.ru homepage has no hreflang.** Its `<head>` is owned by
  `jekyll-seo-tag`, which does not emit `hreflang`. Its product and portfolio
  pages ARE Go-rendered and carry the full reciprocal hreflang matrix, as does
  all of vasic.digital. `seo-meta.spec.js` therefore asserts hreflang on every
  page EXCEPT that one homepage; the exception is intentional and recorded here,
  not silently skipped.

- **Performance uses a measured proxy, not Lighthouse.** No Lighthouse score is
  reported because LHCI is not an installed dependency. The budget is real
  measured transfer size / request count / LCP presence — see
  `evidence/test-types/perf-budget.json` for the actual per-page numbers.

## How to run

```
# unit — Go generator
( cd _tools/gen && go test ./... )

# unit — glossary sentinel roundtrip
python3 _tests/tools/glossary_protect_test.py

# integration — data-gate mutation proof
node _tests/tools/validate.mutation.test.mjs

# integration / security / performance / SEO / e2e / a11y / i18n (all specs, 3 browsers)
( cd _tests && npx playwright test )
```
