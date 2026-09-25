package main

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"
)

// ArgvPolicy is the adapter's OWN refusal of secret-shaped command lines, by
// NAME/SHAPE whatever the value (review T015b I1, T015c I1, T015d F1). The
// recorder stores argv VERBATIM, and the upstream credential scanner misses
// `pass=`, `token=`, short passwords, Bearer headers and URL credentials, so
// this runs BEFORE the command, in ONE process (linear in the total argument
// length).
//
// Every argument is NORMALISED (normalizeArg) before it is judged, so shell
// quoting and escaping inside a script body cannot hide a name from the policy:
// `'--password'`, `"--password"`, `\--password`, `$'--pass\x77ord'` and
// `-”p` all read as their plain form; ANSI-C escapes (`\xHH`, `\uHHHH`,
// `\UHHHHHHHH`, octal `\NNN`, `\c`) are decoded wherever they occur (more
// decoding only ever refuses more); zero-width and other format characters
// are removed; full-width ASCII is folded onto ASCII. When a flag or key NAME
// is judged, the Cyrillic/Greek letters that look like Latin ones are folded
// onto their Latin look-alikes first (`--раssword` reads `password`), and a
// NAME that mixes Latin with Cyrillic or Greek letters is refused as a
// look-alike whatever it spells (fail closed; a whole-script name such as
// `--файл` or a Latin name with diacritics such as `--größe` is not).
//
// Each normalised argument is then judged whole AND word by word (split on
// whitespace), so a secret inside a quoted script body (`sh -c 'sshpass -p X …'`)
// is seen; the words of all arguments form one sequence, so a flag's value may
// be the next word of the same argument or the next argument. Refused shapes:
//
//   - a flag word (`-x…`, `--name[=v]`) whose NAME is secret-shaped (secretName);
//   - `-p` / `-pVALUE` and `-P` / `-PVALUE` (single dash; `-P` is refused since
//     T015d — the case-sensitive exemption is withdrawn);
//   - `-u` / `--user` whose value holds `:` (`-u admin:pw`, `-uadmin:pw`,
//     `--user=a:b`);
//   - a secret-shaped KEY in ANY `key=value` / `key:value` segment of a word,
//     the segments being split on `= : , ; & ?` — INCLUDING a flag's value and
//     a URL query string (`DB_PASS=`, `MYSQL_PWD=`, `Cookie:`, `--build-arg=TOKEN=`,
//     `--header=Cookie:s=`, `--opt=a:b,token=`, `?access_token=`, `?key=`);
//   - `Authorization:` anywhere, `Bearer <word>`;
//   - URL credentials `scheme://user:pass@host`, and URL userinfo WITHOUT a
//     password `scheme://TOKEN@host` (a token-only URL) — except the exact
//     user `git@`, the conventional ssh user of git hosts.
//
// NOT caught, by construction: a value with no secret-shaped name, flag, key or
// URL around it (`redis-cli -a X`; `-a` is refused by NO rule, because it is
// ls/cp/rsync/grep/git territory and a blanket refusal would make the adapter
// unusable — the recipe is REDISCLI_AUTH in the environment); an obfuscated,
// encoded or computed secret (base64, `$(cat f)`, a value the check reads from
// a file or the environment at run time). The reason names the argument/word
// position and the rule — never the value.
func ArgvPolicy(args []string) (refused bool, reason string) {
	type word struct {
		arg, idx int
		w        string
	}
	var ws []word
	for i, a := range args {
		na := normalizeArg(a)
		low := strings.ToLower(na)
		if strings.Contains(low, "authorization:") {
			return true, fmt.Sprintf("argument %d carries an Authorization: header", i+1)
		}
		if urlCredRe.MatchString(na) {
			return true, fmt.Sprintf("argument %d carries URL credentials (scheme://user:pass@host)", i+1)
		}
		for _, m := range urlUserRe.FindAllStringSubmatch(na, -1) {
			if m[1] != "git" {
				return true, fmt.Sprintf("argument %d carries URL userinfo without a password (a token-only scheme://TOKEN@host)", i+1)
			}
		}
		for j, w := range strings.Fields(na) {
			ws = append(ws, word{i + 1, j + 1, w})
		}
	}
	at := func(k int) string { return fmt.Sprintf("argument %d word %d", ws[k].arg, ws[k].idx) }
	for k, x := range ws {
		w := x.w
		low := strings.ToLower(w)
		next := ""
		if k+1 < len(ws) {
			next = ws[k+1].w
		}
		if strings.Trim(low, `()[]{};,`) == "bearer" && next != "" {
			return true, at(k) + " is a Bearer token"
		}
		if len(w) >= 2 && w[0] == '-' && (w[1] == 'p' || w[1] == 'P') {
			return true, at(k) + " is the short option -p/-P (a common password flag)"
		}
		if w == "-u" || low == "--user" {
			if strings.Contains(next, ":") {
				return true, at(k) + " is -u/--user with a user:password value"
			}
		}
		if strings.HasPrefix(w, "-u") && !strings.HasPrefix(w, "--") && len(w) > 2 && strings.Contains(w[2:], ":") {
			return true, at(k) + " is -u with an attached user:password value"
		}
		if strings.HasPrefix(low, "--user=") && strings.Contains(w[len("--user="):], ":") {
			return true, at(k) + " is --user= with a user:password value"
		}
		if strings.HasPrefix(w, "-") && len(strings.TrimLeft(w, "-")) > 0 {
			name := strings.TrimLeft(low, "-")
			if i := strings.IndexAny(name, "=:"); i >= 0 {
				name = name[:i]
			}
			if why := nameRefused(name); why != "" {
				return true, at(k) + " is a flag with a " + why + " name"
			}
			// no `continue`: the flag's VALUE is judged by the key rule below
		}
		// Every key segment of the word: split on the list/pair separators;
		// a segment followed by `=` or `:` is a key, wherever it sits.
		for _, key := range keysOf(low) {
			if why := nameRefused(key); why != "" {
				return true, at(k) + " carries a " + why + " KEY in a key=value / key:value segment"
			}
		}
	}
	return false, ""
}

// keysOf returns every segment of w that is immediately followed by `=` or
// `:`, with leading dashes and bracketing punctuation removed.
func keysOf(w string) []string {
	var keys []string
	start := 0
	for i := 0; i < len(w); i++ {
		switch w[i] {
		case '=', ':', ',', ';', '&', '?':
			if w[i] == '=' || w[i] == ':' {
				if k := strings.TrimLeft(w[start:i], `-"'()[]{}<>`); k != "" {
					keys = append(keys, k)
				}
			}
			start = i + 1
		}
	}
	return keys
}

// nameRefused says why a flag/key NAME is refused: "" (acceptable),
// "secret-shaped" (after the confusables fold: `--раssword` with a Cyrillic
// р and а reads `password`), or "look-alike" (the UNFOLDED name mixes Latin
// with Cyrillic/Greek letters — a look-alike the fold table does not know).
// The mix is judged BEFORE the fold on purpose: folding a whole-script
// Cyrillic name such as `файл` would itself manufacture a mix.
func nameRefused(name string) string {
	if secretName(foldConfusables(name)) {
		return "secret-shaped"
	}
	if mixedScript(name) {
		return "look-alike (Latin mixed with Cyrillic/Greek letters)"
	}
	return ""
}

func foldConfusables(s string) string {
	return strings.Map(func(r rune) rune {
		if f, ok := confusables[r]; ok {
			return f
		}
		return r
	}, s)
}

// mixedScript reports whether a name holds both ASCII Latin letters and
// Cyrillic or Greek letters.
func mixedScript(name string) bool {
	latin, other := false, false
	for _, r := range name {
		switch {
		case r < utf8.RuneSelf && unicode.IsLetter(r):
			latin = true
		case unicode.Is(unicode.Cyrillic, r), unicode.Is(unicode.Greek, r):
			other = true
		}
	}
	return latin && other
}

// normalizeArg renders an argument as the policy judges it: shell quotes and
// escapes removed, ANSI-C escapes decoded, format characters dropped and
// confusable letters folded. It is deliberately MORE permissive than any
// shell (an unquoted `\x77` is decoded too): every extra decoding can only
// add a refusal, never hide one.
func normalizeArg(s string) string {
	s = strings.ReplaceAll(strings.ReplaceAll(s, `$'`, ""), `$"`, "")
	var b strings.Builder
	b.Grow(len(s))
	for i := 0; i < len(s); {
		c := s[i]
		switch {
		case c == '\'' || c == '"':
			i++
		case c == '\\' && i+1 < len(s):
			r, n := decodeEscape(s[i+1:])
			if r >= 0 {
				b.WriteRune(foldRune(rune(r)))
			}
			i += 1 + n
		default:
			r, n := utf8.DecodeRuneInString(s[i:])
			if !unicode.Is(unicode.Cf, r) {
				b.WriteRune(foldRune(r))
			}
			i += n
		}
	}
	return b.String()
}

// decodeEscape decodes the escape body after a backslash: \xHH, \uHHHH,
// \UHHHHHHHH, \NNN (octal), \n \t … ; any other `\c` is `c`. It returns the
// rune (-1 for none) and the number of bytes consumed after the backslash.
func decodeEscape(s string) (int, int) {
	hexN := func(max int) (int, int) {
		n := 0
		for n < max && n < len(s)-1 && isHex(s[1+n]) {
			n++
		}
		if n == 0 {
			return int(s[0]), 1
		}
		v, _ := strconv.ParseUint(s[1:1+n], 16, 32)
		return int(v), 1 + n
	}
	switch s[0] {
	case 'x':
		return hexN(2)
	case 'u':
		return hexN(4)
	case 'U':
		return hexN(8)
	case '0', '1', '2', '3', '4', '5', '6', '7':
		n := 0
		for n < 3 && n < len(s) && s[n] >= '0' && s[n] <= '7' {
			n++
		}
		v, _ := strconv.ParseUint(s[:n], 8, 32)
		return int(v), n
	}
	// Every other `\c` is `c` — the UNQUOTED reading, which is the one that
	// keeps a name intact (`--p\assword`, `--\token`): the control-character
	// reading of `\a`, `\t`, … would HIDE the letter, so it is never taken.
	r, n := utf8.DecodeRuneInString(s)
	return int(r), n
}

func isHex(c byte) bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

// foldRune maps full-width ASCII (U+FF01..U+FF5E, the NFKC compatibility
// forms) onto ASCII, so `－－token` is the flag `--token`. Script confusables
// are NOT folded here: see nameRefused.
func foldRune(r rune) rune {
	if r >= 0xFF01 && r <= 0xFF5E {
		return r - 0xFEE0
	}
	return r
}

var confusables = map[rune]rune{
	// Cyrillic lower/upper
	'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'у': 'y', 'х': 'x', 'і': 'i', 'ј': 'j', 'ѕ': 's',
	'ԁ': 'd', 'ԛ': 'q', 'ԝ': 'w', 'һ': 'h', 'ɡ': 'g', 'ԍ': 'g', 'ӏ': 'l', 'ъ': 'b', 'ь': 'b',
	'А': 'A', 'В': 'B', 'Е': 'E', 'К': 'K', 'М': 'M', 'Н': 'H', 'О': 'O', 'Р': 'P', 'С': 'C', 'Т': 'T',
	'Х': 'X', 'Ѕ': 'S', 'І': 'I', 'Ј': 'J', 'Ү': 'Y', 'Ԝ': 'W', 'Ԁ': 'D', 'Ԛ': 'Q', 'Ӏ': 'I',
	// Greek lower/upper
	'ο': 'o', 'ν': 'v', 'ρ': 'p', 'τ': 't', 'υ': 'u', 'ι': 'i', 'κ': 'k', 'α': 'a', 'ς': 's',
	'Α': 'A', 'Β': 'B', 'Ε': 'E', 'Ζ': 'Z', 'Η': 'H', 'Ι': 'I', 'Κ': 'K', 'Μ': 'M', 'Ν': 'N', 'Ο': 'O',
	'Ρ': 'P', 'Τ': 'T', 'Υ': 'Y', 'Χ': 'X',
}

var (
	urlCredRe = regexp.MustCompile(`[A-Za-z][A-Za-z0-9+.-]*://[^/@\s]+:[^/@\s]*@`)
	urlUserRe = regexp.MustCompile(`[A-Za-z][A-Za-z0-9+.-]*://([^/@\s:]+)@`)
	segRe     = regexp.MustCompile(`[^a-z0-9]+`)
	keyRe     = regexp.MustCompile(`(^|[^a-z0-9])(access|secret|private|api|auth|signing|encryption|master|client|session)[-_.]?keys?($|[^a-z0-9])`)
	// Words (not flags) that end in "pass" but name no password; the suffix
	// rule (storepass, keypass) must not refuse `--bypass` and friends.
	englishPass = map[string]bool{"bypass": true, "compass": true, "encompass": true, "overpass": true,
		"underpass": true, "trespass": true, "surpass": true}
	secretSubstr = []string{"secret", "password", "passwd", "passphrase", "token", "apikey", "api-key",
		"api_key", "credential", "cookie", "authoriz"}
)

// secretName reports whether a flag/variable NAME (lower-case) names a secret:
// it contains one of secretSubstr; or a segment (split on non-alphanumerics)
// is or starts with pass/pwd, or is `pw`; or a segment ENDS in pass/pwd
// (storepass, keypass, MYSQL_PWD) other than the English words above; or it is
// `key` itself or a qualified key (access-key, secret_key, apikey, …).
func secretName(name string) bool {
	n := strings.ToLower(name)
	for _, s := range secretSubstr {
		if strings.Contains(n, s) {
			return true
		}
	}
	for _, seg := range segRe.Split(n, -1) {
		switch {
		case seg == "":
		case seg == "pw", strings.HasPrefix(seg, "pass"), strings.HasPrefix(seg, "pwd"):
			return true
		case strings.HasSuffix(seg, "pwd"):
			return true
		case strings.HasSuffix(seg, "pass") && !englishPass[seg]:
			return true
		}
	}
	return n == "key" || n == "keys" || keyRe.MatchString(n)
}
