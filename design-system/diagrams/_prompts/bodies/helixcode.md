VIEWBOX: 0 0 960 640
TITLE: `<text class="h" x="32" y="44">HelixCode — layered architecture</text>`

ANNOTATIONS (x, y, class, text):
- 40, 90, lbl, "API layer"
- 40, 240, lbl, "Core services"
- 40, 462, lbl, "Data layer"

BOXES (x, y, w, h, class, title, sub):
- 120, 100, 200, 64, box, "REST API", ""
- 380, 100, 200, 64, box, "WebSocket", ""
- 640, 100, 200, 64, box, "MCP", "multi-transport"
- 40, 250, 170, 82, box, "Auth & Sessions", "JWT"
- 226, 250, 170, 82, box, "Worker Pool", "SSH · health monitor"
- 412, 250, 170, 82, box, "Task + Checkpointing", "rollback / resume"
- 598, 250, 170, 82, box, "Project & Workflow", ""
- 784, 250, 170, 82, box, "LLM Providers", "llama.cpp · Ollama · OpenAI"
- 260, 470, 200, 72, box, "PostgreSQL 15+", "11-table schema"
- 500, 470, 200, 72, box, "Redis 7", "optional cache"

CONNECTORS (d verbatim):
- "M220,164 L220,248"
- "M480,164 L480,248"
- "M740,164 L740,248"
- "M360,332 L360,468"
- "M600,332 L600,468"
