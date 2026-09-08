# Quickstart — validating this feature end to end

**Feature**: Session record + QA readiness · **Date**: 2026-09-08
**Build measured**: index generation **7**, 39 served areas, served CSS `sha256 c6d03995…`

Every command below was executed. Where a result is not yet obtainable, that is
stated rather than written as an expectation.

**Exit contract: `0` clean · `1` a real finding · `2` could-not-determine. A `2`
is never a pass.**

## 0 — Confirm you are measuring the served product, not the source

**Do this first, every time.** The most-repeated defect in this project is a
source measurement reported as a served one.

```bash
curl -s 127.0.0.1:8087/api/areas | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["generation"], len(d["areas"]))'
podman inspect workshop-curriculum_platform_1 --format '{{.State.StartedAt}}'
ls -l workshop/platform/bin/workshop-server
```

**If the binary is newer than the container start time, every figure below is
about a stale process.** That state persisted four hours undetected today.

## 1 — The session record (US1, US2)

```bash
curl -s 127.0.0.1:8087/api/chapters/02 | python3 -c '
import json,sys; sr=json.load(sys.stdin)["session_record"]
for n in sr["section_order"]:
    s=sr["sections"][n]
    print(f"{n:16} {s[\"own_state\"]:9} own={s[\"own_count\"]:>3} carried={s[\"carried_count\"]:>3}")'
```

Expected — measured:

```
meeting_notes    authored  own= 50 carried=  0
open_questions   authored  own= 45 carried= 11
todo             authored  own= 35 carried= 27
next_meeting     authored  own= 18 carried= 24
```

**Check the split, not just the totals.** `own_count=0` with an authored reason
is a real state; without the split it would read as a productive session.

```bash
bash workshop/platform/gates/verify-session-record.sh    # rc 0
bash workshop/platform/gates/prove-session-record.sh     # rc 0, 14 passed
```

**Vacuity**: the prover's empty-tree case must exit **2**. A record check over no
chapters has verified nothing.

## 2 — Carry-forward, and that nothing vanished

```bash
curl -s 127.0.0.1:8087/api/chapters/02 | grep -o 'CARRIED-FORWARD' | wc -l   # 126
curl -s 127.0.0.1:8087/api/chapters/02.01 | python3 -c '
import json,sys; cf=json.load(sys.stdin)["session_record"]["carry_forward"]
print("outbox:",cf["is_outbox"],"points:",cf["count"],"max_slip:",cf["max_slip_count"])'
```

Expected: `outbox: True points: 42`. **The latest chapter has no successor, so
its points must still land somewhere findable** (FR-011).

`planned=66 covered=0 carried=66 dropped=0 vanished=0`. **`covered=0` is honest,
not a stub** — no coverage decision has been recorded by anybody, and
`coverage_state: undecided` says so.

## 3 — The learner journey (US4)

```bash
AID=$(curl -s 127.0.0.1:8087/api/areas | python3 -c 'import json,sys;print(json.load(sys.stdin)["areas"][0]["id"])')
S='X-Session: quickstart'
curl -s -H "$S" 127.0.0.1:8087/api/areas/$AID/lessons | python3 -c '
import json,sys; ls=json.load(sys.stdin)["lessons"]
print("lessons:",len(ls),"with a body:",sum(1 for l in ls if (l.get("body") or "").strip()))'
```

**The header is mandatory** — without it these routes answer 400, and the browser
client omitting it made the entire surface unreachable.

Then: fetch the assessment while locked and grep the body for `prompt`,
`choices`, `correct`, `explanation` — **all must be absent**. Complete the
required lessons, re-fetch, confirm questions appear **without** answer fields,
submit, and confirm the result is stable on re-read.

## 4 — The gates, against the running build

```bash
for g in lesson-content bank-reachability session-record sc009-citation-span \
         answer-key-disclosure submission-validation server-unity crossref-currency; do
  printf '%-28s ' "$g"; bash workshop/platform/gates/verify-$g.sh >/dev/null 2>&1; echo "rc=$?"
done
```

Measured after rebuild and restart: **all rc 0**, with `server-unity` at
`PASS=43 FAIL=0 UNDET=0 DEBT=8`.

> **`verify-lesson-content.sh --live` was rc 1 before the restart** — `318 of 318
> EMPTY` — and that red arm is the point. A gate with only the arm that passes
> proves nothing.

## 5 — Cross-references, and a long job that is not a defect

```bash
bash workshop/platform/gates/verify-crossref-currency.sh
```

Measured **rc 1** immediately after restart (`generation 7 has NO crossref run`),
then **rc 0** 45 minutes later: `498580 edge(s) over 24929 source(s)`.

**The red was correct while derivation ran.** Do not treat it as a defect without
checking the container log for `deriving cross-references`.

## 6 — The QA and client documents (US3)

> **Regenerating.** The versions on disk were written at 12:30, before the
> rebuild, and describe 14 areas with tests and 0 lessons with content against a
> live 27 and 318 of 318. **A stale expected-result column manufactures false
> defects.** Both must carry the build id they were written against.

## 7 — Evidence discipline (US5)

Pick any claim in `contracts/evidence.md` and re-run its producer. It must
reproduce, and it must state its **population** — `source`, `in_process` or
`served`.

```bash
bash workshop/platform/gates/prove-answer-key-disclosure.sh   # rc 0, 16 mutations
bash workshop/platform/gates/prove-submission-validation.sh   # rc 0, 11 mutations
```

Check each battery has a **control that goes green** and a **vacuity refusal
exiting 2**. A battery of only refuse-to-pass cases is satisfied by a gate
hardwired to fail.

## What this quickstart can and cannot prove today

| Scenario | Status |
|---|---|
| 0 Population check | **PASS** |
| 1 Session record served | **PASS** — 12/12 sections, 0 empty-without-reason |
| 2 Carry-forward, vanished=0 | **PASS** |
| 3 Learner journey, real content | **PASS** — 318/318 bodies, key withheld while locked |
| 4 Gate sweep | **PASS** — 8 of 8 rc 0 |
| 5 Cross-references | **PASS** — after a 45-minute derivation |
| 6 QA + client documents | **IN FLIGHT** — regenerating against this build |
| 7 Evidence discipline | **PASS** |
| Three standalone section routes | **IN FLIGHT** |
| `/meeting-notes` route | **BLOCKED** — withholding rule is an operator decision |
| Coverage verdicts | **UNDECIDED by design** — a proposal may not move the figure |
