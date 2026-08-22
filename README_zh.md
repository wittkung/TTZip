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
  基于纯 C11 独立核心 (`libttzip`)、SOTA 编解码器矩阵、Dual-ISA 硬件向量加速（ARM64 PMULL / x86_64 AVX2）以及轻量级 Swift 6 macOS 表现层构建。
</p>

<p align="center">
  <a href="https://github.com/wittkung/TTZip"><img src="https://img.shields.io/badge/架构-纯%20C11%20微内核-blue?style=flat-square&logo=c" alt="C11 Core" /></a>
  <a href="https://cmake.org"><img src="https://img.shields.io/badge/构建-CMake%203.20%2B-064F8C?style=flat-square&logo=cmake" alt="CMake" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%20严格并发-orange?style=flat-square&logo=swift" alt="Swift 6.0" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue?style=flat-square&logo=apple" alt="macOS 14+" /></a>
  <a href="https://en.wikipedia.org/wiki/Apple_silicon"><img src="https://img.shields.io/badge/向量%20ISA-ARM64%20NEON%20%2B%20x86__64%20AVX2-purple?style=flat-square" alt="Hardware Vector" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/开源协议-Source--Available-blue.svg?style=flat-square" alt="License" /></a>
</p>

---

## 🌟 核心技术亮点与架构设计

- **🚀 100% 独立纯 C11 微内核 (`libttzip.a`)**：零外部 CLI 进程派生（无 `exec`/`posix_spawn`）。所有压缩、解压、树遍历和编解码逻辑均在进程内通过纯 C11 静态库高效执行，彻底消除对 Apple GCD 的强依赖。
- **⚡️ 63+ GB/s 硬件双指令集 (Dual-ISA) 向量加速**：
  - **63,232 MB/s (63.2 GB/s) CRC32**：ARM64 硬件多项式乘法 (`vmull_p64` / `__crc32d`) 与 x86_64 PCLMULQDQ 宽折叠加速。
  - **36,017 MB/s (36.0 GB/s) CRC64**：Dual-ISA 向量化 ECMA-182 校验。
  - **AES-256 向量指令流水线**：直通硬件 Crypto 指令，实现内存总线带宽级别的 ZIP/7Z 加解密。
- **🏎 SOTA 顶尖编解码器矩阵**：
  - **Deflate (libdeflate)**：单核压缩高达 4,742 MB/s (L1)，解压高达 34,060 MB/s (L9)。
  - **Zstandard (Zstd)**：压缩 7,452 MB/s，解压 29,046 MB/s (L3)。
  - **Google Snappy**：压缩 10,259 MB/s，解压 26,254 MB/s。
  - **Fast-LZMA2 (FL2)**：多核并发极端压缩，配备高效匹配查找器。
  - **Apple LZFSE 与 Zopfli 图优化**：原生 macOS 加速与最短路径 DAG 极限压缩比。
- **🔍 纳秒级虚拟文件系统 (VFS) 微内核**：
  - **常数时间 Magic 幻数嗅探**：4.28 亿次/秒瞬间识别 100+ 种格式。
  - **纯 C11 自然数字排序**：3,218 万次/秒不区分大小写自然排序（`img_2.png` < `img_10.png`）。
  - **紧凑 Radix 归档文件树**：5,000 节点层级检索仅需 **308 微秒 (0.3 ms)**。
  - **零磁盘 I/O 内存即时预览**：直接解压到内存 Buffer，无需写入临时文件，零 SSD 磨损。
- **🛡 密码安全内存擦除与前向纠错 (FEC)**：
  - **DSE 防死存储消除擦除 (4,254 MB/s)**：Volatile 指针物理清零，防止密码残留在 Swift ARC 堆内存中。
  - **里德-所罗门恢复记录 (1,382 MB/s)**：Galois 域 GF(2^8) 纠错算法，自愈受损压缩包。
- **🖥 极轻量级 Swift 6 macOS 表现层 (`TTZipApp`)**：
  - 核心逻辑完全退守为极薄桥接 (`NativeMicrokernelBridge`)，UI 响应零卡顿。

---

## 📦 支持格式矩阵（16 种全格式支持）

| 格式分类 | 具体格式 | 打包压缩 (C11 核心) | 解压提取 (C11 核心) | 内存秒开预览 | 多卷分卷支持 |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **现代主流** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (多核并发) | ✅ (硬件 SIMD) | ✅ (0 磁盘 I/O) | ✅ (`.z01`, `.001`) |
| **高压缩率** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip` | ✅ | ✅ | ✅ | ✅ |
| **极速流式** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - |
| **系统镜像** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - |
| **分卷切割** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ |
| **专有格式** | `.rar`, `.cbr`, `.zipx`, `.cab` | 只读浏览 | ✅ | ✅ | - |

---

## 📈 实机硬件跑分测试 (`ttzip-cli --benchmark`)

*测试环境：Apple Silicon M 系列芯片，macOS 14+，CMake 3.20+ Release `-O3` 编译。*

```text
=================================================================
 TTZip High-Performance Native Archive Engine v1.0.0
 Cross-Platform Pure C11 Core Engine (Zero GCD / SOTA Codecs)
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

[4/4] Cross-Platform Threadpool (ttzip_threadpool) Multi-Core Scaling:
  • Active Worker Threads: 18 P/E Workers
```

---

## ⚡️ 快速安装与编译指南

### 1. 编译纯 C 微内核与独立 CLI 工具 (CMake)

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# 配置并编译 Release 二进制
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j8

# 运行独立 CLI 性能基准测试与快速入门示例
./build/ttzip-cli --benchmark
./build/ttzip-quickstart
```

### 2. 编译 macOS 原生桌面客户端与 Swift CLI

```bash
# 通过 Swift Package Manager 编译
swift build -c release
```

### 3. 运行本地自动化 CI 门禁（0 云端配额消耗）

```bash
./scripts/run_local_ci_gate.sh
```

---

## 🛠 C SDK 1 分钟快速集成示例

通过 `ttzip_api.h` 直接将 `libttzip` 嵌入至您的 C/C++/Rust 应用程序中：

```c
#include <stdio.h>
#include <string.h>
#include <ttzip/ttzip_api.h>

int main(void) {
    printf("TTZip 引擎版本: %s\n", ttzip_version_string());

    // 1. 硬件向量加速 CRC32 校验
    const char *data = "Hello TTZip Native World!";
    uint32_t hash = ttzip_crc32(0, data, strlen(data));

    // 2. 内存级 SOTA 压缩 (如 Zstd)
    size_t comp_cap = ttzip_compress_bound(TTZIP_API_CODEC_ZSTD, strlen(data));
    uint8_t comp_buf[256];
    size_t comp_len = ttzip_compress_buffer(
        TTZIP_API_CODEC_ZSTD, data, strlen(data), comp_buf, sizeof(comp_buf), 3
    );

    // 3. 纳秒级 Magic 格式嗅探
    ttzip_magic_info_t info = ttzip_magic_sniff_buffer(comp_buf, comp_len);
    printf("识别格式: %s (MIME: %s)\n", info.format_name, info.mime_type);

    return 0;
}
```

### CMake `FetchContent` 引入方式

```cmake
include(FetchContent)
FetchContent_Declare(
    TTZip
    GIT_REPOSITORY https://github.com/wittkung/TTZip.git
    GIT_TAG        main
)
FetchContent_MakeAvailable(TTZip)

target_link_libraries(your_application PRIVATE TTZip::ttzip)
```

---

## 💻 CLI 常用命令参考

| 选项命令 | 示例用法 | 功能描述 |
| :--- | :--- | :--- |
| `-c`, `--create` | `ttzip-cli -c archive.zip file1 file2 dir/` | 使用 SOTA 编解码器流式创建归档 |
| `-x`, `--extract` | `ttzip-cli -x archive.tar -o output_dir/` | 多核并行解压 |
| `-t`, `--test` | `ttzip-cli -t archive.7z` | 校验压缩包完整性与 CRC |
| `-l`, `--list` | `ttzip-cli -l archive.zip` | 打印压缩包文件列表与元数据 |
| `--benchmark` | `ttzip-cli --benchmark` | 运行全量硬件向量与编解码器基准测试 |

---

## 💖 回馈开源社区

TTZip 秉持开源回馈精神，积极将验证过的硬件加速与架构优化贡献给上游核心项目：
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
