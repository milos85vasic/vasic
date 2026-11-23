package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
)

// ui-i18n.json is the reviewer-gated (HelixConstitution §11.4.140/§11.4.141/§11.4.236)
// per-language dictionary of every generator-emitted UI/chrome + SEO string.
// English is the source of truth; non-EN values are produced by the HelixTranslate
// engine and independently reviewed (see _tools/gen/translate-ui.py and the
// verdicts under _tests/evidence/l10n-audit/reviews/). Glossary terms are
// preserved verbatim.
//
//go:embed ui-i18n.json
var uiI18nRaw []byte

var uiDict map[string]map[string]string

func init() {
	if err := json.Unmarshal(uiI18nRaw, &uiDict); err != nil {
		panic("ui-i18n.json: " + err.Error())
	}
	if uiDict == nil {
		uiDict = map[string]map[string]string{}
	}
}

// T returns the localized UI string for (lang, key), falling back explicitly and
// visibly to English, then to the key itself. No silent English masquerading as a
// translation: a genuinely missing translation degrades to the EN source string.
func T(lang, key string) string {
	if m, ok := uiDict[lang]; ok {
		if v, ok := m[key]; ok && v != "" {
			return v
		}
	}
	if m, ok := uiDict["en"]; ok {
		if v, ok := m[key]; ok {
			return v
		}
	}
	return key
}

// tOr returns the localized UI string for key, or the provided English fallback
// when the reviewer-gated dictionary has no entry for it (T would otherwise echo
// the raw key). Used for the home chrome labels (nav.work / nav.contact) that are
// not in ui-i18n.json: EN stays byte-identical (fallback == the historical
// literal) while the keys that ARE present localize on the per-language homes. No
// invented translations — a missing key degrades honestly to the EN source text.
func tOr(lang, key, fallback string) string {
	if v := T(lang, key); v != key {
		return v
	}
	return fallback
}

// htmlLang normalizes an empty/absent lang to "en" for the <html lang> attribute.
func htmlLang(lang string) string {
	if lang == "" {
		return "en"
	}
	return lang
}

// htmlDir returns the writing direction for a language (RTL for Arabic/Persian/
// Hebrew/Urdu, LTR otherwise) — drives <html dir> and logical CSS.
func htmlDir(lang string) string {
	switch lang {
	case "ar", "fa", "he", "ur":
		return "rtl"
	}
	return "ltr"
}

// ogLocale maps a language code to an Open Graph / og:locale value.
var ogLocales = map[string]string{
	"en": "en_US", "ru": "ru_RU", "sr": "sr_RS", "de": "de_DE", "es": "es_ES",
	"fr": "fr_FR", "be": "be_BY", "zh": "zh_CN", "kk": "kk_KZ", "hi": "hi_IN",
	"ja": "ja_JP", "ko": "ko_KR", "ar": "ar_AR", "tr": "tr_TR", "fa": "fa_IR",
}

func ogLocale(lang string) string {
	if v, ok := ogLocales[lang]; ok {
		return v
	}
	return "en_US"
}

// siteKeywords returns the per-language SEO keyword list for a site.
func siteKeywords(site *Site, lang string) string {
	if site.Key == "milosvasic.ru" {
		return T(lang, "kw.milos")
	}
	return T(lang, "kw.vasic")
}

// langDisplayNames are the endonyms shown in the language switcher menu.
var langDisplayNames = map[string]string{
	"en": "English", "ru": "Русский", "sr": "Српски", "de": "Deutsch",
	"es": "Español", "fr": "Français", "be": "Беларуская", "zh": "中文",
	"kk": "Қазақша", "hi": "हिन्दी", "ja": "日本語", "ko": "한국어",
	"ar": "العربية", "tr": "Türkçe", "fa": "فارسی",
}

func langName(code string) string {
	if n, ok := langDisplayNames[code]; ok {
		return n
	}
	return strings.ToUpper(code)
}

// odLangMount is the placeholder the switcher script mounts into (header actions
// / nav). Placed by the self-contained (vasic.digital) shells only; the Jekyll
// (milosvasic.ru) pages carry their own switcher in the shared layout.
func odLangMount() string { return `<span id="od-lang-mount"></span>` }

// footerText builds the footer copyright line — the single source of truth shared
// by the SSR footer (home.go) and the OD_I18N client dictionary, so the two are
// byte-identical. The year is deterministic via copyrightYear (§11.4.65) and the
// brand-suffix is fully translated (no hardcoded copy).
func footerText(site *Site, lang string) string {
	return "© " + copyrightYear() + " " + site.Brand + " — " + T(lang, "footer.suffix") + "."
}

// versionRe is the only accepted shape of the committed VERSION file (SemVer
// core, no "v" prefix, no pre-release): the release tag is always "v"+VERSION.
var versionRe = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)

// readSiteVersion reads and validates the single committed VERSION file. A
// missing or malformed file is an error, never a silent default (fail closed).
func readSiteVersion(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("site version: %w", err)
	}
	v := strings.TrimSpace(string(b))
	if !versionRe.MatchString(v) {
		return "", fmt.Errorf("site version: %s holds %q, want MAJOR.MINOR.PATCH", path, v)
	}
	return v, nil
}

// versionBadge renders the footer website-version fragment for sites that carry a
// Repo (empty string otherwise, so sites without the feature stay byte-identical):
//
//	<span class="site-version"><span data-i18n="footer.version">Label:</span> <a href=".../releases/tag/vX">vX</a></span>
//
// The label is the localized UI key footer.version (it includes its own colon);
// the link target is the GitHub release page of the tag "v"+Version.
func versionBadge(site *Site, lang string) string {
	if site.Repo == "" || site.Version == "" {
		return ""
	}
	tag := "v" + site.Version
	return `<span class="site-version"><span data-i18n="footer.version">` + esc(T(lang, "footer.version")) +
		`</span> <a href="https://github.com/` + site.Repo + `/releases/tag/` + tag +
		`" rel="noopener">` + tag + `</a></span>`
}

// footerHTML renders the <footer>. Without a version badge it is byte-identical
// to the historical markup; with one, the copyright text and the badge are two
// flex items. dataI18N (home only) marks the copyright span for the client
// dictionary so the badge is never overwritten by applyDict.
func footerHTML(site *Site, lang, copyHTML string, dataI18N bool) string {
	badge := versionBadge(site, lang)
	if badge == "" {
		if dataI18N {
			return `<footer class="od-footer" data-i18n="footer.text">` + copyHTML + `</footer>`
		}
		return `<footer class="od-footer">` + copyHTML + `</footer>`
	}
	attr := ""
	if dataI18N {
		attr = ` data-i18n="footer.text"`
	}
	return `<footer class="od-footer"><span class="od-footer__copy"` + attr + `>` + copyHTML + `</span>` + badge + `</footer>`
}

// odSwitcher emits the inline config (OD_LANGS / OD_PAGE / OD_I18N) plus the
// deferred switcher script. OD_PAGE.paths carries the per-language STATIC URLs
// (root-absolute) so the switcher NAVIGATES to the real localized page — for
// product/portfolio pages AND the home (localized homes now exist at /<lang>/,
// so selecting a language on the home loads the fully-translated home body, not
// just a client-side chrome swap). The OD_I18N chrome dictionary is still emitted
// on the home as a progressive-enhancement fallback.
func odSwitcher(site *Site, langs []string, pageType, enPath, prefix string) string {
	type nameCode struct {
		Code string `json:"code"`
		Name string `json:"name"`
	}
	var ls []nameCode
	for _, l := range langs {
		ls = append(ls, nameCode{l, langName(l)})
	}
	langsJSON, _ := json.Marshal(ls)

	// Every page type has real per-language static routes now (home included).
	paths := map[string]string{}
	for _, l := range langs {
		paths[l] = "/" + langPath(l, enPath)
	}
	pageJSON, _ := json.Marshal(map[string]interface{}{"type": pageType, "paths": paths})

	// Chrome dictionary consumed on the home (falls back to EN per key).
	i18n := map[string]map[string]string{}
	if pageType == "home" {
		for _, l := range langs {
			i18n[l] = map[string]string{
				"nav.products":     T(l, "nav.products"),
				"nav.portfolio":    T(l, "nav.portfolio"),
				"cta.readmore":     T(l, "pf.readmore"),
				"footer.text":      footerText(site, l),
				"footer.version":   T(l, "footer.version"),
				"aria.primaryNav":  T(l, "aria.primaryNav"),
				"aria.toggleTheme": T(l, "aria.toggleTheme"),
				"aria.backToTop":   T(l, "aria.backToTop"),
			}
		}
	}
	i18nJSON, _ := json.Marshal(i18n)

	return fmt.Sprintf(`<script>window.OD_LANGS=%s;window.OD_PAGE=%s;window.OD_I18N=%s;</script>`+"\n"+
		`<script defer src="%sassets/od/od-i18n.js"></script>`,
		langsJSON, pageJSON, i18nJSON, prefix)
}
