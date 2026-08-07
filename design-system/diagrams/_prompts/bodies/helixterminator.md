VIEWBOX: 0 0 1000 520
TITLE: `<text class="h" x="32" y="44">HelixTerminator — three-channel architecture</text>`

ANNOTATIONS (x, y, class, text):
- 40, 160, lbl, "Clients"
- 520, 100, lbl, "Zero-trust core · SPIFFE/SPIRE · Ed25519"
- 760, 460, note, "OTel · Grafana · Jaeger · Loki"

BOXES (x, y, w, h, class, title, sub):
- 40, 180, 190, 90, box, "Flutter clients", "Dart · BLoC"
- 290, 180, 180, 90, box, "Gateway", "mTLS ingress"
- 520, 120, 220, 220, accent, "Go service mesh", "microservices"
- 790, 110, 180, 60, box, "Kafka", ""
- 790, 180, 180, 60, box, "RabbitMQ", ""
- 790, 250, 180, 60, box, "Redis", ""
- 790, 320, 180, 60, box, "PostgreSQL", ""
- 520, 400, 220, 80, box, "Host agent / SSH proxy", "short-lived certs"

CONNECTORS (d verbatim):
- "M230,225 L288,225"
- "M470,225 L518,225"
- "M740,180 L788,140"
- "M740,210 L788,210"
- "M740,245 L788,280"
- "M740,275 L788,350"
- "M630,340 L630,398"
