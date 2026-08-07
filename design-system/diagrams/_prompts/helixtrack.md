You are an expert SVG author. Output ONLY one valid self-contained `<svg>` (SVG 1.1, `xmlns` set). No HTML, no `<script>`, no external refs, no markdown, no prose. SVG source only. Reproduce every element EXACTLY at the coordinates given. Do not re-layout, move, or resize anything. Draw CONNECTORS FIRST, then boxes, then text (so boxes sit above lines).

Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 620" font-family="'Inter',system-ui,sans-serif">`.

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
TITLE: `<text class="h" x="32" y="44">HelixTrack — architecture map</text>`

ANNOTATIONS (x, y, class, text):
- 40, 96, lbl, "Native clients"
- 650, 60, lbl, "Decoupled services · HTTP/3 QUIC"
- 650, 344, lbl, "Encrypted data layer"
- 278, 178, note, "UDP discovery"

BOXES (x, y, w, h, class, title, sub):
- 40, 110, 190, 60, box, "Web · Angular 19", ""
- 40, 180, 190, 60, box, "Desktop · Tauri 2.0", ""
- 40, 250, 190, 60, box, "Android · Kotlin", ""
- 40, 320, 190, 60, box, "iOS · Swift", ""
- 330, 205, 250, 120, accent, "HelixTrack Core", "Go + Gin · unified /do API"
- 650, 80, 250, 62, box, "Auth service", ""
- 650, 154, 250, 62, box, "Permissions service", ""
- 650, 228, 250, 62, box, "Localization service", ""
- 650, 360, 250, 72, box, "PostgreSQL / SQLite", "SQLCipher AES-256"
- 650, 452, 250, 60, box, "Redis cache", ""

CONNECTORS (d verbatim):
- "M230,140 L328,240"
- "M230,210 L328,255"
- "M230,280 L328,272"
- "M230,350 L328,288"
- "M580,240 L648,111"
- "M580,255 L648,185"
- "M580,270 L648,259"
- "M580,300 L648,396"
- "M580,312 L648,482"
