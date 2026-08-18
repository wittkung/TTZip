# 多仓库与跨语言分层架构组织指南 (Repository Layout & Multi-Tier Architecture Blueprint)

> **文档版本**: 1.0.0 | **创建日期**: 2026-08-16 | **分析基线**: TTZip / libarchive upstream / Swift 6 SPM  
> **适用范围**: TTZip 仓库组织、跨语言 C/Swift 边界治理、上游开源依赖隔离及基础设施库演进

---

## 目录
1. [多层架构组织愿景与核心原则](#1-多层架构组织愿景与核心原则)
2. [4 层物理分层架构拓扑](#2-4-层物理分层架构拓扑)
3. [C 桥接层头文件门面与 Modulemap 隔离规范](#3-c-桥接层头文件门面与-modulemap-隔离规范)
4. [Pristine Upstream 依赖治理与 Git Worktree 补丁 SOP](#4-pristine-upstream-依赖治理与-git-worktree-补丁-sop)
5. [Swift 6 严格并发与多渠道分发构建隔离](#5-swift-6-严格并发与多渠道分发构建隔离)
6. [多仓库拆分与演进路线图](#6-多仓库拆分与演进路线图)

---

## 1. 多层架构组织愿景与核心原则

在涉及底层高性能 C 静态库、硬件向量加速（NEON / AES）与高层现代化 UI（SwiftUI / AppKit）的复杂工程中，混乱的代码组织会导致：
- **上游代码污染**：本地业务修改与上游官方源码混杂，导致无法平滑升级 upstream 版本，且向上游提交 PR 极其繁重。
- **头文件与符号泄漏**：内部未受保护的私有 C 结构体和宏暴露给 Swift，破坏编译边界与沙盒约束。
- **并发与内存安全失控**：C 裸指针无序逃逸至 Swift 异步 Task，引发数据竞争与野指针。

**三大组织原则**：
1. **单向物理依赖 (Strict Unidirectional Dependency)**：高层依赖低层，严禁任何逆向或跨层穿透依赖。
2. **纯净上游隔离 (Pristine Upstream Isolation)**：官方 upstream 代码树保持 100% 原生结构，零业务代码污染。
3. **门面收敛 (Facade-Enforced Boundaries)**：每一层仅通过唯一的公共门面（Header / Modulemap / Facade Class）向外暴露安全契约。

---

## 2. 4 层物理分层架构拓扑

```
┌──────────────────────────────────────────────────────────────────┐
│ Layer 3: Presentation & CLI Layer                                │
│   - Sources/TTZipApp/ (SwiftUI, MVVM, AppViewState, @MainActor)  │
│   - Sources/TTZipCLI/ (ttzip-cli 基准测试与管道验证工具)          │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ 仅依赖 Swift Core Engine
┌─────────────────────────────────▼────────────────────────────────┐
│ Layer 2: Swift 6 Core Engine Layer                               │
│   - Sources/TTZipCore/ (归档管道、28 大设计模式、密码库 v4、      │
│     Zip/7z 编解码调度、安全扫描、Sendable 并发流)                  │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ module.modulemap 纯 C ABI
┌─────────────────────────────────▼────────────────────────────────┐
│ Layer 1: C Bridge & SIMD Hardware Acceleration Layer             │
│   - Sources/CTTZipBridge/ (Thin Wrappers, POSIX 适配器,          │
│     Apple Silicon NEON / AES SIMD 加速内核, CPU 动态分发表)      │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ 静态链接 / 隔离 Worktree
┌─────────────────────────────────▼────────────────────────────────┐
│ Layer 0: Pristine Upstream & Pre-built Vendor Static Libraries   │
│   - Vendor/libarchive-upstream/ (官方干净 git worktree / master) │
│   - Vendor/lib/*.a & Vendor/include/ (预编译 Universal 静态库)   │
└──────────────────────────────────────────────────────────────────┘
```

### 分层职责矩阵

| 层级 | 路径 | 核心职责 | 允许依赖 | 禁止行为 |
| :--- | :--- | :--- | :--- | :--- |
| **Layer 3** | `Sources/TTZipApp/`<br>`Sources/TTZipCLI/` | UI 渲染、用户交互、CLI 命令解析、进度观察者绑定。 | Layer 2 | 严禁直接 `#import CTTZipBridge` 或包含 C 裸指针。 |
| **Layer 2** | `Sources/TTZipCore/` | 业务管道编排、设计模式体系、并发任务调度、安全断言、错误映射。 | Layer 1 | 严禁在并发热路径内部加锁或执行堆分配。 |
| **Layer 1** | `Sources/CTTZipBridge/` | POSIX 桥接、C 指针生命周期收敛、NEON SIMD 硬件指令加速、微缓冲直通。 | Layer 0 | 严禁在 C 桥接层输出裸 `printf`/`NSLog` 日志。 |
| **Layer 0** | `Vendor/libarchive-upstream/`<br>`Vendor/lib/` | 官方原生归档解压引擎、压缩算法静态库（liblzma, libzstd 等）。 | 无外部依赖 | 严禁在 upstream 源码树中引入 TTZip 专有文件。 |

---

## 3. C 桥接层头文件门面与 Modulemap 隔离规范

### 3.1 严格的头文件分类
- **公共门面头文件 (`Sources/CTTZipBridge/include/CTTZipBridge.h`)**：
  - 仅暴露经过安全包装的 C API。
  - 所有导出的函数参数必须采用标准 C 类型（`const uint8_t *`, `size_t`, `int64_t`）。
- **内部私有头文件 (`Sources/CTTZipBridge/*.h`)**：
  - 放置于 `include/` 目录外部（如 `CTTZipBridge_Internal.h`）。
  - 包含 NEON 向量内联函数、底层状态机宏及私有结构体定义。

### 3.2 SPM `module.modulemap` 最小暴露原则
```c
module CTTZipBridge {
    header "include/CTTZipBridge.h"
    export *
}
```
- **红线**：严禁在 `modulemap` 中使用 `umbrella header` 将 `Vendor/include/` 下的数十个第三方私有头文件（如 `archive_read_private.h`）全量暴露给 Swift。

---

## 4. Pristine Upstream 依赖治理与 Git Worktree 补丁 SOP

### 4.1 Git Worktree 纯净隔离流
为同时满足“保持 upstream 纯净”与“为官方开发贡献 Patch”：

```bash
# 1. 在 Vendor/worktrees 下检出干净的 upstream 开发工作树
git worktree add Vendor/worktrees/libarchive-feat upstream/master

# 2. 在该工作树中遵循 [infra] -> [feat] -> [test] 开发
cd Vendor/worktrees/libarchive-feat
git checkout -b feat/my-optimization

# 3. 提交前进行物理纯净度断言
git diff upstream/master..HEAD --stat
```

### 4.2 Patch 导出与本地静态库重编
1. **生成格式化 Patch**：`git format-patch upstream/master --stdout > patches/libarchive-001.patch`
2. **应用 Patch 构建静态库**：由 `./scripts/build_vendor_libs.sh` 脚本在独立编译目录应用 Patch 并构建 Universal `.a` 放置于 `Vendor/lib/`。

---

## 5. Swift 6 严格并发与多渠道分发构建隔离

### 5.1 Swift 6 Sendable 跨边界不变量
- 从 C 桥接层返回的句柄在 Swift 侧封装为 `final class NativeHandle: @unchecked Sendable` 时，其内部可变状态必须通过 `NSLock` 保护。
- 零拷贝微缓冲区指针在 Swift 中以 `UnsafeRawBufferPointer` 形式传递，其生命周期严格由 `withUnsafeBytes` 闭包管理，禁止逃逸。

### 5.2 渠道条件编译隔离
- **MAS 沙盒分发 (`-DMAS_BUILD`)**：
  - 严格剥离 Sparkle 自动更新依赖（`#if !MAS_BUILD`）。
  - 严格遵循 App Sandbox 权限与安全书签（Security-Scoped Bookmarks）。
- **Direct 独立分发**：
  - 激活 Sparkle 2.0 自动更新流水线。

---

## 6. 多仓库拆分与演进路线图

随着系统成熟，可进一步演进为模块化 Monorepo 或多仓库拓扑：

1. **`libarchive-apple-simd` (独立开源贡献仓库)**：
   - 专门存放针对 Apple Silicon ARM NEON / Crypto 扩展优化的 upstream PR 分支。
2. **`TTZipCore` (系统级通用 Swift 归档框架)**：
   - 包含设计模式体系、微缓冲管道与安全防御矩阵，支持 macOS / Linux / iOS 多平台集成。
3. **`TTZipDesktop` (macOS 桌面客户端)**：
   - 纯粹的 UI 视图与交互层，专注于 Kintsugi Gold 视觉设计与 NSOutlineView 极速渲染。
