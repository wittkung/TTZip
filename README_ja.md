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
  Safe Rust マイクロカーネル (<code>ttzip-glue</code> &rarr; <code>TTZipVendor.xcframework</code>)、SOTA コーデック群、Dual-ISA ハードウェア SIMD / PMULL ベクトルアクセラレーション、および Swift 6 macOS GUI シェル &amp; CLI (<code>TTZipApp</code>, <code>TTZipCLI</code>, <code>TTZipCore</code>) を採用。
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

## 🌟 主な特徴とアーキテクチャ設計

- **🚀 デュアルコア・マイクロカーネル設計 (Swift 6 + Safe Rust)**: メモリ安全な高スループット Rust ネイティブエンジン (`rust/ttzip-glue` を `TTZipVendor.xcframework` にコンパイル)、ゼロオーバーヘッドの標準化 C-ABI (`CTTZipBridge`) による相互運用、Swift 6 完全並行性オーケストレーション (`TTZipCore`)、およびネイティブデスクトップ GUI (`TTZipApp`)、POSIX CLI (`ttzip-cli`)、ベンチマークスイート (`ttzip-bench`) で構成。
- **⚡️ 63+ GB/s ハードウェア Dual-ISA ベクトルアクセラレーション**:
  - **63,232 MB/s (63.2 GB/s) CRC32**: ARM64 多項式乗算 (`vmull_p64` / `__crc32d`) および x86_64 PCLMULQDQ ワイドフォールディング演算。
  - **36,017 MB/s (36.0 GB/s) CRC64**: Dual-ISA ベクトル化 ECMA-182 チェックサム。
  - **AES-256 ベクトルパイプライン**: ハードウェア暗号化命令によるメモリバス帯域幅での ZIP / 7Z 暗号化・復号。
- **🏎 SOTA 最適コーデックマトリクス**:
  - **Deflate (libdeflate)**: 単一コア圧縮 4,742 MB/s (L1) / 展開 34,060 MB/s (L9)。
  - **Zstandard (Zstd)**: 圧縮 7,452 MB/s / 展開 29,046 MB/s (L3)。
  - **Google Snappy**: 圧縮 10,259 MB/s / 展開 26,254 MB/s。
  - **Fast-LZMA2 (FL2)**: マルチスレッド極限圧縮と高度なマッチファインダー。
  - **Apple LZFSE, Brotli, Bzip2 & Zopfli DAG 最適化**: macOS ネイティブ高速化、Web ストリーミングコーデック、最短経路グラフ最適化。
- **🔍 サブナノ秒仮想ファイルシステム (VFS) マイクロカーネル**:
  - **定数時間マジックナンバー識別**: 4.28億回/秒で100以上のファイル形式を即時判定。
  - **自然順数値ソート**: 3,218万回/秒の自然順比較（`img_2.png` < `img_10.png`）。
  - **Radix アーカイブツリー検索**: 5,000ノードの階層検索を **308マイクロ秒 (0.3 ms)** で完了。
  - **ゼロディスク I/O メモリプレビュー**: 一時ファイルを作成せず、メモリバッファへ直接展開。
- **🛡 メモリ安全性と前方誤り訂正 (FEC)**:
  - **DSE 耐性メモリ消去 (4,254 MB/s)**: Volatile ポインタによる物理消去で暗号鍵の残留を防止。
  - **Reed-Solomon リカバリレコード (1,382 MB/s)**: Galois 体 GF(2^8) 誤り訂正による破損アーカイブ自己修復。
  - **パニック分離耐性**: `catch_unwind` による堅牢な FFI 境界でホストプロセスを保護。

---

## 📦 対応アーカイブフォーマット（16種フルマトリクス）

| フォーマット分類 | 形式 | 圧縮作成 (Rust/Swift エンジン) | 展開抽出 (Safe エンジン) | メモリ即時プレビュー | 分割マルチボリューム |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **現代標準** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (マルチコア並行) | ✅ (ハードウェア SIMD) | ✅ (0 ディスク I/O) | ✅ (`.z01`, `.001`) |
| **高圧縮率** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip` | ✅ | ✅ | ✅ | ✅ |
| **超高速ストリーム** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - |
| **システムイメージ** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - |
| **分割ボリューム** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ |
| **プロプライエタリ** | `.rar`, `.cbr`, `.zipx`, `.cab` | 閲覧のみ | ✅ | ✅ | - |

---

## 📈 実機パフォーマンステスト結果 (`ttzip-bench matrix`)

*テスト環境：Apple Silicon Mシリーズチップ、macOS 14+、Swift 6.0 & Rust Cargo `-O3` Release ビルド*

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

## ⚡️ クイックインストール & ビルド手順

### 1. Homebrew によるインストール

```bash
brew install wittkung/ttzip/ttzip-cli
```

### 2. ワンクリック・ネイティブビルド & インストール

1行のコマンドで `TTZip.app` を `/Applications` にインストールし、`ttzip` / `ttzip-cli` をシステム PATH に自動登録します：

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# 選択肢 A: Makefile 経由でビルド & インストール
make reinstall

# 選択肢 B: Finder からダブルクリックまたはターミナルから直接実行
./Install-TTZip.command
```

### 3. Swift Package Manager (SwiftPM) によるビルド

```bash
# すべての Release 成果物 (TTZipApp, ttzip-cli, ttzip-bench) をビルド
swift build -c release
```

### 4. Rust コア・マイクロカーネル (`ttzip-glue`) のビルド

```bash
# Universal 静的ライブラリを自動ビルドし Vendor XCFramework に配置
./scripts/build_rust.sh

# または Cargo から直接ビルド
cargo build --manifest-path rust/Cargo.toml --release
```

### 5. ローカル CI 統合テストの実行（クラウドクォータ消費 0）

```bash
./scripts/run_local_ci_gate.sh
```

---

## 💻 CLI 活用ガイド (`ttzip-cli`)

`ttzip-cli` はパイプラインやストリーミング処理に対応した POSIX サブコマンドを提供します：

### 基本的な使用例

```bash
# 1. 高性能コーデックによるアーカイブ作成
ttzip-cli archive backup.zip file1.txt docs/ photos/
ttzip-cli archive output.tar.zst /path/to/source --level 9

# 2. マルチコア並行展開
ttzip-cli extract archive.tar.zst -o ./extracted/
ttzip-cli extract archive.7z

# 3. アーカイブ CRC & 整合性検証
ttzip-cli test archive.zip

# 4. アーカイブ内ファイル一覧およびメタデータ確認
ttzip-cli list archive.zip
ttzip-cli inspect archive.7z

# 5. インタラクティブ TUI アーカイブブラウザの起動
ttzip-cli explore archive.zip

# 6. 破損アーカイブの救出と修復
ttzip-cli repair damaged.zip -o repaired.zip
```

### サブコマンド一覧

| コマンド | エイリアス | 使用例 | 説明 |
| :--- | :--- | :--- | :--- |
| `archive` | `create`, `a`, `c` | `ttzip-cli archive <out> <inputs...>` | SOTA コーデックとマルチコア並行圧縮によるアーカイブ作成 |
| `extract` | `x`, `e` | `ttzip-cli extract <archive> [-o dir]` | 安全なパーミッション処理を備えた高速並行展開 |
| `test` | `t`, `verify` | `ttzip-cli test <archive>` | CRC、ヘッダー、コンテナ構造の完全性検証 |
| `list` | `l`, `ls` | `ttzip-cli list <archive>` | ファイル一覧、圧縮サイズ、属性の表示 |
| `inspect` | `i`, `info` | `ttzip-cli inspect <archive>` | コンテナメタデータ、コーデック、圧縮率の詳細診断 |
| `explore` | `tui`, `browse` | `ttzip-cli explore <archive>` | フルスクリーン TUI アーカイブナビゲータの起動 |
| `repair` | `recover` | `ttzip-cli repair <damaged> -o <fixed>` | 破損した Central Directory の再構築とエントリ救出 |
| `bench` | `b`, `benchmark` | `ttzip-cli bench` | ベクトル命令とコーデックのスループットベンチマーク実行 |

---

## 📊 ベンチマーク & テレメトリガイド (`ttzip-bench`)

`ttzip-bench` は Rust Native C-ABI を介して通信する高性能インメモリ・マイクロベンチマークおよび CI 性能ゲートツールです：

```bash
# 1. 全エンジン対象のインメモリ・ベンチマークマトリクス実行
swift run ttzip-bench matrix

# 2. 自動回帰ゲートチェックの実行 (CI/CD 安定性検証)
swift run ttzip-bench gate

# 3. 構造化 JSON テレメトリ、インタラクティブ Pareto SVG、Zen UI ダッシュボードの生成
swift run ttzip-bench plot --json-out telemetry.json --svg-out pareto.svg --html-out dashboard.html
```

---

## 💖 オープンソースへの還元

TTZip はオープンソースの理念に基づき、検証済みのハードウェア高速化とアーキテクチャ改善を主要な上流プロジェクトへ還元しています：
- [libarchive](https://github.com/libarchive/libarchive) (Tim Kientzle, Martin Matuska)
- [XZ Utils / liblzma](https://github.com/tukaani-project/xz) (Lasse Collin, Igor Pavlov)
- [libdeflate](https://github.com/ebiggers/libdeflate) (Eric Biggers)
- [Zstandard (zstd)](https://github.com/facebook/zstd) (Yann Collet & Meta Compression Team)
- [LZ4](https://github.com/lz4/lz4) (Yann Collet)
- [7-Zip / LZMA SDK](https://www.7-zip.org) (Igor Pavlov)

### 🌟 上流コントリビューション成果
- **[`libarchive/libarchive`](https://github.com/libarchive/libarchive)**:
  - ✅ **ARMv8 ACLE ハードウェア CRC32 加速とアーキテクチャ統合** ([PR #3391](https://github.com/libarchive/libarchive/pull/3391) — **`master` にマージ済み**, Commit [`8e439b92`](https://github.com/libarchive/libarchive/commit/8e439b92787c8104e22c5958caf0a7ef9532567f))
  - 🔄 **7-Zip AES-256-CBC ストリーム復号パイプライン** ([PR #3388](https://github.com/libarchive/libarchive/pull/3388))
  - 💡 **POSIX 領域事前割り当てヒューリスティクス** ([PR #3393](https://github.com/libarchive/libarchive/pull/3393))
- **[`zlib-ng/zlib-ng`](https://github.com/zlib-ng/zlib-ng)**:
  - 🔄 **ARM64 NEON `compare256` 最長一致ベクトル化と I-Cache 最適化** ([PR #2416](https://github.com/zlib-ng/zlib-ng/pull/2416)): `vmaxvq_u8` によるスライディングウィンドウ比較の高速化（長一致レイテンシ -19%〜-25% 低減、I-Cache 占有の最小化）。

---

## 📄 ライセンスと利用規約

TTZip は **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)** に基づいて公開されています。

- **開発者および個人利用は無料**: 学習、コードレビュー、研究、個人の日常利用において自由に利用可能です。
- **無断転載・再パッケージ化の禁止**: 無料・有料を問わず、App Store や Steam などへの無断公開・転載を禁止します。
- **商用ライセンスの問い合わせ**: `witt.w.kung@gmail.com`

---

© 2026 Witt Kung. All rights reserved.
