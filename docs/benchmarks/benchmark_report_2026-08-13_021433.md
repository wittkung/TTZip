# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 18:14:33 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 943.9 MB/s | 134.3 MB/s | **0.1x** | 861.4 MB/s | 1685.8 MB/s | **2.0x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 995.1 MB/s | 157.4 MB/s | **0.2x** | 566.9 MB/s | 1865.6 MB/s | **3.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.5 MB/s | 188.0 MB/s | **0.6x** | 661.0 MB/s | 1897.1 MB/s | **2.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.2 MB/s | 188.2 MB/s | **0.7x** | 534.0 MB/s | 1313.8 MB/s | **2.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1273.0 MB/s | 193.9 MB/s | **0.2x** | 1997.2 MB/s | 1769.9 MB/s | **0.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1115.4 MB/s | 207.7 MB/s | **0.2x** | 933.6 MB/s | 1833.7 MB/s | **2.0x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.0 MB/s | 205.1 MB/s | **0.7x** | 1250.3 MB/s | 1844.8 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 270.6 MB/s | 208.0 MB/s | **0.8x** | 720.0 MB/s | 1057.8 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 181.9 MB/s | 1777.1 MB/s | **9.8x** | 3975.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (84.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 178.8 MB/s | 2266.2 MB/s | **12.7x** | 3253.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (88.1%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 121.8 MB/s | 2337.9 MB/s | **19.2x** | 1536.1 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (89.8%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 121.9 MB/s | 2325.5 MB/s | **19.1x** | 1477.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (90.9%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4804.1 MB/s | 2130.5 MB/s | **0.4x** | 4720.4 MB/s | 6598.6 MB/s | **1.4x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4618.6 MB/s | 2111.9 MB/s | **0.5x** | 4710.9 MB/s | 7082.2 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 612.9 MB/s | 1958.3 MB/s | **3.2x** | 3024.2 MB/s | 4593.1 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 631.7 MB/s | 2130.1 MB/s | **3.4x** | 3128.1 MB/s | 7110.9 MB/s | **2.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
