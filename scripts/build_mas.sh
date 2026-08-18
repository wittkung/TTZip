#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
set -e

echo "=========================================="
echo "🏬 Building TTZip Mac App Store (MAS) Sandboxed Version"
echo "=========================================="

cd "$(dirname "$0")/.."

echo "--> Compiling release executable with -DMAS_BUILD..."
swift build -c release -Xswiftc -DMAS_BUILD

echo "--> MAS Sandboxed build complete! Executable located at: .build/release/TTZipApp"
