#!/usr/bin/env bash
# =============================================================================
# SUPERSEDED — but NOT yet retired, and the distinction is deliberate.
#
# This script spawns raw `ssh`, `scp` and `rsync` itself. §11.4.76(4) forbids
# that: the Containers submodule owns remote execution and a consuming project
# may not reimplement it. A replacement that drives every SSH/SCP operation
# through the module now exists:
#
#     _tools/containers/cmd/distribute-helixtranslate     (Go, three-valued exit)
#     go run ./cmd/distribute-helixtranslate -dry-run     (from _tools/containers)
#
# WHY THIS FILE IS STILL HERE. The replacement has never been run against a
# live remote. On 2026-09-03 both target hosts were measured unreachable from
# the development machine — `ssh` failed at name resolution (rc 255) for both,
# while avahi-daemon was active and `avahi-browse -at` enumerated many other
# devices on the same /24. Retiring a working script in favour of an unverified
# one would be a downgrade dressed up as compliance.
#
# So: prefer the Go command. Keep this until someone has run the Go command
# end to end against thinker/amber and recorded the result. Note that this
# script is ALSO unrunnable on that machine today — its own line-45 seed-db
# precondition fails, because no verified_models.db exists anywhere in the
# helix_translate checkout.
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
# Every path below is DERIVED, never a literal absolute path (a literal only
# resolves on the machine it was typed on).
#   HERE = this script's own directory (<repo>/_tools)
#   ROOT = the repository root (<repo>)
#   HT_SRC = the helix_translate SOURCE. helix_translate is a SIBLING repository,
#            not part of this one, so its default is resolved next to this repo:
#            "$(dirname "$ROOT")/helix_translate". Override with HT_SRC=<path> if
#            your checkout lives elsewhere. The default is a convention, not a
#            guarantee — so the resolved path is validated below and the script
#            aborts with a clear message rather than rsync'ing an empty tree to
#            the build host.
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || { echo "FATAL: cannot resolve this script's directory" >&2; exit 1; }
ROOT="$(cd -- "$HERE/.." && pwd)" || { echo "FATAL: cannot resolve repository root from '$HERE'" >&2; exit 1; }
HT_SRC="${HT_SRC:-$(dirname -- "$ROOT")/helix_translate}"
[ -d "$HT_SRC" ] || { echo "FATAL: helix_translate source not found: '$HT_SRC'
  helix_translate is a SIBLING repository of $(basename -- "$ROOT"); it is expected next to it
  (checked out as $(dirname -- "$ROOT")/helix_translate). Clone it there, or point this
  script at your checkout:  HT_SRC=/path/to/helix_translate bash $0" >&2; exit 1; }
ASSETS="$HERE/helixtranslate-container"
BUILD_HOST="${BUILD_HOST:-thinker.local}"      # native linux/amd64 cgo build
SEED_DB="${SEED_DB:-$HT_SRC/data/verified_models.db}"
[ -f "$SEED_DB" ] || { echo "FATAL: seed db not found: '$SEED_DB' (override with SEED_DB=<path>)" >&2; exit 1; }

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
