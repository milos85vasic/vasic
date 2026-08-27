#!/usr/bin/env bash
# Assemble final prompts (preamble + body) and generate each diagram SVG via OpenDesign.
set -euo pipefail
# ROOT used to be a hardcoded absolute macOS path that exists on no other
# checkout. Derive it from the script's own location instead: this file
# lives at <root>/design-system/diagrams/_prompts/, i.e. THREE levels down.
# VASIC_ROOT overrides the default when the repo root is elsewhere.
ROOT="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)}"
cd "$ROOT" || { echo "FATAL: cannot cd to repository root '$ROOT'" >&2; exit 1; }
PDIR="$ROOT/design-system/diagrams/_prompts"
ODIR="$ROOT/design-system/diagrams"
source ~/api_keys.sh
export OD_DAEMON_URL=http://127.0.0.1:4321 BYOK_PROVIDER=openai BYOK_BASE_URL=https://api.mistral.ai/v1 BYOK_API_KEY=$MISTRAL_API_KEY BYOK_MODEL=codestral-latest

slugs="${*:-helixmemory helixtrack helixcode helixagent helixllm helixcluster helixtranslate llmsverifier helixconstitution helixqa}"
for slug in $slugs; do
  body="$PDIR/bodies/$slug.md"
  final="$PDIR/$slug.md"
  vb="$(grep -m1 '^VIEWBOX:' "$body" | sed 's/^VIEWBOX:[[:space:]]*//')"
  # preamble with viewbox substituted, then the body sans the VIEWBOX line
  sed "s|{VIEWBOX}|$vb|" "$PDIR/_preamble.md" > "$final"
  printf '\n\nDIAGRAM SPEC:\n' >> "$final"
  grep -v '^VIEWBOX:' "$body" >> "$final"
  echo "=== generating $slug (viewBox: $vb) ==="
  bash "$ROOT/_tools/od/generate.sh" "$final" "$ODIR/$slug.svg" other 16000 2>&1 | tail -1
done
