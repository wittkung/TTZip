#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
# TTZip Local CI Verification Pipeline (Zero Cloud Quota, 100% Local)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "================================================================"
echo "         TTZip Local CI Verification Suite (Local Only)         "
echo "================================================================"

# 1. CMake Native C Engine, Test Runner & CLI Build
echo "==> [1/5] Building libttzip.a, ttzip-cli & ttzip_c_test_runner via CMake (Release)..."
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON > /dev/null
cmake --build build --config Release -j8 > /dev/null
echo "    ✅ CMake build passed: libttzip.a, ttzip-cli & ttzip_c_test_runner ready."

# 2. Native C11 Microkernel Test Suites (CTest)
echo "==> [2/5] Running Native C11 Microkernel Test Suites (< 50ms)..."
ctest --test-dir build --output-on-failure
echo "    ✅ All C11 microkernel test suites passed 100% green."

# 3. Pure C CLI Functional & Benchmark Verification
echo "==> [3/5] Testing Standalone ttzip-cli & C SDK Quickstart..."
./build/ttzip-cli --version
./build/ttzip-cli --benchmark
./build/ttzip-quickstart
echo "    ✅ Standalone C CLI & C SDK quickstart verification passed."

# 4. Zero-GCD Audit in TTZipCore
echo "==> [4/5] Auditing Zero Apple GCD Calls in TTZipCore..."
GCD_MATCHES=$(grep -rn "DispatchQueue\|DispatchSemaphore\|DispatchGroup" Sources/TTZipCore/ --include="*.swift" | grep -v "FileWatcherEngine.swift" | grep -v "ConcurrencyBridge.swift:.*///" || true)
if [ -n "${GCD_MATCHES}" ]; then
    echo "    ❌ ERROR: Found residual GCD calls in TTZipCore:"
    echo "${GCD_MATCHES}"
    exit 1
fi
echo "    ✅ Zero-GCD audit passed: 0 Apple GCD calls in TTZipCore."

# 5. Swift Matrix & Concurrency Test Suites
echo "==> [5/5] Running Swift Core & Concurrency Test Matrix..."
swift test --filter "ConcurrencyBridgeTests|ObserverPatternTests|DifferentialOracleTests|PasswordVaultV4Tests"
echo "    ✅ Swift test suites passed 100% green."

# 5. Final Status
echo "================================================================"
echo "       🎉 ALL LOCAL CI CHECKS PASSED SUCCESSFULLY (0 Quota)     "
echo "================================================================"
