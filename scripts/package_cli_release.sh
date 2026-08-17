#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# package_cli_release.sh: Universal 2 Release Packaging & Homebrew Tap Formula Pipeline

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${WORKSPACE_ROOT}"

# Default parameters
VERSION="1.0.0"
TARGET_ARCH="universal"
OUTPUT_DIR="${WORKSPACE_ROOT}/dist"
DRY_RUN=false
STRIP_SYMBOLS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --arch)
            TARGET_ARCH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-strip)
            STRIP_SYMBOLS=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: ./scripts/package_cli_release.sh [options]"
            echo ""
            echo "Options:"
            echo "  --version <ver>      Release version string (default: 1.0.0)"
            echo "  --arch <arch>        Target architecture: universal, arm64, x86_64 (default: universal)"
            echo "  --output-dir <path>  Output directory for tarballs and formula (default: ./dist)"
            echo "  --no-strip           Keep full debug symbols in binary"
            echo "  --dry-run            Simulate build without creating final release archives"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 64
            ;;
    esac
done

TARBALL_NAME="ttzip-cli-v${VERSION}-darwin-${TARGET_ARCH}.tar.gz"
STAGING_DIR="${OUTPUT_DIR}/staging/ttzip-cli-v${VERSION}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${STAGING_DIR}/bin"
mkdir -p "${STAGING_DIR}/share/man/man1"
mkdir -p "${STAGING_DIR}/share/zsh/site-functions"
mkdir -p "${STAGING_DIR}/share/bash-completion/completions"
mkdir -p "${STAGING_DIR}/share/fish/vendor_completions.d"
mkdir -p "${WORKSPACE_ROOT}/Formula"

echo "======================================================================"
echo "           TTZip Standalone CLI Packaging & Homebrew Tap Pipeline      "
echo "======================================================================"
echo "Version:      ${VERSION}"
echo "Architecture: ${TARGET_ARCH}"
echo "Output Dir:   ${OUTPUT_DIR}"
echo ""

if [ "${DRY_RUN}" = true ]; then
    echo "[DRY-RUN] Simulating compilation and packaging for version ${VERSION} (${TARGET_ARCH})..."
    echo "[DRY-RUN] Staging layout: ${STAGING_DIR}"
    echo "[DRY-RUN] Target tarball: ${OUTPUT_DIR}/${TARBALL_NAME}"
    echo "✅ Dry-run completed successfully!"
    exit 0
fi

# 1. Compile Release Binary
echo "[1/5] Compiling Release Binary (${TARGET_ARCH})..."
if [ "${TARGET_ARCH}" = "universal" ]; then
    # Attempt SPM unified universal build, fallback to lipo if needed
    set +e
    swift build -c release --arch arm64 --arch x86_64 --product ttzip-cli
    BUILD_EXIT=$?
    set -e
    
    if [ ${BUILD_EXIT} -eq 0 ] && [ -f ".build/apple/Products/Release/ttzip-cli" ]; then
        COMPILED_BIN=".build/apple/Products/Release/ttzip-cli"
    else
        echo "  ℹ️  Unified multi-arch build failed; falling back to per-slice compilation with lipo..."
        swift build -c release --arch arm64 --product ttzip-cli
        swift build -c release --arch x86_64 --product ttzip-cli
        
        ARM64_BIN=".build/arm64-apple-macosx/release/ttzip-cli"
        X86_BIN=".build/x86_64-apple-macosx/release/ttzip-cli"
        COMPILED_BIN="${OUTPUT_DIR}/ttzip-cli-universal-unstripped"
        lipo -create -output "${COMPILED_BIN}" "${ARM64_BIN}" "${X86_BIN}"
    fi
elif [ "${TARGET_ARCH}" = "arm64" ]; then
    swift build -c release --arch arm64 --product ttzip-cli
    COMPILED_BIN=".build/arm64-apple-macosx/release/ttzip-cli"
    if [ ! -f "${COMPILED_BIN}" ]; then
        COMPILED_BIN=".build/release/ttzip-cli"
    fi
else
    swift build -c release --arch x86_64 --product ttzip-cli
    COMPILED_BIN=".build/x86_64-apple-macosx/release/ttzip-cli"
    if [ ! -f "${COMPILED_BIN}" ]; then
        COMPILED_BIN=".build/release/ttzip-cli"
    fi
fi

cp "${COMPILED_BIN}" "${STAGING_DIR}/bin/ttzip-cli"
chmod +x "${STAGING_DIR}/bin/ttzip-cli"

# 2. Extract DWARF dSYM and Strip Local Symbols
echo "[2/5] Extracting Debug Symbols & Stripping Local Symbols..."
dsymutil "${STAGING_DIR}/bin/ttzip-cli" -o "${OUTPUT_DIR}/ttzip-cli-v${VERSION}.dSYM" >/dev/null 2>&1 || true

if [ "${STRIP_SYMBOLS}" = true ]; then
    strip -x "${STAGING_DIR}/bin/ttzip-cli"
fi

# 3. Self-Generate Man Page & Shell Auto-Completions
echo "[3/5] Self-Generating Man Page & Completion Scripts..."
"${STAGING_DIR}/bin/ttzip-cli" man > "${STAGING_DIR}/share/man/man1/ttzip-cli.1"
"${STAGING_DIR}/bin/ttzip-cli" completion zsh > "${STAGING_DIR}/share/zsh/site-functions/_ttzip-cli"
"${STAGING_DIR}/bin/ttzip-cli" completion bash > "${STAGING_DIR}/share/bash-completion/completions/ttzip-cli"
"${STAGING_DIR}/bin/ttzip-cli" completion fish > "${STAGING_DIR}/share/fish/vendor_completions.d/ttzip-cli.fish"

# Copy license and readme
cp "${WORKSPACE_ROOT}/LICENSE" "${STAGING_DIR}/LICENSE" 2>/dev/null || touch "${STAGING_DIR}/LICENSE"
cp "${WORKSPACE_ROOT}/README.md" "${STAGING_DIR}/README.md" 2>/dev/null || touch "${STAGING_DIR}/README.md"

# 4. Create Clean Release Tarball
echo "[4/5] Creating Clean Release Tarball..."
find "${STAGING_DIR}" -name "._*" -o -name ".DS_Store" -delete 2>/dev/null || true
COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs -czf "${OUTPUT_DIR}/${TARBALL_NAME}" -C "${OUTPUT_DIR}/staging" "ttzip-cli-v${VERSION}"

TARBALL_SHA256=$(shasum -a 256 "${OUTPUT_DIR}/${TARBALL_NAME}" | awk '{print $1}')
echo "  ➔ Tarball: ${OUTPUT_DIR}/${TARBALL_NAME}"
echo "  ➔ SHA-256: ${TARBALL_SHA256}"

# 5. Generate Homebrew Formula
echo "[5/5] Generating Homebrew Formula..."
FORMULA_PATH="${WORKSPACE_ROOT}/Formula/ttzip-cli.rb"

cat <<EOF > "${FORMULA_PATH}"
# typed: false
# frozen_string_literal: true

# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression CLI utility for macOS.

class TtzipCli < Formula
  desc "High-performance native archive and compression CLI utility for macOS"
  homepage "https://github.com/wittkung/TTZip"
  url "https://github.com/wittkung/TTZip/releases/download/v${VERSION}/${TARBALL_NAME}"
  sha256 "${TARBALL_SHA256}"
  license :cannot_be_redistributed

  depends_on :macos => :sonoma

  def install
    bin.install "bin/ttzip-cli"
    man1.install "share/man/man1/ttzip-cli.1"
    bash_completion.install "share/bash-completion/completions/ttzip-cli"
    zsh_completion.install "share/zsh/site-functions/_ttzip-cli"
    fish_completion.install "share/fish/vendor_completions.d/ttzip-cli.fish"
  end

  test do
    assert_match "ttzip-cli", shell_output("#{bin}/ttzip-cli --version")
    (testpath/"hello.txt").write("TTZip Homebrew Test Verification")
    system "#{bin}/ttzip-cli", "create", "-f", "zip", "test.zip", "hello.txt"
    assert_predicate testpath/"test.zip", :exist?
    system "#{bin}/ttzip-cli", "test", "test.zip"
  end
end
EOF

# Clean up staging
rm -rf "${OUTPUT_DIR}/staging"

echo ""
echo "======================================================================"
echo "✅ Release package and Homebrew Formula generated successfully!"
echo "   • Tarball: ${OUTPUT_DIR}/${TARBALL_NAME}"
echo "   • Formula: ${FORMULA_PATH}"
echo "======================================================================"
