# CONST-050(B) challenge family: one proof convention (VSC-369)

| Field | Value |
|---|---|
| Register id | VSC-369 (sweep row G-unproven-checks-02, class `unproven-checks`) |
| Authorised by | operator decision #13, 2026-10-14 (`docs/operator-decisions-2026-10-14-session.md`): cascades 368, 371, 370, then 369 |
| Related | VSC-368 (the CONST-033 scanner the `no_suspend_calls` member wraps), VSC-370 (`host_no_auto_suspend_contract`, the sibling proof of `host_no_auto_suspend`), VSC-371 (the compile/functionality/unit trio) |
| Written | 2026-10-15, before any module commit of this cascade |
| Revised | 2026-10-15, independent-review follow-ups (see "Review follow-ups"): loopback binding measured, fresh `HOME`, harness self-test, `host_no_auto_suspend` argument case, 0 % threshold cases, a corrected decision |
| Scope | the eight family members in the six owned repositories the register row names and this cascade may bump: `submodules/LLMProvider` (and its second checkout `submodules/llm_provider`, same commits), `submodules/RAG`, `submodules/security`, `submodules/doc_processor`, `submodules/llm_orchestrator`, `submodules/vision_engine` |
| Out of scope | `submodules/llms_verifier` (named by the row; gitlink mid-flight in another work stream, not bumped here), and three family carriers the row does not name: `submodules/challenges`, `submodules/containers`, `submodules/qa` (see "Not covered") |

## The convention

One rule set for all eight members, enforced by the members themselves and by one shared harness file,
`challenges/scripts/lib/const050b_proof.sh`, byte-identical in every repository that carries the family.

1. **Arguments.** A member takes exactly one argument, `--prove-failure` (plus `-h`/`--help`). Anything else is
   `COULD NOT DETERMINE` and exit 2. Before this cascade every member silently ignored its arguments.
2. **Live exit contract, three-valued.** 0 = the subject was measured and every step passed; 1 = a real finding;
   2 = could not determine, never a pass. A finding outranks a could-not-determine. No path prints a pass for a
   target that was never measured (the old `PASSED (SKIP-OK)` / exit 0 branches are gone).
3. **Floors.** Every target-driven member counts the steps it judged; fewer than declared is a finding (exit 1,
   "executed-step floor"). Every member that sends a load requires one recorded status line per request sent;
   fewer is exit 2 ("executed-request floor"), because the load did not run. Knobs (`*_REQUESTS`, percentages,
   timeouts, the chaos port) are validated; a malformed knob is exit 2 (it used to surface as a FAIL).
4. **`--prove-failure`.** Runs a COPY of the member hermetically (`env -i`: only `PATH`, `LANG`/`LC_ALL`, and
   `HOME` and `TMPDIR` = throw-away directories, plus the case's own variables, so neither a real target configured
   in the caller's shell nor the caller's `~/.curlrc` — a proxy, a resolve rule — can reach a proof case) and
   requires, per case, the exit code AND a named defect in the output:

   | Arm | Target | Expect |
   |---|---|---|
   | clean | a healthy loopback stub target, a well-behaved fake binary, or a clean planted tree | 0 |
   | stub-target | a deliberately broken loopback stub (one defect per case, each aimed at one step) | 1, naming the step |
   | unreachable | a refused loopback port, an absent or non-executable binary, a missing scanner | 2 |
   | invocation | target unset, a malformed knob, an unknown argument | 2 |
   | planted copy | a step deleted in the COPY (floor) / the load truncated in the COPY (request floor) | 1 / 2 |

   A proof exits 0 only when every case held, 1 when any case did not, 2 when it could not judge one (a missing
   tool, a stub that did not start, `chmod 000` not denying a read when run as root).
5. **Fixtures only.** Stub targets bind `127.0.0.1` only, and that is MEASURED, not trusted: each stub reports the
   address it bound, and the harness also reads the kernel's listening-socket table (`/proc/net/tcp`, `tcp6`); a
   stub listening anywhere but `127.0.0.1` is killed and recorded as a FAIL, and an unreadable table is exit 2. No
   case touches a real service, the network beyond loopback, or a credential (CONST-042). The stub is a Python
   `ThreadingHTTPServer` embedded in the harness; it exits with the proof (parent watch, 600 s cap).

   **The harness proves itself first.** Every proof starts with the harness self-test (`pf_selftest`, also
   `bash lib/const050b_proof.sh --selftest`), each check against a planted defect: T1-T4 verdict precedence
   (a FAIL outranks an UNDET; UNDET is never 0; nothing judged is 2; no self-test is 2), T5-T7 needle and rc
   enforcement, T8 no caller variable and no caller `HOME` reach a case, T9-T11 a stub on `127.0.0.2` is refused
   by its own report and by the kernel table while a `127.0.0.1` stub is accepted, T12 a caller `~/.curlrc` proxy
   line does not reach a case. A failed self-test fails the proof before any case runs; a proof whose self-test
   did not run cannot exit 0.
6. **No cwd fallback.** Members resolve their own directory from `BASH_SOURCE`; `no_suspend_calls` takes the
   repository root as exactly `../..` of its own directory and never searches upwards.
7. **One body per member, everywhere.** The six target-driven members are the SAME file in all six repositories
   except two module-identity lines (`C50_MODULE=`, `C50_PREFIX=`; the prefix keeps each module's existing
   environment names, e.g. `DOCPROCESSOR_HEALTH_URL`). `no_suspend_calls`, `host_no_auto_suspend`, the
   contract challenge and the harness are byte-identical everywhere. **Exception, measured 2026-10-15 after the
   follow-ups:** the contract challenge is no longer byte-identical — the VSC-370 review follow-ups (RAG
   `875221d`, LLMProvider `ac70ced`) changed it in RAG and LLMProvider/llm_provider only (blob `337456c8`), while
   security, doc_processor, llm_orchestrator and vision_engine still carry blob `ddc16809`. That file belongs to
   VSC-370 and was not touched by this cascade. Re-derive:

   ```bash
   for n in chaos_failure_injection ddos_health_flood scaling_horizontal stress_sustained_load \
            ui_terminal_interaction ux_end_to_end_flow; do
     for m in LLMProvider RAG security doc_processor llm_orchestrator vision_engine; do
       grep -vE '^C50_(MODULE|PREFIX)=' submodules/$m/challenges/scripts/${n}_challenge.sh | sha256sum
     done | sort -u | wc -l                                   # 1 per member
   done
   ```

8. **The one sibling.** `host_no_auto_suspend` measures the HOST, which no loopback stub can stand in for. Its
   `--prove-failure` runs `host_no_auto_suspend_contract_challenge.sh` (VSC-370), which drives it through eight
   planted host conditions in a user+mount namespace and asserts each exit code. On a host that restricts
   unprivileged user namespaces the proof is exit 2; run it under `podman unshare`. Because the contract never
   exercises this member's own arguments, the proof first runs a copy of the member with `--no-such-flag` and
   requires exit 2 naming `unknown argument` (case A1); a failed A1 makes the proof exit 1 whatever the contract
   says.

## Members

Old proof state: no member had a proof arm or a sibling proof the sweep recognises (baseline 2026-09-26: 64 rows,
8 x 8). The cases each arm runs:

| Member | Steps | Clean (0) | Stub-target and planted-copy cases (1 unless noted) | Could-not-determine cases (2) |
|---|---|---|---|---|
| `chaos_failure_injection` | 6 | healthy stub | M1 breaks after malformed input [2/6]; M2 drops an 8 KiB header [3/6]; M3 fails under the mixed load [5/6]; M4 dies after the chaos [6/6]; G1 deleted step (floor); G2 truncated load (request floor, 2) | no target; refused health port; healthy target but refused chaos port; malformed knob; 0 % threshold (U6); unknown argument |
| `ddos_health_flood` | 5 | healthy stub | M1 status "down" [2/5]; M2 fails under the flood [4/5]; M3 dies after it [5/5]; G1; G2 (2) | no target; refused port; malformed knob; 0 % threshold (U5); unknown argument |
| `scaling_horizontal` | 6 | two healthy stub replicas | M1 a replica reports "down" [2/6]; M2 a replica fails under load [3/6]; M3 replicas serve different bodies [4/6]; M4 a replica dies after the load [6/6]; G1; G2 (2) | no list; one healthy plus one refused replica; the same replica listed twice; malformed knob; 0 % threshold (U6); unknown argument |
| `stress_sustained_load` | 6 | healthy stub (5000 % budget: loopback latency is sub-millisecond) | M1 fails its baseline [2/6]; M2 status "down" [3/6]; M3 fails under load [4/6]; M4 slows 0.3 s after the load [5/6]; M5 dies after it [6/6]; G1; G2 (2) | no target; refused port; malformed knob; 0 % threshold (U5); unknown argument |
| `ui_terminal_interaction` | 4 | well-behaved fake binary | M1 panicking `--help`; M2 panic then > 64 KiB of help (the SIGPIPE case); M3 empty help; M4 fatal `--version`; M5 panicking unknown flag; M6 hanging unknown flag; G1 | no binary; absent path; not executable; malformed timeout; unknown argument |
| `ux_end_to_end_flow` | 5 | well-behaved fake binary | M1-M4 as UI; M5 hanging unknown flag [4/5]; M6 help gone after the mistake [5/5]; G1 | as UI |
| `no_suspend_calls` | wrapper | clean planted repository tree | M1 planted `systemctl` call; M2 a finding outranks an unreadable file | scanner missing here but present in an enclosing directory; an unreadable file (summary must say UNDETERMINED, not FAIL); unknown argument |
| `host_no_auto_suspend` | 4 | sibling: contract C0 | contract cases 1-8 in a namespace (unmasked targets, no marker, a suspend event, a huge journal) | contract: no systemctl, systemd not booted, no journal; A1 (this member) an unknown argument |

### RED baseline (new arm spliced onto each HEAD body, 2026-10-15)

Failed cases split into a wrong exit code (`rc`) and a right exit code with the wrong or no named defect (`needle`);
`undet` is G1 on every target-driven member: the old bodies have no step floor to plant on.

| Member | LLMProvider (= llm_provider) | RAG | security, doc_processor, llm_orchestrator, vision_engine (identical) |
|---|---|---|---|
| chaos (12 cases) | 5 failed (4 rc: M2 G2 U3 U4), 1 undet | 7 (4 rc: M2 G2 U3 U4), 1 | 7 (6 rc: M2 G2 U1 U2 U3 U4), 1 |
| ddos (10) | 2 (2 rc: G2 U3), 1 | 4 (2 rc), 1 | 4 (4 rc: G2 U1 U2 U3), 1 |
| scaling (12) | 3 (3 rc: G2 U3 U4), 1 | 5 (3 rc), 1 | 5 (5 rc: G2 U1 U2 U3 U4), 1 |
| stress (12) | 5 (2 rc: G2 U3), 1 | 7 (2 rc), 1 | 7 (4 rc: G2 U1 U2 U3), 1 |
| ui (13) | 4 (1 rc: U4), 1 | 4 (1 rc), 1 | 10 (5 rc: C1 U1 U2 U3 U4), 1 |
| ux (13) | 4 (1 rc: U4), 1 | 4 (1 rc), 1 | 10 (5 rc: C1 U1 U2 U3 U4), 1 |
| no_suspend_calls (6) | 2 (1 rc: U1), 0 | 2 (1 rc: U1), 0 | 2 (1 rc: U1), 0 |
| host_no_auto_suspend (contract, 11 assertions) | 11/11 (body already evolved; only the ignored arguments) | 11/11 (same) | 6 pass, 5 fail, rc 1 |
| total failed | 25 of 78, 6 undet | 33 of 78, 6 undet | 45 of 78, 6 undet; contract rc 1 |

Defects behind those rows (each now fixed and covered by a case):

- chaos: the "8 KiB" header was `head -c 8192 /dev/urandom | tr -dc ...`, about 2 KiB, so a target dropping
  large headers passed (M2 rc 0 in every repository); a refused chaos port injected nothing and still passed
  every step (U3 rc 0 everywhere).
- every load member: a truncated or failed load was not detected (`total=0` was coerced to 1; G2 rc 0
  everywhere); a malformed knob reported a FAIL (rc 1) instead of could-not-determine.
- scaling: one replica listed twice passed as a two-replica set (U3 rc 0 everywhere).
- stress: a failed latency probe was counted as a sample, so a failing baseline was blamed on the wrong step.
- the four Helix-lineage repositories: `PASSED (SKIP-OK)` exit 0 with no target or an unreachable one
  (U1/U2 rc 0 in six members); UI/UX `assert_no_panic` returned grep's 1 on a clean body, so no binary could
  ever pass (C1 rc 1), and `printf | grep -q` under `pipefail` missed a panic followed by > 64 KiB of text.
- no_suspend_calls: the walk-up root search scanned an enclosing directory when this repository's scanner was
  missing (U1 rc 0 everywhere); a scanner rc 2 was printed as `FAIL`.
- host_no_auto_suspend (Helix lineage): a host without systemd was rc 1 instead of 2, a missing journal counted
  as a pass, the journal was buffered in one shell variable. Those copies now carry the evolved body and the
  contract challenge, as LLMProvider, RAG and containers already did.

### GREEN (each repository checkout, before its commit)

In all six repositories: chaos 12/12, ddos 10/10, scaling 12/12, stress 12/12, ui 13/13, ux 13/13,
no_suspend_calls 6/6, each rc 0; `host_no_auto_suspend --prove-failure` rc 0 (contract 11 pass) under
`podman unshare` and rc 2 on the bare host (namespaces restricted); contract `--prove-failure` 17/17 under
`podman unshare`; `no_suspend_calls` live rc 0; CONST-033 scanner rc 0; every target-driven member live with no
target configured rc 2; `shellcheck -S warning` clean. Five consecutive runs of the six target-driven proofs in
`submodules/security`: identical (SC-006).

### Review follow-ups (2026-10-15, after the independent review's GO)

One commit per repository on top of the VSC-370/371 follow-ups: RAG `7e18911`, LLMProvider and llm_provider
`131842d` (fast-forward), security `23a7d5d`, doc_processor `0905fed`, llm_orchestrator `17f59d7`, vision_engine
`7cdd8ec`; seven files, harness blob `e53b27cd`, `no_suspend_calls` `8b324792`, `host_no_auto_suspend` `c448667b`.

RED on the previous HEAD (security lineage, same blobs everywhere), each planted on a throw-away copy:

| Follow-up | Planted / observed on HEAD | HEAD proof |
|---|---|---|
| stub loopback binding unproven | stub bound on `0.0.0.0` (`ss` saw 15 such listeners during the run) | ddos rc 0, 10/10 |
| host argument handling unproven | `*) shift ;;` in `host_no_auto_suspend` | rc 0 under `podman unshare` |
| shellcheck not clean | `shellcheck -S warning no_suspend_calls_challenge.sh` | rc 1, SC2034 |
| caller `HOME` reached cases | caller `~/.curlrc` with a proxy on a refused port | ddos rc 1, 4/6 (C1 rc 2) |
| harness had no self-proof | `--selftest`; `pf_end` precedence swapped; needle check removed | rc 0 silent; chaos rc 0; chaos rc 0 |

GREEN in all seven checkouts: chaos 13/13, ddos 11/11, scaling 13/13, stress 13/13, ui 13/13, ux 13/13,
`no_suspend_calls` 6/6, each rc 0 with the self-test 13/13; `host_no_auto_suspend` rc 0 under `podman unshare`
(A1 + contract 11 pass), rc 2 on the bare host (A1 pass); contract `--prove-failure` rc 0 (17/17, 19/19 where
VSC-370 changed it); live members with no target rc 2. `shellcheck -S warning`: 0 findings on the ten family
files in each of the seven checkouts (70 file-checks).

Mutants against the new bodies (security copy): 17 of 18 killed — the stub on `0.0.0.0` (three variants), the
kernel-table check skipped, the wide-listener branch removed, `pf_end` precedence swapped (two members), needle
enforcement removed, `env -i` dropped, the caller `HOME` restored, `host_no_auto_suspend` ignoring arguments, the
1 % threshold floor relaxed to 0 % (four members), the self-test call removed, the "self-test ran" gate removed.
The survivor (`assert_no_panic` returning 1 instead of 0) is EQUIVALENT: no caller reads its return code (there
is no `set -e`), so no observable behaviour changes.

## Decisions and their reasons

- **`no_suspend_calls_challenge.sh` belongs to VSC-369.** It is one of the eight names in the register row and in
  the 2026-09-26 baseline (one row per module). VSC-368 proved the scanner it wraps, not the wrapper.
- **Converge rather than patch eight per-module variants.** The variants differed only in names and in which old
  defects had already been fixed; one body per member (rule 7) makes the next fix a single change.
- **The shared harness is a sourced file, not code copied into each member.** Eight copies of a stub server per
  repository would drift. A live run never reads it, so a missing harness costs only the proof (exit 2).
- **No per-module registry was created.** None of the six repositories carries a check registry; creating one is
  a new component per module and is left as a follow-up rather than done silently.
- **Baseline probes that fail are a finding (stress [2/6] exit 1).** The target answered the pre-check, so a
  failing baseline is a measured defect. (Corrected 2026-10-15 after review: this bullet used to say RAG's previous
  body called a failing baseline could-not-determine. It did not: its sampler ran `curl` without `-f`, so a 503
  answer still recorded a latency sample, the baseline "succeeded", and the old body exited 1 at `[3/6]` on the
  status check — the right code, blamed on the wrong step. Its exit-2 branch ran only when fewer than 5 samples
  completed at transport level. The decision stands; only its stated reason was wrong.)
- **A listed replica that is down is left out and named, not a finding** (unchanged semantics); fewer than two
  distinct answering replicas stays exit 2.
- **Thresholds stay environment knobs** (they were documented knobs before); they are now validated, and a
  value outside 1..100 % is exit 2 — the 0 % edge is a proof case in chaos (U6), ddos (U5), scaling (U6) and
  stress (U5). A permissive value (e.g. 1 %) is still accepted; see follow-ups.

## Not covered (follow-ups)

- `submodules/llms_verifier`: named by the row; its eight members are still the old Helix-lineage bodies. Its
  gitlink is mid-flight in another work stream; apply the same render there when that stream lands.
- `submodules/challenges`, `submodules/containers`, `submodules/qa` carry the family too (not in the baseline
  rows); `submodules/constitution/submodules/llmctl/submodules/containers` is a nested consumed copy.
- A per-module check registry naming the eight members, once a module adopts one.
- Whether a permissive threshold (e.g. `DDOS_MIN_PASS_PCT=1`) should be refused is an open design question, as is
  whether a listed replica that is down should be a finding. A floor was PROPOSED to the operator on 2026-10-15 and
  is NOT decided or implemented; until it is, 1 % is accepted and a down replica is left out and named.
