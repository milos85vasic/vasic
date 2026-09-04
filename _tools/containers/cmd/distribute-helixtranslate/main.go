// Command distribute-helixtranslate builds the HelixTranslate engine image on a
// remote build host and distributes it to the translation worker host, driving
// every SSH and SCP operation through the canonical Containers Submodule
// (`digital.vasic.containers`) as §11.4.76 requires.
//
// It replaces the hand-rolled `_tools/distribute-helixtranslate.sh`, which
// spawned raw `ssh`, `scp` and `rsync` processes itself — a §11.4.76(4)
// violation, because the module owns remote execution and a consuming project
// may not reimplement it.
//
// # ⚠️  UNVERIFIED AGAINST A REAL REMOTE — READ THIS BEFORE TRUSTING IT
//
// This program has NEVER been run end to end against a live host. It was
// written on 2026-09-03 on a machine from which BOTH target hosts were
// measured unreachable:
//
//	ssh -o BatchMode=yes -o ConnectTimeout=8 milosvasic@thinker.local ...
//	  -> ssh: Could not resolve hostname thinker.local: Name or service not known   (rc 255)
//	ssh -o BatchMode=yes -o ConnectTimeout=8 milosvasic@amber.local ...
//	  -> ssh: Could not resolve hostname amber.local: Name or service not known     (rc 255)
//
// That is a measured absence, not a broken resolver: avahi-daemon was active,
// `hosts:` in /etc/nsswitch.conf carries mdns_minimal, and `avahi-browse -at`
// on the same interface enumerated many other devices on the same /24 in the
// same minute. Neither target answered mDNS and neither had an entry in the
// ARP cache.
//
// So: this file COMPILES and `go vet` is clean, its argument construction is
// unit-tested, and its reachability preflight is exercised against a host that
// does not exist. NOTHING BEYOND THAT IS CLAIMED. The build, the image
// replication, the seeding and the verification steps have never executed
// against a real podman or docker daemon. Treat the first live run as a test,
// not as a deployment, and run it with -probe first.
//
// # What the module provides, and what it does NOT
//
// Measured against the module at gitlink d940b51fc247c285c805799452992da8d09c75b9.
// This matters, because the brief for this conversion assumed `cmd/deploy-stack`,
// `pkg/remote` and `pkg/distribution` already did all of it. They do not.
//
// PRESENT, and used here for every remote interaction:
//
//	remote.NewSSHExecutor          -> pooled, ControlMaster-multiplexed SSH
//	RemoteExecutor.IsReachable     -> the preflight
//	RemoteExecutor.Execute         -> a remote command + its real exit code
//	RemoteExecutor.ExecuteStream   -> streaming stdout (the image save)
//	RemoteExecutor.CopyFile/CopyDir-> scp, with argument-injection guards
//	remoteexec.SSHRunner.WriteFile -> upload + chmod in one call (mode 0600)
//
// ABSENT from the module — verified by reading every exported symbol in
// pkg/runtime, pkg/remote, pkg/distribution and pkg/remoteexec:
//
//	image build on a remote host        (only compose `up -d --build` exists)
//	image save / load / tag             (no such API anywhere)
//	image transfer between two hosts    (no such API anywhere)
//	`run` with volume mounts            (ContainerRuntime.Start takes a
//	                                     CONTAINER id, never an image; the
//	                                     distributor's `run -d` builder is
//	                                     unexported and supports only
//	                                     --name/-p/image)
//	named-volume create                 (pkg/volume is SSHFS/NFS host-path
//	                                     mounting, not container volumes)
//	remote -> local file fetch          (CopyFile/CopyDir are local -> remote
//	                                     only)
//
// Those five steps are therefore composed here as command strings and handed to
// RemoteExecutor.Execute. That is NOT a reimplementation of the module: the
// transport, quoting, pooling, timeouts and exit-code handling are all the
// module's. But it is an honest gap, and it should be closed upstream rather
// than copied into the next consumer.
//
// # One deliberate behavioural change from the bash it replaces
//
// The bash replicated the image with `ssh A 'podman save' | ssh B 'docker load'`,
// a local pipe joining two SSH processes so the bytes never touched this
// machine's disk. The module has no remote->local fetch and no way to feed one
// remote command's stdout into another's stdin, so this program streams the
// save to a LOCAL temp file and then scp's it up. The image is ~20 MB
// (_analysis/CONTAINER-DISTRIBUTION.md), so the extra hop is cheap — but it IS
// an extra hop, and on a multi-GB image it would not be.
//
// # Anti-bluff contract (§11.4, §1.1)
//
// A zero exit from a remote command is not evidence that anything was
// distributed. Every run finishes by executing the image on BOTH hosts and
// requiring non-empty version output. A step that cannot be checked is reported
// as COULD NOT DETERMINE, never as success.
//
// # Exit codes — three-valued, as every check in this tree is
//
//	0  the image was built, replicated, seeded AND verified to run on both hosts
//	1  a real failure: a remote command failed, or the verification came back empty
//	2  COULD NOT DETERMINE — a host is unreachable, or a precondition is absent.
//	   NEVER a pass.
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

	"digital.vasic.containers/pkg/logging"
	"digital.vasic.containers/pkg/remote"
	"digital.vasic.containers/pkg/remoteexec"
)

// Exit codes. Three-valued by project convention: 2 is COULD NOT DETERMINE and
// is never a pass.
const (
	exitOK           = 0
	exitFail         = 1
	exitUndetermined = 2
)

// secretEnvKeys are the LLM provider keys copied into the remote env file.
// Their VALUES are never logged, never passed on a command line, and never
// written anywhere but the mode-0600 remote file.
var secretEnvKeys = []string{
	"MISTRAL_API_KEY",
	"GROQ_API_KEY",
	"COHERE_API_KEY",
}

// settings is the fully resolved configuration for one run.
//
// Every field is environment-derived with the literal the bash script used as
// its last resort, so existing callers are unchanged while nothing is frozen.
type settings struct {
	srcDir     string // local helix_translate checkout
	assetsDir  string // local _tools/helixtranslate-container
	seedDB     string // local verified_models.db
	image      string // image tag, e.g. helixtranslate:cli
	volume     string // named volume seeded with the verified-models store
	remoteSrc  string // remote source dir, relative to the SSH login dir
	remoteImg  string // remote asset dir, relative to the SSH login dir
	buildHost  remote.RemoteHost
	workerHost remote.RemoteHost
}

// envOr returns $key, or def when it is unset or empty.
func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// shellQuote wraps s in single quotes for a POSIX shell.
//
// RemoteExecutor.Execute passes its command string to the remote LOGIN SHELL,
// which re-parses it, so every interpolated value must be quoted here. The
// module's own shellEscape is unexported; this is the identical pattern used by
// cmd/deploy-stack/main.go and pkg/distribution/distributor.go.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func main() {
	os.Exit(run())
}

func run() int {
	flagProbe := flag.Bool("probe", false,
		"Preflight only: resolve settings and test reachability of both hosts, then stop. "+
			"Changes nothing. Given that this program is unverified against a live remote, "+
			"run this first.")
	flagDryRun := flag.Bool("dry-run", false,
		"Print every remote command and file transfer this run WOULD perform, then stop. "+
			"Does not connect to anything.")
	flagTimeout := flag.Duration("timeout", 45*time.Minute,
		"Overall timeout. The cgo image build dominates it.")
	flagSkipBuild := flag.Bool("skip-build", false,
		"Skip the source sync and image build; replicate and seed the image already "+
			"present on the build host.")
	flag.Parse()

	log := logging.NewStdLogger("distribute-helixtranslate")

	cfg, err := resolveSettings()
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"distribute-helixtranslate: COULD NOT DETERMINE — %v\n", err)
		return exitUndetermined
	}

	if *flagDryRun {
		printPlan(cfg)
		return exitOK
	}

	ctx, cancel := context.WithTimeout(context.Background(), *flagTimeout)
	defer cancel()
	ctx, stop := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// The module owns SSH: no `ssh`, `scp` or `rsync` process is spawned by
	// this program. CommandTimeout must cover the cgo image build, which the
	// module's own 30-minute default would cut short.
	sshExec, err := remote.NewSSHExecutor(log,
		remote.WithConnectTimeout(15*time.Second),
		remote.WithCommandTimeout(*flagTimeout),
		remote.WithControlMaster(true),
		remote.WithStrictHostKeyCheck(false),
	)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"distribute-helixtranslate: COULD NOT DETERMINE — SSH executor unavailable: %v\n", err)
		return exitUndetermined
	}
	defer sshExec.Close()

	// ---- Preflight. An unreachable host is COULD NOT DETERMINE (2), never a
	// failure of the distribution and never a pass. This is the arm that fires
	// on the machine this program was written on.
	for _, h := range []remote.RemoteHost{cfg.buildHost, cfg.workerHost} {
		if !sshExec.IsReachable(ctx, h) {
			fmt.Fprintf(os.Stderr,
				"distribute-helixtranslate: COULD NOT DETERMINE — host %q (%s@%s:%d) is not reachable.\n"+
					"  Nothing was changed on any host. This is not a failure of the distribution;\n"+
					"  it is the absence of evidence either way.\n",
				h.Name, h.User, h.Address, h.SSHPort())
			return exitUndetermined
		}
		log.Info("host %s (%s) reachable, runtime %s", h.Name, h.Address, h.Runtime)
	}

	if *flagProbe {
		fmt.Printf("probe OK: build=%s(%s) worker=%s(%s) image=%s volume=%s\n",
			cfg.buildHost.Address, cfg.buildHost.Runtime,
			cfg.workerHost.Address, cfg.workerHost.Runtime,
			cfg.image, cfg.volume)
		fmt.Println("Both hosts answered. NOTHING WAS BUILT OR DISTRIBUTED — this was a preflight.")
		return exitOK
	}

	d := &distributor{cfg: cfg, exec: sshExec, log: log}

	if !*flagSkipBuild {
		if err := d.syncSource(ctx); err != nil {
			return failf("source sync to %s failed: %v", cfg.buildHost.Address, err)
		}
		if err := d.buildImage(ctx); err != nil {
			return failf("image build on %s failed: %v", cfg.buildHost.Address, err)
		}
	} else {
		log.Warn("-skip-build: assuming %s already carries %s", cfg.buildHost.Address, cfg.image)
	}

	if err := d.replicateImage(ctx); err != nil {
		return failf("image replication %s -> %s failed: %v",
			cfg.buildHost.Address, cfg.workerHost.Address, err)
	}

	for _, h := range []remote.RemoteHost{cfg.buildHost, cfg.workerHost} {
		if err := d.installHost(ctx, h); err != nil {
			return failf("installing assets on %s failed: %v", h.Address, err)
		}
	}

	// ---- Exit 0 is not evidence. Prove the image actually runs on both hosts.
	ok := true
	for _, h := range []remote.RemoteHost{cfg.buildHost, cfg.workerHost} {
		version, err := d.verifyHost(ctx, h)
		if err != nil {
			fmt.Fprintf(os.Stderr,
				"distribute-helixtranslate: FAIL — %s installed cleanly but %s would not report a version: %v\n",
				h.Address, cfg.image, err)
			ok = false
			continue
		}
		fmt.Printf("   %-14s %s (%s)\n", h.Address, version, h.Runtime)
	}
	if !ok {
		return exitFail
	}

	fmt.Printf("✅ distribute-helixtranslate: %s built on %s, replicated to %s, seeded, and VERIFIED to run on both.\n",
		cfg.image, cfg.buildHost.Address, cfg.workerHost.Address)
	return exitOK
}

func failf(format string, args ...any) int {
	fmt.Fprintf(os.Stderr, "distribute-helixtranslate: FAIL — "+format+"\n", args...)
	return exitFail
}

// resolveSettings derives every path and host from the environment, validating
// each precondition rather than letting a later step fail obscurely.
func resolveSettings() (*settings, error) {
	self, err := os.Executable()
	if err != nil {
		return nil, fmt.Errorf("cannot resolve this program's own path: %w", err)
	}
	// Repository root is derived, never a literal: this binary lives at
	// <root>/_tools/containers/{bin,cmd/...}. When run via `go run` the
	// executable is in a build cache, so ROOT must be overridable.
	root := os.Getenv("VASIC_ROOT")
	if root == "" {
		root, err = repoRootFrom(filepath.Dir(self))
		if err != nil {
			return nil, fmt.Errorf(
				"cannot locate the repository root from %q; set VASIC_ROOT: %w",
				filepath.Dir(self), err)
		}
	}

	srcDir := envOr("HT_SRC", filepath.Join(filepath.Dir(root), "helix_translate"))
	if fi, serr := os.Stat(srcDir); serr != nil || !fi.IsDir() {
		return nil, fmt.Errorf(
			"helix_translate source not found: %q. It is a SIBLING repository of %s; "+
				"clone it there or set HT_SRC=<path>", srcDir, filepath.Base(root))
	}
	assetsDir := envOr("HT_ASSETS", filepath.Join(root, "_tools", "helixtranslate-container"))
	for _, f := range []string{"Containerfile.translator", "run.sh"} {
		if _, serr := os.Stat(filepath.Join(assetsDir, f)); serr != nil {
			return nil, fmt.Errorf("asset %s missing from %q: %w", f, assetsDir, serr)
		}
	}
	seedDB := envOr("SEED_DB", filepath.Join(srcDir, "data", "verified_models.db"))
	if fi, serr := os.Stat(seedDB); serr != nil || fi.IsDir() {
		return nil, fmt.Errorf(
			"seed db not found: %q (override with SEED_DB=<path>). Without it the remote "+
				"bridge runs a ~5-minute live-API verification at startup and then refuses to translate",
			seedDB)
	}

	user := envOr("HT_SSH_USER", "milosvasic")
	keyPath := os.Getenv("HT_SSH_KEY") // empty => ssh-agent / default identities

	return &settings{
		srcDir:    srcDir,
		assetsDir: assetsDir,
		seedDB:    seedDB,
		image:     envOr("HT_IMAGE", "helixtranslate:cli"),
		volume:    envOr("HT_VOLUME", "helixtranslate-data"),
		remoteSrc: envOr("HT_REMOTE_SRC", "helixtranslate-src"),
		remoteImg: envOr("HT_REMOTE_IMG", "helixtranslate-img"),
		buildHost: remote.RemoteHost{
			Name:    "helixtranslate-build",
			Address: envOr("HT_BUILD_HOST", envOr("BUILD_HOST", "thinker.local")),
			User:    user,
			KeyPath: keyPath,
			Runtime: envOr("HT_BUILD_RUNTIME", "podman"),
		},
		workerHost: remote.RemoteHost{
			Name:    "helixtranslate-worker",
			Address: envOr("HT_WORKER_HOST", "amber.local"),
			User:    user,
			KeyPath: keyPath,
			Runtime: envOr("HT_WORKER_RUNTIME", "docker"),
		},
	}, nil
}

// repoRootFrom walks up from dir looking for this repository's own markers.
func repoRootFrom(dir string) (string, error) {
	for d := dir; d != "/" && d != "."; d = filepath.Dir(d) {
		if _, err := os.Stat(filepath.Join(d, "helix-deps.yaml")); err == nil {
			if _, err := os.Stat(filepath.Join(d, "_tools")); err == nil {
				return d, nil
			}
		}
	}
	return "", errors.New("no ancestor directory carries both helix-deps.yaml and _tools/")
}

// distributor carries the resolved settings and the module's executor.
type distributor struct {
	cfg  *settings
	exec *remote.SSHExecutor
	log  logging.Logger
}

// sh runs one command on a host through the module and turns a non-zero remote
// exit code into a rich error. Execute already returns an error for any
// non-zero exit, but its message does not carry the remote stderr, which is the
// only thing that ever explains the failure.
func (d *distributor) sh(ctx context.Context, h remote.RemoteHost, command string) (string, error) {
	res, err := d.exec.Execute(ctx, h, command)
	if err != nil {
		if res != nil {
			return res.Stdout, fmt.Errorf(
				"%s: exit %d: %s", h.Address, res.ExitCode,
				strings.TrimSpace(firstLines(res.Stderr, 8)))
		}
		return "", fmt.Errorf("%s: %w", h.Address, err)
	}
	return res.Stdout, nil
}

// firstLines caps a remote stderr blob so a failure message stays readable.
func firstLines(s string, n int) string {
	lines := strings.Split(s, "\n")
	if len(lines) <= n {
		return s
	}
	return strings.Join(lines[:n], "\n") + "\n  … (truncated)"
}

// syncSource stages a filtered copy of the source locally and uploads it.
//
// The bash used `rsync --exclude=...`; the module offers only CopyDir (scp -r),
// which has no exclude mechanism. Staging preserves the exclude semantics
// without reimplementing a transport: the filtering is local file I/O, and the
// wire transfer is still entirely the module's.
func (d *distributor) syncSource(ctx context.Context) error {
	stage, err := os.MkdirTemp("", "helixtranslate-src-")
	if err != nil {
		return fmt.Errorf("creating local staging dir: %w", err)
	}
	defer os.RemoveAll(stage)

	copied, err := stageSource(d.cfg.srcDir, stage)
	if err != nil {
		return fmt.Errorf("staging source: %w", err)
	}
	d.log.Info("staged %d source file(s) for upload (excludes applied locally)", copied)

	// The Containerfile rides along in the staged tree so a single CopyDir
	// delivers everything the build needs.
	if err := copyFile(
		filepath.Join(d.cfg.assetsDir, "Containerfile.translator"),
		filepath.Join(stage, "Containerfile.translator"),
	); err != nil {
		return fmt.Errorf("staging Containerfile.translator: %w", err)
	}

	if _, err := d.sh(ctx, d.cfg.buildHost,
		"mkdir -p "+shellQuote(d.cfg.remoteSrc)); err != nil {
		return err
	}
	// CopyDir's contract: when basename(local) == basename(remote) it scps into
	// the PARENT of remote; otherwise it rm -rf's remote first. The staging dir
	// has a random basename, so this takes the rm -rf branch — which is the
	// `rsync --delete` the bash asked for.
	if err := d.exec.CopyDir(ctx, d.cfg.buildHost, stage, d.cfg.remoteSrc); err != nil {
		return fmt.Errorf("uploading source: %w", err)
	}
	return nil
}

// stageSource copies src into dst, applying the bash script's exclude list.
func stageSource(src, dst string) (int, error) {
	skipDirs := map[string]bool{
		".git": true, "images": true, "node_modules": true,
		"build": true, "bin": true,
	}
	skipExt := map[string]bool{".pdf": true, ".html": true, ".db": true}

	var n int
	err := filepath.Walk(src, func(path string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, rerr := filepath.Rel(src, path)
		if rerr != nil {
			return rerr
		}
		if rel == "." {
			return nil
		}
		if fi.IsDir() {
			if skipDirs[fi.Name()] {
				return filepath.SkipDir
			}
			return os.MkdirAll(filepath.Join(dst, rel), 0o755)
		}
		if !fi.Mode().IsRegular() || skipExt[strings.ToLower(filepath.Ext(path))] {
			return nil
		}
		if err := copyFile(path, filepath.Join(dst, rel)); err != nil {
			return err
		}
		n++
		return nil
	})
	return n, err
}

func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	fi, err := in.Stat()
	if err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, fi.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// buildImage runs the cgo image build on the build host.
//
// The module has NO remote image-build API (only compose `up -d --build`), so
// the command is composed here and executed through the module's transport.
func (d *distributor) buildImage(ctx context.Context) error {
	cmd := buildImageCommand(
		d.cfg.buildHost.Runtime, d.cfg.image, d.cfg.remoteSrc, "Containerfile.translator")
	d.log.Info("building %s on %s (cgo; this takes minutes)", d.cfg.image, d.cfg.buildHost.Address)
	_, err := d.sh(ctx, d.cfg.buildHost, cmd)
	return err
}

// buildImageCommand is split out so the quoting is unit-testable without a host.
func buildImageCommand(runtimeName, image, dir, containerfile string) string {
	return fmt.Sprintf("cd %s && %s build -t %s -f %s .",
		shellQuote(dir), shellQuote(runtimeName),
		shellQuote(image), shellQuote(containerfile))
}

// replicateImage moves the built image from the build host to the worker host.
//
// The module has no image save/load API and no remote->local fetch, so this
// streams `<rt> save` into a local temp file and scp's it up. See the package
// comment for why this differs from the bash's direct ssh|ssh pipe.
func (d *distributor) replicateImage(ctx context.Context) error {
	tmp, err := os.CreateTemp("", "helixtranslate-image-*.tar")
	if err != nil {
		return fmt.Errorf("creating local image temp file: %w", err)
	}
	defer os.Remove(tmp.Name())
	defer tmp.Close()

	saveCmd := fmt.Sprintf("%s save %s",
		shellQuote(d.cfg.buildHost.Runtime), shellQuote(d.cfg.image))
	d.log.Info("streaming %s off %s", d.cfg.image, d.cfg.buildHost.Address)

	rc, err := d.exec.ExecuteStream(ctx, d.cfg.buildHost, saveCmd)
	if err != nil {
		return fmt.Errorf("starting image save: %w", err)
	}
	written, copyErr := io.Copy(tmp, rc)
	// ExecuteStream returns BEFORE the remote command finishes; the remote exit
	// code surfaces ONLY through Close(). Discarding it here is exactly the
	// defect filed upstream as vasic-digital/containers#2 — a non-zero remote
	// exit would otherwise read as "saved fine, image was empty".
	closeErr := rc.Close()
	if copyErr != nil {
		return fmt.Errorf("reading image stream: %w", copyErr)
	}
	if closeErr != nil {
		return fmt.Errorf("remote %q did not exit cleanly (%d bytes read): %w",
			saveCmd, written, closeErr)
	}
	if written == 0 {
		return fmt.Errorf("remote %q exited 0 but produced no bytes", saveCmd)
	}
	if err := tmp.Sync(); err != nil {
		return fmt.Errorf("flushing local image file: %w", err)
	}
	d.log.Info("image archive is %d bytes", written)

	remoteTar := d.cfg.remoteImg + "/image.tar"
	if _, err := d.sh(ctx, d.cfg.workerHost,
		"mkdir -p "+shellQuote(d.cfg.remoteImg)); err != nil {
		return err
	}
	if err := d.exec.CopyFile(ctx, d.cfg.workerHost, tmp.Name(), remoteTar); err != nil {
		return fmt.Errorf("uploading image archive: %w", err)
	}
	if _, err := d.sh(ctx, d.cfg.workerHost, fmt.Sprintf("%s load -i %s",
		shellQuote(d.cfg.workerHost.Runtime), shellQuote(remoteTar))); err != nil {
		return err
	}
	// podman writes `localhost/<tag>`; docker load preserves the original name.
	// Tagging both ways is idempotent and makes the worker's `run <image>`
	// resolve regardless of which form landed. A failure here is tolerated and
	// logged, because the verification step is what actually decides.
	if _, err := d.sh(ctx, d.cfg.workerHost, fmt.Sprintf("%s tag %s %s || true",
		shellQuote(d.cfg.workerHost.Runtime),
		shellQuote("localhost/"+d.cfg.image), shellQuote(d.cfg.image))); err != nil {
		d.log.Warn("re-tagging localhost/%s was not clean (continuing): %v", d.cfg.image, err)
	}
	if _, err := d.sh(ctx, d.cfg.workerHost,
		"rm -f "+shellQuote(remoteTar)); err != nil {
		d.log.Warn("could not remove the uploaded archive on %s: %v", d.cfg.workerHost.Address, err)
	}
	return nil
}

// installHost writes the secret env file, the runner script, and seeds the
// verified-models volume on one host.
func (d *distributor) installHost(ctx context.Context, h remote.RemoteHost) error {
	runner := remoteexec.NewSSHRunner(d.exec, h)

	// ---- Secrets. No key value is logged or put on a command line; only the
	// key NAMES are reported.
	//
	// Honest boundary: WriteFile scp's the file and THEN chmods it
	// (pkg/remoteexec/sshrunner.go:68-76), so there is a brief window in which
	// the remote file carries scp's default mode rather than 0600. The bash
	// this replaces had the same window (scp, then `install -m600`), so this is
	// not a regression — but it is not the airtight thing a single "mode 0600"
	// label would imply, and closing it needs an upstream atomic-write API.
	env, present := envFileContent()
	if len(present) == 0 {
		return fmt.Errorf(
			"none of %s is set in this environment; the remote engine would have no provider "+
				"credentials. Export at least one before distributing", strings.Join(secretEnvKeys, ", "))
	}
	d.log.Info("%s: installing %d provider key(s) (names only: %s)",
		h.Address, len(present), strings.Join(present, ", "))
	if err := runner.WriteFile(ctx, ".helixtranslate.env", env, 0o600); err != nil {
		return fmt.Errorf("writing the env file: %w", err)
	}

	// ---- The runner script.
	runSh, err := os.ReadFile(filepath.Join(d.cfg.assetsDir, "run.sh"))
	if err != nil {
		return fmt.Errorf("reading run.sh: %w", err)
	}
	if err := runner.WriteFile(ctx, d.cfg.remoteImg+"/run.sh", runSh, 0o755); err != nil {
		return fmt.Errorf("writing run.sh: %w", err)
	}

	// ---- The verified-models store. The module has no named-volume API, so
	// the create and the seeding copy are composed commands.
	if _, err := d.sh(ctx, h, fmt.Sprintf("%s volume create %s >/dev/null 2>&1 || true",
		shellQuote(h.Runtime), shellQuote(d.cfg.volume))); err != nil {
		return fmt.Errorf("creating volume %s: %w", d.cfg.volume, err)
	}
	remoteSeed := d.cfg.remoteImg + "/seed.db"
	if err := d.exec.CopyFile(ctx, h, d.cfg.seedDB, remoteSeed); err != nil {
		return fmt.Errorf("uploading the seed db: %w", err)
	}
	if _, err := d.sh(ctx, h, seedVolumeCommand(
		h.Runtime, d.cfg.volume, remoteSeed,
		envOr("HT_SEED_IMAGE", "docker.io/library/alpine:3.20"),
	)); err != nil {
		return fmt.Errorf("seeding volume %s: %w", d.cfg.volume, err)
	}
	if _, err := d.sh(ctx, h, "rm -f "+shellQuote(remoteSeed)); err != nil {
		d.log.Warn("could not remove the uploaded seed db on %s: %v", h.Address, err)
	}
	return nil
}

// seedVolumeCommand copies the uploaded seed db into the named volume via a
// throwaway container. Split out so the quoting is unit-testable without a host.
//
// remoteSeed is relative to the SSH login directory, and a bind-mount source
// must be absolute, so $HOME is expanded by the remote shell. The mount
// specifiers are single units — quoting "vol:/data" as one word is what keeps a
// volume name containing a space or a colon from splitting into extra flags.
func seedVolumeCommand(runtimeName, volume, remoteSeed, seedImage string) string {
	return fmt.Sprintf(
		"%s run --rm -v %s -v \"$HOME\"/%s:/seed.db:ro %s cp /seed.db /data/verified_models.db",
		shellQuote(runtimeName),
		shellQuote(volume+":/data"),
		shellQuote(remoteSeed),
		shellQuote(seedImage),
	)
}

// envFileContent builds the mode-0600 env file body and reports WHICH keys were
// found — names only, never values.
func envFileContent() ([]byte, []string) {
	var b strings.Builder
	var present []string
	for _, k := range secretEnvKeys {
		if v := os.Getenv(k); v != "" {
			fmt.Fprintf(&b, "%s=%s\n", k, v)
			present = append(present, k)
		}
	}
	return []byte(b.String()), present
}

// verifyHost is the anti-bluff post-condition: the image must actually run.
func (d *distributor) verifyHost(ctx context.Context, h remote.RemoteHost) (string, error) {
	out, err := d.sh(ctx, h, fmt.Sprintf("%s run --rm %s -version 2>&1 | head -1",
		shellQuote(h.Runtime), shellQuote(d.cfg.image)))
	if err != nil {
		return "", err
	}
	version := strings.TrimSpace(out)
	if version == "" {
		return "", errors.New("the container ran but printed no version line")
	}
	return version, nil
}

// printPlan renders everything a real run would do, without connecting.
func printPlan(c *settings) {
	fmt.Println("distribute-helixtranslate — DRY RUN. Nothing was contacted or changed.")
	fmt.Println()
	fmt.Printf("  local source     : %s\n", c.srcDir)
	fmt.Printf("  local assets     : %s\n", c.assetsDir)
	fmt.Printf("  local seed db    : %s\n", c.seedDB)
	fmt.Printf("  image            : %s\n", c.image)
	fmt.Printf("  volume           : %s\n", c.volume)
	fmt.Printf("  build host       : %s@%s:%d runtime=%s\n",
		c.buildHost.User, c.buildHost.Address, c.buildHost.SSHPort(), c.buildHost.Runtime)
	fmt.Printf("  worker host      : %s@%s:%d runtime=%s\n",
		c.workerHost.User, c.workerHost.Address, c.workerHost.SSHPort(), c.workerHost.Runtime)
	fmt.Println()
	fmt.Println("  1. [module CopyDir]   stage source (excludes applied locally) -> ~/" + c.remoteSrc)
	fmt.Println("  2. [module Execute]   " +
		buildImageCommand(c.buildHost.Runtime, c.image, c.remoteSrc, "Containerfile.translator"))
	fmt.Printf("  3. [module Stream]    %s save %s  -> local temp file\n", c.buildHost.Runtime, c.image)
	fmt.Printf("     [module CopyFile]  temp file -> ~/%s/image.tar on %s\n", c.remoteImg, c.workerHost.Address)
	fmt.Printf("     [module Execute]   %s load -i ~/%s/image.tar\n", c.workerHost.Runtime, c.remoteImg)
	fmt.Println("  4. [module WriteFile] ~/.helixtranslate.env (mode 0600) on both hosts")
	fmt.Printf("     [module WriteFile] ~/%s/run.sh (mode 0755) on both hosts\n", c.remoteImg)
	fmt.Printf("     [module Execute]   <rt> volume create %s; seed verified_models.db\n", c.volume)
	fmt.Printf("  5. [module Execute]   <rt> run --rm %s -version   (the anti-bluff check)\n", c.image)
	fmt.Println()
	fmt.Println("  NOTE: steps 2, 3 (save/load/tag), the volume create and the seeding run are")
	fmt.Println("  COMPOSED COMMAND STRINGS, because the Containers module exposes no API for")
	fmt.Println("  remote image build, image transfer, named volumes, or `run` with mounts.")
	fmt.Println("  The transport, quoting, pooling and exit-code handling are all the module's.")
	fmt.Println()
	fmt.Println("  ⚠️  This program has never been run against a live remote. See the package comment.")
}
