#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
# TTZip Local CI Verification Pipeline (Zero Cloud Quota, 100% Local)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "================================================================"
echo "         TTZip Local CI Verification Suite (Local Only)         "
echo "================================================================"

# 1. CMake Native C Engine & CLI Build
echo "==> [1/4] Building libttzip.a and ttzip-cli via CMake (Release)..."
cmake -B build -DCMAKE_BUILD_TYPE=Release -Wno-dev > /dev/null
cmake --build build --config Release -j8 > /dev/null
echo "    ✅ CMake build passed: build/libttzip.a & build/ttzip-cli generated successfully."

# 2. Pure C CLI Functional & Benchmark Verification
echo "==> [2/4] Testing Standalone ttzip-cli & C SDK Quickstart..."
./build/ttzip-cli --version
./build/ttzip-cli --benchmark
./build/ttzip-quickstart
echo "    ✅ Standalone C CLI & C SDK quickstart verification passed."

# 3. Zero-GCD Audit in TTZipCore
echo "==> [3/4] Auditing Zero Apple GCD Calls in TTZipCore..."
GCD_MATCHES=$(grep -rn "DispatchQueue\|DispatchSemaphore\|DispatchGroup" Sources/TTZipCore/ --include="*.swift" | grep -v "FileWatcherEngine.swift" | grep -v "ConcurrencyBridge.swift:.*///" || true)
if [ -n "${GCD_MATCHES}" ]; then
    echo "    ❌ ERROR: Found residual GCD calls in TTZipCore:"
    echo "${GCD_MATCHES}"
    exit 1
fi
echo "    ✅ Zero-GCD audit passed: 0 Apple GCD calls in TTZipCore."

# 4. Swift Matrix & Concurrency Test Suites
echo "==> [4/4] Running Swift Core & Concurrency Test Matrix..."
swift test --filter "ConcurrencyBridgeTests|AllFormatsAndAdvancedParametersMatrixTests|AllFormatDiagnosticSuiteTests|Blosc2PluginRegistryTests|EntropyAdaptiveExtremeRoutingTests|ObserverPatternTests|DiskSortOptionTests"
echo "    ✅ Swift test suites passed 100% green."

# 5. Final Status
echo "================================================================"
echo "       🎉 ALL LOCAL CI CHECKS PASSED SUCCESSFULLY (0 Quota)     "
echo "================================================================"
