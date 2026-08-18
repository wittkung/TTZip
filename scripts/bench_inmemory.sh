#!/bin/bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/bench_inmemory.sh
# TTZip 纯内存极限性能基准测试与 TurboBench 对齐运行脚本
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FORMATS="${1:-zip,7z,zstd,lz4}"
LEVELS="${2:-1,6}"
INPUT_FILE="${3:-}"

echo "========================================================================"
echo "⚡ TTZip 纯内存基准测试引擎 (TurboBench / lzbench 硬件时钟校准模式)"
echo "========================================================================"
echo "🎯 目标格式: ${FORMATS}"
echo "📊 压缩级别: ${LEVELS}"

CMD_ARGS=("bench" "--in-memory" "--compat-turbobench" "-f" "${FORMATS}" "-l" "${LEVELS}")

if [ -n "${INPUT_FILE}" ] && [ -f "${INPUT_FILE}" ]; then
    echo "📁 自定义输入语料: ${INPUT_FILE}"
    CMD_ARGS+=("-i" "${INPUT_FILE}")
fi

(cd "${ROOT_DIR}" && swift run ttzip-cli "${CMD_ARGS[@]}")
