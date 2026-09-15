# Feature Specification: Unified Workshop Platform — Curriculum, Knowledge Layer, QA Readiness and Module Decoupling

**Feature Branch**: `008-unified-workshop-platform`

**Created**: 2026-09-15

**Status**: Draft

**Supersedes**: `specs/001-workshop-curriculum-platform/`, `specs/002-knowledge-areas-deep-linking/`,
`specs/003-chapter-hierarchy/`, `specs/004-authored-ai-areas/`, `specs/005-clone-and-clear-red/`,
`specs/006-session-record-and-qa-readiness/`, `specs/007-decouple-modules-auth/`. All seven remain in
the tree, unmodified except for a supersession notice at the top of their `spec.md` and `tasks.md`,
because their Clarifications, Amendments, Resolved Decisions and withdrawn-claim records are
history this document inherits rather than replaces. **Where this document and a source document
disagree, this document governs** — every such disagreement is recorded, with its reason, in
*Clarifications → Session 2026-09-15 (merge pass)* below. A full contribution map is in
*Supersession Map* at the end.

---

## Input / mission summary

This specification merges seven previously-independent SpecKit features into one internally
consistent document. It does not add a new mission; it states the single mission the seven were
already describing in pieces:

> Turn a private, recorded teaching workshop into a curriculum platform a person can learn from —
> a faithful transcript, a chapter hierarchy that survives sub-chapters, authored AI/IT knowledge
> areas with lessons, provenanced assessments and video deep links, meaning-based search over every
> content kind, grounded question answering, a complete cumulative session record per chapter, and
> an end-to-end manually-testable state a QA team and a client can be walked through — all of it
> obtainable by a second engineer, all of it evidenced by three-valued machine checks with paired
> mutation proofs, and none of it bluffing. Then decouple it: `workshop` and `ai_interviewing`
> become standalone, independently cloneable, independently deployable modules with their own
> authentication and their own user-bound progress, consuming shared code as public submodules
> rather than as umbrella siblings.

The seven source specifications were written between 2026-08-31 and 2026-09-12, each numbering its
own requirements from `FR-001`, its own success criteria from `SC-001`, and its own tasks from
`T001`. **Seven different `FR-001`s existed.** That collision is the direct reason this merge was
authorised: no reader could cite a requirement unambiguously, and no single document stated what
the platform is supposed to be.

**Two architectures are specified here, both to full depth.** Specifications 001, 002, 003, 004 and
006 describe capabilities of one system — `workshop`, living inside the `vasic` umbrella — and that
is the system that exists today. Specification 007 describes a different arrangement of the same
capabilities: two standalone modules outside the umbrella, each with its own authentication. That
is a migration target, not today's architecture, and this document does not blur the two. Part I is
the baseline. Part II is the target. Part III is the migration path connecting them. Specification
005's work divides across both, and every 005-derived requirement says which state it serves.

---

## Context: what is measured, and what is dated

Every figure this document carries is a **dated observation from the source specification it came
from**, not a live measurement taken during this merge. **No figure below was re-measured on
2026-09-15**, and several are known to have moved — spec 003 records its own starting-state table
going stale within hours of being written, and spec 006 records a row that was wrong in an
instructive way and was corrected rather than quietly rewritten.

**Re-derive before relying on any number here.** The source specifications carry the re-derivation
commands; this document carries the figures only so the requirements below are meaningful against
something.

### Baseline starting state, as the source specs measured it

| Fact | Measured value | First recorded in |
|---|---|---|
| Chapter 1 source recording | one screen recording, **1.8 GB**, stored as **36 × 50 MB** `tar.gz` parts plus a SHA-256 manifest; the whole file is git-ignored | 001, 2026-08-31 |
| Supporting material for chapter 1 | one AI-generated notes PDF, **412 KB** | 001, 2026-08-31 |
| Existing transcript at 001's start | **none** | 001, 2026-08-31 |
| Chapters present | **1** → **3** (`01`, `02`, `02.01`; `02.01` is the first sub-chapter) | 001 → 003, 2026-09-05 |
| Passages in the corpus | **1,101** — 1,055 transcript segments, 44 document sections, 2 code passages | 002, 2026-09-01 |
| Passages flagged uncertain | **267** (24.2%) | 002, 2026-09-01 |
| Segment timing granularity | median **6.74 s**, p95 **10.78 s**, max **20.22 s** over 1,055 segments | 002, 2026-09-01 |
| Word-level timings | **present**, in a per-chapter sidecar, **not** in the registry: 15,610 word records, 2,717 (17.4%) below the confidence threshold | 002, 2026-09-01 (after a withdrawn "absent" claim) |
| Passage registry total | **13,141** records → **13,183** within the same session | 003, 2026-09-05 |
| Distinct chapter scopes in the registry | **1** (`01`, 1,819 records) → **2** (`01` 1,819 and `02.01` 42) within the same session | 003, 2026-09-05 |
| Knowledge areas with machine-readable form | **0** at 002's start; **5** existed as prose only, with no identifier, schema or endpoint | 002, 2026-09-01 |
| Extracted taxonomy (landed during 002's drafting) | **7 tracks, 37 modules, 137 terms**; linkage for all 1,101 passages; coverage 884/1,055 passages (83.79%) and 14,290/15,610 words (91.54%) | 002, 2026-09-01 |
| Published areas that are mined single terms | **814 of 819**; topical classifier scored **3.9%** AI/IT-relevant | 004, 2026-09-07 |
| Catalogue / detail disagreement | list serves **819**, detail route refuses **817** as not published | 004, 2026-09-07 |
| Lessons and tests | lessons and assessment routes returned **not-found for every area** | 004, 2026-09-07 |
| Authored lessons carrying teaching content | **339 authored, 0 with any body/content/text field** at source or served | 006, 2026-09-08 |
| Areas — disk versus wire, same moment | **on disk 42 areas / 30 with an assessment / 224 questions**; **on the wire 39 / 14 / 116**, and not one stating why | 006, 2026-09-08 |
| Learning surface reachability | the learning client never sent the required session header; both learning panels rendered an error card on **every** area page | 006, 2026-09-08 |
| Chapters carrying any of the four session sections | **0 of 3** | 006, 2026-09-08 |
| Documents failing publication review | **3**, with **62, 54 and 58** uncited claim blocks | 005 and 006, 2026-09-08 |
| Hue families painted on principal surfaces | **2**, against a floor of 6 | 005, 2026-09-08 |
| Repository obtainability | **54 tracked archive parts, 2,624.8 MB**; pack **1.76 GiB**; a second engineer's clone failed | 005, 2026-09-08 |
| Fleet instruments reporting red | **11** | 005, 2026-09-08 |
| Generative model on the development host | **none at 002's measurement** (two embedding models only); a 3B instruct model was pulled later and wired into the platform's answer path | 002, 2026-09-01 |

### Three facts that are load-bearing and easy to misread

1. **The platform is not starting from zero and is not starting from data either.** Five knowledge
   areas existed as prose before any of this work; a taxonomy of 7 tracks / 37 modules / 137 terms
   landed while spec 002 was being drafted; 339 lessons were authored with no body field to hold
   their content. The work is to promote, reconcile and complete — not to invent against an empty
   page, and not to rewrite what already exists.
2. **A measurement of SOURCE is not evidence about the SERVED product.** This is the single most
   repeated defect across the seven specs: spec 004 recorded it as D6 and again as D8, spec 006
   recorded it as the root cause of the platform's largest live defect and noted the same mistake
   had by then occurred four times, and spec 006's own S4 row made the mistake and was corrected in
   place. Every interface claim in this document must cite what was served, not what was on disk.
3. **Four of the five layers a dotted chapter id has to survive already survive it.** Spec 003
   measured this rather than assuming it: the slug allowlist permits `.`, the directory resolver
   already resolves `chapter-02.01`, the route wildcard is single-segment, and the client's URL
   encoder leaves `.` unescaped. The hierarchy work is therefore much smaller than "add hierarchy
   support" — the part that is wrong is **derivation**, not identity, routing or filesystem.

### Content boundary — binding on this document

`workshop`, `ai_interviewing` and `monetization` are **PRIVATE** submodules; this repository and
this specification directory are **PUBLIC**. Nothing in this document quotes private content.
Areas, terms, questions, transcript text, participant names and recording filenames are referred to
by **shape, count and location only**. A single pasted line would be a permanent, irreversible
disclosure — this repository has an on-the-record incident of exactly that
(`docs/content-boundary-incident-2026-09-01.md`), and the same discipline every source spec applied
applies here without exception.
---

## Part I — Baseline Architecture: the integrated umbrella platform

**This is what exists today.** It is described as the primary architecture because it is reality,
not aspiration: specifications 001, 002, 003, 004 and 006 all describe capabilities of one running
system, and specification 005's obtainability and red-state work is performed against it.

### I.1 Shape

One learning platform, `workshop`, hosted as a private submodule inside the public `vasic`
umbrella, alongside a second private learning module, `ai_interviewing`, which serves as the
structural reference for shape and never as a source of content.

```
vasic/                          PUBLIC umbrella
├── workshop/                   PRIVATE  — the platform this specification is about
│   ├── chapters/<id>/          recorded sessions, archived in size-bounded parts + SHA-256 manifest
│   ├── curriculum/             passage registry, taxonomy, per-chapter knowledge directories
│   ├── pipeline/               transcription, calibration, extraction, authoring
│   ├── platform/backend/       the serving process and its route manifest
│   ├── platform/frontend/      the learner-facing surface
│   ├── platform/gates/         three-valued checks with paired mutation proofs
│   ├── scripts/                ingest, archive, extract, verify
│   └── docs/                   limits, QA and client walkthrough documents
├── ai_interviewing/            PRIVATE  — structural reference only
├── submodules/<name>/          PUBLIC reusables, mounted at the umbrella root
└── specs/                      PUBLIC specification directory (this document)
```

### I.2 The identity spine, and why everything hangs off it

Three identities carry the whole platform, and each is **minted and persisted, never positional and
never content-derived**:

- **Passage identifier** — the smallest addressable unit of source content. Measured to survive both
  a content correction and a structural insertion, 1,101 of 1,101 (002). Every citation, every
  cross-reference, every deep link and every question's provenance resolves through it. **A
  timestamp is never a join key** — it survives neither a re-cut nor a re-transcription.
- **Area / term / lesson-section / question / mention identifiers** — the knowledge layer's own
  identities, taking the same discipline wholesale rather than inventing a weaker scheme for the
  things that point at passages.
- **Chapter identifier** — the one exception, and deliberately so: it is **not** a minted
  identifier. It is the dotted, zero-padded numeric path (`01`, `02`, `02.01`), and that single
  string serves unchanged as the directory name, the URL path segment, the registry scope value, the
  `chapter_slug` and the suffix of a `chapter-<id>` curriculum directory. Hierarchy is **derived**
  from it by string operation and is **never stored**, because a stored `parent_id` is a second
  source of truth about structure and two facts that can disagree have no symptom until something
  navigates.

### I.3 The layers

| Layer | What it holds | Governing requirements |
|---|---|---|
| **Source material** | recordings (split, hash-manifested, git-ignored whole), notes documents, supporting assets | FR-001 – FR-009 |
| **Chapter hierarchy** | the dotted id, its grammar, its validator, its derived hierarchy view | FR-015 – FR-054 |
| **Transcript & passage registry** | timestamped, optionally speaker-attributed, confidence-marked passages with minted identifiers, in two layers — immutable machine output and an optional human correction layer | FR-001 – FR-005, FR-010 – FR-013 |
| **Knowledge layer** | authored AI/IT areas, terms, lesson sections, materials, video anchors, question banks with mandatory provenance | FR-063 – FR-134, FR-183 – FR-191 |
| **Session record** | per chapter: meeting notes, open questions, TODO, next meeting — cumulative over all prior sessions, with derived carry-forward | FR-192 – FR-205 |
| **Navigation & resolution** | one shared resolution path with four outcomes; every relationship traversable in both directions | FR-135 – FR-153 |
| **Search & answering** | meaning-based search over every content kind with a resolving locus; grounded answering with citations and a refusal path | FR-154 – FR-173 |
| **Presentation** | the learning surface, its palette, its accessibility floor | FR-224 – FR-240 |
| **Obtainability & red-state** | how the repository is obtained, and how a red is classified | FR-241 – FR-258 |
| **Evidence & governance** | three-valued checks, paired mutation proofs, the content boundary | FR-259 – FR-280 |

### I.4 Serving discipline, stated as architecture because it is where the platform fails

The serving process reads its catalogue **once at start**, deliberately and documentedly. That is
not a defect. The defect is what it then does with the snapshot: it answered a determined negative
about on-disk state — *"this area's catalogue carries no end-of-area test"* — from a snapshot taken
hours earlier. The 14 areas that worked had banks written before the process started; the 13 that
failed had banks written after it. **The discriminating condition was time.**

The architectural rule that follows is not "reload constantly". It is:

> **A process may only assert what its snapshot licenses.** A snapshot licenses claims about the
> snapshot, never about the directory. Where staleness is possible, the honest answer is
> could-not-determine, naming what changed.

This is FR-267 and it is a load-bearing element of the baseline architecture, not a bug fix.

### I.5 Publication, stated as architecture for the same reason

**Listing and openability are one condition, computed in exactly one place.** The measured cause of
the 819-listed / 817-refused disagreement was two implementations that shared their reason strings
and differed in their *sequence of tests*, each passing its own unit tests because nothing asserted
the pair. Sharing a vocabulary of reasons between separately-implemented decisions does not satisfy
this. This is FR-127 and FR-128.

### I.6 Access, in the baseline

Learners are **anonymous, per browser**. There is no sign-in. Test gating is enforced **where the
content is served**, by withholding the question bank — never by trusting the client, so a tampered
client can reveal only that it has tampered. The platform is **local and internal only**: it is not
published to the public internet, and any access from other than the operator's own loopback
interface requires authentication before recording, transcript or search content is served.

**This is the single largest difference between Part I and Part II**, and Part III states how the
transition is made without silently discarding a learner's existing per-browser progress.
---

## Part II — Target Architecture: Module Decoupling Migration

**This is not today's architecture and nothing in Part I depends on it.** It is specified to the
same depth as Part I because it is a decided direction with its own requirements, its own edge
cases, its own success criteria and its own open questions — not a footnote to the baseline. It
originates in specification 007, and specification 004's User Story 6 (*"each learning module runs
on its own"*, spec 004's FR-024/FR-025) is the same goal stated one spec earlier at a lower priority; the two
are merged here rather than duplicated.

### II.1 Shape

Two standalone repositories, each cloneable and runnable by a user with **no access to the `vasic`
umbrella**, each consuming shared code as public submodules rather than as umbrella siblings.

```
Projects/
├── vasic/                      PUBLIC umbrella — no longer hosts either module's operative copy
├── workshop/                   standalone repository
│   ├── .gitmodules             declares every dependency it needs, resolvable without vasic
│   ├── submodules/<name>/      PUBLIC reusables under vasic-digital, mounted at this root
│   ├── install / test scripts  resolve no vasic path
│   └── auth/                   login surface + module-scoped sessions
├── ai_interviewing/            standalone repository (user-facing name: ai_curriculum)
│   ├── .gitmodules
│   ├── submodules/<name>/
│   ├── install / test scripts
│   └── auth/                   login surface + module-scoped sessions + RBAC
└── <shared user store>         an independently-provisionable component — see OQ-9
```

### II.2 What changes, stated as a delta rather than a restatement

| Dimension | Baseline (Part I) | Target (Part II) |
|---|---|---|
| Location | `workshop/` and `ai_interviewing/` are submodules of `vasic` | two standalone repositories outside the umbrella |
| Obtainability | requires the umbrella, or knowledge of it | a clone + a documented bootstrap, on a machine that has never held the umbrella |
| Dependencies | resolved through the umbrella's `submodules/` and its `helix-deps.yaml` | resolved through each module's **own** `.gitmodules`, from PUBLIC repositories under `vasic-digital` |
| Access | anonymous, per browser; local/internal; authentication beyond loopback | **no content without authentication**; database-backed users; sign out and account switch |
| Authorization | none — every learner sees every published area | role-based: on `workshop` both seed users are equal and full; on `ai_interviewing` one user is denied employer information and GitHub-project analysis by **default-deny** |
| Progress | per browser, anonymous, not durable across devices | per user, persisted in the database, surviving session and restart |
| Session identity | not applicable | module-scoped (audience-restricted) tokens; a `workshop` token is rejected by `ai_interviewing` and vice versa, even though both read one user store |
| Enforcement | local pre-push gates; no server-side CI | **unchanged** — see the CI/CD resolution in *Clarifications → merge pass → C1* |
| Reusables | `submodules/<name>` under the umbrella root | the same repositories, mounted at each standalone module's own root |

### II.3 The authorization model, in full

**The seed set is two users and two modules**, and the four cells are not symmetric:

| | `workshop` | `ai_interviewing` |
|---|---|---|
| `milosvasic` | full access to every feature and every datum | full access to every feature and every datum |
| `rami` | full access, **equal to** `milosvasic` | knowledge base only — areas, lessons, tests, exercises, progress. **Denied** employer information and GitHub-project analysis |

Four properties of that table are requirements rather than descriptions:

1. **Default-deny, not default-allow.** "Employer information" and "GitHub project analysis" are
   named informally, not as a closed list of tables, fields and routes. Enumerating what is denied
   would guarantee a missed path. Therefore anything not explicitly on the allow-list is denied for
   `rami` on `ai_interviewing`, and a user record with **no** assigned role gets **zero** access —
   never admin-equivalent, never inherited from whatever the previous session on that browser had.
2. **Audience-scoped tokens.** Both modules read the same user table, so proving *"this is rami"* is
   not sufficient — the token must also prove *"for this module"*, or a `rami` session obtained on
   `workshop` (full access) is replayable against `ai_interviewing` to reach exactly the data the
   table denies. This is a privilege-escalation path **created by the decoupling itself**.
3. **Fail closed.** On auth-provider or user-database unavailability, access is denied. An
   availability failure must never become an accidental all-access window.
4. **Designed for refinement.** The permission model is a `(user, module, resource, action)` rule
   set from the start, because exhaustive refinement of access levels is anticipated. A two-user,
   two-module hard-coding would have to be thrown away.

### II.4 Credential posture, stated plainly because it is the highest-severity finding in the family

Specification 007 recorded two plaintext passwords directly in its `FR-009`, in a **public**
repository. Those values are in git history and history is not editable after a push. They are
therefore **compromised from the moment of commit**. The target architecture stores only salted
cryptographic hashes, never re-prints a plaintext credential anywhere, and refuses to start a
production-flagged environment while those literal values are still active. **Whether the actually
deployed passwords are rotated is an operator decision** — see OQ-13.

### II.5 Extraction of reusables, and the one thing that makes it dangerous

Reusable code is extracted from the two modules into **public** repositories under `vasic-digital`,
mirrored to GitHub and GitLab, and consumed as submodules mounted at each module's root. Nested
submodules are forbidden; every such repository is public and therefore must contain **zero**
workshop or interviewing content, with synthetic fixtures only.

The danger is not the extraction. It is that `workshop` and `ai_interviewing` sit adjacent to, and
reference, private material. A generic-looking utility pulled out for a new public repository can
still embed a private string, a participant's name, or a developer-host path. **This repository's own
recorded content-boundary incident is the precedent for exactly this failure mode.** Therefore every
extraction passes a content-boundary review confirming zero private data **before** the public
repository is created or pushed — not before it is announced, not before it is consumed: before it
exists publicly.

### II.6 Cutover discipline

Decoupling is **additive-then-cutover, never delete-then-hope**:

- The umbrella-hosted copy of a module remains the operative one until the standalone clone
  independently passes install and the full test suite on its own. **No module is ever left with no
  fully-working copy of itself.**
- A reusable-code extraction preserves a working in-tree path for every existing consumer until each
  consumer is confirmed migrated to, and re-tested against, the extracted public submodule.
- Any session or cookie issued before secure session handling was enforced is invalidated at the
  authentication-rollout cutover. Nothing is grandfathered into "already authenticated".
- Bootstrap of the seed accounts is a privileged, non-network-exposed step — a seed script or
  migration run by an operator, never a self-registration endpoint reachable from the login page.

---

## Part III — The migration path connecting the two states

The two architectures are not alternatives to choose between; they are ordered states, and the
order matters because several baseline requirements are **preconditions** of the target rather than
optional companions to it.

### III.1 The dependency that makes obtainability part of the migration, not just a baseline defect

Specification 005 exists because a second engineer could not clone the private curriculum
repository: **2,624.8 MB across 54 tracked archive parts**, and git's smart-HTTP transport cannot
resume a failed fetch, so a clone that dies at 90% restarts from zero. That is a baseline defect —
work that cannot be obtained cannot be reviewed, run or contributed to.

**It is also a hard precondition of Part II.** A decoupled `workshop` whose whole value proposition
is *"clonable by a user with no access to the umbrella"* cannot ship while cloning it is the thing
that fails. Every 005 obtainability requirement therefore serves **both** states, and says so.

Specification 005's red-state discipline serves both states for a different reason: the target
architecture doubles the number of repositories carrying gates, and a fleet summary that cannot
separate a defect from a declared condition becomes less readable, not more, as the fleet grows.

### III.2 Ordered gates on the migration

| # | Gate | Why it precedes what follows |
|---|---|---|
| **M0** | ✅ **SATISFIED 2026-09-15.** The chapter-`ordinal` type decision and the path-key contradiction are resolved (OQ-3) | Was: every ordinal collision in the hierarchy follows from one line typing `Chapter.ordinal` as `int`; no implementation resolves it and nothing downstream is implementable until it is settled. **Now**: the decision was already made and partially implemented (2026-09-13, `specs/003-chapter-hierarchy/decision-record.md`, predating this merge) — `ordinal_path` is canonical, `ordinal` stays for compatibility. Remaining downstream work (T176/T177/T184 and siblings) proceeds as ordinary implementation work, no longer gated on a decision. |
| **M1** | Repository obtainability meets FR-241 – FR-247 | A standalone module that cannot be cloned is not standalone. |
| **M2** | The platform reaches manual-QA readiness against the **baseline** (FR-206 – FR-217) | This is the operator's stated absolute priority, and it is the only point at which a second party can check that the capabilities Part II is about to move actually work. See OQ-15 for the one open question about *which* state the QA document is written against. |
| **M3** | Each module's dependencies resolve from its own `.gitmodules`, from public repositories | Extraction must complete before the umbrella copy can stop being the operative one. |
| **M4** | Each standalone clone independently passes install and the full test suite | FR-328: the decommission gate. Until M4, the umbrella copy remains operative. |
| **M5** | Authentication, RBAC, module-scoped sessions and user-bound progress are live on both modules | Part II's access model. |
| **M6** | Cutover: pre-rollout sessions invalidated, anonymous per-browser progress explicitly handled (FR-321), umbrella copies decommissioned | The only irreversible step, and the only one that may not be started before M4 passes. |

### III.3 What the migration does **not** change

- **The content boundary.** Private material stays private in both states. The target architecture
  *adds* disclosure surfaces (new public repositories, exported documents, OCR output, QA evidence
  artefacts) and each is gated; it removes none of the existing protections.
- **The no-server-side-CI rule.** See C1 in the merge Clarifications: specification 007's FR-006
  asked for provider-side CI/CD on both standalone modules, and it is resolved **against**, because
  a specification may not weaken an inherited governing rule.
- **The evidence discipline.** Three-valued checks, paired mutation proofs driven by data rather
  than by altering the check, and could-not-determine never recorded as a pass — identical in both
  states.
- **History.** No published history is rewritten, in any repository, in either state.
---

## User Scenarios & Testing *(mandatory)*

Forty user stories existed across the seven source specifications. They are unified here into
**33** — eight merges where two specs described one journey, and no deletions. Every story carries a
back-reference to its origin. Priorities are reconciled: where two source stories describing the
same journey carried different priorities, the **more urgent** of the two is taken, and the reason
is stated. Target-architecture stories carry a `T-` prefix on their priority so a reader cannot
mistake a migration story for a baseline one.

**One priority reordering is deliberate and is stated rather than performed silently.** Story 2
(manual QA readiness) was `006/US3` at P1 among five stories in its own document; here it is placed
second overall because the operator has repeatedly identified getting the platform to a fully
manually-QA-ready state as the most critical and absolute priority. Only obtainability precedes it,
because a platform nobody can obtain cannot be handed to a tester.

### BASELINE — the integrated umbrella platform

---

#### User Story 1 — A second engineer obtains the repository (Priority: P1) 🎯 MVP
*(was: 005/US1)*

An engineer on a different machine clones the curriculum repository, follows its own written setup,
and reaches a state its status command calls ready — without special flags, private knowledge, or a
message to the author.

**Why this priority**: nothing else in this specification is deliverable to anyone who cannot obtain
the repository. It is the only red that blocks *other people* rather than degrading a signal, and it
is additionally a hard precondition of Part II — see Part III, M1.

**Independent Test**: clone into an empty directory on a machine that has never held this work, run
the documented bootstrap, and read the status output.

**Acceptance Scenarios**:

1. **Given** a machine with no prior copy, **When** the engineer clones by the documented command, **Then** the clone completes without a transport error.
2. **Given** the clone, **When** they run the documented bootstrap, **Then** it obtains every dependency it needs, or names precisely what is missing and the exact command to obtain it.
3. **Given** a chapter's recorded material, **When** they follow the documented step to obtain it, **Then** they get the recording, or a stated reason it is unavailable to them.
4. **Given** the documented clone command, **When** a reader looks for it, **Then** it is in the repository's own front-door documentation, not in a chat message.
5. **Given** the repository over time, **When** its size approaches the point where clones fail, **Then** something says so **before** a person discovers it by failing to clone.

---

#### User Story 2 — A QA team can test the platform manually, end to end (Priority: P1) 🎯 MVP
*(was: 006/US3)*

A tester who has never seen the platform is handed one document, follows it, and exercises every
feature and flow — knowing for each step what a correct result looks like and how to report a wrong
one.

**Why this priority**: the operator's stated goal, repeatedly identified as the most critical and
absolute priority of this specification family. It also converts every other claim in this document
from an assertion into something a second party can check.

**Independent Test**: hand the document to someone unfamiliar with the platform and have them
complete it without asking a question.

**Acceptance Scenarios**:

1. **Given** the QA document, **When** a tester follows it, **Then** every feature and flow is covered, each with its expected result stated before the tester performs it.
2. **Given** any step, **When** the observed result differs from the expected one, **Then** the document says how to report it and what information to capture.
3. **Given** a capability that is deliberately absent or limited, **When** a tester reaches it, **Then** the document says so in advance — **a tester must never discover a known limitation as if it were a defect**.
4. **Given** the platform, **When** a tester begins, **Then** getting to a testable state requires only the documented steps.
5. **Given** a single tester acting alone, **When** they work through the document, **Then** every scenario is completable without a second person.
6. **Given** the platform is unreachable when a session begins, **When** the tester attempts to start, **Then** it is a blocking precondition failure recorded as "environment unavailable" — no unreachable step is recorded as passed.
7. **Given** a session interrupted before completion, **When** the tester resumes, **Then** they resume from the last completed, evidenced step rather than restarting from zero.
8. **Given** evidence capture fails for a step, **When** the result is recorded, **Then** it is observed-but-unevidenced — a could-not-determine — never satisfied because the tester watched it happen.

---

#### User Story 3 — Read what was actually said in a workshop chapter (Priority: P1)
*(was: 001/US1)*

A learner who could not attend the session opens the curriculum and reads the chapter as a
structured written document. They follow the whole exercise end to end in text, see who said what,
and jump from any passage to the exact moment in the recording it came from.

**Why this priority**: search, cross-linking, question-answering, the knowledge layer and the
session record are all built on top of a faithful written record. Without it the knowledge is locked
inside a recording nobody can grep, quote or link to.

**Independent Test**: deliver only the transcript and its verification report. A reviewer reads the
chapter in full, picks any five passages at random, and confirms against the recording that each is
accurate and that its stated timestamp lands on the corresponding moment.

**Acceptance Scenarios**:

1. **Given** a chapter's recording and its notes document, **When** transcription runs, **Then** a transcript is produced covering the entire recording with no unexplained gaps.
2. **Given** a transcript, **When** a reader selects any passage, **Then** it carries a timestamp locating it within the recording to within a few seconds.
3. **Given** a transcript, **When** accuracy verification runs, **Then** it reports a measured figure derived from a sampled comparison against the source audio, rather than asserting correctness without evidence.
4. **Given** segments where speech is unclear or inaudible, **When** the transcript is produced, **Then** those segments are explicitly marked uncertain rather than silently guessed at or omitted.
5. **Given** a complete transcript, **When** a reader looks for the topics covered, **Then** it is organised into navigable sections rather than one undifferentiated block.

---

#### User Story 4 — A participant reads what a session produced (Priority: P1)
*(was: 006/US1)*

Someone who attended, or missed, a working session opens that chapter and reads four things: what
was discussed, what is still open, what must be done, and what the next session will cover. Each is
real content about that session, not a placeholder.

**Why this priority**: the operator's stated requirement and the thing whose absence is most
visible — measured at **0 of 3 chapters** carrying any of the four sections. It is also what makes a
chapter presentable to a client, and a QA team handed a chapter with four empty sections cannot tell
whether the sections are broken or simply unwritten.

**Independent Test**: open each chapter and read all four sections. Value is delivered if every
section contains content specific to that session and none is empty or generic.

**Acceptance Scenarios**:

1. **Given** any chapter, **When** a participant opens it, **Then** all four sections are present and each contains content specific to that session.
2. **Given** a chapter's record, **When** a participant reads it, **Then** it reflects that session **and every session before it** — a question opened earlier and still unresolved appears as open.
3. **Given** an item in any section, **When** a participant reads it, **Then** they can tell which session it originated in.
4. **Given** a section with genuinely nothing to report, **When** it is presented, **Then** it says so explicitly with the reason — an empty section and an unwritten section are never indistinguishable.

---

#### User Story 5 — A planned point that slipped is visibly carried forward (Priority: P1)
*(was: 006/US2)*

A point planned for a session and not covered appears in the **next** chapter's plan, re-planned,
and marked so a reader sees at a glance that it slipped rather than being newly raised.

**Why this priority**: shares P1 with Story 4 because a session record without carry-forward is a
record that quietly loses commitments — the precise failure the operator asked to prevent.

**Independent Test**: take a point planned for one session and not covered; confirm it appears in
the next chapter, marked as carried over, with its origin visible.

**Acceptance Scenarios**:

1. **Given** a point planned for a session, **When** the session did not cover it, **Then** it appears in the next chapter's plan.
2. **Given** a carried-forward point, **When** a reader sees it, **Then** it is **visually distinguished** from a point raised for the first time.
3. **Given** a point carried forward more than once, **When** a reader sees it, **Then** how many times it has slipped is visible.
4. **Given** a session's plan, **When** the record is assembled, **Then** every planned point is accounted for as covered, carried forward, or explicitly dropped with a reason — **no planned point may simply vanish**.
5. **Given** the most recent chapter, **When** points carry forward from it, **Then** they land somewhere a reader can find them even though no later chapter exists yet.

---

#### User Story 6 — A sub-chapter is a chapter (Priority: P1)
*(was: 003/US1)*

A maintainer adds a two-level chapter directory and expects the platform to treat it as a chapter:
listed, addressable, orderable, ingestible, searchable — without a single line of code that asks
whether it is a sub-chapter.

**Why this priority**: it is the whole hierarchy capability; Stories 7, 8, 16 and 21 are its
consequences. It went live the day the first sub-chapter directory was added, and three defects that
were latent with one chapter became real with three.

**Independent Test**: create a chapter directory named with a two-level id, run the pipeline, and
confirm it appears in the list, resolves at its own URL, sorts in the right place, and carries no
special-cased handling anywhere in its path.

**Acceptance Scenarios**:

1. **Given** a two-level chapter directory exists, **When** a client calls the chapter list, **Then** the entry appears with its dotted id, its parent, a depth of 2, and an ordinal path that does not collide with its parent's.
2. **Given** the same, **When** a client requests that chapter directly, **Then** it resolves — the route wildcard is single-segment and the id contains no path separator.
3. **Given** a mixed set of top-level and nested ids, **When** any of them is listed, globbed or read from disk, **Then** the three orders are identical and a child falls immediately after its parent.
4. **Given** the codebase, **When** it is searched for a branch conditioned on a chapter's depth, **Then** none is found.

---

#### User Story 7 — Nothing is silently dropped (Priority: P1)
*(was: 003/US2)*

A maintainer runs the extraction, ingestion and authoring stages over a tree containing a
sub-chapter, and every stage either processes it or says, by name, that it did not.

**Why this priority**: also P1, for a stated reason — the two pattern defects already fixed did not
fail. They exited `0`. A pipeline that drops a chapter silently is worse than one that refuses to
run, because the refusal is a fact and the silence is a false one.

**Independent Test**: run every stage against a tree holding a sub-chapter with no content of its
own, and assert the sub-chapter is named in each stage's output — as processed, or as skipped with a
reason.

**Acceptance Scenarios**:

1. **Given** a chapter directory whose name does not match the id grammar, **When** any stage enumerates chapters, **Then** it is reported as `unclassified` with a stated reason and is never omitted from the enumeration.
2. **Given** a sub-chapter with no transcript, **When** ingestion runs without an explicit transcript argument, **Then** it **refuses**, naming the missing input — it does **not** fall back to another chapter's transcript.
3. **Given** any stage that filters chapter paths by pattern, **When** the pattern fails to match a directory that exists, **Then** the non-match is reported rather than skipped silently.

---

#### User Story 8 — Every chapter-scope comparison names exactly one chapter (Priority: P1)
*(was: 003/US3)*

An operator runs a redaction review for one chapter and gets that chapter's artifacts — not a
sub-chapter's, and not that chapter's plus everything whose id happens to end in the same digits.

**Why this priority**: P1, and the reason is disclosure control. A suffix comparison produced a
disclosure-control record that claimed more coverage than it had. The fix has landed; the test that
can see the defect has not, and a fix without one is a fix that reverts the first time somebody
finds the comparison inconvenient.

**Independent Test**: build a fixture registry holding **two** scopes, one a sub-chapter of the
other, run the redaction review for the parent, and assert the sub-chapter's artifacts are absent.

**Acceptance Scenarios**:

1. **Given** a registry with a parent scope and a sub-chapter scope, **When** the review runs for the parent, **Then** exactly the parent's artifacts are covered.
2. **Given** the same fixture, **When** the comparison is mutated back to a suffix test, **Then** the test goes red.
3. **Given** a **one**-scope fixture, **When** the same mutation is applied, **Then** the test stays green — which is the measurement that proves a one-scope fixture cannot guard this.

---

#### User Story 9 — A reader can tell a finding from a designed state (Priority: P1)
*(was: 005/US2)*

Someone runs the fleet's instruments and, for every red, can immediately tell whether it is a defect
to fix, a known condition with a recorded reason, or a check that could not run — and what to do
next in each case.

**Why this priority**: a list of eleven reds where most are permanent is a list nobody reads, and
the reds that *are* defects then hide inside it. This is the difference between a gate suite that
protects the work and one that decorates it. It becomes more load-bearing, not less, in Part II,
where the number of repositories carrying gates doubles.

**Independent Test**: run every instrument, and for each red answer three questions from its output
alone: is this a defect, what is the evidence, what happens next.

**Acceptance Scenarios**:

1. **Given** any instrument reporting red, **When** a reader reads its output, **Then** it states whether the red is a defect, a declared condition, or an unrunnable check.
2. **Given** a declared condition, **When** a reader reads it, **Then** it carries the evidence and the reason it is declared, and names who may lift it.
3. **Given** a check that could not run, **When** it reports, **Then** it is distinguishable from both a pass and a failure, and it is **never** recorded as a pass.
4. **Given** the full suite, **When** it is run, **Then** a single summary states how many reds are defects and how many are declared, and those two counts are never merged.
5. **Given** an instrument that reports clean, **When** the summary is assembled, **Then** it still appears, at zero — silence is never misread as "not yet run".
6. **Given** a red previously closed, **When** new evidence contradicts the closure, **Then** reopening is itself a recorded event carrying the contradicting evidence and when it was found.

---

#### User Story 10 — A learner finds a subject they recognise (Priority: P1)
*(was: 004/US1, 002/US1 — MERGED)*

A learner opens the knowledge catalogue and sees a list of named AI and IT subjects — each with a
human-readable title, a one-paragraph summary, and tags describing its domain and difficulty. Every
entry they can see is an entry they can open, and every claim in an area's materials points back to
the moment in the workshop where it was actually taught.

**Why this priority**: both source stories were P1 for the same reason stated two ways. `004/US1`:
while the catalogue shows opaque identifiers and refuses to open most of them, no other capability
is reachable. `002/US1`: without a knowledge layer the platform remains a media viewer — measured as
0 areas, 0 area materials and a 404 on the area endpoint. **They are one story**: a catalogue that is
honest about what it holds, whose entries are authored subjects rather than mined vocabulary, and
whose materials are evidenced.

**Independent Test**: open the catalogue, read every visible entry, and open each one. Then pick any
five areas at random and confirm each has materials in the reference skeleton and that every
substantive claim carries a citation that resolves.

**Acceptance Scenarios**:

1. **Given** the catalogue is served, **When** a learner views the area list, **Then** every entry shows a title composed of words rather than an opaque identifier.
2. **Given** the catalogue is served, **When** a learner opens any entry from the list, **Then** the detail view loads and never reports that the entry does not exist.
3. **Given** the catalogue is served, **When** a learner reads any entry, **Then** it shows a summary and at least one tag.
4. **Given** an area exists but is not ready to be shown, **When** the catalogue is assembled, **Then** it does not appear in the list at all — being listed and being openable are the same condition.
5. **Given** the indexed corpus, **When** taxonomy extraction is run, **Then** every area and every term is evidenced by at least one passage, and none exists without evidence.
6. **Given** the extracted taxonomy, **When** a reviewer inspects any area, **Then** it carries a materials document following the reference module's section skeleton.
7. **Given** an area's materials, **When** a reviewer examines any substantive claim, **Then** it carries at least one resolving passage citation, or it is visibly marked as editorial framing rather than as workshop content.
8. **Given** extraction is run a second time on unchanged content, **When** it completes, **Then** the taxonomy is identical and no identifier has changed.
9. **Given** a passage that no area claims, **When** extraction completes, **Then** it is explicitly classified as unattached with a stated reason, rather than silently dropped from the accounting.
10. **Given** a term the extractor recognised with low confidence, **When** it is published, **Then** it is marked uncertain and is not presented as a confidently identified term.

---

#### User Story 11 — A learner works through an area and is tested on it (Priority: P1)
*(was: 004/US2, 002/US4 — MERGED)*

Having opened an area, the learner reads its lessons in order. At the end they take a test built
from senior-level interview questions on that subject, submit answers once, and receive a result
telling them which questions they got right and what the correct answers were. Every question shows
where its answer comes from, and a single action takes them to that moment in the recording and back.

**Why this priority**: `004/US2` was P1 because an area that opens but teaches nothing is the
"no lessons and no tests" defect restated, not a fix for it. `002/US4` was P4 because it sits on top
of areas and the link mechanism. **Resolved to P1**, the more urgent of the two, because the measured
state is *339 authored lessons with zero body content* — the teaching half of this story is not a
later refinement, it is the missing substance, and the provenance half is what distinguishes this
platform from its reference.

**Independent Test**: open one area, read its lessons end to end, take its test, answer deliberately
(some right, some wrong), and check that the score and per-question feedback match what was
answered. Then enumerate every served question, resolve every citation, and confirm none is
unresolvable.

**Acceptance Scenarios**:

1. **Given** a published area, **When** the learner opens it, **Then** they see its lessons listed in a stated order, each with a title and an estimated reading time.
2. **Given** a published area, **When** the learner opens a lesson, **Then** they see its body content and can move to the next and previous lesson without returning to the area.
3. **Given** an area whose lessons the learner has not finished, **When** they look for its test, **Then** they are told what remains, and the test's questions, options and answers are **not** disclosed.
4. **Given** an area whose lessons the learner has finished, **When** they take the test, **Then** they may answer each question, submit once, and receive a score plus, for every question, whether they were right and what the correct answer is.
5. **Given** a submitted test, **When** the learner re-reads the result, **Then** the result is the same as when it was first shown.
6. **Given** an area, **When** a learner opens its practice set, **Then** the reference module's question kinds are available — multiple choice, short answer and flashcard.
7. **Given** any served question, **When** its provenance is inspected, **Then** it carries at least one passage citation that resolves.
8. **Given** a question whose citation cannot be resolved, **When** the practice set is assembled, **Then** that question is **withheld** rather than served without provenance.
9. **Given** a question citing a transcript segment, **When** the learner follows the citation, **Then** playback lands inside that segment, and returning restores the question and the learner's progress.
10. **Given** a model answer that was assembled rather than authored, **When** it is shown, **Then** it is marked as such and is not presented as a verified answer.
11. **Given** a learner completes practice, **When** they return later, **Then** their progress per area and per question set is preserved, within the durability bound stated in FR-118.

---

#### User Story 12 — Browse and watch the curriculum like a course (Priority: P2)
*(was: 001/US2)*

A learner opens the curriculum and sees the available chapters. They pick one, read its materials,
watch the recording, and move through its sections in a deliberate order.

**Why this priority**: this is what makes the transcript a *curriculum* rather than a file. It
depends on Story 3's output existing, and a reader can already extract value from a well-structured
transcript without a browsing interface.

**Independent Test**: start the curriculum with the documented command, open it, and confirm a
chapter is listed, its materials are readable, and the recording plays. Testable with exactly one
chapter present.

**Acceptance Scenarios**:

1. **Given** the curriculum is started using its documented start command, **When** a user opens it, **Then** every existing chapter is listed with its title and a summary.
2. **Given** a user has opened a chapter, **When** they view it, **Then** they can read its transcript and materials and play its recording without leaving the curriculum.
3. **Given** a user is partway through a chapter, **When** they navigate between its sections, **Then** their position and progress are preserved.
4. **Given** a machine that has never run it, **When** the documented start command is used, **Then** it starts successfully without manual setup beyond what the documentation states.
5. **Given** a recording stored in split parts, **When** a user plays it, **Then** playback works without the user needing to know about or manually reassemble those parts.
6. **Given** zero chapters have completed ingestion, **When** a user opens the curriculum, **Then** an explicit "no chapters available yet" state is shown — never an empty or broken page.

---

#### User Story 13 — Go from any point to every related point, in both directions (Priority: P2)
*(was: 002/US2)*

A learner watching the recording pauses at a moment and jumps straight to the area that moment
belongs to, and from there to the lesson section and to the questions that test it. Later they come
at it from the other end: they open a quiz question and jump to the exact moment that teaches its
answer, then come back without losing their place.

**Why this priority**: the heart of the operator's description and the mechanism every other story
depends on. Second only because it needs areas to link to.

**Independent Test**: with the taxonomy present, enumerate every recorded link, traverse it forward
and then backward, and confirm the reverse traversal returns the origin. No interface required.

**Acceptance Scenarios**:

1. **Given** a transcript moment, **When** a learner asks what it belongs to, **Then** the areas, the chapter section and the questions attached to it are returned, each reachable in one step.
2. **Given** an area, **When** a learner asks where it appears, **Then** every passage that evidences it is returned, each with the position at which it occurs.
3. **Given** a question, **When** a learner follows its citation, **Then** playback lands inside the time span of the cited passage.
4. **Given** any recorded link, **When** it is traversed in reverse, **Then** the origin is returned; no link is one-way.
5. **Given** a passage whose text is corrected and the content re-indexed, **When** every link is re-traversed, **Then** all of them still resolve to the same targets.
6. **Given** a link whose target no longer exists, **When** it is followed, **Then** it fails loudly with a stated reason, and is never quietly re-pointed at a different target.
7. **Given** a chain of related material that forms a cycle, **When** a learner traverses it, **Then** they are not trapped; the traversal terminates.
8. **Given** a passage that has been redacted, **When** any link to it is followed, **Then** the redaction is honoured at every layer, not merely in the transcript view.
9. **Given** a traversal resolving to more than one qualifying occurrence, **When** it is presented, **Then** **every** occurrence is shown; the system never silently selects one on the learner's behalf.

---

#### User Story 14 — A learner jumps from a lesson to the exact moment in the recording (Priority: P2)
*(was: 004/US3)*

A lesson references a moment in a recorded session. The learner follows the reference and lands on
the recording positioned at that moment, with the accompanying transcript scrolled to the matching
passage and that passage marked so it is findable on the page.

**Why this priority**: this is the capability that makes the lessons worth more than prose — it binds
authored teaching to the primary recorded material. It sits below P1 because a learner can complete
Stories 10 and 11 without it, and it depends on Story 11 existing to link *from*. It is kept
distinct from Story 13 deliberately: Story 13 specifies the **graph and its resolver**; this story
specifies the **landing experience** and its accessibility.

**Independent Test**: follow every reference in one area's lessons and confirm each lands on the
right recording, at the right moment, with the right passage in view and marked.

**Acceptance Scenarios**:

1. **Given** a lesson with a reference to a recorded moment, **When** the learner follows it, **Then** the recording page opens with the player positioned at the referenced start time.
2. **Given** the same reference, **When** the page settles, **Then** the transcript is scrolled so the referenced passage is visible without further scrolling, and that passage is visually distinguished from its neighbours.
3. **Given** a reference naming a start and an end, **When** the learner follows it, **Then** the extent of the referenced range is discernible, not only its start.
4. **Given** a reference whose target recording or passage is not available, **When** the learner follows it, **Then** they are told the target is unavailable — never sent to a page that reports nothing found.
5. **Given** any published lesson, **When** its references are inspected, **Then** every one resolves to an existing recording and an existing passage.
6. **Given** a learner using only a keyboard or a screen reader, **When** they follow the reference, **Then** the jump is reachable without a pointing device and arrival at the referenced passage is **announced**, not conveyed only by a visual highlight.

---

#### User Story 15 — A learner uses supporting materials, not only text (Priority: P2)
*(was: 004/US4)*

Within a lesson the learner encounters illustrations, diagrams, schemes and graphs alongside the
prose, and — where the subject warrants it — a segment of recorded video presented in place rather
than as a link away.

**Why this priority**: the operator named these explicitly. They raise comprehension for the same
content, but a lesson without them still teaches, so they rank below the lesson mechanism itself.

**Independent Test**: open every lesson in one area and confirm each declared material renders,
carries a caption, and is reachable without a mouse.

**Acceptance Scenarios**:

1. **Given** a lesson declaring a visual material, **When** the learner reads it, **Then** the material renders in place with a caption stating what it shows.
2. **Given** a lesson declaring a video segment, **When** the learner reads it, **Then** the segment is playable in place and bounded to its stated range.
3. **Given** any material, **When** it is presented to assistive technology, **Then** it carries a text alternative that conveys its content rather than its file name.
4. **Given** a material file is missing, **When** the lesson renders, **Then** it states the material is unavailable rather than rendering a broken element.

---

#### User Story 16 — Hierarchy is visible without a new endpoint (Priority: P2)
*(was: 003/US4)*

A client renders a chapter tree, filters to one branch, and asks how deep the corpus goes — using
the endpoints it already calls.

**Why this priority**: the information is needed, and a new route is a new manifest row, a new
contract section, a new gate and a new negative assertion. Deriving it costs none of those.

**Independent Test**: fetch the chapter list, build a tree from the `hierarchy` object on each row
without a second request, and confirm the tree matches the directory layout.

**Acceptance Scenarios**:

1. **Given** the chapter list, **When** a client reads a row, **Then** it carries `parent_id`, `depth`, `ancestor_ids`, `child_ids` and `orphaned` — and the array is still **flat**.
2. **Given** a branch filter, **When** the list is fetched, **Then** it returns that branch's descendants, and the response echoes the filters it applied.
3. **Given** a branch filter naming a chapter that does not exist, **When** the list is fetched, **Then** the response is `200` with an empty array and `under_resolved: false` — **not** a `404`, because the request was well-formed and the answer is *"no such branch"*, not *"no such endpoint"*.
4. **Given** the backend cannot read the chapter tree, **When** the list is fetched, **Then** the response is the could-not-determine state **and still echoes the filters**.
5. **Given** `chapters/` is empty or holds only dotfiles, **When** the list is fetched, **Then** it is `200` with an empty array — distinct from could-not-determine, which is reserved for a directory that cannot be read.

---

#### User Story 17 — Every learner-facing defect is repaired or disclosed (Priority: P2)
*(was: 005/US3, 006/US4 — MERGED)*

A learner never encounters content that is silently broken. Where something is missing or withheld,
they are told, rather than shown a shorter test, an absent section, or an area that looks complete
and is not.

**Why this priority**: both source stories were P2 and both describe the same guarantee from two
directions — `005/US3` from the withheld-material side, `006/US4` from the completeness side. They
are user-visible defects that degrade rather than block, so they sit behind the P1 stories for
delivery. **Merged rather than kept separate, because the requirement in each is the same: no silent
absence.**

**Independent Test**: walk one area end to end and confirm nothing is silently absent — every
omission is either repaired or stated. Then open every published area and confirm each shows lessons
with content, and either a test or a stated reason there is none.

**Acceptance Scenarios**:

1. **Given** a question whose supporting material is withheld, **When** the test is served, **Then** the question is repaired to cite available material, or removed with the removal recorded — never silently dropped from a learner's test.
2. **Given** an area with no assessment, **When** a learner opens it, **Then** they are told it has none and why, rather than finding an absence.
3. **Given** an area document citing withheld material as its primary reference, **When** it is published, **Then** its references resolve to material a reader can actually reach.
4. **Given** the areas that could not carry a test for a structural reason, **When** that reason is removed, **Then** those areas become authorable and the coverage figure moves for a real cause.
5. **Given** any published area, **When** a learner opens it, **Then** they see lessons with real content, in order.
6. **Given** an area with a test, **When** the learner completes the required lessons, **Then** they can take it and receive a scored result with per-question feedback.
7. **Given** any area, **When** its materials are presented, **Then** each renders with a caption and a text alternative.
8. **Given** an area whose test exists but whose lessons do not, **When** the build runs, **Then** it surfaces as a finding rather than as an area that looks complete.

---

#### User Story 18 — A reviewer can confirm no claim is unearned (Priority: P2)
*(was: 006/US5)*

An independent reviewer takes any claim made about the platform and traces it to machine-produced
evidence, or finds it explicitly marked as unverified.

**Why this priority**: the operator asked for no bluff of any kind. This is what makes that checkable
rather than promised.

**Independent Test**: sample claims from the QA document and the platform's own reporting; each
resolves to evidence or to a stated limitation.

**Acceptance Scenarios**:

1. **Given** any claim that a capability works, **When** a reviewer asks for evidence, **Then** a machine-produced artefact supports it.
2. **Given** any check, **When** it reports, **Then** it distinguishes satisfied, a real finding, and could-not-determine — and a could-not-determine is **never** recorded as satisfied.
3. **Given** any evidence, **When** a reviewer re-runs its producer, **Then** the same inputs produce the same result.
4. **Given** a known gap, **When** a reviewer looks for it, **Then** it is recorded with its reason and who may lift it — not omitted.

---

#### User Story 19 — The interface is vivid, legible and consistent on the surfaces people use (Priority: P2)
*(was: 004/US5, 005/US4 — MERGED)*

A visitor perceives the platform as a designed product with a distinct and varied palette, rather
than a two-tone monochrome document — and every foreground/background pairing remains legible,
including for a visitor using a dark colour scheme or a high-contrast setting.

**Why this priority**: both source stories were P2 and both describe the same measured defect from
the same instrument — `004/US5` raised it, `005/US4` re-raised it after a corrected instrument
measured the hue count going **down** from 4 to 2 when the instrument became honest. **Merged**,
because two stories measuring one number with one method are one story. It is P2 because it changes
how existing capability is perceived rather than what capability exists.

**Independent Test**: load the served interface, sample the colours actually painted on each
principal surface, and measure both the variety across them and the contrast within each pairing, in
both presentations.

**Acceptance Scenarios**:

1. **Given** the served interface, **When** its principal surfaces are sampled, **Then** they carry materially more hue variety than a two-family scheme.
2. **Given** any hue that is added, **When** a reader asks what it means, **Then** it carries a stated classification job — no hue is added only to raise a count.
3. **Given** the measurement, **When** its population is defined, **Then** the population reflects the surfaces a visitor actually looks at, and any change to that population is justified independently of its effect on the count.
4. **Given** both presentations, **When** contrast is measured, **Then** every text and non-text pairing meets its floor in each, measured separately.
5. **Given** a colour decision recorded in the design source, **When** the served interface is measured, **Then** the served interface reflects it — a measurement taken on the design source alone does **not** satisfy this story.

---

#### User Story 20 — Find anything by meaning, and be told exactly where it is (Priority: P3)
*(was: 001/US3, 002/US3 — MERGED)*

A learner remembers that something was discussed but not the words used. They type what they mean,
get relevant results ranked by meaning across transcripts, documentation, diagrams, code, areas,
lesson sections, terms and questions, see them as they type, and follow cross-references from a
result to related material elsewhere. Each result says *where* it occurs: which unit contains it and
at what position within that unit.

**Why this priority**: both source stories were P3 for compatible reasons. `001/US3` is the
"game-changer" capability and the largest body of work, valuable only once there is indexed content
and a place to present results. `002/US3` extends a proven capability to new kinds, and the new kinds
must exist first. **Merged**, because the second is the first with more kinds and a mandatory locus.

**Independent Test**: with content indexed, issue a benchmark of meaning-based queries whose expected
material is known in advance, and confirm the expected passages are returned and ranked sensibly —
including queries sharing no literal words with the target text — and that every returned hit carries
a locus that resolves.

**Acceptance Scenarios**:

1. **Given** indexed content, **When** a user searches using words that do not literally appear in the target passage, **Then** the passage is still returned because it matches by meaning.
2. **Given** a user is typing a query, **When** each character is entered, **Then** suggestions appear quickly enough to feel instantaneous, and areas and terms are offered alongside the existing suggestions.
3. **Given** a search result, **When** the user selects it, **Then** they are taken to the exact passage in its source material, with surrounding context visible.
4. **Given** a search result, **When** it is displayed, **Then** it states the unit that contains it and the position within that unit — a time span where the source is media-backed, a text span otherwise.
5. **Given** a passage of content, **When** the user views it, **Then** related material elsewhere is offered as cross-references.
6. **Given** the curriculum includes source code, **When** a user searches for a concept implemented in that code, **Then** the relevant code is returned alongside prose results.
7. **Given** all content kinds are indexed, **When** a learner searches, **Then** results may come from any kind, and a kind with content but no index entries is a **failure** rather than an empty category.
8. **Given** a learner wants to narrow results, **When** they filter by area or by kind, **Then** only matching results are returned and the filter is reflected in what is shown.
9. **Given** a search returns no relevant match, **When** results are shown, **Then** the interface says so plainly rather than presenting unrelated results as answers.
10. **Given** the search backend is degraded or unavailable, **When** a learner searches, **Then** the system says it could not answer, and does **not** render the failure as "no results".
11. **Given** the corpus has grown with the new kinds, **When** latency is measured, **Then** it still meets the thresholds established for the existing corpus.

---

#### User Story 21 — An orphan is served, and says so (Priority: P3)
*(was: 003/US5)*

A sub-chapter exists and its parent does not. The platform serves the sub-chapter and states that
its parent is missing.

**Why this priority**: it is a real state — a sub-chapter can be archived before its parent is, or a
parent can be withdrawn — and both of the obvious behaviours are wrong. Hiding the orphan loses
content that exists; serving it as a root silently rewrites the hierarchy.

**Independent Test**: remove a parent directory from a fixture tree, list the chapters, and assert
the child is present, marked orphaned, and names the id it could not find.

**Acceptance Scenarios**:

1. **Given** a sub-chapter with no parent directory, **When** the list is fetched, **Then** it is present, `orphaned` is `true`, and `parent_id` still names the absent parent — the derivation is unchanged by the parent's absence.
2. **Given** the same, **When** the branch filter names the absent parent, **Then** the sub-chapter is returned, because the filter matches derived ancestry and not the existence of the ancestor.

---

#### User Story 22 — Ask a question and get a grounded answer (Priority: P4)
*(was: 001/US4)*

A learner asks a natural-language question about the workshop content and receives a direct answer,
together with citations pointing to the passages the answer was drawn from, so they can verify it.

**Why this priority**: highest-risk item for correctness. It depends on everything above and is the
easiest place for the system to produce confident-sounding falsehoods, which this project's
governance explicitly forbids. Sequencing it late means it is built on already-verified foundations.

**Independent Test**: ask a set of questions with known correct answers, plus a set the content
genuinely cannot answer. Confirm the first set is answered correctly with working citations, and the
second set is refused rather than fabricated.

**Acceptance Scenarios**:

1. **Given** a question answerable from indexed content, **When** the user asks it, **Then** the answer is returned with citations to the specific passages it came from.
2. **Given** a citation in an answer, **When** the user follows it, **Then** it lands on material that genuinely supports the claim made.
3. **Given** a question the content cannot answer, **When** the user asks it, **Then** the system states that it does not know instead of inventing an answer.
4. **Given** an operator has configured a locally-hosted model, **When** questions are asked, **Then** they are answered without content being sent to any external service.
5. **Given** no model is configured or reachable, **When** a user asks a question, **Then** the system reports that answering is unavailable, and search and browsing continue to work.
6. **Given** answer generation starts producing output and then fails or disconnects, **When** the failure occurs, **Then** the partial output is discarded and a failure is reported — never a truncated answer that appears complete.

---

#### User Story 23 — A learning surface, with its own visual identity (Priority: P5)
*(was: 002/US5)*

A learner uses an interface built for learning — an area view, a practice view, a progress view and
a study-plan view — rather than a file browser with a video in it. It looks like the workshop's own
product, not like a copy of the reference module.

**Why this priority**: the surface is the vehicle, not the cargo. Stories 10 to 22 are all testable
through the platform's own interfaces without it. **Kept distinct from Story 19 deliberately**: this
story is about the *shape and composition* of the learning surface; Story 19 is about the *palette
and contrast* painted on whatever surface exists. Merging them would have raised palette work to P5
or dropped surface work to P2, and both would have been wrong.

**Independent Test**: open each new view and complete its primary task using only the keyboard, then
run an accessibility audit and a design-token conformance check against the whole surface.

**Acceptance Scenarios**:

1. **Given** the platform is running, **When** a learner opens it, **Then** the entry point is the knowledge the workshop covers, with the recording reachable from within an area rather than being the top-level object.
2. **Given** an area, **When** a learner opens it, **Then** they can read it, practise it, see their progress in it, and reach every linked point from it.
3. **Given** the existing chapter, transcript, recording and cross-reference views, **When** the new surface is delivered, **Then** those capabilities remain reachable, subordinated to the area they belong to rather than removed.
4. **Given** any new view, **When** its styling is inspected, **Then** every colour, spacing and typographic value resolves through the shared design-token contract, and no brand value is written literally.
5. **Given** any new view, **When** an accessibility audit is run, **Then** it reports no Level A or Level AA violation, and every deep link is reachable and operable by keyboard alone.
6. **Given** a learner is midway through an area, **When** they follow a deep link out and come back, **Then** their position is restored.

---

#### User Story 24 — Add a new chapter and get the whole knowledge layer (Priority: P5)
*(was: 001/US5, 002/US7 — MERGED)*

A maintainer finishes recording the next chapter. They run one documented procedure. The chapter
arrives transcribed, its passages minted, its areas extracted and merged into the existing taxonomy,
its materials written, its short and long question sets built, everything cross-referenced, indexed
and deep-linked — with no hand-assembly of structure and no code change.

**Why this priority**: `001/US5` was P5 and `002/US7` was P7; **resolved to P5**, the more urgent of
the two, because they describe one procedure and the later numbering reflected position in a
seven-story list rather than lower value. The curriculum's long-term value depends on cheap
extension, but it cannot be validated until at least one chapter has been through the pipeline end
to end — which is why it is late rather than early.

**Independent Test**: run the documented procedure against a small synthetic chapter and confirm it
appears fully integrated — browsable, searchable, cross-linked, with materials and question sets —
and that the diff contains no hand-created structural file.

**Acceptance Scenarios**:

1. **Given** a new chapter's raw material placed where the procedure specifies, **When** the procedure runs, **Then** the chapter emerges transcribed, with minted passage identifiers, extracted areas, authored materials, short and long question sets, cross-references, index entries and deep links — with no code change.
2. **Given** an existing taxonomy, **When** a new chapter is processed, **Then** established areas keep their identifiers and gain evidence, newly evidenced areas are added, and a contradiction between new evidence and an existing area is **reported** rather than silently resolved.
3. **Given** the procedure is run twice on the same chapter, **When** the second run completes, **Then** nothing has changed and nothing is duplicated.
4. **Given** a chapter whose material is incomplete, **When** the procedure runs, **Then** it names exactly what is missing and publishes nothing.
5. **Given** two chapters are present, **When** a learner searches or browses an area, **Then** results and evidence span both chapters, and no area is confined to the chapter it first appeared in.
6. **Given** the procedure exists, **When** a maintainer looks for how to add a chapter, **Then** there is exactly **one** documented way to do it.
7. **Given** a run is interrupted, **When** the platform is inspected, **Then** the previously-published state is fully intact and fully servable, and no partially-written artefact is reachable by a learner or by search.

---

#### User Story 25 — Take an area away with you, in four formats (Priority: P6)
*(was: 002/US6)*

A learner exports an area and gets Markdown, HTML, Word and PDF — with the citations preserved.

**Why this priority**: last among baseline stories because it is a transformation of material that
must exist and be correct first. Exporting wrong material in four formats is four times the damage.

**Independent Test**: run the export over every published area and check the format matrix is
complete, then re-run it and confirm the extracted text of each regenerated document is unchanged.

**Acceptance Scenarios**:

1. **Given** a published area, **When** export is run, **Then** all four formats are produced.
2. **Given** the export has been run, **When** an area is exported again from unchanged source, **Then** the extracted text of each output is identical to the previous run.
3. **Given** an exported document, **When** a reader inspects a cited claim, **Then** the citation is present and identifies the passage it came from.
4. **Given** an area that has not passed its publication review, **When** export is run, **Then** that area is not exported and the omission is reported.
5. **Given** a diagram belonging to an area, **When** the area is exported, **Then** the diagram is rendered into each format rather than being dropped.
6. **Given** any exported document, **When** it is written to a location outside the platform's own storage, **Then** it has passed the content-boundary check first, covering extracted taxonomy labels as well as prose.

### TARGET — the decoupled modules

---

#### User Story 26 — Workshop runs as an independent module (Priority: T-P1)
*(was: 007/US1, 004/US6 — MERGED)*

An engineer clones the workshop repository by itself, on a machine with no access to the `vasic`
umbrella, follows its own written instructions, and reaches a running system that passes its own
test suite.

**Why this priority**: T-P1 — foundational to Part II; without decoupling none of the other target
stories can be validated independently. `004/US6` stated the same goal at P3 as a baseline
requirement (*"each learning module runs on its own"*, FR-024/FR-025); **merged and raised**, because
it is the same journey and Part II makes it a primary objective rather than a nice property.

**Independent Test**: clone into an empty directory on a machine that has never held the umbrella,
run the documented bootstrap, run the test suite, and read the status output.

**Acceptance Scenarios**:

1. **Given** a fresh machine with only git and the required runtime, **When** the user clones the workshop repository, **Then** all submodules initialise correctly and the build passes.
2. **Given** workshop cloned independently, **When** the user runs the installation script, **Then** all dependencies are resolved internally without referencing the umbrella.
3. **Given** standalone workshop, **When** the user runs the test suite, **Then** all tests pass with deterministic evidence.
4. **Given** the bootstrapped module, **When** the engineer runs its status command, **Then** it reports ready, or reports precisely which host capability is missing and the exact command to obtain it.
5. **Given** the module in that standalone state, **When** any of its own scripts resolve paths, **Then** none of them require the umbrella to be present.
6. **Given** the standalone clone has not yet passed install and the full test suite, **When** decommissioning is proposed, **Then** it is refused — the umbrella-hosted copy remains operative.

---

#### User Story 27 — ai_interviewing runs as an independent module (Priority: T-P1)
*(was: 007/US2, 004/US6 — MERGED)*

The `ai_interviewing` module (user-facing name: `ai_curriculum`) is extracted from the umbrella and
functions as a completely standalone project that can be cloned, installed and run independently.

**Why this priority**: parallel to Story 26 — both modules must be independently usable, and the
same decommission gate applies to each.

**Independent Test**: clone the `ai_interviewing` repository to a fresh machine, run install/setup,
and verify all functionality works.

**Acceptance Scenarios**:

1. **Given** a fresh machine, **When** the user clones the `ai_interviewing` repository, **Then** all submodules initialise and the build passes.
2. **Given** it cloned independently, **When** the user runs installation, **Then** all dependencies resolve internally.
3. **Given** standalone `ai_interviewing`, **When** the user runs the test suite, **Then** all tests pass with deterministic evidence.
4. **Given** the standalone clone has not yet passed install and the full test suite, **When** decommissioning is proposed, **Then** it is refused.

---

#### User Story 28 — Authentication with role-based access control (Priority: T-P1)
*(was: 007/US3)*

Both modules have login forms with database-backed users and role-based access control. No content
is reachable without authentication; permissions differ per module; sign-out and account switching
work.

**Why this priority**: T-P1 — the security requirement that defines the target architecture's access
model, and the one place in this specification family where real credentials are handled.

**Independent Test**: attempt to access content without login (must fail), log in as each user
(must get the appropriate access per the II.3 table), and switch accounts.

**Acceptance Scenarios**:

1. **Given** an unauthenticated user accesses workshop, **When** they try to view any content, **Then** they are redirected to login.
2. **Given** either seed user logs into workshop, **When** they access any feature, **Then** they have full access, equal to the other.
3. **Given** the privileged user logs into `ai_interviewing`, **When** they access any feature, **Then** they have full access.
4. **Given** the restricted user logs into `ai_interviewing`, **When** they access employer data or GitHub-project analysis, **Then** access is denied.
5. **Given** the restricted user logs into `ai_interviewing`, **When** they access knowledge-base areas, lessons, tests, exercises or progress, **Then** access is granted.
6. **Given** an authenticated user, **When** they sign out, **Then** the session ends and they cannot access content.
7. **Given** a signed-out user, **When** they switch to a different account, **Then** a new session starts with that account's permissions.
8. **Given** a token minted by one module, **When** it is presented to the other, **Then** it is rejected, even though both modules read the same user store.
9. **Given** the auth provider or user database is unreachable, **When** any protected route is requested, **Then** access is denied — never granted.
10. **Given** a user record with no assigned role, **When** they authenticate, **Then** they receive zero access — never admin-equivalent and never inherited.
11. **Given** an unknown username and a known username with a wrong password, **When** each login fails, **Then** the response content and shape are identical.
12. **Given** a screen-reader or keyboard-only user, **When** an auth error occurs, **Then** it is announced and every control is keyboard-reachable.

---

#### User Story 29 — Progress tracking, user-bound and durable (Priority: T-P1)
*(was: 007/US4)*

Progress tracking across areas, lessons, tests and exercises is fully implemented, working, tested,
verified and validated on both modules, persisted per user in the database.

**Why this priority**: T-P1 — explicitly required as *"MUST BE fully implemented working, tested
verified and validated"*, and measured as not working on either module.

**Independent Test**: complete lessons and exercises as each user and verify progress is recorded,
persisted and displayed correctly, surviving restart.

**Acceptance Scenarios**:

1. **Given** an authenticated user on workshop, **When** they complete a lesson, **Then** progress is recorded and visible.
2. **Given** an authenticated user on `ai_interviewing`, **When** they complete an exercise or test, **Then** progress is tracked per area and per lesson.
3. **Given** progress data exists, **When** the user returns later, **Then** progress is restored from the database.
4. **Given** progress tracking, **When** automated tests run, **Then** deterministic evidence of tracking is produced.
5. **Given** a learner had anonymous per-browser progress in the baseline, **When** the authentication cutover occurs, **Then** that record is handled explicitly per FR-321 — it is never silently merged into a user account and never silently discarded without a stated outcome.

---

#### User Story 30 — Full test coverage with deterministic evidence (Priority: T-P1)
*(was: 007/US8)*

All work is covered by every constitution-supported test type, and every test produces
machine-verifiable deterministic evidence.

**Why this priority**: T-P1 — a governing mandate: no false or faulty results, no AI slop, no bluff.
It is what makes every other target story checkable.

**Independent Test**: run the test suite and confirm it produces structured evidence artefacts that
can be programmatically validated.

**Acceptance Scenarios**:

1. **Given** test-suite execution, **When** tests complete, **Then** evidence artefacts are generated in a machine-readable form.
2. **Given** evidence artefacts, **When** validated by verification scripts, **Then** all pass with zero false positives.
3. **Given** any test failure, **When** evidence is examined, **Then** the root cause is deterministically identifiable.

---

#### User Story 31 — Extract reusable code as public submodules (Priority: T-P2)
*(was: 007/US5)*

All reusable code identified across the codebase is extracted as fully decoupled, generic, **public**
submodules hosted in their own repositories under `vasic-digital`, on both GitHub and GitLab.

**Why this priority**: T-P2 — it enables true decoupling of the two modules while keeping shared code
shared, but the decoupling stories can begin before every extraction is finished.

**Independent Test**: each extracted submodule can be cloned independently, builds and tests pass
without either module present, and it can be consumed by an external project.

**Acceptance Scenarios**:

1. **Given** identified reusable code, **When** extraction completes, **Then** each submodule has its own GitHub and GitLab repository under `vasic-digital`.
2. **Given** new public submodules, **When** workshop and `ai_interviewing` reference them, **Then** they work as external dependencies mounted at each module's own root, with no nested submodules.
3. **Given** a public submodule, **When** an external user clones it, **Then** it builds and its tests pass independently, against synthetic fixtures only.
4. **Given** a candidate extraction, **When** the public repository is about to be created or pushed, **Then** a content-boundary review has confirmed zero private data first.
5. **Given** an extraction has shipped, **When** a consumer has not yet been migrated, **Then** the existing in-tree path still works — extraction is additive-then-cutover.
6. **Given** a capability already provided by an existing submodule in the canonical catalogue, **When** a new component is proposed, **Then** the existing one is consumed rather than reimplemented, or the gap is contributed upstream.

---

#### User Story 32 — Every existing submodule is current (Priority: T-P2)
*(was: 007/US6)*

Every existing submodule is fetched to, and evaluated against, the latest main branch of its
upstream, and verified working.

**Why this priority**: T-P2 — it ensures the decoupled modules use current, compatible dependencies,
but it does not block the decoupling itself.

**Independent Test**: every submodule's recorded pin is compared to its remote, the difference and
its direction are reported, and the modules build with no version conflict.

**Acceptance Scenarios**:

1. **Given** the submodules declared in `.gitmodules`, **When** the currency check runs, **Then** every one reports CURRENT, BEHIND with a classified direction, or could-not-determine — never an unclassified difference.
2. **Given** updated submodules, **When** workshop or `ai_interviewing` is built, **Then** there are no version conflicts.
3. **Given** a submodule reported BEHIND, **When** a pin move is proposed, **Then** the move is evidenced and presented for the operator decision FR-326 requires — it is not performed as a side effect of the check.

---

#### User Story 33 — Comprehensive documentation for standalone modules (Priority: T-P2)
*(was: 007/US7)*

All documentation is extended and updated — user guides, manuals, graphs, diagrams, schemes,
templates, SQL definitions — so each standalone module is usable by someone who has never seen the
umbrella.

**Why this priority**: T-P2 — required for independent usability, and it is the deliverable that
makes Stories 26 and 27 verifiable by a stranger rather than by their author.

**Independent Test**: a fresh user follows the docs to clone, install, configure and run each
module, without external help.

**Acceptance Scenarios**:

1. **Given** a fresh clone of workshop, **When** the user follows the README, **Then** setup succeeds without external help.
2. **Given** a fresh clone of `ai_interviewing`, **When** the user follows the docs, **Then** setup succeeds.
3. **Given** the architecture documentation, **When** a developer reads it, **Then** they understand the system without source diving.
4. **Given** the documentation set, **When** a reader looks for what the system cannot do, **Then** it is stated honestly, including any content that is not indexed and any capability requiring operator configuration.
---

### Edge Cases

124 edge cases existed across the seven source specifications. They are unified here into **116** —
eight merges where two specs described the same condition, and no deletions. Every entry carries a
back-reference. Where a merged entry combines two source consequences, both consequences are kept.

**Source material, reassembly and transcription**

- **EC-001** *(was: 001)* — **The recording is only available as split parts.** A fresh clone has archive parts and no playable video. Reassembly must be automatic and integrity-checked; a corrupted or partial reassembly must fail loudly rather than yield a truncated video that appears to work.
- **EC-002** *(was: 001)* — **Transcription is expensive and long-running.** A multi-gigabyte recording cannot be transcribed within a normal interactive wait. The process must be resumable, must report progress, and must not lose completed work if interrupted.
- **EC-003** *(was: 001)* — **Speech is unclear, overlapping, or in mixed languages.** Marked as uncertain, never silently invented.
- **EC-004** *(was: 001)* — **The notes document and the transcript disagree.** The recording is the authority; the disagreement is surfaced, not silently resolved.
- **EC-005** *(was: 001)* — **The host runs out of disk space mid-reassembly or mid-transcription.** The operation must fail loudly with a clear report, never leave a partially written file that could be mistaken for complete.
- **EC-006** *(was: 001)* — **The checksum manifest needed to verify a reassembled recording is itself missing or corrupted.** Reassembly must refuse to proceed rather than serve an unverified file.
- **EC-007** *(was: 001)* — **The curriculum is started on a machine with no GPU, or with a different container runtime.** It must run or state precisely what is missing.

**Chapter identity, grammar and hierarchy**

- **EC-008** *(was: 003 — MERGED from two adjacent entries)* — **A directory whose numeric components are not zero-padded** (`02.2`, or `2` one level up). Byte order puts `02.2` *after* `02.10`. It must be refused by the validator, not silently sorted wrongly. This is the single input class the grammar exists to reject.
- **EC-009** *(was: 003)* — **A deeply nested id** (`02.01.01.01`). Depth is unbounded in the grammar. It must be accepted, and the measured maximum depth published rather than a limit asserted.
- **EC-010** *(was: 003)* — **A chapter id used as a path key against a route wildcard.** The wildcard is single-segment; an id containing a path separator would silently truncate the match — which is exactly why the slug allowlist rejects separators.
- **EC-011** *(was: 003)* — **A parent with no material of its own.** A parent may be a container. It is still a chapter, is still listed, and its zero passages are a measurement rather than an error.
- **EC-012** *(was: 003)* — **Two chapters whose ids differ only by padding.** The grammar rejects the unpadded form, so this cannot arise — but the validator must be *tested* on it, because "cannot arise" is an assertion about a validator that has not been written yet.
- **EC-013** *(was: 003)* — **A search hit whose scope is a sub-chapter.** Any consumer comparing scopes with a prefix, suffix or containment test is wrong for the same reason the redaction reviewer was.
- **EC-014** *(was: 003)* — **A chapter id appearing inside a filename-shaped string.** The leak detector's extension list is closed and holds no numeric-only entry, so a dotted component is not read as an extension. Measured, not assumed — and it must stay measured, because the fix for it is one entry in a list.
- **EC-015** *(was: 003)* — **The client's two chapter shapes disagreeing.** They already do — one yields null, the other yields a colliding integer. Whatever the ordinal decision is, both shapes must produce the same value or the mismatch must be impossible to express.
- **EC-016** *(was: 003)* — **Sibling ids whose final component width differs** (`02.09` beside `02.100`). Both are grammar-valid, but the wider one sorts first once the first differing character is compared, breaking the ordering guarantee. The grammar does not forbid it, because a wider corpus is not itself an error — a gate reports the mismatch instead of silently sorting it wrong.
- **EC-017** *(was: 003)* — **A passage or search-index record whose scope names a chapter id with no corresponding directory.** This is not the orphan case — that is a missing *ancestor*. This is a missing *self*. The registry record is not deleted and the chapter list carries no row for the missing id; the two facts must coexist without either silently disappearing.
- **EC-018** *(was: 003)* — **Two derived ids can never collide into a cycle.** A parent id is always a strict prefix of its own id, one component shorter, so the derivation is a well-founded partial order by construction. Recorded because "circular references" is exactly the kind of defect to rule out explicitly rather than by silence.
- **EC-019** *(was: 003)* — **`chapters/` exists and is empty, or contains only dotfiles.** The list endpoint returns `200` with an empty array — not an error, and not the could-not-determine state, which is reserved for a directory that cannot be *read*.
- **EC-020** *(was: 003)* — **A client renders a breadcrumb trail from `ancestor_ids`.** Read root-first; nearest-first would put the trail backwards on screen without every client reimplementing the same reversal.
- **EC-021** *(was: 003)* — **A branch filter and a depth filter combined.** A depth-limited branch query needs both "how many levels down" and "does the branch root itself count" resolved the same way for every client, or two clients will disagree about what one URL returns.
- **EC-022** *(was: 003)* — **A syntactically invalid branch-filter value**, distinct from a syntactically valid one that names nothing. Treating it as a different failure class would mean the 404-avoidance reasoning stops applying the moment the input is merely malformed instead of merely missing.
- **EC-023** *(was: 003)* — **Chapters that are archived and verified but not ingested are still listed.** Whether an unpublished chapter's existence should be visible before its content is reviewed is a real question this work does not answer by accident — the no-silent-omission rule already answers it for every other directory, and no exception is carved out.

**Knowledge areas, terms and taxonomy**

- **EC-024** *(was: 002)* — **A term appears in a passage that has been redacted.** The term keeps its evidence count only if another passage supports it; otherwise the term itself disappears from the published taxonomy, not merely loses one link.
- **EC-025** *(was: 002)* — **A term is a common word.** An extractor that treats frequency as significance produces a taxonomy of stopwords. Significance must be demonstrated, and the demonstration recorded so it can be challenged.
- **EC-026** *(was: 002)* — **An area is evidenced only by passages flagged uncertain.** An area resting entirely on uncertain evidence must be marked as such and must not read like a confident one.
- **EC-027** *(was: 002)* — **A mention spans a segment boundary.** A term spoken across the seam between two segments belongs to both; attaching it to one silently loses half its evidence.
- **EC-028** *(was: 002)* — **Two areas overlap almost completely.** Near-duplicate areas fragment the taxonomy and split their own evidence. Merging is a decision with consequences for every link already pointing at either one.
- **EC-029** *(was: 004)* — **Two areas claim the same subject.** The catalogue exposes each subject once; duplicates are a defect of the authored set and are detectable before publication. *(Related to EC-028, which is about near-duplicates in an extracted taxonomy; this one is about the authored set.)*
- **EC-030** *(was: 002)* — **A published area's evidence is reduced to zero after publication.** A later redaction removes the last passage that evidenced an already-published area. The publish-time precondition governs publish time only; an area displaying as published with no live evidence behind it is the same failure shifted later in time.
- **EC-031** *(was: 002)* — **A question cites a passage in a different chapter than the area it belongs to.** Legitimate once more than one chapter exists; the model must not assume an area lives in one chapter.
- **EC-032** *(was: 004)* — **An area is authored but incomplete, or its test exists and its lessons do not.** *(MERGED with 006's "an area's test exists but its lessons do not".)* It MUST NOT appear in the catalogue — a listed area that cannot be completed is the listed-but-unopenable defect in a new costume — **and** the inconsistency must surface as a build-time finding rather than as an area that looks complete.
- **EC-033** *(was: 004)* — **The catalogue has zero publishable areas, or zero chapters have completed ingestion.** *(MERGED with 001's zero-chapters case.)* An explicit empty state must be shown — never an error, never a blank page — and that state alone MUST NOT be read as a build failure. An unhandled empty state either looks like a startup failure or renders a page a screen reader announces nothing about.
- **EC-034** *(was: 004)* — **The catalogue or the corpus grows far beyond its current scale.** The effect on catalogue and reference-resolution response time must be measured as scale changes; the design must not assume a fixed ceiling, and a measured slowdown must be reported rather than silently absorbed.

**Lessons, assessment and authored content**

- **EC-035** *(was: 004)* — **A test is taken twice.** The result of the submitted attempt stands; a second submission does not silently overwrite the first without the learner being told.
- **EC-036** *(was: 004)* — **A learner requests a test before finishing the lessons.** The response states what remains. It MUST NOT include the questions, the options or the answers — an "unavailable" response that ships the answer key has disclosed it.
- **EC-037** *(was: 004)* — **A lesson body is extremely long or extremely short.** Its stated reading time must be computed from the body it actually describes rather than authored as an independent guess; a body so short it carries no substantive content must fail the same structural check that catches malformed content, not a separate word-count rule.
- **EC-038** *(was: 004)* — **A test's question bank is very small.** Where the stated pass threshold applied to the question count does not land on a whole number, the required correct-answer count must **round up, never down** — a learner is never told they passed on a downward rounding of the stated bar.
- **EC-039** *(was: 004)* — **Authoring is interrupted before an area is finished**, leaving a lesson, question or field carrying an explicit draft/placeholder marker. That marker must be detected automatically and must exclude the area from publication by the same determination that governs publication — never by the author remembering to delete it before committing.
- **EC-040** *(was: 004)* — **Authored content is malformed** — broken structure, an unparseable reference, a field the schema does not expect. This must surface as a build-time finding, never as a runtime error shown to a learner.
- **EC-041** *(was: 002)* — **An area has zero questions.** Presenting an empty practice set as though practice exists is a small lie that erodes trust in every other count on the page.
- **EC-042** *(was: 004)* — **A learner cannot tell authored teaching prose from a quoted transcript passage inside the same lesson.** The two must be visually and structurally distinguished — this is the presentation-layer expression of the reason this feature exists: the platform publishes authored subjects, not mined material, and a reader must be able to *see* that distinction.
- **EC-043** *(was: 004)* — **A test result is read by a learner who cannot perceive colour.** Per-question correctness must be conveyed by an icon or text label in addition to colour, never by colour alone.
- **EC-044** *(was: 002)* — **A model answer was assembled rather than authored.** It must be marked as assembled and must not be presented as a verified answer.

**Deep linking, citations and anchoring**

- **EC-045** *(was: 001, 002 — MERGED)* — **A transcript passage, or a question's only cited passage, is corrected after references already point at it.** The references must continue to resolve; a correction must not orphan them. This is exactly what the minted identifier exists for, and it must be proven, not assumed.
- **EC-046** *(was: 001)* — **A passage is redacted after it has been indexed and cited.** The redaction must propagate to the index and to any stored answers, not merely to the displayed transcript.
- **EC-047** *(was: 002)* — **A search hit's match offsets or snippet are computed and cached before the passage they were drawn from is redacted.** A cached or precomputed representation sitting ahead of the next full reindex is a gap wide enough for withheld text to keep being served after the redaction that was supposed to stop it.
- **EC-048** *(was: 002)* — **A learner follows a deep link into a passage whose time span is long.** The measured maximum is 20.22 s. Landing "inside the segment" is the guarantee; landing on the word is not, and the interface must not imply the precision it does not have.
- **EC-049** *(was: 002)* — **A landing timestamp falls exactly on a boundary** — the last instant of one word or segment and the first instant of the next. Without one documented convention, the same timestamp can be rendered as belonging to either neighbour depending on which producer or consumer computed it — an off-by-one defect a test suite comparing "inside the span" to itself will never catch.
- **EC-050** *(was: 002)* — **A citation or a "where does this appear" traversal resolves to more than one occurrence.** Picking one silently is faster to build and indistinguishable, to the learner, from having picked the only one.
- **EC-051** *(was: 002)* — **A search hit's containing unit was deleted between indexing and display.** The locus must fail loudly rather than render a link into nothing.
- **EC-052** *(was: 002)* — **A code passage's underlying file is edited, moved or deleted independently**, by unrelated work elsewhere in the monorepo. The workshop's own content did not change, but what the citation points at did — a source of staleness the correction-and-reindex guarantee does not cover, because it is not the workshop that edited the content.
- **EC-053** *(was: 001)* — **Two chapters cover the same topic.** Cross-references must not create loops that trap a reader.
- **EC-054** *(was: 004)* — **A referenced recording moment lies beyond the end of the recording.** The reference is reported as unresolvable at authoring time, not silently clamped to the end at reading time.

**Search and answering**

- **EC-055** *(was: 001, 002 — MERGED)* — **Indexing runs while content is being edited, or the taxonomy is re-extracted while the index is being served.** Results must never be served from a half-written index and half-written taxonomies must never be served; a stale-but-coherent state is preferable to an incoherent one.
- **EC-056** *(was: 001)* — **The indexing backend is unavailable or saturated.** Search must degrade honestly — reporting that it cannot answer right now — rather than returning empty results that read as "nothing found". *(This failure has already occurred. The "75 s" originally recorded was not a measurement: it was the probe's own timeout value, so it recorded the observer rather than the system. The real recorded figures are >90 s for a serialised embed call and ~10 min elsewhere; a controlled re-measurement under load saw three identical two-word embed calls take 20.16 s / 11.05 s / 0.10 s. The conclusion stands; the number was wrong and is withdrawn rather than quietly replaced.)*
- **EC-057** *(was: 001)* — **A search returns a passage the user is not expecting to exist.** Because the recording is a private teaching session naming a specific individual, access scope must be explicit rather than assumed.
- **EC-058** *(was: 001)* — **A very large or very small query.** An empty query, a single character, and a multi-paragraph query must all behave predictably.
- **EC-059** *(was: 001)* — **Answer generation starts producing output and then fails or disconnects partway through.** The partial output must be discarded, not shown as a truncated answer that appears complete but is missing citations.
- **EC-060** *(was: 001)* — **A screen-reader user searches.** Suggestions appearing as the user types must be announced, and must not trap focus.

**Session record and carry-forward**

- **EC-061** *(was: 006)* — **A session covered something never planned.** It is recorded as emergent, not silently folded into the plan as though it had been foreseen.
- **EC-062** *(was: 006)* — **A point is carried forward indefinitely.** The slip count is visible and rising; a point that has slipped repeatedly is surfaced rather than buried.
- **EC-063** *(was: 006)* — **A chapter has no successor.** Carry-forward from the latest chapter must still land somewhere findable.
- **EC-064** *(was: 006)* — **Two chapters disagree about an open question's status.** The later chapter's record governs, and the transition is visible rather than a silent overwrite.

**QA execution**

- **EC-065** *(was: 006)* — **A QA step depends on a capability that is deliberately absent.** Stated in advance, with the reason.
- **EC-066** *(was: 006)* — **A scheduled QA session begins while the platform is unreachable.** The precondition fails outright; the tester records "environment unavailable" and reports it, rather than attempting a partial test — no step that could not actually be exercised is recorded as passed.
- **EC-067** *(was: 006)* — **A QA session is interrupted before completion.** The tester resumes from the last completed, evidenced step rather than restarting from zero; the QA document names the resumption point explicitly.
- **EC-068** *(was: 006)* — **Evidence capture itself fails for a step** (a screenshot, log or recording tool errors, or produces an unreadable artefact). That step is recorded as observed-but-unevidenced, never silently as passed — a capture failure is a could-not-determine, exactly as an unproducible machine artefact is treated everywhere else. *(The machine-side counterpart is EC-076.)*
- **EC-069** *(was: 006)* — **Only one tester is available for a session.** QA readiness does not depend on tester headcount; every scenario must be completable by a single person acting alone.
- **EC-070** *(was: 006)* — **Multiple testers attempt to use the QA document against the same running environment at the same time.** Not required to be supported; each tester works against their own environment instance or at a separate time — concurrent shared-environment testing is out of scope, not silently assumed to work.
- **EC-071** *(was: 006)* — **Evidence accumulates across repeated QA runs.** Nothing is silently deleted; archiving older evidence out of the live directory, if volume becomes a concern, is an operator decision, not an automatic housekeeping step.

**Measurement honesty**

- **EC-072** *(was: 004, 006 — MERGED)* — **The corpus or source material is edited while a count over it is being taken.** Any count reported must be accompanied by evidence that the material did not move during the measurement; a count taken over a moving corpus is not reproducible and must be reported as undetermined rather than as a number.
- **EC-073** *(was: 004, 006 — MERGED)* — **The interface is measured but the served bundle was not rebuilt, or evidence does not identify the state it came from.** Any interface claim must establish that what was measured is what is served, and evidence must identify the state it was produced from or it cannot be trusted after that state moves.
- **EC-074** *(was: 005)* — **A red is fixed by making the instrument weaker.** Forbidden and detectable: any change to a threshold, bucket, allow-list or baseline must be justified by a principle stated *before* the resulting count is known.
- **EC-075** *(was: 005)* — **A fix repairs the count but not the cause.** Each repaired red must name the mechanism that produced it, not only the symptom.
- **EC-076** *(was: 005)* — **A check cannot run because a toolchain is missing.** That is could-not-determine, never a failure of the thing being checked, and never a pass. *(The human-side counterpart is EC-068.)*
- **EC-077** *(was: 005)* — **The direction of a difference cannot be established read-only.** It is reported as determined-difference / undetermined-direction, and resolving it is an explicit decision, never an assumption.
- **EC-078** *(was: 005)* — **Two instruments disagree.** Both readings stand, with their populations stated; the disagreement is reported rather than resolved by preferring the convenient one.
- **EC-079** *(was: 005)* — **A red is declared rather than fixed.** It must name who may lift the declaration and what evidence would.
- **EC-080** *(was: 005)* — **A multi-repository campaign is only partially complete.** Partial progress is reported per repository as a remaining-defect count, never collapsed into one aggregate red and never described as a fourth, undefined state outside defect / declared / unrunnable.
- **EC-081** *(was: 005)* — **An instrument already reports clean, with nothing to declare or fix.** It still appears in the fleet summary at zero, so silence is never misread as "not yet run".
- **EC-082** *(was: 005)* — **A red previously closed as fixed or declared is contradicted by new evidence.** Reopening it is itself a recorded event, carrying the contradicting evidence and when it was found — never a silent overwrite of the prior closure.
- **EC-083** *(was: 005)* — **A declared condition's justification is never re-checked after it is written.** The fact that justified leaving something red can itself go stale; without a re-verification trigger, a justification can silently stop matching reality while the red stays masked as "declared".

**Obtainability**

- **EC-084** *(was: 005)* — **A repository shrinks below the failure threshold but keeps growing.** The size guard must warn on the trend, not only on the breach.
- **EC-085** *(was: 005)* — **A recording is unavailable to a particular engineer.** Absence of permission is a stated reason, never a broken clone.
- **EC-086** *(was: 005)* — **Recorded material moves to storage outside this repository's object store.** The new storage's access-control boundary must be at least as strict as what it replaces — nothing that was private becomes newly reachable merely because the obtainability path changed.
- **EC-087** *(was: 005)* — **An individual recorded-material transfer is interrupted mid-download.** Splitting a monolithic transfer into per-object transfers is *expected* to bound the blast radius of one failure, but that property must be demonstrated for the actual mechanism chosen, not inherited by assumption from the pack-transfer diagnosis.
- **EC-088** *(was: 005)* — **The external storage now holding recorded material approaches its own capacity or cost limit.** The repository's obtainability-cost warning does not extend to the storage that now holds the material moved out of it, so a second budget can silently fill while the first stays comfortably below threshold.

**Export, presentation and accessibility**

- **EC-089** *(was: 002)* — **The export toolchain is not installed.** Its absence must report that the export could not be performed — never that it was performed and produced nothing.
- **EC-090** *(was: 004)* — **A material file is missing.** The lesson states the material is unavailable rather than rendering a broken element.
- **EC-091** *(was: 004)* — **A visitor uses reduced-motion or high-contrast settings.** Both are honoured; neither degrades legibility below the stated floors, and a motion effect that becomes load-bearing for comprehension must not be used at all.
- **EC-092** *(was: 002, 004 — MERGED)* — **A screen-reader or keyboard-only user follows a deep link into the recording.** The jump must be reachable without a pointing device, the context change must be **announced** rather than conveyed only by a visual highlight, and returning must restore focus rather than dumping the user at the top of the page.

**Content boundary — five distinct disclosure surfaces, all of the same class**

- **EC-093** *(was: 006)* — **A session record would disclose private material.** Sections are authored from private recordings while the umbrella is public — the record must exist without content crossing that boundary.
- **EC-094** *(was: 006)* — **A QA evidence artefact would itself disclose private recorded material.** It is withheld or captured by reference instead, under the same rule that applies to session records — evidence capture is a new pathway into the same boundary and is held to the same standard, never treated as a shortcut around it.
- **EC-095** *(was: 002)* — **An exported area document leaves the platform's own storage** — copied into a wiki, attached to a message, or committed into a repository the content-boundary check does not scan. An exported document carrying private material through a different door is the same class of surface.
- **EC-096** *(was: 004)* — **Authored content would need to reference a private individual who took part in a recording.** It must do so by role or pseudonym, never by that person's real name.
- **EC-097** *(was: 004)* — **Authored content reaches a channel outside the primary reviewed route** — a share or link preview, an export, a machine-readable feed. That channel must be covered by the same publication determination as the primary route; there is no bypass for authored text.
- **EC-098** *(was: 004)* — **A material file carries embedded authoring-environment metadata** — location data, a local filesystem path, an authoring-host identifier. It must be scrubbed before publication.
- **EC-099** *(was: 007)* — **Extracted "reusable" code actually carries private content.** A generic-looking utility pulled out for a new public repository could still embed private strings, names or paths. Every extraction must pass a content-boundary review confirming zero private data **before** the public repository is created or pushed.

**Extension and pipeline**

- **EC-100** *(was: 001)* — **The extension procedure is invoked twice at the same time against the same chapter.** This is genuinely concurrent, not a sequential re-run; the second invocation must be refused rather than allowed to interleave writes with the first.
- **EC-101** *(was: 002)* — **A chapter-processing pipeline run is interrupted — killed, crashed, or the host loses power — partway through minting passages, extracting areas, or writing links.** Forbidding publication of an *incomplete input* does not reach a *crashed process* that left partially-written state behind it.

**Target architecture — decoupling**

- **EC-102** *(was: 007)* — **A module fails to decouple cleanly, leaving a partially-extracted state** (new submodule entries added but old in-tree code not yet removed, or the reverse). The umbrella-hosted copy remains the operative one until the standalone clone independently passes install and the full test suite on its own; a module is never left with no fully-working copy of itself.
- **EC-103** *(was: 007)* — **A reusable-code extraction ships before every consumer is updated.** Extraction is additive-then-cutover, not delete-then-hope — the old in-tree path keeps working until each consumer is confirmed migrated and re-tested against the extracted version.
- **EC-104** *(was: 007)* — **The shared user store is itself a new cross-module dependency.** If one module reaches standalone status before the other, a database shared with the still-coupled module would silently re-couple the two "independent" modules. The shared user store must be its own described, independently-provisionable component — never "the umbrella's database" by default.

**Target architecture — authentication and authorization**

- **EC-105** *(was: 007)* — **Plaintext credentials are committed in a public specification.** They must be treated as compromised from the moment of commit: the system must not rely on those literal values as real production secrets, must store only salted password hashes, and must never re-print a plaintext password anywhere.
- **EC-106** *(was: 007)* — **A session or token minted by one module is replayed against the other.** Because both modules read the same user table, proving identity is not sufficient — the token must also prove *for this module*.
- **EC-107** *(was: 007)* — **The auth provider or user database is unreachable at request time.** Fail closed — access denied, never silently granted, during an outage. *(Contrast EC-056: an unavailable search backend **reports** honestly and continues serving other capabilities; an unavailable auth backend **denies**. The two defaults are deliberately opposite and must not be unified.)*
- **EC-108** *(was: 007)* — **A malformed or expired token is presented.** Rejected outright, user redirected to login. It must NOT be treated as an anonymous/limited-access request — that would let a token-parsing bug violate the no-anonymous-content rule by accident rather than by design.
- **EC-109** *(was: 007)* — **A user's zero-access domains are inferred rather than enumerated.** Default-deny: anything not explicitly on the allow-list is denied, never allowed until proven sensitive.
- **EC-110** *(was: 007)* — **First-ever login / bootstrap of the seed users.** Creating the accounts is itself a privileged action. It must happen through a controlled, non-network-exposed bootstrap step, never through a self-registration endpoint reachable from the same login page.
- **EC-111** *(was: 007)* — **Many concurrent login attempts against the same account.** Rate-limited and throttled per account and per source. With only two usernames, both already public, brute-force risk is elevated rather than theoretical.
- **EC-112** *(was: 007)* — **A session predating the authentication rollout survives the cutover.** Invalidated at cutover; a cookie or session issued before secure session handling was enforced must not be grandfathered into "already authenticated".
- **EC-113** *(was: 007)* — **A user exists in zero roles or groups.** Falls back to zero access — never to admin-equivalent, and never to whatever the previous session on that browser happened to grant.
- **EC-114** *(was: 007)* — **A screen-reader or keyboard-only user hits an auth error.** Errors must be announced and every control keyboard-reachable, matching the same accessibility floor the baseline already set.
- **EC-115** *(was: 007)* — **An auth failure message reveals whether an account exists.** The message is generic, never "unknown user" versus "wrong password".
- **EC-116** *(was: 007)* — **A health-check or readiness probe is gated behind login.** Health and readiness endpoints may be exempt from authentication, but must not return content or user data of any kind.
---

## Requirements *(mandatory)*

### How to read this section

375 functional requirements existed across the seven source specifications, every one of them
numbered from its own `FR-001`. They are unified here into **337**, in one sequence, with **every
requirement carrying an explicit back-reference to its origin**. 28 merge groups fold 66 source
requirements into 28 unified ones; the remaining 309 are carried one-to-one.

- `**FR-014** (was: 002/FR-020a)` — one source, carried through.
- `**FR-260** (was: 001/FR-032, 002/FR-053, 004/FR-028, 005/FR-021, 006/FR-025)` — a merge; every
  origin is named and no origin's intent is dropped.
- Where two source requirements were **similar but not the same**, both are kept and the distinction
  is stated inline rather than smoothed away.
- Where two source requirements **contradicted** each other, the requirement below states the
  resolution and points at the Clarifications entry that justifies it.

**Part I requirements (FR-001 – FR-285) describe the baseline architecture. Part II requirements
(FR-286 – FR-337) describe the target architecture.** A requirement that serves both states says so
in its own text.

### Part I — Baseline Architecture requirements

#### Transcription and source material

- **FR-001** *(was: 001/FR-001)*: The system MUST produce a complete written transcript of each chapter's recording, covering the recording from beginning to end.
- **FR-002** *(was: 001/FR-002)*: The system MUST associate each transcript passage with a timestamp locating it in the recording.
- **FR-003** *(was: 001/FR-003)*: The system MUST explicitly mark passages that could not be transcribed with confidence, and MUST NOT substitute invented text for them.
- **FR-004** *(was: 001/FR-004)*: The system MUST produce a verification report stating measured transcript accuracy and the method used to measure it.
- **FR-005** *(was: 001/FR-005)*: The system MUST attribute passages to distinct speakers where the recording allows it, and state where it cannot.
- **FR-006** *(was: 001/FR-006)*: The system MUST preserve the original recording and all supporting materials unmodified.
- **FR-007** *(was: 001/FR-007)*: The system MUST reassemble split recordings automatically and verify their integrity against the recorded checksum before use, failing loudly on mismatch.
- **FR-008** *(was: 001/FR-056)*: If the host runs out of disk space during reassembly or transcription, the operation MUST fail loudly with a clear report and MUST NOT leave a partially written recording or transcript file that could later be mistaken for complete.
- **FR-009** *(was: 001/FR-057)*: If the checksum manifest required by FR-007 is itself missing or corrupted, reassembly MUST refuse to proceed and report that the manifest is unavailable, rather than serving an unverified file.

#### Passage identity, correction and privacy

- **FR-010** *(was: 001/FR-037)*: Every passage MUST carry a stable identifier assigned at ingest that is neither positional nor content-derived, so that cross-references and citations remain valid across re-indexing and transcript correction.
- **FR-011** *(was: 001/FR-038)*: The system MUST preserve machine-generated transcript output immutably, and MUST record for each passage whether its current text is machine-produced or human-corrected.
- **FR-012** *(was: 001/FR-039)*: The system MUST provide a documented redaction step capable of suppressing identified passages, and MUST require it to have been run before any export or publication of chapter content.
- **FR-013** *(was: 001/FR-050)*: Automated-check evidence that could contain transcript excerpts, speaker attribution, or other content derived from the private `workshop` submodule MUST be written to a location inside that submodule's own boundary, never into the public monorepo's shared evidence path. Only evidence provably free of such content MAY use the shared convention.
- **FR-014** *(was: 001/FR-051)*: **Baseline only.** Any access to the curriculum from other than the operator's own loopback interface MUST require authentication before recording, transcript, or search content is served. *(In the target architecture this is superseded by FR-294, which requires authentication unconditionally, not only beyond loopback. FR-014 is the weaker baseline floor and MUST NOT be read as licensing anonymous access once FR-294 is in force.)*

#### Chapter identity, grammar and hierarchy

- **FR-015** *(was: 003/FR-001)*: A chapter's canonical identifier MUST be its dotted, zero-padded numeric path (`01`, `02`, `02.01`) and MUST match the grammar `^[0-9]{2,}(\.[0-9]{2,})*$`.
- **FR-016** *(was: 003/FR-002)*: That one string MUST serve, unchanged and untranslated, as **all five** of: the directory name under `chapters/`, the URL path segment, the passage registry scope value, the `chapter_slug` field value, and the suffix in a `chapter-<id>` curriculum directory name. No layer MAY map it to a different form.
- **FR-017** *(was: 003/FR-003)*: Depth MUST be unbounded in the grammar. A limit MAY be measured and published; it MUST NOT be asserted.
- **FR-018** *(was: 003/FR-004)*: A directory under `chapters/` whose name does not match FR-015 MUST be reported as `unclassified`, with the reason, in every enumeration that covers it. It MUST NOT be silently skipped, and MUST NOT be silently accepted.
- **FR-019** *(was: 003/FR-005)*: The validator MUST reject a non-zero-padded component, and this rejection MUST carry a paired mutation proving the check can fail.
- **FR-020** *(was: 003/FR-006)*: `parent_id`, `depth`, `ancestor_ids`, `child_ids` and `ordinal_path` MUST all be derived from the identifier by string operation and MUST NOT be stored anywhere.
- **FR-021** *(was: 003/FR-007)*: No entity MAY carry a stored `parent_id`, a stored depth, or a stored child list. A second representation of the hierarchy is forbidden, because two representations of one fact can disagree and the disagreement has no symptom.
- **FR-022** *(was: 003/FR-008)*: `parent_id` MUST be null for a top-level chapter and `child_ids` MUST be empty for a leaf. Both MUST fall out of the derivation rather than being special-cased.
- **FR-023** *(was: 003/FR-009)*: The order of chapters MUST be byte-lexicographic on the identifier string, and this MUST be the same order produced by the filesystem, by a shell glob and by the API.
- **FR-024** *(was: 003/FR-010)*: A parent MUST sort immediately before its first child. This is a consequence of the zero-padding and of the separator sorting below the digits; it MUST NOT be implemented as a separate rule.
- **FR-025** *(was: 003/FR-011)*: The existing chapter-list comparator MUST NOT be changed. It is already correct, and a gate MUST assert the ordering rather than the code so that a future rewrite is caught.
- **FR-026** *(was: 003/FR-012)*: Every comparison of a chapter scope against a chapter id MUST be **equality**. Use of a suffix, prefix or containment test on a chapter scope is a defect.
- **FR-027** *(was: 003/FR-013)*: The redaction reviewer's equality comparison MUST be covered by a test whose fixture registry holds **at least two** scopes, one of which is a sub-chapter of the other. A single-scope fixture MUST NOT be accepted as coverage, and the paired proof MUST demonstrate that a single-scope fixture stays green under the suffix mutation.
- **FR-028** *(was: 003/FR-014)*: Every pattern matching a chapter path MUST accept a dotted id, and MUST retain paired mutations asserting **both** directions: a dotted id now matches, **and** the previously-matching flat form still matches. A widening that quietly stopped matching the flat form would be worse than the defect it fixed.
- **FR-029** *(was: 003/FR-015)*: A pattern non-match on a directory that exists MUST be reported. Skipping a non-match silently is forbidden wherever the set being iterated is the set of real chapters.
- **FR-030** *(was: 003/FR-016)*: The ingest script MUST NOT default its transcript input to any specific chapter's transcript. Omitting the transcript export while naming a chapter MUST **refuse**, naming the missing input — it MUST NOT ingest a different chapter's content under the requested scope.
- **FR-031** *(was: 003/FR-017)*: The ingest script's chapter default MUST be removed or MUST be reported on every run. A default that names a real chapter is indistinguishable, in the output, from an explicit choice.
- **FR-032** *(was: 003/FR-018)*: The transcript builder MUST NOT carry frozen chapter-01 slug or title defaults.
- **FR-033** *(was: 003/FR-019)*: The calibration script MUST resolve its recording input from a named chapter rather than from a frozen absolute path.
- **FR-034** *(was: 003/FR-020)*: The per-chapter knowledge builder MUST derive every chapter reference from the record it is processing, as one line in it already does. The frozen deep links and frozen `chapter_slug` literals MUST be derived the same way.
- **FR-035** *(was: 003/FR-021)*: The suggest source manifest MUST NOT hardcode a chapter directory. Its hardcoded rows MUST be replaced by a derivation over the chapters that exist, so a new chapter reaches the suggest surface without a rebuild of an embedded file.
- **FR-036** *(was: 003/FR-022)*: **RESOLVED by OQ-3 (2026-09-15) — restated as decided, not pending.** `ordinal_path` (`[]int`, e.g. `[2,1]` for `02.01`) is the ordering key MUST used wherever chapter ordering across depth is required; it MUST NOT collide between a parent and its child. `ordinal` (`int`) remains present, unchanged, for backward compatibility, and MUST NOT be treated as authoritative for cross-depth ordering — it is deliberately allowed to keep colliding (per `specs/003-chapter-hierarchy/decision-record.md`). Both fields MUST be served side by side on every chapter representation until a future removal of `ordinal` is explicitly scheduled (see the "for one release" gap noted in the OQ-3 Clarifications entry — not yet scheduled anywhere).
- **FR-037** *(was: 003/FR-023)*: The chapter title derivation MUST NOT render two distinct chapters with the same title.
- **FR-038** *(was: 003/FR-024)*: The endpoint's published `derivation.ordinal` string MUST be rewritten when the derivation is, and MUST continue to describe what the code actually does. It is the endpoint's honesty mechanism and it currently works; it MUST NOT be left describing a derivation that has been replaced.
- **FR-039** *(was: 003/FR-025)*: The front end's two chapter shapes MUST produce the same ordinal value for the same chapter, or the wire format MUST make the disagreement unrepresentable.
- **FR-040** *(was: 003/FR-026)*: **The chapter-hierarchy capability MUST NOT add a new route.** The information is carried by the two existing chapter endpoints. *(Scope narrowed during the merge — see Clarifications C5. As written in 003 this read as an unscoped prohibition; in a merged document that would have forbidden the lesson, assessment, area and session-record routes other capabilities require. It binds the hierarchy capability and nothing else.)*
- **FR-041** *(was: 003/FR-027)*: The chapter list MUST carry a `hierarchy` object on every row, and the top-level chapters value MUST remain a **flat array**. Nesting it would break the existing client, which reads it flat.
- **FR-042** *(was: 003/FR-028)*: The chapter list MUST accept `under`, `depth` and `include_self`, and MUST echo the filters it applied on **every** response status, including could-not-determine. A client that cannot see which filters were applied cannot distinguish an empty branch from an ignored parameter.
- **FR-043** *(was: 003/FR-029)*: An `under` value naming a chapter that does not exist MUST return `200` with an empty array and `under_resolved: false`. It MUST NOT return `404`: the request was well-formed and the route exists.
- **FR-044** *(was: 003/FR-030)*: The chapter detail endpoint MUST carry a `hierarchy` object with resolvable parent and child references, MUST replace the colliding ordinal with the ordered path, MUST fix the title, and MUST rewrite the derivation string.
- **FR-045** *(was: 003/FR-031)*: An orphaned chapter MUST be **served**, with `orphaned: true` and the missing ancestor named. It MUST NOT be hidden and MUST NOT be silently promoted to a root.
- **FR-046** *(was: 003/FR-032)*: There MUST be **no sub-chapter-specific code path anywhere**. A branch conditioned on a chapter's depth is a defect, because it means the general case was not built.
- **FR-047** *(was: 003/FR-036)*: A gate MUST detect when sibling chapter ids at the same level do not share equal digit-width in their final component, because unequal width breaks the byte-lexicographic ordering guarantee. The gate MUST report the offending ids by name. It MUST NOT reject the directories at validation time and MUST NOT auto-renumber them.
- **FR-048** *(was: 003/FR-037)*: A passage or search-index record whose scope names a chapter id with no corresponding directory MUST be reported as a **dangling reference**, distinct from `orphaned` (FR-045), which names a missing *ancestor* rather than a missing *self*. Enumeration and hierarchy derivation MUST NOT synthesize a chapter row for an id that exists only in the registry, and MUST NOT delete or hide the registry record — it remains evidence that ingestion occurred.
- **FR-049** *(was: 003/FR-038)*: An empty `chapters/` directory, or one containing only dotfiles, MUST yield `200` with an empty array. Only a `chapters/` directory that cannot be **read** MUST enter the could-not-determine state.
- **FR-050** *(was: 003/FR-039)*: `ancestor_ids` MUST be ordered root-first — the top-level ancestor first, the immediate parent last — because that is the order a breadcrumb trail renders in and the one ordering a client never has to reverse.
- **FR-051** *(was: 003/FR-040)*: `depth` MUST be interpreted as the maximum number of hierarchy levels below `under` to include, with an omitted value meaning unbounded descendants. `include_self` MUST default to `false` and, when `true`, MUST add exactly one row — `under`'s own. Both meanings MUST be documented in the same contract section as `under`.
- **FR-052** *(was: 003/FR-041)*: An `under` value that fails the FR-015 grammar MUST be treated identically to one that is grammar-valid but names no existing chapter: `200`, empty array, `under_resolved: false`. A malformed id is a special case of "does not exist," not a different failure class.
- **FR-053** *(was: 003/FR-042)*: Whether a chapter is listed MUST continue to depend only on whether its directory exists (FR-018), never on ingestion state, review state, or any other readiness signal. **No draft/published visibility distinction for chapters** is introduced. *(This is deliberately the opposite of the rule for knowledge areas in FR-127, where listing and openability are one condition. The two entities have different visibility rules on purpose, and that asymmetry is stated so it is not "fixed" by a later reader — see Clarifications C9.)*
- **FR-054** *(was: 003/FR-043)*: The cost of deriving hierarchy fields for every row MUST be measured against the corpus size present at the time of measurement. No requirement MAY assert a maximum number of chapters or siblings.

#### Curriculum structure and browsing

- **FR-055** *(was: 001/FR-008)*: The system MUST present chapters as a browsable curriculum with titles and summaries.
- **FR-056** *(was: 001/FR-009)*: Users MUST be able to read a chapter's transcript and materials, and play its recording, from within the curriculum.
- **FR-057** *(was: 001/FR-010)*: The system MUST preserve a user's position and progress within a chapter. *(Distinct from FR-118, which governs progress per knowledge area and per question set. The two are different records with different durability bounds and MUST NOT be conflated.)*
- **FR-058** *(was: 001/FR-011)*: The system MUST organise each chapter's content into navigable sections rather than a single undifferentiated document.
- **FR-059** *(was: 001/FR-012)*: The system MUST be startable and stoppable through documented commands that require no manual setup beyond what the documentation states.
- **FR-060** *(was: 001/FR-013)*: The system MUST follow the organisational conventions already established by the existing interviewing module, so that a person familiar with one can navigate the other.
- **FR-061** *(was: 001/FR-049, 004/FR-018d — MERGED)*: The system MUST present an explicit empty state — never an empty page, a blank page, or an error — when zero chapters have completed ingestion **and** when the catalogue holds zero publishable areas. That state MUST NOT by itself be treated as a build failure. *(Merged because the two source requirements state one rule for two surfaces; both surfaces are named so neither is lost.)*
- **FR-062** *(was: 001/FR-055)*: The system MUST support at least 5 concurrent users performing search and browsing without missing the suggestion and result latency targets. *(Distinct from FR-212, which states that the QA document must be completable by a single tester; the two concern different populations — learners versus testers — and neither constrains the other.)*
#### Ported knowledge model — port, do not clone

- **FR-063** *(was: 002/FR-001)*: The workshop MUST adopt the reference module's learning hierarchy — curriculum, track, module, lesson — as its curriculum spine, taking the shape from the reference rather than inventing a second one.
- **FR-064** *(was: 002/FR-002)*: The mapping between that hierarchy and the workshop's existing concepts MUST be defined explicitly and MUST NOT create a parallel hierarchy covering the same ground. A knowledge area is the workshop's module; a chapter is a *source* of material for areas, not a level above them.
- **FR-065** *(was: 002/FR-003)*: For every element taken from the reference, the design MUST record which of three it is — ported as-is, adapted, or newly designed — and why. An element recorded as "ported as-is" that in fact differs is a defect.
- **FR-066** *(was: 002/FR-004)*: **The reference supplies shape, never substance.** No content, wording, fixture, question, model answer or asset MAY be copied from the reference module into the workshop. Every workshop area, lesson and question MUST be derived from the workshop's own chapters and evidenced against the workshop's own passages.
- **FR-067** *(was: 002/FR-004a)*: The reference module is a separate private repository. Its content MUST NOT migrate into the workshop under any justification, including as a placeholder, a fixture, a template with the words left in, or an example.
- **FR-068** *(was: 002/FR-005)*: The normative definition of the ported model MUST live in a single knowledge-model contract document, and this specification and every downstream artifact MUST reference it rather than restate it, so the two cannot drift.

#### Authored subject matter

- **FR-069** *(was: 004/FR-001)*: The catalogue MUST present knowledge areas that are **authored subjects** — a named topic with a scope a practitioner would recognise — and MUST NOT present entries derived solely by extracting a term from source material.
- **FR-070** *(was: 004/FR-002)*: Every published area MUST be an AI or information-technology subject. The **evidence** for that character MUST be recorded and reviewable per area. The **topical judgement itself** is a named human checkpoint, not an automated classification. *(This is the provisional half of Amendment A2 and awaits the operator decision recorded as OQ-6.)*
- **FR-071** *(was: 004/FR-003)*: Every published area MUST carry a human-readable title, a summary describing what it covers, and at least one tag. Titles MUST NOT be, or contain, an opaque machine identifier.
- **FR-072** *(was: 004/FR-004)*: Every published area MUST expose the descriptive fields the interviewing module exposes **and that the shared curriculum library can express**. Fields the library cannot express are recorded as a named exception list with the reason for each, and MUST NOT be fabricated to satisfy this requirement.
- **FR-073** *(was: 004/FR-005)*: The set of published areas MUST be derived from the recorded source material's actual AI/IT content, and the coverage relationship between source material and published set MUST be recorded so gaps are visible.
- **FR-074** *(was: 004/FR-005a)*: The published set MUST be the authored subject set, and MUST NOT be selected by ranking areas on how often their terms occur. Evidence volume MUST be reported per area, including for thinly-evidenced areas, rather than used as a publication filter.
- **FR-075** *(was: 004/FR-005b)*: An area whose supporting evidence is thin MUST still state its evidence volume rather than presenting itself as equally supported.
- **FR-076** *(was: 004/FR-005c)*: Authored content — lesson text, questions, captions — MUST NOT name, quote, or otherwise identify a private individual who took part in a recording but is not the corpus owner. Where such a participant must be referenced, the reference MUST use a role or a pseudonym, never a real name.

#### Taxonomy extraction

- **FR-077** *(was: 002/FR-006)*: The system MUST derive its knowledge areas and terms from the indexed corpus, not from a hand-written list, and MUST record how each was derived.
- **FR-078** *(was: 002/FR-007)*: Every area and every term MUST carry a persisted identifier assigned once at creation, neither positional nor derived from its own text, following the same identity discipline the passage identifier follows.
- **FR-079** *(was: 002/FR-008)*: Every published area and every published term MUST be evidenced by at least one passage. An area or term with no evidencing passage MUST NOT be published.
- **FR-080** *(was: 002/FR-008a)*: Areas that already exist as prose in the workshop's training documentation MUST be **promoted** into the machine-readable model — given identifiers, evidenced against the corpus and reconciled with what extraction derives — rather than being ignored, duplicated, or overwritten by a fresh extraction. Where extraction and the existing prose disagree, the disagreement MUST be surfaced for a decision, not silently resolved in either direction.
- **FR-081** *(was: 002/FR-008b)*: An already-published area whose evidencing passages are reduced to zero by a later redaction MUST be automatically unpublished — or held for an explicit republication decision — and MUST NOT continue to display, export or resolve as though it still carried live evidence.
- **FR-082** *(was: 002/FR-009)*: Extraction MUST be idempotent: a second run over unchanged content MUST produce an identical taxonomy and MUST change no identifier.
- **FR-083** *(was: 002/FR-010)*: Extraction MUST account for every passage — each is either attached to at least one area or explicitly classified as unattached with a stated reason. Silent omission is forbidden.
- **FR-084** *(was: 002/FR-011)*: The system MUST distinguish a term identified with confidence from one identified with low confidence, MUST mark the latter, and MUST NOT present it as the former.
- **FR-085** *(was: 002/FR-012)*: An area evidenced only by passages flagged uncertain MUST be marked as resting on uncertain evidence.
- **FR-086** *(was: 002/FR-013)*: Term significance MUST be demonstrated by a recorded, re-derivable measure rather than asserted, and raw frequency alone MUST NOT be that measure.

#### Area materials

- **FR-087** *(was: 002/FR-014)*: Every published area MUST carry a materials document following the reference module's section skeleton — seven level-2 sections in a fixed order. The two sections whose reference wording is specific to interviewing MUST be **adapted** to the workshop's subject rather than carried over verbatim, and that adaptation MUST be recorded under FR-065.
- **FR-088** *(was: 002/FR-014a)*: Where an area's materials contain a diagram, the diagram MUST be authored as text source and rendered, never embedded as an unreproducible binary.
- **FR-089** *(was: 002/FR-015)*: Every substantive claim in an area's materials MUST carry at least one passage citation that resolves, or MUST be visibly marked as editorial framing that is not workshop content.
- **FR-090** *(was: 002/FR-016)*: An area MUST NOT be published until its publication review has been recorded. Recording *"nothing to change"* is a valid review; skipping the review is not.
- **FR-091** *(was: 002/FR-017)*: Materials MUST record for each unit of prose whether it was authored or assembled, and MUST NOT present assembled text as authored.
- **FR-092** *(was: 005/FR-014)*: A published document's primary references MUST resolve to material a reader can reach. *(Distinct from FR-089: FR-089 governs citations attached to claims; this governs a document whose principal source is withheld material, which can be true even when every individual citation is well-formed.)*

#### Lessons, assessment and learner progress

- **FR-093** *(was: 004/FR-006, 006/FR-013 — MERGED)*: Every published area MUST carry at least one lesson, lessons MUST have a defined order, and every published area MUST present those lessons **with real body content, in order**. *(Merged because 006's requirement is 004's requirement plus the word that the measured defect turned on: 339 lessons were authored and 0 carried any body content.)*
- **FR-094** *(was: 004/FR-007)*: Every lesson MUST carry a title, body content and an estimated reading time, and MUST be navigable to its neighbours without returning to the area.
- **FR-095** *(was: 004/FR-007a)*: A lesson's estimated reading time MUST be computed deterministically from its actual body content, not authored as a separate value that can drift from the content it describes.
- **FR-096** *(was: 004/FR-008, 006/FR-014 — MERGED)*: Every published area for which an authored question bank exists MUST carry an end-of-area test drawn from senior-level interview questions on that subject, presented as a **takeable test with scored per-question feedback**; an area with no such bank MUST carry **no assessment** rather than a generated one. *(This is Amendment A1, and it is the resolution of contradiction C2: 002/FR-034a required every area to carry both a short and a long question set. A fabricated question bank is worse than a missing one — it is a test a learner can fail for the wrong reason. FR-108 therefore binds areas that have an authored bank, not all areas.)*
- **FR-097** *(was: 004/FR-008a)*: Assessment questions MUST be authored against this corpus. Framing and structure may be adopted from the interviewing module; question text, options and answers MUST NOT be imported from it.
- **FR-098** *(was: 004/FR-008b)*: Every assessment MUST declare a pass threshold, and that threshold MUST be shown to the learner before the attempt begins.
- **FR-099** *(was: 004/FR-008c)*: Where a stated pass threshold applied to a question bank's size does not produce a whole number of required correct answers, the required count MUST round **up**, never down.
- **FR-100** *(was: 004/FR-009)*: A learner MUST be able to submit answers to a test and receive a score together with, for each question, whether their answer was correct and what the correct answer is.
- **FR-101** *(was: 004/FR-010)*: Until an area's lessons are complete, its test MUST be reported as unavailable with the remaining requirement stated, and the response MUST NOT contain question text, options, or correct answers.
- **FR-102** *(was: 004/FR-011)*: A submitted test result MUST be stable — re-reading it returns the same result, asserted by an automated check rather than by a manual validation step.
- **FR-103** *(was: 004/FR-012)*: Answers MUST be identified in a way that does not depend on the order options are presented in.
- **FR-104** *(was: 004/FR-012a)*: Test availability MUST be enforced where the content is served, not where it is displayed. A learner record held only in the browser MAY decide what is shown; it MUST NOT be what prevents an answer key from being sent.
- **FR-105** *(was: 004/FR-012b)*: Authored content carrying an explicit incomplete/placeholder marker MUST be excluded from publication by the same automated determination that governs FR-127, not by an author remembering to remove it before commit.
- **FR-106** *(was: 004/FR-012c)*: Authored content MUST validate against its defined structure before publication — including a lesson body so short it carries no substantive content beyond restating its title. A structural validation failure MUST be reported as a build-time finding and MUST NEVER be surfaced to a learner as a runtime error.
- **FR-107** *(was: 002/FR-034)*: The system MUST support the reference module's question kinds — multiple choice, short answer and flashcard — with the reference's difficulty and category vocabulary, taking the schema from it and the questions from the workshop's own material.
- **FR-108** *(was: 002/FR-034a)*: Every area **that carries an authored question bank** MUST carry both a **short** and a **long** question set, and the distinction MUST be a real difference in depth rather than in count: a short set checks recall of core concepts, a long set requires reasoning across more than one passage of evidence. *(Scope narrowed during the merge — see Clarifications C2 and FR-096.)*
- **FR-109** *(was: 002/FR-034b)*: Question coverage MUST be **exhaustive against the area's evidence, not against a target count**. Every lesson section of an area MUST be assessed by at least one question, and the proportion of the area's evidencing passages cited by at least one question MUST be measured and published.
- **FR-110** *(was: 002/FR-035)*: Every question MUST carry at least one passage citation. This is the property the reference module does not have, and it is mandatory here.
- **FR-111** *(was: 002/FR-036)*: A question whose citation does not resolve MUST NOT be served.
- **FR-112** *(was: 005/FR-012)*: A question citing **withheld** material MUST be repaired to cite reachable material, or removed with the removal recorded. It MUST NOT remain silently withheld. *(Distinct from FR-111, which covers a citation that does not resolve at all. A citation to withheld material resolves — to a redacted outcome — and would otherwise pass FR-111 while still reaching a learner as a silently shortened test.)*
- **FR-113** *(was: 002/FR-037)*: From any question, a learner MUST be able to reach the position its citation names and return, with their progress preserved.
- **FR-114** *(was: 002/FR-038)*: A model answer that was assembled rather than authored MUST be marked as assembled.
- **FR-115** *(was: 005/FR-013, 006/FR-015 — MERGED)*: An area without an assessment MUST state the reason to the learner. An unexplained absence is a defect.
- **FR-116** *(was: 005/FR-015)*: The structural obstacle preventing areas from carrying assessments MUST be removed, and the resulting coverage figure MUST move for that cause and be reported.
- **FR-117** *(was: 006/FR-017)*: An area whose test exists but whose lessons do not MUST surface as a finding.
- **FR-118** *(was: 002/FR-039)*: The system MUST record a learner's progress per area and per question set, and that record MUST survive a re-ingest of the content it refers to — a learner's history is not a derived artifact and MUST NOT be discarded when the curriculum is rebuilt. *(Durability is bounded by where the record lives. In the baseline, learners are anonymous and the record is per browser, so "survives a re-ingest" is a guarantee about the server-side content rebuild, **not** a guarantee across browsers, devices or cleared storage — and the interface MUST state that bound rather than imply durability it does not have. In the target architecture the record becomes user-bound and the bound is lifted, per FR-316 – FR-319. See Clarifications C4.)*

#### Materials and video anchors

- **FR-119** *(was: 004/FR-013, 006/FR-016 — MERGED)*: A lesson MUST be able to carry supporting materials — illustration, diagram, scheme, graph, and video segment — and **every** material MUST render with a caption and a text alternative.
- **FR-120** *(was: 004/FR-013a)*: A material file MUST be scrubbed of embedded authoring-environment metadata — location data, a local filesystem path, an authoring-host identifier — before publication.
- **FR-121** *(was: 004/FR-014)*: A lesson MUST be able to reference a moment or a range in a recorded session, identifying the recording, a start position, optionally an end position, and the transcript passage that corresponds to it.
- **FR-122** *(was: 004/FR-015)*: Following such a reference MUST position the recording at the referenced start, scroll the transcript so the referenced passage is in view, and visually distinguish that passage.
- **FR-123** *(was: 004/FR-015a)*: Following a video-anchor reference MUST be achievable using only a keyboard, and arrival at the referenced passage MUST be announced to assistive technology, not conveyed only by a visual highlight.
- **FR-124** *(was: 004/FR-016)*: Every reference in every published lesson MUST resolve to an existing recording and an existing passage; an unresolvable reference MUST prevent publication of that lesson rather than surfacing to a learner.
- **FR-125** *(was: 004/FR-016b)*: Every published lesson MUST visually and structurally distinguish its own authored prose from any quoted or transcribed passage it includes, so a learner cannot mistake one for the other.
- **FR-126** *(was: 004/FR-017)*: A reference that cannot be satisfied at reading time MUST tell the learner the target is unavailable rather than presenting an empty or not-found page.

#### Catalogue integrity

- **FR-127** *(was: 004/FR-018)*: An area MUST appear in the catalogue **if and only if** its detail view, its lessons and its assessment are all servable. Listing and openability are one condition, not two.
- **FR-128** *(was: 004/FR-018a)*: The publication decision MUST be computed in exactly **one** place and consumed by every surface that needs it. Sharing a vocabulary of reasons between separately-implemented decisions does **not** satisfy this — the measured cause of the catalogue/detail disagreement was two implementations that shared their reason strings and differed in their *sequence of tests*, each passing its own unit tests because nothing asserted the pair.
- **FR-129** *(was: 004/FR-018b)*: An area withheld from the catalogue MUST still be identifiable — its identifier and the reason it was withheld MUST remain retrievable, and where a name is derivable it MUST be disclosed. Withholding an area is not a reason to withhold what it is called.
- **FR-130** *(was: 004/FR-018c)*: An inconsistent build MUST be distinguishable from an editorial refusal, and one bad record MUST NOT take the catalogue down.
- **FR-131** *(was: 004/FR-018e)*: Any surface capable of exposing authored lesson or question text outside the primary reviewed route — a share or link preview, an export, a machine-readable feed — MUST be covered by the same publication determination as FR-127. There is no bypass route for authored content.
- **FR-132** *(was: 004/FR-019)*: Descriptive fields present in the catalogue listing MUST survive to the interface that presents them; a field carried by the listing and discarded before display is a defect.
- **FR-133** *(was: 004/FR-020)*: The catalogue MUST expose each subject once.
- **FR-134** *(was: 004/FR-020a)*: The effect of catalogue or corpus growth beyond its current scale on catalogue and reference-resolution response time MUST be measured, not assumed; the design MUST NOT assume a fixed ceiling, and a measured slowdown MUST be reported rather than silently tolerated.

#### Deep linking — identity, navigation and resolution

- **FR-135** *(was: 002/FR-018)*: Every relationship the system records between two addressable things MUST be traversable in both directions. A relationship that can only be followed one way MUST NOT be recorded.
- **FR-136** *(was: 002/FR-019)*: From any transcript moment, the system MUST return the areas, the lesson section and the questions attached to it, each reachable in a single step.
- **FR-137** *(was: 002/FR-020)*: From any area, lesson section or question, the system MUST return every passage that evidences it, with the position at which the evidence occurs.
- **FR-138** *(was: 002/FR-020a)*: Where a citation or a "where does this appear" traversal resolves to more than one qualifying occurrence — including mentions inside one corroboration group — the system MUST present **every** occurrence. It MUST NOT silently select one on the learner's behalf.
- **FR-139** *(was: 002/FR-020b)*: Resolving a single existing link or citation MUST meet the same 2-second, 95th-percentile latency bound established for search results, measured and published the same way, so growth of the link graph cannot silently make the more fundamental operation slow while search stays within budget.
- **FR-140** *(was: 002/FR-021)*: For media-backed evidence the position MUST be a time span, and following it MUST land within that span. Two precisions exist and the system MUST NOT conflate them: **word level**, available where a word-timing sidecar covers the material, and **segment level**, available everywhere else. Every media-backed link MUST record which precision produced it, MUST NOT present segment precision as word precision, and MUST NOT treat a word whose timing confidence is below the recorded threshold as though it were confident. *(This is the resolution of contradiction C6: spec 002's own Assumptions section still asserted segment-only precision after its starting-state table had withdrawn the "word-level timings absent" claim. FR-140 governs; the assumption is superseded.)*
- **FR-141** *(was: 002/FR-021b)*: Every position — a text-match offset pair and a media time span alike — MUST use one documented half-open interval convention (start inclusive, end exclusive), applied uniformly by every producer and every consumer. No component MAY adopt a different convention locally.
- **FR-142** *(was: 002/FR-022)*: A mention that spans a segment boundary MUST be attached to every segment it touches.
- **FR-143** *(was: 002/FR-023)*: Every link MUST resolve through one shared resolution path with **four** distinct outcomes — found, redacted, not present, and could not determine — with no fuzzy fallback, no nearest-match, and no second path.
- **FR-144** *(was: 002/FR-024)*: An unresolvable link MUST fail loudly and MUST NEVER be silently re-pointed at a different target.
- **FR-145** *(was: 002/FR-024a)*: At the learner-facing surface, the resolver's **redacted** and **not present** outcomes MUST be presented as one generic "unavailable" state. The full four-outcome distinction MUST be preserved for internal, authoring and audit surfaces, where it remains subject to FR-144's loud-failure requirement.
- **FR-146** *(was: 002/FR-025)*: All links MUST continue to resolve to their original targets after a passage's text is corrected and the content re-indexed.
- **FR-147** *(was: 002/FR-026)*: Traversal of the relationship graph MUST terminate on cyclic material and MUST NOT trap a reader.
- **FR-148** *(was: 002/FR-027)*: Redaction MUST propagate to every artifact kind — taxonomy, materials, questions, index entries, exports and stored answers — not only to displayed transcript.
- **FR-149** *(was: 002/FR-027a)*: Redaction propagation MUST include every cached or precomputed representation of a passage's text — including search match offsets and snippets computed ahead of a query — **synchronously** with the redaction. It MUST NOT wait for the next full reindex to take effect.
- **FR-150** *(was: 001/FR-018)*: The system MUST offer cross-references from any passage to related material elsewhere in the curriculum. *(Distinct from FR-135: FR-135 governs the bidirectionality of every recorded relationship; this governs the learner-facing offer of related material from a passage being read.)*

#### Full connectivity across all four content kinds

- **FR-151** *(was: 002/FR-033a)*: Four content kinds MUST be interlinked, and the requirement is not satisfied by linking any subset: **transcripts**, **the recording**, **codebases**, and **the knowledge base** (areas with their lessons and questions). Every pair that can meaningfully relate MUST be traversable in both directions — a moment in the recording to what is taught there and what tests it; an area, lesson or question to the position where it was taught; a transcript passage to the knowledge it evidences; a code passage to the moment that code was discussed; an area to the code its knowledge is realised in; and any of the four to any other, transitively, as a path rather than a dead end.
- **FR-152** *(was: 002/FR-033b)*: The join across all four kinds MUST be the **passage identifier**. A timestamp MUST NOT be used as a join key — the identifier is measured to survive both a content correction and a structural insertion; a timestamp survives neither a re-cut nor a re-transcription.
- **FR-153** *(was: 002/FR-033c)*: Search MUST cover all four kinds by meaning and by context, and MUST report where each hit occurs in the terms of the kind it came from — a time position for the recording, a text position for a transcript or document, a file and symbol position for code, and a containing area and lesson for the knowledge base.

#### Search and cross-referencing

- **FR-154** *(was: 001/FR-014)*: The system MUST return results matching a query by meaning, including when the query shares no literal words with the matched passage.
- **FR-155** *(was: 001/FR-015, 002/FR-031 — MERGED)*: The system MUST offer suggestions as the user types, and those suggestions MUST include area and term names alongside the existing kinds.
- **FR-156** *(was: 001/FR-016, 002/FR-028 — MERGED)*: The system MUST index all curriculum content types — transcripts, written documentation, source code, diagrams and schematics, the recordings themselves — **and** every content kind this work introduces: areas, lesson sections, terms and questions.
- **FR-157** *(was: 001/FR-017)*: The system MUST take a user from a search result to the exact passage in its source, with surrounding context.
- **FR-158** *(was: 001/FR-019)*: The system MUST state plainly when a search has no relevant match, and MUST NOT present unrelated results as answers.
- **FR-159** *(was: 001/FR-020, 002/FR-033 — MERGED)*: The system MUST report honestly when search is unavailable or degraded, MUST NOT render an unavailable backend as an empty result set, and MUST preserve the three-state behaviour — results, no relevant match, could not determine — across **every** new content kind.
- **FR-160** *(was: 001/FR-058)*: Indexing MUST be incremental: adding one chapter MUST index only that chapter's content and MUST NOT require rebuilding the index for chapters already indexed.
- **FR-161** *(was: 002/FR-029)*: Every search result MUST carry a locus: the unit that contains it and the position within that unit, **including the match offsets within the matched text**. A field that promises a position and never carries one MUST NOT survive this work — either it is populated, or it is removed and its absence stated.
- **FR-162** *(was: 002/FR-030)*: A locus MUST resolve. A result whose locus cannot be resolved MUST NOT be returned as though it could.
- **FR-163** *(was: 002/FR-030a)*: The reference module's search MUST NOT be ported. It is a substring scan with no ranking and no locus, and the existing search already exceeds it on both counts. This is recorded as an explicit "not ported" decision under FR-065 so a later reader does not mistake the omission for an oversight.
- **FR-164** *(was: 002/FR-032)*: Results MUST be filterable by content kind and by area, and the filter MUST be reflected in what is shown.

#### Question answering

- **FR-165** *(was: 001/FR-021)*: The system MUST answer natural-language questions about indexed content, returning citations to the passages supporting each answer.
- **FR-166** *(was: 001/FR-022)*: The system MUST decline to answer when the indexed content does not support an answer, rather than producing an unsupported one.
- **FR-167** *(was: 001/FR-023)*: The system MUST support both locally-hosted and externally-hosted answering models, selected by operator configuration.
- **FR-168** *(was: 001/FR-024)*: The system MUST NOT transmit curriculum content outside the machine when configured to use a local model.
- **FR-169** *(was: 001/FR-025)*: The system MUST continue to serve browsing and search when answering is unavailable.
- **FR-170** *(was: 001/FR-053)*: If answer generation fails or disconnects after it has started producing output, the system MUST discard the partial output rather than presenting it as the answer, and MUST report a failure.
- **FR-171** *(was: 002/FR-050)*: The known unclosed defects in question answering — the measured fabrication rate on unanswerable questions, and the undefended case where a topically related fragment that does not answer the question passes every existing check — MUST be stated in the shipped limits documentation, and MUST NOT be described as solved anywhere.
- **FR-172** *(was: 002/FR-051)*: If answering is extended to generate answers about areas, lessons or questions, a verification layer that checks the answer against the **question** — not only against the passage — MUST exist and MUST be measured before that extension is enabled.
- **FR-173** *(was: 002/FR-052)*: Where a verification layer cannot run because its prerequisite is absent on the host, it MUST report could-not-determine, and the answer MUST NOT be served as verified. A verifier that was *requested* and could not load MUST NOT silently degrade to a weaker one.
#### Chapter pipeline and extension

- **FR-174** *(was: 001/FR-026, 002/FR-033d, 002/FR-033e — MERGED)*: The system MUST provide **exactly one** documented, repeatable procedure that ingests a new chapter end to end — transcribe, mint passages, extract areas and themes, author materials, build long and short question sets, cross-reference, index and deep-link — without requiring code changes and without hand-authoring of structure. It MUST **extend** the chapter-addition path the platform already contracts rather than introducing a second, parallel way to add a chapter. *(Merged because three source requirements described one procedure; two procedures for the same act guarantee that one of them rots.)*
- **FR-175** *(was: 001/FR-027)*: The extension procedure MUST be idempotent: running it twice on the same chapter MUST NOT duplicate content and MUST change nothing.
- **FR-176** *(was: 001/FR-028, 002/FR-033g — MERGED)*: The procedure MUST report precisely what is missing when a chapter's materials are incomplete, and MUST NOT publish a partially processed chapter as though it were complete.
- **FR-177** *(was: 001/FR-029)*: Long-running processing MUST be resumable and MUST report progress, without losing completed work if interrupted.
- **FR-178** *(was: 001/FR-054)*: The extension procedure MUST detect a concurrent invocation against the same chapter and refuse the second one, rather than interleaving writes from two simultaneous runs.
- **FR-179** *(was: 002/FR-033f)*: Adding a chapter MUST **update** the taxonomy rather than replace it: areas already established keep their identifiers and gain new evidence, areas newly evidenced are added, and an area that a new chapter contradicts is surfaced for a decision rather than silently rewritten.
- **FR-180** *(was: 002/FR-033h)*: A code passage MUST carry enough information — at minimum a content hash or equivalent anchor of the code location it cites — to detect when the underlying file has changed independently of the workshop's own content. Resolving a code passage whose anchor no longer matches MUST report **could not determine** or **stale** through the same four-outcome resolver, and MUST NOT silently point the learner at code that has since changed.
- **FR-181** *(was: 002/FR-033i)*: A chapter-processing run's outputs MUST become visible **together or not at all**. An interrupted run (crash, kill, power loss) MUST NOT leave partially-written state reachable by a learner or by search.
- **FR-182** *(was: 002/FR-033j)*: Processing a new chapter MUST NOT block or degrade interactive serving of the existing, already-published taxonomy, materials, questions or search index while the run is in progress.

#### On-screen text (OCR) — specified, unbuilt

*Every requirement in this block is specified and unbuilt. They were added to spec 002 on
2026-09-02 by decision D5 and were sequenced after that specification's then-28 unbuilt tasks.*

- **FR-183** *(was: 002/FR-060)*: On-screen text recognised from a chapter recording MUST enter the corpus as a passage of the new kind `screen_text`, minted through the **same** minter as every other passage and resolved through the **same** four-outcome resolver. It MUST NOT be stored in a second registry, mint through a second minter, or carry a second identifier format.
- **FR-184** *(was: 002/FR-061)*: Each `screen_text` passage MUST carry a **visibility interval** and the **interval bound** — the sampling period the interval is accurate to. The bound MUST be recorded on the passage and carried onto every mention derived from it. It MUST NOT be omitted and MUST NOT be presented as zero.
- **FR-185** *(was: 002/FR-062)*: A mention derived from a `screen_text` passage MUST join the **existing two-valued** precision model: it declares `segment` precision and carries its interval bound. **No third precision value may be introduced**, and it MUST NOT declare `word` precision, because no per-word timing record produced its time.
- **FR-186** *(was: 002/FR-063)*: Every mention MUST declare its **modality** — spoken or on-screen. Every evidence count on which a publication, coverage or attachment figure depends MUST be taken over **corroboration groups** rather than raw mentions, so a term both spoken and displayed at one moment counts **once**. Both figures — grouped and raw — MUST be published together, and neither mention may be deleted: both MUST remain individually retrievable and individually navigable.
- **FR-187** *(was: 002/FR-064)*: OCR accuracy MUST be measured **per chapter**, against a hand-truthed ground-truth sample drawn by a recorded, seeded, reproducible rule with the population size published, on **both** axes: **textual** accuracy and **temporal** accuracy. A textual figure alone does not satisfy this requirement, because deep linking depends only on the temporal one and a text-only measurement cannot see a temporal failure at all.
- **FR-188** *(was: 002/FR-064a)*: The accuracy **budget** MUST be derived from the recorded speech-recognition calibration for the same corpus and read from it at run time, never written as a literal. Where the calibration record or the ground-truth sample cannot be read, the check MUST report **could not determine** and MUST NOT pass.
- **FR-189** *(was: 002/FR-064b)*: No OCR-derived mention may be **published** for a chapter until that chapter's accuracy measurement has been observed passing **for that chapter**. Font, resolution and compression differ between recordings, so an accuracy figure measured on one chapter is not evidence about another.
- **FR-190** *(was: 002/FR-065)*: OCR output MUST pass the content-boundary check **before** it reaches any public artifact. A screen recording displays material the transcript never contained — window titles, file paths, identifiers, a third party's name in a title bar — so this kind is a **new disclosure surface**, and a boundary check scoped to transcript text does not cover it.
- **FR-191** *(was: 002/FR-066)*: The `screen_text` kind MUST NOT be advertised as an indexed kind until it is **retrievable**, proven by a planted known target rather than by a row count. The corpus already advertises one kind with zero entries; this exists so that a second one is not created.

#### The session record

- **FR-192** *(was: 006/FR-001)*: Every chapter MUST carry four sections — meeting notes, open questions, TODO, and next meeting — each with content specific to that session.
- **FR-193** *(was: 006/FR-002)*: A chapter's record MUST be authored from that session **and every session before it**; an item raised earlier and unresolved MUST still appear.
- **FR-194** *(was: 006/FR-003)*: Every item MUST identify the session it originated in.
- **FR-195** *(was: 006/FR-004)*: A section with nothing to report MUST say so with the reason. **An empty section and an unwritten section MUST NOT be indistinguishable.**
- **FR-196** *(was: 006/FR-005)*: The four sections MUST be **served**, not only present as files, and MUST be reachable at their own routes so a section can be linked to directly.
- **FR-197** *(was: 006/FR-005a)*: A withholding rule for any section MUST be settled by the operator before that section's route is built. A route built on a guessed withholding rule publishes a judgement nobody made.
- **FR-198** *(was: 006/FR-006)*: Every session MUST have a recorded plan, so coverage can be determined at all.
- **FR-199** *(was: 006/FR-007)*: Every planned point MUST resolve to exactly one of: covered, carried forward, or explicitly dropped with a reason. **A planned point MUST NOT simply vanish.**
- **FR-200** *(was: 006/FR-007a)*: A coverage verdict MAY be proposed by a machine but MUST carry, per point, the evidence it rests on and its own confidence, and MUST be marked PROPOSED until a human confirms it. The served coverage state MUST remain undecided until confirmation — **a proposal is not a decision, and the published figure MUST NOT move because a draft exists.**
- **FR-201** *(was: 006/FR-008)*: A point not covered MUST appear in the next chapter's plan, re-planned.
- **FR-202** *(was: 006/FR-009)*: A carried-forward point MUST be **visually distinguished** from a newly raised one.
- **FR-203** *(was: 006/FR-010)*: The number of times a point has slipped MUST be visible.
- **FR-204** *(was: 006/FR-011)*: Carry-forward from the latest chapter MUST land somewhere a reader can find, even with no successor chapter.
- **FR-205** *(was: 006/FR-012)*: Carry-forward MUST be derived from recorded plan and coverage, not hand-maintained — a hand-maintained list is a list that drifts.

#### QA readiness

- **FR-206** *(was: 006/FR-018)*: A single QA document MUST exist covering every feature and flow, each step stating its expected result **before** the tester performs it.
- **FR-207** *(was: 006/FR-019)*: It MUST state how to report a discrepancy and what to capture.
- **FR-208** *(was: 006/FR-020)*: It MUST disclose every known limitation **in advance**. A tester MUST NOT discover a known limitation as if it were a defect.
- **FR-209** *(was: 006/FR-020a)*: The QA and client documents MUST record the build identifier they were written against, and MUST be **regenerated — not patched —** when that build moves. A stale expected-result column manufactures false defects and spends a tester's time disproving fixes.
- **FR-210** *(was: 006/FR-020b)*: The client-facing walkthrough MUST disclose, before a client can encounter them: the served area count against the authored total, the count of areas carrying no test with the reason, and that scores are indeterminate while any bank mixes machine-marked and free-text questions.
- **FR-211** *(was: 006/FR-021)*: Reaching a testable state MUST require only the documented steps.
- **FR-212** *(was: 006/FR-022, 006/FR-022a)*: The QA document MUST cover edge cases and failure paths, not only the paths that succeed, and every scenario MUST be completable by a **single tester acting alone**; the platform MUST NOT require concurrent multiple testers to reach or exercise a documented testable state.
- **FR-213** *(was: 006/FR-022b)*: If the platform is unreachable when a QA session begins, this MUST be treated as a blocking precondition failure. The tester records the environment as unavailable and reports it; no step that could not actually be exercised MUST be recorded as passed.
- **FR-214** *(was: 006/FR-022c)*: The QA document MUST state how a tester resumes an interrupted session from the last completed, evidenced step, rather than requiring a full restart.
- **FR-215** *(was: 006/FR-022d)*: The QA document MUST be written in plain, non-technical language, consistent with the assumption that the QA team is unfamiliar with the platform; any unavoidable technical term MUST be defined at first use.
- **FR-216** *(was: 006/FR-022e)*: The QA document itself MUST meet the same accessibility baseline required of platform materials — screen-reader-navigable structure, no meaning conveyed by colour alone.
- **FR-217** *(was: 006/FR-029a)*: If evidence capture fails for a QA step (the capture tool errors, produces no output, or produces an unreadable artefact), that step MUST be recorded as **observed-but-unevidenced** — a could-not-determine — and MUST NEVER be recorded as satisfied merely because the tester observed it happen.

#### Export

- **FR-218** *(was: 002/FR-045)*: Every published area MUST be exportable to Markdown, HTML, Word and PDF.
- **FR-219** *(was: 002/FR-046)*: The non-Markdown formats MUST be generated from the Markdown source; no format may be authored independently of the others.
- **FR-220** *(was: 002/FR-047)*: Citations MUST be preserved in every exported format.
- **FR-221** *(was: 002/FR-048)*: An area that has not passed publication review MUST NOT be exported, and the omission MUST be reported.
- **FR-222** *(was: 002/FR-049)*: When the export toolchain is unavailable, the system MUST report that export could not be performed, and MUST NOT report success over an empty or partial output.
- **FR-223** *(was: 002/FR-049a)*: Every exported area document MUST pass the same content-boundary check required of OCR output before it is written to any location outside the platform's own storage. The check MUST cover extracted taxonomy labels — area titles and term canonical forms — as well as prose, not prose alone.

#### Presentation, visual identity and accessibility

- **FR-224** *(was: 004/FR-021, 005/FR-016 — MERGED)*: The served interface MUST present a palette spanning a materially wider range of distinct hues than a two-tone scheme, across its principal surfaces.
- **FR-225** *(was: 005/FR-017)*: Every hue present MUST carry a stated classification job. No hue is added only to raise a count.
- **FR-226** *(was: 005/FR-018)*: The measured population MUST reflect the surfaces a visitor actually uses, and any change to it MUST be justified independently of its effect on the count.
- **FR-227** *(was: 004/FR-022, 005/FR-019 — MERGED)*: Every text pairing in the served interface MUST meet the normal-text contrast floor and every non-text indicator the non-text floor, in **both** light and dark presentation, measured separately.
- **FR-228** *(was: 004/FR-022a)*: Per-question correctness in a test result MUST be conveyed by a means other than colour alone — an icon or a text label — so it is legible without colour perception.
- **FR-229** *(was: 004/FR-023)*: Design decisions recorded in the design source MUST be reflected in the served interface; a claim about the interface MUST be supported by a measurement of **what is served**.
- **FR-230** *(was: 004/FR-023a)*: The served catalogue MUST declare the corpus revision it was built from, and any claim about served content MUST cite that revision. A verified on-disk state is not evidence about what is being served.
- **FR-231** *(was: 001/FR-041, 002/FR-044 — MERGED)*: The curriculum interface MUST meet WCAG 2.1 Level AA, every deep link MUST be operable by keyboard alone, and context changes MUST be announced.
- **FR-232** *(was: 001/FR-042)*: Search MUST be fully operable by keyboard alone, including entering a query, moving through suggestions, and opening a result.
- **FR-233** *(was: 001/FR-052)*: A passage marked uncertain MUST be conveyed with a text label or an icon carrying an accessible name, and MUST NOT be conveyed by colour alone.
- **FR-234** *(was: 001/FR-059)*: Playback controls — play, pause, seek, and jumping to a timestamp from a transcript passage — MUST be operable by keyboard alone and MUST expose accessible names, to the same standard FR-232 requires of search.
- **FR-235** *(was: 002/FR-040)*: The interface MUST offer the reference module's learning views — an area view, a practice view, a progress view and a study-plan view — as first-class surfaces.
- **FR-236** *(was: 002/FR-041)*: The existing chapter, transcript, recording and cross-reference capabilities MUST remain reachable, **subordinated** to the area they serve rather than removed.
- **FR-237** *(was: 002/FR-042)*: All new styling MUST resolve through the shared design-token contract, and MUST NOT write brand values literally.
- **FR-238** *(was: 002/FR-043)*: The workshop MUST have a visual identity distinguishable from the reference module, achieved through the token layer rather than by forking the component library.
- **FR-239** *(was: 002/FR-044a)*: Interaction, motion and transition behaviour MUST be taken from the platform's own ranked, sourced user-experience research rather than chosen by taste, and each interaction decision MUST name the finding it rests on. Where a proposed effect has no supporting finding, it MUST NOT ship on the grounds that it looks better.
- **FR-240** *(was: 002/FR-044b)*: Every motion effect MUST respect a reduced-motion preference, preserving the final visual state without the transition. An effect that becomes load-bearing for comprehension MUST NOT be used.

#### Obtainability — serves BOTH states

*Every requirement in this block serves the baseline (work that cannot be obtained cannot be
reviewed, run or contributed to) **and** the target architecture (a decoupled module whose value
proposition is standalone cloneability cannot ship while cloning it is what fails). See Part III,
M1.*

- **FR-241** *(was: 005/FR-001)*: The repository MUST be obtainable by a documented command that completes without a transport error on a machine that has never held it.
- **FR-242** *(was: 005/FR-002)*: Large recorded material MUST NOT be carried in the repository's own object store in a way that makes obtaining the repository fail.
- **FR-243** *(was: 005/FR-003)*: The documented way to obtain recorded material MUST be in the repository's front-door documentation, and MUST state what a reader gets and what they may not. **RESOLVED by OQ-5 (2026-09-15)**: the backend is **GitHub LFS on the same repository** (`github.com/milos85vasic/workshop_curriculum`) — no separate host, so FR-246's access-control-boundary requirement is satisfied by construction rather than by a separate verification step (there is no new boundary to verify; the repository's existing, already-confirmed-private access control governs the LFS objects too).
- **FR-244** *(was: 005/FR-004)*: An automated check MUST report the repository's obtainability cost and MUST warn **before** the point at which obtaining it fails, not after.
- **FR-245** *(was: 005/FR-005)*: Existing published history MUST NOT be rewritten to achieve any of the above — in any repository, in either architectural state.
- **FR-246** *(was: 005/FR-024)*: Moving recorded material to storage outside the repository's object store MUST NOT weaken the access-control boundary that material had before the move; nothing reachable only to a private audience today may become reachable more broadly as a side effect of solving obtainability.
- **FR-247** *(was: 005/FR-025)*: The per-object (or per-part) retryability assumed of the chosen recorded-material transfer mechanism MUST be independently verified against the actual mechanism used, not inferred from the pack-transfer diagnosis that motivated the move.

#### Red-state discipline — serves BOTH states

- **FR-248** *(was: 005/FR-006)*: Every instrument reporting a non-clean result MUST state which of three states it is in: a **defect**, a **declared condition**, or a **check that could not run**.
- **FR-249** *(was: 005/FR-007)*: A declared condition MUST carry its evidence, its reason, and who may lift it.
- **FR-250** *(was: 005/FR-008)*: A check that could not run MUST be distinguishable from both a pass and a failure, and MUST NEVER be recorded as a pass.
- **FR-251** *(was: 005/FR-009)*: A summary of the fleet MUST report defect count and declared-condition count separately and MUST NOT merge them. An instrument that reports clean still appears, at zero.
- **FR-252** *(was: 005/FR-010)*: No red may be closed by weakening the instrument. Any threshold, bucket, allow-list or baseline change MUST be justified by a principle stated **independently of its effect on the resulting count**.
- **FR-253** *(was: 005/FR-011)*: Every fix MUST name the mechanism that produced the red, not only the symptom it removed.
- **FR-254** *(was: 005/FR-011a)*: Debt spanning more than one repository MUST be partitioned by owning repository and reported per repository, never as a single number that hides where the work belongs. Partial progress is a falling defect count, never a fourth status.
- **FR-255** *(was: 005/FR-011b)*: A baselined row MUST be re-derived before it is counted as debt. A row fixed upstream and left in a baseline overstates debt and must be pruned, not carried.
- **FR-256** *(was: 005/FR-011c)*: An instrument added for a previously unprobed host MUST be three-valued, and MUST return could-not-determine when it cannot reach that host. Replacing "never asked" with "asked and could not determine" is progress; replacing it with a pass is not.
- **FR-257** *(was: 005/FR-026)*: A red closed as fixed or declared MUST be reopenable, and reopening MUST record the contradicting evidence and when it was found; a closure MUST NEVER be silently overwritten.
- **FR-258** *(was: 005/FR-027)*: A declared condition's evidence MUST be re-verified whenever the fact it cites changes, or on a stated review cadence, so its justification cannot go stale while the red stays silently masked.
#### Evidence, governance and the content boundary — serves BOTH states

- **FR-259** *(was: 004/FR-026, 005/FR-020 — MERGED)*: Every requirement in this specification MUST be covered by at least one automated check producing machine-readable evidence.
- **FR-260** *(was: 001/FR-032, 002/FR-053, 004/FR-028, 005/FR-021, 006/FR-025 — MERGED)*: Every such check MUST ship a **paired demonstration** that it reports failure when the condition it guards is broken, and that demonstration MUST work by supplying different **data** rather than by altering the check.
- **FR-261** *(was: 001/FR-033, 002/FR-054, 003/FR-034, 004/FR-027, 006/FR-024 — MERGED)*: Every check MUST report **three** outcomes — satisfied, a real finding, or could-not-determine — and a could-not-determine MUST NEVER be recorded as satisfied or as a pass.
- **FR-262** *(was: 004/FR-029, 005/FR-022 — MERGED)*: Every check whose subject is a set MUST establish that the set is non-empty **before** reporting that the set contains no defects; an absence reported over an empty set is not evidence.
- **FR-263** *(was: 004/FR-030, 005/FR-023, 006/FR-027 — MERGED)*: Any count reported about a corpus or about source material MUST be accompanied by evidence that the material did not change during the measurement.
- **FR-264** *(was: 001/FR-040, 002/FR-055 — MERGED)*: Checks MUST write their evidence to a versioned location within the repository, retained alongside the commit that produced it, rather than to transient logs. *(Which repository is governed by FR-013: anything that could carry private content goes inside the private submodule's own boundary.)*
- **FR-265** *(was: 006/FR-023)*: Every claim that a capability works MUST be supported by a machine-produced artefact.
- **FR-266** *(was: 006/FR-026)*: Evidence MUST identify the state it was produced from, and MUST state whether it measured **SOURCE** or the **SERVED** product. The two are different populations and a source measurement MUST NEVER be reported as evidence about what is served.
- **FR-267** *(was: 006/FR-026a)*: A process holding a cached snapshot of on-disk state MUST NOT assert a determined negative about that state once the snapshot may be stale. It MUST detect staleness and return could-not-determine, naming what changed. **A snapshot licenses claims about the snapshot, never about the directory.**
- **FR-268** *(was: 006/FR-028)*: Every known gap MUST be recorded with its reason and who may lift it.
- **FR-269** *(was: 006/FR-029)*: An independent review MUST confirm that no claim is unearned, and its findings MUST be recorded whether or not they are acted on.
- **FR-270** *(was: 006/FR-029b)*: Evidence artefacts MUST be retained, never silently deleted as volume grows. Archiving older evidence out of the live directory, if storage becomes a concern, is an operator decision, not an automated step.
- **FR-271** *(was: 001/FR-034, 002/FR-056 — MERGED)*: No server-side continuous-integration automation may be introduced, anywhere in the fleet, in either architectural state. *(This is the inherited governing rule that resolves contradiction C1 against 007/FR-006. See FR-291.)*
- **FR-272** *(was: 001/FR-035)*: All governance carrier documents MUST remain synchronised, and the continuation document MUST be updated alongside non-trivial changes.
- **FR-273** *(was: 001/FR-036, 007/FR-039 — MERGED)*: All work MUST be committed and pushed across the main repository and every submodule, recursively, leaving no uncommitted state.
- **FR-274** *(was: 002/FR-059, 003/FR-033 — MERGED)*: Every endpoint this work adds MUST be declared in the platform's interface contract **and** in the route manifest the server-unity verifier reads, and MUST be probed against the running binary. An endpoint built but undeclared is a failure by construction; one declared but not built must answer as a not-built route rather than being swallowed by the single-page application. The manifest MUST NOT continue to encode one chapter as the only substitutable chapter.
- **FR-275** *(was: 003/FR-035)*: Every gate that needs a chapter id MUST take it from the live tree rather than hardcoding one.
- **FR-276** *(was: 002/FR-057, 001/FR-048 — MERGED)*: **No workshop content — no transcript text, no participant name, no chapter material, no recording filename — may appear in any public repository, including this specification directory.** Content is referenced by identifier, path or shape only. Every public reusable repository this work produces MUST therefore contain zero workshop content and MUST use synthetic fixtures. *(Scope note, resolving contradiction C7: this requirement binds content **this work introduces**. The pre-existing population the fleet's content-boundary instrument already reports is governed by the red-state discipline of FR-248 – FR-258 as a declared condition with a decision packet, not by a zero target this work could not honestly claim to have met.)*
- **FR-277** *(was: 006/FR-030)*: Session records are authored from PRIVATE recorded material while the umbrella is PUBLIC. No recorded content, participant name, or verbatim transcript text may cross into the public repository. Records refer to private material by location, never by content.
- **FR-278** *(was: 006/FR-030a)*: A QA evidence artefact — screenshot, log excerpt, recording — MUST be subject to the same boundary rule FR-277 applies to session records. An artefact that would disclose private recorded material, a participant's name, or verbatim private transcript text MUST NOT be committed to the public repository; it is captured by reference (path, timestamp, redacted excerpt) instead.
- **FR-279** *(was: 006/FR-030b)*: Until the operator settles the meeting-notes withholding rule (FR-197, OQ-8), the affected route and any content depending on it MUST default to **withheld**. It MUST NOT default to guessed-and-published.
- **FR-280** *(was: 001/FR-031)*: Documentation MUST state honestly what the system cannot do, including any content it does not index and any capability that requires operator configuration.

#### Decoupling and reuse — stated in the baseline, realised in the target

*These five requirements were written in specification 001 as baseline properties of anything the
work produced. They are the design discipline that makes Part II possible at all, and they bind in
both states.*

- **FR-281** *(was: 001/FR-043, 002/FR-058 — MERGED)*: Every component and service this work produces MUST be usable independently of the workshop curriculum. A component MUST NOT depend on curriculum-specific types to function.
- **FR-282** *(was: 001/FR-044)*: Components MUST be placed where another project can consume them. Language mechanisms that forbid external import MUST NOT be used for anything identified as reusable.
- **FR-283** *(was: 001/FR-045)*: Each reusable component MUST be independently testable — its test suite MUST pass without the curriculum present.
- **FR-284** *(was: 001/FR-046)*: Before scaffolding any new component, the canonical submodule catalogue MUST be surveyed. Where an existing submodule provides the capability, or most of it, it MUST be consumed rather than reimplemented; where it is close but incomplete, the gap MUST be contributed upstream.
- **FR-285** *(was: 001/FR-047, 007/FR-023, 007/FR-024 — MERGED)*: Each genuinely new reusable component MUST live in **its own repository** under an owned organisation, with a repository on **both** GitHub and GitLab, and be consumed as a git submodule mounted at the **project root**. Nested submodules are forbidden.

### Part II — Target Architecture requirements

*Requirements FR-286 – FR-337 describe the decoupled, authenticated architecture. Nothing in Part I
depends on them. Where a Part II requirement supersedes a Part I one, both say so.*

#### Module decoupling

- **FR-286** *(was: 007/FR-001)*: The workshop module MUST be extractable as a standalone git repository with all submodules and dependencies contained within.
- **FR-287** *(was: 007/FR-002)*: The `ai_interviewing` module (user-facing name: `ai_curriculum`) MUST be extractable as a standalone git repository with all submodules and dependencies contained within.
- **FR-288** *(was: 007/FR-003, 004/FR-024 — MERGED)*: Both modules MUST be clonable and runnable on a machine with **no access to the `vasic` umbrella repository**, obtaining every dependency through their own documented bootstrap. *(Merged: 004/FR-024 stated this as a P3 baseline property of each learning module; 007/FR-003 states it as the primary objective of the migration. One requirement, two framings, and the target framing governs.)*
- **FR-289** *(was: 007/FR-004)*: Both modules MUST have their own `.gitmodules` files declaring all required submodules.
- **FR-290** *(was: 007/FR-005, 004/FR-025 — MERGED)*: Both modules MUST have independent build/install/test scripts, and **no module script MUST require the umbrella to be present in order to resolve its own paths**.
- **FR-291** *(was: 007/FR-006 — RESOLVED AGAINST)*: Each standalone module MUST carry **locally-enforced** quality gates equivalent to those the umbrella enforces — installed by a documented command, runnable by hand, and documented as bypassable only with a recorded reason — and MUST NOT introduce any active provider-side continuous-integration or continuous-delivery workflow on GitHub or GitLab. *(007/FR-006 required "independent CI/CD configuration for GitHub and GitLab". That contradicts FR-271, which restates an inherited governing rule a specification may not weaken, and which specification 001 and specification 002 both already carried. The contradiction is resolved **against 007/FR-006** and the requirement is restated as the locally-enforced equivalent that delivers the same property — every push is gated — without the prohibited mechanism. See Clarifications C1.)*
- **FR-292** *(was: 007/FR-040)*: Both modules MUST be cloned to sibling directories outside the `vasic` umbrella, and validated there.
- **FR-293** *(was: 007/FR-041)*: Both cloned modules MUST be set up, installed, tested and validated on **live running instances** — locally running containerised services using the shared containers module with a rootless runtime, not cloud deployment.

#### Authentication and authorization

- **FR-294** *(was: 007/FR-007)*: Both modules MUST have a login form as the entry point — **no content accessible without authentication**. *(This supersedes FR-014, which required authentication only beyond the operator's loopback interface. In the target architecture there is no unauthenticated path at all.)*
- **FR-295** *(was: 007/FR-008)*: Users MUST be defined in a shared user store accessible to both modules, and that store MUST be its own described, independently-provisionable component. It MUST NOT be "the `vasic` umbrella's database" by default — a database shared with a still-coupled module would silently re-couple the two modules FR-288 requires to be independent. *(Whether the store is genuinely shared or per-module is OQ-9.)*
- **FR-296** *(was: 007/FR-009)*: The system MUST support two predefined seed users, one privileged and one restricted. *(The source requirement embedded two plaintext passwords in a public specification. **Those literal values are not restated here**, are treated as compromised by FR-302, and MUST NOT be used as real production secrets.)*
- **FR-297** *(was: 007/FR-010)*: On the workshop module, **both** users MUST have full, equal access to all features and data.
- **FR-298** *(was: 007/FR-011)*: On the `ai_interviewing` module, the privileged user MUST have full access to all features and data.
- **FR-299** *(was: 007/FR-012)*: On the `ai_interviewing` module, the restricted user MUST NOT have access to employer information or GitHub-project analysis data.
- **FR-300** *(was: 007/FR-013)*: On the `ai_interviewing` module, the restricted user MUST have access to the knowledge base: areas, lessons, tests, exercises, and progress tracking. Because FR-299's denied domains are named informally rather than as a closed list, this allow-list is the **only** grant: anything not on it is denied by default (FR-314).
- **FR-301** *(was: 007/FR-014)*: Users MUST be able to sign out, ending their session completely.
- **FR-302** *(was: 007/FR-015)*: Users MUST be able to switch accounts — sign out and sign in as a different user — seamlessly.
- **FR-303** *(was: 007/FR-016)*: Access control MUST be designed for future exhaustive refinement of permission levels: a `(user, module, resource, action)` rule set, not a two-user hard-coding.
- **FR-304** *(was: 007/FR-017)*: Session management MUST be secure — HttpOnly cookies, CSRF protection, secure headers.
- **FR-305** *(was: 007/FR-042)*: Passwords MUST be stored only as salted cryptographic hashes — never in plaintext, never in a reversible form.
- **FR-306** *(was: 007/FR-043)*: Any plaintext credential value that has appeared in documentation, a specification, or commit history MUST be treated as **compromised**; production deployments MUST NOT rely on those literal values as real secrets, and a pre-deployment guard MUST refuse to start a production-flagged environment while they are still active.
- **FR-307** *(was: 007/FR-044)*: Tokens, session identifiers, and passwords MUST NEVER be written to logs, error output, crash reports, or included in a URL or query string.
- **FR-308** *(was: 007/FR-045)*: A session identifier MUST be regenerated at successful login; a pre-authentication session id MUST NOT become the authenticated session id.
- **FR-309** *(was: 007/FR-046)*: Authentication and session tokens MUST be scoped to a single module (audience-restricted); a token issued for workshop MUST be rejected by `ai_interviewing` and vice versa, even though both read the shared user store.
- **FR-310** *(was: 007/FR-047)*: On auth-provider or user-database unavailability, both modules MUST **fail closed** (deny access) rather than fail open. *(Deliberately the opposite default from FR-159, which requires an unavailable **search** backend to report honestly and keep serving. The two failure modes are not unified: denying a search is a lost capability; granting an unauthenticated request is a breach.)*
- **FR-311** *(was: 007/FR-048)*: Failed login attempts MUST be rate-limited and throttled per account **and** per source.
- **FR-312** *(was: 007/FR-049)*: Authentication failure messages MUST be generic and MUST NOT disclose whether a given username exists. The response content and shape MUST be identical for an unknown username and a known username with a wrong password.
- **FR-313** *(was: 007/FR-050)*: Health-check and readiness endpoints MAY be exempt from authentication but MUST NOT expose content or user data of any kind.
- **FR-314** *(was: 007/FR-054)*: A user record with no assigned role or permission MUST default to **zero access** (fail closed), never to admin-equivalent or inherited access.
- **FR-315** *(was: 007/FR-055)*: Any session or cookie issued before secure session handling (FR-304) was enforced MUST be invalidated at the authentication-rollout cutover.
- **FR-316** *(new, derived from the merge — see Clarifications C3)*: Bootstrap of the seed accounts MUST occur through a controlled, non-network-exposed step — a seed script or migration run by an operator — and MUST NOT be reachable through a self-registration endpoint exposed alongside the login page. *(Specification 007 resolved this in its Edge Cases but recorded no corresponding functional requirement; it is promoted here so it is testable rather than only asserted.)*

#### Progress tracking — user-bound

- **FR-317** *(was: 007/FR-018)*: Progress tracking MUST be fully implemented on the workshop module across areas, lessons, tests and exercises.
- **FR-318** *(was: 007/FR-019)*: Progress tracking MUST be fully implemented on the `ai_interviewing` module across areas, lessons, tests and exercises.
- **FR-319** *(was: 007/FR-020)*: Progress data MUST persist in the database and survive session end and process restart. *(This lifts the durability bound FR-118 states for the baseline's anonymous per-browser record.)*
- **FR-320** *(was: 007/FR-021)*: Progress tracking MUST produce deterministic test evidence.
- **FR-321** *(new, derived from the merge — see Clarifications C3)*: At the authentication cutover, any anonymous per-browser progress record created under the baseline architecture MUST be handled by a **stated, documented outcome** — migrated on an explicit learner action, or discarded with the learner told. It MUST NOT be silently merged into a user account (which would attribute one person's activity to another on a shared browser) and MUST NOT be silently discarded (which would destroy a record FR-118 promised to preserve).

#### Reusable-submodule extraction

- **FR-322** *(was: 007/FR-022)*: All reusable code MUST be identified and extracted as independent public submodules.
- **FR-323** *(was: 007/FR-025)*: The GitHub and GitLab command-line interfaces MUST be used for repository creation.
- **FR-324** *(was: 007/FR-026)*: Extracted submodules MUST be fully generic and reusable by external projects.
- **FR-325** *(was: 007/FR-027)*: Workshop and `ai_interviewing` MUST consume extracted submodules as external dependencies.
- **FR-326** *(was: 007/FR-028 — SCOPE MODIFIED)*: Every submodule declared in each module's `.gitmodules` MUST be **compared against its upstream main branch, and the comparison reported** — CURRENT, BEHIND with a classified direction, or could-not-determine. **The pin move itself remains an operator decision**, evidenced and proposed by the check but not performed by it. *(007/FR-028 required all submodules be "updated to latest main". Performed blindly that is a mutating fleet-wide operation this project treats as an operator decision, and FR-255's re-derive-before-counting discipline applies to each row. The requirement is narrowed to what a check may do on its own, and the decision it must surface. See Clarifications C8.)*
- **FR-327** *(was: 007/FR-051)*: Extraction of code from a currently-PRIVATE module into a new PUBLIC submodule MUST pass a content-boundary review confirming zero private data **before** the public repository is created or pushed.
- **FR-328** *(was: 007/FR-052)*: A module MUST NOT be decommissioned from its umbrella-hosted location until its standalone clone independently passes install **and** the full test suite; no module may be left with no fully-working copy. *(This is migration gate M4.)*
- **FR-329** *(was: 007/FR-053)*: A reusable-code extraction MUST preserve a working path for existing consumers until each is confirmed migrated and re-tested against the extracted version — extraction is additive-then-cutover, not delete-then-hope.

#### Documentation for the standalone modules

- **FR-330** *(was: 007/FR-029)*: All documentation MUST be extended and updated for both standalone modules.
- **FR-331** *(was: 007/FR-030)*: User guides, manuals, graphs, diagrams and schemes MUST be created or updated. *(The baseline's own documentation set — quick-start tutorial, user guide, operator manual, FAQ — is FR-336 and is not replaced by this.)*
- **FR-332** *(was: 007/FR-031)*: Template files and SQL definitions MUST be documented.
- **FR-333** *(was: 007/FR-032)*: Each module MUST have a complete README with clone, install and run instructions.
- **FR-334** *(was: 007/FR-033)*: Architecture diagrams MUST show module boundaries and data flows.

#### Testing and evidence in the target architecture

- **FR-335** *(was: 007/FR-034)*: All work MUST be covered by **every** constitution-supported test type — unit, integration, end-to-end, contract, performance, security and accessibility.
- **FR-336** *(was: 007/FR-035, 007/FR-036 — MERGED; and 001/FR-030 for the baseline documentation set)*: Every test MUST produce machine-readable, deterministic evidence that is programmatically verifiable without human interpretation. The system MUST additionally ship user-facing documentation covering a quick-start tutorial, a user guide, an operator manual and an FAQ.
- **FR-337** *(was: 007/FR-037, 007/FR-038 — MERGED)*: There MUST be zero tolerance for false positives, fabricated results or unearned claims in test results, and every piece of test evidence MUST be archived and traceable to the specific requirement it satisfies.

### Key Entities

*Unified from the seven sources. Where two specs described the same entity, the descriptions are
combined rather than listed twice.*

- **Chapter** *(001, 003)* — one recorded working session. Its identifier is the dotted, zero-padded numeric path, which is simultaneously its directory name, URL segment, registry scope, `chapter_slug` and `chapter-` suffix. It has a title, a summary, a recording, supporting materials, a transcript and a session record. It gains **no** stored hierarchy field.
- **Chapter Hierarchy** *(003)* — **not an entity**: a derived view. `parent_id`, `depth`, `ancestor_ids`, `child_ids` and `ordinal_path` are computed from the identifier string on demand. Named here only because the API returns it and a thing the API returns needs a defined shape.
- **Recording** *(001)* — the source audiovisual asset for a chapter. Large; stored split; has a checksum for integrity verification.
- **Transcript** *(001)* — the written record of a recording. Timestamped, optionally speaker-attributed passages, each carrying a confidence indication. Exists in two layers: the **immutable machine output** and an optional **human correction layer**. Each passage records which layer it came from.
- **Passage** *(001, 002, 003)* — the smallest addressable unit of source content: a span of transcript, a documentation section, a code region, a diagram, or on-screen text. Carries a **persisted minted identifier** that is neither positional nor content-derived. The join key for the entire graph.
- **On-Screen Text Passage** (`screen_text`) *(002)* — a passage whose text was **shown** rather than spoken. A new **kind** of Passage, not a new entity — it inherits the minter, the resolver, the redaction flag and the mention model unchanged. Carries a visibility interval and the interval bound that interval is accurate to. **Specified and unbuilt.**
- **Cross-reference** *(001)* — a directed relationship between two passages, enabling point-to-point navigation. Every one is traversable in both directions.
- **Index** *(001)* — the derived searchable representation of all passages. Rebuildable from source; never authoritative over it.
- **Supporting Material** *(001)* — non-recording chapter content: notes, documents, diagrams, code.
- **Knowledge Area** *(002, 004)* — a named AI/IT subject and the workshop's realisation of the reference module's *module* level. Has a persisted identifier, a human-readable title, a summary, tags, an ordering, its evidencing passages, an ordered set of lesson sections, its questions and its publication-review record. An area is **not** a chapter and does not live inside one; it draws evidence from any number of chapters.
- **Term** *(002)* — a named concept within one or more areas. Has a persisted identifier, a canonical form, known surface variants, a confidence marking and its evidencing passages. A term with no evidence does not exist.
- **Lesson / Lesson Section** *(002, 004)* — one addressable unit of teaching within an area. Has a title, an ordered position, body content, a computed reading time, its own citations, zero or more materials and zero or more video anchors.
- **Material** *(004)* — a supporting artefact attached to a lesson: illustration, diagram, scheme, graph or video segment. Has a kind, a caption and a text alternative.
- **Video anchor** *(004)* — a reference from a lesson into recorded material: which recording, start position, optional end position, and the corresponding transcript passage.
- **Assessment** *(004)* — the end-of-area test. Has a question bank, a pass threshold, and an availability condition tied to lesson completion.
- **Question** *(002, 004)* — one item in an assessment. Has a persisted identifier, a kind, prompt text, identified options, one or more identified correct answers, an explanation shown after submission, an authored-or-assembled marking, and — **mandatorily** — its citations. This last field is the difference from the reference module, where it does not exist.
- **Attempt** *(004)* — a learner's submission against an assessment: the answers given, a score, and per-question outcomes.
- **Mention** *(002)* — the join that carries the deep-linking feature. Relates a term or an area to a passage and records the position within it, its precision, and its modality.
- **Corroboration Group** *(002)* — the unit evidence is **counted** over. Groups mentions of one subject whose times overlap within a measured window, so a term both spoken and displayed at one moment is one piece of evidence rather than two. It changes what is counted, never what exists. **Specified and unbuilt.**
- **Catalogue** *(004)* — the served set of published areas. Its membership is defined by servability, not by a separate flag.
- **Locus** *(002)* — what a search result reports about where it is: the containing unit and the position within it. Distinct from the result itself, because the same passage can be reached through more than one containing unit.
- **Publication Review** *(002)* — the record that an area has been reviewed and may be published and exported. Has a subject, a decision, a reviewer and a time. Its absence blocks publication.
- **Session record** *(006)* — the four sections for one chapter, cumulative over all prior sessions.
- **Record item** *(006)* — one entry in a section. Has an originating session, text, status, and for a carried item a slip count.
- **Session plan** *(006)* — what a session intended to cover. The thing coverage is measured against.
- **Carry-forward link** *(006)* — the relation from an uncovered planned point to its re-planned successor, carrying the slip count.
- **QA scenario** *(006)* — one testable step: what to do, the expected result, and how to report a discrepancy.
- **Evidence artefact** *(006)* — machine-produced output supporting a claim, identifying the state it came from and whether that state was SOURCE or SERVED.
- **Red state** *(005)* — one instrument's non-clean result. Has a kind (defect / declared / unrunnable), evidence, a reason, and for a declared state, who may lift it.
- **Obtainability budget** *(005)* — the cost of obtaining the repository, with a warning threshold below the failure threshold.
- **Recorded material reference** *(005)* — a pointer from the repository to material held outside it, with instructions and a stated availability condition.
- **Declared condition** *(005)* — a red deliberately left standing, with its justification and lifting authority.
- **Query** *(001)* — a user's natural-language input, resolved either to ranked passages or to a cited answer.
- **User** *(007, target)* — an authentication principal with a username, a password **hash**, roles and permissions.
- **Module** *(007, target)* — a standalone deployable unit with its own repository, submodules, build, tests and documentation.
- **Submodule** *(007, target)* — a git submodule representing reusable code, hosted independently and publicly under an owned organisation.
- **ProgressRecord** *(007, target)* — a user's completion state for areas, lessons, tests and exercises, persisted per user per module.
- **Permission** *(007, target)* — a granular access rule mapping `(user, module, resource, action)`, designed for refinement.
- **Session** *(007, target)* — an authenticated user context with a module-scoped token, an expiration, and revocation capability.
---

## Success Criteria *(mandatory)*

178 success criteria existed across the seven source specifications. They are unified here into
**165** — nine merge groups folding 25 source criteria into 9, 153 carried one-to-one, and three
added by this merge itself (SC-160 – SC-162). Every
criterion carries a back-reference. Every criterion names the method that measures it, or inherits
the method its source stated; a criterion whose measurement is "inspection by a reviewer" says so
and states the sample size and how the sample is drawn.

**Every baseline figure quoted below is a dated observation from the source specification, not a
measurement taken during this merge.** Several are known to have moved. Re-derive before quoting.

### Transcript and source material

- **SC-001** *(was: 001/SC-001)*: A reader can read a complete chapter session as text, covering 100% of the recording's duration with every gap explicitly accounted for.
- **SC-002** *(was: 001/SC-002)*: Transcript accuracy is measured on a random sample of at least 30 passages, and the measured figure is published alongside the transcript.
- **SC-003** *(was: 001/SC-003)*: A reader can move from any transcript passage to the corresponding moment in the recording, landing within 5 seconds of the spoken content.
- **SC-004** *(was: 001/SC-004)*: A new user goes from a fresh clone to a running curriculum in under 15 minutes using only the quick-start tutorial.

### Chapter identity, ordering and hierarchy

- **SC-005** *(was: 003/SC-001)*: 100% of chapter directories are either accepted by the grammar or reported `unclassified` with a reason. **Measured by** enumerating `chapters/`, partitioning, and asserting the two counts sum to the directory count. Paired mutation: make the enumerator skip on a non-match — the check must go red.
- **SC-006** *(was: 003/SC-002)*: The validator rejects non-zero-padded, empty and malformed ids and accepts well-formed ones. **Measured by** a table-driven test over exactly those inputs. Paired mutation: relax the grammar — the rejections must fail.
- **SC-007** *(was: 003/SC-003)*: API order, glob order and filesystem byte order are **identical** over a fixture tree holding mixed-depth ids. **Measured by** capturing all three and comparing element by element. Paired mutation: sort by ordinal path numerically — the check must go red.
- **SC-008** *(was: 003/SC-004)*: A parent sorts immediately before its first child in 100% of parent/child pairs present.
- **SC-009** *(was: 003/SC-005)*: Every pipeline stage that enumerates chapters names every chapter directory in its output — as processed or as skipped-with-reason. Paired mutation: restore silent skipping in one stage — the check must go red.
- **SC-010** *(was: 003/SC-006)*: Both widened patterns match both forms. Paired mutations, both required: revert to the flat-only pattern (the dotted assertion must fail) **and** narrow to dotted-only (the flat assertion must fail).
- **SC-011** *(was: 003/SC-007)*: Ingestion never ingests one chapter's transcript under another chapter's scope. **Measured by** invoking ingestion with a chapter and no transcript export and asserting a non-zero exit naming the missing input, with **zero** records written. Paired mutation: restore the frozen default — the check must go red.
- **SC-012** *(was: 003/SC-008)*: The redaction reviewer's coverage for a parent chapter excludes its sub-chapter's artifacts. **Measured by** a **two-scope** fixture registry. Paired mutation: restore the suffix comparison — the check must go red.
- **SC-013** *(was: 003/SC-009)*: A **one-scope** fixture is proven insufficient. **Measured by** running the same suffix mutation against a single-scope fixture and asserting the test **stays green**. This criterion measures the test's own blindness.
- **SC-014** *(was: 003/SC-010)*: 0 chapter-scope comparisons in the tree use a suffix, prefix or containment test. Paired mutation: introduce one — the check must go red.
- **SC-015** *(was: 003/SC-011)*: 0 hierarchy fields are stored. **Measured by** inspecting the registry schema, the derived database and every serialised artifact. Paired mutation: persist one — the check must go red.
- **SC-016** *(was: 003/SC-012)*: For 100% of chapters, every derived field recomputes identically from the identifier alone, with no filesystem access.
- **SC-017** *(was: 003/SC-013)*: The ordinal derivation produces no collision over every chapter present plus a synthetic set of at least eight ids. Paired mutation: restore leading-digit parsing — the check must go red on the parent/child pair.
- **SC-018** *(was: 003/SC-014)*: The front end's two chapter shapes agree field-by-field on the ordinal representation. Paired mutation: restore the digits-only test in the minimal shape — the check must go red.
- **SC-019** *(was: 003/SC-015)*: 0 new routes are added by the hierarchy capability. **Measured by** diffing the route manifest's route set before and after.
- **SC-020** *(was: 003/SC-016)*: The chapters value is a flat array in 100% of responses, with no element carrying a nested chapter array.
- **SC-021** *(was: 003/SC-017)*: The filters echo is present on **every** status, including could-not-determine. Paired mutation: omit the echo on the unavailable path — the check must go red. This is the criterion that keeps a degraded backend from looking like an empty branch.
- **SC-022** *(was: 003/SC-018)*: An unknown branch filter returns `200` with `under_resolved: false`, never `404`.
- **SC-023** *(was: 003/SC-019)*: An orphaned sub-chapter is served with `orphaned: true` and names its missing ancestor. Paired mutation: filter orphans out of the list — the check must go red.
- **SC-024** *(was: 003/SC-020)*: 0 code paths branch on chapter depth. Any hit is reported with its location rather than counted.
- **SC-025** *(was: 003/SC-021)*: The maximum depth present is **measured and published**, and no depth limit is asserted anywhere.
- **SC-026** *(was: 003/SC-022)*: The existing top-level chapter id is valid under the grammar and its ordinal representation is unchanged in value for every chapter that exists today. This is the criterion that makes the change non-breaking for the corpus as it stands.
- **SC-027** *(was: 003/SC-023)*: Every deep link that resolves today still resolves after the change.
- **SC-028** *(was: 003/SC-024)*: 100% of gates added by the hierarchy capability are three-valued and carry a paired mutation.
- **SC-029** *(was: 003/SC-025)*: 0 gates hardcode a chapter id.
- **SC-030** *(was: 003/SC-026)*: A gate detects a same-level digit-width mismatch and reports the offending ids by name. Paired mutation: remove the width check — the gate must go silent on the same fixture.
- **SC-031** *(was: 003/SC-027)*: A passage whose scope names a chapter id with no corresponding directory is reported, and no chapter row is synthesized for it. Paired mutation: make the enumerator trust the registry over the filesystem — the check must go red.
- **SC-032** *(was: 003/SC-028)*: An empty, readable `chapters/` directory yields `200` and an empty array, asserted distinct from the could-not-determine state exercised separately for an unreadable directory.
- **SC-033** *(was: 003/SC-029)*: `ancestor_ids` is root-first for 100% of chapters with at least one ancestor. Paired mutation: reverse the array — the check must go red.
- **SC-034** *(was: 003/SC-030)*: A depth of 1 under a given parent returns exactly its direct children and no grandchildren; `include_self=true` adds exactly one row, the parent's own.
- **SC-035** *(was: 003/SC-031)*: A grammar-invalid branch filter returns the same shape as a well-formed-but-absent one.
- **SC-036** *(was: 003/SC-032)*: The per-request hierarchy-derivation cost is measured and published at the corpus size present; no assertion of a maximum chapter count exists anywhere in the codebase.

### Catalogue and taxonomy

- **SC-037** *(was: 004/SC-001)*: 100% of areas visible in the catalogue can be opened; the count of listed-but-unopenable areas is **0**, against a measured baseline of **817**.
- **SC-038** *(was: 004/SC-002)*: 100% of published areas are classified AI/IT by a recorded classification, against a measured baseline of **3.9%**.
- **SC-039** *(was: 004/SC-003)*: **0** published areas display an opaque machine identifier as their title, against a baseline of 3 of 4 render branches doing so.
- **SC-040** *(was: 004/SC-005)*: 100% of published areas carry a summary and at least one tag, and those fields are **visible in the interface** — not merely present in the data.
- **SC-041** *(was: 004/SC-016)*: 100% of published areas report their supporting evidence volume, including the thinly-evidenced ones; areas presenting no evidence figure number **0**.
- **SC-042** *(was: 004/SC-018)*: The served catalogue declares the corpus revision it was built from in 100% of responses, so a served-versus-on-disk discrepancy is detectable rather than silent.
- **SC-043** *(was: 002/SC-001)*: 100% of published areas and 100% of published terms have at least one evidencing passage. Paired mutation: publish an area with its mentions removed — the check must go red.
- **SC-044** *(was: 002/SC-002)*: On a random sample of at least 30 extracted terms, drawn with a recorded seed, at least 90% are judged genuine domain terms rather than extraction noise. **Measured by** a reviewer's recorded judgement sheet, stored with the seed so the sample is reproducible and the verdict challengeable.
- **SC-045** *(was: 002/SC-003)*: 100% of passages are accounted for — attached to at least one area or classified as unattached with a stated reason. The attachment *proportion* is published as a measured figure; no threshold is claimed for it, because the corpus's topical density has not been measured and inventing a threshold would be a guess.
- **SC-046** *(was: 002/SC-004)*: A second extraction run over unchanged content changes nothing: 0 identifiers reassigned, 0 areas or terms added or removed, and a byte-identical taxonomy file. Paired mutation: make one identifier depend on content — the check must go red.
- **SC-047** *(was: 002/SC-005)*: 100% of published areas contain every section of the reference skeleton.
- **SC-048** *(was: 002/SC-006)*: 100% of substantive claims in published areas either carry a resolving citation or are marked as editorial.
- **SC-049** *(was: 002/SC-007)*: 0 areas are published without a recorded publication review that is newer than the materials it reviews.
- **SC-050** *(was: 002/SC-007a)*: 0 published areas display with zero live evidencing passages. **Measured by** redacting an already-published area's last evidencing passage and asserting the area is automatically unpublished or flagged. Paired mutation: skip the post-publish check — the check must go red.

### Lessons, assessment and learner-facing completeness

- **SC-051** *(was: 004/SC-004)*: 100% of published areas carry at least one lesson; the count with none is **0**, against a baseline of all of them. 100% of published areas that have an authored question bank carry exactly one assessment.
- **SC-052** *(was: 004/SC-004a)*: Question-bank coverage is **reported on every run** as a fraction of published areas. This is a tracked figure, **not a floor**: it rises only when a bank is authored against evidence, never by generation.
- **SC-053** *(was: 006/SC-005)*: 100% of published areas present lessons with **real content**.
- **SC-054** *(was: 005/SC-010, 006/SC-006 — MERGED)*: 100% of published areas either present a takeable test or state to the learner why there is none, with the reason; unexplained absences number **0**.
- **SC-055** *(was: 005/SC-009)*: **0** questions served to a learner cite material the server withholds, down from **5**.
- **SC-056** *(was: 005/SC-011)*: The number of areas that cannot carry an assessment **for a structural reason** reaches **0**, from **25**; the number that carry none because the corpus does not support one is reported separately and honestly.
- **SC-057** *(was: 004/SC-006)*: A learner goes from opening the catalogue to receiving a scored test result **without leaving the product** and without encountering a not-found response at any step.
- **SC-058** *(was: 004/SC-009)*: Requesting an unavailable test discloses **0** question prompts, **0** options and **0** correct answers.
- **SC-059** *(was: 004/SC-017)*: 100% of assessments declare a pass threshold that is visible before the attempt begins.
- **SC-060** *(was: 004/SC-015)*: A learner completing one area's lessons and test spends no time waiting on a page that has not told them what it is doing.
- **SC-061** *(was: 002/SC-017a)*: 100% of areas **that carry an authored question bank** carry both a short and a long question set, and the two are distinguishable by depth rather than by count. **Measured by** asserting that every question in a long set cites more than one distinct passage while a short-set question may cite one. The depth test is structural on purpose — a reviewer's impression of difficulty is not reproducible, and a citation count is. *(Scope narrowed during the merge; see Clarifications C2.)*
- **SC-062** *(was: 002/SC-017b)*: 100% of lesson sections in every published area are assessed by at least one question.
- **SC-063** *(was: 002/SC-017c)*: The proportion of each area's evidencing passages cited by at least one question is **measured and published per area**, with the distribution across areas published alongside it — never as a mean alone, which is how a well-covered area conceals an empty one. No threshold is claimed, for a stated reason.
- **SC-064** *(was: 002/SC-018)*: 100% of served questions carry at least one citation that resolves. **The reference module's measured value for this property is 0%**, so this criterion is where the workshop exceeds it, and the comparison is recorded rather than claimed.
- **SC-065** *(was: 002/SC-019)*: 100% of questions whose citation is a transcript segment support a round trip — question to cited moment and back — with progress preserved. Where exhaustive traversal is impractical, a sample of at least 30 is drawn with a recorded seed and the total population is published alongside it.
- **SC-066** *(was: 002/SC-020)*: 100% of assembled model answers are marked as assembled.
- **SC-067** *(was: 004/SC-020)*: 100% of published lessons that include a quoted or transcribed passage visually and structurally distinguish it from the lesson's own authored prose, measured by an automated structural check.

### Deep linking, materials and video anchors

- **SC-068** *(was: 004/SC-007)*: 100% of video references in published lessons resolve to an existing recording and an existing passage; unresolvable references number **0**.
- **SC-069** *(was: 004/SC-008)*: Following a video reference positions the recording within **1 second** of the referenced moment and brings the referenced passage into view without further scrolling, in 100% of sampled references.
- **SC-070** *(was: 002/SC-008)*: For 100% of recorded relationships, reverse traversal returns the origin; failures number **0**.
- **SC-071** *(was: 002/SC-009)*: For 100% of media-backed citations, following the link lands inside the cited passage's own time span. The precision delivered is the segment, whose measured distribution (median 6.74 s, p95 10.78 s, maximum 20.22 s) is published **with** the result rather than smoothed into a single number.
- **SC-072** *(was: 002/SC-009a)*: For every citation or traversal with more than one qualifying occurrence, 100% of qualifying occurrences are returned. Paired mutation: make the resolver return only the first — the check must go red.
- **SC-073** *(was: 002/SC-009b)*: 100% of positions — text-match offsets and media time spans alike — are interpreted under one documented half-open convention by every producer and consumer. **Measured by** a boundary-case test that plants a match or mention whose start exactly equals the previous unit's end.
- **SC-074** *(was: 002/SC-009c)*: Resolving a single existing link meets the same 2 s, 95th-percentile bound established for search, published alongside the search figures.
- **SC-075** *(was: 001/SC-016)*: After a transcript is corrected and content re-indexed, **100%** of previously created cross-references and citations to passages the curriculum **owns** still resolve to the passage they originally referred to. This holds by construction, because a minted identifier is anchored into the source artifact itself.
- **SC-076** *(was: 001/SC-016a)*: For passages in source code the curriculum does **not** own, identity is keyed on symbol path with a rename alias table. The guarantee is weaker and is stated rather than overclaimed: **100% of stale code references fail loudly** — an unresolvable identifier returns not-found and is never silently re-pointed at different code. A rename inside the curriculum's own tree without an alias fails ingest rather than shipping a broken link. *(The split exists because an unqualified 100% across all passage kinds would have been unachievable, and discovering that during implementation would have produced either a quiet exception or a silently wrong link.)*
- **SC-077** *(was: 002/SC-010)*: After a content correction and a structural insertion, 100% of area, term, lesson, question and mention links still resolve to the same targets, compared before and after by hash.
- **SC-078** *(was: 002/SC-011)*: 100% of unresolvable links fail loudly; 0 are silently re-pointed. The paired proof makes the resolver re-point by nearest match and requires the check to go red.
- **SC-079** *(was: 002/SC-011a)*: 100% of learner-facing resolver outcomes for a **redacted** target and a **not present** target render identically, while the internal audit log still records which of the four outcomes actually occurred. Paired mutation: render the two states differently — the check must go red.
- **SC-080** *(was: 002/SC-012)*: 100% of redactions propagate to every artifact kind — taxonomy, materials, questions, index, exports and stored answers. Paired mutation: skip one propagation target — the check must go red.
- **SC-081** *(was: 002/SC-012a)*: A redaction is absent from cached and precomputed search offsets and snippets **within the same request cycle**, not only after the next full reindex. Paired mutation: serve from a cache invalidated only on the next scheduled reindex — the check must go red.
- **SC-082** *(was: 002/SC-015f)*: 100% of code passages whose underlying file has changed independently are reported as **could not determine** or **stale** rather than resolved as though nothing changed. Paired mutation: resolve it as a normal hit anyway — the check must go red.

### Search and answering

- **SC-083** *(was: 001/SC-005)*: Search suggestions appear within **200 ms** of a keystroke, measured at the 95th percentile.
- **SC-084** *(was: 001/SC-006)*: Search results return within **2 s** at the 95th percentile.
- **SC-085** *(was: 001/SC-007)*: On a benchmark set of at least 20 meaning-based queries with known expected results, at least **90%** return the expected passage in the top five.
- **SC-086** *(was: 001/SC-008)*: At least **80%** of the benchmark queries succeed when the query shares no literal words with the target passage, demonstrating meaning-based rather than keyword matching.
- **SC-087** *(was: 002/SC-013)*: 100% of content kinds are represented in the index. **Measured by** a query with a planted, known target per kind; a kind with content but zero index entries fails. Deliberately **not** a count of rows, because a row count cannot tell a populated index from a populated table nobody queries.
- **SC-088** *(was: 002/SC-014)*: 100% of returned search hits carry a locus that resolves; any hit without one fails the run.
- **SC-089** *(was: 002/SC-015)*: On a benchmark of at least 20 meaning-based queries over the new content kinds, with expected targets fixed in advance, at least 90% return the expected item in the top five, with the per-query outcome printed and not only the aggregate.
- **SC-090** *(was: 002/SC-016)*: Suggestion latency remains at or below 200 ms at the 95th percentile after the new kinds are indexed, with the measured figure published **alongside** the pre-existing figure so a regression is visible rather than merely absent.
- **SC-091** *(was: 002/SC-017)*: Search result latency remains at or below 2 s at the 95th percentile after the new kinds are indexed, by the same harness and the same before-and-after publication.
- **SC-092** *(was: 001/SC-023)*: Adding a new chapter re-indexes only that chapter — index-build time for the new chapter does not increase as prior chapters accumulate.
- **SC-093** *(was: 001/SC-009)*: 100% of citations in generated answers resolve to passages that genuinely support the claim, verified by review of a sample of at least 20 answers.
- **SC-094** *(was: 001/SC-010)*: On a set of at least 10 questions the content cannot answer, the system declines 100% of them and fabricates none.
- **SC-095** *(was: 002/SC-026)*: The shipped limits documentation names every open defect the evidence directory records, including the measured fabrication rate on unanswerable questions and the undefended topically-related-but-non-answering case. Paired mutation: remove one defect from the limits document — the check must go red.

### Full connectivity and the repeatable pipeline

- **SC-096** *(was: 002/SC-015a)*: All six traversals in the connectivity matrix are exercised and return a non-empty result wherever the underlying material exists — and where no target exists, the system says so rather than returning an empty list that reads as "nothing here". Any row with zero exercised origins **fails**, because an unexercised traversal is unmeasured, not passing.
- **SC-097** *(was: 002/SC-015b)*: **0** links in the knowledge graph are keyed on a timestamp. Paired mutation: introduce one time-keyed link — the check must go red.
- **SC-098** *(was: 002/SC-015c)*: A chapter that has never been processed goes from raw material to a complete, connected knowledge layer using only the documented procedure, with **zero hand-authoring of structure and zero code changes**, and the diff contains no manually created structural file. This is the criterion that proves the pipeline is repeatable rather than that one chapter happens to be finished.
- **SC-099** *(was: 002/SC-015d)*: Adding a chapter preserves the existing taxonomy: 0 identifiers of previously established areas or terms change, and every contradiction between new evidence and an existing area is reported rather than resolved silently. Paired mutation: make the pipeline re-derive area identifiers on each run — the check must go red.
- **SC-100** *(was: 002/SC-015e)*: An incompletely processed chapter is never published as complete. Paired mutation: make the missing input a warning — the check must go red.
- **SC-101** *(was: 002/SC-015g)*: A chapter-processing run killed partway through leaves the previously-published state fully intact and fully servable, with **0** partially-written artifacts reachable by a learner or by search. Paired mutation: make publication non-atomic — the check must go red.
- **SC-102** *(was: 001/SC-011)*: A maintainer adds a new chapter using only the documented procedure, with zero code or configuration changes, in under **30 minutes** of hands-on time.

### On-screen text (OCR) — specified and unmeasured

*These four criteria are what makes "this work cannot close until OCR accuracy is measured" a
checkable statement rather than a sentiment: each names a figure that does not exist yet, and none
can be satisfied by building the pipeline — only by running it and publishing what it produced.*

- **SC-103** *(was: 002/SC-031)*: OCR **textual** accuracy is measured and published per chapter, as word error rate and character error rate against a hand-truthed ground-truth sample drawn by a recorded seed with the population size published, scored by the same edit-distance method the speech-recognition calibration uses so the two figures are comparable rather than merely adjacent. A published figure with no recorded seed **fails**.
- **SC-104** *(was: 002/SC-032)*: OCR **temporal** accuracy is measured and published per chapter: the proportion of on-screen mentions whose declared visibility interval contains the frame at which the text was actually on screen. **Separate from SC-103 deliberately** — deep linking depends on this figure and on no other, and a perfect textual score is compatible with every interval being wrong.
- **SC-105** *(was: 002/SC-033)*: Both OCR figures are published **beside** the speech-recognition figures for the same corpus, in the same document, in the same run. An OCR figure published alone fails, because a number with nothing to compare it to is not an accuracy claim a reader can act on.
- **SC-106** *(was: 002/SC-034)*: **0** OCR-derived mentions are published for any chapter whose accuracy measurement has not been observed passing **for that chapter**. Paired mutation: publish from a chapter whose accuracy run returned could-not-determine — the check must go red.
- **SC-107** *(was: 002/SC-035)*: A term both spoken and displayed at one moment contributes **1** to its area's evidence count, not 2, while **both** mentions remain individually retrievable and navigable, and both grouped and raw figures are published. Paired mutations, both required: count raw mentions instead of groups; and widen the grouping window to the whole chapter so two genuinely distinct occurrences collapse.
- **SC-108** *(was: 002/SC-036)*: **0** occurrences of on-screen-derived text reach a public artifact without passing the content-boundary check. Paired mutation: scope the check to transcript text only — it must go red, because that is precisely the scoping that would let a window title through.

### Session record and carry-forward

- **SC-109** *(was: 006/SC-001)*: **100%** of chapters carry all four sections with session-specific content; chapters with an empty or generic section number **0**, against a baseline of 3 of 3 having none.
- **SC-110** *(was: 006/SC-002)*: **100%** of record items identify their originating session.
- **SC-111** *(was: 006/SC-003)*: **100%** of planned points resolve to covered, carried forward, or explicitly dropped; points that vanish number **0**.
- **SC-112** *(was: 006/SC-004)*: **100%** of carried-forward points are visually distinguished and show their slip count.

### QA readiness and client walkthrough

- **SC-113** *(was: 006/SC-007)*: A tester unfamiliar with the platform completes the QA document **without asking a question**, and every step's expected result was stated before they performed it.
- **SC-114** *(was: 006/SC-008)*: **100%** of known limitations are disclosed in the QA document before a tester can reach them; limitations discovered as apparent defects number **0**.
- **SC-115** *(was: 006/SC-015)*: A client-facing walkthrough of the platform completes with **0** steps that cannot be performed as described.

### Presentation and accessibility

- **SC-116** *(was: 004/SC-010, 005/SC-012 — MERGED)*: The served interface presents at least **6** distinct hue families across its principal surfaces, up from **2**, and **100%** of hues present carry a stated classification job.
- **SC-117** *(was: 004/SC-011, 005/SC-013 — MERGED)*: **100%** of text pairings meet the normal-text contrast floor and **100%** of non-text indicators meet the non-text floor, in both light and dark presentation, measured separately; failures number **0**.
- **SC-118** *(was: 001/SC-017, 002/SC-021 — MERGED)*: The curriculum interface passes an automated WCAG 2.1 Level AA audit with **zero** violations at Level A or AA; every search interaction is completable using only the keyboard; and **100%** of deep links are reachable, activatable and returnable-from by keyboard alone.
- **SC-119** *(was: 002/SC-022)*: **100%** of new styling resolves through the shared design-token contract; **0** literal brand values appear in new stylesheets. Both a token-conformance check and a literal-value scan must pass — the first proves the tokens are valid, the second proves they are actually used.
- **SC-120** *(was: 002/SC-023)*: **100%** of the existing chapter, transcript, recording and cross-reference capabilities remain reachable after the surface is reshaped, measured by a before-and-after list rather than a recollection.
- **SC-121** *(was: 002/SC-029b)*: **100%** of interaction and motion decisions in new views name the research finding they rest on; an entry with no named finding fails.

### Export

- **SC-122** *(was: 002/SC-024)*: **100%** of published areas carry all four formats. The reference module's measured coverage is 25 of 34; this criterion requires completeness, and the comparison is stated so the bar is known to be higher than the model it was taken from.
- **SC-123** *(was: 002/SC-025)*: Re-exporting an unchanged area produces documents whose **extracted text** is identical to the previous run. Extraction rather than byte comparison, because embedded timestamps make byte equality unachievable for some formats and a criterion nobody can meet is worse than none.
- **SC-124** *(was: 002/SC-024a)*: **100%** of exported area documents pass the content-boundary check, **including their extracted taxonomy labels**, before leaving the platform's own storage. Paired mutation: scope the check to prose only, excluding area titles and term names — it must go red, because that is precisely the scoping that would let a name through.

### Obtainability

- **SC-125** *(was: 005/SC-001)*: An engineer on a machine that has never held the repository obtains it by the documented command, with **0** transport failures, in **3 of 3** attempts.
- **SC-126** *(was: 005/SC-002)*: Obtaining the repository **by the documented command** costs **under 250 MB**, down from 2,624.8 MB. **This is a claim about the documented path, not about a naive full-history clone**: history rewriting is forbidden, so existing blobs remain and a full clone stays large. Stated here rather than letting the number imply a reduction it cannot deliver.
- **SC-127** *(was: 005/SC-003)*: **100%** of recorded material remains obtainable by a documented step, with **0** items lost.
- **SC-128** *(was: 005/SC-004)*: **0** commits rewrite existing published history.
- **SC-129** *(was: 005/SC-016)*: **0** items of recorded material that were unreachable to a given audience before the obtainability fix become reachable to that audience afterward, verified by comparing the new storage's access rules to the old boundary **before any push of pointers to it**.

### Red-state discipline

- **SC-130** *(was: 005/SC-005)*: **100%** of non-clean instrument results state their kind; results whose kind cannot be determined from their output number **0**.
- **SC-131** *(was: 005/SC-007)*: **0** reds are closed by weakening an instrument; every threshold or baseline change carries a principle stated independently of the count it produces.
- **SC-132** *(was: 005/SC-008)*: The count of unexplained reds — red, with no stated kind and no reason — reaches **0**, from a baseline of **11**.
- **SC-133** *(was: 005/SC-015)*: A reader answers "is this a defect, what is the evidence, what happens next" for every red from instrument output alone, without consulting a person.
- **SC-134** *(was: 005/SC-017)*: **100%** of reopened reds carry the contradicting evidence and a timestamp for when it was found.

### Evidence and governance

- **SC-135** *(was: 001/SC-012, 002/SC-027, 004/SC-013, 005/SC-014, 006/SC-011 — MERGED)*: **100%** of the requirements in this specification map to at least one automated check, and **every** such check ships a **data-driven** paired demonstration that it fails when its guarded condition is broken — with no exceptions.
- **SC-136** *(was: 001/SC-013, 002/SC-028, 004/SC-014, 005/SC-006, 006/SC-010 — MERGED)*: **100%** of checks distinguish could-not-determine from passed and failed, verified by driving each into a could-not-determine condition; checks recording a could-not-determine as a pass number **0**.
- **SC-137** *(was: 001/SC-018)*: **100%** of automated checks write their evidence to the versioned evidence location, verifiable by inspecting that location after a run.
- **SC-138** *(was: 006/SC-009)*: **100%** of capability claims resolve to a machine-produced artefact, or are explicitly marked unverified.
- **SC-139** *(was: 006/SC-012)*: Re-running any evidence producer on unchanged inputs reproduces its result **100%** of the time.
- **SC-140** *(was: 006/SC-014)*: An independent review completes and its findings are recorded; findings suppressed rather than recorded number **0**.
- **SC-141** *(was: 001/SC-014, 002/SC-030 — MERGED)*: **0** active server-side continuous-integration workflows exist anywhere in the fleet — in either architectural state.
- **SC-142** *(was: 001/SC-015)*: After completion, the main repository and every submodule report a clean working tree.
- **SC-143** *(was: 001/SC-021, 002/SC-029, 006/SC-013 — MERGED)*: **0** occurrences of private workshop content — transcript text, participant names, chapter material, recording filenames — appear in any public repository, including this specification directory, measured by the content-boundary check. *(Scope: content **this work introduces**. See FR-276 and Clarifications C7 for why a fleet-wide zero is not claimed here.)*
- **SC-144** *(was: 002/SC-029a)*: **0** occurrences of reference-module content appear anywhere in the workshop, measured by the same boundary check run in the **opposite direction**. Paired mutation: plant one reference question in a workshop bank — the check must go red. This runs both ways deliberately: one direction protects a private recording from a public repository, the other protects the workshop from shipping someone else's curriculum under its own name.
- **SC-145** *(was: 004/SC-019)*: **0** authored lesson or question characters reach a learner through a channel that bypassed the publication determination — share previews, exports, machine-readable feeds — measured by an automated check.

### Target architecture — decoupling, authentication and evidence

- **SC-146** *(was: 007/SC-001, 004/SC-012 — MERGED)*: The workshop module clones and runs on a fresh machine with no umbrella access, reaching a self-reported ready state, in **under 10 minutes** with a single command.
- **SC-147** *(was: 007/SC-002, 004/SC-012 — MERGED)*: The `ai_interviewing` module clones and runs on a fresh machine with no umbrella access, reaching a self-reported ready state, in **under 10 minutes** with a single command.
- **SC-148** *(was: 007/SC-003)*: **100%** of content on both modules requires authentication — zero anonymous access.
- **SC-149** *(was: 007/SC-004)*: The privileged user has full access on both modules; the restricted user has full access on workshop and restricted access on `ai_interviewing`, verified cell by cell against the authorization table in II.3.
- **SC-150** *(was: 007/SC-005)*: Account switching — sign out and sign in as a different user — completes in **under 3 seconds**.
- **SC-151** *(was: 007/SC-006)*: Progress tracking records and restores **100%** of user actions (lessons, tests, exercises) on **both** modules.
- **SC-152** *(was: 007/SC-007)*: All reusable code is extracted into **at least 5** public submodules under the owned organisation on **both** GitHub and GitLab.
- **SC-153** *(was: 007/SC-008)*: Every declared submodule is compared against its upstream main branch and the comparison reported with a classified direction, with **zero** version conflicts in either module's build. *(Restated from "all updated to latest main" per FR-326 and Clarifications C8: the comparison is the criterion; the pin move is an operator decision.)*
- **SC-154** *(was: 007/SC-009)*: Documentation enables a fresh user to clone, install, run and test each module without external help.
- **SC-155** *(was: 007/SC-010)*: The test suite executes in **under 5 minutes** per module and produces structured machine-readable evidence for every test.
- **SC-156** *(was: 007/SC-011)*: Evidence-validation scripts verify **100%** of test results with zero false positives.
- **SC-157** *(was: 007/SC-012)*: All commits are pushed to all remotes — GitHub and GitLab for each submodule, and the declared remotes for each module repository.
- **SC-158** *(was: 007/SC-013)*: Both modules are validated on **live running instances** — locally running containerised services — with passing health checks.
- **SC-159** *(was: 007/SC-014)*: **Zero** unresolved clarification markers remain in this specification. *(Genuine Open Questions in the table below are **not** clarification markers: they are recorded, owned decisions awaiting an operator, which is the opposite of an unresolved marker left in the text.)*
- **SC-160** *(new, derived from the merge)*: **0** modules are decommissioned from their umbrella-hosted location before their standalone clone has independently passed install and the full test suite, verified by the decommission gate FR-328 requires. *(Promoted to a measurable criterion because FR-328 is migration gate M4 and no source specification measured it.)*
- **SC-161** *(new, derived from the merge)*: **100%** of anonymous per-browser progress records existing at the authentication cutover reach a stated, documented outcome — migrated on an explicit learner action, or discarded with the learner told; records handled silently number **0**. *(Measures FR-321; see Clarifications C3.)*
- **SC-162** *(new, derived from the merge)*: **0** requirements in this specification lack a back-reference to the source specification they came from, and **0** source requirements from specifications 001–007 are absent from the unified sequence. **Measured by** a mechanical cross-check of the back-reference annotations against the seven source documents. *(This criterion exists because the merge itself is a piece of work that can be wrong, and the failure mode — a requirement silently dropped during consolidation — is invisible without it.)*
---

## Clarifications

### Inherited clarifications — recorded, not repeated

Each source specification carries its own dated Clarifications section, and those sessions are
**history this document inherits rather than replaces**. They are not restated here, because
restating them would create the second source of truth several of them exist to prevent. Read them
at their source:

| Session | Where | What it settled |
|---|---|---|
| 2026-08-31 | `001/spec.md` | Passage identity (persisted, non-positional, non-content-derived); layered human correction over immutable machine output; local-only plus a documented redaction step; evidence to a versioned directory; WCAG 2.1 AA with keyboard-operable search. |
| 2026-09-01 | `002/spec.md` | Three questions raised; two later decided. Prose authorship left **open**. |
| 2026-09-02 | `002/spec.md`, D5 | On-screen text is **in scope**; spec 002 extended **in place** rather than superseded; specify-now-build-later; and the accuracy obligation decided **with** the scope so it could not be settled by accident. Answer-against-question verification decided as build, marked unbuilt rather than blocked. |
| 2026-09-05 | `003/spec.md` | The `ordinal` type question raised and left **blocking**; the starting-state table recorded going stale within hours of being written. |
| 2026-09-07 | `004/spec.md` | The authored area set is the 37-module hand-authored lexicon, with frequency measured and **rejected** as the selector; anonymous per-browser learners with server-side gating; questions authored against this corpus only; served catalogue declares its corpus revision; pass threshold stated per area, defaulting to 70%. |
| 2026-09-08 | `005/spec.md` | Git LFS for archive parts going forward, with its honest limit stated; the 387 baselined path occurrences taken into scope as a campaign; read-only adapters written for the two unprobed hosts; the governance-pin fetch authorised with a fixed sequence. |
| 2026-09-08 | `006/spec.md` | The four session-record routes built to match the existing components; coverage proposed by an agent and reviewed by the operator, never asserted; QA documents **regenerated** not patched; client disclosure up front. |
| 2026-09-12 | `007/spec.md` | Technology stack is each module's native stack; `ai_curriculum` **is** `ai_interviewing`; "live running instances" means locally running containerised services, not cloud deployment. |
| 2026-09-15 | all seven | A brainstorm-and-resolve pass per specification, adding requirements, edge cases and success criteria and recording each resolution with its reason. Those resolutions are carried into this document's requirements with their back-references. |

### Session 2026-09-15 — the merge pass

This section records **every decision taken during the merge itself**: eight genuine cross-spec
contradictions, one deliberate asymmetry, eight user-story priority reconciliations, and the
resolutions of each. The standing instruction applied throughout is the one this repository's
earlier passes already used: **where a choice is mandatory, take the safest, most stable,
most reversible option; where the choice is genuinely irreversible, business-level or
safety-relevant, defer it to the operator rather than resolve it silently.** Everything resolvable
under that rule is resolved; everything else is in *Open Questions*.

**Nothing in this pass was measured on 2026-09-15.** Every figure carried into this document is the
dated observation its source specification recorded, and is labelled as such.

#### C1 — Provider-side CI/CD on the standalone modules — RESOLVED AGAINST 007/FR-006

- **The contradiction**: `007/FR-006` requires *"independent CI/CD configuration for GitHub and
  GitLab"* on both standalone modules. `001/FR-034` and `002/FR-056` both require that **no**
  server-side continuous-integration automation be introduced, anywhere in the fleet. These cannot
  both hold.
- **Resolved**: against `007/FR-006`. The result is **FR-291** and **FR-271**.
- **Why**: the no-server-side-CI rule is an **inherited governing rule**, restated in two of the
  seven source specifications. A consumer specification may extend an inherited rule; it may not
  weaken or override one, and the rule itself refuses the exemption vocabulary by name. `007/FR-006`
  is therefore not a competing preference — it is structurally unavailable. The property it was
  reaching for (every push is gated) is preserved by requiring the **locally-enforced equivalent**,
  installed by a documented command, runnable by hand, and documented as bypassable only with a
  recorded reason. This is the same arrangement the umbrella already uses.
- **Honest boundary**: local enforcement is genuinely weaker in one respect and this document says so
  rather than implying parity — an untracked hooks directory means a fresh clone is unprotected until
  the install command is run, and a bypass flag leaves no record. That cost is stated in FR-291 and
  in the *Assumptions* below; it is not hidden behind the resolution.

#### C2 — "Every area carries both question sets" versus "an area with no bank carries no assessment" — RESOLVED IN FAVOUR OF 004's AMENDMENT A1

- **The contradiction**: `002/FR-034a` and `002/SC-017a` require **every** area to carry both a short
  and a long question set. `004/FR-008`, as amended by Amendment A1, permits an area with lessons and
  **no** assessment where no authored question bank exists, and the measured state at the time was
  5 of 42 areas carrying a bank.
- **Resolved**: in favour of A1. The result is **FR-096**, **FR-108** and **SC-061**, all scoped to
  areas that carry an authored bank.
- **Why**: the only way to satisfy `002/FR-034a` universally would be to generate 30-odd question
  banks to satisfy a number. That is forbidden by `002`'s own FR-066 (*the reference supplies shape,
  never substance*), by `004/FR-097` (questions authored against this corpus), and by the governing
  quality rule. **A fabricated question bank is worse than a missing one: it is a test a learner can
  fail for the wrong reason.** This is the safest option in the strict sense — it cannot produce a
  wrong grade.
- **What did not weaken**: the obligation moved rather than disappearing. Bank coverage is
  **reported on every run** (SC-052) instead of being asserted and quietly unmet, and SC-063 requires
  the per-area distribution to be published rather than a mean.

#### C3 — Anonymous learners versus mandatory authentication — RESOLVED AS STATE-SCOPED, WITH A CUTOVER RULE

- **The contradiction**: `004` decides (2026-09-07, Q2) that learners are **anonymous, per browser**,
  with no sign-in, and `004/FR-012a` permits a browser-held learner record to decide what is *shown*.
  `007/FR-007` requires that **no content be accessible without authentication**. `001/FR-051`
  requires authentication only beyond the operator's loopback interface.
- **Resolved**: not as a contradiction to pick a winner in, but as an **architectural state
  transition**. `004`'s anonymity is the **baseline** (FR-014 is its floor); `007`'s mandatory
  authentication is the **target** (FR-294 supersedes FR-014 explicitly). `004/FR-012a`'s
  server-side-enforcement rule survives **both** states unchanged as FR-104, because it is about
  where a gate lives, not about who is signed in.
- **Why this is the safe resolution**: collapsing the two into one requirement would either have
  described today's platform as authenticated (a false claim about a running system) or described the
  target as anonymous (discarding the operator's stated security requirement). Scoping each to its
  own state keeps both true and makes the transition visible.
- **What the merge had to add, because no source specification covered it**: the cutover itself.
  Anonymous per-browser progress exists in the baseline and `002/FR-039` promised it would survive a
  re-ingest. At the moment authentication arrives, that record has no owner. **FR-321** requires a
  stated, documented outcome — migrated on an explicit learner action, or discarded with the learner
  told — and forbids both silent merging (which would attribute one person's activity to another on a
  shared browser) and silent discarding (which would destroy a record a requirement promised to
  preserve). **SC-161** measures it. **FR-316** likewise promotes 007's seed-account bootstrap rule
  from an edge case to a testable requirement.

#### C4 — Progress durability — RESOLVED BY SCOPING THE GUARANTEE TO WHERE THE RECORD LIVES

- **The contradiction**: `002/FR-039` states that a learner's progress record *"MUST survive a
  re-ingest of the content it refers to — a learner's history is not a derived artifact"*. `004`
  decides that progress is held per browser, anonymously. A per-browser record cannot be guaranteed
  to survive a cleared browser, a second device, or a different browser.
- **Resolved**: the durability guarantee binds the **server-side content rebuild**, not the storage
  medium. **FR-118** states this bound explicitly and requires the interface to state it too, rather
  than implying a durability it does not have. **FR-319** lifts the bound in the target architecture,
  where the record becomes user-bound and database-backed.
- **Why**: the alternative readings were to promise cross-device durability the baseline cannot
  deliver, or to drop `002/FR-039` and lose a real guarantee (that a curriculum rebuild does not wipe
  progress). Scoping keeps the guarantee that is deliverable and states the one that is not.

#### C5 — "No new route" — SCOPE NARROWED TO THE HIERARCHY CAPABILITY

- **The contradiction**: `003/FR-026` reads *"**No new route MAY be added by this feature.**"* In
  `003` that scoped to the chapter-hierarchy work. In a merged document it reads as an unscoped
  prohibition — and it would forbid the lesson routes, the assessment routes, the area routes and the
  four session-record routes that `002/FR-059`, `004` and `006/FR-005` all require.
- **Resolved**: narrowed. **FR-040** binds the hierarchy capability and nothing else, and says so.
  **FR-274** governs every route any capability does add: declared in the interface contract **and**
  in the route manifest, and probed against the running binary.
- **Why**: this is a merge artefact rather than a disagreement between the authors. The safest
  resolution is the one that preserves both original intents — no new route *for hierarchy*, and
  full declaration discipline *for everything else*.

#### C6 — Media precision — RESOLVED IN FAVOUR OF THE TWO-VALUED MODEL

- **The contradiction**: `002/FR-021` establishes a two-valued precision model (word level where a
  word-timing sidecar covers the material, segment level otherwise) after `002`'s starting-state
  table **withdrew** its earlier "word-level timings: absent" claim. But `002`'s own *Assumptions*
  section still reads *"Mention precision is the containing segment. Word-level timings do not exist
  in the registry"* — the pre-withdrawal position, left standing.
- **Resolved**: **FR-140** governs; the stale assumption is superseded and is recorded as superseded
  rather than silently dropped.
- **Why**: `002` itself documents the withdrawal and the reason it mattered — committing to
  segment-level as a *ceiling* when word-level is reachable by joining the sidecar on time. The
  assumption is the artefact of the error, not a second decision.
- **Honest boundary, carried forward**: word-level precision is **available, not uniformly
  trustworthy** — 17.4% of word records were flagged below the confidence threshold. FR-140 requires
  every link to record which precision produced it and forbids treating a below-threshold word as
  confident. `002/D5` additionally records that the word branch is **contracted and currently
  unexercised**: every deep link in that deployment resolved at segment precision.

#### C7 — "Zero private content in public repositories" versus a content-boundary gate that is red by design — RESOLVED BY SCOPING TO NEW CONTENT

- **The contradiction**: `002/SC-029` requires **0** occurrences of workshop content in any public
  repository, including the specification directory. `005` states in its *Out of Scope* that making
  the content-boundary detector green is **not** in scope — only its rows' disposition is — and its
  own starting state records a large standing population with a decision packet prepared and
  undecided.
- **Resolved**: **FR-276** and **SC-143** bind the content **this work introduces**. The pre-existing
  population is governed by the red-state discipline (FR-248 – FR-258) as a **declared condition**
  carrying its evidence, its reason and who may lift it.
- **Why this is the safe resolution**: the alternative was to inherit an unqualified zero that this
  work cannot honestly claim to have met, which would have made SC-143 the first unearned claim in
  the document. `005`'s own framing is the correct one and is adopted: **a gate a human must read is
  worth more than one that is quietly green**, and a red that is declared with its evidence is a
  different object from a red that is a defect.
- **What was NOT done**: no row was judged, allow-listed, redacted or re-baselined by this merge, and
  no claim is made about the standing population's disposition.

#### C8 — "All submodules updated to latest main" — SCOPE MODIFIED TO EVIDENCE-THEN-OPERATOR-DECISION

- **The contradiction**: `007/FR-028` requires that all submodules declared in `.gitmodules` be
  *"updated to latest main branch"*, and `007/SC-008` measures that as done. `005/FR-011b` requires a
  baselined row to be re-derived before it counts, `005/FR-011c` requires a probe that cannot reach
  its host to return could-not-determine, and this project treats a gitlink pin move as an operator
  decision rather than a side effect of a check.
- **Resolved**: **FR-326** narrows the requirement to what a check may do on its own — compare each
  declared submodule against its upstream and **report** CURRENT, BEHIND with a classified direction,
  or could-not-determine — and states that the **pin move itself remains an operator decision**,
  evidenced and proposed by the check but not performed by it. **SC-153** measures the comparison
  rather than the move.
- **Why this is the safe resolution**: a fleet-wide blind update is a mutating operation across
  repositories this work does not own, performed without classifying direction. The failure mode is
  not theoretical — this project's own records show a pin whose difference was *determined* while its
  *direction* was not, precisely because the remote object was absent locally. Reporting the
  difference is the whole value; performing the move is the decision.

#### C9 — Chapters are listed regardless of readiness; areas are listed only if servable — A DELIBERATE ASYMMETRY, RECORDED SO IT IS NOT "FIXED"

- **The apparent contradiction**: `003/FR-042` requires chapter listing to depend **only** on whether
  the directory exists — never on ingestion state or review state — and explicitly forbids a
  draft/published distinction for chapters. `004/FR-018` requires an area to appear in the catalogue
  **if and only if** it is fully servable.
- **Resolved**: both stand, as **FR-053** and **FR-127**, and the asymmetry is stated in FR-053's own
  text so a later reader does not resolve it by making one match the other.
- **Why they are not the same rule**: a chapter is a **fact about the tree** — a directory that
  exists, whose existence a pipeline stage must never silently omit (FR-018, User Story 7). An area is
  a **published artefact** whose listing is a promise that it can be opened — and the measured defect
  that `004` exists to remedy was exactly a list that promised 819 openable things and refused 817 of
  them. Hiding a chapter would lose content that exists; listing an unopenable area is a broken
  promise. **Different entities, different failure modes, opposite correct answers.**

#### Priority reconciliations taken during the merge

Eight source user stories were merged in pairs. In four of those pairs the two sources carried
different priorities. Each was resolved to the **more urgent** of the two, with the reason recorded
inline in the merged story:

| Merged story | Source priorities | Resolved to | Reason |
|---|---|---|---|
| US11 — works through an area and is tested | `004/US2` P1, `002/US4` P4 | **P1** | The measured state was 339 authored lessons with zero body content; the teaching half is missing substance, not a later refinement. |
| US24 — add a chapter, get the whole knowledge layer | `001/US5` P5, `002/US7` P7 | **P5** | One procedure; the later numbering reflected position in a seven-story list rather than lower value. |
| US26 / US27 — modules run standalone | `007/US1`+`US2` P1, `004/US6` P3 | **T-P1** | The same journey; Part II makes it a primary objective rather than a nice property. |
| US10, US17, US19, US20 | both sources P1/P1, P2/P2, P2/P2, P3/P3 | unchanged | No conflict; merged on subject, priority already agreed. |

Two stories were deliberately **kept separate** where a naive merge would have joined them:

- **US19 (palette and contrast, P2)** and **US23 (learning-surface shape, P5)**. `004/US5` and
  `005/US4` measure one number with one method and are merged into US19. `002/US5` is a different
  subject — the composition of the learning views. Merging all three would have raised palette work
  to P5 or dropped surface work to P2, and both would have been wrong.
- **US13 (the link graph and its resolver, P2)** and **US14 (the landing experience, P2)**. The first
  specifies bidirectionality, resolution outcomes and multi-occurrence behaviour; the second specifies
  what a learner sees and hears on arrival, including keyboard operation and assistive-technology
  announcement. Same priority, different testable surfaces.

#### One instruction this merge followed and states openly

Where a source specification recorded a **withdrawn claim, a corrected figure, a refuted hypothesis
or a superseded reading**, the withdrawal is carried into this document rather than the tidy version
of the fact. Specifically: `001`'s withdrawn search-latency figure (EC-056), `002`'s withdrawn
"word-level timings absent" claim (C6, FR-140), `003`'s record of its own starting-state table going
stale within hours (Context), `005`'s refuted HTTP/2 hypothesis (Assumptions), and `006`'s corrected
S4 row (Context). **A merged document that quietly kept only the corrected numbers would have
discarded the most useful thing the seven specifications produced**, which is a record of how each
wrong reading was caught.

### OQ-3 resolved during this pass

OQ-3 (`Chapter.ordinal` typing and the path-key contradiction) was marked **BLOCKING** by this
merge on the evidence available in the seven source `spec.md` files alone — specifically `003`'s
own text, which still carried the pre-decision framing (three costed options, none chosen). That
framing was stale. Two artifacts this merge had not yet read at the time OQ-3 was drafted settle
it:

- **`specs/003-chapter-hierarchy/decision-record.md`**, dated **2026-09-13**, formally chose
  option (a)-adjacent: **keep `Chapter.ordinal` as `int`, unchanged (zero-diff), and add
  `ordinal_path` (`[]int`) as the new canonical, collision-free ordering key.** All three options
  OQ-3 names were costed there: sub-chapters with no ordinal makes them permanently unorderable;
  flattening into one number space forces unbounded, non-reversible renumbering of every existing
  chapter on the first sub-chapter insert, breaking deep links, scopes and archived artifacts.
  Keeping `int` unchanged was chosen because it touches nothing that already reads `ordinal` —
  front-end `models.ts`, the registry schema, archived artifacts — while `ordinal_path` becomes the
  field anything depth-sensitive is required to use instead.
- Both amendments the decision implies were **already applied** before this merge began: `Chapter`
  in `specs/001-workshop-curriculum-platform/data-model.md` carries both `ordinal` and
  `ordinal_path` today, and `specs/001-.../contracts/http-api.md` names the dotted id as the single
  path key (the "not accepted as a path key" contradiction OQ-3 names is closed).
- The decision's own words are an honest acknowledgement, not an oversight: *"the zero-diff option
  is the only one that makes the defect permanent"* — `ordinalOf` still returns the same int for
  `02` and `02.01`; nothing was ever asked to stop reading it that way, only to stop being the
  ordering authority.
- **One thing the decision-record does not state, and this merge does not invent an answer to
  (§11.4.6):** the live server code that places `ordinal` and `ordinal_path` beside each other on
  the wire carries its own comment scoping this to **"for one release"** — implying a planned
  future removal of `ordinal` that no artifact seen during this merge names a version or date for.
  That is a genuine gap, distinct from OQ-3, and is not resolved here — see the note this pass adds
  to task T184.

**Resolution: OQ-3 is RESOLVED, not open.** It is kept in the Open Questions table below, marked
accordingly, for traceability — FR-036, migration gate M0, and tasks T176/T177/T184 all cite it by
number, and renumbering the remaining fourteen items to remove its row would break every one of
those citations for no benefit. Migration gate M0 is satisfied.

### OQ-5 resolved during this pass

Unlike OQ-3, this was not a documentation-sync error — no decision existed anywhere before the
operator was asked. Investigated first: no `.lfsconfig`, no `git-lfs`-tracked `.gitattributes`
rule, and no decision-record equivalent to `003`'s exist in the `workshop` repository or in
`specs/005`. The 2026-09-08 clarification this question inherits from fixed the *mechanism* (Git
LFS) but explicitly left the *host* undecided, and getting the host wrong is a push-time,
irreversible privacy event — the exact class of incident this repository already has on record as
unrecoverable once it happens. That combination — genuinely no precedent, genuinely irreversible if
wrong — is exactly the case this document's own standing rule reserves for the operator rather than
a silent safest-default.

**Put to the operator directly, with an investigated recommendation** (GitHub LFS on the repository's
own already-private origin — introduces no new host and therefore nothing new to verify — versus a
self-hosted server, a different named provider, or holding the decision open). **The operator chose
the recommended option: GitHub LFS on `github.com/milos85vasic/workshop_curriculum`, the same
repository, not a third-party host.** This satisfies FR-246 (the access-control boundary MUST NOT
weaken) by construction — the LFS objects live under the identical access control the repository's
private visibility already provides, so there is no second boundary to independently verify. FR-243
now names the resolved backend explicitly.

**Left honest rather than assumed:** whether sufficient GitHub LFS storage and bandwidth quota is
actually provisioned for this corpus — 1.8GB+ per chapter today, growing with every future chapter
— was not checked as part of this decision. That is an operational capacity question, distinct from
the privacy question OQ-5 asked, and is not resolved here.

---

## Open Questions

**Thirteen** genuinely unresolved items across the seven specifications, deduplicated, plus two
raised by the merge itself (fifteen total rows below, two — OQ-3 and OQ-5 — since **RESOLVED**, see
Clarifications "OQ-3 resolved during this pass" and "OQ-5 resolved during this pass"; kept in this
table, not renumbered, for traceability). **None of the thirteen open rows is a clarification
marker left in the text**; each is an owned decision awaiting an operator, and each states why it
could not be resolved under the safest-option rule.

| # | Question | Origin | Why it cannot be resolved here |
|---|---|---|---|
| **OQ-1** | If the third party identifiable in the Chapter 1 recording requests that their contribution be removed, or withdraws consent, what specific action must the system take — full deletion of the source material, redaction-only, or something else — and within what timeframe? | 001/OQ-1 | A consent and privacy question about a real relationship, not a re-openable engineering default. The technically "safest" answer (support full deletion) conflicts with FR-006's preserve-the-original guarantee and with SC-002's requirement that accuracy remain re-measurable against the source. Only the operator can decide which guarantee yields. |
| **OQ-2** | How is area prose produced — **(a)** extractive only, assembled entirely from cited passages and fixed templated connective text; **(b)** agent- or human-authored at build time with citations for every claim and a review gate; or **(c)** platform-generated at run time? | 002, still OPEN | The three differ by an order of magnitude in scope and risk: (a) needs no model and no review workflow; (b) needs a review-and-publication gate; (c) needs a generative model, a grounding pipeline and a fabrication measurement before anything may be published. This is a scope and risk decision, not a default. |
| **OQ-3** | **RESOLVED 2026-09-15** (was BLOCKING). How is `Chapter.ordinal` typed, and what is the chapter path key? **Decided**: keep `ordinal` as `int`, unchanged (zero-diff); add `ordinal_path` (`[]int`) as the canonical, collision-free ordering key; the dotted chapter id is the single path key. See Clarifications, "OQ-3 resolved during this pass" for the full evidence and the one residual gap (an unstated sunset for the transitional both-fields wire state) it does *not* claim to resolve. | 003 | **No longer applicable** — this row is retained for traceability only. The decision was made in `specs/003-chapter-hierarchy/decision-record.md` on 2026-09-13, before this merge began; this merge's own drafting of OQ-3 from `003/spec.md`'s stale pre-decision text was itself the error, corrected here on discovering the decision-record. |
| **OQ-4** | Whether, and how, to detect a substantive **contradiction** between two pieces of authored content about the same subject — for example a lesson stating one trade-off and an assessment's explanation stating the opposite. | 004 | Irreversible in the same way the topicality judgement is: an automated contradiction checker risks a confident false pass on a genuinely conflicting pair, or a confident false finding on two claims that are merely differently framed. Either failure reaches a learner as a silent defect or as eroded trust in every other automated check. The safe default already in force is human review at authoring time; automating further is an operator decision. |
| **OQ-5** | **RESOLVED 2026-09-15** (operator decision). Which external storage backend holds the recorded material once it leaves the repository's object store, and has that backend's own access configuration been verified to keep private material private **before** any pointer or content referencing it is pushed? **Decided**: GitHub LFS on the **same** private repository (`github.com/milos85vasic/workshop_curriculum`), not a third-party host. This was the operator's own selection among the options offered, chosen specifically because it introduces no new host and therefore no new access-control surface to verify — the LFS objects inherit the repository's already-confirmed-private setting automatically. One residual, explicitly unverified point, left honest rather than assumed: whether sufficient GitHub LFS storage/bandwidth quota is provisioned for this corpus (1.8GB+ per chapter, growing) was not checked as part of this decision — it is an operational follow-up, not a privacy risk. | 005 | **No longer applicable** — retained for traceability. The 2026-09-08 clarification fixed the *mechanism* (Git LFS); this decision fixes the *host*. Investigated first for a prior decision (found none — unlike OQ-3, this was genuinely undecided), then put to the operator directly given the push-time-irreversible stakes; not resolved unilaterally. |
| **OQ-6** | Should the AI/IT **topical judgement** remain a named human checkpoint (Amendment A2's provisional resolution, carried as FR-070), or should an automated topical classifier be built and given its own review? | 004, Amendment A2 | A curriculum call rather than an engineering one, and the only amendment in the family that explicitly awaits an operator. Two measurements bear on it: a term-in-name probe scores 64.3% AI-or-IT, and its own author records that it **understates** the result because it cannot see areas whose titles carry no jargon. An automated classifier would inherit that blind spot; a human reading the area does not. |
| **OQ-7** | Should the standalone `ai_interviewing` (`ai_curriculum`) repository be **PUBLIC** — to satisfy FR-288's "clonable by a user with no access to the umbrella" — or remain **PRIVATE** with invited or credentialed access, given it holds employer information the restricted user is explicitly denied (FR-299)? | 007/OQ-1 | FR-288 and FR-299 pull in opposite directions and only the operator can decide which one bends. This is a visibility and business decision about real private content, not a technical default. |
| **OQ-8** | Which specific content in the meeting-notes section must be withheld from the public record? | 006/OQ-1 | A content judgement about what one note may say publicly — not a technical choice with a safe default. The source specification's own text says it **"may not be guessed."** Only the operator has the information needed to decide it. **Interim state, resolved**: the route and any dependent content default to **withheld** (FR-279) — nothing publishes on a guess. |
| **OQ-9** | Is the user store (FR-295) genuinely **shared** across both standalone modules — requiring a new, independently-hosted shared component once neither module has umbrella access — or does each decoupled module get its **own copy** of the user table? | 007/OQ-2 | Both readings satisfy the literal requirement; the choice changes the architecture (a new shared service versus two independent stores kept in sync) and is a product decision about how tightly two "independent" modules are allowed to stay coupled. |
| **OQ-10** | What are the concrete session and token lifetime, idle-timeout, and "remember me" policies? | 007/OQ-3 | The *direction* is resolved as a safe default (short-lived over long-lived, FR-308/FR-309), but the actual numeric values are a security-versus-convenience trade-off only the operator can set. |
| **OQ-11** | Which authentication mechanism is used — self-hosted password authentication, or an external identity provider? Does the answer differ between the equal-access module and the RBAC one? | 007/OQ-4 | A real build-versus-integrate decision with cost and maintenance implications. The Assumptions defer technology to "each module's native stack" but name no auth library or provider. |
| **OQ-12** | Is multi-factor authentication required for either or both users at launch, or only planned for the future refinement FR-303 already anticipates? | 007/OQ-6 | A scope and timeline decision about how much security investment ships now versus later, not a technical default with one obviously-safe answer. |
| **OQ-13** | Should the two already-committed example passwords be **rotated to different real values** before go-live, given they are permanently recorded in a PUBLIC repository's git history? | 007/OQ-5 | Rotating a credential that may already be in use, or choosing to keep these as intentionally-throwaway seed values, is an operator call. This document resolves only the safe default — **treat them as compromised** (FR-306), hash everything, never re-print — not the rotation itself. |
| **OQ-14** | **Raised by this merge.** Is the standalone **workshop** repository to be PUBLIC or PRIVATE? | new | `007/OQ-1` asks this of `ai_interviewing` only. The same question binds `workshop`, and more sharply: it holds a recording of a private teaching session with an identifiable third party, governed by `001/D1`'s local-and-internal-only decision and by OQ-1's unresolved consent question. FR-288 requires it to be clonable by someone with no umbrella access; that is satisfiable privately, with credentials, but the choice is a real disclosure decision about real private material and is **not** an engineering default. |
| **OQ-15** | **Raised by this merge.** Must the manual-QA-readiness milestone (User Story 2, migration gate M2) be reached against the **baseline** umbrella-hosted platform before decoupling begins, or against the **target** standalone modules after it? | new | FR-209 requires the QA and client documents to record the build identifier they were written against and to be **regenerated, not patched**, when that build moves — and decoupling moves the build in the largest possible way. Writing them against the baseline and then decoupling means regenerating them; writing them against the target means the operator's stated absolute priority waits on the whole migration. Both are defensible; the choice is a sequencing and priority decision only the operator can make. |

**Two items were checked and are deliberately NOT open questions**, so they are not re-raised:

- **The answer-against-question verification defect** (`002`). This was decided on 2026-09-02 —
  build the verifier — and is carried as FR-172 and FR-173, marked as **unbuilt** rather than
  blocked. The defect itself remains stated in the limits documentation by FR-171 and must never be
  described as solved.
- **On-screen text scope** (`002/D5`). Decided 2026-09-02 as in scope, with the accuracy obligation
  decided at the same time so it could not be settled later by accident. Carried as FR-183 – FR-191
  and SC-103 – SC-108, all **specified and unbuilt**.

### Decoupling and reuse discipline

*These three criteria come from specification 001's reuse block (FR-281 – FR-285) and belong
topically with the Evidence and governance group above. They are numbered last because they were
found by the mechanical cross-check SC-162 requires, after the preceding criteria had been assigned
their numbers — and renumbering to place them "correctly" would have broken every cross-reference in
this document. **The finding is recorded rather than hidden**: SC-162 caught three source criteria
that this merge had otherwise dropped, which is the check working.*

- **SC-163** *(was: 001/SC-019)*: Every component identified as reusable can be imported and exercised by a consumer **outside** the curriculum, demonstrated by a test that builds and runs it with the curriculum absent. A component that cannot be imported from outside its own module fails this criterion by construction, regardless of how it is written.
- **SC-164** *(was: 001/SC-020)*: **100%** of reusable components resolve from a public repository under an owned organisation, mounted at the project root, with **zero** nested submodules — verifiable by enumerating the submodule declarations and querying each remote's visibility.
- **SC-165** *(was: 001/SC-022)*: At least **5** concurrent users can search and browse simultaneously without the 200 ms suggestion or 2 s result latency targets degrading beyond their stated thresholds. *(Measures FR-062. Distinct from FR-212 and SC-113, which concern a single QA tester; the two populations are unrelated.)*

---

## Assumptions

Unified from the seven sources. Each is a decision taken where the input did not specify, recorded
so it can be challenged in clarification rather than discovered later.

**Scope and audience**

- **Reference implementation.** The existing interviewing module is the structural and technical template. Its conventions are followed unless a workshop-specific requirement makes them unsuitable. *(001)*
- **The reference is a model, not a source.** Its structure, hierarchy, question kinds, document skeleton and export toolchain are the template; none of its content, wording or fixtures crosses into the workshop. Its finished area documents and question banks are about a different subject and are, for this work's purposes, not material but a shape. *(002)*
- **Everything a reader reads is authored from the workshop's own chapters**, evidenced against the workshop's own passages. There is no scenario in which borrowed material is acceptable, including as a temporary placeholder. *(002)*
- **Audience.** Readers are technical practitioners comfortable with a terminal; the QA team is assumed **unfamiliar** with the platform and the QA document assumes no prior knowledge. The red-state audience is engineers and the operator, not anonymous public users. *(001, 005, 006)*
- **Content is authored in English.** Localisation is out of scope. *(004)*

**Architecture and identity**

- **A knowledge area is the workshop's module.** Mapping areas onto the reference's *module* level keeps one hierarchy rather than two. Chapters supply evidence to areas; they are not a level above them. *(002)*
- **Areas span chapters from the first day.** A one-chapter-per-area shortcut would work today and break at the second chapter. Many-to-many now costs nothing and avoids a migration later. *(002)*
- **Identity discipline is inherited wholesale.** Areas, terms, lesson sections, questions and mentions all take minted, persisted identifiers on the same rules as the passage identifier. *(002)*
- **The dotted chapter id is a path, not a decimal.** `02.10` sorts after `02.09` because both are zero-padded strings compared byte by byte, not because of numeric comparison. Reading the id as a decimal is the single most likely misreading and it produces the wrong order at exactly ten children. *(003)*
- **Zero-padding is two digits minimum, and more is allowed.** A grammar that forbids a hundred-chapter corpus for no reason is a limit asserted rather than measured. *(003)*
- **The four already-correct layers stay correct by accident of good design, and are now asserted.** The slug allowlist, the directory resolver, the route wildcard and the client URL encoder all handle a dotted id today. Each is one small edit away from not doing so, so each acquires an assertion rather than a comment. *(003)*
- **A parent chapter may legitimately have no material of its own.** Zero passages under a container chapter is a measurement to publish, not an error to raise. *(003)*
- **The corpus grows; the identity does not change. No renumbering, ever.** Existing chapter ids are immutable. Any option that renumbers an existing chapter is rejected on that ground alone, because every deep link, every registry scope and every archived artifact resolves through it. *(003)*
- **A cycle in the derived hierarchy is structurally impossible.** A parent id is always a strict prefix of its own id, one component shorter, so the parent relation is a well-founded partial order by construction. No gate is added to prove this; nothing can construct the input that would need one. *(003)*
- **Publication is a build-time determination.** Whether an area is servable is decided when the catalogue is assembled, not per request. *(004)*
- **Scale.** The design targets tens of chapters and tens of areas — not thousands. The acceptance evidence is measured against the corpus present; the design must not assume those numbers. *(001, 002, 004)*

**Content and capability**

- **Session records are authored, not generated.** A machine can enforce structure, completeness and carry-forward; the content is authored. *(006)*
- **Carry-forward is derived at build time** from recorded plan and coverage, so it cannot drift from what actually happened. *(006)*
- **Transcription approach.** Automatic speech recognition over the recording's audio, with the recording treated as the authority when it disagrees with the notes document. *(001)*
- **Recordings stay out of version control whole.** They remain split into size-bounded parts with checksums. *(001)*
- **Video is served from material already present in the private module.** No new recording, hosting or transcoding capability is introduced. *(004)*
- **Materials are authored assets committed alongside the lessons.** No authoring tool or upload path is introduced. *(004)*
- **Assessment mirrors the reference's grading model.** Multiple choice is scored automatically; short answer reveals a model answer for self-assessment. Automatic grading of free text would require a capability the host does not have and would import fabrication risk into the one place a learner is most likely to trust the output. *(002)*
- **Answering models are pluggable**, with local operation as the privacy-preserving default. *(001)*
- **Existing semantic search is reused and extended, not replaced.** The existing two-path search and its three-state behaviour are proven; new kinds join that index rather than arriving with a second search system. *(001, 002)*
- **The existing front end is reshaped, not rebuilt.** It has more code than the reference and it works; the defect is its shape. *(002)*
- **The design system is reused.** The palette is derived from existing seeded design tokens; what changes is that the derivation reaches the served interface. The visual identity comes from the token layer, never by forking the component library. *(001, 002, 004)*
- **Some areas will carry no test, honestly**, because their evidence does not support one. That is the correct state and SC-054 is written to accept it, provided the reason is stated. *(006)*
- **Some documents remain unpublished** pending a human reading their uncited claim blocks. A client sees fewer areas than are authored; that is disclosed rather than concealed. *(006)*

**Red state, obtainability and governance**

- **Recorded material may live outside the repository.** No requirement says the recordings must be inside it; only that they remain obtainable by a documented step. *(005)*
- **Some reds are correct and will remain red.** Content-boundary detection, unreviewed documents and areas the corpus cannot support are expected to stay red; the requirement is that they are **declared**, not that they go green. *(005)*
- **History rewriting is unavailable.** It is forbidden fleet-wide, so every obtainability fix must work forward from the current state. *(005)*
- **Read-only probing is preferred.** Where a direction cannot be established without a mutating operation, the undetermined state is reported and the operation is a separate decision. *(005)*
- **Two instruments measuring different populations may legitimately disagree.** The requirement is that populations are stated, not that they agree. *(005)*
- **"No gaps, no weak spots" means every gap is known and stated**, not that none exists. A specification claiming zero gaps would be the first unearned claim in it. *(006)*
- **Governance is binding, not aspirational.** Three-valued checks, paired mutation proofs driven by data, no server-side CI, carriers in lockstep, the continuation document updated alongside non-trivial changes, and the content boundary enforced in both directions. *(001, 002, 003)*
- **Local enforcement is weaker than server-side enforcement in one respect, and this is stated rather than glossed.** An untracked hooks directory means a fresh clone is unprotected until the documented install command is run, and a verification-bypass flag leaves no record. That is the accepted cost of FR-271 and FR-291. *(merge, C1)*

**Target architecture**

- **Technology stack is each module's native stack.** Implementation uses what each module already declares. *(007)*
- **`ai_curriculum` is `ai_interviewing`.** The two names refer to one module; `ai_curriculum` is the user-facing alias. *(007)*
- **"Live running instances" means locally running containerised services** using the shared containers module with a rootless runtime — **not** cloud deployment. *(007)*
- **Constitution-supported test types** are unit, integration, end-to-end, contract, performance, security and accessibility. *(007)*
- **Progress data model.** User → Module → Area → Lesson → (Test | Exercise) → CompletionRecord. *(007)*
- **Employer information and GitHub-project analysis are identifiable data domains** that can be protected by role-based access control — but they are **named informally, not enumerated**, which is why FR-300 grants by allow-list and FR-314 denies by default. *(007, with the merge's emphasis)*
- **Machine-readable evidence format** is structured data carrying at minimum the test name, status, duration, assertions and artefacts. *(007)*
- **Both modules are web applications.** *(007)*

## Dependencies

- The recorded sessions, their recordings and their transcripts — referenced **by location only**. *(001, 006)*
- The existing passage registry, its minted identifiers, the four-outcome resolution path, the search index and its three-state behaviour, the cross-reference graph, and the media range-serving that makes a timestamp jump possible. *(002)*
- The existing archive-and-verify mechanism, which produces per-part and whole-file hashes and refuses a corrupted part. *(005)*
- The passage registry's sectioning tool, for the structural obstacle FR-116 requires removed. *(005)*
- The existing transcript passage registry, which supplies the passages video anchors resolve against. *(004)*
- The knowledge-model contract document, which is the normative definition of the ported hierarchy and which this document references rather than restates (FR-068). *(002)*
- The area and term taxonomy extracted into the workshop's curriculum directory. It is an **input to be reconciled** under FR-080, not a finished answer. *(002)*
- The interviewing module, as the structural template and as the source of the export toolchain's design — and **only** as that. It is a separate private repository, read for shape and never for substance. *(001, 002)*
- The documented chapter-addition procedure and its prompt, which FR-174 extends rather than replaces. *(002)*
- The shared design system and the design toolkit that owns the token contract and its conformance check. *(001, 002)*
- Document conversion tooling for the four-format export. *(002)*
- An answering model, locally hosted or externally reachable, for User Story 22 only. *(001)*
- An entailment-capable model for the answer-to-question verification layer only. *(002)*
- **The platform's user-experience research** (FR-239). **At the time specification 002 was written this had not landed** — the research directory existed but held a document on a different subject, and the corresponding task was marked blocked rather than written against taste. *(002)*
- A durable place to hold recorded material outside the repository's object store, reachable by the documented step — **GitHub LFS on the same repository, per OQ-5's resolution (2026-09-15)**. *(005)*
- The corrected served-surface measurement instrument, for the presentation requirements. *(005)*
- The content-boundary instrument, which governs FR-276 – FR-279. *(002, 006)*
- The constitution submodule, which governs all of this work. *(001)*
- **Target architecture only**: the shared containers module with a rootless runtime, for the live local instances FR-293 requires; the GitHub and GitLab command-line interfaces, authenticated for the owned organisation (FR-323); and the user store component of FR-295, whose shape is OQ-9. *(007)*

## Out of Scope

- **Public internet publication of the curriculum.** The local-and-internal decision stands for the baseline. *(001, 002)* **Target-state note**: FR-288's standalone cloneability is **not** a decision to publish — it is satisfiable with a private repository and credentials, and the visibility question is OQ-7 and OQ-14.
- Editing, re-recording, re-transcribing or translating the source recordings. *(001, 002)*
- Live transcription of sessions as they happen. *(001)*
- Authoring content for chapters that do not yet exist. *(001, 002)*
- **Ingesting the chapters that are archived and verified but not yet ingested.** Running them through the pipeline is the work FR-015 – FR-054 *enable*; it is not this work. *(003)*
- Replacing or re-architecting the interviewing module. It is read, never written. *(001, 002)*
- Authoring assessments for areas whose evidence does not support them. *(005, 006)*
- Publishing the documents that fail publication review; that awaits a human reading their uncited claim blocks. *(006)*
- Automating the authorship of session content; only its structure, completeness and carry-forward are mechanised. *(006)*
- Rewriting published history in any repository, in either architectural state. *(005, 006)*
- **Making the content-boundary detector green.** Only its rows' disposition is in scope. *(005; see Clarifications C7)*
- Changing provider-side settings that only an operator can change in a provider interface — measuring and reporting them is in scope; changing them is not. *(005)*
- Supporting concurrent testers against one shared running environment instance at the same time; each tester works against their own instance or at a separate time. *(006)*
- Restarting or redeploying the platform as part of this specification's own resolution — that is deployment work, not documentation. *(006)*
- **A draft/published visibility distinction for chapters.** Listing depends on directory existence (FR-018, FR-053). Gating chapter visibility on readiness is separate work with its own specification. *(003; see Clarifications C9)*
- **Any new route added by the chapter-hierarchy capability.** FR-040 states it as a requirement; it is repeated here because *"add a children endpoint"* is the obvious first idea. *(003)*
- A nested chapter tree on the wire; the array stays flat. A depth limit; measured and published, never asserted. A hierarchy for anything other than chapters. *(003)*
- Learner accounts, cross-device progress and certificates **in the baseline**. *(004)* — these are precisely what Part II introduces, and the boundary between "out of scope for the baseline" and "the target architecture's core" is stated so the two are not confused.
- Authoring tools or a content-management interface; content is authored as committed files. *(004)*
- Automatic grading of free-text answers. *(002)*
- A second search system, a streaming service, or any new content-delivery infrastructure. *(001, 002)*

---

## Supersession Map

What each of the seven source specifications contributed, and where it lives now. **All seven remain
in the tree.** Each carries a supersession notice at the top of its `spec.md` and `tasks.md` and is
otherwise unmodified, because its Clarifications, Amendments, Resolved Decisions and withdrawn-claim
records are the history this document inherits.

| Source | One-line contribution | Where it lands here |
|---|---|---|
| **001 — Workshop Curriculum Platform** *(2026-08-31, 59 FR, 24 SC, 19 edge cases, 5 stories, 131 tasks)* | The substrate: a faithful transcript with minted passage identifiers, a browsable curriculum, meaning-based search, grounded answering with a refusal path, a repeatable chapter-extension procedure, and the decoupling-and-reuse discipline that makes Part II possible at all. Also the three Resolved Decisions — local/internal only, the search corpus, local video reassembly — and the WCAG 2.1 AA commitment. | FR-001 – FR-014, FR-055 – FR-062, FR-150, FR-154 – FR-160, FR-165 – FR-170, FR-174 – FR-178, FR-231 – FR-234, FR-259 – FR-285; US3, US12, US20, US22, US24; EC-001 – EC-007, EC-053 – EC-060; SC-001 – SC-004, SC-075, SC-076, SC-083 – SC-086, SC-092 – SC-094, SC-102, SC-118, SC-135 – SC-143; OQ-1. |
| **002 — Knowledge Areas & Bidirectional Deep Linking** *(2026-09-01, 93 FR, 55 SC, 20 edge cases, 7 stories, 153 tasks — the largest source)* | The knowledge layer and the link graph: the ported hierarchy, taxonomy extraction with evidence, area materials on the reference skeleton, bidirectional deep linking through one four-outcome resolver, the half-open interval convention, search loci with match offsets, provenanced assessment, four-format export, the repeatable pipeline, and the on-screen-text (OCR) block with the accuracy obligation that gates its own closure. | FR-063 – FR-068, FR-077 – FR-092, FR-107 – FR-114, FR-118, FR-135 – FR-153, FR-161 – FR-164, FR-171 – FR-173, FR-179 – FR-191, FR-218 – FR-223, FR-235 – FR-240; US10, US11, US13, US20, US23, US24, US25; EC-024 – EC-031, EC-041, EC-044 – EC-052, EC-055, EC-089, EC-092, EC-095, EC-101; SC-043 – SC-050, SC-061 – SC-066, SC-070 – SC-074, SC-077 – SC-082, SC-087 – SC-091, SC-095 – SC-101, SC-103 – SC-108, SC-119 – SC-124, SC-144; OQ-2. |
| **003 — Chapter Hierarchy** *(2026-09-05, 43 FR, 32 SC, 17 edge cases, 5 stories, 45 tasks)* | The identity spine: the dotted zero-padded id serving five roles unchanged, derived-never-stored hierarchy, byte-lexicographic ordering as a consequence rather than a rule, the equality rule for every chapter-scope comparison, the silent-data-loss defects and their paired mutations, and the hierarchy exposure on existing endpoints. Its once-blocking `ordinal`-type question was resolved during this merge on discovering a decision-record this document's source `spec.md` predates — see Clarifications, "OQ-3 resolved during this pass". | FR-015 – FR-054, FR-274, FR-275; US6, US7, US8, US16, US21; EC-008 – EC-023; SC-005 – SC-036; **OQ-3 (resolved 2026-09-15)**. |
| **004 — Authored AI/IT Knowledge Areas** *(2026-09-07, 51 FR, 21 SC, 21 edge cases, 6 stories, 82 tasks)* | The remedy for a catalogue of mined vocabulary: authored subjects rather than extracted terms, lessons with real bodies, end-of-area tests with disclosed thresholds and upward rounding, materials and keyboard-operable video anchors, catalogue integrity computed in exactly one place, and the palette work that must be measured on what is **served**. Carries three recorded Amendments, one of which awaits an operator. | FR-069 – FR-076, FR-093 – FR-106, FR-119 – FR-134, FR-224 – FR-230; US10, US11, US14, US15, US19, US26/US27 (its US6); EC-029, EC-032 – EC-043, EC-054, EC-072, EC-073, EC-090, EC-091, EC-096 – EC-098; SC-037 – SC-042, SC-051, SC-052, SC-057 – SC-060, SC-067 – SC-069, SC-116, SC-117, SC-145; OQ-4, OQ-6. |
| **005 — A Repository That Clones, and a Fleet With No Unexplained Red** *(2026-09-08, 30 FR, 17 SC, 15 edge cases, 4 stories; **no plan.md**)* | Two problems with one remedy. **Obtainability** — the repository could not be cloned, root-caused by controlled test (smart-HTTP cannot resume, so a large transfer is a total failure) after a first hypothesis was refuted and recorded as refuted — which serves **both** architectural states. **Red-state discipline** — every red must end as a defect, a declared condition, or an unrunnable check, never merged into one count and never closed by weakening the instrument. Also the learner-facing disclosure requirements and the corrected palette measurement. Its once-open storage-backend question was resolved by direct operator decision during this pass — see Clarifications, "OQ-5 resolved during this pass". | FR-092, FR-112, FR-115, FR-116, FR-224 – FR-227, FR-241 – FR-258, FR-259 – FR-263; US1, US9, US17, US19; EC-074 – EC-088; SC-054 – SC-056, SC-116, SC-117, SC-125 – SC-136; OQ-5 (resolved 2026-09-15). |
| **006 — A Complete Session Record per Chapter, and a Platform a QA Team Can Test** *(2026-09-08, 44 FR, 15 SC, 16 edge cases, 5 stories, 70 tasks)* | **The operator's stated absolute priority.** The four cumulative session sections with derived carry-forward and visible slip counts; the single QA document with expected results stated before the tester acts, limitations disclosed in advance, and a resumption point; the client walkthrough's up-front disclosures; and the SOURCE-versus-SERVED discipline whose root cause — a process asserting a determined negative from a stale snapshot — is now an architectural rule. | FR-093, FR-096, FR-115, FR-117, FR-119, FR-192 – FR-217, FR-259 – FR-263, FR-265 – FR-270, FR-277 – FR-279; **US2**, US4, US5, US17, US18; EC-061 – EC-071, EC-072, EC-073, EC-093, EC-094; SC-053, SC-054, SC-109 – SC-115, SC-136 – SC-143; OQ-8. |
| **007 — Decouple Modules, Add Authentication & Extract Reusables** *(2026-09-12, 55 FR, 14 SC, 16 edge cases, 8 stories, 31 tasks)* | **The entire target architecture.** Both modules standalone and independently cloneable; database-backed authentication with module-scoped tokens, default-deny authorization and fail-closed availability; user-bound durable progress; extraction of reusables into public repositories under an owned organisation, gated by content-boundary review; and the credential posture that treats two already-published passwords as compromised. Its CI/CD requirement is the one source requirement this merge **resolved against**. | Part II in full — FR-286 – FR-337; US26 – US33; EC-099, EC-102 – EC-116; SC-146 – SC-159; OQ-7, OQ-9 – OQ-13; and Clarifications C1, C3, C8. |

**Two items belong to no single source and were raised by the merge itself**: OQ-14 (the visibility
of the standalone **workshop** repository, which 007 asked only of `ai_interviewing`) and OQ-15 (whether
manual-QA readiness is reached against the baseline or the target). Three requirements were likewise
promoted or created by the merge because no source made them testable: **FR-316** (seed-account
bootstrap, resolved in 007's edge cases but never written as a requirement), **FR-321** (the fate of
anonymous per-browser progress at the authentication cutover, which no source covered), and the
criteria that measure them, **SC-160**, **SC-161** and **SC-162**.

---

*End of specification. Task breakdown: [`tasks.md`](./tasks.md). Technical approach:
[`plan.md`](./plan.md).*
