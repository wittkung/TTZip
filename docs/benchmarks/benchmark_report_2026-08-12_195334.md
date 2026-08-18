# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 11:53:34 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 359.2 MB/s | 411.6 MB/s | **1.1x** | 651.3 MB/s | 1684.6 MB/s | **2.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 419.1 MB/s | 588.0 MB/s | **1.4x** | 315.1 MB/s | 264.9 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 212.7 MB/s | 637.0 MB/s | **3.0x** | 645.4 MB/s | 1917.1 MB/s | **3.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 198.0 MB/s | 552.1 MB/s | **2.8x** | 315.6 MB/s | 272.3 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 640.1 MB/s | 524.3 MB/s | **0.8x** | 1038.5 MB/s | 3579.8 MB/s | **3.4x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 586.1 MB/s | 908.4 MB/s | **1.5x** | 908.6 MB/s | 717.5 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 21.9 MB/s | 791.1 MB/s | **36.1x** | 1096.2 MB/s | 4092.7 MB/s | **3.7x** |
| 拟真日志文本 (10MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 23.7 MB/s | 765.2 MB/s | **32.3x** | 1229.0 MB/s | 402.7 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.4 MB/s | 788.9 MB/s | **9.1x** | 3987.1 MB/s | 8230.8 MB/s | **2.1x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.2 MB/s | 866.9 MB/s | **10.5x** | 1868.2 MB/s | 930.5 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5.0 MB/s | 1782.4 MB/s | **355.4x** | 3948.3 MB/s | 7902.5 MB/s | **2.0x** |
| 高熵物理Payload (100MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4.9 MB/s | 990.6 MB/s | **202.3x** | 1800.3 MB/s | 927.7 MB/s | **0.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1023.0 MB/s | 472.9 MB/s | **0.5x** | 1688.0 MB/s | 6203.3 MB/s | **3.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1042.6 MB/s | 567.6 MB/s | **0.5x** | 1986.6 MB/s | 1399.3 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 26.7 MB/s | 502.2 MB/s | **18.8x** | 1584.0 MB/s | 10298.6 MB/s | **6.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 26.6 MB/s | 514.8 MB/s | **19.4x** | 2074.1 MB/s | 1448.0 MB/s | **0.7x** |
