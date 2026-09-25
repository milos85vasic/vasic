// Command zg-chain is the Go half of the feature-010 evidence adapter (T013/T014).
//
// It is invoked by scripts/zero-gap-evidence.sh (append) and
// scripts/zero-gap-evidence-chain.sh (verify, history); it is not an operator
// entry point. The chain walk and the anchor comparison are NOT here — those
// are the upstream `continuum-integrity` verifier's. This tool owns only what
// that verifier cannot see: the sidecar and its binding to the chain.
//
//	zg-chain append  --store D --schema F --session S --cwd C --raw-row F
//	                 --stream-ref P --item-id ID --check-id ID
//	                 --population-kind K --verdict-role R --independence-tier T
//	                 --evidence-class E --fp-before H --fp-after H
//	                 --check-verdict 0|1|2 [--redacted-override]
//	                 [--exec-rows FILE] -- argv...
//	zg-chain verify  --store D --schema F
//	zg-chain history --chain F --anchor F [--witness-remote R] [--lock-timeout 120s]
//	zg-chain preflight --store D --schema F   (0 = the store may be extended)
//	zg-chain with-lock --store D (--shared|--exclusive) [--timeout 120s] -- argv...
//	zg-chain lock-fd --store D --fd N (--shared|--exclusive) [--timeout 120s]
//	zg-chain lock-held --store D --mode shared|exclusive   (0 = an inherited lock is held)
//	zg-chain argv-policy -- argv...   (0 = acceptable, 1 = secret-shaped, refused)
//
// verify, preflight and history take a SHARED flock on the store directory
// (append takes it EXCLUSIVE), waiting at most --lock-timeout for an
// in-progress append rather than reading its half-written state.
//
// Exit codes, three-valued everywhere: 0 holds (or appended), 1 violated,
// 2 could not determine (or not appended). `history` additionally exits 5 when
// the anchor has no committed history (NOT APPLICABLE) and 6 when the history
// is not witnessed by a remote-tracking copy (UNWITNESSED) — the caller
// decides whether either is acceptable, the tool never grants it silently.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	exitHolds    = 0
	exitViolated = 1
	exitUndet    = 2
	exitNA       = 5
	exitUnwit    = 6
)

const exitUnwitnessed = exitUnwit

func main() { os.Exit(run(os.Args[1:], os.Stdout, os.Stderr)) }

func run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "usage: zg-chain append|verify|history ... (see the package doc)")
		return exitUndet
	}
	switch args[0] {
	case "append":
		return cmdAppend(args[1:], stdout, stderr)
	case "verify":
		return cmdVerify(args[1:], stdout, stderr)
	case "history":
		return cmdHistory(args[1:], stdout, stderr)
	case "preflight":
		return cmdPreflight(args[1:], stdout, stderr)
	case "with-lock":
		return cmdWithLock(args[1:], stdout, stderr)
	case "lock-fd":
		return cmdLockFD(args[1:], stdout, stderr)
	case "lock-held":
		return cmdLockHeld(args[1:], stdout, stderr)
	case "argv-policy":
		return cmdArgvPolicy(args[1:], stdout, stderr)
	}
	fmt.Fprintf(stderr, "zg-chain: unknown subcommand %q\n", args[0])
	return exitUndet
}

func cmdAppend(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("append", flag.ContinueOnError)
	fs.SetOutput(stderr)
	var r AppendRequest
	var schema, rawRow, verdict string
	fs.StringVar(&r.StoreDir, "store", "", "store directory")
	fs.StringVar(&schema, "schema", "", "evidence-record contract")
	fs.StringVar(&r.Session, "session", "", "author session id")
	fs.StringVar(&r.Cwd, "cwd", "", "working directory the command ran in")
	fs.StringVar(&rawRow, "raw-row", "", "file holding the recorder's row")
	fs.StringVar(&r.StreamRef, "stream-ref", "", "final stream directory (outside VCS)")
	fs.StringVar(&r.ItemID, "item-id", "", "workable item id or SWEEP")
	fs.StringVar(&r.CheckID, "check-id", "", "check id")
	fs.StringVar(&r.PopulationKind, "population-kind", "", "source|process|wire")
	fs.StringVar(&r.VerdictRole, "verdict-role", "", "author|verifier")
	fs.StringVar(&r.IndependenceTier, "independence-tier", "", "instance|model|capability")
	fs.StringVar(&r.EvidenceClass, "evidence-class", "", "runtime|artifact|source")
	fs.StringVar(&r.FpBefore, "fp-before", "", "state fingerprint before")
	fs.StringVar(&r.FpAfter, "fp-after", "", "state fingerprint after")
	fs.StringVar(&verdict, "check-verdict", "", "the check's own 0|1|2")
	fs.BoolVar(&r.RedactedOverride, "redacted-override", false, "the adapter redacted a stream the recorder missed")
	fs.StringVar(&r.ExecRowsPath, "exec-rows", "", "strict-JSON FR-045 execution-row file to append to")
	fs.DurationVar(&r.LockTimeout, "lock-timeout", 120*time.Second, "bounded wait for the exclusive store lock (a timeout seals nothing)")
	if err := fs.Parse(args); err != nil {
		return exitUndet
	}
	r.Argv = fs.Args()
	v, err := strconv.Atoi(verdict)
	if err != nil || strconv.Itoa(v) != verdict {
		fmt.Fprintf(stderr, "zg-chain append: --check-verdict %q is not a canonical integer\n", verdict)
		return exitUndet
	}
	r.CheckVerdict = v
	if r.Schema, err = LoadSchema(schema); err != nil {
		fmt.Fprintf(stderr, "zg-chain append: %v\n", err)
		return exitUndet
	}
	rb, err := os.ReadFile(rawRow)
	if err != nil {
		fmt.Fprintf(stderr, "zg-chain append: reading the recorder row: %v\n", err)
		return exitUndet
	}
	// The file is private to one adapter invocation and holds exactly ONE
	// recorder row — which may span physical lines, because the recorder writes
	// `command` as "$*" unescaped. Only the recorder's own terminator is removed.
	rb = bytes.TrimSuffix(rb, []byte("\n"))
	if r.Raw, err = ParseRecorderRow(rb); err != nil {
		fmt.Fprintf(stderr, "zg-chain append: %v\n", err)
		return exitUndet
	}
	res, err := Append(r)
	if err != nil {
		fmt.Fprintf(stderr, "zg-chain append: NOT RECORDED / NOT SEALED: %v\n", err)
		return exitUndet
	}
	fmt.Fprintf(stdout, "APPENDED seq=%d outcome=%d artifact_path=%s recorder_row_strict_json=%t\n",
		res.Seq, res.Outcome, res.ArtifactPath, r.Raw.StrictJSON)
	return exitHolds
}

func cmdVerify(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("verify", flag.ContinueOnError)
	fs.SetOutput(stderr)
	store := fs.String("store", "", "store directory")
	schema := fs.String("schema", "", "evidence-record contract")
	lockWait := fs.Duration("lock-timeout", 120*time.Second, "bounded wait for an in-progress append")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 {
		return exitUndet
	}
	s, err := LoadSchema(*schema)
	if err != nil {
		fmt.Fprintf(stderr, "UNDETERMINED sidecar: %v\n", err)
		return exitUndet
	}
	if st, err := os.Stat(*store); err == nil && st.IsDir() {
		release, err := lockStore(*store, false, *lockWait)
		if err != nil {
			fmt.Fprintf(stdout, "UNDETERMINED sidecar: %v\n", err)
			return exitUndet
		}
		defer release()
	}
	rep, err := VerifyStore(*store, s)
	if err != nil {
		fmt.Fprintf(stdout, "UNDETERMINED sidecar: %v\n", err)
		return exitUndet
	}
	for _, f := range rep.Findings {
		fmt.Fprintf(stdout, "VIOLATED sidecar [%s] line %d: %s\n", f.Invariant, f.Line, f.Detail)
	}
	if len(rep.Findings) > 0 {
		return exitViolated
	}
	fmt.Fprintf(stdout, "HOLDS sidecar: %d record(s); every line binds its chain record by position, every adapter invariant holds\n", rep.Records)
	return exitHolds
}

func cmdHistory(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("history", flag.ContinueOnError)
	fs.SetOutput(stderr)
	ch := fs.String("chain", "", "chain file")
	an := fs.String("anchor", "", "anchor file")
	lockWait := fs.Duration("lock-timeout", 120*time.Second, "bounded wait for an in-progress append")
	remote := fs.String("witness-remote", "", "git remote witnessing the anchor history (default origin; an explicit name must be a configured remote)")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 || *ch == "" || *an == "" {
		return exitUndet
	}
	// Never carry on without the lock (review T015c): a history read against a
	// half-written chain is not a verdict.
	if st, err := os.Stat(filepath.Dir(*ch)); err == nil && st.IsDir() {
		release, err := lockStore(filepath.Dir(*ch), false, *lockWait)
		if err != nil {
			fmt.Fprintf(stdout, "history: UNDETERMINED %v\nUNDETERMINED history\n", err)
			return exitUndet
		}
		defer release()
	}
	opt := HistoryOptions{Remote: *remote, RemoteExplicit: *remote != ""}
	r := VerifyAnchorHistoryWith(*ch, *an, opt)
	for _, l := range r.Lines {
		fmt.Fprintf(stdout, "history: %s\n", l)
	}
	fmt.Fprintf(stdout, "%s history\n", r.Verdict)
	switch r.Verdict {
	case HistHolds:
		return exitHolds
	case HistViolated:
		return exitViolated
	case HistNotApplicable:
		return exitNA
	case HistUnwitnessed:
		return exitUnwitnessed
	}
	return exitUndet
}

func cmdPreflight(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("preflight", flag.ContinueOnError)
	fs.SetOutput(stderr)
	store := fs.String("store", "", "store directory")
	schema := fs.String("schema", "", "evidence-record contract")
	lockWait := fs.Duration("lock-timeout", 120*time.Second, "bounded wait for an in-progress append")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 || *store == "" {
		return exitUndet
	}
	s, err := LoadSchema(*schema)
	if err != nil {
		fmt.Fprintf(stderr, "zg-chain preflight: %v\n", err)
		return exitUndet
	}
	if st, err := os.Stat(*store); err == nil && st.IsDir() {
		release, err := lockStore(*store, false, *lockWait)
		if err != nil {
			fmt.Fprintf(stdout, "REFUSE preflight: %v\n", err)
			return exitUndet
		}
		defer release()
	}
	if err := Preflight(*store, s); err != nil {
		fmt.Fprintf(stdout, "REFUSE preflight: %v\n", err)
		return exitUndet
	}
	fmt.Fprintln(stdout, "OK preflight: the store may be extended")
	return exitHolds
}

// cmdWithLock runs a command while holding the store lock, so a multi-step
// shell operation (the four verify parts; anchor-write's verify-then-write; a
// whole adapter record from pre-flight to sealing) sees ONE consistent store
// (review T015b I2, T015c I2). The child inherits stdio and the LOCKED
// directory descriptor as fd 9 (ZG_LOCK_FD/ZG_LOCK_MODE), so zg-chain run by
// the child re-asserts that same lock instead of deadlocking on its holder,
// and a plain environment variable cannot stand in for it. The child is sent
// SIGKILL if this holder dies (PDEATHSIG), so it never runs on unlocked;
// TERM/INT/HUP are forwarded to it and its exit code is returned (a lock not
// obtained in time is exit 2, the child is then never started).
func cmdWithLock(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("with-lock", flag.ContinueOnError)
	fs.SetOutput(stderr)
	store := fs.String("store", "", "store directory")
	shared := fs.Bool("shared", false, "take a shared (reader) lock")
	exclusive := fs.Bool("exclusive", false, "take an exclusive (appender) lock")
	wait := fs.Duration("timeout", 120*time.Second, "bounded wait for the lock")
	if err := fs.Parse(args); err != nil || fs.NArg() == 0 || *store == "" || *shared == *exclusive {
		fmt.Fprintln(stderr, "usage: zg-chain with-lock --store D (--shared|--exclusive) [--timeout 120s] -- argv...")
		return exitUndet
	}
	l, err := acquireStoreLock(*store, *exclusive, *wait)
	if err != nil {
		fmt.Fprintf(stderr, "zg-chain with-lock: %v\n", err)
		return exitUndet
	}
	defer l.release()
	lf := l.f
	if lf == nil { // an inherited lock handed on to a grandchild
		lf = os.NewFile(uintptr(l.fd), *store)
	}
	mode := "shared"
	if l.exclusive {
		mode = "exclusive"
	}
	// PDEATHSIG is delivered when the THREAD that forked the child exits, so
	// the forking goroutine stays on one OS thread for the child's lifetime.
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	cmd := exec.Command(fs.Arg(0), fs.Args()[1:]...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, stdout, stderr
	cmd.ExtraFiles = make([]*os.File, lockFDNum-2)
	cmd.ExtraFiles[lockFDNum-3] = lf
	cmd.Env = append(envWithout(os.Environ(), lockFDEnv, lockModeEnv),
		lockFDEnv+"="+strconv.Itoa(lockFDNum), lockModeEnv+"="+mode)
	cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGKILL}
	sigs := make(chan os.Signal, 4)
	signal.Notify(sigs, syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP)
	defer signal.Stop(sigs)
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(stderr, "zg-chain with-lock: %v\n", err)
		return exitUndet
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	for {
		select {
		case sig := <-sigs:
			cmd.Process.Signal(sig)
		case err := <-done:
			if err == nil {
				return exitHolds
			}
			if ee, ok := err.(*exec.ExitError); ok {
				if ee.ExitCode() >= 0 {
					return ee.ExitCode()
				}
				if ws, ok := ee.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
					return 128 + int(ws.Signal())
				}
			}
			fmt.Fprintf(stderr, "zg-chain with-lock: %v\n", err)
			return exitUndet
		}
	}
}

func envWithout(env []string, names ...string) []string {
	out := env[:0:0]
	for _, e := range env {
		keep := true
		for _, n := range names {
			if strings.HasPrefix(e, n+"=") {
				keep = false
			}
		}
		if keep {
			out = append(out, e)
		}
	}
	return out
}

// cmdLockFD takes the store lock ON A DESCRIPTOR THE CALLER HOLDS OPEN (a
// shell's `exec {fd}<"$store"`), with a bounded wait, and exits. An flock
// belongs to the open file description, which the calling shell keeps: the
// lock therefore stays held until that shell closes the descriptor or dies —
// a SIGKILLed shell releases it; nothing can keep running on a stale lock.
// The shell exports ZG_LOCK_FD/ZG_LOCK_MODE so its zg-chain children
// re-assert the same lock (inheritedStoreLock). The descriptor must be the
// store directory (same device and inode). Exit 0 locked, 2 not locked.
func cmdLockFD(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("lock-fd", flag.ContinueOnError)
	fs.SetOutput(stderr)
	store := fs.String("store", "", "store directory")
	fd := fs.Int("fd", -1, "open descriptor of the store directory")
	shared := fs.Bool("shared", false, "shared (reader) lock")
	exclusive := fs.Bool("exclusive", false, "exclusive (appender) lock")
	wait := fs.Duration("timeout", 120*time.Second, "bounded wait for the lock")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 || *store == "" || *fd < 3 || *shared == *exclusive {
		fmt.Fprintln(stderr, "usage: zg-chain lock-fd --store D --fd N (--shared|--exclusive) [--timeout 120s]")
		return exitUndet
	}
	var fst, dst syscall.Stat_t
	if err := syscall.Fstat(*fd, &fst); err != nil {
		fmt.Fprintf(stderr, "zg-chain lock-fd: descriptor %d is not open: %v\n", *fd, err)
		return exitUndet
	}
	if err := syscall.Stat(*store, &dst); err != nil || fst.Dev != dst.Dev || fst.Ino != dst.Ino || fst.Mode&syscall.S_IFMT != syscall.S_IFDIR {
		fmt.Fprintf(stderr, "zg-chain lock-fd: descriptor %d is not the store directory %s\n", *fd, *store)
		return exitUndet
	}
	how := syscall.LOCK_SH
	if *exclusive {
		how = syscall.LOCK_EX
	}
	deadline := time.Now().Add(*wait)
	for {
		err := syscall.Flock(*fd, how|syscall.LOCK_NB)
		if err == nil {
			return exitHolds
		}
		if err != syscall.EWOULDBLOCK || time.Now().After(deadline) {
			fmt.Fprintf(stderr, "zg-chain lock-fd: the store lock on %s was not obtained within %s (another holder is in progress or stuck): %v\n", *store, *wait, err)
			return exitUndet
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// cmdLockHeld exits 0 when this process inherited a VALID store lock of at
// least the requested mode (the scripts use it to decide whether they already
// run under a holder), 1 otherwise. It never waits and never takes a new lock.
func cmdLockHeld(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("lock-held", flag.ContinueOnError)
	fs.SetOutput(stderr)
	store := fs.String("store", "", "store directory")
	mode := fs.String("mode", "shared", "shared|exclusive")
	if err := fs.Parse(args); err != nil || *store == "" || (*mode != "shared" && *mode != "exclusive") {
		return exitUndet
	}
	if _, ok, err := inheritedStoreLock(*store, *mode == "exclusive"); ok && err == nil {
		return exitHolds
	}
	return exitViolated
}

// cmdArgvPolicy exits 0 when the command line is acceptable, 1 (with the rule
// on stdout, never the value) when it is refused (ArgvPolicy).
func cmdArgvPolicy(args []string, stdout, stderr io.Writer) int {
	if len(args) > 0 && args[0] == "--" {
		args = args[1:]
	}
	if refused, why := ArgvPolicy(args); refused {
		fmt.Fprintln(stdout, why)
		return exitViolated
	}
	return exitHolds
}
