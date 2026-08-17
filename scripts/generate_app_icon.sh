#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# Generates multi-resolution Retina AppIcon.icns from logo/AppIcon.png

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER_ICON="$REPO_ROOT/logo/AppIcon.png"
OUTPUT_DIR="$REPO_ROOT/Sources/TTZipApp/Resources"
ICONSET_DIR="/tmp/TTZipApp.iconset"

if [ ! -f "$MASTER_ICON" ]; then
    echo "❌ Error: Master icon not found at $MASTER_ICON"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

echo "🎨 Generating multi-resolution icon layers..."
sips -z 16 16     "$MASTER_ICON" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$MASTER_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$MASTER_ICON" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$MASTER_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$MASTER_ICON" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$MASTER_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$MASTER_ICON" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$MASTER_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$MASTER_ICON" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$MASTER_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

echo "📦 Packaging AppIcon.icns via iconutil..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "✅ AppIcon.icns generated successfully at: $OUTPUT_DIR/AppIcon.icns"
