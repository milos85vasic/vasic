# Contract: Provider Locality, Egress and Remote-Generation Audit (FR-014 – FR-016)

Depends on spec 011 for the `lan` locality value (011 FR-006/FR-007) and the audit writer
(011 FR-004/FR-005; `contracts/remote-generation-audit-log.md`). Where 011 is not built, the dependent behaviour
is BLOCKED, and the local-provider path is unaffected.

## 1. Locality matrix

| Provider locality | Passages leave the host? | Preconditions (all must hold) | Audit line? |
|---|---|---|---|
| `local` (loopback endpoint, verified by `VerifyLocality`, `pkg/answer/locality.go:49`) | no | provider constructed OK | no (material record only) |
| `lan` (operator-controlled non-loopback; 011 US3) | yes, to an operator-controlled host | 011 `lan` support present; `remote_ack` | **yes** |
| `remote` (hosted catalogue rows) | yes, to a third party | `-answer-allow-remote`; credential present; `remote_ack` | **yes** |

A `local` provider whose resolved endpoint is not loopback is refused exactly as answering refuses it today
(`ollama.go:123`); materials add no relaxation.

## 2. Preflight disclosure (what the learner is shown before confirming)

`provider` (catalogue name), `model`, `locality`, a one-sentence plain-language egress statement ("the passages
selected for this request will be sent to <provider> on <locality>"), the token upper bound, remaining budget.
The learner's confirmation sends `remote_ack: {"provider":"…","locality":"…"}`; the server compares it with what
it would disclose *now* and rejects a mismatch (`400 remote_ack_mismatch`) so a stale page cannot consent to a
provider that has since changed.

## 3. Audit write contract

- One record per **generation attempt** (not per process or per provider construction) for `lan`/`remote`, in the
  schema fixed by 011 FR-005: session id, provider, model, target endpoint, timestamp, request byte-count — plus
  `outcome` ∈ {`success`,`upstream_error`,`timeout`,`cancelled`}. **No** topic, prompt, passage or generated text.
  The writer takes an `int` byte-count, never text (011 contract §2), which makes the negative requirement
  structural.
- Order: (1) insert `generation_attempt` (unsettled), (2) call provider, (3) settle the attempt row, (4) write the
  audit record, (5) only then return/persist the response. If step 4 fails the response is **not** returned as a
  success: the job ends `unavailable audit_unwritable`, the material is not persisted, and the attempt row is left
  with `audit_written=0` for the operator to see.
- **Pre-flight precondition (fail closed, §11.4.252):** before step 2 the audit sink must be writable
  (open-append check). If not ⇒ `unavailable audit_unwritable` and the provider is **not** called. This decides, for
  the materials path, the question 011's contract leaves open; the decision is to be recorded in 011's T009 so the
  two features do not diverge (task T045).
- Crash window: a process dying between step 2 and step 4 leaves an unsettled / un-audited `generation_attempt`.
  Boot reconciles: unsettled attempts older than the timeout are marked `outcome='crashed'`; a report lists
  attempts with `audit_written=0` for non-local providers. The audit file itself stays append-only.

## 4. Properties

| ID | Property | Oracle | Paired mutation |
|---|---|---|---|
| A-1 | lines == provider requests for success, upstream error, timeout (non-local stub) | stub counter vs `wc -l` | skip the write on error ⇒ FAIL |
| A-2 | no audit line contains canary strings planted in topic, passages, output | substring scan | add the topic to the record ⇒ FAIL |
| A-3 | audit unwritable ⇒ provider stub count 0 and `audit_unwritable` | chmod'd file / failing writer | proceed on error ⇒ FAIL |
| A-4 | remote without allow flag ⇒ `provider_disabled`, count 0 | stub counter | drop the flag check ⇒ FAIL |
| A-5 | allow flag but no/incorrect `remote_ack` ⇒ 400, count 0 | stub counter | accept missing ack ⇒ FAIL |
| A-6 | local provider ⇒ no audit line and the stub observes a loopback peer | stub bind address | audit local too ⇒ test FAIL (documents the intent) |
| A-7 | crashed attempt visible after reboot (`settled_at IS NULL` → `crashed`) | kill-9 test, row query | no reconciliation ⇒ FAIL |
| A-8 | credentials never in logs, audit, errors, material | canary key scan (cf. `scrubCredential`, `hosted.go:229`) | log the header ⇒ FAIL |

## 5. Out of scope here

Provider selection UI, audit-log viewer and data-residency copy belong to spec 024. This feature exposes the data
those screens need (`/api/materials/provider` read-only: name, locality, whether remote is allowed).
