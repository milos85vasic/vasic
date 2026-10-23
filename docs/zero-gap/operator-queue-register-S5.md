# Operator queue — every classified register item (T050, stream S5)

Generated 2026-10-21 from the tracked register `docs/workable_items.db` (opened read-only) by this stream. **The register itself stores owner and recheck date for these items but NO unblock options and NO cost (0 of 50 bodies contain `cost:`); the options and costs below are this stream's grouped proposals, labelled estimates, for the operator to confirm. Nothing was executed and the register was not edited.**

| Group | What |
|---|---|
| G1 | Owned gitlink behind its remote |
| G10 | Exposed credentials |
| G11 | Gate-like scripts without failure proofs |
| G2 | Binary built only when absent / stack not redeployed |
| G3 | Content-boundary re-baseline decision |
| G4 | Gate/binary identity defect inside a private module |
| G5 | Register hygiene item |
| G6 | Host browsers/libraries absent |
| G7 | Adopted item with no measurable target |
| G8 | Upstream HelixConstitution guard/boundary gap (third-party) |
| G9 | Project-level guard wiring |

## Groups: unblock options and cost

**G1 — Owned gitlink behind its remote.** A. fast-forward bump: `git -C <sub> fetch`; `merge-base --is-ancestor`; `rev-list --left-right --count` must show 0 divergent; `git merge --ff-only`; stage gitlink AND `helix-deps.yaml` ref together; run `verify-manifest-pins.sh` and `verify-submodule-remote-sync.sh` (cost: ~10 min per module, estimate). B. hold, with a new recheck date (cost: the drift persists; the sync gate stays RED for that row).

**G10 — Exposed credentials.** Follow `docs/zero-gap/operator-queue-T086.md` (rotate both accounts; ~20 min operator time; ends open sessions).

**G11 — Gate-like scripts without failure proofs.** A. write a paired `--prove-failure` for each script in the owning module (owner: module; cost estimate 2-6 h per module) and register it. B. record a documented exemption row with a lifting condition (scripts/check-registry.tsv `exempt`). C. re-date.

**G2 — Binary built only when absent / stack not redeployed.** A. change the module's start/ingest script to rebuild when the source is newer than the binary, with a RED test (owner: module repo; cost: small patch + proof, estimate 1-2 h each). B. for the running stack only (WSP-169): redeploy now with the module's own `scripts/restart.sh` (cost: minutes, brief downtime; operator action). C. accept and re-date.

**G3 — Content-boundary re-baseline decision.** Options 1-4 of the decision packet in CLAUDE.md ("Content-boundary re-baseline - the decision packet"): 1 do nothing; 2 allow-list classes B/C as declared pairs (hides rows from the next reader); 3 direction pass (SHIPPED 2026-09-09); 4 judge the surviving inward rows (largest cost, the only option that can find a new disclosure). Cost of the decision itself: operator reading time; option 4 is days (estimate).

**G4 — Gate/binary identity defect inside a private module.** A. fix in the module (stamp the build identity / make the gate read the prose it guards) with RED/GREEN (owner: module; cost estimate 1-3 h). B. accept and re-date.

**G5 — Register hygiene item.** A. edit the register row (status/title) and close with evidence, or record the decision (cost: minutes; needs a register commit). B. re-date.

**G6 — Host browsers/libraries absent.** A. `sudo apt-get install -y libmanette-0.2-0 libwoff1` then `(cd _tests && npx playwright install firefox webkit)` (cost: ~5 min, host package install = operator action); then `node _tests/preflight.js` must exit 0. B. keep gate 6 chromium-only and re-date.

**G7 — Adopted item with no measurable target.** A. give it a measurable target (`gap` edit) so it becomes workable. B. close as obsolete with evidence. C. re-date. (cost: ~10 min judgement per item, estimate; WSP-042 is an operator-decision.)

**G8 — Upstream HelixConstitution guard/boundary gap (third-party).** A. report upstream (no change in this repository; project-level mitigation VSC-367 / `guard-project-catalogue.sh` covers the class meanwhile). B. wait for an upstream pin move under the standing fast-forward authorization. Cost to this repository: none.

**G9 — Project-level guard wiring.** A. confirm the project PreToolUse hook is wired in `.claude/settings.json` and that `scripts/verify-pretooluse-guard.sh` is green, then reclassify/close with that evidence (cost: ~15 min).

## Items

| Id | Category | Class | Owner | Recheck | Elapsed at 2026-10-21 | Group | Title |
|---|---|---|---|---|---|---|---|
| AII-004 | build-freshness | operator-action | operator | 2026-10-15 | YES | G2 | ai_interviewing start and ingest scripts build the server only when the binary is absent: a restart runs a sta |
| LMV-003 | build-freshness | operator-action | operator | 2026-10-15 | YES | G2 | LLMsVerifier scripts build their binaries only when absent (generator + provider challenge) |
| WSP-169 | build-freshness | operator-action | operator | 2026-10-15 | YES | G2 | workshop platform serves build 185fb15 while workshop HEAD is e076fa6: the stack was not redeployed after the  |
| CON-009 | content-boundary | third-party | operator (upstream HelixConstitution) | 2026-10-26 | no | G3 | content-boundary group C (upstream part): rows inside the constitution submodule |
| VSC-389 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary re-baseline decision: 14621 surviving gate rows over 121 public path classes await an operato |
| VSC-390 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary group A: spec trees in the public umbrella (specs/**) |
| VSC-391 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary group B: public reusable modules (submodules/** except the constitution, design-toolkit) |
| VSC-392 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary group C: governance prose in the umbrella (docs, scripts, carriers, manifests, allow files) |
| VSC-393 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary group E: rendered exports (PDF/HTML) of governance documents |
| VSC-394 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary group S: public site content — one name-class row in each of 11 localized product page sets |
| VSC-395 | content-boundary | operator-decision | operator | 2026-10-03 | YES | G3 | content-boundary remainder: tooling, evidence and spec-kit files (.specify, _tools, _tests, _analysis, .ashlrc |
| AII-005 | false-evidence | operator-action | operator | 2026-10-22 | no | G4 | ai_interviewing's running build carries no source identity: the served binary cannot be tied to its source |
| WSP-167 | false-evidence | operator-action | operator | 2026-10-22 | no | G4 | workshop verify-plan-coverage-proposal.sh passes without reading the prose it guards (66 vs 49 rows) |
| HLP-001 | governance-drift | operator-decision | operator | 2026-10-03 | YES | G1 | submodules/llm_provider gitlink f29fe2439c81 behind origin e05ec64ebc48 |
| LLP-001 | governance-drift | operator-decision | operator | 2026-10-03 | YES | G1 | submodules/LLMProvider gitlink 4c73c8b0dfc6 behind its remote tip e05ec64ebc48 (fast-forwardable) |
| LMV-001 | governance-drift | operator-decision | operator | 2026-10-03 | YES | G1 | submodules/llms_verifier gitlink 2c6602c78931 behind origin 8f2090acb907 |
| VSC-285 | governance-drift | operator-action | operator | 2026-11-08 | no | G5 | Register item says BLOCKED in its title but sits at status Queued |
| VSC-362 | governance-drift | operator-decision | operator | 2026-11-08 | no | G5 | Decision record 2026-09-09: three findings from #12 not yet decided (row repair) |
| VSC-398 | host-capability | operator-action | operator | 2026-10-15 | YES | G6 | Playwright firefox and webkit browser binaries are absent: harness preflight reports CANNOT DETERMINE (rc 2),  |
| VSC-070 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| VSC-078 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| VSC-079 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| VSC-125 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| VSC-293 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| VSC-300 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| VSC-301 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-028 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-042 | other | operator-decision | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-054 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-060 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-062 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-066 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-068 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| WSP-125 | other | operator-action | operator | 2026-10-22 | no | G7 | Pre-existing Queued register item adopted as a zero-gap item with no measurable target |
| CON-003 | security | third-party | operator | 2026-10-26 | no | G8 | PreToolUse guard: host-power rule misses bare reboot/halt/poweroff binaries |
| CON-004 | security | third-party | operator | 2026-10-26 | no | G8 | PreToolUse guard: no rule for ref and history destruction (branch -D, update-ref -d, filter-branch, push --del |
| CON-005 | security | third-party | operator | 2026-10-26 | no | G8 | PreToolUse guard: no rule for uncommitted-work discard on a shared tree (reset --hard, checkout ., restore .,  |
| CON-006 | security | third-party | operator | 2026-10-26 | no | G8 | PreToolUse guard: no rule for bulk staging (git add -A, git add .) |
| CON-007 | security | third-party | operator | 2026-10-26 | no | G8 | PreToolUse guard: no rule for signalling processes by name or pattern (pkill -f, killall) |
| CON-008 | security | third-party | operator | 2026-10-26 | no | G8 | PreToolUse guard: no rule for recursive removal of / or ~ |
| VSC-367 | security | operator-action | operator | 2026-10-22 | no | G9 | Project-level PreToolUse mitigation enforcing docs/zero-gap/guarded-commands.tsv until the upstream guard catc |
| VSC-387 | security | operator-decision | operator | 2026-10-01 | YES | G10 | two predefined-user passwords stated literally in the public spec 007 (15 lines, 5 files), pushed to the publi |
| VSC-397 | security | operator-action | operator | 2026-10-15 | YES | G10 | T086: rotate the milosvasic and <participant-handle> account passwords exposed in public specs/007 (workshop + |
| AII-003 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | ai_interviewing: two gate-like scripts without failure proofs (private module; paths only) |
| LMV-002 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | llms_verifier local verify/validate/challenge scripts (12) have no failure proofs |
| VSC-368 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | CONST-033 no-suspend scanner copied into 11 owned submodules with no paired failure proof |
| VSC-369 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | CONST-050(B) anti-bluff challenge family (8 test types) cascaded into 8 owned submodules with no paired failur |
| VSC-370 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | LLMProvider-lineage shared challenges (apikeys discovery, suspend contract, upstreams recipe origin) have no f |
| VSC-371 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | Per-module compile/functionality/unit challenge trio (RAG, security) has no failure proofs |
| WSP-168 | test-coverage | operator-action | operator | 2026-10-22 | no | G11 | workshop: two gate-like scripts without failure proofs (private module; paths only) |

50 classified item(s); 16 with an elapsed recheck date (V-G2 finding each). Open items with an elapsed `plan_due` (V-G10, 18 at 2026-10-21) are listed in `docs/zero-gap/n7s5/register-open-items.md`.
