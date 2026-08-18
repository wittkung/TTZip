#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/build_libdeflate.sh
# 自动化编译 libdeflate 为 macOS Universal 2 (arm64 + x86_64) 静态库并部署到 Vendor
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LIBDEFLATE_TAG="${LIBDEFLATE_TAG:-v1.22}"
LIBDEFLATE_REPO="https://github.com/ebiggers/libdeflate.git"
WORK_DIR="/tmp/ttzip_build_libdeflate_$$"

echo "=========================================="
echo "📦 Building libdeflate (${LIBDEFLATE_TAG}) Universal 2"
echo "=========================================="

cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

# 1. 检出源码
echo "--> Cloning libdeflate ${LIBDEFLATE_TAG}..."
git clone --depth 1 --branch "${LIBDEFLATE_TAG}" "${LIBDEFLATE_REPO}" "${WORK_DIR}/src"

# 2. CMake 配置与编译 (Universal 2: arm64 + x86_64)
echo "--> Configuring CMake build..."
cmake -B "${WORK_DIR}/build" -S "${WORK_DIR}/src" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_C_FLAGS_RELEASE="-O3" \
    -DLIBDEFLATE_BUILD_STATIC_LIB=ON \
    -DLIBDEFLATE_BUILD_SHARED_LIB=OFF \
    -DLIBDEFLATE_BUILD_GZIP=OFF \
    -DLIBDEFLATE_BUILD_TESTS=OFF

echo "--> Compiling static library..."
cmake --build "${WORK_DIR}/build" --config Release --parallel "$(sysctl -n hw.ncpu)"

# 3. 架构物理断言
echo "--> Verifying binary architectures..."
LIPO_OUT=$(lipo -info "${WORK_DIR}/build/libdeflate.a")
echo "    ${LIPO_OUT}"
if [[ "${LIPO_OUT}" != *"arm64"* ]] || [[ "${LIPO_OUT}" != *"x86_64"* ]]; then
    echo "❌ Error: libdeflate.a is not a valid Universal 2 binary (must contain arm64 and x86_64)."
    exit 1
fi

# 4. 同步产物到 Vendor
echo "--> Deploying artifacts to Vendor/..."
mkdir -p "${REPO_ROOT}/Vendor/lib" "${REPO_ROOT}/Vendor/include"
cp "${WORK_DIR}/build/libdeflate.a" "${REPO_ROOT}/Vendor/lib/libdeflate.a"
cp "${WORK_DIR}/src/libdeflate.h" "${REPO_ROOT}/Vendor/include/libdeflate.h"

# 同步头文件到 xcframework Headers
if [ -d "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/Headers" ]; then
    cp "${WORK_DIR}/src/libdeflate.h" "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/Headers/libdeflate.h"
fi

# 5. 重新打包 libTTZipVendor.a 与 XCFramework 静态归档
echo "--> Re-bundling libTTZipVendor.a..."
libtool -static -o "${REPO_ROOT}/Vendor/libTTZipVendor.a" "${REPO_ROOT}/Vendor/lib"/*.a
if [ -d "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64" ]; then
    cp "${REPO_ROOT}/Vendor/libTTZipVendor.a" "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/libTTZipVendor.a"
fi

echo "=========================================="
echo "✅ libdeflate ${LIBDEFLATE_TAG} Universal 2 build & deployment completed successfully!"
echo "=========================================="
