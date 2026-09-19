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
	)
	if err := fs.Parse(args); err != nil {
		return exitFail
	}
	if fs.NArg() != 2 {
		fmt.Fprintf(stderr, "usage: port-discover [-registry-dir DIR] NAME DEFAULT_PORT\n")
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

	reg := serviceregistry.New(serviceregistry.WithRegistryDir(dir))

	ctx, cancel := context.WithTimeout(context.Background(), *flagTimeout)
	defer cancel()

	port, err := resolvePort(ctx, reg, name, defaultPort)
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
	if svc, ok := reg.Get(name); ok && isFreeToBind(svc.Host, svc.Port) {
		return svc.Port, nil
	}

	free := reg.FindAvailablePort(defaultPort)
	if free == 0 {
		return 0, fmt.Errorf("no free port found in [%d, %d)", defaultPort, defaultPort+10000)
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
