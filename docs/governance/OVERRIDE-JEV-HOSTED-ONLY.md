# Project Override: Jev decision model, hosted TypeSafe only

| Field | Value |
|---|---|
| Document | `docs/governance/OVERRIDE-JEV-HOSTED-ONLY.md` |
| Revision | 1 |
| Date | 2026-10-28 |
| Authority | Operator directive (CRITICAL), 2026-10-28, quoted verbatim below |
| Form | `Override §X.Y` per `submodules/constitution/templates/Constitution.project.md.template` |
| Status | In force; operator-authorized project override of inherited clauses |

## Operator directive (verbatim)

> "Add override on project level for this current project - umbrella vasic, workshop and all others we have under the vasic umbrella to use only Jev decision model from typesafe.ai provider without locally run decision models! Override has to extend / override existing definitions of parent constitution (Submodule)! We have api key for it in our api_keys.sh under home directory!"

The Jev gate stays ON in **shadow** mode and is never switched to enforce.

## Honest note (§11.4.6)

This is an **operator-authorized project override of inherited clauses**, not a
reinterpretation. The inheritance block at the head of the carriers says project
rules "do NOT weaken or override any universal clause", and the earlier
"Project overrides" section recorded "None". The operator has now decided
otherwise for the narrow scope below, so that statement is replaced. The
override is narrow: it changes WHERE decision work runs, not WHETHER it is
detected, installed, measured and calibrated. It does NOT reopen the position
recorded for §11.4.156: no override of that clause exists or is created here.

## Scope

- Applies to the vasic umbrella root and every OWNED submodule under it:
  `workshop`, `design-toolkit`, `ai_interviewing`, `monetization`,
  `submodules/containers`, `submodules/LLMProvider`, `submodules/RAG`,
  `submodules/verdict`, `submodules/passage`, `submodules/curriculum-kit`,
  `milosvasic.ru`, `vasic.digital`. Re-derive the roster from `.gitmodules` and
  `helix-deps.yaml`; this list is a dated reading.
- Never edited by this change: `submodules/constitution` (governance source,
  not owned by this project) and third-party submodules such as
  `submodules/superspec`. The override lives in the CONSUMERS and extends the
  parent text; it does not modify it.

## Override §11.4.279–§11.4.286 (local decision instances) — what is overridden

1. **§11.4.279(A)** names local `llmctl plan --json` `decision_instances` as a
   detection source and lists "local decide gateway, LAN pins" ahead of hosted
   endpoints. Overridden: for this project the only decision endpoint is the
   hosted TypeSafe Jev endpoint. Local llmctl instances, local decide gateways
   and LAN pins are NOT provisioned, started, downloaded, preferred or
   counted.
2. **§11.4.282(A)–(C)** (capacity computed from local instances; "local
   instances first, then LAN pins, then hosted"; a pinned endpoint used while
   idle local capacity exists is non-compliant). Overridden: there is no local
   capacity to utilise. Using the hosted endpoint exclusively is compliant;
   zero local instances is a recorded, reasoned state, not a defect.
3. **Any other requirement or default** in §11.4.279–§11.4.286, §11.4.198 or the
   constitution's jev bootstrap scripts to provision, download, run or prefer
   a LOCAL decision-model instance (for example llmctl-served `decide-*`
   models) or a local-first ordering is overridden to the same effect. The
   operator-bound bootstrap must not be run with a local download profile.

## What replaces it

- The ONLY decision endpoint is hosted **TypeSafe** (typesafe.ai), reached
  through the toolkit's jev loaders (`claude-providers sync-jev` and the
  jev gate/MCP artifacts of §11.4.280).
- The credential is read **by environment-variable NAME**
  (`TYPESAFE_API_KEY`) from the operator's `~/api_keys.sh`. The value is
  never printed, logged, echoed, committed, put in evidence files, issue text
  or a carrier. Detection records name the variable, never its content
  (CONST-042 / §11.4.10).
- Mode is **shadow**. `JEV_GATE` MUST NOT be `off` and MUST NOT be `enforce`.
  Decisions are recorded and compared; they never block work.
- `jev-detection.json` (§11.4.279) still records the endpoint list; for this
  project it is expected to contain exactly the hosted TypeSafe endpoint and
  an explicit reasoned absence for local instances (for example
  `"local": [], "reason": "operator override 2026-10-28: hosted-only"`).
  Silent absence stays a §7.1 bluff.

## What stays binding (not overridden)

- Anti-bluff §11.4 / §7.1 / §1.1; no-guessing §11.4.6; never force-push
  §11.4.113; host safety §12; secrets §11.4.10; main-only §11.4.288.
- All other duties of §11.4.279–§11.4.286: detection before generation
  (§11.4.279 A–D, with the hosted endpoint as the detected one), per-agent
  installation and honest coverage-gap notes (§11.4.280), the token-reduction
  BEFORE/AFTER proof (§11.4.283), the pre-ladder routing stage and the rule
  that decision models never act as chat models (§11.4.284), threshold
  calibration (§11.4.285), the dependency submodules (§11.4.286), and the
  closed model ladder of §11.4.231.
- §11.4.279(B): detection reads the TTL-guarded cache and performs no hosted
  network I/O at work-item time; hosted endpoints enter the cache only at
  explicit sync time.
- Gates: `CM-JEV-DETECTION` and `CM-JEV-WIRING` remain applicable. Where a
  gate asserts local-instance capacity fields, the correct result under this
  override is the reasoned-absence record above; a gate failing on that point
  is reported, not silenced.

## Supersession

Supersedes the statement "None. No clause of the universal constitution is
overridden by this project." in the umbrella carriers. Further overrides still
require an explicit entry and operator authority. Revoking this override is an
operator decision.
