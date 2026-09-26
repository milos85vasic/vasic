#!/usr/bin/env bash
# clean: delegates to a freshness gate that refuses stale builds
source ./_common.sh
ensure_fresh_server
exec ./bin/server
