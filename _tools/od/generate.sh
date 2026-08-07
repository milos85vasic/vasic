#!/usr/bin/env bash
# Reproducible OpenDesign generation wrapper (§11.4.77).
# Usage: generate.sh <promptFile> <outFile> [kind] [maxTokens]
# Requires the OpenDesign daemon running (see _tools/od/start-daemon.sh) and ~/api_keys.sh.
set -euo pipefail
PROMPT_FILE="$1"; OUT="$2"; KIND="${3:-other}"; MAXTOK="${4:-16000}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1090
source ~/api_keys.sh
export OD_DAEMON_URL="${OD_DAEMON_URL:-http://127.0.0.1:4321}"
export BYOK_PROVIDER="${BYOK_PROVIDER:-openai}"
export BYOK_BASE_URL="${BYOK_BASE_URL:-https://api.mistral.ai/v1}"
export BYOK_API_KEY="${BYOK_API_KEY:-$MISTRAL_API_KEY}"
export BYOK_MODEL="${BYOK_MODEL:-codestral-latest}"
args="$(node -e 'const fs=require("fs");const [pf,kind,mt]=process.argv.slice(1);process.stdout.write(JSON.stringify({prompt:fs.readFileSync(pf,"utf8"),kind,maxTokens:Number(mt)}))' "$PROMPT_FILE" "$KIND" "$MAXTOK")"
raw="$(OD_TIMEOUT_MS="${OD_TIMEOUT_MS:-480000}" node "$SELF_DIR/od-mcp-call.mjs" od_generate_design "$args")"
# strip a single leading/trailing markdown code fence if present
printf '%s' "$raw" | node -e 'let s=require("fs").readFileSync(0,"utf8");s=s.replace(/^﻿?\s*```[a-zA-Z]*\n?/,"").replace(/\n?```\s*$/,"");process.stdout.write(s)' > "$OUT"
echo "wrote $OUT ($(wc -c < "$OUT") bytes)"
