# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 17:48:09 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 877.4 MB/s | 141.4 MB/s | **0.2x** | 764.4 MB/s | 1650.8 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 831.5 MB/s | 152.3 MB/s | **0.2x** | 509.5 MB/s | 1777.8 MB/s | **3.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 241.8 MB/s | 155.8 MB/s | **0.6x** | 580.6 MB/s | 1681.5 MB/s | **2.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 248.2 MB/s | 159.0 MB/s | **0.6x** | 453.1 MB/s | 1670.0 MB/s | **3.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1102.6 MB/s | 168.6 MB/s | **0.2x** | 1591.4 MB/s | 1742.8 MB/s | **1.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 894.8 MB/s | 174.6 MB/s | **0.2x** | 779.0 MB/s | 1577.1 MB/s | **2.0x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 250.2 MB/s | 175.1 MB/s | **0.7x** | 956.7 MB/s | 1548.0 MB/s | **1.6x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 256.1 MB/s | 168.3 MB/s | **0.7x** | 610.3 MB/s | 1791.9 MB/s | **2.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 100.9 MB/s | 1476.2 MB/s | **14.6x** | 2871.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (72.4%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 75.8 MB/s | 1586.4 MB/s | **20.9x** | 1746.7 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (82.5%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 74.6 MB/s | 1231.8 MB/s | **16.5x** | 1277.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (87.0%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 98.9 MB/s | 1946.3 MB/s | **19.7x** | 1108.3 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (89.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 3938.7 MB/s | 1640.7 MB/s | **0.4x** | 4249.7 MB/s | 5215.7 MB/s | **1.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 3979.4 MB/s | 1734.6 MB/s | **0.4x** | 3863.8 MB/s | 6267.6 MB/s | **1.6x** | 2_7zDec_ParallelLZMA2Decode (99.9%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 521.7 MB/s | 1694.9 MB/s | **3.2x** | 2513.0 MB/s | 5377.0 MB/s | **2.1x** | 2_7zDec_ParallelLZMA2Decode (99.8%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 514.0 MB/s | 1663.4 MB/s | **3.2x** | 2310.7 MB/s | 5187.7 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (99.9%) |
