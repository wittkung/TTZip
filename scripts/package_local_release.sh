#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
# ==============================================================================
# scripts/package_local_release.sh
# 100% 本地全自动化发布打包流水线 (0 云端 CI / GitHub Actions 额度消耗)
# 产物：TTZip.app、ttzip-cli 发布 tar.gz、TTZip.dmg、Formula/ttzip-cli.rb & ttzip.rb、checksums.txt
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${WORKSPACE_ROOT}"

# Default parameters
VERSION="1.0.0"
TARGET_ARCH="universal"
OUTPUT_DIR="${WORKSPACE_ROOT}/dist"
SKIP_DMG=false
SKIP_RUST=false
STRIP_SYMBOLS=true
DRY_RUN=false

CLI_SHA256=""
DMG_SHA256=""

usage() {
    echo "Usage: ./scripts/package_local_release.sh [OPTIONS]"
    echo "Options:"
    echo "  --version <ver>      Release version string (default: 1.0.0)"
    echo "  --arch <arch>        Target architecture: universal, arm64, x86_64"
    echo "  --output-dir <path>  Output directory for artifacts (default: ./dist)"
    echo "  --skip-dmg           Skip generating Release DMG image"
    echo "  --skip-rust          Skip building Rust core and standalone TUI binary"
    echo "  --no-strip           Keep debug symbols in binaries"
    echo "  --dry-run            Simulate execution without modifying dist artifacts"
    echo "  -h, --help           Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --arch) TARGET_ARCH="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --skip-dmg) SKIP_DMG=true; shift ;;
        --skip-rust) SKIP_RUST=true; shift ;;
        --no-strip) STRIP_SYMBOLS=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; exit 64 ;;
    esac
done

TARBALL_NAME="ttzip-cli-v${VERSION}-darwin-${TARGET_ARCH}.tar.gz"
DMG_NAME="TTZip-v${VERSION}.dmg"
APP_BUNDLE="${OUTPUT_DIR}/TTZip.app"

find_binary() {
    local name="$1"
    local candidates=(
        "${WORKSPACE_ROOT}/.build/apple/Products/Release/${name}"
        "${WORKSPACE_ROOT}/.build/arm64-apple-macosx/release/${name}"
        "${WORKSPACE_ROOT}/.build/x86_64-apple-macosx/release/${name}"
        "${WORKSPACE_ROOT}/.build/release/${name}"
    )
    for p in "${candidates[@]}"; do
        if [ -f "${p}" ]; then echo "${p}"; return 0; fi
    done
    echo ""; return 1
}

build_rust_core() {
    if [ "${SKIP_RUST}" = true ]; then
        echo "--> [INFO] Skipping Rust core build (--skip-rust)"; return 0
    fi
    echo "==> [1/6] Compiling Rust Core Glue & Standalone Binary..."
    "${SCRIPT_DIR}/build_rust.sh" --release
    "${SCRIPT_DIR}/build_tui.sh" --release
}

build_swift_targets() {
    echo "==> [2/6] Compiling Swift Release Product (TTZipApp)..."
    swift build -c release --product TTZipApp
}

assemble_app_bundle() {
    echo "==> [3/6] Assembling Desktop App Bundle (${APP_BUNDLE})..."
    local app_bin
    app_bin="$(find_binary TTZipApp)"
    if [ -z "${app_bin}" ] || [ ! -f "${app_bin}" ]; then
        echo "❌ Error: TTZipApp executable not found in .build"; exit 1
    fi
    
    local contents_dir="${APP_BUNDLE}/Contents"
    local macos_dir="${contents_dir}/MacOS"
    local frameworks_dir="${contents_dir}/Frameworks"
    local resources_dir="${contents_dir}/Resources"
    local helpers_dir="${contents_dir}/Helpers"
    
    rm -rf "${APP_BUNDLE}"
    mkdir -p "${macos_dir}" "${frameworks_dir}" "${resources_dir}" "${helpers_dir}"
    
    cp "${app_bin}" "${macos_dir}/TTZip"
    [ "${STRIP_SYMBOLS}" = true ] && strip -x "${macos_dir}/TTZip" 2>/dev/null || true
    chmod +x "${macos_dir}/TTZip"
    install_name_tool -add_rpath @executable_path/../Frameworks "${macos_dir}/TTZip" 2>/dev/null || true
    
    local rust_cli="${WORKSPACE_ROOT}/bin/ttzip"
    [ ! -f "${rust_cli}" ] && rust_cli="${WORKSPACE_ROOT}/rust/target/release/ttzip"
    if [ -f "${rust_cli}" ]; then
        cp "${rust_cli}" "${helpers_dir}/ttzip"
        [ "${STRIP_SYMBOLS}" = true ] && strip -x "${helpers_dir}/ttzip" 2>/dev/null || true
        chmod +x "${helpers_dir}/ttzip"
        codesign --force --deep --sign - "${helpers_dir}/ttzip" 2>/dev/null || true
    fi
    
    local sparkle_src
    sparkle_src="$(find "${WORKSPACE_ROOT}/.build" -name "Sparkle.framework" -type d 2>/dev/null | grep -E "xcframework.*macos|release/Sparkle.framework" | head -n 1 || true)"
    if [ -n "${sparkle_src}" ] && [ -d "${sparkle_src}" ]; then
        cp -R "${sparkle_src}" "${frameworks_dir}/"
        codesign --force --deep --sign - "${frameworks_dir}/Sparkle.framework" 2>/dev/null || true
    fi
    
    cp "${WORKSPACE_ROOT}/Sources/TTZipApp/Info.plist" "${contents_dir}/Info.plist"
    echo "APPL????" > "${contents_dir}/PkgInfo"
    
    local icon_path="${WORKSPACE_ROOT}/Sources/TTZipApp/Resources/AppIcon.icns"
    if [ ! -f "${icon_path}" ] && [ -f "${SCRIPT_DIR}/generate_app_icon.sh" ]; then
        "${SCRIPT_DIR}/generate_app_icon.sh" || true
    fi
    [ -f "${icon_path}" ] && cp "${icon_path}" "${resources_dir}/AppIcon.icns"
    [ -f "${WORKSPACE_ROOT}/Sources/TTZipApp/PrivacyInfo.xcprivacy" ] && cp "${WORKSPACE_ROOT}/Sources/TTZipApp/PrivacyInfo.xcprivacy" "${resources_dir}/PrivacyInfo.xcprivacy"
    local plugins_dir="${contents_dir}/PlugIns"
    mkdir -p "${plugins_dir}"
    "${SCRIPT_DIR}/build_extensions.sh"
    if [ -d "${OUTPUT_DIR}/PlugIns" ]; then
        cp -R "${OUTPUT_DIR}/PlugIns/"* "${plugins_dir}/"
    fi
    
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
    echo "  ✓ App bundle assembled at ${APP_BUNDLE}"
}

package_cli_tarball() {
    echo "==> [4/6] Packaging Standalone Rust CLI Tarball..."
    local rust_cli="${WORKSPACE_ROOT}/bin/ttzip"
    [ ! -f "${rust_cli}" ] && rust_cli="${WORKSPACE_ROOT}/rust/target/release/ttzip"
    if [ -z "${rust_cli}" ] || [ ! -f "${rust_cli}" ]; then
        echo "❌ Error: ttzip standalone binary not found"; exit 1
    fi
    
    local staging_root="${OUTPUT_DIR}/staging"
    local staging_dir="${staging_root}/ttzip-cli-v${VERSION}"
    rm -rf "${staging_root}"
    mkdir -p "${staging_dir}/bin" "${staging_dir}/share/man/man1"
    mkdir -p "${staging_dir}/share/zsh/site-functions" "${staging_dir}/share/bash-completion/completions" "${staging_dir}/share/fish/vendor_completions.d"
    
    cp "${rust_cli}" "${staging_dir}/bin/ttzip"
    ln -sf "ttzip" "${staging_dir}/bin/ttzip-cli"
    
    if [ "${STRIP_SYMBOLS}" = true ]; then
        strip -x "${staging_dir}/bin/ttzip" 2>/dev/null || true
    fi
    chmod +x "${staging_dir}/bin/ttzip"
    
    [ -f "${WORKSPACE_ROOT}/LICENSE" ] && cp "${WORKSPACE_ROOT}/LICENSE" "${staging_dir}/LICENSE"
    [ -f "${WORKSPACE_ROOT}/README.md" ] && cp "${WORKSPACE_ROOT}/README.md" "${staging_dir}/README.md"
    
    find "${staging_dir}" -name "._*" -o -name ".DS_Store" -delete 2>/dev/null || true
    COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs -czf "${OUTPUT_DIR}/${TARBALL_NAME}" -C "${staging_root}" "ttzip-cli-v${VERSION}"
    rm -rf "${staging_root}"
    
    CLI_SHA256="$(shasum -a 256 "${OUTPUT_DIR}/${TARBALL_NAME}" | awk '{print $1}')"
    echo "  ✓ CLI Tarball: ${OUTPUT_DIR}/${TARBALL_NAME}"
    echo "  ✓ SHA-256    : ${CLI_SHA256}"
}

generate_dmg() {
    if [ "${SKIP_DMG}" = true ]; then
        echo "==> [5/6] Skipping DMG Generation (--skip-dmg)"; return 0
    fi
    echo "==> [5/6] Generating Release DMG (${DMG_NAME})..."
    local dmg_staging="${OUTPUT_DIR}/dmg_staging"
    rm -rf "${dmg_staging}" && mkdir -p "${dmg_staging}"
    cp -R "${APP_BUNDLE}" "${dmg_staging}/"
    ln -s /Applications "${dmg_staging}/Applications"
    
    rm -f "${OUTPUT_DIR}/${DMG_NAME}"
    hdiutil create -volname "TTZip" -srcfolder "${dmg_staging}" -ov -format UDZO "${OUTPUT_DIR}/${DMG_NAME}" >/dev/null
    rm -rf "${dmg_staging}"
    
    DMG_SHA256="$(shasum -a 256 "${OUTPUT_DIR}/${DMG_NAME}" | awk '{print $1}')"
    echo "  ✓ DMG Image : ${OUTPUT_DIR}/${DMG_NAME}"
    echo "  ✓ SHA-256   : ${DMG_SHA256}"
}

generate_single_formula() {
    local class_name="$1"
    local output_path="$2"
    
    cat <<EOF > "${output_path}"
# typed: false
# frozen_string_literal: true

# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression CLI utility for macOS.

class ${class_name} < Formula
  desc "High-performance native archive and compression CLI utility for macOS"
  homepage "https://github.com/wittkung/TTZip"
  url "https://github.com/wittkung/TTZip/releases/download/v${VERSION}/${TARBALL_NAME}"
  sha256 "${CLI_SHA256}"
  license :cannot_be_redistributed

  depends_on :macos => :sonoma

  def install
    bin.install "bin/ttzip-cli"
    bin.install "bin/ttzip" if File.exist?("bin/ttzip")
    man1.install "share/man/man1/ttzip-cli.1" if File.exist?("share/man/man1/ttzip-cli.1")
    bash_completion.install "share/bash-completion/completions/ttzip-cli" if File.exist?("share/bash-completion/completions/ttzip-cli")
    zsh_completion.install "share/zsh/site-functions/_ttzip-cli" if File.exist?("share/zsh/site-functions/_ttzip-cli")
    fish_completion.install "share/fish/vendor_completions.d/ttzip-cli.fish" if File.exist?("share/fish/vendor_completions.d/ttzip-cli.fish")
  end

  test do
    assert_match "ttzip", shell_output("#{bin}/ttzip --version")
    assert_match "platform", shell_output("#{bin}/ttzip doctor --json")
    (testpath/"hello.txt").write("TTZip Homebrew Test Verification")
    system "#{bin}/ttzip", "a", "test.zip", "hello.txt"
    assert_predicate testpath/"test.zip", :exist?
    system "#{bin}/ttzip", "t", "test.zip"
  end
end
EOF
    echo "  ✓ Homebrew Formula: ${output_path}"
}

generate_formula_and_checksums() {
    echo "==> [6/6] Generating Homebrew Formulas & Checksums Manifest..."
    mkdir -p "${WORKSPACE_ROOT}/Formula"
    
    generate_single_formula "TtzipCli" "${WORKSPACE_ROOT}/Formula/ttzip-cli.rb"
    generate_single_formula "Ttzip" "${WORKSPACE_ROOT}/Formula/ttzip.rb"
    
    local checksums_file="${OUTPUT_DIR}/checksums.txt"
    rm -f "${checksums_file}"
    touch "${checksums_file}"
    
    if [ -f "${OUTPUT_DIR}/${TARBALL_NAME}" ]; then
        (cd "${OUTPUT_DIR}" && shasum -a 256 "${TARBALL_NAME}") >> "${checksums_file}"
    fi
    if [ -f "${OUTPUT_DIR}/${DMG_NAME}" ]; then
        (cd "${OUTPUT_DIR}" && shasum -a 256 "${DMG_NAME}") >> "${checksums_file}"
    fi
    echo "  ✓ Checksums Manifest: ${checksums_file}"
    cat "${checksums_file}"
}

main() {
    mkdir -p "${OUTPUT_DIR}"
    echo "======================================================================"
    echo "     TTZip Local-Only Automated Release Packaging Pipeline            "
    echo "======================================================================"
    echo "Version: ${VERSION} | Arch: ${TARGET_ARCH} | Output: ${OUTPUT_DIR}"
    
    if [ "${DRY_RUN}" = true ]; then
        echo "[DRY-RUN] Simulating release packaging for v${VERSION}..."; exit 0
    fi
    
    echo "==> [0/6] Running Single-File LOC Defense Gate (<= 800 LOC)..."
    "${SCRIPT_DIR}/lint_loc_gate.sh"
    
    build_rust_core
    build_swift_targets
    assemble_app_bundle
    package_cli_tarball
    generate_dmg
    generate_formula_and_checksums
    
    echo "======================================================================"
    echo "🎉 Release Packaging Completed Successfully!"
    echo "======================================================================"
}

main "$@"
