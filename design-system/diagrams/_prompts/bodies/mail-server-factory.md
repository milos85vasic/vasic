VIEWBOX: 0 0 1000 560
TITLE: `<text class="h" x="32" y="44">Mail Server Factory — JSON → Docker mail stack</text>`

ANNOTATIONS (x, y, class, text):
- 600, 72, lbl, "Installed Docker mail stack"
- 40, 400, lbl, "Connection-type fan-out"
- 500, 524, note, "Security: AES-256-GCM · firewall ports · TLS/HSTS · RBAC · audit log"

BOXES (x, y, w, h, class, title, sub):
- 40, 220, 180, 90, box, "JSON config", "declarative recipe"
- 280, 190, 220, 150, accent, "Factory engine", "Kotlin 2.0 · JVM G1GC"
- 600, 90, 340, 58, box, "Postfix", "SMTP"
- 600, 160, 340, 58, box, "Dovecot", "IMAP / POP"
- 600, 230, 340, 58, box, "TLS / HSTS", "certificates"
- 600, 300, 340, 58, box, "Sieve", "filtering"
- 40, 420, 920, 72, box, "Connection targets", "local · SSH · Docker · K8s · AWS SSM · Azure · GCP · Libvirt"

CONNECTORS (d verbatim):
- "M220,265 L278,265"
- "M500,230 L598,119"
- "M500,250 L598,189"
- "M500,270 L598,259"
- "M500,300 L598,329"
- "M390,340 L390,418"
