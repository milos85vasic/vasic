VIEWBOX: 0 0 980 540
TITLE: `<text class="h" x="32" y="44">Docs Chain — dependency DAG · change propagation</text>`

ANNOTATIONS (x, y, class, text):
- 40, 216, lbl, "Change propagates downstream"
- 300, 100, lbl, "Transform outputs (exec)"
- 610, 384, lbl, "Persisted state"
- 500, 512, note, "Phases 1–5 implemented (GREEN) · Phases 6–7 planned"

BOXES (x, y, w, h, class, title, sub):
- 40, 230, 170, 90, box, "Markdown source", "chain member"
- 300, 220, 210, 110, accent, "DAG engine", "Kahn topological sort"
- 610, 90, 200, 70, box, "HTML", "exec transform"
- 610, 190, 200, 70, box, "PDF", "exec transform"
- 610, 290, 200, 70, box, "DOCX", "exec transform"
- 610, 400, 200, 70, box, "SQLite state", "modernc pure-Go"
- 40, 400, 170, 70, dash, "fsnotify watch", "content-hash / mtime"

CONNECTORS (d verbatim):
- "M210,275 L298,275"
- "M510,255 L608,125"
- "M510,270 L608,225"
- "M510,290 L608,325"
- "M510,320 L608,435"
- "M210,435 L298,320"
