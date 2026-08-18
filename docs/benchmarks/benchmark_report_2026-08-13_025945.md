# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 18:59:45 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1064.7 MB/s | 336.8 MB/s | **0.3x** | 776.1 MB/s | 3854.7 MB/s | **5.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1033.8 MB/s | 307.3 MB/s | **0.3x** | 612.4 MB/s | 3925.6 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 300.5 MB/s | 405.7 MB/s | **1.4x** | 702.6 MB/s | 3776.4 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.8 MB/s | 410.7 MB/s | **1.4x** | 522.9 MB/s | 3605.2 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1334.5 MB/s | 518.3 MB/s | **0.4x** | 2113.3 MB/s | 3612.2 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1166.8 MB/s | 520.6 MB/s | **0.4x** | 1050.8 MB/s | 3536.1 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 311.5 MB/s | 503.3 MB/s | **1.6x** | 1324.5 MB/s | 3845.8 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 309.5 MB/s | 521.3 MB/s | **1.7x** | 817.1 MB/s | 3859.7 MB/s | **4.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 237.6 MB/s | 2425.3 MB/s | **10.2x** | 4450.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 225.9 MB/s | 2523.7 MB/s | **11.2x** | 3580.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.8%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.0 MB/s | 2468.8 MB/s | **18.1x** | 1778.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.2%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.8 MB/s | 2493.9 MB/s | **18.2x** | 1647.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.2%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5083.5 MB/s | 3396.2 MB/s | **0.7x** | 5448.8 MB/s | 7141.8 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5058.4 MB/s | 3296.8 MB/s | **0.7x** | 5109.1 MB/s | 9481.5 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.2 MB/s | 3327.9 MB/s | **5.0x** | 3588.6 MB/s | 9790.0 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 674.0 MB/s | 3338.3 MB/s | **5.0x** | 3534.3 MB/s | 10393.6 MB/s | **2.9x** | - |
