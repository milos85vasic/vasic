# Design Principles

Every principle below is enforced somewhere in this repository. The citation is
the enforcement point, not a slogan.

## Evidence discipline

1. **No bluffing — every PASS carries positive evidence.**
   `CLAUDE.md:88` (Constitution §11.4). Gate scripts write artifacts under
   `_tests/evidence/` and the harness verdicts are files, not console text.
2. **Mutation-paired gates.** A gate that cannot be shown to FAIL is not a gate.
   `_tests/GATES.md` traceability table: each self-validate runs a
   `golden-good` (expect PASS) *and* a `golden-bad` (expect FAIL) and exits 0
   only if both hold. `CLAUDE.md:89-90` (Constitution §1.1).
3. **SKIP-with-reason instead of silent gaps.** `_tests/TEST-TYPES.md` marks
   ddos, concurrency, memory and chaos **N/A** with a cited reason rather than
   omitting them; `Constitution.md` OC-3 records a missing verifier as an
   explicit SKIP that never counts as a pass.
4. **No guessing language.** `likely`, `probably`, `maybe`, `seems`, `appears`
   are forbidden when reporting causes — `CLAUDE.md:91-92` (§11.4.6).
5. **State the gap rather than imply coverage.** `CLAUDE.md:155-193` and the
   `Constitution.md` gap table exist solely to say what is *not* done.

## Design and output

6. **Tokens only — no ad-hoc CSS.** Every component is styled only from
   `--od-*` custom properties; `components-extended.css` declares no `:root` at
   all so it inherits whichever brand loaded it
   (`design-system/README.md`).
7. **Both themes, always.** Dark is defined in BOTH `:root[data-theme="dark"]`
   and `@media (prefers-color-scheme: dark)` (`design-system/README.md`).
8. **WCAG 2.2 AA on rendered pixels**, asserted by axe-core in a real browser,
   not by static inspection (`_tests/tests/*-a11y.spec.js`).
9. **Self-hosted assets, no CDN.** Fonts are OFL 1.1 `.woff2` under
   `design-system/fonts/`; icons are a local SVG sprite.
10. **Deterministic, reproducible builds.** The footer © year is pinned via
    `-ldflags -X main.buildYear` from `SOURCE_DATE_EPOCH` → last commit year →
    now; `build-pdfs.sh` pins `SOURCE_DATE_EPOCH` from source mtime so unchanged
    content re-renders byte-identically and stays a git no-op
    (`_tools/deploy-langs.sh:30-36`, `:46-49`).

## Governance

11. **Inherit by reference; never copy the corpus.** `Constitution.md` §101.
12. **Never edit a repository this project does not own.** `Constitution.md`
    §103 — `submodules/superspec` and `milosvasic.ru/Upstreamable` are read-only
    from here, even when a gate reports them MISSING.
13. **Submodule-first propagation, applied by the operator.** Carriers are
    staged under `docs/constitution-adoption/propagation/<submodule>/` with a
    `.staged` suffix and are never written into a submodule working tree from
    the umbrella (`Constitution.md` §102).
14. **An unresolved contradiction is not an override.** Contradictions live in
    "Open conflicts" (OC-1…OC-3); overrides require an operator decision and a
    written justification. `Constitution.md`, "Overrides" section: **None.**
