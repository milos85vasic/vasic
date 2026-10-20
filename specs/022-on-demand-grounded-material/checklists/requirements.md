# Specification Quality Checklist: On-Demand Grounded Material Generation

**Purpose**: Validate specification completeness before implementation
**Created**: 2026-10-20
**Feature**: [spec.md](../spec.md)

## Content Quality
- [x] User stories describe learner/operator value; mechanisms live in contracts/ and data-model.md
- [x] Mandatory sections completed; Jordan REQ-3 traced and its interpretation made explicit (OD-2)
- [x] Corpus-only grounding, decline-over-fabricate and never-unasked stated as requirements, not aspirations

## Requirement Completeness
- [x] Requirements testable and unambiguous (each FR maps to a named test in `contracts/` and tasks.md)
- [x] Success criteria measurable; fabrication is expressed as a measured bound with an operator bar, not a claim
- [x] Acceptance scenarios and edge cases defined (injection, concurrency, day rollover, crash, suppression)
- [x] Scope bounded: MCQ deferred (OD-4), promotion deferred (OD-7), per-client corpora excluded
- [x] Dependencies on 011 (US1 done, US2/US3 blocking the remote/LAN path) and calibration stated
- [x] Blocked-on-client-identity items listed without invented answers
- [ ] **Open operator decisions OD-1 … OD-7 resolved** (intentionally open)

## Feature Readiness
- [x] Test-first tasks with a named oracle; oracle authored by a different actor (T013)
- [x] Deterministic tests via scripted fake provider and counting stub
- [x] LIVE verification task writes `result.json` + sha256 manifest and distinguishes scripted from real (T062)
- [x] Manual, guides, FAQ and four diagram classes tasked (T063–T069); exports independently validated (T070–T071)
- [x] Independent review tasks per story and for the whole feature (T072)
- [x] UI-visible acceptance step (T059; Quickstart Scenarios 1–6)

## Notes
- UNCONFIRMED and carried: 011 audit call-site semantics (T004), calibrated thresholds (T008), retrieval
  determinism (T006), local-model fitness (T060), non-English behaviour, client identity.
- The feature is correct-by-refusal in today's environment (uncalibrated gate, answering off): the honest outcome
  of enabling it now is `thresholds_uncalibrated`, and the live evidence will say so rather than fake a pass.
