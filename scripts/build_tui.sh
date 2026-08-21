#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/build_tui.sh
# 自动化构建 TTZip TUI & CLI 独立 Universal Mach-O 单可执行文件 (bin/ttzip)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUST_DIR="${REPO_ROOT}/rust"
BIN_DIR="${REPO_ROOT}/bin"
OUTPUT_BIN="${BIN_DIR}/ttzip"

BUILD_MODE="release"
CARGO_FLAGS="--release"
BUILD_TARGET=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --release        Build in release mode with LTO and optimizations (default)"
    echo "  --debug          Build in debug mode"
    echo "  --target <TRGT>  Build for specific target (e.g. aarch64-apple-darwin)"
    echo "  --help, -h       Show this help message"
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

echo "========================================================"
echo "🖥️  Building TTZip Standalone TUI & CLI (${BUILD_MODE})"
echo "========================================================"

export PATH="$HOME/.cargo/bin:$PATH"

mkdir -p "${BIN_DIR}"

# 1. 探测支持的编译目标架构
HOST_ARCH="$(uname -m)"
TARGETS=()

if [ -n "${BUILD_TARGET}" ]; then
    TARGETS+=("${BUILD_TARGET}")
else
    # 检测 aarch64-apple-darwin 与 x86_64-apple-darwin
    RUSTUP_TARGETS="$(rustup target list --installed 2>/dev/null || true)"

    if echo "${RUSTUP_TARGETS}" | grep -q "aarch64-apple-darwin"; then
        TARGETS+=("aarch64-apple-darwin")
    fi
    if echo "${RUSTUP_TARGETS}" | grep -q "x86_64-apple-darwin"; then
        TARGETS+=("x86_64-apple-darwin")
    fi

    # 如果 rustup 未列出或为当前宿主机架构
    if [ ${#TARGETS[@]} -eq 0 ]; then
        if [ "${HOST_ARCH}" = "arm64" ]; then
            TARGETS+=("aarch64-apple-darwin")
        else
            TARGETS+=("x86_64-apple-darwin")
        fi
    fi
fi

echo "--> Target architectures: ${TARGETS[*]}"

BUILT_BINS=()

for target in "${TARGETS[@]}"; do
    echo "--> [INFO] Building ttzip for ${target} (${BUILD_MODE})..."
    cargo build --manifest-path "${RUST_DIR}/Cargo.toml" -p ttzip-tui --bin ttzip --target "${target}" ${CARGO_FLAGS}

    TARGET_BIN="${RUST_DIR}/target/${target}/${BUILD_MODE}/ttzip"
    if [ -f "${TARGET_BIN}" ]; then
        BUILT_BINS+=("${TARGET_BIN}")
    else
        echo "❌ Error: Expected binary not found at ${TARGET_BIN}"
        exit 1
    fi
done

# 2. 生成或合并 Universal Mach-O 单可执行文件
echo "--> Creating universal standalone binary: ${OUTPUT_BIN}..."
TEMP_MERGED_BIN="${RUST_DIR}/target/ttzip_merged_bin"
mkdir -p "${RUST_DIR}/target"

if [ ${#BUILT_BINS[@]} -eq 1 ]; then
    cp "${BUILT_BINS[0]}" "${OUTPUT_BIN}"
else
    echo "--> Combining slices via lipo: ${BUILT_BINS[*]}"
    lipo -create "${BUILT_BINS[@]}" -output "${OUTPUT_BIN}"
fi

# 3. 符号优化与执行权限
if [ "${BUILD_MODE}" = "release" ]; then
    echo "--> Stripping symbols for release binary..."
    strip -x "${OUTPUT_BIN}" 2>/dev/null || true
fi

chmod +x "${OUTPUT_BIN}"

echo "========================================================"
echo "✅ [SUCCESS] Standalone binary ready at ${OUTPUT_BIN}"
echo "   Architecture: $(lipo -info "${OUTPUT_BIN}" 2>/dev/null || file "${OUTPUT_BIN}")"
echo "   File Size   : $(ls -lh "${OUTPUT_BIN}" | awk '{print $5}')"
echo "========================================================"
