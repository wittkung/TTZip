#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${WORKSPACE_ROOT}"

echo "=========================================="
echo "🧪 Running TTZip Full Test & Verification Suite"
echo "=========================================="

"${SCRIPT_DIR}/run_local_ci_gate.sh" "$@"

echo "=========================================="
echo "✅ ALL TEST SUITES & GATES PASSED CLEANLY!"
echo "=========================================="
