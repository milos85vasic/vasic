// Command port-discover answers ONE question — "what port should THIS named
// test/dev server bind to right now?" — by asking the canonical Containers
// Submodule's pkg/serviceregistry, never by trusting a hardcoded literal.
//
// WHY IT EXISTS.
//
// `_tests/env.js` (the vasic umbrella's Playwright port/base-URL derivation)
// used to fall back to hardcoded literals (8401, 8082, ...) when no
// VD_PORT/MV_PORT env var was set. A hardcoded fallback collides with
// whatever ELSE happens to be listening on that port on a given host (a
// concurrent checkout, an unrelated local service) and fails the whole gate
// with a bind error rather than picking a genuinely free port. The
// Containers Submodule's own CLAUDE.md lists "service discovery" and
// "endpoint discovery" among the capabilities a consuming project MUST
// consume rather than reimplement (§11.4.76(1) and (4)) — this command is a
// thin, shell-callable front for pkg/serviceregistry.ServiceRegistry, the
// same pattern cmd/runtime-probe already established for runtime.AutoDetect.
//
// SEMANTICS — discover-or-allocate, not "always allocate fresh".
//
//  1. If NAME is already registered in the shared, disk-persisted registry
//     AND its recorded port is CURRENTLY free to bind, that same port is
//     reused (stability across repeated runs — two consecutive test runs
//     bind the same port instead of churning through the range for no
//     reason).
//  2. Otherwise (never registered, or its recorded port is no longer free —
//     e.g. claimed by an unrelated process since the last run) a genuinely
//     free port is found via ServiceRegistry.FindAvailablePort(default),
//     and NAME is (re-)registered at that port.
//  3. The resolved port is printed to stdout, nothing else on success, so a
//     shell/Node caller can capture it directly.
//
// This is deliberately NOT pkg/serviceregistry's own Discover(): that method
// looks for a port a service is ALREADY LISTENING on (net.DialTimeout
// succeeds), which is the opposite of what a not-yet-started test webServer
// needs — it needs a port that is FREE to bind, which is FindAvailablePort's
// contract.
//
// The registry is persisted to a shared, umbrella-relative directory (not
// CWD-relative, which pkg/serviceregistry defaults to) so that ANY process —
// Go or otherwise, since the registry file is plain JSON — can discover
// which port a named service resolved to, by name, without re-running this
// command. That shared, readable-by-anything registry is the "full
// discovery capabilities from dependent services" this command exists to
// provide.
//
// EXIT CODES are three-valued, as every check in this tree is:
//
//	0  a port was resolved (reused or freshly allocated) and printed
//	1  a real failure (bad usage, registry unwritable)
//	2  COULD NOT DETERMINE — no free port found in range
//
// CROSS-PROCESS LOCKING (added 2026-09-19 — root cause + fix for a live race).
//
// Two independent subagents, working on unrelated tasks the same day, each
// separately observed net::ERR_CONNECTION_REFUSED at a discovered port while
// multiple Claude Code sessions ran the Playwright suite concurrently against
// the same checkout, and both flagged it as a race in reading/writing the
// shared `.service-registry/services.json` file. Root cause, confirmed by a
// reproduction in concurrency_race_test.go (this package):
// `pkg/serviceregistry.ServiceRegistry` (submodules/containers,
// reviewed 2026-09-19) protects its OWN in-memory state with r.mu/persistMu,
// but each OS process running this binary constructs its OWN fresh
// `*ServiceRegistry` via New() — a separate in-memory map loaded once from
// disk with no re-read before persist() overwrites the shared file. Two
// concrete, reproduced failure shapes follow directly from that:
//
//  1. loadFromDisk()'s crash-recovery reaper (SR2-3, reapOrphanedTempFiles)
//     globs and deletes any `services-*.json.tmp` file on EVERY New() call,
//     with no way to tell "orphaned from a crashed process" apart from
//     "being actively written by a concurrent, live process right now". A
//     second process's New() can delete a first process's in-flight temp
//     file out from under it, so the first process's persist() then fails
//     outright: `rename ... services-NNNN.json.tmp ...: no such file or
//     directory`. Register() propagates that as an error (SR-HARD-3), so
//     resolvePort returns an error, run() reports exitUndetermined, and
//     env.js's discoverPortRaw() (its caller) falls back to the hardcoded
//     literal port on ANY non-zero exit — silently re-introducing exactly
//     the collision-with-whatever-else-is-listening class this whole
//     discovery mechanism exists to avoid.
//  2. Even absent a hard failure, two processes whose New() both loaded the
//     registry before either had persisted can each persist() a snapshot
//     that is missing the other's just-written registration — a classic
//     last-writer-wins lost update, since persist() always writes
//     r.services wholesale rather than merging against whatever is on disk
//     right now.
//
// Neither hazard is fixable by anything internal to a single
// *ServiceRegistry instance, because the defect is that DIFFERENT instances,
// in different processes, are not coordinated at all. This binary is the
// SOLE writer of `.service-registry/services.json` in this repository (env.js
// only ever shells out to it; nothing else imports pkg/serviceregistry
// against this directory — verified 2026-09-19), so the fix belongs here,
// at the consumption layer: acquire an exclusive, cross-process advisory file
// lock (flock(2), via golang.org/x/sys/unix — already an indirect dependency
// of this module, so no new external dependency) on a dedicated lockfile
// inside the registry directory, held for the ENTIRE
// New()-through-Register() sequence. That makes the whole
// load-decide-persist cycle atomic with respect to every other invocation of
// this binary against the same directory, which closes BOTH hazards above:
// no New() can run its reaper while another process's persist() has an
// in-flight temp file, and no persist() can run against a stale snapshot
// while another process's write is landing. flock is held via the file
// descriptor, not a PID, so a crashed holder can never wedge a future
// invocation — the kernel releases the lock the moment the fd is closed
// (including on process death), unlike a stale-PID lockfile scheme.
package main

import (
	"context"
	"flag"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"digital.vasic.containers/pkg/serviceregistry"
	"golang.org/x/sys/unix"
)

const (
	exitOK           = 0
	exitFail         = 1
	exitUndetermined = 2
)

func main() { os.Exit(run(os.Args[1:], os.Stdout, os.Stderr)) }

func run(args []string, stdout, stderr *os.File) int {
	fs := flag.NewFlagSet("port-discover", flag.ContinueOnError)
	fs.SetOutput(stderr)
	var (
		flagRegistryDir = fs.String("registry-dir", "",
			"Shared registry directory (default: $VASIC_ROOT/.service-registry, "+
				"resolved from this binary's own working directory's git toplevel)")
		flagTimeout = fs.Duration("timeout", 5*time.Second,
			"Wall-clock budget for the free-port scan")
		flagUDP = fs.Bool("udp", false,
			"Also require the port to be free on UDP (HTTPS + HTTP/3 bind one port on both)")
	)
	if err := fs.Parse(args); err != nil {
		return exitFail
	}
	if fs.NArg() != 2 {
		fmt.Fprintf(stderr, "usage: port-discover [-registry-dir DIR] [-udp] NAME DEFAULT_PORT\n")
		return exitFail
	}
	name := fs.Arg(0)
	defaultPort, err := strconv.Atoi(fs.Arg(1))
	if err != nil || defaultPort < 1 || defaultPort > 65535 {
		fmt.Fprintf(stderr, "port-discover: DEFAULT_PORT %q is not a valid TCP port (1-65535)\n", fs.Arg(1))
		return exitFail
	}

	dir := *flagRegistryDir
	if dir == "" {
		dir = defaultRegistryDir()
	}

	// Acquire the cross-process lock BEFORE constructing the registry (see
	// the package-level "CROSS-PROCESS LOCKING" doc above): New() itself
	// reads the directory (loadFromDisk + the orphaned-temp-file reaper), so
	// the lock must cover that too, not just the later Register() call, or a
	// second process's New() could still run its reaper concurrently with a
	// first process's in-flight persist().
	unlock, err := acquireRegistryLock(dir)
	if err != nil {
		fmt.Fprintf(stderr, "port-discover: could not acquire cross-process registry lock in %s: %v\n", dir, err)
		return exitFail
	}
	defer unlock()

	reg := serviceregistry.New(serviceregistry.WithRegistryDir(dir))

	ctx, cancel := context.WithTimeout(context.Background(), *flagTimeout)
	defer cancel()

	port, err := resolvePortWith(ctx, reg, name, defaultPort, *flagUDP)
	if err != nil {
		fmt.Fprintf(stderr, "port-discover: COULD NOT DETERMINE a free port for %q near %d: %v\n",
			name, defaultPort, err)
		return exitUndetermined
	}

	fmt.Fprintln(stdout, port)
	return exitOK
}

// resolvePort implements the discover-or-allocate semantics documented in
// the package comment above.
func resolvePort(ctx context.Context, reg *serviceregistry.ServiceRegistry, name string, defaultPort int) (int, error) {
	return resolvePortWith(ctx, reg, name, defaultPort, false)
}

// resolvePortWith is resolvePort with an optional UDP requirement. needUDP is
// for servers that bind ONE port on TCP AND UDP (HTTPS + HTTP/3 advertise the
// TCP port as the QUIC endpoint): FindAvailablePort tests TCP only, so without
// this a port whose UDP side is held was handed out and the server came up
// HTTP-only (measured 2026-09-22). With needUDP, a candidate — including the
// name's own registered port — qualifies only if it is free on both.
func resolvePortWith(ctx context.Context, reg *serviceregistry.ServiceRegistry, name string, defaultPort int, needUDP bool) (int, error) {
	if svc, ok := reg.Get(name); ok && isFreeToBind(svc.Host, svc.Port) && (!needUDP || isUDPFree(svc.Host, svc.Port)) {
		return svc.Port, nil
	}

	// FindAvailablePort tests only the SOCKET. A port can be free to bind yet
	// claimed in the registry by ANOTHER name whose process has exited — and
	// Register (SR2-4) rightly refuses to hand it out twice. So a candidate
	// claimed by another name is skipped here, and the claim is left intact;
	// without this, one stale claim made the whole lookup fail (measured
	// 2026-09-22: 8401 claimed by vasic-tests-vd_port blocked scripts/qa-up.sh).
	claimed := map[int]bool{}
	for otherName, svc := range reg.GetAll() {
		if otherName != name {
			claimed[svc.Port] = true
		}
	}
	limit := defaultPort + 10000
	free := 0
	for start := defaultPort; start < limit; {
		if err := ctx.Err(); err != nil {
			return 0, err
		}
		candidate := reg.FindAvailablePort(start)
		if candidate == 0 || candidate >= limit {
			break
		}
		if !claimed[candidate] && (!needUDP || isUDPFree("", candidate)) {
			free = candidate
			break
		}
		start = candidate + 1
	}
	if free == 0 {
		return 0, fmt.Errorf("no free, unclaimed port found in [%d, %d)", defaultPort, limit)
	}
	select {
	case <-ctx.Done():
		return 0, ctx.Err()
	default:
	}
	if err := reg.Register(name, free); err != nil {
		return 0, fmt.Errorf("register %s at port %d: %w", name, free, err)
	}
	return free, nil
}

// isUDPFree reports whether a UDP socket can bind host:port right now (bind,
// then immediately close — the same probe isFreeToBind uses for TCP).
func isUDPFree(host string, port int) bool {
	if host == "" {
		host = "localhost"
	}
	pc, err := net.ListenPacket("udp", net.JoinHostPort(host, strconv.Itoa(port)))
	if err != nil {
		return false
	}
	_ = pc.Close()
	return true
}

// isFreeToBind mirrors serviceregistry's own isPortAvailable check (bind,
// then immediately close) rather than importing an unexported method.
func isFreeToBind(host string, port int) bool {
	if host == "" {
		host = "localhost"
	}
	ln, err := net.Listen("tcp", net.JoinHostPort(host, strconv.Itoa(port)))
	if err != nil {
		return false
	}
	_ = ln.Close()
	return true
}

// defaultRegistryDir walks up from the current working directory looking for
// a `.git` entry (file or directory — a submodule's `.git` is a file) to
// find the umbrella root, mirroring find_constitution.sh's own parent-walk
// technique rather than hardcoding a depth-dependent relative path. Falls
// back to the current working directory's own `.service-registry` if no
// `.git` is found (e.g. this binary is ever run outside any checkout).
func defaultRegistryDir() string {
	dir, err := os.Getwd()
	if err != nil {
		return ".service-registry"
	}
	cur := dir
	for {
		if _, err := os.Stat(filepath.Join(cur, ".git")); err == nil {
			return filepath.Join(cur, ".service-registry")
		}
		parent := filepath.Dir(cur)
		if parent == cur {
			break
		}
		cur = parent
	}
	return filepath.Join(dir, ".service-registry")
}

// acquireRegistryLock takes an exclusive, blocking, cross-process advisory
// file lock (flock(2)) on a dedicated lockfile inside dir, and returns a
// function that releases it. See the package-level "CROSS-PROCESS LOCKING"
// doc comment above for why this exists and exactly what it closes.
//
// A DEDICATED lockfile (".port-discover.lock"), never services.json itself:
// pkg/serviceregistry's own persist() opens services.json only via
// os.CreateTemp + os.Rename — it never flocks services.json — so flocking
// that path would protect nothing (a concurrent persist() would not
// participate in the same lock) and would also fight the atomic-rename
// replacement, which swaps the underlying inode out from under any fd
// holding a lock on it. A separate, stable file is immune to both problems:
// it is never replaced, so a lock held on its fd remains meaningful for as
// long as this process holds it.
//
// BLOCKING (LOCK_EX, no LOCK_NB): correctness over latency here. Every
// resolvePort call this binary makes is a handful of syscalls plus at most a
// 10000-port bind/close scan — milliseconds, not seconds — so a contending
// process waits briefly rather than needing its own timeout/retry policy.
// *flagTimeout already bounds the free-port scan itself once the lock is
// held; it is not meant to bound queueing for the lock.
//
// CRASH SAFETY: flock is associated with the open file DESCRIPTION, not a
// PID recorded in the file's contents, so the kernel releases it
// automatically the instant the holding process's file descriptor is closed
// — including on a crash or SIGKILL. Unlike a stale-PID lockfile scheme,
// there is no way for a dead holder to wedge every future invocation.
func acquireRegistryLock(dir string) (unlock func(), err error) {
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("create registry dir: %w", err)
	}
	lockPath := filepath.Join(dir, ".port-discover.lock")
	f, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return nil, fmt.Errorf("open lock file %s: %w", lockPath, err)
	}
	if err := unix.Flock(int(f.Fd()), unix.LOCK_EX); err != nil {
		_ = f.Close()
		return nil, fmt.Errorf("flock %s: %w", lockPath, err)
	}
	return func() {
		_ = unix.Flock(int(f.Fd()), unix.LOCK_UN)
		_ = f.Close()
	}, nil
}
