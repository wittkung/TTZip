#!/usr/bin/env bash
# ==============================================================================
# scripts/build_liblzma.sh
# 自动化编译 xz-upstream (liblzma) 为 macOS Universal 2 (arm64 + x86_64) 静态库并部署到 Vendor
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

XZ_SRC_DIR="${REPO_ROOT}/Vendor/xz-upstream"
WORK_DIR="/tmp/ttzip_build_liblzma_$$"

echo "=========================================="
echo "📦 Building xz-upstream (liblzma) Universal 2 with ARM NEON & ACLE CRC32"
echo "=========================================="

cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if [ ! -d "${XZ_SRC_DIR}" ]; then
    echo "❌ Error: Vendor/xz-upstream source directory does not exist."
    exit 1
fi

# 1. CMake 配置与编译 (Universal 2: arm64 + x86_64)
echo "--> Configuring CMake build for liblzma..."
cmake -B "${WORK_DIR}/build" -S "${XZ_SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
    -DBUILD_SHARED_LIBS=OFF \
    -DXZ_ARM64_CRC32=ON \
    -DXZ_SMALL=OFF \
    -DXZ_THREADS=yes \
    -DXZ_CHECKS="crc32;crc64;sha256" \
    -DXZ_MATCH_FINDERS="hc3;hc4;bt2;bt3;bt4" \
    -DXZ_TOOL_XZ=OFF \
    -DXZ_TOOL_XZDEC=OFF \
    -DXZ_TOOL_LZMADEC=OFF \
    -DXZ_TOOL_LZMAINFO=OFF \
    -DXZ_TOOL_SCRIPTS=OFF \
    -DXZ_DOC=OFF \
    -DXZ_NLS=OFF

echo "--> Compiling liblzma static library..."
cmake --build "${WORK_DIR}/build" --config Release --parallel "$(sysctl -n hw.ncpu)"

# 2. 架构物理断言
echo "--> Verifying binary architectures..."
LIB_PATH="${WORK_DIR}/build/liblzma.a"
if [ ! -f "${LIB_PATH}" ]; then
    # CMake 可能将产物放置在子目录
    LIB_PATH=$(find "${WORK_DIR}/build" -name "liblzma.a" | head -n 1)
fi

if [ -z "${LIB_PATH}" ] || [ ! -f "${LIB_PATH}" ]; then
    echo "❌ Error: liblzma.a was not found in build directory."
    exit 1
fi

LIPO_OUT=$(lipo -info "${LIB_PATH}")
echo "    ${LIPO_OUT}"
if [[ "${LIPO_OUT}" != *"arm64"* ]] || [[ "${LIPO_OUT}" != *"x86_64"* ]]; then
    echo "❌ Error: liblzma.a is not a valid Universal 2 binary (must contain arm64 and x86_64)."
    exit 1
fi

# 3. 同步产物到 Vendor
echo "--> Deploying artifacts to Vendor/..."
mkdir -p "${REPO_ROOT}/Vendor/lib" "${REPO_ROOT}/Vendor/include/lzma"
cp "${LIB_PATH}" "${REPO_ROOT}/Vendor/lib/liblzma.a"
cp "${XZ_SRC_DIR}/src/liblzma/api/lzma.h" "${REPO_ROOT}/Vendor/include/lzma.h"
cp -R "${XZ_SRC_DIR}/src/liblzma/api/lzma/" "${REPO_ROOT}/Vendor/include/lzma/"

# 同步头文件到 xcframework Headers
if [ -d "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/Headers" ]; then
    cp "${XZ_SRC_DIR}/src/liblzma/api/lzma.h" "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/Headers/lzma.h"
    mkdir -p "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/Headers/lzma"
    cp -R "${XZ_SRC_DIR}/src/liblzma/api/lzma/" "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/Headers/lzma/"
fi

# 4. 重新打包 libTTZipVendor.a 与 XCFramework 静态归档
echo "--> Re-bundling libTTZipVendor.a..."
libtool -static -o "${REPO_ROOT}/Vendor/libTTZipVendor.a" "${REPO_ROOT}/Vendor/lib"/*.a
if [ -d "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64" ]; then
    cp "${REPO_ROOT}/Vendor/libTTZipVendor.a" "${REPO_ROOT}/Vendor/TTZipVendor.xcframework/macos-arm64/libTTZipVendor.a"
fi

echo "=========================================="
echo "✅ xz-upstream (liblzma) Universal 2 build & deployment completed successfully!"
echo "=========================================="
