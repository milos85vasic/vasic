# The check registry and its meta-check

`scripts/check-registry.tsv` + `scripts/verify-check-registry.sh`

## Why

`specs/001-workshop-curriculum-platform/spec.md` states two success criteria
quantified over *every* automated check:

- **SC-012** — every check has a paired demonstration that it FAILS when the
  guarded condition is broken. 100%, no exceptions.
- **SC-013** — the system distinguishes "unable to verify" from "passed" and
  "failed" in 100% of its checks.

Neither is evaluable without an enumeration of "every check". Per §11.4, a PASS
that cannot be evidenced is a bluff, so an unevaluable universal claim is worse
than no claim. The registry is that enumeration; the meta-check is what keeps it
true instead of aspirational.

The concrete motivation is measured, not theoretical. On 2026-09-01 two gates in
this tree were found with proofs that could not do their job:

- `scripts/verify-governance-cascade.sh --prove-failure` — its pre-flight control
  runs against the LIVE tree. The live tree had a real C8 violation, so the
  control failed, the mutation battery ran **zero** mutations, and the command
  exited 1 having proved nothing.
- a second gate exercised only sandboxed copies while its real entry point could
  not start.

Neither is visible from a summary line. `--run-proofs` sees both.

## Format

TSV, TAB-separated, field 1 is the row type from a closed vocabulary:

```
scanroot   <dir>
exempt     <path>  <reason>
check      <id>  <entry-point>  <proof-kind>  <proof-arg>  <undet-probe>
debt       <id>  <entry-point>  <owed>        <reason>
```

Full field semantics, including why TSV rather than YAML, are in the header of
`scripts/check-registry.tsv` itself. In short: the governance submodule already
keeps every gate ledger as TSV parsed with `cut -f1`, typed rows from a closed
vocabulary are already a governance requirement here
(`submodules/constitution/scripts/gates/cm_ledger_row_typed_from_closed_vocabulary.sh`),
and TSV needs no `python3`/`yq` — a pre-push instrument must not have a parser
that can fail to load and then report a tree it never read.

## Anti-drift

A hand-maintained list rots. Both directions are closed:

- **outward** — every registered path must exist; a dead row is a FAIL.
- **inward** — every `*.sh` under a declared `scanroot` must appear in some row.
  A new check dropped into `scripts/` and not registered is a **FAIL**, not an
  omission. This is the half without which the registry is decorative.
- **ratchet** — a `debt` row whose owed property is found SATISFIED is a FAIL
  ("stale debt — promote it"). Debt may hide a gap; it must not hide a fix.

## Exit codes

`0` all registered checks conform · `1` a real conformance violation ·
`2` could not determine (registry missing/unreadable/malformed, scanroot absent,
probe timed out). The instrument is not exempt from its own SC-013 rule.

Registered **debt** does not block a default run. It prints on every run and is
never reported as compliance. `--strict` turns each debt row into a failure.

## Modes and cost

| mode | what it does | measured wall clock |
|---|---|---|
| default | proof STRUCTURE + executes every rc-2 probe | **0.8–1.1 s** |
| `--prove-failure` | its own §1.1 paired mutation proof (10 mutations) | **5.6 s** |
| `--run-proofs` | additionally EXECUTES every registered paired proof | **243 s** |

The trade is declared rather than silently sampled: executing every paired proof
is the strongest evidence and is far too slow for a hook, so the default run
verifies structure and says in its own summary that it observed no proof
actually run. Nothing is skipped at random.

## Wiring it into the pre-push hook

Not wired by this change — that is the controller's call once the debt below is
scheduled. When wired, it belongs in `scripts/pre-push-gates.sh` as a new gate
id in `GATE_IDS`, with:

```bash
gate_N() { bash "$ROOT/scripts/verify-check-registry.sh"; }
# name:       check-registry conformance (SC-012 / SC-013)
# provenance: docs/check-registry.md
```

Two cautions specific to that host:

1. `pre-push-gates.sh` maps **every** non-zero child rc to `FAILED` (`run_gate`,
   around line 435). A `verify-check-registry.sh` rc of 2 would therefore be
   reported as a failure rather than as "could not determine". That is a defect
   in the harness, not in this gate — it is registered as debt below.
2. Run it **default mode** in the hook (≈1 s). `--run-proofs` at 243 s does not
   belong on a push path; it belongs in a pre-tag / release sweep.

## The conformance gap, as of 2026-09-01

Determined empirically by running each entry point, not by reading its prose.
Re-derive with `bash scripts/verify-check-registry.sh`.

Conforming (paired proof **and** demonstrated rc-2): `constitution-inheritance`,
`governance-cascade`, `manifest-pins`, `continuation-sync`, `provider-ci`,
`check-registry`.

Owed:

| check | owes | note |
|---|---|---|
| `scripts/verify-all-constitution-rules.sh` | proof | rc-2 verified; nothing demonstrates the sweep fails when a child gate is silently dropped |
| `scripts/audit-hardcoded-paths.sh` | proof | rc-2 verified |
| `scripts/audit-environment-assumptions.sh` | proof | rc-2 verified |
| `scripts/lumen-index-doctor.sh` | proof | rc-2 verified |
| `scripts/ollama-tune.sh` | proof | rc-2 verified |
| `scripts/pre-push-gates.sh` | proof, three-valued | collapses child rc 2 into FAIL |
| `scripts/test-setup-agents-wizard.sh` | proof, three-valued | asserts three-valued behaviour in the wizard it tests; implements none for itself |

Separately, `--run-proofs` currently reports `governance-cascade` and
`manifest-pins` as proofs that cannot pass on this tree. Their mechanism is
present and correct; their pre-flight control fails against live violations, so
the battery never runs. Fixing that means giving each a synthetic control that
is green by construction and demoting the live run to a reported pre-flight —
the shape `verify-check-registry.sh --prove-failure` uses.

## Declared scope boundary

The scanroots are `scripts/` and `tests/`. `_tools/` and `_tests/` hold further
gates that `pre-push-gates.sh` runs (`_tools/audit-hardcoding.sh`,
`_tools/translate/reproducibility-selftest.sh`, `_tools/portfolio/self-validate.sh`,
`_tests/run-harness-selfvalidation.sh`) and are **not** swept yet. That is a
declared boundary, not a claim that they conform. Widening it is a one-line
`scanroot` addition.
