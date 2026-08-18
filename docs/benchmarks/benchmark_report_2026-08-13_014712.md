# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 17:47:12 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1020.1 MB/s | 163.4 MB/s | **0.2x** | 869.3 MB/s | 1889.7 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1029.9 MB/s | 191.9 MB/s | **0.2x** | 625.0 MB/s | 2051.1 MB/s | **3.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 297.4 MB/s | 197.8 MB/s | **0.7x** | 719.6 MB/s | 2023.6 MB/s | **2.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 273.8 MB/s | 194.5 MB/s | **0.7x** | 532.3 MB/s | 2013.3 MB/s | **3.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1303.2 MB/s | 211.4 MB/s | **0.2x** | 2081.3 MB/s | 1994.9 MB/s | **1.0x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1155.8 MB/s | 206.9 MB/s | **0.2x** | 989.0 MB/s | 1956.7 MB/s | **2.0x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 305.2 MB/s | 204.6 MB/s | **0.7x** | 1185.1 MB/s | 2021.0 MB/s | **1.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 298.7 MB/s | 192.6 MB/s | **0.6x** | 759.2 MB/s | 1888.8 MB/s | **2.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 221.6 MB/s | 2357.2 MB/s | **10.6x** | 4396.8 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (71.5%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 194.7 MB/s | 2384.8 MB/s | **12.3x** | 3413.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (81.7%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 126.8 MB/s | 2331.7 MB/s | **18.4x** | 1593.8 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (86.1%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 127.6 MB/s | 1993.8 MB/s | **15.6x** | 1516.0 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (88.3%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4892.8 MB/s | 2123.2 MB/s | **0.4x** | 4813.7 MB/s | 6695.5 MB/s | **1.4x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4876.9 MB/s | 2107.6 MB/s | **0.4x** | 5009.4 MB/s | 7415.4 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 649.3 MB/s | 2129.6 MB/s | **3.3x** | 3518.8 MB/s | 7998.9 MB/s | **2.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 576.7 MB/s | 2120.2 MB/s | **3.7x** | 2439.1 MB/s | 7510.3 MB/s | **3.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
