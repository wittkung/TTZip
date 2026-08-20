#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: Industrial Git Worktree A/B Benchmark & Statistical Delta Runner.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BASELINE_REF="${1:-HEAD~1}"
CANDIDATE_REF="${2:-HEAD}"
RUNS=5
THRESHOLD=0.03
REPORT_DIR="${REPO_ROOT}/reports"

# Parse optional arguments
shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs|-r)
            RUNS="$2"
            shift 2
            ;;
        --threshold|-t)
            THRESHOLD="$2"
            shift 2
            ;;
        --report-dir)
            REPORT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

SESSION_ID="ab_$(date +%s)_$$"
WORKTREE_DIR="${REPO_ROOT}/.worktrees/${SESSION_ID}"
TMP_LOG_DIR="${WORKTREE_DIR}/logs"
WORKTREE_BASE="${WORKTREE_DIR}/base"
WORKTREE_CAND="${WORKTREE_DIR}/cand"

CLEANUP_DONE=0
cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM HUP
    if [ "${CLEANUP_DONE}" -eq 1 ]; then
        exit "${exit_code}"
    fi
    CLEANUP_DONE=1
    echo -e "\n\033[1;33m[TEARDOWN] Cleaning up temporary benchmark worktrees...\033[0m"
    if [[ -d "${WORKTREE_BASE}" ]]; then
        git worktree remove --force "${WORKTREE_BASE}" 2>/dev/null || true
    fi
    if [[ -d "${WORKTREE_CAND}" ]]; then
        git worktree remove --force "${WORKTREE_CAND}" 2>/dev/null || true
    fi
    git worktree prune 2>/dev/null || true
    if [[ -d "${WORKTREE_DIR}" ]]; then
        rm -rf "${WORKTREE_DIR}" 2>/dev/null || true
    fi
    if [[ -d "${REPO_ROOT}/build_ab_wip" ]]; then
        rm -rf "${REPO_ROOT}/build_ab_wip" 2>/dev/null || true
    fi
    exit "${exit_code}"
}
trap cleanup EXIT INT TERM HUP

mkdir -p "${TMP_LOG_DIR}" "${REPORT_DIR}"

echo -e "\n\033[1;36m======================================================================\033[0m"
echo -e "\033[1;36m  TTZip Industrial Git Worktree A/B Performance Benchmark Engine    \033[0m"
echo -e "\033[1;36m======================================================================\033[0m"
echo "Session ID:    ${SESSION_ID}"
echo "Baseline Ref:  ${BASELINE_REF}"
echo "Candidate Ref: ${CANDIDATE_REF}"
echo "Sample Runs:   ${RUNS} interleaved iterations"
echo "Platform:      $(uname -s) $(uname -m)"

# 1. Resolve Baseline Commit SHA
BASELINE_SHA="$(git rev-parse "${BASELINE_REF}" 2>/dev/null || echo "unknown")"
echo -e "\n\033[1;34m[1/4] Preparing Baseline Worktree (${BASELINE_REF} @ ${BASELINE_SHA:0:8})...\033[0m"
git worktree add --detach "${WORKTREE_BASE}" "${BASELINE_REF}" >/dev/null

# Link Vendor static libraries into baseline worktree if present in main repository
if [[ -d "${REPO_ROOT}/Vendor/lib" && ! -d "${WORKTREE_BASE}/Vendor/lib" ]]; then
    mkdir -p "${WORKTREE_BASE}/Vendor"
    ln -sf "${REPO_ROOT}/Vendor/lib" "${WORKTREE_BASE}/Vendor/lib"
fi
if [[ -f "${REPO_ROOT}/Vendor/libTTZipVendor.a" && ! -f "${WORKTREE_BASE}/Vendor/libTTZipVendor.a" ]]; then
    mkdir -p "${WORKTREE_BASE}/Vendor"
    ln -sf "${REPO_ROOT}/Vendor/libTTZipVendor.a" "${WORKTREE_BASE}/Vendor/libTTZipVendor.a"
fi

cmake -S "${WORKTREE_BASE}" -B "${WORKTREE_BASE}/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-O3 -DNDEBUG" >/dev/null
cmake --build "${WORKTREE_BASE}/build" --target ttzip_benchmark_runner -j >/dev/null
BIN_BASE="${WORKTREE_BASE}/build/ttzip_benchmark_runner"

# 2. Resolve Candidate Commit SHA and Binary
if [[ "${CANDIDATE_REF}" == "WIP" || "${CANDIDATE_REF}" == "." || "${CANDIDATE_REF}" == "DIRTY" ]]; then
    CANDIDATE_SHA="dirty_working_tree"
    echo -e "\033[1;34m[2/4] Building Candidate from Local Workspace (WIP)...\033[0m"
    cmake -S "${REPO_ROOT}" -B "${REPO_ROOT}/build_ab_wip" -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-O3 -DNDEBUG" >/dev/null
    cmake --build "${REPO_ROOT}/build_ab_wip" --target ttzip_benchmark_runner -j >/dev/null
    BIN_CAND="${REPO_ROOT}/build_ab_wip/ttzip_benchmark_runner"
else
    CANDIDATE_SHA="$(git rev-parse "${CANDIDATE_REF}" 2>/dev/null || echo "unknown")"
    echo -e "\033[1;34m[2/4] Preparing Candidate Worktree (${CANDIDATE_REF} @ ${CANDIDATE_SHA:0:8})...\033[0m"
    git worktree add --detach "${WORKTREE_CAND}" "${CANDIDATE_REF}" >/dev/null

    if [[ -d "${REPO_ROOT}/Vendor/lib" && ! -d "${WORKTREE_CAND}/Vendor/lib" ]]; then
        mkdir -p "${WORKTREE_CAND}/Vendor"
        ln -sf "${REPO_ROOT}/Vendor/lib" "${WORKTREE_CAND}/Vendor/lib"
    fi
    if [[ -f "${REPO_ROOT}/Vendor/libTTZipVendor.a" && ! -f "${WORKTREE_CAND}/Vendor/libTTZipVendor.a" ]]; then
        mkdir -p "${WORKTREE_CAND}/Vendor"
        ln -sf "${REPO_ROOT}/Vendor/libTTZipVendor.a" "${WORKTREE_CAND}/Vendor/libTTZipVendor.a"
    fi

    cmake -S "${WORKTREE_CAND}" -B "${WORKTREE_CAND}/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-O3 -DNDEBUG" >/dev/null
    cmake --build "${WORKTREE_CAND}/build" --target ttzip_benchmark_runner -j >/dev/null
    BIN_CAND="${WORKTREE_CAND}/build/ttzip_benchmark_runner"
fi

# 3. Warm-up Run (Discarded)
echo -e "\033[1;34m[3/4] Warming up CPU caches and virtual memory paging...\033[0m"
"${BIN_BASE}" --all >/dev/null 2>&1 || true
"${BIN_CAND}" --all >/dev/null 2>&1 || true

# 4. Interleaved Multi-Round Sampling
echo -e "\033[1;34m[4/4] Executing ${RUNS} Cross-Over Interleaved Sampling Rounds...\033[0m"
BASE_LOGS=()
CAND_LOGS=()

for ((i=1; i<=RUNS; i++)); do
    echo -n "  Round ${i}/${RUNS}: "
    LOG_B="${TMP_LOG_DIR}/base_run_${i}.log"
    LOG_C="${TMP_LOG_DIR}/cand_run_${i}.log"
    
    if (( i % 2 == 1 )); then
        # Odd: Base -> Cand
        echo -n "[Base ➔ Cand] ... "
        "${BIN_BASE}" --all > "${LOG_B}"
        "${BIN_CAND}" --all > "${LOG_C}"
    else
        # Even: Cand -> Base (Anti-Thermal Throttling Cross-Over)
        echo -n "[Cand ➔ Base] ... "
        "${BIN_CAND}" --all > "${LOG_C}"
        "${BIN_BASE}" --all > "${LOG_B}"
    fi
    BASE_LOGS+=("${LOG_B}")
    CAND_LOGS+=("${LOG_C}")
    echo "Done."
    sleep 0.1
done

# 5. Statistical Processing & Report Generation
REPORT_TS="$(date +%Y%m%d_%H%M%S)"
JSON_REPORT="${REPORT_DIR}/ab_bench_${REPORT_TS}.json"
MD_REPORT="${REPORT_DIR}/ab_bench_${REPORT_TS}.md"

META_JSON=$(cat <<EOF
{
  "session_id": "${SESSION_ID}",
  "baseline_ref": "${BASELINE_REF}",
  "baseline_commit": "${BASELINE_SHA}",
  "candidate_ref": "${CANDIDATE_REF}",
  "candidate_commit": "${CANDIDATE_SHA}",
  "sample_runs": ${RUNS},
  "platform": "$(uname -s) $(uname -m) macOS $(sw_vers -productVersion 2>/dev/null || echo "unknown")"
}
EOF
)

python3 "${SCRIPT_DIR}/statistical_delta.py" \
    --base-logs "${BASE_LOGS[@]}" \
    --cand-logs "${CAND_LOGS[@]}" \
    --meta "${META_JSON}" \
    --json-out "${JSON_REPORT}" \
    --md-out "${MD_REPORT}" \
    --threshold "${THRESHOLD}"

echo -e "✅ Markdown Report: \033[1;32m${MD_REPORT}\033[0m"
echo -e "✅ JSON Telemetry:   \033[1;32m${JSON_REPORT}\033[0m"
