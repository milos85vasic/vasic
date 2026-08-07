VIEWBOX: 0 0 960 620
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
