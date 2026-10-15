# Independent batched review — umbrella commits without a tracked GO (2026-10-15)

| Field | Value |
|---|---|
| Revision | 1 (2026-10-15) |
| Reviewer | independent reviewer session (Fable model); did not author any reviewed change |
| Scope | end state at HEAD (`0f8904a`, later `35336c6`) vs `github/main` (`c827c66`) for the paths named per theme; focus commits listed in the table |
| Method | read-only on tracked code; every mutation in a disposable `git worktree` on disk (removed afterwards); guard probes fed to the hook scripts on stdin as JSON, never executed; heavy runs under `bounded-run -m 6G -T 580` one at a time with memory PSI checked first |
| Content rule | ids, counts, verdicts, file:line, commands and exit codes only; no private text, no credential values |
| Scratch (untracked, this host) | `~/.cache/agent-scratch/rev-umb-batch/` — `probe_guard.py`, `probe2.py`, `probe3.py`, `probes.out`, `*-prove.log`, `audit-*.out` |

## Verdicts per theme

| # | Theme | Verdict |
|---|---|---|
| 1 | Host-safety guard chain (project PreToolUse guard end state) | **NO-GO** — F1 (HIGH), F2 (MEDIUM), F3, F5 (LOW) |
| 1b | Validator, wiring, admission and scratch helpers | GO (validator GO-with-findings, F11) |
| 2 | Pre-push guards Z0 / Z1 and admission wiring of the heavy gates | GO-with-findings — F6 |
| 3 | Allow-list changes (hardcoded-paths rows + paired waivers) | GO-with-findings — F7, F8, F10 |
| 4 | Credential handling (LLMProvider `ac70ced` + bumps) | GO-with-findings — F9 (LOW) |
| 5 | Untraced 63fae39 components (spec 010 tooling) | NOT REVIEWED (time budget) — no verdict claimed |

## Per-commit / per-path table

| sha / path | Theme | Verdict |
|---|---|---|
| `scripts/hooks/guard-project-catalogue.sh` end state (`aa78155`..`96045d0`, `3a2152b`) | 1 | NO-GO (F1, F2, F3, F5) |
| `a5d1b18`, `77dc5a2`, `690faae`, `7ab93e2`, `6650681`, `d39add9`, `f0500df`, `96045d0`, `3a2152b` (guard fix rounds) | 1 | superseded by the end-state verdict above; every round's own proof passes (22/22) |
| `28b75d1`, `d156b13` (docs/AGENT_GUARDRAILS.md section D) | 1 | GO-with-findings (F2/F5 missing from Known limits) |
| `f421b40` `scripts/verify-pretooluse-guard.sh` | 1b | GO-with-findings (F11) |
| `b44c9b0` `.claude/settings.json` second PreToolUse hook | 1b | GO (adds blocking only; measured) |
| `scripts/agent-admit.sh` (`aa78155`, `77dc5a2`) | 1b | GO |
| `scripts/agent-scratch.sh` (`aa78155`, `690faae`) | 1b | GO |
| `63fae39` Z0 `scripts/zero-gap-guard-checks.sh`, Z1 `scripts/zero-gap-third-party-guard.sh`, `scripts/pre-push-gates.sh` Z0/Z1 wiring | 2 | GO-with-findings (F6) |
| `aa78155` admission in `scripts/pre-push-gates.sh`, `scripts/verify-content-boundary.sh`, `scripts/zero-gap-verify.sh` | 2 | GO |
| `c04e86c` | 3 | GO-with-findings (F7, F8, F10) |
| `269b367` | 3 | GO |
| `21c5f71` | 3 | GO-with-findings (F8) |
| `0f8904a` (gate-0 fix, landed during this review) | 3 | GO |
| LLMProvider `ac70ced` `challenges/scripts/apikeys_live_discovery_challenge.sh` | 4 | GO-with-findings (F9) |
| `baf80cc`, `53d1664` (gitlink bumps) | 4 | GO (gitlink == `helix-deps.yaml` ref; CM-MANIFEST-PIN-SYNC 21/21) |
| `63fae39` first `guard-project-catalogue.sh`, `prove-umbrella-mutants.sh`, `zero-gap-determinism-modules.sh`, credentials-public-tree class | 5 | not reviewed |

## Findings

Severity vocabulary: HIGH blocks acceptance of the reviewed path; MEDIUM must be fixed or waived with a tracked item; LOW follow-up; INFO record only.

**F1 — HIGH — one-level shell parameter expansion / same-line variable indirection bypasses the literal-keyed catalogue classes through BOTH wired hooks.**
`scripts/hooks/guard-project-catalogue.sh:583` (`expand()`) already implements `$VAR`, `${VAR}`, `${VAR:-default}` and same-line assignments, but it is applied only through `resolve()` (`:627`, paths) and the pid path; the command word, the git subcommand and option words are classified from the raw token text (`git_flags()` `:890`, wrapper/command normalisation from `:687`). Result (29 of 29 probes ALLOWED by both hooks, rc 0/0): `o=--force; git push $o origin main`; `git push ${FLAG:---force} origin main`; `git push --${X:-force} origin main`; `f=force; git push --$f origin main`; `git push $(printf -- --force) origin main`; `git push -$(echo f) origin main`; `git push --forc${X}e origin main`; `git push --no-verif${X}y origin main`; `c=push; git $c --force origin main`; `g=git; $g push --force origin main`; `git ${X:-push} --force origin main`; `s=sudo; $s id`; `sudo${X} id`; `systemctl ${X:-suspend}`; `s=systemctl; $s suspend`; `systemctl susp${X}end`; `pkill ${X:--f} python`. The same shapes ARE refused where `expand()` is applied: `rm -rf ${X:-/}`, `d=/; rm -rf $d`, `kill -9 ${X:--1}`, `rm -rf /${X}` (all rc 2). The upstream guard's literal regexes miss them too. Not covered by the header's KNOWN LIMITS (which exempt only variables set in an EARLIER call or by `read`) nor by the round-7 F3 waiver (same-line `X='$D'` into systemd-run). Repro: `python3 -I ~/.cache/agent-scratch/rev-umb-batch/probe2.py` (FN 24) and `probe_guard.py` (F45, F46, F50, R28). Fix: run `expand()` over every argv word (command, subcommand, options) before classification; a word whose expansion is unknown (`None`) inside a refused command family (git push/commit/reset/clean/checkout/add/branch/update-ref, rm, sudo/doas/su/pkexec/run0, systemctl/loginctl/shutdown, kill/pkill/killall) is refused with a hint, mirroring the existing ambiguous-prefix rule; add the 29 probes as named cases in P15 / the fixtures.

**F2 — MEDIUM — the guard does not protect its own files or wiring.** 12 probes ALLOWED: `rm`, `sed -i`, `truncate -s0`, `chmod -x`, `: >`, `git rm` of `scripts/hooks/guard-project-catalogue.sh`, `docs/zero-gap/guarded-commands.tsv` and `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh`; `printf '{}' > .claude/settings.json`; `Write`/`Edit` tool payloads naming the same files (every non-Bash tool returns 0 at `main()` `:2212`). An emptied catalogue puts the hook in its rc-1 non-blocking state (`:2204`) for every later call of the session; an edited script takes effect on the next call. Fix: a structural rule refusing writes/removals/mode changes/redirections whose target resolves under `scripts/hooks/`, `submodules/constitution/scripts/hooks/`, `docs/zero-gap/guarded-commands.tsv`, `.claude/settings.json`, and refusing `Write`/`Edit`/`MultiEdit`/`NotebookEdit` payloads naming them; until then list it under KNOWN LIMITS.

**F3 — LOW — both hooks fail OPEN on an unparseable or unexpected payload.** Truncated JSON, empty stdin, `not json at all`, `command` given as an array, `tool_name` `bash` (lowercase): rc 0 from both (`main()` `:2209-2216`; upstream `json_field`). Not reachable by an agent today (the harness builds the JSON), but a harness schema change silently disables both guards with no signal. Fix: undecodable payload or non-string command -> rc 2 with a stderr line.

**F4 — LOW (upstream, report-only) — false-positive refusals.** `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh:813` `shutdown([[:space:]]|$)` refuses `man shutdown` and `shutdown -c` (cancels a scheduled power-off). The project catalogue allows `-c/--show`, but the chain blocks because the upstream fires (§11.4.201(1)). Report upstream; not patched here.

**F5 — LOW — xargs data from a here-string or pipe is not seen.** `xargs rm -rf <<< /` and `printf / | xargs rm -rf` ALLOWED (same class as the documented `pgrep -f x | xargs kill`); add to KNOWN LIMITS or feed literal stdin text as argv.

**F6 — LOW/MEDIUM — Z0's paired waiver pairs nothing semantically.** `scripts/zero-gap-guard-checks.sh:121-146` accepts a new waiver row when its kind is known, four columns are non-empty, and `paired_check` is ANY `check` row with non-weak proof columns and an existing entry point. Measured in a worktree: reason `x` paired to `content-boundary` waived a blanked proof column, two added allow rows (`.hardcoded-paths-allow`, `.content-boundary-allow`) and a deleted check script -> `HOLDS ... waived=4`. Z0 therefore guarantees VISIBILITY of a weakening in the diff, not its justification (its header `:17-26` says so). Recommend: for `add-allow` the `paired_check` MUST be the gate that owns the `*-allow` file; a minimum reason shape (item id + words); an independent-review pointer column.

**F7 — LOW — three dead allow rows.** `ev/VSC-353.green.json`, `ev/VSC-353.red.json`, `ev/VSC-354.green.json` no longer contain a host path (re-sealed in later rounds with git-derived probe paths); removing their rows produces no finding. `scripts/audit-hardcoded-paths.sh:736` reports stale BASELINE rows only, so REASON rows go stale silently. Remove the three rows (a removal is not a Z0 weakening).

**F8 — LOW — allow-row placement and two rows for files that exist in no pinned commit.** Six sealed-evidence rows (`ev/VSC-353.verifier-b17.json`, `ev/VSC-351.verifier.json`, `ev/VSC-352.verifier-b17.json`, `ev/VSC-359.verifier-b17.json`, `ev/VSC-349.red.json`, `ev/VSC-349.green.json`; `c04e86c`, `21c5f71`) sit under the `# BASELINE:` paragraph, so the audit counts them as baselined debt while their waiver rows describe REASON-class sealed evidence (allow kinds at HEAD by the audit's own parser: REASON 87, BASELINE 143; at `github/main`: 20 / 134). `submodules/constitution/scripts/label-sync/cmd/labelctl/fix_test.go` and `internal/state/perf_test.go` are absent at both constitution pins `a71b176` and `36eda36` (`git cat-file -e`); the audit prints them as stale on every run (rc stays 0). Fix: move the six rows under their own `# REASON:` paragraph; drop the two rows until the label-sync branch is pinned.

**F9 — LOW — credential file stderr is kept while sourcing.** `challenges/scripts/apikeys_live_discovery_challenge.sh:384` `source "$API_KEYS_FILE" >/dev/null`: a credential file that writes a key to stderr prints it; proof case S1 covers stdout only. Fix: discard stderr too (report the `source` rc instead) or pass it through a redaction of the resolved values.

**F10 — INFO — attribution.** `c04e86c`'s BASELINE comment says the two label-sync test files "surfaced with the submodule pin move"; measured, they came from an off-pin constitution working tree (`0f8904a` records this correctly).

**F11 — INFO — validator depth.** `scripts/verify-pretooluse-guard.sh` V9 runs three probes against the guard FILE, not the wired command string (operator-waived #12). After F1 lands, add one indirection probe (`o=--force; git push $o origin main`) to V9 so the validator cannot report green on the bypass class.

## Measurements (commands, exit codes)

| Command | Result |
|---|---|
| `bash scripts/verify-pretooluse-guard.sh` | rc 0 — PASS=10 FAIL=0 UNDET=0 (V1-V9 incl. V2b, V9) |
| `bash scripts/verify-pretooluse-guard.sh --prove-failure` (bounded-run) | rc 0 — 19 passed / 0 failed / 19 cases |
| `bash scripts/hooks/guard-project-catalogue.sh --prove-failure` (bounded-run) | rc 0 — 22 passed, 0 failed; L1 p95 69 ms |
| `bash submodules/constitution/scripts/hooks/test_guard_forbidden_commands.sh` | rc 0 — PASS=70 FAIL=0 |
| `python3 -I probe_guard.py` (283 payloads to both hooks: 210 expected-blocked, 46 expected-allowed, 22 documented-gap, 5 payload-shape) | 42.7 s; false negatives 7 (F45 F46 F50 R28 genuine; F75 and C20 mis-specified probes, re-tested as V23/V21 -> BLOCKED; R29 is a documented limit); false positives 2 (B19 `man shutdown`, B25 `shutdown -c`, upstream only); documented gaps still open 22/22 (12 self-protection, 4 interpreter wrappers, 2 git alias, 3 `rm -rf` below `$HOME`, `/sys/power/state`, `pgrep \| xargs kill`); payload-shape 5/5 rc 0 |
| `python3 -I probe2.py` (40 expansion/indirection probes) | 24 false negatives (F1 class); 16 BLOCKED incl. every `rm`/`kill` shape |
| `python3 -I probe3.py` (20: `# guardrails:allow` on six catalogue classes + wrapper spellings) | 1 false negative (`git push ${X:-"--force"}`, F1 class); the marker downgrades nothing in the chain (project guard rc 2 on all six; upstream warns only) |
| `bash scripts/agent-admit.sh --prove-failure` (bounded-run) | rc 0 — 36 passed, 0 failed (A1-A19, W1-W6, M1-M10) |
| `bash scripts/agent-scratch.sh --prove-failure` (bounded-run) | rc 0 — 25 passed, 0 failed |
| `bash scripts/zero-gap-guard-checks.sh --root .` (live, base `c827c66`) | rc 0 — HOLDS; waived=87, new waiver rows=87 (72 add-allow + 15 add-exempt); after `0f8904a`: 91 rows, all valid |
| `bash scripts/zero-gap-third-party-guard.sh --root .` (live) | rc 0 — HOLDS; protected=2; constitution bump NOTE (policy allow) |
| `bash scripts/zero-gap-guard-checks.sh --prove-failure` / `zero-gap-third-party-guard.sh --prove-failure` | rc 0 / rc 0 — 17/17 and 11/11 fixture cases, M1-M6 mutants caught each, U1-U3 rc 2 |
| Z0 worktree mutations (base = main HEAD) | blanked proof columns -> `FINDING WEAKENED check hardcoded-paths`; 2 unwaived allow rows -> 2 `FINDING ADDED allow-list entry`; deleted `scripts/verify-manifest-pins.sh` -> `FINDING DELETED check entry point`; waivers with reason `x` paired to `content-boundary` -> HOLDS (F6); waiver paired to itself / to no check / to a weakened check -> 3 `FINDING WAIVER INVALID` |
| Z1 worktree mutations | superspec gitlink bump -> `FINDING THIRD-PARTY GITLINK BUMP`; gitlink replaced by `evil.txt` with `.gitmodules` entry and tsv row dropped in the same commit -> 3 FINDINGS (STALE classification, EDIT D, EDIT A); constitution bump -> NOTE only |
| `bash scripts/audit-hardcoded-paths.sh` (live, bounded-run) | rc 0 — 82 allowed, 2 stale baseline rows named (F8) |
| audit in worktree with the 76 in-range allow rows removed (`--no-submodules`) | rc 1 — 61 `ev/` + 7 coverage/host-capability + 2 operator-decision files re-flagged; 3 rows not re-flagged (F7); 3 submodule rows not testable without submodules |
| audit with `ev/VSC-999.green.json` and `docs/zero-gap/coverage-evidence/root__new.txt` planted | rc 1 — both flagged (exact-path rows, no glob rows: 0 rows with `*?[`) |
| `docs/findings/zero_findings_ratchet.tsv` base vs HEAD | TOTAL 23 -> 23 (unchanged) |
| content of the 64 allowed `ev/*.json` | host path only in `.argv[]` (53) and `.cwd` (8); `docs/zero-gap/coverage-evidence/*.txt`: only inside the Playwright `Executable doesn't exist at` message |
| `0f8904a` INVENTORY | `<projects-root>` placeholder present (2), 0 host paths left |
| `bash scripts/verify-manifest-pins.sh` | rc 0 — 21 MATCH / 0 DRIFT / 0 UNDETERMINED |
| `GOPROXY=off GOFLAGS=-p=1 bash challenges/scripts/apikeys_live_discovery_challenge.sh --prove-failure` (LLMProvider `261cfde`, bounded-run) | rc 0 — 25 passed, 0 failed, 0 undetermined (S1, U11/U11b, N1 included) |
| `ac70ced` code read | endpoint literal `https://huggingface.co/api/models?limit=5` (`:457`); only `Authorization` set (`:462`); `PROBE_VALUE` never printed, `unset` at `:409`; `declare -p` output not printed (`:396`); probe binary in `mktemp -d` (0700); CR/LF refused before the probe is built (`:404`) |

## Not covered (stated, not hidden)

Theme 5 (first `guard-project-catalogue.sh`, `prove-umbrella-mutants.sh`, `zero-gap-determinism-modules.sh`, the credentials-public-tree class in `63fae39`) was not read. `scripts/zero-gap-verify.sh --prove-failure` was not run (its admission wiring is covered by agent-admit W2/W5). The upstream guard was probed as part of the chain and reported only (F4); it is not this repository's to patch. Nothing was pushed; the scratch worktree was removed (`git worktree remove`, `git worktree prune`).
