<p align="center">
  <a href="README.md">English</a> |
  <a href="README_zh.md">简体中文</a> |
  <a href="README_ja.md"><strong>日本語</strong></a> |
  <a href="README_ko.md">한국어</a>
</p>

<p align="center">
  <img src="logo/AppIcon.png" alt="TTZip Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>超高速ネイティブ・クロスプラットフォーム圧縮・展開マイクロカーネル</strong><br />
  ピュア C11 スタンドアロンコア（`libttzip`）、SOTA コーデック群、Dual-ISA ハードウェア SIMD / PMULL ベクトルアクセラレーション、および軽量 Swift 6 macOS GUI シェルを採用。
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

## 🌟 主な特徴とアーキテクチャ

- **🚀 100% ピュア C11 スタンドアロンコア (`libttzip.a`)**: 外部 CLI プロセス生成（`exec`/`posix_spawn`）を完全排除。アーカイブ作成、展開、ツリー探索、コーデック処理のすべてをインプロセスで高速実行。Apple GCD への依存を排除。
- **⚡️ 63+ GB/s ハードウェア Dual-ISA ベクトルアクセラレーション**:
  - **63,232 MB/s (63.2 GB/s) CRC32**: ARM64 PMULL (`vmull_p64` / `__crc32d`) および x86_64 PCLMULQDQ 高速演算。
  - **36,017 MB/s (36.0 GB/s) CRC64**: ベクトル化された ECMA-182 多項式リダクション。
  - **AES-256 ベクトルパイプライン**: ハードウェア暗号化命令によるメモリバス速度での ZIP / 7Z 暗号化・復号。
- **🏎 SOTA 最適コーデックマトリクス**:
  - **Deflate (libdeflate)**: 単一コア圧縮 4,742 MB/s (L1) / 展開 34,060 MB/s (L9)。
  - **Zstandard (Zstd)**: 圧縮 7,452 MB/s / 展開 29,046 MB/s (L3)。
  - **Google Snappy**: 圧縮 10,259 MB/s / 展開 26,254 MB/s。
  - **Fast-LZMA2 (FL2)**: マルチコア対応の超高圧縮 LZMA2。
- **🔍 サブナノ秒仮想ファイルシステム (VFS) マイクロカーネル**:
  - **定数時間マジックナンバー識別**: 4.28億回/秒で100以上のファイル形式を即時判定。
  - **ピュア C11 自然順数値ソート**: 3,218万回/秒の自然順比較（`img_2.png` < `img_10.png`）。
  - **Radix アーカイブツリー検索**: 5,000ノードの階層検索を **308マイクロ秒 (0.3 ms)** で完了。
  - **ゼロディスク I/O メモリプレビュー**: 一時ファイルを作成せず、メモリバッファへ直接展開。

---

## 📈 実機パフォーマンステスト結果 (`ttzip-cli --benchmark`)

*テスト環境：Apple Silicon Mシリーズチップ、macOS 14+、CMake 3.20+ Release (`-O3`)*

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

## ⚡️ クイックビルド手順

### 1. C マイクロカーネルとスタンドアロン CLI のビルド (CMake)

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j8

# ベンチマークとクイックスタートの実行
./build/ttzip-cli --benchmark
./build/ttzip-quickstart
```

### 2. ローカル CI 統合テストの実行（クラウドクォータ消費 0）

```bash
./scripts/local-ci.sh
```

---

## 🛠 C SDK 1分間インテグレーション

```c
#include <stdio.h>
#include <string.h>
#include <ttzip/ttzip_api.h>

int main(void) {
    printf("TTZip バージョン: %s\n", ttzip_version_string());

    const char *data = "Hello TTZip Native World!";
    uint32_t hash = ttzip_crc32(0, data, strlen(data));

    size_t comp_cap = ttzip_compress_bound(TTZIP_API_CODEC_ZSTD, strlen(data));
    uint8_t comp_buf[256];
    size_t comp_len = ttzip_compress_buffer(
        TTZIP_API_CODEC_ZSTD, data, strlen(data), comp_buf, sizeof(comp_buf), 3
    );

    ttzip_magic_info_t info = ttzip_magic_sniff_buffer(comp_buf, comp_len);
    printf("識別フォーマット: %s (MIME: %s)\n", info.format_name, info.mime_type);

    return 0;
}
```

---

## 📄 ライセンスと利用規約

TTZip は **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)** に基づいて公開されています。

- **開発者および個人利用は無料**: 学習、コードレビュー、研究、個人の日常利用において自由に利用可能です。
- **無断転載・再パッケージ化の禁止**: 無料・有料を問わず、App Store や Steam などへの無断公開・転載を禁止します。
- **商用ライセンスの問い合わせ**: `witt.w.kung@gmail.com`

---

© 2026 Witt Kung. All rights reserved.
