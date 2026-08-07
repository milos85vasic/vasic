VIEWBOX: 0 0 1000 520
TITLE: `<text class="h" x="32" y="44">LLMOrchestrator — control-plane fan-out</text>`

ANNOTATIONS (x, y, class, text):
- 620, 52, lbl, "Coding agents (spawned + driven)"
- 40, 340, lbl, "Resilience"

BOXES (x, y, w, h, class, title, sub):
- 40, 210, 180, 90, box, "Client / caller", ""
- 280, 180, 240, 150, accent, "MultiProviderPool", "round-robin / preference"
- 620, 70, 320, 58, box, "OpenCode", ""
- 620, 140, 320, 58, box, "Claude Code", ""
- 620, 210, 320, 58, box, "Gemini", ""
- 620, 280, 320, 58, box, "Junie", ""
- 620, 350, 320, 58, box, "Qwen Code", ""
- 280, 400, 240, 64, dash, "Transport", "pipe JSON-lines · file inbox/outbox"
- 40, 360, 180, 64, box, "Circuit breaker", "closed→open→half-open"

CONNECTORS (d verbatim):
- "M220,255 L278,255"
- "M520,220 L618,99"
- "M520,235 L618,169"
- "M520,255 L618,239"
- "M520,275 L618,309"
- "M520,295 L618,379"
- "M400,330 L400,398"
- "M220,392 L278,320"
