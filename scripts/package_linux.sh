#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build linux --release
mkdir -p dist
tar -C build/linux/x64/release/bundle -czf dist/slepamapa-linux-x64.tar.gz .
echo 'Created dist/slepamapa-linux-x64.tar.gz. Extract the whole archive, then run slepa_mapa.'
