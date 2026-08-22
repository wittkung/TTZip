<p align="center">
  <a href="README.md">English</a> |
  <a href="README_zh.md">简体中文</a> |
  <a href="README_ja.md">日本語</a> |
  <a href="README_ko.md"><strong>한국어</strong></a>
</p>

<p align="center">
  <img src="logo/AppIcon.png" alt="TTZip Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>초고성능 네이티브 크로스 플랫폼 아카이빙 &amp; 압축 마이크로커널</strong><br />
  Safe Rust 마이크로커널 (<code>ttzip-glue</code> &rarr; <code>TTZipVendor.xcframework</code>), SOTA 코덱 매트릭스, Dual-ISA SIMD / PMULL 하드웨어 가속 및 Swift 6 macOS GUI 셸 &amp; CLI (<code>TTZipApp</code>, <code>TTZipCLI</code>, <code>TTZipCore</code>) 기반 설계.
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

## 🌟 주요 특징 및 아키텍처 설계

- **🚀 듀얼 코어 마이크로커널 아키텍처 (Swift 6 + Safe Rust)**: 고처리량 메모리 안전 Rust 네이티브 엔진(`rust/ttzip-glue`를 `TTZipVendor.xcframework`로 컴파일), 제로 오버헤드 표준화 C-ABI(`CTTZipBridge`) 브리지, Swift 6 완전 동시성 도메인 오케스트레이션(`TTZipCore`), 네이티브 데스크톱 GUI(`TTZipApp`), POSIX CLI(`ttzip-cli`), 벤치마크 스위트(`ttzip-bench`)로 구성.
- **⚡️ 63+ GB/s 하드웨어 Dual-ISA 벡터 가속**:
  - **63,232 MB/s (63.2 GB/s) CRC32**: ARM64 다항식 곱셈(`vmull_p64` / `__crc32d`) 및 x86_64 PCLMULQDQ 광대역 폴딩 가속.
  - **36,017 MB/s (36.0 GB/s) CRC64**: Dual-ISA 벡터화 ECMA-182 체크섬.
  - **AES-256 벡터 파이프라인**: 하드웨어 Crypto 명령어를 통한 메모리 버스 대역폭 수준의 ZIP / 7Z 암호화/복호화.
- **🏎 SOTA 최첨단 코덱 매트릭스**:
  - **Deflate (libdeflate)**: 싱글 코어 압축 4,742 MB/s (L1) / 압축 해제 34,060 MB/s (L9).
  - **Zstandard (Zstd)**: 압축 7,452 MB/s / 압축 해제 29,046 MB/s (L3).
  - **Google Snappy**: 압축 10,259 MB/s / 압축 해제 26,254 MB/s.
  - **Fast-LZMA2 (FL2)**: 멀티스레드 고압축 LZMA2 및 혁신적인 매치 파인더.
  - **Apple LZFSE, Brotli, Bzip2 & Zopfli DAG 그래프 최적화**: macOS 네이티브 가속, 웹 스트리밍 코덱, 최단 경로 그래프 최적화.
- **🔍 나노초 단위 가상 파일 시스템 (VFS) 마이크로커널**:
  - **상수 시간 매직 넘버 감지**: 초당 4억 2,800만 회 100+ 파일 형식 즉시 식별.
  - **자연어 숫자 정렬**: 초당 3,218만 회 대소문자 무시 자연 정렬(`img_2.png` < `img_10.png`).
  - **Radix 아카이브 트리 검색**: 5,000개 노드 계층 검색 단 **308마이크로초 (0.3 ms)**.
  - **0 디스크 I/O 메모리 즉시 미리보기**: 임시 파일을 생성하지 않고 메모리 버퍼로 직접 압축 해제.
- **🛡 메모리 보안 및 순방향 오류 정정 (FEC)**:
  - **DSE 방지 메모리 초기화 (4,254 MB/s)**: Volatile 포인터 물리 초기화로 메모리 암호 키 잔류 방지.
  - **리드-솔로몬 복구 레코드 (1,382 MB/s)**: Galois 체 GF(2^8) 오류 정정 알고리즘을 통한 손상 아카이브 자체 복구.
  - **패닉 격리 탄력성**: `catch_unwind` 격리를 갖춘 견고한 FFI 경계로 호스트 프로세스 보호.

---

## 📦 지원 아카이브 형식 (16종 전체 매트릭스)

| 형식 분류 | 지원 포맷 | 아카이브 생성 (Rust/Swift 엔진) | 압축 해제 (Safe 엔진) | 메모리 즉시 미리보기 | 분할 볼륨 지원 |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **최신 표준** | `.zip`, `.7z`, `.tar`, `.tar.zst` | ✅ (멀티코어 병렬) | ✅ (하드웨어 SIMD) | ✅ (0 디스크 I/O) | ✅ (`.z01`, `.001`) |
| **고압축률** | `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.lzip` | ✅ | ✅ | ✅ | ✅ |
| **초고속 스트림** | `.lz4`, `.brotli`, `.snappy`, `.aar` | ✅ | ✅ | ✅ | - |
| **시스템 이미지** | `.dmg`, `.iso`, `.wim` | ✅ | ✅ | ✅ | - |
| **분할 볼륨** | `.7z.001`, `.zip.001`, `.001` | ✅ | ✅ | ✅ | ✅ |
| **독점/레거시** | `.rar`, `.cbr`, `.zipx`, `.cab` | 읽기 전용 | ✅ | ✅ | - |

---

## 📈 실제 하드웨어 벤치마크 결과 (`ttzip-bench matrix`)

*테스트 환경: Apple Silicon M 시리즈 프로세서, macOS 14+, Swift 6.0 & Rust Cargo `-O3` Release 빌드*

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

## ⚡️ 빠른 설치 및 빌드 가이드

### 1. Homebrew를 통한 설치

```bash
brew install wittkung/ttzip/ttzip-cli
```

### 2. 원클릭 네이티브 빌드 & 설치

단 한 줄의 명령어로 `TTZip.app`을 `/Applications`에 설치하고 `ttzip` / `ttzip-cli` 명령어를 시스템 PATH에 등록합니다:

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# 옵션 A: Makefile을 통한 빌드 및 설치
make reinstall

# 옵션 B: Finder에서 더블 클릭하거나 터미널에서 직접 실행
./Install-TTZip.command
```

### 3. Swift Package Manager (SwiftPM) 빌드

```bash
# 전체 Release 산출물 빌드 (TTZipApp, ttzip-cli, ttzip-bench)
swift build -c release
```

### 4. Rust 코어 마이크로커널 (`ttzip-glue`) 빌드

```bash
# Universal 정적 라이브러리 자동 빌드 및 Vendor XCFramework 배포
./scripts/build_rust.sh

# 또는 Cargo를 통해 직접 빌드
cargo build --manifest-path rust/Cargo.toml --release
```

### 5. 로컬 자동화 CI 파이프라인 실행 (클라우드 쿼터 0 소모)

```bash
./scripts/run_local_ci_gate.sh
```

---

## 💻 CLI 활용 가이드 (`ttzip-cli`)

`ttzip-cli`는 파이프라인 및 스트리밍 처리를 지원하는 표준 POSIX 서브커맨드를 제공합니다:

### 기본 사용 예시

```bash
# 1. 고성능 코덱을 통한 아카이브 생성
ttzip-cli archive backup.zip file1.txt docs/ photos/
ttzip-cli archive output.tar.zst /path/to/source --level 9

# 2. 멀티코어 병렬 압축 해제
ttzip-cli extract archive.tar.zst -o ./extracted/
ttzip-cli extract archive.7z

# 3. 아카이브 CRC 및 무결성 검증
ttzip-cli test archive.zip

# 4. 아카이브 파일 목록 및 메타데이터 조회
ttzip-cli list archive.zip
ttzip-cli inspect archive.7z

# 5. 대화형 터미널 TUI 아카이브 탐색기 실행
ttzip-cli explore archive.zip

# 6. 손상된 아카이브 복구 및 구출
ttzip-cli repair damaged.zip -o repaired.zip
```

### 서브커맨드 요약표

| 명령어 | 별칭 | 사용 예시 | 설명 |
| :--- | :--- | :--- | :--- |
| `archive` | `create`, `a`, `c` | `ttzip-cli archive <out> <inputs...>` | SOTA 코덱 및 멀티코어 병렬 압축으로 아카이브 생성 |
| `extract` | `x`, `e` | `ttzip-cli extract <archive> [-o dir]` | 안전한 권한 매핑을 지원하는 초고속 병렬 압축 해제 |
| `test` | `t`, `verify` | `ttzip-cli test <archive>` | CRC, 헤더 및 컨테이너 구조 무결성 검증 |
| `list` | `l`, `ls` | `ttzip-cli list <archive>` | 파일 목록, 압축 크기 및 파일 속성 출력 |
| `inspect` | `i`, `info` | `ttzip-cli inspect <archive>` | 컨테이너 메타데이터, 코덱 유형, 압축률 정밀 진단 |
| `explore` | `tui`, `browse` | `ttzip-cli explore <archive>` | 전체 화면 대화형 TUI 아카이브 브라우저 실행 |
| `repair` | `recover` | `ttzip-cli repair <damaged> -o <fixed>` | 손상된 Central Directory 재구축 및 파일 항목 구출 |
| `bench` | `b`, `benchmark` | `ttzip-cli bench` | 벡터 명령어 및 코덱 처리량 벤치마크 실행 |

---

## 📊 벤치마크 & 텔레메트리 가이드 (`ttzip-bench`)

`ttzip-bench`는 Rust Native C-ABI를 통해 연동되는 고성능 인메모리 마이크로 벤치마크 및 CI 성능 게이트 도구입니다:

```bash
# 1. 전체 엔진 대상 인메모리 벤치마크 매트릭스 실행
swift run ttzip-bench matrix

# 2. 자동 회귀 게이트 검증 실행 (CI/CD 무결성 검증)
swift run ttzip-bench gate

# 3. 구조화된 JSON 텔레메트리, 대화형 Pareto SVG, Zen UI 독립형 HTML 대시보드 생성
swift run ttzip-bench plot --json-out telemetry.json --svg-out pareto.svg --html-out dashboard.html
```

---

## 💖 오픈소스 기여 및 환원

TTZip은 오픈소스 정신에 따라 검증된 하드웨어 가속 및 아키텍처 최적화 루틴을 상위 핵심 프로젝트에 적극 기여하고 있습니다:
- [libarchive](https://github.com/libarchive/libarchive) (Tim Kientzle, Martin Matuska)
- [XZ Utils / liblzma](https://github.com/tukaani-project/xz) (Lasse Collin, Igor Pavlov)
- [libdeflate](https://github.com/ebiggers/libdeflate) (Eric Biggers)
- [Zstandard (zstd)](https://github.com/facebook/zstd) (Yann Collet & Meta Compression Team)
- [LZ4](https://github.com/lz4/lz4) (Yann Collet)
- [7-Zip / LZMA SDK](https://www.7-zip.org) (Igor Pavlov)

### 🌟 상위 프로젝트 기여 성과
- **[`libarchive/libarchive`](https://github.com/libarchive/libarchive)**:
  - ✅ **ARMv8 ACLE 하드웨어 CRC32 가속 및 아키텍처 통합** ([PR #3391](https://github.com/libarchive/libarchive/pull/3391) — **`master` 병합 완료**, Commit [`8e439b92`](https://github.com/libarchive/libarchive/commit/8e439b92787c8104e22c5958caf0a7ef9532567f))
  - 🔄 **7-Zip AES-256-CBC 스트리밍 복호화 파이프라인** ([PR #3388](https://github.com/libarchive/libarchive/pull/3388))
  - 💡 **POSIX 디스크 공간 사전 할당 휴리스틱 최적화** ([PR #3393](https://github.com/libarchive/libarchive/pull/3393))
- **[`zlib-ng/zlib-ng`](https://github.com/zlib-ng/zlib-ng)**:
  - 🔄 **ARM64 NEON `compare256` 최장 일치 벡터화 및 I-Cache 최적화** ([PR #2416](https://github.com/zlib-ng/zlib-ng/pull/2416)): `vmaxvq_u8` 기반 슬라이딩 윈도우 패턴 비교 최적화(긴 일치 지연 시간 -19% ~ -25% 단축, 최소 I-Cache 점유율 유지).

---

## 📄 라이선스 및 이용 약관

TTZip은 **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)**에 따라 배포됩니다.

- **개발자 및 개인 무료 사용**: 학습, 연구, 코드 리뷰 및 개인 로컬 사용에 자유롭게 이용할 수 있습니다.
- **재포장 및 무단 배포 금지**: 무료/유료 여부와 무관하게 App Store, Microsoft Store, Steam 등에 무단 재배포 및 업로드가 엄격히 금지됩니다.
- **상용 라이선스 문의**: `witt.w.kung@gmail.com`

---

© 2026 Witt Kung. All rights reserved.
