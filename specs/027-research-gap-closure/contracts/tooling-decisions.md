# Contract: Tooling decisions (33 rows)

Seed for `docs/tooling/TOOLING-REGISTER.md` (FR-001). Source: `workshop/docs/research/skills-and-plugins-2026-09-01.md` (called "the research"). Dispositions are DELEGATE DEFAULTS recommended by the authoring agent from the research's own reasoning and the repository facts cited; the operator may amend any of them. "Host" facts come from the plugin names enabled in `~/.claude-claude5/settings.json` on 2026-10-21 (names only; one alias; other aliases not read). A row marked **ADOPT** here means "adoption is consistent with the research and creates no new trust"; installing anything not already enabled is NEEDS-OPERATOR NO-10.

Disposition key: BUILD, ADOPT, ADVISORY-ONLY, REJECT, BUILT-ALREADY.

| # | Item (research ref) | Disposition | Reason (evidence) | Host state | Drift flag |
|---|---|---|---|---|---|
| 1 | `chrome-devtools-mcp` (§6 #1, §7.1) | ADOPT | Skills only, no MCP server of its own, 659 always-on tokens (research §6); gives a11y guidance; the repository's accessibility gate stays `@axe-core/playwright` | enabled | no |
| 2 | `anthropics/skills` theme-factory, webapp-testing, docs suite (§6 #2, §7.2) | ADVISORY-ONLY | `webapp-testing` duplicates Playwright specs already run (research §8 `playwright`); `theme-factory` overlaps the repository's design-token source; no root licence (research §7.2); revisit when markdown-export work (G8) starts | `frontend-design@anthropics` and `code-review@anthropics` enabled; the marketplace's other skills not | no |
| 3 | `claude-security` (§6 #3) | ADVISORY-ONLY | Findings are leads, never a PASS source (binary result plus a lifecycle hook, research §6); §11.4 requires runtime evidence | enabled | no |
| 4 | `trailofbits/skills` property-based-testing (§6 #4, §7.3) | BUILD (the technique, in-repo; FR-033) and NEEDS-OPERATOR NO-10 (the skill: CC-BY-SA-4.0) | The scoring and three-state contracts are invariant-shaped; no property-test library is in `platform/backend/go.mod` or `platform/frontend/package.json` (grep 2026-10-21 found none) | not enabled | no |
| 5 | `mattpocock-skills` (§6 #5) | ADVISORY-ONLY | Overlaps `superpowers` on TDD, debugging and review; 1,614 always-on tokens (research §7.3) | enabled | no |
| 6 | `trailofbits` mutation-testing / `mewt` (§6 #6) | REJECT | AGPL-3.0 engine, configures but does not analyse, no shell coverage (research §9.1); role served by BUILT-ALREADY row 9.1 | not enabled | no |
| 7 | `lyonzin/knowledge-rag` (§6 #7) | ADVISORY-ONLY | A retrieval system that evaluates itself, not a harness (research §9.7); harness is BUILD row 9.7 | not enabled | no |
| 8 | `mlflow` plugin (§6 #8) | REJECT (plugin); BUILD the metrics in-repo | 2,127 always-on tokens, the highest measured, plus a `UserPromptSubmit` hook (research §8); metrics are small and deterministic (FR-027) | enabled | **yes: register says REJECT, host enables** |
| 9 | `Kaiser0733/receipts` (§6 #9) | ADVISORY-ONLY | 1 star (research §6); staleness idea is worth keeping, and evidence manifests with sha256 already exist; equivalence with §11.4.268 UNCONFIRMED | enabled | no |
| 10 | `GarethManning/education-agent-skills` (§6 #10, §7.5b) | ADVISORY-ONLY pending NO-10 | CC BY-SA 4.0 share-alike would bind derivative curriculum content; produces judgement, not gate-able numbers (research §9.4); gate is BUILD row 9.4 | not enabled | no |
| 11 | `modern-web-guidance` (§6 #11, §7.5) | ADOPT | Offline, no key, Apache-2.0; frontend is a major behind (research §7.5) | enabled | no |
| 12 | `superpowers` 6.1.1 to v6.3.0 (§6 #12, §7.4) | ADOPT (operator action) | Already trusted; installed version not read, UNCONFIRMED | enabled (`@anthropics` and `@claude-plugins-official` both) | note: two sources enabled |
| 13 | `MasterPlayspots/motionspec` (§6 #13) | ADVISORY-ONLY | 0 stars (research §7); motion policy is owned by 025 US3 | not enabled | no |
| 14 | `figma` (§6 #14) | REJECT for now | 2,074 always-on tokens, account, egress, no licence (research §7 "not on the shortlist") | enabled | **yes** |
| 15a | `typescript-lsp`, `context7` (§6 #15) | ADOPT | Low risk (research §6 #15) | enabled | no |
| 15b | `playwright` plugin (§6 #15, §8) | ADVISORY-ONLY | Duplicates Playwright already run by the project's gates | enabled | **yes** |
| 16 | Deque `axe-accessibility` (§6 #16) | REJECT | Proprietary server, paid subscription, egress (research §8) | not enabled | no |
| 17 | `kanso-protocol` (§6 #17) | ADVISORY-ONLY | Read its CI gate design for row 9.8; 3 stars, not a dependency | not enabled | no |
| 18 | `serena` (§6 #18) | REJECT | Overlaps `lumen`; catalogue pin 9 months stale (research §6) | not enabled | no |
| 19 | `trailofbits/skills-curated` (§6 #19) | ADVISORY-ONLY | Stale, CC-BY-SA | not enabled | no |
| 20 | `deepeval` (§6 #20, §8) | REJECT as a gate | LLM-as-judge metrics are not reproducible; no local generative model for an offline judge (research §8) | enabled | **yes** |
| 21 | `KyaniteLabs/kinocut` (§6 #21) | ADVISORY-ONLY | Filesystem and ffmpeg reach; row 9.6 is a script on the repository's own ffmpeg | not enabled | no |
| 22 | `codspeed`, `sonarqube` (§6 #22) | ADVISORY-ONLY | Premature without a CI loop, which §11.4.156 forbids at the umbrella root (research §8) | enabled | **yes (minor)** |
| 23 | `ankimcp/anki-mcp-server` (§6 #23) | REJECT | Needs the Anki desktop app; spaced repetition is DEFERRED by 025 P10 | not enabled | no |
| 9.1 | Paired-mutation-for-gates primitive (§9.1) | BUILT-ALREADY | `scripts/verify-check-registry.sh:1-40` enforces a paired proof per check; the workshop carries `platform/gates/check-registry-{001,002,003,006,008,009}.tsv` with `prove-check-registry-*.sh`; the research's "no tool pairs a gate with its mutation" is superseded for this repository | n/a | no |
| 9.2 | Contract testing (§9.2) | BUILT-ALREADY (local) | `platform/gates/verify-contract-{http,cli,pid}.sh` exist (listing 2026-10-21); Schemathesis and Pact stay ADVISORY-ONLY | n/a | no |
| 9.3 | Three-valued check semantics (§9.3) | BUILT-ALREADY | The 0/1/2 contract is the house rule and registry R-checks execute the rc-2 branch; wrapper rule for third-party gates is FR-004 | n/a | no |
| 9.4 | Quiz-bank validation (§9.4) | BUILD | FR-020/021; precondition CK021 already logs areas without assessments; `platform/gates/lib/question_shape.py` covers shape only | n/a | no |
| 9.5 | Transcription QA (§9.5) | BUILD | FR-022-026; the harness exists, the threshold gate and CER do not | n/a | no |
| 9.6 | Subtitle, WebVTT, chaptering (§9.6) | BUILD (WebVTT), ADVISORY-ONLY (chaptering) | FR-029; chaptering is P16, DEFERRED by 025 | n/a | no |
| 9.7 | Retrieval-quality evaluation (§9.7) | BUILD | FR-027; benchmark reports top-1/top-5 only (`run_retrieval_benchmark.py:149,245-267`) | n/a | no |
| 9.8 | Design-token contract verification (§9.8) | BUILD | FR-028; `verify-served-contrast.sh` and `design-tokens.spec.ts` exist, token-usage gate does not | n/a | no |
| 9.9 | Prose and readability linting (§9.9) | BUILD (limited) | FR-030; user-facing documents only; any CLI needs a §11.4.270 dependency verdict | n/a | no |

Counts: 23 shortlist items (item 15 split in two rows for host-state accuracy, so 24 rows), item 5b folded into row 10 (the research ranks it as #10 in §6 and presents it as "5b" in §7), plus 9 gap rows: 33 rows including the split. The check (FR-002) counts research rows, not these rows, so the split cannot hide a missing item.

Host drift summary (FR-003 output on 2026-10-21): enabled while the register says REJECT or ADVISORY-ONLY: `mlflow`, `figma`, `playwright`, `deepeval`, `codspeed`, `sonarqube`. Not remediated: enabling and disabling plugins is an operator action.
