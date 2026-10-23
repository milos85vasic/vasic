# Open gap items at 2026-10-21 (stream S5 snapshot)

| Id | Category | Kind | Severity | plan_due | Title |
|---|---|---|---|---|---|
| AII-002 | docs-drift | weak-spot | low | 2026-10-10 | ai_interviewing documents carry unmeasurable recorded counts (53 documents) |
| CON-002 | governance-drift | weak-spot | medium | 2026-10-10 | submodules/constitution pin f8afb98ab0eb differs from all 8 remotes (direction undetermined at baseline) |
| HQA-001 | docs-drift | weak-spot | low | 2026-10-10 | submodules/qa documents carry unmeasurable recorded counts (22 documents) |
| MON-001 | docs-drift | weak-spot | low | 2026-10-10 | monetization documents carry unmeasurable recorded counts (5 documents) |
| VSC-028 | data-integrity | unfinished-promise | medium | 2026-10-10 | Decision 2026-09-08 #16 (audit 264 citations of unverified relevance) decided but not executed |
| VSC-349 | docs-drift | weak-spot | medium | 2026-10-10 | Root carriers (CLAUDE.md and its three lockstep mirrors) record status/rc and count figures with no re-measure command |
| VSC-351 | docs-drift | weak-spot | medium | 2026-10-10 | CONTINUATION.md current-state sections (0,1,4-7) record figures with no re-measure command |
| VSC-354 | docs-drift | weak-spot | medium | 2026-10-10 | INVENTORY.md section 2/3 phase-1 figures (11,101 lines; 7 nested submodules) read as current but the pin moved |
| VSC-356 | docs-drift | weak-spot | low | 2026-10-10 | Umbrella docs/** carry unmeasurable recorded counts (47 documents) |
| VSC-357 | docs-drift | weak-spot | low | 2026-10-10 | Umbrella specs/** carry unmeasurable recorded counts (32 documents, incl. this feature's own baseline README) |
| VSC-358 | docs-drift | weak-spot | low | 2026-10-10 | Five small owned modules carry unmeasurable recorded counts (llms_verifier 2, security 2, challenges 1, containers 1, ve |
| VSC-378 | false-evidence | weak-spot | medium | 2026-10-10 | Pre-push gates 1 (go test) and 6 (Playwright) cannot be inspected for vacuous passes; gate 1 has no zero-test refusal |
| VSC-379 | false-evidence | unfinished-promise | high | 2026-10-10 | No gate or registered check writes a sealed evidence record (8 pre-push gates, 59 checks, evidence store absent) |
| VSC-380 | false-evidence | unfinished-promise | medium | 2026-10-10 | Evidence anchor docs/zero-gap/anchor.json absent, so the strict chain verify returns rc 2 |
| VSC-396 | content-boundary | weak-spot | medium | 2026-10-10 | content-boundary gate left 137 files unindexed and 3 rows undetermined: those parts were never read |
| WSP-151 | governance-drift | weak-spot | medium | 2026-10-10 | Register item says BLOCKED in its title but sits at status Queued |
| WSP-165 | docs-drift | defect | high | 2026-10-10 | workshop module documents record gate/script/line counts that drifted (verify 23 vs 101, prove 27 vs 94, scripts 20 vs 4 |
| WSP-166 | docs-drift | weak-spot | low | 2026-10-10 | workshop documents carry unmeasurable recorded counts (59 documents) |
| PSG-007 | data-integrity | defect | low | 2026-10-29 | passage: Registry.WriteJSONL, SymbolAliasStore.WriteJSONL and the Sync anchor write-back rewrite files in place (os.Writ |

19 open item(s). Every item with plan_due before 2026-10-21 is a V-G10 finding; re-planning (a new plan_due) or closing needs a register write and, for closure, an independent verifier.
Stream S5 work relevant to these: VSC-379 (sealing: T065 pre-push seal + `zero-gap-seal-checks.sh`), VSC-380 (anchor: OQ-S5-ANCHOR), VSC-378 (vacuous gates 1 and 6: untouched).
