"""Token-aware keyword matching for the HR screen (T166, G-04).

The previous matcher squashed both strings to ``[0-9a-z]`` and tested
substrings, which made ``"We use Django"`` contain ``"Go"`` and
``"JavaScript"`` contain ``"Java"`` -- a gate that reports a missing term as
present is worse than no gate.  This module matches whole tokens.

Rules, in the order they matter:

* Both sides are NFKC-normalised, case-folded, stripped of joiners/bidi
  controls and de-hyphenated across line breaks (``Kuber-\\nnetes``).
* A token is a maximal run of letters, digits and combining marks (so a
  Devanagari word is one token, not one token per consonant), with a trailing
  ``+``/``++``/``#`` kept for ``C++``/``C#``.  Everything else separates.
* A keyword matches when its tokens appear as ADJACENT text tokens.  Token
  equality tolerates a plural ``s`` and a trailing version number
  (``python3`` is Python), and the joined form tolerates ``Node.js``/``NodeJS``.
* Scripts written without spaces (Han, kana, Thai, ...) have no tokens to
  compare, so for them the match is a squashed substring test.  Hangul keeps
  spaces but attaches particles to the noun, so there a keyword token matches
  as a PREFIX of a text token.
* Synonym groups make ``Go``/``Golang`` and ``k8s``/``Kubernetes`` the same
  term in both directions.  Callers may add groups; the table never widens
  matching to substrings.
"""
from __future__ import annotations

import unicodedata
from typing import Iterable, List, Sequence, Tuple

#: Phrases that name the same thing.  Each group is mutually interchangeable.
#: Curated and deliberately small: every entry is a term a posting and a CV
#: write differently for the same technology.
SYNONYM_GROUPS: Tuple[Tuple[str, ...], ...] = (
    ("go", "golang"),
    ("kubernetes", "k8s"),
    ("aws", "amazon web services"),
    ("gcp", "google cloud platform", "google cloud"),
    ("azure", "microsoft azure"),
    ("postgres", "postgresql"),
    ("javascript", "js", "ecmascript"),
    ("typescript", "ts"),
    ("node.js", "nodejs", "node"),
    ("react", "reactjs", "react.js"),
    ("vue", "vuejs", "vue.js"),
    ("c#", "csharp", "c sharp"),
    (".net", "dotnet"),
    ("ci/cd", "cicd", "continuous integration"),
    ("machine learning", "ml"),
    ("large language model", "llm"),
    ("natural language processing", "nlp"),
    ("infrastructure as code", "iac"),
    ("restful api", "rest api", "rest"),
    ("mongodb", "mongo"),
    ("elasticsearch", "elastic search"),
)

_STRIP = {0x00AD, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F,
          0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069}

#: Scripts with no inter-word spaces: compared as a squashed substring.
_UNSPACED = ((0x2E80, 0x9FFF), (0xF900, 0xFAFF), (0x3040, 0x30FF), (0x0E00, 0x0EFF),
             (0x0E80, 0x0EFF), (0x1000, 0x109F), (0x1780, 0x17FF), (0x0F00, 0x0FFF),
             (0x20000, 0x2FA1F))
_HANGUL = ((0xAC00, 0xD7A3), (0x1100, 0x11FF), (0x3130, 0x318F))


def _in(ch: str, ranges: Iterable[Tuple[int, int]]) -> bool:
    o = ord(ch)
    return any(lo <= o <= hi for lo, hi in ranges)


def _norm(text: str) -> str:
    s = unicodedata.normalize("NFKC", str(text or "")).casefold()
    s = s.replace("-\n", "").replace("‐\n", "")
    return "".join(c for c in s if ord(c) not in _STRIP)


def tokenize(text: str) -> List[str]:
    """Normalised tokens of ``text`` (see the module docstring)."""
    s = _norm(text)
    out: List[str] = []
    cur: List[str] = []
    i, n = 0, len(s)
    while i < n:
        ch = s[i]
        cat = unicodedata.category(ch)
        if cat[0] in "LNM":
            cur.append(ch)
        else:
            if cur:
                # C++ / C# : a symbol suffix belongs to the token only when it
                # directly follows it and is not itself followed by a letter.
                if ch == "+" and cur:
                    j = i
                    while j < n and s[j] == "+" and j - i < 2:
                        j += 1
                    if j >= n or unicodedata.category(s[j])[0] not in "LN":
                        cur.append(s[i:j])
                        i = j - 1
                elif ch == "#" and (i + 1 >= n or unicodedata.category(s[i + 1])[0] not in "LN"):
                    cur.append("#")
                out.append("".join(cur))
                cur = []
        i += 1
    if cur:
        out.append("".join(cur))
    return out


def _squash(s: str) -> str:
    return "".join(c for c in _norm(s) if unicodedata.category(c)[0] in "LN")


def _tok_eq(text_tok: str, kw_tok: str) -> bool:
    if text_tok == kw_tok:
        return True
    if len(kw_tok) > 2 and text_tok == kw_tok + "s":
        return True
    if len(text_tok) > 2 and text_tok + "s" == kw_tok:
        return True
    # python3 / java17: a version number does not make it another technology.
    if (len(kw_tok) >= 2 and kw_tok.isalpha() and text_tok.startswith(kw_tok)
            and text_tok[len(kw_tok):].isdigit()):
        return True
    return False


def _hangul_prefix(text_tok: str, kw_tok: str) -> bool:
    return len(kw_tok) >= 2 and text_tok.startswith(kw_tok) and any(_in(c, _HANGUL) for c in kw_tok)


def _match_tokens(text_toks: Sequence[str], kw_toks: Sequence[str]) -> bool:
    n, m = len(text_toks), len(kw_toks)
    if not m:
        return True
    for i in range(0, n - m + 1):
        if all(_tok_eq(text_toks[i + j], kw_toks[j]) or _hangul_prefix(text_toks[i + j], kw_toks[j])
               for j in range(m)):
            return True
    # Node.js vs NodeJS: the same letters, split differently by punctuation.
    joined = "".join(kw_toks)
    if len(joined) >= 4:
        for i in range(n):
            acc = ""
            for span in range(1, 6):
                if i + span > n:
                    break
                acc += text_toks[i + span - 1]
                if (m > 1 or span > 1) and (acc == joined or _tok_eq(acc, joined)):
                    return True
                if len(acc) > len(joined) + 1:
                    break
    return False


def _variants(keyword: str, synonyms: Iterable[Sequence[str]]) -> List[List[str]]:
    base = tokenize(keyword)
    out = [base]
    for group in (*SYNONYM_GROUPS, *[tuple(g) for g in synonyms]):
        toks = [tokenize(g) for g in group]
        if base in toks or any(_joined_eq(base, t) for t in toks):
            out.extend(t for t in toks if t and t not in out)
    return out


def _joined_eq(a: Sequence[str], b: Sequence[str]) -> bool:
    return "".join(a) == "".join(b) and len("".join(a)) >= 4


def has_keyword(text: str, keyword: str, synonyms: Iterable[Sequence[str]] = ()) -> bool:
    """True when ``keyword`` (or a synonym) is present in ``text`` as whole tokens."""
    if not keyword or not _squash(keyword):
        return True
    if any(_in(c, _UNSPACED) for c in _norm(keyword)):
        return _squash(keyword) in _squash(text)
    text_toks = tokenize(text)
    return any(_match_tokens(text_toks, v) for v in _variants(keyword, synonyms) if v)
