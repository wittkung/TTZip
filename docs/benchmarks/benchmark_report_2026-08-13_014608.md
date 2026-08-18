# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 17:46:08 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 835.3 MB/s | 166.5 MB/s | **0.2x** | 615.7 MB/s | 1712.7 MB/s | **2.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 983.3 MB/s | 190.1 MB/s | **0.2x** | 570.0 MB/s | 1948.7 MB/s | **3.4x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.8 MB/s | 194.6 MB/s | **0.7x** | 674.4 MB/s | 1920.1 MB/s | **2.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 280.1 MB/s | 194.5 MB/s | **0.7x** | 506.2 MB/s | 1955.4 MB/s | **3.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1296.7 MB/s | 205.1 MB/s | **0.2x** | 1986.0 MB/s | 1951.1 MB/s | **1.0x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1066.8 MB/s | 204.9 MB/s | **0.2x** | 978.4 MB/s | 1899.8 MB/s | **1.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 303.1 MB/s | 207.3 MB/s | **0.7x** | 1212.8 MB/s | 1850.2 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.6 MB/s | 208.9 MB/s | **0.7x** | 738.7 MB/s | 1999.7 MB/s | **2.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 181.2 MB/s | 2332.3 MB/s | **12.9x** | 4154.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (72.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 173.5 MB/s | 2319.6 MB/s | **13.4x** | 3197.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (82.7%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 118.4 MB/s | 2191.7 MB/s | **18.5x** | 1560.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (86.6%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 119.3 MB/s | 2288.4 MB/s | **19.2x** | 1396.1 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (88.8%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4590.7 MB/s | 2067.2 MB/s | **0.5x** | 5268.2 MB/s | 6500.3 MB/s | **1.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4960.6 MB/s | 2031.5 MB/s | **0.4x** | 4800.1 MB/s | 7325.3 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 635.9 MB/s | 1978.8 MB/s | **3.1x** | 3416.5 MB/s | 7539.1 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 648.3 MB/s | 2039.0 MB/s | **3.1x** | 3404.8 MB/s | 7625.8 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
