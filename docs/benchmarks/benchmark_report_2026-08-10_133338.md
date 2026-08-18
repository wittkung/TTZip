# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 05:33:38 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1934.0 MB/s | 3860.5 MB/s | **2.0x** | 919.2 MB/s | 1063.9 MB/s | **1.2x** |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 218.9 MB/s | 3860.5 MB/s | **17.6x** | 285.6 MB/s | 1063.9 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 2118.2 MB/s | 3261.8 MB/s | **1.5x** | 1036.4 MB/s | 1414.9 MB/s | **1.4x** |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 235.9 MB/s | 3261.8 MB/s | **13.8x** | 305.4 MB/s | 1414.9 MB/s | **4.6x** |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 2846.1 MB/s | 7106.8 MB/s | **2.5x** | 2891.3 MB/s | 7645.8 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | BSD tar (Native) | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1066.0 MB/s | 7106.8 MB/s | **6.7x** | 1262.6 MB/s | 7645.8 MB/s | **6.1x** |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 2513.9 MB/s | 8479.3 MB/s | **3.4x** | 2678.0 MB/s | 8422.0 MB/s | **3.1x** |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | BSD tar (Native) | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 786.3 MB/s | 8479.3 MB/s | **10.8x** | 953.0 MB/s | 8422.0 MB/s | **8.8x** |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5129.4 MB/s | 9114.5 MB/s | **1.8x** | 5622.5 MB/s | 7276.7 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1852.2 MB/s | 9114.5 MB/s | **4.9x** | 1588.5 MB/s | 7276.7 MB/s | **4.6x** |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6937.0 MB/s | 9783.0 MB/s | **1.4x** | 7711.2 MB/s | 9110.1 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1994.2 MB/s | 9783.0 MB/s | **4.9x** | 2254.4 MB/s | 9110.1 MB/s | **4.0x** |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 8267.7 MB/s | 10160.1 MB/s | **1.2x** | 9251.7 MB/s | 9865.1 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 2517.2 MB/s | 10160.1 MB/s | **4.0x** | 2399.6 MB/s | 9865.1 MB/s | **4.1x** |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 8297.5 MB/s | 10267.4 MB/s | **1.2x** | 9201.2 MB/s | 9971.5 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 2523.4 MB/s | 10267.4 MB/s | **4.1x** | 2394.1 MB/s | 9971.5 MB/s | **4.2x** |
