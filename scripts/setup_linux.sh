#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
missing=0
for tool in flutter cmake ninja clang pkg-config; do
  if ! command -v "$tool" >/dev/null; then
    echo "Missing: $tool"
    missing=1
  fi
done
if ! pkg-config --exists gtk+-3.0; then
  echo 'Missing GTK 3 development files.'
  missing=1
fi
if ((missing)); then
  echo 'Install Flutter stable: https://docs.flutter.dev/install'
  echo 'Ubuntu/Debian native dependencies: clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev'
  echo 'Arch Linux: clang cmake ninja pkgconf gtk3'
  echo 'No privileged commands were run.'
  exit 1
fi
flutter pub get
flutter doctor -v
