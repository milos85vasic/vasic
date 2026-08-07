package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
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
				"footer.text":      "© 2026 " + site.Brand + " — " + T(l, "footer.suffix") + ".",
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
