# 🏗️ Setup Wizard Architecture

Visual reference for `scripts/setup-agents-wizard.sh` and its test-suite
`scripts/test-setup-agents-wizard.sh`.

Where the [README](./README.md) tells you **what to run**, this document shows **how the
pieces fit together**: the order of the seven steps, how `lumen` is actually resolved at call
time, why two shell init files are written instead of one, everything the wizard touches on
disk, what the test groups cover, and how the semantic index moves between states.

Every diagram below is derived from the current code. Four facts are worth stating up front
because they are easy to get wrong:

- **Lumen is not an npm package.** It ships as a Claude Code **plugin binary** at
  `~/.claude-shared/plugins/cache/<marketplace>/lumen/<version>/bin/lumen-<os>-<arch>`.
  The wizard installs a version-agnostic wrapper on `PATH` instead of a pinned symlink.
- **Lumen's MCP subcommand is `stdio`**, not `serve`. `serve` does not exist and fails with
  `Error: unknown command "serve" for "lumen"`.
- **Kimi, Opencode and MiMo Code are detected, never installed.** They are not on npm under
  those names, so the wizard prints the vendor URL instead. The only agent CLI it installs is
  Qwen Code, from `@qwen-code/qwen-code` — whose binary is `qwen`, not `qwen-code`.
- **Each agent gets a different MCP shape**, at a different path. There is no single
  config file the wizard writes for all five.

---

## 1. 🔁 End-to-end wizard flow

The wizard runs seven numbered steps top to bottom, non-interactively; the seventh is opt-in
and only runs with `WIZARD_INDEX_PROJECT` set. Only **Step 1** can abort
the run: missing `git`/`curl`/`node`/`npm`, or a `jq` install that cannot be completed, exits
with status 1. Everything after that is *best-effort* — a failed npm package, a missing Ollama
daemon or a failed model pull produces a warning and the wizard keeps going, which is why the
final summary is the authoritative report rather than the exit code.

```mermaid
flowchart TD
    START["run scripts/setup-agents-wizard.sh"] --> LIB{"SETUP_WIZARD_LIB_ONLY set?"}
    LIB -- yes --> RET["return 0<br/>library mode: definitions only,<br/>used by the test suite"]
    LIB -- no --> DET["detect SCRIPT_DIR<br/>PROJECT_ROOT is its parent"]
    DET --> BK["backup_init<br/>open the rollback session<br/>before anything is touched"]
    BK --> P1

    P1["Step 1 - prerequisites<br/>git, curl, node, npm"] --> P1Q{"all four present?"}
    P1Q -- no --> P1X["print_error<br/>exit 1"]
    P1Q -- yes --> JQ{"jq on PATH?"}
    JQ -- no --> JQI["ensure_jq<br/>apt-get, else yum, else brew<br/>else exit 1"]
    JQI --> JQ2{"jq present now?"}
    JQ2 -- no --> JQX["print_error<br/>exit 1"]
    JQ2 -- yes --> G1
    JQ -- yes --> G1

    G1["Step 2 - global CLI tools"] --> BUN{"bun on PATH?"}
    BUN -- no --> BUNI["curl bun.sh installer<br/>prepend HOME/.bun/bin"]
    BUN -- yes --> NPM
    BUNI --> NPM
    NPM["npm_install_if_missing codegraph @colbymchenry/codegraph<br/>npm_install_if_missing glyphdown glyphdown<br/>installs only what is MISSING,<br/>records an undo ACTION for each<br/>Lumen deliberately NOT from npm"] --> SPK
    SPK{"specify on PATH?"}
    SPK -- yes --> AGT
    SPK -- no --> UVQ{"uv available?"}
    UVQ -- yes --> SPKI["uv tool install specify-cli<br/>a Python tool, not an npm package<br/>record_action speckit uv tool uninstall specify-cli"]
    UVQ -- no --> SPKW["warn: install uv first"]
    SPKI --> AGT
    SPKW --> AGT
    AGT["npm_install_if_missing qwen @qwen-code/qwen-code<br/>package name is @qwen-code/qwen-code,<br/>the BINARY it provides is qwen"] --> ROLL
    ROLL["roll call, detection only:<br/>kimi, opencode, mimo<br/>print the vendor URL when missing<br/>never npm-installed - those names<br/>are 404s or unrelated packages"] --> ASH
    ASH{"bun available?"}
    ASH -- yes --> ASHI["install ashlr-plugin<br/>prepend HOME/.ashlr/bin"]
    ASH -- no --> ASHS["warn, skip ashlr"]
    ASHI --> WOZ
    ASHS --> WOZ
    WOZ{"wozcode present?"}
    WOZ -- yes --> L1
    WOZ -- no --> WOZE{"WOZCODE_INSTALL_CMD set?"}
    WOZE -- yes --> WOZI["eval the provided install command"]
    WOZE -- no --> WOZW["warn, skipped"]
    WOZI --> L1
    WOZW --> L1

    L1["Step 3 - ensure_lumen"] --> TEL{"WIZARD_KEEP_TELEMETRY set?"}
    TEL -- yes --> TELS["warn, telemetry settings left alone"]
    TEL -- no --> TELD["configure_telemetry_optout<br/>THIRD managed block in ~/.bashrc:<br/>DO_NOT_TRACK=1 and CODEGRAPH_TELEMETRY=0<br/>codegraph telemetry off<br/>qwen usageStatisticsEnabled to false<br/>Lumen ships no telemetry: nothing to do"]
    TELS --> LW
    TELD --> LW
    LW["install_lumen_wrapper<br/>write ~/.local/bin/lumen, chmod 755"]
    LW --> LC{"wrapper executable?"}
    LC -- yes --> LCG["lumen completion bash<br/>into ~/.local/share/bash-completion/completions"]
    LC -- no --> LCS["warn, skip completions"]
    LCG --> LS
    LCS --> LS
    LS["configure_lumen_shell<br/>rewrite managed blocks in<br/>~/.bashrc and ~/.bash_profile"] --> OL{"ollama on PATH?"}
    OL -- no --> OLI["install ollama<br/>ollama.com script on Linux, brew on macOS"]
    OLI --> OL2{"ollama present now?"}
    OL2 -- no --> OLW["warn: Lumen cannot index or search<br/>return 1, wizard continues"]
    OL2 -- yes --> SVC
    OL -- yes --> SVC
    SVC{"systemctl available<br/>and service inactive?"}
    SVC -- yes --> SVCE["sudo systemctl enable and start ollama"]
    SVC -- no --> MDL
    SVCE --> MDL
    MDL{"embedding model already pulled?"}
    MDL -- yes --> VER
    MDL -- no --> MDLP["ollama pull<br/>ordis/jina-embeddings-v2-base-code<br/>failure warns only"]
    MDLP --> VER
    OLW --> VER
    VER["verify_lumen<br/>wrapper responds to version,<br/>lumen resolves in a login shell,<br/>then a REAL embedding round-trip:<br/>api/tags reachable, then api/embed<br/>must return a vector - NaN means<br/>the runner is wedged, not merely busy"] --> V1

    V1["Step 4 - verify CLI availability<br/>lumen codegraph glyphdown specify<br/>kimi opencode mimo qwen ashlr"] --> M1
    M1["Step 5 - configure MCP servers"] --> MCQ{"claude CLI present?"}
    MCQ -- no --> MCW["warn, skip Claude Code"]
    MCQ -- yes --> MCR{"claude mcp get lumen already succeeds?"}
    MCR -- yes --> MCOK["already registered, nothing to do"]
    MCR -- no --> MCA["claude mcp add-json lumen ... -s user<br/>LUMEN ONLY, absolute wrapper path, args stdio<br/>the CLI owns ~/.claude.json<br/>record_action claude mcp remove lumen -s user"]
    MCW --> MPL
    MCOK --> MPL
    MCA --> MPL
    MPL["clone marketplaces:<br/>claude-cost-optimizer, jcodesmore-plugins"] --> HK1{"WIZARD_SKIP_GLYPHDOWN_HOOK set?"}
    HK1 -- yes --> HKS["warn, hook NOT registered<br/>glyphdown itself stays installed"]
    HK1 -- no --> HK2{"glyphdown on PATH?"}
    HK2 -- no --> HKW["warn, skip the hook<br/>a hook for a missing binary<br/>would fail on every tool call"]
    HK2 -- yes --> HKJ["snapshot_before, seed an empty object if absent,<br/>then jq into ~/.claude/settings.json:<br/>hooks.PreToolUse and hooks.PostToolUse<br/>each gain matcher * command glyphdown<br/>guarded so re-runs never duplicate"]
    HKS --> MK
    HKW --> MK
    HKJ --> MK
    MK{"~/.kimi-code directory exists?"}
    MK -- yes --> MKC["configure_mcp_for_agent<br/>~/.kimi-code/mcp.json<br/>.mcpServers += lumen and codegraph"]
    MK -- no --> MKW["warn, skip Kimi"]
    MKC --> MO
    MKW --> MO
    MO{"~/.config/opencode/opencode.json exists?"}
    MO -- yes --> MOC["jq: .mcp.lumen = local command array<br/>wrapper path plus stdio, enabled true<br/>the .mcp schema, NOT .mcpServers<br/>lumen only, no codegraph"]
    MO -- no --> MOW["warn, skip Opencode<br/>the wizard never creates this file"]
    MOC --> MM
    MOW --> MM
    MM["MiMo Code: no documented MCP config file<br/>NOTHING is written - the command and args<br/>are printed for you to enter by hand"] --> MQ
    MQ{"~/.qwen directory exists?"}
    MQ -- yes --> MQC["configure_mcp_for_agent<br/>~/.qwen/settings.json<br/>.mcpServers += lumen and codegraph"]
    MQ -- no --> MQW["warn, skip Qwen Code"]
    MQC --> PR1
    MQW --> PR1

    PR1["Step 6 - project setup<br/>cd PROJECT_ROOT, mkdir submodules"] --> SK{"specify CLI present?"}
    SK -- no --> SKW["warn, skip SpecKit init"]
    SK -- yes --> SKI{".specify or specs already there?"}
    SKI -- yes --> SKOK["already initialized"]
    SKI -- no --> SKR["specify init, force then -y fallback"]
    SKW --> SS
    SKOK --> SS
    SKR --> SS
    SS["setup_superspec"] --> SSQ{"submodules/superspec/.git exists?"}
    SSQ -- yes --> SSOK["leave it alone<br/>a FILE means submodule,<br/>a DIR means standalone clone"]
    SSQ -- no --> SSR{"git knows it as a<br/>registered submodule?"}
    SSR -- yes --> SSI["git submodule update, init and recursive"]
    SSR -- no --> SSC["remove stale non-git dir,<br/>then git clone superspec"]
    SSOK --> EXT
    SSI --> EXT
    SSC --> EXT
    EXT{"specify present and path exists?"}
    EXT -- yes --> EXTA["specify extension add<br/>./submodules/superspec as dev"]
    EXT -- no --> EXTW["warn, skip extension"]
    EXTA --> IDX
    EXTW --> IDX

    IDX{"WIZARD_INDEX_PROJECT set?"}
    IDX -- no --> IDXS["print: skipping project indexing<br/>the Step 7 header never appears"]
    IDX -- yes --> IX7["Step 7 - indexing this project"]
    IX7 --> CGQ{"codegraph on PATH?"}
    CGQ -- no --> CGW["warn, skip the CodeGraph index"]
    CGQ -- yes --> CGD{".codegraph/codegraph.db already there?"}
    CGD -- yes --> CGS["codegraph sync PROJECT_ROOT<br/>incremental"]
    CGD -- no --> CGI["codegraph init PROJECT_ROOT<br/>creates .codegraph in the project root"]
    CGW --> LXQ
    CGS --> LXQ
    CGI --> LXQ
    LXQ{"lumen on PATH?"}
    LXQ -- no --> LXW["warn, skip the Lumen index"]
    LXQ -- yes --> LXI["lumen index PROJECT_ROOT<br/>incremental, needs the embedding backend,<br/>can run for hours on a big repository"]
    LXW --> SUM
    LXI --> SUM
    IDXS --> SUM
    SUM["final summary - five sections<br/>commands, MCP configs, Lumen state,<br/>telemetry, project state"] --> DONE["exit 0"]

    classDef fatal fill:#fdecea,stroke:#c62828,color:#b71c1c
    classDef warn fill:#fff8e1,stroke:#f9a825,color:#7a5900
    class P1X,JQX fatal
    class OLW,WOZW,ASHS,SKW,EXTW,LCS,SPKW,MCW,HKS,HKW,MKW,MOW,MQW,CGW,LXW,TELS warn
```

**Takeaway:** the only hard gates are the four core prerequisites and `jq`; every later branch
degrades to a warning. Step 3 is where the interesting work happens — the telemetry opt-out,
the wrapper, the two shell files, the embedding backend and the verification pass are all one
function, `ensure_lumen`, whose failures are explicitly swallowed with `|| true` so a broken
Ollama never blocks the MCP wiring in Step 5. Step 5 is the branchiest: every agent is
configured at its own path in its own schema, and each one is skipped rather than guessed at
when the agent is not installed.

---

## 2. 🔎 Lumen resolution sequence

Typing `lumen search "..."` never touches the plugin's version-pinned path directly. `PATH`
finds the wrapper, and the wrapper resolves the newest installed plugin binary **at call time**.
That indirection is the whole point: the `<version>` directory is deleted on every plugin
update, so a symlink or a hardcoded `PATH` entry would break silently the next time the plugin
upgrades.

```mermaid
sequenceDiagram
    autonumber
    participant U as you, in a shell
    participant SH as bash PATH lookup
    participant W as ~/.local/bin/lumen wrapper
    participant FS as plugin cache on disk
    participant B as lumen plugin binary
    participant O as ollama on localhost:11434
    participant IX as index store ~/.local/share/lumen

    U->>SH: lumen search "how does auth work"
    SH->>SH: scan PATH, HOME/.local/bin is first
    SH->>W: exec the wrapper
    alt LUMEN_BIN is exported
        alt LUMEN_BIN is not executable
            W-->>U: error naming the path, exit 127
        else executable
            W->>B: exec LUMEN_BIN with the same args
        end
    else no override
        W->>W: uname -s and uname -m map to os and arch
        W->>FS: glob HOME/.claude-shared/plugins/cache/*/lumen/*/bin/lumen-os-arch
        FS-->>W: zero or more executable candidates
        opt fast path found nothing
            W->>FS: glob HOME/.claude*/plugins/cache/*/lumen/*/bin/lumen-os-arch
            FS-->>W: per-account cache candidates
        end
        W->>W: take version segment, sort -V, keep the last
        alt still nothing
            W-->>U: actionable error naming both globs, exit 127
        else resolved
            W->>B: exec the highest-version binary
        end
    end
    B->>O: embed the query with ordis/jina-embeddings-v2-base-code
    O-->>B: query vector
    B->>IX: nearest-neighbour lookup over the project index
    IX-->>B: ranked chunks with file and line spans
    B-->>U: ranked results
```

**Takeaway:** three things must line up for `lumen` to work — `~/.local/bin` on `PATH`, at least
one plugin binary under a cache glob, and an Ollama backend that actually *embeds* (reachable is
not the same as healthy: a wedged runner answers `/api/tags` with 200 while returning `NaN` from
`/api/embed` for every input, which is why `verify_lumen` does a real round-trip). The wrapper deliberately
exits **127** rather than 0 when it cannot resolve a binary, so no caller mistakes a missing
plugin for an empty result set. `sort -V` matters: a lexical sort would pick `0.0.9` over
`0.0.100`.

---

## 3. 🛤️ PATH wiring: why two files are needed

`configure_lumen_shell` writes **two** managed blocks — a lumen block in `~/.bashrc` and a user-bin
block in `~/.bash_profile`. (A third block, the telemetry opt-out, is written into `~/.bashrc` by
`configure_telemetry_optout` earlier in the same step; it is unrelated to `PATH` and is covered in
section 4 below and in the [README](./README.md#-telemetry-opt-out).)
They are not redundant. Bash reads different init files depending on
whether a shell is a *login* shell and whether it is *interactive*, and the third combination —
login but non-interactive — is exactly how agents spawn MCP servers, how `ssh host 'cmd'` runs,
and how cron and systemd user units execute.

```mermaid
flowchart TD
    subgraph SA["A. interactive, non-login<br/>a new terminal tab"]
        A1["bash starts"] --> A2["reads ~/.bashrc"]
        A2 --> A3["lumen block adds<br/>HOME/.local/bin to PATH"]
        A3 --> A4["lumen resolves ✅"]
    end

    subgraph SB["B. login + interactive<br/>ssh host, then a prompt"]
        B1["bash -l starts"] --> B2["/etc/profile<br/>sets a fresh PATH"]
        B2 --> B3["~/.bash_profile<br/>user-bin block adds HOME/.local/bin"]
        B3 --> B4["~/.bashrc is sourced too<br/>PATH guard sees it already there,<br/>no duplicate entry"]
        B4 --> B5["lumen resolves ✅"]
    end

    subgraph SC["C. login + NON-interactive<br/>ssh host cmd, cron, systemd user units,<br/>agents spawning MCP servers"]
        C1["bash -lc cmd"] --> C2["/etc/profile<br/>sets a fresh PATH"]
        C2 --> C3["~/.bash_profile<br/>user-bin block adds HOME/.local/bin"]
        C3 --> C4["~/.bashrc<br/>case $- in *i* ... else return<br/>RETURNS EARLY, never reached"]
        C4 --> C5["lumen resolves ✅<br/>ONLY because of ~/.bash_profile"]
    end

    C4 -.->|"without the ~/.bash_profile block"| X["lumen: command not found ❌<br/>every ~/.local/bin tool is invisible<br/>to cron, ssh commands and MCP spawns"]

    classDef ok fill:#dff5e1,stroke:#2e7d32,color:#1b5e20
    classDef bad fill:#fdecea,stroke:#c62828,color:#b71c1c
    class A4,B5,C5 ok
    class C4,X bad
```

**Takeaway:** path **C** is the one that breaks, and it breaks invisibly — an agent's MCP server
simply fails to launch. Both blocks use the same idempotent guard
(`case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH=... ;; esac`), written to the file
*unexpanded*, so path B picks up `~/.local/bin` exactly once and no user's home directory is baked
into anyone else's shell. This is also why the MCP configs record an **absolute** command path:
even with both blocks in place, an agent may spawn a server from a shell that read neither file.

---

## 4. 📂 Files touched

Every pre-existing file is copied to `<file>.bak.<YYYYMMDDHHMMSS>` before modification, and every
edit is either a `jq` merge or a marker-delimited block rewrite, so re-running is safe and
non-destructive. One exception: `~/.local/share/bash-completion/completions/lumen` is registered
with `snapshot_before` alone, so it lives in the rollback manifest but gets **no** `.bak` sibling.

```mermaid
flowchart TD
    W["setup-agents-wizard.sh"] --> SG
    W --> HG
    W --> IG
    W --> MG
    W --> DG
    W --> PG

    subgraph SG["🗄️ Rollback state - created on every run"]
        S1["~/.local/share/setup-agents-wizard/backups/UTC-stamp/<br/>manifest.tsv, files/ with byte-exact copies,<br/>latest symlink. Override with WIZARD_STATE_DIR"]
    end

    subgraph HG["🏠 Home shell config - block rewrite, 3 blocks in 2 files"]
        H1["~/.bashrc lumen block:<br/>PATH guard, completion fallback loader,<br/>commented-out tuning knobs"]
        H3["~/.bashrc telemetry opt-out block:<br/>DO_NOT_TRACK=1<br/>CODEGRAPH_TELEMETRY=0"]
        H2["~/.bash_profile user-bin block:<br/>login-shell PATH guard"]
    end

    subgraph IG["⚙️ Installed artifacts"]
        I1["~/.local/bin/lumen<br/>version-agnostic wrapper, mode 755"]
        I2["~/.local/share/bash-completion/completions/lumen<br/>lazy-loaded; snapshot only, no .bak sibling"]
    end

    subgraph MG["🔌 Agent config - one shape per agent"]
        M1["~/.claude.json<br/>NOT hand-edited: claude mcp add-json<br/>owns it. lumen only"]
        M2["~/.claude/settings.json<br/>glyphdown PreToolUse + PostToolUse hooks"]
        M3["~/.kimi-code/mcp.json<br/>.mcpServers: lumen + codegraph"]
        M4["~/.config/opencode/opencode.json<br/>.mcp schema, command as an array<br/>lumen only, no codegraph"]
        M6["~/.qwen/settings.json<br/>.mcpServers: lumen + codegraph,<br/>plus usageStatisticsEnabled false"]
        M5["MiMo Code - NOTHING is written<br/>no documented config file exists,<br/>the values are printed instead"]
    end

    subgraph DG["🧠 Data - written by the tools, not the wizard"]
        D1["~/.local/share/lumen<br/>embedding index store, one dir per project<br/>written by lumen index"]
        D2["~/.codegraph/telemetry.json<br/>written by codegraph telemetry off"]
    end

    subgraph PG["📁 Project root"]
        P1["submodules/"]
        P2["submodules/superspec<br/>submodule init or clone"]
        P3[".specify or specs<br/>SpecKit init"]
        P4[".codegraph<br/>Step 7 only, WIZARD_INDEX_PROJECT"]
    end

    M1 -.->|"command: absolute wrapper path<br/>args: stdio"| I1
    M3 -.-> I1
    M4 -.-> I1
    M6 -.-> I1
    H1 -.->|"puts it on PATH"| I1
    H2 -.->|"puts it on PATH"| I1
    I1 -.->|"reads and writes"| D1

    classDef managed fill:#e8eefc,stroke:#3f51b5,color:#1a237e
    classDef none fill:#f5f5f5,stroke:#9e9e9e,color:#424242
    classDef state fill:#dff5e1,stroke:#2e7d32,color:#1b5e20
    class H1,H2,H3,I1,I2,M1,M2,M3,M4,M6 managed
    class M5 none
    class S1 state
```

The agents do **not** all get the same block. Kimi and Qwen Code receive both servers in
`.mcpServers` — `lumen` pointed at the absolute wrapper path with args `["stdio"]`, plus
`codegraph` with args `["serve"]`. Claude Code and Opencode receive **`lumen` only**, each in its
own form: Claude Code through `claude mcp add-json … -s user`, Opencode as
`{"type":"local","command":[<wrapper>,"stdio"],"enabled":true}` under `.mcp`. MiMo Code receives
nothing at all. `~/.local/share/lumen`, `~/.codegraph/telemetry.json` and `<project>/.codegraph`
are the entries the wizard does not create itself — the tools write those.

**Takeaway:** the wizard's footprint is three managed shell blocks in two files, two installed
files, one rollback session directory, four JSON configs it edits directly
(`~/.claude/settings.json`, `~/.kimi-code/mcp.json`, `~/.config/opencode/opencode.json`,
`~/.qwen/settings.json`) plus `~/.claude.json` mutated on its behalf by the `claude` CLI, and
three project paths — four with the opt-in `.codegraph`. Every JSON edit preserves keys that were
already there.

---

## 5. ✅ Test suite coverage map

`scripts/test-setup-agents-wizard.sh` runs **eight groups, `A`–`H`**. Groups **B**, **C**, **D**,
**G** and **H** source the wizard in *library mode* (`SETUP_WIZARD_LIB_ONLY=1`) against a
throwaway `$HOME` — with `WIZARD_STATE_DIR` pointed inside it for G and H — so no unit test can
touch your real dotfiles. Group **A** only reads the source text. Group **E** builds throwaway git
repositories. Only group **F** looks at the real machine, and `--no-live` skips it. Note that the
file declares group `H` before group `G`, so the console order is A, B, C, D, E, F, H, G.

| Group | Tests | Exercises | Environment |
| :--- | :--- | :--- | :--- |
| **A** Static analysis | A1–A34 | `bash -n`, absence of `@qoomon/lumen` and the other bogus names, `stdio` not `serve`, absolute command path, `-e` gitlink test, `qwen` not `qwen-code`, `PreToolUse` present and `"ToolCall"` absent, the three `WIZARD_*` switches, `codegraph sync` not `codegraph index`, the `speckit` undo action, `DO_NOT_TRACK`, the `/api/embed` health round-trip, library guard, sequential step headers `1..7`, shellcheck | reads the wizard source only |
| **B** Launcher unit | B1–B8 | `install_lumen_wrapper`: executable, valid bash, `sort -V` version pick, `~/.claude*` fallback, `LUMEN_BIN` override, exit 127 paths | throwaway `$HOME` |
| **C** Shell config unit | C1–C10 | `configure_lumen_shell`: one block per file, idempotence across re-runs, valid syntax, unexpanded `$PATH` guard, mode 600 preserved, user content preserved | throwaway `$HOME` |
| **D** MCP config unit | D1–D5 | `configure_mcp_for_agent`: `stdio` args, absolute command, valid JSON, existing keys kept, no server duplication | throwaway `$HOME`, needs `jq` |
| **E** Submodule regression | E1–E3 | `setup_superspec`: gitlink canary survives, submodule reported as such, stale non-git dir still replaced | throwaway git repos |
| **F** Live integration | F1–F8 | real `PATH` in three shell kinds, Ollama reachability, model presence, completion registration, index + search a fixture repo | the real machine |
| **H** Telemetry opt-out | H1–H7 | `configure_telemetry_optout`: exactly one opt-out block and still one after a re-run, generated `~/.bashrc` parses, sourcing it exports the two variables, `WIZARD_KEEP_TELEMETRY` writes nothing, Qwen `usageStatisticsEnabled` set to `false` without losing keys, and an already-`false` value read back correctly | throwaway `$HOME`; H6/H7 need `jq` |
| **G** Manifest and rollback | G1–G18 | `snapshot_before`/`record_action` and the rollback script: TSV header, `MODIFIED` vs `CREATED`, original content and mode preserved, first-snapshot-wins, byte-exact restore, deletion of a created file, `--dry-run`, `--component`, the pre-rollback snapshot, `ACTION` never run without `--run-actions`, `--list`. G16–G18 guard the snapshot-before-seed ordering | throwaway `$HOME`; G16–G18 need `jq` |

```mermaid
flowchart LR
    A["A. static analysis<br/>A1 to A34"] --> AT["wizard source text"]
    B["B. launcher unit<br/>B1 to B8"] --> BT["~/.local/bin/lumen wrapper"]
    C["C. shell config unit<br/>C1 to C10"] --> CT["~/.bashrc and ~/.bash_profile blocks"]
    D["D. MCP config unit<br/>D1 to D5"] --> DT["agent JSON configs"]
    E["E. submodule regression<br/>E1 to E3"] --> ET["setup_superspec and submodules/superspec"]
    F["F. live integration<br/>F1 to F8"] --> FT["PATH in 3 shell kinds,<br/>ollama backend, real index and search"]
    H["H. telemetry opt-out<br/>H1 to H7"] --> HT["~/.bashrc opt-out block,<br/>~/.qwen/settings.json flag"]
    G["G. manifest and rollback<br/>G1 to G18"] --> GT["manifest.tsv, rollback script,<br/>MODIFIED, CREATED and ACTION rows"]

    AT --> EV["evidence: .test-evidence/UTC-stamp/<br/>results.tsv, run.log, summary.json"]
    BT --> EV
    CT --> EV
    DT --> EV
    ET --> EV
    FT --> EV
    HT --> EV
    GT --> EV

    classDef sandbox fill:#e8eefc,stroke:#3f51b5,color:#1a237e
    classDef live fill:#fff8e1,stroke:#f9a825,color:#7a5900
    class BT,CT,DT,ET,HT,GT sandbox
    class FT live
```

**Takeaway:** the map has no blind spot between groups — A guards the *shape* of the source
(regressions that would reintroduce `serve`, the npm package, the `ToolCall` hook or the wrong
`qwen-code` probe name), B–D and H guard the *behaviour* of each generated artifact in isolation,
G guards that every one of those changes can be undone, E is a dedicated regression test for a
real data-loss bug (a registered submodule's `.git` is a **file**, so the old `[[ -d ]]` test was
always false and `rm -rf` deleted the submodule on every run), and F proves the whole chain end to
end by indexing a two-file fixture repo and asserting the semantic search returns
`verify_password` and *not* `billing.py`. Every assertion writes expected value, actual value and
a timestamp to `.test-evidence/<UTC stamp>/results.tsv`.

One wrinkle worth knowing when you read that file: `--no-live` records `F1`–`F7` as skips, but
`F8` is not recorded at all in that mode, so its absence is expected rather than a failure.

---

## 6. 🔄 Indexing state machine

The index is per-project and lives in `~/.local/share/lumen`. It is built by `lumen index <path>`
— by you, by an agent, or by the wizard's opt-in Step 7 when `WIZARD_INDEX_PROJECT` is set — and
it is incremental: a re-index re-embeds only what changed. (CodeGraph keeps a separate database in
`<project>/.codegraph`; Step 7 refreshes it with `codegraph sync`, never with the destructive
`codegraph index`.)

```mermaid
stateDiagram-v2
    [*] --> NoIndex
    NoIndex --> Indexing: lumen index PROJECT
    Indexing --> Fresh: walk, chunk, embed, persist
    Fresh --> Stale: files change, or the freshness TTL elapses
    Stale --> Reindexing: next lumen index run
    Reindexing --> Fresh: only changed files are re-embedded
    Indexing --> Indexing: search answered, flagged stale
    Stale --> Stale: search answered from the older index
    Fresh --> NoIndex: lumen purge PROJECT

    note right of Indexing
        Searches during a build still return results,
        with a staleness warning attached.
        Files created AFTER the tree walk starts are
        picked up only by the NEXT index run.
    end note

    note right of Reindexing
        Incremental. Cost scales with what changed,
        not with repository size. Raise the reindex
        timeout for very large repositories.
    end note
```

**Takeaway:** "indexing" is not a blocking state — searches keep working, they are just labelled
stale, so an agent asking a question mid-build gets an answer plus a warning rather than an error.
The important subtlety is the tree-walk boundary: a file written *after* the walk began is not in
this run's index at all, so a script that generates code and immediately searches for it must
re-index first. Changing the embedding model mid-flight is the other trap — the wizard leaves
`LUMEN_EMBED_MODEL` and friends **commented out** in `~/.bashrc` precisely because a CLI/MCP model
mismatch makes Lumen build a *second* index per project.

---

## 📎 Related

- [README.md](./README.md) — installation, what gets installed, troubleshooting, uninstall.
- `scripts/setup-agents-wizard.sh` — the wizard.
- `scripts/test-setup-agents-wizard.sh` — the test suite; `--no-live` skips group F.
