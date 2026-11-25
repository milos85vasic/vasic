# Operator decision: workable-item closures and fixer attribution, 2026-11-25

| Field | Value |
|---|---|
| Date | 2026-11-25 |
| Decided by | the operator (repository owner) |
| Anchors | section 11.4.240 (producer is not verifier), section 11.4.148 (workable-item integrity), section 11.4.6 (no guessing), section 11.4.10 (no contact data in public evidence) |
| Scope | items CON-002, HLP-001, LLP-001, LMV-001 (closure through `gap close`), VSC-398 and WSP-151 (closure by decision) |
| Companion | `docs/zero-gap/CLOSURE.md` (closure bar), `docs/operator/workable-items-gate-2026-11-25.md` (the 69 findings this resolves in part) |

## The decision, quoted

The operator was asked to name the fixer identity for the gitlink bump commits `7c5d92a` and `c5bf9ea`, which carry no
attribution beyond the git author. The operator answered, verbatim:

> `2. <the operator's contact address, withheld here>` (answering "name the fixer identity")
>
> `1. we approve it all`

The second line approves, in one decision, the closures listed in the scope row above, including closing VSC-398 and
WSP-151 by decision where no git-ref RED exists.

## What is recorded as a result

1. **Fixer of record.** For CON-002, HLP-001, LLP-001 and LMV-001 the fixer is the operator, who is the git author of
   commits `7c5d92a` (constitution pin) and `c5bf9ea` (fast-forward of constitution, LLMProvider, llm_provider and
   llms_verifier). In the register, the evidence chain and the `zero-gap:close` history rows the fixer appears as the
   handle **`operator-mvasic`**. The contact address the operator quoted is NOT reproduced in any register row, evidence
   record or document: the handle form is what the gap tool accepts (`^[A-Za-z0-9][A-Za-z0-9._@:+-]*$`), and the address
   itself is already part of those two commits' public git author data, so nothing in this change adds to it.
2. **Role separation (section 11.4.240).** Four different handles, none created to fake an identity:
   producer and CON-002 check author `wi-producer-2026-11-25` (the agent that prepared this change);
   check author of the pre-existing HLP-001, LLP-001 and LMV-001 checks `closure-wave-t047` (named in those files'
   own headers); verifier and reviewer are separate fresh sub-agents with their own handles, launched after the author
   run, each writing its own record (see `docs/zero-gap/research/` and the `ev/` records for their handles).
3. **Honest limit.** The author-labelled RED and GREEN records are sealed with `--session operator-mvasic`. The producer
   agent executed that run on the operator's behalf and on this approval; the register stores handles as text and cannot
   prove which session ran. This is the "false record" risk `docs/zero-gap/CLOSURE.md` names, and it is accepted here only
   because the operator decided the attribution in the words quoted above. The checks themselves ran for real: each
   sealed record carries the machine-captured argv, exit status and stream digests.
4. **No scope beyond the six items.** The decision does not authorise any other closure, any date extension, or any
   change to a validator rule.

## VSC-398 and WSP-151

Neither has a git-ref RED, so `gap close` cannot be satisfied for them: VSC-398 is host-cache state
(`~/.cache/ms-playwright`) and WSP-151's premise was superseded in the task list. What was found when that route was
investigated (section 11.4.102) is recorded in the pull request that carries this document and in
`docs/operator/workable-items-gate-2026-11-25.md`; this document records only that the operator approved closing them
by decision, and states which of them the tooling permitted.
