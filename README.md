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
  Engineered with a Safe Rust Microkernel (<code>ttzip-glue</code> &rarr; <code>TTZipVendor.xcframework</code>), SOTA Codecs, Dual-ISA SIMD / PMULL Vector Acceleration, and a Swift 6 macOS GUI Shell & CLI (<code>TTZipApp</code>, <code>TTZipCLI</code>, <code>TTZipCore</code>).
</p>

<p align="center">
  <a href="https://github.com/wittkung/TTZip"><img src="https://img.shields.io/badge/Architecture-Swift%206%20%2B%20Safe%20Rust-blue?style=flat-square" alt="Architecture" /></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-1.80%2B%20%7C%20Cargo-dea584?style=flat-square&logo=rust" alt="Rust Cargo" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%20Strict-orange?style=flat-square&logo=swift" alt="Swift 6.0" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue?style=flat-square&logo=apple" alt="macOS 14+" /></a>
  <a href="https://en.wikipedia.org/wiki/Apple_silicon"><img src="https://img.shields.io/badge/Vector%20ISA-ARM64%20NEON%20%2B%20x86__64%20AVX2-purple?style=flat-square" alt="Hardware Vector" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Source--Available-blue.svg?style=flat-square" alt="License" /></a>
</p>

---

## 🌟 Key Highlights & Architectural Principles

- **🚀 Dual-Core Architecture (Swift 6 + Safe Rust Microkernel)**: High-throughput, memory-safe Rust native engine (`rust/ttzip-glue` compiled into `TTZipVendor.xcframework`), bridged via a standardized zero-overhead C-ABI (`CTTZipBridge`), orchestrated by Swift 6 complete concurrency (`TTZipCore`), and presented via native desktop GUI (`TTZipApp`), POSIX CLI (`ttzip-cli`), and telemetry benchmark suite (`ttzip-bench`).
- **⚡️ 63+ GB/s Hardware Vector Dual-ISA Acceleration**:
  - **63,232 MB/s (63.2 GB/s) CRC32**: Hardware polynomial multiplication (`vmull_p64` / `__crc32d` on ARM64, `_mm_clmulepi64_si128` on x86_64).
  - **36,017 MB/s (36.0 GB/s) CRC64**: Dual-ISA wide-folded polynomial reduction (ECMA-182).
  - **AES-256 Vector Pipeline**: Hardware crypto instructions for ZIP / 7Z encryption & decryption at memory bus bandwidth.
- **🏎 SOTA Codec Matrix**:
  - **Deflate (libdeflate)**: 4,742 MB/s single-core compression (L1) / 34,060 MB/s decompression (L9).
  - **Zstandard (Zstd)**: 7,452 MB/s compression / 29,046 MB/s decompression (L3).
  - **Google Snappy**: 10,259 MB/s compression / 26,254 MB/s decompression.
  - **Fast-LZMA2 (FL2)**: Multi-threaded extreme LZMA2 compression with radical match finders.
  - **Apple LZFSE, Brotli, Bzip2 & Zopfli DAG**: Native macOS acceleration, web stream codecs, and shortest-path graph optimization.
- **🔍 Sub-Nanosecond Virtual Filesystem Microkernels**:
  - **Constant-Time Magic Header Sniffing**: 428.33 Million ops/s instant binary signature detection across 100+ formats.
  - **Natural Numeric Sorting**: 32.18 Million ops/s case-insensitive natural sort (`img_2.png` < `img_10.png`).
  - **Compact Radix Archive Tree**: 5,000-node hierarchy search in **308 microseconds (0.3 ms)**.
  - **Zero-Disk-IO Instant Preview**: Memory-mapped direct entry decompression without temporary files.
- **🛡 Cryptographic Memory Scrubbing & Error Correction**:
  - **DSE-Immune Memory Wipe (4,254 MB/s)**: Volatile pointer scrubbing to prevent Dead Store Elimination from leaking keys in memory.
  - **Reed-Solomon Recovery Records (1,382 MB/s)**: Galois Field GF(2^8) forward error correction (FEC) for self-healing damaged archives.
  - **Panic-Free Resilience**: Hardened FFI boundary with `catch_unwind` isolation protecting all host processes.

---

## 📦 Supported Archive Formats (16 Full-Matrix Formats)

| Format Category | Formats | Packing (Rust/Swift Engine) | Extraction (Safe Engine) | In-Memory Preview | Multi-Volume Split |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Primary Modern** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (Multi-Core) | ✅ (Hardware SIMD) | ✅ (0-Disk-IO) | ✅ (`.z01`, `.001`) |
| **High Compression** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip` | ✅ | ✅ | ✅ | ✅ |
| **Real-time / High Speed** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - |
| **System & Disk Images** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - |
| **Multi-Volume Split** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ |
| **Legacy & Proprietary** | `.rar`, `.cbr`, `.zipx`, `.cab` | Read-Only | ✅ | ✅ | - |

---

## 📈 Real Physical Hardware Benchmarks (`ttzip-bench matrix`)

*Tested on Apple Silicon M-Series (macOS 14+ / Darwin), compiled via Swift 6.0 & Rust Cargo with `-O3` Release flags.*

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

## ⚡️ Quick Installation & Building

### 1. Install via Homebrew

```bash
brew install wittkung/ttzip/ttzip-cli
```

### 2. One-Click Native Build & Installation

Build and install `TTZip.app` to `/Applications` and `ttzip` / `ttzip-cli` to your PATH with a single command:

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# Option A: Build and install via Makefile
make reinstall

# Option B: Double-click from Finder or execute directly in terminal
./Install-TTZip.command
```

### 3. Build via Swift Package Manager (SwiftPM)

```bash
# Build all release products (TTZipApp, ttzip-cli, ttzip-bench)
swift build -c release
```

### 4. Build Rust Core Microkernel (`ttzip-glue`)

```bash
# Automatically compile universal static library & deploy to Vendor XCFramework
./scripts/build_rust.sh

# Or build directly via Cargo
cargo build --manifest-path rust/Cargo.toml --release
```

### 5. Run 100% Local Automated CI Verification (0 Cloud Quota)

```bash
./scripts/run_local_ci_gate.sh
```

---

## 💻 CLI Usage Guide (`ttzip-cli`)

`ttzip-cli` provides dedicated POSIX subcommands with pipeline and streaming support:

### Common Commands

```bash
# 1. Create archives with SOTA compression
ttzip-cli archive backup.zip file1.txt docs/ photos/
ttzip-cli archive output.tar.zst /path/to/source --level 9

# 2. Parallel multi-core extraction
ttzip-cli extract archive.tar.zst -o ./extracted/
ttzip-cli extract archive.7z

# 3. Test archive CRC integrity
ttzip-cli test archive.zip

# 4. List and inspect archive contents
ttzip-cli list archive.zip
ttzip-cli inspect archive.7z

# 5. Interactive terminal TUI archive explorer
ttzip-cli explore archive.zip

# 6. Salvage and repair damaged archives
ttzip-cli repair damaged.zip -o repaired.zip
```

### Subcommands Reference

| Command | Aliases | Usage | Description |
| :--- | :--- | :--- | :--- |
| `archive` | `create`, `a`, `c` | `ttzip-cli archive <out> <inputs...>` | Create archive using SOTA codecs & parallel compression |
| `extract` | `x`, `e` | `ttzip-cli extract <archive> [-o dir]` | Multi-core parallel extraction with safe permission mapping |
| `test` | `t`, `verify` | `ttzip-cli test <archive>` | Verify archive CRC, headers, and container integrity |
| `list` | `l`, `ls` | `ttzip-cli list <archive>` | Print archive entry list, compressed size, and attributes |
| `inspect` | `i`, `info` | `ttzip-cli inspect <archive>` | Inspect detailed container metadata, codec, and compression ratio |
| `explore` | `tui`, `browse` | `ttzip-cli explore <archive>` | Launch interactive full-screen TUI archive browser |
| `repair` | `recover` | `ttzip-cli repair <damaged> -o <fixed>` | Reconstruct broken central directories and recover entries |
| `bench` | `b`, `benchmark` | `ttzip-cli bench` | Run hardware vector and codec throughput benchmarks |

---

## 📊 Benchmarking & Telemetry Guide (`ttzip-bench`)

`ttzip-bench` is a high-performance in-memory microbenchmarking utility communicating over the Rust Native C-ABI.

```bash
# 1. Run full in-memory multi-engine benchmark matrix
swift run ttzip-bench matrix

# 2. Run automated regression gate (CI/CD verification)
swift run ttzip-bench gate

# 3. Export structured telemetry JSON, interactive Pareto SVG, and Zen UI dashboard
swift run ttzip-bench plot --json-out telemetry.json --svg-out pareto.svg --html-out dashboard.html
```

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
