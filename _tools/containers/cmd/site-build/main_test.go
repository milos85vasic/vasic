package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestMain lets the test binary act as the site-build program itself: when
// SITE_BUILD_AS_MAIN=1 it runs the real run() and exits with its code. The
// characterisation tests below therefore exercise the real entry point,
// flag parsing included, in a child process (flag.CommandLine is global, so
// calling run() twice in one process is not possible).
func TestMain(m *testing.M) {
	if os.Getenv("SITE_BUILD_AS_MAIN") == "1" {
		os.Exit(run())
	}
	os.Exit(m.Run())
}

// runMain runs the real program with args in dir and returns exit code,
// stdout and stderr.
func runMain(t *testing.T, dir string, args ...string) (int, string, string) {
	t.Helper()
	cmd := exec.Command(os.Args[0], args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "SITE_BUILD_AS_MAIN=1")
	var so, se bytes.Buffer
	cmd.Stdout, cmd.Stderr = &so, &se
	err := cmd.Run()
	code := 0
	if err != nil {
		ee, ok := err.(*exec.ExitError)
		if !ok {
			t.Fatalf("cannot run the program: %v", err)
		}
		code = ee.ExitCode()
	}
	return code, so.String(), se.String()
}

// fakeRoot builds a directory that IsRepoRoot accepts (.gitmodules + _tools).
func fakeRoot(t *testing.T) string {
	t.Helper()
	d := t.TempDir()
	if err := os.WriteFile(filepath.Join(d, ".gitmodules"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(d, "_tools"), 0o755); err != nil {
		t.Fatal(err)
	}
	return d
}

func TestCharExplicitRootThatIsNotARootIsUndetermined(t *testing.T) {
	code, _, se := runMain(t, t.TempDir(), "-root", t.TempDir())
	if code != 2 || !strings.Contains(se, "COULD NOT DETERMINE the repository root") {
		t.Fatalf("code=%d stderr=%q", code, se)
	}
}

func TestCharUnknownWorkloadIsFailure(t *testing.T) {
	code, _, se := runMain(t, t.TempDir(), "-root", fakeRoot(t), "-workload", "nope")
	if code != 1 || !strings.Contains(se, `unknown -workload "nope" (known: `) ||
		!strings.Contains(se, "jekyll") || !strings.Contains(se, "gen-test") {
		t.Fatalf("code=%d stderr=%q", code, se)
	}
}

func TestCharMissingComposeFileIsUndetermined(t *testing.T) {
	code, _, se := runMain(t, t.TempDir(), "-root", fakeRoot(t))
	if code != 2 || !strings.Contains(se, "compose file unreadable") {
		t.Fatalf("code=%d stderr=%q", code, se)
	}
}

func TestCharUnknownFlagExitsTwoViaFlagPackage(t *testing.T) {
	code, _, _ := runMain(t, t.TempDir(), "-no-such-flag")
	if code != 2 {
		t.Fatalf("code=%d, want 2 (flag.ExitOnError)", code)
	}
}

func TestCharProbeAgainstRealRuntime(t *testing.T) {
	root := fakeRoot(t)
	cf := filepath.Join(root, "c.yml")
	if err := os.WriteFile(cf, []byte("services: {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	code, so, se := runMain(t, t.TempDir(), "-root", root, "-compose", cf, "-probe")
	switch code {
	case 0:
		if !strings.Contains(so, "runtime=") || !strings.Contains(so, "workload=jekyll") {
			t.Fatalf("probe printed %q", so)
		}
	case 2:
		if !strings.Contains(se, "COULD NOT DETERMINE") {
			t.Fatalf("rc 2 without a stated reason: %q", se)
		}
	default:
		t.Fatalf("probe exit %d is neither OK nor UNDETERMINED: %q", code, se)
	}
}

func TestCharWorkloadTable(t *testing.T) {
	j := workloads["jekyll"]
	if j.service != "jekyll-build" || j.container != "vasic-jekyll-build" ||
		j.artifact != filepath.Join("milosvasic.ru", "_site", "index.html") {
		t.Fatalf("jekyll workload changed: %+v", j)
	}
	if g := workloads["gen-test"]; g.artifact != "" || g.service != "gen-test" {
		t.Fatalf("gen-test workload changed: %+v", g)
	}
}
