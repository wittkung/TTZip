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
  <strong>초고성능 네이티브 크로스 플랫폼 아카이빙 & 압축 마이크로커널</strong><br />
  순수 C11 독립 코어 엔진(`libttzip`), SOTA 코덱 매트릭스, Dual-ISA SIMD / PMULL 하드웨어 가속 및 초경량 Swift 6 macOS GUI 셸 기반 설계.
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

## 🌟 주요 특징 및 아키텍처

- **🚀 100% 순수 C11 독립 코어 (`libttzip.a`)**: 외부 CLI 프로세스 생성(`exec`/`posix_spawn`)을 완전히 배제하고, 아카이브 생성, 압축 해제, 트리 탐색 및 코덱 연산을 인프로세스 정적 라이브러리로 직접 실행합니다. Apple GCD에 대한 강한 종속성을 제거했습니다.
- **⚡️ 63+ GB/s 하드웨어 Dual-ISA 벡터 가속**:
  - **63,232 MB/s (63.2 GB/s) CRC32**: ARM64 다항식 곱셈(`vmull_p64` / `__crc32d`) 및 x86_64 PCLMULQDQ 광대역 가속.
  - **36,017 MB/s (36.0 GB/s) CRC64**: 벡터화된 ECMA-182 체크섬.
  - **AES-256 벡터 파이프라인**: 하드웨어 Crypto 명령어를 통한 메모리 버스 대역폭 수준의 암호화/복호화.
- **🏎 SOTA 최첨단 코덱 매트릭스**:
  - **Deflate (libdeflate)**: 싱글 코어 압축 4,742 MB/s (L1) / 압축 해제 34,060 MB/s (L9).
  - **Zstandard (Zstd)**: 압축 7,452 MB/s / 압축 해제 29,046 MB/s (L3).
  - **Google Snappy**: 압축 10,259 MB/s / 압축 해제 26,254 MB/s.
  - **Fast-LZMA2 (FL2)**: 멀티스레드 고압축 LZMA2.
- **🔍 나노초 단위 가상 파일 시스템 (VFS) 마이크로커널**:
  - **상수 시간 매직 넘버 감지**: 초당 4억 2,800만 회 100+ 파일 형식 즉시 식별.
  - **순수 C11 자연어 숫자 정렬**: 초당 3,218만 회 대소문자 무시 자연 정렬(`img_2.png` < `img_10.png`).
  - **Radix 아카이브 트리 검색**: 5,000개 노드 계층 검색 단 **308마이크로초 (0.3 ms)**.
  - **0 디스크 I/O 메모리 즉시 미리보기**: 임시 파일을 생성하지 않고 메모리 버퍼로 직접 압축 해제.

---

## 📈 실제 하드웨어 벤치마크 결과 (`ttzip-cli --benchmark`)

*테스트 환경: Apple Silicon M 시리즈 프로세서, macOS 14+, CMake 3.20+ Release (`-O3`)*

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

## ⚡️ 빠른 빌드 및 실행

### 1. C 마이크로커널 및 독립형 CLI 빌드 (CMake)

```bash
git clone https://github.com/wittkung/TTZip.git
cd TTZip

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j8

# 벤치마크 및 퀵스타트 실행
./build/ttzip-cli --benchmark
./build/ttzip-quickstart
```

### 2. 로컬 자동화 CI 파이프라인 실행 (클라우드 쿼터 0 소모)

```bash
./scripts/local-ci.sh
```

---

## 🛠 C SDK 1분 빠른 연동 가이드

```c
#include <stdio.h>
#include <string.h>
#include <ttzip/ttzip_api.h>

int main(void) {
    printf("TTZip 버전: %s\n", ttzip_version_string());

    const char *data = "Hello TTZip Native World!";
    uint32_t hash = ttzip_crc32(0, data, strlen(data));

    size_t comp_cap = ttzip_compress_bound(TTZIP_API_CODEC_ZSTD, strlen(data));
    uint8_t comp_buf[256];
    size_t comp_len = ttzip_compress_buffer(
        TTZIP_API_CODEC_ZSTD, data, strlen(data), comp_buf, sizeof(comp_buf), 3
    );

    ttzip_magic_info_t info = ttzip_magic_sniff_buffer(comp_buf, comp_len);
    printf("형식 식별: %s (MIME: %s)\n", info.format_name, info.mime_type);

    return 0;
}
```

---

## 📄 라이선스 및 이용 약관

TTZip은 **TTZip Source-Available & Anti-Copycat Public License v1.0 (TTZip-SAL-1.0)**에 따라 배포됩니다.

- **개발자 및 개인 무료 사용**: 학습, 연구, 코드 리뷰 및 개인 로컬 사용에 자유롭게 이용할 수 있습니다.
- **재포장 및 무단 배포 금지**: 무료/유료 여부와 무관하게 App Store, Microsoft Store, Steam 등에 무단 재배포 및 업로드가 엄격히 금지됩니다.
- **상용 라이선스 문의**: `witt.w.kung@gmail.com`

---

© 2026 Witt Kung. All rights reserved.
