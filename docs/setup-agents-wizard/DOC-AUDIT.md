# Documentation Audit — `docs/setup-agents-wizard/`

Read-only correctness audit of the seven-document set against the three scripts it documents.
Nothing outside this file was created, edited or executed against the real environment.

## Scope and method

| Artifact | State audited (`sha256`) | Lines |
| :--- | :--- | ---: |
| `scripts/setup-agents-wizard.sh` | `7f2fc18b6c0b0ed32465ae9efd992130b544b6846e19ff2c5f3167647827624f` | 1017 |
| `scripts/rollback-agents-wizard.sh` | `5c54f38e61e213b4f6da09378268b2e23806b574014372170a3166af35af9ab0` | 171 |
| `scripts/test-setup-agents-wizard.sh` | `5c33717362c29839f330e51337120930099d0cd52d557915fa6ea1e5e9f2ef3b` | 589 |
| `docs/setup-agents-wizard/ARCHITECTURE.md` | `7f927db13916f68f005fff46cd53154cdf17524acadb91f3511ed9c5e846487d` | 407 |
| `docs/setup-agents-wizard/FAQ.md` | `e12c78638e8116e7f53bb797ea2ffadee2da00a6636ab61b79a064a07da84c9a` | 556 |
| `docs/setup-agents-wizard/MANUAL.md` | `b10854dd300f77e06129fd0179a9ca7f97dff863aa65c2984694bbfc76c585ae` | 624 |
| `docs/setup-agents-wizard/README.md` | `ce521ff45cd4f007cd3cd24785fd7620c595f35b2154a8ee5aacb62b60593b3b` | 411 |
| `docs/setup-agents-wizard/SAFETY-AND-ROLLBACK.md` | `2d19e2b0297440ccf1f893ed8e8395678ead43b8c46c4b867c6e49cc981a8c72` | 616 |
| `docs/setup-agents-wizard/TROUBLESHOOTING.md` | `b0be08a8b7d026b9853536589d8275fdc3703c3772d29dd87ef9bf8034643afe` | 716 |
| `docs/setup-agents-wizard/USER_GUIDE.md` | `13db707047a1403ee51120d8dac671edca8e71446556791edc243714e56e6fb0` | 443 |

> **The three scripts changed twice while this audit was in progress** (two rounds of edits by
> another process). All findings below are stated against the hashes in the table above, which
> were stable for the final 3+ minutes of the audit. The seven documents did **not** change at
> any point. If the scripts move again, re-verify the rows marked *(new behaviour)*.

Checks performed: extraction and verification of every command, flag, path, package and
environment variable named in the docs; a full static inventory of the test suite; a
`github-slugger`-equivalent resolution of all 86 relative links and in-page anchors; an
`mmdc` 11.12.0 render of all six Mermaid blocks; and live probing of the installed
`lumen 0.0.41` CLI to check the flag tables.

---

## Verdict

**67 findings: 17 Critical, 41 Major, 9 Minor.**

Three whole subsystems that the wizard performs today are **absent from all seven documents**:
the Step 7 project-indexing pass (`WIZARD_INDEX_PROJECT`), the glyphdown-hook opt-out
(`WIZARD_SKIP_GLYPHDOWN_HOOK`), and the telemetry opt-out (`configure_telemetry_optout`,
`WIZARD_KEEP_TELEMETRY`) which writes a third managed block into `~/.bashrc`, runs
`codegraph telemetry off` and edits `~/.qwen/settings.json`. Grep across all seven files
returns zero hits for `WIZARD_SKIP_GLYPHDOWN_HOOK`, `WIZARD_INDEX_PROJECT`,
`WIZARD_KEEP_TELEMETRY`, `telemetry`, `DO_NOT_TRACK`, `usageStatisticsEnabled` and `Step 7`.

`ARCHITECTURE.md` is the worst-affected document: its statement at line 11 that "Every diagram
below is derived from the current code" is false — two of its six diagrams depict the exact
behaviour the wizard removed and the test suite now forbids.

`SAFETY-AND-ROLLBACK.md` and `MANUAL.md` are otherwise the most accurate documents, but both
now carry stale rollback semantics (`MODIFIED` vs `CREATED`, and the SpecKit undo action) that
the most recent script edit inverted.

**`TROUBLESHOOTING.md` is very nearly clean** — one Minor finding only.

Also verified clean, with no findings at all:

- **Cross-links:** all 86 relative markdown links and in-page anchors resolve. Zero broken.
- **Mermaid:** all six ```mermaid blocks in `ARCHITECTURE.md` render successfully under
  `mmdc` 11.12.0 (blocks at lines 31–131, 151–189, 209–235, 254–300, 330–348, 368–390).
  No parse errors. Their *content* is wrong in places (see findings); their *syntax* is fine.
- **Stale `@qoomon/lumen` / `"args": ["serve"]` presented as current:** none. Every occurrence
  is either `codegraph`'s legitimate `serve`, or is explicitly framed as a documented past bug.
- **Embedded script listing in `README.md`:** correctly removed; `README.md:378` and
  `MANUAL.md:8-9` describe its removal rather than reproducing it.

---

## Findings

### Critical

| File | Line | Incorrect claim (quoted) | What the code actually does | Suggested correction |
| :--- | ---: | :--- | :--- | :--- |
| `ARCHITECTURE.md` | 11 | "Every diagram below is derived from the current code." | Diagram 1 (§1) and diagram 4 (§4) describe the pre-fix wizard: bare-name npm agent installs, scoped-name retries, five wrong MCP config paths and a `ToolCall` hook. None of that exists in `scripts/setup-agents-wizard.sh`. | Redraw diagrams 1 and 4 from the current script, then keep the sentence. |
| `ARCHITECTURE.md` | 51 | `    AGT["npm i -g kimi, opencode, mimo, qwen-code"] --> AGTQ{"install failed?"}` | The wizard never npm-installs these. Lines 656–665 are a detection-only roll call printing the vendor URL. Only `qwen` is installed, from `@qwen-code/qwen-code` (line 653). Test `A13` asserts `npm install -g (kimi\|opencode\|mimo\|qwen-code)` appears **zero** times. | Replace with a detection node: "detect kimi / opencode / mimo → print vendor URL if missing" and a separate `npm_install_if_missing qwen "@qwen-code/qwen-code"` node. |
| `ARCHITECTURE.md` | 52 | `    AGTQ -- yes --> AGTF["retry scoped names<br/>kimi/cli, opencode/cli, mimo/cli, qwen-code/cli"]` | No scoped-name retry exists. Test `A12` asserts `@kimi/cli`, `@opencode/cli` and `@mimo/cli` never appear on an executable line. | Delete the `AGTQ`/`AGTF` retry branch entirely. |
| `ARCHITECTURE.md` | 92–96 | `M1["Step 5 - configure MCP servers"] --> MC["~/.claude/mcp.json"]` … `MK["~/.kimi/config.json"]` … `MO["~/.opencode/config.json"]` … `MM["~/.mimo/config.json"]` … `MQ["~/.qwen-code/config.json"]` | All five are the orphan paths the wizard stopped writing. Real targets: `claude mcp add-json … -s user` (line 731), `~/.kimi-code/mcp.json` (793), `~/.config/opencode/opencode.json` (801), `~/.qwen/settings.json` (830); MiMo Code gets **no file** (823–827). | Replace the five node labels with the real targets and make the MiMo node a "manual step, nothing written" terminal. |
| `ARCHITECTURE.md` | 98 | `    MPL --> MHK["jq: add glyphdown ToolCall hook<br/>to ~/.claude/settings.json"]` | The wizard writes `.hooks.PreToolUse` and `.hooks.PostToolUse` (lines 777–785). Test `A21` asserts the literal `"ToolCall"` is **absent**. The step is also skipped when `glyphdown` is missing or `WIZARD_SKIP_GLYPHDOWN_HOOK` is set. | "jq: ensure glyphdown PreToolUse + PostToolUse hooks", with guard branches for `glyphdown` missing and `WIZARD_SKIP_GLYPHDOWN_HOOK` set. |
| `ARCHITECTURE.md` | 272–277 | `M1["~/.claude/mcp.json"]` … `M3["~/.kimi/config.json"]` … `M4["~/.opencode/config.json"]` … `M5["~/.mimo/config.json"]` … `M6["~/.qwen-code/config.json"]` | Same orphan paths as above, repeated in the "Files touched" diagram. `~/.mimo/config.json` in particular is shown as a jq-merged config for an agent the wizard writes nothing for. | Same correction as the row above; drop the MiMo node from the `MG` subgraph. |
| `ARCHITECTURE.md` | 273 | `        M2["~/.claude/settings.json<br/>glyphdown ToolCall hook"]` | `PreToolUse` / `PostToolUse`, not `ToolCall`. | `"~/.claude/settings.json<br/>glyphdown PreToolUse + PostToolUse hooks"` |
| `ARCHITECTURE.md` | 303 | "All five agents receive the **identical** MCP block — `lumen` pointed at the absolute wrapper path with args `[\"stdio\"]`, plus `codegraph` with args `[\"serve\"]`." | Only Kimi and Qwen Code get that block (`configure_mcp_for_agent`, lines 141–175). Claude Code gets `lumen` only, via the CLI. Opencode gets `lumen` only, in the `.mcp` schema as `{"type":"local","command":[…,"stdio"],"enabled":true}` — `MANUAL.md:266` correctly says "CodeGraph is not added here". MiMo Code gets nothing. | "Kimi and Qwen Code receive both servers in `.mcpServers`; Claude Code and Opencode receive `lumen` only, each in its own form; MiMo Code receives nothing." |
| `ARCHITECTURE.md` | 315 | "`scripts/test-setup-agents-wizard.sh` runs six groups." | Eight groups: `A`–`H`. `group "H. Telemetry opt-out (isolated \$HOME)"` is declared at test line 392 and `group "G. …"` at 446. `README.md:269` says "seven groups" — the two documents contradict each other, and both are now wrong. | "runs eight groups (A–H)"; add rows for `G` and `H` to the table at 320–327. |
| `MANUAL.md` | 128 | "Note the `{}` is written *before* `backup_file`, so a config the wizard creates from scratch is recorded `MODIFIED` with `{}` as its original." | *(new behaviour)* Reversed. `configure_mcp_for_agent` now calls `snapshot_before "$component" "$config_file"` at line 149, **before** the `{}` seed at 150–152, with the comment "Snapshot BEFORE seeding the file." Test `G16` asserts the row is `CREATED`, and `G17` asserts rollback **deletes** the file. | "The snapshot is taken *before* the `{}` seed, so a config the wizard creates from scratch is recorded `CREATED` and rollback removes it." |
| `MANUAL.md` | 261 | "The `{}` is written *before* `backup_file`, so on a clean machine the manifest records `MODIFIED` with `{}` as the original." | *(new behaviour)* `snapshot_before claude "$CLAUDE_SETTINGS"` runs at line 773, before the `{}` seed at 774. | Same correction: recorded `CREATED`, deleted on rollback. |
| `SAFETY-AND-ROLLBACK.md` | 582–587 | "**A config the wizard had to create from scratch is recorded as `MODIFIED`, not `CREATED`.** `configure_mcp_for_agent` and the Glyphdown hook step write `{}` into a missing file *before* calling `backup_file`, so the stored original is `{}` and rollback restores an empty `{}` file instead of deleting it." | *(new behaviour)* No longer true for either code path (script lines 149 and 773). Tests `G16`/`G17` are the regression guards. This bullet sits under "What is *not* reversible", so it understates what rollback now does. | Delete the bullet, or move it to a "fixed" note; `~/.kimi-code/mcp.json`, `~/.qwen/settings.json` and `~/.claude/settings.json` are now removed cleanly. |
| `SAFETY-AND-ROLLBACK.md` | 98 | `\| `uv tool install specify-cli` \| Only `npm_install_if_missing` records an undo `ACTION`; the `uv` branch does not \|` | *(new behaviour)* The `uv` branch now records one: `record_action speckit "uv tool uninstall specify-cli"` (script line 639). Test `A28` asserts it. A user who runs `--run-actions` believing SpecKit is out of scope will now have `specify-cli` uninstalled. | Remove the row from "What is *not* recorded" and add a `speckit` component to the components table. |
| `SAFETY-AND-ROLLBACK.md` | 580–581 | "**`uv tool install specify-cli` records no `ACTION`.** Only `npm_install_if_missing` writes undo rows. Uninstall SpecKit by hand if you want it gone." | *(new behaviour)* As above — `record_action speckit …` at script line 639. | "`uv tool install specify-cli` records an `ACTION` under component `speckit`; `--run-actions` will uninstall it." |
| `FAQ.md` | 545–547 | "## Does the wizard index my project?" / "No. It sets up the launcher, `PATH`, completions, the embedding backend and the MCP configs, then prints the commands for you to run:" | With `WIZARD_INDEX_PROJECT` set, Step 7 (script lines 881–909) runs `codegraph sync`/`codegraph init` and `lumen index "$PROJECT_ROOT"`. The answer is only correct for the default, opt-out path. | "Not by default. Set `WIZARD_INDEX_PROJECT=1` and Step 7 builds/refreshes both the CodeGraph and Lumen indexes for the project root." |
| *(all 7 docs)* | — | `WIZARD_SKIP_GLYPHDOWN_HOOK` appears **zero** times across the entire doc set. | Script lines 765–769: setting it skips the glyphdown hook registration entirely and the final summary prints `➖ Glyphdown Hook  skipped on request (WIZARD_SKIP_GLYPHDOWN_HOOK)` (line 995). Test `A19` requires the opt-out to exist. The wizard's own comment calls it "documented". | Add to `MANUAL.md:431–437`, `USER_GUIDE.md:385–389`, and the `MANUAL.md:261` glyphdown row (which currently gives `glyphdown` on `PATH` as the *only* condition). |
| *(all 7 docs)* | — | `WIZARD_INDEX_PROJECT` and `Step 7` appear **zero** times across the entire doc set. | Script lines 881–909 add `Step 7: Indexing This Project`, opt-in via `WIZARD_INDEX_PROJECT`. Tests `A25`–`A27` cover it; `A10` now asserts step headers `"1,2,3,4,5,6,7,"`. | Add Step 7 to every step table and to the env-var references; note that CodeGraph uses `sync` when `.codegraph/codegraph.db` exists and `init` otherwise. |
| *(all 7 docs)* | — | `telemetry`, `WIZARD_KEEP_TELEMETRY`, `DO_NOT_TRACK`, `usageStatisticsEnabled` and `configure_telemetry_optout` each appear **zero** times across the entire doc set. | *(new behaviour)* `configure_telemetry_optout` (script lines 384–430) runs unconditionally as the first act of `ensure_lumen` (line 500). It appends a **third** managed block to `~/.bashrc` (`# >>> telemetry opt-out (managed by Claude Code) >>>`), exports `DO_NOT_TRACK=1` and `CODEGRAPH_TELEMETRY=0`, runs `codegraph telemetry off`, sets `.usageStatisticsEnabled = false` in `~/.qwen/settings.json`, and adds a "Telemetry / analytics:" section to the final summary (lines 975–991). Tests `A29`–`A32` and group `H` (H1–H7) cover it. | Document the block, the three knobs, the `WIZARD_KEEP_TELEMETRY` escape hatch, the extra `~/.qwen/settings.json` mutation, and the new summary section. |

### Major

| File | Line | Incorrect claim (quoted) | What the code actually does | Suggested correction |
| :--- | ---: | :--- | :--- | :--- |
| `README.md` | 68 | "## 🧭 The Six Steps" (table rows `**1**`–`**6**` follow) | Seven step headers exist: `Step 1` … `Step 7: Indexing This Project` (script lines 563, 581, 692, 698, 710, 842, 882). | "The Seven Steps"; add a Step 7 row marked opt-in via `WIZARD_INDEX_PROJECT`. |
| `README.md` | 23 | "Task‑oriented walkthrough: quick start, what each of the six steps prints" | Seven steps. | "…each of the seven steps…" |
| `README.md` | 273 | "…library‑mode guard, sequential `Step 1..6` headers, `shellcheck -S error`." | Test `A10` (test line 142) is now `assert_eq "A10 step headers are sequential 1..7" "1,2,3,4,5,6,7," "$steps"`. | "sequential `Step 1..7` headers" |
| `README.md` | 269 | "It runs assertions across **seven groups**:" | Eight groups, `A`–`H`. | "eight groups" |
| `README.md` | 271–279 | Group table rows `**A**` … `**G**` | No `**H**` row; group `H` (Telemetry opt-out, H1–H7) is missing. | Add an `H` row. |
| `README.md` | 279 | "**G** \| Backup manifest and rollback (15 assertions, `G1`–`G15`)" | `G1`–`G18`: `G16`, `G17`, `G18` were added at test lines 543, 548, 560. | "(18 assertions, `G1`–`G18`)" and mention the `CREATED`-not-`MODIFIED` regression tests. |
| `README.md` | 75 | "Prints ✅ / ⚠️ for `lumen`, `codegraph`, `glyphdown`, `specify`, `kimi`, `opencode`, `mimo`, `qwen-code`, `ashlr`." | Script line 699: `for cmd in lumen codegraph glyphdown specify kimi opencode mimo qwen ashlr; do` — the binary is `qwen`. | Replace `qwen-code` with `qwen`. |
| `README.md` | 118 | "\| **Qwen Code** \| `npm install -g @qwen-code/qwen-code`, only when `qwen-code` is missing \|" | Script line 653: `npm_install_if_missing qwen "@qwen-code/qwen-code"   # binary is \`qwen\`, not \`qwen-code\``. Test `A22` asserts the string `npm_install_if_missing qwen-code` never appears. | "only when `qwen` is missing" |
| `README.md` | 390 | "The step count went from 5 to 6; every later step shifted by one." | The count is now 7. | "went from 5 to 6, and later to 7 with the opt-in indexing step." |
| `MANUAL.md` | 54 | "Bun; `npm_install_if_missing` for `codegraph` and `glyphdown`; `specify` via `uv tool install specify-cli`; `npm_install_if_missing qwen-code`; …" | `npm_install_if_missing qwen "@qwen-code/qwen-code"`. The quoted string is the exact literal that test `A22` requires to be **absent** from the wizard. | `npm_install_if_missing qwen` |
| `MANUAL.md` | 141 | "`npm_install_if_missing qwen-code \"@qwen-code/qwen-code\"`." | Same — the real call site is `npm_install_if_missing qwen "@qwen-code/qwen-code"` (script line 653). | `npm_install_if_missing qwen "@qwen-code/qwen-code"` |
| `MANUAL.md` | 48–59 | "### Execution order" table, rows `1`–`6` plus the two `—` rows | Missing Step 7. | Add a Step 7 row (opt-in, `WIZARD_INDEX_PROJECT`). |
| `MANUAL.md` | 59 | "\| — \| `Setup Complete – Final Summary` \| Four `✅`/`❌` tables plus a numbered next-steps list \|" | *(new behaviour)* Five sections now: `Installed Global Commands`, `Agent MCP Configurations (Lumen)`, `Lumen Semantic Search`, `Telemetry / analytics` (script line 975) and `Project`. | "Five `✅`/`❌` tables" |
| `MANUAL.md` | 302 | "\| `qwen-code` \| `@qwen-code/qwen-code` \| `npm uninstall -g @qwen-code/qwen-code` \|" (Command column) | The command the package provides — and the name the wizard probes — is `qwen`. | Command column: `qwen`. |
| `MANUAL.md` | 118 | "Components in use: `lumen`, `shell`, `claude`, `kimi`, `opencode`, `qwen`, `npm`, and `misc` as the unused fallback." | *(new behaviour)* `speckit` is missing — `record_action speckit "uv tool uninstall specify-cli"` at script line 639. | Add `speckit` to the list. |
| `MANUAL.md` | 143–144 | "SpecKit does not go through it — `specify` is a Python tool installed with `uv tool install specify-cli`, and that branch records **no** undo action." | *(new behaviour)* That branch now records `record_action speckit "uv tool uninstall specify-cli"`. | "…and that branch records an `ACTION` under component `speckit`." |
| `MANUAL.md` | 304–305 | "`specify` comes from `uv tool install specify-cli` when `uv` is available — a Python tool, not an npm package, and the only install the wizard performs **without** recording an undo action." | *(new behaviour)* It now records one. `WOZCODE_INSTALL_CMD`, Bun and ashlr remain unrecorded. | Drop the "only install without an undo action" clause; name Bun/ashlr/WOZCODE as the unrecorded ones. |
| `MANUAL.md` | 340 | "Two blocks are written, each delimited by literal marker lines that must begin at column 1." | *(new behaviour)* Three: the lumen block and the telemetry opt-out block in `~/.bashrc`, plus the user-bin block in `~/.bash_profile` (`PRIVACY_BLOCK_START` at script line 372). Test `H1` asserts exactly one telemetry block. | "Three blocks are written" + a `### telemetry opt-out` subsection. |
| `MANUAL.md` | 431–437 | "### Read by the wizard" table: `WIZARD_STATE_DIR`, `WOZCODE_INSTALL_CMD`, `LUMEN_EMBED_MODEL`, `OLLAMA_HOST`, `SETUP_WIZARD_LIB_ONLY` | The wizard reads nine: those five plus `WIZARD_SKIP_GLYPHDOWN_HOOK` (line 765), `WIZARD_INDEX_PROJECT` (line 881), `WIZARD_KEEP_TELEMETRY` (line 385), and `LUMEN_BIN` (line 233, inside the generated wrapper — already covered separately at 443). | Add the three missing `WIZARD_*` rows. This table is the reference of record, so the omission propagates. |
| `MANUAL.md` | 616–624 | "## Test suite" group table, rows `A` … `G` | Missing group `H` (H1–H7, telemetry opt-out, throwaway `$HOME`). | Add an `H` row. |
| `MANUAL.md` | 618 | "…library-mode guard, sequential step headers `1..6`, `shellcheck -S error`" | Test `A10` asserts `1..7`. | "`1..7`" |
| `MANUAL.md` | 624 | "\| G \| Backup manifest and rollback, `G1`–`G15`, in a throwaway `$HOME` …" | `G1`–`G18`. | "`G1`–`G18`" |
| `ARCHITECTURE.md` | 7 | "…this document shows **how the pieces fit together**: the order of the six steps…" | Seven steps. | "the seven steps" |
| `ARCHITECTURE.md` | 24 | "The wizard runs six numbered steps top to bottom, non-interactively." | Seven; the seventh is conditional on `WIZARD_INDEX_PROJECT`. | "seven numbered steps, the last of which is opt-in" |
| `ARCHITECTURE.md` | 50 | `    NPM["npm i -g codegraph, glyphdown, speckit<br/>failures tolerated<br/>Lumen deliberately NOT from npm"] --> AGT` | SpecKit is not an npm package: script lines 633–646 install it with `uv tool install specify-cli`. The document's own README companion (`README.md:94`) states this correctly. | `"npm i -g codegraph, glyphdown<br/>specify via uv tool install specify-cli"` |
| `ARCHITECTURE.md` | 91 | `    V1["Step 4 - verify CLI availability<br/>lumen codegraph glyphdown specify<br/>kimi opencode mimo qwen-code ashlr"] --> M1` | Script line 699 loops over `qwen`, not `qwen-code`. | Replace `qwen-code` with `qwen`. |
| `ARCHITECTURE.md` | 307 | "**Takeaway:** the wizard's footprint is two managed shell blocks, two installed files, six JSON configs and three project paths." | Three managed blocks; the JSON configs the wizard actually writes are `~/.claude/settings.json`, `~/.kimi-code/mcp.json`, `~/.config/opencode/opencode.json` and `~/.qwen/settings.json` (four), plus `~/.claude.json` mutated by the `claude` CLI. | Recount against the real targets and the telemetry block. |
| `ARCHITECTURE.md` | 315–318 | "Groups **B–D** source the wizard in *library mode* (`SETUP_WIZARD_LIB_ONLY=1`) against a throwaway `$HOME` … Only group **F** looks at the real machine, and `--no-live` skips it." | Groups `B`, `C`, `D`, `G` and `H` all use `in_sandbox` (throwaway `$HOME` + library mode). `README.md:283` correctly says "Groups B, C, D and G" — the two documents contradict each other, and both now omit `H`. | "Groups B, C, D, G and H source the wizard in library mode…" |
| `ARCHITECTURE.md` | 320–327 | "## 5. ✅ Test suite coverage map" table, rows `**A**` … `**F**` | Groups `G` (backup manifest and rollback) and `H` (telemetry opt-out) are both missing from the table. | Add `G` and `H` rows. |
| `ARCHITECTURE.md` | 322 | "\| **A** Static analysis \| A1–A11 \| …" | Group A now runs `A1`–`A32` (36 recorded assertions, because `A12` fires once per bogus package). | "A1–A32" |
| `ARCHITECTURE.md` | 331 | `    A["A. static analysis<br/>A1 to A11"] --> AT["wizard source text"]` | Same. | "A1 to A32" |
| `USER_GUIDE.md` | 151 | "A roll call of `lumen codegraph glyphdown specify kimi opencode mimo qwen-code ashlr`." | Script line 699 lists `qwen`, not `qwen-code`. | Replace `qwen-code` with `qwen`. |
| `USER_GUIDE.md` | 220 | "The wizard closes with three `✅`/`❌` tables — global commands, agent MCP configs, Lumen setup, project state" | Four items are then listed for "three" tables, and the real count is now **five** sections (the `Telemetry / analytics:` block at script line 975 is the fifth). `MANUAL.md:59` says "Four" — the two documents contradict each other and neither matches the code. | "five `✅`/`❌` tables — global commands, agent MCP configs, Lumen setup, telemetry, project state" |
| `USER_GUIDE.md` | 383 | "These three are the only ones worth setting *before* the wizard runs." | Six wizard-input variables exist: the three listed plus `WIZARD_STATE_DIR`, `WIZARD_SKIP_GLYPHDOWN_HOOK`, `WIZARD_INDEX_PROJECT` and `WIZARD_KEEP_TELEMETRY` — all read before or during the run. | Extend the table; `MANUAL.md:433` already documents `WIZARD_STATE_DIR` as a pre-run input, so the two documents disagree. |
| `USER_GUIDE.md` | 59–222 | "## What each step does, and what you will see" — sections `### Step 1` … `### Step 6 — Project-Level Setup`, then `### Final summary` | Step 7 is missing from the walkthrough. | Add a `### Step 7 — Indexing This Project` section noting it only runs with `WIZARD_INDEX_PROJECT` and that the default prints `ℹ️ Skipping project indexing (set WIZARD_INDEX_PROJECT=1 to build indexes).` |
| `USER_GUIDE.md` | 24 | "\| `npm` \| Installs CodeGraph, Glyphdown, SpecKit, agent CLIs \| **Hard stop.** …" | SpecKit is installed with `uv`, not npm — as this same document says at line 213 ("SpecKit is a Python tool; there is no `@specify/cli` npm package") and line 112. Internal contradiction. | "Installs CodeGraph, Glyphdown and the Qwen Code CLI" |
| `FAQ.md` | 225 | "What re-running does **not** do: it never re-indexes anything, and never deletes an index." | With `WIZARD_INDEX_PROJECT` set, Step 7 runs `codegraph sync`/`codegraph init` and `lumen index` (script lines 885–906). | "…never re-indexes anything **unless you set `WIZARD_INDEX_PROJECT`**, and never deletes an index." |
| `FAQ.md` | 442 | "The components are `lumen`, `shell`, `claude`, `kimi`, `opencode`, `qwen` and `npm`; `all` is accepted…" | *(new behaviour)* `speckit` is missing. | Add `speckit`. |
| `SAFETY-AND-ROLLBACK.md` | 169–178 | "### Components" table, rows `lumen`, `shell`, `claude`, `kimi`, `opencode`, `qwen`, `npm`, `misc` | *(new behaviour)* No `speckit` row, although `record_action speckit "uv tool uninstall specify-cli"` writes one (script line 639). Since this table defines what `--component` accepts, the omission is user-visible. | Add: `\| speckit \| Step 2 \| ACTION uv tool uninstall specify-cli \|` |
| `SAFETY-AND-ROLLBACK.md` | 172 | "\| `shell` \| `configure_lumen_shell` (Step 3) \| `~/.bashrc`, `~/.bash_profile` \|" | *(new behaviour)* `configure_telemetry_optout` also writes `shell` rows: `backup_file "$bashrc" shell` at script line 391. So `~/.bashrc` is snapshotted by two different functions in Step 3. | "`configure_lumen_shell` and `configure_telemetry_optout` (Step 3)" |
| `SAFETY-AND-ROLLBACK.md` | 89–101 | "### What is *not* recorded" table | *(new behaviour)* Omits `.codegraph/` (and `~/.codegraph/telemetry.json`), which Step 7 and `codegraph telemetry off` create outside the manifest. `codegraph init` writes `.codegraph/codegraph.db` into `PROJECT_ROOT` (script line 816–821). | Add a row for the CodeGraph index and telemetry state. |

### Minor

| File | Line | Incorrect claim (quoted) | What the code actually does | Suggested correction |
| :--- | ---: | :--- | :--- | :--- |
| `ARCHITECTURE.md` | 249 | "Every pre-existing file is copied to `<file>.bak.<YYYYMMDDHHMMSS>` before modification" | `~/.local/share/bash-completion/completions/lumen` is registered with `snapshot_before` only (script line 303) and gets no `.bak` sibling — as `SAFETY-AND-ROLLBACK.md:85-87` and `TROUBLESHOOTING.md:708-709` both state. Internal contradiction. | Add the completions-file exception. |
| `ARCHITECTURE.md` | 247–309 | "## 4. 📂 Files touched" | The rollback state directory `~/.local/share/setup-agents-wizard/backups/<utc>/` is created on every run (script lines 64–67) but appears in no subgraph. | Add it to the `IG` subgraph or a new "State" subgraph. |
| `MANUAL.md` | 172 | "`mkdir -p ~/.local/bin`; `backup_file \"$LUMEN_WRAPPER\"`; writes the wrapper from a quoted heredoc; `chmod 755`." | The real call passes the component: `backup_file "$LUMEN_WRAPPER" lumen` (script line 212). Without it the default would be `misc`, which the same document says is unused. | `backup_file "$LUMEN_WRAPPER" lumen` |
| `MANUAL.md` | 517–529 | The `lumen [command]` "Available Commands" block, under "Confirmed against `lumen 0.0.41`" | Verified live: the real `lumen --help` also lists `help  Help about any command`. Everything else in the block matches exactly. | Add the `help` row, or mark the listing as abridged. |
| `MANUAL.md` | 500–508 | The `in_sandbox() { … }` code block | Not byte-exact: the real helper (test lines 59–72) also contains `set -uo pipefail`, a four-line comment, and `set +e` before `$1`. | Reproduce verbatim or say "abridged". |
| `README.md` | 243 | "- `/reload-plugins`" (under "**Claude Code**: Restart the IDE extension. Inside Claude, type:") | The wizard's printed next-steps list names only `/cost-mode` and `/fixclaude` (script line 947). `/reload-plugins` is not printed by the wizard and is not verifiable from any script in this repository. | Either drop it or mark it as an extra suggestion, not something the wizard tells you to run. |
| `TROUBLESHOOTING.md` | 550 | "Unit groups **A**–**E** run against a throwaway `$HOME` and throwaway git repositories." | Group `A` reads the wizard source only — no sandbox (`ARCHITECTURE.md:322` gets this right: "reads the wizard source only"). Groups `G` and `H` also run in a throwaway `$HOME` and are not mentioned. | "Group A reads the source only; groups B, C, D, G and H use a throwaway `$HOME`; group E uses throwaway git repositories." |
| `README.md` | 11 | "…and, where the agent's schema takes a server map, **CodeGraph** too" | Opencode's `.mcp` *is* a server map, but the wizard adds only `lumen` there (script lines 806–809); `MANUAL.md:266` says so explicitly. | "…and, for Kimi and Qwen Code, CodeGraph too." |
| `README.md` | 407 | "- Never overwrites your existing project files outside of `submodules/`." | Still true for *overwrites*, but Step 7 now creates `.codegraph/` in the project root in addition to `.specify/` / `specs/`. Worth naming so the claim stays unambiguous. | "…outside of `submodules/`, `.specify/`/`specs/` and `.codegraph/`." |

---

## Verified correct

The following claims were checked against the code (or the live CLI) and are **accurate**.
This list exists so the audit demonstrates coverage rather than only complaints.

### The specific items flagged for verification

- **`WIZARD_STATE_DIR` is resolved at call time.** `MANUAL.md:113`, `MANUAL.md:197`,
  `MANUAL.md:433` and `SAFETY-AND-ROLLBACK.md:58-65` all correctly describe the re-resolution
  inside `backup_init` (script lines 60–62). `README.md:212` correctly says it overrides the
  location. The rollback tool reads the same variable (`rollback-agents-wizard.sh:31`).
- **`SETUP_WIZARD_LIB_ONLY` library mode.** `MANUAL.md:472-486` quotes the guard verbatim and
  correctly notes that `SCRIPT_DIR`/`PROJECT_ROOT` are computed *before* it (script lines
  545–553). `MANUAL.md:86-89` and `MANUAL.md:137-138` correctly state that
  `npm_install_if_missing` is defined *below* the guard and is unavailable in library mode.
- **Every rollback flag exists and behaves as documented.** `--list`, `--session`,
  `--component`/`-c` (repeatable, `all` accepted), `--dry-run`/`-n`, `--yes`/`-y`,
  `--run-actions`, `--help`/`-h` — all present at `rollback-agents-wizard.sh:38-49`. The
  option table at `SAFETY-AND-ROLLBACK.md:195-203` and the synopsis at `MANUAL.md:30-31` are
  correct, including "Any other argument prints `❌ Unknown option: …` and exits **2**".
- **Rollback exit codes.** `SAFETY-AND-ROLLBACK.md:209-216`, `MANUAL.md:76-80` and
  `README.md:226` all match the script: `0` for success/`--list`/`--help`/`--dry-run`/nothing
  to do/declining the prompt; `1` for failures, missing backup root or missing manifest; `2`
  for a bad option; a failed `ACTION` warns without changing the exit code.
- **npm package names.** `@colbymchenry/codegraph` (script line 629) and `glyphdown`
  (line 630) are documented correctly everywhere, as is `@qwen-code/qwen-code` as the
  *package*. `specify` via `uv tool install specify-cli` (line 637) is documented correctly in
  `README.md:94`, `USER_GUIDE.md:84`, `MANUAL.md:326` and `FAQ.md:361`.
- **The `qwen` binary name is correct in the wizard itself** — `README.md:338`,
  `FAQ.md:360`, `SAFETY-AND-ROLLBACK.md:539` and `MANUAL.md:302` all give the right *uninstall*
  command (`npm uninstall -g … @qwen-code/qwen-code`). Only the *binary/probe* name is wrong,
  in the five places listed above.
- **Agent MCP config paths.** `README.md:126-132`, `USER_GUIDE.md:178-184`,
  `MANUAL.md:260-268`, `FAQ.md:406-411`, `TROUBLESHOOTING.md:129-144` and
  `SAFETY-AND-ROLLBACK.md:171-178` all give the verified real targets: `claude mcp add-json
  lumen … -s user`; `~/.kimi-code/mcp.json` (`.mcpServers`); `~/.config/opencode/opencode.json`
  (`.mcp`, `{"type":"local","command":[…],"enabled":true}`); `~/.qwen/settings.json`
  (`.mcpServers`); MiMo Code manual, no file. Each of the five documents also correctly labels
  the old orphan paths as leftovers from a previous revision.
- **`stdio` vs `serve`.** Every occurrence of `"args": ["serve"]` in the docs is either
  `codegraph`'s legitimate one (`README.md:145`, `MANUAL.md:157`, `FAQ.md:486`,
  `ARCHITECTURE.md:304`) or is explicitly presented as the past bug (`README.md:387`,
  `TROUBLESHOOTING.md:126`, `FAQ.md:511`). `TROUBLESHOOTING.md:166` — "`codegraph` legitimately
  uses `serve`. Only the `lumen` entry changes." — is exactly right.
- **No stale `@qoomon/lumen` presented as current.** All five occurrences
  (`README.md:273/378/386/395`, `MANUAL.md:324`, `FAQ.md:98/116`, `ARCHITECTURE.md:322`) frame
  it as a removed 404, matching test `A2`.
- **The deleted README script listing.** `README.md:368-378` correctly points at
  `scripts/setup-agents-wizard.sh` as the single source of truth and explains the removal; no
  document reproduces or links to an embedded listing.

### Structural and mechanical checks

- **Cross-links: 86/86 resolve.** Every relative markdown link between the seven documents
  points at a file that exists, and every `#anchor` matches a real heading under GitHub's
  slug rules — including the emoji-prefixed leading-hyphen anchors
  (`#-safety-and-reversibility`, `#-what-changed-and-why`,
  `#-mcp-configuration-for-every-agent`, `#-script-source`) and the underscore-bearing
  `#library-mode-setup_wizard_lib_only`, `#why-does-the-wizard-not-set-lumen_embed_model`.
- **Mermaid: 6/6 blocks parse and render.** `mmdc` 11.12.0 produced a valid SVG for every
  fenced block in `ARCHITECTURE.md` (127 KB, 42 KB, 30 KB, 35 KB, 27 KB, 30 KB respectively);
  no error SVGs, no parse failures. The `flowchart TD`, `sequenceDiagram`, `flowchart LR` and
  `stateDiagram-v2` blocks are all syntactically sound, `classDef`/`class` statements included.
- **Test-count claims.** `README.md:279`'s "(15 assertions, `G1`–`G15`)" was the only numeric
  test-count claim in the entire doc set at the time it was written; it is now stale (see
  Major findings). No document states an overall assertion total, so no overall total is wrong
  — but none is right either. The true inventory is below.

### Test-suite inventory (measured, `sha256 5c33717…`)

Counted by expanding every loop in `scripts/test-setup-agents-wizard.sh` (each call to
`assert_eq` / `assert_contains` / `assert_absent` / `record` / `skip` increments `TID`).

| Group | Test IDs | Distinct IDs | Records emitted |
| :--- | :--- | ---: | ---: |
| A — Static analysis of the wizard | `A1`–`A32` | 32 | 36 (`A12` fires 5×, once per bogus package) |
| B — Lumen launcher unit tests | `B1`–`B8` | 8 | 8 |
| C — Shell configuration unit tests | `C1`–`C10` | 10 | 10 |
| D — MCP configuration unit tests | `D1`–`D5` | 5 | 5 (or 5 skips without `jq`) |
| E — SuperSpec submodule safety | `E1`–`E3` | 3 | 3 |
| F — Live integration | `F1`–`F8` + `F5b` | 9 | 11 live (`F2` fires 3×, once per shell kind) / 7 with `--no-live` |
| H — Telemetry opt-out | `H1`–`H7` | 7 | 7 (`H6`,`H7` skip without `jq`) |
| G — Backup manifest and rollback | `G1`–`G18` | 18 | 18 (`G16`–`G18` skip without `jq`) |
| **Total** | **A–H, 8 groups** | **92** | **98** full live run / **94** with `--no-live` |

Note the file declares group `H` (line 392) *before* group `G` (line 446), so the console
output order is A, B, C, D, E, F, H, G.

### Observations about the code (not documentation defects)

These are not doc errors, but they affect what the docs *could* truthfully say:

1. **`--no-live` skips `F1`–`F7` but not `F8`.** Test line 293 is
   `for t in F1 F2 F3 F4 F5 F6 F7; do skip "$t live check" "--no-live"; done` — `F8` is simply
   never recorded in that mode. The docs' claim that "`--no-live` skips group F"
   (`README.md:281`, `ARCHITECTURE.md:407`) is true in effect, but the evidence file will
   silently be missing an `F8` row rather than showing it as skipped.
2. **`configure_telemetry_optout` calls `backup_file "$bashrc" shell` a second time**
   (script line 391, after `configure_lumen_shell`'s call at 322). `snapshot_before`
   de-duplicates the manifest row correctly, but a *second* `~/.bashrc.bak.<ts>` sibling is
   written on every run. Documents that describe `.bak` accumulation
   (`USER_GUIDE.md:423-426`, `SAFETY-AND-ROLLBACK.md:73-83`) will under-count by one per run.
3. **`~/.local/share/lumen` is confirmed as the index store** — `lumen purge --help` states
   "Deletes lumen index databases under ~/.local/share/lumen/", and the directory exists on
   this host. `ARCHITECTURE.md:281/304/364`, `MANUAL.md:270` and `FAQ.md:229-244` are correct.
4. **Every Lumen CLI flag documented in `MANUAL.md:534-606` was verified live against
   `lumen 0.0.41`**: `index` (`-b/--backend`, `-f/--force`, `-m/--model`), `search`
   (`-b`, `--cwd`, `-f`, `--max-lines`, `--min-score`, `-m`, `-n/--n-results`, `-p/--path`,
   `--summary`, `--trace`), `purge`, `stdio`, `completion` (bash/fish/powershell/zsh) and
   `hook` (`pre-tool-use`, `session-start`). All match exactly.
