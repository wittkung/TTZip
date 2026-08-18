# TTZip Exhaustive Competitor Benchmark Report

> **Timestamp**: 2026-08-18 21:22:29 +0000
> **Environment**: Apple Silicon (18 cores [P:6 / E:12]) | macOS 版本26.6.1（版号25G76）
> **Competitors**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **Execution Model**: Competitor tools configured with full concurrency (`-mmt=on`, `-T0`, `-p max`, `-n max`), TTZip executing in-process via 16MB mmap / NEON SIMD / native C architecture

| Dataset Dimension | Archive Format | Level | Encryption | Competitor Tool | Competitor Size (Ratio) | TTZip Size (Ratio) | Competitor Comp (MB/s) | TTZip Comp (MB/s) | Comp Speedup | Competitor Extract (MB/s) | TTZip Extract (MB/s) | Extract Speedup | AOP Bottleneck Stage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Small Files (10MB/100 files) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.13 MB (1.1%) | 439.2 MB/s | 7514.5 MB/s | **17.1x** | 571.4 MB/s | 2262.7 MB/s | **4.0x** | - |
| Small Files (10MB/100 files) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.13 MB (1.1%) | 422.9 MB/s | 2292.3 MB/s | **5.4x** | 566.1 MB/s | 1920.7 MB/s | **3.4x** | - |
| Small Files (10MB/100 files) | ZIP | 6 | None | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 360.7 MB/s | 6144.6 MB/s | **17.0x** | 571.2 MB/s | 2347.3 MB/s | **4.1x** | - |
| Small Files (10MB/100 files) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 350.0 MB/s | 2030.0 MB/s | **5.8x** | 559.4 MB/s | 1967.2 MB/s | **3.5x** | - |
| Log Text (10MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.03 MB (0.4%) | 0.09 MB (1.0%) | 607.3 MB/s | 5308.6 MB/s | **8.7x** | 826.7 MB/s | 7266.6 MB/s | **8.8x** | - |
| Log Text (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.03 MB (0.4%) | 0.09 MB (1.0%) | 535.4 MB/s | 3927.6 MB/s | **7.3x** | 814.7 MB/s | 0.0 MB/s | **0.0x** | - |
| Log Text (10MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 0.03 MB (0.3%) | 0.03 MB (0.3%) | 483.9 MB/s | 3.3 MB/s | **0.0x** | 2024.5 MB/s | 7213.0 MB/s | **3.6x** | - |
| Log Text (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.5 MB/s | 1211.4 MB/s | **15.0x** | 824.5 MB/s | 4956.7 MB/s | **6.0x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 45.88 MB (91.8%) | 45.52 MB (91.0%) | 73.1 MB/s | 172.3 MB/s | **2.4x** | 225.5 MB/s | 572.2 MB/s | **2.5x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 45.88 MB (91.8%) | 45.52 MB (91.0%) | 62.6 MB/s | 160.3 MB/s | **2.6x** | 92.9 MB/s | 0.0 MB/s | **0.0x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 6 | None | 7-Zip 7zz CLI (ARM64) | 45.68 MB (91.4%) | 45.49 MB (91.0%) | 56.5 MB/s | 23.0 MB/s | **0.4x** | 247.8 MB/s | 578.4 MB/s | **2.3x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 45.68 MB (91.4%) | 45.56 MB (91.1%) | 51.7 MB/s | 133.4 MB/s | **2.6x** | 96.7 MB/s | 0.0 MB/s | **0.0x** | - |
| Structured JSON (50MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.16 MB (0.4%) | 0.39 MB (1.0%) | 848.4 MB/s | 4604.0 MB/s | **5.4x** | 1390.0 MB/s | 7277.3 MB/s | **5.2x** | - |
| Structured JSON (50MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.16 MB (0.4%) | 0.39 MB (1.0%) | 749.4 MB/s | 4172.1 MB/s | **5.6x** | 1330.3 MB/s | 0.0 MB/s | **0.0x** | - |
| Structured JSON (50MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 0.15 MB (0.4%) | 0.15 MB (0.4%) | 561.9 MB/s | 5.6 MB/s | **0.0x** | 4418.7 MB/s | 8326.0 MB/s | **1.9x** | - |
| Structured JSON (50MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.16 MB (0.4%) | 0.15 MB (0.4%) | 70.0 MB/s | 1312.3 MB/s | **18.7x** | 1306.3 MB/s | 0.0 MB/s | **0.0x** | - |
| High-Entropy Payload (100MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.1 MB/s | 168.3 MB/s | **2.0x** | 3467.7 MB/s | 9398.0 MB/s | **2.7x** | - |
| High-Entropy Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.2 MB/s | 159.5 MB/s | **2.5x** | 142.9 MB/s | 2101.8 MB/s | **14.7x** | - |
| High-Entropy Payload (100MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 78.6 MB/s | 4436.4 MB/s | **56.4x** | 5016.6 MB/s | 9901.7 MB/s | **2.0x** | - |
| High-Entropy Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 56.3 MB/s | 135.7 MB/s | **2.4x** | 142.2 MB/s | 2220.6 MB/s | **15.6x** | - |
| 500MB Large Dataset (500MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.59 MB (0.1%) | 2.04 MB (0.4%) | 1004.7 MB/s | 6104.9 MB/s | **6.1x** | 1651.9 MB/s | 5709.4 MB/s | **3.5x** | - |
| 500MB Large Dataset (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.59 MB (0.1%) | 2.04 MB (0.4%) | 875.7 MB/s | 6628.2 MB/s | **7.6x** | 1612.2 MB/s | 6510.1 MB/s | **4.0x** | - |
| 500MB Large Dataset (500MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 0.49 MB (0.1%) | 0.48 MB (0.1%) | 588.9 MB/s | 110.1 MB/s | **0.2x** | 3578.8 MB/s | 7529.7 MB/s | **2.1x** | - |
| 500MB Large Dataset (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.9 MB/s | 1294.1 MB/s | **14.1x** | 1472.4 MB/s | 7879.4 MB/s | **5.4x** | - |
