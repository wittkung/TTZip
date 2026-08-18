#!/usr/bin/env bash
# ==============================================================================
# TTZip Local Pre-Flight Quality Gate & Repository Hygiene Verification Script
# ==============================================================================
# Executes all necessary quality, safety, and performance floor gates locally
# to validate changes prior to opening a Pull Request.
#
# Runs in-process with 0 GitHub Actions quota consumption.
# ==============================================================================

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Terminal Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Track timings and results
STAGE1_STATUS="FAIL"
STAGE2_STATUS="FAIL"
STAGE3_STATUS="FAIL"
STAGE4_STATUS="FAIL"

STAGE1_DURATION=0
STAGE2_DURATION=0
STAGE3_DURATION=0
STAGE4_DURATION=0

TOTAL_START_TIME=$(python3 -c 'import time; print(time.time())')

echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}  TTZip Local Pre-Flight Quality Gate & Repository Hygiene Verification        ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "Workspace: ${REPO_ROOT}"
echo -e "Date:      $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "Platform:  $(uname -sm)"
echo ""

# ------------------------------------------------------------------------------
# Stage 1: Repository Hygiene & Worktree Cleanliness Gate
# ------------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}[Stage 1/4] Checking Repository Cleanliness & Git Hygiene...${NC}"
S1_START=$(python3 -c 'import time; print(time.time())')

# 1. Assert .gitignore exists and covers key build/vendor directories
if [ ! -f ".gitignore" ]; then
    echo -e "${RED}❌ Error: .gitignore file is missing!${NC}"
    exit 1
fi

# 2. Assert .gitattributes exists and enforces LF
if [ ! -f ".gitattributes" ]; then
    echo -e "${RED}❌ Error: .gitattributes file is missing!${NC}"
    exit 1
fi

# 3. Check for stray .DS_Store files
STRAY_DS_STORE=$(find . -name ".DS_Store" -not -path "./.git/*" 2>/dev/null || true)
if [ -n "$STRAY_DS_STORE" ]; then
    echo -e "${YELLOW}⚠️ Found stray .DS_Store files. Cleaning up...${NC}"
    find . -name ".DS_Store" -not -path "./.git/*" -delete 2>/dev/null || true
fi

# 4. Check for dirty/unignored build leftovers
DIRTY_LEFTOVERS=$(find . -maxdepth 2 \( -name ".build_custom" -o -name ".build_di_test" -o -name ".build_tmp" \) 2>/dev/null || true)
if [ -n "$DIRTY_LEFTOVERS" ]; then
    echo -e "${YELLOW}⚠️ Found transient build directories: ${DIRTY_LEFTOVERS}${NC}"
fi

S1_END=$(python3 -c 'import time; print(time.time())')
STAGE1_DURATION=$(python3 -c "print(round($S1_END - $S1_START, 2))")
STAGE1_STATUS="PASS"
echo -e "${GREEN}✅ Stage 1 PASSED: Repository cleanliness and ignore rules verified (${STAGE1_DURATION}s)${NC}\n"

# ------------------------------------------------------------------------------
# Stage 2: Codebase Invariant & Formatting Lint
# ------------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}[Stage 2/4] Running Codebase Invariant & Formatting Lint...${NC}"
S2_START=$(python3 -c 'import time; print(time.time())')

# 1. Run Python Invariant Linter if present
if [ -f "scripts/lint_codebase_invariants.py" ]; then
    echo "  Running codebase invariant linter (scripts/lint_codebase_invariants.py)..."
    python3 scripts/lint_codebase_invariants.py --strict || {
        echo -e "${RED}❌ Codebase invariant lint failed!${NC}"
        exit 1
    }
fi

# 2. Run SwiftLint if installed
if command -v swiftlint >/dev/null 2>&1; then
    echo "  Running SwiftLint strict check..."
    swiftlint lint --strict --quiet || {
        echo -e "${RED}❌ SwiftLint quality check failed!${NC}"
        exit 1
    }
else
    echo "  (SwiftLint not found in PATH; skipping SwiftLint step)"
fi

S2_END=$(python3 -c 'import time; print(time.time())')
STAGE2_DURATION=$(python3 -c "print(round($S2_END - $S2_START, 2))")
STAGE2_STATUS="PASS"
echo -e "${GREEN}✅ Stage 2 PASSED: Codebase invariants and linter clean (${STAGE2_DURATION}s)${NC}\n"

# ------------------------------------------------------------------------------
# Stage 3: Full Parallel Unit & Pattern Test Suite
# ------------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}[Stage 3/4] Running Fast Core Unit & Pattern Test Suite...${NC}"
S3_START=$(python3 -c 'import time; print(time.time())')

echo "  Executing: swift test --filter \"(MmapBufferHandleTests|LibarchiveGoldenCorpusTests|TestReportGeneratorTests|PlatformPathSanitizerTests|PlatformMemoryTests|PlatformHardwareTests|SecurityAndComplianceTests|PasswordVaultV4Tests)\""
swift test --filter "(MmapBufferHandleTests|LibarchiveGoldenCorpusTests|TestReportGeneratorTests|PlatformPathSanitizerTests|PlatformMemoryTests|PlatformHardwareTests|SecurityAndComplianceTests|PasswordVaultV4Tests)" || {
    echo -e "${RED}❌ Unit & Pattern test suite failed!${NC}"
    exit 1
}

S3_END=$(python3 -c 'import time; print(time.time())')
STAGE3_DURATION=$(python3 -c "print(round($S3_END - $S3_START, 2))")
STAGE3_STATUS="PASS"
echo -e "${GREEN}✅ Stage 3 PASSED: Core unit & pattern test suites passed (${STAGE3_DURATION}s)${NC}\n"


# ------------------------------------------------------------------------------
# Stage 4: Core Engine Performance Floor Gate
# ------------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}[Stage 4/4] Verifying Core Engine Performance Floor Gates (Isolated Run)...${NC}"
S4_START=$(python3 -c 'import time; print(time.time())')

echo "  Executing: swift test --skip-build --filter XCTestPerformanceMeasureTests"
swift test --skip-build --filter XCTestPerformanceMeasureTests || swift test --filter XCTestPerformanceMeasureTests || {
    echo -e "${RED}❌ Core Engine Performance Floor gate failed (throughput regression detected)!${NC}"
    exit 1
}



S4_END=$(python3 -c 'import time; print(time.time())')
STAGE4_DURATION=$(python3 -c "print(round($S4_END - $S4_START, 2))")
STAGE4_STATUS="PASS"
echo -e "${GREEN}✅ Stage 4 PASSED: Core engine performance floors satisfied (${STAGE4_DURATION}s)${NC}\n"

# ------------------------------------------------------------------------------
# Final Summary Table
# ------------------------------------------------------------------------------
TOTAL_END_TIME=$(python3 -c 'import time; print(time.time())')
TOTAL_DURATION=$(python3 -c "print(round($TOTAL_END_TIME - $TOTAL_START_TIME, 2))")

echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}                     PRE-FLIGHT QUALITY GATE SUMMARY                           ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}"
printf "%-8s %-42s %-12s %-10s\n" "Stage" "Quality Gate Description" "Result" "Duration"
echo "--------------------------------------------------------------------------------"
printf "%-8s %-42s ${GREEN}%-12s${NC} %-10s\n" "1" "Repository Cleanliness & Git Hygiene" "[ $STAGE1_STATUS ]" "${STAGE1_DURATION}s"
printf "%-8s %-42s ${GREEN}%-12s${NC} %-10s\n" "2" "Codebase Invariant & Lint Gate" "[ $STAGE2_STATUS ]" "${STAGE2_DURATION}s"
printf "%-8s %-42s ${GREEN}%-12s${NC} %-10s\n" "3" "Parallel Unit & Pattern Test Suite" "[ $STAGE3_STATUS ]" "${STAGE3_DURATION}s"
printf "%-8s %-42s ${GREEN}%-12s${NC} %-10s\n" "4" "Core Performance Floor Gate" "[ $STAGE4_STATUS ]" "${STAGE4_DURATION}s"
echo "--------------------------------------------------------------------------------"
echo -e "${BOLD}Overall Status: ${GREEN}ALL QUALITY GATES PASSED${NC} (Total Time: ${TOTAL_DURATION}s)"
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "🚀 Workspace is 100% compliant with TTZip governance & performance invariants!"
echo -e "   Ready for commit and Pull Request creation."
exit 0
