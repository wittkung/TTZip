# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 18:15:55 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 881.0 MB/s | 138.3 MB/s | **0.2x** | 747.7 MB/s | 1723.7 MB/s | **2.3x** | 2_7zDec_ParallelLZMA2Decode (99.9%) |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 817.2 MB/s | 159.3 MB/s | **0.2x** | 547.9 MB/s | 1820.5 MB/s | **3.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 273.5 MB/s | 176.3 MB/s | **0.6x** | 637.2 MB/s | 1815.0 MB/s | **2.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 277.8 MB/s | 181.2 MB/s | **0.7x** | 484.4 MB/s | 1871.3 MB/s | **3.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1211.5 MB/s | 168.0 MB/s | **0.1x** | 1771.0 MB/s | 1889.4 MB/s | **1.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1058.8 MB/s | 200.0 MB/s | **0.2x** | 962.7 MB/s | 1845.6 MB/s | **1.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 298.1 MB/s | 204.0 MB/s | **0.7x** | 1202.6 MB/s | 1816.1 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.0 MB/s | 207.4 MB/s | **0.7x** | 742.6 MB/s | 1356.3 MB/s | **1.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 175.5 MB/s | 2238.5 MB/s | **12.8x** | 3901.1 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 130.4 MB/s | 2139.1 MB/s | **16.4x** | 1962.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.6%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 107.4 MB/s | 2188.4 MB/s | **20.4x** | 1516.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (94.9%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 116.5 MB/s | 2147.2 MB/s | **18.4x** | 1519.7 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.3%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4722.7 MB/s | 2141.5 MB/s | **0.5x** | 5207.4 MB/s | 6902.2 MB/s | **1.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4615.2 MB/s | 2038.6 MB/s | **0.4x** | 4699.1 MB/s | 7032.2 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 645.1 MB/s | 2132.1 MB/s | **3.3x** | 3056.5 MB/s | 4788.4 MB/s | **1.6x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 593.6 MB/s | 2146.8 MB/s | **3.6x** | 3064.2 MB/s | 7133.0 MB/s | **2.3x** | 2_7zDec_ParallelLZMA2Decode (99.9%) |
