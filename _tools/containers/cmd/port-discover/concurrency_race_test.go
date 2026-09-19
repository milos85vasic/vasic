package main

// TestConcurrentRegistrationsAcrossSeparateRegistryInstances_NoLostWrites and
// TestConcurrentSameNameRegistration_ConvergesOnOnePort are the minimal, fast,
// deterministic reproduction of the race two independent subagents observed
// live (2026-09-19) while multiple Claude Code sessions were concurrently
// running the Playwright suite against the same checkout: net::
// ERR_CONNECTION_REFUSED at a discovered port, traced to a race in
// reading/writing the shared, disk-persisted `.service-registry/services.json`
// file when multiple OS PROCESSES discover or register ports at the same
// time.
//
// WHY THESE CALL run(), NOT resolvePort() DIRECTLY.
//
// Both tests drive the package's real entry point, run() — the exact function
// main() calls — rather than constructing a *serviceregistry.ServiceRegistry
// and calling resolvePort() themselves. That distinction is load-bearing: the
// fix (acquireRegistryLock in main.go) lives INSIDE run(), wrapped around
// serviceregistry.New() and resolvePort() together. A test that called
// resolvePort() directly, bypassing run(), would bypass the fix entirely and
// prove nothing about it either way.
//
// WHY GOROUTINES CALLING run() FAITHFULLY SIMULATE SEPARATE OS PROCESSES.
//
// Every real invocation of this binary is a separate OS process, hence a
// separate `*ServiceRegistry` (New()'s loadFromDisk() runs once, with no
// re-read before persist() overwrites the file) and, after the fix, a
// separate flock(2) file descriptor. flock's exclusion is associated with the
// OPEN FILE DESCRIPTION (i.e. the specific os.OpenFile call), not with the
// process — two goroutines in the SAME OS process that each independently
// open the lock file get two independent descriptions, and the kernel
// enforces mutual exclusion between them exactly as it would across two
// separate processes. So calling run() concurrently from N goroutines, each
// with its own -registry-dir pointed at the same shared directory, reproduces
// the real race (and proves the real fix) with full fidelity, while staying
// in-process — no fork/exec overhead, no browser, no network, deterministic
// to control, and well under a second to run.
import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
)

// runOnce invokes run() with fresh, isolated stdout/stderr temp files
// (run()'s signature requires *os.File, not just io.Writer) and returns the
// exit code plus captured stdout/stderr as strings.
//
// Deliberately takes NO *testing.T: this is called from spawned goroutines in
// the tests below, and testing.T's Fatal family "must be called from the
// goroutine running the Test function" (per the stdlib docs) — calling it
// from another goroutine is itself a bug, so setup failures here are
// returned as a plain error for the caller (the main test goroutine, after
// wg.Wait()) to report.
func runOnce(args []string) (rc int, stdout, stderr string, setupErr error) {
	outFile, err := os.CreateTemp("", "port-discover-race-stdout-*")
	if err != nil {
		return 0, "", "", fmt.Errorf("create stdout capture file: %w", err)
	}
	defer os.Remove(outFile.Name())
	defer outFile.Close()
	errFile, err := os.CreateTemp("", "port-discover-race-stderr-*")
	if err != nil {
		return 0, "", "", fmt.Errorf("create stderr capture file: %w", err)
	}
	defer os.Remove(errFile.Name())
	defer errFile.Close()

	rc = run(args, outFile, errFile)

	outBytes, _ := os.ReadFile(outFile.Name())
	errBytes, _ := os.ReadFile(errFile.Name())
	return rc, string(outBytes), string(errBytes), nil
}

func TestConcurrentRegistrationsAcrossSeparateRegistryInstances_NoLostWrites(t *testing.T) {
	dir := t.TempDir()
	const n = 40

	type result struct {
		name     string
		rc       int
		port     int
		stderr   string
		setupErr error
	}
	results := make([]result, n)

	var wg sync.WaitGroup
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func(i int) {
			defer wg.Done()
			name := fmt.Sprintf("race-svc-%02d", i)
			// Each goroutine's own default-port range is disjoint from every
			// other's (200 apart), so the ONLY shared resource in contention
			// is the registry directory/lock/file itself — never a real TCP
			// port.
			defaultPort := 21000 + i*200

			rc, stdout, stderr, setupErr := runOnce([]string{
				"-registry-dir", dir, name, strconv.Itoa(defaultPort),
			})
			port := 0
			if setupErr == nil && rc == 0 {
				port, _ = strconv.Atoi(strings.TrimSpace(stdout))
			}
			results[i] = result{name: name, rc: rc, port: port, stderr: stderr, setupErr: setupErr}
		}(i)
	}
	wg.Wait()

	for _, r := range results {
		if r.setupErr != nil {
			t.Fatalf("test setup failure for %s: %v", r.name, r.setupErr)
		}
		if r.rc != 0 {
			t.Errorf("run() for %s exited %d (want 0): stderr=%q", r.name, r.rc, r.stderr)
		}
	}

	// No leftover *.tmp file — persist()'s temp-then-rename must always
	// either complete (rename lands) or clean up after itself; a survivor
	// here would mean a write was interrupted mid-flight rather than merely
	// raced.
	tmpLeftovers, _ := filepath.Glob(filepath.Join(dir, "services-*.json.tmp"))
	if len(tmpLeftovers) != 0 {
		t.Fatalf("found %d leftover temp registry file(s): %v", len(tmpLeftovers), tmpLeftovers)
	}

	raw, err := os.ReadFile(filepath.Join(dir, "services.json"))
	if err != nil {
		t.Fatalf("reading final services.json: %v", err)
	}
	var onDisk map[string]struct {
		Port int `json:"port"`
	}
	if err := json.Unmarshal(raw, &onDisk); err != nil {
		t.Fatalf("final services.json is not valid JSON (corrupted): %v\n--- raw content ---\n%s", err, raw)
	}

	var missing []string
	var wrongPort []string
	for _, r := range results {
		if r.rc != 0 {
			continue // already reported above
		}
		got, ok := onDisk[r.name]
		if !ok {
			missing = append(missing, r.name)
			continue
		}
		if got.Port != r.port {
			wrongPort = append(wrongPort, fmt.Sprintf("%s: run() printed %d but registry has %d", r.name, r.port, got.Port))
		}
	}

	if len(missing) > 0 || len(wrongPort) > 0 {
		t.Fatalf(
			"lost/incorrect registrations after %d concurrent registrations from separate run() invocations "+
				"(the exact class of race reported live): on-disk registry has %d/%d entries; "+
				"missing=%v; wrongPort=%v; this is the read-modify-write race in persist() — "+
				"a later process's snapshot, loaded before an earlier process's write landed, "+
				"overwrote the file and dropped the earlier registration",
			n, len(onDisk), n, missing, wrongPort,
		)
	}
}

// TestConcurrentSameNameRegistration_ConvergesOnOnePort is the SAME-NAME shape
// explicitly asked for alongside the above: N concurrent callers asking for
// the identical service name must converge on ONE port, with no corrupted
// registry file and no failed invocation.
func TestConcurrentSameNameRegistration_ConvergesOnOnePort(t *testing.T) {
	dir := t.TempDir()
	const n = 24
	const name = "race-shared-svc"
	const defaultPort = 22800

	type result struct {
		rc       int
		port     int
		stderr   string
		setupErr error
	}
	results := make([]result, n)

	var wg sync.WaitGroup
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func(i int) {
			defer wg.Done()
			rc, stdout, stderr, setupErr := runOnce([]string{
				"-registry-dir", dir, name, strconv.Itoa(defaultPort),
			})
			port := 0
			if setupErr == nil && rc == 0 {
				port, _ = strconv.Atoi(strings.TrimSpace(stdout))
			}
			results[i] = result{rc: rc, port: port, stderr: stderr, setupErr: setupErr}
		}(i)
	}
	wg.Wait()

	for i, r := range results {
		if r.setupErr != nil {
			t.Fatalf("test setup failure for call #%d: %v", i, r.setupErr)
		}
		if r.rc != 0 {
			t.Fatalf("run() call #%d exited %d (want 0): stderr=%q", i, r.rc, r.stderr)
		}
	}

	first := results[0].port
	var divergent []string
	for i, r := range results {
		if r.port != first {
			divergent = append(divergent, fmt.Sprintf("call#%d=%d", i, r.port))
		}
	}
	if len(divergent) > 0 {
		var all []int
		for _, r := range results {
			all = append(all, r.port)
		}
		t.Fatalf("concurrent run() calls for the SAME name %q did not converge on one port: "+
			"first=%d, divergent=%v (all ports: %v)", name, first, divergent, all)
	}

	raw, err := os.ReadFile(filepath.Join(dir, "services.json"))
	if err != nil {
		t.Fatalf("reading final services.json: %v", err)
	}
	var onDisk map[string]struct {
		Port int `json:"port"`
	}
	if err := json.Unmarshal(raw, &onDisk); err != nil {
		t.Fatalf("final services.json is not valid JSON (corrupted): %v\n--- raw content ---\n%s", err, raw)
	}
	svc, ok := onDisk[name]
	if !ok {
		t.Fatalf("service %q missing from final registry entirely after %d concurrent registrations", name, n)
	}
	if svc.Port != first {
		t.Fatalf("registry has port %d for %q but callers converged on %d", svc.Port, name, first)
	}
}
