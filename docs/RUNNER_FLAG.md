# Forcing the container runner: `--runner=NAME` for every launcher

| | |
|---|---|
| Revision | 2026-11-24 |
| Scope | the umbrella repository `vasic` (its own launchers and the wrappers around the submodules) |
| Canonical contract | `submodules/containers/docs/RUNNER_FLAG.md` (Containers Submodule, `vasic-digital/containers` PR #3) |
| Proof | `bash scripts/verify-runner-flag.sh` and `bash scripts/verify-runner-flag.sh --prove-failure` |

On a host with several container runners the Containers Submodule's default
priority order picks one. Every launcher listed below accepts one uniform
override.

## Contract

| | |
|---|---|
| Flag | `--runner=NAME` or `--runner NAME` |
| Env | `CONTAINERS_RUNNER=NAME` |
| Precedence | **flag > env > default** (default = the module's priority order, or, for the remote-host scripts, the per-host `HT_FLEET` entry) |
| `NAME` | a runner the module supports, or `auto` (= default order). The list is **derived from the module** (`runner list`, `runtime.SupportedRunners()`; today podman, docker, nerdctl, cri-o, lxd, kubernetes). It is never hardcoded in a script |
| Unknown `NAME` | refused, **exit 2**, message lists the supported runners (also when it came from the env var) |
| Forced runner not installed | refused, **exit 2**. There is **never** a silent fallback to another runner |
| Explicit `auto` | beats an inherited `CONTAINERS_RUNNER` |

## Launchers

| Launcher | How the flag is honoured |
|---|---|
| `scripts/qa-up.sh` | `--runner=NAME`; the flag is stripped in pure bash and a runner is selected ONLY when containers will be used (mv rebuild, workshop / ai boot) -- validated before anything boots (refusal = rc 2). Static servers (`vd`/`mv` without rebuild) and `--stop` need no runner and work with no Go toolchain / cached runner binary; `--stop` never refuses on a runner (for the stacks it tries the selection, warns if refused and lets their scripts decide); a `--runner` without a value is still a usage error rc 2. Exported as `CONTAINERS_RUNNER` so the site rebuild (`site-build`) and the workshop / ai stacks' own scripts see the same choice |
| `_tools/deploy-langs.sh` | `--runner=NAME` (in the argument parser, usage text and `--prove-args`); validated before any build, stage, commit or push; reaches the containerised jekyll step through `site-build` |
| `_tools/helixtranslate-local.sh` | `--runner=NAME`; outranks the legacy `HELIX_RUNTIME` override |
| `_tools/hawkscan/run.sh` | `--runner=NAME`; with no forced runner the module's selection is preferred and, when it cannot answer (no Go / no cached runner binary), the host's `podman else docker` detection is used so the scan still runs; a FORCED runner that is refused is exit 2, not the "skipped" exit 0. Only podman, docker and nerdctl can `run --rm`; any other runner is refused |
| `_tools/containers/bin/site-build` (`cmd/site-build`) | `--runner=NAME` / env, through `runtime.ResolveRunner` + `SelectRuntime` + `NewDefaultOrchestratorForRunner`; `-probe` prints `runner=<name> source=<flag\|env\|default>` |
| `_tools/containers/bin/ocr` (`cmd/ocr`) | same as `site-build` |
| `_tools/containers/bin/runtime-probe` (`cmd/runtime-probe`) | same; the stdout line is `runtime=<name> version=<v> runner=<name> source=<...>`; `-name-only` still prints one bare name; `-priority` together with a forced runner is refused |
| `_tools/containers/prove-ocr.sh` | `--runner=NAME`, exported for every `cmd/ocr` run it makes |
| `_tools/containers/bin/distribute-helixtranslate` (`cmd/distribute-helixtranslate`) | `--runner=NAME` forces the runtime on BOTH remote hosts (see "Remote hosts") |
| `_tools/helixtranslate-container.sh` | `--runner=NAME` overrides the per-host runtime (see "Remote hosts") |
| `_tools/translate-fleet.sh` | `--runner=NAME` anywhere in its arguments; reaches every fleet job |
| `_tools/distribute-helixtranslate.sh` | `--runner=NAME`, checked on every host before anything is changed |
| `_tools/od/start-daemon.sh` | **accepted and ignored**: it starts a native Electron process and uses no container, so it prints `no containers used` and carries on. A missing value is still exit 2 |
| `_tools/containers/compose/jekyll-build.sh`, `ocr-run.sh` | **N/A**: they run *inside* the container and cannot know which runner started them; their host-side launchers (`site-build`, `ocr`) take the flag |

The umbrella also wraps the submodules' launchers (`workshop/scripts/start.sh`,
`ai_interviewing/platform/scripts/start.sh`, ...). Those accept the same flag in
their own repositories; this umbrella forwards the choice to them as
`CONTAINERS_RUNNER` rather than by argument, so it works with any version.

## Remote hosts (the three `helixtranslate` scripts)

These scripts do not run containers on this machine; each host in `HT_FLEET` has
its own runtime. `--runner` **overrides the per-host choice for every host**.
Validation is split, deliberately:

* **Locally** only the *shape* of the name is checked (`[a-z0-9-]`, because it is
  interpolated into a remote command line); anything else is exit 2 before any
  `ssh`. These scripts must run from a checkout with no Go toolchain, so the
  module's list is not consulted here.
* **On the remote host** `_tools/helixtranslate-container/run.sh` (and, for the
  Go/shell distributors, a `command -v` probe) checks that the runner is
  installed. A host without it exits **2** and the shim surfaces that as exit 2.
  There is no fallback to the configured runtime.

Honest boundary: the ssh transport legs cannot be executed on the development
host (its fleet hosts do not resolve), so the proof runs the remote-side script
locally and the local parsing before ssh; the end-to-end remote run is not
claimed.

## Running it

```bash
bash scripts/qa-up.sh --runner=podman
CONTAINERS_RUNNER=podman bash _tools/deploy-langs.sh --dry-run   # flag would win over this
_tools/containers/bin/site-build --runner=docker -probe          # exit 2 where docker is absent
```

The module's helper (`scripts/lib/runner.sh`) is found from this repository's
root at `submodules/containers`, or `$CONTAINERS_DIR`. If it is missing, or the
submodule is pinned before the selector landed, the launcher exits **2** and says
which `git submodule update --init` command fixes it; it never skips the flag.

## Evidence

`bash scripts/verify-runner-flag.sh` executes the real launchers and binaries on
the host (installed runner accepted, a genuinely absent supported runner refused,
precedence both ways, helper-missing refusal). `--prove-failure` breaks each
shared helper in a sandbox copy in eight ways and requires the same core cases to
catch every mutant, with an unmutated control that must pass.
