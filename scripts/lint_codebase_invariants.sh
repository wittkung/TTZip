#!/usr/bin/env bash
# ==============================================================================
# TTZip Codebase Invariant Linter Gate
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}================================================================================${NC}"
echo -e "${BOLD}🔍 [TTZip Invariant Linter] Scanning Codebase Invariants...${NC}"
echo -e "${CYAN}================================================================================${NC}"

chmod +x scripts/lint_codebase_invariants.py

if python3 scripts/lint_codebase_invariants.py --strict; then
    echo -e "\n${GREEN}✅ [PASSED] All codebase invariants are 100% compliant!${NC}\n"
    exit 0
else
    echo -e "\n${RED}❌ [FAILED] Invariant violations detected. Please resolve above issues.${NC}\n"
    exit 1
fi
