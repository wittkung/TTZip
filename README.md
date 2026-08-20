<p align="center">
  <a href="README.md"><strong>English</strong></a> |
  <a href="README_zh.md">简体中文</a> |
  <a href="README_ja.md">日本語</a> |
  <a href="README_ko.md">한국어</a>
</p>

<p align="center">
  <img src="logo/AppIcon.png" alt="TTZip Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>Ultra-High-Performance Native Archiving & Compression Microkernel</strong><br />
  Engineered with a Pure C11 Standalone Core Engine (`libttzip`), SOTA Codecs, Dual-ISA SIMD / PMULL Vector Acceleration, and a Lightweight Swift 6 macOS GUI Shell.
</p>

<p align="center">
  <a href="https://github.com/wittkung/TTZip"><img src="https://img.shields.io/badge/Architecture-Pure%20C11%20Microkernel-blue?style=flat-square&logo=c" alt="C11 Core" /></a>
  <a href="https://cmake.org"><img src="https://img.shields.io/badge/Build-CMake%203.20%2B-064F8C?style=flat-square&logo=cmake" alt="CMake" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%20Strict-orange?style=flat-square&logo=swift" alt="Swift 6.0" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue?style=flat-square&logo=apple" alt="macOS 14+" /></a>
  <a href="https://en.wikipedia.org/wiki/Apple_silicon"><img src="https://img.shields.io/badge/Vector%20ISA-ARM64%20NEON%20%2B%20x86__64%20AVX2-purple?style=flat-square" alt="Hardware Vector" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Source--Available-blue.svg?style=flat-square" alt="License" /></a>
</p>

---

## 🌟 Key Highlights & Architectural Principles

- **🚀 100% Pure C11 High-Performance Core (`libttzip.a`)**: Zero external CLI process spawning (`exec`/`posix_spawn`). All heavy archive packing, unpacking, tree parsing, and codec operations run in-process via a standalone C11 static library with zero Apple GCD lock-in.
- **⚡️ 63+ GB/s Hardware Vector Dual-ISA Acceleration**:
  - **63,232 MB/s (63.2 GB/s) CRC32**: Hardware polynomial multiplication (`vmull_p64` / `__crc32d` on ARM64, `_mm_clmulepi64_si128` on x86_64).
  - **36,017 MB/s (36.0 GB/s) CRC64**: Dual-ISA wide-folded polynomial reduction (ECMA-182).
  - **AES-256 Vector Pipeline**: Hardware crypto instructions for ZIP / 7Z encryption & decryption at memory bus bandwidth.
- **🏎 SOTA Codec Matrix**:
  - **Deflate (libdeflate)**: 4,742 MB/s single-core compression (L1) / 34,060 MB/s decompression (L9).
  - **Zstandard (Zstd)**: 7,452 MB/s compression / 29,046 MB/s decompression (L3).
  - **Google Snappy**: 10,259 MB/s compression / 26,254 MB/s decompression.
  - **Fast-LZMA2 (FL2)**: Multi-threaded extreme LZMA2 compression with radical match finders.
  - **Apple LZFSE & Zopfli DAG**: Native macOS acceleration and shortest-path graph optimization.
- **🔍 Sub-Nanosecond Virtual Filesystem Microkernels**:
  - **Constant-Time Magic Header Sniffing**: 428.33 Million ops/s instant binary signature detection across 100+ formats.
  - **Pure C11 Natural Numeric Sorting**: 32.18 Million ops/s case-insensitive natural sort (`img_2.png` < `img_10.png`).
  - **Compact Radix Archive Tree**: 5,000-node hierarchy search in **308 microseconds (0.3 ms)**.
  - **Zero-Disk-IO Instant Preview**: Memory-mapped direct entry decompression without temporary files.
- **🛡 Cryptographic Memory Scrubbing & Error Correction**:
  - **DSE-Immune Memory Wipe (4,254 MB/s)**: Volatile pointer scrubbing to prevent Dead Store Elimination from leaking keys in memory.
  - **Reed-Solomon Recovery Records (1,382 MB/s)**: Galois Field GF(2^8) forward error correction (FEC) for self-healing damaged archives.
- **🖥 Lightweight Swift 6 Desktop Shell (`TTZipApp`)**:
  - Thin presentation layer utilizing `NativeMicrokernelBridge` and Swift 6 complete concurrency with 0 Apple GCD calls in core business logic.

---

## 📦 Supported Archive Formats (16 Full-Matrix Formats)

| Format Category | Formats | Packing (C11 Engine) | Extraction (C11 Engine) | In-Memory Preview | Multi-Volume Split |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Primary Modern** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (Multi-Core) | ✅ (Hardware SIMD) | ✅ (0-Disk-IO) | ✅ (`.z01`, `.001`) |
| **High Compression** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip` | ✅ | ✅ | ✅ | ✅ |
| **Real-time / High Speed** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - |
| **System & Disk Images** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - |
| **Multi-Volume Split** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ |
| **Legacy & Proprietary** | `.rar`, `.cbr`, `.zipx`, `.cab` | Read-Only | ✅ | ✅ | - |

---

## 📈 Real Physical Hardware Benchmarks (`ttzip-cli --benchmark`)

*Tested on Apple Silicon M-Series (macOS 14+ / Darwin), compiled via CMake 3.20+ with `-O3` Release flags.*

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

## ⚡️ Quick Installation & Building

### 1. Build Pure C Microkernel & Standalone CLI (CMake)

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# Configure & Build Release Binaries
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j8

# Run Standalone CLI Benchmark & Quickstart
./build/ttzip-cli --benchmark
./build/ttzip-quickstart
```

### 2. Build Native macOS Desktop App & Swift CLI

```bash
# Build via Swift Package Manager
swift build -c release
```

### 3. Run 100% Local Automated CI Verification (0 Cloud Quota)

```bash
./scripts/local-ci.sh
```

---

## 🛠 C SDK 1-Minute Integration Guide

Embed `libttzip` directly into your C/C++/Rust applications via `ttzip_api.h`:

```c
#include <stdio.h>
#include <string.h>
#include <ttzip/ttzip_api.h>

int main(void) {
    printf("TTZip Version: %s\n", ttzip_version_string());

    // 1. Hardware-accelerated CRC32
    const char *data = "Hello TTZip Native World!";
    uint32_t hash = ttzip_crc32(0, data, strlen(data));

    // 2. In-Memory SOTA Compression (e.g. Zstd)
    size_t comp_cap = ttzip_compress_bound(TTZIP_API_CODEC_ZSTD, strlen(data));
    uint8_t comp_buf[256];
    size_t comp_len = ttzip_compress_buffer(
        TTZIP_API_CODEC_ZSTD, data, strlen(data), comp_buf, sizeof(comp_buf), 3
    );

    // 3. Sub-nanosecond format sniffing
    ttzip_magic_info_t info = ttzip_magic_sniff_buffer(comp_buf, comp_len);
    printf("Detected Format: %s (MIME: %s)\n", info.format_name, info.mime_type);

    return 0;
}
```

### CMake `FetchContent` Integration

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

## 💻 CLI Subcommands Reference

`ttzip-cli` provides dedicated subcommands with pipe streaming support:

| Command | Usage | Description |
| :--- | :--- | :--- |
| `-c`, `--create` | `ttzip-cli -c archive.zip file1 file2 dir/` | Create archive using SOTA codecs |
| `-x`, `--extract` | `ttzip-cli -x archive.tar -o output_dir/` | Multi-core parallel extraction |
| `-t`, `--test` | `ttzip-cli -t archive.7z` | Verify archive CRC/integrity |
| `-l`, `--list` | `ttzip-cli -l archive.zip` | List archive files and metadata |
| `--benchmark` | `ttzip-cli --benchmark` | Run full hardware vector & codec benchmark |

---

## 💖 Giving Back to Upstream Open Source

TTZip stands upon the work of foundational open-source compression libraries:
- [libarchive](https://github.com/libarchive/libarchive) (Tim Kientzle, Martin Matuska)
- [XZ Utils / liblzma](https://github.com/tukaani-project/xz) (Lasse Collin, Igor Pavlov)
- [libdeflate](https://github.com/ebiggers/libdeflate) (Eric Biggers)
- [Zstandard (zstd)](https://github.com/facebook/zstd) (Yann Collet & Meta Compression Team)
- [LZ4](https://github.com/lz4/lz4) (Yann Collet)
- [7-Zip / LZMA SDK](https://www.7-zip.org) (Igor Pavlov)

### 🌟 Upstream Contributions
We actively contribute verified hardware acceleration routines back to foundational upstream projects:
- **[`libarchive/libarchive`](https://github.com/libarchive/libarchive)**:
  - ✅ **ARMv8 ACLE Hardware-Accelerated CRC32 & Architectural Unification** ([PR #3391](https://github.com/libarchive/libarchive/pull/3391) — **Merged into `master`**, Commit [`8e439b92`](https://github.com/libarchive/libarchive/commit/8e439b92787c8104e22c5958caf0a7ef9532567f)).
  - 🔄 **7-Zip AES-256-CBC Stream Decryption Pipeline** ([PR #3388](https://github.com/libarchive/libarchive/pull/3388)).
  - 💡 **POSIX `F_PREALLOCATE` & `fallocate` Heuristics** ([Issue #3392](https://github.com/libarchive/libarchive/issues/3392) / [PR #3393](https://github.com/libarchive/libarchive/pull/3393)).
- **[`zlib-ng/zlib-ng`](https://github.com/zlib-ng/zlib-ng)**:
  - 🔄 **ARM64 NEON `compare256` Longest Match Vectorization & I-Cache Optimization** ([PR #2416](https://github.com/zlib-ng/zlib-ng/pull/2416)): Optimized NEON sliding window pattern comparison with compact `vmaxvq_u8` instruction sequences (-19% ~ -25% latency reduction on long matches, minimal I-cache footprint).

---

## 📄 License & Community Model

TTZip is licensed under the **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)**.

- **100% Free for Developers & Personal Use**: All source code is open for reading, learning, research, and local execution.
- **Strict Anti-Copycat Protection**: Repackaging or publishing TTZip (free or paid) to the Apple Mac App Store, Microsoft Store, Steam, or other marketplaces without authorization is strictly prohibited.
- **Commercial Licensing**: Inquiries: `witt.w.kung@gmail.com`.

---

© 2026 Witt Kung. All rights reserved.
