# Contract — What a claim must carry

## Every claim states its population

**`source` · `in_process` · `served`.** The same figure over different
populations is a different fact, and reporting one as another is this project's
most-repeated defect — four times in one day.

The canonical instance: **on disk 42 areas / 30 with an assessment / 224
questions; on the wire 39 / 14 / 116.** Both readings correct. Only one described
the product.

## Every claim carries its state

A build identifier, a corpus fingerprint, or both. **A reading with neither
cannot be trusted once the tree moves** — and this tree moved all day. A
measurement bracketed by identical fingerprints is attributable; one that is not
must say so.

## Every check is three-valued

**0 satisfied · 1 a real finding · 2 could-not-determine.** A finding outranks a
could-not-determine, which outranks clean. **A 2 is never recorded as satisfied.**

## Every check ships a paired proof

Mutations are **DATA** — fixtures, env vars, arguments — **never edits to the
thing under test**. The subject's source hash is captured before the battery and
re-asserted after.

Each battery carries:

- a **control that goes green** — a battery of only refuse-to-pass cases is
  satisfied by a gate hardwired to fail;
- a **vacuity refusal exiting 2** — an absence assertion over an empty set has
  checked nothing;
- where the check forbids something, an **overreach mutation** — the legitimate
  case that must NOT fire.

## Every check states its population

**The SET is justified independently of the count it produces.** Three defects in
one day were instruments aimed at the wrong set while reporting cleanly. If you
add a case and then check whether the number moved, you are tuning to a result.

## Every known gap is recorded

With its reason and **who may lift it**. An exemption is a claim about a file at
a moment in time, and changing the file can falsify it silently.

## Currently admissible, measured after rebuild and restart

| Claim | Population | Verdict |
|---|---|---|
| 39 served / 3 held back / 42 total | served | rc 0 |
| 27 areas with a test, 205 questions | served | rc 0 |
| 318 of 318 lessons carry a body | served | rc 0 |
| four sections with carry-forward | served | rc 0 |
| 205 of 205 video anchors resolve | served | rc 0 |
| 7 hue families (floor 6), 200 contrast pairings | served, bracketed | rc 0 |
| answer key absent while locked | served | rc 0 |
| 498,580 cross-reference edges, generation 7 | served | rc 0 |
| 1,933 boundary rows judged, 0 disclosures | source | rc 1 by design |
