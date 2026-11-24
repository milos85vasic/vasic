// Package runnersel is this repository's single seam onto the Containers
// Submodule's forced-runner selector (docs/RUNNER_FLAG.md in the module):
//
//	precedence   --runner=NAME | --runner NAME   >   $CONTAINERS_RUNNER   >   default order
//
// It owns NO selection logic. Parsing, validation, the supported-runner list and
// the "forced means forced, never fall back" rule all live in
// digital.vasic.containers/pkg/runtime (ParseRunnerFlag, ResolveRunner,
// SelectRuntime) and pkg/compose (NewDefaultOrchestratorForRunner). Every
// command under cmd/ goes through here so the contract is identical everywhere
// (§11.4.76(4): consume, never reimplement).
//
// Every error returned here maps to exit 2 (COULD NOT DETERMINE / refused) at
// the call site: an unknown runner, a runner that is not installed, and a
// runner with no compose front-end are all refusals, never a fallback.
package runnersel

import (
	"context"
	"fmt"
	"os"

	"digital.vasic.containers/pkg/compose"
	"digital.vasic.containers/pkg/logging"
	"digital.vasic.containers/pkg/runtime"
)

// Parse splits --runner out of args and resolves flag > env > default.
// getenv may be nil, meaning os.Getenv.
func Parse(args []string, getenv func(string) string) (runtime.RunnerChoice, []string, error) {
	if getenv == nil {
		getenv = os.Getenv
	}
	val, rest, found, err := runtime.ParseRunnerFlag(args)
	if err != nil {
		return runtime.RunnerChoice{}, nil, err
	}
	choice, err := runtime.ResolveRunner(val, found, getenv)
	if err != nil {
		return runtime.RunnerChoice{}, nil, err
	}
	return choice, rest, nil
}

// Runtime returns the runtime for the choice: the forced one or an error —
// never another runner.
func Runtime(ctx context.Context, c runtime.RunnerChoice) (runtime.ContainerRuntime, error) {
	return runtime.SelectRuntime(ctx, c)
}

// Orchestrator returns a compose orchestrator bound to the choice's runner
// (the default detection order when nothing was forced).
func Orchestrator(root string, log logging.Logger, c runtime.RunnerChoice) (*compose.DefaultOrchestrator, error) {
	return compose.NewDefaultOrchestratorForRunner(root, log, c.Name)
}

// Describe renders "runner=NAME source=SRC" for the runtime that was actually
// chosen (rt.Name(), which for a default choice is whatever AutoDetect found).
func Describe(rt runtime.ContainerRuntime, c runtime.RunnerChoice) string {
	return fmt.Sprintf("runner=%s source=%s", rt.Name(), c.Source)
}

// Usage is the help paragraph for the flag; the runner list is derived from the
// module, never hardcoded.
func Usage() string {
	return fmt.Sprintf("  --runner=NAME   force the container runner (%v|auto); overrides $%s and the default order.\n"+
		"                  An unknown or not-installed runner is refused (exit 2); there is no fallback.\n",
		runtime.SupportedRunners(), runtime.EnvRunner)
}
