#!/usr/bin/env bash
# =============================================================================
# jekyll-build.sh — the milosvasic.ru Jekyll build, AS RUN INSIDE the container.
#
# This file never executes on the host. It is bind-mounted read-only into the
# `jekyll-build` service defined by compose.sites.yml and is that service's
# entrypoint. The container is started, waited on, inspected and torn down by
# _tools/containers/cmd/site-build, which drives podman/docker exclusively
# through `digital.vasic.containers` (§11.4.76(1),(3): the Containers Submodule
# is the orchestration authority — nothing here shells out to a runtime).
#
# Contract with the caller:
#   /site      the milosvasic.ru Jekyll SOURCE tree, read-write (bind mount).
#              _site/ is written back to the host through this mount — that is
#              the whole point, and it is what makes the artifact check in
#              site-build a real measurement rather than a claim.
#   /bundle    a persistent named volume holding the installed gems, so the
#              first run pays for `bundle install` and later runs do not.
#   BUILD_YEAR optional; when non-empty the footer © year is PINNED through an
#              ephemeral _config.deploy.yml, mirroring _tools/gen/build.sh so
#              the container and host paths cannot render different bytes.
#
# Exit codes are the container's, and site-build reads them back off the
# stopped container via the module's runtime.Status(). A non-zero exit here is
# a build failure; it is never swallowed.
# =============================================================================
set -euo pipefail

echo "[jekyll-build] ruby:     $(ruby -v)"
echo "[jekyll-build] bundler:  $(bundle -v)"
echo "[jekyll-build] site:     ${PWD}"

# Gems land in BUNDLE_PATH (/bundle, a named volume). The host's own
# vendor/bundle is deliberately NOT reused: the host is ALT Linux and the image
# is Debian, so native extensions built in one are not guaranteed loadable in
# the other. Keeping the two gem trees separate is the point, not an oversight.
echo "[jekyll-build] bundle install (path=${BUNDLE_PATH:-<unset>}) ..."
bundle install

DEPLOY_CFG="/site/_config.deploy.yml"
CONFIGS="_config.yml"
cleanup() { rm -f "$DEPLOY_CFG"; }
trap cleanup EXIT INT TERM

if [ -n "${BUILD_YEAR:-}" ]; then
  printf 'build_year: %s\n' "$BUILD_YEAR" >"$DEPLOY_CFG"
  CONFIGS="_config.yml,_config.deploy.yml"
  echo "[jekyll-build] footer year pinned to $BUILD_YEAR"
fi

echo "[jekyll-build] jekyll build --config $CONFIGS ..."
bundle exec jekyll build --config "$CONFIGS"

# Anti-bluff, container side (§11.4): a zero exit from `jekyll build` is not
# evidence that a site was produced. Assert the artifact exists and is
# non-empty here too, so a silent no-op cannot reach the host as a success.
if [ ! -s /site/_site/index.html ]; then
  echo "[jekyll-build] FAIL: jekyll exited 0 but /site/_site/index.html is missing or empty" >&2
  exit 1
fi

echo "[jekyll-build] wrote $(find /site/_site -type f | wc -l) file(s) into _site/"
echo "[jekyll-build] done"
