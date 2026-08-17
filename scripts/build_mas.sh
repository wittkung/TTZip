#!/usr/bin/env bash
set -e

echo "=========================================="
echo "🏬 Building TTZip Mac App Store (MAS) Sandboxed Version"
echo "=========================================="

cd "$(dirname "$0")/.."

echo "--> Compiling release executable with -DMAS_BUILD..."
swift build -c release -Xswiftc -DMAS_BUILD

echo "--> MAS Sandboxed build complete! Executable located at: .build/release/TTZipApp"
