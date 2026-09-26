#!/usr/bin/env bash
# comment: command -v commentedtool is not a precondition
command -v confirmedtool >/dev/null 2>&1 || exit 2
command -v presenttool2 >/dev/null 2>&1 || exit 2
if ! command -v uncatalogued >/dev/null 2>&1; then exit 2; fi
cat <<'TXT'
command -v inheredoc
TXT
check_multi() {
    if ! command -v multitool >/dev/null 2>&1; then
        undet "multitool is not on PATH"
    fi
}
command -v softtool >/dev/null 2>&1 || echo "softtool absent; continuing without it"
if ! command -v twolinetool >/dev/null 2>&1; then
    echo "twolinetool is missing" >&2
    exit 2
fi
if ! command -v optionaltool >/dev/null 2>&1; then
    warn "optionaltool absent; the optional leg is skipped"
fi
[ -d ./reports ] || exit 2
