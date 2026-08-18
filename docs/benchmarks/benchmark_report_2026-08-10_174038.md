# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:40:38 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 459.4 MB/s | 3563.4 MB/s | **7.8x** | 710.0 MB/s | 1263.2 MB/s | **1.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 440.0 MB/s | 2233.4 MB/s | **5.1x** | 324.3 MB/s | 1890.0 MB/s | **5.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 212.9 MB/s | 4988.8 MB/s | **23.4x** | 700.6 MB/s | 2038.6 MB/s | **2.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 206.6 MB/s | 2236.9 MB/s | **10.8x** | 321.7 MB/s | 1877.7 MB/s | **5.8x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 785.0 MB/s | 1562.6 MB/s | **2.0x** | 1228.3 MB/s | 4569.0 MB/s | **3.7x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 762.4 MB/s | 1472.8 MB/s | **1.9x** | 1346.2 MB/s | 3772.6 MB/s | **2.8x** |
| 拟真日志文本 (10MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 23.2 MB/s | 1195.3 MB/s | **51.4x** | 1179.0 MB/s | 6775.7 MB/s | **5.7x** |
| 拟真日志文本 (10MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 23.4 MB/s | 1090.6 MB/s | **46.6x** | 1247.5 MB/s | 4700.4 MB/s | **3.8x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.2 MB/s | 196.6 MB/s | **2.2x** | 3971.9 MB/s | 9023.3 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.9 MB/s | 184.6 MB/s | **2.2x** | 1835.3 MB/s | 2157.0 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4.8 MB/s | 153.3 MB/s | **31.9x** | 3985.1 MB/s | 8980.5 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4.7 MB/s | 120.5 MB/s | **25.7x** | 1807.4 MB/s | 1916.7 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.9 MB/s | 1560.2 MB/s | **1.5x** | 1733.7 MB/s | 5726.3 MB/s | **3.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1018.0 MB/s | 1616.8 MB/s | **1.6x** | 2009.6 MB/s | 7065.3 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 24.8 MB/s | 1150.7 MB/s | **46.4x** | 1646.5 MB/s | 10256.2 MB/s | **6.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 25.9 MB/s | 1113.2 MB/s | **43.0x** | 2079.1 MB/s | 5759.4 MB/s | **2.8x** |
