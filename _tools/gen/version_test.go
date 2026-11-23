package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReadSiteVersion(t *testing.T) {
	dir := t.TempDir()
	good := filepath.Join(dir, "VERSION")
	if err := os.WriteFile(good, []byte("1.9.0\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if v, err := readSiteVersion(good); err != nil || v != "1.9.0" {
		t.Fatalf("got %q, %v; want 1.9.0", v, err)
	}
	for _, bad := range []string{"", "v1.9.0", "1.9", "1.9.0-rc1", "latest", "1.9.0 x"} {
		p := filepath.Join(dir, "BAD")
		_ = os.WriteFile(p, []byte(bad), 0o644)
		if _, err := readSiteVersion(p); err == nil {
			t.Errorf("VERSION %q accepted; must be refused", bad)
		}
	}
	if _, err := readSiteVersion(filepath.Join(dir, "missing")); err == nil {
		t.Error("missing VERSION accepted; must fail closed")
	}
}

func TestVersionBadgeAndFooter(t *testing.T) {
	s := &Site{Repo: "o/r", Version: "1.2.3", Brand: "B"}
	b := versionBadge(s, "ru")
	want := `<a href="https://github.com/o/r/releases/tag/v1.2.3" rel="noopener">v1.2.3</a>`
	if !strings.Contains(b, want) || !strings.Contains(b, `class="site-version"`) || !strings.Contains(b, T("ru", "footer.version")) {
		t.Fatalf("badge wrong: %s", b)
	}
	f := footerHTML(s, "en", "© 2026 B", true)
	if !strings.Contains(f, `<span class="od-footer__copy" data-i18n="footer.text">© 2026 B</span>`) || !strings.Contains(f, b[:20]) {
		t.Fatalf("footer wrong: %s", f)
	}
	// A site without a Repo keeps the historical markup byte-for-byte.
	plain := &Site{Brand: "B"}
	if got := footerHTML(plain, "en", "© 2026 B", true); got != `<footer class="od-footer" data-i18n="footer.text">© 2026 B</footer>` {
		t.Fatalf("plain home footer changed: %s", got)
	}
	if got := footerHTML(plain, "en", "© 2026 B", false); got != `<footer class="od-footer">© 2026 B</footer>` {
		t.Fatalf("plain footer changed: %s", got)
	}
}

func TestFooterVersionKeyInAllLanguages(t *testing.T) {
	for _, l := range []string{"en", "ru", "sr", "de", "es", "fr", "be", "zh", "kk", "hi", "ja", "ko", "ar", "tr", "fa"} {
		m, ok := uiDict[l]
		if !ok || strings.TrimSpace(m["footer.version"]) == "" {
			t.Errorf("lang %s: footer.version missing", l)
		}
		if l != "en" && m["footer.version"] == uiDict["en"]["footer.version"] {
			t.Errorf("lang %s: footer.version identical to English (untranslated)", l)
		}
	}
}
