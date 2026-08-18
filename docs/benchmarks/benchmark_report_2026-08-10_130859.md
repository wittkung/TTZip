# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 05:08:59 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 538.2 MB/s | 7237.6 MB/s | **13.4x** | 703.4 MB/s | 1847.5 MB/s | **2.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 476.7 MB/s | 2468.8 MB/s | **5.2x** | 328.6 MB/s | 1842.0 MB/s | **5.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 224.5 MB/s | 7574.2 MB/s | **33.7x** | 686.3 MB/s | 1946.0 MB/s | **2.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 209.9 MB/s | 2236.2 MB/s | **10.7x** | 321.4 MB/s | 1625.8 MB/s | **5.1x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 803.4 MB/s | 1657.4 MB/s | **2.1x** | 1240.9 MB/s | 7919.2 MB/s | **6.4x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 741.2 MB/s | 1460.8 MB/s | **2.0x** | 1304.0 MB/s | 5283.2 MB/s | **4.1x** |
| 拟真日志文本 (10MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 24.6 MB/s | 1165.4 MB/s | **47.4x** | 1197.2 MB/s | 8352.7 MB/s | **7.0x** |
| 拟真日志文本 (10MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 24.7 MB/s | 1145.8 MB/s | **46.5x** | 1318.7 MB/s | 6015.5 MB/s | **4.6x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 92.4 MB/s | 203.0 MB/s | **2.2x** | 4425.4 MB/s | 9389.9 MB/s | **2.1x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.5 MB/s | 189.2 MB/s | **2.2x** | 2009.2 MB/s | 2409.9 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4.9 MB/s | 158.8 MB/s | **32.2x** | 4203.5 MB/s | 11257.0 MB/s | **2.7x** |
| 高熵物理Payload (100MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4.9 MB/s | 147.3 MB/s | **30.3x** | 1877.2 MB/s | 2282.2 MB/s | **1.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1053.5 MB/s | 1678.4 MB/s | **1.6x** | 1827.1 MB/s | 10937.6 MB/s | **6.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1045.9 MB/s | 1674.8 MB/s | **1.6x** | 2087.4 MB/s | 10893.7 MB/s | **5.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 26.0 MB/s | 1165.6 MB/s | **44.9x** | 1786.4 MB/s | 12286.6 MB/s | **6.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 26.4 MB/s | 1165.8 MB/s | **44.2x** | 2118.2 MB/s | 11480.3 MB/s | **5.4x** |
