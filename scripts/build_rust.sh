#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/build_rust.sh
# 自动化编译 TTZip Rust 胶水层 (ttzip-glue) 并部署 Universal 静态库到 Vendor
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUST_DIR="${REPO_ROOT}/rust"
VENDOR_DIR="${REPO_ROOT}/Vendor"
VENDOR_LIB_DIR="${VENDOR_DIR}/lib"
XCFRAMEWORK_MAC_DIR="${VENDOR_DIR}/TTZipVendor.xcframework/macos-arm64"
HEADER_OUT="${REPO_ROOT}/Sources/CTTZipBridge/include/ttzip_rust_glue.h"

BUILD_MODE="release"
CARGO_FLAGS="--release"
BUILD_TARGET=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --release        Build in release mode with LTO and -O3 (default)"
    echo "  --debug          Build in debug mode"
    echo "  --target <TRGT>  Build specific target (e.g. aarch64-apple-darwin)"
    echo "  --help           Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            BUILD_MODE="release"
            CARGO_FLAGS="--release"
            shift
            ;;
        --debug)
            BUILD_MODE="debug"
            CARGO_FLAGS=""
            shift
            ;;
        --target)
            BUILD_TARGET="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "=========================================="
echo "📦 Building TTZip Rust Core Glue Layer (${BUILD_MODE})"
echo "=========================================="

export PATH="$HOME/.cargo/bin:$PATH"

mkdir -p "${VENDOR_LIB_DIR}" "${VENDOR_DIR}/include" "${REPO_ROOT}/Sources/CTTZipBridge/include"

# 1. 探测支持的编译目标架构
HOST_ARCH="$(uname -m)"
TARGETS=()

if [ -n "${BUILD_TARGET}" ]; then
    TARGETS+=("${BUILD_TARGET}")
else
    # 默认多架构支持: 检测 aarch64-apple-darwin 与 x86_64-apple-darwin
    RUSTUP_TARGETS="$(rustup target list --installed 2>/dev/null || true)"
    
    if echo "${RUSTUP_TARGETS}" | grep -q "aarch64-apple-darwin"; then
        TARGETS+=("aarch64-apple-darwin")
    fi
    if echo "${RUSTUP_TARGETS}" | grep -q "x86_64-apple-darwin"; then
        TARGETS+=("x86_64-apple-darwin")
    fi
    
    # 如果 rustup 没有列出或者使用的是非 rustup 工具链，回退到当前 host target
    if [ ${#TARGETS[@]} -eq 0 ]; then
        if [ "${HOST_ARCH}" = "arm64" ]; then
            TARGETS+=("aarch64-apple-darwin")
        else
            TARGETS+=("x86_64-apple-darwin")
        fi
    fi
fi

echo "--> Target architectures: ${TARGETS[*]}"

BUILT_LIBS=()

for target in "${TARGETS[@]}"; do
    echo "--> [INFO] Building ttzip-glue for ${target} (${BUILD_MODE})..."
    cargo build --manifest-path "${RUST_DIR}/Cargo.toml" --target "${target}" ${CARGO_FLAGS}
    
    TARGET_LIB="${RUST_DIR}/target/${target}/${BUILD_MODE}/libttzip_glue.a"
    if [ -f "${TARGET_LIB}" ]; then
        BUILT_LIBS+=("${TARGET_LIB}")
    else
        echo "❌ Error: Expected static library not found at ${TARGET_LIB}"
        exit 1
    fi
done

# 2. 生成或合并 Universal 静态库 libttzip_glue.a
echo "--> Creating universal / standalone libttzip_glue.a..."
TEMP_GLUE_LIB="${RUST_DIR}/target/libttzip_glue_merged.a"
mkdir -p "${RUST_DIR}/target"

if [ ${#BUILT_LIBS[@]} -eq 1 ]; then
    cp "${BUILT_LIBS[0]}" "${TEMP_GLUE_LIB}"
else
    echo "--> Combining slices via lipo: ${BUILT_LIBS[*]}"
    lipo -create "${BUILT_LIBS[@]}" -output "${TEMP_GLUE_LIB}"
fi

cp "${TEMP_GLUE_LIB}" "${VENDOR_LIB_DIR}/libttzip_glue.a"
rm -f "${TEMP_GLUE_LIB}"

echo "    libttzip_glue.a architecture: $(lipo -info "${VENDOR_LIB_DIR}/libttzip_glue.a")"

# 3. 重新打包 libTTZipVendor.a (包含 libttzip_glue.a 与已有 vendor 库)
echo "--> [INFO] Creating Universal static library via libtool / lipo: Vendor/libTTZipVendor.a..."
libtool -static -o "${VENDOR_DIR}/libTTZipVendor.a" "${VENDOR_LIB_DIR}"/*.a

if [ -d "${XCFRAMEWORK_MAC_DIR}" ]; then
    echo "--> Syncing libTTZipVendor.a to ${XCFRAMEWORK_MAC_DIR}/libTTZipVendor.a..."
    if lipo -info "${VENDOR_DIR}/libTTZipVendor.a" | grep -q "arm64"; then
        lipo "${VENDOR_DIR}/libTTZipVendor.a" -extract arm64 -output "${XCFRAMEWORK_MAC_DIR}/libTTZipVendor.a" 2>/dev/null || \
            cp "${VENDOR_DIR}/libTTZipVendor.a" "${XCFRAMEWORK_MAC_DIR}/libTTZipVendor.a"
    else
        cp "${VENDOR_DIR}/libTTZipVendor.a" "${XCFRAMEWORK_MAC_DIR}/libTTZipVendor.a"
    fi
    strip -S -x "${XCFRAMEWORK_MAC_DIR}/libTTZipVendor.a" 2>/dev/null || true
fi
strip -S -x "${VENDOR_DIR}/libTTZipVendor.a" 2>/dev/null || true

# 4. 生成或维护 C-ABI 头文件
echo "--> [INFO] Generating C headers: Sources/CTTZipBridge/include/ttzip_rust_glue.h..."
if command -v cbindgen &>/dev/null; then
    echo "--> Running cbindgen..."
    cbindgen --config "${RUST_DIR}/ttzip-glue/cbindgen.toml" "${RUST_DIR}/ttzip-glue" --output "${HEADER_OUT}" || true
fi

# 同步头文件至 Vendor/include 与 XCFramework Headers
cp "${HEADER_OUT}" "${VENDOR_DIR}/include/ttzip_rust_glue.h"
if [ -d "${XCFRAMEWORK_MAC_DIR}/Headers" ]; then
    cp "${HEADER_OUT}" "${XCFRAMEWORK_MAC_DIR}/Headers/ttzip_rust_glue.h"
fi

echo "=========================================="
echo "✅ [SUCCESS] Rust glue universal library generated successfully."
echo "=========================================="
