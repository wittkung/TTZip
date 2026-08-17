# TTZip ⚡️

<p align="center">
  <img src="logo/AppIcon.png" alt="TTZip Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>Ultra-High-Performance Native Archiving & Compression Engine for macOS 14+ & Darwin Systems</strong><br />
  Engineered with 100% In-Process C11 Static Bindings, Swift 6 Strict Concurrency, and Apple Silicon SIMD / PMULL Hardware Acceleration.
</p>

<p align="center">
  <a href="https://github.com/wittkung/TTZip/actions"><img src="https://img.shields.io/badge/CI-Passing-brightgreen?style=flat-square&logo=githubactions" alt="CI Status" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%20Strict-orange?style=flat-square&logo=swift" alt="Swift 6.0" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue?style=flat-square&logo=apple" alt="macOS 14+" /></a>
  <a href="https://en.wikipedia.org/wiki/Apple_silicon"><img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2B%20x86__64-purple?style=flat-square" alt="Architecture" /></a>
  <a href="Formula/ttzip-cli.rb"><img src="https://img.shields.io/badge/Homebrew-wittkung%2Ftap%2Fttzip--cli-yellow.svg?style=flat-square&logo=homebrew" alt="Homebrew Tap" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Source--Available-blue.svg?style=flat-square" alt="License" /></a>
</p>

---

## 🌟 Key Highlights & Engineering Philosophy

- **🚀 100% In-Process Native C Engine**: Zero external CLI process spawning (`exec`/`posix_spawn`). All operations run directly in-process via static bindings to `libarchive`, `libdeflate`, `LZMA SDK`, `zstd`, `liblz4`, and `libb2`.
- **⚡️ 48 GB/s Apple Silicon SIMD / PMULL Hardware Acceleration**:
  - **48,160 MB/s (47.0 GB/s) CRC64 / CRC32**: Hardware polynomial multiplication (`vmull_p64`) with 4-way unrolled CLMUL pipelines — **35.5x faster (+3,450%)** than scalar table lookup.
  - **AES-256 SIMD**: Direct ARM NEON crypto vector instructions for ZIP/7Z encryption & decryption at memory bus speed.
  - **SWAR & Hybrid Match Finders**: Accelerated sliding window pattern scanning across DEFLATE and LZMA2 encoders.
- **🛡 Swift 6 Complete Concurrency**: 100% data-race-free architecture built with Swift 6 structured concurrency (`Actor`, `@MainActor`, `Task.detached`).
- **🌊 UNIX Pipe Streaming (`stdin`/`stdout`)**: Full-duplex zero-disk-staging streaming compression and decompression pipelines with automatic TTY protection and NDJSON error reporting.
- **🔤 Smart Universal Charset Auto-Detection**: Integrated `uchardet` automatically resolves and repairs GBK / CP936 / Shift-JIS / EUC-KR mojibake in legacy Windows ZIP/RAR archives.
- **👁 Seamless In-Archive QuickLook Preview**: Instant 0ms penetration, browsing, and media/code/document preview without full archive extraction.
- **🔒 Password Vault v4**: Enterprise-grade credential management with PBKDF2-SHA256 (600,000 OWASP iterations) + 32-byte salt and AES-256-GCM hardware encryption.
- **🛍 Dual Distribution Ready**:
  - **Mac App Store (MAS)**: 100% App Sandbox compliant (`-DMAS_BUILD`).
  - **Direct Independent Distribution**: Integrated Sparkle 2.0 automatic updates.

---

## 📦 Supported Archive Formats (16 Full-Matrix Formats)

| Format Category | Formats | Compression / Packing | Decompression | Penetration / QuickLook | Multi-Volume | Governing Standard |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Primary Modern** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (Multi-core) | ✅ (SIMD) | ✅ (0ms) | ✅ (`.001`) | PKWARE, 7z Spec, RFC 8878 |
| **High Compression** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip`, `.lrzip` | ✅ | ✅ | ✅ | ✅ | RFC 1952, POSIX Pax, XZ Spec |
| **Real-time / High Speed** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - | RFC 7932, LZ4 Frame |
| **System & Disk Images** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - | Apple UDIF, ISO 9660, WIM Spec |
| **Multi-Volume Split** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ | Multi-part Span Spec |
| **Legacy & Proprietary** | `.rar`, `.cbr`, `.zipx`, `.cab` | Read-Only | ✅ | ✅ | - | RAR 4.x/5.x, MS CAB |

---

## 📊 Physical Benchmark & Throughput (Apple Silicon M-Series)

Measured under physical monotonic hardware timers (`mach_absolute_time()`) on Apple Silicon with anti-optimization barriers enforced. All competitor tools were configured with full hardware multithreading (`-mmt=on`, `-T0`, `-p max`). For complete methodology, Silesia in-memory benchmarks, and the full 46-scenario matrix, see the **[Comprehensive Performance Whitepaper (docs/PERFORMANCE.md)](docs/PERFORMANCE.md)**.

| Workload Scenario | Target Format | Baseline Competitor | Competitor Throughput | TTZip Physical Throughput | Net Acceleration |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **Hardware Vector CRC64** | `Poly64` | Scalar Table Lookup | 1,352 MB/s | **48,160 MB/s (47.0 GB/s)** | **🟢 35.5x (+3,450%)** |
| **TAR.BZ2 Parallel Stream** | `.tar.bz2` | `pbzip2` (18 Threads) | 112 MB/s | **6,275 MB/s (6.1 GB/s)** | **🟢 55.9x faster** |
| **TAR.GZ Parallel Stream** | `.tar.gz` | `pigz` (18 Cores) | 787 MB/s | **6,037 MB/s (5.9 GB/s)** | **🟢 7.7x faster** |
| **7Z Fast LZMA2 Packaging** | `.7z` | `7-Zip 7zz CLI` | 1,052 MB/s | **2,968 MB/s (2.9 GB/s)** | **🟢 2.8x faster** |
| **ZIP Direct Decompression** | `.zip` | `7zz` (Max Multithread) | 1,016 MB/s | **5,936 MB/s (5.8 GB/s)** | **🟢 5.8x faster** |
| **DMG Disk Image Creation** | `.dmg` | macOS `hdiutil` | 2.8 MB/s | **2,796 MB/s (2.7 GB/s)** | **🟢 1,008x faster** |
| **TAR.ZST Direct Stream** | `.tar.zst` | `zstd -T0` | 12,668 MB/s | **17,166 MB/s (16.8 GB/s)** | **🟢 1.4x (+35%)** |
| **In-Process Latency** | Any | Subprocess Spawn (`fork`) | 15.0 ~ 45.0 ms | **< 0.001 ms (< 1 µs)** | **🟢 > 15,000x faster** |

---

## ⚡️ Quick Installation

### Option 1: Homebrew Tap (Recommended for CLI)

Install `ttzip-cli` along with UNIX manual pages (`man ttzip-cli`) and shell auto-completions (`zsh`, `bash`, `fish`, `nushell`) with a single command:

```bash
# Direct single-line installation
brew install wittkung/ttzip/ttzip-cli

# Or add tap first
brew tap wittkung/ttzip
brew install ttzip-cli
```

### Option 2: Pre-compiled Universal Binaries
Download official Universal 2 (`arm64` + `x86_64`) releases from [GitHub Releases](https://github.com/wittkung/TTZip/releases).

### Option 3: Build from Source
```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip
swift build -c release
```
The compiled standalone binary will be available at `.build/release/ttzip-cli`.

---

## 💻 CLI Command Reference & Stream Pipelines

`ttzip-cli` provides 10 dedicated subcommands with full UNIX pipe streaming and interactive TUI support:

### Subcommands Overview

| Command | Aliases | Description | Key Options |
| :--- | :--- | :--- | :--- |
| `explore` | `tui`, `browse` | Launch interactive terminal TUI archive explorer | `↑`/`↓`/`j`/`k` navigate, `Enter`/`l` drill down, `Space` select, `e` extract, `p` peek |
| `archive` / `create` | `a`, `c` | Create and compress archives | `-f <format>`, `-l <level>`, `-p <password>`, `--split`, `--exclude` |
| `extract` | `x`, `e` | Extract archive contents | `-o <dir>`, `--strip-components`, `--overwrite`, `-p <password>` |
| `list` | `l`, `ls` | List archive contents & metadata | `--json`, `-v`, `--filter <glob>` |
| `test` | `t`, `verify` | Verify archive integrity & standards | `--standard`, `--differential`, `--fuzz`, `--report-json` |
| `bench` | `b`, `pk` | Run physical monotonic benchmarks | `-f <format>`, `--iterations`, `--json` |
| `inspect` | `i`, `info` | Inspect format headers & magic signatures | `--raw`, `--encoding`, `--hash` |
| `tree` | - | Display archive visual tree hierarchy | `-d <depth>`, `--exclude <glob>` |
| `man` | - | Output UNIX groff mdoc manual page | `--output <file>` |
| `completion` | - | Generate shell auto-completion script | `zsh`, `bash`, `fish`, `nushell` |

### Interactive Terminal TUI Mode (`explore`)

```bash
# Launch zero-dependency ANSI/VT100 interactive explorer
ttzip-cli explore release_bundle.tar.zst

# Keybindings inside TUI:
#  ↑ / k       Move cursor up
#  ↓ / j       Move cursor down
#  Enter / l   Drill down / expand directory
#  Backspace/h Collapse directory / back to parent
#  Space       Toggle entry selection checkbox
#  e           Extract selected entries to current directory
#  p           Popup peek modal (syntax preview / hex dump)
#  q / Esc     Exit cleanly and restore terminal screen
```

### UNIX Stream Pipelines (1-Liners)

```bash
# 1. Stream extract directly from curl (zero intermediate disk staging)
curl -fsSL https://example.com/data.tar.zst | ttzip-cli extract - -o ./data/

# 2. Archive a directory and pipe directly to a remote server over SSH
ttzip-cli archive - -f tar.zst ./source | ssh user@server "ttzip-cli extract - -o ./backup/"

# 3. Stream a single log file out of an archive directly into grep
ttzip-cli extract bundle.zip --stdout access.log | grep -E "ERROR|FATAL"
```

---

## 🖥 Native macOS Desktop GUI Features (`TTZipApp`)

- **In-Archive QuickLook Preview**: Instant 0ms penetration and previewing of code, markdown, audio, 4K video, PDFs, and images without full extraction.
- **Smart Universal Charset Auto-Detection**: Seamlessly detects and repairs GBK, CP936, Shift-JIS, and EUC-KR encoding to eliminate mojibake from legacy Windows archives.
- **Password Vault v4**: Hardware-accelerated password management with PBKDF2-SHA256 (600,000 OWASP iterations) + 32-byte salt and AES-256-GCM.
- **Archive Inspector & Health Check**: Interactive diagnostic sheet inspecting magic headers, Zip64 flags, and actively intercepting Zip-Slip path traversal vulnerabilities.

---

## 🏗 System Architecture & Invariants

```
┌────────────────────────────────────────────────────────────────────────┐
│ Layer 3: Presentation & Interfaces (TTZipApp SwiftUI + TTZipCLI)       │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2: Swift 6 Core Engine (TTZipCore Pipelines, Vault v4, Scanners) │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1: C11 In-Process Bridge (CTTZipBridge SIMD PMULL / Crypto / I/O)│
├────────────────────────────────────────────────────────────────────────┤
│ Layer 0: High-Performance Static Foundations (libarchive, zstd, LZMA)  │
└────────────────────────────────────────────────────────────────────────┘
```

### The Four Systemic Engineering Invariants
1. **Stream-First (流式第一性)**: Zero full-buffer memory assumptions; microbuffering pull pipelines under 64MB~128MB.
2. **Invariant-First (纵深防御)**: POSIX primitive security (`ARCHIVE_EXTRACT_SECURE_SYMLINKS`, `O_NOFOLLOW` deferred fixups).
3. **Bounds-First (确定性确界)**: Magic lifecycle tracking, `memset_s` volatile key wiping, and strict integer clamp bounds.
4. **Oracle-First (真实预言机)**: Historical golden vulnerability corpus testing and cross-ecosystem differential oracle verification.

---

## 💖 Giving Back to Upstream Open Source

TTZip is built with deep gratitude for foundational open-source compression engineering. We stand upon the work of:
- [libarchive](https://github.com/libarchive/libarchive) (Tim Kientzle, Martin Matuska)
- [XZ Utils / liblzma](https://github.com/tukaani-project/xz) (Lasse Collin, Igor Pavlov)
- [libdeflate](https://github.com/ebiggers/libdeflate) (Eric Biggers)
- [Zstandard (zstd)](https://github.com/facebook/zstd) (Yann Collet & Meta Compression Team)
- [LZ4](https://github.com/lz4/lz4) (Yann Collet)
- [7-Zip / LZMA SDK](https://www.7-zip.org) (Igor Pavlov)
- [Keka](https://github.com/aonez/Keka) (aone) & [The Unarchiver](https://theunarchiver.com) (Dag Ågren)

### 🌟 Upstream Contribution Commitments
We actively contribute generic hardware acceleration breakthroughs back to upstream projects:
- **ARM64 / Apple Silicon SIMD Vectorization**: Sharing 4-way unrolled Galois Field polynomial multiplication (`vmull_p64`) patches and SWAR pattern matchers with foundational libraries.
- **Reproducible Test Harnesses**: Publishing zero-dependency standalone C verification suites to assist upstream maintainers in verifying ARM64 performance.

Detailed licensing attributions are documented in [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

---

## 📄 License & Community Model

TTZip is proud to support the global developer community under the **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)**.

### 🌟 Permitted Uses (100% Free for Developers)
- **100% Transparent**: All source code (`ttzip-cli`, `TTZipCore`, `CTTZipBridge`, `TTZipApp`) is open for reading, learning, security auditing, and community pull requests.
- **Free for Personal & Local Use**: You are free to run `ttzip-cli` and `TTZipApp` on your personal machines for personal, non-commercial daily tasks, development workflows, and research.
- **Upstream Open-Source Carve-Out**: Generic optimization routines contributed to upstream foundations (libarchive, XZ Utils, zstd, libdeflate) are explicitly licensed under the respective upstream project's permissive license.

### 🔴 Strict Redistribution & Anti-Copycat Prohibitions (无论免费或收费，一律严禁第三方套壳上架)
1. **No App Store Publishing (Free or Paid)**: You may **NOT** publish TTZip (or renamed forks) to the **Apple Mac App Store**, Microsoft Store, Steam, Setapp, or any marketplace — **even as a free app**. Official distribution is exclusive to the author.
2. **No Free Copycats or Traffic Siphoning**: You may NOT repackage TTZip to siphon traffic, promote advertisements, or bundle with third-party software.
3. **No Commercial Resale or Cloud SaaS**: You may NOT embed TTZip into paid commercial products or SaaS services without an Enterprise Commercial License.

### 💼 Enterprise Commercial Licensing
Commercial entities wishing to integrate TTZip into proprietary commercial products, paid services, or enterprise-wide automated production environments must purchase a **Commercial Enterprise License**. Inquiries: `kevintungs@163.com`.

---

© 2026 Weitao Kung (Witt Kung). All rights reserved.
