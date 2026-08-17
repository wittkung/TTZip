#!/bin/bash
# ==============================================================================
# scripts/bootstrap_turbobench.sh
# 一键自动拉取并构建 powturbo/TurboBench 纯内存基准测试工具
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${ROOT_DIR}/Vendor/turbobench"

echo "========================================================================"
echo "🚀 正在部署/同步 powturbo/TurboBench 官方纯内存跑分工具链..."
echo "========================================================================"

if [ ! -d "${VENDOR_DIR}" ]; then
    echo "📦 正在克隆 powturbo/TurboBench 仓库到 Vendor/turbobench..."
    git clone --depth 1 https://github.com/powturbo/TurboBench.git "${VENDOR_DIR}"
else
    echo "🔄 正在更新 Vendor/turbobench 源码..."
    (cd "${VENDOR_DIR}" && git pull --rebase || true)
fi

echo "🔨 正在编译 TurboBench 原生可执行文件..."
if command -v make >/dev/null 2>&1; then
    make -C "${VENDOR_DIR}" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)" || {
        echo "⚠️ 标准 make 编译出现局部警告，尝试构建核心轻量版本..."
        make -C "${VENDOR_DIR}" turbobench || true
    }
fi

if [ -f "${VENDOR_DIR}/turbobench" ]; then
    chmod +x "${VENDOR_DIR}/turbobench"
    echo "✅ TurboBench 构建成功: ${VENDOR_DIR}/turbobench"
    echo "💡 可直接执行: ${VENDOR_DIR}/turbobench -h"
else
    echo "⚠️ 未找到编译产物 turbobench，请检查本地 Clang/GCC/Make 工具链。"
fi

echo "========================================================================"
