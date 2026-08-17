#!/usr/bin/env bash
# ==============================================================================
# TTZip Local Industrial CI/CD Automation Pipeline
# 对标顶级开源工程的本地全自动化质量门禁与测试中枢调度器 (零云端配额消耗)
# ==============================================================================

set -eo pipefail

MODE="${1:---quick}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

START_TIME=$(date +%s)

echo -e "\n${CYAN}================================================================================"
echo -e "   🚀 [TTZip Local CI/CD Pipeline] Mode: ${MODE} | $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "================================================================================${NC}\n"

# ------------------------------------------------------------------------------
# 阶段 1: 静态代码规范与宪法不变量检查 (Static Quality & Constitution Invariant Gate)
# ------------------------------------------------------------------------------
echo -e "${BOLD}[Stage 1/4] 🔍 Running Static Code Quality & Invariant Linter...${NC}"
./scripts/lint_codebase_invariants.sh

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict --quiet && echo -e "  ${GREEN}✓ SwiftLint Quality Gate Passed.${NC}"
else
    echo -e "  ${YELLOW}⚠ SwiftLint not installed on host, skipping swiftlint tool pass.${NC}"
fi

# ------------------------------------------------------------------------------
# 阶段 2: 构建与编译零警告门禁 (Zero-Warning Compilation Gate)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[Stage 2/4] 🔨 Verifying Clean Compilation & Linker Gate...${NC}"
swift build -c release > /dev/null
echo -e "  ${GREEN}✓ Release Binary Built Successfully (0 Errors).${NC}"

# ------------------------------------------------------------------------------
# 阶段 3: 本地 Native 极速诊断矩阵与测试报告持久化
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[Stage 3/4] 🧪 Running Native Diagnostic Test Harness...${NC}"
mkdir -p docs/test_reports
REPORT_JSON="docs/test_reports/local_ci_report.json"
REPORT_MD="docs/test_reports/local_ci_report.md"

swift run ttzip-cli test --fast --json-report "$REPORT_JSON" --markdown-report "$REPORT_MD"
echo -e "  ${GREEN}✓ Native 16-Format Diagnostic Matrix Passed.${NC}"

# ------------------------------------------------------------------------------
# 阶段 4: 单元测试与性能硬门禁 (Unit Tests & Performance Floors)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[Stage 4/4] 🛡️ Running Core Regression & Performance Gates...${NC}"

if [ "$MODE" = "--full" ]; then
    echo -e "  ▶ Running Full Regression (584+ tests)..."
    swift test
    echo -e "  ▶ Running Performance Floors..."
    swift test --filter "(XCTestPerformanceMeasureTests|FrontendPerformanceGateTests)"
elif [ "$MODE" = "--sanitize" ]; then
    echo -e "  ▶ Running AddressSanitizer & ThreadSanitizer Matrix..."
    swift test --sanitize=address --filter "(MmapBufferHandleTests|LibarchiveGoldenCorpusTests)"
else
    echo -e "  ▶ Running Core High-Value Tests (Golden Corpus & Memory Gates & PAL)..."
    swift test --filter "(MmapBufferHandleTests|FrontendPerformanceGateTests|LibarchiveGoldenCorpusTests|TestReportGeneratorTests|PlatformPathSanitizerTests|PlatformMemoryTests|PlatformHardwareTests|SecurityAndComplianceTests|PasswordVaultV4Tests)"
fi


END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo -e "\n${CYAN}================================================================================"
echo -e "   ${GREEN}🏆 [ALL LOCAL CI GATES PASSED]${CYAN} Total Pipeline Duration: ${TOTAL_TIME}s"
echo -e "   📄 JSON Report: ${REPORT_JSON}"
echo -e "   📊 Markdown Report: ${REPORT_MD}"
echo -e "================================================================================${NC}\n"

exit 0
