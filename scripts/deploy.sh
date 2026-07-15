#!/usr/bin/env bash

set -euo pipefail
ENV="${1:-eval}"
ORG="${ORG:-$(gcloud config get-value project)}"
FLAGS="--default-token --disable-check"

retry() { local n=1; until "$@"; do [ $n -ge 3 ] && { echo "failed after $n: $*" >&2; return 1; }; echo "retry $((n++))..." >&2; sleep 5; done; }

retry apigeecli targetservers import -f "config/$ENV/targetservers.json" -e "$ENV" -o "$ORG" $FLAGS

for dir in proxies/*/; do
    name="$(basename "$dir")"
    retry apigeecli apis create bundle -n "$name" --proxy-folder "${dir}apiproxy" -o "$ORG" $FLAGS
    retry apigeecli apis deploy -n "$name" -e "$ENV" -o "$ORG" --ovr --wait $FLAGS
done