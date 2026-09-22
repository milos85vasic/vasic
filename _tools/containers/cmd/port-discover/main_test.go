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
	"os"
	"runtime"
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
	goBin := goTool(t)
	bin := filepath.Join(t.TempDir(), "port-discover")
	build := exec.Command(goBin, "build", "-o", bin, ".")
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

// TestResolvePort_SkipsAPortClaimedByAnotherNameInTheRegistry reproduces the
// 2026-09-22 live failure: 8401 was free to BIND but the shared registry
// recorded it as claimed by "vasic-tests-vd_port" (a Playwright run that had
// exited). FindAvailablePort only tests the socket, so it proposed 8401;
// Register refused it (SR2-4); resolvePort returned an error and qa-up.sh
// could not boot at all. A port claimed by ANOTHER name must be skipped, and
// the claimant's entry must be left exactly as it was.
func TestResolvePort_SkipsAPortClaimedByAnotherNameInTheRegistry(t *testing.T) {
	ctx := context.Background()
	reg := serviceregistry.New(serviceregistry.WithRegistryDir(t.TempDir()))
	const claimed = 20700
	if err := reg.Register("some-other-service", claimed); err != nil {
		t.Fatalf("seeding the other claim: %v", err)
	}

	got, err := resolvePort(ctx, reg, "qa-server", claimed)
	if err != nil {
		t.Fatalf("resolvePort must skip a claimed port, not fail: %v", err)
	}
	if got == claimed {
		t.Fatalf("resolvePort returned %d, which is claimed by another name", got)
	}
	other, ok := reg.Get("some-other-service")
	if !ok || other.Port != claimed {
		t.Fatalf("the other name's claim was disturbed: %+v (ok=%v)", other, ok)
	}
}

// errOnlyCtx reports cancellation through Err() while its Done() channel never
// fires. Only code that consults ctx.Err() inside the scan loop can observe
// it; the post-scan `select { case <-ctx.Done() }` cannot — which is what
// makes this test able to fail when the in-loop check is removed.
type errOnlyCtx struct{ context.Context }

func (errOnlyCtx) Err() error { return context.Canceled }

// TestResolvePort_ScanLoopConsultsTheContext: the -timeout budget must stop
// the claimed-port skip loop itself, not only be checked after the scan.
func TestResolvePort_ScanLoopConsultsTheContext(t *testing.T) {
	reg := serviceregistry.New(serviceregistry.WithRegistryDir(t.TempDir()))
	ctx := errOnlyCtx{context.Background()}
	if _, err := resolvePort(ctx, reg, "qa-server", 20800); !errors.Is(err, context.Canceled) {
		t.Fatalf("want context.Canceled from the scan loop, got %v", err)
	}
	if _, ok := reg.Get("qa-server"); ok {
		t.Fatal("a cancelled lookup must not register anything")
	}
}

// TestResolvePortWith_UDPRequirementSkipsAPortWhoseUDPSideIsHeld reproduces the
// 2026-09-22 sandbox measurement: an HTTPS+HTTP/3 server needs ONE port free on
// TCP AND UDP; port-discover checked TCP only, so it handed out a port whose
// UDP side was held, and the server came up HTTP-only (tls_error). With the
// UDP requirement that port must be skipped; without it (control) the same
// port is still returned, proving the hold does not touch TCP.
func TestResolvePortWith_UDPRequirementSkipsAPortWhoseUDPSideIsHeld(t *testing.T) {
	ctx := context.Background()
	held, err := net.ListenPacket("udp", "localhost:0")
	if err != nil {
		t.Fatalf("holding a UDP port: %v", err)
	}
	defer held.Close()
	port := held.LocalAddr().(*net.UDPAddr).Port

	ctrl := serviceregistry.New(serviceregistry.WithRegistryDir(t.TempDir()))
	got, err := resolvePortWith(ctx, ctrl, "tcp-only", port, false)
	if err != nil || got != port {
		t.Skipf("control could not get TCP port %d (got %d, err %v) — host race, not a verdict", port, got, err)
	}

	reg := serviceregistry.New(serviceregistry.WithRegistryDir(t.TempDir()))
	got, err = resolvePortWith(ctx, reg, "needs-udp", port, true)
	if err != nil {
		t.Fatalf("resolvePortWith(udp): %v", err)
	}
	if got == port {
		t.Fatalf("returned %d although its UDP side is held", port)
	}
}

// TestResolvePortWith_UDPRequirementReallocatesARegisteredPortWhoseUDPIsHeld:
// the same-name reuse shortcut must also honour the UDP requirement.
func TestResolvePortWith_UDPRequirementReallocatesARegisteredPortWhoseUDPIsHeld(t *testing.T) {
	ctx := context.Background()
	reg := serviceregistry.New(serviceregistry.WithRegistryDir(t.TempDir()))
	first, err := resolvePortWith(ctx, reg, "needs-udp", 20900, true)
	if err != nil {
		t.Fatalf("first: %v", err)
	}
	held, err := net.ListenPacket("udp", net.JoinHostPort("localhost", strconv.Itoa(first)))
	if err != nil {
		t.Skipf("could not hold UDP %d: %v", first, err)
	}
	defer held.Close()
	second, err := resolvePortWith(ctx, reg, "needs-udp", 20900, true)
	if err != nil {
		t.Fatalf("second: %v", err)
	}
	if second == first {
		t.Fatalf("reused registered port %d although its UDP side is now held", first)
	}
}

// goTool locates the Go toolchain that is running this test. `go test` IS the
// toolchain, so it can always be found — on PATH, or under runtime.GOROOT()
// when the test binary was launched with a PATH that lacks it. Not finding it
// means the environment is broken, which is a FAILURE to report, not a reason
// to SKIP (a skip here was counted by the zero-findings sweep as a skipped
// test, and it could only ever hide that breakage).
func goTool(t *testing.T) string {
	t.Helper()
	if p, err := exec.LookPath("go"); err == nil {
		return p
	}
	p := filepath.Join(runtime.GOROOT(), "bin", "go") //nolint:staticcheck // GOROOT of the running toolchain is exactly what is wanted here
	if _, err := os.Stat(p); err == nil {
		return p
	}
	t.Fatalf("go test is running but no go toolchain can be located (not on PATH, not at %s)", p)
	return ""
}
