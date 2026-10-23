# Operator queue — stream S5 (spec 010 umbrella), items needing an operator action

Nothing here was executed. Each item states cost, exact commands, owner, recheck date and rollback.
No credential values appear in this file.

## OQ-S5-ANCHOR (task T083, FR-009/FR-016) — first tracked evidence anchor

| Field | Value |
|---|---|
| Owner | operator (the commit is a tracked-state decision; push is an operator decision) |
| Recheck date | 2026-10-28 |
| Cost | about 5 minutes; no third-party service; one `git push` of one 1-line JSON file |
| Until it lands | `bash scripts/zero-gap-evidence-chain.sh --verify` MUST read rc 2 (anchor has no committed history / is unwitnessed). Re-measured in this worktree: rc 2 (store absent). Demonstrated end to end on a throwaway repo: `docs/zero-gap/n7s5/T083-scratch-demo.txt` (rc 2 before the commit, rc 0 after commit+push) |

Expected shape of the file (exact keys, no paths inside): `{"head_digest":"<64 hex>","entry_count":<N>,"anchor_strength":"policy"}`
(`policy`, not `mechanism`: the only upstream is append-only by policy, research D6).

Commands (run in the MAIN checkout, which holds the untracked chain store `.remember/logs/zero-gap/evidence/`):

```bash
cd /home/milosvasic/Projects/vasic
bash scripts/zero-gap-evidence-chain.sh --verify            # expect rc 2 BEFORE (no committed anchor yet)
bash scripts/zero-gap-evidence-chain.sh --anchor-write --remote origin
cat docs/zero-gap/anchor.json                                # shape check
git add -- docs/zero-gap/anchor.json                         # named path only
commit "docs(zero-gap): first tracked evidence anchor (T083)"  # project wrapper; pushes fast-forward to every upstream
bash scripts/zero-gap-evidence-chain.sh --verify            # expect rc 0 and `history: ok witness origin/main`
```

Rollback: the anchor is forward-only by design (a lower count is refused as DETECTED). If the wrong store was anchored, do NOT
rewrite history (§11.4.113); re-anchor from the correct store at a higher count, or add a documented supersession commit.

## OQ-S5-TIMER (task T072, FR-019) — install the daily timer

| Field | Value |
|---|---|
| Owner | operator (host configuration) |
| Recheck date | 2026-10-28 |
| Cost | about 5 minutes; the job itself runs with `Nice=10`, idle IO, `MemoryMax=16G`, refuses under host pressure, takes a flock |
| Depends on | OQ-S5-ANCHOR (the job's evidence-chain step wants a verifying anchor) |

Units: `ops/systemd/zero-gap-daily.{service,timer}` (templates with `@REPO@`, verified with `systemd-analyze --user verify`,
`docs/zero-gap/n7s5/T070-systemd-analyze.txt`). Commands, rollback and the linger note: `ops/systemd/README.md`.

```bash
R=/home/milosvasic/Projects/vasic     # the MAIN checkout (the worktree has no submodules)
mkdir -p ~/.config/systemd/user
for u in zero-gap-daily.service zero-gap-daily.timer; do sed "s#@REPO@#$R#g" $R/ops/systemd/$u > ~/.config/systemd/user/$u; done
systemctl --user daemon-reload
systemctl --user enable --now zero-gap-daily.timer
```
Rollback: `systemctl --user disable --now zero-gap-daily.timer && rm ~/.config/systemd/user/zero-gap-daily.*; systemctl --user daemon-reload`.

Register entry: this item must be added as an `Operator-blocked` register row by whoever holds the register
(`workable-items-vsc gap classify` on the tracked `docs/workable_items.db`); this stream did not edit the tracked binary database
because sibling streams write it concurrently and a binary merge would lose rows.
