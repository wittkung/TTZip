#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# run_delta_audit.sh: Automated Binary Footprint, Symbol Audit & Multi-Level Compression Delta Runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${WORKSPACE_ROOT}"

echo "======================================================================"
echo "⚡️ TTZip Automated Delta Audit (Binary Size & Compression Ratio)"
echo "======================================================================"

swift run ttzip-bench delta "$@"
