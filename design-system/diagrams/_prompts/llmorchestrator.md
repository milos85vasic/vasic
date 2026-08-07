You are an expert SVG author. Output ONLY one valid self-contained `<svg>` (SVG 1.1, `xmlns` set). No HTML, no `<script>`, no external refs, no markdown, no prose. SVG source only. Reproduce every element EXACTLY at the coordinates given. Do not re-layout, move, or resize anything. Draw CONNECTORS FIRST, then boxes, then text (so boxes sit above lines).

Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 520" font-family="'Inter',system-ui,sans-serif">`.

First child MUST be this `<style>` (verbatim):
```
<style>
svg{--ink:#1e293b;--muted:#475569;--line:#94a3b8;--accent:#a31e39;--panel:#f8fafc;--panel2:#eef2f7;--tint:#f4dde1;--good:#dcfce7;--goodln:#16a34a;--goodink:#14532d;}
@media(prefers-color-scheme:dark){svg{--ink:#e2e8f0;--muted:#cbd5e1;--line:#64748b;--accent:#ff6b81;--panel:#1e293b;--panel2:#273449;--tint:#3a2530;--good:#14321f;--goodln:#4ade80;--goodink:#bbf7d0;}}
.box{fill:var(--panel);stroke:var(--line);stroke-width:1.5;}
.accent{fill:var(--panel);stroke:var(--accent);stroke-width:2;}
.tint{fill:var(--tint);stroke:var(--accent);stroke-width:1.5;}
.good{fill:var(--good);stroke:var(--goodln);stroke-width:1.5;}
.dash{fill:var(--panel2);stroke:var(--line);stroke-width:1.5;stroke-dasharray:5 4;}
.t{fill:var(--ink);font-size:15px;font-weight:700;text-anchor:middle;}
.s{fill:var(--muted);font-size:11px;text-anchor:middle;}
.gt{fill:var(--goodink);font-size:15px;font-weight:700;text-anchor:middle;}
.h{fill:var(--ink);font-size:20px;font-weight:700;}
.lbl{fill:var(--muted);font-size:12px;font-weight:600;}
.note{fill:var(--muted);font-size:11px;text-anchor:middle;}
.conn{stroke:var(--line);stroke-width:1.75;fill:none;}
.strike{stroke:var(--accent);stroke-width:2.5;}
</style>
```
Then `<defs><marker id="a" markerWidth="9" markerHeight="9" refX="7" refY="3" orient="auto"><path d="M0,0 L7,3 L0,6 Z" fill="var(--line)"/></marker></defs>`.

How to draw each BOX row "(x, y, w, h, class, title, sub)": `<rect class="{class}" x y width height rx="10"/>`, then `<text class="{t or gt}" x="{x+w/2}" y="{y+34}">{title}</text>`; if sub is non-empty add `<text class="s" x="{x+w/2}" y="{y+54}">{sub}</text>`; if sub is empty put title at y+{h/2+5}. Use class `gt` for the title only when the box class is `good`, otherwise class `t`.
Each CONNECTOR line: `<path class="conn" marker-end="url(#a)" d="{d}"/>` using the given d verbatim.
Each ANNOTATION row "(x, y, class, text)": `<text class="{class}" x="{x}" y="{y}">{text}</text>`. Class `lbl` renders left-aligned; class `note` renders centered — use the class exactly as given.
Each STRIKE row "(x1, y1, x2, y2)": `<line class="strike" x1 y1 x2 y2/>` (used to cross out a box). Omit the STRIKE section if the spec says none.
If a section says "none", omit it entirely.


DIAGRAM SPEC:
TITLE: `<text class="h" x="32" y="44">LLMOrchestrator — control-plane fan-out</text>`

ANNOTATIONS (x, y, class, text):
- 620, 52, lbl, "Coding agents (spawned + driven)"
- 40, 340, lbl, "Resilience"

BOXES (x, y, w, h, class, title, sub):
- 40, 210, 180, 90, box, "Client / caller", ""
- 280, 180, 240, 150, accent, "MultiProviderPool", "round-robin / preference"
- 620, 70, 320, 58, box, "OpenCode", ""
- 620, 140, 320, 58, box, "Claude Code", ""
- 620, 210, 320, 58, box, "Gemini", ""
- 620, 280, 320, 58, box, "Junie", ""
- 620, 350, 320, 58, box, "Qwen Code", ""
- 280, 400, 240, 64, dash, "Transport", "pipe JSON-lines · file inbox/outbox"
- 40, 360, 180, 64, box, "Circuit breaker", "closed→open→half-open"

CONNECTORS (d verbatim):
- "M220,255 L278,255"
- "M520,220 L618,99"
- "M520,235 L618,169"
- "M520,255 L618,239"
- "M520,275 L618,309"
- "M520,295 L618,379"
- "M400,330 L400,398"
- "M220,392 L278,320"
