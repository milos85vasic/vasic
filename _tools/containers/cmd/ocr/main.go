// Command ocr runs this umbrella's OCR workload inside a container, driving
// the container runtime EXCLUSIVELY through the canonical Containers Submodule
// (`digital.vasic.containers`) as §11.4.76 requires.
//
// # Why this program exists
//
// `tesseract` is absent from the development host, so the export validator's
// FULL-VISUAL/visual.ocr check SKIPped and gate 5 sat at verdict=UNDETERMINED
// — rc 2, and a 2 is never a pass. The operator's standing decision (#10 in
// docs/OPERATOR-DECISIONS-2026-09-07.md) is that the remedy is a CONTAINER
// WORKLOAD through `submodules/containers`, never a host package install.
//
// # Why it is a separate command from site-build
//
// The same reason `cmd/runtime-probe` is separate: `site-build` answers a
// different question. Its workloads are a fixed map of compose services each
// with a fixed, repo-root-relative artifact, which is right for "rebuild the
// site" and wrong for "OCR whichever directory the caller just rasterised
// into". Rather than bend a working orchestrator into a general-purpose one,
// this command states its own contract. The lifecycle helpers both need are
// shared through internal/orchestrate, so this is not a fork of site-build.
//
// # Anti-bluff contract (§11.4, §1.1)
//
// A zero exit from the container is NOT evidence that any page was OCR'd, and
// this program never treats it as such. Every run:
//
//  1. enumerates the input PNGs and snapshots any pre-existing .ocr.txt files
//     BEFORE starting anything;
//  2. reads the exit code back off the STOPPED container through the module's
//     runtime API — not from the compose command's own status;
//  3. requires at least one .ocr.txt to exist, be non-empty, AND be strictly
//     newer than the snapshot. A leftover transcript from an earlier run
//     cannot pass, which is the failure mode that matters here: OCR output
//     lands beside its input and is trivially mistakable for fresh.
//
// # Exit codes — three-valued, as every check in this tree is
//
//	0  the OCR ran and produced fresh, verified transcripts
//	1  a real failure: the container exited non-zero, or produced nothing fresh
//	2  COULD NOT DETERMINE — no container runtime, no compose command, no input
//	   PNGs, or an outcome that could not be read back. NEVER a pass.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"

	"digital.vasic.containers/pkg/compose"
	"digital.vasic.containers/pkg/logging"
	"digital.vasic.containers/pkg/runtime"

	"vasic.digital/tools/containers/internal/orchestrate"
)

const (
	prog          = "ocr"
	serviceName   = "tesseract-ocr"
	containerName = "vasic-tesseract-ocr"

	// noInputExit is the container-side exit code meaning "no .png files".
	// It is translated to rc 2 here: an empty input set is COULD NOT
	// DETERMINE, never a successful OCR of nothing.
	noInputExit = 3
)

func main() {
	os.Exit(run())
}

func run() int {
	var (
		flagDir     = flag.String("dir", "", "Directory of page PNGs to OCR (REQUIRED). Each <name>.png yields <name>.ocr.txt beside it")
		flagRoot    = flag.String("root", "", "Umbrella repository root (default: $PWD walked upwards)")
		flagCompose = flag.String("compose", "", "Compose file (default: <root>/_tools/containers/compose/compose.ocr.yml)")
		flagProject = flag.String("project-name", "vasic-ocr", "compose --project-name")
		flagPSM     = flag.String("psm", "6", "tesseract --psm value")
		flagLang    = flag.String("lang", "eng", "tesseract -l value")
		flagTimeout = flag.Duration("timeout", 10*time.Minute, "Overall wall-clock budget")
		flagProbe   = flag.Bool("probe", false, "Report runtime + compose availability and exit; start nothing")
	)
	flag.Parse()

	if flag.NArg() > 0 {
		fmt.Fprintf(os.Stderr, "%s: unexpected argument %q\n", prog, flag.Arg(0))
		return orchestrate.ExitFail
	}

	log := logging.NewStdLogger(prog)

	root, err := orchestrate.ResolveRoot(*flagRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: COULD NOT DETERMINE the repository root: %v\n", prog, err)
		return orchestrate.ExitUndetermined
	}

	composeFile := *flagCompose
	if composeFile == "" {
		composeFile = filepath.Join(root, "_tools", "containers", "compose", "compose.ocr.yml")
	}
	if _, statErr := os.Stat(composeFile); statErr != nil {
		fmt.Fprintf(os.Stderr, "%s: COULD NOT DETERMINE — compose file unreadable: %v\n", prog, statErr)
		return orchestrate.ExitUndetermined
	}

	ctx, cancel := context.WithTimeout(context.Background(), *flagTimeout)
	defer cancel()
	ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()

	// ---- 1. Which runtime is actually here? Ask the module, never `command -v`.
	rt, err := runtime.AutoDetect(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"%s: COULD NOT DETERMINE — no container runtime available: %v\n", prog, err)
		return orchestrate.ExitUndetermined
	}
	version, verr := rt.Version(ctx)
	if verr != nil {
		version = "(version unavailable)"
	}

	// ---- 2. Which compose command? Again the module decides.
	orch, err := compose.NewDefaultOrchestrator(root, log)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"%s: COULD NOT DETERMINE — no compose command available: %v\n", prog, err)
		return orchestrate.ExitUndetermined
	}

	if *flagProbe {
		fmt.Printf("runtime=%s version=%s compose=available root=%s\n",
			rt.Name(), strings.TrimSpace(version), root)
		return orchestrate.ExitOK
	}

	log.Info("runtime: %s %s", rt.Name(), strings.TrimSpace(version))

	// ---- 3. Resolve and validate the input directory.
	if *flagDir == "" {
		fmt.Fprintf(os.Stderr, "%s: -dir is required (the directory of page PNGs to OCR)\n", prog)
		return orchestrate.ExitFail
	}
	dir, err := filepath.Abs(*flagDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: COULD NOT DETERMINE — -dir cannot be resolved: %v\n", prog, err)
		return orchestrate.ExitUndetermined
	}
	fi, err := os.Stat(dir)
	if err != nil || !fi.IsDir() {
		fmt.Fprintf(os.Stderr,
			"%s: COULD NOT DETERMINE — -dir %s is not a readable directory\n", prog, dir)
		return orchestrate.ExitUndetermined
	}

	pages, err := listPNGs(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: COULD NOT DETERMINE — cannot read %s: %v\n", prog, dir, err)
		return orchestrate.ExitUndetermined
	}
	if len(pages) == 0 {
		// Deliberately rc 2, not rc 0. "Nothing to OCR" is an absence of
		// evidence about legibility, and absence of evidence is never a pass.
		fmt.Fprintf(os.Stderr,
			"%s: COULD NOT DETERMINE — no .png files in %s, so nothing was OCR'd\n", prog, dir)
		return orchestrate.ExitUndetermined
	}

	// ---- 4. Snapshot any PRE-EXISTING transcripts. This is the whole basis of
	// the freshness assertion. OCR output lands beside its input, so a stale
	// <name>.ocr.txt from an earlier run is the exact thing that could make a
	// no-op container look like a successful OCR.
	before := make(map[string]time.Time, len(pages))
	stale := 0
	for _, p := range pages {
		out := transcriptFor(dir, p)
		if st, serr := os.Stat(out); serr == nil {
			before[out] = st.ModTime()
			stale++
		}
	}
	log.Info("%d page(s) to OCR in %s (%d pre-existing transcript(s) that must be superseded)",
		len(pages), dir, stale)
	startedAt := time.Now()

	// The compose file reads these; nothing in it is a frozen literal.
	os.Setenv("VASIC_ROOT", root)
	os.Setenv("VASIC_OCR_DIR", dir)
	os.Setenv("VASIC_OCR_PSM", *flagPSM)
	os.Setenv("VASIC_OCR_LANG", *flagLang)

	project := compose.ComposeProject{
		Name:     *flagProject,
		File:     composeFile,
		Services: []string{serviceName},
	}

	// ---- 5. A stale container from an interrupted run would make `up` fail on
	// the container_name. Tear the project down first; a fresh tree has nothing
	// to remove and this is a no-op there.
	if derr := orch.Down(ctx, project, compose.WithDownRemoveOrphans(true)); derr != nil {
		log.Warn("pre-run compose down was not clean (continuing): %v", derr)
	}

	log.Info("starting %q — OCR %d rendered page(s) with tesseract", serviceName, len(pages))
	upErr := orch.Up(ctx, project,
		compose.WithUpDetach(true),
		compose.WithRemoveOrphans(true),
	)
	if upErr != nil {
		fmt.Fprintf(os.Stderr, "%s: compose up failed: %v\n", prog, upErr)
		orchestrate.DumpLogs(ctx, rt, prog, containerName)
		teardown(orch, project, log)
		return orchestrate.ExitFail
	}

	// ---- 6. Wait for the container to stop, then read its REAL exit code off
	// the stopped container through the module's runtime API.
	status, werr := orchestrate.WaitForExit(ctx, rt, containerName)
	orchestrate.DumpLogs(ctx, rt, prog, containerName)
	teardown(orch, project, log)

	if werr != nil {
		fmt.Fprintf(os.Stderr,
			"%s: COULD NOT DETERMINE the outcome of %q: %v\n", prog, serviceName, werr)
		return orchestrate.ExitUndetermined
	}
	if status.ExitCode == noInputExit {
		fmt.Fprintf(os.Stderr,
			"%s: COULD NOT DETERMINE — the container found no .png files in the mounted directory\n", prog)
		return orchestrate.ExitUndetermined
	}
	if status.ExitCode != 0 {
		fmt.Fprintf(os.Stderr,
			"%s: FAIL — %q exited %d\n", prog, serviceName, status.ExitCode)
		return orchestrate.ExitFail
	}

	// ---- 7. Exit 0 is not evidence. Prove the transcripts.
	var fresh, missing, empty, unchanged []string
	for _, p := range pages {
		out := transcriptFor(dir, p)
		st, serr := os.Stat(out)
		switch {
		case serr != nil:
			missing = append(missing, p)
		case st.Size() == 0:
			empty = append(empty, p)
		case !before[out].IsZero() && !st.ModTime().After(before[out]):
			unchanged = append(unchanged, p)
		case st.ModTime().Before(startedAt.Add(-2 * time.Second)):
			unchanged = append(unchanged, p)
		default:
			fresh = append(fresh, p)
		}
	}

	if len(fresh) == 0 {
		fmt.Fprintf(os.Stderr,
			"%s: FAIL — %q exited 0 but produced NO fresh transcript for any of the %d page(s). "+
				"A green exit with no output is a bluff, and it is reported as a failure. "+
				"(missing=%d empty=%d not-rewritten=%d)\n",
			prog, serviceName, len(pages), len(missing), len(empty), len(unchanged))
		return orchestrate.ExitFail
	}

	log.Info("%q exited 0 after %s", serviceName, time.Since(startedAt).Truncate(time.Second))
	fmt.Printf("✅ %s: %s — OCR of %d rendered page(s)\n", prog, serviceName, len(pages))
	fmt.Printf("   runtime  : %s\n", rt.Name())
	fmt.Printf("   dir      : %s\n", dir)
	fmt.Printf("   fresh    : %d transcript(s) written by THIS run\n", len(fresh))
	// Partial results are reported, never rounded up. The caller decides what a
	// missing page means for its own verdict; this program refuses to hide one.
	if n := len(missing) + len(empty) + len(unchanged); n > 0 {
		fmt.Printf("   NOT fresh: %d page(s) — missing=%v empty=%v not-rewritten=%v\n",
			n, missing, empty, unchanged)
	}
	return orchestrate.ExitOK
}

// teardown removes the project's containers, keeping any named volumes. It is
// called on every path out of the run, successful or not.
func teardown(orch compose.ComposeOrchestrator, project compose.ComposeProject, log logging.Logger) {
	// A fresh context: the run's own may already be cancelled or timed out, and
	// leaving a container behind would break the NEXT run's container_name.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	if derr := orch.Down(ctx, project, compose.WithDownRemoveOrphans(true)); derr != nil {
		log.Warn("compose down after the run was not clean: %v", derr)
	}
}

// listPNGs returns the .png file names directly in dir, sorted by the page
// number the rasteriser assigned rather than lexicographically.
//
// The lexicographic trap is real and was already fixed once on the JavaScript
// side: `.sort()` orders a 12-page document 1, 10, 11, 12, 2, 3 …, silently
// scrambling the transcript. It is not repeated here.
func listPNGs(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if strings.EqualFold(filepath.Ext(e.Name()), ".png") {
			out = append(out, e.Name())
		}
	}
	sort.Slice(out, func(i, j int) bool {
		ni, oki := trailingNumber(out[i])
		nj, okj := trailingNumber(out[j])
		if oki && okj && ni != nj {
			return ni < nj
		}
		return out[i] < out[j]
	})
	return out, nil
}

// trailingNumber extracts the trailing integer of a page file name
// ("page-10.png" -> 10). ok is false when there is none, in which case the
// caller falls back to a plain string comparison rather than inventing an
// order.
func trailingNumber(name string) (int, bool) {
	base := strings.TrimSuffix(name, filepath.Ext(name))
	end := len(base)
	for end > 0 && base[end-1] >= '0' && base[end-1] <= '9' {
		end--
	}
	digits := base[end:]
	if digits == "" {
		return 0, false
	}
	n := 0
	for _, c := range digits {
		n = n*10 + int(c-'0')
	}
	return n, true
}

// transcriptFor returns the absolute path of the .ocr.txt that OCRing page
// produces. It mirrors exactly what `tesseract <in> <base>` writes, so a
// caller that used a host tesseract binary reads back the same filenames.
func transcriptFor(dir, page string) string {
	base := strings.TrimSuffix(page, filepath.Ext(page))
	return filepath.Join(dir, base+".ocr.txt")
}
