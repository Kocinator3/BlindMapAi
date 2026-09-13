#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
"$FLUTTER_BIN" build linux --release
mkdir -p dist
cp LICENSE README.md docs/DATA_SOURCES.md build/linux/x64/release/bundle/
tar -C build/linux/x64/release/bundle -czf dist/slepamapa-linux-x64.tar.gz .
echo 'Created dist/slepamapa-linux-x64.tar.gz. Extract the whole archive, then run slepa_mapa.'
