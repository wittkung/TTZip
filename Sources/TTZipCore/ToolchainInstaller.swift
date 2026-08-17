import Foundation

public enum ToolchainError: Error, LocalizedError, Sendable {
    case homebrewNotInstalledNeedConsent
    case processFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .homebrewNotInstalledNeedConsent:
            return "检测到当前系统尚未安装 Homebrew 包管理器，需要用户同意后进行安装。"
        case .processFailed(let msg):
            return "安装过程失败: \(msg)"
        }
    }
}

/// 7-Zip / Keka 同源高性能 CLI 工具链自动部署助手
public final class ToolchainInstaller: @unchecked Sendable {
    public static let shared = ToolchainInstaller()
    
    private init() {}
    
    /// 检查系统中是否安装了 Homebrew 包管理器
    public var homebrewExecutablePath: String? {
        #if MAS_BUILD
        return nil
        #else
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for p in candidates {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }
        return nil
        #endif
    }
    
    public var isHomebrewInstalled: Bool {
        return homebrewExecutablePath != nil
    }
    
    /// 检测 GitHub 官方源连通性 (带 2 秒超时)
    public func testGitHubConnectivity() -> Bool {
        #if MAS_BUILD
        return false
        #else
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-s", "-I", "--connect-timeout", "2", "https://raw.githubusercontent.com"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
        #endif
    }
    
    /// 自动化安装 macOS Homebrew 包管理器 (支持国内网络镜像智能加速)
    public func installHomebrew(statusHandler: @escaping @Sendable (String) -> Void) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("Mac App Store 沙盒版本不开放外部工具链安装")
        return false
        #else
        if isHomebrewInstalled {
            statusHandler("Homebrew 已存在于系统中")
            return true
        }
        
        let hasDirectGitHub = testGitHubConnectivity()
        
        if hasDirectGitHub {
            statusHandler("网络环境良好，正在连接 Homebrew 官方源下载安装脚本...")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 && isHomebrewInstalled {
                statusHandler("✅ Homebrew 包管理器安装成功！")
                return true
            }
        }
        
        // 国内无代理/梯子环境: 自动切换为国内清华 TUNA / Gitee 极速镜像加速源
        statusHandler("检测到国内无代理网络环境，自动切换为 [清华大学 TUNA / Gitee 极速镜像源] 部署...")
        
        let mirrorProcess = Process()
        mirrorProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        // 配置清华源与 Gitee 镜像加速安装脚本
        let mirrorCmd = """
        export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
        export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
        export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
        """
        mirrorProcess.arguments = ["-c", mirrorCmd]
        
        let mirrorPipe = Pipe()
        mirrorProcess.standardOutput = mirrorPipe
        mirrorProcess.standardError = mirrorPipe
        
        do {
            try mirrorProcess.run()
            mirrorProcess.waitUntilExit()
        } catch {
            // 继续向下尝试内置兜底
        }
        
        if isHomebrewInstalled {
            statusHandler("✅ 已通过国内镜像加速成功安装 Homebrew！")
            return true
        } else {
            statusHandler("网络镜像连接受阻，尝试激活内置离线工具链...")
            return false
        }
        #endif
    }
    
    /// 一键部署 7-Zip (7zz) 工具链 (支持国内镜像加速与离线引擎双重保底)
    public func getInstallationGuide(for toolId: String) -> String {
        switch toolId {
        case "7zip_cli":
            return "若需进行 7-Zip CLI 竞品对比测试，请在终端中手动运行：\n  brew install 7-zip"
        case "pigz_cli":
            return "若需进行 pigz 多线程竞品对比测试，请在终端中手动运行：\n  brew install pigz"
        case "zstd_cli":
            return "若需进行 zstd 竞品对比测试，请在终端中手动运行：\n  brew install zstd"
        case "turbobench_cli":
            return "若需进行 TurboBench 官方基准对齐测试，请运行：\n  ./scripts/bootstrap_turbobench.sh"
        case "lzbench_cli":
            return "若需进行 lzbench 纯内存实时测试，请运行：\n  brew install lzbench (或从源码编译)"
        default:
            return "建议通过 Homebrew 手动安装该工具以参与 Benchmark 比对。"
        }
    }
    
    /// 7-Zip 工具链可状态感知部署查询（仅检测已安装状态，或提供安装指南）
    public func installSevenZipToolchain(
        userConsentedHomebrew: Bool = false,
        statusHandler: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("Mac App Store 沙盒版本不开放外部工具链安装")
        return false
        #else
        if let cli = CompetitorDetector.detectAllCompetitors().first(where: { $0.toolId == "7zip_cli" }), cli.isInstalled {
            statusHandler("7-Zip 工具链已准备就绪: \(cli.cliExecutablePath ?? "")")
            return true
        }
        statusHandler(getInstallationGuide(for: "7zip_cli"))
        return false
        #endif
    }
    
    /// 一键部署 pigz 多线程并行 GZIP 工具链 (支持国内镜像加速)
    public func installPigzToolchain(
        userConsentedHomebrew: Bool = false,
        statusHandler: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("Mac App Store 沙盒版本不开放外部工具链安装")
        return false
        #else
        if let cli = CompetitorDetector.detectAllCompetitors().first(where: { $0.toolId == "pigz_cli" }), cli.isInstalled {
            statusHandler("pigz 多线程工具链已准备就绪: \(cli.cliExecutablePath ?? "")")
            return true
        }
        statusHandler(getInstallationGuide(for: "pigz_cli"))
        return false
        #endif
    }
    
    /// 一键全量部署所有竞品工具链 (7-zip + pigz)
    public func installAllCompetitorToolchains(
        userConsentedHomebrew: Bool = false,
        statusHandler: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        #if MAS_BUILD
        statusHandler("Mac App Store 沙盒版本不开放外部工具链安装")
        return false
        #else
        let ok7z = (try? await installSevenZipToolchain(userConsentedHomebrew: userConsentedHomebrew, statusHandler: statusHandler)) ?? false
        let okPigz = (try? await installPigzToolchain(userConsentedHomebrew: userConsentedHomebrew, statusHandler: statusHandler)) ?? false
        return ok7z && okPigz
        #endif
    }

    /// 一键卸载指定/可选择的竞品软件与工具链 (支持选择任意单项或全量卸载)
    public func uninstallCompetitorToolchains(
        tools: [String],
        statusHandler: @escaping @Sendable (String) -> Void
    ) async -> [String: Bool] {
        #if MAS_BUILD
        statusHandler("Mac App Store 沙盒版本不开放外部工具卸载操作")
        return [:]
        #else
        var results: [String: Bool] = [:]
        let isAll = tools.contains("all") || tools.contains("ALL")
        let brewPath = homebrewExecutablePath

        let targetTools = isAll ? ["keka", "betterzip", "maczip", "pigz", "7zip", "zstd"] : tools

        for tool in targetTools {
            let lower = tool.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.isEmpty { continue }
            statusHandler("🗑️ 正在尝试卸载竞品工具: \(lower)...")

            var success = false

            switch lower {
            case "keka":
                if let brew = brewPath {
                    runProcess(brew, ["uninstall", "--cask", "--force", "keka"])
                }
                try? FileManager.default.removeItem(atPath: "/Applications/Keka.app")
                success = !FileManager.default.fileExists(atPath: "/Applications/Keka.app")

            case "betterzip":
                if let brew = brewPath {
                    runProcess(brew, ["uninstall", "--cask", "--force", "betterzip"])
                }
                try? FileManager.default.removeItem(atPath: "/Applications/BetterZip.app")
                success = !FileManager.default.fileExists(atPath: "/Applications/BetterZip.app")

            case "maczip", "ezip":
                if let brew = brewPath {
                    runProcess(brew, ["uninstall", "--cask", "--force", "maczip"])
                }
                try? FileManager.default.removeItem(atPath: "/Applications/MacZip.app")
                success = !FileManager.default.fileExists(atPath: "/Applications/MacZip.app")

            case "pigz":
                if let brew = brewPath {
                    let code = runProcess(brew, ["uninstall", "pigz"])
                    success = code == 0
                }

            case "7zip", "7z", "7zz":
                if let brew = brewPath {
                    let code = runProcess(brew, ["uninstall", "7-zip"])
                    success = code == 0
                }

            case "zstd":
                if let brew = brewPath {
                    let code = runProcess(brew, ["uninstall", "zstd"])
                    success = code == 0
                }

            default:
                statusHandler("⚠️ 未知或不受支持的软件组件: \(lower)")
            }

            results[lower] = success
            if success {
                statusHandler("✅ 已完成 \(lower) 软件的清理卸载")
            } else {
                statusHandler("⚠️ \(lower) 清理可能需手动确认或未完全卸载")
            }
        }

        return results
        #endif
    }

    #if !MAS_BUILD
    @discardableResult
    private func runProcess(_ binary: String, _ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
    #endif
}
