# job_seeker inputs summary

| | |
|---|---|
| Source | `job_seeker/docs/materials/mvp/inputs.md` at job_seeker commit `cc7b0749f185` (read AFTER the 2026-11-24 fast-forward from `8066233`) |
| Date | 2026-11-24 |
| Scope | Faithful structure of the operator's input file. No personal data values. Anything beyond the file is labelled as a decision or UNCONFIRMED. |

## Requirements stated in the file

1. Name of the standard / protocol: ATS (Applicant Tracking System).
2. The CV MUST be optimised for ATS; the CV content comes from the `milosvasic.ru` submodule.
3. The CV is customised per position: AI Engineer, Android Engineer, Android TV Engineer, Android AOSP Engineer, Flutter Engineer, React Native Engineer, Mobile Engineer, Go (lang) Engineer.
4. LaTeX is used to dynamically toggle sections when the CV is exported to PDF and other major formats (HTML, Markdown, Docx), depending on the position the CV is needed for.
5. Job-applying services that MUST be fully incorporated:
   - `https://remotive.com/api/remote-jobs`
   - `https://remoteok.com/api`
   - `https://himalayas.app/jobs/api/search?q=software%20engineer&sort=recent&page=1`
   - `https://api.jobspipe.dev/v1/jobs/search`
   - Sprout AI
   - SmartApplier

## Additional (section in the file)

All of the above MUST be fully incorporated using, as a Submodule, the service `https://jobops.app/` (repo `https://github.com/DaKheera47/job-ops`), with additional materials at `https://jobops.app/#demo` and `https://github.com/DaKheera47?tab=repositories`.

## Changes by the incoming commit (`cc7b074` "Update inputs.md")

1 insertion, 7 deletions in this file only. The pre-ff text is not reproduced here; the list above is the post-ff text.

## Decisions layered on top (NOT in the file; operator decisions recorded elsewhere)

- Prefix `JSK`; layout `flat`; private repository; no personal data in git (`career_private` overlay).
- v1 sources: remotive, remoteok, himalayas (keyless); jobspipe, Sprout AI, SmartApplier deferred. The file says all MUST be incorporated, so the deferral is a scheduling decision, not a scope removal. UNCONFIRMED whether any deferred source needs a key.
- Applying is human-in-the-loop, dry-run by default.
- Stack: Go + Gin + HTTP/3 (quic-go) + Brotli.

## Open / UNCONFIRMED

- jobops licence, stack and adapter boundary have not been read.
- Per-source terms of use and rate limits have not been reviewed.
- Meaning of "Sprout AI" and "SmartApplier" integration surface (API vs UI) not established.
