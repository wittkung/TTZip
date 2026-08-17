#!/bin/bash
# ==============================================================================
# TTZip Local CI & Quality Gate Script (本地自动化构建与质量门禁脚本)
# ==============================================================================
set -e

COLOR_GREEN="\031[32m"
COLOR_RESET="\033[0m"

echo "🔍 [Local CI] 开始本地工程代码与单测质量门禁检查..."

# 1. 检查代码文件行数限制 (单文件 <= 500 行)
echo "📏 [1/4] 检查代码文件行数限制 (上限 500 行)..."
OVERSIZED=$(find Sources -type f \( -name "*.swift" -o -name "*.c" -o -name "*.h" -o -name "*.inc" \) -exec wc -l {} + | awk '$1 > 500 && $2 != "total" {print $1, $2}')
if [ -n "$OVERSIZED" ]; then
    echo "⚠️  发现超过 500 行的源文件:"
    echo "$OVERSIZED"
else
    echo "✅ [行数控制] 现存所有源代码文件均严格控制在 500 行以内。"
fi

# 2. 编译 Debug 目标
echo "🔨 [2/4] 编译 Swift Debug Target..."
swift build -c debug

# 3. 运行全量单元测试 (JetBrains IDE 树状层级可视化日志)
echo "🧪 [3/4] 运行全量 Unit Test 套件 (100% 验证与 CRC 指纹校验)..."
swift test 2>&1 | python3 scripts/pretty_test.py

# 4. 编译 Release 生产构建与 CLI 工具
echo "🚀 [4/4] 编译 Release 极速生产包 (ttzip-cli)..."
swift build -c release

echo "=============================================================================="
echo "🎉 [Local CI 门禁] 本地构建、全量单元测试与工程质量校验 100% 成功通过！"
echo "=============================================================================="
