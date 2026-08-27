# Shipped releases

Evidence: `git tag` on the umbrella (4 tags) plus `_analysis/CHANGELOG.md`.
Tag subjects are quoted from `git log -1 --format='%ci %s' <tag>`.

| Tag | Date | Subject |
|---|---|---|
| `v1.8.0` | 2026-08-08 | apply brand-anchored hybrid tokens to live (crimson M3 palette refinement) |
| `v1.7.2` | 2026-08-08 | chore: bump site pointers — vasic.digital `217d535`, milosvasic.ru `9a3d350` |
| `v1.7.1` | 2026-08-08 | eliminate hardcoded content — localized footer/blurbs/meta, deterministic © year, Linux latinization; bump all pointers |
| `pre-restyle` | 2026-08-07 | Bump submodules: design-toolkit expansion v2 (`13a76eb`) + constitution (`7819e23`) — **rollback restore point**, not a release |

`v1.8.0` is present on `milosvasic.ru` and `vasic.digital` only; §4 mirroring to
the other owned submodules is incomplete (gap G10).

## v1.6.0 — bold re-style, both sites

The only release with a narrative entry (`_analysis/CHANGELOG.md`; full detail in
`_analysis/RESTYLE-v1.6.0.md`). Each property was generated as two candidates
and Candidate A shipped on both:

- **vasic.digital → "MACHINA"** — Bricolage Grotesque display, sharp 0–4px
  corners, whole-page blueprint grid, GPU-only scanline/aurora motion, deep dark
  red `#8f1d2d` retained.
- **milosvasic.ru → "TERMINAL BRUTALIST"** — uppercase Anton display, 2px ink
  frames, hard offset print-shadows, engineering-grid texture, crimson `#a31e39`
  retained.

New self-hosted OFL faces (latin + latin-ext, no CDN); Inter and JetBrains Mono
unchanged. Verified from `_tests/evidence/restyle/`: **0 serious/critical and 0
total axe violations** on every page/theme, **0 horizontal overflow** on desktop
and mobile, milos behaviour intact (hamburger, 15-item language switcher,
15-language download modal, back-to-top), reduced-motion and
reduced-transparency fallbacks present.

Rollback restore points recorded at the time: vasic `v1.5.0`, milos `v1.5.2`,
umbrella `pre-restyle`. Rejected alternates are parked, not deleted — see
`strategies/graveyard.md`.

## Note on release cadence

`_analysis/CHANGELOG.md` documents **only** v1.6.0. There is no changelog entry
for v1.7.1, v1.7.2 or v1.8.0 — their tag subjects above are the whole record.
The `submodules/constitution` and `submodules/superspec` changelogs belong to
those upstream projects, not to this one.
