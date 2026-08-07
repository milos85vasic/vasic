VIEWBOX: 0 0 980 500
TITLE: `<text class="h" x="32" y="44">HelixOTA — three-plane architecture</text>`

ANNOTATIONS (x, y, class, text):
- 40, 92, lbl, "Control plane"
- 370, 92, lbl, "Data plane"
- 700, 92, lbl, "Device"
- 490, 440, note, "Extractable seams: control ↔ data · data ↔ device"

BOXES (x, y, w, h, class, title, sub):
- 40, 110, 240, 80, accent, "Control plane", "Go + Gin · HTTP/3 QUIC"
- 40, 210, 240, 64, box, "Rollout orchestrator", "5→10→30→100 %"
- 40, 290, 240, 64, box, "React dashboard", ""
- 370, 110, 240, 80, box, "PostgreSQL", "release metadata"
- 370, 200, 240, 64, box, "MinIO / S3", "artifact store"
- 370, 280, 240, 64, box, "OpenTelemetry", "Prometheus · Grafana"
- 700, 110, 240, 80, accent, "Device agent", "Kotlin / KMP"
- 700, 210, 240, 64, box, "update_engine", "AVB / dm-verity"
- 700, 290, 240, 80, good, "A/B slots", "zero-brick rollback"

CONNECTORS (d verbatim):
- "M280,150 L368,150"
- "M280,242 L368,232"
- "M610,150 L698,150"
- "M610,232 L698,242"
- "M280,320 L698,330"
