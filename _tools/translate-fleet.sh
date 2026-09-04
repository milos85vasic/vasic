#!/usr/bin/env bash
# =============================================================================
# translate-fleet.sh — parallel article-translation driver that runs the
# HelixTranslate engine ONLY inside containers on thinker.local (podman) and
# amber.local (docker), per the infra mandate. Jobs (site × lang × slug) are
# round-robined across the two hosts and executed by a bounded worker pool, so
# both machines translate concurrently. Each job delegates to the unchanged
# translate-pipeline.sh (frontmatter-preserving, retry+fallback, artifact strip)
# with HELIX_TRANSLATE_BIN pointed at the container shim.
#
# Usage: translate-fleet.sh <tag> <lang> [<lang> ...]
# Env:   FLEET_PARALLEL (default 4)  HOSTS (default "thinker.local amber.local")
# Resumable: existing outputs are skipped. No `set -e` (one bad job ≠ abort).
# =============================================================================
set -uo pipefail
TAG="${1:?tag required}"; shift
LANGS="$*"
# ROOT (the repository root) is DERIVED from this script's own location
# (<repo>/_tools/translate-fleet.sh -> "$(dirname)/.."), never hardcoded: a
# literal absolute path only resolves on the machine it was typed on, and since
# this script sets -u and pipefail but NOT -e, a wrong root fails silently — the
# job list comes out empty and the fleet reports DONE with jobs=0. Set VASIC_ROOT
# only to deliberately target a different checkout.
ROOT="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "FATAL: cannot resolve repository root (got '$ROOT')" >&2; exit 1; }
TOOLS="$ROOT/_tools"
PIPE="$TOOLS/translate-pipeline.sh"
SHIM="$TOOLS/helixtranslate-container.sh"
EVID="$ROOT/_tests/evidence/translate"
SUM="$EVID/${TAG}-summary.log"
JOBS="$EVID/${TAG}-jobs.tsv"
mkdir -p "$EVID"; : > "$SUM"; : > "$JOBS"
PAR="${FLEET_PARALLEL:-4}"
read -r -a HOSTLIST <<<"${HOSTS:-thinker.local amber.local}"

# ---- Build the job list: site \t lang \t slug \t src \t out ----------------
n=0
for site in milosvasic.ru vasic.digital; do
  root="$ROOT/$site"
  for lang in $LANGS; do
    for md in "$root/_article_src/en/"*.md; do
      [ -e "$md" ] || continue
      slug="$(basename "$md" .md)"
      out="$root/_article_src/$lang/$slug.md"
      if [ -f "$out" ]; then echo "SKIP(exists) $site/$lang/$slug" >>"$SUM"; continue; fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$site" "$lang" "$slug" "$md" "$out" >>"$JOBS"
      n=$((n+1))
    done
  done
done
echo "FLEET tag=$TAG langs=[$LANGS] jobs=$n hosts=[${HOSTLIST[*]}] parallel=$PAR" >>"$SUM"

# ---- Worker: translate one job on an assigned host -------------------------
run_job() {
  local site="$1" lang="$2" slug="$3" src="$4" out="$5" host="$6"
  # §11.4.76 verdict for the line below, measured 2026-09-04 rather than assumed:
  # this is per-host CONFIGURATION, not a reimplemented primitive. The Containers
  # Submodule's own `pkg/remote.RemoteHost` carries a declared `Runtime string`
  # field ("the container runtime on this host"), and it ships NO remote runtime
  # detector to defer to — `grep -rn 'DetectRuntime\|AutoDetect' pkg/remote
  # pkg/discovery` outside tests matches nothing at gitlink
  # d940b51fc247c285c805799452992da8d09c75b9. Naming a remote host's runtime is
  # exactly what the module expects a consumer to supply.
  # Contrast `_tools/helixtranslate-local.sh`, which named a runtime for the
  # LOCAL host: the module DOES own that (`runtime.AutoDetect`), so that literal
  # was a real §11.4.76(4) violation and was converted.
  # This script spawns no runtime and no ssh itself; it delegates both to
  # "$SHIM", whose own header declares the remaining exception.
  local rt="podman"; [ "$host" = "amber.local" ] && rt="docker"
  if HELIX_TRANSLATE_BIN="$SHIM" HT_HOST="$host" HT_RUNTIME="$rt" \
       bash "$PIPE" --in "$src" --out "$out" --lang "$lang" --article >>"$SUM" 2>&1; then
    echo "OK   $site/$lang/$slug @${host}"
  else
    echo "FAIL $site/$lang/$slug @${host}"
  fi
}
export -f run_job
export PIPE SHIM SUM

# ---- Dispatch round-robin with a bounded pool ------------------------------
i=0
while IFS=$'\t' read -r site lang slug src out; do
  host="${HOSTLIST[$(( i % ${#HOSTLIST[@]} ))]}"
  i=$((i+1))
  run_job "$site" "$lang" "$slug" "$src" "$out" "$host" &
  while [ "$(jobs -r | wc -l)" -ge "$PAR" ]; do wait -n; done
done < "$JOBS"
wait

# ---- Render fragments for every site/lang ----------------------------------
for site in milosvasic.ru vasic.digital; do
  bash "$TOOLS/render-articles.sh" "$ROOT/$site" $LANGS >>"$SUM" 2>&1
done

{
  echo "=== SUMMARY tag=$TAG ==="
  for site in milosvasic.ru vasic.digital; do
    for lang in $LANGS; do
      echo "$site/$lang md=$(ls "$ROOT/$site/_article_src/$lang/"*.md 2>/dev/null|wc -l) html=$(ls "$ROOT/$site/articles/$lang/"*.html 2>/dev/null|wc -l)"
    done
  done
  echo DONE
} >>"$SUM"
echo "translate-fleet DONE tag=$TAG -> $SUM"
