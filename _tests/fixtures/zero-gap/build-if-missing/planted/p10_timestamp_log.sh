#!/usr/bin/env bash
# planted: a log helper assigns a `timestamp` variable; nothing compares a build stamp
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*"
}
BINARY=./bin/tool
if [ ! -x "$BINARY" ]; then
    log "Building binary..."
    go build -o "$BINARY" ./cmd
fi
exec "$BINARY"
# a wall-clock TIMESTAMP carried into a compared value is not a build stamp either
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="./out/report_${TIMESTAMP}.json"
if [ -f "$OUT" ] && grep -qi success "$OUT"; then echo ok; fi
