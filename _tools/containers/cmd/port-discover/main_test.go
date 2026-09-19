package main

import (
	"context"
	"errors"
	"net"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"digital.vasic.containers/pkg/serviceregistry"
)

// TestResolvePort_AvoidsAnOccupiedDefaultAndPersists is the real-condition
// proof this command exists for: given a default port that is GENUINELY
// occupied by a live listener (exactly the llama-server-on-8082 conflict
// this command was built to fix), resolvePort must not return that port,
// and a second call for the SAME name must reuse whatever it picked the
// first time rather than churning to a new port each run.
func TestResolvePort_AvoidsAnOccupiedDefaultAndPersists(t *testing.T) {
	occupied, ln := listenOnAFreePort(t)
	defer ln.Close()

	reg := serviceregistry.New(serviceregistry.WithRegistryDir(t.TempDir()))
	ctx := context.Background()

	got, err := resolvePort(ctx, reg, "test-server", occupied)
	if err != nil {
		t.Fatalf("resolvePort: %v", err)
	}
	if got == occupied {
		t.Fatalf("resolvePort returned the OCCUPIED port %d — the whole point of this command is to avoid exactly that", occupied)
	}

	again, err := resolvePort(ctx, reg, "test-server", occupied)
	if err != nil {
		t.Fatalf("resolvePort (second call): %v", err)
	}
	if again != got {
		t.Fatalf("second call for the SAME name returned %d, want the same %d as the first call (stability across runs)", again, got)
	}
}

// TestResolvePort_ReallocatesWhenThePreviouslyRegisteredPortIsNowTaken
// covers the other real branch: a name was registered at a port on an
// EARLIER run, but something else has since bound that exact port (a
// different process, or a stale registration surviving a host reboot).
// resolvePort must detect the port is no longer free and pick a new one,
// not blindly trust the stale registration.
func TestResolvePort_ReallocatesWhenThePreviouslyRegisteredPortIsNowTaken(t *testing.T) {
	dir := t.TempDir()
	reg := serviceregistry.New(serviceregistry.WithRegistryDir(dir))
	ctx := context.Background()

	first, err := resolvePort(ctx, reg, "test-server", 20500)
	if err != nil {
		t.Fatalf("resolvePort: %v", err)
	}

	// Simulate "something else claimed the previously-registered port since
	// the last run" by actually binding it.
	ln, err := net.Listen("tcp", net.JoinHostPort("localhost", strconv.Itoa(first)))
	if err != nil {
		t.Fatalf("could not bind %d to simulate the race: %v", first, err)
	}
	defer ln.Close()

	second, err := resolvePort(ctx, reg, "test-server", 20500)
	if err != nil {
		t.Fatalf("resolvePort (after the port was claimed): %v", err)
	}
	if second == first {
		t.Fatalf("resolvePort returned %d again even though it is now genuinely occupied", second)
	}
}

// TestExitCodesAreThreeValued builds the real binary and exercises rc 0 and
// rc 1 against real conditions; rc 2 (no free port anywhere in the 10000-port
// scan window) is not exercised here — occupying 10000 consecutive ports to
// prove it would be a disproportionately expensive, flaky test for a branch
// FindAvailablePort's own doc comment already states plainly (it returns 0
// on genuine exhaustion) and this command's exitUndetermined path passes
// that 0 straight through.
func TestExitCodesAreThreeValued(t *testing.T) {
	if _, err := exec.LookPath("go"); err != nil {
		t.Skip("no go toolchain on PATH; cannot build the binary under test")
	}
	bin := filepath.Join(t.TempDir(), "port-discover")
	build := exec.Command("go", "build", "-o", bin, ".")
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}

	t.Run("rc1_bad_usage_wrong_arg_count", func(t *testing.T) {
		if rc := runBin(t, bin, "only-one-arg"); rc != 1 {
			t.Fatalf("rc = %d, want 1", rc)
		}
	})

	t.Run("rc1_bad_usage_non_numeric_port", func(t *testing.T) {
		if rc := runBin(t, bin, "name", "not-a-port"); rc != 1 {
			t.Fatalf("rc = %d, want 1", rc)
		}
	})

	t.Run("rc0_resolves_and_prints_a_port", func(t *testing.T) {
		out, rc := runBinOut(t, bin,
			"-registry-dir", filepath.Join(t.TempDir(), "registry"),
			"e2e-test-server", "20600")
		if rc != 0 {
			t.Fatalf("rc = %d, want 0; output %q", rc, out)
		}
		port, err := strconv.Atoi(strings.TrimSpace(out))
		if err != nil || port < 1 || port > 65535 {
			t.Fatalf("stdout %q is not a valid port", out)
		}
	})
}

func listenOnAFreePort(t *testing.T) (int, net.Listener) {
	t.Helper()
	ln, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("could not bind an ephemeral port to set up the test: %v", err)
	}
	return ln.Addr().(*net.TCPAddr).Port, ln
}

func runBin(t *testing.T, bin string, args ...string) int {
	t.Helper()
	_, rc := runBinOut(t, bin, args...)
	return rc
}

func runBinOut(t *testing.T, bin string, args ...string) (string, int) {
	t.Helper()
	cmd := exec.Command(bin, args...)
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
