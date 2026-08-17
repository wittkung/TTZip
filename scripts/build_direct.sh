#!/usr/bin/env bash
set -e

echo "=========================================="
echo "📦 Building TTZip Direct Independent Version"
echo "=========================================="

cd "$(dirname "$0")/.."

echo "--> Compiling release executable..."
swift build -c release

echo "--> Direct build complete! Executable located at: .build/release/TTZipApp"
