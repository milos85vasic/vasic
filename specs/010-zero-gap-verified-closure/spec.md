# Feature Specification: Zero-Gap Verified Closure

**Feature Branch**: `010-zero-gap-verified-closure`
**Created**: 2026-09-25
**Status**: Draft
**Input**: User description: "Investigate anything unfinished, uncompleted, any gap or shortcoming, find all issues, weak spots and danger zones and make sure we tackle every single of these items! We MUST tackle it completely and cover everything with all supported test types which will produce ONLY machine rock-solid evidence used for bullet-proof validation and verification fully deterministically! There MUST BE no false or faulty results or bluff or AI slop of any kind or in any form ANYWHERE!!!"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One complete, machine-derived register of every gap (Priority: P1)

The operator asks a single question — "what is unfinished, broken, weak or dangerous anywhere in
this system?" — and gets one register that answers it completely. Every item is discovered by a
repeatable sweep of the whole estate (the umbrella, every owned module, every running service,
every governance instrument), not recalled from memory or from the last conversation. Each item
states what is wrong, where, how severe, what evidence proves it, who owns the fix, and its
current status.

**Why this priority**: Nothing else in this feature can be trusted until the list of things to fix
is known to be complete. A fix programme that starts from a partial list closes the wrong things
and reports success.

**Independent Test**: Run the sweep twice on an unchanged system and compare the two registers
byte for byte; then plant a known defect of each class the sweep claims to cover and confirm each
planted defect appears in the register. Deliverable value: the operator has one authoritative list.

**Acceptance Scenarios**:

1. **Given** an unchanged system, **When** the sweep runs twice, **Then** both registers are
   identical in content and ordering.
2. **Given** a defect of a covered class is deliberately planted in a disposable copy, **When**
   the sweep runs, **Then** the register contains an item for it that cites the planted location.
3. **Given** a part of the estate the sweep cannot inspect (a tool is missing, a host is
   unreachable, a repository is private and unreadable), **When** the sweep runs, **Then** the
   register lists that part as "could not be inspected" with the reason, and never as clean.
4. **Given** the register, **When** the operator asks how complete it is, **Then** the register
   states for each sweep class how many items it found and the measured chance it would miss a
   real one (its recall), or states that the recall is unknown.

---

### User Story 2 - Every item closed with proof, or explicitly classified (Priority: P1)

Every register item ends in exactly one of three states: **closed with verified evidence**,
**explicitly classified** (cannot be fixed from here, needs an operator decision, belongs to a
third party, or is a deliberate documented deviation) with a stated reason and an owner, or
**still open** with a dated plan. No item disappears, is re-labelled without a reason, or is
reported closed on the strength of a statement rather than a measurement.

**Why this priority**: The operator's instruction is that every single item is tackled. The value
is not the list; it is that the list reaches zero unexplained items.

**Independent Test**: Pick any closed item at random; from its evidence alone, re-run the check on
the pre-fix state and observe it fail, then on the current state and observe it pass.

**Acceptance Scenarios**:

1. **Given** an item marked closed, **When** its recorded check is run against the state before
   the fix, **Then** the check fails, and **When** run against the current state, **Then** it
   passes.
2. **Given** an item that needs an operator decision, **When** the register is read, **Then** the
   item names the decision, the options, and the cost of each, and is not counted as closed.
3. **Given** an item that reappears after being closed, **When** the register is updated, **Then**
   it links to its earlier record as a recurrence and is not filed as a new, unrelated item.
4. **Given** the end of the programme, **When** the register is summarised, **Then** the number of
   items with no state, no owner or no evidence is zero.

---

### User Story 3 - Every kind of test applied to every part, with the gaps shown (Priority: P2)

For each owned module and each running service, the operator can see which kinds of testing apply
(unit, integration, end-to-end in a real browser or client, contract, security, accessibility,
performance and load, stress and chaos, mutation, determinism, regression, and manual-QA readiness)
and, for each combination, one of: a runnable check that produced recorded evidence, a declared
reason it does not apply, or a declared gap. A gap is itself a register item.

**Why this priority**: "Cover everything with all supported test types" is an explicit
requirement. Without a coverage map, absent tests are invisible.

**Independent Test**: Delete one test kind's checks for one module in a disposable copy and
confirm the coverage map reports that cell as a gap rather than as covered.

**Acceptance Scenarios**:

1. **Given** the coverage map, **When** any cell is opened, **Then** it links to a check the
   operator can run and to the recorded evidence from its last run, or to the declared reason.
2. **Given** a check that ran zero cases (an empty population), **When** the map is built,
   **Then** the cell is a gap, not covered.
3. **Given** a module whose test tooling is missing on the host, **When** the map is built,
   **Then** the cell reads "could not run" with the missing tool named.

---

### User Story 4 - Evidence that cannot lie (Priority: P1)

Every claim the programme makes — "fixed", "passing", "covered", "deployed" — is backed by
evidence that a machine produced at the moment of the check, states exactly which population it
measured (source on disk, process in memory, or the running product on the wire), can be
reproduced by a stranger from the recorded command, and gives the same result on every repeat.
A check that cannot run reports that it could not run; it never reports a pass.

**Why this priority**: The operator's non-negotiable is no false results, no bluff, no
filler. This story is what makes every other story believable.

**Independent Test**: Take any recorded evidence, re-run its command on the same state five times,
and confirm five identical verdicts; then break the thing it guards and confirm the verdict flips.

**Acceptance Scenarios**:

1. **Given** any check, **When** it is run against a deliberately broken copy of what it guards,
   **Then** it fails (every check has a paired proof that it can fail).
2. **Given** a check run five times on an unchanged state, **When** the verdicts are compared,
   **Then** all five are identical.
3. **Given** a check whose subject population is empty or unreachable, **When** it runs, **Then**
   it reports "could not determine", not a pass.
4. **Given** a claim about the running product, **When** its evidence is read, **Then** it was
   captured from the running product, not inferred from source files.
5. **Given** any report produced by the programme, **When** it is scanned, **Then** it contains
   no unmeasured assertion, no guessing language, and no figure without the command that produced
   it.

---

### User Story 5 - Independent verification and no silent regression (Priority: P2)

A party other than the one that made a fix verifies it, from the recorded evidence, without
trusting the author's summary. After closure, the system keeps re-measuring itself so that a
closed item that reopens, a recorded figure that goes stale, or a new gap is detected without
anyone remembering to look.

**Why this priority**: A programme that closes everything once and then decays has only produced a
snapshot. Independent verification is what separates a fix from a claim of a fix.

**Independent Test**: Reopen a closed item in a disposable copy (revert its fix) and confirm the
next scheduled re-measurement flags it; separately, hand a verifier only an item's evidence and
confirm they reach the same verdict.

**Acceptance Scenarios**:

1. **Given** a closed item whose fix is later reverted, **When** the periodic re-measurement
   runs, **Then** the item is reopened automatically with the failing evidence attached.
2. **Given** a recorded figure in any governance document, **When** the re-measurement runs,
   **Then** a figure that no longer matches the measured value is flagged as stale.
3. **Given** a closed item, **When** an independent verifier re-runs its evidence, **Then** their
   verdict is recorded next to the author's and any disagreement blocks closure.

---

### Edge Cases

- A gap exists only in a private module: it is registered by path and description, and no private
  content is copied into any public record.
- A gap is in third-party or upstream code the project does not own: it is registered and
  classified as not fixable from here, with the reporting route, and never silently dropped or
  "fixed" by editing the upstream copy.
- A fix for one item breaks the gate that guards another: the conflict is registered and
  reconciled before either is reported closed.
- Two agents work on the same area at once: closure evidence is captured against a stated,
  fingerprinted state of the system, so a moving tree is detected and the run is marked
  unstable rather than reported.
- A check is correct but aimed at the wrong population: every check states its population and why
  that population is the right one; a widened population needs its justification recorded before
  its result is read.
- A check that finds a defect is precise but has unknown recall: its "clean" rows are never
  reported as cleared.
- A fix requires an action only the operator can take (a package install, a provider setting, a
  destructive or outward-facing step): the item is classified "operator-blocked" with the exact
  action, and everything else proceeds.
- A host tool needed to produce evidence is missing: evidence for that cell is "could not run",
  and installing the tool is a register item, not a workaround.
- Evidence would embed a credential or private text: it is captured in redacted form, and the
  redaction itself is verified.
- The register itself becomes stale or is edited by hand to look better: hand edits that change a
  status without evidence are rejected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST produce one gap register by a repeatable sweep of the whole estate,
  covering the umbrella repository, every owned module, every running service, every governance
  instrument and every recorded operator decision.
- **FR-002**: Every register item MUST carry an identifier, location, description, severity,
  category, evidence reference, owner, status and creation and last-change dates.
- **FR-003**: The sweep MUST be deterministic: two runs on an unchanged system MUST produce
  identical registers.
- **FR-004**: The sweep MUST state, for each class of defect it searches for, its measured recall
  or explicitly declare the recall unknown; an unknown recall MUST be visible next to every "no
  findings" result.
- **FR-005**: The sweep MUST list any part of the estate it could not inspect, with the reason,
  and MUST NOT count it as clean.
- **FR-006**: Every item MUST end in exactly one of: closed-with-evidence, classified (with reason
  and owner), or open (with a dated plan); an item MUST NOT be removed from the register.
- **FR-007**: An item MUST NOT be closed without a recorded check that fails on the pre-fix state
  and passes on the current state, both captured by machine.
- **FR-008**: A recurrence of a closed item MUST link to the earlier record rather than create a
  new unrelated item.
- **FR-009**: Items requiring an operator decision MUST record the decision needed, the options,
  and the cost of each, and MUST NOT be counted as closed until the decision is executed and
  verified.
- **FR-010**: The system MUST maintain a coverage map of every owned module and running service
  against every supported test kind, each cell being a runnable check with recorded evidence, a
  declared not-applicable reason, or a declared gap.
- **FR-011**: A check that executes zero cases, or whose subject population is empty, MUST be
  reported as a gap or "could not determine", never as covered or passing.
- **FR-012**: Every check MUST report one of three outcomes — condition holds, condition
  violated, condition could not be checked — and MUST NOT report the third as either of the
  first two.
- **FR-013**: Every check MUST have a paired proof that it fails when the thing it guards is
  deliberately broken, and that proof MUST run on a disposable copy, never on shipped source.
- **FR-014**: Every piece of evidence MUST be created by a machine at check time, MUST name the
  population measured (source, process, or running product), and MUST record the exact command,
  the state fingerprint and the time.
- **FR-015**: Evidence MUST be reproducible: re-running its recorded command on the same
  fingerprinted state MUST give the same verdict on every repeat.
- **FR-016**: Evidence MUST be tamper-evident: a change to recorded evidence after capture MUST be
  detectable.
- **FR-017**: Any claim about the running product MUST be supported by evidence captured from the
  running product; a source-only measurement MUST be labelled as such.
- **FR-018**: A verifier independent of the author MUST re-run each closed item's evidence and
  record an independent verdict; a disagreement MUST block closure.
- **FR-019**: After closure, the system MUST re-measure itself on a schedule and on demand,
  reopen any closed item whose evidence now fails, and flag any recorded figure that no longer
  matches its measured value.
- **FR-020**: No record produced by this programme MAY contain an unmeasured assertion, guessing
  language, a credential, or copied private content; a scan for these MUST be part of every
  release of the register.
- **FR-021**: Items in third-party or upstream code MUST be registered and classified as not
  fixable from here, with the reporting route; the programme MUST NOT edit upstream code.
- **FR-022**: Every fix MUST be independently reviewed before it is accepted, and the review
  outcome MUST be recorded against the item.
- **FR-023**: The programme MUST NOT weaken, bypass or silence any existing check to reach a green
  result; a check that is wrong MUST be fixed with its own paired proof.
- **FR-024**: The register MUST be readable by a person in one place, and its summary counts
  (total, closed, classified, open, could-not-inspect) MUST be derived from the items, never typed.

### Key Entities

- **Gap item**: a single defect, shortcoming, weak spot or danger zone — location, severity,
  category, evidence, owner, status, history, and link to any earlier occurrence.
- **Register**: the complete, ordered set of gap items plus the sweep metadata that says what was
  and was not inspected and how sure the sweep is.
- **Sweep class**: one kind of defect the sweep looks for, with its measured recall.
- **Coverage cell**: one (module or service) × (test kind) pair, holding a check with evidence, a
  not-applicable reason, or a declared gap.
- **Evidence record**: the machine-captured proof for one check — command, state fingerprint,
  population measured, outcome, time, and a tamper-evident seal.
- **Independent verdict**: a second party's re-run outcome for a closed item, recorded beside the
  author's.
- **Classification**: the recorded reason an item is not closed — operator decision needed,
  third-party, deliberate documented deviation, or operator-blocked action.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two consecutive sweeps of an unchanged system produce byte-identical registers.
- **SC-002**: For every defect class the sweep claims to cover, 100% of deliberately planted
  defects appear in the register; classes with no planted-defect proof are listed as unproven.
- **SC-003**: 100% of register items are in exactly one final state (closed-with-evidence,
  classified, or open-with-dated-plan); zero items lack a state, an owner or evidence.
- **SC-004**: 100% of items marked closed have a check that fails on the pre-fix state and passes
  on the current state, and 100% of those have a second, independent verdict recorded that agrees.
- **SC-005**: 100% of coverage-map cells are a runnable check with recorded evidence, a declared
  not-applicable reason, or a declared gap; zero cells are blank or unexplained.
- **SC-006**: Every check re-run five times on an unchanged state returns five identical
  outcomes; a check with any differing outcome is registered as unstable and does not count as
  evidence.
- **SC-007**: 100% of checks have a paired proof that they fail when what they guard is broken;
  zero checks are accepted without one.
- **SC-008**: A scan of every report and record the programme produces finds zero unmeasured
  assertions, zero guessing terms in causal statements, zero credentials and zero copied private
  content.
- **SC-009**: A closed item that is deliberately reverted in a disposable copy is reopened by the
  next re-measurement within one scheduled cycle, with its failing evidence attached.
- **SC-010**: An operator can open one place and, within two minutes, answer for any module
  "what is open, what is closed and how do I know" without reading source or asking an author.

## Assumptions

- **Scope**: "Everything" means every repository and running service the project owns (the
  umbrella, the two sites, the workshop platform, the interviewing platform, the shared modules
  and their governance instruments). Third-party and upstream code is in scope only to be
  registered and classified, never edited.
- **Known starting inventory** (each measured in the 2026-09-25 session and to be RE-MEASURED by
  the sweep, not trusted): the content-boundary gate is red by design over a large set of rows an
  operator must read; the workshop answering capability fabricates on about 4.6% of unanswerable
  questions and the success criteria SC-010/SC-094 of feature 001 are unmet, so answering ships
  off; evaluation artefacts are indexed in the workshop's served corpus; the assessment
  answer-shape leak is measured but unremediated; three owned modules are behind their remotes;
  the constitution sweep, the environment audit and the provider-CI probe are red or partly
  unverified for reasons partly outside this project's control; the browser and OCR toolchains
  needed by two gates are missing on this host; the forbidden-command guard does not block several
  destructive git commands; the interviewing platform's start script has the same
  "build only if missing" trap the workshop had; recorded-export coverage and two governance
  hygiene checks are unmet; and several documents carry counts that have drifted from reality.
- **Operator-owned actions**: package installs, provider settings, outward-facing publishing,
  destructive operations and every decision already recorded as pending remain operator actions;
  the programme prepares them and does not perform them unasked.
- **Existing rules bind**: the project constitution and the universal constitution it extends
  apply unchanged — including no force-push, mandatory independent review, three-valued check
  outcomes, and the private/public content boundary.
- **Determinism**: a "stable" result means identical outcomes across repeats on a fingerprinted,
  unchanging state; concurrent editing by other agents is detected and marks a run unstable rather
  than being averaged away.
- **Delivery**: the programme is delivered in prioritised slices; each user story above is
  independently valuable, and the register (Story 1) comes first.

## Open Questions

| # | Question | Status | Resolution |
|---|----------|--------|------------|
| Q1 | Does "everything" include defects inside third-party submodules? | Resolved | Registered and classified only; never edited (FR-021). |
| Q2 | May the programme perform operator-owned actions such as package installs? | Resolved | No; it prepares them and marks items operator-blocked (Assumptions). |
| Q3 | How often does post-closure re-measurement run? | Open | Default: on every push and once daily; to be confirmed at planning. |

## Brainstorm Log

No brainstorm sessions recorded yet.
