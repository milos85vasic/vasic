VIEWBOX: 0 0 1000 480
TITLE: `<text class="h" x="32" y="44">Qemu-Utils — VM lifecycle + networking</text>`

ANNOTATIONS (x, y, class, text):
- 30, 100, lbl, "VM lifecycle"
- 410, 252, lbl, "Bridge + TAP networking"

BOXES (x, y, w, h, class, title, sub):
- 30, 120, 160, 80, box, "ISO / image", ""
- 210, 120, 180, 80, box, "Cache", "compressed / uncompressed"
- 410, 120, 150, 80, accent, "Run VM", "QEMU"
- 580, 120, 180, 80, box, "Publish", "remote endpoint"
- 790, 120, 180, 80, dash, "Accel path", "Linux KVM · macOS HVF"
- 410, 270, 150, 70, box, "Host bridge", ""
- 210, 380, 150, 60, box, "TAP0 → VM", ""
- 410, 380, 150, 60, box, "TAP1 → VM", ""
- 610, 380, 150, 60, box, "TAP2 → VM", ""

CONNECTORS (d verbatim):
- "M190,160 L208,160"
- "M390,160 L408,160"
- "M560,160 L578,160"
- "M760,160 L788,160"
- "M485,200 L485,268"
- "M450,340 L320,378"
- "M485,340 L485,378"
- "M520,340 L680,378"
