#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/build_zlib_ng.sh
# 自动化编译 zlib-ng (ZLIB_COMPAT=ON) 静态库并部署到 Vendor 目录
# 支持平台: macOS Universal 2 (arm64 + x86_64), Linux (x86_64 / aarch64), Windows
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 默认配置参数
ZLIB_NG_TAG="${ZLIB_NG_TAG:-2.2.4}"
ZLIB_NG_REPO="${ZLIB_NG_REPO:-https://github.com/zlib-ng/zlib-ng.git}"
WORK_DIR="/tmp/ttzip_build_zlib_ng_$$"
VENDOR_DIR="${REPO_ROOT}/Vendor"
SRC_DIR=""

echo "========================================================================"
echo "📦 Building zlib-ng (${ZLIB_NG_TAG}) - High-Performance Streaming Deflate"
echo "========================================================================"

cleanup() {
    if [ -n "${WORK_DIR:-}" ] && [ -d "${WORK_DIR}" ]; then
        rm -rf "${WORK_DIR}"
    fi
}
trap cleanup EXIT

# 0. 依赖工具链检查
if ! command -v cmake >/dev/null 2>&1; then
    echo "❌ Error: cmake is required but not found in PATH." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "❌ Error: git is required but not found in PATH." >&2
    exit 1
fi

# 1. 准备源码 (优先使用本地 Vendor/zlib-ng，若不存在则克隆到临时工作区)
if [ -d "${VENDOR_DIR}/zlib-ng" ] && [ -f "${VENDOR_DIR}/zlib-ng/CMakeLists.txt" ]; then
    echo "--> Using existing local source in ${VENDOR_DIR}/zlib-ng..."
    SRC_DIR="${VENDOR_DIR}/zlib-ng"
else
    echo "--> Cloning zlib-ng (${ZLIB_NG_TAG}) from ${ZLIB_NG_REPO}..."
    mkdir -p "${WORK_DIR}"
    git clone --depth 1 --branch "${ZLIB_NG_TAG}" "${ZLIB_NG_REPO}" "${WORK_DIR}/src" || {
        echo "⚠️ Failed to clone specific tag ${ZLIB_NG_TAG}, falling back to default branch..."
        git clone --depth 1 "${ZLIB_NG_REPO}" "${WORK_DIR}/src"
    }
    SRC_DIR="${WORK_DIR}/src"
fi

BUILD_DIR="${WORK_DIR}/build"
mkdir -p "${BUILD_DIR}"

# 2. 跨平台 CMake 配置与编译
OS_NAME="$(uname -s)"
NUM_CORES=4
if command -v sysctl >/dev/null 2>&1; then
    NUM_CORES="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
elif command -v nproc >/dev/null 2>&1; then
    NUM_CORES="$(nproc 2>/dev/null || echo 4)"
fi

echo "--> Detected host OS: ${OS_NAME} (CPU cores: ${NUM_CORES})"

case "${OS_NAME}" in
    Darwin*)
        echo "--> Configuring for macOS Universal 2 (arm64 + x86_64)..."
        cmake -B "${BUILD_DIR}" -S "${SRC_DIR}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DZLIB_COMPAT=ON \
            -DWITH_NATIVE_INSTRUCTIONS=ON \
            -DDYNAMIC_CPU_DISPATCH=ON \
            -DZLIB_ENABLE_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
            -DCMAKE_C_FLAGS_RELEASE="-O3"

        echo "--> Compiling static library (Universal 2)..."
        cmake --build "${BUILD_DIR}" --config Release --parallel "${NUM_CORES}"

        # 架构物理断言
        STATIC_LIB="${BUILD_DIR}/libz.a"
        if [ ! -f "${STATIC_LIB}" ]; then
            echo "❌ Error: Expected build artifact ${STATIC_LIB} not found." >&2
            exit 1
        fi

        echo "--> Verifying binary architectures with lipo..."
        if command -v lipo >/dev/null 2>&1; then
            LIPO_OUT="$(lipo -info "${STATIC_LIB}")"
            echo "    ${LIPO_OUT}"
            if [[ "${LIPO_OUT}" != *"arm64"* ]] || [[ "${LIPO_OUT}" != *"x86_64"* ]]; then
                echo "❌ Error: libz.a is not a valid Universal 2 binary (must contain arm64 and x86_64)." >&2
                exit 1
            fi
        fi

        # 同步产物到 Vendor
        echo "--> Deploying static library and headers to Vendor/..."
        mkdir -p "${VENDOR_DIR}/lib" "${VENDOR_DIR}/include"
        cp "${STATIC_LIB}" "${VENDOR_DIR}/lib/libz.a"

        # 复制 zlib-ng 生成的兼容头文件
        if [ -f "${BUILD_DIR}/zlib.h" ]; then
            cp "${BUILD_DIR}/zlib.h" "${VENDOR_DIR}/include/zlib.h"
        elif [ -f "${SRC_DIR}/zlib.h" ]; then
            cp "${SRC_DIR}/zlib.h" "${VENDOR_DIR}/include/zlib.h"
        fi

        if [ -f "${BUILD_DIR}/zconf.h" ]; then
            cp "${BUILD_DIR}/zconf.h" "${VENDOR_DIR}/include/zconf.h"
        elif [ -f "${SRC_DIR}/zconf.h" ]; then
            cp "${SRC_DIR}/zconf.h" "${VENDOR_DIR}/include/zconf.h"
        fi

        if [ -f "${BUILD_DIR}/zlib_name_mangling.h" ]; then
            cp "${BUILD_DIR}/zlib_name_mangling.h" "${VENDOR_DIR}/include/zlib_name_mangling.h"
        fi

        # 同步头文件至 XCFramework Headers
        XCFRAMEWORK_HEADERS="${VENDOR_DIR}/TTZipVendor.xcframework/macos-arm64/Headers"
        if [ -d "${XCFRAMEWORK_HEADERS}" ]; then
            [ -f "${VENDOR_DIR}/include/zlib.h" ] && cp "${VENDOR_DIR}/include/zlib.h" "${XCFRAMEWORK_HEADERS}/zlib.h"
            [ -f "${VENDOR_DIR}/include/zconf.h" ] && cp "${VENDOR_DIR}/include/zconf.h" "${XCFRAMEWORK_HEADERS}/zconf.h"
        fi

        # 重新打包 libTTZipVendor.a 与 XCFramework 静态归档
        echo "--> Re-bundling libTTZipVendor.a..."
        if command -v libtool >/dev/null 2>&1; then
            libtool -static -o "${VENDOR_DIR}/libTTZipVendor.a" "${VENDOR_DIR}/lib"/*.a
            XCFRAMEWORK_LIB="${VENDOR_DIR}/TTZipVendor.xcframework/macos-arm64/libTTZipVendor.a"
            if [ -d "$(dirname "${XCFRAMEWORK_LIB}")" ]; then
                cp "${VENDOR_DIR}/libTTZipVendor.a" "${XCFRAMEWORK_LIB}"
            fi
            echo "✅ libTTZipVendor.a bundled with zlib-ng successfully."
        fi
        ;;

    Linux*)
        echo "--> Configuring for Linux (PIC static library)..."
        cmake -B "${BUILD_DIR}" -S "${SRC_DIR}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DZLIB_COMPAT=ON \
            -DWITH_NATIVE_INSTRUCTIONS=ON \
            -DDYNAMIC_CPU_DISPATCH=ON \
            -DZLIB_ENABLE_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_C_FLAGS_RELEASE="-O3 -fPIC"

        echo "--> Compiling static library (Linux)..."
        cmake --build "${BUILD_DIR}" --config Release --parallel "${NUM_CORES}"

        STATIC_LIB="${BUILD_DIR}/libz.a"
        if [ ! -f "${STATIC_LIB}" ]; then
            echo "❌ Error: Expected build artifact ${STATIC_LIB} not found." >&2
            exit 1
        fi

        echo "--> Deploying static library and headers to Vendor/..."
        mkdir -p "${VENDOR_DIR}/lib" "${VENDOR_DIR}/include"
        cp "${STATIC_LIB}" "${VENDOR_DIR}/lib/libz.a"
        [ -f "${BUILD_DIR}/zlib.h" ] && cp "${BUILD_DIR}/zlib.h" "${VENDOR_DIR}/include/zlib.h"
        [ -f "${BUILD_DIR}/zconf.h" ] && cp "${BUILD_DIR}/zconf.h" "${VENDOR_DIR}/include/zconf.h"
        ;;

    MINGW*|MSYS*|CYGWIN*|Windows_NT*)
        echo "--> Configuring for Windows (Static Library)..."
        cmake -B "${BUILD_DIR}" -S "${SRC_DIR}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DZLIB_COMPAT=ON \
            -DWITH_NATIVE_INSTRUCTIONS=ON \
            -DDYNAMIC_CPU_DISPATCH=ON \
            -DZLIB_ENABLE_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF

        echo "--> Compiling static library (Windows)..."
        cmake --build "${BUILD_DIR}" --config Release --parallel "${NUM_CORES}"

        mkdir -p "${VENDOR_DIR}/lib" "${VENDOR_DIR}/include"
        # 兼容不同生成器的产物命名与路径
        if [ -f "${BUILD_DIR}/Release/zlibstatic.lib" ]; then
            cp "${BUILD_DIR}/Release/zlibstatic.lib" "${VENDOR_DIR}/lib/zlibstatic.lib"
            cp "${BUILD_DIR}/Release/zlibstatic.lib" "${VENDOR_DIR}/lib/libz.a" 2>/dev/null || true
        elif [ -f "${BUILD_DIR}/zlibstatic.lib" ]; then
            cp "${BUILD_DIR}/zlibstatic.lib" "${VENDOR_DIR}/lib/zlibstatic.lib"
            cp "${BUILD_DIR}/zlibstatic.lib" "${VENDOR_DIR}/lib/libz.a" 2>/dev/null || true
        elif [ -f "${BUILD_DIR}/libz.a" ]; then
            cp "${BUILD_DIR}/libz.a" "${VENDOR_DIR}/lib/libz.a"
        fi

        [ -f "${BUILD_DIR}/zlib.h" ] && cp "${BUILD_DIR}/zlib.h" "${VENDOR_DIR}/include/zlib.h"
        [ -f "${BUILD_DIR}/zconf.h" ] && cp "${BUILD_DIR}/zconf.h" "${VENDOR_DIR}/include/zconf.h"
        ;;

    *)
        echo "❌ Error: Unsupported platform ${OS_NAME}" >&2
        exit 1
        ;;
esac

echo "========================================================================"
echo "✅ zlib-ng (${ZLIB_NG_TAG}) build and deployment finished successfully!"
echo "========================================================================"
