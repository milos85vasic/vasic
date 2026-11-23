# Milestone State: milosvasic.ru career rework

_Revision 2 (2026-11-23). Canonical resume point for this workstream. Every number below was measured on 2026-11-23 and carries the command that produced it; anything not measured says UNCONFIRMED. No personal data values are recorded here._

Related guides: `docs/career/vault-guide.md` (sealed vault operator manual), `docs/career/site-build-guide.md`, `docs/career/deploy-guide.md`. Plan: `docs/plans/2026-11-19-milosvasic-ru-rework/PLAN.md`.

## DONE

- **Career engine** (`_tools/career/`, content in `_content/career/`): 10 areas (`ls _content/career/areas | wc -l` = 10) and 14 non-English locale files plus the English master (`ls _content/career/locales | wc -l` = 14; EN is the master in `profile.yaml`), so 15 languages in total. `python3 _tools/career/career.py model` returns `ok: true, errors: []`. `career.py locales` reports OK per locale (all 14 lines read OK in the tail checked; the full-run exit code was not captured, UNCONFIRMED). The Chinese locale code is `zh` (older drafts said `z`; that was wrong).
- **300 PDF target**: 10 areas x 15 languages x 2 kinds (CV, cover letter) = 300. **The rebuild is IN PROGRESS at the time of writing and is NOT claimed built.** Measured on disk now: `find milosvasic.ru/downloads -name '*.pdf' | wc -l` = 65 (the old pre-rework generic set plus partial output); UNCONFIRMED whether the final 300 exist. Verification command when the build ends: `python3 _tools/career/career.py verify`.
- **Vault v1, redefined**: sealed to the private repository decision (see `docs/career/vault-guide.md`). On disk now: `find milosvasic.ru/downloads/vault -type f | wc -l` = 21 (a `manifest.json` plus 20 files under 10 area directories); UNCONFIRMED whether these are a real seal or an earlier test seal. A real seal with the operator passphrase is still pending.
- **Private repository**: `milos85vasic/career_private` exists as a sibling checkout (`ls /home/milosvasic/Projects | grep career` = `career_private`), with an overlay mechanism and `career.py private-check`. Today `private-check` returns `CANNOT DETERMINE: CAREER_PRIVATE_DIR is not set`, which is rc 2 and never a pass; it must be re-run with the variable set.
- **Expertise pages**: `find milosvasic.ru/expertise -type f | wc -l` = 165, all `index.html`. Breakdown: 1 hub + 10 area pages + 14 localized hubs (`expertise/<lang>/`) + 140 localized area pages (`expertise/<area>/<lang>/`). The figure 187 that circulated earlier is NOT reproduced by this measurement (165); UNCONFIRMED what it counted, so 165 is the number to trust. `expertise_localized.json` holds 14 entries (python3 `len(json.load(...))`). No directory is literally named `_hub`; the localized hubs sit at `expertise/<lang>/index.html`.
- **SEO**: the committed `milosvasic.ru/sitemap.xml` has 690 `<loc>` entries (`grep -c '<loc>'`) but 0 `xhtml:link` and 0 `hreflang` matches in this measurement, so the hreflang sitemap is NOT confirmed in the committed file (it may be produced by the generator, `_tools/gen/seo.go`, at build time; UNCONFIRMED). PNG og cards: `ls milosvasic.ru/assets/og/*.png | wc -l` = 11; UNCONFIRMED whether that covers all 10 areas plus default.
- **Deploy-script hardening**: `_tools/deploy-langs.sh` modified in the working tree (see `git status`); not yet committed.
- **Constitution pin**: fast-forwarded to `6d93ccd1` (`git -C submodules/constitution rev-parse --short=8 HEAD` = `6d93ccd1`; the index gitlink is `6d93ccd19e1c2fe0e1a97ece22b49e962ef3005e`, staged together with `helix-deps.yaml`).
- **Independent review round 1**: findings fixed (reported by the orchestrator, not re-measured here).

## PENDING (in order)

1. Final PDF rebuild finishes, then `python3 _tools/career/career.py verify` (full 10x2x15 matrix built, gated, manifested).
2. Clean containerized Jekyll build: `_tools/containers/bin/site-build -workload jekyll -build-year 2026`, then re-check the sitemap/hreflang and expertise counts above. The earlier "525/525 URLs" figure is superseded and must be re-measured; do not quote it.
3. Full Playwright run (`_tests/`), including the new `expertise.spec.js` and `css-visual-regression.spec.js`.
4. Independent review round 2 (running at the time of writing).
5. Commit and push order: the `milosvasic.ru` submodule first (it shows `m` in `git status`), then the umbrella with the `milosvasic.ru` gitlink and the `helix-deps.yaml` ref staged together (cascade check C9). Fast-forward only, never force. Operator-gated; nothing is committed yet.
6. Tag `vasic-1.0.0-dev-0.0.8` on the umbrella and owned submodules, after 5.
7. Real vault seal: needs the operator passphrase, supplied as a file under `_secure/` (does not exist yet: `ls _secure` fails) or via an environment variable; see `docs/career/vault-guide.md` section 3. The passphrase is never printed or committed.
8. `job_seeker` kickoff checklist, after 1 to 6: (a) confirm 300 PDFs verified, (b) confirm live site passes the Playwright live specs, (c) re-run `private-check` with `CAREER_PRIVATE_DIR` set, (d) confirm the vault is sealed and the console decrypts one slot, (e) operator decides scope and start. UNCONFIRMED: no `job_seeker` artifacts exist yet.

## Resume

```bash
cd <repo root>
python3 _tools/career/career.py model     # ok=true, errors=[]
python3 _tools/career/career.py locales   # every locale OK
find milosvasic.ru/downloads -name '*.pdf' | wc -l   # target 300 when the rebuild is done
python3 _tools/career/career.py verify
```
