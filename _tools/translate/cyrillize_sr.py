#!/usr/bin/env python3
"""Serbian LATIN -> Serbian CYRILLIC transliterator for the content pipeline (#62).

Serbian is a digraphia language: Latin (gajica) and Cyrillic (vukovica) are a
LOSSLESS 1:1 mapping. This tool converts already-translated Serbian *prose* from
Latin to Cyrillic while PRESERVING everything that must stay Latin:

  * glossary.json non-translatable terms (products / brands / tech / acronyms),
  * fenced ```code``` blocks and `inline code`,
  * URLs, email addresses, markdown link/image DESTINATIONS (targets),
  * HTML tags and their attributes,
  * YAML front-matter (kept verbatim — matches the RU/other-lang convention
    where front-matter stays English and only the BODY is localized),
  * JSON keys and structural/identifier VALUES (href/class/id/slug/i18n/...).

Transliteration correctness:
  * DIGRAPHS FIRST — Dž/dž->Џ/џ, Lj/lj->Љ/љ, Nj/nj->Њ/њ (all case variants) —
    then the single-letter map incl. č ć š ž đ. Doing digraphs first is what
    makes 'nj'->'њ' (one letter) instead of 'н'+'ј'.
  * Latin letters with no Serbian Cyrillic equivalent (q w x y) are left as-is.

Modes:
  md    FILE...   transliterate the markdown BODY in place (front-matter kept)
  json  FILE...   transliterate only PROSE string VALUES in place (keys/ids kept)
  text            transliterate stdin -> stdout (raw, glossary-protected)

Idempotent: already-Cyrillic text is untouched (only Latin letters are mapped),
so re-running is safe.
"""
import argparse, json, os, re, sys

GLOSSARY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "glossary.json")

# ---- transliteration tables -------------------------------------------------
# Digraphs handled BEFORE singles. Order: all-caps, title, lower for each.
_DIGRAPHS = [
    ("DŽ", "Џ"), ("Dž", "Џ"), ("dž", "џ"),
    ("LJ", "Љ"), ("Lj", "Љ"), ("lj", "љ"),
    ("NJ", "Њ"), ("Nj", "Њ"), ("nj", "њ"),
]
_SINGLE = {
    "A": "А", "B": "Б", "V": "В", "G": "Г", "D": "Д", "Đ": "Ђ", "E": "Е",
    "Ž": "Ж", "Z": "З", "I": "И", "J": "Ј", "K": "К", "L": "Л", "M": "М",
    "N": "Н", "O": "О", "P": "П", "R": "Р", "S": "С", "T": "Т", "Ć": "Ћ",
    "U": "У", "F": "Ф", "H": "Х", "C": "Ц", "Č": "Ч", "Š": "Ш",
    "a": "а", "b": "б", "v": "в", "g": "г", "d": "д", "đ": "ђ", "e": "е",
    "ž": "ж", "z": "з", "i": "и", "j": "ј", "k": "к", "l": "л", "m": "м",
    "n": "н", "o": "о", "p": "п", "r": "р", "s": "с", "t": "т", "ć": "ћ",
    "u": "у", "f": "ф", "h": "х", "c": "ц", "č": "ч", "š": "ш",
}
_SINGLE_TAB = {ord(k): v for k, v in _SINGLE.items()}


def translit(text):
    for lat, cyr in _DIGRAPHS:
        text = text.replace(lat, cyr)
    return text.translate(_SINGLE_TAB)


# ---- glossary ---------------------------------------------------------------
def load_terms(path):
    with open(path, encoding="utf-8") as f:
        g = json.load(f)
    terms, seen = [], set()
    for val in g.values():
        if not isinstance(val, list):
            continue
        for t in val:
            if isinstance(t, str) and t and t not in seen:
                seen.add(t)
                terms.append(t)
    terms.sort(key=lambda s: (-len(s), s))
    return terms


_TERMS = load_terms(GLOSSARY)

# ---- SR-local extra non-translatable terms ----------------------------------
# Serbian gajica uses NONE of q w x y, so ANY Latin run containing one is, with
# certainty, a foreign token -> those are protected generically (see protect()).
# This supplements that rule with genuine foreign proper nouns / products / tech
# acronyms that happen to be qwxy-FREE (so the generic rule can't catch them) and
# would otherwise mangle into non-standard Cyrillic (e.g. Confluence->Цонфлуенце).
# Kept LOCAL to Serbian transliteration (NOT added to the shared glossary.json)
# so other languages' translations/reviews are unaffected. Case-sensitive,
# whole-token, longest-first (same matching contract as the glossary).
_SR_EXTRA = [
    # OS / platforms / distros
    "Android", "iOS", "iPadOS", "macOS", "tvOS", "watchOS", "AndroidTV",
    "AOSP", "Ubuntu", "Debian", "Fedora", "CentOS", "Deepin", "openEuler",
    "openSUSE", "AlmaLinux", "ROSA", "Astra", "Aurora OS", "HarmonyOS",
    "Apple", "Steam", "PlayStation",
    # dev tools / platforms / brands
    "Confluence", "Jira", "Java", "DevOps", "GitOps", "OpenCV", "GoCV",
    "ClickUp", "GitVerse", "Gitee", "Gitea", "Forgejo", "SourceHut",
    "Bitbucket", "CodeCommit", "Mermaid", "Nvidia", "CUDA", "ROCm",
    "Terraform", "Kustomize", "Ansible", "Consul", "Nomad", "Vault",
    "HashiCorp", "Postgres", "CockroachDB", "FoundationDB", "NATS",
    "JetStream", "Loki", "Jaeger", "Tempo", "Mimir", "Telegram", "Discord",
    "Slack", "Uber", "Meta", "Node", "Deno", "Bun", "Vite", "Astro",
    "Svelte", "Remix", "Docusaurus", "Cobra", "Viper", "Logrus",
    "Lumberjack", "Caffeine", "Gorilla", "Pion", "Merkle", "Raft", "Falco",
    "Rego", "Sieve", "Dovecot", "OpenSSH", "OpenSSL", "OpenAPI", "OpenCode",
    "EventBus", "EventStream", "StepGUI", "RateLimiter", "ToolSchema",
    "VectorDB", "MusicBrainz", "ScreenCaptureKit", "IOKit", "ClassAd",
    "SpecKit", "RedTeam", "BusRide", "SekurMail", "SekurMessenger",
    "SekurSuite", "Sekur", "SambaNova", "RunPod", "Akash", "Chutes", "Kimi",
    "GPT", "Cursor", "Junie", "Aider", "Cline", "Crush", "LangChain",
    "ReAct", "Karma", "Jasmine", "Cobra", "Herbrugg",
    # crypto / algorithms
    "ChaCha20", "Salsa20", "Ed25519", "EdDSA", "HMAC", "HKDF", "AEAD",
    "AES", "GCM", "HS256", "SHA256", "SHA512", "SHA1", "KEM",
    # tech acronyms (kept Latin in Serbian technical writing)
    "PKI", "HSM", "RBAC", "OIDC", "SAML", "SSO", "LDAP", "CORS", "CPU",
    "CRDT", "DAG", "TDD", "BDD", "TUI", "GUI", "BFS", "DFS", "HPC", "DST",
    "SLO", "SLA", "TTL", "LRU", "MTU", "NAS", "SMB", "NFS", "FTP", "FTPS",
    "SFTP", "CIFS", "SSE", "SSM", "ADR", "ANR", "ADB", "TAP", "GSD",
    "DPAPI", "NTLM", "HSTS", "E2EE", "FIDO2", "SPIFFE", "SPIRE", "STONITH",
    "SBD", "IPMI", "KRaft", "G1GC", "JVM", "FFI", "DOM", "JSONL", "CSV",
    "TSV", "EPUB", "FB2", "PNG", "JPEG", "MP3", "WAV", "OPA", "MVP",
    "SaaS", "PaaS", "IaaS", "TCO", "ROI", "SOC", "OAuth2", "OAuth",
    "GA", "HA", "VM", "OS", "ISO", "UI", "TV", "PC", "IP", "LAN", "VLAN",
    "RLHF", "SGLang", "TMDB", "TVDB", "IMDB", "NVENC", "P1", "L0", "L7",
    "AMD", "GCP", "EC2", "CC", "ELK", "SDD", "SSoT", "SIGKILL", "SIGTERM",
    "Brotli", "Zig", "D3",
    # GitHub org / repo identifiers (hyphenated variants of glossary brands) and
    # handles that appear verbatim in contact/body prose and must stay Latin.
    "vasic-digital", "Server-Factory", "Helix-Track", "Mail-Server-Factory",
    "milos85vasic", "Tree-of-Thoughts", "Increment-Loop",
]
_TERMS = sorted(set(_TERMS) | set(_SR_EXTRA), key=lambda s: (-len(s), s))

# ---- protection (sentinel = PUA + digits + PUA; survives translit) ----------
_SENT_OPEN, _SENT_CLOSE = "", ""
_SENT_RE = re.compile(_SENT_OPEN + r"(\d+)" + _SENT_CLOSE)


class Protector:
    def __init__(self):
        self.store = []

    def _sub(self, s):
        idx = len(self.store)
        self.store.append(s)
        return _SENT_OPEN + str(idx) + _SENT_CLOSE

    def protect(self, text, markdown=True):
        # 1) fenced code blocks, then inline code
        text = re.sub(r"```.*?```", lambda m: self._sub(m.group(0)), text, flags=re.DOTALL)
        text = re.sub(r"`[^`]*`", lambda m: self._sub(m.group(0)), text)
        if markdown:
            # 2) markdown link/image DESTINATIONS: keep [label], protect (target)
            text = re.sub(r"\]\(([^)]*)\)",
                          lambda m: "]" + self._sub("(" + m.group(1) + ")"), text)
            # 3) autolinks <url>
            text = re.sub(r"<https?://[^>\s]+>", lambda m: self._sub(m.group(0)), text)
        # 4) HTML tags FIRST (attrs stay Latin) — so a URL/email inside a tag
        #    (e.g. <a href="mailto:x@y">) is swallowed whole and never re-matched
        #    by the URL/email rules below (avoids nested sentinels).
        text = re.sub(r"</?[A-Za-z][^>]*>", lambda m: self._sub(m.group(0)), text)
        text = re.sub(r"&[A-Za-z]+;|&#\d+;", lambda m: self._sub(m.group(0)), text)
        # 5) bare URLs
        text = re.sub(r"https?://[^\s)>\]}\"']+", lambda m: self._sub(m.group(0)), text)
        text = re.sub(r"\b(?:mailto|tel):[^\s)>\]}\"']+", lambda m: self._sub(m.group(0)), text)
        # 6) emails
        text = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
                      lambda m: self._sub(m.group(0)), text)
        # 7) glossary + SR-extra terms (whole-token, case-sensitive, longest-first)
        for term in _TERMS:
            pat = re.compile(r"(?<![A-Za-z0-9])" + re.escape(term) + r"(?![A-Za-z0-9])")
            text = pat.sub(lambda m: self._sub(m.group(0)), text)
        # 8) GENERIC foreign-token guard: Serbian gajica never uses q/w/x/y, so any
        #    remaining alphanumeric run containing one is a foreign word/name ->
        #    keep it verbatim in Latin (prevents mixed-script mangling like
        #    framework->Фрамеwорк, proxy->проxy, Linux->Линуx).
        text = re.sub(r"[A-Za-z0-9]*[QWXYqwxy][A-Za-z0-9]*",
                      lambda m: self._sub(m.group(0)), text)
        return text

    def restore(self, text):
        # Iterate: a restored span may itself contain a sentinel (nested
        # protection), so keep expanding until no sentinel remains.
        for _ in range(10):
            if not _SENT_RE.search(text):
                break
            text = _SENT_RE.sub(lambda m: self.store[int(m.group(1))], text)
        return text


def cyrillize_prose(text, markdown=True):
    p = Protector()
    protected = p.protect(text, markdown=markdown)
    return p.restore(translit(protected))


# ---- markdown: body only (front-matter preserved verbatim) ------------------
def split_frontmatter(text):
    if text.startswith("---\n") or text.startswith("---\r\n"):
        lines = text.split("\n")
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                head = "\n".join(lines[:i + 1]) + "\n"
                body = "\n".join(lines[i + 1:])
                return head, body
    return "", text


def process_md(path):
    text = open(path, encoding="utf-8").read()
    head, body = split_frontmatter(text)
    new = head + cyrillize_prose(body, markdown=True)
    if new != text:
        open(path, "w", encoding="utf-8").write(new)
    return new != text


# ---- json: prose values only (keys + identifier values preserved) -----------
# Values under these keys are DISPLAY prose -> transliterate.
_PROSE_KEYS = {"title", "description", "footer", "label", "text", "name",
               "value", "tagline", "lede", "eyebrow", "note", "alt",
               "heading", "subtitle", "body", "caption"}
# NOTE: "html" is intentionally EXCLUDED — in these home files every html value is
# pure contact-link markup (mailto/GitHub/Telegram anchors whose visible label is a
# URL/handle, not prose). Transliterating it only corrupts URL labels
# (github.com -> гитхуб.цом), so html is left verbatim.
# Everything else (site/kind/lang/css/class/href/i18n/icon/id/slug/type/
# variant/nameI18n/dl/grid/ctaStyle/brand/...) is an identifier/enum -> keep.


def _walk_json(obj, key=None):
    if isinstance(obj, dict):
        return {k: _walk_json(v, k) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_walk_json(v, key) for v in obj]
    if isinstance(obj, str) and key in _PROSE_KEYS:
        # html values contain markup -> protect tags; not markdown-link syntax
        return cyrillize_prose(obj, markdown=False)
    return obj


def process_json(path):
    raw = open(path, encoding="utf-8").read()
    data = json.loads(raw)
    new = json.dumps(_walk_json(data), ensure_ascii=False, indent=2)
    if new != raw:
        open(path, "w", encoding="utf-8").write(new)
    return new != raw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["md", "json", "text"])
    ap.add_argument("files", nargs="*")
    a = ap.parse_args()
    if a.mode == "text":
        sys.stdout.write(cyrillize_prose(sys.stdin.read(), markdown=True))
        return
    changed = 0
    for f in a.files:
        fn = process_md if a.mode == "md" else process_json
        if fn(f):
            changed += 1
            print("[cyrillize] updated %s" % f)
        else:
            print("[cyrillize] unchanged %s" % f)
    print("[cyrillize] %d/%d files changed" % (changed, len(a.files)))


if __name__ == "__main__":
    main()
