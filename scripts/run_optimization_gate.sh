#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# run_optimization_gate.sh: 5-Stage Zero-Regression Optimization & Performance Gate Runner

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
            echo "Usage: ./scripts/run_optimization_gate.sh [options]"
            echo ""
            echo "Options:"
            echo "  --bail               Stop immediately on first failed stage"
            echo "  --stage <name>       Execute only the specified stage"
            echo "  --json <path>        Export structured JSON telemetry report"
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
echo -e "${C_CYAN}${C_BOLD}  TTZip 5-Gate Zero-Regression Optimization & Performance Pipeline    ${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}======================================================================${C_RESET}"
echo -e "Platform: $(uname -m) macOS $(sw_vers -productVersion 2>/dev/null || echo "Sonoma")"
echo -e "Date:     $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Build CMake binaries if not already built
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON > /dev/null
cmake --build build --config Release -j8 > /dev/null

# Stage Definitions
declare -a STAGE_NAMES=(
    "Gate 1: Native C11 Microkernel & Safety Unit Tests"
    "Gate 2: Microarchitectural PMU & 10-Codec Benchmark Matrix"
    "Gate 3: Multi-File Container Packaging & Extraction Benchmark"
    "Gate 4: Standalone C CLI & Quickstart Verification"
    "Gate 5: Process Peak RSS Memory & Zero-Leak Audit"
)

declare -a STAGE_KEYS=(
    "gate1-unit"
    "gate2-micro-pmu"
    "gate3-formats"
    "gate4-cli"
    "gate5-memory-rss"
)

declare -a STAGE_COMMANDS=(
    "./build/ttzip_c_test_runner all"
    "./build/ttzip_benchmark_runner --codecs --checksums --pareto"
    "./build/ttzip_benchmark_runner --formats --stress"
    "./build/ttzip-cli --version && ./build/ttzip-quickstart"
    "./build/ttzip-cli --benchmark"
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
        FAILED_STAGES=$((FAILED_STAGES + 1))
        echo -e "${C_RED}--- Error Log Output ---${C_RESET}"
        cat "${TMP_LOG}" | tail -n 25
        echo -e "${C_RED}------------------------${C_RESET}"
        STAGE_DIAGNOSTICS+=("Execution failed with exit code ${CMD_EXIT}")
        
        if [ "${BAIL_ON_FAILURE}" = true ]; then
            rm -f "${TMP_LOG}"
            echo -e "${C_RED}${C_BOLD}❌ Pipeline stopped early due to --bail flag.${C_RESET}"
            exit 1
        fi
    fi
    rm -f "${TMP_LOG}"
    echo ""
done

GLOBAL_END_TIME=$(python3 -c "import time; print(time.time())")
GLOBAL_DURATION=$(python3 -c "print(round(${GLOBAL_END_TIME} - ${GLOBAL_START_TIME}, 3))")

echo -e "${C_CYAN}======================================================================${C_RESET}"
echo -e "${C_BOLD}Pipeline Execution Summary:${C_RESET}"
echo -e "  Total Stages:    ${TOTAL_STAGES}"
echo -e "  Passed Stages:   ${C_GREEN}${PASSED_STAGES}${C_RESET}"
echo -e "  Failed Stages:   ${C_RED}${FAILED_STAGES}${C_RESET}"
echo -e "  Total Wall Time: ${GLOBAL_DURATION}s"
echo -e "${C_CYAN}======================================================================${C_RESET}"

# Export JSON if requested
if [[ -n "${JSON_REPORT_PATH}" ]]; then
    python3 -c "
import json, os, datetime

names = [\"${STAGE_NAMES[0]}\", \"${STAGE_NAMES[1]}\", \"${STAGE_NAMES[2]}\", \"${STAGE_NAMES[3]}\", \"${STAGE_NAMES[4]}\"]
cmds = [\"${STAGE_COMMANDS[0]}\", \"${STAGE_COMMANDS[1]}\", \"${STAGE_COMMANDS[2]}\", \"${STAGE_COMMANDS[3]}\", \"${STAGE_COMMANDS[4]}\"]
statuses = \"${STAGE_STATUSES[*]}\".split()
durations = [float(x) for x in \"${STAGE_DURATIONS[*]}\".split()]

stages = []
for idx in range(len(names)):
    stages.append({
        'stage_index': idx + 1,
        'name': names[idx],
        'command': cmds[idx],
        'status': statuses[idx] if idx < len(statuses) else 'skip',
        'duration_sec': durations[idx] if idx < len(durations) else 0.0,
        'diagnostic_message': None if (idx < len(statuses) and statuses[idx] == 'pass') else 'Failed'
    })

report = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'platform': 'arm64-apple-darwin',
    'total_gates': len(names),
    'passed_gates': ${PASSED_STAGES},
    'failed_gates': ${FAILED_STAGES},
    'total_duration_sec': ${GLOBAL_DURATION},
    'overall_verdict': 'PASS' if ${FAILED_STAGES} == 0 else 'FAIL',
    'stages': stages,
    'codec_matrix': [],
    'format_matrix': []
}

out_path = '${JSON_REPORT_PATH}'
os.makedirs(os.path.dirname(out_path) or '.', exist_ok=True)
with open(out_path, 'w') as f:
    json.dump(report, f, indent=2)
print('✅ Exported structured telemetry JSON report to ' + out_path)
"
fi

if [ ${FAILED_STAGES} -gt 0 ]; then
    echo -e "${C_RED}${C_BOLD}❌ Zero-Regression Gate Failed! Please fix regressions before committing.${C_RESET}"
    exit 1
else
    echo -e "${C_GREEN}${C_BOLD}🎉 ALL 5 ZERO-REGRESSION GATES PASSED 100% GREEN (Zero Regressions)!${C_RESET}"
    exit 0
fi
