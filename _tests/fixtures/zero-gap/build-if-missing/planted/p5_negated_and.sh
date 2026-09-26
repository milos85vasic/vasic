#!/usr/bin/env bash
# planted: negated test joined with &&
[ ! -e ./target/release/svc ] && cargo build --release
exec ./target/release/svc
