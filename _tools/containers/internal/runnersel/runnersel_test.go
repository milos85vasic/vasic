package runnersel

import (
	"context"
	"errors"
	"strings"
	"testing"

	"digital.vasic.containers/pkg/runtime"
)

func env(m map[string]string) func(string) string { return func(k string) string { return m[k] } }

func TestPrecedenceFlagOverEnvOverDefault(t *testing.T) {
	c, rest, err := Parse([]string{"--runner=podman", "x"}, env(map[string]string{"CONTAINERS_RUNNER": "docker"}))
	if err != nil || c.Name != "podman" || c.Source != runtime.SourceFlag || len(rest) != 1 || rest[0] != "x" {
		t.Fatalf("flag must beat env and be stripped: %+v %v %v", c, rest, err)
	}
	c, _, err = Parse(nil, env(map[string]string{"CONTAINERS_RUNNER": "docker"}))
	if err != nil || c.Name != "docker" || c.Source != runtime.SourceEnv {
		t.Fatalf("env must beat default: %+v %v", c, err)
	}
	c, _, err = Parse([]string{"--runner", "auto"}, env(map[string]string{"CONTAINERS_RUNNER": "docker"}))
	if err != nil || c.Forced() || c.Source != runtime.SourceFlag {
		t.Fatalf("explicit auto must beat env: %+v %v", c, err)
	}
	c, _, err = Parse(nil, env(nil))
	if err != nil || c.Forced() || c.Source != runtime.SourceDefault {
		t.Fatalf("default: %+v %v", c, err)
	}
}

func TestUnknownAndMalformedAreRefused(t *testing.T) {
	if _, _, err := Parse([]string{"--runner=bogus"}, env(nil)); !errors.Is(err, runtime.ErrUnknownRunner) {
		t.Fatalf("unknown flag value: %v", err)
	}
	if _, _, err := Parse(nil, env(map[string]string{"CONTAINERS_RUNNER": "bogus"})); !errors.Is(err, runtime.ErrUnknownRunner) {
		t.Fatalf("unknown env value must be refused too: %v", err)
	}
	if _, _, err := Parse([]string{"--runner"}, env(nil)); err == nil {
		t.Fatal("--runner without a value must be refused")
	}
}

// Real host: every supported runner that is NOT installed here must be refused
// with ErrRunnerUnavailable and never answered by another runner.
func TestForcedUnavailableNeverFallsBack(t *testing.T) {
	for _, name := range runtime.SupportedRunners() {
		c := runtime.RunnerChoice{Name: name, Source: runtime.SourceFlag}
		rt, err := Runtime(context.Background(), c)
		if err != nil {
			if !errors.Is(err, runtime.ErrRunnerUnavailable) {
				t.Fatalf("%s: wrong error class: %v", name, err)
			}
			continue
		}
		if rt.Name() != name {
			t.Fatalf("forced %s but got %s (silent fallback)", name, rt.Name())
		}
	}
}

func TestUsageListsModuleRunners(t *testing.T) {
	u := Usage()
	for _, n := range runtime.SupportedRunners() {
		if !strings.Contains(u, n) {
			t.Fatalf("usage lacks %s: %s", n, u)
		}
	}
}
