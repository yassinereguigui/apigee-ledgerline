#!/usr/bin/env bash

set -euo pipefail

REPO="yassinereguigui/ledgerline"
REF="abc78dbaf552059ab771050fd673a3034d0f6770" 
DEST="specs/openapi.yaml"

URL="https://raw.githubusercontent.com/${REPO}/${REF}/openapi.yaml"
echo "Fetching ${URL}"
curl -fsSL "$URL" -o "$DEST"
echo "Wrote ${DEST} ($(wc -l < "$DEST") lines) @ ${REF:0:12}"