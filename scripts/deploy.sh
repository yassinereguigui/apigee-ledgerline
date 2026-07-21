#!/usr/bin/env bash

set -euo pipefail
ENV="${1:-eval}"
NAME="${2:-}"
ORG="${ORG:-$(gcloud config get-value project)}"
FLAGS="--default-token --disable-check"

retry() { local n=1; until "$@"; do [ $n -ge 3 ] && { echo "failed after $n: $*" >&2; return 1; }; echo "retry $((n++))..." >&2; sleep 5; done; }

deploy_sharedflow() {
    local name="$1"
    retry apigeecli sharedflows create bundle -n "$name" -f "sharedflows/$name/sharedflowbundle" -o "$ORG" $FLAGS
    retry apigeecli sharedflows deploy -n "$name" -e "$ENV" -o "$ORG" --ovr --wait $FLAGS
}

deploy_proxy() {
    local name="$1"
    retry apigeecli apis create bundle -n "$name" --proxy-folder "proxies/$name/apiproxy" -o "$ORG" $FLAGS
    retry apigeecli apis deploy -n "$name" -e "$ENV" -o "$ORG" --ovr --wait $FLAGS
}

retry apigeecli targetservers import -f "config/$ENV/targetservers.json" -e "$ENV" -o "$ORG" $FLAGS
[ -f "config/$ENV/products.json" ] && retry apigeecli products import -f "config/$ENV/products.json" --upsert -o "$ORG" $FLAGS

[ "$NAME" = "config" ] && exit 0

if [ -n "$NAME" ]; then
    if [ -d "sharedflows/$NAME" ]; then
        deploy_sharedflow "$NAME"
    elif [ -d "proxies/$NAME" ]; then
        deploy_proxy "$NAME"
    else
        echo "unknown artifact: $NAME (not in sharedflows/ or proxies/)" >&2
        exit 1
    fi
else
    for dir in sharedflows/*/; do [ -e "$dir" ] || break; deploy_sharedflow "$(basename "$dir")"; done
    for dir in proxies/*/; do [ -e "$dir" ] || break; deploy_proxy "$(basename "$dir")"; done
fi