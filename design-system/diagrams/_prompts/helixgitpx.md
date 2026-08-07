You are an expert SVG author. Output ONLY one valid self-contained `<svg>` (SVG 1.1, `xmlns` set). No HTML, no `<script>`, no external refs, no markdown, no prose. SVG source only. Reproduce every element EXACTLY at the coordinates given. Do not re-layout, move, or resize anything. Draw CONNECTORS FIRST, then boxes, then text (so boxes sit above lines).

Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 640" font-family="'Inter',system-ui,sans-serif">`.

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
TITLE: `<text class="h" x="32" y="44">HelixGitpx — hub-and-spoke Git federation</text>`

ANNOTATIONS (x, y, class, text):
- 40, 74, lbl, "Mirror hosts (11 forges)"
- 340, 262, note, "conflict → policy / AI resolver → single truth"

BOXES (x, y, w, h, class, title, sub):
- 380, 280, 210, 110, accent, "Source-of-truth hub", "Go platform · OPA policy"
- 40, 90, 160, 52, box, "GitHub", ""
- 40, 180, 160, 52, box, "GitLab", ""
- 40, 300, 160, 52, box, "Gitea", ""
- 40, 410, 160, 52, box, "Bitbucket", ""
- 760, 90, 170, 52, box, "Azure DevOps", ""
- 760, 180, 170, 52, box, "AWS CodeCommit", ""
- 760, 300, 170, 52, box, "GitFlic", ""
- 760, 410, 170, 52, box, "GitVerse", ""
- 400, 70, 170, 52, box, "Gitee", ""
- 250, 540, 160, 52, box, "Forgejo", ""
- 560, 540, 160, 52, box, "SourceHut", ""

CONNECTORS (d verbatim):
- "M380,310 L202,116"
- "M380,320 L202,206"
- "M380,335 L202,326"
- "M380,350 L202,436"
- "M590,310 L758,116"
- "M590,320 L758,206"
- "M590,335 L758,326"
- "M590,350 L758,436"
- "M485,280 L485,124"
- "M430,390 L360,538"
- "M540,390 L620,538"
