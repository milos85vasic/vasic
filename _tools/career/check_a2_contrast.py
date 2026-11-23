#!/usr/bin/env python3
"""WCAG contrast check for the Aurora Atlas v2 (--a2-*) tokens.

Parses a CSS file (default: design-system/brand-milosvasic/milosvasic.css),
resolves the --a2-* tokens per theme (light = bare :root; dark = the
:root[data-theme="dark"] block AND the prefers-color-scheme block, which must
agree) for the default accent and for every [data-area] accent, then checks:

  text      --a2-text, --a2-text-muted, --a2-accent (used as text)  >= 4.5:1
            against --a2-bg, --a2-surface, --a2-surface-2
  filled    --a2-accent-on on --a2-accent                          >= 4.5:1
  non-text  --a2-accent on --a2-bg / --a2-surface                  >= 3:1
  parity    hex fallback and oklch value of a token describe the same colour
  cascade   every area has a dark-theme rule via BOTH dark selector forms

Exit 0 all clear, 1 findings, 2 could not determine. Optional 2nd arg: a second
CSS path that must be byte-identical to the first (single-source-of-truth).
"""
import math, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT = ROOT / "design-system/brand-milosvasic/milosvasic.css"

def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lin_to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def oklch_to_rgb(L, C, h):
    a = C * math.cos(math.radians(h)); b = C * math.sin(math.radians(h))
    l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
    g = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
    bl = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_
    return (lin_to_srgb(r), lin_to_srgb(g), lin_to_srgb(bl))

def parse_color(v):
    v = v.strip()
    m = re.fullmatch(r"#([0-9a-fA-F]{6})", v)
    if m:
        n = int(m.group(1), 16)
        return ((n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255)
    m = re.fullmatch(r"#([0-9a-fA-F]{3})", v)
    if m:
        return tuple(int(ch * 2, 16) / 255 for ch in m.group(1))
    m = re.fullmatch(r"oklch\(\s*([\d.]+)%\s+([\d.]+)\s+([\d.]+)\s*\)", v)
    if m:
        return oklch_to_rgb(float(m.group(1)) / 100, float(m.group(2)), float(m.group(3)))
    return None

def lum(rgb):
    r, g, b = (srgb_to_lin(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

def strip_comments(s):
    return re.sub(r"/\*.*?\*/", "", s, flags=re.S)

def parse_rules(css, ctx=""):
    """Yield (ctx, selector, {prop: [values...]}) walking @media nesting."""
    i, n = 0, len(css)
    while i < n:
        j = css.find("{", i)
        if j < 0: break
        sel = css[i:j].strip()
        depth, k = 1, j + 1
        while k < n and depth:
            depth += {"{": 1, "}": -1}.get(css[k], 0); k += 1
        body = css[j + 1:k - 1]
        if sel.startswith("@media") or sel.startswith("@supports"):
            yield from parse_rules(body, ctx + "|" + sel)
        elif sel.startswith("@"):
            pass
        else:
            decls = {}
            for d in body.split(";"):
                if ":" in d:
                    p, v = d.split(":", 1)
                    decls.setdefault(p.strip(), []).append(v.strip())
            yield ctx, sel, decls
        i = k

DARK_MQ = "(prefers-color-scheme: dark)"
def split_sel(sel): return [s.strip() for s in sel.split(",")]

OPACITY_FLOOR = 1.0  # no animation on a text-bearing selector may dip below this
PARITY_TOL = 0.005  # measured max hex-vs-oklch drift is 0.0019 (2026-11-23); was 0.02
DECORATIVE = re.compile(r"::?(before|after)\s*$")

def check_motion_opacity(css):
    """Static rule: every @keyframes used by an `animation`/`animation-name`
    declaration on a text-bearing selector (anything not a ::before/::after
    pseudo) must keep opacity >= OPACITY_FLOOR in every frame. Returns findings."""
    frames = {}
    for m in re.finditer(r"@keyframes\s+([\w-]+)\s*\{", css):
        depth, k = 1, m.end()
        while k < len(css) and depth:
            depth += {"{": 1, "}": -1}.get(css[k], 0); k += 1
        ops = [float(x) for x in re.findall(r"(?<![-\w])opacity\s*:\s*([\d.]+)", css[m.end():k - 1])]
        frames[m.group(1)] = min(ops) if ops else None
    out = []
    def walk(body):
        for ctx, sel, decls in parse_rules(body):
            for prop in ("animation", "animation-name"):
                for v in decls.get(prop, []):
                    # A known @keyframes name may sit in ANY position of the value
                    # ("1s ease fade-in", "fade-in 1s", multi-animation lists).
                    for name in dict.fromkeys(t for t in re.split(r"[\s,]+", v) if t in frames):
                      lo = frames.get(name)
                      if lo is not None and lo < OPACITY_FLOOR:
                        for s_ in split_sel(sel):
                            if not DECORATIVE.search(s_):
                                out.append(f"motion-opacity: {s_} animates {name} down to opacity {lo} < {OPACITY_FLOOR} (text-bearing)")
    walk(css)
    return out

def main():
    path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"CANNOT DETERMINE: {e}"); return 2
    rules = list(parse_rules(strip_comments(raw)))
    A2 = lambda d: {p: v for p, v in d.items() if p.startswith("--a2-")}
    fails, checks = [], 0

    light_base, dark_form = {}, {"attr": {}, "media": {}}
    light_area, dark_area = {}, {"attr": {}, "media": {}}
    for ctx, sel, decls in rules:
        d = A2(decls)
        if not d: continue
        is_dark_mq = DARK_MQ in ctx
        for s in split_sel(sel):
            m = re.fullmatch(r'\[data-area="([^"]+)"\]', s)
            if m and not is_dark_mq:
                light_area.setdefault(m.group(1), {}).update(d); continue
            if s == ":root" and not is_dark_mq:
                for p, v in d.items(): light_base.setdefault(p, []).extend(v)
                continue
            for form, pre, cond in (("attr", ':root[data-theme="dark"]', not is_dark_mq),
                                    ("media", ':root:not([data-theme="light"])', is_dark_mq)):
                if not cond: continue
                if s == pre:
                    for p, v in d.items(): dark_form[form].setdefault(p, []).extend(v)
                    break
                m = re.fullmatch(re.escape(pre) + r'\s+\[data-area="([^"]+)"\]', s)
                if m:
                    dark_area[form].setdefault(m.group(1), {}).update(d); break
    if not light_base or "--a2-accent" not in light_base:
        print("CANNOT DETERMINE: no --a2-* :root block found"); return 2

    areas = sorted(light_area)
    def last(vals): return vals[-1] if vals else None
    def variants(vals):
        hexes = [v for v in vals if v.startswith("#")]
        oks = [v for v in vals if v.startswith("oklch(")]
        return [x for x in (hexes[-1:] + oks[-1:])]

    def theme_tokens(theme, form, area):
        t = {p: list(v) for p, v in light_base.items()}
        if theme == "dark":
            for p, v in dark_form[form].items(): t[p] = list(v)
        if area:
            for p, v in light_area.get(area, {}).items(): t[p] = list(v)
            if theme == "dark":
                for p, v in dark_area[form].get(area, {}).items(): t[p] = list(v)
        return t

    for form in ("attr", "media"):
        for a in areas:
            if a not in dark_area[form]:
                fails.append(f"cascade: area {a!r} has no dark rule in the {form} form"); 
        for p, v in dark_form[form].items():
            pass
    # the two dark forms must agree token for token
    for a in [None] + areas:
        ta, tm = theme_tokens("dark", "attr", a), theme_tokens("dark", "media", a)
        for p in sorted(set(ta) | set(tm)):
            if p in ("--a2-accent-muted", "--a2-focus-ring"): continue
            if variants(ta.get(p, [])) != variants(tm.get(p, [])):
                fails.append(f"parity: dark forms disagree on {p} for {a or 'default'}")

    def col(t, name, idx):
        vs = variants(t.get(name, []))
        c = parse_color(vs[idx]) if idx < len(vs) else None
        return c, (vs[idx] if idx < len(vs) else None)

    for theme in ("light", "dark"):
        for a in [None] + areas:
            t = theme_tokens(theme, "attr", a)
            label = f"{theme}/{a or 'default'}"
            # hex-vs-oklch agreement for every colour token
            for name in ("--a2-bg", "--a2-surface", "--a2-surface-2", "--a2-text",
                         "--a2-text-muted", "--a2-border", "--a2-accent"):
                vs = variants(t.get(name, []))
                if len(vs) == 2:
                    ch, co = parse_color(vs[0]), parse_color(vs[1])
                    checks += 1
                    if max(abs(x - y) for x, y in zip(ch, co)) > PARITY_TOL:
                        fails.append(f"parity: {label} {name} hex {vs[0]} != oklch {vs[1]}")
            for idx in (0, 1):
                bgs = {n: col(t, n, idx) for n in ("--a2-bg", "--a2-surface", "--a2-surface-2")}
                def pair(fg_name, bg_name, need, kind):
                    nonlocal checks
                    fg, fgv = col(t, fg_name, idx) if fg_name != "--a2-accent-on" else (parse_color(last(t["--a2-accent-on"])), last(t["--a2-accent-on"]))
                    bg, bgv = (bgs[bg_name] if bg_name in bgs else col(t, bg_name, idx))
                    if fg is None or bg is None:
                        fails.append(f"undetermined: {label} {fg_name}/{bg_name} variant {idx}"); return
                    r = ratio(fg, bg); checks += 1
                    if r < need:
                        fails.append(f"{kind}: {label} {fg_name} {fgv} on {bg_name} {bgv} = {r:.2f}:1 < {need}")
                for fg in ("--a2-text", "--a2-text-muted", "--a2-accent"):
                    for bg in bgs: pair(fg, bg, 4.5, "text")
                pair("--a2-accent-on", "--a2-accent", 4.5, "filled")
                for bg in ("--a2-bg", "--a2-surface"): pair("--a2-accent", bg, 3.0, "non-text")

    mo = check_motion_opacity(strip_comments(raw)); checks += 1
    fails.extend(mo)

    if len(sys.argv) > 2:
        other = pathlib.Path(sys.argv[2])
        checks += 1
        if not other.exists() or other.read_bytes() != path.read_bytes():
            fails.append(f"single-source: {other} differs from {path}")

    for f in fails: print("FAIL", f)
    print(f"{'FAIL' if fails else 'PASS'}: {checks} checks, {len(fails)} finding(s), "
          f"{len(areas)} areas x 2 themes")
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main())
