package main

import (
	"errors"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestParsePriority pins the only pure function here. The empty-and-whitespace
// cases matter because a shell passing an unset variable through -priority
// would otherwise turn "no preference" into a one-element list containing "".
func TestParsePriority(t *testing.T) {
	for _, tc := range []struct {
		in   string
		want []string
	}{
		{"", nil},
		{"   ", nil},
		{",,", nil},
		{"podman", []string{"podman"}},
		{" podman , docker ", []string{"podman", "docker"}},
		{"podman,,docker", []string{"podman", "docker"}},
	} {
		got := parsePriority(tc.in)
		if len(got) != len(tc.want) {
			t.Fatalf("parsePriority(%q) = %v, want %v", tc.in, got, tc.want)
		}
		for i := range got {
			if got[i] != tc.want[i] {
				t.Fatalf("parsePriority(%q)[%d] = %q, want %q", tc.in, i, got[i], tc.want[i])
			}
		}
	}
}

// TestExitCodesAreThreeValued builds the real binary and exercises each exit
// code against a REAL condition rather than a mock:
//
//	rc 1  bad usage
//	rc 2  a PATH that genuinely contains no container runtime
//
// rc 0 is asserted only when this host actually has a runtime; on a host
// without one the test SKIPs that leg rather than faking a pass, per §11.4.3.
//
// The rc-2 leg is the paired mutation for the whole program: it is DATA (an
// empty PATH), so it cannot be made inoperative by editing the code it guards,
// and a build that silently reported "podman" regardless of the environment
// would fail it.
func TestExitCodesAreThreeValued(t *testing.T) {
	if _, err := exec.LookPath("go"); err != nil {
		t.Skip("no go toolchain on PATH; cannot build the binary under test")
	}
	bin := filepath.Join(t.TempDir(), "runtime-probe")
	build := exec.Command("go", "build", "-o", bin, ".")
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}

	t.Run("rc1_bad_usage", func(t *testing.T) {
		if rc := runBin(t, bin, nil, "unexpected-positional"); rc != 1 {
			t.Fatalf("bad usage: rc = %d, want 1", rc)
		}
	})

	t.Run("rc2_no_runtime_on_path", func(t *testing.T) {
		empty := t.TempDir()
		rc := runBin(t, bin, []string{"PATH=" + empty}, "-name-only")
		if rc != 2 {
			t.Fatalf("empty PATH: rc = %d, want 2 (COULD NOT DETERMINE)", rc)
		}
	})

	t.Run("rc0_when_a_runtime_is_present", func(t *testing.T) {
		if !anyRuntimeOnPath() {
			t.Skip("no container runtime on this host; nothing to detect (documented SKIP, not a pass)")
		}
		out, rc := runBinOut(t, bin, nil, "-name-only")
		if rc != 0 {
			t.Fatalf("rc = %d, want 0; output %q", rc, out)
		}
		if strings.TrimSpace(out) == "" {
			t.Fatal("rc 0 with an empty runtime name: a pass carrying no evidence")
		}
	})
}

func anyRuntimeOnPath() bool {
	for _, n := range []string{"podman", "docker", "nerdctl", "crictl", "lxc", "kubectl"} {
		if _, err := exec.LookPath(n); err == nil {
			return true
		}
	}
	return false
}

func runBin(t *testing.T, bin string, env []string, args ...string) int {
	t.Helper()
	_, rc := runBinOut(t, bin, env, args...)
	return rc
}

func runBinOut(t *testing.T, bin string, env []string, args ...string) (string, int) {
	t.Helper()
	cmd := exec.Command(bin, args...)
	if env != nil {
		cmd.Env = env
	}
	out, err := cmd.Output()
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return string(out), ee.ExitCode()
		}
		t.Fatalf("running %s %v: %v", bin, args, err)
	}
	return string(out), 0
}
