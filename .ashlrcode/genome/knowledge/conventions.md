# Conventions

> The genome-init scan reported "No standard lint/format configs detected."
> That is accurate — there is no ESLint, Prettier, gofmt-CI or RuboCop config at
> this root. The conventions below are the ones actually enforced, by gate
> scripts, by governance carriers, or by review.

## Detected by scan

- No standard lint/format configs at the repository root.
- Enforcement lives in gate scripts (`_tools/*.sh`, `_tests/*.sh`) and in
  `.github/workflows/ci.yml`, not in linter config files.

## Commits

- **Use the commit wrapper.** `commit "<message>"` → `git add .` + `git commit`
  + `push_all.sh`, which reads `upstreams/*.sh`. No direct `git add` /
  `git commit` / `git push` on the main repo (`CLAUDE.md:95-96`, `:174-181`).
- The wrapper stages **everything untracked** — verify `.gitignore` first.
- Never force-push without explicit per-session authorization and a green
  §9.1.5 post-op gate.
- Recent history on `main` is dominated by `Auto-commit` subjects; release
  commits use the tag-prefixed form seen on `v1.7.1`, `v1.7.2`, `v1.8.0`.

## File layout

- English source content in `_content/{docs,portfolio,products,sites}/`;
  translations in `_content_<lang>/` — 14 language siblings, same subtree shape
  minus `portfolio/`.
- Top-level `_`-prefixed directories are tooling/source (`_tools`, `_tests`,
  `_content*`, `_analysis`); unprefixed ones are checkouts or outputs.
- Generated site pages belong to `_tools/gen/`; do not hand-edit them inside the
  site submodules.
- Evidence is tracked on purpose: `.gitignore` carries an explicit
  `!_tests/evidence/` negation.

## CSS / design system

- All classes are `od-` prefixed; all values are `var(--od-*)`. No ad-hoc CSS
  (`design-system/README.md`).
- Load order: brand CSS → `components-extended.css` → `motion/animations.css`.
- Dark theme defined in **both** `:root[data-theme="dark"]` and
  `@media (prefers-color-scheme: dark)`.
- Every interactive control ships a `:focus-visible` ring and a
  `prefers-reduced-motion` guard.

## Governance carriers

- Five root carriers must stay in lockstep: `CLAUDE.md`, `AGENTS.md`, `QWEN.md`,
  `GEMINI.md`, `Constitution.md`. The four agent carriers are byte-identical
  from line 24 — verify with `tail -n +24 <file> | sha256sum`.
- Every carrier opens with `## INHERITED FROM ` (pointer inheritance, never
  `@import`).
- In this repository the submodule path is `submodules/constitution/`, **not**
  the `constitution/` used by the constitution's own prose and templates. Any
  quoted `constitution/<file>` means `submodules/constitution/<file>` here
  (`CLAUDE.md:41-47`).

## Language in reports

- No `likely` / `probably` / `maybe` / `seems` / `appears` when reporting a
  cause (§11.4.6).
- Unrunnable checks are SKIP-with-reason, never a pass.
- Deviations are disclosed inline — e.g. the `§11.4.65` note at the top of
  `Constitution.md` and `docs/constitution-adoption/README.md` declaring the
  missing `.html`/`.pdf` siblings as known gap G8.

## Toolchains

Go 1.26 · Node 20 · Ruby 3.3 + Bundler · poppler-utils · tesseract-ocr
(`CLAUDE.md:132-134`). `_tools/gen/go.mod` declares
`module vasic.digital/tools/gen`, `go 1.26`.
