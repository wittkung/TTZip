<p align="center">
  <a href="README.md">English</a> |
  <a href="README_zh.md"><strong>简体中文</strong></a> |
  <a href="README_ja.md">日本語</a> |
  <a href="README_ko.md">한국어</a>
</p>

<p align="center">
  <img src="logo/AppIcon.png" alt="TTZip Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>极速原生跨平台归档与压缩微内核</strong><br />
  基于 Safe Rust 安全微内核 (<code>ttzip-glue</code> &rarr; <code>TTZipVendor.xcframework</code>)、SOTA 顶尖编解码器矩阵、Dual-ISA 硬件向量加速（ARM64 PMULL / x86_64 AVX2）以及 Swift 6 原生 macOS 表现层与 CLI (<code>TTZipApp</code>, <code>TTZipCLI</code>, <code>TTZipCore</code>) 构建。
</p>

<p align="center">
  <a href="https://github.com/wittkung/TTZip"><img src="https://img.shields.io/badge/架构-Swift%206%20%2B%20Safe%20Rust-blue?style=flat-square" alt="Architecture" /></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-1.80%2B%20%7C%20Cargo-dea584?style=flat-square&logo=rust" alt="Rust Cargo" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%20严格并发-orange?style=flat-square&logo=swift" alt="Swift 6.0" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue?style=flat-square&logo=apple" alt="macOS 14+" /></a>
  <a href="https://en.wikipedia.org/wiki/Apple_silicon"><img src="https://img.shields.io/badge/向量%20ISA-ARM64%20NEON%20%2B%20x86__64%20AVX2-purple?style=flat-square" alt="Hardware Vector" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/开源协议-Source--Available-blue.svg?style=flat-square" alt="License" /></a>
</p>

---

## 🌟 核心技术亮点与架构设计

- **🚀 双核微内核架构 (Swift 6 + Safe Rust 微内核)**：内存安全的高吞吐 Rust 原生引擎 (`rust/ttzip-glue` 编译为 `TTZipVendor.xcframework`)，通过零开销标准化 C-ABI (`CTTZipBridge`) 进行跨语言桥接，由 Swift 6 完全并发域编排 (`TTZipCore`) 驱动，呈现于原生桌面 GUI (`TTZipApp`)、POSIX 命令行 (`ttzip-cli`) 与性能基准套件 (`ttzip-bench`)。
- **⚡️ 63+ GB/s 硬件双指令集 (Dual-ISA) 向量加速**：
  - **63,232 MB/s (63.2 GB/s) CRC32**：ARM64 硬件多项式乘法 (`vmull_p64` / `__crc32d`) 与 x86_64 PCLMULQDQ 宽折叠加速。
  - **36,017 MB/s (36.0 GB/s) CRC64**：Dual-ISA 向量化 ECMA-182 校验。
  - **AES-256 向量指令流水线**：直通硬件 Crypto 指令，实现内存总线带宽级别的 ZIP/7Z 加解密。
- **🏎 SOTA 顶尖编解码器矩阵**：
  - **Deflate (libdeflate)**：单核压缩高达 4,742 MB/s (L1)，解压高达 34,060 MB/s (L9)。
  - **Zstandard (Zstd)**：压缩 7,452 MB/s，解压 29,046 MB/s (L3)。
  - **Google Snappy**：压缩 10,259 MB/s，解压 26,254 MB/s。
  - **Fast-LZMA2 (FL2)**：多核并发极端压缩，配备高效匹配查找器。
  - **Apple LZFSE, Brotli, Bzip2 与 Zopfli DAG 极限图优化**：原生 macOS 加速、网络流式传输与最短路径图优化。
- **🔍 纳秒级虚拟文件系统 (VFS) 微内核**：
  - **常数时间 Magic 幻数嗅探**：4.28 亿次/秒瞬间识别 100+ 种格式。
  - **自然数字排序**：3,218 万次/秒不区分大小写自然排序（`img_2.png` < `img_10.png`）。
  - **紧凑 Radix 归档文件树**：5,000 节点层级检索仅需 **308 微秒 (0.3 ms)**。
  - **零磁盘 I/O 内存即时预览**：直接解压到内存 Buffer，无需写入临时文件，零 SSD 磨损。
- **🛡 密码安全内存擦除与前向纠错 (FEC)**：
  - **DSE 防死存储消除擦除 (4,254 MB/s)**：Volatile 指针物理清零，防止密码残留在 Swift ARC 堆内存中。
  - **里德-所罗门恢复记录 (1,382 MB/s)**：Galois 域 GF(2^8) 纠错算法，自愈受损压缩包。
  - **零崩溃弹性**：加固 FFI 边界并具备 `catch_unwind` 隔离，全方位防护宿主进程。

---

## 📦 支持格式矩阵（16 种全格式支持）

| 格式分类 | 具体格式 | 打包压缩 (Rust/Swift 引擎) | 解压提取 (Safe 引擎) | 内存秒开预览 | 多卷分卷支持 |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **现代主流** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (多核并发) | ✅ (硬件 SIMD) | ✅ (0 磁盘 I/O) | ✅ (`.z01`, `.001`) |
| **高压缩率** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip` | ✅ | ✅ | ✅ | ✅ |
| **极速流式** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - |
| **系统镜像** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - |
| **分卷切割** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ |
| **专有格式** | `.rar`, `.cbr`, `.zipx`, `.cab` | 只读浏览 | ✅ | ✅ | - |

---

## 📈 实机硬件跑分测试 (`ttzip-bench matrix`)

*测试环境：Apple Silicon M 系列芯片，macOS 14+，通过 Swift 6.0 与 Rust Cargo `-O3` Release 编译。*

```text
=================================================================
 TTZip High-Performance Native Archive Engine v1.0.0
 Dual-Core Engine: Swift 6 Concurrency + Safe Rust Microkernel
=================================================================

[1/3] Hardware Vector Checksums:
  • CRC32 (PMULL/ACLE/SSE4.2):  63,232.78 MB/s (63.2 GB/s)
  • CRC64 (PMULL/PCLMULQDQ):   36,017.11 MB/s (36.0 GB/s)

[2/3] SOTA Single-Core Compression Throughput:
  • Deflate (libdeflate L1)    -> Comp:  4,742.1 MB/s | Decomp:   7,464.7 MB/s [OK]
  • Deflate (libdeflate L6)    -> Comp:  1,294.2 MB/s | Decomp:  29,967.3 MB/s [OK]
  • Deflate (libdeflate L9)    -> Comp:    416.9 MB/s | Decomp:  34,060.7 MB/s [OK]
  • Zstandard (Zstd L1)        -> Comp:  7,322.2 MB/s | Decomp:  19,115.9 MB/s [OK]
  • Zstandard (Zstd L3)        -> Comp:  7,452.7 MB/s | Decomp:  29,046.9 MB/s [OK]
  • Google Snappy              -> Comp: 10,259.4 MB/s | Decomp:  26,254.6 MB/s [OK]

[3/4] Virtual Filesystem & Frontend Heavy Calculation Microkernels:
  • Magic Header Sniffing:        428.33 Million ops/s (Detected: PNG - image/png)
  • Natural Numeric Sorting:        32.18 Million ops/s (Result: -1)
  • Radix Tree 5000-Node Search:   308.38 µs (Found 1 matches: 'file_0042.dat')
  • DSE-Immune Memory Scrubbing:  4,254.14 MB/s
  • Reed-Solomon Recovery Parity: 1,382.18 MB/s

[4/4] Cross-Platform Rayon / TaskGroup Multi-Core Scaling:
  • Active Worker Threads: 18 P/E Workers
```

---

## ⚡️ 快速安装与编译指南

### 1. 通过 Homebrew 安装

```bash
brew install wittkung/ttzip/ttzip-cli
```

### 2. 原生一键构建与安装

一行命令自动编译并将 `TTZip.app` 安装至 `/Applications`，同时将 `ttzip` / `ttzip-cli` 软链至系统环境变量：

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# 选项 A: 通过 Makefile 编译并安装
make reinstall

# 选项 B: 在 Finder 中双击运行或在终端中执行
./Install-TTZip.command
```

### 3. 通过 Swift Package Manager (SwiftPM) 编译

```bash
# 编译所有 Release 产物 (TTZipApp, ttzip-cli, ttzip-bench)
swift build -c release
```

### 4. 编译 Rust 安全微内核 (`ttzip-glue`)

```bash
# 自动编译 Universal 静态库并部署至 Vendor XCFramework
./scripts/build_rust.sh

# 或通过 Cargo 直接构建
cargo build --manifest-path rust/Cargo.toml --release
```

### 5. 运行本地自动化 CI 门禁（0 云端配额消耗）

```bash
./scripts/run_local_ci_gate.sh
```

---

## 💻 CLI 命令行使用指南 (`ttzip-cli`)

`ttzip-cli` 提供原生 POSIX 子命令支持，并支持管道与流式传输：

### 常用操作示例

```bash
# 1. 使用 SOTA 顶尖编解码器创建归档
ttzip-cli archive backup.zip file1.txt docs/ photos/
ttzip-cli archive output.tar.zst /path/to/source --level 9

# 2. 多核并发流式解压
ttzip-cli extract archive.tar.zst -o ./extracted/
ttzip-cli extract archive.7z

# 3. 校验压缩包 CRC 与结构完整性
ttzip-cli test archive.zip

# 4. 查看压缩包文件列表与元数据
ttzip-cli list archive.zip
ttzip-cli inspect archive.7z

# 5. 启动交互式终端 TUI 归档文件管理器
ttzip-cli explore archive.zip

# 6. 抢救并修复损坏的压缩文件
ttzip-cli repair damaged.zip -o repaired.zip
```

### 子命令速查表

| 命令 | 别名 | 用法示例 | 功能描述 |
| :--- | :--- | :--- | :--- |
| `archive` | `create`, `a`, `c` | `ttzip-cli archive <out> <inputs...>` | 使用 SOTA 编解码器与多核并行压缩打包 |
| `extract` | `x`, `e` | `ttzip-cli extract <archive> [-o dir]` | 多核极速并行解压，具备安全权限映射 |
| `test` | `t`, `verify` | `ttzip-cli test <archive>` | 校验压缩包 CRC、Header 及容器结构完整性 |
| `list` | `l`, `ls` | `ttzip-cli list <archive>` | 打印压缩包文件列表、压缩体积与属性 |
| `inspect` | `i`, `info` | `ttzip-cli inspect <archive>` | 深度审查容器元数据、编码类型与压缩率 |
| `explore` | `tui`, `browse` | `ttzip-cli explore <archive>` | 启动全屏交互式 TUI 压缩包浏览器 |
| `repair` | `recover` | `ttzip-cli repair <damaged> -o <fixed>` | 重建损坏的 Central Directory 并抢救文件条目 |
| `bench` | `b`, `benchmark` | `ttzip-cli bench` | 运行全量硬件向量指令与编解码器跑分 |

---

## 📊 基准测试与性能遥测指南 (`ttzip-bench`)

`ttzip-bench` 是基于 Rust Native C-ABI 的高性能内存微基准测试与 CI 性能门禁工具：

```bash
# 1. 运行全引擎内存基准测试矩阵 (libdeflate, zstd, lz4, lzfse, snappy, brotli, bzip2)
swift run ttzip-bench matrix

# 2. 运行自动化回归门禁检查 (CI/CD 硬件与编解码器校验)
swift run ttzip-bench gate

# 3. 导出结构化遥测 JSON、交互式 Pareto SVG 帕累托图以及 Zen UI 独立 HTML 仪表盘
swift run ttzip-bench plot --json-out telemetry.json --svg-out pareto.svg --html-out dashboard.html
```

---

## 💖 回馈开源社区

TTZip 秉持开源回馈精神，积极将验证过的硬件加速与架构优化贡献给上游核心项目：
- [libarchive](https://github.com/libarchive/libarchive) (Tim Kientzle, Martin Matuska)
- [XZ Utils / liblzma](https://github.com/tukaani-project/xz) (Lasse Collin, Igor Pavlov)
- [libdeflate](https://github.com/ebiggers/libdeflate) (Eric Biggers)
- [Zstandard (zstd)](https://github.com/facebook/zstd) (Yann Collet & Meta Compression Team)
- [LZ4](https://github.com/lz4/lz4) (Yann Collet)
- [7-Zip / LZMA SDK](https://www.7-zip.org) (Igor Pavlov)

### 🌟 上游贡献成果
- **[`libarchive/libarchive`](https://github.com/libarchive/libarchive)**：
  - ✅ **ARMv8 ACLE 硬件加速 CRC32 与架构统一** ([PR #3391](https://github.com/libarchive/libarchive/pull/3391) — **已合并至 `master`**, Commit [`8e439b92`](https://github.com/libarchive/libarchive/commit/8e439b92787c8104e22c5958caf0a7ef9532567f))。
  - 🔄 **7-Zip AES-256-CBC 流式解密流水线** ([PR #3388](https://github.com/libarchive/libarchive/pull/3388))。
  - 💡 **POSIX 空间预分配启发式优化** ([PR #3393](https://github.com/libarchive/libarchive/pull/3393))。
- **[`zlib-ng/zlib-ng`](https://github.com/zlib-ng/zlib-ng)**：
  - 🔄 **ARM64 NEON `compare256` 最长匹配向量化与指令缓存优化** ([PR #2416](https://github.com/zlib-ng/zlib-ng/pull/2416))：利用紧凑 `vmaxvq_u8` 指令序列优化滑动窗口模式匹配（长匹配延迟降低 -19% ~ -25%，保持极低 I-Cache 占用）。

---

## 📄 许可证与社区准则

TTZip 遵循 **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)**：

- **开发者与个人免费使用**：所有源代码完全开放用于学习、代码审查、学术研究与个人本地日常使用。
- **严禁第三方套壳分发与抄袭**：无论免费或收费，一律严禁擅自打包、更名上架至 Apple Mac App Store、Microsoft Store、Steam 等应用商店。
- **商业授权咨询**：企业商用请联系 `witt.w.kung@gmail.com`。

---

© 2026 Witt Kung. All rights reserved.
