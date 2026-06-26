#!/usr/bin/env bash
# =============================================================================
# distribute-helixtranslate.sh — build the HelixTranslate engine as a container
# and distribute it to the translation hosts (thinker.local / amber.local), per
# the mandate that HelixTranslate runs ONLY via containers on those hosts.
#
# Strategy (proven, see _analysis/CONTAINER-DISTRIBUTION.md):
#   1. rsync the helix_translate source (minus .git + heavy docs) to a BUILD
#      host and build a cgo linux/amd64 image natively there (Containerfile.
#      translator, multi-stage golang:1.26-alpine). cgo is REQUIRED: the bridge
#      opens a go-sqlite3 verified-models store at startup.
#   2. Replicate the image to the other host via `save | ssh ... load`
#      (podman on thinker, docker on amber) — no second multi-GB transfer.
#   3. Seed each host's persistent `helixtranslate-data` volume with a
#      verified_models.db so the one-time startup verification is skipped and
#      the explicit-provider translate path runs immediately.
#   4. Install ~/.helixtranslate.env (mode 600, LLM keys) + ~/helixtranslate-img/
#      run.sh on each host.
#
# Re-runnable. Requires: key-based SSH as milosvasic@<host>; podman on thinker,
# docker on amber; LLM keys (MISTRAL/GROQ/COHERE) in the local environment.
# =============================================================================
set -euo pipefail
HT_SRC="${HT_SRC:-/Volumes/T7/Projects/helix_translate}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ASSETS="$HERE/helixtranslate-container"
BUILD_HOST="${BUILD_HOST:-thinker.local}"      # native linux/amd64 cgo build
SEED_DB="${SEED_DB:-$HT_SRC/data/verified_models.db}"

mk_envfile() {  # write a 600 env file of the working-provider keys to $1
  local out="$1"; umask 077; : > "$out"
  for k in MISTRAL_API_KEY GROQ_API_KEY COHERE_API_KEY; do
    local v="${!k:-}"; [ -n "$v" ] && printf '%s=%s\n' "$k" "$v" >> "$out"
  done
}

echo "== 1. rsync source -> $BUILD_HOST =="
ssh -o BatchMode=yes "milosvasic@$BUILD_HOST" 'mkdir -p ~/helixtranslate-src'
rsync -a --delete --exclude='.git/' --exclude='**/.git/' --exclude='*.pdf' \
  --exclude='*.html' --exclude='images/' --exclude='**/node_modules/' \
  --exclude='build/' --exclude='bin/' --exclude='*.db' \
  "$HT_SRC/" "milosvasic@$BUILD_HOST:~/helixtranslate-src/"
scp -q "$ASSETS/Containerfile.translator" "milosvasic@$BUILD_HOST:~/helixtranslate-src/"

echo "== 2. build cgo image on $BUILD_HOST (podman) =="
ssh -o BatchMode=yes "milosvasic@$BUILD_HOST" \
  'cd ~/helixtranslate-src && podman build -t helixtranslate:cli -f Containerfile.translator .'

echo "== 3. replicate image $BUILD_HOST(podman) -> amber.local(docker) =="
ssh -o BatchMode=yes "milosvasic@$BUILD_HOST" 'podman save helixtranslate:cli' \
  | ssh -o BatchMode=yes 'milosvasic@amber.local' 'docker load'
ssh -o BatchMode=yes 'milosvasic@amber.local' 'docker tag localhost/helixtranslate:cli helixtranslate:cli'

echo "== 4. seed db + install env/run.sh on both hosts =="
TMPENV="$(mktemp)"; trap 'rm -f "$TMPENV"' EXIT; mk_envfile "$TMPENV"
for H in thinker.local amber.local; do
  rt=podman; [ "$H" = amber.local ] && rt=docker
  ssh -o BatchMode=yes "milosvasic@$H" 'mkdir -p ~/helixtranslate-img'
  scp -q "$TMPENV" "milosvasic@$H:~/helixtranslate-img/.helixtranslate.env"
  scp -q "$ASSETS/run.sh" "milosvasic@$H:~/helixtranslate-img/run.sh"
  scp -q "$SEED_DB" "milosvasic@$H:/tmp/seed.db"
  ssh -o BatchMode=yes "milosvasic@$H" "
    install -m600 ~/helixtranslate-img/.helixtranslate.env ~/.helixtranslate.env
    chmod +x ~/helixtranslate-img/run.sh
    $rt volume create helixtranslate-data >/dev/null 2>&1 || true
    $rt run --rm -v helixtranslate-data:/data -v /tmp/seed.db:/seed.db:ro \
       docker.io/library/alpine:3.20 cp /seed.db /data/verified_models.db
    echo \"$H ready: \$($rt run --rm helixtranslate:cli -version 2>&1 | head -1)\"
  "
done
echo "DISTRIBUTE DONE — both hosts run helixtranslate:cli (cgo, seeded)."
