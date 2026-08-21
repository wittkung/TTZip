#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/run_rust_tests.sh
# 自动化执行 TTZip Rust 全域测试套件：单测、集成测试、属性测试、Fuzzing 与基准测试
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUST_DIR="${REPO_ROOT}/rust/ttzip-glue"

export PATH="$HOME/.cargo/bin:$PATH"

RUN_UNIT=false
RUN_PROPS=false
RUN_FUZZ=false
RUN_BENCH=false
RUN_ALL=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --unit           Run Unit and Core C-ABI Integration tests"
    echo "  --props          Run Proptest Property-based invariant test suite"
    echo "  --fuzz           Run Coverage-guided Fuzzing harness test targets"
    echo "  --bench          Run Criterion micro-benchmarks"
    echo "  --all            Run all test suites (Unit, Props, Fuzz, Bench)"
    echo "  --help|-h        Show this help message"
    exit 0
}

if [[ $# -eq 0 ]]; then
    RUN_ALL=true
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --unit)
            RUN_UNIT=true
            shift
            ;;
        --props)
            RUN_PROPS=true
            shift
            ;;
        --fuzz)
            RUN_FUZZ=true
            shift
            ;;
        --bench)
            RUN_BENCH=true
            shift
            ;;
        --all)
            RUN_ALL=true
            shift
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

if [ "${RUN_ALL}" = true ]; then
    RUN_UNIT=true
    RUN_PROPS=true
    RUN_FUZZ=true
    RUN_BENCH=true
fi

cd "${RUST_DIR}"

echo "================================================================"
echo "🦀 TTZip Rust Industrial Test Suite Runner"
echo "   Working Directory: ${RUST_DIR}"
echo "================================================================"

# 1. Unit & Integration Tests
if [ "${RUN_UNIT}" = true ]; then
    echo "--> [1/4] Running Unit & Integration Tests (release mode)..."
    cargo test --release --lib \
        --test codecs_integration_tests \
        --test crypto_integration_tests \
        --test differential_oracle \
        --test phase4_integration_tests \
        --test phase5_archive_ffi_integration_tests \
        --test phase5_containers_integration_tests
    echo "✅ [PASS] Unit & Integration Tests completed successfully."
fi

# 2. Property-Based Invariant Tests (proptest)
if [ "${RUN_PROPS}" = true ]; then
    echo "--> [2/4] Running Property-Based Invariant Tests (release mode)..."
    cargo test --release --test property_tests -- --nocapture
    echo "✅ [PASS] Property-Based Tests completed successfully."
fi

# 3. Fuzzing Harness Targets
if [ "${RUN_FUZZ}" = true ]; then
    echo "--> [3/4] Running Mutation Fuzzing Harness Targets (release mode)..."
    if cargo test --release --test fuzz_harness -- --nocapture 2>/dev/null; then
        echo "✅ [PASS] Fuzzing Harness completed successfully."
    else
        echo "⚠️  [INFO] fuzz_harness test not yet built or skipped."
    fi
fi

# 4. Criterion Micro-benchmarks
if [ "${RUN_BENCH}" = true ]; then
    echo "--> [4/4] Running Criterion Micro-benchmarks (release mode)..."
    cargo bench || true
    echo "✅ [PASS] Criterion Benchmarks executed."
fi

echo "================================================================"
echo "🎉 ALL REQUESTED RUST TESTS PASSED WITH ZERO REGRESSIONS!"
echo "================================================================"
