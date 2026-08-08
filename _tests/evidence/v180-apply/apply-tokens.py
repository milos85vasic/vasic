#!/usr/bin/env python3
"""
Surgical --od-* token VALUE replacement (Helix v180-apply).

Applies the brand-anchored hybrid candidate token VALUES onto the live MACHINA
brand CSS, block-for-block, WITHOUT touching component/effect CSS, comments,
ordering, or the --vd-* MACHINA knobs.

For each of the three token blocks the candidate defines
  (1) :root { }
  (2) :root[data-theme="dark"] { }
  (3) @media (prefers-color-scheme:dark){ :root:not([data-theme="light"]) { } }
we:
  - replace the VALUE of every --od-* token that both the candidate block and
    the matching live block define (value = text between ':' and ';'; any
    trailing inline comment after ';' is preserved byte-for-byte),
  - APPEND (before the block's closing brace, at the block's own indent) any
    --od-* token the candidate block defines that the live block lacks,
  - leave every other declaration (incl. --vd-*, --od-shadow-lg overrides the
    candidate doesn't define, etc.) untouched.

Deterministic, idempotent, no third-party deps. Prints a full audit.
"""
import re
import sys

CAND = "/Volumes/T7/Projects/vasic/design-toolkit/proposed/vasic-digital.od-tokens.css"
LIVE = "/Volumes/T7/Projects/vasic/design-system/brand-vasic-digital/vasic-digital.css"

# (name, header-regex) for each block, in cascade order.
BLOCKS = [
    ("root",  re.compile(r'(?m)^:root\s*\{')),
    ("dark",  re.compile(r'(?m)^:root\[data-theme="dark"\]\s*\{')),
    ("media", re.compile(r'(?m)^[ \t]*:root:not\(\[data-theme="light"\]\)\s*\{')),
]

DECL = re.compile(r'--([A-Za-z0-9-]+)\s*:\s*([^;]*);')


def find_block(text, header_re):
    """Return (start_of_body, end_of_body_excl_brace, body_text) for the
    brace-matched block whose opening brace follows the header match."""
    m = header_re.search(text)
    if not m:
        raise SystemExit(f"header not found: {header_re.pattern}")
    brace = text.index('{', m.start())
    depth = 0
    i = brace
    while i < len(text):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return brace + 1, i, text[brace + 1:i]
        i += 1
    raise SystemExit("unbalanced braces")


def parse_od_tokens(body):
    """Ordered dict of --od-* tokens -> value, as defined in a block body."""
    out = {}
    for name, val in DECL.findall(body):
        if name.startswith("od-"):
            out["--" + name] = val.strip()
    return out


def block_indent(body):
    """Detect the leading-whitespace indent of declarations in this block."""
    m = re.search(r'(?m)^([ \t]+)--od-', body)
    return m.group(1) if m else "  "


def main():
    with open(CAND, encoding="utf-8") as f:
        cand_text = f.read()
    with open(LIVE, encoding="utf-8") as f:
        live_text = f.read()

    # candidate token maps per block
    cand_maps = {}
    for name, hre in BLOCKS:
        _, _, body = find_block(cand_text, hre)
        cand_maps[name] = parse_od_tokens(body)

    total_changed = 0
    total_same = 0
    total_added = 0
    audit = []

    # Rebuild the live text block by block. Because appends change offsets, we
    # process blocks left-to-right and re-locate each block in the mutated text.
    for name, hre in BLOCKS:
        b_start, b_end, body = find_block(live_text, hre)
        live_tokens = parse_od_tokens(body)
        indent = block_indent(body)
        new_body = body

        for tok, newval in cand_maps[name].items():
            if tok in live_tokens:
                oldval = live_tokens[tok]
                if oldval == newval:
                    total_same += 1
                    continue
                # replace value between ':' and ';' for THIS token only (1st hit)
                pat = re.compile(r'(' + re.escape(tok) + r'\s*:\s*)([^;]*)(;)')
                def _sub(mm):
                    return mm.group(1) + newval + mm.group(3)
                new_body, n = pat.subn(_sub, new_body, count=1)
                if n != 1:
                    raise SystemExit(f"[{name}] failed to replace {tok}")
                total_changed += 1
                audit.append(f"  [{name}] {tok}: {oldval}  ->  {newval}")

        # append tokens present in candidate block but missing from live block
        missing = [t for t in cand_maps[name] if t not in live_tokens]
        if missing:
            add_lines = "".join(
                f"{indent}{t}: {cand_maps[name][t]};\n" for t in missing
            )
            # insert right before the block's closing brace, preserving the
            # newline+indent that precedes the '}'.
            if not new_body.endswith("\n"):
                new_body = new_body + "\n"
            new_body = new_body + add_lines
            for t in missing:
                total_added += 1
                audit.append(f"  [{name}] +ADD {t}: {cand_maps[name][t]}")

        live_text = live_text[:b_start] + new_body + live_text[b_end:]

    with open(LIVE, "w", encoding="utf-8") as f:
        f.write(live_text)

    print("=== v180-apply token audit ===")
    for line in audit:
        print(line)
    print("-------------------------------")
    print(f"values changed : {total_changed}")
    print(f"already equal  : {total_same}")
    print(f"tokens added   : {total_added}")


if __name__ == "__main__":
    main()
