# TTZip 架构改进实施计划

> 创建日期：2026-08-11
> 状态：Phase 0, Phase 1, Phase 2 & Phase 3 全阶段已实施完毕 (COMPLETED)
> 目标：消除所有外部 CLI 生产路径依赖，实现 Mac App Store + 独立双渠道分发，全面提升工程质量

---

## 背景与动机

TTZip 是一款面向 macOS 14+ 的高性能归档压缩工具，采用 Swift 6 + C 混合编程。项目整体工程质量处于高水准：零技术债务标记（TODO/FIXME/HACK = 0）、65 个测试文件、`-warnings-as-errors` 编译纪律、完整的设计模式体系。

但通过深度代码审计发现以下需要改进的问题：

1. **外部 CLI 依赖嵌入生产路径**：`7zz` 和 `/usr/bin/tar` 在 5 条生产代码路径中被直接调用（加密解压、7z 压缩、7z 解压、TAR 创建/解压），而非仅用于 Benchmark
2. **密码学原语过时**：PBKDF2-SHA1 + 固定盐值
3. **Fat ViewModel**：`AppViewState` 承载 15+ `@Published` 属性
4. **无法上架 Mac App Store**：Sandbox 禁用 + 子进程依赖 + 不必要的 JIT 权限
5. **缺失自动更新机制**
6. **CI/CD 管线不完善**

---

## 已确认的决策

| 决策项 | 结论 |
|--------|------|
| C 引擎方向 | 全面用 in-process C 实现替代所有 `posix_spawn` 生产路径 |
| 分发渠道 | Mac App Store + 独立分发双渠道 |
| Homebrew | 独立版保留作为首选 7zz 安装源（仅用于 Benchmark） |
| Benchmark 竞品安装 | 移除自动安装功能，仅检测已安装工具，提供安装指南 |
| MAS 版 Benchmark | 仅探测系统工具 + 通过 NSWorkspace 发现已安装 .app 的 Bundle CLI |
| CI/CD | 配置但不启用自动触发（保持 workflow_dispatch） |
| Sparkle | 独立版集成，作为唯一外部 SPM 依赖 |
| AppViewState | 按领域拆分为 4 个独立 ObservableObject |
| 密码库 | PBKDF2-SHA256 + 随机盐，v3→v4 单向迁移 |
| allow-jit / allow-unsigned-executable-memory | 两个版本均移除（确认无实际用途） |

---

## 当前外部 CLI 依赖全景（需消除的 5 个生产路径依赖点）

### 依赖点 1：加密归档解压 — 任何格式带密码 → 7zz

**文件**：`Sources/CTTZipBridge/ttzip_native_archive.c` L188-189

```c
if (password && password[0] != '\0') {
    return ttzip_spawn_7zz_extract(NULL, archive_path, dest_dir, password);
}
```

只要用户提供密码，所有格式的解压绕过自研引擎，直接 spawn 7zz。

**修复**：按格式分发到各自引擎的加密路径（ZIP 已有加密支持，7Z 需补齐）。

### 依赖点 2：7z 压缩 — level > 0 或有密码 → 7zz

**文件**：`Sources/CTTZipBridge/CTTZipBridge_7z.c` L309-314

```c
if (level == 0 && (!password || password[0] == '\0')) {
    return ttzip_create_7z_store_fast_c(output_path, input_paths, input_count);
} else {
    return ttzip_spawn_7zz_compress(NULL, output_path, ...);
}
```

自研引擎仅实现 7z store（level=0 且无密码）。其他全部走 7zz 子进程。

**修复**：集成 LZMA SDK 实现 LZMA2 压缩 + AES-256 加密。

### 依赖点 3：7z 解压 — 自研引擎失败 → 7zz（实际 100% 走 7zz）

**文件**：`Sources/CTTZipBridge/CTTZipBridge_7z.c` L295-298

```c
int res = ttzip_7z_extract_native_parallel_c(archive_path, destination_dir, password);
if (res != 0) {
    return ttzip_spawn_7zz_extract(NULL, archive_path, destination_dir, password);
}
```

而 `ttzip_7z_extract_native_parallel_c` 的实现（`CTTZipBridge_7zNativeDecoder.c` L24）直接调用 `ttzip_spawn_7zz_extract`，即 7z 解压 100% 依赖外部进程。

**修复**：基于已有 `ttzip_lzma2_dec_native.h` 实现真正的 in-process LZMA2 解码。

### 依赖点 4：TAR 系列创建 — 全部走 /usr/bin/tar

**文件**：`Sources/CTTZipBridge/CTTZipBridge_Archive.c` L65-157

TAR、TAR.GZ、TAR.ZST 的创建全部通过 `run_tar_create_with_inputs()` 调用 `/usr/bin/tar`。

**修复**：基于 libarchive API 实现 `ttzip_create_tar_native_c()`。

### 依赖点 5：TAR/GZ/ZSTD 解压 — 走 /usr/bin/tar

**文件**：`Sources/CTTZipBridge/ttzip_native_archive.c` L197-199

```c
} else if (fmt == TTZIP_NATIVE_FMT_TAR || fmt == TTZIP_NATIVE_FMT_GZ || fmt == TTZIP_NATIVE_FMT_ZSTD) {
    const char* argv[] = { "/usr/bin/tar", "-xf", archive_path, "-C", dest_dir, NULL };
    return ttzip_core_posix_spawn_fast("/usr/bin/tar", argv, NULL);
}
```

**修复**：基于 libarchive API 实现 `ttzip_extract_tar_native_c()`。

---

## 执行计划

### Phase 0：基础加固（无架构变更）

#### 0-A. 移除无用 Entitlements

**文件**：`Sources/TTZipApp/TTZip.entitlements`

移除以下两项（全局搜索确认项目中无 MAP_JIT、PROT_EXEC 或动态代码生成）：
- `com.apple.security.cs.allow-jit`
- `com.apple.security.cs.allow-unsigned-executable-memory`

**预估**：10 分钟

#### 0-B. 密码学原语升级

**文件**：
- `Sources/TTZipCore/Security/PasswordVaultManager.swift`
- `Sources/TTZipCore/Security/PasswordVaultManager+Keychain.swift`

**变更**：
1. KDF 算法：PBKDF2-SHA1 → PBKDF2-SHA256（CryptoKit 原生支持）
2. 盐值策略：固定字符串 `"TTZipVaultSalt2026"` → 每个 Vault 随机生成 32 字节 salt（`SecRandomCopyBytes`）
3. 迭代次数：提升到 600,000（OWASP 2024 推荐值）
4. 文件格式：`password_vault_v3.enc` → `password_vault_v4.enc`
5. Keychain 存储的主密码哈希算法同步升级为 SHA256

**v4 文件头部布局**：
```
[4 bytes: magic "TTV4"]
[4 bytes: iteration count (uint32, big-endian)]
[32 bytes: random salt]
[12 bytes: AES-GCM nonce]
[N bytes: ciphertext + 16 bytes GCM tag]
```

**迁移逻辑**：
1. 启动时检测 v3 文件存在 → 用旧 KDF 解密 → 用新 KDF 重新加密为 v4
2. 迁移成功后删除 v3 文件
3. v3 解密失败时保留原文件，提示用户手动输入主密码重建
4. 单向迁移，不支持降级回 v3

**预估**：3-4 小时

#### 0-C. AppViewState 拆分

**文件**：
- `Sources/TTZipCore/AppViewState.swift`（主改造）
- `Sources/TTZipApp/Views/` 目录下所有引用 AppViewState 的视图文件

**拆分方案**：

```swift
// 1. 导航路由状态
@MainActor final class NavigationState: ObservableObject {
    @Published var activeTab: TabIdentifier = .home
    @Published var sidebarSelection: SidebarItem?
    @Published var inspectorVisible: Bool = true
}

// 2. 归档浏览状态
@MainActor final class ArchiveExplorerState: ObservableObject {
    @Published var currentEntries: [ArchiveTreeNode] = []
    @Published var selectedNodes: Set<ArchiveTreeNode.ID> = []
    @Published var searchQuery: String = ""
    @Published var sortOrder: SortDescriptor<ArchiveTreeNode>?
}

// 3. 任务执行状态
@MainActor final class TaskExecutionState: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var progressValue: Double = 0
    @Published var statusMessage: String = ""
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
}

// 4. 弹窗 / Modal 状态
@MainActor final class OverlayState: ObservableObject {
    @Published var showCompressModal: Bool = false
    @Published var showPasswordPrompt: Bool = false
    @Published var showPreferencesWindow: Bool = false
}
```

`AppViewState` 保留为协调器，持有上述 4 个子状态的引用，负责跨领域编排。视图通过 `@EnvironmentObject` 按需注入。

**视图绑定更新原则**：
- `MainView.swift` — 注入全部 4 个子状态
- `ArchiveExplorerView.swift` — 仅注入 `ArchiveExplorerState` + `TaskExecutionState`
- `CompressModalView.swift` — 仅注入 `TaskExecutionState` + `OverlayState`
- `HomeExplorerContainerView.swift` — 仅注入 `NavigationState`
- 其他视图按实际依赖最小化注入

**预估**：1-2 天

---

### Phase 1：C 引擎能力补全（MAS 上架前置条件）

这是工作量最大、技术风险最高的阶段。目标：消除所有 `posix_spawn` 生产路径。

#### 1-A. TAR 引擎原生化（基于 libarchive）

**新增文件**：`Sources/CTTZipBridge/ttzip_tar_native.c`

```c
// 基于 libarchive 的 in-process TAR 创建
// libarchive 原生支持 tar, tar.gz, tar.bz2, tar.xz 的读写
int ttzip_create_tar_native_c(
    const char* output_path,
    const char* format_flag,    // "tar", "tar.gz", "tar.zst"
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
);

// 基于 libarchive 的 in-process TAR 解压
int ttzip_extract_tar_native_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
);
```

对于 `tar.zst` 创建，保持现有的两步策略（先 libarchive 打 tar，再 libzstd 压缩），只是将第一步从 `/usr/bin/tar` 替换为 libarchive in-process。

**修改文件**：
- `Sources/CTTZipBridge/CTTZipBridge_Archive.c`：`run_tar_create_with_inputs()` 替换为 `ttzip_create_tar_native_c()`
- `Sources/CTTZipBridge/ttzip_native_archive.c`：L197-199 TAR/GZ/ZSTD 解压分支替换为 `ttzip_extract_tar_native_c()`

**预估**：1-2 天（libarchive API 成熟，风险低）

#### 1-B. 7z 引擎补全（LZMA SDK 集成）

**新增文件**：
- `Vendor/lzma-sdk/` — Igor Pavlov 的 LZMA SDK 核心源文件（BSD 许可证）
  - `LzmaDec.c`, `Lzma2Dec.c`, `LzmaEnc.c`, `Lzma2Enc.c`
  - `7zDec.c`, `7zIn.c`, `7zStream.c`
  - `Bcj2.c`, `Bcj2Enc.c`（BCJ/BCJ2 过滤器）
  - `Aes.c`, `AesOpt.c`（AES-256 解密，配合 CommonCrypto）
  - `7z.h`, `7zTypes.h` 等头文件

**修改文件**：

1. `Sources/CTTZipBridge/CTTZipBridge_7zNativeDecoder.c`：
   - 当前 `ttzip_7z_extract_native_parallel_c()` 直接调用 `ttzip_spawn_7zz_extract`
   - 用 LZMA SDK 实现真正的 in-process 7z 解压：LZMA/LZMA2 解码 + BCJ 过滤 + AES-256 解密 + 固实包流式解压

2. `Sources/CTTZipBridge/CTTZipBridge_7z.c`：
   - `ttzip_create_7z_native_c()` 中 `level > 0 || password` 分支：实现 LZMA2 压缩 + AES-256 加密，替代 `ttzip_spawn_7zz_compress`

3. `Sources/CTTZipBridge/include/CTTZipBridge.h`：
   - 新增 in-process 7z 引擎的 C API 声明

**预估**：3-5 天（固实包/AES/BCJ 过滤器复杂度高，技术风险高）

#### 1-C. 加密解压路径修正

**修改文件**：`Sources/CTTZipBridge/ttzip_native_archive.c`

移除 L188-189 的"带密码就走 7zz"逻辑，按格式分发到各自引擎的加密路径：

```c
// 修改前
if (password && password[0] != '\0') {
    return ttzip_spawn_7zz_extract(NULL, archive_path, dest_dir, password);
}

// 修改后：删除上面的全局拦截，让每个格式自己处理密码
ttzip_native_fmt_t fmt = ttzip_detect_format_from_filename(archive_path);
if (fmt == TTZIP_NATIVE_FMT_ZIP) {
    return ttzip_extract_zip_c_parallel(archive_path, dest_dir, skip_mac_junk, password);
} else if (fmt == TTZIP_NATIVE_FMT_7Z) {
    return ttzip_extract_7z_native_c(archive_path, dest_dir, password);
} else if (fmt == TTZIP_NATIVE_FMT_TAR || ...) {
    return ttzip_extract_tar_native_c(archive_path, dest_dir, skip_mac_junk);
}
```

**预估**：2-3 小时

#### 1-D. 验证与清理

- 运行全部 65 个测试文件确认无退化
- 搜索全项目确认生产路径中不再有 `posix_spawn`、`ttzip_spawn_7zz`、`/usr/bin/tar` 调用（仅 Benchmark 路径保留）
- 更新 `ACKNOWLEDGEMENTS.md` 加入 LZMA SDK 许可声明

**预估**：0.5 天

---

### Phase 2：双渠道架构

#### 2-A. 条件编译体系

**修改文件**：`Package.swift`

```swift
// 新增 MAS Target
.executableTarget(
    name: "TTZipApp-MAS",
    dependencies: ["TTZipCore", "CTTZipBridge"],
    path: "Sources/TTZipApp",
    swiftSettings: [
        .define("MAS_BUILD")
    ]
)
```

**预估**：1 小时

#### 2-B. 双 Entitlements

**新增文件**：`Sources/TTZipApp/TTZip-MAS.entitlements`

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
```

**修改文件**：`Sources/TTZipApp/TTZip.entitlements`（独立版，Phase 0-A 已移除 JIT 权限）

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

#### 2-C. RootFolderAccessManager 双模式

**修改文件**：`Sources/TTZipCore/RootFolderAccessManager.swift`

```swift
#if MAS_BUILD
// MAS 模式：精准权限 — 仅请求用户当前操作文件的直接父目录
// 通过 NSOpenPanel 指向 parentDir，生成 App-scope Security Bookmark
func requestAccess(for fileURL: URL) async -> Bool {
    let parentDir = fileURL.deletingLastPathComponent()
    if let bookmark = storedBookmarks[parentDir.path] {
        return restoreAccess(from: bookmark)
    }
    return await promptUserAccess(suggestedDirectory: parentDir)
}
#else
// 独立版：保留现有根目录权限策略（highestRootURL）
#endif
```

#### 2-D. Benchmark 双模式

**修改文件**：

1. `Sources/TTZipCore/ToolchainInstaller.swift`：

```swift
#if MAS_BUILD
// MAS 版本：完全禁用工具链安装功能
public final class ToolchainInstaller: @unchecked Sendable {
    public static let shared = ToolchainInstaller()
    public static let isAvailable = false
    public func install() async throws { throw ToolchainError.unavailableInMAS }
}
#else
// 独立版：移除自动安装，仅保留检测 + 安装指南
// 删除 installSevenZipToolchain() 中的 brew install 逻辑
// 替换为：显示安装命令文本，让用户自行安装
#endif
```

2. `Sources/TTZipCore/CompetitorDetector.swift`：

```swift
#if MAS_BUILD
// MAS 模式：仅探测系统工具和已安装 .app
public func detectAllCompetitors() -> [CompetitorTool] {
    var tools: [CompetitorTool] = []
    
    // 1. 系统工具 (/usr/bin/ditto, /usr/bin/tar)
    // 这些路径在 Sandbox 内可访问
    let dittoPath = "/usr/bin/ditto"
    let tarPath = "/usr/bin/tar"
    
    // 2. 已安装的 .app（通过 NSWorkspace 发现）
    // NSWorkspace.shared.urlForApplication(withBundleIdentifier:)
    // 沙盒允许读取已安装应用的 Bundle 内容
    // → Keka (.app/Contents/MacOS/keka7zz)
    // → BetterZip (.app/Contents/Helpers/7za)
    // → The Unarchiver 等
    
    return tools
}
#else
// 独立版：保留现有全路径扫描逻辑
// (PATH + /opt/homebrew + extraPaths)
#endif
```

3. `Sources/TTZipApp/Views/Benchmark/BenchmarkViewModel.swift`：

```swift
#if MAS_BUILD
// 隐藏"安装竞品"按钮
// 替换为"安装指南"链接
// Benchmark 仅对已检测到的工具可用
#else
// 移除自动安装，替换为安装指南 + 检测已安装工具
#endif
```

#### 2-E. Quarantine 清理条件化

**修改文件**：涉及 `removexattr("com.apple.quarantine", ...)` 的代码

```swift
#if !MAS_BUILD
cleanupQuarantineAttributes(at: url)
#endif
```

**预估**：Phase 2 整体 1-2 天

---

### Phase 3：分发基础设施

#### 3-A. Sparkle 自动更新（仅独立版）

**修改文件**：`Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
],

// 仅独立版 Target 依赖 Sparkle
.executableTarget(
    name: "TTZipApp",
    dependencies: [
        "TTZipCore", "CTTZipBridge",
        .product(name: "Sparkle", package: "Sparkle")
    ]
)
```

**新增文件**：`Sources/TTZipApp/Updates/SparkleUpdateManager.swift`

```swift
#if !MAS_BUILD
import Sparkle

final class SparkleUpdateManager: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    var updater: SPUUpdater { updaterController.updater }
}
#endif
```

MAS 版本由 App Store 托管更新。

**预估**：0.5 天

#### 3-B. CI/CD 配置（不启用自动触发）

**修改文件**：`.github/workflows/ci.yml`

```yaml
name: TTZip CI

on:
  workflow_dispatch:   # 保持手动触发
  # push:             # 预留，暂不启用
  # pull_request:     # 预留，暂不启用

jobs:
  build-and-test:
    runs-on: macos-15
    strategy:
      matrix:
        scheme: [TTZipApp, TTZipApp-MAS]
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.0'
      - name: Build (${{ matrix.scheme }})
        run: swift build -c release
      - name: Test
        run: swift test --parallel

  # 预留 Release 步骤（暂不启用）
  # release:
  #   if: startsWith(github.ref, 'refs/tags/')
  #   needs: build-and-test
  #   steps:
  #     - name: Archive & Sign (Independent)
  #       run: xcodebuild archive ...
  #     - name: Notarize (Independent)
  #       run: xcrun notarytool submit ...
  #     - name: Upload to App Store Connect (MAS)
  #       run: xcrun altool --upload-app ...
```

**预估**：2-3 小时

---

### Phase 4：长期优化（可独立排期）

#### 4-A. Swift 6 结构化并发深化

将 `Task { @MainActor in }` 手动保护模式升级为编译器驱动的 actor 隔离：

```swift
// 现状
onProgressUpdated = { progress in
    Task { @MainActor in
        self.progressValue = progress
    }
}

// 目标
@MainActor
func updateProgress(_ progress: Double) {
    self.progressValue = progress
}
```

利用 Sendable 检查替代运行时的 Task 切换。

#### 4-B. SwiftUI 树形列表性能监测

每个 macOS 大版本发布后，评估原生 `List` + `OutlineGroup` 在 10 万+ 节点场景下的性能。一旦追平 `NSOutlineView`，移除 `NativeArchiveOutlineView` 的 AppKit 桥接。

当前判断：保持 NSOutlineView。SwiftUI 的树形列表在大数据集场景下仍无法竞争。

---

## 工作量总览

| Phase | 工作项 | 预估 | 技术风险 |
|-------|--------|------|----------|
| 0-A | 移除无用 entitlements | 10min | 无 |
| 0-B | 密码学升级（PBKDF2-SHA256 + 随机盐 + 迁移） | 3-4h | 低 |
| 0-C | AppViewState 拆分 | 1-2d | 中 |
| 1-A | TAR 原生化（libarchive） | 1-2d | 低 |
| **1-B** | **7z 引擎补全（LZMA SDK）** | **3-5d** | **高** |
| 1-C | 加密解压路径修正 | 2-3h | 低 |
| 1-D | 验证与清理 | 0.5d | 低 |
| 2-A~E | 双渠道条件编译 + Benchmark 双模式 | 1-2d | 中 |
| 3-A | Sparkle 集成 | 0.5d | 低 |
| 3-B | CI/CD 配置 | 2-3h | 低 |
| **总计** | | **10-15 工作日** | |

**关键路径**：Phase 1-B（LZMA SDK 集成）是整个计划的最高风险和最长耗时项。

---

## 执行顺序

```
Phase 0（基础加固）
  └─ 0-A 移除无用 entitlements
  └─ 0-B 密码学升级
  └─ 0-C AppViewState 拆分

Phase 1（C 引擎补全）← 关键路径
  └─ 1-A TAR 原生化
  └─ 1-B 7z 引擎补全
  └─ 1-C 加密解压路径修正
  └─ 1-D 验证与清理

Phase 2（双渠道架构）
  └─ 2-A 条件编译体系
  └─ 2-B 双 Entitlements
  └─ 2-C RootFolderAccessManager 双模式
  └─ 2-D Benchmark 双模式
  └─ 2-E Quarantine 条件化

Phase 3（分发基础设施）
  └─ 3-A Sparkle 自动更新
  └─ 3-B CI/CD 配置
```

Phase 内部各项可并行。Phase 之间严格串行（下一个 Phase 依赖上一个 Phase 的产出）。

---

## 验证计划

### 自动化测试

```bash
# Phase 0 验证
swift test --filter PasswordVault        # 密码学升级 + v3→v4 迁移
swift test --filter AppViewState         # 状态拆分不破坏现有行为

# Phase 1 验证
swift test --filter ArchiveReader        # 引擎 fallback 路径
swift test --filter TarNative            # TAR 原生引擎
swift test --filter LzmaEngine           # LZMA SDK 7z 引擎
swift test --filter ArchiveExtractor     # 加密解压
swift test                               # 全量回归

# Phase 2 验证
swift build -c release                                  # 独立版构建
swift build -c release -Xswiftc -DMAS_BUILD             # MAS 版构建
swift test --filter RootFolderAccess                    # 权限管理
swift test --filter CompetitorDetector                  # 竞品探测
```

### 手动验证

- 独立版：全部功能不退化，Benchmark 仅检测已安装工具（不自动安装）
- MAS 版：在 Sandbox 环境下执行打开 → 浏览 → 解压 → 压缩完整流程
- 使用 `.7z`（含加密/固实）和 `.rar` 文件验证 in-process 引擎
- MAS 版 Benchmark：确认仅探测系统工具 + 已安装 .app
- 提交 TestFlight 验证 MAS 审核合规性
- 独立版 Sparkle 更新流程端到端验证
