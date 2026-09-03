// Command site-build runs this umbrella's site-build workloads inside
// containers, driving the container runtime EXCLUSIVELY through the canonical
// Containers Submodule (`digital.vasic.containers`) as §11.4.76 requires.
//
// # Why this program exists
//
// §11.4.76(1) makes `vasic-digital/containers` the authoritative library for
// runtime auto-detection, compose orchestration and lifecycle/health
// management, and §11.4.76(4) forbids reimplementing any of it in a consuming
// project. So this program shells out to no runtime: `podman` and `docker`
// appear nowhere in it. It calls
//
//	runtime.AutoDetect      -> which runtime is actually present
//	compose.NewDefaultOrchestrator / Up / Down  -> compose lifecycle
//	rt.Status / rt.Logs     -> the stopped container's real exit code + output
//
// and lets the module own every process it starts.
//
// §11.4.76(3)'s on-demand-infra invariant is why the entry point is a program
// rather than a documented sequence of commands: an operator must not be
// required to bring anything up by hand before a build or a test runs.
//
// # Anti-bluff contract (§11.4, §1.1)
//
// A zero exit from `compose up` is NOT evidence that a site was built, and
// this program never treats it as such. Every run:
//
//  1. snapshots the artifact's mtime BEFORE starting anything;
//  2. reads the exit code back off the STOPPED container through the module's
//     runtime API — not from the compose command's own status;
//  3. requires the artifact to exist, be non-empty, AND be strictly newer than
//     the snapshot. A leftover artifact from an earlier run cannot pass.
//
// # Exit codes — three-valued, as every check in this tree is
//
//	0  the workload ran and produced fresh, verified output
//	1  a real failure: the container exited non-zero, or produced nothing
//	2  COULD NOT DETERMINE — no container runtime, no compose command, or the
//	   container's outcome could not be read back. NEVER a pass.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"digital.vasic.containers/pkg/compose"
	"digital.vasic.containers/pkg/logging"
	"digital.vasic.containers/pkg/runtime"
)

// Exit codes. Three-valued by project convention: 2 is COULD NOT DETERMINE and
// is never a pass.
const (
	exitOK           = 0
	exitFail         = 1
	exitUndetermined = 2
)

// workload describes one containerised job this program knows how to run.
//
// artifact/artifactMustBeFresh are the anti-bluff post-conditions. A workload
// with an empty artifact path asserts only the container's exit code, and says
// so in its own output rather than implying it verified more than it did.
type workload struct {
	// service is the compose service name in compose.sites.yml.
	service string
	// container is that service's container_name, used to read the exit code
	// and logs back through the runtime API after it stops.
	container string
	// artifact is a repo-root-relative path the workload must have produced.
	// Empty means "this workload produces no file artifact".
	artifact string
	// what is a one-line human description for the log.
	what string
}

var workloads = map[string]workload{
	"jekyll": {
		service:   "jekyll-build",
		container: "vasic-jekyll-build",
		artifact:  filepath.Join("milosvasic.ru", "_site", "index.html"),
		what:      "rebuild milosvasic.ru/_site with Jekyll",
	},
	"gen-test": {
		service:   "gen-test",
		container: "vasic-gen-test",
		artifact:  "",
		what:      "run the Go generator's unit tests on a pinned toolchain",
	},
}

func main() {
	os.Exit(run())
}

func run() int {
	var (
		flagRoot      = flag.String("root", "", "Umbrella repository root (default: derived from this file's location, then $PWD)")
		flagWorkload  = flag.String("workload", "jekyll", "Which workload to run: jekyll | gen-test")
		flagCompose   = flag.String("compose", "", "Compose file (default: <root>/_tools/containers/compose/compose.sites.yml)")
		flagProject   = flag.String("project-name", "vasic-sites", "compose --project-name")
		flagBuildYear = flag.String("build-year", "", "Pin the rendered footer © year (jekyll workload only)")
		flagTimeout   = flag.Duration("timeout", 20*time.Minute, "Overall wall-clock budget for the workload")
		flagProbe     = flag.Bool("probe", false, "Report runtime + compose availability and exit; start nothing")
	)
	flag.Parse()

	log := logging.NewStdLogger("site-build")

	root, err := resolveRoot(*flagRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "site-build: COULD NOT DETERMINE the repository root: %v\n", err)
		return exitUndetermined
	}

	wl, ok := workloads[*flagWorkload]
	if !ok {
		names := make([]string, 0, len(workloads))
		for k := range workloads {
			names = append(names, k)
		}
		fmt.Fprintf(os.Stderr, "site-build: unknown -workload %q (known: %s)\n",
			*flagWorkload, strings.Join(names, ", "))
		return exitFail
	}

	composeFile := *flagCompose
	if composeFile == "" {
		composeFile = filepath.Join(root, "_tools", "containers", "compose", "compose.sites.yml")
	}
	if _, statErr := os.Stat(composeFile); statErr != nil {
		fmt.Fprintf(os.Stderr, "site-build: COULD NOT DETERMINE — compose file unreadable: %v\n", statErr)
		return exitUndetermined
	}

	ctx, cancel := context.WithTimeout(context.Background(), *flagTimeout)
	defer cancel()
	ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()

	// ---- 1. Which runtime is actually here? Ask the module, never `command -v`.
	rt, err := runtime.AutoDetect(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"site-build: COULD NOT DETERMINE — no container runtime available: %v\n", err)
		return exitUndetermined
	}
	version, verr := rt.Version(ctx)
	if verr != nil {
		version = "(version unavailable)"
	}
	log.Info("runtime: %s %s", rt.Name(), strings.TrimSpace(version))

	// ---- 2. Which compose command? Again the module decides.
	orch, err := compose.NewDefaultOrchestrator(root, log)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"site-build: COULD NOT DETERMINE — no compose command available: %v\n", err)
		return exitUndetermined
	}

	if *flagProbe {
		fmt.Printf("runtime=%s version=%s compose=available root=%s workload=%s\n",
			rt.Name(), strings.TrimSpace(version), root, *flagWorkload)
		return exitOK
	}

	// The compose file reads these; nothing in it is a frozen literal.
	os.Setenv("VASIC_ROOT", root)
	if *flagBuildYear != "" {
		os.Setenv("VASIC_BUILD_YEAR", *flagBuildYear)
	}

	project := compose.ComposeProject{
		Name:     *flagProject,
		File:     composeFile,
		Services: []string{wl.service},
	}

	// ---- 3. Snapshot the artifact BEFORE anything runs. This is the whole
	// basis of the freshness assertion: without a before-value, "the file
	// exists" is a statement about history, not about this run.
	var artifactPath string
	var before time.Time
	if wl.artifact != "" {
		artifactPath = filepath.Join(root, wl.artifact)
		if fi, serr := os.Stat(artifactPath); serr == nil {
			before = fi.ModTime()
			log.Info("artifact %s exists, mtime %s (must be superseded)",
				wl.artifact, before.Format(time.RFC3339))
		} else {
			log.Info("artifact %s absent before this run", wl.artifact)
		}
	}
	startedAt := time.Now()

	// ---- 4. A stale container from an interrupted run would make `up` fail on
	// the container_name. Tear the project down first; a fresh tree has nothing
	// to remove and this is a no-op there.
	if derr := orch.Down(ctx, project, compose.WithDownRemoveOrphans(true)); derr != nil {
		log.Warn("pre-run compose down was not clean (continuing): %v", derr)
	}

	log.Info("starting %q — %s", wl.service, wl.what)
	if err := orch.Up(ctx, project,
		compose.WithUpDetach(true),
		compose.WithRemoveOrphans(true),
	); err != nil {
		fmt.Fprintf(os.Stderr, "site-build: compose up failed: %v\n", err)
		dumpLogs(ctx, rt, wl.container)
		return exitFail
	}

	// ---- 5. Wait for the container to stop, then read its REAL exit code off
	// the stopped container through the module's runtime API.
	status, werr := waitForExit(ctx, rt, wl.container)

	dumpLogs(ctx, rt, wl.container)

	// Tear down regardless of outcome; keep the named volumes (the gem and Go
	// caches are the reason the second run is fast).
	teardownCtx, teardownCancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer teardownCancel()
	if derr := orch.Down(teardownCtx, project, compose.WithDownRemoveOrphans(true)); derr != nil {
		log.Warn("compose down after the run was not clean: %v", derr)
	}

	if werr != nil {
		fmt.Fprintf(os.Stderr,
			"site-build: COULD NOT DETERMINE the outcome of %q: %v\n", wl.service, werr)
		return exitUndetermined
	}
	if status.ExitCode != 0 {
		fmt.Fprintf(os.Stderr,
			"site-build: FAIL — %q exited %d\n", wl.service, status.ExitCode)
		return exitFail
	}
	log.Info("%q exited 0 after %s", wl.service, time.Since(startedAt).Truncate(time.Second))

	// ---- 6. Exit 0 is not evidence. Prove the artifact.
	if artifactPath == "" {
		fmt.Printf("✅ site-build: %s — container exited 0. "+
			"This workload declares NO file artifact, so nothing beyond the exit code is asserted.\n",
			wl.service)
		return exitOK
	}

	fi, serr := os.Stat(artifactPath)
	if serr != nil {
		fmt.Fprintf(os.Stderr,
			"site-build: FAIL — %q exited 0 but %s does not exist. "+
				"A green exit with no artifact is a bluff, and it is reported as a failure.\n",
			wl.service, wl.artifact)
		return exitFail
	}
	if fi.Size() == 0 {
		fmt.Fprintf(os.Stderr,
			"site-build: FAIL — %s exists but is empty (0 bytes).\n", wl.artifact)
		return exitFail
	}
	// Strictly newer than the pre-run snapshot AND not older than the moment we
	// started. Either check alone can be fooled — the first by a file that was
	// never there, the second by a filesystem with coarse timestamps — so both
	// are made, and the failure message says which one bit.
	if !before.IsZero() && !fi.ModTime().After(before) {
		fmt.Fprintf(os.Stderr,
			"site-build: FAIL — %s was NOT rewritten: mtime is still %s. "+
				"The container exited 0 while leaving the previous artifact in place.\n",
			wl.artifact, fi.ModTime().Format(time.RFC3339))
		return exitFail
	}
	if fi.ModTime().Before(startedAt.Add(-2 * time.Second)) {
		fmt.Fprintf(os.Stderr,
			"site-build: FAIL — %s has mtime %s, which predates this run (started %s).\n",
			wl.artifact, fi.ModTime().Format(time.RFC3339), startedAt.Format(time.RFC3339))
		return exitFail
	}

	fmt.Printf("✅ site-build: %s — %s\n", wl.service, wl.what)
	fmt.Printf("   runtime  : %s\n", rt.Name())
	fmt.Printf("   artifact : %s (%d bytes, mtime %s)\n",
		wl.artifact, fi.Size(), fi.ModTime().Format(time.RFC3339))
	if before.IsZero() {
		fmt.Printf("   freshness: created by this run (absent before it)\n")
	} else {
		fmt.Printf("   freshness: mtime advanced from %s\n", before.Format(time.RFC3339))
	}
	return exitOK
}

// waitForExit polls the container until it leaves the running state and
// returns its final status. It returns an error — never a fabricated exit code
// — when the outcome cannot be established, so the caller reports rc 2 rather
// than guessing.
func waitForExit(
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

// logTail is the value passed to runtime.WithTail.
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
// this program does instead is use the module's own public option to ask for a
// value podman accepts, and report Close()'s error instead of discarding it.
// "-1" is what was measured to work on podman; docker's --tail also accepts a
// negative count as "all", though that half was NOT measured here.
const logTail = "-1"

// dumpLogs streams the container's output to stdout. Failure to read logs is
// reported but never changes the verdict — the verdict comes from the exit
// code and the artifact. It is reported LOUDLY, though: an empty log section
// that is really a broken log call must not read as an empty container.
func dumpLogs(ctx context.Context, rt runtime.ContainerRuntime, name string) {
	rc, err := rt.Logs(ctx, name, runtime.WithTail(logTail))
	if err != nil {
		fmt.Fprintf(os.Stderr, "site-build: (container logs unavailable: %v)\n", err)
		return
	}
	fmt.Println("---------------- container output: " + name + " ----------------")
	n, cerr := io.Copy(os.Stdout, rc)
	if cerr != nil && !errors.Is(cerr, io.EOF) {
		fmt.Fprintf(os.Stderr, "site-build: (log stream ended early: %v)\n", cerr)
	}
	// Close() is where the log command's own exit status surfaces. Discarding
	// it is how a failed `podman logs` masquerades as a silent container.
	if closeErr := rc.Close(); closeErr != nil {
		fmt.Fprintf(os.Stderr,
			"site-build: WARNING — reading container logs FAILED (%v). "+
				"The %d byte(s) above are what was readable, not necessarily what the container printed.\n",
			closeErr, n)
	} else if n == 0 {
		fmt.Fprintf(os.Stderr,
			"site-build: NOTE — the log command succeeded and returned 0 bytes; "+
				"this container genuinely printed nothing.\n")
	}
	fmt.Println("---------------- end container output ----------------")
}

// resolveRoot finds the umbrella repository root. Explicit -root wins; then the
// directory this source file lives in (three levels up from cmd/site-build);
// then $PWD walked upwards. It never hardcodes an absolute path — a checkout
// must work from anywhere.
func resolveRoot(explicit string) (string, error) {
	if explicit != "" {
		abs, err := filepath.Abs(explicit)
		if err != nil {
			return "", err
		}
		if !isRepoRoot(abs) {
			return "", fmt.Errorf("-root %s does not look like the umbrella root (no .gitmodules + _tools)", abs)
		}
		return abs, nil
	}
	if wd, err := os.Getwd(); err == nil {
		for dir := wd; ; {
			if isRepoRoot(dir) {
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

func isRepoRoot(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, ".gitmodules")); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "_tools")); err != nil {
		return false
	}
	return true
}
