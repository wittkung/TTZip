# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 10:03:56 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 796.7 MB/s | 262.3 MB/s | **0.3x** | 385.2 MB/s | 2504.5 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 758.5 MB/s | 289.7 MB/s | **0.4x** | 338.0 MB/s | 2613.3 MB/s | **7.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 209.3 MB/s | 297.3 MB/s | **1.4x** | 472.8 MB/s | 2618.6 MB/s | **5.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 203.8 MB/s | 300.3 MB/s | **1.5x** | 360.6 MB/s | 2702.1 MB/s | **7.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1072.9 MB/s | 352.6 MB/s | **0.3x** | 1513.5 MB/s | 2621.2 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 841.1 MB/s | 352.6 MB/s | **0.4x** | 677.3 MB/s | 2755.2 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 224.0 MB/s | 353.7 MB/s | **1.6x** | 902.0 MB/s | 2623.8 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 218.1 MB/s | 349.4 MB/s | **1.6x** | 509.7 MB/s | 2347.0 MB/s | **4.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 197.6 MB/s | 1765.4 MB/s | **8.9x** | 3250.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (97.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 122.8 MB/s | 1785.3 MB/s | **14.5x** | 2259.3 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.8%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 113.1 MB/s | 1755.6 MB/s | **15.5x** | 1174.7 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.8%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 114.1 MB/s | 1795.9 MB/s | **15.7x** | 1045.3 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (97.1%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4939.4 MB/s | 2428.3 MB/s | **0.5x** | 4106.0 MB/s | 6627.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4893.7 MB/s | 2505.9 MB/s | **0.5x** | 3976.0 MB/s | 8774.4 MB/s | **2.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 461.4 MB/s | 2457.6 MB/s | **5.3x** | 2582.9 MB/s | 9009.9 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 460.2 MB/s | 2479.6 MB/s | **5.4x** | 2440.2 MB/s | 9108.0 MB/s | **3.7x** | - |
