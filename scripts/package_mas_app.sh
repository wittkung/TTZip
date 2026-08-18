#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# SPDX-License-Identifier: BSD-3-Clause
#
# Production Mac App Store (MAS) Packaging & Verification Pipeline

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/.build/release"
DIST_MAS_DIR="$REPO_ROOT/dist/mas"
APP_BUNDLE="$DIST_MAS_DIR/TTZip.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$REPO_ROOT/Sources/TTZipApp/TTZip.entitlements"
INFO_PLIST="$REPO_ROOT/Sources/TTZipApp/Info.plist"
PRIVACY_INFO="$REPO_ROOT/Sources/TTZipApp/PrivacyInfo.xcprivacy"
ICON_ASSET="$REPO_ROOT/Sources/TTZipApp/Resources/AppIcon.icns"

echo "======================================================================"
echo "🏬 TTZip Mac App Store (MAS) Production Packaging & Signing Pipeline"
echo "======================================================================"

cd "$REPO_ROOT"

# Step 1: Ensure AppIcon.icns exists
if [ ! -f "$ICON_ASSET" ]; then
    echo "--> Generating AppIcon.icns..."
    ./scripts/generate_app_icon.sh
fi

# Step 2: Compile Release Binary with MAS_BUILD flag
echo "--> Compiling release binary with -DMAS_BUILD flag..."
swift build -c release -Xswiftc -DMAS_BUILD --product TTZipApp

BIN_SRC="$BUILD_DIR/TTZipApp"
if [ ! -f "$BIN_SRC" ]; then
    echo "❌ Error: Compiled executable not found at $BIN_SRC"
    exit 1
fi

# Step 3: Construct .app Bundle
echo "--> Constructing $APP_BUNDLE layout..."
rm -rf "$DIST_MAS_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy and strip binary
cp "$BIN_SRC" "$MACOS_DIR/TTZip"
strip -x "$MACOS_DIR/TTZip" 2>/dev/null || true

# Copy Info.plist & PkgInfo
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy Resources
cp "$ICON_ASSET" "$RESOURCES_DIR/AppIcon.icns"
cp "$PRIVACY_INFO" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"

# Step 4: Ad-hoc / Local Signing with Hardened Runtime & Sandbox Entitlements
echo "--> Code-signing $APP_BUNDLE with App Sandbox entitlements..."
codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP_BUNDLE"

# Step 5: Verification
echo "--> Verifying code signature and sandbox entitlements..."
codesign -dvvv "$APP_BUNDLE" 2>&1 | grep -E "(Identifier|Format|Signature|Authority)" || true
codesign -d --entitlements :- "$APP_BUNDLE" 2>&1 | grep -E "(app-sandbox|user-selected|downloads|bookmarks)" || true

echo "======================================================================"
echo "✅ MAS App Bundle successfully packaged at:"
echo "   $APP_BUNDLE"
echo "======================================================================"
