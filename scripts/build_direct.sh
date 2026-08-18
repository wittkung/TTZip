#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
set -e

echo "=========================================="
echo "📦 Building TTZip Direct Independent Version"
echo "=========================================="

cd "$(dirname "$0")/.."

echo "--> Compiling release executable..."
swift build -c release

echo "--> Direct build complete! Executable located at: .build/release/TTZipApp"
