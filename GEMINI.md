# TTZip — 项目级 AI 执行规则 (Project-Level Agent Rules)

> 本文件在每次对话中无条件注入，作为 AI 协作的最高优先级项目上下文。

---

## 一、 项目概况

TTZip 是面向 macOS 14+ (Sonoma) 的高性能原生归档与压缩解压工具。

| 维度 | 规格 |
| :--- | :--- |
| 语言 | Swift 6.0 (`swift-tools-version: 6.0`) + C11/POSIX |
| 平台 | macOS 14.0+ (Apple Silicon 优先，兼容 Intel) |
| UI 框架 | SwiftUI + AppKit (NSOutlineView 桥接) |
| 底层引擎 | 100% In-Process C 静态库绑定（零外部 CLI 进程调用） |
| 分发渠道 | Mac App Store (MAS 沙盒，`-DMAS_BUILD`) + Direct 独立分发 (Sparkle 2.0) |
| 仓库 | `git@github.com:wittkung/TTZip.git`，主分支 `main` |

### 支持的归档格式

- **完整压缩与解压**：ZIP、7Z、TAR、ZSTD、GZIP、BZIP2、XZ、LZIP、LZ4、BROTLI、LRZIP、AAR、SNAPPY、WIM、DMG、ISO
- **解压与穿透浏览**：RAR/CBR、ZipX、CAB、分卷归档 (.001/.7z.001/.zip.001/.rar.001)

---

## 二、 模块架构

```
TTZip/
├── Sources/
│   ├── CTTZipBridge/      # C 底层桥接：libarchive / libdeflate / LZMA SDK / zstd / ARM NEON SIMD 加解密
│   ├── TTZipCore/         # Swift 核心引擎：归档管道、设计模式体系、Benchmark、密码库 v4、安全扫描
│   ├── TTZipApp/          # SwiftUI + AppKit 桌面应用 (MVVM + @MainActor)
│   └── TTZipCLI/          # 命令行基准测试与管道验证工具 (ttzip-cli)
├── Tests/TTZipTests/      # 80+ 测试源文件，覆盖模式、引擎、安全、性能回归
├── Vendor/                # 预编译 C 静态库：libarchive.a, liblzma.a, liblz4.a, libb2.a, libzstd.a, libdeflate.a, uchardet
├── scripts/               # 构建与测试脚本
└── .github/workflows/     # CI/CD (GitHub Actions, macos-14, workflow_dispatch)
```

### 依赖关系

```
TTZipApp ──→ TTZipCore ──→ CTTZipBridge ──→ Vendor/*.a + 系统库 (bz2, z, iconv, xml2, expat, libc++)
   └──→ Sparkle (v2.6.0, Direct 渠道专用)
```

---

## 三、 构建与测试命令

```bash
# 构建
swift build                                    # Debug
swift build -c release                         # Release (Direct)
swift build -c release -Xswiftc -DMAS_BUILD    # Release (MAS 沙盒)

# 测试
swift test                                     # 全量单元测试 (525+ tests)
swift test --filter XCTestPerformanceMeasureTests  # 性能门禁测试

# 基准测试
swift run ttzip-cli bench -f zip               # ZIP 格式全矩阵基准
swift run ttzip-cli bench -f 7z                # 7Z 格式全矩阵基准
TTZIP_RUN_BENCHMARKS=1 swift test --filter ZipBenchPkTests  # 竞品 1v1 PK

# 构建脚本
./scripts/run_all_tests.sh                     # 全套自动化回归
./scripts/build_direct.sh                      # Direct 渠道打包
./scripts/build_mas.sh                         # MAS 渠道打包
```

---

## 四、 性能铁律 (Performance Invariants)

> 本节为最高优先级执行铁律。任何代码变更在合并前必须满足以下全部约束。

### 1. 热路径零成本抽象 (Zero-Cost Abstraction on Hot Paths)

以下路径为编解码与 I/O 核心热路径，必须保证 **零中间堆分配、零冗余系统调用、零动态对象树构建**：

- `Sources/TTZipCore/Zip/` 下所有并行压缩/解压/流式写入器
- `Sources/CTTZipBridge/CTTZipExtract.c`（C 解压引擎）
- `Sources/CTTZipBridge/CTTZipBridge_Crypto.c`（AES-256 SIMD 加解密）
- `Sources/CTTZipBridge/CTTZipBridge_ZipWrite*.c`（C 压缩写入器）
- `Sources/CTTZipBridge/ttzip_lzma2_*.c`（LZMA2 编解码器）
- `Sources/TTZipCore/Zip/ZipDirectoryScanner.swift`（目录扫描器）

**禁令**：

- 严禁在上述热路径中引入 Composite / Visitor / Decorator 等模式的动态分配对象（如 `ArchiveComponentTree`、`ArchiveComponentVisitor`）。
- 严禁在 GCD / Task 并发任务内部执行 per-file 的 `malloc` / `free`（如每文件创建/销毁 `libdeflate_decompressor`），必须使用线程局部缓存或对象池。
- 严禁为了"统一抽象"将已调优的格式专属 Fast-Path 降级为通用慢路径。

### 2. Fast-Path 旁路保留原则

任何架构分发器（Template Method / Strategy / Bridge / Abstract Factory）必须显式保留格式专属与硬件特化的 Fast-Path 旁路：

- ZIP 加密解压必须直通原生 C 引擎 `ttzip_extract_zip_c_parallel`，不得经由 7z 引擎中转。
- Apple Silicon SIMD 加速路径不得被通用 fallback 覆盖。

### 3. 吞吐硬门禁 (Hard Performance Floor)

修改涉及 `Sources/TTZipCore/` 或 `Sources/CTTZipBridge/` 的代码后，必须执行 `swift test --filter XCTestPerformanceMeasureTests` 验证以下底线全部达标：

| 场景 | 吞吐底线 / 耗时上限 |
| :--- | :--- |
| ZIP Level 1 压缩 (10MB) | >= 1500 MB/s (Debug) / >= 2000 MB/s (Release) |
| ZIP Level 1 压缩 (50MB 单文件) | >= 1700 MB/s (Debug) / >= 2100 MB/s (Release) |
| ZIP Level 6 压缩 (10MB) | >= 1100 MB/s (Debug) / >= 1350 MB/s (Release) |
| ZIP 解压 | >= 7500 MB/s (Debug) / >= 10000 MB/s (Release) |
| ZIP Store Direct I/O | >= 6000 MB/s (Debug) / >= 7500 MB/s (Release) |
| 7Z Level 1 极速压缩 (10MB) | >= 3200 MB/s (Debug) / >= 3900 MB/s (Release) |
| 7Z 极速解压 | >= 6600 MB/s (Debug) / >= 7200 MB/s (Release) |
| 7Z 压缩 (LZMA2 Level 5) | >= 480 MB/s (Debug) / >= 620 MB/s (Release) |
| 批量小文件压缩 (500 文件) | >= 50 MB/s (Debug) / >= 70 MB/s (Release) |
| TAR.ZST Direct 打包 (50MB) | >= 15000 MB/s (Debug) / >= 22000 MB/s (Release) |
| LZ4 进程内流式压缩 (10MB) | >= 6000 MB/s (Debug) / >= 10000 MB/s (Release) |
| TAR.XZ 多核流式打包 (10MB) | >= 1200 MB/s (Debug) / >= 1800 MB/s (Release) |
| 7Z AES-256 KDF 硬件派生耗时 | <= 17 ms (Debug) / <= 15 ms (Release) |

**跌破任一底线 = 测试红灯 = 阻断合并。严禁在后续任何修改中私自下调上述门禁阈值。**


### 3.1 全格式历史最优硬性能门禁全覆盖矩阵 (Full-Matrix Historical Peak Floor Matrix)

全格式 46 项基准测试覆盖全部 16 种格式（共 262 项细分维度），其门禁标准 100% 严格基于历史最优基准 `604d44d`（`docs/benchmarks/benchmark_report_2026-08-15_071939.json`）设定，任何格式的任何场景发生真实性能倒退（$\Delta < -10.0\%$）即阻断流水线：

| 格式 (Format) | 历史最优压缩峰值 (Peak Comp) | 历史最优解压峰值 (Peak Extract) | 门禁细分维度数 |
| :--- | :--- | :--- | :--- |
| **ZIP** | >= 8,381.5 MB/s | >= 12,721.9 MB/s | 32 项 |
| **7Z** | >= 28,926.3 MB/s | >= 10,683.6 MB/s | 32 项 |
| **TAR** | >= 12,437.0 MB/s | >= 12,665.0 MB/s | 32 项 |
| **TAR.ZST** | >= 25,773.3 MB/s | >= 10,058.3 MB/s | 12 项 |
| **TAR.GZ** | >= 16,263.5 MB/s | >= 7,623.2 MB/s | 16 项 |
| **TAR.BZ2** | >= 16,715.8 MB/s | >= 6,020.7 MB/s | 16 项 |
| **TAR.XZ** | >= 5,159.6 MB/s | >= 4,764.7 MB/s | 16 项 |
| **WIM** | >= 12,581.0 MB/s | >= 13,069.5 MB/s | 24 项 |
| **DMG** | >= 5,884.4 MB/s | >= 12,898.1 MB/s | 30 项 |
| **LZ4** | >= 18,960.7 MB/s | >= 4,108.1 MB/s | 16 项 |
| **LZIP** | >= 5,180.1 MB/s | >= 1,876.4 MB/s | 16 项 |
| **LRZIP** | >= 5,143.1 MB/s | >= 1,087.1 MB/s | 16 项 |
| **AAR** | >= 2,109.8 MB/s | >= 2,163.5 MB/s | 4 项 |
| **ISO** | >= 2,024.8 MB/s | >= 1,537.5 MB/s | 4 项 |
| **BROTLI** | >= 1,903.5 MB/s | >= 2,054.5 MB/s | 16 项 |
| **SNAPPY** | >= 4,500.0 MB/s | >= 4,500.0 MB/s | 4 项 |

### 4. 设计模式热路径隔离原则 (Hot-Path Pattern Isolation)

任何设计模式（Flyweight / Composite / Visitor / Decorator / Observer / Command 等）的使用边界严格限制在调度层（Template Method 骨架、Strategy 分发）与冷路径（UI 树构建、错误收集），**严禁侵入数据平面与并行循环体内部**：

- 严禁在 `DispatchQueue.concurrentPerform` 或 GCD 并发闭包内部调用任何涉及 `NSLock` / `DispatchSemaphore` / `pthread_mutex` 的共享享元池或单例模式。
- 严禁在压缩/解压热循环中对单文件分配做任何基于 `Data(count:)` 的内核零填充初始化，必须使用零初始化的裸指针 `UnsafeMutablePointer<UInt8>.allocate(capacity:)` 或栈上固定缓存。
- 严禁在已通过并发调优的路径上额外叠加信号量节流（`DispatchSemaphore`）引入无谓的内核系统调用。

### 5. 前端与 UI 渲染硬性能门禁 (Frontend & UI Hard Performance Floor)

修改涉及 `Sources/TTZipApp/`、前端状态管理或视图缓存调度后，必须执行 `swift test --filter FrontendPerformanceGateTests` 验证以下底线全部达标：

| 场景 | 吞吐底线 / 耗时上限 (Debug) |
| :--- | :--- |
| 1,000 节点目录树构建 | <= 10.0 ms |
| 10,000 节点目录树构建 | <= 60.0 ms |
| 50,000 节点目录树构建 | <= 250.0 ms (>= 250,000 items/s) |
| 20,000 条目实时搜索过滤 | <= 30.0 ms (>= 750,000 items/s) |
| 10,000 次 LRU 缓存存取 | <= 8.0 ms (>= 1,500,000 ops/s) |
| 高频微秒级进度事件拦截率 | >= 97.0% (派发收敛在 <= 60Hz) |


---

## 五、 代码修改纪律

### 1. 冻结文件

以下文件处于完全冻结状态，严禁修改任何逻辑或结构（详见 `.agents/rules/zip-engine-freeze.md`）：

- `ZipParallelExtractor.swift`、`ZipParallelWriter.swift`、`ZipCryptoEngine.swift`
- `ZipBlockParallelCompressor.swift`、`ZipBlockParallelDecompressor.swift`
- `ZipCentralDirectoryReader.swift`、`ZipStoreStreamWriter.swift`
- `CTTZipBridge_Crypto.c`、`CTTZipBridge_Crypto.h`、`CTTZipExtract.c`

解除冻结需用户在 Prompt 中显式包含 `FORCE UNFREEZE ZIP`。

### 2. C 桥接层安全规范

- 所有 C 指针操作必须经由 `CUnsafeBufferAdapter.withBufferPointer(data)` 中枢，严禁裸解引用。
- `NativeCoreArchitecture` 中 `allocateAlignedPageBuffer` 与 `deallocateAlignedPageBuffer` 必须成对调用。

### 3. 线程安全

- UI 更新必须在 `@MainActor` 上执行。
- 重型 I/O 和压缩任务使用 `Task.detached(priority: .userInitiated)`。
- `ArchiveOperationAbstraction`（Bridge 模式）已加 `NSLock`，操作前必须先快照 `let currentImpl = implementor`。

---

## 六、 设计模式约束

TTZip 践行 28 大设计模式（详见 `.agents/skills/design-patterns-guide/SKILL.md`）。以下为性能敏感场景的强制约束：

| 模式 | 允许使用范围 | 严禁使用范围 |
| :--- | :--- | :--- |
| Composite / Visitor | UI 树形渲染、异步文件树分析、归档内容浏览 | `ZipDirectoryScanner` 等压缩扫描器的热路径 |
| Decorator | 上层操作叠加（加密、进度、校验码） | C 桥接层字节流处理内部 |
| Flyweight | 字符串享元、内存页缓冲区池 | 复用池外包装 `Data(bytes:)` 二次拷贝、并发压缩闭包内加锁借还 |
| Template Method | 归档骨架工作流 | 必须支持 inline Fast-Path 提前短路，禁止强制走满全部 hook |
| Builder | 管道构建、命令构建 | `struct` Builder setter 必须捕获返回值：`builder = builder.withX(y)` |

---

## 七、 AI 执行守则

1. **渠道条件编译**：涉及 Sparkle、自动更新等 Direct 渠道专属功能，必须包裹在 `#if !MAS_BUILD` 条件编译中。
2. **IME 兼容性**：Popover 和 Sheet 中严禁使用 `SecureField`（会导致 macOS TSM 中文输入法全局阻塞）。
3. **性能优化四步闭环铁律 (Four-Step Performance Optimization Closed-Loop Protocol)**：
   - 任何涉及算法调优、SIMD 硬件加速、编解码吞吐优化或底层 C 库改造的任务，**必须无条件执行以下四步标准化闭环，严禁在未见基线前盲目改动代码**：
     1. **步骤一 · 明确涉及范围 (Scope Demarcation)**：在动工前，显式向用户列出拟优化的模块边界、具体代码文件、涉及的硬件架构指令集、数据流动路径以及上下游影响范围。
     2. **步骤二 · 优化前基线实测 (Pre-Optimization Baseline Measurement)**：在修改任何代码前，必须先执行基准测试或微基准测试（如 `HybridMatchFinderMicroTests`、`XCTestPerformanceMeasureTests` 或 `AllFormatsPkSuiteTests`），真实捕获并向用户呈现优化前的物理吞吐（MB/s / ops/s / ms）基线表。
     3. **步骤三 · 精准架构实施 (Targeted Implementation & Hardening)**：严格遵循热路径零内存分配、无锁并发与架构契约，落地向量化与硬件指令优化。
     4. **步骤四 · 优化后差分比对与零倒退审查 (Post-Optimization Differential Audit & Zero-Regression Verification)**：运行同套基准测试，在对话中完整输出**优化前 vs 优化后逐项数据对比表**（包含优化前 MB/s、优化后 MB/s、增益比例 $\Delta\%$、🟢 提升项、⚪ 持平项与 🔴 倒退告警项）。若核心场景发生真实性能倒退（$> 3.0\%$），必须立刻定位根因并修复/回滚，绝对禁止带病合并。
4. **外部开源社区协作与 PR 显式授权硬闸门 (Upstream Community Remote Action Hard Gate)**：
   - **本工程仓库自治**：TTZip 自身仓库（`wittkung/TTZip`）内部的本地代码迭代、Git Commit 与常规流水线正常推进，无需反复停顿阻断。
   - **外部社区仓库绝对零静默写操作**：凡涉及外部开源基础库（如 `Vendor/libarchive-upstream`、libarchive 官方 Issue/PR、GitHub 社区公开仓库等）的 `git push`、`gh pr create`、`gh pr comment`、`gh issue comment` 等具有远端公开状态变更副作用的操作，**必须在主对话中向用户完整呈现拟提交的 Commit 结构、Diff 清单与 PR/Comment 回复草稿，并在获得用户明确授权后方可执行**，严禁擅自向外部社区仓库提交代码或发表评论。

5. **严格开源上游贡献与 PR 审查硬门禁 (Mandatory Upstream Contribution Guardrails)**：
   - 凡涉及向外部开源库（如 `Vendor/libarchive-upstream`、`Vendor/zstd-upstream` 等）提交 Patch 或 PR，必须无条件遵循 `.agents/skills/upstream-contribution/SKILL.md` 与 `.agents/skills/code-review/SKILL.md`：
     1. **Git 纯净分支隔离**：必须从 upstream 官方 `master` 或 `dev` 纯净检出，提交前必须执行 `git diff upstream/<branch>..HEAD --stat` 物理断言零无关文件污染。
     2. **原子 Commit 序列**：严格按照 `infra` -> `feat` -> `test` 拆分 commit，保证每个 commit 独立可二分编译（`git bisect` 友好）。
     3. **跨架构整型与流式安全**：所有 64-bit 偏移量转 `size_t` 必须经过 32 位 clamp 保护；所有 `read_ahead` 必须对 NULL 和短读取防御；所有 `consume` 必须检查返回值。
     4. **原生预言机对齐**：测试必须使用项目原生黄金预言机（如 `bitcrc32()` 或 `tests/fuzzer.c`），严禁使用外部硬编码常量。
     5. **双构建系统全量物理验证与原型确界 (Dual-Build System & Missing-Prototypes Mandate)**：必须在本地同时通过 CMake 严格模式（`-DCMAKE_C_FLAGS="-Wmissing-prototypes -Wall -Wextra"`）和 GNU Autotools 模式（`./build/autogen.sh && ./configure && make`）的双向物理编译验证，断言 `Makefile.am` 与 `CMakeLists.txt` 源文件列表 100% 同步；所有新建 `.c` 必须显式包含声明其原型的内部私有头文件（防 `-Wmissing-prototypes` 报错）；mdoc man page 已通过 `doc/update.sh` 验证派生。
     6. **重构减法断言与内部排版注释 (Preprocessor Block Placement)**：从头文件重构为独立 `.c` 时必须剔除无用的 `push/pop` 宏等残留作用域防御；所有条件编译分支（`#if` / `#elif` / `#else`）的说明注释**必须写在预处理块内部紧随其后**，严禁放在宏外部。
     7. **反配置膨胀与默认透明行为 (Zero Configuration Creep)**：基础库严禁随意新增公开 Option Flag 把决策甩给调用方；凡是库内部可以通过客观条件（如 $\ge 64\text{KB}$ 阈值、非稀疏、普通文件）安全判定的，必须以内置启发式透明默认执行。
     8. **敏感内存防死存储消除 (Dead-Store Elimination Immunity)**：密码与密钥缓冲区释放前，严禁依赖普通 `memset`，必须使用 `volatile` 函数指针（如 `secure_zero_memory` / `memset_v`）强制物理擦除。
     9. **流程敬畏与 Draft 隔离 (Issue-First & Draft Isolation)**：架构存在分歧时，讨论重心必须收敛在 Issue 中；未达成共识前 PR 必须挂起为 Draft，绝不抢跑推送发散代码。
     10. **跨架构确定性不可侵犯 (Determinism Invariant Immunity)**：除专用自研格式外，通用基础库优化绝不改变跨架构哈希索引与序列生成逻辑，保证 `.zst` 等二进制比特流 100% 跨平台幂等。
     11. **物理实测真实性断言 (Grounded Benchmarking Mandate)**：所有 Benchmark 数据均为物理单调时钟实测并标明 CPU 型号、核心数、RAM、OS、文件系统、编译器版本与 `-O3` 优化标志，严禁理论推演充当实测数据。
     12. **形式化数学与边界安全证明 (Formal Boundary & Invariant Proofs)**：必须给出模对齐、步长收敛与残差集合推导，证明零越界、零欠读。
     14. **无构建系统裸编译通过性 (Direct Compilation Immunity)**：必须通过 `$CC -Wall -Werror lib/*.c programs/*.c` 直接编译验证，系统库（pthread/m）必须有条件编译宏防护，脱离 CMake 时透明降级为单线程。
     15. **解压与消费侧语义闭环 (Decompression Semantic Symmetry)**：贡献流式/容器压缩特性时，必须闭环阐明标准解压器（gzip/tar）透传与库原生 API 在应用层的循环消费语义。
     16. **栈上配置结构体显式确定性 (Stack Struct Zero-Garbage Guarantee)**：扩展 CLI 命令行选项时，必须显式在 `tmain` 入口初始化结构体默认字段，严禁读取未初始化的栈内存。
     17. **Markdown 纯文本排版防御 (Plain-Text Formatting Immunity)**：PR 描述中公式与内存量一律使用纯文本（`≈ 4 MB`, `W / C`），避免 LaTeX 语法；致谢必须包裹在 Blockquote 中。
     18. **注释-代码双向语义确界铁律 (Bi-directional Comment-Code Semantic Invariant)**：凡从既有模块（如 x86）移植/重构算法或调整操作符时，必须逐句清空并重新推导自然语言描述，严禁保留被替代旧算法的废弃动词（如 shift vs mask、left vs right 混淆）。每次 Review 必须双向断言：函数名、参数名、动词与底层指令在语义和物理行为上 100% 绝对一致。
     19. **特性探测分支全路径逻辑与逆向注入断言 (Feature Detection Strict Logic & Fault Injection)**：任何运行时 CPU 特性探测函数（如 `is_arch_extension_supported`），返回值必须直接布尔绑定系统调用探测结果（如 `return has_feature != 0;`），绝对禁止在 `if` 探测结构外部残留任何硬编码的 `return true;` 伪兜底。审查时必须进行逆向思维测试（Fault Injection 断言）：假设硬件探测失败或不支持该特性，逻辑是否 100% 能够安全返回 `false` 并无缝回退到通用基准。
     20. **零依赖单文件基准与科学可复现性交付 (Zero-Dependency Standalone Reproducibility Standard)**：凡在 PR 或 Issue 中声明硬件吞吐或性能加速比时，必须同时在 PR 描述或 Gist 中随附**单文件零依赖的 C 语言独立可执行验证套件**（包含黄金向量验证、全尺寸全对齐排列扫除与带内存屏障的反优化基准），使任何 Reviewer 均能在任何目标架构机器上以一条命令（`clang -O3 ...`）在 3 秒内复现出比特精确的正确性与物理吞吐数据。
     21. **CI 运行故障精准定性与云端基础设施抖动隔离 (CI Flakiness & Root-Cause Diagnosis)**：遇到远端 CI 红灯时，严禁盲目臆断或无端修改本地代码；必须通过 `gh run view <run-id> --log-failed` 抓取真实物理日志，精准鉴别是真实代码/构建缺陷（如未定义符号、原型缺失），还是云端第三方服务（如 CodeQL、Coverity）的 503 基础设施瞬时抖动。属于平台瞬时故障时，保留证据并请求 Maintainer 重跑，坚决杜绝掩耳盗铃或误改业务逻辑。
     22. **最高程度警惕幻觉与物理实践确界铁律 (Zero-Hallucination & Empirical Practice Mandate)**：严禁任何形式的推演脑补、口头断言与未经验证的推断。凡在对话、文档、Issue 或 PR 中声明“已在本地测试通过”、“0 errors 0 warnings”、“已验证修复”时，必须有磁盘上真实物理落盘代码（`replace_file_content` / `write_to_file`）、物理编译器执行命令（`run_command`）与退出码 `exit code 0` 的控制台真实输出作为物理证据支撑；严禁仅凭脑补草拟 Diff 就宣称验证完成。所有技术描述中的文件名、行号、函数签名与变量类型，必须通过工具 100% 逐行物理核实。

6. **四大系统工程铁律 (The Four Systemic Engineering Invariants)**：
   - **流式第一性 (Stream-First)**：彻底消除“假设内存无限”的全量内存分配；一切数据流动面向微缓冲与分块流式管道；热路径杜绝 `Data(count:)` 内核页清零中断。
   - **纵深防御 (Invariant-First)**：路径安全下沉至 POSIX AT-API（`ARCHIVE_EXTRACT_SECURE_SYMLINKS` 等），采用延后 Fixup 倒序回写与 `O_NOFOLLOW` 物理免疫 TOCTOU 软链接劫持；算术必须调用 CPU 硬件防溢出。
   - **确定性确界 (Bounds-First)**：所有 C 句柄嵌入 `magic`首字段并在 `free()` 前置清零；密码与敏感内存必须调用 `memset_s` 或 volatile 擦除；跨语言数值必须经过 `SSIZE_MAX` Clamp；重构必须执行减法清点冗余。
   - **真实预言机 (Oracle-First)**：测试必须面向历史缺陷黄金语料库（`.uu` 文件）、系统原生工具双向差分测试与崩溃现场优先落盘模糊测试（`Crash-First Fuzzing`）。

---

## 八、 关键文档索引

| 文档 | 路径 |
| :--- | :--- |
| 软件架构总览 | `ARCHITECTURE.md` |
| 全局开源上游贡献规范 | `~/.agents/skills/upstream-contribution/SKILL.md` |
| 全局代码审查标准指南 | `~/.agents/skills/code-review/SKILL.md` |
| 全局设计模式专属指南 | `~/.agents/skills/design-patterns-guide/SKILL.md` |
| UI 设计系统 | `~/.agents/skills/ttzip-ui-design-system/SKILL.md` |
| ZIP 引擎冻结规则 | `.agents/rules/zip-engine-freeze.md` |
| Spec Kit 多 Agent 隔离规则 | `.agents/rules/speckit-multiagent.md` |
| CI/CD 流水线 | `.github/workflows/ci-cd.yml` |

