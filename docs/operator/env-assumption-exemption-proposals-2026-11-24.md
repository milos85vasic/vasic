# Environment-assumption exemptions: record and proposals (2026-11-24)

Record of the exemption rows added to `.environment-assumptions-allow` under the operator's standing approval of 2026-11-24 (reasoned exemptions for classes verified line by line and approved by the independent reviewer; each a visible `# REASON:` row; NO baseline rows). Re-derive the live state with `bash scripts/audit-environment-assumptions.sh --no-submodules`.

Everything that could be fixed for real was fixed in code (PRs #78, #80, #81, #84); only occurrences below remain, grouped by class.
 
## 1. Kernel-assigned / registry-read ports on loopback

Proposed REASON: the port is KERNEL-ASSIGNED (bind to port 0, _free_port, or a port file written by a mock server after bind) or read from the service-registry state file; 127.0.0.1 is the loopback constant of a throwaway local server/probe. Verified line by line; see docs/operator/env-assumption-exemption-proposals-2026-11-24.md section 1.

Evidence: each server binds port 0 (`ThreadingHTTPServer(("127.0.0.1", 0), ...)`, `server.listen(0, "127.0.0.1")`, `_free_port()` via `bind(("127.0.0.1", 0))`, `prove-horizontal-overflow.sh:36`) or writes the bound port to a file after bind (`PYSRV`, mock servers' `.port` files); the registry-read probes take the port from `$sd/$svc.port`. Host 127.0.0.1 is the loopback constant of a throwaway local server. No port number is chosen by these lines.

| file:line | class | text |
|---|---|---|
| `_tests/prove-horizontal-overflow.sh:58` | ENDPOINT | `( cd "$HERE" && VD_BASE="http://127.0.0.1:$PORT" npx playwright test --config "$T/cfg.js" ` |
| `_tools/career/test_expertise_tile_geometry.py:66` | ENDPOINT | `cls.base = f"http://127.0.0.1:{cls.srv.server_address[1]}"` |
| `_tools/career/test_vault_browser.js:38` | ENDPOINT | `const base = 'http://127.0.0.1:${server.address().port}';` |
| `_tools/career/vault_browser_harness.js:40` | ENDPOINT | `return { base: 'http://127.0.0.1:${server.address().port}', hits, close: () => server.clos` |
| `scripts/verify-live-site.py:590` | ENDPOINT | `B = f"http://127.0.0.1:{port}"` |
| `scripts/verify-live-site.py:660` | ENDPOINT | `rep, rc = run_once(f"http://127.0.0.1:{port}", baseline=baseline, crawl=crawl, max_pages=m` |
| `scripts/verify-live-site.py:663` | ENDPOINT | `version_url_prefix=f"http://127.0.0.1:{port}/rel/v" if version else None)` |
| `scripts/verify-live-site.py:692` | ENDPOINT | `rep, rc = run_once(f"http://127.0.0.1:{_free_port()}")` |
| `scripts/zero-gap-class-live-vs-source.sh:476` | ENDPOINT | `probe_static "$tok" "$QA_REL" "$ROOT/$doc" "$doc" "http://127.0.0.1:$port/"` |
| `scripts/zero-gap-class-live-vs-source.sh:612` | ENDPOINT | `stack)   probe_stack "$a" "$a" "$b" fixture-repo "http://127.0.0.1:$port/$k" "$c" ;;` |
| `scripts/zero-gap-class-live-vs-source.sh:614` | ENDPOINT | `static)  if [ "${b%/_site}" != "$b" ]; then probe_static "$a" "$a" "$b" fixture-repo/_site` |
| `scripts/zero-gap-class-live-vs-source.sh:615` | ENDPOINT | `else probe_static "$a" "$a" "$b" fixture-repo "http://127.0.0.1:$port/$k/"; fi ;;` |

## 2. --port flag text used as test input

Proposed REASON: `--port=8080` is TEXT in a list of ordinary arguments fed to an argv policy as test INPUT (it must be allowed, not bound); no port is opened. See docs/operator/env-assumption-exemption-proposals-2026-11-24.md section 2.

Evidence: `fix3_test.go` `TestFix3_ArgvPolicyAllows` and `zero-gap-evidence.sh` E27b put `--port=8080` in a list of ordinary arguments that an argv policy must ALLOW (false-positive control). Nothing binds a port.

| file:line | class | text |
|---|---|---|
| `_tools/zero-gap-chain/fix3_test.go:66` | ENDPOINT | `{"x", "--prove-failure"}, {"x", "--port=8080"}, {"x", "--output-dir", "d"}, {"x", "--bypas` |
| `scripts/zero-gap-evidence.sh:900` | ENDPOINT | `for a in --prove-failure --port=8080 --output-dir --bypass compass "https://example.invali` |
| `scripts/zero-gap-evidence.sh:905` | ENDPOINT | `[ "$fp" -eq 0 ] && ok "E27b false-positive controls (--prove-failure --port=8080 --output-` |

## 3. Linux /proc reads that are fail-closed

Proposed REASON: Linux /proc read that is fail-closed by design: unreadable yields a refusing error, a skip that says NOT a pass, or the conservative minimum (1 job), never a guessed value. See docs/operator/env-assumption-exemption-proposals-2026-11-24.md section 3.

Evidence: `store.go heldFlockMode` returns an error that says `refused, never guessed` when fdinfo is unreadable; `test_vault_concurrency.py` calls `skipTest("... NOT a pass")` when `/proc/locks` is unreadable; `buildlib.available_mib` returns 0 when unreadable and `build_jobs` then caps at 1 job (`cap = ... if avail else 1`).

| file:line | class | text |
|---|---|---|
| `_tools/zero-gap-chain/store.go:440` | OSPATH | `b, err := os.ReadFile(fmt.Sprintf("/proc/self/fdinfo/%d", fd))` |
| `_tools/zero-gap-chain/store.go:442` | OSPATH | `return "", fmt.Errorf("cannot read the held lock mode of descriptor %d from /proc/self/fdi` |
| `_tools/career/test_vault_concurrency.py:13` | OSPATH | `process raises BlockingIOError, and (b) ''/proc/locks'' lists the peer's PID as a BLOCKED ` |
| `_tools/career/test_vault_concurrency.py:123` | OSPATH | `"""PIDs listed as BLOCKED waiters ('->') in /proc/locks, or None if unreadable."""` |
| `_tools/career/test_vault_concurrency.py:125` | OSPATH | `txt = Path("/proc/locks").read_text()` |
| `_tools/career/test_vault_concurrency.py:159` | OSPATH | `self.skipTest("/proc/locks unreadable: cannot obtain lock-contention evidence (NOT a pass)` |
| `_tools/career/buildlib.py:113` | OSPATH | `"""MemAvailable from /proc/meminfo, in MiB (0 when unreadable)."""` |
| `_tools/career/buildlib.py:115` | OSPATH | `for line in Path("/proc/meminfo").read_text().splitlines():` |

## 4. /proc literal that is detection data or a deliberately nonexistent fixture

Proposed REASON: the /proc path is DETECTION DATA (the guard's list of stdin file names) or a deliberately NONEXISTENT negative fixture, not an assumption about the host. See docs/operator/env-assumption-exemption-proposals-2026-11-24.md section 4.

Evidence: `guard-project-catalogue.sh` 2233/2647 are the guard's list of file names that mean stdin (detection data) and 2522 passes a deliberately nonexistent `/proc/nonexistent/override.log` to prove the override is ignored; `agent-scratch.sh:338` passes a deliberately nonexistent path to the df-check.

| file:line | class | text |
|---|---|---|
| `scripts/hooks/guard-project-catalogue.sh:2233` | OSPATH | `STDIN = ("-", "/dev/stdin", "/dev/fd/0", "/proc/self/fd/0")` |
| `scripts/hooks/guard-project-catalogue.sh:2522` | OSPATH | `printf '%s' "$j2" \| AGENT_TMPFS_OK_LOG=/proc/nonexistent/override.log python3 -I -c "$PY" ` |
| `scripts/hooks/guard-project-catalogue.sh:2647` | OSPATH | `stdin-fd0\|        STDIN = ("-", "/dev/stdin", "/dev/fd/0", "/proc/self/fd/0")\|        STDI` |
| `scripts/agent-scratch.sh:338` | OSPATH | `run /proc/agent-scratch-nonexistent df-check >/dev/null 2>&1; rc=$?` |

## 5. refs/heads/main per section 11.4.288

Proposed REASON: 11.4.288 - all work lands on main; the literal names the branch main by design (publish refspec, guard text, a sandbox repository the script itself creates, test data of forbidden commands, a fallback after @{upstream}, or a history note in a comment). See docs/operator/env-assumption-exemption-proposals-2026-11-24.md section 5.

Evidence: `deploy-langs.sh` publishes `<sha>:refs/heads/main` by design and refuses any other branch (section 11.4.288, guard P10); `verify-upstream-sync.sh`, `verify-submodule-remote-sync.sh` and `pointer-drift.sh` name main inside sandbox repositories they create (`git init -q -b main`); `guard-project-catalogue.sh` / `guard-gaps.sh` hold the TEXT of forbidden push commands as test data; `zero-gap-guard-checks.sh` / `third-party-guard.sh` try `@{upstream}` first and only then the `origin/main`, `github/main` candidates, failing with COULD-NOT-DETERMINE when none resolves; `helix-deps.yaml:541` is a history note inside a YAML comment.

| file:line | class | text |
|---|---|---|
| `_tools/deploy-langs.sh:99` | GITREF | `Publish guard: each site must be on branch main (symbolic-ref refs/heads/main)` |
| `_tools/deploy-langs.sh:101` | GITREF | `pushed as <sha>:refs/heads/main.` |
| `_tools/deploy-langs.sh:924` | GITREF | `if [ "$ref" != "refs/heads/main" ]; then` |
| `_tools/deploy-langs.sh:925` | GITREF | `DEPLOY_WHY="HEAD is '${ref:-detached}', not refs/heads/main — refusing to stage or push"; ` |
| `_tools/deploy-langs.sh:1135` | GITREF | `if deploy_site_publishable s10 origin; then ds_ok "P10a synced-main-ok" "main in sync with` |
| `_tools/deploy-langs.sh:1151` | GITREF | `if grep -q 'push "\$r" "\$NEW_SHA:refs/heads/main"' "$DS_SELF" && ! grep -qE 'push "\$r" m` |
| `_tools/deploy-langs.sh:1152` | GITREF | `ds_ok "P10f push-refspec" "push uses \$NEW_SHA:refs/heads/main; no bare 'main' push remain` |
| `_tools/deploy-langs.sh:1153` | GITREF | `else ds_bad "P10f push-refspec" "push line is not the explicit <sha>:refs/heads/main form"` |
| `_tools/deploy-langs.sh:1393` | GITREF | `PUSH_OUT="$(git -C "$s" push "$r" "$NEW_SHA:refs/heads/main" 2>&1)"; PUSH_RC=$?` |
| `scripts/verify-submodule-remote-sync.sh:739` | GITREF | `if [ "$nh_ok" -eq 1 ] && [ -n "$(git ls-remote "file://${sandbox}/up/nohead" refs/heads/ma` |
| `scripts/verify-submodule-remote-sync.sh:768` | GITREF | `git -C "${sandbox}/up/trunkrepo" update-ref refs/heads/main "${behind_sha}" >/dev/null 2>&` |
| `scripts/verify-upstream-sync.sh:43` | GITREF | `git -C "$W/root/sub" checkout -q main 2>/dev/null; git -C "$W/root/sub" fetch -q origin; g` |
| `scripts/verify-upstream-sync.sh:48` | GITREF | `git -C "$W/root/sub" fetch -q origin; git -C "$W/root/sub" merge -q --ff-only origin/main` |
| `scripts/zero-gap-class-pointer-drift.sh:243` | GITREF | `bgit -C "${SRC[$path]}" update-ref refs/heads/main "$sha" \|\| return 2` |
| `scripts/zero-gap-class-guard-gaps.sh:256` | GITREF | `for want_cmd in 'reboot' 'halt' 'git push origin :main' 'git push --delete origin main' 'r` |
| `scripts/hooks/guard-project-catalogue.sh:1575` | GITREF | `"remote-branch-delete-refspec": "deleting a remote branch is an operator decision: report ` |
| `scripts/hooks/guard-project-catalogue.sh:2421` | GITREF | `local benign=("git status" "git add specs/010-zero-gap-verified-closure/tasks.md" "git pus` |
| `scripts/hooks/guard-project-catalogue.sh:2440` | GITREF | `local forced=("git push -f" "git push -fu origin main" "git push -uf origin main" "git pus` |
| `scripts/hooks/guard-project-catalogue.sh:2441` | GITREF | `forced+=("git push origin +HEAD:main" "git push --force-if-includes" "git push --force" "g` |
| `scripts/hooks/guard-project-catalogue.sh:2442` | GITREF | `forced+=("git push --forc origin main" "git push --mirror" "git push -d origin x" "git pus` |
| `scripts/hooks/guard-project-catalogue.sh:2443` | GITREF | `forced+=("bash -c 'git push -f'" "sh -c \"git push origin +main\"" "nohup git push -f" "en` |
| `scripts/hooks/guard-project-catalogue.sh:2444` | GITREF | `forced+=("git -C /tmp/x push -f" "cd x && git push -f origin main" "git push origin '+main` |
| `scripts/hooks/guard-project-catalogue.sh:2452` | GITREF | `local pushok=("git push" "git push -u origin feature" "git push origin main --tags" "git p` |
| `scripts/hooks/guard-project-catalogue.sh:2453` | GITREF | `pushok+=("git push -v -n origin main" "git push origin HEAD:refs/heads/feature" "git fetch` |
| `scripts/hooks/guard-project-catalogue.sh:2454` | GITREF | `pushok+=('echo "git push -f"' "grep -n 'git push -f' notes.md" 'git commit -m "never git p` |
| `scripts/zero-gap-guard-checks.sh:84` | GITREF | `for c in "$up" origin/main github/main; do` |
| `scripts/zero-gap-guard-checks.sh:90` | GITREF | `[ -n "$BASE" ] \|\| { echo "COULD-NOT-DETERMINE no base ref (no @{upstream}, origin/main or ` |
| `scripts/zero-gap-third-party-guard.sh:119` | GITREF | `for c in "$up" origin/main github/main; do` |
| `scripts/zero-gap-third-party-guard.sh:125` | GITREF | `[ -n "$BASE" ] \|\| { echo "COULD-NOT-DETERMINE no base ref (no @{upstream}, origin/main or ` |
| `helix-deps.yaml:541` | GITREF | `ref: "94e666d416f0bde022d784555ec81ddd4389bb04"   # bumped 2026-10-15 (pushed to origin/ma` |

## 6. Planted-violation fixtures and fixture text

Proposed REASON: planted-violation FIXTURE or fixture text: the file exists to contain the violation so the gate that scans it can be proved to catch it (or the literal is an input line of a self-test or a mutation that deliberately re-freezes a value). See docs/operator/env-assumption-exemption-proposals-2026-11-24.md section 6.

Evidence: the two files under `_tests/fixtures/zero-gap/untracked-blind-window/planted/` are the planted violations the untracked-blind-window class is proved against; `normalise-evidence-paths.sh` line 88 is a self-test input line; `live-vs-source.sh:580` is a fixture container-exe path; `zero-gap-qa-readiness.sh` `mutant m2` is a mutation that deliberately re-freezes the port to prove the gate catches it.

| file:line | class | text |
|---|---|---|
| `_tests/fixtures/zero-gap/untracked-blind-window/planted/audit-piped-list.sh:7` | GNUBSD | `list_files "${1:-.}" \| xargs -r grep -l 'password' --` |
| `_tests/fixtures/zero-gap/untracked-blind-window/planted/xargs-in-assignment.sh:3` | GNUBSD | `sizes=$(git ls-files \| xargs stat -c '%s %n')` |
| `scripts/normalise-evidence-paths.sh:88` | OSPATH | `@U@/bob/Library/Android/sdk\|<home>/Library/Android/sdk` |
| `scripts/zero-gap-class-live-vs-source.sh:580` | OSPATH | `else path=/usr/local/bin/server; mounts=""; fi` |

## 6b. scripts/zero-gap-qa-readiness.sh (added after the line-number shift of #81)

| file:line | class | section | text |
|---|---|---|---|
| `scripts/zero-gap-qa-readiness.sh:150` | ENDPOINT | 1 | probe of a port read from the registry state file |
| `scripts/zero-gap-qa-readiness.sh:255,256` | ENDPOINT | 1 | `printf` of the port a mock server bound to |
| `scripts/zero-gap-qa-readiness.sh:213` | ENDPOINT | 6 | `mutant m2`: a mutation that re-freezes the port |

## 7. NOT exempted: left open for an operator decision

- `_tools/career/test_pdf_pipeline.py:397-399` (OSPATH): the test reads `/proc/self/fd` with no skip guard on hosts lacking it; it fails loudly rather than silently, but it is not guarded by design. Proposal: add a `skipUnless(os.path.isdir('/proc/self/fd'))` guard or a portable fd probe (real fix), not an exemption.
- `scripts/agent-admit.sh:81,133` (OSPATH): `BOOT_ID_FILE=/proc/sys/kernel/random/boot_id` is compared with `$(cat ... 2>/dev/null)` at lines 202/259; where the file is absent both sides are empty and compare equal, so the stale-slot check is not fail-closed. Proposal: treat an empty boot id as COULD-NOT-DETERMINE (real fix). Line 133 (`/proc/sys/kernel/threads-max`) is only reached for `ulimit -u` = unlimited and the following `case` already returns 2 on an empty value; it could be exempted once line 81 is fixed.
- `scripts/hooks/guard-project-catalogue.sh:2827` (OSPATH): `/proc/loadavg` in a diagnostic message of a self-test (`cut` of an absent file just prints nothing). Proposal: reword or guard (real fix); not in an approved exemption class.
- `specs/010-*/progress.yml`, `specs/010-*/baseline/sweep-2026-09-26/report.json`, `specs/017-*/progress.yml` (MODEL/GITREF/SERVICE/ENDPOINT, 12 lines): prose of progress records and a frozen sweep report that merely MENTION model ids, refs and ports. They are records, not code; exempting them was not in the approved classes. Proposal for the operator: approve a prose-record class exemption for `specs/**/progress.yml` and the baseline report, or reword the records.
- Also still reported on `main` until PR #84 merges, and FIXED there in code (not exempted): `scripts/qa-candidate-up.sh` lines 70, 71, 121, 257; `scripts/verify-live-site.py` lines 8 and 244; `scripts/zero-gap-sweep.sh:1032`; `_tools/zero-gap-chain/fix5_test.go:197`. After #84 the umbrella-root count is 26 minus these 8 = 18 (all listed in this section).

## 8. Follow-up (2026-11-24): what changed after section 7, and the one decision left

Fixed in code by #86 and #87 (RED reproduced first, paired proofs, no exemption rows):
`scripts/agent-admit.sh` (fail-closed boot id, both lines audit-clean), `_tools/career/test_pdf_pipeline.py`
(skip guard), `scripts/hooks/guard-project-catalogue.sh` (load diagnostic), `scripts/qa-candidate-up.sh`
(`OLLAMA_HOST` bare host defaults to Ollama's port). Umbrella-root `audit-environment-assumptions.sh
--no-submodules` went 18 -> 12 on `main` after both merged; the 12 left are the prose lines below.

### DECIDED (2026-11-25, option A): the 12 prose lines in specs/010-* and specs/017-*

Operator approved option A. Implemented as 12 path-anchored `# REASON:` rows in `scripts/audit-environment-assumptions.sh`
(one per recorded line; no directory wildcard; no baseline rows). Evidence re-verified from git history (11.4.124): every
exempt ledger line was added in one commit and never altered (`git log -S` per line); the report is a frozen copy touched by two
commits (f05817b, fd40432). Paired proofs E14-E16 in `--prove-failure`: the exact line at its path is allow-listed, the same
prose in an unrelated path is still reported, and a modified line inside the exempt file is not covered. Also fixed in the same
change: GNU-only `sed -i` in `scripts/verify-evidence-stability.sh` (two findings that had appeared since). `--no-submodules`
exits 0. The original decision text follows unchanged.

| File | Lines | Classes | Nature |
|---|---|---|---|
| `specs/010-*/baseline/sweep-2026-09-26/report.json` | 4 | MODEL, GITREF | frozen sweep output ("frozen copy", T036 baseline) |
| `specs/010-*/progress.yml` | 4 | GITREF, SERVICE, MODEL | append-only progress ledger |
| `specs/017-*/progress.yml` | 4 | MODEL, ENDPOINT | append-only progress ledger |

Git history was read first (section 11.4.124): the report is a frozen evidence copy committed in `f05817b` and
amended once; `docs/zero-gap/checks/VSC-386.probe.sh` addresses the 010 `progress.yml` lines by number (of its PRE_REF)
and the report's findings by file path. Rewording those files would alter frozen evidence and shift the probe's anchors, so
this change did NOT reword them. Findings that merely mention a model id, ref or port inside a historical
record are not frozen environment assumptions in code.

Options: (A) approve a "prose record" exemption class covering these three paths (a reviewed rule with a
`# REASON:` per path; recommended: it preserves the evidence untouched and the class cannot match code files
because the rule is path-anchored); (B) reword the two ledgers and regenerate the baseline report (loses the
historical wording, requires re-pointing VSC-386 and re-running T036; not recommended). No row has been added.

Not fixed here, noted: `OLLAMA_HOST=::1` (unbracketed IPv6 starting with a colon) is still mishandled in
`qa-candidate-up.sh` (it was broken before the change too).
