#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# run_local_ci_gate.sh: 6-Stage Automated Local Regression & Quality Gate Runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${WORKSPACE_ROOT}"

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"

# Options
BAIL_ON_FAILURE=false
TARGET_STAGE=""
JSON_REPORT_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bail)
            BAIL_ON_FAILURE=true
            shift
            ;;
        --stage)
            TARGET_STAGE="$2"
            shift 2
            ;;
        --json)
            JSON_REPORT_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./scripts/run_local_ci_gate.sh [options]"
            echo ""
            echo "Options:"
            echo "  --bail               Stop immediately on first failed stage"
            echo "  --stage <name>       Execute only the specified stage"
            echo "  --json <path>        Export structured JSON report"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 64
            ;;
    esac
done

echo -e "${C_CYAN}${C_BOLD}======================================================================${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}      TTZip Local CI/CD Automated Regression & Performance Gate       ${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}======================================================================${C_RESET}"
echo -e "Platform: $(uname -m) macOS $(sw_vers -productVersion 2>/dev/null || echo 'Sonoma')"
echo -e "Date:     $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Stage Definitions
declare -a STAGE_NAMES=(
    "Unit & CLI Streaming Suite"
    "Standards Compliance Suite"
    "Differential System Oracle"
    "Malformed Stream Fuzzing"
    "Libarchive Golden Corpus"
    "Deflate-Bench 50-Point Matrix Gate"
)

declare -a STAGE_KEYS=(
    "unit-streaming"
    "standards"
    "differential"
    "fuzzing"
    "golden-corpus"
    "performance"
)

declare -a STAGE_COMMANDS=(
    "swift test --filter PipeStreamingTests,ShellCompletionTests,ManPageGenerationTests,ArchiveFormatStandardTests,CLIPackagingTests,ArchiveInspectorViewTests,InteractiveTUITests,MediaPreviewAuditTests,QuickLookPreviewTests,GUILocalizationTests,AppStorePackageAuditTests"
    "swift test --filter ArchiveStandardsComplianceTests"
    "swift test --filter DifferentialOracleTests"
    "swift test --filter ArchiveMutationFuzzTests"
    "swift test --filter LibarchiveGoldenCorpusTests"
    "swift run ttzip-bench gate"
)

TOTAL_STAGES=${#STAGE_NAMES[@]}
PASSED_STAGES=0
FAILED_STAGES=0
GLOBAL_START_TIME=$(python3 -c "import time; print(time.time())")

declare -a STAGE_STATUSES=()
declare -a STAGE_DURATIONS=()
declare -a STAGE_DIAGNOSTICS=()

for i in "${!STAGE_NAMES[@]}"; do
    STAGE_INDEX=$((i + 1))
    STAGE_NAME="${STAGE_NAMES[$i]}"
    STAGE_KEY="${STAGE_KEYS[$i]}"
    STAGE_CMD="${STAGE_COMMANDS[$i]}"
    
    if [[ -n "${TARGET_STAGE}" && "${TARGET_STAGE}" != "${STAGE_KEY}" && "${TARGET_STAGE}" != "${STAGE_INDEX}" ]]; then
        STAGE_STATUSES+=("skip")
        STAGE_DURATIONS+=(0.0)
        STAGE_DIAGNOSTICS+=("Filtered out by --stage")
        continue
    fi
    
    echo -e "${C_BOLD}[Stage ${STAGE_INDEX}/${TOTAL_STAGES}] ${C_BLUE}${STAGE_NAME}${C_RESET}"
    echo -e "  Command: ${C_YELLOW}${STAGE_CMD}${C_RESET}"
    
    STAGE_START=$(python3 -c "import time; print(time.time())")
    set +e
    TMP_LOG=$(mktemp)
    eval "${STAGE_CMD}" > "${TMP_LOG}" 2>&1
    CMD_EXIT=$?
    set -e
    STAGE_END=$(python3 -c "import time; print(time.time())")
    STAGE_DUR=$(python3 -c "print(round(${STAGE_END} - ${STAGE_START}, 3))")
    STAGE_DURATIONS+=("${STAGE_DUR}")
    
    if [ ${CMD_EXIT} -eq 0 ]; then
        echo -e "  Result:  ${C_GREEN}${C_BOLD}[PASS]${C_RESET} (${STAGE_DUR}s)"
        STAGE_STATUSES+=("pass")
        STAGE_DIAGNOSTICS+=("")
        PASSED_STAGES=$((PASSED_STAGES + 1))
    else
        echo -e "  Result:  ${C_RED}${C_BOLD}[FAIL]${C_RESET} (${STAGE_DUR}s, exit code ${CMD_EXIT})"
        STAGE_STATUSES+=("fail")
        LAST_LINES=$(tail -n 10 "${TMP_LOG}" | tr '\n' ' ')
        STAGE_DIAGNOSTICS+=("${LAST_LINES}")
        FAILED_STAGES=$((FAILED_STAGES + 1))
        
        echo -e "${C_RED}--- Error Diagnostic Output ---${C_RESET}"
        cat "${TMP_LOG}" | tail -n 25
        echo -e "${C_RED}-------------------------------${C_RESET}"
        
        if [ "${BAIL_ON_FAILURE}" = true ]; then
            rm -f "${TMP_LOG}"
            break
        fi
    fi
    rm -f "${TMP_LOG}"
    echo ""
done

GLOBAL_END_TIME=$(python3 -c "import time; print(time.time())")
GLOBAL_DURATION=$(python3 -c "print(round(${GLOBAL_END_TIME} - ${GLOBAL_START_TIME}, 3))")

echo -e "${C_CYAN}${C_BOLD}======================================================================${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}                          Summary Table                               ${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}======================================================================${C_RESET}"
printf "%-6s | %-32s | %-8s | %-10s\n" "Stage" "Name" "Status" "Duration"
echo "----------------------------------------------------------------------"

for i in "${!STAGE_STATUSES[@]}"; do
    S_IDX=$((i + 1))
    S_NAME="${STAGE_NAMES[$i]}"
    S_STAT="${STAGE_STATUSES[$i]}"
    S_DUR="${STAGE_DURATIONS[$i]}s"
    
    if [ "${S_STAT}" = "pass" ]; then
        STATUS_DISPLAY="${C_GREEN}PASS${C_RESET}"
    elif [ "${S_STAT}" = "fail" ]; then
        STATUS_DISPLAY="${C_RED}FAIL${C_RESET}"
    else
        STATUS_DISPLAY="${C_YELLOW}SKIP${C_RESET}"
    fi
    
    printf "%-6s | %-32s | %-17b | %-10s\n" "${S_IDX}" "${S_NAME}" "${STATUS_DISPLAY}" "${S_DUR}"
done

echo "----------------------------------------------------------------------"
echo -e "Total: ${PASSED_STAGES} Passed, ${FAILED_STAGES} Failed (${GLOBAL_DURATION}s total)"
echo ""

# Export JSON if requested
if [[ -n "${JSON_REPORT_PATH}" ]]; then
    python3 -c "
import json
import os
stages = []
names = [\"Unit & CLI Streaming Suite\", \"Standards Compliance Suite\", \"Differential System Oracle\", \"Malformed Stream Fuzzing\", \"Libarchive Golden Corpus\", \"Hard Performance Floors\"]
cmds = [
    \"swift test --filter PipeStreamingTests,ShellCompletionTests,ManPageGenerationTests,ArchiveFormatStandardTests,CLIPackagingTests,ArchiveInspectorViewTests\",
    \"swift test --filter ArchiveStandardsComplianceTests\",
    \"swift test --filter DifferentialOracleTests\",
    \"swift test --filter ArchiveMutationFuzzTests\",
    \"swift test --filter LibarchiveGoldenCorpusTests\",
    \"swift test --filter XCTestPerformanceMeasureTests\"
]
status_list = '${STAGE_STATUSES[*]}'.split()
durations = [float(x) for x in '${STAGE_DURATIONS[*]}'.split()]
for idx, stat in enumerate(status_list):
    stages.append({
        'stageIndex': idx + 1,
        'name': names[idx] if idx < len(names) else f'Stage {idx+1}',
        'command': cmds[idx] if idx < len(cmds) else '',
        'status': stat,
        'durationSeconds': durations[idx] if idx < len(durations) else 0.0,
        'diagnosticMessage': 'Stage execution failed' if stat == 'fail' else None
    })

report = {
    'totalStages': len(names),
    'passedStages': ${PASSED_STAGES},
    'failedStages': ${FAILED_STAGES},
    'totalDurationSeconds': ${GLOBAL_DURATION},
    'isSuccess': (${FAILED_STAGES} == 0),
    'stages': stages
}

out_path = '${JSON_REPORT_PATH}'
os.makedirs(os.path.dirname(out_path) or '.', exist_ok=True)
with open(out_path, 'w') as f:
    json.dump(report, f, indent=2)
print('Exported JSON gate report to ' + out_path)
"
fi

if [ ${FAILED_STAGES} -gt 0 ]; then
    echo -e "${C_RED}${C_BOLD}❌ Local CI/CD Gate Failed! Fix issues before pushing.${C_RESET}"
    exit 1
else
    echo -e "${C_GREEN}${C_BOLD}✅ Local CI/CD Gate Passed! 100% compliant and ready.${C_RESET}"
    exit 0
fi
