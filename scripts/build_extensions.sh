#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# build_extensions.sh: Compiles and packages TTZipQuickLook.appex and TTZipFinderSync.appex plugins.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${WORKSPACE_ROOT}/dist/PlugIns"

mkdir -p "${OUTPUT_DIR}"

echo "==> [Extensions] Compiling App Extension Products (TTZipQuickLook & TTZipFinderSync)..."
swift build -c release --product TTZipQuickLook
swift build -c release --product TTZipFinderSync

BUILD_DIR="$(dirname "$(find "${WORKSPACE_ROOT}/.build" -type f -name "libTTZipQuickLook.dylib" 2>/dev/null | grep -E "release" | grep -v "\.dSYM" | head -n 1)")"

if [ -z "${BUILD_DIR}" ] || [ ! -d "${BUILD_DIR}" ]; then
    echo "❌ Error: Release build directory not found"; exit 1
fi

# 1. Assemble QuickLook Extension (.appex)
QL_BUNDLE="${OUTPUT_DIR}/TTZipQuickLook.appex"
QL_CONTENTS="${QL_BUNDLE}/Contents"
QL_MACOS="${QL_CONTENTS}/MacOS"
rm -rf "${QL_BUNDLE}"
mkdir -p "${QL_MACOS}"

cp "${BUILD_DIR}/libTTZipQuickLook.dylib" "${QL_MACOS}/TTZipQuickLook"
chmod +x "${QL_MACOS}/TTZipQuickLook"
cp "${WORKSPACE_ROOT}/Sources/TTZipQuickLook/Info.plist" "${QL_CONTENTS}/Info.plist"
echo "BNDL????" > "${QL_CONTENTS}/PkgInfo"
install_name_tool -add_rpath @executable_path/../../Frameworks "${QL_MACOS}/TTZipQuickLook" 2>/dev/null || true
codesign --force --deep --sign - "${QL_BUNDLE}" 2>/dev/null || true
echo "  ✓ TTZipQuickLook.appex assembled and signed"

# 2. Assemble FinderSync Extension (.appex)
FS_BUNDLE="${OUTPUT_DIR}/TTZipFinderSync.appex"
FS_CONTENTS="${FS_BUNDLE}/Contents"
FS_MACOS="${FS_CONTENTS}/MacOS"
rm -rf "${FS_BUNDLE}"
mkdir -p "${FS_MACOS}"

cp "${BUILD_DIR}/libTTZipFinderSync.dylib" "${FS_MACOS}/TTZipFinderSync"
chmod +x "${FS_MACOS}/TTZipFinderSync"
cp "${WORKSPACE_ROOT}/Sources/TTZipFinderSync/Info.plist" "${FS_CONTENTS}/Info.plist"
echo "BNDL????" > "${FS_CONTENTS}/PkgInfo"
install_name_tool -add_rpath @executable_path/../../Frameworks "${FS_MACOS}/TTZipFinderSync" 2>/dev/null || true
codesign --force --deep --sign - "${FS_BUNDLE}" 2>/dev/null || true
echo "  ✓ TTZipFinderSync.appex assembled and signed"

echo "==> [Extensions] All plugins assembled in ${OUTPUT_DIR}"
