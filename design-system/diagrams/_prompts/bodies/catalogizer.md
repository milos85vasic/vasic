VIEWBOX: 0 0 980 560
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
