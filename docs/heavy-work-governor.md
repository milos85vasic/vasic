# Heavy-work governor (adoption of constitution §11.4.279)

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-21 |
| Status | active (adoption pointer; canon lives in the constitution submodule) |

Heavy test/build/review runs in this repository go through the constitution's shared governor, never through an ad-hoc
`flock /tmp/*.lock`, a hardcoded slot count, or an unlocked `nice -n 19` run (incident 2026-10-21: ~20 agents behind one flock,
65 waiters starved 40+ minutes, agents fell back to unguarded heavy runs).

- Canon: `submodules/constitution/Constitution.md` §11.4.279; tool: `submodules/constitution/scripts/governor/heavy` (README beside it).
- Agent command: `heavy run --class <critical|review|build|explore> --weight <light|medium|heavy> --timeout <s> -- <cmd>`
  (`heavy <cmd>` = `--class build --weight medium`). Exit `2` = COULD-NOT-ACQUIRE: the command did NOT run, never a pass.
- The operator-local shim `~/.cache/claude-tmp/bin/heavy` `exec`s the constitution tool (no logic of its own).
- Orchestrators: brief every parallel agent with the command above, choose the class by the work's role (integration/verification
  on the critical path = `critical`), and size the fan-out against `heavy calibrate` before dispatch.
- Pin note: until the constitution pin contains §11.4.279 (an operator decision, see the constitution pin authorization terms),
  the shim falls back to the governor worktree path.
