# North Star

> **Grounding.** No file in this repository carries a sentence labelled
> "mission", "vision" or "north star". What follows is assembled from the two
> self-descriptions that *do* exist — `README.md` lines 5–8 and the
> "Project overview" section of `CLAUDE.md` (lines 107–116, byte-identical in
> `AGENTS.md` / `QWEN.md` / `GEMINI.md`). Anything not traceable to those is
> marked **(inferred)**.

## What this project is FOR

`vasic` is the **umbrella monorepo for two personal/portfolio sites and the
shared tooling that builds, translates and validates them**
(`README.md:5`, restated verbatim in `CLAUDE.md:109-116`).

README states the boundary itself, and it is the sharpest statement of intent
in the repository:

> "Nothing here is a framework — it is the working monorepo: the sites live as
> git submodules, and everything that generates or checks them lives at the top
> level." — `README.md:6-8`

The two properties it exists to ship:

| Site | Brand | Build model |
|---|---|---|
| `vasic.digital/` | company (`#dc3545`, `design-system/brand-vasic-digital/`) | committed static HTML, served as-is, **no build step** |
| `milosvasic.ru/` | personal (`#a31e39`, `design-system/brand-milosvasic/`) | Jekyll source; rendered `_site/` is git-ignored |

Deployment target is GitHub Pages — static file hosting with
"no application server, no database, and no runtime state"
(`_tests/TEST-TYPES.md`, opening paragraph). That single fact drives most of
the architecture and most of the test-coverage decisions.

## The end-state the evidence supports

Three commitments are stated repeatedly across `README.md`, `Constitution.md`,
`design-system/README.md` and `_tests/TEST-TYPES.md`, and are the closest thing
this repository has to an end-state:

1. **Both sites ship in every complete language, from one English source.**
   `_content/` is English; `_content_<lang>/` holds 14 sibling languages. A
   language deploys only when *every* source doc has a `PASS` review verdict
   (`_tools/deploy-langs.sh:21-25`).
2. **One design system governs every surface** — both sites, both themes, docs
   and PDFs — with no ad-hoc CSS (`design-system/README.md`, opening paragraph,
   citing Helix Constitution §11.4.162).
3. **Nothing is claimed green that was not proven green.** Every gate that can
   pass must also be proven able to *fail*; gates that cannot be proven are
   recorded as explicit SKIP-with-reason, never as a pass
   (`_tests/GATES.md`, `CLAUDE.md:88-102`, `Constitution.md` "Known open gaps").

**(inferred)** Taken together the repository behaves as a *personal
publishing platform with institutional-grade evidence discipline*: the sites
are small, the machinery around them is not, and the machinery is the point.
This framing is the genome author's reading, not a repository statement.

## What the north star is explicitly NOT

- Not a reusable framework or product — `README.md:6`.
- Not constitution-compliant yet. `CLAUDE.md:155-193` and the `Constitution.md`
  gap table both state plainly that gaps G4, G5, G7, G8, G9, G10, G11 and G12
  are OPEN. Compliance is a destination, not a current state.
