# WSP-060 — chapter-01 deferred redactions: proposal summary (public-safe)

| | |
|---|---|
| Register item | WSP-060 |
| Date | 2026-10-14 |
| Author | agent (read-only proposal) |
| Status | **PROPOSAL — NOTHING APPLIED.** No redaction log row, registry row, rendered file, gate or allow-list was written. |
| Full proposal | Kept privately, outside this repository. It contains pids, segment indices and private line numbers. |
| Private module measured | `workshop` at `fb798e9` |

**Content rule.** This file holds decision ids, counts, reason classes and neutral descriptions only. It
contains no private prose, no personal name, no source filename and no digest. It also names no location
of the newly measured public exposures, because naming them would amplify them.

## Contents

1. [Headline](#1-headline)
2. [Per-decision counts](#2-per-decision-counts)
3. [What commit 83260ee's "six deferred redactions applied" refers to](#3-what-commit-83260ees-six-deferred-redactions-applied-refers-to)
4. [F14: publication-filter design](#4-f14-publication-filter-design)
5. [F16: listing-boundary gate design](#5-f16-listing-boundary-gate-design)
6. [Operator decisions required](#6-operator-decisions-required)
7. [Open questions](#7-open-questions)

## 1. Headline

- **Six of the seven items (F8, F9, F12, F13, F14, F15) were already applied** on 2026-09-03 as one
  operator decision: 84 primary log entries under six reason codes. **F16 was never applied**, because it is
  a listing boundary and has no passage id.
- **That application resolved transcript line numbers against the wrong axis.** The review cites
  `transcript.md` file lines. The application instead selected registry rows whose `source_ref.line_start`
  equalled those numbers, and for transcript segments that field is the segment ordinal. Every transcript
  pick is therefore displaced: it lands on segment index = cited line − 1. The exercise-document picks used
  real line ranges and are correct.
- **Consequences, measured:**
  - **F15**'s transcript-side core (2 passages) and 3 rows derived from it are still unwithheld.
  - **F9**'s core happens to be withheld through another decision's displaced range, but 8 derived index
    and section rows are still unwithheld.
  - F8, F12 and F13 turn out to be fully covered by earlier name-level withholdings, or by later batches.
- **F16 breaches, measured today:**
  - (a) one live listing surface on the private deployment exposes the source filenames to an
    unauthenticated request;
  - (b) the notes-document filename has reached **2 tracked, already-pushed files** of this public
    repository.
- **A separate public name-class exposure was also measured:** a participant-name token occurs in **26
  tracked files** of this repository, used as an account handle. The 2026-09-02 review measured zero for
  the same probe. Whether it denotes the same person is **UNCONFIRMED**.
- **The 12 pids recorded earlier are consistent.** 10 are withheld as decided. 2 are instructor-only and
  are KEEP, as decided.

## 2. Per-decision counts

"Touched" counts every transcript segment on a cited line, plus every overlapping exercise section.
"Withheld" means the pid is in the redaction log at private HEAD. "Displaced" counts the 2026-09-03 picks
that fall outside the cited lines.

| Decision | Reason class | Touched | Already withheld | Required to add | Optional | Derived rows to add | Displaced picks |
|---|---|---:|---:|---:|---:|---:|---:|
| F8 | indirect identifier, operational name | 13 | 3 | 0 | 0 | 0 | 2 |
| F9 | client-engagement fingerprint | 43 | 18 | 0 | 1 (span) | 8 | 4 |
| F12 | third-party commercial strategy | 54 | 17 | 0 | 1 | 0 | 3 |
| F13 | third-party commercial terms, second-hand | 6 | 2 | 0 | 0 | 0 | 1 |
| F15 | third-party proprietary leak admission | 13 | 1 | **2** (1 pid + 1 span) | 0 | **3** | 1 |
| F14 | own unreleased commercial plan | 164 | 67 | — (private-only tier) | 18 | — | 63 |
| F16 | source recording filenames | n/a (no pid) | — | gate + 9 index rows whose source path carries a filename | — | — | — |

Measurement notes:
- **How lines were mapped to segments.** The line-to-segment map was built at the pre-application content.
  It reproduces 10 of 10 line ↔ segment anchors stated in the original review.
- **Earlier figures.** An earlier agent's figures (F8 8, F9 19, F12 11, F13 5, F15 5, F14 215) were not
  reproduced, and their method is unknown.
- **Span offsets.** Offsets are given in the private proposal. The existing redaction tool supports
  whole-line spans of non-passage files only, so sub-passage spans need a new mechanism or a pid-level
  fallback.

## 3. What commit 83260ee's "six deferred redactions applied" refers to

- The six are **F8, F9, F12, F13, F14 and F15**, recorded under six distinct reason codes. The application
  took the redaction log to 197 entries over 149 pids. F16 is the seventh and was never pid-addressable.
- **The claim is TRUE about the log and FALSE about coverage**, because of the line-axis defect in §1.

## 4. F14: publication-filter design

**Decision:** "REDACT before publication; KEEP in the private repo".

**Today.**
- The log has a single action, which means withheld everywhere.
- The registry keeps the text of withheld rows (no purge), so the private repository keeps the material.
- Export application did rewrite the private rendered chapter documents, so "keep" holds for the registry
  only.

**Proposal.**
1. **A consumer-owned policy table maps each reason code to an audience.** The audiences are
   `withheld_everywhere` (the default, and the value for every reason in use today) and `private_only`.
   `private_only` means served only to an authenticated owner role on the private deployment, and excluded
   from every export, publish step, public mirror, unauthenticated route and derived index. The append-only
   log schema stays unchanged. A missing or unknown entry falls back to `withheld_everywhere`
   (fail-closed).
2. **F14's reason maps to `private_only`.** Its 69 existing entries and the 18 proposed additions inherit
   it. Derived rows stay `withheld_everywhere`, because their source reason is not recorded.
3. **The filter is applied at four choke points:** the passage-store read path, the export renderer, the
   static-file guard's suppression index, and any publish or umbrella-bound pipeline.
4. **Optional:** a private-only render of the chapter documents, so that "keep in the private repo" is
   literal.

**Affected served surfaces (code-enumerated, not runtime-verified).**
- 24 passage-bearing GET routes;
- the answering route, when enabled;
- 3 offline render families;
- every publish or umbrella-bound path.

**Paired proof.**
- A fixture row under a `private_only` reason must be 200 for the owner. It must be withheld for an
  anonymous session, for a non-owner role, in every export, and in the publish render.
- Mutations that must each turn it red:
  - dropping the policy row (the row must stay withheld: fail-closed);
  - flipping the audience;
  - bypassing the export choke point;
  - mis-spelling the reason.

## 5. F16: listing-boundary gate design

**Probes are derived at run time and never typed.** They come from the chapter source directory:
- the long filename stems and their basenames;
- the opaque material ids of those stems;
- the archive checksum digests;
- the date-time chunk;
- the participant name token.

**Each probe is matched in six variants:** raw, case-folded, Unicode-folded, slugified, URL-encoded and
HTML-escaped.

**Surfaces scanned.**
1. An isolated server instance on a fixture tree. Every static directory route is fetched anonymously and
   with each role. The gate asserts **no directory listing at all**: any directory without an index answers
   404 or 410.
2. Every serialised registry field, including `source_ref.path`, ids, hrefs and titles.
3. Every export and render directory.
4. Logs and evidence, tracked and ignored.
5. The public umbrella's own tracked files, both worktree and HEAD.
6. The private module's tracked listings and manifests. An allowlist covers only the archive mechanism
   itself.

**Output.** Three-valued exit: 0 clean, 1 finding, 2 could not determine. Paths and counts only; matched
text is never printed.

**Mutations (each must turn the gate red).**
- a canary filename in a fixture source path;
- the same canary slugified;
- the canary URL-encoded in an href;
- a re-enabled bare directory listing;
- the canary in an umbrella fixture file;
- a surface removed from the scan roster (caught by a coverage self-check);
- an unreadable source directory (must exit 2, never 0).

The canary-free control must stay green.

**Measured today (counts only).**

| Surface | Result |
|---|---|
| Live private listing surface | 1 route returns all 41 filenames to an unauthenticated request |
| Opaque material ids | 0 public occurrences |
| Filename stem in this public repository | 2 tracked files, already pushed |
| Archive digests in this public repository | 4 tracked files |
| Date-time chunk in this public repository | 10 tracked files |
| Private tracked files carrying a stem | 7 |
| Private ignored backups carrying a stem | 13 |

## 6. Operator decisions required

| Item | Decision |
|---|---|
| F8 | Accept "covered, add 0". Keep or unredact 2 displaced picks. |
| F9 | Approve 8 derived rows (plus 1 ambiguous). Choose pid-level or span-level for the mixed sections. Decide the 1 optional span. Keep or unredact 4 displaced picks. |
| F12 | Decide 1 optional passage. Keep or unredact 3 displaced picks. |
| F13 | Accept "add 0". Keep or unredact 1 displaced pick. |
| F15 | **Approve 2 core additions and 3 derived rows.** This is the only item whose sensitive core is unwithheld today. |
| F14 | Adopt the two-audience policy, as a policy table or as a log field. Approve 18 private-only candidates. Decide on a private-only render. Keep or re-home 63 displaced picks. |
| F16 | **Immediately close the live unauthenticated listing surface.** Approve the gate. Re-path or withhold 9 index rows whose source path carries a filename. |
| Public exposures | **Escalate** the 2 pushed files carrying the filename stem and the 26 files carrying the name token. History rewrite is forbidden (§11.4.113), so only forward edits plus acceptance are available. |
| Line-axis defect | Decide whether to re-run the transcript side of the 2026-09-03 decision against file lines, as a corrective batch. |

## 7. Open questions

1. Sub-passage span suppression does not exist yet. It is needed, or each span falls back to pid-level.
2. The 18-versus-79 split of F14 carriers and context is an agent judgement and is not machine-verified.
3. The 74 displaced picks were not read. Whether they carry sensitive material is **UNDETERMINED**.
4. Reachability of the live listing from other hosts was not tested. Only the all-interfaces bind was
   measured.
5. The original review's coverage boundary (the transcript was not read end to end) still stands.
