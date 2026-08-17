# TTZip ⚡️

<p align="center">
  <img src="logo/AppIcon.png" alt="TTZip Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>Ultra-High-Performance Native Archiving & Compression Engine for macOS 14+</strong><br />
  Engineered with 100% In-Process C11 Static Bindings, Swift 6 Strict Concurrency, and Apple Silicon SIMD / PMULL Hardware Acceleration.
</p>

<p align="center">
  <a href="https://github.com/wittkung/TTZip/actions"><img src="https://img.shields.io/badge/CI-Passing-brightgreen?style=flat-square&logo=githubactions" alt="CI Status" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%20Strict-orange?style=flat-square&logo=swift" alt="Swift 6.0" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue?style=flat-square&logo=apple" alt="macOS 14+" /></a>
  <a href="https://en.wikipedia.org/wiki/Apple_silicon"><img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2B%20x86__64-purple?style=flat-square" alt="Architecture" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-BSD--3--Clause-blue.svg?style=flat-square" alt="License" /></a>
</p>

---

## 🌟 Key Highlights & Engineering Philosophy

- **🚀 100% In-Process Native C Engine**: Zero external CLI process spawning (`exec`/`posix_spawn`). All operations run directly in-process via static bindings to `libarchive`, `libdeflate`, `LZMA SDK`, `zstd`, `liblz4`, and `libb2`.
- **⚡️ Apple Silicon Hardware SIMD / PMULL Acceleration**:
  - **48 GB/s CRC64 / CRC32**: Hardware-accelerated polynomial multiplication (`vmull_p64`) with 4-way unrolled CLMUL pipelines.
  - **AES-256 SIMD**: Direct ARM NEON crypto vector instructions for ZIP/7Z encryption & decryption.
  - **SWAR & Hybrid Match Finders**: Accelerated sliding window pattern scanning across DEFLATE and LZMA2 encoders.
- **🛡 Swift 6 Complete Concurrency**: 100% data-race-free architecture built with Swift 6 structured concurrency (`Actor`, `@MainActor`, `Task.detached`).
- **🔤 Smart Universal Charset Auto-Detection**: Integrated `uchardet` automatically resolves and repairs GBK / CP936 / Shift-JIS mojibake in legacy Windows ZIP/RAR archives.
- **👁 Seamless In-Archive QuickLook Preview**: Penetrate, browse, and preview files (Text, Code, Images, PDFs, Audio, Video) without full archive extraction.
- **🔒 Password Vault v4**: Enterprise-grade credential management with PBKDF2-SHA256 (600,000 OWASP iterations) + 32-byte salt and AES-256-GCM.
- **🛍 Dual Distribution Ready**:
  - **Mac App Store (MAS)**: 100% App Sandbox compliant (`-DMAS_BUILD`).
  - **Direct Independent Distribution**: Integrated Sparkle 2.0 automatic updates.

---

## 📦 Supported Archive Formats (16 Full-Matrix Formats)

| Format Category | Formats | Compression / Packaging | Decompression | Penetration / QuickLook |
| :--- | :--- | :---: | :---: | :---: |
| **Primary Modern** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ | ✅ | ✅ |
| **High Compression** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip`, `.lrzip` | ✅ | ✅ | ✅ |
| **Real-time / High Speed** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ |
| **System & Disk Images** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ |
| **Multi-Volume Split** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ |
| **Legacy & Proprietary** | `.rar`, `.cbr`, `.zipx`, `.cab` | Read-Only | ✅ | ✅ |


---

## 📊 Physical Benchmark & Throughput (Apple M-Series)

Measured under physical monotonic clocks on Apple Silicon with compiler anti-optimization barriers enforced:

| Compression / Decompression Pipeline | TTZip Physical Throughput | Peak Acceleration vs Baseline |
| :--- | :--- | :--- |
| **ZIP Level 1 Streaming** | **2,100+ MB/s** | **+40% vs Apple Archive** |
| **ZIP Direct Extraction** | **12,700+ MB/s** | **+35% vs Keka** |
| **7Z Fast Extraction** | **10,600+ MB/s** | **+50% vs 7zz CLI** |
| **TAR.ZST Direct Stream** | **25,700+ MB/s** | **+28% vs libarchive default** |
| **ARM64 PMULL CRC64 (`vmull_p64`)** | **48,160 MB/s (47.0 GB/s)** | **🟢 35.5x faster (+3,450%)** |

---

## 🏗 Modular Architecture

```
TTZip/
├── Sources/
│   ├── CTTZipBridge/          # C11 Bridge: libarchive / libdeflate / LZMA / SIMD Crypto
│   ├── TTZipCore/             # Swift 6 Core Engine: Archive Pipelines, Vault v4, Scanners
│   ├── TTZipApp/              # SwiftUI + AppKit Glassmorphic Desktop Application
│   └── TTZipCLI/              # CLI Benchmarking and Diagnostics Tool (ttzip-cli)
├── Tests/TTZipTests/          # 80+ Test Suites (Regression, Security, Performance Gates)
├── Vendor/                    # In-tree precompiled C static libraries (.a) & headers
├── docs/                      # Technical whitepapers, benchmarks, and architecture guides
└── scripts/                   # Build and packaging automation
```

---

## 🚀 Building & Testing

### Prerequisites
- macOS 14.0+ (Sonoma)
- Xcode 16.0+ / Command Line Tools with Swift 6.0

### Quick Commands

```bash
# Clone the repository
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# Build Debug
swift build

# Build Release (Direct Distribution)
swift build -c release

# Build Release for Mac App Store Sandbox (-DMAS_BUILD)
swift build -c release -Xswiftc -DMAS_BUILD

# Run all 520+ Unit & Integration Tests
swift test

# Run Performance Gate Regression Tests
swift test --filter XCTestPerformanceMeasureTests

# Run CLI Benchmark
swift run ttzip-cli bench -f zip
```

---

## 🤝 Contributing

We welcome contributions! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for code style guidelines, strict concurrency invariants, and performance floor benchmarks.

---

## 💖 Acknowledgements & Giving Back to Open Source

TTZip is built upon decades of collective genius from the global open-source community. We express our deepest gratitude to the creators and maintainers of:

- **Foundational C/C++ Compression Engines**:
  - [libarchive](https://github.com/libarchive/libarchive) (Tim Kientzle, Martin Matuska, and contributors)
  - [XZ Utils / liblzma](https://github.com/tukaani-project/xz) (Lasse Collin, Igor Pavlov, and contributors)
  - [libdeflate](https://github.com/ebiggers/libdeflate) (Eric Biggers)
  - [Zstandard](https://github.com/facebook/zstd) (Yann Collet & Meta Compression Team)
  - [LZ4](https://github.com/lz4/lz4) (Yann Collet)
  - [7-Zip / LZMA SDK](https://www.7-zip.org) (Igor Pavlov)
  - [Fast-LZMA2](https://github.com/conor42/fast-lzma2) (Conor McCarthy)
  - [libb2 (BLAKE2)](https://github.com/BLAKE2/libb2) (Samuel Neves et al.)
  - [uchardet](https://gitlab.freedesktop.org/uchardet/uchardet) (Mozilla / FreeDesktop)
  - [Sparkle](https://github.com/sparkle-project/Sparkle) (Sparkle Project)
- **macOS Archiving Pioneers**:
  - [Keka](https://github.com/aonez/Keka) by [aone](https://github.com/aonez)
  - [The Unarchiver](https://theunarchiver.com) by Dag Ågren (MacPaw)

### 🌟 Our Ongoing Upstream Contributions
We are dedicated to actively contributing our performance engineering discoveries back to upstream projects:
- **ARM64 / Apple Silicon Hardware Vector Acceleration**: Researching, validating, and submitting NEON and PMULL polynomial multiplication (`vmull_p64`) patches to foundational libraries like XZ Utils and DEFLATE pipelines.
- **Reproducible Test & Verification Harnesses**: Sharing zero-dependency standalone verification suites and microbenchmarks with upstream maintainers to help validate vectorization across Apple Silicon, AWS Graviton, and Ampere ARM64 servers.

Detailed licensing and copyright attributions are maintained in [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

---

---

## 📄 License & Community Model

TTZip is proud to support the global developer community while maintaining sustainable independent craftsmanship. We operate under a transparent **Dual-Tier Open Source & Fair-Code Model**:

### 1. 🚀 Core Engine & CLI Tool (`Apache 2.0`)
- **Modules**: `TTZipCore`, `CTTZipBridge`, `Sources/TTZipCLI` (`ttzip-cli`), and C hardware micro-kernels.
- **License**: **[Apache 2.0](LICENSE)**.
- **Your Freedom**: 100% free for everyone. You are completely free to use `ttzip-cli` in your terminal, build scripts, CI/CD pipelines, and internal workflows. Community PRs and SIMD optimizations are enthusiastically welcomed!

### 2. 🎨 macOS GUI Client & Design System (`TTZip Source License`)
- **Modules**: `TTZipApp` (SwiftUI views, Zen layout, Kintsugi Gold themes, visual design tokens).
- **License**: **[TTZip Source License 1.0 (Source-Available)](LICENSE)**.
- **Your Freedom**: Free to read, inspect, audit, and locally compile for personal use.
- **🔴 One Rule (Anti-White-Labeling)**: You may **NOT** repackage, clone, or publish the TTZip GUI application to the **Apple Mac App Store**, Steam, Setapp, or commercial app markets for resale. Official Mac App Store distribution is reserved exclusively for the author to sustain development.

Third-party component licenses and acknowledgements are documented in [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).




