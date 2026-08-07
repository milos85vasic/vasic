VIEWBOX: 0 0 1000 540
TITLE: `<text class="h" x="32" y="44">LLMProvider — one interface · 43 adapters</text>`

ANNOTATIONS (x, y, class, text):
- 600, 72, lbl, "Vendor fan-out"
- 40, 392, lbl, "Credentials"

BOXES (x, y, w, h, class, title, sub):
- 40, 230, 180, 90, box, "Application", "Complete / Stream"
- 280, 200, 220, 150, accent, "LLMProvider", "single Go interface"
- 600, 90, 340, 58, box, "43 provider adapters", "OpenAI · Anthropic · Gemini …"
- 600, 165, 340, 58, box, "Generic OpenAI-compatible", "any /v1 endpoint"
- 600, 250, 340, 58, dash, "Honest discovery", "live /v1/models + TTL cache"
- 40, 410, 180, 64, dash, "apikeys", "single credential source"
- 280, 410, 220, 64, box, "Circuit breaker", "closed→open→half-open"
- 560, 410, 240, 64, box, "Retry", "backoff + jitter · status-aware"

CONNECTORS (d verbatim):
- "M220,275 L278,275"
- "M500,240 L598,119"
- "M500,270 L598,194"
- "M500,300 L598,279"
- "M390,350 L390,408"
- "M500,340 L640,408"
- "M130,410 L280,350"
