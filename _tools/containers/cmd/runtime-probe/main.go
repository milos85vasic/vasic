// Command runtime-probe answers ONE question — "which container runtime is
// actually on this machine?" — and answers it by asking the canonical
// Containers Submodule, never by running `command -v podman`.
//
// WHY IT EXISTS (§11.4.76(1) and (4)).
//
// `_tools/helixtranslate-local.sh` decided that question for itself: line 32
// named the literal `podman`. The anchor lists "runtime auto-detection" FIRST
// among the capabilities the Containers Submodule is authoritative for, and
// §11.4.76(4) forbids a consuming project from growing a parallel
// implementation of one. `runtime.AutoDetect` is that function; this command is
// a thin, shell-callable front for it so a bash script can consume the module's
// answer instead of freezing its own.
//
// SCOPE — LOCAL ONLY, and the boundary is measured rather than assumed.
//
// Two other scripts also name a runtime:
//
//	_tools/helixtranslate-container.sh:70  host == amber.local ? docker : podman
//	_tools/translate-fleet.sh:56           host == amber.local ? docker : podman
//
// Those are NOT the same defect and this command does not replace them. Both
// name the runtime of a REMOTE host, and the module has no remote runtime
// detector to defer to: `pkg/remote`'s own `RemoteHost` struct carries a
// declared `Runtime string` field ("the container runtime on this host"), and
// `grep -rn 'DetectRuntime\|AutoDetect' pkg/remote pkg/discovery` outside tests
// matches nothing. A per-host runtime name is therefore CONFIGURATION that the
// module itself expects a consumer to supply — not a primitive being
// reimplemented. Extending upstream with a remote detector would let those two
// lines go away too; until then they stay, correctly.
//
// WHAT IT DELIBERATELY DOES NOT DO.
//
// It does not run containers. The three scripts above each perform a one-shot
// `run --rm -i` that streams a document on STDIN, and that shape is NOT
// expressible through the module today — measured at gitlink
// d940b51fc247c285c805799452992da8d09c75b9:
//
//   - `runtime.ContainerRuntime` (pkg/runtime/runtime.go) declares Name,
//     Version, IsAvailable, Start, Stop, Remove, Status, List, Stats, Exec and
//     Logs. There is NO Run and no Create: the interface operates on containers
//     that already exist, so there is no ephemeral-run primitive to call.
//   - `Exec(ctx, id, cmd []string)` takes no stdin and returns a buffered
//     *ExecResult.
//   - `grep -rn Stdin pkg/` outside tests matches four files. Three set
//     `cmd.Stdin = nil` (emulator, vm/qemu, cuttlefish). The fourth,
//     pkg/remote/connection/interface.go:146, declares `WithStdin` — but that
//     package is interfaces and option builders only: nothing implements its
//     Connection interface and no constructor returns one.
//
// So the stdin half stays in bash and is declared as an exception in each
// script's own header, while the half the module CAN model — which runtime —
// moves here. Closing the remaining half means extending
// vasic-digital/containers upstream, per §11.4.76(4), not rewriting it here.
//
// EXIT CODES are three-valued, as every check in this tree is:
//
//	0  a runtime was detected and is reported on stdout
//	1  a real failure (bad usage)
//	2  COULD NOT DETERMINE — no container runtime is available here
//
// A 2 is never a pass. Build this binary; do not `go run` it — `go run`
// collapses every non-zero exit into 1 and prints "exit status N", which
// destroys exactly that distinction (measured for cmd/site-build, same cause).
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"digital.vasic.containers/pkg/runtime"
)

const (
	exitOK           = 0
	exitFail         = 1
	exitUndetermined = 2
)

func main() { os.Exit(run(os.Args[1:], os.Stdout, os.Stderr)) }

func run(args []string, stdout, stderr *os.File) int {
	fs := flag.NewFlagSet("runtime-probe", flag.ContinueOnError)
	fs.SetOutput(stderr)
	var (
		flagNameOnly = fs.Bool("name-only", false,
			"Print ONLY the runtime name (e.g. `podman`), for shell consumption")
		flagPriority = fs.String("priority", "",
			"Comma-separated preference order (default: the module's own priority)")
		flagTimeout = fs.Duration("timeout", 15*time.Second,
			"Wall-clock budget for detection")
	)
	if err := fs.Parse(args); err != nil {
		return exitFail
	}
	if fs.NArg() != 0 {
		fmt.Fprintf(stderr, "runtime-probe: unexpected argument %q\n", fs.Arg(0))
		return exitFail
	}

	ctx, cancel := context.WithTimeout(context.Background(), *flagTimeout)
	defer cancel()

	// The whole point of this program: the module decides, not `command -v`.
	var (
		rt  runtime.ContainerRuntime
		err error
	)
	if p := parsePriority(*flagPriority); len(p) > 0 {
		rt, err = runtime.AutoDetectWithPriority(ctx, p)
	} else {
		rt, err = runtime.AutoDetect(ctx)
	}
	if err != nil || rt == nil {
		fmt.Fprintf(stderr,
			"runtime-probe: COULD NOT DETERMINE — no container runtime is available here: %v\n", err)
		return exitUndetermined
	}

	if *flagNameOnly {
		fmt.Fprintln(stdout, rt.Name())
		return exitOK
	}

	version, verr := rt.Version(ctx)
	if verr != nil {
		// A detected runtime whose version cannot be read is still detected.
		// Say so rather than inventing a version string.
		version = "(version unavailable)"
	}
	fmt.Fprintf(stdout, "runtime=%s version=%s\n", rt.Name(), strings.TrimSpace(version))
	return exitOK
}

// parsePriority splits and trims a comma-separated preference list, dropping
// empty fields so that "podman,,docker" and " podman , docker " both mean the
// same two runtimes in the same order.
func parsePriority(s string) []string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	out := make([]string, 0, 4)
	for _, f := range strings.Split(s, ",") {
		if f = strings.TrimSpace(f); f != "" {
			out = append(out, f)
		}
	}
	return out
}
