# `_tools/containers` — this umbrella's containerised workloads

This directory is the umbrella root's **consumer** of the canonical Containers
Submodule, `vasic-digital/containers` (Go module `digital.vasic.containers`),
which is pinned in this tree at `submodules/containers`.

It is the first and, at this writing, the **only** consumer of that submodule in
this repository. Measured 2026-09-03: before this directory existed,
`grep -rn 'digital.vasic.containers'` outside `submodules/` and `workshop/`
returned **zero** hits — the gitlink was declared, manifest-pinned and unused.

## What is here

| Path | What it is |
|---|---|
| `go.mod` | consumer module, `replace digital.vasic.containers => ../../submodules/containers` (§11.4.76(2)) |
| `cmd/site-build/` | the orchestrator. Drives podman/docker **only** through the submodule's `pkg/runtime`, `pkg/compose` and `pkg/logging` |
| `cmd/distribute-helixtranslate/` | builds the HelixTranslate image on a remote host and distributes it, through the submodule's `pkg/remote` and `pkg/remoteexec`. **Never run against a live remote — see its package comment before trusting it** |
| `cmd/runtime-probe/` | answers "which container runtime is on THIS machine?" via the submodule's `runtime.AutoDetect`, for shell callers that must not grow their own detection. Three-valued; **fully verified on this host** |
| `cmd/ocr/` | the OCR orchestrator. Runs tesseract over a directory of page PNGs, again through `pkg/runtime` + `pkg/compose`. This is what lets gate 5 reach a real verdict instead of UNDETERMINED |
| `internal/orchestrate/` | the lifecycle helpers `site-build` and `ocr` share — root resolution, wait-for-exit, log streaming. Extracted rather than copied, per §11.4.251 |
| `compose/compose.sites.yml` | the site-build service definitions the orchestrator consumes |
| `compose/compose.ocr.yml` | the tesseract service definition |
| `compose/jekyll-build.sh` | the Jekyll service's entrypoint, executed **inside** the container only |
| `compose/ocr-run.sh` | the tesseract service's entrypoint, executed **inside** the container only (POSIX `sh`: the image ships no bash and no find) |

`podman` and `docker` appear nowhere in `cmd/site-build`. That is the point of
§11.4.76(4): the submodule owns every process that talks to a runtime, and this
tree owns none of them.

## Running it

```bash
cd _tools/containers
go build -o bin/site-build ./cmd/site-build

./bin/site-build -probe                 # which runtime + compose are here
./bin/site-build -workload jekyll       # rebuild milosvasic.ru/_site
./bin/site-build -workload gen-test     # the generator's unit tests, pinned toolchain

go build -o bin/runtime-probe ./cmd/runtime-probe
./bin/runtime-probe                     # runtime=podman version=5.7.1
./bin/runtime-probe -name-only          # podman          (for `$(...)` in shell)

go build -o bin/ocr ./cmd/ocr
./bin/ocr -dir <dir-of-page-pngs>       # writes <page>.ocr.txt beside each PNG
```

`_tests/export/validate-pdf.js` builds and calls `bin/ocr` itself when no host
`tesseract` is on PATH, so gate 5 needs no manual step.

`runtime-probe` exists because `site-build -probe` cannot answer for a caller
that has no compose file: it returns **2** when compose is unavailable, which is
correct for a compose orchestrator and wrong for the question "is there a
runtime here at all". `runtime-probe` asks only `runtime.AutoDetect`.

**Verified on this host, all three exit codes against real conditions**
(2026-09-04, podman 5.7.1):

```
./bin/runtime-probe                       runtime=podman version=5.7.1        rc 0
./bin/runtime-probe extra                 unexpected argument "extra"         rc 1
env PATH=<empty dir> ./bin/runtime-probe  COULD NOT DETERMINE — no container
                                          runtime is available here: tried
                                          podman, docker, nerdctl, cri-o,
                                          lxd, kubernetes                     rc 2
```

The rc-2 leg is the paired §1.1 mutation and it is **DATA** — an empty `PATH` —
so it cannot be made inoperative by editing the code it guards. It is asserted
again in `cmd/runtime-probe/main_test.go`; `go test ./...` is green across the
module.

`_tools/gen/build.sh` builds and calls the `jekyll` workload itself;
`VASIC_JEKYLL_MODE` (`container` | `host` | `auto`, default `auto`) picks the
strategy there.

**Build the binary; do not `go run` it.** `go run` collapses every non-zero
program exit into 1 and prints `exit status N` instead. Measured 2026-09-03,
same code, same arguments:

```
go run ./cmd/site-build -root /tmp -probe   ->  rc 1   (wrong)
./bin/site-build        -root /tmp -probe   ->  rc 2   (COULD NOT DETERMINE)
```

Exit codes are three-valued, as every check in this tree is: **0** the workload
ran and its output was verified, **1** a real failure, **2** COULD NOT
DETERMINE — no runtime, no compose command, a compose file that cannot be read,
or an outcome that could not be read back. **A 2 is never a pass**, and a 2
arriving as a 1 is an unproven claim reported as a defect.

### The freshness assertion is proved, not asserted (§1.1)

The check that makes a green run mean something is *"the artifact was rewritten
by THIS run"*. It was exercised against a paired mutation — same service name,
same container name, a container that exits 0 and writes nothing:

```yaml
services:
  jekyll-build:
    image: docker.io/library/alpine:3.20
    container_name: vasic-jekyll-build
    command: ["true"]
```

```
site-build: FAIL — milosvasic.ru/_site/index.html was NOT rewritten:
mtime is still 2026-09-03T20:24:29+02:00. The container exited 0 while
leaving the previous artifact in place.                            rc 1
```

The mutation is DATA — a throwaway compose file — so the assertion cannot be
made inoperative by editing the code it guards.

## Why the Jekyll service exists — the measured defect

On the development host, `bundle exec jekyll` exits **127** and `bundle install`
**cannot** fix it:

```
mkmf.rb can't find header files for ruby at /usr/lib/include/ruby.h
An error occurred while installing json (2.9.1), and Bundler cannot continue.
```

`ruby-3.3.8-alt3` and `libruby-3.3.8-alt3` are installed; **`libruby-devel` is
not**, so no gem with a C extension can build. Installing it is a root-level
operator action (`sudo` here requires a password).

The consequence was quiet rather than loud. `_tools/gen/build.sh` called a bare
`jekyll`, `set -e` aborted the script at that line, `_site` was never rewritten —
and `_tests/playwright.config.js` serves exactly that directory. Gate 6 went on
reporting a green suite while validating a **six-day-old** artifact for
milosvasic.ru (`_site/index.html` was dated 2026-08-28 when this was measured on
2026-09-03).

The container carries its own headers and toolchain, so the build needs no host
privilege at all — on this machine, and on every future clone.

## Why there is no Containerfile here

Both services run a **stock upstream image** with a bind-mounted entrypoint.
Nothing about either workload needs a derived image, so none is built. If one
ever is needed, §11.4.76(4) says extend `vasic-digital/containers` — its
`pkg/crossbuild` already ships Containerfiles behind a `Backend` seam — rather
than growing a parallel image-build path in this tree.

## Known upstream defect in the consumed submodule

**REPORTED UPSTREAM 2026-09-03 as
[vasic-digital/containers#2](https://github.com/vasic-digital/containers/issues/2)**
(open). The issue carries the CLI reproduction below plus a Go program that
drives the defect through the module's own public API, and the one-line fix.
Re-measured before filing, against gitlink `d940b51fc247c285c805799452992da8d09c75b9`
on podman 5.7.1 / Go 1.26.2. Filing it is not fixing it — this section stays
until the submodule ships the change and the gitlink is bumped.

**THE CODE DEFECT IS FIXED AT THE PIN THIS TREE CONSUMES TODAY, so the sentence
immediately above has had its condition met and the section is kept as HISTORY,
not as an open finding.** Re-measured 2026-09-09 at gitlink
`7f5922563d8bec866b1a25eac483590c9a212817`: `pkg/runtime/podman.go:331-348`
now carries the `strconv.Itoa` guard the paragraph below says already existed
three times elsewhere in its own package, with the failing CLI line quoted in
its own comment. The fix arrived in `6d13ad03528c` (2026-09-04). **Whether the
GitHub issue itself is still open is UNCONFIRMED — the provider was not queried
this session.** Everything below this paragraph describes the state at
`d940b51`; it was true when written.

Measured while filing, and worth recording here: `podman.go` is the **only**
runtime in the package that forwards the `"all"` sentinel to a backend that
cannot parse it. `crio.go:304-308` and `lxd.go:328-332` guard it with
`strconv.Atoi`; `kubernetes.go:418-420` guards it with an explicit
`o.Tail != "all"`. The guard `podman.go` is missing already exists three times
in its own package.

`runtime.Logs()` returns **zero bytes and a nil error** against the podman
runtime when called with default options.

* `pkg/runtime/options.go:141` — `defaultLogOptions()` sets `Tail: "all"`.
* `pkg/runtime/podman.go:331-333` — that value is appended verbatim as
  `--tail all`.
* Podman parses `--tail` with `strconv.ParseInt`. Measured on this host:

  ```
  podman logs --tail all <c>   Error: invalid argument "all" for "--tail" flag … rc 125
  podman logs --tail -1  <c>   <the container's output>                          rc 0
  ```

The failure is **silent**: `ExecuteStream` starts the process successfully, so
`Logs()` returns a nil error; the pipe hits EOF immediately; the rc-125 reaches
the caller only through `Close() -> cmd.Wait()`. A caller that `defer`s `Close()`
and ignores its error sees *"logs read fine, container printed nothing"* — the
exact shape of a bluff. It was observed here first as two green runs with empty
log sections.

**The fix belongs upstream** (§11.4.76(4)): make the podman path translate
`"all"` to `"-1"`, or default to `"-1"`. Nothing in this tree works around it by
shelling out to a runtime. What `cmd/site-build` does instead is (a) use the
module's own public `runtime.WithTail("-1")`, and (b) report `Close()`'s error
instead of discarding it, so a broken log call can never again be mistaken for a
quiet container.

## Why the tesseract service exists — the second measured defect

`tesseract` is not installed on this host and is not going to be. The
operator's standing decision (#10 in
[`docs/OPERATOR-DECISIONS-2026-09-07.md`](../../docs/OPERATOR-DECISIONS-2026-09-07.md))
is that a missing toolchain is provided as a CONTAINER WORKLOAD through
`submodules/containers`, **never** as a host package — that decision
explicitly overruled a recommendation of host installs.

The cost of the absence was measured, not assumed. `_tests/export/validate-pdf.js`
SKIPped `FULL-VISUAL/visual.ocr`, and a SKIP cannot leave the verdict at PASS,
so gate 5 sat at:

```
5 PASS / 0 FAIL / 1 SKIP of 6      verdict=UNDETERMINED      rc 2
```

That is the gate working rather than failing — its golden-BAD arm still
detected correctly — but **rc 2 is never a pass**, so a whole check family was
uncovered. With the container engine wired in, the same command reports:

```
6 PASS / 0 FAIL / 0 SKIP of 6      verdict=PASS              rc 0
```

and the golden-BAD arm **still** exits 1 naming four CONTENT/TEXTUAL faults, so
nothing was weakened to reach the green.

**Two design points worth stating, because both were failure modes first.**

* **One container per PDF, not per page.** The image's own entrypoint is
  `exec tesseract "$@"` — one invocation per container. `compose/ocr-run.sh`
  replaces it with a loop over the mounted directory, so a 12-page document is
  one lifecycle to orchestrate and prove instead of twelve.
* **`user: "0:0"`, and it is not a privilege escalation.** The runtime here is
  ROOTLESS podman, where container uid 0 maps to the invoking host user. The
  image's default `tesseract` user maps to a subuid that does not own the bind
  mount, and tesseract then fails with, measured before the flag was added:
  `Error, could not create TXT output file: Permission denied`.

### The freshness assertion is proved, not asserted (§1.1)

OCR output lands **beside its input**, which makes a stale `<page>.ocr.txt` the
exact thing that could make a no-op container look like a successful OCR. The
assertion was exercised against a paired mutation — same service name, same
container name, a container that exits 0 and writes nothing — in both the
absent and the stale case:

```
# fresh directory
ocr: FAIL — "tesseract-ocr" exited 0 but produced NO fresh transcript for any
of the 2 page(s). (missing=2 empty=0 not-rewritten=0)                    rc 1

# directory already holding transcripts from an earlier run
ocr: FAIL — ... (missing=0 empty=0 not-rewritten=2)                      rc 1
```

The mutation is DATA — a throwaway compose file — so the assertion cannot be
made inoperative by editing the code it guards. Five further mutations were
exercised and each behaved as its contract states: empty `PATH` (no runtime)
rc 2, no PNGs rc 2, unreadable `-dir` rc 2, unexpected argument rc 1, and — on
the JavaScript side — an engine that returns rc 2 is reported as a
SKIP-with-reason rather than as a legibility FAIL, because blaming a document
for a missing runtime is a false accusation.

**Those mutations are now a SHIPPED, RE-RUNNABLE proof rather than this
paragraph.** Until 2026-09-08 they existed only as the prose above: exercised
by hand in the session that wrote `cmd/ocr`, and therefore not re-runnable by
the next reader, not registered, and unable to notice the day the assertion
stopped holding. Its sibling `cmd/runtime-probe` shipped `main_test.go`;
`cmd/ocr` shipped nothing. `prove-ocr.sh` closes that asymmetry:

```bash
bash _tools/containers/prove-ocr.sh
# === paired mutation proof: _tools/containers/cmd/ocr ===
#   PASS M0 CONTROL real compose OCRs a real page   rc=0
#   PASS M0b CONTROL wrote a non-empty transcript
#   PASS M1 no-op container, no transcript at all   rc=1
#   PASS M2 no-op container, STALE transcripts present rc=1
#   PASS M3 empty PATH (no runtime)                 rc=2
#   PASS M4 directory holds no PNGs                 rc=2
#   PASS M5 -dir does not exist                     rc=2
#   PASS M6 compose file unreadable                 rc=2
#   PASS M7 unexpected argument                     rc=1
# RESULT: 9 passed / 0 failed
```

Measured 2026-09-08 on podman 5.7.0. Every mutation is DATA — a throwaway
compose file, an empty `PATH`, an empty directory, an extra argv word — and not
one edits `cmd/ocr`. **M0 carries the same weight as the mutations**: without a
control, "every mutation was caught" is satisfied by a program that fails
unconditionally, which catches everything and detects nothing. M0b is separate
from M0 on purpose — asserting only on rc would let a green exit stand for a
transcript nobody read. The control's page is rasterised from the tracked
`_tests/export/fixtures/golden-good.pdf`, so the proof carries its own input
rather than depending on a leftover evidence directory.

**M2 is the load-bearing one.** OCR output lands beside its input, so a
leftover `<page>.ocr.txt` is indistinguishable from a fresh one to any check
that merely asks whether the file exists.

The script is registered in `scripts/check-registry.tsv` as an `exempt` row —
it IS a paired proof rather than a check owing one — and that registration was
itself proved load-bearing against a throwaway copy of the tree:

```
# control (registry unmutated)              61 PASS, 0 FAIL          rc 0
# mutation (the exempt row deleted)         60 PASS, 1 FAIL          rc 1
#   FAIL [R5] UNREGISTERED — _tools/containers/prove-ocr.sh is under a
#   declared scanroot but appears in no check, debt, or exempt row
```

Declaring `_tools/containers` a scanroot in the same change surfaced a second,
smaller drift: the registry's own honest-boundary comment listed **six**
un-swept `*.sh` under `_tools/` when there are **seven** —
`compose/ocr-run.sh` landed with this workload and was never added. That is
precisely the drift the comment exists to prevent, so it is corrected there
with the correction recorded rather than silently applied.

## Not containerised, and why

* **Playwright (gate 6)** — it works on the host today, so it fixes nothing
  broken; its `webServer` binds host TCP ports and serves two directories; and
  the image it would need is not on this host (`podman images` lists no
  playwright image), so it is a multi-GB pull for no measured gain.
* **The page generator itself** (`gen`, as opposed to its tests) — writes into
  two site submodules and syncs `design-system/` by host path. A candidate, not
  done, and named here rather than left implicit.
* **`workshop-curriculum_platform_1`** — already containerised and deliberately
  untouched.
* **`_tools/helixtranslate-container*`** — a pre-existing §11.4.76(4) finding,
  not a gap this directory created. `_tools/distribute-helixtranslate.sh` builds
  and replicates an image with raw `ssh` + `podman build` + `podman save |
  docker load`, and `_tools/helixtranslate-container.sh` runs it over `ssh`;
  `submodules/containers/cmd/deploy-stack` plus `pkg/remote` /
  `pkg/distribution` exist to do exactly that. It was **not** converted here
  because it targets remote hosts this session could neither reach nor test, and
  converting it unverified would be bluff work.

## The HelixTranslate surface, re-measured 2026-09-04

The line above stays true for the REMOTE half. The surface was then measured
file by file, and it splits three ways rather than two — the middle column is
the one an "it's all a violation" reading loses:

| File | §11.4.76 verdict | State |
|---|---|---|
| `_tools/helixtranslate-container/Containerfile` | **not a violation.** The anchor forbids reimplementing runtime/compose/lifecycle primitives; an image recipe is none of those, and the module itself ships `*.Containerfile` under `pkg/crossbuild` | left as is |
| `_tools/helixtranslate-container/Containerfile.translator` | same | left as is |
| `_tools/helixtranslate-local.sh` | **real violation.** Froze the literal `podman` for the LOCAL host — the module owns local runtime detection (`runtime.AutoDetect`) | **CONVERTED** to `cmd/runtime-probe`, verified on this host |
| `_tools/distribute-helixtranslate.sh` | **real violation.** Raw `ssh`/`scp`/`rsync` + `podman build` + `save｜load` — `pkg/remote`, `pkg/remoteexec`, `pkg/distribution` own all of it | replacement written, **UNVERIFIED** (hosts unreachable); original kept |
| `_tools/helixtranslate-container.sh` | **real violation** (raw `ssh`), **not closeable today** — it streams the document on remote STDIN, and `remote.RemoteRuntime.Run` still explicitly refuses `WithRunStdin`. Verdict re-confirmed 2026-09-09 at gitlink `7f592256`; the REASON is narrowed to the remote-stdin gap specifically | declared exception STANDS, reason narrowed |
| `_tools/helixtranslate-container/run.sh` | **"not closeable today" is WITHDRAWN — it was true when written, at gitlink `d940b51`.** It runs ON the remote host, so its one-shot `run --rm -i` is a LOCAL run there, and `runtime.Run` + `WithRunStdin` express it as of `6d13ad0` | exception reason WITHDRAWN in its header; **conversion NOT performed** — no image, hosts unreachable, rc 2 |
| `_tools/translate-fleet.sh` | **not a violation.** Its `host == amber.local ? docker : podman` is per-host CONFIGURATION: `pkg/remote.RemoteHost` carries a declared `Runtime string` field and the module ships no remote runtime detector | note added, code unchanged |

**THE PARAGRAPH THAT STOOD HERE IS WITHDRAWN BY NAME. It was TRUE at the pin it
named and is FALSE at the pin this tree consumes today.** It read: *"The single
upstream change that would close the two 'not closeable' rows is an ephemeral-run
primitive that accepts stdin in `pkg/runtime` … Measured at gitlink
`d940b51fc247c285c805799452992da8d09c75b9`: `ContainerRuntime` declares Name,
Version, IsAvailable, Start, Stop, Remove, Status, List, Stats, Exec and Logs —
**no Run, no Create** — `Exec` takes no stdin, and the only `WithStdin` in the
module (`pkg/remote/connection/interface.go:146`) sits in an
interfaces-and-options-only package that nothing implements and no constructor
returns."*

**That upstream change LANDED, and this tree consumed it without noticing.**
Re-measured **2026-09-09** at gitlink
`7f5922563d8bec866b1a25eac483590c9a212817`. The primitive arrived in
`6d13ad03528c` (2026-09-04), **two commits before the current pin** — so this
document asserted a closed gap for five days. `pkg/runtime/runtime.go` now
declares on the interface itself:

```go
Run(
    ctx context.Context, image string, cmd []string, opts ...RunOption,
) (*ExecResult, error)
```

`pkg/runtime/run.go` and `pkg/runtime/run_test.go` exist. `WithRunStdin(io.Reader)`
supplies the document and is what puts `-i` on the argv (`run.go:119`;
`args = append(args, "-i")` at `run.go:204`). `StdinExecutor` / `ExecuteWithStdin`
is implemented for real, by `defaultExecutor` on the `os/exec` path (`run.go:53`);
an executor lacking it makes `Run` fail with `ErrStdinUnsupported` **before the
command runs**.

**Two halves of the withdrawn paragraph SURVIVE, and they are why the two rows
split rather than both closing:**

* `Exec(ctx, id, cmd []string)` **still accepts no stdin** — the signature is
  unchanged at the current pin.
* **The REMOTE-stdin gap is still OPEN.** `remote.RemoteRuntime.Run`
  (`pkg/remote/runtime.go`, ~line 240) explicitly REFUSES `WithRunStdin`,
  because `RemoteExecutor` exposes `Execute` and `ExecuteStream` and neither
  accepts an `io.Reader`; it returns an error wrapping
  `runtime.ErrStdinUnsupported` rather than a zero-exit result produced with an
  empty stdin. `pkg/remote/connection` remains four files of interfaces and
  option builders, `WithStdin` at `interface.go:146` included, with nothing
  implementing its `Connection` interface.

**Consequence — a SPLIT, and both halves are stated because reporting only the
good half would be the bluff:**

* `_tools/helixtranslate-container/run.sh` runs ON the remote host, so from that
  host's own view its `run --rm -i` is a LOCAL run. It is **convertible in
  principle** today via `runtime.Run` + `WithRunStdin` / `WithRunVolumes` /
  `WithRunEntrypoint` / `WithRunExtraArgs`. **Its declared exception REASON no
  longer holds** and its header now says so.
* `_tools/helixtranslate-container.sh` is the local half — a raw
  `ssh … < "$IN"` — and is **still NOT convertible**. Its exception STANDS,
  narrowed by measurement to the remote-stdin gap named above.

**NEITHER SCRIPT WAS CONVERTED, deliberately.** Re-measured 2026-09-09 on this
host: `podman images | grep -i helixtranslate` matches **zero** rows; `getent
hosts` fails to resolve `thinker.local` and `amber.local`; `ssh -o
BatchMode=yes` returns **rc 255** for both. Absent image, unreachable hosts —
rc **2**, and **a 2 is never a pass**. A working script is not to be replaced by
a rewrite that cannot be exercised end to end. *Convertible in principle* is not
*verified in practice*, and this document will not spend one as the other.

**One upstream observation, recorded as an observation and NOT as a defect
(§11.4.6).** `defaultExecutor.ExecuteWithStdin` builds its child with
`exec.CommandContext` and folds an `*exec.ExitError` into `exitCode` while
setting `err = nil` (`run.go:53-73`). A CANCELLED run is killed by the context
and so returns as a signal death: **`ExitCode = -1` with a nil error**. A caller
must consult `ctx.Err()` to distinguish cancellation from a container that
exited −1. **Cancellation genuinely works.** Whether reporting it this way is
deliberate is **UNCONFIRMED** — nothing in the module states it and it was not
asked upstream.

**Unverified end to end, and labelled so here as well as in the file:** no
`helixtranslate:cli` image exists on this host (`podman images` matches it zero
times), so the converted `helixtranslate-local.sh` was exercised for runtime
resolution and exit codes only — never for an actual translation. Its rc-1
"translation failed" on this host is the image being absent, and is the same
result the pre-conversion script produced, so nothing was downgraded.
