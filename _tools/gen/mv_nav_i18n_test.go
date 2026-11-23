package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The Jekyll chrome dictionary milosvasic.ru/_data/ui.json is hand-maintained
// source data (merged once by merge_aria_footer.py), read by
// milosvasic.ru/_layouts/default.html. These tests pin that every locale carries
// every key the English block defines, and that the Expertise nav link is
// language-aware (localized hubs live at /expertise/<lang>/).

func loadMVUI(t *testing.T) map[string]map[string]string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(repoRoot(), "milosvasic.ru", "_data", "ui.json"))
	if err != nil {
		t.Fatalf("read ui.json: %v", err)
	}
	var d map[string]map[string]string
	if err := json.Unmarshal(b, &d); err != nil {
		t.Fatalf("parse ui.json: %v", err)
	}
	return d
}

func TestMVUIEveryLocaleHasEveryKey(t *testing.T) {
	d := loadMVUI(t)
	en := d["en"]
	if len(en) == 0 {
		t.Fatal("en block missing/empty")
	}
	for _, l := range []string{"ar", "be", "de", "es", "fa", "fr", "hi", "ja", "kk", "ko", "ru", "sr", "tr", "zh"} {
		blk, ok := d[l]
		if !ok {
			t.Errorf("locale %s missing", l)
			continue
		}
		for k := range en {
			if strings.TrimSpace(blk[k]) == "" {
				t.Errorf("locale %s missing key %q", l, k)
			}
		}
	}
}

func TestMVUINavExpertiseTranslated(t *testing.T) {
	d := loadMVUI(t)
	for l, blk := range d {
		if l == "en" {
			continue
		}
		v := blk["nav.expertise"]
		if v == "" {
			t.Errorf("%s: nav.expertise absent", l)
		} else if v == d["en"]["nav.expertise"] && l != "de" && l != "fr" {
			// de/fr: "Expertise" is the genuine native word (same spelling as English).
			t.Errorf("%s: nav.expertise is untranslated English %q", l, v)
		}
	}
}

func TestMVLayoutExpertiseHrefLanguageAware(t *testing.T) {
	b, err := os.ReadFile(filepath.Join(repoRoot(), "milosvasic.ru", "_layouts", "default.html"))
	if err != nil {
		t.Fatal(err)
	}
	s := string(b)
	if strings.Contains(s, `href="/expertise/"`) {
		t.Error(`layout hardcodes href="/expertise/" (English hub for every language)`)
	}
	if !strings.Contains(s, "/expertise/{{ page.lang }}/") {
		t.Error("layout has no page.lang-based expertise href")
	}
}
