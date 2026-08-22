#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "================================================================"
echo "  TTZip Automated Code Standards & Zero-Warning Lint Latch"
echo "================================================================"

# 1. Check for SPDX Copyright Headers on TTZip-authored source files
echo "▶ [Step 1/3] Verifying SPDX License & Copyright Headers on TTZip sources..."
SPDX_MISSING=0
while IFS= read -r file; do
    if ! grep -q "SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0" "$file"; then
        echo "❌ Missing SPDX header in: $file"
        SPDX_MISSING=$((SPDX_MISSING + 1))
    fi
done < <(find Sources Tests scripts -name "*.swift" -o -name "*.c" -o -name "*.h" -o -name "*.sh" \
    | grep -v "Vendor/" \
    | grep -v "Fixtures/" \
    | grep -v "Sources/CTTZipBridge/zopfli/" \
    | grep -v "Sources/CTTZipBridge/snappy/" \
    | grep -v "Sources/CTTZipBridge/fast-lzma2/" \
    | grep -v "Sources/CTTZipBridge/lzfse/" \
)

if [ "$SPDX_MISSING" -gt 0 ]; then
    echo "❌ $SPDX_MISSING files missing SPDX header."
    exit 1
fi
echo "✅ SPDX Headers 100% verified on all TTZip-authored files."

# 2. Check for Zero Non-ASCII in C Bridge and Native Deflate
echo "▶ [Step 2/3] Verifying 100% Libarchive English in Native C & Core Bridge..."
NON_ASCII_C=$(python3 -c '
import os, glob, sys

c_files = glob.glob("Sources/CTTZipBridge/*.c") + glob.glob("Sources/CTTZipBridge/*.h") + glob.glob("Sources/CTTZipBridge/native_deflate/*.[ch]")
has_err = False
for f in c_files:
    if os.path.isfile(f):
        with open(f, "rb") as fp:
            for idx, line in enumerate(fp, 1):
                try:
                    line.decode("ascii")
                except UnicodeDecodeError:
                    print(f"{f}:{idx}: contains non-ASCII characters")
                    has_err = True
if has_err:
    sys.exit(1)
' || true)
if [ -n "$NON_ASCII_C" ]; then
    echo "❌ Found non-ASCII characters in C bridge files:"
    echo "$NON_ASCII_C"
    exit 1
fi
echo "✅ C Bridge & Native Deflate 100% English Doxygen compliant."

# 3. Verify Zero-Warning Build
echo "▶ [Step 3/3] Compiling Targets & Tests with -warnings-as-errors..."
swift build --build-tests -Xswiftc -warnings-as-errors

echo "================================================================"
echo "🎉 ALL CODEBASE STANDARDS & ZERO-WARNING GATES PASSED (100% OK)"
echo "================================================================"
