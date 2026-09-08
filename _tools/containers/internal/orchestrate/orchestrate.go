// Package orchestrate holds the container-lifecycle helpers shared by this
// module's commands (`site-build`, `ocr`).
//
// # Why this package exists
//
// It was extracted, not invented. `cmd/site-build` grew these helpers first;
// when `cmd/ocr` needed the same three — find the repository root, wait for a
// one-shot container to stop and read its REAL exit code back, stream its logs
// without mistaking a broken log call for a silent container — copying them
// would have produced a second, drifting copy of logic whose whole value is
// that it behaves identically everywhere. §11.4.251 forbids exactly that
// shape. So the helpers live here once and both commands call them.
//
// Nothing in this package shells out to a container runtime. Every process is
// started by the canonical Containers Submodule (`digital.vasic.containers`),
// as §11.4.76(1) and (4) require.
package orchestrate

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"digital.vasic.containers/pkg/runtime"
)

// Exit codes. Three-valued by project convention: 2 is COULD NOT DETERMINE and
// is never a pass.
const (
	ExitOK           = 0
	ExitFail         = 1
	ExitUndetermined = 2
)

// LogTail is the value passed to runtime.WithTail.
//
// It is NOT the module's default, and the difference is a MEASURED upstream
// defect rather than a preference. `runtime.defaultLogOptions()` sets
// Tail:"all" (pkg/runtime/options.go:141) and PodmanRuntime.Logs appends it
// verbatim as `--tail all` (pkg/runtime/podman.go:331-333). Podman parses
// --tail with strconv.ParseInt, so measured on this host:
//
//	podman logs --tail all  <c>  -> Error: invalid argument "all" ... rc 125
//	podman logs --tail -1   <c>  -> the container's output,          rc 0
//
// The failure is SILENT to a caller: ExecuteStream starts the process
// successfully, so Logs() returns a nil error, the pipe hits EOF immediately,
// and the rc-125 only reaches the caller through Close() -> cmd.Wait(). A
// caller that defers Close() and ignores its error therefore sees "logs read
// fine, container produced nothing" — which is exactly the shape of a bluff.
//
// Per §11.4.76(4) the FIX belongs upstream in vasic-digital/containers (make
// the podman path translate "all" to "-1", or default to "-1"), not here. What
// these programs do instead is use the module's own public option to ask for a
// value podman accepts, and report Close()'s error instead of discarding it.
// "-1" is what was measured to work on podman; docker's --tail also accepts a
// negative count as "all", though that half was NOT measured here.
const LogTail = "-1"

// WaitForExit polls the container until it leaves the running state and
// returns its final status. It returns an error — never a fabricated exit code
// — when the outcome cannot be established, so the caller reports rc 2 rather
// than guessing.
func WaitForExit(
	ctx context.Context, rt runtime.ContainerRuntime, name string,
) (*runtime.ContainerStatus, error) {
	const poll = 2 * time.Second
	var lastErr error
	for {
		select {
		case <-ctx.Done():
			if lastErr != nil {
				return nil, fmt.Errorf("timed out waiting for %s; last status error: %w", name, lastErr)
			}
			return nil, fmt.Errorf("timed out waiting for %s to exit: %w", name, ctx.Err())
		case <-time.After(poll):
		}

		st, err := rt.Status(ctx, name)
		if err != nil {
			// A container that has already been reaped is indistinguishable, at
			// this layer, from a runtime that cannot answer. Both are recorded
			// and surface as COULD NOT DETERMINE if the deadline arrives first.
			lastErr = err
			continue
		}
		switch st.State {
		case runtime.StateRunning, runtime.StateCreated, runtime.StateRestarting, runtime.StateRemoving:
			continue
		default:
			return st, nil
		}
	}
}

// DumpLogs streams the container's output to stdout. Failure to read logs is
// reported but never changes the verdict — the verdict comes from the exit
// code and the artifact. It is reported LOUDLY, though: an empty log section
// that is really a broken log call must not read as an empty container.
//
// prog is the calling program's name, used only to prefix its own diagnostics.
func DumpLogs(ctx context.Context, rt runtime.ContainerRuntime, prog, name string) {
	rc, err := rt.Logs(ctx, name, runtime.WithTail(LogTail))
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: (container logs unavailable: %v)\n", prog, err)
		return
	}
	fmt.Println("---------------- container output: " + name + " ----------------")
	n, cerr := io.Copy(os.Stdout, rc)
	if cerr != nil && !errors.Is(cerr, io.EOF) {
		fmt.Fprintf(os.Stderr, "%s: (log stream ended early: %v)\n", prog, cerr)
	}
	// Close() is where the log command's own exit status surfaces. Discarding
	// it is how a failed `podman logs` masquerades as a silent container.
	if closeErr := rc.Close(); closeErr != nil {
		fmt.Fprintf(os.Stderr,
			"%s: WARNING — reading container logs FAILED (%v). "+
				"The %d byte(s) above are what was readable, not necessarily what the container printed.\n",
			prog, closeErr, n)
	} else if n == 0 {
		fmt.Fprintf(os.Stderr,
			"%s: NOTE — the log command succeeded and returned 0 bytes; "+
				"this container genuinely printed nothing.\n", prog)
	}
	fmt.Println("---------------- end container output ----------------")
}

// ResolveRoot finds the umbrella repository root. Explicit -root wins; then
// $PWD walked upwards. It never hardcodes an absolute path — a checkout must
// work from anywhere, and `scripts/audit-hardcoded-paths.sh` enforces that.
func ResolveRoot(explicit string) (string, error) {
	if explicit != "" {
		abs, err := filepath.Abs(explicit)
		if err != nil {
			return "", err
		}
		if !IsRepoRoot(abs) {
			return "", fmt.Errorf("-root %s does not look like the umbrella root (no .gitmodules + _tools)", abs)
		}
		return abs, nil
	}
	if wd, err := os.Getwd(); err == nil {
		for dir := wd; ; {
			if IsRepoRoot(dir) {
				return dir, nil
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	return "", errors.New("no ancestor of the working directory contains both .gitmodules and _tools/")
}

// IsRepoRoot reports whether dir carries the two markers that identify this
// umbrella's root.
func IsRepoRoot(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, ".gitmodules")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "_tools")); err != nil {
		return false
	}
	return true
}
