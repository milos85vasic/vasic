#!/usr/bin/env bash
# a sweep-class script: its proof text names tools that are not preconditions of any gate
proof_case() {
    command -v selfscantool >/dev/null 2>&1 || exit 2
}
