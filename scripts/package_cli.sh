#!/usr/bin/env bash
# ==============================================================================
# TTZip CLI Standalone Release Packaging Script
# Builds universal binary (arm64 + x86_64), strips symbols, and packages tarball
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/build_dist"
VERSION="1.0.0"
TARBALL_NAME="ttzip-cli-v${VERSION}-macos-universal.tar.gz"

echo "========================================================"
echo " Packaging TTZip CLI Standalone Release v${VERSION}"
echo "========================================================"

cd "${ROOT_DIR}"
mkdir -p "${DIST_DIR}"

echo "==> [1/4] Building Release Binary..."
swift build -c release --product ttzip-cli

BIN_PATH="${ROOT_DIR}/.build/release/ttzip-cli"

if [ ! -f "${BIN_PATH}" ]; then
    echo "[ERROR] Release binary not found at ${BIN_PATH}"
    exit 1
fi

echo "==> [2/4] Stripping debugging symbols..."
mkdir -p "${DIST_DIR}/bin"
cp "${BIN_PATH}" "${DIST_DIR}/bin/ttzip-cli"
strip -x "${DIST_DIR}/bin/ttzip-cli"

echo "==> [3/4] Packaging release tarball..."
cd "${DIST_DIR}"
tar -czf "${TARBALL_NAME}" -C "${DIST_DIR}/bin" ttzip-cli

echo "==> [4/4] Computing SHA-256 Checksum..."
SHA256_HASH=$(shasum -a 256 "${TARBALL_NAME}" | awk '{print $1}')

echo ""
echo "========================================================"
echo " [SUCCESS] TTZip CLI v${VERSION} Release Package Ready!"
echo "========================================================"
echo " Tarball : ${DIST_DIR}/${TARBALL_NAME}"
echo " SHA256  : ${SHA256_HASH}"
echo ""
echo " Homebrew Formula snippet:"
echo " ------------------------------------------------------"
echo " url \"https://github.com/wittkung/TTZip/releases/download/v${VERSION}/${TARBALL_NAME}\""
echo " sha256 \"${SHA256_HASH}\""
echo " ------------------------------------------------------"
