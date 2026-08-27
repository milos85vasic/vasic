# Dependencies

External dependencies, API contracts, and gotchas.

## Declared manifest

`helix-deps.yaml` at the repository root (§11.4.31; gap G6 **CLOSED**, verified
2026-08-27, parses under `yaml.safe_load`). It declares own-org dependencies
only — a third-party gitlink is recorded there as a **comment**, never a `deps`
entry (`Constitution.md`, superspec exclusion, point 4).

## Toolchains the gates require (CI-matched)

| Tool | Version | Used by |
|---|---|---|
| Go | **1.26** | `_tools/gen` unit tests + generator build (`_tools/gen/go.mod`) |
| Node | **20** | `_tests` Playwright harness |
| Ruby + Bundler | **3.3** | `milosvasic.ru` Jekyll build |
| poppler-utils | — | export gate: `pdftotext`, `pdfimages`, `pdftoppm` |
| tesseract-ocr | — | export gate: OCR layer |

If poppler/tesseract are missing, gate 5 **degrades to a reasoned SKIP** rather
than failing (`README.md:50-52`). Missing `pandoc`/`weasyprint` makes
`deploy-langs.sh` warn and skip the PDF build — never fake an artifact.

## Node packages (`_tests/package.json`, private, not published)

- `@playwright/test` ^1.61.0 (dev)
- `pixelmatch` ^7.2.0, `pngjs` ^7.0.0 (dev) — visual diffing
- `@axe-core/playwright` ^4.11.3 (runtime dep) — a11y audits

Install path: `npm ci` then `npx playwright install chromium` inside `_tests/`.

## Go module

`module vasic.digital/tools/gen`, `go 1.26`. Sources: `main.go`, `data.go`,
`home.go`, `i18n.go`, `markdown.go`, `portfolio.go`, `product.go`, `seo.go`,
`shells.go` with table tests alongside. Python helpers in the same directory
handle UI-string translation/review (`translate_ui_*.py`, `review_ui_*.py`,
`merge_ui.py`, `audit_ui_glossary.py`).

## Design system assets

Self-hosted only, no CDN: OFL 1.1 `.woff2` families under
`design-system/fonts/` (Inter, JetBrains Mono, Bricolage Grotesque, Anton,
Fraunces) and a local SVG sprite at `design-system/icons/icons.svg`. Generated
with OpenDesign (`github.com/nexu-io/open-design`) — but OpenDesign is **not yet
consumed as an external dependency**, which `_tests/GATES.md` records as an open
§11.4.162 gap.

## Agent / semantic tooling (host-level, not repo-level)

- **Lumen** — MCP semantic search. Not an npm package: it ships as a Claude Code
  plugin binary resolved at call time by a version-agnostic wrapper at
  `~/.local/bin/lumen` (`sort -V`, so `0.0.100` outranks `0.0.9`). Override with
  `LUMEN_BIN`.
- **ollama** — local embedding backend. Model
  `ordis/jina-embeddings-v2-base-code` (~320 MB), set in
  `scripts/lumen-reindex.sh:45` and `scripts/setup-agents-wizard.sh:204`,
  overridable via `LUMEN_EMBED_MODEL`.
- **CodeGraph** — `@colbymchenry/codegraph` (npm), SQLite graph at
  `.codegraph/codegraph.db`. Refresh with `codegraph sync`; `codegraph init`
  only when no DB exists. **Never `codegraph index`** — it discards the DB.
- Also wired by the wizard: Bun, Glyphdown, SpecKit (`uv tool install
  specify-cli` — a Python tool, not npm), `ashlr-plugin`, optional WOZCODE.
- A Vulkan/Intel-iGPU remediation runbook exists at
  `docs/setup-agents-wizard/OLLAMA-REMEDIATION.md`
  (+ `scripts/ollama-vulkan-remediation.sh`).

## Hosting contract

GitHub Pages, static file hosting. Consequences recorded in
`_tests/TEST-TYPES.md`: **no response-header control** (so CSP exists only as a
`<meta>` tag and is checked that way; HSTS/WAF are N/A), no origin server, no
database, no runtime state.

## Credentials

Never tracked. `.gitignore` blocks `.mcp.json`, `.env`/`*.env`/`.env.*`,
`api_keys.sh`, `secrets.sh`, `*.pem`, `*.p12`, and ssh key patterns at any depth
(§11.4.10).
