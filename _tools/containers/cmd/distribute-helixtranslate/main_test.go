package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestShellQuote_ClosesTheInjectionHole locks the quoting helper.
//
// RemoteExecutor.Execute hands its command string to the remote LOGIN SHELL,
// which re-parses it. Every value interpolated into a command must therefore
// survive that second parse as ONE word. The module's own shellEscape is
// unexported, so this helper is ours and needs its own proof.
func TestShellQuote_ClosesTheInjectionHole(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"plain", "helixtranslate:cli", `'helixtranslate:cli'`},
		{"space", "my image", `'my image'`},
		{"single quote", "it's", `'it'\''s'`},
		{"command substitution", "$(rm -rf /)", `'$(rm -rf /)'`},
		{"backtick", "`id`", "'`id`'"},
		{"semicolon chain", "a; rm -rf /", `'a; rm -rf /'`},
		{"dollar var", "$HOME", `'$HOME'`},
		{"empty", "", `''`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := shellQuote(c.in); got != c.want {
				t.Fatalf("shellQuote(%q) = %q, want %q", c.in, got, c.want)
			}
		})
	}
}

// TestShellQuote_NeutralisesAMaliciousImageTag is the mutation this quoting
// exists to survive: an image tag carrying a shell metacharacter must not
// become a second command on the remote host.
func TestShellQuote_NeutralisesAMaliciousImageTag(t *testing.T) {
	evil := "img; touch /tmp/pwned"
	cmd := buildImageCommand("podman", evil, "src", "Containerfile")

	// The payload must appear ONLY inside a quoted run, never as a bare
	// command separator.
	if strings.Contains(cmd, "; touch /tmp/pwned'") == false {
		t.Fatalf("expected the payload to be carried inside quotes, got: %s", cmd)
	}
	if strings.Contains(cmd, " touch /tmp/pwned") &&
		!strings.Contains(cmd, `'img; touch /tmp/pwned'`) {
		t.Fatalf("payload escaped its quoting: %s", cmd)
	}
}

// TestBuildImageCommand_ShapeAndQuoting locks the remote build command. The
// module has no remote-build API, so this string is ours and is the only thing
// standing between a caller and a mis-quoted `podman build`.
func TestBuildImageCommand_ShapeAndQuoting(t *testing.T) {
	got := buildImageCommand("podman", "helixtranslate:cli", "helixtranslate-src", "Containerfile.translator")
	want := `cd 'helixtranslate-src' && 'podman' build -t 'helixtranslate:cli' -f 'Containerfile.translator' .`
	if got != want {
		t.Fatalf("buildImageCommand mismatch\n got: %s\nwant: %s", got, want)
	}
}

// TestSeedVolumeCommand_MountSpecifiersAreSingleWords is the check that a
// volume name or path containing a space cannot split into extra flags.
func TestSeedVolumeCommand_MountSpecifiersAreSingleWords(t *testing.T) {
	got := seedVolumeCommand("docker", "helixtranslate-data", "helixtranslate-img/seed.db", "docker.io/library/alpine:3.20")

	for _, must := range []string{
		`'docker' run --rm`,
		`-v 'helixtranslate-data:/data'`,
		`-v "$HOME"/'helixtranslate-img/seed.db':/seed.db:ro`,
		`'docker.io/library/alpine:3.20' cp /seed.db /data/verified_models.db`,
	} {
		if !strings.Contains(got, must) {
			t.Fatalf("seedVolumeCommand missing %q\n got: %s", must, got)
		}
	}

	// $HOME must stay UNQUOTED so the remote shell expands it — a bind-mount
	// source has to be absolute. If it were quoted, the mount would silently
	// become a relative path and podman/docker would create a directory.
	if strings.Contains(got, `'$HOME'`) {
		t.Fatalf("$HOME was quoted and will not expand remotely: %s", got)
	}

	// A volume name with a space must not become two arguments.
	spaced := seedVolumeCommand("podman", "my vol", "s.db", "alpine")
	if !strings.Contains(spaced, `-v 'my vol:/data'`) {
		t.Fatalf("a spaced volume name split into extra arguments: %s", spaced)
	}
}

// TestEnvFileContent_NamesOnlyAndNoStrayKeys proves the secret file carries
// exactly the keys that are set, and nothing else.
func TestEnvFileContent_NamesOnlyAndNoStrayKeys(t *testing.T) {
	for _, k := range secretEnvKeys {
		t.Setenv(k, "")
	}
	t.Setenv("MISTRAL_API_KEY", "mistral-secret-value")
	t.Setenv("COHERE_API_KEY", "cohere-secret-value")

	body, present := envFileContent()

	if len(present) != 2 {
		t.Fatalf("expected 2 present keys, got %v", present)
	}
	got := string(body)
	if !strings.Contains(got, "MISTRAL_API_KEY=mistral-secret-value\n") {
		t.Fatalf("MISTRAL key missing from env body: %q", got)
	}
	if !strings.Contains(got, "COHERE_API_KEY=cohere-secret-value\n") {
		t.Fatalf("COHERE key missing from env body: %q", got)
	}
	if strings.Contains(got, "GROQ_API_KEY") {
		t.Fatalf("an unset key was written anyway: %q", got)
	}
	// `present` is what gets LOGGED. It must carry names, never values.
	for _, name := range present {
		if strings.Contains(name, "secret-value") {
			t.Fatalf("a secret VALUE leaked into the loggable key list: %v", present)
		}
	}
}

// TestEnvFileContent_EmptyWhenNothingSet drives the arm that makes
// installHost refuse to distribute credential-less.
func TestEnvFileContent_EmptyWhenNothingSet(t *testing.T) {
	for _, k := range secretEnvKeys {
		t.Setenv(k, "")
	}
	body, present := envFileContent()
	if len(present) != 0 || len(body) != 0 {
		t.Fatalf("expected an empty env file and no present keys, got %d key(s), body %q",
			len(present), string(body))
	}
}

// TestEnvOr_PrefersEnvironmentOverFrozenDefault locks the adaptability rule:
// every default is a last resort, never a frozen value.
func TestEnvOr_PrefersEnvironmentOverFrozenDefault(t *testing.T) {
	t.Setenv("HT_TEST_KEY", "")
	if got := envOr("HT_TEST_KEY", "fallback"); got != "fallback" {
		t.Fatalf("unset key should yield the default, got %q", got)
	}
	t.Setenv("HT_TEST_KEY", "override")
	if got := envOr("HT_TEST_KEY", "fallback"); got != "override" {
		t.Fatalf("set key should win over the default, got %q", got)
	}
}

// TestStageSource_AppliesTheExcludeList proves the local staging step
// reproduces the rsync excludes the module's CopyDir (scp -r) cannot express.
func TestStageSource_AppliesTheExcludeList(t *testing.T) {
	src := t.TempDir()
	dst := t.TempDir()

	mk := func(rel, content string) {
		p := filepath.Join(src, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	mk("main.go", "package main")
	mk("cmd/unified-translator/main.go", "package main")
	mk(".git/config", "[core]")
	mk("build/artifact.o", "obj")
	mk("bin/tool", "elf")
	mk("images/logo.png", "png")
	mk("node_modules/x/index.js", "js")
	mk("docs/manual.pdf", "pdf")
	mk("docs/page.html", "html")
	mk("data/verified_models.db", "sqlite")
	mk("README.md", "readme")

	n, err := stageSource(src, dst)
	if err != nil {
		t.Fatalf("stageSource: %v", err)
	}

	mustExist := []string{"main.go", "cmd/unified-translator/main.go", "README.md"}
	mustNotExist := []string{
		".git/config", "build/artifact.o", "bin/tool", "images/logo.png",
		"node_modules/x/index.js", "docs/manual.pdf", "docs/page.html",
		"data/verified_models.db",
	}
	for _, rel := range mustExist {
		if _, err := os.Stat(filepath.Join(dst, rel)); err != nil {
			t.Errorf("expected %s to be staged: %v", rel, err)
		}
	}
	for _, rel := range mustNotExist {
		if _, err := os.Stat(filepath.Join(dst, rel)); err == nil {
			t.Errorf("%s should have been excluded but was staged", rel)
		}
	}
	if n != len(mustExist) {
		t.Errorf("staged file count = %d, want %d", n, len(mustExist))
	}
}

// TestFirstLines_TruncatesLongRemoteStderr keeps a failure message readable
// without hiding that it was cut.
func TestFirstLines_TruncatesLongRemoteStderr(t *testing.T) {
	short := "one\ntwo"
	if got := firstLines(short, 8); got != short {
		t.Fatalf("short input must pass through unchanged, got %q", got)
	}
	long := strings.Repeat("line\n", 40)
	got := firstLines(long, 8)
	if !strings.Contains(got, "(truncated)") {
		t.Fatalf("a truncated blob must say so, got %q", got)
	}
	if strings.Count(got, "line") != 8 {
		t.Fatalf("expected exactly 8 retained lines, got %d", strings.Count(got, "line"))
	}
}

// TestResolveSettings_RefusesAnAbsentSource proves a missing precondition
// becomes a named error rather than an obscure failure five steps later.
func TestResolveSettings_RefusesAnAbsentSource(t *testing.T) {
	t.Setenv("VASIC_ROOT", t.TempDir())
	t.Setenv("HT_SRC", filepath.Join(t.TempDir(), "definitely-not-here"))

	_, err := resolveSettings()
	if err == nil {
		t.Fatal("expected an error for an absent helix_translate source")
	}
	if !strings.Contains(err.Error(), "helix_translate source not found") {
		t.Fatalf("error should name the missing precondition, got: %v", err)
	}
}

// TestResolveSettings_HostsAndRuntimesAreOverridable proves nothing about the
// fleet is frozen: both hostnames and both runtimes come from the environment.
func TestResolveSettings_HostsAndRuntimesAreOverridable(t *testing.T) {
	root := t.TempDir()
	src := filepath.Join(root, "src")
	assets := filepath.Join(root, "assets")
	for _, d := range []string{src, assets, filepath.Join(src, "data")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	for _, f := range []string{"Containerfile.translator", "run.sh"} {
		if err := os.WriteFile(filepath.Join(assets, f), []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(src, "data", "verified_models.db"), []byte("db"), 0o644); err != nil {
		t.Fatal(err)
	}

	t.Setenv("VASIC_ROOT", root)
	t.Setenv("HT_SRC", src)
	t.Setenv("HT_ASSETS", assets)
	t.Setenv("HT_BUILD_HOST", "build.example.invalid")
	t.Setenv("HT_WORKER_HOST", "worker.example.invalid")
	t.Setenv("HT_BUILD_RUNTIME", "nerdctl")
	t.Setenv("HT_WORKER_RUNTIME", "podman")
	t.Setenv("HT_SSH_USER", "someuser")
	t.Setenv("HT_IMAGE", "custom:tag")
	t.Setenv("HT_VOLUME", "custom-vol")

	cfg, err := resolveSettings()
	if err != nil {
		t.Fatalf("resolveSettings: %v", err)
	}
	if cfg.buildHost.Address != "build.example.invalid" ||
		cfg.workerHost.Address != "worker.example.invalid" {
		t.Errorf("host addresses were not taken from the environment: %+v / %+v",
			cfg.buildHost, cfg.workerHost)
	}
	if cfg.buildHost.Runtime != "nerdctl" || cfg.workerHost.Runtime != "podman" {
		t.Errorf("runtimes were not taken from the environment: %q / %q",
			cfg.buildHost.Runtime, cfg.workerHost.Runtime)
	}
	if cfg.buildHost.User != "someuser" || cfg.workerHost.User != "someuser" {
		t.Errorf("ssh user was not taken from the environment")
	}
	if cfg.image != "custom:tag" || cfg.volume != "custom-vol" {
		t.Errorf("image/volume were not taken from the environment: %q / %q", cfg.image, cfg.volume)
	}
	// SSHPort defaults to 22 through the module's own accessor.
	if cfg.buildHost.SSHPort() != 22 {
		t.Errorf("expected the module's default SSH port 22, got %d", cfg.buildHost.SSHPort())
	}
}
