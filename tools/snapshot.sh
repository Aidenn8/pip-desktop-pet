#!/bin/zsh
# Renders preview PNGs of every mood and card tab into the given folder.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/snapshots}"
mkdir -p "$OUT" build
swiftc -D SNAPSHOT -target "$(uname -m)-apple-macos13.0" -framework AppKit -framework SwiftUI \
  $(ls Sources/*.swift | grep -v main.swift) tools/main.swift -o build/snapshot
build/snapshot "$OUT"
echo "Wrote previews to $OUT"
