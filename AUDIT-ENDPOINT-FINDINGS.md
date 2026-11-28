# Audit of KNOWN RED: frozen ENDPOINT assumptions in `workshop/platform/gates/`

**Source:** `bash scripts/audit-environment-assumptions.sh` (run from repo root, exit 1).
**Scope:** `workshop/platform/gates/` only (workshop submodule — READ-ONLY, no edits).
**Constraint satisfied:** exactly **5 frozen ENDPOINT findings** in exactly **2 files**.

---

## The 5 findings (file:line → frozen value)

| # | File:line | Frozen ENDPOINT value | Context |
|---|-----------|----------------------|---------|
| 1 | `workshop/platform/gates/verify-live-flows.sh:25` | `http://127.0.0.1:8087` | passed as `--base` to the live-flows gate (L2 live-port-refused check) |
| 2 | `workshop/platform/gates/verify-live-flows.sh:27` | `http://127.0.0.1:9` | passed as `--base` (L4 unknown-flow-refused check — dead port) |
| 3 | `workshop/platform/gates/verify-live-flows.sh:29` | `http://127.0.0.1:9` | passed as `--base` (L5 unmeasurable-flow check — dead port) |
| 4 | `workshop/platform/gates/prove-read-latency-budget.sh:90` | `http://127.0.0.1:1` | assigned to `BASE` (unreachable-server fault injection) |
| 5 | `workshop/platform/gates/prove-read-latency-budget.sh:92` | `http://127.0.0.1:8087` | assigned to `BASE` (live-port-8087-refused check) |

### Exact source lines

`workshop/platform/gates/verify-live-flows.sh:25`
```sh
expect2 "L2 live port refused" bash "$R" --base http://127.0.0.1:8087 --out "$(mktemp -d)"
```

`workshop/platform/gates/verify-live-flows.sh:27`
```sh
expect2 "L4 unknown flow refused" bash "$R" --base http://127.0.0.1:9 --only no-such-flow
```

`workshop/platform/gates/verify-live-flows.sh:29`
```sh
out="$(WORKSHOP_TEST_SEED_PASSWORD= bash "$R" --base http://127.0.0.1:9 --only ui-sc003-sc017 --out "$T" 2>&1)"; rc=$?
```

`workshop/platform/gates/prove-read-latency-budget.sh:90`
```sh
BASE="http://127.0.0.1:1"; run_gate --levels 1 --requests 8 --timeout 2; rc=$?
```

`workshop/platform/gates/prove-read-latency-budget.sh:92`
```sh
BASE="http://127.0.0.1:8087"; run_gate --levels 1 --requests 8; rc=$?
```

---

## Recommended fix (per finding)

Apply the env-var-override-with-literal-fallback pattern so each endpoint is overridable but keeps its current behavior as last resort. The canonical Python form referenced in the task is:

```python
os.environ.get("WORKSHOP_BASE_URL", "http://127.0.0.1:8087")
```

Because these two files are **shell** scripts, the shell equivalent is:

```sh
${WORKSHOP_BASE_URL:-http://127.0.0.1:8087}
```

`WORKSHOP_BASE_URL` is already the established convention in this codebase (e.g. `prove-sc028-undetermined-states.sh:222` sets `WORKSHOP_BASE_URL="http://127.0.0.1:1"`).

### Per-finding recommendations

**Finding 1 — `verify-live-flows.sh:25`** (`http://127.0.0.1:8087`)
Replace the literal with an env override:
```sh
bash "$R" --base "${WORKSHOP_BASE_URL:-http://127.0.0.1:8087}" --out "$(mktemp -d)"
```
The `--base` value reported by the gate already reflects the resolved argument, so no separate print change is strictly needed; ensure any diagnostic prints echo the resolved `--base`.

**Finding 2 — `verify-live-flows.sh:27`** (`http://127.0.0.1:9`, dead port used for a refused-connection test)
```sh
bash "$R" --base "${WORKSHOP_BASE_URL:-http://127.0.0.1:9}" --only no-such-flow
```
Keeping port 9 as the default preserves the test's intent (guaranteed refusal); the env var allows overriding when needed.

**Finding 3 — `verify-live-flows.sh:29`** (`http://127.0.0.1:9`, dead port)
```sh
out="$(WORKSHOP_TEST_SEED_PASSWORD= bash "$R" --base "${WORKSHOP_BASE_URL:-http://127.0.0.1:9}" --only ui-sc003-sc017 --out "$T" 2>&1)"; rc=$?
```

**Finding 4 — `prove-read-latency-budget.sh:90`** (`http://127.0.0.1:1`, dead port for unreachable-server fault injection)
```sh
BASE="${WORKSHOP_BASE_URL:-http://127.0.0.1:1}"; run_gate --levels 1 --requests 8 --timeout 2; rc=$?
```

**Finding 5 — `prove-read-latency-budget.sh:92`** (`http://127.0.0.1:8087`, live service port)
```sh
BASE="${WORKSHOP_BASE_URL:-http://127.0.0.1:8087}"; run_gate --levels 1 --requests 8; rc=$?
```

### Docstring / print reporting
Per the task pattern, any usage message or diagnostic that documents the endpoint should report the **resolved** value (the value actually in effect after env override), not the hardcoded literal. For example, if a gate prints `base=<url>`, it should print the resolved `BASE`/`--base` value.

---

## Notes / honest boundary

- This is a READ-ONLY audit. No files were edited; the workshop submodule is off-limits per operator constraint (edits there = gitlink bump = operator decision). The fix must be applied inside the `workshop` submodule and returned as a gitlink bump.
- The task's canonical fix pattern is Python `os.environ.get(...)`. The two files containing these 5 findings are shell scripts, so the equivalent shell idiom `${VAR:-literal}` is used; the semantics (env override, literal as last resort) are identical.
- `student_surface.py:2064` (`default="http://127.0.0.1:8087"`) is the Python file matching the `os.environ.get` pattern described in the task; it carries a single frozen ENDPOINT default and is a related candidate for the same remediation. It is not part of the 5-finding count above.
- No commit or push was performed.
