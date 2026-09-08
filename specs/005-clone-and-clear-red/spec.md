# Feature Specification: A Repository That Clones, and a Fleet With No Unexplained Red

**Feature Branch**: `main` (this repository works on `main` only)
**Created**: 2026-09-08
**Status**: Draft

**Input**: "Every red gate across the fleet must be resolved or converted into a stated, justified state — and the workshop repository must be cloneable on a second host. […] Every fix must carry machine-produced deterministic evidence with three-valued gates, and no red may be closed by lowering a threshold, allow-listing a row, or re-baselining a count."

## Why this specification exists

A second engineer tried to clone the private curriculum repository and could not.
That is a hard stop: work that cannot be obtained cannot be reviewed, run or
contributed to, and every other quality property of that repository is
unreachable behind it.

Around that sits a second problem of a different kind. **Eleven instruments
across the fleet report red, and no reader can currently tell which reds are
findings and which are the instruments working as designed.** A red that is
correct and a red that is a defect look identical from the outside, and a list
where most entries are permanent is a list nobody reads.

**This specification treats those as one problem**, because they have one
remedy: every red must end in a state that a reader can act on — repaired, or
declared with its evidence and its reason.

### The measured starting state

| # | Red | Measurement |
|---|---|---|
| **R1** | **The repository cannot be reliably cloned** | 54 tracked archive part files totalling **2,624.8 MB**; pack **1.76 GiB**. A second engineer's clone failed with `curl 92 … CANCEL (err 8)`, `9055 bytes of body are still expected`, `early EOF`, `invalid index-pack output`. **Root cause established by test, not inference** — see *Root cause of R1* below. Only **68.1 MB across 2 blobs** exists in history but not in the tree, so this is not history bloat. |
| **R2** | Continuation record stale | Commits changed watched governance files without updating the resumption record in the same commit. 7 pass · **1 drift** · 15 notes. |
| **R3** | Hardcoded developer paths | 3 files, **17 occurrences**, plus **387** separately baselined. Two of the three are generated exports of one source document. |
| **R4** | Governance-source pin behind its remote | 1 of 13 gitlinks differs from its remote. Difference is determined; **direction is not**, because the remote commit is absent from the local object store. |
| **R5** | Provider-side triggering | **1 confirmed** standing trigger with no file-level remedy; **6 unverified** rows on hosts with no read-only adapter. |
| **R6** | Module gate suite red | 1 gate reports a violation and **4 could not run at all**. |
| **R7** | 25 areas carry no assessment | Not an evidence gap: **25 of 37** area documents were never sectioned into the passage registry, so no citation can resolve at their own source and no question can be authored. |
| **R8** | 5 questions silently withheld | They cite redacted passages; the server withholds each one. They are dead in production and nothing says so to a learner. |
| **R9** | Interface paints 2 hue families | Against a floor of 6, measured on the served bundle by a corrected instrument whose three defects were fixed first — the count went **down** from 4 when the instrument became honest. |
| **R10** | 3 documents fail publication review | **62, 54 and 58** uncited claim blocks. They remain unpublished. |
| **R11** | Content-boundary gate red by design | ~15,300 matches; a decision packet exists and **~1,540 rows** are direction-measured as private-first and unread. |


### Root cause of R1 — established by controlled test, and a first attempt that was wrong

**A refuted hypothesis is recorded here rather than deleted, because the wrong
mechanism pointed the remedy in a different direction and the next reader should
see why it was abandoned.**

**REFUTED: "GitHub's HTTP/2 transport cancels on packs this large."** This was
inferred from the `curl 92` error text and from a blob-filtered clone completing
in 2.01 s. It was reported as a finding without being tested. Two arms were then
run from a third host against the same repository, authenticated over HTTPS,
identical except for the negotiated protocol version:

| arm | `http.version` | result |
|---|---|---|
| A | default (HTTP/2) | **rc 0**, 80 s, 2.6 GB |
| B | HTTP/1.1 | **rc 0**, 82 s, 2.6 GB |

**A full HTTPS clone succeeds, over both protocol versions.** HTTPS is not
broken, HTTP/2 is not the cause, and "use SSH" is not a fix — it is a
coincidence of which link happened to hold.

**ESTABLISHED: git's smart-HTTP transport cannot resume a failed fetch.** A
clone that dies at 90% restarts from zero. This repository therefore requires an
**uninterrupted** 2.6 GB transfer to clone at all, and at that size the
cumulative probability of at least one interruption somewhere in the network path
is substantial on any marginal link. `9055 bytes of body are still expected` is
that interruption caught mid-body — a transfer too long to survive, not a
protocol refusing a large pack.

**This mechanism explains every observation; the refuted one explained two.** It
accounts for success over HTTPS here, success over SSH here, instant success
blob-filtered, and failure there — with one cause.

**What it changes.** The remedy is unchanged: the target is the 2,624.8 MB,
because size is what converts a transient blip into a total failure. What
changes is the reasoning recorded in every artefact, and one design consequence:
**a blob-filtered clone is worth documenting as ROBUST, not merely fast.** A
540 KB transfer that fails costs nothing to retry; a 2.6 GB one costs
everything. FR-004's guard must therefore threshold on transfer size and state
this mechanism in its own output, so the next reader does not re-derive the
refuted one.

## Clarifications

### Session 2026-09-08

- Q: Where should recorded material live, given a 2,624.8 MB repository that HTTPS cannot clone? → A: **Git LFS for the archive parts, going forward.**
- Q: Are the 387 baselined hardcoded-path occurrences in scope, or do they stay declared? → A: **In scope — fix the 17 live ones AND work through the 387.**
- Q: Should the 6 provider rows on hosts with no read-only adapter get one? → A: **Write read-only adapters for both hosts.**
- Q: May the governance-source pin's direction be resolved, and the pin moved? → A: **Authorise the fetch, then fast-forward only if it is genuinely behind.**

#### What each decision obliges

**LFS, and its honest limit.** History rewriting is forbidden, so the existing
blobs stay where they are: **a plain full clone remains large no matter what we
do here.** What LFS changes is everything from now on, and it makes the
documented default clone instant. SC-002's "under 250 MB to obtain" is therefore
a claim about **the documented obtaining path**, not about the size of a naive
`git clone` of full history — and the spec must say so rather than let the
number imply something it cannot deliver. The existing archive tool already
produces per-part and whole-file hashes, so integrity survives the move
unchanged; that is what makes LFS viable here rather than a leap.

**The 387 is a campaign, not a fix.** The operator chose the larger option over
the recommendation. Most of those occurrences sit **inside consumed submodules**
and can only be repaired by upstream commits that return as gitlink bumps — so
this spans repositories and cannot land in one change. Two obligations follow:
the work must be **partitioned by owning repository** and reported per repository
rather than as one number; and each row must first be **re-derived**, because a
baseline that was never pruned overstates debt — a row fixed upstream and left in
the baseline is counted as debt that no longer exists.

**Adapters turn permanent unknowns into verdicts.** Six rows have been rc 2 not
because a check failed but because no instrument was ever registered for those
hosts. Both expose public read-only APIs. The obligation: the adapters must
report **three-valued** like every other probe, and an adapter that cannot reach
its host must return 2 — replacing "never asked" with "asked and could not
determine" is progress; replacing it with a green is not.

**The pin fetch is authorised, and its sequence is fixed.** Fetch to resolve
direction, classify with `merge-base --is-ancestor` and a left/right count, then
`merge --ff-only` — which refuses anything that is not a true fast-forward. The
diff-stat must be filtered **by name** against every governance path before and
after, because "no governance document changed" is a claim that must be measured
rather than eyeballed. This pin has gone stale five times; the move closes an
instance, not the class.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A second engineer obtains the repository (Priority: P1)

An engineer on a different machine clones the curriculum repository, follows its
own written setup, and reaches a state its status command calls ready — without
special flags, private knowledge, or a message to the author.

**Why this priority**: Nothing else in this specification is deliverable to
anyone who cannot obtain the repository. It is the only red that blocks other
people rather than degrading a signal.

**Independent Test**: Clone into an empty directory on a machine that has never
held this work, run the documented bootstrap, and read the status output.

**Acceptance Scenarios**:

1. **Given** a machine with no prior copy, **When** the engineer clones by the documented command, **Then** the clone completes without a transport error.
2. **Given** the clone, **When** they run the documented bootstrap, **Then** it obtains every dependency it needs, or names precisely what is missing and the exact command to obtain it.
3. **Given** a chapter's recorded material, **When** they follow the documented step to obtain it, **Then** they get the recording, or a stated reason it is unavailable to them.
4. **Given** the documented clone command, **When** a reader looks for it, **Then** it is in the repository's own front-door documentation, not in a chat message.
5. **Given** the repository over time, **When** its size approaches the point where clones fail, **Then** something says so **before** a person discovers it by failing to clone.

---

### User Story 2 - A reader can tell a finding from a designed state (Priority: P1)

Someone runs the fleet's instruments and, for every red, can immediately tell
whether it is a defect to fix, a known condition with a recorded reason, or a
check that could not run — and what to do next in each case.

**Why this priority**: A list of eleven reds where most are permanent is a list
nobody reads, and the reds that *are* defects then hide inside it. This is the
difference between a gate suite that protects the work and one that decorates
it.

**Independent Test**: Run every instrument, and for each red answer three
questions from its output alone: is this a defect, what is the evidence, what
happens next.

**Acceptance Scenarios**:

1. **Given** any instrument reporting red, **When** a reader reads its output, **Then** it states whether the red is a defect, a declared condition, or an unrunnable check.
2. **Given** a declared condition, **When** a reader reads it, **Then** it carries the evidence and the reason it is declared, and names who may lift it.
3. **Given** a check that could not run, **When** it reports, **Then** it is distinguishable from both a pass and a failure, and it is **never** recorded as a pass.
4. **Given** the full suite, **When** it is run, **Then** a single summary states how many reds are defects and how many are declared, and those two counts are never merged.

---

### User Story 3 - Every learner-facing defect is repaired or disclosed (Priority: P2)

A learner never encounters content that is silently broken. Where something is
missing or withheld, they are told, rather than shown a shorter test or an
absent section with no explanation.

**Why this priority**: These are user-visible defects, but they degrade rather
than block, and they sit behind Story 1 for delivery.

**Independent Test**: Walk one area end to end and confirm nothing is silently
absent — every omission is either repaired or stated.

**Acceptance Scenarios**:

1. **Given** a question whose supporting material is withheld, **When** the test is served, **Then** the question is repaired to cite available material, or removed with the removal recorded — never silently dropped from a learner's test.
2. **Given** an area with no assessment, **When** a learner opens it, **Then** they are told it has none and why, rather than finding an absence.
3. **Given** an area document citing withheld material as its primary reference, **When** it is published, **Then** its references resolve to material a reader can actually reach.
4. **Given** the areas that could not carry a test for a structural reason, **When** that reason is removed, **Then** those areas become authorable and the coverage figure moves for a real cause.

---

### User Story 4 - The interface looks designed on the surfaces people use (Priority: P2)

A visitor perceives a varied, deliberate palette on the surfaces they spend
their time looking at — not only on small indicators — while every pairing stays
legible in both light and dark presentation.

**Why this priority**: It is the operator's twice-raised complaint and it is now
measured. It changes how existing capability is perceived rather than what
exists.

**Independent Test**: Sample what is painted on principal surfaces in both
presentations; count hue variety and measure contrast within each pairing.

**Acceptance Scenarios**:

1. **Given** the served interface, **When** its principal surfaces are sampled, **Then** they carry materially more hue variety than a two-family scheme.
2. **Given** any hue that is added, **When** a reader asks what it means, **Then** it carries a stated classification job — no hue is added only to raise a count.
3. **Given** the measurement, **When** its population is defined, **Then** the population reflects the surfaces a visitor actually looks at, and any change to that population is justified independently of its effect on the count.
4. **Given** both presentations, **When** contrast is measured, **Then** every text and non-text pairing meets its floor in each, measured separately.

---

### Edge Cases

- **A red is fixed by making the instrument weaker.** Forbidden and detectable: any change to a threshold, bucket, allow-list or baseline must be justified by a principle stated *before* the resulting count is known.
- **A repository shrinks below the failure threshold but keeps growing.** The size guard must warn on the trend, not only on the breach.
- **A recording is unavailable to a particular engineer.** Absence of permission is a stated reason, never a broken clone.
- **A check cannot run because a toolchain is missing.** That is could-not-determine, never a failure of the thing being checked, and never a pass.
- **The direction of a difference cannot be established read-only.** It is reported as determined-difference / undetermined-direction, and resolving it is an explicit decision, never an assumption.
- **A fix repairs the count but not the cause.** Each repaired red must name the mechanism that produced it, not only the symptom.
- **Two instruments disagree.** Both readings stand, with their populations stated; the disagreement is reported rather than resolved by preferring the convenient one.
- **A red is declared rather than fixed.** It must name who may lift the declaration and what evidence would.

## Requirements *(mandatory)*

### Obtainability

- **FR-001**: The repository MUST be obtainable by a documented command that completes without a transport error on a machine that has never held it.
- **FR-002**: Large recorded material MUST NOT be carried in the repository's own object store in a way that makes obtaining the repository fail.
- **FR-003**: The documented way to obtain recorded material MUST be in the repository's front-door documentation, and MUST state what a reader gets and what they may not.
- **FR-004**: An automated check MUST report the repository's obtainability cost and MUST warn **before** the point at which obtaining it fails, not after.
- **FR-005**: Existing published history MUST NOT be rewritten to achieve any of the above.

### Red-state discipline

- **FR-006**: Every instrument reporting a non-clean result MUST state which of three states it is in: a defect, a declared condition, or a check that could not run.
- **FR-007**: A declared condition MUST carry its evidence, its reason, and who may lift it.
- **FR-008**: A check that could not run MUST be distinguishable from both a pass and a failure, and MUST NEVER be recorded as a pass.
- **FR-009**: A summary of the fleet MUST report defect count and declared-condition count separately and MUST NOT merge them.
- **FR-010**: No red may be closed by weakening the instrument. Any threshold, bucket, allow-list or baseline change MUST be justified by a principle stated independently of its effect on the resulting count.
- **FR-011**: Every fix MUST name the mechanism that produced the red, not only the symptom it removed.
- **FR-011a**: Debt spanning more than one repository MUST be partitioned by owning repository and reported per repository, never as a single number that hides where the work belongs.
- **FR-011b**: A baselined row MUST be re-derived before it is counted as debt. A row fixed upstream and left in a baseline overstates debt and must be pruned, not carried.
- **FR-011c**: An instrument added for a previously unprobed host MUST be three-valued, and MUST return could-not-determine when it cannot reach that host. Replacing "never asked" with "asked and could not determine" is progress; replacing it with a pass is not.

### Learner-facing correctness

- **FR-012**: A question citing withheld material MUST be repaired to cite reachable material, or removed with the removal recorded. It MUST NOT remain silently withheld.
- **FR-013**: An area with no assessment MUST tell a learner so, with the reason.
- **FR-014**: A published document's primary references MUST resolve to material a reader can reach.
- **FR-015**: The structural obstacle preventing areas from carrying assessments MUST be removed, and the resulting coverage figure MUST move for that cause and be reported.

### Presentation

- **FR-016**: The served interface MUST carry materially more hue variety on its principal surfaces than a two-family scheme.
- **FR-017**: Every hue present MUST carry a stated classification job.
- **FR-018**: The measured population MUST reflect the surfaces a visitor actually uses, and any change to it MUST be justified independently of its effect on the count.
- **FR-019**: Contrast floors MUST hold for text and non-text pairings in both presentations, measured separately.

### Evidence

- **FR-020**: Every requirement above MUST be covered by an automated check producing machine-readable evidence.
- **FR-021**: Every such check MUST be three-valued and MUST ship a paired demonstration that it detects the defect it exists to catch, driven by **data** rather than by altering the check.
- **FR-022**: Every check whose subject is a set MUST establish the set is non-empty before reporting the set contains no defects.
- **FR-023**: Any count reported about a corpus MUST carry evidence the corpus did not change during the measurement.

### Key Entities

- **Red state** — one instrument's non-clean result. Has a kind (defect / declared / unrunnable), evidence, a reason, and for a declared state, who may lift it.
- **Obtainability budget** — the cost of obtaining the repository, with a warning threshold below the failure threshold.
- **Recorded material reference** — a pointer from the repository to material held outside it, with instructions and a stated availability condition.
- **Declared condition** — a red deliberately left standing, with its justification and lifting authority.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An engineer on a machine that has never held the repository obtains it by the documented command, with **0** transport failures, in **3 of 3** attempts.
- **SC-002**: Obtaining the repository **by the documented command** costs **under 250 MB**, down from 2,624.8 MB. This is a claim about the documented path, not about a naive full-history clone: history rewriting is forbidden, so existing blobs remain and a full clone stays large. The spec states this rather than letting the number imply a reduction it cannot deliver.
- **SC-003**: **100%** of recorded material remains obtainable by a documented step, with **0** items lost.
- **SC-004**: **0** commits rewrite existing published history.
- **SC-005**: **100%** of non-clean instrument results state their kind; results whose kind cannot be determined from their output number **0**.
- **SC-006**: **0** instruments record a could-not-run as a pass.
- **SC-007**: **0** reds are closed by weakening an instrument; every threshold or baseline change carries a principle stated independently of the count it produces.
- **SC-008**: The count of unexplained reds — red, with no stated kind and no reason — reaches **0**, from a baseline of **11**.
- **SC-009**: **0** questions served to a learner cite material the server withholds, down from **5**.
- **SC-010**: **100%** of areas without an assessment say so to a learner, with a reason.
- **SC-011**: The number of areas that cannot carry an assessment **for a structural reason** reaches **0**, from **25**; the number that carry none because the corpus does not support one is reported separately and honestly.
- **SC-012**: Principal surfaces carry at least **6** distinct hue families, up from **2**, and **100%** of hues present carry a stated job.
- **SC-013**: **100%** of text and non-text pairings meet their floor in both presentations; failures number **0**.
- **SC-014**: **100%** of requirements map to at least one automated check, and every such check ships a data-driven paired demonstration.
- **SC-015**: A reader answers "is this a defect, what is the evidence, what happens next" for every red from instrument output alone, without consulting a person.

## Assumptions

- **Recorded material may live outside the repository.** No requirement here says the recordings must be inside it; only that they remain obtainable by a documented step.
- **Some reds are correct and will remain red.** Content-boundary detection, unreviewed documents and areas the corpus cannot support are expected to stay red; the requirement is that they are *declared*, not that they go green.
- **History rewriting is unavailable.** It is forbidden fleet-wide, so every obtainability fix must work forward from the current state.
- **Read-only probing is preferred.** Where a direction cannot be established without a mutating operation, the undetermined state is reported and the operation is a separate decision.
- **The audience is engineers and the operator**, not anonymous public users.
- **Two instruments measuring different populations may legitimately disagree**; the requirement is that populations are stated, not that they agree.

## Dependencies

- A durable place to hold recorded material outside the repository's object store, reachable by the documented step.
- The existing archive-and-verify mechanism, which already produces per-part and whole-file hashes and refuses a corrupted part.
- The passage registry and its sectioning tool, for the structural obstacle in FR-015.
- The corrected served-surface measurement, for FR-016 to FR-019.

## Out of Scope

- Rewriting published history, in any repository.
- Making the content-boundary detector green; only its rows' disposition is in scope.
- Authoring assessments for areas whose evidence does not support them.
- Changing provider-side settings that only an operator can change in a provider interface — measuring and reporting them is in scope; changing them is not.
