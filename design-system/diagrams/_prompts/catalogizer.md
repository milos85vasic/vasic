You are an expert SVG author. Output ONLY one valid self-contained `<svg>` (SVG 1.1, `xmlns` set). No HTML, no `<script>`, no external refs, no markdown, no prose. SVG source only. Reproduce every element EXACTLY at the coordinates given. Do not re-layout, move, or resize anything. Draw CONNECTORS FIRST, then boxes, then text (so boxes sit above lines).

Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 980 560" font-family="'Inter',system-ui,sans-serif">`.

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
TITLE: `<text class="h" x="32" y="44">Catalogizer — layered architecture · multi-protocol fan-out</text>`

ANNOTATIONS (x, y, class, text):
- 40, 96, lbl, "Clients"
- 720, 74, lbl, "Encrypted data layer"
- 250, 424, lbl, "Multi-protocol fan-out"

BOXES (x, y, w, h, class, title, sub):
- 40, 110, 200, 60, box, "Web UI · React + Tailwind", ""
- 40, 185, 200, 60, box, "Desktop · Tauri / Rust", ""
- 40, 260, 200, 60, box, "Realtime · WebSockets", ""
- 380, 140, 230, 150, accent, "Catalogizer Core", "Go + Gin · unified API"
- 720, 90, 230, 64, box, "SQLCipher", "encrypted catalog"
- 720, 166, 230, 64, box, "PostgreSQL", ""
- 720, 242, 230, 64, box, "Redis cache", ""
- 720, 330, 230, 64, box, "Prometheus · OTel", "metrics · traces"
- 250, 440, 230, 72, tint, "SMB · FTP · NFS · WebDAV", "storage sources"
- 520, 440, 230, 72, tint, "S3 · Google Cloud Storage", "object storage"

CONNECTORS (d verbatim):
- "M240,140 L378,190"
- "M240,215 L378,210"
- "M240,290 L378,232"
- "M610,175 L718,122"
- "M610,200 L718,198"
- "M610,225 L718,274"
- "M610,262 L718,362"
- "M380,440 L470,292"
- "M620,440 L520,292"
