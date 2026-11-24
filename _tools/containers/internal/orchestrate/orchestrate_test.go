package orchestrate

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"digital.vasic.containers/pkg/runtime"
)

// fakeRT embeds the interface so only the two methods under test are written.
// It is a test double for the LOGIC of WaitForExit; it is not evidence about a
// real container runtime (§11.4.289) -- see TestDumpLogsAgainstRealRuntime for
// the live-runtime test, which skips with a reason when no runtime is present.
type fakeRT struct {
	runtime.ContainerRuntime
	seq   []*runtime.ContainerStatus
	errs  []error
	calls int
}

func (f *fakeRT) Status(ctx context.Context, id string) (*runtime.ContainerStatus, error) {
	i := f.calls
	f.calls++
	if i < len(f.errs) && f.errs[i] != nil {
		return nil, f.errs[i]
	}
	if i >= len(f.seq) {
		i = len(f.seq) - 1
	}
	return f.seq[i], nil
}

func mkRoot(t *testing.T, gitmodules, tools bool) string {
	t.Helper()
	d := t.TempDir()
	if gitmodules {
		if err := os.WriteFile(filepath.Join(d, ".gitmodules"), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if tools {
		if err := os.Mkdir(filepath.Join(d, "_tools"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return d
}

func TestIsRepoRoot(t *testing.T) {
	cases := []struct {
		name      string
		gm, tools bool
		want      bool
	}{{"both", true, true, true}, {"only gitmodules", true, false, false}, {"only _tools", false, true, false}, {"neither", false, false, false}}
	for _, c := range cases {
		if got := IsRepoRoot(mkRoot(t, c.gm, c.tools)); got != c.want {
			t.Errorf("%s: IsRepoRoot=%v want %v", c.name, got, c.want)
		}
	}
}

func TestResolveRootExplicit(t *testing.T) {
	good := mkRoot(t, true, true)
	got, err := ResolveRoot(good)
	if err != nil || got != good {
		t.Fatalf("explicit good root: got %q err %v", got, err)
	}
	if _, err := ResolveRoot(mkRoot(t, true, false)); err == nil {
		t.Fatal("explicit dir lacking _tools must be refused, got nil error")
	}
}

func TestResolveRootWalksUpFromCwd(t *testing.T) {
	root := mkRoot(t, true, true)
	deep := filepath.Join(root, "a", "b")
	if err := os.MkdirAll(deep, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Chdir(deep)
	got, err := ResolveRoot("")
	if err != nil {
		t.Fatal(err)
	}
	want, _ := filepath.EvalSymlinks(root)
	g, _ := filepath.EvalSymlinks(got)
	if g != want {
		t.Fatalf("walked to %q want %q", g, want)
	}
}

func TestResolveRootNoAncestor(t *testing.T) {
	t.Chdir(t.TempDir())
	// A temp dir has no ancestor carrying both markers on a sane host; if the
	// host does have one the premise is false and the test cannot decide.
	if _, err := ResolveRoot(""); err == nil {
		t.Skip("an ancestor of the temp dir looks like an umbrella root; cannot decide (not a pass)")
	}
}

func TestWaitForExitReturnsRealExitCode(t *testing.T) {
	if testing.Short() {
		t.Skip("polls at 2s")
	}
	f := &fakeRT{seq: []*runtime.ContainerStatus{
		{State: runtime.StateRunning},
		{State: runtime.StateStopped, ExitCode: 7},
	}}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	st, err := WaitForExit(ctx, f, "c")
	if err != nil {
		t.Fatal(err)
	}
	if st.ExitCode != 7 {
		t.Fatalf("exit code %d, want the container's real 7", st.ExitCode)
	}
}

func TestWaitForExitTimesOutWithoutFabricatingCode(t *testing.T) {
	f := &fakeRT{seq: []*runtime.ContainerStatus{{State: runtime.StateRunning}}}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	st, err := WaitForExit(ctx, f, "c")
	if err == nil || st != nil {
		t.Fatalf("a still-running container at deadline must be an error and nil status, got %v %v", st, err)
	}
}

func TestWaitForExitReportsLastStatusError(t *testing.T) {
	boom := errors.New("runtime unreachable")
	f := &fakeRT{seq: []*runtime.ContainerStatus{nil}, errs: []error{boom, boom, boom, boom}}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_, err := WaitForExit(ctx, f, "c")
	if err == nil || !strings.Contains(err.Error(), "runtime unreachable") {
		t.Fatalf("deadline after status errors must wrap the last error, got %v", err)
	}
}

func TestLogTailIsAcceptedByPodman(t *testing.T) {
	// Pins the measured upstream workaround: "all" is rejected by podman, a
	// negative count is accepted. Changing it silently would reintroduce the
	// silent-empty-log defect documented on LogTail.
	if LogTail != "-1" {
		t.Fatalf("LogTail=%q; podman rejects \"all\"", LogTail)
	}
}

func TestExitCodesAreThreeValued(t *testing.T) {
	if ExitOK != 0 || ExitFail != 1 || ExitUndetermined != 2 {
		t.Fatal("exit-code contract changed")
	}
}

// TestDumpLogsMissingContainerAgainstRealRuntime is a LIVE test: it asks the
// real runtime (auto-detected, never hardcoded) for the logs of a container
// that does not exist. The contract under test is that a broken log call is
// reported loudly on stderr and never reads as a silent container.
func TestDumpLogsMissingContainerAgainstRealRuntime(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	rt, err := runtime.AutoDetect(ctx)
	if err != nil || rt == nil {
		t.Skipf("no container runtime on this host (%v): cannot run, NOT a pass", err)
	}
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	old := os.Stderr
	os.Stderr = w
	DumpLogs(ctx, rt, "orch-test", "orchestrate-test-no-such-container-xyz")
	w.Close()
	os.Stderr = old
	buf := make([]byte, 8192)
	n, _ := r.Read(buf)
	out := string(buf[:n])
	if !strings.Contains(out, "unavailable") && !strings.Contains(out, "FAILED") && !strings.Contains(out, "ended early") {
		t.Fatalf("a missing container's logs must be reported as a failure, stderr was %q", out)
	}
	if strings.Contains(out, "genuinely printed nothing") {
		t.Fatalf("a missing container was reported as silent: %q", out)
	}
}
