VIEWBOX: 0 0 1060 380
TITLE: `<text class="h" x="32" y="44">HelixPlay — media pipeline (per-stage tech)</text>`

ANNOTATIONS (x, y, class, text):
- 30, 122, lbl, "GPU host"
- 880, 122, lbl, "Phone · TV · laptop · browser"
- 420, 320, note, "Triple-stack clients (Wails · Flutter · Angular→WASM) over one Go core"

BOXES (x, y, w, h, class, title, sub):
- 30, 150, 150, 90, box, "Capture", "DXGI · SCK · PipeWire"
- 200, 150, 150, 90, box, "Encode", "NVENC·QSV·AMF·VT"
- 370, 150, 150, 90, box, "Packetize", "RTP"
- 540, 150, 150, 90, accent, "Transmit", "WebRTC · QUIC · UDP"
- 710, 150, 150, 90, box, "Decode", "hardware"
- 880, 150, 150, 90, good, "Render", "client"

CONNECTORS (d verbatim):
- "M180,195 L198,195"
- "M350,195 L368,195"
- "M520,195 L538,195"
- "M690,195 L708,195"
- "M860,195 L878,195"
