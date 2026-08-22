#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# create_dmg_installer.sh: Builds professional Retina DMG disk image installer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_PATH="${WORKSPACE_ROOT}/dist/TTZip.app"
VOL_NAME="TTZip"
OUTPUT_DMG="${WORKSPACE_ROOT}/dist/TTZip.dmg"
BG_IMAGE="${WORKSPACE_ROOT}/resources/dmg_background.png"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) APP_PATH="$2"; shift 2 ;;
        --volname) VOL_NAME="$2"; shift 2 ;;
        --output) OUTPUT_DMG="$2"; shift 2 ;;
        --background) BG_IMAGE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: App bundle not found at ${APP_PATH}"
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT_DMG}")"

# 1. Ensure Retina background image exists
if [ ! -f "${BG_IMAGE}" ]; then
    python3 "${SCRIPT_DIR}/generate_dmg_background.py"
fi

TEMP_DMG="/tmp/${VOL_NAME}_temp.dmg"
rm -f "${TEMP_DMG}" "${OUTPUT_DMG}"

echo "==> [DMG] Creating staging DMG image (140MB HFS+)..."
hdiutil create -size 140m -fs HFS+ -volname "${VOL_NAME}" -ov "${TEMP_DMG}" >/dev/null

echo "==> [DMG] Attaching staging disk image..."
MOUNT_INFO="$(hdiutil attach -nobrowse -noverify -noautoopen "${TEMP_DMG}")"
DEV_NODE="$(echo "${MOUNT_INFO}" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')"
MOUNT_POINT="$(echo "${MOUNT_INFO}" | grep "/Volumes/" | awk -F'\t' '{print $NF}' | tr -d '\n')"

if [ -z "${MOUNT_POINT}" ] || [ ! -d "${MOUNT_POINT}" ]; then
    echo "❌ Error: Failed to mount staging DMG"; exit 1
fi

echo "  ✓ Mounted at ${MOUNT_POINT} (${DEV_NODE})"

cleanup() {
    if [ -n "${MOUNT_POINT:-}" ] && [ -d "${MOUNT_POINT}" ]; then
        hdiutil detach "${DEV_NODE}" -force >/dev/null 2>&1 || true
    fi
    rm -f "${TEMP_DMG}"
}
trap cleanup EXIT

# 2. Copy contents & symlinks
echo "==> [DMG] Staging application and filesystem assets..."
cp -R "${APP_PATH}" "${MOUNT_POINT}/"
ln -s /Applications "${MOUNT_POINT}/Applications"

# Background directory
mkdir -p "${MOUNT_POINT}/.background"
cp "${BG_IMAGE}" "${MOUNT_POINT}/.background/dmg_background.png"

# Volume Icon
ICON_SRC="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [ -f "${ICON_SRC}" ]; then
    cp "${ICON_SRC}" "${MOUNT_POINT}/.VolumeIcon.icns"
    # Set volume icon bit if SetFile is available
    if command -v SetFile >/dev/null 2>&1; then
        SetFile -a C "${MOUNT_POINT}" 2>/dev/null || true
    fi
fi

# 3. Configure Finder layout via AppleScript
echo "==> [DMG] Styling Finder window layout and icon spatial alignment..."
osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 120
        set text size of opts to 12
        set background picture of opts to file ".background:dmg_background.png"
        
        set position of item "TTZip.app" of container window to {140, 205}
        set position of item "Applications" of container window to {460, 205}
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# 4. Flush and detach
echo "==> [DMG] Finalizing and unmounting staging disk image..."
sync
sleep 1
hdiutil detach "${DEV_NODE}" >/dev/null 2>&1 || hdiutil detach "${MOUNT_POINT}" -force >/dev/null 2>&1 || true
MOUNT_POINT=""

# 5. Convert to high-compression read-only final DMG
echo "==> [DMG] Compressing into release UDZO DMG image..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -ov -o "${OUTPUT_DMG}" >/dev/null
rm -f "${TEMP_DMG}"

# 6. Sign DMG image
codesign --force --sign - "${OUTPUT_DMG}" 2>/dev/null || true

DMG_SHA256="$(shasum -a 256 "${OUTPUT_DMG}" | awk '{print $1}')"
DMG_SIZE="$(du -h "${OUTPUT_DMG}" | awk '{print $1}')"

echo "======================================================================"
echo "✅ Retina DMG Installer Created Successfully!"
echo "   File   : ${OUTPUT_DMG}"
echo "   Size   : ${DMG_SIZE}"
echo "   SHA256 : ${DMG_SHA256}"
echo "======================================================================"
