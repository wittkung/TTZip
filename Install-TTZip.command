#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# Double-clickable macOS installation script (GUI App + CLI tools)

set -e

# Crucial: cd to script's directory regardless of how Finder launches it
cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

# Colors & Formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GOLD='\033[38;5;220m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${GOLD}"
echo "  ████████╗████████╗███████╗██╗██████╗ "
echo "  ╚══██╔══╝╚══██╔══╝╚══███╔╝██║██╔══██╗"
echo "     ██║      ██║     ███╔╝ ██║██████╔╝"
echo "     ██║      ██║    ███╔╝  ██║██╔═══╝ "
echo "     ██║      ██║   ███████╗██║██║     "
echo "     ╚═╝      ╚═╝   ╚══════╝╚═╝╚═╝     "
echo -e "${CYAN}  Native High-Performance Archiver for macOS${NC}"
echo -e "${BOLD}  [双击一键编译并覆盖安装 Release 最新版]${NC}"
echo "========================================================"

# 1. Check Toolchain
echo -e "\n${BLUE}==> [1/5] 检查编译环境...${NC}"
if ! command -v swift >/dev/null 2>&1; then
    echo -e "${RED}[错误] 未检测到 Swift 编译器，请确保已安装 Xcode 16+ 或 Command Line Tools。${NC}"
    echo "按任意键退出..."
    read -n 1 -s -r
    exit 1
fi

ARCH="$(uname -m)"
OS_VER="$(sw_vers -productVersion 2>/dev/null || echo "macOS")"
echo "  • 架构: ${ARCH} (Apple Silicon / Intel 兼容)"
echo "  • 系统: macOS ${OS_VER}"
echo "  • 源码路径: ${REPO_ROOT}"

# 2. Terminate Old Running Instances
echo -e "\n${BLUE}==> [2/5] 清理旧版运行进程...${NC}"
if pgrep -x "TTZip" >/dev/null 2>&1; then
    echo -e "${YELLOW}  • 检测到正在运行的 TTZip，正在平滑关闭...${NC}"
    pkill -x "TTZip" >/dev/null 2>&1 || true
    sleep 0.8
fi

# 3. Compile Release Targets
echo -e "\n${BLUE}==> [3/5] 开始编译最新 Release 版本 (Swift 6.0 + 硬件加速)...${NC}"
echo "  --> 正在编译 TTZipApp 桌面端..."
swift build -c release --product TTZipApp

echo "  --> 正在编译 ttzip-cli 命令行工具..."
swift build -c release --product ttzip-cli

BUILD_DIR="${REPO_ROOT}/.build/release"
APP_SRC="${BUILD_DIR}/TTZipApp"
CLI_SRC="${BUILD_DIR}/ttzip-cli"

if [ ! -f "${APP_SRC}" ] || [ ! -f "${CLI_SRC}" ]; then
    echo -e "${RED}[错误] 编译产物缺失，请检查构建日志。${NC}"
    read -n 1 -s -r
    exit 1
fi

# 4. Package TTZip.app & Install to /Applications
echo -e "\n${BLUE}==> [4/5] 打包并覆盖安装 TTZip.app 到 /Applications...${NC}"
APP_BUNDLE="${REPO_ROOT}/dist/TTZip.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICON_ASSET="${REPO_ROOT}/Sources/TTZipApp/Resources/AppIcon.icns"

rm -rf "${REPO_ROOT}/dist"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"

# Copy binary & strip
cp "${APP_SRC}" "${MACOS_DIR}/TTZip"
strip -x "${MACOS_DIR}/TTZip" 2>/dev/null || true
chmod +x "${MACOS_DIR}/TTZip"

# Ensure rpath includes Frameworks directory
install_name_tool -add_rpath @executable_path/../Frameworks "${MACOS_DIR}/TTZip" 2>/dev/null || true

# Copy Sparkle.framework if present
SPARKLE_SRC="$(find "${REPO_ROOT}/.build" -name "Sparkle.framework" -type d 2>/dev/null | grep -E "xcframework.*macos|release/Sparkle.framework" | head -n 1 || true)"
if [ -n "${SPARKLE_SRC}" ] && [ -d "${SPARKLE_SRC}" ]; then
    echo "  --> 注入 Sparkle 自动更新框架: ${SPARKLE_SRC}"
    cp -R "${SPARKLE_SRC}" "${FRAMEWORKS_DIR}/"
    codesign --force --deep --sign - "${FRAMEWORKS_DIR}/Sparkle.framework" 2>/dev/null || true
fi

# Copy plist & icons
cp "${REPO_ROOT}/Sources/TTZipApp/Info.plist" "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"
if [ -f "${ICON_ASSET}" ]; then
    cp "${ICON_ASSET}" "${RESOURCES_DIR}/AppIcon.icns"
fi
if [ -f "${REPO_ROOT}/Sources/TTZipApp/PrivacyInfo.xcprivacy" ]; then
    cp "${REPO_ROOT}/Sources/TTZipApp/PrivacyInfo.xcprivacy" "${RESOURCES_DIR}/PrivacyInfo.xcprivacy"
fi

# Sign
echo "  --> 执行本地 Ad-hoc 代码签名..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

# Target install
TARGET_APP="/Applications/TTZip.app"
echo "  --> 覆盖安装至 ${TARGET_APP}..."

if [ -d "${TARGET_APP}" ]; then
    if [ -w "/Applications" ]; then
        rm -rf "${TARGET_APP}"
    else
        echo -e "${YELLOW}  [需要权限] 请输入密码以覆盖 /Applications/TTZip.app:${NC}"
        sudo rm -rf "${TARGET_APP}"
    fi
fi

if [ -w "/Applications" ]; then
    cp -R "${APP_BUNDLE}" "/Applications/"
else
    sudo cp -R "${APP_BUNDLE}" "/Applications/"
fi

# Re-register LaunchServices
if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${TARGET_APP}" 2>/dev/null || true
fi
echo -e "${GREEN}  ✓ GUI 桌面版安装成功: ${TARGET_APP}${NC}"

# 5. Install CLI Tools to System PATH
echo -e "\n${BLUE}==> [5/5] 安装 CLI 命令行工具 (ttzip / ttzip-cli)...${NC}"

CLI_TARGET_DIR="/usr/local/bin"
if [ -w "/opt/homebrew/bin" ] && [[ ":$PATH:" == *":/opt/homebrew/bin:"* ]]; then
    CLI_TARGET_DIR="/opt/homebrew/bin"
fi

echo "  --> 目标目录: ${CLI_TARGET_DIR}"

install_cli() {
    local target_dir="$1"
    if [ -w "${target_dir}" ]; then
        cp "${CLI_SRC}" "${target_dir}/ttzip-cli"
        strip -x "${target_dir}/ttzip-cli" 2>/dev/null || true
        chmod +x "${target_dir}/ttzip-cli"
        ln -sf "${target_dir}/ttzip-cli" "${target_dir}/ttzip"
    else
        echo -e "${YELLOW}  [需要权限] 请输入密码以安装命令行工具到 ${target_dir}:${NC}"
        sudo mkdir -p "${target_dir}"
        sudo cp "${CLI_SRC}" "${target_dir}/ttzip-cli"
        sudo strip -x "${target_dir}/ttzip-cli" 2>/dev/null || true
        sudo chmod +x "${target_dir}/ttzip-cli"
        sudo ln -sf "${target_dir}/ttzip-cli" "${target_dir}/ttzip"
    fi
}

install_cli "${CLI_TARGET_DIR}"

# If on Apple Silicon with both /opt/homebrew/bin and /usr/local/bin, link both if possible
if [ "${CLI_TARGET_DIR}" = "/opt/homebrew/bin" ] && [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    cp "${CLI_SRC}" "/usr/local/bin/ttzip-cli" 2>/dev/null || true
    strip -x "/usr/local/bin/ttzip-cli" 2>/dev/null || true
    ln -sf "/usr/local/bin/ttzip-cli" "/usr/local/bin/ttzip" 2>/dev/null || true
fi

echo -e "${GREEN}  ✓ CLI 命令行工具已安装至: ${CLI_TARGET_DIR}/ttzip & ttzip-cli${NC}"

# Summary & Launch
echo ""
echo "========================================================"
echo -e "${GREEN}${BOLD}🎉 TTZip 最新 Release 版本已成功安装并覆盖！${NC}"
echo "========================================================"
echo -e "  • 桌面端应用 : ${BOLD}/Applications/TTZip.app${NC}"
echo -e "  • 命令行工具 : ${BOLD}${CLI_TARGET_DIR}/ttzip${NC}"
echo ""
echo "--> 正在启动最新版 TTZip.app..."
open -a TTZip || open "${TARGET_APP}"

echo ""
echo -e "${CYAN}安装完毕！按任意键关闭此终端窗口...${NC}"
read -n 1 -s -r
exit 0
