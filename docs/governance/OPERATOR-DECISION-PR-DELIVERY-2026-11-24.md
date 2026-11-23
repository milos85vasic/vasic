# Operator decision: pull-request delivery (anchor 11.4.297)

| Field | Value |
|---|---|
| Revision | 1 |
| Recorded | 2026-11-24 |
| Decision date | 2026-11-23/24 (operator instruction in session; identifier UNCONFIRMED, §11.4.297 forensic anchor) |
| Canon | `submodules/constitution/Constitution.md` §11.4.297 (with §11.4.288, §11.4.66, §11.4.142) |
| Declaration (DATA) | [`pr-delivery.yaml`](pr-delivery.yaml) |
| Scope | the `vasic` umbrella repository (`milos85vasic/vasic`); each own submodule delivers as its own pull request before the parent pin bump (clause F) |

## The decision

The operator decided: **"PR-driven work: task branch, one PR per task, independent review agents, merge to main by the agent."**

Under §11.4.297(A) that is the recorded operator decision that selects `mode: pr` for this project. Without it the
anchor has no effect except clause (G) and §11.4.288 (direct work on `main`) applies as written.

## What it changes, and what it does not

- Changes exactly the three points of §11.4.297(A): the task branch is the recorded necessity (A.1), the merge of a
  GO'd pull request is the landing (A.2), and the landing form is a merge commit (A.3, `gh pr merge --merge`).
- Does NOT change §11.4.113 (never force-push; no squash or rebase merge), §11.4.142 / §11.4.209 (independent review
  and its source-correctness GO; the author's self-review is never the GO), §11.4.240, §11.4.181 or §11.4.288 otherwise.

## Honest status (§11.4.297(G))

| Claim | Word |
|---|---|
| The decision is recorded and the declaration file exists | PROVISIONAL |
| A delivery tool refuses a malformed task, foreign commit or stale base | UNCONFIRMED: this repository ships no delivery tool |
| A direct-push guard blocks pushes to `main` | UNCONFIRMED: `direct_push_guard: off` |
| Reviewer assignment read back from the platform | UNCONFIRMED: author-only list; no second account requested |

No mechanism is claimed ENFORCED. The hosting platform here still offers squash and rebase merges; that setting is an
operator action in the provider UI and is not changed from this tree.

## Open operator questions

1. Add a second reviewer account to `pr_reviewers`? (Not done: the platform notifies every listed account.)
2. Declare a `merge_window` and a delivery tool (the constitution ships none; §11.4.297(H) expects the project's own).
