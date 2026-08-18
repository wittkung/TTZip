#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# Automated Build & Reinstall Script for TTZip (App + CLI)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors & Formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GOLD='\033[38;5;220m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default Configuration
TARGET_MODE="all"      # all, app, cli
BUILD_CONFIG="release" # release, debug
DIST_CHANNEL="direct"  # direct, mas
DO_CLEAN=false
DO_LAUNCH=false
APP_DEST_DIR="/Applications"
CLI_DEST_DIR=""

# Print Banner
print_banner() {
    echo -e "${GOLD}"
    echo "  ████████╗████████╗███████╗██╗██████╗ "
    echo "  ╚══██╔══╝╚══██╔══╝╚══███╔╝██║██╔══██╗"
    echo "     ██║      ██║     ███╔╝ ██║██████╔╝"
    echo "     ██║      ██║    ███╔╝  ██║██╔═══╝ "
    echo "     ██║      ██║   ███████╗██║██║     "
    echo "     ╚═╝      ╚═╝   ╚══════╝╚═╝╚═╝     "
    echo -e "${CYAN}  Native High-Performance Archiver for macOS${NC}"
    echo -e "${BOLD}  Automated Build & Reinstallation Pipeline${NC}"
    echo "========================================================"
}

# Print Usage Help
print_help() {
    echo -e "${BOLD}Usage:${NC} ./scripts/reinstall.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  --all              Build and install both TTZip.app and ttzip CLI (default)"
    echo "  --app              Build and install only Desktop GUI App (TTZip.app)"
    echo "  --cli              Build and install only Command-Line Tool (ttzip / ttzip-cli)"
    echo "  --direct           Build Direct Independent distribution (Sparkle updater, default)"
    echo "  --mas              Build Mac App Store (MAS Sandbox) variant (-DMAS_BUILD)"
    echo "  --debug            Compile in Debug mode instead of Release"
    echo "  --clean            Clean build directory (.build) before compilation"
    echo "  --launch, -o       Launch TTZip.app immediately after installation"
    echo "  --user-apps        Install to ~/Applications instead of /Applications"
    echo "  --help, -h         Show this help message and exit"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./scripts/reinstall.sh                # Standard release build & reinstall both"
    echo "  ./scripts/reinstall.sh --app -o       # Reinstall GUI app and launch it"
    echo "  ./scripts/reinstall.sh --cli          # Reinstall CLI command to PATH"
    echo "  ./scripts/reinstall.sh --clean --mas  # Clean build MAS sandbox version"
    echo ""
}

# Parse Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            TARGET_MODE="all"
            shift
            ;;
        --app)
            TARGET_MODE="app"
            shift
            ;;
        --cli)
            TARGET_MODE="cli"
            shift
            ;;
        --direct)
            DIST_CHANNEL="direct"
            shift
            ;;
        --mas)
            DIST_CHANNEL="mas"
            shift
            ;;
        --debug)
            BUILD_CONFIG="debug"
            shift
            ;;
        --clean)
            DO_CLEAN=true
            shift
            ;;
        --launch|-o)
            DO_LAUNCH=true
            shift
            ;;
        --user-apps)
            APP_DEST_DIR="${HOME}/Applications"
            shift
            ;;
        --help|-h)
            print_banner
            print_help
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR] Unknown option: $1${NC}"
            print_help
            exit 1
            ;;
    esac
done

# Step 1: Pre-flight Verification
print_banner
echo -e "${BLUE}==> [1/5] Checking Environment & Toolchain...${NC}"

if ! command -v swift >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Swift toolchain not found. Please install Xcode 16+ or Xcode Command Line Tools.${NC}"
    exit 1
fi

SWIFT_VER="$(swift --version | head -n 1)"
ARCH="$(uname -m)"
OS_VER="$(sw_vers -productVersion 2>/dev/null || echo "macOS")"

echo "  • Architecture : ${ARCH} (Apple Silicon / Intel)"
echo "  • OS Version   : macOS ${OS_VER}"
echo "  • Toolchain    : ${SWIFT_VER}"
echo "  • Build Target : ${TARGET_MODE} (${BUILD_CONFIG}, ${DIST_CHANNEL})"
echo "  • Install Dest : ${APP_DEST_DIR}"

# Step 2: Clean & Asset Prep
cd "${REPO_ROOT}"

if [ "${DO_CLEAN}" = true ]; then
    echo -e "${BLUE}==> [2/5] Cleaning build artifacts...${NC}"
    rm -rf "${REPO_ROOT}/.build"
    rm -rf "${REPO_ROOT}/dist"
fi

ICON_ASSET="${REPO_ROOT}/Sources/TTZipApp/Resources/AppIcon.icns"
if [ ! -f "${ICON_ASSET}" ] && [ -f "${REPO_ROOT}/scripts/generate_app_icon.sh" ]; then
    echo -e "${BLUE}==> Generating AppIcon.icns...${NC}"
    chmod +x "${REPO_ROOT}/scripts/generate_app_icon.sh"
    "${REPO_ROOT}/scripts/generate_app_icon.sh" || true
fi

# Step 3: Compilation
echo -e "${BLUE}==> [3/5] Compiling Swift Release Targets...${NC}"

SWIFT_FLAGS=()
if [ "${BUILD_CONFIG}" = "release" ]; then
    SWIFT_FLAGS+=("-c" "release")
fi

if [ "${DIST_CHANNEL}" = "mas" ]; then
    SWIFT_FLAGS+=("-Xswiftc" "-DMAS_BUILD")
fi

if [ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "app" ]; then
    echo -e "  --> Building ${BOLD}TTZipApp${NC}..."
    swift build "${SWIFT_FLAGS[@]}" --product TTZipApp
fi

if [ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "cli" ]; then
    echo -e "  --> Building ${BOLD}ttzip-cli${NC}..."
    swift build "${SWIFT_FLAGS[@]}" --product ttzip-cli
fi

BUILD_OUT_DIR="${REPO_ROOT}/.build/${BUILD_CONFIG}"

# Step 4: Install Desktop App (TTZip.app)
if [ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "app" ]; then
    echo -e "${BLUE}==> [4/5] Packaging & Installing TTZip.app...${NC}"
    
    APP_BUNDLE_STAGING="${REPO_ROOT}/dist/TTZip.app"
    CONTENTS_DIR="${APP_BUNDLE_STAGING}/Contents"
    MACOS_DIR="${CONTENTS_DIR}/MacOS"
    FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
    RESOURCES_DIR="${CONTENTS_DIR}/Resources"
    
    rm -rf "${REPO_ROOT}/dist"
    mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"
    
    # Binary
    cp "${BUILD_OUT_DIR}/TTZipApp" "${MACOS_DIR}/TTZip"
    if [ "${BUILD_CONFIG}" = "release" ]; then
        strip -x "${MACOS_DIR}/TTZip" 2>/dev/null || true
    fi
    chmod +x "${MACOS_DIR}/TTZip"
    
    # Ensure rpath includes Frameworks directory
    install_name_tool -add_rpath @executable_path/../Frameworks "${MACOS_DIR}/TTZip" 2>/dev/null || true
    
    # Copy Sparkle.framework if present
    SPARKLE_SRC="$(find "${REPO_ROOT}/.build" -name "Sparkle.framework" -type d 2>/dev/null | grep -E "xcframework.*macos|release/Sparkle.framework" | head -n 1 || true)"
    if [ -n "${SPARKLE_SRC}" ] && [ -d "${SPARKLE_SRC}" ]; then
        echo "  --> Injecting Sparkle update framework..."
        cp -R "${SPARKLE_SRC}" "${FRAMEWORKS_DIR}/"
        codesign --force --deep --sign - "${FRAMEWORKS_DIR}/Sparkle.framework" 2>/dev/null || true
    fi
    
    # Plist & PkgInfo
    cp "${REPO_ROOT}/Sources/TTZipApp/Info.plist" "${CONTENTS_DIR}/Info.plist"
    echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"
    
    # Resources
    if [ -f "${ICON_ASSET}" ]; then
        cp "${ICON_ASSET}" "${RESOURCES_DIR}/AppIcon.icns"
    fi
    if [ -f "${REPO_ROOT}/Sources/TTZipApp/PrivacyInfo.xcprivacy" ]; then
        cp "${REPO_ROOT}/Sources/TTZipApp/PrivacyInfo.xcprivacy" "${RESOURCES_DIR}/PrivacyInfo.xcprivacy"
    fi
    
    # Ad-hoc Code Signing
    echo "  --> Code-signing application bundle (ad-hoc)..."
    codesign --force --deep --sign - "${APP_BUNDLE_STAGING}" 2>/dev/null || true
    
    # Gracefully terminate running instances
    if pgrep -x "TTZip" >/dev/null 2>&1; then
        echo -e "${YELLOW}  [NOTICE] Terminating currently running TTZip instance...${NC}"
        pkill -x "TTZip" >/dev/null 2>&1 || true
        sleep 0.5
    fi
    
    # Ensure Destination Directory Exists
    mkdir -p "${APP_DEST_DIR}"
    
    TARGET_APP_PATH="${APP_DEST_DIR}/TTZip.app"
    echo "  --> Installing bundle to ${TARGET_APP_PATH}..."
    
    if [ -d "${TARGET_APP_PATH}" ]; then
        rm -rf "${TARGET_APP_PATH}" 2>/dev/null || sudo rm -rf "${TARGET_APP_PATH}"
    fi
    
    cp -R "${APP_BUNDLE_STAGING}" "${APP_DEST_DIR}/" 2>/dev/null || sudo cp -R "${APP_BUNDLE_STAGING}" "${APP_DEST_DIR}/"
    
    # Register with LaunchServices
    if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${TARGET_APP_PATH}" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}  ✓ Desktop App successfully installed to ${TARGET_APP_PATH}${NC}"
fi

# Step 5: Install CLI Tool (ttzip & ttzip-cli)
if [ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "cli" ]; then
    echo -e "${BLUE}==> [5/5] Installing ttzip CLI Tool...${NC}"
    
    CLI_BIN_SRC="${BUILD_OUT_DIR}/ttzip-cli"
    
    # Determine best writable directory in PATH
    if [ -w "/usr/local/bin" ]; then
        CLI_DEST_DIR="/usr/local/bin"
    elif [ -w "/opt/homebrew/bin" ]; then
        CLI_DEST_DIR="/opt/homebrew/bin"
    elif [ -d "${HOME}/.local/bin" ] || mkdir -p "${HOME}/.local/bin" 2>/dev/null; then
        CLI_DEST_DIR="${HOME}/.local/bin"
    else
        CLI_DEST_DIR="/usr/local/bin"
    fi
    
    echo "  --> Target CLI directory: ${CLI_DEST_DIR}"
    
    if [ ! -w "${CLI_DEST_DIR}" ]; then
        echo -e "${YELLOW}  [NOTICE] Escalating privileges to write to ${CLI_DEST_DIR}...${NC}"
        sudo mkdir -p "${CLI_DEST_DIR}"
        sudo cp "${CLI_BIN_SRC}" "${CLI_DEST_DIR}/ttzip-cli"
        if [ "${BUILD_CONFIG}" = "release" ]; then
            sudo strip -x "${CLI_DEST_DIR}/ttzip-cli" 2>/dev/null || true
        fi
        sudo chmod +x "${CLI_DEST_DIR}/ttzip-cli"
        sudo ln -sf "${CLI_DEST_DIR}/ttzip-cli" "${CLI_DEST_DIR}/ttzip"
    else
        cp "${CLI_BIN_SRC}" "${CLI_DEST_DIR}/ttzip-cli"
        if [ "${BUILD_CONFIG}" = "release" ]; then
            strip -x "${CLI_DEST_DIR}/ttzip-cli" 2>/dev/null || true
        fi
        chmod +x "${CLI_DEST_DIR}/ttzip-cli"
        ln -sf "${CLI_DEST_DIR}/ttzip-cli" "${CLI_DEST_DIR}/ttzip"
    fi
    
    echo -e "${GREEN}  ✓ CLI binaries installed: ${CLI_DEST_DIR}/ttzip and ${CLI_DEST_DIR}/ttzip-cli${NC}"
fi

# Summary & Launch
echo ""
echo "========================================================"
echo -e "${GREEN}${BOLD}🎉 TTZip Build & Reinstallation Succeeded!${NC}"
echo "========================================================"

if [ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "app" ]; then
    echo -e "  • GUI Application : ${BOLD}${APP_DEST_DIR}/TTZip.app${NC}"
fi
if [ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "cli" ]; then
    echo -e "  • Command Line    : ${BOLD}${CLI_DEST_DIR}/ttzip${NC} (or ttzip-cli)"
fi
echo ""

# Launch if requested
if [ "${DO_LAUNCH}" = true ] && ([ "${TARGET_MODE}" = "all" ] || [ "${TARGET_MODE}" = "app" ]); then
    echo -e "${CYAN}--> Launching TTZip.app...${NC}"
    open "${APP_DEST_DIR}/TTZip.app"
fi
