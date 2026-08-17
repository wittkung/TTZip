# Acknowledgements, Inspirations & Open-Source Contributions

TTZip is built with deep reverence for the global open-source systems engineering community. We stand upon the shoulders of giants — the pioneering authors, maintainers, and researchers whose decades of dedicated work make modern high-performance data compression possible.

---

## 1. Upstream Open-Source Foundations & Core Engines

We express our sincere gratitude and highest respect to the authors and maintainers of the foundational libraries integrated within TTZip:

| Project / Library | Primary Author(s) & Maintainers | Repository & License | Role in TTZip |
| :--- | :--- | :--- | :--- |
| **[libarchive](https://github.com/libarchive/libarchive)** | Tim Kientzle, Martin Matuska & community | BSD 2-Clause | Universal multi-format container parsing and robust POSIX archive decoding (TAR, WIM, ISO, CAB, RAR). |
| **[XZ Utils / liblzma](https://github.com/tukaani-project/xz)** | Lasse Collin, Igor Pavlov & community | 0BSD / Public Domain | Industry-standard LZMA/LZMA2 decompression, header parsing, and `.xz` container processing. |
| **[libdeflate](https://github.com/ebiggers/libdeflate)** | Eric Biggers | MIT License | High-throughput DEFLATE, zlib, and gzip compressor/decompressor with SIMD-accelerated match finding. |
| **[Zstandard (zstd)](https://github.com/facebook/zstd)** | Yann Collet & Meta Compression Team | BSD 3-Clause | Real-time Zstandard compression with high-ratio dictionary matching and fast multithreaded streaming. |
| **[LZ4](https://github.com/lz4/lz4)** | Yann Collet & community | BSD 2-Clause | Ultra-fast in-memory block pre-filtering and real-time streaming pipelines. |
| **[7-Zip / LZMA SDK](https://www.7-zip.org)** | Igor Pavlov | GNU LGPL / Public Domain | Architecture reference for the 7z archive container, PPMd, BCJ2 filters, and Solid archive processing. |
| **[Fast-LZMA2](https://github.com/conor42/fast-lzma2)** | Conor McCarthy | BSD 2-Clause | Inspiration for parallel LZMA2 chunk division and fast dictionary buffer management. |
| **[libb2 (BLAKE2)](https://github.com/BLAKE2/libb2)** | Samuel Neves & BLAKE2 team | CC0 1.0 / OpenSSL | Cryptographic integrity checksums and fast hash deduplication. |
| **[uchardet](https://gitlab.freedesktop.org/uchardet/uchardet)** | Mozilla / FreeDesktop | MPL 1.1 / GPL 2.0+ / LGPL 2.1+ | Universal charset detection for legacy multilingual text encoding (GBK, CP936, Shift-JIS). |
| **[Sparkle](https://github.com/sparkle-project/Sparkle)** | Sparkle Project | MIT License | Secure automatic software update framework for macOS independent direct distribution. |

---

## 2. Pioneers & Inspirations in the macOS Archiving Ecosystem

We are deeply inspired by the trailblazers who shaped the native archiving experience on macOS:

- **[Keka](https://github.com/aonez/Keka)** by **aone**: The benchmark open-source file archiver for macOS that proved native Mac tools can be both simple and powerful.
- **[The Unarchiver](https://theunarchiver.com)** by **Dag Ågren** (MacPaw): The classic pioneer that defined seamless multi-format decompression on macOS.

---

## 3. Our Commitment: Giving Back to Upstream Open Source

TTZip is not merely a consumer of open-source libraries; **we are actively and continuously contributing our engineering breakthroughs back to the upstream projects we rely on**:

1. **Apple Silicon Hardware Acceleration**:
   - We actively research, optimize, and upstream ARM64 vectorization patches (such as 4-way unrolled Galois Field polynomial multiplication `vmull_p64` pipelines for CRC64/CRC32, accelerating checksum throughput to **48 GB/s**).
2. **Hybrid Match Finders & SWAR Optimizations**:
   - We contribute sliding-window pattern matchers and byte-parallel SWAR scanning routines back to compression foundations like XZ Utils and DEFLATE pipelines.
3. **Reproducible Benchmarks & Boundary Verification**:
   - We share zero-dependency standalone C test harnesses and mathematical boundary proofs to help upstream maintainers verify performance gains and safety invariants across different ARM64 microarchitectures (Apple Silicon M-Series, AWS Graviton, Ampere Altra).

We believe that open-source software thrives on mutual respect, rigorous engineering, and selfless reciprocity.

---

## 4. Full License Notices

### libdeflate (MIT)
```text
Copyright (c) 2016-2024 Eric Biggers
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

### Zstandard (BSD 3-Clause)
```text
Copyright (c) 2016-present, Meta Platforms, Inc. and affiliates. All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name Meta nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
```

### libarchive (BSD 2-Clause)
```text
Copyright (c) 2003-2024 Tim Kientzle and contributors. All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
```

### LZ4 (BSD 2-Clause)
```text
Copyright (c) 2011-present, Yann Collet. All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
```
