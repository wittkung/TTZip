# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 09:57:35 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 781.4 MB/s | 268.2 MB/s | **0.3x** | 518.7 MB/s | 2560.9 MB/s | **4.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 784.9 MB/s | 295.6 MB/s | **0.4x** | 367.9 MB/s | 2771.9 MB/s | **7.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 210.9 MB/s | 300.6 MB/s | **1.4x** | 501.8 MB/s | 2823.7 MB/s | **5.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 209.7 MB/s | 304.7 MB/s | **1.5x** | 367.4 MB/s | 2725.6 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1053.4 MB/s | 357.4 MB/s | **0.3x** | 1318.4 MB/s | 2678.6 MB/s | **2.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 840.3 MB/s | 365.5 MB/s | **0.4x** | 705.5 MB/s | 2721.3 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 220.2 MB/s | 363.0 MB/s | **1.6x** | 807.2 MB/s | 2579.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 217.8 MB/s | 360.8 MB/s | **1.7x** | 517.8 MB/s | 2504.0 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 193.5 MB/s | 1746.6 MB/s | **9.0x** | 3303.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 170.7 MB/s | 1708.3 MB/s | **10.0x** | 2329.9 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.9%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 110.7 MB/s | 1744.3 MB/s | **15.8x** | 1187.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (97.0%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 111.1 MB/s | 1754.0 MB/s | **15.8x** | 1045.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.9%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4904.5 MB/s | 2402.7 MB/s | **0.5x** | 3890.9 MB/s | 6110.8 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4893.2 MB/s | 2469.9 MB/s | **0.5x** | 4030.3 MB/s | 8326.4 MB/s | **2.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 459.3 MB/s | 2461.4 MB/s | **5.4x** | 2676.5 MB/s | 9200.6 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 464.3 MB/s | 2546.4 MB/s | **5.5x** | 2553.8 MB/s | 8719.8 MB/s | **3.4x** | - |
